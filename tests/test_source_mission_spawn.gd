extends SceneTree
const Spawn=preload("res://scripts/source_mission_spawn.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_mission_spawn_native.json"
const FIXTURE_SHA:="6ea6d36ae97df54509447ae566b5b9935eca34f6aa474223fd8ffa55d253c379"
const PROOF:="res://validation/mission-statements-2026-11-19/spawn-native-proof/"
const REPORT:="res://build/current-test-reports/source-mission-spawn.json"
var checks:=0
var failures:=0
var native_cases:=0
var sequence_steps:=0
var pool:Dictionary={}
var cached:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<25:push_error(label)
func bytes(size:int,pattern:bool=false)->PackedByteArray:
	var result:=PackedByteArray();result.resize(size)
	if pattern:
		for index in range(size):result[index]=(index*37+11)&255
	return result
func context()->Dictionary:
	var root:=bytes(16384,true);root.encode_u32(0,0x89abcdef);root.encode_u32(4,0x12345678);root.encode_u32(0xc8,116+3*338);root.encode_u32(0xcc,116+17*338)
	var tail:=bytes(6160,true);tail.encode_u32(0x180c,1)
	return {"root":root,"root_tail":tail,"bank":bytes(38986,true)}
func arguments()->Array:return [38,7,0x12345678,0x22334455,0xfedcba98,0xcba98765,0xabcdef01,0x102030ff,0xfade8000]
func fingerprint(value:Variant)->String:return Clock._hash({"v":Scan.json_value(value)})
func reply(pending:Dictionary,returned:int=0)->Dictionary:return {"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":returned,"input_hex":"","output_hex":""}
func complete(before:Dictionary,args:Array,selected:int=17,mutate:bool=false)->Dictionary:
	var observed:Array=[]
	for step in range(3):
		var result:=Spawn.execute(before,"F40",args,observed)
		if result.get("ok",false) or not result.get("pending") is Dictionary:return {"result":result,"observations":observed}
		var pending:Dictionary=result.pending;var row:=reply(pending)
		if row.kind=="F927":
			row.return_u32=0 if selected<0 else 116+selected*338
			row.output_hex="ddccbbaa"
			if mutate:row.after.root.encode_u32(0,0xf1234567);row.after.root.encode_u32(4,0x89fedcba);row.after.root_tail[1]^=0x80
		elif mutate:
			var at:=int(row.args[0]);row.after.bank.encode_u32(at+0xa8,0xfedcba98);row.after.root.encode_u32(0,0x12345678)
			for index in range(24):row.after.bank[at+0x3e+index]=(0x71+index)&255
		observed.append(row)
	return {"result":{"ok":false,"reason":"test_provider_limit"},"observations":observed}
func directed()->void:
	var before:=context();var frozen:=fingerprint(before)
	check(Spawn._context(before) and Spawn.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(before))))==before,"Three owners round-trip without inventing a text buffer or source pointer")
	for value:int in [0,1,0x7fffffff,0x80000000,0xffffffff]:
		var result:=Spawn.execute(before,"F39",[value])
		check(result.get("ok",false) and int(result.return_u32)==value and result.return_defined and result.scalar_return_defined and not result.pointer_return_defined and result.context_after==before and result.source_order==["F39"],"F39 returns its literal source word and preserves all owners")
	var args:=arguments();var pending:=Spawn.execute(before,"F40",args)
	check(not pending.ok and pending.pending.kind=="F927" and pending.pending.args==[1,116+7*338,29,38] and pending.source_order==["F40","F1532","F927"],"Real F40 bank lookup precedes exact allocator boundary")
	var allocation:=reply(pending.pending,116+17*338);allocation.after.root.encode_u32(0,0xf1234567);allocation.after.root.encode_u32(4,0x89fedcba)
	pending=Spawn.execute(before,"F40",args,[allocation]);var at:=116+17*338
	check(not pending.ok and pending.pending.kind=="F1507" and pending.pending.args[0]==at,"A nonnull allocation reaches the actual DOS position boundary")
	if pending.get("pending") is Dictionary:
		var body:PackedByteArray=pending.pending.before.bank.slice(at,at+338)
		check(body.decode_u32(0xa0)==int(args[2]) and body[0x56]==7 and body.decode_u16(0xda)==0xfffc and body.decode_u32(0xa8)==0xf1234567 and body.decode_u32(0xac)==0x89fedcba,"Held allocated body receives fields and reread allocator clock")
		check(body.decode_u32(0xc2)==int(args[5]) and body.decode_u32(0xa4)==0 and body.decode_u16(0xc6)==0xef01 and body[0x87]==1 and body.decode_u32(0xb0)==int(args[3]),"F40 truncates physical fields at the original widths")
		check(pending.pending.args==[at,int(args[3]),0xffffef01,body.decode_u32(0xbe)] and pending.source_order==["F40","F1532","F927","F1510","F1509","F1338","F1507"],"F1507 consumes sign-extended inclination and exact phase high word after closed DOS phase math")
	var done:=complete(before,args,17,true);var result:Dictionary=done.result
	check(result.get("ok",false) and result.return_defined and result.pointer_return_defined and not result.scalar_return_defined and result.pointer_result_kind=="logical_bank_offset" and int(result.return_u32)==at,"F40 exposes a defined logical bank pointer, not an original host address")
	if result.get("ok",false):
		check(result.context_after.bank.decode_u16(at+0xcc)==0x8000 and result.context_after.bank[at+0xc8]==0xff,"Final angle words truncate after position callback")
		check(result.context_after.bank.slice(at+0x3e,at+0x3e+24)==done.observations[-1].after.bank.slice(at+0x3e,at+0x3e+24) and result.context_after.root.decode_u32(0)==0x12345678,"Position and global provider mutations survive final orientation")
		check(result.source_order.slice(-9)==["F1675","F1914","F1914","F1914","F1914","F1521","F1521","F1521","F1521"] and result.F1510_body_executed and result.F1675_body_executed and not result.full_F1507_executed and not result.full_F927_executed,"Only actually closed phase and matrix helpers are claimed")
		check(result.context_after.bank.slice(0,at)==before.bank.slice(0,at) and result.context_after.bank.slice(at+338)==before.bank.slice(at+338),"F40 selected-body writes leave every other bank byte unchanged")
	var null_done:=complete(before,args,-1,true);result=null_done.result
	check(result.get("ok",false) and int(result.return_u32)==0 and result.pointer_return_defined and result.source_order==["F40","F1532","F927"] and not result.F1510_body_executed and result.context_after==null_done.observations[0].after,"A null allocator returns before phase/position/matrix while preserving explicit allocator effects")
	var zero:=arguments();zero[5]=0;zero[4]=0;done=complete(before,zero)
	if done.result.get("ok",false):check(done.observations[-1].before.bank.decode_u32(at+0xba)==0 and done.observations[-1].before.bank.decode_u32(at+0xbe)==0,"Zero rate and zero phase produce the exact zero phase pair")
	check(fingerprint(before)==frozen,"All executions keep caller-owned buffers unchanged")
