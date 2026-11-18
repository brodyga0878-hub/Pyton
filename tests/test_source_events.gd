extends SceneTree
const Events=preload("res://scripts/source_events.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_events_native.json"
const FIXTURE_SHA:="eb7bc02bc0d8ae9abbc8fd43149acf7742a79c11a31e6d7a44ffb1698a4bb2c5"
const REPORT:="res://build/current-test-reports/source-events.json"
var checks:=0
var failures:=0
var native_cases:=0
var dependencies:Dictionary={}
var buffer_pool:Dictionary={}
var hydrated:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<25:push_error(message)
func bytes(count:int)->PackedByteArray:
	var result:=PackedByteArray();result.resize(count);return result
func context()->Dictionary:return {"root":bytes(16384),"bank":bytes(38986),"event_registers":bytes(284),"scratch_words":bytes(32),"arena":bytes(5400),"temporary_event_index_s32":0,"tree_root_u32":0,"nodes":{},"next_node_id_u32":1,"task_variables":{},"next_variable_id_u32":1,"definitions":{"0":{"descriptor_ref_u32":0x101,"cleanup_instruction_u32":0x1234,"variable_words_u32":4}}}
func key(first:int,callback:int=100,arg:int=0)->Array:return [first,0,0,callback,arg,0]
func insert(state:Dictionary,value:Array)->Dictionary:return Events.execute(state,"F44",value).context_after
func json_value(value:Variant)->Variant:
	if value is PackedByteArray:return value.hex_encode()
	if value is Dictionary:
		var result:Dictionary={}
		for field:Variant in value:result[field]=json_value(value[field])
		return result
	if value is Array:
		var result:Array=[]
		for entry:Variant in value:result.append(json_value(entry))
		return result
	return value
func complete(state:Dictionary,operation:String,args:Array=[],mutator:Callable=Callable())->Dictionary:
	var observations:Array=[]
	for step in range(257):
		var result:=Events.execute(state,operation,args,observations)
		if result.get("ok",false) or not result.get("pending") is Dictionary:return {"result":result,"observations":observations}
		var pending:Dictionary=result.pending;var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0}
		if row.kind=="F53":row.after.arena.encode_u32(int(row.args[0])*36,1)
		if mutator.is_valid():mutator.call(row,step)
		observations.append(row)
	return {"result":{"ok":false,"reason":"test_boundary_limit"},"observations":observations}
func reentrant(row:Dictionary,step:int)->void:
	if row.kind!="event_callback" or step!=0:return
	var actions:Array=[{"operation":"F45","args":[22,0,7,200,20,2]},{"operation":"F44","args":[22,0,7,300,30,3]}]
	var changed:Dictionary=row.after
	for action:Dictionary in actions:changed=Events.execute(changed,action.operation,action.args).context_after
	row.after=changed;row["registry_actions"]=actions;row.after.event_registers.encode_u32(48,0x76543210);row.after.bank[100]=17;row.after.temporary_event_index_s32=-5;row.after.scratch_words[0]=77
