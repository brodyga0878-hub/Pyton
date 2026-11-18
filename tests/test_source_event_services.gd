extends SceneTree
const Services=preload("res://scripts/source_event_services.gd")
const State=preload("res://scripts/source_event_services_state.gd")
const Effects=preload("res://scripts/source_damage_effects.gd")
const Events=preload("res://scripts/source_events.gd")
const Player=preload("res://scripts/source_player_events.gd")
const Messages=preload("res://scripts/source_messages.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const FIXTURE:="res://tests/fixtures/source_event_services_native.json"
const FIXTURE_SHA:="91b3c907336972f452fc140bda326d658e25c3dbd0d54e1e07af990877cf5b3b"
const REPORT:="res://build/current-test-reports/source-event-services.json"
var checks:=0
var failures:=0
var native_cases:=0
var native_fixture_pending:=true
var dependencies:Dictionary={}
var buffer_pool:Dictionary={}
var hydrated:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<25:push_error(message)
func bytes(count:int,fill:int=0)->PackedByteArray:
	var result:=PackedByteArray();result.resize(count);result.fill(fill);return result
func base()->Dictionary:
	var root:=bytes(16384);root.encode_u32(0,0x12345678);root.encode_u32(4,0x121cf7);root.encode_u32(0xc0,114);root[0xef]=99
	return {"root":root,"bank":bytes(38986),"event_registers":bytes(284),"module_entries":bytes(168),"module_count_s32":-1,"model_resources":Effects.source_resources(),"arena":bytes(5400),"tree_root_u32":0,"nodes":{},"next_node_id_u32":1,"task_variables":{},"next_variable_id_u32":1,"definitions":{"0":{"descriptor_ref_u32":0x101,"cleanup_instruction_u32":0x1234,"variable_words_u32":4}},"scratch_words":bytes(32,0xc3),"queue_records":bytes(10380),"queue_control":bytes(36),"fallback_name":bytes(612),"temporary_event_index_s32":-7,"watched_index_u8":77}
func same(a:Dictionary,b:Dictionary)->bool:
	for key:String in Services.KEYS:
		if a[key]!=b[key]:return false
	return true
func event_command(operation:String,args:Array=[])->Dictionary:return {"kind":"events","operation":operation,"args":args}
func player_command(operation:String,index:int,code:int=0)->Dictionary:return {"kind":"player","operation":operation,"payload":{"code_u32":code,"body_slot_u32":1,"index_u8":index}}
func packet(code:int=0x98ca,parameter:int=0x11223344)->PackedByteArray:
	var result:=bytes(48,0xa5);result.encode_u32(0,code);result.encode_u32(4,parameter);result.encode_u32(0x18,0xffffffff);return result
func message_command(value:PackedByteArray,operation:String="F349",mode:int=1)->Dictionary:return {"kind":"message","operation":operation,"packet":value,"display_mode_s32":mode}
func complete(context:Dictionary,command:Dictionary,mutator:Callable=Callable())->Dictionary:
	var observed:Array=[];var packets:Array=[]
	for step in range(256):
		var result:=Services.execute(context,command,observed,packets)
		if result.get("ok",false) or not result.get("pending") is Dictionary:return {"result":result,"observations":observed,"event_packets":packets}
		var pending:Dictionary=result.pending;var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0}
		var stage:String=result.service_stage
		if stage=="message":
			row["input_text_hex"]=pending.input_text_hex
			row["output_text_hex"]="6f726967696e616c207465787400" if row.kind=="F1344" else "610d620d00" if row.kind=="F1398" else ""
		if mutator.is_valid():mutator.call(row,stage,step)
		if command.kind=="player" and stage=="events":
			var call_index:int=int(result.event_call_index_u32)
			if packets.is_empty() or int(packets[-1].call_index_u32)!=call_index:packets.append({"call_index_u32":call_index,"observations":[]})
			packets[-1].observations.append(row)
		else:observed.append(row)
	return {"result":{"ok":false,"reason":"test_provider_limit"},"observations":observed,"event_packets":packets}
