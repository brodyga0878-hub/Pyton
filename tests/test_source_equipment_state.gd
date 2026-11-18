extends SceneTree
const State=preload("res://scripts/source_equipment_state.gd")
const Equipment=preload("res://scripts/source_equipment.gd")
const Factory=preload("res://scripts/source_object_factory.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_equipment_native.json"
const FIXTURE_SHA:="3d3827bb66c49d640aea08c4238d738d470495192cbdf73eb161fcf2d02ddc63"
const REPORT:="res://build/current-test-reports/source-equipment-state.json"
var checks:=0
var failures:=0
var native_cases:=0
var native_total_cases:=0
var buffer_pool:Dictionary={}
var hydrated:Dictionary={}
var dependencies:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<25:push_error(message)
func bytes(count:int)->PackedByteArray:
	var value:=PackedByteArray();value.resize(count);return value
func base()->Dictionary:
	var model:=Factory.source_model(24);var root:=bytes(16384);root.encode_u32(0x24,0x12345678);root.encode_u32(0x28,0x456789ab)
	var record:=bytes(338);record[0x86]=114;record[0x118]=255;record[0xd0]=4;record.encode_u32(0x82,24);record.encode_u32(0xc8,0xffffffff)
	return {"body":record,"context":{"root":root,"flags":bytes(115),"event_registers":bytes(284),"module_entries":bytes(168),"module_count_s32":0,"model_descriptors":{"24":str(model.descriptor_hex).hex_decode()},"physical_specs":{"24":str(model.physical_spec_hex).hex_decode()}}}
func digest(value:Dictionary)->String:return Clock._hash(value)
func sign_snapshot(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true);result.erase("snapshot_sha256");result["snapshot_sha256"]=digest(result);return result
func complete(owner:RefCounted,operation:String="F952",args:Array=[],mutate:bool=false)->Dictionary:
	var observations:Array=[]
	for step in range(97):
		var prepared:Dictionary=owner.prepare_equipment(observations,operation,args)
		if prepared.get("ok",false) or not prepared.get("pending") is Dictionary:return {"prepared":prepared,"observations":observations}
		var pending:Dictionary=prepared.pending;var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0}
		if mutate and row.kind=="F144_handler" and int(row.args[0])==2:row["payload_after_u32"]=[0xffffffff,0x80000000]
		observations.append(row)
	return {"prepared":{"ok":false},"observations":observations}
