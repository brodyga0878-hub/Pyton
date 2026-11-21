extends RefCounted
## The player's presentation choices are independent of the flight save.

const SessionIO := preload("res://scripts/session_io.gd")
const FlightAudio := preload("res://scripts/flight_audio.gd")
const Music := preload("res://scripts/flight_music.gd")
const PATH := "user://presentation.json"
const LEGACY_FIELDS := ["quality", "sensitivity", "layout"]
const PRE_INVERSION_FIELDS := ["quality", "sensitivity", "layout", FlightAudio.VOLUME_KEY]
const PRE_AUDIO_MIX_FIELDS := ["quality", "sensitivity", "layout", FlightAudio.VOLUME_KEY, "invert_yaw", "invert_pitch"]
const AXIS_CHOICES := ["Обычная", "Инверсия"]
const OPTIONS := {
	"quality": ["Экономичный", "Сбалансированный", "Детальный"],
	"sensitivity": ["Точно", "Обычно", "Быстро"],
	"layout": ["Стандарт", "Действия слева"],
	FlightAudio.VOLUME_KEY: FlightAudio.LEVEL_LABELS,
	"invert_yaw": AXIS_CHOICES,
	"invert_pitch": AXIS_CHOICES,
	FlightAudio.EFFECT_VOLUME_KEY: FlightAudio.LEVEL_LABELS,
	Music.VOLUME_KEY: FlightAudio.LEVEL_LABELS,
	Music.MODE_KEY: Music.MODE_LABELS,
	"language": ["Русский", "English"],
}
const AUDIO_FIELDS := [FlightAudio.VOLUME_KEY, FlightAudio.EFFECT_VOLUME_KEY, Music.VOLUME_KEY, Music.MODE_KEY]

var quality := 1
var sensitivity := 1
var layout := 0
var notification_volume := FlightAudio.DEFAULT_LEVEL
var invert_yaw := 0
var invert_pitch := 0
var effects_volume := FlightAudio.DEFAULT_LEVEL
var music_volume := Music.DEFAULT_LEVEL
var music_mode := Music.CONTEXTUAL
var language := 0


func snapshot() -> Dictionary:
	return {
		"quality": quality, "sensitivity": sensitivity, "layout": layout,
		FlightAudio.VOLUME_KEY: notification_volume,
		"invert_yaw": invert_yaw, "invert_pitch": invert_pitch,
		FlightAudio.EFFECT_VOLUME_KEY: effects_volume,
		Music.VOLUME_KEY: music_volume, Music.MODE_KEY: music_mode,
		"language": language,
	}


func restore(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var fields := OPTIONS.keys()
	if value.size() == LEGACY_FIELDS.size():
		fields = LEGACY_FIELDS
	elif value.size() == PRE_INVERSION_FIELDS.size():
		fields = PRE_INVERSION_FIELDS
	elif value.size() == PRE_AUDIO_MIX_FIELDS.size():
		fields = PRE_AUDIO_MIX_FIELDS
	elif value.size() == OPTIONS.size() - 1:
		fields.erase("language")
	if value.size() != fields.size():
		return false
	for field: String in fields:
		if not _is_choice(field, value.get(field)):
			return false
	quality = int(value.quality)
	sensitivity = int(value.sensitivity)
	layout = int(value.layout)
	notification_volume = int(value.get(FlightAudio.VOLUME_KEY, FlightAudio.DEFAULT_LEVEL))
	invert_yaw = int(value.get("invert_yaw", 0))
	invert_pitch = int(value.get("invert_pitch", 0))
	effects_volume = int(value.get(FlightAudio.EFFECT_VOLUME_KEY, FlightAudio.DEFAULT_LEVEL))
	music_volume = int(value.get(Music.VOLUME_KEY, Music.DEFAULT_LEVEL))
	music_mode = int(value.get(Music.MODE_KEY, Music.CONTEXTUAL))
	language = int(value.get("language", 0))
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


func pilot_steering(direction: Vector2) -> Vector2:
	return Vector2(-direction.x if invert_yaw == 1 else direction.x,
		-direction.y if invert_pitch == 1 else direction.y)


static func _is_choice(field: String, value: Variant) -> bool:
	if not OPTIONS.has(field) or not (value is int or value is float):
		return false
	return is_finite(value) and floorf(value) == value and value >= 0 and value < OPTIONS[field].size()
