class_name ShipCatalog
extends RefCounted
var data: Dictionary
var ships := {}
func _init() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://data/ships.json"))
	for ship in data.ships: ships[str(ship.id)]=ship
func get_ship(id: String) -> Dictionary:
	return ships.get(id,{})
func all() -> Array:
	return data.ships
