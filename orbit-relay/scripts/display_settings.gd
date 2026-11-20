extends RefCounted
## The player's presentation choices are independent of the flight save.

const SessionIO := preload("res://scripts/session_io.gd")
const PATH := "user://presentation.json"
const OPTIONS := {
	"quality": ["Экономичный", "Сбалансированный", "Детальный"],
	"sensitivity": ["Точно", "Обычно", "Быстро"],
	"layout": ["Стандарт", "Действия слева"],
}

var quality := 1
var sensitivity := 1
var layout := 0


func snapshot() -> Dictionary:
	return {"quality": quality, "sensitivity": sensitivity, "layout": layout}


func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != OPTIONS.size():
		return false
	for field: String in OPTIONS:
		if not _is_choice(field, value.get(field)):
			return false
	quality = int(value.quality)
	sensitivity = int(value.sensitivity)
	layout = int(value.layout)
	return true


## Returns true for a valid choice, including the current choice.
func change(field: String, value: int) -> bool:
	if not _is_choice(field, value):
		return false
	set(field, value)
	return true


func load_preferences(path: String = PATH) -> bool:
	return restore(SessionIO.load_state(path))


func save_preferences(path: String = PATH) -> Error:
	return SessionIO.save_state(snapshot(), path)


func fps_limit() -> int:
	return 30 if quality == 0 else 60


static func _is_choice(field: String, value: Variant) -> bool:
	if not OPTIONS.has(field) or not (value is int or value is float):
		return false
	return is_finite(value) and floorf(value) == value and value >= 0 and value < OPTIONS[field].size()
