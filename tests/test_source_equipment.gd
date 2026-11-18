extends SceneTree
const Equipment=preload("res://scripts/source_equipment.gd")
const Factory=preload("res://scripts/source_object_factory.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_equipment_native.json"
const FIXTURE_SHA:="3d3827bb66c49d640aea08c4238d738d470495192cbdf73eb161fcf2d02ddc63"
const REPORT:="res://build/current-test-reports/source-equipment.json"
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
	var value:=PackedByteArray();value.resize(count);return value
func context()->Dictionary:
	var model:=Factory.source_model(24);var root:=bytes(16384);root.encode_u32(0x24,0x12345678);root.encode_u32(0x28,0x456789ab)
	return {"root":root,"flags":bytes(115),"event_registers":bytes(284),"module_entries":bytes(168),"module_count_s32":0,"model_descriptors":{"24":str(model.descriptor_hex).hex_decode()},"physical_specs":{"24":str(model.physical_spec_hex).hex_decode()}}
func body()->PackedByteArray:
	var value:=bytes(338);value[0x86]=114;value[0x118]=255;value[0xd0]=4;value.encode_u32(0x82,24);return value
func complete(record:PackedByteArray,state:Dictionary,operation:String="F952",args:Array=[],mutator:Callable=Callable())->Dictionary:
	var observations:Array=[]
	for step in range(97):
		var result:=Equipment.execute(record,state,observations,operation,args)
		if result.get("ok",false) or not result.get("pending") is Dictionary:return {"result":result,"observations":observations}
		var pending:Dictionary=result.pending;var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0}
		if mutator.is_valid():mutator.call(row,step)
		observations.append(row)
	return {"result":{"ok":false,"reason":"test_callback_limit"},"observations":observations}
func json_value(value:Variant)->Variant:
	if value is PackedByteArray:return value.hex_encode()
	if value is Dictionary:
		var copy:Dictionary={}
		for key:Variant in value:copy[key]=json_value(value[key])
		return copy
	if value is Array:
		var copy:Array=[]
		for cell:Variant in value:copy.append(json_value(cell))
		return copy
	return value
func selector(row:Dictionary,_step:int)->void:
	if row.kind=="F349":row.after.body[0x118]=0
func packet(row:Dictionary,_step:int)->void:
	if row.kind=="F144_handler" and int(row.args[0])==2:row["payload_after_u32"]=[0xffffffff,0x80000000]
