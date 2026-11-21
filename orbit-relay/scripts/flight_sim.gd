extends RefCounted
## Flight coordinates are local to the current star system.

const MiningRig = preload("res://scripts/mining_rig.gd")
const ShipSystems = preload("res://scripts/ship_systems.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")
const Dynamics = preload("res://scripts/orbital_dynamics.gd")
const Navigation = preload("res://scripts/orbital_navigation.gd")
const Rendezvous = preload("res://scripts/rendezvous_navigation.gd")
const Atmosphere = preload("res://scripts/atmosphere.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const Economy = preload("res://scripts/port_economy.gd")
const NpcFreight = preload("res://scripts/npc_freight.gd")
const GalacticRoute = preload("res://scripts/galactic_route.gd")
const Traffic = preload("res://scripts/sector_traffic.gd")
const Patrol = preload("res://scripts/patrol_encounter.gd")
const Expedition = preload("res://scripts/expedition.gd")
const FactionFronts = preload("res://scripts/faction_fronts.gd")
const ConvoyOrders = preload("res://scripts/convoy_orders.gd")
const DockAccess = preload("res://scripts/dock_access.gd")
const Passengers = preload("res://scripts/passengers.gd")
const Crew = preload("res://scripts/crew.gd")
const Cartography = preload("res://scripts/cartography.gd")
const FlightFrame = preload("res://scripts/flight_frame.gd")
const Customs = preload("res://scripts/customs.gd")
const UnattendedMining = preload("res://scripts/unattended_mining.gd")
const OrbitalMining = preload("res://scripts/orbital_mining.gd")
const CargoPods = preload("res://scripts/cargo_pods.gd")
const PortAccount = preload("res://scripts/port_account.gd")
const CivicReputation = preload("res://scripts/civic_reputation.gd")
const MissionCalendar = preload("res://scripts/mission_calendar.gd")
const CombatSystems = preload("res://scripts/combat_systems.gd")
const Ground = preload("res://scripts/ground_port.gd")
const SpeedHold = preload("res://scripts/speed_hold.gd")
const CivilianTraffic = preload("res://scripts/civilian_traffic.gd")
const PilotCareer = preload("res://scripts/pilot_career.gd")
const BranchingStory = preload("res://scripts/branching_story.gd")
const SectorNews = preload("res://scripts/sector_news.gd")
const SAVE_SCHEMA := 49
const INTERRUPTED_LABELS := {
	"autopilot": "автопилот", "rig_approach": "заход к буру", "orbit_maneuver": "орбитальный манёвр",
	"rendezvous": "автоматическое сближение", "patrol_course": "наведение дозора",
	"project_course": "наведение экспедиции", "convoy_course": "курс к конвою",
	"dock_roll_sync": "синхронизация крена", "unpaid_jump_charge": "зарядка прыжкового привода",
	"scoop": "сбор водорода", "time_scale": "ускорение времени",
}
const POWERED_ASSISTS := ["autopilot", "rig_approach", "orbit_maneuver", "rendezvous", "patrol_course", "project_course", "convoy_course"]
const REMOTE_RIG_ACCESS_DISTANCE := 20.0
const MINING_PULSE_RANGE := 200.0
const MINING_PULSE_FUEL := 0.4
const MINING_BEAM_DURATION := 0.24
const FRAGMENT_COLLECT_RANGE := 145.0
const FRAGMENT_COLLECT_SPEED := 7.0
const FUEL_PUMP_THRESHOLD := 0.35
const MISSILE_DAMAGE := 28.0
const MISSILE_HIT_RADIUS := 3.0
const SHIPYARD_PORTS := [0, 10, Catalog.FRINGE_ARRIVAL_PORT]
const TIME_SCALES := [1, 4, 16]
const SETTLED_TIME_SCALES := [1, 4, 16, 64, 256]
const FAST_WAIT_STEP := 4.0
const FAST_WAIT_DEADLINE_MARGIN := 15.0
const MAX_FLIGHT_STEP := 1.0 / 60.0
const JUMP_CHARGE := 2.5
const JUMP_TRANSIT_WALL := 0.45
const LEGACY_JUMP_PRICING := 0
const MASS_JUMP_PRICING := 1
const SAVE_CLOCK_LIMIT := 3155760000.0
const JUMP_BRAKE := 67.0
const NAVIGATOR_JUMP_CHARGE := 2.2
const JUMP_SPEED := 42.0
const JUMP_CLEARANCE := 45.0
const ARRIVAL_OFFSET := 90.0
const MAX_SPEED := 145.0
const RESERVE_SPEED := 42.0
const SCOOP_RATE := 7.0
const GAS_SCOOP_RATE := 8.5
const GAS_SCOOP_MIN_ALTITUDE := 26.0
const GAS_SCOOP_MAX_ALTITUDE := 84.0
const GAS_SCOOP_SPEED := 36.0
const HEAT_SCOOP_SLOW := 55.0
const HEAT_SCOOP_LIMIT := 76.0
const HEAT_DAMAGE_LIMIT := 85.0
const MAX_STEER := 1.45
const MAX_PITCH := PI * 0.5
const LEGACY_MAX_PITCH := 1.42
const MAX_ROLL := ShipSystems.COURIER_ROLL_RATE
const DOCK_SPEED := 5.0
const DOCK_ROLL_ERROR := 0.16
const DOCK_AIM_ERROR := 0.15
const DOCK_GUIDE_DISTANCE := 180.0
const DOCK_SYNC_AIM := 32.0
const DOCK_AUTO_DISTANCE := 2.7
const DOCK_AUTO_SPEED := 3.0
const DEPARTURE_SECONDS := 3.2
const DEPARTURE_DISTANCE := 15.0
const DEPARTURE_SPEED := 6.0
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
const LANDING_GUIDE_HEIGHT := 90.0
const LANDING_ANGLE := 20.0
const GEAR_TRAVEL_SECONDS := 1.4
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
const RENDEZVOUS_HOLD_DISTANCE := 4.0
const RENDEZVOUS_HOLD_SPEED := 1.0

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
var rendezvous_active := false
var docked := 0
var dock_roll_sync := -1
var dock_access := DockAccess.new()
var _departure_requested := false
var _departure_seconds := -1.0
var landed_site := -1
var landing_direction := Vector3.ZERO
var landed: bool:
	get:
		return landed_site >= 0
var gear_extension := 0.0
var gear_deployed := false
var mining := MiningRig.new()
var ship := ShipSystems.new()
var market := Economy.new()
var freight := NpcFreight.new()
var patrol := Patrol.new()
var patrol_course := false
var expedition := Expedition.new()
var factions := FactionFronts.new()
var convoy_order := ConvoyOrders.new()
var passengers := Passengers.new()
var crew := Crew.new()
var cartography := Cartography.new()
var frame := FlightFrame.new()
var speed_hold := SpeedHold.new()
var customs := Customs.new()
var _port_account := PortAccount.new()
var _civic := CivicReputation.new()
var remote_rig := UnattendedMining.new()
var orbital_mining := OrbitalMining.new()
var _cargo_pods := CargoPods.new()
var combat := CombatSystems.new()
var ambient := CivilianTraffic.new()
var career := PilotCareer.new()
var story := BranchingStory.new()
var news := SectorNews.new()
var _mining_beam: Dictionary = {}
var convoy_course := false
var project_course := false
var scooping := false
var _scoop_body := -1
var _scoop_progress := 0.0
var star_heat := 0.0
var entry_heat := 0.0
var system_id := Catalog.HOME_SYSTEM
var jump_target := -1
var jump_seconds_left := 0.0
var _jump_charge_total := JUMP_CHARGE
var _jump_transit_duration := 0.0
var _jump_paid_fare := 0
var _jump_paid_pricing := MASS_JUMP_PRICING
var _jump_route: Array[int] = []
var target := 1
var planned_target := -1
var autopilot := false
var autopilot_phase := ""
var credits := 0
var deliveries := 0
var contract_stage := 0
var contract_origin := -1
var _contract_issuer := -1
var contract_destination := -1
var contract_route_id := ""
var contract_leg := -1
var elapsed := 0.0
var orbit_time := 0.0
var time_scale := 1
var time_paused := false
var status_event := ""
var status_message := ""

var _approach_committed := false
var _rig_approach := false
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
var _rendezvous_site := -1
var _rendezvous_gap := 150
var _rendezvous_offset := Vector3.ZERO
var _rendezvous_holding := false
var _entry_site := -1


func speed() -> float:
	return velocity.length()


func reference_site() -> int:
	return frame.reference_site(self)


func frame_status() -> Dictionary:
	var site := reference_site()
	var drift := _reference_velocity(site) if site >= 0 else Vector3.ZERO
	var relative := Vector3.ZERO if docked >= 0 or landed else velocity - drift
	var mode := "body"
	if frame.choice == FlightFrame.AUTO:
		mode = "auto"
	elif frame.choice == FlightFrame.SYSTEM:
		mode = "system"
	return {
		"mode": mode, "choice": frame.choice, "reference": site,
		"name": Catalog.system(system_id).name if site < 0 else target_name(site),
		"available": jump_seconds_left <= 0.0 and not _departure_requested,
		"surface": site >= 0 and _reference_ground_weight(site) > 0.0,
		"velocity": drift, "relative_velocity": relative, "relative_speed": relative.length(),
	}


func set_reference_frame(selection: int) -> bool:
	if jump_seconds_left > 0.0 or _departure_requested or selection == frame.choice or not frame.select(selection, local_targets()):
		return false
	var chosen := "Автоматический выбор"
	if selection == FlightFrame.SYSTEM:
		chosen = "Система «%s»" % Catalog.system(system_id).name
	elif selection >= 0:
		chosen = target_name(selection)
	_announce("reference_frame", "Кадр полёта · %s." % chosen)
	return true


func cycle_reference_frame() -> bool:
	if frame.choice == FlightFrame.AUTO:
		return set_reference_frame(FlightFrame.SYSTEM)
	if frame.choice == FlightFrame.SYSTEM and target in local_targets():
		return set_reference_frame(target)
	return set_reference_frame(FlightFrame.AUTO)


func relative_speed() -> float:
	if docked >= 0 or landed:
		return 0.0
	var site := reference_site()
	return velocity.distance_to(_reference_velocity(site)) if site >= 0 else speed()


func speed_relative_to(index: int) -> float:
	return (velocity - target_velocity(index)).length()


func clock_status() -> Dictionary:
	var label := MissionCalendar.stamp(orbit_time)
	var parts := label.split(" · ", false, 1)
	return {
		"stamp": label, "date": parts[0] if parts.size() == 2 else "",
		"clock": parts[1] if parts.size() == 2 else "", "epoch": orbit_time,
		"paused": time_paused, "scale": time_scale,
	}


func toggle_time_pause() -> bool:
	time_paused = not time_paused
	if time_paused:
		_announce("time_paused", "Ход времени приостановлен.")
	else:
		_announce("time_resumed", "Ход времени возобновлён.")
	return true


func time_status() -> Dictionary:
	if jump_seconds_left > 0.0:
		return {"allowed": false, "reason": "Зарядка прыжкового привода"}
	if _departure_requested:
		return {"allowed": false, "reason": "Выход из дока"}
	if gear_extension != (1.0 if gear_deployed else 0.0):
		return {"allowed": false, "reason": "Шасси в движении"}
	if orbit_maneuver:
		return {"allowed": false, "reason": "Орбитальный манёвр"}
	if rendezvous_active:
		return {"allowed": false, "reason": "Сближение с объектом" if not _rendezvous_holding else "Удержание позиции"}
	if scooping:
		return {"allowed": false, "reason": "Сбор топлива"}
	if patrol.in_danger(self) or ambient.in_danger(self) or not combat.projectile_status().is_empty():
		return {"allowed": false, "reason": "Боевой контакт"}
	if convoy_course or convoy_order.in_danger(self):
		return {"allowed": false, "reason": "Сближение с конвоем"}
	if docked >= 0 or landed:
		var fast_available := orbit_time < _fast_wait_stop_epoch()
		return {"allowed": true, "reason": "", "max_rate": SETTLED_TIME_SCALES[-1] if fast_available else TIME_SCALES[-1]}
	if Atmosphere.sample(self, position, velocity).inside:
		return {"allowed": false, "reason": "Полёт в атмосфере"}
	if maxf(star_heat, entry_heat) >= HEAT_SCOOP_LIMIT:
		return {"allowed": false, "reason": "Корпус ещё горячий"}
	for id: int in local_targets():
		var radius := Catalog.SCOOP_OUTER + STAR_WARP_MARGIN if Catalog.is_star(id) else float(Catalog.site(id).radius) + FRAME_MARGIN
		if position.distance_squared_to(target_position(id)) <= radius * radius:
			return {"allowed": false, "reason": "Рядом «%s»" % target_name(id)}
	return {"allowed": true, "reason": "", "max_rate": TIME_SCALES[-1]}


func cycle_time_scale() -> bool:
	if time_paused:
		_announce("time_denied", "Возобновите ход времени.")
		return false
	var availability := time_status()
	if not availability.allowed:
		_announce("time_denied", "Ускорение недоступно. %s." % availability.reason)
		return false
	var rates := SETTLED_TIME_SCALES if int(availability.max_rate) > TIME_SCALES[-1] else TIME_SCALES
	time_scale = rates[(rates.find(time_scale) + 1) % rates.size()]
	_announce("time_scale", "Скорость времени ×%d." % time_scale)
	return true


func reset_time_scale() -> bool:
	if time_scale == 1:
		return false
	time_scale = 1
	_announce("time_normal", "Возврат к обычному времени.")
	return true


func station_axis(index: int) -> Vector3:
	return Ground.basis(index, orbit_time).z if Ground.is_port(index) else Vector3.BACK


func station_angle(index: int) -> float:
	var port := Catalog.site(index)
	return wrapf(elapsed * float(port.spin) + float(port.angle), -PI, PI)


func gate_position(index: int) -> Vector3:
	return target_gate(index)


func docking_position(index: int) -> Vector3:
	return target_contact(index)


func dock_hatch_position(index: int) -> Vector3:
	return docking_position(index) + station_axis(index) * DockAccess.HATCH_AXIS_OFFSET


func target_name(index: int) -> String:
	return str(Catalog.site(index).get("name", ""))


func system_known(index: int) -> bool:
	return expedition.known(index) or cartography.discovered(index)


func known_systems() -> Array[int]:
	return _known_systems(expedition, cartography)


func system_faction_name(index: int) -> String:
	return FactionFronts.faction_name(factions.owner(index))


func station_operational(index: int) -> bool:
	return Catalog.is_port(index) and _site_available(index, expedition)


func body_dossier(site: int) -> Dictionary:
	return cartography.body_status(self, site)


func system_dossier(system: int) -> Dictionary:
	return cartography.system_status(self, system)


func survey_action(site: int) -> bool:
	var scan := body_dossier(site)
	if not scan.can_scan or not cartography.record(site, orbit_time):
		return false
	_announce("survey_record", "Данные «%s» записаны в атлас." % target_name(site))
	return true


func galaxy_scan_status() -> Dictionary:
	var count := cartography.neighbors_to_discover(system_id).size() if system_known(system_id) else 0
	var reason := ""
	if jump_seconds_left > 0.0 or _departure_requested:
		reason = "Дождитесь окончания манёвра"
	elif count == 0:
		reason = "В пределах радиуса нет неизвестных систем"
	return {"allowed": reason.is_empty(), "unseen_count": count, "range": Catalog.GENERATED_SCAN_RANGE, "reason": reason}


func scan_galaxy() -> bool:
	if not galaxy_scan_status().allowed:
		return false
	var count := cartography.discover_from(system_id, orbit_time)
	if count <= 0:
		return false
	_announce("galaxy_scan", "Новые звёздные отметки на карте · %d." % count)
	return true


func local_targets() -> Array:
	var targets := Catalog.targets_for(system_id)
	if system_id < Catalog.CORE_SYSTEM_COUNT or expedition.commissioned(system_id):
		return targets
	return targets.filter(func(id: int) -> bool: return not Catalog.is_port(id))


func local_ports() -> Array:
	return Catalog.ports_for(system_id) if system_id < Catalog.CORE_SYSTEM_COUNT or expedition.commissioned(system_id) else []


func _site_available(index: int, progress: RefCounted, atlas: RefCounted = null) -> bool:
	var system := Catalog.system_of_site(index)
	if system >= 0 and system < Catalog.CORE_SYSTEM_COUNT:
		return true
	if Catalog.is_generated_system(system):
		return (cartography if atlas == null else atlas).discovered(system)
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


func _surface_axis(index: int, epoch: float) -> Vector3:
	return Terrain.spin_basis(index, epoch).z


func _rig_landing_target(index: int) -> bool:
	return _rig_approach and remote_rig.site_id == index and remote_rig.active()


func _approach_axis(index: int, epoch: float) -> Vector3:
	if Ground.is_port(index):
		return Ground.basis(index, epoch).z
	if _rig_landing_target(index):
		return Terrain.spin_basis(index, epoch) * remote_rig.direction
	return _surface_axis(index, epoch)


func target_gate(index: int) -> Vector3:
	return target_position(index) + _approach_axis(index, orbit_time) * float(Catalog.site(index).gate_offset)


func target_contact(index: int) -> Vector3:
	var center := target_position(index)
	if _rig_landing_target(index):
		return center + Terrain.spin_basis(index, orbit_time) * Terrain.contact(index, remote_rig.direction)
	return center + _approach_axis(index, orbit_time) * float(Catalog.site(index).pad_offset)


func _surface_body(site: int) -> int:
	return Ground.body(site) if Ground.is_port(site) else site


func _surface_basis(site: int, epoch: float) -> Basis:
	return Ground.basis(site, epoch) if Ground.is_port(site) else Terrain.spin_basis(site, epoch)


func surface_velocity(site: int, at_point: Vector3) -> Vector3:
	return target_velocity(site) + Terrain.spin_velocity(_surface_body(site), at_point - target_position(site))


func _reference_ground_weight(site: int) -> float:
	if Terrain.spin_rate(_surface_body(site)) <= 0.0:
		return 0.0
	var altitude := position.distance_to(target_position(site)) - float(Catalog.site(site).radius)
	return 1.0 - smoothstep(LANDING_GUIDE_HEIGHT - 20.0, LANDING_GUIDE_HEIGHT, altitude)


func _reference_velocity(site: int) -> Vector3:
	var drift := target_velocity(site)
	return drift + Terrain.spin_velocity(_surface_body(site), position - target_position(site)) * _reference_ground_weight(site)


func intercept_time(index: int) -> float:
	if Catalog.system_of_site(index) != system_id:
		return 0.0
	var from_gate := target_gate(index) - position
	var drift := surface_velocity(index, target_gate(index))
	var cruise := _cruise_limit(118.0)
	var speed_difference := maxf(1.0, cruise * cruise - drift.length_squared())
	var projection := from_gate.dot(drift)
	return (projection + sqrt(projection * projection + speed_difference * from_gate.length_squared())) / speed_difference


func roll_error(index: int) -> float:
	return angle_difference(roll, station_angle(index) if Catalog.is_port(index) else 0.0)


func _match_target_roll(delta: float) -> void:
	var limit := ship.roll_rate(mining.ore_hold) * delta
	var turn := clampf(roll_error(target), -limit, limit)
	roll = wrapf(roll + turn, -PI, PI)


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
	var rates := Vector3(steer.y * MAX_STEER, -steer.x * MAX_STEER, bank * ship.roll_rate(mining.ore_hold))
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
	var collision_radius := surface_radius
	if Catalog.is_star(focus):
		collision_radius = Catalog.stellar_clearance(focus)
	elif Catalog.is_mine_site(focus):
		collision_radius = surface_radius * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE
	result.merge({
		"star": star, "focus": focus, "focus_kind": site.get("kind", ""),
		"name": str(site.get("name", "")), "classification": (
			("bound" if result.bound else "escape") if measurable else "unavailable"
		),
		"altitude": maxf(0.0, float(result.radius) - surface_radius),
		"relative_speed": relative_velocity.length(),
		"collision_radius": collision_radius,
		"approach_min": band.x, "approach_max": band.y,
		"allowed": reason.is_empty() and not orbit_maneuver,
		"reason": "Можно выполнить орбитальный манёвр" if reason.is_empty() else reason,
		"maneuver": orbit_maneuver, "maneuver_phase": _orbit_phase, "delta_v": delta_v,
	})
	return result


func orbit_forecast(focus_id := -1) -> Dictionary:
	return Navigation.forecast(self, 180.0, _orbit_focus(focus_id))


func rendezvous_status(site_id := -1, gap := 150) -> Dictionary:
	var site := _rendezvous_site if rendezvous_active else (target if site_id == -1 else site_id)
	var separation := _rendezvous_gap if rendezvous_active else gap
	var reason := _rendezvous_block_reason(site, separation)
	var clear_to_proceed := reason.is_empty()
	var has_point := Rendezvous.supports(site) and site in local_targets() and separation in Rendezvous.GAPS
	var point := Vector3.ZERO
	var predicted := Vector3.ZERO
	var eta := -1.0
	var distance := -1.0
	var relative := -1.0
	if has_point:
		var offset := _rendezvous_offset if rendezvous_active else Rendezvous.choose_offset(self, site, separation)
		var plan := Rendezvous.plan(self, site, offset)
		point = plan.point
		predicted = plan.predicted
		eta = 0.0 if _rendezvous_holding else float(plan.eta)
		distance = position.distance_to(point)
		relative = speed_relative_to(site)
	var phase := "idle"
	if rendezvous_active:
		phase = "hold" if _rendezvous_holding else "approach"
	var settled := _rendezvous_holding and distance <= RENDEZVOUS_HOLD_DISTANCE and relative <= RENDEZVOUS_HOLD_SPEED
	if reason.is_empty():
		match phase:
			"idle": reason = "Можно начать сближение"
			"approach": reason = "Идём к точке встречи и снижаем относительную скорость"
			"hold": reason = "Скорость выровнена. Можно продолжить к цели" if settled else "Восстанавливаем позицию"
	return {
		"site": site, "name": target_name(site), "kind": str(Catalog.site(site).get("kind", "")),
		"allowed": not rendezvous_active and has_point and clear_to_proceed,
		"reason": reason, "active": rendezvous_active, "phase": phase,
		"gap": separation, "has_point": has_point, "point": point, "predicted": predicted, "eta": eta,
		"distance": distance, "relative_speed": relative,
		"can_finish": rendezvous_active and settled and clear_to_proceed,
	}


func start_rendezvous(site: int, gap := 150) -> bool:
	if rendezvous_active or not _rendezvous_block_reason(site, gap).is_empty():
		return false
	reset_time_scale()
	set_autopilot(false)
	_release_speed_hold(false)
	select_target(site)
	rendezvous_active = true
	_rendezvous_site = site
	_rendezvous_gap = gap
	_rendezvous_offset = Rendezvous.choose_offset(self, site, gap)
	_rendezvous_holding = false
	_reset_scoop()
	throttle = 0.0
	boost = false
	_announce("rendezvous_start", "Сближение с объектом «%s». Дистанция ожидания %d м." % [target_name(site), gap])
	return true


func cancel_rendezvous() -> bool:
	if not rendezvous_active:
		return false
	_clear_rendezvous()
	_announce("rendezvous_cancel", "Сближение отменено. Ручное управление.")
	return true


func finish_rendezvous() -> bool:
	var status := rendezvous_status()
	if not status.can_finish or not select_target(status.site):
		return false
	set_autopilot(true)
	var operation := "Стыковка" if Catalog.is_port(status.site) else "Посадка"
	_announce("rendezvous_finish", "%s. Автопилот ведёт к объекту «%s»." % [operation, status.name])
	return true


func _clear_rendezvous() -> void:
	if rendezvous_active:
		rendezvous_active = false
		_rendezvous_site = -1
		_rendezvous_holding = false
		throttle = 0.0


func _rendezvous_block_reason(site: int, gap: int) -> String:
	if not Rendezvous.supports(site) or site not in local_targets():
		return "Выберите действующий порт или твёрдое тело этой системы"
	if gap not in Rendezvous.GAPS:
		return "Выберите дистанцию ожидания"
	if docked >= 0 or landed or jump_seconds_left > 0.0:
		return "Выйдите в открытый космос"
	if not ship.autopilot_fitted:
		return "Автопилот снят. Его можно установить в порту."
	if patrol.in_danger(self) or convoy_order.in_danger(self) or ambient.in_danger(self):
		return "Отойдите от боевого контакта"
	if ship.hull <= ShipSystems.MIN_HULL:
		return "Восстановите корпус в порту"
	return ""


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
	_release_speed_hold(false)
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
	if Catalog.is_star(focus):
		if Catalog.stars_for(system_id).size() > 1:
			# A local circular burn would cross the shared gravitational region.
			return Vector2.ZERO
		return Vector2(ORBIT_MIN_RADIUS, ORBIT_MAX_RADIUS)
	var parent := Orbit.orbit_parent(focus)
	if parent >= 0:
		return Navigation.orbit_band(focus, center, target_position(parent), Dynamics.gravity_parameter(parent))
	if Catalog.stars_for(system_id).size() > 1:
		var barycenter: Vector3 = Catalog.system(system_id).barycenter
		return Navigation.orbit_band(focus, center, barycenter, Orbit.gravity_parameter(system_id))
	return Navigation.orbit_band(focus, center, target_position(star), Dynamics.gravity_parameter(star))


func _orbit_speed_tolerance(focus: int, circular_speed: float) -> float:
	if Catalog.is_star(focus):
		return ORBIT_SPEED_TOLERANCE
	return clampf(circular_speed * 0.025, 0.015, ORBIT_SPEED_TOLERANCE)


func _orbit_block_reason(focus: int, radius: float, relative_speed: float, band: Vector2, starting: bool) -> String:
	if docked >= 0 or landed or jump_seconds_left > 0.0:
		return "Выйдите в открытый космос"
	if not ship.autopilot_fitted:
		return "Автопилот снят. Его можно установить в порту."
	if patrol.in_danger(self) or convoy_order.in_danger(self) or ambient.in_danger(self):
		return "Отойдите от боевого контакта"
	if band.x >= band.y:
		return "Для круговой орбиты вокруг этого тела сейчас нет безопасного диапазона"
	if radius < band.x or radius > band.y:
		return "Держитесь в пределах %d–%d м от центра «%s»" % [ceili(band.x), floori(band.y), target_name(focus)]
	if starting and relative_speed > ORBIT_MAX_SPEED:
		return "Снизьте скорость относительно цели до %d м/с" % int(ORBIT_MAX_SPEED)
	if ship.fuel <= 0.0 or (starting and ship.fuel < ORBIT_MIN_FUEL):
		return "Для манёвра нужно не менее %d ед. топлива" % int(ORBIT_MIN_FUEL)
	if ship.hull <= ShipSystems.MIN_HULL or maxf(star_heat, entry_heat) >= HEAT_SCOOP_LIMIT:
		return "Манёвр требует исправного и остывшего корпуса"
	if Atmosphere.sample(self, position, velocity).inside:
		return "Выйдите из атмосферы для орбитального манёвра"
	for id: int in local_targets():
		var clearance := Catalog.SCOOP_OUTER + 50.0 if Catalog.is_star(id) else float(Catalog.site(id).radius) + ORBIT_CLEARANCE
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
	var offer := Economy.courier_at(docked)
	if offer.is_empty():
		return offer
	var required := int(CivicReputation.CONTRACT_REQUIREMENTS.get(offer.id, 0))
	var score := _civic.reputation(deliveries)
	offer.allowed = station_services_available() and score >= required
	offer.access_hint = "Гражданская репутация %d / %d. Помогите фонду экипажей или завершите обычные рейсы." % [score, required] if score < required else ""
	return offer


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
	if not offer.allowed:
		if not str(offer.access_hint).is_empty():
			_announce("contract_reputation_denied", offer.access_hint)
		return false
	contract_origin = docked
	_contract_issuer = factions.owner(system_id)
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
	if not station_services_available():
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
		career.note_delivery(_contract_issuer)
		_contract_issuer = -1
		contract_stage = 2
		_announce("delivery", "Груз принят. Начислено %d кр." % reward)
	else:
		contract_stage = 1
		contract_route_id = ""
		contract_leg = -1
		contract_origin = docked
		_contract_issuer = factions.owner(system_id)
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
	_cargo_pods.tracked = -1
	if docked >= 0 or landed:
		planned_target = index
	else:
		_stop_convoy_course()
		_clear_orbit_maneuver()
		_clear_rendezvous()
		cancel_dock_sync()
		if target != index:
			dock_access.cancel(orbit_time)
		target = index
		_approach_committed = false
		if autopilot:
			set_autopilot(true)
	return true


func station_services_available() -> bool:
	return not _departure_requested and station_operational(docked)


func port_account_status() -> Dictionary:
	var account := _port_account.status(docked, orbit_time, credits)
	var available := station_services_available()
	account.can_pay = account.can_pay and available
	account.can_defer = account.can_defer and available
	return account


func civic_status() -> Dictionary:
	return _civic.status(deliveries, credits, station_services_available())


func autopilot_equipment_status() -> Dictionary:
	return {
		"installed": ship.autopilot_fitted,
		"available": station_services_available(),
		"can_engage": ship.autopilot_fitted and _manual_speed_available(),
	}


func autopilot_equipment_action() -> bool:
	if not station_services_available():
		return false
	var fitted := not ship.autopilot_fitted
	ship.set_autopilot_fitted(fitted)
	_announce("autopilot_equipment", "Автопилот установлен." if fitted else "Автопилот снят в отсек.")
	return true


func _manual_speed_available() -> bool:
	return docked < 0 and not landed and jump_seconds_left <= 0.0


func nearby_pilot_target() -> bool:
	var radius := float(Catalog.site(target).radius)
	return position.distance_to(target_position(target)) < maxf(150.0, radius + FRAME_MARGIN)


func speed_hold_status() -> Dictionary:
	var controls := frame_status()
	return {
		"available": _manual_speed_available(), "enabled": speed_hold.enabled,
		"setpoint": speed_hold.setpoint, "name": controls.name,
		"actual": SpeedHold.projected_speed(velocity, controls.velocity, forward()) if _manual_speed_available() else 0.0,
		"step": 2.0 if nearby_pilot_target() else 10.0,
	}


func toggle_speed_hold() -> bool:
	if not _manual_speed_available():
		return false
	reset_time_scale()
	if speed_hold.enabled:
		_release_speed_hold()
	else:
		set_autopilot(false)
		throttle = 0.0
		boost = false
		speed_hold.set_enabled(true)
		_announce("speed_hold_on", "Удержание продольной скорости включено.")
	return true


func adjust_speed_hold(amount: float) -> bool:
	if not speed_hold.enabled or not _manual_speed_available() or not speed_hold.adjust(amount):
		return false
	reset_time_scale()
	return true


func change_speed_pilot_control(throttle_delta: float, speed_delta: float) -> void:
	if speed_hold.enabled:
		adjust_speed_hold(speed_delta)
	else:
		change_throttle(throttle_delta)


func _release_speed_hold(notify := true) -> void:
	if speed_hold.set_enabled(false) and notify:
		_announce("speed_hold_off", "Удержание скорости выключено. Ручная тяга.")


func change_throttle(amount: float) -> void:
	if docked < 0 and not landed and _jump_transit_duration <= 0.0:
		reset_time_scale()
		cancel_jump()
		_release_speed_hold()
		if dock_roll_sync < 0:
			set_autopilot(false)
		throttle = clampf(throttle + amount, 0.0, 1.0)


func set_autopilot(enabled: bool) -> void:
	if enabled and not ship.autopilot_fitted:
		_announce("autopilot_missing", "Автопилот снят. Его можно установить в порту.")
		return
	_rig_approach = false
	cancel_dock_sync()
	patrol_course = false
	project_course = false
	_stop_convoy_course()
	_clear_orbit_maneuver()
	_clear_rendezvous()
	autopilot = enabled and docked < 0 and not landed and jump_seconds_left <= 0.0
	_approach_committed = false
	_departure_leg = 0
	_departure_axis = Vector3.ZERO
	autopilot_phase = "К створу" if autopilot else ""
	if not autopilot:
		return
	_cargo_pods.tracked = -1
	_release_speed_hold(false)
	for index: int in local_targets():
		if Catalog.is_star(index):
			continue
		var center := target_position(index)
		var offset := position - center
		var near_distance := float(Catalog.site(index).radius) + 48.0
		if index != target and Ground.is_port(index) and offset.length_squared() < 1600.0 and offset.dot(station_axis(index)) >= -0.8:
			_departure_site = index
			_departure_axis = station_axis(index)
			_departure_leg = 1
			break
		if index != target and Catalog.is_mine_site(index) and offset.length_squared() < near_distance * near_distance and (Terrain.spin_rate(index) > 0.0 or offset.normalized().dot(Vector3.BACK) < 0.96):
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
		var exit := departure_status()
		return {"ok": exit.can_request or exit.can_cancel, "reason": exit.reason}
	if landed:
		var ready := mining.phase == MiningRig.STOWED
		return {"ok": ready, "reason": "Можно взлететь" if ready else "Сначала верните модуль на борт"}
	if jump_seconds_left > 0.0:
		return {"ok": false, "reason": "Идёт зарядка прыжкового привода"}
	if Catalog.is_star(target):
		return {"ok": false, "reason": "У звезды можно собирать топливо"}
	if Catalog.is_gas_giant(target):
		return {"ok": false, "reason": "В атмосфере гиганта можно собирать водород"}
	if Catalog.is_mine_site(target):
		return surface_status()
	return docking_guidance()


func docking_guidance() -> Dictionary:
	if docked >= 0 or landed or jump_seconds_left > 0.0 or Catalog.system_of_site(target) != system_id or not station_operational(target):
		return {"near": false, "in_front": false, "port": -1, "ok": false, "sync_available": false,
			"sync_active": false, "cleared": false, "access": dock_access_status(target),
			"reason": "Выберите действующий порт в текущей системе"}
	var ground := Ground.is_port(target)
	var hangar := Ground.is_hangar(target)
	var axis := station_axis(target)
	var displacement := position - docking_position(target)
	var relative_velocity := velocity - target_velocity(target)
	var local_offset := Ground.basis(target, orbit_time).transposed() * displacement if ground else displacement.rotated(axis, -station_angle(target))
	var off_axis := Vector2(local_offset.x, local_offset.y)
	var axis_distance := displacement.dot(axis)
	var distance := displacement.length()
	var speed := relative_velocity.length()
	var nose_error := acos(clampf(forward().dot(-axis), -1.0, 1.0))
	var bank_error := roll_error(target)
	var in_front := axis_distance >= -0.8
	var near := distance <= DOCK_GUIDE_DISTANCE
	var position_ok := in_front and distance <= 7.0 and off_axis.length() <= (4.7 if ground and not hangar else 3.1)
	var crossed_hatch := (ground and not hangar) or axis_distance <= DockAccess.HATCH_AXIS_OFFSET
	var speed_ok := speed <= (LANDING_SPEED if ground else DOCK_SPEED)
	var aim_ok := nose_error <= DOCK_AIM_ERROR
	var roll_ok := ground or absf(bank_error) <= DOCK_ROLL_ERROR
	var gear_ok := not ground or _gear_locked()
	var access := dock_access_status(target, displacement)
	var reason := "Можно садиться в порту" if ground else "Можно швартоваться"
	if not access.ready:
		reason = access.reason
	elif not position_ok:
		reason = "Подойдите к посадочной отметке" if ground else "Подойдите к центру стыковочного кольца"
	elif not crossed_hatch:
		reason = "Войдите через открытый створ"
	elif not speed_ok:
		reason = "Снизьте скорость над площадкой до 4 м/с" if ground else "Снизьте скорость относительно станции до 5 м/с"
	elif not aim_ok:
		reason = "Направьте нос к площадке" if ground else "Направьте нос в створ"
	elif not roll_ok:
		reason = "Совместите крен с кольцом"
	elif not gear_ok:
		reason = "Дождитесь выпуска шасси" if gear_deployed else "Выпустите шасси"
	var manual_flight := not (autopilot or orbit_maneuver or rendezvous_active or patrol_course or project_course or convoy_course)
	return {
		"near": near, "in_front": in_front, "port": target,
		"port_tariff": PortAccount.TARIFFS.get(target, Vector2i.ZERO),
		"ground": ground, "ground_hangar": hangar, "gear_ok": gear_ok,
		"awaiting_gear": ground and access.ready and position_ok and crossed_hatch and speed_ok and aim_ok and not gear_ok,
		"ok": access.ready and position_ok and crossed_hatch and speed_ok and aim_ok and roll_ok and gear_ok,
		"access": access, "cleared": access.ready, "crossed_hatch": crossed_hatch,
		"axis_distance": axis_distance, "range": distance, "off_axis": off_axis, "lateral_error": off_axis.length(),
		"closing_speed": -relative_velocity.dot(axis), "relative_speed": speed, "aim_error_deg": rad_to_deg(nose_error),
		"roll_error_deg": rad_to_deg(bank_error),
		"spin_deg_sec": rad_to_deg(Terrain.spin_rate(_surface_body(target)) if ground else float(Catalog.site(target).spin)),
		"position_ok": position_ok, "speed_ok": speed_ok, "aim_ok": aim_ok, "roll_ok": roll_ok,
		"sync_available": not ground and manual_flight and near and in_front and nose_error <= deg_to_rad(DOCK_SYNC_AIM),
		"sync_active": dock_roll_sync == target, "reason": reason,
	}


func dock_access_status(site: int, displacement := Vector3.INF) -> Dictionary:
	var status := dock_access.status(site, orbit_time)
	status.request_available = false
	status.reason = "Выберите действующий порт в текущей системе"
	if Catalog.system_of_site(site) != system_id or not station_operational(site):
		return status
	if Ground.is_port(site) and not Ground.is_hangar(site):
		status.ready = true
		status.phase = "open"
		status.open_fraction = 1.0
		status.reason = "Открытая площадка"
		return status
	if not displacement.is_finite():
		displacement = position - docking_position(site)
	var in_range := displacement.length_squared() <= DOCK_GUIDE_DISTANCE * DOCK_GUIDE_DISTANCE
	var in_front := displacement.dot(station_axis(site)) >= -0.8
	status.request_available = (not landed and docked < 0 and jump_seconds_left <= 0.0
		and site == target and in_range and in_front and status.phase == "closed")
	match status.phase:
		"queued": status.reason = "Ожидайте допуска перед створом"
		"opening": status.reason = "Створ открывается"
		"open": status.reason = "Проход открыт"
		"closing": status.reason = "Створ закрывается. Дождитесь нового допуска"
		_:
			status.reason = "Запросите допуск" if status.request_available else "Подойдите к створу действующего порта"
	return status


func dock_clearance_action() -> bool:
	var status := dock_access_status(target)
	if not status.request_available or not dock_access.request(target, orbit_time, freight_status(target)):
		return false
	reset_time_scale()
	_announce("dock_request", "Запрос на швартовку. Ожидайте перед створом «%s»." % target_name(target))
	return true


func departure_status() -> Dictionary:
	var required := ship.crew_required()
	var hired: int = crew.status(orbit_time).count if docked >= 0 and required > 0 else 0
	var cleared := _port_account.clearance(docked, orbit_time, credits)
	var status := {"active": _departure_requested, "can_cancel": false, "phase": "idle",
		"progress": 0.0, "wait": 0.0, "reason": "Запросите выход", "port": docked,
		"can_request": docked >= 0 and not _departure_requested and hired >= required and cleared}
	if not _departure_requested:
		if docked >= 0 and hired < required:
			status.reason = "Для выхода нужен экипаж: %d из %d. Откройте Сервис → Экипаж." % [hired, required]
		elif docked >= 0 and not cleared:
			status.reason = "Просрочен счёт этого порта. Откройте Сервис → Сборы."
		elif Ground.is_port(docked) and not Ground.is_hangar(docked):
			status.reason = "Можно взлететь с площадки"
		return status
	var access := dock_access.status(docked, orbit_time)
	if _departure_seconds >= 0.0:
		status.phase = "transit"
		status.progress = _departure_seconds / DEPARTURE_SECONDS
		status.reason = "Корабль проходит через открытый створ"
	else:
		status.phase = "opening" if access.phase == "opening" else "waiting"
		status.can_cancel = true
		status.progress = access.open_fraction if access.phase == "opening" else 0.0
		status.wait = access.wait
		if access.phase == "closing":
			status.wait += DockAccess.HEADING_SECONDS + DockAccess.OPENING_SECONDS
		status.reason = "Створ открывается для выхода" if access.phase == "opening" else "Ожидайте разрешения на выход"
	return status


func _departure_action() -> bool:
	if _departure_requested:
		if _departure_seconds >= 0.0:
			return false
		dock_access.cancel(orbit_time)
		_departure_requested = false
		_announce("departure_canceled", "Выход отменён. Корабль остаётся в доке.")
		return true
	if not station_operational(docked):
		return false
	var status := departure_status()
	if not status.can_request:
		_announce("departure_crew_denied" if _port_account.clearance(docked, orbit_time, credits) else "departure_charge_denied", status.reason)
		return false
	reset_time_scale()
	if Ground.is_port(docked) and not Ground.is_hangar(docked):
		_launch()
		return true
	_departure_requested = true
	_request_departure_slot()
	_announce("departure_requested", "Запрос выхода из «%s» передан." % target_name(docked))
	return true


func _request_departure_slot() -> void:
	if dock_access.status(docked, orbit_time).phase == "closed":
		dock_access.request(docked, orbit_time, freight_status(docked))


func _advance_departure(delta: float) -> void:
	if _departure_seconds < 0.0:
		var access := dock_access.status(docked, orbit_time)
		if access.ready:
			_departure_seconds = 0.0
			_hold_departure_pose()
			var berth := "ангара" if Ground.is_hangar(docked) else "дока"
			_announce("departure_open", "Створ открыт. Корабль выходит из %s." % berth)
		else:
			_request_departure_slot()
			_hold_docked_pose()
		return
	_departure_seconds += delta
	if _departure_seconds >= DEPARTURE_SECONDS:
		dock_access.settle(orbit_time)
		_launch()
	else:
		_hold_departure_pose()


func _hold_departure_pose() -> void:
	var progress := clampf(_departure_seconds / DEPARTURE_SECONDS, 0.0, 1.0)
	# Cubic motion starts at rest in the moving dock and matches the release speed.
	var tangent := DEPARTURE_SPEED * DEPARTURE_SECONDS
	var a := 3.0 * DEPARTURE_DISTANCE - tangent
	var b := tangent - 2.0 * DEPARTURE_DISTANCE
	var distance := progress * progress * (a + b * progress)
	var rate := progress * (2.0 * a + 3.0 * b * progress) / DEPARTURE_SECONDS
	var axis := station_axis(docked)
	position = docking_position(docked) + axis * distance
	velocity = surface_velocity(docked, position) + axis * rate
	if Ground.is_port(docked):
		var outside := Ground.basis(docked, orbit_time) * Basis(Vector3.UP, PI)
		_set_orientation(outside.get_rotation_quaternion())
	else:
		yaw = PI
		pitch = 0.0
		roll = station_angle(docked)


func toggle_dock_sync() -> bool:
	if cancel_dock_sync():
		_announce("dock_sync_off", "Помощник крена выключен.")
		return true
	if not docking_guidance().sync_available:
		return false
	reset_time_scale()
	dock_roll_sync = target
	_announce("dock_sync_on", "Помощник крена следует вращению дока.")
	return true


func cancel_dock_sync() -> bool:
	if dock_roll_sync < 0:
		return false
	dock_roll_sync = -1
	return true


func gear_status() -> Dictionary:
	var reason := ""
	if docked >= 0:
		reason = "Корабль в наземном порту" if Ground.is_port(docked) else "Корабль в орбитальном доке"
	elif landed:
		reason = "Поднимитесь с поверхности"
	elif jump_seconds_left > 0.0:
		reason = "Идёт зарядка прыжкового привода"
	elif autopilot and (Catalog.is_mine_site(target) or Ground.is_port(target)):
		reason = "Выпуском управляет посадочный автопилот"
	var locked := _gear_locked()
	var caption := "Шасси убрано"
	if locked:
		caption = "Шасси выпущено"
	elif gear_deployed:
		caption = "Выпуск шасси · %d%%" % floori(gear_extension * 100.0)
	elif gear_extension > 0.0:
		caption = "Уборка шасси · %d%%" % floori(gear_extension * 100.0)
	return {
		"progress": gear_extension, "deployed": gear_deployed, "locked": locked,
		"allowed": reason.is_empty(), "reason": reason, "text": caption,
	}


func gear_action() -> bool:
	var status := gear_status()
	if not status.allowed:
		_announce("gear_denied", status.reason)
		return false
	_command_gear(not gear_deployed)
	return true


func _gear_locked() -> bool:
	return gear_deployed and gear_extension == 1.0


func _command_gear(deployed: bool) -> void:
	if gear_deployed == deployed:
		return
	reset_time_scale()
	gear_deployed = deployed
	if deployed:
		_announce("gear_deploy", "Выпускается шасси.")
	else:
		_announce("gear_retract", "Шасси убирается.")


func _advance_gear(delta: float) -> void:
	var stop := 1.0 if gear_deployed else 0.0
	if gear_extension == stop:
		return
	gear_extension = move_toward(gear_extension, stop, delta / GEAR_TRAVEL_SECONDS)
	if is_equal_approx(gear_extension, stop):
		gear_extension = stop
		if gear_deployed:
			_announce("gear_ready", "Шасси выпущено.")
		else:
			_announce("gear_stowed", "Шасси убрано.")


func surface_status() -> Dictionary:
	var status := {
		"ok": false, "near": false, "guide": false, "reason": "Подойдите к твёрдой поверхности",
		"altitude": 0.0, "slope": 0.0, "pad": false, "direction": Vector3.ZERO,
		"gear_ok": _gear_locked(), "awaiting_gear": false,
	}
	if docked >= 0 or landed or not Catalog.is_mine_site(target):
		return status
	var center := target_position(target)
	var rotation := Terrain.spin_basis(target, orbit_time)
	var relative := rotation.transposed() * (position - center)
	var distance := relative.length()
	if distance < 0.01 or distance > float(Catalog.site(target).radius) + FRAME_MARGIN:
		return status
	var pad_height := relative.z - float(Catalog.site(target).pad_offset)
	var over_pad := relative.z > 0.0 and Vector2(relative.x, relative.y).length() <= LANDING_RADIUS
	var direction := Vector3.BACK if over_pad else relative / distance
	var local_normal := Terrain.normal(target, direction)
	var normal := rotation * local_normal
	var ground_radius := Terrain.radius_at(target, direction)
	var ground_point := center + rotation * (direction * ground_radius)
	var altitude := pad_height + Terrain.CONTACT_CLEARANCE if over_pad else distance - ground_radius
	var relative_velocity := velocity - surface_velocity(target, ground_point)
	var speed := relative_velocity.length()
	var alignment := clampf(forward().dot(-normal), -1.0, 1.0)
	var height_ok := altitude >= Terrain.CONTACT_CLEARANCE - 0.1 and altitude <= (11.0 if over_pad else FREE_LANDING_MAX_HEIGHT)
	var speed_ok := speed <= LANDING_SPEED
	var slope_ok := over_pad or Terrain.landable(target, direction)
	var aim_ok := alignment >= cos(deg_to_rad(12.0 if over_pad else LANDING_ANGLE))
	status.near = true
	status.guide = altitude <= LANDING_GUIDE_HEIGHT and jump_seconds_left <= 0.0
	status.altitude = altitude
	status.slope = rad_to_deg(acos(clampf(local_normal.dot(direction), -1.0, 1.0)))
	status.pad = over_pad
	status.direction = direction
	status.ground_point = ground_point
	status.surface_normal = normal
	status.descent_speed = -relative_velocity.dot(normal)
	status.drift_speed = relative_velocity.slide(normal).length()
	status.relative_speed = speed
	status.aim_error_deg = rad_to_deg(acos(alignment))
	status.height_ok = height_ok
	status.speed_ok = speed_ok
	status.slope_ok = slope_ok
	status.aim_ok = aim_ok
	if jump_seconds_left > 0.0:
		status.reason = "Идёт зарядка прыжкового привода"
	elif autopilot and _approach_committed and not over_pad and not _rig_landing_target(target):
		status.reason = "Подойдите к отмеченной площадке"
	elif not height_ok:
		status.reason = "Подойдите к площадке" if over_pad else "Снизьтесь до 4–10 м над поверхностью"
	elif not speed_ok:
		status.reason = "Снизьте скорость относительно поверхности до 4 м/с"
	elif not slope_ok:
		status.reason = "Выберите участок с меньшим уклоном"
	elif not aim_ok:
		status.reason = "Направьте нос к площадке" if over_pad else "Направьте нос к поверхности"
	elif not status.gear_ok:
		status.awaiting_gear = true
		status.reason = "Дождитесь выпуска шасси" if gear_deployed else "Выпустите шасси"
	else:
		status.ok = true
		status.reason = "Можно садиться"
	return status


func landed_offpad() -> bool:
	return landed and not landing_direction.is_equal_approx(Vector3.BACK)


func landed_basis() -> Basis:
	return Terrain.spin_basis(landed_site, orbit_time) * Terrain.basis(landed_site, landing_direction) if landed else Basis.IDENTITY


func surface_deposit() -> Transform3D:
	if not landed:
		return Transform3D(Basis.IDENTITY, position)
	var surface := Transform3D(Terrain.spin_basis(landed_site, orbit_time), target_position(landed_site))
	return surface * Terrain.deposit(landed_site, landing_direction)


func dock_action() -> bool:
	if docked >= 0:
		return _departure_action()
	var status := selected_dock_status()
	if status.get("awaiting_gear", false) and not gear_deployed and not autopilot:
		_command_gear(true)
		return false
	if Catalog.is_port(target) and dock_clearance_action():
		return false
	if not status.ok:
		_announce("dock_denied" if Catalog.is_port(target) else "landing_denied", status.reason)
		return false
	if landed:
		_lift()
	else:
		_arrive(status.get("direction", Vector3.BACK))
	return true


func remote_rig_transform() -> Transform3D:
	var site: int = remote_rig.site_id
	if not remote_rig.active() or Catalog.system_of_site(site) != system_id:
		return Transform3D.IDENTITY
	var surface := Transform3D(Terrain.spin_basis(site, orbit_time), target_position(site))
	return surface * Terrain.deposit(site, remote_rig.direction)


func remote_rig_status() -> Dictionary:
	var active := remote_rig.active()
	var site: int = remote_rig.site_id
	var region := Catalog.system_of_site(site)
	var same_system := active and region == system_id
	var point := remote_rig_transform().origin if same_system else Vector3.ZERO
	var distance := position.distance_to(point) if same_system else -1.0
	var near := false
	if active and landed_site == site:
		var ground := Terrain.contact(site, landing_direction)
		var installation := Terrain.contact(site, remote_rig.direction)
		distance = ground.distance_to(installation)
		near = distance <= REMOTE_RIG_ACCESS_DISTANCE
	var good := str(Catalog.site(site).get("resource", ""))
	return {
		"active": active, "site": site, "system": region, "same_system": same_system,
		"stored": remote_rig.stored, "capacity": UnattendedMining.CAPACITY,
		"working": active and remote_rig.next_epoch >= 0.0,
		"remaining": maxf(0.0, remote_rig.next_epoch - orbit_time), "reserve": mining.reserve_at(site),
		"point": point, "direction": remote_rig.direction, "name": target_name(site),
		"resource": Catalog.resource_name(good), "distance": distance, "near": near,
		"can_deploy": not active and landed and mining.phase == MiningRig.STOWED and mining.reserve_at(landed_site) > 0,
		"can_unload": near and remote_rig.stored > 0 and mining.free_capacity() > 0,
		"can_retrieve": near and remote_rig.stored == 0,
		"can_route": active and not landed and jump_seconds_left <= 0.0 and not _departure_requested,
		"navigating": _rig_landing_target(target),
	}


func leave_remote_rig() -> bool:
	if not remote_rig_status().can_deploy or not remote_rig.deploy(mining, landed_site, landing_direction, orbit_time):
		return false
	_announce("remote_rig_deployed", "Бур оставлен на «%s». Можно взлетать." % target_name(landed_site))
	return true


func unload_remote_rig() -> bool:
	if not remote_rig_status().can_unload:
		return false
	var units := remote_rig.unload(mining, orbit_time)
	if units <= 0:
		return false
	_announce("remote_rig_unloaded", "Из бура выгружено %d ед. сырья." % units)
	return true


func retrieve_remote_rig() -> bool:
	if not remote_rig_status().can_retrieve or not remote_rig.retrieve():
		return false
	_announce("remote_rig_retrieved", "Бур возвращён на борт.")
	return true


func track_remote_rig() -> bool:
	var status := remote_rig_status()
	if not status.can_route:
		return false
	if not status.same_system:
		return plan_route(int(status.system))
	if not select_target(int(status.site)):
		return false
	if docked < 0 and ship.autopilot_fitted:
		set_autopilot(true)
		_rig_approach = true
	_announce("remote_rig_route", "Курс к участку бурения на «%s»." % status.name)
	return true


func mine_action() -> bool:
	if not landed or remote_rig.active():
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
	var earned := 0
	for order in _raw_sale_orders():
		if _sell_market_cargo(order.good, order.quantity):
			earned += int(order.payment)
	if earned == 0:
		return false
	credits += earned
	_announce("ore_sold", "Сырьё продано. Начислено %d кр." % earned)
	return true

func raw_sale_quote() -> int:
	var total := 0
	for order in _raw_sale_orders():
		total += int(order.payment)
	return total


func _raw_sale_orders() -> Array[Dictionary]:
	var orders: Array[Dictionary] = []
	if not station_services_available() or mining.phase != MiningRig.STOWED:
		return orders
	for good: String in Catalog.RESOURCES:
		var quantity := market_limit(good, "sell")
		if quantity > 0:
			orders.append({"good": good, "quantity": quantity, "payment": market.trade_value(docked, good, "sell", quantity)})
	return orders


func customs_status(system := -1) -> Dictionary:
	var region := system_id if system < 0 else system
	var authority := factions.owner(region) if system_known(region) else -1
	var status := customs.status(authority)
	var available := region == system_id and station_services_available() and authority >= 0
	status.merge({
		"authority": authority, "authority_name": FactionFronts.faction_name(authority),
		"medical_allowance": Customs.allowance(authority, "medical"),
		"medical_aboard": mining.cargo_amount("medical"), "available": available,
		"can_pay": available and credits > 0 and int(status.debt) > 0,
	})
	return status


func customs_pay() -> bool:
	var status := customs_status()
	return status.can_pay and _apply_service_result(customs.pay(int(status.authority), credits))


func _inspect_docked_cargo() -> void:
	var authority := factions.owner(system_id)
	for good: String in Economy.ALLOWANCES:
		var excess := Customs.excess(authority, good, mining.cargo_amount(good))
		if excess > 0:
			_confiscate_market_cargo(authority, good, excess, false)


func _confiscate_market_cargo(authority: int, good: String, quantity: int, hidden: bool) -> bool:
	if not mining.remove_cargo(good, quantity):
		return false
	var result := customs.record(authority, docked, good, quantity, orbit_time)
	if hidden and result.ok:
		result.event = "market_contact_seized"
		result.message = "Тайная сделка сорвана. " + str(result.message)
	if not _apply_service_result(result):
		mining.insert_cargo(good, quantity)
		return false
	career.note_customs_violation(authority)
	return true


func market_profile(port: int) -> Dictionary:
	var region := Catalog.system_of_site(port)
	if region < 0:
		return {}
	var control := factions.system_state(region)
	var settlements := 0
	for local_port: int in Catalog.ports_for(region):
		if station_operational(local_port):
			settlements += 1
	return Economy.profile(port, int(control.owner), settlements, int(control.pressure), control.stage == "war")


func market_contact() -> Dictionary:
	return Economy.contact(docked, factions.owner(system_id)) if station_services_available() else {}


func market_quote(good: String, side: String, quantity: int, hidden := false) -> Dictionary:
	var local := market_profile(docked)
	var owner := int(local.get("owner", -1))
	var allowance := Customs.allowance(owner, good)
	var listed := Economy.GOODS.has(good) and side in ["buy", "sell"] and not local.is_empty()
	if listed:
		listed = market_contact().get("goods", []).has(good) if hidden else allowance != 0
	var unit := market.trade_value(docked, good, side, 1, local, hidden) if listed else 0
	var stock := market.stock(docked, good, hidden)
	var owned := mining.cargo_amount(good)
	var capacity := Economy.MAX_HIDDEN_STOCK if hidden else Economy.MAX_STOCK
	var valid_quantity := quantity > 0 and quantity <= mini(ship.cargo_capacity(), capacity)
	var cost := market.trade_value(docked, good, side, quantity, local, hidden) if listed and valid_quantity else 0
	var intercepted_units := 0
	if hidden and allowance >= 0 and valid_quantity:
		if side == "buy":
			intercepted_units = maxi(0, quantity - maxi(0, allowance - owned))
		else:
			intercepted_units = mini(quantity, maxi(0, owned - allowance))
	var risk := mini(92, 13 + int(local.get("risk", 0)) * 6 + intercepted_units * 13) if intercepted_units > 0 else 0
	var reason := ""
	if not station_services_available():
		reason = "Рынок доступен после швартовки"
	elif not listed:
		reason = "Контакт не торгует этим товаром" if hidden else "Запрещено правилами порта" if allowance == 0 else "Этот товар недоступен"
	elif not valid_quantity or unit == 0:
		reason = "Выберите товар и количество"
	elif mining.phase != MiningRig.STOWED:
		reason = "Сначала верните добывающий модуль"
	elif side == "buy":
		if not hidden and allowance >= 0 and owned + quantity > allowance:
			reason = "Таможенный лимит на борту · %d ед." % allowance
		elif stock < quantity:
			reason = "У продавца недостаточно товара" if hidden else "В порту недостаточно товара"
		elif mining.free_capacity() < quantity:
			reason = "В трюме мало места"
		elif credits < cost:
			reason = "Недостаточно кредитов"
	elif owned < quantity:
		reason = "В трюме недостаточно товара"
	elif quantity > capacity - stock:
		reason = "Не хватает места на складе"
	elif credits < -cost:
		reason = "Недостаточно кредитов для утилизации"
	var balance_change := -cost if side == "buy" else cost
	if reason.is_empty() and balance_change > 1000000000 - credits:
		reason = "Достигнут лимит кредитов"
	return {"ok": reason.is_empty(), "listed": listed, "cost": cost, "unit": unit, "stock": stock,
		"owned": owned, "reason": reason, "risk": risk, "seizable": intercepted_units, "allowance": allowance}


func market_limit(good: String, side: String, hidden := false) -> int:
	if not station_services_available() or not market_quote(good, side, 1, hidden).listed:
		return 0
	var stock := market.stock(docked, good, hidden)
	var capacity := Economy.MAX_HIDDEN_STOCK if hidden else Economy.MAX_STOCK
	var upper := mini(mining.cargo_amount(good), capacity - stock) if side == "sell" else mini(stock, mining.free_capacity())
	var lower := 0
	while lower < upper:
		var count := ceili((lower + upper) * 0.5)
		if market_quote(good, side, count, hidden).ok:
			lower = count
		else:
			upper = count - 1
	return lower


func freight_status(port: int) -> Array[Dictionary]:
	return freight.status_for(port, orbit_time)


func passenger_board() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	if not station_services_available():
		return offers
	var current := passengers.status(orbit_time)
	for port: int in local_ports():
		if port != docked:
			offers.append(Passengers.offer(docked, port))
	var interstellar := _nearest_interstellar_port()
	if interstellar >= 0:
		offers.append(Passengers.offer(docked, interstellar))
	for offer in offers:
		offer.available = not current.active and current.debt == 0 and offer.seats <= current.capacity
	return offers


func passenger_status() -> Dictionary:
	var status := passengers.status(orbit_time)
	var at_berth := station_services_available()
	var at_origin: bool = status.active and docked == status.origin and not status.overdue
	var at_destination: bool = status.active and docked == status.destination and not status.overdue
	status.canceling = at_berth and at_origin
	status.can_discharge = at_berth and status.active and (status.overdue or at_origin or at_destination)
	status.can_repay = at_berth and status.debt > 0 and credits > 0
	var route_port := int(status.destination) if status.active else -1
	if status.active and status.overdue:
		if at_berth:
			route_port = docked
		else:
			route_port = _nearest_passenger_berth()
	status.route_port = route_port
	status.can_follow = route_port >= 0 and route_port != docked and jump_seconds_left <= 0.0 and not _departure_requested
	status.reason = "Свободные места в каюте"
	if status.active and status.overdue:
		status.reason = "Срок истёк. Высадите пассажиров в любом действующем порту."
	elif at_destination:
		status.reason = "Можно высадить пассажиров и получить остаток оплаты."
	elif status.active:
		status.reason = "Доставьте пассажиров в порт «%s» к сроку." % target_name(status.destination)
	elif status.debt > 0:
		status.reason = "Погасите остаток аванса перед новым рейсом."
	return status


func _nearest_passenger_berth() -> int:
	var selected := -1
	var distance := INF
	for port: int in local_ports():
		var separation := position.distance_squared_to(docking_position(port))
		if separation < distance:
			distance = separation
			selected = port
	return selected if selected >= 0 else _nearest_interstellar_port()


func _nearest_interstellar_port() -> int:
	var selected := -1
	var best_cost := 1000000
	for system: int in known_systems():
		var ports := Catalog.ports_for(system)
		if ports.is_empty():
			continue
		var cost := jump_tariff(system_id, system)
		if cost <= 0 or cost >= best_cost:
			continue
		for port: int in ports:
			if station_operational(port):
				selected = port
				best_cost = cost
				break
	return selected


func passenger_accept(destination: int) -> bool:
	for offer in passenger_board():
		if int(offer.destination) == destination and offer.available:
			return _apply_service_result(passengers.begin(docked, destination, orbit_time))
	return false


func passenger_discharge() -> bool:
	if not passenger_status().can_discharge:
		return false
	return _apply_service_result(passengers.discharge(docked, orbit_time, credits))


func passenger_repay() -> bool:
	if not passenger_status().can_repay:
		return false
	return _apply_service_result(passengers.repay(credits))


func passenger_follow() -> bool:
	var status := passenger_status()
	if not status.can_follow:
		return false
	var port := int(status.route_port)
	var destination := Catalog.system_of_site(port)
	var selected := select_target(port) if destination == system_id else plan_route(destination)
	if selected:
		_announce("passenger_course", "Курс пассажирского рейса на «%s»." % target_name(port))
	return selected


func _apply_service_result(result: Dictionary) -> bool:
	if result.is_empty() or not result.ok:
		return false
	credits += int(result.credits)
	_announce(result.event, result.message)
	return true


func career_status() -> Dictionary:
	var result := career.status()
	var dispatch := career.dispatch_status(orbit_time)
	var service := station_services_available()
	var destination := int(dispatch.destination)
	result.dispatch = dispatch
	result.offer = career.dispatch_offer(factions.owner(system_id), docked, _default_port(docked), orbit_time) if service else {}
	result.can_submit = service and dispatch.active and docked == destination
	result.can_follow = dispatch.active and docked != destination and jump_seconds_left <= 0.0 and not _departure_requested
	return result


func career_dispatch_action() -> bool:
	if not station_services_available():
		return false
	var dispatch := career.dispatch_status(orbit_time)
	if dispatch.active:
		return _apply_service_result(career.finish_dispatch(docked, orbit_time))
	return _apply_service_result(career.accept_dispatch(factions.owner(system_id), docked, _default_port(docked), orbit_time))


func career_follow() -> bool:
	var status := career_status()
	if not status.can_follow:
		return false
	var destination := int(status.dispatch.destination)
	var sector := Catalog.system_of_site(destination)
	if not (select_target(destination) if sector == system_id else plan_route(sector)):
		return false
	_announce("career_dispatch_course", "Курс служебной депеши на «%s»." % target_name(destination))
	return true


func story_status() -> Dictionary:
	var berth := docked if station_services_available() else -1
	var result := story.status(berth, deliveries, cartography.surveyed_sites())
	result.merge(story.snapshot())
	result.can_follow = result.can_follow and not _departure_requested and jump_seconds_left <= 0.0
	return result


func story_action(action: String) -> bool:
	if not station_services_available():
		return false
	var receipt := story.perform(action, docked, deliveries, cartography.surveyed_sites(), orbit_time)
	if receipt.is_empty():
		return false
	credits += int(receipt.credits)
	career.note_story_result(receipt.trust)
	_record_story_news(news, story.snapshot(), str(receipt.action))
	_announce("story_" + str(receipt.action), receipt.message)
	return true


func story_follow() -> bool:
	var status := story_status()
	if not status.can_follow:
		return false
	var destination := int(status.target)
	var sector := Catalog.system_of_site(destination)
	if not (select_target(destination) if sector == system_id else plan_route(sector)):
		return false
	_announce("story_course", "Курс «Слепой поправки» на «%s»." % target_name(destination))
	return true


func news_archive(sector := -1, limit := 12) -> Array[Dictionary]:
	var area := system_id if sector < 0 else sector
	if not system_known(area):
		return []
	return news.archive(area, orbit_time, limit)


func news_edition(sector: int, published_at: float) -> Dictionary:
	var area := system_id if sector < 0 else sector
	return news.edition(area, published_at, orbit_time) if system_known(area) else {}


func news_article(id: String) -> Dictionary:
	return news.article(id, orbit_time)


static func _record_story_news(archive: SectorNews, branch: Dictionary, command: String) -> void:
	match command:
		BranchingStory.BRIEF:
			if float(branch.briefed_at) >= 0.0:
				archive.record("story-brief", "story_brief", Catalog.HOME_SYSTEM, branch.briefed_at,
					"Диспетчеры обнаружили расхождение маячных координат у Сланца. Пилотов просят проверить расчёт курса.", "", "story")
		BranchingStory.REGISTRY, BranchingStory.MIRROR:
			if float(branch.chosen_at) >= 0.0:
				var title: String = BranchingStory.BRANCHES[branch.branch].name
				archive.record("story-choice", "story_choice", Catalog.HOME_SYSTEM, branch.chosen_at,
					"Для проверки выбрали план «%s». Диспетчеры ожидают подтверждения." % title, "story-brief", "story")
		BranchingStory.SUBMIT:
			if float(branch.settled_at) >= 0.0:
				var mirror: bool = branch.branch == BranchingStory.MIRROR
				var region := Catalog.VELAR_SYSTEM if mirror else Catalog.HOME_SYSTEM
				var headline := "story_mirror" if mirror else "story_registry"
				archive.record("story-result", headline, region, branch.settled_at,
					BranchingStory.BRANCHES[branch.branch].ending, "story-choice", "story")


func _record_front_news(result: Dictionary, epoch: float) -> void:
	news.record(result.news_id, result.event, result.news_system, epoch, result.message, result.news_related)


func crew_status() -> Dictionary:
	var status := crew.status(orbit_time)
	status.engineer = crew.active_role("engineer")
	status.navigator = crew.active_role("navigator")
	var at_berth := station_services_available()
	for member: Dictionary in status.members:
		member.can_dismiss = at_berth and member.arrears == 0
		member.can_pay = at_berth and member.arrears > 0 and credits > 0
	return status


func crew_candidates() -> Array[Dictionary]:
	if not station_services_available():
		return []
	var status := crew.status(orbit_time)
	var offers := Crew.candidates(docked)
	for offer: Dictionary in offers:
		var hired: bool = status.members.any(func(member: Dictionary) -> bool: return member.id == offer.id)
		offer.available = not hired and status.count < status.capacity and credits >= offer.fee
	return offers


func crew_hire(id: int) -> bool:
	if not station_services_available():
		return false
	return _apply_service_result(crew.hire(id, docked, orbit_time, credits))


func crew_dismiss(id: int) -> bool:
	if not station_services_available():
		return false
	return _apply_service_result(crew.dismiss(id))


func crew_pay(id: int) -> bool:
	if not station_services_available():
		return false
	return _apply_service_result(crew.pay(id, credits))


func shipyard_available() -> bool:
	return station_services_available() and docked in SHIPYARD_PORTS


func shipyard_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	if shipyard_available():
		for id in ShipSystems.hull_ids():
			offers.append(shipyard_offer(id))
	return offers


func shipyard_offer(id: String) -> Dictionary:
	var offer := ShipSystems.profile(id)
	if offer.is_empty():
		return offer
	offer.installed = ship.hull_id == id
	offer.trade_in = ship.trade_in_value()
	offer.net_cost = int(offer.price) - int(offer.trade_in)
	offer.cargo_capacity = ship.cargo_capacity_for(id)
	offer.reason = ""
	if not shipyard_available():
		offer.reason = "Обмен доступен на действующей верфи"
	elif offer.installed:
		offer.reason = "Текущий корпус"
	elif mining.phase != MiningRig.STOWED or mining.ore_hold > offer.cargo_capacity:
		offer.reason = "Освободите место в трюме, чтобы груз поместился"
	elif offer.net_cost > credits:
		offer.reason = "Недостаточно кредитов"
	offer.available = offer.reason.is_empty()
	return offer


func shipyard_swap(id: String) -> bool:
	var offer := shipyard_offer(id)
	if offer.is_empty() or not offer.available or not ship.swap_hull(id):
		return false
	credits -= int(offer.net_cost)
	mining.cargo_capacity = ship.cargo_capacity()
	_announce("ship_exchange", "Обмен завершён. Корабль %s." % offer.name)
	return true


func market_trade(good: String, side: String, quantity: int, hidden := false) -> bool:
	var quote := market_quote(good, side, quantity, hidden)
	if not quote.ok:
		return false
	if hidden and int(quote.risk) > 0:
		var roll := posmod(hash([docked, good, side, quantity, int(quote.stock), floori(orbit_time / 30.0)]), 100)
		if roll < int(quote.risk):
			return _intercept_market_contact(good, side, int(quote.seizable))
	if side == "buy":
		if not mining.insert_cargo(good, quantity):
			return false
		if not market.change_stock(docked, good, -quantity, hidden):
			mining.remove_cargo(good, quantity)
			return false
		credits -= int(quote.cost)
	else:
		if not _sell_market_cargo(good, quantity, hidden):
			return false
		credits += int(quote.cost)
	var message: String
	var name := Economy.good_name(good)
	if side == "buy":
		message = "Куплено %d ед. товара «%s» за %d кр." % [quantity, name, quote.cost] if quote.cost > 0 else 			"Принято на вывоз: %s (%d ед.). Выплата %d кр." % [name, quantity, -quote.cost]
	else:
		message = "Продано %d ед. товара «%s» за %d кр." % [quantity, name, quote.cost] if quote.cost > 0 else 			"Принято на утилизацию: %s (%d ед.). Оплата %d кр." % [name, quantity, -quote.cost]
	_announce(("market_contact_" if hidden else "market_") + side, message)
	return true


func _intercept_market_contact(good: String, side: String, quantity: int) -> bool:
	var authority := factions.owner(system_id)
	if side == "sell":
		return _confiscate_market_cargo(authority, good, quantity, true)
	var result := customs.record(authority, docked, good, quantity, orbit_time)
	if not result.ok:
		return false
	market.change_stock(docked, good, -quantity, true)
	result.event = "market_contact_seized"
	result.message = "Тайная сделка сорвана. " + str(result.message)
	_apply_service_result(result)
	career.note_customs_violation(authority)
	return true


func _sell_market_cargo(good: String, quantity: int, hidden := false) -> bool:
	if not mining.remove_cargo(good, quantity):
		return false
	if market.change_stock(docked, good, quantity, hidden):
		return true
	mining.insert_cargo(good, quantity)
	return false


func refuel_unit_price() -> int:
	return Catalog.refuel_price(docked)


func repair_unit_price() -> int:
	var base := Economy.repair_price(docked)
	return maxi(1, base - 1) if base > 0 and crew.active_role("engineer") else base


func traffic_contacts() -> Array[Dictionary]:
	var contacts := Traffic.contacts(self)
	contacts.append_array(patrol.contacts(self))
	var order := convoy_order.status(self)
	if order.active and order.local and order.kind == "intercept":
		for contact in contacts:
			if contact.id == order.id:
				contact.hull = order.enemy_hull
				break
	contacts.append_array(ambient.contacts(self))
	return contacts


func combat_beams() -> Array[Dictionary]:
	if docked >= 0 or landed or jump_seconds_left > 0.0:
		return []
	var beams := patrol.beams()
	beams.append_array(convoy_order.beams())
	beams.append_array(ambient.beams(self))
	return beams


func ambient_status() -> Dictionary:
	var status := ambient.status(self)
	status.fire_visible = status.hostile and _manual_speed_available() and status.distance <= 520.0
	return status


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
	if not ship.autopilot_fitted:
		_announce("autopilot_missing", "Автопилот снят. Наводитесь на отметку конвоя вручную.")
		return false
	reset_time_scale()
	set_autopilot(false)
	_release_speed_hold(false)
	convoy_course = true
	_announce("convoy_order_course", "Проложен курс к конвою. «%s»." % status.name)
	return true


func _stop_convoy_course() -> void:
	if convoy_course:
		convoy_course = false
		throttle = 0.0


func project_action() -> bool:
	if _departure_requested:
		return false
	var status := frontier_status()
	if not status.can_act:
		if status.route_system >= 0 and status.route_system != system_id:
			return plan_jump(status.route_system)
		if status.route_port >= 0 and select_target(status.route_port):
			if docked < 0 and not landed and ship.autopilot_fitted:
				set_autopilot(true)
			_announce("expedition_course", "Курс к порту заказчика.")
			return true
		if not status.can_follow:
			return false
		if not ship.autopilot_fitted:
			_announce("autopilot_missing", "Автопилот снят. Наводитесь на отметку экспедиции вручную.")
			return false
		set_autopilot(false)
		_release_speed_hold(false)
		project_course = true
		_announce("expedition_course", "Курс к цели экспедиции.")
		return true
	var result := expedition.act(self)
	if not result.get("ok", false):
		return false
	var region := int(status.system)
	var prefix := "expedition-%d-" % region
	match str(result.event):
		"expedition_accepted": news.record(prefix + "opened", result.event, region, orbit_time, result.message)
		"expedition_report": news.record(prefix + "survey", result.event, region, orbit_time, result.message, prefix + "opened")
		"expedition_complete": news.record(prefix + "commission", result.event, region, orbit_time, result.message, prefix + "survey")
	project_course = false
	credits += int(result.get("credits", 0))
	if result.has("commissioned"):
		factions.commission(result.commissioned, result.owner, orbit_time)
		freight.activate_frontier(result.commissioned, orbit_time)
	if result.has("planned_system"):
		plan_jump(result.planned_system)
	_announce(result.event, result.message)
	return true


func combat_equipment_status() -> Dictionary:
	return {
		"weapon": combat.weapon, "name": combat.profile().name, "shield_fitted": combat.shield_fitted,
		"ecm_fitted": combat.ecm_fitted, "focus_owned": combat.focus_owned, "damaged": combat.damaged,
		"station": station_services_available(),
	}


func select_weapon(id: String) -> bool:
	if not station_services_available() or not combat.select_weapon(id):
		return false
	_announce("combat_weapon_selected", "Активный лазер · %s." % combat.profile().name)
	return true


func combat_status() -> Dictionary:
	var incoming := combat.projectile_status()
	var active := not incoming.is_empty()
	var parked := docked >= 0 or landed or jump_seconds_left > 0.0
	var local_contact := patrol.in_danger(self) or convoy_order.in_danger(self) or ambient.in_danger(self)
	var reason := combat.ecm_denial(position, orbit_time)
	if parked:
		reason = "Помехи доступны в открытом полёте"
	return {
		"visible": not parked and (local_contact or active or combat.heat > 0.01 or combat.shield_fitted),
		"heat": combat.heat, "shield": combat.shield,
		"shield_max": CombatSystems.SHIELD_CAPACITY if combat.shield_fitted else 0.0,
		"weapon": combat.weapon, "name": combat.profile().name, "damaged": combat.damaged,
		"projectile": active, "projectile_distance": position.distance_to(incoming.position) if active else -1.0,
		"ecm_fitted": combat.ecm_fitted, "ecm_ok": reason.is_empty(), "ecm_reason": reason,
		"position": incoming.get("position", Vector3.ZERO), "velocity": incoming.get("velocity", Vector3.ZERO),
		"fire_blocked": combat.fire_denial(orbit_time),
	}


func use_ecm() -> bool:
	var status := combat_status()
	if not status.ecm_ok or not combat.use_ecm(position, orbit_time):
		return false
	reset_time_scale()
	_announce("combat_ecm", "Радиопомехи сорвали подлёт ракеты.")
	return true


func fire_status() -> Dictionary:
	var bonus := float(combat.profile().range_bonus)
	var channel := _fire_channel()
	var status := {}
	match channel:
		"convoy": status = convoy_order.fire_status(self, bonus)
		"patrol": status = patrol.fire_status(self, bonus)
		"ambient": status = ambient.fire_status(self, bonus)
	status.channel = channel
	if status.ok:
		var reason := combat.fire_denial(orbit_time)
		if not reason.is_empty():
			status.ok = false
			status.reason = reason
	return status


func _fire_channel() -> String:
	if convoy_status().fire_visible:
		return "convoy"
	return "patrol" if patrol.in_danger(self) else "ambient"


func patrol_action() -> bool:
	if _departure_requested:
		return false
	var status := patrol_status()
	if not status.available:
		return false
	if docked >= 0:
		if patrol.phase == Patrol.RETURN:
			var payment := patrol.finish(docked)
			if payment <= 0:
				return false
			credits += payment
			career.note_patrol_report(docked)
			_announce("patrol_paid", "Доклад принят. Награда %d кр." % payment)
		else:
			if not patrol.accept(docked):
				return false
			career.note_patrol_accept(factions.owner(system_id), docked)
			_announce("patrol_accepted", "Дозор принят. После старта выберите «К сигналу».")
	elif patrol.phase == Patrol.RETURN:
		select_target(patrol.origin)
		if ship.autopilot_fitted:
			set_autopilot(true)
	else:
		if not ship.autopilot_fitted:
			_announce("autopilot_missing", "Автопилот снят. Наводитесь на сигнал дозора вручную.")
			return false
		var follow := not patrol_course
		set_autopilot(false)
		if follow:
			_release_speed_hold(false)
		patrol_course = follow
		if not follow:
			throttle = 0.0
	return true


func fire_action() -> bool:
	var status := fire_status()
	if not status.ok:
		return false
	var bonus := float(combat.profile().range_bonus)
	var channel: String = status.channel
	var shot := {}
	match channel:
		"convoy": shot = convoy_order.fire(self, bonus)
		"patrol": shot = patrol.fire(self, bonus)
		"ambient": shot = ambient.fire(self, bonus)
	if shot.get("ok", false):
		combat.record_fire(orbit_time)
		reset_time_scale()
	match channel:
		"convoy": _apply_convoy_result(shot)
		"patrol": _apply_patrol_result(shot)
		"ambient": _apply_ambient_result(shot)
	return shot.get("ok", false)


func _apply_ambient_result(result: Dictionary) -> void:
	var event := str(result.get("event", ""))
	if event.is_empty():
		return
	if event == "ambient_victory":
		career.note_ambient_victory()
	if event == "ambient_engaged":
		reset_time_scale()
		if not patrol.in_danger(self) and not convoy_order.in_danger(self):
			combat.reset_salvos()
	if result.has("damage"):
		_apply_hostile_beam(event, result)
	else:
		_announce(event, str(result.get("message", "")))


func _apply_patrol_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	var event: String = result.get("event", "")
	if event.is_empty():
		return
	if event in ["patrol_engaged", "patrol_victory", "patrol_retreat"]:
		reset_time_scale()
		if event == "patrol_engaged":
			combat.reset_salvos()
			_stop_convoy_course()
		elif event == "patrol_victory":
			career.note_patrol_victory()
		if patrol_course:
			patrol_course = false
			throttle = 0.0
	if result.get("damage", 0.0) > 0.0:
		_apply_hostile_beam(event, result)
	else:
		_announce(event, str(result.get("message", "")))


func _apply_convoy_result(result: Dictionary) -> void:
	var event: String = result.get("event", "")
	if event.is_empty():
		return
	if event in ["convoy_order_escorted", "convoy_order_paid", "convoy_order_failed"]:
		_stop_convoy_course()
	if result.has("front_news"):
		_record_front_news(result.front_news, orbit_time)
	if event in ["convoy_order_paid", "convoy_order_failed"]:
		career.note_convoy_result(convoy_order.faction, convoy_order.target_faction, convoy_order.kind, event == "convoy_order_paid")
	credits += int(result.get("credits", 0))
	if result.get("damage", 0.0) > 0.0:
		_apply_hostile_beam(event, result)
	else:
		_announce(event, str(result.get("message", "")))


func _apply_hostile_beam(event: String, result: Dictionary) -> void:
	var amount := float(result.damage)
	var remainder := combat.absorb_hit(amount, orbit_time)
	if remainder > 0.0:
		ship.apply_damage(remainder)
	var message := str(result.get("message", ""))
	if remainder < amount:
		message = "Щит поглотил %.0f ед. урона." % (amount - remainder)
		if remainder > 0.0:
			message += " Корпус получил %.0f ед." % remainder
	var source: Variant = result.get("source")
	if source is Vector3 and combat.incoming_shot(source, position, system_id, orbit_time):
		reset_time_scale()
		_announce("combat_missile", message + " Противник выпустил ракету.")
	else:
		_announce(event, message)


func _advance_combat_projectile(previous_ship: Vector3, delta: float) -> void:
	var sweep := combat.advance_projectile(orbit_time, delta)
	if sweep.is_empty():
		return
	if int(sweep.system) != system_id or not combat_line_clear(sweep.from, sweep.to):
		combat.clear_projectile()
		return
	var relative_start: Vector3 = sweep.from - previous_ship
	var relative_end: Vector3 = sweep.to - position
	var nearest := Geometry3D.get_closest_point_to_segment(Vector3.ZERO, relative_start, relative_end)
	if nearest.length_squared() > MISSILE_HIT_RADIUS * MISSILE_HIT_RADIUS:
		return
	combat.clear_projectile()
	var remainder := combat.absorb_hit(MISSILE_DAMAGE, orbit_time)
	if remainder <= 0.0:
		_announce("combat_missile_hit", "Щит принял удар ракеты.")
		return
	ship.apply_damage(remainder)
	var module := combat.damage_module()
	var message := "Ракета повредила корпус. Прочность %.0f%%." % ship.hull
	if module == "focus":
		message += " Оптика лазера «Нить» отключена."
	elif module == "ecm":
		message += " Блок радиопомех отключён."
	_announce("combat_missile_hit", message)


func combat_line_clear(start: Vector3, finish: Vector3) -> bool:
	var steps := maxi(1, ceili(start.distance_to(finish) / 8.0))
	for step in range(1, steps + 1):
		if _blocked(start.lerp(finish, float(step) / steps)):
			return false
	return true


func local_fragments() -> Array[Dictionary]:
	var fragments: Array[Dictionary] = []
	for site: int in orbital_mining.fragment_sites():
		if Catalog.system_of_site(site) == system_id:
			fragments.append(orbital_mining.fragment_state(site, orbit_time))
	return fragments


func orbital_mining_beam() -> Dictionary:
	if _mining_beam.is_empty() or orbit_time >= float(_mining_beam.until):
		return {}
	return {
		"start": _mining_beam.start, "end": _mining_beam.end,
		"remaining": float(_mining_beam.until) - orbit_time,
	}


func orbital_mining_status() -> Dictionary:
	var valid_site := OrbitalMining.supports_site(target) and Catalog.system_of_site(target) == system_id
	var open_flight := docked < 0 and not landed and jump_seconds_left <= 0.0
	var body := Catalog.site(target)
	var center := target_position(target)
	var ray := center - position
	var radius := float(body.get("radius", 0.0))
	var standoff := maxf(0.0, ray.length() - radius * Terrain.MAX_RADIUS_FACTOR)
	var fragment := orbital_mining.fragment_state(target, orbit_time) if valid_site else {}
	var has_fragment := not fragment.is_empty()
	var distance := position.distance_to(fragment.position) if has_fragment else standoff
	var relative_speed := velocity.distance_to(fragment.velocity) if has_fragment else speed_relative_to(target)
	var ready_in := maxf(0.0, orbital_mining.ready_at - orbit_time)
	var common := ""
	if not open_flight or scooping:
		common = "Добыча доступна в свободном полёте"
	elif not valid_site:
		common = "Выберите астероид"
	elif patrol.in_danger(self) or convoy_order.in_danger(self) or ambient.in_danger(self):
		common = "Выйдите из боевого контакта"
	var fire_reason := common
	if fire_reason.is_empty():
		if not ship.mining_laser:
			fire_reason = "Установите горный лазер в порту"
		elif has_fragment:
			fire_reason = "Сначала подберите отделённый обломок"
		elif mining.reserve_at(target) <= 0:
			fire_reason = "Месторождение истощено"
		elif ship.fuel < MINING_PULSE_FUEL:
			fire_reason = "Нужно %.1f ед. реактивного топлива" % MINING_PULSE_FUEL
		elif ready_in > 0.0:
			fire_reason = "Лазер остывает"
		elif standoff > MINING_PULSE_RANGE:
			fire_reason = "Подойдите к породе на %d м" % int(MINING_PULSE_RANGE)
		elif not _mining_aimed(ray, radius):
			fire_reason = "Наведите нос на астероид"
	var collect_reason := common
	if collect_reason.is_empty():
		if not ship.fragment_collector:
			collect_reason = "Установите сборщик обломков в порту"
		elif not has_fragment:
			collect_reason = "Рядом нет отделённого обломка"
		elif mining.free_capacity() == 0:
			collect_reason = "Трюм заполнен"
		elif distance > FRAGMENT_COLLECT_RANGE:
			collect_reason = "Подойдите к обломку на %d м" % int(FRAGMENT_COLLECT_RANGE)
		elif relative_speed > FRAGMENT_COLLECT_SPEED:
			collect_reason = "Снизьте скорость к обломку до %d м/с" % int(FRAGMENT_COLLECT_SPEED)
	return {
		"visible": open_flight and valid_site and (standoff <= 500.0 or has_fragment),
		"installed": ship.mining_laser, "collector": ship.fragment_collector, "site": target,
		"resource": Catalog.resource_name(str(body.get("resource", ""))), "fragment": has_fragment,
		"distance": distance, "relative_speed": relative_speed, "ready_in": ready_in,
		"position": fragment.get("position", Vector3.ZERO),
		"fire_ok": fire_reason.is_empty(), "collect_ok": collect_reason.is_empty(),
		"fire_reason": fire_reason, "collect_reason": collect_reason,
	}


func _mining_aimed(relative: Vector3, radius: float) -> bool:
	var aim := forward()
	var reach := relative.dot(aim)
	return reach > 0.0 and (relative - aim * reach).length_squared() <= pow(radius * 0.78, 2)


func _mining_impact(site: int) -> Vector3:
	var center := target_position(site)
	var to_center := center - position
	var axis := forward()
	var reach := to_center.dot(axis)
	var envelope := float(Catalog.site(site).radius) * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE
	var miss := (to_center - axis * reach).length_squared()
	var before := maxf(0.0, reach - sqrt(maxf(0.0, envelope * envelope - miss)) - 0.1)
	var high := reach
	if not _inside_hull(position + axis * high, site):
		return Vector3.INF
	for _iteration in range(12):
		var mid := (before + high) * 0.5
		if _inside_hull(position + axis * mid, site):
			high = mid
		else:
			before = mid
	if high > MINING_PULSE_RANGE or not combat_line_clear(position, position + axis * maxf(0.0, before - 0.1)):
		return Vector3.INF
	return position + axis * high


func fire_mining_pulse() -> bool:
	var status := orbital_mining_status()
	if not status.fire_ok:
		_announce("mining_pulse_denied", str(status.fire_reason))
		return false
	var hit := _mining_impact(target)
	if not hit.is_finite():
		_announce("mining_pulse_denied", "Горный луч не достиг открытой породы.")
		return false
	var direction := (hit - target_position(target)).normalized()
	if not orbital_mining.spawn(mining, target, direction, orbit_time):
		return false
	reset_time_scale()
	ship.fuel -= MINING_PULSE_FUEL
	_mining_beam = {"start": position, "end": hit, "until": orbit_time + MINING_BEAM_DURATION}
	_announce("mining_pulse", "Обломок отделён. Снизьте скорость и подберите его.")
	return true


func collect_fragment() -> bool:
	var status := orbital_mining_status()
	if not status.collect_ok:
		_announce("fragment_collect_denied", str(status.collect_reason))
		return false
	if not combat_line_clear(position, status.position):
		_announce("fragment_collect_denied", "Между кораблём и обломком препятствие.")
		return false
	if not orbital_mining.collect(mining, target):
		return false
	reset_time_scale()
	_announce("fragment_collected", "Обломок в трюме · %s." % str(status.resource))
	return true


func service_offer(action: String) -> Dictionary:
	var unit_price := repair_unit_price() if action == "repair" else refuel_unit_price()
	var offer := combat.service_offer(action, credits) if action.begins_with("combat_") else ship.service_offer(action, unit_price, credits)
	offer.allowed = offer.allowed and station_services_available()
	return offer


func service_action(action: String) -> bool:
	if action == "autopilot":
		return autopilot_equipment_action()
	if action in ["berth_pay", "berth_defer", "civic_donate"]:
		return _port_account_action(action)
	if not service_offer(action).allowed:
		return false
	var unit_price := repair_unit_price() if action == "repair" else refuel_unit_price()
	var paid := combat.buy(action, credits) if action.begins_with("combat_") else ship.buy(action, unit_price, credits)
	if paid <= 0:
		return false
	credits -= paid
	match action:
		"refuel":
			_announce("service_refuel", "Реактивный бак заправлен. Списано %d кр." % paid)
		"jump_refuel":
			_announce("service_jump_refuel", "Прыжковый запас пополнен. Списано %d кр." % paid)
		"tank":
			_announce("service_tank", "Ёмкость обоих топливных контуров увеличена до %d ед." % int(ship.capacity()))
		"eco":
			_announce("service_eco", "Экономичный привод установлен.")
		"repair":
			_announce("service_repair", "Корпус отремонтирован. Списано %d кр." % paid)
		"cargo":
			mining.cargo_capacity = ship.cargo_capacity()
			_announce("service_cargo", "Вместимость трюма увеличена до %d ед." % mining.cargo_capacity)
		"heat_shield":
			_announce("service_heat_shield", "Теплозащита установлена. Списано %d кр." % paid)
		"mining_laser":
			_announce("service_mining_laser", "Горный лазер установлен. Списано %d кр." % paid)
		"fragment_collector":
			_announce("service_fragment_collector", "Сборщик обломков установлен. Списано %d кр." % paid)
		"hydrogen_scoop":
			_announce("service_hydrogen_scoop", "Сборщик водорода установлен. Списано %d кр." % paid)
		"fuel_pump":
			_announce("service_fuel_pump", "Топливный насос установлен. Списано %d кр." % paid)
		"range_drive":
			_announce("service_range_drive", "Дальний привод «Вектор» установлен. Списано %d кр." % paid)
		"combat_shield":
			_announce("service_combat_shield", "Генератор щита установлен. Списано %d кр." % paid)
		"combat_ecm":
			_announce("service_combat_ecm", "Блок радиопомех установлен. Списано %d кр." % paid)
		"combat_focus":
			_announce("service_combat_focus", "Лазер «Нить» установлен. Списано %d кр." % paid)
		"combat_repair":
			_announce("service_combat_repair", "Выведенный из строя модуль восстановлен. Списано %d кр." % paid)
	return true


func _port_account_action(action: String) -> bool:
	if not station_services_available():
		return false
	match action:
		"berth_pay":
			var payment := _port_account.pay(docked, orbit_time, credits)
			if payment <= 0:
				return false
			credits -= payment
			_announce("berth_payment", "В счёт порта «%s» внесено %d кр." % [target_name(docked), payment])
			return true
		"berth_defer":
			if not _port_account.defer(docked, orbit_time, credits):
				return false
			_announce("berth_permit", "Порт разрешил выход в долг. Счёт остаётся к оплате в этом порту.")
			return true
		"civic_donate":
			if not _civic.donate(docked, orbit_time, credits, deliveries):
				return false
			credits -= CivicReputation.COST
			_announce("civic_donation", "Фонд помощи экипажам получил %d кр. Гражданская репутация: %d." % [CivicReputation.COST, _civic.reputation(deliveries)])
			return true
	return false


func fuel_equipment_status() -> Dictionary:
	return {
		"scoop": ship.hydrogen_scoop, "pump": ship.fuel_pump, "mode": ship.pump_mode,
		"station": station_services_available(),
		"can_set_mode": ship.fuel_pump and not _departure_requested and not scooping and jump_seconds_left <= 0.0,
		"scoop_resale": ShipSystems.SCOOP_RESALE, "pump_resale": ShipSystems.FUEL_PUMP_RESALE,
		"canisters": mining.cargo_amount(Economy.HYDROGEN),
	}


func remove_fuel_module(module: String) -> bool:
	if not station_services_available():
		return false
	var refund := ship.remove_fuel_module(module)
	if refund <= 0:
		return false
	credits += refund
	var name := "Сборщик водорода" if module == "hydrogen_scoop" else "Топливный насос"
	_announce("fuel_module_removed", "%s снят. Получено %d кр." % [name, refund])
	return true


func set_fuel_pump_mode(mode: String) -> bool:
	if not fuel_equipment_status().can_set_mode or ship.pump_mode == mode or not ship.set_pump_mode(mode):
		return false
	var label := "Реактивный бак" if mode == ShipSystems.PUMP_REACTION else "Прыжковый запас"
	_announce("fuel_pump_mode", "Автоперелив выключен." if mode == ShipSystems.PUMP_OFF else "Автоперелив · %s." % label)
	return true


func _advance_fuel_pump(previous_epoch: float) -> void:
	if not ship.fuel_pump or ship.pump_mode == ShipSystems.PUMP_OFF or scooping or mining.phase != MiningRig.STOWED:
		return
	# The simulated clock is the timer, so loading cannot repeat a passed second.
	if floori(previous_epoch + 0.000001) >= floori(orbit_time + 0.000001):
		return
	var reaction := ship.pump_mode == ShipSystems.PUMP_REACTION
	var capacity := ship.capacity() if reaction else ship.jump_capacity()
	var fuel := ship.fuel if reaction else ship.jump_fuel
	var threshold := capacity * FUEL_PUMP_THRESHOLD
	if not reaction and jump_target >= 0:
		threshold = maxf(threshold, jump_tariff(system_id, jump_target))
	var units := ShipSystems.HYDROGEN_UNITS_PER_CANISTER
	if fuel >= threshold or capacity - fuel < units:
		return
	if _transfer_hydrogen(ship.pump_mode, 1, units) > 0.0:
		var tank := "реактивный бак" if reaction else "прыжковый запас"
		_announce("fuel_pump_transfer", "Насос перелил одну канистру в %s." % tank)


func fuel_transfer_offer(destination: String) -> Dictionary:
	if destination not in ["reaction", "jump"]:
		return {"ok": false, "reason": "Выберите контур", "canisters": 0, "added": 0.0}
	if _departure_requested:
		return {"ok": false, "reason": "Дождитесь выхода из дока", "canisters": 0, "added": 0.0}
	if jump_seconds_left > 0.0 or scooping or mining.phase != MiningRig.STOWED:
		var reason := "Остановите сбор" if scooping else "Дождитесь завершения зарядки или верните добывающий модуль"
		return {"ok": false, "reason": reason, "canisters": 0, "added": 0.0}
	var missing := ship.capacity() - ship.fuel if destination == "reaction" else ship.jump_capacity() - ship.jump_fuel
	var available := mining.cargo_amount(Economy.HYDROGEN)
	var units := ShipSystems.HYDROGEN_UNITS_PER_CANISTER
	var canisters := mini(available, ceili(missing / units))
	var reason := ""
	if missing <= 0.0:
		reason = "Запас полон"
	elif available <= 0:
		reason = "В трюме нет водорода"
	return {"ok": canisters > 0, "reason": reason, "canisters": canisters, "added": minf(missing, canisters * units)}


func fuel_transfer(destination: String) -> bool:
	var offer := fuel_transfer_offer(destination)
	if not offer.ok:
		return false
	var amount := _transfer_hydrogen(destination, int(offer.canisters), float(offer.added))
	if amount <= 0.0:
		return false
	var circuit := "Реактивный бак" if destination == "reaction" else "Прыжковый запас"
	_announce("fuel_transfer", "%s пополнен на %.1f ед. из трюма." % [circuit, amount])
	return true


func _transfer_hydrogen(destination: String, canisters: int, units: float) -> float:
	if not mining.remove_cargo(Economy.HYDROGEN, canisters):
		return 0.0
	var added := ship.add_fuel(units) if destination == ShipSystems.PUMP_REACTION else ship.add_jump_fuel(units)
	if added <= 0.0:
		mining.insert_cargo(Economy.HYDROGEN, canisters)
	return added


func fuel_cargo_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if docked >= 0 or landed or scooping or jump_seconds_left > 0.0 or mining.phase != MiningRig.STOWED:
		return options
	for good: String in Economy.GOODS:
		var quantity := mining.cargo_amount(good)
		if quantity > 0:
			options.append({"good": good, "name": Economy.good_name(good), "quantity": quantity})
	return options


func jettison_status(good: String) -> Dictionary:
	var reason := _cargo_flight_reason()
	var direction := Vector3.ZERO
	if reason.is_empty():
		if mining.cargo_amount(good) <= 0:
			reason = "В трюме нет выбранного товара."
		elif not _cargo_pods.can_eject():
			reason = "Слишком много выброшенных контейнеров. Подберите один из них."
		else:
			direction = _cargo_release_direction()
			if direction.is_zero_approx():
				reason = "Слишком близко к препятствиям для выброса."
	return {"ok": reason.is_empty(), "reason": reason, "direction": direction}


func jettison_cargo(good: String) -> bool:
	var offer := jettison_status(good)
	if not offer.ok:
		_announce("cargo_jettison_denied", offer.reason)
		return false
	var direction: Vector3 = offer.direction
	var origin := position + direction * CargoPods.EJECT_CLEARANCE
	var drift := velocity + direction * CargoPods.EJECT_SPEED
	if not _cargo_pods.eject(mining, system_id, good, origin, drift, orbit_time, MAX_SAVED_SPEED + CargoPods.EJECT_SPEED):
		_announce("cargo_jettison_denied", "Не удалось выпустить контейнер.")
		return false
	reset_time_scale()
	_announce("cargo_jettisoned", "Контейнер выпущен · %s. В трюме освободилось место." % Economy.good_name(good))
	return true


func local_cargo_pods() -> Array[Dictionary]:
	var pods := _cargo_pods.local(system_id, orbit_time)
	pods.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_distance := position.distance_squared_to(left.position)
		var right_distance := position.distance_squared_to(right.position)
		return int(left.id) < int(right.id) if left_distance == right_distance else left_distance < right_distance)
	return pods


