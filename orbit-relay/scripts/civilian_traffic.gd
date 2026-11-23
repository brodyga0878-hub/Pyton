extends RefCounted
## A scheduled local transport, escort and raider. Orbits and NPC decisions use
## absolute game time, so the same encounter also unfolds in an unvisited system.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Traffic = preload("res://scripts/sector_traffic.gd")

const PERIOD := 132.0
const SECTOR_OFFSET := 8.0
const APPROACH := 26.0
const RAID := 40.0
const INTERCEPT := 50.0
const RETREAT := 60.0
const DEPARTURE := 77.0
const BEAM_RANGE := 300.0
const THREAT_RANGE := 224.0
const AIM_COSINE := cos(deg_to_rad(24.0))
const FIRST_ATTACK_DELAY := 3.0
const ATTACK_DELAY := 2.8
const MISSILE_DEFENCE_RANGE := 145.0
const REACQUIRE_DELAY := 0.9
const BEAM_DURATION := 0.18
const RAIDER_HULL := 100.0
const SHOT_DAMAGE := 24.0

const TRANSPORT := [
	[0.0, Vector3(86, 96, -55)],
	[APPROACH, Vector3(-480, 130, -455)],
	[RAID, Vector3(-185, 136, -550)],
	[RETREAT, Vector3(-560, 180, -670)],
	[DEPARTURE, Vector3(60, 150, -490)],
	[108.0, Vector3(660, 188, -577)],
	[PERIOD, Vector3(86, 96, -55)],
]
const ESCORT := [
	[0.0, Vector3(145, 107, 77)],
	[APPROACH, Vector3(-585, 155, -480)],
	[RAID, Vector3(-280, 170, -534)],
	[INTERCEPT, Vector3(-383, 190, -708)],
	[RETREAT, Vector3(-488, 196, -743)],
	[DEPARTURE, Vector3(28, 171, -547)],
	[108.0, Vector3(702, 211, -597)],
	[PERIOD, Vector3(145, 107, 77)],
]
const RAIDER := [
	[APPROACH, Vector3(235, 291, -1230)],
	[RAID, Vector3(-76, 159, -687)],
	[RETREAT, Vector3(-502, 183, -823)],
	[DEPARTURE, Vector3(264, 260, -1190)],
]
const NPC_BEAMS := [
	[42.0, "raider", "trader", 7.0],
	[46.0, "raider", "trader", 7.0],
	[50.0, "patrol", "raider", 10.0],
	[54.0, "patrol", "raider", 10.0],
	[58.0, "patrol", "raider", 10.0],
]

var _raider_damage := {}
var _engaged_system := -1
var _engaged_cycle := -1
var _next_attack := 0.0
var _enemy_beam := {}
var _player_beam := {}
var _beam_system := -1
var _epoch := 0.0


func contacts(sim: RefCounted) -> Array[Dictionary]:
	var port := _anchor(sim)
	if port < 0:
		return []
	var system: int = sim.system_id
	var epoch: float = sim.orbit_time
	var phase := _phase(system, epoch)
	var raider := _raider(sim, port, phase, epoch)
	var relief_at := _relief_phase(system, phase, epoch)
	var transport_hull := 100.0 - _scheduled_damage("trader", system, phase, epoch)
	var transport_stage := "retreat" if phase >= RAID and phase < RETREAT and not raider.is_empty() and raider.hull > 0.0 else "transit"
	var escort_stage := "intercept" if phase >= INTERCEPT and phase < RETREAT and not raider.is_empty() and raider.hull > 0.0 else "escort"
	if phase >= RETREAT and phase < DEPARTURE or not raider.is_empty() and raider.hull <= 0.0:
		transport_stage = "relief"
		escort_stage = "escort"
	elif phase >= APPROACH and phase < RAID:
		transport_stage = "approach"
	var result: Array[Dictionary] = [
		_contact(sim, port, phase, TRANSPORT, "trader", "Транспорт «Роса»", transport_stage, transport_hull, relief_at),
		_contact(sim, port, phase, ESCORT, "patrol", "Эскорт «Грань»", escort_stage, 100.0, relief_at),
	]
	if not raider.is_empty() and raider.hull > 0.0:
		if raider.phase == "attack":
			var at: Vector3 = raider.position
			var threat := _airborne(sim) and at.distance_to(sim.position) <= THREAT_RANGE
			var victim: Vector3 = sim.position if threat else result[0].position
			raider.forward = at.direction_to(victim)
		result.append(raider)
	return result


