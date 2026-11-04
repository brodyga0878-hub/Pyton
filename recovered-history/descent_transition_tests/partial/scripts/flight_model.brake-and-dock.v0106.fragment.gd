
func brake() -> void:
	target_speed = 0.0
	assisted = true
	autopilot = false

func can_dock() -> bool:
	return not surface_mode and not combat_active and hull>0 and station_available and position.distance_to(STATION) <= DOCK_RADIUS and velocity.length() <= DOCK_SPEED

func dock() -> bool:
	if not can_dock():
		return false
	docked = true
	autopilot = false
	velocity = Vector3.ZERO
	target_speed = 0.0
	return true

func launch() -> void:
