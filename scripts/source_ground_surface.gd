extends RefCounted
# Original integer ground-port positioning and natural terrain queries.
# Object/world preparation and live collision integration belong to the caller.
const Orbit=preload("res://scripts/source_orbit.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const Pads=preload("res://scripts/source_ground_pads.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const SOURCE_VARIANT:="jjffe-7e54034-ground-surface"
const OBJECT_BYTES:=338
const MASK:=0xffffffff
static var collision_resources:Dictionary={}
var point_kernel:=Point.new()

static func _s32(value:int)->int:return Ground.signed32(value)
static func _words(value:int)->PackedInt64Array:return PackedInt64Array([value&MASK,(value>>32)&MASK])
static func _shift64(value:int,count:int)->int:return Orbit.signed64(Orbit.shift_words(_words(value),count))
static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=MASK and float(value)==floorf(float(value))

static func _load_collision_resources()->bool:
	if not collision_resources.is_empty():return true
	if not FileAccess.file_exists("res://data/ffe_ground_collision.json"):return false
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_ground_collision.json"))
	if not parsed is Dictionary or parsed.get("schema")!=1 or parsed.get("source_sha256")!="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" or not parsed.get("models") is Dictionary:return false
	collision_resources=parsed
	return true

static func model_resources(model_index:int)->Dictionary:
	if not _load_collision_resources():return {}
	var model:Variant=collision_resources.models.get(str(model_index))
	return model.duplicate(true) if model is Dictionary else {}

static func initialize_model(initial:PackedByteArray,model_index:int,tick_u32:Variant=0,day_u32:Variant=0)->Dictionary:
	# Actual F1533's in-place branch for these descriptors, all of which have
	# no physical-specification pointer. Allocation/copying is not inferred.
	if initial.size()!=OBJECT_BYTES or not _u32(tick_u32) or not _u32(day_u32):return {}
	var model:=model_resources(model_index)
	if model.is_empty() or int(model.get("physical_spec_pointer_raw",-1))!=0:return {}
	var descriptor:=str(model.get("descriptor_hex","")).hex_decode()
	if descriptor.size()!=68:return {}
	var candidate:=initial.duplicate()
	candidate.encode_u32(0xa8,int(tick_u32));candidate.encode_u32(0xac,int(day_u32));candidate.encode_u32(0x82,model_index)
	var exponent:=int(model.model_scale_raw)
	for row in [[0x138,int(model.outer_radius_raw)],[0x140,int(model.inner_radius_raw)]]:
		var mantissa:int=int(row[1])&65535
		if mantissa>=32768:mantissa-=65536
		candidate.encode_s64(int(row[0]),_shift64(mantissa,exponent))
	candidate[0x151]=0;candidate[0x25]=0;candidate[0x124]=0;candidate[0x88]=255
	var flags:=(int(model.flags_raw)>>4)&7
	var collision:=str(model.collision_bytes_hex).hex_decode()
	if not collision.is_empty() and collision[0]!=0:flags|=0x80
	candidate[0x14c]=flags
	return {"object":candidate,"model_index":model_index,"outer_bound_raw":candidate.decode_s64(0x138),"inner_bound_raw":candidate.decode_s64(0x140),"source_variant":SOURCE_VARIANT}

static func matrix_q31(phase:int,inclination:int)->PackedInt64Array:
	return PackedInt64Array(Pads.matrix_for_angles(phase,inclination))

static func _radial_position(radial:PackedInt64Array,scalar:int,exponent:int)->PackedInt64Array:
	var result:=PackedInt64Array()
	for axis in range(3):result.append(_shift64(_s32(radial[axis])*_s32(scalar),_s32(exponent-31)))
	return result

static func refine_raw(radial:PackedInt64Array,outer_radius_raw:int,scale_exponent:int,first_height_raw:int,second_height_raw:int)->Dictionary:
	# Exact arithmetic surrounding F879's two F574 calls. Heights are supplied
	# explicitly here; this helper alone does not perform the collision query.
	if radial.size()!=3:return {}
	for value in radial:
		if value<(-0x80000000) or value>0x7fffffff:return {}
	if outer_radius_raw<1 or outer_radius_raw>0x7fffffff or scale_exponent<(-32) or scale_exponent>63:return {}
	if first_height_raw<(-0x80000000) or first_height_raw>0x7fffffff or second_height_raw<(-0x80000000) or second_height_raw>0x7fffffff:return {}
	var scalar:=_s32(outer_radius_raw-1);var exponent:=scale_exponent
	var initial:=_radial_position(radial,scalar,exponent)
	var inset:=_s32(first_height_raw-(first_height_raw>>3))
	if exponent<0:scalar=_s32(scalar-_s32(inset<<((-exponent)&31)))
	elif exponent<16:scalar=_s32(_s32(scalar<<(exponent&31))-inset);exponent=0
	else:
		exponent=_s32(exponent-16)
		scalar=_s32(_s32(scalar<<16)-(inset>>(exponent&31)))
	var intermediate:=_radial_position(radial,scalar,exponent)
	if exponent<0:scalar=_s32(scalar-_s32(second_height_raw<<((-exponent)&31)))
	else:scalar=_s32(scalar-(second_height_raw>>(exponent&31)))
	return {"position_raw":_radial_position(radial,scalar,exponent),"initial_position_raw":initial,"intermediate_position_raw":intermediate,"first_height_raw":first_height_raw,"second_height_raw":second_height_raw,"final_scalar_s32":scalar,"final_exponent_s32":exponent,"source_variant":SOURCE_VARIANT}

func query_model_local(model_index:int,source_uid:int,observer_model_local_raw:PackedInt64Array,vector_scale:int,graphics_level_raw:=1,threshold_raw:=0)->Dictionary:
	return point_kernel.query_point_raw(model_index,source_uid,observer_model_local_raw,vector_scale,graphics_level_raw,threshold_raw)

static func _object_vector(object:PackedByteArray,offset:int)->PackedInt64Array:
	return PackedInt64Array([object.decode_s64(offset),object.decode_s64(offset+8),object.decode_s64(offset+16)])

static func _matrix(object:PackedByteArray)->PackedInt64Array:
	var result:=PackedInt64Array()
	for index in range(9):result.append(object.decode_s32(index*4))
	return result

static func _transpose_transform(vector:PackedInt64Array,matrix:PackedInt64Array)->PackedInt64Array:
	var result:=PackedInt64Array()
	for axis in range(3):
		var total:=0
		for component in range(3):total=_s32(total+Ground.multiply_q31(vector[component],matrix[axis*3+component]))
		result.append(total)
	return result

static func _divide_q31_unsigned(numerator:int,denominator:int)->int:
	var first:=numerator&MASK;var second:=denominator&MASK
	if (first>>1)>=second:return MASK
	return ((first<<31)/second)&MASK

static func _divide_q31_signed(numerator:int,denominator:int)->int:
	# F1501's unsigned restoring loop, followed by the original signed result.
	var source:=_s32(numerator);var remainder:=(-source if source<0 else source)&MASK
	var divisor:=denominator&MASK;var quotient:=1
	while true:
		remainder=(remainder<<1)&MASK;quotient=(quotient<<1)&MASK
		if divisor<=remainder:remainder=(remainder-divisor)&MASK;quotient=(quotient+1)&MASK
		if _s32(quotient)<=0:break
	quotient&=0x7fffffff
	return _s32(-quotient if source<0 else quotient)

static func _normalize_vector(vector:PackedInt64Array)->PackedInt64Array:
	var length:=(Point.source_length(vector)+1)&MASK
	var shift:=31-Gravity._msb(length)
	var denominator:=((length<<(shift&31))&MASK)>>1
	var factor:=(_divide_q31_unsigned(0x3f800000,denominator)>>1)-1
	var result:=PackedInt64Array()
	for coordinate in vector:result.append(_s32(Ground.multiply_q31(coordinate,factor)<<((shift+1)&31)))
	return result

static func _normalize_1503(vector:PackedInt64Array)->PackedInt64Array:
	var squared:=0
	for coordinate in vector:squared=_s32(squared+((coordinate*coordinate)>>32))
	var root:=Point.source_square_root(_s32(squared*2))&MASK
	var result:=PackedInt64Array()
	for coordinate in vector:result.append(Ground.multiply_q31(_divide_q31_signed(coordinate,root),0x7fffffff))
	return result

static func _cross(first:PackedInt64Array,second:PackedInt64Array)->PackedInt64Array:
	return PackedInt64Array([_s32(Ground.multiply_q31(first[1],second[2])-Ground.multiply_q31(first[2],second[1])),_s32(Ground.multiply_q31(first[2],second[0])-Ground.multiply_q31(first[0],second[2])),_s32(Ground.multiply_q31(first[0],second[1])-Ground.multiply_q31(first[1],second[0]))])

static func _swap_matrix_rows(matrix:PackedInt64Array)->PackedInt64Array:
	return PackedInt64Array([_s32(-matrix[0]),_s32(-matrix[1]),_s32(-matrix[2]),matrix[6],matrix[7],matrix[8],matrix[3],matrix[4],matrix[5]])

static func _orthonormalize(matrix:PackedInt64Array)->PackedInt64Array:
	var first:=_normalize_vector(PackedInt64Array([matrix[0],matrix[1],matrix[2]]))
	var third:=_normalize_vector(PackedInt64Array([matrix[6],matrix[7],matrix[8]]))
	var second:=_normalize_vector(_cross(third,first))
	first=_cross(second,third)
	return PackedInt64Array([first[0],first[1],first[2],second[0],second[1],second[2],third[0],third[1],third[2]])

static func _contact_response(probe:PackedByteArray,parent:PackedByteArray,position_raw:PackedInt64Array,state:Dictionary)->Dictionary:
	# Reviewed non-player, zero-enabled contact path of F575. Damage/player
	# callbacks require a different context and are not silently substituted.
	if probe[0x86]==0 or probe.decode_u16(0x9e)!=0:return {}
	var shift:=maxi(0,Gravity._vec64_msb(position_raw)-28)
	var vector:=PackedInt64Array()
	for coordinate in position_raw:vector.append(_s32(_shift64(coordinate,-shift)&MASK))
	var normal:=_normalize_1503(vector)
	var previous:=Orbit.signed64(PackedInt64Array([int(state.previous_altitude_low_u32),int(state.previous_altitude_high_s32)&MASK]))
	var difference:=_s32(probe.decode_s64(0x140)-previous)
	var candidate:=probe.duplicate()
	for axis in range(3):
		var displacement:=Ground.multiply_q31(difference,normal[axis])
		var location:=candidate.decode_s64(0x3e+axis*8)+displacement
		candidate.encode_s64(0x3e+axis*8,location)
	var matrix:=_matrix(candidate)
	for axis in range(3):matrix[3+axis]=normal[axis]
	matrix=_swap_matrix_rows(_orthonormalize(_swap_matrix_rows(matrix)))
	for index in range(9):candidate.encode_u32(index*4,int(matrix[index])&MASK)
	for axis in range(3):candidate.encode_u32(0x8c+axis*4,0)
	state.collision_active_u8=0
	state.collision_flags_u8=int(state.collision_flags_u8)|2
	if parent.decode_u32(0x140)!=parent.decode_u32(0x138):state.collision_flags_u8=int(state.collision_flags_u8)|1
	if int(state.collider_index_u8)==0:state.collider_index_u8=parent[0x86]
	return {"probe":candidate,"globals":state}

static func _initial_globals(values:Dictionary)->Dictionary:
	var result:={"altitude_low_u32":MASK,"altitude_high_s32":0,"previous_altitude_low_u32":0,"previous_altitude_high_s32":0,"collision_kind_u8":0,"collision_flags_u8":0,"volume_flags_u8":0,"collider_index_u8":0,"collision_active_u8":0,"collision_enabled_u8":0,"primitive_flags_u8":0,"terrain_query_calls":0,"recorded_intersection_raw":0,"pending_query_flag":0}
	for key in values:
		if result.has(key):result[key]=int(values[key])
	# F574 resets the low altitude and collision-kind byte, not the high or
	# previous-contact words. Carrying the latter is part of the source ABI.
	for key in ["collision_flags_u8","volume_flags_u8","collider_index_u8","collision_enabled_u8","primitive_flags_u8","collision_kind_u8","terrain_query_calls"]:result[key]=0
	result.altitude_low_u32=MASK
	return result

static func _valid_globals(values:Dictionary)->bool:
	var signed_keys:=["altitude_high_s32","previous_altitude_high_s32","recorded_intersection_raw"]
	var word_keys:=["altitude_low_u32","previous_altitude_low_u32","terrain_query_calls","pending_query_flag"]
	var byte_keys:=["collision_kind_u8","collision_flags_u8","volume_flags_u8","collider_index_u8","collision_active_u8","collision_enabled_u8","primitive_flags_u8"]
	for key in values:
		if not (key is String or key is StringName) or key not in signed_keys+word_keys+byte_keys:return false
		var value:Variant=values[key]
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)):return false
		if key in signed_keys:
			if value<(-0x80000000) or value>0x7fffffff:return false
		elif key in byte_keys:
			if value<0 or value>255:return false
		elif not _u32(value):return false
	return true

