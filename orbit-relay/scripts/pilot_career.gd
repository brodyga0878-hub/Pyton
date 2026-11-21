extends RefCounted
## Combat distinctions, wanted-ship awards, and separate military standings.

const Catalog := preload("res://scripts/sector_catalog.gd")
const Factions := preload("res://scripts/faction_fronts.gd")
const Ambient := preload("res://scripts/civilian_traffic.gd")

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
const COMBAT_THRESHOLDS := [0, 1, 3, 7, 15, 30, 60, 110, 180, 300]
const COMBAT_TITLES := ["Без боевых отметок", "Боевой пилот", "Перехватчик", "Ведущий звена",
	"Ветеран рубежа", "Командир звена", "Ас рубежа", "Мастер перехвата", "Гроза рейдеров", "Легенда рубежа"]
const SERVICE_THRESHOLDS := [0, DISPATCH_SERVICE, 3, 6]
const SERVICE_TITLES := ["Гражданский пилот", "Резервист", "Связной", "Координатор службы"]
const LEGACY_FIELDS := ["trust", "service", "combat", "patrol", "dispatch"]
const PATROL_FIELDS := ["issuer", "origin", "victory"]
const DISPATCH_FIELDS := ["issuer", "origin", "destination", "accepted_at", "deadline"]
const ORDER_FIELDS := ["kind", "issuer", "origin", "site", "accepted_at", "deadline", "proof_at"]
const BOUNTY_FIELDS := ["last_raiders", "awards", "credits"]
const ORDERS := {
	"recon": {"name": "Разведка рубежа", "service": 3, "trust": 3, "duration": 330.0, "reward": 650, "points": 2},
	"intercept": {"name": "Охрана сектора", "service": 6, "trust": 5, "duration": 540.0, "reward": 960, "points": 3},
}
const STANDING_SUSPENSION := -3
const MAX_BOUNTY_CREDITS := 1000000000

var _trust: Array[int] = [0, 0]
var _service: Array[int] = [0, 0]
var _combat := 0
var _patrol: Dictionary = {}
var _dispatch: Dictionary = {}
var _order: Dictionary = {}
var _last_raiders := _empty_raiders()
var _bounty_awards := 0
var _bounty_credits := 0


