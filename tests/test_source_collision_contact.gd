extends SceneTree
const Contact=preload("res://scripts/source_collision_contact.gd")
const Classifier=preload("res://scripts/source_contact_classifier.gd")
const Geometry=preload("res://scripts/source_collision_geometry.gd")
const Program=preload("res://scripts/source_collision_program.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const State=preload("res://scripts/source_contact_scan_state.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_collision_contact_native.json"
const FIXTURE_SHA:="c1f5ea26093f3855d75e78822f3eddf1c13d9046b331a3c3325a5e21895ada3f"
const REPORT:="res://build/current-test-reports/source-collision-contact.json"
var checks:=0
var failures:=0
var native_cases:=0
var native_program_calls:=0
var terrain_cases:=0
var source_dependencies:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<25:push_error(message)
func digest(value:Dictionary)->String:return Clock._hash(value)
func decode_observations(value:Array)->Array:
 var rows:Array=value.duplicate(true)
 for row:Dictionary in rows:
  for side:String in ["before","after"]:
   for key:String in ["body","collider","relative"]:
    if row[side][key] is String:row[side][key]=str(row[side][key]).hex_decode()
 return rows
func globals12(state:Dictionary)->Dictionary:
 var result:Dictionary={}
 for key:String in Frame.GLOBAL_KEYS:result[key]=int(state[key])
 return result
func globals13()->Dictionary:
 var result:Dictionary={}
 for key:String in Classifier.GLOBAL_KEYS:result[key]=0
 result["player_index_u32"]=114
 return result
func raw_bank(body:PackedByteArray,collider:PackedByteArray,globals:Dictionary)->Dictionary:
 var subject:=body.duplicate();var parent:=collider.duplicate();var root:=PackedByteArray();root.resize(0x4000);root.fill(0xa5)
 root.encode_u32(0xc0,114);root.encode_u32(0xc8,114);root.encode_u32(0xcc,83)
 subject[0x86]=114;subject[0x56]=37;subject[0x57]=0;subject[0x58]=0;parent[0x86]=37;parent[0x56]=0;parent[0x57]=0;parent[0x58]=0
 var flags:=PackedByteArray();flags.resize(115);flags[114]=4;flags[37]=4
 return {"body":subject,"objects":{37:parent},"flags":flags,"root":root,"globals":globals12(globals),"ticks":17,"source_frame":31}
func configure(owner:RefCounted,bank:Dictionary)->bool:return owner.configure(bank.body,bank.objects,bank.flags,bank.root,bank.globals,bank.ticks,bank.source_frame)
func scan(bank:Dictionary,packets:Variant=[],route:Variant=true)->Dictionary:return Scan.dispatch(bank.body,bank.objects,bank.flags,bank.root,bank.globals,bank.ticks,bank.source_frame,packets,true,route)
func signature(value:Dictionary)->Dictionary:
 var result:=value.duplicate(true);result.erase("snapshot_sha256");result["snapshot_sha256"]=digest(result);return result
func reply_terrain(pending:Dictionary)->Dictionary:
 var end:=Program.skip_terrain_features(pending.before.program,int(pending.args[0])+6)
 check(end.ok,"Typed terrain continuation follows exact F1822 feature record boundary")
 return {"kind":pending.kind,"args":pending.args.duplicate(),"depth_u32":pending.depth_u32,"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_s32":-1,"next_offset_u32":int(end.next_offset_u32)}
func terrain_cold()->void:
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_natural_contact_native.json"));var seed:Dictionary={}
 for row:Dictionary in fixture.cases:
  if int(row.expected.terrain_query_calls)>0:
   seed=row;break
 check(not seed.is_empty(),"Retained native terrain witness supplies an actual catalog model and input pose")
 if seed.is_empty():return
 var body:=str(seed.player_object_hex).hex_decode();var collider:=str(seed.parent_object_hex).hex_decode();var relative:=str(seed.relative_before_hex).hex_decode();body[0x86]=114;body[0x56]=37;collider[0x86]=37
 var state:=globals13();var frozen:=var_to_bytes([body,collider,relative,state]);var initial:=Contact.execute(body,collider,relative,state)
 check(not initial.ok and initial.get("pending") is Dictionary and initial.pending.kind=="F581" and int(initial.get("geometry_iteration_u32",-1))==0,"Actual catalog terrain query is exposed through F575/F576 with its source child iteration")
 if not initial.get("pending") is Dictionary:return
 var reply:=reply_terrain(initial.pending);var packets:Array=[{"iteration_u32":int(initial.geometry_iteration_u32),"observations":[reply]}]
 var resumed:=Contact.execute(body,collider,relative,state,[],packets)
 var transported:Variant=JSON.parse_string(JSON.stringify(Scan.json_value(packets)))
 var cold:=Contact.execute(body,collider,relative,state,[],transported)
 check(resumed.ok and cold.ok and resumed.F576_body_executed and resumed.geometry_calls.size()==1,"Matched actual terrain continuation resumes the real geometry route")
 if resumed.ok and cold.ok:
  check(resumed.body_after==cold.body_after and resumed.collider_after==cold.collider_after and resumed.relative_after==cold.relative_after and digest(resumed.globals_after)==digest(cold.globals_after) and resumed.return_u8==cold.return_u8,"Terrain continuation survives complete JSON byte and numeric transport")
  terrain_cases+=1
 check(var_to_bytes([body,collider,relative,state])==frozen,"Pending and complete terrain contacts preserve caller-owned raw context")
 var wrong:Array=transported.duplicate(true);wrong[0].iteration_u32=1
 check(not Contact.execute(body,collider,relative,state,[],wrong).ok,"A terrain reply for a different source child iteration cannot continue")
 wrong=transported.duplicate(true);wrong[0].observations[0].before.body="00"
 check(not Contact.execute(body,collider,relative,state,[],wrong).ok,"Truncated or foreign terrain body cannot continue")
 var bank:=raw_bank(body,collider,state)
 for axis in range(3):bank.body.encode_s64(0x3e+axis*8,relative.decode_s64(axis*8))
 var bank_frozen:=var_to_bytes(bank);var missing:=scan(bank)
 check(not missing.ok and missing.get("pending") is Dictionary and missing.pending.kind=="F581" and int(missing.get("geometry_iteration_u32",-1))==0 and int(missing.get("classifier_call_index_u32",-1))==0,"Scan forwards both classifier position and geometry iteration for the actual pending terrain query")
 if not missing.get("pending") is Dictionary:return
 var scan_reply:=reply_terrain(missing.pending)
 var scan_packets:Array=[{"call_index_u32":0,"observations":[],"geometry_observations":[{"iteration_u32":int(missing.geometry_iteration_u32),"observations":[scan_reply]}]}]
 var hot:=scan(bank,scan_packets)
 check(hot.ok and hot.actual_geometry_route and hot.classifier_calls.size()==1,"Actual F569 scan resumes typed terrain at the true classifier position")
 check(var_to_bytes(bank)==bank_frozen,"Terrain scan and packet construction leave raw bank and Root unchanged")
 var owner:=State.new();check(configure(owner,bank),"Raw collision owner configures the same terrain pose")
 var before:=digest(owner.snapshot());var pending:=owner.prepare([],true,true)
 check(not pending.ok and pending.get("pending") is Dictionary and int(pending.get("geometry_iteration_u32",-1))==0 and digest(owner.snapshot())==before,"Missing actual terrain result cannot publish or mutate an owned scan")
 var prepared:=owner.prepare(scan_packets,true,true)
 check(prepared.ok and prepared.receipt.get("actual_geometry_route",false) and digest(owner.snapshot())==before,"Actual geometry prepares privately and marks the selected route")
 if not prepared.ok:return
 check(owner.commit(prepared),"Matched actual terrain geometry commits through the raw owner")
 var snapshot:=owner.snapshot();var new_owner:=State.new()
 check(new_owner.restore(JSON.parse_string(JSON.stringify(snapshot))) and digest(new_owner.raw_core())==digest(owner.raw_core()),"Actual terrain program packets cold-restore through complete source replay")
 var forged:=snapshot.duplicate(true);forged.last_witness.payload.classifier_observations[0].geometry_observations[0].observations[0].before.body="00"
 check(not new_owner.restore(signature(forged)),"Rehashed cold save cannot replace the original terrain before-context")
 for bad:Variant in [null,0,1,"true",[],{}]:
  check(not scan(bank,[],bad).ok,"Source scanner requires an explicit boolean geometry policy")
  check(not owner.prepare([],true,bad).ok,"Owned scanner cannot coerce geometry policy")
 var bad_packet:Array=[{"call_index_u32":0,"observations":[],"geometry_observations":[]}]
 check(not scan(bank,bad_packet,false).ok,"Legacy mode cannot silently consume actual-geometry packets")
 check(var_to_bytes(bank)==bank_frozen,"All rejected terrain and policy operations preserve source bank")
func terrain_child_iteration()->void:
 var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_natural_contact_native.json"));var seed:Dictionary={}
 for row:Dictionary in original.cases:
  if int(row.player_model)==15 and int(row.expected.terrain_query_calls)>=2:
   seed=row;break
 check(not seed.is_empty(),"Independent native witness retains a ship child volume needing a second terrain query")
 if seed.is_empty():return
 var body:=str(seed.player_object_hex).hex_decode();var other:=str(seed.parent_object_hex).hex_decode();var relative:=str(seed.relative_before_hex).hex_decode();var bank:=raw_bank(body,other,globals13())
 for axis in range(3):bank.body.encode_s64(0x3e+axis*8,relative.decode_s64(axis*8))
 var owner:=State.new();check(configure(owner,bank),"Owned child-volume witness configures original model15 geometry")
 var frozen:=digest(owner.snapshot());var packets:Array=[];var nonzero:=false;var complete:=false
 for attempt in range(5):
  var result:=owner.prepare(packets,true,true)
  if result.ok:
   check(owner.commit(result),"All exact per-child terrain responses publish together")
   var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))) and digest(cold.raw_core())==digest(owner.raw_core()),"Nonzero terrain child iterations cold-restore with identical actual geometry")
   complete=true;break
  check(result.get("pending") is Dictionary and result.pending.kind=="F581" and result.has("geometry_iteration_u32") and int(result.get("classifier_call_index_u32",-1))==0,"Each unresolved child query preserves both nested iteration and bank callback index")
  if not result.get("pending") is Dictionary:return
  var iteration:=int(result.geometry_iteration_u32)
  if iteration>0:nonzero=true
  check(digest(owner.snapshot())==frozen,"Partial source child traversal never mutates the live bank")
  if packets.is_empty():packets.append({"call_index_u32":0,"observations":[],"geometry_observations":[]})
  var row:Dictionary={"iteration_u32":iteration,"observations":[reply_terrain(result.pending)]}
  packets[0].geometry_observations.append(row)
 check(nonzero and complete,"Actual catalog child iteration1 is forwarded through Contact, Scan and owned cold replay")