func invoked(context:Dictionary,command:Dictionary,done:Dictionary)->Dictionary:return Services.execute(context,command,done.observations,done.event_packets)
func prepared(owner:RefCounted,command:Dictionary,done:Dictionary)->Dictionary:return owner.prepare(command,done.observations,done.event_packets)
func registered(context:Dictionary,key:Array)->Dictionary:
	var result:=Services.execute(context,event_command("F44",key))
	check(result.ok,"A real F44 registration enters the one shared event tree")
	return result.context_after if result.ok else context
func event_policy(row:Dictionary,stage:String,_step:int)->void:
	if stage=="events" and row.kind=="event_callback":
		row.after.event_registers.encode_u32(22*4,0xdec0ad66);row.after.scratch_words.encode_u32(0,0xaabbccdd);row.after.temporary_event_index_s32=1234
func signed_save(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true);result.erase("snapshot_sha256");result["snapshot_sha256"]=Clock._hash(result);return result
func direct_events()->void:
	var context:=base();check(Services._context(context) and context.size()==19,"Services context is the exact nineteen-field owner union")
	context=registered(context,[22,0,17,100,5,6]);var frozen:=var_to_bytes(context)
	var command:=event_command("F48",[22,0,17]);var pending:=Services.execute(context,command)
	check(not pending.ok and pending.service_stage=="events" and pending.pending.kind=="event_callback" and pending.pending.args==[100,5,6],"Direct event service exposes the actual captured registration callback")
	var done:=complete(context,command,Callable(self,"event_policy"));var result:Dictionary=done.result
	check(result.ok and result.kernel_result.source_order.has("F48") and result.event_calls.is_empty(),"Direct event dispatch executes Events rather than an observed whole F48 reply")
	if result.ok:
		check(result.context_after.event_registers.decode_u32(22*4)==0xdec0ad66 and result.context_after.scratch_words.decode_u32(0)==0xaabbccdd and result.context_after.temporary_event_index_s32==1234,"Event callback changes the declared shared registers, exact32-byte scratch and temporary owner")
		check(result.context_after.root[0xef]==99 and result.context_after.watched_index_u8==77,"Root+EF and the external watched byte remain separate owners")
		check(result.context_after.queue_records==context.queue_records and result.context_after.module_entries==context.module_entries and result.context_after.model_resources==context.model_resources,"Projecting an Events kernel does not drop unrelated queue, modules or readonly model owners")
	check(var_to_bytes(context)==frozen,"Event completion preserves the original shared caller buffers")
	var copied:=Services.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(context))))
	check(not copied.is_empty() and same(copied,context),"All nineteen context owners survive canonical cold JSON")
	if not copied.is_empty():check(invoked(copied,command,JSON.parse_string(JSON.stringify(Scan.json_value(done)))).ok,"Direct event callback witnesses replay through the public service codec")
