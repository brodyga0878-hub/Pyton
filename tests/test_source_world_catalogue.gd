extends SceneTree
const Catalogue=preload("res://scripts/source_world_catalogue.gd")
const Builder=preload("res://scripts/source_system_builder.gd")
var checks:=0
var failures:=0
var example:Dictionary={}
var mapped_systems:Dictionary={}
var observed_types:Dictionary={}
var total_records:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<25:push_error(label)
func close(first:float,second:float)->bool:return absf(first-second)<=maxf(1e-11,absf(second)*1e-12)
func blank_bank(fill:int=0)->Array:
	var bank:Array=[]
	for i in range(128):
		var record:=PackedByteArray();record.resize(68);record.fill(fill);bank.append(record)
	return bank
func native_bank(row:Dictionary)->Array:
	var bank:=blank_bank(int(row.fill_byte))
	for key in row.records:bank[int(key)]=str(row.records[key]).hex_decode()
	for key in row.expected_records:bank[int(key)]=str(row.expected_records[key]).hex_decode()
	return bank
func generated_for(bank:Array,count:int,expected:Dictionary)->Dictionary:
	return {"ok":true,"records":bank,"record_count":count,"body_count_byte":int(expected.get("body_count_byte",0)),"star_count_byte":int(expected.get("star_count_byte",0)),"port_count_byte":int(expected.get("port_count_byte",0)),"orbital_count_byte":int(expected.get("orbital_count_byte",expected.get("orbital_port_count_byte",0))),"source_variant":"independent_native_f878_fixture"}
func validate(catalogue:RefCounted,star:Dictionary,generated:Dictionary,native_digest:String="")->Dictionary:
	var before:=var_to_bytes([star,generated]);var result:Dictionary=catalogue.build(star,generated)
	check(result.get("ok",false),"Complete source runtime bank converts atomically "+str(star.id))
	check(before==var_to_bytes([star,generated]),"Catalogue preserves all original source runtime bytes and metadata")
	if not result.get("ok",false):return {}
	if not native_digest.is_empty():check(result.runtime_bank_sha256==native_digest,"Catalogue retains independent full native 8704-byte bank SHA")
	var all:Array=result.bodies+result.settlements;var by_id:Dictionary={};var by_index:Dictionary={}
	check(all.size()==int(generated.record_count),"No original source record omitted or extra training port appended")
	for row:Dictionary in all:by_id[str(row.id)]=row;by_index[int(row.original_index)]=row
	check(by_id.size()==all.size(),"Uniform IDs are unique")
	for index in range(int(generated.record_count)):
		total_records+=1
		var record:PackedByteArray=generated.records[index];var row:Dictionary=by_index[index+1]
		var type_code:=int(record.decode_u16(10));var parent:=int(record.decode_u16(8));observed_types[type_code]=true
		check(str(row.runtime_record_hex).hex_decode()==record,"Exact complete native 68-byte runtime record including name tails")
		check(not row.has("record_hex") and row.runtime_record_domain==Catalogue.RECORD_DOMAIN,"Runtime bank never masquerades as a constructor template")
		check(row.original_type==type_code and row.model_index==int(record.decode_u16(12)) and row.source_uid_u32==int(record.decode_u32(4)),"Type/model/UID come from the actual native runtime fields")
		check(row.parent==("" if parent==0 else str(by_index[parent].id)),"One-based original parent forest preserved")
		var name:=str(row.source_name_bytes_hex).hex_decode();var offset:=38
		while offset<62 and record[offset]!=0:offset+=1
		check(name==record.slice(38,offset+1),"Original NUL-terminated name bytes preserved without code-page guesses")
		check(row.source_phase_u16==int(record.decode_u16(18)) and row.source_inclination_u16==int(record.decode_u16(34)),"Native unsigned angle words preserved")
		check(row.temperature_c==int(record.decode_u16(36))-273,"Original constructor Celsius offset is273, not273.15")
		if type_code>=32:
			check(row.id=="site%d"%(index+1) and not row.has("mass_solar"),"Settlement remains a site, with no fabricated packed ground mass")
			if type_code==35:
				check(row.ground_phase_u16==int(record.decode_u16(18)) and row.ground_inclination_u16==int(record.decode_u16(34)),"Ground ports use actual source packed angle words")
				check(row.source_parameter_domain=="unconverted_ground_constructor_fields","F878 type35 copy retains its actual unconverted parameter domain")
		else:
			check(row.mass_adapter==Catalogue.MASS_ADAPTER and is_finite(float(row.mass_solar)),"Mass display ratio explicitly identifies its original Sol reference")
			check(row.landable==(int(row.model_index)>=117 and int(row.model_index)<=133 and type_code>0 and type_code<17),"Landability follows the proven source natural terrain domain")
			if not row.landable and type_code!=0:check(close(float(row.radius_km)*1000.0,float(row.source_outer_bound_m)),"Unsupported natural/star model uses an explicit descriptor render reference")
			if type_code==0:check(row.kind=="barycenter" and float(row.radius_km)==0.0,"Barycentres preserve source hierarchy without an invented physical sphere")
	if int(star.id)==Catalogue.SOL_ID and by_id.has("earth"):
		check(result.default_id=="earth","Sol starts at the original Earth record")
		check(by_id.has("earth") and by_id.has("moon") and by_id.has("star"),"Stable Sol IDs preserve existing game selection")
		check(close(by_id.earth.radius_km,7049.7) and close(by_id.moon.radius_km,3961.26),"Source static axes, not modern Earth/Moon radii, define render references")
		check(close(by_id.star.mass_solar,1.0),"Original packed F878Sol mass fixes unit display ratio")
	return result
