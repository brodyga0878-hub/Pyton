extends SceneTree
const Services=preload("res://scripts/source_mission_services.gd")
const State=preload("res://scripts/source_mission_services_state.gd")
const Expr=preload("res://scripts/source_mission_expression.gd")
const Guards=preload("res://scripts/source_mission_guards.gd")
const Events=preload("res://scripts/source_events.gd")
const Programs=preload("res://scripts/source_mission_programs.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const FIXTURE:="res://tests/fixtures/source_mission_services_native.json"
const FIXTURE_SHA:="bb7215f3c1d97ba25e96f6fb846a44d39c7cd59fb38cadc179200e9afcee32e7"
const REPORT:="res://build/current-test-reports/source-mission-services.json"
var checks:=0
var failures:=0
var native_cases:=0
var native_fixture_pending:=true
var dependencies:Dictionary={}
var programs:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<30:push_error(message)
func bytes(count:int,fill:int=0)->PackedByteArray:
	var result:=PackedByteArray();result.resize(count);result.fill(fill);return result
func literal(value:int)->PackedByteArray:
	var result:=bytes(5);result[0]=2;result.encode_u32(1,value&0xffffffff);return result
func indexed(token:int,index:int)->PackedByteArray:
	var result:=literal(index);result[0]=token;return result
func binary(token:int,first:PackedByteArray,second:PackedByteArray)->PackedByteArray:
	var result:=PackedByteArray([token]);result.append_array(first);result.append_array(second);return result
func base(program:PackedByteArray=literal(37))->Dictionary:
	var root:=bytes(16384);root.encode_u32(0,0x12345678);root.encode_u32(4,0x121cf7);root.encode_u32(0xc8,116+338);root.encode_u32(0xcc,116+338*2)
	var tail:=bytes(6160);tail.encode_u32(0x180c,1)
	var bank:=bytes(38986);bank[116+338+0x86]=1;bank[116+338*2+0x86]=2
	var arena:=bytes(5400);var slot:=7;var at:=slot*36;var definitions:=Programs.events_definitions(programs)
	arena.encode_u16(at+4,slot);arena.encode_u16(at+6,3);arena.encode_u32(at+24,0);arena.encode_u32(at+28,int(definitions["0"].descriptor_ref_u32));arena.encode_u32(at+32,1)
	var variables:=bytes(int(definitions["0"].variable_words_u32)*4);variables.encode_u32(4,0x11223344)
	return {"root":root,"root_tail":tail,"bank":bank,"event_registers":bytes(284),"module_globals":Programs.initial_module_globals(programs),"program":program.duplicate(),"ip_u32":0,"module_global_offset_u32":0,"temporary_event_index_s32":-7,"scratch_words":bytes(32,0xa5),"arena":arena,"tree_root_u32":0,"nodes":{},"next_node_id_u32":1,"task_variables":{"1":variables},"next_variable_id_u32":2,"definitions":definitions,"task_slot_u32":slot,"program_base_u32":int(Programs.REGION_LAYOUT.mission[0]),"metadata":Programs.read(programs,"expression_metadata",0,1088)}
func same(first:Dictionary,second:Dictionary)->bool:
	for key:String in Services.KEYS:
		if first[key]!=second[key]:return false
	return true
func command(kind:String,operation:String,args:Array=[])->Dictionary:return {"kind":kind,"operation":operation,"args":args}
func registered(context:Dictionary,key:Array)->Dictionary:
	var result:=Events.execute(Services._view(context,Events.CONTEXT_KEYS),"F44",key)
	check(result.ok,"A real F44 registration configures the common event tree")
	return Services._merge_events(context,result.context_after) if result.ok else context
func has_key(context:Dictionary,key:Array)->bool:
	for node:Dictionary in context.nodes.values():
		if node.key_u32==key:return true
	return false
func complete(context:Dictionary,request:Dictionary,mutator:Callable=Callable())->Dictionary:
	var observed:Array=[];var packets:Array=[]
	for step in range(256):
		var result:=Services.execute(context,request,observed,packets)
		if result.get("ok",false) or not result.get("pending") is Dictionary:return {"result":result,"observations":observed,"dependency_packets":packets}
		var pending:Dictionary=result.pending;var stage:String=result.service_stage
		var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0}
		if stage=="expression":row["input_hex"]="";row["output_hex"]=""
		if mutator.is_valid():mutator.call(row,stage,step)
		if result.has("dependency_call_index_u32"):
			var call_index:=int(result.dependency_call_index_u32)
			if packets.is_empty() or int(packets[-1].call_index_u32)!=call_index:packets.append({"call_index_u32":call_index,"observations":[]})
			packets[-1].observations.append(row)
		else:observed.append(row)
	return {"result":{"ok":false,"reason":"test_provider_limit"},"observations":observed,"dependency_packets":packets}
func execute_done(context:Dictionary,request:Dictionary,done:Dictionary)->Dictionary:return Services.execute(context,request,done.observations,done.dependency_packets)
func prepare_done(owner:RefCounted,request:Dictionary,done:Dictionary)->Dictionary:return owner.prepare(request,done.observations,done.dependency_packets)
func event_policy(row:Dictionary,stage:String,_step:int)->void:
	if stage=="events" and row.kind=="event_callback":
		row.after.root.encode_u32(0x200,0xdec0ad66);row.after.event_registers.encode_u32(70*4,0xaabbccdd);row.after.scratch_words.encode_u32(0,0x55667788);row.after.temporary_event_index_s32=99
		row.after.task_variables["1"].encode_u32(4,0x77889900)
