extends RefCounted
## Faction offences, a local patrol and the release terms of a port arrest.

const Catalog := preload("res://scripts/sector_catalog.gd")
const Factions := preload("res://scripts/faction_fronts.gd")
const MAX_TIME := Factions.MAX_ORBIT_CLOCK
const MAX_CREDITS := 1000000000
const MAX_INCIDENTS := 1000000
const MAX_WANTED := 12
const ALERT := 2
const ARREST := 4
const CHALLENGE_TIME := 30.0
const RESPONSE_GRACE := 60.0
const HOLD_TIME := 55.0
const DISTRESS_COOLDOWN := 360.0
const RADIO_RANGE := 1800.0
const PATROL_SPEED := 185.0
const PATROL_RANGE := 115.0
const PATROL_ID := "jurisdiction-patrol"
const CRIMES := {
	"contraband": {"name": "Контрабанда", "score": 1, "fine": 0},
	"traffic": {"name": "Нарушение режима створа", "score": 2, "fine": 95},
	"weapons": {"name": "Огонь в зоне порта", "score": 2, "fine": 85},
	"evasion": {"name": "Уклонение от дозора", "score": 2, "fine": 80},
	"bribery": {"name": "Попытка подкупа", "score": 2, "fine": 65},
}
const RECORD_FIELDS := ["counts", "wanted", "debt", "last", "last_at", "appealed", "bribed"]
const PATROL_FIELDS := ["system", "owner", "position", "velocity", "phase", "deadline", "answered"]
const CUSTODY_FIELDS := ["port", "owner", "until"]
const SAVE_FIELDS := ["records", "patrol", "custody", "last_distress"]

var _records: Array[Dictionary] = [_blank_record(), _blank_record()]
var _patrol: Dictionary = {}
var _custody: Dictionary = {}
var _last_distress := -1.0


static func _blank_record() -> Dictionary:
	return {"counts": {"contraband": 0, "traffic": 0, "weapons": 0, "evasion": 0, "bribery": 0},
		"wanted": 0, "debt": 0, "last": "", "last_at": -1.0, "appealed": false, "bribed": false}


func record(owner: int, crime: String, epoch: float, aggravated := false) -> bool:
	if not _authority(owner) or not CRIMES.has(crime) or not _number(epoch, 0.0, MAX_TIME):
		return false
	var entry := _records[owner]
	if epoch < float(entry.last_at) or int(entry.counts[crime]) >= MAX_INCIDENTS:
		return false
	if crime in ["traffic", "weapons"] and entry.last == crime and epoch - float(entry.last_at) < 20.0:
		return false
	entry.counts[crime] += 1
	entry.wanted = mini(MAX_WANTED, int(entry.wanted) + int(CRIMES[crime].score) + int(aggravated))
	entry.debt = mini(MAX_CREDITS, int(entry.debt) + int(CRIMES[crime].fine))
	entry.last = crime
	entry.last_at = epoch
	return true


func status(owner: int, epoch: float) -> Dictionary:
	var entry := _records[owner].duplicate(true) if _authority(owner) else _blank_record()
	entry.authority = owner
	entry.name = Factions.faction_name(owner)
	entry.phase = str(_patrol.get("phase", "")) if int(_patrol.get("owner", -1)) == owner else ""
	entry.remaining = maxf(0.0, float(_patrol.get("deadline", epoch)) - epoch) if entry.phase == "challenge" else 0.0
	entry.can_answer = not _patrol.is_empty() and not bool(_patrol.get("answered", false))
	entry.detained = not _custody.is_empty()
	entry.release_at = float(_custody.get("until", 0.0))
	entry.last_name = str(CRIMES.get(entry.last, {}).get("name", ""))
	return entry


func clear_patrol() -> void:
	_patrol.clear()


func case_owner(fallback: int) -> int:
	return int(_custody.get("owner", fallback))


func approach(sim: RefCounted, delta: float) -> Dictionary:
	var owner: int = sim.factions.owner(sim.system_id)
	if not _authority(owner) or int(_records[owner].wanted) < (ALERT if _patrol.is_empty() else 1) or sim.docked >= 0 \
			or sim.landed or sim.jump_seconds_left > 0.0 or sim.ship.hull <= 1.0:
		clear_patrol()
		return {}
	var epoch: float = sim.orbit_time
	if _patrol.is_empty() or int(_patrol.system) != sim.system_id or int(_patrol.owner) != owner:
		var offset: Vector3 = sim.attitude().x * 225.0 + Vector3.UP * 64.0
		_patrol = {"system": sim.system_id, "owner": owner, "phase": "challenge", "deadline": epoch + CHALLENGE_TIME,
			"position": sim.position + offset, "velocity": Vector3.ZERO, "answered": false}
		return _result("law_challenge", "Дозор требует ответить. Откройте связь в течение 30 секунд.")
	var position: Vector3 = _patrol.position
	var next := position.move_toward(sim.position + sim.attitude().x * 35.0, PATROL_SPEED * delta)
	_patrol.position = next
	_patrol.velocity = (next - position) / delta
	if _patrol.phase == "challenge" and epoch >= float(_patrol.deadline):
		record(owner, "evasion", epoch)
		_patrol.phase = "pursuit"
		return _result("law_pursuit", "Вызов проигнорирован. Дозор начал преследование.")
	if _patrol.phase == "negotiation" and epoch >= float(_patrol.deadline):
		if int(_records[owner].wanted) < ALERT:
			clear_patrol()
			return {}
		_patrol.phase = "pursuit"
		return _result("law_pursuit", "Срок переговоров истёк. Дозор продолжил преследование.")
	if _patrol.phase == "pursuit" and next.distance_to(sim.position) <= PATROL_RANGE:
		_patrol.phase = "interdicted"
		return _result("law_interdiction", "Дозор перехватил корабль и ограничил тягу. Ответьте по связи или сядьте в порт.")
	return {}


