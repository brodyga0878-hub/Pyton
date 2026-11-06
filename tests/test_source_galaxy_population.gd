extends SceneTree
# Broad runtime integration from independently native F860 headers. The204
# native full-bank controls remain separate; this test invents no bank oracle.
const Definition=preload("res://scripts/source_system_definition.gd")
const Builder=preload("res://scripts/source_system_builder.gd")
const Catalogue=preload("res://scripts/source_world_catalogue.gd")
const WorldPolicy=preload("res://scripts/planetary_system.gd")
var checks:=0
var failures:=0
var witnesses:Array=[]
var correction_ids:Array=[]
var models:Dictionary={}
var types:Dictionary={}
var multiplicities:Dictionary={}
var ids:Dictionary={}
var valid_headers:=0
var invalid_headers:=0
var generated_systems:=0
var total_records:=0
var total_bodies:=0
var total_sites:=0
var maximum_records:=0
var repeated_samples:=0

func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(label)
func _raw_digest(bank:Array)->String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	for raw:PackedByteArray in bank:digest.update(raw)
	return digest.finish().hex_encode()
func _witness(id:int,request:Dictionary,error:String,generated:Dictionary)->void:
	if witnesses.size()>=8:return
	var fields:=request.duplicate(true)
	if fields.has("system_name_bytes"):fields.system_name_bytes_hex=fields.system_name_bytes.hex_encode();fields.erase("system_name_bytes")
	var witness:={"system_id":id,"request":fields,"error":error}
	if generated.get("records") is Array:
		var records:Array=[]
		for raw:PackedByteArray in generated.records:records.append(raw.hex_encode())
		witness.records128_hex=records
		witness.record_count=int(generated.get("record_count",-1))
	witnesses.append(witness)

func native_nontermination_witness()->void:
	var path:="res://tests/fixtures/zero_orbit_native.json";var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(FileAccess.get_sha256(path)=="4aef2ed649728e4941c038285ba081bb3f99fa0f2a75db70a1302893839175d3","Pinned actual bounded F878/F897 native witness")
	check(fixture.case_count==4 and fixture.fresh_process_runs==3 and fixture.reverse_repeat_count==4 and fixture.bank_canaries_unchanged and fixture.bank_unchanged_during_f897,"Independent native zero-radius prefix provenance and bank guards")
	for row:Dictionary in fixture.cases:
		var expected:Dictionary=row.expected;var meta:Dictionary=expected.metadata
		check(expected.completed_source_iterations==64 and meta.boundary_count==65 and expected.loop_boundaries.size()==65,"Bounded witness executes64 original loop bodies, never claims normal source return")
		check((int(meta.first_rng_b)&65535)<256 and (int(meta.start_radius)&65535)==0,"Actual original RNG low word produces a zero source radius word")
		check(meta.first_loop_index==3 and meta.final_loop_index==3 and expected.bank_unchanged_during_f897,"Original loop appends no records during the bounded source prefix")
		for i in range(expected.loop_boundaries.size()):
			var boundary:Dictionary=expected.loop_boundaries[i]
			check(boundary.radius_u16==0 and boundary.spacing_u32==0 and boundary.index==3,"Actual original recurrence cannot advance its zero orbit")
			if i>0:check(boundary.candidate_mass_u32==0,"Every completed original loop computes zero candidate mass independent of RNG")
		var bank:Array=[]
		for encoded:String in expected.records128_hex:bank.append(encoded.hex_decode())
		check(_raw_digest(bank)==expected.bank_sha256,"Bounded original prefix preserves its complete native128-record bank")

