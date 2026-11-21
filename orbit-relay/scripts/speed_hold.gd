extends RefCounted
## Holds the signed speed along the ship's nose in the current flight frame.

const LIMIT := 60.0
const SAVE_FIELDS := ["enabled", "setpoint"]

var enabled := false
var setpoint := 0.0


func set_enabled(value: bool) -> bool:
	if value == enabled:
		return false
	enabled = value
	return true


func set_speed(value: float) -> bool:
	if not is_finite(value):
		return false
	var bounded := clampf(value, -LIMIT, LIMIT)
	if bounded == setpoint:
		return false
	setpoint = bounded
	return true


func adjust(amount: float) -> bool:
	return set_speed(setpoint + amount)


static func projected_speed(velocity: Vector3, reference: Vector3, forward: Vector3) -> float:
	if not _valid_frame(velocity, reference, forward):
		return 0.0
	return (velocity - reference).dot(forward.normalized())


func speed_delta(velocity: Vector3, reference: Vector3, forward: Vector3, acceleration: float,
		delta: float, reachable_limit := LIMIT) -> float:
	if not enabled or not _valid_frame(velocity, reference, forward):
		return 0.0
	if not is_finite(acceleration) or acceleration <= 0.0 or not is_finite(delta) or delta <= 0.0:
		return 0.0
	if not is_finite(reachable_limit) or reachable_limit < 0.0:
		return 0.0
	var current := projected_speed(velocity, reference, forward)
	if not is_finite(current):
		return 0.0
	var limit := minf(LIMIT, reachable_limit)
	var target := clampf(setpoint, -limit, limit)
	return move_toward(current, target, acceleration * delta) - current


func snapshot() -> Dictionary:
	return {"enabled": enabled, "setpoint": setpoint}


func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != SAVE_FIELDS.size() or not value.has_all(SAVE_FIELDS):
		return false
	if not value.enabled is bool or not (value.setpoint is int or value.setpoint is float):
		return false
	var speed := float(value.setpoint)
	if not is_finite(speed) or absf(speed) > LIMIT:
		return false
	enabled = value.enabled
	setpoint = speed
	return true


static func _valid_frame(velocity: Vector3, reference: Vector3, forward: Vector3) -> bool:
	return velocity.is_finite() and reference.is_finite() and forward.is_finite() and not forward.is_zero_approx()
