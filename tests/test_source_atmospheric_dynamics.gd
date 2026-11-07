extends SceneTree
# Canonical expected outputs come from independently executed, DOS-matched
# instructions. Boundary cases below name caller contracts and source quirks;
# they do not replace that oracle with a second copy of the implementation.
const Core=preload("res://scripts/source_atmospheric_dynamics.gd")
const FIXTURE:="res://tests/fixtures/source_atmospheric_native.json"
const REPORT:="res://validation/thermal-2026-11-07/source-atmospheric-core.json"
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
func atmosphere_state()->Dictionary:
	return {"altitude_s32":1000,"speed_s32":4096,"heat_s32":0,"velocity_s32":[1048576,-1048576,1],"shielding":false,"gear_down":false,"wind_enabled":false,"wind_armed":false,"parent_shield_s16":278,"wind_flags_u8":0}
func damage_state()->Dictionary:
	return {"object_index_u8":7,"kind_u8":3,"volume_s8":-12,"player_selector_u8":255,"shield_u16":5,"hull_u16":400,"damage_timer_u8":0,"damage_flags_u8":0}
func boundaries()->void:
	var source:=atmosphere_state();var before:=var_to_bytes(source)
	var zero_time:=Core.atmosphere(source,0)
	check(zero_time.ok and zero_time.state.heat_s32==256 and zero_time.state.velocity_s32==source.velocity_s32,"DOS adds its per-invocation heat even at zero elapsed master ticks; drag stays zero")
	check(zero_time.damage_calls==[{"amount_s32":1,"attacker_u32":0}],"DOS incremental heat damage is increment SAR8 rather than a JJFFE threshold alarm")
	var geared:=source.duplicate(true);geared.gear_down=true
	check(Core.atmosphere(geared,0).state.heat_s32==128 and Core.atmosphere(geared,0).damage_calls.is_empty(),"Original gear bit changes the shift by exactly one and affects incremental damage")
	var shielded:=source.duplicate(true);shielded.shielding=true
	check(Core.atmosphere(shielded,0).state.heat_s32==4,"Original atmospheric shielding uses its DOS10-bit shift with gear retracted")
	var above:=source.duplicate(true);above.altitude_s32=20000001
	check(Core.atmosphere(above,0xffffffff).state==above and Core.atmosphere(above,0xffffffff).callbacks.is_empty(),"Altitude strictly above20million skips heat, wind, damage and drag")
	above.altitude_s32=20000000
	check(Core.atmosphere(above,1).heat_increment_s32==256,"The exact20million altitude boundary is included")
	above.altitude_s32=2147483647
	check(Core.atmosphere(above,1).state==above,"F1033-normalized unknown-height sentinel cannot manufacture atmospheric effects")
	above.altitude_s32=-1
	check(Core.atmosphere(above,1).heat_increment_s32==256,"Untouched raw−1 is a different DOS input and must be normalized by the caller")
	var fatal:=source.duplicate(true);fatal.speed_s32=16;fatal.heat_s32=65535
	var overheated:=Core.atmosphere(fatal,0)
	check(overheated.overheat_requested and overheated.state.heat_s32==65535 and overheated.damage_calls==[{"amount_s32":-1,"attacker_u32":0}],"Fatal DOS heat requests F953−1 without storing the overflowing heat candidate")
	fatal.heat_s32=65534
	check(not Core.atmosphere(fatal,0).overheat_requested and Core.atmosphere(fatal,0).state.heat_s32==65535,"Exactly65535 heat remains below the strict destruction comparison")
	fatal.heat_s32=2147483647
	check(Core.atmosphere(fatal,0).state.heat_s32==-2147483648 and not Core.atmosphere(fatal,0).overheat_requested,"Original signed32 overflow is preserved rather than silently saturated")
	var capped:=Core.atmosphere(source,0xfffff);var greater:=Core.atmosphere(source,0xffffffff)
	check(capped.state.velocity_s32==[1,-1,1] and capped.state.velocity_s32==greater.state.velocity_s32,"DOS drag retains its20-bit cap and signed Q31 rounding on all axes")
	var rounding:=source.duplicate(true);rounding.velocity_s32=[1,-1,0]
	check(Core.atmosphere(rounding,0xfffff).state.velocity_s32==[1,0,0],"Negative one-raw-unit drag follows x86 arithmetic-shift rounding")
	var wind:=source.duplicate(true);wind.wind_enabled=true;wind.wind_armed=true;wind.parent_shield_s16=-1;wind.wind_flags_u8=3
	var windy:=Core.atmosphere(wind,0)
	check(windy.state.wind_flags_u8==0x43 and windy.callbacks.has({"function":"F1906","sample":14}),"DOS wind compares the lookup object's shield word as signed and preserves other flags")
	wind.parent_shield_s16=278
	check(Core.atmosphere(wind,0).state.wind_flags_u8==3,"Exactly278 lookup shield does not request atmospheric wind sound")
	check(var_to_bytes(source)==before,"Atmosphere leaves the complete caller dictionary immutable")
	var hp:=damage_state();var hp_before:=var_to_bytes(hp)
	var exact_shield:=Core.damage(hp,5)
	check(exact_shield.state.shield_u16==0 and exact_shield.state.hull_u16==400 and exact_shield.state.damage_flags_u8==1 and not exact_shield.destruction_requested,"Exact shield damage depletes only the shield, with the original hit latch")
	var exact_hull:=Core.damage(hp,405)
	check(exact_hull.destruction_requested and exact_hull.state.shield_u16==0 and exact_hull.state.hull_u16==400,"Exact residual hull damage requests F942; its unexecuted cascade is not fabricated as a raw hull write")
	var partial:=Core.damage(hp,13,0,{"rng_u32":65535})
	check(partial.state.hull_u16==392 and partial.state.damage_timer_u8==10 and partial.rng_consumed and not partial.equipment_damage_requested,"Small penetrating damage updates raw hull/timer and executes one probabilistic equipment check")
	check(Core.damage(hp,13,0,{"rng_u32":0}).equipment_damage_requested,"The source probability branch can request F952 without inventing a repaired equipment model")
	var negative:=Core.damage(hp,1,0,{"filtered_damage_s32":-1})
	check(negative.state.shield_u16==6 and negative.state.hull_u16==400,"Explicit negative event-filter output retains the original signed comparison and word subtraction")
	check(Core.damage(hp,-1).destruction_requested and Core.damage(hp,-1).normalized_damage_s32==2147483647,"A negative direct damage argument is normalized before the source variable bus")
	var other:=hp.duplicate(true);other.kind_u8=9
	check(Core.damage(other,2147483647).state==other,"Unsupported object kinds receive only their source callback/sound branch")
	other.kind_u8=11
	check(Core.damage(other,2147483647,0,{"object_flags_u8":16}).state==other and Core.damage(other,2147483647,0,{"has_spec":false}).state==other,"Type11 eligibility respects the original object flag and descriptor guard")
	check(var_to_bytes(hp)==hp_before,"Damage leaves the caller's shield/hull dictionary immutable")
	var missing:=Core.damage(hp,13)
	check(not missing.ok and missing.state==hp and missing.callbacks.is_empty(),"Missing RNG on a reached probabilistic branch rejects atomically")
	var invalid:=source.duplicate(true);invalid.velocity_s32=[1,2]
	check(not Core.atmosphere(invalid,1).ok and Core.atmosphere(invalid,1).state==invalid,"Malformed source velocity rejects without a partial heat write")
	for value:Variant in [-1,0x100000000,0.5,INF,NAN,"1"]:
		check(not Core.atmosphere(source,value).ok,"Out-of-domain master ticks reject before atmospheric state changes: "+str(value))
	invalid=hp.duplicate(true);invalid.hull_u16=65536
	check(not Core.damage(invalid,1).ok and Core.damage(invalid,1).state==invalid,"Out-of-width raw hull rejects atomically")
	check(not Core.damage(hp,1,0,{"module_flags_u8":[1,-1]}).ok and not Core.damage(hp,1,0,{"rng_state":{"seed_a_u32":1,"seed_b_u32":-1}}).ok,"Malformed module/RNG context cannot cross the pure damage boundary")
	check(Core.near_surface(source).callbacks==[{"function":"F1017"}] and Core.surface_stub(source).state==source,"Complete F1016/F1017 preserve the actual reserved no-op surface behavior")
	var seed:={"seed_a_u32":0x12345678,"seed_b_u32":0x89abcdef};var seed_before:=var_to_bytes(seed)
	var next:=Core.rng(seed)
	check(next.ok and int(next.value_u16)<=65535 and var_to_bytes(seed)==seed_before,"F1530 is a pure bounded-return transition over two full raw seed words")
	evidence.append({"case":"source_frame_dependence","zero_tick_heat_increment":zero_time.heat_increment_s32,"original_heat_cadence":"per F1014 invocation","caller_fixed_frequency_policy_proved_here":false})

