extends Node
## Short, original cockpit cues. Flight notices remain visible independently
## of the selected volume and of the current audio output device.

signal cue_played(cue: String)
signal effect_played(cue: String)

const Catalog = preload("res://scripts/sector_catalog.gd")
const Music := preload("res://scripts/flight_music.gd")

const VOLUME_KEY := "notification_volume"
const EFFECT_VOLUME_KEY := "effects_volume"
const LEVEL_LABELS := ["Выкл.", "Тихо", "Обычно", "Громко"]
const DEFAULT_LEVEL := 2
const LEVEL_DB := [-80.0, -21.0, -14.0, -7.0]
const EFFECT_LEVEL_DB := [-80.0, -22.0, -15.0, -8.0]
const EFFECT_VOICES := 3
const EFFECT_REPEAT_MS := 90
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
const EVENT_EFFECTS := {
	"launch": "thrust", "lift": "thrust", "land": "touchdown", "dock": "latch",
	"gear_deploy": "gear", "gear_retract": "gear", "departure_open": "latch",
	"jump_charging": "charge", "jump_committed": "fold", "jump_complete": "arrival",
	"atmosphere_enter": "entry", "scoop_start": "scoop", "scoop_canister": "canister",
	"mining_deploy": "drill", "remote_rig_deployed": "drill", "mining_pulse": "ore_pulse",
	"fragment_collected": "latch", "cargo_pod_collected": "latch", "cargo_jettisoned": "release",
	"survey_record": "scan", "galaxy_scan": "scan", "combat_ecm": "jamming",
	"ambient_fire": "laser", "patrol_fire": "laser", "convoy_order_fire": "laser",
	"ambient_victory": "laser", "patrol_victory": "laser",
	"ambient_enemy_hit": "impact", "patrol_enemy_hit": "impact", "convoy_order_enemy_hit": "impact",
	"combat_missile_hit": "impact", "hull_damage": "impact",
}

# Start frequency, end frequency, note duration, following silence, harmonic mix.
const NOTES := {
	"approach": [[510.0, 510.0, 0.078, 0.035, 0.08], [680.0, 680.0, 0.116, 0.0, 0.08]],
	"dock": [[586.0, 586.0, 0.065, 0.023, 0.1], [742.0, 742.0, 0.067, 0.023, 0.10], [981.0, 981.0, 0.140, 0.0, 0.09]],
	"overheat": [[803.0, 654.0, 0.118, 0.028, 0.20], [620.0, 438.0, 0.157, 0.0, 0.16]],
	"danger": [[348.0, 345.0, 0.067, 0.038, 0.36], [348.0, 345.0, 0.067, 0.038, 0.36], [417.0, 376.0, 0.114, 0.0, 0.32]],
}

# Effects optionally mix filtered noise after the harmonic voice.
const EFFECT_NOTES := {
	"thrust": [[58.0, 154.0, 0.42, 0.0, 0.21, 0.67]],
	"touchdown": [[113.0, 53.0, 0.175, 0.028, 0.18, 0.51], [178.0, 81.0, 0.15, 0.0, 0.12, 0.34]],
	"latch": [[197.0, 148.0, 0.071, 0.022, 0.45, 0.33], [339.0, 258.0, 0.101, 0.0, 0.40, 0.25]],
	"gear": [[124.0, 206.0, 0.16, 0.025, 0.31, 0.54], [138.0, 98.0, 0.08, 0.0, 0.18, 0.38]],
	"charge": [[156.0, 727.0, 0.62, 0.0, 0.24, 0.11], [728.0, 912.0, 0.17, 0.0, 0.31, 0.10]],
	"fold": [[79.0, 71.0, 0.15, 0.0, 0.48, 0.54], [630.0, 85.0, 0.37, 0.0, 0.37, 0.47]],
	"arrival": [[184.0, 382.0, 0.18, 0.015, 0.31, 0.10], [387.0, 191.0, 0.18, 0.0, 0.39, 0.23]],
	"entry": [[354.0, 138.0, 0.52, 0.0, 0.14, 0.75]],
	"scoop": [[284.0, 390.0, 0.10, 0.022, 0.30, 0.20], [430.0, 515.0, 0.15, 0.0, 0.27, 0.16]],
	"canister": [[785.0, 825.0, 0.045, 0.026, 0.20], [997.0, 933.0, 0.082, 0.0, 0.17]],
	"drill": [[236.0, 177.0, 0.26, 0.015, 0.38, 0.54], [135.0, 68.0, 0.19, 0.0, 0.22, 0.45]],
	"ore_pulse": [[478.0, 132.0, 0.195, 0.0, 0.50, 0.58]],
	"release": [[353.0, 293.0, 0.07, 0.012, 0.32, 0.43], [218.0, 76.0, 0.19, 0.0, 0.22, 0.61]],
	"scan": [[510.0, 655.0, 0.10, 0.031, 0.15], [632.0, 828.0, 0.10, 0.027, 0.16], [744.0, 881.0, 0.11, 0.0, 0.15]],
	"jamming": [[248.0, 711.0, 0.10, 0.015, 0.32, 0.44], [711.0, 329.0, 0.11, 0.015, 0.40, 0.59], [329.0, 96.0, 0.16, 0.0, 0.36, 0.35]],
	"laser": [[1420.0, 146.0, 0.175, 0.0, 0.44, 0.19]],
	"impact": [[174.0, 41.0, 0.21, 0.0, 0.28, 0.66]],
}

