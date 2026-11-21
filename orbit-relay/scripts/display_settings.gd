extends RefCounted
## The player's presentation choices are independent of the flight save.

const SessionIO := preload("res://scripts/session_io.gd")
const FlightAudio := preload("res://scripts/flight_audio.gd")
const PATH := "user://presentation.json"
const LEGACY_FIELDS := ["quality", "sensitivity", "layout"]
const OPTIONS := {
	"quality": ["Экономичный", "Сбалансированный", "Детальный"],
	"sensitivity": ["Точно", "Обычно", "Быстро"],
	"layout": ["Стандарт", "Действия слева"],
	FlightAudio.VOLUME_KEY: FlightAudio.LEVEL_LABELS,
}

var quality := 1
var sensitivity := 1
var layout := 0
var notification_volume := FlightAudio.DEFAULT_LEVEL


func snapshot() -> Dictionary:
	return {
		"quality": quality, "sensitivity": sensitivity, "layout": layout,
		FlightAudio.VOLUME_KEY: notification_volume,
	}


func restore(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var legacy: bool = value.size() == LEGACY_FIELDS.size() and value.has_all(LEGACY_FIELDS)
	if not legacy and value.size() != OPTIONS.size():
		return false
	for field: String in OPTIONS:
		if legacy and field == FlightAudio.VOLUME_KEY:
			continue
		if not _is_choice(field, value.get(field)):
			return false
	quality = int(value.quality)
	sensitivity = int(value.sensitivity)
	layout = int(value.layout)
	notification_volume = int(value.get(FlightAudio.VOLUME_KEY, FlightAudio.DEFAULT_LEVEL))
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
