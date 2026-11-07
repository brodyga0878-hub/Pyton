extends SceneTree
# Raw arithmetic expectations live in the independent native motion fixture.
# This suite tests the actual World/Flight SI boundary and save continuation.
const Bridge=preload("res://scripts/source_motion_bridge.gd")
const Motion=preload("res://scripts/source_motion_pipeline.gd")
const World=preload("res://scripts/planetary_system.gd")
const Definition=preload("res://scripts/source_system_definition.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Units=preload("res://scripts/source_units.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<30:push_error(message)
func copied(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func ship_copy(ship:RefCounted)->RefCounted:
	var result:=Flight.new()
	result.station_available=false;result.position=ship.position;result.velocity=ship.velocity;result.attitude=ship.attitude;result.target_speed=ship.target_speed;result.assisted=ship.assisted
	return result
func run()->void:
	var world:=World.new();world.configure(Definition.new().describe(World.SOL_ID),World.FULL_LAYOUT)
	var ship:=Flight.new();ship.station_available=false;ship.position=Vector3(0.125,0.25,-0.5);ship.velocity=Vector3(0.00123,-0.00234,0.00345);ship.assisted=false
	var bridge:=Bridge.new();var days:=0.125
	check(world.layout_mode==World.FULL_LAYOUT and world.focus_id=="earth" and Bridge.eligible(world,ship),"Actual original full Sol Earth natural arrival is eligible")
	check(bridge.configure(world,ship,days),"Real World/Flight state configures")
	check(bridge.synchronized(world,ship,days),"Initial natural-parent state is synchronized at its navigation clock")
	check(bridge.elapsed_days()==days,"Active bridge exposes exact authoritative nominal-day time")
	check(not bridge.synchronized(world,ship,days+0.000001),"Same parent with changed navigation time invalidates a quiescent save boundary")
	ship.attitude=Quaternion(Vector3.UP,0.01)
	check(not bridge.synchronized(world,ship,days),"External orientation change invalidates a save boundary until source orientation is updated")
	ship.attitude=Quaternion.IDENTITY
	var saved:=bridge.snapshot();var body:=str(saved.motion.body_hex).hex_decode();var center:Vector3=world.local_meters("earth",days)
	check(body.decode_u16(0x82)==38 and body.decode_u16(0xe4)==400,"Body uses source Cobra38 and source mass100tonnes")
	var limits:Array=[]
	for axis in range(6):limits.append(body.decode_s16(0xbc+axis*2))
	check(limits==[3815,-3815,3815,-3815,10900,-3815],"All six actual source thrust words survive SI preparation")
	check(body.decode_s32(0)==-2147483647 and body.decode_s32(16)==2147483647 and body.decode_s32(32)==-2147483647,"Godot identity maps native left/up/forward by proper local yaw(pi)")
	check(Basis(-Basis(ship.attitude).x,Basis(ship.attitude).y,-Basis(ship.attitude).z).determinant()>0.9999,"Axis adapter is a proper rotation")
	for axis in range(3):
		check(body.decode_s64(0x3e+axis*8)==roundi((float(ship.position[axis])-float(center[axis]))/Units.METRES_PER_RAW),"Source position is relative to natural parent, not arrival origin axis%d"%axis)
		var q16:=float(body.decode_s32(0x8c+axis*4))+float(body.decode_u16(0xec+axis*2))/65536.0
		check(absf(q16*Motion.VELOCITY_UNIT_MPS-float(ship.velocity[axis]))<=Motion.VELOCITY_UNIT_MPS/65536.0,"Negative/positive velocity keeps Q16 residue axis%d"%axis)
	var world_before:=var_to_bytes(world.snapshot());var attitude_before:=ship.attitude
	var outcome:=bridge.step(0.001,ship,world,days+0.001/86400.0)
	check(outcome.ok and outcome.handled and outcome.ticks==49 and outcome.ticks_fraction>0,"Subframe coast carries fractional nominal-day ticks")
	check(ship.position.distance_to(Vector3(0.125,0.25,-0.5))<0.01,"Anchored output preserves sub-metre local position beside25Mm parent offset")
	check(ship.attitude==attitude_before and world_before==var_to_bytes(world.snapshot()),"Motion updates only ship translation and retains world/source state")
	days+=0.001/86400.0
	check(bridge.synchronized(world,ship,days),"Handled source step synchronizes raw attitude, translation and current navigation clock")
	saved=copied(bridge.snapshot());var resumed:=Bridge.new();var resumed_ship:=ship_copy(ship)
	check(resumed.restore(saved,world,resumed_ship,days),"Strict bridge JSON restore retains raw words and fractional ticks")
	check(resumed.snapshot()==bridge.snapshot(),"Bridge save roundtrip is exact")
	for step_index in range(12):
		var dt:=0.007+float(step_index)*0.0001;days+=dt/86400.0
		ship.target_speed=300.0;resumed_ship.target_speed=300.0
		var first:=bridge.step(dt,ship,world,days);var second:=resumed.step(dt,resumed_ship,world,days)
		check(first.handled and second.handled and bridge.snapshot()==resumed.snapshot() and ship.position==resumed_ship.position and ship.velocity==resumed_ship.velocity,"Thrust continuation after restore preserves raw state step%d"%step_index)
	check(ship.velocity.z<0,"Native positive main thrust accelerates along authored Godot forward")
	var raw_before:=str(bridge.snapshot().motion.body_hex).hex_decode()
	ship.attitude=Quaternion(Vector3.UP,PI/2);resumed_ship.attitude=ship.attitude;ship.target_speed=0;resumed_ship.target_speed=0
	days+=0.001/86400.0
	check(bridge.step(0.001,ship,world,days).handled,"Changing phone attitude keeps original raw translational state active")
	var raw_after:=str(bridge.snapshot().motion.body_hex).hex_decode()
	check(raw_after.slice(0,36)!=raw_before.slice(0,36),"Attitude adapter refreshes Q31 orientation")
	var original:=bridge.snapshot();var frozen:=var_to_bytes(original);var invalid:Array=[null,[],true,{},42]
	for edit in ["version","ticks_fraction","contract","system_id","parent_id","parent_record_sha256","source_spec_sha256","extra","anchor","clock","orientation","mass","parent","raw_anchor"]:
		var bad:Dictionary=copied(original)
		match edit:
			"version":bad.version=true
			"ticks_fraction":bad.ticks_fraction_f64_hex=Bridge._float_hex(1.0)
			"contract":bad.contract="unknown"
			"system_id":bad.system_id=0
			"parent_id":bad.parent_id="mars"
			"parent_record_sha256":bad.parent_record_sha256="0".repeat(64)
			"source_spec_sha256":bad.source_spec_sha256="0".repeat(64)
			"extra":bad.extra=0
			"anchor":bad.anchor_local_m[0]+=10
			"clock":bad.elapsed_days_f64_hex=Bridge._float_hex(days+0.000001)
			"raw_anchor":bad.anchor_raw_hex="00".repeat(24)
			"orientation":
				var altered:=str(bad.motion.body_hex).hex_decode();altered.encode_s32(0,0x7fffffff);bad.motion.body_hex=altered.hex_encode()
			"mass":
				var altered:=str(bad.motion.body_hex).hex_decode();altered.encode_u16(0xe4,200);bad.motion.body_hex=altered.hex_encode()
			"parent":bad.motion.parent_hex="00".repeat(338)
		invalid.append(bad)
	var bad_index:=0
	for bad in invalid:
		check(not bridge.restore(bad,world,ship,days) and var_to_bytes(bridge.snapshot())==frozen,"Invalid/mismatched restore rejects atomically %d"%bad_index);bad_index+=1
	for dt in [true,null,"0.1",0,-0.1,0.100001,NAN,INF]:
		var result:=bridge.step(dt,ship,world,days)
		check(not result.ok and not result.handled and var_to_bytes(bridge.snapshot())==frozen,"Invalid dt preserves the raw state")
	ship.target_speed=NAN
	check(not bridge.step(0.01,ship,world,days).ok and var_to_bytes(bridge.snapshot())==frozen,"Nonfinite phone target rejects before integer conversion")
	ship.target_speed=0
	var good_attitude:=ship.attitude;ship.attitude=Quaternion(NAN,0,0,1)
	check(not bridge.step(0.01,ship,world,days).ok and var_to_bytes(bridge.snapshot())==frozen,"Nonfinite attitude rejects before Q31 conversion")
	ship.attitude=good_attitude
	ship.position+=Vector3(10,0,0)
	check(not bridge.step(0.01,ship,world,days).handled and not bridge.is_active(),"Collision/teleport externally changed position resets old source state")
	check(bridge.step(0.01,ship,world,days).handled,"Following eligible step reanchors authoritatively after external change")
	check(not bridge.step(0.01,ship,world,days,1).handled and not bridge.is_active(),"Vertical phone assist uses existing explicit fallback and resets raw state")
	for field in ["autopilot","surface_mode","combat_active","docked","station_available"]:
		ship.set(field,true);check(not Bridge.eligible(world,ship),"Unsupported gameplay context excludes raw motion "+field);ship.set(field,false)
	world.site_id="site17";check(not Bridge.eligible(world,ship),"Selected orbital/site reference frame excluded until velocity transform proven");world.site_id=""
	world.transfer_remaining=1;check(not Bridge.eligible(world,ship),"Transfer origin change excluded");world.transfer_remaining=0
	ship.hull=0;check(not Bridge.eligible(world,ship),"Destroyed ship cannot receive source thrust");ship.hull=100
	var assisted_ship:=Flight.new();assisted_ship.station_available=false;assisted_ship.target_speed=100
	var assisted_bridge:=Bridge.new()
	check(assisted_ship.assisted and assisted_bridge.step(0.05,assisted_ship,world,0.5).handled,"Default assisted Flight reaches original F607/F599/F601 through the live bridge")
	check(assisted_ship.velocity.z<0,"Assisted source set-speed follows the same authored forward axis")
	var assisted_body:=str(assisted_bridge.snapshot().motion.body_hex).hex_decode()
	check(assisted_body.decode_s16(0xba)>0 and assisted_body.decode_s16(0xba)<=10900 and assisted_body.decode_s32(0xfa)<0,"Assisted local forward request uses native Cobra limit and signed world residual")
	assisted_ship.attitude=Quaternion(Vector3.UP,PI/2)
	check(assisted_bridge.step(0.05,assisted_ship,world,0.5+0.05/86400.0).handled and assisted_ship.velocity.x<0,"Assisted rotated Q31 forward thrust follows current phone attitude without reflecting world axes")
	print("SOURCE MOTION BRIDGE TESTS: %d checks, %d failures; fixed natural parent only, explicit phone axes and nominal-day clock"%[checks,failures]);quit(1 if failures else 0)
