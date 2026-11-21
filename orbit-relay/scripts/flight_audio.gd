extends Node
## Short, original cockpit cues. Flight notices remain visible independently
## of the selected volume and of the current audio output device.

signal cue_played(cue: String)

const Catalog = preload("res://scripts/sector_catalog.gd")

const VOLUME_KEY := "notification_volume"
const LEVEL_LABELS := ["Выкл.", "Тихо", "Обычно", "Громко"]
const DEFAULT_LEVEL := 2
const LEVEL_DB := [-80.0, -21.0, -14.0, -7.0]
const SAMPLE_RATE := 22050
const POLL_MS := 80
const PEAK := 0.48
const APPROACH_ENTER := 265.0
const APPROACH_EXIT := 325.0
const MIN_CLOSING_SPEED := 3.0
const STELLAR_EXIT := 298.0
const HEAT_ENTER := 82.0
const HEAT_EXIT := 69.0
const LASER_ENTER := 100.0
const LASER_EXIT := 92.0

const PRIORITY := ["approach", "dock", "overheat", "danger"]
const COOLDOWN_MS := {"approach": 1800, "dock": 700, "overheat": 2700, "danger": 2200}
const EVENT_CUES := {
	"patrol_engaged": "danger",
	"ambient_engaged": "danger",
	"combat_missile": "danger",
	"combat_missile_hit": "danger",
	"hull_damage": "danger",
	"thermal_damage": "overheat",
	"atmosphere_damage": "overheat",
	"dock_ready": "dock",
}

# Start frequency, end frequency, note duration, following silence, harmonic mix.
const NOTES := {
	"approach": [[510.0, 510.0, 0.078, 0.035, 0.08], [680.0, 680.0, 0.116, 0.0, 0.08]],
	"dock": [[586.0, 586.0, 0.065, 0.023, 0.1], [742.0, 742.0, 0.067, 0.023, 0.10], [981.0, 981.0, 0.140, 0.0, 0.09]],
	"overheat": [[803.0, 654.0, 0.118, 0.028, 0.20], [620.0, 438.0, 0.157, 0.0, 0.16]],
	"danger": [[348.0, 345.0, 0.067, 0.038, 0.36], [348.0, 345.0, 0.067, 0.038, 0.36], [417.0, 376.0, 0.114, 0.0, 0.32]],
}

var level := DEFAULT_LEVEL
var _streams := {}
var _player: AudioStreamPlayer
var _ready_at := {}
var _heard := {}
var _approach_target := -1
var _cleared_port := -1
var _active_until := 0
var _active_priority := -1
var _poll_at := 0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "FlightNotifications"
	_player.volume_db = LEVEL_DB[level]
	add_child(_player)


func _exit_tree() -> void:
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null


func set_level(value: int) -> bool:
	if value < 0 or value >= LEVEL_DB.size():
		return false
	level = value
	if is_instance_valid(_player):
		_player.volume_db = LEVEL_DB[level]
		if level == 0:
			_player.stop()
			_active_until = 0
			_active_priority = -1
	return true


func notify(event: String, now_ms := Time.get_ticks_msec(), dock_port := -1) -> bool:
	var cue: String = EVENT_CUES.get(event, "")
	if cue.is_empty():
		return false
	if cue == "dock" and dock_port >= 0:
		_cleared_port = dock_port
	var accepted := _offer(cue, now_ms)
	if accepted or now_ms < int(_ready_at.get(cue, 0)):
		_heard[cue] = true
	return accepted


func poll(flight: RefCounted, now_ms := Time.get_ticks_msec()) -> String:
	if now_ms < _poll_at:
		return ""
	_poll_at = now_ms + POLL_MS
	if flight.docked >= 0 or flight.landed or flight.jump_seconds_left > 0.0:
		_heard.clear()
		_approach_target = -1
		_cleared_port = -1
		return ""
	var target: int = flight.target
	var position: Vector3 = flight.position
	var distance := INF
	var closing := 0.0
	if Catalog.system_of_site(target) == int(flight.system_id) and (not Catalog.is_port(target) or flight.station_operational(target)):
		var delta: Vector3 = flight.target_gate(target) - position
		var drift: Vector3 = flight.velocity - flight.target_velocity(target)
		distance = delta.length()
		closing = delta.normalized().dot(drift)
	else:
		target = -1
	var cleared_port := -1
	if target >= 0 and int(flight.dock_access.port) == target and flight.dock_access.status(target, flight.orbit_time).ready:
		cleared_port = target
	var star_distance := INF
	for star: int in Catalog.stars_for(flight.system_id):
		star_distance = minf(star_distance, position.distance_to(flight.target_position(star)))
	var hostile: bool = flight.patrol.in_danger(flight) or flight.convoy_order.in_danger(flight) or flight.ambient.in_danger(flight)
	return observe({
		"target": target, "distance": distance, "closing": closing, "cleared_port": cleared_port,
		"star_distance": star_distance, "hostile": hostile, "missile": not flight.combat.projectile_status().is_empty(),
		"heat": maxf(flight.star_heat, flight.entry_heat),
		"laser_load": float(flight.combat.heat) + float(flight.combat.profile().heat),
	}, now_ms)


