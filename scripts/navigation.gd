class_name Navigation
extends RefCounted
# Newly rebuilt navigation around the explicit, bounded Galaxy catalogue.
# Fuel, jump duration and map positions are adapters, not recovered FFE rules.
const GalaxyData=preload("res://scripts/galaxy.gd")
const FUEL_CAPACITY:=12
const CHARGE_SECONDS:=3.0
var galaxy:=GalaxyData.new()
var current_id:=GalaxyData.SOL_ID
var selected_id:=GalaxyData.SOL_ID
var elapsed_days:=0.0
var fuel:=FUEL_CAPACITY
var remaining:=0.0
var visited:Array=[GalaxyData.SOL_ID]
var pending_id:=-1
var pending_fuel:=0
var station_override:=""
var message:=""

func current()->Dictionary:return galaxy.get_system(current_id)
func selected()->Dictionary:return galaxy.get_system(selected_id)
func distance()->float:return galaxy.distance(current_id,selected_id)
func has_station(id:int=-1)->bool:
	var star:=galaxy.get_system(current_id if id<0 else id)
	return bool(star.get("has_station",false))
func fuel_required()->int:
	var d:=distance()
	return ceili(d/4.0) if is_finite(d) and d>0 else 0
func select(id:int)->bool:
	if remaining>0 or galaxy.get_system(id).is_empty():return false
	selected_id=id;return true

func jump_error(ship:RefCounted)->String:
	if remaining>0:return "Гиперпереход уже готовится."
	if ship.hull<=0:return "Корабль потерян."
	if ship.docked:return "Сначала вылетите со станции."
	if ship.surface_mode:return "Сначала вернитесь на орбиту."
	if ship.combat_active:return "Сначала выйдите из боя."
	if not ship.position.is_finite() or not ship.velocity.is_finite():return "Невозможно определить положение корабля."
	if current_id==selected_id:return "Вы уже в выбранной системе."
	if selected().is_empty():return "Система недоступна в текущем каталоге."
	if distance()>ship.jump_range():return "Система за пределами дальности гипердвигателя."
	if fuel_required()>fuel:return "Недостаточно гипертоплива."
	if ship.velocity.length()>20:return "Затормозите до 20 м/с."
	return ""

func begin_jump(ship:RefCounted)->bool:
	message=jump_error(ship)
	if not message.is_empty():return false
	pending_id=selected_id;pending_fuel=fuel_required();remaining=CHARGE_SECONDS
	ship.brake();message="Заряд гипердвигателя. Повторное нажатие отменяет переход."
	return true

func cancel_jump()->void:
	remaining=0;pending_id=-1;pending_fuel=0;message="Гиперпереход отменён."

func step(dt:float,ship:RefCounted)->bool:
	if remaining<=0 or not is_finite(dt) or dt<=0:return false
	if ship.hull<=0 or ship.docked or ship.surface_mode or ship.combat_active or not ship.velocity.is_finite() or ship.velocity.length()>20:
		cancel_jump();return false
	remaining=maxf(0.0,remaining-dt)
	if remaining>0:return false
	if galaxy.get_system(pending_id).is_empty() or pending_fuel<1 or pending_fuel>fuel:
		cancel_jump();return false
	var travelled:=galaxy.distance(current_id,pending_id)
	current_id=pending_id;selected_id=current_id;fuel-=pending_fuel;elapsed_days+=maxf(0.02,travelled*0.1)
	if not current_id in visited:visited.append(current_id)
	pending_id=-1;pending_fuel=0;station_override=""
	ship.position=Vector3.ZERO;ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.attitude=Quaternion.IDENTITY
	ship.autopilot=false;ship.station_available=has_station()
	message="Прибытие в систему: %s."%current().name
	return true

func refuel(ship:RefCounted)->bool:
	if not ship.docked or not has_station() or remaining>0:return false
	var missing:=FUEL_CAPACITY-fuel
	if missing<=0:message="Баки полны.";return false
	var cost:=missing*10
	if ship.credits<cost:message="Недостаточно средств на заправку.";return false
	ship.credits-=cost;fuel=FUEL_CAPACITY;message="Гипертопливо пополнено."
	return true

func snapshot()->Dictionary:
	return {"schema":"starfrontier-rebuild-navigation-v1","version":1,"current_id":current_id,"selected_id":selected_id,"elapsed_days":elapsed_days,"fuel":fuel,"remaining":remaining,"pending_id":pending_id,"pending_fuel":pending_fuel,"visited":visited.duplicate()}

static func _number(value:Variant,low:float,high:float,whole:=false)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high and (not whole or float(value)==floorf(float(value)))

func restore(data:Dictionary)->bool:
	if data.get("schema")!="starfrontier-rebuild-navigation-v1" or data.get("version")!=1:return false
	for key in ["current_id","selected_id"]:
		if not _number(data.get(key),0,4294967295.0,true) or galaxy.get_system(int(data[key])).is_empty():return false
	if not _number(data.get("elapsed_days"),0,1e9) or not _number(data.get("fuel"),0,FUEL_CAPACITY,true) or not _number(data.get("remaining"),0,CHARGE_SECONDS):return false
	if not _number(data.get("pending_id"),-1,4294967295.0,true) or not _number(data.get("pending_fuel"),0,FUEL_CAPACITY,true):return false
	if not data.get("visited") is Array or data.visited.size()>galaxy.system_count():return false
	var seen:Dictionary={}
	for id in data.visited:
		if not _number(id,0,4294967295.0,true) or galaxy.get_system(int(id)).is_empty() or seen.has(int(id)):return false
		seen[int(id)]=true
	if not seen.has(int(data.current_id)):return false
	if float(data.remaining)>0:
		if int(data.pending_id)!=int(data.selected_id) or int(data.pending_id)==int(data.current_id) or galaxy.get_system(int(data.pending_id)).is_empty() or int(data.pending_fuel)<1 or int(data.pending_fuel)>int(data.fuel):return false
		if int(data.pending_fuel)!=ceili(galaxy.distance(int(data.current_id),int(data.pending_id))/4.0):return false
	elif int(data.pending_id)!=-1 or int(data.pending_fuel)!=0:return false
	current_id=int(data.current_id);selected_id=int(data.selected_id);elapsed_days=float(data.elapsed_days);fuel=int(data.fuel)
	remaining=float(data.remaining);pending_id=int(data.pending_id);pending_fuel=int(data.pending_fuel);visited=data.visited.duplicate()
	station_override="";message=""
	return true