func cargo_pod_status(id := -1) -> Dictionary:
	var pods := local_cargo_pods()
	var preferred := _cargo_pods.tracked if id == -1 else id
	var index := _cargo_pod_index(pods, preferred)
	if index == -1 and id == -1 and not pods.is_empty():
		index = 0
	var pod: Dictionary = {} if index < 0 else pods[index]
	var active := index >= 0
	var contact: Vector3 = pod.get("position", Vector3.ZERO)
	var drift: Vector3 = pod.get("velocity", Vector3.ZERO)
	var distance := position.distance_to(contact) if active else -1.0
	var relative_speed := velocity.distance_to(drift) if active else -1.0
	var flight_reason := _cargo_flight_reason()
	var targetable := active and flight_reason.is_empty()
	var reason := flight_reason
	if reason.is_empty():
		if not active:
			reason = "В этой системе нет доступного контейнера."
		elif not ship.fragment_collector:
			reason = "Установите сборщик обломков в порту."
		elif mining.free_capacity() == 0:
			reason = "Трюм заполнен."
		elif distance > FRAGMENT_COLLECT_RANGE:
			reason = "Подойдите к контейнеру на %d м." % int(FRAGMENT_COLLECT_RANGE)
		elif relative_speed > FRAGMENT_COLLECT_SPEED:
			reason = "Снизьте скорость к контейнеру до %d м/с." % int(FRAGMENT_COLLECT_SPEED)
	return {"active": active, "id": int(pod.get("id", -1)), "count": pods.size(), "position": contact, "velocity": drift,
		"good": str(pod.get("good", "")), "name": Economy.good_name(str(pod.good)) if active else "",
		"distance": distance, "relative_speed": relative_speed, "remaining": float(pod.get("remaining", 0.0)),
		"tracking": active and _cargo_pods.tracked == int(pod.id), "targetable": targetable,
		"collectible": reason.is_empty(), "reason": reason}


