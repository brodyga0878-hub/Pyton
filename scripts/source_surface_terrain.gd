extends "res://scripts/spherical_terrain.gd"
# Explicit SI/geographic adapter around the independently checked source kernel.
# Legacy sphere-v1/v2/v3 are implemented only by spherical_terrain.gd.
const REVISION_NAME:="sphere-source-ground-v4"
const BOUNDARY_POLICY:="source_exterior_probe_125pct_axes_v1"
const SAMPLE_POLICY:="continuous_q31_source_probe_grid_v1"
const SourceKernel=preload("res://scripts/source_ground_surface.gd")
const TerrainPoint=preload("res://scripts/source_terrain_point.gd")
const Pads=preload("res://scripts/source_ground_pads.gd")
const Units=preload("res://scripts/source_units.gd")
const Underground=preload("res://scripts/source_underground_port.gd")
const CELL_METRES:=256.0
const CACHE_LIMIT:=8192
const SOURCE_DETAIL:=1
var source_record:=PackedByteArray()
var source_model_index:=-1
var configured_ok:=false
var configuration_error:=""
var source_policy:Dictionary={}
var _kernel:=SourceKernel.new()
var _probe:=PackedByteArray()
var _parent:=PackedByteArray()
var _cache:Dictionary={}
var _cache_order:Array[String]=[]
var _cache_hits:=0
var _source_samples:=0
var _cache_evictions:=0
var _generation:=0
var _lat_cells:=1
var _lon_cells:=1
var _mutex:=Mutex.new()

func _init()->void:revision=REVISION_NAME

static func supported_model(record:PackedByteArray)->bool:
	return record.size()==68 and int(record.decode_u16(12))>=117 and int(record.decode_u16(12))<=133

static func geometry_metadata(record:PackedByteArray)->Dictionary:
	if not supported_model(record):return {}
	var model_index:=int(record.decode_u16(12))
	var model:=SourceKernel.model_resources(model_index)
	if model.is_empty():return {}
	var vertices:=str(model.vertices_hex).hex_decode()
	if vertices.size()!=24:return {}
	var axes:=PackedInt64Array([absi(vertices.decode_s8(2)),absi(vertices.decode_s8(15)),absi(vertices.decode_s8(10))])
	var exponent:=int(model.scale)+int(model.scale2)
	var maximum:=maxi(axes[0],maxi(axes[1],axes[2]))
	var raw_reference:=float(maximum)*pow(2.0,exponent)*(1.25 if model_index==117 else 1.0)
	return {"model_index":model_index,"static_axes_raw":axes,"mesh_zoom":exponent,
		"reference_radius_raw":raw_reference,"reference_radius_m":Units.metres(raw_reference),
		"exterior_probe_guard_raw":maxi(65536,roundi(raw_reference)>>12) if model_index==117 else 0,
		"original_outer_bound_raw":int(model.outer_radius_raw)<<int(model.model_scale_raw),
		"original_inner_bound_raw":int(model.inner_radius_raw)<<int(model.model_scale_raw),
		"boundary_policy":BOUNDARY_POLICY if model_index==117 else "source_descriptor_bounds_v1",
		"reference_is_physical_sphere":model_index!=117,"height_policy":SAMPLE_POLICY,"graphics_level_raw":SOURCE_DETAIL}

static func reference_radius(record:PackedByteArray)->float:
	return float(geometry_metadata(record).get("reference_radius_m",0.0))

static func radial_q31(lat:float,lon:float)->PackedInt64Array:
	if not is_finite(lat) or not is_finite(lon) or absf(lat)>PI*0.5+1e-12:return PackedInt64Array()
	var cl:=cos(lat)
	return PackedInt64Array([roundi(cl*cos(lon)*2147483647.0),roundi(sin(lat)*2147483647.0),roundi(-cl*sin(lon)*2147483647.0)])

static func _radius_raw(point:PackedInt64Array)->float:
	return sqrt(float(point[0])*point[0]+float(point[1])*point[1]+float(point[2])*point[2])

