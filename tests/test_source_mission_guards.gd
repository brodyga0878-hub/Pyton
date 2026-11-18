extends SceneTree
const Guards=preload("res://scripts/source_mission_guards.gd")
const FIXTURE:="res://tests/fixtures/source_mission_guards_native.json"
const FIXTURE_SHA:="aea9057d78aeb41d7ea1ad6ab5d68f71bae83b7ea6a1416e7f50a18d590ae44b"
const REPORT:="res://build/current-test-reports/source-mission-guards.json"
const PROOF:="res://validation/mission-expressions-2026-11-18/guards-native-proof/"
var checks:=0
var failures:=0
var native_callbacks:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<20:push_error(message)
func digest(value:Variant)->String:return var_to_bytes(value).hex_encode().sha256_text()
func encode(value:Variant)->Variant:
	if value is PackedByteArray:return value.hex_encode()
	if value is Dictionary:
		var out:Dictionary={}
		for key:Variant in value:out[key]=encode(value[key])
		return out
	if value is Array:
		var out:Array=[]
		for item:Variant in value:out.append(encode(item))
		return out
	return value
func native_controls(doc:Dictionary)->void:
	check(doc.profile==Guards.PROFILE and int(doc.case_count)==113 and doc.cases.size()==113,"Native whole guard corpus is complete")
	check(int(doc.fresh_process_runs)==3 and int(doc.reverse_repeat_cases)==113 and int(doc.consecutive_native_state_transitions)==12,"Three fresh native runs, reverse cohort and dependent event owners are retained")
	check(not doc.expected_arithmetic_calculated_in_python,"Expected guard state/order originates in actual instructions")
	for path:String in doc.source_dependencies_sha256:check(FileAccess.get_sha256("res://"+path)==doc.source_dependencies_sha256[path],"Native dependency current: "+path)
	for name:String in doc.proofs_sha256:check(FileAccess.get_sha256(PROOF+name)==doc.proofs_sha256[name],"Native proof current: "+name)
	var selectors:Dictionary={};var block_cases:=0;var changed_blocks:=0
	for row:Dictionary in doc.cases:
		var before:=Guards.decode_context(row.context_before);var expected:=Guards.decode_context(row.expected.context_after);var observations:Variant=Guards.decode_observations(row.observations)
		check(not before.is_empty() and not expected.is_empty() and observations is Array,"Complete native owner transport decodes: "+str(row.name))
		if before.is_empty() or expected.is_empty() or not observations is Array:continue
		var frozen:=digest([before,row.args,observations]);var result:=Guards.execute(before,row.operation,row.args,observations)
		check(result.ok,"Whole source guard executes: "+str(row.name))
		if not result.ok:continue
		for field:String in Guards.CONTEXT_KEYS:check(result.context_after[field]==expected[field],"Native full owner matches "+field+": "+str(row.name))
		check(result.source_order==row.expected.source_order and result.observations_used==observations.size(),"Original recursion, literal and callback order matches")
		check(result.return_defined==row.expected.return_defined and result.return_u32==int(row.expected.return_u32),"Only F35 exports its source-defined scalar return")
		check(digest([before,row.args,observations])==frozen,"Original request/owners remain unchanged")
		check(result.context_after.program==before.program and result.context_after.metadata==before.metadata,"Source programs and metadata stay readonly")
		if str(row.name).begins_with("all-metadata-selector-"):selectors[int(str(row.name).get_slice("-",3))]=true
		if row.operation=="F33":
			block_cases+=1;check(result.context_after.ip_u32==before.ip_u32,"F33 owns a local guard cursor and preserves the unrelated caller IP")
			if str(row.name).begins_with("block-reread-"):
				changed_blocks+=1;check(result.requests.size()==1 and result.context_after.task_record.decode_u32(8)!=before.task_record.decode_u32(8),"F33 rereads task+8 after a registration callback")
		for reply:Dictionary in result.requests:
			native_callbacks+=1
			if reply.kind in ["F44","F45"]:
				check(int(reply.args[3])==Guards.F47_WORD and int(reply.args[4])==Guards.TASK_BASE+int(before.task_slot_u32)*36,"Registration preserves the original F47 word and physical task address")
	check(selectors.size()==68 and block_cases==10 and changed_blocks==2,"All metadata slots, signed counts and task-block reread controls execute")
