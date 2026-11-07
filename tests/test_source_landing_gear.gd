extends SceneTree
# Original DOS instruction output, rather than a duplicate source formula,
# supplies every canonical expected state and callback sequence below.
const Core=preload("res://scripts/source_landing_gear.gd")
const FIXTURE:="res://tests/fixtures/source_landing_gear_native.json"
const REPORT:="res://validation/gear-2026-11-08/source-landing-gear-core.json"
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
func baseline()->Dictionary:
	return {"position_u16":0,"object_timer_u16":17,"autopilot_phase_u8":0,"flight_state_u8":0,"control_flags_u8":0,"warning_flags_u16":0,"speed_s32":0}
func raw_callbacks(callbacks:Array)->Array:
	var result:Array=[]
	for callback:Dictionary in callbacks:
		var number:=int(str(callback.function).trim_prefix("F"));var args:Array=[]
		match number:
			262:args=[callback.button,callback.image]
			1097:args=[callback.message,callback.priority_s32]
			1906:args=[callback.sample]
		var row:Array=[number,0,0,0]
		for index in range(args.size()):row[index+1]=int(args[index])&0xffffffff
		result.append(row)
	return result
func equal_words(actual:Variant,expected:Variant)->bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size()!=expected.size():return false
		for key:Variant in actual:
			if not expected.has(key) or not equal_words(actual[key],expected[key]):return false
		return true
	if actual is Array and expected is Array:
		if actual.size()!=expected.size():return false
		for index in range(actual.size()):
			if not equal_words(actual[index],expected[index]):return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):return int(actual)==int(expected)
	return actual==expected
func native_cases()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture is Dictionary and fixture.get("schema_version")==1 and fixture.get("executable_sha256")==Core.SOURCE_SHA,"Landing-gear reference identifies the uploaded DOS executable")
	if not fixture is Dictionary:return
	for name:String in ["F1008","F1056_JUMP_004410"]:
		check(fixture.byte_instruction_proofs.get(name,{}).get("all_instructions_equal_after_branch_destination_normalization",false),"Every selected source instruction matches actual DOS "+name)
	check(fixture.byte_instruction_proofs.F1008.instruction_count==72 and fixture.byte_instruction_proofs.F1056_JUMP_004410.instruction_count==32,"Full F1008 and only the bounded F1056 branch have their stated104-instruction scope")
	var execution:Dictionary=fixture.execution_checks
	check(execution.fresh_identical_processes==3 and execution.reverse_case_order_identical and execution.object_globals_output_canaries and execution.unrelated_bytes_unchanged and not execution.expected_transitions_computed_by_python,"Fresh native runs and reverse order retain guarded unrelated object/global bytes")
	var cases_by_id:Dictionary={}
	for sample:Dictionary in fixture.cases:
		var label:=str(sample.id)+" "+str(sample.operation);var operation:=str(sample.operation);var old_failures:=failures
		cases_by_id[str(sample.id)]=sample;domains[operation]=int(domains.get(operation,0))+1
		var original:=var_to_bytes(sample);var state:Dictionary=sample.state.duplicate(true);var callbacks:Array=[]
		for iteration in range(int(sample.repeat_count)):
			var operations:Array=[]
			match operation:
				"F1008":operations=["step"]
				"toggle":operations=["toggle"]
				"toggle_then_step":operations=["toggle","step"]
				"step_then_toggle":operations=["step","toggle"]
				_:check(false,label+" has an explicit native operation");break
			for action:String in operations:
				var before:=var_to_bytes(state);var result:Dictionary=Core.toggle(state) if action=="toggle" else Core.step(state,sample.step_ticks_u32)
				check(result.ok,label+" accepts its native "+action+" input")
				check(var_to_bytes(state)==before,label+" leaves the caller state immutable on "+action)
				if not result.ok:break
				state=result.state;callbacks.append_array(result.callbacks)
		for key:String in Core.STATE_KEYS:check(equal_words(state[key],sample.expected.state[key]),label+" exact native field "+key+" actual="+str(state[key])+" expected="+str(sample.expected.state[key]))
		check(equal_words(raw_callbacks(callbacks),sample.expected.callbacks_raw_u32),label+" exact native GUI/warning/sound callback order and arguments")
		check(var_to_bytes(sample)==original,label+" does not alter the independent native fixture")
		if failures>old_failures:domain_failures[operation]=int(domain_failures.get(operation,0))+failures-old_failures
	var literal_checks:=0
	for control:Dictionary in fixture.independent_literal_controls:
		var sample:Dictionary=cases_by_id[str(control.case_id)];var okay:bool=control.passed
		for key:String in control.literal_state_subset:okay=okay and equal_words(sample.expected.state[key],control.literal_state_subset[key])
		okay=okay and equal_words(sample.expected.callbacks_raw_u32,control.literal_callbacks_raw_u32)
		check(okay,"Independent fixed literal control "+str(control.name));literal_checks+=1
	check(literal_checks==10,"All ten independently authored gear literal controls are retained")
	var total:=0
	for count:Variant in domains.values():total+=int(count)
	check(total==int(fixture.case_count) and total==fixture.cases.size() and domains.size()==4,"Every canonical native case is consumed once across all four original operation compositions")
	check(fixture.known_dos_jjffe_differences.is_empty(),"These two bounded source regions were compared without importing a JJFFE-only correction")
	var warning:Dictionary=fixture.warning_resource;var text:=str(warning.hex).hex_decode().get_string_from_utf8()
	check(int(warning.ff_code_u16)==Core.WARNING_MESSAGE and text.contains("Undercarriage down.") and text.contains("micrometeorites"),"Original warning literal proves the deployed-gear meaning without claiming a micrometeorite damage implementation")
	evidence.append({"native_cases":total,"operations":domains.duplicate(true),"domain_failures":domain_failures.duplicate(true),"full_procedure_instruction_count":fixture.byte_instruction_proofs.F1008.instruction_count,"bounded_toggle_instruction_count":fixture.byte_instruction_proofs.F1056_JUMP_004410.instruction_count,"independent_literal_controls":literal_checks,"warning_resource":warning,"scope":fixture.scope,"raw_semantics":fixture.raw_semantics})

