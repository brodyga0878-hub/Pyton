extends RefCounted
## The crew has its own roster and salary schedule, separate from passenger cabins.

const Catalog = preload("res://scripts/sector_catalog.gd")
const CAPACITY := 2
const WAGE_PERIOD := 240.0
const MAX_EPOCH := 3155760000.0
const MAX_PERIODS := int(MAX_EPOCH / WAGE_PERIOD)
const CLOCK_PRECISION := 0.0001
const RECORD_FIELDS := ["id", "hired_at", "periods", "arrears"]
const NAMES := {
	0: ["Мира Орлова", "Игнат Ветров"],
	1: ["Таис Норд", "Ян Лебедев"],
	3: ["Лев Громов", "Элина Заря"],
	10: ["Ада Власова", "Павел Рощин"],
	11: ["Саша Рудин", "Дарья Миронова"],
	Catalog.FRINGE_ARRIVAL_PORT: ["Артём Белов", "Ника Снегирёва"],
	Catalog.FRINGE_SECOND_PORT: ["Тимур Садов", "Лина Ярова"],
	Catalog.HEATHER_PORT: ["Вера Соколова", "Марк Волин"],
	Catalog.LIMIT_PORT: ["Дина Рябова", "Роман Литвин"],
}

var _members: Array[Dictionary] = []


