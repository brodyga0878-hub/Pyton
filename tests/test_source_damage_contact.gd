extends SceneTree
const Contact=preload("res://scripts/source_damage_contact.gd")
const Damage=preload("res://scripts/source_damage.gd")
const Rng=preload("res://scripts/source_global_rng.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const State=preload("res://scripts/source_contact_scan_state.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Classifier=preload("res://scripts/source_contact_classifier.gd")
const TerrainState=preload("res://scripts/source_terrain_state.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const REPORT:="res://build/current-test-reports/source-damage-contact.json"
const FIXTURE:="res://tests/fixtures/source_damage_contact_native.json"
const FIXTURE_SHA:="61d6f3f1237fa2e02b0e3a79a4596b8fd9786a01d9adae228f793701df23f6bd"
var checks:=0
var failures:=0
var native_cases:=0
var buffer_pool:Dictionary={}
var hydrated:Dictionary={}
var dependencies:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<25:push_error(message)
func digest(value:Dictionary)->String:return Clock._hash(value)
func body(index:int)->PackedByteArray:
 var result:=PackedByteArray();result.resize(338);result[0x86]=index;result[0x87]=3;result.encode_u32(0x82,24);result.encode_u16(0xe4,4000);result.encode_s64(0x138,1<<40);result.encode_s64(0x140,1<<40)
 return result
func bank()->Dictionary:
 var root:=PackedByteArray();root.resize(0x4000);root.fill(0x5a);root.encode_u32(0xc0,17);root.encode_u32(0xc8,17);root.encode_u32(0xcc,0);root.encode_u32(0x10,1);root.encode_u32(0x24,0x12345678);root.encode_u32(0x28,0x87654321)
 var flags:=PackedByteArray();flags.resize(115);flags[17]=4;flags[9]=4;flags[7]=4
 var globals:Dictionary={}
 for key:String in Frame.GLOBAL_KEYS:globals[key]=0
 var events:=PackedByteArray();events.resize(284);events.fill(0xcc)
 var modules:=PackedByteArray();modules.resize(168)
 var descriptor:=PackedByteArray();descriptor.resize(68)
 return {"body":body(17),"objects":{9:body(9),7:body(7)},"flags":flags,"root":root,"globals":globals,"ticks":17,"source_frame":31,"damage_aux":{"event_registers":events,"module_entries":modules,"module_count_s32":0,"model_descriptors":{"24":descriptor}}}
func context(value:Dictionary)->Dictionary:
 var result:Dictionary=value.damage_aux.duplicate(true);result["root"]=value.root.duplicate();result["flags"]=value.flags.duplicate();return result
func invoke(value:Dictionary,packets:Array=[],geometry:bool=false,terrain:Variant=null)->Dictionary:
 return Scan.dispatch(value.body,value.objects,value.flags,value.root,value.globals,value.ticks,value.source_frame,packets,true,geometry,terrain,context(value))
func configure(owner:RefCounted,value:Dictionary,terrain_aux:Variant=null)->bool:
 return owner.configure(value.body,value.objects,value.flags,value.root,value.globals,value.ticks,value.source_frame,terrain_aux,value.damage_aux)
func bank_from_core(core:Dictionary)->Dictionary:
 var objects:Dictionary={}
 for key:String in core.objects_hex:objects[int(key)]=str(core.objects_hex[key]).hex_decode()
 var root:=str(core.root_hex).hex_decode();var flags:=str(core.flags_hex).hex_decode();var aux:=State._damage_context(root,flags,core.damage_aux);aux.erase("root");aux.erase("flags")
 return {"body":str(core.body_hex).hex_decode(),"objects":objects,"root":root,"flags":flags,"damage_aux":aux,"globals":core.globals.duplicate(true),"ticks":int(core.frame_ticks_u32),"source_frame":int(core.source_frame_byte)}
func reply(pending:Dictionary,mode:String,first:bool)->Dictionary:
 var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":1}
 # Explicit test module effects reduce each pair's measured damage to one;
 # this is a controlled observation, not an invented world implementation.
 if row.kind=="F48" and int(row.args[2])==12:row.after.context.event_registers.encode_u32(48,1)
 if first:
  if mode=="clear_later":row.after.context.flags[7]=0
  elif mode=="activate_later":row.after.context.flags[7]=4
  elif mode=="activate_absent":row.after.context.flags[8]=4
  elif mode=="rng":row.after.context.root.encode_u32(0x24,0x89abcdef);row.after.context.root.encode_u32(0x28,0xfedcba98)
  elif mode=="graphics":row.after.context.root.encode_u32(0x10,2)
  elif mode=="identity":row.after.body[0x86]=18
 return row
func complete(value:Dictionary,mode:String="",geometry:bool=false,terrain:Variant=null)->Dictionary:
 var packets:Array=[];var replies:=0
 for attempt in range(160):
  var result:=invoke(value,packets,geometry,terrain)
  if result.ok:return {"ok":true,"result":result,"packets":packets,"callback_count":replies}
  if not result.get("pending") is Dictionary or not result.has("damage_call_index_u32"):return result
  var index:int=int(result.classifier_call_index_u32);var damage_index:int=int(result.damage_call_index_u32)
  if packets.is_empty() or int(packets[-1].call_index_u32)!=index:packets.append({"call_index_u32":index,"observations":[],"damage_observations":[]})
  var rows:Array=packets[-1].damage_observations
  if rows.is_empty() or int(rows[-1].call_index_u32)!=damage_index:rows.append({"call_index_u32":damage_index,"observations":[]})
  rows[-1].observations.append(reply(result.pending,mode,replies==0));replies+=1
 return {"ok":false,"reason":"test_boundary_limit"}
func snapshot_signature(value:Dictionary)->Dictionary:
 var result:=value.duplicate(true);result.erase("snapshot_sha256");result["snapshot_sha256"]=digest(result);return result
func scan_threading()->void:
 var raw:=bank();var before:=var_to_bytes(raw);var first:=invoke(raw)
 check(not first.ok and first.get("pending") is Dictionary and first.pending.kind=="F48" and int(first.classifier_call_index_u32)==0 and int(first.damage_call_index_u32)==0,"Actual F569/F575/F578 enters the first real F953 event callback")
 var done:=complete(raw);check(done.ok,"Explicit test callbacks resume all actual F953 kernels in two descending classifiers: "+str(done.get("reason")))
 if not done.ok:return
 var result:Dictionary=done.result
 check(result.classifier_calls.size()==2 and result.classifier_calls[0].collider_index_u8==9 and result.classifier_calls[1].collider_index_u8==7,"Actual damage retains the original descending raw-bank scan order")
 check(result.actual_damage_route and result.classifier_calls[0].damage_calls.size()==2 and result.classifier_calls[1].damage_calls.size()==2,"Both original pair damage calls execute inside each actual classifier")
 check(result.body.decode_u16(0xe4)==3998 and result.objects_by_index[9].decode_u16(0xe4)==3999 and result.objects_by_index[7].decode_u16(0xe4)==3999,"Real F953 consumes the event12 callback value and publishes each target HP")
 check(result.damage_context_after.root==result.root_after and result.damage_context_after.flags==result.flags,"The resulting damage view shares the scan's sole Root and raw flags values")
 var cold:=invoke(raw,JSON.parse_string(JSON.stringify(Scan.json_value(done.packets))))
 check(cold.ok and cold.body==result.body and cold.objects_by_index==result.objects_by_index and cold.root_after==result.root_after and digest(cold.damage_context_after)==digest(result.damage_context_after),"Nested F953 observations survive JSON byte/numeric transport without a second RNG owner")
 var cleared:=complete(raw,"clear_later")
 check(cleared.ok and cleared.result.classifier_calls.size()==1 and cleared.result.classifier_calls[0].collider_index_u8==9 and cleared.result.flags[7]==0 and cleared.result.objects_by_index[7]==raw.objects[7],"First F953 callback clears later bit4 before traversal reaches that collider")
 var inactive:=bank();inactive.flags[7]=0;var activated:=complete(inactive,"activate_later")
 check(activated.ok and activated.result.classifier_calls.size()==2 and activated.result.classifier_calls[1].collider_index_u8==7 and activated.result.objects_by_index[7].decode_u16(0xe4)==3999,"First F953 callback activates an existing later raw record and traversal visits it")
 var absent:=complete(raw,"activate_absent")
 check(not absent.ok and str(absent.reason).contains("raw_bank"),"Activating a missing record rejects the private scan instead of inventing a slot")
 var changed_rng:=complete(raw,"rng")
 check(changed_rng.ok,"Callback-updated Root RNG can continue through later source damage calls")
 if changed_rng.ok:
  var rolling:PackedByteArray=raw.root.duplicate();rolling.encode_u32(0x24,0x89abcdef);rolling.encode_u32(0x28,0xfedcba98);var calls:=0
  for entry:Dictionary in changed_rng.result.classifier_calls:
   for damage_call:Dictionary in entry.damage_calls:
    var calculation:Dictionary=damage_call.calculation;check(calculation.source_order.has("F1530"),"Each surviving one-point hull hit executes actual F1530")
    for ignored in range(int(calculation.rng_calls_u32)):rolling=Rng.execute(rolling,"F1530").root_after;calls+=1
    var actual_root:=str(calculation.context_after.root).hex_decode()
    check(actual_root.decode_u32(0x24)==rolling.decode_u32(0x24) and actual_root.decode_u32(0x28)==rolling.decode_u32(0x28),"Later F953 uses the callback-updated preceding Root RNG words")
  check(calls==4 and changed_rng.result.root_after.decode_u32(0x24)==rolling.decode_u32(0x24) and changed_rng.result.root_after.decode_u32(0x28)==rolling.decode_u32(0x28),"Four actual damage kernels advance one sequential Root RNG stream")
 var wrong:=complete(raw,"identity")
 check(not wrong.ok and str(wrong.reason).contains("identity"),"A damage callback cannot change target identity without the separate slot lifecycle")
 check(var_to_bytes(raw)==before,"Every live, pending, rejected and JSON scan preserves caller records, Root and callback sources")
func terrain_threading()->void:
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_collision_surface_native.json"));var seed:Dictionary=fixture.cases[0];var raw:=bank()
 raw.body=str(seed.body_hex).hex_decode();raw.body[0x86]=17;raw.body[0x56]=0;raw.body[0x57]=0;raw.body[0x58]=0;raw.body.encode_u16(0xe4,4000);raw.body.encode_u16(0xe0,0)
 for axis in range(3):raw.body.encode_s64(0x3e+axis*8,str(seed.relative_hex).hex_decode().decode_s64(axis*8))
 var natural:=str(seed.collider_hex).hex_decode();natural[0x86]=7;natural[0x56]=0;natural[0x57]=0;natural[0x58]=0
 for axis in range(3):natural.encode_s64(0x3e+axis*8,0)
 raw.objects[7]=natural
 for axis in range(3):raw.objects[9].encode_s64(0x3e+axis*8,raw.body.decode_s64(0x3e+axis*8))
 var terrain:Dictionary=seed.terrain_state_before.duplicate(true);raw.root.encode_u32(0x10,int(terrain.graphics_level_u32));var frozen:=var_to_bytes(raw)
 var done:=complete(raw,"graphics",true,terrain)
 check(done.ok,"A damage callback Root graphics change continues into a later real natural-model geometry query: "+str(done.get("reason")))
 if not done.ok:return
 var result:Dictionary=done.result;var queried:=0
 check(result.classifier_calls.size()==2 and result.classifier_calls[1].collider_index_u8==7,"Real natural geometry executes after the earlier callback at the proper descending scan position")
 for geometry:Dictionary in result.classifier_calls[1].geometry_calls:
  for program:Dictionary in geometry.calls:
   for actual:Dictionary in program.terrain_calls:
    queried+=int(actual.query_count_u32);check(int(actual.terrain_state_after.graphics_level_u32)==2,"Later actual F581/F1876 uses callback-updated Root+10 rather than a duplicated graphics owner")
 check(queried>0 and result.root_after.decode_u32(0x10)==2 and int(result.terrain_state_after.graphics_level_u32)==2,"At least one real source terrain query retains the sequential shared Root graphics value")
 var owner:=State.new();check(configure(owner,raw,TerrainState.auxiliary(terrain)),"Damage plus terrain owner derives graphics from one Root and stores two terrain auxiliary words")
 var prepared:=owner.prepare(done.packets,true,true,true,true)
 check(prepared.ok and prepared.receipt.actual_damage_route and prepared.receipt.actual_terrain_route and owner.commit(prepared),"Actual damage, later terrain and both auxiliary sets commit as one owned scan")
 if prepared.ok:
  var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))) and digest(cold.raw_core())==digest(owner.raw_core()),"Cold replay preserves callback-updated graphics through actual F581 in the later classifier")
  check(owner.raw_core().terrain_aux.size()==2 and not owner.raw_core().terrain_aux.has("graphics_level_u32") and owner.raw_core().damage_aux.size()==4,"Neither optional auxiliary state duplicates Root graphics, RNG or flags")
 check(var_to_bytes(raw)==frozen,"Composed damage-to-terrain execution never mutates original source buffers")
