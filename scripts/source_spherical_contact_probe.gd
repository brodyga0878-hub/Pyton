extends RefCounted
# Read-only F577 sphere ENVELOPE diagnostic, not original F575 dispatch.
# Natural/city terrain still uses the unchanged0.19 provider/kind1 bridge.
# All raw objects below are isolated operands, never a live source object bank.
const Sphere=preload("res://scripts/source_spherical_contact.gd")
const Bridge=preload("res://scripts/source_surface_contact_bridge.gd")
const Frame=preload("res://scripts/source_surface_render_state.gd")
const FuelContact=preload("res://scripts/source_fuel_contact.gd")
const Clock=preload("res://scripts/source_clock.gd")
const World=preload("res://scripts/planetary_system.gd")
const Physics=preload("res://scripts/source_physics_bridge.gd")
const CONTRACT:="source-f577-readonly-phone-sphere-envelope-v1"
const DATA_PATH:="res://data/ffe_spherical_contact.json"
const DATA_SHA:="e0fe32fe24ec2a0bb036aca3ee2afd1cb890bee1a976ffe58ffbee68ce42a07f"
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
static var _routing:Dictionary={}
static var _routing_mutex:=Mutex.new()

static func _number(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func _whole(value:Variant,low:int,high:int)->bool:return _number(value) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _base()->Dictionary:
	return {"ok":false,"reason":"unavailable","source_contract":CONTRACT,"envelope_only":true,"response_applied":false,"full_F569":false,"source_object_bank_present":false,"original_sphere_dispatch_eligible":false,"eligibility_policy":"initial-f1533-prefix-only-no-live-object-bank-v1","origin_policy":"phone-authored-centre-no-ground-offset-v1","terrain_provider_queried":false,"original_F575_dispatch_executed":false}
static func _failure(reason:String)->Dictionary:
	var result:=_base();result.reason=reason;return result
static func _plain(value:Variant)->Variant:
	# Dictionary dot assignments may introduce StringName keys. Keep the public
	# diagnostic literally JSON primitives, including keys and write-name arrays.
	if value is Dictionary:
		var result:Dictionary={}
		for key:Variant in value:result[str(key)]=_plain(value[key])
		return result
	if value is Array:
		var result:Array=[]
		for item:Variant in value:result.append(_plain(item))
		return result
	return str(value) if value is StringName else value
static func _load_routing()->bool:
	_routing_mutex.lock()
	if not _routing.is_empty():_routing_mutex.unlock();return true
	if not FileAccess.file_exists(DATA_PATH) or FileAccess.get_sha256(DATA_PATH)!=DATA_SHA:_routing_mutex.unlock();return false
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not data is Dictionary or data.get("schema")!=1 or data.get("source_sha256")!=SOURCE_SHA or not data.get("model_collision_routing") is Dictionary or data.model_collision_routing.size()!=149:_routing_mutex.unlock();return false
	var rows:Dictionary={}
	for index in range(149):
		var row:Variant=data.model_collision_routing.get(str(index));var descriptor:=Bridge.model_descriptor(index)
		if not row is Dictionary or descriptor.size()!=68 or not _whole(row.get("model_index"),index,index) or row.get("descriptor_sha256")!=Frame._sha(descriptor) or not _whole(row.get("collision_pointer_u32"),0,0xffffffff) or int(row.collision_pointer_u32)!=int(descriptor.decode_u32(0x34)) or not row.get("collision_prefix_hex") is String or not _whole(row.get("collision_first_byte_u8"),0,255):_routing_mutex.unlock();return false
		var prefix:=str(row.collision_prefix_hex).hex_decode();var first:=0
		if int(row.collision_pointer_u32)!=0:
			if prefix.size()!=8 or Frame._sha(prefix)!=row.get("collision_prefix_sha256") or not _whole(row.get("collision_file_offset"),0,0x7fffffff):_routing_mutex.unlock();return false
			first=int(prefix[0])
		elif not prefix.is_empty() or row.get("collision_file_offset")!=null:_routing_mutex.unlock();return false
		var flags:=((int(descriptor.decode_u32(0x24))>>4)&7)|(128 if first!=0 else 0)
		if int(row.collision_first_byte_u8)!=first or not _whole(row.get("descriptor_derived_object_flags_14c_u8"),flags,flags):_routing_mutex.unlock();return false
		if index==0:
			# F1533 explicitly skips descriptor initialization for model0. Its
			# stored prefix remains observable but establishes no object flags.
			if row.get("model_zero_skips_F1533_descriptor_initialization")!=true or row.get("initial_object_flags_14c_u8")!=null or row.get("initial_sphere_path_eligible")!=null:_routing_mutex.unlock();return false
			rows[str(index)]=row.duplicate(true);continue
		if row.get("model_zero_skips_F1533_descriptor_initialization")!=false or not _whole(row.get("initial_object_flags_14c_u8"),0,255) or not row.get("initial_sphere_path_eligible") is bool:_routing_mutex.unlock();return false
		if int(row.collision_first_byte_u8)!=first or int(row.initial_object_flags_14c_u8)!=flags or row.initial_sphere_path_eligible!=((flags&128)==0):_routing_mutex.unlock();return false
		rows[str(index)]=row.duplicate(true)
	_routing=rows;_routing_mutex.unlock();return true
static func model_routing(model_index:int)->Dictionary:
	if model_index<0 or model_index>=149 or not _load_routing():return {}
	return _routing[str(model_index)].duplicate(true)
static func _hex64(value:int)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_s64(0,value);return bytes.hex_encode()
static func _vector_hex(value:PackedInt64Array)->String:
	var bytes:=PackedByteArray();bytes.resize(24)
	for axis in range(3):bytes.encode_s64(axis*8,value[axis])
	return bytes.hex_encode()
static func _raw_point(values:PackedFloat64Array)->PackedInt64Array:
	if values.size()!=3:return PackedInt64Array()
	var result:=PackedInt64Array()
	for value:float in values:
		var converted:=Physics.raw_metres(value)
		if converted.is_empty() or absi(int(converted.raw))>0x10000000000000:return PackedInt64Array()
		result.append(int(converted.raw))
	return result
static func _scratch_world(world:RefCounted)->RefCounted:
	# Reuse current source records/caches, never regenerate a system or call a
	# cache-writing position method on the live World. Cache misses advance an
	# isolated ordinary ephemeris context only.
	var scratch:=World.new();scratch.layout_mode=world.layout_mode;scratch.requested_layout=world.requested_layout
	scratch.bodies=world.bodies.duplicate(true);scratch.settlements=world.settlements.duplicate(true);scratch.by_id=world.by_id.duplicate(true)
	scratch.focus_id=world.focus_id;scratch.site_id=world.site_id
	scratch._native_cache_tick=world.get("_native_cache_tick");scratch._native_cache_day=world.get("_native_cache_day")
	scratch._native_positions_raw=world.get("_native_positions_raw").duplicate(true);scratch._native_relative_raw=world.get("_native_relative_raw").duplicate(true)
	return scratch
static func _space_point(world:RefCounted,body:Dictionary,ship:RefCounted,days:float)->Dictionary:
	var rotation:=FuelContact._basis_readonly(world,body,days)
	if rotation.is_empty():return {"ok":false,"reason":"invalid_readonly_source_rotation"}
	var inverse:=Frame._inverse_rows(rotation.basis)
	if inverse.size()!=9:return {"ok":false,"reason":"invalid_source_rotation_basis"}
	var scratch:=_scratch_world(world);var origin:PackedInt64Array=scratch._full_origin_raw(days)
	if origin.size()!=3 or not scratch._native_positions_raw.has(str(body.id)):return {"ok":false,"reason":"readonly_source_ephemeris_unavailable"}
	var parent:PackedInt64Array=scratch._native_positions_raw[str(body.id)];var relative:=PackedFloat64Array()
	for axis in range(3):relative.append(float(ship.position[axis])-float(parent[axis]-origin[axis])*Bridge.Units.METRES_PER_RAW)
	var values:=PackedFloat64Array()
	for axis in range(3):values.append(inverse[axis*3]*relative[0]+inverse[axis*3+1]*relative[1]+inverse[axis*3+2]*relative[2])
	var raw:=_raw_point(values)
	return {"ok":true,"raw":raw,"frame_policy":"readonly-source-ephemeris-current-phone-local-origin-bodyfixed-scalar64-v1"} if raw.size()==3 else {"ok":false,"reason":"space_position_out_of_probe_domain"}

static func sample(world:RefCounted,ship:RefCounted,surface:RefCounted,days:float)->Dictionary:
	if world==null or ship==null or not is_finite(days) or Clock.from_elapsed_days(days).is_empty():return _failure("invalid_query_context")
	if world.get("layout_mode")!=World.FULL_LAYOUT:return _failure("outside_source_world")
	if not ship.get("position") is Vector3 or not ship.position.is_finite() or not ship.get("ship_id") is String:return _failure("invalid_authored_ship_centre")
	var data:=Bridge.source_ship_data(ship.ship_id)
	if not data.get("ok",false):return _failure("unsupported_source_ship")
	var body:Dictionary={};var raw:=PackedInt64Array();var frame_policy:=""
	if surface!=null and surface.get("active")==true:
		if not surface.has_method("source_surface") or not surface.source_surface() or surface.get("globe")==null:return _failure("outside_source_surface_frame")
		var globe:RefCounted=surface.globe;var id:=str(surface.get("body_id"))
		if not world.by_id.has(id) or str(world.focus_id)!=id or globe.get("configured_ok")!=true or not globe.get("source_record") is PackedByteArray or globe.source_record.size()!=68:return _failure("surface_source_context_mismatch")
		body=world.by_id[id]
		if str(body.get("runtime_record_hex","")).hex_decode()!=globe.source_record or int(body.get("model_index",-1))!=int(globe.get("source_model_index")):return _failure("surface_original_record_mismatch")
		if not _number(globe.get("latitude")) or not _number(globe.get("longitude")) or not _number(globe.get("radius")) or not globe.has_method("basis_at"):return _failure("invalid_surface_tangent_frame")
		var values:=Bridge.to_bodyfixed_point(globe.basis_at(globe.latitude,globe.longitude),float(globe.radius),ship.position);raw=_raw_point(values)
		if raw.size()!=3:return _failure("surface_position_out_of_probe_domain")
		frame_policy="current-source-surface-tangent-authored-centre-scalar64-v1"
	else:
		if ship.get("surface_mode")==true:return _failure("missing_active_surface_frame")
		if not world.by_id.has(str(world.focus_id)):return _failure("missing_source_focus_body")
		body=world.by_id[str(world.focus_id)]
		var mapped:=_space_point(world,body,ship,days)
		if not mapped.get("ok",false):return _failure(str(mapped.reason))
		raw=mapped.raw;frame_policy=mapped.frame_policy
	var model:Variant=body.get("model_index")
	if not _whole(model,1,148):return _failure("unsupported_source_parent_model")
	var record:=str(body.get("runtime_record_hex","")).hex_decode()
	if record.size()!=68 or int(record.decode_u16(12))!=int(model):return _failure("parent_original_record_model_mismatch")
	var routing:=model_routing(int(model));var descriptor:=Bridge.model_descriptor(int(model));var radii:=Bridge.descriptor_radii(descriptor)
	if routing.is_empty() or not radii.get("ok",false):return _failure("missing_original_sphere_routing_metadata")
	var player:=PackedByteArray();player.resize(Sphere.OBJECT_BYTES);player.fill(0);var parent:=player.duplicate()
	player.encode_u32(0x82,int(data.model_index));parent.encode_u32(0x82,int(model))
	player.encode_s64(0x138,int(data.outer_radius_raw));player.encode_s64(0x140,int(data.inner_radius_raw));parent.encode_s64(0x138,int(radii.outer_raw));parent.encode_s64(0x140,int(radii.inner_raw))
	parent[0x14c]=int(routing.initial_object_flags_14c_u8)
	var absolute:=PackedInt64Array()
	for value:int in raw:absolute.append(absi(value))
	var context:={"relative_position_s64":raw,"absolute_position_s64":absolute,"globals":{"collision_flags_u8":0,"altitude_s64":0}}
	var classified:Dictionary=Sphere.classify(player,parent,context)
	if not classified.get("ok",false):return _failure(str(classified.get("error","raw_sphere_query_rejected")))
	var result:=_base();result.ok=true;result.reason="sphere_envelope_query_only";result.original_sphere_dispatch_eligible=bool(routing.initial_sphere_path_eligible)
	result.body_id=str(body.id);result.body_model_index=int(data.model_index);result.parent_model_index=int(model);result.frame_policy=frame_policy
	result.relative_position_s64_hex=_vector_hex(raw);result.absolute_position_s64_hex=_vector_hex(absolute);result.relative_position_s64_preview=Array(raw)
	result.body_outer_radius_s64_hex=_hex64(int(data.outer_radius_raw));result.body_inner_radius_s64_hex=_hex64(int(data.inner_radius_raw));result.parent_outer_radius_s64_hex=_hex64(int(radii.outer_raw));result.parent_inner_radius_s64_hex=_hex64(int(radii.inner_raw))
	result.return_s32=int(classified.return_s32);result.inside_sphere=bool(classified.inside_sphere);result.sphere_branch="inside_candidate_return_zero" if int(classified.return_s32)==0 else "outside_or_tangent_early_return_minus_one"
	for key in ["shift_s32","distance_squared_s32","radius_s32","radius_squared_s32"]:result[key]=int(classified[key])
	result.collision_flags_u8=int(classified.globals_after.collision_flags_u8);result.altitude_s64_hex=_hex64(int(classified.globals_after.altitude_s64));result.altitude_s64_preview=int(classified.globals_after.altitude_s64)
	result.altitude_semantics="source-reconstructed-centre-distance-not-AGL";result.altitude_written=classified.global_writes.has("altitude_s64");result.initial_altitude_policy="isolated-zero-no-object-bank-history"
	result.global_write_keys=Array(classified.global_writes.keys());result.scaled_position_s64_hex=_vector_hex(classified.scaled_position_s64)
	result.initial_parent_object_flags_14c_u8=int(routing.initial_object_flags_14c_u8);result.collision_prefix_hex=str(routing.collision_prefix_hex);result.source_descriptor_sha256=str(routing.descriptor_sha256)
	result.raw_kernel_contract=Sphere.CONTRACT;result.source_sha256=SOURCE_SHA;result.flags2_means_landing_hit=false;result.terrain_collision_kind_changed=false
	return _plain(result)
