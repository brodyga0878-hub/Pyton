extends "res://tests/test_source_natural_surface_bridge.gd"
# Source expectations are independently observed native F576/F579/F581/F1876.
# Modern observer/flat-provider placements are explicit fixtures. A source
# response is evaluated only as a preview; no Main physical commit is tested.
const Footprint=preload("res://scripts/source_natural_footprint_probe.gd")
const Diagnostics=preload("res://scripts/game_diagnostics.gd")
const FOOTPRINT_REPORT:="res://build/current-test-reports/source-natural-footprint-probe.json"
const NATIVE_FIXTURE:="res://tests/fixtures/source_footprint_native.json"
var footprint_counts:={"native_modern_actors":0,"visited_volumes":0,"native_query_leaves":0,"selected_children":0,"history_control_volumes":0,"capped_history_controls":0}
var footprint_evidence:Array=[]

func explicit_context(initial:Dictionary={})->Dictionary:
	return {"initial_globals":Natural._globals(initial),"history_policy":"isolated-diagnostic-initial-state"}
func flags(report:Dictionary)->void:
	check(report.diagnostic_only and not report.response_applied and not report.live_response_enabled and not report.source_geometry_identity_verified and not report.whole_mesh_certified,"Footprint observations never authorize source/render identity or live response")
	check(not report.full_F569 and not report.full_F570 and not report.source_object_bank_present,"Read-only source caller does not become an original bank or full dispatcher")
	check(Bridge._plain(report) and JSON.parse_string(JSON.stringify(report)) is Dictionary,"Footprint report contains only bounded finite JSON primitives")
func transport_depth(report:Dictionary)->void:
	var diagnostics:=Diagnostics.new();var envelope:={"context":{"flight":{"last_surface_footprint":report}}}
	var transported:Dictionary=diagnostics._safe_value(envelope,0)
	diagnostics.free()
	check(transported==envelope and not JSON.stringify(transported).contains("[depth limit]"),"Actual diagnostic collector preserves the complete shallow footprint report at context.flight.last_surface_footprint")
func observe(ctx:Dictionary,gear:int=65535,event:Dictionary={})->Dictionary:
	var before:=protected_state();var inputs:=var_to_bytes([ctx,event]);var report:=Footprint.sample(surface,ship,gear,ctx,event)
	check(protected_state()==before and inputs==var_to_bytes([ctx,event]),"Footprint query preserves flight/surface/source caches/provider counters and caller history/event")
	flags(report);return report
