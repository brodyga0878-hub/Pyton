extends SceneTree
const Kernel=preload("res://scripts/source_mission_statements.gd")
const Programs=preload("res://scripts/source_mission_programs.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const FIXTURE:="res://tests/fixtures/source_mission_statements_native.json"
const FIXTURE_SHA:="63c8c29aa3a5d606964321ed8ed32bf141a054bf96945aaf7c1698a7e0d88ab0"
const PROOF:="res://validation/mission-statements-2026-11-19/statements-native-proof/"
const REPORT:="res://build/current-test-reports/source-mission-statements.json"
const BASE:=0x4801c4
var checks:=0
var failures:=0
var native_cases:=0
var provider_calls:=0
var resources:Dictionary={}
var pool:Dictionary={}
var hydrated:Dictionary={}
var native_fault_domains:=0
var original_resource_cases:=0
var covered_selectors:Dictionary={}
var native_whole_procedures:=0
var native_whole_instructions:=0
var native_state_edges:=0
var native_frame_edges:=0
var native_bounded_nontermination:=0
var native_transport_rejections:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<30:push_error(message)
func bytes(count:int,fill:int=0)->PackedByteArray:
	var value:=PackedByteArray();value.resize(count);value.fill(fill);return value
func word(value:int)->PackedByteArray:
	var value_bytes:=bytes(4);value_bytes.encode_u32(0,value&0xffffffff);return value_bytes
func literal(value:int)->PackedByteArray:return PackedByteArray([2])+word(value)
func program(opcode:int,values:Array=[],assign:bool=false)->PackedByteArray:
	var result:=PackedByteArray([opcode])
	for value:int in values:result.append_array(literal(value))
	if assign:result.append_array(PackedByteArray([6])+word(2))
	result.append(0);return result
func context(code:PackedByteArray=PackedByteArray([0]))->Dictionary:
	var tail:=bytes(6160);tail.encode_u32(0x180c,1);var task:=bytes(36);task.encode_u32(0,1);task.encode_u16(4,7);task.encode_u16(6,3);task.encode_u32(28,BASE)
	var root:=bytes(16384);root.encode_u32(0xc8,116+338);root.encode_u32(0xcc,116+676);root.encode_u32(0x10a,0x12345678)
	var bank:=bytes(38986);bank[116+338+0x86]=1;bank[116+676+0x86]=2
	return {"root":root,"root_tail":tail,"bank":bank,"program":code.duplicate(),"program_base_u32":BASE,"ip_u32":0,"task_record":task,"task_slot_u32":7,"vectors":Programs.read(resources,"vectors",0,324),"text_buffer":bytes(256,0x5a),"text_cursor_u32":7}
func scratch()->Dictionary:
	var seed:=bytes(156)
	for index in range(156):seed[index]=(index*73+29)&255
	return {"seed_hex":seed.hex_encode(),"defined_hex":"00".repeat(156)}
func digest(value:Variant)->String:return var_to_bytes(value).hex_encode().sha256_text()
func reply(pending:Dictionary)->Dictionary:return {"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0,"input_hex":pending.input_hex,"input_defined_hex":pending.input_defined_hex,"output_hex":"","output_defined_hex":""}
func complete(before:Dictionary,seed:Dictionary,policy:Callable=Callable())->Dictionary:
	var rows:Array=[]
	for step in range(256):
		var result:=Kernel.execute(before,rows,seed)
		if result.get("ok",false) or not result.get("pending") is Dictionary:return {"result":result,"observations":rows}
		var row:=reply(result.pending)
		if row.kind=="F31":
			var at:=int(row.before.ip_u32)
			if at+5<=row.before.program.size():row.return_u32=row.before.program.decode_u32(at+1);row.after.ip_u32=at+5
		elif row.kind=="F37":row.after.ip_u32=int(row.before.ip_u32)+5;row.after.root.encode_u32(0x200,int(row.args[1]))
		elif row.kind in ["F772","F664","F665","F666","F668","F297","F40","F926","F291"]:row.return_u32=116+676
		elif row.kind=="F52":row.return_u32=0x77889900
		elif row.kind in ["F101","F314"]:row.return_u32=0x55aa1122
		elif row.kind=="F1344":row.return_u32=int(row.args[1])+3
		elif row.kind in ["F304","F305"]:row.output_hex="11223344";row.output_defined_hex="01010101"
		if policy.is_valid():policy.call(row,step)
		rows.append(row)
	return {"result":{"ok":false,"reason":"test_callback_limit"},"observations":rows}
func mutate_packet(row:Dictionary,_step:int)->void:
	if row.kind=="F345":
		var value:=str(row.input_hex).hex_decode();var known:=str(row.input_defined_hex).hex_decode();value[31]=0x91;known[31]=1;row.output_hex=value.hex_encode();row.output_defined_hex=known.hex_encode()
func cancel_generation(row:Dictionary,_step:int)->void:
	if row.kind=="F38":row.after.task_record.encode_u16(6,(row.after.task_record.decode_u16(6)+1)&65535);row.after.task_record.encode_u32(0,6)
func change_mode(row:Dictionary,_step:int)->void:
	if row.kind=="F31":row.after.root_tail.encode_u32(0x180c,0)
func change_state(row:Dictionary,_step:int)->void:
	if row.kind=="F342":row.after.task_record.encode_u32(0,0)
func directed()->void:
	var seed:=scratch();var before:=context();var original:=digest([before,seed]);var result:=Kernel.execute(before,[],seed)
	check(result.get("ok",false) and result.source_order==["F41"] and int(result.context_after.ip_u32)==1 and result.scratch_after_hex==seed.seed_hex and result.scratch_defined_hex==seed.defined_hex,"Stop opcode consumes one byte and preserves every supplied private byte")
	check(not Kernel.execute(before).ok,"Invocation stack bytes are explicit rather than invented zero initialization")
	for opcode in range(61,256):
		var raw:=context(PackedByteArray([opcode,0]));result=Kernel.execute(raw,[],seed);check(result.get("ok",false) and result.context_after.ip_u32==2 and result.source_order==["F41"],"Every out-of-table byte is a source loop no-op: %d"%opcode)
	var counts:={4:6,5:0,6:0,7:1,8:1,11:1,12:1,13:1,14:3,15:2,16:3,17:2,18:1,19:1,20:1,21:3,22:1,23:1,24:1,25:1,26:2,27:2,28:2,29:1,30:2,31:3,32:1,33:2,34:0,35:1,36:2,37:0,38:1,39:4,40:2,41:2,42:2,43:2,44:2,45:3,46:2,47:3,48:5,49:5,50:9,51:2,52:2,53:3,54:3,55:3,56:4,57:1,58:2,59:5,60:3}
	for opcode:int in counts:
		var values:Array=[]
		for index in range(int(counts[opcode])):values.append(1)
		if opcode==58:values[1]=1001
		var assigns:=opcode in [7,19,37,39,41,42,43,48,50,52,58];var raw:=context(program(opcode,values,assigns));var done:=complete(raw,seed)
		check(done.result.get("ok",false),"All source selector caller bodies execute with explicit callbacks: %d / %s"%[opcode,str(done.result.get("reason","ok"))])
		if done.result.get("ok",false):check(not done.result.return_defined and done.result.return_u32==0 and done.result.void_return_register_ignored,"Void F41 never becomes a fabricated scalar result")
	var done:=complete(context(program(10,[])),seed)
	check(not done.result.ok,"Inline string opcode rejects a missing expression continuation")
	var inline_code:=PackedByteArray([10,65,0])+literal(1)+literal(2)+literal(3)+literal(4)+PackedByteArray([6])+word(2)+PackedByteArray([0]);done=complete(context(inline_code),seed)
	check(done.result.get("ok",false) and done.observations[4].kind=="F101" and done.observations[4].args[0]==BASE+1 and done.observations[4].input_hex=="4100" and done.observations[4].input_defined_hex=="0101","Inline string uses actual sourceVA and known NUL-terminated bytes")
	var branch:=PackedByteArray([2])+literal(1)+word(0xfffffffc)+PackedByteArray([5,0]);done=complete(context(branch),seed)
	check(done.result.get("ok",false) and done.result.source_order==["F41","F31","F342"],"True conditional skips the displacement without calling F20")
	branch=PackedByteArray([2])+literal(0)+word(5)+PackedByteArray([61,0]);done=complete(context(branch),seed)
	check(done.result.get("ok",false) and done.result.source_order==["F41","F31","F20"],"False conditional displacement is relative to its own word")
	branch=PackedByteArray([3])+word(0xffffffff);result=Kernel.execute(context(branch),[],seed);check(not result.ok and result.reason=="statement_iteration_profile_limit","Source backward jump is bounded without inventing a normal after-state")
	var packet_code:=program(23,[17]);packet_code.resize(packet_code.size()-1);packet_code.append_array(program(27,[29,31]));done=complete(context(packet_code),seed,mutate_packet)
	check(done.result.get("ok",false),"Two UI statements share the same private scratch invocation")
	if done.result.get("ok",false):
		var packets:Array=[]
		for row:Dictionary in done.observations:
			if row.kind=="F345":packets.append(row)
		check(packets.size()==2 and str(packets[1].input_hex).hex_decode()[31]==0x91 and str(packets[1].input_defined_hex).hex_decode()[31]==1,"Callback pointer writes survive to a later packet without losing definedness")
		check(str(packets[0].input_defined_hex).hex_decode().slice(0,4)==bytes(4,1) and str(packets[0].input_defined_hex).hex_decode().slice(4,48)==bytes(44),"Source initializes only the packet words it actually stores")
	var cancel_code:=program(8,[0x30007]);cancel_code.resize(cancel_code.size()-1);cancel_code.append_array(PackedByteArray([5,0]));done=complete(context(cancel_code),seed,cancel_generation)
	check(done.result.get("ok",false) and done.result.source_order.has("F342") and done.result.context_after.task_record.decode_u32(0)==6,"Self cancellation compares handle after the callback and continues when generation changed")
	done=complete(context(PackedByteArray([5,6,0])),seed,change_state);check(done.result.get("ok",false) and done.result.source_order==["F41","F342","F326"],"World task-state changes do not become a generic source loop exit")
	var wrapped:=context(program(60,[1,0x12345678,0x40000000]));done=complete(wrapped,seed)
	check(done.result.get("ok",false) and done.result.context_after.bank.decode_u16(116+338+0x102)==500 and done.result.context_after.bank.decode_u16(116+338+0x106)==0xfe0c,"Vector index scaling wraps32 bits before readonly table admission")
	var alias:=context(program(57,[0x80000001]));alias.bank.encode_u32(116+338+0x8c,0x11223344);done=complete(alias,seed)
	check(done.result.get("ok",false) and done.result.context_after.bank.decode_u32(116+338+0x8c)==0,"Whole F1532 low32 multiplication retains a canonical body alias")
	var held:=context(program(57,[1]));held.bank.encode_u32(116+338+0x8c,0x11223344);done=complete(held,seed,change_mode)
	check(done.result.get("ok",false) and done.result.context_after.root_tail.decode_u32(0x180c)==0 and done.result.context_after.bank.decode_u32(116+338+0x8c)==0,"Bank base captured before expression survives a later global-mode change")
	var warm:=complete(context(packet_code),seed,mutate_packet)
	if warm.result.get("ok",false):
		var cold_ctx:=Kernel.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(context(packet_code)))));var cold_rows:Variant=Kernel.decode_observations(JSON.parse_string(JSON.stringify(Scan.json_value(warm.observations))));var cold:=Kernel.execute(cold_ctx,cold_rows,JSON.parse_string(JSON.stringify(seed)))
		check(cold.get("ok",false) and cold.context_after==warm.result.context_after and cold.source_order==warm.result.source_order and cold.scratch_after_hex==warm.result.scratch_after_hex and cold.scratch_defined_hex==warm.result.scratch_defined_hex,"Cold JSON replays every context owner, typed callback and private byte exactly")
		for key:String in ["program_base_u32","ip_u32","task_slot_u32","text_cursor_u32"]:check(cold.context_after[key] is int,"Cold scalar owner is canonically integral: "+key)
	check(digest([before,seed])==original,"Successful, pending and rejected calls preserve caller-owned inputs")
