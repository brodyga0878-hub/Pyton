extends SceneTree
const Runtime=preload("res://scripts/source_mission_runtime.gd")
const State=preload("res://scripts/source_mission_runtime_state.gd")
const Events=preload("res://scripts/source_events.gd")
const Guards=preload("res://scripts/source_mission_guards.gd")
const Programs=preload("res://scripts/source_mission_programs.gd")
const Models=preload("res://scripts/source_mission_models.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const FIXTURE:="res://tests/fixtures/source_mission_runtime_native.json"
const FIXTURE_SHA:="3a2523e896e8d3cbdc3b7e149a9a591fbca2a68485e9ecdfc05cd9d41b6b7421"
const REPORT:="res://build/current-test-reports/source-mission-runtime.json"
const BASE:=0x4801c4
const MASK:=0xffffffff
var checks:=0
var failures:=0
var native_cases:=0
var directed_cases:=0
var sequence_steps:=0
var programs:Dictionary={}
var pool:Dictionary={}
var hydrated:Dictionary={}
var native_edges:=0
var native_world_calls:=0
var native_dependency_calls:=0
var native_original_resource_cases:=0
var native_fault_domains:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<35:push_error(message)
func zeros(count:int,fill:int=0)->PackedByteArray:
	var out:=PackedByteArray();out.resize(count);out.fill(fill);return out
func literal(value:int,token:int=2)->PackedByteArray:
	var out:=zeros(5);out[0]=token;out.encode_u32(1,value&MASK);return out
func put(code:PackedByteArray,at:int,value:PackedByteArray)->void:
	for index in range(value.size()):code[at+index]=value[index]
func digest(value:Variant)->String:return var_to_bytes(value).hex_encode().sha256_text()
func command(kind:String,operation:String,args:Array=[],slot:int=7,ip:int=0)->Dictionary:return {"kind":kind,"operation":operation,"args":args,"task_slot_s32":slot,"ip_u32":ip}
func core()->Dictionary:
	var program:=zeros(512);program.encode_u32(0,BASE+96);program.encode_u32(8,2);program.encode_u32(12,MASK);program.encode_u32(16,4);program.encode_u32(20,0x60bde0);program.encode_u32(28,BASE+64)
	program.encode_u32(64,BASE+128);program.encode_u32(68,1);program.encode_u32(72,BASE+160)
	put(program,96,literal(2,6));put(program,101,literal(3,6));put(program,160,literal(0,4));put(program,192,literal(11));put(program,197,literal(22))
	var root:=zeros(16384);root.encode_u32(0xc8,116+338);root.encode_u32(0xcc,116+676)
	var tail:=zeros(6160);tail.encode_u32(0x180c,1)
	var arena:=zeros(5400);var at:=7*36;arena.encode_u32(at,1);arena.encode_u16(at+4,7);arena.encode_u16(at+6,3);arena.encode_u32(at+8,BASE+64);arena.encode_u32(at+12,0);arena.encode_u32(at+16,BASE+64);arena.encode_u32(at+20,0);arena.encode_u32(at+28,BASE);arena.encode_u32(at+32,1)
	var variables:=zeros(16);variables.encode_u32(0,arena.decode_u32(at+4));variables.encode_u32(4,0x10203040)
	return {"root":root,"root_tail":tail,"bank":zeros(38986),"event_registers":zeros(284),"module_globals":Programs.initial_module_globals(programs),"program":program,"program_base_u32":BASE,"metadata":Programs.read(programs,"expression_metadata",0,1088),"temporary_event_index_s32":-7,"scratch_words":zeros(32,0xa5),"arena":arena,"tree_root_u32":0,"nodes":{},"next_node_id_u32":1,"task_variables":{"1":variables},"next_variable_id_u32":2,"definitions":{"0":{"descriptor_ref_u32":BASE,"cleanup_instruction_u32":0,"variable_words_u32":4}},"market_records":{}}
func complete(before:Dictionary,request:Dictionary,policy:Callable=Callable())->Dictionary:
	var rows:Array=[]
	for step in range(256):
		var result:=Runtime.execute(before,request,rows)
		if result.get("ok",false) or not result.get("pending") is Dictionary:return {"result":result,"observations":rows}
		var pending:Dictionary=result.pending
		var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"task_slot_s32":int(pending.task_slot_s32),"ip_before_u32":int(pending.ip_before_u32),"ip_after_u32":int(pending.ip_before_u32),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0,"input_hex":"","output_hex":""}
		if policy.is_valid():policy.call(row,step)
		rows.append(row)
	return {"result":{"ok":false,"reason":"test_world_limit"},"observations":rows}
func f41(row:Dictionary,_step:int)->void:
	if row.kind=="F41":row.ip_after_u32=int(row.ip_before_u32)+1;row.after.root.encode_u32(0x200,row.after.root.decode_u32(0x200)+1)
func market(row:Dictionary,_step:int)->void:
	if row.kind=="F649":
		var key:=str(int(row.args[0]));row.return_u32=1
		if not row.after.market_records.has(key):row.after.market_records[key]=zeros(308,0x31 if key=="17" else 0x72)
func early_stop(row:Dictionary,_step:int)->void:
	if row.kind=="F41":row.after.arena.encode_u32(int(row.task_slot_s32)*36,0);row.ip_after_u32=int(row.ip_before_u32)+1