func modern_native_actor_cases(fixture:Dictionary)->void:
	for actor:Dictionary in fixture.actor_cases:
		if int(actor.parent_model)!=118 or not actor.get("euler_radians") is Array:continue
		ship.ship_id=str(actor.ship_id);ship.velocity=Vector3.ZERO;ship.attitude=Quaternion.from_euler(Vector3(actor.euler_radians[0],actor.euler_radians[1],actor.euler_radians[2]))
		var source:=Phone.source_ship_data(ship.ship_id);var inner:=int(source.inner_radius_raw)*Phone.Units.METRES_PER_RAW
		ship.position=Vector3(0,accepted_height+surface.clearance(ship)-inner+float(actor.source_center_height_m),0)
		var ctx:=explicit_context(actor.context.initial_globals);var report:=observe(ctx,0);var expected:Dictionary=actor.expected
		check(report.ok,str(actor.id)+" produces an actual source footprint report")
		if not report.ok:continue
		footprint_counts.native_modern_actors+=1;footprint_counts.visited_volumes+=report.volumes.size()
		check(report.query_context.original_relative_s64_hex==actor.relative_before_hex and report.query_context.source_orientation_q31_hex==str(actor.player_object_hex).left(72),str(actor.id)+" exact canonical observer and actual Q31 ship orientation")
		check(int(report.f576_return_s32)==int(expected.canonical.f576_return_s32) and int(report.collision_kind_u8)==int(expected.canonical.globals.collision_kind_u8) and int(report.visited_volume_count)==int(expected.visited_volume_count) and int(report.total_volume_count)==int(expected.nominal_source_volume_count),str(actor.id)+" exact native return/kind and ordered visited/nominal counts")
		check(int(report.selected_child_index)==int(expected.selected_child_index),str(actor.id)+" first hit index remains distinct from last visited nohit index")
		check(report.final_previous_s64_hex==expected.selected_previous_altitude_s64_hex and report.trace_query_count_matches and not report.query_context.trace_truncated,str(actor.id)+" exact signed64 native previous altitude and complete uncapped trace")
		for index in range(report.volumes.size()):
			var row:Dictionary=report.volumes[index];var native:Dictionary=expected.volume_trace[index];var ground:Dictionary=actor.visible_ground_points[index]
			check(int(row.child_index)==int(native.child_index) and row.relative_before_s64_hex==native.relative_before_hex and row.relative_truncated_s64_hex==native.relative_truncated_hex and int(row.threshold_before_s32)==int(native.threshold_before_s32) and int(row.threshold_scaled_s32)==int(native.threshold_scaled_s32) and int(row.vector_scale_s32)==int(native.vector_scale_s32),str(actor.id)+" exact raw source offset/quantization/threshold for volume"+str(index))
			check(int(row.f579_return_s32)==int(native.f579_return_s32) and row.source_branch==native.branch and bool(row.source_previous_fresh)==bool(native.query.fresh_altitude_written),str(actor.id)+" actual per-volume branch and freshly written previous provenance")
			check(row.previous_after_s64_hex==Bridge._hex64(Footprint._signed_words(native.globals_after_f579,"previous_altitude")) and row.altitude_after_s64_hex==Bridge._hex64(Footprint._signed_words(native.globals_after_f579,"altitude")),str(actor.id)+" exact native source words after F579")
			check(row.local_point_f64_hex==ground.local_f64_hex and row.raw_inverse_forward_roundtrip_exact and row.visible_point_s64_hex==ground.visible_ground_raw_hex,str(actor.id)+" native child observer maps to its own actual Float64 visible footprint without another clearance shift")
			if bool(native.query.executed):
				footprint_counts.native_query_leaves+=1
				check(row.source_trace_status=="exact_observed_query_result" and int(row.source_query_result_s32)==int(native.query.result_s32) and int(row.source_query_limit_s32)==int(native.query.limit_s32),str(actor.id)+" trace observes the actual unchanged source query")
				if bool(native.winning_triangle.captured):
					check(row.source_winning_leaf_observed and row.winning_positions_s32_hex==Footprint._hex32(native.winning_triangle.positions_raw) and row.winning_depths_s32_hex==Footprint._hex32(native.winning_triangle.depths_s32) and int(row.winning_sar_shift_s32)==int(native.winning_triangle.sar_shift_s32) and int(row.winning_recorded_intersection_s32)==int(native.winning_triangle.recorded_intersection_raw),str(actor.id)+" original native winning triangle positions/depth/SAR/intersection")
		if int(report.selected_child_index)>=0:
			check(report.response_preview.available and report.response_preview.preview_only and not report.response_preview.response_applied and not report.response_preview.damage_applied,str(actor.id)+" bounded continuation remains an unapplied diagnostic preview")
			check(report.response_preview.relative_operand_s64_hex==actor.relative_before_hex and report.response_preview.previous_operand_s64_hex==report.final_previous_s64_hex,str(actor.id)+" continuation keeps original relative and actual selected native previous")
			if int(report.selected_child_index)>0:
				footprint_counts.selected_children+=1
				check(report.response_preview.relative_operand_s64_hex!=report.volumes[int(report.selected_child_index)].relative_before_s64_hex,str(actor.id)+" selected child observer never replaces original F575 radial operand")
		else:check(not report.response_preview.available and int(report.selected_child_index)==-1,str(actor.id)+" nohit has no fabricated selected contact or continuation")
		if str(actor.id)=="118_cobra_roll_plus_3.0":
			check(int(report.selected_child_index)==2 and report.final_previous_s64_hex=="68e5ffffffffffff" and int(report.visited_volume_count)==3,"Independently executed Cobra118 roll0.25 child2 case retains exact -6808raw selected previous")
			check(report.volumes[0].visible_point_boundary_certified and not report.volumes[1].visible_point_boundary_certified and not report.volumes[2].visible_point_boundary_certified,"A body-zero visible plane remains explicitly mismatched at both actual Cobra child footprints")
			check(not report.all_visited_visible_points_boundary_certified,"No whole-footprint admission is inferred from a body point")
			transport_depth(report);footprint_evidence.append({"case":"independent_native_cobra118_roll025_child2","report":report})
	check(footprint_counts.native_modern_actors>=54 and footprint_counts.selected_children>0 and footprint_counts.native_query_leaves>0,"Native actor coverage includes all three ships, real children and actual winning source leaves")
