extends RefCounted
## Each legal command evaluates named flight facts, then advances to a declared stage.

const COURIER_ID := "operation-red-kite-408"
const RELAY_ID := "operation-quiet-array"
const HOME := 0
const VELAR := 1
const VELAR_PORT := 10
const SLATE := 7
const RELAY_ANCHOR := 13
const TOOL_PRICE := 120
const COURIER_HULL := 72.0
const PROGRAMS := {
	"signal": {
		"title": "Сигнал подо льдом", "issuer": HOME, "reward": 510, "limit": 1500.0,
		"nodes": {
			"offer": {"text": "Диспетчер Маяка-7 просит проверить подлёдный сигнал на Сланце. Задание доступно после первой доставки.",
				"actions": [["accept", "Принять экспедицию", "issue_unlocked", "scan"]]},
			"scan": {"text": "Подойдите к Сланцу и нажмите «Выполнить замер», чтобы записать подлёдный сигнал.", "site": SLATE,
				"actions": [["survey", "Выполнить замер", "survey", "choice"]]},
			"choice": {"text": "Кому передать данные? Исследователи ждут в порту «Створ», портовая служба — на Маяке-7.",
				"actions": [["research", "Научной станции", "free", "research"], ["safety", "Портовой службе", "free", "safety"]]},
			"research": {"text": "Доставьте запись подлёдного сигнала исследователям в порту «Створ».", "site": VELAR_PORT,
				"actions": [["report", "Сдать запись исследователям", "at_site", "done_research"]]},
			"safety": {"text": "Доставьте запись подлёдного сигнала портовой службе Маяка-7.", "site": HOME,
				"actions": [["report", "Сдать запись портовой службе", "at_site", "done_safety"]]},
			"done_research": {"text": "Подлёдный сигнал внесён в научный каталог Створа."},
			"done_safety": {"text": "Портовая служба Маяка-7 взяла район подлёдного сигнала под наблюдение."},
		},
	},
	"courier": {
		"title": "Красный коршун · РК-408", "issuer": HOME, "reward": 740, "limit": 960.0,
		"nodes": {
			"offer": {"text": "Разведка выяснила, когда вооружённый курьер РК-408 пройдёт через систему «Велар». Его нужно перехватить.",
				"actions": [["accept", "Принять срочный перехват", "issue", "intercept"]]},
			"intercept": {"text": "Перехватите РК-408 у Просеки. После принятия заказа судно появится через 35 с, а через 6 мин покинет район.", "site": RELAY_ANCHOR},
			"report": {"text": "РК-408 перехвачен. Сдайте отчёт на Маяке-7.", "site": HOME,
				"actions": [["report", "Сдать отчёт о перехвате", "at_site", "done"]]},
			"done": {"text": "Отчёт о перехвате РК-408 принят. Награда выплачена."},
		},
	},
	"relay": {
		"title": "Тихая решётка", "issuer": VELAR_PORT, "reward": 860, "limit": 1100.0,
		"nodes": {
			"offer": {"text": "Веларская лига предлагает вывести из строя нелегальный передатчик возле Просеки.",
				"actions": [["buy", "Установить глушитель · 120 кр.", "buy_tool", "offer"],
					["accept", "Принять задание", "issue_tool", "neutralize"]]},
			"neutralize": {"text": "Подойдите к передатчику на расстояние до 180 м и наведите на него нос. Для работы глушителя нужна прямая видимость.", "site": RELAY_ANCHOR,
				"actions": [["disable", "Заглушить установку", "can_disrupt", "report"]]},
			"report": {"text": "Передатчик отключён. Сдайте запись в порту «Створ».", "site": VELAR_PORT,
				"actions": [["report", "Сдать запись об отключении", "at_site", "done"]]},
			"done": {"text": "Помехи исчезли. Веларская лига приняла запись и выплатила награду."},
		},
	},
}

var _records: Dictionary = {}
var _disruptor := false


func deadline() -> float:
	var next := INF
	for id: String in _records:
		var record: Dictionary = _records[id]
		if _terminal(record.stage):
			continue
		var limit := float(record.started) + float(PROGRAMS[id].limit)
		if id == "courier" and record.stage == "intercept":
			limit = minf(limit, float(record.started) + 360.0)
		next = minf(next, limit)
	return next


func expire(epoch: float) -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	for id: String in _records:
		var record: Dictionary = _records[id]
		if _terminal(record.stage):
			continue
		var window := 360.0 if id == "courier" and record.stage == "intercept" else float(PROGRAMS[id].limit)
		if epoch >= float(record.started) + window:
			record.stage = "expired"
			record.changed = epoch
			notices.append(_result("operation_expired", "Срок задания «%s» истёк." % PROGRAMS[id].title))
	return notices


