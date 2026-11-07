extends SceneTree
# DOS-native original instruction outputs are the oracle. The F938 comparison
# intentionally covers its fuel tail, not shield/hull/cooldown maintenance.
const Core=preload("res://scripts/source_jet_fuel.gd")
const FIXTURE:="res://tests/fixtures/source_jet_fuel_native.json"
var checks:=0
var failures:=0
var domains:Dictionary={}
var domain_failures:Dictionary={}
var evidence:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=40:push_error(message)
func words_equal(actual:Array,expected:Array)->bool:
	if actual.size()!=expected.size():return false
	for index in range(actual.size()):
		if (int(actual[index])&0xffffffff)!=(int(expected[index])&0xffffffff):return false
	return true
func state_from(object:PackedByteArray,globals:Dictionary)->Dictionary:
	var thrust:Array=[]
	for index in range(6):thrust.append(int(object.decode_u16(0xbc+index*2)))
	var cached:Array=[]
	for value:Variant in globals.get("cached_thrust_u32",globals.get("cached_thrust_words_u16",[])):cached.append(int(value)&65535)
	return {"jet_raw_u32":int(object.decode_u32(0x11e)),"object_index_u8":int(object[0x86]),"drive_index_s8":int(object[0xd0])-256 if object[0xd0]>=128 else int(object[0xd0]),"npc_fuel_u8":int(object[0x119]),"auto_refueller":bool(object[0xc8]&2),"thrust_u16":thrust,"cached_thrust_u16":cached,"player_object_index_u32":int(globals.player_object_index_u32),"status_u16":int(globals.status_u16),"cargo_s32":int(globals.cargo_s32),"hydrogen_u16":int(globals.hydrogen_u16),"military_u16":int(globals.military_u16),"waste_u16":int(globals.waste_u16)}
