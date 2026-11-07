class_name Navigation
extends RefCounted
# Legacy v1/v2 retain their adapter contracts. Explicit v3 sessions use the
# original F833/F903 arithmetic with a separately persisted source inventory.
const GalaxyData=preload("res://scripts/galaxy.gd")
const HyperdriveSession=preload("res://scripts/source_hyperdrive_session.gd")
const Hyperdrive=preload("res://scripts/source_hyperdrive.gd")
const FUEL_CAPACITY:=12
const CHARGE_SECONDS:=3.0
const NATIVE_VISIT_LIMIT:=65536
const NATIVE_FUEL_PROFILE:="rebuild-three-ship-4ly-per-unit-v1"
var galaxy:=GalaxyData.new()
var current_id:=GalaxyData.SOL_ID
var selected_id:=GalaxyData.SOL_ID
var elapsed_days:=0.0
var fuel:=FUEL_CAPACITY
var remaining:=0.0
var visited:Array=[GalaxyData.SOL_ID]
var pending_id:=-1
var pending_fuel:=0
var station_override:=""
var message:=""
var _source_port_available:=false # Derived selected-port context, never saved.
var _hyperdrive:RefCounted
var pending_source_quote:Dictionary={}
var fuel_extension_upgraded:=false

func is_native()->bool:return galaxy.is_native()
func is_source_hyperdrive()->bool:return _hyperdrive!=null

func configure_native(start_id:int=GalaxyData.SOL_ID)->bool:
	var candidate:=GalaxyData.new()
	if not candidate.configure_native() or not candidate.set_focus(start_id):return false
	galaxy=candidate;current_id=start_id;selected_id=start_id;elapsed_days=0.0;fuel=FUEL_CAPACITY;remaining=0.0
	visited=[start_id];pending_id=-1;pending_fuel=0;station_override="";message="";_source_port_available=false
	_hyperdrive=null;pending_source_quote={};fuel_extension_upgraded=false
	return true

func set_source_port_available(available:bool)->void:
	_source_port_available=available if is_native() else false

func current()->Dictionary:return galaxy.get_system(current_id)
func selected()->Dictionary:return galaxy.get_system(selected_id)
func distance()->float:return galaxy.distance(current_id,selected_id)
func has_station(id:int=-1)->bool:
	if is_native():return _source_port_available and (id<0 or id==current_id)
	var star:=galaxy.get_system(current_id if id<0 else id)
	return bool(star.get("has_station",false))
func fuel_required()->int:
	if is_source_hyperdrive():return maxi(0,int(quote_for(selected_id).get("required_fuel",0)))
	var d:=distance()
	return ceili(d/4.0) if is_finite(d) and d>0 else 0
func select(id:int)->bool:
	if remaining>0 or galaxy.get_system(id).is_empty():return false
	selected_id=id;return true

func jump_error(ship:RefCounted)->String:
	if is_source_hyperdrive():return _source_jump_error(ship)
	if remaining>0:return "Гиперпереход уже готовится."
	if ship.hull<=0:return "Корабль потерян."
	if ship.docked:return "Сначала вылетите со станции."
	if ship.surface_mode:return "Сначала вернитесь на орбиту."
	if ship.combat_active:return "Сначала выйдите из боя."
	if not ship.position.is_finite() or not ship.velocity.is_finite():return "Невозможно определить положение корабля."
	if current_id==selected_id:return "Вы уже в выбранной системе."
	if selected().is_empty():return "Система недоступна в текущем каталоге."
	if distance()>ship.jump_range():return "Система за пределами дальности гипердвигателя."
	if fuel_required()>fuel:return "Недостаточно гипертоплива."
	if ship.velocity.length()>20:return "Затормозите до 20 м/с."
	return ""

func begin_jump(ship:RefCounted)->bool:
	if is_source_hyperdrive():return _begin_source_jump(ship)
	message=jump_error(ship)
	if not message.is_empty():return false
	pending_id=selected_id;pending_fuel=fuel_required();remaining=CHARGE_SECONDS
	ship.brake();message="Заряд гипердвигателя. Повторное нажатие отменяет переход."
	return true

