extends RefCounted
## Approximate solids matching the hub, arms and ring on the visible port models.

const RING_PORTS := [3, 10]


static func contains(port: int, point: Vector3) -> bool:
	var radial := Vector2(point.x, point.y).length()
	if radial > 25.0 or point.z < -9.0 or point.z > 2.65:
		return false
	if point.z >= -8.55 and point.z <= 1.33 and radial < lerpf(9.2, 7.0, inverse_lerp(-8.55, 1.33, point.z)):
		return true
	if point.z > 1.3 and radial >= 4.4 and radial <= 7.0:
		return true
	if port in RING_PORTS:
		if point.z > -2.1 or point.z < -7.1:
			return false
		if radial >= 15.1 and radial <= 20.65:
			return true
		return _arms(point, 8, PI * 0.125, 7.0, 18.0, 0.72, -3.8, 1.0)
	if port == 0:
		if _arms(point, 4, PI * 0.5, 6.0, 20.0, 1.49, -4.0, 1.85):
			return true
		for arm in range(4):
			var panel := Vector2(point.x, point.y).rotated(-TAU * float(arm + 1) / 4.0)
			if panel.x > 11.0 and panel.x < 22.0 and absf(absf(panel.y) - 4.0) < 3.0 and absf(point.z + 4.3) < 0.66:
				return true
		return false
	if _arms(point, 3, PI * 0.16, 6.3, 18.7, 2.25, -6.0, 2.25):
		return true
	for arm in range(3):
		var pod := Vector2.from_angle(TAU * float(arm) / 3.0 + PI * 0.16) * 17.0
		if Vector2(point.x, point.y).distance_squared_to(pod) < 4.8 * 4.8 and absf(point.z + 4.0) < 4.55:
			return true
	return false


static func _arms(point: Vector3, count: int, base: float, start: float, end: float, width: float, z: float, depth: float) -> bool:
	if absf(point.z - z) > depth:
		return false
	for arm in range(count):
		var local := Vector2(point.x, point.y).rotated(-base - TAU * float(arm) / float(count))
		if local.x >= start and local.x <= end and absf(local.y) < width:
			return true
	return false
