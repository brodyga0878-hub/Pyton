extends SceneTree
# Independent read-only public-API audit. No VM/kernel method is substituted.
const VM=preload("res://scripts/source_mission_vm.gd")
const State=preload("res://scripts/source_mission_vm_state.gd")
const Programs=preload("res://scripts/source_mission_programs.gd")
const Events=preload("res://scripts/source_events.gd")
const Guards=preload("res://scripts/source_mission_guards.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const HERE:="res://validation/mission-statements-2026-11-19/independent-vm-audit/"
const BASE:=0x4801c4
const MASK:=0xffffffff
var checks:=0
var failures:=0
var labels:Array=[]
var resources:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1;labels.append({"condition":label,"passed":value})
	if not value:failures+=1;push_error(label)
func zero(count:int,fill:int=0)->PackedByteArray:
	var result:=PackedByteArray();result.resize(count);result.fill(fill);return result
func literal(value:int,opcode:int=2)->PackedByteArray:
	var result:=zero(5);result[0]=opcode;result.encode_u32(1,value&MASK);return result
func put(program:PackedByteArray,at:int,value:PackedByteArray)->void:
	for index in range(value.size()):program[at+index]=value[index]
func private_seed(fill:int=0xa5)->Dictionary:return {"seed_hex":zero(156,fill).hex_encode(),"defined_hex":"00".repeat(156)}
func command(kind:String="statements",operation:String="F41",args:Array=[],slot:int=7,ip:int=256,frames:Array=[{}])->Dictionary:
	return {"kind":kind,"operation":operation,"args":args,"task_slot_s32":slot,"ip_u32":ip,"statement_frames":[private_seed()] if frames==[{}] else frames.duplicate(true)}
func core()->Dictionary:
	var program:=zero(1024);program.encode_u32(0,BASE+96);program.encode_u32(8,0);program.encode_u32(12,MASK);program.encode_u32(16,4);program.encode_u32(20,0x60bde0);program.encode_u32(28,BASE+64);program.encode_u32(32,BASE+80)
	program.encode_u32(64,BASE+256);program.encode_u32(68,1);program.encode_u32(72,BASE+512);program.encode_u32(80,BASE+384);program.encode_u32(84,0);put(program,96,literal(2,6));put(program,512,literal(0,4))
	var root:=zero(16384);root.encode_u32(0,0x12345678);root.encode_u32(4,0x121cf7);root.encode_u32(0xc8,454);root.encode_u32(0xcc,792)
	var tail:=zero(6160);tail.encode_u32(0x180c,1)
	var arena:=zero(5400);var at:=7*36
	arena.encode_u32(at,1);arena.encode_u32(at+4,0x30007);arena.encode_u32(at+8,BASE+64);arena.encode_u32(at+12,0);arena.encode_u32(at+16,BASE+64);arena.encode_u32(at+20,0);arena.encode_u32(at+28,BASE);arena.encode_u32(at+32,1)
	var variables:=zero(16);variables.encode_u32(0,0x30007);variables.encode_u32(8,91);variables.encode_u32(12,13)
	return {"root":root,"root_tail":tail,"bank":zero(38986),"event_registers":zero(284),"module_globals":zero(40),"program":program,"program_base_u32":BASE,"metadata":Programs.read(resources,"expression_metadata",0,1088),"temporary_event_index_s32":-7,"scratch_words":zero(32,0x77),"arena":arena,"tree_root_u32":0,"nodes":{},"next_node_id_u32":1,"task_variables":{"1":variables},"next_variable_id_u32":2,"definitions":{"0":{"descriptor_ref_u32":BASE,"cleanup_instruction_u32":0,"variable_words_u32":4}},"market_records":{"2147483648":zero(308,0x53)},"text_buffer":zero(128),"text_cursor_u32":0,"vectors":Programs.read(resources,"vectors",0,324)}
func fingerprint(value:Variant)->String:return Clock._hash({"v":Scan.json_value(value)})
func world_row(pending:Dictionary)->Dictionary:
	return {"kind":pending.kind,"args":pending.args.duplicate(),"task_slot_s32":int(pending.task_slot_s32),"ip_before_u32":int(pending.ip_before_u32),"ip_after_u32":int(pending.ip_before_u32),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0,"input_hex":pending.input_hex,"output_hex":"","input_defined_hex":pending.input_defined_hex,"output_defined_hex":""}
func complete(before:Dictionary,request:Dictionary,policy:Callable=Callable())->Dictionary:
	var rows:Array=[]
	for index in range(32):
		var result:=VM.execute(before,request,rows)
		if result.get("ok",false) or not result.get("pending") is Dictionary:return {"result":result,"observations":rows}
		var row:=world_row(result.pending)
		if policy.is_valid():policy.call(row,index)
		rows.append(row)
	return {"result":{"ok":false,"reason":"audit_provider_budget"},"observations":rows}
func roundtrip(value:Dictionary)->Dictionary:return VM.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(value))))
func decode_and_stop()->void:
	var before:=core();check(VM._context(before) and before.size()==21,"Core21 has one occurrence of every persisted owner")
	var registered:=VM.execute(before,command("events","F44",[77,1,2,0x12345678,3,4],-1,MASK,[]))
	check(registered.get("ok",false),"Real registry node contributes to the cold numeric owner audit")
	if registered.get("ok",false):before=registered.context_after
	var decoded:=roundtrip(before);check(decoded==before,"Core21 cold codec normalizes every scalar and all node/definition IDs")
	check(decoded.definitions["0"].descriptor_ref_u32 is int and decoded.nodes["1"].key_u32[0] is int and decoded.text_cursor_u32 is int,"Decoded definition, registry and text cursor are canonical integers")
	check(not before.has("ip_u32") and not before.has("task_record") and before.task_variables is Dictionary,"Invocation cursor and selected record are not duplicate persistent owners")
	var frozen:=fingerprint(before);var result:=VM.execute(before,command())
	check(result.get("ok",false) and result.cursor_after_u32==257 and result.source_order==["F41"],"Actual stop consumes one byte and closes without a world F41 substitute")
	if result.get("ok",false):
		check(result.context_after==before and result.statement_frames_used==1,"Stop preserves every persistent byte and consumes one supplied private frame")
		check(result.statement_frames_after[0].scratch_after_hex==private_seed().seed_hex and result.statement_frames_after[0].scratch_defined_hex==private_seed().defined_hex,"Uninitialized private bytes retain explicit seed and unknown mask")
		result.context_after.root[0]^=0x40;check(fingerprint(before)==frozen,"Returned after-state does not alias caller input buffers")
	check(not VM.execute(before,command("statements","F41",[],7,256,[])).ok,"A statement invocation cannot fabricate an omitted scratch seed")
	check(not VM.execute(before,command("statements","F41",[],7,256,[private_seed(),private_seed()])).ok,"Unconsumed extra FIFO frame seeds reject")
	var bad:=command();bad.statement_frames[0].seed_hex="00".repeat(155);check(not VM.execute(before,bad).ok,"Scratch byte length is exact156")
	bad=command();bad.statement_frames[0].defined_hex="02".repeat(156);check(not VM.execute(before,bad).ok,"Scratch definedness admits only00or01")
	bad=command();bad.erase("statement_frames");check(not VM.execute(before,bad).ok,"Scratch FIFO field cannot silently default")
	for key:String in VM.EXTRA_KEYS:
		var missing:=before.duplicate(true);missing.erase(key);check(not VM._context(missing) and VM.decode_context(missing).is_empty(),"Missing VM owner rejects: "+key)