func malformed()->void:
	var raw:=context();var seed:=scratch();var frozen:=digest(raw)
	for bad:Variant in [null,true,3,[],{},bytes(1)]:check(not Kernel.execute(bad,[],seed).ok,"Malformed statement context rejects before typed access")
	for key:String in Kernel.CONTEXT_KEYS:
		var bad:=raw.duplicate(true);bad.erase(key);check(not Kernel.execute(bad,[],seed).ok and Kernel.decode_context(bad).is_empty(),"Missing statement owner rejects: "+key)
	for bad:Variant in [null,true,[],{}, {"seed_hex":"00","defined_hex":"00"},{"seed_hex":"00".repeat(156),"defined_hex":"ff".repeat(156)}]:check(not Kernel.execute(raw,[],bad).ok,"Malformed invocation stack provenance rejects")
	var cycle:Dictionary={};cycle["self"]=cycle;check(Kernel.decode_context(cycle).is_empty() and not Kernel.execute(raw,[],cycle).ok,"Cyclic stack/context fields reject before deep copying");cycle.clear()
	var rows:Array=[];rows.append(rows);check(Kernel.decode_observations(rows)==null and not Kernel.execute(raw,rows,seed).ok,"Cyclic callbacks reject before recursive duplication");rows.clear()
	var done:=complete(context(program(23,[17])),seed)
	if done.result.get("ok",false):
		var initial:=context(program(23,[17]))
		for field:String in ["task_slot_u32","program_base_u32"]:
			var bad:Array=done.observations.duplicate(true);bad[0].after[field]=int(bad[0].after[field])+1;check(not Kernel.execute(initial,bad,seed).ok,"Callback cannot alter physical frame identity: "+field)
		var bad:Array=done.observations.duplicate(true);bad[0].after.program[0]^=1;check(not Kernel.execute(initial,bad,seed).ok,"Callback cannot alter the source byte program")
		bad=done.observations.duplicate(true);bad[1].input_defined_hex="01".repeat(48);check(not Kernel.execute(initial,bad,seed).ok,"Callback cannot claim uninitialized packet bytes were source-defined")
		bad=done.observations.duplicate(true);bad[1].output_hex="00";bad[1].output_defined_hex="01";check(not Kernel.execute(initial,bad,seed).ok,"Truncated typed packet output rejects")
		bad=done.observations.duplicate(true);bad.append(bad[-1].duplicate(true));check(not Kernel.execute(initial,bad,seed).ok,"Unused callbacks cannot silently succeed")
	check(digest(raw)==frozen,"Malformed transports never mutate the live caller owner")
