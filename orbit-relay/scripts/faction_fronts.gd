extends RefCounted
## Distant conflicts progress on the simulation clock and leave commissioned ports usable.

const Catalog = preload("res://scripts/sector_catalog.gd")
const FACTIONS := ["Содружество Маяков", "Веларская лига"]
const CORE_OWNERS := [0, 1, 0]
const FRONTIER_SYSTEMS := [Catalog.HEATHER_SYSTEM, Catalog.LIMIT_SYSTEM]
const FOUNDING_GRACE := 360.0
const ROUND_SECONDS := 180.0
const TRUCE_SECONDS := 480.0
const CAMPAIGN_ROUNDS := 3
const MAX_NEWS := 8
const MAX_ORBIT_CLOCK := 3155760000.0
const MAX_CAMPAIGNS := 10000000
const RECORD_FIELDS := ["owner", "stage", "pressure", "challenger", "next_at", "round", "campaign"]

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
			"challenger": -1, "next_at": 0.0}
	return _frontiers[index].duplicate()


func news() -> Array[String]:
	return _news.duplicate()


func commission(system: int, sponsor: int, now: float) -> bool:
	var index := FRONTIER_SYSTEMS.find(system)
	if index < 0 or sponsor < 0 or sponsor >= FACTIONS.size() or owner(system) >= 0 or not _number(now, 0.0, MAX_ORBIT_CLOCK):
		return false
	var frontier := _frontiers[index]
	frontier.owner = sponsor
	frontier.stage = "peace"
	frontier.next_at = now + FOUNDING_GRACE
	_record("Станция введена в строй. Контроль над системой «%s» получает фракция «%s»." % [
		_system_name(system), faction_name(sponsor),
	])
	return true


func advance(now: float) -> Dictionary:
	if not _number(now, 0.0, MAX_ORBIT_CLOCK):
		return {}
	var index := -1
	var next_due := INF
	for candidate in range(_frontiers.size()):
		var record := _frontiers[candidate]
		if record.owner >= 0 and record.next_at <= now and record.next_at < next_due:
			index = candidate
			next_due = record.next_at
	if index < 0:
		return {}

	var frontier := _frontiers[index]
	var system := _system_name(FRONTIER_SYSTEMS[index])
	if frontier.stage == "peace":
		frontier.stage = "war"
		frontier.challenger = 1 - int(frontier.owner)
		frontier.pressure = 16
		frontier.campaign = mini(int(frontier.campaign) + 1, MAX_CAMPAIGNS)
		_schedule(frontier, now, ROUND_SECONDS)
		return _event("war_declared", "Фракция «%s» оспаривает контроль над системой «%s». К рубежу идут подкрепления." % [
			faction_name(frontier.challenger), system,
		])

	frontier.round += 1
	frontier.pressure = clampi(int(frontier.pressure) + _pressure_delta(index), 0, 100)
	if frontier.round < CAMPAIGN_ROUNDS:
		_schedule(frontier, now, ROUND_SECONDS)
		return _event("war_round", "Фронт в системе «%s». Сила наступления %d%%, раунд %d из %d." % [
			system, frontier.pressure, frontier.round, CAMPAIGN_ROUNDS,
		])

	var captured: bool = frontier.pressure >= 55
	if captured:
		frontier.owner = frontier.challenger
	frontier.stage = "peace"
	frontier.challenger = -1
	frontier.pressure = 0
	frontier.round = 0
	_schedule(frontier, now, TRUCE_SECONDS)
	if captured:
		return _event("war_captured", "Контроль над системой «%s» перешёл к фракции «%s». Заключено перемирие." % [
			system, faction_name(frontier.owner),
		])
	return _event("war_repulsed", "Фракция «%s» удержала систему «%s». Заключено перемирие." % [
		faction_name(frontier.owner), system,
	])


func snapshot() -> Dictionary:
	return {"frontiers": _frontiers.duplicate(true), "news": _news.duplicate()}


func restore(payload: Variant) -> bool:
	if not payload is Dictionary or payload.size() != 2:
		return false
	var records: Variant = payload.get("frontiers")
	var reports: Variant = payload.get("news")
	if not records is Array or records.size() != FRONTIER_SYSTEMS.size() or not reports is Array or reports.size() > MAX_NEWS:
		return false
	var restored_frontiers: Array[Dictionary] = []
	for record in records:
		if not _valid_record(record):
			return false
		restored_frontiers.append({"owner": int(record.owner), "stage": record.stage,
			"pressure": int(record.pressure), "challenger": int(record.challenger), "next_at": float(record.next_at),
			"round": int(record.round), "campaign": int(record.campaign)})
	var restored_news: Array[String] = []
	for report in reports:
		if not report is String or report.is_empty() or report.length() > 240:
			return false
		restored_news.append(report)
	_frontiers = restored_frontiers
	_news = restored_news
	return true


func _pressure_delta(index: int) -> int:
	var frontier := _frontiers[index]
	var attacker: int = frontier.challenger
	var defender: int = frontier.owner
	var campaign: int = frontier.campaign
	var turn: int = frontier.round
	# Holdings support fleets, and alternating supply windows can reverse an advantage.
	var opening := 12 if (campaign + index) % 2 == 1 else -10
	var attack := 6 * _holdings(attacker) + (index * 11 + campaign * 7 + turn * 5) % 13
	var defence := 6 * _holdings(defender) + (index * 7 + campaign * 5 + turn * 3) % 11
	return 16 + opening + attack - defence


func _holdings(faction: int) -> int:
	var total := CORE_OWNERS.count(faction)
	for frontier in _frontiers:
		if frontier.owner == faction:
			total += 1
	return total


func _event(id: String, message: String) -> Dictionary:
	_record(message)
	return {"event": id, "message": message}


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
		"round": 0, "campaign": 0}


static func _valid_record(record: Variant) -> bool:
	if not record is Dictionary or record.size() != RECORD_FIELDS.size() or not record.has_all(RECORD_FIELDS):
		return false
	if not record.stage is String or record.stage not in ["neutral", "peace", "war"]:
		return false
	if not _integer(record.owner, -1, FACTIONS.size() - 1) or not _integer(record.challenger, -1, FACTIONS.size() - 1):
		return false
	if not _integer(record.pressure, 0, 100) or not _integer(record.round, 0, CAMPAIGN_ROUNDS - 1):
		return false
	if not _integer(record.campaign, 0, MAX_CAMPAIGNS) or not _number(record.next_at, 0.0, MAX_ORBIT_CLOCK + TRUCE_SECONDS):
		return false
	if record.stage == "neutral":
		return record.owner == -1 and record.challenger == -1 and record.pressure == 0 and record.round == 0 \
			and record.campaign == 0 and record.next_at == 0.0
	if record.owner < 0 or record.next_at < ROUND_SECONDS:
		return false
	if record.stage == "peace":
		return record.challenger == -1 and record.pressure == 0 and record.round == 0
	return record.challenger == 1 - int(record.owner) and record.campaign > 0 and (record.round > 0 or record.pressure == 16)


static func _system_name(system: int) -> String:
	return str(Catalog.system(system).get("name", "Рубеж %d" % system))


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and floorf(float(value)) == value