func market_read(row:Dictionary,_step:int)->void:
	if row.kind=="F649":row.return_u32=1;row.output_hex=row.after.market_records[str(int(row.args[0]))].hex_encode()
func equipment(row:Dictionary,_step:int)->void:
	if row.kind=="F392":row.return_u32=2
	elif row.kind=="F390":row.return_u32=1;row.after.bank[116+338+0x40]=0x91
func registry_world(row:Dictionary,_step:int)->void:
	if row.kind!="F41":return
	var key:=[77,11,22,0x12345678,0x33445566,3];var added:=Events.execute(Runtime._view(row.after,Events.CONTEXT_KEYS),"F44",key)
	if not added.get("ok",false):return
	for field:String in Events.CONTEXT_KEYS:row.after[field]=added.context_after[field]
	row.registry_actions=[{"operation":"F44","args":key}]
	row.ip_after_u32=int(row.ip_before_u32)+1
func monotonic_heap_world(row:Dictionary,_step:int)->void:
	if row.kind!="F41":return
	var id:=str(int(row.after.next_variable_id_u32));row.after.task_variables[id]=zeros(16);row.after.task_variables[id].encode_u32(0,0x12345678);row.after.next_variable_id_u32=int(row.after.next_variable_id_u32)+1
	row.ip_after_u32=int(row.ip_before_u32)+1
func signed_snapshot(value:Dictionary)->Dictionary:
	var out:=value.duplicate(true);out.erase("snapshot_sha256");out["snapshot_sha256"]=Clock._hash(out);return out
func register(before:Dictionary,key:Array)->Dictionary:
	var result:=Runtime.execute(before,command("events","F44",key,-1,MASK));check(result.get("ok",false),"Real F44 registers the shared owned tree");return result.context_after if result.get("ok",false) else before
func frame_and_resources()->void:
	var before:=core();check(Runtime._context(before) and before.size()==18,"Exactly eighteen persistent owners admit no invocation cursor")
	var cold:=Runtime.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(before))));check(cold==before,"All eighteen owners survive cold canonical JSON")
	var actual:=before.duplicate(true);actual.program=Programs.read(programs,"mission",0,57560);actual.definitions=Programs.events_definitions(programs)
	var module:=Programs.module(programs,2);actual.arena.encode_u32(7*36+24,2);actual.arena.encode_u32(7*36+28,int(BASE)+int(module.descriptor_offset_u32));actual.task_variables["1"]=zeros(int(module.variable_words_u32)*4);actual.event_registers.encode_u32(40*4,0x12345678)
	var result:=Runtime.execute(actual,command("expression","F31",[],7,13171))
	check(result.get("ok",false) and int(result.return_u32)==0x12345678 and int(result.cursor_after_u32)==13176,"Actual module2/block3/clause1 reads original DOS register40 bytes")
	if result.get("ok",false):check(result.context_after==actual,"Invocation expression cursor is not persisted in Core")
	var invalid:=actual.duplicate(true);invalid.arena.encode_u32(7*36+28,BASE)
	check(not Runtime.execute(invalid,command("expression","F31",[],7,13171)).ok,"Actual-image projection rejects a module/descriptor disagreement")
	invalid=actual.duplicate(true);invalid.task_variables["1"]=zeros(8)
	check(not Runtime.execute(invalid,command("expression","F31",[],7,13171)).ok,"Actual-image projection rejects a false local allocation size")
	var alloc:=Runtime.execute(actual,command("tasks","F52",[-1,0,73],-1,MASK))
	check(alloc.get("ok",false) and alloc.return_defined and int(alloc.return_u32)==65536 and int(alloc.cursor_after_u32)==MASK,"Actual original module0 allocates without a caller expression cursor")
	if alloc.get("ok",false):
		var first:Dictionary=Programs.block(programs,int(Programs.module(programs,0).block_offsets_u32[0]));var done:=complete(alloc.context_after,command("tasks","F53",[0],0,MASK),early_stop)
		check(done.result.get("ok",false) and done.observations.size()==1 and int(done.observations[0].ip_before_u32)==int(first.initialization_offset_u32) and done.result.context_after.arena.decode_u32(0)==0,"Actual original block initializer sourceVA projects to its exact F41 stream and honors changed state")
	var tampered:=actual.duplicate(true);tampered.program[0]^=1;check(not Runtime._context(tampered),"Original-image bytes cannot change while retaining source identity")
	tampered=actual.duplicate(true);tampered.definitions["0"].descriptor_ref_u32+=4;check(not Runtime._context(tampered),"Original descriptor table cannot be replaced under the same program witness")
	directed_cases+=7