func player_events()->void:
	var context:=registered(base(),[22,0,17,200,7,8]);var command:=player_command("F61",17);var done:=complete(context,command,Callable(self,"event_policy"));var result:Dictionary=done.result
	check(result.ok and result.event_calls.size()==1 and done.observations.is_empty() and done.event_packets.size()==1,"Player F61 invokes actual F48 with its own nested event packet")
	if result.ok:
		check(done.event_packets[0].observations[0].before.temporary_event_index_s32==17 and result.context_after.temporary_event_index_s32==0,"F61 publishes its temporary index during event dispatch and resets it afterward")
		check(result.context_after.scratch_words.decode_u32(0)==0xaabbccdd and result.context_after.event_registers.decode_u32(22*4)==0xdec0ad66,"Actual nested Events changes survive the subsequent Player projection")
		check(result.context_after.watched_index_u8==77 and result.context_after.root[0xef]==99 and result.context_after.arena==context.arena,"Nested services retain separate watched/scratch owners and unaffected task memory")
	context=registered(base(),[22,0,0xffffffff,201,9,10]);command=player_command("F61",255);done=complete(context,command,Callable(self,"event_policy"));result=done.result
	check(result.ok and result.event_calls.size()==1,"Signed byte minus1 is normalized only at the unsigned event-key seam")
	if result.ok:
		check(done.event_packets[0].observations[0].before.temporary_event_index_s32==-1 and result.context_after.temporary_event_index_s32==0,"Native signed removal byte remains visible during F48 and is reset afterward")
		check(result.kernel_result.requests[0].args==[22,0,-1] and result.event_calls[0].captured_callbacks==[[201,9,10]],"The player call retains signed source arguments while real Events matches rawFFFFFFFF")
	context=base();context.root[0xec]=17;context.root[0xed]=18;context.root[0xe8]=2;context=registered(context,[1,0,14,202,11,12]);command=player_command("F1103",17);done=complete(context,command);result=done.result
	check(result.ok and result.event_calls.size()==1 and result.context_after.root[0xec]==0 and result.context_after.root[0xed]==18 and result.context_after.root[0xe8]==0,"Actual player cleanup feeds its event1 notification through the same source registry")
	context=base();context.watched_index_u8=17;context.root[0xef]=99;context.root[0xec]=17;context.root[0xea]=5;command=player_command("F1103",17);done=complete(context,command);result=done.result
	check(result.ok and result.context_after.watched_index_u8==0 and result.context_after.root[0xef]==99 and result.context_after.root[0xec]==17 and result.context_after.root[0xea]==0,"Watched-index removal clears its external byte, leaves RootEF/target independent, and follows its alternate branch")
	check(result.ok and result.event_calls.is_empty() and result.kernel_result.source_order==["F1103","F1102","F262","F991"],"Watched branch does not manufacture a cleanup or event-dispatch call")
func message_bindings()->void:
	var witness:=packet();var pending:Dictionary={"kind":"F349","args":[0x98ca,0x11223344,0xffffffff]};var original:=witness.duplicate()
	var bound:=Services.bind_message_packet(pending,witness,"equipment")
	check(bound.ok and bound.packet==witness and bound.other_words_policy=="explicit-opaque-caller-witness","Equipment call binds only its three source-defined packet words")
	if bound.ok:
		check(bound.defined_word_offsets_u32==[0,0x18,4],"Equipment binder identifies exactly the source-written offsets")
		bound.packet[8]=0;check(witness==original,"Bound witness is a private48-byte copy")
	var alternate:=witness.duplicate();alternate[8]=0x35;alternate[47]=0x66;bound=Services.bind_message_packet(pending,alternate,"equipment")
	check(bound.ok and bound.packet[8]==0x35 and bound.packet[47]==0x66,"Unwritten packet bytes remain the explicit caller witness instead of synthesized zeros")
	for offset in [0,4,0x18]:
		var bad:=witness.duplicate();bad[offset]=int(bad[offset])^1;check(not Services.bind_message_packet(pending,bad,"equipment").ok,"A mismatched source-defined equipment word rejects")
	pending={"kind":"F349","args":[0x8635,1,999,0xffffffff]};witness=packet(0x8635);witness.encode_u32(0xc,999);bound=Services.bind_message_packet(pending,witness,"destruction")
	check(bound.ok and bound.defined_word_offsets_u32==[0,0x18,0xc],"Bounty caller binds its actual extra payload word at0xC")
	witness[0xc]=int(witness[0xc])^1;check(not Services.bind_message_packet(pending,witness,"destruction").ok,"Bounty caller rejects a changed known payout parameter")
	pending.args=[0x98cf,0,0,0xffffffff];witness=packet(0x98cf);witness.encode_u32(0xc,0xdeadbeef);bound=Services.bind_message_packet(pending,witness,"destruction")
	check(bound.ok and bound.defined_word_offsets_u32==[0,0x18] and bound.packet.decode_u32(0xc)==0xdeadbeef,"Rank caller leaves its unwritten0xC bytes opaque even when the normalized observation has a zero placeholder")
	for bad:Variant in [null,true,0,[],{},bytes(47),bytes(49),"00"]:check(not Services.bind_message_packet(pending,bad,"destruction").ok,"Only a complete explicit48-byte caller packet is accepted")
	for bad:Variant in [null,true,0,[],{},"unknown"]:check(not Services.bind_message_packet(pending,witness,bad).ok,"Unknown or malformed caller kinds reject without typed-call errors")
