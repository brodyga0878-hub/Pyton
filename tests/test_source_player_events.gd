extends SceneTree
const Player=preload("res://scripts/source_player_events.gd")
const FIXTURE:="res://tests/fixtures/source_player_events_native.json"
const FIXTURE_SHA:="783f55c6927dd1741d2659f1ecfecea1e285575d164374ca0b7d6e9f385ba82e"
const REPORT:="res://build/current-test-reports/source-player-events.json"
const PROOF:="res://validation/events-messages-2026-11-18/player-events-native-proof/"
var checks:=0
var failures:=0
var buffers:Dictionary={}
var hydrated:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<20:push_error(message)
func digest(value:Variant)->String:return var_to_bytes(value).hex_encode().sha256_text()
func zeros(count:int)->PackedByteArray:
	var value:=PackedByteArray();value.resize(count);return value
func context()->Dictionary:
	var root:=zeros(16384);root.encode_u32(0xc0,1);root[0x112]=17;root[0xef]=99;root[0xec]=17;root[0xed]=18;root[0xe8]=2;root[0xea]=5
	return {"root":root,"bank":zeros(38986),"event_registers":zeros(284),"temporary_event_index_s32":-7,"watched_index_u8":9}
func payload(code:int=0,index:int=17)->Dictionary:return {"code_u32":code,"body_slot_u32":17,"index_u8":index}
func complete(raw:Dictionary,p:Dictionary,operation:String="F1103",policy:Callable=Callable())->Dictionary:
	var replies:Array=[]
	for attempt in range(17):
		var result:=Player.execute(raw,p,replies,operation)
		if result.get("ok",false):return {"ok":true,"result":result,"observations":replies}
		if not result.get("pending") is Dictionary:return {"ok":false,"result":result,"observations":replies}
		var pending:Dictionary=result.pending;var after:Dictionary=pending.before.duplicate(true)
		if policy.is_valid():policy.call(pending.kind,after)
		replies.append({"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":after,"return_u32":0x13570000+int(str(pending.kind).substr(1))})
	return {"ok":false}
func temporary_policy(kind:String,after:Dictionary)->void:
	if kind=="F48":after.temporary_event_index_s32=123;after.event_registers.encode_u32(88,0xdeadbeef)
func reselect_policy(kind:String,after:Dictionary)->void:
	if kind=="F1097":after.root[0xec]=18;after.root[0xed]=17
func encode(value:Variant)->Variant:
	if value is PackedByteArray:return value.hex_encode()
	if value is Dictionary:
		var result:Dictionary={}
		for key:Variant in value:result[key]=encode(value[key])
		return result
	if value is Array:
		var result:Array=[]
		for item:Variant in value:result.append(encode(item))
		return result
	return value
func buffer(key:String)->PackedByteArray:
	if hydrated.has(key):return hydrated[key].duplicate()
	var entry:Dictionary=buffers[key];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE);var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(raw)
	check(raw.size()==int(entry.byte_count) and h.finish().hex_encode()==key,"Original owner bytes decode with exact SHA and length")
	hydrated[key]=raw.duplicate();return raw
func hydrate(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true)
	for key:String in Player.BUFFER_BYTES:result[key]=buffer(str(value[key]))
	result.temporary_event_index_s32=int(result.temporary_event_index_s32);result.watched_index_u8=int(result.watched_index_u8);return result
