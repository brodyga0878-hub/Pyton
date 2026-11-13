extends RefCounted
# A new geometric caller around the unchanged signed F581/F1876 field. F879
# remains the unchanged reviewed JJFFE two-query seed (SAR3, DOS has SAR4),
# not a claim that its placement result is a
# zero of the finer contact field. No ship, response or phone pose is invented.
const Ground=preload("res://scripts/source_ground_surface.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Units=preload("res://scripts/source_units.gd")
const CONTRACT:="source-f581-certified-radial-contact-field-v1"
const HEIGHT_POLICY:="source_f581_signed_ray_boundary_v1"
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const GRAPHICS_LEVEL:=1
const MAX_FIELD_QUERIES:=32
const MAX_CORRECTIONS:=8
const MAX_EXPANSIONS:=8
const Q31:=2147483647
const MASK:=0xffffffff
const RESOURCE_SHA256:={"res://data/ffe_ground_collision.json":"2dbf44a94422907b1bb29b34df1d795cef819cecf267b1591f3d82ea6326d018","res://data/ffe_terrain_query.json":"8d764c2cd2a682ddfa8e0b8978b8f12616333ef361d0ed820dcb5b03b3f1977a"}
var _ground:=Ground.new()
var _point:=Point.new()
var _mutex:=Mutex.new()
var _resources_verified:=false

static func _hex(vector:PackedInt64Array)->String:
	var bytes:=PackedByteArray();bytes.resize(24)
	for axis in range(3):bytes.encode_s64(axis*8,vector[axis])
	return bytes.hex_encode()
static func _radius(point:PackedInt64Array)->float:
	return sqrt(float(point[0])*point[0]+float(point[1])*point[1]+float(point[2])*point[2])
static func ray_point(direction_q31:PackedInt64Array,ray_radius_raw:int)->PackedInt64Array:
	# Exact floor((signed Q31)*positive64/2^31), without a >64-bit product.
	# Geometry queries, rather than this seed/radius parameter, certify outputs.
	if direction_q31.size()!=3 or ray_radius_raw<1 or ray_radius_raw>0x1000000000000:return PackedInt64Array()
	var result:=PackedInt64Array();var integer:=ray_radius_raw>>31;var fraction:=ray_radius_raw&Q31
	for value:int in direction_q31:
		if value<(-2147483648) or value>Q31:return PackedInt64Array()
		result.append(value*integer+((value*fraction)>>31))
	return result
static func _direction_valid(direction:PackedInt64Array)->bool:
	if direction.size()!=3:return false
	var squared:=0.0
	for value:int in direction:
		if value<(-2147483648) or value>Q31:return false
		squared+=float(value)*value
	# Public direction is a unit Q31 ray, not an arbitrary scaled vector.
	return absf(squared/(float(Q31)*Q31)-1.0)<=0.000001
static func _failure(reason:String,trace:Array=[],seed:Dictionary={})->Dictionary:
	return {"ok":false,"certified":false,"error":reason,"status":"unsupported","position_raw":PackedInt64Array(),"bracket":{},"query_count":trace.size(),"query_trace":trace.duplicate(true),"seed":seed.duplicate(true),"source_contract":CONTRACT,"height_policy":HEIGHT_POLICY,"source_sha256":SOURCE_SHA}
static func _source_models(record:PackedByteArray)->Dictionary:
	if record.size()!=68:return {}
	var index:=int(record.decode_u16(12))
	if index<117 or index>133:return {}
	var model:=Ground.model_resources(index)
	if model.is_empty():return {}
	var raw_parent:=PackedByteArray();raw_parent.resize(338);raw_parent[0x86]=1;raw_parent.encode_u32(0xa0,record.decode_u32(4))
	for axis in range(3):raw_parent.encode_s32(axis*16,Q31)
	var raw_probe:=PackedByteArray();raw_probe.resize(338);raw_probe[0x56]=1;raw_probe[0x57]=1;raw_probe[0x86]=2
	var parent:=Ground.initialize_model(raw_parent,index);var probe:=Ground.initialize_model(raw_probe,84)
	if parent.is_empty() or probe.is_empty():return {}
	var vertices:=str(model.vertices_hex).hex_decode()
	if vertices.size()!=24:return {}
	var axes:=PackedInt64Array([absi(vertices.decode_s8(2)),absi(vertices.decode_s8(15)),absi(vertices.decode_s8(10))]);var zoom:=int(model.scale)+int(model.scale2)
	var reference_raw:=int(maxi(axes[0],maxi(axes[1],axes[2])))<<zoom
	if reference_raw<1 or reference_raw>0x800000000000:return {}
	return {"model_index":index,"uid_u32":int(record.decode_u32(4)),"model":model,"parent":parent.object,"probe":probe.object,"reference_raw":reference_raw,"axes":axes,"mesh_zoom":zoom}

func _sample_at(direction:PackedInt64Array,radius:int,data:Dictionary,cache:Dictionary,trace:Array)->Dictionary:
	var key:=str(radius)
	if cache.has(key):return cache[key]
	if trace.size()>=MAX_FIELD_QUERIES:return {}
	var point:=ray_point(direction,radius)
	if point.size()!=3:return {}
	# Recompute the actual F579 scale at EVERY point; freezing a convenient
	# scale changes the original integer field and cannot certify this boundary.
	var scale:=maxi(0,Gravity._vec64_msb(point)-28);var local:=PackedInt64Array()
	for value:int in point:local.append(Point._s32(Point.shift_int64(value,-scale)))
	var minimum:=int(data.mesh_zoom)-23
	if scale<minimum:
		for axis in range(3):local[axis]>>=(minimum-scale)&31
		scale=minimum
	var frame:=_point.frame_raw(int(data.model_index),local,scale)
	if frame.is_empty():return {}
	var query:=_point.kernel.query_raw(int(data.uid_u32),int(frame.query_style_raw),frame.query_matrix_raw,frame.query_center_raw,int(frame.query_limit_raw),GRAPHICS_LEVEL,frame.features)
	if query.is_empty() or int(query.query_result_raw)>=int(frame.query_limit_raw) or int(query.pending_query_flag)!=0:return {}
	var residual:=Point.shift_int64(int(query.query_result_raw),scale)
	var sample:={"ray_radius_raw":radius,"position_raw":point,"point_hex":_hex(point),"residual_raw_s64":residual,"query_result_s32":int(query.query_result_raw),"vector_scale_s32":scale,"query_matrix_raw":frame.query_matrix_raw,"query_center_raw":frame.query_center_raw,"query_style_raw":int(frame.query_style_raw),"query_limit_raw":int(frame.query_limit_raw),"recorded_intersection_raw":int(query.recorded_intersection_raw),"pending_query_flag":int(query.pending_query_flag),"vertex_pool_count":int(query.vertex_pool_count_after_return),"depth_control_raw":int(query.depth_control_raw)}
	cache[key]=sample;trace.append(sample)
	return sample

static func _bracket(samples:Dictionary)->Dictionary:
	# An outward crossing has a negative inner and positive outer signed query.
	# Only sampled signs establish the bracket; a height epsilon never does.
	var ordered:Array=samples.values();ordered.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.ray_radius_raw)<int(b.ray_radius_raw))
	var inside:Dictionary={};var result:Dictionary={}
	for value:Dictionary in ordered:
		if int(value.residual_raw_s64)<0:inside=value
		elif int(value.residual_raw_s64)>0 and not inside.is_empty():
			var width:=int(value.ray_radius_raw)-int(inside.ray_radius_raw)
			if result.is_empty() or width<int(result.width_raw):result={"inside":inside,"outside":value,"width_raw":width}
	return result

