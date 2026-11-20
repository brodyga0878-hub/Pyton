extends RefCounted
## One passenger booking occupies cabins rather than cargo space.

const Catalog = preload("res://scripts/sector_catalog.gd")
const CABIN_CAPACITY := 2
const MIN_REPUTATION := -20
const MAX_REPUTATION := 20
const MAX_RIDES := 10000000
const MAX_DEBT := 225
const MAX_EPOCH := 3155760000.0
const CLOCK_PRECISION := 0.0001
const SAVE_FIELDS := ["origin", "destination", "accepted_at", "deadline", "overdue",
	"reputation", "debt", "completed", "late"]

var _origin := -1
var _destination := -1
var _accepted_at := 0.0
var _deadline := 0.0
var _overdue := false
var _reputation := 0
var _debt := 0
var _completed := 0
var _late := 0


static func offer(origin: int, destination: int) -> Dictionary:
	if origin == destination or not Catalog.is_port(origin) or not Catalog.is_port(destination):
		return {}
	var origin_system := Catalog.system_of_site(origin)
	var destination_system := Catalog.system_of_site(destination)
	var interstellar := origin_system != destination_system
	var seats := 1
	var fare := 0
	var duration := 0.0
	if interstellar:
		var jump_cost := Catalog.jump_cost(origin_system, destination_system)
		if jump_cost <= 0:
			return {}
		seats = CABIN_CAPACITY
		fare = 420 + jump_cost * 4
		duration = 350.0 + ceilf(Catalog.jump_distance(origin_system, destination_system) * 12.0)
	else:
		var distance: float = Catalog.site(origin).center.distance_to(Catalog.site(destination).center)
		fare = 240 + ceili(distance / 18.0)
		duration = 210.0 + ceilf(distance / 12.0)
	return {
		"origin": origin, "destination": destination, "seats": seats, "fare": fare,
		"advance": floori(fare * 0.25), "duration": duration,
	}


func begin(origin: int, destination: int, epoch: float) -> Dictionary:
	if _origin >= 0:
		return _rejected("На борту уже есть пассажиры.")
	if _debt > 0:
		return _rejected("Погасите долг за предыдущий рейс.")
	var quote := offer(origin, destination)
	if quote.is_empty() or not _valid_epoch(epoch):
		return _rejected("Этот рейс недоступен.")
	_origin = origin
	_destination = destination
	_accepted_at = epoch
	_deadline = epoch + float(quote.duration)
	var advance_payment := int(quote.advance)
	return _result("passenger_accepted", "Пассажиры на борту. Аванс %d кр." % advance_payment, advance_payment)


func advance(epoch: float) -> Dictionary:
	if _origin < 0 or _overdue or not _valid_epoch(epoch) or epoch < _deadline:
		return {}
	_overdue = true
	return _result("passenger_overdue", "Срок пассажирского рейса истёк. Высадите пассажиров в действующем порту.")


func discharge(port: int, epoch: float, credits: int) -> Dictionary:
	if _origin < 0 or not Catalog.is_port(port) or not _valid_epoch(epoch) or epoch < _accepted_at or credits < 0:
		return _rejected("Высадка доступна в действующем порту во время рейса.")
	var quote := offer(_origin, _destination)
	if _overdue or epoch >= _deadline:
		_late = mini(MAX_RIDES, _late + 1)
		return _refund_advance(quote.advance, credits, -2, "passenger_late", "Пассажиры высажены с опозданием.")
	if port == _destination:
		var balance := int(quote.fare) - int(quote.advance)
		_completed = mini(MAX_RIDES, _completed + 1)
		_reputation = mini(MAX_REPUTATION, _reputation + 2)
		_clear_booking()
		return _result("passenger_paid", "Пассажиры прибыли в срок. Получено %d кр." % balance, balance)
	if port == _origin:
		return _refund_advance(quote.advance, credits, -1, "passenger_canceled", "Пассажирский рейс отменён.")
	return _rejected("До истечения срока высадка доступна в порту назначения или отправления.")