func owned()->void:
 var raw:=bank();var done:=complete(raw,"clear_later");check(done.ok,"Owned controls use the actual callback flag-threading scan")
 if not done.ok:return
 var owner:=State.new();check(configure(owner,raw),"Contact owner configures four damage auxiliary fields beside one Root and flags bank")
 var before:=digest(owner.snapshot());var pending:=owner.prepare([],true,false,false,true)
 check(not pending.ok and pending.get("pending") is Dictionary and int(pending.damage_call_index_u32)==0 and digest(owner.snapshot())==before,"Owned scan forwards actual F953 callback position and remains atomic while pending")
 var prepared:=owner.prepare(done.packets,true,false,false,true)
 check(prepared.ok and prepared.receipt.actual_damage_route and prepared.receipt.damage_engine_executed and digest(owner.snapshot())==before,"Actual nested damage prepares privately and labels execution honestly")
 if not prepared.ok:return
 var peer:=State.new();check(configure(peer,raw) and not peer.commit(prepared),"Equivalent raw contact bank cannot publish another damage owner's transaction")
 var forged:=prepared.duplicate(true);forged.receipt.damage_aux_after.event_registers="00"
 check(not owner.commit(forged) and digest(owner.snapshot())==before,"Forged event-table receipt rejects atomically")
 forged=prepared.duplicate(true);forged.receipt.damage_engine_executed=false
 check(not owner.commit(forged),"Forged actual damage execution receipt rejects")
 var rival:=owner.prepare(done.packets,true,false,false,true)
 check(owner.commit(prepared) and not owner.commit(prepared) and not owner.commit(rival),"Exactly one matching prepared damage scan publishes")
 var core:=owner.raw_core();check(core.damage_aux.size()==4 and not core.damage_aux.has("root") and not core.damage_aux.has("flags") and not core.damage_aux.has("rng"),"Owned contact stores only four auxiliary fields; Root, flags and RNG have single owners")
 check(str(core.flags_hex).hex_decode()[7]==0 and str(core.objects_hex["7"]).hex_decode()==raw.objects[7],"Committed callback flags and skipped later target publish together")
 var snapshot:=owner.snapshot();var cold:=State.new()
 check(cold.restore(JSON.parse_string(JSON.stringify(snapshot))) and digest(cold.raw_core())==digest(core),"Cold damage-enabled scan restores by replaying actual kernels and typed callbacks")
 var hot_next:=owner.prepare([],true,false,false,true);var cold_next:=cold.prepare([],true,false,false,true)
 check(not hot_next.ok and not cold_next.ok and hot_next.has("pending") and cold_next.has("pending") and digest(Scan.json_value(hot_next.get("pending",{})))==digest(Scan.json_value(cold_next.get("pending",{}))),"Hot and cold banks request the exact same next F953 callback with persisted Root, events and flags")
 var next_done:=complete(bank_from_core(core));check(next_done.ok,"Committed damage context can supply the next real scan and shared RNG stream")
 if next_done.ok:
  var hot_complete:=owner.prepare(next_done.packets,true,false,false,true);var cold_complete:=cold.prepare(next_done.packets,true,false,false,true)
  check(hot_complete.ok and cold_complete.ok and digest(hot_complete.candidate_state.raw_core())==digest(cold_complete.candidate_state.raw_core()) and digest(hot_complete.receipt)==digest(cold_complete.receipt),"Hot and cold owned banks continue a complete subsequent damage scan with identical body, Root, flags, events and receipt")
  check(owner.commit(hot_complete) and cold.commit(cold_complete) and digest(owner.raw_core())==digest(cold.raw_core()),"Both uninterrupted and restored owners publish the same second real damage scan")
  check(owner.restore(snapshot) and cold.restore(snapshot),"Cold replay of the previous generation remains valid after sequential live scans")
 var altered:=snapshot.duplicate(true);var decoded:=str(altered.core.root_hex).hex_decode();decoded.encode_u32(0x24,decoded.decode_u32(0x24)^1);altered.core.root_hex=decoded.hex_encode()
 check(not cold.restore(snapshot_signature(altered)),"Rehashed cold RNG tampering still fails original damage scan replay")
 altered=snapshot.duplicate(true);decoded=str(altered.core.flags_hex).hex_decode();decoded[7]=4;altered.core.flags_hex=decoded.hex_encode()
 check(not cold.restore(snapshot_signature(altered)),"Rehashed cold callback flags cannot bypass original scan replay")
 for aux:Variant in [{},null,{"event_registers":"00"}]:
  if aux==null:continue
  check(not owner.configure(raw.body,raw.objects,raw.flags,raw.root,raw.globals,raw.ticks,raw.source_frame,null,aux),"Incomplete optional damage auxiliary state rejects atomically")
 for extra:String in ["root","flags","rng"]:
  var duplicated:Dictionary=raw.damage_aux.duplicate(true);duplicated[extra]=raw.root.duplicate()
  check(not owner.configure(raw.body,raw.objects,raw.flags,raw.root,raw.globals,raw.ticks,raw.source_frame,null,duplicated),"Damage auxiliary state cannot introduce a second Root/flags/RNG owner: "+extra)
 check(digest(owner.raw_core())==digest(core),"Bad receipts, cold data and auxiliary fields never mutate live damage state")
 var legacy:=State.new();check(legacy.configure(raw.body,raw.objects,raw.flags,raw.root,raw.globals,raw.ticks,raw.source_frame),"Legacy core without optional damage aux remains supported")
 check(not legacy.prepare([],true,false,false,true).ok,"Actual damage route requires the owned event and module state")
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_contact_scan_native.json"))
 for row:Dictionary in old.cases.slice(0,4):
  var objects:Dictionary={}
  for key:String in row.objects_by_index:objects[int(key)]=str(row.objects_by_index[key]).hex_decode()
  var old_owner:=State.new();check(old_owner.configure(str(row.player_hex).hex_decode(),objects,str(row.flags_hex).hex_decode(),str(row.root_before_hex).hex_decode(),row.globals,row.frame_ticks_u32,row.source_frame_byte),"Previous native v1 core still configures without damage state")
  var token:=old_owner.prepare(row.classifier_observations,row.enabled);check(token.ok and old_owner.commit(token),"Previous default observation route still commits its measured native scan")
  if token.ok:
   var saved:=old_owner.snapshot();var restored:=State.new();check(not saved.core.has("damage_aux") and not saved.last_witness.payload.has("use_damage") and restored.restore(JSON.parse_string(JSON.stringify(saved))),"Existing v1 default save retains its old field shape and cold replay")
