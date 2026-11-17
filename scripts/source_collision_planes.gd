extends RefCounted
# Whole original DOS F583. Packed six-byte normal/vertex records, byte-width
# X mirroring, wrapped signed32 scaling and the original integer plane test.
# Buffer origins explicitly represent any source prefix preceding a pointer;
# plane0/1 may read the preceding normal and never receive invented bytes.
const PROFILE:="dos-firstenc-f583-packed-plane-v1"
const SOURCE_EXE_SHA256:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const REQUIRED_KEYS:=["point_xyz_s32","normals","vertices","mesh_zoom_s32","vector_scale_s32"]
const OPTIONAL_KEYS:=["normal_origin_u32","vertex_origin_u32"]
const MASK:=0xffffffff
static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high and float(value)==floorf(float(value))
static func _s32(value:int)->int:return (value&0x7fffffff)-(value&0x80000000)
static func _s8(value:int)->int:return (value&127)-(value&128)
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"full_collision_program_VM":false}
static func _context(value:Variant)->bool:
	if not value is Dictionary or value.size()<REQUIRED_KEYS.size() or value.size()>REQUIRED_KEYS.size()+OPTIONAL_KEYS.size():return false
	for key:String in REQUIRED_KEYS:
		if not value.has(key):return false
	for key:Variant in value:
		if not (key is String or key is StringName) or str(key) not in REQUIRED_KEYS and str(key) not in OPTIONAL_KEYS:return false
	if not value.normals is PackedByteArray or not value.vertices is PackedByteArray:return false
	if not (value.point_xyz_s32 is Array or value.point_xyz_s32 is PackedInt64Array) or value.point_xyz_s32.size()!=3:return false
	for part:Variant in value.point_xyz_s32:
		if not _whole(part,-0x80000000,0x7fffffff):return false
	for key:String in ["mesh_zoom_s32","vector_scale_s32"]:
		if not _whole(value[key],-0x80000000,0x7fffffff):return false
	for key:String in OPTIONAL_KEYS:
		if value.has(key) and not _whole(value[key],0,MASK):return false
	return true
static func execute(context:Variant,plane_u8:Variant,threshold_s32:Variant)->Dictionary:
	if not _context(context) or not _whole(plane_u8,0,255) or not _whole(threshold_s32,-0x80000000,0x7fffffff):return _reject("invalid_packed_plane_context")
	var code:=int(plane_u8);var normals:PackedByteArray=context.normals;var vertices:PackedByteArray=context.vertices
	var normal_at:=int(context.get("normal_origin_u32",0))+(code>>1)*6-6
	if normal_at<0 or normal_at+6>normals.size():return _reject("normal_record_unavailable")
	var vertex_code:=int(normals[normal_at]);var vertex_at:=int(context.get("vertex_origin_u32",0))+(vertex_code>>1)*6
	if vertex_at<0 or vertex_at+6>vertices.size():return _reject("vertex_record_unavailable")
	var normal:=PackedInt64Array()
	for axis in range(3):
		var component:=_s8(int(normals[normal_at+2+axis]))
		if axis==0 and (code&1)!=0:component=-component
		normal.append(_s32(component<<8))
	var scale:=_s32(int(context.mesh_zoom_s32)-int(context.vector_scale_s32));var delta:=PackedInt64Array()
	for axis in range(3):
		var raw:int=vertices[vertex_at+2+axis]
		if axis==0 and ((code^vertex_code)&1)!=0:raw=(-raw)&255
		var component:=_s8(raw)
		component=component>>((_s32(-scale))&31) if scale<0 else _s32(component<<(scale&31))
		delta.append(_s32(component-int(context.point_xyz_s32[axis])))
	var combined:=0
	for cell:int in delta:combined|=(-cell)&MASK if cell<0 else cell
	var msb:=0;var word:int=combined&MASK
	while word>1:word>>=1;msb+=1
	var truncated:=maxi(0,msb-13);var distance:=0
	for axis in range(3):distance=_s32(distance+_s32((delta[axis]>>(truncated&31))*normal[axis]))
	distance=_s32(_s32(-distance)*2)
	var threshold:=int(threshold_s32)>>(truncated&31)
	return {"ok":true,"profile":PROFILE,"value_s32":1 if distance>=threshold else 0,"normal_q8_s32":normal,"delta_s32":delta,"truncate_shift_u32":truncated,"distance_s32":distance,"threshold_after_s32":threshold,"source_order":["F583","_abs","_abs","_abs","F1656"],"live_owners_changed":false,"full_collision_program_VM":false}
