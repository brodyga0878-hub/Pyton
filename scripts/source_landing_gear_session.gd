extends RefCounted
# Independent whole-game gear state. It never reads Navigation, fuel, Flight,
# wall-clock time or an inferred phone autopilot phase. The host supplies the
# actual source-context adapter and decides when simulation is paused.
const Kernel=preload("res://scripts/source_landing_gear.gd")
const DATA_PATH:="res://data/ffe_landing_gear.json"
const SCHEMA:="starfrontier-source-landing-gear-session-v1"
const HOST_POLICY:="nominal-day-si-fixed60-source-landing-gear-v1"
const HZ:=60
const TICK_DENOMINATOR:=86400*HZ
const MAX_STEPS:=256
const KEYS:=["schema","version","source_contract","source_sha256","source_digest","host_policy","control_flags_u8","position_u16","object_timer_u16","warning_flags_u16","phase_f64_hex","frame_tick_remainder_raw"]
static var _resource_digest:=""
static var _resource_mutex:=Mutex.new()
var _saved:Dictionary={}

static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _digest()->String:
	_resource_mutex.lock()
	if _resource_digest.is_empty() and FileAccess.file_exists(DATA_PATH):
		var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if data is Dictionary and data.get("schema")==1 and data.get("source_sha256")==Kernel.SOURCE_SHA:_resource_digest=FileAccess.get_sha256(DATA_PATH)
	var result:=_resource_digest
	_resource_mutex.unlock();return result
static func _float_hex(value:float)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()
static func _phase(value:Variant)->float:
	if not value is String or value.length()!=16:return -1.0
	for character:String in value:
		if not character in "0123456789abcdef":return -1.0
	var result:float=value.hex_decode().decode_double(0)
	return result if is_finite(result) and result>=0 and result<1 else -1.0
static func _valid(data:Dictionary)->bool:
	if data.size()!=KEYS.size():return false
	for key:String in KEYS:
		if not data.has(key):return false
	if data.schema!=SCHEMA or not _whole(data.version,1,1) or data.source_contract!=Kernel.CONTRACT or data.source_sha256!=Kernel.SOURCE_SHA or data.host_policy!=HOST_POLICY:return false
	if not data.source_digest is String or data.source_digest.length()!=64 or data.source_digest!=_digest():return false
	if not _whole(data.control_flags_u8,0,255):return false
	for key:String in ["position_u16","object_timer_u16","warning_flags_u16"]:
		if not _whole(data[key],0,65535):return false
	return _phase(data.phase_f64_hex)>=0 and _whole(data.frame_tick_remainder_raw,0,TICK_DENOMINATOR-1)
func configure(default_down:bool=false)->bool:
	var candidate:={"schema":SCHEMA,"version":1,"source_contract":Kernel.CONTRACT,"source_sha256":Kernel.SOURCE_SHA,"source_digest":_digest(),"host_policy":HOST_POLICY,"control_flags_u8":0 if default_down else Kernel.RETRACT_FLAG,"position_u16":Kernel.DEPLOYED_POSITION if default_down else 0,"object_timer_u16":0,"warning_flags_u16":0,"phase_f64_hex":_float_hex(0),"frame_tick_remainder_raw":0}
	if not _valid(candidate):return false
	_saved=candidate;return true
func snapshot()->Dictionary:return _saved.duplicate(true)
func restore(data:Dictionary)->bool:
	if not _valid(data):return false
	var candidate:=data.duplicate(true)
	for key:String in ["version","control_flags_u8","position_u16","object_timer_u16","warning_flags_u16","frame_tick_remainder_raw"]:candidate[key]=int(candidate[key])
	_saved=candidate;return true
func _kernel_state(context:Dictionary)->Dictionary:
	return {"position_u16":_saved.get("position_u16"),"object_timer_u16":_saved.get("object_timer_u16"),"autopilot_phase_u8":context.get("autopilot_phase_u8"),"flight_state_u8":context.get("flight_state_u8"),"control_flags_u8":_saved.get("control_flags_u8"),"warning_flags_u16":_saved.get("warning_flags_u16"),"speed_s32":context.get("speed_s32")}
func _context_valid(context:Dictionary)->bool:
	if context.has("paused") and not context.paused is bool:return false
	return _valid(_saved) and Kernel.valid_state(_kernel_state(context))
func _take_kernel(raw:Dictionary)->void:
	for key:String in ["position_u16","object_timer_u16","control_flags_u8","warning_flags_u16"]:_saved[key]=int(raw[key])