func cancel_jump()->void:
	remaining=0;pending_id=-1;pending_fuel=0;message="Гиперпереход отменён."
	pending_source_quote={}

func step(dt:float,ship:RefCounted)->bool:
	if is_source_hyperdrive():return _step_source(dt,ship)
	if remaining<=0 or not is_finite(dt) or dt<=0:return false
	if ship.hull<=0 or ship.docked or ship.surface_mode or ship.combat_active or not ship.velocity.is_finite() or ship.velocity.length()>20:
		cancel_jump();return false
	remaining=maxf(0.0,remaining-dt)
	if remaining>0:return false
	if galaxy.get_system(pending_id).is_empty() or pending_fuel<1 or pending_fuel>fuel:
		cancel_jump();return false
	var travelled:=galaxy.distance(current_id,pending_id)
	current_id=pending_id;selected_id=current_id;fuel-=pending_fuel;elapsed_days+=maxf(0.02,travelled*0.1)
	if not current_id in visited:visited.append(current_id)
	if is_native() and visited.size()>NATIVE_VISIT_LIMIT:visited.pop_front()
	pending_id=-1;pending_fuel=0;station_override="";_source_port_available=false
	if is_native():galaxy.set_focus(current_id)
	ship.position=Vector3.ZERO;ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.attitude=Quaternion.IDENTITY
	ship.autopilot=false;ship.station_available=has_station()
	message="Прибытие в систему: %s."%current().name
	return true

func refuel(ship:RefCounted)->bool:
	if is_source_hyperdrive():
		var state:=service_state(ship)
		for row:Dictionary in state.get("fuels",[]):
			if row.id==_hyperdrive.fuel_kind():return service("refuel",str(row.id),int(row.fill_quantity),ship)
		return false
	if ship.original_port and not is_native():message="Заправка этого космопорта пока недоступна.";return false
	if not ship.docked or not has_station() or remaining>0 or ship.surface_mode or ship.combat_active or not ship.station_available or not is_finite(ship.hull) or ship.hull<=0:
		message="Заправка доступна после стыковки с выбранным космопортом." if is_native() else "Заправка доступна после стыковки с учебным узлом.";return false
	var missing:=FUEL_CAPACITY-fuel
	if missing<=0:message="Баки полны.";return false
	var cost:=missing*10
	if ship.credits<cost:message="Недостаточно средств на заправку.";return false
	ship.credits-=cost;fuel=FUEL_CAPACITY;message="Гипертопливо пополнено."
	return true

func snapshot()->Dictionary:
	var result:={"schema":"starfrontier-rebuild-navigation-v1","version":1,"current_id":current_id,"selected_id":selected_id,"elapsed_days":elapsed_days,"fuel":fuel,"remaining":remaining,"pending_id":pending_id,"pending_fuel":pending_fuel,"visited":visited.duplicate()}
	if is_native():
		result.schema="starfrontier-rebuild-navigation-v2";result.version=2;result.catalogue_mode=GalaxyData.NATIVE_MODE;result.source_digest=galaxy.source_digest;result.fuel_profile=NATIVE_FUEL_PROFILE
	if is_source_hyperdrive():
		result.schema="starfrontier-rebuild-navigation-v3";result.version=3;result.fuel_profile=HyperdriveSession.FUEL_PROFILE
		result.source_hyperdrive=_hyperdrive.snapshot();result.pending_source_quote=pending_source_quote.duplicate(true)
	return result

static func _number(value:Variant,low:float,high:float,whole:=false)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high and (not whole or float(value)==floorf(float(value)))