static func _height_result(height:int,state:Dictionary,trace:Dictionary,probe:PackedByteArray,parent:PackedByteArray,position_raw:PackedInt64Array)->Dictionary:
	var point_after:=PackedInt64Array()
	for coordinate in position_raw:point_after.append(absi(coordinate))
	return {"height_s32":height,"globals":state,"trace":trace,"point_after_raw":point_after,"probe":probe.duplicate(),"parent":parent.duplicate(),"source_variant":SOURCE_VARIANT}

func height_raw(probe:PackedByteArray,parent:PackedByteArray,position_raw:PackedInt64Array,graphics_level_raw:int=1,initial_globals:Dictionary={})->Dictionary:
	# F574 natural-parent path in the reviewed non-player geometry context:
	# broad phase, F579 frame, F581 terrain and the bounded contact response.
	# Returned copies carry original mutations; damage/player policy is separate.
	if probe.size()!=OBJECT_BYTES or parent.size()!=OBJECT_BYTES or position_raw.size()!=3 or graphics_level_raw<0 or graphics_level_raw>15 or not _valid_globals(initial_globals):return {}
	if not _load_collision_resources():return {}
	var parent_model:=int(parent.decode_u32(0x82));var probe_model:=int(probe.decode_u32(0x82))
	var model:=model_resources(parent_model);var source_model:=model_resources(probe_model)
	if model.is_empty() or source_model.is_empty() or str(model.get("role",""))!="natural_parent":return {}
	if (parent[0x14c]&0x80)==0 or int(source_model.get("inner_radius_raw",-1))!=0 or probe.decode_s64(0x140)!=0:return {}
	var preceding:=str(source_model.get("collision_preceding_hex","")).hex_decode()
	if preceding.size()<2 or preceding.decode_u16(preceding.size()-2)!=0:return {}
	var natural_stream:=str(model.collision_bytes_hex).hex_decode()
	if natural_stream.size()<8 or natural_stream[0]!=0x10 or natural_stream[1] not in [0x82,0x83] or natural_stream[2]!=255 or natural_stream.slice(natural_stream.size()-5)!=PackedByteArray([0x50,0x80,0,0,0]):return {}
	var sum:=0
	for coordinate in position_raw:
		if coordinate<(-0x1000000000000) or coordinate>0x1000000000000:return {}
		sum+=absi(coordinate)
	var state:=_initial_globals(initial_globals)
	var trace:={"point_raw":position_raw.duplicate(),"broad_phase_rejected":false,"terrain_branch":"none"}
	var half_distance:=(sum>>1)-probe.decode_s64(0x138)-parent.decode_s64(0x138)
	if half_distance>=0:
		trace.broad_phase_rejected=true
		return _height_result(-1,state,trace,probe,parent,position_raw)
	var shift:=maxi(0,Gravity._vec64_msb(position_raw)-28)
	var vector:=PackedInt64Array()
	for coordinate in position_raw:vector.append(_s32(_shift64(coordinate,-shift)&MASK))
	var minimum_shift:=int(model.scale)+int(model.scale2)-23
	if shift<minimum_shift:
		var change:=minimum_shift-shift
		for axis in range(3):vector[axis]>>=change&31
		shift=minimum_shift
	var threshold:=_s32(probe.decode_u32(0x140))
	threshold=_s32(threshold<<((-shift)&31)) if shift<0 else threshold>>(shift&31)
	if probe[0x57]==0 or probe[0x56]!=parent[0x86]:vector=_transpose_transform(vector,_matrix(parent))
	var frame:=point_kernel.frame_raw(parent_model,vector,shift)
	if frame.is_empty():return {}
	var distance:=int(frame.query_center_raw[2])
	var outer:=_s32(_shift64(parent.decode_s64(0x138),-shift)&MASK)
	var inner:=_s32(_shift64(parent.decode_s64(0x140),-shift)&MASK)
	trace["vector_scale"]=shift;trace["observer_model_local_raw"]=vector.duplicate();trace["distance_raw"]=distance
	if _s32(distance-outer)>=threshold:
		trace.terrain_branch="outside_outer_bound";state.collision_kind_u8=0
	elif _s32(distance-inner)<=threshold:
		trace.terrain_branch="inside_inner_bound";state.collision_kind_u8=1
	else:
		trace.terrain_branch="terrain_query"
		var query:Dictionary=point_kernel.kernel.query_raw(int(parent.decode_u32(0xa0)),int(frame.query_style_raw),frame.query_matrix_raw,frame.query_center_raw,int(frame.query_limit_raw),graphics_level_raw,frame.features)
		if query.is_empty():return {}
		var height:=int(query.query_result_raw)
		state.collision_kind_u8=255;state.terrain_query_calls=1
		state.recorded_intersection_raw=int(query.recorded_intersection_raw);state.pending_query_flag=int(query.pending_query_flag)
		if height<int(frame.query_limit_raw):
			var altitude:=_shift64(height,shift)
			state.altitude_low_u32=altitude&MASK;state.altitude_high_s32=_s32(altitude>>32)
		state.previous_altitude_low_u32=state.altitude_low_u32;state.previous_altitude_high_s32=state.altitude_high_s32
		if (threshold>>16)>height:
			state.altitude_low_u32=0;state.altitude_high_s32=0;state.collision_kind_u8=1
	# The original natural stream's terrain record accumulates low flags;
	# its following empty exclusion record returns -1. F576 then reads the
	# verified zero child marker and returns before mutable collision response.
	if int(state.collision_kind_u8)==255 or str(trace.terrain_branch)=="outside_outer_bound":
		state.volume_flags_u8=natural_stream[1]&0x7f;state.collision_flags_u8=state.volume_flags_u8
		state.collider_index_u8=parent[0x86];state.primitive_flags_u8=0x50
	elif int(state.collision_kind_u8)==1:
		state.volume_flags_u8=natural_stream[1];state.collision_flags_u8=natural_stream[1]
		state.collider_index_u8=parent[0x86];state.primitive_flags_u8=0x10
		var contacted:=_contact_response(probe,parent,position_raw,state)
		if contacted.is_empty():return {}
		probe=contacted.probe;state=contacted.globals
	var result:=-1
	if int(state.altitude_high_s32)==0 and _s32(int(state.altitude_low_u32))>=0:result=_s32(int(state.altitude_low_u32))
	return _height_result(result,state,trace,probe,parent,position_raw)