func _reject(reason:String,message:String)->Dictionary:
	return {"ok":false,"accepted":false,"changed":false,"reason":reason,"message":message,"callbacks":[],"state":state(),"source_contract":Kernel.CONTRACT,"host_policy":HOST_POLICY}
func _paused(context:Dictionary)->Dictionary:
	return {"ok":true,"accepted":false,"changed":false,"reason":"paused_host","message":"Управление приостановлено.","callbacks":[],"state":state(context),"executed_steps":0,"host_policy":HOST_POLICY}
func command_toggle(context:Dictionary)->Dictionary:
	if not _context_valid(context):return _reject("invalid_context","Не удалось определить состояние управления шасси.")
	if context.get("paused",false):return _paused(context)
	var result:=Kernel.toggle(_kernel_state(context))
	if not result.get("ok",false):return _reject("invalid_kernel_state","Исходная команда шасси недоступна.")
	_take_kernel(result.state)
	return {"ok":true,"accepted":bool(result.accepted),"changed":bool(result.changed),"reason":str(result.reason),"message":("Выпуск шасси." if result.requested_down else "Уборка шасси.") if result.accepted else "Шасси нельзя переключить в текущем состоянии корабля.","callbacks":result.callbacks.duplicate(true),"source_state":result.state.duplicate(true),"state":state(context),"source_contract":Kernel.CONTRACT,"host_policy":HOST_POLICY}
func command_request(down:bool,context:Dictionary)->Dictionary:
	if not _context_valid(context):return _reject("invalid_context","Не удалось определить состояние управления шасси.")
	if context.get("paused",false):return _paused(context)
	if down==((int(_saved.control_flags_u8)&Kernel.RETRACT_FLAG)==0):
		# Explicit idempotent phone adapter: no synthetic toggle or callbacks.
		return {"ok":true,"accepted":true,"changed":false,"reason":"already_requested","message":"","callbacks":[],"state":state(context),"source_contract":Kernel.CONTRACT,"host_policy":HOST_POLICY}
	return command_toggle(context)
func _advance_seconds(dt:float,context:Dictionary,allow_identity_fastpath:=true)->Dictionary:
	if not _context_valid(context) or not is_finite(dt) or dt<0:return _reject("invalid_elapsed_or_context","Не удалось обновить положение шасси.")
	if context.get("paused",false):return _paused(context)
	if dt==0:return {"ok":true,"accepted":true,"changed":false,"reason":"zero_elapsed","message":"","callbacks":[],"state":state(context),"executed_steps":0,"master_ticks":0,"host_policy":HOST_POLICY,"source_contract":Kernel.CONTRACT}
	var accumulated:=dt*HZ+_phase(_saved.phase_f64_hex)
	if not is_finite(accumulated) or accumulated<0 or accumulated>=MAX_STEPS+1:return _reject("step_budget","Шаг движения шасси превышает допустимый предел.")
	var steps:=floori(accumulated);var candidate:RefCounted=get_script().new()
	if not candidate.restore(_saved):return _reject("invalid_saved_state","Не удалось проверить сохранённое положение шасси.")
	var callbacks:Array=[];var master_ticks:=0
	var retract:bool=(int(candidate._saved.control_flags_u8)&Kernel.RETRACT_FLAG)!=0
	var endpoint:bool=(int(candidate._saved.position_u16)==0 if retract else int(candidate._saved.position_u16)==Kernel.DEPLOYED_POSITION)
	var no_new_warning:bool=retract or int(context.speed_s32)<Kernel.WARNING_SPEED_RAW or (int(candidate._saved.warning_flags_u16)&Kernel.WARNING_FLAG)!=0
	var identity:bool=allow_identity_fastpath and steps>0 and int(context.flight_state_u8)==0 and int(candidate._saved.object_timer_u16)==0 and endpoint and no_new_warning
	if identity:
		# Only a manual, stationary endpoint without a timer or new warning.
		# One actual proven source transition confirms the identity; rational
		# clock accumulation remains identical to every fixed60 invocation.
		var total:=int(candidate._saved.frame_tick_remainder_raw)+steps*0x100000000
		var ticks:int=total/TICK_DENOMINATOR
		var result:=Kernel.step(candidate._kernel_state(context),ticks)
		if not result.get("ok",false) or result.changed or not result.callbacks.is_empty():return _reject("invalid_identity","Не удалось проверить стабильное положение шасси.")
		candidate._take_kernel(result.state);candidate._saved.frame_tick_remainder_raw=total%TICK_DENOMINATOR;master_ticks=ticks
	for _index in range(0 if identity else steps):
		var total:=int(candidate._saved.frame_tick_remainder_raw)+0x100000000
		var ticks:int=total/TICK_DENOMINATOR
		candidate._saved.frame_tick_remainder_raw=total%TICK_DENOMINATOR
		var result:=Kernel.step(candidate._kernel_state(context),ticks)
		if not result.get("ok",false):return _reject("invalid_kernel_step","Исходное движение шасси недоступно.")
		candidate._take_kernel(result.state);callbacks.append_array(result.callbacks.duplicate(true));master_ticks+=ticks
	candidate._saved.phase_f64_hex=_float_hex(accumulated-float(steps))
	if not _valid(candidate._saved):return _reject("invalid_candidate","Не удалось проверить новое положение шасси.")
	var changed:bool=candidate._saved!=_saved;_saved=candidate._saved
	var warning_message:=""
	for callback:Dictionary in callbacks:
		if callback.get("function")=="F1097" and int(callback.get("message",0))==Kernel.WARNING_MESSAGE:warning_message="Шасси выпущены на высокой скорости. Рекомендуется убрать шасси."
	return {"ok":true,"accepted":true,"changed":changed,"reason":"advanced" if steps>0 else "fraction_only","message":warning_message,"callbacks":callbacks,"state":state(context),"executed_steps":steps,"master_ticks":master_ticks,"host_policy":HOST_POLICY,"source_contract":Kernel.CONTRACT}
