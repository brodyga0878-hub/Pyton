extends SceneTree
const Pair=preload("res://scripts/source_pair_response.gd")
const FIXTURE:="res://tests/fixtures/source_pair_response_native.json"
const FIXTURE_SHA:="016221418ecb601b995441babd8bd40a9f4cb7ed61710e33558255ea5e4c7ed4"
const REPORT:="res://build/current-test-reports/source-pair-response.json"
var checks:=0
var failures:=0
var native_cases:=0
var matched_boundaries:=0
var sequence_cases:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<28:push_error(message)
func digest(value:Variant)->String:return JSON.stringify(JSON.parse_string(JSON.stringify(value)),"",true).sha256_text()
func body_for(index:int,parent:int,kind:int,model:int,velocity:Array,hp:int)->PackedByteArray:
	var result:=PackedByteArray();result.resize(Pair.OBJECT_BYTES);result.fill(0xa5)
	result[0x86]=index;result[0x56]=parent;result[0x87]=kind;result.encode_u32(0x82,model);result.encode_u16(0xe4,hp)
	for axis in range(3):result.encode_s32(0x8c+axis*4,int(velocity[axis]))
	return result
func baseline()->Dictionary:
	return {"body":body_for(114,0,3,14,[8,-5,0x7fffffff],20),"collider":body_for(37,0,3,14,[4,-4,1],10),"globals":{"collision_flags_u8":1,"collision_enabled_u8":255}}
func execute_context(context:Dictionary,observations:Array=[])->Dictionary:return Pair.execute(context.body,context.collider,context.globals,observations)
func response(pending:Dictionary)->Dictionary:
	var row:Dictionary=pending.duplicate(true);row.after=pending.before.duplicate(true);return row
func decode_context(value:Dictionary)->Dictionary:
	return {"body":str(value.body_hex).hex_decode(),"collider":str(value.collider_hex).hex_decode(),"globals":value.globals.duplicate(true)}
func decode_observations(value:Array)->Array:
	var result:Array=[]
	for native:Dictionary in value:
		result.append({"kind":native.kind,"target":native.target,"args":native.args.duplicate(),"before":decode_context(native.before),"after":decode_context(native.after)})
	return result
