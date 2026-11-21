extends RefCounted
## Pilot combat record, independent faction standings, and one open service dispatch.

const Catalog := preload("res://scripts/sector_catalog.gd")
const Factions := preload("res://scripts/faction_fronts.gd")

const ROLE_NAME := "Служебный курьер"
const DISPATCH_NAME := "Служебная депеша"
const DISPATCH_TRUST := 2
const DISPATCH_SERVICE := 1
const DISPATCH_CREDITS := 300
const DISPATCH_DURATION := 180.0
const TRUST_LIMIT := 24
const SERVICE_LIMIT := 1000
const COMBAT_LIMIT := 1000000
const MAX_EPOCH := 3155760000.0
const TIME_PRECISION := 0.000002
const COMBAT_THRESHOLDS := [0, 1, 3, 7]
const COMBAT_TITLES := ["Без боевых отметок", "Боевой пилот", "Перехватчик", "Ведущий звена"]
const SERVICE_THRESHOLDS := [0, DISPATCH_SERVICE, 3, 6]
const SERVICE_TITLES := ["Гражданский пилот", "Резервист", "Связной", "Координатор службы"]
const SAVE_FIELDS := ["trust", "service", "combat", "patrol", "dispatch"]
const PATROL_FIELDS := ["issuer", "origin", "victory"]
const DISPATCH_FIELDS := ["issuer", "origin", "destination", "accepted_at", "deadline"]

var _trust: Array[int] = [0, 0]
var _service: Array[int] = [0, 0]
var _combat := 0
var _patrol: Dictionary = {}
var _dispatch: Dictionary = {}


func status() -> Dictionary:
	var factions: Array[Dictionary] = []
	for issuer in range(_trust.size()):
		var grade := _rank(_service[issuer], SERVICE_THRESHOLDS)
		var reason := _dispatch_requirement(issuer)
		factions.append({
			"id": issuer, "name": Factions.faction_name(issuer), "trust": _trust[issuer],
			"service_points": _service[issuer], "service_rank": grade, "service_title": SERVICE_TITLES[grade],
			"dispatch_role": reason.is_empty(), "dispatch_reason": reason,
		})
	var grade := _rank(_combat, COMBAT_THRESHOLDS)
	return {
		"combat_points": _combat, "combat_rank": grade, "combat_title": COMBAT_TITLES[grade],
		"factions": factions, "patrol_issuer": _patrol.get("issuer", -1),
	}


func note_patrol_accept(issuer: int, origin: int, victory := false) -> bool:
	if not _patrol.is_empty() or not _integer(issuer, -1, Factions.FACTIONS.size() - 1) or not Catalog.is_port(origin):
		return false
	# A migration may attach an already finished fight without awarding it again.
	_patrol = {"issuer": issuer, "origin": origin, "victory": victory}
	return true


func note_patrol_victory() -> bool:
	if _patrol.is_empty() or _patrol.victory:
		return false
	_patrol.victory = true
	note_ambient_victory()
	return true


func note_patrol_report(port: int) -> bool:
	if _patrol.is_empty() or not _patrol.victory or port != int(_patrol.origin):
		return false
	var issuer: int = _patrol.issuer
	_patrol.clear()
	if _valid_faction(issuer):
		_award_service(issuer, 1, 1)
	return true


func note_ambient_victory() -> void:
	_combat = mini(COMBAT_LIMIT, _combat + 1)


func note_delivery(issuer: int) -> bool:
	if not _valid_faction(issuer):
		return false
	_change_trust(issuer, 1)
	return true


func note_convoy_result(issuer: int, target: int, kind: String, completed: bool) -> bool:
	if not _valid_faction(issuer) or not _valid_faction(target):
		return false
	if not ((kind == "escort" and issuer == target) or (kind == "intercept" and issuer != target)):
		return false
	if not completed:
		_change_trust(issuer, -2)
		return true
	_award_service(issuer, 1, 2)
	if kind == "intercept":
		_change_trust(target, -2)
		note_ambient_victory()
	return true


func note_customs_violation(issuer: int) -> bool:
	if not _valid_faction(issuer):
		return false
	_change_trust(issuer, -2)
	return true


