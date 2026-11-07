extends RefCounted
# A bounded nominal-SI scheduler for the rebuilt flight controller. Original
# timer controls below have independent native references; the modern safety
# policy is explicit and does not claim to be the original FFE integrator.
const SourceClock=preload("res://scripts/source_clock.gd")
const CONTRACT:="bounded-nominal-si-flight-time-v1"
const SCHEMA:="starfrontier-flight-time-session-v1"
const SOURCE_ASM_SHA256:="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a"
const RATES:=[1,10,100,1000,10000]
const SOURCE_TIMERS:=[994,9942,99420,994200,9942000]
const SOURCE_SHIFTS:=[0,3,7,10,12]
const STATE_NAMES:=["temporary_timer","temporary_shift","timer","shift","clock_low","frame_step","accelerated_counter","system_counter","last_action","button_image","button_index","last_timestamp"]
const MASK:=0xffffffff
const MAX_SUBSTEPS:=32
const MAX_STEP_SECONDS:=0.1
const MAX_IMPLEMENTED_RATE:=100
const MAX_BACKLOG_REAL_SECONDS:=3600.0
const MIN_BODY_CLEARANCE_10_M:=10000.0
const MIN_BODY_CLEARANCE_100_M:=100000.0
const MIN_STATION_DISTANCE_10_M:=20000.0
const MIN_STATION_DISTANCE_100_M:=200000.0
const BOOLEAN_KEYS:=["active","menu_open","busy","paused","source_world","manual_input","autopilot","landing","taking_off","docked","surface_active","combat_active","station_available","atmospheric_hazard"]
const NONNEGATIVE_KEYS:=["speed_mps","gravity_mps2","jump_remaining","transfer_remaining"]
var requested_rate:=1
var effective_rate:=1
var pending_real_seconds:=0.0
var last_reason:=""
var _token:=0
var _plan:Dictionary={}

static func _number(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value))

static func _whole(value:Variant,minimum:int,maximum:int)->bool:
	return _number(value) and float(value)>=minimum and float(value)<=maximum and float(value)==floorf(float(value))

static func _context_valid(context:Dictionary)->bool:
	for key in BOOLEAN_KEYS:
		if context.has(key) and not context[key] is bool:return false
	for key in NONNEGATIVE_KEYS:
		if context.has(key) and (not _number(context[key]) or float(context[key])<0):return false
	for key in ["body_clearance_m","station_distance_m"]:
		if context.has(key) and not _number(context[key]):return false
	return true

static func safety_limit(context:Dictionary)->Dictionary:
	if not _context_valid(context):return {"rate":0,"reason":"Неверные данные времени или безопасности.","code":"invalid_context"}
	if not bool(context.get("active",true)):return {"rate":0,"reason":"Приложение неактивно.","code":"inactive"}
	for key in ["paused","menu_open","busy"]:
		if bool(context.get(key,false)):return {"rate":0,"reason":"Симуляция приостановлена.","code":key}
	if bool(context.get("atmospheric_hazard",false)):
		return {"rate":1,"reason":"В атмосфере или при опасном нагреве доступно обычное время.","code":"atmospheric_hazard"}
	for key in ["manual_input","autopilot","landing","taking_off","docked","surface_active","combat_active"]:
		if bool(context.get(key,false)):return {"rate":1,"reason":"Управление, сближение или контакт требуют обычного времени.","code":key}
	for key in ["jump_remaining","transfer_remaining"]:
		if float(context.get(key,0.0))>0:return {"rate":1,"reason":"Переход выполняется в обычном времени.","code":key}
	if not bool(context.get("source_world",false)):return {"rate":1,"reason":"Прежний режим полёта сохраняет обычное время.","code":"legacy"}
	for key in ["body_clearance_m","speed_mps","gravity_mps2","station_available"]:
		if not context.has(key):return {"rate":1,"reason":"Недостаточно данных для безопасного ускорения.","code":"missing_safety_data"}
	var speed:=float(context.speed_mps);var gravity:=float(context.gravity_mps2)
	# Conservative ten-simulated-second movement envelope, evaluated again by
	# the caller after each executed substep. This is a mobile policy, not F208.
	var envelope:=speed*10.0+gravity*50.0
	if not is_finite(envelope):return {"rate":1,"reason":"Невозможно оценить безопасное сближение.","code":"invalid_envelope"}
	var clearance:=float(context.body_clearance_m)
	if clearance<MIN_BODY_CLEARANCE_10_M+envelope:return {"rate":1,"reason":"Слишком близко к поверхности.","code":"near_surface"}
	var maximum:=MAX_IMPLEMENTED_RATE
	if clearance<MIN_BODY_CLEARANCE_100_M+envelope:maximum=10
	if bool(context.station_available):
		if not context.has("station_distance_m"):return {"rate":1,"reason":"Расстояние до станции неизвестно.","code":"missing_station_distance"}
		var distance:=float(context.station_distance_m)
		if distance<MIN_STATION_DISTANCE_10_M+envelope:return {"rate":1,"reason":"Слишком близко к станции.","code":"near_station"}
		if distance<MIN_STATION_DISTANCE_100_M+envelope:maximum=10
	return {"rate":maximum,"reason":"" if maximum==100 else "В этой области доступно ускорение до ×10.","code":"clear" if maximum==100 else "limited_clearance"}

