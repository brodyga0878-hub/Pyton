extends SceneTree
const Motion=preload("res://scripts/source_motion_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_motion_native.json"
const FIXTURE_SHA:="087eeb8f70ffcd70a489f3d37bbd96e468bca2c01cffca8a7646f4e680c53625"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<24:push_error(message)
func result_for(row:Dictionary)->Dictionary:
	var body:=str(row.initial_body_hex).hex_decode();var parent:=str(row.parent_hex).hex_decode()
	match int(row.operation):
		0:return Motion.set_thrust(body,row.command_s32,"maximum")
		1:return Motion.set_thrust(body,row.command_s32,"limited")
		2:return Motion.set_thrust(body,row.command_s32,"direction")
		3:return Motion.desired_acceleration(body,row.set_speed_s32)
		4:return Motion.velocity_step(body,row.ticks_u32,true)
		5:return Motion.velocity_step(body,row.ticks_u32,false)
		6,7:return Motion.manual_step(body,parent,row.ticks_u32,row.set_speed_s32,row.command_s32,int(row.operation)==7,row.days_u32)
	return {}
func different_bytes(actual:PackedByteArray,expected:PackedByteArray)->String:
	var changed:Array=[]
	for i in range(mini(actual.size(),expected.size())):
		if actual[i]!=expected[i]:changed.append("%x:%x/%x"%[i,actual[i],expected[i]])
	return str(changed.slice(0,12))
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent native fixture bytes remain pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.profile==Motion.PROFILE and fixture.case_count==fixture.cases.size() and fixture.case_count==1236,"Fixture covers the original fixed-frame motion core")
	check(fixture.fresh_process_runs==3 and fixture.reverse_case_count==1236 and fixture.body_and_bank_canaries_unchanged and fixture.parent_bank_unchanged,"Native controls are fresh-process/reverse-order/canary verified")
	var index:=0;var operations:Dictionary={}
	for row:Dictionary in fixture.cases:
		var result:=result_for(row);var label:="op%d case%d"%[int(row.operation),index]
		operations[int(row.operation)]=true
		check(not result.is_empty(),"Original motion result exists "+label)
		if result.is_empty():index+=1;continue
		var expected:=str(row.expected.body_hex).hex_decode()
		check(result.body==expected,"Entire338-byte result matches original instructions "+label+" "+different_bytes(result.body,expected))
		if int(row.operation) not in [4,5]:check(result.command_s32==PackedInt64Array(row.expected.command_s32),"Source command vector matches "+label)
		if int(row.operation) in [6,7]:
			check(result.fixed_parent_and_attitude and not result.complete_original_player_pipeline,"Fixed-frame scope is explicit "+label)
			var si:=Motion.decode_si(result.body)
			check(si.axes=="unaltered_source_world_axes" and si.position_metres.size()==3 and si.velocity_mps.size()==3,"Presentation boundary retains explicit source axes "+label)
			var engine:=Motion.new();var initial:=str(row.initial_body_hex).hex_decode();var parent:=str(row.parent_hex).hex_decode()
			check(engine.configure(initial,parent),"Raw motion state configures "+label)
			var frozen:=var_to_bytes(engine.snapshot());var saved:Dictionary=JSON.parse_string(JSON.stringify(engine.snapshot()))
			var restored:=Motion.new()
			check(restored.restore(saved) and restored.raw_body()==initial,"JSON save preserves integer/fraction bytes exactly "+label)
			var live:=engine.advance(row.ticks_u32,row.set_speed_s32,row.command_s32,int(row.operation)==7,row.days_u32)
			var resumed:=restored.advance(row.ticks_u32,row.set_speed_s32,row.command_s32,int(row.operation)==7,row.days_u32)
			check(not live.is_empty() and not resumed.is_empty() and engine.raw_body()==expected and restored.raw_body()==expected,"Source state advances identically after restore "+label)
			if row.has("follows_native_case"):
				var prior:Dictionary=fixture.cases[int(row.follows_native_case)]
				var sequential:=Motion.new();sequential.configure(str(prior.initial_body_hex).hex_decode(),str(prior.parent_hex).hex_decode())
				sequential.advance(prior.ticks_u32,prior.set_speed_s32,prior.command_s32,int(prior.operation)==7,prior.days_u32)
				sequential.advance(row.ticks_u32,row.set_speed_s32,row.command_s32,int(row.operation)==7,row.days_u32)
				check(sequential.raw_body()==expected,"Two dependent original steps preserve accumulated state "+label)
			check(initial.hex_encode()==str(row.initial_body_hex) and parent.hex_encode()==str(row.parent_hex),"Original body and parent inputs remain unchanged "+label)
		index+=1
	check(operations.size()==8,"All eight independently executed source entry/composition modes consumed")
	var engine:=Motion.new();var row:Dictionary=fixture.cases[-1]
	engine.configure(str(row.initial_body_hex).hex_decode(),str(row.parent_hex).hex_decode())
	var before:=var_to_bytes(engine.snapshot());var original:Dictionary=engine.snapshot()
	for value in [null,[],{},true,42]:check(not engine.restore(value) and var_to_bytes(engine.snapshot())==before,"Invalid state container rejects atomically")
	var invalid:Array=[]
	var bad:=original.duplicate(true);bad.version=true;invalid.append(bad)
	bad=original.duplicate(true);bad.profile="unknown";invalid.append(bad)
	bad=original.duplicate(true);bad.body_hex="g".repeat(676);invalid.append(bad)
	bad=original.duplicate(true);bad.parent_hex="00";invalid.append(bad)
	bad=original.duplicate(true);bad.extra="unexpected";invalid.append(bad)
	for value in invalid:check(not engine.restore(value) and var_to_bytes(engine.snapshot())==before,"Malformed raw state rejects without replacing live fractions")
	for ticks in [-1,true,NAN,INF,0x80000000]:check(engine.advance(ticks,0).is_empty() and var_to_bytes(engine.snapshot())==before,"Invalid signed physical timestep is atomic")
	var raw:=engine.raw_body();raw[0]=raw[0]^255
	check(var_to_bytes(engine.snapshot())==before,"Caller cannot mutate state through returned raw bytes")
	print("SOURCE MOTION PIPELINE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