func restore(data:Dictionary)->bool:
	if data.get("schema")=="starfrontier-rebuild-navigation-v3" and data.get("version")==3:return _restore_source(data)
	var native:bool=data.get("schema")=="starfrontier-rebuild-navigation-v2" and data.get("version")==2
	var legacy:bool=data.get("schema")=="starfrontier-rebuild-navigation-v1" and data.get("version")==1
	if not native and not legacy:return false
	var candidate:RefCounted=galaxy
	if native:
		candidate=GalaxyData.new()
		if not candidate.configure_native() or data.get("catalogue_mode")!=GalaxyData.NATIVE_MODE or data.get("source_digest")!=candidate.source_digest or data.get("fuel_profile")!=NATIVE_FUEL_PROFILE:return false
	elif is_native():candidate=GalaxyData.new()
	for key in ["current_id","selected_id"]:
		if not _number(data.get(key),0,4294967295.0,true) or not candidate.is_valid_id(int(data[key])):return false
	if not _number(data.get("elapsed_days"),0,1e9) or not _number(data.get("fuel"),0,FUEL_CAPACITY,true) or not _number(data.get("remaining"),0,CHARGE_SECONDS):return false
	if not _number(data.get("pending_id"),-1,4294967295.0,true) or not _number(data.get("pending_fuel"),0,FUEL_CAPACITY,true):return false
	if not data.get("visited") is Array or data.visited.size()>(NATIVE_VISIT_LIMIT if native else candidate.system_count()):return false
	var seen:Dictionary={}
	for id in data.visited:
		if not _number(id,0,4294967295.0,true) or not candidate.is_valid_id(int(id)) or seen.has(int(id)):return false
		seen[int(id)]=true
	if not seen.has(int(data.current_id)):return false
	if float(data.remaining)>0:
		if int(data.pending_id)!=int(data.selected_id) or int(data.pending_id)==int(data.current_id) or not candidate.is_valid_id(int(data.pending_id)) or int(data.pending_fuel)<1 or int(data.pending_fuel)>int(data.fuel):return false
		if int(data.pending_fuel)!=ceili(candidate.distance(int(data.current_id),int(data.pending_id))/4.0):return false
	elif int(data.pending_id)!=-1 or int(data.pending_fuel)!=0:return false
	if native and not candidate.set_focus(int(data.current_id)):return false
	galaxy=candidate
	current_id=int(data.current_id);selected_id=int(data.selected_id);elapsed_days=float(data.elapsed_days);fuel=int(data.fuel)
	remaining=float(data.remaining);pending_id=int(data.pending_id);pending_fuel=int(data.pending_fuel);visited=data.visited.duplicate()
	station_override="";message="";_source_port_available=false
	_hyperdrive=null;pending_source_quote={};fuel_extension_upgraded=false
	return true

func configure_source(ship_id:String="cobra",start_id:int=GalaxyData.SOL_ID)->bool:
	var session:=HyperdriveSession.new();var candidate:=GalaxyData.new()
	if not session.configure(ship_id) or not candidate.configure_native() or not candidate.set_focus(start_id):return false
	galaxy=candidate;current_id=start_id;selected_id=start_id;elapsed_days=0.0;remaining=0.0;visited=[start_id]
	pending_id=-1;pending_fuel=0;pending_source_quote={};station_override="";message="";_source_port_available=false
	_hyperdrive=session;fuel=session.fuel();fuel_extension_upgraded=false;return true
func fuel_capacity()->int:return _hyperdrive.fuel_capacity() if is_source_hyperdrive() else FUEL_CAPACITY
func source_range_ly(ship:RefCounted=null)->float:
	if not is_source_hyperdrive():return 0.0
	var candidate:RefCounted=_hyperdrive if ship==null else _hyperdrive.with_ship(ship)
	return maxf(0,float(candidate.range_quote().get("current_range_raw",0))/100.0) if candidate!=null else 0.0
func validate_source_ship(ship:RefCounted)->bool:
	return not is_source_hyperdrive() or (_hyperdrive.bridge_matches(ship) and fuel==_hyperdrive.fuel())
func sync_source_ship(ship:RefCounted)->bool:
	if not is_source_hyperdrive():return true
	var candidate:RefCounted=_hyperdrive.with_ship(ship)
	if candidate==null or (remaining>0 and not _hyperdrive.bridge_matches(ship)):return false
	_hyperdrive=candidate;fuel=candidate.fuel();return true
static func _quote_reason(code:String)->String:
	return str({"zero_distance":"Вы уже в выбранной системе.","no_drive":"Гипердвигатель не установлен.","out_of_range":"Система за пределами дальности гипердвигателя.","insufficient_fuel":"Недостаточно гипертоплива.","invalid_session":"Груз или оборудование не помещаются в исходный корабль."}.get(code,"Исходный расчёт гиперперехода недоступен."))
