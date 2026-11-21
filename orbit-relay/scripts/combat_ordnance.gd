extends RefCounted

const DART := "dart"
const LANCE := "lance"
const SLOT_COUNT := 4
const DECOY_CAPACITY := 4
const LAUNCHER_COST := 180
const DECOY_COST := 28
const DECOY_LIFETIME := 4.0
const DECOY_PULL_RANGE := 205.0
const DECOY_HIT_RADIUS := 4.2
const HOSTILE_TURN := 1.65
const HIT_RADIUS := 6.0
const POSITION_LIMIT := 10001200.0
const CLOCK_MARGIN := 0.000002
const MAX_EPOCH := 3155760000.0
const PROFILES := {
	DART: {"name": "Дротик", "cost": 45, "speed": 112.0, "turn": 2.6, "range": 410.0, "life": 5.0, "damage": 34.0},
	LANCE: {"name": "Копьё", "cost": 78, "speed": 84.0, "turn": 1.55, "range": 510.0, "life": 8.0, "damage": 56.0},
}
const SAVE_FIELDS := ["fitted", "selected", "selected_slot", "slots", "decoys", "missile", "decoy"]
const MISSILE_FIELDS := ["type", "slot", "system", "target", "position", "velocity", "expires"]
const DECOY_FIELDS := ["system", "position", "velocity", "expires"]

var fitted := false
var selected := DART
var selected_slot := -1
var slots: Array[String] = ["", "", "", ""]
var decoys := 0
var missile: Dictionary = {}
var decoy: Dictionary = {}


func offer(action: String, credits: int) -> Dictionary:
	var kind := _ammo_kind(action)
	var cost := 0
	var blocked := false
	if action == "combat_launcher":
		cost = LAUNCHER_COST
		blocked = fitted
	elif action == "combat_decoy":
		cost = DECOY_COST
		blocked = decoys >= DECOY_CAPACITY
	elif PROFILES.has(kind):
		cost = PROFILES[kind].cost
		blocked = not fitted or not slots.has("")
	return {"allowed": cost > 0 and not blocked and credits >= cost, "cost": cost, "installed": blocked}


func buy(action: String, credits: int) -> int:
	var available := offer(action, credits)
	if not available.allowed:
		return 0
	match action:
		"combat_launcher": fitted = true
		"combat_decoy": decoys += 1
		_:
			var kind := _ammo_kind(action)
			var slot := slots.find("")
			slots[slot] = kind
			if selected_slot < 0:
				select_slot(slot)
	return int(available.cost)


func ammo_counts() -> Dictionary:
	return {DART: slots.count(DART), LANCE: slots.count(LANCE)}


func select(kind: String) -> bool:
	return PROFILES.has(kind) and kind != selected and select_slot(slots.find(kind))