func world_contract()->void:
	var before:=core();put(before.program,256,PackedByteArray([18])+literal(9)+PackedByteArray([0]));var pending:=VM.execute(before,command())
	check(not pending.ok and pending.pending.kind=="F105","Actual F41 reaches its concrete world worker rather than external F41")
	var row:=world_row(pending.pending);row.after.root.encode_u32(0x200,0xaabbccdd);var owner:=State.new();owner.configure(before);var frozen:=fingerprint(owner.snapshot())
	var good:=VM.execute(before,command(),[row]);check(good.get("ok",false) and good.context_after.root.decode_u32(0x200)==0xaabbccdd,"Exact world before/after propagates a concrete world mutation")
	for field:String in ["task_slot_s32","ip_before_u32","ip_after_u32"]:
		var bad:=row.duplicate(true);bad[field]=int(bad[field])+1;check(not VM.execute(before,command(),[bad]).ok and not owner.prepare(command(),[bad]).ok and fingerprint(owner.snapshot())==frozen,"Wrong callback frame rejects atomically: "+field)
	var forbidden:=row.duplicate(true);forbidden.kind="F41";check(not VM.execute(before,command(),[forbidden]).ok,"World observations cannot replace the real F41 body")
	for field:String in ["program","metadata","vectors"]:
		var bad:=row.duplicate(true);bad.after[field][0]^=1;check(not VM.execute(before,command(),[bad]).ok,"Readonly source owner cannot change: "+field)
	var bad:=row.duplicate(true);bad.after.definitions["0"].descriptor_ref_u32+=4;check(not VM.execute(before,command(),[bad]).ok,"Readonly definition table cannot change")
	bad=row.duplicate(true);bad.after.text_buffer.append(0);check(not VM.execute(before,command(),[bad]).ok,"World service cannot resize persistent text owner")
	bad=row.duplicate(true);bad.after.next_variable_id_u32=1;check(not VM.execute(before,command(),[bad]).ok,"Logical heap ID counter cannot decrease")
	bad=row.duplicate(true);bad.after.task_variables["1"].resize(20);check(not VM.execute(before,command(),[bad]).ok,"A surviving allocation cannot change its byte extent")
	bad=row.duplicate(true);bad.return_u32=1;check(not VM.execute(before,command(),[bad]).ok,"Ignored void worker EAX is normalized rather than invented as a result")
	bad=row.duplicate(true);bad.input_defined_hex="01";check(not VM.execute(before,command(),[bad]).ok,"Input defined mask must match exact input extent")
	bad=row.duplicate(true);bad.output_hex="00";bad.output_defined_hex="02";check(not VM.execute(before,command(),[bad]).ok,"Output defined masks cannot claim a third provenance state")
	bad=row.duplicate(true);var added:=Events.execute(VM._view(bad.after,Events.CONTEXT_KEYS),"F44",[90,3,4,0x12345678,5,6])
	for key:String in Events.CONTEXT_KEYS:bad.after[key]=added.context_after[key]
	check(not VM.execute(before,command(),[bad]).ok,"Unjournaled event-tree mutation cannot pass as a world byte patch")
	bad.registry_actions=[{"operation":"F44","args":[90,3,4,0x12345678,5,6]}];var accepted:=VM.execute(before,command(),[bad])
	check(accepted.get("ok",false) and accepted.context_after.nodes.size()==1 and accepted.source_order.count("F44")==1,"Actual registry journal replays one source registration without duplicate order")
	check(not VM.execute(before,command(),[row,row]).ok,"Unused duplicate world observations reject")
	check(fingerprint(owner.snapshot())==frozen,"All failed world controls preserve live owned state")
