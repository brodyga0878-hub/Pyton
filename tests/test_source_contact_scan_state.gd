extends SceneTree
const State=preload("res://scripts/source_contact_scan_state.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_contact_scan_native.json"
const FIXTURE_SHA:="d0f5355216aeb30f5f9f66dce713609c8d13728e3992b52cf4a0c35c53ae7657"
const REPORT:="res://build/current-test-reports/source-contact-scan-state.json"
var checks:=0
var failures:=0
var native_cases:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<24:push_error(message)
func digest(value:Dictionary)->String:return Clock._hash(value)
func base()->Dictionary:
	var body:=PackedByteArray();body.resize(338);body[0x86]=17;body.encode_u32(0x82,24)
	var collider:=PackedByteArray();collider.resize(338);collider[0x86]=9;collider.encode_u32(0x82,24);collider.encode_s64(0x3e,9000)
	var flags:=PackedByteArray();flags.resize(115);flags[17]=4;flags[9]=4
	var root:=PackedByteArray();root.resize(0x4000);root.fill(0xa5);root.encode_u32(0xc0,17);root.encode_u32(0xc8,17);root.encode_u32(0xcc,0)
	var globals:Dictionary={}
	for key:String in Frame.GLOBAL_KEYS:globals[key]=0
	return {"body":body,"objects":{9:collider},"flags":flags,"root":root,"globals":globals,"ticks":17,"source_frame":31}
func configure(owner:RefCounted,context:Dictionary)->bool:return owner.configure(context.body,context.objects,context.flags,context.root,context.globals,context.ticks,context.source_frame)
func sign_snapshot(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true);result.erase("snapshot_sha256");result.snapshot_sha256=digest(result);return result
func change_hex(value:String,offset:int)->String:
	var bytes:=value.hex_decode();bytes[offset]=int(bytes[offset])^1;return bytes.hex_encode()
func ownership()->void:
	var owner:=State.new();var context:=base();var frozen:=var_to_bytes(context)
	check(not owner.is_active() and owner.generation()==0 and owner.snapshot().is_empty() and owner.raw_core().is_empty(),"A fresh collision owner has no inferred raw bank")
	check(not owner.prepare().ok and not owner.commit({}),"An inactive owner cannot scan or commit")
	check(configure(owner,context) and owner.is_active() and owner.generation()==0,"Explicit raw bank, Root and source globals configure together")
	var initial:=owner.snapshot();var initial_hash:=digest(initial);var prepared:=owner.prepare()
	check(prepared.ok and prepared.candidate_state.generation()==1 and prepared.receipt.classifier_calls.size()==1,"A private candidate performs the actual source classifier scan")
	if not prepared.ok:return
	check(digest(owner.snapshot())==initial_hash and owner.generation()==0 and var_to_bytes(context)==frozen,"Prepare scans a private copy without changing the live or supplied bank")
	var raw:=owner.raw_core();raw.globals.collision_flags_u8=99;raw.objects_hex["9"]="00"
	check(digest(owner.snapshot())==initial_hash,"Raw accessors cannot alias the owned bank")
	var returned:=owner.snapshot();returned.core.globals.collision_flags_u8=99
	check(digest(owner.snapshot())==initial_hash,"Portable snapshot data cannot mutate the live owner")
	var peer:=State.new();check(configure(peer,context) and not peer.commit(prepared),"A matching second raw bank cannot commit another owner's token")
	for key:String in ["owner_instance_id","owner_revision","before_generation","before_core_sha256","profile"]:
		var bad:=prepared.duplicate(true);bad[key]="forged" if key in ["before_core_sha256","profile"] else 0
		if key=="before_generation":bad[key]=1
		check(not owner.commit(bad) and digest(owner.snapshot())==initial_hash,"Forged transaction context rejects atomically: "+key)
	for key:String in ["receipt","contact_boundary"]:
		for bad_value:Variant in [null,true,0,"receipt",[]]:
			var bad:=prepared.duplicate(true);bad[key]=bad_value
			check(not owner.commit(bad) and digest(owner.snapshot())==initial_hash,"Malformed prepared publication rejects: "+key)
	var bad:=prepared.duplicate(true);bad.receipt.outputs.flags_u8=int(bad.receipt.outputs.flags_u8)^1
	check(not owner.commit(bad),"Changing scan output receipt cannot bypass original replay")
	bad=prepared.duplicate(true);bad.contact_boundary.flags_u8=int(bad.contact_boundary.flags_u8)^1
	check(not owner.commit(bad),"Changing the F1033 response cannot bypass exact provenance replay")
	bad=prepared.duplicate(true);bad.candidate_state=owner
	check(not owner.commit(bad),"A live owner is not its own publishable candidate")
	bad=prepared.duplicate(true);bad.candidate_state=RefCounted.new()
	check(not owner.commit(bad),"An unrelated candidate class cannot commit")
	var forged:Dictionary=prepared.candidate_state.snapshot();forged.core.body_hex=change_hex(forged.core.body_hex,0)
	check(not prepared.candidate_state.restore(sign_snapshot(forged)),"A rehashed candidate body that disagrees with replay rejects")
	var competitor:=owner.prepare()
	check(competitor.ok and owner.commit(prepared) and owner.generation()==1,"A verified source scan publishes exactly one generation")
	var committed:=owner.snapshot();var committed_hash:=digest(committed)
	check(not owner.commit(prepared) and not owner.commit(competitor) and digest(owner.snapshot())==committed_hash,"Repeated and stale prepared scans cannot publish")
	var outstanding:=owner.prepare();check(outstanding.ok,"Next scan can be prepared from the published raw bank")
	check(owner.restore(JSON.parse_string(JSON.stringify(committed))) and not owner.commit(outstanding),"Cold JSON restore invalidates outstanding tokens even at identical content")
	var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(committed))) and digest(cold.raw_core())==digest(owner.raw_core()),"A new owner restores the raw collision bank through witness replay")
	var hot_next:=owner.prepare();var cold_next:=cold.prepare()
	check(hot_next.ok and cold_next.ok and digest(hot_next.candidate_state.raw_core())==digest(cold_next.candidate_state.raw_core()) and digest(hot_next.receipt)==digest(cold_next.receipt),"Cold and uninterrupted source scans continue identical state and receipts")
	check(not cold.commit(hot_next),"Equivalent cold data does not transfer live transaction ownership")
	check(owner.restore(initial) and owner.generation()==0 and not owner.commit(hot_next),"Restoring the initial checkpoint also invalidates prepared revisions")
	var before_reset:=owner.prepare();check(configure(owner,context) and not owner.commit(before_reset),"Reconfiguration invalidates prepared state at the same generation")
	for field:String in ["body_hex","root_hex","flags_hex"]:
		forged=committed.duplicate(true);forged.core[field]=change_hex(forged.core[field],0)
		check(not owner.restore(sign_snapshot(forged)),"Recomputed checksum cannot hide forged raw output: "+field)
	check(var_to_bytes(context)==frozen,"Every ownership, replay and reject check preserves supplied records")
