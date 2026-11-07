extends RefCounted
# Read-only contact/context for F1014. Natural geometry is queried through the
# existing original-source F574/F581 kernels; current phone coordinate frames,
# SI conversion and caller selection remain explicit adapters.
const Natural=preload("res://scripts/source_ground_surface.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Gas=preload("res://scripts/source_fuel_contact.gd")
const Units=preload("res://scripts/source_units.gd")
const Physics=preload("res://scripts/source_physics_bridge.gd")
const Clock=preload("res://scripts/source_clock.gd")
const World=preload("res://scripts/planetary_system.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const CONTRACT:="source-natural-f1014-contact-current-phone-frame-v1"
const SOLID_CONTRACT:="source-f574-natural-solid-readonly-probe-v1"
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const ATMOSPHERE_ALTITUDE_LIMIT_RAW:=20000000
const UNKNOWN_ALTITUDE_S32:=0x7fffffff
const MASK:=0xffffffff
var _natural:=Natural.new()
var _gas:=Gas.new()

static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _point(value:Variant)->PackedInt64Array:
	if not (value is Array or value is PackedInt64Array) or value.size()!=3:return PackedInt64Array()
	var result:=PackedInt64Array()
	for component:Variant in value:
		if not _whole(component,-0x1000000000000,0x1000000000000):return PackedInt64Array()
		result.append(int(component))
	return result

static func metadata(model_index:int)->Dictionary:
	if model_index>=134 and model_index<=148:
		var result:=Gas.metadata(model_index);var gas_data:=Gas.model(model_index)
		if result.is_empty() or gas_data.is_empty():return {}
		var descriptor:=str(gas_data.descriptor_hex).hex_decode()
		result["body_flags_u8"]=((int(descriptor.decode_u32(36))>>4)&7)|0x80
		result["source_variant"]="pinned_jjffe_natural_queries_with_dos_model_resources"
		return result
	if model_index<117 or model_index>133:return {}
	var model:=Natural.model_resources(model_index)
	if model.is_empty():return {}
	var descriptor:=str(model.get("descriptor_hex","")).hex_decode();var prefix:=str(model.get("collision_prefix_hex","")).hex_decode()
	if descriptor.size()!=68 or prefix.size()!=3 or prefix[0]!=0x10 or prefix[1] not in [0x82,0x83] or prefix[2]!=255:return {}
	var outer:=Natural._shift64(int(descriptor.decode_s16(44)),int(model.model_scale_raw));var inner:=Natural._shift64(int(descriptor.decode_s16(48)),int(model.model_scale_raw))
	return {"model_index":model_index,"outer_bound_raw":outer,"inner_bound_raw":inner,"outer_bound_m":Units.metres(float(outer)),"inner_bound_m":Units.metres(float(inner)),"descriptor_sha256":str(model.descriptor_sha256),"body_flags_u8":((int(model.flags_raw)>>4)&7)|0x80,"native_stream_atmosphere_flag":int(prefix[1])&1,"source_variant":Natural.SOURCE_VARIANT,"bounds_are_terrain_surface":false}

func query_raw(model_index:int,seed_u32:Variant,relative_model_raw:Variant,graphics_level_raw:=1)->Dictionary:
	if not _whole(seed_u32,0,MASK) or graphics_level_raw<0 or graphics_level_raw>15:return {"ok":false,"reason":"invalid_raw_context"}
	if model_index>=134 and model_index<=148:return _gas.query_raw(model_index,seed_u32,relative_model_raw,graphics_level_raw)
	var point:=_point(relative_model_raw);var meta:=metadata(model_index)
	if point.size()!=3 or meta.is_empty():return {"ok":false,"reason":"unsupported_natural_model_or_position"}
	var parent:=PackedByteArray();parent.resize(Natural.OBJECT_BYTES);parent[0x86]=1;parent.encode_u32(0xa0,int(seed_u32))
	for axis in range(3):parent.encode_u32(axis*16,0x7fffffff)
	var probe:=PackedByteArray();probe.resize(Natural.OBJECT_BYTES);probe[0x56]=1;probe[0x57]=1;probe[0x86]=2
	var parent_init:=Natural.initialize_model(parent,model_index);var probe_init:=Natural.initialize_model(probe,84)
	if parent_init.is_empty() or probe_init.is_empty():return {"ok":false,"reason":"missing_source_model"}
	var sampled:=_natural.height_raw(probe_init.object,parent_init.object,point,graphics_level_raw)
	if sampled.is_empty():return {"ok":false,"reason":"source_natural_query_failed"}
	return {"ok":true,"source_contract":SOLID_CONTRACT,"contact":{"flags_u8":int(sampled.globals.collision_flags_u8),"altitude_raw_s32":int(sampled.height_s32),"parent_model_u32":model_index},"body_flags_u8":int(parent_init.object[0x14c]),"source_descriptor_sha256":meta.descriptor_sha256,"branch":str(sampled.trace.get("terrain_branch","none")),"broad_phase_rejected":bool(sampled.trace.get("broad_phase_rejected",false)),"terrain_query_calls":int(sampled.globals.terrain_query_calls),"relative_raw":point.duplicate(),"native_query_globals":sampled.globals.duplicate(true),"full_f569":false,"collision_response_applied_to_player":false,"probe":"source_model84_zero_inner_bound_readonly"}

static func _bodyfixed_surface_point(globe:RefCounted,position:Vector3)->PackedInt64Array:
	# Exact scalar expression used by SourceTerrain.coordinates_at_height,
	# retaining a small altitude while adding it to the large reference radius.
	if globe==null or not position.is_finite():return PackedInt64Array()
	var lat:=float(globe.latitude);var lon:=float(globe.longitude);var radius:=float(globe.radius)
	if not is_finite(lat) or not is_finite(lon) or not is_finite(radius) or radius<=0:return PackedInt64Array()
	var sl:=sin(lat);var cl:=cos(lat);var sn:=sin(lon);var cs:=cos(lon);var up:=radius+float(position.y)
	var values:=[-sn*float(position.x)+cl*cs*up+sl*cs*float(position.z),sl*up-cl*float(position.z),-cs*float(position.x)-cl*sn*up-sl*sn*float(position.z)]
	var raw:=PackedInt64Array()
	for value:float in values:
		var converted:=Units.raw(value)
		if not is_finite(converted) or absf(converted)>float(0x1000000000000):return PackedInt64Array()
		raw.append(roundi(converted))
	return raw

static func _bodyfixed_orbit_point(world:RefCounted,body:Dictionary,ship:RefCounted,days:float)->Dictionary:
	var orientation:=Gas._basis_readonly(world,body,days)
	if orientation.is_empty():return {}
	var centre:Vector3=world.local_meters(str(body.id),days)
	if not centre.is_finite():return {}
	var bodyfixed:Vector3=Basis(orientation.basis).inverse()*(ship.position-centre);var raw:=PackedInt64Array()
	for value in [bodyfixed.x,bodyfixed.y,bodyfixed.z]:
		var converted:=Units.raw(float(value))
		if not is_finite(converted) or absf(converted)>float(0x1000000000000):return {}
		raw.append(roundi(converted))
	return {"raw":raw,"basis_body_to_world":orientation.basis}

static func _base_result(ship:RefCounted,gear_down:bool)->Dictionary:
	var speed:=Gas.raw_speed(ship.velocity)
	if not speed.get("ok",false):return {"ok":false,"reason":str(speed.get("reason","invalid_velocity"))}
	return {"ok":true,"source_contract":CONTRACT,"policy":"native_natural_contact_with_explicit_current_phone_frame_v1","reason":"outside_natural_atmosphere","contact":{"flags_u8":0,"altitude_raw_s32":-1,"parent_model_u32":0},"altitude_s32":UNKNOWN_ALTITUDE_S32,"speed_s32":int(speed.speed_s32),"velocity_s32":Array(speed.raw_velocity_s32),"velocity_unit_mps":Physics.VELOCITY_UNIT_MPS,"velocity_basis":Basis.IDENTITY,"velocity_to_phone_basis":Basis.IDENTITY,"velocity_frame":"current_phone_world_local_frame","velocity_policy":"current_phone_si_to_source_words_no_automatic_f570_frame_selection","input_velocity_mps":ship.velocity,"body_id":"","body_flags_u8":0,"gear_down":gear_down,"gear_policy":"explicit_caller_input_default_retracted","apply_f1014":false,"within_altitude_gate":false,"full_original_caller_dispatch":false,"full_f569":false,"physical_device_tested":false}

static func speed_from_raw_velocity(raw_velocity:Variant)->Dictionary:
	if not (raw_velocity is Array or raw_velocity is PackedInt64Array) or raw_velocity.size()!=3:return {"ok":false,"reason":"invalid_raw_velocity"}
	var source:=PackedInt64Array();var bits:=0
	for value:Variant in raw_velocity:
		if not _whole(value,-2147483648,2147483647):return {"ok":false,"reason":"invalid_raw_velocity"}
		source.append(int(value));bits|=absi(int(value))
	var shift:=0
	while bits>=0x4000:bits>>=1;shift+=1
	var scaled:=PackedInt64Array()
	for value:int in source:scaled.append(value>>shift)
	var speed:=Point.source_length(scaled)
	for i in range(shift):
		if speed&0x40000000:speed=0x7fffffff;break
		speed=Natural._s32(speed*2)
	return {"ok":true,"speed_s32":speed,"source_shift":shift,"source_scaled_velocity_s32":Array(scaled),"source_procedures":"F1099 speed fragment/F1475/F1466/F1502","automatic_reference_frame_selection":false}

static func raw_speed_words(raw_velocity:Variant)->Dictionary:return speed_from_raw_velocity(raw_velocity)

func sample(world:RefCounted,ship:RefCounted,surface:RefCounted,days:float,gear_down:=false)->Dictionary:
	if world==null or ship==null or not is_finite(days) or Clock.from_elapsed_days(days).is_empty() or not ship.position.is_finite() or not is_finite(ship.hull):return {"ok":false,"reason":"invalid_live_context"}
	var result:=_base_result(ship,gear_down)
	if not result.get("ok",false):return result
	if world.layout_mode!=World.FULL_LAYOUT:result.reason="legacy_world";return result
	if ship.docked or ship.hull<=0:result.reason="docked_or_destroyed";return result
	var body:Dictionary={};var raw:=PackedInt64Array();var geometry:Dictionary={}
	if surface!=null and surface.active:
		if not surface.source_surface() or surface.globe==null or not surface.globe.configured_ok or not world.by_id.has(str(surface.body_id)):
			result.reason="legacy_or_unavailable_surface";return result
		body=world.by_id[str(surface.body_id)]
		if str(surface.body_id)!=str(world.focus_id) or int(body.get("model_index",-1))!=int(surface.globe.source_model_index) or str(body.get("runtime_record_hex","")).hex_decode()!=surface.globe.source_record:return {"ok":false,"reason":"surface_source_context_mismatch"}
		raw=_bodyfixed_surface_point(surface.globe,ship.position)
		if raw.size()!=3:return {"ok":false,"reason":"surface_position_out_of_source_domain"}
		var tangent_to_body:Basis=surface.globe.basis_at(surface.globe.latitude,surface.globe.longitude)
		var body_velocity:=Gas.raw_speed(tangent_to_body*ship.velocity)
		if not body_velocity.get("ok",false):return {"ok":false,"reason":"surface_velocity_out_of_source_domain"}
		result.velocity_s32=Array(body_velocity.raw_velocity_s32);result.speed_s32=int(body_velocity.speed_s32)
		result.velocity_frame="bodyfixed_from_current_source_surface_tangent";result.velocity_to_phone_basis=tangent_to_body.inverse();result.velocity_basis=result.velocity_to_phone_basis;result["bodyfixed_basis"]=tangent_to_body;result["caller_policy"]="phone_active_source_surface_natural_atmosphere_v1"
	else:
		if ship.surface_mode:result.reason="unavailable_surface_context";return result
		var nearest:=INF
		for candidate:Dictionary in world.bodies:
			var index:=int(candidate.get("model_index",-1));var meta:=metadata(index)
			if meta.is_empty():continue
			var centre:Vector3=world.local_meters(str(candidate.id),days)
			if not centre.is_finite():continue
			var distance:float=ship.position.distance_to(centre)-float(meta.outer_bound_m)
			if distance<nearest:nearest=distance;body=candidate
		if body.is_empty():result.reason="no_supported_natural_body";return result
		var point:=_bodyfixed_orbit_point(world,body,ship,days)
		if point.is_empty():return {"ok":false,"reason":"orbital_position_out_of_source_domain"}
		raw=point.raw;result["bodyfixed_basis"]=point.basis_body_to_world;result["caller_policy"]="phone_free_flight_natural_atmosphere_v1"
	var meta:=metadata(int(body.model_index))
	if meta.is_empty():return {"ok":false,"reason":"missing_source_body"}
	geometry=query_raw(int(body.model_index),int(body.get("source_uid_u32",body.get("source_seed",0))),raw)
	if not geometry.get("ok",false):return geometry
	result.body_id=str(body.id);result.body_flags_u8=int(meta.body_flags_u8);result.contact=geometry.contact.duplicate(true);result["geometry"]=geometry;result["descriptor_sha256"]=meta.descriptor_sha256
	# F1033 converts an unavailable signed raw altitude(-1) to INT_MAX before
	# F1014 reads game+0xdc. Feeding-1 directly would falsely enable heating.
	result.altitude_s32=UNKNOWN_ALTITUDE_S32 if int(result.contact.altitude_raw_s32)==-1 else int(result.contact.altitude_raw_s32)
	result.apply_f1014=(int(result.contact.flags_u8)&1)!=0;result.within_altitude_gate=result.apply_f1014 and int(result.altitude_s32)<=ATMOSPHERE_ALTITUDE_LIMIT_RAW
	result.reason="source_atmosphere" if result.apply_f1014 else "outside_natural_atmosphere"
	return result