func expression_policy(row:Dictionary,stage:String,_step:int)->void:
	if stage=="expression" and row.kind=="F85":
		row.return_u32=41;row.after.module_globals.encode_u32(0,0x33445566);row.after.task_variables.encode_u32(4,102);row.after.root_tail.encode_u32(0x10e0,0x11223344)
	elif stage=="expression" and row.kind=="F909":
		row.after.root.encode_u32(0x10a,0x1234abcd);row.after.module_globals.encode_u32(4,0x55667788);row.after.root_tail.encode_u32(0x10e4,0x99aabbcc)
	else:event_policy(row,stage,_step)
func selection_policy(row:Dictionary,stage:String,_step:int)->void:
	if stage=="events" and row.kind=="event_callback":row.after.arena.encode_u32(7*36+32,2)
func descriptor_policy(row:Dictionary,stage:String,_step:int)->void:
	if stage=="events" and row.kind=="event_callback":row.after.arena.encode_u32(7*36+28,int(row.after.arena.decode_u32(7*36+28))^4)
func signed_save(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true);result.erase("snapshot_sha256");result["snapshot_sha256"]=Clock._hash(result);return result
func resource_views()->void:
	check(Programs.validate(programs) and programs.modules.size()==105,"Mission services use the independently captured original 105-module graph")
	check(Programs.read(programs,"mission",0,57560).size()==57560 and Programs.read(programs,"expression_metadata",0,1088).size()==1088,"Program and guard metadata project exact original DOS regions")
	var context:=base();check(Services._context(context) and context.size()==20,"Core contains exactly twenty owners and references")
	var expression:=Services.expression_view(context);var events:=Services._view(context,Events.CONTEXT_KEYS);var guards:=Services.guard_view(context)
	var bound:=Services.bind_views(expression,events,guards)
	check(bound.ok and same(bound.context,context),"All three kernel views bind one consistent arena and variable owner")
	for bad:Variant in [null,true,0,[],{},bytes(0)]:
		check(not Services.bind_views(bad,events,guards).ok,"Malformed expression views reject without typed-call errors")
		check(not Services.bind_views(expression,bad,guards).ok,"Malformed event views reject without typed-call errors")
		check(not Services.bind_views(expression,events,bad).ok,"Malformed guard views reject without typed-call errors")
	check(expression.task_variables==context.task_variables["1"] and guards.task_record==context.arena.slice(7*36,8*36),"Selected expression variables and guard record are projections of the persisted heap and arena")
	var original:=var_to_bytes(context);expression.task_variables[0]=123;guards.task_record[0]=1
	check(var_to_bytes(context)==original,"Temporary kernel views cannot mutate the persisted owner")
	for field:String in ["root","bank","event_registers"]:
		var wrong:=Services.expression_view(context);wrong[field][0]=int(wrong[field][0])^1
		check(not Services.bind_views(wrong,events,Services.guard_view(context)).ok,"Inconsistent shared expression/event owner rejects: "+field)
	var wrong_guard:=Services.guard_view(context);wrong_guard.task_record[16]=1
	check(not Services.bind_views(Services.expression_view(context),events,wrong_guard).ok,"A guard record that differs from its selected arena slot rejects")
	var wrong_expression:=Services.expression_view(context);wrong_expression.task_variables[0]=1
	check(not Services.bind_views(wrong_expression,events,Services.guard_view(context)).ok,"A duplicated expression variable buffer cannot disagree with the selected heap allocation")
	var cold:=Services.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(context))))
	check(not cold.is_empty() and same(cold,context),"All twenty raw owners survive canonical cold JSON")
	var module:=Programs.module(programs,26);var actual:=base(Programs.read(programs,"mission",0,57560));actual.module_global_offset_u32=int(module.global_owner_offset_u32);actual.arena.encode_u32(7*36+24,26);actual.arena.encode_u32(7*36+28,int(actual.program_base_u32)+int(module.descriptor_offset_u32));actual.task_variables["1"]=bytes(int(module.variable_words_u32)*4)
	check(Services._context(actual) and actual.module_globals.size()==40 and actual.program.size()==57560,"An actual descriptor with shared module globals configures the same owner profile")
	var actual_bound:=Services.bind_views(Services.expression_view(actual),Services._view(actual,Events.CONTEXT_KEYS),Services.guard_view(actual))
	check(actual_bound.ok and actual_bound.original_resource_projection_verified and not bound.original_resource_projection_verified,"Only a full verified original-image projection receives the resource-backed marker")
	var invalid:=actual.duplicate(true);invalid.module_global_offset_u32=(int(actual.module_global_offset_u32)+4)%40
	check(not Services._context(invalid),"A full original descriptor cannot point its globals at a different shared word")
	invalid=actual.duplicate(true);invalid.arena.encode_u32(7*36+28,int(actual.arena.decode_u32(7*36+28))^4)
	check(not Services._context(invalid),"Selected task descriptor must match the actual DOS module table")
	invalid=actual.duplicate(true);invalid.definitions["26"].descriptor_ref_u32=int(invalid.definitions["26"].descriptor_ref_u32)^4
	check(not Services._context(invalid),"An altered definition cannot be paired with the frozen full mission image")
	invalid=actual.duplicate(true);invalid.task_variables["1"]=bytes(actual.task_variables["1"].size()+4)
	check(not Services._context(invalid),"A full-image task allocation must retain its source descriptor's exact word count")
	invalid=actual.duplicate(true);invalid.program[0]=int(invalid.program[0])^1
	check(not Services._context(invalid),"A modified full-length program is not admitted as the original resource graph")
	for row:Array in [[2,13171,40],[5,47882,52],[9,29219,15],[31,42276,36]]:
		var module_row:=Programs.module(programs,int(row[0]));var original_context:=base(Programs.read(programs,"mission",0,57560));original_context.ip_u32=int(row[1]);original_context.module_global_offset_u32=int(module_row.global_owner_offset_u32);original_context.arena.encode_u32(7*36+24,int(row[0]));original_context.arena.encode_u32(7*36+28,int(original_context.program_base_u32)+int(module_row.descriptor_offset_u32));original_context.task_variables["1"]=bytes(int(module_row.variable_words_u32)*4);original_context.event_registers.encode_u32(int(row[2])*4,0xabcdef12)
		var read:=Services.execute(original_context,command("expression","F31"))
		check(read.ok and read.kernel_result.return_u32==0xabcdef12 and int(read.context_after.ip_u32)==int(row[1])+5,"An actual DOS guard expression reads its shared register at the original program offset: module "+str(row[0]))