var level := DEFAULT_LEVEL
var effects_level := DEFAULT_LEVEL
var music: Music
var _streams := {}
var _player: AudioStreamPlayer
var _effect_players: Array[AudioStreamPlayer] = []
var _effect_cursor := 0
var _effect_ready_at: Dictionary[String, int] = {}
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
	for index in range(EFFECT_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.name = "FlightEffects%d" % index
		voice.volume_db = EFFECT_LEVEL_DB[effects_level]
		add_child(voice)
		_effect_players.append(voice)
	music = Music.new()
	add_child(music)


func _exit_tree() -> void:
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null
	for voice: AudioStreamPlayer in _effect_players:
		voice.stop()
		voice.stream = null


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
	var effect: String = EVENT_EFFECTS.get(event, "")
	var played := _offer_effect(effect, now_ms) if not effect.is_empty() else false
	var cue: String = EVENT_CUES.get(event, "")
	if cue.is_empty():
		return played
	if cue == "dock" and dock_port >= 0:
		_cleared_port = dock_port
	var accepted := _offer(cue, now_ms)
	if accepted or now_ms < int(_ready_at.get(cue, 0)):
		_heard[cue] = true
	return accepted or played


func set_effect_level(value: int) -> bool:
	if value < 0 or value >= EFFECT_LEVEL_DB.size():
		return false
	effects_level = value
	for voice: AudioStreamPlayer in _effect_players:
		voice.volume_db = EFFECT_LEVEL_DB[value]
		if value == 0:
			voice.stop()
	return true


func advance_music(flight: RefCounted, delta: float) -> void:
	music.advance(Music.context_for(flight), delta)


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
	if not NOTES.has(cue) and not EFFECT_NOTES.has(cue):
		return null
	if not _streams.has(cue):
		_streams[cue] = _synthesize(NOTES.get(cue, EFFECT_NOTES.get(cue)))
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


func _offer_effect(cue: String, now_ms: int) -> bool:
	if effects_level == 0 or _effect_players.is_empty() or now_ms < _effect_ready_at.get(cue, 0):
		return false
	_effect_ready_at[cue] = now_ms + EFFECT_REPEAT_MS
	var voice := _effect_players[_effect_cursor]
	_effect_cursor = (_effect_cursor + 1) % _effect_players.size()
	voice.stream = stream_for(cue)
	voice.play()
	effect_played.emit(cue)
	return true


static func _synthesize(notes: Array) -> AudioStreamWAV:
	var frame_count := 0
	for note: Array in notes:
		frame_count += roundi(float(note[2]) * SAMPLE_RATE) + roundi(float(note[3]) * SAMPLE_RATE)
	var samples := PackedByteArray()
	samples.resize(frame_count * 2)
	var offset := 0
	var random := RandomNumberGenerator.new()
	random.seed = hash(notes)
	for note: Array in notes:
		var start := float(note[0])
		var ratio := (float(note[1]) - start) / float(note[2])
		var count := roundi(float(note[2]) * SAMPLE_RATE)
		var edge := maxi(2, roundi(0.016 * SAMPLE_RATE))
		var overtone := float(note[4])
		var noise := float(note[5]) if note.size() > 5 else 0.0
		var filtered := 0.0
		for sample in range(count):
			var seconds := float(sample) / SAMPLE_RATE
			var phase := TAU * (start * seconds + 0.5 * ratio * seconds * seconds)
			var envelope := smoothstep(0.0, float(edge), float(mini(sample, count - 1 - sample)))
			var amplitude := sin(phase) * (1.0 - overtone) + sin(phase * 2.0) * overtone
			if noise > 0.0:
				filtered = lerpf(filtered, random.randf_range(-1.0, 1.0), 0.40)
				amplitude = lerpf(amplitude, filtered, noise)
			samples.encode_s16((offset + sample) * 2, roundi(amplitude * envelope * PEAK * 32767.0))
		offset += count + roundi(float(note[3]) * SAMPLE_RATE)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = SAMPLE_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = samples
	return stream
