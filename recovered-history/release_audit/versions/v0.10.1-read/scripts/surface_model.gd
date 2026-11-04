extends RefCounted

const SegmentBox=preload("res://scripts/segment_box.gd")
const G := 6.67430e-11
const SOLAR_MASS := 1.98847e30
const LIMIT := 1750.0
const GRID_WIDTH:=4000.0
const GRID_CELLS:=96
var taking_off:=false
var active := false
var landed := false
var landing := false
var body_id := ""
var seed_value := 0
var gravity := 0.0
var orbit_position := Vector3.ZERO
var orbit_attitude := Quaternion.IDENTITY
var message := ""
var kind := "rock"
var site_name:=""

func raw_height_at(x: float, z: float) -> float:
	var phase:=float(seed_value&1023)*0.013
	var relief:=sin(x*0.003+phase)*cos(z*0.0023)*95+sin(z*0.008+x*0.004)*22
	# A flat, marked landing field blends into a deterministic patch of hills.
	return relief*smoothstep(100,420,Vector2(x,z).length())

func height_at(x: float, z: float) -> float:
	# Exact same diagonal and vertices as the rendered mesh, eliminating hill clipping.
	var cell:=GRID_WIDTH/GRID_CELLS
	var gx:=(x+GRID_WIDTH/2)/cell;var gz:=(z+GRID_WIDTH/2)/cell
	var ix:=floorf(gx);var iz:=floorf(gz);var fx:=gx-ix;var fz:=gz-iz
	var x0:=ix*cell-GRID_WIDTH/2;var z0:=iz*cell-GRID_WIDTH/2
	var a:=raw_height_at(x0,z0);var b:=raw_height_at(x0+cell,z0);var c:=raw_height_at(x0,z0+cell)
	if fx+fz<=1:return a+(b-a)*fx+(c-a)*fz
	var d:=raw_height_at(x0+cell,z0+cell)
	return d+(c-d)*(1-fx)+(b-d)*(1-fz)

func clearance(ship: RefCounted) -> float:
	return float(ship.profile().visual_span_m)*0.14+2.0

func altitude(ship: RefCounted) -> float:
	return ship.position.y-height_at(ship.position.x,ship.position.z)-clearance(ship)

func entry_error(ship: RefCounted, system: RefCounted) -> String:
	if active:return "Вы уже у поверхности."
	if ship.hull<=0:return "Корабль потерян."
	if ship.docked:return "Сначала вылетите со станции."
	if ship.combat_active:return "Сначала выйдите из боя."
	if system.transfer_remaining>0:return "Сначала отмените перелёт."
	var body: Dictionary=system.by_id[system.focus_id]
	if str(body.kind) in ["star","barycenter","gas","ice_gas"]:return "У этого объекта нет доступной твёрдой поверхности."
	if ship.velocity.length()>20:return "Затормозите до 20 м/с."
	var g:=G*float(body.mass_solar)*SOLAR_MASS/pow(float(body.radius_km)*1000,2)
	if g>ship.acceleration()*0.8:return "Недостаточно тяги для безопасного взлёта при этой гравитации."
	return ""

func enter(ship: RefCounted, system: RefCounted) -> bool:
	message=entry_error(ship,system)
	if message!="":return false
	var body: Dictionary=system.by_id[system.focus_id]
	body_id=system.focus_id
	kind=str(body.kind)
	seed_value=system.system_id^body_id.hash()
	site_name=""
	var site:Dictionary=system.current_site()
	if not site.is_empty() and int(site.type_code)==35:
		seed_value^=str(site.id).hash();site_name=str(site.name)
	gravity=G*float(body.mass_solar)*SOLAR_MASS/pow(float(body.radius_km)*1000,2)
	orbit_position=ship.position;orbit_attitude=ship.attitude
	active=true;landed=false;landing=false
	ship.surface_mode=true;ship.station_available=false;ship.autopilot=false
	ship.position=Vector3(0,1500,800)
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.assisted=true
	ship.attitude=Quaternion(Vector3.RIGHT,-0.35)
	message="Посадочная зона: %s. «Автопилот» — заход; «Стыковка» — мягкая посадка."%(site_name if not site_name.is_empty() else body.name)
	return true

func begin_landing(ship: RefCounted) -> bool:
	if not active or landed or ship.hull<=0:return false
	taking_off=false
	landing=not landing
	ship.autopilot=false;ship.target_speed=0
	message="Автоматический заход на площадку." if landing else "Заход отменён."
	return true

