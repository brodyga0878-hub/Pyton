extends SceneTree
# Actual original callback execution supplies every expected record/seed.
const Classifier=preload("res://scripts/planetary_classifier.gd")
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=20:push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rebuilt_planet_classification_native.json"))
	check(fixture.get("source_sha256")==SOURCE_SHA,"Verified executable provenance")
	var cases:Array=fixture.get("cases",[])
	check(cases.size()==3060 and fixture.get("case_count")==cases.size(),"Independent native boundary/random callback contexts present")
	check(fixture.get("fresh_process_runs")==3 and fixture.get("reverse_repeat_count")==cases.size(),"Fresh native processes and reverse interleaving agree")
	check(fixture.get("non_target_records_unchanged")==true and fixture.get("index_unchanged")==true,"Native callback record/index write boundaries preserved")
	var classifier:=Classifier.new()
	var accepted:=0;var rejected:=0;var callbacks:Dictionary={};var helpers:Dictionary={};var rng_changes:=0
	for i in range(cases.size()):
		var row:Dictionary=cases[i]
		var record:=str(row.record_hex).hex_decode();var before:=record.duplicate()
		var actual:Dictionary=classifier.classify(record,row.callback,row.mass,row.population_raw,row.system_id,row.seed_a,row.seed_b)
		check(record==before,"Caller record untouched %d"%i)
		check(not actual.is_empty(),"Native callback context executes %d"%i)
		if actual.is_empty():continue
		var expected:Dictionary=row.expected
		check(actual.get("ok")==expected.supported,"Native callback support boundary %d"%i)
		if expected.supported:
			accepted+=1;callbacks[int(row.callback)]=true
			check(actual.get("record")==str(expected.record_hex).hex_decode(),"All68original classified record bytes %d"%i)
			check(actual.get("seed_a")==int(expected.seed_a),"Original random state A %d"%i)
			check(actual.get("seed_b")==int(expected.seed_b),"Original random state B %d"%i)
			check(actual.get("callback")==int(row.callback),"Caller callback identity retained %d"%i)
			if int(expected.seed_a)!=int(row.seed_a) or int(expected.seed_b)!=int(row.seed_b):rng_changes+=1
		else:
			rejected+=1;helpers[int(expected.helper_id)]=true
			check(actual.get("helper_id")==int(expected.helper_id),"Actual first unimplemented source helper %d"%i)
			check(actual.get("reason")=="requires_unimplemented_source_helper","Rejected branch has explicit source boundary %d"%i)
			check(not actual.has("record") and not actual.has("seed_a") and not actual.has("seed_b"),"Unfinished classification cannot commit partial source state %d"%i)
	check(callbacks.size()==5,"All five original callbacks finish on accepted contexts")
	check(accepted==2224 and rejected==836,"Accepted and gated populations are both covered")
	check(helpers.has(892) and helpers.has(893),"Actual special-port and naming gates both covered")
	check(rng_changes>0,"Actual warm-world random steps covered")
	var record:=PackedByteArray();record.resize(68);var before:=record.duplicate()
	for callback in [882,888,-1,0.5,"883",true,0x100000000]:
		check(classifier.classify(record,callback,1,0,0,0,0).is_empty(),"Invalid callback rejected")
	for position in range(5):
		for bad in [-1,0x100000000,0.5,"1",true,INF,NAN]:
			var args:Array=[1,0,0,0,0];args[position]=bad
			check(classifier.classify(record,883,args[0],args[1],args[2],args[3],args[4]).is_empty(),"Invalid unsigned32 field rejected")
	check(classifier.classify(PackedByteArray(),883,1,0,0,0,0).is_empty(),"Missing native record rejected")
	var short_record:=PackedByteArray();short_record.resize(67)
	check(classifier.classify(short_record,883,1,0,0,0,0).is_empty(),"Truncated native record rejected")
	check(record==before,"Invalid calls preserve storage")
	print("PLANETARY CLASSIFIER TESTS: %d checks, %d failures; %d native callback contexts (%d complete, %d gated)"%[checks,failures,cases.size(),accepted,rejected])
	quit(1 if failures else 0)