func target_cargo_pod(id := -1) -> bool:
	var status := cargo_pod_status(id)
	if not status.targetable:
		_announce("cargo_pod_target_denied", _cargo_flight_reason() if status.active else "Контейнер недоступен.")
		return false
	if id == -1 and status.tracking and int(status.count) > 1:
		var pods := local_cargo_pods()
		var index := _cargo_pod_index(pods, int(status.id))
		status = cargo_pod_status(int(pods[(index + 1) % pods.size()].id))
	_cargo_pods.tracked = int(status.id)
	_announce("cargo_pod_targeted", "Контейнер отмечен · %s." % str(status.name))
	return true


func collect_cargo_pod(id := -1) -> bool:
	var status := cargo_pod_status(id)
	if not status.collectible:
		_announce("cargo_pod_collect_denied", status.reason)
		return false
	if not combat_line_clear(position, status.position):
		_announce("cargo_pod_collect_denied", "Между кораблём и контейнером препятствие.")
		return false
	if not _cargo_pods.collect(mining, int(status.id)):
		_announce("cargo_pod_collect_denied", "Не удалось принять контейнер в трюм.")
		return false
	reset_time_scale()
	_announce("cargo_pod_collected", "Контейнер принят · %s." % str(status.name))
	return true


func _cargo_flight_reason() -> String:
	if docked >= 0 or landed or jump_seconds_left > 0.0 or mining.phase != MiningRig.STOWED:
		return "Контейнеры доступны в свободном полёте."
	if scooping:
		return "Сначала остановите сбор водорода."
	return ""


