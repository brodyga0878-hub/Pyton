extends SceneTree

const OrbitRelay := preload("res://main.tscn")
const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const MATERIAL_DIR := "res://assets/materials/"
const MAPS := ["rock_basalt", "rock_ice", "metal_brushed", "metal_paint", "cloud_bands"]
const MAP_SIZE := Vector2i(512, 512)

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_imported_maps()
	await _test_live_materials()
	print("Material maps integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_imported_maps() -> void:
	for name: String in MAPS:
		var path := MATERIAL_DIR + name + ".png"
		var source := Image.new()
		var decoded := source.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		if not _expect(texture != null and decoded == OK and source.get_size() == MAP_SIZE
			and texture.get_size() == Vector2(MAP_SIZE) and source.get_format() == Image.FORMAT_RGB8,
			"%s loads as a 512-pixel packed RGB resource from a clean import" % name):
			continue
		var imported := texture.get_image()
		if not _expect(imported != null and imported.has_mipmaps() and imported.get_mipmap_count() == 9,
			"%s has a complete runtime mip chain down to one texel" % name):
			continue
		var lowest := Vector3.ONE
		var highest := Vector3.ZERO
		var separate := 0
		var matches := true
		for y in range(0, MAP_SIZE.y, 13):
			for x in range(0, MAP_SIZE.x, 13):
				var color := source.get_pixel(x, y)
				var channels := Vector3(color.r, color.g, color.b)
				lowest = lowest.min(channels)
				highest = highest.max(channels)
				if channels.x != channels.y and channels.y != channels.z:
					separate += 1
				matches = matches and color.is_equal_approx(imported.get_pixel(x, y))
		_expect(matches, "%s preserves the packed RGB data in the actual imported texture" % name)
		var span := highest - lowest
		_expect(span.x > 0.05 and span.y > 0.05 and span.z > 0.035 and separate > 100,
			"%s carries separately varying tone, relief and surface detail channels" % name)


func _test_live_materials() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	game.flight.credits = 151
	game.flight.ship.hull = 84.0
	game._update_display(0.0)
	await process_frame
	var view: Node = game._view
	var rock: Node3D = view._surface_views[2]
	var moon: Node3D = view._surface_views[6]
	var comet: Node3D = view._surface_views[8]
	var rock_paint: ShaderMaterial = rock._surface_paint
	var moon_paint: ShaderMaterial = moon._surface_paint
	var comet_paint: ShaderMaterial = comet._surface_paint
	var terrain_mesh := rock.get_child(0) as MeshInstance3D
	var baseline_mesh := terrain_mesh.mesh
	var saved_contact: Vector3 = game.flight.target_contact(2)
	var flight_before: Dictionary = game.flight.snapshot()
	_expect(_asset(rock_paint, "surface_detail") == "rock_basalt"
		and _asset(moon_paint, "surface_detail") == "rock_ice" and _asset(comet_paint, "surface_detail") == "rock_ice",
		"Live rock, ice and comet geometry binds the corresponding surface detail data")
	_expect(rock_paint.get_shader_parameter("detail_offset") != view._surface_views[4]._surface_paint.get_shader_parameter("detail_offset"),
		"Two faces sharing the same rock map retain individual deterministic offsets")
	var gas: ShaderMaterial = view._backdrop_material
	_expect(_asset(gas, "cloud_detail") == "cloud_bands", "The actual giant binds the cloud data atlas")
	var ship: Array[ShaderMaterial] = view._ship_finishes
	var stations: Array[ShaderMaterial] = view._sector_finishes
	var metal: Array[ShaderMaterial] = ship.duplicate()
	metal.append_array(stations)
	_expect(not ship.is_empty() and not stations.is_empty()
		and _metal_data_is_bound(ship) and _metal_data_is_bound(stations),
		"Actual ship and station finishes both bind painted and brushed packed materials")
	for quality in [0, 2, 1, 2]:
		game.presentation.change("quality", quality)
		game._apply_presentation()
		var finishes_correct := true
		for finish: ShaderMaterial in metal:
			finishes_correct = finishes_correct and finish.get_shader_parameter("finish_quality") == quality
		var surface_correct := true
		for paint: ShaderMaterial in [rock_paint, moon_paint, comet_paint]:
			surface_correct = surface_correct and paint.get_shader_parameter("profile") == quality
		_expect(view._visual_profile == quality and gas.get_shader_parameter("cloud_quality") == quality
			and finishes_correct and surface_correct,
			"The live quality preset %d reaches terrain, equipment and clouds together" % quality)
	_expect(terrain_mesh.mesh == baseline_mesh and game.flight.target_contact(2) == saved_contact
		and game.flight.snapshot() == flight_before,
		"Selecting packed-material detail does not alter the surface mesh, flight geometry or saved simulation")
	var weather: float = gas.get_shader_parameter("weather_phase")
	game._update_display(1.0)
	_expect(is_equal_approx(gas.get_shader_parameter("weather_phase"), weather),
		"Cloud motion is independent of renderer frame delta while simulation is paused")
	game._physics_process(45.0)
	game._update_display(0.0)
	var advanced: float = gas.get_shader_parameter("weather_phase")
	_expect(not is_equal_approx(advanced, weather) and advanced >= 0.0 and advanced < 1.0,
		"Cloud phase advances with the live simulated orbit clock")
	var flight := Flight.new()
	var to_velar := flight.snapshot()
	var dock := flight.docking_position(10)
	to_velar.merge({"system_id": Catalog.VELAR_SYSTEM, "docked": 10, "target": 10, "position": [dock.x, dock.y, dock.z]}, true)
	if _expect(flight.restore(to_velar), "Prepare a normal ship in a second system"):
		game.flight = flight
		game._update_display(0.0)
		var terrace: ShaderMaterial = view._surface_views[Catalog.TERRACE_ID]._surface_paint
		_expect(_asset(terrace, "surface_detail") == "rock_basalt"
			and terrace.get_shader_parameter("profile") == 2
			and view._backdrop_material != gas and view._backdrop_material.get_shader_parameter("cloud_quality") == 2
			and _metal_data_is_bound(view._sector_finishes),
			"Rebuilding the sector carries the chosen profile through new terrain, clouds and stations")
	viewport.queue_free()
	await process_frame


func _metal_data_is_bound(finishes: Array[ShaderMaterial]) -> bool:
	var brushed := false
	var paint := false
	for finish: ShaderMaterial in finishes:
		var data := _asset(finish, "panel_data")
		if data == "metal_brushed":
			brushed = true
		elif data == "metal_paint":
			paint = true
		else:
			return false
	return brushed and paint


func _asset(material: ShaderMaterial, parameter: String) -> String:
	var texture := material.get_shader_parameter(parameter) as Texture2D if material != null else null
	return texture.resource_path.get_file().get_basename() if texture != null else ""


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