func advance_seconds(dt:float,context:Dictionary)->Dictionary:return _advance_seconds(dt,context)
func state(context:Dictionary={})->Dictionary:
	if not _valid(_saved):return {"initialized":false,"requested_down":false,"retract_requested":true,"f1014_raw_gear_flag":true,"position_u16":0,"extension_fraction":0.0,"extension_percent":0.0,"deployed":false,"retracted":false,"moving":false,"landing_ready":false,"status_text":"Состояние шасси не подготовлено.","command_label":"Шасси","can_toggle":false,"toggle_reason":"Состояние шасси не подготовлено.","warning_latched":false,"warning_text":""}
	var retract:bool=(int(_saved.control_flags_u8)&Kernel.RETRACT_FLAG)!=0
	var position:=int(_saved.position_u16);var deployed:bool=position==Kernel.DEPLOYED_POSITION;var retracted:bool=position==0
	var moving:bool=not retracted if retract else not deployed
	var status:="Убраны" if retract else "Выпущены"
	if moving:status=("Уборка %d%%"%(roundi((1.0-float(position)/Kernel.DEPLOYED_POSITION)*100.0))) if retract else ("Выпуск %d%%"%(roundi(float(position)*100.0/Kernel.DEPLOYED_POSITION)))
	var can_toggle:=false;var reason:="Контекст управления не задан."
	if _context_valid(context):
		if context.get("paused",false):reason="Управление приостановлено."
		else:
			var preview:=Kernel.toggle(_kernel_state(context));can_toggle=bool(preview.get("ok",false)) and bool(preview.get("accepted",false))
			reason="" if can_toggle else "Шасси нельзя переключить в текущем состоянии корабля."
	var warning:bool=(int(_saved.warning_flags_u16)&Kernel.WARNING_FLAG)!=0
	return {"initialized":true,"requested_down":not retract,"retract_requested":retract,"f1014_raw_gear_flag":retract,"control_flags_u8":int(_saved.control_flags_u8),"position_u16":position,"object_timer_u16":int(_saved.object_timer_u16),"extension_fraction":float(position)/Kernel.DEPLOYED_POSITION,"extension_percent":float(position)*100.0/Kernel.DEPLOYED_POSITION,"deployed":deployed,"retracted":retracted,"moving":moving,"landing_ready":deployed,"status_text":status,"command_label":"Выпустить шасси" if retract else "Убрать шасси","can_toggle":can_toggle,"toggle_reason":reason,"warning_latched":warning,"warning_text":"Шасси выпущены на высокой скорости. Рекомендуется убрать шасси." if warning else "","phase_f64_hex":str(_saved.phase_f64_hex),"frame_tick_remainder_raw":int(_saved.frame_tick_remainder_raw),"source_contract":Kernel.CONTRACT,"host_policy":HOST_POLICY}