func compatibility_and_rejects(row:Dictionary)->void:
 var body:=str(row.body_hex).hex_decode();var collider:=str(row.collider_hex).hex_decode();var relative:=str(row.relative_hex).hex_decode();var globals:Dictionary=row.globals_before.duplicate(true);var frozen:=var_to_bytes([body,collider,relative,globals])
 for bad:Variant in [null,true,0,"raw",[],{},PackedByteArray()]:
  check(not Contact.execute(bad,collider,relative,globals).ok,"Malformed contact body rejects")
  check(not Contact.execute(body,bad,relative,globals).ok,"Malformed collider rejects")
  check(not Contact.execute(body,collider,bad,globals).ok,"Malformed signed source vector rejects")
 for bad:Variant in [null,true,0,"globals",[],{}]:check(not Contact.execute(body,collider,relative,bad).ok,"Malformed complete classifier globals reject")
 for bad:Variant in [null,true,0,"trace",{}]:
  check(not Contact.execute(body,collider,relative,globals,bad).ok,"Malformed F953 observation stream rejects")
  check(not Contact.execute(body,collider,relative,globals,[],bad).ok,"Malformed actual geometry observation stream rejects")
 var prefix:=Classifier.execute(body,collider,relative,globals)
 check(not prefix.ok and prefix.get("pending") is Dictionary and prefix.pending.kind=="F576","Complex native witness really enters the hierarchical geometry branch")
 if prefix.get("pending") is Dictionary:
  var fake:Dictionary={"kind":"F576","args":prefix.pending.args.duplicate(),"before":prefix.pending.before.duplicate(true),"after":prefix.pending.before.duplicate(true),"return_u32":1}
  check(not Contact.execute(body,collider,relative,globals,[fake]).ok,"An observed F576 substitution cannot replace actual collision program geometry")
 check(not Contact.execute(body,collider,relative,globals,[],[{"iteration_u32":64,"observations":[]}]).ok,"Unconsumed geometry iteration packets reject")
 var distant:=relative.duplicate();distant.encode_s64(0,0x1000000000000000);distant.encode_s64(8,0);distant.encode_s64(16,0)
 var original:=Classifier.execute(body,collider,distant,globals);var actual:=Contact.execute(body,collider,distant,globals)
 check(original.ok and actual.ok and original.body_after==actual.body_after and original.relative_after==actual.relative_after and digest(original.globals_after)==digest(actual.globals_after) and not actual.F576_body_executed and actual.geometry_calls.is_empty(),"Coarse rejection preserves original behavior without invoking model geometry")
 check(not Contact.execute(body,collider,distant,globals,[],[{"iteration_u32":0,"observations":[]}]).ok,"Coarse exit rejects unused geometry results instead of claiming their execution")
 check(var_to_bytes([body,collider,relative,globals])==frozen,"Every malformed or substituted contact preserves raw caller context")
 # Existing v1 default witnesses omit use_geometry and keep their old route.
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_contact_scan_native.json"))
 for i in range(4):
  var sample:Dictionary=old.cases[i];var objects:Dictionary={}
  for key:String in sample.objects_by_index:objects[int(key)]=str(sample.objects_by_index[key]).hex_decode()
  var owner:=State.new();check(owner.configure(str(sample.player_hex).hex_decode(),objects,str(sample.flags_hex).hex_decode(),str(sample.root_before_hex).hex_decode(),sample.globals,sample.frame_ticks_u32,sample.source_frame_byte),"Legacy v1 native bank configures")
  var prepared:=owner.prepare(sample.classifier_observations,sample.enabled)
  check(prepared.ok and owner.commit(prepared),"Legacy default route retains actual native scan result")
  if not prepared.ok:continue
  var snapshot:=owner.snapshot();check(not snapshot.last_witness.payload.has("use_geometry"),"Old v1 payload shape remains byte-compatible with the prior owner")
  var restored:=State.new();check(restored.restore(JSON.parse_string(JSON.stringify(snapshot))) and digest(restored.raw_core())==digest(owner.raw_core()),"Old v1 witness continues restoring with the unchanged default route")
