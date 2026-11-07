extends SceneTree
const Bridge=preload("res://scripts/source_motion_bridge.gd")
const World=preload("res://scripts/planetary_system.gd")
const Definition=preload("res://scripts/source_system_definition.gd")
const Flight=preload("res://scripts/flight_model.gd")
const TimeControl=preload("res://scripts/flight_time_controller.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func copy_ship(ship:RefCounted)->RefCounted:
	var other:=Flight.new();other.station_available=false;other.position=ship.position;other.velocity=ship.velocity;other.attitude=ship.attitude;other.target_speed=ship.target_speed;other.assisted=ship.assisted
	return other
func run()->void:
	var world:=World.new();world.configure(Definition.new().describe(World.SOL_ID),World.FULL_LAYOUT)
	var ship:=Flight.new();ship.station_available=false;ship.assisted=false;ship.velocity=Vector3(900.123,-500.234,25.345)
	var bridge:=Bridge.new();var days:=0.125
	check(bridge.configure(world,ship,days),"Actual original Earth frame configures the source bridge")
	var dt:=0.0073;days+=dt/86400
	check(bridge.step(dt,ship,world,days).get("handled",false),"Raw movement carries non-integral source time")
	var snapshot:=bridge.snapshot();var before:=str(snapshot.motion.body_hex).hex_decode();var words:=bridge.velocity_words()
	check(words.size()==3 and words[0]>0 and words[1]<0,"Bridge exposes signed integer velocity independently of its Q16 residue")
	var after_words:Array=[int(words[0])-11,int(words[1])+7,int(words[2])-2]
	check(bridge.apply_velocity_words(after_words,ship),"Source drag can replace only the native integer velocity words")
	var changed:=bridge.snapshot();var after:=str(changed.motion.body_hex).hex_decode()
	for index in range(before.size()):
		if index>=0x8c and index<0x98:continue
		check(before[index]==after[index],"Drag preserves every non-velocity byte including source fractions")
	for axis in range(3):check(after.decode_s32(0x8c+axis*4)==int(after_words[axis]),"Drag writes the correct signed source velocity word")
	var without_motion:=snapshot.duplicate(true);without_motion.erase("motion")
	var other_fields:=changed.duplicate(true);other_fields.erase("motion")
	check(without_motion==other_fields,"Thermal drag retains the anchor, exact days and fractional source ticks")
	check(bridge.synchronized(world,ship,days),"Source save boundary remains synchronized immediately after thermal drag")
	var cold:=Bridge.new();var second:=copy_ship(ship)
	check(cold.restore(JSON.parse_string(JSON.stringify(changed)),world,second,days),"Strict cold restore accepts the post-drag raw source body")
	for iteration in range(4):
		days+=0.0081/86400.0
		check(bridge.step(0.0081,ship,world,days).get("handled",false) and cold.step(0.0081,second,world,days).get("handled",false),"Both post-drag continuations execute source motion")
		check(bridge.snapshot()==cold.snapshot() and ship.position==second.position and ship.velocity==second.velocity,"Post-drag raw continuation survives cold restore without reanchoring")
	var original:=bridge.snapshot();var old_velocity:=ship.velocity
	for invalid:Array in [[],[0,0],[0,0,0x80000000],[0,0,-0x80000001],[0,0,1.5]]:
		check(not bridge.apply_velocity_words(invalid,ship) and bridge.snapshot()==original and ship.velocity==old_velocity,"Invalid drag words leave the complete raw and phone state unchanged")
	ship.velocity+=Vector3.ONE
	check(not bridge.apply_velocity_words([0,0,0],ship) and bridge.snapshot()==original,"A stale source body cannot overwrite externally changed phone velocity")
	var safe_context:={"source_world":true,"body_clearance_m":1e12,"speed_mps":0.0,"gravity_mps2":0.0,"station_available":false}
	check(TimeControl.safety_limit(safe_context).rate==100,"Clear cold space retains the existing bounded acceleration rates")
	safe_context.atmospheric_hazard=true
	check(TimeControl.safety_limit(safe_context).rate==1 and TimeControl.safety_limit(safe_context).code=="atmospheric_hazard","Atmospheric heat risk restricts acceleration with an accurate reason")
	safe_context.paused=true
	check(TimeControl.safety_limit(safe_context).rate==0,"A heat warning does not resume a paused simulation")
	safe_context.paused=false;safe_context.active=false
	check(TimeControl.safety_limit(safe_context).rate==0,"A thermal state does not resume an inactive application")
	safe_context.active=true;safe_context.atmospheric_hazard="yes"
	check(TimeControl.safety_limit(safe_context).rate==0,"Malformed thermal safety input cannot enable acceleration")
	print("SOURCE THERMAL MOTION BRIDGE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