func message_services()->void:
	var context:=base();var witness:=packet();var command:=message_command(witness);var frozen:=var_to_bytes([context,command]);var done:=complete(context,command);var result:Dictionary=done.result
	check(result.ok and result.kernel_result.F271_backend_executed and result.kernel_result.submissions.size()==1,"An explicit caller packet routes through real F349/F350 and the message-ring backend")
	if result.ok:
		var text:PackedByteArray=str("6f726967696e616c207465787400").hex_decode()
		check(result.context_after.queue_records.slice(9,9+text.size())==text and result.context_after.queue_records[8]==17,"Ring stores the original formatter text with negative-flags style17")
		check(result.kernel_result.submissions[0].wrapped_line_count_u32==2 and result.context_after.queue_control.decode_u32(24)==1,"Actual wrapping observations drive line count while ordinary submission advances the source cursor")
		check(result.context_after.queue_records.decode_u32(0)==context.root.decode_u32(4) and result.context_after.queue_records.decode_u32(4)==context.root.decode_u32(0),"Message backend stamps the one shared source date/clock")
		check(result.context_after.nodes==context.nodes and result.context_after.scratch_words==context.scratch_words and result.context_after.watched_index_u8==77,"Message projection preserves independent event/task/scratch/watched owners")
	check(var_to_bytes([context,command])==frozen,"Message context and explicit packet are read-only inputs")
	var cold_command:Dictionary=JSON.parse_string(JSON.stringify(Scan.json_value(command)));var cold_done:Dictionary=JSON.parse_string(JSON.stringify(Scan.json_value(done)))
	check(invoked(Services.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(context)))),cold_command,cold_done).ok,"Message packet and text callbacks replay through cold service codecs")
