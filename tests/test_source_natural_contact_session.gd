extends SceneTree
const Session=preload("res://scripts/source_natural_contact_session.gd")
const Natural=preload("res://scripts/source_natural_contact.gd")
const Pipeline=preload("res://scripts/source_natural_contact_pipeline.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const Hyperdrive=preload("res://scripts/source_hyperdrive_session.gd")
const FIXTURE:="res://tests/fixtures/source_footprint_native.json"
const LIFECYCLE:="res://tests/fixtures/source_contact_lifecycle_native.json"
const REPORT:="res://build/current-test-reports/source-natural-contact-session.json"
var checks:=0
var failures:=0
var totals:={"native_actor_inputs":0,"supported_native_classifications":0,"explicit_scope_rejections":0,"actual_child_contacts":0,"actual_nohit":0,"actual_nohit_with_flag2":0,"prepared_queries":0}
var first:Dictionary={}
var accepted:Dictionary={}
var evidence:Array=[]
var lifecycle_counts:={"native_original_F574_F575_inputs":0,"accepted_source_responses":0,"corrected_genuine_nohit":0,"original_header_skips":0}
var lifecycle_finished:=false
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<35:push_error(label)
func request(sequence:int=1)->Dictionary:
	return {"sequence":sequence,"graphics_level":1,"caller_policy":Session.CALLER_POLICY,"interval_receipt":{"seconds_f64_hex":"9a9999999999b93f","commands_s16":[0,0,0],"clock_owner":"Navigation.elapsed_days","fuel_owner":"Navigation.source_hyperdrive"}}
func binding(parent:PackedByteArray)->Dictionary:
	var record:=PackedByteArray();record.resize(68);record.encode_u16(12,parent.decode_u32(0x82));record.encode_u32(4,parent.decode_u32(0xa0))
	return {"system_id":7,"parent_id":"explicit-native-parent","source_record_hex":record.hex_encode(),"coordinate_policy":Session.COORDINATE_POLICY,"history_policy":Session.HISTORY_POLICY}
func adapted(sample:Dictionary)->Dictionary:
	var body:=str(sample.player_object_hex).hex_decode();var parent:=str(sample.parent_object_hex).hex_decode();var relative:=Session._decode_vector(str(sample.relative_before_hex))
	# Actual F576 uses the explicit relative argument, not body position. This
	# declared fixture adapter aligns body3E with F570's primary-parent input.
	for axis in range(3):body.encode_s64(0x3e+axis*8,relative[axis])
	return {"body":body,"parent":parent,"relative":relative,"globals":Natural._globals(sample.context.initial_globals),"binding":binding(parent)}
func configure(row:Dictionary)->Session:
	var session:=Session.new()
	check(session.configure(row.body,row.parent,row.globals,row.binding),"Valid explicit primary-parent raw operands configure the contact session")
	return session
func bank()->void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(data.source_sha256==Natural.SOURCE_SHA and data.case_count==158 and data.actor_cases.size()==65,"The session consumes the independent158case native footprint bank, with65actual F576 actors and93directF579 ground controls")
	for sample:Dictionary in data.actor_cases:
		totals.native_actor_inputs+=1
		var row:=adapted(sample);var session:=Session.new()
		if not session.configure(row.body,row.parent,row.globals,row.binding):
			totals.explicit_scope_rejections+=1
			check(int(sample.parent_model)>133 or not Session._operands_valid(row.body,row.parent,row.relative),"Native gas/modified-radius/nonmatching-frame controls are explicitly outside this bounded canonical session")
			continue
		var before:=var_to_bytes(row);var start:=session.snapshot();var prepared:=session.prepare(row.body,row.parent,row.relative,request())
		if not prepared.ok:
			check(prepared.reason=="unsupported_f578_contact","A genuine unsupported original F578 branch is rejected, never converted to a natural surface hit")
			check(session.snapshot()==start,"An unsupported original response leaves the source session atomic")
			continue
		totals.supported_native_classifications+=1
		check(var_to_bytes(row)==before,"Preparing actual source contact never mutates caller operands, previous words or binding")
		check(session.snapshot().is_empty() and session.raw_body()==row.body and session.globals()==row.globals,"Pending source contact blocks snapshots and retains committed history/pose")
		var classified:Dictionary=prepared.classification;var expected:Dictionary=sample.expected.canonical
		check(int(classified.f576_return_s32)==int(expected.f576_return_s32) and int(classified.terrain_query_calls)==int(expected.terrain_query_calls),"Actual session classification agrees with independently executed original F576: "+str(sample.id))
		var expected_globals:=Natural._globals(expected.globals)
		# Native fixture already contains the active caller prefix. Compare all
		# actual classifier globals, independently of subsequent F575 writes.
		check(classified.globals_after==expected_globals,"Every resulting raw classifier global matches the independent native witness")
		check(prepared.trace_rows.size()==int(classified.terrain_query_calls),"Provider receives exactly the original collector rows from the same execution")
		totals.prepared_queries+=prepared.trace_rows.size()
		if int(classified.f576_return_s32)!=0:
			totals.actual_nohit+=1
			if int(classified.globals_after.collision_flags_u8)&2:totals.actual_nohit_with_flag2+=1
			check(not prepared.contact_detected and not prepared.response_applied and prepared.damage_calls.is_empty() and prepared.callbacks.is_empty() and prepared.body_after_hex==row.body.hex_encode(),"A native nohit, including flags2, changes no pose and requests no F575/F953 response")
		else:
			if int(classified.iterations[-1].child_index)>0:totals.actual_child_contacts+=1
			check(prepared.kernel.relative_position_s64==row.relative,"F575 always retains the original primary vector when a child volume wins")
		check(session.prepare(row.body,row.parent,row.relative,request())==prepared,"An identical retry uses its private staged result instead of a second classifier execution")
		var receipt:Dictionary=prepared.commit_receipt;check(session.commit(prepared.token,receipt).ok,"The exact outer-candidate acknowledgement commits the staged raw transition")
		check(session.raw_body().hex_encode()==prepared.body_after_hex and session.globals()==prepared.globals_after and session.generation()==1,"Commit advances exact raw body/history once")
		var saved:=session.snapshot();var restored:=Session.new();check(restored.restore(JSON.parse_string(JSON.stringify(saved))) and restored.snapshot()==saved,"Completed source body and14globals cold-restore with strict JSON hex transport")
		var duplicate:=restored.commit(prepared.token,receipt);check(duplicate.ok and duplicate.already_committed and duplicate.damage_calls.is_empty() and duplicate.callbacks.is_empty() and restored.snapshot()==saved,"A completed token remains idempotent across cold restore and emits no HP commands")
		if first.is_empty():first={"row":row.duplicate(true),"prepared":prepared.duplicate(true)}
		if accepted.is_empty() and str(sample.id)=="118_cobra_upright_3.0":accepted={"row":row.duplicate(true)}
	check(totals.supported_native_classifications>40 and totals.actual_child_contacts>2 and totals.actual_nohit>10 and totals.actual_nohit_with_flag2>0,"The complete native bank exercises supported child hits, source nohit and incidental flags2")
	evidence.append({"case":"separate_original_native_bank_consumed","counts":totals.duplicate(true),"F575_native_combined_chain_proof_claimed":false,"raw_position_primary_fixture_adapter":true})
func transaction_guards()->void:
	if first.is_empty():return
	var row:Dictionary=first.row;var session:=configure(row);var before:=session.snapshot();var prepared:=session.prepare(row.body,row.parent,row.relative,request());var raw_before:=var_to_bytes([session.raw_body(),session.globals()])
	var other:=request();other.interval_receipt.clock_owner="different";check(not session.prepare(row.body,row.parent,row.relative,other).ok and session.prepare(row.body,row.parent,row.relative,request())==prepared,"A changed pending request rejects without replacing the frozen retry")
	var receipt:Dictionary=prepared.commit_receipt.duplicate(true);receipt.commands_sha256="0".repeat(64)
	check(not session.commit(prepared.token,receipt).ok and session.is_pending() and var_to_bytes([session.raw_body(),session.globals()])==raw_before,"An invalid outer receipt cannot publish source pose/history or consume retry")
	var public:=session.prepare(row.body,row.parent,row.relative,request());public.globals_after.previous_altitude_low_u32=1;public.kernel.body_after[0]=1;public.trace_rows.clear();public.commit_receipt.commands_sha256="changed"
	check(session.prepare(row.body,row.parent,row.relative,request())==prepared,"Returned raw output, trace rows, commands and receipt are private copies")
	var fork:Session=session.fork_runtime();check(fork.is_pending() and fork.prepare(row.body,row.parent,row.relative,request())==prepared and fork.raw_body()==session.raw_body(),"Runtime transaction fork copies its exact staged trace and history without cold replay")
	check(fork.commit(prepared.token,prepared.commit_receipt).ok and session.is_pending() and session.raw_body()==row.body,"Committing a runtime fork cannot consume or mutate the original pending session")
	check(not session.discard("bad") and session.discard(prepared.token) and session.snapshot()==before,"Discard removes only the staged transaction and leaves committed state unchanged")
	var changed:PackedByteArray=row.body.duplicate();changed.encode_s64(0x140,1);check(not session.prepare(changed,row.parent,row.relative,request()).ok and session.snapshot()==before,"A modified source radius is rejected before the source pipeline")
	var vector:PackedInt64Array=row.relative.duplicate();vector[0]+=1;check(not session.prepare(row.body,row.parent,vector,request()).ok,"A vector inconsistent with F570 primary body3E cannot be substituted")
	other=request();other.sequence=2;check(not session.prepare(row.body,row.parent,row.relative,other).ok,"A skipped or stale sequence cannot bypass generation binding")
	var history:Dictionary=row.globals.duplicate(true);history.altitude_high_s32=-123;history.previous_altitude_high_s32=-456;history.previous_altitude_low_u32=0x89abcdef;history.collision_active_u8=77
	var prefix:=Session.caller_globals(history);check(prefix.altitude_low_u32==0xffffffff and prefix.altitude_high_s32==-123 and prefix.previous_altitude_high_s32==-456 and prefix.previous_altitude_low_u32==0x89abcdef and prefix.collision_active_u8==77 and prefix.collision_enabled_u8==255,"The actual active prefix resets only source-defined words and preserves high/previous/active history")
	prepared=session.prepare(row.body,row.parent,row.relative,request());check(session.commit(prepared.token,prepared.commit_receipt).ok,"A valid retry after rejection commits normally")
	var saved:=session.snapshot();receipt=prepared.commit_receipt.duplicate(true);receipt.sequence=19
	check(not session.commit(prepared.token,receipt).ok and session.snapshot()==saved,"Even an already consumed token requires its exact original receipt")
	for mutation:String in ["unknown","rawhex","missingglobal","raw64decimal","receipt","binding","phase"]:
		var broken:=saved.duplicate(true)
		match mutation:
			"unknown":broken.extra=1
			"rawhex":broken.body_hex="ABC"
			"missingglobal":broken.globals.erase("previous_altitude_high_s32")
			"raw64decimal":broken.body_hex=9223372036854775807
			"receipt":broken.last_commit_receipt.generation=88
			"binding":broken.binding.source_record_hex="00".repeat(68)
			"phase":broken.phase="parked"
		check(not session.restore(broken) and session.snapshot()==saved,"Malformed JSON "+mutation+" restores atomically without altering a valid live session")
	var old_body:=session.raw_body();var delta:=PackedInt64Array([1,-2,3])
	check(session.apply_host_velocity_word_delta(delta),"An explicitly bound host thermal adapter can update a free session's original integer words")
	var new_body:=session.raw_body()
	for axis in range(3):check(new_body.decode_s32(0x8c+axis*4)==old_body.decode_s32(0x8c+axis*4)+delta[axis] and new_body.decode_u16(0xec+axis*2)==old_body.decode_u16(0xec+axis*2),"A thermal source word delta preserves original Q16 low residues exactly")
	var shifted:=session.snapshot();var restored:=Session.new();check(restored.restore(shifted) and restored.raw_body()==new_body,"Free-session cold state retains explicit host thermal integer-word changes")
	check(not session.apply_host_velocity_word_delta(PackedInt64Array([4294967295,0,0])) and session.snapshot()==shifted,"A host velocity delta overflow rejects atomically")
func park_and_history()->void:
	if accepted.is_empty():return
	var row:Dictionary=accepted.row.duplicate(true);row.body.encode_u16(0x9e,65535)
	for axis in range(3):row.body.encode_s32(0x8c+axis*4,0);row.body.encode_u16(0xec+axis*2,101+axis)
	for offset:int in [0xb0,0xb2,0xb6,0xb8,0xba]:row.body.encode_u16(offset,17+offset)
	var session:=configure(row);var prepared:=session.prepare(row.body,row.parent,row.relative,request())
	check(prepared.ok and prepared.contact_detected and prepared.landing_accepted and prepared.damage_calls.is_empty(),"Actual upright Cobra child contact is accepted from source gear/speed/alignment predicates")
	if not prepared.ok or not prepared.landing_accepted:return
	var after:=str(prepared.body_after_hex).hex_decode()
	check(after.decode_s64(0x3e)>row.body.decode_s64(0x3e) and int(prepared.classification.previous_altitude_s64)<0,"Actual source correction places this accepted anchor outward from its native queried surface without a mesh-zero constraint")
	for axis in range(3):check(after.decode_s32(0x8c+axis*4)==0 and after.decode_u16(0xec+axis*2)==101+axis,"F575 zero integer velocity retains each raw Q16 fractional word")
	check(session.commit(prepared.token,prepared.commit_receipt).ok and session.mark_parked(),"Explicit host park anchors a real accepted source response without any mesh AGL input")
	for offset:int in [0xb0,0xb2,0xb6,0xb8,0xba]:check(session.raw_body().decode_u16(offset)==0 and after.decode_u16(offset)!=0,"Session source32 park applies actual F1042 control/rate resets separately from F575 output")
	var parked_body:=session.raw_body();var parked_state:=session.park_state();var held:=session.parked_tick()
	check(parked_state.source_state_u8==0x32 and not parked_state.source_object_bank_present and held.ok and held.body_after==parked_body and held.callbacks.is_empty(),"The bound source32 RET hold leaves the accepted rawbody unchanged without classifier or HP commands")
	var saved:=session.snapshot();var restored:=Session.new();check(restored.restore(JSON.parse_string(JSON.stringify(saved))) and restored.snapshot()==saved,"Cold parked anchor pure-replays the accepted original transition and preserves exact raw fractions/history")
	check(not restored.prepare(restored.raw_body(),restored.raw_parent(),Session._relative(restored.raw_body()),request(2)).ok and restored.snapshot()==saved,"Parked source state does not repeatedly run F575 or generate damage under a host gravity tick")
	check(not restored.apply_host_velocity_word_delta(PackedInt64Array([1,0,0])) and restored.snapshot()==saved,"The thermal bridge cannot invalidate a source accepted park witness in place")
	var before_body:=restored.raw_body();var before_globals:=restored.globals();check(restored.release_park().ok and restored.raw_body()==before_body and restored.globals()==before_globals and restored.phase()=="free","Explicit host release changes no source pose, attitude, velocity fractions or previous words")
	var next:=restored.prepare(restored.raw_body(),restored.raw_parent(),Session._relative(restored.raw_body()),request(2));check(next.ok,"A real source nohit or new contact may be classified normally after park release")
	if next.ok:
		check(restored.commit(next.token,next.commit_receipt).ok and restored.generation()==2,"Post-release transition advances the same source history without resetting it")
	var bad:=saved.duplicate(true);bad.park_witness.contact.body_after_hex="00".repeat(338);check(not restored.restore(bad),"A changed raw parked result cannot pass pure original transition replay")
	bad=saved.duplicate(true);bad.park_witness.contact.binding=[];check(not restored.restore(bad),"Malformed nested parked binding rejects as data without a runtime exception")
	bad=saved.duplicate(true);var changed_root:=str(bad.game_root_hex).hex_decode();changed_root[0xe8]=0x2c;bad.game_root_hex=changed_root.hex_encode();check(not restored.restore(bad),"Unsupported control-state bytes cannot poison an isolated source park root on cold restore")
	var surviving:=restored.snapshot()
	for path:Array in [["park_witness","contact","request","sequence"],["park_witness","contact","request","interval_receipt"],["park_witness","contact","generation"],["park_witness","park_context","parent_pointer_u32"],["park_witness","park_context","parent_index_u8"],["park_witness","callbacks"],["last_commit_receipt","generation"],["globals","previous_altitude_high_s32"],["binding","system_id"]]:
		bad=saved.duplicate(true);var cursor:Dictionary=bad
		for index in range(path.size()-1):cursor=cursor[path[index]]
		cursor[path[-1]]=[]
		check(not restored.restore(bad) and restored.snapshot()==surviving,"Malformed nested parked numeric/command data rejects atomically: "+str(path))
	evidence.append({"case":"native_accepted_park_cold_release","source_before_s64_hex":prepared.original_relative_s64_hex,"source_after_body_hex":prepared.body_after_hex,"source_previous_low":prepared.globals_after.previous_altitude_low_u32,"park_policy":Session.PARK_POLICY,"mesh_AGL_not_an_input":true,"source_player_phase32_fragment_executed":true,"full_F1021_executed":false,"source_fractional_velocity_preserved":true})
	# A real inside-inner branch retains all caller previous words. This is a
	# history observation, not proof that arbitrary initial history is physical.
	row.body=before_body.duplicate();var parent:PackedByteArray=row.parent;var relative:=PackedInt64Array([parent.decode_s64(0x140)/2,0,0])
	for axis in range(3):row.body.encode_s64(0x3e+axis*8,relative[axis])
	row.relative=relative;row.globals.previous_altitude_high_s32=-2345678;row.globals.previous_altitude_low_u32=0x89abcdef;row.globals.altitude_high_s32=-1234567
	var inner:=configure(row);var result:=inner.prepare(row.body,parent,relative,request());check(result.ok and result.classification.terrain_query_calls==0 and result.classification.globals_after.previous_altitude_high_s32==-2345678 and result.classification.globals_after.previous_altitude_low_u32==0x89abcdef and result.classification.globals_after.altitude_high_s32==-1234567,"Actual no-fresh-query innerfast path preserves explicit full caller history without inventing phone AGL or zero high words")
func existing_hp_owner_transaction()->void:
	if accepted.is_empty():return
	var row:Dictionary=accepted.row.duplicate(true);row.body.encode_u16(0x9e,0)
	var session:=configure(row);var owner:=Hyperdrive.new();check(owner.configure("cobra") and owner.bind_thermal_hull(37.625),"The real existing Hyperdrive/thermal owner prepares its fractional source HP anchor")
	var owner_before:=owner.snapshot();var prepared:=session.prepare(row.body,row.parent,row.relative,request())
	check(prepared.ok and prepared.damage_calls.size()==1 and not prepared.landing_accepted and owner.snapshot()==owner_before,"A genuine unsafe child contact stages one original F953 command without touching existing HP/RNG/fuel/thermal clocks")
	if not prepared.ok:return
	var candidate:Hyperdrive=owner.duplicate_session();var damage:=candidate.apply_contact_damage(prepared.damage_calls)
	check(damage.ok and damage.applied_calls==1 and candidate.thermal_hull_percent()==12.625 and owner.snapshot()==owner_before,"The existing HP owner applies the native minimum100raw loss once to an isolated candidate and preserves the37.625percent anchor")
	var bad:Dictionary=prepared.commit_receipt.duplicate(true);bad.token="bad"
	check(not session.commit(prepared.token,bad).ok and owner.snapshot()==owner_before and session.is_pending(),"A rejected outer candidate is discarded without publishing its real HP loss or consuming retry")
	candidate=owner.duplicate_session();damage=candidate.apply_contact_damage(prepared.damage_calls)
	check(damage.ok and session.commit(prepared.token,prepared.commit_receipt).ok,"Validated real HP and source transition candidates can be committed before the host swaps owners")
	owner=candidate;var after:=owner.snapshot();var replay:=session.commit(prepared.token,prepared.commit_receipt)
	check(replay.ok and replay.already_committed and replay.damage_calls.is_empty() and owner.snapshot()==after and owner.thermal_hull_percent()==12.625,"A replay emits no damage requests and cannot spend HP/RNG, fuel or thermal clock a second time")
	evidence.append({"case":"existing_Hyperdrive_HP_owner_clone_commit","fractional_hull_before":37.625,"fractional_hull_after":owner.thermal_hull_percent(),"applied_original_damage_calls":damage.applied_calls,"source_session_owns_HP":false,"host_clone_and_swap_required":true})
func original_caller_lifecycle()->void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LIFECYCLE))
	check(data.source_sha256==Natural.SOURCE_SHA and data.actor_case_count>=204 and data.explicit_corrected_requery_case_count>=73,"The independent native caller fixture executes actual F574/F575 on its complete actor and corrected-source-pose banks")
	var expected_accepted:=0;var expected_corrected_nohit:=0
	for bank_name:String in ["actor_cases","corrected_requery_cases"]:
		for sample:Dictionary in data[bank_name]:
			var row:=adapted(sample)
			if sample.has("source_record_hex"):row.binding.source_record_hex=sample.source_record_hex
			var session:=configure(row);var prepared:=session.prepare(row.body,row.parent,row.relative,request())
			lifecycle_counts.native_original_F574_F575_inputs+=1
			check(prepared.ok,"Original caller lifecycle input has a supported canonical session transition: "+str(sample.id))
			if not prepared.ok:continue
			var expected:Dictionary=sample.expected.canonical
			if int(expected.globals.collision_flags_u8)&0x40:expected_accepted+=1
			elif bank_name=="corrected_requery_cases" and int(expected.f576_return_s32)!=0:expected_corrected_nohit+=1
			if expected.f576_return_s32==null:
				lifecycle_counts.original_header_skips+=1
				check(not prepared.f576_called and not prepared.f575_header_entered and prepared.classification.is_empty() and prepared.trace_rows.is_empty() and prepared.kernel.f576_return_s32==null and prepared.body_after_hex==row.body.hex_encode() and not prepared.response_applied and prepared.damage_calls.is_empty(),"Actual original F575 header nohit never runs or fabricates F576, a leaf, response or HP command")
			else:check(prepared.f576_called and prepared.body_after_hex==sample.expected.body_after_f575_hex and int(prepared.kernel.f576_return_s32)==int(expected.f576_return_s32),"The original full F574/F575 native chain independently agrees on exact response body and classification")
			var globals:=Natural._globals(expected.globals)
			# F574 disables contact and does not select DATA8702. This declared
			# F569/F570 primary prefix sets enabledFF and selects its parent;
			# a native header skip exposes that otherwise latent pointer binding.
			globals.collision_enabled_u8=255;globals.collider_parent_selected=true
			check(prepared.globals_after==globals,"Every caller word matches native F574 after explicitly exposing active-enable and primary-parent-pointer policy differences")
			if prepared.landing_accepted:
				lifecycle_counts.accepted_source_responses+=1
				check(prepared.damage_calls.is_empty() and bool(prepared.response_applied),"A native accepted response emits no contact HP command")
			elif bank_name=="corrected_requery_cases" and not prepared.contact_detected:
				lifecycle_counts.corrected_genuine_nohit+=1
				check(prepared.body_after_hex==row.body.hex_encode() and prepared.damage_calls.is_empty(),"A native corrected-body requery genuinely returns nohit without parking or a manufactured response")
	check(lifecycle_counts.native_original_F574_F575_inputs==int(data.actor_case_count)+int(data.explicit_corrected_requery_case_count) and lifecycle_counts.accepted_source_responses==expected_accepted and lifecycle_counts.corrected_genuine_nohit==expected_corrected_nohit and lifecycle_counts.original_header_skips==6,"All independent original caller responses, six header skips and corrected-body nohit cases finish")
	evidence.append({"case":"independent_original_F574_F575_caller_chain","counts":lifecycle_counts.duplicate(true),"original_F574_collision_enabled":0,"session_F569_F570_prefix_collision_enabled":255,"exposed_caller_difference_fields":["collision_enabled_u8","collider_parent_selected"],"full_F1021_not_implemented_by_session":true})
	lifecycle_finished=true