func dual_cursor_create()->void:
	var before:=core();var frozen:=digest(before);var result:=Runtime.execute(before,command("tasks","F52",[7,0,0xabcdef01],7,192))
	check(result.get("ok",false),"F52 closes real F51/F31/F37 with no fabricated argument provider")
	if not result.get("ok",false):return
	check(result.return_defined and int(result.return_u32)==65536 and int(result.cursor_after_u32)==202,"F52 returns allocated slot0 generation1 handle and advances caller by two expressions")
	check(result.context_after.task_variables["2"].decode_u32(0)==65536 and result.context_after.task_variables["2"].decode_u32(4)==0xabcdef01 and result.context_after.task_variables["2"].decode_u32(8)==11 and result.context_after.task_variables["2"].decode_u32(12)==22,"Real callee local target stream binds both evaluated caller arguments and keeps allocator headers")
	check(result.context_after.arena.decode_u32(16)==BASE+64 and result.context_after.arena.decode_u32(20)==0,"F52 selects allocated task block0 after assignment")
	check(result.context_after.task_variables["1"]==before.task_variables["1"] and result.context_after.program==before.program and digest(before)==frozen,"Callee binding preserves caller locals and immutable instructions")
	var cursors:Array=[]
	for call:Dictionary in result.dependency_calls:
		if call.operation in ["F31","F37"]:cursors.append([call.operation,call.task_slot_s32,call.ip_u32,call.cursor_after_u32])
	check(cursors==[["F31",7,192,197],["F37",0,96,101],["F31",7,197,202],["F37",0,101,106]],"Nested calls retain independent caller and callee IPs across physical task slots")
	check(result.source_order==["F52","F51","F31","F20","F37","F20","F48","F31","F20","F37","F20","F48"],"Full source order expands both actual assignment events")
	directed_cases+=1
func allocator_transport()->void:
	var before:=core()
	for slot in range(6):before.arena.encode_u32(slot*36,1)
	var result:=Runtime.execute(before,command("events","F51",[0,0x77889900],-1,MASK))
	check(result.get("ok",false) and result.return_defined and int(result.return_u32)==6 and int(result.cursor_after_u32)==MASK,"Actual F51 physical pointer transport retains a nonzero slot and defined return")
	if result.get("ok",false):check(result.kernel_result.pointer_return_defined and int(result.kernel_result.allocated_slot_s32)==6 and result.context_after.task_variables["2"].decode_u32(4)==0x77889900,"F51 kernel pointer metadata and persistent allocated locals agree")
	before=core()
	for slot in range(150):before.arena.encode_u32(slot*36,1)
	result=Runtime.execute(before,command("events","F51",[0,0],-1,MASK))
	check(result.get("ok",false) and result.return_defined and int(result.return_u32)==MASK and result.context_after==before,"Exhausted source F51 returns null physical pointer without inventing allocation")
	result=Runtime.execute(before,command("tasks","F52",[7,0,0],7,192))
	check(not result.ok and not result.has("context_after"),"F52 null allocation faults atomically instead of becoming packed handle0")
	directed_cases+=4
func lifecycle_and_dispatch()->void:
	var before:=core();before.arena.encode_u32(7*36+8,0)
	var request:=command("tasks","F53",[7],7,MASK);var done:=complete(before,request,f41)
	check(done.result.get("ok",false) and done.observations.size()==1 and done.observations[0].kind=="F41" and int(done.observations[0].ip_before_u32)==128,"F53 closes real conditions and guards around its sole explicit initialization F41 witness")
	if not done.result.get("ok",false):return
	var initialized:Dictionary=done.result.context_after
	check(initialized.arena.decode_u32(7*36)==1 and initialized.arena.decode_u32(7*36+8)==BASE+64 and initialized.root.decode_u32(0x200)==1 and initialized.nodes.size()==1,"Initialization activates its exact block and registers actual guard key through real F44")
	var expected_key:=[2,0,0,Guards.F47_WORD,Guards.TASK_BASE+7*36,0]
	check(initialized.nodes.values()[0].key_u32==expected_key,"Guard registry retains original event2/task/function/clause tuple")
	initialized.event_registers.encode_u32(0,1);done=complete(initialized,command("events","F48",[2,0,0],-1,MASK),f41)
	check(done.result.get("ok",false) and done.observations.size()==1 and int(done.observations[0].ip_before_u32)==165,"Registered event closes actual F47 and actual expression before explicit statement continuation")
	if done.result.get("ok",false):
		check(done.result.context_after.root.decode_u32(0x200)==2 and done.result.context_after.arena.decode_u32(7*36)==1,"F47 temporarily enters2 and restores1 after the witnessed statement")
		check(done.result.source_order.has("F47") and done.result.source_order.has("F31") and done.result.source_order.has("F41") and done.result.source_order.has("F54"),"Event callback, expression, statement and postdispatch scheduler all run")
	var unchecked:=core();unchecked.program.encode_u32(68,0);unchecked.event_registers.encode_u32(0,1)
	done=complete(unchecked,command("tasks","F47",[7,0],7,MASK),f41)
	check(done.result.get("ok",false) and done.observations.size()==1,"Actual DOS F47 reads a clause pointer with declared count0")
	for status:int in [0,1,4,5,6,0x80000000,MASK]:
		var cancel:=core();cancel.arena.encode_u32(7*36,status);cancel.arena.encode_u32(7*36+8,0)
		var result:=Runtime.execute(cancel,command("tasks","F38",[cancel.arena.decode_u32(7*36+4)],7,MASK))
		check(result.get("ok",false) and result.context_after.arena.decode_u32(7*36)==6 and result.context_after.arena.decode_u16(7*36+6)==4,"Actual DOS F38 admits matching packed handles in state %08x"%status)
	var zero:=core();var record:PackedByteArray=zero.arena.slice(7*36,8*36);zero.arena.fill(0);put(zero.arena,0,record);zero.arena.encode_u32(0,0);zero.arena.encode_u32(4,0);zero.arena.encode_u32(8,0)
	var result:=Runtime.execute(zero,command("tasks","F38",[0],0,MASK));check(result.get("ok",false) and result.context_after.arena.decode_u32(0)==6 and result.context_after.arena.decode_u16(6)==1,"Packed zero is a valid matching handle, including inactive state0")
	if result.get("ok",false):
		result=Runtime.execute(result.context_after,command("events","F54",[],-1,MASK));check(result.get("ok",false) and result.context_after.arena.decode_u32(0)==0 and result.context_after.task_variables.is_empty(),"Real scheduler frees variable owner after cancellation")
	var wrap:=core();wrap.arena.encode_u16(7*36+6,65535);wrap.arena.encode_u32(7*36+8,0)
	result=Runtime.execute(wrap,command("tasks","F38",[wrap.arena.decode_u32(7*36+4)],7,MASK));check(result.get("ok",false) and result.context_after.arena.decode_u16(7*36+6)==0,"Cancellation generation increments modulo sixteen bits")
	var cleanup:=core();cleanup.arena.encode_u32(7*36+8,0);cleanup.program.encode_u32(12,0);cleanup.definitions["0"].cleanup_instruction_u32=BASE+128
	result=Runtime.execute(cleanup,command("tasks","F38",[cleanup.arena.decode_u32(7*36+4)],7,MASK))
	check(result.get("ok",false) and result.context_after.arena.decode_u32(7*36)==5,"Descriptor cleanup enters source state5")
	if result.get("ok",false):
		done=complete(result.context_after,command("events","F54",[],-1,MASK),f41)
		check(done.result.get("ok",false) and done.observations.size()==1 and int(done.observations[0].ip_before_u32)==128 and done.result.context_after.task_variables.is_empty() and done.result.context_after.arena.decode_u32(7*36)==0,"Cleanup F41 consumes converted sourceVA then scheduler releases its actual heap allocation")
	var boot:=core();boot.program.encode_u32(8,0);boot.arena.fill(0);boot.task_variables={};boot.next_variable_id_u32=1
	done=complete(boot,command("events","F55",[],-1,MASK),f41)
	check(done.result.get("ok",false) and done.observations.size()==1,"F55 boot callback closes F52→F51 allocation through the bounded mutable heap shim")
	if done.result.get("ok",false):check(done.result.context_after.scratch_words==zeros(32) and done.result.context_after.task_variables.size()==1 and done.result.context_after.next_variable_id_u32==2 and done.result.context_after.arena.decode_u32(0)==1,"Boot persists exactly one allocated/initialized task and zeros scratch words")
	directed_cases+=16