func free_or_retarget(row:Dictionary,_index:int)->void:
	if row.kind!="F106":return
	row.return_u32=1
	if row.args[0]==9:row.after.task_variables.erase("1")
	elif row.args[0]==10:
		var replacement:=zero(32);replacement.encode_u32(12,41);row.after.task_variables["2"]=replacement;row.after.next_variable_id_u32=3;row.after.arena.encode_u32(7*36+32,2)
	elif row.args[0]==11:row.after.arena.encode_u32(7*36+28,BASE+700);row.after.module_globals.encode_u32(4,41)
func selected_lifetime()->void:
	var before:=core();put(before.program,256,PackedByteArray([7,45])+literal(9)+literal(2,4)+PackedByteArray([0]));var done:=complete(before,command(),free_or_retarget)
	check(done.result.get("ok",false) and done.result.context_after.task_variables.is_empty() and done.result.context_after.event_registers.decode_u32(8)==1,"A literal/register continuation after free finishes without resurrecting retired locals")
	before=core();put(before.program,256,PackedByteArray([7,13,45])+literal(9)+literal(0,6)+literal(2,4)+PackedByteArray([0]));done=complete(before,command(),free_or_retarget)
	check(not done.result.get("ok",false) and not done.result.has("context_after") and str(done.result.reason).contains("dangling_selected_task_variable_read"),"An actual subsequent read through the freed task pointer rejects the bounded profile")
	before=core();put(before.program,256,PackedByteArray([7,13,45])+literal(10)+literal(3,6)+literal(2,4)+PackedByteArray([0]));done=complete(before,command(),free_or_retarget)
	check(done.result.get("ok",false) and done.result.context_after.event_registers.decode_u32(8)==42 and done.result.context_after.task_variables["1"]==before.task_variables["1"] and done.result.context_after.task_variables["2"].size()==32,"Recursive expression refetches current task heap pointer and respects new owner size")
	before=core();put(before.program,256,PackedByteArray([7,13,45])+literal(11)+literal(0,5)+literal(2,4)+PackedByteArray([0]));before.program.encode_u32(700+20,0x60bde4);done=complete(before,command(),free_or_retarget)
	check(done.result.get("ok",false) and done.result.context_after.event_registers.decode_u32(8)==42,"Recursive expression refetches changed module descriptor before global read")
	before=core();before.program.encode_u32(20,0x60bde1);var pure:=VM.execute(before,command("expression","F20",[],7,256,[]));check(pure.get("ok",false),"Unrepresentable global pointer remains unused transport for a pure F20")
	put(before.program,256,literal(0,5));var actual:=VM.execute(before,command("expression","F31",[],7,256,[]));check(not actual.get("ok",false) and str(actual.reason).contains("invalid_selected_module_global_read"),"Actual read of an unrepresentable global projection rejects without engine errors")
