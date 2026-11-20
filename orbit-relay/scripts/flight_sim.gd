extends RefCounted
## Flight coordinates are local to the current star system.

const MiningRig = preload("res://scripts/mining_rig.gd")
const ShipSystems = preload("res://scripts/ship_systems.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const SAVE_SCHEMA := 5
const JUMP_CHARGE := 2.5
const JUMP_SPEED := 42.0
const JUMP_CLEARANCE := 45.0
const ARRIVAL_OFFSET := 90.0
const MAX_SPEED := 145.0
const RESERVE_SPEED := 42.0
const SCOOP_RATE := 7.0
const MAX_STEER := 1.45
const MAX_PITCH := 1.42
const MAX_ROLL := 1.9
const DOCK_SPEED := 5.0
const DOCK_ROLL_ERROR := 0.16
const DOCK_AIM_ERROR := 0.15
const HULL_X := 32.0
const HULL_Y := 27.0
const HULL_Z := 23.0
const ASTEROID_TARGET := 2
const ASTEROID_CENTER := Vector3(-215, -70, -415)
const ASTEROID_PAD := ASTEROID_CENTER + Vector3(0, 0, 43)
const ASTEROID_GATE := ASTEROID_CENTER + Vector3(0, 0, 105)
const LANDING_SPEED := 4.0
const LANDING_RADIUS := 8.0

var position := Vector3(0, 0, -152)
var velocity := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var roll := 0.0
var throttle := 0.0
var boost := false
var docked := 0
var landed_site := -1
var landed: bool:
	get:
		return landed_site >= 0
var mining := MiningRig.new()
var ship := ShipSystems.new()
var scooping := false
var system_id := Catalog.HOME_SYSTEM
var jump_target := -1
var jump_seconds_left := 0.0
var target := 1
var planned_target := -1
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
	var port := Catalog.site(index)
	return wrapf(elapsed * float(port.spin) + float(port.angle), -PI, PI)


func gate_position(index: int) -> Vector3:
	return target_gate(index)


func docking_position(index: int) -> Vector3:
	return target_contact(index)


func target_name(index: int) -> String:
	return Catalog.site(index).name


func target_position(index: int) -> Vector3:
	return Catalog.site(index).center


func target_gate(index: int) -> Vector3:
	return target_position(index) + Vector3.BACK * float(Catalog.site(index).gate_offset)


func target_contact(index: int) -> Vector3:
	return target_position(index) + Vector3.BACK * float(Catalog.site(index).pad_offset)


func roll_error(index: int) -> float:
	return angle_difference(roll, station_angle(index) if Catalog.is_port(index) else 0.0)


func attitude() -> Basis:
	var heading := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	return heading * Basis(Vector3.BACK, roll)


func forward() -> Vector3:
	return attitude() * Vector3.FORWARD


func offer_destination() -> int:
	if docked < 0:
		return -1
	if not Catalog.contract(docked, planned_target).is_empty():
		return planned_target
	return _default_port(docked)


func _default_port(excluded := -1) -> int:
	for id: int in Catalog.ports_for(system_id):
		if id != excluded:
			return id
	return -1


func contract_cargo() -> String:
	var offer := _current_contract()
	return "" if offer.is_empty() else str(offer[0])


func contract_reward() -> int:
	var offer := _current_contract()
	return 0 if offer.is_empty() else int(offer[1])


func _current_contract() -> Array:
	if contract_stage == 1:
		return Catalog.contract(contract_origin, contract_destination)
	return Catalog.contract(docked, offer_destination())


func contract_action() -> bool:
	if docked < 0:
		return false
	if contract_stage == 1:
		if docked != contract_destination:
			return false
		var reward := contract_reward()
		credits += reward
		deliveries += 1
		contract_stage = 2
		_announce("delivery", "Груз принят. Начислено %d кр." % reward)
	else:
		contract_stage = 1
		contract_origin = docked
		contract_destination = offer_destination()
		target = contract_destination
		_announce("contract", "Груз на борту. Пункт назначения — %s." % target_name(contract_destination))
	return true


func change_target() -> void:
	if docked < 0 and not landed:
		var options := Catalog.targets_for(system_id)
		select_target(options[(options.find(target) + 1) % options.size()])


func select_target(index: int) -> bool:
	if jump_seconds_left > 0.0 or Catalog.system_of_site(index) != system_id or index == docked or index == landed_site:
		return false
	if docked >= 0 or landed:
		planned_target = index
	else:
		target = index
		_approach_committed = false
		if autopilot:
			set_autopilot(true)
	return true


func change_throttle(amount: float) -> void:
	if docked < 0 and not landed:
		cancel_jump()
		set_autopilot(false)
		throttle = clampf(throttle + amount, 0.0, 1.0)


func set_autopilot(enabled: bool) -> void:
	autopilot = enabled and docked < 0 and not landed and jump_seconds_left <= 0.0
	_approach_committed = false
	_departure_leg = 0
	autopilot_phase = "К створу" if autopilot else ""
	if not autopilot:
		return
	for index: int in Catalog.targets_for(system_id):
		if index == Catalog.star_for(system_id):
			continue
		var center := target_position(index)
		var offset := position - center
		var near_distance := float(Catalog.site(index).radius) + 48.0
		if index != target and offset.length() < near_distance and offset.z >= 0.0 and target_position(target).z < center.z:
			_departure_site = index
			_departure_leg = 1
			break


func selected_dock_status() -> Dictionary:
	if docked >= 0:
		return {"ok": true, "reason": "Можно стартовать"}
	if landed:
		var ready := mining.phase == MiningRig.STOWED
		return {"ok": ready, "reason": "Можно взлететь" if ready else "Сначала верните модуль на борт"}
	if jump_seconds_left > 0.0:
		return {"ok": false, "reason": "Идёт зарядка прыжкового привода"}
	if target == Catalog.star_for(system_id):
		return {"ok": false, "reason": "У звезды можно собирать топливо"}
	if not Catalog.is_port(target):
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
	var offset := position - target_contact(target)
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
		_announce("dock_denied" if Catalog.is_port(target) else "landing_denied", status.reason)
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
	var earned := mining.sell(docked)
	if earned == 0:
		return false
	credits += earned
	_announce("ore_sold", "Сырьё продано. Начислено %d кр." % earned)
	return true


func refuel_unit_price() -> int:
	return Catalog.refuel_price(docked)


func service_offer(action: String) -> Dictionary:
	var offer := ship.service_offer(action, refuel_unit_price(), credits)
	offer.allowed = offer.allowed and Catalog.is_port(docked)
	return offer


func service_action(action: String) -> bool:
	if not service_offer(action).allowed:
		return false
	var paid := ship.buy(action, refuel_unit_price(), credits)
	if paid <= 0:
		return false
	credits -= paid
	match action:
		"refuel":
			_announce("service_refuel", "Бак заправлен. Списано %d кр." % paid)
		"tank":
			_announce("service_tank", "Установлен бак на %d ед. топлива." % int(ship.capacity()))
		"eco":
			_announce("service_eco", "Экономичный привод установлен.")
	return true


func scoop_status() -> Dictionary:
	var distance := position.distance_to(target_position(Catalog.star_for(system_id)))
	var near := distance <= Catalog.SCOOP_OUTER + 180.0
	var reason := ""
	if docked >= 0 or landed:
		reason = "Сбор топлива доступен в полёте у звезды"
	elif jump_seconds_left > 0.0:
		reason = "Идёт зарядка прыжкового привода"
	elif distance < Catalog.SCOOP_INNER:
		reason = "Отойдите от звезды до зоны сбора"
	elif distance > Catalog.SCOOP_OUTER:
		reason = "Подойдите к отмеченной зоне сбора"
	elif speed() > Catalog.SCOOP_SPEED:
		reason = "Снизьте скорость до %d м/с" % int(Catalog.SCOOP_SPEED)
	elif ship.fuel >= ship.capacity():
		reason = "Бак уже полон"
	return {"ok": reason.is_empty(), "reason": "Можно собирать топливо" if reason.is_empty() else reason, "near": near}


func scoop_action() -> bool:
	if scooping:
		scooping = false
		_announce("scoop_stop", "Сбор топлива остановлен.")
		return true
	var status := scoop_status()
	if not status.ok:
		_announce("scoop_denied", status.reason)
		return false
	scooping = true
	_announce("scoop_start", "Идёт сбор топлива.")
	return true


func _collect_fuel(delta: float) -> void:
	if not scooping:
		return
	var status := scoop_status()
	if not status.ok:
		scooping = false
		_announce("scoop_stop", status.reason)
		return
	ship.add_fuel(SCOOP_RATE * delta)
	if ship.fuel >= ship.capacity():
		scooping = false
		_announce("scoop_full", "Бак полностью заправлен от звезды.")


func plan_jump(destination: int) -> bool:
	if jump_seconds_left > 0.0 or Catalog.jump_cost(system_id, destination) == 0:
		return false
	jump_target = destination
	_announce("jump_planned", "Межзвёздный курс. «%s»." % Catalog.system(destination).name)
	return true


func jump_status(destination: int) -> Dictionary:
	var cost := Catalog.jump_cost(system_id, destination)
	var reason := ""
	if cost == 0:
		reason = "Выберите другую звёздную систему"
	elif docked >= 0 or landed:
		reason = "Выйдите в открытый космос"
	elif autopilot or scooping:
		reason = "Отключите автопилот и сбор топлива"
	elif speed() > JUMP_SPEED:
		reason = "Снизьте скорость до %d м/с" % int(JUMP_SPEED)
	elif ship.fuel < cost:
		reason = "Нужно %d ед. топлива" % cost
	else:
		var star := Catalog.star_for(system_id)
		for id: int in Catalog.targets_for(system_id):
			var clearance := Catalog.SCOOP_OUTER if id == star else float(Catalog.site(id).radius) + JUMP_CLEARANCE
			if position.distance_squared_to(target_position(id)) <= clearance * clearance:
				reason = "Отойдите от объекта «%s»" % target_name(id)
				break
	return {"ok": reason.is_empty(), "reason": "Можно зарядить прыжковый привод" if reason.is_empty() else reason, "cost": cost}


func start_jump() -> bool:
	if jump_seconds_left > 0.0:
		return false
	var status := jump_status(jump_target)
	if not status.ok:
		_announce("jump_denied", status.reason)
		return false
	throttle = 0.0
	boost = false
	jump_seconds_left = JUMP_CHARGE
	_announce("jump_charging", "Прыжковый привод заряжается.")
	return true


func cancel_jump() -> bool:
	if jump_seconds_left <= 0.0:
		return false
	jump_seconds_left = 0.0
	_announce("jump_canceled", "Прыжок отменён. Топливо сохранено.")
	return true


func _charge_jump(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, 67.0 * delta)
	var next := position + velocity * delta
	if _blocked(next):
		velocity = Vector3.ZERO
		cancel_jump()
		return
	position = next
	var status := jump_status(jump_target)
	if not status.ok:
		cancel_jump()
		return
	jump_seconds_left -= delta
	if jump_seconds_left > 0.000001:
		return
	jump_seconds_left = 0.0
	ship.fuel -= status.cost
	system_id = jump_target
	jump_target = -1
	target = Catalog.system(system_id).arrival_port
	position = target_gate(target) + Vector3.BACK * ARRIVAL_OFFSET
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	_announce("jump_complete", "Прыжок завершён. Система «%s»." % Catalog.system(system_id).name)


func _arrive() -> void:
	if not Catalog.is_port(target):
		mining.select_site(target)
		landed_site = target
		set_autopilot(false)
		_hold_landed_pose()
		_announce("land", "Посадка завершена. «%s»." % target_name(landed_site))
	else:
		_dock()


func _hold_landed_pose() -> void:
	position = target_contact(landed_site)
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	throttle = 0.0
	boost = false
	scooping = false


func _lift() -> void:
	var origin := landed_site
	landed_site = -1
	yaw = PI
	velocity = Vector3.BACK * 9.0
	target = _departure_target(_default_port())
	_announce("lift", "Взлёт. Площадка «%s»." % target_name(origin))


func _launch() -> void:
	var origin := docked
	position = docking_position(origin) + station_axis(origin) * 15.0
	yaw = PI
	pitch = 0.0
	throttle = 0.0
	velocity = station_axis(origin) * 6.0
	target = _departure_target(_default_port(origin))
	docked = -1
	_announce("launch", "Старт со станции «%s»." % target_name(origin))


func _departure_target(default_target: int) -> int:
	var requested := planned_target
	planned_target = -1
	if requested >= 0:
		return requested
	if contract_stage == 1 and contract_destination != docked and Catalog.system_of_site(contract_destination) == system_id:
		return contract_destination
	return default_target


func _dock() -> void:
	docked = target
	set_autopilot(false)
	throttle = 0.0
	boost = false
	scooping = false
	_hold_docked_pose()
	_announce("dock", "Швартовка завершена. Станция «%s»." % target_name(docked))


func _hold_docked_pose() -> void:
	position = docking_position(docked)
	velocity = Vector3.ZERO
	roll = station_angle(docked)
	yaw = 0.0
	pitch = 0.0


func update(delta: float, steer: Vector2, bank: float, boost_requested: bool, brake: bool) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	elapsed += delta
	if docked >= 0:
		_hold_docked_pose()
		return
	if landed:
		var mining_event := mining.update(delta)
		match mining_event:
			"mining_ready":
				_announce(mining_event, "Добыто %d ед. сырья. Заберите модуль." % mining.pending_ore)
			"mining_loaded":
				_announce(mining_event, "Модуль на борту. Сырьё в трюме. Можно взлетать.")
		return

	var manual_input := steer.length_squared() > 0.04 or absf(bank) > 0.12 or boost_requested or brake
	if jump_seconds_left > 0.0:
		if manual_input:
			cancel_jump()
		else:
			_charge_jump(delta)
		return
	if manual_input:
		if autopilot:
			set_autopilot(false)
			_announce("manual_override", "Ручное управление")

	var had_fuel := ship.fuel > 0.0
	if autopilot:
		_autopilot_step(delta)
	else:
		yaw = wrapf(yaw - steer.x * delta * MAX_STEER, -PI, PI)
		pitch = clampf(pitch + steer.y * delta * MAX_STEER, -MAX_PITCH, MAX_PITCH)
		roll = wrapf(roll + bank * delta * MAX_ROLL, -PI, PI)
		boost = boost_requested and not brake and had_fuel
		var desired_velocity := Vector3.ZERO
		if brake:
			throttle = 0.0
		elif boost:
			desired_velocity = forward() * MAX_SPEED * 1.55
		else:
			desired_velocity = forward() * (MAX_SPEED if had_fuel else RESERVE_SPEED) * throttle
		var acceleration := 34.0 if had_fuel else 20.0
		velocity = velocity.move_toward(desired_velocity, (67.0 if brake else acceleration) * delta)

	ship.burn(delta, throttle, boost)
	if had_fuel and ship.fuel <= 0.0:
		_announce("fuel_empty", "Бак пуст. Включён резервный ход до 42 м/с.")

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
	_collect_fuel(delta)


func _blocked(point: Vector3, sector_id := -1) -> bool:
	for index: int in Catalog.targets_for(system_id if sector_id < 0 else sector_id):
		if _inside_hull(point, index):
			return true
	return false


func _inside_hull(point: Vector3, index: int) -> bool:
	var relative := point - target_position(index)
	if index == Catalog.star_for(Catalog.system_of_site(index)):
		return relative.length_squared() < Catalog.STAR_CLEARANCE * Catalog.STAR_CLEARANCE
	if not Catalog.is_port(index):
		var radius := float(Catalog.site(index).radius)
		return relative.length_squared() < radius * radius
	# A narrow corridor leads into the illuminated docking collar.
	var inside_corridor := relative.z >= float(Catalog.site(index).pad_offset) - 0.8 and Vector2(relative.x, relative.y).length() < 4.4
	var hull := Vector3(relative.x / HULL_X, relative.y / HULL_Y, relative.z / HULL_Z)
	return hull.length_squared() < 1.0 and not inside_corridor


func _autopilot_step(delta: float) -> void:
	boost = false
	var star_run := target == Catalog.star_for(system_id)
	var mining_site := not Catalog.is_port(target)
	var target_radius := Catalog.STAR_CLEARANCE if star_run else float(Catalog.site(target).radius)
	var center := target_position(target)
	var gate := target_gate(target)
	var relative := position - center
	var waypoint := gate
	var max_speed := 118.0
	var aim := Vector3.FORWARD

	if _departure_leg == 0 and not _approach_committed and position.distance_to(gate) < 3.4 and speed() < 7.0:
		_approach_committed = true

	if _approach_committed:
		if star_run:
			waypoint = target_contact(target)
			max_speed = 32.0
			autopilot_phase = "Вход в зону сбора"
		else:
			waypoint = target_contact(target) + Vector3.BACK * 1.8
			max_speed = 13.0 if mining_site else 19.0
			autopilot_phase = "Посадка" if mining_site else "Стыковка"
		roll = wrapf(roll + clampf(roll_error(target), -MAX_ROLL * delta, MAX_ROLL * delta), -PI, PI)
	else:
		autopilot_phase = "К зоне сбора" if star_run else "К створу"
		# Approach a station from the front. The side waypoint keeps a return
		# journey from crossing the station hull from behind.
		var front_clearance := target_radius + 22.0 if mining_site else 34.0
		var side_clearance := maxf(84.0, target_radius + 42.0)
		if relative.z < front_clearance and absf(relative.x) < side_clearance - 7.0:
			var side := 1.0 if relative.x >= 0.0 else -1.0
			waypoint = center + Vector3(side * side_clearance, relative.y, minf(relative.z, front_clearance))
			autopilot_phase = "Обход объекта"
		elif relative.z < front_clearance + 6.0:
			var side := 1.0 if relative.x >= 0.0 else -1.0
			waypoint = center + Vector3(side * side_clearance, 0.0, front_clearance + 21.0)
			autopilot_phase = "Обход объекта"
		if _departure_leg > 0:
			var departure := target_position(_departure_site)
			var departure_radius := float(Catalog.site(_departure_site).radius)
			var forward_clearance := departure_radius + 30.0 if not Catalog.is_port(_departure_site) else 53.0
			var exit_point := departure + Vector3.BACK * forward_clearance
			var side := 1.0 if center.x >= departure.x else -1.0
			waypoint = exit_point if _departure_leg == 1 else exit_point + Vector3(side * maxf(83, departure_radius + 42.0), 0, 0)
			autopilot_phase = "Выход из зоны объекта"
			max_speed = 36.0
			if position.distance_to(waypoint) < 4.0 and speed() < 8.0:
				_departure_leg = 2 if _departure_leg == 1 else 0
		elif not star_run:
			var detour := _star_detour(waypoint)
			if detour != waypoint:
				waypoint = detour
				autopilot_phase = "Обход звезды"
				max_speed = 64.0
		var direction := waypoint - position
		if direction.length_squared() > 0.25:
			aim = direction.normalized()

	_point_towards(aim, delta)
	var displacement := waypoint - position
	if ship.fuel <= 0.0:
		max_speed = minf(max_speed, RESERVE_SPEED)
	var desired_speed := minf(max_speed, minf(sqrt(42.0 * displacement.length()), displacement.length() * 1.6))
	var desired := displacement.normalized() * desired_speed
	velocity = velocity.move_toward(desired, 42.0 * delta)
	throttle = clampf(desired_speed / MAX_SPEED, 0.0, 1.0)
	if _approach_committed and star_run and displacement.length() < 2.0 and speed() < 3.0:
		set_autopilot(false)
		throttle = 0.0
		_announce("star_arrival", "Корабль у звезды «%s». Можно включить сбор топлива." % target_name(target))
	elif _approach_committed and not star_run and selected_dock_status().ok:
		_arrive()


func _star_detour(waypoint: Vector3) -> Vector3:
	var center := target_position(Catalog.star_for(system_id))
	var radial := position - center
	var course := waypoint - position
	var margin_squared := Catalog.SCOOP_INNER * Catalog.SCOOP_INNER
	if radial.length_squared() < margin_squared:
		return center + radial.normalized() * (Catalog.STAR_CLEARANCE + 60.0)
	if course.length_squared() < 0.001:
		return waypoint
	var closest := radial + course * clampf(-radial.dot(course) / course.length_squared(), 0.0, 1.0)
	if closest.length_squared() >= margin_squared:
		return waypoint
	var outward := radial.normalized()
	var sideways := course.slide(outward)
	if sideways.length_squared() < 0.001:
		sideways = Vector3.RIGHT.slide(outward)
		if sideways.length_squared() < 0.001:
			sideways = Vector3.UP.slide(outward)
	return center + outward * (Catalog.STAR_CLEARANCE + 60.0) + sideways.normalized() * 210.0


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
		"landed_site": landed_site, "planned_target": planned_target, "mining": mining.snapshot(),
		"ship": ship.snapshot(), "system_id": system_id, "jump_target": jump_target,
	}


