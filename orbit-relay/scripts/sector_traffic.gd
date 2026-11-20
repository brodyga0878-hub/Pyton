extends RefCounted
## Positions and velocities of autonomous civilian craft in the active system.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const TRADER_NAMES := ["Торговец «Вектор»", "Торговец «Каскад»"]
const TRADE_PERIOD := 106.0
const PATROL_PERIOD := 54.0


static func contacts(sim: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ports := Catalog.ports_for(sim.system_id)
	if ports.is_empty():
		return result
	var first: int = ports[0]
	var last: int = ports[ports.size() - 1]
	var departure: Vector3 = sim.target_gate(first) + Vector3(0.0, 106.0, 26.0)
	var arrival: Vector3 = sim.target_gate(last) + Vector3(0.0, 106.0, 26.0)
	var departure_velocity: Vector3 = sim.target_velocity(first)
	var arrival_velocity: Vector3 = sim.target_velocity(last)
	var lane := arrival - departure
	var cross_lane := Vector3.UP.cross(lane)
	var lateral := Vector3.RIGHT
	var lateral_velocity := Vector3.ZERO
	if cross_lane.length_squared() > 0.01:
		lateral = cross_lane.normalized()
		var cross_velocity := Vector3.UP.cross(arrival_velocity - departure_velocity)
		lateral_velocity = cross_velocity.slide(lateral) / cross_lane.length()
	for index in range(TRADER_NAMES.size()):
		var rate := TAU / TRADE_PERIOD
		var angle := fposmod(float(sim.orbit_time), TRADE_PERIOD) * rate + 0.55 + PI * index
		var fraction := (1.0 - cos(angle)) * 0.5
		var advance := 0.5 * sin(angle) * rate
		var side := 46.0 if index == 0 else -46.0
		var height := Vector3.UP * (sin(angle * 2.0) * 25.0)
		var climb := Vector3.UP * (cos(angle * 2.0) * rate * 50.0)
		var sample := clear_hulls(
			sim, departure + lane * fraction + lateral * side + height,
			departure_velocity.lerp(arrival_velocity, fraction) + lane * advance + lateral_velocity * side + climb,
		)
		result.append({
			"id": "trader-%d-%d" % [sim.system_id, index], "name": TRADER_NAMES[index], "role": "trader",
			"position": sample.position, "velocity": sample.velocity, "hull": 100.0,
		})
	var patrol_rate := TAU / PATROL_PERIOD
	var patrol_angle := fposmod(float(sim.orbit_time), PATROL_PERIOD) * patrol_rate + 0.7
	var patrol_offset := Vector3(164.0 * cos(patrol_angle), 74.0 + 18.0 * sin(patrol_angle * 2.0), 110.0 * sin(patrol_angle))
	var patrol_drift := Vector3(-164.0 * sin(patrol_angle), 36.0 * cos(patrol_angle * 2.0), 110.0 * cos(patrol_angle)) * patrol_rate
	var sample := clear_hulls(sim, sim.target_gate(first) + patrol_offset, departure_velocity + patrol_drift)
	result.append({
		"id": "patrol-%d" % sim.system_id, "name": "Патруль «Дозор»", "role": "patrol",
		"position": sample.position, "velocity": sample.velocity, "hull": 100.0,
	})
	return result


static func clear_hulls(sim: RefCounted, at: Vector3, velocity: Vector3, margin := 22.0, system := -1) -> Dictionary:
	# Raise the lane smoothly before it crosses a hull's horizontal projection.
	# The derivative keeps the nose of a model aligned during the climb.
	var sector: int = sim.system_id if system < 0 else system
	var star := Catalog.star_for(sector)
	var rise := 0.0
	var climb := 0.0
	for id: int in Catalog.targets_for(sector):
		var center: Vector3 = sim.target_position(id)
		var radius := float(Catalog.site(id).radius)
		if id == star:
			radius = Catalog.STAR_CLEARANCE
		elif Catalog.is_mine_site(id):
			radius = radius * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE
		var needed := center.y + radius + margin - at.y
		if needed <= 0.0:
			continue
		var delta := Vector2(at.x - center.x, at.z - center.z)
		var distance := delta.length()
		var blend_span := 96.0
		var progress := clampf((distance - radius - margin) / blend_span, 0.0, 1.0)
		var weight := 1.0 - smoothstep(0.0, 1.0, progress)
		var added := needed * weight
		if added <= rise:
			continue
		var body_drift: Vector3 = sim.target_velocity(id)
		var relative_drift := Vector2(velocity.x - body_drift.x, velocity.z - body_drift.z)
		var distance_rate := delta.normalized().dot(relative_drift)
		var weight_rate := -6.0 * progress * (1.0 - progress) * distance_rate / blend_span
		rise = added
		climb = (body_drift.y - velocity.y) * weight + needed * weight_rate
	return {"position": at + Vector3.UP * rise, "velocity": velocity + Vector3.UP * climb}
