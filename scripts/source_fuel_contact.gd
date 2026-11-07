extends RefCounted
# Read-only gas/star natural branch, with explicit phone SI/frame adapters.
# Source bounds only reject/dispatch; F581/F1876 determines the actual field.
# This does not replace full F569 object scanning, collision response or FOR.
const Point=preload("res://scripts/source_terrain_point.gd")
const Math=preload("res://scripts/ground_coordinates.gd")
const Query=preload("res://scripts/source_terrain_query.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Units=preload("res://scripts/source_units.gd")
const Physics=preload("res://scripts/source_physics_bridge.gd")
const Clock=preload("res://scripts/source_clock.gd")
const Rotation=preload("res://scripts/body_rotation.gd")
const StationGeometry=preload("res://scripts/source_station_geometry.gd")
const World=preload("res://scripts/planetary_system.gd")
const CONTRACT:="source-gas-star-f574-f581-readonly-contact-v1"
const POLICY:="source-natural-field-with-current-phone-frame-si-adapter-v1"
const DATA_PATH:="res://data/ffe_fuel.json"
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const MASK:=0xffffffff
static var _models:Dictionary={}
static var _mutex:=Mutex.new()
var _query:=Query.new()

static func _s32(value:int)->int:return Ground._s32(value)
static func _integer(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _sha(raw:PackedByteArray)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(raw);return h.finish().hex_encode()
static func model(index:int)->Dictionary:
	if index<134 or index>148:return {}
	_mutex.lock()
	if _models.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		if not parsed is Dictionary or parsed.get("source_sha256")!=SOURCE_SHA or not parsed.get("models") is Dictionary:_mutex.unlock();return {}
		_models=parsed.models.duplicate(true)
	var value:Variant=_models.get(str(index));var result:Dictionary=value.duplicate(true) if value is Dictionary else {};_mutex.unlock()
	if result.is_empty():return {}
	var descriptor:=str(result.get("descriptor_hex","")).hex_decode();var vertices:=str(result.get("vertices_hex","")).hex_decode();var payload:=str(result.get("collision_payload_hex","")).hex_decode()
	if descriptor.size()!=68 or _sha(descriptor)!=str(result.get("descriptor_sha256","")) or vertices.size()!=24 or _sha(vertices)!=str(result.get("vertices_sha256","")) or payload.size()!=8 or _sha(payload)!=str(result.get("collision_payload_sha256","")):return {}
	if descriptor.decode_u32(56)!=0 or int(result.get("mesh_zoom",-1))!=int(descriptor.decode_u32(20))+int(descriptor.decode_u32(24)):return {}
	if str(result.get("collision_prefix_hex",""))!="1083ff":return {}
	return result

static func metadata(index:int)->Dictionary:
	var data:=model(index)
	if data.is_empty():return {}
	var d:=str(data.descriptor_hex).hex_decode();var exponent:=int(d.decode_u32(20))+int(d.decode_u32(24))-8
	var outer:=Point.shift_int64(int(d.decode_s16(44)),exponent);var inner:=Point.shift_int64(int(d.decode_s16(48)),exponent)
	return {"model_index":index,"outer_bound_raw":outer,"inner_bound_raw":inner,"mesh_zoom":int(data.mesh_zoom),"descriptor_sha256":str(data.descriptor_sha256),"outer_bound_m":Units.metres(float(outer)),"inner_bound_m":Units.metres(float(inner)),"terrain_style_raw":str(data.collision_payload_hex).hex_decode().decode_u16(4)}

func _frame(data:Dictionary,observer:PackedInt64Array,vector_scale:int)->Dictionary:
	var vertices_data:=str(data.vertices_hex).hex_decode();var payload:=str(data.collision_payload_hex).hex_decode();var vertices:Array=[];var zoom:=int(data.mesh_zoom)-vector_scale
	for i in range(4):vertices.append(Point._source_vertex(vertices_data,int(payload[i]),zoom))
	var origin:PackedInt64Array=vertices[0];var center:=Query._subtract(origin,observer);var distance:=Point.source_length(center)
	if distance<0:return {}
	var matrix:=PackedInt64Array([0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff])
	if center[0]!=0:
		var xy:=Point.source_length(PackedInt64Array([center[0],center[1],0]));var first:=Point._normalized_component(center[0],xy);var second:=Point._normalized_component(center[1],xy)
		matrix=PackedInt64Array([second,first,0,_s32(-first),second,0,0,0,0x7fffffff]);center[1]=xy
	if center[1]!=0:
		var yz:=Point.source_length(PackedInt64Array([0,center[1],center[2]]));var first:=Point._normalized_component(center[1],yz);var second:=Point._normalized_component(center[2],yz)
		for row in range(2):matrix[row*3+2]=Math.multiply_q31(matrix[row*3+1],first);matrix[row*3+1]=Math.multiply_q31(matrix[row*3+1],second)
		matrix[7]=_s32(-first);matrix[8]=second
	var query_matrix:=PackedInt64Array()
	for i in range(1,4):query_matrix.append_array(Point._transform(Query._subtract(vertices[i],origin),matrix))
	return {"matrix":query_matrix,"center":PackedInt64Array([0,0,distance]),"distance":distance,"style":int(payload.decode_u16(4)),"features":payload.slice(6),"limit":2000000000>>(vector_scale&31)}

func query_raw(model_index:int,seed_u32:Variant,relative_raw:Variant,graphics_level_raw:int=1)->Dictionary:
	if not _integer(seed_u32,0,MASK) or not (relative_raw is Array or relative_raw is PackedInt64Array) or relative_raw.size()!=3 or graphics_level_raw<0 or graphics_level_raw>15:return {"ok":false,"reason":"invalid_raw_query"}
	var point:=PackedInt64Array();var sum:=0
	for value:Variant in relative_raw:
		if not _integer(value,-0x1000000000000000,0x1000000000000000):return {"ok":false,"reason":"invalid_raw_position"}
		point.append(int(value));sum+=absi(int(value))
	var data:=model(model_index);var meta:=metadata(model_index)
	if data.is_empty() or meta.is_empty():return {"ok":false,"reason":"missing_source_model"}
	# Model84 is the explicit source zero-inner-radius read-only probe.
	# Its own descriptor outer bound contributes only to the broad phase;
	# it is not substituted for the player's collision radius.
	var probe_meta:=Ground.model_resources(84)
	if probe_meta.is_empty():return {"ok":false,"reason":"missing_source_probe"}
	var probe_outer:=Point.shift_int64(int(probe_meta.outer_radius_raw),int(probe_meta.model_scale_raw))
	var contact:={"flags_u8":0,"altitude_raw_s32":-1,"parent_model_u32":model_index}
	var result:={"ok":true,"source_contract":CONTRACT,"contact":contact,"branch":"broad_phase_rejected","terrain_query_calls":0,"source_descriptor_sha256":meta.descriptor_sha256,"relative_raw":point.duplicate(),"full_f569":false,"collision_response_applied":false}
	if (sum>>1)-probe_outer-int(meta.outer_bound_raw)>=0:return result
	var shift:=maxi(0,Gravity._vec64_msb(point)-28);var vector:=PackedInt64Array()
	for value:int in point:vector.append(_s32(Point.shift_int64(value,-shift)&MASK))
	var minimum_shift:=int(data.mesh_zoom)-23
	if shift<minimum_shift:
		for i in range(3):vector[i]>>=(minimum_shift-shift)&31
		shift=minimum_shift
	var frame:=_frame(data,vector,shift)
	if frame.is_empty():return {"ok":false,"reason":"degenerate_source_frame"}
	var outer:=_s32(Point.shift_int64(int(meta.outer_bound_raw),-shift)&MASK);var inner:=_s32(Point.shift_int64(int(meta.inner_bound_raw),-shift)&MASK)
	result["vector_scale"]=shift;result["observer_model_local_raw"]=vector;result["query_frame"]=frame
	if _s32(int(frame.distance)-outer)>=0:result.branch="outside_outer_bound";contact.flags_u8=3
	elif _s32(int(frame.distance)-inner)<=0:result.branch="inside_inner_bound";contact.flags_u8=0x83
	else:
		var query:=_query.query_raw(int(seed_u32),int(frame.style),frame.matrix,frame.center,int(frame.limit),graphics_level_raw,frame.features)
		if query.is_empty():return {"ok":false,"reason":"source_query_failed"}
		var height:=int(query.query_result_raw);result.branch="terrain_query";result.terrain_query_calls=1;result["recorded_intersection_raw"]=query.recorded_intersection_raw;result["query_result_raw"]=height;contact.flags_u8=3
		if height<int(frame.limit):
			var raw_height:=Point.shift_int64(height,shift)
			contact.altitude_raw_s32=int(raw_height) if raw_height>=0 and raw_height<=0x7fffffff else -1
		if height<0:contact.flags_u8=0x83;contact.altitude_raw_s32=0
	return result

static func raw_speed(velocity:Vector3)->Dictionary:
	if not velocity.is_finite():return {"ok":false,"reason":"invalid_velocity"}
	var raw:=PackedInt64Array()
	for component in [velocity.x,velocity.y,velocity.z]:
		var value:=float(component)/Physics.VELOCITY_UNIT_MPS
		if not is_finite(value) or value<(-0x7fffffff) or value>0x7fffffff:return {"ok":false,"reason":"velocity_out_of_source_domain"}
		raw.append(int(value))
	var bits:=0
	for component:int in raw:bits|=absi(component)
	var shift:=0
	while bits>=0x4000:bits>>=1;shift+=1
	var scaled:=PackedInt64Array()
	for component:int in raw:scaled.append(component>>shift)
	var speed:=Point.source_length(scaled)
	for i in range(shift):
		if speed&0x40000000:speed=0x7fffffff;break
		speed=_s32(speed*2)
	return {"ok":true,"speed_s32":speed,"raw_velocity_s32":raw,"velocity_unit_mps":Physics.VELOCITY_UNIT_MPS,"policy":"phone_si_to_source_f1475_f1466_current_frame_v1","automatic_source_frame_selection":false}

static func _basis_readonly(world:RefCounted,body:Dictionary,days:float)->Dictionary:
	# World.body_rotation_basis advances its persistent spin. Sampling must
	# instead advance an isolated copy, including historical-time fallback.
	var clock:=Clock.from_elapsed_days(days)
	if clock.is_empty():return {}
	var record:=str(body.get("runtime_record_hex","")).hex_decode()
	if record.size()!=68:return {}
	var spin:Dictionary=world.body_spin_by_id.get(str(body.id),{}).duplicate(true)
	if spin.is_empty() or int(clock.day_u32)<int(spin.day_u32) or (int(clock.day_u32)==int(spin.day_u32) and int(clock.tick_u32)<int(spin.tick_u32)):
		spin={"rotation_raw":int(record[62]),"tilt_u16":int(record.decode_u16(66)),"matrix_q31":Array(Rotation.initialize(int(record[62]),int(record.decode_u16(66)),Clock.EPOCH_TICK_U32)),"tick_u32":Clock.EPOCH_TICK_U32,"day_u32":Clock.EPOCH_DAY_U32}
	var advanced:=Rotation.advance(PackedInt64Array(spin.matrix_q31),int(spin.rotation_raw),int(spin.tilt_u16),0,int(spin.tick_u32),int(clock.tick_u32),int(spin.day_u32),int(clock.day_u32))
	spin.matrix_q31=Array(advanced.matrix);spin.tick_u32=int(clock.tick_u32);spin.day_u32=int(clock.day_u32)
	return {"basis":StationGeometry.orientation_basis(spin)}

func sample(world:RefCounted,ship:RefCounted,days:float)->Dictionary:
	var empty_contact:={"flags_u8":0,"altitude_raw_s32":-1,"parent_model_u32":0}
	var result:={"ok":true,"contact":empty_contact,"speed_s32":0,"body_id":"","policy":POLICY,"reason":"outside_source_atmosphere","full_f569":false,"original_collision_response":false,"timer_policy":"caller_owned"}
	if world==null or ship==null or not is_finite(days) or Clock.from_elapsed_days(days).is_empty():result.ok=false;result.reason="invalid_live_context";return result
	var speed:=raw_speed(ship.velocity)
	if not speed.ok:result.ok=false;result.reason=speed.reason;return result
	result.speed_s32=int(speed.speed_s32);result["speed_policy"]=speed.policy
	if world.layout_mode!=World.FULL_LAYOUT:result.reason="legacy_world";return result
	if ship.surface_mode or ship.docked or ship.hull<=0:result.reason="not_airborne";return result
	if not ship.position.is_finite():result.ok=false;result.reason="invalid_ship_position";return result
	var nearest:=INF;var chosen:Dictionary={};var relative:=Vector3.ZERO
	for body:Dictionary in world.bodies:
		var index:=int(body.get("model_index",-1))
		if index<134 or index>148:continue
		var meta:=metadata(index)
		if meta.is_empty():continue
		var delta:Vector3=ship.position-world.local_meters(str(body.id),days)
		if not delta.is_finite():continue
		var distance:=delta.length()-float(meta.outer_bound_m)
		if distance<nearest:nearest=distance;chosen=body;relative=delta
	if chosen.is_empty():result.reason="no_source_gas_or_star";return result
	result.body_id=str(chosen.id);var body_meta:=metadata(int(chosen.model_index))
	# Before a terrain query, only the exact source broad phase is used.
	# Body orientation is sampled from the real current source world.
	var orientation:=_basis_readonly(world,chosen,days)
	if orientation.is_empty():result.ok=false;result.reason="invalid_source_body_orientation";return result
	var basis:Basis=orientation.basis;var bodyfixed:=basis.inverse()*relative
	var raw:=PackedInt64Array()
	for component in [bodyfixed.x,bodyfixed.y,bodyfixed.z]:
		var value:=Units.raw(float(component))
		if not is_finite(value) or absf(value)>float(0x1000000000000000):result.ok=false;result.reason="position_out_of_source_domain";return result
		raw.append(int(round(value)))
	var queried:=query_raw(int(chosen.model_index),int(chosen.get("source_uid_u32",chosen.get("source_seed",0))),raw)
	if not queried.ok:result.ok=false;result.reason=queried.reason;return result
	result.contact=queried.contact;result.reason="source_atmosphere" if int(queried.contact.flags_u8)&1!=0 else "outside_source_atmosphere";result["geometry"]=queried;result["world_frame_policy"]="current_world_body_rotation_and_local_phone_position_v1";result["descriptor_sha256"]=body_meta.descriptor_sha256
	return result
