extends SceneTree
const Bank=preload("res://scripts/source_reference_bank.gd")
const FIXTURE:="res://tests/fixtures/source_reference_bank_native.json"
const FIXTURE_SHA:="474763d258cfcf694f7521cf7fb8e1637fc31f090961179780d35dc71fb4cb45"
const REPORT:="res://build/current-test-reports/source-reference-bank.json"
var checks:=0
var failures:=0
var native_cases:=0
var selection_cases:=0
var cache_changes:=0
var operations:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<28:push_error(label)
func objects_from(encoded:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in encoded:result[int(key)]=str(encoded[key]).hex_decode()
	return result
func events_as_pairs(events:Array)->Array:
	var result:Array=[]
	for event:Dictionary in events:result.append([int(event.event_u32),int(event.param_u32)])
	return result
func expected_pairs(events:Array)->Array:
	var result:Array=[]
	for event:Array in events:result.append([int(event[0]),int(event[1])])
	return result
func differences(first:PackedByteArray,second:PackedByteArray)->String:
	var result:Array=[]
	for index in range(mini(first.size(),second.size())):
		if first[index]!=second[index]:result.append("%x:%x/%x"%[index,first[index],second[index]])
	return str(result.slice(0,10))
func fixture_result(row:Dictionary,body:PackedByteArray,parent:PackedByteArray,objects:Dictionary,flags:PackedByteArray)->Dictionary:
	match str(row.operation):
		"parent_velocity":
			var result:=Bank.parent_velocity_dos(parent)
			if result.is_empty():return {}
			result.body=body.duplicate();result.events=[];return result
		"leave_parent":return Bank.translate_leave(body,parent)
		"enter_parent":return Bank.translate_enter(body,parent,row.target_index_u8)
		"leave_then_enter":
			var first:=Bank.translate_leave(body,parent)
			if first.is_empty():return {}
			var second:=Bank.translate_enter(first.body,parent,row.target_index_u8)
			if not second.is_empty():second.events=first.events+second.events
			return second
		"select_parent":return Bank.select_parent(body,objects,flags,row.source_frame_byte)
	return {}
func native_controls()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"The independently executed DOS native fixture bytes remain pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.schema=="starfrontier-source-reference-bank-native-v1" and fixture.profile==Bank.VARIANT and fixture.case_count==444 and fixture.cases.size()==444,"All444 original DOS reference-frame cases are present")
	check(fixture.fresh_process_runs==3 and fixture.reverse_case_count==460 and fixture.guards_and_bank_flags_unchanged,"Three original native processes, reversed order, body/bank/flags guards are checked separately")
	check(fixture.source_executable_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and fixture.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a","Original DOS executable and pinned source assembly identities are explicit")
	for row:Dictionary in fixture.cases:
		var body:=str(row.body_hex).hex_decode();var parent:=str(row.get("parent_hex","")).hex_decode()
		var objects:=objects_from(row.objects_by_index);var flags:=str(row.flags_hex).hex_decode()
		var before:=var_to_bytes([body,parent,objects,flags]);var label:=str(row.name)
		var result:=fixture_result(row,body,parent,objects,flags)
		operations[str(row.operation)]=true;native_cases+=1
		check(not result.is_empty(),"An actual original reference-frame result exists: "+label)
		if result.is_empty():continue
		var expected:=str(row.expected_body_hex).hex_decode()
		check(result.body==expected,"Entire338-byte DOS player matches: "+label+" "+differences(result.body,expected))
		check(events_as_pairs(result.events)==expected_pairs(row.expected_events),"Source event requests match without executing global gameplay callbacks: "+label)
		check(result.body.slice(0xec,0xf2)==body.slice(0xec,0xf2) and result.body.slice(0xb0,0xb6)==body.slice(0xb0,0xb6),"Raw fractional velocity and angular accumulators are retained: "+label)
		if row.operation=="parent_velocity":
			check(result.velocity_s32==PackedInt64Array(row.expected_parent_velocity_s32),"F595 native velocity words match: "+label)
			if row.expected_future_clock!=null:check(result.get("future_copy_clock",{})==Bank._clock_copy(row.expected_future_clock),"F595 private future-copy clock retains raw carry: "+label)
			check(not result.full_f866_executed,"The known DOS result does not claim a full orbital F866 port: "+label)
		if row.operation=="select_parent":
			selection_cases+=1
			check(result.flags==str(row.expected_flags_hex).hex_decode(),"All115 original bank flags match: "+label)
			var expected_objects:=objects_from(row.expected_objects_by_index)
			check(result.objects_by_index.size()==expected_objects.size(),"Stable source bank slots are retained: "+label)
			for index:int in expected_objects:
				check(result.objects_by_index.has(index) and result.objects_by_index[index]==expected_objects[index],"Entire cached source record matches at slot%d: %s %s"%[index,label,differences(result.objects_by_index.get(index,PackedByteArray()),expected_objects[index])])
			if row.expected_bank_changed:cache_changes+=1
			var state:=Bank.new()
			check(state.configure(body,objects,flags,{"tick_u32":0xffffffff,"day_u32":0x121cf7}),"The original explicit indexed bank binds without SI conversion: "+label)
			var frozen:=var_to_bytes(state.snapshot());var candidate:=state.prepare_select(row.source_frame_byte)
			check(candidate.get("ok",false) and candidate.body==expected and var_to_bytes(state.snapshot())==frozen,"Selection prepares the native player privately while preserving the live raw bank: "+label)
			if candidate.get("ok",false):
				var cold:=Bank.new();var saved:Dictionary=JSON.parse_string(JSON.stringify(candidate.candidate_bank.snapshot()))
				check(cold.restore(saved) and cold.raw_player()==expected and cold.raw_objects()==expected_objects and cold.raw_clock()==state.raw_clock(),"Cold JSON preserves all338-byte cache records, raw day/tick, and residue bytes: "+label)
		check(var_to_bytes([body,parent,objects,flags])==before,"Every caller-owned input remains unchanged: "+label)
	check(operations.size()==5 and selection_cases==192 and cache_changes>0,"Original velocity, entry, exit, composition and indexed selection/cache branches are all exercised")
	check(fixture.diagnostic_case_count==16 and fixture.JJFFE_COPY_boundary_diagnostics.size()==16,"JJFFE controlled-copy boundary diagnostics remain a separate native set")
	var differences_found:=0
	for row:Dictionary in fixture.JJFFE_COPY_boundary_diagnostics:
		var parent:=str(row.parent_hex).hex_decode();var dos:=Bank.parent_velocity_dos(parent)
		if dos.velocity_s32!=PackedInt64Array(row.expected_parent_velocity_s32):differences_found+=1
		check(Bank.parent_velocity(parent,"jjffe-7e54034").is_empty(),"Unported JJFFE profile rejects instead of silently selecting its velocity fix")
	check(differences_found>0,"Independent controlled-copy probes distinguish the original DOS result from JJFFE's changed operands")

func record(index:int,parent:int,seed:int=0)->PackedByteArray:
	var result:=PackedByteArray();result.resize(Bank.OBJECT_BYTES)
	for i in range(result.size()):result[i]=(i*17+seed)&255
	for i in range(9):result.encode_s32(i*4,0x7fffffff if i in [0,4,8] else 0)
	result[0x86]=index;result[0x87]=3;result[0x56]=parent;result[0x57]=0;result[0x25]=0
	result.encode_s16(0xda,0)
	for axis in range(3):
		result.encode_s64(0x3e+axis*8,(index*100+axis*7)*(1 if axis!=1 else -1))
		result.encode_s32(0x8c+axis*4,(index*19+axis*31)*(1 if axis!=1 else -1))
	return result
func state_fixture()->Dictionary:
	var player:=record(114,1,9);var objects:={1:record(1,0,3),2:record(2,1,7),3:record(3,1,11)}
	var flags:=PackedByteArray();flags.resize(Bank.FLAGS_BYTES);flags.fill(0);flags[1]=0x11;flags[2]=0x10;flags[3]=0x10;flags[114]=4
	var clock:={"tick_u32":0xffffffff,"day_u32":0xffffffff}
	var state:=Bank.new();check(state.configure(player,objects,flags,clock),"Explicit raw indexed transaction state configures")
	return {"state":state,"player":player,"objects":objects,"flags":flags,"clock":clock}
func transactions_and_cold()->void:
	var row:=state_fixture();var state:RefCounted=row.state;var before:=var_to_bytes(state.snapshot())
	var entered:Dictionary=state.prepare_transition("enter_parent",2)
	check(entered.get("ok",false) and entered.candidate_bank.raw_player()[0x56]==2,"An existing child frame prepares an explicit native F605 entry")
	check(var_to_bytes(state.snapshot())==before,"Preparing a successful entry does not commit a player or cache mutation")
	if entered.get("ok",false):
		var candidate:RefCounted=entered.candidate_bank
		check(candidate.raw_objects()==state.raw_objects() and candidate.bank_flags()==state.bank_flags() and candidate.raw_clock()==state.raw_clock(),"F605 preserves every indexed record, flag and raw clock word")
		check(candidate.generation()==state.generation()+1 and entered.receipt.events==[Bank._event()],"Transaction generation and source event request are explicit")
		var left:Dictionary=candidate.prepare_transition("leave_parent")
		check(left.get("ok",false) and left.body==row.player,"Actual integer F605/F604 pair retains full raw338B including Q16 and angular residues")
		var resumed:=Bank.new()
		check(resumed.restore(JSON.parse_string(JSON.stringify(candidate.snapshot()))),"Typed cold state binds exactly after an actual entry")
		var resumed_left:=resumed.prepare_transition("leave_parent")
		check(resumed_left.get("ok",false) and resumed_left.body==left.body and resumed_left.receipt==left.receipt,"The next native transaction agrees byte-for-byte after cold restore")
	var selected:Dictionary=state.prepare_select(19)
	check(selected.get("ok",false) and selected.body[0x56]==3,"Descending source indices and strict score comparisons retain the higher slot in an equal-score tie")
	if selected.get("ok",false):
		check(not selected.receipt.complete_original_flight_pipeline and not selected.receipt.full_f570_caller and not selected.receipt.full_f585_controller and selected.receipt.bank_cache_writes_allowed,"Selection declares its proved raw/cached source domain without claiming the whole flight loop")
		var same:Dictionary=selected.candidate_bank.prepare_select(19)
		check(same.get("ok",false),"A subsequent same-frame source call can consume the actual retained cache stamp")
	var player:PackedByteArray=state.raw_player();player[0]=0
	var objects:Dictionary=state.raw_objects();objects[1][0]=0;objects[7]=record(7,0)
	var flags:PackedByteArray=state.bank_flags();flags[1]=0
	var clock:Dictionary=state.raw_clock();clock.tick_u32=0
	check(var_to_bytes(state.snapshot())==before,"All raw getters return isolated buffers and dictionaries")
	var altered:PackedByteArray=state.raw_player();altered.encode_s32(0x8c,123456789);altered.encode_u16(0xb0,65535)
	var rebind:Dictionary=state.prepare_rebind(altered,{"tick_u32":0,"day_u32":0})
	check(rebind.get("ok",false) and rebind.candidate_bank.raw_player()==altered and rebind.candidate_bank.raw_clock()=={"tick_u32":0,"day_u32":0},"Verified caller raw state and wrapped clock can bind without an SI roundtrip")
	if rebind.get("ok",false):check(rebind.receipt.procedure=="caller-owned-raw-state-rebind-not-native-F570" and not rebind.receipt.source_clock_interval_executed_here and not rebind.receipt.celestial_f866_advanced,"Raw ownership rebind is not represented as a source motion, ephemeris or clock callback")
	check(var_to_bytes(state.snapshot())==before,"Every preparation and caller rebind keeps live raw owners unchanged")
func rejection_guards()->void:
	var row:=state_fixture();var state:RefCounted=row.state;var original:Dictionary=state.snapshot();var before:=var_to_bytes(original)
	for value in [null,[],{},true,0,"raw"]:check(not state.restore(value) and var_to_bytes(state.snapshot())==before,"Malformed cold container rejects atomically")
	var bad_states:Array=[];var bad:Dictionary
	for value:Variant in [true,0,2,"1",NAN,INF]:bad=original.duplicate(true);bad.version=value;bad_states.append(bad)
	for value:Variant in [true,-1,4294967296.0,0.5,NAN,INF]:bad=original.duplicate(true);bad.clock.tick_u32=value;bad_states.append(bad)
	for value:Variant in [true,-1,4294967296.0,0.5,NAN,INF]:bad=original.duplicate(true);bad.clock.day_u32=value;bad_states.append(bad)
	for value:Variant in [true,-1,100000001,0.5,NAN,INF]:bad=original.duplicate(true);bad.generation=value;bad_states.append(bad)
	for key:String in ["schema","profile","variant"]:bad=original.duplicate(true);bad[key]="jjffe-or-unrecognized";bad_states.append(bad)
	for key:String in ["player_hex","flags_hex","snapshot_sha256"]:
		for value:Variant in [true,[],"","ff",str(original[key])+"00",str(original[key]).to_upper()]:
			if value is String and value==original[key]:continue
			bad=original.duplicate(true);bad[key]=value;bad_states.append(bad)
	bad=original.duplicate(true);bad.unrecognized=true;bad_states.append(bad)
	bad=original.duplicate(true);bad.clock.unrecognized=true;bad_states.append(bad)
	bad=original.duplicate(true);bad.objects.reverse();bad_states.append(bad)
	bad=original.duplicate(true);bad.objects.append(bad.objects[0].duplicate(true));bad_states.append(bad)
	bad=original.duplicate(true);bad.objects[0].index=true;bad_states.append(bad)
	bad=original.duplicate(true);bad.objects[0].index=115;bad_states.append(bad)
	bad=original.duplicate(true);bad.objects[0].object_hex="00";bad_states.append(bad)
	var tampered:PackedByteArray=row.player.duplicate();tampered[0x86]=1;bad=original.duplicate(true);bad.player_hex=tampered.hex_encode();bad_states.append(bad)
	tampered=row.player.duplicate();tampered[0x56]=113;bad=original.duplicate(true);bad.player_hex=tampered.hex_encode();bad_states.append(bad)
	tampered=row.objects[1].duplicate();tampered[0x56]=2;bad=original.duplicate(true);bad.objects[0].object_hex=tampered.hex_encode();bad_states.append(bad)
	tampered=row.player.duplicate();tampered[0xec]^=1;bad=original.duplicate(true);bad.player_hex=tampered.hex_encode();bad_states.append(bad)
	for value:Dictionary in bad_states:check(not state.restore(value) and var_to_bytes(state.snapshot())==before,"Typed, sealed, indexed malformed cold state rejects before publication")
	for target:Variant in [null,true,-1,0,115,1.5,NAN,INF,"2",[],{}]:check(not state.prepare_transition("enter_parent",target).get("ok",false) and var_to_bytes(state.snapshot())==before,"Invalid native target index rejects atomically")
	for target in [1,7,114]:check(not state.prepare_transition("enter_parent",target).get("ok",false),"Missing/current/self frame cannot replace an eligible sibling transition")
	for value:Variant in [null,true,-1,256,0.5,NAN,INF,"1"]:check(not state.prepare_select(value).get("ok",false) and var_to_bytes(state.snapshot())==before,"Malformed source frame byte rejects without cache writes")
	var flags:PackedByteArray=row.flags.duplicate();flags[114]|=0x10
	check(not state.configure(row.player,row.objects,flags,row.clock) and var_to_bytes(state.snapshot())==before,"An orbital player flag cannot select itself into a cyclic parent")
	flags=row.flags.duplicate();flags[113]|=0x10
	check(not state.configure(row.player,row.objects,flags,row.clock) and var_to_bytes(state.snapshot())==before,"A selectable missing bank slot rejects before recursive access")
	var objects:Dictionary=row.objects.duplicate(true);objects[1][0x56]=2
	check(not state.configure(row.player,objects,row.flags,row.clock) and var_to_bytes(state.snapshot())==before,"Cyclic parent chains reject before original recursive lookup")
	check(not state.configure(row.player,row.objects,row.flags,row.clock,"jjffe-7e54034") and var_to_bytes(state.snapshot())==before,"Known JJFFE patch profile cannot silently replace the original DOS contract")
	var altered:PackedByteArray=row.player.duplicate();altered[0x56]=2
	check(not state.prepare_rebind(altered,row.clock).get("ok",false),"Caller raw rebind cannot bypass source parent translation")
	altered=row.player.duplicate();altered[0x57]=1
	check(not state.prepare_rebind(altered,row.clock).get("ok",false),"Caller raw rebind cannot bypass the original rotating-frame operator")
	var empty:=Bank.new();check(empty.snapshot().is_empty() and not empty.prepare_select(1).get("ok",false) and not empty.prepare_transition("leave_parent").get("ok",false),"Inactive raw owner does not fabricate a source frame")
	check(Bank.translate_enter(PackedByteArray(),row.objects[1],1).is_empty() and Bank.parent_velocity_dos(PackedByteArray()).is_empty(),"Truncated raw records reject at the pure procedure boundary")
func report()->void:
	var paths:=["scripts/source_reference_bank.gd","scripts/ground_coordinates.gd","scripts/source_gravity.gd","scripts/source_frame_kinematics.gd","scripts/source_orbit.gd","tests/test_source_reference_bank.gd","tests/fixtures/source_reference_bank_native.json"]
	var pins:Dictionary={}
	for path:String in paths:pins[path]=FileAccess.get_sha256("res://"+path)
	var result:={"schema":"starfrontier-source-reference-bank-test-v1","profile":Bank.PROFILE,"variant":Bank.VARIANT,"checks":checks,"failures":failures,"native_cases":native_cases,"native_selection_cases":selection_cases,"native_bank_cache_change_cases":cache_changes,"separate_jjffe_copy_diagnostics":16,"full_original_flight_pipeline":false,"full_f570_caller":false,"full_f585_controller":false,"live_Main_motion_replaced":false,"physical_device_tested":false,"sources":pins}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT).get_base_dir())
	var output:=FileAccess.open(REPORT,FileAccess.WRITE)
	if output!=null:output.store_string(JSON.stringify(result,"\t")+"\n")
func run()->void:
	if "--state-only" not in OS.get_cmdline_user_args():native_controls()
	transactions_and_cold();rejection_guards()
	if "--state-only" not in OS.get_cmdline_user_args():report()
	print("SOURCE REFERENCE BANK TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
