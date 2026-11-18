extends SceneTree
const State=preload("res://scripts/source_events_state.gd")
const Events=preload("res://scripts/source_events.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_events_native.json"
const FIXTURE_SHA:="eb7bc02bc0d8ae9abbc8fd43149acf7742a79c11a31e6d7a44ffb1698a4bb2c5"
const REPORT:="res://build/current-test-reports/source-events-state.json"
var checks:=0
var failures:=0
var native_cases:=0
var native_total_cases:=0
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
func digest(value:Dictionary)->String:return Clock._hash(value)
func sign_snapshot(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true);result.erase("snapshot_sha256");result["snapshot_sha256"]=digest(result);return result
func complete(owner:RefCounted,operation:String,args:Array=[])->Dictionary:
	var observations:Array=[]
	for step in range(257):
		var prepared:Dictionary=owner.prepare(operation,args,observations)
		if prepared.get("ok",false) or not prepared.get("pending") is Dictionary:return {"prepared":prepared,"observations":observations}
		var pending:Dictionary=prepared.pending;var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0}
		if row.kind=="F53":row.after.arena.encode_u32(int(row.args[0])*36,1)
		if row.kind=="event_callback":row.after.event_registers.encode_u32(48,0x87654321);row.after.bank[100]=33;row.after.temporary_event_index_s32=-7;row.after.scratch_words[0]=99
		observations.append(row)
	return {"prepared":{"ok":false},"observations":observations}
func standalone()->void:
	var source:=context();var owner:=State.new();check(not owner.is_active() and owner.snapshot().is_empty(),"A new event owner is inactive")
	check(owner.configure(source) and owner.generation()==0,"One complete event context configures without duplicate Root, bank or temporary fields")
	var original:=digest(owner.snapshot());var prepared:=owner.prepare("F44",[22,0,7,100,10,1])
	check(prepared.ok and digest(owner.snapshot())==original,"Registration prepares privately without changing the live tree")
	if prepared.ok:
		var candidate:RefCounted=prepared.candidate_state;check(candidate.raw_context().nodes.size()==1 and candidate.raw_context().tree_root_u32==1,"A private registration candidate owns its actual logical links and node ID")
		check(owner.commit(prepared) and not owner.commit(prepared),"One event registration token commits exactly once")
		var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))),"Registered tree restores from lossless JSON by repeating the original operation")
		check(Events._same_context(cold.raw_context(),owner.raw_context()),"All shared raw buffers, logical tree nodes and task definitions match after cold restore")
		var hot_next:=owner.prepare("F44",[22,0,7,100,10,1]);var cold_next:=cold.prepare("F44",[22,0,7,100,10,1])
		check(hot_next.ok and cold_next.ok and digest(hot_next.receipt)==digest(cold_next.receipt),"Hot and cold registration duplicates produce the same next logical node")
		check(owner.commit(hot_next) and cold.commit(cold_next) and digest(owner.snapshot())==digest(cold.snapshot()),"Complete second publications converge across cold owners")
		var altered:=owner.snapshot();altered.core.context.nodes["2"].key_u32[3]=101;altered=sign_snapshot(altered)
		check(not cold.restore(altered),"A recomputed save hash cannot conceal changed node payloads after the witnessed source step")
		var done:=complete(owner,"F48",[22,0,7]);check(done.prepared.ok,"Two captured VM callbacks can prepare a complete owned dispatch")
		if done.prepared.ok:
			var before:=digest(owner.snapshot());var forged:Dictionary=done.prepared.duplicate();forged.receipt=done.prepared.receipt.duplicate(true);forged.receipt.captured_callbacks=[]
			check(not owner.commit(forged) and digest(owner.snapshot())==before,"A forged dispatch receipt cannot publish a valid candidate")
			check(owner.commit(done.prepared),"The authentic callback dispatch commits")
			var restored:=State.new();check(restored.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))),"Captured callback snapshots and mutated shared owners replay after cold JSON")
			check(restored.raw_context().temporary_event_index_s32==-7 and restored.raw_context().bank[100]==33 and restored.raw_context().event_registers.decode_u32(48)==0x87654321 and restored.raw_context().scratch_words[0]==99,"Only the declared single owners carry callback and separate scratch mutations through loading")
			var prefix:Array=done.observations.slice(0,done.observations.size()-1);var fresh:=State.new();fresh.restore(cold.snapshot());var missing:=fresh.prepare("F48",[22,0,7],prefix)
			check(not missing.ok and missing.has("pending"),"A missing VM result remains a typed pending continuation rather than an implicit identity")
			var malformed:Array=done.observations.duplicate(true);malformed[0].after.definitions["0"].cleanup_instruction_u32=1
			var initial:=State.new();initial.restore(cold.snapshot());check(not initial.prepare("F48",[22,0,7],malformed).ok,"Readonly definition changes inside a callback transcript reject")
	var frozen:=digest(owner.snapshot())
	for bad:Variant in [null,true,0,"save",[],{}]:check(not owner.restore(bad) and not owner.commit(bad),"Malformed event save or token rejects")
	for operation:Variant in [null,true,0,"F41","F49","F52",[],"unknown"]:check(not owner.prepare(operation).ok,"Unsupported event operation cannot publish")
	for observations:Variant in [null,true,0,"trace",{},[{}]]:check(not owner.prepare("F48",[22,0,7],observations).ok,"Malformed callback witnesses reject")
	for field:String in ["schema","version","profile","generation","core","last_witness","snapshot_sha256"]:
		var broken:=owner.snapshot();broken.erase(field);check(not owner.restore(broken),"Incomplete event save rejects: "+field)
	check(digest(owner.snapshot())==frozen,"All malformed deliveries leave the active event owner unchanged")
	var raw:=context();raw.arena.encode_u16(6,65535);var tasks:=State.new();check(tasks.configure(raw),"Task owner with an imminent16bit generation wrap configures")
	prepared=tasks.prepare("F51",[0,123]);check(prepared.ok and prepared.receipt.allocated_slot_s32==0 and prepared.receipt.allocated_handle_u32==0,"Valid packed task handle0 is distinct from no allocated slot")
	if prepared.ok:
		check(tasks.commit(prepared),"Task allocation commits its real generation and variable handle")
		var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(tasks.snapshot()))),"Task arena and A5-filled owned variable bytes survive cold replay")
		var done:=complete(cold,"F54");check(done.prepared.ok and cold.commit(done.prepared),"Explicit VM activation drains from priority4 to the callback's live state")
		var next:=cold.prepare("F56");check(next.ok and cold.commit(next),"Task cleanup releases variable ownership through the source state machine")
		check(cold.raw_context().task_variables.is_empty() and cold.raw_context().arena.decode_u32(32)==1,"Cold released task retains a stale source token without retaining its freed variable owner")
	var other:=State.new();other.configure(source);prepared=owner.prepare("F50");check(prepared.ok and not other.commit(prepared),"Event tokens belong to their exact owner instance")
	owner.configure(owner.raw_context());check(not owner.commit(prepared),"Reconfiguration invalidates an older event token")