func buffer(key:String)->PackedByteArray:
	if hydrated.has(key):return hydrated[key].duplicate()
	if not pool.has(key):check(false,"Native statement buffer exists in its source-hashed pool");return PackedByteArray()
	var entry:Dictionary=pool[key];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
	check(raw.size()==int(entry.byte_count) and hash.finish().hex_encode()==key,"Native statement owner bytes decompress to their exact captured SHA256")
	hydrated[key]=raw.duplicate();return raw
func hydrate(value:Dictionary)->Dictionary:
	var raw:=value.duplicate(true)
	for key:String in Kernel.BYTE_COUNTS:
		if raw[key] is String and pool.has(raw[key]):raw[key]=buffer(raw[key])
	for key:String in ["program","text_buffer"]:
		if raw[key] is String and pool.has(raw[key]):raw[key]=buffer(raw[key])
	return Kernel.decode_context(raw)
func native_controls(doc:Dictionary)->void:
	check(doc.schema=="starfrontier-mission-statements-native-v1" and doc.profile==Kernel.PROFILE and int(doc.case_count)==doc.cases.size(),"Native statement profile and case inventory match")
	check(not doc.expected_arithmetic_calculated_in_python,"Original native instructions provide every expected statement owner and private byte")
	for path:String in doc.get("source_dependencies_sha256",{}):check(FileAccess.get_sha256("res://"+path)==doc.source_dependencies_sha256[path],"Statement native source dependency is current: "+path)
	for path:String in doc.get("proofs_sha256",{}):check(FileAccess.get_sha256(PROOF+path)==doc.proofs_sha256[path],"Statement whole-procedure proof artifact is pinned: "+path)
	var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PROOF+"instruction-proof.json"))
	native_whole_procedures=int(proof.whole_procedure_count);native_whole_instructions=int(proof.whole_instruction_count)
	check(int(proof.whole_procedure_count)==7 and int(proof.whole_instruction_count)==1509 and int(proof.F41_instruction_count)==1430 and int(proof.F41_dispatch_target_count)==61,"Whole original F41 and six closed helper bodies retain all1509 actual instructions and61 targets")
	check(proof.all_code_regions_equal and proof.all_inline_table_bytes_and_targets_equal and proof.source_code_variants.is_empty() and proof.source_table_variants.is_empty() and proof.unmodified_JJFFE_F41_semantics_equal,"Actual DOS code and complete dispatch table have no inferred JJFFE substitutions")
	check(int(doc.fresh_process_runs)==3 and int(doc.reverse_repeat_cases)==doc.cases.size(),"Three fresh and reverse native streams reproduce every normal source case")
	check(doc.uninitialized_stack_bytes_have_explicit_seed_and_mask and int(doc.observable_scratch_byte_count)==72,"Private source bytes use explicit invocation witnesses rather than invented initialization")
	var previous:Dictionary={};var previous_cold:Dictionary={};var previous_scratch:Dictionary={}
	for row:Dictionary in doc.cases:
		var before:=hydrate(row.context_before);var expected:=hydrate(row.expected.context_after);var replies:Array=[]
		for item:Dictionary in row.observations:
			var reply:=item.duplicate(true);reply.before=hydrate(item.before);reply.after=hydrate(item.after);replies.append(reply)
		check(not before.is_empty() and not expected.is_empty(),"Native eleven-owner statement contexts decode: "+str(row.name))
		if before.is_empty() or expected.is_empty():continue
		if row.get("carries_previous_native_state",false):
			check(not previous.is_empty() and before==previous and before==previous_cold,"Every native statement owner comes from the preceding live and cold continuation");native_state_edges+=1
		if row.get("carries_previous_measured_frame",false):
			check(not previous_scratch.is_empty() and row.scratch==previous_scratch,"Next invocation explicitly carries the preceding measured source pointer-backed bytes and mask");native_frame_edges+=1
		var frozen:=digest([before,row.scratch,replies]);var result:=Kernel.execute(before,replies,row.scratch)
		check(result.get("ok",false),"Whole original statement caller executes: "+str(row.name)+" / "+str(result.get("reason","ok")))
		if not result.get("ok",false):continue
		for field:String in Kernel.CONTEXT_KEYS:check(result.context_after[field]==expected[field],"Native statement owner matches "+field+": "+str(row.name))
		check(result.source_order==row.expected.source_order and int(result.observations_used)==replies.size(),"Every expression, service, store and event retains native source order")
		check(result.scratch_after_hex==row.expected.scratch_after_hex and result.scratch_defined_hex==row.expected.scratch_defined_hex,"All72 observable private bytes and definedness masks match actual source stores and provider writes")
		check(not result.return_defined and result.return_u32==0 and result.void_return_register_ignored and int(result.cursor_after_u32)==int(row.expected.cursor_after_u32),"F41 cursor and ignored void return match their original ABI")
		var counts:Array=[]
		for value:Variant in row.expected.opcode_counts_u32:counts.append(int(value))
		check(result.opcode_counts_u32==counts and int(result.dispatch_iterations_u32)==int(row.expected.dispatch_iterations_u32),"Dispatch selectors and loop iterations come from literal original instruction execution")
		for index in range(256):
			if int(counts[index])>0:covered_selectors[index]=true
		var cold_before:=Kernel.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(previous_cold if row.get("carries_previous_native_state",false) else before))));var cold_rows:Variant=Kernel.decode_observations(JSON.parse_string(JSON.stringify(Scan.json_value(replies))));var cold:=Kernel.execute(cold_before,cold_rows,JSON.parse_string(JSON.stringify(row.scratch)))
		check(cold.get("ok",false) and cold.context_after==result.context_after and cold.scratch_after_hex==result.scratch_after_hex and cold.scratch_defined_hex==result.scratch_defined_hex and cold.source_order==result.source_order,"Independent cold JSON source continuation matches all native owner/private effects")
		check(digest([before,row.scratch,replies])==frozen,"Native commands and typed callback owners remain private")
		if before.program.size()==57560:
			check(before.program==Programs.read(resources,"mission",0,57560),"Actual-resource statement cases preserve the complete independently captured DOS program image");original_resource_cases+=1
		native_cases+=1;provider_calls+=replies.size();previous=result.context_after.duplicate(true);previous_cold=cold.context_after.duplicate(true) if cold.get("ok",false) else {};previous_scratch={"seed_hex":result.scratch_after_hex,"defined_hex":result.scratch_defined_hex}
	check(native_state_edges==int(doc.consecutive_native_state_transitions) and native_frame_edges==int(doc.consecutive_measured_frame_transitions) and native_state_edges==11 and native_frame_edges==11,"Twelve native invocations retain all eleven measured owner and explicit-frame carry edges")
	check(provider_calls==int(doc.typed_boundary_count) and original_resource_cases==int(doc.actual_original_resource_cases) and original_resource_cases==16,"Every typed native service and all sixteen actual DOS statement prefixes execute")
	check(native_cases==doc.cases.size(),"Every normal original native case executes")
	check(covered_selectors.size()==256,"All256 selector bytes include every61 source statement and all195 table misses")
	for row:Dictionary in doc.get("original_fault_domains_separate",[]):
		var before:=hydrate(row.context_before);var replies:Array=[]
		for raw:Dictionary in row.get("observations",[]):
			var reply:=raw.duplicate(true);reply.before=hydrate(raw.before);reply.after=hydrate(raw.after);replies.append(reply)
		var frozen:=digest([before,replies]);var result:=Kernel.execute(before,replies,row.scratch)
		check(not before.is_empty() and Kernel.decode_observations(replies)!=null and int(row.actual_native_process_returncode)==-11 and int(row.fresh_native_process_runs)==3 and not row.expected_complete_native_context_after_available,"Native pointer-fault domain is separate from normal expected after-states")
		check(not result.get("ok",false) and not result.has("context_after") and not result.has("pending") and digest([before,replies])==frozen,"Original native pointer fault rejects without fabricated owner state")
		native_fault_domains+=1
	for row:Dictionary in doc.get("bounded_nontermination_domains_separate",[]):
		var before:=hydrate(row.context_before);var result:=Kernel.execute(before,[],row.scratch)
		check(int(row.native_host_status_u32)==2 and int(row.dispatch_budget_u32)==4096 and int(row.fresh_native_process_runs)==3 and not row.source_termination_claimed and not row.after_state_claimed,"Literal nontermination has a bounded native host witness and no invented source termination")
		check(not result.get("ok",false) and result.reason=="statement_iteration_profile_limit" and not result.has("context_after"),"Portable loop guard rejects nontermination without a fabricated final source context");native_bounded_nontermination+=1
	for row:Dictionary in doc.get("unsupported_transport_cases",[]):
		var before:=hydrate(row.context_before);var frozen:=digest(before);var result:=Kernel.execute(before,[],row.scratch)
		check(int(row.native_transport_exit_code)==97 and int(row.fresh_native_process_runs)==3 and not row.original_source_fault_claimed and not row.after_state_claimed,"Malformed owned literal is a transport rejection rather than an invented original source SIGSEGV")
		check(not result.get("ok",false) and result.reason=="unterminated_statement_inline_string" and not result.has("context_after") and not result.has("pending") and digest(before)==frozen,"Unterminated literal rejects atomically before any string provider or native helper claim");native_transport_rejections+=1
	check(native_transport_rejections==1,"Independent malformed-literal admission control remains in the corpus")
	check(native_fault_domains==2 and native_bounded_nontermination==1,"Separate fault and bounded-loop inventories retain their original outcomes")
