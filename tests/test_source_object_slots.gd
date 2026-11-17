extends SceneTree
const Slots=preload("res://scripts/source_object_slots.gd")
const FIXTURE:="res://tests/fixtures/source_object_slots_native.json"
const PROOF:="res://validation/damage-core-2026-11-17/slots-native-proof/"
const REPORT:="res://build/current-test-reports/source-object-slots.json"
var checks:=0
var failures:Array=[]
var dependencies:Dictionary={}
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func make_bank(seed:Dictionary)->PackedByteArray:
	var raw:=str(seed.header_hex).hex_decode();var template:=str(seed.template_hex).hex_decode()
	for _i:int in range(115):raw.append_array(template)
	for key:String in seed.overrides:
		var body:=str(seed.overrides[key]).hex_decode();var offset:=116+int(key)*338
		for i:int in range(338):raw[offset+i]=body[i]
	return raw
func execute(row:Dictionary)->Dictionary:
	var bank:=make_bank(row.bank_before);var source:=str(row.source_body_hex).hex_decode();var window:=str(row.module_window_before_hex).hex_decode()
	if int(row.operation_u32)==0:return Slots.allocate(bank,source,row.model_index_u32,row.flags_u8,row.clock,row.recyclable_count_before_u32,row.source_slot_s32)
	var observations:Array=[]
	for i:int in range(row.event_replies.size()):observations.append({"before":row.expected.events[i],"reply":row.event_replies[i]})
	return Slots.release(bank,row.body_slot_u32,row.reason_u8,row.recyclable_count_before_u32,window,row.module_highest_before_s32,observations,int(row.operation_u32)==2)
func compare_case(row:Dictionary)->void:
	var before:=make_bank(row.bank_before);var before_hash:=Slots._sha(before);var source:=str(row.source_body_hex).hex_decode();var source_before:=source.duplicate()
	var result:=execute(row);var label:=str(row.name)
	check(result.get("ok",false),label+" accepted "+str(result.get("reason","")))
	if not result.get("ok",false):return
	var expected:Dictionary=row.expected
	check(Slots._sha(result.bank_after)==expected.bank_after_sha256,label+" all115 raw records and flags")
	check(result.bank_after.slice(0,116).hex_encode()==expected.bank_header_after_hex,label+" header")
	for key:String in ["selected_slot_u32","return_body_offset_u32","recyclable_count_after_u32","factory_copy_calls_u32","factory_lookup_calls_u32"]:check(result[key]==expected[key],label+" "+key)
	if int(row.operation_u32)!=0:
		check(result.module_highest_after_s32==expected.module_highest_after_s32,label+" callback loop limit")
		check(result.module_window_after.hex_encode()==expected.module_window_after_hex,label+" module flag/private window")
	else:
		check(result.external_source_body_after.hex_encode()==expected.external_source_body_after_hex,label+" external template untouched")
		check(result.source_pointer_body_after.hex_encode()==expected.source_pointer_body_after_hex,label+" actual alias pointer post-state")
		if int(result.selected_slot_u32)>0:
			var at:=116+int(result.selected_slot_u32)*338
			check(result.bank_after.slice(at,at+338).hex_encode()==expected.selected_body_after_hex,label+" factory raw result")
	var events_match:bool=result.events.size()==expected.events.size()
	for i:int in range(result.events.size()):events_match=events_match and Slots._same_fields(result.events[i],expected.events[i])
	check(events_match,label+" every F144 input before mutation")
	check(Slots._sha(before)==before_hash and source==source_before,label+" caller owners untouched")