func sample_radial_raw(probe:PackedByteArray,parent:PackedByteArray,radial_q31:PackedInt64Array,graphics_level_raw:int=1,initial_globals:Dictionary={})->Dictionary:
	# Explicit continuous-direction probe adapter around the original two
	# height calls and F879 arithmetic. It does not quantize direction to the
	# 16-bit constructor angles or claim to execute F1674 for arbitrary rays.
	if probe.size()!=OBJECT_BYTES or parent.size()!=OBJECT_BYTES or radial_q31.size()!=3:return {}
	for coordinate in radial_q31:
		if coordinate<(-0x80000000) or coordinate>0x7fffffff:return {}
	if radial_q31==PackedInt64Array([0,0,0]):return {}
	var model:=model_resources(int(parent.decode_u32(0x82)))
	if model.is_empty():return {}
	var outer:=int(model.outer_radius_raw);var exponent:=int(model.model_scale_raw)
	var first_point:=_radial_position(radial_q31,outer-1,exponent)
	var first:=height_raw(probe,parent,first_point,graphics_level_raw,initial_globals)
	if first.is_empty():return {}
	var partial:=refine_raw(radial_q31,outer,exponent,int(first.height_s32),0)
	if partial.is_empty():return {}
	var second_point:PackedInt64Array=partial.intermediate_position_raw
	var second:=height_raw(first.probe,parent,second_point,graphics_level_raw,first.globals)
	if second.is_empty():return {}
	var result:=refine_raw(radial_q31,outer,exponent,int(first.height_s32),int(second.height_s32))
	result["passes"]=[first,second];result["height_calls"]=2
	result["terrain_query_calls"]=int(first.globals.terrain_query_calls)+int(second.globals.terrain_query_calls)
	result["port_after_queries"]=second.probe
	result["input_policy"]="source_radial_probe_v1"
	return result

