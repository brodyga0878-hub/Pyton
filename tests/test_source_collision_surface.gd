extends SceneTree
const Surface=preload("res://scripts/source_collision_terrain.gd")
const TerrainState=preload("res://scripts/source_terrain_state.gd")
const Program=preload("res://scripts/source_collision_program.gd")
const Geometry=preload("res://scripts/source_collision_geometry.gd")
const Contact=preload("res://scripts/source_collision_contact.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const State=preload("res://scripts/source_contact_scan_state.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_collision_surface_native.json"
const FIXTURE_SHA:="4b206eaaa29d5aed6ba41f43ca7ad0608b8c771385dd02f8e9be6a701cd8d9f2"
const REPORT:="res://build/current-test-reports/source-collision-surface.json"
var checks:=0
var failures:=0
var native_cases:=0
var native_surface_calls:=0
var query_cases:=0
var flat_cases:=0
var dependencies:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<25:push_error(message)
func digest(value:Dictionary)->String:return Clock._hash(value)
func g12(value:Dictionary)->Dictionary:
 var result:Dictionary={}
 for key:String in Frame.GLOBAL_KEYS:result[key]=int(value.get(key,0))
 return result
func g13(value:Dictionary={})->Dictionary:
 var result:=g12(value);result["player_index_u32"]=114;return result
func auxiliary()->Dictionary:return {"recorded_intersection_raw_s32":-123456789,"pending_query_flag_u32":0xa5b6c7d8}
func terrain(graphics:int=1)->Dictionary:
 var result:=auxiliary();result["graphics_level_u32"]=graphics;return result
func originals()->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_natural_contact_native.json"))
func seed_query(ship:int=24)->Dictionary:
 for row:Dictionary in originals().cases:
  if int(row.player_model)==ship and int(row.expected.terrain_query_calls)>0:return row
 return {}
func decode_observations(value:Array)->Array:
 var result:Array=value.duplicate(true)
 for row:Dictionary in result:
  for side:String in ["before","after"]:
   for key:String in ["body","collider","relative"]:
    if row[side][key] is String:row[side][key]=str(row[side][key]).hex_decode()
 return result
func unpack_seed(seed:Dictionary)->Dictionary:
 var body:=str(seed.player_object_hex).hex_decode();var collider:=str(seed.parent_object_hex).hex_decode();body[0x86]=114;body[0x56]=37;collider[0x86]=37;collider[0x56]=0;collider[0x57]=0
 return {"body":body,"collider":collider,"relative":str(seed.relative_before_hex).hex_decode(),"globals":g13(seed.context.initial_globals)}
func bank(seed:Dictionary,graphics:int=1)->Dictionary:
 var raw:=unpack_seed(seed);var body:PackedByteArray=raw.body.duplicate()
 for axis in range(3):body.encode_s64(0x3e+axis*8,raw.relative.decode_s64(axis*8))
 var flags:=PackedByteArray();flags.resize(115);flags[114]=4;flags[37]=4
 var root:=PackedByteArray();root.resize(0x4000);root.fill(0x5a);root.encode_u32(0x10,graphics);root.encode_u32(0xc0,114);root.encode_u32(0xc8,114);root.encode_u32(0xcc,83)
 return {"body":body,"objects":{37:raw.collider.duplicate()},"flags":flags,"root":root,"globals":g12(raw.globals),"ticks":17,"source_frame":31}
func configure(owner:RefCounted,input:Dictionary,aux:Variant=null)->bool:return owner.configure(input.body,input.objects,input.flags,input.root,input.globals,input.ticks,input.source_frame,aux)
func sign_snapshot(value:Dictionary)->Dictionary:
 var result:=value.duplicate(true);result.erase("snapshot_sha256");result["snapshot_sha256"]=digest(result);return result
func surface_calls(result:Dictionary)->Array:
 var calls:Array=[]
 for geometry:Dictionary in result.get("geometry_calls",[]):
  for step:Dictionary in geometry.calls:calls.append_array(step.get("terrain_calls",[]))
 return calls
func complete_contact(raw:Dictionary,t:Dictionary)->Dictionary:
 var observed:Array=[]
 for attempt in range(9):
  var result:=Contact.execute(raw.body,raw.collider,raw.relative,raw.globals,observed,[],t)
  if result.ok:return {"ok":true,"result":result,"observations":observed}
  if not result.get("pending") is Dictionary:return result
  var pending:Dictionary=result.pending
  if pending.kind!="F953":return result
  observed.append({"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0})
 return {"ok":false,"reason":"test_damage_boundary_limit"}
func state_prepare(owner:RefCounted)->Dictionary:
 var packets:Array=[]
 for attempt in range(9):
  var result:Dictionary=owner.prepare(packets,true,true,true)
  if result.ok:return {"ok":true,"prepared":result,"packets":packets}
  if not result.get("pending") is Dictionary or result.pending.kind!="F953":return result
  var pending:Dictionary=result.pending
  if packets.is_empty():packets.append({"call_index_u32":int(result.classifier_call_index_u32),"observations":[]})
  packets[0].observations.append({"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0})
 return {"ok":false,"reason":"test_damage_boundary_limit"}
func state_ownership()->void:
 var seed:=seed_query();check(not seed.is_empty(),"Prior native query witness supplies a real original model and pose")
 if seed.is_empty():return
 var input:=bank(seed);var aux:=auxiliary();var frozen:=var_to_bytes([input,aux]);var owner:=State.new()
 check(configure(owner,input,aux),"Raw collision owner explicitly admits only two terrain auxiliary words")
 var initial:=owner.snapshot();var before:=digest(initial)
 check(owner.raw_core().has("terrain_aux") and owner.raw_core().terrain_aux.size()==2 and not owner.raw_core().terrain_aux.has("graphics_level_u32"),"Graphics is owned by Root10 rather than a duplicate saved global")
 check(TerrainState.from_root(input.root,aux).graphics_level_u32==1,"Graphics is derived from its actual raw Root alias")
 var prepared:=state_prepare(owner)
 check(prepared.ok,"Owned scan reaches the actual original F581 query: "+str(prepared.get("reason")))
 if not prepared.ok:return
 check(digest(owner.snapshot())==before and var_to_bytes([input,aux])==frozen,"Preparing actual terrain never mutates live or supplied state")
 var token:Dictionary=prepared.prepared
 check(token.receipt.actual_terrain_route and token.receipt.actual_geometry_route and token.receipt.terrain_aux_after.size()==2,"Receipt identifies the actual route and the separately owned query words")
 var bad:Dictionary=token.duplicate(true);bad.receipt.terrain_aux_after.pending_query_flag_u32=int(bad.receipt.terrain_aux_after.pending_query_flag_u32)^1
 check(not owner.commit(bad) and digest(owner.snapshot())==before,"Forging a query-state receipt cannot commit")
 check(owner.commit(token),"Native terrain and raw bank publish atomically")
 var saved:=owner.snapshot();var cold:=State.new()
 check(cold.restore(JSON.parse_string(JSON.stringify(saved))) and digest(cold.raw_core())==digest(owner.raw_core()),"Terrain auxiliary words cold-restore through exact complete source replay")
 var hot_next:=state_prepare(owner);var cold_next:=state_prepare(cold)
 check(hot_next.ok and cold_next.ok and digest(hot_next.prepared.candidate_state.raw_core())==digest(cold_next.prepared.candidate_state.raw_core()) and digest(hot_next.prepared.receipt)==digest(cold_next.prepared.receipt),"Hot and cold source terrain scans continue identical state and receipts")
 if hot_next.ok:check(not cold.commit(hot_next.prepared),"Equivalent query state does not transfer live owner authority")
 var changed:=saved.duplicate(true);changed.core.terrain_aux.recorded_intersection_raw_s32=int(changed.core.terrain_aux.recorded_intersection_raw_s32)^1
 check(not cold.restore(sign_snapshot(changed)),"Rehashed query output that disagrees with source replay rejects")
 changed=saved.duplicate(true);changed.core.terrain_aux["graphics_level_u32"]=9
 check(not cold.restore(sign_snapshot(changed)),"A second saved owner for graphics cannot be introduced")
 changed=saved.duplicate(true);changed.last_witness.payload.use_terrain=false
 check(not cold.restore(sign_snapshot(changed)),"A terrain witness cannot be relabeled as the old observed route")
 check(owner.raw_core().root_hex==input.root.hex_encode(),"Actual query leaves all raw Root bytes unchanged")
 for invalid:Variant in [true,0,"aux",[],{},terrain(),{"recorded_intersection_raw_s32":0,"pending_query_flag_u32":-1},{"recorded_intersection_raw_s32":0x80000000,"pending_query_flag_u32":0}]:
  check(not configure(owner,input,invalid),"Malformed or duplicate query-state owners reject")
 for invalid:Variant in [null,0,1,"true",[],{}]:check(not owner.prepare([],true,true,invalid).ok,"Actual terrain mode requires a boolean policy")
 check(not owner.prepare([],true,false,true).ok,"Actual terrain cannot be enabled while the geometry route is disabled")
 var missing:=State.new();check(configure(missing,input) and not missing.prepare([],true,true,true).ok,"A legacy owner cannot invent missing query-state words")
 var mismatched:=terrain(2)
 check(not Scan.dispatch(input.body,input.objects,input.flags,input.root,input.globals,input.ticks,input.source_frame,[],true,true,mismatched).ok,"Scanner rejects terrain state whose graphics word disagrees with Root10")
 var nonsupported:=bank(seed,0xffffffff);var unsafe:=State.new();check(configure(unsafe,nonsupported,aux),"Raw high graphics word remains representable before an actual query")
 var unsafe_before:=digest(unsafe.snapshot());check(not unsafe.prepare([],true,true,true).ok and digest(unsafe.snapshot())==unsafe_before,"Unsupported actual query graphics fails atomically without a fake floor")
 check(var_to_bytes([input,aux])==frozen,"Ownership, replay and all rejects preserve source inputs")
func flat_nested_and_failure()->void:
 var seed:=seed_query();var raw:=unpack_seed(seed);var models:=Geometry.catalog();var state:=g12(raw.globals);var t:=terrain();var frozen:=var_to_bytes([raw,state,t])
 var prepared:=Geometry.prepare_f579(raw.body,raw.collider,raw.relative,raw.body.decode_s32(0x140),models)
 check(prepared.ok,"Real original model prepares its exact F581 local context")
 if not prepared.ok:return
 var pending:=Program.execute(raw.collider,prepared.program,prepared.geometry_context,prepared.threshold_s32,state)
 check(not pending.ok and pending.get("pending") is Dictionary and pending.pending.kind=="F581","Observed default route is preserved as a separate explicit seam")
 if pending.get("pending") is Dictionary:
  var request:Dictionary=pending.pending;var end:=Program.skip_terrain_features(request.before.program,int(request.args[0])+6)
  var supplied:Array=[{"kind":request.kind,"args":request.args.duplicate(),"depth_u32":request.depth_u32,"before":request.before.duplicate(true),"after":request.before.duplicate(true),"return_s32":-1,"next_offset_u32":end.next_offset_u32}]
  check(not Program.execute(raw.collider,prepared.program,prepared.geometry_context,prepared.threshold_s32,state,supplied,models,0,t).ok,"Observed F581 answers cannot override the actual terrain route")
  check(not Geometry.execute(raw.body,raw.collider,raw.relative,state,[{"iteration_u32":0,"observations":supplied}],models,t).ok,"Geometry rejects externally supplied terrain answers in actual mode")
  check(not Contact.execute(raw.body,raw.collider,raw.relative,raw.globals,[],[{"iteration_u32":0,"observations":supplied}],t).ok,"Contact cannot substitute externally supplied terrain results")
 var invalid_program:PackedByteArray=prepared.program.duplicate();invalid_program.encode_u16(7,14)
 check(not Program.execute(raw.collider,invalid_program,prepared.geometry_context,prepared.threshold_s32,state,[],models,0,t).ok,"Unsupported terrain style rejects instead of becoming a harmless empty hit")
 var context:Dictionary=prepared.geometry_context.duplicate(true);context.point_xyz_s32=[0,0,0];context.vertices=PackedByteArray([0,0,0,0,0,0]);context["vertex_origin_u32"]=0
 var nested:=PackedByteArray([0x80,0,0,117,0,0,0x80,128,0,117,0,0,0])
 var chain:=Program.execute(raw.collider,nested,context,0,state,[],models,0,t)
 check(chain.ok and chain.F581_body_executed and chain.terrain_calls.size()==2,"Actual F581 runs through two recursive nested-model volumes")
 if chain.ok:
  var query_count:=0
  for call:Dictionary in chain.terrain_calls:query_count+=int(call.query_count_u32)
  check(query_count==0 and digest(chain.terrain_state_after)==digest(t),"Flat nested exits retain both prior query words without reset or fabricated query")
  flat_cases+=2
 var high:=terrain(0xffffffff);var flat:=Program.execute(raw.collider,nested,context,0,state,[],models,0,high)
 check(flat.ok and digest(flat.terrain_state_after)==digest(high),"Flat F581 paths preserve an arbitrary uint32 graphics word without reading graphics tables")
 var invalid:=t.duplicate(true);invalid.recorded_intersection_raw_s32=0x80000000
 check(not Program.execute(raw.collider,prepared.program,prepared.geometry_context,prepared.threshold_s32,state,[],models,0,invalid).ok,"Malformed signed terrain auxiliary data rejects")
 check(var_to_bytes([raw,state,t])==frozen,"Nested, flat and invalid queries leave all caller records and states unchanged")
 # A type15 ship has a real child volume; query-state must cross that loop.
 var child_raw:=unpack_seed(seed_query(15));var child:=Geometry.execute(child_raw.body,child_raw.collider,child_raw.relative,g12(child_raw.globals),[],{},t)
 check(child.ok and child.calls.size()>1,"Original model15 footprint enters a second F576 child with actual terrain")
 if child.ok:
  var calls:Array=[]
  for entry:Dictionary in child.calls:calls.append_array(entry.get("terrain_calls",[]))
  check(calls.size()>=2 and digest(child.terrain_state_after)==digest(calls[-1].terrain_state_after),"The last real child query owns the persisted auxiliary words")
func legacy_defaults()->void:
 var corpus:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_contact_scan_native.json"))
 var row:Dictionary=corpus.cases[0];var objects:Dictionary={}
 for key:String in row.objects_by_index:objects[int(key)]=str(row.objects_by_index[key]).hex_decode()
 var owner:=State.new();check(owner.configure(str(row.player_hex).hex_decode(),objects,str(row.flags_hex).hex_decode(),str(row.root_before_hex).hex_decode(),row.globals,row.frame_ticks_u32,row.source_frame_byte),"Old source owner still configures without terrain auxiliary fields")
 var prepared:=owner.prepare(row.classifier_observations,row.enabled)
 check(prepared.ok and owner.commit(prepared),"Unchanged observed/default native scan route remains available")
 if not prepared.ok:return
 var snapshot:=owner.snapshot();check(not snapshot.core.has("terrain_aux") and not snapshot.last_witness.payload.has("use_terrain"),"Legacy v1 snapshot shape has no new implicit query owner or mode")
 var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(snapshot))) and digest(cold.raw_core())==digest(owner.raw_core()),"Legacy v1 snapshots still restore by their original route")
 var with_aux:=State.new();var aux:=auxiliary()
 check(with_aux.configure(str(row.player_hex).hex_decode(),objects,str(row.flags_hex).hex_decode(),str(row.root_before_hex).hex_decode(),row.globals,row.frame_ticks_u32,row.source_frame_byte,aux),"Auxiliary ownership may coexist with an explicit legacy route")
 var old_route:=with_aux.prepare(row.classifier_observations,row.enabled)
 check(old_route.ok and with_aux.commit(old_route) and digest(with_aux.raw_core().terrain_aux)==digest(aux) and not old_route.receipt.has("actual_terrain_route"),"Observed/default route leaves existing query auxiliaries untouched and makes no actual-query claim")
func malformed_actual_state()->void:
 var raw:=unpack_seed(seed_query());var t:=terrain();var frozen:=var_to_bytes([raw,t])
 for bad:Variant in [true,0,"terrain",[],{}, {"graphics_level_u32":1}]:check(not Contact.execute(raw.body,raw.collider,raw.relative,raw.globals,[],[],bad).ok,"Malformed actual terrain state rejects before contact processing")
 for key:String in TerrainState.STATE_KEYS:
  var bad:=t.duplicate(true);bad.erase(key);check(not Contact.execute(raw.body,raw.collider,raw.relative,raw.globals,[],[],bad).ok,"Missing owned terrain word rejects: "+key)
 var unknown:=t.duplicate(true);unknown["extra"]=0
 check(not Contact.execute(raw.body,raw.collider,raw.relative,raw.globals,[],[],unknown).ok,"An unowned extra query field cannot enter actual contact state")
 check(var_to_bytes([raw,t])==frozen,"Every malformed state rejects without touching raw owners")
func native_composition()->void:
 check(FileAccess.file_exists(FIXTURE),"Independent full F575→geometry→actual F581 composition corpus exists")
 if not FileAccess.file_exists(FIXTURE):return
 check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent surface composition fixture pinned")
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
 check(int(fixture.case_count)>=32 and fixture.cases.size()==int(fixture.case_count),"Complete declared native surface cohort is present")
 if fixture.get("proof") is Dictionary and fixture.proof.get("source_dependencies_sha256") is Dictionary:
  dependencies=fixture.proof.source_dependencies_sha256.duplicate(true)
  for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Actual surface native source pinned: "+path)
 for row:Dictionary in fixture.cases:
  var body:=str(row.body_hex).hex_decode();var collider:=str(row.collider_hex).hex_decode();var relative:=str(row.relative_hex).hex_decode();var trace:=decode_observations(row.observations);var frozen:=var_to_bytes([body,collider,relative,row.globals_before,row.terrain_state_before,trace])
  var result:=Contact.execute(body,collider,relative,row.globals_before,trace,[],row.terrain_state_before);native_cases+=1
  check(result.ok,"Actual original terrain resumes inside source F575: "+row.name+" "+str(result.get("reason")))
  if not result.ok:continue
  var expected:Dictionary=row.expected
  check(result.body_after.hex_encode()==expected.body_after_hex and result.collider_after.hex_encode()==expected.collider_after_hex and result.relative_after.hex_encode()==expected.relative_after_hex,"Whole native subject/collider/absolute caller vector agree: "+row.name)
  check(digest(result.globals_after)==digest(expected.globals_after) and int(result.return_u8)==int(expected.return_u8) and result.source_order==expected.source_order,"All collision words, source order and F575 return match the actual native composition: "+row.name)
  check(digest(result.terrain_state_after)==digest(row.terrain_state_after) and int(result.terrain_state_after.graphics_level_u32)==int(row.terrain_state_before.graphics_level_u32),"Every actual terrain auxiliary word persists without duplicating graphics ownership: "+row.name)
  var calls:=surface_calls(result);var expected_calls:Array=[]
  for program:Dictionary in row.program_calls:expected_calls.append_array(program.terrain_calls)
  check(not calls.is_empty() and calls.size()==expected_calls.size(),"Every actual native F581 call is represented in its original child/nested order")
  for index in range(calls.size()):
   var call:Dictionary=calls[index];var expected_call:Dictionary=expected_calls[index].expected
   native_surface_calls+=1
   check(int(call.hit_s32)==int(expected_call.hit_s32) and int(call.next_offset_u32)==int(expected_call.next_offset_u32) and int(call.query_count_u32)==int(expected_call.query_count_u32),"Exact original F581 hit, advanced program pointer and query gate match")
   check(digest(call.globals_after)==digest(expected_call.globals_after) and digest(call.terrain_state_after)==digest(expected_call.terrain_state_after),"Every intermediate terrain call preserves the actual collision globals and persistent query words")
   check(call.body_after.hex_encode()==expected_call.body_after_hex and call.program_after.hex_encode()==expected_call.program_after_hex,"Native source body and complete collision program remain unchanged inside F581")
   if int(call.query_count_u32)>0:
    query_cases+=1
    var actual_args:Dictionary=call.query_args;var native_args:Dictionary=expected_call.query_args
    check(int(actual_args.seed_u32)==int(native_args.seed_u32) and int(actual_args.style_u32)==int(native_args.style_u32) and int(actual_args.query_limit_s32)==int(native_args.query_limit_s32),"Actual F1876 receives source seed, style and raw query limit")
    check(Clock._hash({"matrix":actual_args.query_matrix_s32,"center":actual_args.query_center_s32})==Clock._hash({"matrix":native_args.matrix_s32,"center":native_args.center_s32}),"Exact integer F581 query frame and observer center match original instructions")
   else:flat_cases+=1
  check(var_to_bytes([body,collider,relative,row.globals_before,row.terrain_state_before,trace])==frozen,"Native terrain composition preserves every caller buffer and supplied continuation")
 check(native_surface_calls>=native_cases and query_cases>0,"Declared actual surface cohort contains executed source queries")
func run()->void:
 state_ownership();flat_nested_and_failure();legacy_defaults();malformed_actual_state();native_composition()
 var sources:Dictionary={}
 for path:String in ["scripts/source_collision_terrain.gd","scripts/source_terrain_state.gd","scripts/source_collision_program.gd","scripts/source_collision_geometry.gd","scripts/source_collision_contact.gd","scripts/source_contact_scan.gd","scripts/source_contact_scan_state.gd","tests/test_source_collision_surface.gd",FIXTURE.trim_prefix("res://"),Geometry.DATA_PATH.trim_prefix("res://")]:sources[path]=FileAccess.get_sha256("res://"+path)
 for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify({"profile":"dos-firstenc-actual-terrain-contact-integration-v1","checks":checks,"failures":failures,"native_cases":native_cases,"native_F581_calls":native_surface_calls,"native_query_calls":query_cases,"flat_cases":flat_cases,"sources":sources,"Main_integrated":false},"\t"));file.close()
 print("SOURCE COLLISION SURFACE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