func native_history_controls(fixture:Dictionary)->void:
	for bank:String in ["actor_cases","ground_cases"]:
		for sample:Dictionary in fixture[bank]:
			var initial:=Natural._globals(sample.context.initial_globals)
			var state:={"altitude":Footprint._signed_words(initial,"altitude"),"previous":Footprint._signed_words(initial,"previous_altitude"),"altitude_origin":"supplied_initial_altitude","previous_origin":"supplied_initial_previous"}
			for native:Dictionary in sample.expected.volume_trace:
				var query:Dictionary=native.query;var iteration:={"branch":str(native.branch),"query_result_raw":int(query.result_s32),"query_limit_raw":int(query.limit_s32),"vector_scale_s32":int(native.vector_scale_s32),"child_index":int(native.child_index),"f579_return_s32":int(native.f579_return_s32)}
				var before:=var_to_bytes([state,iteration]);var next:=Footprint._history_step(state,iteration);footprint_counts.history_control_volumes+=1
				check(before==var_to_bytes([state,iteration]) and int(next.altitude)==Footprint._signed_words(native.globals_after_f579,"altitude") and int(next.previous)==Footprint._signed_words(native.globals_after_f579,"previous_altitude"),str(sample.id)+" observed native previous/altitude transition, including coarse gates and capped queries")
				check(bool(next.fresh)==bool(query.fresh_altitude_written),str(sample.id)+" query-call count never substitutes for fresh-altitude evidence")
				if bool(query.executed) and not bool(query.fresh_altitude_written):
					footprint_counts.capped_history_controls+=1;check(next.update=="query_capped_copies_retained_altitude",str(sample.id)+" capped query copies retained altitude and is labelled honestly")
				state=next
	check(footprint_counts.capped_history_controls>0,"At least one independent native capped query demonstrates retained/high-word history semantics outside the modern public surface scope")