func status(sim: RefCounted) -> Dictionary:
	var empty := {"phase": "clear", "hostile": false, "danger": false, "id": "", "name": "",
		"position": Vector3.ZERO, "velocity": Vector3.ZERO, "hull": 0.0, "distance": -1.0, "missile_defence": false}
	var port := _anchor(sim)
	if port < 0:
		return empty
	var epoch: float = sim.orbit_time
	var phase := _phase(int(sim.system_id), epoch)
	var raider := _raider(sim, port, phase, epoch)
	if raider.is_empty() or raider.hull <= 0.0:
		if phase >= RETREAT and phase < DEPARTURE or not raider.is_empty():
			empty.phase = "relief"
		return empty
	var at: Vector3 = raider.position
	raider.distance = at.distance_to(sim.position)
	raider.danger = raider.phase == "attack" and raider.distance <= THREAT_RANGE and _airborne(sim)
	raider.missile_defence = raider.danger and not sim.combat.ordnance.threatening_missile(epoch, sim.system_id,
		raider.id, at, MISSILE_DEFENCE_RANGE).is_empty()
	if raider.danger:
		raider.forward = at.direction_to(sim.position)
	return raider


func in_danger(sim: RefCounted) -> bool:
	var phase := _phase(int(sim.system_id), float(sim.orbit_time))
	if phase < RAID or phase >= RETREAT or not _airborne(sim):
		return false
	return bool(status(sim).danger)


func interrupt() -> void:
	_clear_engagement()


func fire_status(sim: RefCounted, range_bonus := 0.0) -> Dictionary:
	var target := status(sim)
	var reason := "Можно стрелять"
	var distance := float(target.distance)
	var effective_range := BEAM_RANGE + (maxf(0.0, range_bonus) if is_finite(range_bonus) else 0.0)
	if not target.hostile or not _airborne(sim):
		reason = "Нет цели для огня"
	elif distance > effective_range:
		reason = "Сблизьтесь до %d м" % int(effective_range)
	elif distance <= 0.01 or sim.forward().dot((target.position - sim.position) / distance) < AIM_COSINE:
		reason = "Наведите нос на рейдера"
	elif not sim.combat_line_clear(sim.position, target.position):
		reason = "Цель закрыта препятствием"
	return {"ok": reason == "Можно стрелять", "reason": reason, "distance": distance,
		"id": target.id, "position": target.position}


func fire(sim: RefCounted, range_bonus := 0.0) -> Dictionary:
	var ready := fire_status(sim, range_bonus)
	if not ready.ok:
		return {"ok": false, "event": "", "message": ready.reason}
	var epoch: float = sim.orbit_time
	_sync_beams(sim.system_id, epoch)
	_player_beam = {"from": sim.position + sim.forward() * 2.5, "to": ready.position,
		"hostile": false, "expires": epoch + BEAM_DURATION}
	return _take_hit(sim, SHOT_DAMAGE)


func missile_hit(sim: RefCounted, id: String, amount: float) -> Dictionary:
	var contact := status(sim)
	if not _airborne(sim) or not contact.hostile or id != contact.id:
		return {}
	return _take_hit(sim, amount)


