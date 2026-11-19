extends RefCounted
## Ports and the mining site use the same flight coordinates.

const MiningRig = preload("res://scripts/mining_rig.gd")
const SAVE_SCHEMA := 2
const MAX_SPEED := 145.0
const MAX_STEER := 1.45
const MAX_PITCH := 1.42
const MAX_ROLL := 1.9
const STATION_RATES := [0.19, -0.27]
const DOCK_OFFSET := 8.0
const GATE_OFFSET := 70.0
const DOCK_SPEED := 5.0
const DOCK_ROLL_ERROR := 0.16
const DOCK_AIM_ERROR := 0.15
const HULL_X := 32.0
const HULL_Y := 27.0
const HULL_Z := 23.0
const REWARDS := [240, 180]
const CARGOS := ["Регуляторы охлаждения", "Калибровочные датчики"]
const ASTEROID_TARGET := 2
const ASTEROID_CENTER := Vector3(-215, -70, -415)
const ASTEROID_PAD := ASTEROID_CENTER + Vector3(0, 0, 43)
const ASTEROID_GATE := ASTEROID_CENTER + Vector3(0, 0, 105)
const ASTEROID_CLEARANCE := 43.0
const LANDING_SPEED := 4.0
const LANDING_RADIUS := 8.0

var station_names: Array[String] = ["Маяк-7", "Тихий порт"]
var station_positions: Array[Vector3] = [Vector3(0, 0, -160), Vector3(330, 65, -870)]
var position := Vector3(0, 0, -152)
var velocity := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var roll := 0.0
var throttle := 0.0
var boost := false
var docked := 0
var landed := false
var mining := MiningRig.new()
var target := 1
var autopilot := false
var autopilot_phase := ""
var credits := 0
var deliveries := 0
var contract_stage := 0
var contract_origin := -1
var contract_destination := -1
var elapsed := 0.0
var status_event := ""
var status_message := ""

var _approach_committed := false
var _departure_site := -1
var _departure_leg := 0


func speed() -> float:
	return velocity.length()


func station_axis(_index: int) -> Vector3:
	return Vector3.BACK


func station_angle(index: int) -> float:
	return wrapf(elapsed * STATION_RATES[index] + (0.55 if index == 1 else 0.0), -PI, PI)


func gate_position(index: int) -> Vector3:
	return station_positions[index] + station_axis(index) * GATE_OFFSET


func docking_position(index: int) -> Vector3:
	return station_positions[index] + station_axis(index) * DOCK_OFFSET


func target_name(index: int) -> String:
	return "Осколок" if index == ASTEROID_TARGET else station_names[index]


func target_position(index: int) -> Vector3:
	return ASTEROID_CENTER if index == ASTEROID_TARGET else station_positions[index]


func target_gate(index: int) -> Vector3:
	return ASTEROID_GATE if index == ASTEROID_TARGET else gate_position(index)


func target_contact(index: int) -> Vector3:
	return ASTEROID_PAD if index == ASTEROID_TARGET else docking_position(index)


func roll_error(index: int) -> float:
	return angle_difference(roll, 0.0 if index == ASTEROID_TARGET else station_angle(index))


func attitude() -> Basis:
	var heading := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	return heading * Basis(Vector3.BACK, roll)


func forward() -> Vector3:
	return attitude() * Vector3.FORWARD


func offer_destination() -> int:
	return 1 - docked if docked >= 0 else -1


func contract_cargo() -> String:
	var origin := contract_origin if contract_stage == 1 else docked
	return CARGOS[origin] if origin >= 0 else ""


func contract_reward() -> int:
	var origin := contract_origin if contract_stage == 1 else docked
	return REWARDS[origin] if origin >= 0 else 0


func contract_action() -> bool:
	if docked < 0:
		return false
	if contract_stage == 1:
		if docked != contract_destination:
			return false
		credits += REWARDS[contract_origin]
		deliveries += 1
		contract_stage = 2
		_announce("delivery", "Груз принят. Начислено %d кр." % REWARDS[contract_origin])
	else:
		contract_stage = 1
		contract_origin = docked
		contract_destination = offer_destination()
		target = contract_destination
		_announce("contract", "Груз на борту. Пункт назначения — %s." % station_names[target])
	return true


func change_target() -> void:
	if docked < 0 and not landed:
		target = (target + 1) % (ASTEROID_TARGET + 1)
		_approach_committed = false
		if autopilot:
			set_autopilot(true)


func change_throttle(amount: float) -> void:
	if docked < 0 and not landed:
		set_autopilot(false)
		throttle = clampf(throttle + amount, 0.0, 1.0)