func restore(state: Dictionary) -> bool:
	if not _integer(state.get("schema"), 1, SAVE_SCHEMA):
		return false
	var schema := int(state.schema)
	var pre_galaxy := schema < 5
	var pre_fuel := schema < 4
	var pre_sector := schema < 3
	var restored_system := Catalog.HOME_SYSTEM
	var restored_jump := -1
	if not pre_galaxy:
		if not _integer(state.get("system_id"), 0, Catalog.SYSTEM_COUNT - 1) or not _integer(state.get("jump_target"), -1, Catalog.SYSTEM_COUNT - 1):
			return false
		restored_system = int(state.system_id)
		restored_jump = int(state.jump_target)
		if restored_jump >= 0 and Catalog.jump_cost(restored_system, restored_jump) == 0:
			return false
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
	var site_count := Catalog.DESTINATION_COUNT
	if pre_galaxy:
		site_count = schema + 1 if pre_sector else (Catalog.SITE_COUNT if pre_fuel else Catalog.TARGET_COUNT)
	for field in ["docked", "contract_origin", "contract_destination"]:
		if not _integer(state.get(field), -1, site_count - 1):
			return false
		if int(state[field]) >= 0 and not Catalog.is_port(int(state[field])):
			return false
	if not _integer(state.get("target"), 0, site_count - 1) or not _integer(state.get("contract_stage"), 0, 2):
		return false
	if Catalog.system_of_site(int(state.target)) != restored_system or (int(state.docked) >= 0 and Catalog.system_of_site(int(state.docked)) != restored_system):
		return false
	if not _integer(state.get("credits"), 0, 1000000000) or not _integer(state.get("deliveries"), 0, 10000000):
		return false
	var stage := int(state.contract_stage)
	var origin := int(state.contract_origin)
	var destination := int(state.contract_destination)
	if stage == 0 and (origin != -1 or destination != -1):
		return false
	if stage != 0 and Catalog.contract(origin, destination).is_empty():
		return false
	var restored_position := Vector3(state.position[0], state.position[1], state.position[2])
	var restored_velocity := Vector3(state.velocity[0], state.velocity[1], state.velocity[2])
	var restored_dock := int(state.docked)
	var restored_mining := MiningRig.new()
	var restored_ship := ShipSystems.new()
	var restored_landing := -1
	var restored_plan := -1
	if schema >= 2 and not restored_mining.restore(state.get("mining"), schema == 2, pre_galaxy):
		return false
	if not pre_fuel and not restored_ship.restore(state.get("ship")):
		return false
	if schema == 2:
		if not state.get("landed") is bool:
			return false
		if state.landed:
			restored_landing = ASTEROID_TARGET
	elif not pre_sector:
		if not _integer(state.get("landed_site"), -1, site_count - 1) or not _integer(state.get("planned_target"), -1, site_count - 1):
			return false
		restored_landing = int(state.landed_site)
		restored_plan = int(state.planned_target)
	if restored_landing >= 0:
		if not Catalog.is_mine_site(restored_landing) or restored_dock >= 0 or int(state.target) != restored_landing or restored_mining.site_id != restored_landing:
			return false
		if not restored_position.is_equal_approx(target_contact(restored_landing)) or not restored_velocity.is_zero_approx():
			return false
	elif restored_mining.phase != MiningRig.STOWED:
		return false
	if restored_plan >= 0:
		if Catalog.system_of_site(restored_plan) != restored_system or restored_plan == restored_dock or restored_plan == restored_landing or (restored_dock < 0 and restored_landing < 0):
			return false
	# Earlier saves may occupy coordinates where a new hull was added.
	if pre_fuel and restored_dock < 0 and restored_landing < 0:
		for index in range(site_count, Catalog.TARGET_COUNT):
			if _inside_hull(restored_position, index):
				restored_position = target_gate(index)
				restored_velocity = Vector3.ZERO
				break
	if restored_velocity.length() > MAX_SPEED * 1.56 or (restored_dock < 0 and _blocked(restored_position, restored_system)):
		return false
	position = restored_position
	velocity = restored_velocity
	yaw = float(state.yaw)
	pitch = float(state.pitch)
	roll = float(state.roll)
	throttle = float(state.throttle)
	elapsed = float(state.elapsed)
	docked = restored_dock
	landed_site = restored_landing
	mining = restored_mining
	ship = restored_ship
	scooping = false
	system_id = restored_system
	jump_target = restored_jump
	jump_seconds_left = 0.0
	target = int(state.target)
	planned_target = restored_plan
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
