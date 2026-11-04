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

func is_orbital_site()->bool:
	var site:=current_site()
	return not site.is_empty() and int(site.type_code)<35
func begin_site_transfer(id:String,ship:RefCounted,nav:RefCounted)->bool:
	var site:=get_site(id)
	if site.is_empty():message="Неизвестное поселение.";return false
	if transfer_remaining>0:message="Сначала отмените текущий перелёт.";return false
	if id==site_id:message="Вы уже у выбранного поселения.";return false
	if int(site.type_code)==35:
		var body:Dictionary=by_id[site.parent]
		var g:float=6.67430e-11*1.98847e30*float(body.mass_solar)/pow(float(body.radius_km)*1000,2)
		if body.kind in ["star","barycenter","gas","ice_gas"] or g>ship.acceleration()*0.8:
			message="Нет безопасного входа к этому космопорту при текущей тяге.";return false
	var previous:=selected_id
	selected_id=str(site.parent)
	if not begin_transfer(ship,nav,id):selected_id=previous;return false
	return true