func select_slot(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT or slot == selected_slot or slots[slot].is_empty():
		return false
	selected_slot = slot
	selected = slots[slot]
	return true


func launch(origin: Vector3, attitude: Basis, system: int, target: String, epoch: float) -> bool:
	var slot := selected_slot
	if not fitted or slot < 0 or not missile.is_empty() or not _target_valid(target):
		return false
	var profile: Dictionary = PROFILES[selected]
	if not _number(epoch, 0.0, MAX_EPOCH - profile.life):
		return false
	var direction := -attitude.z.normalized()
	var side := attitude.x.normalized()
	var offset := (float(slot) - (SLOT_COUNT - 1) * 0.5) * 2.6
	var launch_position := origin + direction * 5.0 + side * offset
	if not launch_position.is_finite() or direction.is_zero_approx():
		return false
	missile = {"type": selected, "slot": slot, "system": system, "target": target, "position": launch_position,
		"velocity": direction * float(profile.speed), "expires": epoch + float(profile.life)}
	slots[slot] = ""
	selected_slot = slots.find(selected)
	return true


func launch_decoy(origin: Vector3, side: Vector3, drift: Vector3, system: int, epoch: float) -> bool:
	if decoys <= 0 or not decoy.is_empty() or not _number(epoch, 0.0, MAX_EPOCH - DECOY_LIFETIME):
		return false
	var direction := side.normalized()
	var launch_position := origin + direction * 18.0
	var velocity := drift.limit_length(65.0) * 0.3 + direction * 32.0
	if not launch_position.is_finite() or not velocity.is_finite() or direction.is_zero_approx():
		return false
	decoy = {"system": system, "position": launch_position, "velocity": velocity, "expires": epoch + DECOY_LIFETIME}
	decoys -= 1
	return true


func advance_missile(epoch: float, delta: float, target: Vector3) -> Dictionary:
	if missile.is_empty():
		return {}
	var profile: Dictionary = PROFILES[missile.type]
	var sweep := _advance(missile, epoch, delta, float(profile.life), target, float(profile.turn))
	if epoch >= float(missile.expires):
		missile.clear()
	return sweep


func advance_decoy(epoch: float, delta: float) -> Dictionary:
	if decoy.is_empty():
		return {}
	var sweep := _advance(decoy, epoch, delta, DECOY_LIFETIME)
	if epoch >= float(decoy.expires):
		decoy.clear()
	return sweep


static func _advance(item: Dictionary, epoch: float, delta: float, life: float,
		target := Vector3.INF, turn := 0.0) -> Dictionary:
	var start_at := maxf(epoch - delta, float(item.expires) - life)
	var finish_at := minf(epoch, float(item.expires))
	if start_at >= finish_at:
		return {}
	var from: Vector3 = item.position
	var elapsed := finish_at - start_at
	if target.is_finite():
		item.velocity = guide(item.velocity, from.direction_to(target), turn * elapsed)
	item.position = from + Vector3(item.velocity) * elapsed
	return {"from": from, "to": item.position, "system": item.system,
		"start": (start_at - (epoch - delta)) / delta, "finish": (finish_at - (epoch - delta)) / delta}


static func guide(velocity: Vector3, aim: Vector3, maximum_angle: float) -> Vector3:
	if aim.is_zero_approx():
		return velocity
	var forward := velocity.normalized()
	if forward.angle_to(aim) <= maximum_angle:
		return aim * velocity.length()
	var axis := forward.cross(aim)
	if axis.is_zero_approx():
		axis = forward.cross(Vector3.UP if absf(forward.y) < 0.99 else Vector3.RIGHT)
	return forward.rotated(axis.normalized(), maximum_angle) * velocity.length()


static func contact_fraction(from: Vector3, to: Vector3, radius: float) -> float:
	var gap := from.length_squared() - radius * radius
	if gap <= 0.0:
		return 0.0
	var movement := to - from
	var distance := movement.length_squared()
	var approach := from.dot(movement)
	var discriminant := approach * approach - distance * gap
	if distance <= 0.0 or approach >= 0.0 or discriminant < 0.0:
		return INF
	var fraction := (-approach - sqrt(discriminant)) / distance
	return fraction if fraction <= 1.0 else INF


func snapshot() -> Dictionary:
	return {"fitted": fitted, "selected": selected, "selected_slot": selected_slot, "slots": slots.duplicate(), "decoys": decoys,
		"missile": _encode(missile), "decoy": _encode(decoy)}


func restore(raw: Variant, epoch: float, system: int) -> bool:
	if not raw is Dictionary or raw.size() != SAVE_FIELDS.size() or not raw.has_all(SAVE_FIELDS):
		return false
	if not raw.fitted is bool or not raw.selected is String or not PROFILES.has(raw.selected):
		return false
	if not raw.fitted and raw.selected != DART:
		return false
	if not raw.slots is Array or raw.slots.size() != SLOT_COUNT or not _integer(raw.decoys, 0, DECOY_CAPACITY):
		return false
	var restored_slots: Array[String] = []
	for kind: Variant in raw.slots:
		if not kind is String or (not kind.is_empty() and (not raw.fitted or not PROFILES.has(kind))):
			return false
		restored_slots.append(kind)
	if not _integer(raw.selected_slot, -1, SLOT_COUNT - 1):
		return false
	var slot := int(raw.selected_slot)
	if (slot < 0 and restored_slots.has(raw.selected)) or (slot >= 0 and restored_slots[slot] != raw.selected):
		return false
	if not raw.missile is Dictionary or not raw.decoy is Dictionary:
		return false
	var restored_missile := {}
	if not raw.missile.is_empty():
		if not raw.fitted or not restored_slots.has("") or not raw.missile.has_all(MISSILE_FIELDS) \
				or raw.missile.size() != MISSILE_FIELDS.size():
			return false
		var kind: Variant = raw.missile.type
		if not kind is String or not PROFILES.has(kind) or not _target_valid(raw.missile.target):
			return false
		if not _integer(raw.missile.slot, 0, SLOT_COUNT - 1) or not restored_slots[int(raw.missile.slot)].is_empty():
			return false
		var profile: Dictionary = PROFILES[kind]
		restored_missile = _decode(raw.missile, epoch, system, float(profile.life), float(profile.speed) + 0.002)
		if restored_missile.is_empty() or absf(Vector3(restored_missile.velocity).length() - float(profile.speed)) > 0.002:
			return false
		restored_missile.slot = int(raw.missile.slot)
	var restored_decoy := {}
	if not raw.decoy.is_empty():
		if raw.decoys >= DECOY_CAPACITY or raw.decoy.size() != DECOY_FIELDS.size() or not raw.decoy.has_all(DECOY_FIELDS):
			return false
		restored_decoy = _decode(raw.decoy, epoch, system, DECOY_LIFETIME, 52.0)
		if restored_decoy.is_empty():
			return false
	fitted = raw.fitted
	selected = raw.selected
	selected_slot = slot
	slots = restored_slots
	decoys = int(raw.decoys)
	missile = restored_missile
	decoy = restored_decoy
	return true


static func _encode(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var result := item.duplicate()
	for key: String in ["position", "velocity"]:
		var vector: Vector3 = item[key]
		result[key] = [vector.x, vector.y, vector.z]
	return result


static func _decode(raw: Dictionary, epoch: float, system: int, lifetime: float, speed_limit: float) -> Dictionary:
	if not _integer(raw.system, system, system) or not _number(raw.expires, epoch, minf(MAX_EPOCH, epoch + lifetime + CLOCK_MARGIN)):
		return {}
	if float(raw.expires) <= epoch:
		return {}
	var position := _vector(raw.position, POSITION_LIMIT)
	var velocity := _vector(raw.velocity, speed_limit)
	if not position.is_finite() or not velocity.is_finite() or velocity.length() > speed_limit:
		return {}
	var result := raw.duplicate()
	result.system = system
	result.expires = float(raw.expires)
	result.position = position
	result.velocity = velocity
	return result


static func _vector(raw: Variant, limit: float) -> Vector3:
	if not raw is Array or raw.size() != 3:
		return Vector3.INF
	for item: Variant in raw:
		if not _number(item, -limit, limit):
			return Vector3.INF
	return Vector3(raw[0], raw[1], raw[2])


static func _target_valid(id: Variant) -> bool:
	return id is String and not id.is_empty() and id.length() <= 96


static func _ammo_kind(action: String) -> String:
	return action.trim_prefix("combat_missile_") if action.begins_with("combat_missile_") else ""


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and floorf(float(value)) == float(value)
