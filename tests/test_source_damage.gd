extends SceneTree
const Damage=preload("res://scripts/source_damage.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_damage_native.json"
const FIXTURE_SHA:="d8f25e97a65c7b04eed8f13a9252758d8866b371a57d8f1e1872cc115a3789c3"
const REPORT:="res://build/current-test-reports/source-damage.json"
var checks:=0
var failures:=0
var native_cases:=0
var native_complete:=false
var buffer_pool:Dictionary={}
var hydrated:Dictionary={}
var dependencies:Dictionary={}
var kinds:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<26:push_error(message)
func bytes(count:int)->PackedByteArray:
	var result:=PackedByteArray();result.resize(count);return result
func context()->Dictionary:return {"root":bytes(16384),"flags":bytes(115),"event_registers":bytes(284),"module_entries":bytes(168),"module_count_s32":0,"model_descriptors":{}}
func body()->PackedByteArray:
	var result:=bytes(338);result[0x86]=1;result[0x87]=3;result.encode_u16(0xe0,50);result.encode_u16(0xe4,100);return result
func complete(record:PackedByteArray,amount:int,attacker:int,state:Dictionary,mutator:Callable=Callable())->Dictionary:
	var observations:Array=[]
	for step in range(65):
		var result:=Damage.execute(record,amount,attacker,state,observations)
		if result.get("ok",false):return {"result":result,"observations":observations}
		if not result.get("pending") is Dictionary:return {"result":result,"observations":observations}
		var pending:Dictionary=result.pending
		var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0}
		if mutator.is_valid():mutator.call(row,step)
		observations.append(row)
	return {"result":{"ok":false,"reason":"test_boundary_limit"},"observations":observations}
func filtered(row:Dictionary,_step:int)->void:
	if row.kind=="F48" and int(row.args[2])==12:row.after.context.event_registers.encode_u32(48,0xffffffff)
	if row.kind=="F1907":row.after.body[0x151]=128
func modules(row:Dictionary,_step:int)->void:
	if row.kind=="F144_handler" and int(row.args[1])==11:
		if int(row.args[0])==3:
			row.after.context.module_count_s32=12;row.after.context.module_entries[88]=4;row.after.body[0x86]=9
		else:row.after.context.module_count_s32=-1
	if row.kind=="F1907":row.after.body[0x118]=255
	if row.kind=="F144_handler" and int(row.args[1])==2:row.after.context.root.encode_u32(0xc0,77)
func payload(row:Dictionary,_step:int)->void:
	if row.kind=="F144_handler" and int(row.args[1])==2 and int(row.args[0])==2:row.payload_after_u32=[0xffffffff,0x80000000]
func encode_context(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true)
	for key:String in Damage.BYTE_COUNTS:result[key]=value[key].hex_encode()
	for key:String in result.model_descriptors:result.model_descriptors[key]=value.model_descriptors[key].hex_encode()
	return result
func encode_observations(value:Array)->Array:
	var result:=value.duplicate(true)
	for row:Dictionary in result:
		for side:String in ["before","after"]:
			row[side].body=row[side].body.hex_encode();row[side].context=encode_context(row[side].context)
	return result
