extends RefCounted
# Explicitly adapted training-dock transactions, not original FFE port economy.
const REPAIR_CREDITS_PER_PERCENT:=2.0
const MAX_CREDITS:=1000000000

static func _number(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value))

static func _failure(status:String,message:String)->Dictionary:
	return {"ok":false,"status":status,"message":message,"cost":0}

static func repair_quote(ship:RefCounted)->Dictionary:
	if ship==null:return _failure("invalid_state","Не удалось определить состояние корабля.")
	var hull:Variant=ship.get("hull")
	var credits:Variant=ship.get("credits")
	if not _number(hull) or float(hull)<0.0 or float(hull)>100.0:
		return _failure("invalid_state","Неверное состояние корпуса.")
	if not _number(credits) or float(credits)<0.0 or float(credits)>MAX_CREDITS or float(credits)!=floorf(float(credits)):
		return _failure("invalid_state","Неверное состояние счёта.")
	for name in ["original_port","docked","surface_mode","combat_active","station_available"]:
		if not ship.get(name) is bool:return _failure("invalid_state","Не удалось определить режим корабля.")
	var current_hull:=float(hull)
	var current_credits:=int(credits)
	var quote:Dictionary={"ok":false,"status":"context_unavailable","message":"Ремонт доступен после стыковки с учебным узлом.","cost":0,"hull_before":current_hull,"hull_after":current_hull,"credits_before":current_credits,"credits_after":current_credits}
	if current_hull<=0.0:
		quote.status="destroyed";quote.message="Корабль потерян: ремонт в доке недоступен."
		return quote
	if ship.get("original_port") or not ship.get("docked") or ship.get("surface_mode") or ship.get("combat_active") or not ship.get("station_available"):
		return quote
	if current_hull>=100.0:
		quote.status="already_repaired";quote.message="Корпус исправен. Ремонт не требуется."
		return quote
	var cost:=ceili((100.0-current_hull)*REPAIR_CREDITS_PER_PERCENT)
	quote.cost=cost
	if current_credits<cost:
		quote.status="insufficient_funds";quote.message="Для ремонта корпуса нужно %d кр. Недостаточно средств."%cost
		return quote
	quote.ok=true;quote.status="available";quote.message="Ремонт корпуса до 100%%: %d кр."%cost
	quote.hull_after=100.0;quote.credits_after=current_credits-cost
	return quote

static func repair(ship:RefCounted)->Dictionary:
	var quote:=repair_quote(ship)
	if not quote.ok:return quote
	# All validation precedes both writes; neither inventory nor flight state changes.
	ship.set("hull",100.0)
	ship.set("credits",int(quote.credits_after))
	quote.status="repaired";quote.message="Корпус восстановлен до 100%%. Оплачено %d кр."%int(quote.cost)
	return quote

static func _whole(value:Variant,maximum:=1000000)->bool:
	return _number(value) and float(value)>=0.0 and float(value)<=maximum and float(value)==floorf(float(value))

static func _native_navigation(nav:RefCounted)->bool:
	return nav!=null and nav.has_method("is_native") and nav.is_native()==true

static func _source_refuel_context(ship:RefCounted,nav:RefCounted)->bool:
	return ship!=null and ship.get("original_port") is bool and ship.original_port and _native_navigation(nav) and nav.has_method("has_station") and nav.has_station()==true

