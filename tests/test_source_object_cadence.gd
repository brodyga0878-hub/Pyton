extends SceneTree
const Cadence=preload("res://scripts/source_object_cadence.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_object_cadence_native.json"
const FIXTURE_SHA:="8798bd2950832fedaf0cc4bd58fc0170218399df6a8386b8a06b08e18720bfa4"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<24:push_error(message)
func objects_from(row:Dictionary,expected:bool=false)->Dictionary:
	var result:Dictionary={}
	var raw:Dictionary=row.expected_objects_by_index if expected else row.objects_by_index
	for key:Variant in raw:result[int(str(key))]=str(raw[key]).hex_decode()
	return result
func objects_digest(objects:Dictionary)->String:
	var hexes:Dictionary={}
	for key:Variant in objects:hexes[str(key)]=objects[key].hex_encode()
	return Clock._hash(hexes)
func request(row:Dictionary,objects:Dictionary={})->Dictionary:
	return Cadence.advance_raw(row.operation,{"clock_low_u32":row.clock_low_u32,"clock_day_u32":row.clock_day_u32},objects_from(row) if objects.is_empty() else objects,str(row.flags_hex).hex_decode(),row.callback_types_u8,row.mutations,row.dispatch_object_index_u8,row.dispatch_type_u8)
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Whole DOS cadence native fixture is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.get("schema")=="starfrontier-source-object-cadence-native-v1" and fixture.case_count==265 and fixture.cases.size()==265,"Fixture retains all265 actual native cadence controls")
	check(fixture.fresh_process_runs==3 and fixture.reverse_case_count==265 and fixture.consecutive_original_steps==32 and fixture.canaries_and_unprovided_bank_records_unchanged and not fixture.expected_arithmetic_calculated_in_Python,"Native expected data comes from repeated guarded original instructions")
	var sequences:=0;var previous:Dictionary={};var callbacks:=0;var effects:=0
	for row:Dictionary in fixture.cases:
		var objects:=objects_from(row);var flags:=str(row.flags_hex).hex_decode()
		var before:=objects_digest(objects);var flags_before:=flags.hex_encode();var callbacks_before:=JSON.stringify(row.callback_types_u8);var mutations_before:=JSON.stringify(row.mutations)
		var result:=Cadence.advance_raw(row.operation,{"clock_low_u32":row.clock_low_u32,"clock_day_u32":row.clock_day_u32},objects,flags,row.callback_types_u8,row.mutations,row.dispatch_object_index_u8,row.dispatch_type_u8)
		check(result.ok,"Original F149/F144 input accepted: "+str(row.name))
		if not result.ok:continue
		check(result.objects_by_index.size()==objects.size(),"Sparse indexed bank ownership retained: "+str(row.name))
		for index:Variant in objects:
			check(result.objects_by_index[index]==objects_from(row,true)[index],"Entire338-byte object matches native output index%d: %s"%[int(index),row.name])
		check(result.flags.hex_encode()==row.expected_flags_hex and result.flags.size()==115,"All115 bank flags match original instructions: "+str(row.name))
		check(Clock._hash({"calls":result.dispatch_attempts})==Clock._hash({"calls":row.expected_dispatch_attempts}),"Actual source F144 attempts preserve descending order, selector and raw clock: "+str(row.name))
		check(Clock._hash({"calls":result.callbacks})==Clock._hash({"calls":row.expected_callbacks}),"NULL handlers and actual handler observations match native table lookup: "+str(row.name))
		check(result.mutations_applied==row.expected_mutations_applied,"Declared byte effects occur only for actual callbacks in source order: "+str(row.name))
		check(result.get("owner_global_bound_to_bank")==row.expected_owner_global_bound_to_bank,"F149 bank pointer binding and unchanged directF144 owner are explicit: "+str(row.name))
		check(objects_digest(objects)==before and flags.hex_encode()==flags_before and JSON.stringify(row.callback_types_u8)==callbacks_before and JSON.stringify(row.mutations)==mutations_before,"Native cadence wrapper never mutates input owners: "+str(row.name))
		check(not result.live_owners_changed and not result.callback_effects_executed and not result.full_world_scheduler and not result.JJFFE_laser_fix_executed,"Observed callback boundary is separate from actual world handler execution: "+str(row.name))
		callbacks+=result.callbacks.size();effects+=int(result.mutations_applied)
		if row.has("sequence_step"):
			check(int(row.sequence_step)==sequences,"Actual native sequence step order retained")
			if sequences>0:check(objects_digest(previous)==before,"Next native step begins with preceding actual raw output")
			var composed:=request(row,previous) if sequences>0 else result
			check(composed.ok and objects_digest(composed.objects_by_index)==objects_digest(result.objects_by_index),"Consecutive runtime cadence matches the complete original sequence")
			previous={}
			for index:Variant in result.objects_by_index:previous[index]=result.objects_by_index[index].duplicate()
			sequences+=1
		var exposed:Dictionary=result.objects_by_index
		if not exposed.is_empty():
			var first:Variant=exposed.keys()[0];exposed[first][0]^=255
			check(objects_digest(objects)==before,"Returned raw byte records do not alias caller input")
	check(sequences==32 and callbacks>0 and effects>0,"Repeated native cadence and cross-index observer effects exercised")
	var body:=PackedByteArray();body.resize(338);body.fill(0);body[0x86]=1;body[0x87]=1;body[0x8a]=3;body[0x8b]=0
	var objects:Dictionary={1:body};var flags:=PackedByteArray();flags.resize(115);flags.fill(0);flags[1]=1
	var clock:Dictionary={"clock_low_u32":0xffffffff,"clock_day_u32":0xffffffff}
	var frozen:=objects_digest(objects);var frozen_flags:=flags.hex_encode()
	var normal:=Cadence.advance_raw("cadence",clock,objects,flags)
	check(normal.ok and normal.callback_table_policy=="pinned-DOS-event5-presence" and normal.callbacks.size()==1 and normal.objects_by_index[1][0x8b]==3,"Default table uses the original six registered event5 selectors")
	for kind:int in range(21):
		var copy:=body.duplicate();copy[0x87]=kind
		var selected:=Cadence.advance_raw("dispatch",clock,{1:copy},flags,null,[],1,kind)
		check(selected.ok and selected.dispatch_attempts.size()==1 and selected.callbacks.size()==(1 if kind in Cadence.ORIGINAL_EVENT5_TYPES else 0),"Pinned original callback presence type%d"%kind)
	var dormant:=body.duplicate();dormant[0x87]=255;dormant[0x8b]=1
	var dormant_result:=Cadence.advance_raw("cadence",clock,{1:dormant},flags)
	check(dormant_result.ok and dormant_result.dispatch_attempts.is_empty() and dormant_result.objects_by_index[1][0x8b]==0,"Unregistered raw type stays safe while its callback timer is not ready")
	check(not Cadence.advance_raw("cadence",clock,dormant_result.objects_by_index,flags).ok,"The same raw type rejects when the next actual dispatch would be unsafe")
	var disabled_flags:=flags.duplicate();disabled_flags[1]=2
	var disabled:=Cadence.advance_raw("cadence",clock,{1:dormant},disabled_flags)
	check(disabled.ok and disabled.objects_by_index[1]==dormant and disabled.dispatch_attempts.is_empty(),"Flagsbit1 gates even dormant out-of-domain selectors exactly")
	for invalid:Variant in [null,true,[],"cadence",1]:
		check(not Cadence.advance_raw("cadence",invalid,objects,flags).ok and not Cadence.advance_raw("cadence",clock,invalid,flags).ok,"Malformed clock or raw-bank container rejects")
	for invalid:Variant in [null,true,[],PackedInt64Array(),PackedByteArray([1]),1]:
		check(not Cadence.advance_raw("cadence",clock,objects,invalid).ok,"Malformed flags reject without conversion")
	for invalid:Variant in [true,{},PackedInt64Array([1]),[21],[-1],[true],[1.5],[1,1],[NAN]]:
		check(not Cadence.advance_raw("cadence",clock,objects,flags,invalid).ok,"Malformed callback-table witness rejects")
	for bad_value:Variant in [-1,true,0x100000000,0.5,NAN,INF,"0"]:
		var bad_clock:=clock.duplicate(true);bad_clock.clock_low_u32=bad_value
		check(not Cadence.advance_raw("cadence",bad_clock,objects,flags).ok,"Invalid raw unsigned timestamp rejects")
	var bad_clock:=clock.duplicate(true);bad_clock.extra=0
	check(not Cadence.advance_raw("cadence",bad_clock,objects,flags).ok,"Unknown clock field rejects")
	for invalid_objects:Dictionary in [{0:body},{115:body},{"1":body},{1:[]},{1:PackedByteArray([0])}]:
		check(not Cadence.advance_raw("cadence",clock,invalid_objects,flags).ok,"Invalid stable index or full raw object shape rejects")
	var ready_bad:=body.duplicate();ready_bad[0x87]=255
	var early:=body.duplicate();early[0x86]=114
	var late_flags:=flags.duplicate();late_flags[114]=1
	var later:Dictionary={1:ready_bad,114:early};var later_before:=objects_digest(later)
	var effect:Dictionary={"trigger_index_u8":114,"target_index_u8":1,"offset_u16":0,"value_u8":99}
	check(not Cadence.advance_raw("cadence",clock,later,late_flags,[1],[effect]).ok and objects_digest(later)==later_before,"A later invalid selector rejects the entire private earlier-callback transaction")
	var missing_flags:=flags.duplicate();missing_flags[114]=1
	check(not Cadence.advance_raw("cadence",clock,objects,missing_flags).ok and objects_digest(objects)==frozen,"Missing eligible record rejects without publishing an earlier partial bank")
	var invalid_effects:Array=[null,true,{},[{}],[effect.duplicate(true)]]
	invalid_effects[-1][0].offset_u16=338
	var e:=effect.duplicate(true);e.target_index_u8=2;invalid_effects.append([e])
	e=effect.duplicate(true);e.value_u8=256;invalid_effects.append([e])
	e=effect.duplicate(true);e.value_u8=true;invalid_effects.append([e])
	e=effect.duplicate(true);e.extra=0;invalid_effects.append([e])
	var too_many:Array=[]
	for _i:int in range(17):too_many.append(effect.duplicate(true))
	invalid_effects.append(too_many)
	for invalid:Variant in invalid_effects:check(not Cadence.advance_raw("cadence",clock,objects,flags,[1],invalid).ok,"Invalid or unowned declared byte effect rejects atomically")
	for bad_index:Variant in [0,2,115,-1,true,NAN]:check(not Cadence.advance_raw("dispatch",clock,objects,flags,[1],[],bad_index,1).ok,"DirectF144 requires a provided stable object index")
	for bad_type:Variant in [-1,21,true,NAN]:check(not Cadence.advance_raw("dispatch",clock,objects,flags,[1],[],1,bad_type).ok,"DirectF144 protects the original21-entry selector domain")
	check(not Cadence.advance_raw("unknown",clock,objects,flags).ok and objects_digest(objects)==frozen and flags.hex_encode()==frozen_flags,"All rejected envelopes leave original raw owners unchanged")
	var sources:Dictionary={}
	for path:String in ["scripts/source_object_cadence.gd","scripts/source_clock_pipeline.gd","scripts/source_reference_bank.gd","tests/test_source_object_cadence.gd","tests/fixtures/source_object_cadence_native.json","tools/rebuild_source_object_cadence_native.py","validation/player-dispatch-2026-11-17/cadence-native-proof/instruction-proof.json","validation/player-dispatch-2026-11-17/cadence-native-proof/source-procedures.asm"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"))
	var file:=FileAccess.open("res://build/current-test-reports/source-object-cadence.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":"starfrontier-source-object-cadence-tests-v1","checks":checks,"failures":failures,"sources":sources,"native_cases":265,"native_sequence_steps":32,"scope":"Whole DOS F149/F144 cadence/control request trace parity with explicit original/default or supplied event5 callback presence. Observed indexed-byte effects only; no original handler bodies, complete player/world scheduler, Main or Android proof."},"\t"));file.close()
	print("SOURCE OBJECT CADENCE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