func expression_routes()->void:
	var context:=base();var frozen:=var_to_bytes(context);var request:=command("expression","F31");var result:=Services.execute(context,request)
	check(result.ok and result.kernel_result.return_u32==37 and result.context_after.ip_u32==5 and result.dependency_calls.is_empty(),"A literal executes the actual expression kernel and advances its one shared cursor")
	check(var_to_bytes(context)==frozen,"A service command keeps every supplied owner unchanged")
	context=base(binary(13,indexed(5,0),indexed(6,1)));context.module_globals.encode_u32(0,7);context.task_variables["1"].encode_u32(4,11);result=Services.execute(context,request)
	check(result.ok and result.kernel_result.return_u32==18 and result.context_after.ip_u32==11,"Expression reads shared static and selected local words through their single owners")
	if result.ok:check(result.context_after.module_globals==context.module_globals and result.context_after.task_variables==context.task_variables,"Read-only expression projection preserves full global/variable ownership")
	var tail_expression:=PackedByteArray([31]);tail_expression.append_array(literal(2));context=base(tail_expression);context.root_tail.encode_u32(0x10e0+8,0xfedcba98);result=Services.execute(context,request)
	check(result.ok and result.kernel_result.return_u32==0xfedcba98 and result.context_after.root_tail==context.root_tail,"Expression reads the separate original Root tail instead of a fabricated main-Root alias")
	context=base(binary(13,binary(32,literal(1),literal(2)),indexed(6,1)));var done:=complete(context,request,Callable(self,"expression_policy"));result=done.result
	check(result.ok and done.observations.size()==1 and done.dependency_packets.is_empty(),"An outer expression uses its explicit provider observation")
	if result.ok:
		check(result.kernel_result.return_u32==143 and result.context_after.task_variables["1"].decode_u32(4)==102,"A later local read sees the callback's preceding selected-heap mutation")
		check(result.context_after.module_globals.decode_u32(0)==0x33445566 and result.context_after.root_tail.decode_u32(0x10e0)==0x11223344,"Callback changes to both separate owner windows survive expression publication")
	context=registered(base(),[1,0,12,0x6060,7,8]);request=command("expression","F22",[12,0xffffffff]);done=complete(context,request,Callable(self,"event_policy"));result=done.result
	check(result.ok and result.dependency_calls.size()==1 and done.observations.is_empty() and done.dependency_packets.size()==1,"Global setter invokes real F48 rather than an observed substitute")
	if result.ok:
		check(done.dependency_packets[0].observations[0].before.root[0xec]==255 and result.context_after.root[0xec]==255,"The setter's original byte write is visible before nested event dispatch")
		check(result.context_after.root.decode_u32(0x200)==0xdec0ad66 and result.context_after.scratch_words.decode_u32(0)==0x55667788 and result.context_after.task_variables["1"].decode_u32(4)==0x77889900,"Real event callbacks preserve root, scratch and selected variable changes")
		check(not result.kernel_result.return_defined and result.kernel_result.void_return_register_ignored,"F22 does not invent a defined scalar EAX return")
	context=registered(base(),[1,0,4,0x6061,9,10]);request=command("expression","F22",[4,123]);done=complete(context,request,Callable(self,"expression_policy"));result=done.result
	check(result.ok and done.observations.size()==1 and done.observations[0].kind=="F909" and done.dependency_packets.size()==1,"F909 completes explicitly before the setter's actual event dispatch")
	if result.ok:
		check(result.context_after.root.decode_u32(0x10a)==0x1234abcd and result.context_after.module_globals.decode_u32(4)==0x55667788 and result.context_after.root_tail.decode_u32(0x10e4)==0x99aabbcc,"Event projection retains preceding expression-provider root/tail/static mutations")
		check(result.context_after.event_registers.decode_u32(70*4)==0xaabbccdd and result.context_after.temporary_event_index_s32==99,"Separate event registers and temporary index retain their actual event result")
	for selector in [15,16]:
		context=registered(base(),[1,0,selector,0x6070+selector,1,2]);context.root.encode_u32(0x124,0x55);done=complete(context,command("expression","F22",[selector,0x12345678]),Callable(self,"event_policy"));result=done.result
		check(result.ok and result.context_after.root.decode_u32(0x124)==(0x12345678 if selector==15 else 0x55) and result.dependency_calls.size()==1,"Original DOS setter slot "+str(selector)+" retains its actual write/ignore behavior and still dispatches the event")
