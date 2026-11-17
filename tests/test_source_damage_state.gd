extends SceneTree
const State=preload("res://scripts/source_damage_state.gd")
const Damage=preload("res://scripts/source_damage.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_damage_native.json"
const FIXTURE_SHA:="d8f25e97a65c7b04eed8f13a9252758d8866b371a57d8f1e1872cc115a3789c3"
const REPORT:="res://build/current-test-reports/source-damage-state.json"
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
func sign_snapshot(value:Dictionary)->Dictionary:
 var copied:=value.duplicate(true);copied.erase("snapshot_sha256");copied["snapshot_sha256"]=digest(copied);return copied
func flip_hex(value:String,at:int)->String:
 var raw:=value.hex_decode();raw[at]=int(raw[at])^1;return raw.hex_encode()
func base()->Dictionary:
 var body:=PackedByteArray();body.resize(338);body[0x86]=114;body[0x87]=3;body.encode_u32(0x82,24);body.encode_u16(0xe4,4000)
 var root:=PackedByteArray();root.resize(0x4000);root.fill(0x5a);root.encode_u32(0x24,0x12345678);root.encode_u32(0x28,0x87654321)
 var flags:=PackedByteArray();flags.resize(115);flags.fill(0xa5);flags[114]=0
 var events:=PackedByteArray();events.resize(284);events.fill(0xcc)
 var modules:=PackedByteArray();modules.resize(168)
 var descriptor:=PackedByteArray();descriptor.resize(68)
 return {"body":body,"context":{"root":root,"flags":flags,"event_registers":events,"module_entries":modules,"module_count_s32":0,"model_descriptors":{"24":descriptor}}}
func complete(owner:RefCounted,amount:int=1,attacker:int=7)->Dictionary:
 var rows:Array=[]
 for attempt in range(Damage.MAX_OBSERVATIONS+1):
  var prepared:Dictionary=owner.prepare_damage(amount,attacker,rows)
  if prepared.ok:return {"ok":true,"prepared":prepared,"observations":rows}
  if not prepared.get("pending") is Dictionary:return prepared
  var pending:Dictionary=prepared.pending
  rows.append({"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":1})
 return {"ok":false,"reason":"test_boundary_limit"}
func ownership()->void:
 var original:=base();var frozen:=var_to_bytes(original);var owner:=State.new()
 check(not owner.is_active() and owner.snapshot().is_empty() and owner.raw_body().is_empty() and owner.raw_context().is_empty(),"An inactive damage owner invents no Root, RNG, events or object")
 check(not owner.prepare_damage(1,0).ok and not owner.commit({}),"Inactive owner rejects commands and publication")
 check(owner.configure(original.body,original.context),"One target and exact complete damage context configure together")
 var initial:=owner.snapshot();var initial_hash:=digest(initial)
 var pending:=owner.prepare_damage(1,7)
 check(not pending.ok and pending.get("pending") is Dictionary and pending.pending.kind=="F48" and digest(owner.snapshot())==initial_hash,"Missing event callback pauses before publication without mutating live Root or event table")
 var done:=complete(owner);check(done.ok,"Typed identity callback observations complete the actual F953 kernel")
 if not done.ok:return
 var token:Dictionary=done.prepared
 check(token.candidate_state.generation()==1 and owner.generation()==0 and digest(owner.snapshot())==initial_hash and var_to_bytes(original)==frozen,"Preparing damage is private and does not mutate source buffers")
 check(token.receipt.source_order.has("F953") and token.receipt.source_order.has("F34") and token.receipt.source_order.has("F35") and token.receipt.source_order.has("F1530"),"Real damage, event table and shared Root RNG run inside the owned command")
 var raw:=owner.raw_context();raw.root[0]=int(raw.root[0])^1;raw.event_registers[0]=0;raw.model_descriptors["24"][0]=1
 check(digest(owner.snapshot())==initial_hash,"Raw-context copies cannot mutate Root, event words or immutable descriptor catalog")
 var current:=owner.raw_core();current.context.root="00";current.body_hex="00"
 check(digest(owner.snapshot())==initial_hash,"Portable raw core is isolated from the live owner")
 var peer:=State.new();check(peer.configure(original.body,original.context) and not peer.commit(token),"Equivalent raw state does not authorise a foreign transaction")
 for key:String in ["owner_instance_id","owner_revision","before_generation","before_core_sha256","profile"]:
  var forged:=token.duplicate(true);forged[key]="forged" if key in ["before_core_sha256","profile"] else 0
  if key=="before_generation":forged[key]=1
  check(not owner.commit(forged) and digest(owner.snapshot())==initial_hash,"Forged transaction context rejects atomically: "+key)
 var forged:=token.duplicate(true);forged.receipt.return_u32=int(forged.receipt.return_u32)^1
 check(not owner.commit(forged),"Modified damage return receipt fails exact replay")
 for bad:Variant in [null,true,[],0,"receipt"]:
  forged=token.duplicate(true);forged.receipt=bad;check(not owner.commit(forged),"Malformed receipt cannot reach a typed hash call")
 forged=token.duplicate(true);forged.candidate_state=owner;check(not owner.commit(forged),"Live owner cannot be its own prepared candidate")
 forged=token.duplicate(true);forged.candidate_state=RefCounted.new();check(not owner.commit(forged),"Foreign candidate scripts cannot publish")
 var rival:=complete(owner);check(rival.ok and owner.commit(token),"One verified complete damage command commits")
 var saved:=owner.snapshot();var saved_hash:=digest(saved);check(owner.generation()==1,"Commit increments generation exactly once")
 check(not owner.commit(token) and not owner.commit(rival.prepared) and digest(owner.snapshot())==saved_hash,"Duplicate and stale damage publications reject")
 var raw_after:=owner.raw_context()
 check(raw_after.root.decode_u32(0x24)!=original.context.root.decode_u32(0x24) or raw_after.root.decode_u32(0x28)!=original.context.root.decode_u32(0x28),"The shared Root RNG words advance rather than a duplicate private seed")
 check(raw_after.event_registers.decode_u32(12*4)==1 and raw_after.event_registers.decode_u32(13*4)==114 and raw_after.event_registers.decode_u32(14*4)==7,"All source F953 event-register words publish with the target")
 check(owner.raw_core().size()==2 and owner.raw_core().context.size()==6 and not owner.raw_core().context.has("rng"),"Cold state has one Root and the six actual context owners")
 var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(saved))) and digest(cold.raw_core())==digest(owner.raw_core()),"A new owner cold-restores complete raw state through the last actual F953 command")
 var hot_next:=complete(owner,1,7);var cold_next:=complete(cold,1,7)
 check(hot_next.ok and cold_next.ok and digest(hot_next.prepared.candidate_state.raw_core())==digest(cold_next.prepared.candidate_state.raw_core()) and digest(hot_next.prepared.receipt)==digest(cold_next.prepared.receipt),"Cold and uninterrupted damage continue exact body, Root RNG, event table and requests")
 check(not cold.commit(hot_next.prepared),"Cold equality does not transfer owner-instance authority")
 var outstanding:=complete(owner);check(outstanding.ok and owner.restore(JSON.parse_string(JSON.stringify(saved))) and not owner.commit(outstanding.prepared),"Restore invalidates outstanding transactions at identical state")
 for field:String in ["root","flags","event_registers","module_entries"]:
  var modified:=saved.duplicate(true);modified.core.context[field]=flip_hex(modified.core.context[field],0)
  check(not cold.restore(sign_snapshot(modified)),"Rehashed raw damage output disagrees with original command replay: "+field)
 var modified:=saved.duplicate(true);modified.core.body_hex=flip_hex(modified.core.body_hex,0xe4)
 check(not cold.restore(sign_snapshot(modified)),"Rehashed HP output cannot bypass damage replay")
 modified=saved.duplicate(true);modified.last_witness.payload.observations[0].before.context.root=flip_hex(modified.last_witness.payload.observations[0].before.context.root,0x24)
 check(not cold.restore(sign_snapshot(modified)),"Changed observed RNG before-state cannot survive cold command replay")
 check(owner.restore(initial) and owner.generation()==0 and not owner.commit(hot_next.prepared),"Restoring the initial state also invalidates live revisions")
 var before_reset:=complete(owner);check(owner.configure(original.body,original.context) and not owner.commit(before_reset.prepared),"Reconfiguration invalidates old tokens at generation zero")
 check(var_to_bytes(original)==frozen,"Every private command, commit, cold load and rejection preserves caller buffers")
