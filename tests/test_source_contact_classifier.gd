extends SceneTree
const Classifier=preload("res://scripts/source_contact_classifier.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_contact_classifier_native.json"
const FIXTURE_SHA:="52445178302dec59e1befad2b996690e8f5aa85214b5108492143771a260352a"
const REPORT:="res://build/current-test-reports/source-contact-classifier.json"
var checks:=0
var failures:=0
var native_cases:=0
var boundary_count:=0
var pending_count:=0
var source_dependencies:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<30:push_error(message)
func hash_globals(value:Dictionary)->String:return Clock._hash(value)
func decode_context(value:Dictionary)->Dictionary:
	return {"body":str(value.body_hex).hex_decode(),"collider":str(value.collider_hex).hex_decode(),"relative":str(value.relative_hex).hex_decode(),"globals":Classifier._copy_globals(value.globals)}
func decode_observations(row:Dictionary)->Array:
	var result:Array=[]
	for source:Dictionary in row.expected.observations:
		var args:Array=[]
		for word:Variant in source.args:args.append(int(word))
		result.append({"kind":source.kind,"args":args,"before":decode_context(source.before),"after":decode_context(source.after),"return_u32":int(source.return_u32)})
	return result
func differences(first:PackedByteArray,second:PackedByteArray)->String:
	var cells:Array=[]
	for offset in range(mini(first.size(),second.size())):
		if first[offset]!=second[offset]:cells.append("%x:%x/%x"%[offset,first[offset],second[offset]])
	return str(cells.slice(0,12))
func base()->Dictionary:
	var body:=PackedByteArray();body.resize(338);body[0x86]=1;body.encode_u32(0x82,24)
	var collider:=PackedByteArray();collider.resize(338);collider[0x86]=2;collider.encode_u32(0x82,117)
	var relative:=PackedByteArray();relative.resize(24);relative.encode_s64(0,-3000);relative.encode_s64(8,2000);relative.encode_s64(16,-1000)
	var globals:Dictionary={}
	for key:String in Classifier.GLOBAL_KEYS:globals[key]=0
	globals.player_index_u32=1
	return {"body":body,"collider":collider,"relative":relative,"globals":globals}
func call_context(context:Dictionary,observations:Variant=[])->Dictionary:return Classifier.execute(context.body,context.collider,context.relative,context.globals,observations)
func coarse_and_pending()->void:
	var context:=base();var frozen:=var_to_bytes(context)
	var coarse:=call_context(context)
	check(coarse.ok and coarse.return_u8==0 and coarse.observations_used==0,"Outside coarse bounds returns the actual no-contact value without geometry observations")
	if coarse.ok:
		check(coarse.body_after==context.body and coarse.collider_after==context.collider and hash_globals(coarse.globals_after)==hash_globals(context.globals),"Coarse rejection preserves the entire bodies and every collision global")
		check(coarse.relative_after.decode_s64(0)==3000 and coarse.relative_after.decode_s64(8)==2000 and coarse.relative_after.decode_s64(16)==1000,"Caller vector receives the source absolute candidate")
		check(coarse.source_order==["F575","F1664"] and not coarse.F577_body_executed and not coarse.F578_body_executed,"Coarse rejection does not claim unexecuted geometry or pair responses")
		coarse.body_after[0]=99;coarse.collider_after[0]=99;coarse.relative_after[0]=99;coarse.globals_after.collision_flags_u8=99
	check(var_to_bytes(context)==frozen,"Coarse outputs never alias caller-owned records or globals")
	context.body.encode_s64(0x138,10000);context.collider.encode_s64(0x138,10000);context.collider[0x14c]=128
	frozen=var_to_bytes(context)
	var pending:=call_context(context)
	check(not pending.ok and pending.reason=="boundary_required" and pending.observations_used==0 and pending.pending.kind=="F576" and pending.pending.args==[1,2],"Hierarchical geometry pauses at its exact typed source boundary")
	if not pending.get("pending") is Dictionary:return
	check(pending.pending.before==context,"F576 receives all338-byte records, original signed local relative vector and13 source globals")
	var row:Dictionary={"kind":pending.pending.kind,"args":pending.pending.args.duplicate(),"before":pending.pending.before.duplicate(true),"after":pending.pending.before.duplicate(true),"return_u32":0xffffffff}
	row.after.body[0xf0]=55;row.after.collider[0xf1]=66;row.after.relative.encode_s64(0,71);row.after.globals.collision_flags_u8=0xa5
	var complete:=call_context(context,[row])
	check(complete.ok and complete.return_u8==0xa5 and complete.observations_used==1,"Original nonzero F576 result returns current collision flags after applying the matched response")
	if complete.ok:
		check(complete.body_after==row.after.body and complete.collider_after==row.after.collider and complete.globals_after==row.after.globals,"Matched geometry response updates complete raw records and globals")
		check(complete.relative_after.decode_s64(0)==3000 and complete.relative_after.decode_s64(16)==1000,"Geometry changes its local signed vector without changing the separate caller absolute buffer")
		check(complete.requests==[row] and complete.source_order==["F575","F1664","F576"] and not complete.F577_body_executed,"Geometry observation is recorded once with precise source order and scope")
		complete.requests[0].after.body[0]=42;complete.globals_after.collision_flags_u8=0
		check(row.after.body[0]!=42 and row.after.globals.collision_flags_u8==0xa5,"Returned request and result dictionaries are deep independent copies")
	for side:String in ["before"]:
		for key:String in ["body","collider","relative"]:
			var bad:=row.duplicate(true);bad[side][key][0]=int(bad[side][key][0])^1
			check(not call_context(context,[bad]).ok,"Every observed before-byte matches exactly: "+key)
	var bad:=row.duplicate(true);bad.before.globals.altitude_low_u32=1
	check(not call_context(context,[bad]).ok,"Before globals cannot be borrowed from a different source call")
	bad=row.duplicate(true);bad.kind="F953";check(not call_context(context,[bad]).ok,"Another function cannot consume the next geometry response")
	bad=row.duplicate(true);bad.args=[2,1];check(not call_context(context,[bad]).ok,"The source logical object arguments cannot be reversed")
	for key:String in ["body","collider"]:
		bad=row.duplicate(true);bad.after[key][0x86]=int(bad.after[key][0x86])^1
		check(not call_context(context,[bad]).ok,"Observed effects cannot replace the typed source object identity: "+key)
	for key:String in ["kind","args","before","after","return_u32"]:
		bad=row.duplicate(true);bad.erase(key);check(not call_context(context,[bad]).ok,"Incomplete observation rejects: "+key)
	bad=row.duplicate(true);bad.extra=0;check(not call_context(context,[bad]).ok,"Unknown observation fields are not silently trusted")
	for value:Variant in [-1,0x100000000,0.5,NAN,INF,true,"0"]:
		bad=row.duplicate(true);bad.return_u32=value;check(not call_context(context,[bad]).ok,"Invalid observation return words reject")
	check(not call_context(context,[row,row]).ok,"Unused responses cannot be added after the actual source return")
	check(var_to_bytes(context)==frozen,"All geometry rejects and continuations preserve the caller context")
func malformed()->void:
	var context:=base();var frozen:=var_to_bytes(context)
	for bad:Variant in [null,true,0,"record",{},[],PackedByteArray()]:
		check(not Classifier.execute(bad,context.collider,context.relative,context.globals).ok,"Malformed subject record rejects")
		check(not Classifier.execute(context.body,bad,context.relative,context.globals).ok,"Malformed collider record rejects")
		check(not Classifier.execute(context.body,context.collider,bad,context.globals).ok,"Malformed relative buffer rejects")
	for bad:Variant in [null,true,0,"globals",[],{}]:check(not Classifier.execute(context.body,context.collider,context.relative,bad).ok,"Malformed collision globals reject")
	for key:String in Classifier.GLOBAL_KEYS:
		var globals:Dictionary=context.globals.duplicate(true);globals.erase(key)
		check(not Classifier.execute(context.body,context.collider,context.relative,globals).ok,"Missing required source global rejects: "+key)
		for bad:Variant in [NAN,INF,true,0.5,"0"]:
			globals=context.globals.duplicate(true);globals[key]=bad
			check(not Classifier.execute(context.body,context.collider,context.relative,globals).ok,"Non-integer source global rejects: "+key)
		var low:=-0x80000000 if key.ends_with("_s32") else 0
		var high:=0x7fffffff if key.ends_with("_s32") else (0xffffffff if key.ends_with("_u32") else 255)
		if key=="collider_ref_u32":high=114
		for bad:int in [low-1,high+1]:
			globals=context.globals.duplicate(true);globals[key]=bad
			check(not Classifier.execute(context.body,context.collider,context.relative,globals).ok,"Out-of-range source global rejects: "+key)
	var globals:Dictionary=context.globals.duplicate(true);globals.extra=0
	check(not Classifier.execute(context.body,context.collider,context.relative,globals).ok,"Unknown collision-global aliases reject")
	for bad:Variant in [null,true,0,"trace",{},[{}]]:check(not call_context(context,bad).ok,"Malformed or unused observer containers reject")
	var excess:Array=[]
	for index in range(65):excess.append({})
	check(not call_context(context,excess).ok,"Unbounded observation arrays reject")
	check(var_to_bytes(context)==frozen,"Malformed calls preserve all input owners")
func native_bank()->void:
	check(FileAccess.file_exists(FIXTURE),"Independent original-instruction classifier fixture is present")
	if not FileAccess.file_exists(FIXTURE):return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent classifier fixture is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.schema=="starfrontier-source-contact-classifier-native-v1" and fixture.profile==Classifier.PROFILE and int(fixture.case_count)==fixture.cases.size() and fixture.cases.size()>=360,"Whole original classifier native corpus and source profile are complete")
	check(fixture.source_executable_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and fixture.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a","Native proof retains original DOS executable and assembly identities")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_cases==fixture.case_count and not fixture.expected_arithmetic_computed_in_Python,"Three fresh native processes and reversed inputs use original expected arithmetic")
	check(FileAccess.get_sha256("res://validation/contact-classifier-2026-11-17/native-proof/instruction-proof.json")==fixture.instruction_proof_sha256,"Whole original instruction proof is bound to the fixture")
	check(FileAccess.get_sha256("res://validation/contact-classifier-2026-11-17/native-proof/classifier-native.s")==fixture.host_assembly_sha256,"Documented host ABI adapter is pinned")
	source_dependencies=fixture.source_dependencies_sha256.duplicate(true)
	for path:String in source_dependencies:check(FileAccess.get_sha256("res://"+path)==source_dependencies[path],"Portable native reproduction dependency is pinned: "+path)
	var continued:Dictionary={};var damaged:Dictionary={};var traced:Array=[];var pair_cases:=0;var sphere_cases:=0;var natural_cases:=0;var non_player_cases:=0;var normal_cases:=0;var sequence_steps:=0;var previous_sequence:Dictionary={}
	for row:Dictionary in fixture.cases:
		var body:=str(row.body_before_hex).hex_decode();var collider:=str(row.collider_before_hex).hex_decode();var relative:=str(row.relative_before_hex).hex_decode();var globals:Dictionary=row.globals_before.duplicate(true);var observations:=decode_observations(row)
		var frozen:=var_to_bytes([body,collider,relative,globals,observations]);var result:=Classifier.execute(body,collider,relative,globals,observations);native_cases+=1;boundary_count+=observations.size()
		check(result.get("ok",false),"Whole original F575 executes: "+row.name+" "+str(result.get("reason"))+" "+str(result.get("observations_used")))
		if not result.get("ok",false):
			if failures<15:print("ACTUAL ORDER ",result.get("source_order")," EXPECTED ",row.expected.source_order)
			continue
		var expected:Dictionary=row.expected;var expected_body:=str(expected.body_after_hex).hex_decode();var expected_collider:=str(expected.collider_after_hex).hex_decode();var expected_relative:=str(expected.relative_after_hex).hex_decode()
		check(result.body_after==expected_body,"All338 subject bytes match original F575: "+row.name+" "+differences(result.body_after,expected_body))
		check(result.collider_after==expected_collider,"All338 collider bytes match original F575: "+row.name+" "+differences(result.collider_after,expected_collider))
		check(result.relative_after==expected_relative,"All24 caller absolute-vector bytes match original F1664: "+row.name)
		check(hash_globals(result.globals_after)==hash_globals(expected.globals_after) and result.return_u8==int(expected.return_u8),"All13 globals and final AL match native original: "+row.name)
		check(result.source_order==expected.source_order,"Original classifier/helper/callback order matches: "+row.name+" "+str(result.source_order)+" / "+str(expected.source_order))
		check(result.observations_used==observations.size() and result.requests==observations,"Every F576/F953 boundary consumes exactly its original matched context: "+row.name)
		check(not result.general_F576_geometry_executed and not result.damage_engine_executed and not result.full_world_classifier and not result.live_owners_changed and result.F575_body_executed and result.F577_body_executed==("F577" in result.source_order) and result.F578_body_executed==("F578" in result.source_order),"Geometry, damage and caller-ownership scope is truthful: "+row.name)
		check(var_to_bytes([body,collider,relative,globals,observations])==frozen,"Native parity call preserves every input owner: "+row.name)
		if "F577" in result.source_order:sphere_cases+=1
		if "F578" in result.source_order:pair_cases+=1
		if "F576" in result.source_order:natural_cases+=1
		if int(body[0x86])!=int(globals.player_index_u32):non_player_cases+=1
		if "F571" in result.source_order:normal_cases+=1
		if row.has("sequence_index"):
			if not previous_sequence.is_empty():check(body==previous_sequence.body_after and collider==previous_sequence.collider_after and hash_globals(globals)==hash_globals(previous_sequence.globals_after),"Consecutive native F575 call continues the exact previous records and source globals")
			previous_sequence=result;sequence_steps+=1
		if observations.size()>traced.size():continued=row;traced=observations
		for item:Dictionary in observations:
			if item.kind=="F953" and damaged.is_empty():damaged=row
		for item:Dictionary in expected.observations:
			check(item.before.caller_relative_hex==expected.relative_after_hex and item.after.caller_relative_hex==expected.relative_after_hex,"Observed callbacks cannot alias the separate source caller absolute buffer")
	check(pair_cases>0 and sphere_cases>0 and natural_cases>0 and non_player_cases>0 and normal_cases>0,"Native corpus exercises real sphere, pair, hierarchical admission, nonplayer and basis responses")
	check(sequence_steps==int(fixture.get("consecutive_native_steps",0)),"All actual dependent native source calls are executed without resetting residues")
	if not continued.is_empty():
		var row:=continued;var observations:=decode_observations(row);var body:=str(row.body_before_hex).hex_decode();var collider:=str(row.collider_before_hex).hex_decode();var relative:=str(row.relative_before_hex).hex_decode();var globals:Dictionary=row.globals_before
		for index in range(observations.size()):
			var pending:=Classifier.execute(body,collider,relative,globals,observations.slice(0,index));pending_count+=1
			check(not pending.ok and pending.reason=="boundary_required" and pending.observations_used==index and pending.pending.kind==observations[index].kind and pending.pending.args==observations[index].args and pending.pending.before==observations[index].before,"Incremental caller reaches only the next actual native boundary")
		var complete:=Classifier.execute(body,collider,relative,globals,observations)
		check(complete.ok and complete.body_after==str(row.expected.body_after_hex).hex_decode(),"All incremental native boundary results resume complete source response")
		var json_observations:=decode_observations(row)
		for index in range(json_observations.size()):
			json_observations[index].args=row.expected.observations[index].args.duplicate()
			json_observations[index].before.globals=row.expected.observations[index].before.globals.duplicate(true)
			json_observations[index].after.globals=row.expected.observations[index].after.globals.duplicate(true)
		var cold:=Classifier.execute(body,collider,relative,globals,json_observations)
		check(cold.ok and cold.body_after==str(row.expected.body_after_hex).hex_decode(),"JSON-parsed whole numeric fields continue the same native boundary result")
	if not damaged.is_empty():
		var row:=damaged;var observations:=decode_observations(row)
		for item:Dictionary in observations:
			if item.kind=="F953":item.after.relative[0]=int(item.after.relative[0])^1;break
		var result:=Classifier.execute(str(row.body_before_hex).hex_decode(),str(row.collider_before_hex).hex_decode(),str(row.relative_before_hex).hex_decode(),row.globals_before,observations)
		check(not result.ok and result.reason=="unpassed_relative_mutated","F953 cannot change a local vector whose pointer was not passed")
	for path:String in [FIXTURE.trim_prefix("res://"),"validation/contact-classifier-2026-11-17/native-proof/instruction-proof.json","validation/contact-classifier-2026-11-17/native-proof/classifier-native.s"]:source_dependencies[path]=FileAccess.get_sha256("res://"+path)
func run()->void:
	coarse_and_pending();malformed();native_bank()
	var sources:Dictionary={}
	for path:String in ["scripts/source_contact_classifier.gd","tests/test_source_contact_classifier.gd","scripts/source_surface_contact.gd","scripts/source_spherical_contact.gd","scripts/source_object_factory.gd","scripts/source_frame_dispatch.gd","data/ffe_object_factory.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in source_dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var output:=FileAccess.open(REPORT,FileAccess.WRITE)
	if output:output.store_string(JSON.stringify({"schema":1,"profile":Classifier.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"matched_boundaries":boundary_count,"pending_boundaries":pending_count,"sources":sources,"full_world_classifier":false,"Main_integrated":false,"physical_device_tested":false},"\t"));output.close()
	print("SOURCE CONTACT CLASSIFIER TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