static func _lat_lon(point:PackedInt64Array)->Array:
	return [atan2(float(point[1]),sqrt(float(point[0])*point[0]+float(point[2])*point[2])),atan2(-float(point[2]),float(point[0]))]

func configure(system:RefCounted,body_id:String,site_id:String,revision_value:String=REVISION_NAME)->void:
	# Prepare in an isolated instance first: failed data never expose half a body.
	var record:=str(system.by_id.get(body_id,{}).get("runtime_record_hex","")).hex_decode()
	var metadata:=geometry_metadata(record)
	if revision_value!=REVISION_NAME or metadata.is_empty():
		configured_ok=false;configuration_error="Unsupported source terrain body or revision";return
	var raw_parent:=PackedByteArray();raw_parent.resize(SourceKernel.OBJECT_BYTES)
	var raw_probe:=PackedByteArray();raw_probe.resize(SourceKernel.OBJECT_BYTES)
	raw_parent[0x86]=1;raw_parent.encode_u32(0xa0,record.decode_u32(4))
	for axis in range(3):raw_parent.encode_u32(axis*16,0x7fffffff)
	raw_probe[0x56]=1;raw_probe[0x57]=1;raw_probe[0x86]=2
	var parent_init:=SourceKernel.initialize_model(raw_parent,int(metadata.model_index))
	var probe_init:=SourceKernel.initialize_model(raw_probe,84)
	if parent_init.is_empty() or probe_init.is_empty():
		configured_ok=false;configuration_error="Missing original source terrain descriptors";return
	var candidate_parent:PackedByteArray=parent_init.object
	if int(metadata.model_index)==117:
		candidate_parent.encode_s64(0x138,roundi(float(metadata.reference_radius_raw)))
		candidate_parent.encode_s64(0x140,0)
	# Warm immutable shared query data before any worker can receive this object.
	if not _kernel.point_kernel.kernel._load_resources():
		configured_ok=false;configuration_error="Missing original source terrain field";return
	var profiles:Dictionary={};var locations:Dictionary={}
	for site:Dictionary in system.settlements:
		if str(site.get("parent",""))!=body_id or int(site.get("type_code",-1))!=35:continue
		var profile:=source_city_profile(site,record,float(metadata.reference_radius_m))
		if profile.is_empty():
			configured_ok=false;configuration_error="Invalid source ground-port anchor: "+str(site.get("id",""));return
		profiles[str(site.id)]=profile;locations[str(site.id)]=[profile.root_latitude,profile.root_longitude]
	_mutex.lock()
	source_record=record.duplicate();source_model_index=int(metadata.model_index);radius=float(metadata.reference_radius_m)
	_parent=candidate_parent;_probe=probe_init.object;source_policy=metadata.duplicate(true)
	seed_value=int(system.system_id)^body_id.hash();selected_site_id=site_id;revision=REVISION_NAME
	city_profiles=profiles;source_site_coordinates=locations;flat_sites=[]
	_lat_cells=maxi(2,ceili(PI*radius/CELL_METRES));_lon_cells=maxi(4,ceili(TAU*radius/CELL_METRES))
	_reset_cache_locked();configured_ok=true;configuration_error=""
	var pad:=site_coordinates(site_id)
	if profiles.has(site_id):pad=[profiles[site_id].pad_latitude,profiles[site_id].pad_longitude]
	pad_latitude=pad[0];pad_longitude=pad[1];latitude=pad_latitude;longitude=pad_longitude
	_mutex.unlock()