func _cargo_release_direction() -> Vector3:
	var axes := attitude()
	for direction: Vector3 in [axes.x, -axes.x, axes.y, -axes.y, axes.z, -axes.z]:
		if combat_line_clear(position, position + direction * CargoPods.EJECT_CLEARANCE):
			return direction
	return Vector3.ZERO


static func _cargo_pod_index(pods: Array[Dictionary], id: int) -> int:
	for index in range(pods.size()):
		if int(pods[index].id) == id:
			return index
	return -1


func is_scoop_site(site: int) -> bool:
	return Catalog.system_of_site(site) == system_id and (Catalog.is_star(site) or Catalog.is_gas_giant(site))


func scoop_active_at(site: int) -> bool:
	return scooping and _scoop_body == site


func _scoop_site() -> int:
	if scooping:
		return _scoop_body
	if is_scoop_site(target):
		return target
	var giant := Catalog.gas_giant_for(system_id)
	if giant >= 0:
		var near_radius := float(Catalog.site(giant).radius) + GAS_SCOOP_MAX_ALTITUDE + 120.0
		if position.distance_squared_to(target_position(giant)) <= near_radius * near_radius:
			return giant
	return _nearest_star()


func scoop_status() -> Dictionary:
	var body := _scoop_site()
	var gas := Catalog.is_gas_giant(body)
	var radius := float(Catalog.site(body).radius)
	var distance := position.distance_to(target_position(body))
	var inner := radius + GAS_SCOOP_MIN_ALTITUDE if gas else Catalog.SCOOP_INNER
	var outer := radius + GAS_SCOOP_MAX_ALTITUDE if gas else Catalog.SCOOP_OUTER
	var max_speed := GAS_SCOOP_SPEED if gas else Catalog.SCOOP_SPEED
	var near := distance <= outer + (120.0 if gas else 180.0)
	var speed := speed_relative_to(body)
	var free := mining.free_capacity()
	var reason := ""
	if docked >= 0 or landed:
		reason = "Сбор доступен в полёте у звезды или газового гиганта"
	elif jump_seconds_left > 0.0:
		reason = "Идёт зарядка прыжкового привода"
	elif not ship.hydrogen_scoop:
		reason = "Установите сборщик водорода в порту"
	elif distance < inner:
		reason = "Поднимитесь в верхний слой атмосферы" if gas else "Отойдите от звезды до зоны сбора"
	elif distance > outer:
		reason = "Войдите в верхний слой атмосферы" if gas else "Подойдите к отмеченной зоне сбора"
	elif maxf(star_heat, entry_heat) >= HEAT_SCOOP_LIMIT:
		reason = "Корпус перегрет. Выйдите из зоны сбора и охладите корабль"
	elif speed > max_speed:
		reason = "Снизьте относительную скорость до %d м/с" % int(max_speed)
	elif free <= 0:
		reason = "Трюм заполнен. Для сбора нужна свободная ячейка"
	return {
		"ok": reason.is_empty(), "reason": "Можно собирать водород" if reason.is_empty() else reason,
		"near": near, "installed": ship.hydrogen_scoop, "body": body, "kind": "gas" if gas else "star", "distance": distance, "altitude": distance - radius,
		"inner": inner, "outer": outer, "max_speed": max_speed, "relative_speed": speed,
		"progress": _scoop_progress, "scooping": scooping, "free": free,
		"cargo_units": mining.cargo_amount(Economy.HYDROGEN),
	}