func mutable_broadcast_packet()->void:
 var raw:=base();raw.body[0x118]=255;raw.body.encode_u16(0xe0,50);raw.context.module_entries[16]=2;raw.context.module_entries[24]=2;var owner:=State.new();check(owner.configure(raw.body,raw.context),"Mutable F148 packet control configures one owned target")
 var observations:Array=[];var prepared:Dictionary={};var handler_args:Array=[]
 for attempt in range(Damage.MAX_OBSERVATIONS+1):
  prepared=owner.prepare_damage(1,7,observations)
  if prepared.ok:break
  if not prepared.get("pending") is Dictionary:break
  var pending:Dictionary=prepared.pending;var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":1}
  if pending.kind=="F144_handler":
   handler_args.append(pending.args.duplicate())
   if handler_args.size()==1:row["payload_after_u32"]=[0x12345678,0xffffffff]
  observations.append(row)
 check(prepared.get("ok",false) and handler_args==[[2,2,23,0],[3,2,0x12345678,0xffffffff]],"The second real F148 handler receives the first callback's changed shared stack packet")
 if not prepared.get("ok",false):return
 check(owner.commit(prepared),"Mutable F148 packet effects publish through exact damage replay")
 var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))) and digest(cold.raw_core())==digest(owner.raw_core()),"Cold owned command preserves the optional ephemeral F148 packet continuation")
 check(owner.raw_core().context.size()==6 and not owner.raw_core().context.has("payload_after_u32"),"The F148 packet remains ephemeral rather than becoming a duplicate cold owner")
 var initial:=State.new();initial.configure(raw.body,raw.context)
 for wrong:Variant in [[1],[-1,0],[1,0x100000000],true,null]:
  var altered:Array=observations.duplicate(true)
  for row:Dictionary in altered:
   if row.has("payload_after_u32"):row.payload_after_u32=wrong;break
  check(not initial.prepare_damage(1,7,altered).ok,"Malformed mutable F148 packet rejects before publication")
 var altered:Array=observations.duplicate(true);altered[0]["payload_after_u32"]=[0,0]
 check(not initial.prepare_damage(1,7,altered).ok,"F48 cannot masquerade as the F148 stack packet owner")