static func source_city_profile(site:Dictionary,parent_record:PackedByteArray,reference_radius_m:float)->Dictionary:
	var port_record:=str(site.get("runtime_record_hex","")).hex_decode()
	if port_record.size()!=68 or not supported_model(parent_record) or reference_radius_m<=0:return {}
	var placement:=SourceKernel.new().place_records(port_record,parent_record,int(site.get("original_index",0)),SOURCE_DETAIL)
	if placement.is_empty():return {}
	var enclosed:=int(site.get("model_index",-1))==96
	var profile:Dictionary=Underground.describe(site,reference_radius_m) if enclosed else CityProfile.describe(site,reference_radius_m)
	if profile.is_empty():return {}
	var point:PackedInt64Array=placement.position_raw
	var ll:=_lat_lon(point);var matrix:Array=[]
	for value in placement.matrix_q31:matrix.append(int(value))
	var positions:Array=Pads.transformed_positions(int(site.model_index),matrix) if not enclosed else [[0,0,0]]
	var pad_index:=int(profile.pad_index)
	if enclosed:pad_index=0
	if pad_index>=positions.size():return {}
	var offset:Array=positions[pad_index]
	var pad_body:=PackedFloat64Array()
	for axis in range(3):pad_body.append(Units.metres(float(point[axis])+float(offset[axis])))
	profile.root_latitude=ll[0];profile.root_longitude=ll[1];profile.root_basis=CityProfile.basis_at(ll[0],ll[1])
	profile.root_elevation_m=Units.metres(_radius_raw(point))-reference_radius_m
	profile.source_matrix_q31=matrix;profile["source_root_raw"]=point.duplicate()
	var row_x:=Vector3(matrix[0],matrix[1],matrix[2])/2147483648.0
	var row_y:=Vector3(matrix[3],matrix[4],matrix[5])/2147483648.0
	var row_z:=Vector3(matrix[6],matrix[7],matrix[8])/2147483648.0
	# Keep the large-radius plane equation in scalar doubles.
	var normal:Array=[float(matrix[1])*matrix[8]-float(matrix[2])*matrix[7],float(matrix[2])*matrix[6]-float(matrix[0])*matrix[8],float(matrix[0])*matrix[7]-float(matrix[1])*matrix[6]]
	var normal_length:=sqrt(float(normal[0])*normal[0]+float(normal[1])*normal[1]+float(normal[2])*normal[2])
	var sign_value:=1.0 if float(normal[0])*point[0]+float(normal[1])*point[1]+float(normal[2])*point[2]>=0 else -1.0
	for axis in range(3):normal[axis]=float(normal[axis])*sign_value/normal_length
	profile.plane_normal_body=normal
	if enclosed:
		profile.port_basis_local=profile.root_basis.inverse()*Basis(row_x,row_y,row_z)
		profile.approach_vec_raw=Underground.approach_raw(matrix)
	profile["source_root_body_m"]=PackedFloat64Array([Units.metres(point[0]),Units.metres(point[1]),Units.metres(point[2])])
	profile.pad_latitude=atan2(pad_body[1],sqrt(pad_body[0]*pad_body[0]+pad_body[2]*pad_body[2]))
	profile.pad_longitude=atan2(-pad_body[2],pad_body[0])
	profile.pad_offset_body_m=Vector3(Units.metres(offset[0]),Units.metres(offset[1]),Units.metres(offset[2]))
	profile.pad_offset_local_m=profile.root_basis.inverse()*profile.pad_offset_body_m
	profile["terrain_revision"]=REVISION_NAME;profile["source_variant"]=SourceKernel.SOURCE_VARIANT
	profile["placement_policy"]="isolated_source_geometry_v1"
	profile.key=REVISION_NAME+":"+str(profile.key)+":"+var_to_bytes(point).hex_encode()
	return profile

func site_coordinates(id:String)->Array:
	if source_site_coordinates.has(id):return source_site_coordinates[id].duplicate()
	# Uninhabited entry is deterministic geography, without artificial flattening.
	return super.site_coordinates(id)