func thermal_status() -> Dictionary:
	var star := _nearest_star()
	var distance := position.distance_to(target_position(star))
	var in_flight := docked < 0 and not landed
	var level := "normal"
	if star_heat >= HEAT_DAMAGE_LIMIT:
		level = "critical"
	elif star_heat >= 65.0:
		level = "hot"
	elif star_heat >= 35.0:
		level = "warm"
	return {
		"heat": star_heat, "body": star, "distance": distance, "level": level,
		"visible": in_flight and (distance <= Catalog.SCOOP_OUTER or star_heat >= 1.0),
		"danger": in_flight and distance < Catalog.SCOOP_INNER,
		"blocked": star_heat >= HEAT_SCOOP_LIMIT,
		"cooling": star_heat - _heat_target() > 0.1,
	}


func atmosphere_status() -> Dictionary:
	var air := Atmosphere.sample(self, position, velocity)
	var in_flight := docked < 0 and not landed and jump_seconds_left <= 0.0
	var equilibrium := _entry_heat_target(air) if in_flight else 0.0
	var altitude: float = air.altitude
	if air.near and Catalog.is_mine_site(air.site):
		var from_center := position - target_position(air.site)
		if not from_center.is_zero_approx():
			altitude = from_center.length() - Terrain.radius_at(air.site, Terrain.spin_basis(air.site, orbit_time).transposed() * from_center.normalized())
	air.merge({
		"name": target_name(air.site), "heat": entry_heat,
		"visible": in_flight and (air.near or entry_heat >= 1.0),
		"heating": equilibrium > entry_heat + 0.1,
		"cooling": equilibrium < entry_heat - 0.1,
		"shielded": ship.heat_shield,
		"heat_reduction": ShipSystems.HEAT_SHIELD_REDUCTION if ship.heat_shield else 0,
		"level": _entry_heat_level(), "safe_speed": Atmosphere.SAFE_ENTRY_SPEED,
	})
	air.altitude = altitude
	return air


func _entry_heat_level() -> String:
	if entry_heat >= HEAT_DAMAGE_LIMIT:
		return "critical"
	if entry_heat >= 65.0:
		return "hot"
	if entry_heat >= 35.0:
		return "warm"
	return "normal"


func _atmosphere_step(delta: float) -> void:
	var air := Atmosphere.sample(self, position + velocity * delta * 0.5, velocity)
	var current: int = air.site if air.inside else -1
	if _entry_site != current:
		_entry_site = current
		if current >= 0:
			_announce("atmosphere_enter", "Вход в атмосферу планеты «%s»." % target_name(current))
		else:
			_announce("atmosphere_exit", "Корабль вышел из атмосферы.")
	if air.inside:
		velocity = Atmosphere.drag(velocity, air.drift, air.density, delta)
	_update_entry_heat(delta, _entry_heat_target(air), true)


func _entry_heat_target(air: Dictionary) -> float:
	return Atmosphere.heat_target(air.relative_speed, air.density) * ship.entry_heat_factor()


func _update_entry_heat(delta: float, equilibrium := 0.0, airborne := false) -> void:
	if not airborne:
		_entry_site = -1
	if entry_heat == 0.0 and equilibrium == 0.0:
		return
	var previous := entry_heat
	var response := 0.90 if equilibrium > entry_heat else 0.30
	entry_heat = clampf(lerpf(entry_heat, equilibrium, 1.0 - exp(-response * delta)), 0.0, 100.0)
	if entry_heat < 0.05:
		entry_heat = 0.0
	if airborne and entry_heat >= HEAT_DAMAGE_LIMIT:
		var severity := inverse_lerp(HEAT_DAMAGE_LIMIT, 100.0, entry_heat)
		ship.apply_damage(lerpf(0.7, 8.0, severity) * delta)
		if previous < HEAT_DAMAGE_LIMIT:
			_announce("atmosphere_damage", "Критический нагрев при входе. Корпус повреждается.")


func _nearest_star() -> int:
	var nearest := Catalog.star_for(system_id)
	var distance := INF
	for id: int in Catalog.stars_for(system_id):
		var separation := position.distance_squared_to(target_position(id))
		if separation < distance:
			distance = separation
			nearest = id
	return nearest


func _heat_target() -> float:
	# Each illuminated star heats the ship. The collector adds heat only while running.
	var total := 0.0
	for id: int in Catalog.stars_for(system_id):
		var distance := position.distance_to(target_position(id))
		var proximity := maxf(0.0, Catalog.SCOOP_OUTER - distance) / (Catalog.SCOOP_OUTER - Catalog.SCOOP_INNER)
		var output: float = Catalog.site(id).get("stellar_heat", Catalog.stellar_heat(system_id))
		total += 82.0 * output * proximity * proximity + (12.0 if scoop_active_at(id) else 0.0)
	return total


func _update_star_heat(delta: float) -> void:
	var exposed := docked < 0 and not landed and jump_seconds_left <= 0.0
	var equilibrium := _heat_target() if exposed else 0.0
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
		_stop_scoop("scoop_stop", "Сбор водорода остановлен.")
		return true
	var status := scoop_status()
	if not status.ok:
		_announce("scoop_denied", status.reason)
		return false
	reset_time_scale()
	_clear_rendezvous()
	_scoop_body = status.body
	_scoop_progress = 0.0
	scooping = true
	_announce("scoop_start", "Идёт сбор водорода в трюм.")
	return true


func _stop_scoop(event: String, message: String) -> void:
	_reset_scoop()
	_announce(event, message)


func _reset_scoop() -> void:
	scooping = false
	_scoop_body = -1
	_scoop_progress = 0.0


func _collect_fuel(delta: float) -> void:
	if not scooping:
		return
	var status := scoop_status()
	if not status.ok:
		_stop_scoop("scoop_stop", status.reason)
		return
	var heat_fraction := clampf(inverse_lerp(HEAT_SCOOP_SLOW, HEAT_SCOOP_LIMIT, maxf(star_heat, entry_heat)), 0.0, 1.0)
	var rate := GAS_SCOOP_RATE if status.kind == "gas" else SCOOP_RATE
	_scoop_progress += rate * lerpf(1.0, 0.45, heat_fraction) * delta / ShipSystems.HYDROGEN_UNITS_PER_CANISTER
	if _scoop_progress < 1.0:
		return
	if not mining.insert_cargo(Economy.HYDROGEN, 1):
		_stop_scoop("scoop_stop", "Не удалось поместить водород в трюм.")
		return
	_scoop_progress -= 1.0
	if mining.free_capacity() <= 0:
		_stop_scoop("scoop_full", "Трюм заполнен. Перелейте водород через меню «Топливо».")
	else:
		_announce("scoop_canister", "В трюме %d канистр водорода." % mining.cargo_amount(Economy.HYDROGEN))


func jump_tariff(origin: int, destination: int) -> int:
	if _jump_transit_duration > 0.0 and origin == system_id and destination == jump_target:
		return _jump_paid_fare
	var reserve: float = ship.jump_fuel if origin == system_id else ship.jump_capacity()
	return ship.jump_tariff(Catalog.jump_cost(origin, destination), mining.ore_hold, reserve)


func jump_travel_seconds(origin: int, destination: int) -> float:
	if _jump_transit_duration > 0.0 and origin == system_id and destination == jump_target:
		return _jump_transit_duration
	return ship.jump_duration(Catalog.jump_distance(origin, destination), mining.ore_hold)


func jump_drive_status() -> Dictionary:
	return {
		"id": ship.drive_kind, "name": ship.drive_name(), "have_range": ship.range_drive,
		"can_select": station_services_available() and ship.range_drive,
		"load": mining.ore_hold, "capacity": ship.cargo_capacity(), "jump_capacity": ship.jump_capacity(),
		"mass_t": ship.flight_mass(mining.ore_hold), "dry_mass_t": ship.dry_mass(),
		"range_ly": _generated_jump_range(ship.jump_fuel), "max_range_ly": _generated_jump_range(ship.jump_capacity()),
	}


func _generated_jump_range(reserve: float) -> float:
	var base := ship.base_jump_budget(reserve, mining.ore_hold, reserve)
	return maxf(0.0, (base - Catalog.GENERATED_JUMP_ENTRY) / Catalog.GENERATED_JUMP_PER_LIGHT_YEAR)


func select_jump_drive(id: String) -> bool:
	if not station_services_available() or ship.drive_kind == id or not ship.select_drive(id):
		return false
	var route_adjusted := false
	if not _jump_route.is_empty():
		var path: Array[int] = [system_id]
		path.append_array(_jump_route)
		var known := _known_systems(expedition, cartography)
		if not GalacticRoute.valid_path(path, known, ship.jump_capacity(), jump_tariff):
			var replacement := route_preview(_jump_route.back())
			_jump_route.clear()
			if replacement.available:
				_jump_route.assign(replacement.path.slice(1))
			jump_target = -1 if _jump_route.is_empty() else _jump_route.front()
			route_adjusted = true
	var note := " Маршрут обновлён." if route_adjusted and jump_target >= 0 else ""
	if route_adjusted and jump_target < 0:
		note = " Выберите новый межзвёздный курс."
	_announce("jump_drive_selected", "Активный привод · %s.%s" % [ship.drive_name(), note])
	return true


func jump_progress_status() -> Dictionary:
	var active := jump_seconds_left > 0.0
	var transit := _jump_transit_duration > 0.0
	var duration := _jump_transit_duration if transit else jump_travel_seconds(system_id, jump_target)
	var time_left := jump_seconds_left if transit else maxf(0.0, jump_seconds_left - JUMP_TRANSIT_WALL)
	var phase_length := JUMP_TRANSIT_WALL if transit else _jump_charge_total - JUMP_TRANSIT_WALL
	var fare := _jump_paid_fare if transit else jump_tariff(system_id, jump_target)
	return {
		"phase": ("transit" if transit else "charge") if active else "idle", "active": active, "is_transit": transit,
		"remaining": time_left, "duration": duration, "fare": fare, "destination": jump_target,
		"progress": clampf(1.0 - time_left / phase_length, 0.0, 1.0) if active else 0.0,
		"arrival_epoch": orbit_time + duration + (0.0 if transit else time_left),
	}


func plan_jump(destination: int) -> bool:
	if jump_seconds_left > 0.0 or not system_known(destination) or jump_tariff(system_id, destination) == 0:
		return false
	_jump_route.clear()
	jump_target = destination
	_announce("jump_planned", "Межзвёздный курс. «%s»." % Catalog.system(destination).name)
	return true


func route_preview(goal: int) -> Dictionary:
	var known := _known_systems(expedition, cartography)
	var capacity := ship.jump_capacity()
	var reachable_first_leg := _plot_route(goal, known, capacity, ship.jump_fuel)
	if reachable_first_leg.available or ship.jump_fuel >= capacity:
		return reachable_first_leg
	return _plot_route(goal, known, capacity, capacity)


func _plot_route(goal: int, known: Array[int], capacity: float, first_reserve: float) -> Dictionary:
	var payload: int = mining.ore_hold
	var tariff := func(origin: int, destination: int) -> int:
		var reserve := first_reserve if origin == system_id else capacity
		return ship.jump_tariff(Catalog.jump_cost(origin, destination), payload, reserve)
	var nearby := func(origin: int, budget: float) -> Array[int]:
		var reserve := first_reserve if origin == system_id else capacity
		return Catalog.jump_candidates(origin, ship.base_jump_budget(budget, payload, reserve))
	return GalacticRoute.plan(system_id, goal, known, capacity, first_reserve, tariff, jump_travel_seconds, nearby)


func planned_route() -> Dictionary:
	var path: Array[int] = []
	if jump_target >= 0:
		path.append(system_id)
		if _jump_route.is_empty():
			path.append(jump_target)
		else:
			path.append_array(_jump_route)
	return GalacticRoute.describe(path, jump_tariff, jump_travel_seconds)


func plan_route(goal: int) -> bool:
	if jump_seconds_left > 0.0:
		return false
	var plot := route_preview(goal)
	if not plot.available:
		return false
	_jump_route.assign(plot.path.slice(1))
	jump_target = plot.next
	_announce("jump_planned", "Маршрут до «%s». Ближайший прыжок в «%s»." % [
		Catalog.system(goal).name, Catalog.system(jump_target).name])
	return true