func stores_models_markets()->void:
	var before:=core();put(before.program,224,PackedByteArray([62])+literal(1));var at:=116+338;before.bank.encode_u16(at+0x82,149)
	var result:=Runtime.execute(before,command("store","F37",[0x12345678],7,224))
	check(result.get("ok",false) and result.context_after.bank[at+0xff]==0x78 and int(result.cursor_after_u32)==230 and result.source_order.has("F48"),"Actual DOS selector62 writes lowbyte and dispatches even with null model149")
	before=core();put(before.program,224,PackedByteArray([61])+literal(1));before.bank[at+0x28]=0x73
	var expected:=Models.replace(before.bank.slice(at,at+338),1);result=Runtime.execute(before,command("store","F37",[1],7,224))
	check(expected.get("ok",false) and result.get("ok",false) and result.context_after.bank.slice(at,at+338)==expected.body_after,"F37 selector61 closes actual F36 with complete original model replacement")
	if result.get("ok",false):check(result.source_order.has("F36") and result.context_after.bank.slice(0,at)==before.bank.slice(0,at),"Real F36 touches its selected body and contributes source order")
	before=core();put(before.program,224,PackedByteArray([66])+literal(17)+literal(1002));put(before.program,240,PackedByteArray([66])+literal(29)+literal(1003));put(before.program,256,PackedByteArray([66])+literal(17)+literal(1004))
	var codes:=[[224,0x11112222],[240,0x33334444],[256,0x55556666]];var current:=before.duplicate(true)
	for pair:Array in codes:
		var done:=complete(current,command("store","F37",[pair[1]],7,pair[0]),market)
		check(done.result.get("ok",false) and done.observations.size()==1,"Each market assignment binds its actual F649 owner")
		if done.result.get("ok",false):current=done.result.context_after
	check(current.market_records.size()==2 and current.market_records["17"].decode_u32(20)==0x11112222 and current.market_records["17"].decode_u32(36)==0x55556666 and current.market_records["29"].decode_u32(28)==0x33334444,"Two distinct market records and a later first-market write survive sequential assignments")
	put(current.program,272,PackedByteArray([66])+literal(17)+literal(1002));var read:=complete(current,command("expression","F31",[],7,272),market_read)
	check(read.result.get("ok",false) and int(read.result.return_u32)==0x11112222 and read.result.context_after.market_records==current.market_records,"Expression market snapshot reads exactly the previously persisted market owner")
	if read.result.get("ok",false):
		var wrong:Array=read.observations.duplicate(true);wrong[0].output_hex=zeros(308).hex_encode();check(not Runtime.execute(current,command("expression","F31",[],7,272),wrong).ok,"An expression snapshot that disagrees with the persisted market owner rejects")
	var lookup_before:=core();put(lookup_before.program,224,PackedByteArray([66])+literal(17)+literal(1002));lookup_before.market_records["29"]=zeros(308)
	var lookup:=complete(lookup_before,command("store","F37",[123],7,224),market)
	if lookup.result.get("ok",false):
		var wrong:Array=lookup.observations.duplicate(true);wrong[0].after.market_records["29"][0]=1;check(not Runtime.execute(lookup_before,command("store","F37",[123],7,224),wrong).ok,"F649 lookup cannot alter an existing unrelated market owner")
	before=core();put(before.program,224,PackedByteArray([37])+literal(1)+literal(100));var eq:=complete(before,command("store","F37",[5],7,224),equipment)
	check(eq.result.get("ok",false) and eq.observations.size()==2 and eq.observations[0].kind=="F392" and eq.observations[0].args==[1,0] and eq.observations[1].kind=="F390" and eq.observations[1].args==[1,0],"Equipment caller observes count before add and honors actual nonzero service early stop")
	if eq.result.get("ok",false):check(eq.result.context_after.bank[at+0x40]==0x91,"Explicit equipment world mutation survives all outer projection merges")
	directed_cases+=11
