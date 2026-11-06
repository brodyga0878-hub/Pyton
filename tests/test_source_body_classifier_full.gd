extends SceneTree
const Full=preload("res://scripts/source_body_classifier_full.gd")
const NATIVE_PATH:="res://tests/fixtures/source_system_native.json"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(label)
func state_for(row:Dictionary)->Dictionary:
	return {"index":int(row.index),"seed_a":int(row.seed_a),"seed_b":int(row.seed_b),"population_raw":int(row.population_raw),"system_id":int(row.system_id),"ordinal_counter":0,"port_count_byte":0,"orbital_count_byte":0,"language":0}
func bank_for(row:Dictionary)->Array:
	var bank:Array=[]
	for i in range(128):
		var record:=PackedByteArray();record.resize(68);record.fill(0xa5);bank.append(record)
	bank[int(row.index)]=str(row.record_hex).hex_decode()
	return bank
func compatibility()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rebuilt_planet_classification_native.json"))
	check(fixture.get("source_sha256")=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72","Old independent native classifier controls retain executable provenance")
	var classifier:=Full.new();var accepted:=0
	for row:Dictionary in fixture.cases:
		if not row.expected.supported:continue
		accepted+=1
		var bank:=bank_for(row);var state:=state_for(row);var before:=var_to_bytes([bank,state])
		var result:=classifier.classify(bank,row.callback,row.mass,state)
		check(not result.is_empty() and result.get("ok",false),"Full callback preserves old complete path "+str(row.callback))
		if result.is_empty() or not result.get("ok",false):continue
		check(result.records[int(row.index)]==str(row.expected.record_hex).hex_decode(),"Exact complete old native record "+str(row.callback))
		check(result.index==int(row.index) and result.seed_a==int(row.expected.seed_a) and result.seed_b==int(row.expected.seed_b),"Exact old native index and both global RNG words")
		var expected:=bank.duplicate();expected[int(row.index)]=str(row.expected.record_hex).hex_decode()
		check(result.records==expected,"Callback cannot mutate another source record on old complete paths")
		check(var_to_bytes([bank,state])==before,"Candidate classification preserves caller bank and request")
	check(accepted==int(fixture.supported_case_count),"Every independently completed old callback is preserved")
func atomic_guards()->void:
	var row:={"index":0,"seed_a":0,"seed_b":0,"population_raw":200,"system_id":44341016,"record_hex":""}
	var record:=PackedByteArray();record.resize(68);record.encode_u32(0,0x00494ac0);record.encode_u32(4,0xe3d24ac9);record.encode_u16(0x24,280);row.record_hex=record.hex_encode()
	var bank:=bank_for(row);var state:=state_for(row);var before:=var_to_bytes([bank,state]);var classifier:=Full.new()
	for bad in [-1,0,882,888,NAN,INF,883.5,"883",null]:check(classifier.classify(bank,bad,0,state).is_empty(),"Invalid callback domain rejects")
	for bad in [-1,NAN,INF,0.5,4294967296.0,"0",null]:check(classifier.classify(bank,883,bad,state).is_empty(),"Invalid mass rejects before mutation")
	for key in Full.FIELDS:
		var invalid:=state.duplicate();invalid.erase(key)
		check(classifier.classify(bank,883,0,invalid).is_empty(),"Every source context word is explicit "+str(key))
	var short:=bank.duplicate();short[1]=PackedByteArray([0]);check(classifier.classify(short,883,0,state).is_empty(),"Malformed bank record rejects")
	check(var_to_bytes([bank,state])==before,"All rejected calls preserve complete inputs")
	state.index=127;bank[127]=record.duplicate();before=var_to_bytes([bank,state])
	var capacity:=classifier.classify(bank,884,0,state)
	check(capacity.get("ok")==false and capacity.get("reason")=="capacity" and not capacity.has("records"),"Settlement bank exhaustion rejects entire callback atomically")
	check(var_to_bytes([bank,state])==before,"Capacity rejection preserves pre-name and pre-classification source state")
func raw_digest(records:Array)->String:
	var raw:=PackedByteArray()
	for record:PackedByteArray in records:raw.append_array(record)
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw);return hash.finish().hex_encode()
func complete_native()->void:
	if not FileAccess.file_exists(NATIVE_PATH):check(false,"Independent full callback fixture is required before completion");return
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(NATIVE_PATH))
	check(fixture.get("source_sha256")=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72","Full callback controls pin original executable")
	check(fixture.get("source_assembly_sha256")=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a" and fixture.get("source_commit")=="7e540341d4e09aa3c92877b87d49e7f2c143ad8d","Complete callbacks pin independently executed source revision")
	check(fixture.get("record_bank_slots")==128 and fixture.get("source_f881_entry_limit")==60,"Full callback bank is distinct from original body-entry limit")
	check(fixture.get("fresh_process_runs")==3 and fixture.get("reverse_repeat_count")==fixture.get("case_count") and fixture.get("guard_canaries_unchanged")==true,"Complete native callback oracle repeats and protects complete source bank")
	check(fixture.get("source_procedure_hashes") is Dictionary and fixture.source_procedure_hashes.has_all(["883","884","885","886","887"]),"Every tested source callback has pinned native procedure provenance")
	check(fixture.get("callback_cases") is Array and not fixture.callback_cases.is_empty(),"Native fixture includes direct complete callbacks")
	if not fixture.get("callback_cases") is Array:return
	var classifier:=Full.new();var callback_counts:Dictionary={};var appended:=0
	for row:Dictionary in fixture.callback_cases:
		var bank:Array=[]
		for i in range(128):
			var record:=PackedByteArray();record.resize(68);record.fill(int(row.get("fill_byte",0)));bank.append(record)
		for key in row.records:bank[int(key)]=str(row.records[key]).hex_decode()
		var expected:=bank.duplicate()
		for key in row.expected_records:expected[int(key)]=str(row.expected_records[key]).hex_decode()
		check(raw_digest(expected)==str(row.expected_bank_sha256),"Independent sparse callback output reconstructs the complete native bank")
		var state:=state_for(row)
		state.ordinal_counter=int(row.counter);state.port_count_byte=int(row.port_count_byte);state.orbital_count_byte=int(row.orbital_count_byte);state.language=int(row.language)
		var before:=var_to_bytes([bank,state]);var result:=classifier.classify(bank,row.callback,row.mass,state)
		callback_counts[int(row.callback)]=int(callback_counts.get(int(row.callback),0))+1
		check(not result.is_empty() and result.get("ok",false),"Complete original callback succeeds "+str(row.callback))
		if result.is_empty() or not result.get("ok",false):continue
		check(result.records==expected and raw_digest(result.records)==str(row.expected_bank_sha256),"All128 source records exactly match complete native callback "+str(row.callback))
		for pair in [["index","index"],["seed_a","seed_a"],["seed_b","seed_b"],["ordinal_counter","counter"],["port_count_byte","port_count_byte"],["orbital_count_byte","orbital_count_byte"],["language","language"]]:
			check(result[pair[0]]==int(row.expected[pair[1]]),"Complete native callback source state "+str(pair[0]))
		check(var_to_bytes([bank,state])==before,"Complete populated callback is an atomic candidate")
		if result.appended_count>0:appended+=1
	for callback in Full.CALLBACKS:check(int(callback_counts.get(callback,0))>0,"Every complete original classifier has native coverage "+str(callback))
	check(appended>0,"Native callbacks exercise actual appended settlement records")
func run()->void:
	compatibility();atomic_guards();complete_native()
	print("SOURCE FULL BODY CLASSIFIER TESTS: %d checks, %d failures; complete populated callbacks and preserved source controls"%[checks,failures])
	quit(1 if failures else 0)
