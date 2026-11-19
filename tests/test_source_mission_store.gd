extends SceneTree
const Store=preload("res://scripts/source_mission_store.gd")
const Expr=preload("res://scripts/source_mission_expression.gd")
const Programs=preload("res://scripts/source_mission_programs.gd")
const FIXTURE:="res://tests/fixtures/source_mission_store_native.json"
const FIXTURE_SHA:="4c1415e5dc44c16290925a5b3e722c0c4d318bdfa00cf9440188c79ded42c9fb"
const PROOF:="res://validation/mission-tasks-2026-11-19/store-native-proof/"
const REPORT:="res://build/current-test-reports/source-mission-store.json"
var checks:=0
var failures:=0
var native_cases:=0
var provider_calls:=0
var pool:Dictionary={}
var hydrated:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<20:push_error(message)
func bytes(count:int,fill:int=0)->PackedByteArray:
	var out:=PackedByteArray();out.resize(count);out.fill(fill);return out
func word(value:int)->PackedByteArray:
	var out:=bytes(4);out.encode_u32(0,value&0xffffffff);return out
func literal(value:int)->PackedByteArray:return PackedByteArray([2])+word(value)
func program(selector:int,operands:Array=[])->PackedByteArray:
	var out:=PackedByteArray([selector])
	for operand:PackedByteArray in operands:out.append_array(operand)
	return out
func context(code:PackedByteArray=PackedByteArray([0]))->Dictionary:
	var root:=bytes(16384);root.encode_u32(0xc8,116+2*338);root.encode_u32(0xcc,116+3*338);root.encode_u32(0x118,20);root.encode_u32(0x120,12)
	var tail:=bytes(6160);tail.encode_u32(0x180c,1)
	return {"root":root,"root_tail":tail,"bank":bytes(38986),"event_registers":bytes(284),"module_globals":bytes(40),"task_variables":bytes(32),"program":code.duplicate(),"ip_u32":0,"module_global_offset_u32":8,"temporary_event_index_s32":-7,"task_slot_u32":149,"descriptor_ref_u32":0x48b238,"market_buffer":bytes(308)}
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
func complete(before:Dictionary,value:int,policy:Callable=Callable())->Dictionary:
	var replies:Array=[]
	for attempt in range(257):
		var result:=Store.execute(before,value&0xffffffff,replies)
		if result.get("ok",false):return {"ok":true,"result":result,"observations":replies}
		if not result.get("pending") is Dictionary:return {"ok":false,"result":result,"observations":replies}
		var pending:Dictionary=result.pending
		var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0,"input_hex":"","output_hex":""}
		if pending.kind=="F31":
			var expression:Dictionary=Expr.execute(Store._expression_view(pending.before))
			if not expression.get("ok",false):return {"ok":false,"result":expression,"observations":replies}
			for key:String in Expr.CONTEXT_KEYS:row.after[key]=expression.context_after[key]
			row.return_u32=expression.return_u32
		if policy.is_valid():policy.call(row,replies.size())
		replies.append(row)
	return {"ok":false}
