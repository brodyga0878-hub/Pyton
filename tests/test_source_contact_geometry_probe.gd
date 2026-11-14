extends "res://tests/test_source_natural_footprint_probe.gd"
const GeometryProbe=preload("res://scripts/source_contact_geometry_probe.gd")
const GEOMETRY_REPORT:="res://build/current-test-reports/source-contact-geometry-probe.json"
var geometry_evidence:Array=[]
var geometry_counts:={"native_actors":0,"visited_volumes":0,"native_leaf_packets":0,"blocked_pole_frames":0}

func observe_geometry(ctx:Dictionary,gear_word:=0)->Dictionary:
	var before:=protected_state();var input:=var_to_bytes(ctx)
	var report:=GeometryProbe.sample(surface,ship,gear_word,ctx)
	check(protected_state()==before and input==var_to_bytes(ctx),"Native geometry inspection preserves flight, physical provider, terrain cache and caller history")
	check(report.diagnostic_only and not report.response_applied and not report.live_response_enabled and not report.whole_mesh_certified and not report.ordinary_surface_replaced,"A certified leaf preview never becomes a live terrain or whole-mesh contact certificate")
	check(not report.full_F569 and not report.full_F570 and not report.source_object_bank_present and not report.original_F575_dispatch_executed,"Frame/leaf inspection does not execute a source bank or terminal response")
	check(Bridge._plain(report),"Geometry report uses finite bounded JSON primitives")
	var diagnostics:=Diagnostics.new();var envelope:={"context":{"flight":{"last_contact_geometry":report}}}
	var transported:Dictionary=diagnostics._safe_value(envelope,0);diagnostics.free()
	check(transported==envelope and not JSON.stringify(transported).contains("[depth limit]"),"Actual collector retains every frame, packet and interval field at the real report depth")
	return report
func native_geometry_snapshots()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(NATIVE_FIXTURE))
	for actor:Dictionary in fixture.actor_cases:
		if int(actor.parent_model)!=118 or not actor.get("euler_radians") is Array:continue
		ship.ship_id=str(actor.ship_id);ship.velocity=Vector3.ZERO;ship.attitude=Quaternion.from_euler(Vector3(actor.euler_radians[0],actor.euler_radians[1],actor.euler_radians[2]))
		var data:=Phone.source_ship_data(ship.ship_id);var inner:=int(data.inner_radius_raw)*Phone.Units.METRES_PER_RAW
		ship.position=Vector3(0,accepted_height+surface.clearance(ship)-inner+float(actor.source_center_height_m),0)
		var report:=observe_geometry(explicit_context(actor.context.initial_globals));var expected:Dictionary=actor.expected
		check(report.ok and report.source_query_count_matches,str(actor.id)+" completes one actual ordered classification with a matching trace count")
		if not report.ok:continue
		geometry_counts.native_actors+=1;geometry_counts.visited_volumes+=report.volumes.size()
		check(report.query_context.original_relative_s64_hex==actor.relative_before_hex and int(report.f576_return_s32)==int(expected.canonical.f576_return_s32) and int(report.collision_kind_u8)==int(expected.canonical.globals.collision_kind_u8),str(actor.id)+" retains the independently executed native observer and classification")
		check(int(report.selected_child_index)==int(expected.selected_child_index) and report.final_previous_s64_hex==expected.selected_previous_altitude_s64_hex,str(actor.id)+" retains native first-hit selection and signed64 history")
		for index in range(report.volumes.size()):
			var row:Dictionary=report.volumes[index];var native:Dictionary=expected.volume_trace[index]
			check(int(row.child_index)==int(native.child_index) and row.relative_before_s64_hex==native.relative_before_hex and int(row.vector_scale_s32)==int(native.vector_scale_s32),str(actor.id)+" volume origin/order/scale equal native")
			if not native.query.executed:
				check(not row.geometry_ok and row.packet.is_empty() and row.geometry_reason=="source_terrain_query_not_executed",str(actor.id)+" coarse gates cannot invent an F1876 leaf")
				continue
			check(row.geometry_ok,str(actor.id)+" regular source frame yields a real native leaf projection packet: "+str(row.geometry_reason))
			if not row.geometry_ok:continue
			geometry_counts.native_leaf_packets+=1
			check(row.certificate.ok and row.certificate.source_query_identity_verified and row.certificate.raw_leaf_identity_verified and row.certificate.original_integer_intersection_replayed and row.certificate.render_projection_verified,str(actor.id)+" certificate binds source query, actual leaf, unchanged integer arithmetic and declared render projection")
			check(not row.certificate.whole_mesh_certified and not row.certificate.live_response_enabled,str(actor.id)+" local derivation does not certify the current ordinary surface")
			check(str(row.packet.local_vertices_f64_hex).length()==144 and str(row.packet.local_vertices_f32_hex).length()==72 and row.packet.indices.size()==3 and row.packet.indices[0]==0 and row.packet.indices[1]==1 and row.packet.indices[2]==2,str(actor.id)+" packet retains all three actual local vertices in explicitIEEE64/32 form")
			check(row.certificate.packet_sha256==JSON.stringify(row.packet,"",true).sha256_text(),str(actor.id)+" JSON transport retains the exact canonical packet seal")
		geometry_evidence.append({"case":str(actor.id),"selected_child_index":report.selected_child_index,"visited":report.visited_volume_count,"packets":report.geometry_packet_count,"binding":report.context_binding_sha256})
	check(int(geometry_counts.native_actors)==56 and int(geometry_counts.native_leaf_packets)>0,"All56 independently observed modern actors produce bounded source geometry observations")