func run()->void:
	bank();transaction_guards();park_and_history();existing_hp_owner_transaction();original_caller_lifecycle()
	check(totals.native_actor_inputs==65 and not first.is_empty() and not accepted.is_empty(),"All source bank cases finish without an interrupted test function")
	check(lifecycle_finished,"The complete independent caller lifecycle bank finishes without an interrupted test function")
	var pins:Dictionary={}
	for path:String in ["scripts/source_natural_contact_session.gd","scripts/source_natural_park.gd","tests/test_source_natural_contact_session.gd","scripts/source_natural_contact.gd","scripts/source_natural_contact_pipeline.gd","scripts/source_surface_contact.gd","scripts/source_terrain_query_trace.gd","scripts/source_hyperdrive_session.gd","tests/fixtures/source_footprint_native.json","tests/fixtures/source_contact_lifecycle_native.json"]:pins[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE);file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"counts":totals,"lifecycle_counts":lifecycle_counts,"sources":pins,"evidence":evidence,"scope":"Explicit canonical matching-bodyfixed primary-parent raw session; exact F569/F570-prefix assignments and original F575 header, immutable actual F576/F575 continuation and same-execution trace, strict hex snapshots, private staged retry/commit, pure contact plus accepted F1021-fragment/F1042/state32 park replay. Separate native F574/F575 caller-chain inputs independently match raw bodies/history after exposing F574's disabled byte/unchanged parent pointer versus this active prefix's FF/selected parent; accepted, six header skips and genuine corrected-body nohit cases covered. Session park pointer words are explicitly isolated object references. No executed native F570 scanner/F953/full F1021 or launch scheduler, HP/RNG/fuel/clock ownership, whole-mesh admission or actual Main/Android proof. Outer host clone-and-swap remains required."},"\t"));file.close()
	print("Natural contact session: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
