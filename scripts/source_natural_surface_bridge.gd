extends RefCounted
# Pure candidate preparation only. The caller owns physical/visible geometry,
# source-global history, HP/RNG and the atomic application of a returned pose.
# A local point certificate is deliberately not a whole-triangle certificate.
const Natural=preload("res://scripts/source_natural_contact.gd")
const Pipeline=preload("res://scripts/source_natural_contact_pipeline.gd")
const Phone=preload("res://scripts/source_surface_contact_bridge.gd")
const ContactTerrain=preload("res://scripts/source_contact_surface_terrain.gd")
const Field=preload("res://scripts/source_terrain_contact_field.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Frame=preload("res://scripts/source_surface_render_state.gd")
const CONTRACT:="source-f576-f575-v5-surface-candidate-bridge-v1"
const GUARD_CONTRACT:="source-v5-visible-local-point-exact-f581-guard-v1"
const CALLER_POLICY:="isolated-f569-enabled-f570-primary-parent-prefix-v1"
const MASK:=0xffffffff

static func _plain(value:Variant,depth:int=0)->bool:
	if depth>12:return false
	if value is Dictionary:
		for key:Variant in value:
			if not key is String or not _plain(value[key],depth+1):return false
		return true
	if value is Array:
		for item:Variant in value:
			if not _plain(item,depth+1):return false
		return true
	return value==null or value is String or value is bool or value is int or (value is float and is_finite(value))
static func _hex64(value:int)->String:
	var raw:=PackedByteArray();raw.resize(8);raw.encode_s64(0,value);return raw.hex_encode()
static func _vector_hex(value:PackedInt64Array)->String:
	var raw:=PackedByteArray();raw.resize(24)
	for axis in range(3):raw.encode_s64(axis*8,value[axis])
	return raw.hex_encode()
static func _floats_hex(value:PackedFloat64Array)->String:
	var raw:=PackedByteArray();raw.resize(value.size()*8)
	for index in range(value.size()):raw.encode_double(index*8,value[index])
	return raw.hex_encode()
static func _transport_guard(value:Dictionary)->Dictionary:
	# JSON transports all numeric values as float. Normalize public previews
	# once; authoritative source points and frame doubles remain exact hex.
	return JSON.parse_string(JSON.stringify(value))
static func _history_valid(history:Dictionary)->bool:
	if not _plain(history):return false
	for key:String in Natural.GLOBAL_KEYS:
		if not history.has(key):return false
	return not Natural._globals(history).is_empty()
static func caller_globals(history:Dictionary)->Dictionary:
	# F569 selects enabled FF. Only F570's primary-parent prefix is adapted;
	# its scanner, frame switching and source object bank are not executed.
	if not _history_valid(history):return {}
	var result:=Natural._globals(history)
	for key:String in ["collision_flags_u8","volume_flags_u8","collider_index_u8","primitive_flags_u8","collision_kind_u8"]:result[key]=0
	result.altitude_low_u32=MASK;result.collision_enabled_u8=255
	result.collider_parent_selected=true
	return result
static func _failure(surface:RefCounted,ship:RefCounted,context:Dictionary,reason:String)->Dictionary:
	var history:Variant=context.get("history_globals",{})
	return {"ok":false,"error":reason,"eligible":false,"response_applied":false,"contact_detected":false,"landing_accepted":false,"position":ship.get("position") if ship!=null else Vector3.ZERO,"velocity":ship.get("velocity") if ship!=null else Vector3.ZERO,"attitude":ship.get("attitude") if ship!=null else Quaternion.IDENTITY,"globals_after":history.duplicate(true) if history is Dictionary and _plain(history) else {},"damage_calls":[],"callbacks":[],"kernel":{},"geometry_guard":{},"facts":{"source_contract":CONTRACT,"caller_policy":CALLER_POLICY,"full_F569":false,"full_F570":false,"source_object_bank_present":false,"damage_applied":false,"clock_advanced":false}}
static func _blocked(surface:RefCounted,ship:RefCounted,context:Dictionary,reason:String,measured:Dictionary,classified:Dictionary)->Dictionary:
	# Retain measured diagnostic evidence without publishing candidate raw
	# globals, pose correction or F953 commands from a rejected transaction.
	var result:=_failure(surface,ship,context,reason)
	result.geometry_guard=measured.duplicate(true)
	result.facts["native_contact_observed"]=int(classified.f576_return_s32)==0
	result.facts["native_collision_kind"]=int(classified.globals_after.collision_kind_u8)
	result.facts["f576_return_s32"]=int(classified.f576_return_s32)
	result.facts["selected_child_index"]=int(classified.iterations[-1].child_index)
	result.facts["blocked_reason"]=reason
	return result
static func _position(value:Variant)->Dictionary:
	if value is Vector3 and value.is_finite():return {"ok":true,"value":value}
	if value is Array and value.size()==3:
		for item:Variant in value:
			if not Phone._number(item):return {"ok":false}
		var result:=Vector3(value[0],value[1],value[2])
		if result.is_finite():return {"ok":true,"value":result}
	return {"ok":false}
static func _outside_grading(globe:RefCounted,point:PackedFloat64Array,margin:float)->bool:
	var profiles:Variant=globe.get("city_profiles")
	if not profiles is Dictionary:return false
	var lat:=atan2(point[1],sqrt(point[0]*point[0]+point[2]*point[2]));var lon:=atan2(-point[2],point[0])
	for profile:Variant in profiles.values():
		if not profile is Dictionary:return false
		for key:String in ["flat_outer_m","root_latitude","root_longitude"]:
			if not Phone._number(profile.get(key)):return false
		var delta:=pow(sin((lat-float(profile.root_latitude))*0.5),2)+cos(lat)*cos(float(profile.root_latitude))*pow(sin((lon-float(profile.root_longitude))*0.5),2)
		if 2.0*float(globe.radius)*asin(sqrt(clampf(delta,0,1)))<=float(profile.flat_outer_m)+margin:return false
	return true
static func _prepare_frame(surface:RefCounted,ship:RefCounted,event:Dictionary)->Dictionary:
	if surface==null or ship==null or surface.get("active")!=true or not ship.has_method("profile"):return {"ok":false,"error":"outside_active_surface"}
	var globe:Variant=surface.get("globe")
	if not globe is ContactTerrain or globe.get("revision")!=ContactTerrain.CONTACT_REVISION or globe.get("configured_ok")!=true:return {"ok":false,"error":"unsupported_terrain_revision"}
	if not surface.get("city_data") is Dictionary or not surface.city_data.is_empty() or surface.get("underground")!=null:return {"ok":false,"error":"city_or_underground_not_supported"}
	for key:Variant in event:
		if key not in ["kind","candidate_position"]:return {"ok":false,"error":"unsupported_surface_event_field"}
	if event.get("kind","terrain") not in ["terrain","manual"]:return {"ok":false,"error":"unsupported_surface_event_kind"}
	var candidate:=_position(event.get("candidate_position",ship.get("position")))
	if not candidate.ok or not ship.get("position") is Vector3 or not ship.position.is_finite() or not ship.get("velocity") is Vector3 or not ship.velocity.is_finite() or not ship.get("attitude") is Quaternion or not ship.attitude.is_finite() or ship.attitude.length_squared()<0.0001:return {"ok":false,"error":"invalid_phone_pose"}
	var record:Variant=globe.get("source_record")
	if not record is PackedByteArray or record.size()!=68:return {"ok":false,"error":"invalid_original_parent_record"}
	var model:=int(record.decode_u16(12))
	if model<118 or model>133 or int(globe.get("source_model_index"))!=model:return {"ok":false,"error":"unsupported_natural_surface_model"}
	if globe.get("source_policy")!=ContactTerrain.geometry_metadata(record):return {"ok":false,"error":"invalid_v5_geometry_policy"}
	if not ship.get("ship_id") is String:return {"ok":false,"error":"invalid_source_ship_id"}
	var data:=Phone.source_ship_data(ship.ship_id);var natural_ship:=Natural.ship_model(int(data.get("model_index",-1)))
	if not data.get("ok",false) or natural_ship.is_empty():return {"ok":false,"error":"unverified_original_ship"}
	if not Phone._number(globe.get("latitude")) or not Phone._number(globe.get("longitude")) or not Phone._number(globe.get("radius")) or float(globe.radius)<=0:return {"ok":false,"error":"invalid_surface_geographic_frame"}
	var basis:Basis=globe.basis_at(globe.latitude,globe.longitude)
	var body_point:=Phone.to_bodyfixed_point(basis,globe.radius,candidate.value);var body_velocity:=Phone.to_bodyfixed_vector(basis,ship.velocity)
	if body_point.size()!=3 or body_velocity.size()!=3:return {"ok":false,"error":"invalid_surface_frame_mapping"}
	if not _outside_grading(globe,body_point,int(data.outer_radius_raw)*Phone.Units.METRES_PER_RAW):return {"ok":false,"error":"inside_or_invalid_city_grading"}
	var profile:Variant=ship.profile()
	if not profile is Dictionary or not Phone._number(profile.get("visual_span_m")) or float(profile.visual_span_m)<=0:return {"ok":false,"error":"invalid_authored_ship_profile"}
	var clearance:float=float(profile.visual_span_m)*0.14+2.0
	if not surface.has_method("clearance") or not Phone._number(surface.clearance(ship)) or float(surface.clearance(ship))!=clearance:return {"ok":false,"error":"unsupported_phone_clearance_policy"}
	return {"ok":true,"globe":globe,"record":record.duplicate(),"model":model,"ship_data":data,"natural_ship":natural_ship,"basis":basis,"input_position":candidate.value,"input_velocity":ship.velocity,"input_attitude":ship.attitude,"body_point":body_point,"body_velocity":body_velocity,"phone_clearance_m":clearance}
static func _clone_provider(provider:RefCounted)->RefCounted:
	if provider.get_script()!=Frame:return null
	var copy:=Frame.new()
	for name:String in ["configured_ok","source_key","core_width","core_cells","core_offset","_frame","_vertices","_grid_x","_grid_z","_minimum","_maximum","_record","_target_lat","_target_lon","_transform","_inverse","_queries","_last_cells","_last_triangles","_maximum_cells"]:
		var value:Variant=provider.get(name)
		if value is Dictionary or value is Array:value=value.duplicate(true)
		elif value is PackedVector3Array or value is PackedFloat64Array or value is PackedByteArray:value=value.duplicate()
		copy.set(name,value)
	return copy
static func _raw_point(point:PackedFloat64Array)->PackedInt64Array:
	var result:=PackedInt64Array()
	for value:float in point:
		var raw:=Phone.Physics.raw_metres(value)
		if raw.is_empty() or absi(int(raw.raw))>0x10000000000000:return PackedInt64Array()
		result.append(int(raw.raw))
	return result
static func _geometry(frame:Dictionary,surface:RefCounted)->Dictionary:
	var result:={"contract":GUARD_CONTRACT,"certified":false,"reason":"missing_published_v5_core","scope":"local-visible-point-only-not-whole-triangle","terrain_revision":ContactTerrain.CONTACT_REVISION,"record_sha256":Frame._sha(frame.record),"latitude":float(frame.globe.latitude),"longitude":float(frame.globe.longitude),"radius_m":float(frame.globe.radius),"local_x":float(frame.input_position.x),"local_z":float(frame.input_position.z),"frame_f64_hex":_floats_hex(PackedFloat64Array([float(frame.globe.latitude),float(frame.globe.longitude),float(frame.globe.radius),float(frame.input_position.x),float(frame.input_position.z)])),"graphics_level":1}
	var provider:Variant=surface.get("source_render_state")
	if not provider is RefCounted:return result
	var scratch:=_clone_provider(provider)
	if scratch==null:return result
	var hit:Dictionary=scratch.height_at(frame.globe,float(frame.input_position.x),float(frame.input_position.z))
	if hit.is_empty():return result
	result["provider_sha256"]=Frame._sha(var_to_bytes([provider.source_key,provider.core_width,provider.core_cells,provider.core_offset,provider.get("_frame"),provider.get("_vertices"),provider.get("_grid_x"),provider.get("_grid_z")]))
	result["visible_height_m"]=float(hit.height);result["visible_height_f64_hex"]=_floats_hex(PackedFloat64Array([float(hit.height)]));result["provider_triangle_index"]=int(hit.triangle_index)
	# Keep the interpolated visible-plane height in scalar64. Casting it to a
	# Vector3 first would add another Float32 height rounding at large relief.
	var point:=PackedFloat64Array();var up:=float(frame.globe.radius)+float(hit.height)
	for axis in range(3):point.append(float(frame.basis.x[axis])*float(frame.input_position.x)+float(frame.basis.y[axis])*up+float(frame.basis.z[axis])*float(frame.input_position.z))
	var raw:=_raw_point(point)
	if raw.size()!=3:result.reason="visible_point_out_of_raw_domain";return result
	result["visible_point_s64_hex"]=_vector_hex(raw)
	var model:=Natural.parent_model(int(frame.model));var scale:=maxi(0,Gravity._vec64_msb(raw)-28);var observer:=PackedInt64Array()
	for value:int in raw:observer.append(Point._s32(Point.shift_int64(value,-scale)))
	var minimum:=int(model.mesh_zoom)-23
	if scale<minimum:
		for axis in range(3):observer[axis]>>=(minimum-scale)&31
		scale=minimum
	var query_frame:=Point.new().frame_raw(int(frame.model),observer,scale)
	if query_frame.is_empty():result.reason="undefined_visible_source_frame";return result
	var parent_radii:=Phone.descriptor_radii(model.descriptor);var distance:=int(query_frame.query_center_raw[2])
	var outer:=Point._s32(Point.shift_int64(int(parent_radii.outer_raw),-scale));var inner:=Point._s32(Point.shift_int64(int(parent_radii.inner_raw),-scale))
	if Point._s32(distance-outer)>=0 or Point._s32(distance-inner)<=0:result.reason="visible_point_outside_original_terrain_query_bounds";return result
	var query:=Point.new().kernel.query_raw(frame.record.decode_u32(4),int(query_frame.query_style_raw),query_frame.query_matrix_raw,query_frame.query_center_raw,int(query_frame.query_limit_raw),1,query_frame.features)
	if query.is_empty() or int(query.query_result_raw)>=int(query_frame.query_limit_raw) or int(query.pending_query_flag)!=0:result.reason="undefined_visible_source_query";return result
	var residual:=Point.shift_int64(int(query.query_result_raw),scale)
	result["source_residual_s64_hex"]=_hex64(residual);result["vector_scale_s32"]=scale;result["query_result_s32"]=int(query.query_result_raw)
	if residual==0:result.certified=true;result.reason="exact_visible_source_zero";return result
	# A nonzero F581 residual is acceptable only for the exact raw outside
	# point of a freshly proved adjacent signed boundary, never a tolerance.
	var length:=sqrt(point[0]*point[0]+point[1]*point[1]+point[2]*point[2]);var direction:=PackedInt64Array()
	for value:float in point:direction.append(clampi(roundi(value/length*2147483647.0),-2147483647,2147483647))
	var boundary:=Field.new().sample_radial(frame.record,direction,1)
	if boundary.get("ok",false) and boundary.get("certified")==true and boundary.get("status")=="adjacent_sign_boundary" and boundary.position_raw==raw and boundary.source_bounds.terrain_query_eligible==true and int(boundary.residual_raw_s64)==residual:
		result.certified=true;result.reason="exact_adjacent_outside_point_identity";result["boundary_width_raw"]=int(boundary.bracket.width_raw)
	else:result.reason="visible_point_not_exact_source_boundary"
	return result
static func certify_geometry_point(surface:RefCounted,ship:RefCounted,event:Dictionary={})->Dictionary:
	var prepared:=_prepare_frame(surface,ship,event)
	if not prepared.ok:return {"contract":GUARD_CONTRACT,"certified":false,"reason":str(prepared.error),"scope":"local-visible-point-only-not-whole-triangle"}
	return _transport_guard(_geometry(prepared,surface))
static func eligibility(surface:RefCounted,ship:RefCounted,guard:Dictionary={},event:Dictionary={})->Dictionary:
	var measured:=certify_geometry_point(surface,ship,event)
	var valid:bool=_plain(guard) and guard==measured and measured.get("certified")==true
	return {"eligible":valid,"reason":"certified_current_visible_point" if valid else ("missing_or_stale_geometry_guard" if guard!=measured else str(measured.get("reason","uncertified_geometry"))),"geometry_guard":measured.duplicate(true),"whole_triangle_certified":false,"live_response_enabled":false,"source_contract":CONTRACT}
static func resolve(surface:RefCounted,ship:RefCounted,physical_gear_u16:int,context:Dictionary,event:Dictionary={})->Dictionary:
	if not _plain(context) or context.size()!=2 or not context.get("history_globals") is Dictionary or not context.get("geometry_guard") is Dictionary or not _history_valid(context.history_globals):return _failure(surface,ship,context,"invalid_explicit_caller_history_or_context")
	if not Phone._whole(physical_gear_u16,0,65535):return _failure(surface,ship,context,"invalid_physical_gear_word")
	var frame:=_prepare_frame(surface,ship,event)
	if not frame.ok:return _failure(surface,ship,context,str(frame.error))
	var initial:=caller_globals(context.history_globals);var data:Dictionary=frame.ship_data
	var offset:=int(data.inner_radius_raw)*Phone.Units.METRES_PER_RAW-float(frame.phone_clearance_m);var source_point:PackedFloat64Array=frame.body_point.duplicate()
	for axis in range(3):source_point[axis]+=float(frame.basis.y[axis])*offset
	var relative:=_raw_point(source_point)
	if relative.size()!=3:return _failure(surface,ship,context,"native_position_out_of_live_precision_domain")
	var player:=PackedByteArray();player.resize(338);player.fill(0);var parent:=player.duplicate();var matrix:=Phone.contact_orientation_q31(frame.basis,frame.input_attitude)
	if matrix.size()!=9:return _failure(surface,ship,context,"invalid_source_contact_orientation")
	for index in range(9):player.encode_s32(index*4,matrix[index])
	for axis in range(3):parent.encode_s32(axis*16,0x7fffffff)
	player.encode_u32(0x82,int(data.model_index));player[0x86]=1;parent[0x86]=2;player[0x56]=2;player[0x57]=1;player[0x14c]=int(frame.natural_ship.initial_object_flags_14c_u8)
	parent.encode_u32(0xa0,frame.record.decode_u32(4));parent=Ground.initialize_model(parent,int(frame.model)).object
	player.encode_u16(0x9e,physical_gear_u16);player.encode_u16(0xe4,(int(data.mass_s16)*4)&65535)
	player.encode_s64(0x138,int(data.outer_radius_raw));player.encode_s64(0x140,int(data.inner_radius_raw))
	for axis in range(3):
		player.encode_s64(0x3e+axis*8,relative[axis]);var units:=float(frame.body_velocity[axis])/Phone.Physics.VELOCITY_UNIT_MPS;var integer:=floori(units);var fraction:=roundi((units-float(integer))*65536.0)
		if fraction==65536:integer+=1;fraction=0
		if not Phone._whole(integer,-2147483648,2147483647):return _failure(surface,ship,context,"native_velocity_out_of_live_domain")
		player.encode_s32(0x8c+axis*4,integer);player.encode_u16(0xec+axis*2,fraction)
	var classified:=Natural.new().classify_natural_player(player,parent,relative,{"graphics_level":1,"initial_globals":initial})
	if not classified.get("ok",false):return _failure(surface,ship,context,str(classified.get("error","natural_query_failed")))
	var measured:=_transport_guard(_geometry(frame,surface));var eligible:bool=context.geometry_guard==measured and measured.get("certified")==true
	if int(classified.f576_return_s32)==0:
		var last:Dictionary=classified.iterations[-1]
		if int(last.child_index)>0:return _blocked(surface,ship,context,"unsupported_child_geometry_certificate",measured,classified)
		if int(classified.globals_after.collision_kind_u8)!=1 or str(last.branch)!="terrain_query" or int(last.f579_return_s32)!=0 or not last.has("query_result_raw") or int(last.query_result_raw)>=int(last.query_limit_raw):return _blocked(surface,ship,context,"unsupported_contact_without_current_terrain_previous_altitude",measured,classified)
		if not eligible:return _blocked(surface,ship,context,"uncertified_or_stale_physical_visible_geometry",measured,classified)
	var raw_context:={"initial_globals":initial,"player_object_index_u32":1,"graphics_level":1}
	if not Pipeline._valid_context(player,parent,relative,raw_context):return _failure(surface,ship,context,"invalid_prepared_raw_player_context")
	var kernel:=Pipeline.new()._dispatch_classification(player,parent,relative,raw_context,classified)
	if not kernel.get("ok",false):return _failure(surface,ship,context,str(kernel.get("error","natural_pipeline_rejected")))
	var applied:bool=kernel.response_applied;var pose:={"ok":true,"position":ship.position,"velocity":ship.velocity,"attitude":ship.attitude,"position_delta_raw":[0,0,0],"velocity_delta_q16":[0,0,0],"orientation_projection_policy":"unchanged-no-source-response"}
	if applied:
		pose=Phone._pose_delta(frame,player,kernel.body_after)
		if not pose.get("ok",false):return _failure(surface,ship,context,str(pose.get("reason","invalid_native_pose_projection")))
	var facts:={"source_contract":CONTRACT,"caller_policy":CALLER_POLICY,"terrain_revision":ContactTerrain.CONTACT_REVISION,"model_index":int(data.model_index),"parent_model_index":int(frame.model),"parent_uid_u32":int(frame.record.decode_u32(4)),"relative_position_s64_hex":_vector_hex(relative),"previous_altitude_s64_hex":_hex64(int(classified.previous_altitude_s64)),"native_previous_is_phone_AGL":false,"native_collision_kind":int(classified.globals_after.collision_kind_u8),"f576_return_s32":int(classified.f576_return_s32),"selected_child_index":int(classified.iterations[-1].child_index),"response_geometry_scope":"primary-player-volume-only","source_body_origin_policy":"authored-clearance-to-f1533-inner-radius-v1","source_body_origin_up_offset_m":offset,"source_inner_radius_raw":int(data.inner_radius_raw),"body_flags_14c_u8":int(player[0x14c]),"parent_flags_14c_u8":int(parent[0x14c]),"matching_bodyfixed_frame_56_57":true,"position_delta_raw":pose.position_delta_raw,"velocity_delta_q16":pose.velocity_delta_q16,"orientation_projection_policy":pose.orientation_projection_policy,"physical_visible_point_certified":eligible,"whole_triangle_certified":false,"response_applied":applied,"damage_applied":false,"clock_advanced":false,"live_response_enabled":false,"full_F569":false,"full_F570":false,"source_object_bank_present":false}
	return {"ok":true,"error":"","eligible":eligible,"response_applied":applied,"contact_detected":applied,"landing_accepted":bool(kernel.landing_accepted),"position":pose.position,"velocity":pose.velocity,"attitude":pose.attitude,"globals_after":kernel.globals_after.duplicate(true),"damage_calls":kernel.damage_calls.duplicate(true),"callbacks":kernel.callbacks.duplicate(true),"kernel":kernel.duplicate(true),"geometry_guard":measured.duplicate(true),"facts":facts}
