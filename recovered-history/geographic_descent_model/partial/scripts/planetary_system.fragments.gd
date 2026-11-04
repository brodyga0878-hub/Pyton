func local_meters(id: String, days: float) -> Vector3:
	var p := position_au(id,days)
	var origin := origin_au(days)
	# Subtract in double precision before constructing the float32 Vector3.
	return Vector3((p[0]-origin[0])*AU_METERS,(p[1]-origin[1])*AU_METERS,(p[2]-origin[2])*AU_METERS)

func select(id: String) -> bool:
	if not by_id.has(id) or transfer_remaining>0: return false
	selected_id = id
	return true

func can_transfer(ship: RefCounted, nav: RefCounted, destination_site:String="") -> String:
	if transfer_remaining>0: return "Автоперелёт уже готовится."
	if ship.hull<=0: return "Корабль потерян."
	if ship.surface_mode: return "Сначала вернитесь на орбиту."
	if ship.combat_active: return "Сначала выйдите из боя."
	if ship.docked: return "Сначала вылетите со станции."
	if nav.remaining>0: return "Сначала отмените гиперпереход."
	if selected_id==focus_id and destination_site.is_empty() and site_id.is_empty():
		if not (focus_id==default_id and nav.has_station() and ship.position.distance_to(ship.STATION)>1000):return "Вы уже у выбранного объекта."
	if str(by_id[selected_id].kind) in ["star","barycenter"]: return "Непосредственный подлёт к звезде заблокирован."
	if ship.velocity.length()>20: return "Затормозите до 20 м/с."
	if ship.station_available and ship.position.distance_to(ship.STATION)<400: return "Отойдите от станции минимум на 400 м."
	return ""

# [gap: intervening source was not read in this agent's history]

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
