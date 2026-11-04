extends RefCounted
# Modern CCD against original solid source faces. Render-only decal bias,
# billboards, balls and other decorative events never change these triangles.
const Compiler=preload("res://scripts/source_model_mesh.gd")
const Placement=preload("res://scripts/source_city_profile.gd")
const Units=preload("res://scripts/source_units.gd")
const SegmentTriangle=preload("res://scripts/segment_triangle.gd")
const CELL_SIZE_M:=256.0
const MAX_TRIANGLE_CELLS:=64
const MAX_QUERY_CELLS:=4096
const CACHE_LIMIT:=8
const BROADPHASE_EPS_M:=0.003
static var _cache:Dictionary={}
static var _cache_order:Array=[]
static var _cache_mutex:=Mutex.new()

static func clear_cache()->void:
	_cache_mutex.lock()
	_cache.clear();_cache_order.clear()
	_cache_mutex.unlock()
static func cache_size()->int:
	_cache_mutex.lock()
	var count:=_cache.size()
	_cache_mutex.unlock()
	return count
static func _valid_basis(value:Variant)->bool:
	if not value is Basis:return false
	var basis:Basis=value
	if not basis.is_finite() or absf(basis.determinant()-1.0)>0.001:return false
	return absf(basis.x.length_squared()-1)<0.001 and absf(basis.y.length_squared()-1)<0.001 and absf(basis.z.length_squared()-1)<0.001 and absf(basis.x.dot(basis.y))<0.001 and absf(basis.x.dot(basis.z))<0.001 and absf(basis.y.dot(basis.z))<0.001
static func _valid_profile(profile:Dictionary)->bool:
	if not _valid_basis(profile.get("root_basis",null)):return false
	if not profile.get("source_matrix_q31",null) is Array or profile.source_matrix_q31.size()!=9:return false
	if int(profile.get("model_index",-1))<81 or int(profile.get("model_index",-1))>90:return false
	var seed:Variant=profile.get("source_seed",null)
	if not (seed is int or seed is float) or not is_finite(float(seed)) or float(seed)!=float(int(seed)) or int(seed)<0 or int(seed)>0xffffffff:return false
	if not profile.get("key",null) is String or str(profile.key).is_empty():return false
	for key in ["root_latitude","root_longitude","root_elevation_m"]:
		if not profile.has(key) or not is_finite(float(profile[key])):return false
	if absf(float(profile.root_latitude))>PI*0.5+0.0000001:return false
	for value in profile.source_matrix_q31:
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=float(int(value)) or int(value)<-2147483648 or int(value)>2147483647:return false
	return true
static func _cache_key(profile:Dictionary)->String:
	return str(profile.key)+":"+str(profile.model_index)+":"+str(profile.source_seed)+":"+JSON.stringify(profile.source_matrix_q31)+":"+var_to_str(profile.root_basis)
static func prepare(profile:Dictionary)->Dictionary:
	if not _valid_profile(profile):return {"ok":false,"error":"Invalid original city placement profile"}
	# One optional loading worker and the main thread may request the same city.
	# Serialize compilation/cache publication; published geometry is read-only.
	_cache_mutex.lock()
	var result:=_prepare_locked(profile)
	_cache_mutex.unlock()
	return result
static func _footprint_fits(data:Dictionary,profile:Dictionary)->bool:
	return is_finite(float(profile.get("flat_inner_m",0.0))) and float(data.footprint_m)<float(profile.get("flat_inner_m",0.0))-1.0
