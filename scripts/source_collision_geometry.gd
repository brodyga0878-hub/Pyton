extends RefCounted
# Whole original F576 child loop and F579 raw coordinate preparation.
# The live entry invokes the collision-program kernel; observed F582 replies
# exist only as an explicit independently tested callback adapter.
const Program=preload("res://scripts/source_collision_program.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const Surface=preload("res://scripts/source_ground_surface.gd")
const PROFILE:="dos-firstenc-f576-f579-geometry-v1"
const DATA_PATH:="res://data/ffe_collision_programs.json"
const RESOURCE_SHA:="7ccd9884e0c05fc4d645347301112ab972d83c40780243325f3e907d5f527013"
const MASK:=0xffffffff
static var _catalog:Dictionary={}
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false}
static func _s32(value:int)->int:return Ground.signed32(value)
static func _body(value:Variant)->bool:return value is PackedByteArray and value.size()==338
static func _vector(value:Variant)->bool:return value is PackedByteArray and value.size()==24
static func _globals(value:Variant)->Dictionary:
	if not Frame._globals(value):return {}
	return Frame._copy_globals(value)
static func _resource(value:Variant)->bool:
	return value is Dictionary and value.get("descriptor") is PackedByteArray and value.descriptor.size()==68 and value.get("vertices") is PackedByteArray and value.get("normals") is PackedByteArray and value.get("collision_program") is PackedByteArray and value.get("children_records",[]) is Array
static func catalog()->Dictionary:
	if not _catalog.is_empty():return _catalog.duplicate(true)
	if RESOURCE_SHA=="PENDING" or FileAccess.get_sha256(DATA_PATH)!=RESOURCE_SHA:return {}
	var doc:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not doc is Dictionary or not doc.get("models") is Dictionary:return {}
	var result:Dictionary={}
	for key:Variant in doc.models:
		if not key is String or not key.is_valid_int() or str(int(key))!=key:return {}
		var id:=int(key)
		var row:Variant=doc.models[key]
		if not row is Dictionary or not Frame._hex(row.get("descriptor_hex"),68):return {}
		var resource:Dictionary={"model_index_u32":id,"descriptor":str(row.descriptor_hex).hex_decode(),"vertices":str(row.get("vertices_hex","")).hex_decode(),"normals":str(row.get("normals_hex","")).hex_decode(),"collision_program":str(row.get("collision_program_hex","")).hex_decode(),"normal_origin_u32":int(row.get("normals_origin_u32",0)),"vertex_origin_u32":int(row.get("vertices_origin_u32",0)),"children_records":row.get("children_records",[]).duplicate(true),"collision_program_present":row.get("collision_program_present",false)}
		if not _resource(resource):return {}
		result[id]=resource
	for id in range(149):
		if not result.has(id):return {}
	_catalog=result;return _catalog.duplicate(true)
static func _resources(value:Variant)->Dictionary:
	if not value is Dictionary:return {}
	if value.is_empty():return catalog()
	var result:Dictionary={}
	for key:Variant in value:
		if not key is int or key<0 or key>65535 or not _resource(value[key]):return {}
		result[key]=value[key].duplicate(true)
	return result
static func _vec(relative:PackedByteArray)->PackedInt64Array:
	return PackedInt64Array([relative.decode_s64(0),relative.decode_s64(8),relative.decode_s64(16)])
static func _bytes(vector:PackedInt64Array)->PackedByteArray:
	var raw:=PackedByteArray();raw.resize(24)
	for axis in range(3):raw.encode_s64(axis*8,vector[axis])
	return raw
static func _add64(first:int,second:int)->int:
	var low:=(first&MASK)+(second&MASK)
	return (_s32((first>>32)+(second>>32)+(low>>32))<<32)|(low&MASK)
static func prepare_f579(body:Variant,collider:Variant,relative:Variant,threshold:Variant,resources:Variant={})->Dictionary:
	if not _body(body) or not _body(collider) or not _vector(relative) or not Frame._whole(threshold,-0x80000000,0x7fffffff):return _reject("invalid_F579_context")
	var models:=_resources(resources);var model:Variant=models.get(int(collider.decode_u32(0x82)))
	if not _resource(model):return _reject("missing_F579_model")
	if model.has("collision_program_present") and not model.collision_program_present:return _reject("missing_F579_program")
	var descriptor:PackedByteArray=model.descriptor;var original:=_vec(relative)
	var shift:=maxi(0,Gravity._vec64_msb(original)-28);var truncated:=PackedInt64Array();var point:=PackedInt64Array()
	for axis in range(3):
		var cell:=Point.shift_int64(original[axis],-shift);truncated.append(cell);point.append(_s32(cell))
	var mesh_zoom:=_s32(descriptor.decode_s32(0x14)+descriptor.decode_s32(0x18));var minimum:=_s32(mesh_zoom-23)
	if shift<minimum:
		for axis in range(3):point[axis]>>=(minimum-shift)&31
		shift=minimum
	var scaled:=int(threshold)
	if shift<0:scaled=_s32(scaled<<((-shift)&31))
	elif shift>0:scaled>>=shift&31
	var transposed:=int(body[0x57])==0 or int(body[0x56])!=int(collider[0x86])
	if transposed:point=Surface._transpose_transform(point,Surface._matrix(collider))
	var context:Dictionary={"point_xyz_s32":Array(point),"normals":model.normals.duplicate(),"vertices":model.vertices.duplicate(),"mesh_zoom_s32":mesh_zoom,"vector_scale_s32":shift,"normal_origin_u32":int(model.get("normal_origin_u32",0)),"vertex_origin_u32":int(model.get("vertex_origin_u32",0))}
	return {"ok":true,"profile":PROFILE,"geometry_context":context,"threshold_s32":scaled,"relative_after":_bytes(truncated),"program":model.collision_program.duplicate(),"model_index_u32":int(collider.decode_u32(0x82)),"parent_transpose_applied":transposed,"source_order":["F579","F1538","F1658"]+(["F1670"] if transposed else [])}
static func _same_context(a:Variant,b:Dictionary)->bool:
	if not a is Dictionary or a.size()!=b.size():return false
	for key:String in b:
		if not a.has(key):return false
		if b[key] is int:
			if not Frame._whole(a[key],-0x80000000,MASK) or int(a[key])!=int(b[key]):return false
		elif key=="globals":
			if not Frame._globals(a[key]) or not Frame._same_globals(a[key],b[key]):return false
		elif key=="geometry_context":
			if not Program._same_context(a[key],b[key]):return false
		elif a[key]!=b[key]:return false
	return true
static func _raw(value:Variant,count:int=-1)->Variant:
	if value is PackedByteArray:
		return value.duplicate() if count<0 or value.size()==count else null
	if not value is String or value.length()%2!=0 or value.length()>33554432:return null
	var size:int=value.length()/2
	return value.hex_decode() if (count<0 or size==count) and Frame._hex(value,size) else null
static func _decode_rows(rows:Variant,observed:bool)->Variant:
	if not rows is Array or rows.size()>1024:return null
	var result:Array=[]
	for item:Variant in rows:
		if not item is Dictionary:return null
		var row:Dictionary=item.duplicate(true)
		var sides:Array=["before"] if observed else ["before","after"]
		for side:String in sides:
			if not row.get(side) is Dictionary:return null
			var owner:Dictionary=row[side]
			for key:String in ["body","program"]:
				var decoded:Variant=_raw(owner.get(key),338 if key=="body" else -1)
				if decoded==null:return null
				owner[key]=decoded
			var context_key:="geometry_context" if observed else "context"
			if not owner.get(context_key) is Dictionary:return null
			for key:String in ["normals","vertices"]:
				var decoded:Variant=_raw(owner[context_key].get(key))
				if decoded==null:return null
				owner[context_key][key]=decoded
		result.append(row)
	return result