func native_cases()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture is Dictionary and fixture.get("schema")==1 and fixture.get("source_sha256")==Core.SOURCE_SHA,"Native jet fixture identifies original uploaded DOS executable")
	if not fixture is Dictionary:return
	check(fixture.get("fresh_process_runs")==3 and fixture.get("canaries_unchanged",false),"Original native routines were independently repeated with guarded buffers")
	for id:String in ["289","929","938"]:
		check(fixture.dos_instruction_proof[id].all_instructions_equal_after_only_branch_destination_normalization,"Every reassembled source instruction matches actual DOS procedure "+id)
	for id:String in ["cooling","cadence"]:
		check(fixture.dos_slice_instruction_proof[id].get("all_instructions_equal",false),"Every bounded thermal/cadence instruction matches the actual DOS slice "+id)
	for at in range(fixture.cases.size()):
		var sample:Dictionary=fixture.cases[at];var operation:=str(sample.operation);var label:="native%d %s"%[at,operation];var previous_failures:=failures
		domains[operation]=int(domains.get(operation,0))+1
		var expected:Dictionary=sample.expected;var object:=str(sample.object_hex).hex_decode();var globals:Dictionary=sample.globals
		var state:=state_from(object,globals);var before:=var_to_bytes(state);var events:Array=[];var callbacks:Array=[];var consume_calls:=0;var last_debit:=0
		if operation=="cooling":
			var cooled:=Core.cooling(int(sample.heat_s32),int(sample.step_s32),bool(sample.shield_bool))
			check(cooled.ok and int(cooled.heat_s32)==int(expected.heat_s32),label+" exact original F1007 thermal-head signed subtraction/clamp")
		elif operation=="cadence":
			var advanced:=Core.cadence(int(sample.current_tick_u32),int(sample.last_tick_u32))
			check(advanced.ok and int(advanced.whole_seconds)==int(expected.whole_seconds),label+" exact original F152 whole-second quotient")
			check(int(advanced.last_processed_tick_u32)==int(expected.updated_last_tick_u32),label+" exact original F152 processed-clock stamp with wrap")
		elif operation=="initial_profile":
			check(Core.npc_initial_jet_raw(int(object[0xd0]))==int(str(expected.object_hex).hex_decode().decode_u32(0x11e)),label+" exact DATA6266/SHL24 initial NPC jet raw")
		else:
			for iteration in range(int(sample.get("repeat_count",1))):
				var state_before:=var_to_bytes(state)
				var result:Dictionary
				if operation=="F289":result=Core.manual_refuel(state,Core.jet_capacity_raw(int(object[0xd0])))
				elif operation=="F929":last_debit=int(sample.amount_u32);result=Core.consume(state,last_debit);consume_calls+=1
				elif operation=="F938":
					var spec:=str(sample.spec_hex).hex_decode();var mass:=int(spec.decode_s16(6));var commands:Array=[]
					for index in range(3):commands.append(int(object.decode_s16(0xb6+index*2)))
					result=Core.fuel_step(state,mass,commands,int(sample.step_s32));last_debit=int(result.consumption.amount_u32);consume_calls+=1
				else:check(false,label+" supported native operation");break
				check(result.ok,label+" valid source input is accepted: "+str(result.get("reason","")))
				check(var_to_bytes(state)==state_before,label+" immutable state boundary on depletion/manual refill")
				events.append_array(result.events);callbacks.append_array(result.callbacks);state=result.state
			var actual_expected:=state_from(str(expected.object_hex).hex_decode(),expected.globals)
			for key:String in Core.STATE_KEYS:
				check(words_equal(state[key],actual_expected[key]) if state[key] is Array else state[key]==actual_expected[key],label+" exact DOS projected fuel state "+key+" actual="+str(state[key])+" expected="+str(actual_expected[key]))
			check(words_equal(events,expected.messages_u32),label+" exact source alert sequence")
			check(callbacks.count(287)==int(expected.refresh_call_count) and callbacks.count(293)==int(expected.no_fuel_call_count),label+" exact source manual GUI callback boundaries")
			check(consume_calls==int(expected.consume_call_count),label+" exact source depletion call count")
			if consume_calls>0:check(last_debit==int(expected.debit_u32_last),label+" exact raw F938 demand/F929 entry debit")
		check(var_to_bytes(state_from(object,globals))==before,label+" native caller input buffers remain unchanged")
		if failures>previous_failures:domain_failures[operation]=int(domain_failures.get(operation,0))+failures-previous_failures
	var every_case:bool=domains.size()==fixture.operation_counts.size()
	for key:String in domains:every_case=every_case and int(domains[key])==int(fixture.operation_counts.get(key,-1))
	check(every_case and int(fixture.reverse_repeat_count)==fixture.cases.size(),"Every canonical DOS native case is consumed once and independently repeated in reverse order")
	var counter:Dictionary=fixture.jjffe_counterfactual
	check(counter.not_canonical_dos and counter.case_count==128 and counter.difference_count==counter.differences.size(),"The later JJFFE behavior is explicitly separate from the uploaded DOS reference")
	for sample:Dictionary in counter.differences:
		var state:=state_from(str(sample.object_hex).hex_decode(),sample.globals)
		for iteration in range(int(sample.repeat_count)):state=Core.consume(state,int(sample.amount_u32)).state
		var dos:=state_from(str(sample.expected_dos.object_hex).hex_decode(),sample.expected_dos.globals)
		var jjffe:=state_from(str(sample.expected_jjffe.object_hex).hex_decode(),sample.expected_jjffe.globals)
		check(words_equal(state.thrust_u16,dos.thrust_u16) and not words_equal(state.thrust_u16,jjffe.thrust_u16),"Default kernel preserves the independently observed DOS/JJFFE nozzle-policy difference")
	evidence.append({"native_cases":fixture.get("case_count",fixture.cases.size()),"operations":domains,"domain_failures":domain_failures,"source_policy":Core.SOURCE_POLICY,"jjffe_counterfactual_cases":counter.case_count,"jjffe_counterfactual_differences":counter.difference_count,"scope":"F929 and F289 projected raw fuel/global/six-word results; F938 fuel tail only, excluding maintenance side effects. Supplementary F1007 cooling head and F152 cadence are bounded instruction slices, not complete event handlers."})
