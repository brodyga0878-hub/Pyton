extends SceneTree
# Native observations establish frame identity. Integer remainder witnesses
# establish forward quantization; a floating inverse never becomes a proof.
const Frame=preload("res://scripts/source_terrain_query_frame.gd")
const Natural=preload("res://scripts/source_natural_contact.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Math=preload("res://scripts/ground_coordinates.gd")
const Units=preload("res://scripts/source_units.gd")
const Physics=preload("res://scripts/source_physics_bridge.gd")
const Phone=preload("res://scripts/source_surface_contact_bridge.gd")
const NATIVE:="res://tests/fixtures/source_contact_frame_native.json"
const ORIGINAL:="res://tests/fixtures/source_natural_contact_native.json"
const ROOT:="res://tests/fixtures/source_contact_field_native.json"
const REPORT:="res://validation/contact-frame-2026-11-14/source-terrain-query-frame.json"
var checks:=0
var failures:=0
var native_cases:=0
var native_frames:=0
var native_coarse:=0
var native_unsupported:=0
var native_poles:=0
var original_cases:=0
var original_frames:=0
var root_frames:=0
var forward_points:=0
var inverse_previews:=0
var phone_witnesses:=0
var native_leaf_previews:=0
var evidence:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=30:push_error(label)
func ints(value:Array)->PackedInt64Array:
	var result:=PackedInt64Array()
	for component:Variant in value:result.append(int(component))
	return result
func vector_hex(value:String)->PackedInt64Array:
	var data:=value.hex_decode()
	return PackedInt64Array([data.decode_s64(0),data.decode_s64(8),data.decode_s64(16)]) if data.size()==24 else PackedInt64Array()
func fixture(path:String)->Dictionary:
	var result:Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	check(result is Dictionary,"Independent native fixture exists: "+path)
	return result if result is Dictionary else {}
func same(actual:Variant,expected:Variant)->bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size()!=expected.size():return false
		for key:Variant in actual:
			if not expected.has(key) or not same(actual[key],expected[key]):return false
		return true
	if (actual is Array or actual is PackedInt64Array) and (expected is Array or expected is PackedInt64Array):
		if actual.size()!=expected.size():return false
		for index in range(actual.size()):
			if not same(actual[index],expected[index]):return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):return int(actual)==int(expected)
	return actual==expected

func inspect_forward(frame:Dictionary,point:PackedInt64Array,label:String)->void:
	var before:=var_to_bytes([frame,point]);var mapped:=Frame.map_model_point_raw(frame,point)
	check(mapped.get("ok",false),"Admissible source point has an exact nonwrapping forward witness: "+label)
	if not mapped.get("ok",false):return
	forward_points+=1
	check(var_to_bytes([frame,point])==before,"Forward witness leaves frame and point unchanged: "+label)
	var delta:=PackedInt64Array()
	for axis in range(3):delta.append(point[axis]-int(frame.O[axis]))
	var original:=Point._transform(delta,frame.U);var expected:=PackedInt64Array()
	for axis in range(3):expected.append(int(frame.C[axis])+original[axis])
	check(expected==mapped.query_point_raw,"Forward result equals unchanged Point._transform plus original C: "+label)
	if point==frame.observer_model_local_raw:check(mapped.query_point_raw==frame.source_qorigin_delta_raw and frame.source_qorigin_delta_nonwrapping,"Reported actor query origin equals the actual quantized forward map, rather than assuming odd Q31 flooring: "+label)
	for axis in range(3):
		var numerator:=0
		for row in range(3):
			var product:int=delta[row]*int(frame.U[row*3+axis]);var term:=product>>31;var remainder:=product-term*Frame.Q31_DEN
			check(remainder>=0 and remainder<Frame.Q31_DEN,"Each signed Q31 multiply has an exact nonnegative floor remainder: "+label)
			numerator+=remainder
		check(int(mapped.floor_residual_numerators[axis])==numerator and numerator>=0 and numerator<=Frame.FLOOR_NUMERATOR_MAX,"Sum of three exact floor remainders is strictly below three query units: "+label)
	check(mapped.nonwrapping and mapped.linear_inverse_is_certificate==false,"Forward witness records its bounded domain without claiming a floating inverse certificate: "+label)
	var inverse:=Frame.inverse_linear_preview(frame,mapped.query_point_raw)
	check(inverse.get("ok",false),"Witnessed source point has a finite explicitly noncertifying inverse preview: "+label)
	if inverse.get("ok",false):
		inverse_previews+=1
		check(inverse.model_point_scaled_f64 is PackedFloat64Array and inverse.bodyfixed_metres_f64 is PackedFloat64Array and inverse.scaled_model_floor_region_f64.size()==3,"Inverse preview retains scalar double coordinates and a peraxis floor region: "+label)
		check(inverse.floor_region_is_float64_preview and not inverse.linear_inverse_is_certificate and not inverse.unique_integer_inverse_claim and inverse.q31_floor_residual_interval_raw==[0,3] and inverse.q31_floor_residual_upper_exclusive,"Inverse preview explicitly preserves quantization and never asserts a unique signed32 inverse: "+label)