func standalone()->void:
	var record:=body();var state:=context();var before:=var_to_bytes([record,state]);var first:=Damage.execute(record,10,0,state)
	check(not first.ok and first.reason=="boundary_required" and first.pending.kind=="F48" and first.pending.args==[2,0,13],"F953 requires an explicit first F34 notification callback")
	check(first.pending.before.context.event_registers.decode_u32(52)==1 and first.pending.before.body==record,"Real F34 writes event13 before notifying F48")
	var whole:=complete(record,10,0,state);var got:Dictionary=whole.result
	check(got.ok and got.return_s32==1 and got.body_after.decode_u16(0xe0)==40 and got.body_after.decode_u16(0xe4)==100 and got.body_after[0x151]==1,"F953 shield path executes source shield subtraction and post-sound flag write")
	check(got.source_order==["F953","F34","F48","F34","F48","F34","F48","F35","F1907"] and got.observations_used==4,"All three F34 writes and actual F35 reread precede the shield sound boundary")
	check(var_to_bytes([record,state])==before,"Successful and pending pure damage kernels preserve supplied raw owners")
	got.body_after[0]=255;got.context_after.root[0]=255;got.context_after.event_registers[0]=255;got.context_after.module_entries[0]=255
	check(var_to_bytes([record,state])==before,"Returned damage/context buffers cannot alias caller-owned data")
	var altered:=complete(record,-1,0xffffffff,state,Callable(self,"filtered"));var filtered_result:Dictionary=altered.result
	check(filtered_result.ok and filtered_result.body_after.decode_u16(0xe0)==51 and filtered_result.body_after[0x151]==129,"Negative initial damage normalizes once; callback-filtered negative register12 stays signed and wraps the shield word")
	check(filtered_result.context_after.event_registers.decode_u32(56)==0xffffffff and filtered_result.context_after.event_registers.decode_u32(48)==0xffffffff,"F34 writes attacker bits and F35 observes the actual filtered damage register")
	var physical:=record.duplicate();physical[0x87]=11;var models:=context();var descriptor:=bytes(68);descriptor.encode_u32(0x38,1);models.model_descriptors={"0":descriptor}
	var physical_result:Dictionary=complete(physical,10,0,models).result
	check(physical_result.ok and physical_result.model_calls_u32==1 and physical_result.body_after.decode_u16(0xe0)==40,"Type11 reads the currently supplied model descriptor through actual F1538")
	var excluded:=context();excluded.flags[1]=16;var excluded_result:Dictionary=complete(physical,10,0,excluded).result
	check(excluded_result.ok and excluded_result.model_calls_u32==0 and excluded_result.body_after.decode_u16(0xe0)==50,"Flag16 type11 bypasses model lookup and hull/shield response exactly as source")
	var unavailable:Dictionary=complete(physical,10,0,context()).result
	check(not unavailable.ok and unavailable.reason=="damage_model_descriptor_unavailable","A required undeclared source model rejects instead of inventing a physical specification")
	var opaque_record:=record.duplicate();opaque_record.encode_u32(0x82,0xffffffff)
	check(complete(opaque_record,1,0,state).result.ok,"Type3 keeps unused full32-bit model identifiers opaque")
	var unsupported_record:=physical.duplicate();unsupported_record.encode_u32(0x82,149);var unsupported_state:=context();unsupported_state.model_descriptors={"149":descriptor}
	var unsupported_result:Dictionary=complete(unsupported_record,1,0,unsupported_state).result
	check(not unsupported_result.ok and unsupported_result.reason=="unsupported_damage_model_index","An actual F1538 read outside current source catalog0..148 rejects even if an opaque extra key was supplied")
	var module_state:=context();module_state.module_count_s32=4;module_state.module_entries[0]=4;module_state.module_entries[24]=4;module_state.module_entries[160]=2
	var dynamic:=complete(record,1,0,module_state,Callable(self,"modules"));var dynamic_result:Dictionary=dynamic.result
	check(dynamic_result.ok and dynamic_result.context_after.module_count_s32==-1 and dynamic_result.context_after.root.decode_u32(0xc0)==77,"Dynamic preloop count and fixed21-entry F148 broadcast observe callback-written module/root state")
	var module_requests:Array=[]
	for row:Dictionary in dynamic.observations:
		if row.kind=="F144_handler":module_requests.append(row.args)
	check(module_requests==[[3,11,1,1],[11,11,1,9],[20,2,23,0]],"Actual dispatcher skips null0; handlers reread changed body/flags; F148 visits20 independently of negative dynamic count")
	var cold:Variant=Damage.decode_observations(JSON.parse_string(JSON.stringify(encode_observations(dynamic.observations))))
	var resumed:=Damage.execute(record,1,0,module_state,cold)
	check(resumed.ok and resumed.body_after==dynamic_result.body_after and Damage._same_context(resumed.context_after,dynamic_result.context_after),"Lossless JSON observations decode to the exact source continuation")
	var player:=record.duplicate();player[0x118]=255;var broadcast_state:=context()
	for index in [2,3,20]:broadcast_state.module_entries[index*8]=2
	var packet:=complete(player,1,0,broadcast_state,Callable(self,"payload"));var handler_args:Array=[]
	for row:Dictionary in packet.observations:
		if row.kind=="F144_handler":handler_args.append(row.args)
	check(packet.result.ok and handler_args==[[2,2,23,0],[3,2,0xffffffff,0x80000000],[20,2,0xffffffff,0x80000000]],"F148 reuses the same mutable two-word stack packet across later original handlers")
	var packet_cold:Variant=Damage.decode_observations(JSON.parse_string(JSON.stringify(encode_observations(packet.observations))))
	check(Damage.execute(player,1,0,broadcast_state,packet_cold).ok,"Optional F148 payload writes survive cold JSON continuation without becoming persistent context owners")
	for bad:Variant in [null,true,[],[0],[0,0,0],[-1,0],[0,0x100000000],[0,0.5],[0,"0"]]:
		var broken:Array=packet.observations.duplicate(true)
		for row:Dictionary in broken:
			if row.has("payload_after_u32"):row.payload_after_u32=bad
		check(not Damage.execute(player,1,0,broadcast_state,broken).ok,"Invalid F148 payload output rejects atomically")
	var wrong_payload:Array=whole.observations.duplicate(true);wrong_payload[0].payload_after_u32=[23,0]
	check(not Damage.execute(record,10,0,state,wrong_payload).ok,"Only event2 module handlers may write the F148 stack packet")
	for bad:Variant in [null,true,0,"raw",[],{},PackedByteArray()]:check(not Damage.execute(bad,0,0,state).ok,"Malformed raw damage body rejects")
	for bad:Variant in [null,true,NAN,INF,0.5,-0x80000001,0x80000000,"0"]:check(not Damage.execute(record,bad,0,state).ok,"Invalid signed damage amount rejects")
	for bad:Variant in [null,true,NAN,INF,0.5,-1,0x100000000,"0"]:check(not Damage.execute(record,0,bad,state).ok,"Invalid attacker word rejects")
	for key:String in Damage.CONTEXT_KEYS:
		var broken:=state.duplicate(true);broken.erase(key);check(not Damage.execute(record,0,0,broken).ok,"Missing damage owner rejects: "+key)
	for key:String in Damage.BYTE_COUNTS:
		var broken:=state.duplicate(true);broken[key]=bytes(int(Damage.BYTE_COUNTS[key])-1);check(not Damage.execute(record,0,0,broken).ok,"Truncated damage owner rejects: "+key)
	for bad:Variant in [{0:bytes(68)},{"00":bytes(68)},{"-1":bytes(68)},{"4294967296":bytes(68)},{"0":bytes(67)},{"0":[]},true,[]]:
		var broken:=state.duplicate(true);broken.model_descriptors=bad;check(not Damage.execute(record,0,0,broken).ok,"Undeclared model key/type/descriptor bytes reject")
	for bad:Variant in [null,true,NAN,INF,0.5,-0x80000001,22,0x80000000,"0"]:
		var broken:=state.duplicate(true);broken.module_count_s32=bad;check(not Damage.execute(record,0,0,broken).ok,"Unrepresentable or unsupported module count rejects")
	for change:String in ["kind","args","before","after","return_u32"]:
		var trace:Array=whole.observations.duplicate(true)
		if change=="kind":trace[0].kind="F144"
		elif change=="args":trace[0].args=[2,0,14]
		elif change=="before":trace[0].before.context.root[0]=1
		elif change=="after":trace[0].after.body=bytes(337)
		else:trace[0].return_u32=-1
		check(not Damage.execute(record,10,0,state,trace).ok,"Mismatched explicit damage observation rejects atomically: "+change)
	var unused:Array=whole.observations.duplicate(true);unused.append(unused[-1].duplicate(true))
	check(not Damage.execute(record,10,0,state,unused).ok,"Unused callback observations reject instead of silently applying effects")
	check(var_to_bytes([record,state])==before,"Every invalid damage delivery preserves original caller owners")
