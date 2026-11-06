extends RefCounted
# The terrain branch of F581 in source model-local integer coordinates.
# Broad-phase body bounds and object/world transforms belong to its caller.
# vector_scale is supplied explicitly: this module does not assign SI units.
const Query=preload("res://scripts/source_terrain_query.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const MASK:=0xffffffff
const MAX_Q31:=0x7fffffff
var kernel:=Query.new()

static func _s32(value:int)->int:return Ground.signed32(value)
static func _s8(value:int)->int:
	var low:=value&255
	return low-256 if low>=128 else low
static func _qmul(first:int,second:int)->int:return Ground.multiply_q31(first,second)

static func source_square_root(value:int)->int:
	# F1502, including its finite low-bit precision and unsigned trial sums.
	var input:=value&MASK
	var step:=0
	var probe:=0x80000000
	while probe>input:step+=1;probe>>=2
	var root:=0
	var remainder:=0
	while step<=31:
		var trial:=(root>>((step-1)&31))+remainder
		if step<=15:trial+=0x80000000>>((step*2)&31)
		trial&=MASK
		if trial<=input:
			remainder=trial
			root=(root+(0x80000000>>(step&31)))&MASK
		step+=1
	return _s32(root)

static func source_length(vector:PackedInt64Array)->int:
	# F1466 preserves an unsigned lower bound from each absolute component.
	var absolute:=PackedInt64Array()
	var bits:=0
	for value in vector:
		var magnitude:=(_s32(-value) if value<0 else value)&MASK
		absolute.append(magnitude);bits|=magnitude
	var shift:=30-Query._msb(bits)
	var total:=0
	for magnitude in absolute:
		var normalized:=_s32(magnitude<<(shift&31))
		total=_s32(total+(_qmul(normalized,normalized)>>2))
	var root:=source_square_root(total)&MASK
	var result:int=root>>((shift-1)&31) if shift>0 else (root*2)&MASK
	for magnitude in absolute:result=maxi(result,magnitude)
	return _s32(result)

static func _normalized_component(value:int,length:int)->int:
	var magnitude:=(_s32(-value) if value<0 else value)&MASK
	var divisor:=length&MASK
	var quotient:=MASK
	if divisor>0 and (magnitude>>1)<divisor:
		quotient=(magnitude<<31)/divisor
	if quotient>=0x80000000:quotient=MAX_Q31
	return _s32(-quotient if value<0 else quotient)

static func _transform(vector:PackedInt64Array,matrix:PackedInt64Array)->PackedInt64Array:
	var result:=PackedInt64Array()
	for axis in range(3):
		var value:=0
		for row in range(3):value=_s32(value+_qmul(vector[row],matrix[row*3+axis]))
		result.append(value)
	return result

static func shift_int64(value:int,count:int)->int:
	# F1341 uses two 32-bit halves; counts beyond one word retain x86 masking.
	var low:=value&MASK
	var high:=(value>>32)&MASK
	if count>0:
		if count<32:
			high=((high<<count)|(low>>(32-count)))&MASK;low=(low<<count)&MASK
		else:high=(low<<((count-32)&31))&MASK;low=0
	elif count<0:
		var amount:=-count
		if amount<32:
			low=((low>>amount)|(high<<(32-amount)))&MASK;high=(_s32(high)>>amount)&MASK
		else:low=(_s32(high)>>((amount-32)&31))&MASK;high=(_s32(high)>>31)&MASK
	return (_s32(high)<<32)|low

static func _source_vertex(data:PackedByteArray,index:int,shift:int)->PackedInt64Array:
	var offset:=(index>>1)*6
	var x:=_s8(data[offset+2])
	if index&1:x=-x
	var vertex:=PackedInt64Array([x,_s8(data[offset+3]),_s8(data[offset+4])])
	for axis in range(3):
		vertex[axis]=_s32(vertex[axis]<<(shift&31)) if shift>=0 else vertex[axis]>>((-shift)&31)
	return vertex

func frame_raw(model_index:int,observer_model_local_raw:PackedInt64Array,vector_scale:int)->Dictionary:
	if observer_model_local_raw.size()!=3 or not kernel._load_resources():return {}
	vector_scale=_s32(vector_scale)
	var key:=str(model_index)
	if not Query.resources.models.has(key):return {}
	var model:Dictionary=Query.resources.models[key]
	var vertex_data:PackedByteArray=str(model.vertices_hex).hex_decode()
	var payload:PackedByteArray=str(model.collision_payload_hex).hex_decode()
	if payload.size()<8:return {}
	var vertices:Array=[]
	var shift:=_s32(int(model.mesh_zoom)-vector_scale)
	for corner in range(4):
		var index:int=payload[corner]
		if (index>>1)*6+5>=vertex_data.size():return {}
		vertices.append(_source_vertex(vertex_data,index,shift))
	var origin:PackedInt64Array=vertices[0]
	var point:=Query._vector(observer_model_local_raw)
	var center:PackedInt64Array=Query._subtract(origin,point)
	var distance:=source_length(center)
	if distance<=0:return {}
	var matrix:=PackedInt64Array([MAX_Q31,0,0,0,MAX_Q31,0,0,0,MAX_Q31])
	if center[0]!=0:
		var xy:=source_length(PackedInt64Array([center[0],center[1],0]))
		var first:=_normalized_component(center[0],xy)
		var second:=_normalized_component(center[1],xy)
		matrix=PackedInt64Array([second,first,0,_s32(-first),second,0,0,0,MAX_Q31])
		center[1]=xy
	if center[1]!=0:
		var yz:=source_length(PackedInt64Array([0,center[1],center[2]]))
		var first:=_normalized_component(center[1],yz)
		var second:=_normalized_component(center[2],yz)
		for row in range(2):
			matrix[row*3+2]=_qmul(matrix[row*3+1],first)
			matrix[row*3+1]=_qmul(matrix[row*3+1],second)
		matrix[7]=_s32(-first);matrix[8]=second
	var query_matrix:=PackedInt64Array()
	for column in range(1,4):query_matrix.append_array(_transform(Query._subtract(vertices[column],origin),matrix))
	return {"query_matrix_raw":query_matrix,"query_center_raw":PackedInt64Array([0,0,distance]),"query_style_raw":payload.decode_u16(4),"query_limit_raw":2000000000>>(vector_scale&31),"features":payload.slice(6)}

func query_point_raw(model_index:int,source_uid:int,observer_model_local_raw:PackedInt64Array,vector_scale:int,graphics_level_raw:=1,threshold_raw:=0)->Dictionary:
	vector_scale=_s32(vector_scale)
	var frame:=frame_raw(model_index,observer_model_local_raw,vector_scale)
	if frame.is_empty():return {}
	var query:Dictionary=kernel.query_raw(source_uid,int(frame.query_style_raw),frame.query_matrix_raw,frame.query_center_raw,int(frame.query_limit_raw),graphics_level_raw,frame.features)
	if query.is_empty():return {}
	var height:int=query.query_result_raw
	var collision_status:=0 if (_s32(threshold_raw)>>16)>height else -1
	var terrain_written:bool=height<int(frame.query_limit_raw)
	var contact_altitude:Variant=shift_int64(height,vector_scale) if terrain_written else null
	var altitude:Variant=0 if collision_status==0 else contact_altitude
	return {"collision_status":collision_status,"altitude_raw_i64":altitude,"contact_altitude_raw_i64":contact_altitude,"altitude_written":terrain_written or collision_status==0,"recorded_intersection_raw":query.recorded_intersection_raw,"pending_query_flag":query.pending_query_flag,"terrain_query_calls":1,"query_matrix_raw":frame.query_matrix_raw,"query_center_raw":frame.query_center_raw,"query_style_raw":frame.query_style_raw,"query_limit_raw":frame.query_limit_raw,"vector_scale":vector_scale}