func directed_controls()->void:
	var active:=[3,4,5,6,31,35,36,37,48,56,61,62,65,66]
	for selector in range(256):
		if selector in active:continue
		var raw:=context(program(selector));var original:=digest(raw);var result:=Store.execute(raw,0xdeadbeef)
		check(result.ok and result.context_after.ip_u32==1 and result.source_order==["F37"],"Default source selector consumes only its byte: %d"%selector)
		check(digest(raw)==original and result.context_after.root==raw.root and result.context_after.bank==raw.bank,"Default selector keeps all caller owners private")
	var raw:=context(program(3,[word(15)]));var original:=digest(raw);var result:=Store.execute(raw,0x12345678)
	check(not result.ok and result.pending.kind=="F22" and result.pending.args==[15,0x12345678] and result.pending.before.ip_u32==5,"Global lvalue reads its full immediate then calls F22")
	check(digest(raw)==original and result.pending.before.root==raw.root,"Store does not invent the setter's body before its continuation")
	var global:=complete(raw,0x12345678,func(row:Dictionary,_index:int):
		if row.kind=="F22":row.after.root.encode_u32(0x124,0x12345678))
	check(global.ok and global.result.context_after.root.decode_u32(0x124)==0x12345678 and not global.result.return_defined,"A matched global continuation publishes only its supplied source owner mutation")
	var event:=complete(context(program(4,[word(70)])),0x76543210)
	check(event.ok and event.observations.size()==1 and event.observations[0].kind=="F34" and event.observations[0].args==[70,0x76543210],"Event lvalue delegates exactly to F34")
	raw=context(program(5,[word(1)]));result=Store.execute(raw,0xfedcba98)
	check(not result.ok and result.pending.kind=="F48" and result.pending.args==[3,int(raw.descriptor_ref_u32),1],"Static store emits descriptor identity and original index")
	check(result.pending.before.module_globals.decode_u32(12)==0xfedcba98 and raw.module_globals.decode_u32(12)==0,"Static word is written before notification, in a private owner")
	var static_done:=complete(raw,0xfedcba98,func(row:Dictionary,_index:int):
		if row.kind=="F48":row.after.module_globals.encode_u32(12,33))
	check(static_done.ok and static_done.result.context_after.module_globals.decode_u32(12)==33,"Event callback changes survive the completed static assignment")
	raw=context(program(6,[word(1)]));result=Store.execute(raw,0xaabbccdd)
	check(not result.ok and result.pending.args==[4,Store.TASK_BASE+149*36,1] and result.pending.before.task_variables.decode_u32(4)==0xaabbccdd,"Local store uses physical task identity, not a packed handle")
	for item:Array in [[31,21,0x10e0],[35,10,0x10f8],[48,17,0x184]]:
		var done:=complete(context(program(int(item[0]),[literal(3)])),0x89abcdef)
		check(done.ok and done.observations.size()==2 and done.observations[1].args==[int(item[1]),0,3],"Indexed owner writes notify the correct source event")
		if done.ok:
			var owner:PackedByteArray=done.result.context_after.root if int(item[0])==48 else done.result.context_after.root_tail
			check(owner.decode_u32(int(item[2])+12)==0x89abcdef,"Indexed store retains full uint32 value in its exact owner")
		for index in [-1,6]:
			var skipped:=complete(context(program(int(item[0]),[literal(index)])),91)
			check(skipped.ok and skipped.observations.size()==1,"Signed out-of-range six-word index emits no event")
	raw=context(program(36,[literal(2)]));var body:=116+2*338
	var flag:=complete(raw,77,func(row:Dictionary,_index:int):
		if row.kind=="F31":row.after.bank.encode_u32(body+0xa0,123))
	check(flag.ok and flag.observations[1].kind=="F441" and flag.observations[1].args==[2,77,123],"F441 uses the body word reread after expression side effects")
	var counter:Dictionary={"add":0,"remove":0}
	var equipment_policy:=func(row:Dictionary,_index:int):
		if row.kind=="F392":row.return_u32=2
		elif row.kind=="F390":counter.add+=1;row.return_u32=1 if int(counter.add)==2 else 0
		elif row.kind=="F391":counter.remove+=1;row.return_u32=1 if int(counter.remove)==2 else 0
	var added:=complete(context(program(37,[literal(2),literal(150)])),8,equipment_policy)
	check(added.ok and int(counter.add)==2 and added.observations[2].args==[2,50],"Equipment add loop stops at first nonzero service return and preserves item transform")
	var removed:=complete(context(program(37,[literal(2),literal(150)])),0,equipment_policy)
	check(removed.ok and int(counter.remove)==2,"Equipment remove loop advances the negative difference until failure")
	var unchanged:=complete(context(program(37,[literal(2),literal(150)])),2,equipment_policy)
	check(unchanged.ok and unchanged.observations.size()==3,"Equal equipment quantity still queries source count but does not mutate")
	for sample:Array in [[20,12,15,15,20],[18,12,15,13,18],[20,25,15,2,20],[20,12,0xffffffff,0,5]]:
		raw=context(program(37,[literal(2),literal(1003)]));raw.root.encode_u16(0x134+6,7);raw.root.encode_u32(0x118,int(sample[0]));raw.root.encode_u32(0x120,int(sample[1]));var done:=complete(raw,int(sample[2]))
		check(done.ok and done.result.context_after.root.decode_u16(0x134+6)==int(sample[3]) and done.result.context_after.root.decode_u32(0x120)==int(sample[4]),"Cargo source signed clamp includes negative target and over-capacity correction")
	raw=context(program(37,[literal(3),literal(1003)]));raw.root.encode_u16(0x13a,7);var nonplayer:=complete(raw,15)
	check(nonplayer.ok and nonplayer.result.context_after.root==raw.root,"Cargo store rejects another body without changing player totals")
	var direct:=complete(context(program(56,[literal(2)])),0xdeadbeef)
	check(direct.ok and direct.result.context_after.bank.decode_u32(body+0xa0)==0xdeadbeef and direct.observations.size()==1,"Direct body-A0 store emits no extra event")
	var model:=complete(context(program(61,[literal(2)])),153)
	check(model.ok and model.observations[1].kind=="F36" and model.observations[1].args==[2,153],"Model lvalue calls F36, not the different F1533 factory")
	raw=context(program(62,[literal(2)]));raw.bank.encode_u32(body+0x82,149);var byte_ff:=complete(raw,0x12345678)
	check(byte_ff.ok and byte_ff.result.context_after.bank[body+0xff]==0x78 and byte_ff.observations[1].args==[23,0,2],"Actual DOS selector62 stores and notifies even for null model149")
	check(byte_ff.ok and not "F1538" in byte_ff.result.source_order,"Later JJFFE physical-presence gate is absent from original DOS")
	var byte_fe:=complete(context(program(65,[literal(2)])),0x12345678)
	check(byte_fe.ok and byte_fe.result.context_after.bank[body+0xfe]==0x78 and byte_fe.observations.size()==1,"Body-FE assignment truncates to byte without notification")
	var market_policy:=func(row:Dictionary,_index:int):
		if row.kind=="F649":row.return_u32=1;row.after.root.encode_u32(0x40,0x1234);row.after.market_buffer.encode_u32(44,12)
	var market:=complete(context(program(66,[literal(0x12345678),literal(1005)])),0xabcdef12,market_policy)
	check(market.ok and market.result.context_after.market_buffer.decode_u32(44)==0xabcdef12 and market.observations[3].args==[24,0x12345678,1005],"Market write persists in its pointed owner before exact event24")
	var market_skip:=complete(context(program(66,[literal(9),literal(999)])),77,market_policy)
	check(market_skip.ok and market_skip.observations.size()==3 and market_skip.result.context_after.root.decode_u32(0x40)==0x1234 and market_skip.result.context_after.market_buffer.decode_u32(44)==12,"Market lookup occurs before index rejection and preserves its visible effects")
	raw=context(program(6,[word(1)]));var done:=complete(raw,42)
	var transported:Variant=Store.decode_observations(JSON.parse_string(JSON.stringify(encode(done.observations))))
	check(transported is Array and Store.execute(raw,42,transported).ok,"A matched local-store continuation survives JSON transport")
	for malformed:Variant in [null,true,3,"bad",[],{}]:check(not Store.execute(malformed,0).ok,"Malformed store owner rejects")
	for value:Variant in [-1,0x100000000,null,true,0.25,INF,NAN]:check(not Store.execute(context(),value).ok,"Store value requires exact uint32")
	for key:String in Store.CONTEXT_KEYS:
		var bad:=context();bad.erase(key);check(not Store.execute(bad,1).ok,"Missing store owner rejects: "+key)
	for key:String in ["packed_handle","root_copy","task_record"]:
		var bad:=context();bad[key]=0;check(not Store.execute(bad,1).ok,"Undeclared duplicate owner rejects")
	for selector in [3,4,5,6]:check(not Store.execute(context(program(selector)),1).ok,"Truncated immediate rejects without reading beyond source program")
	for selector in [5,6]:check(not Store.execute(context(program(selector,[word(0xffffffff)])),1).ok,"Out-of-range raw local/static index rejects without fabricated writes")
	var no_global:=context(program(5,[word(0)]));no_global.module_global_offset_u32=0xffffffff;check(not Store.execute(no_global,1).ok,"Unbound static storage is a rejected source fault profile")
	var wrong:Array=done.observations.duplicate(true);wrong[0].before.root[0]^=1;check(not Store.execute(raw,42,wrong).ok,"Wrong callback-before bytes cannot resume")
	wrong=done.observations.duplicate(true);wrong[0].after.ip_u32=0;check(not Store.execute(raw,42,wrong).ok,"A registry provider cannot replace the lvalue cursor")
	wrong=done.observations.duplicate(true);wrong.append(wrong[0]);check(not Store.execute(raw,42,wrong).ok,"Unused observations do not silently succeed")
	var cyclic:Dictionary=context();cyclic.program=cyclic
	check(Store.decode_context(cyclic).is_empty() and not Store.execute(cyclic,1).ok and Store._copy_context(cyclic).is_empty(),"Cyclic malformed owner rejects before duplication")
	cyclic.program=null;cyclic.clear()
	var cycle:Array=[];cycle.append(cycle)
	check(Store.decode_observations(cycle)==null and not Store.execute(context(),1,cycle).ok,"Cyclic malformed replies reject before duplication")
	cycle.clear()
