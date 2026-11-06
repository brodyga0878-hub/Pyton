extends SceneTree
const Ship=preload("res://scripts/flight_model.gd")
const Geometry=preload("res://scripts/source_station_geometry.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func _initialize()->void:call_deferred("run")

func flight(model:int=72,id:String="cobra",basis:=Basis.IDENTITY,door:=0)->RefCounted:
	var ship:=Ship.new();ship.ship_id=id;ship.station_available=true;ship.original_port=true
	check(ship.configure_source_station(Geometry.prepare(model,0,door),basis),"Actual source model configures its flight backend")
	return ship

func source_approaches()->void:
	for model in Geometry.MODELS:
		for id in ["cobra","eagle","shuttle"]:
			var basis:=Basis(Vector3.UP,0.35)*Basis(Vector3.FORWARD,0.7)
			var ship:=flight(model,id,basis)
			var waypoint:Vector3=Geometry.prepare(model).approach_waypoint
			ship.position=Ship.STATION+basis*(waypoint+Vector3(160,40,250))
			ship.attitude=Basis(Vector3.RIGHT,0.9).get_rotation_quaternion();ship.autopilot=true
			var staged:=false;var entered:=false;var max_speed:=0.0;var frames:=0
			while not ship.docked and frames<2500:
				ship.step(0.25,Vector2.ZERO)
				max_speed=maxf(max_speed,ship.velocity.length());frames+=1
				if (basis.transposed()*(ship.position-Ship.STATION)).distance_to(waypoint)<5.0:staged=true
				if ship._source_pilot_phase=="enter":entered=true
			check(ship.docked and staged and entered,"Native %d/%s autopilot rejoins actual outer point then flies into real bay"%[model,id])
			check(ship.hull==100 and max_speed<=Ship.DOCK_SPEED+0.001,"Actual source corridor remains clear and phone speed stays capped")
			check(ship.position==Ship.STATION and ship.velocity==Vector3.ZERO and ship.forward().dot(-basis.z)>0.999 and Basis(ship.attitude).y.dot(basis.y)>0.999,"Docking snaps to source centre with heading and roll matched")
			ship.launch()
			check(not ship.docked and ship.position==Ship.STATION and ship.velocity.dot(basis.z)>11.99 and ship.forward().dot(basis.z)>0.999,"Launch starts physical outward flight through source +Z, without teleporting outside")
			for frame in range(100):ship.step(0.25,Vector2.ZERO)
			check(ship.hull==100 and (basis.transposed()*(ship.position-Ship.STATION)).z>250 and not ship.can_dock(),"Outward launch crosses actual open gate safely and cannot redock backwards")

func collision_and_doors()->void:
	for model in Geometry.MODELS:
		var ship:=flight(model);ship.position=Ship.STATION+Vector3(0,0,60);ship.velocity=Vector3(0,0,-100);ship.assisted=false
		ship.step(0.6,Vector2.ZERO)
		check(ship.hull==100 and ship.position.distance_to(Ship.STATION)<0.01,"Open source bay bypasses old invisible 38m station sphere")
		check(not ship.can_dock(),"Fast flight through bay cannot be captured by phone docking guard")
		ship=flight(model);ship.position=Ship.STATION+Vector3(100,0,700);ship.velocity=Vector3(0,0,-1000);ship.assisted=false
		ship.step(1,Vector2.ZERO)
		check(ship.hull<100 and ship.position.z>Ship.STATION.z and not ship.autopilot,"Continuous source wall collision prevents high-speed tunnelling")
		ship=flight(model);ship.position=Ship.STATION+Vector3(0,10,0);ship.attitude=Quaternion(Vector3.FORWARD,PI/2)
		check(not ship._source_shape_sweep(Vector3(0,10,0),Vector3(0,10,0),ship.attitude).is_empty(),"Rolled actual ship ellipsoid does not retain an incorrectly thin station-Y collider")
		ship=flight(model);ship.position=Ship.STATION;ship.velocity=Vector3.ZERO
		check(ship.can_dock() and ship.dock(),"Aligned actual interior dock pose is accepted")
		var closed:=Geometry.prepare(model,0,65535)
		check(ship.configure_source_station(closed,Basis.IDENTITY),"Closing source gate preserves actual dock frame")
		check(ship.source_dock_pose_valid(ship.position,ship.velocity,ship.attitude) and not ship.can_dock(),"Docked interior remains valid behind a closed gate without permitting a new entry")
		ship.launch();check(ship.docked and ship.position==Ship.STATION,"Closed source door prevents launch through solids")
		var save:Dictionary=copy(ship.snapshot());var loaded:=flight(model,"cobra",Basis.IDENTITY,65535)
		check(loaded.restore(save) and loaded.docked,"Legitimate docked save restores while its outer gate is closed")
		ship=flight(model,"cobra",Basis.IDENTITY,65535);ship.position=Ship.STATION+Geometry.prepare(model).approach_waypoint;ship.autopilot=true
		for frame in range(80):ship.step(0.1,Vector2.ZERO)
		check(not ship.docked and ship.velocity.length()<0.01 and ship._source_pilot_phase=="align" and ship.hull==100,"Closed-gate autopilot waits at actual outer waypoint")
		check(ship.configure_source_station(Geometry.prepare(model),Basis.IDENTITY),"Door opening updates derived geometry without replacing flight")
		for frame in range(5):ship.step(0.1,Vector2.ZERO)
		check(ship._source_pilot_phase=="enter" and ship.velocity.z<0,"Waiting pilot resumes actual bay approach after source door opens")
		ship.configure_source_station(closed,Basis.IDENTITY);ship.step(0.1,Vector2.ZERO)
		check(not ship.autopilot and not ship.docked and ship.position.z>Ship.STATION.z+3500,"A closing gate cancels entry while the ship remains outside")

func pose_guards_and_spin()->void:
	var ship:=flight();ship.position=Ship.STATION+Vector3.BACK*80
	check(not ship.can_dock(),"Old 100m capture sphere cannot dock outside actual interior")
	ship.position=Ship.STATION;ship.attitude=Quaternion(Vector3.UP,PI)
	check(not ship.can_dock(),"Backwards heading cannot dock")
	ship.attitude=Quaternion(Vector3.FORWARD,PI)
	check(not ship.can_dock(),"Upside-down roll cannot dock")
	ship.attitude=Quaternion.IDENTITY;ship.velocity=Vector3(0,0,12.01)
	check(not ship.can_dock(),"Phone speed cap rejects fast source docking")
	ship.velocity=Vector3.ZERO;ship.surface_mode=true
	check(not ship.can_dock(),"Surface mode cannot reuse orbital source docking")
	ship.surface_mode=false;ship.combat_active=true
	check(not ship.can_dock(),"Combat guard remains active in source bay")
	ship.combat_active=false;ship.station_available=false
	check(not ship.can_dock(),"Unavailable source services cannot capture the ship")
	ship.station_available=true;check(ship.dock(),"Valid source fixture docks")
	var basis:=Basis(Vector3.UP,0.25)*Basis(Vector3.FORWARD,0.8)
	check(ship.configure_source_station(Geometry.prepare(72),basis) and ship.position==Ship.STATION and ship.forward().dot(-basis.z)>0.999 and Basis(ship.attitude).y.dot(basis.y)>0.999,"Docked ship follows source station spin pose coherently")
	ship=flight();ship.position=Ship.STATION+Geometry.prepare(72).approach_waypoint;ship.autopilot=true
	for frame in range(1700):
		basis=Basis(Vector3.FORWARD,float(frame)*0.002)
		ship.configure_source_station(Geometry.prepare(72),basis);ship.step(0.25,Vector2.ZERO)
		if ship.docked:break
	check(ship.docked and ship.hull==100 and Basis(ship.attitude).y.dot(basis.y)>0.999,"Modern pilot tracks a rotating roll frame through real source opening")

func versioned_saves()->void:
	var legacy:=Ship.new();var legacy_save:Dictionary=copy(legacy.snapshot())
	check(legacy_save.version==4 and not legacy_save.has("source_station"),"Default ship snapshot remains exactly legacy version4")
	var ship:=flight(73,"eagle",Basis(Vector3.FORWARD,0.2));ship.position=Ship.STATION;ship.attitude=Basis(Vector3.FORWARD,0.2).get_rotation_quaternion();check(ship.dock(),"Source save fixture docks")
	var saved:Dictionary=copy(ship.snapshot())
	check(saved.version==5 and saved.source_station.size()==5 and not saved.source_station.has("triangles"),"Opt-in v5 stores compact source identity and pilot profile without a mesh")
	var no_context:=Ship.new();var before:=JSON.stringify(no_context.snapshot())
	check(not no_context.restore(saved) and JSON.stringify(no_context.snapshot())==before,"Source save requires validated world context before flight restore")
	var restored:=flight(73,"cobra",Basis(Vector3.FORWARD,0.2))
	check(restored.restore(saved) and restored.ship_id=="eagle" and restored.docked and restored.has_source_station(),"Sourcev5 restores actual saved ship profile with matching world pose")
	before=JSON.stringify(restored.snapshot());var context:Dictionary=restored.source_station_state()
	for key in ["revision","model_index","source_seed","descriptor_sha256","pilot_profile"]:
		var bad:Dictionary=saved.duplicate(true);bad.source_station[key]="invalid"
		check(not restored.restore(bad) and JSON.stringify(restored.snapshot())==before and restored.source_station_state()==context,"Mismatched source save context rejects atomically")
	var wrong_pose:Dictionary=saved.duplicate(true);wrong_pose.position=[0,0,Ship.STATION.z+80]
	check(not restored.restore(wrong_pose) and JSON.stringify(restored.snapshot())==before,"Forged legacy-radius dock pose fails actual bay geometry validation")
	var forged:Dictionary=saved.duplicate(true);forged.docked=false;forged.position=[100,0,Ship.STATION.z+196.7]
	check(not restored.restore(forged) and JSON.stringify(restored.snapshot())==before,"Undocked saved hull overlap rejects before live flight changes")
	check(restored.restore(legacy_save) and not restored.has_source_station() and restored.snapshot().version==4,"Legacyv4 restore explicitly clears derived source backend")
	ship=flight();before=JSON.stringify(ship.snapshot())
	for bad_basis in [Basis(Vector3(2,0,0),Vector3.UP,Vector3.BACK),Basis(Vector3.LEFT,Vector3.UP,Vector3.BACK)]:check(not ship.configure_source_station(Geometry.prepare(72),bad_basis) and JSON.stringify(ship.snapshot())==before,"Nonrigid or mirrored source pose rejects atomically")
	check(not ship.configure_source_station({},Basis.IDENTITY) and JSON.stringify(ship.snapshot())==before,"Missing source geometry rejects atomically")
	ship.clear_source_station();check(not ship.has_source_station() and ship.snapshot().version==4,"Explicit context clear returns to legacy snapshot contract")

func run()->void:
	source_approaches();collision_and_doors();pose_guards_and_spin();versioned_saves()
	print("SOURCE DOCKING FLIGHT TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