func malformed()->void:
 var raw:=bank();var before:=var_to_bytes(raw);var globals:Dictionary=raw.globals.duplicate(true);globals["player_index_u32"]=17;var vector:=PackedByteArray();vector.resize(24);var damage:=context(raw)
 for bad:Variant in [null,true,0,"context",[],{}]:check(not Contact.execute(raw.body,raw.objects[9],vector,globals,bad).ok,"Malformed full damage contact context rejects")
 for key:String in Damage.CONTEXT_KEYS:
  var changed:=damage.duplicate(true);changed.erase(key);check(not Contact.execute(raw.body,raw.objects[9],vector,globals,changed).ok,"Missing complete actual damage context field rejects: "+key)
 var changed:=damage.duplicate(true);changed.root.encode_u32(0xc0,18)
 check(not Contact.execute(raw.body,raw.objects[9],vector,globals,changed).ok,"Damage context Root player reference must match classifier globals")
 changed=damage.duplicate(true);changed.root[0]^=1
 check(not Scan.dispatch(raw.body,raw.objects,raw.flags,raw.root,raw.globals,raw.ticks,raw.source_frame,[],true,false,null,changed).ok,"Actual scan rejects a second, mismatched Root copy")
 changed=damage.duplicate(true);changed.flags[7]=0
 check(not Scan.dispatch(raw.body,raw.objects,raw.flags,raw.root,raw.globals,raw.ticks,raw.source_frame,[],true,false,null,changed).ok,"Actual scan rejects a second, mismatched flag-bank copy")
 for packets:Variant in [null,true,0,"packets",{},[{}],[{"call_index_u32":0,"observations":[],"extra":0}]]:check(not Contact.execute(raw.body,raw.objects[9],vector,globals,damage,[],packets).ok,"Malformed per-F953 packet container rejects")
 check(not Contact.execute(raw.body,raw.objects[9],vector,globals,damage,[],[{"call_index_u32":63,"observations":[]}]).ok,"A reply assigned to an unused damage call cannot fabricate completion")
 check(not Contact.execute(raw.body,raw.objects[9],vector,globals,damage,[],[],[{"iteration_u32":0,"observations":[]}]).ok,"Unused geometry observations cannot enter a sphere-only damage route")
 var done:=complete(raw)
 if done.ok:
  var packets:Array=done.packets.duplicate(true);packets[0].damage_observations[0].observations[0].before.context.root[0]^=1
  check(not invoke(raw,packets).ok,"A nested damage callback with another Root before-state rejects atomically")
  packets=done.packets.duplicate(true);packets[0].damage_observations[0].call_index_u32=1
  check(not invoke(raw,packets).ok,"A callback stream for another F953 within the same classifier cannot continue")
  packets=done.packets.duplicate(true);packets[0].damage_observations.append(packets[0].damage_observations[-1].duplicate(true))
  check(not invoke(raw,packets).ok,"Unused duplicated nested damage packets cannot enter an owned witness")
 check(var_to_bytes(raw)==before,"Rejected complete contexts and packet policies preserve every caller owner")
