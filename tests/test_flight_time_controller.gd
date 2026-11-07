extends SceneTree
# Source timer instructions are checked against an independently executed ELF;
# scheduler checks verify elapsed time accounting and the modern safety policy.
const TimeController=preload("res://scripts/flight_time_controller.gd")
const Clock=preload("res://scripts/source_clock.gd")
const FIXTURE:="res://tests/fixtures/source_time_controls_native.json"
const FIXTURE_SHA:="f5d812f399f24490580f1907cbf4e9c78b71c39949203c57e2228128abea571b"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<25:push_error(message)
func near(a:float,b:float,epsilon:=1e-9)->bool:return absf(a-b)<=epsilon
func far()->Dictionary:
	return {"active":true,"menu_open":false,"busy":false,"paused":false,"source_world":true,"manual_input":false,"autopilot":false,"landing":false,"taking_off":false,"docked":false,"surface_active":false,"combat_active":false,"jump_remaining":0.0,"transfer_remaining":0.0,"station_available":false,"body_clearance_m":1e9,"speed_mps":600.0,"gravity_mps2":0.001}
func finish_all(timer:RefCounted,plan:Dictionary)->Dictionary:
	check(plan.ok,"Scheduler accepts a valid frame")
	check(plan.steps.size()<=TimeController.MAX_SUBSTEPS,"Frame has bounded work")
	var total:=0.0
	for value in plan.steps:
		check(value>0 and value<=0.100000000001 and is_finite(value),"Every physical substep is finite, positive and at most0.1s")
		total+=value
	var result:Dictionary=timer.finish_frame(plan.token,plan.steps.size())
	check(result.ok and near(result.advanced_seconds,total),"Acknowledgement accounts only the actually executed step sequence")
	return result
func native_controls()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent native fixture identity is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.case_count==1736 and fixture.fresh_process_runs==3 and fixture.guards_unchanged,"Original time controls were executed independently with fresh/reverse/guard checks")
	for row:Dictionary in fixture.cases:
		var initial:Dictionary={}
		for index in range(TimeController.STATE_NAMES.size()):initial[TimeController.STATE_NAMES[index]]=row.initial[index]
		initial.last_timestamp=(int(row.timestamp)-int(row.elapsed_ms))&TimeController.MASK
		var before:=var_to_bytes(initial)
		var result:Dictionary=TimeController.source_control(row.operation,row.action,row.player_mode,initial,row.elapsed_ms,row.timestamp)
		check(not result.is_empty(),"Source timer control accepts its native input")
		for key in TimeController.STATE_NAMES:check(int(result.get(key,-1))==int(row.result[key]),"Source time matches actual instruction result "+str(key))
		check(var_to_bytes(initial)==before,"Source time helpers never mutate the caller's state")
	var normal:=TimeController.source_timer_delta(1000,994,0)
	check(normal.increment_u32==49700,"Source normal timer is49700ticks/sec, not display49710 or nominal-day SI")
	check(TimeController.source_timer_delta(1000,994,0xffffffff).counter_u32==49699,"Source timer counter wraps exactly at32bits")
	check(TimeController.source_timer_delta(0x7fffffff,0xffffffff,0).is_empty(),"Original unsigned DIV overflow domain is refused before multiplication")
	for bad in [true,-1,1.5,NAN,INF,"20",null]:check(TimeController.source_timer_delta(bad,994,0).is_empty(),"Invalid elapsed raw timer input rejects")

func frame_rates_and_clocks()->void:
	for rate in [1,10,100]:
		for fps in [30,60,120]:
			var timer:=TimeController.new();check(timer.request_rate(rate),"Implemented source-labelled rate is selectable")
			var total:=0.0;var wall:=0.0;var expected_rate:int=10 if rate==100 and fps==30 else int(rate)
			for frame in range(fps*2):
				var delta:=1.0/float(fps);wall+=delta
				var plan:Dictionary=timer.plan_frame(delta,far())
				check(plan.effective_rate==expected_rate,"Effective rate follows explicit work budget at%dHz"%fps)
				if rate==1:check(plan.steps.size()==1 and plan.steps[0]==delta,"Ordinary legacy-sized1x frame preserves its exact dt")
				var result:=finish_all(timer,plan);total+=float(result.advanced_seconds)
				check(near(float(result.pending_real_seconds),0),"Ordinary frame cadence leaves no hidden wall-time debt")
			check(near(total,wall*expected_rate,1e-8),"No real seconds disappear at the selected effective rate")
			var actual:=Clock.from_elapsed_days(total/86400.0);var expected:=Clock.from_elapsed_days(2.0*expected_rate/86400.0)
			check(actual.day_u32==expected.day_u32 and absi(int(actual.tick_u32)-int(expected.tick_u32))<=1,"Calendar and ephemeris clock derive from the same actual simulated interval")
	var timer:=TimeController.new();var sum:=0.0
	for delta in [0.004,0.036,0.005,0.055,0.1,0.003,0.097]:
		var plan:=timer.plan_frame(delta,far());sum+=float(finish_all(timer,plan).advanced_seconds)
	check(near(sum,0.3),"Jittered1x frame sequence conserves all supplied time")
	var day:=0.499999
	var plan:=timer.plan_frame(0.2,far());day+=float(finish_all(timer,plan).advanced_seconds)/86400.0
	var clock:=Clock.from_elapsed_days(day)
	check(clock.day_u32==Clock.EPOCH_DAY_U32+1 and clock.tick_u32<100000,"A bounded sequence crosses the original half-day epoch rollover correctly")

