extends SceneTree
const Effects=preload("res://scripts/source_damage_effects.gd")
const State=preload("res://scripts/source_damage_effects_state.gd")
const Damage=preload("res://scripts/source_damage.gd")
const Equipment=preload("res://scripts/source_equipment.gd")
const Destruction=preload("res://scripts/source_destruction.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const FIXTURE:="res://tests/fixtures/source_damage_effects_native.json"
const FIXTURE_SHA:="11a115d6b2c122a0e0dd33b82d83e93775432fec9893ebcfbbcbd424b07ba96b"
const REPORT:="res://build/current-test-reports/source-damage-effects.json"
var checks:=0
var failures:=0
var native_cases:=0
var pool:Dictionary={}
var cache:Dictionary={}
var dependencies:Dictionary={}
var native_coverage:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<25:push_error(message)
func bytes(count:int)->PackedByteArray:
	var value:=PackedByteArray();value.resize(count);return value
func put(bank:PackedByteArray,slot:int,body:PackedByteArray)->void:
	for index in range(338):bank[116+slot*338+index]=body[index]
func base()->Dictionary:
	var root:=bytes(16384);root.encode_u32(0,0x12345678);root.encode_u32(4,0x121cf7)
	root.encode_u32(0x24,0x12345678);root.encode_u32(0x28,0x456789ab);root.encode_u32(0xc0,114);root.encode_u32(0xc8,114)
	var body:=bytes(338);body.encode_u32(0x82,24);body[0x86]=114;body[0x87]=3;body[0x118]=0;body.encode_u16(0xe0,100);body.encode_u16(0xe4,100);body[0xd0]=4
	var bank:=bytes(38986);bank[114]=4;put(bank,114,body)
	return {"root":root,"bank":bank,"event_registers":bytes(284),"module_entries":bytes(168),"module_count_s32":-1,"model_resources":Effects.source_resources()}
func complete(context:Dictionary,slot:int,amount:int,attacker:int=0,mutator:Callable=Callable())->Dictionary:
	var observed:Array=[];var equipment:Array=[];var destruction:Array=[]
	for step in range(96):
		var result:=Effects.execute(context,slot,amount,attacker,observed,equipment,destruction)
		if result.get("ok",false) or not result.get("pending") is Dictionary:return {"result":result,"observations":observed,"equipment_packets":equipment,"destruction_packets":destruction}
		var pending:Dictionary=result.pending;var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":pending.before.duplicate(true),"return_u32":0}
		var stage:String=result.effect_stage
		if mutator.is_valid():mutator.call(row,stage,step)
		if stage=="damage":observed.append(row)
		else:
			var packets:Array=equipment if stage=="equipment" else destruction
			var call_index:int=int(result.effect_call_index_u32)
			if packets.is_empty() or int(packets[-1].call_index_u32)!=call_index:packets.append({"call_index_u32":call_index,"observations":[]})
			packets[-1].observations.append(row)
	return {"result":{"ok":false,"reason":"test_callback_limit"},"observations":observed,"equipment_packets":equipment,"destruction_packets":destruction}
func invoke(context:Dictionary,slot:int,amount:int,attacker:int,completed:Dictionary)->Dictionary:
	return Effects.execute(context,slot,amount,attacker,completed.observations,completed.equipment_packets,completed.destruction_packets)
func prepare(owner:RefCounted,slot:int,amount:int,attacker:int,completed:Dictionary)->Dictionary:
	return owner.prepare_damage(slot,amount,attacker,completed.observations,completed.equipment_packets,completed.destruction_packets)
func same(first:Dictionary,second:Dictionary)->bool:
	for key:String in Effects.KEYS:
		if first[key]!=second[key]:return false
	return true
func signed_save(value:Dictionary)->Dictionary:
	var copy:=value.duplicate(true);copy.erase("snapshot_sha256");copy["snapshot_sha256"]=Clock._hash(copy);return copy
func mutate_shield_callback(row:Dictionary,stage:String,_step:int)->void:
	if stage=="damage" and row.kind=="F1907":
		row.after.context.root.encode_u32(0x24,0xffffffff);row.after.context.root.encode_u32(0x70,7)
		row.after.body[0x151]=0x80
func directed()->void:
	var context:=base();check(context.model_resources.size()==151 and Effects._context(context),"Composition owns149 original plus2 captured special resources")
	var frozen:=var_to_bytes(context);var completed:=complete(context,114,7,3);var result:Dictionary=completed.result
	check(result.ok and result.equipment_calls_u32==0 and result.destruction_calls_u32==0,"Shield damage executes actual F953 without inventing an effect call")
	if result.ok:
		check(result.body_after.decode_u16(0xe0)==93 and result.body_after.decode_u16(0xe4)==100,"Source shield subtraction leaves hull intact")
		check(result.context_after.event_registers.decode_u32(13*4)==114 and result.context_after.event_registers.decode_u32(14*4)==3 and result.context_after.event_registers.decode_u32(12*4)==7,"Shared source event registers retain target, attacker and admitted damage")
		check(result.context_after.root==context.root and result.context_after.bank.slice(0,115)==context.bank.slice(0,115),"Shield route preserves the single Root RNG/count and bank flag owners")
	check(var_to_bytes(context)==frozen,"Completing explicit test callbacks never mutates original input owners")
	completed=complete(context,114,7,0,Callable(self,"mutate_shield_callback"));result=completed.result
	check(result.ok and result.context_after.root.decode_u32(0x24)==0xffffffff and result.context_after.root.decode_u32(0x70)==7 and result.body_after[0x151]==0x81,"A declared callback changes the actual shared Root while source shield flag write follows it")
	var player:=Effects.body_at(context.bank,114);player[0x118]=255;player.encode_u16(0xe0,0);put(context.bank,114,player)
	context.root.encode_u32(0x118,100000);context.root.encode_u32(0x120,100000);context.root.encode_u16(0x17e,3)
	completed=complete(context,114,20);result=completed.result
	check(result.ok and result.equipment_calls_u32==1 and result.destruction_calls_u32==0 and "F952" in result.source_order and "F951" in result.source_order,"F953 resumes into actual equipment and descending cargo-removal procedures")
	if result.ok:
		check(result.body_after.decode_u16(0xe4)==80 and result.context_after.root.decode_u16(0x17e)==2 and result.context_after.root.decode_u16(0x170)==1,"Hull and actual high cargo word/free-space alias change in source order")
		check(result.effect_calls[0].calculation.F952_body_executed and result.effect_calls[0].kind=="F952","An effects call contains the executed equipment kernel result")
		check(not completed.equipment_packets.is_empty() and completed.destruction_packets.is_empty(),"Equipment callbacks stay separate from F953 and destruction continuations")
	var decoded:=Effects.decode_context(JSON.parse_string(JSON.stringify(Scan.json_value(context))))
	check(not decoded.is_empty() and same(decoded,context),"Full resource context and packed bank survive canonical cold JSON")
	if not decoded.is_empty():check(invoke(decoded,114,20,0,JSON.parse_string(JSON.stringify(Scan.json_value(completed)))).ok,"All nested equipment observations replay through the public cold codecs")
	var impossible:Dictionary=context.duplicate(true);impossible.model_resources["24"].drive_mass_table_u32[4]=46
	check(not Effects.execute(impossible,114,20,0).ok,"A second incompatible drive-mass table rejects before any shared Root write")
	context=base();player=Effects.body_at(context.bank,114);player.encode_u16(0xe0,0);put(context.bank,114,player)
	completed=complete(context,114,100);result=completed.result
	check(result.ok and result.F942_body_executed and result.destruction_calls_u32==1 and result.equipment_calls_u32==0,"Fatal damage executes whole destruction through the physical target bank")
	if result.ok:
		var explosion:int=int(result.effect_calls[0].calculation.explosion_slot_u32)
		check(explosion==113 and result.context_after.bank[114]==0 and result.context_after.bank[113]==9,"Original descending allocation creates an explosion then clears the destroyed slot flag")
		check(Effects.body_at(result.context_after.bank,explosion).decode_u32(0x82)==155 and "F1675" in result.source_order,"New physical record contains the real model155 and original matrix construction")
		check(result.context_after.root!=context.root and result.return_u32==0,"Fatal effects advance shared RNG and return original zero")
		var unsupported:Dictionary=complete(result.context_after,explosion,1,0).result
		check(not unsupported.ok and str(unsupported.reason).contains("unsupported_damage_model_index"),"Later damage on a special model155 actual lookup remains an explicit unsupported source profile")
	context=base();player=Effects.body_at(context.bank,114);player.encode_u16(0xe0,0);put(context.bank,114,player)
	for index in range(1,115):context.bank[index]=1
	context.bank[114]=4
	completed=complete(context,114,100);result=completed.result
	check(result.ok and int(result.effect_calls[0].calculation.explosion_slot_u32)==0 and result.context_after.bank[114]==0,"A genuinely full nonrecyclable bank still frees the victim after allocation failure")
	if result.ok:check("F1675" not in result.source_order and result.context_after.root==context.root,"Failed explosion allocation does not manufacture random orientation or consume its RNG calls")
	context.bank[114]=0x20;context.root.encode_u32(0x70,1)
	completed=complete(context,114,100);result=completed.result
	check(result.ok and int(result.effect_calls[0].calculation.explosion_slot_u32)==114,"A full bank reuses the same physical victim record when the source flags permit it")
	if result.ok:
		check(result.body_after.decode_u32(0x82)==155 and result.context_after.bank[114]==0 and result.context_after.root.decode_u32(0x70)==0,"In-place factory aliasing and final release preserve the original saved pointer/count semantics")
	context=base();player=Effects.body_at(context.bank,114);player[0x86]=1;player.encode_u16(0xe0,0);put(context.bank,113,player);context.bank[114]=0;context.bank[113]=4;context.bank[1]=4
	completed=complete(context,113,100);result=completed.result
	check(result.ok and result.context_after.bank[1]==0 and result.context_after.bank[113]==4,"Physical target slot and record index are distinct: F924 clears the captured logical flag, not its physical address")
	owner_controls()
func owner_controls()->void:
	var context:=base();var owner:=State.new();check(owner.configure(context),"Complete bank context configures one private owner")
	var core:=owner.raw_core();check(core.keys()==["context"] and Effects.KEYS.size()==6 and not core.context.has("flags") and not core.context.has("body") and not core.context.has("rng"),"Cold state has one Root and one bank, with no independently saved flags/body/RNG duplicate")
	check(core.context.root is String and core.context.bank is String and core.context.event_registers is String and core.context.module_entries is String,"Initial packed owners are canonical hex before the first witness is serialized")
	var initial:=Clock._hash(owner.snapshot());var completed:=complete(context,114,7);var prepared:=prepare(owner,114,7,0,completed)
	check(prepared.ok and Clock._hash(owner.snapshot())==initial,"Prepare computes all effects privately before publishing an owner")
	if not prepared.ok:return
	check(owner.commit(prepared) and owner.generation()==1,"The verified effects candidate publishes exactly one generation")
	check(not owner.commit(prepared),"A consumed prepared token cannot publish a second time")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(owner.snapshot()));var cold:=State.new();check(cold.restore(saved) and same(cold.raw_context(),owner.raw_context()),"A cold JSON save replays and restores all shared raw owners")
	var next_context:=owner.raw_context();var next_complete:=complete(next_context,114,1);var first:=prepare(owner,114,1,0,next_complete);var second:=prepare(cold,114,1,0,next_complete)
	check(first.ok and second.ok and Clock._hash(first.receipt)==Clock._hash(second.receipt),"Hot and cold owners produce the same next receipt")
	if first.ok and second.ok:check(owner.commit(first) and cold.commit(second) and same(owner.raw_context(),cold.raw_context()),"Hot and cold paths publish an identical second damage step")
	var clone:=owner.raw_context();clone.root[0]=int(clone.root[0])^255;clone.bank[0]=1
	check(not same(clone,owner.raw_context()),"Returned raw context is a private copy")
	var stable:=Clock._hash(owner.snapshot());var forged:=signed_save(owner.snapshot());var altered:PackedByteArray=str(forged.core.context.bank).hex_decode();altered[0]=1;forged.core.context.bank=altered.hex_encode();forged=signed_save(forged)
	check(not owner.restore(forged) and Clock._hash(owner.snapshot())==stable,"Rehashing a forged after-bank does not bypass last-step replay")
	var again:=prepare(owner,114,1,0,complete(owner.raw_context(),114,1));check(again.ok,"Another valid candidate is available for receipt validation")
	if again.ok:
		var wrong:Dictionary=again.duplicate(true);wrong.receipt.raw_state_after_sha256="forged";check(not owner.commit(wrong) and Clock._hash(owner.snapshot())==stable,"A forged receipt cannot publish state")
	var aba:=State.new();check(aba.configure(context),"ABA owner begins from the same context")
	var token:=prepare(aba,114,7,0,completed);check(token.ok and aba.configure(context) and not aba.commit(token),"Reconfigure to identical bytes invalidates old prepared capabilities")
	for bad:Variant in [null,true,0,[],{},"save"]:check(not owner.restore(bad) and not owner.commit(bad),"Malformed save or prepared containers reject atomically")
	for bad:Variant in [null,true,0,[],"nested"]:
		var raw:Dictionary=owner.snapshot();raw.core=bad;check(not owner.restore(signed_save(raw)),"Malformed nested core rejects without a typed-call error")
		raw=owner.snapshot();raw.core.context=bad;check(not owner.restore(signed_save(raw)),"Malformed nested context rejects without a typed-call error")
		raw=owner.snapshot();raw.last_witness=bad;check(not owner.restore(signed_save(raw)),"Malformed witness container rejects")
		raw=owner.snapshot();raw.last_witness.before_core=bad;check(not owner.restore(signed_save(raw)),"Malformed before-core rejects without a typed-call error")
		raw=owner.snapshot();raw.last_witness.payload=bad;check(not owner.restore(signed_save(raw)),"Malformed nested command payload rejects without a typed-call error")
	for key:String in State.PAYLOAD_KEYS:
		var raw:=owner.snapshot();raw.last_witness.payload.erase(key);raw=signed_save(raw);check(not owner.restore(raw),"An incomplete command witness cannot cold restore: "+key)
	check(Clock._hash(owner.snapshot())==stable,"All rejected receipts and saves preserve active owner state")
