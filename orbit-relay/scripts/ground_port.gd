extends RefCounted
## Local berth geometry and its attachment to the moving terrain.

const Catalog := preload("res://scripts/sector_catalog.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const FOUNDATION_DEPTH := 8.0
const DECK_HEIGHT := -1.6
const DECK_RADIUS := 12.0
const HANGAR_APERTURE := 4.4
const HANGAR_TOP := 6.0
const BERTH_CLEARANCE := 6.0

static var _anchors := _build_anchors()


static func is_port(id: int) -> bool:
	return id == Catalog.GROUND_PAD or id == Catalog.GROUND_HANGAR


static func is_hangar(id: int) -> bool:
	return id == Catalog.GROUND_HANGAR


static func body(id: int) -> int:
	return int(Catalog.site(id).get("ground_body", -1))


static func anchor_offset(id: int, epoch: float) -> Vector3:
	if not is_port(id):
		return Vector3.ZERO
	return Terrain.spin_basis(body(id), epoch) * _anchors[id].offset


static func basis(id: int, epoch: float) -> Basis:
	if not is_port(id):
		return Basis.IDENTITY
	return Terrain.spin_basis(body(id), epoch) * _anchors[id].frame


static func local_hull(id: int, relative: Vector3) -> bool:
	if not is_port(id) or not relative.is_finite() or relative.z < -FOUNDATION_DEPTH:
		return false
	var radius_squared := Vector2(relative.x, relative.y).length_squared()
	if radius_squared >= DECK_RADIUS * DECK_RADIUS:
		return false
	if relative.z < DECK_HEIGHT:
		return true
	return is_hangar(id) and relative.z <= HANGAR_TOP and radius_squared >= HANGAR_APERTURE * HANGAR_APERTURE


static func hull_entry(id: int, start: Vector3, end: Vector3) -> float:
	if local_hull(id, start):
		return 0.0
	var motion := end - start
	var cuts: Array[float] = [0.0, 1.0]
	if not is_zero_approx(motion.z):
		for plane: float in [DECK_HEIGHT, -FOUNDATION_DEPTH, HANGAR_TOP]:
			var time: float = (plane - start.z) / motion.z
			if time > 0.0 and time < 1.0:
				cuts.append(time)
	var ray := Vector2(motion.x, motion.y)
	var a := ray.length_squared()
	if a > 0.0:
		var from := Vector2(start.x, start.y)
		var b := ray.dot(from)
		for radius: float in [DECK_RADIUS, HANGAR_APERTURE]:
			var discriminant := b * b - a * (from.length_squared() - radius * radius)
			if discriminant >= 0.0:
				var root := sqrt(discriminant)
				for time: float in [(-b - root) / a, (-b + root) / a]:
					if time > 0.0 and time < 1.0:
						cuts.append(time)
	cuts.sort()
	for i in range(cuts.size() - 1):
		if local_hull(id, start + motion * ((cuts[i] + cuts[i + 1]) * 0.5)):
			return cuts[i]
	return 1.0 if local_hull(id, end) else -1.0


static func _build_anchors() -> Dictionary:
	var result := {}
	for id in [Catalog.GROUND_PAD, Catalog.GROUND_HANGAR]:
		var host := body(id)
		var direction: Vector3 = Catalog.site(id).ground_direction.normalized()
		var frame := Terrain.basis(host, direction)
		var offset := Terrain.point(host, direction) + frame.z * BERTH_CLEARANCE
		result[id] = {"offset": offset, "frame": frame}
	return result
