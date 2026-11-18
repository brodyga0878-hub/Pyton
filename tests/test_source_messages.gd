extends SceneTree
const Messages=preload("res://scripts/source_messages.gd")
const FIXTURE:="res://tests/fixtures/source_messages_native.json"
const FIXTURE_SHA:="96a4fd9d10517183a2c184db051998585575444fac019361676e0ff33242cdca"
const PROOF:="res://validation/events-messages-2026-11-18/messages-native-proof/"
const REPORT:="res://build/current-test-reports/source-messages.json"
var checks:=0
var failures:=0
var pool:Dictionary={}
var cache:Dictionary={}
func check(v:bool,message:String)->void:
	checks+=1
	if not v:
		failures+=1
		if failures<20:push_error(message)
func buffer(key:String)->PackedByteArray:
	if cache.has(key):return cache[key].duplicate()
	var e:Dictionary=pool[key];var b:=Marshalls.base64_to_raw(e.zlib_base64).decompress(int(e.byte_count),FileAccess.COMPRESSION_DEFLATE);var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(b)
	check(b.size()==int(e.byte_count) and h.finish().hex_encode()==key,"Native message buffer exact length and SHA")
	cache[key]=b.duplicate();return b
func context(v:Dictionary)->Dictionary:
	var out:Dictionary={}
	for key:String in Messages.BYTE_COUNTS:out[key]=buffer(str(v[key]))
	return out
func observations(v:Array)->Array:
	var out:Array=v.duplicate(true)
	for row:Dictionary in out:row.before=context(row.before);row.after=context(row.after)
	return out
func encode(v:Variant)->Variant:
	if v is PackedByteArray:return v.hex_encode()
	if v is Dictionary:
		var out:Dictionary={}
		for key:Variant in v:out[key]=encode(v[key])
		return out
	if v is Array:
		var out:Array=[]
		for item:Variant in v:out.append(encode(item))
		return out
	return v