func invalid_controls()->void:
	var context:=base();var frozen:=var_to_bytes(context)
	for bad:Variant in [null,true,0,"context",[],{},bytes(0)]:check(not Effects.execute(bad,114,1,0).ok,"Malformed composition context rejects")
	for key:String in Effects.KEYS:
		var wrong:Dictionary=context.duplicate(true);wrong.erase(key);check(not Effects.execute(wrong,114,1,0).ok,"Every raw context owner is required: "+key)
	for key:String in Effects.BUFFER_BYTES:
		var wrong:Dictionary=context.duplicate(true);wrong[key]=bytes(int(Effects.BUFFER_BYTES[key])-1);check(not Effects.execute(wrong,114,1,0).ok,"Truncated raw owner rejects: "+key)
	for value:Variant in [-1,115,true,NAN,INF,0.5,null,"114"]:check(not Effects.execute(context,value,1,0).ok,"An invalid physical slot rejects")
	for value:Variant in [-0x80000001,0x80000000,true,NAN,INF,0.5,null,"1"]:check(not Effects.execute(context,114,value,0).ok,"Invalid signed damage rejects")
	for value:Variant in [-1,0x100000000,true,NAN,INF,0.5,null,"0"]:check(not Effects.execute(context,114,1,value).ok,"Invalid attacker word rejects")
	for value:Variant in [null,true,0,{},[{}],[{"call_index_u32":-1,"observations":[]}],[{"call_index_u32":0,"observations":{}}]]:
		check(not Effects.execute(context,114,1,0,[],value).ok,"Malformed equipment packet rejects")
		check(not Effects.execute(context,114,1,0,[],[],value).ok,"Malformed destruction packet rejects")
	var wrong:Dictionary=context.duplicate(true);wrong.model_resources["149"]=wrong.model_resources["153"].duplicate(true)
	check(not Effects.execute(wrong,114,1,0).ok,"Uncaptured NULL149 cannot enter the actual resource namespace")
	wrong=context.duplicate(true);wrong["flags"]=bytes(115);check(not Effects.execute(wrong,114,1,0).ok,"A duplicate independently owned flags window is rejected")
	check(var_to_bytes(context)==frozen,"All invalid composition calls leave original packed owners unchanged")