static func _raw_distance(fromrow:Dictionary,torow:Dictionary)->Dictionary:
	var first:Variant=fromrow.get("position_q16");var second:Variant=torow.get("position_q16")
	if not first is Array or not second is Array:return {"ok":false,"distance_raw":0}
	return Hyperdrive.distance_raw_from_q16(first,second)
func quote_for(destination_id:int,ship:RefCounted=null)->Dictionary:
	if not is_source_hyperdrive():return {}
	var candidate:RefCounted=_hyperdrive if ship==null else _hyperdrive.with_ship(ship)
	if candidate==null:return {"ok":false,"can_jump":false,"reason":"invalid_session"}
	var metric:=_raw_distance(current(),galaxy.get_system(destination_id))
	if not metric.get("ok",false):return {"ok":false,"can_jump":false,"reason":"invalid_position"}
	var result:Dictionary=candidate.quote(int(metric.distance_raw))
	result["distance_raw"]=int(metric.distance_raw);result["distance_ly"]=float(metric.distance_raw)/100.0
	return result
func map_profile(ship:RefCounted=null)->Dictionary:
	if not is_source_hyperdrive():return {}
	var session:RefCounted=_hyperdrive if ship==null else _hyperdrive.with_ship(ship)
	if session==null:return {}
	var ranges:Dictionary=session.range_quote()
	return {"schema":"source-hyperdrive-map-profile-v1","source_state":session.snapshot(),"current_id":current_id,"fuel":session.fuel(),"fuel_capacity":session.fuel_capacity(),"jump_range_ly":maxf(0,float(ranges.get("current_range_raw",0))/100.0),"maximum_jump_range_ly":maxf(0,float(ranges.get("max_range_raw",0))/100.0)}
static func validate_map_profile(profile:Dictionary)->bool:
	if profile.size()!=7 or profile.get("schema")!="source-hyperdrive-map-profile-v1" or not profile.get("source_state") is Dictionary or not _number(profile.get("current_id"),0,4294967295,true):return false
	var session:=HyperdriveSession.new()
	if not session.restore(profile.source_state):return false
	var ranges:=session.range_quote()
	for key in ["fuel","fuel_capacity"]:
		if not _number(profile.get(key),0,65535,true):return false
	for key in ["jump_range_ly","maximum_jump_range_ly"]:
		if not _number(profile.get(key),0,1000000):return false
	return int(profile.fuel)==session.fuel() and int(profile.fuel_capacity)==session.fuel_capacity() and float(profile.jump_range_ly)==maxf(0,float(ranges.get("current_range_raw",0))/100.0) and float(profile.maximum_jump_range_ly)==maxf(0,float(ranges.get("max_range_raw",0))/100.0)
static func source_map_quote(profile:Dictionary,fromrow:Dictionary,torow:Dictionary)->Dictionary:
	var rejected:={"profile_valid":false,"reachable":false,"distance_ly":0.0,"fuel_required":0,"reason":"Исходный профиль гиперперехода недоступен.","duration_days":0.0,"fuel_profile":HyperdriveSession.FUEL_PROFILE}
	if not validate_map_profile(profile) or not _number(fromrow.get("id"),0,4294967295,true) or int(fromrow.id)!=int(profile.current_id):return rejected
	var session:=HyperdriveSession.new()
	if not session.restore(profile.source_state):return rejected
	var metric:=_raw_distance(fromrow,torow)
	if not metric.get("ok",false):return rejected
	var quote:=session.quote(int(metric.distance_raw));var reachable:=bool(quote.get("ok",false)) and bool(quote.get("can_jump",false))
	return {"profile_valid":true,"distance_raw":int(metric.distance_raw),"distance_ly":float(metric.distance_raw)/100.0,"fuel_required":maxi(0,int(quote.get("required_fuel",0))),"required_fuel_raw":int(quote.get("required_fuel",-1)),"reachable":reachable,"reason":"" if reachable else _quote_reason(str(quote.get("reason",""))),"duration_raw_u32":int(quote.get("duration_raw_u32",0)),"duration_days":float(quote.get("duration_days",0)),"fuel_profile":HyperdriveSession.FUEL_PROFILE}