static func _prepare_locked(profile:Dictionary)->Dictionary:
	var key:=_cache_key(profile)
	if _cache.has(key):
		if not _footprint_fits(_cache[key],profile):return {"ok":false,"error":"City footprint exceeds the verified graded terrain region"}
		_cache_order.erase(key);_cache_order.append(key)
		var cached:Dictionary=_cache[key].duplicate()
		cached.profile=profile.duplicate(true)
		return cached
	var compiled:=Compiler.new().compile(int(profile.model_index),{"source_seed":int(profile.source_seed),"matrix_q31":profile.source_matrix_q31})
	if not compiled.get("ok",false):return {"ok":false,"error":compiled.get("error","Original city compilation failed")}
	var conversion:Basis=profile.root_basis.inverse()
	var triangles:Array=[]
	for face in compiled.triangles_raw:
		var triangle:Array[Vector3]=[]
		for point in face.vertices:
			# Convert scalar source units before Vector3 to retain local precision.
			var body_m:=Vector3(Units.metres(float(point[0])),Units.metres(float(point[1])),Units.metres(float(point[2])))
			triangle.append(conversion*body_m)
		triangles.append(triangle)
	if triangles.is_empty():return {"ok":false,"error":"Original city contains no solid source triangles"}
	var indexed:=_index_triangles(triangles)
	var footprint:=0.0
	for triangle in triangles:
		for point in triangle:footprint=maxf(footprint,Vector2(point.x,point.z).length())
	var data:={"ok":true,"compiled":compiled,"conversion_basis":conversion,"triangles":triangles,"bounds":indexed.bounds,
		"footprint_m":footprint,
		"cells":indexed.cells,"large_triangles":indexed.large_triangles,"triangle_bounds":indexed.triangle_bounds,
		"cruise_height_m":maxf(350.0,indexed.bounds.end.y+100.0),"collision_profile":"modern-source-solid-triangles-v1",
		"decorative_collision":false,"cache_key":key}
	if not _footprint_fits(data,profile):return {"ok":false,"error":"City footprint exceeds the verified graded terrain region","footprint_m":footprint}
	_cache[key]=data
	_cache_order.append(key)
	while _cache_order.size()>CACHE_LIMIT:_cache.erase(_cache_order.pop_front())
	var result:=data.duplicate()
	result.profile=profile.duplicate(true)
	return result

static func transform_to_frame(profile:Dictionary,globe:Variant)->Transform3D:
	var root_basis:Basis=profile.root_basis
	var current_basis:=Placement.basis_at(float(globe.latitude),float(globe.longitude))
	var root_lat:=float(profile.root_latitude);var root_lon:=float(profile.root_longitude)
	var current_lat:=float(globe.latitude);var current_lon:=float(globe.longitude)
	var radius:=float(globe.radius);var elevation:=float(profile.get("root_elevation_m",0.0))
	var rx:=cos(root_lat)*cos(root_lon);var ry:=sin(root_lat);var rz:=-cos(root_lat)*sin(root_lon)
	var cx:=cos(current_lat)*cos(current_lon);var cy:=sin(current_lat);var cz:=-cos(current_lat)*sin(current_lon)
	# Subtract the unit components in scalar double precision FIRST. Casting
	# Earth-radius absolute positions to Vector3 would lose sub-metre motion.
	var difference:=Vector3((rx-cx)*radius+rx*elevation,(ry-cy)*radius+ry*elevation,(rz-cz)*radius+rz*elevation)
	var inverse:=current_basis.inverse()
	return Transform3D(inverse*root_basis,inverse*difference)

static func _index_triangles(triangles:Array)->Dictionary:
	var cells:Dictionary={};var large:=PackedInt32Array();var boxes:Array=[];var bounds:=AABB();var first:=true
	for index in range(triangles.size()):
		var triangle:Array=triangles[index]
		var box:=AABB(triangle[0],Vector3.ZERO)
		for point in triangle:box=box.expand(point)
		boxes.append(box)
		if first:bounds=box;first=false
		else:bounds=bounds.merge(box)
		var x0:=floori(box.position.x/CELL_SIZE_M);var x1:=floori(box.end.x/CELL_SIZE_M)
		var z0:=floori(box.position.z/CELL_SIZE_M);var z1:=floori(box.end.z/CELL_SIZE_M)
		if (x1-x0+1)*(z1-z0+1)>MAX_TRIANGLE_CELLS:large.append(index);continue
		for x in range(x0,x1+1):
			for z in range(z0,z1+1):
				var cell:=Vector2i(x,z)
				if not cells.has(cell):cells[cell]=[]
				cells[cell].append(index)
	for cell in cells:cells[cell]=PackedInt32Array(cells[cell])
	return {"cells":cells,"large_triangles":large,"triangle_bounds":boxes,"bounds":bounds}
