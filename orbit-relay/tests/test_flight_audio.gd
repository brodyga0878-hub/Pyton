extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const FlightAudio := preload("res://scripts/flight_audio.gd")
const OrbitRelay := preload("res://main.tscn")
const Patrol := preload("res://scripts/patrol_encounter.gd")

const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_audio_streams()
	_test_priority_and_mute()
	_test_docking_notification_identity()
	_test_closing_hysteresis()
	await _test_game_notifications()
	print("Flight audio integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_audio_streams() -> void:
	var audio := FlightAudio.new()
	var signatures := {}
	for cue: String in ["approach", "dock", "overheat", "danger"]:
		var stream := audio.stream_for(cue)
		var data := stream.data
		var peak := 0
		for index in range(0, data.size(), 2):
			peak = maxi(peak, absi(data.decode_s16(index)))
		var signature := hash(data)
		_expect(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 22050
			and not stream.stereo and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED
			and stream.get_length() > 0.16 and stream.get_length() < 0.40
			and data.decode_s16(0) == 0 and data.decode_s16(data.size() - 2) == 0
			and peak > 1000 and peak < 16500 and not signatures.has(signature)
			and audio.stream_for(cue) == stream, "Generate a distinct cached mono tone with safe fades and no clipping for %s" % cue)
		signatures[signature] = cue
	_expect(audio.stream_for("missing") == null, "Unknown notifications do not synthesize accidental audio")
	audio.free()


func _test_priority_and_mute() -> void:
	var audio := _player()
	var sounded: Array[String] = []
	audio.cue_played.connect(func(cue: String) -> void: sounded.append(cue))
	var mixed := {"target": 1, "distance": 224.0, "closing": 7.0, "cleared_port": 1, "heat": 89.0, "missile": true}
	_expect(audio.level == 2 and audio.observe(mixed, 1000).contains("ракета") and sounded == ["danger"],
		"The most urgent real audio channel takes precedence over simultaneous approach, docking and heat cues")
	_expect(audio.observe(mixed, 1100).is_empty() and sounded == ["danger"],
		"Lower priority signals do not interrupt the active danger tone")
	_expect(audio.observe(mixed, 1350).contains("Температура") and sounded == ["danger", "overheat"],
		"An unacknowledged heat warning plays after the danger tone has protected its interval")
	_expect(audio.set_level(0) and not audio._player.playing and not audio.set_level(-1)
		and not audio.set_level(4) and audio.level == 0, "Muting stops the real player and rejects invalid volume values")
	var silent := audio.observe(mixed, 1800)
	_expect(silent.contains("Допуск") and sounded == ["danger", "overheat"],
		"Mute keeps the pending cockpit caption without emitting a played-signal event")
	_expect(audio.set_level(1) and is_equal_approx(audio._player.volume_db, -21.0)
		and audio.set_level(3) and is_equal_approx(audio._player.volume_db, -7.0),
		"Quiet and loud selections reach the actual Godot audio player")
	_expect(not audio.notify("unmapped", 4700) and audio.notify("dock_ready", 4700) and sounded.back() == "dock"
		and not audio.notify("dock_ready", 4750), "A confirmed event maps to one dock chime and its real cooldown")
	audio.queue_free()


func _test_docking_notification_identity() -> void:
	var audio := _player()
	var sounded: Array[String] = []
	audio.cue_played.connect(func(cue: String) -> void: sounded.append(cue))
	_expect(audio.notify("dock_ready", 3000, 1) and sounded == ["dock"]
		and audio.observe({"cleared_port": 1}, 3780).is_empty() and sounded == ["dock"],
		"A late poll of the same actual clearance does not duplicate its chime after cooldown")
	audio.observe({"cleared_port": -1}, 3870)
	_expect(audio.observe({"cleared_port": 1}, 3960).contains("Допуск") and sounded == ["dock", "dock"],
		"Losing and regaining a clearance can still issue a new chime for that port")
	audio.queue_free()


func _test_closing_hysteresis() -> void:
	var audio := _player()
	var sounded: Array[String] = []
	audio.cue_played.connect(func(cue: String) -> void: sounded.append(cue))
	var flight := Flight.new()
	if not _expect(Fixture.depart(flight) and flight.select_target(1), "Start real local flight before measuring approach motion"):
		audio.queue_free()
		return
	var gate := flight.target_gate(1)
	flight.position = gate + Vector3.BACK * 260.0
	flight.velocity = flight.target_velocity(1) + Vector3.BACK * 10.0
	_expect(audio.poll(flight, 8000).is_empty() and sounded.is_empty(), "A nearby ship moving away does not get an approach signal")
	flight.velocity = flight.target_velocity(1) + Vector3.FORWARD * 8.0
	_expect(audio.poll(flight, 8050).is_empty() and audio.poll(flight, 8100).contains("Цель близко")
		and sounded == ["approach"], "Real target-relative closing speed and the poll rate gate the first alert")
	flight.position = gate + Vector3.BACK * 289.0
	_expect(audio.poll(flight, 10000).is_empty(), "The alarm does not rearm while still inside the outer threshold")
	flight.position = gate + Vector3.BACK * 255.0
	_expect(audio.poll(flight, 10100).is_empty() and sounded.size() == 1, "Repeated inward threshold crossings do not create alert spam")
	flight.position = gate + Vector3.BACK * 330.0
	audio.poll(flight, 10200)
	flight.position = gate + Vector3.BACK * 259.0
	_expect(audio.poll(flight, 10300).contains("Цель близко") and sounded == ["approach", "approach"],
		"Leaving the hysteresis zone properly rearms the real approach alert")
	audio.queue_free()


func _test_game_notifications() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var flight := Flight.new()
	game.flight = flight
	var sounded: Array[String] = []
	game._audio.cue_played.connect(func(cue: String) -> void: sounded.append(cue))
	if not _expect(Fixture.depart(flight) and flight.select_target(0), "The actual scene begins a legitimate local docking approach"):
		viewport.queue_free()
		return
	flight.position = flight.docking_position(0) + Vector3.BACK * 25.0
	flight.velocity = flight.target_velocity(0)
	for _frame in range(ceili((Flight.DockAccess.CLOSING_SECONDS + STEP) / STEP)):
		game._physics_process(STEP)
	game._handle_action("dock_clearance")
	var heard_dock := false
	for _frame in range(ceili(15.0 / STEP)):
		game._physics_process(STEP)
		if sounded.has("dock"):
			heard_dock = true
			break
	_expect(heard_dock and flight.dock_access_status(0).ready
		and _caption(game).contains("Допуск"), "The genuine docking slot opening reaches both the audio player and HUD caption")
	_test_real_heat(game, sounded)
	await _test_muted_patrol(game, sounded)
	await _test_muted_fallback(game, sounded)
	viewport.queue_free()
	await process_frame


func _test_real_heat(game: Node, sounded: Array[String]) -> void:
	var pilot := Flight.new()
	game.flight = pilot
	if not _expect(Fixture.depart(pilot), "Launch another local route before the thermal signal"):
		return
	var star := Catalog.STAR_ID
	pilot.position = pilot.target_position(star) + Vector3.BACK * (Catalog.SCOOP_INNER - 8.0)
	pilot.velocity = pilot.target_velocity(star)
	var amount := pilot.star_heat
	for _frame in range(ceili(20.0 / STEP)):
		pilot.update(STEP, Vector2.ZERO, 0.0, false, false)
		if pilot.status_event == "thermal_damage":
			break
	var actual_warning := pilot.status_event == "thermal_damage"
	game._physics_process(STEP)
	_expect(actual_warning and pilot.star_heat > amount and pilot.star_heat >= Flight.HEAT_DAMAGE_LIMIT and sounded.has("overheat")
		and _caption(game).contains("перегрев"), "Real stellar heating sends the thermal cue through the ordinary game event path")


func _test_muted_patrol(game: Node, sounded: Array[String]) -> void:
	var flight := Flight.new()
	game.flight = flight
	game.presentation.change("notification_volume", 0)
	game._apply_presentation()
	await process_frame
	if not _expect(game._audio.level == 0 and flight.patrol_action() and Fixture.depart(flight) and flight.patrol_action(),
		"Mute with the actual presentation controls and fly the normal patrol"):
		return
	var before := sounded.size()
	for _frame in range(ceili(65.0 / STEP)):
		game._physics_process(STEP)
		if flight.patrol.phase == Patrol.ENGAGED:
			break
	_expect(flight.patrol.phase == Patrol.ENGAGED and sounded.size() == before and not game._audio._player.playing
		and _caption(game).contains("Рейдер"), "A real combat event stays readable with audio disabled and emits no tone")


func _test_muted_fallback(game: Node, sounded: Array[String]) -> void:
	var pilot := Flight.new()
	game.flight = pilot
	if not _expect(Fixture.depart(pilot) and pilot.select_target(1), "Start a separate real approach with no thermal or combat notice pending"):
		return
	pilot.position = pilot.target_gate(1) + Vector3.BACK * 250.0
	pilot.velocity = pilot.target_velocity(1) + Vector3.FORWARD * 12.0
	game._deliver_notice()
	var before := sounded.size()
	var next_poll := Time.get_ticks_msec() + FlightAudio.POLL_MS + 1
	while Time.get_ticks_msec() < next_poll:
		await process_frame
	game._physics_process(STEP)
	_expect(_caption(game).contains("Цель близко") and sounded.size() == before and not game._audio._player.playing,
		"Real proximity telemetry still reaches the HUD through the silent fallback when no normal notice exists")


func _caption(game: Node) -> String:
	return game._hud._notice.text


func _player() -> FlightAudio:
	var audio := FlightAudio.new()
	root.add_child(audio)
	return audio


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append("FAIL: " + description)
	return value