func standalone()->void:
	var state:=context();var original:=var_to_bytes(state)
	var result:=Events.compare_f42([0xffffffff,0,0,0,0,0],[0,0,0,0,0,0])
	check(result.ok and result.return_s32==-1,"F42 compares the signed32 wrapped difference rather than unsigned ordering")
	result=Events.compare_f42([1,2,3,0xffffffff,4,5],[1,2,3,0,4,5]);check(result.return_s32==-1,"Callback word is the final F42 discriminator after target arguments")
	result=Events.compare_f43([0x80000000,0,0],[0,0,0]);check(result.return_s32==-0x80000000,"F43 preserves the exact INT_MIN wrapped difference")
	for value in [20,10,30,5,15,12,17]:state=insert(state,key(value))
	result=Events.execute(state,"F45",key(20));state=result.context_after
	check(result.ok and int(state.tree_root_u32)==7 and not state.nodes.has("1") and state.nodes["7"].key_u32[0]==17,"F45 replaces a two-child node by the same rightmost-left predecessor identity")
	check(state.nodes["5"].right_u32==0 and state.nodes["7"].left_u32==2 and state.nodes["7"].right_u32==3,"Predecessor detachment precedes grafting its left/right links")
	state=context()
	for index in range(3):state=insert(state,key(1))
	check(state.tree_root_u32==1 and state.nodes["1"].right_u32==2 and state.nodes["2"].right_u32==3,"Equal registrations remain distinct and are inserted to the right")
	result=Events.execute(state,"F45",key(1));check(result.ok and result.context_after.tree_root_u32==2 and result.context_after.nodes.size()==2,"F45 removes only the first matching duplicate found by source search")
	state=context();state=insert(state,[22,0,7,100,10,1]);state=insert(state,[22,0,7,200,20,2]);var next_id:int=state.next_node_id_u32
	result=Events.execute(state,"F46",[22,0,7]);check(result.ok and result.captured_callbacks==[[100,10,1],[200,20,2]] and result.context_after.next_node_id_u32==next_id,"F46 copies callback/argument triples in-order without consuming persistent tree IDs")
	var dispatched:=complete(state,"F48",[22,0,7],Callable(self,"reentrant"));result=dispatched.result
	check(result.ok and result.captured_callbacks==[[100,10,1],[200,20,2]] and dispatched.observations.size()==2,"Dispatch uses its pre-callback snapshot even after a callback deletes a later registration")
	check(dispatched.observations[1].args==[200,20,2] and result.context_after.nodes.size()==2,"New registration waits for a later dispatch while a captured removed callback still executes")
	check(result.context_after.event_registers.decode_u32(48)==0x76543210 and result.context_after.bank[100]==17 and result.context_after.temporary_event_index_s32==-5 and result.context_after.scratch_words[0]==77,"VM continuation shares declared event, bank, scratch and temporary-index owners")
	var next:=complete(result.context_after,"F48",[22,0,7]);check(next.result.ok and next.result.captured_callbacks==[[100,10,1],[300,30,3]],"A following dispatch sees the newly committed tree")
	var null_callback:=insert(context(),[1,2,3,0,4,5]);check(Events.execute(null_callback,"F46",[1,2,3]).ok and not Events.execute(null_callback,"F48",[1,2,3]).ok,"A source null callback word remains opaque in registrations and snapshots but cannot become a successful call")
	var decoded:Variant=Events.decode_observations(JSON.parse_string(JSON.stringify(json_value(dispatched.observations))))
	check(decoded is Array and Events.execute(state,"F48",[22,0,7],decoded).ok,"Reentrant registry actions and full raw owners survive cold JSON observations")
	state=context();state.arena.encode_u32(0,7);result=Events.execute(state,"F48",[1,2,3])
	check(result.ok and result.source_order==["F48"] and result.context_after.arena==state.arena,"A missing F48 key never starts F54, even with an otherwise unsupported active priority")
	check(not Events.execute(state,"F54").ok,"Actual F54 rejects source priorities above6 that would loop indefinitely")
	state=context();state.arena.encode_u16(6,65535);result=Events.execute(state,"F51",[0,0xdeadbeef])
	check(result.ok and result.allocated_slot_s32==0 and result.allocated_handle_u32==0 and result.context_after.arena.decode_u32(0)==4,"Slot0 generationFFFF wraps to a valid allocated task with packed handle0")
	check(result.pointer_return_defined and not result.scalar_return_defined and result.allocation_succeeded and result.pointer_result_kind=="logical_task_slot","F51 has a defined normalized non-null task pointer without inventing scalar EAX or exposing a host address")
	check(result.context_after.task_variables["1"].decode_u32(0)==0 and result.context_after.task_variables["1"].decode_u32(4)==0xdeadbeef and result.context_after.task_variables["1"].slice(8)==PackedByteArray([165,165,165,165,165,165,165,165]),"F51 writes only the defined first8 environment bytes and retains the reviewed fresh-allocation fill")
	check(result.context_after.arena.decode_u32(12)==0xffffffff and result.context_after.arena.decode_u32(20)==0xffffffff and result.context_after.arena.decode_u32(28)==0x101,"Task locals, descriptor token and cursor fields preserve original initialization widths")
	state=context();state.definitions={};state.next_variable_id_u32=513
	for slot in range(150):state.arena.encode_u32(slot*36,1)
	result=Events.execute(state,"F51",[0,1]);check(result.ok and result.allocated_slot_s32==-1 and result.context_after==state,"A full arena returns allocation failure without dereferencing a missing definition or consuming a variable ID")
	state=context()
	for slot in range(3):state=Events.execute(state,"F51",[0,slot]).context_after
	state.arena.encode_u32(0,4);state.arena.encode_u32(36,5);state.arena.encode_u32(72,6)
	dispatched=complete(state,"F54");result=dispatched.result
	check(result.ok and dispatched.observations.size()==2 and dispatched.observations[0].kind=="F41" and dispatched.observations[0].args==[1,0x1234] and dispatched.observations[1].kind=="F53" and dispatched.observations[1].args[0]==0,"F54 drains highest signed priority first and enters cleanup at state6 before its VM callback")
	check(dispatched.observations[0].before.arena.decode_u32(36)==6 and not dispatched.observations[0].before.task_variables.has("3"),"Priority6 release precedes priority5 cleanup and the cleanup snapshot already exposes state6")
	check(result.context_after.task_variables.size()==1 and result.context_after.task_variables.has("1") and result.context_after.arena.decode_u32(68)==2,"Source release removes variable ownership while leaving the inactive task's stale environment token intact")
	state=context();state.event_registers.fill(255);state.scratch_words.fill(165);dispatched=complete(state,"F55");result=dispatched.result
	check(result.ok and dispatched.observations.size()==1 and dispatched.observations[0].kind=="F52" and dispatched.observations[0].args==[0,0,0,0],"F55 exposes a required explicit initialization continuation before running the scheduler")
	check(result.context_after.scratch_words==bytes(32) and result.context_after.event_registers==state.event_registers,"F55 zeros the separate8 scratch words at D8550..8557 and preserves all71 event registers")
	state=context()
	for slot in range(3):state=Events.execute(state,"F51",[0,slot]).context_after
	state.arena.encode_u32(0,1);state.arena.encode_u32(36,0xffffffff);state.arena.encode_u32(72,6);state=insert(state,key(2));result=Events.execute(state,"F56")
	check(result.ok and result.context_after.nodes.is_empty() and result.context_after.tree_root_u32==0 and result.context_after.task_variables.keys()==["2"],"F56 frees only positive task states and then clears the original registration tree")
	check(result.context_after.arena.decode_u32(32)==1 and result.context_after.arena.decode_u32(36)==0xffffffff,"F56 retains source task fields and negative inactive status bits")
	state=context();state.next_node_id_u32=513;check(not Events.execute(state,"F44",key(1)).ok,"The bounded monotonic logical tree allocator rejects exhaustion atomically")
	state=context();var frozen:=var_to_bytes(state)
	for bad:Variant in [null,true,0,"context",[],{}]:check(not Events.execute(bad,"F50").ok,"Malformed source event context rejects")
	for operation:Variant in [null,true,0,"F41","F52","F49","unknown",[]]:check(not Events.execute(state,operation).ok,"Unsupported or unsafe direct worker entry rejects")
	for field:String in Events.CONTEXT_KEYS:
		var broken:=state.duplicate(true);broken.erase(field);check(not Events.execute(broken,"F50").ok,"Every event context owner is required: "+field)
	for field:String in Events.BYTE_COUNTS:
		var broken:=state.duplicate(true);broken[field]=bytes(int(Events.BYTE_COUNTS[field])-1);check(not Events.execute(broken,"F50").ok,"Truncated raw event owner rejects: "+field)
	var broken:=insert(state,key(1));broken.nodes["1"].left_u32=1;check(not Events.execute(broken,"F50").ok,"Logical tree cycles reject before any source operation")
	broken=state.duplicate(true);broken.task_variables={"01":bytes(8)};check(not Events.execute(broken,"F54").ok,"Noncanonical variable IDs cannot enter cold owners")
	broken=state.duplicate(true);broken.definitions["0"].variable_words_u32=1;check(not Events.execute(broken,"F51",[0,0]).ok,"Too-small source environments are unsupported rather than silently enlarged")
	check(var_to_bytes(state)==frozen and not original.is_empty(),"Rejected calls preserve all raw caller owners")
