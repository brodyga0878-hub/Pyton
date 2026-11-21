extends RefCounted
## Radio responses use actual local contacts and the authority with an open case.

const Law := preload("res://scripts/law_network.gd")
const EMERGENCY_FUEL := 6.0
const TRANSFER_RANGE := 260.0


static func status(sim: RefCounted, network: RefCounted, id: String, receipt: String) -> Dictionary:
	var selected := _contact(sim, id)
	var law: Dictionary = sim.law_status()
	var station: bool = sim.station_services_available()
	var patrol: Dictionary = network.contact(sim)
	var in_radio_range: bool = not patrol.is_empty() and sim.position.distance_to(patrol.position) <= Law.RADIO_RANGE
	var authorized: bool = (station or in_radio_range) and int(law.authority) >= 0 and sim.jump_seconds_left <= 0.0
	var customs: Dictionary = sim.customs.status(int(law.authority))
	var debt := int(law.debt) + int(customs.debt)
	if authorized and (int(law.wanted) > 0 or debt > 0 or law.detained) \
			and (selected.is_empty() or id == Law.PATROL_ID or law.detained):
		return _law_status(sim, law, station, debt, receipt)
	var commands: Array[Dictionary] = []
	var title := str(selected.get("name", "Диспетчерская связь"))
	var detail := "Выберите корабль в списке целей или вызовите помощь."
	if not selected.is_empty():
		detail = "Канал открыт · дистанция %.0f м." % sim.position.distance_to(selected.position)
	elif not id.is_empty():
		detail = "Выбранный контакт вне зоны связи."
	var radio: bool = not selected.is_empty() and sim.jump_seconds_left <= 0.0
	var port := _route_port(sim)
	commands.append(_command("report", "Запросить данные", radio, "Выберите корабль в пределах 1,8 км."))
	commands.append(_command("route", "Маршрут к порту", radio and not selected.get("hostile", false) and port >= 0,
		"Нужны дружественный корабль в зоне связи и действующий порт."))
	var aid: bool = network.distress_available(sim.orbit_time) and _airborne(sim) and sim.ship.fuel < EMERGENCY_FUEL \
		and not _responder(sim).is_empty()
	commands.append(_command("distress", "Вызвать помощь", aid,
		"Нужны топливо ниже 6 ед., дружественный корабль в пределах 260 м и пауза 360 с между запросами."))
	return {"title": title, "summary": detail, "receipt": receipt, "actions": commands}


static func _law_status(sim: RefCounted, law: Dictionary, station: bool, debt: int, receipt: String) -> Dictionary:
	var commands: Array[Dictionary] = []
	var detail := "Розыск %d · взыскания %d кр." % [int(law.wanted), debt]
	if not str(law.last_name).is_empty():
		detail += "\nПоследняя запись: %s." % str(law.last_name)
	if law.phase == "challenge":
		detail += " Срок ответа %d с." % ceili(float(law.remaining))
	if law.detained:
		detail += " Освобождение через %d с или после урегулирования." % ceili(maxf(0.0, float(law.release_at) - sim.orbit_time))
	var negotiation: bool = law.phase == "negotiation" or station
	if not station:
		commands.append(_command("answer", "Ответить дозору", bool(law.can_answer), "Данные уже переданы."))
	commands.append(_command("pay", "Оплатить взыскания", negotiation and debt > 0 and sim.credits > 0,
		"Для оплаты нужны средства и открытые переговоры."))
	if int(law.wanted) > 0:
		commands.append(_command("contest", "Оспорить", negotiation and not law.appealed,
			"Возражение доступно один раз после ответа или в порту."))
		commands.append(_command("bribe", "Предложить 120 кр.", negotiation and not law.bribed and sim.credits >= 120,
			"Недостаточно средств или предложение уже сделано."))
	commands.append(_command("release", "Закрыть дело" if not law.detained else "Освободиться",
		negotiation and ((bool(law.detained) and sim.orbit_time >= float(law.release_at)) or (int(law.wanted) > 0 and debt == 0)),
		"Погасите взыскания или дождитесь окончания задержания."))
	return {"title": "Служба порядка · %s" % str(law.name), "summary": detail, "receipt": receipt, "actions": commands}


