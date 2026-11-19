extends SceneTree
const Kernel=preload("res://scripts/source_mission_task.gd")
const FIXTURE:="res://tests/fixtures/source_mission_task_native.json"
const FIXTURE_SHA:="91f66840d9cf7a462e5f41bcaffb51e2c580ee7f5efeb02bbe0748878e15f910"
const PROOF:="res://validation/mission-tasks-2026-11-19/task-native-proof/"
const REPORT:="res://build/current-test-reports/source-mission-task.json"
const BASE:=0x4801c4
var checks:=0
var failures:=0
var native_cases:=0
var provider_calls:=0
var buffers:Dictionary={}
var hydrated:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<20:push_error(message)
func zeros(count:int)->PackedByteArray:
	var value:=PackedByteArray();value.resize(count);return value
func context(slot:int=17)->Dictionary:
	var program:=zeros(256);program.encode_u32(0,BASE+32);program.encode_u32(8,2);program.encode_u32(12,0xffffffff);program.encode_u32(28,BASE+64)
	program.encode_u32(64,BASE+128);program.encode_u32(68,2);program.encode_u32(72,BASE+160);program.encode_u32(76,BASE+176)
	program.encode_u32(96,BASE+144);program.encode_u32(100,1);program.encode_u32(104,BASE+192)
	var arena:=zeros(5400);var at:=slot*36;arena.encode_u32(at,1);arena.encode_u16(at+4,slot);arena.encode_u16(at+6,3);arena.encode_u32(at+8,BASE+64);arena.encode_u32(at+12,0);arena.encode_u32(at+16,BASE+64);arena.encode_u32(at+20,0);arena.encode_u32(at+24,0);arena.encode_u32(at+28,BASE);arena.encode_u32(at+32,0x12345678)
	return {"arena":arena,"program":program,"program_base_u32":BASE,"module_refs":{"0":BASE},"caller_ip_u32":16}
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
func reply(pending:Dictionary,returned:int=0,cursor_after:int=-1)->Dictionary:
	var after:Dictionary=pending.before.duplicate(true)
	var cursor_value:=int(pending.cursor_before_u32) if cursor_after<0 else cursor_after
	if pending.cursor_kind=="caller":after.caller_ip_u32=cursor_value
	return {"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":after,"return_u32":returned,"cursor_kind":pending.cursor_kind,"cursor_before_u32":int(pending.cursor_before_u32),"cursor_after_u32":cursor_value}
