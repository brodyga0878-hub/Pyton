extends RefCounted
## Distant conflicts progress on the simulation clock and leave commissioned ports usable.

const Catalog = preload("res://scripts/sector_catalog.gd")
const FACTIONS := ["Содружество Маяков", "Веларская лига"]
const CORE_OWNERS := [0, 1, 0]
const FRONTIER_SYSTEMS := [Catalog.HEATHER_SYSTEM, Catalog.LIMIT_SYSTEM]
const FOUNDING_GRACE := 360.0
const ROUND_SECONDS := 180.0
const ATTACK_CONVOY_SECONDS := 90.0
const DEFENCE_CONVOY_SECONDS := 120.0
const TRUCE_SECONDS := 480.0
const CAMPAIGN_ROUNDS := 3
const MAX_NEWS := 8
const MAX_ORBIT_CLOCK := 3155760000.0
const MAX_CAMPAIGNS := 10000000
const RECORD_FIELDS := ["owner", "stage", "pressure", "challenger", "next_at", "round", "campaign"]
const CONVOY_FIELDS := ["id", "faction", "stage", "launched_at", "due_at", "shipment", "units"]
const SHIPMENTS := ["Запасные узлы", "Энергоячейки"]

var _frontiers: Array[Dictionary] = [_new_frontier(), _new_frontier()]
var _news: Array[String] = []


static func faction_name(id: int) -> String:
	return FACTIONS[id] if id >= 0 and id < FACTIONS.size() else "Без фракции"


func owner(system: int) -> int:
	if system >= 0 and system < CORE_OWNERS.size():
		return CORE_OWNERS[system]
	var index := FRONTIER_SYSTEMS.find(system)
	return int(_frontiers[index].owner) if index >= 0 else -1


func system_state(system: int) -> Dictionary:
	var index := FRONTIER_SYSTEMS.find(system)
	if index < 0:
		var core_owner := owner(system)
		return {"owner": core_owner, "stage": "core" if core_owner >= 0 else "neutral", "pressure": 0,
			"challenger": -1, "next_at": 0.0, "next_event_at": 0.0, "convoys": []}
	var frontier := _frontiers[index]
	var state := frontier.duplicate(true)
	state.next_event_at = _next_event_at(frontier)
	return state


func active_convoys(system: int) -> Array[Dictionary]:
	var convoys: Array[Dictionary] = []
	var index := FRONTIER_SYSTEMS.find(system)
	if index >= 0:
		for convoy: Dictionary in _frontiers[index].convoys:
			if convoy.stage == "en_route":
				convoys.append(convoy.duplicate())
	return convoys


func convoy(system: int, id: String) -> Dictionary:
	return _find_convoy(system, id).duplicate()


func escort_convoy(system: int, id: String, sponsor_faction: int) -> bool:
	var shipment := _find_convoy(system, id)
	if shipment.is_empty() or shipment.stage != "en_route" or shipment.assistance != "none" or shipment.faction != sponsor_faction:
		return false
	shipment.assistance = "escort"
	return true


func intercept_convoy(system: int, id: String, sponsor_faction: int) -> Dictionary:
	var shipment := _find_convoy(system, id)
	if shipment.is_empty() or shipment.stage != "en_route" or shipment.assistance != "none" or shipment.faction != 1 - sponsor_faction:
		return {}
	shipment.assistance = "intercept"
	return _finish_convoy(shipment, system, false)


func _find_convoy(system: int, id: String) -> Dictionary:
	var index := FRONTIER_SYSTEMS.find(system)
	if index >= 0:
		for shipment: Dictionary in _frontiers[index].convoys:
			if shipment.id == id:
				return shipment
	return {}


func news() -> Array[String]:
	return _news.duplicate()


func can_commission(system: int, sponsor: int, now: float) -> bool:
	return system in FRONTIER_SYSTEMS and sponsor >= 0 and sponsor < FACTIONS.size() \
		and owner(system) < 0 and _number(now, 0.0, MAX_ORBIT_CLOCK)


