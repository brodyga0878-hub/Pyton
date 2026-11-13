extends RefCounted
# Pure, bounded original F576/F579/F582-natural/F581 classifier. The caller
# supplies source object records and source relative coordinates. This module
# neither places a phone ship nor resolves contact, damage, time or F578.
const Ground=preload("res://scripts/source_ground_surface.gd")
const Math=preload("res://scripts/ground_coordinates.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Query=preload("res://scripts/source_terrain_query.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Fuel=preload("res://scripts/source_fuel_contact.gd")
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const CONTRACT:="dos-firstenc-f576-natural-player-contact-v1"
const DATA_PATH:="res://data/ffe_natural_contact.json"
const DATA_SHA:="0074a49df9f22879a4eefbef6dda183cbb517243792dd8d086cb782c2da5603e"
const OBJECT_BYTES:=338
const MASK:=0xffffffff
const GLOBAL_KEYS:=["altitude_low_u32","altitude_high_s32","previous_altitude_low_u32","previous_altitude_high_s32","collision_kind_u8","collision_flags_u8","volume_flags_u8","collider_index_u8","collision_active_u8","collision_enabled_u8","primitive_flags_u8","recorded_intersection_raw","pending_query_flag","collider_parent_selected"]
static var _ship_models:Dictionary={}
static var _resource_mutex:=Mutex.new()
var _query:=Query.new()

static func _s32(value:int)->int:return Math.signed32(value)
static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _sha(raw:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw);return hash.finish().hex_encode()
static func _add64(first:int,second:int)->int:
	var low:=(first&MASK)+(second&MASK)
	return (_s32((first>>32)+(second>>32)+(low>>32))<<32)|(low&MASK)
static func _s16(raw:int)->int:return (raw&65535)-65536 if raw&32768 else raw&65535
static func _vector_hex(vector:PackedInt64Array)->String:
	var raw:=PackedByteArray();raw.resize(24)
	for axis in range(3):raw.encode_s64(axis*8,vector[axis])
	return raw.hex_encode()

static func ship_model(index:int)->Dictionary:
	if index not in [15,24,38]:return {}
	_resource_mutex.lock()
	if _ship_models.is_empty():
		if not FileAccess.file_exists(DATA_PATH) or FileAccess.get_sha256(DATA_PATH)!=DATA_SHA:_resource_mutex.unlock();return {}
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		if not parsed is Dictionary or parsed.get("schema")!=1 or parsed.get("source_sha256")!=SOURCE_SHA or not parsed.get("ship_models") is Dictionary:_resource_mutex.unlock();return {}
		_ship_models=parsed.ship_models.duplicate(true)
	var value:Variant=_ship_models.get(str(index));var data:Dictionary=value.duplicate(true) if value is Dictionary else {};_resource_mutex.unlock()
	if data.is_empty() or not data.get("preceding_children") is Dictionary:return {}
	var descriptor:=str(data.get("descriptor_hex","")).hex_decode();var children:Dictionary=data.preceding_children
	var preceding:=str(children.get("hex","")).hex_decode()
	if descriptor.size()!=68 or _sha(descriptor)!=str(data.get("descriptor_sha256","")) or preceding.size()<2 or preceding.size()%4!=2 or _sha(preceding)!=str(children.get("sha256","")):return {}
	if preceding.decode_s16(0)!=0 or not children.get("records") is Array or children.records.size()!=(preceding.size()-2)/4:return {}
	var records:Array=[]
	for offset in range(preceding.size()-2,0,-4):
		var displacement:=preceding.decode_s16(offset);var encoded:=preceding.decode_s16(offset-2)
		var expected:Dictionary=children.records[records.size()]
		if displacement==0 or (encoded&6)==6 or int(expected.get("radius_s16",0))!=displacement or int(expected.get("axis_radius_encoded_s16",0))!=encoded:return {}
		records.append({"displacement_s16":displacement,"axis_radius_encoded_s16":encoded})
	data["descriptor"]=descriptor;data["children"]=records
	return data

static func parent_model(index:int)->Dictionary:
	if index<117 or index>148:return {}
	var data:=Ground.model_resources(index) if index<=133 else Fuel.model(index)
	if data.is_empty():return {}
	var descriptor:=str(data.get("descriptor_hex","")).hex_decode();var vertices:=str(data.get("vertices_hex","")).hex_decode()
	var stream:=str(data.get("collision_bytes_hex",data.get("collision_stream_hex",""))).hex_decode()
	var stream_hash:=str(data.get("collision_bytes_sha256",data.get("collision_stream_sha256","")))
	if descriptor.size()!=68 or _sha(descriptor)!=str(data.get("descriptor_sha256","")) or vertices.size()!=24 or _sha(vertices)!=str(data.get("vertices_sha256","")) or stream.size()<16 or _sha(stream)!=stream_hash:return {}
	# Only the actual terrain record and empty class40 exclusion tail are
	# supported. Plane lists, conditional records, F580 and F583 stay outside.
	if stream[0]!=0x10 or stream[1] not in [0x82,0x83] or stream[2]!=255 or stream.slice(stream.size()-5)!=PackedByteArray([0x50,0x80,0,0,0]):return {}
	if descriptor.decode_u32(0x38)!=0:return {}
	var payload:=stream.slice(3,stream.size()-5)
	if payload.size()<8 or payload.decode_u16(4)>=14:return {}
	for corner in range(4):
		if (int(payload[corner])>>1)*6+5>=vertices.size():return {}
	return {"model_index":index,"descriptor":descriptor,"descriptor_sha256":str(data.descriptor_sha256),"vertices":vertices,"payload":payload,"mesh_zoom":_s32(descriptor.decode_s32(0x14)+descriptor.decode_s32(0x18)),"volume_u8":int(stream[1]),"stream_sha256":stream_hash}

static func _globals(initial:Dictionary)->Dictionary:
	var result:={"altitude_low_u32":MASK,"altitude_high_s32":0,"previous_altitude_low_u32":0,"previous_altitude_high_s32":0,"collision_kind_u8":0,"collision_flags_u8":0,"volume_flags_u8":0,"collider_index_u8":0,"collision_active_u8":0,"collision_enabled_u8":0,"primitive_flags_u8":0,"recorded_intersection_raw":0,"pending_query_flag":0,"collider_parent_selected":false}
	for key:Variant in initial:
		if not (key is String or key is StringName) or key not in GLOBAL_KEYS:return {}
		var value:Variant=initial[key]
		if key=="collider_parent_selected":
			if not value is bool:return {}
		elif key in ["altitude_high_s32","previous_altitude_high_s32","recorded_intersection_raw"]:
			if not _whole(value,-2147483648,2147483647):return {}
		elif key in ["altitude_low_u32","previous_altitude_low_u32","pending_query_flag"]:
			if not _whole(value,0,MASK):return {}
		elif not _whole(value,0,255):return {}
		result[key]=bool(value) if key=="collider_parent_selected" else int(value)
	return result

static func _reject(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,reason:String)->Dictionary:
	return {"ok":false,"error":reason,"body_after":body.duplicate(),"parent_after":parent.duplicate(),"relative_position_s64":relative.duplicate(),"globals_after":{},"global_writes":{},"query_trace":[],"iterations":[],"terrain_query_calls":0,"source_contract":CONTRACT,"source_sha256":SOURCE_SHA}

func _frame(model:Dictionary,observer:PackedInt64Array,scale:int)->Dictionary:
	# F581 uses the source four-vertex basis, including anisotropic model117.
	# Reuse the proved source integer operations without altering old modules.
	var vertices:Array=[];var payload:PackedByteArray=model.payload
	for corner in range(4):vertices.append(Point._source_vertex(model.vertices,int(payload[corner]),_s32(int(model.mesh_zoom)-scale)))
	var origin:PackedInt64Array=vertices[0];var center:=Query._subtract(origin,observer);var distance:=Point.source_length(center)
	var matrix:=PackedInt64Array([0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff])
	if center[0]!=0:
		var length:=Point.source_length(PackedInt64Array([center[0],center[1],0]));var first:=Point._normalized_component(center[0],length);var second:=Point._normalized_component(center[1],length)
		matrix=PackedInt64Array([second,first,0,_s32(-first),second,0,0,0,0x7fffffff]);center[1]=length
	if center[1]!=0:
		var length:=Point.source_length(PackedInt64Array([0,center[1],center[2]]));var first:=Point._normalized_component(center[1],length);var second:=Point._normalized_component(center[2],length)
		for row in range(2):matrix[row*3+2]=Math.multiply_q31(matrix[row*3+1],first);matrix[row*3+1]=Math.multiply_q31(matrix[row*3+1],second)
		matrix[7]=_s32(-first);matrix[8]=second
	var query_matrix:=PackedInt64Array()
	for corner in range(1,4):query_matrix.append_array(Point._transform(Query._subtract(vertices[corner],origin),matrix))
	return {"matrix":query_matrix,"center":PackedInt64Array([0,0,distance]),"distance":distance,"style":int(payload.decode_u16(4)),"features":payload.slice(6),"limit":2000000000>>(scale&31)}

func _classify_record(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,threshold:int,model:Dictionary,state:Dictionary,graphics:int)->Dictionary:
	# F579 mutates only its local copy via F1658, and applies a further
	# minimum-scale shift to the low observer words, not to the local64 copy.
	var truncated_shift:=maxi(0,Gravity._vec64_msb(relative)-28);var truncated:=PackedInt64Array();var observer:=PackedInt64Array()
	for component:int in relative:
		var value:=Point.shift_int64(component,-truncated_shift);truncated.append(value);observer.append(_s32(value))
	var scale:=truncated_shift;var minimum:=_s32(int(model.mesh_zoom)-23)
	if scale<minimum:
		for axis in range(3):observer[axis]>>=(minimum-scale)&31
		scale=minimum
	var scaled_threshold:=_s32(threshold<<((-scale)&31)) if scale<0 else threshold>>(scale&31)
	var transformed:bool=body[0x57]==0 or body[0x56]!=parent[0x86]
	if transformed:observer=Ground._transpose_transform(observer,Ground._matrix(parent))
	var frame:=_frame(model,observer,scale)
	var outer:=_s32(Point.shift_int64(parent.decode_s64(0x138),-scale));var inner:=_s32(Point.shift_int64(parent.decode_s64(0x140),-scale))
	var trace:={"relative_before_hex":_vector_hex(relative),"relative_truncated_hex":_vector_hex(truncated),"truncated_shift_s32":truncated_shift,"vector_scale_s32":scale,"threshold_before_s32":threshold,"threshold_s32":scaled_threshold,"observer_model_local_raw":observer,"parent_transpose_applied":transformed,"distance_s32":int(frame.distance),"outer_s32":outer,"inner_s32":inner,"terrain_query_calls":0}
	state.collision_kind_u8=255
	var primitive:=0x50;var result:=-1
	if _s32(int(frame.distance)-outer)>=scaled_threshold:
		state.collision_kind_u8=0;trace["branch"]="outside_outer"
	elif _s32(int(frame.distance)-inner)<=scaled_threshold:
		state.collision_kind_u8=1;primitive=0x10;result=0;trace["branch"]="inside_inner"
	else:
		var query:=_query.query_raw(parent.decode_u32(0xa0),int(frame.style),frame.matrix,frame.center,int(frame.limit),graphics,frame.features)
		if query.is_empty():return {}
		var height:=int(query.query_result_raw);trace["branch"]="terrain_query";trace.terrain_query_calls=1
		for key:String in ["query_result_raw","recorded_intersection_raw","pending_query_flag","vertex_pool_count_after_return","depth_control_raw"]:trace[key]=int(query[key])
		trace["query_matrix_raw"]=frame.matrix;trace["query_center_raw"]=frame.center;trace["query_style_raw"]=int(frame.style);trace["query_limit_raw"]=int(frame.limit)
		state.recorded_intersection_raw=int(query.recorded_intersection_raw);state.pending_query_flag=int(query.pending_query_flag)
		if height<int(frame.limit):
			var altitude:=Point.shift_int64(height,scale);state.altitude_low_u32=altitude&MASK;state.altitude_high_s32=_s32(altitude>>32)
		state.previous_altitude_low_u32=int(state.altitude_low_u32);state.previous_altitude_high_s32=int(state.altitude_high_s32)
		if (scaled_threshold>>16)>height:
			state.altitude_low_u32=0;state.altitude_high_s32=0;state.collision_kind_u8=1;primitive=0x10;result=0
	# F582 terrain record returns0 on a hit. An outside result accumulates the
	# low volume bits then executes the actual empty class40 tail (primitive50).
	state.volume_flags_u8=int(state.volume_flags_u8)|(int(model.volume_u8) if result==0 else int(model.volume_u8)&0x7f)
	trace["f579_return_s32"]=result;trace["primitive_u8"]=primitive
	return {"return_s32":result,"primitive_u8":primitive,"trace":trace}

func classify_natural_player(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,context:Dictionary={})->Dictionary:
	if body.size()!=OBJECT_BYTES or parent.size()!=OBJECT_BYTES or relative.size()!=3:return _reject(body,parent,relative,"invalid_object_or_vector_size")
	for key:Variant in context:
		if key not in ["graphics_level","initial_globals"]:return _reject(body,parent,relative,"unsupported_context_field")
	var graphics:Variant=context.get("graphics_level",1);var initial:Variant=context.get("initial_globals",{})
	if not _whole(graphics,0,15) or not initial is Dictionary:return _reject(body,parent,relative,"invalid_query_context")
	var state:=_globals(initial)
	if state.is_empty():return _reject(body,parent,relative,"invalid_source_globals")
	var ship:=ship_model(body.decode_u32(0x82));var model:=parent_model(parent.decode_u32(0x82))
	if ship.is_empty() or model.is_empty():return _reject(body,parent,relative,"unsupported_or_unverified_source_model")
	var initial_state:=state.duplicate(true);state.volume_flags_u8=0
	var local_relative:=relative.duplicate();var threshold:=_s32(body.decode_u32(0x140));var child_index:=0;var iterations:Array=[];var queries:Array=[];var result:=-1
	while true:
		var classified:=_classify_record(body,parent,local_relative,threshold,model,state,int(graphics))
		if classified.is_empty():return _reject(body,parent,relative,"unsupported_or_failed_source_query")
		var trace:Dictionary=classified.trace;trace["child_index"]=child_index;iterations.append(trace)
		if int(trace.terrain_query_calls)>0:queries.append(trace.duplicate(true))
		if int(classified.return_s32)>0:state.volume_flags_u8=int(state.volume_flags_u8)|0x80
		if int(state.volume_flags_u8)!=0:
			state.collider_index_u8=int(parent[0x86]);state.collider_parent_selected=true;state.collision_flags_u8=int(state.volume_flags_u8);state.primitive_flags_u8=int(classified.primitive_u8)
		if int(classified.return_s32)>=0:result=0;break
		if body[0x14c]<128 or child_index>=ship.children.size():break
		var child:Dictionary=ship.children[child_index];var encoded:=int(child.axis_radius_encoded_s16);var row:=(encoded&6)/2;var shift:=_s32(23-int(ship.descriptor.decode_s32(0x14)))
		threshold=_s32((encoded&0xfff8)<<15)
		if shift!=0:threshold>>=shift&31
		local_relative=PackedInt64Array()
		for axis in range(3):
			var component:=body.decode_s32((int(row)*3+axis)*4)
			if encoded&1:component=_s32(-component)
			component=_s32((component>>16)*int(child.displacement_s16))
			if shift!=0:component>>=shift&31
			local_relative.append(_add64(relative[axis],component))
		child_index+=1
	# Publish final changed values, not a memory-write instruction audit.
	var writes:Dictionary={}
	for key:String in GLOBAL_KEYS:
		if state[key]!=initial_state[key]:writes[key]=state[key]
	var altitude:=(int(state.altitude_high_s32)<<32)|int(state.altitude_low_u32);var previous:=(int(state.previous_altitude_high_s32)<<32)|int(state.previous_altitude_low_u32)
	return {"ok":true,"error":"","body_after":body.duplicate(),"parent_after":parent.duplicate(),"relative_position_s64":relative.duplicate(),"f576_return_s32":result,"return_s32":result,"globals_after":state,"global_writes":writes,"altitude_s64":altitude,"previous_altitude_s64":previous,"height_s32":int(state.altitude_low_u32) if int(state.altitude_high_s32)==0 and _s32(int(state.altitude_low_u32))>=0 else -1,"iterations":iterations,"query_trace":queries,"terrain_query_calls":queries.size(),"source_contract":CONTRACT,"source_sha256":SOURCE_SHA,"scope":"natural117..148; actual player15/24/38 child lists; classification only; no F569/F570, F575 response, F578, bank collision, damage or phone pose"}
