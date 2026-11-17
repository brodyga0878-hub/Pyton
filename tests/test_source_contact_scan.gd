extends SceneTree
const Scan=preload("res://scripts/source_contact_scan.gd")
const Classifier=preload("res://scripts/source_contact_classifier.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Motion=preload("res://scripts/source_player_motion.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_contact_scan_native.json"
const FIXTURE_SHA:="d0f5355216aeb30f5f9f66dce713609c8d13728e3992b52cf4a0c35c53ae7657"
const REPORT:="res://build/current-test-reports/source-contact-scan.json"
var checks:=0
var failures:=0
var native_cases:=0
var source_dependencies:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<26:push_error(message)
func digest(value:Dictionary)->String:return Clock._hash(value)
func base()->Dictionary:
	var body:=PackedByteArray();body.resize(338);body[0x86]=17;body.encode_u32(0x82,24)
	var flags:=PackedByteArray();flags.resize(115);flags[17]=4
	var objects:Dictionary={}
	for index in [7,9]:
		var collider:=PackedByteArray();collider.resize(338);collider[0x86]=index;collider.encode_u32(0x82,24);collider.encode_s64(0x3e,index*1000);objects[index]=collider;flags[index]=4
	var root:=PackedByteArray();root.resize(0x4000);root.fill(0xa5);root.encode_u32(0xc0,17);root.encode_u32(0xc8,17);root.encode_u32(0xcc,0)
	var globals:Dictionary={}
	for key:String in Frame.GLOBAL_KEYS:globals[key]=0
	return {"body":body,"objects":objects,"flags":flags,"root":root,"globals":globals,"ticks":17,"source_frame":31}
func invoke(context:Dictionary,observations:Variant=[],enabled:Variant=true)->Dictionary:return Scan.dispatch(context.body,context.objects,context.flags,context.root,context.globals,context.ticks,context.source_frame,observations,enabled)
func standalone()->void:
	var context:=base();var frozen:=var_to_bytes(context);var result:=invoke(context)
	check(result.ok,"Actual F569 scan executes coarse F575 calls across the private raw bank")
	if not result.ok:return
	check(result.classifier_calls.size()==2 and result.classifier_calls[0].collider_index_u8==9 and result.classifier_calls[1].collider_index_u8==7,"Actual classifiers execute in the original descending bank order")
	check(result.F575_body_executed and result.F570_executed and not result.full_collision_program_VM and not result.Main_integrated,"Actual caller/classifier execution retains bounded VM and Main scope")
	check(result.body==context.body and result.objects_by_index==context.objects and result.flags==context.flags and result.root_after==context.root,"No-contact coarse scan preserves all raw object, bank and Root bytes")
	check(result.outputs.flags_u8==0 and result.outputs.altitude_s32==-1 and result.classifier_trace.size()==2,"No-contact results retain source flags and unknown altitude without invented ground")
	var trace:Array=[]
	for entry:Dictionary in result.classifier_trace:trace.append(entry.duplicate(true))
	var legacy:=Frame.dispatch(context.body,context.objects,context.flags,context.globals,context.ticks,context.source_frame,trace,true)
	check(legacy.ok and legacy.body==result.body and legacy.objects_by_index==result.objects_by_index and legacy.globals_after==result.globals_after and legacy.outputs==result.outputs,"Real classifier results feed the unchanged independently verified bank caller")
	var disabled:=invoke(context,[],false)
	check(disabled.ok and disabled.caller_procedure=="F568" and disabled.globals_after.collision_enabled_u8==0 and disabled.classifier_calls.size()==2,"F568 preserves actual traversal with collision response disabled")
	var boundary:=Scan.contact_boundary(context.body,result)
	check(boundary.caller_profile==Motion.CONTACT_PROFILE and boundary.body_before_hex==context.body.hex_encode() and boundary.body_after_hex==result.body.hex_encode() and boundary.collider_ref_u32==0,"Completed scan forms the typed real F569 response for motion contact")
	var response:=Motion.execute("contact_f1033",context.body,result.root_after,{"effect_gate_s32":0,"sound_mode_s8":-1,"step_u32":context.ticks},boundary)
	check(response.ok,"Actual scan response is admitted by the real F1033 contact kernel")
	var other:PackedByteArray=context.body.duplicate();other[0]=1
	check(Scan.contact_boundary(other,result).is_empty(),"A response cannot be rebound to another before-body")
	var returned_root:PackedByteArray=result.root_after;returned_root[0]=0;result.body[0]=1;result.objects_by_index[9][0]=1;result.classifier_trace[0].globals_before.collision_flags_u8=99
	check(var_to_bytes(context)==frozen,"Every completed scan output is independent of caller state")
	# General geometry is admitted only with an exact per-call observation.
	context.objects[9][0x14c]=128;context.objects[9].encode_s64(0x138,100000)
	frozen=var_to_bytes(context)
	var pending:=invoke(context)
	check(not pending.ok and pending.reason=="classifier_boundary_required" and pending.classifier_call_index_u32==0 and pending.pending.kind=="F576","Missing general geometry pauses before source effects and identifies the actual scan call")
	if pending.get("pending") is Dictionary:
		var row:Dictionary={"kind":pending.pending.kind,"args":pending.pending.args.duplicate(),"before":pending.pending.before.duplicate(true),"after":pending.pending.before.duplicate(true),"return_u32":1}
		var packet:Array=[{"call_index_u32":0,"observations":[row]}]
		var complete:=invoke(context,packet)
		check(complete.ok and complete.classifier_calls.size()==2,"Matching hierarchy response resumes later descending candidates")
		var json_packet:Variant=JSON.parse_string(JSON.stringify(Scan.json_value(packet)))
		var cold:=invoke(context,json_packet)
		check(cold.ok and cold.body==complete.body and cold.root_after==complete.root_after and cold.globals_after==complete.globals_after,"JSON hex/numeric observation packets continue exactly like live raw packets")
		var bad:=packet.duplicate(true);bad[0].call_index_u32=1
		check(not invoke(context,bad).ok,"A geometry result for another scan call cannot satisfy this call")
		bad=packet.duplicate(true);bad[0].observations[0].before.body[0]=1
		check(not invoke(context,bad).ok,"Geometry response whose complete before-state differs is rejected")
		bad=packet.duplicate(true);bad.append(packet[0])
		check(not invoke(context,bad).ok,"Unused duplicated geometry packet cannot be accepted")
	check(var_to_bytes(context)==frozen,"Pending and rejected geometry calls preserve the raw caller bank")
func malformed()->void:
	var context:=base();var frozen:=var_to_bytes(context)
	for bad:Variant in [null,true,0,"raw",[],{},PackedByteArray()]:
		check(not Scan.dispatch(bad,context.objects,context.flags,context.root,context.globals,context.ticks,context.source_frame).ok,"Malformed scan subject rejects")
		check(not Scan.dispatch(context.body,context.objects,bad,context.root,context.globals,context.ticks,context.source_frame).ok,"Malformed scan flags reject")
		check(not Scan.dispatch(context.body,context.objects,context.flags,bad,context.globals,context.ticks,context.source_frame).ok,"Malformed scan Root rejects")
	for bad:Variant in [null,true,0,"objects",[],{}]:
		if bad is Dictionary and bad.is_empty():continue
		check(not Scan.dispatch(context.body,bad,context.flags,context.root,context.globals,context.ticks,context.source_frame).ok,"Malformed raw object bank rejects")
	for bad:Variant in [null,true,0,"globals",[],{}]:check(not Scan.dispatch(context.body,context.objects,context.flags,context.root,bad,context.ticks,context.source_frame).ok,"Malformed scan globals reject")
	for bad:Variant in [-1,0x100000000,NAN,INF,true,0.5,"0"]:check(not Scan.dispatch(context.body,context.objects,context.flags,context.root,context.globals,bad,context.source_frame).ok,"Invalid raw tick word rejects")
	for bad:Variant in [-1,256,NAN,INF,true,0.5,"0"]:check(not Scan.dispatch(context.body,context.objects,context.flags,context.root,context.globals,context.ticks,bad).ok,"Invalid source frame byte rejects")
	for bad:Variant in [null,0,1,"true",[],{}]:check(not invoke(context,[],bad).ok,"Response-enabled policy must be boolean")
	for bad:Variant in [null,true,0,"trace",{},[{}],[{"call_index_u32":-1,"observations":[]}],[{"call_index_u32":0,"observations":[{}]}]]:check(not invoke(context,bad).ok,"Malformed per-call classifier packets reject")
	var root:PackedByteArray=context.root.duplicate();root.encode_u32(0xc0,115)
	check(not Scan.dispatch(context.body,context.objects,context.flags,root,context.globals,context.ticks,context.source_frame).ok,"Player Root reference outside the raw bank rejects")
	for bad:Variant in [null,true,{},[],"scan",{"ok":true}]:check(Scan.contact_boundary(context.body,bad).is_empty(),"Incomplete or foreign scan result cannot be converted to a contact response")
	check(var_to_bytes(context)==frozen,"All invalid scan inputs reject without changing any owner")
func native_bank()->void:
	check(FileAccess.file_exists(FIXTURE),"Independent native F569→F575 scan composition fixture is present")
	if not FileAccess.file_exists(FIXTURE):return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent scan composition fixture is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.schema=="starfrontier-source-contact-scan-native-v1" and fixture.profile==Scan.PROFILE and int(fixture.case_count)==32 and fixture.cases.size()==32 and int(fixture.actual_F575_calls)==80,"All32 independently composed native scans and80 actual classifiers are present")
	check(fixture.proof.fresh_process_runs_each_call==3 and fixture.proof.all_raw_record_bank_and_output_canaries_verified and not fixture.proof.expected_arithmetic_calculated_in_python and fixture.proof.frame_conversion_cases>0 and fixture.proof.cache_record_change_count>0,"Native scan proof retains actual frame conversions/caches and clean guarded processes")
	source_dependencies=fixture.proof.source_dependencies_sha256.duplicate(true)
	for path:String in source_dependencies:check(FileAccess.get_sha256("res://"+path)==source_dependencies[path],"Native scan dependency pin matches: "+path)
	var actual_classifiers:=0
	for row:Dictionary in fixture.cases:
		var objects:Dictionary={}
		for key:String in row.objects_by_index:objects[int(key)]=str(row.objects_by_index[key]).hex_decode()
		var context:Dictionary={"body":str(row.player_hex).hex_decode(),"objects":objects,"flags":str(row.flags_hex).hex_decode(),"root":str(row.root_before_hex).hex_decode(),"globals":row.globals.duplicate(true),"ticks":int(row.frame_ticks_u32),"source_frame":int(row.source_frame_byte)}
		var frozen:=var_to_bytes([context,row.classifier_observations]);var result:=invoke(context,row.classifier_observations,row.enabled);native_cases+=1
		check(result.get("ok",false),"Original native composed scan executes: "+row.name+" "+str(result.get("reason")))
		if not result.get("ok",false):continue
		var expected:Dictionary=row.expected
		check(result.body==str(expected.player_hex).hex_decode(),"Whole338-byte subject agrees with native composition: "+row.name)
		var expected_objects:Dictionary={}
		for key:String in expected.objects_by_index:expected_objects[int(key)]=str(expected.objects_by_index[key]).hex_decode()
		check(result.objects_by_index==expected_objects and result.flags==str(expected.flags_hex).hex_decode(),"Every candidate record, frame cache and bank flag agrees with original scan: "+row.name)
		check(result.root_after==str(expected.root_after_hex).hex_decode(),"All16KiB Root bytes preserve true player and collider-reference aliases: "+row.name)
		check(digest(result.globals_after)==digest(expected.globals) and digest(result.outputs)==digest(expected.outputs),"Every global, F569 output and AL matches native composition: "+row.name)
		check(result.classifier_calls.size()==row.classifier_calls.size() and result.classifier_trace.size()==row.trace.size(),"Actual native classifier count and observed bank trace lengths match: "+row.name)
		for index in range(result.classifier_calls.size()):
			check(result.classifier_calls[index].source_order==row.classifier_calls[index].expected.source_order,"Each original classifier/helper/callback executes at its exact scan position")
		actual_classifiers+=result.classifier_calls.size()
		var boundary:=Scan.contact_boundary(context.body,result)
		var reference:=int(expected.outputs.collider_ref_u32)
		if reference!=0 and reference!=int(result.body[0x86]) and not result.objects_by_index.has(reference):check(boundary.is_empty(),"A stale collider reference absent from the supplied sparse bank cannot invent an F1033 record: "+row.name)
		else:check(not boundary.is_empty() and boundary.body_after_hex==expected.player_hex and int(boundary.flags_u8)==int(expected.outputs.flags_u8),"Native scan result forms a provenance-bound F1033 contact response: "+row.name)
		check(var_to_bytes([context,row.classifier_observations])==frozen,"Actual native scan composition leaves caller-owned records and packets unchanged")
	check(actual_classifiers==80,"All80 original F575 calls actually execute through the source bank scanner")
	for path:String in [FIXTURE.trim_prefix("res://"),"validation/contact-classifier-2026-11-17/scan-native-proof/composition-proof.json"]:
		if FileAccess.file_exists("res://"+path):source_dependencies[path]=FileAccess.get_sha256("res://"+path)
func run()->void:
	standalone();malformed();native_bank()
	var sources:Dictionary={}
	for path:String in ["scripts/source_contact_scan.gd","scripts/source_frame_dispatch.gd","scripts/source_contact_classifier.gd","scripts/source_pair_response.gd","scripts/source_player_motion.gd","tests/test_source_contact_scan.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in source_dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var output:=FileAccess.open(REPORT,FileAccess.WRITE)
	if output:output.store_string(JSON.stringify({"schema":1,"profile":Scan.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"sources":sources,"full_collision_program_VM":false,"Main_integrated":false,"physical_device_tested":false},"\t"));output.close()
	print("SOURCE CONTACT SCAN TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