static func candidates(port: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if Catalog.is_port(port):
		for slot in range(CAPACITY):
			result.append(_candidate(port * CAPACITY + slot))
	return result


static func _candidate(id: int) -> Dictionary:
	if id < 0 or id >= Catalog.DESTINATION_COUNT * CAPACITY:
		return {}
	@warning_ignore("integer_division")
	var origin := id / CAPACITY
	if not Catalog.is_port(origin):
		return {}
	var slot := id % CAPACITY
	var names: Array = NAMES.get(origin, ["Инженер порта %d" % origin, "Штурман порта %d" % origin])
	return {"id": id, "origin": origin, "name": names[slot],
		"role": "engineer" if slot == 0 else "navigator", "fee": 120 if slot == 0 else 90,
		"wage": _wage(id)}


static func _wage(id: int) -> int:
	return 18 if id % CAPACITY == 0 else 14


func status(epoch: float) -> Dictionary:
	var members: Array[Dictionary] = []
	var arrears := 0
	var soonest := INF
	for record in _members:
		var member := _candidate(record.id)
		var next_due := _due_at(record, int(record.periods) + 1)
		member.merge({"hired_at": record.hired_at, "next_due": next_due,
			"remaining": maxf(0.0, next_due - epoch) if is_finite(epoch) else 0.0,
			"arrears": record.arrears, "active": record.arrears == 0})
		members.append(member)
		arrears += int(record.arrears)
		soonest = minf(soonest, next_due)
	return {"capacity": CAPACITY, "count": members.size(), "members": members,
		"arrears": arrears, "next_due": soonest if not members.is_empty() else -1.0}


func active_role(role: String) -> bool:
	for record in _members:
		if record.arrears == 0 and _candidate(record.id).role == role:
			return true
	return false


func hire(id: int, port: int, epoch: float, credits: int) -> Dictionary:
	var candidate := _candidate(id)
	if candidate.is_empty() or candidate.origin != port or not _valid_epoch(epoch):
		return _rejected("Кандидат доступен в другом порту.")
	if _find(id) >= 0:
		return _rejected("Этот специалист уже на борту.")
	if _members.size() >= CAPACITY or credits < int(candidate.fee):
		return _rejected("Для найма нужны свободное место и средства.")
	_members.append({"id": id, "hired_at": epoch, "periods": 0, "arrears": 0})
	_members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	return _result("crew_hired", "%s принят в экипаж. Списано %d кр." % [candidate.name, candidate.fee], -int(candidate.fee))


func dismiss(id: int) -> Dictionary:
	var index := _find(id)
	if index < 0:
		return _rejected("Специалист не числится в экипаже.")
	if _members[index].arrears > 0:
		return _rejected("Перед увольнением выплатите задолженность.")
	_members.remove_at(index)
	return _result("crew_dismissed", "%s покидает экипаж." % _candidate(id).name)


func pay(id: int, credits: int) -> Dictionary:
	var index := _find(id)
	if index < 0 or credits <= 0 or _members[index].arrears == 0:
		return _rejected("Нет доступной суммы для выплаты.")
	var record := _members[index]
	var paid := mini(credits, int(record.arrears))
	record.arrears -= paid
	return _result("crew_arrears_paid", "%s: выплачено %d кр. Остаток %d кр." % [
		_candidate(id).name, paid, record.arrears], -paid)


func advance(epoch: float, credits: int) -> Dictionary:
	if _members.is_empty() or not _valid_epoch(epoch) or credits < 0:
		return {}
	var due: Array[int] = []
	var owed := 0
	var earliest := INF
	for record in _members:
		var count := _due_periods(record, epoch)
		due.append(count)
		if count > 0:
			owed += _cost(record, count)
			earliest = minf(earliest, _due_at(record, int(record.periods) + 1))
	if owed == 0:
		return {}
	var paid_counts: Array[int] = []
	var payments: Array[int] = []
	var budget := credits
	var cutoff := epoch
	if credits < owed:
		cutoff = _budget_cutoff(earliest, epoch, credits) if credits > 0 else earliest - 1.0
	for record in _members:
		var count := _due_periods(record, cutoff)
		var payment := _cost(record, count)
		paid_counts.append(count)
		payments.append(payment)
		budget -= payment
	# At most one timestamp straddles the budget cutoff. Break a tie by roster ID.
	for _slot in range(CAPACITY):
		if budget <= 0:
			break
		var next_index := -1
		var next_epoch := INF
		for index in range(_members.size()):
			if paid_counts[index] >= due[index]:
				continue
			var record := _members[index]
			var due_at := _due_at(record, int(record.periods) + paid_counts[index] + 1)
			if due_at < next_epoch:
				next_epoch = due_at
				next_index = index
		if next_index < 0:
			break
		var record := _members[next_index]
		var bill := _wage(record.id) + (int(record.arrears) if paid_counts[next_index] == 0 else 0)
		var payment := mini(bill, budget)
		payments[next_index] += payment
		paid_counts[next_index] += 1
		budget -= payment
	var arrears := 0
	for index in range(_members.size()):
		var record := _members[index]
		record.periods += due[index]
		record.arrears += due[index] * _wage(record.id) - payments[index]
		arrears += int(record.arrears)
	var paid := credits - budget
	var message := "Жалованье экипажа выплачено. Списано %d кр." % paid
	if arrears > 0:
		message = "Жалованье: выплачено %d кр. Долг экипажу %d кр." % [paid, arrears]
	return _result("crew_payroll", message, -paid)


func _budget_cutoff(first_due: float, epoch: float, credits: int) -> float:
	# Find the last fully funded prefix without iterating potentially millions of pay periods.
	var before := first_due - 1.0
	var after := epoch
	for _iteration in range(64):
		var mid := before + (after - before) * 0.5
		if mid == before or mid == after:
			break
		var bill := 0
		for record in _members:
			bill += _cost(record, _due_periods(record, mid))
		if bill <= credits:
			before = mid
		else:
			after = mid
	return before


static func _cost(record: Dictionary, periods: int) -> int:
	return periods * _wage(record.id) + int(record.arrears) if periods > 0 else 0


static func _due_at(record: Dictionary, period: int) -> float:
	return float(record.hired_at) + WAGE_PERIOD * period


static func _due_periods(record: Dictionary, epoch: float) -> int:
	var already_billed := int(record.periods)
	if epoch < _due_at(record, already_billed + 1):
		return 0
	var period := floori((epoch - float(record.hired_at)) / WAGE_PERIOD)
	# Compare canonical due timestamps too, so a float just below a boundary never pays early.
	if _due_at(record, period) > epoch:
		period -= 1
	elif _due_at(record, period + 1) <= epoch:
		period += 1
	return maxi(0, period - already_billed)


func snapshot() -> Dictionary:
	return {"members": _members.duplicate(true)}


func restore(raw: Variant, epoch: float) -> bool:
	if not _valid_epoch(epoch) or not raw is Dictionary or raw.size() != 1 or not raw.get("members") is Array:
		return false
	if raw.members.size() > CAPACITY:
		return false
	var roster: Array[Dictionary] = []
	var previous_id := -1
	for record: Variant in raw.members:
		if not record is Dictionary or record.size() != RECORD_FIELDS.size() or not record.has_all(RECORD_FIELDS):
			return false
		if not _integer(record.id, previous_id + 1, Catalog.DESTINATION_COUNT * CAPACITY - 1):
			return false
		var id := int(record.id)
		if _candidate(id).is_empty() or not _number(record.hired_at, 0.0, minf(MAX_EPOCH, epoch + CLOCK_PRECISION)):
			return false
		if not _integer(record.periods, 0, MAX_PERIODS) or not _integer(record.arrears, 0, int(record.periods) * _wage(id)):
			return false
		var periods := int(record.periods)
		if _due_at(record, periods) > epoch + CLOCK_PRECISION or _due_at(record, periods + 1) < epoch - CLOCK_PRECISION:
			return false
		roster.append({"id": id, "hired_at": float(record.hired_at), "periods": periods, "arrears": int(record.arrears)})
		previous_id = id
	_members = roster
	return true


func _find(id: int) -> int:
	for index in range(_members.size()):
		if _members[index].id == id:
			return index
	return -1


static func _result(event: String, message: String, credits := 0) -> Dictionary:
	return {"ok": true, "event": event, "message": message, "credits": credits}


static func _rejected(message: String) -> Dictionary:
	return {"ok": false, "event": "", "message": message, "credits": 0}


static func _valid_epoch(epoch: float) -> bool:
	return _number(epoch, 0.0, MAX_EPOCH)


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floorf(float(value))


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum
