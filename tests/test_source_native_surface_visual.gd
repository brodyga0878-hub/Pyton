extends "res://tests/test_source_native_contact_geometry.gd"
# Actual original actor inputs and genuine sealed providers, not positive
# render mocks. Native instruction parity belongs to the producer suites.
const Visual=preload("res://scripts/source_native_surface_visual.gd")
const Provider=preload("res://scripts/source_native_surface_provider.gd")
const VISUAL_REPORT:="res://build/current-test-reports/source-native-surface-visual.json"
var visual:Node3D
var flight_camera:Camera3D
var provider:RefCounted
var actor_fixture:Dictionary={}
var fixture_phone:Dictionary={}
var visual_evidence:Array=[]
class WrongProvider extends RefCounted:
	func configured()->bool:return true
func decode_relative(hex:String)->PackedInt64Array:
	var bytes:=hex.hex_decode();return PackedInt64Array([bytes.decode_s64(0),bytes.decode_s64(8),bytes.decode_s64(16)])
func stage_actor(actor:Dictionary,binding:Dictionary,chart:Dictionary)->Dictionary:
	var body:=str(actor.player_object_hex).hex_decode();var parent:=str(actor.parent_object_hex).hex_decode();var relative:=decode_relative(str(actor.relative_before_hex));var ctx:Dictionary=actor.context.duplicate(true)
	var before:=var_to_bytes([body,parent,relative,ctx,chart,binding]);var tracer:=Trace.new();var kernel:=Natural.new();kernel.set("_query",tracer)
	var classified:=kernel.classify_natural_player(body,parent,relative,ctx)
	var staged:=Provider.stage_from_classification(body,parent,relative,classified,tracer.read_trace(),chart,binding)
	check(var_to_bytes([body,parent,relative,ctx,chart,binding])==before,"Staging the actual source actor and render provider preserves every caller input")
	return staged
func make_provider(generation:int=12,token:String="visual-test")->RefCounted:
	var binding:={"generation":generation,"request_token":token,"request_sha256":token.sha256_text()}
	if not actor_fixture.is_empty():
		var staged:=stage_actor(actor_fixture,binding,fixture_phone);return staged.get("provider") if staged.get("ok",false) else null
	var native:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for actor:Dictionary in native.actor_cases:
		if int(actor.parent_model)!=118 or actor.get("ship_id")!="cobra" or not actor.get("euler_radians") is Array or int(actor.expected.get("visited_volume_count",0))!=3:continue
		var parent:=str(actor.parent_object_hex).hex_decode()
		for coordinates:Vector2 in [Vector2(0,0),Vector2(0.31,0.47)]:
			var chart:=phone_frame(118,parent.decode_u32(0xa0),coordinates.x,coordinates.y);var staged:=stage_actor(actor,binding,chart)
			if not staged.get("ok",false):continue
			actor_fixture=actor.duplicate(true);fixture_phone=chart.duplicate(true);return staged.provider
	return null
func flight_state()->PackedByteArray:
	return var_to_bytes([flight_camera.transform,flight_camera.current,visual.transform])
func mesh_vertices()->PackedVector3Array:
	if not is_instance_valid(visual._terrain):return PackedVector3Array()
	var arrays:Array=visual._terrain.mesh.surface_get_arrays(0);return arrays[Mesh.ARRAY_VERTEX]