func buffer(reference:String)->PackedByteArray:
 if hydrated.has(reference):return hydrated[reference].duplicate()
 var entry:Dictionary=buffer_pool[reference];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
 var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(raw)
 check(raw.size()==int(entry.byte_count) and hasher.finish().hex_encode()==reference,"Composed native pool decodes to its exact original bytes and SHA")
 hydrated[reference]=raw.duplicate();return raw
func hydrate_context(value:Dictionary)->Dictionary:
 var result:=value.duplicate(true)
 for key:String in Damage.BYTE_COUNTS:result[key]=buffer(str(value[key]))
 for key:String in result.model_descriptors:result.model_descriptors[key]=buffer(str(value.model_descriptors[key]))
 return result
func hydrate_observations(value:Array)->Array:
 var result:Array=[]
 for source:Dictionary in value:
  var row:Dictionary={"kind":source.kind,"args":source.args.duplicate(),"return_u32":source.return_u32}
  if source.has("payload_after_u32"):row["payload_after_u32"]=source.payload_after_u32.duplicate()
  for side:String in ["before","after"]:row[side]={"body":buffer(str(source[side].body)),"context":hydrate_context(source[side].context)}
  result.append(row)
 return result
func decode_outer(value:Array)->Array:
 var result:Array=value.duplicate(true)
 for row:Dictionary in result:
  for side:String in ["before","after"]:
   for key:String in ["body","collider","relative"]:
    if row[side][key] is String:row[side][key]=str(row[side][key]).hex_decode()
 return result