func native_frame_controls()->void:
	var data:=fixture(NATIVE)
	if data.is_empty():return
	check(data.source_sha256==Natural.SOURCE_SHA and data.fresh_process_runs_per_bank==3 and not data.python_expected_frame_or_subtraction_arithmetic,"Frame oracle identifies original executable and fresh MOV-observed native execution")
	check(data.frame_cases.size()==int(data.frame_case_count) and data.frame_reverse_repeat_count==data.frame_case_count,"Every native frame control repeats unchanged in reverse order")
	for sample:Dictionary in data.frame_cases:
		native_cases+=1
		for observed:Dictionary in sample.expected.frames:
			if not observed.query_frame_observed:
				native_coarse+=1
				continue
			var label:=str(sample.id)+" child"+str(observed.child_index);var observer:=ints(observed.observer_model_local_raw);var before:=var_to_bytes(observer)
			var frame:=Frame.build(int(sample.parent_model),observer,int(observed.vector_scale_s32));native_frames+=1
			if int(sample.parent_model)>133:
				native_unsupported+=1
				check(not frame.ok and frame.reason=="unsupported_solid_model","Retained non-solid history frame is explicitly outside the new solid mapping contract: "+label)
				continue
			check(frame.has("U") and frame.frame_matches_immutable_point,"Every actually built native frame has unchanged Point identity: "+label)
			if not frame.has("U"):continue
			check(var_to_bytes(observer)==before,"Frame construction leaves the actual source observer unchanged: "+label)
			check(same(frame.O,observed.source_origin_raw) and same(frame.D,observed.center_difference_raw) and same(frame.working_difference_raw,observed.working_difference_raw),"Native origin and both original centre vectors match all signed32 words: "+label)
			check(same(frame.U,observed.U_q31) and same(frame.C,observed.C_raw) and same(frame.A,observed.A_raw),"All native Q31 rotation, query centre and original basis words match exactly: "+label)
			check(same(frame.T_D,observed.native_U_times_D_raw) and frame.xy_rotation_taken==observed.xy_rotation_taken and frame.yz_rotation_taken==observed.yz_rotation_taken,"Independent native F1669 diagnostic and actual source branch decisions match: "+label)
			var pole:=int(frame.D[0])==0 and int(frame.D[1])==0 and int(frame.D[2])<0;var diagnostic:=PackedInt64Array();var delta:=PackedInt64Array();var observer_delta:=PackedInt64Array()
			for axis in range(3):observer_delta.append(observer[axis]-int(frame.O[axis]))
			var quantized_observer:=Point._transform(observer_delta,frame.U)
			for axis in range(3):
				diagnostic.append(int(frame.C[axis])-int(frame.T_D[axis]));delta.append(int(frame.C[axis])+quantized_observer[axis])
				check(int(frame.q31_floor_nonoddness_raw[axis])==int(frame.T_D[axis])+quantized_observer[axis] and int(frame.q31_floor_nonoddness_raw[axis])>=-3 and int(frame.q31_floor_nonoddness_raw[axis])<=0,"Original signed Q31 floor non-oddness is exposed exactly, not discarded: "+label)
			var wrapped_delta:=PackedInt64Array()
			for axis in range(3):wrapped_delta.append(Math.signed32(delta[axis]))
			check(frame.antiparallel_axis_degeneracy==pole and frame.source_qorigin_delta_raw==wrapped_delta and frame.source_qorigin_delta_unwrapped_raw==delta and frame.center_minus_rotated_difference_raw==diagnostic,"Actual signed32 source actor query origin and separate C-minus-T(D) diagnostic remain distinct, including the exact pole predicate: "+label)
			check(observed.has("native_U_times_negative_D_raw") and observed.has("native_observer_forward_q_raw"),"Independent original native operations observe negative-D transform and actor-origin translation: "+label)
			if observed.has("native_U_times_negative_D_raw") and observed.has("native_observer_forward_q_raw"):
				check(same(frame.observer_minus_origin_raw,observed.native_negative_D_raw) and same(frame.rotated_observer_minus_origin_raw,observed.native_U_times_negative_D_raw),"All original native NEG and F1669 negative-D output words match the actual observer transform: "+label)
				check(same(frame.source_qorigin_delta_raw,observed.native_observer_forward_q_raw) and same(frame.center_minus_rotated_difference_raw,observed.native_center_minus_rotated_difference_raw),"Original native signed32 translation independently confirms actual observer origin and its distinct legacy diagnostic: "+label)
			check(frame.native_f581_execution_claim==false and frame.parent_frame_conversion_performed==false and frame.linear_inverse_is_certificate==false,"Reconstructed metadata does not imply extra native execution, parent transform or render equivalence: "+label)
			if pole:
				native_poles+=1
				check(not frame.ok and frame.reason=="native_antiparallel_axis_frame" and not Frame.inverse_linear_preview(frame,PackedInt64Array([0,0,0])).ok,"Original antiparallel-axis metadata is available but bodyfixed inverse publication is rejected: "+label)
			else:
				check(frame.ok and frame.mapping_admissible,"Nondegenerate native frame is explicitly admissible for bounded helpers: "+label)
				inspect_forward(frame,observer,label+" source observer")
				for corner in range(4):inspect_forward(frame,frame.model_vertices_raw[corner],label+" basis"+str(corner))
				var matched:=false
				for visit:Dictionary in sample.expected.footprint.volume_trace:
					if int(visit.child_index)!=int(observed.child_index):continue
					matched=true
					check(visit.winning_triangle.captured,"An actual admissible native query supplies its observed leaf, rather than a synthetic mesh: "+label)
					if not visit.winning_triangle.captured:continue
					var positions:Array=[]
					for vertex:Array in visit.winning_triangle.positions_raw:positions.append(ints(vertex))
					var inputs:=var_to_bytes([frame,positions]);var preview:=Frame.source_leaf_to_bodyfixed_f64(frame,positions)
					check(preview.get("ok",false),"Actual native leaf has a finite bounded scalar64 preview: "+label)
					if not preview.get("ok",false):continue
					native_leaf_previews+=1
					check(preview.vertices_bodyfixed_metres_f64.size()==3 and preview.vertex_previews.size()==3 and not preview.render_provider_or_collision_response and var_to_bytes([frame,positions])==inputs,"Actual native leaf preview retains three private source vertices and makes no publication claim: "+label)
					for vertex in range(3):check(preview.vertex_previews[vertex].query_point_raw==positions[vertex] and not preview.vertex_previews[vertex].linear_inverse_is_certificate and not preview.vertex_previews[vertex].unique_integer_inverse_claim,"Native leaf vertex preview retains the exact source query input without claiming a unique integer inverse: "+label)
				check(matched,"Native frame and observed winning leaf are bound by the actually visited child index: "+label)
	check(native_cases==int(data.frame_case_count) and native_frames>0 and native_poles>0 and native_coarse>0,"Every frame case is consumed and native poles/coarse early returns remain distinct")
	evidence.append({"case":"independent_native_frames","cases":native_cases,"observed_query_frames":native_frames,"unsupported_legacy_history_frames":native_unsupported,"coarse_without_query_frame":native_coarse,"antiparallel_frames_rejected_for_mapping":native_poles,"actual_native_leaf_previews":native_leaf_previews,"O_D_workingD_U_C_A_and_native_UD_exact":true,"unobserved_coarse_frame_claim":false})