func owner_sequence()->void:
	var before:=core();before.arena.encode_u32(7*36+8,0);var hot:=State.new();var cold:=State.new();check(hot.configure(before) and cold.configure(before),"Independent hot and cold owners configure identical initial context")
	var requests:Array=[command("tasks","F52",[7,0,0xabcdef01],7,192),command("tasks","F53",[0],0,MASK),command("guards","F34",[0,1],0,0),command("tasks","F38",[65536],0,MASK),command("events","F54",[],-1,MASK),command("events","F56",[],-1,MASK)]
	for request:Dictionary in requests:
		var done:=complete(hot.raw_context(),request,f41)
		check(done.result.get("ok",false),"Same-owner multi-step sequence executes "+str(request.operation))
		if not done.result.get("ok",false):break
		var unchanged:=digest(hot.snapshot());var prepared:=hot.prepare(request,done.observations);var other:=cold.prepare(JSON.parse_string(JSON.stringify(request)),JSON.parse_string(JSON.stringify(Scan.json_value(done.observations))))
		check(prepared.get("ok",false) and other.get("ok",false) and digest(hot.snapshot())==unchanged,"Prepare keeps live owners unchanged for "+str(request.operation))
		if not prepared.get("ok",false) or not other.get("ok",false):break
		check(prepared.receipt==other.receipt,"Hot/cold replay receipts are identical for "+str(request.operation))
		check(hot.commit(prepared) and cold.commit(other),"Both independent owners commit verified "+str(request.operation))
		var restored:=State.new();check(restored.restore(JSON.parse_string(JSON.stringify(cold.snapshot()))),"Cold JSON restores same owner after "+str(request.operation));cold=restored
		check(hot.raw_context()==cold.raw_context() and hot.raw_context()==done.result.context_after,"Every persistent owner matches independent hot and cold continuation")
		sequence_steps+=1
	check(sequence_steps==6 and hot.raw_context().task_variables.is_empty() and hot.raw_context().nodes.is_empty(),"Six dependent transitions finish with real heap and event-tree cleanup")