func native()->void:
 check(FileAccess.file_exists(FIXTURE),"Actual original F575→F576→collision VM composition fixture is present")
 if not FileAccess.file_exists(FIXTURE):return
 check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent whole geometry/contact native fixture is pinned")
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
 check(int(fixture.case_count)==32 and fixture.cases.size()==32 and fixture.proof.fresh_process_runs_each_call==3 and fixture.proof.all_raw_canaries_verified and not fixture.proof.expected_arithmetic_calculated_in_python and not fixture.proof.F581_terrain_answers_invented,"Independent composed native proof retains exact kernels and guarded process repeats")
 source_dependencies=fixture.proof.source_dependencies_sha256.duplicate(true)
 for path:String in source_dependencies:check(FileAccess.get_sha256("res://"+path)==source_dependencies[path],"Composed native source dependency pinned: "+path)
 var hit:=0;var nohit:=0;var damage:=0
 for row:Dictionary in fixture.cases:
  var body:=str(row.body_hex).hex_decode();var collider:=str(row.collider_hex).hex_decode();var relative:=str(row.relative_hex).hex_decode();var observations:=decode_observations(row.observations)
  var frozen:=var_to_bytes([body,collider,relative,row.globals_before,observations,row.geometry_observations]);var result:=Contact.execute(body,collider,relative,row.globals_before,observations,row.geometry_observations)
  native_cases+=1
  check(result.ok,"Actual collision programs resume inside the original F575 response: "+row.name+" "+str(result.get("reason")))
  if not result.ok:continue
  var expected:Dictionary=row.expected
  check(result.body_after.hex_encode()==expected.body_after_hex and result.collider_after.hex_encode()==expected.collider_after_hex and result.relative_after.hex_encode()==expected.relative_after_hex,"Whole original raw body/collider/caller absolute vector match: "+row.name)
  check(digest(result.globals_after)==digest(expected.globals_after) and result.return_u8==int(expected.return_u8),"All13 raw globals and F575 returned flags match actual native composition: "+row.name)
  check(result.source_order==expected.source_order,"Whole source F575/math/F578/F953 order matches: "+row.name)
  check(result.F576_body_executed and result.geometry_calls.size()==1,"Real F576 replaces the formerly observed geometry seam")
  var geometry:Dictionary=result.geometry_calls[0]
  check(int(geometry.return_s32)==int(row.geometry_expected.return_s32) and digest(geometry.globals_after)==digest(row.geometry_expected.globals_after) and geometry.calls.size()==row.geometry_expected.calls.size(),"Actual F576 child traversal agrees with its independent native whole-procedure result")
  for i in range(geometry.calls.size()):
   check(geometry.calls[i].relative_after.hex_encode()==row.geometry_expected.calls[i].relative_after_hex and int(geometry.calls[i].return_s32)==int(row.geometry_expected.calls[i].return_s32),"Native per-child transformed vector and actual collision-program return agree")
  native_program_calls+=row.program_calls.size()
  if int(row.geometry_expected.return_s32)==0:hit+=1
  else:nohit+=1
  damage+=observations.size()
  check(not result.full_collision_program_VM and not result.get("Main_integrated",false),"Terrain/damage and live Main scope remains explicit")
  check(var_to_bytes([body,collider,relative,row.globals_before,observations,row.geometry_observations])==frozen,"Composed native contact leaves every supplied raw record and continuation unchanged")
 check(hit>0 and nohit>0 and damage>0,"Native geometry contains both contact/no-contact and strict damage continuations")
 check(native_program_calls==int(fixture.actual_F582_calls),"Every native F582 call in the composed corpus is represented")
 compatibility_and_rejects(fixture.cases[0])
func run()->void:
 native();terrain_cold();terrain_child_iteration()
 var sources:Dictionary={}
 for path:String in ["scripts/source_collision_contact.gd","scripts/source_collision_geometry.gd","scripts/source_collision_program.gd","scripts/source_contact_classifier.gd","scripts/source_contact_scan.gd","scripts/source_contact_scan_state.gd","tests/test_source_collision_contact.gd",FIXTURE.trim_prefix("res://"),Geometry.DATA_PATH.trim_prefix("res://")]:sources[path]=FileAccess.get_sha256("res://"+path)
 for path:String in source_dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify({"profile":Contact.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"native_program_calls":native_program_calls,"terrain_cold_continuations":terrain_cases,"sources":sources,"Main_integrated":false,"full_collision_program_VM":false},"\t"));file.close()
 print("SOURCE COLLISION CONTACT TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