func malformed()->void:
 var raw:=base();var owner:=State.new();check(owner.configure(raw.body,raw.context),"Malformed checks begin with an active valid damage state")
 var frozen:=digest(owner.snapshot())
 for bad:Variant in [null,true,0,"state",[],{},PackedByteArray()]:
  check(not owner.configure(bad,raw.context),"Malformed target record rejects")
  check(not owner.configure(raw.body,bad),"Malformed complete damage context rejects")
 for key:String in Damage.CONTEXT_KEYS:
  var altered:Dictionary=raw.context.duplicate(true);altered.erase(key);check(not owner.configure(raw.body,altered),"Missing raw context field rejects: "+key)
 for amount:Variant in [-0x80000001,0x80000000,true,NAN,INF,0.5,null,"0"]:check(not owner.prepare_damage(amount,0).ok,"Invalid signed damage amount rejects")
 for attacker:Variant in [-1,0x100000000,true,NAN,INF,0.5,null,"0"]:check(not owner.prepare_damage(0,attacker).ok,"Invalid attacker event word rejects")
 for bad:Variant in [null,true,0,"trace",{},[{}]]:check(not owner.prepare_damage(1,0,bad).ok,"Malformed callback witness rejects")
 for bad:Variant in [null,true,0,"save",[],{}]:
  check(not owner.restore(bad),"Malformed cold container rejects")
  check(not owner.commit(bad),"Malformed prepared container rejects")
 for key:String in ["schema","version","profile","generation","core","last_witness","snapshot_sha256"]:
  var saved:=owner.snapshot();saved.erase(key);check(not owner.restore(saved),"Incomplete cold save rejects: "+key)
 var callbacks:=complete(owner)
 if callbacks.ok:
  var wrong:Array=callbacks.observations.duplicate(true);wrong[0].before.body[0]=1
  check(not owner.prepare_damage(1,7,wrong).ok,"A callback for a different before-body cannot continue")
  wrong=callbacks.observations.duplicate(true);wrong[0].after.context.model_descriptors["24"][0]=1
  check(not owner.prepare_damage(1,7,wrong).ok,"Immutable descriptors cannot be replaced by a world callback")
  wrong=callbacks.observations.duplicate(true);wrong.append(wrong[-1].duplicate(true))
  check(not owner.prepare_damage(1,7,wrong).ok,"An unused callback result cannot enter a committed witness")
 check(digest(owner.snapshot())==frozen,"All malformed contexts, cold data and observations leave the active owner unchanged")
