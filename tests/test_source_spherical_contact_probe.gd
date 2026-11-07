extends SceneTree
# Actual source World/ship operands drive a diagnostic envelope query only.
# Observer placements are explicit fixtures; no physical sphere dispatch or
# new original-machine execution is claimed by these consumer controls.
const Probe=preload("res://scripts/source_spherical_contact_probe.gd")
const Sphere=preload("res://scripts/source_spherical_contact.gd")
const Bridge=preload("res://scripts/source_surface_contact_bridge.gd")
const World=preload("res://scripts/planetary_system.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const Navigation=preload("res://scripts/navigation.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Frame=preload("res://scripts/source_surface_render_state.gd")
const Patch=preload("res://scripts/source_surface_contact_patch.gd")
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
func source_world()->void:
	var galaxy:=Galaxy.new();check(galaxy.configure_native(),"Original galaxy metadata configures the actual source-world fixture")
	world=World.new();world.configure(galaxy.get_system(World.SOL_ID),World.FULL_LAYOUT);ship=Flight.new();ship.hull=37.625
	nav=Navigation.new();check(nav.configure_source("cobra") and nav.sync_source_ship(ship) and nav.bind_thermal_ship(ship),"Actual independent source fuel/HP session binds the retained fractional hull")
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
func routing_metadata()->void:
	var simple:Array=[]
	for index in range(149):
		var row:=Probe.model_routing(index)
		check(not row.is_empty() and int(row.model_index)==index,"New149-model collision prefix metadata has a runtime consumer: "+str(index))
		if index!=0 and row.initial_sphere_path_eligible:simple.append(index)
	check(simple==[1,2,3,4,5,6,7,8,9,10,11,12,13,101,102,104,105,109],"Exactly18 nonzero source models initialize a simple-sphere route")
	var zero:=Probe.model_routing(0)
	check(zero.model_zero_skips_F1533_descriptor_initialization and zero.initial_object_flags_14c_u8==null and zero.initial_sphere_path_eligible==null,"Model0 retains unknown actual initialization rather than inventing a sphere route")
	for index in range(117,149):check(not Probe.model_routing(index).initial_sphere_path_eligible,"Every actual natural terrain/gas/star model remains on original F576 routing")
	var row:=Probe.model_routing(120);row.initial_sphere_path_eligible=true
	check(not Probe.model_routing(120).initial_sphere_path_eligible and Probe.model_routing(-1).is_empty(),"Caller metadata edits cannot alter cached routing or create unsupported models")
func actual_space_queries()->void:
	source_world()
	for body_id:String in ["earth","mercury"]:
		world.focus_id=body_id;world.site_id="";var body:Dictionary=world.by_id[body_id];var centre:Vector3=world.local_meters(body_id,0.0)
		var rotation:Dictionary=Probe.FuelContact._basis_readonly(world,body,0.0);var radii:=Bridge.descriptor_radii(Bridge.model_descriptor(int(body.model_index)))
		for factor:float in [0.5,1.5]:
			# Explicit envelope observer, not a claim that it can be flown here
			# through the natural terrain or that F577 is this body's dispatcher.
			ship.position=centre+rotation.basis*Vector3(float(radii.outer_raw)*Bridge.Units.METRES_PER_RAW*factor,0,0)
			var before:=protected_state();var result:=Probe.sample(world,ship,null,0.25)
			check(result.ok and result.inside_sphere==(factor<1) and result.return_s32==(0 if factor<1 else -1),"Actual source descriptor sphere envelope has the original inside/outside return polarity: "+body_id)
			if not result.ok:continue
			check(result.envelope_only and not result.response_applied and not result.original_sphere_dispatch_eligible and not result.source_object_bank_present and not result.full_F569,"Actual natural world query explicitly remains a non-dispatch diagnostic")
			check(protected_state()==before,"Cache-miss/read-only ephemeris and copied spin preserve World snapshot, all cache words/counters, HP/RNG, fuel and clocks")
			check(result.altitude_semantics=="source-reconstructed-centre-distance-not-AGL" and result.altitude_written==(factor>1) and result.initial_altitude_policy=="isolated-zero-no-object-bank-history","Outside centre distance and unwritten inside altitude cannot be mistaken for terrain clearance")
			check(plain(result) and JSON.parse_string(JSON.stringify(result)) is Dictionary and result.relative_position_s64_hex.length()==48,"Diagnostic facts are JSON-safe and retain exact raw64 operands separately from previews")
			check(not result.has("damage_calls") and not result.has("position") and not result.has("landing_accepted") and not result.flags2_means_landing_hit,"Probe supplies no accidental response/pose/landing command")
			evidence.append({"case":"actual_source_space_envelope","body_id":body_id,"observer_radius_factor":factor,"parent_model":result.parent_model_index,"inside_sphere":result.inside_sphere,"return_s32":result.return_s32,"original_sphere_dispatch_eligible":result.original_sphere_dispatch_eligible,"altitude_written":result.altitude_written,"world_and_game_unchanged":protected_state()==before})
func saved_source_patch_and_no_height_query()->void:
	world.focus_id="earth";world.site_id="";var globe:=Terrain.new();globe.configure(world,"earth","")
	check(globe.configured_ok,"Actual original Earth terrain supplies the surface frame")
	var cell:=4000.0/64.0;var vertices:Array=[Vector3(0,globe.raw_height(0,0),0),Vector3(cell,globe.raw_height(cell,0),0),Vector3(0,globe.raw_height(0,cell),cell)]
	var frame:={"latitude":globe.latitude,"longitude":globe.longitude,"radius":globe.radius,"record_hash":Frame._sha(globe.source_record),"terrain_revision":Terrain.REVISION_NAME,"record_domain":Frame.RECORD_DOMAIN}
	var capture:=Patch.seal_capture(frame,4000,64,Vector2.ZERO,Vector2i(32,32),0,vertices,globe);var verified:=Patch.new()
	check(verified.configure(capture,globe) and verified.validation_samples==3,"Actual saved source contact patch validates all three original vertices")
	var surface:=ObservedSurface.new();surface.active=true;surface.globe=globe;surface.body_id="earth";surface.source_render_state=verified
	ship.position=Vector3(8,surface.height_at(8,12)+surface.clearance(ship)-0.025,12);ship.velocity=Vector3(0,-0.01,0);ship.attitude=Quaternion.IDENTITY
	var before_contact:=Bridge.resolve(surface,ship,65535);check(before_contact.ok,"Unchanged0.19 contact bridge resolves the real saved triangle fixture")
	var before:=protected_state();var heights:int=surface.height_calls;var clearances:int=surface.clearance_calls;var cache:=var_to_bytes(globe.cache_stats())
	var result:=Probe.sample(world,ship,surface,0.0)
	var probe_heights:int=surface.height_calls-heights;var probe_clearances:int=surface.clearance_calls-clearances
	check(result.ok and result.origin_policy=="phone-authored-centre-no-ground-offset-v1" and not result.terrain_provider_queried,"Surface envelope queries the authored ship centre without the0.19 ground-origin mapping")
	check(surface.height_calls==heights and surface.clearance_calls==clearances and var_to_bytes(globe.cache_stats())==cache,"Probe alone makes zero height/AGL/clearance/render-state/native-terrain queries")
	check(protected_state()==before and surface.source_render_state==verified and not surface.landed,"Actual saved triangle, game data and landing state remain unchanged")
	var after_contact:=Bridge.resolve(surface,ship,65535)
	check(after_contact.ok and before_contact.kernel.body_after==after_contact.kernel.body_after and before_contact.damage_calls==after_contact.damage_calls and before_contact.position==after_contact.position and before_contact.velocity==after_contact.velocity,"Readonly F577 envelope cannot change any0.19 kind1 contact response or original raw output")
	evidence.append({"case":"actual_saved_patch_unchanged","parent_model":result.get("parent_model_index",-1),"verified_vertices":verified.validation_samples,"probe_height_calls":probe_heights,"probe_clearance_calls":probe_clearances,"old_kind1_raw_output_unchanged":before_contact.kernel.body_after==after_contact.kernel.body_after,"original_sphere_dispatch_eligible":result.get("original_sphere_dispatch_eligible",false)})
func raw_boundary_controls()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_spherical_contact_native.json"));var chosen:Array=["dos-spherical-contact-0000","dos-spherical-contact-0046","dos-spherical-contact-0627","dos-spherical-contact-0628"]
	for row:Dictionary in fixture.cases:
		if row.id not in chosen:continue
		var context:Dictionary=row.context.duplicate(true)
		for key:String in ["relative_position_s64","absolute_position_s64"]:
			context[key]=[]
			for axis in range(3):context[key].append(str(row.context[key+"_hex"]).hex_decode().decode_s64(axis*8))
		context.globals.altitude_s64=str(row.context.globals.altitude_s64_hex).hex_decode().decode_s64(0)
		var body:=str(row.body_hex).hex_decode();var parent:=str(row.parent_hex).hex_decode();var result:=Sphere.classify(body,parent,context)
		check(result.ok and result.return_s32==int(row.expected.return_s32) and result.shift_s32==int(row.expected.shift_s32) and result.radius_s32==int(row.expected.radius_s32),"Consumer boundary control uses the already independent native raw result: "+row.id)
		if row.id=="dos-spherical-contact-0000":
			check(result.return_s32==0 and result.radius_s32==922746880 and int(fixture.jjffe_counterfactual_case.expected.return_s32)==-1 and int(fixture.jjffe_counterfactual_case.expected.radius_s32)==251658240,"Nonpositive DOS body-inner plus other-OUTER radius stays distinct from the separately proven JJFFE other-inner counterfactual")
		if row.id=="dos-spherical-contact-0046":check(result.return_s32==-1 and result.global_writes.has("altitude_s64") and (int(result.globals_after.collision_flags_u8)&2)!=0,"Exact raw sphere tangency is early return with flags/centre distance, never automatic landing or damage")
func guards()->void:
	var before:=protected_state();check(not Probe.sample(null,ship,null,0).ok and not Probe.sample(world,ship,null,NAN).ok,"Invalid world/time context rejects without a partial diagnostic")
	var layout:String=world.layout_mode;world.layout_mode=World.SOLAR_LAYOUT;var result:=Probe.sample(world,ship,null,0);world.layout_mode=layout
	check(not result.ok and result.reason=="outside_source_world" and protected_state()==before,"Legacy layout cannot be implicitly upgraded or supplied source sphere physics")
	check(FileAccess.get_sha256("res://scripts/source_surface_contact_bridge.gd")=="f83bbecc35c60bfaf79cf2314d067f997b966258665a41a93f082534ba7dfdd9","Frozen0.19 source contact bridge remains byte-for-byte unchanged")
func run()->void:
	routing_metadata();actual_space_queries();saved_source_patch_and_no_height_query();raw_boundary_controls();guards()
	print("SPHERICAL PROBE EVIDENCE: ",JSON.stringify(evidence))
	print("SPHERICAL PROBE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
