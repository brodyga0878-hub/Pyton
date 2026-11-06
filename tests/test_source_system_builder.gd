extends SceneTree
const Factory=preload("res://scripts/source_body_factory.gd")
const Builder=preload("res://scripts/source_system_builder.gd")
const Meta=preload("res://scripts/source_system_metadata.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<25:push_error(label)
func bank_for(row:Dictionary)->Array:
 var bank:Array=[]
 for i in range(128):
  var b:=PackedByteArray();b.resize(68);b.fill(int(row.get("fill_byte",0)));bank.append(b)
 for key in row.records:bank[int(key)]=str(row.records[key]).hex_decode()
 return bank
func digest(bank:Array)->String:
 var b:=PackedByteArray()
 for record:PackedByteArray in bank:b.append_array(record)
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(b);return h.finish().hex_encode()
func compare(row:Dictionary,result:Dictionary,bank:Array)->void:
 check(not result.is_empty() and result.has("records"),"Source operation returns complete candidate "+str(row.group))
 if result.is_empty() or not result.has("records"):return
 var expected:=bank.duplicate()
 for key in row.expected_records:expected[int(key)]=str(row.expected_records[key]).hex_decode()
 check(digest(expected)==str(row.expected_bank_sha256),"Sparse independent bank hash")
 check(result.records==expected and digest(result.records)==str(row.expected_bank_sha256),"Complete native128 bank "+str(row.group)+" "+str(row.get("mass")))
 if result.records!=expected and failures<25:
  for i in range(128):
   if result.records[i]!=expected[i]:print("DIFF ",row.operation," ",row.group," i=",i," actual=",result.records[i].hex_encode()," expected=",expected[i].hex_encode());break
 for key in row.expected:
  if int(row.operation)==0 and key in ["star_quota","largest_mass"]:
   check(int(row[key])==int(row.expected[key]),"F881 preserves caller globals "+str(key))
  else:
   check(result.has(key),"All native output fields are explicit "+str(key))
   if result.has(key):check(int(result[key])==int(row.expected[key]),"Native state "+str(key)+" got"+str(result[key])+" expected"+str(row.expected[key]))
func metadata_cases(fixture:Dictionary)->void:
 check(fixture.metadata_case_count==1145,"All direct source metadata controls are present")
 for row:Dictionary in fixture.metadata_cases:
  var actual:=Meta.query(row.system_id,row.first_value,row.second_value)
  check(not actual.is_empty(),"Native metadata context succeeds")
  if actual.is_empty():continue
  check((int(actual.policy_index)&0xffffffff)==int(row.expected.policy_index_u32),"Original signed F868 policy row")
  for i in range(8):check(int(actual.F869_values[i])==int(row.expected["F869_"+str(i)]),"Original F869 field "+str(i))
  for key in ["nibble_low","nibble_high","nibble_max","language","first_value","second_value"]:check(int(actual[key])==int(row.expected[key]),"Original F871 metadata "+str(key))
func guards_and_lookup(fixture:Dictionary)->void:
 var builder:=Builder.new();var factory:=Factory.new();var row:Dictionary=fixture.system_cases[0].duplicate(true);var bank:=bank_for(row);var before:=var_to_bytes([bank,row])
 for key in ["seed_a","mass","num_stars","system_id","population_raw"]:
  var missing:=row.duplicate();missing.erase(key);check(builder.build(missing,bank).is_empty(),"Every F878 parameter is explicit "+str(key))
  for bad in [-1,NAN,INF,0.5,4294967296.0,"0",null]:
   var invalid:=row.duplicate();invalid[key]=bad;check(builder.build(invalid,bank).is_empty(),"Invalid F878 word rejects atomically "+str(key))
 for key in ["initial_seed_a","initial_seed_b","initial_star_quota"]:
  var invalid:=row.duplicate();invalid[key]=-1;check(builder.build(invalid,bank).is_empty(),"Optional diagnostic globals validate before construction "+key)
 var zero_radius:Dictionary=fixture.children_cases[0].duplicate(true);zero_radius.start_radius=0
 check(builder.construct_children(bank_for(zero_radius),zero_radius).is_empty(),"Zero-radius nonterminating source domain rejects atomically")
 var bad_bank:=bank.duplicate();bad_bank[0]=PackedByteArray([0]);check(builder.build(row,bad_bank).is_empty(),"Malformed128-record destination rejects")
 check(builder.build(row,bank.slice(0,60)).is_empty(),"Full builder cannot silently accept legacy60 bank")
 var no_name:=row.duplicate();no_name.erase("system_name");check(builder.build(no_name,bank).is_empty(),"Original name context is required")
 var invalid_name:=row.duplicate();invalid_name.system_name_bytes=PackedByteArray([65,0,66,0]);check(builder.build(invalid_name,bank).is_empty(),"Embedded name terminator rejects")
 var capacity_request:Dictionary=fixture.factory_cases[0].duplicate(true);capacity_request.index=60;var capped:=factory.construct_full(bank,capacity_request)
 check(capped.get("ok")==false and capped.get("reason")=="capacity" and capped.return_word==65535 and capped.index==60,"Original F881 entry gate60 remains intact in128bank")
 check(capped.records==bank,"Original F881 capacity gate writes no record")
 check(before==var_to_bytes([bank,row]),"Malformed calls and capacity preserve original candidate inputs")
 check(builder.orbit_lookup(0x4000)==11945,"Source F896 inclusive endpoint reads real adjacent DATA7130 word")
 check(builder.orbit_lookup(0x4001)==65535 and builder.orbit_lookup(0xffff)==65535,"F896 unsigned upper range returns wordFFFF")
 check(builder.orbit_lookup(0x10000)==builder.orbit_lookup(0),"F896 consumes only inputAX")
 for bad in [-1,NAN,INF,0.5,"0",null]:check(builder.orbit_lookup(bad)==-1,"Invalid F896 host value rejects")
func run()->void:
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_system_native.json"))
 check(fixture.source_sha256==Meta.SOURCE_SHA and fixture.source_commit=="7e540341d4e09aa3c92877b87d49e7f2c143ad8d","Native oracle pins executable and source revision")
 check(fixture.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a","Native hierarchy pins original assembly")
 check(fixture.case_count==5829 and fixture.fresh_process_runs==3 and fixture.reverse_repeat_count==5829 and fixture.guard_canaries_unchanged==true,"Every complete native hierarchy repeats in3fresh processes and reverse order with bank guards")
 check(fixture.record_bank_slots==128 and fixture.source_f881_entry_limit==60,"Bank and source body-entry capacities remain distinct")
 for procedure in ["877","878","881","882","883","884","885","886","887","888","889","890","894","896","897"]:check(fixture.source_procedure_hashes.has(procedure),"Actual native procedure provenance "+procedure)
 metadata_cases(fixture);guards_and_lookup(fixture)
 var factory:=Factory.new()
 for row:Dictionary in fixture.factory_cases:
  var bank:=bank_for(row);var before:=var_to_bytes([bank,row]);var result:=factory.construct_full(bank,row)
  compare(row,result,bank);check(before==var_to_bytes([bank,row]),"Factory candidate preserves inputs")
 var builder:=Builder.new()
 for category in ["binary_cases","children_cases","system_cases"]:
  for row:Dictionary in fixture[category]:
   var bank:=bank_for(row);var before:=var_to_bytes([bank,row]);var result:Dictionary={}
   if category=="binary_cases":result=builder.construct_binary(bank,row)
   elif category=="children_cases":result=builder.construct_children(bank,row)
   else:
    var request:=row.duplicate();request.initial_seed_b=int(row.seed_b);request.initial_star_quota=int(row.star_quota)
    result=builder.build(request,bank)
   compare(row,result,bank);check(before==var_to_bytes([bank,row]),"Full hierarchy candidate preserves inputs")
 var corrected:=0
 for row:Dictionary in fixture.system_cases:
  if row.group!="actual_f860_zero_radius_caller_fix":continue
  corrected+=1;var raw:=row.duplicate();raw.seed_a=int(row.original_seed_a)
  check(Builder.root_radius_would_not_advance(raw) and not Builder.root_radius_would_not_advance(row),"Actual raw zero-radius header and effective safe header remain distinct")
  check(Builder.new().build(raw).is_empty(),"Original infinite source loop rejects before iteration")
 check(corrected==4,"All four native effective zero-radius correction banks are present")
 var largest:=0;var handcrafted:=0;var populated:=0;var multiple:=0
 for row:Dictionary in fixture.system_cases:
  largest=maxi(largest,int(row.expected.index))
  if int(row.seed_a)==0:handcrafted+=1
  if int(row.expected.port_count_byte)>0:populated+=1
  if int(row.expected.star_count_byte)>1:multiple+=1
 check(largest>60,"Real source callbacks append beyond original body-entry gate")
 check(handcrafted==24 and populated>0 and multiple>0,"Complete systems cover every11handcrafted mappings, fallback, inhabited and multiple stars")
 print("SOURCE SYSTEM BUILDER TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