func _source_jump_error(ship:RefCounted)->String:
	if remaining>0:return "Гиперпереход уже готовится."
	if ship.hull<=0:return "Корабль потерян."
	if ship.docked:return "Сначала вылетите со станции."
	if ship.surface_mode:return "Сначала вернитесь на орбиту."
	if ship.combat_active:return "Сначала выйдите из боя."
	if not ship.position.is_finite() or not ship.velocity.is_finite():return "Невозможно определить положение корабля."
	if current_id==selected_id:return "Вы уже в выбранной системе."
	var quote:=quote_for(selected_id,ship)
	if not quote.get("ok",false) or not quote.get("can_jump",false):return _quote_reason(str(quote.get("reason","")))
	if ship.velocity.length()>20:return "Затормозите до 20 м/с."
	return ""
static func _pending_for(session:RefCounted,origin_id:int,destination_id:int,distance_raw:int,legacy:=false)->Dictionary:
	var quote:Dictionary=session.quote(distance_raw)
	if not quote.get("ok",false) or not quote.get("can_jump",false):return {}
	var result:={"schema":"source-hyperdrive-pending-v1" if legacy else "source-hyperdrive-pending-v2","origin_id":origin_id,"destination_id":destination_id,"distance_raw":distance_raw,"required_fuel":int(quote.required_fuel),"duration_raw_u32":int(quote.duration_raw_u32),"max_range_raw":int(quote.max_range_raw),"current_range_raw":int(quote.current_range_raw),"session_before_sha256":JSON.stringify(session.hyperdrive_snapshot()).sha256_text()}
	if not legacy:result.fuel_hardware_before_sha256=JSON.stringify({"refueller_installed":bool(session.fuel_system.refueller_installed),"scoop_installed":bool(session.fuel_system.scoop_installed),"atmospheric_shielding_installed":bool(session.fuel_system.atmospheric_shielding_installed)}).sha256_text()
	return result
static func _same_pending(first:Dictionary,second:Dictionary)->bool:
	if first.size()!=second.size():return false
	for key in first:
		if not second.has(key):return false
		if first[key] is int:
			if not _number(second[key],0,4294967295,true) or int(first[key])!=int(second[key]):return false
		elif not second[key] is String or first[key]!=second[key]:return false
	return true
func _begin_source_jump(ship:RefCounted)->bool:
	message=_source_jump_error(ship)
	if not message.is_empty():return false
	var candidate:RefCounted=_hyperdrive.with_ship(ship);var quote:=quote_for(selected_id,ship)
	var pending:=_pending_for(candidate,current_id,selected_id,int(quote.distance_raw))
	if pending.is_empty():return false
	_hyperdrive=candidate;fuel=candidate.fuel();pending_id=selected_id;pending_fuel=int(pending.required_fuel);pending_source_quote=pending;remaining=CHARGE_SECONDS
	ship.brake();message="Заряд гипердвигателя. Повторное нажатие отменяет переход.";return true
func _step_source(dt:float,ship:RefCounted)->bool:
	if remaining<=0 or not is_finite(dt) or dt<=0:return false
	if not validate_source_ship(ship) or ship.hull<=0 or ship.docked or ship.surface_mode or ship.combat_active or not ship.position.is_finite() or not ship.velocity.is_finite() or ship.velocity.length()>20:
		cancel_jump();return false
	var metric:=_raw_distance(current(),galaxy.get_system(pending_id))
	if not metric.get("ok",false) or pending_id!=selected_id or not _same_pending(_pending_for(_hyperdrive,current_id,pending_id,int(metric.distance_raw)),pending_source_quote):cancel_jump();return false
	remaining=maxf(0,remaining-dt)
	if remaining>0:return false
	var candidate:RefCounted=_hyperdrive.duplicate_session();var consumed:Dictionary=candidate.commit(int(metric.distance_raw),pending_source_quote)
	if not consumed.get("ok",false) or not consumed.get("can_jump",false) or not galaxy.set_focus(pending_id):cancel_jump();return false
	_hyperdrive=candidate;fuel=candidate.fuel();current_id=pending_id;selected_id=current_id;elapsed_days+=float(consumed.duration_raw_u32)/65536.0
	if not current_id in visited:visited.append(current_id)
	if visited.size()>NATIVE_VISIT_LIMIT:visited.pop_front()
	pending_id=-1;pending_fuel=0;pending_source_quote={};station_override="";_source_port_available=false
	ship.position=Vector3.ZERO;ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.attitude=Quaternion.IDENTITY;ship.autopilot=false;ship.station_available=false
	message="Прибытие в систему: %s."%current().name;return true
