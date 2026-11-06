extends SceneTree
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Legacy=preload("res://scripts/spherical_terrain.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
class FakeSystem extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=44341016
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func _init()->void:call_deferred("run")
func system_for(record:PackedByteArray)->FakeSystem:
	var system:=FakeSystem.new();system.by_id.body={"runtime_record_hex":record.hex_encode(),"radius_km":1.0};return system
func ints(values:Variant)->PackedInt64Array:
	var result:=PackedInt64Array()
	for value in values:result.append(int(value))
	return result
func run()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"))
	cold_thread_controls(fixture.cases[0])
	var seen:Dictionary={};var checked_anchors:=0
	for row:Dictionary in fixture.cases:
		var record:=str(row.parent_record_hex).hex_decode();var model:=int(row.parent_model)
		if not seen.has(model):
			seen[model]=true
			var metadata:=Terrain.geometry_metadata(record)
			check(Terrain.supported_model(record) and metadata.model_index==model,"Source model domain "+str(model))
			check(Terrain.reference_radius(record)>0,"Physical source static reference "+str(model))
			check(metadata.boundary_policy==(Terrain.BOUNDARY_POLICY if model==117 else "source_descriptor_bounds_v1"),"Explicit117callerpolicy")
			var terrain:=Terrain.new();terrain.configure(system_for(record),"body","")
			check(terrain.configured_ok and terrain.revision==Terrain.REVISION_NAME,"Configure new revision "+str(model))
			for ll in [[0.31,0.42],[-0.6,-1.1],[0.0,0.0],[PI*0.5,0.0],[-PI*0.5,0.0]]:
				var sample:=terrain.exact_source_sample(ll[0],ll[1])
				check(not sample.is_empty() and is_finite(float(sample.get("elevation_m",NAN))),"Continuous source direction "+str(model)+str(ll))
			if model==129:check(terrain.radius==7049700.0,"Earth reference is actual source axes, not modern catalogue radius")
			terrain.latitude=0.31;terrain.longitude=0.42
			var mapped_height:=terrain.raw_height(400.0,-300.0)
			var mapped_ll:=terrain.coordinates_at_height(400.0,-300.0,mapped_height)
			var projected:=terrain.project(mapped_ll[0],mapped_ll[1])
			check(projected.distance_to(Vector2(400.0,-300.0))<0.02,"True tangent projection and source surface inverse "+str(model))
			var mapped_radius:=sqrt(400.0*400.0+300.0*300.0+pow(terrain.radius+mapped_height,2))
			check(absf(mapped_radius-terrain.radius-terrain.elevation(mapped_ll[0],mapped_ll[1]))<0.02,"Rendered tangent point lies on shared radial source field "+str(model))
		if model!=117 and int(row.graphics_level)==Terrain.SOURCE_DETAIL:
			var terrain:=Terrain.new();terrain.configure(system_for(record),"body","")
			var matrix:=Ground.matrix_q31(int(row.phase_u16),int(row.inclination_u16))
			var actual:=terrain.exact_source_direction(PackedInt64Array([matrix[3],matrix[4],matrix[5]]))
			check(not actual.is_empty() and actual.position_raw==ints(row.expected.position_raw),"Continuous direction adapter agrees native F879 "+str(model)+":"+str(row.angle_case))
		if int(row.angle_case)==0 and int(row.graphics_level)==1 and str(row.origin).begins_with("original handcrafted"):
			var port:=str(row.port_record_hex).hex_decode()
			var site:={"id":"port","parent":"body","model_index":int(row.port_model),"type_code":35,"original_index":int(row.local_index),"source_seed":int(port.decode_u32(4)),"ground_phase_u16":int(port.decode_u16(18)),"ground_inclination_u16":int(port.decode_u16(34)),"runtime_record_hex":port.hex_encode()}
			var profile:=Terrain.source_city_profile(site,record,Terrain.reference_radius(record))
			check(not profile.is_empty() and profile.source_root_raw==ints(row.expected.position_raw),"Exact source city anchor "+str(row.local_index))
			if not profile.is_empty():
				var system:=system_for(record);system.settlements=[site]
				var terrain:=Terrain.new();terrain.configure(system,"body","port")
				check(terrain.configured_ok and terrain.city_profiles.has("port"),"Source city configured")
				check(absf(terrain.elevation(profile.root_latitude,profile.root_longitude)-profile.root_elevation_m)<0.001,"Render/collision city plane at exact source root")
				check(absf(terrain.raw_height(0,0)-terrain.sample(0,0)[0])<1e-9,"Shared mesh and physics height")
				checked_anchors+=1
	check(seen.size()==17 and checked_anchors==21,"All17naturalmodels and21actualgroundports")
	corrected_117_controls()
	cache_controls(str(fixture.cases[0].parent_record_hex).hex_decode())
	check(not Terrain.supported_model(PackedByteArray()) and Terrain.reference_radius(PackedByteArray())==0.0,"Reject missing raw record")
	check(not Legacy.supports_revision(Terrain.REVISION_NAME) and Legacy.CURRENT_REVISION=="sphere-source-cities-v3","Legacy revision acceptance unchanged")
	print("SOURCE SURFACE TERRAIN TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func cache_controls(record:PackedByteArray)->void:
	var terrain:=Terrain.new();terrain.configure(system_for(record),"body","")
	var a:=terrain.elevation(0.31,0.42);var first:=terrain.cache_stats()
	var b:=terrain.elevation(0.31,0.42);var second:=terrain.cache_stats()
	check(a==b and first.entries==4 and second.source_samples==first.source_samples and second.hits==first.hits+4,"Repeated physics queries reuse four shared grid nodes")
	var patch:=terrain.prepare_patch(0.31,0.42,1024.0)
	check(not patch.is_empty() and patch.nodes.size()>4,"Prepare worker-owned geographic cache patch")
	var other:=Terrain.new();other.configure(system_for(record),"body","")
	check(other.install_patch(patch) and other.elevation(0.31,0.42)==a,"Prepared patch installs matching source body atomically")
	var malformed:=patch.duplicate(true);malformed.nodes["wrong"]=0.0
	var before:=other.cache_stats()
	check(not other.install_patch(malformed) and other.cache_stats().entries==before.entries,"Malformed cache rejected without partial mutation")
	malformed=patch.duplicate(true);malformed.record_hex="different"
	check(not other.install_patch(malformed),"Reject other-body cache transfer")
	var state:=terrain.capture_worker_state();var clone:=Terrain.from_worker_state(state)
	check(clone!=null and clone.elevation(0.31,0.42)==a,"Immutable state creates independent warmed source sampler")
	if clone!=null:
		clone.clear_cache();check(terrain.cache_stats().entries>0 and clone.cache_stats().entries==0,"Worker source cache never shares live mutation")
	state.radius=1.0;check(Terrain.from_worker_state(state)==null,"Worker snapshot rejects mismatched source reference")
	var edge_a:=terrain.elevation(0.2,-PI);var edge_b:=terrain.elevation(0.2,PI)
	check(edge_a==edge_b,"Geographic grid seam wraps consistently")
	check(is_nan(terrain.elevation(NAN,0.0)) and terrain.exact_source_sample(INF,0.0).is_empty(),"Invalid directions rejected")
	terrain.clear_cache();check(terrain.cache_stats().entries==0,"Bounded cache clears publicly")
func corrected_117_controls()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_model117_surface_policy_native.json"))
	check(fixture.case_count==312 and fixture.corrected_probe_case_count==156 and fixture.unguarded_boundary_rejection_count==24,"Independent native corrected117andboundary controls")
	check(fixture.boundary_policy==Terrain.BOUNDARY_POLICY and fixture.all_corrected_controls_outside_terrain_kind255,"Corrected caller policy provenance")
	for field in ["observation_matches_untouched_objects_and_query","parent_bank_unchanged","object_canaries_unchanged"]:check(fixture[field]==true,"Corrected native memory proof "+field)
	var kernel:=Ground.new()
	for row:Dictionary in fixture.cases:
		var expected:Dictionary=row.expected.passes[0]
		var actual:=kernel.height_raw(str(row.expected.initialized_port_hex).hex_decode(),str(row.expected.initialized_parent_hex).hex_decode(),ints(row.point_input_raw),int(row.graphics_level))
		check(not actual.is_empty() and actual.height_s32==int(expected.height_s32) and actual.globals.collision_kind_u8==int(expected.collision_kind_u8),"Native corrected117F574andunguardedboundary "+str(row.direction_integer)+str(row.probe_kind))
		if str(row.probe_kind)!="corrected_outside_probe" or int(row.graphics_level)!=Terrain.SOURCE_DETAIL:continue
		var record:=str(row.parent_record_hex).hex_decode()
		var terrain:=Terrain.new();terrain.configure(system_for(record),"body","")
		var result:=terrain.exact_source_direction(ints(row.radial_q31))
		check(not result.is_empty() and result.position_raw==ints(row.expected.caller_derived_surface_point_raw),"Native model117sourcefield radial adapter "+str(row.direction_integer))
		if not result.is_empty():
			check(result.passes[0].height_s32==int(expected.height_s32),"Native model117altitude shared withlive adapter")
		check(terrain.source_policy.original_outer_bound_raw<terrain.source_policy.reference_radius_raw and terrain.source_policy.exterior_probe_guard_raw==181760,"Original nonsphericalboundandnew callerboundseparate")
func _thread_patch(system:RefCounted)->Dictionary:
	var terrain:=Terrain.new();terrain.configure(system,"body","port")
	if not terrain.configured_ok:return {}
	return {"height":terrain.elevation(0.31,0.42),"patch":terrain.prepare_patch(0.31,0.42,512.0),"stats":terrain.cache_stats()}
func cold_thread_controls(row:Dictionary)->void:
	var record:=str(row.parent_record_hex).hex_decode();var port:=str(row.port_record_hex).hex_decode()
	var system:=system_for(record)
	system.settlements=[{"id":"port","parent":"body","model_index":int(row.port_model),"type_code":35,"original_index":int(row.local_index),"source_seed":int(port.decode_u32(4)),"ground_phase_u16":int(port.decode_u16(18)),"ground_inclination_u16":int(port.decode_u16(34)),"runtime_record_hex":port.hex_encode()}]
	var first:=Thread.new();var second:=Thread.new()
	check(first.start(_thread_patch.bind(system))==OK and second.start(_thread_patch.bind(system))==OK,"Two independent cold source workers launch")
	var main_result:=_thread_patch(system)
	var a:Variant=first.wait_to_finish();var b:Variant=second.wait_to_finish()
	check(a is Dictionary and b is Dictionary and not a.is_empty() and not b.is_empty(),"Cold static resources publish safely across actual workers")
	if not a is Dictionary or not b is Dictionary or a.is_empty() or b.is_empty():return
	check(a.height==b.height and a.height==main_result.height and a.patch.nodes==b.patch.nodes,"Independent threaded patches preserve exact source heights")
	var terrain:=Terrain.new();terrain.configure(system,"body","port")
	check(terrain.install_patch(a.patch) and terrain.elevation(0.31,0.42)==main_result.height,"Worker patch transfers to live sampler without sharing mutable kernel")
