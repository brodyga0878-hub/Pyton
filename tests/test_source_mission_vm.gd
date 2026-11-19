extends SceneTree
const VM=preload("res://scripts/source_mission_vm.gd")
const State=preload("res://scripts/source_mission_vm_state.gd")
const Runtime=preload("res://scripts/source_mission_runtime.gd")
const Programs=preload("res://scripts/source_mission_programs.gd")
const Events=preload("res://scripts/source_events.gd")
const Guards=preload("res://scripts/source_mission_guards.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const REPORT:="res://build/current-test-reports/source-mission-vm.json"
const FIXTURE:="res://tests/fixtures/source_mission_vm_native.json"
const FIXTURE_SHA:="5af70919e7bb15e6e9539f16b549efc143952e89f067506f77f3538fb2a1edd6"
const BASE:=0x4801c4
const MASK:=0xffffffff
var checks:=0
var failures:=0
var programs:Dictionary={}
var directed_cases:=0
var native_cases:=0
var native_edges:=0
var native_dependencies:=0
var native_world_calls:=0
var native_frames:=0
var native_original_resource_cases:=0
var native_doc:Dictionary={}
var pool:Dictionary={}
var hydrated:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<30:push_error(message)
func bytes(count:int,fill:int=0)->PackedByteArray:
	var result:=PackedByteArray();result.resize(count);result.fill(fill);return result
func literal(value:int,opcode:int=2)->PackedByteArray:
	var result:=bytes(5);result[0]=opcode;result.encode_u32(1,value&MASK);return result
func put(program:PackedByteArray,at:int,value:PackedByteArray)->void:
	for index in range(value.size()):program[at+index]=value[index]
func scratch_seed(fill:int=0xa7,defined:int=0)->Dictionary:return {"seed_hex":bytes(156,fill).hex_encode(),"defined_hex":bytes(156,defined).hex_encode()}
func command(kind:String="statements",operation:String="F41",args:Array=[],slot:int=7,ip:int=128,frames:Array=[{}])->Dictionary:
	return {"kind":kind,"operation":operation,"args":args,"task_slot_s32":slot,"ip_u32":ip,"statement_frames":[scratch_seed()] if frames==[{}] else frames.duplicate(true)}
func core()->Dictionary:
	var program:=bytes(512);program.encode_u32(0,BASE+96);program.encode_u32(8,0);program.encode_u32(12,MASK);program.encode_u32(16,4);program.encode_u32(20,0x60bde0);program.encode_u32(28,BASE+64);program.encode_u32(32,BASE+80)
	program.encode_u32(64,BASE+128);program.encode_u32(68,1);program.encode_u32(72,BASE+160);program.encode_u32(80,BASE+192);program.encode_u32(84,0)
	put(program,160,literal(0,4));put(program,96,literal(2,6))
	var root:=bytes(16384);root.encode_u32(0xc8,454);root.encode_u32(0xcc,792)
	var tail:=bytes(6160);tail.encode_u32(0x180c,1)
	var arena:=bytes(5400);var at:=7*36;arena.encode_u32(at,1);arena.encode_u32(at+4,0x30007);arena.encode_u32(at+8,BASE+64);arena.encode_u32(at+12,0);arena.encode_u32(at+16,BASE+64);arena.encode_u32(at+20,0);arena.encode_u32(at+28,BASE);arena.encode_u32(at+32,1)
	var variables:=bytes(16);variables.encode_u32(0,0x30007);variables.encode_u32(4,0x10203040)
	return {"root":root,"root_tail":tail,"bank":bytes(38986),"event_registers":bytes(284),"module_globals":Programs.initial_module_globals(programs),"program":program,"program_base_u32":BASE,"metadata":Programs.read(programs,"expression_metadata",0,1088),"temporary_event_index_s32":-7,"scratch_words":bytes(32,0xa5),"arena":arena,"tree_root_u32":0,"nodes":{},"next_node_id_u32":1,"task_variables":{"1":variables},"next_variable_id_u32":2,"definitions":{"0":{"descriptor_ref_u32":BASE,"cleanup_instruction_u32":0,"variable_words_u32":4}},"market_records":{},"vectors":Programs.read(programs,"vectors",0,324),"text_buffer":bytes(256),"text_cursor_u32":0}
func complete(before:Dictionary,request:Dictionary,policy:Callable=Callable())->Dictionary:
	var rows:Array=[]
	for step in range(256):
		var result:=VM.execute(before,request,rows)
		if result.get("ok",false) or not result.get("pending") is Dictionary:return {"result":result,"observations":rows}
		var pending:Dictionary=result.pending
		var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"task_slot_s32":int(pending.task_slot_s32),"ip_before_u32":int(pending.ip_before_u32),"ip_after_u32":int(pending.ip_before_u32),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0,"input_hex":pending.input_hex,"output_hex":"","input_defined_hex":pending.input_defined_hex,"output_defined_hex":""}
		if policy.is_valid():policy.call(row,step)
		rows.append(row)
	return {"result":{"ok":false,"reason":"test_world_limit"},"observations":rows}