func mutate_root(row:Dictionary,_index:int)->void:row.after.root.encode_u32(0x240,0x66778899)
func stop_and_branch_order()->void:
	var before:=core();before.arena.encode_u32(7*36+8,0);put(before.program,256,PackedByteArray([8])+literal(0x30007)+PackedByteArray([18])+literal(99)+PackedByteArray([0]));var done:=complete(before,command(),mutate_root)
	check(done.result.get("ok",false) and done.observations.size()==1 and done.result.context_after.arena.decode_u32(7*36+4)==0x40007,"Self cancellation compares the post-F38 handle and continues after generation increment")
	before=core();before.arena.encode_u32(7*36+8,0);before.program.encode_u32(12,0);before.definitions["0"].cleanup_instruction_u32=BASE+256;put(before.program,256,PackedByteArray([8])+literal(0x30007)+PackedByteArray([18])+literal(99)+PackedByteArray([0]));var stopped:=VM.execute(before,command())
	check(stopped.get("ok",false) and stopped.cursor_after_u32==262 and stopped.source_order.count("F41")==1 and stopped.context_after.arena.decode_u32(7*36)==5,"Self cancellation stops when cleanup leaves the compared packed handle unchanged")
	before=core();var block:=PackedByteArray([9]);var index:=zero(4);index.encode_u32(0,1);block.append_array(index);block.append_array(PackedByteArray([18]));block.append_array(literal(99));put(before.program,256,block);stopped=VM.execute(before,command())
	check(stopped.get("ok",false) and stopped.cursor_after_u32==261 and stopped.context_after.arena.decode_u32(7*36)==4 and stopped.context_after.arena.decode_u32(7*36+16)==BASE+80 and stopped.context_after.arena.decode_u32(7*36+20)==1,"Block switch mutates the current task and stops before later world code")
	before=core();var jump:=PackedByteArray([2]);jump.append_array(literal(1));var displacement:=zero(4);displacement.encode_u32(0,0x7fffffff);jump.append_array(displacement);jump.append(0);put(before.program,256,jump);stopped=VM.execute(before,command())
	check(stopped.get("ok",false) and stopped.cursor_after_u32==267 and stopped.source_order.count("F20")==1,"True conditional skips its displacement without reading it")
func scratch_writer(row:Dictionary,_index:int)->void:
	if row.kind=="F345":
		var raw:PackedByteArray=row.input_hex.hex_decode();var known:PackedByteArray=row.input_defined_hex.hex_decode();raw.encode_u32(44,0x11223344)
		for index in range(4):known[44+index]=1
		row.output_hex=raw.hex_encode();row.output_defined_hex=known.hex_encode()