func baseline()->Dictionary:
	return {"jet_raw_u32":Core.RAW_PER_TONNE,"object_index_u8":1,"drive_index_s8":3,"npc_fuel_u8":0,"auto_refueller":false,"thrust_u16":[101,102,103,104,105,106],"cached_thrust_u16":[201,202,203,204,205,206],"player_object_index_u32":1,"status_u16":0,"cargo_s32":10,"hydrogen_u16":4,"military_u16":4,"waste_u16":0}
func boundaries()->void:
	var source:=baseline();var before:=var_to_bytes(source)
	var equal:=Core.consume(source,Core.RAW_PER_TONNE)
	check(equal.ok and equal.state.jet_raw_u32==0 and equal.state.thrust_u16==[0,102,0,104,0,106],"DOS equality exhausts the tank and preserves all three reverse-direction limits")
	check(equal.events==[0x9907] and equal.state.status_u16==1 and equal.disabled_axes_mask_u8==0x15,"Empty-player warning is latched once and exact unavailable-axis mask is0x15")
	var again:=Core.consume(equal.state,0)
	check(again.events.is_empty() and again.state.thrust_u16==equal.state.thrust_u16,"An empty zero-demand update cannot duplicate the warning or disable reverse thrust")
	var replenished:Dictionary=equal.state.duplicate(true);replenished.jet_raw_u32=10
	var spent:=Core.consume(replenished,1)
	check(spent.state.jet_raw_u32==9 and spent.state.thrust_u16==equal.state.thrust_u16,"Ordinary DOS debit does not silently apply JJFFE's six-axis restoration patch")
	var feeder:Dictionary=equal.state.duplicate(true);feeder.auto_refueller=true
	var auto:=Core.consume(feeder,0xffffffff)
	check(auto.refilled and auto.state.jet_raw_u32==Core.RAW_PER_TONNE and auto.state.hydrogen_u16==3 and auto.state.cargo_s32==9,"Automatic feeder transfers exactly one hydrogen tonne without residual debit")
	check(auto.state.thrust_u16==equal.state.thrust_u16 and auto.state.status_u16==1,"Automatic refill preserves source disabled axes and the empty-warning latch")
	var manual:=Core.manual_refuel(equal.state,Core.jet_capacity_raw(3))
	check(manual.accepted and manual.state.thrust_u16==source.cached_thrust_u16 and manual.state.status_u16==0,"Original manual F289 refuel restores all six cached limits and clears warning bit0")
	check(manual.state.jet_raw_u32==Core.RAW_PER_TONNE and manual.state.hydrogen_u16==3,"Manual refuel uses the same source one-tonne conversion")
	var military:=source.duplicate(true);military.drive_index_s8=11;military.auto_refueller=true;military.jet_raw_u32=0;military.waste_u16=65535
	var military_after:=Core.consume(military,1)
	check(military_after.state.military_u16==3 and military_after.state.waste_u16==0 and military_after.state.cargo_s32==10,"Military feeder replaces fuel with u16 radioactive waste without changing source cargo")
	var npc:=source.duplicate(true);npc.object_index_u8=2;npc.jet_raw_u32=0;npc.npc_fuel_u8=1
	var npc_after:=Core.consume(npc,0)
	check(npc_after.refilled and npc_after.state.npc_fuel_u8==0 and npc_after.state.hydrogen_u16==4,"NPC refill uses its own byte inventory even without an automatic feeder")
	check(Core.jet_capacity_raw(9)==0xffffffff and Core.npc_initial_jet_raw(9)==0xff000000,"Player manual capacity and NPC initial tank are distinct verified source tables")
	check(Core.jet_capacity_raw(14)==0x20000000 and Core.npc_initial_jet_raw(14)==0,"Special drive14 retains distinct capacity and initial amount")
	for axis in range(3):
		var positive:Array=[0,0,0];positive[axis]=32767;var negative:Array=[0,0,0];negative[axis]=-32767
		check(Core.consumption(100,positive,17).amount_u32==Core.consumption(100,negative,17).amount_u32,"Positive and reverse thrust on each of three signed axes consume equal source magnitude "+str(axis))
	check(Core.consumption(100,[0,0,0],17).amount_u32==0 and Core.consumption(100,[32767,-32768,1],0).amount_u32==0,"Zero actual thrust or zero source update quantum has zero F938 demand")
	check(var_to_bytes(source)==before,"Every source fuel quote leaves its input dictionary immutable")
	var invalid:=source.duplicate(true);invalid.thrust_u16=[1,2]
	check(not Core.consume(invalid,1).ok and var_to_bytes(Core.consume(invalid,1).state)==var_to_bytes(invalid),"Malformed six-axis state rejects atomically")
	check(not Core.consumption(32768,[0,0,0],1).ok and not Core.consumption(100,[32768,0,0],1).ok,"Out-of-width source mass and thrust commands reject explicitly")
	check(not Core.consume(source,-1).ok and not Core.manual_refuel(source,-1).ok,"Negative raw unsigned amount/capacity rejects before changing inventory")
	var invalid_drive:=source.duplicate(true);invalid_drive.drive_index_s8=-1
	check(not Core.manual_refuel(invalid_drive,1).ok and Core.consume(invalid_drive,1).ok,"F289 guards unsigned table lookup while F929 retains valid signed-byte semantics")
	check(Core.cadence(49709,0).whole_seconds==0 and Core.cadence(49710,0).whole_seconds==1,"F152 event cadence crosses precisely49710 master ticks rather than every frame")
	var wrap:=Core.cadence(49609,0xffffff9b)
	check(wrap.whole_seconds==1 and wrap.last_processed_tick_u32==49609 and wrap.remainder_ticks==0,"F152 elapsed-display-second cadence preserves unsigned tick rollover")
	for fps in [30,60,120]:
		var last:=0;var delivered:=0
		for frame_index in range(1,fps*10+1):
			var tick:=int(frame_index*497100.0/(fps*10));var update:=Core.cadence(tick,last)
			delivered+=int(update.whole_seconds);last=int(update.last_processed_tick_u32)
		check(delivered==10 and last==497100,"Raw cadence delivers the same10 source seconds with no frame-rate loss or repetition at%dFPS"%fps)
	check(Core.cooling(10000,1,false).heat_s32==9872 and Core.cooling(10000,1,true).heat_s32==9488,"Original cooling uses128 or512 raw heat per source display second")
	check(Core.cooling(1,1).heat_s32==0 and Core.cooling(0,-1).heat_s32==0,"Original cooling clamps after subtraction while a zero heat field skips the entire branch")
	check(Core.cooling(2147483647,-1).heat_s32==0 and Core.cooling(-2147483648,1).heat_s32==2147483520,"Thermal subtraction preserves source signed32 wrap before its negative clamp")
	check(not Core.cooling(2147483648,1).ok and not Core.cadence(-1,0).ok,"Out-of-width thermal and source-clock values reject explicitly")
func run()->void:
	native_cases();boundaries()
	var path:="res://validation/jet-fuel-2026-11-07/source-jet-fuel-core.json";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()));var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"evidence":evidence,"scope":"Uploaded DOS F929, F938 jet consumption tail, F289 cargo-to-jet refuelling, bounded F1007 cooling head and F152 display-second cadence arithmetic. Excludes other shield/hull/laser maintenance, complete event/player thermal handlers, live integration and scoop/contact heat production.","sources":{"core_sha256":FileAccess.get_sha256("res://scripts/source_jet_fuel.gd"),"test_sha256":FileAccess.get_sha256("res://tests/test_source_jet_fuel.gd"),"fixture_sha256":FileAccess.get_sha256(FIXTURE),"resource_sha256":FileAccess.get_sha256(Core.DATA_PATH)}},"\t"))
	print("Source jet fuel: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
