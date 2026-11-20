extends RefCounted
## Flight coordinates are local to the current star system.

const MiningRig = preload("res://scripts/mining_rig.gd")
const ShipSystems = preload("res://scripts/ship_systems.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")
const Dynamics = preload("res://scripts/orbital_dynamics.gd")
const Navigation = preload("res://scripts/orbital_navigation.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const Economy = preload("res://scripts/port_economy.gd")
const Traffic = preload("res://scripts/sector_traffic.gd")
const Patrol = preload("res://scripts/patrol_encounter.gd")
const Expedition = preload("res://scripts/expedition.gd")
const FactionFronts = preload("res://scripts/faction_fronts.gd")
const ConvoyOrders = preload("res://scripts/convoy_orders.gd")
const SAVE_SCHEMA := 13
const TIME_SCALES := [1, 4, 16]
const MAX_FLIGHT_STEP := 1.0 / 60.0
const JUMP_CHARGE := 2.5
const JUMP_SPEED := 42.0
const JUMP_CLEARANCE := 45.0
const ARRIVAL_OFFSET := 90.0
const MAX_SPEED := 145.0
const RESERVE_SPEED := 42.0
const SCOOP_RATE := 7.0
const HEAT_SCOOP_SLOW := 55.0
const HEAT_SCOOP_LIMIT := 76.0
const HEAT_DAMAGE_LIMIT := 85.0
const MAX_STEER := 1.45
const MAX_PITCH := PI * 0.5
const LEGACY_MAX_PITCH := 1.42
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
const FREE_LANDING_MAX_HEIGHT := 10.0
const LANDING_ANGLE := 20.0
const IMPACT_DAMAGE_SPEED := 14.0
const PATROL_CRUISE_SPEED := 70.0
const CONVOY_CRUISE_SPEED := 105.0
const CONVOY_ESCORT_SPACING := 54.0
const CONVOY_AIM_SPACING := 142.0
const FRAME_MARGIN := 110.0
const STAR_WARP_MARGIN := 120.0
const MAX_SAVED_SPEED := MAX_SPEED * 1.56 + 8.0
const ORBIT_MIN_RADIUS := 520.0
const ORBIT_MAX_RADIUS := 1800.0
const ORBIT_MAX_SPEED := 30.0
const ORBIT_MIN_FUEL := 3.0
const ORBIT_CLEARANCE := 110.0
const ORBIT_BURN_ACCELERATION := 12.0
const ORBIT_SPEED_TOLERANCE := 0.12
const ORBIT_TIMEOUT := 11.0
const ORBIT_ALIGNMENT := cos(deg_to_rad(3.0))

var position := Vector3(0, 0, -152)
var velocity := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var roll := 0.0
var throttle := 0.0
var boost := false
var flight_assist := true
var orbit_maneuver := false
var orbit_maneuver_focus := -1
var docked := 0
var landed_site := -1
var landing_direction := Vector3.ZERO
var landed: bool:
	get:
		return landed_site >= 0
var mining := MiningRig.new()
var ship := ShipSystems.new()
var market := Economy.new()
var patrol := Patrol.new()
var patrol_course := false
var expedition := Expedition.new()
var factions := FactionFronts.new()
var convoy_order := ConvoyOrders.new()
var convoy_course := false
var project_course := false
var scooping := false
var star_heat := 0.0
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
var contract_route_id := ""
var contract_leg := -1
var elapsed := 0.0
var orbit_time := 0.0
var time_scale := 1
var status_event := ""
var status_message := ""

var _approach_committed := false
var _departure_site := -1
var _departure_leg := 0
var _departure_axis := Vector3.ZERO
var _sample_time := -1.0
var _samples: Dictionary[int, Dictionary] = {}
var _orientation := Quaternion.IDENTITY
var _orientation_angles := Vector3.ZERO
var _orbit_normal := Vector3.ZERO
var _orbit_seconds := 0.0
var _orbit_phase := ""


func speed() -> float:
	return velocity.length()


func reference_site() -> int:
	if docked >= 0:
		return docked
	if landed:
		return landed_site
	if target == Catalog.star_for(system_id):
		return -1
	var radius := float(Catalog.site(target).radius) + FRAME_MARGIN
	return target if position.distance_squared_to(target_position(target)) <= radius * radius else -1


func relative_speed() -> float:
	if docked >= 0 or landed:
		return 0.0
	var site := reference_site()
	return speed_relative_to(site) if site >= 0 else speed()


func speed_relative_to(index: int) -> float:
	return (velocity - target_velocity(index)).length()


func time_status() -> Dictionary:
	if jump_seconds_left > 0.0:
		return {"allowed": false, "reason": "Зарядка прыжкового привода"}
	if orbit_maneuver:
		return {"allowed": false, "reason": "Орбитальный манёвр"}
	if scooping:
		return {"allowed": false, "reason": "Сбор топлива"}
	if patrol.in_danger(self):
		return {"allowed": false, "reason": "Боевой контакт"}
	if convoy_course or convoy_order.in_danger(self):
		return {"allowed": false, "reason": "Сближение с конвоем"}
	if docked >= 0 or landed:
		return {"allowed": true, "reason": ""}
	if star_heat >= HEAT_SCOOP_LIMIT:
		return {"allowed": false, "reason": "Корпус ещё горячий"}
	var star := Catalog.star_for(system_id)
	for id: int in local_targets():
		var radius := Catalog.SCOOP_OUTER + STAR_WARP_MARGIN if id == star else float(Catalog.site(id).radius) + FRAME_MARGIN
		if position.distance_squared_to(target_position(id)) <= radius * radius:
			return {"allowed": false, "reason": "Рядом «%s»" % target_name(id)}
	return {"allowed": true, "reason": ""}


func cycle_time_scale() -> bool:
	var availability := time_status()
	if not availability.allowed:
		_announce("time_denied", "Ускорение недоступно. %s." % availability.reason)
		return false
	time_scale = TIME_SCALES[(TIME_SCALES.find(time_scale) + 1) % TIME_SCALES.size()]
	_announce("time_scale", "Скорость времени ×%d." % time_scale)
	return true


func reset_time_scale() -> bool:
	if time_scale == 1:
		return false
	time_scale = 1
	_announce("time_normal", "Возврат к обычному времени.")
	return true


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
	return str(Catalog.site(index).get("name", ""))


func system_known(index: int) -> bool:
	return expedition.known(index)


func system_faction_name(index: int) -> String:
	return FactionFronts.faction_name(factions.owner(index))


func station_operational(index: int) -> bool:
	return Catalog.is_port(index) and _site_available(index, expedition)


func local_targets() -> Array:
	var targets := Catalog.targets_for(system_id)
	if system_id < Catalog.CORE_SYSTEM_COUNT or expedition.commissioned(system_id):
		return targets
	return targets.filter(func(id: int) -> bool: return not Catalog.is_port(id))


func local_ports() -> Array:
	return Catalog.ports_for(system_id) if system_id < Catalog.CORE_SYSTEM_COUNT or expedition.commissioned(system_id) else []


func _site_available(index: int, progress: RefCounted) -> bool:
	var system := Catalog.system_of_site(index)
	if system >= 0 and system < Catalog.CORE_SYSTEM_COUNT:
		return true
	return progress.known(system) and (not Catalog.is_port(index) or progress.commissioned(system))


func target_position(index: int) -> Vector3:
	return _orbital_state(index).position


func target_velocity(index: int) -> Vector3:
	return _orbital_state(index).velocity


func _orbital_state(index: int) -> Dictionary:
	if orbit_time != _sample_time:
		_samples.clear()
		_sample_time = orbit_time
	if not _samples.has(index):
		_samples[index] = Orbit.sample(index, orbit_time)
	return _samples[index]


func target_gate(index: int) -> Vector3:
	return target_position(index) + Vector3.BACK * float(Catalog.site(index).gate_offset)


func target_contact(index: int) -> Vector3:
	return target_position(index) + Vector3.BACK * float(Catalog.site(index).pad_offset)


func intercept_time(index: int) -> float:
	if Catalog.system_of_site(index) != system_id:
		return 0.0
	var from_gate := target_gate(index) - position
	var drift := target_velocity(index)
	var cruise := 118.0 if ship.fuel > 0.0 else RESERVE_SPEED
	var speed_difference := cruise * cruise - drift.length_squared()
	var projection := from_gate.dot(drift)
	return (projection + sqrt(projection * projection + speed_difference * from_gate.length_squared())) / speed_difference


func roll_error(index: int) -> float:
	return angle_difference(roll, station_angle(index) if Catalog.is_port(index) else 0.0)


func attitude() -> Basis:
	if landed:
		return landed_basis()
	return Basis(_flight_orientation())


func forward() -> Vector3:
	return attitude() * Vector3.FORWARD


func _flight_orientation() -> Quaternion:
	# Approach controllers still set the individual aiming angles.
	var angles := Vector3(pitch, yaw, roll)
	return _orientation if angles == _orientation_angles else Quaternion.from_euler(angles)


func _rotate_manual(steer: Vector2, bank: float, delta: float) -> void:
	var rates := Vector3(steer.y * MAX_STEER, -steer.x * MAX_STEER, bank * MAX_ROLL)
	var speed := rates.length()
	if speed <= 0.000001:
		return
	var turn := Quaternion(rates / speed, speed * delta)
	_set_orientation(_flight_orientation() * turn)


func _set_orientation(facing: Quaternion) -> void:
	_orientation = facing.normalized()
	var angles := Basis(_orientation).get_euler()
	pitch = clampf(angles.x, -MAX_PITCH, MAX_PITCH)
	yaw = clampf(angles.y, -PI, PI)
	roll = clampf(angles.z, -PI, PI)
	_orientation_angles = Vector3(pitch, yaw, roll)


func set_flight_assist(enabled: bool) -> bool:
	if enabled == flight_assist or jump_seconds_left > 0.0:
		return false
	reset_time_scale()
	set_autopilot(false)
	flight_assist = enabled
	throttle = 0.0
	boost = false
	_announce("flight_assist", "Стабилизация включена." if enabled else "Режим инерции. Тормоз гасит дрейф.")
	return true


func gravity_at(at: Vector3) -> Vector3:
	return Dynamics.acceleration(self, at)


func orbit_status(focus_id := -1) -> Dictionary:
	var star := Catalog.star_for(system_id)
	var focus := _orbit_focus(focus_id)
	var site := Catalog.site(focus)
	var mu := Dynamics.gravity_parameter(focus) if Catalog.system_of_site(focus) == system_id else 0.0
	var center := target_position(focus) if mu > 0.0 else Vector3.ZERO
	var relative_velocity := velocity - target_velocity(focus) if mu > 0.0 else Vector3.ZERO
	var radial := position - center
	var result := Navigation.elements(position, relative_velocity, center, mu)
	var normal := _orbit_normal if orbit_maneuver else Navigation.orbit_normal(radial, relative_velocity, forward())
	var delta_v := relative_velocity.distance_to(Navigation.circular_velocity(radial, normal, mu))
	var band := _orbit_band(focus, center) if mu > 0.0 else Vector2.ZERO
	var reason := "Выберите звезду, планету или луну этой системы"
	if mu > 0.0:
		reason = _orbit_block_reason(focus, radial.length(), relative_velocity.length(), band, not orbit_maneuver)
	if reason.is_empty() and not orbit_maneuver and delta_v <= _orbit_speed_tolerance(focus, float(result.circular_speed)):
		reason = "Скорость уже близка к круговой"
	var measurable: bool = result.valid and docked < 0 and not landed and jump_seconds_left <= 0.0
	var surface_radius := float(site.get("radius", 0.0))
	result.merge({
		"star": star, "focus": focus, "focus_kind": site.get("kind", ""),
		"name": str(site.get("name", "")), "classification": (
			("bound" if result.bound else "escape") if measurable else "unavailable"
		),
		"altitude": maxf(0.0, float(result.radius) - surface_radius),
		"relative_speed": relative_velocity.length(),
		"collision_radius": Catalog.STAR_CLEARANCE if focus == star else surface_radius * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE,
		"approach_min": band.x, "approach_max": band.y,
		"allowed": reason.is_empty() and not orbit_maneuver,
		"reason": "Можно выполнить орбитальный манёвр" if reason.is_empty() else reason,
		"maneuver": orbit_maneuver, "maneuver_phase": _orbit_phase, "delta_v": delta_v,
	})
	return result


func orbit_forecast(focus_id := -1) -> Dictionary:
	return Navigation.forecast(self, 180.0, _orbit_focus(focus_id))


func start_orbit_maneuver(focus_id := -1) -> bool:
	if orbit_maneuver:
		return false
	var status := orbit_status(focus_id)
	if not status.allowed:
		return false
	var focus: int = status.focus
	_orbit_normal = Navigation.orbit_normal(position - target_position(focus), velocity - target_velocity(focus), forward())
	reset_time_scale()
	set_autopilot(false)
	flight_assist = false
	throttle = 0.0
	boost = false
	orbit_maneuver = true
	orbit_maneuver_focus = focus
	_orbit_seconds = 0.0
	_orbit_phase = "turn"
	_announce("orbit_start", "Выход на круговую орбиту. Ориентир — «%s»." % status.name)
	return true


func cancel_orbit_maneuver() -> bool:
	if not orbit_maneuver:
		return false
	_clear_orbit_maneuver()
	_announce("orbit_cancel", "Манёвр отменён. Корабль продолжает полёт по инерции.")
	return true


func _clear_orbit_maneuver() -> void:
	if orbit_maneuver:
		orbit_maneuver = false
		orbit_maneuver_focus = -1
		_orbit_phase = ""
		throttle = 0.0


func _orbit_focus(requested: int) -> int:
	if orbit_maneuver:
		return orbit_maneuver_focus
	return Catalog.star_for(system_id) if requested == -1 else requested


func _orbit_band(focus: int, center: Vector3) -> Vector2:
	var star := Catalog.star_for(system_id)
	if focus == star:
		return Vector2(ORBIT_MIN_RADIUS, ORBIT_MAX_RADIUS)
	return Navigation.orbit_band(focus, center, target_position(star))


func _orbit_speed_tolerance(focus: int, circular_speed: float) -> float:
	if focus == Catalog.star_for(system_id):
		return ORBIT_SPEED_TOLERANCE
	return clampf(circular_speed * 0.025, 0.015, ORBIT_SPEED_TOLERANCE)


func _orbit_block_reason(focus: int, radius: float, relative_speed: float, band: Vector2, starting: bool) -> String:
	if docked >= 0 or landed or jump_seconds_left > 0.0:
		return "Выйдите в открытый космос"
	if patrol.in_danger(self) or convoy_order.in_danger(self):
		return "Отойдите от боевого контакта"
	if band.x >= band.y:
		return "Для круговой орбиты вокруг этого тела сейчас нет безопасного диапазона"
	if radius < band.x or radius > band.y:
		return "Держитесь в пределах %d–%d м от центра «%s»" % [ceili(band.x), floori(band.y), target_name(focus)]
	if starting and relative_speed > ORBIT_MAX_SPEED:
		return "Снизьте скорость относительно цели до %d м/с" % int(ORBIT_MAX_SPEED)
	if ship.fuel <= 0.0 or (starting and ship.fuel < ORBIT_MIN_FUEL):
		return "Для манёвра нужно не менее %d ед. топлива" % int(ORBIT_MIN_FUEL)
	if ship.hull <= ShipSystems.MIN_HULL or star_heat >= HEAT_SCOOP_LIMIT:
		return "Манёвр требует исправного и остывшего корпуса"
	var star := Catalog.star_for(system_id)
	for id: int in local_targets():
		var clearance := Catalog.SCOOP_OUTER + 50.0 if id == star else float(Catalog.site(id).radius) + ORBIT_CLEARANCE
		if id != focus and position.distance_to(target_position(id)) <= clearance:
			return "Отойдите от объекта «%s»" % target_name(id)
	return ""


func offer_destination() -> int:
	if docked < 0:
		return -1
	if not Catalog.contract(docked, planned_target).is_empty():
		return planned_target
	var local := _default_port(docked)
	return local if not Catalog.contract(docked, local).is_empty() else Catalog.first_contract_destination(docked)


func _default_port(excluded := -1) -> int:
	var ports := local_ports()
	for id: int in ports:
		if id != excluded:
			return id
	if not ports.is_empty():
		return ports[0]
	var surfaces := Catalog.mines_for(system_id)
	for id: int in surfaces:
		if id != excluded:
			return id
	return surfaces[0]


func contract_cargo() -> String:
	var offer := _current_contract()
	return "" if offer.is_empty() else str(offer[0])


func contract_reward() -> int:
	var offer := _current_contract()
	return 0 if offer.is_empty() else int(offer[1])


func _current_contract() -> Array:
	if contract_stage == 1:
		if not contract_route_id.is_empty():
			var route := Economy.courier(contract_route_id)
			return [route.cargo, route.reward]
		return Catalog.contract(contract_origin, contract_destination)
	return Catalog.contract(docked, offer_destination())


func courier_offer() -> Dictionary:
	return Economy.courier_at(docked)


func contract_itinerary() -> Dictionary:
	if contract_route_id.is_empty():
		return {}
	var route := Economy.courier(contract_route_id)
	route.leg = contract_leg
	route.completed = contract_stage == 2
	return route


func accept_courier(route_id: String) -> bool:
	var offer := courier_offer()
	if offer.is_empty() or offer.id != route_id or contract_stage == 1:
		return false
	contract_origin = docked
	contract_stage = 1
	contract_route_id = route_id
	contract_leg = 0
	contract_destination = offer.stops[0]
	_plan_contract_leg()
	_announce("contract", "Курьерский рейс. Первая остановка «%s»." % target_name(contract_destination))
	return true


func _plan_contract_leg() -> void:
	var destination_system := Catalog.system_of_site(contract_destination)
	if destination_system == system_id:
		target = contract_destination
		planned_target = contract_destination
	else:
		planned_target = -1
		jump_target = destination_system


func contract_action() -> bool:
	if docked < 0:
		return false
	if contract_stage == 1:
		if docked != contract_destination:
			return false
		if not contract_route_id.is_empty():
			var stops: Array = Economy.courier(contract_route_id).stops
			if contract_leg + 1 < stops.size():
				contract_leg += 1
				contract_destination = stops[contract_leg]
				_plan_contract_leg()
				_announce("contract_leg", "Этап принят. Следующая остановка «%s»." % target_name(contract_destination))
				return true
		var reward := contract_reward()
		credits += reward
		deliveries += 1
		contract_stage = 2
		_announce("delivery", "Груз принят. Начислено %d кр." % reward)
	else:
		contract_stage = 1
		contract_route_id = ""
		contract_leg = -1
		contract_origin = docked
		contract_destination = offer_destination()
		if Catalog.system_of_site(contract_destination) == system_id:
			target = contract_destination
		else:
			_plan_contract_leg()
		_announce("contract", "Груз на борту. Пункт назначения — %s." % target_name(contract_destination))
	return true


func change_target() -> void:
	if docked < 0 and not landed:
		var options := local_targets()
		select_target(options[(options.find(target) + 1) % options.size()])


func select_target(index: int) -> bool:
	if jump_seconds_left > 0.0 or Catalog.system_of_site(index) != system_id or index == docked or index == landed_site or not _site_available(index, expedition):
		return false
	if docked >= 0 or landed:
		planned_target = index
	else:
		_stop_convoy_course()
		_clear_orbit_maneuver()
		target = index
		_approach_committed = false
		if autopilot:
			set_autopilot(true)
	return true


func change_throttle(amount: float) -> void:
	if docked < 0 and not landed:
		reset_time_scale()
		cancel_jump()
		set_autopilot(false)
		throttle = clampf(throttle + amount, 0.0, 1.0)


func set_autopilot(enabled: bool) -> void:
	patrol_course = false
	project_course = false
	_stop_convoy_course()
	_clear_orbit_maneuver()
	autopilot = enabled and docked < 0 and not landed and jump_seconds_left <= 0.0
	_approach_committed = false
	_departure_leg = 0
	_departure_axis = Vector3.ZERO
	autopilot_phase = "К створу" if autopilot else ""
	if not autopilot:
		return
	for index: int in local_targets():
		if index == Catalog.star_for(system_id):
			continue
		var center := target_position(index)
		var offset := position - center
		var near_distance := float(Catalog.site(index).radius) + 48.0
		if index != target and Catalog.is_mine_site(index) and offset.length_squared() < near_distance * near_distance and offset.normalized().dot(Vector3.BACK) < 0.96:
			_departure_site = index
			_departure_axis = offset.normalized()
			_departure_leg = 1
			break
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
	if Catalog.is_mine_site(target):
		return surface_status()
	var relative := position - docking_position(target)
	if relative.length() > 7.0 or relative.z < -0.8 or Vector2(relative.x, relative.y).length() > 3.1:
		return {"ok": false, "reason": "Подойдите к центру стыковочного кольца"}
	if speed_relative_to(target) > DOCK_SPEED:
		return {"ok": false, "reason": "Снизьте скорость относительно станции до 5 м/с"}
	if forward().dot(Vector3.FORWARD) < cos(DOCK_AIM_ERROR):
		return {"ok": false, "reason": "Направьте нос в створ"}
	if absf(roll_error(target)) > DOCK_ROLL_ERROR:
		return {"ok": false, "reason": "Совместите крен с кольцом"}
	return {"ok": true, "reason": "Можно швартоваться"}


func surface_status() -> Dictionary:
	var status := {"ok": false, "near": false, "reason": "Подойдите к твёрдой поверхности", "altitude": 0.0, "slope": 0.0, "pad": false, "direction": Vector3.ZERO}
	if docked >= 0 or landed or not Catalog.is_mine_site(target):
		return status
	var relative := position - target_position(target)
	var distance := relative.length()
	if distance < 0.01 or distance > float(Catalog.site(target).radius) + FRAME_MARGIN:
		return status
	var pad_height := relative.z - float(Catalog.site(target).pad_offset)
	var over_pad := relative.z > 0.0 and Vector2(relative.x, relative.y).length() <= LANDING_RADIUS
	var direction := Vector3.BACK if over_pad else relative / distance
	var normal := Terrain.normal(target, direction)
	var altitude := pad_height + Terrain.CONTACT_CLEARANCE if over_pad else distance - Terrain.radius_at(target, direction)
	status.near = true
	status.altitude = altitude
	status.slope = rad_to_deg(acos(clampf(normal.dot(direction), -1.0, 1.0)))
	status.pad = over_pad
	status.direction = direction
	if jump_seconds_left > 0.0:
		status.reason = "Идёт зарядка прыжкового привода"
	elif autopilot and _approach_committed and not over_pad:
		status.reason = "Подойдите к отмеченной площадке"
	elif altitude < Terrain.CONTACT_CLEARANCE - 0.1 or altitude > (11.0 if over_pad else FREE_LANDING_MAX_HEIGHT):
		status.reason = "Подойдите к площадке" if over_pad else "Снизьтесь до 4–10 м над поверхностью"
	elif speed_relative_to(target) > LANDING_SPEED:
		status.reason = "Снизьте скорость относительно поверхности до 4 м/с"
	elif not over_pad and not Terrain.landable(target, direction):
		status.reason = "Выберите участок с меньшим уклоном"
	elif forward().dot(-normal) < cos(deg_to_rad(12.0 if over_pad else LANDING_ANGLE)):
		status.reason = "Направьте нос к площадке" if over_pad else "Направьте нос к поверхности"
	else:
		status.ok = true
		status.reason = "Можно садиться"
	return status


func landed_offpad() -> bool:
	return landed and not landing_direction.is_equal_approx(Vector3.BACK)


func landed_basis() -> Basis:
	return Terrain.basis(landed_site, landing_direction) if landed else Basis.IDENTITY


func surface_deposit() -> Transform3D:
	if not landed:
		return Transform3D(Basis.IDENTITY, position)
	var deposit := Terrain.deposit(landed_site, landing_direction)
	deposit.origin += target_position(landed_site)
	return deposit


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
		_arrive(status.get("direction", Vector3.BACK))
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
	var cargo_before := {}
	for good: String in Catalog.RESOURCES:
		cargo_before[good] = mining.cargo_amount(good)
	var earned := mining.sell(docked)
	if earned == 0:
		return false
	for good: String in Catalog.RESOURCES:
		var sold: int = cargo_before[good] - mining.cargo_amount(good)
		if sold > 0:
			market.change_stock(docked, good, sold)
	credits += earned
	_announce("ore_sold", "Сырьё продано. Начислено %d кр." % earned)
	return true


func market_quote(good: String, side: String, quantity: int) -> Dictionary:
	var unit := Economy.price(docked, good, side)
	var stock := market.stock(docked, good)
	var owned := mining.cargo_amount(good)
	var cost := unit * quantity if quantity > 0 and quantity <= ship.cargo_capacity() else 0
	var reason := ""
	if docked < 0:
		reason = "Рынок доступен после швартовки"
	elif unit <= 0 or cost <= 0:
		reason = "Выберите товар и количество"
	elif side == "buy":
		if stock < quantity:
			reason = "В порту недостаточно товара"
		elif mining.free_capacity() < quantity:
			reason = "В трюме мало места"
		elif credits < cost:
			reason = "Недостаточно кредитов"
	elif owned < quantity:
		reason = "В трюме недостаточно товара"
	return {"ok": reason.is_empty(), "cost": cost, "unit": unit, "stock": stock, "owned": owned, "reason": reason}


func market_trade(good: String, side: String, quantity: int) -> bool:
	var quote := market_quote(good, side, quantity)
	if not quote.ok:
		return false
	if side == "buy":
		if not mining.insert_cargo(good, quantity):
			return false
		if not market.change_stock(docked, good, -quantity):
			mining.remove_cargo(good, quantity)
			return false
		credits -= quote.cost
		_announce("market_buy", "Куплено %d ед. товара «%s» за %d кр." % [quantity, Economy.good_name(good), quote.cost])
	else:
		if not mining.remove_cargo(good, quantity):
			return false
		market.change_stock(docked, good, quantity)
		credits += quote.cost
		_announce("market_sell", "Продано %d ед. товара «%s» за %d кр." % [quantity, Economy.good_name(good), quote.cost])
	return true


func refuel_unit_price() -> int:
	return Catalog.refuel_price(docked)


func repair_unit_price() -> int:
	return Economy.repair_price(docked)


func traffic_contacts() -> Array[Dictionary]:
	var contacts := Traffic.contacts(self)
	contacts.append_array(patrol.contacts(self))
	var order := convoy_order.status(self)
	if order.active and order.local and order.kind == "intercept":
		for contact in contacts:
			if contact.id == order.id:
				contact.hull = order.enemy_hull
				break
	return contacts


func combat_beams() -> Array[Dictionary]:
	if docked >= 0 or landed or jump_seconds_left > 0.0:
		return []
	var beams := patrol.beams()
	beams.append_array(convoy_order.beams())
	return beams


func patrol_status() -> Dictionary:
	return patrol.status(self)


func frontier_status() -> Dictionary:
	return expedition.status(self)


func convoy_offers() -> Array[Dictionary]:
	return convoy_order.offers(self)


func convoy_status() -> Dictionary:
	var status := convoy_order.status(self)
	var patrol_engaged := patrol.in_danger(self)
	status.escort_time = status.formation_time
	status.escort_total = status.formation_required
	status.fire_visible = status.fire_visible and not patrol_engaged
	if status.local and patrol_engaged:
		status.can_route = false
		if status.active:
			status.reason = "Сначала выйдите из боевого контакта «Дозора»."
	return status


func convoy_action(system := -1, id := "") -> bool:
	if jump_seconds_left > 0.0:
		return false
	if not id.is_empty():
		var accepted := convoy_order.accept(self, system, id)
		if accepted.is_empty():
			return false
		_stop_convoy_course()
		if system != system_id:
			plan_jump(system)
		_apply_convoy_result(accepted)
		return true
	if convoy_course:
		_stop_convoy_course()
		_announce("convoy_order_course", "Сближение с конвоем отменено.")
		return true
	var status := convoy_status()
	if not status.can_route:
		return false
	if not status.local:
		return plan_jump(status.system)
	reset_time_scale()
	set_autopilot(false)
	convoy_course = true
	_announce("convoy_order_course", "Проложен курс к конвою. «%s»." % status.name)
	return true


func _stop_convoy_course() -> void:
	if convoy_course:
		convoy_course = false
		throttle = 0.0


func project_action() -> bool:
	var status := frontier_status()
	if not status.can_act:
		if status.route_system >= 0 and status.route_system != system_id:
			return plan_jump(status.route_system)
		if status.route_port >= 0 and select_target(status.route_port):
			if docked < 0 and not landed:
				set_autopilot(true)
			_announce("expedition_course", "Курс к порту заказчика.")
			return true
		if not status.can_follow:
			return false
		set_autopilot(false)
		project_course = true
		_announce("expedition_course", "Курс к цели экспедиции.")
		return true
	var result := expedition.act(self)
	if not result.get("ok", false):
		return false
	project_course = false
	credits += int(result.get("credits", 0))
	if result.has("commissioned"):
		factions.commission(result.commissioned, result.owner, orbit_time)
	if result.has("planned_system"):
		plan_jump(result.planned_system)
	_announce(result.event, result.message)
	return true


func fire_status() -> Dictionary:
	return convoy_order.fire_status(self) if convoy_status().fire_visible else patrol.fire_status(self)


func patrol_action() -> bool:
	var status := patrol_status()
	if not status.available:
		return false
	if docked >= 0:
		if patrol.phase == Patrol.RETURN:
			var payment := patrol.finish(docked)
			if payment <= 0:
				return false
			credits += payment
			_announce("patrol_paid", "Доклад принят. Награда %d кр." % payment)
		else:
			if not patrol.accept(docked):
				return false
			_announce("patrol_accepted", "Дозор принят. После старта выберите «К сигналу».")
	elif patrol.phase == Patrol.RETURN:
		select_target(patrol.origin)
		set_autopilot(true)
	else:
		var follow := not patrol_course
		set_autopilot(false)
		patrol_course = follow
		if not follow:
			throttle = 0.0
	return true


func fire_action() -> bool:
	if convoy_status().fire_visible:
		var result := convoy_order.fire(self)
		_apply_convoy_result(result)
		return result.get("ok", false)
	var shot := patrol.fire(self)
	_apply_patrol_result(shot)
	return shot.get("ok", false)


func _apply_patrol_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	var event: String = result.get("event", "")
	if event.is_empty():
		return
	if event in ["patrol_engaged", "patrol_victory", "patrol_retreat"]:
		reset_time_scale()
		if event == "patrol_engaged":
			_stop_convoy_course()
		if patrol_course:
			patrol_course = false
			throttle = 0.0
	if result.get("damage", 0.0) > 0.0:
		ship.apply_damage(float(result.damage))
	_announce(event, str(result.get("message", "")))


func _apply_convoy_result(result: Dictionary) -> void:
	var event: String = result.get("event", "")
	if event.is_empty():
		return
	if event in ["convoy_order_escorted", "convoy_order_paid", "convoy_order_failed"]:
		_stop_convoy_course()
	if result.has("damage"):
		ship.apply_damage(float(result.damage))
	credits += int(result.get("credits", 0))
	_announce(event, str(result.get("message", "")))


func combat_line_clear(start: Vector3, finish: Vector3) -> bool:
	var steps := maxi(1, ceili(start.distance_to(finish) / 8.0))
	for step in range(1, steps + 1):
		if _blocked(start.lerp(finish, float(step) / steps)):
			return false
	return true


func service_offer(action: String) -> Dictionary:
	var unit_price := repair_unit_price() if action == "repair" else refuel_unit_price()
	var offer := ship.service_offer(action, unit_price, credits)
	offer.allowed = offer.allowed and Catalog.is_port(docked)
	return offer


func service_action(action: String) -> bool:
	if not service_offer(action).allowed:
		return false
	var unit_price := repair_unit_price() if action == "repair" else refuel_unit_price()
	var paid := ship.buy(action, unit_price, credits)
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
		"repair":
			_announce("service_repair", "Корпус отремонтирован. Списано %d кр." % paid)
		"cargo":
			mining.cargo_capacity = ship.cargo_capacity()
			_announce("service_cargo", "Вместимость трюма увеличена до %d ед." % mining.cargo_capacity)
	return true


func scoop_status() -> Dictionary:
	var distance := _star_distance()
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
	elif star_heat >= HEAT_SCOOP_LIMIT:
		reason = "Корпус перегрет. Отойдите от звезды, чтобы остыть"
	elif speed() > Catalog.SCOOP_SPEED:
		reason = "Снизьте скорость до %d м/с" % int(Catalog.SCOOP_SPEED)
	elif ship.fuel >= ship.capacity():
		reason = "Бак уже полон"
	return {"ok": reason.is_empty(), "reason": "Можно собирать топливо" if reason.is_empty() else reason, "near": near}


func thermal_status() -> Dictionary:
	var distance := _star_distance()
	var in_flight := docked < 0 and not landed
	var level := "normal"
	if star_heat >= HEAT_DAMAGE_LIMIT:
		level = "critical"
	elif star_heat >= 65.0:
		level = "hot"
	elif star_heat >= 35.0:
		level = "warm"
	return {
		"heat": star_heat, "distance": distance, "level": level,
		"visible": in_flight and (distance <= Catalog.SCOOP_OUTER or star_heat >= 1.0),
		"danger": in_flight and distance < Catalog.SCOOP_INNER,
		"blocked": star_heat >= HEAT_SCOOP_LIMIT,
		"cooling": star_heat - _heat_target(distance) > 0.1,
	}


func _star_distance() -> float:
	return position.distance_to(target_position(Catalog.star_for(system_id)))


func _heat_target(distance: float) -> float:
	# Approach heat rises more quickly near the stellar surface. Running the collector adds heat.
	var proximity := maxf(0.0, Catalog.SCOOP_OUTER - distance) / (Catalog.SCOOP_OUTER - Catalog.SCOOP_INNER)
	var output := Catalog.stellar_heat(system_id)
	return 82.0 * output * proximity * proximity + (12.0 if scooping else 0.0)


func _update_star_heat(delta: float) -> void:
	var exposed := docked < 0 and not landed and jump_seconds_left <= 0.0
	var equilibrium := _heat_target(_star_distance()) if exposed else 0.0
	if star_heat == 0.0 and equilibrium == 0.0:
		return
	var previous := star_heat
	var response := 0.17 if equilibrium > star_heat else 0.28
	star_heat = clampf(lerpf(star_heat, equilibrium, 1.0 - exp(-response * delta)), 0.0, 100.0)
	if star_heat < 0.05:
		star_heat = 0.0
	if exposed and star_heat >= HEAT_DAMAGE_LIMIT:
		var severity := inverse_lerp(HEAT_DAMAGE_LIMIT, 100.0, star_heat)
		ship.apply_damage(lerpf(0.7, 6.0, severity) * delta)
		if previous < HEAT_DAMAGE_LIMIT:
			_announce("thermal_damage", "Критический перегрев. Отойдите от звезды, корпус повреждается.")


func scoop_action() -> bool:
	if scooping:
		scooping = false
		_announce("scoop_stop", "Сбор топлива остановлен.")
		return true
	var status := scoop_status()
	if not status.ok:
		_announce("scoop_denied", status.reason)
		return false
	reset_time_scale()
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
	var heat_fraction := clampf(inverse_lerp(HEAT_SCOOP_SLOW, HEAT_SCOOP_LIMIT, star_heat), 0.0, 1.0)
	ship.add_fuel(SCOOP_RATE * lerpf(1.0, 0.45, heat_fraction) * delta)
	if ship.fuel >= ship.capacity():
		scooping = false
		_announce("scoop_full", "Бак полностью заправлен от звезды.")


func plan_jump(destination: int) -> bool:
	if jump_seconds_left > 0.0 or not system_known(destination) or Catalog.jump_cost(system_id, destination) == 0:
		return false
	jump_target = destination
	_announce("jump_planned", "Межзвёздный курс. «%s»." % Catalog.system(destination).name)
	return true


func jump_status(destination: int) -> Dictionary:
	var cost := Catalog.jump_cost(system_id, destination) if system_known(destination) else 0
	var reason := ""
	if cost == 0:
		reason = "Выберите другую звёздную систему"
	elif docked >= 0 or landed:
		reason = "Выйдите в открытый космос"
	elif autopilot or scooping:
		reason = "Отключите автопилот и сбор топлива"
	elif patrol.in_danger(self):
		reason = "Выйдите из зоны боя"
	elif convoy_order.in_danger(self):
		reason = "Отойдите от конвоя"
	elif speed() > JUMP_SPEED:
		reason = "Снизьте скорость до %d м/с" % int(JUMP_SPEED)
	elif ship.fuel < cost:
		reason = "Нужно %d ед. топлива" % cost
	else:
		var star := Catalog.star_for(system_id)
		for id: int in local_targets():
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
	reset_time_scale()
	patrol_course = false
	project_course = false
	_stop_convoy_course()
	_clear_orbit_maneuver()
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
	var arrival: int = Catalog.system(system_id).arrival_port
	if not station_operational(arrival):
		arrival = Catalog.system(system_id).survey_sites[0]
	target = arrival
	if contract_stage == 1 and Catalog.system_of_site(contract_destination) == system_id and _site_available(contract_destination, expedition) and (not contract_route_id.is_empty() or contract_origin >= Catalog.PRE_EXPANSION_DESTINATION_COUNT):
		target = contract_destination
	position = target_gate(arrival) + Vector3.BACK * ARRIVAL_OFFSET
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	_announce("jump_complete", "Прыжок завершён. Система «%s»." % Catalog.system(system_id).name)


func _arrive(direction := Vector3.BACK) -> void:
	if Catalog.is_mine_site(target):
		mining.select_site(target)
		landed_site = target
		landing_direction = direction.normalized()
		set_autopilot(false)
		_hold_landed_pose()
		var location := "Вне площадки" if landed_offpad() else "Площадка"
		_announce("land", "Посадка завершена. %s на «%s»." % [location, target_name(landed_site)])
	else:
		_dock()


func _hold_landed_pose() -> void:
	position = target_position(landed_site) + Terrain.contact(landed_site, landing_direction)
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	throttle = 0.0
	boost = false
	scooping = false


func _lift() -> void:
	var origin := landed_site
	var away := Terrain.normal(origin, landing_direction)
	var offpad := landed_offpad()
	reset_time_scale()
	landed_site = -1
	landing_direction = Vector3.ZERO
	yaw = atan2(-away.x, -away.z) if offpad else PI
	pitch = clampf(asin(clampf(away.y, -1.0, 1.0)), -MAX_PITCH, MAX_PITCH)
	if offpad:
		position += away * 0.35
	velocity = target_velocity(origin) + away * 9.0
	target = _departure_target(_default_port(origin))
	_announce("lift", "Взлёт с поверхности. «%s»." % target_name(origin))


func _launch() -> void:
	var origin := docked
	reset_time_scale()
	position = docking_position(origin) + station_axis(origin) * 15.0
	yaw = PI
	pitch = 0.0
	throttle = 0.0
	velocity = target_velocity(origin) + station_axis(origin) * 6.0
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


func update(delta: float, steer: Vector2, bank: float, boost_requested: bool, brake: bool, translation := Vector3.ZERO) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var traverse := translation.limit_length() if translation.is_finite() else Vector3.ZERO
	var manual_input := steer.length_squared() > 0.04 or absf(bank) > 0.12 or boost_requested or brake or not traverse.is_zero_approx()
	if manual_input or (time_scale > 1 and not time_status().allowed):
		reset_time_scale()
	if docked >= 0 or landed:
		_step(delta * time_scale, steer, bank, boost_requested, brake, manual_input, traverse)
		return
	var steps := maxi(1, ceili(delta * time_scale / MAX_FLIGHT_STEP - 0.000001))
	var interval := delta / steps
	for step in range(steps):
		if time_scale > 1 and not time_status().allowed:
			reset_time_scale()
		_step(interval * time_scale, steer, bank, boost_requested, brake, manual_input, traverse)


func _step(delta: float, steer: Vector2, bank: float, boost_requested: bool, brake: bool, manual_input: bool, translation: Vector3) -> void:
	var previous_orbit_time := orbit_time
	orbit_time += delta
	elapsed += delta
	var front := factions.advance(orbit_time)
	if not front.is_empty():
		_announce(front.event, front.message)
	if docked >= 0:
		_hold_docked_pose()
		_update_star_heat(delta)
		_apply_patrol_result(patrol.step(self, delta))
		_apply_convoy_result(convoy_order.step(self, delta))
		return
	if landed:
		_hold_landed_pose()
		_update_star_heat(delta)
		_apply_patrol_result(patrol.step(self, delta))
		var mining_event := mining.update(delta)
		match mining_event:
			"mining_ready":
				_announce(mining_event, "Добыто %d ед. сырья. Заберите модуль." % mining.pending_ore)
			"mining_loaded":
				_announce(mining_event, "Модуль на борту. Сырьё в трюме. Можно взлетать.")
		_apply_convoy_result(convoy_order.step(self, delta))
		return

	if jump_seconds_left > 0.0:
		if manual_input:
			cancel_jump()
		else:
			_charge_jump(delta)
		_update_star_heat(delta)
		_apply_convoy_result(convoy_order.step(self, delta))
		return
	if manual_input:
		if autopilot or patrol_course or project_course or convoy_course or orbit_maneuver:
			set_autopilot(false)
			_announce("manual_override", "Ручное управление")

	var had_fuel := ship.fuel > 0.0
	var manual_load := 0.0
	if autopilot:
		_autopilot_step(delta)
	elif orbit_maneuver:
		_orbit_maneuver_step(delta)
	elif convoy_course:
		_convoy_course_step(delta)
	elif project_course:
		_project_course_step(delta)
	elif patrol_course:
		_patrol_course_step(delta)
	else:
		manual_load = _manual_step(delta, steer, bank, boost_requested, brake, translation)

	ship.burn(delta, maxf(throttle, manual_load), boost)
	if had_fuel and ship.fuel <= 0.0:
		_announce("fuel_empty", "Бак пуст. Включён резервный ход до 42 м/с.")

	if docked >= 0 or landed:
		_apply_convoy_result(convoy_order.step(self, delta))
		return
	var next := position + velocity * delta
	var obstacle := _obstacle_at(next)
	if obstacle < 0:
		position = next
	else:
		reset_time_scale()
		var impact_speed := speed_relative_to(obstacle)
		var damage := ship.apply_damage(clampf((impact_speed - IMPACT_DAMAGE_SPEED) * 0.32, 0.0, 45.0))
		if damage > 0.0:
			_announce("hull_damage", "Корпус повреждён. Прочность %.0f%%." % ship.hull)
		elif velocity.length_squared() > 0.05:
			_announce("clearance", "Защитное торможение у препятствия")
		var caught_by_motion := _inside_hull(position, obstacle)
		if caught_by_motion:
			var previous_center: Vector3 = Orbit.sample(obstacle, previous_orbit_time).position
			position += target_position(obstacle) - previous_center
		velocity = target_velocity(obstacle) if caught_by_motion else Vector3.ZERO
		throttle = 0.0
		set_autopilot(false)
	_update_star_heat(delta)
	_collect_fuel(delta)
	_apply_patrol_result(patrol.step(self, delta))
	_apply_convoy_result(convoy_order.step(self, delta))


func _orbit_maneuver_step(delta: float) -> void:
	var focus := orbit_maneuver_focus
	var center := target_position(focus)
	var radial := position - center
	var drift := target_velocity(focus)
	velocity += gravity_at(position) * delta
	throttle = 0.0
	_orbit_seconds += delta
	var stop_reason := _orbit_block_reason(focus, radial.length(), velocity.distance_to(drift), _orbit_band(focus, center), false)
	if stop_reason.is_empty() and _orbit_seconds >= ORBIT_TIMEOUT:
		stop_reason = "Не удалось выровнять скорость"
	if not stop_reason.is_empty():
		_clear_orbit_maneuver()
		_announce("orbit_abort", "Манёвр прерван. %s." % stop_reason)
		return
	var circular := Navigation.circular_velocity(radial, _orbit_normal, Dynamics.gravity_parameter(focus))
	var desired := drift + circular
	var correction := desired - velocity
	var remaining := correction.length()
	if remaining <= _orbit_speed_tolerance(focus, circular.length()):
		_clear_orbit_maneuver()
		_announce("orbit_complete", "Импульс завершён. Корабль движется по инерции.")
		return
	var aim := correction / remaining
	_turn_nose_toward(aim, delta)
	_orbit_phase = "turn"
	if forward().dot(aim) >= ORBIT_ALIGNMENT:
		_orbit_phase = "burn"
		var impulse := minf(remaining, ORBIT_BURN_ACCELERATION * delta)
		velocity += forward() * impulse
		throttle = impulse / (34.0 * delta)


func _turn_nose_toward(direction: Vector3, delta: float) -> void:
	var nose := forward()
	var axis := nose.cross(direction)
	var cosine := clampf(nose.dot(direction), -1.0, 1.0)
	if axis.length_squared() < 0.00000001:
		if cosine > 0.0:
			return
		axis = attitude().y
	var angle := acos(cosine)
	_set_orientation(Quaternion(axis.normalized(), minf(angle, MAX_STEER * delta)) * _flight_orientation())


func _manual_step(delta: float, steer: Vector2, bank: float, boost_requested: bool, brake: bool, translation: Vector3) -> float:
	_rotate_manual(steer, bank, delta)
	var had_fuel := ship.fuel > 0.0
	boost = boost_requested and not brake and had_fuel
	var reference := reference_site()
	var drift := target_velocity(reference) if reference >= 0 else Vector3.ZERO
	if brake:
		throttle = 0.0
		velocity = velocity.move_toward(drift, 67.0 * delta)
		return 0.0
	var thrust := 1.55 if boost else throttle
	var local := Vector3(translation.x, translation.y, -translation.z - thrust)
	var limit := 1.55 if boost else 1.0
	var drive := attitude() * local.limit_length(limit)
	var drive_acceleration := 34.0 if had_fuel else 20.0
	var drive_speed := MAX_SPEED if had_fuel else RESERVE_SPEED
	if flight_assist:
		var desired := drift + drive * drive_speed
		if not had_fuel:
			desired = desired.limit_length(RESERVE_SPEED)
		velocity = velocity.move_toward(desired, drive_acceleration * delta)
	else:
		# Opposing thrust can brake drift without forcing it down to a new engine speed limit.
		var relative := velocity - drift
		var powered_limit := maxf(relative.length(), drive_speed * limit)
		var powered := (relative + drive * drive_acceleration * delta).limit_length(powered_limit)
		velocity = (drift + powered + gravity_at(position) * delta).limit_length(MAX_SAVED_SPEED - 1.0)
	return local.length()


func _blocked(point: Vector3, sector_id := -1, epoch := -1.0, progress: RefCounted = null) -> bool:
	return _obstacle_at(point, sector_id, epoch, progress) >= 0


func _obstacle_at(point: Vector3, sector_id := -1, epoch := -1.0, progress: RefCounted = null) -> int:
	var history := expedition if progress == null else progress
	for index: int in Catalog.targets_for(system_id if sector_id < 0 else sector_id):
		if _site_available(index, history) and _inside_hull(point, index, epoch):
			return index
	return -1


func _inside_hull(point: Vector3, index: int, epoch := -1.0) -> bool:
	var center: Vector3 = target_position(index) if epoch < 0.0 else Orbit.sample(index, epoch).position
	var relative := point - center
	if index == Catalog.star_for(Catalog.system_of_site(index)):
		return relative.length_squared() < Catalog.STAR_CLEARANCE * Catalog.STAR_CLEARANCE
	if Catalog.is_mine_site(index):
		var outer := float(Catalog.site(index).radius) * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE
		var distance_squared := relative.length_squared()
		if distance_squared >= outer * outer:
			return false
		if distance_squared < 0.0001:
			return true
		var radius := Terrain.radius_at(index, relative.normalized()) + Terrain.CONTACT_CLEARANCE - 0.025
		return distance_squared < radius * radius
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
	var drift := target_velocity(target)
	var relative := position - center
	var waypoint := gate
	var max_speed := 118.0
	var aim := Vector3.FORWARD

	if _departure_leg == 0 and not _approach_committed and position.distance_to(gate) < 3.4 and speed_relative_to(target) < 7.0:
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
			drift = target_velocity(_departure_site)
			var departure_radius := float(Catalog.site(_departure_site).radius)
			if _departure_axis == Vector3.ZERO:
				var forward_clearance := departure_radius + 30.0 if not Catalog.is_port(_departure_site) else 53.0
				var exit_point := departure + Vector3.BACK * forward_clearance
				var side := 1.0 if center.x >= departure.x else -1.0
				waypoint = exit_point if _departure_leg == 1 else exit_point + Vector3(side * maxf(83, departure_radius + 42.0), 0, 0)
			else:
				waypoint = departure + _departure_axis * (departure_radius * Terrain.MAX_RADIUS_FACTOR + 48.0)
			autopilot_phase = "Выход из зоны объекта"
			max_speed = 36.0
			if position.distance_to(waypoint) < 4.0 and speed_relative_to(_departure_site) < 8.0:
				_departure_leg = 2 if _departure_leg == 1 and _departure_axis == Vector3.ZERO else 0
		elif not star_run:
			var detour := _star_detour(waypoint)
			if detour != waypoint:
				waypoint = detour
				drift = Vector3.ZERO
				autopilot_phase = "Обход звезды"
				max_speed = 64.0
	var displacement := waypoint - position
	var direction := displacement
	if waypoint == gate and not star_run and _departure_leg == 0 and displacement.length_squared() > 62500.0:
		var forecast: Vector3 = Orbit.sample(target, orbit_time + intercept_time(target)).position
		direction += forecast - center
		drift = Vector3.ZERO
		autopilot_phase = "Перехват движущейся цели"
	if not _approach_committed and _departure_leg == 0:
		var obstacle := _transit_obstacle(direction, max_speed)
		if obstacle >= 0:
			displacement = _transit_waypoint(obstacle, direction) - position
			direction = displacement
			drift = target_velocity(obstacle)
			max_speed = minf(max_speed, 58.0)
			autopilot_phase = "Обход препятствия"
	if not _approach_committed and direction.length_squared() > 0.25:
		aim = direction.normalized()

	_point_towards(aim, delta)
	if ship.fuel <= 0.0:
		max_speed = minf(max_speed, RESERVE_SPEED)
	var desired_speed := minf(max_speed, minf(sqrt(42.0 * displacement.length()), displacement.length() * 1.6))
	var desired := drift + direction.normalized() * desired_speed
	if ship.fuel <= 0.0:
		desired = desired.limit_length(RESERVE_SPEED)
	velocity = velocity.move_toward(desired, 42.0 * delta)
	throttle = clampf(desired_speed / MAX_SPEED, 0.0, 1.0)
	if _approach_committed and star_run and displacement.length() < 2.0 and speed() < 3.0:
		set_autopilot(false)
		throttle = 0.0
		_announce("star_arrival", "Корабль у звезды «%s». Можно включить сбор топлива." % target_name(target))
	elif _approach_committed and not star_run and selected_dock_status().ok:
		_arrive()


func _patrol_course_step(delta: float) -> void:
	boost = false
	var distance := 0.0
	var waypoint: Vector3 = patrol.status(self).point
	if patrol.phase == Patrol.OUTBOUND:
		waypoint = _star_detour(waypoint)
		var obstacle := _transit_obstacle(waypoint - position, PATROL_CRUISE_SPEED, false)
		if obstacle >= 0:
			waypoint = _transit_waypoint(obstacle, waypoint - position)
		distance = position.distance_to(waypoint)
	var direction := position.direction_to(waypoint)
	if not direction.is_zero_approx():
		_point_towards(direction, delta)
	var cruise := PATROL_CRUISE_SPEED if ship.fuel > 0.0 else RESERVE_SPEED
	var speed_limit := minf(cruise, distance * 0.30)
	velocity = velocity.move_toward(direction * speed_limit, 42.0 * delta)
	throttle = speed_limit / MAX_SPEED


func _project_course_step(delta: float) -> void:
	boost = false
	var status := frontier_status()
	if not status.has_point or (not status.can_follow and not status.ready):
		project_course = false
		throttle = 0.0
		return
	var point: Vector3 = status.point
	var distance := position.distance_to(point)
	var waypoint := _star_detour(point)
	var obstacle := _transit_obstacle(waypoint - position, PATROL_CRUISE_SPEED, false)
	if obstacle >= 0:
		waypoint = _transit_waypoint(obstacle, waypoint - position)
	var direction := position.direction_to(waypoint)
	if not direction.is_zero_approx():
		_point_towards(direction, delta)
	var cruise := PATROL_CRUISE_SPEED if ship.fuel > 0.0 else RESERVE_SPEED
	var speed_limit := minf(cruise, position.distance_to(waypoint) * 0.34)
	var drift := target_velocity(status.site) if waypoint == point else Vector3.ZERO
	velocity = velocity.move_toward((direction * speed_limit + drift).limit_length(cruise), 42.0 * delta)
	throttle = speed_limit / MAX_SPEED
	if status.ready and distance <= 24.0 and velocity.distance_to(drift) < 9.0:
		project_course = false
		throttle = 0.0


func _convoy_course_step(delta: float) -> void:
	boost = false
	var order := convoy_status()
	if not order.can_route or not order.has_point or not order.local:
		_stop_convoy_course()
		return
	var contact: Vector3 = order.point
	var drift: Vector3 = order.point_velocity
	var radial := contact.direction_to(position)
	var escort: bool = order.kind == "escort"
	if escort and drift.length_squared() > 0.25:
		radial = -drift.normalized()
	if radial.is_zero_approx():
		radial = Vector3.BACK
	var spacing := CONVOY_ESCORT_SPACING if escort else CONVOY_AIM_SPACING
	var slot := contact + radial * spacing
	var waypoint := _star_detour(slot)
	var obstacle := _transit_obstacle(waypoint - position, CONVOY_CRUISE_SPEED, false)
	if obstacle >= 0:
		waypoint = _transit_waypoint(obstacle, waypoint - position)
	var detouring := waypoint != slot
	var course := position.direction_to(waypoint)
	var aim := position.direction_to(contact) if not detouring and order.distance <= 350.0 else course
	if not aim.is_zero_approx():
		_point_towards(aim, delta)
	var cruise := CONVOY_CRUISE_SPEED if ship.fuel > 0.0 else RESERVE_SPEED
	var speed_limit := minf(cruise, position.distance_to(waypoint) * 0.56)
	var desired := course * speed_limit
	if not detouring:
		desired += drift
	velocity = velocity.move_toward(desired.limit_length(cruise), 42.0 * delta)
	throttle = speed_limit / MAX_SPEED


func _transit_obstacle(course: Vector3, cruise: float, skip_target := true) -> int:
	var star := Catalog.star_for(system_id)
	var speed_limit := cruise if ship.fuel > 0.0 else minf(cruise, RESERVE_SPEED)
	var duration := course.length() / speed_limit
	var earliest := INF
	var obstacle := -1
	for id: int in local_targets():
		if (skip_target and id == target) or id == star:
			continue
		var radial := position - target_position(id)
		var relative_course := course - target_velocity(id) * duration
		var travel_squared := relative_course.length_squared()
		if travel_squared < 0.001:
			continue
		var fraction := minf(1.0, -radial.dot(relative_course) / travel_squared)
		if fraction <= 0.0 or fraction >= earliest:
			continue
		var closest := radial + relative_course * fraction
		var clearance := float(Catalog.site(id).radius) + 30.0
		if closest.length_squared() < clearance * clearance:
			earliest = fraction
			obstacle = id
	return obstacle


func _transit_waypoint(id: int, course: Vector3) -> Vector3:
	var center := target_position(id)
	var radius := float(Catalog.site(id).radius)
	var outward := (position - center).normalized()
	var side := course.slide(outward)
	if side.length_squared() < 0.001:
		side = Vector3.UP.slide(outward)
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT.slide(outward)
	return center + outward * (radius + 55.0) + side.normalized() * (radius + 58.0)


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
	var facing := _flight_orientation()
	return {
		"schema": SAVE_SCHEMA,
		"position": [position.x, position.y, position.z],
		"velocity": [velocity.x, velocity.y, velocity.z],
		"yaw": yaw, "pitch": pitch, "roll": roll, "elapsed": elapsed,
		"orientation": [facing.x, facing.y, facing.z, facing.w], "flight_assist": flight_assist,
		"orbit_time": orbit_time,
		"throttle": 0.0 if orbit_maneuver else throttle, "docked": docked, "target": target,
		"credits": credits, "deliveries": deliveries,
		"contract_stage": contract_stage, "contract_origin": contract_origin,
		"contract_destination": contract_destination,
		"contract_route_id": contract_route_id, "contract_leg": contract_leg,
		"landed_site": landed_site, "planned_target": planned_target, "mining": mining.snapshot(),
		"landing_direction": [landing_direction.x, landing_direction.y, landing_direction.z],
		"ship": ship.snapshot(), "market": market.snapshot(), "system_id": system_id, "jump_target": jump_target,
		"patrol": patrol.snapshot(), "star_heat": star_heat,
		"expedition": expedition.snapshot(), "factions": factions.snapshot(),
		"convoy_order": convoy_order.snapshot(),
	}


func restore(state: Dictionary) -> bool:
	if not _integer(state.get("schema"), 1, SAVE_SCHEMA):
		return false
	var schema := int(state.schema)
	var pre_navigation := schema < 13
	var pre_convoy_orders := schema < 12
	var pre_thermal := schema < 11
	var pre_expansion := schema < 10
	var pre_traffic := schema < 9
	var pre_economy := schema < 8
	var pre_surface := schema < 7
	var pre_galaxy := schema < 5
	var pre_fuel := schema < 4
	var pre_sector := schema < 3
	if not pre_thermal and not _number(state.get("star_heat"), 0.0, 100.0):
		return false
	if not pre_navigation and not state.get("flight_assist") is bool:
		return false
	var restored_epoch := 0.0
	if schema >= 6:
		if not _number(state.get("orbit_time"), 0.0, 3155760000.0):
			return false
		restored_epoch = float(state.orbit_time)
	var restored_system := Catalog.HOME_SYSTEM
	var restored_jump := -1
	if not pre_galaxy:
		var systems := Catalog.SYSTEM_COUNT
		if pre_expansion:
			systems = Catalog.PRE_TRAFFIC_SYSTEM_COUNT if pre_traffic else Catalog.CORE_SYSTEM_COUNT
		if not _integer(state.get("system_id"), 0, systems - 1) or not _integer(state.get("jump_target"), -1, systems - 1):
			return false
		restored_system = int(state.system_id)
		restored_jump = int(state.jump_target)
		if restored_jump >= 0 and Catalog.jump_cost(restored_system, restored_jump) == 0:
			return false
	for key in ["position", "velocity"]:
		if not state.get(key) is Array or state[key].size() != 3:
			return false
		var limit := 10000000.0 if key == "position" else MAX_SAVED_SPEED
		for item in state[key]:
			if not _number(item, -limit, limit):
				return false
	var pitch_limit := LEGACY_MAX_PITCH if pre_navigation else MAX_PITCH
	if not _number(state.get("yaw"), -PI, PI) or not _number(state.get("pitch"), -pitch_limit, pitch_limit):
		return false
	if not _number(state.get("roll"), -PI, PI) or not _number(state.get("elapsed"), 0.0, 3155760000.0):
		return false
	var restored_angles := Vector3(state.pitch, state.yaw, state.roll)
	var restored_orientation := Quaternion.from_euler(restored_angles)
	if not pre_navigation:
		var encoded: Variant = state.get("orientation")
		if not encoded is Array or encoded.size() != 4:
			return false
		for component in encoded:
			if not _number(component, -1.0, 1.0):
				return false
		var saved := Quaternion(encoded[0], encoded[1], encoded[2], encoded[3])
		if absf(saved.length_squared() - 1.0) > 0.0001:
			return false
		if absf(saved.dot(restored_orientation)) < 0.9999:
			return false
		restored_orientation = saved
	if not _number(state.get("throttle"), 0.0, 1.0):
		return false
	var site_count := Catalog.PRE_EXPANSION_DESTINATION_COUNT if pre_expansion else Catalog.DESTINATION_COUNT
	if pre_traffic:
		site_count = Catalog.PRE_TRAFFIC_DESTINATION_COUNT
	if pre_surface:
		site_count = Catalog.PRE_SURFACE_DESTINATION_COUNT
	if pre_galaxy:
		site_count = schema + 1 if pre_sector else (Catalog.SITE_COUNT if pre_fuel else Catalog.TARGET_COUNT)
	for field in ["docked", "contract_origin", "contract_destination"]:
		if not _integer(state.get(field), -1, site_count - 1):
			return false
		if int(state[field]) >= 0 and not Catalog.is_port(int(state[field])):
			return false
	if not _integer(state.get("target"), 0, site_count - 1) or not _integer(state.get("contract_stage"), 0, 2):
		return false
	var restored_expedition := Expedition.new()
	var restored_factions := FactionFronts.new()
	var restored_convoy_order := ConvoyOrders.new()
	if not pre_expansion:
		if not restored_expedition.restore(state.get("expedition")) or not restored_factions.restore(state.get("factions"), pre_thermal, pre_convoy_orders):
			return false
		for system in range(Catalog.CORE_SYSTEM_COUNT, Catalog.SYSTEM_COUNT):
			if restored_expedition.commissioned(system) != (restored_factions.owner(system) >= 0):
				return false
	if not pre_convoy_orders and not restored_convoy_order.restore(state.get("convoy_order"), restored_factions, restored_expedition):
		return false
	if not restored_expedition.known(restored_system) or (restored_jump >= 0 and not restored_expedition.known(restored_jump)):
		return false
	if not _site_available(int(state.target), restored_expedition):
		return false
	for field in ["docked", "contract_origin", "contract_destination"]:
		if int(state[field]) >= 0 and not _site_available(int(state[field]), restored_expedition):
			return false
	if Catalog.system_of_site(int(state.target)) != restored_system or (int(state.docked) >= 0 and Catalog.system_of_site(int(state.docked)) != restored_system):
		return false
	if not _integer(state.get("credits"), 0, 1000000000) or not _integer(state.get("deliveries"), 0, 10000000):
		return false
	var stage := int(state.contract_stage)
	var origin := int(state.contract_origin)
	var destination := int(state.contract_destination)
	var route_id := ""
	var leg := -1
	if not pre_economy:
		if not state.get("contract_route_id") is String or not _integer(state.get("contract_leg"), -1, 2):
			return false
		route_id = state.contract_route_id
		leg = int(state.contract_leg)
	if stage == 0 and (origin != -1 or destination != -1):
		return false
	if route_id.is_empty():
		if leg != -1 or (stage != 0 and Catalog.contract(origin, destination).is_empty()):
			return false
	else:
		var route := Economy.courier(route_id)
		if stage == 0 or route.is_empty() or route.origin != origin or leg < 0 or leg >= route.stops.size():
			return false
		if route.stops[leg] != destination or (stage == 2 and leg != route.stops.size() - 1):
			return false
	var restored_position := Vector3(state.position[0], state.position[1], state.position[2])
	var restored_velocity := Vector3(state.velocity[0], state.velocity[1], state.velocity[2])
	var restored_dock := int(state.docked)
	var restored_mining := MiningRig.new()
	var restored_ship := ShipSystems.new()
	var restored_market := Economy.new()
	var restored_patrol := Patrol.new()
	var restored_landing := -1
	var restored_plan := -1
	if not pre_fuel and not restored_ship.restore(state.get("ship"), pre_economy):
		return false
	if not pre_economy and not restored_market.restore(state.get("market"), pre_traffic, pre_expansion):
		return false
	if not pre_traffic and not restored_patrol.restore(state.get("patrol")):
		return false
	if restored_patrol.origin >= 0 and not _site_available(restored_patrol.origin, restored_expedition):
		return false
	var mining_count := Catalog.SITE_COUNT if pre_galaxy else site_count
	if schema >= 2 and not restored_mining.restore(state.get("mining"), schema == 2, mining_count, restored_ship.cargo_capacity(), not pre_economy):
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
	var restored_direction := Vector3.ZERO
	if not pre_surface:
		if not state.get("landing_direction") is Array or state.landing_direction.size() != 3:
			return false
		for component in state.landing_direction:
			if not _number(component, -1.0, 1.0):
				return false
		restored_direction = Vector3(state.landing_direction[0], state.landing_direction[1], state.landing_direction[2])
	elif restored_landing >= 0:
		restored_direction = Vector3.BACK
	if restored_landing >= 0:
		if not Catalog.is_mine_site(restored_landing) or restored_dock >= 0 or int(state.target) != restored_landing or restored_mining.site_id != restored_landing:
			return false
		if not restored_direction.is_normalized() or not Terrain.landable(restored_landing, restored_direction):
			return false
		var center: Vector3 = Orbit.sample(restored_landing, restored_epoch).position
		var contact := center + Terrain.contact(restored_landing, restored_direction)
		if not restored_position.is_equal_approx(contact) or not restored_velocity.is_zero_approx():
			return false
	elif restored_mining.phase != MiningRig.STOWED or restored_direction != Vector3.ZERO:
		return false
	if restored_plan >= 0:
		if Catalog.system_of_site(restored_plan) != restored_system or not _site_available(restored_plan, restored_expedition) or restored_plan == restored_dock or restored_plan == restored_landing or (restored_dock < 0 and restored_landing < 0):
			return false
	# Earlier saves may occupy coordinates where a new hull was added.
	if pre_fuel and restored_dock < 0 and restored_landing < 0:
		for index in range(site_count, Catalog.TARGET_COUNT):
			if _inside_hull(restored_position, index, restored_epoch):
				var center: Vector3 = Orbit.sample(index, restored_epoch).position
				restored_position = center + Vector3.BACK * float(Catalog.site(index).gate_offset)
				restored_velocity = Vector3.ZERO
				break
	# A legacy ship can be clear of the old sphere yet overlap the new terrain.
	if pre_surface and restored_dock < 0 and restored_landing < 0:
		var obstacle := _obstacle_at(restored_position, restored_system, restored_epoch, restored_expedition)
		if Catalog.is_mine_site(obstacle):
			var center: Vector3 = Orbit.sample(obstacle, restored_epoch).position
			var relative := restored_position - center
			if obstacle >= site_count:
				restored_position = center + Vector3.BACK * float(Catalog.site(obstacle).gate_offset)
				restored_velocity = Vector3.ZERO
			elif relative.length() >= float(Catalog.site(obstacle).radius) - 0.01:
				var direction := relative.normalized()
				restored_position = center + Terrain.contact(obstacle, direction) + direction * 3.0
				restored_velocity = Vector3.ZERO
	var velocity_limit := MAX_SAVED_SPEED if schema >= 6 else MAX_SPEED * 1.56
	if restored_velocity.length() > velocity_limit or (restored_dock < 0 and restored_landing < 0 and _blocked(restored_position, restored_system, restored_epoch, restored_expedition)):
		return false
	set_autopilot(false)
	position = restored_position
	velocity = restored_velocity
	yaw = float(state.yaw)
	pitch = float(state.pitch)
	roll = float(state.roll)
	_orientation_angles = restored_angles
	_orientation = restored_orientation
	flight_assist = true if pre_navigation else state.flight_assist
	throttle = float(state.throttle)
	elapsed = float(state.elapsed)
	orbit_time = restored_epoch
	time_scale = 1
	docked = restored_dock
	landed_site = restored_landing
	landing_direction = restored_direction
	mining = restored_mining
	ship = restored_ship
	market = restored_market
	patrol = restored_patrol
	expedition = restored_expedition
	factions = restored_factions
	convoy_order = restored_convoy_order
	star_heat = 0.0 if pre_thermal else float(state.star_heat)
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
	contract_route_id = route_id
	contract_leg = leg
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