func scratch_and_recursion()->void:
	var before:=core();put(before.program,256,PackedByteArray([23])+literal(5)+PackedByteArray([24])+literal(6)+PackedByteArray([0]));var done:=complete(before,command(),scratch_writer)
	check(done.result.get("ok",false) and done.observations.size()==2,"Consecutive UI statements retain one private packet owner")
	if done.result.get("ok",false):check(done.observations[1].input_hex.hex_decode().decode_u32(44)==0x11223344 and done.observations[1].input_defined_hex.right(8)=="01".repeat(4),"Callback packet bytes and definedness survive until the next source use")
	before=core();put(before.program,256,PackedByteArray([7])+literal(9)+literal(2,6)+PackedByteArray([0]));before.event_registers.encode_u32(0,1);put(before.program,517,PackedByteArray([18])+literal(1)+PackedByteArray([0]))
	for index in range(36):before.arena[8*36+index]=before.arena[7*36+index]
	before.arena.encode_u32(8*36+4,0x10008);before.arena.encode_u32(8*36+32,2);before.task_variables["2"]=zero(16);before.next_variable_id_u32=3
	var key:=[4,Guards.TASK_BASE+7*36,2,Guards.F47_WORD,Guards.TASK_BASE+8*36,0];var registration:=VM.execute(before,command("events","F44",key,-1,MASK,[]));before=registration.context_after
	var request:=command("statements","F41",[],7,256,[private_seed(0x11),private_seed(0x22)]);done=complete(before,request,mutate_root)
	check(done.result.get("ok",false) and done.result.statement_frames_used==2 and done.result.source_order.count("F41")==2 and done.result.source_order.has("F47"),"Real F48 snapshot/F47 condition recursively executes a second real F41")
	if done.result.get("ok",false):
		var afters:Array=done.result.statement_frames_after;check(afters.size()==2 and afters[0].ordinal_u32==1 and afters[1].ordinal_u32==0 and afters[0].scratch_after_hex==private_seed(0x22).seed_hex and afters[1].scratch_after_hex==private_seed(0x11).seed_hex,"Frame seed consumption is FIFO and private scratch returns in source unwind order")
	check(not VM.execute(before,command(),done.observations).ok,"Recursive source entry cannot use an unsupplied second frame")
func expression_buffer_masks()->void:
	var before:=core();put(before.program,256,PackedByteArray([67])+literal(7));var request:=command("expression","F31",[],7,256,[]);var pending:=VM.execute(before,request)
	check(not pending.ok and pending.pending.kind=="F870","Old expression output-buffer provider remains explicit")
	var row:=world_row(pending.pending);var output:=zero(16);output.encode_u32(4,0xabcdef12);row.output_hex=output.hex_encode();row.output_defined_hex="01".repeat(16)
	var result:=VM.execute(before,request,[row]);check(result.get("ok",false) and int(result.return_u32)==0xabcdef12,"Fully defined old-expression buffer produces its real consumed scalar")
	row.output_defined_hex="00".repeat(16);result=VM.execute(before,request,[row]);check(not result.get("ok",false) and not result.has("context_after") and str(result.reason).contains("expression_output_bytes_outside_defined_transport_profile"),"Unknown old-expression output rejects the conservative VM transport without claiming a DOS fault")
func spawn_world(row:Dictionary,_index:int)->void:
	var at:=116+17*338
	if row.kind=="F927":row.return_u32=at;row.after.bank[at+0x86]=77
	elif row.kind=="F1507":row.after.bank[at+0x86]=91
func spawn_abi()->void:
	var before:=core();var values:Array=[38,7,17,0x11223344,0xcba87654,3,0xffff8001,32,0x8000];var stream:=PackedByteArray([50])
	for value:int in values:stream.append_array(literal(value))
	stream.append_array(literal(2,4));stream.append(0);put(before.program,256,stream)
	var done:=complete(before,command(),spawn_world);check(done.result.get("ok",false),"F41 nine-word creation closes through real Spawn rather than a world F40 substitute")
	if done.result.get("ok",false):
		var at:=116+17*338
		check(done.observations.size()==2 and done.observations[0].kind=="F927" and done.observations[1].kind=="F1507" and done.observations[0].args==[1,116+7*338,29,38],"Only allocator and actual DOS position remain typed after nine source arguments")
		check(done.result.context_after.event_registers.decode_u32(8)==91 and done.result.cursor_after_u32==308,"F41 rereads returned body+86 after position mutation before real F37 store")
		check(done.result.context_after.bank.decode_u32(at+0xa0)==17 and done.result.context_after.bank.decode_u32(at+0xb0)==0x11223344 and done.result.context_after.bank.decode_u32(at+0xc2)==3 and done.result.context_after.bank.decode_u16(at+0xc6)==0x8001 and done.result.context_after.bank[at+0xc8]==32 and done.result.context_after.bank.decode_u16(at+0xcc)==0x8000,"Nine-argument widths and order survive the full F41/Spawn adapter")
		check(done.result.source_order.has("F1510") and done.result.source_order.has("F1338") and done.result.source_order.has("F1675") and done.result.statement_frames_used==1,"Spawn's closed native arithmetic does not allocate a fake statement frame")
