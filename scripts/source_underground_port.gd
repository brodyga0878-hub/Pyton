extends RefCounted
# Original model96 is a roof-entry enclosed hangar (child237), not an open pad.
# Source F650/F741/F865 are preserved separately from the mobile route adapter.
const VM=preload("res://scripts/source_model_vm.gd")
const Compiler=preload("res://scripts/source_model_mesh.gd")
const City=preload("res://scripts/source_city_runtime.gd")
const Placement=preload("res://scripts/source_city_profile.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const Pads=preload("res://scripts/source_ground_pads.gd")
const Station=preload("res://scripts/source_station_geometry.gd")
const Units=preload("res://scripts/source_units.gd")
const Segment=preload("res://scripts/segment_triangle.gd")
const REVISION:="source-enclosed-ground-hangar-v1"
const STATE_REVISION:="source-enclosed-ground-state-v1"
const HATCH_HEIGHT_RAW:=65535
# Fixed outside vertices of actual model237 faces at offsets272..320.
const HATCH_HEX_RAW:=[[-196607,0],[-98303,-163840],[98303,-163840],[196607,0],[98303,163839],[-98303,163839]]
const SLOT_COUNT:=6
const FLOOR_CLEARANCE_M:=0.25 # Explicit mobile ellipsoid/gear clearance adapter.
const PHASES:=["closed","opening","approach","inside","docked","departing","closing"]
static var _cache:Dictionary={}
static var _cache_order:Array=[]
static var _mutex:=Mutex.new()

static func _integer(value:Variant,minimum:int,maximum:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==float(int(value)) and int(value)>=minimum and int(value)<=maximum
static func _u16(value:Variant)->bool:return _integer(value,0,65535)
static func _u32(value:Variant)->bool:return _integer(value,0,0xffffffff)
static func _matrix_valid(matrix:Variant)->bool:
	if not matrix is Array or matrix.size()!=9:return false
	for value in matrix:
		if not _integer(value,-2147483648,2147483647):return false
	return true
static func _signed16(value:int)->int:return (value+32768)%65536-32768
static func clear_cache()->void:
	_mutex.lock();_cache.clear();_cache_order.clear();_mutex.unlock()

static func approach_raw(matrix:Array)->Array:
	# Complete ground branch's F1669 + F741 signed16 waypoint storage; F610 later
	# expands these navigation offsets by <<10. Do not use ideal trigonometry.
	if not _matrix_valid(matrix):return []
	var result:Array=[]
	for axis in range(3):result.append(_signed16(Ground.multiply_q31(6000,int(matrix[3+axis])))<<10)
	return result

static func reserve(identifier:Variant,occupancy:Array,matrix:Array,last_slot:Variant=5)->Dictionary:
	# Full non-player/non-openpad F650 path, including signed byte comparisons.
	# The six slots reserve traffic; there are no six geometric landing pads.
	if not _integer(identifier,-2147483648,2147483647) or not _integer(last_slot,-1,5) or occupancy.size()<SLOT_COUNT or not _matrix_valid(matrix):return {}
	for value in occupancy:
		if not _integer(value,0,255):return {}
	var slots:Array=[]
	for value in occupancy:slots.append(int(value))
	var selected:=int(last_slot);var allocated:=0
	while selected>=0:
		var slot:=int(slots[selected]);var signed_slot:=slot if slot<128 else slot-256
		if signed_slot==int(identifier):break
		if slot==0:slots[selected]=int(identifier)&255;allocated=-1;break
		selected-=1
	if selected<0:return {"return_i32":-1,"occupancy_after_u8":slots,"initialized_last_slot_i32":5,"selected_slot_i32":-1}
	return {"return_i32":0,"allocation_status_i32":allocated,"selected_slot_i32":selected,
		"target_vec64_raw":[0,0,-1],"occupancy_after_u8":slots,"initialized_last_slot_i32":5}

static func describe(site:Dictionary,radius:float,root_elevation_m:=0.0)->Dictionary:
	if int(site.get("type_code",-1))!=35 or int(site.get("model_index",-1))!=96 or not _u32(site.get("source_seed")) or not is_finite(radius) or radius<=0 or not is_finite(root_elevation_m):return {}
	if not _u16(site.get("ground_phase_u16")) or not _u16(site.get("ground_inclination_u16")):return {}
	var coordinates:Array=Ground.coordinates(site)
	if coordinates.is_empty() or VM.model(96).is_empty():return {}
	var matrix:=Pads.matrix_for_angles(int(site.ground_phase_u16),int(site.ground_inclination_u16))
	var basis:=Placement.basis_at(coordinates[0],coordinates[1]);var inverse:=basis.inverse()
	var source_basis:=Basis(Vector3(matrix[0],matrix[1],matrix[2])/2147483648.0,Vector3(matrix[3],matrix[4],matrix[5])/2147483648.0,Vector3(matrix[6],matrix[7],matrix[8])/2147483648.0)
	var port_basis:=inverse*source_basis
	var normal:=source_basis.x.cross(source_basis.z).normalized()
	if normal.dot(basis.y)<0:normal=-normal
	var asset:=VM.model(96)
	var outer:=Units.metres(float(asset.outer_radius_q8)*pow(2.0,int(asset.scale)+int(asset.scale2)-8))
	var inner:=maxf(1000.0,maxf(192.0*pow(2.0,int(asset.scale)+int(asset.scale2))*Units.METRES_PER_RAW,outer*1.6+64.0))
	return {"site_id":str(site.get("id","")),"model_index":96,"source_seed":int(site.source_seed),
		"root_latitude":coordinates[0],"root_longitude":coordinates[1],"root_basis":basis,
		"source_matrix_q31":matrix,"plane_normal_body":[float(normal.x),float(normal.y),float(normal.z)],
		"port_basis_local":port_basis,"pad_index":-1,"pad_count":0,"reservation_count":SLOT_COUNT,
		"pad_offset_body_m":Vector3.ZERO,"pad_offset_local_m":Vector3.ZERO,"pad_latitude":coordinates[0],"pad_longitude":coordinates[1],
		"dock_sentinel_raw":[0,0,-1],"approach_vec_raw":approach_raw(matrix),
		"hatch_height_source_m":Units.metres(HATCH_HEIGHT_RAW),"flat_inner_m":inner,"flat_outer_m":inner+1000.0,
		"root_elevation_m":root_elevation_m,"enclosed_hangar":true,
		"key":"96:%d:%d:%d:"%[int(site.source_seed),int(site.ground_phase_u16),int(site.ground_inclination_u16)]+String.num(radius,9)+":"+String.num(root_elevation_m,9)}

static func _profile_valid(profile:Dictionary)->bool:
	if int(profile.get("model_index",-1))!=96 or not profile.get("enclosed_hangar",false) or not profile.get("root_basis") is Basis or not City._valid_basis(profile.root_basis) or not profile.get("port_basis_local") is Basis or not profile.port_basis_local.is_finite() or absf(profile.port_basis_local.determinant())<=0.9 or not _matrix_valid(profile.get("source_matrix_q31")) or not _u32(profile.get("source_seed")) or not profile.get("key") is String or str(profile.key).is_empty():return false
	for field in ["root_latitude","root_longitude","root_elevation_m","hatch_height_source_m","flat_inner_m"]:
		if not profile.has(field) or not (profile[field] is int or profile[field] is float) or not is_finite(float(profile[field])):return false
	if absf(float(profile.root_latitude))>PI/2 or float(profile.flat_inner_m)<=0 or not profile.get("approach_vec_raw") is Array or profile.approach_vec_raw.size()!=3:return false
	for value in profile.approach_vec_raw:
		if not _integer(value,-2147483648,2147483647):return false
	return float(profile.hatch_height_source_m)>0

static func _pose_key(profile:Dictionary,door:int)->String:
	# A caller-supplied display key alone cannot identify source geometry.
	var fingerprint:=str(profile.source_seed)+JSON.stringify(profile.source_matrix_q31)+var_to_str(profile.root_basis)+var_to_str(profile.port_basis_local)
	for field in ["root_latitude","root_longitude","root_elevation_m","hatch_height_source_m"]:fingerprint+=String.num(float(profile[field]),15)+":"
	return str(profile.key)+":"+fingerprint.sha256_text()+":door:"+str(door)

static func prepare(profile:Dictionary,door_u16:Variant=0)->Dictionary:
	if not _profile_valid(profile) or not _u16(door_u16):return {"ok":false,"error":"Invalid enclosed source hangar profile or hatch word"}
	_mutex.lock()
	var result:=_prepare_locked(profile,int(door_u16))
	_mutex.unlock()
	return result
static func _prepare_locked(profile:Dictionary,door:int)->Dictionary:
	var key:=_pose_key(profile,door)
	if _cache.has(key):
		if float(_cache[key].footprint_m)>=float(profile.flat_inner_m)-1:return {"ok":false,"error":"Enclosed city geometry exceeds its graded region"}
		var cached:Dictionary=_cache[key].duplicate();cached.profile=profile.duplicate(true);cached.profile.key=key
		return cached
	var entity:Array=[];entity.resize(64);entity.fill(0)
	entity[1]=door;entity[2]=int(profile.source_seed)&65535;entity[3]=(int(profile.source_seed)>>16)&65535
	var compiled:=Compiler.new().compile(96,{"source_seed":int(profile.source_seed),"matrix_q31":profile.source_matrix_q31,"entity_variables_u16":entity})
	if not compiled.get("ok",false):return {"ok":false,"error":compiled.get("error","Original enclosed hangar compilation failed")}
	var inverse:Basis=profile.root_basis.inverse();var triangles:Array=[];var hatch_triangles:Array=[];var footprint:=0.0
	for face in compiled.triangles_raw:
		var triangle:Array[Vector3]=[]
		for point in face.vertices:
			var local:=inverse*Vector3(Units.metres(float(point[0])),Units.metres(float(point[1])),Units.metres(float(point[2])))
			triangle.append(local);footprint=maxf(footprint,Vector2(local.x,local.z).length())
		triangles.append(triangle)
		if int(face.model_index)==237 and str(face.instance_path)=="96/237@20" and int(face.offset)>=272 and int(face.offset)<=320:hatch_triangles.append(triangle)
	if triangles.is_empty() or footprint>=float(profile.get("flat_inner_m",0.0))-1:return {"ok":false,"error":"Enclosed city geometry exceeds its graded region"}
	var indexed:=City._index_triangles(triangles)
	var placed:=profile.duplicate(true);placed.key=key
	var data:={"ok":true,"compiled":compiled,"conversion_basis":inverse,"triangles":triangles,"bounds":indexed.bounds,
		"footprint_m":footprint,"cells":indexed.cells,"large_triangles":indexed.large_triangles,"triangle_bounds":indexed.triangle_bounds,
		"cruise_height_m":maxf(350.0,indexed.bounds.end.y+100.0),"collision_profile":"modern-source-solid-triangles-v1",
		"decorative_collision":false,"cache_key":key,"profile":placed,"door_u16":door,"hatch_triangles":hatch_triangles,
		"enclosed_hangar":true,"revision":REVISION}
	_cache[key]=data;_cache_order.append(key)
	# Exact poses, not quantized substitutes; bounded cache prevents unbounded
	# memory growth while F865 animates. The caller may publish poses on a worker.
	while _cache_order.size()>3:_cache.erase(_cache_order.pop_front())
	var published:=data.duplicate();published.profile=placed.duplicate(true)
	return published

static func _extents(profile:Dictionary,radii:Vector3)->Vector3:
	return City._root_radii(profile.port_basis_local.inverse(),radii)
static func route(profile:Dictionary,radii:Vector3)->Dictionary:
	if not _profile_valid(profile) or not radii.is_finite() or minf(radii.x,minf(radii.y,radii.z))<=0:return {}
	var extent:=_extents(profile,radii);var basis:Basis=profile.port_basis_local
	var roof:=float(profile.hatch_height_source_m)
	var raw:Array=profile.approach_vec_raw
	var outer:Vector3=profile.root_basis.inverse()*Vector3(Units.metres(raw[0]),Units.metres(raw[1]),Units.metres(raw[2]))
	var polygon:=PackedVector2Array()
	for point in HATCH_HEX_RAW:polygon.append(Vector2(Units.metres(point[0]),Units.metres(point[1])))
	var inradius:=INF
	for index in range(polygon.size()):
		var a:=polygon[index];var edge:=polygon[(index+1)%polygon.size()]-a
		inradius=minf(inradius,absf(a.cross(edge))/edge.length())
	var fits:=Vector2(extent.x,extent.z).length()+FLOOR_CLEARANCE_M<inradius and 2.0*(extent.y+FLOOR_CLEARANCE_M)<roof
	return {"outer_local_m":outer,"entrance_local_m":basis*Vector3(0,roof+extent.y+15.0,0),
		"interior_local_m":basis*Vector3(0,extent.y+FLOOR_CLEARANCE_M,0),
		"hatch_center_local_m":basis*Vector3(0,roof,0),"up_local":basis.y.normalized(),
		"source_extents_m":extent,"hatch_inradius_source_m":inradius,"fits":fits,
		"source_outer_vec_raw":raw.duplicate(),"source_dock_sentinel_raw":[0,0,-1],
		"adaptation":"mobile-ellipsoid-vertical-hangar-route-v1"}

static func classify(profile:Dictionary,position:Vector3,radii:Vector3)->Dictionary:
	var planned:=route(profile,radii)
	if planned.is_empty() or not position.is_finite():return {}
	var local:Vector3=profile.port_basis_local.inverse()*position
	var extent:Vector3=planned.source_extents_m;var roof:=float(profile.hatch_height_source_m)
	var lateral:=Vector2(local.x,local.z).length()+Vector2(extent.x,extent.z).length()<float(planned.hatch_inradius_source_m)-FLOOR_CLEARANCE_M
	var outer_radius:=0.0
	for point in HATCH_HEX_RAW:outer_radius=maxf(outer_radius,Vector2(Units.metres(point[0]),Units.metres(point[1])).length())
	# Whole-hull containment grants entry. Closing protection instead needs ANY
	# overlap, including a ship straddling an edge of the real hatch polygon.
	var aperture_overlap:=Vector2(local.x,local.z).length()<=outer_radius+Vector2(extent.x,extent.z).length()+FLOOR_CLEARANCE_M
	return {"source_local_m":local,"lateral_inside":lateral,"below_roof":local.y+extent.y<roof-FLOOR_CLEARANCE_M,
		"above_roof":local.y-extent.y>roof+FLOOR_CLEARANCE_M,"inside":lateral and local.y-extent.y>=-FLOOR_CLEARANCE_M and local.y+extent.y<roof-FLOOR_CLEARANCE_M,
		"aperture_overlap":aperture_overlap,"floor_contact_height_m":extent.y+FLOOR_CLEARANCE_M,"fits":planned.fits}

static func sweep(data:Dictionary,start:Vector3,finish:Vector3,radii:Vector3)->Dictionary:
	# Caller coordinates are root tangent metres; world/globe adapter can use
	# SourceCityRuntime.sweep(data,globe,...) without changing solid triangles.
	if not data.get("ok",false) or not start.is_finite() or not finish.is_finite() or not radii.is_finite() or minf(radii.x,minf(radii.y,radii.z))<=0:return {}
	var extent:=radii+Vector3.ONE*City.BROADPHASE_EPS_M
	var query:=AABB(start.min(finish)-extent,start.max(finish)-start.min(finish)+extent*2)
	var best:Dictionary={}
	for index in City._candidates(data,query):
		var hit:=Segment.sweep(start,finish,data.triangles[index],radii)
		if not hit.is_empty() and (best.is_empty() or float(hit.time)<float(best.time)):
			best=hit;best.triangle_index=index
	return best

static func new_state(site_id:String,docked:=false)->Dictionary:
	if site_id.is_empty():return {}
	return {"revision":STATE_REVISION,"site_id":site_id,"phase":"docked" if docked else "closed","intent":"none","door_u16":65535,"status_u8":0}
static func restore(value:Dictionary,site_id:String)->Dictionary:
	if value.get("revision")!=STATE_REVISION or value.get("site_id")!=site_id or site_id.is_empty() or value.get("phase") not in PHASES or value.get("intent") not in ["none","dock","launch"] or not _u16(value.get("door_u16")) or not _integer(value.get("status_u8"),0,255):return {}
	var phase:=str(value.phase);var intent:=str(value.intent);var door:=int(value.door_u16);var status:=int(value.status_u8)
	if status not in [0,2,3,254,255]:return {}
	if phase=="opening" and (intent=="none" or status!=255):return {}
	if phase in ["approach","inside"] and (intent!="dock" or door!=0 or status not in [254,255]):return {}
	if phase=="departing" and (intent!="launch" or door!=0 or status not in [254,255]):return {}
	if phase in ["closed","docked"] and intent!="none":return {}
	if phase=="closing" and (intent!="none" or status==0):return {}
	if phase=="closed" and (door!=65535 or status!=0):return {}
	return {"revision":STATE_REVISION,"site_id":site_id,"phase":phase,"intent":intent,"door_u16":door,"status_u8":status}
static func snapshot(state:Dictionary)->Dictionary:return restore(state,str(state.get("site_id","")))
static func command(state:Dictionary,action:String)->Dictionary:
	var next:=snapshot(state)
	if next.is_empty():return {}
	if action=="dock" and str(next.phase) in ["closed","closing"]:
		next.intent="dock";next.phase="opening";next.status_u8=255
	elif action=="launch" and str(next.phase)=="docked":
		next.intent="launch";next.phase="opening";next.status_u8=255
	else:return {}
	return next
static func advance(state:Dictionary,source_step_u32:Variant,profile:Dictionary,position:Vector3,radii:Vector3,contact_ok:=false)->Dictionary:
	var next:=snapshot(state);var where:=classify(profile,position,radii)
	if next.is_empty() or not _u32(source_step_u32) or where.is_empty() or str(next.site_id)!=str(profile.site_id):return {}
	# Never sweep a closing hatch through a ship which occupies its aperture.
	var crossing:bool=where.aperture_overlap and not where.below_roof and not where.above_roof
	if str(next.phase) in ["closing","docked"] and int(next.door_u16)<65535 and crossing:next.status_u8=255
	elif str(next.phase)=="closing":next.status_u8=3
	var door:=Station.advance_door(next.door_u16,next.status_u8,source_step_u32)
	if door.is_empty():return {}
	next.door_u16=door.door_u16;next.status_u8=door.status_u8
	match str(next.phase):
		"opening":
			if int(next.door_u16)==0:next.phase="departing" if str(next.intent)=="launch" else "approach"
		"approach":
			if where.inside:next.phase="inside"
		"inside":
			if contact_ok and where.inside and absf(float(where.source_local_m.y)-float(where.floor_contact_height_m))<=1.0:
				next.phase="docked";next.intent="none";next.status_u8=3
			elif where.above_roof:
				# A pilot may abandon descent and fly back out manually.
				next.phase="closing";next.intent="none";next.status_u8=3
		"departing":
			if where.above_roof:next.phase="closing";next.intent="none";next.status_u8=3
		"closing":
			if int(next.door_u16)==65535:next.phase="closed";next.status_u8=0
		"docked":
			if not crossing and int(next.door_u16)<65535:next.status_u8=3
	return next