func hostile()->void:
	var before:=context();var args:=arguments();var done:=complete(before,args);var rows:Array=done.observations
	check(done.result.get("ok",false),"Valid providers configure hostile controls")
	for key:String in Spawn.CONTEXT_KEYS:
		var missing:=before.duplicate(true);missing.erase(key);check(Spawn.decode_context(missing).is_empty() and not Spawn.execute(missing,"F39",[0]).ok,"Missing owner rejects: "+key)
	for invalid:Variant in [null,true,0,[],{},bytes(1)]:check(not Spawn.execute(invalid,"F39",[0]).ok,"Malformed owner shape rejects before copying")
	for field:int in [0xc8,0xcc]:
		var bad:=before.duplicate(true);bad.root.encode_u32(field,117);check(not Spawn.execute(bad,"F39",[0]).ok,"Misaligned root body pointer rejects")
	var bad_context:=before.duplicate(true);bad_context.root_tail.encode_u32(0x180c,0);check(not Spawn.execute(bad_context,"F39",[0]).ok,"Unbound object bank token rejects")
	var wrong:=args.duplicate();wrong[1]=115;check(not Spawn.execute(before,"F40",wrong).ok,"Out-of-bank F1532 parent is outside the bounded transport profile")
	for malformed:Variant in [[],[0],args+[0],[0,0,0,0,0,0,0,0,-1]]:check(not Spawn.execute(before,"F40",malformed).ok,"Malformed source argument words reject")
	check(not Spawn.execute(before,"F1344",[0]).ok and not Spawn.execute(before,"F39",[0],[rows[0]]).ok,"Unimplemented formatter and unused source observations cannot masquerade as spawn bodies")
	if rows.size()==2:
		for index in range(2):
			var invalid:Array=rows.duplicate(true);invalid[index].args[0]=int(invalid[index].args[0])+1;check(not Spawn.execute(before,"F40",args,invalid).ok,"Mismatched callback argument rejects atomically")
			invalid=rows.duplicate(true);invalid[index].before.bank[0]^=1;check(not Spawn.execute(before,"F40",args,invalid).ok,"Mismatched callback before-owner rejects atomically")
			invalid=rows.duplicate(true);invalid[index].after.root_tail.encode_u32(0x180c,2);check(not Spawn.execute(before,"F40",args,invalid).ok,"Callback cannot unbind canonical bank transport")
		var invalid:Array=rows.duplicate(true);invalid[0].return_u32=117;check(not Spawn.execute(before,"F40",args,invalid).ok,"Misaligned allocation return pointer rejects")
		invalid=rows.duplicate(true);invalid[0].output_hex="aabb";check(not Spawn.execute(before,"F40",args,invalid).ok,"Partial unconsumed allocator outlocal rejects")
		invalid=rows.duplicate(true);invalid[1].return_u32=1;check(not Spawn.execute(before,"F40",args,invalid).ok,"Position helper void EAX is never admitted as a semantic return")
		invalid=rows.duplicate(true);invalid[1].output_hex="00";check(not Spawn.execute(before,"F40",args,invalid).ok,"Unknown position output transport rejects")
		invalid=rows.duplicate(true);invalid[0].input_hex="00000000";check(not Spawn.execute(before,"F40",args,invalid).ok,"Uninitialized allocator local has no invented input word")
		invalid=rows.duplicate(true);invalid.append(rows[-1]);check(not Spawn.execute(before,"F40",args,invalid).ok,"Excess observation count rejects before copies")
	var cycle:Array=[];cycle.append(cycle);check(not Spawn.execute(before,"F40",cycle).ok,"Cyclic arguments reject before copying");cycle.clear()
	var cyclic:Dictionary={};cyclic["cycle"]=cyclic;check(Spawn.decode_context(cyclic).is_empty() and not Spawn.execute(cyclic,"F39",[0]).ok,"Cyclic owner shape rejects before copying");cyclic.clear()
	cycle=[];cycle.append(cycle);check(Spawn.decode_observations(cycle)==null and not Spawn.execute(before,"F40",args,cycle).ok,"Cyclic observation graph rejects before copying");cycle.clear()
	var cold:Variant=Spawn.decode_observations(JSON.parse_string(JSON.stringify(Scan.json_value(rows))));check(cold!=null and Spawn.execute(before,"F40",args,cold).get("ok",false),"Typed providers restore exactly from cold JSON without floating owner identities")