func run()->void:
	var path:="res://tests/fixtures/source_system_definition_native.json"
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(fixture.case_count==4234 and fixture.fresh_process_runs==3 and fixture.canaries_unchanged,"Independent4234 original F860 header controls")
	native_nontermination_witness()
	var definition:=Definition.new();var builder:=Builder.new();var catalogue:=Catalogue.new()
	for case_index in range(fixture.cases.size()):
		var row:Dictionary=fixture.cases[case_index];var id:=int(row.id);var header:=definition.header(id)
		if int(row.return_s32)!=0:
			invalid_headers+=1;check(header.is_empty(),"Original invalid last-sector index remains rejected "+str(id));continue
		valid_headers+=1;ids[id]=true
		var raw:=str(row.params_hex).hex_decode();var request:Dictionary={}
		for pair in [["seed_a",0],["mass",4],["num_stars",8],["system_id",12],["population_raw",16]]:
			request[pair[0]]=int(raw.decode_u32(int(pair[1])))
			check(int(header.get(pair[0],-1))==request[pair[0]],"Actual F860 header field enters the runtime system builder "+str(id)+"/"+str(pair[0]))
		request.system_name_bytes=str(row.name_hex).hex_decode()
		check(header.get("system_name_bytes")==request.system_name_bytes,"Original source system name reaches population pipeline "+str(id))
		var original_before:=var_to_bytes(request)
		var normalized:=WorldPolicy.normalize_source_parameters(request)
		check(not normalized.is_empty() and normalized.get("original")==request,"Public World caller preserves the exact independently native header "+str(id))
		check(original_before==var_to_bytes(request),"Caller normalization cannot mutate original source inputs "+str(id))
		if normalized.is_empty():_witness(id,request,"normalizer_rejected",{});continue
		if not normalized.policies.is_empty():
			var strict:=builder.build(request)
			check(not strict.get("ok",false),"Unsafe original header rejects before explicit caller correction")
			correction_ids.append({"system_id":id,"original_mass":int(request.mass),"effective_mass":int(normalized.effective.mass),"original_seed_a":int(request.seed_a),"effective_seed_a":int(normalized.effective.seed_a),"policies":Array(normalized.policies)})
		request=normalized.effective
		var before:=var_to_bytes(request);var generated:=builder.build(request)
		check(generated.get("ok",false),"Every valid original galaxy header populates a complete system "+str(id))
		check(before==var_to_bytes(request),"Population cannot mutate its independent original header "+str(id))
		if not generated.get("ok",false):_witness(id,request,str(generated.get("error",generated.get("reason","builder_rejected"))),generated);continue
		var result:=catalogue.build({"id":id},generated)
		check(result.get("ok",false),"Every original generated system converts to a valid complete world catalogue "+str(id))
		if not result.get("ok",false):_witness(id,request,str(result.get("error","catalogue_rejected")),generated);continue
		generated_systems+=1
		var count:=int(generated.record_count);maximum_records=maxi(maximum_records,count)
		total_records+=count;total_bodies+=result.bodies.size();total_sites+=result.settlements.size()
		var multiplicity:=int(request.num_stars);multiplicities[str(multiplicity)]=int(multiplicities.get(str(multiplicity),0))+1
		check(result.bodies.size()+result.settlements.size()==count and generated.records[count].decode_u32(0)==0,"Actual source hierarchy and sentinel retain all generated records "+str(id))
		for i in range(count):
			var record:PackedByteArray=generated.records[i]
			var type_code:=str(record.decode_u16(10));var model:=str(record.decode_u16(12))
			types[type_code]=int(types.get(type_code,0))+1;models[model]=int(models.get(model,0))+1
		if case_index%64==0 or int(request.seed_a)==0 or int(raw.decode_u32(4))==0xffffffff:
			var repeated:=builder.build(request);var again:={}
			if repeated.get("ok",false):again=catalogue.build({"id":id},repeated)
			check(repeated.get("ok",false) and again.get("ok",false),"Repeated source header remains available "+str(id))
			if repeated.get("ok",false) and again.get("ok",false):
				check(repeated.records==generated.records and _raw_digest(repeated.records)==result.runtime_bank_sha256,"Same original header has deterministic complete8704-byte output "+str(id))
				check(again==result,"Same original header has deterministic full world catalogue "+str(id))
			repeated_samples+=1
		if case_index%512==0:print("SOURCE GALAXY POPULATION progress: %d/%d headers, %d systems, %d failures"%[case_index+1,fixture.cases.size(),generated_systems,failures]);await process_frame
	check(valid_headers==4231 and invalid_headers==3,"All valid independent headers covered and three invalid endpoints rejected")
	check(generated_systems==valid_headers and witnesses.is_empty(),"No rare name, descriptor, parent or full-bank population failure")
	check(correction_ids.size()==5 and multiplicities.size()==6,"Exactly one upper-mass and four zero-radius caller policies, with every source multiplicity0..5 covered")
	check(maximum_records<128 and models.size()>=40 and types.size()>=30,"Original model/type population diversity stays inside the reviewed128-slot bank")
	var report:={"schema":1,"scope":"Runtime integration of independently native F860 headers through public World caller normalization, original Builder and Catalogue; no World instance or renderer. Does not add independent native full-bank controls beyond the separate209system fixture.","input_fixture_sha256":FileAccess.get_sha256(path),"valid_headers":valid_headers,"invalid_headers":invalid_headers,"unique_system_ids":ids.size(),"generated_systems":generated_systems,"total_records":total_records,"total_bodies":total_bodies,"total_settlements":total_sites,"maximum_active_records":maximum_records,"multiplicities":multiplicities,"models":models,"types":types,"determinism_samples":repeated_samples,"caller_corrections":correction_ids,"failure_witnesses":witnesses,"checks":checks,"failures":failures}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var destination:=argument.substr(9);var file:=FileAccess.open(destination,FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(report,"\t")+"\n")
	print("SOURCE GALAXY POPULATION TESTS: %d checks, %d failures; %d/%d systems, %d records, max%d active, %d models"%[checks,failures,generated_systems,valid_headers,total_records,maximum_records,models.size()]);quit(1 if failures else 0)
