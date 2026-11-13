extends SceneTree
# Expected transitions come from independent original machine-code execution.
# Decode signed64 words from little-endian hex, never JSON decimal previews.
const Core=preload("res://scripts/source_natural_contact.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const FIXTURE:="res://tests/fixtures/source_natural_contact_native.json"
const REPORT:="res://build/current-test-reports/source-natural-contact-core.json"
var checks:=0
var failures:=0
var domains:Dictionary={}
var domain_failures:Dictionary={}
var models:Dictionary={}
var players:Dictionary={}
var branches:Dictionary={}
var returns:Dictionary={}
var iterations:Dictionary={}
var thresholds:Dictionary={}
var evidence:Array=[]
var baseline:Dictionary={}
var core:=Core.new()
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=40:push_error(label)
func equal_words(actual:Variant,expected:Variant)->bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size()!=expected.size():return false
		for key:Variant in actual:
			if not expected.has(key) or not equal_words(actual[key],expected[key]):return false
		return true
	if (actual is Array or actual is PackedInt64Array) and (expected is Array or expected is PackedInt64Array):
		if actual.size()!=expected.size():return false
		for index in range(actual.size()):
			if not equal_words(actual[index],expected[index]):return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):return int(actual)==int(expected)
	return actual==expected
func exact_vector(value:String)->PackedInt64Array:
	var raw:=value.hex_decode()
	return PackedInt64Array([raw.decode_s64(0),raw.decode_s64(8),raw.decode_s64(16)]) if raw.size()==24 else PackedInt64Array()
