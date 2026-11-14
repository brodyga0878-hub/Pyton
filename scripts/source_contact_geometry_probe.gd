extends RefCounted
# Explicit paused inspection. One original ordered F576 classification supplies
# each leaf; this observer never publishes terrain or applies F575/F953.
const Natural=preload("res://scripts/source_natural_contact.gd")
const Footprint=preload("res://scripts/source_natural_footprint_probe.gd")
const SurfaceBridge=preload("res://scripts/source_natural_surface_bridge.gd")
const Trace=preload("res://scripts/source_terrain_query_trace.gd")
const ContactFrame=preload("res://scripts/source_terrain_query_frame.gd")
const Geometry=preload("res://scripts/source_native_contact_geometry.gd")
const RenderFrame=preload("res://scripts/source_surface_render_state.gd")
const Units=preload("res://scripts/source_units.gd")
const CONTRACT:="source-contact-frame-and-native-leaf-readonly-probe-v1"
const MAX_VOLUMES:=3

static func _base(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"source_contract":CONTRACT,"diagnostic_only":true,"response_applied":false,"live_response_enabled":false,"whole_mesh_certified":false,"ordinary_surface_replaced":false,"source_object_bank_present":false,"full_F569":false,"full_F570":false,"original_F575_dispatch_executed":false,"query_context":{},"context_binding_sha256":"","visited_volume_count":0,"total_volume_count":0,"terrain_query_count":0,"terrain_query_count_scope":"original_F576_walk_only","geometry_certificate_build_count":0,"geometry_packet_count":0,"blocked_frame_count":0,"selected_child_index":-1,"f576_return_s32":-1,"collision_kind_u8":0,"volumes":[]}
static func _hex32(values:Variant)->String:
	var flat:Array=[]
	for value:Variant in values:
		if value is Array or value is PackedInt64Array:
			for component:Variant in value:flat.append(int(component))
		else:flat.append(int(value))
	var raw:=PackedByteArray();raw.resize(flat.size()*4)
	for index in range(flat.size()):raw.encode_s32(index*4,Trace._s32(flat[index]))
	return raw.hex_encode()