func directed_controls(doc:Dictionary)->void:
	var raw:=Guards.decode_context(doc.cases[0].context_before);var original:=digest(raw)
	var pending:=Guards.execute(raw,"F34",[70,0x12345678])
	check(not pending.ok and pending.reason=="boundary_required" and pending.pending.kind=="F48" and pending.pending.args==[2,0,70],"F34 first stores the event word then requests event2")
	check(pending.pending.before.event_registers.decode_u32(280)==0x12345678 and digest(raw)==original,"Pending store occurs in the private continuation only")
	var replies:Array=[{"kind":"F48","args":[2,0,70],"before":pending.pending.before.duplicate(true),"after":pending.pending.before.duplicate(true),"return_u32":0xffffffff}]
	var after:=Guards.execute(raw,"F34",[70,0x12345678],replies)
	check(after.ok and after.return_u32==0 and not after.return_defined and after.void_return_register_ignored,"Void F34 does not expose callback EAX")
	var cold:Variant=Guards.decode_observations(JSON.parse_string(JSON.stringify(encode(replies))))
	check(cold is Array and Guards.execute(raw,"F34",[70,0x12345678],cold).ok,"Matched continuation survives JSON transport")
	for bad:Variant in [null,true,3,"bad",[],{}]:check(not Guards.execute(bad,"F35",[0]).ok,"Malformed guard context rejects")
	for field:String in Guards.CONTEXT_KEYS:
		var bad:=raw.duplicate(true);bad.erase(field);check(not Guards.execute(bad,"F35",[0]).ok,"Missing guard owner rejects: "+field)
	for field:String in ["root_copy","packed_task_handle","registry_copy"]:
		var bad:=raw.duplicate(true);bad[field]=0;check(not Guards.execute(bad,"F35",[0]).ok,"Undeclared aliases reject")
	for index:Variant in [-1,71,0xffffffff,true,null,INF,NAN,0.5]:check(not Guards.execute(raw,"F35",[index]).ok,"Invalid event word index rejects")
	for operation:Variant in [null,true,0,"F31","F52"]:check(not Guards.execute(raw,operation,[]).ok,"Unsupported or malformed operation rejects")
	for args:Variant in [null,true,0,"F44",[],["F44",0,1],["F48",0],[0,0],["F44",-1]]:check(not Guards.execute(raw,"F32",args).ok,"Malformed guard command rejects")
	for field:String in ["event_registers","metadata","task_record"]:
		var bad:=raw.duplicate(true);bad[field]=bad[field].slice(0,bad[field].size()-1);check(not Guards.execute(bad,"F35",[0]).ok,"Truncated owner rejects: "+field)
	var bad:=raw.duplicate(true);bad.metadata[0]=1;check(not Guards.execute(bad,"F35",[0]).ok,"Changed original metadata rejects")
	bad=raw.duplicate(true);bad.program=PackedByteArray([2]);bad.ip_u32=0;check(not Guards.execute(bad,"F32",["F44",0]).ok,"Truncated immediate span rejects")
	bad=raw.duplicate(true);bad.program=PackedByteArray([68,0,0,0,0]);bad.ip_u32=0;check(not Guards.execute(bad,"F32",["F44",0]).ok,"Byte selector beyond the real metadata table rejects")
	bad=raw.duplicate(true);bad.task_record.encode_u32(8,0);check(not Guards.execute(bad,"F33",["F44"]).ok,"Missing block resource reference rejects")
	bad=raw.duplicate(true);bad.program=PackedByteArray();bad.program.resize(135);bad.program.fill(7);bad.program[130]=2
	for index in range(131,135):bad.program[index]=0
	bad.ip_u32=0
	check(not Guards.execute(bad,"F32",["F44",0]).ok,"Nonterminating/deep authored guard tree is bounded explicitly")
	var wrong:Array=replies.duplicate(true);wrong[0].before.event_registers[0]^=1;check(not Guards.execute(raw,"F34",[70,0x12345678],wrong).ok,"Wrong callback-before owner cannot resume")
	wrong=replies.duplicate(true);wrong[0].after.program[0]^=1;check(not Guards.execute(raw,"F34",[70,0x12345678],wrong).ok,"Provider cannot mutate readonly source bytes")
	wrong=replies.duplicate(true);wrong.append(wrong[0].duplicate(true));check(not Guards.execute(raw,"F34",[70,0x12345678],wrong).ok,"Unused callback reply cannot silently succeed")
	var cycle:Dictionary=raw.duplicate(true);cycle.program=cycle
	check(Guards.decode_context(cycle).is_empty() and not Guards.execute(cycle,"F35",[0]).ok,"Cyclic malformed owner rejects before any recursive copy")
	cycle.program=null;cycle.clear()
	var cycle_array:Array=[];cycle_array.append(cycle_array)
	check(Guards.decode_observations(cycle_array)==null and not Guards.execute(raw,"F35",[0],cycle_array).ok,"Cyclic callback array rejects before duplication")
	cycle_array.clear()
	var deeply_nested:Dictionary={};var child:Dictionary=deeply_nested
	for index in range(300):
		child["next"]={};child=child.next
	var deep_context:=raw.duplicate(true);deep_context.program=deeply_nested
	check(Guards.decode_context(deep_context).is_empty(),"Deep unsupported data rejects by field type without traversal")
	check(digest(raw)==original,"All negative/pending/completed commands retain the caller's owners")
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent guard fixture is pinned")
	var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));native_controls(doc);directed_controls(doc)
	var sources:Dictionary={}
	for path:String in ["scripts/source_mission_guards.gd","tests/test_source_mission_guards.gd","tests/fixtures/source_mission_guards_native.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in doc.source_dependencies_sha256:sources[path]=FileAccess.get_sha256("res://"+path)
	for name:String in doc.proofs_sha256:sources[PROOF.trim_prefix("res://")+name]=FileAccess.get_sha256(PROOF+name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Guards.PROFILE,"checks":checks,"failures":failures,"native_cases":int(doc.case_count),"native_callbacks":native_callbacks,"sources":sources,"Main_integrated":false,"F31_body_executed_by_this_kernel":false,"full_mission_VM_executed":false},"\t"));file.close()
	print("SOURCE MISSION GUARDS TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
