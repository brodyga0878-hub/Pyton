class_name FlightModel
extends RefCounted
# Rebuilt baseline: preserved motion/inventory code plus documented new validation and service gaps.

const Catalog = preload("res://scripts/ship_catalog.gd")
var catalog := Catalog.new()
const EconomyCatalog = preload("res://scripts/economy_catalog.gd")
const SourceStation = preload("res://scripts/source_station_geometry.gd")
const SOURCE_PILOT_PROFILE:="source-bay-phone-pilot-v1"
var economy_catalog := EconomyCatalog.new()
var goods := {"medicines":2,"food":0,"metals":0,"machines":0,"electronics":0,"luxury":0}
var equipment: Array = []
var mission_cargo := {}
var story_cargo := 0
var ship_id := "cobra"
var external_view := false

const ACCELERATION := 18.0
const MAX_SPEED := 600.0
const DOCK_RADIUS := 100.0
const DOCK_SPEED := 12.0
const STATION := Vector3(0, 0, -2500)
var original_port:=false # Derived from planetary context, never trusted from a save.
var station_available := true
var surface_mode := false
var combat_active := false
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var attitude := Quaternion.IDENTITY
var target_speed := 0.0
var assisted := true
var autopilot := false
var docked := false
var hull := 100.0
var credits := 1000
var cargo: int:
	get: return int(goods.get("medicines",0))
	set(value): goods["medicines"]=value
var delivered := false
var shots := 0
var last_notice := ""
var _source_station:Dictionary={}
var _source_basis:=Basis.IDENTITY
var _source_pilot_phase:=""
var _source_clear_key:=""
var _source_clear:=false

func has_source_station()->bool:return not _source_station.is_empty()

func configure_source_station(geometry:Dictionary,basis:Basis)->bool:
	if not geometry.get("ok") is bool or not geometry.get("revision") is String:return false
	if not SourceStation._valid_geometry(geometry) or int(geometry.get("model_index",-1)) not in SourceStation.MODELS or not basis.is_finite():return false
	if not SourceStation._u32(geometry.get("source_seed")) or not SourceStation._u16(geometry.get("door_u16")) or not geometry.get("descriptor_sha256") is String or str(geometry.descriptor_sha256).length()!=64 or not geometry.get("cache_key") is String or not geometry.get("approach_waypoint") is Vector3 or not geometry.approach_waypoint.is_finite() or geometry.triangles.is_empty() or not geometry.bounds.position.is_finite() or not geometry.bounds.size.is_finite():return false
	if absf(basis.determinant()-1.0)>0.001 or absf(basis.x.length_squared()-1.0)>0.001 or absf(basis.y.length_squared()-1.0)>0.001 or absf(basis.z.length_squared()-1.0)>0.001 or absf(basis.x.dot(basis.y))>0.001 or absf(basis.x.dot(basis.z))>0.001 or absf(basis.y.dot(basis.z))>0.001:return false
	if not has_source_station() or int(_source_station.model_index)!=int(geometry.model_index) or int(_source_station.source_seed)!=int(geometry.source_seed):_source_pilot_phase=""
	_source_station=geometry;_source_basis=basis
	if docked:position=STATION;velocity=Vector3.ZERO;attitude=basis.get_rotation_quaternion().normalized()
	return true

func clear_source_station()->void:
	_source_station={};_source_basis=Basis.IDENTITY;_source_pilot_phase="";_source_clear_key=""

func _source_approach_clear()->bool:
	var key:="%s:%s"%[str(_source_station.get("cache_key","")),ship_id]
	if key!=_source_clear_key:_source_clear=SourceStation.approach_clear(_source_station,source_collision_radii());_source_clear_key=key
	return _source_clear

func source_station_state()->Dictionary:
	if not has_source_station():return {}
	return {"revision":SourceStation.REVISION,"model_index":int(_source_station.model_index),"source_seed":int(_source_station.source_seed),"descriptor_sha256":str(_source_station.descriptor_sha256),"pilot_profile":SOURCE_PILOT_PROFILE}