func _take_hit(sim: RefCounted, amount: float) -> Dictionary:
	var epoch: float = sim.orbit_time
	var system: int = sim.system_id
	var cycle := _cycle(system, epoch)
	var phase := _phase(system, epoch)
	var damage := _damage_record(system, cycle)
	var total := minf(RAIDER_HULL, float(damage.get("damage", 0.0)) + amount)
	var remaining := maxf(0.0, RAIDER_HULL - total - _scheduled_damage("raider", system, phase, epoch))
	_raider_damage[system] = {"cycle": cycle, "damage": total, "defeated": epoch if remaining <= 0.0 else -1.0}
	if remaining > 0.0:
		return {"ok": true, "event": "ambient_fire", "message": "Попадание. Корпус рейдера %.0f%%." % remaining}
	_clear_engagement()
	return {"ok": true, "event": "ambient_victory", "message": "Рейдер обезврежен. Транспорт продолжает рейс.",
		"system": system, "cycle": cycle}


func step(sim: RefCounted, delta: float) -> Dictionary:
	if delta <= 0.0 or not is_finite(delta):
		return {}
	var epoch: float = sim.orbit_time
	var system: int = sim.system_id
	_sync_beams(system, epoch)
	var phase := _phase(system, epoch)
	if not _airborne(sim) or phase < RAID or phase >= RETREAT:
		_clear_engagement()
		return {}
	var target := status(sim)
	if not target.danger or not sim.combat_line_clear(target.position, sim.position):
		_clear_engagement()
		return {}
	var cycle := _cycle(system, epoch)
	if _engaged_system != system or _engaged_cycle != cycle:
		_engaged_system = system
		_engaged_cycle = cycle
		_next_attack = epoch + FIRST_ATTACK_DELAY
		return {"event": "ambient_engaged", "message": "Рейдер взял ваш корабль на прицел."}
	if target.missile_defence:
		_next_attack = maxf(_next_attack, epoch + REACQUIRE_DELAY)
		return {}
	if epoch < _next_attack:
		return {}
	_next_attack = epoch + ATTACK_DELAY
	_enemy_beam = {"from": target.position, "to": sim.position,
		"hostile": true, "expires": epoch + BEAM_DURATION}
	return {"event": "ambient_enemy_hit", "message": "Рейдер обстрелял ваш корабль.",
		"damage": 6.0, "source": target.position}