func native()->void:
 check(FileAccess.file_exists(FIXTURE),"Independent composed DOS F575/F953 fixture is available")
 if not FileAccess.file_exists(FIXTURE):return
 check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Whole DOS damage/contact proof corpus is pinned")
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));buffer_pool=fixture.buffers;dependencies=fixture.proof.source_dependencies_sha256.duplicate(true)
 check(int(fixture.case_count)==40 and int(fixture.proof.actual_F953_calls)==72 and int(fixture.proof.pair_two_damage_cases)==32 and int(fixture.proof.actual_F1530_calls)==54,"Independent composition retains all40 original contact responses,72 actual damage kernels and54 shared Root RNG invocations")
 check(int(fixture.proof.fresh_process_runs_each_call)==3 and fixture.proof.all_raw_native_canaries_verified and not fixture.proof.expected_arithmetic_calculated_in_python,"Composed oracle preserves whole original kernels and checked raw process canaries")
 for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Composed native damage proof dependency is pinned: "+path)
 var damage_count:=0;var pairs:=0;var changed_player:=0;var rng_count:=0
 for row:Dictionary in fixture.cases:
  var record:=str(row.body_hex).hex_decode();var collider:=str(row.collider_hex).hex_decode();var vector:=str(row.relative_hex).hex_decode();var state:=hydrate_context(row.damage_context_before);var outer:=decode_outer(row.observations);var packets:Array=[]
  for packet:Dictionary in row.damage_packets:packets.append({"call_index_u32":packet.call_index_u32,"observations":hydrate_observations(packet.observations)})
  var frozen:=var_to_bytes([record,collider,vector,row.globals_before,state,outer,packets]);var result:=Contact.execute(record,collider,vector,row.globals_before,state,outer,packets);native_cases+=1
  check(result.ok,"Native F575 resumes its actual F953 results in source order: "+str(row.name)+" "+str(result.get("reason")))
  if not result.ok:continue
  var expected:Dictionary=row.expected
  check(result.body_after==str(expected.body_after_hex).hex_decode() and result.collider_after==str(expected.collider_after_hex).hex_decode() and result.relative_after==str(expected.relative_after_hex).hex_decode(),"Every original contact record and relative vector agrees with independently composed native kernels: "+str(row.name))
  check(digest(result.globals_after)==digest(expected.globals_after) and int(result.return_u8)==int(expected.return_u8) and result.source_order==expected.source_order,"Original caller signed/byte result, globals and whole-kernel call order match native composition: "+str(row.name))
  check(Damage._same_context(result.damage_context_after,hydrate_context(row.damage_context_after)) and result.damage_calls.size()==row.damage_calls.size(),"Original shared Root, flags, event table, module entries and nested damage-call count all match: "+str(row.name))
  for index in range(result.damage_calls.size()):
   var actual:Dictionary=result.damage_calls[index].calculation;var native_call:Dictionary=row.damage_calls[index]
   check(actual.body_after==buffer(str(native_call.expected.body_after)) and Damage._same_context(actual.context_after,hydrate_context(native_call.expected.context_after)) and actual.source_order==native_call.expected.source_order,"Each individual F953 continuation retains the actual preceding kernel's body, Root and callback state")
   check(int(actual.return_u32)==int(native_call.expected.return_u32) and int(actual.return_s32)==int(native_call.expected.return_s32),"Fatal/equipment signed return propagates unchanged at the exact original callsite")
   damage_count+=1;rng_count+=int(actual.rng_calls_u32)
  if result.damage_calls.size()==2:pairs+=1
  if result.damage_context_after.root.decode_u32(0xc0)!=state.root.decode_u32(0xc0):changed_player+=1
  var cold_packets:Variant=JSON.parse_string(JSON.stringify(Scan.json_value(packets)));var cold_context:=Damage.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(state))));var cold:=Contact.execute(record,collider,vector,row.globals_before,cold_context,outer,cold_packets)
  check(cold.ok and cold.body_after==result.body_after and cold.collider_after==result.collider_after and Damage._same_context(cold.damage_context_after,result.damage_context_after) and digest(cold.globals_after)==digest(result.globals_after),"Complete native damage/contact callback packets retain exact results after cold JSON transport: "+str(row.name))
  check(var_to_bytes([record,collider,vector,row.globals_before,state,outer,packets])==frozen,"Independent native composition preserves every caller-owned raw input: "+str(row.name))
 check(damage_count==72 and pairs==32 and rng_count==54 and changed_player>0,"All measured paired damage, shared RNG and changed Root player continuations actually execute")
func run()->void:
 scan_threading();terrain_threading();owned();malformed();native()
 var sources:Dictionary={}
 for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
 for path:String in ["scripts/source_damage_contact.gd","scripts/source_damage.gd","scripts/source_global_rng.gd","scripts/source_contact_scan.gd","scripts/source_contact_scan_state.gd","scripts/source_frame_dispatch.gd","tests/test_source_damage_contact.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
 if FileAccess.file_exists(FIXTURE):sources[FIXTURE.trim_prefix("res://")]=FileAccess.get_sha256(FIXTURE)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var output:=FileAccess.open(REPORT,FileAccess.WRITE)
 if output:output.store_string(JSON.stringify({"profile":Contact.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"sources":sources,"threading_controls_are_explicit_test_callbacks":true,"full_world_effects_executed":false,"Main_integrated":false},"\t"));output.close()
 print("SOURCE DAMAGE CONTACT TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
