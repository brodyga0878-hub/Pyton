extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Economy := preload("res://scripts/port_economy.gd")
const Expedition := preload("res://scripts/expedition.gd")
const Factions := preload("res://scripts/faction_fronts.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const GalaxyMap := preload("res://scripts/galaxy_map.gd")
const Dossier := preload("res://scripts/system_dossier.gd")
const HOME := Catalog.HOME_SYSTEM
const VELAR := Catalog.VELAR_SYSTEM
const FRINGE := Catalog.FRINGE_SYSTEM
const HEATHER := Catalog.HEATHER_SYSTEM
const BINARY := Catalog.BINARY_SYSTEM

var _viewport: SubViewport
var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var flight := Flight.new()
	var hidden := Dossier.read(flight, BINARY)
	_expect(not hidden.known and not hidden.has("stars") and not hidden.has("population")
		and not hidden.has("authority") and hidden.goods.is_empty(), "The hidden system exposes neither its components nor its political profile")
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	root.add_child(_viewport)
	var map := GalaxyMap.new()
	_viewport.add_child(map)
	map.open(flight)
	await process_frame
	await _test_known_systems(flight, map)
	await _test_frontier_trade(flight, map)
	_viewport.queue_free()
	await process_frame
	print("System dossier integration: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))


func _test_known_systems(flight: Flight, map: GalaxyMap) -> void:
	_tap(map._dossier_button, "Open the dossier with touch")
	await process_frame
	_expect(map._dossier_stars.is_visible_in_tree() and "Одиночная звезда" in map._dossier_stars.text
		and "G V" in map._dossier_stars.text and "орбитальные поселения" in map._dossier_population.text,
		"Helion lists its actual single star, authored spectral class and settlement profile")
	map._select_system(BINARY)
	_expect(map._candidate == HOME, "Trying to select a hidden system keeps the previous dossier")
	flight.credits = 1000
	_expect(flight.market_trade("medical", "buy", 5), "Load actual regulated medical cargo at Helion")
	_tap(map._system_buttons.get(VELAR), "Select the remote Velar system by touch")
	await process_frame
	_expect(map._candidate == VELAR and "A V" in map._dossier_stars.text
		and "Лазури" in map._dossier_population.text and "Веларская лига" in map._dossier_population.text,
		"Velar gives its own stellar and settlement data and current political authority while the player is away")
	_tap(map._dossier_tabs[GalaxyMap.DossierPage.TRADE], "Open the separate trade page with touch")
	await process_frame
	var velar := flight.system_dossier(VELAR)
	_expect(map._dossier_stock.is_visible_in_tree() and not map._dossier_stars.is_visible_in_tree()
		and "Медикаменты %d" % int(velar.goods.medical) in map._dossier_stock.text
		and map._dossier_customs_rule.is_visible_in_tree() and "До 4 ед." in map._dossier_customs_rule.text
		and "изымут 1 ед." in map._dossier_customs_rule.text and flight.system_id == HOME,
		"The remote trade page displays current stock, the live limit and the player's actual excess cargo")
	_expect(flight.scan_galaxy() and flight.system_known(BINARY), "Discover the binary system through the standard scanner")
	map.refresh()
	map._select_system(BINARY)
	_tap(map._dossier_tabs[GalaxyMap.DossierPage.OVERVIEW], "Switch back to overview with touch")
	await process_frame
	var binary := Dossier.read(flight, BINARY)
	_expect(map._dossier_stars.is_visible_in_tree() and "Двойная звезда" in map._dossier_stars.text
		and binary.stars.size() == Catalog.stars_for(BINARY).size()
		and "Элиора A · G V" in map._dossier_stars.text and "Элиора B · K V" in map._dossier_stars.text
		and "не зарегистрированы" in map._dossier_population.text,
		"Discovering Eliora reveals both actual components and an unoccupied profile")
	var spectra := {}
	for system in flight.known_systems():
		if Catalog.is_generated_system(system) and system != BINARY:
			var first: Dictionary = Dossier.read(flight, system).stars[0]
			spectra[first.spectral_class] = true
			_expect(not str(first.spectral_class).is_empty() and Dossier.read(flight, system).stars[0] == first,
				"A discovered procedural system has a stable catalog class")
	_expect(spectra.size() > 1, "The generator's discovered systems exhibit distinct recorded spectral classes")


func _test_frontier_trade(flight: Flight, map: GalaxyMap) -> void:
	if not _expect(flight.project_action(), "Accept the real prospecting contract to reveal Heather"):
		return
	map._select_system(HEATHER)
	_tap(map._dossier_tabs[GalaxyMap.DossierPage.TRADE], "Open the frontier trade page by touch")
	await process_frame
	_expect(map._dossier_stock.is_visible_in_tree() and "рынков нет" in map._dossier_stock.text
		and not map._dossier_customs_rule.is_visible_in_tree(), "A known unfinished system has no operative market or customs")
	var projects := flight.expedition.snapshot()
	projects.projects[0].phase = Expedition.COMPLETE
	projects.projects[0].scan_index = Expedition.SURVEY_TOTAL
	projects.projects[0].build_index = Expedition.BUILD_TOTAL
	if not _expect(flight.expedition.restore(projects) and flight.factions.commission(HEATHER, 0, flight.orbit_time)
		and flight.freight.activate_frontier(HEATHER, flight.orbit_time), "Seed the legitimate commissioned market and its freight schedule"):
		return
	var pre_stock := flight.market.stock(Catalog.HEATHER_PORT, "medical")
	flight.update(29.0, Vector2.ZERO, 0.0, false, false)
	map.refresh()
	var imports: Array = flight.system_dossier(HEATHER).imports
	if not _expect(imports.size() == 1 and imports[0].good == "medical", "The real scheduled frontier freighter loaded its medical shipment"):
		return
	var amount := int(imports[0].amount)
	var shipment := "%s · %d ед." % [Economy.good_name("medical"), amount]
	_expect(shipment in map._dossier_imports.text and "Свод" in map._dossier_imports.text
		and shipment not in map._dossier_exports.text and "Медикаменты %d" % pre_stock in map._dossier_stock.text,
		"The destination lists an incoming shipment from its real origin and leaves stock unchanged in transit")
	map._select_system(FRINGE)
	_expect(shipment in map._dossier_exports.text and "Форпост Вереска" in map._dossier_exports.text
		and shipment not in map._dossier_imports.text, "The origin lists the same cargo separately as exports to the real destination")
	flight.update(50.0, Vector2.ZERO, 0.0, false, false)
	map._select_system(HEATHER)
	_expect(shipment not in map._dossier_imports.text and "Медикаменты %d" % (pre_stock + amount) in map._dossier_stock.text,
		"Arrival removes the in-transit row and updates the market total")
	_tap(map._dossier_tabs[GalaxyMap.DossierPage.OVERVIEW], "Inspect the commissioned outpost overview")
	await process_frame
	_expect("орбитальный форпост" in map._dossier_population.text and "Администрация форпоста" in map._dossier_population.text,
		"The new settlement profile describes the actual commissioned outpost")
	flight.update(Factions.FOUNDING_GRACE - flight.orbit_time + 1.0, Vector2.ZERO, 0.0, false, false)
	map.refresh()
	_expect("Контроль удерживает Содружество Маяков" in map._dossier_population.text
		and "Оспаривает Веларская лига" in map._dossier_population.text,
		"The live war changes political status and names both the incumbent and challenger")


func _tap(button: Button, description: String) -> void:
	if not _expect(button != null and button.is_visible_in_tree() and not button.disabled, description):
		return
	var point := button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 10
		touch.position = point
		touch.pressed = pressed
		_viewport.push_input(touch, true)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		printerr(description)
		_failures += 1
	return condition