func beams(sim: RefCounted = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var epoch := _epoch if sim == null else float(sim.orbit_time)
	if sim == null or sim.system_id == _beam_system:
		for effect: Dictionary in [_enemy_beam, _player_beam]:
			if float(effect.get("expires", 0.0)) > epoch:
				result.append({"from": effect.from, "to": effect.to, "hostile": effect.hostile})
	if sim == null:
		return result
	var system: int = sim.system_id
	var phase := _phase(system, epoch)
	for shot: Array in NPC_BEAMS:
		if phase >= shot[0] and phase < float(shot[0]) + BEAM_DURATION:
			var nearby := contacts(sim)
			var source := _by_role(nearby, str(shot[1]))
			var target := _by_role(nearby, str(shot[2]))
			if not source.is_empty() and not target.is_empty() and sim.combat_line_clear(source.position, target.position):
				result.append({"from": source.position, "to": target.position, "hostile": shot[1] == "raider"})
			break
	return result


func snapshot() -> Dictionary:
	var damage := {}
	for system: int in _raider_damage:
		damage[str(system)] = _raider_damage[system].duplicate()
	return {"raider_damage": damage, "engaged_system": _engaged_system,
		"engaged_cycle": _engaged_cycle, "next_attack": _next_attack}


func restore(raw: Variant, epoch: float) -> bool:
	if not raw is Dictionary or raw.size() != 4 or not raw.get("raider_damage") is Dictionary:
		return false
	var engaged := _integer(raw.get("engaged_system"), -2)
	var cycle := _integer(raw.get("engaged_cycle"), -2)
	var next: Variant = raw.get("next_attack")
	if not _number(next) or not is_finite(epoch) or epoch < 0.0 or engaged < -1 or engaged >= Catalog.AUTHORED_SYSTEM_COUNT:
		return false
	if engaged < 0:
		if cycle != -1 or next != 0.0:
			return false
	elif cycle < 0 or cycle > _cycle(engaged, epoch) or next <= 0.0 or next > epoch + FIRST_ATTACK_DELAY + 0.000001:
		return false
	var damage := {}
	for key: Variant in raw.raider_damage:
		if not key is String or not key.is_valid_int():
			return false
		var system := int(key)
		if key != str(system) or system < 0 or system >= Catalog.AUTHORED_SYSTEM_COUNT:
			return false
		var record: Variant = raw.raider_damage[key]
		if not record is Dictionary or record.size() != 3:
			return false
		var raid := _integer(record.get("cycle"), -1)
		var amount: Variant = record.get("damage")
		var defeated: Variant = record.get("defeated")
		if raid < 0 or raid > _cycle(system, epoch) or not _number(amount) or not _number(defeated):
			return false
		if amount <= 0.0 or amount > RAIDER_HULL or defeated < -1.0 or defeated > epoch:
			return false
		if defeated != -1.0:
			var defeated_phase := _phase(system, defeated)
			if defeated < 0.0 or _cycle(system, defeated) != raid or defeated_phase < APPROACH or defeated_phase >= DEPARTURE:
				return false
			var volley_damage := 0.0
			for shot: Array in NPC_BEAMS:
				if shot[2] == "raider" and float(shot[0]) <= defeated_phase + 0.000001:
					volley_damage += float(shot[3])
			if float(amount) + volley_damage < RAIDER_HULL:
				return false
		damage[system] = {"cycle": raid, "damage": float(amount), "defeated": float(defeated)}
	_raider_damage = damage
	_engaged_system = engaged
	_engaged_cycle = cycle
	_next_attack = float(next)
	_beam_system = -1
	_epoch = epoch
	_enemy_beam.clear()
	_player_beam.clear()
	return true


func _raider(sim: RefCounted, port: int, phase: float, epoch: float) -> Dictionary:
	if phase < APPROACH or phase >= DEPARTURE:
		return {}
	var system: int = sim.system_id
	var damage := _damage_record(system, _cycle(system, epoch))
	var hull := maxf(0.0, RAIDER_HULL - float(damage.get("damage", 0.0)) - _scheduled_damage("raider", system, phase, epoch))
	var stage := "approach" if phase < RAID else ("attack" if phase < RETREAT else "retreat")
	return _contact(sim, port, phase, RAIDER, "raider", "Рейдер «Галс»", stage, hull)


func _contact(sim: RefCounted, port: int, phase: float, path: Array, role: String, name: String, stage: String, hull: float, relief_at := -1.0) -> Dictionary:
	var lane := _relief_lane(path, phase, relief_at) if relief_at >= 0.0 and phase < DEPARTURE else _lane(path, phase)
	var anchor: Vector3 = sim.target_position(port)
	var drift: Vector3 = sim.target_velocity(port)
	var sample := Traffic.clear_hulls(sim, anchor + lane.position, drift + lane.velocity, 28.0)
	var forward: Vector3 = lane.forward
	var relative_velocity: Vector3 = sample.velocity - drift
	if relative_velocity.length_squared() > 0.001:
		forward = relative_velocity.normalized()
	var cycle := _cycle(int(sim.system_id), float(sim.orbit_time))
	return {"id": "ambient-%s-%d-%d" % [role, sim.system_id, cycle], "name": name, "role": role, "cycle": cycle,
		"position": sample.position, "velocity": sample.velocity, "forward": forward,
		"hull": hull, "phase": stage, "hostile": role == "raider", "ambient": true}


static func _lane(path: Array, phase: float) -> Dictionary:
	for i: int in range(1, path.size()):
		var first: Array = path[i - 1]
		var last: Array = path[i]
		if phase > float(last[0]):
			continue
		var duration := float(last[0]) - float(first[0])
		var progress := clampf((phase - float(first[0])) / duration, 0.0, 1.0)
		var start: Vector3 = first[1]
		var course: Vector3 = last[1] - start
		var velocity := course * (6.0 * progress * (1.0 - progress) / duration)
		return {"position": start + course * smoothstep(0.0, 1.0, progress),
			"velocity": velocity, "forward": course.normalized()}
	return {"position": path.back()[1], "velocity": Vector3.ZERO, "forward": Vector3.FORWARD}


static func _relief_lane(path: Array, phase: float, relief_at: float) -> Dictionary:
	# Rejoin the ordinary course directly when an attack ends early. Retain
	# position and velocity at diversion and merge without a jump in either.
	var start := _lane(path, relief_at)
	var finish := _lane(path, DEPARTURE)
	var duration := DEPARTURE - relief_at
	var progress := clampf((phase - relief_at) / duration, 0.0, 1.0)
	var course: Vector3 = finish.position - start.position
	var tangent: Vector3 = start.velocity
	var easing := smoothstep(0.0, 1.0, progress)
	var fade := 1.0 - progress
	return {
		"position": start.position + course * easing + tangent * (duration * progress * fade * fade),
		"velocity": course * (6.0 * progress * fade / duration) + tangent * (fade * (1.0 - 3.0 * progress)),
		"forward": course.normalized(),
	}


func _relief_phase(system: int, phase: float, epoch: float) -> float:
	var record := _damage_record(system, _cycle(system, epoch))
	var defeated := float(record.get("defeated", -1.0))
	if defeated >= 0.0:
		return _phase(system, defeated)
	var hull := RAIDER_HULL - float(record.get("damage", 0.0))
	for shot: Array in NPC_BEAMS:
		if phase < float(shot[0]):
			break
		if shot[2] == "raider":
			hull -= float(shot[3])
			if hull <= 0.0:
				return float(shot[0])
	return -1.0


func _scheduled_damage(role: String, system: int, phase: float, epoch: float) -> float:
	var damage := _damage_record(system, _cycle(system, epoch))
	var defeated := float(damage.get("defeated", -1.0))
	var total := 0.0
	for shot: Array in NPC_BEAMS:
		if phase < float(shot[0]):
			break
		if defeated >= 0.0 and epoch - phase + float(shot[0]) > defeated:
			break
		if shot[2] == role:
			total += float(shot[3])
	return total


func _damage_record(system: int, cycle: int) -> Dictionary:
	var record: Dictionary = _raider_damage.get(system, {})
	return record if int(record.get("cycle", -1)) == cycle else {}


func _clear_engagement() -> void:
	_engaged_system = -1
	_engaged_cycle = -1
	_next_attack = 0.0


func _sync_beams(system: int, epoch: float) -> void:
	if system != _beam_system:
		_enemy_beam.clear()
		_player_beam.clear()
		_beam_system = system
	_epoch = epoch


static func _anchor(sim: RefCounted) -> int:
	var system: int = sim.system_id
	if system < 0 or system >= Catalog.AUTHORED_SYSTEM_COUNT or not sim.system_known(system):
		return -1
	var port := int(Catalog.system(system).arrival_port)
	return port if sim.station_operational(port) else -1


static func _airborne(sim: RefCounted) -> bool:
	return sim.docked < 0 and not sim.landed and sim.jump_seconds_left <= 0.0 and sim.ship.hull > 1.0


static func _cycle(system: int, epoch: float) -> int:
	return floori((epoch - float(system) * SECTOR_OFFSET) / PERIOD)


static func _phase(system: int, epoch: float) -> float:
	return fposmod(epoch - float(system) * SECTOR_OFFSET, PERIOD)


static func _by_role(contacts: Array[Dictionary], role: String) -> Dictionary:
	for contact: Dictionary in contacts:
		if contact.role == role:
			return contact
	return {}


static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value))


static func _integer(value: Variant, fallback: int) -> int:
	if _number(value) and absf(float(value)) < 1.0e12 and floorf(float(value)) == float(value):
		return int(value)
	return fallback