func commission(system: int, sponsor: int, now: float) -> bool:
	if not can_commission(system, sponsor, now):
		return false
	var frontier := _frontiers[FRONTIER_SYSTEMS.find(system)]
	frontier.owner = sponsor
	frontier.stage = "peace"
	frontier.next_at = now + FOUNDING_GRACE
	_record("Станция введена в строй. Контроль над системой «%s» получает фракция «%s»." % [
		_system_name(system), faction_name(sponsor),
	])
	return true


func next_event_time() -> float:
	var next_due := INF
	for frontier: Dictionary in _frontiers:
		if frontier.owner >= 0:
			next_due = minf(next_due, _next_event_at(frontier))
	return next_due


func advance(now: float) -> Dictionary:
	if not _number(now, 0.0, MAX_ORBIT_CLOCK):
		return {}
	var index := -1
	var next_due := INF
	for candidate in range(_frontiers.size()):
		var record := _frontiers[candidate]
		var due := _next_event_at(record)
		if record.owner >= 0 and due <= now and due < next_due:
			index = candidate
			next_due = due
	if index < 0:
		return {}

	var frontier := _frontiers[index]
	var system_id: int = FRONTIER_SYSTEMS[index]
	var system := _system_name(system_id)
	for convoy: Dictionary in frontier.convoys:
		if convoy.stage == "en_route" and convoy.due_at == next_due:
			return _resolve_convoy(frontier, convoy, system_id)

	if frontier.stage == "peace":
		frontier.stage = "war"
		frontier.challenger = 1 - int(frontier.owner)
		frontier.pressure = 16
		frontier.campaign = mini(int(frontier.campaign) + 1, MAX_CAMPAIGNS)
		_schedule(frontier, now, ROUND_SECONDS)
		_dispatch_convoys(frontier, system_id)
		return _event("war_declared", "Фракция «%s» оспаривает контроль над системой «%s». Обе стороны отправили конвои." % [
			faction_name(frontier.challenger), system,
		], system_id, _campaign_news_key(system_id, int(frontier.campaign)), "expedition-%d-commission" % system_id)

	var supply_bonus := _delivered_supply_bonus(frontier)
	frontier.round += 1
	frontier.pressure = clampi(int(frontier.pressure) + _pressure_delta(index) + supply_bonus, 0, 100)
	if frontier.round < CAMPAIGN_ROUNDS:
		_schedule(frontier, now, ROUND_SECONDS)
		_dispatch_convoys(frontier, system_id)
		return _event("war_round", "Фронт в системе «%s». Сила наступления %d%%, завершён раунд %d из %d. Вклад конвоев %+d п. п." % [
			system, frontier.pressure, frontier.round, CAMPAIGN_ROUNDS, supply_bonus,
		], system_id, "%s-round-%d" % [_campaign_news_key(system_id, int(frontier.campaign)), frontier.round],
			_campaign_news_key(system_id, int(frontier.campaign)))

	var captured: bool = frontier.pressure >= 55
	if captured:
		frontier.owner = frontier.challenger
	frontier.stage = "peace"
	frontier.challenger = -1
	frontier.pressure = 0
	frontier.round = 0
	frontier.convoys.clear()
	frontier.legacy_round = false
	_schedule(frontier, now, TRUCE_SECONDS)
	if captured:
		return _event("war_captured", "Контроль над системой «%s» перешёл к фракции «%s». Заключено перемирие. Вклад конвоев в решающем раунде %+d п. п." % [
			system, faction_name(frontier.owner), supply_bonus,
		], system_id, _campaign_news_key(system_id, int(frontier.campaign)) + "-outcome", _campaign_news_key(system_id, int(frontier.campaign)))
	return _event("war_repulsed", "Фракция «%s» удержала систему «%s». Заключено перемирие. Вклад конвоев в решающем раунде %+d п. п." % [
		faction_name(frontier.owner), system, supply_bonus,
	], system_id, _campaign_news_key(system_id, int(frontier.campaign)) + "-outcome", _campaign_news_key(system_id, int(frontier.campaign)))