func owned_and_hostile()->void:
	var before:=core();put(before.program,256,PackedByteArray([7])+literal(67)+literal(2,4)+PackedByteArray([0]));var state:=State.new();check(state.configure(before),"Owned VM configures once with full Core21")
	var frozen:=fingerprint(state.snapshot());var prepared:=state.prepare(command());check(prepared.get("ok",false) and fingerprint(state.snapshot())==frozen,"Prepare remains private and reviewable")
	if prepared.get("ok",false):
		var changed:=prepared.duplicate();changed.receipt=prepared.receipt.duplicate(true);changed.receipt.cursor_after_u32+=1;check(not state.commit(changed) and fingerprint(state.snapshot())==frozen,"Forged receipt cannot commit or mutate owned state")
		check(state.commit(prepared) and state.generation()==1 and not state.commit(prepared),"Verified candidate commits exactly once")
		var snapshot:Dictionary=JSON.parse_string(JSON.stringify(state.snapshot()));var cold:=State.new();check(cold.restore(snapshot) and cold.raw_context()==state.raw_context(),"Cold snapshot replays its last full statement execution")
		var corrupt:Dictionary=snapshot.duplicate(true);corrupt.core.context.event_registers="01"+str(corrupt.core.context.event_registers).substr(2);corrupt.erase("snapshot_sha256");corrupt.snapshot_sha256=Clock._hash(corrupt);check(not cold.restore(corrupt),"Re-signed invented after-owner fails cold replay")
		var stale:=state.prepare(command());state.restore(state.snapshot());check(not state.commit(stale),"Restoring equal owners invalidates stale preparation revisions")
		stale=state.prepare(command());state.configure(before);check(not state.commit(stale),"Reconfiguring an earlier equal core prevents ABA commit")
	var cyc:Dictionary={};cyc.self=cyc;check(VM.decode_context(cyc).is_empty() and not VM.execute(before,cyc).ok and not state.restore(cyc),"Cyclic core, command and snapshot are rejected before copies");cyc.clear()
	var cycle:Array=[];cycle.append(cycle);var bad:=command();bad.args=cycle;check(not VM.execute(before,bad).ok and not state.prepare(bad).ok,"Cyclic command arguments reject before serialization");cycle.clear()
	cycle=[];cycle.append(cycle);check(not VM.execute(before,command(),cycle).ok and not state.prepare(command(),cycle).ok,"Cyclic world observation graph rejects before serialization");cycle.clear()
func baseline_and_report()->void:
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(HERE+"frozen-constituents.json"))
	for path:String in baseline:check(FileAccess.get_sha256("res://"+path)==str(baseline[path]),"Frozen0.31 constituent remains unchanged: "+path)
	var sources:Dictionary={}
	for path:String in ["scripts/source_mission_vm.gd","scripts/source_mission_vm_state.gd","scripts/source_mission_statements.gd","scripts/source_mission_spawn.gd","validation/mission-statements-2026-11-19/independent-vm-audit/audit.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	var report:Dictionary={"checks":checks,"failures":failures,"conditions":labels,"source_hashes":sources,"audit_scope":"Public Core21/VM/State, read-only implementation review","old_kernels_modified":false,"Main_integrated":false};var file:=FileAccess.open(HERE+"report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t")+"\n")
func run()->void:
	resources=Programs.load_original();check(not resources.is_empty(),"Pinned original program resources load before audit")
	if not resources.is_empty():decode_and_stop();world_contract();selected_lifetime();stop_and_branch_order();scratch_and_recursion();expression_buffer_masks();spawn_abi();owned_and_hostile()
	baseline_and_report();print("INDEPENDENT MISSION VM AUDIT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