func buffer(reference:String)->PackedByteArray:
	if hydrated.has(reference):return hydrated[reference].duplicate()
	var entry:Dictionary=buffer_pool[reference];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(raw)
	check(raw.size()==int(entry.byte_count) and hasher.finish().hex_encode()==reference,"Native event owner buffer retains its exact bytes and SHA")
	hydrated[reference]=raw.duplicate();return raw
func hydrate_context(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true)
	for field:String in Events.BYTE_COUNTS:result[field]=buffer(str(value[field]))
	for key:String in result.task_variables:result.task_variables[key]=buffer(str(value.task_variables[key]))
	return Events._copy_context(result)
func hydrate_observations(value:Array)->Array:
	var result:Array=[]
	for source:Dictionary in value:
		var row:Dictionary={"kind":source.kind,"args":source.args.duplicate(),"before":hydrate_context(source.before),"after":hydrate_context(source.after)}
		if source.has("return_u32"):row["return_u32"]=source.return_u32
		if source.has("registry_actions"):row["registry_actions"]=source.registry_actions.duplicate(true)
		result.append(row)
	return result
func captures(value:Array)->Array:
	var result:Array=[]
	for source:Array in value:
		var row:Array=[]
		for word:Variant in source:row.append(int(word))
		result.append(row)
	return result