func place_point_raw(probe:PackedByteArray,parent:PackedByteArray,phase_u16:int,inclination_u16:int,graphics_level_raw:int=1,initial_globals:Dictionary={})->Dictionary:
	# Exact F1674 constructor orientation followed by the two source queries.
	if phase_u16<0 or phase_u16>65535 or inclination_u16<0 or inclination_u16>65535:return {}
	var matrix:=matrix_q31(phase_u16,inclination_u16)
	var radial:=PackedInt64Array([matrix[3],matrix[4],matrix[5]])
	if probe.size()!=OBJECT_BYTES:return {}
	var oriented:=probe.duplicate()
	for index in range(9):oriented.encode_u32(index*4,int(matrix[index])&MASK)
	var result:=sample_radial_raw(oriented,parent,radial,graphics_level_raw,initial_globals)
	if result.is_empty():return {}
	result["matrix_q31"]=_matrix(result.port_after_queries);result["matrix_initial_q31"]=matrix;result["input_policy"]="source_f1674_ground_angles"
	return result

func place_raw(probe:PackedByteArray,parent:PackedByteArray,phase_u16:int,inclination_u16:int,graphics_level_raw:int=1,initial_globals:Dictionary={})->Dictionary:
	# Complete changed port object for the independently reviewed F879 domain.
	# Model117's source contact normalization remains exact; it is not used as
	# evidence that its nonspherical shape has a universal landing radius.
	var result:=place_point_raw(probe,parent,phase_u16,inclination_u16,graphics_level_raw,initial_globals)
	if result.is_empty():return {}
	var candidate:PackedByteArray=result.port_after_queries.duplicate()
	for axis in range(3):candidate.encode_s64(0x3e+axis*8,int(result.position_raw[axis]))
	result["port"]=candidate;result["parent"]=parent.duplicate()
	return result