func source_collision_radii(id:String="")->Vector3:
	var span:=float(catalog.get_ship(ship_id if id.is_empty() else id).get("visual_span_m",0.0))
	return Vector3(span*0.55,span*0.14+2.0,span*0.55) if span>0 else Vector3.ZERO

func _source_local(point:Vector3)->Vector3:return _source_basis.transposed()*(point-STATION)

func _source_shape_sweep(start:Vector3,finish:Vector3,rotation:Quaternion,id:String="")->Dictionary:
	var radii:=source_collision_radii(id)
	if radii==Vector3.ZERO:return {}
	var broad:=AABB(start.min(finish),start.max(finish)-start.min(finish)).grow(maxf(radii.x,maxf(radii.y,radii.z)))
	if not broad.intersects(_source_station.bounds):return {}
	var local_basis:=_source_basis.transposed()*Basis(rotation.normalized())
	# Horizontal radii are equal. Yaw does not change this ellipsoid, whereas
	# roll/pitch need the actual oriented triangle transform, not a thin fixed Y.
	if absf(local_basis.y.dot(Vector3.UP))>0.999999:return SourceStation.sweep(_source_station,start,finish,radii)
	var inverse:=local_basis.transposed();var transformed:=_source_station.duplicate();var triangles:Array=[];var boxes:Array=[];var bounds:=AABB();var first:=true
	for triangle:Array in _source_station.triangles:
		var vertices:Array[Vector3]=[]
		for point:Vector3 in triangle:vertices.append(inverse*point)
		var box:=AABB(vertices[0],Vector3.ZERO)
		for point:Vector3 in vertices:box=box.expand(point)
		triangles.append(vertices);boxes.append(box);bounds=box if first else bounds.merge(box);first=false
	transformed.triangles=triangles;transformed.triangle_bounds=boxes;transformed.bounds=bounds
	var hit:=SourceStation.sweep(transformed,inverse*start,inverse*finish,radii)
	if not hit.is_empty():hit.position=local_basis*hit.position;hit.normal=local_basis*hit.normal
	return hit

func source_dock_pose_valid(candidate_position:Vector3,candidate_velocity:Vector3,candidate_attitude:Quaternion,candidate_id:String="")->bool:
	if not has_source_station() or not candidate_position.is_finite() or not candidate_velocity.is_finite() or not candidate_attitude.is_finite() or candidate_attitude.length_squared()<0.01:return false
	var local_basis:=_source_basis.transposed()*Basis(candidate_attitude.normalized())
	var radii:=source_collision_radii(candidate_id)
	var fitted:=Vector3.ZERO
	for axis in range(3):fitted[axis]=sqrt(pow(float(local_basis.x[axis])*radii.x,2)+pow(float(local_basis.y[axis])*radii.y,2)+pow(float(local_basis.z[axis])*radii.z,2))
	# A docked source port may legitimately close its outer gate. Validate the
	# interior pose against the open bay contract and the ACTUAL current solids.
	var open_geometry:=_source_station if int(_source_station.door_u16)==0 else SourceStation.prepare(int(_source_station.model_index),int(_source_station.source_seed),0)
	var point:=_source_local(candidate_position)
	return SourceStation.mobile_dock_ready(open_geometry,point,_source_basis.transposed()*candidate_velocity,-local_basis.z,local_basis.y,fitted) and _source_shape_sweep(point,point,candidate_attitude,candidate_id).is_empty()

func _source_collide(previous:Vector3)->void:
	var hit:=_source_shape_sweep(_source_local(previous),_source_local(position),attitude)
	if hit.is_empty():return
	var normal:Vector3=(_source_basis*hit.normal).normalized();var speed:=velocity.length()
	position=STATION+_source_basis*hit.position+normal*0.02
	var inward:=velocity.dot(normal)
	if inward<0:velocity-=normal*inward*1.2
	if speed>DOCK_SPEED:hull=maxf(0.0,hull-speed*0.15)
	target_speed=0.0;autopilot=false;_source_pilot_phase=""
	last_notice="Столкновение с корпусом станции. Выровняйте корабль по проёму."