func note_story_result(trust: Dictionary) -> void:
	for issuer: int in range(_trust.size()):
		_change_trust(issuer, int(trust.get(issuer, 0)))


func dispatch_offer(issuer: int, origin: int, destination: int, epoch: float) -> Dictionary:
	var reason := ""
	if not _valid_faction(issuer) or not _valid_route(origin, destination):
		reason = "Между этими портами нет служебного маршрута."
	elif not _dispatch.is_empty():
		reason = "На борту уже есть служебная депеша."
	elif not _valid_epoch(epoch) or epoch > MAX_EPOCH - DISPATCH_DURATION:
		reason = "Невозможно назначить срок доставки."
	else:
		reason = _dispatch_requirement(issuer)
	return {
		"allowed": reason.is_empty(), "reason": reason, "name": DISPATCH_NAME,
		"issuer": issuer, "origin": origin, "destination": destination,
		"duration": DISPATCH_DURATION, "reward": DISPATCH_CREDITS,
	}


func accept_dispatch(issuer: int, origin: int, destination: int, epoch: float) -> Dictionary:
	var offer := dispatch_offer(issuer, origin, destination, epoch)
	if not offer.allowed:
		return _rejected(offer.reason)
	_dispatch = {
		"issuer": issuer, "origin": origin, "destination": destination,
		"accepted_at": epoch, "deadline": epoch + DISPATCH_DURATION,
	}
	return _result("career_dispatch_accepted", "Служебная депеша на борту. Доставьте её в порт «%s»." % Catalog.site(destination).name)


func dispatch_status(epoch: float) -> Dictionary:
	var active := not _dispatch.is_empty()
	var remaining := maxf(0.0, float(_dispatch.deadline) - epoch) if active and _valid_epoch(epoch) else 0.0
	return {
		"active": active, "name": DISPATCH_NAME, "reward": DISPATCH_CREDITS,
		"issuer": _dispatch.get("issuer", -1), "origin": _dispatch.get("origin", -1),
		"destination": _dispatch.get("destination", -1), "accepted_at": _dispatch.get("accepted_at", 0.0),
		"deadline": _dispatch.get("deadline", 0.0), "remaining": remaining,
	}


func next_event_time() -> float:
	return float(_dispatch.deadline) if not _dispatch.is_empty() else INF


func advance(epoch: float) -> Dictionary:
	if _dispatch.is_empty() or not _valid_epoch(epoch) or epoch < float(_dispatch.deadline):
		return {}
	var issuer: int = _dispatch.issuer
	_dispatch.clear()
	_change_trust(issuer, -2)
	return _result("career_dispatch_expired", "Срок доставки депеши истёк. Доверие фракции снизилось.")


func finish_dispatch(port: int, epoch: float) -> Dictionary:
	if _dispatch.is_empty():
		return _rejected("На борту нет служебной депеши.")
	if not _valid_epoch(epoch) or epoch < float(_dispatch.accepted_at):
		return _rejected("Время доставки указано неверно.")
	var expiry := advance(epoch)
	if not expiry.is_empty():
		return expiry
	if port != int(_dispatch.destination):
		return _rejected("Сдайте депешу в порту «%s»." % Catalog.site(int(_dispatch.destination)).name)
	var issuer: int = _dispatch.issuer
	_dispatch.clear()
	_award_service(issuer, 1, 1)
	return _result("career_dispatch_paid", "Депеша доставлена. Получено %d кр." % DISPATCH_CREDITS, DISPATCH_CREDITS)


func snapshot() -> Dictionary:
	return {
		"trust": _trust.duplicate(), "service": _service.duplicate(), "combat": _combat,
		"patrol": _patrol.duplicate(), "dispatch": _dispatch.duplicate(),
	}


