extends SceneTree
const Kernel=preload("res://scripts/source_mission_expression.gd")
const FIXTURE:="res://tests/fixtures/source_mission_expression_native.json"
const FIXTURE_SHA:="ff177e8e1ec382c8bc3754907019486cc6b98246abeca3ae0f59a55dbe8fd0df"
const PROOF:="res://validation/mission-expressions-2026-11-18/expression-native-proof/"
const REPORT:="res://build/current-test-reports/source-mission-expression.json"
var checks:=0
var failures:=0
var buffers:Dictionary={}
var hydrated:Dictionary={}
var native_cases:=0
var provider_calls:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<20:push_error(message)
func zeros(count:int)->PackedByteArray:
	var result:=PackedByteArray();result.resize(count);return result
func word(value:int)->PackedByteArray:
	var result:=zeros(4);result.encode_u32(0,value&0xffffffff);return result
func literal(value:int)->PackedByteArray:return PackedByteArray([2])+word(value)
func expression(opcode:int,children:Array)->PackedByteArray:
	var result:=PackedByteArray([opcode])
	for child:PackedByteArray in children:result.append_array(child)
	return result
func context(program:PackedByteArray=PackedByteArray([2,0,0,0,0]))->Dictionary:
	var root:=zeros(16384);root.encode_u32(0xc8,454);root.encode_u32(0xcc,792);root.encode_u32(4,0x121cf7);root.encode_u32(0x24,0x12345678);root.encode_u32(0x28,0xfedcba98)
	var tail:=zeros(6160);tail.encode_u32(0x180c,1)
	var bank:=zeros(38986);bank[1]=1;bank[2]=1;bank[454+0x86]=1;bank[792+0x86]=2
	return {"root":root,"root_tail":tail,"bank":bank,"event_registers":zeros(284),"module_globals":zeros(40),"task_variables":zeros(32),"program":program.duplicate(),"ip_u32":0,"module_global_offset_u32":0,"temporary_event_index_s32":-7}
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
func list_buffer()->PackedByteArray:
	var out:=zeros(4096)
	for index in range(3):
		out.encode_u32(index*68,1);out.encode_u32(index*68+4,101+index);out.encode_u16(index*68+0xa,0x20 if index!=1 else 0x1f);out.encode_u16(index*68+0xc,0x76+index)
	return out
func output_for(kind:String)->PackedByteArray:
	if kind=="F461":return list_buffer()
	if kind=="F649":
		var out:=zeros(308)
		for index in range(38):out.encode_u32(index*8+4,100+index)
		return out
	if kind=="F658":return PackedByteArray([0xef,0xbe])
	if kind=="F870":return word(11)+word(22)+word(33)+word(44)
	if kind=="F871":return word(55)+word(66)
	return PackedByteArray()