func _source_autopilot_step(dt:float,gravity:Vector3)->bool:
	if can_dock():dock();return true
	var local:=_source_local(position);var waypoint:Vector3=_source_station.approach_waypoint
	var clear:=_source_approach_clear()
	if _source_pilot_phase.is_empty():_source_pilot_phase="staging"
	if _source_pilot_phase=="enter" and (absf(local.x)>8.0 or absf(local.y)>4.0 or local.z<(-8.0)):_source_pilot_phase="staging"
	if _source_pilot_phase=="staging" and local.distance_to(waypoint)<5.0 and velocity.length()<2.0:_source_pilot_phase="align"
	var target:=waypoint
	if _source_pilot_phase=="enter":
		if not clear:
			velocity=velocity.move_toward(Vector3.ZERO,acceleration()*dt);target_speed=0;last_notice="Проём закрыт. Автопилот остановлен.";autopilot=false;_source_pilot_phase=""
			return false
		target=Vector3.ZERO
	var offset:Vector3=STATION+_source_basis*target-position;var distance:=offset.length()
	var direction:=offset.normalized() if distance>0.0001 else Vector3.ZERO
	var desired_basis:=_source_basis
	if _source_pilot_phase=="staging" and distance>1.0:
		var up:Vector3=_source_basis.y if absf(direction.dot(_source_basis.y))<0.98 else _source_basis.x
		desired_basis=Basis.looking_at(direction,up)
	attitude=attitude.slerp(desired_basis.get_rotation_quaternion(),minf(dt*2.5,1.0)).normalized()
	var available:=maxf(0,acceleration()-gravity.length())
	var speed:=minf(DOCK_SPEED,sqrt(available*maxf(distance-1.0,0.0)))
	if _source_pilot_phase=="align":
		speed=0.0
		var local_orientation:=_source_basis.transposed()*Basis(attitude)
		if velocity.length()<0.5 and -local_orientation.z.dot(Vector3.FORWARD)>0.999 and local_orientation.y.dot(Vector3.UP)>0.999:
			if clear:_source_pilot_phase="enter"
			else:last_notice="Ожидание открытия стыковочного проёма."
	elif _source_pilot_phase=="enter":
		var local_orientation:=_source_basis.transposed()*Basis(attitude)
		if -local_orientation.z.dot(Vector3.FORWARD)<0.99 or local_orientation.y.dot(Vector3.UP)<0.99:speed=0.0
	target_speed=speed;velocity=velocity.move_toward(direction*speed,available*dt)
	if gravity.length()>acceleration():velocity+=gravity.normalized()*(gravity.length()-acceleration())*dt
	return false

func profile() -> Dictionary:
	return catalog.get_ship(ship_id)

func acceleration() -> float:
	return float(profile().get("acceleration",0.0))*(1.2 if "engine" in equipment else 1.0)

func cargo_capacity() -> int:
	return maxi(0,int(profile().get("cargo_capacity",0))-equipment_space())

func jump_range() -> float:
	return float(profile().get("jump_range",0.0))*(1.25 if "hyperdrive" in equipment else 1.0)

func change_ship(id: String) -> bool:
	var candidate:=catalog.get_ship(id)
	if original_port or candidate.is_empty() or not docked or hull<=0 or total_cargo()>int(candidate.cargo_capacity)-equipment_space(): return false
	ship_id=id
	velocity=Vector3.ZERO
	target_speed=0
	autopilot=false
	return true

func forward() -> Vector3:
	return -(Basis(attitude).z)

