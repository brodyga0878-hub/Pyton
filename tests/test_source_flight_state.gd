extends SceneTree
# Integration ownership checks use the already independent native control
# banks. Explicit commands are not a claimed source player-dispatcher order.
const State=preload("res://scripts/source_flight_state.gd")
const Bank=preload("res://scripts/source_reference_bank.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const ANGULAR:="res://tests/fixtures/source_angular_native.json"
const CLOCK:="res://tests/fixtures/source_clock_pipeline_native.json"
const REFERENCE:="res://tests/fixtures/source_reference_bank_native.json"
const REPORT:="res://build/current-test-reports/source-flight-state.json"
var checks:=0
var failures:=0
var angular_case_count:=0
var clock_case_count:=0
var frame_case_count:=0
var _angular_fixture:Dictionary={}
var _clock_fixture:Dictionary={}
var _reference_fixture:Dictionary={}

func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<28:push_error(message)
func digest(value:Dictionary)->String:return Clock._hash(value)
func json_copy(value:Dictionary)->Dictionary:return JSON.parse_string(JSON.stringify(value))
func reseal(value:Dictionary)->void:
	var unsigned:=value.duplicate(true);unsigned.erase("snapshot_sha256");value.snapshot_sha256=digest(unsigned)
func raw_clock(low:int=0x80000000,day:int=0x121cf7)->Dictionary:
	return {"clock_low_u32":low,"clock_day_u32":day,"deadline_low_u32":0xffffffff,"deadline_day_u32":0xffffffff,"accelerated_counter_u32":0,"frame_ticks_u32":0,"system_counter_u32":0,"system_frame_ticks_u32":0,"system_total_u32":0}
func objects_from(encoded:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in encoded:result[int(key)]=str(encoded[key]).hex_decode()
	return result
func raw_parent(index:int)->PackedByteArray:
	var body:=PackedByteArray();body.resize(Bank.OBJECT_BYTES);body.fill(0);body[0x86]=index
	for component in [0,4,8]:body.encode_s32(component*4,0x7fffffff)
	return body
func pairs(events:Array)->Array:
	var result:Array=[]
	for event:Dictionary in events:result.append([int(event.event_u32),int(event.param_u32)])
	return result
func expected_pairs(events:Array)->Array:
	var result:Array=[]
	for event:Array in events:result.append([int(event[0]),int(event[1])])
	return result
func binding(body:PackedByteArray,objects:Dictionary,flags:PackedByteArray,clock_state:Dictionary,globals:Dictionary)->Dictionary:
	var bank:=Bank.new();var clock:=Clock.new();var owner:=State.new()
	if not bank.configure(body,objects,flags,{"tick_u32":int(clock_state.clock_low_u32),"day_u32":int(clock_state.clock_day_u32)}) or not clock.configure(clock_state):return {}
	if not owner.configure(bank.snapshot(),clock.snapshot(),globals):return {}
	return {"owner":owner,"bank":bank,"clock":clock,"globals":globals.duplicate(true)}
func angular_binding(row:Dictionary,clock_state:Dictionary={})->Dictionary:
	var body:=str(row.body_before_hex).hex_decode();var parent:=int(body[0x56]);var objects:Dictionary={}
	if parent!=0:objects[parent]=raw_parent(parent)
	var flags:=PackedByteArray();flags.resize(Bank.FLAGS_BYTES);flags.fill(0)
	return binding(body,objects,flags,raw_clock() if clock_state.is_empty() else clock_state,row.globals_before)
func eligible_angular(row:Dictionary)->bool:
	if int(row.operation)!=0:return false
	var body:=str(row.body_before_hex).hex_decode();var own:=int(body[0x86]);var parent:=int(body[0x56])
	return own>=1 and own<=Bank.MAX_INDEX and parent<=Bank.MAX_INDEX and parent!=own and int(row.globals_before.player_index_u32)==own
func seed_row()->Dictionary:
	for row:Dictionary in _angular_fixture.cases:
		if eligible_angular(row):return row
	return {}
func seed_parts()->Dictionary:return angular_binding(seed_row())
func report_scope(prepared:Dictionary,label:String)->void:
	check(prepared.profile==State.PROFILE and not prepared.receipt.event_effects_applied and not prepared.receipt.si_roundtrip and not prepared.receipt.F1418_executed and not prepared.receipt.full_original_player_dispatcher and not prepared.receipt.celestial_F866_advanced,"Explicit raw command retains its bounded caller/physics scope: "+label)

func angular_native()->void:
	for row:Dictionary in _angular_fixture.cases:
		if not eligible_angular(row):continue
		var parts:=angular_binding(row)
		check(not parts.is_empty(),"Unchanged angular native body binds a legitimate indexed owner: "+str(row.name))
		if parts.is_empty():continue
		angular_case_count+=1
		var owner:RefCounted=parts.owner;var frozen:=digest(owner.snapshot());var before_body:PackedByteArray=owner.raw_player();var before_clock:Dictionary=owner.raw_clock();var before_objects:Dictionary=owner.raw_objects()
		var prepared:Dictionary=owner.prepare_angular(row.budget_s32,row.accumulate,row.elapsed_ticks_s32)
		check(prepared.get("ok",false),"Actual source angular command prepares through unified owner: "+str(row.name))
		if not prepared.get("ok",false):continue
		var candidate:RefCounted=prepared.candidate_state
		check(candidate.raw_player().hex_encode()==str(row.body_after_hex),"Complete338 angular bytes match independent original instructions: "+str(row.name))
		check(digest(candidate.angular_globals())==digest(row.globals_after),"Raw player roll/global results match native controls: "+str(row.name))
		check(candidate.raw_clock()==before_clock and candidate.raw_objects()==before_objects,"Angular command preserves raw clock and all parent records")
		check(digest(owner.snapshot())==frozen and owner.raw_player()==before_body,"Angular private candidate never changes live raw owners")
		report_scope(prepared,str(row.name))
		var cold:=State.new();check(cold.restore(json_copy(candidate.snapshot())) and digest(cold.snapshot())==digest(candidate.snapshot()),"Angular native result survives exact cold JSON ownership boundary")
		check(owner.commit(prepared) and owner.raw_player().hex_encode()==str(row.body_after_hex),"Native angular result publishes as one verified owner transaction")
	check(angular_case_count==12,"All12 unchanged native angular bodies satisfying the explicit bank ownership domain are exercised")

func clock_native()->void:
	for row:Dictionary in _clock_fixture.cases:
		var parts:=angular_binding(seed_row(),row.initial)
		check(not parts.is_empty(),"Every independent original clock input binds its exact bank raw timestamp")
		if parts.is_empty():continue
		var owner:RefCounted=parts.owner;var frozen:=digest(owner.snapshot());var body:PackedByteArray=owner.raw_player();var objects:Dictionary=owner.raw_objects();var globals:Dictionary=owner.angular_globals()
		var prepared:Dictionary=owner.prepare_clock(0,0)
		check(prepared.get("ok",false),"The source clock counter already present in the native input is admitted once")
		if not prepared.get("ok",false):continue
		clock_case_count+=1
		var candidate:RefCounted=prepared.candidate_state;var state_after:Dictionary=candidate.raw_clock();var snapshot:Dictionary=candidate.snapshot()
		check(digest(state_after)==digest(row.result.state_after),"All nine clock/counter words match independently executed original instructions")
		check(digest({"events":prepared.receipt.events})==digest({"events":row.result.events}),"Actual native rollback/weekly/daily event order is retained by unified receipt")
		check(int(snapshot.core.reference_bank.clock.tick_u32)==int(state_after.clock_low_u32) and int(snapshot.core.reference_bank.clock.day_u32)==int(state_after.clock_day_u32),"Reference bank and raw clock publish exactly the same source timestamp")
		check(candidate.raw_player()==body and candidate.raw_objects()==objects and candidate.angular_globals()==globals and digest(owner.snapshot())==frozen,"Clock admission changes no angular, position, residue or parent byte and leaves live owner untouched")
		report_scope(prepared,"native clock")
	check(clock_case_count==836,"All836 independent original counter-admission cases pass through the unified raw owner")

func reference_native()->void:
	var operation_counts:Dictionary={}
	for row:Dictionary in _reference_fixture.cases:
		var operation:=str(row.operation)
		if operation not in ["select_parent","enter_parent","leave_parent","leave_then_enter"]:continue
		var body:=str(row.body_hex).hex_decode();var globals:={"player_index_u32":int(body[0x86]),"player_roll_s16":-1234}
		var parts:=binding(body,objects_from(row.objects_by_index),str(row.flags_hex).hex_decode(),raw_clock(),globals)
		check(not parts.is_empty(),"Original frame controls bind their explicit indexed bank: "+str(row.name))
		if parts.is_empty():continue
		var owner:RefCounted=parts.owner;var frozen:=digest(owner.snapshot());var initial_clock:Dictionary=owner.raw_clock();var events:Array=[]
		var prepared:Dictionary={}
		if operation=="select_parent":prepared=owner.prepare_frame("select",0,row.source_frame_byte)
		elif operation=="leave_then_enter":
			var left:Dictionary=owner.prepare_frame("leave_parent")
			check(left.get("ok",false),"Original composed source frame transition prepares its first departure")
			if not left.get("ok",false):continue
			events.append_array(left.receipt.events)
			check(digest(owner.snapshot())==frozen and owner.commit(left),"First source departure publishes only after its explicit commit")
			frozen=digest(owner.snapshot());prepared=owner.prepare_frame("enter_parent",row.target_index_u8)
		else:prepared=owner.prepare_frame(operation,row.target_index_u8)
		check(prepared.get("ok",false),"Original frame action prepares through unified raw owner: "+str(row.name))
		if not prepared.get("ok",false):continue
		frame_case_count+=1;operation_counts[operation]=int(operation_counts.get(operation,0))+1
		events.append_array(prepared.receipt.events)
		var candidate:RefCounted=prepared.candidate_state
		check(candidate.raw_player().hex_encode()==str(row.expected_body_hex),"Entire338 player bytes match original frame native control: "+str(row.name))
		check(pairs(events)==expected_pairs(row.expected_events),"Original source frame event requests survive explicit command composition")
		check(candidate.raw_objects()==objects_from(row.expected_objects_by_index) and candidate.snapshot().core.reference_bank.flags_hex==row.expected_flags_hex,"Every source record, cache and115 flag bytes match independent indexed-bank control")
		check(candidate.raw_clock()==initial_clock and digest(candidate.angular_globals())==digest(globals) and digest(owner.snapshot())==frozen,"Frame transitions preserve clock/angular globals and leave current owner untouched")
		report_scope(prepared,str(row.name))
		var cold:=State.new();check(cold.restore(json_copy(candidate.snapshot())) and cold.raw_player()==candidate.raw_player(),"Whole native frame outcome survives replay-validated cold restore")
		check(owner.commit(prepared) and owner.raw_player()==candidate.raw_player(),"Original frame state publishes exactly the staged outcome")
	check(frame_case_count==372 and operation_counts=={"select_parent":192,"enter_parent":72,"leave_parent":72,"leave_then_enter":36},"All372 eligible original frame cases cover selection, entry, exit and explicit composition")

func ownership_and_cold()->void:
	var parts:=seed_parts();var owner:RefCounted=parts.owner;var initial:Dictionary=owner.snapshot();var initial_frozen:=digest(initial)
	var p:Dictionary=owner.prepare_clock(100,49700)
	check(p.get("ok",false) and digest(owner.snapshot())==initial_frozen,"Real raw counter delivery stages without live changes")
	check(owner.commit(p),"First staged counter delivery commits")
	var current:Dictionary=owner.snapshot();var frozen:=digest(current);var cold:=State.new()
	check(cold.restore(json_copy(current)) and digest(cold.snapshot())==frozen,"Complete clock/bank/angular owner survives JSON cold boundary")
	check(not owner.commit(p) and digest(owner.snapshot())==frozen,"Duplicate command cannot publish its raw counter/event delivery twice")
	for action:String in ["clock","angular","frame"]:
		var a:Dictionary={};var b:Dictionary={}
		match action:
			"clock":a=owner.prepare_clock(49710,49700);b=cold.prepare_clock(49710,49700)
			"angular":a=owner.prepare_angular(163,true,1000);b=cold.prepare_angular(163,true,1000)
			"frame":a=owner.prepare_frame("leave_parent");b=cold.prepare_frame("leave_parent")
		check(a.get("ok",false) and b.get("ok",false),"Each explicit next command is available to both warm and cold owner: "+action)
		if not a.get("ok",false) or not b.get("ok",false):continue
		check(digest(a.candidate_state.snapshot())==digest(b.candidate_state.snapshot()) and digest(a.receipt)==digest(b.receipt),"Following explicit command is bit-identical after cold restore: "+action)
		check(owner.commit(a) and cold.commit(b) and digest(owner.snapshot())==digest(cold.snapshot()),"Warm and cold command composition stay identical: "+action)
	frozen=digest(owner.snapshot())
	var body:PackedByteArray=owner.raw_player();body[0]=int(body[0])^0xff
	var objects:Dictionary=owner.raw_objects()
	for key:Variant in objects:objects[key][0]=int(objects[key][0])^0xff
	var exposed_clock:Dictionary=owner.raw_clock();exposed_clock.clock_low_u32=0
	var exposed_globals:Dictionary=owner.angular_globals();exposed_globals.player_roll_s16=0
	var exposed_save:Dictionary=owner.snapshot();exposed_save.core.angular_globals.player_roll_s16=0
	check(digest(owner.snapshot())==frozen,"All exposed player, parent, clock, globals and snapshots are independent owned copies")
	var legacy:Dictionary=owner.snapshot();var stale:Dictionary=owner.prepare_clock(1,1)
	check(owner.restore(json_copy(legacy)) and not owner.commit(stale) and digest(owner.snapshot())==frozen,"Loading an identical cold state invalidates all older prepared envelopes")
	var sibling:=State.new();check(sibling.restore(json_copy(legacy)),"Second valid owner restores the exact same raw state")
	var cross:Dictionary=owner.prepare_clock(1,1)
	check(not sibling.commit(cross) and digest(sibling.snapshot())==frozen,"A different owner cannot consume another instance's staged counters")
	var reset_parts:=seed_parts();var reset:RefCounted=reset_parts.owner;var prior:Dictionary=reset.prepare_clock(1,1)
	check(reset.configure(reset_parts.bank.snapshot(),reset_parts.clock.snapshot(),reset_parts.globals) and not reset.commit(prior),"Reconfiguration invalidates previous prepared envelope even with identical source words and generation")
	var bounded:RefCounted=seed_parts().owner;var first_size:=0;var max_size:=0
	for index in range(64):
		var next:Dictionary=bounded.prepare_clock(49710,49700)
		check(next.get("ok",false) and bounded.commit(next),"Explicit repeated raw-clock command commits without retaining an unbounded command list")
		var size:=JSON.stringify(bounded.snapshot()).length()
		if index==0:first_size=size
		max_size=maxi(max_size,size)
	check(max_size<=first_size+1024 and bounded.snapshot().last_witness.size()==4,"Cold snapshot retains only one bounded previous core and one current core after64 commands")
	var bounded_cold:=State.new();check(bounded_cold.restore(json_copy(bounded.snapshot())),"Bounded long sequence remains cold-restorable")

func malformed_and_receipts()->void:
	var parts:=seed_parts();var owner:RefCounted=parts.owner;var frozen:=digest(owner.snapshot())
	for invalid:Variant in [null,true,1,"raw",[],{},NAN,INF]:
		check(not owner.configure(invalid,parts.clock.snapshot(),parts.globals) and not owner.configure(parts.bank.snapshot(),invalid,parts.globals) and not owner.configure(parts.bank.snapshot(),parts.clock.snapshot(),invalid) and not owner.restore(invalid) and digest(owner.snapshot())==frozen,"Malformed raw owner components reject atomically")
	var wrong_clock:=Clock.new();var mismatch:=raw_clock();mismatch.clock_low_u32+=1
	check(wrong_clock.configure(mismatch) and not owner.configure(parts.bank.snapshot(),wrong_clock.snapshot(),parts.globals) and digest(owner.snapshot())==frozen,"A legitimate source clock with a different timestamp cannot bind the reference bank")
	var wrong_globals:Dictionary=parts.globals.duplicate(true);wrong_globals.player_index_u32=int(wrong_globals.player_index_u32)+1
	check(not owner.configure(parts.bank.snapshot(),parts.clock.snapshot(),wrong_globals) and digest(owner.snapshot())==frozen,"The angular player ID must identify the exact raw indexed player")
	for invalid:Variant in [-1,true,1.25,0x100000000,NAN,INF,"0",null]:
		check(not owner.prepare_clock(invalid,0).ok and not owner.prepare_clock(0,invalid).ok and digest(owner.snapshot())==frozen,"Invalid delivered source counters reject without changing any raw owner")
	for invalid:Variant in [true,1.25,-0x80000001,0x80000000,NAN,INF,"1",null]:
		check(not owner.prepare_angular(invalid,true,1).ok and not owner.prepare_angular(1,true,invalid).ok and digest(owner.snapshot())==frozen,"Invalid signed source angular commands reject atomically")
	check(not owner.prepare_angular(1,1,1).ok and not owner.prepare_frame("F570").ok and not owner.prepare_frame("enter_parent",115).ok and not owner.prepare_frame("select",0,256).ok,"Unimplemented dispatcher names and invalid frame domains reject explicitly")
	for key:String in ["events","operation","generation_after","raw_player_before_sha256","event_effects_applied","F1418_executed","full_original_player_dispatcher","si_roundtrip","celestial_F866_advanced"]:
		var prepared:Dictionary=owner.prepare_clock(1,1)
		check(prepared.get("ok",false),"A valid raw command exists before testing receipt corruption")
		if not prepared.get("ok",false):continue
		match key:
			"events":prepared.receipt.events=[{"event_u32":16,"param_u32":0}]
			"operation":prepared.receipt.operation="frame"
			"generation_after":prepared.receipt.generation_after+=1
			"raw_player_before_sha256":prepared.receipt.raw_player_before_sha256="0".repeat(64)
			_:prepared.receipt[key]=true
		check(not owner.commit(prepared) and digest(owner.snapshot())==frozen,"Tampered public receipt cannot publish a different effect/claim: "+key)
	var dropped:Dictionary=owner.prepare_clock(1,1);dropped.receipt.erase("events")
	check(not owner.commit(dropped) and digest(owner.snapshot())==frozen,"Missing admitted event receipt cannot commit")
	var profile:Dictionary=owner.prepare_clock(1,1);profile.profile="jjffe-fixed"
	check(not owner.commit(profile) and digest(owner.snapshot())==frozen,"An outer envelope with a substituted reference profile rejects")
	var good:Dictionary=owner.prepare_clock(100,49700)
	check(good.get("ok",false) and owner.commit(good),"One valid command precedes cold-witness corruption controls")
	frozen=digest(owner.snapshot())
	for key:String in ["version","profile","generation","core","last_witness","snapshot_sha256"]:
		var saved:Dictionary=owner.snapshot()
		match key:
			"version":saved.version=true
			"profile":saved.profile="jjffe-fixed"
			"generation":saved.generation=0
			"core":saved.core.angular_globals.player_index_u32=0
			"last_witness":saved.last_witness.payload.accelerated_ticks_u32+=1
			"snapshot_sha256":saved.snapshot_sha256="0".repeat(64)
		check(not owner.restore(saved) and digest(owner.snapshot())==frozen,"Corrupted cold raw-owner snapshot rejects without altering live state: "+key)
	var rehashed:Dictionary=owner.snapshot();rehashed.last_witness.payload.accelerated_ticks_u32+=1;reseal(rehashed)
	check(not owner.restore(rehashed) and digest(owner.snapshot())==frozen,"Rehashed but incompatible claimed command fails native last-step replay")
	var mixed:Dictionary=owner.snapshot();mixed.core.clock_pipeline=wrong_clock.snapshot();reseal(mixed)
	check(not owner.restore(mixed) and digest(owner.snapshot())==frozen,"Individually valid but mismatched cold bank and clock owners reject")
	var extra:Dictionary=owner.snapshot();extra.last_witness.extra=0;reseal(extra)
	check(not owner.restore(extra) and digest(owner.snapshot())==frozen,"Unknown fields cannot expand the bounded command witness")

func run()->void:
	check(FileAccess.get_sha256(ANGULAR)=="ddcd81328d778ed5225f878e561f65188e4bebdabba6e61e21c36a88b44bdf84","Angular original-native fixture is pinned")
	check(FileAccess.get_sha256(CLOCK)=="88ea9774bef2a5a36dc2f4011f5c59b1c8f44ca382b8ade21df4906120ddfc62","Original raw clock fixture is pinned")
	check(FileAccess.get_sha256(REFERENCE)=="474763d258cfcf694f7521cf7fb8e1637fc31f090961179780d35dc71fb4cb45","Original indexed reference fixture is pinned")
	_angular_fixture=JSON.parse_string(FileAccess.get_file_as_string(ANGULAR));_clock_fixture=JSON.parse_string(FileAccess.get_file_as_string(CLOCK));_reference_fixture=JSON.parse_string(FileAccess.get_file_as_string(REFERENCE))
	angular_native();clock_native();reference_native();ownership_and_cold();malformed_and_receipts()
	var sources:Dictionary={}
	for path:String in ["scripts/source_flight_state.gd","scripts/source_reference_bank.gd","scripts/source_clock_pipeline.gd","scripts/source_angular_motion.gd","tests/test_source_flight_state.gd","tests/fixtures/source_angular_native.json","tests/fixtures/source_clock_pipeline_native.json","tests/fixtures/source_reference_bank_native.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":sources,"source_fixture_cases_compared":{"angular":angular_case_count,"clock":clock_case_count,"reference":frame_case_count},"scope":"Explicit raw-flight owner integration over existing independently DOS-verified angular, indexed-frame and clock kernels. Native fixture controls are reused, not new oracle cases. Private transactions, common receipts, typed ownership, bounded one-step witness and cold continuation are checked. No original F570/F1019/F1041 caller order, F1418 timer, F597 autopilot, celestial F866 advancement, actual Main flight or physical Android claim."},"\t"));file.close()
	print("Source flight state: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
