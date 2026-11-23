extends SceneTree

const Main := preload("res://main.tscn")
const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const GalaxyChart := preload("res://scripts/galaxy_chart.gd")
const GalaxyMap := preload("res://scripts/galaxy_map.gd")
const Fixture := preload("res://tests/flight_fixture.gd")

var _canvas: SubViewport
var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_previous_atlas_area()
	_test_spatial_projection()
	await _test_large_discovery_atlas()
	await _test_map_ui()
	print("Galactic atlas integration: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_previous_atlas_area() -> void:
	var prior_size := Catalog.PRE_ATLAS_DESTINATION_COUNT
	var last_known := Catalog.PRE_ATLAS_SYSTEM_COUNT - 1
	var old := Flight.new().snapshot()
	old.schema = 46
	Fixture.remove_expanded_market_from_legacy(old)
	old.mining.reserves.resize(prior_size)
	old.cartography.systems = [{"system": last_known, "epoch": 0.0}]
	var site: int = Catalog.mines_for(last_known)[0]
	old.cartography.scans = [{"site": site, "epoch": 0.0}]
	old.mining.reserves[site] -= 12
	var fresh := Flight.new()
	if not _expect(fresh.restore(old), "Open an exact-shaped .92 flight with the last old system recorded"):
		return
	_expect(fresh.system_known(last_known) and fresh.body_dossier(site).known
		and fresh.mining.reserve_at(site) == old.mining.reserves[site] and not fresh.system_known(last_known + 1),
		"Restore the old observations and depletion while new systems remain undiscovered")
	var earlier := fresh.snapshot()
	old.cartography.systems.append({"system": last_known + 1, "epoch": 0.0})
	_expect(not fresh.restore(old) and fresh.snapshot() == earlier,
		"An old schema rejects a new system ID without changing the live flight")
	var stars := 0
	for id in range(Catalog.SYSTEM_COUNT):
		stars += Catalog.stars_for(id).size()
	_expect(Catalog.SYSTEM_COUNT == 1024 and stars == 1037,
		"Actual star components are counted separately from selectable systems")


func _test_spatial_projection() -> void:
	var generated := Catalog.AUTHORED_SYSTEM_COUNT
	var systems: Array[int] = [Catalog.HOME_SYSTEM, generated]
	var chart := GalaxyChart.new()
	chart.size = Vector2(1200, 720)
	chart.set_systems(systems, systems, -1, false)
	var before: Vector2 = chart.marker_position(generated) - chart.marker_position(Catalog.HOME_SYSTEM)
	var separation := Catalog.system_position3(generated) - Catalog.system_position3(Catalog.HOME_SYSTEM)
	chart.rotate_by(Vector2(0.0, PI / (2.0 * GalaxyChart.ROTATION_RADIANS_PER_PIXEL)))
	var across: Vector2 = chart.marker_position(generated) - chart.marker_position(Catalog.HOME_SYSTEM)
	_expect(not is_zero_approx(separation.z) and is_equal_approx(across.x, before.x)
		and is_equal_approx(across.y, -separation.z * chart._pixels_per_light_year()),
		"A quarter-turn reveals the catalogued height while preserving the horizontal separation")
	chart.free()


func _test_large_discovery_atlas() -> void:
	# A supported-size long-voyage save is an explicit stress fixture. Its
	# discoveries do not assert that this entire journey has been flown here.
	var pilot := Flight.new()
	var payload := pilot.snapshot()
	var discoveries: Array[int] = []
	for id in range(Catalog.SYSTEM_COUNT, Catalog.SYSTEM_COUNT + 20000):
		discoveries.append(id)
	payload.cartography["sector_systems"] = [[0.0, discoveries]]
	if not _expect(pilot.restore(payload), "A valid schema56 long-survey fixture loads all20,000 discoveries"):
		return
	var before := pilot.snapshot()
	var map := GalaxyMap.new()
	root.add_child(map)
	map.open(pilot)
	await process_frame
	_expect(map._atlas and map._known.size() == discoveries.size() + 3
		and map._chart._systems.size() == map._known.size()
		and map._chart._positions.is_empty() and map._chart._points.size() <= 3,
		"A large catalogue opens on density while retaining every known ID without eagerly projecting every star")
	var last: int = discoveries.back()
	map._select_system(last)
	_expect(map._candidate == last and map._system_buttons.has(last)
		and map._chart._points.has(last) and map._known.size() == discoveries.size() + 3,
		"The full paginated catalogue still selects a distant discovery and projects its actual navigation anchor")
	var chart: GalaxyChart = map._chart
	map._select_system(Catalog.GALAXY_CENTER_SYSTEM)
	chart.focus_atlas_core()
	var core_point := chart.marker_position(Catalog.GALAXY_CENTER_SYSTEM)
	_expect(chart.atlas_is_local() and chart._atlas_sector_rect.get_area() <= GalaxyChart.MAX_ATLAS_SECTORS
		and chart._points.size() <= chart._atlas_signals.size() + 3
		and chart.system_at(core_point) == Catalog.GALAXY_CENTER_SYSTEM,
		"A discovered core star remains selectable through the bounded visible-sector cache")
	var prior_points := chart._points.duplicate()
	map.refresh()
	_expect(chart._positions.is_empty() and chart._points == prior_points
		and chart._known_systems.size() == discoveries.size() + 3 and chart.atlas_is_local(),
		"Refreshing the unchanged long survey retains its local view without rebuilding a full coordinate table")
	var hidden_route_node: int = discoveries[1000]
	var projected: Vector2 = chart.marker_position(hidden_route_node)
	_expect(projected.is_equal_approx(chart._project_to_view(GalaxyChart._project(hidden_route_node, false)))
		and chart._points.size() <= chart._atlas_signals.size() + 4,
		"An off-window route node is projected from its real coordinates instead of falling back to the atlas centre")
	map._toggle_scope()
	var expected: Array[int] = []
	for id: int in Catalog.sector_system_ids(Catalog.GALAXY_CENTER_SECTOR):
		if pilot.system_known(id):
			expected.append(id)
	expected.sort()
	_expect(not map._atlas and map._chart._systems == expected
		and map._chart._positions.size() == expected.size() and not expected.is_empty(),
		"The traditional local sector keeps every discovered member with its ordinary coordinate projection")
	_expect(pilot.snapshot() == before, "Density browsing, picking and paging a large map cannot change the player's voyage")
	map.queue_free()
	await process_frame


func _test_map_ui() -> void:
	_canvas = SubViewport.new()
	_canvas.size = Vector2i(1544, 720)
	_canvas.own_world_3d = true
	root.add_child(_canvas)
	var game := Main.instantiate()
	_canvas.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._audio.set_level(0)
	await process_frame
	_tap(game._hud._actions["galaxy"])
	await process_frame
	var map: Node = game._galaxy
	var chart: Control = map._chart
	var pilot: Flight = game.flight
	_expect(map.is_open() and pilot.known_systems() == [0, 1, 2],
		"Opening the flight presents the three actually known systems")
	_tap(map._system_buttons[Catalog.VELAR_SYSTEM])
	_tap(map._plan_button)
	await process_frame
	var before := pilot.snapshot()
	_expect(pilot.planned_route().goal == Catalog.VELAR_SYSTEM, "Create a real planned route before changing views")
	_tap(map._atlas_button)
	await process_frame
	_expect(map._atlas and map._atlas_button.button_pressed
		and map._scope_label.text.replace(" ", "").contains(str(Catalog.GALAXY_SYSTEM_COUNT))
		and map._drag_button.disabled
		and chart._systems.size() == 3 and chart._points.size() == 3 and chart._atlas_signals.is_empty()
		and not map._system_buttons.has(Catalog.SYSTEM_COUNT - 1),
		"Atlas reveals whole-catalog density without revealing undiscovered destinations or expanding the known list")
	_tap(map._core_button)
	await process_frame
	_expect(chart.atlas_is_local() and chart.atlas_center_sector() == Catalog.GALAXY_CENTER_SECTOR
		and chart._atlas_sector_rect.get_area() <= GalaxyChart.MAX_ATLAS_SECTORS and not chart._atlas_signals.is_empty(),
		"Core control zooms the atlased survey to the real core and only loads a bounded sector window")
	_expect(chart._atlas_signals.has(Catalog.GALAXY_CENTER_SYSTEM) and not chart._points.has(Catalog.GALAXY_CENTER_SYSTEM)
		and chart.system_at(chart.size * 0.5) == -1 and pilot.snapshot() == before,
		"Unexplored core signals cannot be selected for a jump and navigation view does not change the live flight")
	_tap(map._atlas_button)
	await process_frame
	var first: Vector2 = chart.marker_position(Catalog.HOME_SYSTEM)
	var second: Vector2 = chart.marker_position(Catalog.VELAR_SYSTEM)
	_tap(map._zoom_in_button)
	await process_frame
	_expect(chart.marker_position(Catalog.HOME_SYSTEM).distance_to(chart.marker_position(Catalog.VELAR_SYSTEM))
		> first.distance_to(second) * 1.2 and not map._zoom_out_button.disabled,
		"Visible touch control zooms real catalogue coordinates instead of changing their underlying values")
	var home: Vector2 = chart.marker_position(Catalog.HOME_SYSTEM)
	var start := chart.get_global_transform_with_canvas() * (chart.size * 0.5)
	var moved := start + Vector2(64, -22)
	_send(start, true, 44)
	_drag(start, moved, 44)
	_send(moved, false, 44)
	var displaced: Vector2 = chart.marker_position(Catalog.HOME_SYSTEM)
	_expect(displaced.distance_to(home) > 15.0 and map._candidate == Catalog.VELAR_SYSTEM,
		"Dragging the chart pans its coordinates without changing the selected route")
	var pivot: Vector3 = chart._view_basis().transposed() * Vector3(chart._view_offset.x, chart._view_offset.y, chart._view_depth)
	_tap(map._drag_button)
	var rotate_end := start + Vector2(72, -54)
	_send(start, true, 46)
	_drag(start, rotate_end, 46)
	_send(rotate_end, false, 46)
	_expect(map._drag_button.button_pressed and map._candidate == Catalog.VELAR_SYSTEM
		and absf(chart._orbit_angles.x) > 0.5 and absf(chart._orbit_angles.y) > 0.4
		and pivot.is_equal_approx(chart._view_basis().transposed() * Vector3(chart._view_offset.x, chart._view_offset.y, chart._view_depth)),
		"Touch rotates two axes around the current center and releases without selecting a star")
	_tap(map._drag_button)
	_expect(not map._drag_button.button_pressed and not chart._orbit_angles.is_zero_approx(),
		"Switching back to pan preserves the current spatial projection")
	_tap(map._zoom_out_button)
	var point: Vector2 = chart.get_global_transform_with_canvas() * chart.marker_position(Catalog.HOME_SYSTEM)
	_send(point, true, 45)
	_send(point, false, 45, true)
	_expect(map._candidate == Catalog.VELAR_SYSTEM and map._chart_pointer == -1,
		"A canceled chart touch neither chooses another system nor latches drag")
	_send(point, true, 47)
	_send(point, false, 47)
	_expect(map._candidate == Catalog.HOME_SYSTEM and not chart._orbit_angles.is_zero_approx(),
		"A tap on a transformed marker selects its own system and preserves rotation during refresh")
	_tap(map._projection_button)
	_expect(map._elevation and chart._systems.size() == 3 and chart._orbit_angles.is_zero_approx(),
		"Fixed side projection restores its standard orientation and keeps the original known systems")
	_tap(map._ship_button)
	await process_frame
	_expect(not map._atlas and map._sector_focus == Catalog.HOME_SYSTEM
		and map._candidate == Catalog.HOME_SYSTEM and chart._detailed,
		"Return to ship opens and recenters the ship's local sector")
	_tap(map._drag_button)
	var sector_start: Vector2 = chart.get_global_transform_with_canvas() * (chart.size * 0.5)
	var sector_end := sector_start + Vector2(64, 54)
	var mouse_motion := InputEventMouseMotion.new()
	_mouse(sector_start, true)
	mouse_motion.position = sector_end
	mouse_motion.relative = sector_end - sector_start
	mouse_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_canvas.push_input(mouse_motion, true)
	_mouse(sector_end, false)
	_expect(map._chart_pointer == -1 and not chart._orbit_angles.is_zero_approx(),
		"Left mouse drag rotates the sector from the fixed side projection")
	_tap(map._directory_button)
	await process_frame
	_expect(map._directory and map._listed_systems() == [Catalog.HOME_SYSTEM, Catalog.VELAR_SYSTEM, Catalog.FRINGE_SYSTEM],
		"The directory shows the three known named systems without disclosing unopened core dossiers")
	_tap(map._system_buttons[Catalog.VELAR_SYSTEM])
	_tap(map._dossier_button)
	await process_frame
	_tap(map._dossier_tabs[2])
	await process_frame
	_expect(map._dossier_archive_title.text == "Орбита и поверхность Лазури"
		and map._dossier_archive_text.text.count("\n\n") == 1 and map._dossier_pages[2].is_visible_in_tree(),
		"Open the authored archive of another known system using the actual touch controls")
	_expect(pilot.snapshot() == before, "Exploring each map view leaves the flight, fuel, discoveries and planned route intact")
	_tap(map._dossier_button)
	_tap(map._directory_button)
	_tap(map._scope_button)
	_tap(map._projection_button)
	_tap(map._scan_button)
	await process_frame
	var streamed: Array[int] = pilot.known_systems().filter(func(id: int) -> bool:
		return Catalog.is_extended_system(id) and pilot.route_preview(id).available)
	if _expect(not streamed.is_empty(), "Radio scan makes a streamed system available through the flight map"):
		var target := streamed[0]
		var marker: Vector2 = chart.get_global_transform_with_canvas() * chart.marker_position(target)
		_send(marker, true, 48)
		_send(marker, false, 48)
		_expect(map._candidate == target and map._destination.text == Catalog.system(target).name,
			"An opened streamed system is selectable by touching its own marker")
		_tap(map._plan_button)
		_expect(pilot.planned_route().goal == target,
			"The standard route action saves the streamed destination")
	_canvas.queue_free()
	await process_frame


func _tap(button: Button) -> void:
	if not _expect(button != null and button.is_visible_in_tree() and not button.disabled, "Actual map button is usable by touch"):
		return
	var point := button.get_global_rect().get_center()
	_send(point, true, 10)
	_send(point, false, 10)


func _send(point: Vector2, pressed: bool, index: int, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	_canvas.push_input(event, true)


func _drag(origin: Vector2, end: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = end
	event.relative = end - origin
	_canvas.push_input(event, true)


func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	_canvas.push_input(event, true)


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures += 1
		printerr(description)
	return value
