extends RefCounted
# Read-only diagnostics of the actual ordered F576 volume walk. Local visible
# point observations do not certify a whole mesh, a native leaf/render match,
# a running source object bank, or permission to apply a candidate response.
const Natural=preload("res://scripts/source_natural_contact.gd")
const Pipeline=preload("res://scripts/source_natural_contact_pipeline.gd")
const SurfaceBridge=preload("res://scripts/source_natural_surface_bridge.gd")
const Phone=preload("res://scripts/source_surface_contact_bridge.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const ContactTerrain=preload("res://scripts/source_contact_surface_terrain.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Frame=preload("res://scripts/source_surface_render_state.gd")
const Field=preload("res://scripts/source_terrain_contact_field.gd")
const Trace=preload("res://scripts/source_terrain_query_trace.gd")
const CONTRACT:="source-f576-ordered-volume-footprint-readonly-v1"
const MAX_VOLUMES:=3

static func _base(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"source_contract":CONTRACT,"diagnostic_only":true,"response_applied":false,"live_response_enabled":false,"source_geometry_identity_verified":false,"whole_mesh_certified":false,"full_F569":false,"full_F570":false,"source_object_bank_present":false,"query_context":{},"context_binding_sha256":"","visited_volume_count":0,"total_volume_count":0,"selected_child_index":-1,"last_visited_child_index":-1,"f576_return_s32":-1,"collision_kind_u8":0,"volumes":[],"response_preview":{"available":false,"reason":"query_unavailable","preview_only":true,"response_applied":false}}
static func _hex32(values:Variant)->String:
	var flat:Array=[]
	for value:Variant in values:
		if value is Array or value is PackedInt64Array:
			for word:Variant in value:flat.append(int(word))
		else:flat.append(int(value))
	if flat.size()>64:return ""
	var raw:=PackedByteArray();raw.resize(flat.size()*4)
	for index in range(flat.size()):raw.encode_s32(index*4,Point._s32(flat[index]))
	return raw.hex_encode()
static func _vector(hex:String)->PackedInt64Array:
	var raw:=hex.hex_decode()
	if raw.size()!=24:return PackedInt64Array()
	return PackedInt64Array([raw.decode_s64(0),raw.decode_s64(8),raw.decode_s64(16)])
static func _signed_words(globals:Dictionary,prefix:String)->int:
	return (int(globals[prefix+"_high_s32"])<<32)|int(globals[prefix+"_low_u32"])
static func _prepare(surface:RefCounted,ship:RefCounted,event:Dictionary)->Dictionary:
	if surface==null or ship==null or surface.get("active")!=true:return {"ok":false,"reason":"outside_active_source_surface"}
	var globe:Variant=surface.get("globe")
	if not globe is Terrain or globe.get("configured_ok")!=true or globe.get("revision") not in [Terrain.REVISION_NAME,ContactTerrain.CONTACT_REVISION]:return {"ok":false,"reason":"unsupported_source_surface_frame"}
	if not surface.get("city_data") is Dictionary or not surface.city_data.is_empty() or surface.get("underground")!=null:return {"ok":false,"reason":"city_or_underground_outside_natural_footprint_scope"}
	for key:Variant in event:
		if key not in ["kind","candidate_position"]:return {"ok":false,"reason":"unsupported_diagnostic_event_field"}
	if event.get("kind","terrain") not in ["terrain","manual"]:return {"ok":false,"reason":"unsupported_diagnostic_event_kind"}
	var candidate:=SurfaceBridge._position(event.get("candidate_position",ship.get("position")))
	if not candidate.ok or not ship.get("position") is Vector3 or not ship.position.is_finite() or not ship.get("velocity") is Vector3 or not ship.velocity.is_finite() or not ship.get("attitude") is Quaternion or not ship.attitude.is_finite() or ship.attitude.length_squared()<0.0001 or not ship.has_method("profile"):return {"ok":false,"reason":"invalid_phone_ship_pose"}
	var record:Variant=globe.get("source_record")
	if not record is PackedByteArray or record.size()!=68:return {"ok":false,"reason":"missing_original_parent_record"}
	var model:=int(record.decode_u16(12))
	if model<117 or model>133 or int(globe.get("source_model_index"))!=model:return {"ok":false,"reason":"unsupported_natural_parent_model"}
	if not Phone._number(globe.get("latitude")) or not Phone._number(globe.get("longitude")) or not Phone._number(globe.get("radius")) or float(globe.radius)<=0:return {"ok":false,"reason":"invalid_geographic_frame"}
	var basis:Basis=globe.basis_at(globe.latitude,globe.longitude)
	var position:=Phone.to_bodyfixed_point(basis,float(globe.radius),candidate.value);var velocity:=Phone.to_bodyfixed_vector(basis,ship.velocity)
	if position.size()!=3 or velocity.size()!=3:return {"ok":false,"reason":"invalid_bodyfixed_phone_adapter"}
	if not ship.get("ship_id") is String:return {"ok":false,"reason":"invalid_source_ship_id"}
	var data:=Phone.source_ship_data(ship.ship_id);var shape:=Natural.ship_model(int(data.get("model_index",-1)))
	if not data.get("ok",false) or shape.is_empty() or not surface.has_method("clearance") or not Phone._number(surface.clearance(ship)):return {"ok":false,"reason":"unverified_ship_or_clearance"}
	var clearance:float=surface.clearance(ship)
	if clearance<=0:return {"ok":false,"reason":"invalid_phone_clearance"}
	return {"ok":true,"globe":globe,"record":record.duplicate(),"model":model,"basis":basis,"input_position":candidate.value,"input_velocity":ship.velocity,"input_attitude":ship.attitude,"source_position":position,"source_velocity":velocity,"data":data,"shape":shape,"clearance":clearance}
static func _operands(frame:Dictionary,gear:int)->Dictionary:
	var point:PackedFloat64Array=frame.source_position.duplicate();var offset:=int(frame.data.inner_radius_raw)*Phone.Units.METRES_PER_RAW-float(frame.clearance)
	for axis in range(3):point[axis]+=float(frame.basis.y[axis])*offset
	var relative:=SurfaceBridge._raw_point(point);var matrix:=Phone.contact_orientation_q31(frame.basis,frame.input_attitude)
	if relative.size()!=3 or matrix.size()!=9:return {}
	var body:=PackedByteArray();body.resize(338);body.fill(0);var parent:=body.duplicate()
	for index in range(9):body.encode_s32(index*4,matrix[index])
	for axis in range(3):parent.encode_s32(axis*16,0x7fffffff)
	body.encode_u32(0x82,int(frame.data.model_index));body[0x86]=1;body[0x56]=2;body[0x57]=1;body[0x14c]=int(frame.shape.initial_object_flags_14c_u8)
	parent[0x86]=2;parent.encode_u32(0xa0,frame.record.decode_u32(4))
	var initialized:=Ground.initialize_model(parent,int(frame.model))
	if initialized.is_empty():return {}
	parent=initialized.object
	body.encode_u16(0x9e,gear);body.encode_u16(0xe4,(int(frame.data.mass_s16)*4)&65535);body.encode_s64(0x138,int(frame.data.outer_radius_raw));body.encode_s64(0x140,int(frame.data.inner_radius_raw))
	for axis in range(3):
		body.encode_s64(0x3e+axis*8,relative[axis]);var units:=float(frame.source_velocity[axis])/Phone.Physics.VELOCITY_UNIT_MPS;var integer:=floori(units);var fraction:=roundi((units-float(integer))*65536.0)
		if fraction==65536:integer+=1;fraction=0
		if not Phone._whole(integer,-2147483648,2147483647):return {}
		body.encode_s32(0x8c+axis*4,integer);body.encode_u16(0xec+axis*2,fraction)
	return {"body":body,"parent":parent,"relative":relative,"origin_offset_m":offset}
static func _provider_hash(surface:RefCounted)->String:
	var provider:Variant=surface.get("source_render_state")
	if not provider is RefCounted or provider.get_script()!=Frame:return ""
	return Frame._sha(var_to_bytes([provider.source_key,provider.core_width,provider.core_cells,provider.core_offset,provider.get("_frame"),provider.get("_vertices"),provider.get("_grid_x"),provider.get("_grid_z")]))
static func _visible(frame:Dictionary,surface:RefCounted,local:PackedFloat64Array)->Dictionary:
	var result:={"visible_status":"published_provider_unavailable","visible_point_boundary_certified":false,"source_geometry_identity_verified":false}
	var provider:Variant=surface.get("source_render_state")
	if not provider is RefCounted:return result
	var copy:=SurfaceBridge._clone_provider(provider)
	if copy==null:return result
	var hit:Dictionary=copy.height_at(frame.globe,local[0],local[2])
	if hit.is_empty():result.visible_status="footprint_outside_published_core";return result
	result["visible_height_f64_hex"]=SurfaceBridge._floats_hex(PackedFloat64Array([float(hit.height)]));result["visible_height_m"]=float(hit.height);result["visible_triangle_index"]=int(hit.triangle_index)
	var point:=PackedFloat64Array();var up:=float(frame.globe.radius)+float(hit.height)
	for axis in range(3):point.append(float(frame.basis.x[axis])*local[0]+float(frame.basis.y[axis])*up+float(frame.basis.z[axis])*local[2])
	var raw:=SurfaceBridge._raw_point(point)
	if raw.size()!=3:result.visible_status="visible_point_out_of_source_domain";return result
	result["visible_point_s64_hex"]=SurfaceBridge._vector_hex(raw)
	var model:=Natural.parent_model(int(frame.model));var scale:=maxi(0,Gravity._vec64_msb(raw)-28);var observer:=PackedInt64Array()
	for value:int in raw:observer.append(Point._s32(Point.shift_int64(value,-scale)))
	var minimum:=int(model.mesh_zoom)-23
	if scale<minimum:
		for axis in range(3):observer[axis]>>=(minimum-scale)&31
		scale=minimum
	var kernel:=Point.new();var query_frame:=kernel.frame_raw(int(frame.model),observer,scale)
	if query_frame.is_empty():result.visible_status="visible_source_frame_undefined";return result
	var radii:=Phone.descriptor_radii(model.descriptor);var distance:=int(query_frame.query_center_raw[2]);var outer:=Point._s32(Point.shift_int64(int(radii.outer_raw),-scale));var inner:=Point._s32(Point.shift_int64(int(radii.inner_raw),-scale))
	if Point._s32(distance-outer)>=0 or Point._s32(distance-inner)<=0:result.visible_status="visible_point_outside_original_terrain_bounds";return result
	var query:=kernel.kernel.query_raw(frame.record.decode_u32(4),int(query_frame.query_style_raw),query_frame.query_matrix_raw,query_frame.query_center_raw,int(query_frame.query_limit_raw),1,query_frame.features)
	if query.is_empty() or int(query.query_result_raw)>=int(query_frame.query_limit_raw) or int(query.pending_query_flag)!=0:result.visible_status="visible_signed_query_undefined_or_capped";return result
	var residual:=Point.shift_int64(int(query.query_result_raw),scale);result["visible_source_residual_s64_hex"]=SurfaceBridge._hex64(residual);result["visible_source_residual_m"]=residual*Phone.Units.METRES_PER_RAW;result["visible_source_vector_scale_s32"]=scale
	if residual==0:result.visible_point_boundary_certified=true;result.visible_status="exact_visible_f581_zero";return result
	var length:=sqrt(point[0]*point[0]+point[1]*point[1]+point[2]*point[2]);var direction:=PackedInt64Array()
	for value:float in point:direction.append(clampi(roundi(value/length*2147483647.0),-2147483647,2147483647))
	var boundary:=Field.new().sample_radial(frame.record,direction,1)
	if boundary.get("ok",false) and boundary.get("certified")==true and boundary.get("status")=="adjacent_sign_boundary" and boundary.position_raw==raw and boundary.source_bounds.terrain_query_eligible==true and int(boundary.residual_raw_s64)==residual:
		result.visible_point_boundary_certified=true;result.visible_status="exact_adjacent_boundary_raw_identity"
	else:result.visible_status="visible_point_differs_from_signed_boundary"
	return result
static func _trace_metadata(row:Dictionary,volume:Dictionary,record:PackedByteArray)->Dictionary:
	var result:={"source_trace_status":"unavailable","source_winning_leaf_observed":false,"source_geometry_identity_verified":false}
	if row.is_empty():return result
	var output:Variant=row.get("result",{})
	if not row.get("query_ok",false) or not output is Dictionary or int(row.get("source_uid_u32",-1))!=int(record.decode_u32(4)) or int(row.get("graphics_level_s32",-1))!=1 or int(row.get("style_s32",-1))!=int(volume.query_style_raw) or int(row.get("query_limit_s32",0))!=int(volume.query_limit_raw) or int(output.get("query_result_raw",2147483647))!=int(volume.query_result_raw) or row.get("query_matrix_raw")!=volume.query_matrix_raw or row.get("query_center_raw")!=volume.query_center_raw:
		result.source_trace_status="trace_query_identity_mismatch";return result
	result.source_trace_status="exact_observed_query_result";result["source_query_matrix_s32_hex"]=_hex32(row.query_matrix_raw);result["source_query_center_s32_hex"]=_hex32(row.query_center_raw)
	var triangle:Variant=row.get("winning_triangle",{})
	if not triangle is Dictionary or triangle.is_empty():return result
	result.source_winning_leaf_observed=true;result["winning_leaf_coordinate_domain"]="f1876_query_frame_not_phone_mesh"
	for pair:Array in [["positions_raw","winning_positions_s32_hex"],["normals_raw","winning_normals_s32_hex"],["sar_positions_raw","winning_sar_positions_s32_hex"],["vertex_ids_s32","winning_vertex_ids_s32_hex"],["depths_s32","winning_depths_s32_hex"],["heights_s32","winning_heights_s32_hex"],["lands_s32","winning_lands_s32_hex"]]:
		if triangle.has(pair[0]):result[pair[1]]=_hex32(triangle[pair[0]])
	result["winning_sar_shift_s32"]=int(triangle.get("sar_shift_s32",0));result["winning_leaf_depth_s32"]=int(triangle.get("leaf_depth_s32",0));result["winning_recorded_intersection_s32"]=int(triangle.get("recorded_intersection_raw",0))
	var fractions:Array=[]
	for item:Dictionary in triangle.get("plane_fraction_calls",[]):
		if fractions.size()>=6:break
		fractions.append(int(item.numerator_s32));fractions.append(int(item.denominator_s32));fractions.append(int(item.fraction_s32))
	result["winning_plane_fraction_s32_flat"]=fractions
	return result
static func _history_step(state:Dictionary,iteration:Dictionary)->Dictionary:
	# F581 copies retained altitude into previous even when F1876 reaches its
	# limit. A query call alone therefore does not prove a fresh previous word.
	var result:=state.duplicate(true);result["fresh"]=false
	if str(iteration.branch)!="terrain_query":result["update"]="preserved_without_terrain_query";return result
	if int(iteration.query_result_raw)<int(iteration.query_limit_raw):
		result.altitude=Point.shift_int64(int(iteration.query_result_raw),int(iteration.vector_scale_s32));result.altitude_origin="fresh_query_volume_"+str(iteration.child_index);result.fresh=true;result["update"]="fresh_current_query"
	else:result["update"]="query_capped_copies_retained_altitude"
	result.previous=result.altitude;result.previous_origin=result.altitude_origin
	if int(iteration.f579_return_s32)==0:result.altitude=0;result.altitude_origin="zeroed_after_query_hit"
	return result
static func _preview(frame:Dictionary,operands:Dictionary,initial:Dictionary,classified:Dictionary,provenance:String)->Dictionary:
	var result:={"available":false,"reason":"no_native_kind1_contact","preview_only":true,"response_applied":false,"damage_applied":false}
	if int(classified.f576_return_s32)!=0 or int(classified.globals_after.collision_kind_u8)!=1:return result
	var context:={"initial_globals":initial,"player_object_index_u32":1,"graphics_level":1}
	if not Pipeline._valid_context(operands.body,operands.parent,operands.relative,context):result.reason="unsupported_raw_continuation_context";return result
	var response:=Pipeline.new()._dispatch_classification(operands.body,operands.parent,operands.relative,context,classified)
	if not response.get("ok",false):result.reason=str(response.get("error","continuation_rejected"));return result
	result.available=true;result.reason="bounded_source_continuation_evaluated_on_copies";result["source_contract"]=Pipeline.CONTRACT;result["relative_operand_s64_hex"]=SurfaceBridge._vector_hex(operands.relative);result["previous_operand_s64_hex"]=SurfaceBridge._hex64(int(classified.previous_altitude_s64));result["previous_provenance"]=provenance
	result["source_landing_accepted"]=bool(response.landing_accepted);result["source_return_flags_u8"]=int(response.return_flags_u8);result["normal_q31_s32_hex"]=_hex32(response.response.normal_q31);result["f953_requests_preview"]=response.damage_calls.duplicate(true);result["body_after_sha256"]=Frame._sha(response.body_after)
	var delta:=PackedInt64Array()
	for axis in range(3):delta.append(response.body_after.decode_s64(0x3e+axis*8)-operands.body.decode_s64(0x3e+axis*8))
	result["body_position_delta_s64_hex"]=SurfaceBridge._vector_hex(delta)
	var mapped:=Phone._pose_delta(frame,operands.body,response.body_after)
	if mapped.get("ok",false):
		result["phone_position_preview"]=[mapped.position.x,mapped.position.y,mapped.position.z];result["phone_velocity_preview"]=[mapped.velocity.x,mapped.velocity.y,mapped.velocity.z];result["phone_orientation_projection_policy"]=str(mapped.orientation_projection_policy)
	else:result["phone_projection_blocked_reason"]=str(mapped.get("reason","projection_unavailable"))
	return result
static func sample(surface:RefCounted,ship:RefCounted,physical_gear_u16:int,context:Dictionary,event:Dictionary={})->Dictionary:
	if not SurfaceBridge._plain(context) or context.size()!=2 or not context.get("initial_globals") is Dictionary or not context.get("history_policy") is String or str(context.history_policy).is_empty() or not SurfaceBridge._history_valid(context.initial_globals):return _base("missing_or_invalid_explicit_initial_globals")
	if not Phone._whole(physical_gear_u16,0,65535):return _base("invalid_physical_gear_word")
	var frame:=_prepare(surface,ship,event)
	if not frame.ok:return _base(str(frame.reason))
	var operands:=_operands(frame,physical_gear_u16)
	if operands.is_empty():return _base("invalid_source_operand_mapping")
	var initial:=Natural._globals(context.initial_globals);var classifier:=Natural.new();var collector:=Trace.new()
	collector.reset_trace();classifier._query=collector
	var classified:=classifier.classify_natural_player(operands.body,operands.parent,operands.relative,{"graphics_level":1,"initial_globals":initial})
	if not classified.get("ok",false):return _base(str(classified.get("error","raw_natural_query_failed")))
	if classified.iterations.size()>MAX_VOLUMES:return _base("volume_report_budget_exceeded")
	var source_rows:Array=collector.read_trace();var trace_state:=collector.trace_state();var query_index:=0
	var result:=_base("ordered_source_footprints_observed_only");result.ok=true;result.visited_volume_count=classified.iterations.size();result.total_volume_count=frame.shape.children.size()+1;result.last_visited_child_index=int(classified.iterations[-1].child_index);result.selected_child_index=result.last_visited_child_index if int(classified.f576_return_s32)==0 else -1;result.f576_return_s32=int(classified.f576_return_s32);result.collision_kind_u8=int(classified.globals_after.collision_kind_u8)
	var provider_hash:=_provider_hash(surface);var basis_values:=PackedFloat64Array()
	for axis:Vector3 in [frame.basis.x,frame.basis.y,frame.basis.z]:
		for component:float in [axis.x,axis.y,axis.z]:basis_values.append(component)
	var frame_hex:=SurfaceBridge._floats_hex(PackedFloat64Array([float(frame.globe.latitude),float(frame.globe.longitude),float(frame.globe.radius)]))+SurfaceBridge._floats_hex(basis_values)
	result.context_binding_sha256=Frame._sha(var_to_bytes([frame.record,operands.body,operands.parent,operands.relative,initial,str(context.history_policy),frame_hex,provider_hash]))
	result.query_context={"terrain_revision":str(frame.globe.revision),"body_id":str(surface.get("body_id")),"body_model_index":int(frame.data.model_index),"parent_model_index":int(frame.model),"parent_uid_u32":int(frame.record.decode_u32(4)),"source_record_sha256":Frame._sha(frame.record),"original_parent_bounds_preserved":true,"physical_gear_u16":physical_gear_u16,"graphics_level":1,"history_policy":str(context.history_policy),"history_is_running_source_bank":false,"initial_globals":initial.duplicate(true),"caller_resets_executed":false,"original_relative_s64_hex":SurfaceBridge._vector_hex(operands.relative),"source_orientation_q31_hex":operands.body.slice(0,36).hex_encode(),"phone_frame_f64_hex":frame_hex,"body_origin_policy":"authored-clearance-to-native-inner-radius-v1","body_origin_offset_m":float(operands.origin_offset_m),"provider_geometry_sha256":provider_hash,"trace_available":true,"trace_truncated":bool(trace_state.trace_truncated),"trace_max_query_count":int(trace_state.max_trace_queries),"terrain_query_count":int(classified.terrain_query_calls),"trace_query_count":source_rows.size(),"trace_executed_query_count":int(trace_state.query_count)}
	if Natural._whole(surface.get("frame_index"),0,0x7fffffff):result.query_context["surface_frame_index"]=int(surface.get("frame_index"))
	if Phone._number(surface.get("_source_days")):result.query_context["surface_source_days"]=float(surface.get("_source_days"))
	var state:={"altitude":_signed_words(initial,"altitude"),"previous":_signed_words(initial,"previous_altitude"),"altitude_origin":"supplied_initial_altitude","previous_origin":"supplied_initial_previous"};var inverse:=Frame._inverse_rows(frame.basis);var all_visible:=true
	for iteration:Dictionary in classified.iterations:
		var raw:=_vector(str(iteration.relative_before_hex));var local:=PackedFloat64Array();var metres:=PackedFloat64Array()
		for value:int in raw:metres.append(float(value)*Phone.Units.METRES_PER_RAW)
		for axis in range(3):local.append(inverse[axis*3]*metres[0]+inverse[axis*3+1]*metres[1]+inverse[axis*3+2]*metres[2])
		local[1]-=float(frame.globe.radius)
		var back:=PackedFloat64Array()
		for axis in range(3):back.append(float(frame.basis.x[axis])*local[0]+float(frame.basis.y[axis])*(float(frame.globe.radius)+local[1])+float(frame.basis.z[axis])*local[2])
		var row:={"child_index":int(iteration.child_index),"selected_contact_volume":int(iteration.child_index)==int(result.selected_child_index),"relative_before_s64_hex":str(iteration.relative_before_hex),"relative_truncated_s64_hex":str(iteration.relative_truncated_hex),"threshold_before_s32":int(iteration.threshold_before_s32),"threshold_scaled_s32":int(iteration.threshold_s32),"vector_scale_s32":int(iteration.vector_scale_s32),"parent_transpose_applied":bool(iteration.parent_transpose_applied),"source_branch":str(iteration.branch),"f579_return_s32":int(iteration.f579_return_s32),"local_point_f64_hex":SurfaceBridge._floats_hex(local),"local_x":local[0],"local_y":local[1],"local_z":local[2],"raw_inverse_forward_roundtrip_exact":SurfaceBridge._raw_point(back)==raw,"altitude_before_s64_hex":SurfaceBridge._hex64(int(state.altitude)),"previous_before_s64_hex":SurfaceBridge._hex64(int(state.previous)),"terrain_query_executed":int(iteration.terrain_query_calls)>0}
		state=_history_step(state,iteration);row["source_previous_fresh"]=bool(state.get("fresh",false));row["source_previous_update"]=str(state.update)
		if str(iteration.branch)=="terrain_query":
			row["source_query_result_s32"]=int(iteration.query_result_raw);row["source_query_limit_s32"]=int(iteration.query_limit_raw)
			row.merge(_trace_metadata(source_rows[query_index] if query_index<source_rows.size() else {},iteration,frame.record));query_index+=1
		else:
			row["source_trace_status"]="not_executed_"+str(iteration.branch)
		row["altitude_after_s64_hex"]=SurfaceBridge._hex64(int(state.altitude));row["previous_after_s64_hex"]=SurfaceBridge._hex64(int(state.previous));row["previous_provenance"]=str(state.previous_origin)
		if not row.raw_inverse_forward_roundtrip_exact or row.parent_transpose_applied:
			row["visible_status"]="unproved_source_to_local_frame";row["visible_point_boundary_certified"]=false;all_visible=false
		else:
			var visible:=_visible(frame,surface,local);row.merge(visible);all_visible=all_visible and bool(visible.visible_point_boundary_certified)
		result.volumes.append(row)
	if int(state.altitude)!=int(classified.altitude_s64) or int(state.previous)!=int(classified.previous_altitude_s64):return _base("per_volume_source_history_reconstruction_mismatch")
	result["all_visited_visible_points_boundary_certified"]=all_visible;result["trace_query_count_matches"]=not bool(trace_state.trace_truncated) and query_index==source_rows.size() and query_index==int(classified.terrain_query_calls) and query_index==int(trace_state.query_count);result["final_altitude_s64_hex"]=SurfaceBridge._hex64(int(state.altitude));result["final_previous_s64_hex"]=SurfaceBridge._hex64(int(state.previous))
	result.response_preview=_preview(frame,operands,initial,classified,str(state.previous_origin))
	return SurfaceBridge._transport_guard(result)