func _restore_source(data:Dictionary)->bool:
	var candidate:=GalaxyData.new();var session:=HyperdriveSession.new()
	if not candidate.configure_native() or data.get("catalogue_mode")!=GalaxyData.NATIVE_MODE or data.get("source_digest")!=candidate.source_digest or data.get("fuel_profile")!=HyperdriveSession.FUEL_PROFILE or not data.get("source_hyperdrive") is Dictionary or not session.restore(data.source_hyperdrive):return false
	for key in ["current_id","selected_id"]:
		if not _number(data.get(key),0,4294967295,true) or not candidate.is_valid_id(int(data[key])):return false
	if not _number(data.get("elapsed_days"),0,1e9) or not _number(data.get("fuel"),0,65535,true) or int(data.fuel)!=session.fuel() or not _number(data.get("remaining"),0,CHARGE_SECONDS):return false
	if not _number(data.get("pending_id"),-1,4294967295,true) or not _number(data.get("pending_fuel"),0,65535,true) or not data.get("pending_source_quote") is Dictionary:return false
	if not data.get("visited") is Array or data.visited.size()>NATIVE_VISIT_LIMIT:return false
	var seen:Dictionary={}
	for id:Variant in data.visited:
		if not _number(id,0,4294967295,true) or not candidate.is_valid_id(int(id)) or seen.has(int(id)):return false
		seen[int(id)]=true
	if not seen.has(int(data.current_id)):return false
	var restored_pending:Dictionary={}
	if float(data.remaining)>0:
		if int(data.pending_id)!=int(data.selected_id) or int(data.pending_id)==int(data.current_id) or not candidate.is_valid_id(int(data.pending_id)):return false
		var metric:=_raw_distance(candidate.get_system(int(data.current_id)),candidate.get_system(int(data.pending_id)))
		if not metric.get("ok",false):return false
		var legacy_pending:bool=not data.source_hyperdrive.has("fuel_system")
		var expected:=_pending_for(session,int(data.current_id),int(data.pending_id),int(metric.distance_raw),legacy_pending)
		if expected.is_empty() or int(data.pending_fuel)!=int(expected.required_fuel) or not _same_pending(expected,data.pending_source_quote):return false
		restored_pending=_pending_for(session,int(data.current_id),int(data.pending_id),int(metric.distance_raw))
	elif int(data.pending_id)!=-1 or int(data.pending_fuel)!=0 or not data.pending_source_quote.is_empty():return false
	if not candidate.set_focus(int(data.current_id)):return false
	galaxy=candidate;_hyperdrive=session;current_id=int(data.current_id);selected_id=int(data.selected_id);elapsed_days=float(data.elapsed_days);fuel=int(data.fuel)
	remaining=float(data.remaining);pending_id=int(data.pending_id);pending_fuel=int(data.pending_fuel);visited=data.visited.duplicate();pending_source_quote=restored_pending
	fuel_extension_upgraded=session.fuel_extension_upgraded
	station_override="";message="";_source_port_available=false;return true
func _fuel_action_reason(ship:RefCounted)->String:
	if not is_source_hyperdrive():return "Этот сеанс сохраняет прежнюю топливную модель."
	if remaining>0:return "Сначала отмените заряд гипердвигателя."
	if ship==null or not is_finite(ship.hull) or ship.hull<=0:return "Корабль недоступен для заправки."
	return ""
