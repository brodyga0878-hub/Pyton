extends RefCounted
# Read-only F576 operands at the current authored phone centre. These are
# isolated object records, not a live F569/F570 bank or a landing predicate.
# In particular, the published phone mesh and source F581 are not yet aligned.
const Natural=preload("res://scripts/source_natural_contact.gd")
const Envelope=preload("res://scripts/source_spherical_contact_probe.gd")
const Bridge=preload("res://scripts/source_surface_contact_bridge.gd")
const Frame=preload("res://scripts/source_surface_render_state.gd")
const FuelContact=preload("res://scripts/source_fuel_contact.gd")
const CONTRACT:="dos-firstenc-f576-readonly-phone-authored-centre-v1"
const DATA_PATH:="res://data/ffe_natural_contact.json"
const DATA_SHA:="0074a49df9f22879a4eefbef6dda183cbb517243792dd8d086cb782c2da5603e"
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"

static func _base()->Dictionary:
	return {"ok":false,"reason":"unavailable","source_contract":CONTRACT,"diagnostic_only":true,"response_applied":false,"full_F569":false,"source_object_bank_present":false,"live_collision_classifier_changed":false,"original_F575_dispatch_executed":false,"origin_policy":"phone-authored-centre-no-ground-offset-v1","terrain_provider_queried":false,"mesh_source_height_alignment_proved":false}
static func _failure(reason:String)->Dictionary:
	var result:=_base();result.reason=reason;return result
static func _uid_hex(value:int)->String:
	var raw:=PackedByteArray();raw.resize(4);raw.encode_u32(0,value);return raw.hex_encode()
static func _matrix_write(object:PackedByteArray,matrix:PackedInt64Array)->void:
	for element in range(9):object.encode_s32(element*4,matrix[element])
static func _orientation(world:RefCounted,ship:RefCounted,surface:RefCounted,body:Dictionary,days:float)->PackedInt64Array:
	var basis:=Basis.IDENTITY
	if surface!=null and surface.get("active")==true:
		var globe:RefCounted=surface.globe;basis=globe.basis_at(globe.latitude,globe.longitude)
	else:
		var rotation:=FuelContact._basis_readonly(world,body,days)
		if rotation.is_empty():return PackedInt64Array()
		var rows:=Frame._inverse_rows(rotation.basis)
		if rows.size()!=9:return PackedInt64Array()
		basis=Basis(Vector3(rows[0],rows[3],rows[6]),Vector3(rows[1],rows[4],rows[7]),Vector3(rows[2],rows[5],rows[8]))
	if not ship.get("attitude") is Quaternion:return PackedInt64Array()
	return Bridge.contact_orientation_q31(basis,ship.attitude)