func step(dt: float, steering: Vector2, roll: float = 0.0, gravity := Vector3.ZERO, lift := 0.0) -> void:
	# New boundary guard: a bad frame/input cannot poison the saved flight state.
	if dt<=0 or not is_finite(dt) or not steering.is_finite() or not is_finite(roll) or not gravity.is_finite() or not is_finite(lift):return
	if not position.is_finite() or not velocity.is_finite() or not attitude.is_finite() or attitude.length_squared()<0.0001 or not is_finite(target_speed) or not is_finite(hull) or profile().is_empty():return
	if docked or hull<=0:
		return
	steering=steering.limit_length();roll=clampf(roll,-1,1)
	target_speed=clampf(target_speed,-100.0,MAX_SPEED)
	if not station_available or surface_mode or combat_active: autopilot = false
	if not autopilot:_source_pilot_phase=""
	if autopilot:
		if has_source_station():
			if _source_autopilot_step(dt,gravity):return
		else:
			var offset := STATION - position
			var distance := offset.length()
			var direction := offset.normalized()
			if distance > 1.0:
				var desired_basis := Basis.looking_at(direction, Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT)
				attitude = attitude.slerp(desired_basis.get_rotation_quaternion(), minf(dt * 2.5, 1.0)).normalized()
			var available:=maxf(0,acceleration()-gravity.length())
			var approach_speed := minf(300.0, sqrt(available * maxf(distance - 60.0, 0.0)))
			target_speed = approach_speed
			velocity = velocity.move_toward(direction * approach_speed, available * dt)
			if gravity.length()>acceleration():velocity+=gravity.normalized()*(gravity.length()-acceleration())*dt
			if can_dock():
				dock()
				return
	else:
		var local_rotation := Quaternion(Vector3.UP, -steering.x * dt * float(profile().turn_rate)) * Quaternion(Vector3.RIGHT, -steering.y * dt * float(profile().turn_rate)) * Quaternion(Vector3.FORWARD, roll * dt * float(profile().turn_rate)/1.2)
		attitude = (attitude * local_rotation).normalized()
		if assisted:
			velocity = velocity.move_toward(forward() * target_speed+Vector3.UP*clampf(lift,-1,1)*60, maxf(0,acceleration()-gravity.length()) * dt)
			if gravity.length()>acceleration(): velocity+=gravity.normalized()*(gravity.length()-acceleration())*dt
		else:
			# Inertial mode: the slider sets axial thrust, not a hidden velocity clamp.
			velocity += (forward() * (target_speed / MAX_SPEED) * acceleration()+gravity+Vector3.UP*clampf(lift,-1,1)*acceleration()*0.5) * dt
	var previous:=position
	position += velocity * dt
	if has_source_station():
		if station_available and not surface_mode:_source_collide(previous)
		return
	var movement:=position-previous
	var fraction:=clampf((STATION-previous).dot(movement)/movement.length_squared(),0,1) if movement.length_squared()>0.001 else 0.0
	var closest:=previous+movement*fraction
	if station_available and not surface_mode and closest.distance_to(STATION) < 38.0:
		if velocity.length() > DOCK_SPEED:
			hull = maxf(0.0, hull - velocity.length() * 0.15)
			var normal:=(closest-STATION).normalized() if closest.distance_to(STATION)>0.1 else (-velocity.normalized() if velocity.length()>0.1 else Vector3.BACK)
			position = STATION + normal * 45.0
			velocity *= -0.25
			autopilot = false
			last_notice = "Столкновение со станцией. Снизьте скорость."

func brake() -> void:
	target_speed = 0.0
	assisted = true
	autopilot = false

func can_dock() -> bool:
	if has_source_station():return is_finite(hull) and hull>0 and station_available and not surface_mode and not combat_active and int(_source_station.door_u16)==0 and source_dock_pose_valid(position,velocity,attitude)
	return position.is_finite() and velocity.is_finite() and is_finite(hull) and not surface_mode and not combat_active and hull>0 and station_available and position.distance_to(STATION) <= DOCK_RADIUS and velocity.length() <= DOCK_SPEED