func snapshot() -> Dictionary:
	return {"frontiers": _frontiers.duplicate(true), "news": _news.duplicate()}


func restore(payload: Variant, legacy_convoys := false, pre_assistance := false) -> bool:
	if not payload is Dictionary or payload.size() != 2:
		return false
	var records: Variant = payload.get("frontiers")
	var reports: Variant = payload.get("news")
	if not records is Array or records.size() != FRONTIER_SYSTEMS.size() or not reports is Array or reports.size() > MAX_NEWS:
		return false
	var restored_frontiers: Array[Dictionary] = []
	for index in range(records.size()):
		var record: Variant = records[index]
		if not _valid_record(record, FRONTIER_SYSTEMS[index], legacy_convoys, pre_assistance):
			return false
		var legacy_round: bool = record.stage == "war" if legacy_convoys else record.legacy_round
		var restored := {"owner": int(record.owner), "stage": record.stage,
			"pressure": int(record.pressure), "challenger": int(record.challenger), "next_at": float(record.next_at),
			"round": int(record.round), "campaign": int(record.campaign), "convoys": [], "legacy_round": legacy_round}
		if restored.stage == "war" and not legacy_round:
			_dispatch_convoys(restored, FRONTIER_SYSTEMS[index])
			for slot in range(restored.convoys.size()):
				restored.convoys[slot].stage = record.convoys[slot].stage
				if not pre_assistance:
					restored.convoys[slot].assistance = record.convoys[slot].assistance
		restored_frontiers.append(restored)
	var restored_news: Array[String] = []
	for report in reports:
		if not report is String or report.is_empty() or report.length() > 240:
			return false
		restored_news.append(report)
	_frontiers = restored_frontiers
	_news = restored_news
	return true


static func _next_event_at(frontier: Dictionary) -> float:
	var due: float = frontier.next_at
	for convoy: Dictionary in frontier.convoys:
		if convoy.stage == "en_route":
			due = minf(due, convoy.due_at)
	return due


static func _dispatch_convoys(frontier: Dictionary, system: int) -> void:
	var launched_at := float(frontier.next_at) - ROUND_SECONDS
	var attacker: int = frontier.challenger
	var defender: int = frontier.owner
	frontier.legacy_round = false
	frontier.convoys = [
		_convoy(frontier, system, attacker, launched_at, ATTACK_CONVOY_SECONDS),
		_convoy(frontier, system, defender, launched_at, DEFENCE_CONVOY_SECONDS),
	]


static func _convoy(frontier: Dictionary, system: int, faction: int, launched_at: float, duration: float) -> Dictionary:
	var campaign: int = frontier.campaign
	var turn: int = frontier.round
	var units := 3 + (system * 13 + campaign * 7 + turn * 3 + faction * 2) % 5
	return {"id": "front-%d-%d-%d-%d" % [system, campaign, turn, faction], "faction": faction,
		"stage": "en_route", "launched_at": launched_at, "due_at": launched_at + duration,
		"shipment": SHIPMENTS[faction], "units": units, "assistance": "none"}


func _resolve_convoy(frontier: Dictionary, convoy: Dictionary, system: int) -> Dictionary:
	var faction: int = convoy.faction
	var campaign: int = frontier.campaign
	var turn: int = frontier.round
	var escort := _holdings(faction) + (system * 11 + campaign * 7 + turn * 11 + faction * 3) % 17
	var blockade := _holdings(1 - faction) + (system * 5 + campaign * 11 + turn * 3 + faction * 5) % 17
	return _finish_convoy(convoy, system, convoy.assistance == "escort" or escort + 3 >= blockade)