func set_autopilot(enabled: bool) -> void:
	autopilot = enabled and docked < 0 and not landed
	_approach_committed = false
	_departure_leg = 0
	autopilot_phase = "К створу" if autopilot else ""
	if not autopilot:
		return
	for index in range(ASTEROID_TARGET + 1):
		var center := target_position(index)
		var offset := position - center
		if index != target and offset.length() < 80.0 and offset.z >= 0.0 and target_position(target).z < center.z:
			_departure_site = index
			_departure_leg = 1
			break


func selected_dock_status() -> Dictionary:
	if docked >= 0:
		return {"ok": true, "reason": "Можно стартовать"}
	if landed:
		var ready := mining.phase == MiningRig.STOWED
		return {"ok": ready, "reason": "Можно взлететь" if ready else "Сначала верните модуль на борт"}
	if target == ASTEROID_TARGET:
		return _landing_status()
	var relative := position - docking_position(target)
	if relative.length() > 7.0 or relative.z < -0.8 or Vector2(relative.x, relative.y).length() > 3.1:
		return {"ok": false, "reason": "Подойдите к центру стыковочного кольца"}
	if speed() > DOCK_SPEED:
		return {"ok": false, "reason": "Снизьте скорость до 5 м/с"}
	if forward().dot(Vector3.FORWARD) < cos(DOCK_AIM_ERROR):
		return {"ok": false, "reason": "Направьте нос в створ"}
	if absf(roll_error(target)) > DOCK_ROLL_ERROR:
		return {"ok": false, "reason": "Совместите крен с кольцом"}
	return {"ok": true, "reason": "Можно швартоваться"}


func _landing_status() -> Dictionary:
	var offset := position - ASTEROID_PAD
	if offset.z < -0.1 or offset.z > 7.0 or Vector2(offset.x, offset.y).length() > LANDING_RADIUS:
		return {"ok": false, "reason": "Подойдите к отмеченной площадке"}
	if speed() > LANDING_SPEED:
		return {"ok": false, "reason": "Снизьте скорость до 4 м/с"}
	if forward().dot(Vector3.FORWARD) < cos(deg_to_rad(12.0)):
		return {"ok": false, "reason": "Направьте нос к площадке"}
	return {"ok": true, "reason": "Можно садиться"}


func dock_action() -> bool:
	if docked >= 0:
		_launch()
		return true
	var status := selected_dock_status()
	if not status.ok:
		_announce("landing_denied" if target == ASTEROID_TARGET else "dock_denied", status.reason)
		return false
	if landed:
		_lift()
	else:
		_arrive()
	return true


func mine_action() -> bool:
	if not landed:
		return false
	var event := mining.action()
	match event:
		"mining_deploy":
			_announce(event, "Модуль отделяется и идёт к залежи.")
		"mining_recover":
			_announce(event, "Модуль возвращается на борт.")
		_:
			return false
	return true


func sell_ore_action() -> bool:
	if docked < 0:
		return false
	var earned := mining.sell()
	if earned == 0:
		return false
	credits += earned
	_announce("ore_sold", "Руда продана. Начислено %d кр." % earned)
	return true


func _arrive() -> void:
	if target == ASTEROID_TARGET:
		landed = true
		set_autopilot(false)
		_hold_landed_pose()
		_announce("land", "Посадка на «Осколок» завершена.")
	else:
		_dock()


func _hold_landed_pose() -> void:
	position = ASTEROID_PAD
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	throttle = 0.0
	boost = false


func _lift() -> void:
	landed = false
	yaw = PI
	velocity = Vector3.BACK * 9.0
	target = contract_destination if contract_stage == 1 else 0
	_announce("lift", "Взлёт с «Осколка».")


func _launch() -> void:
	var origin := docked
	position = docking_position(origin) + station_axis(origin) * 15.0
	yaw = PI
	pitch = 0.0
	throttle = 0.0
	velocity = station_axis(origin) * 6.0
	target = contract_destination if contract_stage == 1 and contract_destination != origin else 1 - origin
	docked = -1
	_announce("launch", "Старт со станции «%s»." % station_names[origin])


func _dock() -> void:
	docked = target
	set_autopilot(false)
	throttle = 0.0
	boost = false
	_hold_docked_pose()
	_announce("dock", "Швартовка завершена. Станция «%s»." % station_names[docked])


func _hold_docked_pose() -> void:
	position = docking_position(docked)
	velocity = Vector3.ZERO
	roll = station_angle(docked)
	yaw = 0.0
	pitch = 0.0