func standalone()->void:
	var record:=body();var state:=context();var original:=var_to_bytes([record,state])
	state.root.encode_u16(0x170,65535);state.root.encode_u32(0x118,0xffffffff);state.root.encode_u32(0x120,0x7fffffff)
	var result:=Equipment.execute(record,state,[],"F946",[1])
	check(result.ok and result.return_u32==0 and result.context_after.root.decode_u16(0x170)==0 and result.context_after.root.decode_u32(0x120)==0x80000000,"F946 preserves separate low16 and32bit modulo updates in the shared Root")
	check(result.body_after==record and state.root.decode_u16(0x170)==65535,"F946 does not mutate the supplied body or Root")
	state=context();record=body();record[0x118]=0;state.root.encode_u32(0x120,1);state.root.encode_u16(0x17e,2)
	result=Equipment.execute(record,state,[],"F951",[0])
	check(result.ok and result.context_after.root.decode_u16(0x17e)==1 and result.context_after.root.decode_u16(0x170)==1 and result.context_after.root.decode_u32(0x120)==1,"F951 removes one actual high-end cargo word and increments only original free-space word")
	state=context();record=body();state.root.encode_u32(0x120,1);state.root.encode_u16(0x170,2)
	var completed:=complete(record,state,"F951",[0]);result=completed.result
	check(result.ok and result.context_after.root.decode_u16(0x170)==2,"Overlapping cargo/free-space word is decremented then incremented in source order")
	check(not completed.observations.is_empty() and completed.observations[0].args==[0x98c8,0x8e1e,0xffffffff],"F951 walks literal indices37..0 across the source alias at cargo index30")
	state=context();record=body();record.encode_u32(0xc8,1<<13)
	result=Equipment.execute(record,state,[],"F933")
	check(result.ok and result.return_u32==0 and result.rng_calls_u32==29 and result.body_after==record,"F933 stops after29 real samples when only unreachable rotated bits are set")
	check(result.context_after.root!=state.root,"Rejected equipment samples still advance the single shared RNG")
	record=body();record.encode_u32(0xc8,0xffffffff);state=context();result=Equipment.execute(record,state,[],"F933")
	check(result.ok and result.rng_calls_u32==1 and result.return_u32 in Equipment.EQUIPMENT_NAMES and result.body_after.decode_u32(0xc8)!=0xffffffff and result.body_after.decode_u32(0xcc)!=0,"F933 chooses a source name and writes matching live availability/damage bits")
	record=body();record[0x118]=0;record[0xd0]=255;record.encode_u32(0x11e,0xdeadbeef);state=context();result=Equipment.execute(record,state,[],"F947")
	check(result.ok and result.body_after[0xd0]==0 and result.body_after.decode_u32(0x11e)==0 and result.context_after.root==state.root,"NPC drive loss does not dereference an unused negative drive index")
	result=Equipment.execute(record,state,[],"F948")
	check(result.ok and result.body_after[0xd0]==1 and result.context_after.root==state.root,"NPC downgrade preserves source opaque signed drive input without a player mass-table read")
	record=body();state=context();state.module_entries[16]=2;state.module_entries[24]=2
	completed=complete(record,state,"F944",[0x12345678,0x87654321]);result=completed.result
	check(result.ok and result.broadcast_calls_u32==2 and result.message_calls_u32==1 and completed.observations.size()==5,"F944 performs message and two distinct broadcasts when selector remainsFF")
	completed=complete(record,state,"F944",[1,2],Callable(self,"selector"));result=completed.result
	check(result.ok and result.broadcast_calls_u32==1 and result.body_after[0x118]==0 and completed.observations.size()==3,"F944 first broadcast is unconditional after message callback, while F943 rereads changed selector")
	completed=complete(record,state,"F943",[],Callable(self,"packet"));var args:Array=[]
	for row:Dictionary in completed.observations:args.append(row.args)
	check(completed.result.ok and args==[[2,2,23,0],[3,2,0xffffffff,0x80000000]],"F148 handlers see the same mutable two-word packet in source order")
	var decoded:Variant=Equipment.decode_observations(JSON.parse_string(JSON.stringify(json_value(completed.observations))))
	check(decoded is Array and Equipment.execute(record,state,decoded,"F943").ok,"Equipment callback packet mutation survives lossless cold JSON")
	for sample in [0x887,0x888,0x1c70,0x1c71,0x5554,0x5555]:
		record=body();record[0x118]=0;record.encode_u32(0xc8,0xffffffff);state=context();state.root.encode_u32(0x24,sample);state.root.encode_u32(0x28,0x1234567f)
		result=Equipment.execute(record,state,[],"F950");var selected:String="F947" if sample<0x888 else "F948" if sample<0x1c71 else "F949" if sample<0x5555 else "F945"
		check(result.ok and selected in result.source_order,"Unsigned16 original equipment probability boundary selects "+selected+" for "+str(sample))
	state=context();record=body();state.root.encode_u32(0x118,100000);state.root.encode_u32(0x120,100000);state.root.encode_u16(0x17e,65535)
	completed=complete(record,state);result=completed.result
	check(result.ok and "F951" in result.source_order and result.context_after.root.decode_u16(0x17e)==65534,"F952 routes selected player cargo through the actual descending inventory algorithm")
	record=body();record[0x118]=0;record.encode_u32(0x82,0xffffffff);state=context();result=Equipment.execute(record,state)
	check(result.ok and result.model_calls_u32==0,"NPC equipment path preserves an unused opaque model word")
	state=context();record=body();state.model_descriptors["24"].encode_u32(0x38,0)
	check(not Equipment.execute(record,state).ok,"An actual player physical-spec dereference requires a non-null source binding")
	state=context();record=body();var frozen:=var_to_bytes([record,state])
	for bad:Variant in [null,true,0,"body",[],{},bytes(337)]:check(not Equipment.execute(bad,state).ok,"Malformed equipment target rejects")
	for operation:Variant in [null,true,0,"F942","F953","",[]]:check(not Equipment.execute(record,state,[],operation).ok,"Unknown operation rejects")
	for args_value:Variant in [null,true,0,{},[1],[1,2,3],[-1,0],[0,0x100000000]]:check(not Equipment.execute(record,state,[],"F944",args_value).ok,"Invalid message raw operands reject")
	for key:String in Equipment.CONTEXT_KEYS:
		var broken:=state.duplicate(true);broken.erase(key);check(not Equipment.execute(record,broken).ok,"Every equipment context owner is required: "+key)
	for key:String in Equipment.BYTE_COUNTS:
		var broken:=state.duplicate(true);broken[key]=bytes(int(Equipment.BYTE_COUNTS[key])-1);check(not Equipment.execute(record,broken).ok,"Truncated raw owner rejects: "+key)
	for bad:Variant in [null,true,[],{"024":bytes(24)},{"24":bytes(23)}]:
		var broken:=state.duplicate(true);broken.physical_specs=bad;check(not Equipment.execute(record,broken).ok,"Invalid immutable physical-spec map rejects")
	check(var_to_bytes([record,state])==frozen,"All rejected equipment calls leave caller buffers unchanged")
	check(not original.is_empty(),"Test source snapshot covers real packed raw owners")