func _sample_direction_unlocked(radial:PackedInt64Array)->Dictionary:
	if radial.size()!=3 or radial==PackedInt64Array([0,0,0]) or not configured_ok:return {}
	for value in radial:
		if value<(-0x80000000) or value>0x7fffffff:return {}
	var result:Dictionary
	if source_model_index==117:
		# A corrected exterior caller probes the actual nonspherical F581 field.
		# Original descriptor bounds remain in metadata and source fixtures.
		var reference_raw:=roundi(float(source_policy.reference_radius_raw))-int(source_policy.exterior_probe_guard_raw)
		var point:=PackedInt64Array()
		for component in radial:point.append((component*reference_raw)>>31)
		var positioned_probe:=_probe.duplicate()
		for axis in range(3):positioned_probe.encode_s64(0x3e+axis*8,point[axis])
		var query:=_kernel.height_raw(positioned_probe,_parent,point,SOURCE_DETAIL)
		if query.is_empty() or int(query.height_s32)<0 or int(query.globals.collision_kind_u8)!=255:return {}
		var surface_radius:=_radius_raw(point)-int(query.height_s32)
		var surface_point:=PackedInt64Array()
		for component in radial:surface_point.append(roundi(float(component)*surface_radius/2147483647.0))
		result={"position_raw":surface_point,"passes":[query],"input_policy":BOUNDARY_POLICY}
	else:
		result=_kernel.sample_radial_raw(_probe,_parent,radial,SOURCE_DETAIL)
		if result.is_empty():return {}
	_source_samples+=1
	result["elevation_m"]=Units.metres(_radius_raw(result.position_raw))-radius
	return result

func _sample_source_unlocked(lat:float,lon:float)->Dictionary:
	var result:=_sample_direction_unlocked(radial_q31(lat,lon))
	if not result.is_empty():result["latitude"]=lat;result["longitude"]=wrapf(lon,-PI,PI)
	return result

func exact_source_direction(radial:PackedInt64Array)->Dictionary:
	_mutex.lock();var result:=_sample_direction_unlocked(radial);_mutex.unlock()
	return result

func exact_source_sample(lat:float,lon:float)->Dictionary:
	_mutex.lock();var result:=_sample_source_unlocked(lat,lon);_mutex.unlock()
	return result

func _reset_cache_locked()->void:
	_cache.clear();_cache_order.clear();_cache_hits=0;_source_samples=0;_cache_evictions=0;_generation+=1

func clear_cache()->void:
	_mutex.lock();_reset_cache_locked();_mutex.unlock()

func cache_stats()->Dictionary:
	_mutex.lock()
	var result:={"entries":_cache.size(),"limit":CACHE_LIMIT,"source_samples":_source_samples,"hits":_cache_hits,"evictions":_cache_evictions,"generation":_generation,"cell_metres":CELL_METRES,"policy":SAMPLE_POLICY}
	_mutex.unlock();return result

func _node_key(x:int,y:int)->String:
	return str(0 if y==0 or y==_lat_cells else posmod(x,_lon_cells))+":"+str(y)

func _node_height_unlocked(x:int,y:int)->float:
	var key:=_node_key(x,y)
	if _cache.has(key):_cache_hits+=1;return float(_cache[key])
	var lat:=-PI*0.5+float(y)*PI/float(_lat_cells)
	var lon:=-PI+float(posmod(x,_lon_cells))*TAU/float(_lon_cells)
	var sampled:=_sample_source_unlocked(lat,lon)
	if sampled.is_empty():return NAN
	var value:=float(sampled.elevation_m)
	_cache[key]=value;_cache_order.append(key)
	if _cache_order.size()>CACHE_LIMIT:
		_cache.erase(_cache_order.pop_front());_cache_evictions+=1
	return value

func _grid_height_unlocked(lat:float,lon:float)->float:
	var y:=clampf((lat+PI*0.5)*float(_lat_cells)/PI,0.0,float(_lat_cells))
	var x:=(wrapf(lon,-PI,PI)+PI)*float(_lon_cells)/TAU
	var ix:=floori(x);var iy:=mini(_lat_cells-1,floori(y))
	var a:=_node_height_unlocked(ix,iy);var b:=_node_height_unlocked(ix+1,iy)
	var c:=_node_height_unlocked(ix,iy+1);var d:=_node_height_unlocked(ix+1,iy+1)
	return lerpf(lerpf(a,b,x-ix),lerpf(c,d,x-ix),y-iy)