func cancel_route() -> bool:
	if jump_seconds_left > 0.0 or jump_target < 0:
		return false
	_jump_route.clear()
	jump_target = -1
	_announce("route_canceled", "Межзвёздный маршрут снят.")
	return true


static func _known_systems(progress: RefCounted, atlas: RefCounted) -> Array[int]:
	var systems: Array[int] = []
	for id in range(Catalog.AUTHORED_SYSTEM_COUNT):
		if progress.known(id):
			systems.append(id)
	systems.append_array(atlas.discovered_systems())
	return systems


func jump_status(destination: int) -> Dictionary:
	var cost := jump_tariff(system_id, destination) if system_known(destination) else 0
	var reason := ""
	var duration := jump_travel_seconds(system_id, destination)
	if _jump_transit_duration > 0.0:
		reason = "Корабль в гиперпространстве"
	elif cost == 0:
		reason = "Выберите другую звёздную систему"
	elif docked >= 0 or landed:
		reason = "Выйдите в открытый космос"
	elif autopilot or scooping:
		reason = "Отключите автопилот и сбор топлива"
	elif Atmosphere.sample(self, position, velocity).inside:
		reason = "Выйдите из атмосферы"
	elif patrol.in_danger(self) or ambient.in_danger(self) or not combat.projectile_status().is_empty():
		reason = "Выйдите из зоны боя"
	elif convoy_order.in_danger(self):
		reason = "Отойдите от конвоя"
	elif speed() > JUMP_SPEED:
		reason = "Снизьте скорость до %d м/с" % int(JUMP_SPEED)
	elif cost > ship.jump_capacity():
		reason = "При такой массе топливо на переход не поместится в бак."
	elif ship.jump_fuel < cost:
		reason = "Нужно %d ед. в прыжковом запасе" % cost
	elif orbit_time + duration + JUMP_CHARGE > SAVE_CLOCK_LIMIT:
		reason = "Прыжок выходит за пределы календаря"
	else:
		for id: int in local_targets():
			var clearance := Catalog.SCOOP_OUTER if Catalog.is_star(id) else float(Catalog.site(id).radius) + JUMP_CLEARANCE
			if position.distance_squared_to(target_position(id)) <= clearance * clearance:
				reason = "Отойдите от объекта «%s»" % target_name(id)
				break
			if jump_seconds_left <= 0.0 and Catalog.is_star(id) and Orbit.period(id) > 0.0 and not _clear_during_charge(id, clearance):
				reason = "Звезда «%s» приблизится во время зарядки. Отойдите дальше." % target_name(id)
				break
	return {"ok": reason.is_empty(), "reason": "Можно зарядить прыжковый привод" if reason.is_empty() else reason, "cost": cost, "duration": duration}


func _clear_during_charge(star: int, clearance: float) -> bool:
	var duration := NAVIGATOR_JUMP_CHARGE if crew.active_role("navigator") else JUMP_CHARGE
	var stop := speed() / JUMP_BRAKE
	# The continuous estimate allows for the discrete braking step in flight.
	var limit := clearance + 0.5 * speed() * MAX_FLIGHT_STEP + 0.02
	var previous := position - target_position(star)
	for part in range(1, 7):
		var moment := duration * part / 6.0
		var braking_time := minf(moment, stop)
		var displacement := velocity * (braking_time * (1.0 - 0.5 * braking_time / stop)) if stop > 0.0 else Vector3.ZERO
		var moving_center: Vector3 = Orbit.sample(star, orbit_time + moment).position
		var offset := position + displacement - moving_center
		var closest := Geometry3D.get_closest_point_to_segment(Vector3.ZERO, previous, offset)
		if closest.length_squared() <= limit * limit:
			return false
		previous = offset
	return true


func start_jump() -> bool:
	if jump_seconds_left > 0.0:
		return false
	var status := jump_status(jump_target)
	if not status.ok:
		_announce("jump_denied", status.reason)
		return false
	reset_time_scale()
	ambient.interrupt()
	_cargo_pods.tracked = -1
	_release_speed_hold(false)
	cancel_dock_sync()
	dock_access.clear()
	patrol_course = false
	project_course = false
	_stop_convoy_course()
	_clear_orbit_maneuver()
	_clear_rendezvous()
	throttle = 0.0
	boost = false
	_command_gear(false)
	_jump_charge_total = NAVIGATOR_JUMP_CHARGE if crew.active_role("navigator") else JUMP_CHARGE
	jump_seconds_left = _jump_charge_total
	_announce("jump_charging", "Прыжковый привод заряжается.")
	return true


func cancel_jump() -> bool:
	if jump_seconds_left <= 0.0 or _jump_transit_duration > 0.0:
		return false
	jump_seconds_left = 0.0
	_announce("jump_canceled", "Прыжок отменён. Топливо сохранено.")
	return true


func _charge_jump(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, JUMP_BRAKE * delta)
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
	if jump_seconds_left > JUMP_TRANSIT_WALL + 0.000001:
		return
	jump_seconds_left = minf(jump_seconds_left, JUMP_TRANSIT_WALL)
	_jump_transit_duration = float(status.duration)
	_jump_paid_fare = int(status.cost)
	_jump_paid_pricing = MASS_JUMP_PRICING
	ship.jump_fuel -= _jump_paid_fare
	velocity = Vector3.ZERO
	_announce("jump_committed", "Переход в гиперпространство · %d ед. топлива." % _jump_paid_fare)


func _advance_jump_transit(delta: float) -> void:
	var remaining := jump_seconds_left - delta
	if remaining > 0.000001:
		jump_seconds_left = remaining
		return
	_advance_hyperspace_calendar(_jump_transit_duration)
	jump_seconds_left = 0.0
	_jump_transit_duration = 0.0
	_jump_paid_fare = 0
	_jump_paid_pricing = MASS_JUMP_PRICING
	_finish_jump_arrival()


func _finish_jump_arrival() -> void:
	dock_access.clear()
	system_id = jump_target
	_mining_beam.clear()
	frame.reset_on_arrival()
	if not _jump_route.is_empty() and _jump_route.front() == system_id:
		_jump_route.pop_front()
	else:
		_jump_route.clear()
	jump_target = -1 if _jump_route.is_empty() else _jump_route[0]
	var destination := Catalog.system(system_id)
	var arrival := int(destination.get("arrival_target", destination.arrival_port))
	if not Catalog.is_generated_system(system_id) and not station_operational(arrival):
		arrival = int(destination.survey_sites[0])
	target = arrival
	if contract_stage == 1 and Catalog.system_of_site(contract_destination) == system_id and _site_available(contract_destination, expedition) and (not contract_route_id.is_empty() or contract_origin >= Catalog.PRE_EXPANSION_DESTINATION_COUNT):
		target = contract_destination
	position = target_gate(arrival) + Vector3.BACK * ARRIVAL_OFFSET
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	var message := "Прыжок завершён. Система «%s»." % Catalog.system(system_id).name
	if jump_target >= 0:
		message += " Далее «%s»." % Catalog.system(jump_target).name
	_announce("jump_complete", message)


func _arrive(direction := Vector3.BACK) -> void:
	combat.clear_projectile()
	ambient.interrupt()
	_release_speed_hold(false)
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
	var rotation := Terrain.spin_basis(landed_site, orbit_time)
	position = target_position(landed_site) + rotation * Terrain.contact(landed_site, landing_direction)
	velocity = surface_velocity(landed_site, position) if Terrain.spin_rate(landed_site) > 0.0 else Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	throttle = 0.0
	boost = false
	_reset_scoop()


func _lift() -> void:
	var origin := landed_site
	var ground_basis := landed_basis()
	var away := ground_basis.z
	var inherited_velocity := surface_velocity(origin, position)
	var offpad := landed_offpad()
	var rotates := Terrain.spin_rate(origin) > 0.0
	reset_time_scale()
	landed_site = -1
	landing_direction = Vector3.ZERO
	_command_gear(false)
	if rotates:
		_set_orientation((ground_basis * Basis(Vector3.UP, PI)).get_rotation_quaternion())
	else:
		yaw = atan2(-away.x, -away.z) if offpad else PI
		pitch = clampf(asin(clampf(away.y, -1.0, 1.0)), -MAX_PITCH, MAX_PITCH)
	if offpad or rotates:
		position += away * 0.35
	velocity = inherited_velocity + away * 9.0
	target = _departure_target(_default_port(origin))
	_announce("lift", "Взлёт с поверхности. «%s»." % target_name(origin))


func _launch() -> void:
	var origin := docked
	_port_account.leave()
	reset_time_scale()
	position = docking_position(origin) + station_axis(origin) * DEPARTURE_DISTANCE
	if Ground.is_port(origin):
		var outside := Ground.basis(origin, orbit_time) * Basis(Vector3.UP, PI)
		_set_orientation(outside.get_rotation_quaternion())
		_command_gear(false)
	else:
		yaw = PI
		pitch = 0.0
		if _departure_requested:
			roll = station_angle(origin)
	throttle = 0.0
	velocity = surface_velocity(origin, position) + station_axis(origin) * DEPARTURE_SPEED
	target = _departure_target(_default_port(origin))
	docked = -1
	_departure_requested = false
	_departure_seconds = -1.0
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
	ambient.interrupt()
	_release_speed_hold(false)
	dock_access.settle(orbit_time)
	gear_deployed = Ground.is_port(docked)
	gear_extension = 1.0 if gear_deployed else 0.0
	set_autopilot(false)
	throttle = 0.0
	boost = false
	_reset_scoop()
	_hold_docked_pose()
	var arrival := "Посадка завершена. Порт" if Ground.is_port(docked) else "Швартовка завершена. Станция"
	var message := "%s «%s»." % [arrival, target_name(docked)]
	var paid := _port_account.arrive(docked, orbit_time, credits)
	if PortAccount.TARIFFS.has(docked):
		credits -= paid
		message += " Сбор %d кр., списано %d кр." % [PortAccount.TARIFFS[docked].x, paid]
	_announce("dock", message)
	_inspect_docked_cargo()


func _hold_docked_pose() -> void:
	position = docking_position(docked)
	velocity = target_velocity(docked) if Ground.is_port(docked) else Vector3.ZERO
	if Ground.is_port(docked):
		_set_orientation(Ground.basis(docked, orbit_time).get_rotation_quaternion())
	else:
		roll = station_angle(docked)
		yaw = 0.0
		pitch = 0.0


func update(delta: float, steer: Vector2, bank: float, boost_requested: bool, brake: bool, translation := Vector3.ZERO) -> void:
	if time_paused or not is_finite(delta) or delta <= 0.0:
		return
	var traverse := translation.limit_length() if translation.is_finite() else Vector3.ZERO
	var manual_input := steer.length_squared() > 0.04 or absf(bank) > 0.12 or boost_requested or brake or not traverse.is_zero_approx()
	if manual_input or (time_scale > 1 and not time_status().allowed):
		reset_time_scale()
	if (docked >= 0 and not _departure_requested) or landed:
		if time_scale > TIME_SCALES[-1]:
			_advance_fast_wait(delta)
		else:
			_step(delta * time_scale, steer, bank, boost_requested, brake, manual_input, traverse)
		return
	var steps := maxi(1, ceili(delta * time_scale / MAX_FLIGHT_STEP - 0.000001))
	var interval := delta / steps
	for step in range(steps):
		if time_scale > 1 and not time_status().allowed:
			reset_time_scale()
		_step(interval * time_scale, steer, bank, boost_requested, brake, manual_input, traverse)


func _fast_wait_stop_epoch() -> float:
	var deadline := career.next_event_time()
	var booking := passengers.status(orbit_time)
	if booking.active and not booking.overdue:
		deadline = minf(deadline, float(booking.deadline))
	return minf(SAVE_CLOCK_LIMIT, deadline - FAST_WAIT_DEADLINE_MARGIN)


func _advance_fast_wait(real_delta: float) -> void:
	var stop_epoch := _fast_wait_stop_epoch()
	var end_epoch := minf(orbit_time + real_delta * time_scale, stop_epoch)
	while orbit_time < end_epoch:
		var step := minf(end_epoch - orbit_time, FAST_WAIT_STEP)
		_step(step, Vector2.ZERO, 0.0, false, false, false, Vector3.ZERO)
		if time_scale <= TIME_SCALES[-1]:
			return
		var availability := time_status()
		if not availability.allowed:
			time_scale = 1
			_announce("time_normal", "Время возвращено к ×1. %s." % availability.reason)
			return
	if orbit_time >= stop_epoch:
		time_scale = 1
		if stop_epoch == SAVE_CLOCK_LIMIT:
			_announce("time_normal", "Достигнут предел игрового календаря.")
		else:
			_announce("time_normal", "Время возвращено к ×1 перед сроком задания.")


func _advance_background_clock(delta: float) -> void:
	var previous := orbit_time
	orbit_time += delta
	if docked >= 0:
		var paid := _port_account.advance(docked, orbit_time, credits)
		if paid >= 0:
			credits -= paid
			_announce("berth_bill", "Выставлен счёт за стоянку. Списано %d кр." % paid)
	_cargo_pods.advance(orbit_time)
	elapsed += delta
	combat.advance_energy(previous, orbit_time)
	if remote_rig.active():
		remote_rig.advance(mining, orbit_time)
	freight.advance(market, previous, orbit_time)
	market.advance(previous, orbit_time, self)


func _advance_mission_deadlines() -> void:
	_apply_service_result(passengers.advance(orbit_time))
	_apply_service_result(crew.advance(orbit_time, credits))
	_apply_service_result(career.advance(orbit_time))


func _advance_front(epoch: float) -> void:
	var due := factions.next_event_time()
	if due > epoch:
		return
	var result := factions.advance(due)
	if not result.is_empty():
		_record_front_news(result, due)
		_announce(result.event, result.message)


func _advance_hyperspace_calendar(duration: float) -> void:
	var arrival_epoch := orbit_time + duration
	var due := factions.next_event_time()
	while due <= arrival_epoch:
		var advance := maxf(0.0, due - orbit_time)
		if advance > 0.0:
			_advance_background_clock(advance)
		_advance_front(due)
		_advance_mission_deadlines()
		_apply_convoy_result(convoy_order.step(self, advance))
		due = factions.next_event_time()
	var remainder := maxf(0.0, arrival_epoch - orbit_time)
	if remainder > 0.0:
		_advance_background_clock(remainder)
	_advance_mission_deadlines()
	_apply_convoy_result(convoy_order.step(self, remainder))


func _step(delta: float, steer: Vector2, bank: float, boost_requested: bool, brake: bool, manual_input: bool, translation: Vector3) -> void:
	if _jump_transit_duration > 0.0:
		_advance_jump_transit(delta)
		return
	var previous_orbit_time := orbit_time
	_advance_background_clock(delta)
	if docked < 0 and not landed and dock_access.port == target:
		var before := dock_access.status(target, previous_orbit_time)
		var access := dock_access.status(target, orbit_time)
		if access.ready and not before.ready:
			_announce("dock_ready", "Створ открыт. Допуск «%s» получен." % target_name(target))
		elif before.ready and not access.ready:
			_announce("dock_expired", "Окно швартовки закрыто. Запросите новый допуск.")
	_advance_front(orbit_time)
	_advance_mission_deadlines()
	if docked >= 0:
		if _departure_requested:
			_advance_departure(delta)
		else:
			_hold_docked_pose()
		_update_star_heat(delta)
		_update_entry_heat(delta)
		_apply_patrol_result(patrol.step(self, delta))
		_apply_convoy_result(convoy_order.step(self, delta))
		return
	if landed:
		_hold_landed_pose()
		_update_star_heat(delta)
		_update_entry_heat(delta)
		_apply_patrol_result(patrol.step(self, delta))
		var mining_event := mining.update(delta)
		match mining_event:
			"mining_ready":
				_announce(mining_event, "Добыто %d ед. сырья. Заберите модуль." % mining.pending_ore)
			"mining_loaded":
				_announce(mining_event, "Модуль на борту. Сырьё в трюме. Можно взлетать.")
		_apply_convoy_result(convoy_order.step(self, delta))
		return

	_advance_gear(delta)
	if jump_seconds_left > 0.0:
		if manual_input:
			cancel_jump()
		else:
			_charge_jump(delta)
			if _jump_transit_duration > 0.0:
				return
		_update_star_heat(delta)
		_update_entry_heat(delta)
		_apply_convoy_result(convoy_order.step(self, delta))
		return
	if manual_input:
		if autopilot or patrol_course or project_course or convoy_course or orbit_maneuver or rendezvous_active:
			set_autopilot(false)
			_announce("manual_override", "Ручное управление")

	var had_fuel := ship.fuel > 0.0
	var manual_load := 0.0
	if autopilot:
		_autopilot_step(delta)
	elif orbit_maneuver:
		_orbit_maneuver_step(delta)
	elif rendezvous_active:
		_rendezvous_step(delta)
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
		_update_entry_heat(delta)
		_apply_convoy_result(convoy_order.step(self, delta))
		return
	_atmosphere_step(delta)
	var previous_ship := position
	var next := position + velocity * delta
	var shutter := _closed_hatch_between(position, next, previous_orbit_time)
	var obstacle := shutter if shutter >= 0 else _obstacle_at(next)
	if obstacle < 0:
		position = next
	else:
		reset_time_scale()
		var rotates := Terrain.spin_rate(_surface_body(obstacle)) > 0.0
		var impact_speed := velocity.distance_to(surface_velocity(obstacle, next)) if rotates else speed_relative_to(obstacle)
		var damage := ship.apply_damage(clampf((impact_speed - IMPACT_DAMAGE_SPEED) * 0.32, 0.0, 45.0))
		if damage > 0.0:
			_announce("hull_damage", "Корпус повреждён. Прочность %.0f%%." % ship.hull)
		elif shutter >= 0:
			_announce("dock_denied", "Створ закрыт. Запросите допуск перед входом.")
		elif velocity.length_squared() > 0.05:
			_announce("clearance", "Защитное торможение у препятствия")
		var caught_by_motion := _inside_hull(position, obstacle)
		if rotates:
			if caught_by_motion:
				var previous_center: Vector3 = Orbit.sample(obstacle, previous_orbit_time).position
				var previous_frame := _surface_basis(obstacle, previous_orbit_time)
				var local := previous_frame.transposed() * (position - previous_center)
				position = target_position(obstacle) + _surface_basis(obstacle, orbit_time) * local
				if _inside_hull(position, obstacle):
					position = _outside_rotating_surface(position, obstacle, orbit_time)
			velocity = surface_velocity(obstacle, position)
		else:
			if caught_by_motion or shutter >= 0:
				var previous_center: Vector3 = Orbit.sample(obstacle, previous_orbit_time).position
				position += target_position(obstacle) - previous_center
			velocity = target_velocity(obstacle) if caught_by_motion or shutter >= 0 else Vector3.ZERO
		throttle = 0.0
		_release_speed_hold(false)
		set_autopilot(false)
	_update_star_heat(delta)
	_advance_fuel_pump(previous_orbit_time)
	_collect_fuel(delta)
	_advance_combat_projectile(previous_ship, delta)
	_apply_patrol_result(patrol.step(self, delta))
	_apply_convoy_result(convoy_order.step(self, delta))
	_apply_ambient_result(ambient.step(self, delta))


func _rendezvous_step(delta: float) -> void:
	var site := _rendezvous_site
	var reason := _rendezvous_block_reason(site, _rendezvous_gap)
	if not reason.is_empty():
		_clear_rendezvous()
		_announce("rendezvous_abort", "Сближение прервано. %s." % reason)
		return
	boost = false
	var plan := Rendezvous.plan(self, site, _rendezvous_offset)
	var aim_point: Vector3 = plan.point
	var drift: Vector3 = plan.velocity
	var waypoint := Rendezvous.route_waypoint(self, plan)
	var detouring := not (waypoint.is_equal_approx(aim_point) or waypoint.is_equal_approx(plan.predicted))
	var offset := waypoint - position
	var aim := target_position(site) - position if _rendezvous_holding else offset
	if aim.length_squared() > 0.001:
		_turn_nose_toward(aim.normalized(), delta)
	var cruise := _cruise_limit(Rendezvous.CRUISE_SPEED)
	if detouring:
		cruise = minf(cruise, 58.0)
	var distance := offset.length()
	var requested := minf(cruise, minf(sqrt(30.0 * distance), 0.8 * distance))
	var desired := offset.normalized() * requested
	if not detouring:
		desired += drift
	if ship.fuel <= 0.0:
		desired = desired.limit_length(RESERVE_SPEED)
	velocity = velocity.move_toward(desired, _acceleration_limit(40.0) * delta)
	throttle = requested / MAX_SPEED if distance >= 0.25 else 0.0
	if not _rendezvous_holding and not detouring and position.distance_to(aim_point) <= RENDEZVOUS_HOLD_DISTANCE and velocity.distance_to(drift) <= RENDEZVOUS_HOLD_SPEED:
		_rendezvous_holding = true
		_announce("rendezvous_hold", "Скорость выровнена. Удерживаем дистанцию %d м от объекта «%s»." % [_rendezvous_gap, target_name(site)])


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
		var impulse := minf(remaining, _acceleration_limit(ORBIT_BURN_ACCELERATION) * delta)
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
	if absf(bank) > 0.12 and cancel_dock_sync():
		_announce("dock_sync_manual", "Ручное управление креном.")
	_rotate_manual(steer, bank, delta)
	if dock_roll_sync >= 0:
		if dock_roll_sync != target or not docking_guidance().sync_available:
			cancel_dock_sync()
		else:
			_match_target_roll(delta)
	var had_fuel := ship.fuel > 0.0
	boost = boost_requested and not brake and had_fuel
	var reference := reference_site()
	var drift := _reference_velocity(reference) if reference >= 0 else Vector3.ZERO
	if boost_requested or brake or not is_zero_approx(translation.z):
		_release_speed_hold()
	var basis := attitude()
	if brake:
		throttle = 0.0
		var drive_power := 1.0 if had_fuel else ShipSystems.RESERVE_THRUST_FRACTION
		var emergency_duration := delta * JUMP_BRAKE / (34.0 * drive_power)
		velocity += basis * _bounded_manual_impulse(basis.transposed() * (drift - velocity), emergency_duration)
		return 0.0
	if speed_hold.enabled:
		return _speed_hold_step(delta, drift, translation, basis)
	var thrust := 1.55 if boost else throttle
	var limit := 1.55 if boost else 1.0
	var requested := Vector3(translation.x, translation.y, -translation.z - thrust)
	var local := requested.limit_length(limit)
	var drive_speed := _cruise_limit(MAX_SPEED)
	if flight_assist:
		var desired := drift + basis * local * drive_speed
		if not had_fuel:
			desired = desired.limit_length(RESERVE_SPEED)
		velocity += basis * _bounded_manual_impulse(basis.transposed() * (desired - velocity), delta * limit)
	else:
		# The flight frame changes instruments and velocity assistance. Free coast is inertial.
		var powered_limit := maxf(velocity.length(), drive_speed * limit)
		var impulse := local * ship.thrust_acceleration(local, mining.ore_hold) * delta
		var powered := (velocity + basis * impulse).limit_length(powered_limit)
		velocity = (powered + gravity_at(position) * delta).limit_length(MAX_SAVED_SPEED - 1.0)
	return requested.length()


func _bounded_manual_impulse(requested: Vector3, duration: float) -> Vector3:
	if duration <= 0.0:
		return Vector3.ZERO
	var limits := ship.thrust_acceleration(requested, mining.ore_hold) * duration
	return (requested / limits).limit_length() * limits