func run()->void:
	resources=Programs.load_original();check(Programs.validate(resources),"Immutable original resources validate")
	directed();malformed()
	var doc:Dictionary={}
	if FileAccess.file_exists(FIXTURE):
		doc=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));check(FIXTURE_SHA==FileAccess.get_sha256(FIXTURE),"Original statement native fixture SHA is frozen");pool=doc.get("buffer_pool",{});native_controls(doc)
	var sources:Dictionary={}
	for path:String in ["scripts/source_mission_statements.gd","scripts/source_mission_statements.gd.uid","tests/test_source_mission_statements.gd","tests/test_source_mission_statements.gd.uid","scripts/source_mission_programs.gd","data/ffe_mission_programs.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if not doc.is_empty():
		sources[FIXTURE.trim_prefix("res://")]=FileAccess.get_sha256(FIXTURE)
		for path:String in doc.get("source_dependencies_sha256",{}):sources[path]=FileAccess.get_sha256("res://"+path)
		for path:String in doc.get("proofs_sha256",{}):sources[(PROOF+path).trim_prefix("res://")]=FileAccess.get_sha256(PROOF+path)
	for name:String in ["instruction-proof.json","source-procedures.asm","statements-native.s","statements-host.c"]:
		if FileAccess.file_exists(PROOF+name):sources[(PROOF+name).trim_prefix("res://")]=FileAccess.get_sha256(PROOF+name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Kernel.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"provider_calls":provider_calls,"native_fixture_pending":doc.is_empty(),"native_fault_domains":native_fault_domains,"native_same_owner_edges":native_state_edges,"native_explicit_frame_edges":native_frame_edges,"native_bounded_nontermination":native_bounded_nontermination,"native_transport_rejections":native_transport_rejections,"native_selector_bytes":covered_selectors.size(),"native_whole_procedure_count":native_whole_procedures,"native_whole_instruction_count":native_whole_instructions,"actual_DOS_resource_cases":original_resource_cases,"sources":sources,"Main_integrated":false,"full_world_services_executed":false},"\t")+"\n");file.close()
	print("SOURCE MISSION STATEMENTS TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
