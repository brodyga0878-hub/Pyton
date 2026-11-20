extends SceneTree

const Scene = preload("res://main.tscn")
const SessionIO = preload("res://scripts/session_io.gd")
const Fixture = preload("res://tests/flight_fixture.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := Scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud: CanvasLayer = game._hud
	hud.action_requested.emit("contract")
	hud.action_requested.emit("dock")
	_check(game.flight.docked == 0 and game.flight.departure_status().active
		and game.flight.contract_stage == 1, "The HUD requests departure for a contracted flight")
	_check(Fixture.await_departure(game.flight, 15.0, game._physics_process), "The HUD departure advances into a normal flight")
	hud.action_requested.emit("autopilot")
	_check(game.flight.autopilot, "The HUD engages autopilot")
	hud.action_requested.emit("report")
	await process_frame
	var before: float = game.flight.elapsed
	game._physics_process(0.5)
	_check(game._report.visible and game.flight.elapsed == before, "Opening the report suspends flight")
	var close_button: Button = game._report_buttons.back()
	var touch_position := close_button.get_global_rect().get_center()
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 7
		touch.position = touch_position
		touch.pressed = pressed
		root.push_input(touch, true)
	_check(not game._report.visible and game._report_touches.is_empty(), "Indexed touch closes the report and releases the finger")
	var report := SessionIO.new()
	report.trace("integration", {"target": game.flight.target})
	var exported := report.export_report(game.flight.snapshot(), "user://integration-report.zip")
	var zip := ZIPReader.new()
	_check(exported.ok and zip.open(exported.path) == OK, "Report ZIP is readable")
	if exported.ok and zip.file_exists("flight.json"):
		var state := JSON.parse_string(zip.read_file("flight.json").get_string_from_utf8()) as Dictionary
		_check(int(state.get("contract_stage", -1)) == 1, "Report has the actual flight and contract state")
		_check(zip.file_exists("events.jsonl") and zip.file_exists("report.json"), "Report includes metadata and history")
	zip.close()
	_check(int(SessionIO.load_state().get("docked", -2)) == -1, "Normal launch writes a resumable save")
	game.queue_free()
	await process_frame
	print("Scene integration: %d failures" % failures.size())
	for message in failures:
		printerr(message)
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
