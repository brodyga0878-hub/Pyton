extends RefCounted
# Read-only feedback for the existing mobile docking guard. It grants no port
# permission, opens no door and never changes Flight, World or a save owner.
const Flight=preload("res://scripts/flight_model.gd")
const Geometry=preload("res://scripts/source_station_geometry.gd")
const Dynamics=preload("res://scripts/rotating_dock_dynamics.gd")
const POLICY:="source-station-mobile-approach-feedback-v1"
const SOURCE_SPEED_LIMIT_MPS:=12.0
const SOURCE_ALIGNMENT_DOT_MIN:=0.9375
const SOURCE_INTERIOR_Z_LIMIT_M:=8.0

static func _finish(result:Dictionary,reason:String,message:String)->Dictionary:
	result.reason=reason;result.message=message
	if reason=="invalid_state":result.available=false;result.can_request_clearance=false
	return result

static func status(ship:RefCounted)->Dictionary:
	var result:={"policy":POLICY,"available":false,"source":false,"ready":false,"docked":false,"reason":"unavailable","message":"Стыковка доступна у выбранной станции.","door_open":false,"door_u16":-1,"relative_speed_mps":0.0,"distance_m":0.0,"local_position_m":Vector3.ZERO,"forward_dot":0.0,"up_dot":0.0,"roll_error_rad":0.0,"heading_error_rad":0.0,"station_angular_velocity_world_rad_s":Vector3.ZERO,"rate_sample_valid":false,"interior_z_limit_m":SOURCE_INTERIOR_Z_LIMIT_M,"speed_limit_mps":SOURCE_SPEED_LIMIT_MPS,"alignment_dot_min":SOURCE_ALIGNMENT_DOT_MIN,"can_request_clearance":false}
	if ship==null or ship.get_script()!=Flight:return _finish(result,"invalid_state","Не удалось определить состояние корабля для стыковки.")
	result.source=ship.has_source_station();result.docked=ship.docked
	if not ship.position.is_finite() or not ship.velocity.is_finite() or not ship.attitude.is_finite() or ship.attitude.length_squared()<0.01 or not is_finite(ship.hull):return _finish(result,"invalid_state","Неверная поза или состояние корабля.")
	result.distance_m=ship.position.distance_to(Flight.STATION)
	if ship.hull<=0:return _finish(result,"destroyed","Корабль потерян: стыковка недоступна.")
	if ship.surface_mode:return _finish(result,"surface","Для стыковки со станцией сначала завершите полёт над поверхностью.")
	if ship.combat_active:return _finish(result,"combat","Стыковка недоступна во время боя.")
	if not ship.station_available:return result
	result.available=true;result.relative_speed_mps=ship.velocity.length()
	if not result.source:
		result.ready=not ship.docked and ship.can_dock()
		if ship.docked:return _finish(result,"docked","Корабль в доке. Откройте службы или запросите вылет.")
		if result.ready:return _finish(result,"ready","Учебный узел готов принять корабль. Нажмите «Стыковка».")
		if result.distance_m>Flight.DOCK_RADIUS:return _finish(result,"distance","Подойдите к учебному узлу на расстояние до 100 м. «Авто» выполнит подход.")
		return _finish(result,"relative_speed","Снизьте скорость до 12 м/с для стыковки с учебным узлом.")
	var geometry:Dictionary=ship._source_station
	if not Geometry._valid_geometry(geometry) or not Dynamics.rigid(ship._source_basis) or not ship._source_angular_velocity.is_finite():return _finish(result,"invalid_state","Не удалось проверить проём выбранной станции.")
	var telemetry:Dictionary=ship.source_docking_telemetry()
	if telemetry.is_empty() or not telemetry.get("relative_linear_velocity_mps") is Vector3 or not telemetry.relative_linear_velocity_mps.is_finite():return _finish(result,"invalid_state","Не удалось определить скорость относительно дока.")
	var basis:Basis=ship._source_basis.transposed()*Basis(ship.attitude.normalized())
	var point:Vector3=ship._source_local(ship.position)
	var fitted:=Vector3.ZERO;var radii:Vector3=ship.source_collision_radii()
	for axis in range(3):fitted[axis]=sqrt(pow(float(basis.x[axis])*radii.x,2)+pow(float(basis.y[axis])*radii.y,2)+pow(float(basis.z[axis])*radii.z,2))
	result.door_u16=int(geometry.get("door_u16",-1));result.door_open=result.door_u16==0
	result.local_position_m=point;result.relative_speed_mps=telemetry.relative_linear_velocity_mps.length()
	result.forward_dot=(-basis.z).normalized().dot(Vector3.FORWARD);result.up_dot=basis.y.normalized().dot(Vector3.UP)
	result.roll_error_rad=float(telemetry.get("roll_error_rad",0.0));result.heading_error_rad=float(telemetry.get("heading_error_rad",0.0))
	result.station_angular_velocity_world_rad_s=telemetry.get("station_angular_velocity_world_rad_s",Vector3.ZERO);result.rate_sample_valid=bool(telemetry.get("sample_valid",false))
	result.can_request_clearance=not ship.docked
	if ship.docked:return _finish(result,"docked","Корабль в доке. Откройте службы или запросите вылет через проём.")
	if not result.door_open:return _finish(result,"door_closed","Стыковочный проём закрыт. Запросите открытие и дождитесь готовности.")
	if result.relative_speed_mps>SOURCE_SPEED_LIMIT_MPS:return _finish(result,"relative_speed","Снизьте скорость относительно вращающегося дока до 12 м/с.")
	if result.forward_dot<SOURCE_ALIGNMENT_DOT_MIN:return _finish(result,"heading","Направьте нос внутрь стыковочного проёма. «Авто» выполнит заход.")
	if result.up_dot<SOURCE_ALIGNMENT_DOT_MIN:return _finish(result,"roll","Совместите крен корабля с вращающимся проёмом станции.")
	var bay:AABB=geometry.dock_bay
	if minf(radii.x,minf(radii.y,radii.z))<=0 or absf(point.x)+fitted.x>=minf(-bay.position.x,bay.end.x) or absf(point.y)+fitted.y>=minf(-bay.position.y,bay.end.y):return _finish(result,"hull_clearance","Корпус не помещается в текущем положении. Выровняйтесь по центру проёма.")
	if absf(point.z)>SOURCE_INTERIOR_Z_LIMIT_M:return _finish(result,"outside_capture","Войдите внутрь дока к его центру. Близости к станции недостаточно; «Авто» выполнит заход.")
	if point.z-fitted.z<=bay.position.z or point.z+fitted.z>=bay.end.z:return _finish(result,"hull_clearance","Корпус выходит за границу внутреннего объёма дока.")
	# The same existing physical guard remains authoritative. Feedback never
	# accepts a rounded display value or replaces an actual triangle query.
	result.ready=ship.can_dock()
	if not result.ready:return _finish(result,"geometry_blocked","Корпус пересекает геометрию станции. Выровняйтесь по центру проёма.")
	return _finish(result,"ready","Проём открыт, положение и относительная скорость подходят. Нажмите «Стыковка».")
