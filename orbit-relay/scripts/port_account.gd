extends RefCounted
## Berth bills follow the flight calendar and remain with the port that issued them.

const Catalog := preload("res://scripts/sector_catalog.gd")
const Calendar := preload("res://scripts/mission_calendar.gd")
const DAY := Calendar.SECONDS_PER_DAY
const MAX_DEBT := 1000000000
const TARIFFS := {
	Catalog.GROUND_HANGAR: Vector2i(8, 3),
	Catalog.HEATHER_PORT: Vector2i(6, 2),
	Catalog.LIMIT_PORT: Vector2i(10, 4),
}
const RECEIPT_FIELDS := ["kind", "total", "paid", "at"]
const ACCOUNT_FIELDS := ["port", "debt", "due", "receipt"]
const VISIT_FIELDS := ["port", "since", "days", "permit"]

var _visit := {}
var _accounts: Dictionary[int, Dictionary] = {}


func anchor(port: int, epoch: float) -> void:
	_visit = {"port": port, "since": epoch, "days": 0, "permit": false} if TARIFFS.has(port) else {}


func arrive(port: int, epoch: float, credits: int) -> int:
	anchor(port, epoch)
	if _visit.is_empty():
		return 0
	return _bill(port, "entry", TARIFFS[port].x, epoch, epoch, credits)


func advance(port: int, epoch: float, credits: int) -> int:
	if not TARIFFS.has(port):
		return -1
	if _visit.get("port", -1) != port:
		anchor(port, epoch)
	var days := floori((epoch - float(_visit.since)) / DAY)
	var posted := int(_visit.days)
	if days <= posted:
		return -1
	var rate: int = TARIFFS[port].y
	var first_unpaid := posted + floori(float(credits) / rate) + 1
	_visit.days = days
	return _bill(port, "parking", (days - posted) * rate, _visit.since + days * DAY,
		_visit.since + first_unpaid * DAY, credits)


func leave() -> void:
	_visit.clear()


func clearance(port: int, epoch: float, credits: int) -> bool:
	var account: Dictionary = _accounts.get(port, {})
	return not _overdue(account, epoch) or (_visit.get("port", -1) == port and _visit.permit and credits < int(account.debt))


func status(port: int, epoch: float, credits: int) -> Dictionary:
	var tariff: Vector2i = TARIFFS.get(port, Vector2i.ZERO)
	var account: Dictionary = _accounts.get(port, {})
	var debt := int(account.get("debt", 0))
	var current: bool = not _visit.is_empty() and _visit.port == port
	var debts: Array[Dictionary] = []
	for other_port: int in _accounts:
		if other_port != port and int(_accounts[other_port].debt) > 0:
			debts.append({"port": other_port, "debt": _accounts[other_port].debt})
	return {"entry": tariff.x, "per_day": tariff.y, "debt": debt, "due": float(account.get("due", -1.0)),
		"next_bill": (float(_visit.since) + (int(_visit.days) + 1) * DAY if current else epoch + DAY) if tariff.y > 0 else -1.0,
		"receipt": account.get("receipt", {}).duplicate(), "other_debts": debts,
		"overdue": _overdue(account, epoch), "cleared": clearance(port, epoch, credits),
		"can_pay": debt > 0 and credits > 0, "can_defer": current and not _visit.permit and _overdue(account, epoch) and credits < debt}


func pay(port: int, epoch: float, credits: int) -> int:
	var account: Dictionary = _accounts.get(port, {})
	var payment := mini(int(account.get("debt", 0)), credits)
	if payment <= 0:
		return 0
	account.debt -= payment
	if account.debt == 0:
		account.due = -1.0
		if _visit.get("port", -1) == port:
			_visit.permit = false
	account["receipt"] = {"kind": "payment", "total": payment, "paid": payment, "at": epoch}
	return payment


func defer(port: int, epoch: float, credits: int) -> bool:
	if not status(port, epoch, credits).can_defer:
		return false
	_visit.permit = true
	return true


func snapshot() -> Dictionary:
	var ports := _accounts.keys()
	ports.sort()
	var accounts: Array[Dictionary] = []
	for port: int in ports:
		accounts.append(_accounts[port].duplicate(true))
	return {"visit": _visit.duplicate(), "accounts": accounts}