func actual_provider_render()->void:
	provider=make_provider();check(provider!=null,"An independently observed original actor yields a genuine staged native provider")
	if provider==null:return
	var before:=var_to_bytes([provider.snapshot(),provider.render_payload()]);var scene:=flight_state()
	check(visual.set_kind("earth") and visual.set_quality(2),"The native trial binds existing source-palette earth material maps")
	check(visual.publish(provider),"A cold-rebuilt verified provider publishes literal native terrain")
	await process_frame
	check(var_to_bytes([provider.snapshot(),provider.render_payload()])==before and flight_state()==scene,"Rendering cannot change provider, flight camera or host transform")
	var payload:Dictionary=provider.render_payload();var actual:Dictionary=visual.terrain_geometry();var expected:=PackedVector3Array();var expected_indices:=PackedInt32Array()
	check(payload.triangles.size()==3,"The positive render control exercises all three actually visited Cobra volumes")
	check(actual.triangles.size()==payload.triangles.size() and int(visual.stats().terrain_triangle_count)==payload.triangles.size(),"Every emitted visited native leaf is filled, including overlapping witnesses")
	for index in range(payload.triangles.size()):
		var supplied:Dictionary=payload.triangles[index];var rendered:Dictionary=actual.triangles[index];var base:=expected.size()
		check(rendered.vertices==supplied.vertices and rendered.indices==supplied.indices and rendered.packet_sha256==supplied.packet_sha256 and int(rendered.child_id)==int(supplied.child_id),"Each rendered triangle preserves its own literal F32 vertices, indices, packet and child identity")
		check(rendered.vertex_f32_hex==Visual._vertex_bytes(supplied.vertices).hex_encode() and rendered.vertex_f32_sha256==Visual._sha(Visual._vertex_bytes(supplied.vertices)),"Each leaf's actual36-byte vertex buffer matches its recorded geometry hash")
		expected.append_array(supplied.vertices)
		for vertex_index:int in supplied.indices:expected_indices.append(base+vertex_index)
	check(actual.vertices==expected and mesh_vertices()==expected and actual.indices==expected_indices,"The ArrayMesh concatenates literal emitted buffers without displacement, truncation or reordered topology")
	check(visual.stats().terrain_vertex_f32_hex==Visual._vertex_bytes(expected).hex_encode() and visual.stats().terrain_vertex_f32_sha256==Visual._sha(Visual._vertex_bytes(mesh_vertices())),"Published stats hash the actual render buffer, not just provider metadata")
	check(visual._terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]==expected_indices and actual.normals.size()==expected.size(),"Actual indices and perface shading normals remain aligned with all native vertices")
	for normal:Vector3 in actual.normals:check(normal.is_finite() and normal.is_normalized() and normal.y>=0,"Shading normals are finite face normals oriented toward local up")
	check(visual.stats().literal_packet_vertices and not visual.stats().terrain_vertex_deformation and visual.stats().all_emitted_leaves_filled and not visual.stats().active_leaf_only_filled and not visual.stats().physics_camera_clock_or_provider_written,"Rendering explicitly reports all literal leaves and no physical/camera/provider mutations")
	check(visual._mesh_root.get_child_count()==payload.triangles.size()+1,"Every visited leaf retains its own visible identity marker beside the terrain mesh")
	for node:Node in visual._mesh_root.get_children():
		if node is Label3D:
			check(node.position.is_finite() and (node.text.contains("Корпус") or node.text.contains("Объём")),"Witness labels identify actual source volumes without adding terrain vertices")
	actual.vertices[0].x+=100;actual.triangles[0].vertices[0].y+=100;actual.request_binding.request_token="caller mutation"
	var exposed:Dictionary=provider.render_payload();exposed.triangles[0].vertices[0].z+=100
	check(mesh_vertices()==expected and provider.render_payload()==payload and visual.terrain_geometry().vertices==expected,"Returned geometry and provider payloads are private copies of the frozen render buffers")
	visual_evidence.append({"case":"genuine_native_actor_literal_triangle_soup","actor":str(actor_fixture.id),"provider_snapshot":provider.snapshot_identity(),"visual":visual.stats(),"independent_native_execution_repeated_by_visual_test":false})
func material_and_marker_contract()->void:
	if provider==null:return
	var geometry:=var_to_bytes(visual.terrain_geometry());var scene:=flight_state();var snapshot:=var_to_bytes(provider.snapshot())
	for kind:String in ["earth","rock","desert","ice"]:
		check(visual.set_kind(kind),"Known source palette is available: "+kind)
		for quality:int in [0,1,2]:
			check(visual.set_quality(quality),"Bounded native surface detail configures: "+kind+"/"+str(quality))
			check(visual._terrain.material_override is StandardMaterial3D and visual._material.albedo_color==Visual.PALETTE[kind] and visual._material.cull_mode==BaseMaterial3D.CULL_DISABLED,"Two-sided native topology uses only the supplied source palette")
			if quality==0:check(visual._material.albedo_texture==null and not visual._material.normal_enabled,"Lowest quality keeps literal palette geometry without map dependency")
			else:check(visual._material.albedo_texture!=null and visual._material.normal_texture!=null and visual._material.roughness_texture!=null and visual._material.ao_texture!=null and visual._material.uv1_triplanar,"Existing albedo, normal and ORM detail change shading without vertex shaders")
			check(var_to_bytes(visual.terrain_geometry())==geometry and flight_state()==scene and var_to_bytes(provider.snapshot())==snapshot,"Material/detail selection cannot rewrite native geometry, source provider or flight")
	var kind_before:String=visual.stats().palette_kind;var quality_before:int=visual.stats().detail_quality
	check(not visual.set_kind("invented") and not visual.set_quality(-1) and not visual.set_quality(3) and visual.stats().palette_kind==kind_before and visual.stats().detail_quality==quality_before,"Unsupported palette/detail choices fail atomically")
	visual.set_witnesses_visible(false)
	for node:Node in visual._mesh_root.get_children():
		if node is Label3D:check(not node.visible,"Witness labels can be hidden without replacing native terrain")
	visual.set_witnesses_visible(true)
	check(var_to_bytes(visual.terrain_geometry())==geometry and mesh_vertices()==visual.terrain_geometry().vertices,"Witness visibility never displaces or deforms terrain")