func _speed_hold_step(delta: float, drift: Vector3, translation: Vector3, basis: Basis) -> float:
	var facing := -basis.z
	var lateral := Vector2(translation.x, translation.y).limit_length()
	var speed_limit := _cruise_limit(MAX_SPEED)
	if not lateral.is_zero_approx():
		var command := Vector3(lateral.x, lateral.y, 0.0)
		if flight_assist:
			var actual := basis.transposed() * (velocity - drift)
			var change := command * speed_limit - Vector3(actual.x, actual.y, 0.0)
			velocity += basis * _bounded_manual_impulse(change, lateral.length() * delta)
		else:
			velocity += basis * (command * ship.thrust_acceleration(command, mining.ore_hold) * delta)
	if not flight_assist:
		velocity += gravity_at(position) * delta
	var reachable := minf(SpeedHold.LIMIT, speed_limit)
	var wanted := clampf(speed_hold.setpoint, -reachable, reachable)
	var projected := SpeedHold.projected_speed(velocity, drift, facing)
	var direction := Vector3.FORWARD if wanted >= projected else Vector3.BACK
	var acceleration := ship.thrust_acceleration(direction, mining.ore_hold).z
	var authority := acceleration * sqrt(maxf(0.0, 1.0 - lateral.length_squared()))
	var correction := speed_hold.speed_delta(velocity, drift, facing, authority, delta, speed_limit)
	velocity = (velocity + facing * correction).limit_length(MAX_SAVED_SPEED - 1.0)
	return Vector2(lateral.length(), absf(correction) / (acceleration * delta)).length()


func _cruise_limit(speed_with_fuel: float) -> float:
	return speed_with_fuel * ship.speed_factor() if ship.fuel > 0.0 else minf(speed_with_fuel, RESERVE_SPEED)


func _acceleration_limit(acceleration: float) -> float:
	return acceleration * ship.thrust_acceleration(Vector3.FORWARD, mining.ore_hold).z / 34.0


func _blocked(point: Vector3, sector_id := -1, epoch := -1.0, progress: RefCounted = null, atlas: RefCounted = null) -> bool:
	return _obstacle_at(point, sector_id, epoch, progress, atlas) >= 0


func _obstacle_at(point: Vector3, sector_id := -1, epoch := -1.0, progress: RefCounted = null, atlas: RefCounted = null) -> int:
	var history := expedition if progress == null else progress
	for index: int in Catalog.targets_for(system_id if sector_id < 0 else sector_id):
		if _site_available(index, history, atlas) and _inside_hull(point, index, epoch):
			return index
	return -1


func _inside_hull(point: Vector3, index: int, epoch := -1.0, fixed_surface := false) -> bool:
	var center: Vector3 = target_position(index) if epoch < 0.0 else Orbit.sample(index, epoch).position
	var relative := point - center
	if Ground.is_port(index):
		var geometry_epoch := orbit_time if epoch < 0.0 else epoch
		var orientation := Ground.basis(index, 0.0 if fixed_surface else geometry_epoch)
		if fixed_surface:
			var host: Vector3 = Orbit.sample(Ground.body(index), geometry_epoch).position
			relative = point - (host + Ground.anchor_offset(index, 0.0))
		return Ground.local_hull(index, orientation.transposed() * relative)
	if Catalog.is_star(index):
		var clearance := Catalog.stellar_clearance(index)
		return relative.length_squared() < clearance * clearance
	if Catalog.is_gas_giant(index):
		var pressure_radius := float(Catalog.site(index).radius)
		return relative.length_squared() < pressure_radius * pressure_radius
	if Catalog.is_mine_site(index):
		var outer := float(Catalog.site(index).radius) * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE
		var distance_squared := relative.length_squared()
		if distance_squared >= outer * outer:
			return false
		if distance_squared < 0.0001:
			return true
		var direction := relative.normalized()
		if not fixed_surface:
			direction = Terrain.spin_basis(index, orbit_time if epoch < 0.0 else epoch).transposed() * direction
		var radius := Terrain.radius_at(index, direction) + Terrain.CONTACT_CLEARANCE - 0.025
		return distance_squared < radius * radius
	# A narrow corridor leads into the illuminated docking collar.
	var inside_corridor := relative.z >= float(Catalog.site(index).pad_offset) - 0.8 and Vector2(relative.x, relative.y).length() < 4.4
	var hull := Vector3(relative.x / HULL_X, relative.y / HULL_Y, relative.z / HULL_Z)
	return hull.length_squared() < 1.0 and not inside_corridor


func _closed_hatch_between(from: Vector3, to: Vector3, previous_epoch: float) -> int:
	for port: int in local_ports():
		var ground := Ground.is_port(port)
		if ground and not Ground.is_hangar(port):
			continue
		var destination := docking_position(port)
		if to.distance_squared_to(destination) > 400.0:
			continue
		var frame_now := Ground.basis(port, orbit_time) if ground else Basis.IDENTITY
		var hatch := Vector3.BACK * DockAccess.HATCH_AXIS_OFFSET
		var end := frame_now.transposed() * (to - destination) - hatch
		if end.z > 0.0:
			continue
		var earlier: Dictionary = Orbit.sample(port, previous_epoch)
		var frame_before := Ground.basis(port, previous_epoch) if ground else Basis.IDENTITY
		var earlier_center: Vector3 = earlier.position + frame_before.z * float(Catalog.site(port).pad_offset)
		var start := frame_before.transposed() * (from - earlier_center) - hatch
		# A ship already inside the plane can always leave under its own power.
		if start.z < 0.0 or start.z <= end.z:
			continue
		var crossing := start.lerp(end, clampf(start.z / (start.z - end.z), 0.0, 1.0))
		if Vector2(crossing.x, crossing.y).length_squared() <= DockAccess.HATCH_RADIUS * DockAccess.HATCH_RADIUS:
			if not dock_access.status(port, orbit_time).ready:
				return port
	return -1



func _outside_rotating_surface(point: Vector3, site: int, epoch: float) -> Vector3:
	var center: Vector3 = Orbit.sample(site, epoch).position
	if Ground.is_port(site):
		var platform := Ground.basis(site, epoch)
		var local := platform.transposed() * (point - center)
		var ceiling := Ground.HANGAR_TOP if Ground.is_hangar(site) else Ground.DECK_HEIGHT
		local.z = maxf(local.z, ceiling + 0.5)
		var repaired := center + platform * local
		return center + platform.z * 12.0 if _inside_hull(repaired, Ground.body(site), epoch) else repaired
	var outward := (point - center).normalized()
	if outward.is_zero_approx():
		outward = _surface_axis(site, epoch)
	var direction := Terrain.spin_basis(site, epoch).transposed() * outward
	var radius := Terrain.radius_at(site, direction) + Terrain.CONTACT_CLEARANCE + 0.5
	return center + outward * radius

func _autopilot_step(delta: float) -> void:
	boost = false
	var star_run := Catalog.is_star(target)
	var gas_run := Catalog.is_gas_giant(target)
	var scoop_run := star_run or gas_run
	var mining_site := Catalog.is_mine_site(target)
	var port_run := Catalog.is_port(target)
	var ground := Ground.is_port(target)
	var needs_clearance := port_run and (not ground or Ground.is_hangar(target))
	var target_radius := Catalog.stellar_clearance(target) if star_run else float(Catalog.site(target).radius)
	var atmosphere := Atmosphere.profile(target)
	var bypass_radius := target_radius + float(atmosphere.height) if gas_run else target_radius
	var center := target_position(target)
	var gate := target_gate(target)
	var surface_frame := Ground.basis(target, orbit_time) if ground else Terrain.spin_basis(target, orbit_time)
	var remote_landing := _rig_landing_target(target)
	var landing_normal := surface_frame.z
	if remote_landing:
		var outward := surface_frame * remote_rig.direction
		landing_normal = surface_frame * Terrain.normal(target, remote_rig.direction)
		var guide_up := Vector3.RIGHT if absf(outward.y) > 0.95 else Vector3.UP
		surface_frame = Basis.looking_at(-outward, guide_up)
	var rotates := Terrain.spin_rate(_surface_body(target)) > 0.0
	var drift := surface_velocity(target, gate)
	var relative := position - center
	var approach_offset := surface_frame.transposed() * relative
	var waypoint := gate
	var max_speed := 118.0
	var aim := -landing_normal
	var waiting_for_port := false
	var retreating := false
	if needs_clearance and _approach_committed and not dock_access.status(target, orbit_time).ready:
		_approach_committed = false
		retreating = true
	elif needs_clearance and not _approach_committed:
		var corridor := surface_frame.transposed() * (position - docking_position(target))
		var hatch_limit := DockAccess.HATCH_AXIS_OFFSET if ground else HULL_Z
		retreating = corridor.z >= -0.8 and corridor.z < hatch_limit and Vector2(corridor.x, corridor.y).length_squared() <= DockAccess.HATCH_RADIUS * DockAccess.HATCH_RADIUS

	if _departure_leg == 0 and not _approach_committed and position.distance_to(gate) < 3.4 and velocity.distance_to(drift) < 7.0:
		if needs_clearance and not dock_access.status(target, orbit_time).ready:
			dock_clearance_action()
			waiting_for_port = true
		else:
			_approach_committed = true

	if retreating:
		autopilot_phase = "Отход от закрытого створа"
		max_speed = 24.0
	elif waiting_for_port:
		autopilot_phase = "Ожидание допуска"
		_match_target_roll(delta)
	elif _approach_committed:
		if scoop_run:
			waypoint = target_contact(target)
			max_speed = 30.0 if gas_run else 32.0
			autopilot_phase = "Вход в зону сбора"
		else:
			waypoint = target_contact(target) + landing_normal * 1.8
			drift = surface_velocity(target, waypoint)
			max_speed = 13.0 if mining_site or ground else 19.0
			if mining_site or ground:
				_command_gear(true)
				autopilot_phase = "Посадка" if _gear_locked() else "Выпуск шасси"
			else:
				_command_gear(false)
				autopilot_phase = "Стыковка"
		_match_target_roll(delta)
	else:
		autopilot_phase = "К зоне сбора" if scoop_run else "К створу"
		# Approach a station from the front. The side waypoint keeps a return
		# journey from crossing the station hull from behind.
		var front_clearance := bypass_radius + 22.0 if mining_site or gas_run else 34.0
		var side_clearance := maxf(84.0, bypass_radius + 42.0)
		if ground and approach_offset.z < 34.0:
			waypoint = center + landing_normal * 50.0
			drift = surface_velocity(target, waypoint)
			autopilot_phase = "Над посадочной площадкой"
		elif not ground and approach_offset.z < front_clearance and absf(approach_offset.x) < side_clearance - 7.0:
			var side := 1.0 if approach_offset.x >= 0.0 else -1.0
			waypoint = center + surface_frame * Vector3(side * side_clearance, approach_offset.y, minf(approach_offset.z, front_clearance))
			drift = surface_velocity(target, waypoint)
			autopilot_phase = "Обход объекта"
		elif not ground and approach_offset.z < front_clearance + 6.0:
			var side := 1.0 if approach_offset.x >= 0.0 else -1.0
			waypoint = center + surface_frame * Vector3(side * side_clearance, 0.0, front_clearance + 21.0)
			drift = surface_velocity(target, waypoint)
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
			elif Ground.is_port(_departure_site):
				waypoint = departure + station_axis(_departure_site) * (departure_radius + 48.0)
				drift = surface_velocity(_departure_site, waypoint)
			else:
				waypoint = departure + _departure_axis * (departure_radius * Terrain.MAX_RADIUS_FACTOR + 48.0)
			autopilot_phase = "Выход из зоны объекта"
			max_speed = 36.0
			if position.distance_to(waypoint) < 4.0 and speed_relative_to(_departure_site) < 8.0:
				_departure_leg = 2 if _departure_leg == 1 and _departure_axis == Vector3.ZERO else 0
		else:
			var detour := _star_detour(waypoint, target if star_run else -1)
			if detour != waypoint:
				waypoint = detour
				drift = Vector3.ZERO
				autopilot_phase = "Обход звезды"
				max_speed = 64.0
	var displacement := waypoint - position
	var direction := displacement
	if waypoint == gate and not star_run and _departure_leg == 0 and displacement.length_squared() > 62500.0:
		var meeting_epoch := orbit_time + intercept_time(target)
		var forecast: Vector3 = Orbit.sample(target, meeting_epoch).position
		direction += forecast - center
		if rotates:
			direction += (_approach_axis(target, meeting_epoch) - surface_frame.z) * float(Catalog.site(target).gate_offset)
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

	var in_gas_layer := gas_run and relative.length_squared() <= bypass_radius * bypass_radius
	if not atmosphere.is_empty() and _departure_leg == 0 and (relative.dot(direction) < 0.0 or in_gas_layer):
		var clearance := maxf(0.0, relative.length() - target_radius - float(atmosphere.height))
		var entry_limit := sqrt(Atmosphere.SAFE_ENTRY_SPEED * Atmosphere.SAFE_ENTRY_SPEED + 64.0 * clearance)
		if entry_limit < max_speed:
			max_speed = entry_limit
			autopilot_phase = "Торможение перед входом" if clearance > 0.0 else "Снижение в атмосфере"
	_point_towards(aim, delta)
	max_speed = _cruise_limit(max_speed)
	var desired_speed := minf(max_speed, minf(sqrt(42.0 * displacement.length()), displacement.length() * 1.6))
	var desired := drift + direction.normalized() * desired_speed
	if ship.fuel <= 0.0:
		desired = desired.limit_length(RESERVE_SPEED)
	velocity = velocity.move_toward(desired, _acceleration_limit(42.0) * delta)
	throttle = clampf(desired_speed / (MAX_SPEED * ship.speed_factor()), 0.0, 1.0)
	if _approach_committed and scoop_run and displacement.length() < 2.0 and speed_relative_to(target) < 3.0:
		set_autopilot(false)
		throttle = 0.0
		var next_step := "Можно включить сбор водорода." if ship.hydrogen_scoop else "Сборщик водорода не установлен."
		_announce("gas_arrival" if gas_run else "star_arrival", "Корабль в зоне сбора «%s». %s" % [target_name(target), next_step])
	elif _approach_committed and not scoop_run:
		var status := selected_dock_status()
		if status.ok and (mining_site or (status.range <= DOCK_AUTO_DISTANCE and status.relative_speed <= DOCK_AUTO_SPEED)):
			if not remote_landing or position.distance_to(target_contact(target)) <= REMOTE_RIG_ACCESS_DISTANCE:
				_arrive(status.direction if remote_landing else Vector3.BACK)


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
	var cruise := _cruise_limit(PATROL_CRUISE_SPEED)
	var speed_limit := minf(cruise, distance * 0.30)
	velocity = velocity.move_toward(direction * speed_limit, _acceleration_limit(42.0) * delta)
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
	var cruise := _cruise_limit(PATROL_CRUISE_SPEED)
	var speed_limit := minf(cruise, position.distance_to(waypoint) * 0.34)
	var drift := target_velocity(status.site) if waypoint == point else Vector3.ZERO
	velocity = velocity.move_toward((direction * speed_limit + drift).limit_length(cruise), _acceleration_limit(42.0) * delta)
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
	var cruise := _cruise_limit(CONVOY_CRUISE_SPEED)
	var speed_limit := minf(cruise, position.distance_to(waypoint) * 0.56)
	var desired := course * speed_limit
	if not detouring:
		desired += drift
	velocity = velocity.move_toward(desired.limit_length(cruise), _acceleration_limit(42.0) * delta)
	throttle = speed_limit / MAX_SPEED


func _transit_obstacle(course: Vector3, cruise: float, skip_target := true) -> int:
	var speed_limit := _cruise_limit(cruise)
	var duration := course.length() / speed_limit
	var earliest := INF
	var obstacle := -1
	for id: int in local_targets():
		if (skip_target and id == target) or Catalog.is_star(id):
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
		var clearance := _transit_radius(id) + 30.0
		if closest.length_squared() < clearance * clearance:
			earliest = fraction
			obstacle = id
	return obstacle


func _transit_waypoint(id: int, course: Vector3) -> Vector3:
	var center := target_position(id)
	var radius := _transit_radius(id)
	var outward := (position - center).normalized()
	var side := course.slide(outward)
	if side.length_squared() < 0.001:
		side = Vector3.UP.slide(outward)
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT.slide(outward)
	return center + outward * (radius + 55.0) + side.normalized() * (radius + 58.0)


func _transit_radius(id: int) -> float:
	var radius := float(Catalog.site(id).radius)
	return radius + float(Atmosphere.profile(id).height) if Catalog.is_gas_giant(id) else radius


func _star_detour(waypoint: Vector3, excluded := -1) -> Vector3:
	var course := waypoint - position
	var length_squared := course.length_squared()
	var margin_squared := Catalog.SCOOP_INNER * Catalog.SCOOP_INNER
	var obstacle := -1
	var earliest := INF
	for id: int in Catalog.stars_for(system_id):
		if id == excluded:
			continue
		var center := target_position(id)
		var radial := position - center
		var clearance := maxf(Catalog.SCOOP_INNER + 1.0, Catalog.stellar_clearance(id) + 60.0)
		if radial.length_squared() < margin_squared:
			var exit_axis := Vector3.BACK if radial.is_zero_approx() else radial.normalized()
			return center + exit_axis * clearance
		if length_squared < 0.001:
			continue
		var fraction := clampf(-radial.dot(course) / length_squared, 0.0, 1.0)
		var closest := radial + course * fraction
		if fraction < earliest and closest.length_squared() < margin_squared:
			obstacle = id
			earliest = fraction
	if obstacle < 0:
		return waypoint
	var center := target_position(obstacle)
	var outward := (position - center).normalized()
	var sideways := course.slide(outward)
	if sideways.length_squared() < 0.001:
		sideways = Vector3.RIGHT.slide(outward)
		if sideways.length_squared() < 0.001:
			sideways = Vector3.UP.slide(outward)
	var clearance := maxf(Catalog.SCOOP_INNER + 1.0, Catalog.stellar_clearance(obstacle) + 60.0)
	return center + outward * clearance + sideways.normalized() * 210.0


func _point_towards(direction: Vector3, delta: float) -> void:
	var goal_yaw := atan2(-direction.x, -direction.z)
	var goal_pitch := clampf(asin(clampf(direction.y, -1.0, 1.0)), -MAX_PITCH, MAX_PITCH)
	yaw = wrapf(yaw + clampf(angle_difference(yaw, goal_yaw), -MAX_STEER * delta, MAX_STEER * delta), -PI, PI)
	pitch = move_toward(pitch, goal_pitch, MAX_STEER * delta)


func _announce(event: String, message: String) -> void:
	status_event = event
	status_message = message


func _interruptions_at_save() -> Array[String]:
	var interrupted: Array[String] = []
	if autopilot:
		interrupted.append("rig_approach" if _rig_approach else "autopilot")
	if orbit_maneuver:
		interrupted.append("orbit_maneuver")
	if rendezvous_active:
		interrupted.append("rendezvous")
	if patrol_course:
		interrupted.append("patrol_course")
	if project_course:
		interrupted.append("project_course")
	if convoy_course:
		interrupted.append("convoy_course")
	if dock_roll_sync >= 0:
		interrupted.append("dock_roll_sync")
	if jump_seconds_left > 0.0 and _jump_transit_duration <= 0.0:
		interrupted.append("unpaid_jump_charge")
	if scooping:
		interrupted.append("scoop")
	if time_scale > 1:
		interrupted.append("time_scale")
	return interrupted


func snapshot() -> Dictionary:
	var facing := _flight_orientation()
	frame.reference_site(self)
	var interrupted := _interruptions_at_save()
	var powered := interrupted.any(func(mode: String) -> bool: return mode in POWERED_ASSISTS)
	var transit := {}
	if _jump_transit_duration > 0.0:
		transit = {"remaining": jump_seconds_left, "duration": _jump_transit_duration,
			"fare": _jump_paid_fare, "pricing": _jump_paid_pricing}
	return {
		"schema": SAVE_SCHEMA,
		"position": [position.x, position.y, position.z],
		"velocity": [velocity.x, velocity.y, velocity.z],
		"yaw": yaw, "pitch": pitch, "roll": roll, "elapsed": elapsed,
		"orientation": [facing.x, facing.y, facing.z, facing.w], "flight_assist": flight_assist,
		"orbit_time": orbit_time, "time_paused": time_paused,
		"throttle": 0.0 if powered else throttle, "docked": docked, "target": target,
		"dock_access": dock_access.snapshot(),
		"departure_requested": _departure_requested, "departure_seconds": _departure_seconds,
		"credits": credits, "deliveries": deliveries,
		"contract_stage": contract_stage, "contract_origin": contract_origin,
		"contract_issuer": _contract_issuer,
		"contract_destination": contract_destination,
		"contract_route_id": contract_route_id, "contract_leg": contract_leg,
		"landed_site": landed_site, "planned_target": planned_target, "mining": mining.snapshot(),
		"landing_direction": [landing_direction.x, landing_direction.y, landing_direction.z],
		"gear_extension": gear_extension, "gear_deployed": gear_deployed,
		"ship": ship.snapshot(), "market": market.snapshot(), "freight": freight.snapshot(),
		"market_contacts": market.hidden_snapshot(),
		"system_id": system_id, "jump_target": jump_target, "jump_route": _jump_route.duplicate(),
		"jump_transit": transit,
		"patrol": patrol.snapshot(), "star_heat": star_heat, "entry_heat": entry_heat,
		"expedition": expedition.snapshot(), "factions": factions.snapshot(),
		"convoy_order": convoy_order.snapshot(),
		"passengers": passengers.snapshot(),
		"crew": crew.snapshot(),
		"cartography": cartography.snapshot(), "frame": frame.snapshot(), "customs": customs.snapshot(),
		"port_account": _port_account.snapshot(), "civic": _civic.snapshot(),
		"remote_rig": remote_rig.snapshot(), "orbital_mining": orbital_mining.snapshot(),
		"cargo_pods": _cargo_pods.snapshot(),
		"combat": combat.snapshot(),
		"ambient": ambient.snapshot(), "career": career.snapshot(),
		"story": story.snapshot(), "news": news.snapshot(),
		"speed_hold": speed_hold.snapshot(),
		"resume": {"interrupted": interrupted, "patrol_clock": patrol.combat_clock(), "convoy_clock": convoy_order.combat_clock()},
	}