static func execute(sim: RefCounted, network: RefCounted, action: String, id: String) -> Dictionary:
	var available := false
	for command: Dictionary in status(sim, network, id, "").actions:
		if command.id == action and command.enabled:
			available = true
			break
	if not available:
		return {}
	var owner := int(sim.law_status().authority)
	var customs: Dictionary = sim.customs.status(owner)
	match action:
		"answer": return network.answer(sim.orbit_time)
		"pay":
			var criminal: Dictionary = network.pay(owner, sim.credits)
			if not criminal.is_empty():
				return criminal
			var receipt: Dictionary = sim.customs.pay(owner, sim.credits)
			if receipt.get("ok", false):
				receipt.event = "law_paid"
			return receipt
		"contest": return network.contest(owner, int(customs.debt) == 0)
		"bribe": return network.bribe(owner, sim.credits, sim.orbit_time)
		"release": return network.release(owner, int(customs.debt), sim.orbit_time)
		"report":
			var contact := _contact(sim, id)
			var motion: Vector3 = contact.velocity
			var reply := "Принимаю только опознавательные запросы." if contact.get("hostile", false) else "Могу передать координаты порта."
			return _response("comms_report", "«%s». Скорость %.0f м/с, корпус %.0f%%. %s" % [
				contact.name, motion.length(), float(contact.get("hull", 100.0)), reply])
		"route":
			var port := _route_port(sim)
			return _response("comms_route", "В навигацию передан курс на «%s»." % sim.target_name(port)) if sim.select_target(port) else {}
		"distress":
			var helper := _responder(sim)
			if not helper.is_empty() and network.note_distress(sim.orbit_time):
				var amount: float = sim.ship.add_fuel(EMERGENCY_FUEL - sim.ship.fuel)
				return _response("comms_distress", "«%s» передал %.1f ед. аварийного топлива прямо в бак." % [helper.name, amount])
	return {}


static func _contact(sim: RefCounted, id: String) -> Dictionary:
	if id.is_empty() or sim.jump_seconds_left > 0.0:
		return {}
	for candidate: Dictionary in sim.traffic_contacts():
		if candidate.id == id and sim.position.distance_to(candidate.position) <= Law.RADIO_RANGE:
			return candidate
	return {}


static func _route_port(sim: RefCounted) -> int:
	var best := -1
	var minimum := INF
	for candidate: int in sim.local_ports():
		if candidate in [sim.docked, sim.landed_site]:
			continue
		var distance: float = sim.position.distance_squared_to(sim.target_position(candidate))
		if distance < minimum:
			minimum = distance
			best = candidate
	return best


static func _airborne(sim: RefCounted) -> bool:
	return sim.docked < 0 and not sim.landed and sim.jump_seconds_left <= 0.0 and sim.ship.hull > 1.0


static func _responder(sim: RefCounted) -> Dictionary:
	if not _airborne(sim):
		return {}
	var result := {}
	var range_limit := TRANSFER_RANGE
	for contact: Dictionary in sim.traffic_contacts():
		if contact.id == Law.PATROL_ID or contact.get("hostile", false) or contact.role not in ["patrol", "trader"]:
			continue
		var distance: float = sim.position.distance_to(contact.position)
		if distance < range_limit:
			range_limit = distance
			result = contact
	return result


static func _command(id: String, label: String, enabled: bool, reason: String) -> Dictionary:
	return {"id": id, "label": label, "enabled": enabled, "reason": "" if enabled else reason}


static func _response(event: String, message: String) -> Dictionary:
	return {"ok": true, "event": event, "credits": 0, "message": message}