func guard_routes()->void:
	var context:=registered(base(),[2,0,3,0x6062,11,12]);var request:=command("guards","F34",[3,0x76543210]);var done:=complete(context,request,Callable(self,"event_policy"));var result:Dictionary=done.result
	check(result.ok and done.dependency_packets.size()==1 and result.dependency_calls[0].kind=="F48","F34 publishes the register write before executing the actual common registry")
	if result.ok:
		check(done.dependency_packets[0].observations[0].before.event_registers.decode_u32(12)==0x76543210 and result.context_after.event_registers.decode_u32(12)==0x76543210,"Nested dispatch observes and preserves the one updated register word")
		check(result.context_after.root.decode_u32(0x200)==0xdec0ad66 and result.context_after.task_variables["1"].decode_u32(4)==0x77889900,"Guard projection preserves event callback changes outside its own narrow view")
		var read:=Services.execute(result.context_after,command("guards","F35",[3]));check(read.ok and read.kernel_result.return_u32==0x76543210 and same(read.context_after,result.context_after),"F35 reads the shared register without any secondary state mutation")
	var expression:=binary(13,indexed(3,1),indexed(6,1));context=base(expression);request=command("guards","F32",["F44",4]);result=Services.execute(context,request)
	var task_address:=Guards.TASK_BASE+7*36
	check(result.ok and result.context_after.ip_u32==11 and result.dependency_calls.size()==2,"F32 traverses both operands and executes both original registrations")
	if result.ok:
		check(has_key(result.context_after,[1,0,1,Guards.F47_WORD,task_address,4]),"Global dependency uses the original event code and callback word")
		check(has_key(result.context_after,[4,task_address,1,Guards.F47_WORD,task_address,4]),"Task-variable dependency carries the physical arena reference, not its generation-packed handle")
		check(task_address!=((3<<16)|7) and result.context_after.arena==context.arena,"Registration preserves the record and keeps physical references distinct from handles")
		var remove:Dictionary=result.context_after.duplicate(true);remove.ip_u32=0;var removed:=Services.execute(remove,command("guards","F32",["F45",4]));check(removed.ok and removed.context_after.nodes.is_empty() and removed.context_after.tree_root_u32==0,"The same guard walk executes real F45 removal against the common registry")
	context=base(binary(32,literal(5),literal(7)));result=Services.execute(context,request)
	check(result.ok and result.context_after.ip_u32==11 and result.dependency_calls.size()==3,"F32 evaluates both dynamic keys through real F31 and rewinds before recursively traversing operands")
	if result.ok:check(has_key(result.context_after,[7,5,7,Guards.F47_WORD,task_address,4]),"Measured dynamic keys feed the actual event-tree registration")
	context=base(binary(32,binary(32,literal(1),literal(2)),indexed(6,1)));done=complete(context,request,Callable(self,"expression_policy"));result=done.result
	check(result.ok and done.observations.is_empty() and done.dependency_packets.size()==1 and done.dependency_packets[0].call_index_u32==0,"A nested F31 external provider is indexed inside its actual dependency call")
	if result.ok:
		check(has_key(result.context_after,[7,41,102,Guards.F47_WORD,task_address,4]) and result.context_after.task_variables["1"].decode_u32(4)==102,"Guard key two sees the heap change produced while evaluating key one")
		check(result.context_after.module_globals.decode_u32(0)==0x33445566 and result.context_after.root_tail.decode_u32(0x10e0)==0x11223344,"Guard continuation preserves the full expression result beyond its narrow view")
	var image:=bytes(64);var first:=indexed(3,2);var second:=indexed(4,5);for index in range(5):image[24+index]=first[index];image[40+index]=second[index]
	context=base(image);context.ip_u32=60;context.program.encode_u32(4,2);context.program.encode_u32(8,int(context.program_base_u32)+24);context.program.encode_u32(12,int(context.program_base_u32)+40);context.arena.encode_u32(7*36+8,int(context.program_base_u32));request=command("guards","F33",["F44"]);result=Services.execute(context,request)
	check(result.ok and result.context_after.ip_u32==60 and result.dependency_calls.size()==2,"F33 uses local per-clause cursors and preserves the caller's saved instruction position")
	if result.ok:check(has_key(result.context_after,[1,0,2,Guards.F47_WORD,task_address,0]) and has_key(result.context_after,[2,0,5,Guards.F47_WORD,task_address,1]),"F33 assigns the original independent clause index to each registration")
