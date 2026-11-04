extends SceneTree
const Flight=preload("res://scripts/flight_model.gd")
var checks:=0
var failures:=0

func _init()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(message)
func near(first:float,second:float,tolerance:=0.0001)->bool:return absf(first-second)<=tolerance
func json_copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func runtime_state(ship:RefCounted)->String:
	return JSON.stringify({"save":ship.snapshot(),"autopilot":ship.autopilot,"original_port":ship.original_port,"surface_mode":ship.surface_mode,"combat_active":ship.combat_active,"station_available":ship.station_available,"shots":ship.shots,"notice":ship.last_notice})

func flight_controls()->void:
	var ship:=Flight.new()
	check(ship.catalog.valid and ship.ship_id=="cobra" and ship.cargo_capacity()==60 and near(ship.profile().visual_span_m,42),"Recovered default API uses the documented adapted Cobra profile")
	ship.station_available=false;ship.target_speed=100
	ship.step(1.0,Vector2.ZERO)
	check(ship.velocity.distance_to(Vector3(0,0,-18))<0.0001 and ship.position.distance_to(Vector3(0,0,-18))<0.0001,"Assisted mode approaches requested velocity with available acceleration")
	ship=Flight.new();ship.station_available=false;ship.assisted=false;ship.target_speed=600
	ship.step(1,Vector2.ZERO,0,Vector3.DOWN*9.81)
	check(ship.velocity.distance_to(Vector3(0,-9.81,-18))<0.0001,"Inertial mode applies axial thrust and actual gravity")
	ship=Flight.new();ship.station_available=false
	ship.step(1,Vector2.ZERO,0,Vector3.DOWN*9.81)
	check(ship.velocity.length()<0.0001,"Available assisted thrust can hold altitude without adding a second gravity impulse")
	ship.step(1,Vector2.ZERO,0,Vector3.DOWN*25)
	check(near(ship.velocity.y,-7),"Insufficient thrust leaves the uncompensated gravity acceleration")
	ship=Flight.new();ship.station_available=false
	ship.step(1,Vector2.ZERO,0,Vector3.DOWN*9.81,1)
	check(near(ship.velocity.y,18-9.81),"Touch lift uses the remaining thrust reserve")
	for tick in range(120):ship.step(1.0/60,Vector2(0.4,-0.6),0.5,Vector3.ZERO,0)
	check(ship.attitude.is_finite() and near(ship.attitude.length_squared(),1,0.00001) and ship.forward().is_finite(),"Combined phone steering retains a finite unit orientation")
	ship=Flight.new();ship.station_available=false;ship.velocity=Vector3.RIGHT*100;ship.autopilot=true;ship.brake()
	check(ship.target_speed==0 and ship.assisted and not ship.autopilot,"Brake requests an assisted stop and releases station guidance")
	for tick in range(420):ship.step(1.0/60,Vector2.ZERO)
	check(ship.velocity.length()<0.001,"Assisted braking actually stops lateral motion")
	var before:=runtime_state(ship)
	for dt in [0.0,-1.0,NAN,INF]:
		ship.step(dt,Vector2.ZERO)
		check(runtime_state(ship)==before,"Invalid frame duration cannot change flight state")
	ship.step(1,Vector2(INF,0));check(runtime_state(ship)==before,"Non-finite steering cannot poison flight")
	ship.step(1,Vector2.ZERO,NAN);check(runtime_state(ship)==before,"Non-finite roll is rejected")
	ship.step(1,Vector2.ZERO,0,Vector3(INF,0,0));check(runtime_state(ship)==before,"Non-finite gravity is rejected")
	ship.step(1,Vector2.ZERO,0,Vector3.ZERO,INF);check(runtime_state(ship)==before,"Non-finite lift is rejected")
	ship.hull=0;var point:Vector3=ship.position;ship.step(1,Vector2.ONE)
	check(ship.position==point and not ship.fire(),"A destroyed ship cannot accelerate or fire")

