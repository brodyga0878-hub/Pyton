extends SceneTree
const Phase=preload("res://scripts/source_player_phase.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_player_phase_native.json"
const FIXTURE_SHA:="4aafa3fbb5d9319d11955629b1c252264961aff0bc358c29133ad79cf2c08d9f"
var checks:=0
var failures:=0
var cases:=0
var boundaries:=0
var sequences:=0
var operations:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<24:push_error(message)
func root_from(patches:Array)->PackedByteArray:
	var root:=PackedByteArray();root.resize(0x4000);root.fill(0xa5)
	for patch:Array in patches:
		var bytes:=str(patch[1]).hex_decode()
		for index in range(bytes.size()):root[int(patch[0])+index]=bytes[index]
	return root
func context_from(value:Dictionary)->Dictionary:
	return {"body":str(value.body_hex).hex_decode(),"root":root_from(value.root_patch),"external":value.external.duplicate(true)}
func responses(row:Dictionary)->Array:
	var result:Array=[]
	for source:Dictionary in row.expected.observations:
		var item:={"kind":source.kind,"args":source.args.duplicate(),"before":context_from(source.before),"after":context_from(source.after),"return_u32":source.return_u32}
		if source.kind=="F1033":item.collider_body=str(source.collider_hex).hex_decode();item.collider_index=source.collider_index
		result.append(item)
	return result
func hash_external(value:Dictionary)->String:return Clock._hash(value)
func difference(a:PackedByteArray,b:PackedByteArray)->String:
	var cells:Array=[]
	for i in range(mini(a.size(),b.size())):
		if a[i]!=b[i]:cells.append("%x:%x/%x"%[i,a[i],b[i]])
	return str(cells.slice(0,12))
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Whole original phase oracle fixture is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.schema=="starfrontier-source-player-phase-native-v1" and fixture.profile==Phase.PROFILE and fixture.case_count==288 and fixture.cases.size()==288,"All288 whole original phase controls exist")
	check(FileAccess.get_sha256("res://validation/player-cycle-2026-11-17/phase-native-proof/instruction-proof.json")==fixture.instruction_proof_sha256,"Whole40-procedure binary proof is bound to this native fixture")
	check(FileAccess.get_sha256("res://validation/player-cycle-2026-11-17/phase-native-proof/source-procedures.s")==fixture.source_procedures_sha256 and FileAccess.get_sha256("res://validation/player-cycle-2026-11-17/phase-native-proof/player-phase-native.s")==fixture.host_assembly_sha256,"Verified original source and reviewed host adapter identities match fixture")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_cases==288 and fixture.consecutive_native_steps==32 and not fixture.expected_arithmetic_calculated_in_python,"Fresh native controls and dependent original phases execute without Python expected arithmetic")
	var previous_body:=PackedByteArray();var previous_root:=PackedByteArray();var previous_external:Dictionary={}
	var first_row:Dictionary={};var continued_row:Dictionary={};var audio_row:Dictionary={};var clear_contact_row:Dictionary={};var post_drift:=0;var pre_drift:=0;var f606_mutations:=0
	for row:Dictionary in fixture.cases:
		var body:=str(row.body_before_hex).hex_decode();var parent:=str(row.parent_hex).hex_decode();var root:=root_from(row.root_before_patch);var external:Dictionary=row.external_before.duplicate(true);var observed:=responses(row)
		var frozen:=var_to_bytes([body,parent,root,external,observed])
		var result:=Phase.execute(str(row.operation),body,parent,root,external,observed)
		cases+=1;operations[str(row.operation)]=true;boundaries+=observed.size()
		check(result.get("ok",false),"Whole original phase executes: "+row.name+" "+str(result.get("reason"))+" "+str(result.get("observations_used")))
		if not result.get("ok",false):
			if failures<12:print("ORDER ",result.get("source_order")," EXPECTED ",row.expected.source_order)
			continue
		var expected_body:=str(row.expected.body_after_hex).hex_decode();var expected_root:=root_from(row.expected.root_after_patch)
		check(result.body_after==expected_body,"All338 body bytes match DOS phase: "+row.name+" "+difference(result.body_after,expected_body))
		check(result.root_after==expected_root,"All16384 Root bytes and logical refs match DOS phase: "+row.name+" "+difference(result.root_after,expected_root))
		check(hash_external(result.external_after)==hash_external(row.expected.external_after),"Every external cell matches DOS phase: "+row.name)
		check(result.source_order==row.expected.source_order,"Whole original source order matches: "+row.name+" "+str(result.source_order)+" / "+str(row.expected.source_order))
		check(result.observations_used==observed.size() and result.requests==observed,"Every boundary consumes exact before/after context in source order: "+row.name)
		check(not result.raw_owners_mutated and not result.full_world_effects_executed and not result.live_Main_motion_replaced and var_to_bytes([body,parent,root,external,observed])==frozen,"Caller Root/body/parent/external and observation owners stay unchanged: "+row.name)
		if first_row.is_empty():first_row=row
		if observed.size()>=5 and continued_row.is_empty():continued_row=row
		if "F1046" in result.source_order and "F601" in result.source_order:
			if row.operation=="phase_f1019":check(result.source_order.find("F1046")<result.source_order.find("F601"),"F1019 original drift precedes kick");pre_drift+=1
			else:check(result.source_order.find("F1046")>result.source_order.find("F601"),"F1021 original drift follows kick");post_drift+=1
		for item:Dictionary in observed:
			if item.kind=="F606" and item.before.root!=item.after.root:f606_mutations+=1
			if item.kind=="F1910" and audio_row.is_empty():audio_row=row
			if item.kind=="F1033" and int(item.return_u32)==0 and clear_contact_row.is_empty():clear_contact_row=row
		if row.has("sequence_step"):
			if sequences>0:check(body==previous_body and root==previous_root and hash_external(external)==hash_external(previous_external),"Consecutive phase begins from exact previous native output")
			previous_body=result.body_after;previous_root=result.root_after;previous_external=result.external_after;sequences+=1
	check(operations.size()==2 and pre_drift>0 and post_drift>0 and f606_mutations>0,"Both whole source phases, opposite drift order and mutable F606 alias continuation are exercised")
	check(sequences==32,"All32 original dependent phases preserve body/Root/scratch residues")
	if not continued_row.is_empty():
		var row:=continued_row;var observed:=responses(row);var admitted:Array=[];var body:=str(row.body_before_hex).hex_decode();var parent:=str(row.parent_hex).hex_decode();var root:=root_from(row.root_before_patch);var external:Dictionary=row.external_before
		for index in range(observed.size()):
			var pending:=Phase.execute(row.operation,body,parent,root,external,admitted)
			check(not pending.ok and pending.reason=="boundary_required" and pending.observations_used==index and pending.pending.kind==observed[index].kind and Clock._hash({"args":pending.pending.args})==Clock._hash({"args":observed[index].args}) and pending.pending.before.body==observed[index].before.body and pending.pending.before.root==observed[index].before.root and hash_external(pending.pending.before.external)==hash_external(observed[index].before.external),"Owner can resume only the next actual source boundary")
			admitted.append(observed[index])
		var finished:=Phase.execute(row.operation,body,parent,root,external,admitted)
		check(finished.ok and finished.body_after==str(row.expected.body_after_hex).hex_decode() and finished.root_after==root_from(row.expected.root_after_patch),"Incremental actual boundary responses resume the complete original phase")
	if not first_row.is_empty():
		var row:=first_row;var body:=str(row.body_before_hex).hex_decode();var parent:=str(row.parent_hex).hex_decode();var root:=root_from(row.root_before_patch);var external:Dictionary=row.external_before;var observed:=responses(row)
		var frozen:=var_to_bytes([body,parent,root,external,observed])
		for value:Variant in [null,true,{},[],"body",PackedByteArray()]:check(not Phase.execute(row.operation,value,parent,root,external,observed).ok,"Malformed body rejects")
		for value:Variant in [null,true,{},[],"root",PackedByteArray()]:check(not Phase.execute(row.operation,body,parent,value,external,observed).ok,"Malformed full Root rejects")
		for key:String in Phase.EXTERNAL_KEYS:
			var bad:=external.duplicate(true);bad.erase(key);check(not Phase.execute(row.operation,body,parent,root,bad,observed).ok,"Missing external cell rejects: "+key)
		for value:Variant in [null,true,0,"step",""]:check(not Phase.execute(value,body,parent,root,external,observed).ok,"Invented universal phase rejects")
		for at in [0,0xe0,0xc8,0x3fb6,0x3fff]:
			var bad:=observed.duplicate(true);bad[0].before.root[at]=int(bad[0].before.root[at])^1
			check(not Phase.execute(row.operation,body,parent,root,external,bad).ok,"Any unmatched Root byte rejects at the boundary")
		var bad:=observed.duplicate(true);bad[0].before.external.transfer_state_u32=int(bad[0].before.external.transfer_state_u32)^1
		check(not Phase.execute(row.operation,body,parent,root,external,bad).ok,"Unmatched external context rejects")
		bad=observed.duplicate(true);bad.append(observed[0]);check(not Phase.execute(row.operation,body,parent,root,external,bad).ok,"Unused world response rejects")
		check(var_to_bytes([body,parent,root,external,observed])==frozen,"Rejected phase transactions preserve every input owner")
	if not clear_contact_row.is_empty():
		var row:=clear_contact_row;var observed:=responses(row)
		for item:Dictionary in observed:
			if item.kind=="F1033":item.collider_index=0;item.collider_body=PackedByteArray();item.collider_body.resize(338)
		var result:=Phase.execute(row.operation,str(row.body_before_hex).hex_decode(),str(row.parent_hex).hex_decode(),root_from(row.root_before_patch),row.external_before,observed)
		check(result.ok,"No-contact source result admits logical collider0 when no following branch reads a collider")
		for item:Dictionary in observed:
			if item.kind=="F1033":item.return_u32=0x20
		check(not Phase.execute(row.operation,str(row.body_before_hex).hex_decode(),str(row.parent_hex).hex_decode(),root_from(row.root_before_patch),row.external_before,observed).ok,"Contact branch cannot dereference a missing logical collider")
	if not audio_row.is_empty():
		var row:=audio_row;var observed:=responses(row)
		for item:Dictionary in observed:
			if item.kind=="F1910":item.after.root[0x3fff]=int(item.after.root[0x3fff])^1;break
		var result:=Phase.execute(row.operation,str(row.body_before_hex).hex_decode(),str(row.parent_hex).hex_decode(),root_from(row.root_before_patch),row.external_before,observed)
		check(not result.ok and result.reason=="presentation_boundary_mutated_player","Audio observer cannot mutate any byte of the raw Root")
	var sources:Dictionary={}
	for path:String in ["scripts/source_player_phase.gd","scripts/source_player_context.gd","tests/test_source_player_phase.gd","tests/fixtures/source_player_phase_native.json","tools/rebuild_source_player_phase_native.py","validation/player-cycle-2026-11-17/phase-native-proof/instruction-proof.json","validation/player-cycle-2026-11-17/phase-native-proof/source-procedures.s"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"))
	var report:=FileAccess.open("res://build/current-test-reports/source-player-phase.json",FileAccess.WRITE)
	if report:report.store_string(JSON.stringify({"profile":Phase.PROFILE,"checks":checks,"failures":failures,"native_cases":cases,"matched_boundaries":boundaries,"consecutive_phases":sequences,"source_order_pre_drift_cases":pre_drift,"source_order_post_drift_cases":post_drift,"F606_alias_mutation_cases":f606_mutations,"sources":sources,"full_world_effects_executed":false,"live_Main_motion_replaced":false,"physical_device_tested":false},"\t"));report.close()
	print("SOURCE PLAYER PHASE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