func dock() -> bool:
	if not can_dock():
		return false
	docked = true
	autopilot = false
	velocity = Vector3.ZERO
	target_speed = 0.0
	if has_source_station():position=STATION;attitude=_source_basis.get_rotation_quaternion().normalized();_source_pilot_phase=""
	return true

# New reconstruction of the missing launch/training-market section.
func launch() -> void:
	if not docked or hull<=0:return
	if has_source_station():
		if not _source_approach_clear():last_notice="Вылет ожидает открытия стыковочного проёма.";return
		position=STATION
		attitude=Basis.looking_at(_source_basis.z,_source_basis.y).get_rotation_quaternion().normalized()
		velocity=_source_basis.z*DOCK_SPEED;target_speed=DOCK_SPEED;docked=false;autopilot=false;assisted=true;_source_pilot_phase=""
		last_notice="Вылет выполнен через открытый проём. Корабль отходит от станции."
		return
	var away:Vector3=(position-STATION).normalized()
	if away.length_squared()<0.5:away=Vector3.BACK
	position=STATION+away*maxf(150.0,float(profile().get("visual_span_m",42.0))*2.0+DOCK_RADIUS)
	attitude=Basis.looking_at(away,Vector3.UP if absf(away.y)<0.98 else Vector3.RIGHT).get_rotation_quaternion().normalized()
	velocity=away*20.0;target_speed=20.0
	docked=false;autopilot=false;assisted=true
	last_notice="Вылет выполнен. Корабль отходит от станции."

func _trade_ready() -> bool:
	return not original_port and docked and is_finite(hull) and hull>0 and credits>=0 and credits<=1000000000

func buy(id:String="medicines",quantity:Variant=1) -> bool:
	if not _trade_ready() or not economy_catalog.goods.has(id) or not _whole_quantity(quantity) or int(quantity)<=0:return false
	if not _whole_quantity(goods.get(id,0)):return false
	var amount:=int(quantity)
	var price:=int(economy_catalog.goods[id].price)*amount
	if credits<price or total_cargo()+amount>cargo_capacity():return false
	credits-=price;goods[id]=int(goods.get(id,0))+amount
	return true

func sell(id:String="medicines",quantity:Variant=1) -> bool:
	if not _trade_ready() or not economy_catalog.goods.has(id) or not _whole_quantity(quantity) or int(quantity)<=0:return false
	if not _whole_quantity(goods.get(id,0)) or int(goods.get(id,0))<int(quantity):return false
	var amount:=int(quantity)
	var payment:=floori(float(economy_catalog.goods[id].price)*0.8)*amount
	if credits+payment>1000000000:return false
	goods[id]=int(goods[id])-amount;credits+=payment
	return true

func deliver() -> bool:
	# One adapted training order, not an original FFE campaign callback.
	if not _trade_ready() or delivered or not _whole_quantity(goods.get("medicines",0)) or cargo<=0:return false
	var payment:=cargo*400
	if credits+payment>1000000000:return false
	cargo=0;credits+=payment;delivered=true
	return true

func fire() -> bool:
	if docked or hull<=0 or shots>=1000000000:return false
	shots+=1
	return true

func snapshot() -> Dictionary:
	var result:={"version": 4,"story_cargo":story_cargo, "goods":goods.duplicate(),"equipment":equipment.duplicate(),"mission_cargo":mission_cargo.duplicate(),"ship_id":ship_id,"external_view":external_view, "position": [position.x, position.y, position.z], "velocity": [velocity.x, velocity.y, velocity.z], "attitude": [attitude.x, attitude.y, attitude.z, attitude.w], "target_speed": target_speed, "assisted": assisted, "docked": docked, "hull": hull, "credits": credits, "cargo": cargo, "delivered": delivered}
	if has_source_station():result.version=5;result.source_station=source_station_state()
	return result

