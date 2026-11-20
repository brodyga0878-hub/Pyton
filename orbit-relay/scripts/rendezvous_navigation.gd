extends RefCounted
## A moving stand-off point and its interception along the local ephemeris.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")

const GAPS := [150, 300, 600]
const CRUISE_SPEED := 100.0
const MAX_INTERCEPT_SECONDS := 240.0
const INTERCEPT_TOLERANCE := 0.002
const TERMINAL_DISTANCE := 220.0


static func supports(site: int) -> bool:
	return Catalog.is_port(site) or Catalog.is_mine_site(site)


static func choose_offset(sim: RefCounted, site: int, gap: float) -> Vector3:
	if not supports(site) or Catalog.system_of_site(site) != sim.system_id or not is_finite(gap) or gap <= 0.0:
		return Vector3.ZERO
	var radius := float(Catalog.site(site).radius)
	if Catalog.is_port(site):
		return sim.station_axis(site) * (radius + gap)
	var center: Vector3 = sim.target_position(site)
	var facing: Vector3 = center.direction_to(sim.position)
	if facing.is_zero_approx():
		facing = Vector3.BACK
	var envelope := radius * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE
	return facing * (envelope + gap)


static func plan(sim: RefCounted, site: int, offset: Vector3) -> Dictionary:
	if not supports(site) or Catalog.system_of_site(site) != sim.system_id or not offset.is_finite():
		return {"point": Vector3.ZERO, "velocity": Vector3.ZERO, "predicted": Vector3.ZERO, "eta": 0.0}
	var point: Vector3 = sim.target_position(site) + offset
	var velocity: Vector3 = sim.target_velocity(site)
	var position: Vector3 = sim.position
	var cruise := CRUISE_SPEED if sim.ship.fuel > 0.0 else minf(CRUISE_SPEED, sim.RESERVE_SPEED)
	var eta := minf(position.distance_to(point) / cruise, MAX_INTERCEPT_SECONDS)
	var epoch: float = sim.orbit_time
	# Orbital motion is much slower than cruise, so this bounded iteration
	# converges quickly while following the curved ephemeris instead of a linear lead.
	for attempt in range(7):
		var lead: Vector3 = Orbit.sample(site, epoch + eta).position + offset
		var corrected := minf(position.distance_to(lead) / cruise, MAX_INTERCEPT_SECONDS)
		if absf(corrected - eta) <= INTERCEPT_TOLERANCE:
			break
		eta = corrected
	var predicted: Vector3 = Orbit.sample(site, epoch + eta).position + offset
	return {"point": point, "velocity": velocity, "predicted": predicted, "eta": eta}


static func route_waypoint(sim: RefCounted, intercept: Dictionary) -> Vector3:
	var position: Vector3 = sim.position
	var destination: Vector3 = intercept.point if position.distance_to(intercept.point) <= TERMINAL_DISTANCE else intercept.predicted
	var waypoint: Vector3 = sim._star_detour(destination)
	var obstacle: int = sim._transit_obstacle(waypoint - position, CRUISE_SPEED, false)
	if obstacle >= 0:
		waypoint = sim._star_detour(sim._transit_waypoint(obstacle, waypoint - position))
	return waypoint