func update(delta: float, steer: Vector2, bank: float, boost_requested: bool, brake: bool) -> void:
	if delta <= 0.0:
		return
	elapsed += delta
	if docked >= 0:
		_hold_docked_pose()
		return
	if landed:
		var mining_event := mining.update(delta)
		match mining_event:
			"mining_ready":
				_announce(mining_event, "Добыто %d ед. руды. Заберите модуль." % mining.pending_ore)
			"mining_loaded":
				_announce(mining_event, "Модуль на борту. Руда в трюме. Можно взлетать.")
		return

	if steer.length_squared() > 0.04 or absf(bank) > 0.12 or boost_requested or brake:
		if autopilot:
			set_autopilot(false)
			_announce("manual_override", "Ручное управление")

	if autopilot:
		_autopilot_step(delta)
	else:
		yaw = wrapf(yaw - steer.x * delta * MAX_STEER, -PI, PI)
		pitch = clampf(pitch + steer.y * delta * MAX_STEER, -MAX_PITCH, MAX_PITCH)
		roll = wrapf(roll + bank * delta * MAX_ROLL, -PI, PI)
		boost = boost_requested and not brake
		var desired_velocity := Vector3.ZERO
		if brake:
			throttle = 0.0
		elif boost:
			desired_velocity = forward() * MAX_SPEED * 1.55
		else:
			desired_velocity = forward() * MAX_SPEED * throttle
		velocity = velocity.move_toward(desired_velocity, (67.0 if brake else 34.0) * delta)

	if docked >= 0 or landed:
		return
	var next := position + velocity * delta
	if _blocked(next):
		if velocity.length_squared() > 0.05:
			_announce("clearance", "Защитное торможение у препятствия")
		velocity = Vector3.ZERO
		throttle = 0.0
		set_autopilot(false)
	else:
		position = next


func _blocked(point: Vector3) -> bool:
	if point.distance_squared_to(ASTEROID_CENTER) < ASTEROID_CLEARANCE * ASTEROID_CLEARANCE:
		return true
	for index in range(station_positions.size()):
		var relative := point - station_positions[index]
		# A narrow corridor leads into the illuminated docking collar.
		var inside_corridor := relative.z >= DOCK_OFFSET - 0.8 and Vector2(relative.x, relative.y).length() < 4.4
		var hull := Vector3(relative.x / HULL_X, relative.y / HULL_Y, relative.z / HULL_Z)
		if hull.length_squared() < 1.0 and not inside_corridor:
			return true
	return false


func _autopilot_step(delta: float) -> void:
	boost = false
	var mining_site := target == ASTEROID_TARGET
	var center := target_position(target)
	var gate := target_gate(target)
	var relative := position - center
	var waypoint := gate
	var max_speed := 118.0
	var aim := Vector3.FORWARD

	if _departure_leg == 0 and not _approach_committed and position.distance_to(gate) < 3.4 and speed() < 7.0:
		_approach_committed = true

	if _approach_committed:
		waypoint = target_contact(target) + Vector3.BACK * 1.8
		max_speed = 13.0 if mining_site else 19.0
		autopilot_phase = "Посадка" if mining_site else "Стыковка"
		roll = wrapf(roll + clampf(roll_error(target), -MAX_ROLL * delta, MAX_ROLL * delta), -PI, PI)
	else:
		autopilot_phase = "К створу"
		# Approach a station from the front. The side waypoint keeps a return
		# journey from crossing the station hull from behind.
		var front_clearance := 65.0 if mining_site else 34.0
		if relative.z < front_clearance and absf(relative.x) < 77.0:
			var side := 1.0 if relative.x >= 0.0 else -1.0
			waypoint = center + Vector3(side * 84.0, relative.y, minf(relative.z, front_clearance))
			autopilot_phase = "Обход объекта"
		elif relative.z < front_clearance + 6.0:
			var side := 1.0 if relative.x >= 0.0 else -1.0
			waypoint = center + Vector3(side * 84.0, 0.0, front_clearance + 21.0)
			autopilot_phase = "Обход объекта"
		if _departure_leg > 0:
			var departure := target_position(_departure_site)
			var forward_clearance := 73.0 if _departure_site == ASTEROID_TARGET else 53.0
			var exit_point := departure + Vector3.BACK * forward_clearance
			var side := 1.0 if center.x >= departure.x else -1.0
			waypoint = exit_point if _departure_leg == 1 else exit_point + Vector3(side * 83, 0, 0)
			autopilot_phase = "Выход из зоны объекта"
			max_speed = 36.0
			if position.distance_to(waypoint) < 4.0 and speed() < 8.0:
				_departure_leg = 2 if _departure_leg == 1 else 0
		var direction := waypoint - position
		if direction.length_squared() > 0.25:
			aim = direction.normalized()

	_point_towards(aim, delta)
	var displacement := waypoint - position
	var desired_speed := minf(max_speed, minf(sqrt(42.0 * displacement.length()), displacement.length() * 1.6))
	var desired := displacement.normalized() * desired_speed
	velocity = velocity.move_toward(desired, 42.0 * delta)
	throttle = clampf(desired_speed / MAX_SPEED, 0.0, 1.0)
	if _approach_committed and selected_dock_status().ok:
		_arrive()