func place_records(port_record:PackedByteArray,parent_record:PackedByteArray,port_index:int,graphics_level_raw:int=1)->Dictionary:
	# Explicit isolated geometry bootstrap: zeroed objects, source identifiers,
	# parent UID and identity parent orientation followed by actual F1533.
	# This is not allocation or the complete F880 object factory.
	if port_record.size()!=68 or parent_record.size()!=68 or port_record.decode_u16(10)!=35 or port_index<1 or port_index>255:return {}
	var parent_index:=int(port_record.decode_u16(8))
	if parent_index<1 or parent_index>255 or parent_index==port_index:return {}
	var initial_port:=PackedByteArray();initial_port.resize(OBJECT_BYTES)
	var initial_parent:=PackedByteArray();initial_parent.resize(OBJECT_BYTES)
	initial_port[0x56]=parent_index;initial_port[0x57]=1;initial_port[0x86]=port_index
	initial_parent[0x86]=parent_index;initial_parent.encode_u32(0xa0,int(parent_record.decode_u32(4)))
	for axis in range(3):initial_parent.encode_u32(axis*16,0x7fffffff)
	var port:=initialize_model(initial_port,int(port_record.decode_u16(12)))
	var parent:=initialize_model(initial_parent,int(parent_record.decode_u16(12)))
	if port.is_empty() or parent.is_empty():return {}
	var result:=place_raw(port.object,parent.object,int(port_record.decode_u16(18)),int(port_record.decode_u16(34)),graphics_level_raw)
	if result.is_empty():return {}
	result["initialized_port"]=port.object;result["initialized_parent"]=parent.object
	result["input_policy"]="isolated_source_geometry_v1"
	return result