func fuel_state(ship:RefCounted=null)->Dictionary:
	if not is_source_hyperdrive():return {"source_mode":false,"reason":"Этот сеанс сохраняет прежнюю топливную модель.","can_manual_refuel":false,"can_toggle_refueller":false,"upgrade_notice":""}
	var candidate:RefCounted=_hyperdrive if ship==null else _hyperdrive.with_ship(ship)
	if candidate==null:return {"source_mode":true,"reason":"Груз или оборудование не помещаются в исходный корабль.","can_manual_refuel":false,"can_toggle_refueller":false,"upgrade_notice":""}
	var result:Dictionary=candidate.fuel_state();var reason:="" if ship==null else _fuel_action_reason(ship)
	if not reason.is_empty():
		result.can_manual_refuel=false;result.manual_refuel_reason=reason;result.can_toggle_refueller=false;result.toggle_reason=reason
	return result
func apply_fuel_availability(ship:RefCounted)->bool:
	if ship==null:return false
	if not is_source_hyperdrive():ship.propulsion_available=true;ship.source_thrust_limits_u16=[];return true
	if not validate_source_ship(ship):return false
	ship.source_thrust_limits_u16=_hyperdrive.thrust_limits_u16();ship.propulsion_available=_hyperdrive.propulsion_available();return true
func set_refueller_enabled(enabled:bool,ship:RefCounted)->bool:
	message=_fuel_action_reason(ship)
	if not message.is_empty():return false
	var candidate:RefCounted=_hyperdrive.with_ship(ship)
	if candidate==null or not candidate.set_refueller_enabled(enabled):message="Автозаправщик не установлен или недоступен.";return false
	_hyperdrive=candidate;fuel=candidate.fuel();message="Автозаправщик включён." if enabled else "Автозаправщик выключен.";return true
func manual_jet_refuel(ship:RefCounted)->bool:
	message=_fuel_action_reason(ship)
	if not message.is_empty():return false
	var candidate:RefCounted=_hyperdrive.with_ship(ship)
	if candidate==null:message="Груз или оборудование не помещаются в исходный корабль.";return false
	var result:Dictionary=candidate.manual_jet_refuel();message=str(result.get("message","Ручная заправка недоступна."))
	if not result.get("ok",false) or not result.get("accepted",false):return false
	_hyperdrive=candidate;fuel=candidate.fuel();apply_fuel_availability(ship);return true
func _commit_fuel_result(candidate:RefCounted,result:Dictionary,ship:RefCounted)->Dictionary:
	if not result.get("ok",false):return result
	var cancelled:=false
	if remaining>0 and candidate.hyperdrive_snapshot()!=_hyperdrive.hyperdrive_snapshot():cancel_jump();cancelled=true
	_hyperdrive=candidate;fuel=candidate.fuel();apply_fuel_availability(ship)
	result.hyperjump_cancelled=cancelled;return result
func _fuel_candidate(ship:RefCounted)->RefCounted:
	if not is_source_hyperdrive() or ship==null or not is_finite(ship.hull) or ship.hull<=0:return null
	if remaining>0 and not validate_source_ship(ship):return null
	return _hyperdrive.with_ship(ship)
func fuel_step(context:Dictionary,ship:RefCounted)->Dictionary:
	var candidate:RefCounted=_fuel_candidate(ship)
	if candidate==null:return {"ok":false,"reason":"invalid_fuel_session"}
	return _commit_fuel_result(candidate,candidate.fuel_step(context),ship)
func advance_fuel_ticks(ticks:int,context:Dictionary,ship:RefCounted)->Dictionary:
	var candidate:RefCounted=_fuel_candidate(ship)
	if candidate==null:return {"ok":false,"reason":"invalid_fuel_session"}
	return _commit_fuel_result(candidate,candidate.advance_fuel_ticks(ticks,context),ship)
func advance_fuel_seconds(dt:float,context:Dictionary,ship:RefCounted)->Dictionary:
	var candidate:RefCounted=_fuel_candidate(ship)
	if candidate==null:return {"ok":false,"reason":"invalid_fuel_session"}
	return _commit_fuel_result(candidate,candidate.advance_fuel_seconds(dt,context),ship)
func _service_reason(ship:RefCounted)->String:
	if not is_source_hyperdrive():return "Этот сеанс сохраняет прежнюю топливную модель."
	if remaining>0:return "Сначала отмените заряд гипердвигателя."
	if not ship.docked or not _source_port_available or not ship.station_available or ship.surface_mode or ship.combat_active or not is_finite(ship.hull) or ship.hull<=0:return "Для обслуживания выполните стыковку с выбранным космопортом."
	return ""