func raw_callbacks(callbacks:Array)->Array:
	var result:Array=[]
	for callback:Dictionary in callbacks:
		var number:=int(str(callback.function).trim_prefix("F"));var args:Array=[]
		match number:
			34:args=[callback.register,callback.value_u32]
			35:args=[callback.register,callback.return_s32]
			144:args=[callback.module_index,callback.event,callback.code,callback.object_index_u8]
			148:args=[callback.action,callback.value]
			942:args=[callback.attacker_u32]
			953:args=[callback.amount_s32,callback.attacker_u32]
			1530:args=[callback.return_u32]
			1906:args=[callback.sample]
			1907:args=[callback.sample,callback.volume_s8]
		var row:Array=[number,0,0,0,0,0]
		for index in range(args.size()):row[index+1]=int(args[index])&0xffffffff
		result.append(row)
	return result
func words_equal(actual:Variant,expected:Variant)->bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size()!=expected.size():return false
		for key:Variant in actual:
			if not expected.has(key) or not words_equal(actual[key],expected[key]):return false
		return true
	if actual is Array and expected is Array:
		if actual.size()!=expected.size():return false
		for index in range(actual.size()):
			if not words_equal(actual[index],expected[index]):return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):return int(actual)==int(expected)
	return actual==expected
func native_cases()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) if FileAccess.file_exists(FIXTURE) else null
	check(fixture is Dictionary,"Independent original-DOS atmospheric fixture exists")
	if not fixture is Dictionary:return
	check(fixture.get("schema_version")==1 and fixture.get("executable_sha256")==Core.SOURCE_SHA,"Native atmosphere fixture identifies the uploaded executable")
	for number:String in ["34","35","953","1014","1016","1017","1521","1530"]:
		check(fixture.byte_instruction_proofs.get(number,{}).get("all_instructions_equal_after_only_branch_destination_normalization",false),"Every instruction matches uploaded DOS for F"+number)
	var execution:Dictionary=fixture.execution_checks
	check(execution.fresh_identical_processes==3 and execution.reverse_case_order_identical and execution.object_globals_output_canaries and execution.unrelated_object_bytes_unchanged and not execution.expected_arithmetic_computed_by_python,"Independent native runs are repeatable with original-byte proofs and guarded buffers")
	var literals:Array=fixture.get("independent_literal_controls",[]);var literal_controls_ok:bool=literals.size()==8
	for control:Dictionary in literals:literal_controls_ok=literal_controls_ok and control.passed and words_equal(control.observed,control.literal_expected)
	check(literal_controls_ok,"Independent fixed-literal DOS controls verify heat, fatal no-store, wind, shield boundary and the first zero-seed RNG output")
	for sample:Dictionary in fixture.cases:
		var operation:=str(sample.operation);var label:=str(sample.id)+" "+operation;var old_failures:=failures
		domains[operation]=int(domains.get(operation,0))+1
		var state:Dictionary=sample.state.duplicate(true);var original:=var_to_bytes(sample);var context:Dictionary=sample.context.duplicate(true)
		var callbacks:Array=[];var damage_calls:Array=[];var last_return:int=0
		for iteration in range(int(sample.repeat_count)):
			var previous:=var_to_bytes(state);var result:Dictionary={}
			if operation in ["F1014","F1014_damage"]:
				result=Core.atmosphere(state,int(sample.step_ticks_u32));check(result.ok,label+" accepts native atmosphere input")
				check(var_to_bytes(state)==previous,label+" atmosphere input is immutable")
				if not result.ok:break
				state=result.state;damage_calls.append_array(result.damage_calls)
				for callback:Dictionary in result.callbacks:
					callbacks.append(callback)
					if operation=="F1014_damage" and callback.function=="F953":
						var damaged:=Core.damage(state,callback.amount_s32,callback.attacker_u32,context)
						check(damaged.ok,label+" accepts native atmosphere-to-damage call")
						if not damaged.ok:break
						state=damaged.state;callbacks.append_array(damaged.callbacks);context.rng_state=damaged.rng_state
			elif operation=="F953":
				result=Core.damage(state,sample.damage_s32,sample.attacker_u32,context)
				check(result.ok,label+" accepts native raw damage input")
				check(var_to_bytes(state)==previous,label+" damage input is immutable")
				if not result.ok:break
				state=result.state;callbacks.append_array(result.callbacks);context.rng_state=result.rng_state;last_return=int(result.return_s32)
			elif operation=="F1016":
				result=Core.near_surface(state);state=result.state;callbacks.append({"function":"F1016"});callbacks.append_array(result.callbacks)
			elif operation=="F1017":
				result=Core.surface_stub(state);state=result.state;callbacks.append({"function":"F1017"});callbacks.append_array(result.callbacks)
			elif operation=="F1530":
				result=Core.rng(context.rng_state);check(result.ok,label+" accepts native RNG seeds")
				if not result.ok:break
				context.rng_state=result.state;last_return=int(result.value_u16);callbacks.append({"function":"F1530","return_u32":last_return})
			else:check(false,label+" has supported original operation");break
		var expected:Dictionary=sample.expected
		for key:String in expected.state:
			check(state.has(key) and words_equal(state[key],expected.state[key]),label+" exact native projected field "+key+" actual="+str(state.get(key))+" expected="+str(expected.state[key]))
		check(words_equal(raw_callbacks(callbacks),expected.callbacks_raw_u32),label+" exact native callback order and raw arguments")
		check(words_equal(damage_calls,expected.damage_calls),label+" exact original atmosphere damage request sequence")
		check(words_equal(context.rng_state,expected.rng_state),label+" original RNG advances only on reached source calls")
		if expected.return_s32!=null:check(last_return==int(expected.return_s32),label+" original or explicit external callback return value")
		check(var_to_bytes(sample)==original,label+" native fixture remains immutable")
		if failures>old_failures:domain_failures[operation]=int(domain_failures.get(operation,0))+failures-old_failures
	var total:=0
	for count:Variant in domains.values():total+=int(count)
	check(total==int(fixture.case_count) and total==fixture.cases.size() and domains.size()==6,"Every canonical native fixture is consumed once across all six operations")
	evidence.append({"native_cases":total,"operations":domains.duplicate(true),"domain_failures":domain_failures.duplicate(true),"byte_instruction_proof_count":fixture.byte_instruction_proofs.size(),"independent_native_literal_controls":literals.size(),"scope":fixture.scope,"known_jjffe_differences":fixture.known_jjffe_differences})

func run()->void:
	native_cases();boundaries()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	var sources:={"core_sha256":FileAccess.get_sha256("res://scripts/source_atmospheric_dynamics.gd"),"test_sha256":FileAccess.get_sha256("res://tests/test_source_atmospheric_dynamics.gd"),"fixture_sha256":FileAccess.get_sha256(FIXTURE) if FileAccess.file_exists(FIXTURE) else ""}
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"domains":domains,"domain_failures":domain_failures,"evidence":evidence,"sources":sources,"scope":"Uploaded DOS F1014 heat/drag/wind, complete reserved F1016/F1017, F953 raw shield/hull and explicit external callback boundaries, F1530 pure seed transitions. No original destruction/equipment/module VM, shared global AI stream, phone cadence, SI flight integration or Android device proof."},"\t"));file.close()
	print("Source atmospheric dynamics: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