func owner_guards()->void:
	var before:=core();var request:=command("expression","F31",[],7,192);var owner:=State.new();check(owner.configure(before),"Owner configures before transaction guards")
	var prepared:=owner.prepare(request);check(prepared.get("ok",false),"Pure real-expression preparation returns reviewable candidate")
	if not prepared.get("ok",false):return
	var frozen:=digest(owner.snapshot());var outsider:=State.new();outsider.configure(before)
	check(not outsider.commit(prepared),"Prepared candidate cannot commit to another owner")
	var corrupt:=prepared.duplicate();corrupt.receipt=prepared.receipt.duplicate(true);corrupt.receipt.return_u32=999
	check(not owner.commit(corrupt) and digest(owner.snapshot())==frozen,"Altered cursor/return receipt rejects atomically")
	var candidate_snapshot:Dictionary=prepared.candidate_state.snapshot();var changed:=candidate_snapshot.duplicate(true);changed.core.context.root="01"+str(changed.core.context.root).substr(2);changed=signed_snapshot(changed)
	var forged:=State.new();check(not forged.restore(changed),"Rehashed after-state cannot bypass deterministic last-witness replay")
	check(owner.commit(prepared) and not owner.commit(prepared),"A verified preparation commits once and rejects replay")
	var stale:=owner.prepare(request);var saved:=owner.snapshot();check(owner.restore(saved) and not owner.commit(stale),"Restore invalidates stale same-generation preparations through revision guard")
	var aba:=owner.prepare(request);check(owner.configure(before) and not owner.commit(aba),"Reconfigure to an earlier equal context cannot admit ABA candidate")
	frozen=digest(owner.snapshot());var invalid:=before.duplicate(true);invalid.arena.encode_u32(7*36+32,99)
	check(not Runtime.execute(invalid,request).ok and not owner.prepare(command("expression","F31",[],149,192)).ok and digest(owner.snapshot())==frozen,"Invalid/dead projections reject without changing the owned live state")
	var cycle:Dictionary={};cycle["self"]=cycle
	check(Runtime.decode_context(cycle).is_empty() and not Runtime.execute(before,cycle).ok and not owner.restore(cycle),"Cyclic malformed context/command/snapshot reject before deep copy")
	cycle.clear();var rows:Array=[];rows.append(rows)
	check(not Runtime.execute(before,request,rows).ok and not owner.prepare(request,rows).ok,"Cyclic world replies reject before recursive serialization");rows.clear()
	for key:String in Runtime.KEYS:
		var bad:=before.duplicate(true);bad.erase(key);check(Runtime.decode_context(bad).is_empty() and not Runtime.execute(bad,request).ok,"Missing persisted owner rejects: "+key)
	for key:String in Runtime.COMMAND_KEYS:
		var bad:=request.duplicate(true);bad.erase(key);check(not Runtime.execute(before,bad).ok,"Missing invocation field rejects: "+key)
	for bad:Variant in [null,true,0,[],{},zeros(1)]:check(not Runtime.execute(bad,request).ok and not owner.configure(bad),"Malformed Core rejects atomically")
	var world_before:=core();world_before.arena.encode_u32(7*36+8,0);var done:=complete(world_before,command("tasks","F53",[7],7,MASK),f41)
	if done.result.get("ok",false):
		for field:String in ["task_slot_s32","ip_before_u32"]:
			var bad:Array=done.observations.duplicate(true);bad[0][field]=int(bad[0][field])+1;check(not Runtime.execute(world_before,command("tasks","F53",[7],7,MASK),bad).ok,"Wrong task/cursor world frame rejects: "+field)
		var bad:Array=done.observations.duplicate(true);bad[0].after.program[0]^=1;check(not Runtime.execute(world_before,command("tasks","F53",[7],7,MASK),bad).ok,"World service cannot change readonly source bytecode")
		bad=done.observations.duplicate(true);bad[0].after.task_variables.erase("1");check(not Runtime.execute(world_before,command("tasks","F53",[7],7,MASK),bad).ok,"Freeing outer task locals rejects dangling continuation atomically")
		bad=done.observations.duplicate(true);bad.append(bad[0].duplicate(true));check(not Runtime.execute(world_before,command("tasks","F53",[7],7,MASK),bad).ok,"Unused world replies cannot silently pass")
func hostile_world_and_snapshot()->void:
	var before:=core();before.arena.encode_u32(7*36+8,0);var request:=command("tasks","F53",[7],7,MASK)
	var journal:=complete(before,request,registry_world)
	check(journal.result.get("ok",false) and journal.result.context_after.nodes.size()==2,"A witnessed F41 registry action replays actual F44 before actual guard registration")
	if journal.result.get("ok",false):
		var bad:Array=journal.observations.duplicate(true);bad[0].erase("registry_actions");check(not Runtime.execute(before,request,bad).ok,"A world reply cannot claim tree changes without actual registry action replay")
		bad=journal.observations.duplicate(true);bad[0].registry_actions[0].args[0]+=1;check(not Runtime.execute(before,request,bad).ok,"A mismatched registry journal rejects even when raw after-tree is structurally valid")
		bad=journal.observations.duplicate(true);bad[0].after.nodes.values()[0].generation_u32=2;check(not Runtime.execute(before,request,bad).ok,"Forged tree generations cannot cross the world observation codec")
	var heap:=complete(before,request,monotonic_heap_world)
	check(heap.result.get("ok",false) and heap.result.context_after.task_variables.size()==2 and heap.result.context_after.next_variable_id_u32==3,"A bounded new F41 logical allocation survives outer task projection and real registry callbacks")
	if heap.result.get("ok",false):
		var bad:Array=heap.observations.duplicate(true);bad[0].after.next_variable_id_u32=1;check(not Runtime.execute(before,request,bad).ok,"World allocator cannot rewind logical allocation identity")
		bad=heap.observations.duplicate(true);bad[0].after.task_variables["1"]=zeros(20);check(not Runtime.execute(before,request,bad).ok,"World reply cannot resize a live allocation")
		bad=heap.observations.duplicate(true);bad[0].after.definitions["0"].variable_words_u32=5;check(not Runtime.execute(before,request,bad).ok,"World reply cannot rewrite readonly module allocation definitions")
		bad=heap.observations.duplicate(true);bad[0].return_u32=1;check(not Runtime.execute(before,request,bad).ok,"Void F41 cannot expose an invented scalar success return")
		bad=heap.observations.duplicate(true);bad[0].ip_after_u32=513;check(not Runtime.execute(before,request,bad).ok,"F41 continuation cursor must remain within the source program")
	var owner:=State.new();owner.configure(before);var prepared:=owner.prepare(command("expression","F31",[],7,192));var snapshot:Dictionary=prepared.candidate_state.snapshot();var initial:=digest(owner.snapshot())
	var altered:=snapshot.duplicate(true);altered.last_witness.payload.command.ip_u32=197;altered=signed_snapshot(altered)
	# F31 is read-only, so changing its literal cursor may preserve core bytes. The
	# serialized witness remains authoritative for cursor receipts at commit.
	var forged:=State.new();var accepted:=forged.restore(altered)
	check(accepted and forged.raw_context()==before and digest(owner.snapshot())==initial,"A valid alternate read-only witness restores the same raw core while the live owner remains unchanged")
	if accepted:
		var replacement:=prepared.duplicate();replacement.candidate_state=forged;check(not owner.commit(replacement),"A different replayable read-only witness still cannot use another invocation's receipt")
	var invalid:=snapshot.duplicate(true);invalid.generation=100000001;invalid=signed_snapshot(invalid);check(not owner.restore(invalid),"Snapshots reject generation beyond bounded profile")
	invalid=snapshot.duplicate(true);invalid.last_witness.before_generation=-1;invalid=signed_snapshot(invalid);check(not owner.restore(invalid),"Snapshots reject negative witness generation")
	invalid=snapshot.duplicate(true);invalid.snapshot_sha256="0".repeat(64);check(not owner.restore(invalid),"Snapshot integrity rejects unsigned replacement")
	var extra:=request.duplicate(true);extra.persisted_ip=0;check(not Runtime.execute(before,extra).ok,"Invocation codec rejects extra cursor aliases")
	var core_extra:=before.duplicate(true);core_extra.ip_u32=0;check(not Runtime.execute(core_extra,request).ok,"Core codec rejects a duplicated persisted invocation cursor")
	var noncanonical:=before.duplicate(true);noncanonical.market_records={"017":zeros(308)};check(not Runtime._context(noncanonical),"Market identities use canonical unsigned numeric owner keys")
	directed_cases+=18