static func _boxes_overlap(first:AABB,second:AABB)->bool:
	return first.position.x<=second.end.x and second.position.x<=first.end.x and first.position.y<=second.end.y and second.position.y<=first.end.y and first.position.z<=second.end.z and second.position.z<=first.end.z
static func _root_radii(inverse:Basis,radii:Vector3)->Vector3:
	# Exact AABB extents of the current-axis ellipsoid after rigid rotation.
	var result:=Vector3.ZERO
	for axis in range(3):result[axis]=sqrt(pow(float(inverse.x[axis])*radii.x,2)+pow(float(inverse.y[axis])*radii.y,2)+pow(float(inverse.z[axis])*radii.z,2))
	return result+Vector3.ONE*BROADPHASE_EPS_M
static func _candidates(data:Dictionary,query:AABB)->Array:
	if not _boxes_overlap(data.bounds.grow(BROADPHASE_EPS_M),query):return []
	var seen:Dictionary={}
	var x0:=floori(query.position.x/CELL_SIZE_M);var x1:=floori(query.end.x/CELL_SIZE_M)
	var z0:=floori(query.position.z/CELL_SIZE_M);var z1:=floori(query.end.z/CELL_SIZE_M)
	if (x1-x0+1)*(z1-z0+1)>MAX_QUERY_CELLS:
		for index in range(data.triangles.size()):seen[index]=true
	else:
		for index in data.large_triangles:seen[int(index)]=true
		for x in range(x0,x1+1):
			for z in range(z0,z1+1):
				for index in data.cells.get(Vector2i(x,z),PackedInt32Array()):seen[int(index)]=true
	var result:Array=[]
	for index in seen:
		if _boxes_overlap(data.triangle_bounds[index].grow(BROADPHASE_EPS_M),query):result.append(index)
	result.sort()
	return result
static func sweep(data:Dictionary,globe:Variant,start:Vector3,finish:Vector3,radii:Vector3)->Dictionary:
	if not data.get("ok",false) or not start.is_finite() or not finish.is_finite() or not radii.is_finite() or radii.x<=0 or radii.y<=0 or radii.z<=0:return {}
	var transform:=transform_to_frame(data.profile,globe)
	if not transform.is_finite():return {}
	var inverse:=transform.affine_inverse()
	var first:=inverse*start;var last:=inverse*finish
	var extent:=_root_radii(inverse.basis,radii)
	# Float32 local vectors may gain a few ulps through a large rebase. A
	# conservative broad-phase margin changes candidate selection only.
	extent+=Vector3.ONE*maxf(first.length(),last.length())*0.000001
	var query:=AABB(first.min(last)-extent,first.max(last)-first.min(last)+extent*2.0)
	var best:Dictionary={}
	for index in _candidates(data,query):
		var triangle:Array[Vector3]=[]
		for point in data.triangles[index]:triangle.append(transform*point)
		# Do not transform anisotropic radii into a falsely axis-aligned root
		# ellipsoid: the actual narrow phase is evaluated in CURRENT axes.
		var hit:=SegmentTriangle.sweep(start,finish,triangle,radii)
		if hit.is_empty():continue
		if best.is_empty() or float(hit.time)<float(best.time):
			best=hit;best.triangle_index=index;best.site_id=str(data.profile.get("site_id",""))
	return best
static func overlaps(data:Dictionary,globe:Variant,center:Vector3,radii:Vector3)->bool:
	return not sweep(data,globe,center,center,radii).is_empty()