static func _source_refuel_state(ship:RefCounted,nav:RefCounted,selected_port:bool)->Dictionary:
	var hull:Variant=ship.get("hull") if ship!=null else 0.0
	var credits:Variant=ship.get("credits") if ship!=null else 0
	var error:=""
	var validation:=repair_quote(ship)
	if validation.status in ["invalid_state","destroyed"]:error=validation.message
	elif not selected_port:error="Для заправки выберите доступный космопорт и выполните стыковку."
	elif not ship.docked or ship.surface_mode or ship.combat_active or not ship.station_available:error="Заправка доступна после стыковки с выбранным космопортом."
	elif nav==null or not _number(nav.get("remaining")) or float(nav.get("remaining"))!=0.0:error="Заправка недоступна во время гиперперехода."
	var state:Dictionary={"original_port":ship!=null and ship.get("original_port") is bool and ship.original_port,"source_refuel_only":selected_port,"source_port_name":"Выбранный космопорт","docked":ship!=null and ship.get("docked") is bool and ship.docked,"hull":float(hull) if _number(hull) else 0.0,"credits":int(credits) if _whole(credits,MAX_CREDITS) else 0,"cargo_used":0,"cargo_capacity":0,"fuel":0,"fuel_capacity":0,"profile_name":"—","goods":[],"ships":[],"repair":{"price":0,"can_repair":false,"reason":"Ремонт в этом космопорте недоступен."},"refuel":{"price":0,"can_refuel":false,"reason":error},"delivery":{"reward":0,"can_deliver":false,"reason":"Учебные доставки в этом космопорте не принимаются."},"context_error":error}
	if not selected_port:state.native_services_unavailable=true
	if ship!=null and ship.has_method("profile"):
		var profile:Dictionary=ship.profile();state.profile_name=str(profile.get("name","—"))
		if profile.is_empty() and error.is_empty():error="Не удалось определить корабль."
	# Never pass a malformed manifest into the model's typed integer sum.
	var valid_inventory:bool=ship!=null and ship.get("goods") is Dictionary and ship.get("mission_cargo") is Dictionary and ship.get("equipment") is Array and _whole(ship.get("story_cargo"))
	if valid_inventory:
		for count in ship.goods.values():
			if not _whole(count):valid_inventory=false;break
	if valid_inventory:
		for count in ship.mission_cargo.values():
			if not _whole(count):valid_inventory=false;break
	if valid_inventory:
		for id in ship.equipment:
			if not id is String or not ship.economy_catalog.equipment.has(id):valid_inventory=false;break
	if valid_inventory and ship.has_method("total_cargo") and ship.has_method("cargo_capacity"):
		state.cargo_used=ship.total_cargo();state.cargo_capacity=ship.cargo_capacity()
	elif error.is_empty():error="Неверное состояние груза."
	if nav!=null and _whole(nav.FUEL_CAPACITY) and _whole(nav.get("fuel"),int(nav.FUEL_CAPACITY)):
		state.fuel=int(nav.fuel);state.fuel_capacity=int(nav.FUEL_CAPACITY)
	elif error.is_empty():error="Неверное состояние гипертоплива."
	var missing:int=state.fuel_capacity-state.fuel;var price:=missing*10
	state.context_error=error
	if error.is_empty():
		if missing<=0:error="Баки полны."
		elif state.credits<price:error="Недостаточно средств на заправку."
	state.refuel={"price":price,"can_refuel":error.is_empty(),"reason":error}
	return state

static func _service_error(ship:RefCounted,nav:RefCounted)->String:
	var repair_state:=repair_quote(ship)
	if repair_state.status in ["invalid_state","destroyed","context_unavailable"]:return repair_state.message
	if nav==null or not _number(nav.get("remaining")) or float(nav.get("remaining"))!=0.0:return "Обслуживание недоступно во время гиперперехода."
	if not ship.has_method("total_cargo") or not ship.has_method("cargo_capacity") or not ship.has_method("trade_ship_error") or not ship.has_method("ship_trade_value"):
		return "Не удалось определить каталог корабля."
	var goods:Variant=ship.get("goods")
	if not goods is Dictionary:return "Неверное состояние груза."
	for id in goods:
		if not _whole(goods[id]):return "Неверное состояние груза."
	return ""

static func service_state(ship:RefCounted,nav:RefCounted)->Dictionary:
	if _native_navigation(nav):return _source_refuel_state(ship,nav,_source_refuel_context(ship,nav))
	var error:=_service_error(ship,nav)
	var hull:Variant=ship.get("hull") if ship!=null else 0.0
	var credits:Variant=ship.get("credits") if ship!=null else 0
	var state:Dictionary={"original_port":ship!=null and ship.get("original_port")==true,"docked":ship!=null and ship.get("docked")==true,"hull":float(hull) if _number(hull) else 0.0,"credits":int(credits) if _whole(credits,MAX_CREDITS) else 0,"cargo_used":0,"cargo_capacity":0,"fuel":0,"fuel_capacity":0,"profile_name":"—","goods":[],"ships":[],"repair":{"price":0,"can_repair":false,"reason":error},"refuel":{"price":0,"can_refuel":false,"reason":error},"delivery":{"reward":0,"can_deliver":false,"reason":error},"context_error":error}
	if ship==null or nav==null or not ship.has_method("profile") or not ship.has_method("total_cargo") or not ship.has_method("cargo_capacity"):return state
	var profile:Dictionary=ship.profile()
	state.profile_name=str(profile.get("name","—"))
	if not _number(hull) or float(hull)<0.0 or float(hull)>100.0 or not _whole(credits,MAX_CREDITS):return state
	# Invalid inventory must not be passed through the model's typed integer sum.
	var valid_inventory:bool=ship.get("goods") is Dictionary
	if valid_inventory:
		for id in ship.goods:
			if not _whole(ship.goods[id]):valid_inventory=false;break
	if not valid_inventory:return state
	state.cargo_used=ship.total_cargo();state.cargo_capacity=ship.cargo_capacity()
	var fuel:Variant=nav.get("fuel")
	var capacity:Variant=nav.FUEL_CAPACITY
	if _whole(capacity) and _whole(fuel,int(capacity)):
		state.fuel=int(fuel);state.fuel_capacity=int(capacity)
	else:
		error="Неверное состояние гипертоплива.";state.context_error=error
	var available:=error.is_empty()
	var quote:=repair_quote(ship)
	state.repair={"price":int(quote.cost),"can_repair":available and quote.ok,"reason":error if not available else ("" if quote.ok else str(quote.message))}
	var missing:int=state.fuel_capacity-state.fuel
	var fuel_price:=missing*10
	var fuel_reason:=error
	if fuel_reason.is_empty():
		if not nav.has_station():fuel_reason="У этой системы нет доступного учебного узла."
		elif missing<=0:fuel_reason="Баки полны."
		elif state.credits<fuel_price:fuel_reason="Недостаточно средств на заправку."
	state.refuel={"price":fuel_price,"can_refuel":fuel_reason.is_empty(),"reason":fuel_reason}
	var medicine:Variant=ship.goods.get("medicines",0)
	var reward:=int(medicine)*400
	var delivery_reason:=error
	if delivery_reason.is_empty():
		if ship.delivered:delivery_reason="Учебная доставка уже завершена."
		elif int(medicine)<=0:delivery_reason="Нет лекарств для учебной доставки."
		elif state.credits+reward>MAX_CREDITS:delivery_reason="Превышен предел счёта."
	state.delivery={"reward":reward,"can_deliver":delivery_reason.is_empty(),"reason":delivery_reason}
	for id in ship.economy_catalog.goods:
		var good:Dictionary=ship.economy_catalog.goods[id]
		var owned:=int(ship.goods.get(id,0));var price:=int(good.price);var sale:=floori(float(good.price)*0.8)
		var buy_reason:=error;var sell_reason:=error
		if buy_reason.is_empty():
			if state.credits<price:buy_reason="Недостаточно кредитов."
			elif state.cargo_used+1>state.cargo_capacity:buy_reason="Недостаточно места в трюме."
		if sell_reason.is_empty():
			if owned<=0:sell_reason="Нет этого товара в трюме."
			elif state.credits+sale>MAX_CREDITS:sell_reason="Превышен предел счёта."
		state.goods.append({"id":str(id),"name":str(good.name),"owned":owned,"buy_price":price,"sell_price":sale,"can_buy":buy_reason.is_empty(),"can_sell":sell_reason.is_empty(),"buy_reason":buy_reason,"sell_reason":sell_reason})
	for candidate in ship.catalog.all():
		var id:String=str(candidate.id)
		var trade_reason:String=error if not available else ship.trade_ship_error(id)
		var trade_cost:=int(ship.economy_catalog.ship_prices[id])-int(ship.ship_trade_value())
		state.ships.append({"id":id,"name":str(candidate.name),"cargo_capacity":int(candidate.cargo_capacity),"trade_cost":trade_cost,"can_trade":trade_reason.is_empty(),"current":str(ship.ship_id)==id,"reason":trade_reason})
	return state