func observed_cold()->void:
	var context:=base();context.objects[9][0x14c]=128;context.objects[9].encode_s64(0x138,100000)
	var owner:=State.new();check(configure(owner,context),"Observed-owner test configures an actual hierarchy candidate")
	var before:=digest(owner.snapshot());var pending:=owner.prepare()
	check(not pending.ok and pending.get("pending") is Dictionary and pending.pending.kind=="F576" and digest(owner.snapshot())==before,"Missing geometry does not commit or mutate the live collision state")
	if not pending.get("pending") is Dictionary:return
	var row:Dictionary={"kind":pending.pending.kind,"args":pending.pending.args.duplicate(),"before":pending.pending.before.duplicate(true),"after":pending.pending.before.duplicate(true),"return_u32":1}
	var packets:Array=[{"call_index_u32":0,"observations":[row]}]
	var prepared:=owner.prepare(packets)
	check(prepared.ok and owner.commit(prepared),"A matched general-geometry result is committed inside the real scan")
	var snapshot:=owner.snapshot();var cold:=State.new()
	check(cold.restore(JSON.parse_string(JSON.stringify(snapshot))) and digest(cold.raw_core())==digest(owner.raw_core()),"Observed packed bytes survive JSON cold-save replay")
	var forged:=snapshot.duplicate(true);forged.last_witness.payload.classifier_observations[0].observations[0].before.body=change_hex(forged.last_witness.payload.classifier_observations[0].observations[0].before.body,0)
	check(not cold.restore(sign_snapshot(forged)),"Forged observed before-body fails replay after recomputing the outer save hash")
