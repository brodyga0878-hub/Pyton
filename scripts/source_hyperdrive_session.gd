extends RefCounted
# Source hardware/inventory with an explicit bridge to the prototype cargo.
# F903 always reads the unchanged source hull spec; carried mass is capacity only.
const Kernel=preload("res://scripts/source_hyperdrive.gd")
const SCHEMA:="starfrontier-source-hyperdrive-session-v1"
const FUEL_PROFILE:="source-f903-hydrogen-military-v1"
const PRICING:="basic-source-workshop-pricing-adapter-v1"
const MAX_QUANTITY:=65535
static var _resource:Dictionary={}
static var _resource_mutex:=Mutex.new()
var ship_id:=""
var model_index:=-1
var drive_index:=0
var hydrogen:=0
var military:=0
var radioactives:=0
var fixed_equipment_space_t:=0
var adapted_cargo_t:=0
var adapted_equipment_space_t:=0

static func _number(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _data()->Dictionary:
	# Map workers repeatedly validate copied sessions. Keep one private immutable
	# resource copy instead of duplicating all extraction metadata per drive row.
	_resource_mutex.lock()
	if _resource.is_empty():_resource=Kernel.resource()
	var result:=_resource
	_resource_mutex.unlock();return result
static func _definition(id:String)->Dictionary:
	var data:=_data();var profiles:Variant=data.get("new_session_profiles",{})
	var value:Variant=profiles.get(id) if profiles is Dictionary else null
	return value.duplicate(true) if value is Dictionary else {}
static func _digest()->String:return FileAccess.get_sha256(Kernel.DATA_PATH)
static func drive_mass(index:int)->int:
	for value:Variant in _data().get("drives",[]):
		if value is Dictionary and int(value.get("index",-1))==index:return int(value.get("mass_tonnes_u32",-1))
	return -1
static func drive_name(index:int)->String:
	if index==0:return "Гипердвигатель снят"
	if index==1:return "Встроенный межпланетный двигатель"
	if index>=2 and index<=9:return "Стандартный гипердвигатель, класс %d"%(index-1)
	if index>=10 and index<=12:return "Военный гипердвигатель, класс %d"%(index-9)
	return "Специальный гипердвигатель"
func configure(id:String)->bool:
	var definition:=_definition(id)
	for key in ["source_model_index","source_drive_index","hydrogen","military","waste","fixed_equipment_space_t"]:
		if not _number(definition.get(key),0,MAX_QUANTITY):return false
	var candidate:RefCounted=get_script().new()
	candidate.ship_id=id;candidate.model_index=int(definition.source_model_index);candidate.drive_index=int(definition.source_drive_index)
	candidate.hydrogen=int(definition.hydrogen);candidate.military=int(definition.military);candidate.radioactives=int(definition.waste)
	candidate.fixed_equipment_space_t=int(definition.fixed_equipment_space_t)
	if not candidate.valid():return false
	_copy(candidate);return true
func capacity()->int:
	var spec:=Kernel.ship_spec(model_index)
	return Kernel._s16(int(spec.decode_u16(8))) if spec.size()>=10 else -1
func hull_mass()->int:
	var spec:=Kernel.ship_spec(model_index)
	return Kernel._s16(int(spec.decode_u16(6))) if spec.size()>=10 else 0
func cargo_quantity()->int:return adapted_cargo_t+hydrogen+military+radioactives
func occupied()->int:return cargo_quantity()+adapted_equipment_space_t+fixed_equipment_space_t+drive_mass(drive_index)
func free_space()->int:return capacity()-occupied()
func fuel_kind()->String:return "military" if drive_index>=10 else "hydrogen"
func fuel()->int:return military if fuel_kind()=="military" else hydrogen
func fuel_capacity()->int:return fuel()+maxi(0,free_space())
func valid()->bool:
	var definition:=_definition(ship_id)
	if definition.is_empty() or model_index!=int(definition.get("source_model_index",-1)) or fixed_equipment_space_t!=int(definition.get("fixed_equipment_space_t",-1)):return false
	if drive_index<0 or drive_index>12 or (drive_index==1 and int(definition.get("source_drive_index",-1))!=1):return false
	for value in [hydrogen,military,radioactives,fixed_equipment_space_t,adapted_cargo_t,adapted_equipment_space_t]:
		if value<0 or value>MAX_QUANTITY:return false
	return hull_mass()>0 and capacity()>=0 and drive_mass(drive_index)>=0 and occupied()<=capacity()
static func ship_bridge(ship:RefCounted)->Dictionary:
	if ship==null or not ship.has_method("total_cargo") or not ship.has_method("equipment_space"):return {}
	var cargo:Variant=ship.total_cargo();var equipment:Variant=ship.equipment_space()
	if not _number(cargo,0,MAX_QUANTITY) or not _number(equipment,0,MAX_QUANTITY) or not ship.ship_id is String:return {}
	return {"ship_id":str(ship.ship_id),"adapted_cargo_t":int(cargo),"adapted_equipment_space_t":int(equipment)}
func bridge_matches(ship:RefCounted)->bool:
	var bridge:=ship_bridge(ship)
	return not bridge.is_empty() and str(bridge.ship_id)==ship_id and int(bridge.adapted_cargo_t)==adapted_cargo_t and int(bridge.adapted_equipment_space_t)==adapted_equipment_space_t and valid()
func with_ship(ship:RefCounted)->RefCounted:
	var bridge:=ship_bridge(ship)
	if bridge.is_empty() or str(bridge.ship_id)!=ship_id:return null
	var candidate:=duplicate_session()
	if candidate==null:return null
	candidate.adapted_cargo_t=int(bridge.adapted_cargo_t);candidate.adapted_equipment_space_t=int(bridge.adapted_equipment_space_t)
	return candidate if candidate.valid() else null
func profile()->Dictionary:
	return {"model_index":model_index,"source_drive_index":drive_index,"player":true,"cargo_u32":cargo_quantity(),"waste_u16":radioactives,"status_u16":0}
func quote(distance_raw:int,consume:=false)->Dictionary:
	if not valid():return {"ok":false,"can_jump":false,"reason":"invalid_session"}
	return Kernel.quote(profile(),distance_raw,hydrogen,military,consume)
func range_quote()->Dictionary:return quote(1)
func snapshot()->Dictionary:
	return {"schema":SCHEMA,"version":1,"source_digest":_digest(),"ship_id":ship_id,"model_index":model_index,"drive_index":drive_index,"hydrogen":hydrogen,"military":military,"radioactives":radioactives,"fixed_equipment_space_t":fixed_equipment_space_t,"adapted_cargo_t":adapted_cargo_t,"adapted_equipment_space_t":adapted_equipment_space_t}
func restore(data:Dictionary)->bool:
	var keys:=["schema","version","source_digest","ship_id","model_index","drive_index","hydrogen","military","radioactives","fixed_equipment_space_t","adapted_cargo_t","adapted_equipment_space_t"]
	if data.size()!=keys.size():return false
	for key in keys:
		if not data.has(key):return false
	if data.schema!=SCHEMA or data.version!=1 or not data.source_digest is String or data.source_digest!=_digest() or not data.ship_id is String:return false
	for key in ["model_index","drive_index","hydrogen","military","radioactives","fixed_equipment_space_t","adapted_cargo_t","adapted_equipment_space_t"]:
		if not _number(data.get(key),0,MAX_QUANTITY):return false
	var candidate:RefCounted=get_script().new()
	candidate.ship_id=str(data.ship_id);candidate.model_index=int(data.model_index);candidate.drive_index=int(data.drive_index)
	candidate.hydrogen=int(data.hydrogen);candidate.military=int(data.military);candidate.radioactives=int(data.radioactives)
	candidate.fixed_equipment_space_t=int(data.fixed_equipment_space_t);candidate.adapted_cargo_t=int(data.adapted_cargo_t);candidate.adapted_equipment_space_t=int(data.adapted_equipment_space_t)
	if not candidate.valid():return false
	_copy(candidate);return true
func _copy(other:RefCounted)->void:
	ship_id=other.ship_id;model_index=other.model_index;drive_index=other.drive_index;hydrogen=other.hydrogen;military=other.military;radioactives=other.radioactives
	fixed_equipment_space_t=other.fixed_equipment_space_t;adapted_cargo_t=other.adapted_cargo_t;adapted_equipment_space_t=other.adapted_equipment_space_t
func duplicate_session()->RefCounted:
	var candidate:RefCounted=get_script().new()
	return candidate if candidate.restore(snapshot()) else null
func commit(distance_raw:int,expected:Dictionary)->Dictionary:
	var current:=quote(distance_raw)
	if not current.get("ok",false) or not current.get("can_jump",false):return {"ok":false,"reason":"quote_unavailable"}
	for key in ["required_fuel","duration_raw_u32","max_range_raw","current_range_raw"]:
		if current.get(key)!=expected.get(key):return {"ok":false,"reason":"quote_changed"}
	var consumed:=quote(distance_raw,true)
	if not consumed.get("ok",false) or not consumed.get("can_jump",false):return {"ok":false,"reason":"commit_rejected"}
	var candidate:=duplicate_session()
	if candidate==null:return {"ok":false,"reason":"invalid_session"}
	candidate.hydrogen=int(consumed.hydrogen_after);candidate.military=int(consumed.military_after);candidate.radioactives=int(consumed.waste_after)
	if not candidate.valid() or int(consumed.cargo_after)!=candidate.cargo_quantity():return {"ok":false,"reason":"cargo_accounting_mismatch"}
	_copy(candidate);return consumed
func service_state(credits:int,available:bool,reason:String="")->Dictionary:
	var ranges:=range_quote();var current_range:=float(ranges.get("current_range_raw",0))/100.0
	var state:={"schema":"source-hyperdrive-services-v1","source_mode":true,"ship_id":ship_id,"source_model_index":model_index,"profile_name":"Корабельное оборудование и гипертопливо","pricing_profile":PRICING,"drive_class":drive_index,"drive_index":drive_index,"drive_name":drive_name(drive_index),"drive_class_label":drive_name(drive_index),"class_label":drive_name(drive_index),"range_ly":maxf(0,current_range),"maximum_range_ly":maxf(0,float(ranges.get("max_range_raw",0))/100.0),"fuel_kind":fuel_kind(),"hydrogen":hydrogen,"military":military,"radioactives":radioactives,"source_capacity_t":capacity(),"occupied_t":occupied(),"free_t":free_space(),"flight_cargo_t":adapted_cargo_t,"flight_equipment_space_t":adapted_equipment_space_t,"credits":credits,"docked":available,"service_available":available,"reason":reason,"drives":[],"fuels":[],"remove_price":maxi(0,drive_mass(drive_index))*50,"can_remove":available and drive_index>=2,"remove_reason":reason,"can_unload_waste":available and radioactives>0 and credits>=radioactives*10,"unload_quantity":radioactives,"waste_price":radioactives*10,"waste_reason":reason}
	for index in range(2,13):
		var mass:=drive_mass(index);var price:=mass*100;var after:=occupied()-drive_mass(drive_index)+mass
		var why:=reason
		if index==drive_index:why="Этот гипердвигатель уже установлен."
		elif after>capacity():why="Недостаточно свободного места."
		elif credits<price:why="Недостаточно средств."
		state.drives.append({"class":index,"drive_index":index,"name":drive_name(index),"class_label":drive_name(index),"space_t":mass,"installed":index==drive_index,"price":price,"can_install":available and why.is_empty(),"reason":why})
	for kind in ["hydrogen","military"]:
		var quantity:=hydrogen if kind=="hydrogen" else military
		var fill:=mini(maxi(0,free_space()),maxi(0,int(credits/10)))
		var why:=reason
		if free_space()<1:why="В трюме нет свободного места."
		elif credits<10:why="Недостаточно средств."
		state.fuels.append({"id":kind,"name":"Водородное топливо" if kind=="hydrogen" else "Военное топливо","quantity":quantity,"unit_price":10,"can_refuel":available and why.is_empty(),"reason":why,"fill_quantity":fill,"fill_price":fill*10,"can_fill":available and fill>0,"fill_reason":why,"can_unload":available and quantity>0,"unload_quantity":1 if quantity>0 else 0,"unload_price":0,"unload_reason":reason if not available else ("Топлива этого типа нет." if quantity==0 else "")})
	if radioactives==0:state.waste_reason="Радиоактивных отходов нет."
	elif credits<radioactives*10:state.waste_reason="Недостаточно средств для передачи отходов."
	if drive_index<2:state.remove_reason="Съёмный гипердвигатель не установлен."
	elif credits+int(state.remove_price)>1000000000:
		state.can_remove=false;state.remove_reason="Сумма возврата превышает допустимый баланс."
	return state
func service(action:String,id:String,quantity:int,credits:int)->Dictionary:
	var rejected:={"ok":false,"credits":credits,"message":"Недопустимая операция службы станции."}
	if not valid() or credits<0 or credits>1000000000:return rejected
	var candidate:=duplicate_session()
	if candidate==null:return rejected
	var cost:=0;var message:=""
	match action:
		"install_drive":
			if not id.is_valid_int() or quantity!=1:return rejected
			var index:=id.to_int()
			if str(index)!=id or index<2 or index>12 or index==drive_index:return rejected
			candidate.drive_index=index;cost=drive_mass(index)*100;message="Гипердвигатель установлен."
		"remove_drive":
			if not id.is_empty() or quantity!=1 or drive_index<2:return rejected
			cost=-drive_mass(drive_index)*50;candidate.drive_index=0;message="Гипердвигатель снят."
		"refuel":
			if quantity<1 or quantity>MAX_QUANTITY or not id in ["hydrogen","military"]:return rejected
			if id=="hydrogen":candidate.hydrogen+=quantity
			else:candidate.military+=quantity
			cost=quantity*10;message="Гипертопливо пополнено."
		"unload_fuel":
			if quantity<1 or quantity>MAX_QUANTITY or not id in ["hydrogen","military"]:return rejected
			if id=="hydrogen":candidate.hydrogen-=quantity
			else:candidate.military-=quantity
			message="Гипертопливо передано службе станции без оплаты."
		"unload_waste":
			if not id.is_empty() or quantity<1 or quantity>radioactives:return rejected
			candidate.radioactives-=quantity;cost=quantity*10;message="Радиоактивные отходы переданы службе станции."
		_:return rejected
	if not candidate.valid() or cost>credits or credits-cost<0 or credits-cost>1000000000:return rejected
	_copy(candidate);return {"ok":true,"credits":credits-cost,"message":message,"pricing_profile":PRICING}
