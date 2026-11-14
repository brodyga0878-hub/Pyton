extends SceneTree
const Provider=preload("res://scripts/source_native_surface_provider.gd")
const Natural=preload("res://scripts/source_natural_contact.gd")
const Trace=preload("res://scripts/source_terrain_query_trace.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Geometry=preload("res://scripts/source_native_contact_geometry.gd")
const REPORT:="res://build/current-test-reports/source-native-surface-provider.json"
var checks:=0
var failures:=0
var counts:={"actor_cases":0,"staged_actors":0,"own_leaves":0,"atomic_rejections":0,"orientation_cases":0}
var example:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=25:push_error(label)
func vector_hex(value:String)->PackedInt64Array:
	var bytes:=value.hex_decode();return PackedInt64Array([bytes.decode_s64(0),bytes.decode_s64(8),bytes.decode_s64(16)])
func same_words(actual:Variant,expected:Variant)->bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size()!=expected.size():return false
		for key:Variant in actual:
			if not expected.has(key) or not same_words(actual[key],expected[key]):return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):return actual==expected
	return actual==expected
func phone_frame(model:int,uid:int,raw:PackedInt64Array,body:PackedByteArray,parent:PackedByteArray)->Dictionary:
	var lat:=atan2(float(raw[1]),sqrt(float(raw[0])*raw[0]+float(raw[2])*raw[2]));var lon:=atan2(-float(raw[2]),float(raw[0]));var basis:Basis=Terrain.new().basis_at(lat,lon);var values:Array=[]
	for axis:Vector3 in [basis.x,basis.y,basis.z]:
		for component:float in [axis.x,axis.y,axis.z]:values.append(component)
	var record:=PackedByteArray();record.resize(68);record.encode_u16(12,model)
	return {"basis_f64":values,"radius_m":Terrain.reference_radius(record),"source_uid_u32":uid,"source_model_index":model,"latitude":lat,"longitude":lon,"parent_frame_policy":"isolated-matching-bodyfixed-parent-q31","source_body_parent_index_u8":int(body[0x56]),"source_body_frame_u8":int(body[0x57]),"source_parent_index_u8":int(parent[0x86]),"source_parent_matrix_q31_hex":parent.slice(0,36).hex_encode()}
func orientation_controls()->void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_native_provider_orientation.json"))
	for row:Dictionary in data.cases:
		var p:=PackedFloat64Array()
		for encoded:String in row.f64_le_hex:p.append(encoded.hex_decode().decode_double(0))
		var actual:=Provider._orient(p[0],p[1],p[2],p[3],p[4],p[5]);counts.orientation_cases+=1
		check(actual.get("ok",false) and int(actual.get("sign",9))==int(row.expected_sign),"Exact orientation matches independent Fraction oracle "+str(counts.orientation_cases))
	check(counts.orientation_cases==int(data.case_count),"All independent exact rational controls consumed")
	check(not Provider._orient(0,0,1,0,0,NAN).ok and not Provider._orient(0,0,1,0,0,pow(2,-300)).ok,"Nonfinite and underflow predicate domains reject explicitly")
	for invalid:String in ["-000000000000001","+000000000000001","g000000000000000"]:
		check(not Provider._decode({"t":"i64","v":invalid},{"nodes":0}).ok and Provider._vector(invalid+"0".repeat(32)).is_empty(),"Malformed signed/nonhex codecs reject before hex_decode can emit an engine error")
	var literal:=PackedFloat64Array([0,2,0,4,6,0,0,10,4])
	for point:Vector2 in [Vector2(0,0),Vector2(4,0),Vector2(0,4),Vector2(2,0),Vector2(0,2),Vector2(1,1)]:
		var hit:=Provider._coverage(literal,point.x,point.y)
		check(not hit.is_empty() and hit.coverage_exact and hit.height==2.0+point.x+2.0*point.y,"Literal closed triangle edges/vertices use their own plane")
	check(Provider._coverage(literal,-0.0000001,0).is_empty() and Provider._coverage(literal,3,3).is_empty(),"Exterior points reject without epsilon")
	var raised:=literal.duplicate()
	for index in range(3):raised[index*3+1]+=0.000000000000001
	var order:=Provider._height_order(raised,literal,1,1)
	check(order.get("ok",false) and int(order.sign)>0 and Provider._height_order(literal,literal,1,1).sign==0,"Exact rational plane ordering resolves overlapping binary64 enclosures and exact ties without epsilon")