func increment_root(row:Dictionary,_step:int)->void:row.after.root.encode_u32(0x200,row.after.root.decode_u32(0x200)+1)
func free_selected(row:Dictionary,_step:int)->void:
	if row.kind=="F106":row.after.task_variables.erase(str(row.after.arena.decode_u32(7*36+32)));row.return_u32=11
func retarget_selected(row:Dictionary,_step:int)->void:
	if row.kind!="F106":return
	var replacement:=bytes(32);replacement.encode_u32(3*4,41);row.after.task_variables["2"]=replacement;row.after.next_variable_id_u32=3;row.after.arena.encode_u32(7*36+32,2);row.return_u32=1
func retarget_global(row:Dictionary,_step:int)->void:
	if row.kind!="F106":return
	row.after.arena.encode_u32(7*36+28,BASE+240);row.after.module_globals.encode_u32(4,41);row.return_u32=1
func formatter(row:Dictionary,step:int)->void:
	if row.kind!="F1344":return
	var start:=int(row.args[1]);var text:PackedByteArray=("OK" if step==0 else "Z").to_ascii_buffer();text.append(0)
	for index in range(text.size()):row.after.text_buffer[start+index]=text[index]
	row.return_u32=start+text.size()
func packet_writer(row:Dictionary,_step:int)->void:
	if row.kind!="F345":return
	var packet:PackedByteArray=str(row.input_hex).hex_decode();var defined:PackedByteArray=str(row.input_defined_hex).hex_decode();packet.encode_u32(44,0x77889900)
	for index in range(4):defined[44+index]=1
	row.output_hex=packet.hex_encode();row.output_defined_hex=defined.hex_encode()
func expression_buffer(row:Dictionary,_step:int)->void:
	if row.kind!="F870":return
	var output:=bytes(16);output.encode_u32(4,0x55667788);row.output_hex=output.hex_encode();row.output_defined_hex="01".repeat(16)
