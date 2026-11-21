extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")
const Ground := preload("res://scripts/ground_port.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const Atmosphere := preload("res://scripts/atmosphere.gd")
const MIN_GUIDE_LENGTH := 110.0
const GUIDE_HORIZON := 6200.0
const BODY_STANDOFF := 24.0


static func project(flight: RefCounted, camera: Camera3D, sites: Array) -> Array[Dictionary]:
	var bodies := _bodies(flight, sites)
	var start := camera.global_position
	var frame := camera.global_transform.affine_inverse()
	var result: Array[Dictionary] = []
	for body: Dictionary in bodies:
		var point: Vector3 = body.point
		var depth := -(frame * point).z
		if depth <= camera.near or depth >= camera.far or _occluded(start, point, body.id, bodies):
			continue
		result.append({
			"id": body.id,
			"screen": camera.unproject_position(point),
			"name": Catalog.site(body.id).name,
			"distance": start.distance_squared_to(point),
			"active": body.id == flight.target,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.active != b.active:
			return a.active
		return a.distance < b.distance if a.distance != b.distance else a.id < b.id)
	return result


static func is_visible(flight: RefCounted, camera: Camera3D, sites: Array, site: int) -> bool:
	var bodies := _bodies(flight, sites)
	for body: Dictionary in bodies:
		if body.id == site:
			var point: Vector3 = body.point
			var depth := -camera.to_local(point).z
			return depth > camera.near and depth < camera.far \
				and camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(point)) \
				and not _occluded(camera.global_position, point, site, bodies)
	return false


static func approach_corridor(flight: RefCounted, camera: Camera3D, sites: Array) -> Dictionary:
	var site: int = flight.target
	if site not in sites:
		return {}
	var bodies := _bodies(flight, sites)
	for body: Dictionary in bodies:
		if body.id == site:
			return _approach(flight, camera, body, bodies)
	return {}


static func _approach(flight: RefCounted, camera: Camera3D, body: Dictionary, bodies: Array[Dictionary]) -> Dictionary:
	var site: int = body.id
	var pilot: Vector3 = flight.position
	var center: Vector3 = body.center
	var radial := pilot - center
	var half_width := clampf(radial.length() * 0.024, 10.0, 32.0)
	var envelope := half_width * sqrt(2.0)
	var end: Vector3
	if Catalog.is_port(site):
		if flight.docking_guidance().near:
			return {}
		end = flight.target_gate(site)
	else:
		var boundary: float = body.radius
		var atmosphere_top := float(Catalog.site(site).radius) + float(Atmosphere.profile(site).get("height", 0.0))
		boundary = maxf(boundary, atmosphere_top)
		if Catalog.is_star(site):
			boundary = maxf(boundary, maxf(Catalog.stellar_clearance(site), Catalog.SCOOP_OUTER))
		var standoff := boundary + envelope + BODY_STANDOFF
		if radial.length() <= standoff:
			return {}
		end = center + radial.normalized() * standoff
	var path := end - pilot
	var length := path.length()
	var depth := -camera.to_local(end).z
	if length < MIN_GUIDE_LENGTH or length > GUIDE_HORIZON or depth <= camera.near or depth >= camera.far:
		return {}
	var start := pilot + path.normalized() * clampf(length * 0.16, 30.0, 140.0)
	# Reject a straight guide if the active route or the visible guide crosses a body.
	if _occluded(pilot, end, -1, bodies) or _occluded(start, end, -1, bodies, envelope):
		return {}
	if _occluded(camera.global_position, end, -1, bodies):
		return {}
	return {"start": start, "end": end, "half_width": half_width}


static func _bodies(flight: RefCounted, sites: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site: int in sites:
		var item := Catalog.site(site)
		var center: Vector3 = flight.target_position(site)
		var point := center
		var radius := float(item.radius)
		if Ground.is_port(site):
			var station_axis: Vector3 = flight.station_axis(site)
			point += station_axis * (Ground.HANGAR_TOP + 0.5)
			radius = Vector2(Ground.DECK_RADIUS, Ground.FOUNDATION_DEPTH).length()
		elif Catalog.is_mine_site(site):
			# The mesh can extend beyond its mean radius. Use the outer bound for picking.
			radius *= Terrain.MAX_RADIUS_FACTOR
		result.append({"id": site, "point": point, "center": center, "radius": radius})
	return result


static func _occluded(start: Vector3, point: Vector3, target: int, bodies: Array[Dictionary], padding := 0.0) -> bool:
	var ray := point - start
	var squared := ray.length_squared()
	for body: Dictionary in bodies:
		if body.id == target:
			continue
		var offset: Vector3 = body.center - start
		var radius := float(body.radius) + padding
		var radius_squared := radius * radius
		if offset.length_squared() <= radius_squared:
			# A camera close to uneven terrain may be inside its conservative sphere.
			# Outward rays leave the envelope without passing through the body.
			if offset.dot(ray) > 0.0:
				return true
			continue
		var nearest := clampf(offset.dot(ray) / squared, 0.0, 1.0)
		if (offset - ray * nearest).length_squared() < radius_squared:
			return true
	return false