func safety_and_interruption()->void:
	var timer:=TimeController.new();var context:=far();var original:=var_to_bytes(context)
	var options:=timer.rate_options(context)
	check(options.size()==5 and options[0].enabled and options[1].enabled and options[2].enabled,"All five original-labelled levels are described; implemented levels are enabled in safe space")
	check(not options[3].supported and not options[3].enabled and not options[4].supported and not options[4].reason.is_empty(),"Unsafe unimplemented1000/10000 levels have truthful unavailable reasons")
	check(not timer.request_rate(1000) and timer.requested_rate==1,"A disabled high level cannot be selected programmatically")
	check(var_to_bytes(context)==original,"Safety and option queries preserve caller context")
	for key in ["manual_input","autopilot","landing","taking_off","docked","surface_active","combat_active"]:
		context=far();context[key]=true;timer.reset();timer.request_rate(100)
		var plan:=timer.plan_frame(0.02,context)
		check(plan.effective_rate==1 and timer.requested_rate==1,"Safety event returns to explicit normal time: "+key)
		finish_all(timer,plan)
	for key in ["jump_remaining","transfer_remaining"]:
		context=far();context[key]=0.001;timer.reset();timer.request_rate(100)
		var plan:=timer.plan_frame(0.02,context)
		check(plan.effective_rate==1,"Pending transition uses unaccelerated charge time: "+key);finish_all(timer,plan)
	for key in ["active","paused","menu_open","busy"]:
		context=far();context[key]=false if key=="active" else true;timer.reset();timer.request_rate(100)
		var plan:=timer.plan_frame(0.02,context)
		check(plan.steps.is_empty() and plan.effective_rate==0 and plan.blocked_real_seconds==0.02,"Modal/lifecycle pause contributes no simulation time: "+key)
		check(timer.finish_frame(plan.token,0).ok,"Empty paused plans are safely acknowledged")
	context=far();var envelope:=float(context.speed_mps)*10+float(context.gravity_mps2)*50
	context.body_clearance_m=TimeController.MIN_BODY_CLEARANCE_10_M+envelope-0.01
	check(TimeController.safety_limit(context).rate==1,"Actual body safety envelope boundary caps to1x")
	context.body_clearance_m+=0.01
	check(TimeController.safety_limit(context).rate==10,"Exact safe10x threshold is deterministic")
	context=far();context.station_available=true;context.station_distance_m=TimeController.MIN_STATION_DISTANCE_10_M+envelope-0.01
	check(not timer.can_continue(10,context) and timer.can_continue(1,context),"Crossing the station boundary interrupts an accelerated sequence while allowing ordinary flight")
	context.station_distance_m=TimeController.MIN_STATION_DISTANCE_100_M+envelope
	check(timer.can_continue(100,context),"Far station can admit100x under the explicit conservative profile")
	context=far();context.erase("body_clearance_m")
	check(TimeController.safety_limit(context).rate==1,"Missing distance data fails closed to ordinary speed")
	context=far();context.gravity_mps2=NAN
	check(TimeController.safety_limit(context).rate==0,"Malformed physical telemetry cannot advance time")
	context=far();context.source_world=false
	check(TimeController.safety_limit(context).rate==1,"Legacy worlds never inherit source acceleration")
	timer.reset();timer.request_rate(100)
	var plan:=timer.plan_frame(0.02,far());var executed:=5
	var partial:=timer.finish_frame(plan.token,executed,true)
	check(near(partial.advanced_seconds,0.5) and near(partial.consumed_real_seconds,0.005),"Interrupted sequence advances only its five genuinely executed0.1s steps")
	check(near(partial.discarded_pending_real_seconds,0.015) and timer.pending_real_seconds==0 and timer.requested_rate==1,"Safety interruption explicitly cancels unprocessed wall budget without hidden catchup")
	plan=timer.plan_frame(1.0/60.0,far())
	check(plan.effective_rate==1 and near(float(finish_all(timer,plan).advanced_seconds),1.0/60.0),"After an interruption resuming cannot secretly accelerate")