func owner_controls()->void:
	var context:=registered(base(),[22,0,17,301,11,12]);var command:=player_command("F61",17);var done:=complete(context,command,Callable(self,"event_policy"));var owner:=State.new()
	check(done.result.ok and owner.configure(context),"One complete raw owner configures the nested Player/Events service")
	var core:=owner.raw_core();check(core.keys()==["context"] and core.context.size()==19 and core.context.root is String and core.context.bank is String and core.context.scratch_words is String,"Initial packed owners are canonical hex and occur only once in the saved core")
	check(not core.context.has("player_context") and not core.context.has("events_context") and not core.context.has("flags") and not core.context.has("packet"),"Kernel projections and transient packets are not duplicated persistent owners")
	var before:=Clock._hash(owner.snapshot());var first:=prepared(owner,command,done)
	check(first.get("ok",false) and Clock._hash(owner.snapshot())==before,"Nested event service prepares privately")
	if not first.get("ok",false):return
	check(owner.commit(first) and owner.generation()==1 and same(owner.raw_context(),done.result.context_after),"Verified nested callbacks publish exactly their actual shared result")
	check(not owner.commit(first),"A consumed service capability cannot be committed twice")
	var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))) and same(cold.raw_context(),owner.raw_context()),"Full event tree,32-byte scratch, external watcher and queue owners replay after cold JSON restore")
	var next_command:=message_command(packet());var next:=complete(owner.raw_context(),next_command);var hot_prepared:=prepared(owner,next_command,next);var cold_prepared:=prepared(cold,next_command,next)
	check(hot_prepared.get("ok",false) and cold_prepared.get("ok",false) and Clock._hash(hot_prepared.receipt)==Clock._hash(cold_prepared.receipt),"Hot and cold states produce the same receipt for the next message operation")
	if hot_prepared.get("ok",false) and cold_prepared.get("ok",false):check(owner.commit(hot_prepared) and cold.commit(cold_prepared) and same(owner.raw_context(),cold.raw_context()),"Message submission publishes identical ring contents after hot/cold continuation")
	var stable:=Clock._hash(owner.snapshot());var copy:=owner.raw_context();copy.scratch_words[0]=int(copy.scratch_words[0])^1;copy.watched_index_u8=0
	check(not same(copy,owner.raw_context()) and Clock._hash(owner.snapshot())==stable,"Read access returns private owner copies")
	var forged:=owner.snapshot();var queue:PackedByteArray=str(forged.core.context.queue_records).hex_decode();queue[0]=int(queue[0])^1;forged.core.context.queue_records=queue.hex_encode();forged=signed_save(forged)
	check(not owner.restore(forged) and Clock._hash(owner.snapshot())==stable,"A rehashed forged queue cannot bypass command replay")
	var other:=complete(owner.raw_context(),event_command("F50"));var candidate:=prepared(owner,event_command("F50"),other)
	check(candidate.get("ok",false),"Another valid service candidate exists for receipt checks")
	if candidate.get("ok",false):
		var wrong:Dictionary=candidate.duplicate(true);wrong.receipt.raw_state_after_sha256="forged";check(not owner.commit(wrong) and Clock._hash(owner.snapshot())==stable,"A forged service receipt cannot publish state")
	var aba:=State.new();check(aba.configure(context),"ABA owner is initialized from the same raw context")
	var token:=prepared(aba,command,done);check(token.get("ok",false) and aba.configure(context) and not aba.commit(token),"Reconfigure to identical bytes invalidates an earlier prepared capability")
	for bad:Variant in [null,true,0,[],{},"save"]:check(not owner.restore(bad) and not owner.commit(bad),"Malformed save and commit containers reject without script errors")
	for bad:Variant in [null,true,0,[],"nested"]:
		var save:=owner.snapshot();save.core=bad;check(not owner.restore(signed_save(save)),"Malformed nested core rejects")
		save=owner.snapshot();save.core.context=bad;check(not owner.restore(signed_save(save)),"Malformed nested service context rejects")
		save=owner.snapshot();save.last_witness=bad;check(not owner.restore(signed_save(save)),"Malformed nested witness rejects")
		save=owner.snapshot();save.last_witness.before_core=bad;check(not owner.restore(signed_save(save)),"Malformed witness before-core rejects")
		save=owner.snapshot();save.last_witness.payload=bad;check(not owner.restore(signed_save(save)),"Malformed witness payload rejects")
	check(Clock._hash(owner.snapshot())==stable,"All malformed cold data leave the active service owner intact")