func rate_options(context:Dictionary={})->Array:
	var limit:=safety_limit(context);var result:Array=[]
	for index in range(RATES.size()):
		var rate:int=RATES[index];var supported:=rate<=MAX_IMPLEMENTED_RATE
		var reason:="Ускорение выше ×100 в этой сборке пока недоступно." if not supported else str(limit.reason)
		result.append({"rate":rate,"label":"×%d"%rate,"source_timer_u32":SOURCE_TIMERS[index],"source_shift":SOURCE_SHIFTS[index],"supported":supported,"enabled":supported and rate<=int(limit.rate),"reason":reason})
	return result

func request_rate(value:Variant)->bool:
	if not _whole(value,1,MAX_IMPLEMENTED_RATE) or not int(value) in RATES:
		last_reason="Эта ступень ускорения пока недоступна.";return false
	requested_rate=int(value);return true

func reset()->void:
	# Tokens remain monotonic for this controller instance. Reusing token1
	# after reset/restore would allow an old frame to acknowledge a new plan.
	requested_rate=1;effective_rate=1;pending_real_seconds=0;last_reason="";_plan.clear()

func interrupt(reason:="Обычное время.")->Dictionary:
	# A pending transaction must first acknowledge actually executed steps.
	if not _plan.is_empty():return {"ok":false,"reason":"Сначала завершите текущий план времени."}
	var discarded:=pending_real_seconds
	pending_real_seconds=0;requested_rate=1;effective_rate=1;last_reason=reason
	return {"ok":true,"discarded_pending_real_seconds":discarded}

func can_continue(rate:Variant,context:Dictionary)->bool:
	if not _whole(rate,1,MAX_IMPLEMENTED_RATE) or not int(rate) in RATES:return false
	return int(safety_limit(context).rate)>=int(rate)