func directed()->void:
	var context:=baseline();var original:=var_to_bytes(context)
	var initial:=execute_context(context)
	check(not initial.ok and initial.reason=="boundary_required" and initial.pending.target=="collider" and initial.pending.args==[20,114],"Unsigned minimum HP selects first collider damage and original subject attacker")
	if not initial.get("pending") is Dictionary:return
	check(initial.pending.before.body.decode_s32(0x8c)==6 and initial.pending.before.collider.decode_s32(0x8c)==6,"Both velocities have changed before the first damage boundary")
	check(initial.pending.before.body.decode_s32(0x90)==-5 and initial.pending.before.collider.decode_s32(0x90)==-5,"Arithmetic right shift rounds the negative odd velocity sum down")
	check(initial.pending.before.body.decode_s32(0x94)==-1073741824,"Signed32 overflow wraps before the arithmetic mean shift")
	check(initial.pending.before.globals.collision_flags_u8==0x81,"Collision flag80 is set before any response")
	var first:=response(initial.pending);first.after.collider.encode_u16(0xe4,100);first.after.body.encode_u16(0xe4,3);first.after.collider[0x86]=99;first.after.globals.collision_enabled_u8=0;first.after.body.encode_u32(0x82,5)
	var next:=execute_context(context,[first])
	check(not next.ok and next.pending.target=="body" and next.pending.args==[200,99],"Second request reloads HP and attacker after F953 while preserving the original minimum branch")
	check(next.observations_used==1 and next.pending.before.body.decode_u32(0x82)==5 and next.pending.before.globals.collision_enabled_u8==0,"First response mutations are visible without repeating the already-passed damage gate")
	var second:=response(next.pending);second.after.globals.collision_flags_u8=0x5a
	var completed:=execute_context(context,[first,second])
	check(completed.ok and completed.observations_used==2 and completed.source_order==["F578","F953","F953"],"Both ordered matched damage responses resume the complete procedure")
	check(completed.ok and completed.globals_after.collision_flags_u8==0x5a,"No later instruction invents a flag rewrite after the final response")
	check(var_to_bytes(context)==original,"Pending and resumed calls leave every caller-owned byte unchanged")
	var low_subject:=baseline();low_subject.body.encode_u16(0xe4,10);low_subject.collider.encode_u16(0xe4,20)
	var a:=execute_context(low_subject);check(not a.ok and a.pending.args==[20,114],"Unsigned subject-minimum branch uses the subject HP for first damage")
	var row:=response(a.pending);row.after.body.encode_u16(0xe4,500);row.after.collider.encode_u16(0xe4,2);row.after.collider[0x86]=7
	var b:=execute_context(low_subject,[row]);check(not b.ok and b.pending.args==[1000,7],"Subject-minimum branch reloads subject HP after first damage and does not recompute the minimum")
	for route:int in range(2):
		var parent:=baseline();parent.body=body_for(114,37 if route==0 else 0,3,14,[-9,7,-1],20);parent.collider[0x87]=3 if route==0 else 1;parent.globals.collision_enabled_u8=0
		var result:=execute_context(parent)
		check(not result.ok and result.pending.target=="body" and result.pending.args==[15,0],"Parent identity and type1 independently enter enabled-independent recoil: "+str(route))
		check(result.pending.before.body.decode_s32(0x8c)==3 and result.pending.before.body.decode_s32(0x90)==-1 and result.pending.before.body.decode_s32(0x94)==1,"Parent recoil negates a signed quarter-shift before calculating damage")
		check(result.pending.before.collider==parent.collider and result.source_order==["F578","_abs","_abs","_abs","F953"],"Parent recoil leaves the collider untouched and computes the exact source abs sequence")
		parent.body.encode_u32(0x82,13);var no_damage:=execute_context(parent)
		check(no_damage.ok and no_damage.requests.is_empty() and no_damage.body_after.decode_s32(0x8c)==3,"Model13 parent recoil still updates velocity while suppressing damage")
	for enabled:int in [0,1,255]:
		for model:int in [0,13,14,0xffffffff]:
			var gated:=baseline();gated.globals.collision_enabled_u8=enabled;gated.body.encode_u32(0x82,model)
			var result:=execute_context(gated)
			check(result.ok if enabled==0 or model<=13 else not result.ok and result.get("pending") is Dictionary,"Damage gate uses unsigned model words and enabled byte")
			var after:PackedByteArray=result.body_after if result.ok else result.pending.before.body
			check(after.decode_s32(0x8c)==6 and after.decode_s32(0x94)==-1073741824,"Disabled or low-model damage does not skip original velocity averaging")