func station_and_training_trade()->void:
	var ship:=Flight.new();ship.autopilot=true
	for tick in range(12000):
		ship.step(1.0/60,Vector2.ZERO)
		if ship.docked:break
	check(ship.docked and ship.hull==100 and ship.velocity.length()<0.001,"Station guidance completes an unharmed assisted approach")
	check(ship.buy() and ship.cargo==3 and ship.credits==900,"Adapted training market buys a whole unit")
	check(ship.sell() and ship.cargo==2 and ship.credits==980,"Adapted training market sells a whole unit")
	check(ship.deliver() and ship.cargo==0 and ship.credits==1780 and ship.delivered,"Two default medicine units yield the observed 800-credit training reward")
	var balance:int=ship.credits
	check(not ship.deliver() and ship.credits==balance,"The training order cannot be paid twice")
	check(not ship.buy("unknown") and not ship.buy("food",0) and not ship.buy("food",1.5),"Unknown or fractional/empty market requests are rejected")
	ship.launch()
	check(not ship.docked and ship.position.distance_to(Flight.STATION)>=150 and ship.forward().dot((ship.position-Flight.STATION).normalized())>0.99,"Launch clears the station and points the nose outward for phone control")
	check(ship.velocity.length()>0 and not ship.autopilot and ship.assisted,"Launch starts a controlled outward departure")
	check(not ship.buy() and not ship.sell() and not ship.change_ship("eagle"),"Market and ship changes require docking")
	ship=Flight.new();ship.position=Flight.STATION+Vector3.BACK*1000;ship.velocity=Vector3.FORWARD*200;ship.assisted=false
	ship.step(10,Vector2.ZERO)
	check(near(ship.hull,70) and near(ship.position.distance_to(Flight.STATION),45) and ship.velocity.z>0,"Swept station contact catches a segment that tunnels through the station")
	ship=Flight.new();ship.position=Flight.STATION+Vector3.BACK*80
	ship.surface_mode=true;check(not ship.dock(),"Surface flight cannot enter the orbital docking flow")
	ship.surface_mode=false;ship.combat_active=true;check(not ship.dock(),"Combat blocks docking")
	ship.combat_active=false;ship.station_available=false;check(not ship.dock(),"Absent station blocks docking")
	ship.station_available=true;check(ship.dock(),"A stopped nearby ship can dock")
	ship.original_port=true
	check(not ship.buy() and not ship.sell() and not ship.deliver() and not ship.install_equipment("shield") and not ship.change_ship("eagle"),"The adapted training market does not impersonate an unfinished original FFE port service")

func loadout_and_inventory()->void:
	var ship:=Flight.new();ship.docked=true;ship.credits=10000
	check(ship.install_equipment("engine") and near(ship.acceleration(),21.6) and ship.cargo_capacity()==56,"Equipment takes cargo space and changes actual thrust")
	check(not ship.install_equipment("engine"),"Unique equipment cannot be installed twice")
	check(ship.remove_equipment("engine") and ship.credits==9400 and near(ship.acceleration(),18) and ship.cargo_capacity()==60,"Removing equipment restores capacity and the bounded half-price refund")
	check(ship.install_equipment("hyperdrive") and near(ship.jump_range(),25),"The hyperdrive adapter changes exposed jump range")
	ship.remove_equipment("hyperdrive")
	ship.goods.metals=20
	check(not ship.change_ship("eagle") and ship.ship_id=="cobra","Ship changes cannot discard cargo to fit a smaller hold")
	ship.goods.metals=0
	check(ship.change_ship("shuttle") and ship.cargo_capacity()==4 and near(ship.acceleration(),12) and near(ship.jump_range(),8),"The preserved Shuttle limits are distinct from Cobra")
	check(ship.buy() and ship.buy() and not ship.buy() and ship.cargo==4,"The loaded hold prevents over-capacity purchases")
	check(not ship.install_equipment("shield"),"Equipment cannot overlap occupied cargo capacity")
	ship.goods=ship.economy_catalog.empty_manifest();ship.credits=1000000000;ship.equipment=["shield"]
	check(not ship.remove_equipment("shield") and "shield" in ship.equipment,"A refund cannot overflow the credit limit")
	ship=Flight.new();ship.docked=true
	check(ship.trade_ship("eagle") and ship.ship_id=="eagle" and ship.credits==5000,"The adapted exchange deducts the new hull and credits the documented trade value")