func _point_towards(direction: Vector3, delta: float) -> void:
	var goal_yaw := atan2(-direction.x, -direction.z)
	var goal_pitch := clampf(asin(clampf(direction.y, -1.0, 1.0)), -MAX_PITCH, MAX_PITCH)
	yaw = wrapf(yaw + clampf(angle_difference(yaw, goal_yaw), -MAX_STEER * delta, MAX_STEER * delta), -PI, PI)
	pitch = move_toward(pitch, goal_pitch, MAX_STEER * delta)


func _announce(event: String, message: String) -> void:
	status_event = event
	status_message = message


func snapshot() -> Dictionary:
	return {
		"schema": SAVE_SCHEMA,
		"position": [position.x, position.y, position.z],
		"velocity": [velocity.x, velocity.y, velocity.z],
		"yaw": yaw, "pitch": pitch, "roll": roll, "elapsed": elapsed,
		"throttle": throttle, "docked": docked, "target": target,
		"credits": credits, "deliveries": deliveries,
		"contract_stage": contract_stage, "contract_origin": contract_origin,
		"contract_destination": contract_destination,
		"landed": landed, "mining": mining.snapshot()
	}


func restore(state: Dictionary) -> bool:
	if not _integer(state.get("schema"), 1, SAVE_SCHEMA):
		return false
	var legacy := int(state.schema) == 1
	for key in ["position", "velocity"]:
		if not state.get(key) is Array or state[key].size() != 3:
			return false
		var limit := 10000000.0 if key == "position" else MAX_SPEED * 1.56
		for item in state[key]:
			if not _number(item, -limit, limit):
				return false
	if not _number(state.get("yaw"), -PI, PI) or not _number(state.get("pitch"), -MAX_PITCH, MAX_PITCH):
		return false
	if not _number(state.get("roll"), -PI, PI) or not _number(state.get("elapsed"), 0.0, 3155760000.0):
		return false
	if not _number(state.get("throttle"), 0.0, 1.0):
		return false
	for field in ["docked", "contract_origin", "contract_destination"]:
		if not _integer(state.get(field), -1, 1):
			return false
	if not _integer(state.get("target"), 0, 1 if legacy else ASTEROID_TARGET) or not _integer(state.get("contract_stage"), 0, 2):
		return false
	if not _integer(state.get("credits"), 0, 1000000000) or not _integer(state.get("deliveries"), 0, 10000000):
		return false
	var stage := int(state.contract_stage)
	var origin := int(state.contract_origin)
	var destination := int(state.contract_destination)
	if stage == 0 and (origin != -1 or destination != -1):
		return false
	if stage != 0 and (origin < 0 or destination != 1 - origin):
		return false
	var restored_position := Vector3(state.position[0], state.position[1], state.position[2])
	var restored_velocity := Vector3(state.velocity[0], state.velocity[1], state.velocity[2])
	var restored_dock := int(state.docked)
	var restored_mining := MiningRig.new()
	var restored_landed := false
	if not legacy:
		if not state.get("landed") is bool or not restored_mining.restore(state.get("mining")):
			return false
		restored_landed = state.landed
	if restored_landed:
		if restored_dock >= 0 or int(state.target) != ASTEROID_TARGET or not restored_position.is_equal_approx(ASTEROID_PAD) or not restored_velocity.is_zero_approx():
			return false
	elif restored_mining.phase != MiningRig.STOWED:
		return false
	# Old runs could stop inside the newly introduced asteroid.
	if legacy and restored_dock < 0 and restored_position.distance_to(ASTEROID_CENTER) < ASTEROID_CLEARANCE:
		restored_position = ASTEROID_GATE
		restored_velocity = Vector3.ZERO
	if restored_velocity.length() > MAX_SPEED * 1.56 or (restored_dock < 0 and _blocked(restored_position)):
		return false
	position = restored_position
	velocity = restored_velocity
	yaw = float(state.yaw)
	pitch = float(state.pitch)
	roll = float(state.roll)
	throttle = float(state.throttle)
	elapsed = float(state.elapsed)
	docked = restored_dock
	landed = restored_landed
	mining = restored_mining
	target = int(state.target)
	credits = int(state.credits)
	deliveries = int(state.deliveries)
	contract_stage = stage
	contract_origin = origin
	contract_destination = destination
	set_autopilot(false)
	boost = false
	if docked >= 0:
		_hold_docked_pose()
	elif landed:
		_hold_landed_pose()
	return true


func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= minimum and value <= maximum


func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floorf(float(value))
