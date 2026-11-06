extends RefCounted
# Original station triangle programs plus explicit modern triangle CCD. Source
# docking-contact arithmetic and mobile approach guards remain separate APIs.
const Compiler=preload("res://scripts/source_model_mesh.gd")
const VM=preload("res://scripts/source_model_vm.gd")
const Units=preload("res://scripts/source_units.gd")
const Segment=preload("res://scripts/segment_triangle.gd")
const Rotation=preload("res://scripts/body_rotation.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const REVISION:="source-station-solid-v1"
const SPIN_REVISION:="source-station-spin-state-v1"
const MODELS:=[72,73,80]
const OUTER_APPROACH_RAW:=4000*1024 # F741 ordinary orbital-station waypoint.
const SOURCE_CONTACT_ALIGNMENT:=0x78000000
const SOURCE_CONTACT_L1_SPEED:=0x258
static var _cache:Dictionary={}

static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=0xffffffff and float(value)==floorf(float(value))
static func _u16(value:Variant)->bool:return _u32(value) and value<=65535
static func _s32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=(-2147483648) and value<=2147483647 and float(value)==floorf(float(value))
static func _point(point:Array)->Vector3:
	return Vector3(Units.metres(float(point[0])),Units.metres(float(point[1])),Units.metres(float(point[2])))
static func clear_cache()->void:_cache.clear()
static func cache_size()->int:return _cache.size()

static func prepare(model_index:int,source_seed:Variant=0,door_u16:Variant=0)->Dictionary:
	if model_index not in MODELS or not _u32(source_seed) or not _u16(door_u16):return {}
	var key:="%d:%d:%d"%[model_index,int(source_seed),int(door_u16)]
	if _cache.has(key):return _cache[key].duplicate(true)
	var entity:Array=[];entity.resize(64);entity.fill(0)
	entity[1]=int(door_u16);entity[2]=int(source_seed)&65535;entity[3]=(int(source_seed)>>16)&65535
	var compiled:=Compiler.new().compile(model_index,{"source_seed":int(source_seed),"entity_variables_u16":entity})
	if not compiled.get("ok",false):return {}
	var triangles:Array=[];var boxes:Array=[];var bay:=AABB();var bounds:=AABB();var first:=true;var first_bay:=true
	for face:Dictionary in compiled.triangles_raw:
		var triangle:Array[Vector3]=[]
		for raw:Array in face.vertices:triangle.append(_point(raw))
		if triangle.size()!=3:return {}
		var box:=AABB(triangle[0],Vector3.ZERO)
		for point:Vector3 in triangle:box=box.expand(point)
		triangles.append(triangle);boxes.append(box)
		bounds=box if first else bounds.merge(box);first=false
		if int(face.model_index)==227:
			bay=box if first_bay else bay.merge(box);first_bay=false
	if triangles.is_empty() or first_bay:return {}
	var asset:=VM.model(model_index)
	var result:={"ok":true,"revision":REVISION,"model_index":model_index,"source_seed":int(source_seed),"door_u16":int(door_u16),"compiled":compiled,
		"triangles":triangles,"triangle_bounds":boxes,"bounds":bounds,"dock_bay":bay,"dock_local":Vector3.ZERO,"entry_axis":Vector3.BACK,
		"approach_waypoint":Vector3(0,0,Units.metres(float(OUTER_APPROACH_RAW))),"source_units":"16785/2^24 metres per raw unit; direct source XYZ",
		"descriptor_sha256":str(asset.descriptor_sha256),"mesh_sha256":str(asset.mesh_sha256),
		"collision_profile":"modern-ellipsoid-vs-source-solid-triangles-v1","original_collision_vm":false,"decorative_collision":false,
		"original_autopilot":false,"source_dock_target":"F650 ordinary-port sentinel resolves to station centre","cache_key":key}
	# Only a few selected sites are needed; all callers receive independent
	# containers so diagnostics or render configuration cannot poison the cache.
	if _cache.size()>=12:_cache.erase(_cache.keys()[0])
	_cache[key]=result
	return result.duplicate(true)

static func prepare_site(site:Dictionary,door_u16:Variant=0)->Dictionary:
	if int(site.get("type_code",-1)) not in [32,33,34] or int(site.get("model_index",-1)) not in MODELS:return {}
	var record:=str(site.get("runtime_record_hex","")).hex_decode()
	if record.size()!=68 or int(record.decode_u16(12))!=int(site.model_index) or int(record.decode_u16(10))!=int(site.type_code):return {}
	return prepare(int(site.model_index),int(record.decode_u32(4)),door_u16)

static func _valid_geometry(data:Dictionary)->bool:
	return data.get("ok",false)==true and data.get("revision")==REVISION and data.get("triangles") is Array and data.get("triangle_bounds") is Array and data.triangles.size()==data.triangle_bounds.size() and data.get("bounds") is AABB and data.get("dock_bay") is AABB

static func sweep(data:Dictionary,start:Vector3,finish:Vector3,radii:Vector3)->Dictionary:
	if not _valid_geometry(data) or not start.is_finite() or not finish.is_finite() or not radii.is_finite() or radii.x<=0 or radii.y<=0 or radii.z<=0:return {}
	var box:=AABB(start.min(finish)-radii,start.max(finish)-start.min(finish)+radii*2)
	if not box.intersects(data.bounds.grow(0.003)):return {}
	var best:Dictionary={}
	for index in range(data.triangles.size()):
		if not box.intersects(data.triangle_bounds[index].grow(0.003)):continue
		var hit:=Segment.sweep(start,finish,data.triangles[index],radii)
		if not hit.is_empty() and (best.is_empty() or float(hit.time)<float(best.time)):
			best=hit;best["triangle_index"]=index
	return best

static func approach_clear(data:Dictionary,radii:Vector3)->bool:
	if not _valid_geometry(data) or int(data.get("door_u16",-1))!=0:return false
	if not radii.is_finite():return false
	var bay:AABB=data.dock_bay
	if radii.x<=0 or radii.y<=0 or radii.z<=0 or radii.x>=minf(-bay.position.x,bay.end.x) or radii.y>=minf(-bay.position.y,bay.end.y):return false
	return sweep(data,data.approach_waypoint,Vector3.ZERO,radii).is_empty()

static func mobile_dock_ready(data:Dictionary,position:Vector3,velocity:Vector3,forward:Vector3,up:Vector3,radii:Vector3,speed_limit:=12.0)->bool:
	# Modern phone control: strict capped speed, heading and a small interior
	# target volume. It never replaces the separate original raw contact rule.
	if not _valid_geometry(data) or int(data.get("door_u16",-1))!=0 or not position.is_finite() or not velocity.is_finite() or not forward.is_finite() or not up.is_finite() or not is_finite(speed_limit) or speed_limit<=0 or speed_limit>12.0:return false
	if not radii.is_finite() or radii.x<=0 or radii.y<=0 or radii.z<=0:return false
	if velocity.length()>speed_limit or forward.length_squared()<0.5 or up.length_squared()<0.5:return false
	if forward.normalized().dot(Vector3.FORWARD)<0.9375 or up.normalized().dot(Vector3.UP)<0.9375:return false
	var bay:AABB=data.dock_bay
	if absf(position.x)+radii.x>=minf(-bay.position.x,bay.end.x) or absf(position.y)+radii.y>=minf(-bay.position.y,bay.end.y):return false
	if absf(position.z)>8.0 or position.z-radii.z<=bay.position.z or position.z+radii.z>=bay.end.z:return false
	return sweep(data,position,position,radii).is_empty()

static func source_contact(velocity_s32:PackedInt64Array,up_q31:PackedInt64Array,normal_q31:PackedInt64Array,gear_u16:Variant,initial_flags_u8:Variant=0,damage_enabled_u8:Variant=0)->Dictionary:
	# Exact final acceptance slice of F575, NOT its collision/normal provider.
	if velocity_s32.size()!=3 or up_q31.size()!=3 or normal_q31.size()!=3 or not _u16(gear_u16) or not _u16(initial_flags_u8) or initial_flags_u8>255 or not _u16(damage_enabled_u8) or damage_enabled_u8>255:return {}
	for value in velocity_s32:
		if not _s32(value):return {}
	for value in up_q31:
		if not _s32(value):return {}
	for value in normal_q31:
		if not _s32(value):return {}
	var l1:=0;var dot:=0
	for axis in range(3):
		l1=Ground.signed32(l1+Ground.signed32(absi(velocity_s32[axis])))
		dot=Ground.signed32(dot+Ground.multiply_q31(up_q31[axis],normal_q31[axis]))
	var accepted:=l1<=SOURCE_CONTACT_L1_SPEED and int(gear_u16)==65535 and dot>=SOURCE_CONTACT_ALIGNMENT
	return {"accepted":accepted,"l1_speed_s32":l1,"alignment_q31":dot,"flags_u8":((int(initial_flags_u8)|0x40)&0x7f) if accepted else int(initial_flags_u8),"damage_enabled_u8":0 if accepted else int(damage_enabled_u8)}

static func initialize_orientation(record:PackedByteArray,tick_u32:Variant,day_u32:Variant)->Dictionary:
	if record.size()!=68 or int(record.decode_u16(10)) not in [32,33,34] or int(record.decode_u16(12)) not in MODELS or not _u32(tick_u32) or not _u32(day_u32):return {}
	var matrix:=Rotation.initialize(int(record[62]),int(record.decode_u16(66)),int(tick_u32))
	return {"revision":SPIN_REVISION,"model_index":int(record.decode_u16(12)),"rotation_raw":int(record[62]),"tilt_u16":int(record.decode_u16(66)),"matrix_q31":Array(matrix),"tick_u32":int(tick_u32),"day_u32":int(day_u32)}

static func advance_door(door_u16:Variant,status_u8:Variant,step_u32:Variant)->Dictionary:
	# Complete original F865, with signed status and wrapped intermediate ADD.
	if not _u16(door_u16) or not _u16(status_u8) or status_u8>255 or not _u32(step_u32):return {}
	var door:=int(door_u16);var status:=int(status_u8);var signed_status:=Rotation.signed8(status)
	if signed_status>0:
		var next:=Ground.signed32(door+(int(step_u32)>>1))
		if next>65535:door=65535;status&=254
		else:door=next&65535
	elif signed_status<0:
		var next:=Ground.signed32(door-(int(step_u32)>>1))
		if next<0:door=0;status=254
		else:door=next&65535
	return {"door_u16":door,"status_u8":status}

static func advance_orientation(state:Dictionary,tick_u32:Variant,day_u32:Variant)->Dictionary:
	if state.get("revision")!=SPIN_REVISION or int(state.get("model_index",-1)) not in MODELS or not _u32(tick_u32) or not _u32(day_u32) or not _u32(state.get("tick_u32")) or not _u32(state.get("day_u32")) or not _u16(state.get("rotation_raw")) or int(state.rotation_raw)>255 or not _u16(state.get("tilt_u16")) or not state.get("matrix_q31") is Array or state.matrix_q31.size()!=9:return {}
	for value in state.matrix_q31:
		if not _s32(value):return {}
	var matrix:=PackedInt64Array(state.matrix_q31)
	var updated:=Rotation.advance(matrix,int(state.rotation_raw),int(state.tilt_u16),0x10,int(state.tick_u32),int(tick_u32),int(state.day_u32),int(day_u32))
	var result:=state.duplicate(true)
	result.model_index=int(state.model_index);result.rotation_raw=int(state.rotation_raw);result.tilt_u16=int(state.tilt_u16)
	result.matrix_q31=Array(updated.matrix);result.tick_u32=int(tick_u32);result.day_u32=int(day_u32)
	return result

static func orientation_basis(state:Dictionary)->Basis:
	if not state.get("matrix_q31") is Array or state.matrix_q31.size()!=9:return Basis.IDENTITY
	var values:Array=state.matrix_q31
	for value in values:
		if not _s32(value):return Basis.IDENTITY
	var first:=Vector3(float(values[0])/2147483648.0,float(values[1])/2147483648.0,float(values[2])/2147483648.0)
	var second:=Vector3(float(values[3])/2147483648.0,float(values[4])/2147483648.0,float(values[5])/2147483648.0)
	var third:=Vector3(float(values[6])/2147483648.0,float(values[7])/2147483648.0,float(values[8])/2147483648.0)
	var basis:=Basis(first,second,third)
	return basis.orthonormalized() if absf(basis.determinant())>0.5 else Basis.IDENTITY