func buffer(key:String)->PackedByteArray:
	if hydrated.has(key):return hydrated[key].duplicate()
	if not pool.has(key):check(false,"Native buffer reference exists in the independently captured pool");return PackedByteArray()
	var entry:Dictionary=pool[key];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
	check(raw.size()==int(entry.byte_count) and hash.finish().hex_encode()==key,"Native pooled owner bytes have exact size and SHA256")
	hydrated[key]=raw.duplicate();return raw
func hydrate(value:Dictionary)->Dictionary:
	var raw:Dictionary=value.duplicate(true)
	for key:String in Runtime.BYTE_COUNTS:
		if raw[key] is String and pool.has(raw[key]):raw[key]=buffer(raw[key])
	if raw.program is String and pool.has(raw.program):raw.program=buffer(raw.program)
	for field:String in ["task_variables","market_records"]:
		for key:String in raw[field]:
			if raw[field][key] is String and pool.has(raw[field][key]):raw[field][key]=buffer(raw[field][key])
	return Runtime.decode_context(raw)
func native_controls(doc:Dictionary)->void:
	check(doc.schema=="starfrontier-mission-runtime-native-v1" and doc.profile==Runtime.PROFILE,"Native composition schema and bounded runtime profile agree")
	check(not doc.expected_arithmetic_calculated_in_python and int(doc.fresh_process_runs)==3 and int(doc.reverse_repeat_cases)==doc.cases.size(),"Full native contexts come from three fresh original instruction runs and reverse-repeat controls")
	for path:String in doc.get("source_dependencies_sha256",{}):check(FileAccess.get_sha256("res://"+path)==doc.source_dependencies_sha256[path],"Native composition source dependency is current: "+path)
	for path:String in doc.get("proofs_sha256",{}):check(FileAccess.get_sha256("res://"+path)==doc.proofs_sha256[path],"Original whole-procedure composition proof is pinned: "+path)
	var previous:Dictionary={};var chain_hot:RefCounted;var chain_cold:RefCounted
	for row:Dictionary in doc.cases:
		var before:=hydrate(row.context_before);var expected:=hydrate(row.expected.context_after);var replies:Array=[]
		for raw:Dictionary in row.observations:
			var reply:=raw.duplicate(true);reply.before=hydrate(raw.before);reply.after=hydrate(raw.after);replies.append(reply)
		check(not before.is_empty() and not expected.is_empty(),"Native composed eighteen-owner contexts decode: "+str(row.name))
		if before.is_empty() or expected.is_empty():continue
		var frozen:=digest([before,row.command,replies]);var result:=Runtime.execute(before,row.command,replies)
		check(result.get("ok",false),"Original composed native command executes: "+str(row.name)+" / "+str(result.get("reason","ok")))
		if not result.get("ok",false):continue
		for field:String in Runtime.KEYS:check(result.context_after[field]==expected[field],"Native composed owner matches "+field+": "+str(row.name))
		check(int(result.cursor_after_u32)==int(row.expected.cursor_after_u32) and int(result.return_u32)==int(row.expected.return_u32) and bool(result.return_defined)==bool(row.expected.return_defined),"Invocation cursor and scalar/pointer return match native: "+str(row.name))
		check(result.source_order==row.expected.source_order and Clock._hash({"calls":result.dependency_calls})==Clock._hash({"calls":row.expected.dependency_calls}),"All nested original callees and their caller/callee cursors match native: "+str(row.name))
		check(int(result.world_observations_used)==int(row.expected.world_observations_used) and result.world_observations_used==replies.size(),"Native typed world witnesses are consumed exactly: "+str(row.name))
		check(digest([before,row.command,replies])==frozen,"Native command and observed world owners stay private: "+str(row.name))
		if row.get("carries_previous_native_state",false):
			check(not previous.is_empty() and before==previous,"Every persisted native owner crosses the same-state continuation edge")
			check(chain_hot!=null and chain_cold!=null and chain_hot.raw_context()==before and chain_cold.raw_context()==before,"Both independent live and cold owner chains start from the preceding committed native state");native_edges+=1
		else:
			chain_hot=State.new();chain_cold=State.new();check(chain_hot.configure(before) and chain_cold.configure(before),"New native sequence configures independent owned continuations")
		if chain_hot!=null and chain_cold!=null:
			var hot:Dictionary=chain_hot.prepare(row.command,replies);var cold:Dictionary=chain_cold.prepare(JSON.parse_string(JSON.stringify(row.command)),JSON.parse_string(JSON.stringify(Scan.json_value(replies))))
			check(hot.get("ok",false) and cold.get("ok",false),"Native composition also prepares through the replay-verified owner")
			if hot.get("ok",false) and cold.get("ok",false):
				check(hot.receipt==cold.receipt and chain_hot.commit(hot) and chain_cold.commit(cold),"Independent native sequence receipts and commits agree")
				var restored:=State.new();check(restored.restore(JSON.parse_string(JSON.stringify(chain_cold.snapshot()))),"Native transition survives actual cold owner restoration");chain_cold=restored
				check(chain_hot.raw_context()==expected and chain_cold.raw_context()==expected,"Hot and restored native continuations match all eighteen expected owners")
		previous=expected.duplicate(true);native_cases+=1;native_world_calls+=replies.size();native_dependency_calls+=result.dependency_calls.size()
		if before.program.size()==57560 and int(before.program_base_u32)==BASE:
			check(before.definitions.size()==105,"Actual native resource composition binds all105 original DOS module descriptors");native_original_resource_cases+=1
	check(doc.get("native_fault_domains_separate",[]).size()==1,"Native pointer fault is a separate domain without fabricated expected after-state")
	for row:Dictionary in doc.get("native_fault_domains_separate",[]):
		var before:=hydrate(row.context_before);var frozen:=digest(before);var result:=Runtime.execute(before,row.command,row.observations)
		check(not before.is_empty() and row.source_signal=="SIGSEGV" and int(row.actual_native_process_returncode)==-11 and int(row.fresh_native_process_runs)==3 and not row.after_state_claimed and not row.expected_complete_native_context_after_available,"Fault-domain witness is retained from three fresh original SIGSEGV runs")
		check(not result.get("ok",false) and not result.has("context_after") and digest(before)==frozen,"Actual pointer-fault command rejects atomically without inventing normal final owners")
		var owner:=State.new();check(owner.configure(before),"Fault domain still has a valid bounded persisted owner context");var saved:=digest(owner.snapshot())
		check(not owner.prepare(row.command,row.observations).ok and digest(owner.snapshot())==saved,"Replay-verified owner rejects the original fault without committing partial allocation or state")
		native_fault_domains+=1
	check(native_original_resource_cases>=3,"Native composition includes actual original immutable DOS program and descriptor resources")
	check(native_dependency_calls+native_cases==int(doc.native_measurement_count),"Each top-level command and nested original kernel has a distinct retained native measurement")
	check(native_cases==int(doc.case_count) and native_cases==doc.cases.size() and native_cases>=20,"Entire native composition case bank executed")
	check(native_edges>=4,"Independent native contexts include at least four dependent same-owner edges")