func contracts_and_boundaries()->void:
	var state:=baseline();var original:=var_to_bytes(state)
	var deploy:=Core.step(state,2)
	check(deploy.requested_down and deploy.state.position_u16==1 and deploy.moving and not deploy.deployed,"A clear source command bit physically deploys the gear; zero position itself is retracted")
	var up:=state.duplicate(true);up.control_flags_u8=0x42;up.position_u16=1
	var retracted:=Core.step(up,2)
	check(not retracted.requested_down and retracted.retracted and not retracted.moving and retracted.state.control_flags_u8==0x42,"A set source command bit retracts toward zero while preserving other command bits")
	var toggle:=state.duplicate(true);toggle.control_flags_u8=0x40;toggle.warning_flags_u16=0xffff
	var requested:=Core.toggle(toggle)
	check(requested.accepted and requested.state.control_flags_u8==0x42 and requested.state.warning_flags_u16==0xfffd,"A selected toggle changes only the request bit and clears only its warning latch")
	check(requested.state.position_u16==toggle.position_u16 and requested.state.flight_state_u8==toggle.flight_state_u8 and requested.state.autopilot_phase_u8==toggle.autopilot_phase_u8,"The bounded toggle does not move the mechanism or force flight/autopilot state")
	check(raw_callbacks(requested.callbacks)==[[262,56,0,0],[262,70,0,0],[1116,0,0,0],[1906,12,0,0],[1906,20,0,0]],"Original retract-command image and sound requests retain both console button IDs")
	toggle.autopilot_phase_u8=0x24;var blocked:=Core.toggle(toggle)
	check(blocked.ok and not blocked.accepted and blocked.state==toggle and raw_callbacks(blocked.callbacks)==[[1906,20,0,0]],"Protected phase0x24 blocks toggling but retains the source action sound")
	var automatic:=state.duplicate(true);automatic.flight_state_u8=2;automatic.autopilot_phase_u8=30;automatic.warning_flags_u16=0xffff
	var forced:=Core.step(automatic,0);var repeated:=Core.step(forced.state,0)
	check(forced.state.control_flags_u8==2 and forced.state.warning_flags_u16==0xfffd and raw_callbacks(forced.callbacks)==[[1116,0,0,0]] and repeated.callbacks==forced.callbacks,"Automatic phase30 forces retraction and refreshes on every source invocation even at zero ticks")
	automatic.autopilot_phase_u8=31;automatic.control_flags_u8=2
	forced=Core.step(automatic,0);repeated=Core.step(forced.state,0)
	check(forced.requested_down and forced.state.control_flags_u8==0 and raw_callbacks(forced.callbacks)==[[1116,0,0,0]] and repeated.callbacks.is_empty(),"Automatic phase31 deploys and refreshes only on the original command transition")
	automatic.autopilot_phase_u8=255
	check(Core.step(automatic,0).requested_down,"Automatic phase is compared as an unsigned byte, including255")
	var fast:=state.duplicate(true);fast.speed_s32=100000
	var warned:=Core.step(fast,0);var latched:=Core.step(warned.state,0)
	check(raw_callbacks(warned.callbacks)==[[1097,0x98ce,0xffffffff,0]] and latched.callbacks.is_empty() and warned.state.warning_flags_u16==2,"The exact signed speed threshold warns once even without elapsed animation ticks")
	fast.speed_s32=99999
	check(Core.step(fast,0).callbacks.is_empty(),"One raw speed unit below the source warning threshold does not warn")
	fast.speed_s32=-2147483648
	check(Core.step(fast,0).callbacks.is_empty(),"The source speed comparison retains signed32 semantics")
	var latched_up:Dictionary=warned.state.duplicate(true);latched_up.control_flags_u8=2
	check(Core.step(latched_up,2).state.warning_flags_u16==2,"Retracting alone does not silently clear the original warning latch")
	var first:=Core.step(state,1);var second:=Core.step(first.state,1)
	check(second.state.position_u16==0 and Core.step(state,2).state.position_u16==1,"Odd master ticks are truncated per invocation; a caller must not invent fractional gear travel")
	check(Core.step(state,131070).deployed and Core.step(up,0xffffffff).retracted,"Large unsigned tick steps saturate the physical endpoints without wrap")
	var timer:=state.duplicate(true);timer.object_timer_u16=17
	check(Core.step(timer,17).state.object_timer_u16==0 and Core.step(timer,16).state.object_timer_u16==1 and Core.step(timer,65536).state.object_timer_u16==0,"The separate object timer retains unsigned equality and over-word clamp behavior")
	check(var_to_bytes(state)==original,"All kernel operations preserve the caller dictionary")
	var tagged:=state.duplicate(true);tagged["metadata"]={"ids":[1]};var isolated:=Core.step(tagged,2);isolated.state.metadata.ids[0]=2
	check(tagged.metadata.ids==[1],"Returned metadata is deeply isolated from the caller")
	for key:String in Core.STATE_KEYS:
		var missing:=state.duplicate(true);missing.erase(key);var rejected:=Core.step(missing,1)
		check(not rejected.ok and rejected.state==missing and rejected.callbacks.is_empty(),"Missing source field rejects atomically: "+key)
	for invalid:Variant in [-1,0x100000000,0.5,INF,NAN,"1",true]:
		var rejected:=Core.step(state,invalid)
		check(not rejected.ok and rejected.state==state and rejected.callbacks.is_empty(),"Invalid unsigned master ticks reject before any original callback: "+str(invalid))
	for pair:Array in [["position_u16",65536],["object_timer_u16",-1],["autopilot_phase_u8",256],["flight_state_u8",-1],["control_flags_u8",256],["warning_flags_u16",65536],["speed_s32",2147483648],["speed_s32",0.25]]:
		var invalid:=state.duplicate(true);invalid[pair[0]]=pair[1];var rejected:=Core.toggle(invalid)
		check(not rejected.ok and rejected.state==invalid and rejected.callbacks.is_empty(),"Out-of-width source field rejects atomically: "+str(pair))
	evidence.append({"case":"kernel_boundary_policy","requested_down_bit_clear":true,"physical_deployed_position":65535,"physical_retracted_position":0,"gear_fractional_travel_accumulator_added":false,"full_F1056_dispatch_claim":false,"micrometeorite_damage_claim":false})

func run()->void:
	native_cases();contracts_and_boundaries()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	var sources:={"core_sha256":FileAccess.get_sha256("res://scripts/source_landing_gear.gd"),"test_sha256":FileAccess.get_sha256("res://tests/test_source_landing_gear.gd"),"fixture_sha256":FileAccess.get_sha256(FIXTURE),"native_generator_sha256":FileAccess.get_sha256("res://tools/rebuild_source_landing_gear_native.py")}
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"domains":domains,"domain_failures":domain_failures,"sources":sources,"evidence":evidence,"scope":"Uploaded DOS complete F1008 timer/automatic gear/warning/position transitions and bounded F1056 undercarriage toggle branch versus independently executed instruction-matched controls. GUI/sound are observed requests; full keyboard/flight dispatcher, game save/session, host cadence, physical renderer and micrometeorite damage remain separate."},"\t"));file.close()
	print("Source landing gear: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