func owner_controls()->void:
	var context:=base(binary(32,binary(32,literal(1),literal(2)),indexed(6,1)));var request:=command("guards","F32",["F44",4]);var done:=complete(context,request,Callable(self,"expression_policy"));var owner:=State.new()
	check(done.result.ok and owner.configure(context),"Owned state configures all twenty shared mission owners")
	var packed:=owner.raw_core();check(packed.keys()==["context"] and packed.context.size()==20 and packed.context.root_tail is String and packed.context.task_variables["1"] is String,"Saved Core stores each tail and selected allocation once in canonical hex")
	check(not packed.context.has("task_record") and not packed.context.has("expression_context") and not packed.context.has("guard_context"),"Derived kernel views are not duplicated in persistent state")
	var before:=Clock._hash(owner.snapshot());var prepared:=prepare_done(owner,request,done)
	check(prepared.get("ok",false) and Clock._hash(owner.snapshot())==before,"Nested parser and registry composition prepares privately")
	if not prepared.get("ok",false):return
	check(owner.commit(prepared) and owner.generation()==1 and same(owner.raw_context(),done.result.context_after),"A replay-verified command atomically publishes the complete mission result")
	check(not owner.commit(prepared),"A consumed mission-state capability cannot publish twice")
	var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))) and same(cold.raw_context(),owner.raw_context()),"Nested guard, expression and registry work replays after cold JSON restoration")
	var next_command:=command("expression","F22",[1,0x7fffffff]);var next:=complete(owner.raw_context(),next_command);var hot_next:=prepare_done(owner,next_command,next);var cold_next:=prepare_done(cold,next_command,next)
	check(hot_next.get("ok",false) and cold_next.get("ok",false) and Clock._hash(hot_next.receipt)==Clock._hash(cold_next.receipt),"Hot and cold owners produce the same receipt for the next global setter")
	if hot_next.get("ok",false) and cold_next.get("ok",false):check(owner.commit(hot_next) and cold.commit(cold_next) and same(owner.raw_context(),cold.raw_context()),"Next-operation continuation publishes the same clamped global and shared tree")
	var stable:=Clock._hash(owner.snapshot());var copied:=owner.raw_context();copied.root_tail[0]=1;copied.module_globals[0]=1;copied.task_variables["1"][0]=1
	check(Clock._hash(owner.snapshot())==stable,"Reading raw mission owners returns private copies")
	for field:String in ["root_tail","module_globals","arena"]:
		var forged:=owner.snapshot();var raw:=str(forged.core.context[field]).hex_decode();raw[0]=int(raw[0])^1;forged.core.context[field]=raw.hex_encode()
		check(not owner.restore(signed_save(forged)) and Clock._hash(owner.snapshot())==stable,"Rehashing forged raw state cannot bypass command replay: "+field)
	var forged:=owner.snapshot();var variable:=str(forged.core.context.task_variables["1"]).hex_decode();variable[0]=int(variable[0])^1;forged.core.context.task_variables["1"]=variable.hex_encode()
	check(not owner.restore(signed_save(forged)) and Clock._hash(owner.snapshot())==stable,"Rehashing a forged selected allocation cannot bypass the cold witness")
	var receipt_candidate:=owner.prepare(command("guards","F35",[0]));check(receipt_candidate.get("ok",false),"A readonly mission candidate exists for receipt verification")
	if receipt_candidate.get("ok",false):
		var wrong:=receipt_candidate.duplicate(true);wrong.receipt.raw_state_after_sha256="forged";check(not owner.commit(wrong) and Clock._hash(owner.snapshot())==stable,"Forged mission receipts cannot publish their candidate")
	var other:=State.new();check(other.configure(owner.raw_context()) and not other.commit(receipt_candidate),"A capability belongs to its originating mission owner")
	var aba:=State.new();check(aba.configure(context),"ABA control starts from the same mission state");var token:=prepare_done(aba,request,done)
	check(token.get("ok",false) and aba.configure(context) and not aba.commit(token),"Reconfiguring identical raw bytes invalidates an earlier capability")
	for bad:Variant in [null,true,0,[],{},"save"]:check(not owner.restore(bad) and not owner.commit(bad),"Malformed mission state and publication containers reject safely")
	for bad:Variant in [null,true,0,[],"nested"]:
		var save:=owner.snapshot();save.core=bad;check(not owner.restore(signed_save(save)),"Malformed Core rejects before replay")
		save=owner.snapshot();save.core.context=bad;check(not owner.restore(signed_save(save)),"Malformed mission context rejects before replay")
		save=owner.snapshot();save.last_witness=bad;check(not owner.restore(signed_save(save)),"Malformed witness rejects before replay")
		save=owner.snapshot();save.last_witness.before_core=bad;check(not owner.restore(signed_save(save)),"Malformed witness owner rejects before replay")
		save=owner.snapshot();save.last_witness.payload=bad;check(not owner.restore(signed_save(save)),"Malformed witness payload rejects before replay")
	check(Clock._hash(owner.snapshot())==stable,"Invalid cold data never replace the active mission owner")
	var cyclic_args:Array=[];cyclic_args.append(cyclic_args)
	check(not owner.prepare(command("expression","F31",cyclic_args)).ok,"A cyclic argument array rejects before recursive JSON serialization")
	cyclic_args.clear()
	var cyclic_dictionary:Dictionary={};cyclic_dictionary["self"]=cyclic_dictionary
	check(not owner.prepare(command("expression","F31",[cyclic_dictionary])).ok,"A cyclic nested argument dictionary rejects before serialization")
	cyclic_dictionary.clear()
	var cyclic_observations:Array=[];cyclic_observations.append(cyclic_observations)
	check(not owner.prepare(command("expression","F31"),cyclic_observations).ok,"Cyclic observations reject without script recursion errors")
	check(not owner.prepare(command("guards","F34",[0,1]),[],[{"call_index_u32":0,"observations":cyclic_observations}]).ok,"Cyclic nested dependency observations reject without serialization")
	cyclic_observations.clear()
	var deep:Array=[];var current:Array=deep
	for index in range(40):
		var child:Array=[];current.append(child);current=child
	check(not owner.prepare(command("expression","F31",deep)).ok,"Deep malformed plain data rejects within the documented serialization bound")
	check(Clock._hash(owner.snapshot())==stable,"Cyclic and deep payload rejection preserves the active owner")
	var cyclic_core:=owner.raw_context();var cyclic_heap:Dictionary=cyclic_core.task_variables;cyclic_heap["loop"]=cyclic_heap
	check(not owner.configure(cyclic_core) and Services.decode_context(cyclic_core).is_empty(),"Cyclic Core containers reject before owner copying or cold decoding")
	var cyclic_save:=owner.snapshot();cyclic_save.core.context=cyclic_core
	check(not owner.restore(cyclic_save),"A cyclic cold Core rejects before hashing the save")
	cyclic_heap.erase("loop")
	if receipt_candidate.get("ok",false):
		var cyclic_receipt:Dictionary={};cyclic_receipt["self"]=cyclic_receipt;var cyclic_prepared:=receipt_candidate.duplicate(true);cyclic_prepared.receipt=cyclic_receipt
		check(not owner.commit(cyclic_prepared),"A cyclic receipt rejects before receipt hashing")
		cyclic_receipt.clear()
	check(Clock._hash(owner.snapshot())==stable,"Cyclic Core and receipt rejection preserves the active owner")
	var selection:=registered(base(),[2,0,0,0x6063,13,14]);selection.task_variables["2"]=bytes(8);selection.next_variable_id_u32=3
	var selection_command:=command("guards","F34",[0,1]);var shifted:=complete(selection,selection_command,Callable(self,"selection_policy"));var selection_owner:=State.new()
	check(selection_owner.configure(selection),"Selection guard starts with two valid independent heap allocations")
	var selection_before:=Clock._hash(selection_owner.snapshot())
	check(not shifted.result.ok and shifted.result.reason=="mission_selection_changed_outside_service_profile","A callback cannot silently replace the selected variable allocation")
	check(not prepare_done(selection_owner,selection_command,shifted).ok and Clock._hash(selection_owner.snapshot())==selection_before,"Rejected selection changes never publish a partial variable or registry result")
	var descriptor_shift:=complete(selection,selection_command,Callable(self,"descriptor_policy"))
	check(not descriptor_shift.result.ok and descriptor_shift.result.reason=="mission_selection_changed_outside_service_profile","A callback cannot retarget the selected task's original descriptor")
	check(not prepare_done(selection_owner,selection_command,descriptor_shift).ok and Clock._hash(selection_owner.snapshot())==selection_before,"Rejected descriptor changes leave all owners untouched")