func old_classifier_controls()->void:
	var data:=fixture(ORIGINAL)
	if data.is_empty():return
	var original:=Natural.new()
	for sample:Dictionary in data.cases:
		var body:=str(sample.player_object_hex).hex_decode();var parent:=str(sample.parent_object_hex).hex_decode();var relative:=vector_hex(str(sample.relative_before_hex));var context:Dictionary=sample.context.duplicate(true)
		var before:=var_to_bytes([body,parent,relative,context]);var actual:=original.classify_natural_player(body,parent,relative,context);original_cases+=1
		check(actual.get("ok",false) and int(actual.f576_return_s32)==int(sample.expected.f576_return_s32) and same(actual.globals_after,sample.expected.globals),"Immutable full classifier still matches its existing independently native-proved return and globals: "+str(sample.name))
		check(actual.body_after==str(sample.expected.player_hex).hex_decode() and actual.parent_after==str(sample.expected.parent_hex).hex_decode() and actual.relative_position_s64==vector_hex(str(sample.expected.relative_after_hex)) and var_to_bytes([body,parent,relative,context])==before,"Existing native buffers and caller inputs remain unchanged: "+str(sample.name))
		for query:Dictionary in actual.query_trace:
			if parent.decode_u32(0x82)>133:continue
			var frame:=Frame.build(parent.decode_u32(0x82),query.observer_model_local_raw,int(query.vector_scale_s32));original_frames+=1
			check(frame.has("A") and frame.A==query.query_matrix_raw and frame.C==query.query_center_raw and int(frame.query_style_raw)==int(query.query_style_raw) and int(frame.query_limit_raw)==int(query.query_limit_raw),"New metadata exactly matches an actually visited immutable old classifier frame: "+str(sample.name))
	check(original_cases==993 and original_frames>0,"All993 old native cases and their supported visited query frames are retained")
	evidence.append({"case":"old_native_classifier_unchanged","cases":original_cases,"supported_visited_query_frames":original_frames,"independent_native_execution_repeated_by_this_test":false})