func _finish_convoy(convoy: Dictionary, system: int, delivered: bool) -> Dictionary:
	var faction: int = convoy.faction
	var name := _system_name(system)
	var cargo := "«%s», %d ед." % [str(convoy.shipment).to_lower(), convoy.units]
	var key := "%s-arrival" % str(convoy.id)
	var campaign := _campaign_news_key(system, int(_frontiers[FRONTIER_SYSTEMS.find(system)].campaign))
	if delivered:
		convoy.stage = "delivered"
		if convoy.assistance == "escort":
			return _event("war_convoy_delivered", "С вашей охраной конвой фракции «%s» доставил снабжение в систему «%s». Груз %s" % [
				faction_name(faction), name, cargo,
			], system, key, campaign)
		return _event("war_convoy_delivered", "Конвой фракции «%s» доставил снабжение в систему «%s». Груз %s" % [
			faction_name(faction), name, cargo,
		], system, key, campaign)
	convoy.stage = "intercepted"
	if convoy.assistance == "intercept":
		return _event("war_convoy_intercepted", "Вы сорвали поставку фракции «%s» в системе «%s». Потерян груз %s" % [
			faction_name(faction), name, cargo,
		], system, key, campaign)
	return _event("war_convoy_intercepted", "Фракция «%s» перехватила конвой фракции «%s» в системе «%s». Потерян груз %s" % [
		faction_name(1 - faction), faction_name(faction), name, cargo,
	], system, key, campaign)


static func _delivered_supply_bonus(frontier: Dictionary) -> int:
	var bonus := 0
	for convoy: Dictionary in frontier.convoys:
		if convoy.stage == "delivered":
			var points := 2 * int(convoy.units)
			bonus += points if convoy.faction == frontier.challenger else -points
	return bonus


func _pressure_delta(index: int) -> int:
	var frontier := _frontiers[index]
	var attacker: int = frontier.challenger
	var defender: int = frontier.owner
	var campaign: int = frontier.campaign
	var turn: int = frontier.round
	# Keep the original balance for an already active round restored from a v10 save.
	var holdings_weight := 6 if frontier.legacy_round else 4
	var opening := 12 if (campaign + index) % 2 == 1 else -10
	var attack := holdings_weight * _holdings(attacker) + (index * 11 + campaign * 7 + turn * 5) % 13
	var defence := holdings_weight * _holdings(defender) + (index * 7 + campaign * 5 + turn * 3) % 11
	return 16 + opening + attack - defence


func _holdings(faction: int) -> int:
	var total := CORE_OWNERS.count(faction)
	for frontier in _frontiers:
		if frontier.owner == faction:
			total += 1
	return total


static func _campaign_news_key(system: int, campaign: int) -> String:
	return "war-%d-%d" % [system, campaign]


func _event(id: String, message: String, system: int, article: String, related: String) -> Dictionary:
	_record(message)
	return {"event": id, "message": message, "news_system": system, "news_id": article, "news_related": related}


func _record(message: String) -> void:
	_news.push_front(message)
	if _news.size() > MAX_NEWS:
		_news.pop_back()


static func _schedule(frontier: Dictionary, now: float, interval: float) -> void:
	var target := float(frontier.next_at) + interval
	# Normal ticks retain their exact deadlines. An exceptionally large jump skips backlog.
	frontier.next_at = target if target > now else now + interval


static func _new_frontier() -> Dictionary:
	return {"owner": -1, "stage": "neutral", "pressure": 0, "challenger": -1, "next_at": 0.0,
		"round": 0, "campaign": 0, "convoys": [], "legacy_round": false}


