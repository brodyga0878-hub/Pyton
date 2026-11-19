extends RefCounted
## One detached mining rig and the cargo it can recover from the asteroid.

const STOWED := 0
const DEPLOYING := 1
const DRILLING := 2
const READY := 3
const RETURNING := 4
const CAPACITY := 24
const BATCH := 12
const PRICE := 20
const INITIAL_RESERVE := 120
const DEPLOY_SECONDS := 2.0
const DRILL_SECONDS := 9.0
const RETURN_SECONDS := 2.0
const SAVE_FIELDS := ["phase", "phase_seconds", "ore_hold", "reserve", "pending_ore"]

var phase: int = STOWED
var phase_seconds := 0.0
var ore_hold := 0
var reserve := INITIAL_RESERVE
var pending_ore := 0


func available_to_deploy() -> bool:
	return phase == STOWED and _next_batch(ore_hold, reserve) > 0


func action() -> String:
	if available_to_deploy():
		phase = DEPLOYING
		return "mining_deploy"
	if phase == READY:
		phase = RETURNING
		return "mining_recover"
	return ""


func update(delta: float) -> String:
	if not is_finite(delta) or delta <= 0.0:
		return ""
	while delta > 0.0:
		var duration := _phase_duration(phase)
		if duration == 0.0:
			return ""
		var advanced := phase_seconds + delta
		if advanced < duration:
			phase_seconds = advanced
			return ""
		delta = advanced - duration
		phase_seconds = 0.0
		match phase:
			DEPLOYING:
				phase = DRILLING
			DRILLING:
				phase = READY
				pending_ore = _next_batch(ore_hold, reserve)
				return "mining_ready"
			RETURNING:
				phase = STOWED
				ore_hold += pending_ore
				reserve -= pending_ore
				pending_ore = 0
				return "mining_loaded"
	return ""


func sell() -> int:
	if phase != STOWED:
		return 0
	var payment := ore_hold * PRICE
	ore_hold = 0
	return payment


func progress() -> float:
	if phase == READY:
		return 1.0
	var duration := _phase_duration(phase)
	return clampf(phase_seconds / duration, 0.0, 1.0) if duration > 0.0 else 0.0


func snapshot() -> Dictionary:
	return {
		"phase": phase,
		"phase_seconds": phase_seconds,
		"ore_hold": ore_hold,
		"reserve": reserve,
		"pending_ore": pending_ore,
	}


func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != SAVE_FIELDS.size() or not value.has_all(SAVE_FIELDS):
		return false
	if not _integer_in_range(value.phase, STOWED, RETURNING):
		return false
	if not _integer_in_range(value.ore_hold, 0, CAPACITY) or not _integer_in_range(value.reserve, 0, INITIAL_RESERVE):
		return false
	if not _integer_in_range(value.pending_ore, 0, BATCH):
		return false
	if not (value.phase_seconds is int or value.phase_seconds is float):
		return false

	var restored_phase := int(value.phase)
	var restored_seconds := float(value.phase_seconds)
	var restored_hold := int(value.ore_hold)
	var restored_reserve := int(value.reserve)
	var restored_pending := int(value.pending_ore)
	var duration := _phase_duration(restored_phase)
	if not is_finite(restored_seconds) or restored_seconds < 0.0:
		return false
	if (duration == 0.0 and restored_seconds != 0.0) or (duration > 0.0 and restored_seconds >= duration):
		return false
	if restored_hold + restored_reserve > INITIAL_RESERVE:
		return false
	var batch := _next_batch(restored_hold, restored_reserve)
	if restored_phase != STOWED and batch == 0:
		return false
	var expected_pending := batch if restored_phase in [READY, RETURNING] else 0
	if restored_pending != expected_pending:
		return false

	phase = restored_phase
	phase_seconds = restored_seconds
	ore_hold = restored_hold
	reserve = restored_reserve
	pending_ore = restored_pending
	return true


static func _phase_duration(value: int) -> float:
	match value:
		DEPLOYING:
			return DEPLOY_SECONDS
		DRILLING:
			return DRILL_SECONDS
		RETURNING:
			return RETURN_SECONDS
		_:
			return 0.0


static func _next_batch(hold: int, deposit: int) -> int:
	return mini(BATCH, mini(CAPACITY - hold, deposit))


static func _integer_in_range(value: Variant, lower: int, upper: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value >= lower and value <= upper and floorf(float(value)) == float(value)
