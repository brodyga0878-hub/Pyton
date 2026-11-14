extends RefCounted
# Exact integer metadata for the unchanged F581 frame construction. The
# forward map preserves source Q31 floors; its linear inverse is a preview,
# not an exact inverse of the integer map or a render/collision certificate.
const Natural=preload("res://scripts/source_natural_contact.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Math=preload("res://scripts/ground_coordinates.gd")
const Units=preload("res://scripts/source_units.gd")
const Physics=preload("res://scripts/source_physics_bridge.gd")
const Phone=preload("res://scripts/source_surface_contact_bridge.gd")
const CONTRACT:="source-f581-quantized-query-frame-v1"
const Q31_DEN:=2147483648
const MAX_Q31:=2147483647
const MIN_S32:=-2147483648
const MAX_EXACT_PHONE_RAW:=0x10000000000000
const FLOOR_NUMERATOR_MAX:=6442450941 # 3*(2^31-1), strictly less than3 units.

static func _failure(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"error":reason,"source_contract":CONTRACT,"mapping_admissible":false,"linear_inverse_is_certificate":false}
static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _s32_vector(value:PackedInt64Array)->bool:
	if value.size()!=3:return false
	for component:int in value:
		if component<MIN_S32 or component>MAX_Q31:return false
	return true
static func _f64_vector(value:PackedFloat64Array)->bool:
	if value.size()!=3:return false
	for component:float in value:
		if not is_finite(component):return false
	return true
static func _inverse_rows(rows:PackedFloat64Array)->PackedFloat64Array:
	if rows.size()!=9:return PackedFloat64Array()
	var a:=rows[0];var b:=rows[1];var c:=rows[2];var d:=rows[3];var e:=rows[4];var f:=rows[5];var g:=rows[6];var h:=rows[7];var i:=rows[8]
	var det:=a*(e*i-f*h)-b*(d*i-f*g)+c*(d*h-e*g)
	if not is_finite(det) or det==0.0:return PackedFloat64Array()
	var result:=PackedFloat64Array([(e*i-f*h)/det,(c*h-b*i)/det,(b*f-c*e)/det,(f*g-d*i)/det,(a*i-c*g)/det,(c*d-a*f)/det,(d*h-e*g)/det,(b*g-a*h)/det,(a*e-b*d)/det])
	for value:float in result:
		if not is_finite(value):return PackedFloat64Array()
	return result
static func _linear(rows:PackedFloat64Array,value:PackedFloat64Array)->PackedFloat64Array:
	var result:=PackedFloat64Array()
	for axis in range(3):result.append(rows[axis*3]*value[0]+rows[axis*3+1]*value[1]+rows[axis*3+2]*value[2])
	return result
static func _transform_witness(value:PackedInt64Array,matrix:PackedInt64Array)->Dictionary:
	# Each product fits signed64. Reject source wrapping rather than treating
	# the resulting integer map as a continuous affine transformation.
	var sums:=PackedInt64Array();var remainders:=PackedInt64Array()
	for axis in range(3):
		var sum:=0;var residual:=0
		for row in range(3):
			var product:int=value[row]*matrix[row*3+axis];var term:=product>>31
			if term<MIN_S32 or term>MAX_Q31:return _failure("q31_product_wrap")
			sum+=term
			if sum<MIN_S32 or sum>MAX_Q31:return _failure("q31_accumulation_wrap")
			residual+=product-(term<<31)
		sums.append(sum);remainders.append(residual)
	if sums!=Point._transform(value,matrix):return _failure("immutable_transform_identity_failed")
	return {"ok":true,"value":sums,"floor_residual_numerators":remainders,"floor_residual_denominator":Q31_DEN,"nonwrapping":true}

static func build(model_index:Variant,observer_model_local_raw:PackedInt64Array,vector_scale:Variant)->Dictionary:
	if not _whole(model_index,117,133):return _failure("unsupported_solid_model")
	if not _whole(vector_scale,0,30):return _failure("unsupported_source_vector_scale")
	if not _s32_vector(observer_model_local_raw):return _failure("invalid_source_observer")
	var index:=int(model_index);var scale:=int(vector_scale);var model:=Natural.parent_model(index)
	if model.is_empty():return _failure("unverified_original_model")
	if scale<maxi(0,int(model.mesh_zoom)-23):return _failure("below_original_f579_minimum_scale")
	var observer:=observer_model_local_raw.duplicate();var vertices:Array=[]
	for corner in range(4):vertices.append(Point._source_vertex(model.vertices,int(model.payload[corner]),int(model.mesh_zoom)-scale))
	var origin:PackedInt64Array=vertices[0];var difference:=PackedInt64Array()
	for axis in range(3):
		var component:int=origin[axis]-observer[axis]
		if component<MIN_S32 or component>MAX_Q31:return _failure("source_origin_subtraction_wrap")
		difference.append(component)
	var distance:=Point.source_length(difference)
	if distance<=0:return _failure("undefined_original_source_distance")
	var matrix:=PackedInt64Array([MAX_Q31,0,0,0,MAX_Q31,0,0,0,MAX_Q31]);var working:=difference.duplicate()
	var xy_taken:=working[0]!=0;var xy_length:=0;var yz_length:=0
	if xy_taken:
		xy_length=Point.source_length(PackedInt64Array([working[0],working[1],0]))
		if xy_length<=0:return _failure("undefined_original_xy_distance")
		var first:=Point._normalized_component(working[0],xy_length);var second:=Point._normalized_component(working[1],xy_length)
		matrix=PackedInt64Array([second,first,0,Math.signed32(-first),second,0,0,0,MAX_Q31]);working[1]=xy_length
	var yz_taken:=working[1]!=0
	if yz_taken:
		yz_length=Point.source_length(PackedInt64Array([0,working[1],working[2]]))
		if yz_length<=0:return _failure("undefined_original_yz_distance")
		var first:=Point._normalized_component(working[1],yz_length);var second:=Point._normalized_component(working[2],yz_length)
		for row in range(2):matrix[row*3+2]=Math.multiply_q31(matrix[row*3+1],first);matrix[row*3+1]=Math.multiply_q31(matrix[row*3+1],second)
		matrix[7]=Math.signed32(-first);matrix[8]=second
	var query_matrix:=PackedInt64Array()
	for corner in range(1,4):
		var delta:=PackedInt64Array()
		for axis in range(3):
			var component:int=vertices[corner][axis]-origin[axis]
			if component<MIN_S32 or component>MAX_Q31:return _failure("source_vertex_subtraction_wrap")
			delta.append(component)
		var transformed:=_transform_witness(delta,matrix)
		if not transformed.ok:return transformed
		query_matrix.append_array(transformed.value)
	var center:=PackedInt64Array([0,0,distance]);var transformed_difference:=_transform_witness(difference,matrix)
	if not transformed_difference.ok:return transformed_difference
	var rotated:PackedInt64Array=transformed_difference.value;var origin_delta:=PackedInt64Array()
	for axis in range(3):origin_delta.append(int(center[axis])-rotated[axis])
	# Q31 flooring is not odd: T(-D) is generally not -T(D). The
	# actor's actual query origin is C+T(observer-O), not C-T(D).
	var observer_delta:=PackedInt64Array()
	for axis in range(3):
		var component:int=observer[axis]-origin[axis]
		if component<MIN_S32 or component>MAX_Q31:return _failure("source_observer_subtraction_wrap")
		observer_delta.append(component)
	var transformed_observer:=_transform_witness(observer_delta,matrix)
	if not transformed_observer.ok:return transformed_observer
	var actual_origin:=PackedInt64Array();var unwrapped_origin:=PackedInt64Array();var nonoddness:=PackedInt64Array();var origin_nonwrapping:=true
	for axis in range(3):
		var component:int=int(center[axis])+int(transformed_observer.value[axis]);unwrapped_origin.append(component);actual_origin.append(Math.signed32(component))
		if component<MIN_S32 or component>MAX_Q31:origin_nonwrapping=false
		nonoddness.append(rotated[axis]+int(transformed_observer.value[axis]))
	var immutable:=Point.new().frame_raw(index,observer,scale)
	if immutable.is_empty() or immutable.query_matrix_raw!=query_matrix or immutable.query_center_raw!=center or int(immutable.query_style_raw)!=int(model.payload.decode_u16(4)) or immutable.features!=model.payload.slice(6):return _failure("immutable_frame_identity_failed")
	var linear:=PackedFloat64Array()
	for axis in range(3):
		for row in range(3):linear.append(float(matrix[row*3+axis])/Q31_DEN)
	var inverse:=_inverse_rows(linear)
	if inverse.size()!=9:return _failure("noninvertible_linear_frame")
	var pole:=difference[0]==0 and difference[1]==0 and difference[2]<0
	var result:={"ok":not pole,"reason":"native_antiparallel_axis_frame" if pole else "source_quantized_frame_ready","error":"native_antiparallel_axis_frame" if pole else "","source_contract":CONTRACT,"mapping_admissible":not pole,"model_index":index,"vector_scale_s32":scale,"observer_model_local_raw":observer,"O":origin.duplicate(),"D":difference.duplicate(),"U":matrix.duplicate(),"A":query_matrix.duplicate(),"C":center.duplicate(),"T_D":rotated.duplicate(),"origin_model_raw":origin.duplicate(),"center_before_rotation_raw":difference.duplicate(),"rotation_q31_raw":matrix.duplicate(),"query_matrix_raw":query_matrix.duplicate(),"query_center_raw":center.duplicate(),"rotated_center_raw":rotated.duplicate(),"source_qorigin_delta_raw":origin_delta,"working_difference_raw":working,"xy_rotation_taken":xy_taken,"yz_rotation_taken":yz_taken,"antiparallel_axis_degeneracy":pole,"xy_length_s32":xy_length,"yz_length_s32":yz_length,"source_distance_s32":distance,"model_vertices_raw":vertices,"query_style_raw":int(immutable.query_style_raw),"query_limit_raw":int(immutable.query_limit_raw),"features_hex":immutable.features.hex_encode(),"frame_matches_immutable_point":true,"source_quantum_raw_s64":1<<scale,"source_quantum_metres":Units.metres(float(1<<scale)),"linear_model_to_query_rows_f64":linear,"linear_query_to_model_rows_f64":inverse,"q31_floor_residual_interval_raw":[0,3],"q31_floor_residual_upper_exclusive":true,"q31_floor_residual_numerator_max":FLOOR_NUMERATOR_MAX,"q31_floor_residual_denominator":Q31_DEN,"linear_inverse_is_certificate":false,"native_f581_execution_claim":false,"parent_frame_conversion_performed":false}
	result["center_minus_rotated_difference_raw"]=origin_delta
	result["observer_minus_origin_raw"]=observer_delta
	result["rotated_observer_minus_origin_raw"]=transformed_observer.value.duplicate()
	result["q31_floor_nonoddness_raw"]=nonoddness
	result["source_qorigin_delta_raw"]=actual_origin
	result["source_qorigin_delta_unwrapped_raw"]=unwrapped_origin
	result["source_qorigin_delta_nonwrapping"]=origin_nonwrapping
	if not pole and not origin_nonwrapping:
		result["ok"]=false;result["mapping_admissible"]=false;result["reason"]="source_observer_query_addition_wrap";result["error"]=result.reason
	return result

static func _canonical(frame:Dictionary)->Dictionary:
	if not frame.get("ok") is bool or not frame.ok or not frame.get("observer_model_local_raw") is PackedInt64Array:return {}
	var expected:=build(frame.get("model_index"),frame.observer_model_local_raw,frame.get("vector_scale_s32"))
	if not expected.get("ok",false) or var_to_bytes(expected)!=var_to_bytes(frame):return {}
	return expected

static func map_model_point_raw(frame:Dictionary,model_point_raw:PackedInt64Array)->Dictionary:
	var source:=_canonical(frame)
	if source.is_empty():return _failure("invalid_or_rejected_source_frame")
	if not _s32_vector(model_point_raw):return _failure("invalid_scaled_model_point")
	var delta:=PackedInt64Array()
	for axis in range(3):
		var component:int=model_point_raw[axis]-int(source.O[axis])
		if component<MIN_S32 or component>MAX_Q31:return _failure("model_point_subtraction_wrap")
		delta.append(component)
	var transformed:=_transform_witness(delta,source.U)
	if not transformed.ok:return transformed
	var query:=PackedInt64Array()
	for axis in range(3):
		var component:int=int(source.C[axis])+int(transformed.value[axis])
		if component<MIN_S32 or component>MAX_Q31:return _failure("query_center_addition_wrap")
		query.append(component)
	return {"ok":true,"reason":"exact_nonwrapping_source_forward_map","source_contract":CONTRACT,"model_point_raw":model_point_raw.duplicate(),"query_point_raw":query,"transformed_model_delta_raw":transformed.value.duplicate(),"floor_residual_numerators":transformed.floor_residual_numerators.duplicate(),"floor_residual_denominator":Q31_DEN,"floor_residual_numerator_max":FLOOR_NUMERATOR_MAX,"nonwrapping":true,"linear_inverse_is_certificate":false}

static func inverse_linear_preview(frame:Dictionary,query_point_raw:PackedInt64Array)->Dictionary:
	# "bodyfixed" here is the original parent MODEL-LOCAL frame, after any
	# caller-supplied source parent transform. This helper performs none.
	var source:=_canonical(frame)
	if source.is_empty():return _failure("invalid_or_rejected_source_frame")
	if not _s32_vector(query_point_raw):return _failure("invalid_source_query_point")
	var delta:=PackedFloat64Array()
	for axis in range(3):delta.append(float(query_point_raw[axis])-float(source.C[axis]))
	var value:=_linear(source.linear_query_to_model_rows_f64,delta);var raw:=PackedFloat64Array();var metres:=PackedFloat64Array();var regions:Array=[]
	for axis in range(3):
		value[axis]+=float(source.O[axis])
		if not is_finite(value[axis]) or value[axis]<MIN_S32 or value[axis]>MAX_Q31:return _failure("inverse_preview_outside_scaled_source_domain")
		var unscaled:=value[axis]*float(source.source_quantum_raw_s64)
		if not is_finite(unscaled) or absf(unscaled)>MAX_EXACT_PHONE_RAW:return _failure("inverse_preview_outside_phone_precision_domain")
		raw.append(unscaled);metres.append(Units.metres(unscaled))
		var low:=value[axis];var high:=value[axis]
		for component in range(3):
			var bound:=float(source.linear_query_to_model_rows_f64[axis*3+component])*(float(FLOOR_NUMERATOR_MAX)/Q31_DEN)
			low+=minf(0,bound);high+=maxf(0,bound)
		regions.append(PackedFloat64Array([low,high]))
	return {"ok":true,"reason":"noncertifying_linear_inverse_preview","source_contract":CONTRACT,"query_point_raw":query_point_raw.duplicate(),"model_point_scaled_f64":value,"bodyfixed_raw_f64":raw,"bodyfixed_metres_f64":metres,"scaled_model_floor_region_f64":regions,"floor_region_is_float64_preview":true,"q31_floor_residual_interval_raw":[0,3],"q31_floor_residual_upper_exclusive":true,"q31_floor_residual_numerator_max":FLOOR_NUMERATOR_MAX,"q31_floor_residual_denominator":Q31_DEN,"linear_inverse_is_certificate":false,"unique_integer_inverse_claim":false,"source_qorigin_delta_raw":source.source_qorigin_delta_raw.duplicate()}

static func source_leaf_to_bodyfixed_f64(frame:Dictionary,positions_raw:Array)->Dictionary:
	# Returned metres retain that original parent model frame; no conversion
	# to a source world frame or an independently oriented phone frame occurs.
	if positions_raw.size()!=3:return _failure("invalid_source_leaf_size")
	var vertices:Array=[];var previews:Array=[]
	for point:Variant in positions_raw:
		if not point is PackedInt64Array:return _failure("invalid_source_leaf_point_type")
		var preview:=inverse_linear_preview(frame,point)
		if not preview.ok:return preview
		vertices.append(preview.bodyfixed_metres_f64.duplicate());previews.append(preview)
	return {"ok":true,"reason":"noncertifying_source_leaf_bodyfixed_preview","source_contract":CONTRACT,"vertices_bodyfixed_metres_f64":vertices,"vertex_previews":previews,"linear_inverse_is_certificate":false,"render_provider_or_collision_response":false}

static func project_bodyfixed_f64(frame:Dictionary,bodyfixed_metres_f64:PackedFloat64Array)->Dictionary:
	var source:=_canonical(frame)
	if source.is_empty():return _failure("invalid_or_rejected_source_frame")
	if not _f64_vector(bodyfixed_metres_f64):return _failure("invalid_bodyfixed_metres_point")
	var raw:=PackedInt64Array();var scaled:=PackedInt64Array();var sar_remainders:=PackedInt64Array();var rounding:=PackedFloat64Array()
	for value:float in bodyfixed_metres_f64:
		var real_raw:=Units.raw(value);var converted:=Physics.raw_metres(value)
		if converted.is_empty() or not is_finite(real_raw) or absf(real_raw)>MAX_EXACT_PHONE_RAW or absi(int(converted.raw))>MAX_EXACT_PHONE_RAW:return _failure("bodyfixed_point_outside_phone_precision_domain")
		var component:=int(converted.raw);var shifted:=Point.shift_int64(component,-int(source.vector_scale_s32))
		if shifted<MIN_S32 or shifted>MAX_Q31:return _failure("projected_point_truncation_wrap")
		raw.append(component);scaled.append(shifted);sar_remainders.append(component-(shifted<<int(source.vector_scale_s32)));rounding.append(float(component)-real_raw)
	var result:=map_model_point_raw(source,scaled)
	if not result.ok:return result
	result["bodyfixed_metres_f64"]=bodyfixed_metres_f64.duplicate();result["unscaled_raw_point_s64"]=raw;result["source_sar_remainders_raw_s64"]=sar_remainders;result["raw_rounding_error_f64"]=rounding
	result["source_rounding_policy"]="existing-source-physics-nearest-raw64-then-original-arithmetic-SAR-v1";result["source_quantum_raw_s64"]=int(source.source_quantum_raw_s64)
	result["linear_inverse_is_certificate"]=false
	return result

static func project_phone_vertex_f32(frame:Dictionary,local_vertex:Vector3,basis:Basis,reference_radius_m:float,expected_query_point_raw:PackedInt64Array=PackedInt64Array())->Dictionary:
	if not local_vertex.is_finite():return _failure("invalid_phone_float32_vertex")
	var bodyfixed:=Phone.to_bodyfixed_point(basis,reference_radius_m,local_vertex)
	if bodyfixed.size()!=3:return _failure("invalid_phone_surface_frame")
	var result:=project_bodyfixed_f64(frame,bodyfixed)
	if not result.ok:return result
	result["phone_vertex_float32_hex"]=PackedFloat32Array([local_vertex.x,local_vertex.y,local_vertex.z]).to_byte_array().hex_encode()
	result["phone_basis_float32_hex"]=PackedFloat32Array([basis.x.x,basis.x.y,basis.x.z,basis.y.x,basis.y.y,basis.y.z,basis.z.x,basis.z.y,basis.z.z]).to_byte_array().hex_encode()
	var radius_bytes:=PackedByteArray();radius_bytes.resize(8);radius_bytes.encode_double(0,reference_radius_m);result["reference_radius_f64_hex"]=radius_bytes.hex_encode()
	if not expected_query_point_raw.is_empty():
		if not _s32_vector(expected_query_point_raw):return _failure("invalid_expected_query_vertex")
		var difference:=PackedInt64Array()
		for axis in range(3):difference.append(int(result.query_point_raw[axis])-expected_query_point_raw[axis])
		result["expected_query_point_raw"]=expected_query_point_raw.duplicate();result["query_roundtrip_delta_raw_s64"]=difference;result["query_roundtrip_exact"]=result.query_point_raw==expected_query_point_raw
	result["render_geometry_certificate"]=false
	return result