func status() -> Dictionary:
	var factions: Array[Dictionary] = []
	for issuer in range(_trust.size()):
		var grade := _service_grade(issuer)
		var reason := _dispatch_requirement(issuer)
		factions.append({
			"id": issuer, "name": Factions.faction_name(issuer), "trust": _trust[issuer],
			"service_points": _service[issuer], "service_rank": grade,
			"service_title": "Отстранён от службы" if _trust[issuer] <= STANDING_SUSPENSION else SERVICE_TITLES[grade],
			"dispatch_role": reason.is_empty(), "dispatch_reason": reason,
		})
	var grade := _rank(_combat, COMBAT_THRESHOLDS)
	return {
		"combat_points": _combat, "combat_rank": grade, "combat_title": COMBAT_TITLES[grade],
		"combat_next": COMBAT_THRESHOLDS[grade + 1] if grade + 1 < COMBAT_THRESHOLDS.size() else -1,
		"bounty_awards": _bounty_awards, "bounty_credits": _bounty_credits,
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
	_award_combat(1)
	return true


func note_patrol_report(port: int) -> bool:
	if _patrol.is_empty() or not _patrol.victory or port != int(_patrol.origin):
		return false
	var issuer: int = _patrol.issuer
	_patrol.clear()
	if _valid_faction(issuer):
		_award_service(issuer, 1, 1)
	return true


static func bounty_offer(system: int, cycle: int, owner: int) -> int:
	return 85 + system * 23 + (cycle % 4) * 8 if _valid_faction(owner) and system >= 0 \
		and system < Catalog.AUTHORED_SYSTEM_COUNT and cycle >= 0 and (cycle + system) % 3 == 1 else 0


func note_ambient_victory(system: int, cycle: int, owner: int, funds: int) -> Dictionary:
	if system < 0 or system >= _last_raiders.size() or cycle <= _last_raiders[system]:
		return {}
	_last_raiders[system] = cycle
	var bounty := bounty_offer(system, cycle, owner)
	_award_combat(2 if bounty > 0 else 1)
	var paid := mini(bounty, mini(maxi(0, funds), MAX_BOUNTY_CREDITS - _bounty_credits))
	if paid > 0:
		_bounty_awards = mini(COMBAT_LIMIT, _bounty_awards + 1)
		_bounty_credits += paid
	return {"paid": paid, "marked": bounty > 0}


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
		_award_combat(3)
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
	elif not _dispatch.is_empty() or not _order.is_empty():
		reason = "Уже принят служебный приказ."
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


func order_offer(kind: String, issuer: int, origin: int, site: int, epoch: float) -> Dictionary:
	if not ORDERS.has(kind):
		return {}
	var rule: Dictionary = ORDERS[kind]
	var reason := ""
	if not _valid_faction(issuer) or not _valid_order_route(kind, origin, site):
		reason = "В этом порту нет подходящей цели для приказа."
	elif not _dispatch.is_empty() or not _order.is_empty():
		reason = "Сначала завершите принятый приказ."
	elif _trust[issuer] <= STANDING_SUSPENSION:
		reason = "Служба приостановлена из-за низкого доверия."
	elif _service[issuer] < int(rule.service):
		reason = "Нужен ранг «%s»." % SERVICE_TITLES[_rank(int(rule.service), SERVICE_THRESHOLDS)]
	elif _trust[issuer] < int(rule.trust):
		reason = "Нужно доверие от %d." % int(rule.trust)
	elif not _valid_epoch(epoch) or epoch > MAX_EPOCH - float(rule.duration):
		reason = "Невозможно назначить срок операции."
	return {"kind": kind, "name": rule.name, "origin": origin, "issuer": issuer, "site": site,
		"duration": rule.duration, "reward": rule.reward, "allowed": reason.is_empty(), "reason": reason}


func accept_order(kind: String, issuer: int, origin: int, site: int, epoch: float) -> Dictionary:
	var offer := order_offer(kind, issuer, origin, site, epoch)
	if offer.is_empty() or not offer.allowed:
		return _rejected(str(offer.get("reason", "Приказ недоступен.")))
	_order = {"kind": kind, "issuer": issuer, "origin": origin, "site": site,
		"accepted_at": epoch, "deadline": epoch + float(offer.duration), "proof_at": -1.0}
	return _result("career_order_accepted", "Принят приказ «%s»." % offer.name)


func order_status(epoch: float) -> Dictionary:
	if _order.is_empty():
		return {"active": false, "kind": "", "issuer": -1, "origin": -1, "site": -1}
	var status := _order.duplicate()
	var rule: Dictionary = ORDERS[_order.kind]
	status.merge({"active": true, "name": rule.name, "reward": rule.reward,
		"proved": float(_order.proof_at) >= 0.0, "remaining": maxf(0.0, float(_order.deadline) - epoch)})
	return status


func prove_order(kind: String, system: int, epoch: float) -> bool:
	if _order.is_empty() or _order.kind != kind or float(_order.proof_at) >= 0.0 \
			or Catalog.system_of_site(int(_order.origin)) != system or not _valid_epoch(epoch) \
			or epoch < float(_order.accepted_at) or epoch >= float(_order.deadline):
		return false
	_order.proof_at = epoch
	return true


func finish_order(port: int, epoch: float) -> Dictionary:
	if _order.is_empty() or not _valid_epoch(epoch):
		return _rejected("Нет активного приказа.")
	var expiry := advance(epoch)
	if not expiry.is_empty():
		return expiry
	if port != int(_order.origin) or float(_order.proof_at) < 0.0 or epoch < float(_order.proof_at):
		return _rejected("Завершите операцию и вернитесь с докладом.")
	var issuer: int = _order.issuer
	var rule: Dictionary = ORDERS[_order.kind]
	var prior_grade := _service_grade(issuer)
	_order.clear()
	_award_service(issuer, int(rule.points), 2)
	return _result("career_order_paid", "Доклад принят. Получено %d кр.%s" % [int(rule.reward),
		_promotion(issuer, prior_grade)], int(rule.reward))


func cancel_lost_jurisdiction(owner: int) -> Dictionary:
	if not _order.is_empty() and owner != int(_order.issuer):
		_order.clear()
		return _result("career_order_removed", "Порт сменил владельца. Приказ отозван.")
	return {}


func next_event_time() -> float:
	if not _order.is_empty():
		return float(_order.deadline)
	return float(_dispatch.deadline) if not _dispatch.is_empty() else INF


func advance(epoch: float) -> Dictionary:
	if not _valid_epoch(epoch):
		return {}
	if not _order.is_empty():
		var war_issuer: int = _order.issuer
		if _trust[war_issuer] <= STANDING_SUSPENSION:
			_order.clear()
			return _result("career_order_removed", "Пилот отстранён от службы. Приказ отозван.")
		if epoch >= float(_order.deadline):
			_order.clear()
			_service[war_issuer] = maxi(0, _service[war_issuer] - 2)
			_change_trust(war_issuer, -2)
			return _result("career_order_expired", "Срок приказа истёк. Выслуга и доверие снижены.")
		return {}
	if _dispatch.is_empty() or epoch < float(_dispatch.deadline):
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
	var prior_grade := _service_grade(issuer)
	_dispatch.clear()
	_award_service(issuer, 1, 1)
	return _result("career_dispatch_paid", "Депеша доставлена. Получено %d кр.%s" % [DISPATCH_CREDITS,
		_promotion(issuer, prior_grade)], DISPATCH_CREDITS)


func snapshot() -> Dictionary:
	return {
		"trust": _trust.duplicate(), "service": _service.duplicate(), "combat": _combat,
		"patrol": _patrol.duplicate(), "dispatch": _dispatch.duplicate(),
		"order": _order.duplicate(),
		"bounty": {"last_raiders": _last_raiders.duplicate(), "awards": _bounty_awards, "credits": _bounty_credits},
	}


func restore(raw: Variant, epoch: float, legacy := false) -> bool:
	var fields := LEGACY_FIELDS if legacy else LEGACY_FIELDS + ["order", "bounty"]
	if not _valid_epoch(epoch) or not raw is Dictionary or not _exact_fields(raw, fields):
		return false
	if not _valid_faction_values(raw.trust, -TRUST_LIMIT, TRUST_LIMIT) or not _valid_faction_values(raw.service, 0, SERVICE_LIMIT):
		return false
	if not _integer(raw.combat, 0, COMBAT_LIMIT) or not _valid_patrol(raw.patrol) or not _valid_dispatch(raw.dispatch, epoch):
		return false
	if not legacy and (not _valid_order(raw.order, epoch) or not _valid_bounty(raw.bounty, epoch, int(raw.combat))
			or (not raw.order.is_empty() and not raw.dispatch.is_empty())):
		return false
	_trust.assign(raw.trust)
	_service.assign(raw.service)
	_combat = int(raw.combat)
	_patrol = raw.patrol.duplicate()
	_dispatch = raw.dispatch.duplicate()
	_order = {} if legacy else raw.order.duplicate()
	_last_raiders = _empty_raiders()
	_bounty_awards = 0
	_bounty_credits = 0
	if not legacy:
		_last_raiders.assign(raw.bounty.last_raiders)
		_bounty_awards = int(raw.bounty.awards)
		_bounty_credits = int(raw.bounty.credits)
		if not _order.is_empty():
			_order.issuer = int(_order.issuer)
			_order.origin = int(_order.origin)
			_order.site = int(_order.site)
	if not _patrol.is_empty():
		_patrol.issuer = int(_patrol.issuer)
		_patrol.origin = int(_patrol.origin)
	if not _dispatch.is_empty():
		_dispatch.issuer = int(_dispatch.issuer)
		_dispatch.origin = int(_dispatch.origin)
		_dispatch.destination = int(_dispatch.destination)
	return true


func _dispatch_requirement(issuer: int) -> String:
	if _trust[issuer] <= STANDING_SUSPENSION:
		return "Служба приостановлена из-за низкого доверия."
	if _service[issuer] < DISPATCH_SERVICE:
		return "Нужен служебный ранг «%s»." % SERVICE_TITLES[1]
	if _trust[issuer] < DISPATCH_TRUST:
		return "Нужно доверие не ниже %d." % DISPATCH_TRUST
	return ""


func _service_grade(issuer: int) -> int:
	return 0 if _trust[issuer] <= STANDING_SUSPENSION else _rank(_service[issuer], SERVICE_THRESHOLDS)


func _promotion(issuer: int, previous: int) -> String:
	var grade := _service_grade(issuer)
	return " Новый ранг «%s»." % SERVICE_TITLES[grade] if grade > previous else ""


func _award_combat(points: int) -> void:
	_combat = mini(COMBAT_LIMIT, _combat + points)


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


static func _valid_order(raw: Variant, epoch: float) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return true
	if not _exact_fields(raw, ORDER_FIELDS) or not raw.kind is String or not ORDERS.has(raw.kind) \
			or not _integer(raw.issuer, 0, Factions.FACTIONS.size() - 1) \
			or not _integer(raw.origin, 0, Catalog.DESTINATION_COUNT - 1) \
			or not _integer(raw.site, -1, Catalog.DESTINATION_COUNT - 1) \
			or not _valid_order_route(raw.kind, int(raw.origin), int(raw.site)) \
			or not _epoch_value(raw.accepted_at) or not _epoch_value(raw.deadline):
		return false
	var accepted := float(raw.accepted_at)
	var deadline := float(raw.deadline)
	var duration := float(ORDERS[raw.kind].duration)
	return accepted <= epoch + TIME_PRECISION and absf(deadline - (accepted + duration)) <= TIME_PRECISION \
		and (raw.proof_at == -1.0 or (_epoch_value(raw.proof_at) and raw.proof_at >= accepted \
			and raw.proof_at < deadline and raw.proof_at <= epoch + TIME_PRECISION))


static func _valid_order_route(kind: String, origin: int, site: int) -> bool:
	if not Catalog.is_port(origin):
		return false
	var system := Catalog.system_of_site(origin)
	if kind == "recon":
		return Catalog.is_mine_site(site) and Catalog.system_of_site(site) == system
	return kind == "intercept" and site == -1 and system >= 0 and system < Catalog.AUTHORED_SYSTEM_COUNT


static func _valid_bounty(raw: Variant, epoch: float, combat: int) -> bool:
	if not raw is Dictionary or not _exact_fields(raw, BOUNTY_FIELDS) or not raw.last_raiders is Array \
			or raw.last_raiders.size() != Catalog.AUTHORED_SYSTEM_COUNT or not _integer(raw.awards, 0, combat) \
			or not _integer(raw.credits, 0, MAX_BOUNTY_CREDITS):
		return false
	var recorded := false
	for system in range(raw.last_raiders.size()):
		var cycle: Variant = raw.last_raiders[system]
		var latest := floori((epoch - float(system) * Ambient.SECTOR_OFFSET) / Ambient.PERIOD)
		if not _integer(cycle, -1, maxi(-1, latest)):
			return false
		recorded = recorded or cycle >= 0
	return (raw.awards == 0 and raw.credits == 0) or (recorded and raw.awards > 0 and raw.credits >= raw.awards)


static func _empty_raiders() -> Array[int]:
	var cycles: Array[int] = []
	cycles.resize(Catalog.AUTHORED_SYSTEM_COUNT)
	cycles.fill(-1)
	return cycles


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
