extends SceneTree
# Actual original World/ship records drive a diagnostic natural query only.
# Observer placements are explicit fixtures, not claims of a flown approach.
const Probe=preload("res://scripts/source_natural_contact_probe.gd")
const Bridge=preload("res://scripts/source_surface_contact_bridge.gd")
const World=preload("res://scripts/planetary_system.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const Navigation=preload("res://scripts/navigation.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Frame=preload("res://scripts/source_surface_render_state.gd")
const Patch=preload("res://scripts/source_surface_contact_patch.gd")
const REPORT:="res://validation/natural-2026-11-13/source-natural-contact-probe.json"
class ObservedSurface extends "res://scripts/surface_model.gd":
	var height_calls:=0
	var clearance_calls:=0
	func height_at(x:float,z:float)->float:height_calls+=1;return super.height_at(x,z)
	func clearance(ship:RefCounted)->float:clearance_calls+=1;return super.clearance(ship)
var checks:=0
var failures:=0
var evidence:Array=[]
var world:RefCounted
var ship:RefCounted
var nav:RefCounted
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func source_world(ship_id:="cobra")->void:
	var galaxy:=Galaxy.new();check(galaxy.configure_native(),"Original galaxy metadata configures the actual source-world fixture")
	world=World.new();world.configure(galaxy.get_system(World.SOL_ID),World.FULL_LAYOUT);ship=Flight.new();ship.ship_id=ship_id;ship.hull=37.625;ship.goods.clear() # Explicit empty-cargo fixture also fits the bare4t Shuttle.
	nav=Navigation.new();check(nav.configure_source(ship_id) and nav.sync_source_ship(ship) and nav.bind_thermal_ship(ship),"Actual independent fuel/HP session binds the selected source ship and fractional hull")
	check(world.layout_mode==World.FULL_LAYOUT,"Actual full original Sol world is available")
func protected_state()->PackedByteArray:
	return var_to_bytes([world.snapshot(),world.native_evaluation_count,world.get("_native_cache_tick"),world.get("_native_cache_day"),world.get("_native_positions_raw"),world.get("_native_relative_raw"),world.body_spin_by_id,world.bodies,world.settlements,world.source_runtime_state,nav.snapshot(),ship.snapshot()])
func plain(value:Variant)->bool:
	if value is Dictionary:
		for key:Variant in value:
			if not key is String or not plain(value[key]):return false
		return true
	if value is Array:
		for item:Variant in value:
			if not plain(item):return false
		return true
	return value==null or value is String or value is bool or value is int or (value is float and is_finite(value))
func contract(result:Dictionary)->void:
	check(result.get("diagnostic_only")==true and result.get("response_applied")==false and result.get("live_collision_classifier_changed")==false,"Natural query explicitly remains read-only and cannot replace live collision response")
	check(result.get("full_F569",false)==false and result.get("source_object_bank_present",false)==false,"Bounded natural diagnostics cannot claim original object-bank scanning")
	check(plain(result) and JSON.parse_string(JSON.stringify(result)) is Dictionary,"Compact natural diagnostic facts contain only finite JSON primitives")
	check(not result.has("damage_calls") and not result.has("body_after") and not result.has("parent_after") and not result.has("landing_accepted"),"Diagnostics expose neither mutable raw source objects nor response commands")
func actual_space_queries()->void:
	for pair:Array in [["eagle",24,0],["cobra",38,2],["shuttle",15,1]]:
		source_world(pair[0])
		for body_id:String in ["earth","mercury","star"]:
			world.focus_id=body_id;world.site_id="";var body:Dictionary=world.by_id[body_id];var days:=0.25;var centre:Vector3=world.local_meters(body_id,days)
			var radii:=Bridge.descriptor_radii(Bridge.model_descriptor(int(body.model_index)))
			check(radii.get("ok",false),"Actual source descriptor supplies the explicit observer scale: "+body_id)
			if not radii.get("ok",false):continue
			ship.position=centre+Vector3.RIGHT*(float(radii.outer_raw)*Bridge.Units.METRES_PER_RAW*4.0);ship.velocity=Vector3.ZERO;ship.attitude=Quaternion.IDENTITY
			var before:=protected_state();var result:=Probe.sample(world,ship,null,days);contract(result)
			check(result.get("ok",false) and result.get("return_s32")==-1,"Actual F576 returns no hit for the explicit far observer: "+str(pair[0])+" / "+body_id)
			if not result.get("ok",false):continue
			check(result.get("body_model_index")==pair[1] and result.get("parent_model_index")==int(body.model_index),"Readonly adapter uses the actual selected ship and natural-parent models")
			var original:=str(body.runtime_record_hex).hex_decode()
			check(result.get("parent_uid_u32")==int(original.decode_u32(4)) and str(result.get("parent_uid_hex","")).length()==8,"Terrain seed is the real original parent UID rather than zero-filled object memory")
			check(result.get("query_iteration_count")==int(pair[2])+1 and result.get("child_probe_count")==pair[2] and result.get("terrain_query_calls")==0,"Far no-hit traverses every actual player child volume without entering F1876")
			check(str(result.get("relative_position_s64_hex","")).length()==48 and str(result.get("altitude_s64_hex","")).length()==16,"Exact raw coordinates and altitude words survive compact JSON serialization")
			check(protected_state()==before,"Copied ephemeris/spin and natural-query operands preserve all live World cache words, HP/RNG, fuel and clocks")
			var second:=Probe.sample(world,ship,null,days);check(second==result and protected_state()==before,"Repeated natural observations are deterministic and have no live side effects")
			evidence.append({"case":"actual_far_natural_observer","ship":pair[0],"body_id":body_id,"probe":result,"world_and_game_unchanged":protected_state()==before})
func saved_source_patch_and_no_provider_query()->void:
	source_world();world.focus_id="earth";world.site_id="";var globe:=Terrain.new();globe.configure(world,"earth","")
	check(globe.configured_ok,"Actual original Earth terrain supplies the surface frame")
	var cell:=4000.0/64.0;var vertices:Array=[Vector3(0,globe.raw_height(0,0),0),Vector3(cell,globe.raw_height(cell,0),0),Vector3(0,globe.raw_height(0,cell),cell)]
	var frame:={"latitude":globe.latitude,"longitude":globe.longitude,"radius":globe.radius,"record_hash":Frame._sha(globe.source_record),"terrain_revision":Terrain.REVISION_NAME,"record_domain":Frame.RECORD_DOMAIN}
	var capture:=Patch.seal_capture(frame,4000,64,Vector2.ZERO,Vector2i(32,32),0,vertices,globe);var verified:=Patch.new()
	check(verified.configure(capture,globe) and verified.validation_samples==3,"Actual saved contact patch independently validates its three source vertices")
	var surface:=ObservedSurface.new();surface.active=true;surface.globe=globe;surface.body_id="earth";surface.source_render_state=verified
	ship.position=Vector3(8,surface.height_at(8,12)+surface.clearance(ship)-0.025,12);ship.velocity=Vector3(0,-0.01,0);ship.attitude=Quaternion.IDENTITY
	var before_contact:=Bridge.resolve(surface,ship,65535);check(before_contact.ok,"Unchanged provider-based contact bridge resolves the actual saved triangle fixture")
	var before:=protected_state();var heights:int=surface.height_calls;var clearances:int=surface.clearance_calls;var cache:=var_to_bytes(globe.cache_stats())
	var result:=Probe.sample(world,ship,surface,0.0);var probe_heights:=surface.height_calls-heights;var probe_clearances:=surface.clearance_calls-clearances;contract(result)
	check(result.get("ok",false) and result.get("origin_policy")=="phone-authored-centre-no-ground-offset-v1","Natural diagnostics sample the authored centre without the old provider-clearance origin correction")
	check(surface.height_calls==heights and surface.clearance_calls==clearances and var_to_bytes(globe.cache_stats())==cache,"Diagnostic F1876 owns isolated resources and never queries or changes the live height/AGL/provider cache")
	check(protected_state()==before and surface.source_render_state==verified and not surface.landed,"The actual saved patch, flight and landing state remain unchanged")
	var after_contact:=Bridge.resolve(surface,ship,65535)
	check(after_contact.ok and before_contact.kernel.body_after==after_contact.kernel.body_after and before_contact.damage_calls==after_contact.damage_calls and before_contact.position==after_contact.position and before_contact.velocity==after_contact.velocity,"Natural diagnostics cannot alter the existing live kind1 response, raw output, damage or placement")
	var first:=result.duplicate(true);result["reason"]="caller edit";result["query_trace"]=[]
	check(Probe.sample(world,ship,surface,0.0)==first,"Caller edits to compact diagnostic facts cannot modify subsequent classification")
	evidence.append({"case":"actual_saved_patch_unchanged","probe":first,"verified_vertices":verified.validation_samples,"probe_height_calls":probe_heights,"probe_clearance_calls":probe_clearances,"old_contact_raw_unchanged":before_contact.kernel.body_after==after_contact.kernel.body_after})
func guards()->void:
	var before:=protected_state();check(not Probe.sample(null,ship,null,0).ok and not Probe.sample(world,ship,null,NAN).ok,"Invalid world/time context returns an explicit rejected diagnostic")
	var layout:String=world.layout_mode;world.layout_mode=World.SOLAR_LAYOUT;var result:=Probe.sample(world,ship,null,0);world.layout_mode=layout
	check(not result.ok and result.reason=="outside_source_world" and protected_state()==before,"Legacy layout cannot be upgraded implicitly by natural diagnostics")
	var id:String=ship.ship_id;ship.ship_id="invented";result=Probe.sample(world,ship,null,0);ship.ship_id=id
	check(not result.ok and protected_state()==before,"Unsupported authored ships reject without changing live objects")
	check(FileAccess.get_sha256("res://scripts/source_surface_contact_bridge.gd")=="f83bbecc35c60bfaf79cf2314d067f997b966258665a41a93f082534ba7dfdd9","Published0.19 live contact bridge remains byte-for-byte unchanged")
func run()->void:
	actual_space_queries();saved_source_patch_and_no_provider_query();guards()
	var sources:Dictionary={}
	for path:String in ["scripts/source_natural_contact.gd","scripts/source_natural_contact_probe.gd","scripts/source_surface_contact_bridge.gd","tests/test_source_natural_contact_probe.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"status":"passed" if failures==0 else "failed","checks":checks,"failures":failures,"evidence":evidence,"sources":sources,"scope":"Actual original World operands for all three authored source ships and Earth/Mercury/star, actual saved source contact patch, copied ephemeris/spin and exact live-state isolation. F576 is observed read-only; no live response, physical Android or complete source object-bank parity is claimed."},"\t"));file.close()
	print("NATURAL PROBE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