func sample_record_radial(parent_record:PackedByteArray,radial_q31:PackedInt64Array,graphics_level_raw:int=1,probe_model:int=84)->Dictionary:
	# Stable body-fixed height-probe policy for callers that do not represent
	# an actual settlement. The chosen real descriptor has zero inner bound;
	# its identity and detail remain explicit, shared by mesh/collision users.
	if parent_record.size()!=68:return {}
	var raw_probe:=PackedByteArray();raw_probe.resize(OBJECT_BYTES)
	var raw_parent:=PackedByteArray();raw_parent.resize(OBJECT_BYTES)
	raw_probe[0x56]=1;raw_probe[0x57]=1;raw_probe[0x86]=2
	raw_parent[0x86]=1;raw_parent.encode_u32(0xa0,int(parent_record.decode_u32(4)))
	for axis in range(3):raw_parent.encode_u32(axis*16,0x7fffffff)
	var probe:=initialize_model(raw_probe,probe_model)
	var parent:=initialize_model(raw_parent,int(parent_record.decode_u16(12)))
	if probe.is_empty() or parent.is_empty():return {}
	var result:=sample_radial_raw(probe.object,parent.object,radial_q31,graphics_level_raw)
	if result.is_empty():return {}
	result["probe_model_index"]=probe_model;result["graphics_level_raw"]=graphics_level_raw
	return result
