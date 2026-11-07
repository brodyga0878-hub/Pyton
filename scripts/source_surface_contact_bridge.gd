extends RefCounted
# Read-only phone/source boundary. Published height triangles are the geometry
# provider; their face normal is NOT F575 kind1's native radial normal.
# No Navigation, HP, clock, landing hold or independent SI impact law lives here.
const Frame=preload("res://scripts/source_surface_render_state.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const Units=preload("res://scripts/source_units.gd")
const Physics=preload("res://scripts/source_physics_bridge.gd")
const Core=preload("res://scripts/source_surface_contact.gd")
const CONTRACT:="source-surface-contact-phone-frame-v1"
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const DESCRIPTORS_SHA:="cf9c673c2bba22f0c865e77e3a7ceed5497053cdb444b80f31d7439176446818"
const HYPERDRIVE_SHA:="17fe376bf480aa34fe8278193c558a8a30d198fa06354caf3c9692de34b1cf47"
const GRID_WIDTH:=4000.0 # The existing Surface.height_at fallback lattice.
const SHIP_MODELS:={"cobra":38,"eagle":24,"shuttle":15}
static var _tables:Dictionary={}
static var _tables_mutex:=Mutex.new()
class CandidateShip extends RefCounted:
	var position:=Vector3.ZERO
	var velocity:=Vector3.ZERO
	var attitude:=Quaternion.IDENTITY
	var _profile:Dictionary={}
	func profile()->Dictionary:return _profile

static func _number(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func _whole(value:Variant,low:int,high:int)->bool:return _number(value) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _failure(reason:String)->Dictionary:return {"ok":false,"reason":reason,"source_contract":CONTRACT}
static func _s16(value:int)->int:return value-65536 if value>=32768 else value
static func _array3(value:Variant)->bool:
	if not (value is Array or value is PackedFloat64Array or value is PackedInt64Array) or value.size()!=3:return false
	for component:Variant in value:
		if not _number(component):return false
	return true
static func _basis_valid(value:Basis)->bool:
	return value.is_finite() and absf(value.determinant()-1.0)<0.00001 and absf(value.x.length_squared()-1.0)<0.00001 and absf(value.y.length_squared()-1.0)<0.00001 and absf(value.z.length_squared()-1.0)<0.00001 and absf(value.x.dot(value.y))<0.00001 and absf(value.x.dot(value.z))<0.00001 and absf(value.y.dot(value.z))<0.00001

static func to_bodyfixed_vector(basis:Basis,value:Vector3)->PackedFloat64Array:
	if not _basis_valid(basis) or not value.is_finite():return PackedFloat64Array()
	var result:=PackedFloat64Array()
	for axis in range(3):result.append(float(basis.x[axis])*float(value.x)+float(basis.y[axis])*float(value.y)+float(basis.z[axis])*float(value.z))
	return result
static func to_bodyfixed_point(basis:Basis,radius:float,value:Vector3)->PackedFloat64Array:
	if not _basis_valid(basis) or not is_finite(radius) or radius<=0 or not value.is_finite():return PackedFloat64Array()
	# Form radius+y before any Float32 Vector3 is constructed. Large planet
	# coordinates must not erase the centimetres of the local surface frame.
	var up:=radius+float(value.y);var result:=PackedFloat64Array()
	for axis in range(3):result.append(float(basis.x[axis])*float(value.x)+float(basis.y[axis])*up+float(basis.z[axis])*float(value.z))
	return result
static func to_local_vector(basis:Basis,value:Variant)->PackedFloat64Array:
	if not _basis_valid(basis) or not _array3(value):return PackedFloat64Array()
	var inverse:=Frame._inverse_rows(basis)
	if inverse.size()!=9:return PackedFloat64Array()
	var result:=PackedFloat64Array()
	for axis in range(3):result.append(inverse[axis*3]*float(value[0])+inverse[axis*3+1]*float(value[1])+inverse[axis*3+2]*float(value[2]))
	return result
static func apply_bodyfixed_delta(basis:Basis,original:Vector3,delta:Variant)->Dictionary:
	var local:=to_local_vector(basis,delta)
	if local.size()!=3 or not original.is_finite():return _failure("invalid_frame_delta")
	var result:=Vector3(float(original.x)+local[0],float(original.y)+local[1],float(original.z)+local[2])
	return {"ok":true,"value":result,"delta_local":local} if result.is_finite() else _failure("nonfinite_frame_delta")
static func native_orientation_q31(basis:Basis,attitude:Quaternion)->PackedInt64Array:
	if not _basis_valid(basis) or not attitude.is_finite() or attitude.length_squared()<0.0001:return PackedInt64Array()
	var phone:=basis*Basis(attitude.normalized());var axes:=[-phone.x,phone.y,-phone.z];var result:=PackedInt64Array()
	# Exactly SourceMotionBridge's proper LOCAL yaw(pi): native +X left,
	# +Y up, +Z forward. Never reflect the global/bodyfixed coordinate frame.
	for axis:Vector3 in axes:
		for component:float in [axis.x,axis.y,axis.z]:result.append(clampi(roundi(component*2147483647.0),-2147483647,2147483647))
	return result
static func contact_orientation_q31(basis:Basis,attitude:Quaternion)->PackedInt64Array:
	if not _basis_valid(basis) or not attitude.is_finite() or attitude.length_squared()<0.0001:return PackedInt64Array()
	var phone:=basis*Basis(attitude.normalized());var raw:=PackedInt64Array()
	for axis:Vector3 in [-phone.x,phone.y,-phone.z]:
		# Float32 rotations can be microscopically longer than one. Normalize
		# components in scalar doubles before the exact source F1520 operation;
		# a Q31 dot at +1 must not wrap solely due to phone matrix roundoff.
		var length:=sqrt(float(axis.x)*axis.x+float(axis.y)*axis.y+float(axis.z)*axis.z)
		if not is_finite(length) or length<=0:return PackedInt64Array()
		for component:float in [axis.x,axis.y,axis.z]:raw.append(clampi(roundi(component/length*2147483647.0),-2147483647,2147483647))
	return Ground._orthonormalize(raw)

static func _load_tables()->bool:
	_tables_mutex.lock()
	if not _tables.is_empty():_tables_mutex.unlock();return true
	var result:Dictionary={}
	for row:Array in [["descriptors","res://data/ffe_runtime_model_descriptors.json",DESCRIPTORS_SHA],["hyperdrive","res://data/ffe_hyperdrive.json",HYPERDRIVE_SHA]]:
		if not FileAccess.file_exists(row[1]) or FileAccess.get_sha256(row[1])!=row[2]:_tables_mutex.unlock();return false
		var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(row[1]))
		if not data is Dictionary or data.get("schema")!=1 or data.get("source_sha256")!=SOURCE_SHA:_tables_mutex.unlock();return false
		result[row[0]]=data
	_tables=result;_tables_mutex.unlock();return true
static func model_descriptor(model_index:int)->PackedByteArray:
	if not _load_tables():return PackedByteArray()
	var row:Variant=_tables.descriptors.get("models",{}).get(str(model_index))
	if not row is Dictionary or not row.get("descriptor_hex") is String:return PackedByteArray()
	var result:=str(row.descriptor_hex).hex_decode()
	return result if result.size()==68 and Frame._sha(result)==str(row.get("descriptor_sha256","")) else PackedByteArray()
static func descriptor_radii(descriptor:PackedByteArray)->Dictionary:
	if descriptor.size()!=68:return _failure("invalid_descriptor")
	# The common F1533 radius branch is valid for ship descriptors too; calling
	# Ground.initialize_model would wrongly reject their physical-spec pointer.
	var exponent:=_s16((int(descriptor.decode_u16(0x14))+int(descriptor.decode_u16(0x18))+7)&65535)-15
	return {"ok":true,"outer_raw":Ground._shift64(_s16(descriptor.decode_u16(0x2c)),exponent),"inner_raw":Ground._shift64(_s16(descriptor.decode_u16(0x30)),exponent),"shift":exponent,"source_procedure":"F1533 common radii/F1495 signed64 shift"}
static func source_ship_data(ship_id:String)->Dictionary:
	if not SHIP_MODELS.has(ship_id) or not _load_tables():return _failure("unsupported_ship_profile")
	var index:int=SHIP_MODELS[ship_id];var row:Variant=_tables.hyperdrive.get("ship_specs",{}).get(str(index));var descriptor:=model_descriptor(index)
	if not row is Dictionary or not row.get("spec_hex") is String or descriptor.size()!=68:return _failure("missing_ship_source_data")
	var spec:=str(row.spec_hex).hex_decode();var radii:=descriptor_radii(descriptor)
	if spec.size()!=24 or Frame._sha(spec)!=str(row.get("spec_sha256","")) or not radii.get("ok",false):return _failure("invalid_ship_source_data")
	return {"ok":true,"ship_id":ship_id,"model_index":index,"descriptor":descriptor,"spec":spec,"mass_s16":_s16(spec.decode_u16(6)),"inner_radius_raw":radii.inner_raw,"outer_radius_raw":radii.outer_raw,"radii_shift":radii.shift,"source_sha256":SOURCE_SHA,"descriptor_resource_sha256":DESCRIPTORS_SHA,"spec_resource_sha256":HYPERDRIVE_SHA}

static func _fallback(surface:RefCounted,x:float,z:float)->Dictionary:
	if not surface.has_method("raw_height_at") or not surface.has_method("grid_cells"):return _failure("missing_height_provider")
	var count:Variant=surface.grid_cells()
	if not _whole(count,1,1000000):return _failure("invalid_surface_grid")
	var cell:=GRID_WIDTH/float(count);var gx:=(x+GRID_WIDTH*0.5)/cell;var gz:=(z+GRID_WIDTH*0.5)/cell
	var ix:=floorf(gx);var iz:=floorf(gz);var fx:=gx-ix;var fz:=gz-iz;var x0:=ix*cell-GRID_WIDTH*0.5;var z0:=iz*cell-GRID_WIDTH*0.5
	var a:Variant=surface.raw_height_at(x0,z0);var b:Variant=surface.raw_height_at(x0+cell,z0);var c:Variant=surface.raw_height_at(x0,z0+cell)
	if not _number(a) or not _number(b) or not _number(c):return _failure("invalid_surface_vertex")
	var first:=fx+fz<=1.0;var height:=0.0;var vertices:=PackedFloat64Array();var slope_x:=0.0;var slope_z:=0.0
	if first:
		height=float(a)+(float(b)-float(a))*fx+(float(c)-float(a))*fz
		vertices=PackedFloat64Array([x0,a,z0,x0+cell,b,z0,x0,c,z0+cell]);slope_x=(float(b)-float(a))/cell;slope_z=(float(c)-float(a))/cell
	else:
		var d:Variant=surface.raw_height_at(x0+cell,z0+cell)
		if not _number(d):return _failure("invalid_surface_vertex")
		height=float(d)+(float(c)-float(d))*(1.0-fx)+(float(b)-float(d))*(1.0-fz)
		vertices=PackedFloat64Array([x0+cell,b,z0,x0+cell,d,z0+cell,x0,c,z0+cell]);slope_x=(float(d)-float(c))/cell;slope_z=(float(d)-float(b))/cell
	# This is the selected three-vertex plane, not a separately sampled gradient.
	var normal:=Vector3(-slope_x,1,-slope_z).normalized()
	if not is_finite(height) or not normal.is_finite():return _failure("invalid_surface_plane")
	return {"ok":true,"height":height,"normal":normal,"provider":"surface-height-grid-exact-triangle-v1","cell":Vector2(ix,iz),"triangle":0 if first else 1,"vertices_local_f64":vertices,"cell_width_m":cell}

static func sample(surface:RefCounted,ship:RefCounted)->Dictionary:
	if surface==null or ship==null or not surface.has_method("source_surface") or not surface.source_surface():return _failure("outside_source_surface")
	var globe:Variant=surface.get("globe")
	if not globe is RefCounted or not globe.has_method("basis_at") or not _number(globe.get("latitude")) or not _number(globe.get("longitude")) or not _number(globe.get("radius")) or float(globe.radius)<=0:return _failure("invalid_surface_frame")
	var position:Variant=ship.get("position");var velocity:Variant=ship.get("velocity");var attitude:Variant=ship.get("attitude")
	if not position is Vector3 or not position.is_finite() or not velocity is Vector3 or not velocity.is_finite() or not attitude is Quaternion or not attitude.is_finite() or attitude.length_squared()<0.0001:return _failure("invalid_ship_pose")
	var basis:Variant=globe.basis_at(float(globe.latitude),float(globe.longitude))
	if not basis is Basis or not _basis_valid(basis):return _failure("invalid_surface_basis")
	var hit:Dictionary={};var state:Variant=surface.get("source_render_state")
	if state is RefCounted and state.has_method("height_at"):
		var query:Variant=state.height_at(globe,float(position.x),float(position.z))
		if not query is Dictionary:return _failure("invalid_published_height_result")
		if not query.is_empty():
			if not _number(query.get("height")) or not query.get("normal") is Vector3 or not query.normal.is_finite() or query.normal.length_squared()<0.0001 or query.normal.y<=0:return _failure("invalid_published_height_plane")
			hit=query.duplicate(true);hit["ok"]=true;hit["provider"]="verified-saved-contact-triangle" if str(query.get("revision",""))=="source-surface-contact-triangle-v1" else "published-source-render-triangle"
	if hit.is_empty():hit=_fallback(surface,float(position.x),float(position.z))
	if not hit.get("ok",false):return hit
	if not surface.has_method("clearance"):return _failure("missing_phone_clearance")
	var clearance:Variant=surface.clearance(ship)
	if not _number(clearance) or float(clearance)<0:return _failure("invalid_phone_clearance")
	var normal:Vector3=hit.normal;var body_position:=to_bodyfixed_point(basis,float(globe.radius),position);var body_velocity:=to_bodyfixed_vector(basis,velocity);var body_normal:=to_bodyfixed_vector(basis,normal)
	if body_position.size()!=3 or body_velocity.size()!=3 or body_normal.size()!=3:return _failure("invalid_bodyfixed_mapping")
	return {"ok":true,"source_contract":CONTRACT,"height":float(hit.height),"normal":normal,"agl_m":float(position.y)-float(hit.height)-float(clearance),"phone_clearance_m":float(clearance),"basis":basis,"radius_m":float(globe.radius),"input_position":position,"input_velocity":velocity,"input_attitude":attitude,"position_bodyfixed_f64":body_position,"velocity_bodyfixed_f64":body_velocity,"provider_normal_bodyfixed_f64":body_normal,"orientation_q31":native_orientation_q31(basis,attitude),"provider":str(hit.provider),"provider_metadata":hit.duplicate(true),"mesh_normal_is_native_contact_normal":false,"full_f569_classifier":false,"phone_frame_adapter":true}

static func _resolve_failure(error:String)->Dictionary:
	return {"ok":false,"error":error,"landing_accepted":false,"damage_calls":[],"callbacks":[],"kernel":{},"facts":{"source_contract":CONTRACT,"full_f569_classifier":false}}
static func _orientation_basis(body:PackedByteArray)->Basis:
	var axes:Array=[]
	for column in range(3):axes.append(Vector3(body.decode_s32(column*12),body.decode_s32(column*12+4),body.decode_s32(column*12+8))/2147483647.0)
	return Basis(axes[0],axes[1],axes[2])
static func _pose_delta(sampled:Dictionary,before:PackedByteArray,after:PackedByteArray)->Dictionary:
	var position_delta:=PackedFloat64Array();var velocity_delta:=PackedFloat64Array();var raw_position_delta:Array=[];var raw_velocity_delta:Array=[]
	for axis in range(3):
		var delta:int=after.decode_s64(0x3e+axis*8)-before.decode_s64(0x3e+axis*8)
		position_delta.append(float(delta)*Units.METRES_PER_RAW);raw_position_delta.append(delta)
		var old_q16:=int(before.decode_s32(0x8c+axis*4))*65536+int(before.decode_u16(0xec+axis*2))
		var new_q16:=int(after.decode_s32(0x8c+axis*4))*65536+int(after.decode_u16(0xec+axis*2))
		velocity_delta.append(float(new_q16-old_q16)*(Physics.VELOCITY_UNIT_MPS/65536.0));raw_velocity_delta.append(new_q16-old_q16)
	var position:=apply_bodyfixed_delta(sampled.basis,sampled.input_position,position_delta);var velocity:=apply_bodyfixed_delta(sampled.basis,sampled.input_velocity,velocity_delta)
	if not position.ok or not velocity.ok:return _failure("invalid_native_pose_delta")
	var attitude:Quaternion=sampled.input_attitude;var projection_policy:="native-rotation-delta-to-phone-quaternion-v1";var native_determinant:=_orientation_basis(after).determinant()
	if before.slice(0,36)!=after.slice(0,36):
		var previous:=_orientation_basis(before);var next:=_orientation_basis(after)
		if not previous.is_finite() or not next.is_finite() or previous.determinant()<0.0001 or native_determinant<(-0.0001):return _failure("invalid_native_orientation")
		if absf(native_determinant)<0.0001:
			# A real tangential F575 impact can make finalForward parallel to
			# oldX. Native F1520 then returns a rank-one matrix (native0013).
			# It has no Quaternion projection: keep the prior valid PHONE pose
			# while preserving exact raw output, other deltas and F953 requests.
			projection_policy="native-rank-deficient-preserve-phone-quaternion-v1"
		else:
			# Retain the input's Q31 quantization residue too: apply the native
			# rotation delta instead of replacing the phone attitude with raw axes.
			var local:Basis=sampled.basis.inverse()*(next*previous.inverse())*sampled.basis*Basis(attitude)
			if not local.is_finite() or local.determinant()<0.0001:return _failure("invalid_local_orientation_delta")
			attitude=local.orthonormalized().get_rotation_quaternion().normalized()
	if not attitude.is_finite():return _failure("nonfinite_native_attitude")
	return {"ok":true,"position":position.value,"velocity":velocity.value,"attitude":attitude,"position_delta_raw":raw_position_delta,"velocity_delta_q16":raw_velocity_delta,"orientation_projection_policy":projection_policy,"native_orientation_determinant":native_determinant}

static func resolve(surface:RefCounted,ship:RefCounted,physical_gear_u16:int,event:Dictionary={})->Dictionary:
	if not _whole(physical_gear_u16,0,65535) or ship==null or not ship.has_method("profile") or not ship.get("ship_id") is String:return _resolve_failure("invalid_source_ship_or_gear")
	var kind:Variant=event.get("kind","terrain")
	if not kind is String or kind not in ["terrain","city_floor","manual"]:return _resolve_failure("unsupported_contact_provider_kind")
	var candidate:Variant=event.get("candidate_position",ship.get("position"))
	if not candidate is Vector3 or not candidate.is_finite():return _resolve_failure("invalid_candidate_position")
	var velocity:Variant=ship.get("velocity");var attitude:Variant=ship.get("attitude");var profile:Variant=ship.profile()
	if not velocity is Vector3 or not velocity.is_finite() or not attitude is Quaternion or not attitude.is_finite() or not profile is Dictionary:return _resolve_failure("invalid_source_ship_pose")
	var probe:=CandidateShip.new();probe.position=candidate;probe.velocity=velocity;probe.attitude=attitude;probe._profile=profile.duplicate(true)
	var sampled:=sample(surface,probe)
	if not sampled.get("ok",false):return _resolve_failure(str(sampled.get("reason","invalid_surface_sample")))
	var provided:Variant=event.get("provider_hit",{})
	if not provided is Dictionary:return _resolve_failure("invalid_contact_provider_hit")
	if kind=="city_floor" and not provided.has("height"):return _resolve_failure("city_floor_requires_explicit_plane_height")
	if provided.has("height"):
		if not _number(provided.height) or not provided.get("normal") is Vector3 or not provided.normal.is_finite() or provided.normal.y<=0 or provided.normal.length_squared()<0.0001:return _resolve_failure("invalid_contact_provider_plane")
		sampled.height=float(provided.height);sampled.normal=provided.normal;sampled.provider_normal_bodyfixed_f64=to_bodyfixed_vector(sampled.basis,provided.normal)
		sampled.agl_m=float(candidate.y)-sampled.height-float(sampled.phone_clearance_m);sampled.provider="explicit-"+str(kind)+"-plane-provider";sampled.provider_metadata=provided.duplicate(true)
	if event.is_empty() and sampled.agl_m>0:return _resolve_failure("outside_surface_contact")
	var data:=source_ship_data(ship.ship_id)
	if not data.get("ok",false) or int(data.inner_radius_raw)<=0:return _resolve_failure("invalid_ship_source_metadata")
	var globe:RefCounted=surface.globe;var record:Variant=globe.get("source_record")
	if not record is PackedByteArray or record.size()!=68:return _resolve_failure("missing_original_parent_record")
	var parent_model:=int(record.decode_u16(12));var parent_descriptor:=model_descriptor(parent_model);var parent_radii:=descriptor_radii(parent_descriptor)
	if parent_descriptor.size()!=68 or not parent_radii.get("ok",false):return _resolve_failure("invalid_original_parent_descriptor")
	var origin_offset:=float(data.inner_radius_raw)*Units.METRES_PER_RAW-float(sampled.phone_clearance_m)
	var source_point:PackedFloat64Array=sampled.position_bodyfixed_f64.duplicate();var raw_position:=PackedInt64Array();var raw_velocity:=PackedInt64Array();var fractions:=PackedInt64Array()
	for axis in range(3):
		source_point[axis]+=float(sampled.basis.y[axis])*origin_offset
		var coordinate:=Physics.raw_metres(source_point[axis])
		# The live SI boundary is deliberately below exact-double integer range;
		# source raw arithmetic outside it remains the independent kernel's scope.
		if coordinate.is_empty() or absi(int(coordinate.raw))>0x10000000000000:return _resolve_failure("source_position_out_of_live_precision_domain")
		raw_position.append(int(coordinate.raw))
		var units:=float(sampled.velocity_bodyfixed_f64[axis])/Physics.VELOCITY_UNIT_MPS;var integer:=floori(units);var fraction:=roundi((units-float(integer))*65536.0)
		if fraction==65536:integer+=1;fraction=0
		if not _whole(integer,-2147483648,2147483647):return _resolve_failure("source_velocity_out_of_domain")
		raw_velocity.append(integer);fractions.append(fraction)
	var altitude:=Physics.raw_metres(float(sampled.agl_m))
	if altitude.is_empty() or absi(int(altitude.raw))>0x7fffffff:return _resolve_failure("contact_agl_out_of_live_domain")
	var body:=PackedByteArray();body.resize(Core.OBJECT_BYTES);body.fill(0);var parent:=body.duplicate()
	var contact_matrix:=contact_orientation_q31(sampled.basis,sampled.input_attitude)
	if contact_matrix.size()!=9:return _resolve_failure("invalid_contact_orientation")
	for index in range(9):body.encode_s32(index*4,int(contact_matrix[index]))
	for index in [0,4,8]:parent.encode_s32(index*4,0x7fffffff)
	body.encode_u32(0x82,int(data.model_index));body[0x86]=1;parent.encode_u32(0x82,parent_model);parent[0x86]=2
	body.encode_u16(0x9e,physical_gear_u16);body.encode_u16(0xe4,(int(data.mass_s16)*4)&65535)
	for axis in range(3):
		body.encode_s64(0x3e+axis*8,raw_position[axis]);body.encode_s32(0x8c+axis*4,raw_velocity[axis]);body.encode_u16(0xec+axis*2,fractions[axis])
	body.encode_s64(0x138,int(data.outer_radius_raw));body.encode_s64(0x140,int(data.inner_radius_raw));parent.encode_s64(0x138,int(parent_radii.outer_raw));parent.encode_s64(0x140,int(parent_radii.inner_raw))
	var globals:={"collision_flags_u8":0,"collider_index_u8":0,"collision_active_u8":1,"collision_enabled_u8":1,"previous_altitude_s64":int(data.inner_radius_raw)+int(altitude.raw),"collision_kind_u8":1,"player_object_index_u32":1,"collider_parent_selected":false}
	var context:={"relative_position_s64":raw_position.duplicate(),"distance_squared_s32":0,"globals":globals,"body_descriptor":data.descriptor,"parent_descriptor":parent_descriptor,"body_spec":data.spec}
	var result:Dictionary=Core.resolve_player(body,parent,context)
	if not result.get("ok",false):return _resolve_failure(str(result.get("error","source_contact_rejected")))
	var pose:=_pose_delta(sampled,body,result.body_after)
	if not pose.get("ok",false):return _resolve_failure(str(pose.get("reason","invalid_source_contact_pose")))
	var facts:={"source_contract":CONTRACT,"kernel_contract":Core.CONTRACT,"kind":kind,"native_collision_kind":1,"provider":sampled.provider,"height_m":sampled.height,"agl_m":sampled.agl_m,"provider_normal":[sampled.normal.x,sampled.normal.y,sampled.normal.z],"native_radial_normal_q31":result.normal_q31.duplicate(),"input_matrix_policy":"proper-local-yaw-pi-double-unit-q31-source-f1520-v1","mesh_normal_is_native_contact_normal":false,"phone_clearance_m":sampled.phone_clearance_m,"source_inner_radius_raw":data.inner_radius_raw,"source_body_origin_up_offset_m":origin_offset,"source_body_origin_policy":"authored-clearance-to-f1533-inner-radius-v1","altitude_policy":"sampled-phone-agl-plus-native-inner-radius-v1","previous_altitude_s64":globals.previous_altitude_s64,"model_index":data.model_index,"parent_model_index":parent_model,"source_mass_s16":data.mass_s16,"physical_gear_u16":physical_gear_u16,"position_delta_raw":pose.position_delta_raw,"velocity_delta_q16":pose.velocity_delta_q16,"source_object_indices_policy":"isolated-player1-parent2-postclassification-v1","city_floor_is_explicit_radial_proxy":kind=="city_floor","full_f569_classifier":false,"full_f575":false,"damage_applied":false,"clock_advanced":false}
	facts.orientation_projection_policy=pose.orientation_projection_policy;facts.native_orientation_determinant=pose.native_orientation_determinant
	if pose.orientation_projection_policy=="native-rank-deficient-preserve-phone-quaternion-v1":facts.native_orientation_q31_after=Array(Ground._matrix(result.body_after))
	return {"ok":true,"error":"","position":pose.position,"velocity":pose.velocity,"attitude":pose.attitude,"landing_accepted":bool(result.landing_accepted),"damage_calls":result.damage_calls.duplicate(true),"callbacks":result.callbacks.duplicate(true),"kernel":result,"facts":facts}