func invalid_controls(rows:Array)->void:
	var row:Dictionary=rows[0];var bank:=make_bank(row.bank_before);var source:=str(row.source_body_hex).hex_decode();var initial:=bank.duplicate();var clock:Dictionary=row.clock
	for bad:Variant in [-1,149,155,0.5,NAN,INF,"38",true]:check(not Slots.allocate(bank,source,bad,1,clock,0).ok,"reject unsupported model "+str(bad))
	for bad:Variant in [-1,256,0.5,NAN,"1",true]:check(not Slots.allocate(bank,source,38,bad,clock,0).ok,"reject flags "+str(bad))
	for bad:Variant in [-2,115,0.5,"0",true]:check(not Slots.allocate(bank,source,38,1,clock,0,bad).ok,"reject source alias "+str(bad))
	for bad:Variant in [-1,4294967296.0,0.5,NAN,true]:check(not Slots.allocate(bank,source,38,1,clock,bad).ok,"reject count "+str(bad))
	check(not Slots.allocate(bank.slice(1),source,38,1,clock,0).ok,"reject truncated bank")
	check(not Slots.allocate(bank,source.slice(1),38,1,clock,0).ok,"reject truncated source")
	check(not Slots.allocate(bank,source,38,1,{"tick_u32":0},0).ok,"reject missing factory clock")
	var window:=PackedByteArray();window.resize(168)
	for bad:Variant in [-2,21,0.5,true]:check(not Slots.release(bank,1,0,0,window,bad).ok,"reject module limit")
	var bad_bank:=bank.duplicate();bad_bank[116+338+0x86]=115
	check(not Slots.release(bad_bank,1,0,0,window,-1).ok,"reject record slot outside owned bank")
	for value:Variant in [[],{},1,"00"]:check(not Slots.release(bank,1,0,0,value,-1).ok,"reject malformed module window")
	var event_row:Dictionary={}
	for candidate:Dictionary in rows:
		if candidate.name=="event-grow-limit-activate-and-body-index-mutate":event_row=candidate;break
	check(not event_row.is_empty(),"mutation controls exist")
	if not event_row.is_empty():
		var eb:=make_bank(event_row.bank_before);var ew:=str(event_row.module_window_before_hex).hex_decode();var obs:Array=[]
		for i:int in range(event_row.event_replies.size()):obs.append({"before":event_row.expected.events[i].duplicate(true),"reply":event_row.event_replies[i].duplicate(true)})
		var snapshot:=eb.duplicate();check(not Slots.release(eb,37,event_row.reason_u8,5,ew,0,[]).ok,"missing callback fails closed")
		var bad:=obs.duplicate(true);bad[0].before.bank_before_sha256="0".repeat(64)
		check(not Slots.release(eb,37,event_row.reason_u8,5,ew,0,bad).ok,"callback raw precondition mismatch")
		bad=obs.duplicate(true);bad[0].reply.bank_patches=[{"offset_u32":38985,"hex":"aabb"}]
		check(not Slots.release(eb,37,event_row.reason_u8,5,ew,0,bad).ok,"callback out-of-bank patch")
		bad=obs.duplicate(true);bad[0].reply.module_highest_after_s32=21
		check(not Slots.release(eb,37,event_row.reason_u8,5,ew,0,bad).ok,"callback unsafe next loop bound")
		bad=obs.duplicate(true);bad.append(obs[0])
		check(not Slots.release(eb,37,event_row.reason_u8,5,ew,0,bad).ok,"unused callback rejects")
		check(eb==snapshot,"callback rejection leaves original owner intact")
	check(bank==initial,"all invalid allocations leave caller unchanged")
func _initialize()->void:
	var doc:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(doc is Dictionary,"native fixture parsed")
	if not doc is Dictionary:finish();return
	check(doc.profile==Slots.PROFILE and int(doc.case_count)==doc.cases.size(),"source profile and count")
	check(int(doc.case_count)>=970 and int(doc.fresh_process_runs)==3 and int(doc.reverse_repeat_cases)==doc.cases.size() and int(doc.consecutive_original_steps)==24,"independent full bank bank/callback controls")
	check(not doc.expected_arithmetic_calculated_in_python,"expected arithmetic native only")
	check(FileAccess.get_sha256(PROOF+"instruction-proof.json")==doc.instruction_proof_sha256,"whole DOS proof pinned")
	check(FileAccess.get_sha256(PROOF+"source-procedures.asm")==doc.source_procedures_sha256,"captured source pinned")
	check(FileAccess.get_sha256(PROOF+"slots-native.s")==doc.host_adapted_assembly_sha256,"host ABI adapter pinned")
	dependencies=doc.source_dependencies_sha256.duplicate(true)
	for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"source dependency "+path)
	for row:Dictionary in doc.cases:compare_case(row)
	invalid_controls(doc.cases)
	finish()
func finish()->void:
	var sources:Dictionary={}
	for path:String in ["scripts/source_object_slots.gd","scripts/source_object_factory.gd","scripts/source_orbit.gd","tests/test_source_object_slots.gd",FIXTURE.trim_prefix("res://"),PROOF.trim_prefix("res://")+"instruction-proof.json",PROOF.trim_prefix("res://")+"source-procedures.asm",PROOF.trim_prefix("res://")+"slots-native.s"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	var report:={"suite":"source_object_slots","profile":Slots.PROFILE,"checks":checks,"failures":failures.size(),"failure_details":failures,"sources":sources,"fixture_sha256":FileAccess.get_sha256(FIXTURE),"new_APK":false,"live_Main_integration":false,"full_F144_or_F942_engine":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(report,"\t")+"\n")
	print("SOURCE OBJECT SLOTS TESTS: %d checks, %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
