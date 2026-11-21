extends RefCounted
## A single optional incident whose progress survives travel and reloads.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Traffic = preload("res://scripts/sector_traffic.gd")
const IDLE := 0
const OUTBOUND := 1
const ENGAGED := 2
const RETURN := 3
const COMPLETE := 4
const SIGNAL_OFFSET := Vector3(112.0, 62.0, 560.0)
const TRIGGER_RANGE := 180.0
const RETREAT_RANGE := 490.0
const BEAM_RANGE := 300.0
const AIM_COSINE := cos(deg_to_rad(24.0))
const PLAYER_DELAY := 0.38
const ENEMY_DELAY := 2.2
const FIRST_ATTACK_DELAY := 3.0
const BEAM_DURATION := 0.18
const MAX_ENEMY_HULL := 100.0
const PLAYER_DAMAGE := 24.0
const SAVE_FIELDS := ["phase", "origin", "enemy_hull", "encounter_time", "completed"]

var phase := IDLE
var origin := -1
var enemy_hull := MAX_ENEMY_HULL
var completed := 0
var _encounter_time := 0.0
var _shot_delay := 0.0
var _attack_delay := FIRST_ATTACK_DELAY
var _player_flash := 0.0
var _enemy_flash := 0.0
var _player_beam := {}
var _enemy_beam := {}


func accept(port: int) -> bool:
	if phase not in [IDLE, COMPLETE] or not Catalog.is_port(port):
		return false
	origin = port
	phase = OUTBOUND
	enemy_hull = MAX_ENEMY_HULL
	_encounter_time = 0.0
	_clear_effects()
	return true


func finish(port: int) -> int:
	if phase != RETURN or port != origin:
		return 0
	phase = COMPLETE
	completed += 1
	return _reward()


func signal_position(sim: RefCounted) -> Vector3:
	return _signal_pose(sim).position if origin >= 0 else Vector3.ZERO


func status(sim: RefCounted) -> Dictionary:
	var outbound := phase == OUTBOUND
	var local := _same_system(sim)
	var in_flight := _airborne(sim)
	var point := Vector3.ZERO
	var caption := "Дозор"
	var reason := "Примите заявку на перехват в порту"
	var available := false
	var visible := true
	match phase:
		IDLE, COMPLETE:
			available = Catalog.is_port(sim.docked)
			visible = available
		OUTBOUND, ENGAGED:
			point = signal_position(sim) if outbound else _enemy_position(sim)
			if outbound:
				caption = "Выкл. курс" if sim.patrol_course else "К сигналу"
			else:
				caption = "Выкл. прицел" if sim.patrol_course else "Навести"
			available = local and in_flight and sim.ship.hull > 1.0
			visible = outbound or (local and in_flight)
			reason = "Подойдите к источнику сигнала" if outbound else "Наведитесь на рейдера"
			if local and in_flight and sim.ship.hull <= 1.0:
				reason = "Восстановите корпус в порту"
			elif local and not in_flight and outbound:
				reason = "Выйдите в открытый космос"
		RETURN:
			point = sim.target_gate(origin)
			var report: bool = sim.docked == origin
			caption = "Доложить" if report else "К порту"
			available = report or (local and in_flight)
			reason = "Доложите о перехвате в порту «%s»" % sim.target_name(origin)
	if phase in [OUTBOUND, ENGAGED, RETURN] and not local:
		reason = "Вернитесь в систему «%s»" % Catalog.system(Catalog.system_of_site(origin)).name
	return {
		"phase": phase, "origin": origin, "available": available, "visible": visible,
		"caption": caption, "reason": reason, "point": point, "same_system": local,
		"distance": sim.position.distance_to(point) if local else -1.0,
		"enemy_hull": enemy_hull, "reward": _reward(),
	}


func in_danger(sim: RefCounted) -> bool:
	return phase == ENGAGED and _same_system(sim) and _airborne(sim)


func contacts(sim: RefCounted) -> Array[Dictionary]:
	if not in_danger(sim):
		return []
	var at := _enemy_position(sim)
	return [{
		"id": "raider-%d" % origin, "name": "Рейдер «Шип»", "role": "raider",
		"position": at, "velocity": _enemy_velocity(sim), "hull": enemy_hull,
		"forward": at.direction_to(sim.position),
	}]


func step(sim: RefCounted, delta: float) -> Dictionary:
	if delta <= 0.0 or not is_finite(delta):
		return {}
	_shot_delay = maxf(0.0, _shot_delay - delta)
	_player_flash = maxf(0.0, _player_flash - delta)
	_enemy_flash = maxf(0.0, _enemy_flash - delta)
	if phase not in [OUTBOUND, ENGAGED]:
		return {}
	if not _same_system(sim) or not _airborne(sim):
		return _retreat() if phase == ENGAGED else {}
	var distance: float = sim.position.distance_to(signal_position(sim))
	if phase == OUTBOUND:
		if distance <= TRIGGER_RANGE and sim.ship.hull > 1.0:
			phase = ENGAGED
			_attack_delay = FIRST_ATTACK_DELAY
			return {"event": "patrol_engaged", "message": "Рейдер обнаружен. Наведите корабль и откройте огонь."}
		return {}
	if distance > RETREAT_RANGE or sim.ship.hull <= 1.0:
		return _retreat()
	_encounter_time += delta
	_attack_delay -= delta
	if _attack_delay > 0.0:
		return {}
	var source := _enemy_position(sim)
	if source.distance_to(sim.position) > BEAM_RANGE or not sim.combat_line_clear(source, sim.position):
		_attack_delay = 0.25
		return {}
	_attack_delay = ENEMY_DELAY
	_enemy_flash = BEAM_DURATION
	_enemy_beam = {"from": source, "to": sim.position, "hostile": true}
	return {"event": "patrol_enemy_hit", "message": "Импульс рейдера повредил корпус.",
		"damage": 6.0 + sim.system_id, "source": source}