func repay(credits: int) -> Dictionary:
	if credits <= 0 or _debt == 0:
		return _rejected("Нет суммы для погашения долга.")
	var paid := mini(credits, _debt)
	_debt -= paid
	var message := "Долг за пассажирский рейс погашен."
	if _debt > 0:
		message = "Погашено %d кр. Остаток долга %d кр." % [paid, _debt]
	return _result("passenger_debt_paid", message, -paid)


func status(epoch: float) -> Dictionary:
	var active := _origin >= 0
	var quote := offer(_origin, _destination) if active else {}
	var overdue := active and (_overdue or (_valid_epoch(epoch) and epoch >= _deadline))
	var remaining := maxf(0.0, _deadline - epoch) if active and not overdue and _valid_epoch(epoch) else 0.0
	return {
		"active": active, "overdue": overdue, "origin": _origin, "destination": _destination,
		"seats": int(quote.get("seats", 0)), "capacity": CABIN_CAPACITY, "fare": int(quote.get("fare", 0)),
		"advance": int(quote.get("advance", 0)), "accepted_at": _accepted_at, "deadline": _deadline,
		"remaining": remaining, "reputation": _reputation, "debt": _debt, "completed": _completed, "late": _late,
	}


func snapshot() -> Dictionary:
	return {
		"origin": _origin, "destination": _destination, "accepted_at": _accepted_at, "deadline": _deadline,
		"overdue": _overdue, "reputation": _reputation, "debt": _debt, "completed": _completed, "late": _late,
	}


func restore(raw: Variant, epoch: float) -> bool:
	if not _valid_epoch(epoch) or not raw is Dictionary or raw.size() != SAVE_FIELDS.size() or not raw.has_all(SAVE_FIELDS):
		return false
	if not _integer(raw.origin, -1, Catalog.DESTINATION_COUNT - 1) or not _integer(raw.destination, -1, Catalog.DESTINATION_COUNT - 1):
		return false
	if not _number(raw.accepted_at, 0.0, MAX_EPOCH) or not _number(raw.deadline, 0.0, MAX_EPOCH + 600.0) or not raw.overdue is bool:
		return false
	if not _integer(raw.reputation, MIN_REPUTATION, MAX_REPUTATION) or not _integer(raw.debt, 0, MAX_DEBT):
		return false
	if not _integer(raw.completed, 0, MAX_RIDES) or not _integer(raw.late, 0, MAX_RIDES):
		return false
	var origin := int(raw.origin)
	var destination := int(raw.destination)
	var accepted_at := float(raw.accepted_at)
	var deadline := float(raw.deadline)
	if origin == -1:
		if destination != -1 or accepted_at != 0.0 or deadline != 0.0 or raw.overdue:
			return false
	else:
		var quote := offer(origin, destination)
		if quote.is_empty() or raw.debt != 0 or accepted_at > epoch + CLOCK_PRECISION:
			return false
		if absf(deadline - accepted_at - float(quote.duration)) > CLOCK_PRECISION:
			return false
		# The state on a rounded clock boundary retains whether its alert was sent.
		if (raw.overdue and epoch < deadline - CLOCK_PRECISION) or (not raw.overdue and epoch > deadline + CLOCK_PRECISION):
			return false
	_origin = origin
	_destination = destination
	_accepted_at = accepted_at
	_deadline = deadline
	_overdue = raw.overdue
	_reputation = int(raw.reputation)
	_debt = int(raw.debt)
	_completed = int(raw.completed)
	_late = int(raw.late)
	return true


func _refund_advance(advance_payment: int, credits: int, penalty: int, event: String, message: String) -> Dictionary:
	var refund := mini(credits, advance_payment)
	_debt = advance_payment - refund
	_reputation = maxi(MIN_REPUTATION, _reputation + penalty)
	_clear_booking()
	if refund > 0:
		message += " Возвращено %d кр. аванса." % refund
	if _debt > 0:
		message += " Долг %d кр." % _debt
	return _result(event, message, -refund)


func _clear_booking() -> void:
	_origin = -1
	_destination = -1
	_accepted_at = 0.0
	_deadline = 0.0
	_overdue = false


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
