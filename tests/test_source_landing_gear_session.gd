extends SceneTree
const Gear=preload("res://scripts/source_landing_gear_session.gd")
const Core=preload("res://scripts/source_landing_gear.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func encoded(gear:RefCounted)->String:return JSON.stringify(gear.snapshot())
func context(phase:int=0,speed:int=0,flight:int=0)->Dictionary:return {"flight_state_u8":flight,"autopilot_phase_u8":phase,"speed_s32":speed}
func callbacks(result:Dictionary,function:String)->Array:
	var found:Array=[]
	for callback:Dictionary in result.get("callbacks",[]):
		if callback.get("function")==function:found.append(callback)
	return found
func _initialize()->void:call_deferred("run")

func requests_and_physical_motion()->void:
	var gear:=Gear.new();check(not gear.state().initialized and not gear.restore({}),"Unconfigured state and present empty snapshot are not valid initialization")
	check(gear.configure(false),"Airborne legacy initialization configures retracted gear")
	var state:Dictionary=gear.state(context())
	check(state.position_u16==0 and state.retracted and not state.requested_down and state.f1014_raw_gear_flag and state.extension_fraction==0,"UP means rawE9bit2SET and physical9Ezero")
	check(state.status_text=="Убраны" and state.command_label=="Выпустить шасси" and state.can_toggle,"Model supplies short Russian console presentation")
	var caller:=context();var caller_before:=JSON.stringify(caller);var old:=encoded(gear)
	var no_op:Dictionary=gear.command_request(false,caller)
	check(no_op.ok and no_op.accepted and not no_op.changed and no_op.callbacks.is_empty() and encoded(gear)==old,"Idempotent request is explicit no-toggle adapter with no invented callbacks")
	var result:Dictionary=gear.command_request(true,caller)
	check(result.ok and result.accepted and gear.state().requested_down and not gear.state().f1014_raw_gear_flag and gear.state().position_u16==0,"Deployment changes only source request, preserving physical position until F1008")
	check(callbacks(result,"F262").size()==2 and callbacks(result,"F1116").size()==1 and callbacks(result,"F1906").size()==2,"Toggle observations preserve original GUI/refresh/sound requests")
	check(JSON.stringify(caller)==caller_before,"Gear commands never mutate caller autopilot/status/speed context")
	result=gear.advance_seconds(0.5,caller);state=gear.state(caller)
	check(result.ok and result.executed_steps==30 and state.position_u16==12420 and state.moving and not state.landing_ready,"Thirty fixed source steps animate physical deployment without a false touchdown-ready flag")
	check(state.status_text.begins_with("Выпуск ") and state.extension_fraction>0 and state.extension_fraction<1,"Model exposes animation progress separately from request")
	var middle:=gear.snapshot();result=gear.command_request(false,caller)
	check(result.ok and result.accepted and gear.state().position_u16==middle.position_u16,"Mid-animation reversal preserves physical travel already completed")
	check(gear.advance_seconds(0.1,caller).ok and gear.state().position_u16==12420-6*414 and gear.state().status_text.begins_with("Уборка "),"Reversed target moves toward retracted endpoint on exact source ticks")
	check(gear.advance_seconds(1.0,caller).ok and gear.state().retracted and not gear.state().moving,"Retraction saturates exactly at zero")
	check(gear.command_request(true,caller).accepted and gear.advance_seconds(2.65,caller).ok and gear.state().position_u16==65535 and gear.state().deployed and gear.state().landing_ready,"Deployment saturates exactly atFFFF, the source physical contact criterion")
	check(gear.configure(true) and gear.state().position_u16==65535 and not gear.state().f1014_raw_gear_flag,"Landed/docked migration default is fully deployed with rawbitCLEAR")
	var input:=gear.snapshot();input.control_flags_u8=0xa5;input.warning_flags_u16=0x8003
	check(gear.restore(input),"All source request/warning bits remain representable, not just the gear masks")
	result=gear.command_toggle(caller)
	check(result.ok and gear.snapshot().control_flags_u8==(0xa5^2) and gear.snapshot().warning_flags_u16==0x8001,"Source toggle preserves unrelated flags and clears only warningbit2")

func source_context_and_warning()->void:
	var gear:=Gear.new();check(gear.configure(true),"Source-phase command fixture configures")
	var before:=encoded(gear);var blocked:=context(0x24)
	var result:Dictionary=gear.command_toggle(blocked)
	check(result.ok and not result.accepted and not result.changed and encoded(gear)==before and not gear.state(blocked).can_toggle,"Only originalFF0x24 selected toggle restriction blocks the source command")
	check(callbacks(result,"F1906").size()==1 and callbacks(result,"F262").is_empty(),"Blocked source branch returns its original sound observation without fake toggle")
	check(gear.command_request(true,blocked).accepted and encoded(gear)==before,"Already-deployed automatic phone request stays idempotent even in blocked source phase")
	check(gear.configure(false) and gear.command_request(true,context()).accepted,"High-speed deployment fixture configures")
	result=gear.advance_seconds(1.0/60.0,context(0,99999))
	check(result.ok and result.message.is_empty() and not gear.state().warning_latched,"Source warning excludes signed speed99999")
	result=gear.advance_seconds(1.0/60.0,context(0,100000))
	check(result.ok and gear.state().warning_latched and result.message=="Шасси выпущены на высокой скорости. Рекомендуется убрать шасси." and callbacks(result,"F1097").size()==1,"Exact signed source threshold100000 latches warning without invented damage")
	var position:int=gear.state().position_u16;result=gear.advance_seconds(1.0/60.0,context(0,100000))
	check(result.ok and result.message.is_empty() and callbacks(result,"F1097").is_empty() and gear.state().position_u16>position,"Warning remains latched without blocking animation or repeating notifications")
	check(gear.command_toggle(context(0,100000)).accepted and not gear.state().warning_latched,"Manual source toggle clears warning and remains allowed at high speed")
	check(gear.configure(true),"Native automatic mode fixture configures")
	var automatic:=context(30,0,2);var automatic_before:=JSON.stringify(automatic)
	result=gear.advance_seconds(0.5,automatic)
	check(result.ok and gear.state().retract_requested and gear.state().position_u16<65535 and callbacks(result,"F1116").size()==30,"Actual kernel mode2/phase<=30 retracts and requests refresh on every virtual invocation")
	check(JSON.stringify(automatic)==automatic_before,"No source or phone autopilot phase is invented or broken by the model")
	result=gear.advance_seconds(1.0/60.0,context(31,0,2))
	check(result.ok and gear.state().requested_down and callbacks(result,"F1116").size()==1,"Actual kernel mode2/phase31 deploys by its verified original branch")
	check(gear.configure(false),"Independent neutral object-timer fixture configures")
	var timer:=gear.snapshot();timer.object_timer_u16=50000
	check(gear.restore(timer) and gear.command_request(true,context()).accepted,"Neutral objectE8 timer is saved explicitly")
	result=gear.advance_seconds(1.0/60.0,context())
	check(result.ok and gear.snapshot().object_timer_u16==50000-828 and gear.state().position_u16==414,"ObjectE8 is decremented but never misused as a gear-motion delay")

func cadence_restore_and_pause()->void:
	var snapshots:Array=[]
	for fps in [30,60,120]:
		var gear:=Gear.new();check(gear.configure(false) and gear.command_request(true,context()).accepted,"FPS partition source fixture configures")
		var steps:=0
		for _index in range(fps):
			var result:Dictionary=gear.advance_seconds(1.0/fps,context());check(result.ok,"Bounded physical frame is accepted")
			steps+=int(result.executed_steps)
		check(steps==60,"Exactly60virtualsourceupdates are independent of display FPS")
		snapshots.append(encoded(gear))
	check(snapshots[0]==snapshots[1] and snapshots[1]==snapshots[2],"30/60/120 batching preserves entire snapshot including physical9E, phase, request and rational tick carry")
	var gear:=Gear.new();check(gear.configure(false) and gear.command_request(true,context()).accepted,"Cold continuation fixture configures")
	check(gear.advance_seconds(0.3712345,context()).ok,"Fractional phase and partial animation advance")
	var stored:Dictionary=copy(gear.snapshot());var loaded:=Gear.new();check(loaded.restore(stored),"JSON snapshot restores mid-animation and both exact clock fields")
	var uninterrupted:Dictionary=gear.advance_seconds(0.6512345,context());var cold:Dictionary=loaded.advance_seconds(0.6512345,context())
	check(uninterrupted.ok and cold.ok and encoded(gear)==encoded(loaded) and JSON.stringify(uninterrupted)==JSON.stringify(cold),"Cold continuation preserves complete physical state and callback sequence exactly")
	var protected:=encoded(gear);var paused:=context();paused.paused=true
	check(gear.advance_seconds(3600,paused).ok and encoded(gear)==protected,"Paused host ignores elapsed wall-style interval without accumulating catchup")
	check(not gear.command_toggle(paused).accepted and encoded(gear)==protected,"Explicit paused host rejects new flight input without touching source state")
	check(gear.advance_seconds(0,context()).ok and encoded(gear)==protected,"Zero simulation time preserves every persisted bit")
	var result:Dictionary=gear.advance_seconds(1.0/60.0,context())
	check(result.ok and result.executed_steps==1,"Resume advances only new simulation time, never a paused interval")

func strict_domains_and_reference()->void:
	var gear:=Gear.new();check(gear.configure(false),"Strict source snapshot fixture configures")
	var snapshot:=gear.snapshot();var protected:=encoded(gear)
	for key in ["schema","source_contract","source_sha256","source_digest","host_policy"]:
		var bad:Dictionary=copy(snapshot);bad[key]="wrong"
		check(not gear.restore(bad) and encoded(gear)==protected,"Wrong source/schema contract rejects atomically: "+key)
	for key in ["version","position_u16","control_flags_u8","object_timer_u16","warning_flags_u16","frame_tick_remainder_raw"]:
		for value in [-1,4294967296,0.5,true]:
			var bad:Dictionary=copy(snapshot);bad[key]=value
			check(not gear.restore(bad) and encoded(gear)==protected,"Strict numeric source domain rejects "+key)
	for phase in ["", "000000000000f03f", "000000000000f87f", "000000000000f0bf", 0]:
		var bad:Dictionary=copy(snapshot);bad.phase_f64_hex=phase
		check(not gear.restore(bad) and encoded(gear)==protected,"Invalid F64fraction rejects without dropping animation history")
	var extra:Dictionary=copy(snapshot);extra.extra=0
	check(not gear.restore(extra) and not gear.restore({}) and encoded(gear)==protected,"Present empty or unknown-field snapshot cannot masquerade as missing old gear state")
	for invalid in [{},context(-1),context(256),{"flight_state_u8":0,"autopilot_phase_u8":0,"speed_s32":0.5}]:
		check(not gear.command_toggle(invalid).ok and not gear.advance_seconds(0.1,invalid).ok and encoded(gear)==protected,"Malformed caller context rejects before mutation")
	for elapsed in [NAN,INF,-1.0,10.0]:check(not gear.advance_seconds(elapsed,context()).ok and encoded(gear)==protected,"Invalid/over-budget interval rejects atomically")
	check(gear.command_request(true,context()).accepted,"Independent fixed-clock kernel reference configures")
	var raw:={"position_u16":0,"object_timer_u16":0,"autopilot_phase_u8":0,"flight_state_u8":0,"control_flags_u8":0,"warning_flags_u16":0,"speed_s32":0}
	var remainder:=0;var observed:Array=[]
	for _index in range(60):
		var total:=remainder+0x100000000;var ticks:int=total/(86400*60);remainder=total%(86400*60)
		var native:=Core.step(raw,ticks);raw=native.state;observed.append_array(native.callbacks)
	var result:Dictionary=gear.advance_seconds(1.0,context())
	check(result.ok and gear.snapshot().position_u16==raw.position_u16 and gear.snapshot().frame_tick_remainder_raw==remainder and result.callbacks==observed,"Host fixed60 carry and physical animation equal independently stepped proven source kernel")
	var detached:=gear.snapshot();detached.position_u16=0
	check(gear.snapshot().position_u16==raw.position_u16,"Returned snapshots do not expose live mutable state")
func identity_fastpath_reference()->void:
	for down in [false,true]:
		for fps in [30,60,120]:
			for warp in [1,100]:
				var fast:=Gear.new();check(fast.configure(down),"Identity reference endpoint configures")
				var initial:=fast.snapshot();initial.phase_f64_hex=Gear._float_hex(0.375);initial.frame_tick_remainder_raw=Gear.TICK_DENOMINATOR-1
				initial.control_flags_u8=int(initial.control_flags_u8)|0xa0;initial.warning_flags_u16=0x8002
				check(fast.restore(initial),"Identity reference preserves unrelated raw flags and carried phase")
				var slow:=Gear.new();check(slow.restore(initial),"Forced-slow reference starts with identical source snapshot")
				for _index in range(int(fps/30)):
					var quicker:Dictionary=fast._advance_seconds(float(warp)/fps,context(0,100000),true)
					var reference:Dictionary=slow._advance_seconds(float(warp)/fps,context(0,100000),false)
					check(quicker.ok and reference.ok and encoded(fast)==encoded(slow),"Endpoint fast/forced-slow complete snapshots match forFPS%d warp%d"%[fps,warp])
					check(JSON.stringify(quicker)==JSON.stringify(reference),"Endpoint fast/forced-slow callback/message/clock/presentation results match")
	for guard:String in ["timer","midtravel","new_warning","native_auto"]:
		var fast:=Gear.new();check(fast.configure(true),"Boundary guard fixture configures")
		var initial:=fast.snapshot();var current:=context()
		match guard:
			"timer":initial.object_timer_u16=50000
			"midtravel":initial.position_u16=12345
			"new_warning":current.speed_s32=100000
			"native_auto":current=context(30,0,2)
		check(fast.restore(initial),"Boundary guard raw snapshot restores")
		var slow:=Gear.new();check(slow.restore(initial),"Boundary guard slow reference restores")
		var quicker:Dictionary=fast._advance_seconds(1.0,current,true)
		var reference:Dictionary=slow._advance_seconds(1.0,current,false)
		check(quicker.ok and reference.ok and encoded(fast)==encoded(slow) and JSON.stringify(quicker)==JSON.stringify(reference),"Identity fastpath guard preserves all source observations: "+guard)

func run()->void:
	requests_and_physical_motion();source_context_and_warning();cadence_restore_and_pause();strict_domains_and_reference();identity_fastpath_reference()
	print("SOURCE LANDING GEAR SESSION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