func plan_frame(real_dt:Variant,context:Dictionary)->Dictionary:
	if not _plan.is_empty():return {"ok":false,"steps":PackedFloat64Array(),"reason":"Предыдущий план времени не завершён."}
	if not _number(real_dt) or float(real_dt)<0 or float(real_dt)>MAX_BACKLOG_REAL_SECONDS or pending_real_seconds+float(real_dt)>MAX_BACKLOG_REAL_SECONDS:
		return {"ok":false,"steps":PackedFloat64Array(),"reason":"Неверный или чрезмерный интервал кадра."}
	var limit:=safety_limit(context);var input_seconds:=float(real_dt)
	if int(limit.rate)==0:
		var discarded:=pending_real_seconds
		pending_real_seconds=0;requested_rate=1;effective_rate=0;last_reason=str(limit.reason)
		return {"ok":true,"token":0,"steps":PackedFloat64Array(),"requested_rate":1,"effective_rate":0,"advanced_seconds":0.0,"planned_real_seconds":0.0,"blocked_real_seconds":input_seconds,"pending_real_seconds":0.0,"discarded_pending_real_seconds":discarded,"reason":last_reason,"reason_code":limit.code}
	var reason:=str(limit.reason);var reason_code:=str(limit.code)
	# Proximity/manual/transition events require a new explicit acceleration
	# selection after the danger clears; no automatic hidden reacceleration.
	var dropped_rate:=requested_rate>int(limit.rate)
	var discarded_before:=0.0
	if dropped_rate or (int(limit.rate)==1 and str(limit.code)!="legacy"):
		# A fresh manoeuvre must not apply new stick input retroactively to an
		# old wall-time debt. Safety cancellation is reported, never hidden.
		discarded_before=pending_real_seconds;pending_real_seconds=0
	if dropped_rate:requested_rate=1
	var available:=pending_real_seconds+input_seconds
	var rate:=requested_rate
	var capacity:=MAX_SUBSTEPS*MAX_STEP_SECONDS
	if available*rate>capacity+1e-12:
		for candidate in [100,10,1]:
			if candidate<=rate and available*float(candidate)<=capacity+1e-12:rate=candidate;break
		if available*rate>capacity+1e-12:rate=1
		reason="Скорость ограничена бюджетом безопасных подшагов.";reason_code="step_budget"
	var advanced:=minf(available*rate,capacity)
	var steps:=PackedFloat64Array()
	if advanced>0:
		var count:=mini(MAX_SUBSTEPS,maxi(1,ceili(advanced/MAX_STEP_SECONDS-1e-12)))
		var step:=advanced/float(count)
		for index in range(count):steps.append(step)
	effective_rate=rate;last_reason=reason
	if steps.is_empty():return {"ok":true,"token":0,"steps":steps,"requested_rate":requested_rate,"effective_rate":rate,"advanced_seconds":0.0,"planned_real_seconds":0.0,"pending_real_seconds":pending_real_seconds,"discarded_pending_real_seconds":discarded_before,"reason":reason,"reason_code":reason_code}
	_token+=1
	_plan={"token":_token,"rate":rate,"steps":steps.duplicate(),"available_real_seconds":available,"input_real_seconds":input_seconds,"pending_real_before":pending_real_seconds,"discarded_before":discarded_before}
	return {"ok":true,"token":_token,"steps":steps,"requested_rate":requested_rate,"effective_rate":rate,"advanced_seconds":advanced,"planned_real_seconds":advanced/float(rate),"pending_real_seconds":maxf(0,available-advanced/float(rate)),"discarded_pending_real_seconds":discarded_before,"reason":reason,"reason_code":reason_code}

func finish_frame(token:Variant,executed_steps:Variant,interrupted:=false)->Dictionary:
	if _plan.is_empty():
		if token is int and token==0 and _whole(executed_steps,0,0):return {"ok":true,"advanced_seconds":0.0,"consumed_real_seconds":0.0,"pending_real_seconds":pending_real_seconds,"discarded_pending_real_seconds":0.0}
		return {"ok":false}
	if not token is int or token!=int(_plan.token) or not _whole(executed_steps,0,_plan.steps.size()):return {"ok":false}
	var advanced:=0.0
	for index in range(int(executed_steps)):advanced+=float(_plan.steps[index])
	var consumed:=advanced/float(_plan.rate)
	pending_real_seconds=maxf(0,float(_plan.available_real_seconds)-consumed)
	if pending_real_seconds<1e-12:pending_real_seconds=0
	var discarded:=float(_plan.discarded_before)
	if interrupted:
		discarded+=pending_real_seconds;pending_real_seconds=0;requested_rate=1;effective_rate=1
		last_reason="Ускорение остановлено из-за изменения условий полёта."
	_plan.clear()
	return {"ok":true,"advanced_seconds":advanced,"consumed_real_seconds":consumed,"pending_real_seconds":pending_real_seconds,"discarded_pending_real_seconds":discarded}

