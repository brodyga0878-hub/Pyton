extends SceneTree
const Probe=preload("res://scripts/source_contact_alignment_probe.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const ContactTerrain=preload("res://scripts/source_contact_surface_terrain.gd")
const Field=preload("res://scripts/source_terrain_contact_field.gd")
const Frame=preload("res://scripts/source_surface_render_state.gd")
const Patch=preload("res://scripts/source_surface_contact_patch.gd")
const Packet=preload("res://scripts/source_surface_render_packet.gd")
const Flight=preload("res://scripts/flight_model.gd")
const World=preload("res://scripts/planetary_system.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const Navigation=preload("res://scripts/navigation.gd")
const Units=preload("res://scripts/source_units.gd")
const REPORT:="res://build/current-test-reports/source-contact-alignment-probe.json"
class FixtureWorld extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=44341016
class ObservedSurface extends "res://scripts/surface_model.gd":
	var height_calls:=0
	var snapshot_calls:=0
	var clearance_calls:=0
	func height_at(x:float,z:float)->float:height_calls+=1;return super.height_at(x,z)
	func snapshot()->Dictionary:snapshot_calls+=1;return super.snapshot()
	func clearance(ship:RefCounted)->float:clearance_calls+=1;return super.clearance(ship)
var checks:=0
var failures:=0
var evidence:Array=[]
var fixture_records:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func plain(value:Variant)->bool:
	if value is Dictionary:
		for key:Variant in value:
			if not key is String or not plain(value[key]):return false
		return true
	if value is Array:
		for item:Variant in value:
			if not plain(item):return false
		return true
	return value==null or value is bool or value is String or value is int or (value is float and is_finite(value))
func provider_state(surface:RefCounted)->Variant:
	var provider:RefCounted=surface.source_render_state
	if provider==null:return null
	if provider.get_script()==Frame:
		var result:Dictionary={}
		for key:String in Probe.FRAME_FIELDS+["_record","_target_lat","_target_lon","_transform","_inverse","_queries","_last_cells","_last_triangles","_maximum_cells"]:result[key]=provider.get(key)
		return result
	if provider.get_script()==Patch:
		var result:Dictionary={}
		for key:String in ["configured_ok","source_key","validation_samples","_patch","_frame","_points","_record","_target_lat","_target_lon","_transform","_inverse"]:result[key]=provider.get(key)
		return result
	return {"instance_id":provider.get_instance_id()}
func protected_state(surface:RefCounted,ship:RefCounted,world:RefCounted=null,nav:RefCounted=null)->PackedByteArray:
	var value:Array=[ship.snapshot(),surface.active,surface.landed,surface.landing,surface.taking_off,surface.body_id,surface.frame_index,surface.message,surface.pending_source_contact(),surface.height_calls,surface.snapshot_calls,surface.clearance_calls,surface.globe.capture_worker_state(),surface.globe.cache_stats(),provider_state(surface)]
	if world!=null:value.append([world.snapshot(),world.bodies,world.settlements,world.body_spin_by_id,world.native_evaluation_count,world._native_cache_tick,world._native_cache_day,world._native_positions_raw,world._native_relative_raw])
	if nav!=null:value.append(nav.snapshot())
	return var_to_bytes(value)
func contract(result:Dictionary)->void:
	check(result.get("diagnostic_only")==true and result.get("response_applied")==false and result.get("live_collision_classifier_changed")==false,"Explicit alignment comparison has no live response or collision-route authority")
	check(result.get("interpolated_points_certified")==false and result.get("positive_player_classification_executed")==false and result.get("source_object_bank_present")==false,"A radial certificate cannot certify an interpolated triangle or positive-player/live-bank dispatch")
	check(plain(result) and JSON.parse_string(JSON.stringify(result)) is Dictionary,"Comparison diagnostics contain only finite JSON primitives")
	check(not result.has("body_after") and not result.has("parent_after") and not result.has("damage_calls") and not result.has("landing_accepted"),"Readonly comparison exposes neither raw object mutations nor landing/damage commands")
func surface_for(globe:RefCounted,id:String)->RefCounted:
	var surface:=ObservedSurface.new();surface.active=true;surface.globe=globe;surface.body_id=id;surface.frame_index=7;surface._source_days=0.375;return surface
func fixture_globe(contact:bool)->RefCounted:
	var record:PackedByteArray=fixture_records[120];var world:=FixtureWorld.new();world.by_id.body={"runtime_record_hex":record.hex_encode(),"radius_km":1.0}
	var globe:RefCounted=ContactTerrain.new() if contact else Terrain.new()
	globe.configure(world,"body","")
	return globe
func place(surface:RefCounted,ship:RefCounted,x:=19.53125,z:=21.875)->void:
	ship.position=Vector3(x,surface.height_at(x,z)+7.88+2.0,z);ship.velocity=Vector3(0,-0.5,0);ship.attitude=Quaternion.IDENTITY;ship.target_speed=10.0
func assert_query(surface:RefCounted,ship:RefCounted,label:String,world:RefCounted=null,nav:RefCounted=null)->Dictionary:
	var before:=protected_state(surface,ship,world,nav);var result:=Probe.sample(surface,ship);contract(result)
	check(result.get("ok",false),"A valid current source surface supplies an explicit signed-field comparison: "+label)
	check(protected_state(surface,ship,world,nav)==before,"The original terrain cache, provider query counters, ship, HP/RNG, fuel, clocks and source World remain unchanged: "+label)
	if not result.get("ok",false):return result
	check(result.get("terrain_revision")==surface.globe.revision and result.get("body_id")==surface.body_id and result.get("parent_uid_u32")==int(surface.globe.source_record.decode_u32(4)),"Exact source UID/body/revision identify the observed data: "+label)
	check(is_finite(float(result.source_root_height_m)) and is_finite(float(result.visible_height_m)) and is_finite(float(result.delta_m)) and result.source_raw_to_metres==Units.METRES_PER_RAW,"Visible and certified-root heights share the actual source radial unit/reference contract: "+label)
	check(result.sampled_radial_point_certified and result.source_root_status in ["exact_zero","adjacent_sign_boundary"] and int(result.query_count)>=1 and int(result.query_count)<=Field.MAX_FIELD_QUERIES,"Source root is actually certified within the bounded isolated field budget: "+label)
	check(str(result.source_root_position_s64_hex).length()==48 and str(result.source_residual_s64_hex).length()==16 and str(result.context_binding_sha256).length()==64,"Raw source certificate and query-context binding retain exact source bits: "+label)
	check(result.query_context.ship_position_local_m==[float(ship.position.x),float(ship.position.y),float(ship.position.z)] and result.query_context.frame_index==surface.frame_index and result.query_context.source_elapsed_days==surface._source_days,"The result is explicitly bound to the observed pose/frame/time rather than an implicitly current state: "+label)
	var again:=Probe.sample(surface,ship);check(again==result and protected_state(surface,ship,world,nav)==before,"Identical explicit observations are deterministic without live mutation: "+label)
	evidence.append({"case":label,"probe":result})
	return result
func fallback_and_snapshot_binding()->void:
	for contact:bool in [false,true]:
		var globe:=fixture_globe(contact);check(globe.configured_ok,"Model120 fixture configures its explicit terrain revision")
		var surface:=surface_for(globe,"fixture120");var ship:=Flight.new();ship.hull=37.625;place(surface,ship)
		var result:=assert_query(surface,ship,"fixture120/"+("v5" if contact else "v4")+"/fallback")
		if not result.get("ok",false):continue
		check(result.visible_provider_kind=="diagonal_grid_fallback","Missing published geometry uses the actual production diagonal-grid fallback on a clone")
		var saved:Dictionary=result.duplicate(true);ship.position.x+=1.0;surface.frame_index+=1
		var newer:=Probe.sample(surface,ship)
		check(newer.get("ok",false) and newer.context_binding_sha256!=saved.context_binding_sha256 and saved.query_context.frame_index==7,"Moving flight cannot make an earlier comparison look like a current result")
		result.query_context.body_id="caller edit";result.source_direction_q31=[]
		check(Probe.sample(surface,ship)==newer,"Caller edits to returned JSON cannot alter future isolated comparisons")
func saved_provider(contact:bool)->void:
	var globe:=fixture_globe(contact);var step:=4000.0/64.0;var vertices:Array=[]
	for point in [Vector2.ZERO,Vector2(step,0),Vector2(0,step)]:vertices.append(Vector3(point.x,globe.raw_height(point.x,point.y),point.y))
	var frame:={"latitude":globe.latitude,"longitude":globe.longitude,"radius":globe.radius,"record_hash":Frame._sha(globe.source_record),"terrain_revision":globe.revision,"record_domain":Frame.RECORD_DOMAIN}
	var patch:=Patch.seal_capture(frame,4000.0,64,Vector2.ZERO,Vector2i(32,32),0,vertices,globe);var provider:=Patch.new()
	check(provider.configure(JSON.parse_string(JSON.stringify(patch)),globe),"Saved provider independently validates allthree source vertices for explicit revision")
	var surface:=surface_for(globe,"saved120");surface.source_render_state=provider;var ship:=Flight.new();place(surface,ship)
	var result:=assert_query(surface,ship,"fixture120/"+("v5" if contact else "v4")+"/saved")
	if result.get("ok",false):check(result.visible_provider_kind=="verified_saved_contact_triangle" and result.query_context.visible_provider_geometry_sha256.length()==64,"Saved triangle height comes from a validated private copy, retaining its geometry binding")
func published_provider(contact:bool)->void:
	var globe:=fixture_globe(contact);var packet:=Packet.prepare(globe,{"core_width":128.0,"core_cells":2,"include_rings":false});var provider:=Frame.new()
	check(provider.configure(packet),"A small actual production packet configures the published-core provider")
	var surface:=surface_for(globe,"published120");surface.source_render_state=provider;var ship:=Flight.new();place(surface,ship,8,12)
	var result:=assert_query(surface,ship,"fixture120/"+("v5" if contact else "v4")+"/published")
	if result.get("ok",false):check(result.visible_provider_kind=="published_core_triangles","Published triangle height uses a private geometry copy without incrementing original ray-query counters")
func actual_world()->void:
	var galaxy:=Galaxy.new();check(galaxy.configure_native(),"Actual source galaxy metadata configures the independent real-world fixture")
	var world:=World.new();world.configure(galaxy.get_system(World.SOL_ID),World.FULL_LAYOUT)
	var ship:=Flight.new();ship.hull=37.625;var nav:=Navigation.new();check(nav.configure_source("cobra") and nav.sync_source_ship(ship) and nav.bind_thermal_ship(ship),"Actual source fuel/HP session binds the fractional visible hull")
	for id:String in ["earth","mercury"]:
		world.focus_id=id;world.site_id=""
		for contact:bool in [false,true]:
			var globe:RefCounted=ContactTerrain.new() if contact else Terrain.new();globe.configure(world,id,"")
			check(globe.configured_ok,"Actual source body supplies its original record and explicit surface revision")
			var surface:=surface_for(globe,id);place(surface,ship,8,12);assert_query(surface,ship,"actualWorld/"+id+("/v5" if contact else "/v4"),world,nav)
func guards()->void:
	var globe:=fixture_globe(false);var surface:=surface_for(globe,"guards");var ship:=Flight.new();place(surface,ship)
	var before:=protected_state(surface,ship)
	for result:Dictionary in [Probe.sample(null,ship),Probe.sample(surface,null)]:contract(result);check(not result.ok,"Missing lifecycle context rejects explicitly")
	surface.active=false;check(Probe.sample(surface,ship).reason=="no_active_source_surface","Inactive surfaces do not trigger source-field work");surface.active=true
	var position:Vector3=ship.position;ship.position.x=NAN;check(not Probe.sample(surface,ship).ok,"Nonfinite ship pose rejects before cloning/querying");ship.position=position
	surface.source_render_state=RefCounted.new();check(Probe.sample(surface,ship).reason=="unsupported_visible_provider_type","Unknown provider implementations reject instead of guessing a visible surface");surface.source_render_state=null
	var revision:String=globe.revision;globe.revision="sphere-source-cities-v3";check(Probe.sample(surface,ship).reason=="unsupported_source_surface","Legacy terrain cannot be silently upgraded by a diagnostic command");globe.revision=revision
	check(protected_state(surface,ship)==before,"All rejected diagnostic contexts leave observed game/provider/cache data unchanged")
func run()->void:
	var sources:Dictionary={}
	for path:String in ["scripts/source_contact_alignment_probe.gd","scripts/source_terrain_contact_field.gd","scripts/source_contact_surface_terrain.gd","scripts/source_surface_terrain.gd","scripts/source_surface_contact_patch.gd","scripts/source_surface_render_state.gd","scripts/source_surface_render_packet.gd","scripts/surface_model.gd","scripts/source_units.gd","tests/test_source_contact_alignment_probe.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"))
	for row:Dictionary in fixture.cases:
		if not fixture_records.has(int(row.parent_model)):fixture_records[int(row.parent_model)]=str(row.parent_record_hex).hex_decode()
	fallback_and_snapshot_binding();saved_provider(false);saved_provider(true);published_provider(false);published_provider(true);actual_world();guards()
	for path:String in sources:check(FileAccess.get_sha256("res://"+path)==sources[path],"The explicit comparison suite leaves every pinned source file unchanged: "+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"sources":sources,"evidence":evidence,"scope":"Explicit user-command read-only source/render comparison. Isolated v4/v5 terrain, copied published/saved provider and actualWorldEarth/Mercury preserve live caches/provider counters, source World, fractionalHP/RNG, fuel, clock, frames and inputs. Certificates belong to sampled radial points, not arbitrary interpolation or positive-player/live collision dispatch. Small published packets are explicit CPU fixtures, not GPU or phone execution."},"\t"));file.close()
	print("SOURCE CONTACT ALIGNMENT PROBE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
