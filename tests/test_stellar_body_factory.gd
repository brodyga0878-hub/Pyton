extends SceneTree
# Independent native controls; no live world, saved progress or graphics touched.
const Factory=preload("res://scripts/stellar_body_factory.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=16:push_error(message)
func _initialize()->void:call_deferred("run")
func blank_records()->Array:
	var rows:Array=[]
	for index in range(60):
		var row:=PackedByteArray();row.resize(68);rows.append(row)
	return rows
func run()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rebuilt_world_factory_native.json"))
	check(fixture.source_sha256==Factory.SOURCE_SHA,"Native source executable provenance")
	check(fixture.case_count==760 and fixture.cases.size()==760,"All new native stellar cases are present")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_count==760,"Fresh native processes and interleaved reverse controls")
	check(fixture.non_target_records_unchanged,"Native target-only record writes")
	var factory:=Factory.new()
	var bins:Dictionary={};var capacities:=0;var remnant_records:=0;var rng_changes:=0
	for i in range(fixture.cases.size()):
		var request:Dictionary=fixture.cases[i]
		var rows:=blank_records()
		for key in request.records:rows[int(key)]=str(request.records[key]).hex_decode()
		var before:=rows.duplicate(true)
		var result:Dictionary=factory.construct(rows,request)
		check(not result.is_empty(),"Accepted native context %d executes"%i)
		check(rows==before,"Native constructor input records unchanged %d"%i)
		if result.is_empty():continue
		for key in request.expected:
			check(result.get(key)==int(request.expected[key]),"Native context %d state %s expected%s actual%s"%[i,key,str(request.expected[key]),str(result.get(key))])
		if int(request.index)==60:
			capacities+=1
			check(not result.ok and not result.has("record"),"Native capacity rejection writes no record %d"%i)
		else:
			check(result.ok and result.record==str(request.expected_record_hex).hex_decode(),"All68nativebytes including source name match %d"%i)
			bins[int(result.mass_bin)]=true
			if int(result.record.decode_u16(0x0c))==0x94:remnant_records+=1
		if result.seed_a!=int(request.seed_a) or result.seed_b!=int(request.seed_b):rng_changes+=1
	check(bins.size()==12 and bins.has(11) and bins.has(22),"All twelve accepted F881 stellar-name mass classes covered")
	check(capacities==31,"Native capacity boundary cases retained")
	check(remnant_records==182 and rng_changes==561,"Native remnant outcomes and random-state branch changes covered")
	# Invalid/unsupported inputs must be rejected before any caller mutation.
	var base:Dictionary=fixture.cases[0].duplicate(true)
	var rows:=blank_records();var before:=rows.duplicate(true)
	for key in ["index","parent","multiplier","distance","mass","seed_a","seed_b","depth","counter","body_count_byte","star_count_byte","planet_counter","moon_counter","third_counter"]:
		for bad in [-1,0x100000000,0.5,"1"]:
			var request:=base.duplicate(true);request[key]=bad
			check(factory.construct(rows,request).is_empty(),"Invalid numeric field rejected: "+key)
	for mass in [0,2000000,Factory.MIN_MASS-1,0xffffffff]:
		var request:=base.duplicate(true);request.mass=mass
		check(factory.construct(rows,request).is_empty(),"Outside proven stellar-name mass domain rejected")
	for key in ["body_count_byte","star_count_byte"]:
		var request:=base.duplicate(true);request[key]=256
		check(factory.construct(rows,request).is_empty(),"Original byte counter range enforced")
	for bad in ["1234567890123456789012","A\nB","Солнце",3]:
		var request:=base.duplicate(true);request.system_name=bad
		check(factory.construct(rows,request).is_empty(),"Unreviewed raw name rejected")
	var request:=base.duplicate(true);request.parent=1
	check(factory.construct(rows,request).is_empty(),"Root cannot point to itself as one-based parent")
	request=base.duplicate(true);request.index=61
	check(factory.construct(rows,request).is_empty(),"API destination beyond explicit capacity boundary rejected")
	check(factory.construct([],base).is_empty(),"Missing record buffer rejected")
	var malformed:=blank_records();malformed[0]=PackedByteArray([1,2])
	check(factory.construct(malformed,base).is_empty(),"Incomplete packed record rejected")
	malformed=blank_records();malformed[0].encode_u16(8,1)
	request=base.duplicate(true);request.index=1;request.parent=1
	check(factory.construct(malformed,request).is_empty(),"Invalid ancestor link rejected before F882 traversal")
	check(rows==before,"Rejected calls preserve input storage")
	print("STELLAR BODY FACTORY TESTS: %d checks, %d failures;760 independent native stellar F881 contexts"%[checks,failures])
	quit(1 if failures else 0)