func run()->void:
	programs=Programs.load_original();check(Programs.validate(programs),"Original DOS resource graph validates before composition")
	frame_and_resources();dual_cursor_create();allocator_transport();lifecycle_and_dispatch();stores_models_markets();owner_sequence();owner_guards();hostile_world_and_snapshot()
	var doc:Dictionary={}
	if FileAccess.file_exists(FIXTURE):
		doc=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));check(FIXTURE_SHA==FileAccess.get_sha256(FIXTURE),"Native composition fixture SHA is frozen");pool=doc.get("buffer_pool",{});native_controls(doc)
	var sources:Dictionary={}
	for path:String in ["scripts/source_mission_runtime.gd","scripts/source_mission_runtime_state.gd","scripts/source_mission_runtime_state.gd.uid","scripts/source_mission_expression.gd","scripts/source_mission_store.gd","scripts/source_mission_task.gd","scripts/source_mission_guards.gd","scripts/source_events.gd","scripts/source_mission_models.gd","scripts/source_mission_programs.gd","tests/test_source_mission_runtime.gd","tests/test_source_mission_runtime.gd.uid"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if not doc.is_empty():
		sources[FIXTURE.trim_prefix("res://")]=FileAccess.get_sha256(FIXTURE)
		for group:String in ["source_dependencies_sha256","proofs_sha256"]:
			for path:String in doc.get(group,{}):sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Runtime.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"native_fixture_pending":doc.is_empty(),"native_continuation_edges":native_edges,"native_world_calls":native_world_calls,"native_dependency_calls":native_dependency_calls,"native_original_resource_cases":native_original_resource_cases,"native_fault_domains":native_fault_domains,"native_measurement_count":int(doc.get("native_measurement_count",0)),"directed_cases":directed_cases,"same_owner_sequence_steps":sequence_steps,"sources":sources,"Main_integrated":false,"full_mission_VM_executed":false},"\t")+"\n");file.close()
	print("SOURCE MISSION RUNTIME TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