func step(dt: float, ship: RefCounted, steering: Vector2, roll: float, lift := 0.0) -> void:
	if not active or dt<=0 or ship.hull<=0:return
	if landed:
		ship.velocity=Vector3.ZERO;ship.target_speed=0
		return
	var previous:Vector3=ship.position
	if absf(lift)>0.1:landing=false;taking_off=false
	if taking_off:
		ship.velocity=ship.velocity.move_toward(Vector3.UP*15,maxf(0.1,ship.acceleration()-gravity)*dt)
		ship.position+=ship.velocity*dt
		if altitude(ship)>=35:taking_off=false;ship.brake()
	elif landing:
		var horizontal:=Vector3(-ship.position.x,0,-ship.position.z)
		var height:=maxf(0,ship.position.y-clearance(ship))
		var reserve:=maxf(0.1,ship.acceleration()-gravity)
		var desired:=horizontal.normalized()*minf(60,sqrt(horizontal.length()*reserve))
		desired.y=-minf(25,sqrt(maxf(0,height-0.3)*reserve)) if horizontal.length()<80 else clampf((200-ship.position.y)*0.1,-20,20)
		ship.velocity=ship.velocity.move_toward(desired,reserve*dt)
		ship.attitude=ship.attitude.slerp(Quaternion.IDENTITY,minf(1,dt*1.5)).normalized()
		ship.position+=ship.velocity*dt
	else:
		ship.step(dt,steering,roll,Vector3.DOWN*gravity,lift)
	_clip_buildings(previous,ship)
	if ship.hull<=0:return
	var radial:=Vector2(ship.position.x,ship.position.z)
	if radial.length()>LIMIT:
		var edge:=radial.normalized()*LIMIT
		ship.position.x=edge.x;ship.position.z=edge.y
		ship.velocity.x=0;ship.velocity.z=0
		ship.target_speed=0
		message="Граница посадочного района. Вернитесь к площадке или на орбиту."
	if ship.position.y>4000:
		ship.position.y=4000;ship.velocity.y=minf(ship.velocity.y,0);ship.target_speed=0
	if landing and altitude(ship)<=0.6 and ship.velocity.length()<=6:
		ship.position.y=height_at(ship.position.x,ship.position.z)+clearance(ship)
		ship.velocity=Vector3.ZERO;ship.target_speed=0;landing=false;landed=true
		message="Посадка выполнена. «Взлететь» — подъём над поверхностью."
	if altitude(ship)<=0 and not landed:
		var impact: float=ship.velocity.length()
		ship.position.y=height_at(ship.position.x,ship.position.z)+clearance(ship)
		ship.velocity=Vector3.ZERO;ship.target_speed=0;landing=false
		if impact>6:
			ship.hull=maxf(0,ship.hull-(impact-6)*3)
			message="Жёсткое касание: %.0f м/с. Проверьте корпус."%impact
		else:message="Посадка выполнена. «Взлететь» — подъём над поверхностью."
		landed=true

func touch_down(ship: RefCounted) -> bool:
	if not active or landed or ship.hull<=0 or altitude(ship)>3 or ship.velocity.length()>6:return false
	ship.position.y=height_at(ship.position.x,ship.position.z)+clearance(ship)
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.attitude=Quaternion.IDENTITY
	landed=true;landing=false
	message="Мягкая посадка выполнена."
	return true

func take_off(ship: RefCounted) -> bool:
	if not active or not landed or ship.hull<=0:return false
	landed=false;landing=false;taking_off=true
	ship.position.y+=0.3
	ship.velocity=Vector3.UP
	ship.attitude=Quaternion(Vector3.RIGHT,0.35)
	ship.assisted=true;ship.target_speed=0
	message="Взлёт. Поднимитесь выше 500 м, затем нажмите «На орбиту»."
	return true

func leave(ship: RefCounted) -> bool:
	if not active or landed or ship.hull<=0 or altitude(ship)<500 or ship.velocity.length()>20:
		message="Для выхода на орбиту: высота от 500 м, скорость до 20 м/с."
		return false
	ship.position=orbit_position;ship.attitude=orbit_attitude
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.autopilot=false;ship.surface_mode=false
	active=false;landing=false;taking_off=false
	message="Возврат в орбитальную зону."
	return true

func snapshot() -> Dictionary:
	return {"version":3,"active":active,"landed":landed,"body_id":body_id,"orbit_position":[orbit_position.x,orbit_position.y,orbit_position.z],"orbit_attitude":[orbit_attitude.x,orbit_attitude.y,orbit_attitude.z,orbit_attitude.w]}