func invalid_controls()->void:
	var context:=base();var request:=command("expression","F31");var frozen:=var_to_bytes(context)
	for bad:Variant in [null,true,0,"context",[],{},bytes(0)]:check(not Services.execute(bad,request).ok,"Malformed Core context rejects without typed-call errors")
	for key:String in Services.KEYS:
		var wrong:=context.duplicate(true);wrong.erase(key);check(not Services.execute(wrong,request).ok,"Every original owner or reference must be explicit: "+key)
	for key:String in ["root","root_tail","bank","event_registers","module_globals","arena","scratch_words","metadata"]:
		var wrong:=context.duplicate(true);wrong[key]=bytes(context[key].size()-1);check(not Services.execute(wrong,request).ok,"A truncated raw owner rejects: "+key)
	for bad:Variant in [null,true,0,"command",[],{}, {"kind":1}, {"kind":"unknown","operation":"F31","args":[]}]:check(not Services.execute(context,bad).ok,"Unknown or malformed command containers reject safely")
	for bad:Variant in [null,true,0,[],{},"F999"]:
		check(not Services.execute(context,{"kind":"expression","operation":bad,"args":[]}).ok,"Malformed expression operation rejects safely")
		check(not Services.execute(context,{"kind":"guards","operation":bad,"args":[]}).ok,"Malformed guard operation rejects safely")
	for bad:Variant in [null,true,0,{},[{}],[{"call_index_u32":-1,"observations":[]}],[{"call_index_u32":0,"observations":{}}]]:check(not Services.execute(context,request,[],bad).ok,"Malformed dependency packets reject safely")
	for bad:Variant in [null,true,0,{},"trace",[{}]]:check(not Services.execute(context,request,bad).ok,"Malformed provider observations reject safely")
	var wrong:=context.duplicate(true);wrong.root_tail.encode_u32(0x180c,2);check(not Services.execute(wrong,request).ok,"The canonical bank reference marker cannot become an unrelated raw pointer")
	wrong=context.duplicate(true);wrong.task_variables.erase("1");check(not Services.execute(wrong,request).ok,"A selected allocation must exist in the one shared variable heap")
	wrong=context.duplicate(true);wrong.arena.encode_u32(7*36+32,2);check(not Services.execute(wrong,request).ok,"A dangling selected variable reference rejects before evaluation")
	wrong=context.duplicate(true);wrong.arena.encode_u32(0,5);wrong.arena.encode_u32(24,0);check(not Services.execute(wrong,request).ok,"A priority5 cleanup cannot fabricate a source cleanup for a cleanup-less module")
	wrong=context.duplicate(true);wrong.metadata[0]=int(wrong.metadata[0])^1;check(not Services.execute(wrong,request).ok,"Guard metadata must retain the actual original DOS bytes")
	wrong=context.duplicate(true);wrong["task_record"]=bytes(36);check(not Services.execute(wrong,request).ok,"A second persistent copy of the selected record is rejected")
	var fault:=base(PackedByteArray([0]));check(not Services.execute(fault,request).ok,"An undefined original expression result remains an explicit fault, not a synthesized scalar")
	check(not Services.execute(context,request,[],[{"call_index_u32":0,"observations":[]}]).ok,"Unused dependency replies cannot be silently ignored")
	var nested:=base(binary(32,binary(32,literal(1),literal(2)),literal(3)));var nested_command:=command("guards","F32",["F44",4]);var done:=complete(nested,nested_command,Callable(self,"expression_policy"))
	check(done.result.ok and not Services.execute(nested,nested_command,[],[]).ok,"A missing nested expression answer cannot be replaced by a successful generic dependency")
	if done.result.ok and not done.dependency_packets.is_empty():
		var changed:Array=done.dependency_packets.duplicate(true);changed[0].observations[0].before.root_tail[0]=1
		check(not Services.execute(nested,nested_command,[],changed).ok,"A nested expression answer for a different Root-tail owner cannot resume")
	check(var_to_bytes(context)==frozen,"All invalid commands preserve the original supplied Core")
