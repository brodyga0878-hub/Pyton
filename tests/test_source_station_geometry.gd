extends SceneTree
# Native final-contact and station-spin controls; source mesh continuity and
# independent geometric sweeps. This does not emulate the full docking AI.
const Geometry=preload("res://scripts/source_station_geometry.gd")
const Visual=preload("res://scripts/source_station_visual.gd")
const Materials=preload("res://scripts/material_library.gd")
const Finish=preload("res://scripts/station_visual.gd")
const World=preload("res://scripts/planetary_system.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const Catalog=preload("res://scripts/ship_catalog.gd")
const Clock=preload("res://scripts/source_clock.gd")
const Vertices=preload("res://scripts/source_model_vertices.gd")
const VM=preload("res://scripts/source_model_vm.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<25:push_error(message)
func json(path:String)->Dictionary:
	var result:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return result if result is Dictionary else {}
func ints(value:Array)->PackedInt64Array:
	var result:=PackedInt64Array()
	for item in value:result.append(int(item))
	return result
func special_asset_publication()->void:
	var resource:=json("res://data/ffe_special_station_models.json")
	check(resource.source_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and resource.roots.size()==1 and int(resource.roots[0])==69 and resource.models.size()==2,"Special source port69/225 is an append-only resource pinned to uploaded EXE")
	var workers:Array=[]
	for worker in range(4):
		var thread:=Thread.new()
		thread.start(func()->bool:
			for pass_index in range(250):
				var model:=VM.model(69 if pass_index%2==0 else 72)
				if model.is_empty() or int(model.index)!=(69 if pass_index%2==0 else 72):return false
			return true)
		workers.append(thread)
	for thread:Thread in workers:check(thread.wait_to_finish()==true,"Concurrent cold base/special model lookups publish complete immutable dictionaries")
func all_root_native_vertices()->void:
	var path:="res://tests/fixtures/source_station_vertices_native.json"
	var text:=FileAccess.get_file_as_string(path);var fixture:Dictionary=JSON.parse_string(text)
	check(text.sha256_text()=="6baff6ab0601cca0068fedb8dff3d53ab4cd656e1b7f829dcf74823dc43c07b4","All10 station-root native vertex fixture is pinned")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_count==240 and fixture.guard_canaries_unchanged,"Independent original station vertex executions repeat with guards")
	var points:=0
	for row:Dictionary in fixture.cases:
		var model:Dictionary=fixture.models[str(int(row.model_index))]
		var context:Dictionary=fixture.contexts[int(row.context_index)].duplicate(true)
		context.scale_shift_raw=int(model.scale_shift_raw)
		var kernel:=Vertices.new()
		check(kernel.configure(str(model.vertices_hex).hex_decode(),context),"Original root station vertex input configures")
		var result:=kernel.all_points()
		check(result.get("ok",false),"All source station root vertices evaluate")
		if not result.get("ok",false):continue
		for i in range(row.vertices_local_raw.size()):
			points+=1
			for axis in range(3):check(int(result.vertices_local_raw[i][axis])==int(row.vertices_local_raw[i][axis]),"Exact independent F1470/F1478 source station coordinate")
		check(ints(result.final_random_state_u32)==ints(row.final_random_state_u32),"Original station vertex random-state snapshot agrees")
	check(points==14544 and fixture.models.size()==10,"All10 source station roots and14544 actual native vertex points are covered")
func contact_controls()->void:
	var fixture:=json("res://tests/fixtures/source_station_native.json")
	check(fixture.get("source_executable_sha256")=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72","Native contact controls pin uploaded source image")
	check(fixture.get("source_assembly_sha256")=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a" and fixture.get("source_commit")=="7e540341d4e09aa3c92877b87d49e7f2c143ad8d","Contact controls pin source revision")
	check(fixture.get("case_count")==fixture.get("cases",[]).size() and fixture.get("case_count",0)>=400,"Complete independent source contact fixture")
	check(fixture.get("fresh_process_runs",0)>=3 and fixture.get("reverse_repeat_count")==fixture.get("case_count") and fixture.get("body_readonly_verified")==true and fixture.get("canaries_unchanged")==true,"Native repeated processes and source object boundaries")
	var accepted:=0
	for row:Dictionary in fixture.get("cases",[]):
		var actual:=Geometry.source_contact(ints(row.velocity_s32),ints(row.up_q31),ints(row.normal_q31),row.gear_u16,row.initial_flags_u8,row.damage_enabled_u8)
		check(not actual.is_empty(),"Source contact context executes "+str(row.name))
		for key in row.expected:check(actual.get(key)==row.expected[key],"Native F575 contact %s/%s"%[str(row.name),key])
		if actual.get("accepted",false):accepted+=1
	check(accepted>0 and accepted<fixture.get("case_count",0),"Actual source contact accepts and rejects controls")
	check(fixture.get("door_case_count")==fixture.get("door_cases",[]).size() and fixture.get("door_case_count",0)>=300 and fixture.get("door_reverse_repeat_count")==fixture.get("door_case_count") and fixture.get("door_non_target_bytes_unchanged")==true,"Complete independent F865 door controls")
	for row:Dictionary in fixture.get("door_cases",[]):
		var actual:=Geometry.advance_door(row.door_u16,row.status_u8,row.step_u32)
		check(actual.get("door_u16")==row.expected.door_u16,"Native F865 door word "+str(row.name))
		check(actual.get("status_u8")==row.expected.status_u8,"Native F865 signed traffic state "+str(row.name))
func spin_controls()->void:
	var fixture:=json("res://tests/fixtures/rebuild_body_rotation_native.json");var count:=0
	for row:Dictionary in fixture.get("cases",[]):
		if not (int(row.flags_u8)&0x10) or (int(row.flags_u8)&0x20):continue
		var record:=PackedByteArray();record.resize(68);record.encode_u16(10,32);record.encode_u16(12,72);record[62]=int(row.rotation_raw)&255;record.encode_u16(66,int(row.tilt_i16)&65535)
		var old_tick:=int(row.old_tick_u32)&0xffffffff;var new_tick:=int(row.new_tick_u32)&0xffffffff
		var old_day:=int(row.old_day_u32)&0xffffffff;var new_day:=int(row.new_day_u32)&0xffffffff
		var state:=Geometry.initialize_orientation(record,old_tick,old_day)
		check(not state.is_empty() and ints(state.matrix_q31)==ints(row.initial_matrix_q31),"Native F880 station orientation initialization")
		if row.get("previous_matrix_override")!=null:state.matrix_q31=Array(ints(row.previous_matrix_override))
		var original:=var_to_bytes(state)
		var next:=Geometry.advance_orientation(state,new_tick,new_day)
		check(not next.is_empty() and ints(next.matrix_q31)==ints(row.updated_matrix_q31),"Native F866 station-specific argument order and coarse clock gate")
		check(var_to_bytes(state)==original,"Source spin does not mutate supplied saved state")
		check(int(next.tick_u32)==int(row.stored_tick_u32) and int(next.day_u32)==int(row.stored_day_u32),"Source spin timestamps follow original stores")
		var decoded:Dictionary=JSON.parse_string(JSON.stringify(next))
		check(Geometry.advance_orientation(decoded,new_tick,new_day)==next,"Plain JSON source-spin state survives unchanged-clock restore")
		count+=1
	check(count>=250,"Station spin exercised by at least250 independent original instruction cases")
func geometry_controls()->void:
	# Published0.11.11 source-compiler snapshots before this station wrapper.
	# Expected apertures also follow original submodel227 source vertex bounds.
	var snapshots:={72:[891,[-196607,-196608,-247552],[196607,236542,196607],"939d3b8555ca1629e1780d0ac1b1699e809198a6c6dc2ac5d9b6c89ba517feec"],73:[292,[-999423,-983040,-196608],[999423,983039,237567],"53b78adb1aa8d80b93cd5898f9f2a98e63b9578b138d9b4766f484e9d3516c77"],80:[570,[-3932159,-3162112,-8290304],[3932159,3162110,229375],"cfaac5a0dbaec22c496e96322dc923e689adcbbb41475aa61eb4ab8344e573f8"]}
	snapshots.merge({
		69:[55,[-196607,-40960,-229376],[196607,40959,229375],"ea5dd31e7519a0faa07b1800bf82e92dbf11e4174d52cc78ecdc6f711e94c737"],
		74:[262,[-794623,-794624,-679935],[794622,794622,679935],"bdbf1bec6e8a06fa4f2572307b7f59de61847b14f8b09b416f681c636942affe"],
		75:[172,[-638975,-638976,-1146880],[638975,638975,229375],"a1887a29d2b5e31533bb86aae4a6d05fa4aece4048fce3dd1e61081e20e9afd9"],
		76:[174,[-376832,-376832,-770048],[376832,376831,196607],"5e00905840435f624d1e3a419743a8ff570042d372a399bef429aacb9ba7a7d3"],
		77:[158,[-679935,-794624,-155648],[679935,794622,155647],"3aa324e1167464ea373e818ca049588bac4c097fba0532c65ca42a3335eb3816"],
		78:[160,[-393215,-376832,-794624],[393215,376831,794623],"019336645760b0c39807221a0b0ef59a8c03a90976161ee06a33015947c9da0d"],
		79:[152,[-950271,-950272,-1785856],[950271,950271,147455],"f575767ec858b0c11711a5fa344d86c5fe6cbf741868fb94571d1090377800d6"]})
	var ships:=Catalog.new().all()
	for id:int in Geometry.MODELS:
		var data:=Geometry.prepare(id);var expected:Array=snapshots[id]
		check(data.get("ok",false) and data.triangles.size()==expected[0],"Complete original station triangle program "+str(id))
		check(ints(data.compiled.bounds_raw.minimum)==ints(expected[1]) and ints(data.compiled.bounds_raw.maximum)==ints(expected[2]),"Published source station hull coordinates preserved "+str(id))
		check(data.descriptor_sha256==expected[3] and data.dock_local==Vector3.ZERO,"Source descriptor and orbital docking centre "+str(id))
		check(absf(data.approach_waypoint.z-4097.900390625)<0.01,"Source F741 outer waypoint uses calibrated4000*1024 raw")
		check(data.collision_profile=="modern-ellipsoid-vs-source-solid-triangles-v1" and not data.original_collision_vm and not data.original_autopilot,"Triangle CCD/phone adaptation is explicit")
		var fingerprint:=var_to_bytes(data.compiled)
		for profile:Dictionary in ships:
			var span:=float(profile.visual_span_m);var radii:=Vector3(span*0.55,span*0.14+2.0,span*0.55)
			check(Geometry.approach_clear(data,radii),"Original clear aperture fits current profile %d/%s"%[id,profile.id])
			check(Geometry.mobile_dock_ready(data,Vector3.ZERO,Vector3.ZERO,Vector3.FORWARD,Vector3.UP,radii),"Source bay centre is a safe mobile docking point")
			check(not Geometry.mobile_dock_ready(data,Vector3(0,0,100),Vector3.ZERO,Vector3.FORWARD,Vector3.UP,radii),"Old hundred-metre capture bubble cannot dock outside interior target")
			check(not Geometry.mobile_dock_ready(data,Vector3.ZERO,Vector3(13,0,0),Vector3.FORWARD,Vector3.UP,radii),"Phone speed cap rejects fast collision")
			check(not Geometry.mobile_dock_ready(data,Vector3.ZERO,Vector3.ZERO,Vector3.BACK,Vector3.UP,radii),"Heading guard rejects backwards approach")
			check(not Geometry.mobile_dock_ready(data,Vector3.ZERO,Vector3.ZERO,Vector3.FORWARD,Vector3.DOWN,radii),"Roll guard rejects upside-down approach")
			var wall:=Geometry.sweep(data,Vector3(100,0,700),Vector3(100,0,0),radii)
			check(not wall.is_empty() and float(wall.time)>=0 and float(wall.time)<=1,"Real source front hull blocks off-centre high-speed sweep")
		check(var_to_bytes(data.compiled)==fingerprint,"Collision checks do not change source mesh or cache state")
		var cached:=Geometry.prepare(id);data.compiled.triangles_raw.clear()
		check(Geometry.prepare(id).compiled.triangles_raw.size()==expected[0] and cached.compiled.triangles_raw.size()==expected[0],"Returned geometry arrays do not alias cached source")
		var closed:=Geometry.prepare(id,0,65535)
		check(not closed.is_empty() and not Geometry.approach_clear(closed,Vector3(10,5,10)),"Closed-door source snapshot cannot advertise an approach corridor")
		check(not Geometry.sweep(closed,Vector3(0,0,700),Vector3.ZERO,Vector3(10,5,10)).is_empty(),"Closed original door geometry blocks the central sweep")
	var count:=0;var galaxy:=Galaxy.new()
	for star:Dictionary in galaxy.all():
		var world:=World.new();world.configure(star)
		for site:Dictionary in world.settlements:
			if int(site.type_code) not in [32,33,34]:continue
			var data:=Geometry.prepare_site(site)
			check(data.get("ok",false) and data.model_index==int(site.model_index),"Every source orbital site uses its actual model")
			var spin:=Geometry.initialize_orientation(str(site.runtime_record_hex).hex_decode(),Clock.EPOCH_TICK_U32,Clock.EPOCH_DAY_U32)
			check(not spin.is_empty(),"Source site has initialized persistent original spin state")
			count+=1
	check(count==17,"All17 current orbital sites support original station geometry")
func render_controls()->void:
	check(Materials._textures.is_empty() and Finish._finish_textures.is_empty(),"Cold geometry/native tests do not load PBR maps")
	for id:int in Geometry.MODELS:
		var visual:=Visual.new();visual.set_quality(0);root.add_child(visual)
		var data:=Geometry.prepare(id)
		check(visual.configure(data) and visual.triangle_count==data.triangles.size(),"Renderer binds original root/source submodels directly")
		check(visual.model_index==id and visual.local_bounds==data.bounds,"Source model/render bounds remain identical")
		var arrays:Array=[]
		for entry in visual._mesh_nodes:
			arrays.append(entry.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
			check(entry.node.material_override.albedo_texture==null and not entry.node.material_override.normal_enabled,"Economy station loads no detailed finish")
		visual.set_quality(2)
		for index in range(visual._mesh_nodes.size()):
			var entry:Dictionary=visual._mesh_nodes[index]
			check(entry.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==arrays[index],"Quality preserves source triangle coordinates")
			check(entry.node.material_override.albedo_texture==Finish.finish_texture("albedo") and entry.node.material_override.normal_texture==Finish.finish_texture("normal"),"Detailed station uses shared existing station PBR maps")
			check(entry.node.material_override.vertex_color_is_srgb and entry.node.material_override.vertex_color_use_as_albedo,"Original source palette has explicit StandardMaterial colour space")
		var children:=visual.get_children();check(not visual.configure({}) and visual.get_children()==children,"Failed renderer configure preserves existing scene")
		visual.set_quality(0)
		for entry in visual._mesh_nodes:check(entry.node.material_override.albedo_texture==null,"Economy transition releases detailed mesh bindings")
		visual.queue_free();await process_frame
func invalid_inputs()->void:
	var before:=Geometry.cache_size()
	for row in [[900,0,0],[72,-1,0],[72,4294967296,0],[72,0,-1],[72,0,65536]]:check(Geometry.prepare(row[0],row[1],row[2]).is_empty(),"Invalid station model/state rejected")
	check(Geometry.cache_size()==before,"Rejected geometry inputs cannot mutate cache")
	check(Geometry.source_contact(PackedInt64Array(),PackedInt64Array([0,0,0]),PackedInt64Array([0,0,0]),65535).is_empty(),"Malformed original contact vectors rejected")
	check(Geometry.initialize_orientation(PackedByteArray(),0,0).is_empty() and Geometry.advance_orientation({},0,0).is_empty(),"Malformed source spin state rejected")
	var data:=Geometry.prepare(72)
	for radii in [Vector3.ZERO,Vector3(-1,1,1),Vector3(INF,1,1)]:check(not Geometry.mobile_dock_ready(data,Vector3.ZERO,Vector3.ZERO,Vector3.FORWARD,Vector3.UP,radii),"Invalid collision size cannot accept docking")
	check(not Geometry.approach_clear(data,Vector3(INF,1,1)),"Invalid collision size cannot advertise approach clearance")
	for row in [[-1,0,0],[65536,0,0],[0,256,0],[0,0,-1],[0,0,4294967296]]:check(Geometry.advance_door(row[0],row[1],row[2]).is_empty(),"Invalid original door state rejected")
func run()->void:
	if not World.can_instantiate():check(false,"World dependency must compile before source station geometry integration runs");quit(1);return
	special_asset_publication();all_root_native_vertices();contact_controls();spin_controls();geometry_controls();await render_controls();invalid_inputs()
	print("SOURCE STATION TESTS: %d checks, %d failures; original69/72-through80 geometry, native contact/spin, explicit modern CCD/mobile guard"%[checks,failures])
	quit(1 if failures else 0)