func restore(data: Dictionary) -> bool:
	# New validation is completed before the preserved commit block below.
	var version:Variant=data.get("version",0)
	if not (version is int or version is float) or not is_finite(float(version)) or float(version)!=floorf(float(version)):return false
	if not catalog.valid:return false
	for field in ["assisted","docked","delivered","external_view"]:
		if data.has(field) and not data[field] is bool:return false
	if not (data.get("hull") is float or data.get("hull") is int) or not is_finite(float(data.hull)) or float(data.hull)<0 or float(data.hull)>100:return false
	if not (data.get("target_speed") is float or data.get("target_speed") is int) or not is_finite(float(data.target_speed)) or absf(float(data.target_speed))>1.0e9:return false
	if data.get("version",0)!=1 and data.get("version",0)!=2 and data.get("version",0)!=3 and data.get("version",0)!=4 and data.get("version",0)!=5:
		return false
	var saved_id := "cobra"
	if data.get("version",0)==2 or data.get("version",0)==3 or data.get("version",0)==4 or data.get("version",0)==5:
		if not data.get("ship_id") is String or catalog.get_ship(data.ship_id).is_empty():return false
		saved_id=data.ship_id
	for key in ["position", "velocity", "attitude"]:
		var a: Variant = data.get(key)
		var count := 4 if key == "attitude" else 3
		if not a is Array or a.size() != count:
			return false
		for v in a:
			if not (v is float or v is int) or not is_finite(float(v)) or absf(float(v)) > 1.0e9:
				return false
	for key in ["target_speed", "hull", "credits", "cargo"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):
			return false
	if float(data.credits) < 0 or float(data.credits) > 1.0e9 or float(data.cargo) < 0 or float(data.cargo) > float(catalog.get_ship(saved_id).cargo_capacity):
		return false
	if float(data.credits)!=floorf(float(data.credits)) or float(data.cargo)!=floorf(float(data.cargo)): return false
	if data.get("version",0)==1 and data.cargo>10: return false
	var loaded_goods:=economy_catalog.empty_manifest()
	loaded_goods.medicines=int(data.cargo)
	var loaded_equipment: Array=[]
	var loaded_missions: Dictionary={}
	if data.get("version",0)==3 or data.get("version",0)==4 or data.get("version",0)==5:
		if not data.get("goods") is Dictionary or not data.get("equipment") is Array or not data.get("mission_cargo") is Dictionary:return false
		for id in data.goods:
			if not economy_catalog.goods.has(id) or not _whole_quantity(data.goods[id]):return false
			loaded_goods[id]=int(data.goods[id])
		if loaded_goods.medicines!=data.cargo:return false
		for id in data.equipment:
			if not id is String or not economy_catalog.equipment.has(id) or id in loaded_equipment:return false
			loaded_equipment.append(id)
		if data.mission_cargo.size()>3:return false
		for id in data.mission_cargo:
			if not id is String or id.is_empty() or id.length()>100 or not _whole_quantity(data.mission_cargo[id]) or data.mission_cargo[id]<=0:return false
			loaded_missions[id]=int(data.mission_cargo[id])
	var loaded_story:=0
	if data.get("version",0)==4 or data.get("version",0)==5:
		if not _whole_quantity(data.get("story_cargo")) or (data.story_cargo!=0 and data.story_cargo!=2):return false
		loaded_story=int(data.story_cargo)
	var used:=loaded_story
	for count in loaded_goods.values():used+=int(count)
	for count in loaded_missions.values():used+=int(count)
	for id in loaded_equipment:used+=int(economy_catalog.equipment[id].space)
	if used>int(catalog.get_ship(saved_id).cargo_capacity):return false
	var q: Array = data.attitude
	var restored_q := Quaternion(q[0], q[1], q[2], q[3])
	if restored_q.length_squared() < 0.01:
		return false
	var p: Array = data.position
	var v: Array = data.velocity
	if int(version)==5:
		if not has_source_station() or not data.get("source_station") is Dictionary:return false
		var expected:=source_station_state()
		for key in expected:
			var supplied:Variant=data.source_station.get(key)
			if expected[key] is int:
				if not SourceStation._u32(supplied) or int(supplied)!=int(expected[key]):return false
			elif not supplied is String or supplied!=expected[key]:return false
		var candidate_position:=Vector3(p[0],p[1],p[2]);var candidate_velocity:=Vector3(v[0],v[1],v[2])
		if not _source_shape_sweep(_source_local(candidate_position),_source_local(candidate_position),restored_q,saved_id).is_empty():return false
		if bool(data.get("docked",false)) and (float(data.hull)<=0 or not source_dock_pose_valid(candidate_position,candidate_velocity,restored_q,saved_id)):return false
	else:clear_source_station()
	original_port=false
	story_cargo=loaded_story
	goods=loaded_goods;equipment=loaded_equipment;mission_cargo=loaded_missions
	ship_id=saved_id
	external_view=bool(data.get("external_view",false))
	position = Vector3(p[0], p[1], p[2])
	velocity = Vector3(v[0], v[1], v[2])
	attitude = restored_q.normalized()
	target_speed = clampf(data.target_speed, -100.0, MAX_SPEED)
	assisted = bool(data.get("assisted", true))
	docked = bool(data.get("docked", false))
	hull = clampf(data.hull, 0.0, 100.0)
	# New reconstruction of the previously missing restore tail.
	credits=int(data.credits)
	delivered=bool(data.get("delivered",false))
	autopilot=false;surface_mode=false;combat_active=false;station_available=true
	shots=0;last_notice=""
	_source_pilot_phase=""
	return true


static func _whole_quantity(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=1000000 and float(value)==floorf(float(value))

func total_cargo() -> int:
	var total:=story_cargo
	for count in goods.values():total+=int(count)
	for count in mission_cargo.values():total+=int(count)
	return total

func equipment_space() -> int:
	var space:=0
	for id in equipment:space+=int(economy_catalog.equipment[id].space)
	return space

func shield_capacity() -> float:
	return 100.0 if "shield" in equipment else 60.0

func cooling_rate() -> float:
	return 40.0 if "cooler" in equipment else 24.0

func install_equipment(id: String) -> bool:
	if original_port or not docked or hull<=0 or not economy_catalog.equipment.has(id) or id in equipment:return false
	var item: Dictionary=economy_catalog.equipment[id]
	if credits<int(item.price) or total_cargo()+int(item.space)>cargo_capacity():return false
	credits-=int(item.price)
	equipment.append(id)
	return true

func remove_equipment(id: String) -> bool:
	if original_port or not docked or hull<=0 or id not in equipment:return false
	var refund:=int(economy_catalog.equipment[id].price)/2
	if credits+refund>1000000000:return false
	equipment.erase(id);credits+=refund
	return true

func ship_trade_value() -> int:
	return floori(float(economy_catalog.ship_prices[ship_id])*0.8*(0.5+0.5*hull/100.0))

func trade_ship_error(id: String) -> String:
	if original_port or not docked or hull<=0:return "Верфь доступна после стыковки."
	if id==ship_id:return "Текущий корабль."
	var candidate:=catalog.get_ship(id)
	if candidate.is_empty():return "Неизвестный корабль."
	if total_cargo()+equipment_space()>int(candidate.cargo_capacity):return "Разгрузите трюм или снимите оборудование."
	var balance:=credits+ship_trade_value()-int(economy_catalog.ship_prices[id])
	if balance<0:return "Недостаточно кредитов для обмена."
	if balance>1000000000:return "Превышен предел счёта."
	return ""

func trade_ship(id: String) -> bool:
	if trade_ship_error(id)!="":return false
	var balance:=credits+ship_trade_value()-int(economy_catalog.ship_prices[id])
	if not change_ship(id):return false
	credits=balance
	return true