func basic_and_scratch_seed()->void:
	var before:=core();var original:=Clock._hash(Scan.json_value(before));check(VM._context(before) and before.size()==21,"Exactly twenty-one persistent VM owner fields")
	check(VM.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(before))))==before,"Core21 cold codec preserves shared owners")
	var result:=VM.execute(before,command());check(result.get("ok",false),"An actual stop statement needs no world callback")
	if result.get("ok",false):
		check(result.cursor_after_u32==129 and result.source_order==["F41"] and result.statement_frames_used==1,"F41 uses one explicit private frame and advances only its cursor")
		check(result.context_after==before and result.statement_frames_after[0].scratch_after_hex==scratch_seed().seed_hex and result.statement_frames_after[0].scratch_defined_hex==scratch_seed().defined_hex,"Untouched private scratch is preserved without claiming defined source values")
	check(Clock._hash(Scan.json_value(before))==original,"Pure VM execution preserves caller-owned buffers")
	check(not VM.execute(before,command("statements","F41",[],7,128,[])).ok,"F41 refuses an omitted invocation seed")
	check(not VM.execute(before,command("statements","F41",[],7,128,[scratch_seed(),scratch_seed()])).ok,"Unused private frame seeds are rejected")
	var bad:=command();bad.statement_frames[0].defined_hex="02".repeat(156);check(not VM.execute(before,bad).ok,"Definedness bytes are exact00/01")
	bad=command();bad.erase("statement_frames");check(not VM.execute(before,bad).ok,"Explicit command frame field cannot silently default")
	before.program[128]=255;before.program[129]=61;var nop:=VM.execute(before,command());check(nop.get("ok",false) and nop.cursor_after_u32==131,"Actual out-of-table opcodes consume one byte and continue")
	directed_cases+=6
func assignments_and_lifetime()->void:
	var before:=core();put(before.program,128,PackedByteArray([7])+literal(42)+literal(2,6)+PackedByteArray([0]));var result:=VM.execute(before,command())
	check(result.get("ok",false),"F41 assignment closes real F31/F37/F48 without observations: "+str(result.get("reason","")))
	if result.get("ok",false):check(result.context_after.task_variables["1"].decode_u32(8)==42 and result.source_order.has("F48"),"Actual local store publishes its source event and scheduler")
	before=core();put(before.program,128,PackedByteArray([7,45])+literal(9)+literal(2,4)+PackedByteArray([0]));var done:=complete(before,command(),free_selected)
	check(done.result.get("ok",false),"Selected heap may be freed after its final real read: "+str(done.result.get("reason","")))
	if done.result.get("ok",false):check(done.observations.size()==1 and done.observations[0].kind=="F106" and done.result.context_after.task_variables.is_empty() and done.result.context_after.event_registers.decode_u32(8)==11,"Retired projection bytes are not reinserted while later register assignment succeeds")
	before=core();put(before.program,128,PackedByteArray([7,13,45])+literal(9)+literal(0,6)+literal(2,4)+PackedByteArray([0]));done=complete(before,command(),free_selected)
	check(not done.result.get("ok",false) and not done.result.has("context_after") and str(done.result.reason).contains("dangling_selected_task_variable_read"),"A subsequent actual freed-variable read rejects the bounded owner profile atomically")
	before=core();put(before.program,128,PackedByteArray([7,13,45])+literal(9)+literal(3,6)+literal(2,4)+PackedByteArray([0]));done=complete(before,command(),retarget_selected)
	check(done.result.get("ok",false),"Recursive F31 rereads a resized replacement selected allocation: "+str(done.result.get("reason","")))
	if done.result.get("ok",false):check(done.result.context_after.event_registers.decode_u32(8)==42 and done.result.context_after.task_variables["2"].size()==32 and done.result.context_after.task_variables["1"]==before.task_variables["1"],"Retargeting uses current task+32 without overwriting the retired allocation")
	before=core();before.program.encode_u32(240+20,0x60bde4);put(before.program,128,PackedByteArray([7,13,45])+literal(9)+literal(0,5)+literal(2,4)+PackedByteArray([0]));done=complete(before,command(),retarget_global)
	check(done.result.get("ok",false),"Recursive F31 rereads task+28 before a module-global dereference: "+str(done.result.get("reason","")))
	if done.result.get("ok",false):check(done.result.context_after.event_registers.decode_u32(8)==42,"Retargeted descriptor selects its real updated global base")
	directed_cases+=5