func malformed()->void:
	var context:=base();var owner:=State.new();check(configure(owner,context),"Malformed owner checks begin from valid explicit state")
	var before:=digest(owner.snapshot())
	for value:Variant in [null,true,0,"save",[],{}]:
		check(not owner.restore(value) and digest(owner.snapshot())==before,"Malformed cold-save container rejects without mutation")
		check(not owner.commit(value) and digest(owner.snapshot())==before,"Malformed commit container rejects without mutation")
	for value:Variant in [null,true,0,"raw",[],{},PackedByteArray()]:check(not owner.configure(value,context.objects,context.flags,context.root,context.globals,context.ticks,context.source_frame),"Malformed configure subject rejects")
	for value:Variant in [null,true,0,"raw",[],{},PackedByteArray()]:check(not owner.configure(context.body,context.objects,context.flags,value,context.globals,context.ticks,context.source_frame),"Malformed configure Root rejects")
	for value:Variant in [null,true,0,"trace",{},[{}]]:check(not owner.prepare(value).ok,"Malformed observed scan command rejects")
	for value:Variant in [null,0,1,"true",[],{}]:check(not owner.prepare([],value).ok,"Scan enable policy cannot be coerced")
	for key:String in ["schema","version","profile","generation","core","last_witness","snapshot_sha256"]:
		var bad:=owner.snapshot();bad.erase(key)
		check(not owner.restore(bad),"Incomplete cold-save rejects: "+key)
	check(digest(owner.snapshot())==before,"All malformed inputs preserve the active collision owner")
func native_bank()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"State replay uses the pinned independent native composed scan corpus")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for row:Dictionary in fixture.cases:
		var objects:Dictionary={}
		for key:String in row.objects_by_index:objects[int(key)]=str(row.objects_by_index[key]).hex_decode()
		var owner:=State.new();check(owner.configure(str(row.player_hex).hex_decode(),objects,str(row.flags_hex).hex_decode(),str(row.root_before_hex).hex_decode(),row.globals,row.frame_ticks_u32,row.source_frame_byte),"Actual native sparse bank configures: "+row.name)
		var prepared:=owner.prepare(row.classifier_observations,row.enabled);native_cases+=1
		check(prepared.ok and owner.commit(prepared),"Actual native composed scan commits through typed ownership: "+row.name)
		if not prepared.ok:continue
		check(prepared.receipt.contact_boundary_available==not prepared.contact_boundary.is_empty(),"Receipt explicitly marks whether the sparse bank can supply an authoritative collider record: "+row.name)
		var core:=owner.raw_core();var expected:Dictionary=row.expected
		check(core.body_hex==expected.player_hex and digest(core.objects_hex)==digest(expected.objects_by_index) and core.flags_hex==expected.flags_hex and core.root_hex==expected.root_after_hex and digest(core.globals)==digest(expected.globals),"Every owned raw record, cache, global and Root byte matches native composition: "+row.name)
		var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))) and digest(cold.raw_core())==digest(core),"Native matched scan cold-restores all raw bytes through independent replay: "+row.name)
func run()->void:
	ownership();observed_cold();malformed();native_bank()
	var sources:Dictionary={}
	for path:String in ["scripts/source_contact_scan_state.gd","scripts/source_contact_scan.gd","scripts/source_frame_dispatch.gd","scripts/source_contact_classifier.gd","scripts/source_pair_response.gd","tests/test_source_contact_scan_state.gd",FIXTURE.trim_prefix("res://")]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var output:=FileAccess.open(REPORT,FileAccess.WRITE)
	if output:output.store_string(JSON.stringify({"schema":1,"profile":State.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"sources":sources,"full_collision_program_VM":false,"Main_integrated":false,"physical_device_tested":false},"\t"));output.close()
	print("SOURCE CONTACT SCAN STATE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
