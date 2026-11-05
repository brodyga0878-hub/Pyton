extends SceneTree
# Full original F881 controls; unsupported callbacks are non-returning native
# gates, never expected partial planets or settlement records.
const Factory=preload("res://scripts/source_body_factory.gd")
const Stellar=preload("res://scripts/stellar_body_factory.gd")
const FIXTURE:="res://tests/fixtures/source_body_factory_native.json"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=20:push_error(message)
func records_for(row:Dictionary)->Array:
	var records:Array=[]
	for _index in range(60):
		var record:=PackedByteArray();record.resize(68);records.append(record)
	for index in row.get("records",{}):records[int(index)]=str(row.records[index]).hex_decode()
	return records
func request_for(row:Dictionary)->Dictionary:
	var request:Dictionary={}
	for key in Factory.FIELDS:request[key]=row[key]
	request.system_name=row.system_name
	return request
func rejection_controls(factory:RefCounted,base:Dictionary)->void:
	var rows:=records_for(base);var request:=request_for(base)
	var before:=var_to_bytes(rows)
	for key in Factory.FIELDS:
		for value in [-1,0x100000000,0.5,"1",null]:
			var invalid:Dictionary=request.duplicate(true);invalid[key]=value
			check(factory.construct(rows,invalid).is_empty(),"Invalid field rejects atomically: "+key)
	for key in ["body_count_byte","star_count_byte"]:
		var invalid:Dictionary=request.duplicate(true);invalid[key]=256
		check(factory.construct(rows,invalid).is_empty(),"Byte counter bound is explicit: "+key)
	for value in ["1234567890123456789012","A\nB","Солнце",3]:
		var invalid:Dictionary=request.duplicate(true);invalid.system_name=value
		check(factory.construct(rows,invalid).is_empty(),"Invalid raw system name rejected")
	var invalid:Dictionary=request.duplicate(true);invalid.mass=0xffffffff
	check(factory.construct(rows,invalid).is_empty(),"Source table overrun mass is rejected")
	invalid=request.duplicate(true);invalid.index=61
	check(factory.construct(rows,invalid).is_empty(),"Destination past explicit capacity is rejected")
	invalid=request.duplicate(true);invalid.index=0;invalid.parent=0;invalid.mass=1
	check(factory.construct(rows,invalid).is_empty(),"Low-mass root cannot read a fabricated parent minus one")
	invalid=request.duplicate(true);invalid.index=1;invalid.parent=2
	check(factory.construct(rows,invalid).is_empty(),"Forward parent reference rejected")
	check(factory.construct([],request).is_empty(),"Missing source record buffer rejected")
	var malformed:=rows.duplicate(true);malformed[0]=PackedByteArray([1,2])
	check(factory.construct(malformed,request).is_empty(),"Incorrect packed record size rejected")
	malformed=rows.duplicate(true);malformed[0].encode_u16(8,1)
	invalid=request.duplicate(true);invalid.index=1;invalid.parent=1
	check(factory.construct(malformed,invalid).is_empty(),"Invalid ancestor chain rejected")
	for name in [PackedByteArray([1,0]),"1234567890123456789012".to_ascii_buffer(),"ABCDEFGHIJKLMNOPQRSTUVWX".to_ascii_buffer()]:
		malformed=records_for(base);malformed[0].encode_u16(8,0);malformed[0][0x3f]=0
		for offset in range(24):malformed[0][38+offset]=0
		for offset in range(name.size()):malformed[0][38+offset]=name[offset]
		invalid=request.duplicate(true);invalid.index=1;invalid.parent=1;invalid.mass=1
		check(factory.construct(malformed,invalid).is_empty(),"Unbounded or nonprintable parent name rejected without truncation")
	check(var_to_bytes(rows)==before,"All rejected requests preserve the caller's source records")
func stellar_compatibility(factory:RefCounted)->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rebuilt_world_factory_native.json"))
	var old:=Stellar.new()
	for index in range(fixture.cases.size()):
		var row:Dictionary=fixture.cases[index]
		var request:Dictionary=row.duplicate(true);request.population_raw=0;request.system_id=0
		var records:=records_for(row)
		var previous:Dictionary=old.construct(records,row)
		var current:Dictionary=factory.construct(records,request)
		var equivalent:=not current.is_empty()
		for key in previous:equivalent=equivalent and current.get(key)==previous[key]
		check(equivalent,"Previously independently checked stellar native context remains exact: %d"%index)
func run()->void:
	if not FileAccess.file_exists(FIXTURE):push_error("Missing independently generated source-body native fixture");quit(1);return
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.get("source_sha256","")==Factory.SOURCE_SHA,"Original executable provenance is retained")
	check(int(fixture.get("case_count",0))==fixture.get("cases",[]).size() and fixture.cases.size()>500,"Full native factory fixture contains substantial boundary controls")
	check(fixture.get("fresh_process_runs",0)==3,"Native oracle repeats in three fresh processes")
	check(int(fixture.get("reverse_repeat_count",0))==fixture.cases.size(),"Native oracle independently reverses interleaving order")
	check(fixture.get("records_buffer_guard_canaries_unchanged",false) and fixture.get("non_target_records_unchanged",false),"Native controls preserve both buffer guards and every non-target record")
	var factory:=Factory.new();var bins:Dictionary={};var helpers:Dictionary={};var capacities:=0;var completed:=0
	for index in range(fixture.cases.size()):
		var row:Dictionary=fixture.cases[index];var records:=records_for(row);var request:=request_for(row)
		var before:=var_to_bytes([records,request])
		var actual:Dictionary=factory.construct(records,request)
		check(var_to_bytes([records,request])==before,"Complete source records and request remain caller-owned: %d"%index)
		var expected:Dictionary=row.expected
		if not expected.supported:
			var helper:=int(expected.helper_id);helpers[helper]=int(helpers.get(helper,0))+1
			check(actual=={"ok":false,"reason":"requires_unimplemented_source_helper","helper_id":helper},"Actual unsupported helper returns no partial record/state: %d"%index)
			continue
		check(not actual.is_empty(),"Original supported factory context executes: %d"%index)
		if actual.is_empty():continue
		for key in expected:
			if key in ["supported","helper_id"]:continue
			check(actual.get(key)==int(expected[key]),"Native state %s matches context%d"%[key,index])
		check(actual.get("population_raw")==int(request.population_raw) and actual.get("system_id")==int(request.system_id),"Read-only system context is retained: %d"%index)
		if int(request.index)==60:
			capacities+=1
			check(not actual.ok and actual.reason=="capacity" and not actual.has("record"),"Capacity returns original code without constructing a record: %d"%index)
		else:
			completed+=1
			check(actual.ok and actual.record==str(row.expected_record_hex).hex_decode(),"Every original byte including ordinal name matches native F881: %d"%index)
			bins[int(actual.mass_bin)]=true
	check(completed>0 and capacities>0 and helpers.has(893),"Native fixture includes complete construction, capacity and genuine naming boundaries")
	check(bins.size()==23,"All23 source mass intervals are exercised by complete records")
	rejection_controls(factory,fixture.cases[0])
	stellar_compatibility(factory)
	print("SOURCE BODY FACTORY TESTS: %d checks, %d failures; %d independent native F881 contexts, %d complete, %d capacity, helpers%s"%[checks,failures,fixture.cases.size(),completed,capacities,str(helpers)])
	quit(1 if failures else 0)