func backlog_and_transactions()->void:
	var timer:=TimeController.new();var plan:=timer.plan_frame(5.0,far())
	check(plan.steps.size()==32 and near(plan.advanced_seconds,3.2),"Long active frame cannot exceed the bounded32-step budget")
	check(not timer.plan_frame(1.0,far()).ok,"Unacknowledged plan cannot duplicate the incoming frame")
	check(not timer.finish_frame(plan.token+1,1).ok and not timer.finish_frame(plan.token,true).ok,"Wrong token and boolean count reject without settling real time")
	var result:=finish_all(timer,plan)
	check(near(result.pending_real_seconds,1.8),"Real time not processed by the budget remains explicit unscaled debt")
	plan=timer.plan_frame(0.0,far());var rest:=finish_all(timer,plan)
	check(near(result.advanced_seconds+rest.advanced_seconds,5.0) and timer.pending_real_seconds==0,"A later budget consumes exactly the remaining wall interval, once")
	plan=timer.plan_frame(5.0,far());finish_all(timer,plan)
	var blocked:=far();blocked.paused=true
	plan=timer.plan_frame(1.0,blocked)
	check(plan.steps.is_empty() and near(plan.discarded_pending_real_seconds,1.8) and plan.blocked_real_seconds==1.0,"Explicit pause reports discarded backlog and blocked wall time separately")
	plan=timer.plan_frame(0.02,far());result=finish_all(timer,plan)
	check(near(result.advanced_seconds,0.02),"Pause/resume never replays the discarded lag interval")
	timer.reset();plan=timer.plan_frame(5.0,far());finish_all(timer,plan)
	var manual:=far();manual.manual_input=true
	plan=timer.plan_frame(0.02,manual);result=finish_all(timer,plan)
	check(near(result.advanced_seconds,0.02) and near(result.discarded_pending_real_seconds,1.8),"Fresh steering never applies retroactively to old real-time debt")
	timer.reset();plan=timer.plan_frame(0.2,far());var first:float=plan.steps[0];plan.steps[0]=25.0
	result=timer.finish_frame(plan.token,1,true)
	check(near(result.advanced_seconds,first),"Mutating the returned step array cannot alter the controller's acknowledgement record")
	for bad in [NAN,INF,-1.0,true,"1",null,3600.1]:
		var before:=var_to_bytes(timer.snapshot())
		check(not timer.plan_frame(bad,far()).ok and before==var_to_bytes(timer.snapshot()),"Invalid frame interval rejects atomically")

func persistence()->void:
	var timer:=TimeController.new();timer.request_rate(10)
	var state:Dictionary=JSON.parse_string(JSON.stringify(timer.snapshot()))
	var copy:=TimeController.new()
	check(copy.restore(state) and copy.requested_rate==10 and copy.pending_real_seconds==0,"Session UI preference restores without replaying real wall-time debt")
	for field in ["schema","version","contract","requested_rate"]:
		var bad:Dictionary=state.duplicate();bad.erase(field)
		var before:=var_to_bytes(copy.snapshot())
		check(not copy.restore(bad) and before==var_to_bytes(copy.snapshot()),"Missing session field rejects atomically: "+field)
	for bad_rate in [1000,10000,0,2,true,NAN,1.5,"10",null]:
		var bad:Dictionary=state.duplicate();bad.requested_rate=bad_rate
		check(not copy.restore(bad) and copy.requested_rate==10,"Invalid/unsupported saved rate cannot enable unsafe acceleration")
	var old:=copy.plan_frame(0.02,far());copy.reset()
	var current:=copy.plan_frame(0.03,far())
	check(current.token>old.token and not copy.finish_frame(old.token,old.steps.size()).ok,"A pre-reset token cannot settle a different post-reset plan")
	finish_all(copy,current)
	old=copy.plan_frame(0.02,far());check(copy.restore(state),"Valid session restore can reset a pending frame transaction")
	current=copy.plan_frame(0.03,far())
	check(current.token>old.token and not copy.finish_frame(old.token,old.steps.size()).ok,"A pre-restore token cannot acknowledge a new plan with an aliased token")
	finish_all(copy,current)

func run()->void:
	native_controls();frame_rates_and_clocks();safety_and_interruption();backlog_and_transactions();persistence()
	print("FLIGHT TIME CONTROLLER TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
