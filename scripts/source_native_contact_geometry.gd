extends RefCounted
# A packet of ONE observed original integer F1876 leaf and its declared phone
# rendering projection. This is not an ordinary-float collision-height proof,
# a full terrain mesh, a source object bank, or permission to apply F575.
const SourceFrame=preload("res://scripts/source_terrain_query_frame.gd")
const Natural=preload("res://scripts/source_natural_contact.gd")
const Query=preload("res://scripts/source_terrain_query.gd")
const Trace=preload("res://scripts/source_terrain_query_trace.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Phone=preload("res://scripts/source_surface_contact_bridge.gd")
const SurfaceFrame=preload("res://scripts/source_surface_render_state.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const CONTRACT:="source-observed-f1876-leaf-render-packet-v1"
const CERTIFIES:="fresh-original-integer-leaf-generation-intersection-and-declared-render-projection"
const TERRAIN_DATA_SHA:="8d764c2cd2a682ddfa8e0b8978b8f12616333ef361d0ed820dcb5b03b3f1977a"
const Q31:=2147483648.0
const I32_MIN:=-2147483648
const I32_MAX:=2147483647

static func _failure(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"packet":{},"certificate":{"ok":false,"reason":reason,"certifies":CERTIFIES,"live_response_enabled":false,"whole_mesh_certified":false,"float_collision_height_equivalence":false}}
static func _words(value:Variant,count:int)->PackedInt64Array:
	var flat:=PackedInt64Array()
	if not (value is Array or value is PackedInt64Array):return flat
	for item:Variant in value:
		if item is Array or item is PackedInt64Array:
			for word:Variant in item:
				if not Natural._whole(word,I32_MIN,I32_MAX):return PackedInt64Array()
				flat.append(int(word))
		else:
			if not Natural._whole(item,I32_MIN,I32_MAX):return PackedInt64Array()
			flat.append(int(item))
	return flat if flat.size()==count else PackedInt64Array()
static func _hex32(values:PackedInt64Array)->String:
	var raw:=PackedByteArray();raw.resize(values.size()*4)
	for index in range(values.size()):raw.encode_s32(index*4,values[index])
	return raw.hex_encode()
static func _hex64(values:PackedFloat64Array)->String:
	var raw:=PackedByteArray();raw.resize(values.size()*8)
	for index in range(values.size()):raw.encode_double(index*8,values[index])
	return raw.hex_encode()
static func _hex_f32(values:PackedFloat64Array)->String:
	var raw:=PackedByteArray();raw.resize(values.size()*4)
	for index in range(values.size()):raw.encode_float(index*4,values[index])
	return raw.hex_encode()
static func _canonical(value:Dictionary)->Dictionary:return JSON.parse_string(JSON.stringify(value))
static func packet_sha256(packet:Dictionary)->String:return JSON.stringify(packet,"",true).sha256_text()
static func _next64(value:float,up:bool)->float:
	var bytes:=PackedByteArray();bytes.resize(8)
	if value==0:
		bytes.encode_s64(0,1 if up else (-9223372036854775807))
	else:
		bytes.encode_double(0,value);var bits:=bytes.decode_s64(0);bits+=(1 if up else -1) if value>0 else (-1 if up else 1);bytes.encode_s64(0,bits)
	return bytes.decode_double(0)
static func _next32(value:float,up:bool)->float:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_float(0,value);var bits:=bytes.decode_u32(0)
	if value==0:bits=1 if up else 0x80000001
	else:bits+=(1 if up else -1) if value>0 else (-1 if up else 1)
	bytes.encode_u32(0,bits);return bytes.decode_float(0)
static func _i(value:float)->PackedFloat64Array:return PackedFloat64Array([value,value])
static func _valid_interval(value:PackedFloat64Array)->bool:return value.size()==2 and is_finite(value[0]) and is_finite(value[1]) and value[0]<=value[1]
static func _add(a:PackedFloat64Array,b:PackedFloat64Array)->PackedFloat64Array:return PackedFloat64Array([_next64(a[0]+b[0],false),_next64(a[1]+b[1],true)])
static func _sub(a:PackedFloat64Array,b:PackedFloat64Array)->PackedFloat64Array:return PackedFloat64Array([_next64(a[0]-b[1],false),_next64(a[1]-b[0],true)])
static func _mul(a:PackedFloat64Array,b:PackedFloat64Array)->PackedFloat64Array:
	var values:=[a[0]*b[0],a[0]*b[1],a[1]*b[0],a[1]*b[1]]
	return PackedFloat64Array([_next64(values.min(),false),_next64(values.max(),true)])
static func _div(a:PackedFloat64Array,b:PackedFloat64Array)->PackedFloat64Array:
	if b[0]<=0 and b[1]>=0:return PackedFloat64Array()
	var values:=[a[0]/b[0],a[0]/b[1],a[1]/b[0],a[1]/b[1]]
	return PackedFloat64Array([_next64(values.min(),false),_next64(values.max(),true)])
static func _cofactor(m:Array,a:int,b:int,c:int,d:int)->PackedFloat64Array:return _sub(_mul(m[a],m[b]),_mul(m[c],m[d]))
static func _inverse(rows:PackedFloat64Array)->Dictionary:
	if rows.size()!=9:return {}
	var m:Array=[]
	for value:float in rows:
		if not is_finite(value):return {}
		m.append(_i(value))
	var c:Array=[_cofactor(m,4,8,5,7),_cofactor(m,2,7,1,8),_cofactor(m,1,5,2,4),_cofactor(m,5,6,3,8),_cofactor(m,0,8,2,6),_cofactor(m,2,3,0,5),_cofactor(m,3,7,4,6),_cofactor(m,1,6,0,7),_cofactor(m,0,4,1,3)]
	var determinant:=_add(_add(_mul(m[0],c[0]),_mul(m[1],c[3])),_mul(m[2],c[6]))
	if not _valid_interval(determinant) or (determinant[0]<=0 and determinant[1]>=0):return {}
	var inverse_intervals:Array=[]
	for cell:PackedFloat64Array in c:
		var quotient:=_div(cell,determinant)
		if not _valid_interval(quotient):return {}
		inverse_intervals.append(quotient)
	var a:=rows[0];var b:=rows[1];var cc:=rows[2];var d:=rows[3];var e:=rows[4];var f:=rows[5];var g:=rows[6];var h:=rows[7];var ii:=rows[8]
	var det:=a*(e*ii-f*h)+b*(f*g-d*ii)+cc*(d*h-e*g)
	if not is_finite(det) or det==0:return {}
	var ordinary:=PackedFloat64Array([e*ii-f*h,cc*h-b*ii,b*f-cc*e,f*g-d*ii,a*ii-cc*g,cc*d-a*f,d*h-e*g,b*g-a*h,a*e-b*d])
	for index in range(9):ordinary[index]/=det
	return {"rows":ordinary,"intervals":inverse_intervals,"determinant_interval":determinant}
static func _linear(rows:PackedFloat64Array,vector:PackedFloat64Array)->PackedFloat64Array:
	var result:=PackedFloat64Array()
	for row in range(3):result.append(rows[row*3]*vector[0]+rows[row*3+1]*vector[1]+rows[row*3+2]*vector[2])
	return result
static func _linear_interval(rows:Array,vector:Array)->Array:
	var result:Array=[]
	for row in range(3):result.append(_add(_add(_mul(rows[row*3],vector[0]),_mul(rows[row*3+1],vector[1])),_mul(rows[row*3+2],vector[2])))
	return result
static func _rows_intervals(rows:PackedFloat64Array)->Array:
	var result:Array=[]
	for value:float in rows:result.append(_i(value))
	return result
static func _phone(frame:Dictionary)->Dictionary:
	if not frame.get("basis_f64") is Array or frame.basis_f64.size()!=9 or not Phone._number(frame.get("radius_m")) or float(frame.radius_m)<=0 or not Phone._number(frame.get("latitude")) or not Phone._number(frame.get("longitude")) or absf(float(frame.latitude))>PI*0.5 or absf(float(frame.longitude))>PI:return {}
	if not Natural._whole(frame.get("source_uid_u32"),0,0xffffffff) or not Natural._whole(frame.get("source_model_index"),117,133):return {}
	if frame.get("parent_frame_policy")!="isolated-matching-bodyfixed-parent-q31" or not Natural._whole(frame.get("source_body_parent_index_u8"),1,255) or not Natural._whole(frame.get("source_body_frame_u8"),1,255) or not Natural._whole(frame.get("source_parent_index_u8"),1,255) or int(frame.source_body_parent_index_u8)!=int(frame.source_parent_index_u8):return {}
	var parent_matrix:=PackedByteArray();parent_matrix.resize(36)
	for axis in range(3):parent_matrix.encode_s32(axis*16,0x7fffffff)
	if not frame.get("source_parent_matrix_q31_hex") is String or str(frame.source_parent_matrix_q31_hex)!=parent_matrix.hex_encode():return {}
	var expected:Basis=Terrain.new().basis_at(float(frame.latitude),float(frame.longitude));var basis:=PackedFloat64Array()
	for axis in [expected.x,expected.y,expected.z]:
		for component:float in [axis.x,axis.y,axis.z]:basis.append(component)
	for index in range(9):
		if not Phone._number(frame.basis_f64[index]) or float(frame.basis_f64[index])!=basis[index]:return {}
	var rows:=PackedFloat64Array([basis[0],basis[3],basis[6],basis[1],basis[4],basis[7],basis[2],basis[5],basis[8]])
	var inverse:=_inverse(rows)
	if inverse.is_empty():return {}
	return {"basis":basis,"rows":rows,"inverse":inverse,"radius":float(frame.radius_m),"uid":int(frame.source_uid_u32),"model":int(frame.source_model_index),"frame_f64_hex":_hex64(PackedFloat64Array([float(frame.latitude),float(frame.longitude),float(frame.radius_m)]))+_hex64(basis),"body_parent_index":int(frame.source_body_parent_index_u8),"body_frame":int(frame.source_body_frame_u8),"parent_index":int(frame.source_parent_index_u8),"parent_matrix_hex":parent_matrix.hex_encode()}
static func _frame_matches(given:Dictionary,fresh:Dictionary)->bool:
	for key:String in ["model_index","vector_scale_s32","xy_rotation_taken","yz_rotation_taken"]:
		if not given.has(key) or given[key]!=fresh[key]:return false
	for pair:Array in [["observer_model_local_raw",3],["origin_model_raw",3],["center_before_rotation_raw",3],["rotation_q31_raw",9],["query_center_raw",3],["query_matrix_raw",9],["rotated_center_raw",3],["source_qorigin_delta_raw",3]]:
		var first:=_words(given.get(pair[0]),int(pair[1]));var second:=_words(fresh.get(pair[0]),int(pair[1]))
		if first.size()!=int(pair[1]) or first!=second:return false
	return true
static func _leaf_matches(first:Dictionary,second:Dictionary)->bool:
	for pair:Array in [["positions_raw",9],["normals_raw",9],["vertex_ids_s32",3],["depths_s32",3],["heights_s32",3],["lands_s32",3],["sar_positions_raw",9]]:
		if _words(first.get(pair[0]),int(pair[1])).size()!=int(pair[1]) or _words(first.get(pair[0]),int(pair[1]))!=_words(second.get(pair[0]),int(pair[1])):return false
	for key:String in ["leaf_depth_s32","sar_shift_s32","recorded_intersection_raw"]:
		if not Natural._whole(first.get(key),I32_MIN,I32_MAX) or int(first[key])!=int(second.get(key,0)):return false
	if first.get("vertex_ids_are_native_pointers")!=false:return false
	var a:Variant=first.get("plane_fraction_calls");var b:Variant=second.get("plane_fraction_calls")
	if not a is Array or not b is Array or a.size()!=2 or b.size()!=2:return false
	for index in range(2):
		if not a[index] is Dictionary:return false
		for key:String in ["numerator_s32","denominator_s32","fraction_s32"]:
			if not Natural._whole(a[index].get(key),I32_MIN,I32_MAX) or int(a[index][key])!=int(b[index][key]):return false
	return true
static func _leaf_plane(vertices:PackedFloat64Array)->Dictionary:
	var x:=vertices[3]-vertices[0];var y:=vertices[4]-vertices[1];var z:=vertices[5]-vertices[2];var xx:=vertices[6]-vertices[0];var yy:=vertices[7]-vertices[1];var zz:=vertices[8]-vertices[2]
	var nx:=y*zz-z*yy;var ny:=z*xx-x*zz;var nz:=x*yy-y*xx
	if nx==0 and ny==0 and nz==0:return {"nondegenerate":false,"intercept_defined":false}
	if nz==0:return {"nondegenerate":true,"intercept_defined":false}
	var intercept:=vertices[2]+(nx*vertices[0]+ny*vertices[1])/nz
	return {"nondegenerate":true,"intercept_defined":is_finite(intercept),"intercept":intercept}
static func _forward_interval(local32:PackedFloat64Array,phone:Dictionary,frame:Dictionary)->PackedInt64Array:
	var local:Array=[_i(local32[0]),_add(_i(phone.radius),_i(local32[1])),_i(local32[2])]
	var body:Array=_linear_interval(_rows_intervals(phone.rows),local);var scaled:Array=[];var scale:=int(frame.vector_scale_s32)
	for axis in range(3):
		var raw:=_div(body[axis],_i(Phone.Units.METRES_PER_RAW))
		if not _valid_interval(raw) or raw[0]<=-9223372036854775808.0 or raw[1]>=9223372036854775808.0:return PackedInt64Array()
		scaled.append(PackedInt64Array([(roundi(raw[0])>>scale)-int(frame.origin_model_raw[axis]),(roundi(raw[1])>>scale)-int(frame.origin_model_raw[axis])]))
	var result:=PackedInt64Array();var rotation:PackedInt64Array=frame.rotation_q31_raw
	for column in range(3):
		var low:=int(frame.query_center_raw[column]);var high:=low
		for row in range(3):
			if scaled[row][0]<I32_MIN or scaled[row][1]>I32_MAX:return PackedInt64Array()
			var coefficient:=int(rotation[row*3+column]);var first:=(int(scaled[row][0])*coefficient)>>31;var second:=(int(scaled[row][1])*coefficient)>>31
			low+=mini(first,second);high+=maxi(first,second)
		if low<I32_MIN or high>I32_MAX:return PackedInt64Array()
		result.append(low);result.append(high)
	return result
static func build(source_frame:Dictionary,trace_row:Dictionary,phone_frame:Dictionary)->Dictionary:
	var phone:=_phone(phone_frame)
	if phone.is_empty():return _failure("invalid_or_stale_phone_frame")
	var observer:=_words(source_frame.get("observer_model_local_raw"),3)
	if observer.size()!=3 or not Natural._whole(source_frame.get("model_index"),117,133) or int(source_frame.model_index)!=phone.model or not Natural._whole(source_frame.get("vector_scale_s32"),0,31):return _failure("invalid_source_model_observer_or_scale")
	var frame:=SourceFrame.build(phone.model,observer,int(source_frame.vector_scale_s32))
	if not frame.get("ok",false):return _failure(str(frame.get("reason",frame.get("error","source_frame_mapping_unavailable"))))
	if source_frame.get("ok")!=true or not _frame_matches(source_frame,frame):return _failure("mismatched_or_stale_source_frame")
	var d:PackedInt64Array=frame.center_before_rotation_raw
	if d[0]==0 and d[1]==0 and d[2]<0:return _failure("original_antiparallel_zero_xy_axis_degeneracy")
	if FileAccess.get_sha256("res://data/ffe_terrain_query.json")!=TERRAIN_DATA_SHA:return _failure("unverified_original_terrain_resources")
	var query_frame:=Point.new().frame_raw(phone.model,observer,int(frame.vector_scale_s32))
	if query_frame.is_empty() or trace_row.get("query_ok")!=true or not Natural._whole(trace_row.get("source_uid_u32"),0,0xffffffff) or int(trace_row.source_uid_u32)!=phone.uid:return _failure("mismatched_query_uid_or_status")
	for pair:Array in [["style_s32",int(query_frame.query_style_raw)],["graphics_level_s32",1],["query_limit_s32",int(query_frame.query_limit_raw)]]:
		if not Natural._whole(trace_row.get(pair[0]),I32_MIN,I32_MAX) or int(trace_row[pair[0]])!=int(pair[1]):return _failure("mismatched_source_query_operands")
	if _words(trace_row.get("query_matrix_raw"),9)!=frame.query_matrix_raw or _words(trace_row.get("query_center_raw"),3)!=frame.query_center_raw or str(trace_row.get("features_hex",""))!=query_frame.features.hex_encode():return _failure("mismatched_source_query_geometry")
	var tracer:=Trace.new();var queried:=tracer.query_raw(phone.uid,int(query_frame.query_style_raw),frame.query_matrix_raw,frame.query_center_raw,int(query_frame.query_limit_raw),1,query_frame.features)
	var rows:=tracer.read_trace()
	if queried.is_empty() or rows.size()!=1 or rows[0].winning_triangle.is_empty() or int(queried.pending_query_flag)!=0:return _failure("no_defined_captured_source_leaf")
	var actual:Dictionary=rows[0];var leaf:Dictionary=actual.winning_triangle
	if not trace_row.get("result") is Dictionary or not trace_row.get("winning_triangle") is Dictionary:return _failure("missing_captured_leaf_or_query_result")
	for key:Variant in queried:
		if not trace_row.result.has(key) or not Natural._whole(trace_row.result[key],I32_MIN,0xffffffff) or int(trace_row.result[key])!=int(queried[key]):return _failure("mismatched_source_query_result")
	if not _leaf_matches(trace_row.winning_triangle,leaf):return _failure("mismatched_native_leaf_or_quantization")
	var positions:=_words(leaf.positions_raw,9);var vertices:Array=[]
	for index in range(3):vertices.append({"p":positions.slice(index*3,index*3+3)})
	var original:=Query.new();var replay:=original._intersection(vertices)
	if original.invalid_query or replay!=int(leaf.recorded_intersection_raw) or replay!=int(queried.recorded_intersection_raw):return _failure("original_integer_intersection_replay_mismatch")
	var rotation:PackedInt64Array=frame.rotation_q31_raw;var source_rows:=PackedFloat64Array()
	for row in range(3):
		for column in range(3):source_rows.append(float(rotation[column*3+row])/Q31)
	var inverse:=_inverse(source_rows)
	if inverse.is_empty():return _failure("noninvertible_or_uncertain_source_matrix")
	var linear_local:=PackedFloat64Array();var render_local:=PackedFloat64Array();var linear_intervals:=PackedFloat64Array();var q31_intervals:=PackedFloat64Array();var sar_intervals:=PackedFloat64Array();var rounding_cells:=PackedFloat64Array();var error_intervals:=PackedFloat64Array();var sar_error_intervals:=PackedFloat64Array();var projected_intervals:=PackedInt64Array();var projected_points:=PackedInt64Array();var projected_error:=PackedInt64Array();var real_query_render:=PackedFloat64Array();var quantum:=pow(2.0,int(frame.vector_scale_s32));var max_render_error:=0.0
	for vertex in range(3):
		var q:=PackedFloat64Array();var exact_q:Array=[];var floor_q:Array=[]
		for axis in range(3):
			var value:=float(positions[vertex*3+axis])-float(frame.query_center_raw[axis]);q.append(value);exact_q.append(_i(value));floor_q.append(PackedFloat64Array([value,value+3.0]))
		var model:=_linear(inverse.rows,q);var model_i:=_linear_interval(inverse.intervals,exact_q);var floor_i:=_linear_interval(inverse.intervals,floor_q);var body:=PackedFloat64Array();var body_i:Array=[];var preimage_i:Array=[];var sar_preimage_i:Array=[]
		for axis in range(3):
			var origin:=float(frame.origin_model_raw[axis]);model[axis]+=origin;body.append(model[axis]*quantum*Phone.Units.METRES_PER_RAW)
			body_i.append(_mul(_mul(_add(model_i[axis],_i(origin)),_i(quantum)),_i(Phone.Units.METRES_PER_RAW)))
			var representative_raw:=_mul(_add(floor_i[axis],_i(origin)),_i(quantum))
			preimage_i.append(_mul(representative_raw,_i(Phone.Units.METRES_PER_RAW)))
			# Arithmetic SAR maps both signs' raw64 inputs into bins [k*2^s,(k+1)*2^s-1].
			# This encloses every lost low-bit value; integer preimage existence is separate.
			sar_preimage_i.append(_mul(_add(representative_raw,PackedFloat64Array([0.0,quantum-1.0])),_i(Phone.Units.METRES_PER_RAW)))
		var local:=_linear(phone.inverse.rows,body);local[1]-=phone.radius
		var local_i:=_linear_interval(phone.inverse.intervals,body_i);var pre_i:=_linear_interval(phone.inverse.intervals,preimage_i);var sar_i:=_linear_interval(phone.inverse.intervals,sar_preimage_i)
		local_i[1]=_sub(local_i[1],_i(phone.radius));pre_i[1]=_sub(pre_i[1],_i(phone.radius));sar_i[1]=_sub(sar_i[1],_i(phone.radius))
		var rendered:=PackedFloat64Array();var bytes:=PackedByteArray();bytes.resize(4)
		for axis in range(3):
			if not is_finite(local[axis]) or not _valid_interval(local_i[axis]) or not _valid_interval(pre_i[axis]) or not _valid_interval(sar_i[axis]) or local[axis]<local_i[axis][0] or local[axis]>local_i[axis][1]:return _failure("unbounded_or_inconsistent_inverse_projection")
			bytes.encode_float(0,local[axis]);var f32:=float(bytes.decode_float(0))
			if not is_finite(f32):return _failure("float32_render_vertex_overflow")
			var previous:=_next32(f32,false);var next:=_next32(f32,true);var low:=(previous+f32)*0.5;var high:=(f32+next)*0.5
			if not is_finite(low) or not is_finite(high) or local[axis]<low or local[axis]>high:return _failure("float32_rounding_cell_mismatch")
			linear_local.append(local[axis]);render_local.append(f32);rendered.append(f32);linear_intervals.append_array(local_i[axis]);q31_intervals.append_array(pre_i[axis]);sar_intervals.append_array(sar_i[axis]);rounding_cells.append(low);rounding_cells.append(high);error_intervals.append_array(_sub(_i(f32),pre_i[axis]));sar_error_intervals.append_array(_sub(_i(f32),sar_i[axis]));max_render_error=maxf(max_render_error,absf(f32-local[axis]))
		var projection:=SourceFrame.project_phone_vertex_f32(frame,Vector3(rendered[0],rendered[1],rendered[2]),Basis(Vector3(phone.basis[0],phone.basis[1],phone.basis[2]),Vector3(phone.basis[3],phone.basis[4],phone.basis[5]),Vector3(phone.basis[6],phone.basis[7],phone.basis[8])),phone.radius,PackedInt64Array([positions[vertex*3],positions[vertex*3+1],positions[vertex*3+2]]))
		if not projection.get("ok",false):return _failure("native_forward_render_projection_unavailable")
		var projected:=_words(projection.get("query_point_raw"),3)
		if projected.size()!=3:return _failure("native_forward_projection_schema_mismatch")
		var bounds:=_forward_interval(rendered,phone,frame)
		if bounds.size()!=6:return _failure("native_forward_projection_interval_overflow")
		for axis in range(3):
			if projected[axis]<bounds[axis*2] or projected[axis]>bounds[axis*2+1]:return _failure("native_forward_projection_outside_derived_interval")
			var difference:int=projected[axis]-positions[vertex*3+axis]
			if difference<I32_MIN or difference>I32_MAX:return _failure("native_render_projection_delta_overflow")
			projected_points.append(projected[axis]);projected_error.append(difference)
		projected_intervals.append_array(bounds)
		var body_render:=_linear(phone.rows,PackedFloat64Array([rendered[0],rendered[1]+phone.radius,rendered[2]]));var scaled:=PackedFloat64Array()
		for axis in range(3):scaled.append(body_render[axis]/Phone.Units.METRES_PER_RAW/quantum-float(frame.origin_model_raw[axis]))
		var projected_real:=_linear(source_rows,scaled)
		for axis in range(3):real_query_render.append(projected_real[axis]+float(frame.query_center_raw[axis]))
	var plane_vertices:=PackedFloat64Array()
	for value:int in positions:plane_vertices.append(float(value))
	var plane:=_leaf_plane(plane_vertices);var render_plane:=_leaf_plane(real_query_render)
	if not plane.nondegenerate or not render_plane.nondegenerate:return _failure("degenerate_source_or_render_triangle")
	var fraction_words:=PackedInt64Array()
	for entry:Dictionary in leaf.plane_fraction_calls:fraction_words.append(int(entry.numerator_s32));fraction_words.append(int(entry.denominator_s32));fraction_words.append(int(entry.fraction_s32))
	var packet:={"schema":1,"source_contract":CONTRACT,"source_model_index":phone.model,"source_uid_u32":phone.uid,"source_executable_sha256":Natural.SOURCE_SHA,"source_terrain_resource_sha256":TERRAIN_DATA_SHA,"frame_observer_s32_hex":_hex32(observer),"frame_scale_s32":int(frame.vector_scale_s32),"frame_origin_s32_hex":_hex32(frame.origin_model_raw),"frame_rotation_q31_hex":_hex32(rotation),"frame_center_s32_hex":_hex32(frame.query_center_raw),"frame_matrix_s32_hex":_hex32(frame.query_matrix_raw),"frame_origin_delta_s32_hex":_hex32(frame.source_qorigin_delta_raw),"phone_frame_f64_hex":phone.frame_f64_hex,"source_style_s32":int(query_frame.query_style_raw),"source_features_hex":query_frame.features.hex_encode(),"source_query_limit_s32":int(query_frame.query_limit_raw),"source_query_result_s32":int(queried.query_result_raw),"native_positions_s32_hex":_hex32(positions),"native_normals_s32_hex":_hex32(_words(leaf.normals_raw,9)),"native_vertex_ids_s32_hex":_hex32(_words(leaf.vertex_ids_s32,3)),"native_depths_s32_hex":_hex32(_words(leaf.depths_s32,3)),"native_heights_s32_hex":_hex32(_words(leaf.heights_s32,3)),"native_lands_s32_hex":_hex32(_words(leaf.lands_s32,3)),"native_sar_positions_s32_hex":_hex32(_words(leaf.sar_positions_raw,9)),"native_sar_shift_s32":int(leaf.sar_shift_s32),"native_leaf_depth_s32":int(leaf.leaf_depth_s32),"native_plane_fractions_s32_hex":_hex32(fraction_words),"native_recorded_intersection_s32":replay,"local_vertices_f64_hex":_hex64(linear_local),"local_vertices_f32_hex":_hex_f32(render_local),"indices":[0,1,2],"linear_projection_enclosure_f64_hex":_hex64(linear_intervals),"q31_floor_preimage_enclosure_f64_hex":_hex64(q31_intervals),"float32_rounding_cells_f64_hex":_hex64(rounding_cells),"render_vs_q31_preimage_error_f64_hex":_hex64(error_intervals),"render_native_query_points_s32_hex":_hex32(projected_points),"render_native_query_error_s32_hex":_hex32(projected_error),"render_native_query_intervals_s32_hex":_hex32(projected_intervals),"source_inverse_determinant_interval_f64_hex":_hex64(inverse.determinant_interval),"phone_inverse_determinant_interval_f64_hex":_hex64(phone.inverse.determinant_interval)}
	packet=_canonical(packet)
	packet["source_graphics_level_s32"]=1
	packet["f579_sar_preimage_enclosure_f64_hex"]=_hex64(sar_intervals);packet["render_vs_f579_sar_preimage_error_f64_hex"]=_hex64(sar_error_intervals)
	packet["parent_frame_policy"]="isolated-matching-bodyfixed-parent-q31";packet["source_body_parent_index_u8"]=phone.body_parent_index;packet["source_body_frame_u8"]=phone.body_frame;packet["source_parent_index_u8"]=phone.parent_index;packet["source_parent_matrix_q31_hex"]=phone.parent_matrix_hex
	packet=_canonical(packet)
	var certificate:={"ok":true,"reason":"original_leaf_and_declared_projection_verified","certifies":CERTIFIES,"source_contract":CONTRACT,"packet_sha256":packet_sha256(packet),"source_query_identity_verified":true,"raw_leaf_identity_verified":true,"original_integer_intersection_replayed":true,"render_projection_verified":true,"float32_rounding_cells_verified":true,"native_forward_derived_intervals_verified":true,"source_geometry_identity_verified":false,"float_collision_height_equivalence":false,"whole_mesh_certified":false,"live_response_enabled":false,"maximum_observed_float32_error_m":max_render_error,"native_query_capped":int(queried.query_result_raw)>=int(queried.query_limit_raw),"q31_interval_semantics":"inverse-image enclosure for three unwrapped signed-Q31 floors; integer preimage existence is not asserted","float_interval_semantics":"outward IEEE-binary64 arithmetic and exact adjacent-binary32 rounding cells; no selected height epsilon","coordinate_policy":"O_plus_inverse_U_of_q_minus_C_then_source_quantum_and_phone_inverse; no observer shortcut or origin-delta removal"}
	if plane.intercept_defined:certificate["raw_leaf_float_intercept_gap_m"]=(float(plane.intercept)-float(replay))*quantum*Phone.Units.METRES_PER_RAW
	if render_plane.intercept_defined:certificate["render_float_intercept_gap_m"]=(float(render_plane.intercept)-float(replay))*quantum*Phone.Units.METRES_PER_RAW
	certificate["parent_frame_conversion_performed"]=false;certificate["phone_chart_coordinate_domain"]="original-parent-model-local-bodyfixed"
	certificate["q31_interval_semantics"]="scaled-model Q31 preimage enclosure with zero F579 SAR low bits; integer preimage existence is not asserted"
	certificate["f579_sar_interval_semantics"]="Q31 enclosure plus every raw64 low-bit value in each signed arithmetic-SAR bin [0,2^scale-1], then declared phone projection; integer preimage existence is not asserted"
	return {"ok":true,"reason":"original_leaf_and_declared_projection_verified","packet":packet,"certificate":_canonical(certificate)}
static func verify(packet:Dictionary,source_frame:Dictionary,trace_row:Dictionary,phone_frame:Dictionary)->Dictionary:
	var result:=build(source_frame,trace_row,phone_frame)
	if not result.ok:return result
	if not Phone._number(packet.get("schema")) or packet!=result.packet:return _failure("stale_or_tampered_render_packet")
	return result