func tally(target:Dictionary,key:Variant)->void:target[str(key)]=int(target.get(str(key),0))+1
func native_cases()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) if FileAccess.file_exists(FIXTURE) else null
	check(fixture is Dictionary,"Independent natural machine-code fixture exists")
	if not fixture is Dictionary:return
	check(fixture.get("source_sha256",fixture.get("executable_sha256",""))==Core.SOURCE_SHA,"Native fixture identifies the uploaded DOS executable")
	var proofs:Dictionary=fixture.get("byte_instruction_proofs",{})
	for name:String in ["576","579","581","582","1876"]:
		check(proofs.has(name),"Native byte proof includes complete F"+name)
		if proofs.has(name):check(bool(proofs[name].get("all_instructions_equal_after_branch_destination_normalization",proofs[name].get("all_instructions_equal",false))),"All original DOS F"+name+" instructions agree with the executed relocated procedure")
	check(proofs.size()>=60,"Native instruction proof includes integer helpers and the original terrain workers")
	for name:String in proofs:check(bool(proofs[name].get("all_instructions_equal_after_branch_destination_normalization",proofs[name].get("all_instructions_equal",false))),"Complete original native instruction proof "+name)
	check(int(fixture.get("fresh_process_runs",0))>=3 and int(fixture.get("reverse_repeat_count",0))==int(fixture.get("case_count",-1)),"Three fresh native processes and reverse order produce identical complete outputs")
	check(bool(fixture.get("output_canaries_unchanged",false)) and bool(fixture.get("caller_buffers_unchanged",false)),"Original native classifier preserves guarded caller buffers")
	check(fixture.get("native_expected_arithmetic_in_python",true)==false and fixture.get("dos_jjffe_behavior_differences",["unknown"]).is_empty(),"Expected transitions execute original machine instructions without Python contact arithmetic or unknown source variants")
	var cases:Variant=fixture.get("cases")
	check(cases is Array and cases.size()>100,"Native matrix contains more than100 independent raw cases")
	if not cases is Array:return
	for sample:Dictionary in cases:
		var domain:=str(sample.get("domain",sample.get("selection","")));var label:=str(sample.get("id",sample.get("name","")))+" "+domain;var old_failures:=failures
		var body:=str(sample.player_object_hex).hex_decode();var parent:=str(sample.parent_object_hex).hex_decode();var relative:=exact_vector(str(sample.relative_before_hex));var context:Dictionary=sample.context.duplicate(true)
		var before:=var_to_bytes([body,parent,relative,context]);var source_before:=var_to_bytes(sample);var result:=core.classify_natural_player(body,parent,relative,context)
		if baseline.is_empty():baseline={"body":body.duplicate(),"parent":parent.duplicate(),"relative":relative.duplicate(),"context":context.duplicate(true)}
		tally(domains,domain);tally(players,body.decode_u32(0x82));tally(models,parent.decode_u32(0x82))
		check(result.ok,label+" accepts the original operand domain")
		check(var_to_bytes([body,parent,relative,context])==before,label+" leaves object records, caller vector and globals unchanged")
		if not result.ok:
			tally(domain_failures,domain);continue
		var expected:Dictionary=sample.expected
		check(result.body_after==str(expected.player_hex).hex_decode() and result.body_after==body,label+" complete player338 bytes unchanged")
		check(result.parent_after==str(expected.parent_hex).hex_decode() and result.parent_after==parent,label+" complete natural parent338 bytes unchanged")
		check(result.relative_position_s64==exact_vector(str(expected.relative_after_hex)) and result.relative_position_s64==relative,label+" exact unchanged original signed64 caller vector")
		check(int(result.f576_return_s32)==int(expected.f576_return_s32),label+" signed F576 return actual="+str(result.f576_return_s32)+" expected="+str(expected.f576_return_s32))
		check(equal_words(result.globals_after,expected.globals),label+" complete source flags, altitude words, previous words, kind, primitive and collider")
		check(int(result.terrain_query_calls)==int(expected.terrain_query_calls),label+" exact native F1876 call count")
		check(result.iterations.size()==int(expected.f579_calls) and result.iterations.size()==expected.volume_trace.size(),label+" exact native child-volume iteration count")
		for index in range(mini(result.iterations.size(),expected.volume_trace.size())):
			var trace:Dictionary=result.iterations[index];var original_trace:Dictionary=expected.volume_trace[index];var detail:=label+" volume"+str(index)
			check(int(trace.threshold_before_s32)==int(original_trace.threshold_s32),detail+" original positive player/child radius threshold")
			check(str(trace.relative_before_hex)==str(original_trace.relative_before_hex),detail+" exact original relative-plus-child displacement")
			check(str(trace.relative_truncated_hex)==str(original_trace.relative_after_hex),detail+" exact F1658 local signed64 truncation")
			check(int(trace.f579_return_s32)==int(original_trace.f579_return_s32) and int(trace.terrain_query_calls)==int(original_trace.terrain_query_calls),detail+" native F579 return and query count")
			tally(branches,trace.branch);tally(thresholds,trace.threshold_before_s32)
		check(var_to_bytes(sample)==source_before,label+" fixture immutable")
		tally(returns,result.f576_return_s32);tally(iterations,result.iterations.size())
		if failures>old_failures:domain_failures[domain]=int(domain_failures.get(domain,0))+failures-old_failures
	check(cases.size()==int(fixture.get("case_count",-1)),"Every native fixture case is consumed once")
	for index in range(117,149):check(models.has(str(index)),"Natural parent source model covered "+str(index))
	for index:int in [15,24,38]:check(players.has(str(index)),"Real source player model covered "+str(index))
	for branch:String in ["outside_outer","inside_inner","terrain_query"]:check(branches.has(branch),"Independent native F581 branch covered "+branch)
	for value:int in [-1,0]:check(returns.has(str(value)),"Independent native F576 return covered "+str(value))
	for value:int in [1,2,3]:check(iterations.has(str(value)),"Actual child traversal length covered "+str(value))
	for radius:int in [5200,9600,1920]:check(thresholds.has(str(radius)),"Actual positive initialized ship inner radius covered "+str(radius))
	evidence.append({"case_count":cases.size(),"domains":domains.duplicate(true),"domain_failures":domain_failures.duplicate(true),"natural_models":models.duplicate(true),"player_models":players.duplicate(true),"branches":branches.duplicate(true),"returns":returns.duplicate(true),"iteration_counts":iterations.duplicate(true),"thresholds":thresholds.duplicate(true),"byte_instruction_proofs":proofs,"execution_checks":fixture.get("execution_checks",{"fresh_process_runs":fixture.get("fresh_process_runs",0),"reverse_repeat_count":fixture.get("reverse_repeat_count",0),"output_canaries_unchanged":fixture.get("output_canaries_unchanged",false),"caller_buffers_unchanged":fixture.get("caller_buffers_unchanged",false),"native_expected_arithmetic_in_python":fixture.get("native_expected_arithmetic_in_python",true)}),"scope":fixture.get("scope",{}),"exact64_policy":"Only little-endian hex supplies machine input/output vectors; no decimal signed64 conversion."})