static func _frame_report(frame:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in ["ok","reason","model_index","vector_scale_s32","xy_rotation_taken","yz_rotation_taken","antiparallel_axis_degeneracy","mapping_admissible","frame_matches_immutable_point","source_qorigin_delta_nonwrapping"]:
		if frame.has(key):result[key]=frame[key]
	for key:String in ["observer_model_local_raw","origin_model_raw","center_before_rotation_raw","rotation_q31_raw","query_matrix_raw","query_center_raw","working_difference_raw","source_qorigin_delta_raw","center_minus_rotated_difference_raw","q31_floor_nonoddness_raw","T_D","model_vertices_raw"]:
		if frame.has(key):result[key+"_s32_hex"]=_hex32(frame[key])
	for key:String in ["linear_model_to_query_rows_f64","linear_query_to_model_rows_f64"]:
		if frame.has(key):result[key+"_hex"]=SurfaceBridge._floats_hex(PackedFloat64Array(frame[key]))
	if frame.has("source_quantum_raw_s64"):result["source_quantum_raw_s64_hex"]=SurfaceBridge._hex64(int(frame.source_quantum_raw_s64))
	var delta:Variant=frame.get("source_qorigin_delta_raw")
	if delta is PackedInt64Array and delta.size()==3:
		result["actual_observer_equals_query_origin"]=frame.get("mapping_admissible",false) and frame.get("source_qorigin_delta_nonwrapping",false) and delta[0]==0 and delta[1]==0 and delta[2]==0
	var unwrapped:Variant=frame.get("source_qorigin_delta_unwrapped_raw")
	if unwrapped is PackedInt64Array and unwrapped.size()==3:
		result["source_qorigin_delta_unwrapped_s64_hex"]=SurfaceBridge._vector_hex(unwrapped)
		var length:=sqrt(float(unwrapped[0])*unwrapped[0]+float(unwrapped[1])*unwrapped[1]+float(unwrapped[2])*unwrapped[2])
		result["query_origin_unwrapped_offset_m"]=length*float(frame.get("source_quantum_raw_s64",0))*Units.METRES_PER_RAW
	return result
static func _phone_frame(frame:Dictionary,operands:Dictionary)->Dictionary:
	var values:Array=[]
	for axis:Vector3 in [frame.basis.x,frame.basis.y,frame.basis.z]:
		for component:float in [axis.x,axis.y,axis.z]:values.append(component)
	return {"basis_f64":values,"radius_m":float(frame.globe.radius),"source_uid_u32":int(frame.record.decode_u32(4)),"source_model_index":int(frame.model),"latitude":float(frame.globe.latitude),"longitude":float(frame.globe.longitude),"parent_frame_policy":"isolated-matching-bodyfixed-parent-q31","source_body_parent_index_u8":int(operands.body[0x56]),"source_body_frame_u8":int(operands.body[0x57]),"source_parent_index_u8":int(operands.parent[0x86]),"source_parent_matrix_q31_hex":operands.parent.slice(0,36).hex_encode()}

static func sample(surface:RefCounted,ship:RefCounted,physical_gear_u16:int,context:Dictionary,event:Dictionary={})->Dictionary:
	if not SurfaceBridge._plain(context) or context.size()!=2 or not context.get("initial_globals") is Dictionary or not context.get("history_policy") is String or str(context.history_policy).is_empty() or not SurfaceBridge._history_valid(context.initial_globals):return _base("missing_or_invalid_explicit_initial_globals")
	if not Natural._whole(physical_gear_u16,0,65535):return _base("invalid_physical_gear_word")
	var prepared:=Footprint._prepare(surface,ship,event)
	if not prepared.ok:return _base(str(prepared.reason))
	var operands:=Footprint._operands(prepared,physical_gear_u16)
	if operands.is_empty():return _base("invalid_source_operand_mapping")
	var initial:=Natural._globals(context.initial_globals);var collector:=Trace.new();var classifier:=Natural.new();classifier.set("_query",collector)
	var classified:=classifier.classify_natural_player(operands.body,operands.parent,operands.relative,{"graphics_level":1,"initial_globals":initial})
	if not classified.get("ok",false):return _base(str(classified.get("error","source_classification_failed")))
	var traces:=collector.read_trace();var trace_state:=collector.trace_state()
	if classified.iterations.size()>MAX_VOLUMES or trace_state.trace_truncated:return _base("source_observation_budget_exceeded")
	var phone:=_phone_frame(prepared,operands);var result:=_base("original_frame_and_leaf_observed")
	result.ok=true;result.visited_volume_count=classified.iterations.size();result.total_volume_count=prepared.shape.children.size()+1;result.terrain_query_count=int(classified.terrain_query_calls);result.f576_return_s32=int(classified.f576_return_s32);result.collision_kind_u8=int(classified.globals_after.collision_kind_u8)
	result.selected_child_index=int(classified.iterations[-1].child_index) if result.f576_return_s32==0 else -1
	result.query_context={"body_id":str(surface.get("body_id")),"terrain_revision":str(prepared.globe.revision),"body_model_index":int(prepared.data.model_index),"parent_model_index":int(prepared.model),"parent_uid_u32":int(phone.source_uid_u32),"source_record_sha256":RenderFrame._sha(prepared.record),"original_parent_bounds_preserved":true,"original_relative_s64_hex":SurfaceBridge._vector_hex(operands.relative),"body_object_hex":operands.body.hex_encode(),"parent_object_hex":operands.parent.hex_encode(),"physical_gear_u16":physical_gear_u16,"graphics_level":1,"initial_globals":initial.duplicate(true),"history_policy":str(context.history_policy),"history_is_running_source_bank":false,"body_origin_policy":"authored-clearance-to-native-inner-radius-v1","body_origin_offset_m":float(operands.origin_offset_m),"phone_basis_f64_hex":SurfaceBridge._floats_hex(PackedFloat64Array(phone.basis_f64)),"phone_geographic_frame_f64_hex":SurfaceBridge._floats_hex(PackedFloat64Array([phone.latitude,phone.longitude,phone.radius_m]))}
	if Natural._whole(surface.get("frame_index"),0,0x7fffffff):result.query_context["surface_frame_index"]=int(surface.get("frame_index"))
	if Footprint.Phone._number(surface.get("_source_days")):result.query_context["surface_source_days"]=float(surface.get("_source_days"))
	result.context_binding_sha256=RenderFrame._sha(var_to_bytes([prepared.record,operands.body,operands.parent,operands.relative,initial,str(context.history_policy),phone]))
	var query_index:=0
	for iteration:Dictionary in classified.iterations:
		var row:Dictionary={"child_index":int(iteration.child_index),"selected_contact_volume":int(iteration.child_index)==int(result.selected_child_index),"source_branch":str(iteration.branch),"relative_before_s64_hex":str(iteration.relative_before_hex),"threshold_before_s32":int(iteration.threshold_before_s32),"threshold_scaled_s32":int(iteration.threshold_s32),"vector_scale_s32":int(iteration.vector_scale_s32),"geometry_ok":false,"geometry_reason":"source_terrain_query_not_executed","frame":{},"packet":{},"certificate":{}}
		if str(iteration.branch)=="terrain_query":
			if query_index>=traces.size():return _base("missing_original_query_trace")
			var source_frame:=ContactFrame.build(int(prepared.model),iteration.observer_model_local_raw,int(iteration.vector_scale_s32))
			row.frame=_frame_report(source_frame)
			if iteration.parent_transpose_applied:row.geometry_reason="unsupported_parent_frame_transpose"
			elif not source_frame.get("ok",false):row.geometry_reason=str(source_frame.get("reason","source_query_frame_unavailable"))
			else:
				result.geometry_certificate_build_count+=1
				var geometry:=Geometry.build(source_frame,traces[query_index],phone)
				row.geometry_ok=bool(geometry.get("ok",false));row.geometry_reason=str(geometry.get("reason","geometry_certificate_unavailable"))
				row.packet=geometry.get("packet",{});row.certificate=geometry.get("certificate",{})
				if row.geometry_ok:result.geometry_packet_count+=1
			if not row.geometry_ok:result.blocked_frame_count+=1
			query_index+=1
		result.volumes.append(row)
	if query_index!=traces.size() or query_index!=int(classified.terrain_query_calls) or query_index!=int(trace_state.query_count):return _base("original_query_count_mismatch")
	result["source_query_count_matches"]=true
	result["final_altitude_s64_hex"]=SurfaceBridge._hex64(int(classified.altitude_s64));result["final_previous_s64_hex"]=SurfaceBridge._hex64(int(classified.previous_altitude_s64))
	return SurfaceBridge._transport_guard(result)