func restore(raw: Variant, epoch: float, docked: int, operational: Callable) -> bool:
	if not raw is Dictionary or raw.size() != 2 or not raw.get("visit") is Dictionary or not raw.get("accounts") is Array:
		return false
	if raw.accounts.size() > TARIFFS.size():
		return false
	var accounts: Dictionary[int, Dictionary] = {}
	var previous_port := -1
	for bill: Variant in raw.accounts:
		if not _valid_account(bill, epoch, previous_port) or not operational.call(int(bill.port)):
			return false
		previous_port = int(bill.port)
		var receipt: Dictionary = bill.receipt
		accounts[previous_port] = {"port": previous_port, "debt": int(bill.debt), "due": float(bill.due),
			"receipt": {"kind": str(receipt.kind), "total": int(receipt.total), "paid": int(receipt.paid), "at": float(receipt.at)}}
	var visit: Dictionary = raw.visit
	if not visit.is_empty():
		if not _valid_visit(visit, epoch, docked):
			return false
		if visit.permit and not _overdue(accounts.get(docked, {}), epoch):
			return false
	_accounts = accounts
	if visit.is_empty():
		anchor(docked, epoch)
	else:
		_visit = {"port": docked, "since": float(visit.since), "days": int(visit.days), "permit": visit.permit}
	return true


func _bill(port: int, kind: String, charge: int, at: float, first_unpaid: float, credits: int) -> int:
	var account: Dictionary = _accounts.get(port, {"port": port, "debt": 0, "due": -1.0})
	var paid := mini(charge, credits)
	if paid < charge:
		if account.debt == 0:
			account.due = first_unpaid + DAY
		account.debt = mini(MAX_DEBT, int(account.debt) + charge - paid)
	account["receipt"] = {"kind": kind, "total": charge, "paid": paid, "at": at}
	_accounts[port] = account
	return paid


static func _overdue(account: Dictionary, epoch: float) -> bool:
	return int(account.get("debt", 0)) > 0 and epoch >= float(account.due)


static func _valid_account(bill: Variant, epoch: float, previous_port: int) -> bool:
	if not bill is Dictionary or bill.size() != ACCOUNT_FIELDS.size() or not bill.has_all(ACCOUNT_FIELDS):
		return false
	if not _integer(bill.port, previous_port + 1, Catalog.DESTINATION_COUNT - 1) or not TARIFFS.has(int(bill.port)):
		return false
	if not _integer(bill.debt, 0, MAX_DEBT) or not _number(bill.due, -1.0, epoch + DAY):
		return false
	if (bill.debt == 0 and bill.due != -1.0) or (bill.debt > 0 and bill.due < DAY):
		return false
	var receipt: Variant = bill.receipt
	if not receipt is Dictionary or receipt.size() != RECEIPT_FIELDS.size() or not receipt.has_all(RECEIPT_FIELDS):
		return false
	if not _integer(receipt.total, 1, MAX_DEBT) or not _integer(receipt.paid, 0, int(receipt.total)) or not _number(receipt.at, 0.0, epoch):
		return false
	var tariff: Vector2i = TARIFFS[int(bill.port)]
	match receipt.kind:
		"entry": return int(receipt.total) == tariff.x and bill.debt >= receipt.total - receipt.paid
		"parking": return int(receipt.total) % tariff.y == 0 and bill.debt >= receipt.total - receipt.paid
		"payment": return receipt.total == receipt.paid
		_: return false


static func _valid_visit(visit: Dictionary, epoch: float, docked: int) -> bool:
	return visit.size() == VISIT_FIELDS.size() and visit.has_all(VISIT_FIELDS) and TARIFFS.has(docked) \
		and _integer(visit.port, docked, docked) and _number(visit.since, 0.0, epoch) and visit.permit is bool \
		and _integer(visit.days, floori((epoch - float(visit.since)) / DAY), floori((epoch - float(visit.since)) / DAY))


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, float(low), float(high)) and float(value) == floorf(float(value))


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= low and float(value) <= high