func invalid_controls()->void:
	var context:=base();var command:=event_command("F50");var original:=var_to_bytes(context)
	for bad:Variant in [null,true,0,"context",[],{},bytes(0)]:check(not Services.execute(bad,command).ok,"Malformed service contexts reject")
	for key:String in Services.KEYS:
		var wrong:Dictionary=context.duplicate(true);wrong.erase(key);check(not Services.execute(wrong,command).ok,"Every shared owner is explicitly present: "+key)
	for key:String in ["root","bank","event_registers","module_entries","arena","scratch_words","queue_records","queue_control","fallback_name"]:
		var wrong:Dictionary=context.duplicate(true);wrong[key]=bytes(context[key].size()-1);check(not Services.execute(wrong,command).ok,"A truncated raw service owner rejects: "+key)
	for bad:Variant in [null,true,0,"command",[],{}, {"kind":1},{"kind":"missing"}]:check(not Services.execute(context,bad).ok,"Malformed or unknown command kinds reject")
	for bad:Variant in [null,true,0,[],{},"F999"]:
		check(not Services.execute(context,{"kind":"events","operation":bad,"args":[]}).ok,"Malformed event operation rejects")
		check(not Services.execute(context,{"kind":"player","operation":bad,"payload":{"code_u32":0,"body_slot_u32":1,"index_u8":17}}).ok,"Malformed player operation rejects")
		check(not Services.execute(context,{"kind":"message","operation":bad,"packet":packet(),"display_mode_s32":1}).ok,"Malformed message operation rejects")
	for bad:Variant in [null,true,0,{},[{}],[{"call_index_u32":-1,"observations":[]}],[{"call_index_u32":0,"observations":{}}]]:check(not Services.execute(context,player_command("F61",17),[],bad).ok,"Malformed nested event packets reject")
	for bad:Variant in [null,true,0,{},"bad",[{}]]:check(not Services.execute(context,command,bad).ok,"Malformed callback traces reject")
	var wrong:Dictionary=context.duplicate(true);wrong["Root_EF_alias"]=77;check(not Services.execute(wrong,command).ok,"An invented watcher/Root alias cannot enter the context")
	wrong=context.duplicate(true);wrong.scratch_words=bytes(28);check(not Services.execute(wrong,command).ok,"A historical28-byte event scratch cannot stand in for the complete32-byte source window")
	wrong=context.duplicate(true);wrong.queue_control.encode_u32(24,10);check(not Services.execute(wrong,command).ok,"An out-of-ring queue cursor rejects before unrelated services execute")
	for bad:Variant in [null,true,0,[],{},bytes(47)]:check(not Services.execute(context,{"kind":"message","operation":"F349","packet":bad,"display_mode_s32":1}).ok,"Messages always require an explicit complete packet")
	var registered_context:=registered(context,[22,0,17,400,1,2]);var player:=player_command("F61",17);var nested:=complete(registered_context,player)
	if nested.result.ok:
		var unused:Array=nested.event_packets.duplicate(true);unused.append(unused[-1].duplicate(true));check(not Services.execute(registered_context,player,nested.observations,unused).ok,"An extra nested event packet cannot silently succeed")
	check(var_to_bytes(context)==original,"Invalid commands and witnesses preserve caller owners")
func buffer(reference:String)->PackedByteArray:
	if hydrated.has(reference):return hydrated[reference].duplicate()
	var entry:Dictionary=buffer_pool[reference];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(raw)
	check(raw.size()==int(entry.byte_count) and hasher.finish().hex_encode()==reference,"A native composition buffer retains its exact bytes and SHA")
	hydrated[reference]=raw.duplicate();return raw
func hydrate_context(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true)
	for field:String in ["root","bank","event_registers","module_entries","arena","scratch_words","queue_records","queue_control","fallback_name","packet"]:
		if result.has(field):result[field]=buffer(str(result[field]))
	if result.has("task_variables"):
		for key:String in result.task_variables:result.task_variables[key]=buffer(str(value.task_variables[key]))
	return result
func hydrate_observations(value:Array)->Array:
	var result:Array=[]
	for source:Dictionary in value:
		var row:Dictionary={"kind":source.kind,"args":source.args.duplicate(),"before":hydrate_context(source.before),"after":hydrate_context(source.after)}
		for key:String in ["return_u32","registry_actions","input_text_hex","output_text_hex"]:
			if source.has(key):row[key]=source[key].duplicate(true) if source[key] is Array else source[key]
		result.append(row)
	return result
func hydrate_packets(value:Array)->Array:
	var result:Array=[]
	for source:Dictionary in value:result.append({"call_index_u32":int(source.call_index_u32),"observations":hydrate_observations(source.observations)})
	return result
func words(value:Array)->Array:
	var result:Array=[]
	for word:Variant in value:result.append(words(word) if word is Array else int(word))
	return result