func interdicting() -> bool:
	return _patrol.get("phase", "") == "interdicted"


func is_tracking() -> bool:
	return not _patrol.is_empty()


func contact(sim: RefCounted) -> Dictionary:
	if _patrol.is_empty() or int(_patrol.system) != sim.system_id or sim.docked >= 0 or sim.landed:
		return {}
	var position: Vector3 = _patrol.position
	return {"id": PATROL_ID, "name": "Дозор «%s»" % Factions.faction_name(int(_patrol.owner)),
		"position": position, "velocity": _patrol.velocity, "forward": position.direction_to(sim.position),
		"role": "patrol", "phase": _patrol.phase, "hull": 100.0, "hostile": false}


func arrive(owner: int, port: int, epoch: float) -> Dictionary:
	var detained := _authority(owner) and (int(_records[owner].wanted) >= ARREST \
		or (interdicting() and int(_patrol.owner) == owner))
	clear_patrol()
	if not detained:
		return {}
	_custody = {"port": port, "owner": owner, "until": minf(MAX_TIME, epoch + HOLD_TIME)}
	return _result("law_arrest", "Корабль задержан. Урегулируйте дело по связи или дождитесь освобождения.")


func can_depart() -> bool:
	return _custody.is_empty()


func answer(epoch: float) -> Dictionary:
	if _patrol.is_empty() or _patrol.answered:
		return {}
	_patrol.phase = "negotiation"
	_patrol.answered = true
	_patrol.deadline = epoch + RESPONSE_GRACE
	return _result("law_answer", "Данные корабля приняты. Дозор ждёт оплаты или возражения.")


func pay(owner: int, credits: int) -> Dictionary:
	if not _authority(owner) or credits <= 0:
		return {}
	var entry := _records[owner]
	var paid := mini(credits, int(entry.debt))
	if paid <= 0:
		return {}
	entry.debt -= paid
	return _result("law_paid", "Уплачено %d кр. Остаток по делу %d кр." % [paid, int(entry.debt)], -paid)


func contest(owner: int, allow_remission: bool) -> Dictionary:
	if not _authority(owner):
		return {}
	var entry := _records[owner]
	if entry.appealed or int(entry.wanted) <= 0:
		return {}
	entry.appealed = true
	if allow_remission and int(entry.wanted) <= ALERT and entry.last == "traffic":
		entry.wanted -= 1
		entry.debt = maxi(0, int(entry.debt) - 30)
		return _result("law_contest", "Дозор принял часть возражений. Штраф уменьшен на 30 кр.")
	entry.debt = mini(MAX_CREDITS, int(entry.debt) + 45)
	return _result("law_contest", "Возражение отклонено. Издержки по делу увеличены на 45 кр.")


func bribe(owner: int, credits: int, epoch: float) -> Dictionary:
	const COST := 120
	if not _authority(owner) or credits < COST:
		return {}
	var entry := _records[owner]
	if entry.bribed or int(entry.wanted) <= 0:
		return {}
	entry.bribed = true
	if owner == 0 and entry.last == "traffic" and int(entry.wanted) == ALERT:
		entry.wanted -= 1
		entry.debt = maxi(0, int(entry.debt) - 45)
		return _result("law_bribe", "Посредник снял часть претензий. Уплачено 120 кр.", -COST)
	record(owner, "bribery", epoch)
	return _result("law_bribe", "Попытка подкупа внесена в дело. Уплачено 120 кр.", -COST)


func release(owner: int, customs_debt: int, epoch: float) -> Dictionary:
	if not _authority(owner):
		return {}
	var entry := _records[owner]
	var detained := int(_custody.get("owner", -1)) == owner
	var served := detained and epoch >= float(_custody.until)
	if not served and (int(entry.debt) != 0 or customs_debt != 0):
		return {}
	if int(entry.wanted) <= 0 and not detained:
		return {}
	entry.wanted = 0
	entry.appealed = false
	entry.bribed = false
	clear_patrol()
	_custody.clear()
	return _result("law_release", "Задержание завершено. Неуплаченные взыскания сохранены." if served \
		else "Дело урегулировано. Ограничения сняты.")