static func _execute(body:Variant,collider:Variant,relative:Variant,globals:Variant,observations:Variant,resources:Variant,observed:bool)->Dictionary:
	if not _body(body) or not _body(collider) or not _vector(relative) or _globals(globals).is_empty() or not observations is Array or observations.size()>64:return _reject("invalid_F576_context")
	if observed:
		var decoded:Variant=_decode_rows(observations,true)
		if decoded==null:return _reject("invalid_F582_observation_bytes")
		observations=decoded
	else:
		var decoded:Array=[]
		for packet:Variant in observations:
			if not packet is Dictionary or not Frame._whole(packet.get("iteration_u32"),0,64):return _reject("invalid_program_observation_packet")
			var rows:Variant=_decode_rows(packet.get("observations"),false)
			if rows==null:return _reject("invalid_program_observation_bytes")
			decoded.append({"iteration_u32":int(packet.iteration_u32),"observations":rows})
		observations=decoded
	var models:=_resources(resources);var ship:Variant=models.get(int(body.decode_u32(0x82)))
	if not _resource(ship):return _reject("missing_F576_model")
	var state:=_globals(globals);state.volume_flags_u8=0
	var threshold:int=body.decode_s32(0x140);var source:=_vec(relative);var local:=source.duplicate();var retained:=PackedInt64Array();var children:Array=ship.get("children_records",[])
	var order:Array=["F576","F1538"];var calls:Array=[];var used:=0;var child:=0
	for iteration in range(65):
		var prepared:=prepare_f579(body,collider,_bytes(local),threshold,models)
		if not prepared.get("ok",false):return prepared
		order.append_array(prepared.source_order)
		var before:Dictionary={"geometry_context":prepared.geometry_context,"threshold_s32":prepared.threshold_s32,"globals":state.duplicate(true),"body":collider.duplicate(),"program":prepared.program.duplicate(),"iteration_u32":iteration}
		var result:Dictionary
		if observed:
			if used>=observations.size():return {"ok":false,"reason":"boundary_required","profile":PROFILE,"pending":{"kind":"F582","before":before},"observations_used":used,"source_order":order}
			var reply:Variant=observations[used]
			if not reply is Dictionary or not _same_context(reply.get("before"),before) or not Frame._whole(reply.get("return_s32"),-128,127) or not Frame._whole(reply.get("primitive_u8"),0,255) or not Frame._globals(reply.get("globals_after")):return _reject("unmatched_F582_observation")
			result={"ok":true,"return_s8":int(reply.return_s32),"primitive_u8":int(reply.primitive_u8),"globals_after":Frame._copy_globals(reply.globals_after),"source_order":["F582"],"requests":[]};used+=1
		else:
			var replies:Array=[]
			if used<observations.size() and observations[used] is Dictionary and int(observations[used].get("iteration_u32",-1))==iteration:
				if not observations[used].get("observations") is Array:return _reject("invalid_program_observation_packet")
				replies=observations[used].observations;used+=1
			# F579 passes the collider to F582; equipment is read there.
			result=Program.execute(collider,prepared.program,prepared.geometry_context,prepared.threshold_s32,state,replies,models)
			if not result.get("ok",false):
				if result.get("pending") is Dictionary:
					var pending:=result.duplicate(true);pending.iteration_u32=iteration;return pending
				return result
		state=Frame._copy_globals(result.globals_after);var returned:int=int(result.return_s8)
		order.append_array(result.source_order);calls.append({"before":before,"relative_after":prepared.relative_after.duplicate(),"return_s32":returned,"primitive_u8":int(result.primitive_u8),"globals_after":state.duplicate(true),"requests":result.get("requests",[]).duplicate(true)})
		if returned>0:state.volume_flags_u8=int(state.volume_flags_u8)|0x80
		if int(state.volume_flags_u8)!=0:
			state.collider_index_u8=int(collider[0x86]);state.collider_ref_u32=int(collider[0x86]);state.collision_flags_u8=int(state.volume_flags_u8);state.primitive_flags_u8=int(result.primitive_u8)
		if returned>=0:
			if used!=observations.size():return _reject("unused_geometry_observations")
			return {"ok":true,"profile":PROFILE,"body_after":body.duplicate(),"collider_after":collider.duplicate(),"relative_after":relative.duplicate(),"return_s32":0,"globals_after":state,"source_order":order,"calls":calls,"requests":calls,"observations_used":used,"live_owners_changed":false,"Main_integrated":false}
		if int(body[0x14c])<128 or child>=children.size():
			if used!=observations.size():return _reject("unused_geometry_observations")
			return {"ok":true,"profile":PROFILE,"body_after":body.duplicate(),"collider_after":collider.duplicate(),"relative_after":relative.duplicate(),"return_s32":-1,"globals_after":state,"source_order":order,"calls":calls,"requests":calls,"observations_used":used,"live_owners_changed":false,"Main_integrated":false}
		var item:Variant=children[child]
		if not item is Dictionary or not Frame._whole(item.get("axis_radius_encoded_s16"),-32768,32767) or not Frame._whole(item.get("displacement_s16"),-32768,32767) or int(item.displacement_s16)==0:return _reject("invalid_F576_child_record")
		var encoded:int=int(item.axis_radius_encoded_s16);var axis_selector:=encoded&6
		if axis_selector!=6:
			retained=PackedInt64Array()
			for axis in range(3):retained.append(body.decode_s32((axis_selector/2)*12+axis*4))
		elif retained.size()!=3:return _reject("uninitialized_first_child_axis6")
		var shift:=_s32(23-int(ship.descriptor.decode_s32(0x14)))
		for axis in range(3):
			if (encoded&1)!=0:retained[axis]=_s32(-retained[axis])
			retained[axis]=_s32((retained[axis]>>16)*int(item.displacement_s16))
			if shift!=0:retained[axis]>>=shift&31
		threshold=_s32((encoded&0xfff8)<<15)
		if shift!=0:threshold>>=shift&31
		local=PackedInt64Array()
		for axis in range(3):local.append(_add64(source[axis],retained[axis]))
		child+=1
	return _reject("geometry_child_boundary_limit")
static func execute(body:Variant,collider:Variant,relative:Variant,globals:Variant,observations:Variant=[],resources:Variant={})->Dictionary:
	return _execute(body,collider,relative,globals,observations,resources,false)
static func execute_observed(body:Variant,collider:Variant,relative:Variant,globals:Variant,observations:Variant=[],resources:Variant={})->Dictionary:
	return _execute(body,collider,relative,globals,observations,resources,true)