func native_controls()->void:
	check(FileAccess.file_exists(FIXTURE),"Independent original event registration/scheduler native fixture exists")
	if not FileAccess.file_exists(FIXTURE):return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Events native fixture pinned to the final original instruction proof")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));buffer_pool=fixture.buffers;dependencies=fixture.source_dependencies_sha256.duplicate(true)
	check(fixture.profile==Events.PROFILE and int(fixture.case_count)==fixture.cases.size(),"Native event kernel profile and actual unique case count are retained")
	check(int(fixture.fresh_process_runs)==3 and int(fixture.reverse_repeat_cases)==int(fixture.case_count) and not fixture.expected_arithmetic_calculated_in_python and fixture.all_external_results_explicit,"Event results are measured by guarded original procedures and explicit callback evidence")
	for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Native event proof dependency remains pinned: "+path)
	var operations:Dictionary={};var callbacks:=0;var carried:=0
	for row:Dictionary in fixture.cases:
		var state:=hydrate_context(row.context_before);var observations:=hydrate_observations(row.observations);var original:=var_to_bytes([state,observations]);native_cases+=1
		var result:=Events.execute(state,row.operation,row.args,observations)
		check(result.ok,"Original event operation is supported: "+str(row.name))
		if not result.ok:continue
		var expected:=hydrate_context(row.expected.context_after)
		check(Events._same_context(result.context_after,expected),"All raw external owners, logical tree IDs, task fields and variable bytes equal native execution: "+str(row.name))
		check(result.source_order==row.expected.source_order and int(result.observations_used)==int(row.expected.observations_used),"Recursive source worker and callback order matches native execution: "+str(row.name))
		check(result.captured_callbacks==captures(row.expected.captured_callbacks),"Immutable source snapshot retains callback triples in exact order: "+str(row.name))
		check(bool(result.return_defined)==bool(row.expected.return_defined),"Defined scalar return is distinguished from source void EAX: "+str(row.name))
		if row.expected.return_defined:check(int(result.return_u32)==int(row.expected.return_u32) and int(result.return_s32)==int(row.expected.return_s32),"Source comparator returns exact signed and unsigned wrapped bits: "+str(row.name))
		if row.operation=="F51":check(int(result.allocated_slot_s32)==int(row.expected.allocated_slot_s32) and int(result.allocated_handle_u32)==int(row.expected.allocated_handle_u32),"Defined task pointer/NULL and packed handle remain distinct: "+str(row.name))
		check(result.requests==observations,"Every typed native callback and nested registry action is matched: "+str(row.name))
		check(var_to_bytes([state,observations])==original,"Event kernel does not mutate source caller buffers or evidence: "+str(row.name))
		operations[row.operation]=true;callbacks+=observations.size()
		if row.get("carries_previous_native_state",false):carried+=1
	check(operations.size()==Events.OPERATIONS.size(),"All supported source event and task entries have independent native controls")
	check(callbacks>0 and carried>=18,"Native callbacks and dependent logical allocator/task generations are exercised")
func run()->void:
	standalone();native_controls();var sources:Dictionary={}
	for path:String in ["scripts/source_events.gd","scripts/source_frame_dispatch.gd","tests/test_source_events.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if FileAccess.file_exists(FIXTURE):sources[FIXTURE.trim_prefix("res://")]=FileAccess.get_sha256(FIXTURE)
	for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"native_cases":native_cases,"sources":sources,"profile":Events.PROFILE,"Main_integrated":false,"full_F41_VM_executed":false},"\t"));file.close()
	print("SOURCE EVENTS TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