func buffer(reference:String)->PackedByteArray:
	if hydrated.has(reference):return hydrated[reference].duplicate()
	var entry:Dictionary=buffer_pool[reference];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(raw)
	check(raw.size()==int(entry.byte_count) and hasher.finish().hex_encode()==reference,"Lossless native buffer pool decodes with its exact byte count and SHA256")
	hydrated[reference]=raw.duplicate();return raw
func hydrate_context(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true)
	for key:String in Damage.BYTE_COUNTS:result[key]=buffer(str(value[key]))
	for key:String in result.model_descriptors:result.model_descriptors[key]=buffer(str(value.model_descriptors[key]))
	return result
func hydrate_observations(value:Array)->Array:
	var result:Array=[]
	for source:Dictionary in value:
		var row:Dictionary={"kind":source.kind,"args":source.args.duplicate(),"return_u32":source.return_u32}
		if source.has("payload_after_u32"):row.payload_after_u32=source.payload_after_u32.duplicate()
		for side:String in ["before","after"]:row[side]={"body":buffer(str(source[side].body)),"context":hydrate_context(source[side].context)}
		result.append(row)
	return result
func native_controls()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Whole original F953 native fixture is pinned")
	if not FileAccess.file_exists(FIXTURE):return
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));buffer_pool=fixture.buffers;dependencies=fixture.get("source_dependencies_sha256",{})
	check(int(fixture.case_count)==fixture.cases.size() and int(fixture.fresh_process_runs)==3 and int(fixture.reverse_repeat_cases)==fixture.cases.size(),"Native damage controls include three fresh processes and complete reverse-order replay")
	check(fixture.expected_arithmetic_calculated_in_python==false and fixture.all_external_results_explicit==true and int(fixture.consecutive_shared_root_cases)>0,"Native arithmetic and all external outcomes are explicit, including interleaved shared Root continuation")
	var dispatched:Dictionary={2:[],11:[]}
	check(fixture.original_module_registry.size()==21,"Native original pointer registry contains all21 source module tables")
	for entry:Dictionary in fixture.original_module_registry:
		var span:=str(entry.span_hex).hex_decode();var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(span)
		check(span.size()==48 and hasher.finish().hex_encode()==str(entry.span_sha256) and span.decode_u32(8)==int(entry.event2_handler_va_u32) and span.decode_u32(44)==int(entry.event11_handler_va_u32),"Original event2/11 table words agree with complete captured source span")
		if int(entry.event2_handler_va_u32)!=0:dispatched[2].append(int(entry.module_index_u32))
		if int(entry.event11_handler_va_u32)!=0:dispatched[11].append(int(entry.module_index_u32))
	check(dispatched[2]==Damage.HANDLER_MODULES[2] and dispatched[11]==Damage.HANDLER_MODULES[11],"Runtime null/non-null module routing exactly equals captured original pointer tables")
	for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Native damage reproduction dependency is pinned: "+path)
	for row:Dictionary in fixture.cases:
		if row.operation!="damage":continue
		var record:=buffer(str(row.body_before));var state:=hydrate_context(row.context_before);var observations:=hydrate_observations(row.observations);var before:=var_to_bytes([record,state,observations])
		var result:=Damage.execute(record,row.damage_s32,row.attacker_u32,state,observations);native_cases+=1
		check(result.ok,"Actual original F953 invocation completes: "+str(row.name))
		if not result.ok:continue
		check(result.body_after==buffer(str(row.expected.body_after)) and Damage._same_context(result.context_after,hydrate_context(row.expected.context_after)),"All raw F953 body/root/flag/event/module words equal original native output: "+str(row.name))
		check(int(result.return_u32)==int(row.expected.return_u32) and int(result.return_s32)==int(row.expected.return_s32),"Original F953 return word including F942/F952 propagation matches: "+str(row.name))
		check(result.source_order==row.expected.source_order and int(result.observations_used)==int(row.expected.observations_used),"All actual F953/F34/F35/F1538/F148/RNG/callback ordering matches native: "+str(row.name))
		var requests_match:bool=result.requests.size()==row.expected.requests.size()
		for index in range(mini(result.requests.size(),row.expected.requests.size())):
			requests_match=requests_match and result.requests[index].kind==row.expected.requests[index].kind and Damage._same_args(result.requests[index].args,row.expected.requests[index].args)
		check(requests_match,"Every canonical handler/sound/fatal/equipment request equals original native payload: "+str(row.name))
		check(var_to_bytes([record,state,observations])==before,"Native damage replay preserves all caller-owned raw inputs: "+str(row.name))
		if not observations.is_empty():
			var prefix:=observations.slice(0,observations.size()-1);var pending:=Damage.execute(record,row.damage_s32,row.attacker_u32,state,prefix);var last:Dictionary=observations[-1]
			check(not pending.ok and pending.get("pending") is Dictionary and pending.pending.kind==last.kind and Damage._same_args(pending.pending.args,last.args) and Damage._same_snapshot(pending.pending.before,last.before),"Unobserved final callback exposes the exact original native pending state: "+str(row.name))
		for request:Dictionary in result.requests:kinds[request.kind]=true
		var cold:Variant=Damage.decode_observations(JSON.parse_string(JSON.stringify(encode_observations(observations))))
		var again:=Damage.execute(record,row.damage_s32,row.attacker_u32,state,cold)
		check(again.ok and again.body_after==result.body_after and Damage._same_context(again.context_after,result.context_after) and again.source_order==result.source_order,"Cold JSON observations retain every callback-dependent source continuation: "+str(row.name))
	check(native_cases>0 and kinds.has("F48") and kinds.has("F144_handler") and kinds.has("F1907") and kinds.has("F942") and kinds.has("F952"),"Native damage controls execute every explicit callback kind")
	native_complete=true
func run()->void:
	standalone();native_controls();check(native_complete,"Complete independent native damage controls return normally")
	var sources:Dictionary={}
	for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in ["scripts/source_damage.gd","scripts/source_global_rng.gd","tests/test_source_damage.gd",FIXTURE.trim_prefix("res://")]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"profile":Damage.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"callback_kinds":kinds.keys(),"sources":sources,"Main_integrated":false,"physical_device_tested":false},"\t"));file.close()
	print("SOURCE DAMAGE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
