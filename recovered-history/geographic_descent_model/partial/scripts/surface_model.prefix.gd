extends RefCounted

const OrbitLink=preload("res://scripts/surface_orbit_link.gd")
var orbit_link:Dictionary={}
const SphereTerrain=preload("res://scripts/spherical_terrain.gd")
const REBASE_DISTANCE:=512.0
const MIN_DESCENT_HEIGHT:=1800.0
const MAX_DESCENT_HEIGHT:=60000.0
# Height over the rendered terrain can exceed geoid height in shallow depressions.
const MAX_FLIGHT_HEIGHT:=60200.0
var extended_flight:=false
var flight_phase:=""
var ready_for_orbit:=false
var globe:RefCounted
var frame_index:=0
var frame_rotation:=Quaternion.IDENTITY
var rebase_from:=Vector3.ZERO
var rebase_to:=Vector3.ZERO
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
	if globe:return globe.raw_height(x,z)
	var phase:=float(seed_value&1023)*0.013
	var relief:=sin(x*0.003+phase)*cos(z*0.0023)*95+sin(z*0.008+x*0.004)*22
	# A flat, marked landing field blends into a deterministic patch of hills.
	return relief*smoothstep(100,420,Vector2(x,z).length())

func height_at(x: float, z: float) -> float:
	# Exact same diagonal and vertices as the rendered mesh, eliminating hill clipping.
	var cell:=GRID_WIDTH/grid_cells()
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

func geoid_height(ship:RefCounted)->float:
	if not globe:return ship.position.y
	var angle:=Vector2(ship.position.x,ship.position.z).length()/float(globe.radius)
	return (ship.position.y+2.0*float(globe.radius)*pow(sin(angle*0.5),2))/cos(angle)

func entry_error(ship: RefCounted, system: RefCounted) -> String:
	if active:return "Вы уже у поверхности."
	if not ship.position.is_finite() or not ship.velocity.is_finite() or not ship.attitude.is_finite():return "Невозможно определить положение корабля."
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

func enter(ship: RefCounted, system: RefCounted, spherical:=false) -> bool:
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
	orbit_link={}
	extended_flight=false;flight_phase="";ready_for_orbit=false
	globe=null;frame_index=0
	if spherical:
		globe=SphereTerrain.new();globe.configure(system,body_id,system.site_id)
	gravity=G*float(body.mass_solar)*SOLAR_MASS/pow(float(body.radius_km)*1000,2)
	orbit_position=ship.position;orbit_attitude=ship.attitude
	active=true;landed=false;landing=false
	ship.surface_mode=true;ship.station_available=false;ship.autopilot=false
	ship.position=Vector3(0,1500,800)
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.assisted=true
	ship.attitude=Quaternion(Vector3.RIGHT,-0.35)
	if globe:recenter(ship)
	message="Посадочная зона: %s. «Автопилот» — заход; «Стыковка» — мягкая посадка."%(site_name if not site_name.is_empty() else body.name)
	return true

func begin_landing(ship: RefCounted) -> bool:
	if not active or landed or ship.hull<=0:return false
	cancel_vertical()
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
	if not flight_phase.is_empty() and (steering.length()>0.05 or absf(roll)>0.05 or absf(lift)>0.1):cancel_vertical()
	if absf(lift)>0.1:landing=false;taking_off=false
	if not flight_phase.is_empty():
		_step_vertical(dt,ship)
	elif taking_off:
		ship.velocity=ship.velocity.move_toward(Vector3.UP*15,maxf(0.1,ship.acceleration()-gravity)*dt)
		ship.position+=ship.velocity*dt
		if altitude(ship)>=35:taking_off=false;ship.brake()
	elif landing:
		var pad:=pad_position()
		var horizontal:=Vector3(pad.x-ship.position.x,0,pad.z-ship.position.z)
		var height:=maxf(0,ship.position.y-pad.y-clearance(ship))
		var reserve:=maxf(0.1,ship.acceleration()-gravity)
		var desired:=horizontal.normalized()*minf(60,sqrt(horizontal.length()*reserve))
		desired.y=-minf(25,sqrt(maxf(0,height-0.3)*reserve)) if horizontal.length()<80 else clampf((height_at(ship.position.x,ship.position.z)+200-ship.position.y)*0.1,-20,20)
		if globe and horizontal.length()>80 and altitude(ship)<100:
			# Clear nearby hills before accelerating horizontally after a wilderness takeoff.
			desired=Vector3.UP*minf(20,sqrt(maxf(0,180-altitude(ship))*reserve))
		ship.velocity=ship.velocity.move_toward(desired,reserve*dt)
		ship.attitude=ship.attitude.slerp(Quaternion.IDENTITY,minf(1,dt*1.5)).normalized()
		ship.position+=ship.velocity*dt
	else:
		ship.step(dt,steering,roll,Vector3.DOWN*gravity,lift)
	_clip_buildings(previous,ship)
	if ship.hull<=0:return
	var radial:=Vector2(ship.position.x,ship.position.z)
	if not globe and radial.length()>LIMIT:
		var edge:=radial.normalized()*LIMIT
		ship.position.x=edge.x;ship.position.z=edge.y
		ship.velocity.x=0;ship.velocity.z=0
		ship.target_speed=0
		message="Граница посадочного района. Вернитесь к площадке или на орбиту."
	var ceiling:=height_at(ship.position.x,ship.position.z)+clearance(ship)+(MAX_FLIGHT_HEIGHT if extended_flight else 4000.0) if globe else 4000.0
	if ship.position.y>ceiling:
		ship.position.y=ceiling;ship.velocity.y=minf(ship.velocity.y,0);ship.target_speed=0
	if landing and altitude(ship)<=0.6 and ship.velocity.length()<=6 and (not globe or pad_distance(ship)<80):
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

	if globe and radial.length()>REBASE_DISTANCE:recenter(ship)

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

func leave(ship: RefCounted,system:RefCounted=null,days:=0.0) -> bool:
	if not active or landed or ship.hull<=0 or altitude(ship)<500 or ship.velocity.length()>20:
		message="Для выхода на орбиту: высота от 500 м, скорость до 20 м/с."
		return false
	if globe and system:
		orbit_link=OrbitLink.make(self,ship,system,days)
		var ll:Array=geographic_position(ship)
		var world_basis:Basis=Basis(Vector3.UP,OrbitLink.spin(system.by_id[body_id],days))*globe.basis_at(globe.latitude,globe.longitude)
		ship.attitude=(world_basis.get_rotation_quaternion()*ship.attitude).normalized()
		var height:float=clampf(geoid_height(ship),OrbitLink.ALTITUDE,MAX_FLIGHT_HEIGHT) if extended_flight else OrbitLink.ALTITUDE
		# Keep the v2 record as its original 20-km geographic reference. Higher
		# departures retain their real position, so re-entry uses the radial path.
		if height>OrbitLink.ALTITUDE:
			var radial:Vector3=Basis(Vector3.UP,OrbitLink.spin(system.by_id[body_id],days))*OrbitLink.direction(ll[0],ll[1])
			ship.position=system.local_meters(body_id,days)+radial*(float(globe.radius)+height)
		else:ship.position=Vector3(orbit_link.position[0],orbit_link.position[1],orbit_link.position[2])
	else:
		ship.position=orbit_position;ship.attitude=orbit_attitude
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.autopilot=false;ship.surface_mode=false
	active=false;landing=false;taking_off=false;flight_phase="";ready_for_orbit=false
	message="Возврат в орбитальную зону."
	return true

func snapshot() -> Dictionary:
	var state:Dictionary={"version":3,"active":active,"landed":landed,"body_id":body_id,"orbit_position":[orbit_position.x,orbit_position.y,orbit_position.z],"orbit_attitude":[orbit_attitude.x,orbit_attitude.y,orbit_attitude.z,orbit_attitude.w]}

	if active and globe:
		state.version=4;state.layout="globe_v1";state.terrain_revision=SphereTerrain.REVISION
		state.latitude=globe.latitude;state.longitude=globe.longitude
	if active and extended_flight:state.version=6;state.flight_phase=flight_phase
	if not active and not orbit_link.is_empty():state.version=5;state.orbit_link=orbit_link.duplicate(true)
	return state

func restore(data: Dictionary, ship: RefCounted, system: RefCounted) -> bool:
	if data.get("version",0)==6:
		if not data.get("flight_phase") is String or data.flight_phase not in ["","ascent","descent"]:return false
		if data.get("landed")==true and not data.flight_phase.is_empty():return false
		if not data.flight_phase.is_empty() and (ship.velocity.length()>301 or not ship.assisted or absf(ship.target_speed)>0.01):return false
		if not _restore_globe(data,ship,system,MAX_FLIGHT_HEIGHT+1):return false
		extended_flight=true;flight_phase=data.flight_phase
		return true
	if data.get("version",0)==5:
		if not data.get("active") is bool or not data.get("landed") is bool or data.active or data.landed or data.get("body_id")!=system.focus_id or not OrbitLink.valid(data.get("orbit_link"),system):return false
		var old:=data.duplicate(true);old.version=3;old.erase("orbit_link")
		var candidate:RefCounted=get_script().new()
		if not candidate.restore(old,ship,system):return false
		if not restore(old,ship,system):return false
		orbit_link=data.orbit_link.duplicate(true)
		return true
	if data.get("version",0)==4:
		if data.has("flight_phase"):return false
		return _restore_globe(data,ship,system)
	if data.has("terrain_revision") or data.has("layout"):return false
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
	orbit_link={}
	extended_flight=false;flight_phase="";ready_for_orbit=false
	globe=null;frame_index=0
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
	var pad:=pad_position()
	if globe and Vector2(pad.x,pad.z).length()>GRID_WIDTH:return result
	for i in range(10):