func native_controls(doc:Dictionary)->void:
	check(doc.profile==Player.PROFILE and int(doc.case_count)==doc.cases.size() and int(doc.case_count)==333,"Independent full original player event cases and profile match")
	check(int(doc.fresh_process_runs)==3 and int(doc.reverse_repeat_cases)==333 and int(doc.all_index_byte_values)==256 and not doc.expected_arithmetic_calculated_in_python,"All defined byte indices and independent fresh/reverse executions are retained")
	check(FileAccess.get_sha256(PROOF+"instruction-proof.json")==doc.instruction_proof_sha256,"Whole original instructions and data aliases remain pinned")
	for path:String in doc.source_dependencies_sha256:check(FileAccess.get_sha256("res://"+path)==doc.source_dependencies_sha256[path],"Independent source dependency matches: "+path)
	var seen:Dictionary={};var removals:=0;var cleanups:=0
	for row:Dictionary in doc.cases:
		var before:=hydrate(row.context_before);var expected:=hydrate(row.expected.context_after);var observations:Array=[]
		for source:Dictionary in row.observations:
			var reply:Dictionary=source.duplicate(true);reply.before=hydrate(source.before);reply.after=hydrate(source.after);observations.append(reply)
		var frozen:=digest([before,row.payload,observations]);var result:=Player.execute(before,row.payload,observations,row.operation)
		check(result.ok,"Actual original player event executes: "+str(row.name))
		if not result.ok:continue
		check(Player._same_context(result.context_after,expected),"Every Root/bank/event/external watcher/temp byte matches original: "+str(row.name))
		check(result.return_u32==int(row.expected.return_u32) and result.return_defined==row.expected.return_defined,"Source-defined returns match; unused payload pointer is not fabricated")
		check(result.source_order==row.expected.source_order and result.observations_used==observations.size(),"Actual handler, cleanup and UI/VM callback order matches")
		check(digest([before,row.payload,observations])==frozen,"Original input owners and defined payload remain private")
		check(result.context_after.root[0xef]==before.root[0xef],"Root+EF remains untouched: watched byte is a separate DOS owner")
		if str(row.name).begins_with("damage-all-index-"):seen[int(row.payload.index_u8)]=true
		if row.operation=="F61":removals+=1
		if "F1101" in result.source_order:cleanups+=1
	check(seen.size()==256 and removals>=24 and cleanups>10,"Source sign domain, temporary removal dispatch and actual target cleanup all execute")