func standalone()->void:
	var raw:=base();var owner:=State.new();check(not owner.is_active() and owner.snapshot().is_empty(),"New equipment owner is inactive")
	check(owner.configure(raw.body,raw.context),"All raw equipment owners configure atomically")
	var initial:=digest(owner.snapshot());var initial_body:=owner.raw_body();var initial_context:=owner.raw_context()
	check(owner.generation()==0 and owner.raw_context().root==raw.context.root,"Initial Root carries the sole shared RNG/inventory bytes")
	var prepared:=owner.prepare_equipment([],"F933")
	check(prepared.ok and digest(owner.snapshot())==initial,"Native equipment operation prepares a private state without changing the live owner")
	if prepared.ok:
		var direct:=Equipment.execute(raw.body,raw.context,[],"F933");var candidate:RefCounted=prepared.candidate_state
		check(candidate.raw_body()==direct.body_after and Equipment._same_context(candidate.raw_context(),direct.context_after),"Candidate contains the complete kernel body and shared Root result")
		check(owner.commit(prepared) and owner.generation()==1,"A matching equipment result commits once")
		check(not owner.commit(prepared),"Repeated stale equipment publication rejects")
		var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))),"Committed equipment state restores through lossless JSON and last-step replay")
		check(cold.raw_body()==owner.raw_body() and Equipment._same_context(cold.raw_context(),owner.raw_context()),"Cold restore preserves RNG, inventory, modules and readonly physical resources exactly")
		var next:=owner.prepare_equipment([],"F946",[3]);var cold_next:=cold.prepare_equipment([],"F946",[3])
		check(next.ok and cold_next.ok and digest(next.receipt)==digest(cold_next.receipt),"Restored equipment owner produces the same following inventory transaction")
		check(owner.commit(next) and cold.commit(cold_next) and digest(owner.snapshot())==digest(cold.snapshot()),"Hot and cold owners converge after a second complete publication")
		var forged:=owner.snapshot();var root:=str(forged.core.context.root).hex_decode();root[0x24]=int(root[0x24])^1;forged.core.context.root=root.hex_encode();forged=sign_snapshot(forged)
		check(not cold.restore(forged),"A recomputed envelope hash cannot hide altered post-step shared RNG")
	check(initial_body==raw.body and Equipment._same_context(initial_context,raw.context),"Stored source copies do not alias later live publications")
	var active_hash:=digest(owner.snapshot())
	for bad:Variant in [null,true,0,"save",[],{}]:check(not owner.restore(bad) and not owner.commit(bad),"Malformed save and prepared containers reject")
	for operation:Variant in [null,true,0,"F942","unknown",[]]:check(not owner.prepare_equipment([],operation).ok,"Unknown equipment command rejects")
	for bad:Variant in [null,true,0,"trace",{},[{}]]:check(not owner.prepare_equipment(bad).ok,"Malformed callback transcript rejects")
	for amount:Variant in [null,true,NAN,INF,0.5,-0x80000001,0x80000000,"0"]:check(not owner.prepare_equipment([],"F946",[amount]).ok,"Unrepresentable inventory arithmetic operand rejects")
	for key:String in ["schema","version","profile","generation","core","last_witness","snapshot_sha256"]:
		var broken:=owner.snapshot();broken.erase(key);check(not owner.restore(broken),"Incomplete owned save rejects: "+key)
	check(digest(owner.snapshot())==active_hash,"Every malformed delivery leaves the active equipment owner unchanged")
	owner=State.new();raw=base();raw.context.module_entries[16]=2;raw.context.module_entries[24]=2;check(owner.configure(raw.body,raw.context),"Mutable broadcast owner configured")
	var done:=complete(owner,"F944",[0x98ca,0],true);check(done.prepared.ok,"Owned F944 executes both real broadcasts with typed callbacks")
	if done.prepared.ok:
		var saved_before:=digest(owner.snapshot());var wrong:Dictionary=done.prepared.duplicate();wrong.receipt=done.prepared.receipt.duplicate(true);wrong.receipt.return_u32=0
		check(not owner.commit(wrong) and digest(owner.snapshot())==saved_before,"Forged equipment receipt cannot publish a candidate")
		check(owner.commit(done.prepared),"Original typed callback candidate commits")
		var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))),"Two broadcasts and mutable local packet replay in a cold owned witness")
		check(digest(cold.snapshot())==digest(owner.snapshot()),"Typed handler payload changes do not create extra persistent local packet owners")
		var restored:Dictionary=owner.snapshot();restored.last_witness.payload.observations[0].after.context.physical_specs["24"]="00".repeat(24);restored=sign_snapshot(restored)
		check(not cold.restore(restored),"Readonly physical-resource replacement inside a recomputed cold witness rejects")
		var other:=State.new();check(other.configure(raw.body,raw.context) and not other.commit(done.prepared),"A prepared result belongs to its exact equipment owner instance")
		var stale_owner:=State.new();stale_owner.configure(raw.body,raw.context);var stale:Dictionary=complete(stale_owner,"F944",[0x98ca,0],true).prepared;stale_owner.configure(raw.body,raw.context)
		check(not stale_owner.commit(stale),"Reconfiguration invalidates an otherwise matching equipment token")
func buffer(reference:String)->PackedByteArray:
	if hydrated.has(reference):return hydrated[reference].duplicate()
	var entry:Dictionary=buffer_pool[reference];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(raw)
	check(raw.size()==int(entry.byte_count) and hasher.finish().hex_encode()==reference,"Owned native equipment buffer retains exact byte count and SHA")
	hydrated[reference]=raw.duplicate();return raw
func hydrate_context(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true)
	for key:String in Equipment.BYTE_COUNTS:result[key]=buffer(str(value[key]))
	for field:String in ["model_descriptors","physical_specs"]:
		for key:String in result[field]:result[field][key]=buffer(str(value[field][key]))
	return Equipment._copy_context(result)
func hydrate_observations(value:Array)->Array:
	var result:Array=[]
	for source:Dictionary in value:
		var row:Dictionary={"kind":source.kind,"args":source.args.duplicate(),"return_u32":source.return_u32}
		if source.has("payload_after_u32"):row["payload_after_u32"]=source.payload_after_u32.duplicate()
		for side:String in ["before","after"]:row[side]={"body":buffer(str(source[side].body)),"context":hydrate_context(source[side].context)}
		result.append(row)
	return result