func atomic_replacement_and_rejections()->void:
	if provider==null:return
	var before:=var_to_bytes(visual.terrain_geometry());var scene:=flight_state();var count:int=visual.stats().publication_count
	check(visual.configure(provider) and int(visual.stats().publication_count)==count and var_to_bytes(visual.terrain_geometry())==before,"Synchronizing the same verified immutable provider reuses its exact rendered buffer")
	check(not visual.configure(provider.render_payload()) and var_to_bytes(visual.terrain_geometry())==before,"A bare render payload cannot borrow source provenance without its verified provider")
	check(not visual.publish(null) and not visual.publish(WrongProvider.new()),"Null and unrelated providers cannot publish a guessed or fallback surface")
	check(var_to_bytes(visual.terrain_geometry())==before and flight_state()==scene and int(visual.stats().publication_count)==count,"Rejected provider types preserve the previously accepted render state")
	for mode:String in ["vertices","binding","snapshot","empty","disabled"]:
		var damaged:RefCounted=Provider.from_snapshot(provider.snapshot());check(damaged!=null,"Rejection control starts from a genuine cold-rebuilt sealed provider")
		if damaged==null:continue
		if mode=="vertices":damaged._entries[0].vertices[0]+=1.0
		elif mode=="binding":damaged._binding.generation+=1
		elif mode=="snapshot":damaged._snapshot.snapshot_sha256="0".repeat(64)
		elif mode=="empty":damaged._entries.clear()
		else:damaged._ready=false
		check(not visual.publish(damaged),"Corrupted current provider cannot borrow a valid historical snapshot: "+mode)
		check(var_to_bytes(visual.terrain_geometry())==before and flight_state()==scene and int(visual.stats().publication_count)==count,"Stale or invalid publication is atomic: "+mode)
	var next:RefCounted=make_provider(13,"visual-replacement");check(next!=null and visual.publish(next),"A separately sealed new generation replaces the displayed native leaf set")
	if next==null:return
	check(int(visual.stats().generation)==13 and visual.stats().snapshot_sha256==next.snapshot_identity() and visual.stats().request_binding.request_token=="visual-replacement" and int(visual.stats().publication_count)==count+1,"Replacement publishes its exact generation, request token and source binding")
	check(visual.stats().terrain_vertex_f32_sha256==Visual._sha(Visual._vertex_bytes(mesh_vertices())) and flight_state()==scene,"Replacement retains exact actual-buffer hashing and host ownership")
	var stopped:Dictionary=visual.stats();stopped.request_binding.request_token="tampered stats"
	check(visual.stats().request_binding.request_token=="visual-replacement","Stats return a private request binding")
	visual.clear("explicit_trial_exit");await process_frame
	check(visual.terrain_geometry().is_empty() and not visual.stats().configured and visual.get_child_count()==0 and int(visual.stats().terrain_triangle_count)==0 and visual.stats().last_clear_reason=="explicit_trial_exit","Explicit exit releases terrain and witness nodes and clears all old identities")
	check(visual.publish(provider),"A cleared renderer can publish a fresh copy of a still-valid provider")
	visual.clear("test_cleanup");await process_frame;check(flight_state()==scene,"Repeated publish/clear never changes the flight camera or host transform")
	visual_evidence.append({"case":"atomic_new_generation_reject_and_clear","rejection_modes":["wrong_type","vertices","binding","snapshot","empty","disabled"],"visual":visual.stats()})
func run()->void:
	flight_camera=Camera3D.new();flight_camera.position=Vector3(7,8,9);root.add_child(flight_camera);flight_camera.current=true
	visual=Visual.new();visual.transform=Transform3D(Basis(Vector3.UP,0.23),Vector3(3,4,5));root.add_child(visual)
	await actual_provider_render();material_and_marker_contract();await atomic_replacement_and_rejections()
	var sources:Dictionary={}
	for path:String in ["scripts/source_native_surface_visual.gd","scripts/source_native_surface_provider.gd","scripts/world_surface_library.gd","tests/test_source_native_surface_visual.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VISUAL_REPORT.get_base_dir()));var file:=FileAccess.open(VISUAL_REPORT,FileAccess.WRITE);file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"sources":sources,"evidence":visual_evidence,"scope":"Actual original actor fixture and genuine cold-rebuilt sealed native provider. Literal F32 ArrayMesh buffers for all emitted leaves, topology, hashes, bounded reused-material shading/normals, visible child markers, private source/render copies, new generation replacement, stale/internal corruption rejection and explicit cleanup. Does not independently execute original native instructions, mutate Surface/Main/flight physics, render a GPU framebuffer, test an Android phone or claim universal mesh/native-height equivalence."},"\t"));file.close()
	visual.queue_free();flight_camera.queue_free();await process_frame;await process_frame;print("SOURCE NATIVE SURFACE VISUAL TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
