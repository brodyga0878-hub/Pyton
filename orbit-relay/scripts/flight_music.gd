extends Node
## The original stereo soundtrack follows the flight state with an audio crossfade.

signal track_changed(track: String)

const VOLUME_KEY := "music_volume"
const MODE_KEY := "music_mode"
const MODE_LABELS := ["По обстановке", "Непрерывно"]
const DEFAULT_LEVEL := 1
const LEVEL_GAIN := [0.0, 0.13, 0.23, 0.36]
const CONTEXTUAL := 0
const CONTINUOUS := 1
const TRACKS := {
	"berth": "res://assets/audio/berth.wav",
	"flight": "res://assets/audio/flight.wav",
	"combat": "res://assets/audio/combat.wav",
	"transit": "res://assets/audio/transit.wav",
}
const CROSSFADE_SECONDS := 0.72

var level := DEFAULT_LEVEL
var mode := CONTEXTUAL
var track := ""
var _players: Dictionary[String, AudioStreamPlayer] = {}
var _gain: Dictionary[String, float] = {}
var _streams: Dictionary[String, AudioStreamWAV] = {}


func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players.values():
		player.stop()
		player.stream = null


func configure(value: int, policy: int) -> bool:
	if value < 0 or value >= LEVEL_GAIN.size() or policy < 0 or policy >= MODE_LABELS.size():
		return false
	level = value
	mode = policy
	for name: String in _players:
		var player := _players[name]
		if level == 0:
			player.stop()
			_gain[name] = 0.0
		_apply_gain(name, player)
	return true


func advance(context: String, delta: float) -> void:
	var selected := "flight" if mode == CONTINUOUS else context
	if level == 0 or not TRACKS.has(selected) or not is_inside_tree():
		return
	var selected_player := _player_for(selected)
	if selected_player.stream == null:
		return
	if not selected_player.playing:
		selected_player.play()
	if track != selected:
		track = selected
		track_changed.emit(track)
	var rise := maxf(0.0, delta) / CROSSFADE_SECONDS
	for name: String in _players:
		var player := _players[name]
		if not player.playing:
			continue
		var target := 1.0 if name == selected else 0.0
		_gain[name] = move_toward(_gain[name], target, rise)
		if _gain[name] == 0.0 and name != selected:
			player.stop()
		_apply_gain(name, player)


func stream_for(name: String) -> AudioStreamWAV:
	if not TRACKS.has(name):
		return null
	if not _streams.has(name):
		var track_source := load(TRACKS[name]) as AudioStreamWAV
		if track_source != null:
			_streams[name] = track_source
	return _streams.get(name)


func _player_for(name: String) -> AudioStreamPlayer:
	if _players.has(name):
		return _players[name]
	var player := AudioStreamPlayer.new()
	player.name = "Score_" + name
	player.volume_db = -80.0
	player.stream = stream_for(name)
	add_child(player)
	_players[name] = player
	_gain[name] = 0.0
	return player


func _apply_gain(name: String, player: AudioStreamPlayer) -> void:
	player.volume_db = linear_to_db(maxf(0.0001, _gain[name] * float(LEVEL_GAIN[level])))


static func context_for(flight: RefCounted) -> String:
	if flight == null or flight.docked >= 0 or flight.landed:
		return "berth"
	if flight.jump_seconds_left > 0.0:
		return "transit"
	if flight.patrol.in_danger(flight) or flight.ambient.in_danger(flight) or flight.convoy_order.in_danger(flight) \
			or not flight.combat.projectile_status().is_empty():
		return "combat"
	return "flight"