func status(sim: RefCounted, id: String) -> Dictionary:
	var program: Dictionary = PROGRAMS.get(id, {})
	if program.is_empty():
		return {}
	var record: Dictionary = _records.get(id, {})
	var stage := str(record.get("stage", "offer"))
	var node: Dictionary = program.nodes.get(stage, {})
	var state := {"title": program.title, "stage": stage, "reward": program.reward,
		"text": str(node.get("text", "Срок операции истёк.")), "time": 0.0,
		"site": int(node.get("site", program.issuer if stage == "offer" else -1)),
		"actions": [], "contact": {}, "hint": ""}
	if stage == "expired":
		state.site = program.issuer
		state.actions = [{"id": "renew", "name": "Взять новое поручение",
			"enabled": _fact(sim, id, int(state.site), "issue")}]
	if stage != "offer" and not _terminal(stage):
		var window := 360.0 if id == "courier" and stage == "intercept" else float(program.limit)
		state.time = maxf(0.0, float(record.started) + window - float(sim.orbit_time))
	for step: Array in node.get("actions", []):
		var option := {"id": step[0], "name": step[1], "enabled": _fact(sim, id, state.site, step[2])}
		if step[0] != "buy" or not _disruptor:
			state.actions.append(option)
	if id == "courier" and stage == "intercept":
		state.contact = courier(sim)
	if id == "relay" and stage == "neutralize":
		state.contact = relay(sim)
		state.hint = disruption_hint(sim)
	return state


func perform(sim: RefCounted, id: String, command: String) -> Dictionary:
	var program: Dictionary = PROGRAMS.get(id, {})
	if program.is_empty():
		return {}
	var state := status(sim, id)
	if state.stage == "expired" and command == "renew" and _fact(sim, id, int(state.site), "issue"):
		_records.erase(id)
		return _result("operation_progress", "Поручение снова доступно.")
	if state.is_empty() or (state.stage != "offer" and state.time <= 0.0):
		return {}
	var node: Dictionary = program.nodes.get(state.stage, {})
	for step: Array in node.get("actions", []):
		if step[0] != command or not _fact(sim, id, state.site, step[2]):
			continue
		if command == "buy":
			_disruptor = true
			return _result("operation_equipment", "Глушитель установлен.", -TOOL_PRICE)
		if command == "survey":
			var dossier: Dictionary = sim.body_dossier(state.site)
			if not dossier.known and not sim.survey_action(state.site):
				return {}
		var payment := int(program.reward) if command == "report" else 0
		if int(sim.credits) > 1000000000 - payment:
			return {}
		var record: Dictionary = _records.get(id, {"started": sim.orbit_time, "stage": "", "changed": sim.orbit_time,
			"hull": COURIER_HULL if id == "courier" else 0.0})
		record.stage = step[3]
		record.changed = sim.orbit_time
		_records[id] = record
		var message := str(program.nodes[record.stage].text)
		return _result("operation_paid" if payment > 0 else "operation_progress", message, payment)
	return {}


func courier(sim: RefCounted) -> Dictionary:
	var record: Dictionary = _records.get("courier", {})
	if record.get("stage") != "intercept" or sim.system_id != VELAR:
		return {}
	var age := float(sim.orbit_time) - float(record.started)
	if age < 35.0 or age >= 360.0:
		return {}
	var phase := (age - 35.0) * 0.032
	var orbit := Vector3(cos(phase) * 145.0, sin(phase) * 21.0, sin(phase) * 145.0)
	var drift := Vector3(-sin(phase) * 145.0, cos(phase) * 21.0, cos(phase) * 145.0) * 0.032
	return {"id": COURIER_ID, "name": "Красный коршун · РК-408", "role": "raider", "channel": "operation",
		"position": sim.target_position(RELAY_ANCHOR) + orbit, "velocity": sim.target_velocity(RELAY_ANCHOR) + drift,
		"hull": float(record.hull)}


func relay(sim: RefCounted) -> Dictionary:
	var record: Dictionary = _records.get("relay", {})
	if record.get("stage") not in ["neutralize", "report", "done"] or sim.system_id != VELAR:
		return {}
	return {"id": RELAY_ID, "name": "Ретранслятор «Тихая решётка»", "role": "relay",
		"position": sim.target_position(RELAY_ANCHOR) + Vector3(63.0, 155.0, 45.0),
		"velocity": sim.target_velocity(RELAY_ANCHOR), "hull": 100.0 if record.stage == "neutralize" else 0.0}


func disruption_hint(sim: RefCounted) -> String:
	var contact := relay(sim)
	if not _disruptor or contact.is_empty() or sim.docked >= 0 or sim.landed or sim.jump_seconds_left > 0.0:
		return "Выйдите в открытый космос и подойдите к передатчику, чтобы включить глушитель."
	var offset: Vector3 = contact.position - sim.position
	if offset.length() > 180.0 or offset.length() < 1.0:
		return "До передатчика %.0f м. Держитесь на расстоянии 1–180 м." % offset.length()
	if sim.forward().dot(offset.normalized()) < 0.94:
		return "Наведите нос корабля на отметку установки."
	if not sim.combat_line_clear(sim.position, contact.position):
		return "Между кораблём и установкой есть препятствие."
	return ""