func restore(state: Dictionary) -> bool:
	if not _integer(state.get("schema"), 1, SAVE_SCHEMA):
		return false
	var schema := int(state.schema)
	var pre_assortment := schema < 49
	var pre_rich_systems := schema < 48
	var pre_atlas := schema < 47
	var pre_expanded_galaxy := schema < 46
	var pre_lazur_spin := schema < 45
	var pre_resume := schema < 44
	var pre_news := schema < 43
	var pre_story := schema < 42
	var pre_career := schema < 41
	var pre_ambient_traffic := schema < 40
	var pre_speed_hold := schema < 39
	var pre_ground_ports := schema < 38
	var pre_combat := schema < 37
	var pre_jump_drive := schema < 36
	var pre_calendar := schema < 35
	var pre_fuel_equipment := schema < 34
	var pre_orbital_mining := schema < 33
	var pre_remote_rig := schema < 32
	var pre_customs := schema < 31
	var pre_frames := schema < 30
	var pre_rotation := schema < 29
	var pre_binary := schema < 28
	var pre_procedural := schema < 27
	var pre_cartography := schema < 26
	var pre_shipyard := schema < 25
	var pre_crew := schema < 24
	var pre_passengers := schema < 23
	var pre_departure := schema < 22
	var pre_dock_access := schema < 21
	var pre_dual_fuel := schema < 20
	var pre_gear := schema < 19
	var pre_frontier_freight := schema < 18
	var pre_jump_route := schema < 17
	var pre_freight := schema < 16
	var pre_heat_shield := schema < 15
	var pre_entry := schema < 14
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
	if not pre_entry and not _number(state.get("entry_heat"), 0.0, 100.0):
		return false
	if not pre_navigation and not state.get("flight_assist") is bool:
		return false
	if not pre_calendar and not state.get("time_paused") is bool:
		return false
	var restored_epoch := 0.0
	if schema >= 6:
		if not _number(state.get("orbit_time"), 0.0, 3155760000.0):
			return false
		restored_epoch = float(state.orbit_time)
	var restored_system := Catalog.HOME_SYSTEM
	var restored_jump := -1
	var systems := Catalog.PRE_ATLAS_SYSTEM_COUNT if pre_atlas else Catalog.SYSTEM_COUNT
	if pre_expanded_galaxy:
		systems = Catalog.PRE_EXPANDED_SYSTEM_COUNT
	if not pre_galaxy:
		if pre_binary:
			systems = Catalog.PRE_BINARY_SYSTEM_COUNT
		if pre_procedural:
			systems = Catalog.AUTHORED_SYSTEM_COUNT
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
	var site_count := Catalog.PRE_ATLAS_DESTINATION_COUNT if pre_atlas else Catalog.DESTINATION_COUNT
	if pre_rich_systems and not pre_atlas:
		site_count = Catalog.PRE_RICH_SYSTEMS_DESTINATION_COUNT
	if pre_expanded_galaxy:
		site_count = Catalog.PRE_EXPANDED_DESTINATION_COUNT
	if pre_ground_ports:
		site_count = Catalog.PRE_GROUND_DESTINATION_COUNT
	if pre_expansion:
		site_count = Catalog.PRE_EXPANSION_DESTINATION_COUNT
	if pre_binary and not pre_expansion:
		site_count = Catalog.PRE_BINARY_DESTINATION_COUNT
	if pre_procedural and not pre_expansion:
		site_count = Catalog.AUTHORED_DESTINATION_COUNT
	if pre_dual_fuel and not pre_expansion:
		site_count = Catalog.PRE_GAS_DESTINATION_COUNT
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
	var restored_passengers := Passengers.new()
	var restored_crew := Crew.new()
	var restored_cartography := Cartography.new()
	var restored_frame := FlightFrame.new()
	var restored_customs := Customs.new()
	if not pre_customs and not restored_customs.restore(state.get("customs"), restored_epoch, pre_assortment):
		return false
	if not pre_expansion:
		if not restored_expedition.restore(state.get("expedition")) or not restored_factions.restore(state.get("factions"), pre_thermal, pre_convoy_orders):
			return false
		for system in Expedition.FRONTIER_SYSTEMS:
			if restored_expedition.commissioned(system) != (restored_factions.owner(system) >= 0):
				return false
	if not pre_convoy_orders and not restored_convoy_order.restore(state.get("convoy_order"), restored_factions, restored_expedition):
		return false
	if not pre_passengers:
		if not restored_passengers.restore(state.get("passengers"), restored_epoch):
			return false
		var manifest := restored_passengers.status(restored_epoch)
		if manifest.active and (not _site_available(manifest.origin, restored_expedition) or not _site_available(manifest.destination, restored_expedition)):
			return false
	if not pre_crew:
		if not restored_crew.restore(state.get("crew"), restored_epoch):
			return false
		for member: Dictionary in restored_crew.status(restored_epoch).members:
			if not _site_available(member.origin, restored_expedition):
				return false
	if not pre_cartography:
		if not restored_cartography.restore(state.get("cartography"), restored_epoch, pre_procedural, systems, site_count):
			return false
		for site: int in restored_cartography.surveyed_sites():
			if not _site_available(site, restored_expedition, restored_cartography):
				return false
	var known := _known_systems(restored_expedition, restored_cartography)
	if restored_system not in known or (restored_jump >= 0 and restored_jump not in known):
		return false
	var restored_cargo_pods := CargoPods.new()
	if schema >= 48 and not restored_cargo_pods.restore(state.get("cargo_pods"), restored_epoch, restored_system, known, MAX_SAVED_SPEED + CargoPods.EJECT_SPEED):
		return false
	if not pre_frames:
		var frame_sites := Catalog.targets_for(restored_system).filter(
			func(id: int) -> bool: return id < site_count and _site_available(id, restored_expedition, restored_cartography))
		if not restored_frame.restore(state.get("frame"), frame_sites):
			return false
	if not _site_available(int(state.target), restored_expedition, restored_cartography):
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
	var restored_story := BranchingStory.new()
	if not pre_story:
		var story_state: Variant = state.get("story")
		if not restored_story.restore(story_state, restored_epoch):
			return false
		if story_state.entry == "freight" and int(state.deliveries) <= 0:
			return false
		if story_state.entry == "survey":
			var observed := restored_cartography.observation_time(BranchingStory.ENTRY_SCAN)
			if observed < 0.0 or observed > float(story_state.briefed_at):
				return false
		if story_state.branch == BranchingStory.REGISTRY and float(story_state.settled_at) >= 0.0:
			var observed := restored_cartography.observation_time(BranchingStory.AUDIT_BODY)
			if observed < 0.0 or observed > float(story_state.settled_at):
				return false
	var restored_news := SectorNews.new()
	if pre_news:
		var record := restored_story.snapshot()
		_record_story_news(restored_news, record, BranchingStory.BRIEF)
		_record_story_news(restored_news, record, str(record.branch))
		_record_story_news(restored_news, record, BranchingStory.SUBMIT)
	elif not restored_news.restore(state.get("news"), restored_epoch):
		return false
	var restored_position := Vector3(state.position[0], state.position[1], state.position[2])
	var restored_velocity := Vector3(state.velocity[0], state.velocity[1], state.velocity[2])
	var restored_dock := int(state.docked)
	var restored_port_account := PortAccount.new()
	var restored_civic := CivicReputation.new()
	if schema >= 49:
		var available_port := func(id: int) -> bool:
			return Catalog.is_port(id) and _site_available(id, restored_expedition, restored_cartography)
		if not restored_port_account.restore(state.get("port_account"), restored_epoch, restored_dock, available_port) \
				or not restored_civic.restore(state.get("civic"), restored_epoch, available_port):
			return false
	else:
		restored_port_account.anchor(restored_dock, restored_epoch)
	var restored_access := DockAccess.new()
	var restored_mining := MiningRig.new()
	var restored_ship := ShipSystems.new()
	var restored_market := Economy.new()
	var restored_freight := NpcFreight.new()
	var restored_patrol := Patrol.new()
	var restored_landing := -1
	var restored_plan := -1
	if not pre_fuel and not restored_ship.restore(state.get("ship"), pre_economy, pre_heat_shield, pre_dual_fuel, pre_shipyard, pre_orbital_mining, pre_fuel_equipment, pre_jump_drive, pre_speed_hold):
		return false
	var restored_route: Array[int] = []
	if not pre_jump_route:
		var remaining: Variant = state.get("jump_route")
		if not remaining is Array or remaining.size() >= systems:
			return false
		for system: Variant in remaining:
			if not _integer(system, 0, systems - 1):
				return false
			restored_route.append(int(system))
		if not restored_route.is_empty():
			var path: Array[int] = [restored_system]
			path.append_array(restored_route)
			var tariff := func(a: int, b: int) -> int: return restored_ship.legacy_jump_tariff(Catalog.jump_cost(a, b))
			var capacity := restored_ship.jump_capacity()
			if schema >= 49:
				tariff = func(a: int, b: int) -> int: return ShipSystems.minimum_jump_tariff(Catalog.jump_cost(a, b))
				capacity = ShipSystems.BASE_CAPACITY + ShipSystems.EXTRA_CAPACITY
			if restored_route[0] != restored_jump or not GalacticRoute.valid_path(path, known, capacity, tariff):
				return false
	if not pre_economy and not restored_market.restore(state.get("market"), pre_traffic, pre_expansion, pre_dual_fuel,
			pre_ground_ports, pre_assortment, state.get("market_contacts")):
		return false
	if pre_freight:
		restored_freight.reset(restored_epoch)
	elif not restored_freight.restore(state.get("freight"), restored_epoch, pre_frontier_freight):
		return false
	for frontier: int in Expedition.FRONTIER_SYSTEMS:
		var commissioned := restored_expedition.commissioned(frontier)
		if pre_frontier_freight:
			if commissioned and not restored_freight.activate_frontier(frontier, restored_epoch):
				return false
		elif restored_freight.frontier_active(frontier) != commissioned:
			return false
	if not pre_traffic and not restored_patrol.restore(state.get("patrol")):
		return false
	if restored_patrol.origin >= 0 and not _site_available(restored_patrol.origin, restored_expedition):
		return false
	var restored_career := PilotCareer.new()
	var active_patrol := restored_patrol.phase in [Patrol.OUTBOUND, Patrol.ENGAGED, Patrol.RETURN]
	var report_only := restored_patrol.phase == Patrol.RETURN
	var restored_contract_issuer := -1
	if pre_career:
		if active_patrol:
			var sponsor := restored_factions.owner(Catalog.system_of_site(restored_patrol.origin))
			restored_career.note_patrol_accept(sponsor, restored_patrol.origin, report_only)
		if stage == 1:
			restored_contract_issuer = restored_factions.owner(Catalog.system_of_site(origin))
	else:
		var career_state: Variant = state.get("career")
		if not restored_career.restore(career_state, restored_epoch):
			return false
		if not _integer(state.get("contract_issuer"), -1, FactionFronts.FACTIONS.size() - 1):
			return false
		restored_contract_issuer = int(state.contract_issuer)
		if stage != 1 and restored_contract_issuer != -1:
			return false
		var has_patrol_record: bool = not career_state.patrol.is_empty()
		if active_patrol != has_patrol_record:
			return false
		if active_patrol and (int(career_state.patrol.origin) != restored_patrol.origin or career_state.patrol.victory != report_only):
			return false
		var dispatch := restored_career.dispatch_status(restored_epoch)
		if dispatch.active and (not _site_available(int(dispatch.origin), restored_expedition) or not _site_available(int(dispatch.destination), restored_expedition)):
			return false
	var mining_count := Catalog.SITE_COUNT if pre_galaxy else site_count
	if schema >= 2 and not restored_mining.restore(state.get("mining"), schema == 2, mining_count,
			restored_ship.cargo_capacity(), not pre_economy, pre_dual_fuel, pre_assortment):
		return false
	var restored_remote_rig := UnattendedMining.new()
	if not pre_remote_rig:
		if not restored_remote_rig.restore(state.get("remote_rig"), restored_epoch, restored_mining):
			return false
		if restored_remote_rig.active():
			var rig_site := restored_remote_rig.site_id
			if rig_site >= site_count or not _site_available(rig_site, restored_expedition, restored_cartography):
				return false
	var restored_orbital_mining := OrbitalMining.new()
	if not pre_orbital_mining:
		if not restored_orbital_mining.restore(state.get("orbital_mining"), restored_epoch, restored_mining,
				restored_remote_rig.site_id, restored_remote_rig.stored):
			return false
		for site: int in restored_orbital_mining.fragment_sites():
			if not restored_ship.mining_laser or not _site_available(site, restored_expedition, restored_cartography):
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
		var orbit := Orbit.sample(restored_landing, restored_epoch)
		var local_contact := Terrain.contact(restored_landing, restored_direction)
		var offset := Terrain.spin_basis(restored_landing, restored_epoch) * local_contact
		var contact: Vector3 = orbit.position + offset
		var ground_velocity := Vector3.ZERO
		if Terrain.spin_rate(restored_landing) > 0.0:
			ground_velocity = orbit.velocity + Terrain.spin_velocity(restored_landing, offset)
		if pre_rotation or (pre_lazur_spin and restored_landing == Catalog.GROUND_BODY):
			var old_contact: Vector3 = orbit.position + local_contact
			if not restored_position.is_equal_approx(old_contact) or not restored_velocity.is_zero_approx():
				return false
			restored_position = contact
			restored_velocity = ground_velocity
		elif not restored_position.is_equal_approx(contact) or not restored_velocity.is_equal_approx(ground_velocity):
			return false
	elif restored_mining.phase != MiningRig.STOWED or restored_direction != Vector3.ZERO:
		return false
	var restored_departure := false
	var restored_departure_seconds := -1.0
	if not pre_departure:
		if not state.get("departure_requested") is bool or not _number(state.get("departure_seconds"), -1.0, DEPARTURE_SECONDS):
			return false
		restored_departure = state.departure_requested
		restored_departure_seconds = float(state.departure_seconds)
		if (restored_departure_seconds < 0.0 and restored_departure_seconds != -1.0) or (not restored_departure and restored_departure_seconds != -1.0) or restored_departure_seconds == DEPARTURE_SECONDS:
			return false
		if restored_departure and (restored_dock < 0 or restored_landing >= 0 or (Ground.is_port(restored_dock) and not Ground.is_hangar(restored_dock))):
			return false
		if restored_departure and restored_crew.status(restored_epoch).count < restored_ship.crew_required():
			return false
	if not pre_dock_access:
		if not restored_access.restore(state.get("dock_access"), restored_epoch):
			return false
		if restored_access.port >= 0:
			if restored_access.port >= site_count or (Ground.is_port(restored_access.port) and not Ground.is_hangar(restored_access.port)):
				return false
			if Catalog.system_of_site(restored_access.port) != restored_system or not _site_available(restored_access.port, restored_expedition):
				return false
			var access := restored_access.status(restored_access.port, restored_epoch)
			var access_port := restored_dock if restored_departure else int(state.target)
			if access.phase in ["queued", "opening", "open"] and (restored_access.port != access_port
					or (restored_dock >= 0 and not restored_departure) or restored_landing >= 0):
				return false
	if restored_departure and restored_access.port != restored_dock:
		return false
	if restored_departure and restored_departure_seconds >= 0.0:
		var permit := restored_access.status(restored_dock, restored_epoch)
		if not permit.ready or permit.remaining + DockAccess.CLOCK_PRECISION < DEPARTURE_SECONDS - restored_departure_seconds:
			return false
	var restored_transit: Variant = {} if pre_jump_drive else state.get("jump_transit")
	var restored_pricing := MASS_JUMP_PRICING
	if not restored_transit is Dictionary:
		return false
	if not restored_transit.is_empty():
		var receipt_fields := ["remaining", "duration", "fare"]
		if schema >= 49:
			receipt_fields.append("pricing")
		if not restored_transit.has_all(receipt_fields) or restored_transit.size() != receipt_fields.size():
			return false
		if not _integer(restored_transit.get("pricing", LEGACY_JUMP_PRICING), LEGACY_JUMP_PRICING, MASS_JUMP_PRICING):
			return false
		restored_pricing = int(restored_transit.get("pricing", LEGACY_JUMP_PRICING))
		if not _integer(restored_transit.fare, 1, int(restored_ship.jump_capacity())):
			return false
		var reserve_before_charge := restored_ship.jump_fuel + float(restored_transit.fare)
		var base_fare := Catalog.jump_cost(restored_system, restored_jump)
		var fare := restored_ship.legacy_jump_tariff(base_fare) if restored_pricing == LEGACY_JUMP_PRICING \
			else restored_ship.jump_tariff(base_fare, restored_mining.ore_hold, reserve_before_charge)
		var duration := restored_ship.jump_duration(Catalog.jump_distance(restored_system, restored_jump), restored_mining.ore_hold)
		if restored_dock >= 0 or restored_landing >= 0 or restored_departure or fare <= 0 or duration <= 0.0:
			return false
		if not _number(restored_transit.remaining, 0.000001, JUMP_TRANSIT_WALL) or not _integer(restored_transit.fare, fare, fare):
			return false
		if not _number(restored_transit.duration, duration, duration) or restored_epoch + duration > SAVE_CLOCK_LIMIT:
			return false
		if reserve_before_charge > restored_ship.jump_capacity() or not restored_velocity.is_zero_approx() or float(state.throttle) != 0.0:
			return false
	var interrupted: Array[String] = []
	if not pre_resume:
		var resume: Variant = state.get("resume")
		if not resume is Dictionary or resume.size() != 3 or not resume.get("interrupted") is Array:
			return false
		if not restored_patrol.restore_combat_clock(resume.get("patrol_clock")) or not restored_convoy_order.restore_combat_clock(resume.get("convoy_clock")):
			return false
		if resume.interrupted.size() > INTERRUPTED_LABELS.size():
			return false
		for mode: Variant in resume.interrupted:
			if not mode is String or not INTERRUPTED_LABELS.has(mode) or mode in interrupted:
				return false
			if mode in POWERED_ASSISTS and float(state.throttle) != 0.0:
				return false
			interrupted.append(mode)
		if "unpaid_jump_charge" in interrupted and (restored_jump < 0 or not restored_transit.is_empty()):
			return false
	var restored_combat := CombatSystems.new()
	var restored_ambient := CivilianTraffic.new()
	if not pre_ambient_traffic:
		var ambient_state: Variant = state.get("ambient")
		if not restored_ambient.restore(ambient_state, restored_epoch):
			return false
		var engaged := int(ambient_state.engaged_system)
		if engaged != -1 and (engaged != restored_system or restored_dock >= 0 or restored_landing >= 0 or not restored_transit.is_empty()):
			return false
	var restored_speed := SpeedHold.new()
	if not pre_speed_hold and not restored_speed.restore(state.get("speed_hold")):
		return false
	if restored_speed.enabled and (restored_dock >= 0 or restored_landing >= 0 or not restored_transit.is_empty() or float(state.throttle) != 0.0):
		return false
	if not pre_combat and not restored_combat.restore(state.get("combat"), restored_epoch, restored_system):
		return false
	if not restored_combat.projectile_status().is_empty() and (restored_dock >= 0 or restored_landing >= 0 or not restored_transit.is_empty()):
		return false
	var restored_gear_command := restored_landing >= 0 or Ground.is_port(restored_dock)
	var restored_gear := 1.0 if restored_gear_command else 0.0
	if not pre_gear:
		if not _number(state.get("gear_extension"), 0.0, 1.0) or not state.get("gear_deployed") is bool:
			return false
		if restored_dock >= 0 or restored_landing >= 0:
			if float(state.gear_extension) != restored_gear or state.gear_deployed != restored_gear_command:
				return false
		restored_gear = float(state.gear_extension)
		restored_gear_command = state.gear_deployed
	if restored_plan >= 0:
		if Catalog.system_of_site(restored_plan) != restored_system or not _site_available(restored_plan, restored_expedition, restored_cartography) or restored_plan == restored_dock or restored_plan == restored_landing or (restored_dock < 0 and restored_landing < 0):
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
	# The new gas giant can overlap a valid position from a pre-giant flight.
	if pre_dual_fuel and restored_system == Catalog.HOME_SYSTEM and restored_dock < 0 and restored_landing < 0:
		var giant := Catalog.GAS_GIANT_ID
		if _inside_hull(restored_position, giant, restored_epoch):
			var center: Vector3 = Orbit.sample(giant, restored_epoch).position
			restored_position = center + Vector3.BACK * float(Catalog.site(giant).gate_offset)
			restored_velocity = Vector3.ZERO
	if pre_rich_systems and restored_system >= Catalog.PRE_ATLAS_SYSTEM_COUNT and restored_dock < 0 and restored_landing < 0:
		var obstacle := _obstacle_at(restored_position, restored_system, restored_epoch, restored_expedition, restored_cartography)
		if obstacle >= Catalog.PRE_RICH_SYSTEMS_DESTINATION_COUNT:
			var body := Orbit.sample(obstacle, restored_epoch)
			restored_position = body.position + Vector3.BACK * float(Catalog.site(obstacle).gate_offset)
			restored_velocity = body.velocity
	if pre_rotation and not pre_procedural and restored_dock < 0 and restored_landing < 0:
		var obstacle := _obstacle_at(restored_position, restored_system, restored_epoch, restored_expedition, restored_cartography)
		if Terrain.spin_rate(obstacle) > 0.0 and not _inside_hull(restored_position, obstacle, restored_epoch, true):
			restored_position = _outside_rotating_surface(restored_position, obstacle, restored_epoch)
			restored_velocity = Vector3.ZERO
	# Keep a clear old position. Resolve only overlaps introduced by the new
	# hardware or by the terrain and berths rotating into an existing flight.
	if pre_lazur_spin and restored_system == Catalog.VELAR_SYSTEM and restored_dock < 0 and restored_landing < 0:
		var overlap := _obstacle_at(restored_position, restored_system, restored_epoch, restored_expedition, restored_cartography)
		if overlap == Catalog.GROUND_BODY or Ground.is_port(overlap):
			if (Ground.is_port(overlap) and pre_ground_ports) or not _inside_hull(restored_position, overlap, restored_epoch, true):
				restored_position = _outside_rotating_surface(restored_position, overlap, restored_epoch)
				var remaining := _obstacle_at(restored_position, restored_system, restored_epoch, restored_expedition, restored_cartography)
				if Ground.is_port(remaining):
					restored_position = _outside_rotating_surface(restored_position, remaining, restored_epoch)
				restored_velocity = Vector3.ZERO
	var velocity_limit := MAX_SAVED_SPEED if schema >= 6 else MAX_SPEED * 1.56
	if restored_velocity.length() > velocity_limit or (restored_dock < 0 and restored_landing < 0 and _blocked(restored_position, restored_system, restored_epoch, restored_expedition, restored_cartography)):
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
	time_paused = false if pre_calendar else state.time_paused
	docked = restored_dock
	dock_access = restored_access
	_departure_requested = restored_departure
	_departure_seconds = restored_departure_seconds
	landed_site = restored_landing
	landing_direction = restored_direction
	gear_extension = restored_gear
	gear_deployed = restored_gear_command
	mining = restored_mining
	ship = restored_ship
	market = restored_market
	freight = restored_freight
	patrol = restored_patrol
	expedition = restored_expedition
	factions = restored_factions
	convoy_order = restored_convoy_order
	passengers = restored_passengers
	crew = restored_crew
	cartography = restored_cartography
	frame = restored_frame
	customs = restored_customs
	_port_account = restored_port_account
	_civic = restored_civic
	remote_rig = restored_remote_rig
	orbital_mining = restored_orbital_mining
	_cargo_pods = restored_cargo_pods
	combat = restored_combat
	ambient = restored_ambient
	career = restored_career
	story = restored_story
	news = restored_news
	speed_hold = restored_speed
	_mining_beam.clear()
	star_heat = 0.0 if pre_thermal else float(state.star_heat)
	entry_heat = 0.0 if pre_entry else float(state.entry_heat)
	_entry_site = -1
	_reset_scoop()
	system_id = restored_system
	jump_target = restored_jump
	_jump_route = restored_route
	jump_seconds_left = float(restored_transit.get("remaining", 0.0))
	_jump_transit_duration = float(restored_transit.get("duration", 0.0))
	_jump_paid_fare = int(restored_transit.get("fare", 0))
	_jump_paid_pricing = restored_pricing
	target = int(state.target)
	planned_target = restored_plan
	credits = int(state.credits)
	deliveries = int(state.deliveries)
	contract_stage = stage
	contract_origin = origin
	_contract_issuer = restored_contract_issuer
	contract_destination = destination
	contract_route_id = route_id
	contract_leg = leg
	boost = false
	if docked >= 0:
		if _departure_seconds >= 0.0:
			_hold_departure_pose()
		else:
			_hold_docked_pose()
	elif landed:
		_hold_landed_pose()
	status_event = ""
	status_message = ""
	if not interrupted.is_empty():
		var names := PackedStringArray()
		for mode: String in interrupted:
			names.append(str(INTERRUPTED_LABELS[mode]))
		_announce("flight_restore_interruptions", "Временные режимы остановлены при загрузке (%s). Их можно включить снова." % ", ".join(names))
	return true


func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= minimum and value <= maximum


func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floorf(float(value))