static func _original_bounds(data:Dictionary,sample:Dictionary)->Dictionary:
	var scale:=int(sample.vector_scale_s32);var parent:PackedByteArray=data.parent
	var outer:=Point._s32(Point.shift_int64(parent.decode_s64(0x138),-scale));var inner:=Point._s32(Point.shift_int64(parent.decode_s64(0x140),-scale));var distance:=int(sample.query_center_raw[2])
	var branch:="terrain_query"
	if Point._s32(distance-outer)>=0:branch="outside_outer"
	elif Point._s32(distance-inner)<=0:branch="inside_inner"
	return {"branch":branch,"terrain_query_eligible":branch=="terrain_query","threshold_raw_s32":0,"vector_scale_s32":scale,"distance_s32":distance,"outer_s32":outer,"inner_s32":inner,"outer_bound_raw_s64":parent.decode_s64(0x138),"inner_bound_raw_s64":parent.decode_s64(0x140),"policy":"unchanged original descriptor gates; geometry-only root never overrides F581 bounds or positive-player classification"}

static func _success(data:Dictionary,direction:PackedInt64Array,sample:Dictionary,status:String,bracket:Dictionary,trace:Array,seed:Dictionary)->Dictionary:
	return {"ok":true,"certified":true,"error":"","status":status,"position_raw":sample.position_raw.duplicate(),"ray_radius_raw":int(sample.ray_radius_raw),"residual_raw_s64":int(sample.residual_raw_s64),"residual_m":Units.metres(float(sample.residual_raw_s64)),"actual_radius_raw":_radius(sample.position_raw),"direction_q31":direction.duplicate(),"bracket":bracket.duplicate(true),"query_count":trace.size(),"query_trace":trace.duplicate(true),"seed":seed.duplicate(true),"source_bounds":_original_bounds(data,sample),"source_policy":{"height_policy":HEIGHT_POLICY,"model_index":int(data.model_index),"uid_u32":int(data.uid_u32),"graphics_level_raw":GRAPHICS_LEVEL,"seed_policy":"unchanged reviewed JJFFE F879 two-query radial placement, SAR3; original DOS F879 has SAR4","seed_source_variant":Ground.SOURCE_VARIANT,"geometry_policy":"actual four source vertices and signed original DOS F581/F1876; model117 anisotropy retained","root_selection":"first exact zero or tight outward sign boundary reached from F879 seed; global uniqueness is not asserted","max_field_queries":MAX_FIELD_QUERIES,"metres_per_raw":Units.METRES_PER_RAW},"height_policy":HEIGHT_POLICY,"source_contract":CONTRACT,"source_sha256":SOURCE_SHA}