func malformed()->void:
	var context:=baseline();var original:=var_to_bytes(context)
	for bad:Variant in [null,true,{},[],0,"body",PackedByteArray()]:
		check(not Pair.execute(bad,context.collider,context.globals).ok,"Malformed subject body rejects")
		check(not Pair.execute(context.body,bad,context.globals).ok,"Malformed collider body rejects")
	for size:int in [1,337,339]:
		var raw:=PackedByteArray();raw.resize(size)
		check(not Pair.execute(raw,context.collider,context.globals).ok and not Pair.execute(context.body,raw,context.globals).ok,"Wrong raw record extent rejects")
	for bad:Variant in [null,true,[],0,"globals",{}]:check(not Pair.execute(context.body,context.collider,bad).ok,"Malformed pair globals reject")
	for key:String in Pair.GLOBAL_KEYS:
		var invalid:Dictionary=context.globals.duplicate(true);invalid.erase(key);check(not Pair.execute(context.body,context.collider,invalid).ok,"Missing pair global rejects: "+key)
		for bad:Variant in [-1,256,NAN,INF,true,0.5,"0",null]:
			invalid=context.globals.duplicate(true);invalid[key]=bad;check(not Pair.execute(context.body,context.collider,invalid).ok,"Invalid raw pair byte rejects: "+key)
	var extra:Dictionary=context.globals.duplicate(true);extra.player_index_u32=114;check(not Pair.execute(context.body,context.collider,extra).ok,"Unknown or duplicated global owners reject")
	for bad:Variant in [null,true,0,"observations",{},[{}, {}, {}]]:check(not Pair.execute(context.body,context.collider,context.globals,bad).ok,"Malformed or excessive observations reject")
	var pending:=execute_context(context);var valid:=response(pending.pending)
	for key:String in ["kind","target","args","before","after"]:
		var invalid:=valid.duplicate(true);invalid.erase(key);check(not execute_context(context,[invalid]).ok,"Missing matched observation field rejects: "+key)
	for key:String in ["body","collider"]:
		var invalid:=valid.duplicate(true);invalid.before[key][0]=int(invalid.before[key][0])^1;check(not execute_context(context,[invalid]).ok,"A different before record cannot consume a response: "+key)
		invalid=valid.duplicate(true);invalid.after[key]=PackedByteArray();check(not execute_context(context,[invalid]).ok,"Truncated after response rejects: "+key)
	for key:String in ["before","after"]:
		for bad:Variant in [null,true,{},[],0,"context"]:
			var invalid:=valid.duplicate(true);invalid[key]=bad;check(not execute_context(context,[invalid]).ok,"Malformed matched raw context rejects: "+key)
	for bad:Variant in [null,true,0,"args",[],[20],[20,114,0],[20,115]]:
		var invalid:=valid.duplicate(true);invalid.args=bad;check(not execute_context(context,[invalid]).ok,"Different or malformed damage arguments reject")
	for field:String in ["kind","target"]:
		for bad:Variant in [null,true,0,[],{}]:
			var malformed:=valid.duplicate(true);malformed[field]=bad;check(not execute_context(context,[malformed]).ok,"Malformed callback identity rejects: "+field)
	for bad:Variant in [[true,114],[20,true],[-1,114],[0x100000000,114],[20,-1],[20,0x100000000],[20.5,114],[NAN,114],[INF,114]]:
		var malformed:=valid.duplicate(true);malformed.args=bad;check(not execute_context(context,[malformed]).ok,"Malformed raw callback words reject")
	var invalid:=valid.duplicate(true);invalid.kind="F578";check(not execute_context(context,[invalid]).ok,"Wrong callback cannot consume the observation")
	invalid=valid.duplicate(true);invalid.target="body";check(not execute_context(context,[invalid]).ok,"Response for the other pointer target rejects")
	invalid=valid.duplicate(true);invalid.before.globals.collision_flags_u8=0;check(not execute_context(context,[invalid]).ok,"Stale before globals reject")
	invalid=valid.duplicate(true);invalid.after.globals.collision_enabled_u8=256;check(not execute_context(context,[invalid]).ok,"Malformed after globals reject")
	invalid=valid.duplicate(true);invalid.extra=0;check(not execute_context(context,[invalid]).ok,"Unknown observation fields reject")
	check(var_to_bytes(context)==original,"Every rejected observation preserves all caller bytes and globals")
	var frozen:=var_to_bytes([context,valid]);pending.pending.before.body[0]=0;pending.pending.before.collider[0]=0;pending.pending.before.globals.collision_flags_u8=0
	check(var_to_bytes([context,valid])==frozen,"Returned pending descriptors do not alias caller context or previously copied responses")
	var safe:=baseline();safe.globals.collision_enabled_u8=0;var result:=execute_context(safe);var safe_frozen:=var_to_bytes(safe)
	result.body_after[0]=0;result.collider_after[0]=0;result.globals_after.collision_flags_u8=0
	check(var_to_bytes(safe)==safe_frozen,"Completed raw output records and globals are independent of caller ownership")
	check(not execute_context(safe,[valid]).ok,"Unused supplied observations cannot be silently discarded")