func _grade_cities(height:float,lat:float,lon:float)->float:
	var weight:=0.0;var plane:=height
	for profile:Dictionary in city_profiles.values():
		var outer:=float(profile.flat_outer_m)
		if absf(lat-float(profile.root_latitude))*radius>outer:continue
		var delta:=pow(sin((lat-float(profile.root_latitude))*0.5),2)+cos(lat)*cos(float(profile.root_latitude))*pow(sin((lon-float(profile.root_longitude))*0.5),2)
		var distance:=2.0*radius*asin(sqrt(clampf(delta,0.0,1.0)))
		if distance>=outer:continue
		var influence:=1.0-smoothstep(float(profile.flat_inner_m),outer,distance)
		if influence>weight:weight=influence;plane=CityProfile.plane_height(profile,radius,lat,lon)
	return plane if weight>=1.0 else lerpf(height,plane,weight)

func elevation(lat:float,lon:float)->float:
	if not is_finite(lat) or not is_finite(lon) or absf(lat)>PI*0.5+1e-12:return NAN
	_mutex.lock()
	# An entirely graded city plane needs no source ray query at all.
	var result:=_grade_cities(NAN,lat,lon)
	if not is_finite(result):result=_grade_cities(_grid_height_unlocked(lat,lon),lat,lon) if configured_ok else NAN
	_mutex.unlock();return result

func prepare_patch(center_lat:float,center_lon:float,width_m:float,step_m:float=CELL_METRES)->Dictionary:
	# A worker-owned sampler can prepare this immutable cache transfer. Never
	# expose its live Dictionary or mutate another instance's source kernel.
	if not configured_ok or not is_finite(width_m) or width_m<0 or width_m>65536 or not is_finite(step_m) or step_m<16:return {}
	if radial_q31(center_lat,center_lon).is_empty():return {}
	var count:=ceili(width_m/step_m)
	if (count+1)*(count+1)>CACHE_LIMIT:return {}
	_mutex.lock()
	for y in range(count+1):
		for x in range(count+1):
			var north:=(float(y)-count*0.5)*step_m
			var east:=(float(x)-count*0.5)*step_m
			var lat:=clampf(center_lat+north/radius,-PI*0.5,PI*0.5)
			var lon:=center_lon+east/(radius*maxf(0.001,cos(lat)))
			if not is_finite(_grid_height_unlocked(lat,lon)):_mutex.unlock();return {}
	var result:={"revision":REVISION_NAME,"record_hex":source_record.hex_encode(),"cell_metres":CELL_METRES,"height_policy":SAMPLE_POLICY,"source_policy":source_policy.duplicate(true),"nodes":_cache.duplicate(true)}
	_mutex.unlock();return result

func install_patch(patch:Dictionary)->bool:
	# Validate the whole incoming cache before replacing anything.
	if not configured_ok or patch.get("revision")!=REVISION_NAME or patch.get("record_hex")!=source_record.hex_encode() or patch.get("height_policy")!=SAMPLE_POLICY or patch.get("cell_metres")!=CELL_METRES or patch.get("source_policy")!=source_policy:return false
	var nodes:Variant=patch.get("nodes")
	if not nodes is Dictionary or nodes.size()>CACHE_LIMIT:return false
	var prepared:Dictionary={};var order:Array[String]=[]
	for key:Variant in nodes:
		if not key is String or not (nodes[key] is float or nodes[key] is int) or not is_finite(float(nodes[key])) or absf(float(nodes[key]))>2.0*radius:return false
		var coordinates_key:=str(key).split(":")
		if coordinates_key.size()!=2 or not coordinates_key[0].is_valid_int() or not coordinates_key[1].is_valid_int():return false
		var x:=int(coordinates_key[0]);var y:=int(coordinates_key[1])
		if x<0 or x>=_lon_cells or y<0 or y>_lat_cells or key!=_node_key(x,y):return false
		prepared[key]=float(nodes[key]);order.append(key)
	_mutex.lock();_cache=prepared;_cache_order=order;_generation+=1;_mutex.unlock()
	return true
