extends SceneTree
const Names=preload("res://scripts/source_planet_names.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(label)
func run()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_names_native.json"))
	check(fixture.get("schema")==1 and fixture.get("source_sha256")==Names.SOURCE_SHA,"Original executable provenance")
	check(fixture.get("source_variant")==Names.SOURCE_VARIANT and fixture.get("record_and_name_buffer_canaries_unchanged")==true,"Explicit source variant and independent native buffer guards")
	check(fixture.get("case_count")==fixture.cases.size() and fixture.get("fresh_process_runs")==3 and fixture.get("reverse_repeat_count")==fixture.cases.size(),"Independent complete native cases, fresh processes and reverse order")
	for row:Dictionary in fixture.cases:
		var result:Dictionary
		if int(row.operation)==2:
			result=Names.random_bounded(row.uid,row.language,row.category)
			check(not result.is_empty() and result.first==int(row.expected_rng.first) and result.second==int(row.expected_rng.second) and result.value==int(row.expected_rng.value),"Direct original F921 local RNG including32-bit multiply truncation expected "+str(row.expected_rng)+" actual "+str(result))
			continue
		if int(row.operation)==3:
			result=Names.surname(row.uid,row.language)
			check(not result.is_empty(),"Direct original F793 surname executes")
			if result.is_empty():continue
			check(result.name_bytes==str(row.expected_name_hex).hex_decode() and result.first==int(row.expected_rng.first) and result.second==int(row.expected_rng.second),"F793 surname and both local seed words match native")
			continue
		var original:=str(row.record_hex).hex_decode();var before:=original.duplicate()
		if int(row.operation)==1:
			if int(row.category) not in [6,7,8,9,10]:continue
			result=Names.rename(original,row.category,row.language)
		else:result=Names.generate(row.category,row.uid)
		check(not result.is_empty(),"Source naming context executes "+str(row.category)+"/"+str(row.uid))
		if result.is_empty():continue
		check(result.name_bytes==str(row.expected_name_hex).hex_decode(),"Exact original name bytes "+str(row.category)+"/"+str(row.uid)+" expected "+str(row.expected_name_hex)+" actual "+str(result.name_bytes.hex_encode()))
		check(result.end_offset==int(row.expected_end_offset),"Original terminating-NUL pointer offset")
		if int(row.operation)==0:check(result.write_bytes==str(row.expected_write_hex).hex_decode(),"All bytes actually written, including original temporary tails after shortened NUL")
		if int(row.operation)==1:check(result.record==str(row.expected_record_hex).hex_decode(),"Full68-byte renamed record, source flags and untouched bytes")
		check(original==before,"Caller record remains unchanged")
	check(Names.rename(PackedByteArray(),6).is_empty(),"Wrong record length rejects")
	for value in [-1,NAN,INF,0.5,4294967296.0,"6",null]:
		check(Names.generate(value,0).is_empty() and Names.generate(6,value).is_empty(),"Invalid category or UID rejects before mutation")
	var record:=PackedByteArray();record.resize(68);record.encode_u32(4,0xe3d24ac9);var before:=record.duplicate()
	check(Names.rename(record,23).is_empty() and record==before,"Nonfactory model/system name lookup is outside F893 domain")
	check(Names.rename(record,6,3).name_bytes==PackedByteArray([70,111,114,116,114,101,115,115,32,77,91,99,104,0]),"Original M[nich bracket quirk remains visible in French station naming")
	check(Names.expand_table_index(["ff301600"],0,PackedByteArray([65,0]))==PackedByteArray([65,0]),"Exact FF3016 name substitution")
	check(Names.expand_table_index(["ff300100"],0,PackedByteArray([65,0])).is_empty(),"Unimplemented non-name FF domain does not receive fabricated text")
	check(Names.expand_table_index(["ff301600"],0,PackedByteArray([91,71,114,0])).is_empty(),"Foreign journal bracket command requires its own source context")
	print("SOURCE PLANET NAME TESTS: %d checks, %d failures; original F893/F791 byte strings, not model/system lookups"%[checks,failures])
	quit(1 if failures else 0)
