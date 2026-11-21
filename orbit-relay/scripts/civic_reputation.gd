extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")
const COST := 100
const DONATION_REPUTATION := 2
const MAX_REPUTATION := 20
@warning_ignore("integer_division")
const MAX_DONATIONS := MAX_REPUTATION / DONATION_REPUTATION
const CONTRACT_REQUIREMENTS := {"fringe_beacons": 2, "limit_telemetry": 2}

var _donations := 0
var _receipt := {}


func reputation(deliveries: int) -> int:
	return mini(MAX_REPUTATION, _donations * DONATION_REPUTATION + deliveries)


func status(deliveries: int, credits: int, docked: bool) -> Dictionary:
	var current := reputation(deliveries)
	return {"score": current, "maximum": MAX_REPUTATION, "cost": COST, "raise_by": mini(DONATION_REPUTATION, MAX_REPUTATION - current),
		"donated": _donations * COST, "receipt": _receipt.duplicate(), "can_donate": docked and current < MAX_REPUTATION and credits >= COST}


func donate(port: int, epoch: float, credits: int, deliveries: int) -> bool:
	if not status(deliveries, credits, Catalog.is_port(port)).can_donate:
		return false
	_donations += 1
	_receipt = {"port": port, "at": epoch}
	return true


func snapshot() -> Dictionary:
	return {"donations": _donations, "receipt": _receipt.duplicate()}


func restore(raw: Variant, epoch: float, operational: Callable) -> bool:
	if not raw is Dictionary or raw.size() != 2 or not raw.get("receipt") is Dictionary:
		return false
	var donations: Variant = raw.get("donations")
	if not _number(donations, float(MAX_DONATIONS)) or float(donations) != floorf(float(donations)):
		return false
	var receipt: Dictionary = raw.receipt
	if donations == 0:
		if not receipt.is_empty():
			return false
	else:
		if receipt.size() != 2 or not _number(receipt.get("at"), epoch) or not _number(receipt.get("port"), Catalog.DESTINATION_COUNT - 1):
			return false
		if float(receipt.port) != floorf(float(receipt.port)) or not operational.call(int(receipt.port)):
			return false
	_donations = int(donations)
	_receipt = {} if receipt.is_empty() else {"port": int(receipt.port), "at": float(receipt.at)}
	return true


static func _number(value: Variant, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= 0.0 and value <= high
