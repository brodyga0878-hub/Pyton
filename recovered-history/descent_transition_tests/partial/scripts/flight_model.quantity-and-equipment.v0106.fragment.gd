
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
