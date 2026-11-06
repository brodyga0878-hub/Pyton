extends SceneTree
const Session=preload("res://scripts/source_station_session.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Nav=preload("res://scripts/navigation.gd")
const World=preload("res://scripts/planetary_system.gd")
const Geometry=preload("res://scripts/source_station_geometry.gd")
const Clock=preload("res://scripts/source_clock.gd")
const Bridge=preload("res://scripts/source_physics_bridge.gd")
var checks:=0
var failures:=0

class WorldHarness:
	extends RefCounted
	var layout_mode:=Session.FULL_LAYOUT
	var system_id:=World.SOL_ID
	var site_id:="source"
	var site:Dictionary={}
	var orbital:=true
	var frame:Dictionary={}
	var door:=0
	var status:=0
	var advances:=0
	var geometry_reads:=0
	var reject_step:=false
	var override_geometry:=false
	var invalid_geometry:Variant={}
	var override_basis:=false
	var invalid_basis:Variant=Basis.IDENTITY
	func current_site()->Dictionary:return site
	func is_orbital_site()->bool:return orbital
	func source_station_geometry(_days:float)->Variant:
		geometry_reads+=1
		return invalid_geometry if override_geometry else Geometry.prepare_site(site,door)
	func source_station_basis(_days:float)->Variant:
		return invalid_basis if override_basis else Geometry.orientation_basis(frame)
	func source_station_state(_days:float)->Dictionary:
		return {"site_id":site_id,"spin":frame.duplicate(true),"door_u16":door,"status_u8":status}
	func advance_station(dt:float,days:float)->bool:
		if reject_step:return false
		if not orbital:return true
		var clock:=Clock.from_elapsed_days(days)
		if clock.is_empty():return false
		var next:=Geometry.advance_orientation(frame,clock.tick_u32,clock.day_u32)
		var gate:=Geometry.advance_door(door,status,roundi(dt*Bridge.TICKS_PER_SECOND))
		if next.is_empty() or gate.is_empty():return false
		frame=next;door=gate.door_u16;status=gate.status_u8;advances+=1;return true

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func _initialize()->void:call_deferred("run")

func source_records()->Dictionary:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/handcrafted_runtime_native.json"))
	var result:Dictionary={}
	for case:Dictionary in fixture.cases:
		if not str(case.name).ends_with("/ zero destination"):continue
		for encoded:String in case.expected.records_hex:
			var raw:=encoded.hex_decode();var model:=int(raw.decode_u16(12))
			if int(raw.decode_u16(10)) in [32,33,34] and model in Geometry.MODELS and not result.has(model):result[model]=raw
	# Actual native F892 controls supply procedural/special roots missing from
	# handcrafted systems, including the type4 model79 sentinel-name port.
	fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_settlements_native.json"))
	for case:Dictionary in fixture.cases:
		if int(case.operation)!=1:continue
		for encoded:String in case.expected.records.values():
			var raw:=encoded.hex_decode();var model:=int(raw.decode_u16(12))
			if int(raw.decode_u16(10)) in [32,33,34] and model in Geometry.MODELS and not result.has(model):result[model]=raw
	return result

func harness(raw:PackedByteArray)->RefCounted:
	var world:=WorldHarness.new()
	world.site={"id":world.site_id,"parent":"earth","type_code":int(raw.decode_u16(10)),"model_index":int(raw.decode_u16(12)),"runtime_record_hex":raw.hex_encode()}
	var clock:=Clock.from_elapsed_days(0.0)
	world.frame=Geometry.initialize_orientation(raw,clock.tick_u32,clock.day_u32)
	return world

func legacy_isolation()->void:
	var nav:=Nav.new();var world:=World.new();world.configure(nav.current(),World.PORT_LAYOUT)
	var ship:=Ship.new();ship.original_port=true;ship.station_available=true;ship.autopilot=true
	var before:=JSON.stringify(ship.snapshot());var nav_before:=JSON.stringify(nav.snapshot())
	check(ship.configure_source_station(Geometry.prepare(72),Basis.IDENTITY),"Source backend fixture exists before legacy clearing")
	var result:=Session.configure_flight(ship,world,nav)
	check(result.ok and not result.active and not result.handled and result.status=="legacy_layout","Legacy source-portv3 does not opt into v4 collision")
	check(not ship.has_source_station() and JSON.stringify(ship.snapshot())==before and ship.original_port and ship.station_available and ship.autopilot,"Legacy flight snapshot/availability/pilot flags remain unchanged while derived backend clears")
	check(JSON.stringify(nav.snapshot())==nav_before,"Legacy navigation schema and data remain unchanged")
	check(not ship.source_motion_profile,"Legacy context keeps the old motion profile")
	check(Session.refresh(ship,world,nav,NAN).ok,"Legacy refresh does not introduce a station time policy")
	var restored:=Session.restore_flight(world,nav,copy(ship.snapshot()))
	check(restored.get("ok",false) and JSON.stringify(restored.ship.snapshot())==before,"Published legacy Flightv4 restores through the isolated coordinator")
	check(Session.restore_flight(world,nav,{"version":5}).is_empty(),"Source Flightv5 cannot load into a legacy world")

func selected_station(records:Dictionary)->void:
	check(records.size()==Geometry.MODELS.size(),"Tests use actual native packed records for every supported source orbital-station model")
	for model in records:
		var nav:=Nav.new();check(nav.configure_native(),"Native navigation opts in explicitly")
		var world:=harness(records[model]);var ship:=Ship.new()
		var result:=Session.configure_flight(ship,world,nav)
		check(result.ok and result.active and result.handled and result.model_index==model and result.source_seed==int(records[model].decode_u32(4)),"Actual packed station record selects matching geometry identity")
		check(ship.has_source_station() and ship.station_available and ship.original_port and nav.has_station() and ship.snapshot().version==5,"Derived source station enables actual Flightv5 context and selected-port fuel availability")
		check(ship.source_motion_profile,"Full world selects the explicit source motion profile")
		var before:Dictionary=world.frame.duplicate(true)
		ship._source_pilot_phase="align";world.status=1;nav.elapsed_days=0.2/86400.0
		result=Session.refresh(ship,world,nav,0.2)
		check(result.ok and result.active and world.advances==1 and world.door>0 and ship._source_station.door_u16==world.door,"Refresh advances actual source door/orientation before reconfiguring Flight geometry")
		check(world.frame.tick_u32!=before.tick_u32 and ship._source_basis.is_equal_approx(Geometry.orientation_basis(world.frame)) and ship._source_pilot_phase=="align","Aperture changes preserve pilot phase while Flight follows persistent source spin")
		var diagnostic:=Session.diagnostics(ship,world,nav)
		check(diagnostic.active and diagnostic.site_id==world.site_id and diagnostic.flight_context.model_index==model and diagnostic.world_context.door_u16==world.door and not diagnostic.flight_context.has("triangles"),"Compact diagnostics identify source station and persistent frame without geometry payload")
		diagnostic.world_context.spin.matrix_q31[0]=123
		check(world.frame.matrix_q31[0]!=123,"Diagnostics cannot mutate persistent world station state")
		world.orbital=false;world.site={"id":"ground","type_code":35};world.site_id="ground";ship.autopilot=true
		result=Session.configure_flight(ship,world,nav)
		check(result.ok and not result.active and not ship.has_source_station() and not ship.station_available and not ship.autopilot and not nav.has_station() and ship.original_port,"Surface/ground selection clears orbital backend and unavailable orbital services")
		check(ship.source_motion_profile,"Full ground context retains its source motion profile after orbital context clears")
		world.site={};world.site_id="";Session.configure_flight(ship,world,nav)
		check(not ship.original_port and not ship.station_available and not nav.has_station(),"An empty v4 arrival cannot inherit a training station")

func invalid_contexts(records:Dictionary)->void:
	var nav:=Nav.new();check(nav.configure_native(),"Malformed-context native fixture configures")
	var world:=harness(records[72]);var ship:=Ship.new()
	for kind in ["nav_id","nav_time","record","site_model","geometry_model","geometry_seed","geometry_type","basis_scale","basis_mirror","basis_nonfinite","step"]:
		world=harness(records[72]);nav.elapsed_days=0.0;nav.current_id=World.SOL_ID
		check(Session.configure_flight(ship,world,nav).active,"Each invalid-context control starts from a valid active source station")
		ship.autopilot=true
		match kind:
			"nav_id":nav.current_id=0
			"nav_time":nav.elapsed_days=NAN
			"record":world.site.runtime_record_hex="invalid"
			"site_model":world.site.model_index={}
			"geometry_model":world.door=1;world.override_geometry=true;world.invalid_geometry=Geometry.prepare(73)
			"geometry_seed":world.door=1;world.override_geometry=true;world.invalid_geometry=Geometry.prepare(72,int(records[72].decode_u32(4))^1)
			"geometry_type":world.door=1;world.override_geometry=true;world.invalid_geometry=[]
			"basis_scale":world.override_basis=true;world.invalid_basis=Basis.IDENTITY.scaled(Vector3(2,1,1))
			"basis_mirror":world.override_basis=true;world.invalid_basis=Basis(Vector3.LEFT,Vector3.UP,Vector3.BACK)
			"basis_nonfinite":world.override_basis=true;world.invalid_basis=Basis(Vector3(NAN,0,0),Vector3.UP,Vector3.BACK)
			"step":world.reject_step=true
		var result:Dictionary=Session.refresh(ship,world,nav,0.1) if kind=="step" else Session.configure_flight(ship,world,nav)
		check(not result.ok and not result.active and not ship.has_source_station() and not ship.station_available and not ship.autopilot and not nav.has_station(),"Invalid %s fails closed and removes every inherited orbital service/collision context"%kind)
	world=harness(records[72]);nav.elapsed_days=0.0;nav.current_id=World.SOL_ID
	for dt in [NAN,INF,-1.0,"0.1"]:
		Session.configure_flight(ship,world,nav)
		check(not Session.refresh(ship,world,nav,dt).ok and not ship.has_source_station() and world.advances==0,"Invalid refresh duration rejects before world station mutation")
	check(not Session.configure_flight(null,world,nav).ok and not Session.configure_flight(ship,null,nav).ok and not Session.configure_flight(ship,world,null).ok,"Missing session models reject safely")

func restore_order(records:Dictionary)->void:
	var nav:=Nav.new();check(nav.configure_native(),"Restore fixture configures native navigation")
	var world:=harness(records[73]);var ship:=Ship.new()
	check(Session.configure_flight(ship,world,nav).active,"World-first context prepares source Flight before save")
	ship.position=Ship.STATION;ship.attitude=world.source_station_basis(0).get_rotation_quaternion()
	check(ship.dock(),"Saved fixture docks in actual source station bay")
	var saved:Dictionary=copy(ship.snapshot());var live_before:=JSON.stringify(ship.snapshot())
	check(not Ship.new().restore(saved),"Actual Flightv5 alone cannot restore before validated World source context")
	var decoded:=Session.restore_flight(world,nav,saved)
	check(decoded.get("ok",false) and decoded.ship!=ship and decoded.ship.docked and decoded.ship.has_source_station() and decoded.ship.station_available and JSON.stringify(decoded.ship.snapshot())==live_before,"Coordinator reconstructs an independent Flight only after matching World frame and source geometry")
	for kind in ["seed","identity","pose","velocity","target","version"]:
		var bad:Dictionary=copy(saved)
		match kind:
			"seed":bad.source_station.source_seed=int(bad.source_station.source_seed)^1
			"identity":bad.source_station.descriptor_sha256="0".repeat(64)
			"pose":bad.position=[0,0,Ship.STATION.z+80]
			"velocity":bad.velocity=[0,0,1]
			"target":bad.target_speed=1
			"version":bad.version=4;bad.erase("source_station")
		check(Session.restore_flight(world,nav,bad).is_empty() and JSON.stringify(ship.snapshot())==live_before,"Bad source %s rejects without touching an existing live ship"%kind)
	world.orbital=false;world.site={};world.site_id=""
	check(Session.restore_flight(world,nav,saved).is_empty(),"A source Flightv5 save cannot restore while its actual source station is unselected")

func real_full_world()->void:
	var nav:=Nav.new();check(nav.configure_native(),"Actual Worldv4 test configures native navigation")
	var world:=World.new();world.configure(nav.current(),World.FULL_LAYOUT)
	check(world.layout_mode==Session.FULL_LAYOUT,"Actual full source Solar constructor is available")
	var ship:=Ship.new();var configured:=Session.configure_flight(ship,world,nav)
	check(configured.ok and not configured.active and not nav.has_station(),"Actual v4 arrival has no inherited universal station")
	var count:=0
	for site:Dictionary in world.settlements:
		if int(site.type_code) not in [32,33,34]:continue
		world.focus_id=str(site.parent);world.selected_id=world.focus_id;world.site_id=str(site.id)
		configured=Session.configure_flight(ship,world,nav)
		check(configured.ok and configured.active and ship.has_source_station(),"Actual World selects its original orbital geometry through Session")
		nav.elapsed_days+=0.1/86400.0
		check(Session.refresh(ship,world,nav,0.1).ok,"Actual World persistent station frame advances before Flight")
		ship.position=Ship.STATION;ship.velocity=Vector3.ZERO;ship.attitude=world.source_station_basis(nav.elapsed_days).get_rotation_quaternion();ship.docked=false
		check(ship.dock(),"Actual selected source station accepts its centre dock pose")
		var saved_world:Dictionary=copy(world.snapshot());var saved_flight:Dictionary=copy(ship.snapshot())
		var restored_world:=World.new();restored_world.configure(nav.current())
		check(restored_world.restore(saved_world),"Actual Worldv4 restores source gate/spin state first")
		var restored:=Session.restore_flight(restored_world,nav,saved_flight)
		check(restored.get("ok",false) and restored.ship.docked and restored.ship.has_source_station(),"Actual restored Worldv4 supplies the matching Flightv5 source identity")
		check(Session.diagnostics(restored.ship,restored_world,nav).world_context.site_id==str(site.id),"Actual saved source station identity reaches compact diagnostics")
		ship.docked=false;count+=1
	check(count==8,"All eight actual Solar orbital stations pass session and save integration")

func real_generated_stations()->void:
	for control in [[44963608,69],[446994200,74],[178558744,75],[178558746,76],[446994199,77],[111449881,78]]:
		var nav:=Nav.new();check(nav.configure_native(int(control[0])),"Actual procedural source system configures")
		var world:=World.new();world.configure(nav.current(),World.FULL_LAYOUT)
		check(world.layout_mode==World.FULL_LAYOUT,"Actual procedural source hierarchy constructs without handcrafted fallback")
		var found:=false
		for site:Dictionary in world.settlements:
			if int(site.type_code) not in [32,33,34] or int(site.model_index)!=int(control[1]):continue
			found=true;world.focus_id=str(site.parent);world.selected_id=world.focus_id;world.site_id=str(site.id)
			var ship:=Ship.new();var state:=Session.configure_flight(ship,world,nav)
			check(state.ok and state.active and state.model_index==int(control[1]),"Actual generated port selects its own original station model")
			check(Session.refresh(ship,world,nav,0.1).ok and ship.has_source_station() and nav.has_station(),"Actual generated port has source collision/spin and selected fuel context")
			ship.position=Ship.STATION;ship.attitude=world.source_station_basis(0.0).get_rotation_quaternion()
			check(ship.dock(),"Actual generated station has a clear physical centre dock")
			var restored_world:=World.new();restored_world.configure(nav.current())
			check(restored_world.restore(copy(world.snapshot())),"Actual generated station world state restores first")
			var loaded:=Session.restore_flight(restored_world,nav,copy(ship.snapshot()))
			check(loaded.get("ok",false) and loaded.ship.docked and loaded.ship.has_source_station(),"Generated station Flightv5 restores with exact source identity")
			break
		check(found,"Independent real source-header control contains expected procedural station model")

func immutable_geometry_reuse(records:Dictionary)->void:
	var nav:=Nav.new();check(nav.configure_native(),"Geometry reuse native navigation fixture configures")
	var world:=harness(records[72]);var ship:=Ship.new()
	check(Session.configure_flight(ship,world,nav).active and world.geometry_reads==1,"First source context compiles/obtains actual world geometry once")
	for step in range(128):
		nav.elapsed_days+=0.001/86400.0
		check(Session.refresh(ship,world,nav,0.001).active,"Cached source geometry can follow each changing source spin frame")
	check(world.geometry_reads==1 and world.advances==128,"Unchanged model/UID/door avoids copying full triangle packs every frame")
	world.door=1
	check(Session.configure_flight(ship,world,nav).active and world.geometry_reads==2 and ship._source_station.door_u16==1,"Door identity change fetches one new original geometry pack")

func run()->void:
	if not World.can_instantiate():check(false,"World dependency must compile before session integration controls run");quit(1);return
	var records:=source_records()
	legacy_isolation();selected_station(records);invalid_contexts(records);restore_order(records);real_full_world();real_generated_stations();immutable_geometry_reuse(records)
	print("SOURCE STATION SESSION TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
