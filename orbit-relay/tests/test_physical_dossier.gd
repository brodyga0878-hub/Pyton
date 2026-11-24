extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Dossier := preload("res://scripts/system_dossier.gd")
const Survey := preload("res://scripts/cartography.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const LocalMap := preload("res://scripts/sector_map.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_metadata_boundary()
	await _test_catalog_and_ui()
	print("Physical astronomical dossier: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(int(not _failures.is_empty()))


func _test_metadata_boundary() -> void:
	var model := {"radius": 84.0, "mass_kg": 123.0, "gravity_parameter": 456.0, "gravity": 7.0,
		"temperature_k": 9999.0, "period": 42.0, "spin": 0.1, "spin_period": TAU / 0.1}
	var model_before := model.duplicate(true)
	var facts := {"radius_km": 6371.0, "mass_kg": 5.97237e24, "semimajor_km": 149597870.7,
		"period_days": 365.256363, "type": "planet", "epoch": "J2000.0", "rotation_period_days": -2.0,
		"scale_notice": "Explicit test scale", "ephemeris_notice": "Explicit test approximation"}
	var facts_before := facts.duplicate(true)
	var physical := Survey.physical_body_data(model, {"astronomy": facts, "astronomical_orbit": {"eccentricity": 0.01671123}})
	_expect(model == model_before and facts == facts_before, "Public physical overlay does not mutate model data or catalogue facts")
	_expect(physical.radius == 6371000.0 and physical.diameter == 12742000.0
		and physical.mass_kg == 5.97237e24 and absf(float(physical.gravity_parameter) - 3.9861389091e14) < 1.0e5,
		"Radius, diameter, mass and GM use explicit physical km-to-SI units")
	_expect(absf(float(physical.gravity) - 9.820581830) < 1.0e-6
		and physical.period == 365.256363 * 86400.0 and physical.semimajor == 149597870700.0,
		"Physical surface gravity and orbital units are independent of the scene scale")
	_expect(physical.spin < 0.0 and physical.spin_period == 172800.0,
		"An explicitly supplied retrograde rotation keeps its sign and real period")
	_expect(physical.temperature_k == 0.0 and not "temperature_k" in physical.physical_fields,
		"An unavailable catalogue temperature is not filled with gameplay equilibrium temperature")
	_expect(physical.physical_catalog and physical.astronomy_epoch == "J2000.0"
		and physical.scale_notice == "Explicit test scale" and physical.ephemeris_notice == "Explicit test approximation",
		"Physical provenance and approximation labels accompany the numbers")
	_expect(Survey.physical_body_data(model, {}) == model, "A legacy site without metadata retains its exact model dossier")
	var invalid := Dossier.physical_metadata({"radius_km": NAN, "mass_kg": INF, "period_days": -1,
		"temperature_k": "5772", "type": 7, "epoch": 2000, "rotation_period_days": -0.5})
	_expect(invalid == {"rotation_period_days": -0.5}, "Invalid public quantities are omitted rather than displayed as physical facts")


func _test_catalog_and_ui() -> void:
	var pilot := Flight.new()
	pilot.start_solar_voyage()
	var before := pilot.cartography.snapshot()
	var credits := pilot.credits
	var earth := pilot.body_dossier(Catalog.SOLAR_EARTH)
	_expect(earth.catalog_known and not earth.known and earth.recorded_at == -1.0
		and earth.data.radius == 6371000.0 and earth.data.physical_catalog,
		"Earth's public physical dossier is available before any personal scan")
	_expect(pilot.cartography.snapshot() == before and pilot.credits == credits,
		"Reading public astronomical data awards no observation, scan record or credits")
	var system := Dossier.read(pilot, Catalog.SOLAR_SYSTEM)
	var sun := Catalog.star_for(Catalog.SOLAR_SYSTEM)
	_expect(system.stars.size() == 1 and system.stars[0].spectral_class == "G2 V"
		and Dossier.stellar_temperature(sun) == 5772.0 and not system.archive.is_empty(),
		"The public Solar dossier identifies a G2 V star with its supplied 5772 K temperature and source archive")
	var moon := Catalog.STREAMED_SITE_LIMIT + 4
	var moon_data: Dictionary = pilot.body_dossier(moon).data
	_expect(moon_data.orbit_reference == "Земля" and moon_data.semimajor == 384400000.0
		and moon_data.period == 27.321661 * 86400.0 and "схематичны" in moon_data.ephemeris_notice,
		"The lunar dossier distinguishes its real parent, physical distance and period from illustrative orbital orientation")
	var nereid := Catalog.STREAMED_SITE_LIMIT + 29
	var nereid_data: Dictionary = pilot.body_dossier(nereid).data
	_expect(not "mass_kg" in nereid_data.physical_fields and "radius" in nereid_data.physical_fields,
		"An unsupplied satellite mass remains a model quantity and is never labelled measured")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1544, 720)
	root.add_child(viewport)
	var map := LocalMap.new()
	viewport.add_child(map)
	map.open(pilot)
	map._set_panel("survey")
	await process_frame
	_expect("Каталожные данные" in map._survey_state.text
		and map._survey_values.radius.text == "6371,0 км"
		and map._survey_values.period.text == "365,256 сут"
		and map._survey_captions.radius.text == "Справочный радиус"
		and map._survey_captions.mass_kg.text == "Масса",
		"The actual local map displays physical Earth values and explicit public-data labels")
	_expect("2000 единиц" in map._survey_scale.text and "модели" in map._survey_captions.spin_period.text
		and not map._survey_values.temperature_k.get_parent().visible,
		"The displayed scale and unsupplied rotation/temperature are clearly distinguished from physical measurements")
	map._select_site(moon)
	_expect("схематичны" in map._survey_scale.text and map._survey_values.orbit_reference.text == "Земля"
		and map._survey_values.semimajor.text == "384400,0 км",
		"Selecting the actual Moon displays its orientation limitation and physical orbital radius")
	map._select_site(sun)
	_expect(map._survey_values.temperature_k.text == "5772 К · справочное значение"
		and map._survey_captions.temperature_k.text == "Температура из каталога",
		"Selecting the actual Sun displays the supplied photospheric temperature")
	map._select_site(nereid)
	_expect(map._survey_captions.mass_kg.text == "Гравитационная масса модели",
		"A radius-only physical card keeps an unsupplied mass explicitly labelled as a model value")
	var eris := Catalog.STREAMED_SITE_LIMIT + 37
	map._select_site(eris)
	for side: bool in [false, true]:
		map._chart.side_view = side
		var bounds: Rect2 = map._chart._bounds()
		var plot: Rect2 = map._chart._plot_bounds()
		_expect(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.x > 0.0 and bounds.size.y > 0.0,
			"Solar map bounds remain finite in the top/side projection")
		for position: Vector3 in map._chart.centers.values():
			var projected: Vector2 = map._chart._project(position, plot, bounds)
			_expect(projected.is_finite() and plot.grow(0.1).has_point(projected), "All forty Solar centres fit the chart")
		for position: Vector3 in Orbit.orbit_points(eris, pilot.orbit_time):
			var projected: Vector2 = map._chart._project(position, plot, bounds)
			if not projected.is_finite() or not plot.grow(0.1).has_point(projected):
				_expect(false, "The selected distant ellipse is clipped from the top/side Solar map")
				break
	var legacy := Flight.new()
	legacy.cartography.record(Catalog.STAR_ID, 0.0)
	map._show_survey_values(legacy.body_dossier(Catalog.STAR_ID).data)
	_expect(map._survey_captions.radius.text == "Радиус модели"
		and map._survey_captions.mass_kg.text == "Гравитационная масса модели"
		and map._survey_scale.text == "Размеры, время и гравитация в масштабе модели."
		and not map._survey_values.astronomy_epoch.get_parent().visible,
		"Returning to a legacy dossier clears all physical labels and optional astronomical rows")
	viewport.queue_free()
	await process_frame


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