func projection_boundaries()->void:
	var before:=core();before.program.encode_u32(20,0x60bde1);put(before.program,128,literal(42));var result:=VM.execute(before,command("expression","F31",[],7,128,[]))
	check(result.get("ok",false) and result.return_u32==42,"An unused unrepresentable global projection does not poison a literal expression")
	put(before.program,128,literal(0,5));result=VM.execute(before,command("expression","F31",[],7,128,[]));check(not result.get("ok",false) and str(result.reason).contains("invalid_selected_module_global_read"),"An actual unrepresentable global read rejects the bounded transport without engine errors")
	before=core();before.task_variables.clear();put(before.program,128,literal(2,6));result=VM.execute(before,command("store","F37",[9],7,128,[]));check(not result.get("ok",false) and str(result.reason).contains("dangling_selected_task_variable_write"),"An actual selected-local store requires a current owned allocation")
	before=core();put(before.program,128,PackedByteArray([67])+literal(1));var request:=command("expression","F31",[],7,128,[]);var done:=complete(before,request,expression_buffer)
	check(done.result.get("ok",false) and done.result.return_u32==0x55667788,"An existing expression output packet accepts fully observed bytes")
	var unknown:Array=done.observations.duplicate(true)
	if not unknown.is_empty():unknown[0].output_defined_hex="00"+"01".repeat(15);check(not VM.execute(before,request,unknown).ok,"Conservative expression output transport refuses an unknown buffer byte")
	directed_cases+=5
func text_and_packet_provenance()->void:
	var before:=core();put(before.program,128,PackedByteArray([35])+literal(70)+PackedByteArray([36])+literal(71)+literal(42)+PackedByteArray([0]));var done:=complete(before,command(),formatter)
	check(done.result.get("ok",false),"Both F41 text append opcodes use typed formatter observations")
	if done.result.get("ok",false):
		check(done.observations.size()==2 and done.observations[0].args==[0,0,70] and done.observations[1].args==[0,2,71],"Text cursor keeps formatter returned end minus one")
		check(done.observations[0].input_defined_hex=="00".repeat(20) and done.observations[1].input_defined_hex=="01".repeat(4)+"00".repeat(16),"Only explicitly written formatter parameters become defined")
		check(done.result.context_after.text_cursor_u32==3 and done.result.context_after.text_buffer.slice(0,4)==PackedByteArray([79,75,90,0]),"Subsequent append overwrites the prior NUL in the same text owner")
	before=core();put(before.program,128,PackedByteArray([23])+literal(5)+PackedByteArray([24])+literal(6)+PackedByteArray([0]));done=complete(before,command(),packet_writer)
	check(done.result.get("ok",false),"UI packet callbacks retain private scratch data and byte definedness")
	if done.result.get("ok",false):
		check(done.observations[0].input_defined_hex=="01".repeat(4)+"00".repeat(44),"One UI argument defines exactly four packet bytes")
		check(done.observations[1].input_hex.hex_decode().decode_u32(44)==0x77889900 and done.observations[1].input_defined_hex.right(8)=="01".repeat(4),"A later statement sees the earlier callback's private packet writes")
	var rejected:Array=done.observations.duplicate(true)
	if not rejected.is_empty():rejected[0].input_defined_hex="01".repeat(48);check(not VM.execute(before,command(),rejected).ok,"A fabricated known-input mask cannot match original scratch provenance")
	directed_cases+=3