func restore(data: Dictionary, ship: RefCounted, system: RefCounted) -> bool:
	if (data.get("version",0)!=1 and data.get("version",0)!=2 and data.get("version",0)!=3) or not data.get("active") is bool or not data.get("landed") is bool:return false
	for key in ["orbit_position","orbit_attitude"]:
		var values: Variant=data.get(key)
		if not values is Array or values.size()!=(4 if key=="orbit_attitude" else 3):return false
		for value in values:
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>1e9:return false
	var rotation:=Quaternion(data.orbit_attitude[0],data.orbit_attitude[1],data.orbit_attitude[2],data.orbit_attitude[3])
	if rotation.length_squared()<0.01:return false
	if data.active:
		if data.get("body_id","")!=system.focus_id or ship.docked:return false
		if str(system.by_id[system.focus_id].kind) in ["gas","ice_gas","star","barycenter"]:return false
		if Vector2(ship.position.x,ship.position.z).length()>LIMIT+1 or ship.position.y>4001 or ship.position.y< -200:return false
		var candidate: RefCounted=get_script().new()
		candidate.seed_value=system.system_id^system.focus_id.hash()
		if not system.site_id.is_empty():candidate.seed_value^=system.site_id.hash()
		var site:Dictionary=system.current_site()
		if not site.is_empty() and int(site.type_code)==35:candidate.site_name=str(site.name)
		if data.version==3 and candidate.overlaps_building(ship):return false
		var altitude_now: float=candidate.altitude(ship)
		if data.get("version",0)==1:altitude_now=ship.position.y-candidate.raw_height_at(ship.position.x,ship.position.z)-candidate.clearance(ship)
		if altitude_now < -1 or (data.landed and (absf(altitude_now)>1 or ship.velocity.length()>0.1)):return false
	elif data.landed:return false
	site_name=""
	active=data.active;landed=data.landed;landing=false;body_id=str(data.get("body_id",""))
	orbit_position=Vector3(data.orbit_position[0],data.orbit_position[1],data.orbit_position[2]);orbit_attitude=rotation.normalized()
	if active:
		var body: Dictionary=system.by_id[system.focus_id]
		kind=str(body.kind);seed_value=system.system_id^body_id.hash()
		site_name=""
		var site:Dictionary=system.current_site()
		if not site.is_empty() and int(site.type_code)==35:seed_value^=str(site.id).hash();site_name=str(site.name)
		gravity=G*float(body.mass_solar)*SOLAR_MASS/pow(float(body.radius_km)*1000,2)
	taking_off=false
	if active and data.get("version",0)==1:
		ship.position.y=maxf(ship.position.y,height_at(ship.position.x,ship.position.z)+clearance(ship))
		if landed:ship.position.y=height_at(ship.position.x,ship.position.z)+clearance(ship)
	if active and data.version!=3 and overlaps_building(ship):
		evacuate_building(ship);landed=false
		message="Старое сохранение: корабль безопасно поднят над зданием. Прогресс и корпус сохранены."
	ship.surface_mode=active
	return true

func buildings()->Array[AABB]:
	var result:Array[AABB]=[]
	if site_name.is_empty():return result
	for i in range(10):
		var height:=20.0+float((seed_value+i*53)&63)
		var x:=float(-180 if i<5 else 180);var z:=float((i%5)*130-260)
		result.append(AABB(Vector3(x-16,height_at(x,z),z-20),Vector3(32,height,40)))
	return result
func collision_radius(ship:RefCounted)->float:return float(ship.profile().visual_span_m)*0.55
func overlaps_building(ship:RefCounted)->bool:
	for box in buildings():
		if box.grow(collision_radius(ship)-0.02).has_point(ship.position):return true
	return false
func evacuate_building(ship:RefCounted)->void:
	for box in buildings():
		var expanded:AABB=box.grow(collision_radius(ship))
		if expanded.has_point(ship.position):ship.position.y=expanded.end.y+0.05
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.autopilot=false
func _clip_buildings(previous:Vector3,ship:RefCounted)->void:
	var best:Dictionary={};var first:=2.0
	for box in buildings():
		var expanded:AABB=box.grow(collision_radius(ship))
		var contact:=SegmentBox.intersect(previous,ship.position,expanded)
		if not contact.is_empty() and float(contact.time)<first:
			best=contact;first=float(contact.time)
			if contact.inside:best.position=Vector3(previous.x,expanded.end.y+0.05,previous.z)
	if best.is_empty():return
	ship.position=Vector3(best.position)+Vector3(best.normal)*0.05
	var inward:float=ship.velocity.dot(best.normal)
	if inward<0:
		ship.hull=maxf(0,ship.hull-maxf(0,-inward-6)*2)
		ship.velocity-=Vector3(best.normal)*inward
	ship.brake();landing=false;taking_off=false
	message="Столкновение со зданием. Снизьте скорость и отойдите от фасада."
