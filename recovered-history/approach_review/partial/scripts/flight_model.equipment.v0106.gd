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
	credits+=refund
	equipment.erase(id)
	return true

func ship_trade_value() -> int:
	return floori(float(economy_catalog.ship_prices[ship_id])*0.8*(0.5+0.5*hull/100.0))
