extends RefCounted
## Positions and velocities of autonomous craft in the active system.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const Freight = preload("res://scripts/npc_freight.gd")
const CONVOY_NAMES := ["Конвой Маяков", "Конвой Лиги"]
const TRADE_PERIOD := 106.0
const PATROL_PERIOD := 54.0


static func contacts(sim: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ports: Array = sim.local_ports()
	if ports.is_empty():
		return result
	var first: int = ports[0]
	var departure: Vector3 = sim.target_gate(first) + Vector3(0.0, 106.0, 26.0)
	var departure_velocity: Vector3 = sim.target_velocity(first)
	var services: Array = sim.freight.services(int(sim.system_id), float(sim.orbit_time))
	var has_local_service := false
	for service: Dictionary in services:
		if bool(service.get("interstellar", false)):
			var contact := _interstellar_contact(sim, service)
			if not contact.is_empty():
				result.append(contact)
		else:
			has_local_service = true
			result.append(_freighter_contact(sim, service))
	if not has_local_service and ports.size() == 1:
		# The original colony loiterer remains separate from visiting interstellar
		# freighters, including when they disappear from the local frame to jump.
		var rate := TAU / TRADE_PERIOD
		var angle := fposmod(float(sim.orbit_time), TRADE_PERIOD) * rate + 0.55
		var at := departure + Vector3(250.0 * cos(angle), sin(angle * 2.0) * 25.0, 176.0 * sin(angle))
		var velocity := departure_velocity + Vector3(-250.0 * sin(angle) * rate, cos(angle * 2.0) * rate * 50.0, 176.0 * cos(angle) * rate)
		var sample := clear_hulls(sim, at, velocity)
		result.append({
			"id": "trader-%d-0" % sim.system_id, "name": Freight.TRADER_NAMES[0], "role": "trader",
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
	for convoy: Dictionary in sim.factions.active_convoys(sim.system_id):
		result.append(_convoy_contact(sim, first, convoy))
	return result


static func _freighter_contact(sim: RefCounted, service: Dictionary) -> Dictionary:
	# Berths depend on port and ship slot, never on the direction of a leg.
	# Arrival may relabel destination as origin while progress returns to zero;
	# the physical endpoint and its orbital drift therefore remain identical.
	var side := 1.0 if int(service.slot) == 0 else -1.0
	var berth_offset := Vector3(side * 34.0, 30.0, 24.0)
	var departure: Vector3 = sim.target_gate(int(service.origin)) + berth_offset
	var arrival: Vector3 = sim.target_gate(int(service.destination)) + berth_offset
	var departure_velocity: Vector3 = sim.target_velocity(int(service.origin))
	var arrival_velocity: Vector3 = sim.target_velocity(int(service.destination))
	var lane := arrival - departure
	var progress := float(service.progress)
	var advance := float(service.speed_fraction)
	# This bow and its derivative vanish at both ends. A fixed world-space
	# bow also avoids a lateral sign flip when the two route endpoints swap.
	var bow := Vector3(side * 46.0, 28.0, 0.0)
	var bend := 16.0 * progress * progress * (1.0 - progress) * (1.0 - progress)
	var bend_slope := 32.0 * progress * (1.0 - progress) * (1.0 - 2.0 * progress)
	var at := departure.lerp(arrival, progress) + bow * bend
	var drift := departure_velocity.lerp(arrival_velocity, progress)
	var course := lane + bow * bend_slope
	var velocity := drift + course * advance
	var sample := clear_hulls(sim, at, velocity)
	# Subtract the co-moving solution from its unit-progress derivative. The
	# clearance map is affine in velocity at a fixed position, so this retains
	# its climb without orbital drift or a zero-speed division at the berth.
	var coasting := clear_hulls(sim, at, drift)
	var advancing := clear_hulls(sim, at, drift + course)
	var forward: Vector3 = advancing.velocity - coasting.velocity
	if not bool(service.in_transit) and int(service.last_port) >= 0:
		# Turn the nose during the real layover, not instantly at the delivery
		# boundary. The next destination is also the previous origin on a shuttle.
		var turn := clampf(1.0 - float(service.departure_eta) / Freight.LAYOVER_SECONDS, 0.0, 1.0)
		var direction := forward.normalized()
		var axis := Vector3.UP - direction * direction.y
		if axis.length_squared() < 0.0001:
			axis = Vector3.RIGHT - direction * direction.x
		forward = (-direction).rotated(axis.normalized(), PI * smoothstep(0.0, 1.0, turn))
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	return {
		"id": str(service.id), "name": str(service.name), "role": "trader",
		"position": sample.position, "velocity": sample.velocity, "forward": forward.normalized(), "hull": 100.0,
		"freight": service.duplicate(true),
	}


static func _interstellar_contact(sim: RefCounted, service: Dictionary) -> Dictionary:
	var port := int(service.local_port)
	var phase := str(service.visual_phase)
	if Catalog.system_of_site(port) != int(sim.system_id) or not sim.station_operational(port) \
			or phase not in ["waiting", "departure", "arrival"]:
		return {}
	# Each endpoint owns its own local lane. Remote coordinates never enter it.
	# Both visiting services have berths clear of the dock and the local shuttles.
	var side := 1.0 if int(service.slot) % 2 == 0 else -1.0
	var berth := Vector3(side * 72.0, 57.0, 48.0)
	var jump := _shuttle_jump_offset(int(service.slot))
	var lane := jump - berth
	var progress := float(service.local_progress)
	var advance := float(service.local_speed_fraction)
	var bow := Vector3(side * 32.0, 42.0, 0.0)
	var bend := 16.0 * progress * progress * (1.0 - progress) * (1.0 - progress)
	var bend_slope := 32.0 * progress * (1.0 - progress) * (1.0 - 2.0 * progress)
	var at: Vector3 = sim.target_gate(port) + berth.lerp(jump, progress) + bow * bend
	var drift: Vector3 = sim.target_velocity(port)
	var course := lane + bow * bend_slope
	var sample := clear_hulls(sim, at, drift + course * advance)
	var coasting := clear_hulls(sim, at, drift)
	var advancing := clear_hulls(sim, at, drift + course)
	var forward: Vector3 = advancing.velocity - coasting.velocity
	if phase == "arrival":
		forward = -forward
	elif phase == "waiting" and int(service.last_port) == port:
		var turn := clampf(1.0 - float(service.departure_eta) / Freight.LAYOVER_SECONDS, 0.0, 1.0)
		var direction := forward.normalized()
		var axis := Vector3.UP - direction * direction.y
		if axis.length_squared() < 0.0001:
			axis = Vector3.RIGHT - direction * direction.x
		forward = (-direction).rotated(axis.normalized(), PI * smoothstep(0.0, 1.0, turn))
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	return {
		"id": str(service.id), "name": str(service.name), "role": "trader",
		"position": sample.position, "velocity": sample.velocity, "forward": forward.normalized(), "hull": 100.0,
		"freight": service.duplicate(true),
	}


static func hyperspace_echo_position(sim: RefCounted, port: int, slot: int) -> Vector3:
	var at: Vector3 = sim.target_gate(port) + _shuttle_jump_offset(slot)
	return clear_hulls(sim, at, sim.target_velocity(port)).position


static func _shuttle_jump_offset(slot: int) -> Vector3:
	var side := 1.0 if slot % 2 == 0 else -1.0
	return Vector3(side * 840.0, 325.0, 690.0)


static func convoy_contact(sim: RefCounted, id: String) -> Dictionary:
	if id.is_empty():
		return {}
	var convoy: Dictionary = sim.factions.convoy(sim.system_id, id)
	if convoy.is_empty() or convoy.stage != "en_route":
		return {}
	var ports: Array = sim.local_ports()
	return {} if ports.is_empty() else _convoy_contact(sim, int(ports[0]), convoy)


static func _convoy_contact(sim: RefCounted, port: int, convoy: Dictionary) -> Dictionary:
	# The two factions use opposite lanes and approach rally points clear of the dock.
	var faction: int = convoy.faction
	var side := -1.0 if faction == 0 else 1.0
	var gate: Vector3 = sim.target_gate(port)
	var start := gate + Vector3(side * 542.0, 154.0, 378.0)
	var finish := gate + Vector3(side * 126.0, 73.0, -82.0)
	var route := finish - start
	var duration := float(convoy.due_at) - float(convoy.launched_at)
	var progress := clampf((float(sim.orbit_time) - float(convoy.launched_at)) / duration, 0.0, 1.0)
	var drift: Vector3 = sim.target_velocity(port)
	var sample := clear_hulls(sim, start + route * progress, drift + route / duration, 28.0)
	return {
		"id": convoy.id, "name": CONVOY_NAMES[faction], "role": "convoy",
		"position": sample.position, "velocity": sample.velocity, "hull": 100.0,
		"route_start": start, "route_end": finish,
	}


static func clear_hulls(sim: RefCounted, at: Vector3, velocity: Vector3, margin := 22.0, system := -1) -> Dictionary:
	# Raise the lane smoothly before it crosses a hull's horizontal projection.
	# The derivative keeps the nose of a model aligned during the climb.
	var sector: int = sim.system_id if system < 0 else system
	var star := Catalog.star_for(sector)
	var rise := 0.0
	var climb := 0.0
	for id: int in Catalog.targets_for(sector):
		if Catalog.is_port(id) and not sim.station_operational(id):
			continue
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
