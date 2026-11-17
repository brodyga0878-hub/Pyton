extends SceneTree
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_clock_pipeline_native.json"
const FIXTURE_SHA:="88ea9774bef2a5a36dc2f4011f5c59b1c8f44ca382b8ade21df4906120ddfc62"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<24:push_error(message)
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Original DOS clock control bank is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.get("schema")=="starfrontier-source-clock-pipeline-native-v1" and fixture.cases.size()>0,"Native original main-loop admission fixture exists")
	var covered_events:Dictionary={}
	for row:Dictionary in fixture.cases:
		var before:=JSON.stringify(row.initial)
		var result:=Clock.consume(row.initial)
		check(result.ok,"Original clock state admitted "+str(row.id))
		if not result.ok:continue
		check(Clock._hash(result.state_after)==Clock._hash(row.result.state_after),"Every raw clock/counter word matches original native instructions "+str(row.id))
		check(Clock._hash({"events":result.events})==Clock._hash({"events":row.result.events}),"Original callback admission order and parameters match "+str(row.id))
		check(JSON.stringify(row.initial)==before,"Clock arithmetic never mutates caller-owned state "+str(row.id))
		check(not result.event_effects_applied and not result.F1418_executed and not result.full_world_event_dispatch_executed and not result.jjffe_groundhog_fix_applied,"Original counter admission retains bounded callback and scheduler scope")
		for event:Dictionary in result.events:covered_events[int(event.event_u32)]=true
	check(covered_events.has(0x15) and covered_events.has(0x10) and covered_events.has(0x0f),"Actual native bank covers rollback, weekly and daily admissions")
	var initial:Dictionary=fixture.cases[0].initial.duplicate(true)
	initial.deadline_day_u32=0xffffffff;initial.clock_day_u32=28;initial.clock_low_u32=0xfffffff0;initial.accelerated_counter_u32=0
	var live:=Clock.new()
	check(live.configure(initial),"Raw owner starts from explicit source clock words")
	var frozen:=Clock._hash(live.snapshot())
	var staged:=live.prepare(100,49700)
	check(staged.ok and Clock._hash(live.snapshot())==frozen,"Counter delivery prepares a private candidate without consuming live time")
	check(staged.candidate_clock.raw_state().clock_day_u32==29 and staged.events==[{"event_u32":15,"param_u32":0}],"A real raw-day crossing retains its admitted daily event")
	var candidate_snapshot:Dictionary=JSON.parse_string(JSON.stringify(staged.candidate_clock.snapshot()))
	var cold:=Clock.new()
	check(cold.restore(candidate_snapshot) and Clock._hash(cold.snapshot())==Clock._hash(staged.candidate_clock.snapshot()),"Cold JSON restore retains all nine unsigned32 words and last admission witness")
	check(live.commit(staged) and Clock._hash(live.snapshot())==Clock._hash(cold.snapshot()),"Atomic commit publishes exactly the staged raw state")
	frozen=Clock._hash(live.snapshot())
	check(not live.commit(staged) and Clock._hash(live.snapshot())==frozen,"Duplicate frame commit cannot consume time or admit callbacks twice")
	var next_live:=live.prepare(49700,49700)
	var next_cold:=cold.prepare(49700,49700)
	check(next_live.ok and next_cold.ok and Clock._hash(next_live.candidate_clock.snapshot())==Clock._hash(next_cold.candidate_clock.snapshot()),"Following actual counter delivery is bit-identical after cold restore")
	var exposed:=live.raw_state();exposed.clock_low_u32=0
	var exposed_save:=live.snapshot();exposed_save.state.clock_day_u32=0
	check(Clock._hash(live.snapshot())==frozen,"Returned raw state and save cannot mutate the owner")
	for invalid:Variant in [null,true,[],{},1,"raw",NAN,INF]:
		check(not Clock.consume(invalid).ok and not live.configure(invalid) and not live.restore(invalid) and Clock._hash(live.snapshot())==frozen,"Malformed state containers reject atomically")
	for bad_value:Variant in [-1,true,1.25,0x100000000,NAN,INF,"0"]:
		var bad:=initial.duplicate(true);bad.clock_low_u32=bad_value
		check(not Clock.consume(bad).ok and not live.configure(bad) and not live.prepare(bad_value,0).ok and not live.prepare(0,bad_value).ok and Clock._hash(live.snapshot())==frozen,"Invalid raw words and delivered counters never modify live state")
	var bad_state:=initial.duplicate(true);bad_state.erase("frame_ticks_u32")
	check(not Clock.consume(bad_state).ok,"Missing raw word is not silently initialized")
	bad_state=initial.duplicate(true);bad_state.extra=0
	check(not Clock.consume(bad_state).ok,"Unknown raw state field rejects")
	check(not live.configure(initial,"jjffe-fixed") and Clock._hash(live.snapshot())==frozen,"A JJFFE timer/deadline variant cannot silently replace uploaded DOS semantics")
	for key:String in ["version","profile","generation","state","last_witness","snapshot_sha256"]:
		var corrupt:=live.snapshot()
		match key:
			"version":corrupt.version=true
			"profile":corrupt.profile="jjffe-fixed"
			"generation":corrupt.generation=0
			"state":corrupt.state.clock_low_u32=(int(corrupt.state.clock_low_u32)+1)&0xffffffff
			"last_witness":corrupt.last_witness.events=[]
			"snapshot_sha256":corrupt.snapshot_sha256="0".repeat(64)
		check(not live.restore(corrupt) and Clock._hash(live.snapshot())==frozen,"Corrupted cold snapshot rejects atomically: "+key)
	var forged:=live.snapshot();forged.state.clock_low_u32=(int(forged.state.clock_low_u32)+1)&0xffffffff
	var unsigned:=forged.duplicate(true);unsigned.erase("snapshot_sha256");forged.snapshot_sha256=Clock._hash(unsigned)
	check(not live.restore(forged) and Clock._hash(live.snapshot())==frozen,"Rehashed incompatible state still fails native admission replay")
	var wrong:=live.prepare(1,1);wrong.events=[]
	# The next frame usually admits no event; alter its private candidate receipt
	# explicitly so equality cannot accidentally pass for an empty callback list.
	wrong.receipt.accelerated_delivery_u32=2
	check(not live.commit(wrong) and Clock._hash(live.snapshot())==frozen,"A replaced event receipt cannot commit a different raw candidate")
	var reset_owner:=Clock.new();reset_owner.configure(initial)
	var before_reset:=reset_owner.prepare(100,0)
	reset_owner.configure(initial)
	check(not reset_owner.commit(before_reset),"Identical reconfigure still invalidates a previously staged delivery")
	var before_load:=reset_owner.prepare(100,0);var same_save:=reset_owner.snapshot()
	check(reset_owner.restore(same_save) and not reset_owner.commit(before_load),"Loading identical portable words cannot revive old wall-counter delivery")
	var other_owner:=Clock.new();other_owner.configure(initial)
	var owner_bound:=reset_owner.prepare(100,0)
	check(not other_owner.commit(owner_bound) and Clock._hash(other_owner.raw_state())==Clock._hash(initial),"Same-valued owners cannot consume one another's prepared delivery")
	var wrong_profile:=reset_owner.prepare(100,0);wrong_profile.profile="jjffe-fixed"
	check(not reset_owner.commit(wrong_profile),"The prepared envelope cannot change the source ABI profile")
	var report_sources:Dictionary={}
	for path:String in ["scripts/source_clock_pipeline.gd","scripts/source_clock.gd","tests/test_source_clock_pipeline.gd","tests/fixtures/source_clock_pipeline_native.json"]:report_sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var file:=FileAccess.open("res://build/source-clock-pipeline-tests.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":report_sources,"native_cases":fixture.cases.size(),"scope":"Uploaded DOS main-loop counter admission, raw32-bit carry/wrap/deadline and original event21/16/15 ordering; independent original instructions with callback recorders. Stateful private counter delivery, exactly-once publication and bounded replay-validated cold state. No F1418 millisecond collector, event effects, complete world scheduler, actual Main or Android claim."},"\t"));file.close()
	print("SOURCE CLOCK PIPELINE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