func native_controls()->void:
	check(FileAccess.file_exists(FIXTURE),"Independent services composition fixture is present")
	if not FileAccess.file_exists(FIXTURE):return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Native services fixture is pinned to the original instruction proof")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));buffer_pool=fixture.buffers;dependencies=fixture.proof.source_dependencies_sha256.duplicate(true)
	check(fixture.profile==Services.PROFILE and int(fixture.case_count)==fixture.cases.size() and fixture.buffer_codec=="sha256-zlib-base64-v1","Native services profile, codec and actual unique case count match")
	check(int(fixture.proof.fresh_process_runs_each_call)==3 and fixture.proof.reverse_native_calls_verified and not fixture.proof.expected_arithmetic_calculated_in_python and fixture.proof.all_native_guards_verified,"Composition expectations come from fresh, guarded original procedures with reverse-stream replay")
	for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Native composition source dependency remains pinned: "+path)
	var previous:Dictionary={};var previous_owner:RefCounted;var event_count:=0;var backend_count:=0;var shared_count:=0;var signed_count:=0;var bindings:=0
	for row:Dictionary in fixture.cases:
		var name:String=row.name;var context:=Services.decode_context(hydrate_context(row.context_before));var expected:=Services.decode_context(hydrate_context(row.expected.context_after));var observations:=hydrate_observations(row.observations);var packets:=hydrate_packets(row.event_packets);var command:Dictionary=row.command.duplicate(true)
		check(not context.is_empty() and not expected.is_empty(),"Native contexts retain every shared owner: "+name)
		if context.is_empty() or expected.is_empty():continue
		var owner:=State.new();var chained:bool=row.get("carries_previous_native_state",false)
		if chained:
			shared_count+=1;check(not previous.is_empty() and same(context,previous),"Native continuation carries the preceding actual owner, including clock, bank and ring: "+name)
			owner=previous_owner
		else:check(owner.configure(context),"A complete native owner configures without invented fields: "+name)
		var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))),"Native owner can be cold-restored before its next command: "+name)
		var frozen:=var_to_bytes([context,command,observations,packets]);var result:=Services.execute(context,command,observations,packets)
		check(result.get("ok",false),"Actual source services complete the measured composition: "+name+" "+str(result.get("reason","")))
		if not result.get("ok",false):continue
		if name=="temporary-dispatch/index-0":
			check(not Services.execute(context,command,observations,[]).ok,"Observed outer Player data cannot replace missing actual F48 callback witnesses")
			var wrong:Array=packets.duplicate(true);wrong[0].observations[0].before.scratch_words[0]=int(wrong[0].observations[0].before.scratch_words[0])^1
			check(not Services.execute(context,command,observations,wrong).ok,"A native nested callback for another scratch owner cannot continue")
		if name=="message/route-F349":
			var wrong:Array=observations.duplicate(true);wrong.append({"kind":"F271","args":[],"before":{},"after":{},"return_u32":0})
			check(not Services.execute(context,command,wrong).ok,"A supplied F271 observation cannot replace the executed original message-ring backend")
		native_cases+=1
		for key:String in Services.KEYS:check(result.context_after[key]==expected[key],"Complete native shared owner matches at "+key+": "+name)
		check(result.kernel_result.source_order==row.expected.kernel_result.source_order,"Outer kernel calls retain measured instruction order: "+name)
		if row.expected.kernel_result.get("return_defined",true):check(int(result.kernel_result.return_u32)==int(row.expected.kernel_result.return_u32),"Defined scalar return matches original composition: "+name)
		if row.expected.kernel_result.has("return_defined"):check(result.kernel_result.return_defined==row.expected.kernel_result.return_defined,"Outer void/scalar return distinction remains explicit: "+name)
		check(result.event_calls.size()==row.expected.event_calls.size(),"Every Player F48 is an actual event kernel invocation: "+name)
		for index in result.event_calls.size():
			var call:Dictionary=result.event_calls[index];var expected_call:Dictionary=row.expected.event_calls[index];event_count+=1
			check(call.source_order==expected_call.source_order and call.captured_callbacks==words(expected_call.captured_callbacks) and call.return_defined==false and not call.has("return_u32"),"Nested dispatch retains native captured callbacks, traversal and void return: "+name)
		backend_count+=result.kernel_result.source_order.count("F271")
		if row.has("packet_witness"):
			var witness:Dictionary=row.packet_witness;var bound:=Services.bind_message_packet(witness.pending,command.packet,witness.caller_kind);bindings+=1
			check(bound.ok and bound.packet.hex_encode()==command.packet and bound.defined_word_offsets_u32==words(witness.defined_word_offsets_u32),"Native caller binds its exact defined packet words and preserves all opaque bytes: "+name)
		if command.kind=="player" and command.operation=="F61" and int(command.payload.index_u8)==255 and not packets.is_empty() and not packets[0].observations.is_empty():
			signed_count+=1;check(packets[0].observations[0].before.temporary_event_index_s32==-1 and result.context_after.temporary_event_index_s32==0,"Original index255 uses signed temporary minus1 across actual unsigned F48 and then resets: "+name)
		check(var_to_bytes([context,command,observations,packets])==frozen,"Native execution preserves every supplied owner and callback witness: "+name)
		var hot_prepared:=owner.prepare(command,observations,packets);var cold_prepared:=cold.prepare(command,observations,packets)
		check(hot_prepared.get("ok",false) and cold_prepared.get("ok",false),"Measured native composition prepares in both hot and cold owners: "+name)
		if hot_prepared.get("ok",false) and cold_prepared.get("ok",false):
			check(Clock._hash(hot_prepared.receipt)==Clock._hash(cold_prepared.receipt),"Hot/cold composition receipts match: "+name)
			check(owner.commit(hot_prepared) and cold.commit(cold_prepared) and same(owner.raw_context(),expected) and same(cold.raw_context(),expected),"Only replay-verified native results publish all nineteen owners: "+name)
			var restored:=State.new();check(restored.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))) and same(restored.raw_context(),expected),"Completed native command replays after cold JSON restore: "+name)
		previous=expected;previous_owner=owner
	check(native_cases==int(fixture.case_count) and event_count==int(fixture.proof.actual_F48_calls) and backend_count==int(fixture.proof.actual_F271_calls),"All original native cases, nested event invocations and ring submissions were actually compared")
	check(shared_count==int(fixture.proof.shared_owner_steps) and shared_count>0 and signed_count>0 and bindings==int(fixture.proof.message_cases),"Coverage includes shared continuation, signed-byte dispatch and explicit caller packet witnesses")
	native_fixture_pending=false
func run()->void:
	direct_events();player_events();message_bindings();message_services();owner_controls();invalid_controls();native_controls()
	var sources:Dictionary={}
	for path:String in ["scripts/source_event_services.gd","scripts/source_event_services_state.gd","scripts/source_events.gd","scripts/source_events_state.gd","scripts/source_player_events.gd","scripts/source_messages.gd","scripts/source_damage_effects.gd","scripts/source_clock_pipeline.gd","tests/test_source_event_services.gd","tests/fixtures/source_event_services_native.json"]:
		if FileAccess.file_exists("res://"+path):sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	for name:String in ["composition-proof.json","player-composed-native.s","player-support.c","events-composed-native.s","events-support.c","messages-composed-native.s","messages-support.c"]:
		var path:String="validation/events-messages-2026-11-18/services-native-proof/"+name;sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var output:=FileAccess.open(REPORT,FileAccess.WRITE)
	if output:output.store_string(JSON.stringify({"profile":Services.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"native_fixture_pending":native_fixture_pending,"sources":sources,"directed_callbacks_are_explicit_test_providers":true,"Main_integrated":false,"full_mission_VM_executed":false},"\t"));output.close()
	print("SOURCE EVENT SERVICES TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