func directed_controls()->void:
	var raw:=context();var p:=payload();var before:=digest([raw,p]);var done:=complete(raw,p)
	check(done.ok and done.result.context_after.root[0x112]==0 and done.result.context_after.root[0xec]==0 and done.result.context_after.root[0xed]==18 and done.result.context_after.root[0xe8]==0,"Ordinary removal performs exact target cleanup and screen-mode transition")
	check(done.ok and done.result.source_order==["F1103","F1102","F1101","F1097","F1116","F48","F1104"],"Cleanup callback sequencing exactly follows source")
	var watched:=context();watched.watched_index_u8=17
	var watched_result:=complete(watched,p)
	check(watched_result.ok and watched_result.result.context_after.watched_index_u8==0 and watched_result.result.context_after.root[0xea]==0 and watched_result.result.context_after.root[0xec]==17 and watched_result.result.context_after.root[0xed]==18,"Watched-index branch skips F1101/F1104 instead of clearing all refs")
	check(watched_result.ok and watched_result.result.source_order==["F1103","F1102","F262","F991"] and watched_result.result.context_after.root[0xef]==99,"Actual DOS watcher is independent from Root+EF")
	var unsigned_player:=context();unsigned_player.root.encode_u32(0xc0,255);unsigned_player.root.encode_u32(0x10e,7)
	var signed_result:=Player.execute(unsigned_player,payload(1,255));check(signed_result.ok and signed_result.context_after.root.decode_u32(0x10e)==7,"Unsigned255 player ID does not equal source signed-byte minus1")
	unsigned_player.root.encode_u32(0xc0,0xffffffff);signed_result=Player.execute(unsigned_player,payload(1,255));check(signed_result.ok and signed_result.context_after.root.decode_u32(0x10e)==30 and signed_result.return_s32==-1,"Source signed-byte comparison accepts the matching raw32-bit minus1")
	unsigned_player.root.encode_u32(0xc0,0);signed_result=Player.execute(unsigned_player,payload(1,0));check(signed_result.ok and signed_result.context_after.root.decode_u32(0x10e)==30,"Actor zero is compared as a source byte rather than discarded as a false value")
	var temporary:=complete(raw,payload(0,255),"F61",Callable(self,"temporary_policy"))
	check(temporary.ok and temporary.observations[0].args==[22,0,-1] and temporary.observations[0].before.temporary_event_index_s32==-1,"F61 exposes the signed removal index to event22")
	check(temporary.ok and temporary.result.context_after.temporary_event_index_s32==0 and temporary.result.context_after.event_registers.decode_u32(88)==0xdeadbeef,"Original temporary reset overrides callback write while preserving other event changes")
	var skipped:=Player.execute(raw,payload(1,255),[],"F61");check(skipped.ok and not skipped.return_defined and skipped.return_u32==0 and skipped.context_after.temporary_event_index_s32==-7,"Skipped F61 does not export an unconsumed process pointer or reset old temp")
	var reread:=complete(raw,p,"F1103",Callable(self,"reselect_policy"));check(reread.ok and reread.result.context_after.root[0xec]==18 and reread.result.context_after.root[0xed]==0 and "F1116" not in reread.result.source_order,"F1101 rereads both target fields after message callbacks")
	var decoded:Variant=Player.decode_observations(JSON.parse_string(JSON.stringify(encode(done.observations))))
	check(decoded is Array and Player.execute(raw,p,decoded).ok,"Defined callback contexts survive cold JSON continuation")
	for invalid:Variant in [null,true,0,"context",[],{}]:check(not Player.execute(invalid,p).ok,"Malformed event context rejects")
	for field:String in Player.CONTEXT_KEYS:
		var invalid:=raw.duplicate(true);invalid.erase(field);check(not Player.execute(invalid,p).ok,"Missing event owner rejects: "+field)
	for field:String in Player.BUFFER_BYTES:
		var invalid:=raw.duplicate(true);invalid[field]=zeros(int(Player.BUFFER_BYTES[field])-1);check(not Player.execute(invalid,p).ok,"Truncated event owner rejects: "+field)
	for value:Variant in [-1,256,true,null,NAN,INF,0.5]:
		var invalid:=raw.duplicate(true);invalid.watched_index_u8=value;check(not Player.execute(invalid,p).ok,"Invalid standalone watcher rejects")
	for value:Variant in [-0x80000001,0x80000000,true,null,NAN,INF,0.5]:
		var invalid:=raw.duplicate(true);invalid.temporary_event_index_s32=value;check(not Player.execute(invalid,p).ok,"Invalid standalone temporary index rejects")
	for field:String in ["root_copy","rng_seed","flags","Root_EF_alias"]:
		var invalid:=raw.duplicate(true);invalid[field]=0;check(not Player.execute(invalid,p).ok,"A second owner or undeclared alias cannot enter context")
	for field:String in Player.PAYLOAD_KEYS:
		var invalid:=p.duplicate(true);invalid.erase(field);check(not Player.execute(raw,invalid).ok,"Payload contains exactly the defined original fields")
	for value:Variant in [-1,256,0.5,true,null,"17"]:
		var invalid:=p.duplicate(true);invalid.index_u8=value;check(not Player.execute(raw,invalid).ok,"Undefined index representation rejects")
	var wrong:Array=done.observations.duplicate(true);wrong[0].before.watched_index_u8=0;check(not Player.execute(raw,p,wrong).ok,"An observation for another watcher state cannot continue")
	wrong=done.observations.duplicate(true);wrong.append(wrong[-1].duplicate(true));check(not Player.execute(raw,p,wrong).ok,"Unused external callback cannot silently succeed")
	check(digest([raw,p])==before,"All invalid, pending and completed calculations preserve caller owners")
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Native player event fixture is immutable")
	var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));buffers=doc.buffers;native_controls(doc);directed_controls();var sources:Dictionary={}
	for path:String in ["scripts/source_player_events.gd","tests/test_source_player_events.gd","tests/fixtures/source_player_events_native.json","validation/events-messages-2026-11-18/player-events-native-proof/instruction-proof.json","validation/events-messages-2026-11-18/player-events-native-proof/source-procedures.asm","validation/events-messages-2026-11-18/player-events-native-proof/player-events-native.s","validation/events-messages-2026-11-18/player-events-native-proof/player-events-support.c"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in doc.source_dependencies_sha256:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Player.PROFILE,"checks":checks,"failures":failures,"native_cases":int(doc.case_count),"sources":sources,"full_gameover_executed":false,"full_event_VM_executed":false,"Main_integrated":false},"\t"));file.close()
	print("SOURCE PLAYER EVENTS TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