func native_controls()->void:
	check(FileAccess.file_exists(FIXTURE),"Independent native mission-services fixture is present")
	if not FileAccess.file_exists(FIXTURE):return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent native mission-services fixture is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.get("profile")==Services.PROFILE and fixture.get("cases") is Array and int(fixture.get("case_count",0))==fixture.cases.size(),"Native composition declares its actual unique service cases")
	if not fixture.get("cases") is Array or not fixture.get("proof") is Dictionary:return
	var proof:Dictionary=fixture.proof
	check(int(proof.get("fresh_process_runs_each_call",0))==3 and proof.get("reverse_native_calls_verified",false) and not proof.get("expected_arithmetic_calculated_in_python",true),"Native expectations come from three fresh original-procedure runs and reverse replay")
	check(proof.get("source_dependencies_sha256") is Dictionary and not proof.source_dependencies_sha256.is_empty(),"Native composition pins every source and adapter dependency")
	if not proof.get("source_dependencies_sha256") is Dictionary:return
	dependencies=proof.source_dependencies_sha256.duplicate(true)
	for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Native composition dependency remains current: "+path)
	var previous:Dictionary={};var previous_owner:RefCounted;var previous_cold:RefCounted;var shared_steps:=0;var shared_operations:=0;var original_image_cases:=0;var counts:Dictionary={"F31":0,"F44":0,"F45":0,"F48":0}
	for row:Dictionary in fixture.cases:
		var name:String=row.name;var context:=Services.decode_context(row.context_before);var expected:=Services.decode_context(row.expected.context_after)
		check(not context.is_empty() and not expected.is_empty(),"Native service contexts bind all twenty original owners: "+name)
		if context.is_empty() or expected.is_empty():continue
		var observations:Variant=Expr.decode_observations(row.observations);var packets:Array=row.dependency_packets.duplicate(true);var request:Dictionary=row.command.duplicate(true)
		check(observations!=null,"External native expression witnesses pass the public codec: "+name)
		if observations==null:continue
		var owner:=State.new();var chained:bool=row.get("carries_previous_native_state",false)
		if row.has("shared_owner_sequence_index_u32"):
			check(int(row.shared_owner_sequence_index_u32)==shared_operations and chained==(shared_operations>0),"Each measured shared sequence step explicitly identifies its continuation: "+name)
			shared_operations+=1
		if chained:
			shared_steps+=1;check(not previous.is_empty() and same(previous,context) and previous_owner!=null and previous_cold!=null,"Native continuation carries the preceding measured complete owner: "+name)
			if previous_owner==null or previous_cold==null:continue
			owner=previous_owner
		else:check(owner.configure(context),"A measured native owner configures without invented aliases: "+name)
		var cold:=State.new();var cold_before:Dictionary=previous_cold.snapshot() if chained else owner.snapshot()
		check(cold.restore(JSON.parse_string(JSON.stringify(cold_before))) and same(cold.raw_context(),context),"The independent cold owner restores its own preceding result before the next operation: "+name)
		if row.has("shared_owner_sequence_index_u32"):check(owner.generation()==int(row.shared_owner_sequence_index_u32) and cold.generation()==owner.generation(),"Shared hot and cold histories advance without reconfiguration: "+name)
		var frozen:=var_to_bytes([context,request,observations,packets]);var result:=Services.execute(context,request,observations,packets)
		check(result.get("ok",false),"Actual mission kernels complete the measured composition: "+name+" "+str(result.get("reason","")))
		if not result.get("ok",false):continue
		native_cases+=1
		for key:String in Services.KEYS:check(result.context_after[key]==expected[key],"Measured native owner matches at "+key+": "+name)
		check(result.source_order==row.expected.source_order,"Outer source call order matches the measured native composition: "+name)
		check(result.original_resource_projection_verified==row.expected.original_resource_projection_verified,"Original-image projection is claimed only for measured complete-resource contexts: "+name)
		if result.original_resource_projection_verified:original_image_cases+=1
		check(result.kernel_result.return_defined==row.expected.return_defined,"Native scalar/void return distinction is preserved: "+name)
		if row.expected.return_defined:check(int(result.kernel_result.return_u32)==int(row.expected.return_u32),"Defined native scalar result matches: "+name)
		check(result.dependency_calls.size()==row.expected.dependency_calls.size(),"Every dependency is an actual kernel invocation: "+name)
		for index in range(mini(result.dependency_calls.size(),row.expected.dependency_calls.size())):
			var call:Dictionary=result.dependency_calls[index];var measured:Dictionary=row.expected.dependency_calls[index]
			check(call.kind==measured.kind and call.result.source_order==measured.result.source_order,"Nested original procedure order matches: "+name+" #"+str(index))
			check(call.result.return_defined==measured.result.return_defined,"Nested scalar/void result classification matches: "+name)
			if measured.result.return_defined:check(int(call.result.return_u32)==int(measured.result.return_u32),"Nested defined native expression value matches: "+name)
			if counts.has(call.kind):counts[call.kind]=int(counts[call.kind])+1
		check(var_to_bytes([context,request,observations,packets])==frozen,"Measured service invocation preserves all input owners and witnesses: "+name)
		var hot_prepared:=owner.prepare(request,observations,packets);var cold_prepared:=cold.prepare(request,observations,packets)
		check(hot_prepared.get("ok",false) and cold_prepared.get("ok",false),"Measured composition prepares in hot and cold owners: "+name)
		if hot_prepared.get("ok",false) and cold_prepared.get("ok",false):
			check(Clock._hash(hot_prepared.receipt)==Clock._hash(cold_prepared.receipt),"Measured hot/cold receipts are identical: "+name)
			check(owner.commit(hot_prepared) and cold.commit(cold_prepared) and same(owner.raw_context(),expected) and same(cold.raw_context(),expected),"Only replay-verified native results publish all twenty owners: "+name)
			if row.has("shared_owner_sequence_index_u32"):check(owner.generation()==int(row.shared_owner_sequence_index_u32)+1 and cold.generation()==owner.generation(),"Both independent histories publish the next original sequence generation: "+name)
			var restored:=State.new();check(restored.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))) and same(restored.raw_context(),expected),"A completed measured transition survives cold replay: "+name)
		previous=expected;previous_owner=owner;previous_cold=cold
	check(native_cases==int(fixture.case_count),"Every independently measured native composition was compared")
	check(shared_steps==int(proof.get("shared_owner_continuations",-1)) and shared_steps>0 and shared_operations==int(proof.get("shared_owner_steps",-1)) and not proof.get("shared_sequence_program_rebound",true),"Native sequence carries the same program and all twenty owners through every continuation")
	check(original_image_cases==int(proof.get("original_full_image_cases",-1)) and original_image_cases>0,"Native compositions include complete original-image descriptor/global/local bindings")
	for operation:String in counts:
		var key:="actual_"+operation+"_calls"
		check(int(counts[operation])==int(proof.get(key,-1)) and int(counts[operation])>0,"All measured actual dependency invocations were counted separately: "+operation)
	native_fixture_pending=false
func run()->void:
	programs=Programs.load_original();check(not programs.is_empty(),"The exact original mission resource graph loads before service tests")
	if not programs.is_empty():resource_views();expression_routes();guard_routes();owner_controls();invalid_controls();native_controls()
	var sources:Dictionary={}
	for path:String in ["scripts/source_mission_services.gd","scripts/source_mission_services_state.gd","scripts/source_mission_expression.gd","scripts/source_mission_guards.gd","scripts/source_mission_programs.gd","scripts/source_events.gd","scripts/source_global_rng.gd","scripts/source_contact_scan.gd","scripts/source_clock_pipeline.gd","data/ffe_mission_programs.json","tests/test_source_mission_services.gd","tests/fixtures/source_mission_services_native.json"]:
		if FileAccess.file_exists("res://"+path):sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Services.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"native_fixture_pending":native_fixture_pending,"sources":sources,"directed_callbacks_are_explicit_test_providers":true,"Main_integrated":false,"full_mission_VM_executed":false},"\t"));file.close()
	print("SOURCE MISSION SERVICES TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