func complete_native_controls()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_system_native.json"))
	check(fixture.source_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and fixture.fresh_process_runs==3 and fixture.guard_canaries_unchanged,"Actual independent F878 native fixture provenance and process guards")
	var catalogue:=Catalogue.new();var builder:=Builder.new();var max_count:=0
	for row:Dictionary in fixture.system_cases:
		var bank:=native_bank(row);var count:=int(row.expected.index);max_count=maxi(max_count,count)
		var generated:=generated_for(bank,count,row.expected);var star:={"id":int(row.system_id),"name":str(row.system_name)}
		var result:=validate(catalogue,star,generated,str(row.expected_bank_sha256))
		if example.is_empty() and not result.is_empty():example={"star":star,"generated":generated}
		if row.group=="complete_handcrafted_dispatch":mapped_systems[int(row.system_id)]=true
		# End-to-end inputs are independently fixed native packets, not values
		# synthesized by this adapter or a parallel procedural implementation.
		var actual:=builder.build({"seed_a":int(row.seed_a),"mass":int(row.mass),"num_stars":int(row.num_stars),"system_id":int(row.system_id),"population_raw":int(row.population_raw),"system_name":str(row.system_name)})
		check(actual.get("ok",false) and actual.records==bank,"Complete source builder emits the independently native catalogue bank")
		if actual.get("ok",false):check(catalogue.build(star,actual).get("ok",false),"Actual builder result contract is accepted")
	check(fixture.system_cases.size()==209 and mapped_systems.size()==11 and max_count==61,"All procedural,11mapped,42realF860headers,4callerfixes,Polaris and fallback complete native systems, including61active records")
func mapped_native_variants()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/handcrafted_runtime_native.json"));var catalogue:=Catalogue.new();var accepted:=0
	for row:Dictionary in fixture.cases:
		if not row.scope.begins_with("actual "):continue
		var bank:=blank_bank()
		for i in range(row.expected.records_hex.size()):bank[i]=str(row.expected.records_hex[i]).hex_decode()
		var system_id:=int(row.system_id) if row.get("system_id")!=null else 19088743
		var result:=validate(catalogue,{"id":system_id},generated_for(bank,int(row.expected.count),row.expected))
		if not result.is_empty():accepted+=1
	check(accepted==24,"All22mapped zero/patterned destination variants and2real fallback suffix variants")