func _sample_radial(record:PackedByteArray,direction:PackedInt64Array,graphics:int)->Dictionary:
	if graphics!=GRAPHICS_LEVEL or not _direction_valid(direction):return _failure("invalid_or_unsupported_direction_or_graphics")
	if not _resources_verified:
		for path:String in RESOURCE_SHA256:
			if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=RESOURCE_SHA256[path]:return _failure("source_resource_hash_mismatch")
		_resources_verified=true
	var data:=_source_models(record)
	if data.is_empty():return _failure("unsupported_source_record")
	var original_seed:=_ground.sample_radial_raw(data.probe,data.parent,direction,GRAPHICS_LEVEL)
	if original_seed.is_empty():return _failure("original_f879_seed_unavailable")
	var seed:={"position_raw":original_seed.position_raw.duplicate(),"point_hex":_hex(original_seed.position_raw),"first_height_raw":int(original_seed.first_height_raw),"second_height_raw":int(original_seed.second_height_raw),"height_calls":int(original_seed.height_calls),"terrain_query_calls":int(original_seed.terrain_query_calls),"policy":"unchanged reviewed JJFFE two-query Ground.sample_radial_raw; F879 SAR3 rather than DOS SAR4","source_variant":Ground.SOURCE_VARIANT}
	var radius:=roundi(_radius(original_seed.position_raw));var maximum:=int(data.reference_raw)*2
	if radius<1 or radius>maximum:return _failure("original_seed_outside_supported_ray_envelope",[],seed)
	var cache:Dictionary={};var trace:Array=[];var best:Dictionary={}
	for iteration in range(MAX_CORRECTIONS):
		var sample:=_sample_at(direction,radius,data,cache,trace)
		if sample.is_empty():return _failure("undefined_signed_source_query_or_budget",trace,seed)
		var height:=int(sample.residual_raw_s64)
		if height==0:return _success(data,direction,sample,"exact_zero",{},trace,seed)
		if best.is_empty() or absi(height)<absi(int(best.residual_raw_s64)):best=sample
		var next:=radius-height
		if next<1 or next>maximum or cache.has(str(next)):break
		radius=next
	var bracket:=_bracket(cache)
	if bracket.is_empty():
		# A signed correction can stay on one side or cycle at source integer
		# steps. Expand a bounded interval around its best observed point.
		var center:=int(best.ray_radius_raw);var step:=maxi(1,absi(int(best.residual_raw_s64)))
		for expansion in range(MAX_EXPANSIONS):
			for candidate:int in [maxi(1,center-step),mini(maximum,center+step)]:
				var sample:=_sample_at(direction,candidate,data,cache,trace)
				if sample.is_empty():return _failure("undefined_bracket_query_or_budget",trace,seed)
				if int(sample.residual_raw_s64)==0:return _success(data,direction,sample,"exact_zero",{},trace,seed)
			bracket=_bracket(cache)
			if not bracket.is_empty():break
			step*=2
	if bracket.is_empty():return _failure("no_outward_signed_bracket",trace,seed)
	while int(bracket.width_raw)>1:
		@warning_ignore("integer_division")
		var midpoint:int=int(bracket.inside.ray_radius_raw)+(int(bracket.width_raw)/2)
		var sample:=_sample_at(direction,midpoint,data,cache,trace)
		if sample.is_empty():return _failure("source_boundary_budget_exhausted_or_undefined",trace,seed)
		if int(sample.residual_raw_s64)==0:return _success(data,direction,sample,"exact_zero",bracket,trace,seed)
		bracket=_bracket(cache)
		if bracket.is_empty():return _failure("sampled_outward_boundary_lost",trace,seed)
	return _success(data,direction,bracket.outside,"adjacent_sign_boundary",bracket,trace,seed)

func sample_radial(record:PackedByteArray,direction_q31:PackedInt64Array,graphics_level_raw:int=1)->Dictionary:
	_mutex.lock();var result:=_sample_radial(record,direction_q31,graphics_level_raw);_mutex.unlock();return result