func buffer(key:String)->PackedByteArray:
	if hydrated.has(key):return hydrated[key].duplicate()
	var entry:Dictionary=pool[key];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE);var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(raw)
	check(raw.size()==int(entry.byte_count) and h.finish().hex_encode()==key,"Independent native owner pool validates bytes")
	hydrated[key]=raw.duplicate();return raw
func hydrate(value:Dictionary)->Dictionary:
	var raw:Dictionary=value.duplicate(true)
	for key:String in Store.CONTEXT_KEYS:
		if raw[key] is Dictionary and raw[key].has("buffer_sha256"):raw[key]=buffer(str(raw[key].buffer_sha256))
	return Store.decode_context(raw)
func native_controls(doc:Dictionary)->void:
	check(doc.profile==Store.PROFILE and int(doc.case_count)==doc.cases.size(),"Native store profile and case inventory agree")
	check(not doc.expected_arithmetic_calculated_in_python,"Expected full owner state comes from original instructions")
	if doc.has("fresh_cohort_runs"):check(int(doc.fresh_cohort_runs)==3 and int(doc.reverse_repeat_cases)==doc.cases.size(),"Fresh and reverse native streams are retained")
	check(int(doc.whole_procedure_count)==3 and int(doc.whole_instruction_count)==351,"Whole F20/F37/F1532 code regions remain independently proved")
	for pair:Array in [["instruction-proof.json","instruction_proof_sha256"],["source-procedures.asm","source_procedures_sha256"],["store-native.s","native_assembly_sha256"],["store-support.c","native_support_sha256"]]:check(FileAccess.get_sha256(PROOF+pair[0])==doc[pair[1]],"Actual original code and reviewed host ABI source are pinned")
	var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PROOF+"instruction-proof.json"))
	check(proof.all_code_regions_equal and proof.all_source_label_instruction_boundaries_equal and proof.all_inline_table_bytes_and_targets_equal,"Whole proof includes code boundaries and both inline tables")
	check(not proof.unmodified_JJFFE_tables_all_equal and proof.table_target_order_same_as_JJFFE,"Source selector ordering is retained while DOS branch addresses reflect its different code body")
	check(int(proof.root_fields.DATA_008889)==0x118 and int(proof.root_fields.DATA_008891)==0x120,"Cargo capacity and used words are independently bound to actual DOS operands")
	check(doc.selector_table_u8.size()==67 and doc.jump_target_symbols.size()==18 and doc.all_256_byte_selectors_tested,"Actual selector and jump-table extents remain explicit")
	for index in range(67):check(int(doc.selector_table_u8[index])==int(Store.SELECTOR_MAP[index]),"Runtime selector map matches its proved original byte")
	check(doc.source_code_variants.size()==1 and int(doc.source_code_variants[0].selector_u32)==62 and doc.source_code_variants[0].actual_DOS_unconditional_FF_store and doc.source_code_variants[0].JJFFE_only_physical_spec_gate,"The DOS selector62 behavior is not replaced by the later JJFFE gate")
	for path:String in doc.get("source_dependencies_sha256",{}):check(FileAccess.get_sha256("res://"+path)==doc.source_dependencies_sha256[path],"Native store dependency current: "+path)
	var selectors:Dictionary={};var actual_cases:=0;var shared_steps:=0;var edges:=0;var previous:Dictionary={};var shared_program:=PackedByteArray()
	var resources:=Programs.load_original();var original_program:=Programs.read(resources,"mission",0,57560)
	for row:Dictionary in doc.cases:
		var before:=hydrate(row.context_before);var expected:=hydrate(row.expected.context_after);var replies:Array=[]
		for item:Dictionary in row.observations:
			var reply:=item.duplicate(true);reply.before=hydrate(item.before);reply.after=hydrate(item.after);replies.append(reply)
		check(not before.is_empty() and not expected.is_empty(),"Native full store owners decode: "+str(row.name))
		if before.is_empty() or expected.is_empty():continue
		selectors[int(before.program[int(before.ip_u32)])]=true
		var frozen:=digest([before,replies]);var result:=Store.execute(before,int(row.value_u32),replies)
		check(result.ok,"Whole DOS store executes: "+str(row.name))
		if not result.ok:continue
		for field:String in Store.CONTEXT_KEYS:check(result.context_after[field]==expected[field],"Native store owner matches "+field+": "+str(row.name))
		check(result.source_order==row.expected.source_order and int(result.observations_used)==replies.size(),"Literal, expression, lookup and callback order matches")
		check(not result.return_defined and result.return_u32==0 and result.void_return_register_ignored,"Void store return does not become an invented scalar")
		check(digest([before,replies])==frozen,"Store request and callback inputs remain private")
		if row.has("source_resource"):
			actual_cases+=1;var module:=Programs.module(resources,int(row.source_resource.module_index_u32))
			check(before.program==original_program and int(before.ip_u32)==int(row.source_resource.lvalue_entry_offset_u32) and int(before.ip_u32)==int(module.argument_targets_offset_u32),"Real argument-target cases read exact original DOS bytes at the descriptor's actual stream")
			check(before.task_variables.size()==int(module.variable_words_u32)*4 and int(before.module_global_offset_u32)==int(module.global_owner_offset_u32) and int(before.descriptor_ref_u32)==int(Programs.REGION_LAYOUT.mission[0])+int(module.descriptor_offset_u32),"Real target cases retain declared local storage and original static/descriptor binding")
		if row.get("shared_owner_sequence",false):
			check(int(row.shared_step_u32)==shared_steps,"Dependent native stores remain in their original sequence")
			if not previous.is_empty():
				check(Store._same_context(before,previous),"Every owner of the next store equals the actual preceding after-state");edges+=1
			else:shared_program=before.program.duplicate()
			check(before.program==shared_program and result.context_after.program==shared_program,"Dependent stores keep the same immutable program witness")
			previous=result.context_after.duplicate(true);shared_steps+=1
		native_cases+=1;provider_calls+=replies.size()
	check(selectors.size()==256,"All byte selectors, including source table holes, execute against native controls")
	check(actual_cases==int(doc.actual_DOS_resource_assignment_cases) and actual_cases==35,"Every actual DOS first-argument assignment target is checked")
	check(shared_steps==int(doc.dependent_native_transition_count) and edges==int(doc.shared_continuation_edges) and shared_steps==5 and edges==4,"Five native transitions carry the complete thirteen-owner state through four edges")
	check(int(doc.get("fault_case_count_separate",0))==1 and doc.get("original_fault_domains",[]).size()==1,"Original SIGSEGV control is separate from the normal native case bank")
	for row:Dictionary in doc.get("original_fault_domains",[]):
		var before:=hydrate(row.context_before);var replies:Array=[]
		for item:Dictionary in row.observations:
			var reply:=item.duplicate(true);reply.before=hydrate(item.before);reply.after=hydrate(item.after);replies.append(reply)
		var frozen:=digest([before,replies]);var result:=Store.execute(before,int(row.value_u32),replies)
		check(not result.ok and not result.has("context_after") and int(row.actual_native_process_returncode)==-11 and int(row.fresh_native_process_runs)==3 and not row.expected_complete_native_context_after_available,"Actual original null-static-pointer SIGSEGV rejects without fabricated after-state")
		check(digest([before,replies])==frozen,"Fault-profile rejection leaves all caller owners private")