func distress_available(epoch: float) -> bool:
	return _last_distress < 0.0 or epoch - _last_distress >= DISTRESS_COOLDOWN


func note_distress(epoch: float) -> bool:
	if not distress_available(epoch) or not _number(epoch, 0.0, MAX_TIME):
		return false
	_last_distress = epoch
	return true


func snapshot() -> Dictionary:
	var pursuit := _patrol.duplicate()
	if not pursuit.is_empty():
		for field: String in ["position", "velocity"]:
			var vector: Vector3 = pursuit[field]
			pursuit[field] = [vector.x, vector.y, vector.z]
	return {"records": _records.duplicate(true), "patrol": pursuit, "custody": _custody.duplicate(), "last_distress": _last_distress}


func restore(raw: Variant, epoch: float, system: int, docked: int, landed: bool) -> bool:
	if not _exact(raw, SAVE_FIELDS) or not raw.records is Array or raw.records.size() != Factions.FACTIONS.size() \
			or not raw.patrol is Dictionary or not raw.custody is Dictionary or not _number(raw.last_distress, -1.0, epoch):
		return false
	var records: Array[Dictionary] = []
	for entry: Variant in raw.records:
		if not _valid_record(entry, epoch):
			return false
		var normalized: Dictionary = entry.duplicate(true)
		for crime: String in CRIMES:
			normalized.counts[crime] = int(normalized.counts[crime])
		normalized.wanted = int(normalized.wanted)
		normalized.debt = int(normalized.debt)
		normalized.last_at = float(normalized.last_at)
		records.append(normalized)
	var pursuit: Dictionary = raw.patrol.duplicate()
	if not pursuit.is_empty():
		if docked >= 0 or landed or not _exact(pursuit, PATROL_FIELDS) or not _integer(pursuit.system, system, system) \
				or not _integer(pursuit.owner, 0, records.size() - 1) or records[int(pursuit.owner)].wanted < 1 \
				or pursuit.phase not in ["challenge", "pursuit", "interdicted", "negotiation"] \
				or not pursuit.answered is bool or not _number(pursuit.deadline, 0.0, epoch + RESPONSE_GRACE + 0.001):
			return false
		pursuit.position = _vector(pursuit.position, 11000000.0)
		pursuit.velocity = _vector(pursuit.velocity, PATROL_SPEED + 0.01)
		if not pursuit.position.is_finite() or not pursuit.velocity.is_finite():
			return false
	var custody: Dictionary = raw.custody.duplicate()
	if not custody.is_empty() and (not _exact(custody, CUSTODY_FIELDS) or not Catalog.is_port(docked) \
			or not _integer(custody.port, docked, docked) or not _integer(custody.owner, 0, records.size() - 1) \
			or not _number(custody.until, 0.0, epoch + HOLD_TIME + 0.001)):
		return false
	_records = records
	_patrol = pursuit
	_custody = custody
	_last_distress = float(raw.last_distress)
	return true


static func _valid_record(entry: Variant, epoch: float) -> bool:
	if not _exact(entry, RECORD_FIELDS) or not _exact(entry.counts, CRIMES.keys()) or not _integer(entry.wanted, 0, MAX_WANTED) \
			or not _integer(entry.debt, 0, MAX_CREDITS) or not entry.last is String or not _number(entry.last_at, -1.0, epoch) \
			or not entry.appealed is bool or not entry.bribed is bool:
		return false
	var total := 0
	for crime: String in CRIMES:
		if not _integer(entry.counts[crime], 0, MAX_INCIDENTS):
			return false
		total += int(entry.counts[crime])
	if total == 0:
		return int(entry.wanted) == 0 and int(entry.debt) == 0 and entry.last.is_empty() \
			and float(entry.last_at) == -1.0 and not entry.appealed and not entry.bribed
	return CRIMES.has(entry.last) and entry.last_at >= 0.0 and int(entry.counts[entry.last]) > 0


static func _vector(raw: Variant, bound: float) -> Vector3:
	if not raw is Array or raw.size() != 3:
		return Vector3.INF
	for coordinate: Variant in raw:
		if not _number(coordinate, -bound, bound):
			return Vector3.INF
	return Vector3(raw[0], raw[1], raw[2])


static func _exact(raw: Variant, fields: Array) -> bool:
	return raw is Dictionary and raw.size() == fields.size() and raw.has_all(fields)


static func _authority(owner: int) -> bool:
	return owner >= 0 and owner < Factions.FACTIONS.size()


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and int(value) == value


static func _result(event: String, message: String, credits := 0) -> Dictionary:
	return {"ok": true, "event": event, "message": message, "credits": credits}
