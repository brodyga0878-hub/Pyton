extends SceneTree
const Initializer=preload("res://scripts/body_initializer.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=12:push_error(message)
func _init()->void:call_deferred("run")
func blank_records()->Array:
	var result:Array=[]
	for _i in range(60):
		var record:=PackedByteArray()
		record.resize(68)
		result.append(record)
	return result
func run()->void:
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rebuilt_body_initializer_native.json"))
	check(reference.schema==1 and reference.case_count==1424 and reference.cases.size()==1424,"All complete independent native F882 cases are present")
	check(reference.source_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72","Original executable provenance")
	check(reference.fresh_process_runs==3 and reference.fresh_process_outputs_identical,"Native oracle repeated in three fresh processes")
	check(reference.same_process_reverse_repeat_checks==1424 and reference.non_target_records_unchanged,"Native reversed controls and untouched other records")
	var initializer:=Initializer.new()
	var orientations:Dictionary={}
	for index in range(reference.cases.size()):
		var row:Dictionary=reference.cases[index]
		var records:=blank_records()
		for key in row.records:records[int(key)]=str(row.records[key]).hex_decode()
		var before:Array=records.duplicate(true)
		var result:Dictionary=initializer.construct(records,int(row.index),int(row.parent),int(row.multiplier),int(row.distance),int(row.mass),int(row.seed_a),int(row.seed_b),int(row.depth),int(row.counter))
		check(not result.is_empty(),"F882 executes case %d"%index)
		check(records==before,"F882 leaves supplied input records unchanged case %d"%index)
		check(result.get("record")==str(row.expected_record_hex).hex_decode(),"All 68 native bytes match case %d"%index)
		check(result.get("counter")==int(row.expected_counter_u32),"Native uint32 counter matches case %d"%index)
		if not result.is_empty():orientations[int(result.record.decode_u16(0x42))]=true
	check(orientations.has(0) and orientations.has(65535) and orientations.size()==2,"Native LOW16 sign extension covers both source orientation values")
	var records:=blank_records()
	var before:Array=records.duplicate(true)
	for index in [-1,60]:
		check(initializer.construct(records,index,0,1,1,1,1,1,1,1).is_empty(),"Out-of-range destination rejected")
	for parent in [-1,2]:
		check(initializer.construct(records,1,parent,1,1,1,1,1,1,1).is_empty(),"Out-of-range parent rejected")
	for field in range(7):
		for invalid in [-1,0x100000000]:
			var values:Array=[1,1,1,1,1,1,1]
			values[field]=invalid
			check(initializer.construct(records,0,0,values[0],values[1],values[2],values[3],values[4],values[5],values[6]).is_empty(),"Out-of-range uint32 field rejected")
	check(records==before,"Rejected numeric requests leave input unchanged")
	check(initializer.construct([],0,0,1,1,1,1,1,1,1).is_empty(),"Missing record storage rejected")
	var malformed:=blank_records()
	malformed[0]=PackedByteArray([1,2,3])
	check(initializer.construct(malformed,0,0,1,1,1,1,1,1,1).is_empty(),"Incomplete packed record rejected")
	malformed=blank_records()
	malformed[0].encode_u16(8,1)
	check(initializer.construct(malformed,1,1,1,1,1,1,1,1,1).is_empty(),"Invalid ancestor chain rejected before traversal")
	print("REBUILT BODY INITIALIZER TESTS: %d checks, %d failures; 1424 complete original F882 native cases"%[checks,failures])
	quit(1 if failures else 0)