func pole_and_scope_guards()->void:
	ship.ship_id="cobra";ship.velocity=Vector3.ZERO;ship.attitude=Quaternion.IDENTITY
	var model:=Natural.parent_model(118);var radii:=Phone.descriptor_radii(model.descriptor);var data:=Phone.source_ship_data(ship.ship_id)
	surface.globe.latitude=0;surface.globe.longitude=-PI*0.5
	var radius:=float((int(radii.outer_raw)+int(radii.inner_raw))/2)*Phone.Units.METRES_PER_RAW
	ship.position=Vector3(0,radius-float(surface.globe.radius)-int(data.inner_radius_raw)*Phone.Units.METRES_PER_RAW+surface.clearance(ship),0)
	var report:=observe_geometry(explicit_context())
	check(report.ok and int(report.blocked_frame_count)>0,"Exact source+Z degeneracy is retained as an explicit blocked frame")
	for row:Dictionary in report.get("volumes",[]):
		if row.geometry_reason=="native_antiparallel_axis_frame":
			geometry_counts.blocked_pole_frames+=1
			check(not row.geometry_ok and row.packet.is_empty() and row.frame.antiparallel_axis_degeneracy,"The original skipped rotations are not repaired by a global sign flip or hidden displacement")
	check(int(geometry_counts.blocked_pole_frames)>0,"A real post-F579 observer exercises the blocked antiparallel source branch")
	var before:=protected_state();var bad:Dictionary=GeometryProbe.sample(surface,ship,-1,explicit_context())
	check(not bad.ok and bad.reason=="invalid_physical_gear_word" and protected_state()==before,"Malformed gear is rejected atomically before observation")
	bad=GeometryProbe.sample(surface,ship,0,{})
	check(not bad.ok and bad.reason=="missing_or_invalid_explicit_initial_globals" and protected_state()==before,"Missing source-global history cannot become an implicit live caller")
	surface.active=false;bad=GeometryProbe.sample(surface,ship,0,explicit_context());surface.active=true
	check(not bad.ok and bad.reason=="outside_active_source_surface","An inactive source surface has no geometry snapshot")
	geometry_evidence.append({"case":"actual_positive_z_source_degeneracy","observation":report,"global_sign_flip_applied":false})

func run()->void:
	if configure():native_geometry_snapshots();pole_and_scope_guards()
	var sources:Dictionary={}
	for path:String in ["scripts/source_contact_geometry_probe.gd","scripts/source_terrain_query_frame.gd","scripts/source_native_contact_geometry.gd","scripts/source_terrain_query_trace.gd","scripts/source_natural_footprint_probe.gd","scripts/source_natural_contact.gd","scripts/source_terrain_point.gd","scripts/game_diagnostics.gd","tests/test_source_contact_geometry_probe.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEOMETRY_REPORT.get_base_dir()));var file:=FileAccess.open(GEOMETRY_REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"counts":geometry_counts,"sources":sources,"evidence":geometry_evidence,"scope":"One actual original classification per copied snapshot; all56 modern native actor controls, exact ordered origins and first-hit/history, native frame/leaf projection certificates, real collector transport, original antiparallel pole rejection and atomic scope guards. Certificates describe native leaf derivation and original arithmetic, not ordinary flight mesh identity, live response, full source caller or physical Android."},"\t"));file.close()
	print("Source contact geometry probe: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