func nested_frames()->void:
	var before:=core();put(before.program,128,PackedByteArray([7])+literal(9)+literal(2,6)+PackedByteArray([0]));before.event_registers.encode_u32(0,1);put(before.program,165,PackedByteArray([18])+literal(3)+PackedByteArray([0]))
	for index in range(36):before.arena[8*36+index]=before.arena[7*36+index]
	before.arena.encode_u32(8*36+4,0x10008);before.arena.encode_u32(8*36+32,2);before.task_variables["2"]=bytes(16);before.next_variable_id_u32=3
	var key:=[4,Guards.TASK_BASE+7*36,2,Guards.F47_WORD,Guards.TASK_BASE+8*36,0]
	var registered:=VM.execute(before,command("events","F44",key,-1,MASK,[]));check(registered.get("ok",false),"Shared F44 registers a real task condition for recursive entry")
	if not registered.get("ok",false):return
	before=registered.context_after;var request:=command("statements","F41",[],7,128,[scratch_seed(0x11),scratch_seed(0x22)]);var done:=complete(before,request,increment_root)
	check(done.result.get("ok",false),"Actual event dispatch closes F47/F31 and recursively enters F41: "+str(done.result.get("reason","")))
	if done.result.get("ok",false):
		check(done.result.statement_frames_used==2 and done.result.context_after.root.decode_u32(0x200)==1 and done.observations.size()==1 and done.observations[0].kind=="F105","Recursive F41 consumes a separate supplied seed and only its real world service")
		check(done.result.context_after.arena.decode_u32(8*36)==1 and done.result.context_after.task_variables["1"].decode_u32(8)==9,"F47 restores state1 after inner F41 while preserving outer local assignment")
		check(done.result.source_order.count("F41")==2 and done.result.source_order.has("F47"),"Expanded source order contains both actual statement frames")
	check(not VM.execute(before,command("statements","F41",[],7,128,[scratch_seed()])).ok,"An unsupplied recursive frame never acquires an invented zero seed")
	directed_cases+=2
func lifecycle_and_spawn()->void:
	var before:=core();before.program.encode_u32(64,BASE+192);var code:=PackedByteArray([1]);var immediate:=bytes(4);immediate.encode_u32(0,0);code.append_array(immediate);code.append_array(literal(10,4));code.append(0);put(before.program,128,code)
	var result:=VM.execute(before,command());check(result.get("ok",false),"F41 creates a real child task through F52/F51 and stores the packed handle")
	if result.get("ok",false):
		check(result.context_after.event_registers.decode_u32(40)==0x10000 and result.context_after.task_variables["2"].decode_u32(0)==0x10000 and result.context_after.task_variables["2"].decode_u32(4)==0x30007,"Created task owns the allocator header and original caller packed-handle parameter")
		var scheduled:=VM.execute(result.context_after,command("events","F54",[],-1,MASK,[scratch_seed(0x33)]));check(scheduled.get("ok",false),"Actual F54/F53 initializes the child through real F41")
		if scheduled.get("ok",false):check(scheduled.context_after.arena.decode_u32(0)==1 and scheduled.context_after.nodes.size()==1 and scheduled.statement_frames_after[0].task_slot_u32==0,"Child initialization registers original conditions and keeps a distinct physical frame")
	before=core();before.program.encode_u32(12,0);before.definitions["0"].cleanup_instruction_u32=BASE+192;put(before.program,128,PackedByteArray([8])+literal(0x30007)+PackedByteArray([18])+literal(5)+PackedByteArray([0]));result=VM.execute(before,command())
	check(result.get("ok",false),"Self cancellation with a cleanup block halts through unchanged packed handle")
	if result.get("ok",false):
		check(result.cursor_after_u32==134 and result.context_after.arena.decode_u32(7*36)==5,"F38 self halt skips later world statements and preserves cleanup state5")
		var cleaned:=VM.execute(result.context_after,command("events","F54",[],-1,MASK,[scratch_seed(0x44)]));check(cleaned.get("ok",false),"F54 executes actual cleanup F41 before releasing locals")
		if cleaned.get("ok",false):check(cleaned.context_after.arena.decode_u32(7*36)==0 and cleaned.context_after.task_variables.is_empty() and cleaned.context_after.arena.decode_u32(7*36+32)==1,"Cleanup frees the owner once and leaves the original stale scalar task field")
	before=core();put(before.program,128,PackedByteArray([8])+literal(0x30007)+PackedByteArray([18])+literal(5)+PackedByteArray([0]));var done:=complete(before,command(),increment_root)
	check(done.result.get("ok",false),"No-cleanup self cancellation compares the generation after F38")
	if done.result.get("ok",false):check(done.observations.size()==1 and done.observations[0].kind=="F105" and done.result.context_after.arena.decode_u32(7*36+4)==0x40007,"Changed generation allows the following real statement to continue")
	before=core();code=PackedByteArray([50])
	for value:int in [7,1,11,12,13,14,15,16,17]:code.append_array(literal(value))
	code.append_array(literal(11,4));code.append(0);put(before.program,128,code);done=complete(before,command())
	check(done.result.get("ok",false),"F41 closes the complete nine-argument F40 caller through the actual spawn kernel")
	if done.result.get("ok",false):check(done.observations.size()==1 and done.observations[0].kind=="F927" and done.observations[0].args==[1,454,29,7] and done.result.context_after.event_registers.decode_u32(44)==0 and done.result.source_order.has("F40"),"A genuine null allocator result writes zero without treating F40 as a generic world success")
	directed_cases+=5