func native_controls()->void:
	if not FileAccess.file_exists(FIXTURE):check(false,"Independent original DOS pair-response fixture is required");return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent native pair fixture identity is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.get("case_count",0)==fixture.get("cases",[]).size() and int(fixture.get("case_count",0))>=250,"Complete native pair-response bank contains the declared controls")
	check(fixture.schema=="starfrontier-source-pair-response-native-v1" and fixture.profile==Pair.PROFILE and fixture.source_executable_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72","Actual uploaded DOS source and pair profile remain explicit")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_cases==288 and fixture.consecutive_native_steps==32 and fixture.all_context_output_canaries_unchanged and not fixture.expected_arithmetic_calculated_in_python,"Three fresh native processes, reversed order, guarded ownership and actual consecutive inputs remain independent")
	var proof_path:="res://validation/contact-classifier-2026-11-17/pair-native-proof/instruction-proof.json"
	check(FileAccess.get_sha256(proof_path)==fixture.instruction_proof_sha256,"Full original instruction proof identity is pinned")
	var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(proof_path));var primary:Dictionary=proof.procedures["578"]
	check(primary.instruction_count==114 and primary.byte_length==416 and primary.all_full_procedure_instructions_equal,"All114 instructions and416 bytes of actual DOS F578 are included")
	for path:String in fixture.source_dependencies_sha256:check(FileAccess.get_sha256("res://"+path)==fixture.source_dependencies_sha256[path],"Portable original-instruction reproduction dependency is pinned: "+path)
	var previous:Dictionary={}
	for row:Dictionary in fixture.cases:
		var context:Dictionary={"body":str(row.body_before_hex).hex_decode(),"collider":str(row.collider_before_hex).hex_decode(),"globals":row.globals_before.duplicate(true)}
		var expected:Dictionary=row.expected;var observations:=decode_observations(expected.observations);var frozen:=var_to_bytes([context,observations])
		var result:=execute_context(context,observations);native_cases+=1
		check(result.ok,"Original DOS whole pair response completes: "+str(row.name))
		if not result.ok:continue
		check(result.body_after==str(expected.body_after_hex).hex_decode(),"All338 subject bytes match original instructions")
		check(result.collider_after==str(expected.collider_after_hex).hex_decode(),"All338 collider bytes match original instructions")
		check(digest(result.globals_after)==digest(expected.globals_after),"Every pair global matches the native source result")
		check(result.source_order==expected.source_order,"Exact source order matches the original including ordered damage calls")
		check(result.observations_used==observations.size() and result.requests.size()==observations.size(),"Each native observed call is consumed exactly once")
		check(not result.live_owners_changed and not result.F953_body_executed and not result.complete_collision_pipeline,"Damage/world effects stay outside the independently checked pair arithmetic")
		check(var_to_bytes([context,observations])==frozen,"Every native call leaves source data and observations unchanged")
		for index in range(observations.size()):
			var paused:=execute_context(context,observations.slice(0,index));var next:Dictionary=observations[index]
			check(not paused.ok and paused.get("pending") is Dictionary and paused.pending.kind==next.kind and paused.pending.target==next.target and digest(paused.pending.args)==digest(next.args),"Original call pauses at the next native F953 boundary")
			if paused.get("pending") is Dictionary:check(Pair._same(paused.pending.before,next.before),"Entire native before context matches at the exact callback")
			matched_boundaries+=1
		var cold_context:=decode_context(JSON.parse_string(JSON.stringify({"body_hex":row.body_before_hex,"collider_hex":row.collider_before_hex,"globals":row.globals_before})))
		var cold:=execute_context(cold_context,decode_observations(JSON.parse_string(JSON.stringify(expected.observations))))
		check(cold.ok and cold.body_after==result.body_after and cold.collider_after==result.collider_after and digest(cold.globals_after)==digest(result.globals_after),"Cold raw JSON delivery preserves native continuation exactly")
		if str(row.name).begins_with("consecutive/"):
			var step:=int(str(row.name).trim_prefix("consecutive/"))
			check(step==sequence_cases,"Consecutive source procedure controls keep the declared native order")
			if step>0:check(context.body==previous.body and context.collider==previous.collider and digest(context.globals)==digest(previous.globals),"Consecutive pair input retains the prior actual native output")
			previous={"body":result.body_after.duplicate(),"collider":result.collider_after.duplicate(),"globals":result.globals_after.duplicate(true)};sequence_cases+=1
	check(native_cases==320 and matched_boundaries>0 and sequence_cases==32,"Entire native bank and all32 state-retaining consecutive calls are exercised")
func run()->void:
	directed();malformed();native_controls()
	var sources:Dictionary={}
	for path:String in ["scripts/source_pair_response.gd","tests/test_source_pair_response.gd","tools/rebuild_source_pair_response_native.py","tests/fixtures/source_pair_response_native.json","validation/contact-classifier-2026-11-17/pair-native-proof/instruction-proof.json","validation/contact-classifier-2026-11-17/pair-native-proof/source-procedures.s"]:
		if FileAccess.file_exists("res://"+path):sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"profile":Pair.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"matched_boundaries":matched_boundaries,"consecutive_actual_inputs":sequence_cases,"sources":sources,"live_Main_changed":false,"F953_body_executed":false,"complete_collision_pipeline":false,"scope":"Whole uploaded-DOS F578 arithmetic and matched F953 boundaries only; both complete338-byte records and globals checked against independent original instructions."},"\t"));file.close()
	print("SOURCE PAIR RESPONSE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