func buffer(reference:String)->PackedByteArray:
	if hydrated.has(reference):return hydrated[reference].duplicate()
	var entry:Dictionary=buffer_pool[reference];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(raw)
	check(raw.size()==int(entry.byte_count) and hasher.finish().hex_encode()==reference,"Native equipment raw owner buffer decodes to exact byte length and SHA")
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
	check(FileAccess.file_exists(FIXTURE),"Independent whole equipment native fixture exists")
	if not FileAccess.file_exists(FIXTURE):return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Equipment native fixture is pinned to its final source proof")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));buffer_pool=fixture.buffers;dependencies=fixture.source_dependencies_sha256.duplicate(true)
	check(fixture.profile==Equipment.PROFILE and int(fixture.case_count)==fixture.cases.size(),"Native equipment corpus retains its whole source procedure profile and unique case count")
	check(int(fixture.fresh_process_runs)==3 and int(fixture.reverse_repeat_cases)==int(fixture.case_count) and not fixture.expected_arithmetic_calculated_in_python and fixture.all_external_results_explicit,"Expected equipment owners and returns are measured by original procedures with guarded fresh/reverse executions")
	var masses:Array=[];var names:Array=[]
	for word:Variant in fixture.original_tables.DATA_007210.words_u32:masses.append(int(word))
	for word:Variant in fixture.original_tables.DATA_007211.words_u32:names.append(int(word))
	check(masses==Equipment.DRIVE_MASSES and names==Equipment.EQUIPMENT_NAMES,"Runtime uses all15 original masses and all30 original equipment-name words")
	for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Native equipment dependency remains pinned: "+path)
	var operations:Dictionary={};var carried:=0;var callbacks:=0;var mutable:=0
	for row:Dictionary in fixture.cases:
		var record:=buffer(str(row.body_before));var state:=hydrate_context(row.context_before);var observations:=hydrate_observations(row.observations);var original:=var_to_bytes([record,state,observations]);native_cases+=1
		var result:=Equipment.execute(record,state,observations,row.operation,row.args)
		check(result.ok,"Original equipment operation is supported: "+str(row.name))
		if not result.ok:continue
		var expected_body:=buffer(str(row.expected.body_after));var expected_context:=hydrate_context(row.expected.context_after);var requests:Array=[]
		for request:Dictionary in result.requests:requests.append({"kind":request.kind,"args":request.args})
		check(result.body_after==expected_body,"All338 original body bytes equal native equipment result: "+str(row.name))
		check(Equipment._same_context(result.context_after,expected_context),"Complete Root, flags, events, modules and immutable maps equal original equipment result: "+str(row.name))
		check(int(result.return_u32)==int(row.expected.return_u32) and int(result.return_s32)==int(row.expected.return_s32),"Native return bits and signed return are preserved: "+str(row.name))
		check(result.source_order==row.expected.source_order and int(result.observations_used)==int(row.expected.observations_used),"Actual source helper/RNG/message/module call order equals native execution: "+str(row.name))
		check(requests==row.expected.requests and result.requests==observations,"Full defined external requests and matched owner responses equal native execution: "+str(row.name))
		check(var_to_bytes([record,state,observations])==original,"Equipment parity does not mutate caller buffers or native callback evidence: "+str(row.name))
		operations[row.operation]=true
		if row.carries_previous_native_state:carried+=1
		callbacks+=observations.size()
		for observation:Dictionary in observations:
			if observation.has("payload_after_u32"):mutable+=1
	check(operations.size()==Equipment.OPERATIONS.size(),"Every original equipment helper and F952 entry is independently controlled")
	check(carried>=20 and callbacks>0,"Dependent native states carry shared RNG/inventory and exact external callback results")
func run()->void:
	standalone();native_controls();var sources:Dictionary={}
	for path:String in ["scripts/source_equipment.gd","scripts/source_global_rng.gd","scripts/source_damage.gd","scripts/source_object_factory.gd","tests/test_source_equipment.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if FileAccess.file_exists(FIXTURE):sources[FIXTURE.trim_prefix("res://")]=FileAccess.get_sha256(FIXTURE)
	for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"profile":Equipment.PROFILE,"native_cases":native_cases,"sources":sources,"Main_integrated":false,"full_world_effects_executed":false},"\t"));file.close()
	print("SOURCE EQUIPMENT TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