func cold_and_atomic()->void:
	var before:=core();put(before.program,128,PackedByteArray([7])+literal(77)+literal(2,4)+PackedByteArray([0]));var owner:=State.new();check(owner.configure(before),"Owned VM accepts Core21")
	var prior:=owner.snapshot();var prepared:=owner.prepare(command());check(prepared.get("ok",false),"Prepare executes real F41 privately: "+str(prepared.get("reason","")))
	check(owner.snapshot()==prior,"Prepare does not mutate live state")
	if not prepared.get("ok",false):return
	check(owner.commit(prepared) and owner.generation()==1 and owner.raw_context().event_registers.decode_u32(8)==77,"Commit publishes the replayed complete VM transaction exactly once")
	check(not owner.commit(prepared),"Stale prepared VM transaction cannot commit twice")
	var cold:=State.new();var snapshot:Dictionary=JSON.parse_string(JSON.stringify(owner.snapshot()));check(cold.restore(snapshot) and cold.raw_context()==owner.raw_context(),"Cold owner restore reproduces its full last statement execution")
	var corrupted:=snapshot.duplicate(true);corrupted.last_witness.payload.command.ip_u32=129;corrupted.erase("snapshot_sha256");corrupted["snapshot_sha256"]=Clock._hash(corrupted)
	check(not cold.restore(corrupted),"A re-signed changed statement execution fails cold replay")
	var text_before:=core();put(text_before.program,128,PackedByteArray([35])+literal(70)+PackedByteArray([0]));var text_request:=command();var done:=complete(text_before,text_request,formatter);var text_owner:=State.new();check(text_owner.configure(text_before),"Cold mask witness configures")
	var text_prepared:=text_owner.prepare(text_request,done.observations);check(text_prepared.get("ok",false) and text_owner.commit(text_prepared),"Actual formatter observation commits with its private input mask")
	corrupted=text_owner.snapshot();corrupted.last_witness.payload.command.statement_frames[0].defined_hex="01".repeat(156);corrupted.erase("snapshot_sha256");corrupted["snapshot_sha256"]=Clock._hash(corrupted)
	check(not cold.restore(corrupted),"Re-signed fabricated observed scratch definedness fails exact cold replay")
	var other:=State.new();check(other.configure(before) and not other.commit(owner.prepare(command())),"Prepared VM transaction is bound to its owning instance")
	var cyclic:Dictionary={};cyclic["cycle"]=cyclic;check(not VM.execute(before,cyclic).ok,"Cyclic malformed commands reject before deep-copy")
	directed_cases+=3
func buffer(key:String)->PackedByteArray:
	if hydrated.has(key):return hydrated[key].duplicate()
	if not pool.has(key):check(false,"Native buffer pool reference exists");return PackedByteArray()
	var entry:Dictionary=pool[key];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	check(raw.size()==int(entry.byte_count) and VM._hash(raw)==key,"Every native pooled byte owner has its exact size and SHA256")
	hydrated[key]=raw.duplicate();return raw