static func sample(world:RefCounted,ship:RefCounted,surface:RefCounted,days:float)->Dictionary:
	# The older read-only envelope owns the already tested scalar64 position
	# adapter and isolated ephemeris evaluation. Its sphere verdict is unused.
	var mapped:=Envelope.sample(world,ship,surface,days)
	if not mapped.get("ok",false):return _failure(str(mapped.get("reason","invalid_query_context")))
	var model:=int(mapped.parent_model_index)
	if model<117 or model>148:return _failure("outside_natural_parent_scope")
	if not FileAccess.file_exists(DATA_PATH) or FileAccess.get_sha256(DATA_PATH)!=DATA_SHA:return _failure("unverified_natural_contact_resource")
	var body:Dictionary=world.by_id[str(mapped.body_id)]
	var record:=str(body.get("runtime_record_hex","")).hex_decode()
	if record.size()!=68 or record.decode_u16(12)!=model:return _failure("parent_original_record_model_mismatch")
	var ship_data:=Natural.ship_model(int(mapped.body_model_index));var parent_data:=Natural.parent_model(model)
	if ship_data.is_empty() or parent_data.is_empty():return _failure("unsupported_or_unverified_source_model")
	var matrix:=_orientation(world,ship,surface,body,days)
	if matrix.size()!=9:return _failure("invalid_authored_ship_orientation")
	var vector_bytes:=str(mapped.relative_position_s64_hex).hex_decode();var relative:=PackedInt64Array()
	if vector_bytes.size()!=24:return _failure("invalid_source_position_adapter")
	for axis in range(3):relative.append(vector_bytes.decode_s64(axis*8))
	var player:=PackedByteArray();player.resize(Natural.OBJECT_BYTES);player.fill(0);var parent:=player.duplicate()
	_matrix_write(player,matrix);_matrix_write(parent,PackedInt64Array([0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff]))
	player.encode_u32(0x82,int(mapped.body_model_index));parent.encode_u32(0x82,model)
	player[0x86]=1;parent[0x86]=2;player[0x56]=2;player[0x57]=1
	player[0x14c]=int(ship_data.initial_object_flags_14c_u8);parent[0x14c]=int(Envelope.model_routing(model).initial_object_flags_14c_u8)
	parent.encode_u32(0xa0,record.decode_u32(4))
	player.encode_s64(0x138,int(ship_data.f1533_radii.outer_s64));player.encode_s64(0x140,int(ship_data.f1533_radii.inner_s64))
	parent.encode_s64(0x138,str(mapped.parent_outer_radius_s64_hex).hex_decode().decode_s64(0));parent.encode_s64(0x140,str(mapped.parent_inner_radius_s64_hex).hex_decode().decode_s64(0))
	# This is an explicit isolated initial state. It is not the prior F574
	# globals of a running source object bank, and cannot authorize F575 here.
	var initial:={"altitude_low_u32":0xffffffff,"altitude_high_s32":0,"previous_altitude_low_u32":0,"previous_altitude_high_s32":0,"collision_kind_u8":0,"collision_flags_u8":0,"volume_flags_u8":0,"collider_index_u8":0,"collision_active_u8":0,"collision_enabled_u8":0,"primitive_flags_u8":0,"recorded_intersection_raw":0,"pending_query_flag":0,"collider_parent_selected":false}
	var classified:Dictionary=Natural.new().classify_natural_player(player,parent,relative,{"graphics_level":1,"initial_globals":initial})
	if not classified.get("ok",false):return _failure(str(classified.get("error","source_natural_query_rejected")))
	var result:=_base();result.ok=true;result.reason="natural_query_diagnostic_only"
	result.body_id=str(mapped.body_id);result.body_model_index=int(mapped.body_model_index);result.parent_model_index=model
	result.parent_uid_u32=int(record.decode_u32(4));result.parent_uid_hex=_uid_hex(result.parent_uid_u32)
	result.frame_policy=str(mapped.frame_policy);result.orientation_policy="actual-phone-attitude-source-bodyfixed-Q31-local-yaw-pi-v1"
	result.relative_position_s64_hex=str(mapped.relative_position_s64_hex);result.relative_position_s64_preview=mapped.relative_position_s64_preview.duplicate()
	result.body_inner_radius_s64_hex=str(mapped.body_inner_radius_s64_hex);result.body_outer_radius_s64_hex=str(mapped.body_outer_radius_s64_hex)
	result.body_initial_flags_14c_u8=int(player[0x14c]);result.parent_initial_flags_14c_u8=int(parent[0x14c]);result.parent_transpose_skipped_by_matching_frame=true
	result.graphics_level=1;result.return_s32=int(classified.return_s32);result.collision_kind_u8=int(classified.globals_after.collision_kind_u8)
	result.altitude_s64_hex=Envelope._hex64(int(classified.altitude_s64));result.previous_altitude_s64_hex=Envelope._hex64(int(classified.previous_altitude_s64))
	result.altitude_semantics="original-F581-source-field-not-phone-AGL";result.initial_globals_policy="isolated-explicit-low-sentinel-high-and-previous-zero-not-bank-history"
	result.global_write_keys=Array(classified.global_writes.keys());result.terrain_query_calls=int(classified.terrain_query_calls)
	result.query_iteration_count=classified.iterations.size();result.child_probe_count=maxi(0,classified.iterations.size()-1)
	result.query_trace=[]
	for iteration:Dictionary in classified.iterations:
		var item:Dictionary={}
		for key:String in ["child_index","branch","vector_scale_s32","threshold_s32","distance_s32","f579_return_s32","query_result_raw"]:
			if iteration.has(key):item[key]=iteration[key]
		result.query_trace.append(item)
	result.source_sha256=SOURCE_SHA;result.metadata_sha256=DATA_SHA;result.raw_kernel_contract=Natural.CONTRACT
	result.flags2_means_landing_hit=false;result.terrain_collision_kind_changed=false
	return Envelope._plain(result)