func service_state(ship:RefCounted)->Dictionary:
	if not is_source_hyperdrive():return {"schema":"source-hyperdrive-services-v1","source_mode":false,"docked":ship.docked,"service_available":false,"reason":_service_reason(ship),"drives":[],"fuels":[],"fuel_system":fuel_state(ship),"fuel_equipment":[]}
	var candidate:RefCounted=_hyperdrive.with_ship(ship);var reason:=_service_reason(ship)
	if candidate==null:return {"schema":"source-hyperdrive-services-v1","source_mode":true,"docked":ship.docked,"service_available":false,"reason":"Груз или оборудование не помещаются в исходный корабль.","drives":[],"fuels":[]}
	var result:Dictionary=candidate.service_state(int(ship.credits),reason.is_empty(),reason);result.docked=ship.docked
	result.profile_name=str(ship.profile().get("name",ship.ship_id))
	result.fuel_system=fuel_state(ship)
	return result
func service(action:String,id:String,quantity:int,ship:RefCounted)->bool:
	message=_service_reason(ship)
	if not message.is_empty():return false
	if not _number(ship.credits,0,1000000000,true):
		message="Недопустимое состояние средств корабля.";return false
	var candidate:RefCounted=_hyperdrive.with_ship(ship)
	if candidate==null:
		message="Груз или оборудование не помещаются в исходный корабль.";return false
	var result:Dictionary=candidate.service(action,id,quantity,int(ship.credits))
	message=str(result.message)
	if not result.ok:return false
	_hyperdrive=candidate;fuel=candidate.fuel();ship.credits=int(result.credits);apply_fuel_availability(ship);return true
func migration_quote(ship:RefCounted)->Dictionary:
	var reason:=""
	if is_source_hyperdrive() or not is_native():reason="Переход доступен только для прежнего нативного сеанса."
	elif remaining>0:reason="Сначала отмените заряд гипердвигателя."
	elif not ship.docked or not _source_port_available or not ship.station_available or ship.surface_mode or ship.combat_active or ship.hull<=0:reason="Для перехода выполните стыковку с выбранным космопортом."
	elif not ship.equipment.is_empty():reason="Снимите прежнее адаптированное оборудование перед переходом."
	var candidate:RefCounted=get_script().new()
	if reason.is_empty() and not candidate.configure_source(str(ship.ship_id),current_id):reason="Исходный профиль этого корабля недоступен."
	if reason.is_empty():
		candidate._hyperdrive.hydrogen=fuel;candidate._hyperdrive.military=0;candidate._hyperdrive.radioactives=0
		candidate._hyperdrive.fuel_system.initialization_policy="explicit-v2-migration-profile-v1"
		if not candidate.sync_source_ship(ship):reason="Груз и переведённое топливо не помещаются в исходный корабль."
	if not reason.is_empty():return {"ok":false,"message":reason,"reason":reason}
	candidate.selected_id=selected_id;candidate.elapsed_days=elapsed_days;candidate.visited=visited.duplicate()
	return {"ok":true,"message":"Прежние единицы гипертоплива будут переведены в тонны водорода один к одному. Цена перехода — 0.","reason":"","hydrogen":fuel,"price":0,"source_capacity_t":candidate._hyperdrive.capacity(),"occupied_t":candidate._hyperdrive.occupied(),"free_t":candidate._hyperdrive.free_space(),"drive_name":HyperdriveSession.drive_name(candidate._hyperdrive.drive_index),"candidate_snapshot":candidate.snapshot(),"migration_profile":"explicit-native-v2-fuel-units-to-hydrogen-tonnes-v1"}
func migrate_source(ship:RefCounted)->Dictionary:
	var quote:=migration_quote(ship)
	if not quote.ok:return quote
	var port_context:=_source_port_available
	if not restore(quote.candidate_snapshot):return {"ok":false,"message":"Не удалось проверить подготовленный переход."}
	_source_port_available=port_context
	message="Исходный гипердвигатель и отдельное гипертопливо включены для этого сохранения.";return {"ok":true,"message":message,"migration_profile":quote.migration_profile}