func buffer(reference:String)->PackedByteArray:
	if cache.has(reference):return cache[reference].duplicate()
	var entry:Dictionary=pool[reference];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
	check(raw.size()==int(entry.byte_count) and hash.finish().hex_encode()==reference,"A native raw owner buffer hydrates to its exact byte count and SHA256")
	cache[reference]=raw.duplicate();return raw
func hydrate_context(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true)
	for key:String in Effects.BUFFER_BYTES:result[key]=buffer(str(value[key]))
	return Effects._copy_context(result)
func hydrate_damage_context(value:Dictionary,equipment:bool)->Dictionary:
	var result:=value.duplicate(true)
	for key:String in Damage.BYTE_COUNTS:result[key]=buffer(str(value[key]))
	for field:String in (["model_descriptors","physical_specs"] if equipment else ["model_descriptors"]):
		for key:String in result[field]:result[field][key]=buffer(str(value[field][key]))
	return result
func hydrate_observations(value:Array,stage:String)->Array:
	var result:Array=[]
	for original:Dictionary in value:
		var row:Dictionary={"kind":original.kind,"args":original.args.duplicate(),"return_u32":original.return_u32}
		if original.has("payload_after_u32"):row["payload_after_u32"]=original.payload_after_u32.duplicate()
		for side:String in ["before","after"]:
			if stage=="destruction":
				var context:Dictionary=original[side].duplicate(true)
				for key:String in ["root","bank","module_entries"]:context[key]=buffer(str(context[key]))
				row[side]=context
			else:row[side]={"body":buffer(str(original[side].body)),"context":hydrate_damage_context(original[side].context,stage=="equipment")}
		result.append(row)
	return result
