extends RefCounted

const JUMP_WEAR := 5.0
const EMERGENCY_WEAR := 13.0
const WEAR_LIMIT := 100.0
const DRIVE_COOLDOWN := 18.0
const AUTO_REPAIR_COST := 140
const REPAIR_DELAY := 9.0
const MAX_EPOCH := 3155760000.0
const FIELDS := ["wear", "drive_until", "auto_fitted", "repair_at"]

var wear := 0.0
var drive_until := 0.0
var auto_fitted := false
var repair_at := 0.0


func record_jump(epoch: float, emergency: bool) -> void:
	wear = minf(WEAR_LIMIT, wear + (EMERGENCY_WEAR if emergency else JUMP_WEAR))
	if wear >= WEAR_LIMIT:
		drive_until = minf(MAX_EPOCH, epoch + DRIVE_COOLDOWN)


func record_impact(epoch: float, damage: float) -> void:
	if damage > 0.0:
		wear = minf(WEAR_LIMIT, wear + damage * 0.15)
		if auto_fitted:
			repair_at = minf(MAX_EPOCH, epoch + REPAIR_DELAY)


func repair_ready(epoch: float) -> bool:
	return auto_fitted and epoch >= repair_at


func offer(action: String, credits: int) -> Dictionary:
	var cost := AUTO_REPAIR_COST if action == "combat_auto_repair" else 25 + ceili(wear)
	var installed := auto_fitted if action == "combat_auto_repair" else wear <= 0.001
	return {"cost": cost, "installed": installed, "allowed": not installed and credits >= cost}


func buy(action: String, credits: int, epoch: float) -> int:
	var quote := offer(action, credits)
	if not quote.allowed:
		return 0
	if action == "combat_auto_repair":
		auto_fitted = true
		repair_at = minf(MAX_EPOCH, epoch + REPAIR_DELAY)
	else:
		wear = 0.0
		drive_until = 0.0
	return int(quote.cost)


func snapshot() -> Dictionary:
	return {"wear": wear, "drive_until": drive_until, "auto_fitted": auto_fitted, "repair_at": repair_at}


func restore(raw: Variant, epoch: float) -> bool:
	if not raw is Dictionary or raw.size() != FIELDS.size() or not raw.has_all(FIELDS) or not raw.auto_fitted is bool:
		return false
	if not _number(raw.wear, WEAR_LIMIT) or not _number(raw.drive_until, minf(MAX_EPOCH, epoch + DRIVE_COOLDOWN)):
		return false
	if not _number(raw.repair_at, minf(MAX_EPOCH, epoch + REPAIR_DELAY) if raw.auto_fitted else 0.0):
		return false
	if float(raw.drive_until) > 0.0 and float(raw.wear) != WEAR_LIMIT:
		return false
	wear = float(raw.wear)
	drive_until = float(raw.drive_until)
	auto_fitted = raw.auto_fitted
	repair_at = float(raw.repair_at)
	return true


static func _number(value: Variant, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0.0 and value <= maximum