func _initialize()->void:
	var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));pool=doc.buffers
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent native message fixture byte identity pinned")
	check(doc.case_count==doc.cases.size() and doc.cases.size()>=120,"Independent whole message cohort present")
	check(doc.whole_original_procedures==5 and doc.whole_original_instructions==278 and not doc.expected_arithmetic_calculated_in_python,"Complete original message procedure proof")
	check(doc.all_owner_canaries_and_input_bytes_unchanged and doc.void_return_register_ignored and doc.consecutive_native_steps==16,"Native guards, void ABI and dependent ring controls")
	for pair:Array in [["instruction-proof.json","instruction_proof_sha256"],["source-procedures.asm","source_procedures_sha256"],["messages-native.s","host_assembly_sha256"],["messages-support.c","host_support_sha256"]]:check(FileAccess.get_sha256(PROOF+pair[0])==str(doc[pair[1]]),"Original/host message proof pinned: "+str(pair[0]))
	var backend:=0;var skipped:=0;var sticky:=0;var actor_names:=0;var fallback_names:=0
	for row:Dictionary in doc.cases:
		var state:=context(row.context_before);var replies:=observations(row.observations);var text:Variant=str(row.submitted_text_hex).hex_decode() if not str(row.get("submitted_text_hex","")).is_empty() else null;var operation:String=Messages.OPERATIONS[int(row.operation_u32)];var frozen:=var_to_bytes([state,replies,text])
		var result:=Messages.execute(state,operation,replies,row.display_mode_s32,text)
		check(result.ok,"Original message operation accepted: "+str(row.name))
		if not result.ok:
			if failures<20:print(result)
			continue
		check(Messages._same(result.context_after,context(row.expected.context_after)),"All original packet, ring, cursors, Root and fallback bytes equal: "+str(row.name))
		check(result.source_order==row.expected.source_order,"Original source call order exact: "+str(row.name))
		check(var_to_bytes([state,replies,text])==frozen,"Caller inputs remain unchanged")
		check(result.requests.size()==replies.size() and result.observations_used==replies.size(),"All message provider witnesses consumed")
		check(result.void_return_register_ignored and not result.rendering_executed,"Void return and backend scope do not claim hostpointer/render output")
		backend+=result.source_order.count("F271");skipped+=1 if not result.F271_backend_executed else 0
		for submission:Dictionary in result.submissions:
			sticky+=1 if submission.flags_u32==1 else 0
			var at:int=int(submission.slot_u32)*1038;var original:PackedByteArray=str(submission.text_hex).hex_decode()
			check(result.context_after.queue_records.slice(at+9,at+9+original.size())==original,"Ring stores the original unwrapped formatter text")
		for reply:Dictionary in replies:
			if reply.kind=="F1344":
				actor_names+=1 if int(reply.args[6])==1 else 0;fallback_names+=1 if int(reply.args[6])==2 else 0
		if not replies.is_empty():
			var pending:=Messages.execute(state,operation,[],row.display_mode_s32,text)
			check(not pending.ok and pending.get("pending") is Dictionary and pending.pending.kind==replies[0].kind,"Missing providers produce exact pending calls")
		if row==doc.cases[0]:
			var cold:=Messages.decode_context(JSON.parse_string(JSON.stringify(encode(state))));var cold_replies:Variant=Messages.decode_observations(JSON.parse_string(JSON.stringify(encode(replies))))
			check(not cold.is_empty() and cold_replies is Array and Messages.execute(cold,operation,cold_replies,row.display_mode_s32,text).ok,"Message bytes and text witnesses survive cold JSON continuation")
	check(backend>0 and skipped>0 and sticky>0 and actor_names>0 and fallback_names>0,"Native coverage includes gates, immediate sticky and typed actor/fallback branches")
	var base:=context(doc.cases[0].context_before);var frozen:=var_to_bytes(base)
	for bad:Variant in [null,true,0,[],{},PackedByteArray()]:check(not Messages.execute(bad).ok,"Invalid message context rejects")
	for bad:Variant in [null,true,0,"F999",[]]:check(not Messages.execute(base,bad).ok,"Invalid message entrypoint rejects")
	for bad:Variant in [-0x80000001,0x80000000,true,0.5,NAN,INF,"0",null]:check(not Messages.execute(base,"F350",[],bad).ok,"Invalid signed display flag rejects")
	for bad:Variant in [PackedByteArray(),PackedByteArray([1]),PackedByteArray([0,0]),PackedByteArray([65,0,66]),true,"text"]:check(not Messages.execute(base,"F271",[],1,bad).ok,"Unbounded/noncanonical C string rejects")
	for key:String in Messages.BYTE_COUNTS:
		var invalid:=base.duplicate(true);invalid[key].resize(int(Messages.BYTE_COUNTS[key])-1);check(not Messages.execute(invalid).ok,"Truncated owner rejects: "+key)
	var invalid:=base.duplicate(true);invalid.queue_control.encode_u32(24,10);check(not Messages.execute(invalid).ok,"Out-of-ring write index rejects")
	invalid=base.duplicate(true);invalid.packet.encode_u32(0x18,0);invalid.packet.encode_u32(0x1c,1);check(not Messages.execute(invalid,"F350").ok,"Actual actor-name branch rejects an unbound packet pointer")
	var too_long:=PackedByteArray();too_long.resize(1025);too_long.fill(65);too_long[-1]=0;check(not Messages.execute(base,"F271",[],1,too_long).ok,"A1025byteCString cannot overrun source1024byte scratch")
	var witnesses:=observations(doc.cases[0].observations)
	for part:String in ["kind","args","before","after","return_u32","input_text_hex","output_text_hex"]:
		var bad:Array=witnesses.duplicate(true)
		if part=="kind":bad[0].kind="F999"
		elif part=="args":bad[0].args=[0]
		elif part=="before":bad[0].before.root[0]=int(bad[0].before.root[0])^1
		elif part=="after":bad[0].after.queue_control.encode_u32(24,10)
		elif part=="return_u32":bad[0].return_u32=-1
		elif part=="input_text_hex":bad[0].input_text_hex="00"
		else:bad[0].output_text_hex="00"
		check(not Messages.execute(base,"F349",bad).ok,"Mismatched provider witness rejects: "+part)
	check(var_to_bytes(base)==frozen,"Rejected message inputs preserve existing owner")
	var sources:Dictionary={}
	for path:String in ["scripts/source_messages.gd","tests/test_source_messages.gd","tests/fixtures/source_messages_native.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in doc.source_dependencies_sha256:sources[path]=FileAccess.get_sha256("res://"+path);check(sources[path]==doc.source_dependencies_sha256[path],"Native message dependency current: "+path)
	for name:String in ["instruction-proof.json","source-procedures.asm","messages-native.s","messages-support.c"]:sources[PROOF.trim_prefix("res://")+name]=FileAccess.get_sha256(PROOF+name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Messages.PROFILE,"checks":checks,"failures":failures,"native_cases":doc.cases.size(),"backend_calls":backend,"sources":sources,"rendering_executed":false,"Main_integrated":false},"\t"));file.close()
	print("SOURCE MESSAGES TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