static func execute(ship:RefCounted,nav:RefCounted,action:String,id:="")->Dictionary:
	var result:Dictionary={"ok":false,"status":"unavailable","message":"Служба недоступна.","ship_changed":false}
	if action not in ["buy","sell","repair","refuel","deliver","trade_ship"]:
		result.status="unknown_action";result.message="Неизвестная служба.";return result
	if _native_navigation(nav):
		var source_state:=_source_refuel_state(ship,nav,_source_refuel_context(ship,nav))
		if action!="refuel":result.message="В этом космопорте доступна базовая заправка.";return result
		if not source_state.refuel.can_refuel:result.message=source_state.refuel.reason;return result
		result.ok=nav.refuel(ship);result.message="Гипертопливо пополнено." if result.ok else "Заправка недоступна."
		if result.ok:result.status="completed"
		return result
	var error:=_service_error(ship,nav)
	if not error.is_empty():result.message=error;return result
	var state:=service_state(ship,nav)
	if not str(state.context_error).is_empty():result.message=state.context_error;return result
	if action=="repair":
		var repair_result:=repair(ship)
		for key in repair_result:result[key]=repair_result[key]
		return result
	if action=="refuel":
		if not state.refuel.can_refuel:result.message=state.refuel.reason;return result
		result.ok=nav.refuel(ship);result.message="Гипертопливо пополнено." if result.ok else "Заправка недоступна."
	elif action=="deliver":
		if not state.delivery.can_deliver:result.message=state.delivery.reason;return result
		result.ok=ship.deliver();result.message="Учебная доставка завершена." if result.ok else "Доставка недоступна."
	elif action=="trade_ship":
		var found:=false
		for entry in state.ships:
			if entry.id!=id:continue
			found=true
			if not entry.can_trade:result.message=entry.reason;return result
		if not found:result.status="unknown_item";result.message="Неизвестный корабль.";return result
		result.ok=ship.trade_ship(id);result.ship_changed=result.ok;result.message="Корабль заменён." if result.ok else "Обмен недоступен."
	else:
		var found:=false
		for entry in state.goods:
			if entry.id!=id:continue
			found=true
			if action=="buy" and not entry.can_buy:result.message=entry.buy_reason;return result
			if action=="sell" and not entry.can_sell:result.message=entry.sell_reason;return result
		if not found:result.status="unknown_item";result.message="Неизвестный товар.";return result
		result.ok=ship.buy(id,1) if action=="buy" else ship.sell(id,1)
		result.message=("Груз загружен." if action=="buy" else "Груз продан.") if result.ok else "Операция с грузом недоступна."
	if result.ok:result.status="completed"
	return result