func buffer(reference:String)->PackedByteArray:
	if hydrated.has(reference):return hydrated[reference].duplicate()
	var entry:Dictionary=buffer_pool[reference];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(raw)
	check(raw.size()==int(entry.byte_count) and hasher.finish().hex_encode()==reference,"Native cold-event buffer preserves exact bytes and SHA")
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
func native_controls()->void:
	check(FileAccess.file_exists(FIXTURE),"Independent event native fixture exists for cold owner controls")
	if not FileAccess.file_exists(FIXTURE):return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Owned events fixture pinned to final original instruction proof")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));buffer_pool=fixture.buffers;dependencies=fixture.source_dependencies_sha256.duplicate(true);native_total_cases=int(fixture.case_count)
	check(int(fixture.fresh_process_runs)==3 and int(fixture.reverse_repeat_cases)==int(fixture.case_count) and not fixture.expected_arithmetic_calculated_in_python,"Owned events cases retain original native fresh/reverse execution provenance")
	for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Owned event native dependency remains pinned: "+path)
	var selected:Dictionary={};var compare_selected:Dictionary={}
	var directed:Array=["insert-stream/00","insert-stream/01","allocate/65535/0","allocate-full-arena","allocate-first-hole/149","remove/leaf","remove/both-immediate","remove/both-deep","remove/duplicate","wrapped-remove/80000000","wrapped-remove/ffffffff"]
	for row:Dictionary in fixture.cases:
		if row.operation in ["F46","F48","F50","F54","F55"] or str(row.name).begins_with("task-reuse-stream/") or row.name in directed:selected[row.name]=true
		if row.operation in ["F42","F43"] and not compare_selected.has(row.operation):selected[row.name]=true;compare_selected[row.operation]=true
	check(selected.size()==64,"Cold cohort selects64 distinct cases spanning all11 operations, snapshot mutation, predecessor identity, wrapped search, scheduler priority, F55 scratch and20-step task reuse")
	var previous:RefCounted;var carried:=0;var operations:Dictionary={}
	for row:Dictionary in fixture.cases:
		if not selected.has(row.name):continue
		var raw:=hydrate_context(row.context_before);var observations:=hydrate_observations(row.observations);var original:=var_to_bytes([raw,observations]);native_cases+=1
		var owner:RefCounted=previous if row.get("carries_previous_native_state",false) and previous!=null else State.new()
		if row.get("carries_previous_native_state",false) and previous!=null:
			carried+=1;check(Events._same_context(owner.raw_context(),raw),"A dependent native event step resumes the preceding cold owner: "+str(row.name))
		else:check(owner.configure(raw),"Independent event context configures one owned state: "+str(row.name))
		var before:=digest(owner.snapshot());var generation:int=owner.generation();var prepared:Dictionary=owner.prepare(row.operation,row.args,observations)
		check(prepared.ok and digest(owner.snapshot())==before,"Native event delivery prepares privately: "+str(row.name))
		if not prepared.ok:continue
		var expected:=hydrate_context(row.expected.context_after);var candidate:RefCounted=prepared.candidate_state
		check(Events._same_context(candidate.raw_context(),expected),"All logical heap/task and shared-world owners equal native output: "+str(row.name))
		check(prepared.receipt.source_order==row.expected.source_order and bool(prepared.receipt.return_defined)==bool(row.expected.return_defined),"Owned source order and defined-result category match native execution: "+str(row.name))
		if row.expected.return_defined:check(int(prepared.receipt.return_u32)==int(row.expected.return_u32),"Owned wrapped comparator return matches native bits: "+str(row.name))
		if row.operation=="F51":check(int(prepared.receipt.allocated_slot_s32)==int(row.expected.allocated_slot_s32) and int(prepared.receipt.allocated_handle_u32)==int(row.expected.allocated_handle_u32),"Owned pointer/NULL allocation preserves the packed task generation separately: "+str(row.name))
		check(owner.commit(prepared) and owner.generation()==generation+1,"Native event operation publishes exactly one generation: "+str(row.name))
		var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))),"Native event witness replays through cold JSON: "+str(row.name))
		check(Events._same_context(cold.raw_context(),expected) and digest(cold.snapshot())==digest(owner.snapshot()),"Hot and cold native event owners coincide exactly: "+str(row.name))
		check(not owner.commit(prepared),"A published event token cannot commit twice: "+str(row.name))
		check(var_to_bytes([raw,observations])==original,"Owned native event publication does not mutate source evidence: "+str(row.name))
		if not observations.is_empty():
			var fresh:=State.new();fresh.configure(raw);var prefix:Array=observations.slice(0,observations.size()-1);var missing:Dictionary=fresh.prepare(row.operation,row.args,prefix);var last:Dictionary=observations[-1]
			check(not missing.ok and missing.get("pending") is Dictionary and missing.pending.kind==last.kind and Events._same_context(missing.pending.before,last.before),"Owned execution stops at the exact final missing native continuation: "+str(row.name))
		previous=cold;operations[row.operation]=true
	check(carried>=18 and operations.size()==Events.OPERATIONS.size(),"Cold controlled cohort covers every operation and the full dependent task generation stream")
func run()->void:
	standalone();native_controls();var sources:Dictionary={}
	for path:String in ["scripts/source_events.gd","scripts/source_events_state.gd","scripts/source_clock_pipeline.gd","tests/test_source_events_state.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if FileAccess.file_exists(FIXTURE):sources[FIXTURE.trim_prefix("res://")]=FileAccess.get_sha256(FIXTURE)
	for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"native_cases":native_cases,"native_total_cases":native_total_cases,"sources":sources,"profile":State.PROFILE,"Main_integrated":false,"full_F41_VM_executed":false},"\t"));file.close()
	print("SOURCE EVENTS STATE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