func hydrate_packets(value:Array,stage:String)->Array:
	var result:Array=[]
	for row:Dictionary in value:result.append({"call_index_u32":row.call_index_u32,"observations":hydrate_observations(row.observations,stage)})
	return result
func native_controls()->void:
	check(FileAccess.file_exists(FIXTURE),"Independent native full damage/effects composition exists")
	if not FileAccess.file_exists(FIXTURE):return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Native composition fixture is frozen and pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));pool=fixture.buffers;dependencies=fixture.proof.source_dependencies_sha256.duplicate(true)
	check(fixture.schema=="starfrontier-source-damage-effects-native-v1" and fixture.profile=="dos-firstenc-actual-f953-equipment-destruction-composition-v1" and int(fixture.case_count)==fixture.cases.size(),"Native fixture identifies the complete composed source kernels and its case count")
	check(int(fixture.proof.fresh_process_runs_each_call)==3 and fixture.proof.reverse_native_calls_verified and not fixture.proof.expected_arithmetic_calculated_in_python and fixture.proof.all_native_canaries_verified,"Composed expected states come from guarded source instructions in fresh and reverse native processes")
	for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Native composition dependency remains pinned: "+path)
	var equipment_cases:=0;var fatal_cases:=0;var shield_cases:=0;var cargo_cases:=0;var created_cargo_cases:=0;var native_effects:=0;var cold_created_cargo:=false
	for row:Dictionary in fixture.cases:
		var context:=hydrate_context(row.context_before);var expected:=hydrate_context(row.expected.context_after)
		var observed:=hydrate_observations(row.observations,"damage");var equipment:=hydrate_packets(row.equipment_packets,"equipment");var destruction:=hydrate_packets(row.destruction_packets,"destruction");var frozen:=var_to_bytes([context,observed,equipment,destruction])
		var result:=Effects.execute(context,row.target_slot_u32,row.damage_s32,row.attacker_u32,observed,equipment,destruction);native_cases+=1
		check(result.ok,"Actual native F953/effect composition accepts: "+str(row.name))
		if not result.ok:continue
		check(same(result.context_after,expected),"Complete Root, bank, events, modules and readonly resources match native: "+str(row.name))
		check(result.body_after==Effects.body_at(expected.bank,int(row.target_slot_u32)),"Physical target is read back from the resulting authoritative bank: "+str(row.name))
		check(int(result.return_u32)==int(row.expected.return_u32) and int(result.return_s32)==int(row.expected.return_s32),"Source signed and raw returns match native: "+str(row.name))
		check(result.source_order==row.expected.source_order,"Expanded F953/equipment/destruction source order matches native: "+str(row.name))
		check(int(result.equipment_calls_u32)==int(row.expected.equipment_calls_u32) and int(result.destruction_calls_u32)==int(row.expected.destruction_calls_u32),"Actual effect dispatch counts match native: "+str(row.name))
		check(var_to_bytes([context,observed,equipment,destruction])==frozen,"Executing the composition does not mutate caller buffers or observations: "+str(row.name))
		for effect:Dictionary in result.effect_calls:
			native_effects+=1
			if effect.kind=="F942" and int(effect.calculation.cargo_calls_u32)>0:cargo_cases+=1
		var created_cargo:=false
		for index in range(1,115):
			if int(expected.bank[index])!=0 and Effects.body_at(expected.bank,index).decode_u32(0x82)==153:created_cargo=true
		if created_cargo:created_cargo_cases+=1
		if row.family=="equipment":equipment_cases+=1
		elif row.family=="fatal":fatal_cases+=1
		else:shield_cases+=1
		if native_cases%11==1 or (created_cargo and not cold_created_cargo):
			var owner:=State.new();check(owner.configure(context),"Independent native context configures the single cold owner")
			var before:=Clock._hash(owner.snapshot());var prepared:=owner.prepare_damage(row.target_slot_u32,row.damage_s32,row.attacker_u32,observed,equipment,destruction)
			check(prepared.ok and Clock._hash(owner.snapshot())==before,"Independent native effects prepare privately")
			if prepared.ok:
				check(owner.commit(prepared) and same(owner.raw_context(),expected),"Native full bank result commits unchanged")
				var cold:=State.new();var restored:bool=cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))) and same(cold.raw_context(),expected);check(restored,"Native effect continuation replays after cold JSON restore")
				if created_cargo and restored:cold_created_cargo=true
	check(equipment_cases>=16 and fatal_cases>=16 and shield_cases>=4 and native_effects>=32,"Independent corpus covers actual equipment, fatal and no-effect source routes")
	check(cargo_cases>0,"Actual composed destruction paths include original cargo attempts")
	check(created_cargo_cases>=2,"Independent full-bank cases create active original model153 cargo records, beyond allocation-failure attempts")
	check(cold_created_cargo,"An actual native bank containing created model153/model155 effects commits and cold-restores all new records")
	native_coverage={"equipment_cases":equipment_cases,"fatal_cases":fatal_cases,"shield_cases":shield_cases,"cargo_attempt_cases":cargo_cases,"created_cargo_cases":created_cargo_cases,"cold_created_cargo_verified":cold_created_cargo}
func run()->void:
	directed();invalid_controls();native_controls()
	var sources:Dictionary={}
	for path:String in ["scripts/source_damage_effects.gd","scripts/source_damage_effects_state.gd","scripts/source_damage.gd","scripts/source_equipment.gd","scripts/source_destruction.gd","scripts/source_effect_factory.gd","scripts/source_object_factory.gd","scripts/source_global_rng.gd","scripts/body_rotation.gd","scripts/source_clock_pipeline.gd","scripts/source_contact_scan.gd","data/ffe_effect_factory.json","tests/test_source_damage_effects.gd","tests/fixtures/source_damage_effects_native.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var output:=FileAccess.open(REPORT,FileAccess.WRITE)
	if output:output.store_string(JSON.stringify({"profile":Effects.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"native_coverage":native_coverage,"sources":sources,"directed_callbacks_are_explicit_test_providers":true,"Main_integrated":false,"full_event_VM_executed":false},"\t"));output.close()
	print("SOURCE DAMAGE EFFECTS TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