func native_controls()->void:
	check(FileAccess.file_exists(FIXTURE),"Independent whole equipment native fixture exists for owned cold controls")
	if not FileAccess.file_exists(FIXTURE):return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Owned equipment fixture is pinned to its final source proof")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));buffer_pool=fixture.buffers;dependencies=fixture.source_dependencies_sha256.duplicate(true)
	check(int(fixture.fresh_process_runs)==3 and int(fixture.reverse_repeat_cases)==int(fixture.case_count) and not fixture.expected_arithmetic_calculated_in_python and fixture.all_external_results_explicit,"Owned controls retain native full-procedure/reverse/fresh evidence")
	for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Owned native equipment dependency remains pinned: "+path)
	var selected:Dictionary={};var per_operation:Dictionary={}
	var directed:Array=["equipment-bit/13","equipment-bit/14","equipment-bit/15","equipment-hit-attempt29","cargo-selected/30","broadcast-local-packet/0","broadcast-local-packet/1","registry-event2/00","registry-event2/02","registry-event2/03","registry-event2/20"]
	for row:Dictionary in fixture.cases:
		var count:int=int(per_operation.get(row.operation,0))
		if count<2:selected[row.name]=true;per_operation[row.operation]=count+1
		if str(row.name).begins_with("dependent-stream/") or str(row.name).begins_with("callbacks/") or row.name in directed:selected[row.name]=true
	native_total_cases=int(fixture.case_count)
	check(selected.size()==64,"Owned native cohort contains64 stratified cases: all11 operations, callbacks, alias/lasttry/packet branches and the complete24-step dependent stream")
	var chain_owner:RefCounted;var carried:=0
	for row:Dictionary in fixture.cases:
		if not selected.has(row.name):continue
		var record:=buffer(str(row.body_before));var state:=hydrate_context(row.context_before);var observations:=hydrate_observations(row.observations);var original:=var_to_bytes([record,state,observations]);native_cases+=1
		var owner:RefCounted=chain_owner if row.carries_previous_native_state and chain_owner!=null else State.new()
		if row.carries_previous_native_state and chain_owner!=null:
			carried+=1;check(owner.raw_body()==record and Equipment._same_context(owner.raw_context(),state),"Dependent native equipment step resumes the preceding committed shared owner: "+str(row.name))
		else:check(owner.configure(record,state),"Independent native equipment target/context configure a single owner: "+str(row.name))
		var before:=digest(owner.snapshot());var generation:int=owner.generation();var prepared:Dictionary=owner.prepare_equipment(observations,row.operation,row.args)
		check(prepared.ok and digest(owner.snapshot())==before,"Native equipment delivery prepares privately: "+str(row.name))
		if not prepared.ok:continue
		var candidate:RefCounted=prepared.candidate_state;var expected_body:=buffer(str(row.expected.body_after));var expected_context:=hydrate_context(row.expected.context_after)
		check(candidate.raw_body()==expected_body and Equipment._same_context(candidate.raw_context(),expected_context),"Complete owned equipment body/context equals original native execution: "+str(row.name))
		check(int(prepared.receipt.return_u32)==int(row.expected.return_u32) and prepared.receipt.source_order==row.expected.source_order,"Owned receipt preserves original return and actual call sequence: "+str(row.name))
		check(owner.commit(prepared) and owner.generation()==generation+1,"Native equipment delivery commits one bounded generation: "+str(row.name))
		var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))),"Native equipment witness exactly replays after cold JSON: "+str(row.name))
		check(cold.raw_body()==expected_body and Equipment._same_context(cold.raw_context(),expected_context) and digest(cold.snapshot())==digest(owner.snapshot()),"Hot and cold full native equipment owners match: "+str(row.name))
		check(not owner.commit(prepared),"Published native equipment token cannot commit twice: "+str(row.name))
		check(var_to_bytes([record,state,observations])==original,"Owned equipment delivery leaves native inputs and callback records unchanged: "+str(row.name))
		if not observations.is_empty():
			var fresh:=State.new();fresh.configure(record,state);var prefix:Array=observations.slice(0,observations.size()-1);var pending:Dictionary=fresh.prepare_equipment(prefix,row.operation,row.args);var last:Dictionary=observations[-1]
			check(not pending.ok and pending.get("pending") is Dictionary and pending.pending.kind==last.kind and Equipment._same_snapshot(pending.pending.before,last.before),"Cold equipment replay stops at the exact final missing native callback: "+str(row.name))
		chain_owner=cold
	check(carried>=20,"Actual native dependent equipment stream survives successive cold owner publications")
func run()->void:
	standalone();native_controls();var sources:Dictionary={}
	for path:String in ["scripts/source_equipment.gd","scripts/source_equipment_state.gd","scripts/source_global_rng.gd","scripts/source_damage.gd","scripts/source_clock_pipeline.gd","tests/test_source_equipment_state.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if FileAccess.file_exists(FIXTURE):sources[FIXTURE.trim_prefix("res://")]=FileAccess.get_sha256(FIXTURE)
	for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"profile":State.PROFILE,"native_cases":native_cases,"native_total_cases":native_total_cases,"native_cases_separate":native_cases,"sources":sources,"Main_integrated":false,"full_world_effects_executed":false},"\t"));file.close()
	print("SOURCE EQUIPMENT STATE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