func run()->void:
	directed_controls()
	var doc:Dictionary={};var sources:Dictionary={}
	if FileAccess.file_exists(FIXTURE):
		doc=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));check(FIXTURE_SHA==FileAccess.get_sha256(FIXTURE),"Independent store fixture SHA is pinned");pool=doc.get("buffer_pool",{});native_controls(doc)
	else:check(false,"Native store fixture pending; directed controls alone are not parity")
	for path:String in ["scripts/source_mission_store.gd","scripts/source_mission_expression.gd","scripts/source_mission_programs.gd","tests/test_source_mission_store.gd","tools/rebuild_source_mission_store_native.py"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if not doc.is_empty():
		sources[FIXTURE.trim_prefix("res://")]=FileAccess.get_sha256(FIXTURE)
		for path:String in doc.get("source_dependencies_sha256",{}):sources[path]=FileAccess.get_sha256("res://"+path)
	for name:String in ["instruction-proof.json","source-procedures.asm","store-native.s","store-support.c"]:
		var path:String=PROOF.trim_prefix("res://")+name
		if FileAccess.file_exists("res://"+path):sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Store.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"provider_calls":provider_calls,"native_fixture_pending":doc.is_empty(),"actual_DOS_resource_assignment_cases":int(doc.get("actual_DOS_resource_assignment_cases",0)),"dependent_native_transition_count":int(doc.get("dependent_native_transition_count",0)),"fault_case_count_separate":int(doc.get("fault_case_count_separate",0)),"sources":sources,"Main_integrated":false,"full_mission_VM_executed":false},"\t")+"\n");file.close()
	print("SOURCE MISSION STORE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