func cold_sequence()->void:
	var hot:=context();var cold:=Spawn.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(hot))))
	for index in range(6):
		var args:=arguments();args[4]=(int(args[4])+index)&0xffffffff;args[7]=[0,1,31,32,255,0x80000000][index]
		var done:=complete(hot,args,17 if index%2==0 else 7,true);var replay:=Spawn.execute(cold,"F40",args,Spawn.decode_observations(JSON.parse_string(JSON.stringify(Scan.json_value(done.observations)))))
		check(done.result.get("ok",false) and replay.get("ok",false),"Dependent warm/cold spawn executes")
		if not done.result.get("ok",false) or not replay.get("ok",false):break
		hot=done.result.context_after;cold=Spawn.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(replay.context_after))))
		check(hot==cold and int(done.result.return_u32)==int(replay.return_u32) and done.result.source_order==replay.source_order,"Every complete dependent owner and result survives cold continuation")
		sequence_steps+=1
func pooled(value:Variant)->PackedByteArray:
	if not value is Dictionary or not value.has("buffer_sha256") or not pool.has(str(value.buffer_sha256)):
		check(false,"Native owner buffer reference is complete");return PackedByteArray()
	var key:=str(value.buffer_sha256)
	if cached.has(key):return cached[key].duplicate()
	var entry:Dictionary=pool[key];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
	check(raw.size()==int(entry.byte_count) and hash.finish().hex_encode()==key,"Native owner buffer preserves exact decompressed bytes")
	cached[key]=raw;return raw.duplicate()
