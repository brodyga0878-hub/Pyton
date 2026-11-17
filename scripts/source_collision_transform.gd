extends RefCounted
# Whole DOS F580 coordinate prefix. The recursive F582 call belongs to the
# program owner; this pure preparation does not execute or invent its result.
const PROFILE:="dos-firstenc-f580-nested-model-transform-v1"
const CONTEXT_KEYS:=["point_xyz_s32","normals","vertices","mesh_zoom_s32","vector_scale_s32"]
const RESOURCE_KEYS:=["descriptor","normals","vertices","collision_program"]
const MASK:=0xffffffff
static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and float(value)==floorf(float(value))
static func _vector(value:Variant)->bool:
	if not (value is Array or value is PackedInt64Array) or value.size()!=3:return false
	for cell:Variant in value:
		if not _whole(cell,-0x80000000,0x7fffffff):return false
	return true
static func _s32(value:int)->int:return (value&0x7fffffff)-(value&0x80000000)
static func _s8(value:int)->int:return (value&127)-(value&128)
static func _bytes(value:Variant)->bool:return value is PackedByteArray and value.size()<=1048576
static func _origin(context:Dictionary)->int:return int(context.get("vertex_origin_u32",0))
static func _context(value:Variant)->bool:
	if not value is Dictionary:return false
	for key:String in CONTEXT_KEYS:
		if not value.has(key):return false
	return _vector(value.point_xyz_s32) and _bytes(value.normals) and _bytes(value.vertices) and _whole(value.mesh_zoom_s32,-0x80000000,0x7fffffff) and _whole(value.vector_scale_s32,-0x80000000,0x7fffffff) and _whole(value.get("vertex_origin_u32",0),0,value.vertices.size()) and _whole(value.get("normal_origin_u32",0),0,value.normals.size())
static func _resource(value:Variant)->bool:
	if not value is Dictionary:return false
	for key:String in RESOURCE_KEYS:
		if not value.has(key):return false
	return value.descriptor is PackedByteArray and value.descriptor.size()==68 and _bytes(value.normals) and _bytes(value.vertices) and _bytes(value.collision_program) and _whole(value.get("vertex_origin_u32",0),0,value.vertices.size()) and _whole(value.get("normal_origin_u32",0),0,value.normals.size())
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"recursive_F582_executed":false}
static func resume_nested(return_u32:Variant,primitive_u8:Variant)->Dictionary:
	if not _whole(return_u32,0,MASK) or not _whole(primitive_u8,0,255):return _reject("invalid_recursive_boundary_result")
	return {"ok":true,"profile":PROFILE,"return_s32":_s8(int(return_u32)&255),"primitive_u8":int(primitive_u8),"recursive_F582_executed":false,"live_owners_changed":false}
static func prepare_nested(context:Variant,model_resource:Variant,vertex_u8:Variant,orientation_u8:Variant,threshold_s32:Variant)->Dictionary:
	if not _context(context) or not _resource(model_resource) or not _whole(vertex_u8,0,255) or not _whole(orientation_u8,0,255) or not _whole(threshold_s32,-0x80000000,0x7fffffff):return _reject("invalid_nested_model_context")
	var orientation:=int(orientation_u8)
	# Source codes6/7 leave the destination stack vector uninitialized.
	if (orientation&7)>5:return _reject("uninitialized_original_axis_permutation")
	var offset:=_origin(context)+(_s8(int(vertex_u8))>>1)*6
	if offset<0 or offset+6>context.vertices.size():return _reject("source_vertex_outside_resource")
	var displacement:=PackedInt64Array([_s8(int(context.vertices[offset+2])),_s8(int(context.vertices[offset+3])),_s8(int(context.vertices[offset+4]))])
	if (int(vertex_u8)&1)!=0:displacement[0]=_s32(-displacement[0])
	var shift:=_s32(int(context.mesh_zoom_s32)-int(context.vector_scale_s32))
	for axis in range(3):
		displacement[axis]=displacement[axis]>>((-shift)&31) if shift<0 else _s32(displacement[axis]<<(shift&31))
	var point:=PackedInt64Array()
	for axis in range(3):point.append(_s32(int(context.point_xyz_s32[axis])-displacement[axis]))
	if orientation!=0:
		for axis in range(3):
			if (orientation&(0x20>>axis))!=0:point[axis]=_s32(-point[axis])
	var mappings:=[ [0,1,2],[2,0,1],[1,2,0],[2,1,0],[1,0,2],[0,2,1] ]
	var mapping:Array=mappings[orientation&7]
	var transformed:Array=[int(point[int(mapping[0])]),int(point[int(mapping[1])]),int(point[int(mapping[2])])]
	var next:Dictionary={"point_xyz_s32":transformed,"normals":model_resource.normals.duplicate(),"vertices":model_resource.vertices.duplicate(),"mesh_zoom_s32":_s32(model_resource.descriptor.decode_s32(0x14)+model_resource.descriptor.decode_s32(0x18)),"vector_scale_s32":int(context.vector_scale_s32)}
	if model_resource.has("vertex_origin_u32"):next["vertex_origin_u32"]=int(model_resource.vertex_origin_u32)
	if model_resource.has("normal_origin_u32"):next["normal_origin_u32"]=int(model_resource.normal_origin_u32)
	var request:Dictionary={"kind":"F582","context":next.duplicate(true),"threshold_s32":int(threshold_s32)}
	return {"ok":true,"profile":PROFILE,"context_after":next,"program":model_resource.collision_program.duplicate(),"threshold_s32":int(threshold_s32),"source_order":["F580","F1538"],"request":request,"live_owners_changed":false,"recursive_F582_executed":false}