func observe(sample: Dictionary, now_ms := Time.get_ticks_msec()) -> String:
	var target := int(sample.get("target", -1))
	var distance := float(sample.get("distance", INF))
	var cleared_port := int(sample.get("cleared_port", -1))
	var star_distance := float(sample.get("star_distance", INF))
	var heat := float(sample.get("heat", 0.0))
	var laser := float(sample.get("laser_load", 0.0))
	var missile := bool(sample.get("missile", false))
	var hostile := bool(sample.get("hostile", false))

	if target != _approach_target or distance >= APPROACH_EXIT:
		_approach_target = target
		_heard.erase("approach")
	if cleared_port != _cleared_port:
		_cleared_port = cleared_port
		_heard.erase("dock")
	if heat <= HEAT_EXIT and laser <= LASER_EXIT:
		_heard.erase("overheat")
	if not hostile and not missile and star_distance >= STELLAR_EXIT:
		_heard.erase("danger")

	var messages := {}
	if target >= 0 and distance <= APPROACH_ENTER and float(sample.get("closing", 0.0)) >= MIN_CLOSING_SPEED:
		messages.approach = "Цель близко. Контролируйте скорость сближения."
	if cleared_port >= 0:
		messages.dock = "Допуск к швартовке подтверждён. Створ открыт."
	if heat >= HEAT_ENTER:
		messages.overheat = "Температура корпуса опасно растёт. Уменьшите нагрузку."
	elif laser > LASER_ENTER:
		messages.overheat = "Лазер перегрет. Дождитесь охлаждения."
	if missile or hostile or star_distance < Catalog.SCOOP_INNER:
		messages.danger = "Обнаружена приближающаяся ракета." if missile else ("Обнаружен боевой контакт." if hostile else "Опасное сближение со звездой. Увеличьте расстояние.")
	for index in range(PRIORITY.size() - 1, -1, -1):
		var cue: String = PRIORITY[index]
		if not messages.has(cue) or _heard.has(cue):
			continue
		if _offer(cue, now_ms):
			_heard[cue] = true
			return messages[cue]
		if now_ms < int(_ready_at.get(cue, 0)):
			_heard[cue] = true
	return ""


func stream_for(cue: String) -> AudioStreamWAV:
	if not NOTES.has(cue):
		return null
	if not _streams.has(cue):
		_streams[cue] = _synthesize(NOTES[cue])
	return _streams[cue]


func _offer(cue: String, now_ms: int) -> bool:
	var priority := PRIORITY.find(cue)
	if now_ms < int(_ready_at.get(cue, 0)) or (now_ms < _active_until and priority <= _active_priority):
		return false
	_ready_at[cue] = now_ms + int(COOLDOWN_MS[cue])
	if level == 0 or not is_instance_valid(_player):
		return true
	var sound := stream_for(cue)
	_active_until = now_ms + ceili(sound.get_length() * 1000.0)
	_active_priority = priority
	_player.stream = sound
	_player.play()
	cue_played.emit(cue)
	return true


static func _synthesize(notes: Array) -> AudioStreamWAV:
	var frame_count := 0
	for note: Array in notes:
		frame_count += roundi(float(note[2]) * SAMPLE_RATE) + roundi(float(note[3]) * SAMPLE_RATE)
	var samples := PackedByteArray()
	samples.resize(frame_count * 2)
	var offset := 0
	for note: Array in notes:
		var start := float(note[0])
		var ratio := (float(note[1]) - start) / float(note[2])
		var count := roundi(float(note[2]) * SAMPLE_RATE)
		var edge := maxi(2, roundi(0.016 * SAMPLE_RATE))
		var overtone := float(note[4])
		for sample in range(count):
			var seconds := float(sample) / SAMPLE_RATE
			var phase := TAU * (start * seconds + 0.5 * ratio * seconds * seconds)
			var envelope := smoothstep(0.0, float(edge), float(mini(sample, count - 1 - sample)))
			var amplitude := sin(phase) * (1.0 - overtone) + sin(phase * 2.0) * overtone
			samples.encode_s16((offset + sample) * 2, roundi(amplitude * envelope * PEAK * 32767.0))
		offset += count + roundi(float(note[3]) * SAMPLE_RATE)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = SAMPLE_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = samples
	return stream
