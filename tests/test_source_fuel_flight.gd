extends SceneTree
const Flight=preload("res://scripts/flight_model.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Bridge=preload("res://scripts/source_fuel_flight_bridge.gd")
var checks:=0
var failures:=0

func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func fresh(disabled_mask:=0)->RefCounted:
	var ship:=Flight.new();ship.station_available=false;ship.assisted=false
	ship.source_thrust_limits_u16=Bridge.cached_limits("cobra")
	for axis in range(6):
		if disabled_mask&(1<<axis):ship.source_thrust_limits_u16[axis]=0
	ship.propulsion_available=ship.source_thrust_limits_u16.any(func(value:Variant)->bool:return int(value)!=0)
	return ship

func run()->void:
	var full:=fresh()
	check(full.source_thrust_limits_u16.size()==6 and full.forward_propulsion_available(),"Source Cobra supplies six cached source nozzle words")
	for axis in range(3):
		for sign_value in [-1,1]:
			var input:=Vector3.ZERO;input[axis]=sign_value
			check(full.filter_propulsive_delta(input)==input,"Healthy source thrust preserves existing phone controller vector")
	var empty:=fresh(0x15)
	check(empty.propulsion_available and not empty.forward_propulsion_available(),"DOS exhaustion preserves three reverse nozzles and disables forward thrust")
	for pair:Array in [[Vector3.LEFT,Vector3.ZERO],[Vector3.RIGHT,Vector3.RIGHT],[Vector3.UP,Vector3.ZERO],[Vector3.DOWN,Vector3.DOWN],[Vector3.FORWARD,Vector3.ZERO],[Vector3.BACK,Vector3.BACK]]:
		check(empty.filter_propulsive_delta(pair[0]).distance_to(pair[1])<0.00001,"Exact positive/negative source axes remain distinct at empty fuel")
	empty.target_speed=600;empty.step(1,Vector2.ZERO)
	check(empty.velocity.length()<0.00001,"Empty forward nozzle cannot add a free forward impulse")
	empty.target_speed=-100;empty.step(1,Vector2.ZERO)
	check(empty.velocity.z>0 and absf(empty.velocity.x)<0.00001,"Uploaded DOS reverse-thrust quirk remains operational")
	var rotating:=fresh(0x15);rotating.attitude=Quaternion(Vector3.UP,1.1)
	check(rotating.filter_propulsive_delta(rotating.forward()).length()<0.00001,"Nozzle gating rotates with the ship rather than world axes")
	check(rotating.filter_propulsive_delta(-rotating.forward()).length()>0.99,"Rotated retro nozzle remains usable")
	var gravity:=fresh(0x15);gravity.assisted=true;gravity.step(0.1,Vector2.ZERO,0,Vector3.DOWN*9.8)
	check(gravity.velocity.y< -0.97 and gravity.last_propulsive_delta_v.length()<0.00001,"Empty upward nozzle cannot cancel gravity in assisted mode")
	var drifting:=fresh(0x3f);drifting.velocity=Vector3(12,3,-5);drifting.target_speed=600
	drifting.step(0.5,Vector2.ZERO,0,Vector3.DOWN*9.8)
	check(drifting.velocity.distance_to(Vector3(12,-1.9,-5))<0.0001,"No fuel preserves inertia and gravity instead of stopping the ship")
	check(Bridge.commands(drifting,0.5)==[0,0,0],"No powered impulse maps to zero source fuel force")
	var mapped:=fresh();mapped.target_speed=600;mapped.step(0.1,Vector2.ZERO)
	var words:=Bridge.commands(mapped,0.1)
	check(words.size()==3 and int(words[2])>0 and int(words[0])==0 and int(words[1])==0,"Actual phone forward impulse maps to positive F938 source force")
	check(int(words[2])<=int(mapped.source_thrust_limits_u16[4]),"Phone force conversion respects the original source nozzle limit")
	check(Bridge.commands(mapped,0).is_empty(),"Invalid adapter duration cannot manufacture fuel consumption")
	var before:Dictionary=mapped.snapshot();mapped.propulsion_available=false;mapped.source_thrust_limits_u16=[0,0,0,0,0,0]
	check(mapped.snapshot()==before,"Derived fuel gating is absent from the independent Flight save contract")
	var restored:=Flight.new()
	check(restored.restore(before) and restored.propulsion_available and restored.source_thrust_limits_u16.is_empty(),"Flight restore does not trust stale derived nozzle gates")
	var landed:=fresh(0x15);landed.surface_mode=true;var surface:=Surface.new();surface.active=true;surface.landed=true;surface.gravity=9.8
	var pose:Vector3=landed.position
	check(not surface.take_off(landed) and surface.landed and landed.position==pose and surface.message.contains("реактивный бак"),"Blocked powered takeoff is atomic and explains the remedy")
	landed.source_thrust_limits_u16=Bridge.cached_limits("cobra")
	check(surface.take_off(landed),"Restoring the six source nozzle limits permits takeoff again")
	var falling:=fresh(0x15);falling.surface_mode=true;falling.position=Vector3(0,1000,0)
	var airborne:=Surface.new();airborne.active=true;airborne.gravity=9.8;airborne.landing=true
	airborne.step(0.1,falling,Vector2.ZERO,0)
	check(falling.velocity.y< -0.97,"Automated surface landing cannot use the old minimum thrust through a missing upward nozzle")
	print("SOURCE FUEL FLIGHT TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
