extends SceneTree
# Actual ownership around the native-proved player callbacks. F606 is executed
# at its source boundary, before speed-hold derives new acceleration commands.
const State=preload("res://scripts/source_flight_state.gd")
const Bank=preload("res://scripts/source_reference_bank.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Player=preload("res://scripts/source_player_dispatch.gd")
const Motion=preload("res://scripts/source_motion_pipeline.gd")
const Factory=preload("res://scripts/source_object_factory.gd")
const FIXTURE:="res://tests/fixtures/source_player_dispatch_native.json"
const FIXTURE_SHA:="2033e37070b53e2eaa90452ddf7cbb0f7484ce0453f5aba4a5dea00c5f446c8e"
const CHAIN:="res://validation/player-dispatch-2026-11-17/player-native-proof/player-frame-chain.json"
const CHAIN_SHA:="4b14fb995c23a3ffe8de2f3f324e9a14b052a7de2a3da9092ecfec2edb48f69e"
const REPORT:="res://build/current-test-reports/source-player-dispatch-state.json"
var checks:=0
var failures:=0
var native_cases:=0
var identity_adapted_cases:=0
var verified_cache_cases:=0
var root_frame_cases:=0
var frame_chain_cases:=0
var changed_order_cases:=0
var _fixture:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<28:push_error(label)
func digest(value:Dictionary)->String:return Clock._hash(value)
func json_copy(value:Dictionary)->Dictionary:return JSON.parse_string(JSON.stringify(value))
func reseal(value:Dictionary)->void:
	var unsigned:=value.duplicate(true);unsigned.erase("snapshot_sha256");value.snapshot_sha256=digest(unsigned)
func clock_state(frame_ticks:int=0)->Dictionary:
	return {"clock_low_u32":0x80000000,"clock_day_u32":0x121cf7,"deadline_low_u32":0xffffffff,"deadline_day_u32":0xffffffff,"accelerated_counter_u32":0,"frame_ticks_u32":frame_ticks,"system_counter_u32":0,"system_frame_ticks_u32":0,"system_total_u32":0}
func binding(body:PackedByteArray,objects:Dictionary,flags:PackedByteArray,globals:Dictionary,with_player_context:bool=true,time:Dictionary={})->Dictionary:
	var bank:=Bank.new();var clock:=Clock.new();var owner:=State.new()
	var raw_time:Dictionary={"tick_u32":0x80000000,"day_u32":0x121cf7} if time.is_empty() else time
	var source_clock:=clock_state(int(globals.frame_ticks_u32));source_clock.clock_low_u32=int(raw_time.tick_u32);source_clock.clock_day_u32=int(raw_time.day_u32)
	if not bank.configure(body,objects,flags,raw_time) or not clock.configure(source_clock):return {}
	var angular:={"player_index_u32":int(globals.player_index_u32),"player_roll_s16":int(globals.player_roll_s16)}
	var accepted:bool=owner.configure(bank.snapshot(),clock.snapshot(),angular,globals) if with_player_context else owner.configure(bank.snapshot(),clock.snapshot(),angular)
	if not accepted:return {}
	return {"owner":owner,"bank":bank,"clock":clock,"globals":Player._copy_globals(globals)}
func eligible(row:Dictionary)->bool:
	var body:=str(row.body_before_hex).hex_decode();var own:=int(body[0x86]);var parent:=int(body[0x56])
	return own>=1 and own<=114 and parent<=114 and parent!=own and int(row.globals_before.player_index_u32)==own and str(row.frame_response_body_hex).is_empty()
func parts_for(row:Dictionary,with_player_context:bool=true)->Dictionary:
	var body:=str(row.body_before_hex).hex_decode();var objects:Dictionary={};var parent:=int(body[0x56]);var identity_adapted:=false
	if parent!=0:
		var record:=str(row.parent_hex).hex_decode()
		# The isolated F603 oracle resolves the supplied record by pointer and
		# never reads its +86 identity. A real indexed bank also requires that
		# metadata to name the occupied slot; every physical byte is retained.
		identity_adapted=int(record[0x86])!=parent;record[0x86]=parent;objects[parent]=record
	var flags:=PackedByteArray();flags.resize(Bank.FLAGS_BYTES);flags.fill(0)
	var result:=binding(body,objects,flags,row.globals_before,with_player_context)
	if not result.is_empty():result.parent_identity_adapter=identity_adapted
	return result
func body_except_cache(body:PackedByteArray)->PackedByteArray:
	var result:=body.duplicate()
	for index in range(0x25,0x3e):result[index]=0
	return result
func objects_from(encoded:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in encoded:result[int(key)]=str(encoded[key]).hex_decode()
	return result
func native_controls()->void:
	for row:Dictionary in _fixture.cases:
		if not eligible(row):continue
		var parts:=parts_for(row);check(not parts.is_empty(),"Native callback body and raw globals bind a real indexed owner: "+str(row.name))
		if parts.is_empty():continue
		var owner:RefCounted=parts.owner;var frozen:=digest(owner.snapshot());var original:PackedByteArray=owner.raw_player();var old_clock:Dictionary=owner.raw_clock()
		var prepared:Dictionary=owner.prepare_player(row.operation,row.globals_before,255)
		check(prepared.get("ok",false),"Actual player callback prepares privately through the raw owner: "+str(row.name))
		if not prepared.get("ok",false):continue
		native_cases+=1
		if parts.parent_identity_adapter:identity_adapted_cases+=1
		var candidate:RefCounted=prepared.candidate_state;var expected_body:=str(row.expected.body_after_hex).hex_decode()
		if str(row.operation)=="prepare_f1041" and row.expected.frame_selection_requested:
			# The original callback fixture observes F606 without cache writes.
			# Here a real verified F606 executes: compare all other native bytes
			# and independently re-evaluate the exact middle bank/cache stage.
			var body:=str(row.body_before_hex).hex_decode();var parent:PackedByteArray=body if int(body[0x56])==0 else parts.bank.raw_object(int(body[0x56]))
			var prefix:=Player.prefix_f1041(body,parent,row.globals_before)
			var rebound:Dictionary=parts.bank.prepare_rebind(prefix.body_after,parts.bank.raw_clock())
			var selected:Dictionary=rebound.candidate_bank.prepare_select(255)
			check(selected.ok and selected.candidate_bank.raw_player()[0x56]==body[0x56],"Observer fixture domain has no eligible competing parent")
			check(body_except_cache(candidate.raw_player())==body_except_cache(expected_body),"Every native callback byte outside real source cache writes matches")
			check(candidate.raw_player().slice(0x25,0x3e)==selected.candidate_bank.raw_player().slice(0x25,0x3e) and candidate.raw_objects()==selected.candidate_bank.raw_objects(),"Actual F606 middle-stage caches and all parent records are published together")
			verified_cache_cases+=1
		else:check(candidate.raw_player()==expected_body,"Whole338-byte owned callback matches independent original native output: "+str(row.name))
		check(digest(candidate.player_globals())==digest(row.expected.globals_after) and digest(prepared.player_globals_after)==digest(row.expected.globals_after),"All14 native globals, including F603 scratch, remain authoritative")
		check(digest(candidate.angular_globals())==digest({"player_index_u32":int(row.expected.globals_after.player_index_u32),"player_roll_s16":int(row.expected.globals_after.player_roll_s16)}),"Angular alias follows the actual source player-roll result")
		check(candidate.raw_clock()==old_clock and int(candidate.snapshot().core.reference_bank.clock.tick_u32)==int(old_clock.clock_low_u32),"Control preparation and drift do not invent an extra clock interval")
		check(digest({"requests":prepared.callback_requests})==digest({"requests":row.expected.requests}) and prepared.receipt.source_order==row.expected.source_order,"Owned callback retains exact original external requests and procedure order")
		check(prepared.receipt.F606_executed==row.expected.frame_selection_requested and not prepared.receipt.event_effects_applied and not prepared.receipt.full_original_player_dispatcher,"Actual bounded frame selection is distinguished from a full player dispatcher")
		check(digest(owner.snapshot())==frozen and owner.raw_player()==original,"Prepared player step never writes live raw state")
		var cold:=State.new();check(cold.restore(json_copy(candidate.snapshot())) and digest(cold.snapshot())==digest(candidate.snapshot()),"Native callback result cold-restores full raw bytes and14 mutable globals")
		check(owner.commit(prepared) and digest(owner.snapshot())==digest(candidate.snapshot()),"Exactly the verified native candidate publishes as one owner command")
	check(native_cases>300 and identity_adapted_cases>0 and verified_cache_cases>0,"Raw owner consumes all eligible native domains, including documented identity and real-cache boundaries")
func root_frame_controls()->void:
	for row:Dictionary in _fixture.cases:
		var body:=str(row.body_before_hex).hex_decode()
		if row.operation!="prepare_f1041" or int(body[0x56])!=0 or not str(row.frame_response_body_hex).is_empty() or int(row.globals_before.frame_ticks_u32)>=30:continue
		# These exact native callbacks have half-step budgets below15, so F585
		# cannot consume an angle or read the player-ID comparison. Binding the
		# actual owned ID changes only metadata, not native arithmetic or roll.
		var g:Dictionary=Player._copy_globals(row.globals_before);g.player_index_u32=int(body[0x86])
		var flags:=PackedByteArray();flags.resize(Bank.FLAGS_BYTES);flags.fill(0)
		var parts:=binding(body,{},flags,g);check(not parts.is_empty(),"Unparented original callback binds without inventing a physical parent")
		if parts.is_empty():continue
		var prepared:Dictionary=parts.owner.prepare_player("prepare_f1041",g,253)
		check(prepared.ok and prepared.candidate_state.raw_player().hex_encode()==row.expected.body_after_hex,"Root-frame low-budget callback retains entire original native body")
		var expected:Dictionary=Player._copy_globals(row.expected.globals_after);expected.player_index_u32=int(body[0x86])
		check(prepared.ok and digest(prepared.candidate_state.player_globals())==digest(expected) and prepared.candidate_state.player_globals().spin_xyz_s32==g.spin_xyz_s32,"F603 no-parent branch preserves the previous shared spin/scratch words")
		var cold:=State.new();check(prepared.ok and cold.restore(json_copy(prepared.candidate_state.snapshot())),"Unparented callback result cold-restores without a fake bank record")
		root_frame_cases+=1
	check(root_frame_cases>0,"Actual unparented F1041 branches are covered in their unchanged arithmetic domain")
func seed_row()->Dictionary:
	for row:Dictionary in _fixture.cases:
		if eligible(row) and row.operation=="prepare_f1041" and not row.expected.frame_selection_requested:return row
	return {}
func next_player(owner:RefCounted)->Dictionary:
	return owner.prepare_player("prepare_f1041",owner.player_globals(),254)
func owner_and_cold()->void:
	var row:=seed_row();check(not row.is_empty(),"Native seed for persistent callback tests exists")
	if row.is_empty():return
	var parts:=parts_for(row);var owner:RefCounted=parts.owner;var first:Dictionary=next_player(owner)
	check(first.ok and owner.commit(first),"Actual first control callback commits before continuation tests")
	var cold:=State.new();check(cold.restore(json_copy(owner.snapshot())),"Committed full mutable player context restores")
	var a:=next_player(owner);var b:=next_player(cold)
	check(a.ok and b.ok and digest(a.candidate_state.snapshot())==digest(b.candidate_state.snapshot()),"Following actual callback is bit-identical after cold restore")
	check(owner.commit(a) and cold.commit(b),"Live and cold owners publish the same following callback")
	var frozen:=digest(owner.snapshot())
	var exposed:Dictionary=owner.player_globals();exposed.spin_xyz_s32[0]=0;exposed.player_roll_s16=0
	var saved:Dictionary=owner.snapshot();saved.core.player_dispatch_globals.reference_velocity_s32[0]=0
	check(digest(owner.snapshot())==frozen,"Exposed full player globals and snapshots cannot alias the owner")
	for invalid:Variant in [null,true,[],{},0,"callback"]:
		check(not owner.prepare_player("prepare_f1041",invalid).ok and digest(owner.snapshot())==frozen,"Malformed player context rejects atomically")
	var g:Dictionary=owner.player_globals();g.frame_ticks_u32=(int(g.frame_ticks_u32)+1)&0xffffffff
	check(not owner.prepare_player("prepare_f1041",g).ok and digest(owner.snapshot())==frozen,"Callback cannot consume a raw interval other than its owned clock admission")
	g=owner.player_globals();g.player_index_u32=(int(g.player_index_u32)%114)+1
	check(not owner.prepare_player("prepare_f1041",g).ok,"Callback cannot replace the owned player index")
	g=owner.player_globals();g.player_roll_s16=0 if int(g.player_roll_s16)!=0 else 1
	check(not owner.prepare_player("prepare_f1041",g).ok,"Callback cannot silently reset accumulated player roll")
	for field:String in ["callback_requests","player_globals_after","receipt","profile"]:
		var bad:Dictionary=next_player(owner)
		match field:
			"callback_requests":bad.callback_requests=[{"kind":"F1910","args":[3,1,301]}]
			"player_globals_after":bad.player_globals_after.spin_xyz_s32[0]=(int(bad.player_globals_after.spin_xyz_s32[0])+1)&0x7fffffff
			"receipt":bad.receipt.player_globals_after_sha256="0".repeat(64)
			"profile":bad.profile="jjffe-fixed"
		check(not owner.commit(bad) and digest(owner.snapshot())==frozen,"Mutated callback metadata cannot publish: "+field)
	var corrupt:Dictionary=owner.snapshot();corrupt.core.player_dispatch_globals.spin_xyz_s32[0]=(int(corrupt.core.player_dispatch_globals.spin_xyz_s32[0])+1)&0x7fffffff;reseal(corrupt)
	check(not owner.restore(corrupt) and digest(owner.snapshot())==frozen,"Rehashed scratch corruption still fails actual last-callback replay")
	corrupt=owner.snapshot();corrupt.core.player_dispatch_globals.frame_ticks_u32=(int(corrupt.core.player_dispatch_globals.frame_ticks_u32)+1)&0xffffffff;reseal(corrupt)
	check(not owner.restore(corrupt) and digest(owner.snapshot())==frozen,"Rehashed player/clock interval disagreement rejects before publication")
	var staged:Dictionary=next_player(owner);check(owner.restore(json_copy(owner.snapshot())) and not owner.commit(staged),"Loading identical raw state invalidates an old prepared callback")
	staged=next_player(owner);var other:=State.new();other.restore(json_copy(owner.snapshot()))
	check(not other.commit(staged),"Same-valued independent owners cannot consume one another's callback")
	var before_load:Dictionary=owner.snapshot();staged=next_player(owner)
	check(owner.configure(before_load.core.reference_bank,before_load.core.clock_pipeline,before_load.core.angular_globals,before_load.core.player_dispatch_globals) and not owner.commit(staged),"Explicit reconfigure invalidates already prepared player work")
	var ticks:Dictionary=owner.prepare_clock(49710,49700)
	check(ticks.ok and ticks.candidate_state.player_globals().frame_ticks_u32==ticks.candidate_state.raw_clock().frame_ticks_u32 and owner.commit(ticks),"Real clock admission synchronizes the persisted callback interval")
	var turn:Dictionary=owner.prepare_angular(1000,true,1000)
	check(turn.ok and turn.candidate_state.player_globals().player_roll_s16==turn.candidate_state.angular_globals().player_roll_s16 and owner.commit(turn),"Explicit angular operation synchronizes persisted player roll")
	var legacy:=parts_for(row,false);var old_owner:RefCounted=legacy.owner;var old_save:=json_copy(old_owner.snapshot());var restored:=State.new()
	check(not old_save.core.has("player_dispatch_globals") and restored.restore(old_save) and digest(restored.snapshot())==digest(old_save),"Existing three-field core snapshots remain portable without invented new globals")
	var attached:Dictionary=restored.prepare_player(row.operation,row.globals_before,255)
	check(attached.ok and attached.candidate_state.player_globals().size()==14,"An explicit callback can attach its verified14-field context to a legacy owner")
	var sequential:RefCounted=parts_for(row).owner
	var admit:Dictionary=sequential.prepare_clock(49710,49700)
	check(admit.ok and sequential.commit(admit),"Dependent callback sequence begins from a real source clock admission")
	var initial_size:=JSON.stringify(sequential.snapshot()).length()
	for index in range(64):
		var context:Dictionary=sequential.player_globals();context.forward_key_u8=0 if index%3==0 else 1;context.reverse_key_u8=0 if index%3==1 else 1
		var next:Dictionary=sequential.prepare_player("prepare_f1041",context,index+1)
		check(next.ok and sequential.commit(next),"Repeated actual control callback publishes raw residues and scratch "+str(index))
		var restored_next:=State.new()
		check(restored_next.restore(json_copy(sequential.snapshot())) and digest(restored_next.snapshot())==digest(sequential.snapshot()),"Every dependent callback cold-restores its exact raw context "+str(index))
		if index==31:sequential=restored_next
	check(JSON.stringify(sequential.snapshot()).length()<initial_size+2048,"Sixty-four commands retain a bounded last-step witness instead of recursive history")
func factory_seed()->void:
	var path:="res://tests/fixtures/source_object_factory_native.json"
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var chosen:Dictionary={}
	var actual_resources:Dictionary=Factory.source_model(38)
	for row:Dictionary in fixture.cases:
		if int(row.model_index_u32)!=38 or digest(row.resources)!=digest(actual_resources):continue
		var body:=str(row.expected_body_hex).hex_decode();var own:=int(body[0x86]);var parent:=int(body[0x56])
		if own>=1 and own<=114 and parent<=114 and parent!=own:chosen=row;break
	check(not chosen.is_empty(),"A native Cobra38 factory result satisfies explicit indexed owner admission")
	if chosen.is_empty():return
	var initialized:=Factory.initialize_raw(str(chosen.before_body_hex).hex_decode(),str(chosen.source_body_hex).hex_decode(),38,chosen.clock,chosen.copy_source)
	check(initialized.ok and initialized.body_after.hex_encode()==chosen.expected_body_hex,"Actual raw factory reproduces its entire independent338-byte Cobra control")
	if not initialized.ok:return
	var body:PackedByteArray=initialized.body_after;var parent:=int(body[0x56]);var objects:Dictionary={}
	if parent!=0:
		var record:=PackedByteArray();record.resize(338);record.fill(0);record[0x86]=parent
		for offset in [0,16,32]:record.encode_s32(offset,0x7fffffff)
		objects[parent]=record
	var flags:=PackedByteArray();flags.resize(115);flags.fill(0)
	var g:Dictionary=Player._copy_globals(seed_row().globals_before);g.player_index_u32=int(body[0x86]);g.player_roll_s16=0;g.frame_ticks_u32=0;g.spin_elapsed_s32=0x2625a01;g.player_mode_u8=0;g.flight_flags_u8=1;g.damping_flags_u8=0;g.forward_key_u8=1;g.reverse_key_u8=1;g.spin_xyz_s32=[0,0,0]
	var parts:=binding(body,objects,flags,g,true,chosen.clock)
	check(not parts.is_empty() and parts.owner.raw_player()==body,"Factory output binds Bank/Clock/owner with every raw pose, velocity and residue byte preserved")
	if parts.is_empty():return
	var original:=body.duplicate();var prepared:Dictionary=parts.owner.prepare_player("prepare_f1041",g,252)
	check(prepared.ok and parts.owner.raw_player()==original,"First raw controller callback prepares from factory bytes without an SI seeding round-trip")
	if prepared.ok:
		check(prepared.candidate_state.raw_player().slice(0,0x24)==original.slice(0,0x24) and prepared.candidate_state.raw_player().slice(0x3e,0x56)==original.slice(0x3e,0x56) and prepared.candidate_state.raw_player().slice(0x8c,0x98)==original.slice(0x8c,0x98) and prepared.candidate_state.raw_player().slice(0xec,0xf2)==original.slice(0xec,0xf2),"Zero-budget source preparation preserves factory pose, velocity and Q16 residues")
func chain_native()->void:
	check(FileAccess.file_exists(CHAIN),"Independent native middle-frame continuation control exists")
	if not FileAccess.file_exists(CHAIN):return
	check(FileAccess.get_sha256(CHAIN)==CHAIN_SHA,"The separate original native frame-chain control is pinned")
	var chain:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CHAIN))
	check(chain.get("cases") is Array and chain.cases.size()==2 and chain.source_executable_sha256==Player.SOURCE_EXE_SHA256 and not chain.expected_arithmetic_calculated_in_python,"Supplemental native frame-chain proof contains two independently executed original controls")
	for path:String in chain.source_pins:check(FileAccess.get_sha256("res://"+path)==str(chain.source_pins[path]),"Supplemental native continuation uses the pinned source/proof input "+path)
	for row:Dictionary in chain.cases:
		var input:Dictionary=row.player_input;var bank_input:Dictionary=row.bank_input;var bank_expected:Dictionary=row.bank_expected;var expected:Dictionary=row.player_expected
		var body:=str(input.body_before_hex).hex_decode();var parent:=str(input.parent_hex).hex_decode();var globals:Dictionary=input.globals_before
		var flags:=str(bank_input.flags_hex).hex_decode();var objects:=objects_from(bank_input.objects_by_index)
		var parts:=binding(body,objects,flags,globals)
		check(not parts.is_empty(),"Actual original native moving-parent control binds its complete unmodified indexed bank")
		if parts.is_empty():continue
		var prefix:=Player.prefix_f1041(body,parent,globals)
		check(prefix.ok and prefix.frame_selection_requested and prefix.frame_boundary_body.hex_encode()==bank_input.body_hex,"Original callback reaches the exact independently captured F606 input")
		var middle:Dictionary=parts.bank.prepare_rebind(prefix.body_after,parts.bank.raw_clock())
		var selected:Dictionary=middle.candidate_bank.prepare_select(bank_input.source_frame_byte)
		check(selected.ok and selected.body.hex_encode()==bank_expected.body_hex and selected.objects_by_index==objects_from(bank_expected.objects_by_index) and selected.flags.hex_encode()==bank_expected.flags_hex,"Whole actual F606 player/cache/bank output matches its independent original native control")
		var owner:RefCounted=parts.owner;var frozen:=digest(owner.snapshot())
		var prepared:Dictionary=owner.prepare_player(input.operation,globals,bank_input.source_frame_byte)
		check(prepared.ok and prepared.receipt.F606_executed,"Raw owner executes the requested middle F606 itself")
		if not prepared.ok:continue
		var candidate:RefCounted=prepared.candidate_state
		check(candidate.raw_player().hex_encode()==expected.body_after_hex,"Entire owned338-byte callback matches actual original F1041 after independently executed F606")
		check(candidate.raw_objects()==objects_from(bank_expected.objects_by_index) and digest(candidate.player_globals())==digest(expected.globals_after),"Native parent caches and all mutable callback globals publish with the final player")
		check(digest({"requests":prepared.callback_requests})==digest({"requests":expected.requests}) and prepared.receipt.source_order==expected.source_order,"Original middle-frame request and post-frame thrust callback order remain exact")
		var late:=str(row.wrong_late_order.body_hex).hex_decode()
		if row.wrong_late_order.body_differs:
			check(candidate.raw_player()!=late,"Applying F606 after F607 would produce a different independently measured raw result")
			check(candidate.raw_player().slice(0xb6,0xbc)!=late.slice(0xb6,0xbc) or candidate.raw_player().slice(0xf2,0xfe)!=late.slice(0xf2,0xfe),"The observed ordering difference reaches thrust or remaining velocity rather than only cache metadata")
			changed_order_cases+=1
		else:check(candidate.raw_player()==late,"A native negative control does not invent a different thrust result when its frame transform has no relevant velocity change")
		check(digest(owner.snapshot())==frozen and owner.commit(prepared),"Correct middle-frame native result remains private until a verified commit")
		var cold:=State.new();check(cold.restore(json_copy(owner.snapshot())) and digest(cold.snapshot())==digest(owner.snapshot()),"Moving-parent native result cold-restores its exact raw player/bank/globals")
		if int(owner.raw_player()[0x56])!=0:
			var leave:Dictionary=owner.prepare_frame("leave_parent")
			check(leave.ok and owner.commit(leave) and int(owner.raw_player()[0x56])==0,"Actual source frame departure reaches the root without an invented parent record")
		else:check(int(owner.raw_player()[0x56])==0,"An already unparented native result retains its genuine root-frame state")
		if int(owner.raw_player()[0x56])==0:
			var root_cold:=State.new();check(root_cold.restore(json_copy(owner.snapshot())),"Source root-frame departure survives cold restore")
			var next:Dictionary=owner.prepare_player("prepare_f1041",owner.player_globals(),252)
			var resumed:Dictionary=root_cold.prepare_player("prepare_f1041",root_cold.player_globals(),252)
			check(next.ok and resumed.ok and digest(next.candidate_state.snapshot())==digest(resumed.candidate_state.snapshot()),"Following unparented F1041 uses the native no-parent branch identically after cold restore")
		frame_chain_cases+=1
	check(frame_chain_cases==2 and changed_order_cases>0,"Two whole native frame continuations include a moving-parent case with an independently measured order-sensitive thrust result")
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Original callback fixture bytes stay pinned")
	_fixture=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	native_controls();root_frame_controls();owner_and_cold();factory_seed();chain_native()
	var sources:Dictionary={}
	for path:String in ["scripts/source_flight_state.gd","scripts/source_player_dispatch.gd","scripts/source_reference_bank.gd","scripts/source_clock_pipeline.gd","scripts/source_angular_motion.gd","scripts/source_object_factory.gd","data/ffe_object_factory.json","tests/test_source_player_dispatch_state.gd","tests/fixtures/source_player_dispatch_native.json","tests/fixtures/source_object_factory_native.json","tests/fixtures/source_reference_bank_native.json","tools/rebuild_source_player_dispatch_native.py","tools/rebuild_source_player_frame_chain_native.py"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if FileAccess.file_exists(CHAIN):sources[CHAIN.trim_prefix("res://")]=FileAccess.get_sha256(CHAIN)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"native_eligible_callback_cases":native_cases,"parent_identity_adapter_cases":identity_adapted_cases,"native_observer_cases_with_actual_F606_cache":verified_cache_cases,"root_frame_low_budget_native_cases":root_frame_cases,"supplemental_native_frame_chain_cases":frame_chain_cases,"supplemental_native_order_sensitive_cases":changed_order_cases,"sources":sources,"full_original_player_pipeline":false,"live_Main_motion_replaced":false,"physical_device_tested":false,"scope":"Actual unified raw owner invokes independent DOS player callbacks. Real Bank F606 runs at the original middle boundary before thrust; native observer-only cases distinguish actual cache writes, and isolated-parent identity metadata is explicitly adapted without changing physical input fields. Root low-budget controls bind player-ID metadata only where F585 cannot consume an angle. Mutable scratch/roll/clock aliases, factory seeding, receipt verification, cold replay and revision-bound ownership are checked. Two supplemental original native frame-chain witnesses are separate from the640 callback bank; one records an order-sensitive moving-parent result, the other is a negative control. No universal F1019/F570 scheduler or live Main claim."},"\t"));file.close()
	print("SOURCE PLAYER DISPATCH STATE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