func old_root_controls()->void:
	var data:=fixture(ROOT)
	if data.is_empty():return
	var original:=Point.new()
	for sample:Dictionary in data.geometry_cases:
		var observer:=ints(sample.expected.observer_model_local_raw);var scale:=int(sample.expected.vector_scale_s32);var model:=int(sample.model_index)
		var baseline:=original.frame_raw(model,observer,scale);var frame:=Frame.build(model,observer,scale);root_frames+=1
		check(frame.has("A") and frame.A==baseline.query_matrix_raw and frame.C==baseline.query_center_raw and frame.features_hex==baseline.features.hex_encode(),"Old signed-root basis/centre/features remain exact: "+str(sample.id))
		if frame.get("ok",false):inspect_forward(frame,observer,str(sample.id))
	check(root_frames==153,"All153 existing native-proved signed-root frames are consumed")
	evidence.append({"case":"old_signed_root_frames","frames":root_frames,"native_float_plane_equivalence_claim":false})

func precision_and_rejection_controls()->void:
	var frame:=Frame.build(120,PackedInt64Array([100000000,200000000,-300000000]),3)
	check(frame.get("ok",false),"General nonaxis test frame is admissible")
	if not frame.get("ok",false):return
	var frozen:=var_to_bytes(frame);var point:=PackedInt64Array([1234567,-7654321,3131313]);inspect_forward(frame,point,"mixed signed test point")
	check(frame.source_qorigin_delta_raw==PackedInt64Array([-1,-2,0]) and frame.center_minus_rotated_difference_raw==PackedInt64Array([1,1,3]) and frame.q31_floor_nonoddness_raw==PackedInt64Array([-2,-3,-3]),"Concrete nonaxis observer catches every peraxis non-odd Q31 origin correction")
	var axis_frame:=Frame.build(120,PackedInt64Array([0,0,-300000000]),3)
	check(axis_frame.ok and axis_frame.source_qorigin_delta_raw==PackedInt64Array([0,0,0]) and axis_frame.center_minus_rotated_difference_raw==PackedInt64Array([0,0,1]),"Concrete non-antiparallel Z-axis observer origin is zero even though C-minus-T(D) is one")
	var wrapping_pole:=Frame.build(120,PackedInt64Array([0,0,2000000000]),3)
	check(not wrapping_pole.ok and wrapping_pole.reason=="native_antiparallel_axis_frame" and wrapping_pole.C==PackedInt64Array([0,0,2000000006]) and wrapping_pole.source_qorigin_delta_raw==PackedInt64Array([0,0,-294967291]) and wrapping_pole.source_qorigin_delta_unwrapped_raw==PackedInt64Array([0,0,4000000005]) and not wrapping_pole.source_qorigin_delta_nonwrapping,"Rejected wrapping antiparallel metadata retains approximated F1466 distance, exact native signed32 origin and separate unwrapped diagnostic without admitting an affine map")
	var copy:=frame.duplicate(true)
	check(Frame.map_model_point_raw(copy,point).get("ok",false),"A private deep copy retains exact canonical frame identity")
	for key:String in ["U","A","C","source_qorigin_delta_raw","model_vertices_raw","linear_query_to_model_rows_f64"]:
		copy=frame.duplicate(true)
		if key=="model_vertices_raw":copy[key][0][0]+=1
		else:copy[key][0]+=1
		check(not Frame.map_model_point_raw(copy,point).ok,"Modified frame metadata cannot authorize a mapping: "+key)
	copy=frame.duplicate(true);copy["extra_certificate"]=true
	check(not Frame.map_model_point_raw(copy,point).ok and var_to_bytes(frame)==frozen,"Unknown metadata cannot silently authorize a mapping and caller mutation never changes the original")
	for value:Variant in [116,134,-1,120.5,NAN,INF,"120",true]:check(not Frame.build(value,PackedInt64Array([1,2,3]),3).ok,"Unsupported model input is rejected by a typed result")
	for value:Variant in [-1,31,3.5,NAN,INF,"3",true]:check(not Frame.build(120,PackedInt64Array([1,2,3]),value).ok,"Unsupported source scale input is rejected by a typed result")
	check(not Frame.build(120,PackedInt64Array([0,0,0]),3).ok and not Frame.build(120,PackedInt64Array([2147483648,0,0]),3).ok and not Frame.build(120,PackedInt64Array([1,2]),3).ok,"Undefined distance, outofrange source observer and malformed point are rejected")
	check(not Frame.build(133,PackedInt64Array([1,2,3]),0).ok,"Below-native minimum vector scale is rejected")
	check(Frame._inverse_rows(PackedFloat64Array([1,0,0,0,0,0,0,0,1])).is_empty() and Frame._inverse_rows(PackedFloat64Array([NAN,0,0,0,1,0,0,0,1])).is_empty(),"Noninvertible and nonfinite linear frames have no preview inverse")
	check(not Frame.map_model_point_raw(frame,PackedInt64Array([2147483648,0,0])).ok and not Frame.inverse_linear_preview(frame,PackedInt64Array([1,2])).ok,"Outofdomain source and malformed query points cannot reach arithmetic")
	check(not Frame._transform_witness(PackedInt64Array([2147483647,2147483647,2147483647]),PackedInt64Array([2147483647,0,0,2147483647,0,0,2147483647,0,0])).ok,"Signed32 accumulation wrapping is a typed rejection, never an affine inverse")
	for xyz:PackedFloat64Array in [PackedFloat64Array([NAN,0,0]),PackedFloat64Array([INF,0,0]),PackedFloat64Array([1,2]),PackedFloat64Array([1e20,0,0])]:check(not Frame.project_bodyfixed_f64(frame,xyz).ok,"Nonfinite, malformed or imprecise bodyfixed input is rejected")
	var bodyfixed:=PackedFloat64Array([Units.metres(1234567.0*8),Units.metres(-7654321.0*8),Units.metres(3131313.0*8)]);var projected:=Frame.project_bodyfixed_f64(frame,bodyfixed)
	check(projected.get("ok",false) and projected.model_point_raw==point,"Existing nearest raw64 then original SAR recovers a source scaled point exactly")
	if projected.get("ok",false):
		for axis in range(3):check(projected.source_sar_remainders_raw_s64[axis]>=0 and projected.source_sar_remainders_raw_s64[axis]<8 and absf(projected.raw_rounding_error_f64[axis])<=0.5,"Phone conversion exposes exact SAR remainder and measured raw rounding independently")
	var offset:=PackedFloat64Array([Units.metres(1001.0),Units.metres(-1001.0),Units.metres(1111.0)]);var offset_result:=Frame.project_bodyfixed_f64(frame,offset)
	check(offset_result.get("ok",false) and offset_result.unscaled_raw_point_s64==PackedInt64Array([1001,-1001,1111]) and offset_result.source_sar_remainders_raw_s64==PackedInt64Array([1,7,7]),"Negative original arithmetic SAR retains its positive low-bit remainder instead of truncating toward zero")
	for basis:Basis in [Basis.IDENTITY,Basis(Vector3(1,2,3).normalized(),0.43)]:
		var local:=Vector3(12.34567,-7.89123,3.45678);var radius:=1000000.125;var expected_body:=Phone.to_bodyfixed_point(basis,radius,local)
		var expected:=Frame.project_bodyfixed_f64(frame,expected_body);var actual:=Frame.project_phone_vertex_f32(frame,local,basis,radius)
		check(actual.get("ok",false) and expected.get("ok",false) and actual.query_point_raw==expected.query_point_raw and actual.bodyfixed_metres_f64==expected_body,"Actual Float32 local vertex and basis project through the unchanged scalar64 phone adapter")
		if actual.get("ok",false):
			phone_witnesses+=1
			var witnessed:=Frame.project_phone_vertex_f32(frame,local,basis,radius,actual.query_point_raw)
			check(witnessed.query_roundtrip_exact and witnessed.query_roundtrip_delta_raw_s64==PackedInt64Array([0,0,0]) and not witnessed.render_geometry_certificate,"Exact integer forward equality is recorded without a mesh/native equivalence claim")
			check(actual.phone_vertex_float32_hex==PackedFloat32Array([local.x,local.y,local.z]).to_byte_array().hex_encode() and actual.phone_basis_float32_hex.length()==72 and actual.reference_radius_f64_hex.length()==16,"Actual emitted Float32 vertex/basis and scalar64 radius bytes are preserved")
	check(not Frame.project_phone_vertex_f32(frame,Vector3(INF,0,0),Basis.IDENTITY,1).ok and not Frame.project_phone_vertex_f32(frame,Vector3.ZERO,Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),1).ok and not Frame.project_phone_vertex_f32(frame,Vector3.ZERO,Basis.IDENTITY,-1).ok,"Invalid actual phone vertex, basis and radius are rejected")
	var leaf:=[PackedInt64Array([1000,2000,3000]),PackedInt64Array([3000,-2000,1000]),PackedInt64Array([-2000,3000,-1000])];var before:=var_to_bytes([frame,leaf]);var preview:=Frame.source_leaf_to_bodyfixed_f64(frame,leaf)
	check(preview.get("ok",false) and preview.vertices_bodyfixed_metres_f64.size()==3 and preview.vertex_previews.size()==3 and not preview.render_provider_or_collision_response and var_to_bytes([frame,leaf])==before,"Three sourceleaf vertices yield private scalar64 previews without publication or response")
	check(not Frame.source_leaf_to_bodyfixed_f64(frame,[]).ok and not Frame.source_leaf_to_bodyfixed_f64(frame,[[0,0,0],[1,2,3],[3,2,1]]).ok,"Malformed leaf sizes and noncanonical source vertex types are rejected")
	evidence.append({"case":"precision_and_mutation_guards","phone_float32_forward_witnesses":phone_witnesses,"strict_canonical_frame":true,"integer_floor_residuals_proven_in_nonwrapping_domain":true,"inverse_and_floor_region_are_float64_previews":true,"old_phone_adapter_used_verbatim":true})