func restore(raw: Variant, epoch: float) -> bool:
	if not _valid_epoch(epoch) or not raw is Dictionary or not _exact_fields(raw, SAVE_FIELDS):
		return false
	if not _valid_faction_values(raw.trust, -TRUST_LIMIT, TRUST_LIMIT) or not _valid_faction_values(raw.service, 0, SERVICE_LIMIT):
		return false
	if not _integer(raw.combat, 0, COMBAT_LIMIT) or not _valid_patrol(raw.patrol) or not _valid_dispatch(raw.dispatch, epoch):
		return false
	_trust.assign(raw.trust)
	_service.assign(raw.service)
	_combat = int(raw.combat)
	_patrol = raw.patrol.duplicate()
	_dispatch = raw.dispatch.duplicate()
	if not _patrol.is_empty():
		_patrol.issuer = int(_patrol.issuer)
		_patrol.origin = int(_patrol.origin)
	if not _dispatch.is_empty():
		_dispatch.issuer = int(_dispatch.issuer)
		_dispatch.origin = int(_dispatch.origin)
		_dispatch.destination = int(_dispatch.destination)
	return true


func _dispatch_requirement(issuer: int) -> String:
	if _service[issuer] < DISPATCH_SERVICE:
		return "Нужен служебный ранг «%s»." % SERVICE_TITLES[1]
	if _trust[issuer] < DISPATCH_TRUST:
		return "Нужно доверие не ниже %d." % DISPATCH_TRUST
	return ""


func _award_service(issuer: int, points: int, trust: int) -> void:
	_service[issuer] = mini(SERVICE_LIMIT, _service[issuer] + points)
	_change_trust(issuer, trust)


func _change_trust(issuer: int, amount: int) -> void:
	_trust[issuer] = clampi(_trust[issuer] + amount, -TRUST_LIMIT, TRUST_LIMIT)


static func _valid_patrol(raw: Variant) -> bool:
	return raw is Dictionary and (raw.is_empty() or (_exact_fields(raw, PATROL_FIELDS)
		and _integer(raw.issuer, -1, Factions.FACTIONS.size() - 1) and raw.victory is bool
		and _integer(raw.origin, 0, Catalog.DESTINATION_COUNT - 1) and Catalog.is_port(int(raw.origin))))


static func _valid_dispatch(raw: Variant, epoch: float) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return true
	if not _exact_fields(raw, DISPATCH_FIELDS) or not _integer(raw.issuer, 0, Factions.FACTIONS.size() - 1):
		return false
	if not _integer(raw.origin, 0, Catalog.DESTINATION_COUNT - 1) or not _integer(raw.destination, 0, Catalog.DESTINATION_COUNT - 1):
		return false
	if not _valid_route(int(raw.origin), int(raw.destination)):
		return false
	if not _epoch_value(raw.accepted_at) or not _epoch_value(raw.deadline):
		return false
	return raw.accepted_at <= epoch + TIME_PRECISION \
		and absf(float(raw.deadline) - (float(raw.accepted_at) + DISPATCH_DURATION)) <= TIME_PRECISION


static func _valid_route(origin: int, destination: int) -> bool:
	return origin != destination and Catalog.is_port(origin) and Catalog.is_port(destination) \
		and Catalog.system_of_site(origin) == Catalog.system_of_site(destination)


static func _valid_faction_values(raw: Variant, low: int, high: int) -> bool:
	if not raw is Array or raw.size() != Factions.FACTIONS.size():
		return false
	for value in raw:
		if not _integer(value, low, high):
			return false
	return true


static func _valid_faction(issuer: int) -> bool:
	return issuer >= 0 and issuer < Factions.FACTIONS.size()


static func _rank(points: int, thresholds: Array) -> int:
	for grade in range(thresholds.size() - 1, 0, -1):
		if points >= int(thresholds[grade]):
			return grade
	return 0


static func _epoch_value(value: Variant) -> bool:
	return (value is float or value is int) and _valid_epoch(float(value))


static func _valid_epoch(epoch: float) -> bool:
	return is_finite(epoch) and epoch >= 0.0 and epoch <= MAX_EPOCH


static func _exact_fields(raw: Dictionary, fields: Array) -> bool:
	return raw.size() == fields.size() and raw.has_all(fields)


static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and value >= low and value <= high and value == int(value)


static func _rejected(message: String) -> Dictionary:
	return {"ok": false, "event": "", "message": message, "credits": 0}


static func _result(event: String, message: String, credits := 0) -> Dictionary:
	return {"ok": true, "event": event, "message": message, "credits": credits}