func anchors_and_guards()->void:
	var catalogue:=Catalogue.new();var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_system_native.json"))
	var resource_text:=FileAccess.get_file_as_string("res://data/ffe_runtime_model_descriptors.json");var resource:Dictionary=JSON.parse_string(resource_text)
	check(resource_text.sha256_text()=="cf9c673c2bba22f0c865e77e3a7ceed5497053cdb444b80f31d7439176446818" and resource.model_count==149,"Pinned independent original descriptor byte resource")
	check(resource.model_table_sha256=="2c5a58f2130a6820a47114eaa4e7ee3f8f988aec3df6b12ca1385b32c2b0e532" and resource.model_table_executable_offset==0xba8fc,"Original model pointer table provenance")
	var offsets:Dictionary={}
	for key in resource.models:
		var model:Dictionary=resource.models[key];var raw:=str(model.descriptor_hex).hex_decode()
		check(raw.size()==68 and Catalogue._sha(raw)==str(model.descriptor_sha256),"Each original descriptor retains independently extracted bytes and SHA")
		check(int(model.model_index)==int(key) and int(model.table_slot_executable_offset)==0xba8fc+4*int(key),"Descriptor model-table slot identity")
		offsets[int(model.descriptor_executable_offset)]=true
	check(offsets.size()==149,"All149 descriptors resolve to unique original EXE offsets")
	for row:Dictionary in fixture.system_cases:
		if row.system_name!="Sol":continue
		var generated:=generated_for(native_bank(row),int(row.expected.index),row.expected);var result:=catalogue.build({"id":Catalogue.SOL_ID},generated);var objects:Dictionary={}
		for body:Dictionary in result.bodies:objects[str(body.id)]=body
		check(close(objects.earth.mass_solar,2.9900076544195953e-6) and close(objects.moon.mass_solar,3.500008960022938e-8),"Independent numeric packed-mass anchors from native F878 output")
		check(close(objects.earth.a_au,1.0004361432398383) and close(objects.moon.a_au,0.0025707446115407844),"Independent source-unit orbit anchors from native F878 output")
		check(close(objects.earth.period_days,365.27407407407406) and close(objects.moon.period_days,27.512592592592593),"Independent packed period anchors from native F878 output")
		check(close(objects.earth.source_outer_bound_m,7813417.5) and not close(objects.earth.source_outer_bound_m,objects.earth.radius_km*1000.0),"Original descriptor outer bound is retained separately from static reference and sampled terrain")
		check(close(objects.earth.rotation_hours,24.0),"Source Earth spin exponent displays24hours")
		break
	var original:Dictionary=example.generated;var star:Dictionary=example.star;var before:=var_to_bytes([original,star])
	for key in ["body_count_byte","star_count_byte","port_count_byte","orbital_count_byte","source_variant"]:
		var invalid:=original.duplicate(true);invalid.erase(key)
		check(not catalogue.build(star,invalid).get("ok",false),"Missing original source count or runtime provenance rejects "+key)
	for change in ["missing_model","missing_parent","self_parent","cycle","site_parent","early_zero","missing_sentinel","unterminated_name"]:
		var invalid:=original.duplicate(true)
		if change=="missing_model":invalid.records[0].encode_u16(12,65535)
		elif change=="missing_parent":invalid.records[1].encode_u16(8,127)
		elif change=="self_parent":invalid.records[1].encode_u16(8,2)
		elif change=="cycle":invalid.records[0].encode_u16(8,2);invalid.records[1].encode_u16(8,1)
		elif change=="site_parent":invalid.records[0].encode_u16(10,35);invalid.records[0].encode_u16(8,3)
		elif change=="early_zero":invalid.records[1].encode_u32(0,0)
		elif change=="missing_sentinel":invalid.records[int(invalid.record_count)].encode_u32(0,1)
		elif change=="unterminated_name":
			for i in range(38,62):invalid.records[0][i]=65
		var invalid_before:=var_to_bytes(invalid);var result:=catalogue.build(star,invalid)
		check(not result.get("ok",false) and not result.has("bodies"),"Malformed source bank rejects atomically "+change)
		check(invalid_before==var_to_bytes(invalid),"Malformed input preserved "+change)
	check(before==var_to_bytes([original,star]),"Negative cases cannot mutate the original native fixture")
	var raw:=PackedByteArray([65,131,0]);var safe:=Catalogue.display_name(raw)
	check(safe.text=="A"+String.chr(0xfffd) and safe.has_unmapped_glyphs and raw==PackedByteArray([65,131,0]),"Unproven extended font glyphs preserve original bytes with safe UI fallback")
	var reordered:=original.duplicate(true);var temporary:PackedByteArray=reordered.records[0].duplicate();reordered.records[0]=reordered.records[1];reordered.records[1]=temporary
	# Root moves from one-based1 to2. Adjust all original references and make
	# the former child at slot1 refer to its now-later parent at slot2.
	for i in range(int(reordered.record_count)):
		var parent:=int(reordered.records[i].decode_u16(8))
		if parent==1:reordered.records[i].encode_u16(8,2)
		elif parent==2:reordered.records[i].encode_u16(8,1)
	check(catalogue.build(star,reordered).get("ok",false),"Valid source parent forest is topologically ordered without requiring parent-before-child storage")
func run()->void:
	complete_native_controls();mapped_native_variants();anchors_and_guards()
	check(observed_types.size()>=30 and total_records>3800,"Broad original body and settlement type coverage")
	print("SOURCE WORLD CATALOGUE TESTS: %d checks, %d failures, %d original runtime records"%[checks,failures,total_records]);quit(1 if failures else 0)