func v4_and_public_boundaries()->void:
	var v5:RefCounted=surface.globe;var provider:RefCounted=surface.source_render_state
	var v4:=Legacy.new();v4.configure(system,"body","");v4.latitude=0;v4.longitude=0;surface.globe=v4
	var packet:=Packet.prepare(v4,{"core_width":64.0,"core_cells":2,"include_rings":false,"source_key":"actual-v4-footprint-provider"});var state:=Frame.new()
	check(packet.get("ok",false) and state.configure(packet),"Default v4 sampler prepares the actual source geometry used by current gameplay")
	surface.source_render_state=state
	for ship_id:String in ["eagle","cobra","shuttle"]:
		ship.ship_id=ship_id;ship.attitude=Quaternion.IDENTITY;ship.velocity=Vector3.ZERO;ship.position=Vector3(0,float(v4.raw_height(0,0))+surface.clearance(ship)+3,0)
		var report:=observe(explicit_context())
		check(report.ok and report.query_context.terrain_revision==Legacy.REVISION_NAME and not report.query_context.history_is_running_source_bank and report.query_context.history_policy=="isolated-diagnostic-initial-state", "Default v4 query provides honest current source footprints: "+ship_id)
		transport_depth(report);footprint_evidence.append({"case":"default_v4_"+ship_id,"report":report})
	for anchor:Array in [[0.31,0.47],[PI*0.5,PI],[-PI*0.5,-PI]]:
		v4.latitude=float(anchor[0]);v4.longitude=float(anchor[1]);ship.ship_id="shuttle";ship.attitude=Quaternion.from_euler(Vector3(-0.22,0.17,0.13));ship.position=Vector3(8.25,float(v4.raw_height(8.25,-12.5))+surface.clearance(ship)+3,-12.5)
		packet=Packet.prepare(v4,{"core_width":64.0,"core_cells":2,"include_rings":false,"source_key":"actual-v4-geographic-footprint-provider"});state=Frame.new()
		check(packet.get("ok",false) and state.configure(packet),"Actual v4 provider configures at an oblique/polar geographic frame")
		surface.source_render_state=state;var geographic:=observe(explicit_context())
		check(geographic.ok and geographic.trace_query_count_matches,"Actual oblique/polar frame has a complete ordered native query trace")
		for row:Dictionary in geographic.volumes:check(row.raw_inverse_forward_roundtrip_exact and not row.parent_transpose_applied,"Scalar64 source point/child footprint round-trips exact raw coordinates at oblique and polar anchors")
		transport_depth(geographic)
	v4.latitude=0;v4.longitude=0
	var current_provider:RefCounted=surface.source_render_state;surface.source_render_state=null
	var unrendered:=observe(explicit_context());check(unrendered.ok and not unrendered.all_visited_visible_points_boundary_certified,"Absent published geometry retains useful source observations without a visible-point claim")
	for row:Dictionary in unrendered.volumes:check(row.visible_status=="published_provider_unavailable","Each actually visited volume states why visible geometry is unavailable")
	surface.source_render_state=current_provider
	surface.globe=v5;surface.source_render_state=provider
	var ctx:=explicit_context();var missing:=ctx.duplicate(true);missing.initial_globals.erase("previous_altitude_high_s32");var rejected:=observe(missing)
	check(not rejected.ok and rejected.reason=="missing_or_invalid_explicit_initial_globals","An absent previous high word cannot silently become zero")
	surface.city_data={"fixture":true};rejected=observe(ctx);check(not rejected.ok and rejected.reason=="city_or_underground_outside_natural_footprint_scope","City geometry reports its explicit blocked scope");surface.city_data={}
	var old_active:bool=surface.active;surface.active=false;rejected=observe(ctx);check(not rejected.ok and int(rejected.selected_child_index)==-1,"Inactive surface has no invented native footprint");surface.active=old_active
	ship.ship_id="cobra";ship.attitude=Quaternion.IDENTITY;ship.position=Vector3(0,accepted_height+surface.clearance(ship)+100,0)
	var first:=observe(ctx);var same:=observe(JSON.parse_string(JSON.stringify(ctx)))
	check(first==same,"Typed JSON source globals preserve the exact deterministic context binding and report")
	var original:=protected_state();first.volumes[0].relative_before_s64_hex="caller edit";first.query_context.initial_globals.altitude_high_s32=0
	check(protected_state()==original and observe(ctx)==same,"Returned report buffers and source histories are private")
func run()->void:
	if configure():
		var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(NATIVE_FIXTURE))
		check(fixture.source_sha256==Natural.SOURCE_SHA and fixture.native_fresh_process_runs_per_bank==3,"Independent footprint fixture observes original source in fresh native processes")
		modern_native_actor_cases(fixture);native_history_controls(fixture);v4_and_public_boundaries()
	var sources:Dictionary={}
	for path:String in ["scripts/source_natural_footprint_probe.gd","tests/test_source_natural_footprint_probe.gd","scripts/source_terrain_query_trace.gd","tests/fixtures/source_footprint_native.json","scripts/source_natural_contact.gd","scripts/source_natural_contact_pipeline.gd","scripts/source_natural_surface_bridge.gd","scripts/source_terrain_query.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOOTPRINT_REPORT.get_base_dir()));var file:=FileAccess.open(FOOTPRINT_REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"counts":footprint_counts,"evidence":footprint_evidence,"sources":sources,"scope":"Actual ordered read-only player volumes and visible points, source-winning integer leaves and independently observed native history transitions. Default v4 and v5 fixtures preserve all live state. Preview F575 candidates are never applied; no live admission, source/render mesh identity, complete bank, physical Android or native combined response chain is claimed."},"\t"));file.close()
	print("Natural footprint probe: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