func run()->void:
	native_frame_controls();old_classifier_controls();old_root_controls();precision_and_rejection_controls()
	var sources:Dictionary={}
	for path:String in ["scripts/source_terrain_query_frame.gd","tests/test_source_terrain_query_frame.gd","scripts/source_terrain_point.gd","scripts/source_terrain_query.gd","scripts/source_natural_contact.gd","scripts/source_surface_contact_bridge.gd","scripts/source_physics_bridge.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	var report:={"schema":1,"source_contract":Frame.CONTRACT,"checks":checks,"failures":failures,"native_frame_cases":native_cases,"native_observed_frames":native_frames,"native_unsupported_legacy_frames":native_unsupported,"native_coarse_without_frame":native_coarse,"native_antiparallel_frames":native_poles,"native_leaf_previews":native_leaf_previews,"existing_native_classifier_cases":original_cases,"existing_supported_classifier_frames":original_frames,"existing_root_frames":root_frames,"exact_forward_points":forward_points,"noncertifying_inverse_previews":inverse_previews,"phone_float32_witnesses":phone_witnesses,"sources":sources,"fixtures":{"native_frames_sha256":FileAccess.get_sha256(NATIVE),"old_classifier_sha256":FileAccess.get_sha256(ORIGINAL),"old_signed_root_sha256":FileAccess.get_sha256(ROOT)},"evidence":evidence,"scope":"Read-only metadata for original F581 Q31 query-frame construction; exact native U/O/D/C/A and Point forward identity. Literal original positive-Z antiparallel branch is retained as rejected metadata. Exact floor numerator/SAR/rounding witnesses are distinct from noncertifying scalar64 inverse previews. No old kernel mutation, generic inverse uniqueness, float-plane native contact equivalence, fullmesh/body surface certificate, provider publication, sourcebank/physics/HP/time or live Android claim."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SOURCE TERRAIN QUERY FRAME TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
