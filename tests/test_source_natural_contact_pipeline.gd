extends SceneTree
# Composition checks: the new native fixture independently proves F576;
# source_surface_contact has its separate native F575-continuation proof.
# This suite does not claim an independently executed combined native chain.
const Pipeline=preload("res://scripts/source_natural_contact_pipeline.gd")
const Natural=preload("res://scripts/source_natural_contact.gd")
const Response=preload("res://scripts/source_surface_contact.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const FIXTURE:="res://tests/fixtures/source_natural_contact_native.json"
const REPORT:="res://build/current-test-reports/source-natural-contact-pipeline.json"
var pipeline:=Pipeline.new()
var checks:=0
var failures:=0
var evidence:Array=[]
var totals:={"native_cases":0,"responses":0,"early_returns":0,"early_returns_with_flag2":0,"inner_hits_preserving_previous_high":0}

func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=35:push_error(label)
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
func vector_from_hex(value:String)->PackedInt64Array:
	var raw:=value.hex_decode()
	return PackedInt64Array([raw.decode_s64(0),raw.decode_s64(8),raw.decode_s64(16)])
func context_for(initial:Dictionary,player_index:int,graphics:int=1)->Dictionary:
	# Fixture transport observes eleven source globals plus pointer identity.
	# Expand the remaining query-side fields explicitly in this test adapter;
	# the production pipeline itself never supplies absent caller words.
	return {"initial_globals":Natural._globals(initial),"player_object_index_u32":player_index,"graphics_level":graphics}
func raw_case(ship_index:int=24)->Dictionary:
	var ship:=Natural.ship_model(ship_index);var body:=PackedByteArray();body.resize(338);body.fill(0)
	for axis in range(3):body.encode_s32(axis*16,0x7fffffff)
	body.encode_u32(0x82,ship_index);body[0x86]=1;body[0x56]=2;body[0x57]=1;body[0x14c]=int(ship.initial_object_flags_14c_u8)
	body.encode_s64(0x138,int(ship.f1533_radii.outer_s64));body.encode_s64(0x140,int(ship.f1533_radii.inner_s64));body.encode_u16(0x9e,65535)
	var parent:=body.duplicate();parent[0x86]=2;parent.encode_u32(0xa0,0x12345678)
	parent=Ground.initialize_model(parent,120).object
	var previous:=0x33445566
	var context:=context_for({"altitude_low_u32":0x89abcdef,"altitude_high_s32":-0x1234567,"previous_altitude_low_u32":previous,"previous_altitude_high_s32":-0x2345678,"collision_active_u8":1,"collision_enabled_u8":1,"recorded_intersection_raw":-117,"pending_query_flag":19},1)
	return {"body":body,"parent":parent,"relative":PackedInt64Array([0,parent.decode_s64(0x140)/2,0]),"context":context}
func reject_case(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,context:Dictionary,label:String)->void:
	var before:=var_to_bytes([body,parent,relative,context]);var result:=pipeline.resolve_natural_player(body,parent,relative,context)
	check(not result.ok and result.body_after==body and result.parent_after==parent and result.relative_position_s64==relative and not result.response_applied and not result.contact_detected and result.damage_calls.is_empty() and result.callbacks.is_empty() and result.global_writes.is_empty(),label+" rejects atomically without response or damage")
	check(var_to_bytes([body,parent,relative,context])==before,label+" preserves all caller buffers")
	if context.get("initial_globals") is Dictionary:check(equal_words(result.globals_after,context.initial_globals),label+" retains exact caller globals rather than publishing partial classifier writes")
func raw_boundaries()->void:
	var row:=raw_case();var body:PackedByteArray=row.body;var parent:PackedByteArray=row.parent;var relative:PackedInt64Array=row.relative;var context:Dictionary=row.context
	var before:=var_to_bytes(row);var result:=pipeline.resolve_natural_player(body,parent,relative,context)
	check(result.ok and result.response_applied and result.dispatch=="f575_natural_kind1_response","Actual source inner-bound classification enters the supported continuation")
	check(var_to_bytes(row)==before,"Successful raw composition leaves source objects, original relative vector and context immutable")
	if result.ok:
		check(result.classification.terrain_query_calls==0 and result.globals_after.previous_altitude_high_s32==context.initial_globals.previous_altitude_high_s32 and result.globals_after.previous_altitude_low_u32==context.initial_globals.previous_altitude_low_u32,"Inner sphere fast branch preserves caller previous-altitude high and low words")
		check(result.globals_after.altitude_high_s32==context.initial_globals.altitude_high_s32 and result.globals_after.altitude_low_u32==context.initial_globals.altitude_low_u32,"Pipeline performs no hidden F574 altitude reset on an inner-bound hit")
		check(result.previous_altitude_s64==((int(context.initial_globals.previous_altitude_high_s32)<<32)|int(context.initial_globals.previous_altitude_low_u32)),"Signed64 previous altitude reaches F575 without float or phone-AGL substitution")
		var fresh:=pipeline.resolve_natural_player(body,parent,relative,context)
		result.body_after[0]=0;result.parent_after[0]=0;result.relative_position_s64[0]=19;result.globals_after.previous_altitude_high_s32=0;result.classification.body_after[0]=0;result.response.globals_after.previous_altitude_s64=0
		check(var_to_bytes(row)==before and equal_words(pipeline.resolve_natural_player(body,parent,relative,context),fresh),"Returned raw bodies, vectors, globals and nested stages are private and cannot affect a repeat call")
	for key:String in Natural.GLOBAL_KEYS:
		var invalid:=context.duplicate(true);invalid.initial_globals.erase(key);reject_case(body,parent,relative,invalid,"Absent explicit caller global "+key)
	for key:String in ["initial_globals","player_object_index_u32"]:
		var invalid:=context.duplicate(true);invalid.erase(key);reject_case(body,parent,relative,invalid,"Missing context "+key)
	var invalid:=context.duplicate(true);invalid.player_object_index_u32=2;reject_case(body,parent,relative,invalid,"Object does not match explicit source player identity")
	invalid=context.duplicate(true);invalid.initial_globals.previous_altitude_high_s32=0.5;reject_case(body,parent,relative,invalid,"Fractional source high word")
	invalid=context.duplicate(true);invalid.graphics_level=16;reject_case(body,parent,relative,invalid,"Unsupported graphics query level")
	invalid=context.duplicate(true);invalid["phone_agl_m"]=0.0;reject_case(body,parent,relative,invalid,"Phone height is not a raw classifier operand")
	var unsupported:=parent.duplicate();unsupported[0x14c]=0;reject_case(body,unsupported,relative,context,"Parent does not enter the original natural F575 dispatch")
	var classified:=Natural.new().classify_natural_player(body,parent,relative,{"initial_globals":context.initial_globals,"graphics_level":1})
	for kind:int in [0,2,255]:
		# Explicit synthetic guard controls only. Supported natural programs
		# normally return0 with kind1; these are not native hit observations.
		var control:=classified.duplicate(true);control.f576_return_s32=0;control.globals_after.collision_kind_u8=kind
		var snapshot:=var_to_bytes([row,control]);var denied:=pipeline._dispatch_classification(body,parent,relative,context,control)
		check(not denied.ok and denied.error==("unsupported_f578_contact" if kind==0 else "unsupported_f575_contact_kind") and denied.body_after==body and equal_words(denied.globals_after,context.initial_globals) and denied.damage_calls.is_empty() and denied.callbacks.is_empty(),"Synthetic unsupported dispatch kind"+str(kind)+" publishes no classifier writes or F953 requests")
		check(var_to_bytes([row,control])==snapshot,"Synthetic unsupported dispatch control remains immutable")
	evidence.append({"case":"raw_caller_boundary","full_globals_required":true,"high_previous_words_preserved":true,"caller_reset_executed":false,"synthetic_unsupported_dispatch_controls":[0,2,255],"private_return_buffers":true})
func native_composition()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) if FileAccess.file_exists(FIXTURE) else null
	check(fixture is Dictionary and fixture.get("source_sha256")==Natural.SOURCE_SHA,"Independent F576 fixture identifies the uploaded executable")
	if not fixture is Dictionary:return
	for sample:Dictionary in fixture.cases:
		var label:=str(sample.get("id",sample.get("name","native case")));var body:=str(sample.player_object_hex).hex_decode();var parent:=str(sample.parent_object_hex).hex_decode();var relative:=vector_from_hex(str(sample.relative_before_hex))
		var context:=context_for(sample.context.initial_globals,int(body[0x86]),int(sample.context.graphics_level));var before:=var_to_bytes([sample,body,parent,relative,context]);var result:=pipeline.resolve_natural_player(body,parent,relative,context)
		totals.native_cases+=1
		check(result.ok,label+" accepts the independent raw source classifier operands")
		check(var_to_bytes([sample,body,parent,relative,context])==before,label+" preserves fixture, body, parent, original vector and explicit caller globals")
		if not result.ok:continue
		var native_return:=int(sample.expected.f576_return_s32)
		check(result.f576_return_s32==native_return and result.classification.body_after.hex_encode()==str(sample.expected.player_hex) and result.classification.parent_after.hex_encode()==str(sample.expected.parent_hex) and result.classification.relative_position_s64==vector_from_hex(str(sample.expected.relative_after_hex)),label+" classifier stage matches independently executed F576 return and all caller buffers")
		for key:String in sample.expected.globals:
			check(equal_words(result.classification.globals_after[key],sample.expected.globals[key]),label+" exact independently observed classifier global "+key)
		if native_return!=0:
			totals.early_returns+=1
			if int(result.return_flags_u8)&2:totals.early_returns_with_flag2+=1
			check(not result.response_applied and not result.contact_detected and not result.landing_accepted and result.body_after==body and result.parent_after==parent and result.damage_calls.is_empty() and result.callbacks.is_empty() and result.response.is_empty(),label+" F575 early return is a successful no-response outcome without damage")
			check(equal_words(result.globals_after,result.classification.globals_after),label+" early return preserves exact classified globals")
		else:
			totals.responses+=1
			check(int(sample.expected.globals.collision_kind_u8)==1 and result.response_applied and result.contact_detected,label+" kind1 native classification selects the supported response")
			var ship:=Natural.ship_model(body.decode_u32(0x82));var descriptor:=Natural.parent_model(parent.decode_u32(0x82));var response_globals:Dictionary=result.classification.globals_after.duplicate(true)
			response_globals["previous_altitude_s64"]=(int(response_globals.previous_altitude_high_s32)<<32)|int(response_globals.previous_altitude_low_u32);response_globals["player_object_index_u32"]=int(body[0x86])
			var expected:=Response.resolve_player(body,parent,{"relative_position_s64":relative,"distance_squared_s32":0,"globals":response_globals,"body_descriptor":ship.descriptor,"parent_descriptor":descriptor.descriptor,"body_spec":str(ship.physical_spec_hex).hex_decode()})
			check(expected.ok and result.body_after==expected.body_after and result.parent_after==expected.parent_after and equal_words(result.damage_calls,expected.damage_calls) and equal_words(result.callbacks,expected.callbacks) and result.landing_accepted==expected.landing_accepted,label+" composition passes the original relative vector and raw classified height to the separately proved F575 continuation")
			check(equal_words(result.response,expected),label+" entire continuation result agrees with direct composition")
			for key:String in Natural.GLOBAL_KEYS:check(equal_words(result.globals_after[key],expected.globals_after[key]),label+" exact composed raw global "+key)
			if result.classification.terrain_query_calls==0 and int(context.initial_globals.previous_altitude_high_s32)!=0:
				totals.inner_hits_preserving_previous_high+=1
				check(result.globals_after.previous_altitude_high_s32==context.initial_globals.previous_altitude_high_s32 and result.globals_after.previous_altitude_low_u32==context.initial_globals.previous_altitude_low_u32,label+" inner-bound classification retains native caller previous words")
	check(totals.native_cases==fixture.cases.size() and totals.responses>0 and totals.early_returns>0 and totals.early_returns_with_flag2>0 and totals.inner_hits_preserving_previous_high>0,"Fixture covers supported responses, real no-responses with flag2, and preserved nonzero previous high words")
	evidence.append({"case":"native_classifier_composition","counts":totals.duplicate(true),"classifier_expected":"independently executed original native F576 fixture","continuation_expected":"direct composition with separately native-proved source_surface_contact","combined_native_chain_executed":false,"HP_RNG_fuel_clock_executed":false,"full_F575_broad_phase_executed":false})
func run()->void:
	raw_boundaries();native_composition()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	var sources:={"pipeline_sha256":FileAccess.get_sha256("res://scripts/source_natural_contact_pipeline.gd"),"test_sha256":FileAccess.get_sha256("res://tests/test_source_natural_contact_pipeline.gd"),"classifier_sha256":FileAccess.get_sha256("res://scripts/source_natural_contact.gd"),"response_sha256":FileAccess.get_sha256("res://scripts/source_surface_contact.gd"),"native_fixture_sha256":FileAccess.get_sha256(FIXTURE) if FileAccess.file_exists(FIXTURE) else "missing"}
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"counts":totals,"sources":sources,"evidence":evidence,"scope":Pipeline.SCOPE,"combined_native_chain_executed":false},"\t"));file.close()
	print("Source natural contact pipeline: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
