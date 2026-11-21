extends RefCounted
## Records confiscation notices and unpaid fines by the authority that issued them.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Factions = preload("res://scripts/faction_fronts.gd")
const ShipSystems = preload("res://scripts/ship_systems.gd")
const Economy = preload("res://scripts/port_economy.gd")
const VELAR_AUTHORITY := 1
const MEDICAL_ALLOWANCE := 4
const MAX_HOLD := ShipSystems.HULLS[ShipSystems.FREIGHTER_HULL].expanded_cargo
const BASE_FINE := 100
const UNIT_FINE := 45
const MAX_DEBT := 1000000000
const MAX_VIOLATIONS := 100000000
const CLOCK_PRECISION := 0.0001
const SAVE_FIELDS := ["debts", "notice", "violations"]
const NOTICE_FIELDS := ["authority", "port", "good", "quantity", "fine", "epoch"]

var _debts: Array[int] = [0, 0]
var _notice: Dictionary = {}
var _violations := 0


static func allowance(authority: int, good: String) -> int:
	return Economy.allowance(authority, good)


static func excess(authority: int, good: String, quantity: int) -> int:
	var limit := allowance(authority, good)
	return 0 if limit < 0 or quantity <= limit else quantity - limit


func record(authority: int, port: int, good: String, quantity: int, epoch: float) -> Dictionary:
	if not _valid_violation(authority, port, good, quantity) or not _valid_epoch(epoch):
		return _rejected("Не удалось зарегистрировать таможенное нарушение.")
	if not _notice.is_empty() and epoch < float(_notice.epoch):
		return _rejected("Время нарушения предшествует последней записи таможни.")
	var fine := _fine(quantity)
	if _violations >= MAX_VIOLATIONS or _debts[authority] > MAX_DEBT - fine:
		return _rejected("Достигнут предел таможенной задолженности или записей.")
	_debts[authority] += fine
	_notice = {"authority": authority, "port": port, "good": good, "quantity": quantity,
		"fine": fine, "epoch": epoch}
	_violations += 1
	return {"ok": true, "credits": 0, "event": "customs_inspection", "debt": _debts[authority],
		"notice": _notice.duplicate(), "message": "Таможня «%s» изъяла: %s (%d ед.). Штраф %d кр." % [
			Factions.faction_name(authority), Economy.good_name(good), quantity, fine]}


func pay(authority: int, credits: int) -> Dictionary:
	if not _valid_authority(authority) or _debts[authority] == 0:
		return _rejected("Нет задолженности перед этой таможней.")
	if credits <= 0:
		return _rejected("Недостаточно средств для оплаты штрафа.")
	var paid := mini(credits, _debts[authority])
	_debts[authority] -= paid
	return {"ok": true, "credits": -paid, "event": "customs_paid", "paid": paid,
		"debt": _debts[authority], "message": "Уплачено %d кр. Остаток штрафов этой таможни %d кр." % [
			paid, _debts[authority]]}


func status(authority: int) -> Dictionary:
	var debts: Array[Dictionary] = []
	var total := 0
	for index in range(_debts.size()):
		var amount := _debts[index]
		if amount > 0:
			debts.append({"authority": index, "name": Factions.faction_name(index), "amount": amount})
			total += amount
	return {"debt": _debts[authority] if _valid_authority(authority) else 0, "total_debt": total,
		"debts": debts, "notice": _notice.duplicate(), "violations": _violations}


func snapshot() -> Dictionary:
	return {"debts": _debts.duplicate(), "notice": _notice.duplicate(), "violations": _violations}


func restore(raw: Variant, epoch: float, pre_assortment := false) -> bool:
	if not raw is Dictionary or not _valid_epoch(epoch) or not _has_fields(raw, SAVE_FIELDS):
		return false
	if not raw.debts is Array or raw.debts.size() != Factions.FACTIONS.size():
		return false
	if not _valid_integer(raw.violations, 0, MAX_VIOLATIONS) or not raw.notice is Dictionary:
		return false
	var violations := int(raw.violations)
	var debts: Array[int] = []
	for authority in range(Factions.FACTIONS.size()):
		var maximum := 0 if pre_assortment and authority != VELAR_AUTHORITY else MAX_DEBT
		if not _valid_integer(raw.debts[authority], 0, maximum):
			return false
		debts.append(int(raw.debts[authority]))
	var notice: Dictionary = {}
	if violations > 0:
		notice = _restore_notice(raw.notice, epoch, pre_assortment)
		var max_seizure := MAX_HOLD - MEDICAL_ALLOWANCE if pre_assortment else MAX_HOLD
		if notice.is_empty() or debts[0] + debts[1] > _fine(max_seizure) * (violations - 1) + int(notice.fine):
			return false
	elif not raw.notice.is_empty() or debts[0] + debts[1] != 0:
		return false
	_debts = debts
	_notice = notice
	_violations = violations
	return true


static func _restore_notice(raw: Dictionary, epoch: float, pre_assortment: bool) -> Dictionary:
	if not _has_fields(raw, NOTICE_FIELDS):
		return {}
	if not _valid_integer(raw.authority, 0, Factions.FACTIONS.size() - 1):
		return {}
	if not _valid_integer(raw.port, 0, Catalog.DESTINATION_COUNT - 1) or not raw.good is String:
		return {}
	if pre_assortment and raw.good != "medical":
		return {}
	if not _valid_integer(raw.quantity, 1, MAX_HOLD):
		return {}
	if not _valid_violation(int(raw.authority), int(raw.port), raw.good, int(raw.quantity)):
		return {}
	var fine := _fine(int(raw.quantity))
	if not _valid_integer(raw.fine, fine, fine):
		return {}
	if not (raw.epoch is int or raw.epoch is float):
		return {}
	var issued_at := float(raw.epoch)
	if not _valid_epoch(issued_at) or issued_at > epoch + CLOCK_PRECISION:
		return {}
	return {"authority": int(raw.authority), "port": int(raw.port), "good": raw.good,
		"quantity": int(raw.quantity), "fine": fine, "epoch": issued_at}


static func _valid_violation(authority: int, port: int, good: String, quantity: int) -> bool:
	var limit := allowance(authority, good)
	if limit < 0 or quantity < 1 or quantity > MAX_HOLD - limit or not Catalog.is_port(port):
		return false
	var system := Catalog.system_of_site(port)
	if system < Factions.CORE_OWNERS.size():
		return Factions.CORE_OWNERS[system] == authority
	return system in Factions.FRONTIER_SYSTEMS


static func _fine(quantity: int) -> int:
	return BASE_FINE + UNIT_FINE * quantity


static func _valid_authority(authority: int) -> bool:
	return authority >= 0 and authority < Factions.FACTIONS.size()


static func _valid_epoch(epoch: float) -> bool:
	return is_finite(epoch) and epoch >= 0.0 and epoch <= Factions.MAX_ORBIT_CLOCK


static func _valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and value >= minimum and value <= maximum and value == int(value)


static func _has_fields(raw: Dictionary, fields: Array) -> bool:
	return raw.size() == fields.size() and raw.has_all(fields)


static func _rejected(message: String) -> Dictionary:
	return {"ok": false, "credits": 0, "event": "", "message": message}