func native_context(value:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in Spawn.CONTEXT_KEYS:result[key]=pooled(value[key])
	return Spawn.decode_context(result)
func native_controls(document:Dictionary)->void:
	check(document.schema=="starfrontier-mission-spawn-native-v1" and document.profile==Spawn.PROFILE,"Native proof identifies actual spawn callers rather than text functions")
	check(int(document.case_count)==674 and document.cases.size()==674 and int(document.whole_original_procedures)==9 and int(document.whole_original_instructions)==290,"All nine complete DOS bodies and674 independent cases are present")
	check(int(document.fresh_process_runs)==3 and int(document.reverse_repeat_cases)==674 and document.expected_arithmetic_calculated_in_python==false and document.all_owner_canaries_unchanged==true,"Expected values come from three fresh and reverse native executions with intact owners")
	check(document.native_F1510_and_F1675_bodies_executed and not document.F1507_original_DOS_body_executed and not document.JJFFE_F1507_substituted and document.typed_world_callbacks==["F927","F1507"],"Only proved DOS phase and matrix dependencies are closed")
	for key:String in document.source_dependencies_sha256:check(FileAccess.get_sha256("res://"+key)==str(document.source_dependencies_sha256[key]),"Native dependency source hash remains exact: "+key)
	for key:String in document.proofs_sha256:check(FileAccess.get_sha256(PROOF+key)==str(document.proofs_sha256[key]),"Native complete instruction/ABI proof remains exact: "+key)
	var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PROOF+"instruction-proof.json"))
	check(proof.F39_is_scalar_identity and proof.F40_is_nine_argument_body_spawn and proof.all_whole_instructions_equal and proof.sine_table_sha256==document.original_sine_table_sha256,"Actual source identity and sine table anchor the mathematical helpers")
	var ground:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_ground_coordinates.json"));var sine:=bytes(65536)
	for index in range(16384):sine.encode_s32(index*4,int(ground.sin_quarter_q31[index]))
	var sine_hash:=HashingContext.new();sine_hash.start(HashingContext.HASH_SHA256);sine_hash.update(sine)
	check(sine_hash.finish().hex_encode()==str(document.original_sine_table_sha256),"Runtime sine resource equals all original65536 table bytes")
	pool=document.buffer_pool;var shared:Dictionary={};var shared_steps:=0;var f39_values:Dictionary={};var shift_values:Dictionary={};var null_cases:=0
	for row:Dictionary in document.cases:
		var before:=native_context(row.context_before);var after:=native_context(row.expected.context_after);var replies:Array=[]
		for raw:Dictionary in row.observations:
			var reply_row:Dictionary=raw.duplicate(true);reply_row.before=native_context(raw.before);reply_row.after=native_context(raw.after);replies.append(reply_row)
		check(not before.is_empty() and not after.is_empty(),"Native complete context shape validates: "+str(row.name))
		var frozen:=fingerprint(before);var result:=Spawn.execute(before,row.operation,row.args,replies)
		check(result.get("ok",false),"Native complete spawn executes: "+str(row.name)+" / "+str(result.get("reason","")))
		if not result.get("ok",false):continue
		check(result.context_after==after,"Every byte of all three native owners matches: "+str(row.name))
		for field:String in ["return_u32","return_defined","scalar_return_defined","pointer_return_defined","pointer_result_kind","source_order"]:check(fingerprint(result[field])==fingerprint(row.expected[field]),"Native semantic result agrees: "+str(row.name)+" / "+field)
		check(fingerprint(before)==frozen and result.observations_used==replies.size(),"Native providers consume exactly once without mutating input owners")
		if row.operation=="F39":f39_values[int(row.args[0])&255]=true
		else:
			shift_values[int(row.args[7])&255]=true
			if int(result.return_u32)==0:null_cases+=1
		if row.get("shared_owner_sequence",false):
			if int(row.shared_step_u32)>0:check(shared==before,"Native dependent transition consumes all previous complete owners")
			var cold_before:=Spawn.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(before))));var cold_replies:Variant=Spawn.decode_observations(JSON.parse_string(JSON.stringify(Scan.json_value(replies))));var cold:=Spawn.execute(cold_before,row.operation,row.args,cold_replies)
			check(cold.get("ok",false) and cold.context_after==after and cold.source_order==result.source_order and int(cold.return_u32)==int(result.return_u32),"Dependent native transition survives complete cold replay")
			shared=result.context_after;shared_steps+=1
		native_cases+=1
	check(native_cases==674 and f39_values.size()==256 and shift_values.size()==256 and null_cases>0,"Entire native bank covers every F39 low byte, every shift byte and real NULL allocation control")
	check(shared_steps==8 and int(document.dependent_native_transitions)==8 and int(document.shared_continuation_edges)==7,"Eight dependent native states retain seven full-owner continuation edges")
func run()->void:
	directed();hostile();cold_sequence()
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Native fixture SHA is pinned")
	var document:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(document is Dictionary,"Native fixture is a readable object")
	if document is Dictionary:native_controls(document)
	var sources:Dictionary={}
	for path:String in ["scripts/source_mission_spawn.gd","scripts/source_orbit.gd","scripts/body_rotation.gd","scripts/ground_coordinates.gd","scripts/source_mission_expression.gd","scripts/source_mission_services.gd","data/ffe_ground_coordinates.json","tools/rebuild_source_mission_spawn_native.py","tests/test_source_mission_spawn.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Spawn.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"native_fixture_pending":false,"same_owner_sequence_steps":sequence_steps,"sources":sources,"Main_integrated":false},"\t")+"\n");file.close()
	print("SOURCE MISSION SPAWN TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