func reject_case(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,context:Dictionary,label:String)->void:
	var before:=var_to_bytes([body,parent,relative,context]);var result:=core.classify_natural_player(body,parent,relative,context)
	check(not result.ok and result.body_after==body and result.parent_after==parent and result.relative_position_s64==relative,label+" rejects atomically with copied raw inputs")
	check(result.globals_after.is_empty() and result.global_writes.is_empty() and result.iterations.is_empty() and result.query_trace.is_empty() and int(result.terrain_query_calls)==0,label+" publishes no fabricated classification, partial globals or trace")
	check(var_to_bytes([body,parent,relative,context])==before,label+" leaves caller inputs immutable")
func contracts()->void:
	check(FileAccess.get_sha256(Core.DATA_PATH)==Core.DATA_SHA,"New ship child metadata matches its frozen original extraction hash")
	for index:int in [15,24,38]:
		var model:=Core.ship_model(index);check(not model.is_empty(),"Verified actual source player model "+str(index))
		if not model.is_empty():check(model.children.size()==({15:1,24:0,38:2})[index],"Actual preceding collision child list "+str(index))
	for index in range(117,149):check(not Core.parent_model(index).is_empty(),"Verified exact natural parent resource "+str(index))
	for index:int in [-1,0,84,116,149,1000]:check(Core.ship_model(index).is_empty() and Core.parent_model(index).is_empty(),"Unsupported model metadata "+str(index))
	if baseline.is_empty():return
	var body:PackedByteArray=baseline.body;var parent:PackedByteArray=baseline.parent;var relative:PackedInt64Array=baseline.relative;var context:Dictionary=baseline.context
	for size_value:int in [0,337,339]:
		var changed:=body.duplicate();changed.resize(size_value);reject_case(changed,parent,relative,context,"Invalid player record size "+str(size_value))
		changed=parent.duplicate();changed.resize(size_value);reject_case(body,changed,relative,context,"Invalid parent record size "+str(size_value))
	for size_value:int in [0,2,4]:
		var changed:=relative.duplicate();changed.resize(size_value);reject_case(body,parent,changed,context,"Invalid relative size "+str(size_value))
	for value:Variant in [-1,16,1.5,"1",null]:
		var changed:=context.duplicate(true);changed.graphics_level=value;reject_case(body,parent,relative,changed,"Invalid graphics level "+str(value))
	for field:String in ["body_descriptor","parent_descriptor","fake_child_radius","mutate_pose"]:
		var changed:=context.duplicate(true);changed[field]=0;reject_case(body,parent,relative,changed,"Unsupported context field "+field)
	for value:Variant in [[],null,"bad"]:
		var changed:=context.duplicate(true);changed.initial_globals=value;reject_case(body,parent,relative,changed,"Invalid globals container "+str(value))
	for pair:Array in [["unknown",0],["collision_flags_u8",256],["volume_flags_u8",-1],["altitude_low_u32",4294967296],["altitude_high_s32",2147483648],["previous_altitude_high_s32",-2147483649],["collider_parent_selected",1],["collision_kind_u8",1.5]]:
		var changed:=context.duplicate(true);changed.initial_globals[pair[0]]=pair[1];reject_case(body,parent,relative,changed,"Invalid source global "+str(pair[0]))
	for index:int in [0,84,117,149]:
		var changed:=body.duplicate();changed.encode_u32(0x82,index);reject_case(changed,parent,relative,context,"Unsupported player model "+str(index))
	for index:int in [0,15,116,149]:
		var changed:=parent.duplicate();changed.encode_u32(0x82,index);reject_case(body,changed,relative,context,"Unsupported parent model "+str(index))
	# In-memory resource copies exercise a correctly rehashed, unsupported VM
	# record without modifying old resource files. Only the bounded natural
	# terrain record and its original empty exclusion tail may be classified.
	var saved_resources:Dictionary=Ground.collision_resources.duplicate(true)
	var changed_parent:=parent.duplicate();changed_parent.encode_u32(0x82,117)
	for opcode:int in [0x20,0x90,0xd0]:
		var changed_resources:=saved_resources.duplicate(true);var entry:Dictionary=changed_resources.models["117"]
		var stream:=str(entry.collision_bytes_hex).hex_decode();stream[0]=opcode
		entry.collision_bytes_hex=stream.hex_encode();entry.collision_bytes_sha256=Core._sha(stream);Ground.collision_resources=changed_resources
		reject_case(body,changed_parent,relative,context,"Unsupported conditional/plane/nested VM record "+str(opcode))
	Ground.collision_resources=saved_resources
	var saved_ships:Dictionary=Core._ship_models.duplicate(true)
	var bad_ship_resources:=saved_ships.duplicate(true);var bad_ship:Dictionary=bad_ship_resources["38"];var preceding:=str(bad_ship.preceding_children.hex).hex_decode()
	var offset:=preceding.size()-4;var encoded:=(preceding.decode_u16(offset)&0xfff9)|6;preceding.encode_u16(offset,encoded)
	bad_ship.preceding_children.hex=preceding.hex_encode();bad_ship.preceding_children.sha256=Core._sha(preceding);bad_ship.preceding_children.records[0].axis_radius_encoded_s16=Core._s16(encoded)
	Core._ship_models=bad_ship_resources
	var changed_body:=body.duplicate();changed_body.encode_u32(0x82,38);reject_case(changed_body,parent,relative,context,"Unsupported absent source axis6 child encoding")
	Core._ship_models=saved_ships
	var first:=core.classify_natural_player(body,parent,relative,context)
	for pass_index in range(3):check(equal_words(core.classify_natural_player(body,parent,relative,context),first),"Repeated pure classification is deterministic "+str(pass_index))
	check(Ground.new().height_raw(body,parent,relative).is_empty(),"Old zero-inner/zero-child height API keeps rejecting real positive-inner player shapes")
func run()->void:
	native_cases();contracts()
	var report:={"schema":1,"date":"2026-11-13","test":"source_natural_contact_core","source_contract":Core.CONTRACT,"source_sha256":Core.SOURCE_SHA,"checks":checks,"failures":failures,"native_case_count":0 if evidence.is_empty() else evidence[0].case_count,"source_file_sha256":FileAccess.get_sha256("res://scripts/source_natural_contact.gd"),"test_file_sha256":FileAccess.get_sha256("res://tests/test_source_natural_contact.gd"),"fixture_sha256":FileAccess.get_sha256(FIXTURE),"metadata_sha256":FileAccess.get_sha256(Core.DATA_PATH),"evidence":evidence,"scope":"Pure original F576→F579→natural F582→F581/F1876 classification; actual player15/24/38 offsets and natural117..148; no Main pose/HP/clock mutation, response, general planes/nested city/station collision or complete original scanner."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t")+"\n")
	print("Source natural contact core: "+str(checks)+" checks, "+str(failures)+" failures")
	quit(1 if failures>0 else 0)