func complete(before:Dictionary,operation:String="F31",args:Array=[],policy:Callable=Callable())->Dictionary:
	var replies:Array=[]
	for attempt in range(65):
		var result:=Kernel.execute(before,operation,args,replies)
		if result.get("ok",false):return {"ok":true,"result":result,"observations":replies}
		if not result.get("pending") is Dictionary:return {"ok":false,"result":result,"observations":replies}
		var pending:Dictionary=result.pending;var kind:String=pending.kind;var after:Dictionary=pending.before.duplicate(true)
		if policy.is_valid():policy.call(kind,after)
		var returned:=0 if kind in ["F461","F48","F909","F870","F871"] else 1 if kind=="F649" else 0xffffffff if kind=="F1476" else 3
		replies.append({"kind":kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":after,"return_u32":returned,"input_hex":"","output_hex":output_for(kind).hex_encode()})
	return {"ok":false}
func mutate_event(kind:String,after:Dictionary)->void:
	if kind=="F85":after.event_registers.encode_u32(0,10);after.root_tail.encode_u32(0x10e0,0xdeadbeef)
func resize_variables(_kind:String,after:Dictionary)->void:after.task_variables.resize(36)
func directed_controls()->void:
	var raw:=context(literal(0xffffffff));var before:=digest(raw);var result:=Kernel.execute(raw)
	check(result.ok and result.return_u32==0xffffffff and result.return_s32==-1 and result.context_after.ip_u32==5,"Literal reader preserves raw uint32 and advances its actual four bytes")
	check(digest(raw)==before and result.source_order==["F31","F20"],"Expression input owners remain private and exact calls are recorded")
	var copy:Dictionary=result.context_after.duplicate(true);copy.root[0]=99;check(raw.root[0]==0,"Returned owners do not alias caller storage")
	var pairs:Array=[[11,-7,3,-2],[12,-7,3,-1],[10,0x80000000,2,0],[15,1,33,2],[16,0x80000000,33,0xc0000000],[17,0x80000000,0,1],[21,0xffffffff,-1,1]]
	for item:Array in pairs:
		result=Kernel.execute(context(expression(item[0],[literal(item[1]),literal(item[2])])));check(result.ok and result.return_u32==(int(item[3])&0xffffffff),"Source signed division/shift/wrap boundary has its defined result")
	for opcode in [11,12]:
		for pair:Array in [[1,0],[-0x80000000,-1]]:
			result=Kernel.execute(context(expression(opcode,[literal(pair[0]),literal(pair[1])])));check(not result.ok and result.reason=="source_signed_division_fault","Both source IDIV fault domains reject without fabricated arithmetic")
	for opcode in Kernel.UNDEFINED_SELECTORS+[68,255]:
		result=Kernel.execute(context(PackedByteArray([opcode])));check(not result.ok and result.reason=="undefined_source_expression_result","Unwritten original frame result is an explicit unsupported domain")
	var pointers:=context();pointers.root.encode_u32(0x10a,0xfedcba98);pointers.root[0xec]=255;pointers.root[0xe8]=128
	for pair:Array in [[0,1],[13,2],[4,0xfedcba98],[12,0xffffffff],[14,0xffffff80],[0xffffffff,0]]:
		result=Kernel.execute(pointers,"F21",[pair[0]]);check(result.ok and result.return_u32==pair[1],"Source globals use DOS aliases, unaligned DWORDs and signed bytes")
	var set15:=complete(pointers,"F22",[15,0x76543210]);var set16:=complete(pointers,"F22",[16,0x76543210])
	check(set15.ok and set15.result.context_after.root.decode_u32(0x124)==0x76543210 and set16.ok and set16.result.context_after.root.decode_u32(0x124)==0,"Actual DOS setter table uses15; JJFFE16 is not imported")
	check(set15.ok and set15.result.source_order==["F22","F48"] and set15.observations[0].args==[1,0,15] and not set15.result.return_defined,"Setter dispatch uses the original selector and void EAX remains ignored")
	for value in [0xffffffff,0x80000000,0,1,0x0fffffff,0x10000000]:
		var done:=complete(pointers,"F22",[1,value]);check(done.ok and done.result.context_after.root.decode_u32(0x19c)==clampi(Kernel._s32(value),0,0x0fffffff),"Credit-like selector saturates its actual signed domain")
	var done:=complete(pointers,"F22",[4,123]);check(done.ok and done.result.source_order==["F22","F909","F48"],"Setter service completes before its event dispatch")
	var globals:=context(PackedByteArray([5])+word(1));globals.module_global_offset_u32=4;globals.module_globals.encode_u32(8,0x81234567)
	result=Kernel.execute(globals);check(result.ok and result.return_u32==0x81234567,"Module variables share the actual40-byte owner at a descriptor base")
	globals.module_global_offset_u32=0xffffffff;result=Kernel.execute(globals);check(not result.ok,"Null descriptor globals are rejected before dereference")
	var tail:=context(expression(31,[literal(5)]));tail.root_tail.encode_u32(0x10e0+20,0x87654321);result=Kernel.execute(tail)
	check(result.ok and result.return_u32==0x87654321,"D9093 is read from the distinct original Root tail")
	var composed:=expression(13,[expression(32,[literal(1),literal(2)]),PackedByteArray([4])+word(0)]);raw=context(composed);before=digest(raw);done=complete(raw,"F31",[],Callable(self,"mutate_event"))
	check(done.ok and done.result.return_u32==13 and done.result.context_after.root_tail.decode_u32(0x10e0)==0xdeadbeef,"Later expression operands reread callback-mutated shared owners")
	check(digest(raw)==before and done.ok and done.result.context_after.ip_u32==composed.size(),"Callback continuation advances the private cursor exactly and preserves its caller")
	done=complete(raw,"F31",[],Callable(self,"resize_variables"));check(not done.ok,"A provider cannot resize the selected variable-buffer identity")
	for opcode in [49,67]:
		done=complete(context(expression(opcode,[literal(9)])));check(done.ok and done.result.return_u32==(66 if opcode==49 else 22),"Aliased F871 and ordered F870 output arguments return the actual result slot")
	done=complete(context(expression(50,[literal(2)])));check(done.ok and done.result.return_u32==1 and done.result.source_order==["F31","F1476","F31","F20"],"Time/random provider executes before its recursively evaluated unsigned divisor")
	for index in [-1,0,37,38]:
		done=complete(context(expression(66,[literal(1),literal(1000+index)])));check(done.ok and done.result.return_u32==(100+index if index>=0 and index<38 else 0),"Market pointer witness is checked after the original service call and before indexed read")
	var list:=list_buffer();raw=context(list);result=Kernel.execute(raw,"F462");check(result.ok and result.return_u32==2,"Actual qualifying-list count runs over original68-byte records")
	result=Kernel.execute(raw,"F463",[1]);check(result.ok and result.return_u32==137 and result.pointer_return_defined and not result.scalar_return_defined,"Logical list-pointer result preserves slot2 while excluding host EAX")
	result=Kernel.execute(raw,"F463",[2]);check(result.ok and result.return_u32==0 and result.pointer_return_defined,"List pointer NULL differs from a valid first-record reference")
	result=Kernel.execute(raw,"F25",[30]);check(result.ok and result.return_u32==3,"Original class predicate traverses the explicit local list")
	result=Kernel.execute(raw,"F26",[30,7]);check(result.ok and result.return_u32==0,"Past-end list lookup returns its caller-provided terminator value")
	raw.program.encode_u32(3*68+4,0xfeedbeef);result=Kernel.execute(raw,"F26",[30,7]);check(result.ok and result.return_u32==0xfeedbeef,"F26 does not invent NULL where source reads the terminator payload")
	raw=context();raw.bank[114]=1;raw.bank.encode_u32(116+114*338+0xa0,77);raw.bank[116+114*338+0x14c]=16;raw.bank.encode_u32(454+0xa0,77);raw.bank[454+0x14c]=16
	result=Kernel.execute(raw,"F27",[28,77]);check(result.ok and result.return_u32==114,"Source bank search takes the first matching record in descending slot order")
	for slot in [0,1,114]:
		result=Kernel.execute(raw,"F1532",[slot]);check(result.ok and result.return_u32==116+338*slot and result.pointer_return_defined and not result.scalar_return_defined,"Whole source bank lookup returns a logical pointer at the actual record stride")
	for invalid:Variant in [null,[],0,"bad",{}]:check(not Kernel.execute(invalid).ok,"Malformed contexts reject without a script error")
	for invalid:Variant in [null,0,{},[1],[-1],[0x100000000]]:check(not Kernel.execute(context(),"F31",invalid).ok,"Malformed operation arguments reject atomically")
	for path:String in ["root","root_tail","bank","event_registers","module_globals","task_variables","program"]:
		var bad:=context();bad[path]=zeros(0);check(not Kernel.execute(bad).ok,"Every byte owner requires its exact bounded layout")
	var bad:=context();bad.root_tail.encode_u32(0x180c,0);check(not Kernel.execute(bad).ok,"Canonical bank identity is mandatory")
	bad=context();bad.root.encode_u32(0xc8,117);check(not Kernel.execute(bad).ok,"Body references require actual record boundaries")
	result=Kernel.execute(context(PackedByteArray([2,0,0])));check(not result.ok,"Truncated immediates reject before reading outside bytecode")
	var reply_done:=complete(context(expression(32,[literal(1),literal(2)])));check(reply_done.ok,"Provider fixture has a complete valid continuation")
	if reply_done.ok:
		for field:String in ["program","ip_u32","module_global_offset_u32"]:
			var replies:Array=reply_done.observations.duplicate(true)
			if field=="program":replies[0].after.program[0]=0
			else:replies[0].after[field]=int(replies[0].after[field])+1
			check(not Kernel.execute(context(expression(32,[literal(1),literal(2)])),"F31",[],replies).ok,"A provider cannot rewrite program or cursor identity")
		var extra:Array=reply_done.observations.duplicate(true);extra.append(extra[0]);check(not Kernel.execute(context(expression(32,[literal(1),literal(2)])),"F31",[],extra).ok,"Unused observations cannot silently alter a completed evaluation")
	var json_context:Variant=encode(context(literal(7)));check(Kernel._same_context(Kernel.decode_context(JSON.parse_string(JSON.stringify(json_context))),context(literal(7))),"Canonical JSON round-trip preserves every typed owner")
	var cycle:Dictionary={};cycle["self"]=cycle
	var cyclic_context:=context();cyclic_context.program=cycle
	check(Kernel.decode_context(cyclic_context).is_empty() and not Kernel.execute(cyclic_context).ok and Kernel._copy_context(cyclic_context).is_empty(),"Cyclic forged owners reject before any recursive duplication")
	var cyclic_observations:Array=[];cyclic_observations.append(cyclic_observations)
	check(Kernel.decode_observations(cyclic_observations)==null and not Kernel.execute(context(),"F31",[],cyclic_observations).ok,"Cyclic forged observation rows reject before duplication")
	cycle.clear();cyclic_observations.clear()
func buffer(key:String)->PackedByteArray:
	if hydrated.has(key):return hydrated[key].duplicate()
	var entry:Dictionary=buffers[key];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE);var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(raw)
	check(raw.size()==int(entry.byte_count) and h.finish().hex_encode()==key,"Native owner pool verifies exact decompressed bytes")
	hydrated[key]=raw.duplicate();return raw
func hydrate(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true)
	for key:String in Kernel.BYTE_COUNTS.keys()+["task_variables","program"]:result[key]=buffer(str(value[key].buffer_sha256))
	return Kernel._copy_context(result)
func native_controls(doc:Dictionary)->void:
	check(doc.profile==Kernel.PROFILE and int(doc.case_count)==doc.cases.size(),"Native complete-expression profile and case inventory agree")
	check(doc.fresh_cohort_runs==3 and doc.reverse_repeat_cases==doc.case_count and not doc.expected_arithmetic_calculated_in_python,"Expected arithmetic comes from fresh and reversed original-instruction executions")
	check(int(doc.whole_procedure_count)==17 and int(doc.whole_instruction_count)==1311,"Whole original procedures and all disjoint code regions remain covered")
	check(FileAccess.get_sha256(PROOF+"instruction-proof.json")==doc.instruction_proof_sha256,"Whole code regions and actual DOS inline jump tables stay pinned")
	for pair:Array in [["source-procedures.asm","source_procedures_sha256"],["expression-native.s","native_assembly_sha256"],["expression-support.c","native_support_sha256"]]:check(FileAccess.get_sha256(PROOF+pair[0])==doc[pair[1]],"Reviewed whole-source and host ABI captures remain exact")
	for path:String in doc.source_dependencies_sha256:check(FileAccess.get_sha256("res://"+path)==doc.source_dependencies_sha256[path],"Native source dependency current: "+path)
	var selectors:Dictionary={}
	for row:Dictionary in doc.cases:
		var before:=hydrate(row.context_before);var expected:=hydrate(row.expected.context_after);var observations:Array=[]
		if row.operation=="F31":selectors[int(before.program[int(before.ip_u32)])]=true
		for item:Dictionary in row.observations:
			var reply:Dictionary=item.duplicate(true);reply.before=hydrate(item.before);reply.after=hydrate(item.after);observations.append(reply)
		var frozen:=digest([before,row.args,observations]);var result:=Kernel.execute(before,row.operation,row.args,observations)
		check(result.ok,"Original expression case executes: "+str(row.name))
		if not result.ok:continue
		check(Kernel._same_context(result.context_after,expected),"All ten owner fields match original execution: "+str(row.name))
		check(result.return_u32==int(row.expected.return_u32),"Source result or logical pointer matches native: "+str(row.name))
		check(result.return_defined==row.expected.return_defined and result.scalar_return_defined==row.expected.return_defined and result.pointer_return_defined==(row.operation in ["F1532","F463"]),"Pointer, scalar and void return domains remain distinct")
		check(result.source_order==row.expected.source_order and result.observations_used==observations.size(),"Exact recursive/provider order and continuation count match")
		check(digest([before,row.args,observations])==frozen,"Original input context, arguments and observations stay private")
		check(result.context_after.program==before.program and result.context_after.module_global_offset_u32==before.module_global_offset_u32 and result.context_after.task_variables.size()==before.task_variables.size(),"Code and allocation identities remain readonly")
		native_cases+=1;provider_calls+=observations.size()
	check(selectors.size()==55,"Every source selector with a defined result is represented by independently executed controls")
	for selector in range(68):check(selectors.has(selector)==(selector not in Kernel.UNDEFINED_SELECTORS),"Defined and unwritten original selector domains stay distinct")
	check(doc.source_table_variants.size()==2 and int(doc.source_table_variants[0].slot_u32)==15 and int(doc.source_table_variants[1].slot_u32)==16,"Actual DOS setter-table differences remain explicit provenance")
	check(doc.original_fault_domains.size()==5 and int(doc.fault_case_count_separate)==5,"Original divide faults remain a separate native diagnostic bank")
	for row:Dictionary in doc.original_fault_domains:
		var before:=hydrate(row.context_before);var observations:Array=[]
		for item:Dictionary in row.observations:
			var reply:Dictionary=item.duplicate(true);reply.before=hydrate(item.before);reply.after=hydrate(item.after);observations.append(reply)
		var frozen:=digest([before,observations]);var result:=Kernel.execute(before,row.operation,row.args,observations)
		check(not result.ok and str(result.reason).ends_with("division_fault") and int(row.actual_native_process_returncode)==-8 and not row.expected_complete_native_context_after_available,"Runtime rejects actual original SIGFPE domains without a fabricated after-state")
		check(digest([before,observations])==frozen,"Fault rejection leaves every input owner and witness private")
func run()->void:
	directed_controls()
	var doc:Dictionary={};var sources:Dictionary={}
	if FileAccess.file_exists(FIXTURE):
		doc=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));check(FIXTURE_SHA==FileAccess.get_sha256(FIXTURE),"Native fixture immutable SHA is current");buffers=doc.buffer_pool;native_controls(doc)
	else:check(false,"Native fixture pending; directed controls alone are not full parity")
	for path:String in ["scripts/source_mission_expression.gd","scripts/source_global_rng.gd","tests/test_source_mission_expression.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if not doc.is_empty():
		for path:String in doc.source_dependencies_sha256:sources[path]=FileAccess.get_sha256("res://"+path)
		sources[FIXTURE.trim_prefix("res://")]=FileAccess.get_sha256(FIXTURE)
	for name:String in ["instruction-proof.json","source-procedures.asm","expression-native.s","expression-support.c"]:
		var path:String=PROOF.trim_prefix("res://")+name
		if FileAccess.file_exists("res://"+path):sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Kernel.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"provider_calls":provider_calls,"native_fixture_pending":doc.is_empty(),"sources":sources,"Main_integrated":false,"full_mission_VM_executed":false},"\t")+"\n");file.close()
	print("SOURCE MISSION EXPRESSION TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