func fire_status(sim: RefCounted, range_bonus := 0.0) -> Dictionary:
	if not in_danger(sim):
		return {"ok": false, "reason": "Нет цели для огня", "distance": -1.0}
	var at := _enemy_position(sim)
	var offset: Vector3 = at - sim.position
	var distance := offset.length()
	var effective_range := BEAM_RANGE + (maxf(0.0, range_bonus) if is_finite(range_bonus) else 0.0)
	var reason := "Можно стрелять"
	if distance > effective_range:
		reason = "Сблизьтесь до %d м" % int(effective_range)
	elif distance <= 0.01 or sim.forward().dot(offset / distance) < AIM_COSINE:
		reason = "Наведите нос на рейдера"
	elif not sim.combat_line_clear(sim.position, at):
		reason = "Цель закрыта препятствием"
	elif _shot_delay > 0.0:
		reason = "Перезарядка"
	return {"ok": reason == "Можно стрелять", "reason": reason, "distance": distance}


func fire(sim: RefCounted, range_bonus := 0.0) -> Dictionary:
	var ready := fire_status(sim, range_bonus)
	if not ready.ok:
		return {"ok": false, "event": "", "message": ready.reason}
	_shot_delay = PLAYER_DELAY
	_player_flash = BEAM_DURATION
	_player_beam = {"from": sim.position + sim.forward() * 2.5, "to": _enemy_position(sim), "hostile": false}
	enemy_hull = maxf(0.0, enemy_hull - PLAYER_DAMAGE)
	if enemy_hull > 0.0:
		return {"ok": true, "event": "patrol_fire", "message": "Попадание. Корпус рейдера %.0f%%." % enemy_hull}
	phase = RETURN
	return {"ok": true, "event": "patrol_victory", "message": "Рейдер обезврежен. Вернитесь в порт «%s»." % sim.target_name(origin)}


func beams() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _player_flash > 0.0:
		result.append(_player_beam)
	if _enemy_flash > 0.0:
		result.append(_enemy_beam)
	return result


func snapshot() -> Dictionary:
	return {"phase": phase, "origin": origin, "enemy_hull": enemy_hull, "encounter_time": _encounter_time, "completed": completed}


func combat_clock() -> Dictionary:
	return {"shot": _shot_delay, "attack": _attack_delay} if phase == ENGAGED else {}


func restore_combat_clock(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if phase != ENGAGED:
		return value.is_empty()
	if value.size() != 2 or not _number(value.get("shot"), 0.0, PLAYER_DELAY) or not _number(value.get("attack"), 0.0, FIRST_ATTACK_DELAY):
		return false
	_shot_delay = float(value.shot)
	_attack_delay = float(value.attack)
	return true


func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != SAVE_FIELDS.size() or not value.has_all(SAVE_FIELDS):
		return false
	if not _integer(value.phase, IDLE, COMPLETE) or not _integer(value.origin, -1, Catalog.DESTINATION_COUNT - 1):
		return false
	if not _number(value.enemy_hull, 0.0, MAX_ENEMY_HULL) or not _number(value.encounter_time, 0.0, 3155760000.0):
		return false
	if not _integer(value.completed, 0, 10000000):
		return false
	var restored_phase := int(value.phase)
	var restored_origin := int(value.origin)
	var restored_hull := float(value.enemy_hull)
	if restored_phase == IDLE:
		if restored_origin != -1 or restored_hull != MAX_ENEMY_HULL or value.encounter_time != 0.0 or value.completed != 0:
			return false
	elif not Catalog.is_port(restored_origin):
		return false
	elif (restored_phase >= RETURN) != (restored_hull == 0.0):
		return false
	if restored_phase == COMPLETE and value.completed == 0:
		return false
	phase = restored_phase
	origin = restored_origin
	enemy_hull = restored_hull
	_encounter_time = float(value.encounter_time)
	completed = int(value.completed)
	_clear_effects()
	return true


func _retreat() -> Dictionary:
	phase = OUTBOUND
	_clear_effects()
	return {"event": "patrol_retreat", "message": "Контакт прерван. Рейдер остался у сигнала."}


func _clear_effects() -> void:
	_shot_delay = 0.0
	_attack_delay = FIRST_ATTACK_DELAY
	_player_flash = 0.0
	_enemy_flash = 0.0
	_player_beam.clear()
	_enemy_beam.clear()


func _enemy_position(sim: RefCounted) -> Vector3:
	var angle := fposmod(_encounter_time, TAU / 0.72) * 0.72
	return signal_position(sim) + Vector3(34.0 * sin(angle), 14.0 * sin(angle * 2.0), 35.0 * cos(angle))


func _enemy_velocity(sim: RefCounted) -> Vector3:
	var angle := fposmod(_encounter_time, TAU / 0.72) * 0.72
	return _signal_pose(sim).velocity + Vector3(34.0 * cos(angle), 28.0 * cos(angle * 2.0), -35.0 * sin(angle)) * 0.72


func _signal_pose(sim: RefCounted) -> Dictionary:
	return Traffic.clear_hulls(sim, sim.target_position(origin) + SIGNAL_OFFSET, sim.target_velocity(origin), 68.0, Catalog.system_of_site(origin))


func _same_system(sim: RefCounted) -> bool:
	return origin >= 0 and Catalog.system_of_site(origin) == sim.system_id


func _airborne(sim: RefCounted) -> bool:
	return sim.docked < 0 and not sim.landed and sim.jump_seconds_left <= 0.0


func _reward() -> int:
	return 450 + Catalog.system_of_site(origin) * 75 if origin >= 0 else 0


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and float(value) == floorf(float(value))