static func _valid_record(record: Variant, system: int, legacy_convoys: bool, pre_assistance: bool) -> bool:
	var expected_fields := RECORD_FIELDS.size() if legacy_convoys else RECORD_FIELDS.size() + 2
	if not record is Dictionary or record.size() != expected_fields or not record.has_all(RECORD_FIELDS):
		return false
	if not record.stage is String or record.stage not in ["neutral", "peace", "war"]:
		return false
	if not _integer(record.owner, -1, FACTIONS.size() - 1) or not _integer(record.challenger, -1, FACTIONS.size() - 1):
		return false
	if not _integer(record.pressure, 0, 100) or not _integer(record.round, 0, CAMPAIGN_ROUNDS - 1):
		return false
	if not _integer(record.campaign, 0, MAX_CAMPAIGNS) or not _number(record.next_at, 0.0, MAX_ORBIT_CLOCK + TRUCE_SECONDS):
		return false
	if not legacy_convoys and not _valid_convoys(record, system, pre_assistance):
		return false
	if record.stage == "neutral":
		return record.owner == -1 and record.challenger == -1 and record.pressure == 0 and record.round == 0 \
			and record.campaign == 0 and record.next_at == 0.0
	if record.owner < 0 or record.next_at < ROUND_SECONDS:
		return false
	if record.stage == "peace":
		return record.challenger == -1 and record.pressure == 0 and record.round == 0
	return record.challenger == 1 - int(record.owner) and record.campaign > 0 and (record.round > 0 or record.pressure == 16)


static func _valid_convoys(frontier: Dictionary, system: int, pre_assistance: bool) -> bool:
	var convoys: Variant = frontier.get("convoys")
	var legacy_round: Variant = frontier.get("legacy_round")
	if not convoys is Array or not legacy_round is bool:
		return false
	if frontier.stage != "war":
		return convoys.is_empty() and not legacy_round
	if legacy_round:
		return convoys.is_empty()
	if convoys.size() != 2 or frontier.owner < 0 or frontier.challenger < 0 or frontier.next_at < ROUND_SECONDS:
		return false
	var launched_at := float(frontier.next_at) - ROUND_SECONDS
	var attacker := _convoy(frontier, system, int(frontier.challenger), launched_at, ATTACK_CONVOY_SECONDS)
	var defender := _convoy(frontier, system, int(frontier.owner), launched_at, DEFENCE_CONVOY_SECONDS)
	return _valid_convoy(convoys[0], attacker, pre_assistance) and _valid_convoy(convoys[1], defender, pre_assistance) \
		and (convoys[1].stage == "en_route" or convoys[0].stage != "en_route" \
			or (not pre_assistance and convoys[1].assistance == "intercept"))


static func _valid_convoy(convoy: Variant, expected: Dictionary, pre_assistance: bool) -> bool:
	var field_count := CONVOY_FIELDS.size() if pre_assistance else CONVOY_FIELDS.size() + 1
	if not convoy is Dictionary or convoy.size() != field_count or not convoy.has_all(CONVOY_FIELDS):
		return false
	if not convoy.stage is String or convoy.stage not in ["en_route", "delivered", "intercepted"]:
		return false
	if not _integer(convoy.faction, expected.faction, expected.faction) or not _integer(convoy.units, expected.units, expected.units):
		return false
	if not _number(convoy.launched_at, 0.0, MAX_ORBIT_CLOCK) or not _number(convoy.due_at, 0.0, MAX_ORBIT_CLOCK + ROUND_SECONDS):
		return false
	if not pre_assistance:
		var assistance: Variant = convoy.get("assistance")
		if not assistance is String or assistance not in ["none", "escort", "intercept"]:
			return false
		if (assistance == "escort" and convoy.stage == "intercepted") or (assistance == "intercept" and convoy.stage != "intercepted"):
			return false
	return convoy.id is String and convoy.id == expected.id and convoy.shipment is String and convoy.shipment == expected.shipment \
		and absf(float(convoy.launched_at) - float(expected.launched_at)) < 0.00001 \
		and absf(float(convoy.due_at) - float(expected.due_at)) < 0.00001


static func _system_name(system: int) -> String:
	return str(Catalog.system(system).get("name", "Рубеж %d" % system))


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and floorf(float(value)) == value