func hit_courier(sim: RefCounted, id: String, damage: float) -> Dictionary:
	var contact := courier(sim)
	if id != COURIER_ID or damage <= 0.0 or contact.is_empty():
		return {}
	var record: Dictionary = _records["courier"]
	record.hull = maxf(0.0, float(record.hull) - damage)
	record.changed = sim.orbit_time
	if record.hull > 0.0:
		return _result("operation_hit", "Попадание по РК-408. Целостность корпуса %.0f%%." % (float(record.hull) / COURIER_HULL * 100.0))
	record.stage = "report"
	return _result("operation_intercepted", "РК-408 перехвачен. Вернитесь с докладом на Маяк-7.")


func counterfire(sim: RefCounted, dt: float) -> Dictionary:
	var contact := courier(sim)
	if contact.is_empty() or sim.docked >= 0 or sim.landed:
		return {}
	var next_shot := floori(float(sim.orbit_time) / 5.0)
	var previous_shot := floori((float(sim.orbit_time) - dt) / 5.0)
	if next_shot == previous_shot or sim.position.distance_squared_to(contact.position) > 175.0 * 175.0:
		return {}
	if not sim.combat_line_clear(contact.position, sim.position):
		return {}
	return {"damage": 4.5, "source": contact.position, "message": "РК-408 открыл ответный огонь."}


func snapshot() -> Dictionary:
	return {"disruptor": _disruptor, "records": _records.duplicate(true)}


func restore(raw: Variant, epoch: float) -> bool:
	if not raw is Dictionary or raw.size() != 2 or not raw.get("disruptor") is bool or not raw.get("records") is Dictionary:
		return false
	var records := {}
	for id: Variant in raw.records:
		if not PROGRAMS.has(id):
			return false
		var data: Variant = raw.records[id]
		if not data is Dictionary or data.size() != 4 or not data.get("stage") is String:
			return false
		var stage: String = data.stage
		if stage == "offer" or (stage != "expired" and not PROGRAMS[id].nodes.has(stage)):
			return false
		if not _number(data.get("started"), 0.0, epoch) or not _number(data.get("changed"), float(data.started), epoch):
			return false
		if not _number(data.get("hull"), 0.0, COURIER_HULL if id == "courier" else 0.0):
			return false
		if id == "relay" and not raw.disruptor:
			return false
		if id == "courier" and ((stage == "intercept" and data.hull <= 0.0) or (stage in ["report", "done"] and data.hull != 0.0)):
			return false
		var window := 360.0 if id == "courier" and stage == "intercept" else float(PROGRAMS[id].limit)
		if not _terminal(stage) and epoch >= float(data.started) + window:
			return false
		if stage == "expired":
			var expired_window := 360.0 if id == "courier" and float(data.hull) > 0.0 else float(PROGRAMS[id].limit)
			if float(data.changed) < float(data.started) + expired_window:
				return false
		if stage.begins_with("done") and float(data.changed) >= float(data.started) + window:
			return false
		records[id] = {"stage": stage, "started": float(data.started), "changed": float(data.changed), "hull": float(data.hull)}
	_disruptor = raw.disruptor
	_records = records
	return true


func _fact(sim: RefCounted, id: String, site: int, key: String) -> bool:
	var port := int(PROGRAMS[id].issuer)
	var issuing: bool = sim.docked == port and sim.station_services_available()
	match key:
		"issue": return issuing
		"issue_unlocked": return issuing and sim.deliveries > 0
		"at_site": return sim.docked == site and sim.station_services_available()
		"buy_tool": return issuing and not _disruptor and sim.credits >= TOOL_PRICE
		"issue_tool": return issuing and _disruptor and sim.factions.owner(sim.system_id) == 1
		"free": return sim.jump_seconds_left <= 0.0
		"survey":
			var dossier: Dictionary = sim.body_dossier(site)
			if dossier.can_scan:
				return true
			return dossier.known and dossier.in_system and sim.jump_seconds_left <= 0.0 and sim.docked < 0 \
				and (sim.landed_site == site or (dossier.range <= dossier.scan_limit and dossier.relative_speed <= 34.0))
		"can_disrupt": return disruption_hint(sim).is_empty()
	return false


static func _terminal(stage: String) -> bool:
	return stage == "expired" or stage.begins_with("done")


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


static func _result(event: String, message: String, credits := 0) -> Dictionary:
	return {"ok": true, "event": event, "message": message, "credits": credits}