func directed_controls()->void:
	var raw:=context();var original:=digest(raw);var at:=17*36;var handle:int=raw.arena.decode_u32(at+4)
	var result:=Kernel.execute(raw,"F38",[(handle-65536)&0xffffffff])
	check(result.ok and result.context_after==raw and result.source_order==["F38"],"A stale packed handle is the literal source no-op")
	for state:int in [0,1,4,5,6,0x80000000,0xffffffff]:
		var inactive:=context();inactive.arena.encode_u32(at,state);inactive.arena.encode_u32(at+8,0)
		result=Kernel.execute(inactive,"F38",[handle])
		check(result.ok and result.context_after.arena.decode_u32(at)==6 and result.context_after.arena.decode_u16(at+6)==4,"Actual DOS F38 has no later JJFFE state gate: %08x"%state)
	var cleanup:=context();cleanup.arena.encode_u32(at+8,0);cleanup.program.encode_u32(12,1)
	result=Kernel.execute(cleanup,"F38",[handle])
	check(result.ok and result.context_after.arena.decode_u32(at)==5 and result.context_after.arena.decode_u16(at+6)==3,"Cancellation with cleanup enters5 without generation increment")
	var pending:=Kernel.execute(raw,"F38",[handle])
	check(not pending.ok and pending.pending.kind=="F33" and pending.pending.args==[17,45] and pending.pending.before.arena.decode_u32(at)==1,"Cancellation unregisters the active block before state and generation changes")
	var row:=reply(pending.pending);row.after.arena.encode_u16(at+6,65535);row.after.arena.encode_u32(at+8,BASE+96)
	result=Kernel.execute(raw,"F38",[handle],[row])
	check(result.ok and result.context_after.arena.decode_u32(at+8)==0 and result.context_after.arena.decode_u32(at+12)==0xffffffff and result.context_after.arena.decode_u16(at+6)==0,"Cancellation clears the callback-mutated active block then increments the reread generation modulo16bits")
	var invalid:=context();invalid.arena.encode_u32(at,0);invalid.arena.encode_u32(at+8,0);invalid.arena.encode_u32(at+28,0)
	check(not Kernel.execute(invalid,"F38",[handle]).ok,"Matching inactive DOS task still dereferences its descriptor; a missing pointer is not invented as a no-op")
	var zero:=context(0);zero.arena.encode_u16(6,0);zero.arena.encode_u32(8,0)
	result=Kernel.execute(zero,"F38",[0])
	check(result.ok and result.context_after.arena.decode_u16(6)==1 and result.context_after.arena.decode_u32(0)==6,"A valid wrapped zero handle is not a null task")
	var skipped:=context();skipped.arena.encode_u32(at,2);skipped.arena.encode_u32(at+8,0)
	result=Kernel.execute(skipped,"F47",[17,0])
	check(result.ok and result.context_after==skipped,"F47 skips inactive callback states before touching the block")
	var unchecked:=context();unchecked.program.encode_u32(68,0)
	pending=Kernel.execute(unchecked,"F47",[17,0])
	check(not pending.ok and pending.pending.kind=="F31" and pending.pending.cursor_before_u32==160,"Actual DOS F47 reads the pointer even outside the declared clause count")
	row=reply(pending.pending,0,165);result=Kernel.execute(unchecked,"F47",[17,0],[row])
	check(result.ok and result.context_after.arena.decode_u32(at)==1 and result.context_after.caller_ip_u32==16,"A false local condition leaves task state and unrelated caller cursor unchanged")
	pending=Kernel.execute(raw,"F47",[17,1]);var condition:=reply(pending.pending,1,181);condition.after.arena.encode_u32(at,5)
	pending=Kernel.execute(raw,"F47",[17,1],[condition])
	check(not pending.ok and pending.pending.kind=="F41" and pending.pending.cursor_before_u32==181 and pending.pending.before.arena.decode_u32(at)==2,"True F47 overwrites callback state with2 and continues at the exact advanced condition cursor")
	var statement:=reply(pending.pending,0,183);statement.after.arena.encode_u32(at,5)
	result=Kernel.execute(raw,"F47",[17,1],[condition,statement])
	check(result.ok and result.context_after.arena.decode_u32(at)==5 and result.context_after.caller_ip_u32==16,"F47 preserves a changed statement state and its local cursor never replaces caller IP")
	statement.after.arena.encode_u32(at,2);result=Kernel.execute(raw,"F47",[17,1],[condition,statement])
	check(result.ok and result.context_after.arena.decode_u32(at)==1,"F47 restores1 only when the statement leaves2")
	var empty:=context();empty.program.encode_u32(8,0);empty.caller_ip_u32=0xffffffff
	pending=Kernel.execute(empty,"F52",[-1,0,77])
	check(not pending.ok and pending.pending.kind=="F51" and pending.pending.args==[0,77],"F52 allocation comes before descriptor argument binding")
	var allocation:=reply(pending.pending,0);allocation.after.arena.encode_u32(4,0)
	result=Kernel.execute(empty,"F52",[-1,0,77],[allocation])
	check(result.ok and result.return_defined and result.return_u32==0 and result.context_after.arena.decode_u32(16)==BASE+64 and result.context_after.arena.decode_u32(20)==0,"Zero-argument module admits null caller and returns a valid defined zero handle")
	var failed_allocation:=reply(pending.pending,0xffffffff)
	result=Kernel.execute(empty,"F52",[-1,0,77],[failed_allocation])
	check(not result.ok and result.reason=="task_allocation_null_fault" and not result.has("context_after"),"F51 NULL is a separate original F52 fault, not a successful zero handle")
	var replies:Array=[];pending=Kernel.execute(raw,"F52",[17,0,99]);allocation=reply(pending.pending,18)
	allocation.after.arena.encode_u16(18*36+4,18);allocation.after.arena.encode_u16(18*36+6,1);replies.append(allocation)
	pending=Kernel.execute(raw,"F52",[17,0,99],replies)
	check(pending.pending.kind=="F31" and pending.pending.args==[17] and pending.pending.cursor_kind=="caller" and pending.pending.cursor_before_u32==16,"F52 evaluates its first argument in the caller task and caller cursor")
	row=reply(pending.pending,11,20);replies.append(row);pending=Kernel.execute(raw,"F52",[17,0,99],replies)
	check(pending.pending.kind=="F37" and pending.pending.args==[18,11] and pending.pending.cursor_kind=="callee" and pending.pending.cursor_before_u32==32,"F52 stores into a different task and independently initialized target cursor")
	row=reply(pending.pending,0,37);replies.append(row);pending=Kernel.execute(raw,"F52",[17,0,99],replies)
	check(pending.pending.kind=="F31" and pending.pending.cursor_before_u32==20,"Second argument resumes the caller cursor, not the callee target")
	row=reply(pending.pending,22,25);replies.append(row);pending=Kernel.execute(raw,"F52",[17,0,99],replies)
	check(pending.pending.kind=="F37" and pending.pending.args==[18,22] and pending.pending.cursor_before_u32==37,"Second assignment resumes the independent callee cursor")
	row=reply(pending.pending,0,41);replies.append(row);result=Kernel.execute(raw,"F52",[17,0,99],replies)
	check(result.ok and result.return_u32==65554 and result.context_after.caller_ip_u32==25 and result.context_after.arena.decode_u32(18*36+16)==BASE+64,"F52 returns its reread handle after selecting block0 and preserving the advanced caller cursor")
	check(result.source_order==["F52","F51","F31","F37","F31","F37"],"F52 allocation/evaluation/store order is exact")
	var cold:Variant=Kernel.decode_observations(JSON.parse_string(JSON.stringify(encode(replies))))
	check(cold is Array and Kernel.execute(raw,"F52",[17,0,99],cold).ok,"Both cursor identities and task identities survive JSON continuation transport")
	var initialized:=context();initialized.arena.encode_u32(at+8,0);replies=[];pending=Kernel.execute(initialized,"F53",[17])
	check(pending.pending.kind=="F41" and pending.pending.cursor_before_u32==128 and pending.pending.before.arena.decode_u32(at)==3,"F53 sets state3 and starts the current block initialization statement stream")
	row=reply(pending.pending,0,129);replies.append(row);pending=Kernel.execute(initialized,"F53",[17],replies)
	check(pending.pending.kind=="F31" and pending.pending.cursor_before_u32==160,"F53 initially evaluates clause0")
	row=reply(pending.pending,1,165);replies.append(row);pending=Kernel.execute(initialized,"F53",[17],replies)
	check(pending.pending.kind=="F41" and pending.pending.cursor_before_u32==165,"F53 condition advances immediately into its associated statements")
	row=reply(pending.pending,0,167);row.after.arena.encode_u32(at+20,23);replies.append(row);pending=Kernel.execute(initialized,"F53",[17],replies)
	check(pending.pending.kind=="F31" and pending.pending.cursor_before_u32==176,"Literal xor0 followed by common inc means a true clause rescan resumes at1")
	row=reply(pending.pending,0,181);replies.append(row);pending=Kernel.execute(initialized,"F53",[17],replies)
	check(pending.pending.kind=="F33" and pending.pending.args==[17,44] and pending.pending.before.arena.decode_u32(at+8)==BASE+64 and pending.pending.before.arena.decode_u32(at+12)==23,"F53 stores the reread block/index before guard registration")
	row=reply(pending.pending);row.after.arena.encode_u32(at,6);replies.append(row);result=Kernel.execute(initialized,"F53",[17],replies)
	check(result.ok and result.context_after.arena.decode_u32(at)==1 and result.context_after.caller_ip_u32==16,"F53 writes finalstate1 after registration even when its provider changed state")
	var early:=Kernel.execute(initialized,"F53",[17]);row=reply(early.pending);row.after.arena.encode_u32(at,0)
	result=Kernel.execute(initialized,"F53",[17],[row])
	check(result.ok and result.context_after.arena.decode_u32(at)==0 and result.source_order==["F53","F41"],"Changed initialization state exits before condition scanning or final registration")
	for bad:Variant in [null,true,3,"bad",[],{}]:check(not Kernel.execute(bad,"F53",[17]).ok,"Malformed task context rejects")
	for key:String in Kernel.CONTEXT_KEYS:
		var bad:=raw.duplicate(true);bad.erase(key);check(not Kernel.execute(bad,"F53",[17]).ok,"Missing task owner rejects: "+key)
	for operation:Variant in [null,true,3,"F51","F54"]:check(not Kernel.execute(raw,operation,[]).ok,"Unimplemented/malformed operation rejects explicitly")
	for args:Variant in [null,true,3,[],[150],[0xffffffff],[-1],[0,1]]:check(not Kernel.execute(raw,"F53",args).ok,"Invalid physical slot transport rejects")
	for clause:Variant in [-1,16384,0xffffffff,true,NAN,INF,0.25]:check(not Kernel.execute(raw,"F47",[17,clause]).ok,"Invalid clause transport domain rejects")
	check(not Kernel.execute(raw,"F38",[0xffffffff]).ok,"Packed handle slots outside150 cannot touch host memory")
	var malformed:=raw.duplicate(true);malformed.arena.resize(5399);check(not Kernel.execute(malformed,"F53",[17]).ok,"Truncated arena rejects")
	malformed=raw.duplicate(true);malformed.program=PackedByteArray([1]);check(not Kernel.execute(malformed,"F53",[17]).ok,"Missing block bytes reject before a fabricated callback")
	var mismatched:Array=replies.duplicate(true);mismatched[0].cursor_before_u32=129
	check(not Kernel.execute(initialized,"F53",[17],mismatched).ok,"Wrong invocation-local cursor cannot resume")
	mismatched=replies.duplicate(true);mismatched[0].after.caller_ip_u32=17
	check(not Kernel.execute(initialized,"F53",[17],mismatched).ok,"A local callback cannot secretly alter the caller cursor")
	mismatched=replies.duplicate(true);mismatched[0].after.program[0]^=1
	check(not Kernel.execute(initialized,"F53",[17],mismatched).ok,"Program bytes remain readonly across every provider")
	mismatched=replies.duplicate(true);mismatched.append(replies[-1].duplicate(true));check(not Kernel.execute(initialized,"F53",[17],mismatched).ok,"Unused replies do not silently succeed")
	var cycle:Dictionary=raw.duplicate(true);cycle.module_refs={"0":cycle}
	check(Kernel.decode_context(cycle).is_empty() and not Kernel.execute(cycle,"F53",[17]).ok and Kernel._copy_context(cycle).is_empty(),"Cyclic forged fields reject before recursive copying")
	cycle.module_refs={};cycle.clear()
	var cycle_rows:Array=[];cycle_rows.append(cycle_rows)
	check(Kernel.decode_observations(cycle_rows)==null and not Kernel.execute(raw,"F53",[17],cycle_rows).ok,"Cyclic observations reject before duplication")
	cycle_rows.clear()
	check(digest(raw)==original,"Pending, completed and rejected lifecycle calls never mutate input owners")
