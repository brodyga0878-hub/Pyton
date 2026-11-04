# HISTORICAL FRAGMENT ONLY. These complete functions were read in inherited root context;
# this is NOT a complete flight_model.gd and does not define its fields/constants.
func forward() -> Vector3:
	return -(Basis(attitude).z)

func brake() -> void:
	target_speed = 0.0
	assisted = true
	autopilot = false

func can_dock() -> bool:
	return not surface_mode and not combat_active and hull>0 and station_available and position.distance_to(STATION) <= DOCK_RADIUS and velocity.length() <= DOCK_SPEED

func snapshot() -> Dictionary:
	return {"version": 4,"story_cargo":story_cargo, "goods":goods.duplicate(),"equipment":equipment.duplicate(),"mission_cargo":mission_cargo.duplicate(),"ship_id":ship_id,"external_view":external_view, "position": [position.x, position.y, position.z], "velocity": [velocity.x, velocity.y, velocity.z], "attitude": [attitude.x, attitude.y, attitude.z, attitude.w], "target_speed": target_speed, "assisted": assisted, "docked": docked, "hull": hull, "credits": credits, "cargo": cargo, "delivered": delivered}