func actor_controls()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_footprint_native.json"));var classifier:=Natural.new();var trace:=Trace.new();classifier._query=trace
	for sample:Dictionary in fixture.actor_cases:
		var model:=int(sample.parent_model)
		if model<118 or model>133:continue
		counts.actor_cases+=1
		var body:=str(sample.player_object_hex).hex_decode();var parent:=str(sample.parent_object_hex).hex_decode();var relative:=vector_hex(str(sample.relative_before_hex));var phone:=phone_frame(model,parent.decode_u32(0xa0),relative,body,parent);var binding:={"generation":counts.actor_cases,"request_token":str(sample.id),"request_sha256":str(sample.id).sha256_text()}
		trace.reset_trace();var classified:=classifier.classify_natural_player(body,parent,relative,sample.context.duplicate(true));var rows:=trace.read_trace();var before:=var_to_bytes([body,parent,relative,classified,rows,phone,binding]);var built:=Provider.stage_from_classification(body,parent,relative,classified,rows,phone,binding)
		check(int(classified.f576_return_s32)==int(sample.expected.canonical.f576_return_s32) and same_words(classified.globals_after,sample.expected.canonical.globals),"Same executed classification retains independently observed original native return and all globals")
		var query_index:=0
		for native:Dictionary in sample.expected.volume_trace:
			if not native.query.executed:continue
			check(query_index<rows.size() and Geometry._words(rows[query_index].winning_triangle.positions_raw,9)==Geometry._words(native.winning_triangle.positions_raw,9),"Provider source input is the independently captured original winning leaf")
			query_index+=1
		check(var_to_bytes([body,parent,relative,classified,rows,phone,binding])==before,"Same execution consumed without source/caller mutations")
		var complete:bool=rows.size()==classified.iterations.size() and not Geometry._phone(phone).is_empty() and body[0x57]!=0 and body[0x56]==parent[0x86]
		for iteration:Dictionary in classified.iterations:
			complete=complete and iteration.branch=="terrain_query" and not iteration.parent_transpose_applied and iteration.has("query_result_raw")
			if iteration.has("query_result_raw"):complete=complete and int(iteration.query_result_raw)<int(iteration.query_limit_raw)
		if not built.ok:
			counts.atomic_rejections+=1;check(not complete,"Ineligible actor rejected atomically: "+str(sample.id)+" "+str(built.reason));continue
		counts.staged_actors+=1;var provider:RefCounted=built.provider;var payload:Dictionary=provider.render_payload();var snapshot:Dictionary=provider.snapshot()
		check(complete and provider.configured() and payload.triangles.size()==classified.iterations.size() and payload.generation==counts.actor_cases,"One immutable bound snapshot covers all visited leaves")
		check(not payload.universal_mesh_identity and not payload.native_integer_height_equivalence and not payload.native_physics_authorized,"No Float32/native law equivalence or universal mesh admission")
		for triangle:Dictionary in payload.triangles:
			counts.own_leaves+=1;var probe:Dictionary=provider.probe_sample(int(triangle.child_id));var actual:=PackedFloat32Array()
			for vertex:Vector3 in triangle.vertices:actual.append(vertex.x);actual.append(vertex.y);actual.append(vertex.z)
			check(actual.to_byte_array().hex_encode()==probe.packet.local_vertices_f32_hex and triangle.indices==PackedInt32Array([0,1,2]),"Rendering and height use identical36 Float32 bytes and source order")
			check(not probe.height.is_empty() and probe.height.coverage_exact and probe.height.snapshot_sha256==provider.snapshot_identity(),"Every actual ownleaf footprint has exact coverage")
			check(provider.height_at(probe.local_point[0],probe.local_point[2],int(triangle.child_id))==probe.height,"Overlapping witnesses cannot change perprobe height selection")
			var upper:Dictionary=provider.height_at(probe.local_point[0],probe.local_point[2]);check(not upper.is_empty() and upper.selection_policy=="uppermost_emitted_triangle_then_lowest_child_id","Every real footprint also has a proved uppermost emitted display triangle")
		check(provider.height_at(1e20,1e20).is_empty() and provider.height_at(0,0,99).is_empty(),"Outside/unknown points return no ordinary fallback")
		var cold:=Provider.from_snapshot(JSON.parse_string(JSON.stringify(snapshot)))
		check(cold!=null and cold.snapshot_identity()==provider.snapshot_identity() and cold.render_payload()==payload,"Lossless JSON cold rebuild regenerates identical source packets")
		var original:Dictionary=provider.render_payload();payload.triangles[0].vertices[0]=Vector3.ZERO;payload.request_binding.request_token="edit";snapshot.kind="edit"
		check(provider.render_payload()==original and provider.snapshot().kind=="actual_f576_visited_leaves","Caller edits cannot change private geometry/witnesses")
		if example.is_empty():example={"body":body,"parent":parent,"relative":relative,"classification":classified,"rows":rows,"phone":phone,"binding":binding,"provider":provider}
	check(counts.staged_actors>40 and counts.own_leaves>70 and counts.atomic_rejections>0,"Real native actors cover many complete sets and coarse exclusions")
func guard_and_root_controls()->void:
	if example.is_empty():check(false,"A real accepted source actor exists");return
	var e:=example;var body:PackedByteArray=e.body;var parent:PackedByteArray=e.parent;var relative:PackedInt64Array=e.relative;var c:Dictionary=e.classification;var rows:Array=e.rows;var phone:Dictionary=e.phone;var binding:Dictionary=e.binding
	var altered:=body.duplicate();altered[0x57]=0;check(not Provider.stage_from_classification(altered,parent,relative,c,rows,phone,binding).ok,"Inertial sourceframe rejected")
	var position:=relative.duplicate();position[0]+=1;check(not Provider.stage_from_classification(body,parent,position,c,rows,phone,binding).ok,"Primary relative must equal raw body position")
	var changed:=c.duplicate(true);changed.iterations[0].branch="inside_inner";check(not Provider.stage_from_classification(body,parent,relative,changed,rows,phone,binding).ok,"Coarse inner branch cannot fabricate a leaf")
	changed=c.duplicate(true);changed.iterations[0].query_result_raw=changed.iterations[0].query_limit_raw;check(not Provider.stage_from_classification(body,parent,relative,changed,rows,phone,binding).ok,"Capped stale previous-altitude cannot admit geometry")
	var traced:=rows.duplicate(true);traced[0].winning_triangle.positions_raw[0][0]+=1;check(not Provider.stage_from_classification(body,parent,relative,c,traced,phone,binding).ok,"Changed native leaf rejected by fresh Geometry replay")
	changed=c.duplicate(true);changed.iterations[0].relative_before_hex="00".repeat(24);check(not Provider.stage_from_classification(body,parent,relative,changed,rows,phone,binding).ok,"A genuine leaf cannot be moved to a foreign actual volume footprint")
	changed=c.duplicate(true);changed.iterations[0].threshold_before_s32+=1;check(not Provider.stage_from_classification(body,parent,relative,changed,rows,phone,binding).ok,"Source child radii thresholds cannot be rewritten by a geometry witness")
	changed=c.duplicate(true);changed.iterations[0].query_result_raw-=1;check(not Provider.stage_from_classification(body,parent,relative,changed,rows,phone,binding).ok,"Iteration's integer query result must equal the same executed source trace")
	var post:=Provider.stage_from_classification(body,parent,relative,c,rows,phone,binding,"post_response_render_only")
	check(post.ok and post.provider.render_payload().render_only_witness and post.provider.render_payload().render_phase=="post_response_render_only" and Provider.from_snapshot(post.provider.snapshot())!=null,"Fresh postresponse rendering is distinctly sealed and never renamed as accepted collision authority")
	var snapshot:Dictionary=e.provider.snapshot();snapshot.witness_sha256="0".repeat(64);check(Provider.from_snapshot(snapshot)==null,"Stale source seal rejected")
	var invalid_binding:=binding.duplicate(true);invalid_binding.request_sha256="-"+"0".repeat(63);check(not Provider.stage_from_classification(body,parent,relative,c,rows,phone,invalid_binding).ok,"A signed numeric hexadecimal string is not a request SHA256")
	for prefix:String in ["-","+","g"]:
		var corrupt:Dictionary=e.provider.snapshot();corrupt.source_witness.v.body.v=prefix+"0".repeat(675);corrupt.witness_sha256=Provider._sha({"witness":corrupt.source_witness});corrupt.erase("snapshot_sha256");corrupt.snapshot_sha256=Provider._sha(corrupt)
		check(Provider.from_snapshot(corrupt)==null,"Resealed signed/nonhex byte witness rejects before invoking hex_decode")
	snapshot=e.provider.snapshot();var decoded:=Provider._decode(snapshot.source_witness,{"nodes":0});decoded.value.body="wrong type";snapshot.source_witness=Provider._encode(decoded.value);snapshot.witness_sha256=Provider._sha({"witness":snapshot.source_witness});snapshot.erase("snapshot_sha256");snapshot.snapshot_sha256=Provider._sha(snapshot)
	check(Provider.from_snapshot(snapshot)==null,"Corrupt resealed typed witness rejected without raw-call type errors")
	for key:String in ["iterations","terrain_query_calls","f576_return_s32"]:
		var corrupt:Dictionary=e.provider.snapshot();var data:=Provider._decode(corrupt.source_witness,{"nodes":0});data.value.classification[key]="malformed";corrupt.source_witness=Provider._encode(data.value);corrupt.witness_sha256=Provider._sha({"witness":corrupt.source_witness});corrupt.erase("snapshot_sha256");corrupt.snapshot_sha256=Provider._sha(corrupt)
		check(Provider.from_snapshot(corrupt)==null,"Resealed malformed classification field rejects safely: "+key)
	var record:=PackedByteArray();record.resize(68);record.encode_u16(12,118);record.encode_u32(4,1);var basis:Basis=Terrain.new().basis_at(0.31,0.47);var root_phone:=phone_frame(118,1,relative,body,parent);root_phone.latitude=0.31;root_phone.longitude=0.47;root_phone.basis_f64=[]
	for axis:Vector3 in [basis.x,basis.y,basis.z]:
		for component:float in [axis.x,axis.y,axis.z]:root_phone.basis_f64.append(component)
	var root:=Provider.prepare_root(record,root_phone,Terrain.radial_q31(0.31,0.47),binding)
	check(root.ok,"Independent signed-root stages visible native terrain: "+str(root.reason))
	if root.ok:
		var provider:RefCounted=root.provider;var anchor:Dictionary=provider.root_anchor()
		check(anchor.render_only and not anchor.actual_ship_collision and anchor.source_bounds.terrain_query_eligible and provider.render_payload().render_only_root,"Initial root is explicitly renderonly and original-bounds eligible")
		check(not provider.height_at(anchor.local_point[0],anchor.local_point[2]).is_empty() and Provider.from_snapshot(provider.snapshot())!=null,"Actual root has exact coverage and fresh cold rebuild")
	record.encode_u16(12,117);check(not Provider.prepare_root(record,root_phone,Terrain.radial_q31(0.31,0.47),binding).ok,"Anisotropic117 cannot bypass initial model policy")
	var blank:=Provider.new();check(not blank.configured() and blank.height_at(0,0).is_empty(),"Unconfigured provider exposes no fallback")
func run()->void:
	orientation_controls();actor_controls();guard_and_root_controls()
	var pins:Dictionary={}
	for path:String in ["scripts/source_native_surface_provider.gd","tests/test_source_native_surface_provider.gd","scripts/source_terrain_query_frame.gd","scripts/source_native_contact_geometry.gd","scripts/source_natural_contact.gd","tests/fixtures/source_footprint_native.json","tests/fixtures/source_native_provider_orientation.json"]:pins[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE);file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"counts":counts,"sources":pins,"scope":"Same-execution F576 ownleaf provider; identical literal Float32 render/height geometry; exact rational orientation controls; outward heights; lossless cold Geometry replay; separate renderonly signed root. No second F576, native/float height equality, universalmesh, sourcebank, F575/HP/time application, GPU or Android performance claim."},"\t"));file.close()
	print("Native surface provider: %d checks, %d failures; %d actors / %d ownleaves"%[checks,failures,counts.staged_actors,counts.own_leaves]);quit(1 if failures else 0)
