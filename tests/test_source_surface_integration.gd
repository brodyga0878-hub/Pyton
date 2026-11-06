extends SceneTree
const World=preload("res://scripts/planetary_system.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
const Near=preload("res://scripts/near_surface_view.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func _init()->void:call_deferred("run")
func fixture(model:int)->Dictionary:
	var world:=World.new();world.configure(Galaxy.new().get_system(Galaxy.SOL_ID),World.FULL_LAYOUT)
	var site:Dictionary={}
	for candidate:Dictionary in world.settlements:
		if int(candidate.model_index)==model:site=candidate;break
	if site.is_empty():return {}
	world.focus_id=str(site.parent);world.selected_id=world.focus_id;world.site_id=str(site.id)
	var ship:=Flight.new();ship.station_available=false
	return {"world":world,"ship":ship,"surface":Surface.new(),"site":site}
func run()->void:
	var f:=fixture(84)
	check(not f.is_empty(),"NewWorld exposes actual original groundports")
	if f.is_empty():quit(1);return
	var world:RefCounted=f.world;var ship:RefCounted=f.ship;var surface:RefCounted=f.surface
	check(surface.enter(ship,world,true),"Native source surface entry")
	if not surface.active:push_error(surface.message);quit(1);return
	check(surface.source_surface() and surface.globe.revision==Terrain.REVISION_NAME,"FULLlayout selects source terrain only")
	check(not surface.city_data.is_empty() and surface.globe.radius==7049700.0,"Actual city anchor and source radius live")
	check(is_finite(surface.gravity) and surface.gravity>0 and surface.gravity_vector.is_finite(),"Live source gravity available")
	var ll:Array=surface.geographic_position(ship)
	var point:Vector3=Link.direction(ll[0],ll[1])*(surface.globe.radius+surface.geoid_height(ship))
	var expected:Dictionary=world.source_surface_gravity(world.focus_id,point,0.0)
	check(absf(surface.gravity-float(expected.gravity_mps2))<1e-9,"Safety and flight use World actualF603gravity")
	var frame:Basis=world.body_rotation_basis(world.focus_id,0.0)*surface.globe.basis_at(surface.globe.latitude,surface.globe.longitude)
	check((frame*surface.gravity_vector).distance_to(expected.acceleration)<1e-5,"Gravity converted through same actual source body pose")
	var state:Dictionary=JSON.parse_string(JSON.stringify(surface.snapshot()))
	var restored:=Surface.new()
	check(restored.restore(state,ship,world) and restored.globe.revision==Terrain.REVISION_NAME,"Source surface save restores explicit revision")
	var bad:=state.duplicate(true);bad.terrain_revision="sphere-source-ground-v999"
	var previous:=restored.snapshot()
	check(not restored.restore(bad,ship,world) and restored.snapshot()==previous,"Invalid source revision restore atomic")
	# The source field sits kilometres below its static-axis reference; ascent
	# targets20km above terrain, keeping it inside the existing60km flight cap.
	ship.position=Vector3(0,surface.height_at(0,0)+Link.ALTITUDE-0.2,0);ship.velocity=Vector3.ZERO
	check(surface.begin_ascent(ship),"Source ascent engages above native terrain")
	surface.step(0.01,ship,Vector2.ZERO,0.0)
	check(surface.ready_for_orbit,"Source ascent reaches AGLtarget instead of impossible geoidtarget")
	check(surface.leave(ship,world,0.0),"Source surface departure")
	check(surface.orbit_link.revision==Link.SOURCE_REVISION and surface.orbit_link.terrain_revision==Terrain.REVISION_NAME,"New source link revision explicit")
	check(surface.orbit_link.departure_matrix_q31.size()==9 and Link.valid(surface.orbit_link,world),"Link stores actual departure source matrix and validates")
	check(absf(float(surface.orbit_link.surface_elevation_m))>1000.0,"Source link preserves significant real source elevation")
	var departure_lat:=float(surface.orbit_link.latitude);var departure_lon:=float(surface.orbit_link.longitude)
	check(Link.coordinates(surface.orbit_link,ship,world,0.0)==[departure_lat,departure_lon],"Exact same-time geographic source roundtrip")
	var near:=Near.new()
	check(near.update(surface,ship,world,0.0) and near.drawing.globe.revision==Terrain.REVISION_NAME,"Near-surface preview uses source height/frame at20kmAGL")
	check(absf(near.height-(Link.ALTITUDE-near.drawing.clearance(ship)))<2.0,"Preview height measured above actual source terrain")
	var distant:=Near.new();var departure_position:Vector3=ship.position
	ship.position=world.local_meters(world.focus_id,0.0)+Vector3.RIGHT*float(world.by_id[world.focus_id].radius_km)*3000.0
	check(not distant.update(surface,ship,world,0.0) and distant._source_sampler==null,"Distant source orbit rejects before any sampler/city construction")
	ship.position=departure_position
	check(surface.enter_from_orbit(ship,world,0.0),"Source geographic reentry")
	check(surface.globe.revision==Terrain.REVISION_NAME and absf(surface.altitude(ship)-1500.0)<0.1,"Source reentry keeps source sampler and AGLclearance")
	# User regression: an off-pad landing remains able to lift on a healthy ship.
	ship.position=Vector3(10000,surface.height_at(10000,-10000)+surface.clearance(ship)+0.5,-10000);ship.velocity=Vector3.ZERO
	check(surface.touch_down(ship),"Off-pad source surface touchdown")
	surface.step(0.1,ship,Vector2.ZERO,0.0,1.0)
	check(not surface.landed and surface.altitude(ship)>0.1 and ship.velocity.y>0,"Phone lift leaves off-pad source landing: "+surface.message)
	await underground_controls()
	prepared_entry_controls()
	model117_controls()
	print("SOURCE SURFACE INTEGRATION TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func underground_controls()->void:
	var f:=fixture(96)
	check(not f.is_empty(),"Sol original enclosed lunar hangar exists")
	if f.is_empty():return
	var world:RefCounted=f.world;var ship:RefCounted=f.ship;var surface:RefCounted=f.surface
	check(surface.enter(ship,world,true),"Original model96 enters onlysourcev4")
	if not surface.active:push_error(surface.message);return
	check(surface.underground!=null and not surface.city_data.is_empty() and surface.city_data.profile.pad_count==0,"Closed source hangar has actual collider and no fake openpad")
	check(surface.begin_landing(ship) and surface.underground.state.phase=="opening","Autoland requests native hatch opening")
	var pending_before:Dictionary=surface.city_data
	surface.step(0.1,ship,Vector2.ZERO,0.0)
	check(surface.underground.dirty and surface.city_data==pending_before,"Fixed step queues hatch without publishing stalecollider")
	var bundle:Dictionary=surface.prepare_underground_update()
	check(bundle.get("ok",false) and surface.publish_underground_update(bundle,ship),"Worker-prepared hatch publishes atomically")
	check(surface.city_data.door_u16==surface.underground.state.door_u16,"Renderedcity andphysics share exact hatchpose")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(surface.snapshot()))
	var restored:=Surface.new()
	check(restored.restore(saved,ship,world) and restored.underground!=null,"Source hangar phase and source geometry restore")
	var bad:=saved.duplicate(true);bad.underground.state.door_u16=70000
	var before:=restored.snapshot()
	check(not restored.restore(bad,ship,world) and restored.snapshot()==before,"Corrupt hangar door rejects atomically")
	await process_frame
func model117_controls()->void:
	var world:=World.new();world.configure(Galaxy.new().get_system(Galaxy.SOL_ID),World.FULL_LAYOUT)
	var body:Dictionary={}
	for candidate:Dictionary in world.bodies:
		if int(candidate.model_index)==117 and candidate.get("landable",false):body=candidate;break
	check(not body.is_empty(),"Actual generated Sol has nonspherical Hyperion model117")
	if body.is_empty():return
	world.focus_id=str(body.id);world.selected_id=world.focus_id;world.site_id=""
	var ship:=Flight.new();ship.source_motion_profile=true;ship.station_available=false
	var surface:=Surface.new()
	check(surface.enter(ship,world,true),"Live model117 enters with actual source field/corrected callerbound")
	if not surface.active:push_error(surface.message);return
	check(surface.globe.source_policy.boundary_policy==Terrain.BOUNDARY_POLICY and is_finite(surface.altitude(ship)),"Nonspherical live source policy explicit")
	ship.position=Vector3(0,surface.height_at(0,0)+surface.clearance(ship)+0.5,0);ship.velocity=Vector3.ZERO
	check(surface.touch_down(ship),"Model117 off-pad physical touchdown")
	var landed_save:Dictionary=JSON.parse_string(JSON.stringify(surface.snapshot()))
	var landed_restore:=Surface.new();check(landed_restore.restore(landed_save,ship,world) and landed_restore.landed,"Model117 landed state restores beforetakeoff")
	surface=landed_restore
	check(surface.take_off(ship),"Model117 restored off-pad takeoff available")
	surface.step(0.1,ship,Vector2.ZERO,0.0,1.0)
	check(not surface.landed and surface.altitude(ship)>0.1 and ship.velocity.y>0,"Model117 phone lift produces positive physicalclearance")
	check(surface.begin_departure(ship),"Model117 takeoff continues to controlled departure")
	var departure_save:Dictionary=JSON.parse_string(JSON.stringify(surface.snapshot()))
	var departure_restore:=Surface.new();check(departure_restore.restore(departure_save,ship,world) and departure_restore.flight_phase=="ascent","Model117 active departure restores consistently")
	surface=departure_restore
	ship.position=Vector3(1000,0,-700);ship.position.y=surface.height_at(1000,-700)+surface.clearance(ship)+600.0
	var before_radius:=sqrt(float(ship.position.x)*ship.position.x+float(ship.position.z)*ship.position.z+pow(surface.globe.radius+float(ship.position.y),2))
	var before_ll:Array=surface.geographic_position(ship)
	surface.recenter(ship)
	check(absf(surface.globe.radius+float(ship.position.y)-before_radius)<0.03,"Model117 rebase preserves actual bodyfixed radius")
	check(absf(surface.globe.latitude-float(before_ll[0]))<1e-10 and absf(surface.globe.longitude-float(before_ll[1]))<1e-10,"Model117 rebase uses physical ship direction")
	check(surface.begin_ascent(ship),"Model117 native gravity permits safe manual ascent")
	ship.position.y=surface.height_at(0,0)+Link.ALTITUDE-0.2;ship.velocity=Vector3.ZERO
	surface.step(0.01,ship,Vector2.ZERO,0.0)
	check(surface.ready_for_orbit and surface.leave(ship,world,0.0),"Nonspherical source surface reaches terrainrelative orbit")
	check(Link.valid(surface.orbit_link,world) and surface.orbit_link.revision==Link.SOURCE_REVISION,"Model117 link saves actual source height and pose")
	var restored:=Surface.new();var snapshot:Dictionary=JSON.parse_string(JSON.stringify(surface.snapshot()))
	check(restored.restore(snapshot,ship,world),"Model117 orbital link restores without fake spherical radius")
	check(restored.enter_from_orbit(ship,world,0.0) and absf(restored.altitude(ship)-1500.0)<0.1,"Model117 reentry uses same original terrainfield")
func prepared_entry_controls()->void:
	var f:=fixture(96)
	var world:RefCounted=f.world;var ship:RefCounted=f.ship;var surface:RefCounted=f.surface
	var before:=var_to_bytes(world.snapshot())
	var snapshot:=Surface.create_entry_snapshot(world,ship)
	check(not snapshot.is_empty() and snapshot.site.model_index==96,"Main-thread entry snapshot contains only copied source descriptors/shipradii")
	var worker:=Thread.new();check(worker.start(Surface.prepare_entry.bind(snapshot))==OK,"Actual isolated source96entry preparation launches on worker")
	var bundle:Variant=worker.wait_to_finish()
	check(bundle is Dictionary and bundle.get("ok",false),"Worker creates complete source96terrain/controller/collider")
	check(before==var_to_bytes(world.snapshot()) and not surface.active and surface.globe==null,"Worker never mutates World or live Surface")
	if not bundle is Dictionary or not bundle.get("ok",false):return
	var previous_site:=str(world.site_id);world.site_id=""
	check(not surface.install_prepared_entry(bundle,world,ship) and not surface.active and surface.globe==null,"Stale site preparation rejects without partial entry")
	world.site_id=previous_site
	var previous_ship:=str(ship.ship_id);ship.ship_id="viper"
	check(not surface.install_prepared_entry(bundle,world,ship),"Stale ship geometry rejects prepared entry")
	ship.ship_id=previous_ship
	check(surface.install_prepared_entry(bundle,world,ship) and surface.has_prepared_entry(world,ship),"Matching immutable sourceentry bundle installs as one-use candidate")
	check(surface.enter(ship,world,true) and surface.globe==bundle.globe and surface.underground==bundle.underground,"Entry consumes worker-prepared exact objects instead of synchronous recompilation")
	check(not surface.has_prepared_entry(),"Prepared entry consumed once")
	# Cold orbit preview of96 also prepares on an isolated worker, retaining
	# global planet rendering until its complete real city geometry is ready.
	var near:=Near.new();var orbit_surface:=Surface.new()
	var ll:Array=[surface.globe.latitude,surface.globe.longitude]
	var ground_radius:float=surface.globe.radius+surface.globe.elevation(ll[0],ll[1])
	ship.position=world.local_meters(world.focus_id,0.0)+world.body_rotation_basis(world.focus_id,0.0)*Link.direction(ll[0],ll[1])*(ground_radius+20000.0)
	check(not near.update(orbit_surface,ship,world,0.0) and near._preview_worker!=null,"Cold model96preview requests complete geometry off main thread")
	near.finish_preparation()
	check(near.update(orbit_surface,ship,world,0.0) and near.drawing.underground!=null,"Complete worker96preview uses paired actual city/collider")