func pooled(value:Variant)->Variant:
	if value is Dictionary and value.keys()==["buffer_sha256"]:return buffer(str(value.buffer_sha256))
	if value is String and pool.has(value):return buffer(value)
	return value
func hydrate(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true)
	for key:String in Runtime.BYTE_COUNTS.keys()+["program","text_buffer","vectors"]:result[key]=pooled(result[key])
	for field:String in ["task_variables","market_records"]:
		for key:String in result[field]:result[field][key]=pooled(result[field][key])
	return VM.decode_context(result)
func native_controls()->void:
	if not FileAccess.file_exists(FIXTURE):check(false,"Independent complete native VM fixture is required");return
	native_doc=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));pool=native_doc.get("buffer_pool",{})
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Native composed VM fixture has its frozen SHA256")
	check(native_doc.schema=="starfrontier-mission-vm-native-v1" and native_doc.profile==VM.PROFILE,"Independent native VM schema and profile agree")
	check(not native_doc.expected_arithmetic_calculated_in_python and int(native_doc.fresh_process_runs)==3 and int(native_doc.reverse_repeat_cases)==native_doc.cases.size(),"Expected complete owners come from three fresh actual native runs and reverse-repeat measurements")
	check(native_doc.native_F41_is_closed and int(native_doc.F41_world_callbacks)==0,"No native composition replaces F41 with an authored world success")
	for group:String in ["source_dependencies_sha256","proofs_sha256"]:
		for path:String in native_doc[group]:check(FileAccess.get_sha256("res://"+path)==native_doc[group][path],"Native VM source/proof dependency is current: "+path)
	var previous:Dictionary={};var hot:RefCounted;var cold:RefCounted
	for row:Dictionary in native_doc.cases:
		var before:=hydrate(row.context_before);var expected:=hydrate(row.expected.context_after);var replies:Array=[]
		for raw:Dictionary in row.observations:
			var reply:=raw.duplicate(true);reply.before=hydrate(raw.before);reply.after=hydrate(raw.after);replies.append(reply)
		check(not before.is_empty() and not expected.is_empty(),"Native Core21 projections decode: "+str(row.name))
		if before.is_empty() or expected.is_empty():continue
		var saved:=Clock._hash({"before":Scan.json_value(before),"command":row.command,"observations":Scan.json_value(replies)});var result:=VM.execute(before,row.command,replies)
		check(result.get("ok",false),"Actual native composed VM command executes: "+str(row.name)+" / "+str(result.get("reason","ok")))
		if not result.get("ok",false):continue
		for key:String in Runtime.KEYS+VM.EXTRA_KEYS:check(result.context_after[key]==expected[key],"Complete native owner agrees for "+key+": "+str(row.name))
		check(int(result.cursor_after_u32)==int(row.expected.cursor_after_u32) and int(result.return_u32)==int(row.expected.return_u32) and bool(result.return_defined)==bool(row.expected.return_defined),"Native private cursor and real return agree: "+str(row.name))
		check(result.source_order==row.expected.source_order,"Every actual source callee occurs in native order: "+str(row.name))
		check(Clock._hash({"calls":result.dependency_calls})==Clock._hash({"calls":row.expected.dependency_calls}),"All recursive frames, cursors and dependency returns match native: "+str(row.name))
		check(int(result.world_observations_used)==replies.size() and int(result.world_observations_used)==int(row.expected.world_observations_used),"Every native world packet is consumed exactly once: "+str(row.name))
		check(int(result.statement_frames_used)==int(row.expected.statement_frames_used) and Clock._hash({"frames":result.statement_frames_after})==Clock._hash({"frames":row.expected.statement_frames_after}),"All native scratch bytes and known/unknown masks match per original frame: "+str(row.name))
		check(Clock._hash({"before":Scan.json_value(before),"command":row.command,"observations":Scan.json_value(replies)})==saved,"Native immutable caller inputs stay private: "+str(row.name))
		if row.get("carries_previous_native_state",false):
			check(before==previous and hot!=null and cold!=null and hot.raw_context()==before and cold.raw_context()==before,"Both independent hot/cold owners continue the preceding complete native state");native_edges+=1
		else:
			hot=State.new();cold=State.new();check(hot.configure(before) and cold.configure(before),"Independent hot/cold native VM owners configure")
		if hot!=null and cold!=null:
			var prepared:Dictionary=hot.prepare(row.command,replies);var other:Dictionary=cold.prepare(JSON.parse_string(JSON.stringify(row.command)),JSON.parse_string(JSON.stringify(Scan.json_value(replies))))
			check(prepared.get("ok",false) and other.get("ok",false),"Native VM execution prepares in both live and JSON-restored form")
			if prepared.get("ok",false) and other.get("ok",false):
				check(prepared.receipt==other.receipt and hot.commit(prepared) and cold.commit(other),"Replay-verified native VM transaction receipts and commits agree")
				var restored:=State.new();check(restored.restore(JSON.parse_string(JSON.stringify(cold.snapshot()))),"Every native VM transition restores by actual cold replay");cold=restored
				check(hot.raw_context()==expected and cold.raw_context()==expected,"Hot and independently restored owners match all twenty-one native owners")
		previous=expected;native_cases+=1;native_dependencies+=result.dependency_calls.size();native_world_calls+=replies.size();native_frames+=int(result.statement_frames_used)
		if before.program.size()==57560 and int(before.program_base_u32)==BASE:
			check(before.definitions.size()==105,"Actual complete native program binds all105 original DOS module definitions");native_original_resource_cases+=1
	check(native_cases==int(native_doc.case_count) and native_cases==native_doc.cases.size(),"Entire independently measured native VM bank executes")
	check(native_cases+native_dependencies==int(native_doc.native_measurement_count),"Each top-level and nested real kernel has its own retained native measurement")
	check(native_edges==int(native_doc.consecutive_shared_state_edges) and native_frames==int(native_doc.statement_invocations),"All dependent native state edges and actual statement frames are preserved")
	check(native_original_resource_cases>0,"Native composition includes the actual unchanged complete mission image")