func save_validation()->void:
	var source:=Flight.new();source.credits=71923;source.hull=83.5;source.goods.food=1
	source.goods.medicines=3;source.mission_cargo={"contract-a":2};source.story_cargo=2;source.equipment=["engine","shield"]
	source.position=Vector3(1234.25,876.5,-6543);source.velocity=Vector3(3,-4,5);source.attitude=Quaternion(Vector3.UP,0.6);source.target_speed=120
	var state:Dictionary=json_copy(source.snapshot())
	var copy:=Flight.new()
	check(copy.restore(state),"A complete rebuilt snapshot decodes after JSON serialization")
	check(copy.ship_id==source.ship_id and copy.credits==71923 and near(copy.hull,83.5) and copy.total_cargo()==8 and copy.equipment==source.equipment,"Saved hull, funds, ordinary/mission/story cargo and equipment survive")
	check(copy.position.distance_to(source.position)<0.001 and copy.velocity==source.velocity and copy.attitude.is_equal_approx(source.attitude),"Saved local pose and motion survive with a normalized quaternion")
	var cases:Array=[];var bad:Dictionary
	bad=state.duplicate(true);bad.position=[1,2];cases.append(bad)
	bad=state.duplicate(true);bad.position[2]=INF;cases.append(bad)
	bad=state.duplicate(true);bad.velocity[0]=NAN;cases.append(bad)
	bad=state.duplicate(true);bad.attitude=[0,0,0,0];cases.append(bad)
	bad=state.duplicate(true);bad.credits=4.5;cases.append(bad)
	bad=state.duplicate(true);bad.credits=1000000001;cases.append(bad)
	bad=state.duplicate(true);bad.cargo=1;cases.append(bad)
	bad=state.duplicate(true);bad.goods.metals=60;cases.append(bad)
	bad=state.duplicate(true);bad.goods.unknown=1;cases.append(bad)
	bad=state.duplicate(true);bad.equipment=["engine","engine"];cases.append(bad)
	bad=state.duplicate(true);bad.equipment=[false];cases.append(bad)
	bad=state.duplicate(true);bad.mission_cargo={"":1};cases.append(bad)
	bad=state.duplicate(true);bad.story_cargo=1;cases.append(bad)
	bad=state.duplicate(true);bad.ship_id="missing";cases.append(bad)
	bad=state.duplicate(true);bad.target_speed=INF;cases.append(bad)
	bad=state.duplicate(true);bad.hull=-1;cases.append(bad)
	bad=state.duplicate(true);bad.docked="false";cases.append(bad)
	bad=state.duplicate(true);bad.external_view=0;cases.append(bad)
	bad=state.duplicate(true);bad.delivered="false";cases.append(bad)
	bad=state.duplicate(true);bad.version=true;cases.append(bad)
	for index in range(cases.size()):
		copy=Flight.new();copy.restore(state);copy.original_port=true;copy.station_available=false;copy.surface_mode=true;copy.combat_active=true;copy.autopilot=true;copy.shots=7;copy.last_notice="Сохранить"
		var before:=runtime_state(copy)
		check(not copy.restore(cases[index]),"Malformed save is rejected: %d"%index)
		check(runtime_state(copy)==before,"Rejected save is atomic including derived runtime flags: %d"%index)
	copy=Flight.new();copy.original_port=true;copy.surface_mode=true;copy.combat_active=true;copy.autopilot=true
	check(copy.restore(state) and not copy.original_port and not copy.surface_mode and not copy.combat_active and not copy.autopilot,"Successful restore leaves context flags for world-level reconstruction instead of trusting a save")
	for version in [1,2,3]:
		var legacy:Dictionary=state.duplicate(true);legacy.version=version
		if version<3:
			for key in ["goods","equipment","mission_cargo","story_cargo"]:legacy.erase(key)
			if version==2:legacy.ship_id="shuttle";legacy.cargo=4
			else:legacy.erase("ship_id")
		else:legacy.erase("story_cargo")
		copy=Flight.new()
		check(copy.restore(legacy) and copy.snapshot().version==4,"Supported legacy flight schema migrates to the retained v4 wire format: %d"%version)
		check(copy.story_cargo==0 and (version!=2 or copy.ship_id=="shuttle" and copy.cargo==4),"Legacy migration retains its hull/cargo semantics: %d"%version)
	var invalid_v1:Dictionary=state.duplicate(true);invalid_v1.version=1;invalid_v1.cargo=11
	check(not Flight.new().restore(invalid_v1),"The old v1 ten-ton limit remains explicit")

func run()->void:
	flight_controls();station_and_training_trade();loadout_and_inventory();save_validation()
	print("REBUILT FLIGHT TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