func buffer(reference:String)->PackedByteArray:
 if hydrated.has(reference):return hydrated[reference].duplicate()
 var entry:Dictionary=buffer_pool[reference];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
 var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(raw)
 check(raw.size()==int(entry.byte_count) and hasher.finish().hex_encode()==reference,"Portable native state buffer decodes to its exact original bytes and SHA")
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
func native_controls()->void:
 check(FileAccess.file_exists(FIXTURE),"Independent full DOS F953 fixture is available for cold owner controls")
 if not FileAccess.file_exists(FIXTURE):return
 check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent native F953 state inputs and results pinned")
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));buffer_pool=fixture.buffers;dependencies=fixture.source_dependencies_sha256.duplicate(true)
 check(int(fixture.fresh_process_runs)==3 and int(fixture.reverse_repeat_cases)==int(fixture.case_count) and not fixture.expected_arithmetic_calculated_in_python and fixture.all_external_results_explicit,"Native state controls retain whole source kernels, guarded process repeats and explicit callback observations")
 for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Damage owner native proof dependency remains pinned: "+path)
 var kinds:Dictionary={};var carried:=0;var mutable_packets:=0
 for row:Dictionary in fixture.cases:
  if row.operation!="damage":continue
  var record:=buffer(str(row.body_before));var state:=hydrate_context(row.context_before);var observations:=hydrate_observations(row.observations);var frozen:=var_to_bytes([record,state,observations]);var owner:=State.new()
  native_cases+=1
  check(owner.configure(record,state),"Independent native target/context configure one complete owner: "+str(row.name))
  var initial:=digest(owner.snapshot());var prepared:=owner.prepare_damage(row.damage_s32,row.attacker_u32,observations)
  check(prepared.ok and digest(owner.snapshot())==initial,"Actual native F953 prepares privately in the owned state: "+str(row.name))
  if not prepared.ok:continue
  var expected_context:=hydrate_context(row.expected.context_after);var expected_body:=buffer(str(row.expected.body_after));var candidate:RefCounted=prepared.candidate_state
  check(candidate.raw_body()==expected_body and Damage._same_context(candidate.raw_context(),expected_context),"Complete native body, Root RNG, flags, events and modules equal private owned result: "+str(row.name))
  check(int(prepared.receipt.return_u32)==int(row.expected.return_u32) and int(prepared.receipt.return_s32)==int(row.expected.return_s32) and prepared.receipt.source_order==row.expected.source_order,"Native signed return and exact kernel/callback ordering survive the damage receipt: "+str(row.name))
  check(owner.commit(prepared) and owner.raw_body()==expected_body and Damage._same_context(owner.raw_context(),expected_context),"Only verified whole native state publishes through commit: "+str(row.name))
  var cold:=State.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))) and digest(cold.raw_core())==digest(owner.raw_core()),"Every native callback-dependent owned result cold-restores through actual F953 replay: "+str(row.name))
  if not observations.is_empty():
   var other:=State.new();other.configure(record,state);var prefix:=observations.slice(0,observations.size()-1);var pending:=other.prepare_damage(row.damage_s32,row.attacker_u32,prefix);var last:Dictionary=observations[-1]
   check(not pending.ok and pending.get("pending") is Dictionary and Damage._same_snapshot(pending.pending.before,last.before) and Damage._same_args(pending.pending.args,last.args) and pending.pending.kind==last.kind and digest(other.snapshot())==initial,"Missing final native callback exposes exact pending state without publishing: "+str(row.name))
  for observation:Dictionary in observations:
   kinds[observation.kind]=true
   if observation.has("payload_after_u32"):mutable_packets+=1
  if row.carries_previous_native_root:carried+=1
  check(var_to_bytes([record,state,observations])==frozen,"Whole native state transaction and JSON replay preserve all caller owners: "+str(row.name))
 check(native_cases>200 and carried>0 and kinds.has("F942") and kinds.has("F952") and kinds.has("F144_handler"),"Owned native controls cover fatal, equipment, dispatched handlers and a shared native RNG sequence")
 check(mutable_packets>0,"Ephemeral mutable F148 packet observations survive cold owner replay")
func run()->void:
 ownership();mutable_broadcast_packet();malformed();native_controls()
 var sources:Dictionary={}
 for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
 for path:String in ["scripts/source_damage_state.gd","scripts/source_damage.gd","scripts/source_global_rng.gd","tests/test_source_damage_state.gd",FIXTURE.trim_prefix("res://")]:sources[path]=FileAccess.get_sha256("res://"+path)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify({"profile":State.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"sources":sources,"full_world_effects_executed":false,"Main_integrated":false},"\t"));file.close()
 print("SOURCE DAMAGE STATE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
