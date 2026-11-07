extends SceneTree
const Core=preload("res://scripts/source_fuel_scoop.gd")
const FIXTURE:="res://tests/fixtures/source_fuel_scoop_native.json"
var checks:=0
var failures:=0
var domains:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=30:push_error(message)
func native_cases()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture is Dictionary and fixture.get("asm_sha256")==Core.ASM_SHA and fixture.get("source_contract")==Core.CONTRACT,"Pinned original native fixture contract")
	if not fixture is Dictionary:return
	check(fixture.get("fresh_process_runs")==3 and fixture.get("reverse_order_unchanged",false) and fixture.get("canaries_unchanged",false),"Independent fresh, reverse and guarded original executions")
	check(fixture.get("case_count")==fixture.cases.size(),"Every native case is consumed once")
	for sample:Dictionary in fixture.cases:
		var game:=str(sample.game_hex).hex_decode();var object:=str(sample.object_hex).hex_decode();var contact:Dictionary=sample.contact.duplicate(true);var state:Dictionary=sample.state
		var before:=var_to_bytes([game,object,contact,state]);var actual:=Core.evaluate_buffers(game,object,contact,state.step_u32,state.sound_mode_s8);var expected:Dictionary=sample.expected;var label:="native%d %s"%[int(sample.id),sample.group]
		domains[sample.group]=int(domains.get(sample.group,0))+1
		check(actual.ok,label+" input accepted")
		if not actual.ok:continue
		check(actual.return_s32==int(expected.return_s32),label+" signed flag return")
		check(actual.game.hex_encode()==expected.game_hex,label+" exact544game bytes")
		check(actual.object.hex_encode()==expected.object_hex,label+" exact338object bytes")
		var event_keys:=["refresh","notify","sound","destroy","message_code","message_amount","notify_first","notify_second"]
		for i in range(event_keys.size()):check(int(actual.events[event_keys[i]])==int(expected.events[i]),label+" original callback "+event_keys[i])
		check(var_to_bytes([game,object,contact,state])==before,label+" all caller inputs immutable")
		check(actual.scooped_tonnes==(1 if int(expected.events[4])==0x9906 else 0),label+" physical H2 increment event")
func boundaries()->void:
	var state:={"equipped_ca_u8":0x10,"cargo_used_s32":4,"capacity_s32":80,"hydrogen_u16":4,"speed_s32":9000,"step_u32":49710,"cooldown_u32":0,"heat_s32":123}
	var contact:={"flags_u8":1,"altitude_raw_s32":30000000,"parent_model_u32":137}
	var before:=var_to_bytes([state,contact]);var first:=Core.evaluate(state,contact)
	check(first.ok and first.scooped_tonnes==1 and first.hydrogen_u16==5 and first.cargo_used_s32==5,"Convenience kernel adds exactly1tonne H2 to cargo")
	check(first.cooldown_u32==149130 and first.heat_s32==171,"Exact timer reset and lower stellar branch")
	check(var_to_bytes([state,contact])==before,"Convenience inputs immutable")
	var next:=state.duplicate(true);next.cooldown_u32=first.cooldown_u32
	var blocked:=Core.evaluate(next,contact)
	check(blocked.scooped_tonnes==0 and blocked.reason=="cooldown" and blocked.heat_s32==123 and blocked.cooldown_u32==149130,"Original early cooldown return skips heat and does not decrement time")
	next.cooldown_u32=0;next.cargo_used_s32=80
	var full:=Core.evaluate(next,contact)
	check(full.scooped_tonnes==0 and full.reason=="cargo_full" and full.heat_s32==171 and full.cooldown_u32==149130,"Full cargo still enters source heat and resets delay")
	next=state.duplicate(true);next.equipped_ca_u8=0;contact.parent_model_u32=140
	var absent:=Core.evaluate(next,contact)
	check(absent.scooped_tonnes==0 and absent.heat_s32==317 and absent.cooldown_u32==149130,"Missing scoop still enters hotter source star branch")
	next=state.duplicate(true);next.heat_s32=0x7fffffff
	check(Core.evaluate(next,contact).destruction_requested,"Signed32 heat overflow requests original F953 destruction callback")
	contact.flags_u8=0
	check(Core.evaluate(state,contact).heat_s32==123,"Outside atmospheric F569 flag skips stellar heat")
	for pair:Array in [["hydrogen_u16",-1],["hydrogen_u16",65536],["speed_s32",0x80000000],["step_u32",-1],["heat_s32",NAN],["cargo_used_s32",INF],["cooldown_u32",1.5],["equipped_ca_u8",256]]:
		var malformed:=state.duplicate(true);malformed[pair[0]]=pair[1];var frozen:=var_to_bytes(malformed)
		check(not Core.evaluate(malformed,contact).ok and var_to_bytes(malformed)==frozen,"Reject malformed state atomically "+str(pair[0]))
	for bad:Dictionary in [{},{"flags_u8":-1,"altitude_raw_s32":0,"parent_model_u32":137},{"flags_u8":1,"altitude_raw_s32":INF,"parent_model_u32":137}]:check(not Core.evaluate(state,bad).ok,"Malformed F569 fixture rejects")
	check(not Core.evaluate_buffers(PackedByteArray(),PackedByteArray(),contact,49710).ok,"Raw buffers checked before every offset")
func run()->void:
	native_cases();boundaries()
	var report:={"schema":1,"checks":checks,"failures":failures,"native_cases":729,"domains":domains,"scope":"Original F1033/F1034 raw branch, cargo, timer, thermal and side-effect call parity after explicitly stubbed F569 result. Does not prove physical geometry, SI units, countdown scheduling, atmospheric heat/cooling, callback damage or Android device execution.","physical_device_tested":false,"sources":{"core_sha256":FileAccess.get_file_as_string("res://scripts/source_fuel_scoop.gd").sha256_text(),"fixture_sha256":FileAccess.get_file_as_string(FIXTURE).sha256_text(),"test_sha256":FileAccess.get_file_as_string("res://tests/test_source_fuel_scoop.gd").sha256_text()}}
	var path:="res://validation/fuel-2026-11-07/source-fuel-scoop-core.json";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()));var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));print("Source fuel scoop: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