func report()->void:
	var sources:Dictionary={}
	for path:String in ["scripts/source_mission_vm.gd","scripts/source_mission_vm_state.gd","scripts/source_mission_statements.gd","scripts/source_mission_spawn.gd","scripts/source_mission_runtime.gd","scripts/source_mission_expression.gd","scripts/source_mission_store.gd","scripts/source_mission_task.gd","scripts/source_events.gd","data/ffe_mission_programs.json","tests/test_source_mission_vm.gd"]:sources[path]=VM._hash(FileAccess.get_file_as_bytes("res://"+path))
	for path:String in ["scripts/source_mission_vm.gd.uid","scripts/source_mission_vm_state.gd.uid","tests/test_source_mission_vm.gd.uid"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if not native_doc.is_empty():
		sources[FIXTURE.trim_prefix("res://")]=FileAccess.get_sha256(FIXTURE)
		for group:String in ["source_dependencies_sha256","proofs_sha256"]:
			for path:String in native_doc[group]:sources[path]=FileAccess.get_sha256("res://"+path)
	var result:Dictionary={"checks":checks,"failures":failures,"directed_cases":directed_cases,"native_cases":native_cases,"native_dependencies":native_dependencies,"native_measurements":native_cases+native_dependencies,"native_world_calls":native_world_calls,"native_statement_frames":native_frames,"native_continuation_edges":native_edges,"native_original_resource_cases":native_original_resource_cases,"sources":sources};DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n")
func run()->void:
	programs=Programs.load_original();check(not programs.is_empty(),"Pinned actual mission resources load")
	if not programs.is_empty():basic_and_scratch_seed();assignments_and_lifetime();projection_boundaries();text_and_packet_provenance();nested_frames();lifecycle_and_spawn();cold_and_atomic();native_controls()
	report();print("%d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
