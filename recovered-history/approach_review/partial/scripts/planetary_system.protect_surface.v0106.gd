func protect_surface(ship: RefCounted, days: float) -> bool:
	var center := local_meters(focus_id,days)
	var offset: Vector3 = ship.position-center
	var safe: float = by_id[focus_id].radius_km*1000.0+2000.0
	if offset.length()>=safe: return false
	var direction := offset.normalized() if offset.length()>0.1 else Vector3.UP
	ship.position = center+direction*(safe+50.0)
	ship.velocity = direction*10.0
	ship.target_speed = 0
	ship.autopilot = false
	ship.hull = maxf(0,ship.hull-10)
	message = "Опасное сближение с поверхностью. Для посадки используйте «К поверхности»."
	return true

func snapshot() -> Dictionary:
	var result:={"version":3,"layout":layout_mode,"system_id":system_id,"focus_id":focus_id,"selected_id":selected_id,"site_id":site_id}
	if layout_mode=="source_v1":result.version=4;result.source_digest=source_digest
	return result