func buffer(key:String)->PackedByteArray:
	if hydrated.has(key):return hydrated[key].duplicate()
	var entry:Dictionary=buffers[key];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(raw)
	check(raw.size()==int(entry.byte_count) and h.finish().hex_encode()==key,"Native arena/program pool has exact decompressed bytes")
	hydrated[key]=raw.duplicate();return raw
func hydrate(value:Dictionary)->Dictionary:
	var result:Dictionary=value.duplicate(true)
	for key:String in ["arena","program"]:
		var raw:Variant=value[key]
		result[key]=buffer(str(raw.buffer_sha256)) if raw is Dictionary else buffer(str(raw)) if buffers.has(str(raw)) else str(raw).hex_decode()
	return Kernel.decode_context(result)
func native_controls(doc:Dictionary)->void:
	check(doc.profile==Kernel.PROFILE and int(doc.case_count)==doc.cases.size(),"Native task corpus declares its complete case inventory")
	check(not doc.get("expected_arithmetic_calculated_in_python",true),"Task expected results originate in original instructions")
	check(int(doc.whole_original_procedures)==4 and int(doc.whole_original_instructions)==177,"Four complete uploaded-DOS bodies are proved, including their actual shorter variants")
	check(int(doc.fresh_process_runs)==3 and int(doc.reverse_repeat_cases)==int(doc.case_count),"Fresh native cohorts and reverse execution preserve exact results")
	check(int(doc.actual_original_module_cases)==105,"All105 original module initialization witnesses remain in the independent corpus")
	check(int(doc.consecutive_native_state_transitions)==12,"Dependent source cancellation/generation controls are counted separately from fresh inputs")
	check(int(doc.F51_NULL_transport_token_u32)==0xffffffff,"Native NULL allocation has a separate token from physical slot0")
	check(doc.F52_zero_handle_is_defined,"A successful wrapped handle0 remains a defined scalar result")
	var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PROOF+"instruction-proof.json"))
	check(proof.all_whole_instructions_equal and int(proof.whole_procedure_count)==4 and int(proof.whole_instruction_count)==177,"Actual whole instruction proof is complete")
	check(proof.source_variants.size()==2 and proof.source_variants[0].procedure=="F38" and proof.source_variants[1].procedure=="F47","DOS versus JJFFE state/count guard differences are explicit provenance")
	for name:String in doc.proofs_sha256:check(FileAccess.get_sha256(PROOF+name)==doc.proofs_sha256[name],"Native lifecycle capture current: "+name)
	var operations:Dictionary={};var actual_modules:=0;var native_observations:=0;var chain_after:Dictionary={};var chain_count:=0;var saw_wrap:=false;var opaque_cases:=0
	for row:Dictionary in doc.cases:
		var before:=hydrate(row.context_before);var expected:=hydrate(row.expected.context_after);var observations:Array=[]
		for item:Dictionary in row.observations:
			var reply_row:Dictionary=item.duplicate(true);reply_row.before=hydrate(item.before);reply_row.after=hydrate(item.after);observations.append(reply_row)
		var decoded:Variant=Kernel.decode_observations(observations)
		check(not before.is_empty() and not expected.is_empty() and decoded is Array,"Full native arena/resource/cursor transport decodes: "+str(row.name))
		if before.is_empty() or expected.is_empty() or not decoded is Array:continue
		if str(row.name).begins_with("dependent-cancel-generation-") and not chain_after.is_empty():check(Kernel._same_context(before,chain_after),"Every dependent transition starts at the preceding complete actual after-state")
		var frozen:=digest([before,row.args,decoded]);var result:=Kernel.execute(before,row.operation,row.args,decoded)
		check(result.ok,"Whole original lifecycle case executes: "+str(row.name))
		if not result.ok:continue
		for key:String in Kernel.CONTEXT_KEYS:check(result.context_after[key]==expected[key],"Every native owner matches "+key+": "+str(row.name))
		check(result.source_order==row.expected.source_order and result.observations_used==decoded.size(),"Exact original lifecycle/provider order matches")
		check(result.return_defined==row.expected.return_defined and result.return_u32==int(row.expected.return_u32),"Only F52 exports the defined packed handle; void EAX is ignored")
		check(digest([before,row.args,decoded])==frozen,"Native-controlled requests and owners remain private")
		check(result.context_after.program==before.program and result.context_after.module_refs==before.module_refs,"Immutable code and module table remain unchanged")
		if row.operation!="F52":check(result.context_after.caller_ip_u32==before.caller_ip_u32,"Task-local cursors never replace the caller IP")
		operations[row.operation]=int(operations.get(row.operation,0))+1;native_cases+=1;provider_calls+=decoded.size()
		native_observations+=decoded.size()
		if str(row.name).begins_with("original-module-"):actual_modules+=1
		if str(row.name).begins_with("dependent-cancel-generation-"):
			var slot:=int(row.args[0])&65535
			if before.arena.decode_u16(slot*36+6)==65535 and result.context_after.arena.decode_u16(slot*36+6)==0:saw_wrap=true
			chain_after=result.context_after.duplicate(true);chain_count+=1
		if str(row.name).begins_with("opaque-unused-host-collision-"):
			var slot:=int(row.args[0])&65535
			check(before.arena.decode_u32(slot*36+32)==0x60000008 and result.context_after.arena.decode_u32(slot*36+32)==0x60000008,"An opaque unused source word stays numeric even when it equals the host program address")
			opaque_cases+=1
	check(operations.size()==4,"All four original lifecycle bodies have independent controls")
	check(actual_modules==105 and native_observations==int(doc.typed_boundary_count),"The actual-module and typed-boundary censuses come from executed rows")
	check(chain_count==12 and saw_wrap and opaque_cases==2,"Dependent16bit wrap and typed opaque-word provenance controls really execute")
	check(doc.original_fault_domains_separate.size()==1 and doc.original_fault_domains_separate[0].operation=="F52" and int(doc.original_fault_domains_separate[0].native_returncode)==-11 and not doc.original_fault_domains_separate[0].after_state_claimed,"Original NULL-allocation SIGSEGV stays separate from normal handles and has no invented after-state")
	for path:String in doc.get("source_dependencies_sha256",{}):check(FileAccess.get_sha256("res://"+path)==doc.source_dependencies_sha256[path],"Native dependency current: "+path)
func run()->void:
	directed_controls();var doc:Dictionary={};var sources:Dictionary={}
	if FileAccess.file_exists(FIXTURE):
		doc=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Native task fixture is pinned")
		buffers=doc.get("buffer_pool",{});native_controls(doc)
	else:check(false,"Native task fixture pending; directed controls alone do not prove parity")
	for path:String in ["scripts/source_mission_task.gd","tests/test_source_mission_task.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if not doc.is_empty():
		sources[FIXTURE.trim_prefix("res://")]=FileAccess.get_sha256(FIXTURE)
		for path:String in doc.get("source_dependencies_sha256",{}):sources[path]=FileAccess.get_sha256("res://"+path)
	for name:String in ["instruction-proof.json","source-procedures.asm","task-native.s","task-host.c","dos-disassembly.txt"]:
		if FileAccess.file_exists(PROOF+name):sources[PROOF.trim_prefix("res://")+name]=FileAccess.get_sha256(PROOF+name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Kernel.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"provider_calls":provider_calls,"native_fixture_pending":doc.is_empty(),"sources":sources,"Main_integrated":false,"full_F41_executed":false},"\t")+"\n");file.close()
	print("SOURCE MISSION TASK TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