func snapshot()->Dictionary:
	# Only the requested UI rate is portable; unprocessed real wall time and
	# in-flight plans are session state, never game progress to replay on load.
	return {"schema":SCHEMA,"version":1,"contract":CONTRACT,"requested_rate":requested_rate}

func restore(value:Variant)->bool:
	if not value is Dictionary or value.size()!=4 or value.get("schema")!=SCHEMA or not _whole(value.get("version"),1,1) or value.get("contract")!=CONTRACT or not _whole(value.get("requested_rate"),1,MAX_IMPLEMENTED_RATE) or not int(value.requested_rate) in RATES:return false
	reset();requested_rate=int(value.requested_rate);return true

@warning_ignore("integer_division")
static func source_timer_delta(milliseconds:Variant,timer:Variant,counter:Variant)->Dictionary:
	if not _whole(milliseconds,0,0x7fffffff) or not _whole(timer,0,MASK) or not _whole(counter,0,MASK):return {}
	# F1418 unsigned DIV requires a32-bit quotient. Refuse the exact overflow
	# domain before multiplying, rather than silently wrapping its quotient.
	if int(timer)>0 and int(milliseconds)>85899345919/int(timer):return {}
	var increment:int=int(milliseconds)*int(timer)/20
	return {"increment_u32":increment,"counter_u32":(int(counter)+increment)&MASK}

static func source_control(operation:Variant,action:Variant,player_mode:Variant,initial:Variant,milliseconds:Variant,timestamp:Variant)->Dictionary:
	if not _whole(operation,0,3) or not _whole(action,0,MASK) or not _whole(player_mode,0,255) or not _whole(timestamp,0,MASK) or not _whole(milliseconds,0,0x7fffffff) or not initial is Dictionary or initial.size()!=STATE_NAMES.size():return {}
	for key in STATE_NAMES:
		if not initial.has(key) or not _whole(initial[key],0,MASK):return {}
	var state:Dictionary=initial.duplicate()
	if int(operation)==3:
		var system:=source_timer_delta(milliseconds,994,state.system_counter)
		var accelerated:=source_timer_delta(milliseconds,state.timer,state.accelerated_counter)
		if system.is_empty() or accelerated.is_empty():return {}
		state.system_counter=system.counter_u32;state.accelerated_counter=accelerated.counter_u32;state.last_timestamp=int(timestamp)
	elif int(operation)==2:
		state.temporary_timer=0;state.temporary_shift=0;state.frame_step=0;state.timer=0;state.shift=0;state.button_image=0x25;state.button_index=1
	elif int(operation)==1:
		if int(state.timer)!=994:
			state.temporary_timer=994;state.temporary_shift=0;state.timer=994;state.shift=0;state.frame_step=0;state.accelerated_counter=0;state.button_image=0x27;state.button_index=1
	else:
		var raw_action:=int(action)&255
		if raw_action==0:return state
		if int(player_mode)==4:
			if raw_action>=0xc1 and raw_action<=0xc5:state.temporary_timer=0xf880000;state.temporary_shift=0x12
			else:state.last_action=int(action)
			return state
		if raw_action==0x3a:state.last_action=int(action);return state
		var selected:=0x3a if raw_action==0x30 else raw_action
		if selected>=0xc1 and selected<=0xc5:selected-=0x8b
		selected-=0x36
		if selected<0 or selected>4:state.last_action=int(action);return state
		state.temporary_timer=SOURCE_TIMERS[selected];state.temporary_shift=SOURCE_SHIFTS[selected];state.button_image=0x27+selected;state.button_index=1
		if selected>0:state.clock_low=(int(state.clock_low)-49710)&MASK
	return state
