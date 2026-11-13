extends RefCounted
# Explicit user-command diagnostic. It compares copied visible-provider data
# with an isolated source-field ray, never a live collision/landing policy.
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const ContactTerrain=preload("res://scripts/source_contact_surface_terrain.gd")
const Field=preload("res://scripts/source_terrain_contact_field.gd")
const Bridge=preload("res://scripts/source_surface_contact_bridge.gd")
const Frame=preload("res://scripts/source_surface_render_state.gd")
const Patch=preload("res://scripts/source_surface_contact_patch.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Units=preload("res://scripts/source_units.gd")
const CONTRACT:="source-surface-explicit-readonly-height-comparison-v1"
const FRAME_FIELDS:=["configured_ok","source_key","core_width","core_cells","core_offset","_frame","_vertices","_grid_x","_grid_z","_minimum","_maximum"]

static func _number(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func _base()->Dictionary:
	return {"ok":false,"reason":"unavailable","source_contract":CONTRACT,"diagnostic_only":true,"response_applied":false,"live_collision_classifier_changed":false,"interpolated_points_certified":false,"positive_player_classification_executed":false,"source_object_bank_present":false,"query_count":0,"height_metric":"radial elevation above the shared source static reference radius; visible local tangent y is reported separately","explicit_user_command_only":true}
static func _failure(reason:String,context:Dictionary={})->Dictionary:
	var result:=_base();result.reason=reason;result["query_context"]=context.duplicate(true)
	return _plain(result)
static func _plain(value:Variant)->Variant:
	if value is Dictionary:
		var result:Dictionary={}
		for key:Variant in value:result[str(key)]=_plain(value[key])
		return result
	if value is Array:
		var result:Array=[]
		for item:Variant in value:result.append(_plain(item))
		return result
	return str(value) if value is StringName else value
static func _hex64(value:int)->String:
	var raw:=PackedByteArray();raw.resize(8);raw.encode_s64(0,value);return raw.hex_encode()
static func _vector_hex(value:PackedInt64Array)->String:
	var raw:=PackedByteArray();raw.resize(24)
	for axis in range(3):raw.encode_s64(axis*8,value[axis])
	return raw.hex_encode()
static func _clone_terrain(globe:RefCounted)->RefCounted:
	var snapshot:Dictionary=globe.capture_worker_state()
	if globe.revision==Terrain.REVISION_NAME:return Terrain.from_worker_state(snapshot)
	if globe.revision==ContactTerrain.CONTACT_REVISION:return ContactTerrain.from_worker_state(snapshot)
	return null
static func _clone_value(value:Variant)->Variant:
	if value is Dictionary or value is Array:return value.duplicate(true)
	if value is PackedVector3Array or value is PackedFloat64Array or value is PackedByteArray:return value.duplicate()
	return value
static func _provider_copy(provider:RefCounted,sampler:RefCounted)->Dictionary:
	if provider==null:return {"ok":true,"provider":null,"kind":"diagonal_grid_fallback","source_key":"","geometry_sha256":""}
	if provider.get_script()==Frame:
		var copied:=Frame.new();var geometry:Dictionary={}
		for name:String in FRAME_FIELDS:
			var value:Variant=provider.get(name);copied.set(name,_clone_value(value));geometry[name]=_clone_value(value)
		return {"ok":true,"provider":copied,"kind":"published_core_triangles","source_key":str(copied.source_key),"geometry_sha256":Frame._sha(var_to_bytes(geometry))}
	if provider.get_script()==Patch:
		var raw:Variant=provider.get("_patch")
		if not raw is Dictionary:return {"ok":false,"reason":"invalid_saved_contact_provider"}
		var captured:Dictionary=raw.duplicate(true);var copied:=Patch.new()
		if not copied.configure(captured,sampler):return {"ok":false,"reason":"saved_contact_copy_did_not_validate"}
		return {"ok":true,"provider":copied,"kind":"verified_saved_contact_triangle","source_key":str(copied.source_key),"geometry_sha256":Frame._sha(var_to_bytes(captured))}
	return {"ok":false,"reason":"unsupported_visible_provider_type"}
static func _context(surface:RefCounted,ship:RefCounted,provider:Dictionary)->Dictionary:
	var globe:RefCounted=surface.globe;var position:Vector3=ship.position;var attitude:Quaternion=ship.attitude
	var record:PackedByteArray=globe.source_record
	return {"body_id":str(surface.body_id),"parent_uid_u32":int(record.decode_u32(4)),"source_model_index":int(record.decode_u16(12)),"source_record_sha256":Frame._sha(record),"terrain_revision":str(globe.revision),"height_policy":str(globe.source_policy.get("height_policy","")),"frame_index":int(surface.frame_index),"latitude":float(globe.latitude),"longitude":float(globe.longitude),"reference_radius_m":float(globe.radius),"ship_position_local_m":[float(position.x),float(position.y),float(position.z)],"ship_attitude":[float(attitude.x),float(attitude.y),float(attitude.z),float(attitude.w)],"source_elapsed_days":float(surface.get("_source_days")),"visible_provider_kind":str(provider.kind),"visible_provider_source_key":str(provider.source_key),"visible_provider_geometry_sha256":str(provider.geometry_sha256)}
static func _bodyfixed_scalar64(globe:RefCounted,x:float,height:float,z:float)->PackedFloat64Array:
	var axes:=Frame._axes(globe.latitude,globe.longitude);var values:=PackedFloat64Array()
	for axis in range(3):values.append(float(axes[0][axis])*x+float(axes[1][axis])*(globe.radius+height)+float(axes[2][axis])*z)
	return values
static func _length(values:Variant)->float:
	return sqrt(float(values[0])*values[0]+float(values[1])*values[1]+float(values[2])*values[2])

static func sample(surface:RefCounted,ship:RefCounted)->Dictionary:
	if surface==null or ship==null or surface.get("active")!=true or not surface.get("globe") is RefCounted:return _failure("no_active_source_surface")
	var globe:RefCounted=surface.globe
	if globe.get("revision") not in [Terrain.REVISION_NAME,ContactTerrain.CONTACT_REVISION] or globe.get("configured_ok")!=true or not globe.get("source_record") is PackedByteArray or not Terrain.supported_model(globe.source_record):return _failure("unsupported_source_surface")
	if not ship.get("position") is Vector3 or not ship.position.is_finite() or not ship.get("attitude") is Quaternion or not ship.attitude.is_finite():return _failure("invalid_ship_pose")
	for name:String in ["radius","latitude","longitude"]:
		if not _number(globe.get(name)):return _failure("invalid_source_surface_frame")
	if globe.radius<=0 or absf(globe.latitude)>PI*0.5 or not _number(surface.get("_source_days")):return _failure("invalid_source_surface_frame")
	var sampler:=_clone_terrain(globe)
	if sampler==null:return _failure("source_surface_copy_rejected")
	var copied:=_provider_copy(surface.get("source_render_state"),sampler)
	if not copied.get("ok",false):return _failure(str(copied.reason))
	var context:=_context(surface,ship,copied)
	var x:=float(ship.position.x);var z:=float(ship.position.z)
	var hit:Dictionary=copied.provider.height_at(sampler,x,z) if copied.provider!=null else {}
	var visible_local:=NAN
	if not hit.is_empty():visible_local=float(hit.height)
	else:
		# Execute the actual production fallback on an isolated Surface/terrain,
		# never by calling a height or snapshot method on the observed surface.
		var isolated:=Surface.new();isolated.active=true;isolated.globe=sampler;isolated.body_id=str(surface.body_id)
		visible_local=isolated.height_at(x,z);copied.kind="diagonal_grid_fallback"
	if not is_finite(visible_local):return _failure("visible_surface_height_unavailable",context)
	context["visible_provider_kind"]=str(copied.kind)
	var visible_point:=_bodyfixed_scalar64(sampler,x,visible_local,z);var radius:=_length(visible_point)
	if not is_finite(radius) or radius<=0:return _failure("invalid_visible_source_direction",context)
	var direction:=PackedInt64Array()
	for value:float in visible_point:direction.append(clampi(roundi(value/radius*2147483647.0),-2147483647,2147483647))
	var root:=Field.new().sample_radial(sampler.source_record.duplicate(),direction,1)
	if not root.get("ok",false) or root.get("certified")!=true:
		var failure:=_failure(str(root.get("error","uncertified_signed_source_root")),context)
		failure.query_count=int(root.get("query_count",0));failure["visible_local_height_m"]=visible_local;return _plain(failure)
	var root_point:PackedInt64Array=root.position_raw;var root_radius:=Units.metres(_length(root_point))
	var visible_height:=radius-float(sampler.radius);var root_height:=root_radius-float(sampler.radius)
	if not is_finite(root_height) or not is_finite(visible_height):return _failure("nonfinite_comparison_height",context)
	var phone_point:=Bridge.to_bodyfixed_point(sampler.basis_at(sampler.latitude,sampler.longitude),sampler.radius,Vector3(x,visible_local,z))
	var mapping_distance:=0.0
	for axis in range(3):mapping_distance+=pow(phone_point[axis]-visible_point[axis],2)
	var result:=_base();result.ok=true;result.reason="explicit_surface_height_comparison"
	result["query_context"]=context;result["context_binding_sha256"]=JSON.stringify(context).sha256_text()
	result["body_id"]=str(context.body_id);result["parent_uid_u32"]=int(context.parent_uid_u32);result["source_model_index"]=int(context.source_model_index)
	result["terrain_revision"]=str(context.terrain_revision);result["height_policy"]=str(context.height_policy)
	result["visible_provider_kind"]=str(copied.kind);result["visible_height_m"]=visible_height;result["visible_local_height_m"]=visible_local
	result["source_root_height_m"]=root_height;result["delta_m"]=root_height-visible_height
	result["source_root_status"]=str(root.status);result["source_root_position_s64_hex"]=_vector_hex(root_point);result["source_direction_q31"]=Array(direction)
	result["source_residual_s64_hex"]=_hex64(int(root.residual_raw_s64));result["source_residual_m"]=float(root.residual_m);result["query_count"]=int(root.query_count)
	result["vector_scale_s32"]=int(root.source_bounds.vector_scale_s32);result["original_zero_radius_bounds_eligible"]=bool(root.source_bounds.terrain_query_eligible);result["original_zero_radius_bound_branch"]=str(root.source_bounds.branch)
	result["sampled_radial_point_certified"]=true;result["bounds_are_positive_player_eligibility"]=false
	result["field_contract"]=Field.CONTRACT;result["field_height_policy"]=Field.HEIGHT_POLICY
	result["source_raw_to_metres"]=Units.METRES_PER_RAW;result["phone_basis_vs_scalar64_distance_m"]=sqrt(mapping_distance)
	result["field_seed_policy"]="reviewed JJFFE F879 placement with SAR3, followed by independently signed DOS F581/F1876 certification; original DOS F879 SAR4 is distinct"
	return _plain(result)
