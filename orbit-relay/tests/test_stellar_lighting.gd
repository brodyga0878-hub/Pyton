extends SceneTree

const View := preload("res://scripts/flight_view.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view := View.new()
	root.add_child(view)
	view.build()
	var flight := Flight.new()
	view.sync(flight, 0.0)
	var far_energy := view._sunlight.light_energy
	_check(_directed_to_ship(view._sunlight, view._star.position, flight.position),
		"The starter station light travels away from the current main star toward the ship")
	flight.docked = -1
	flight.select_target(Catalog.STAR_ID)
	var home_star := flight.target_position(Catalog.STAR_ID)
	flight.position = home_star + Vector3(0.0, 320.0, 0.0)
	var near_flight := flight.snapshot()
	view.sync(flight, 0.0)
	_check(view._sunlight.light_energy > far_energy and _directed_to_ship(view._sunlight, home_star, flight.position),
		"Close to a single star the light follows its direction and becomes brighter")
	_check(view._sunlight.basis.is_finite() and flight.snapshot() == near_flight,
		"The overhead star uses a valid basis and scene synchronisation leaves flight state unchanged")
	flight.position = home_star + Vector3(0.0, -320.0, 0.0)
	view.sync(flight, 0.0)
	_check(_directed_to_ship(view._sunlight, home_star, flight.position) and (-view._sunlight.basis.z).y < -0.99,
		"Going past the star turns the light to the opposite side")

	flight.system_id = Catalog.VELAR_SYSTEM
	flight.target = Catalog.TERRACE_ID
	for epoch: float in [110.0, 232.0, 415.0]:
		flight.orbit_time = epoch
		flight.position = flight.target_gate(Catalog.TERRACE_ID)
		view.sync(flight, 0.0)
		var star := flight.target_position(Catalog.VELAR_STAR_ID)
		_check(view._star.position == star and _directed_to_ship(view._sunlight, star, flight.position),
			"At Terrace epoch %.0f the light follows the blue star, distinct from the terrestrial body" % epoch)
		var backdrop_sun := view._backdrop_planet.position.direction_to(star)
		_check(view._backdrop_material.get_shader_parameter("light_direction").is_equal_approx(backdrop_sun)
			and view._backdrop_halo_material.get_shader_parameter("light_direction").is_equal_approx(backdrop_sun)
			and view._backdrop_ring_material.get_shader_parameter("light_direction").is_equal_approx(backdrop_sun),
			"Planet, atmosphere and ring shadow follow the same star at epoch %.0f" % epoch)
	var terrace := flight.target_position(Catalog.TERRACE_ID)
	var terrace_sun := terrace.direction_to(flight.target_position(Catalog.VELAR_STAR_ID))
	var terrace_radius := float(Catalog.site(Catalog.TERRACE_ID).radius)
	flight.position = terrace + terrace_sun * (terrace_radius + 26.0)
	view.sync(flight, 0.0)
	var reflected_day := view._fill.light_energy
	var haze_day := view._lighting.fog_light_energy
	_check(reflected_day > 0.1 and _directed_to_ship(view._fill, terrace, flight.position)
		and view._lighting.fog_enabled,
		"The lit planet supplies local reflected light and the camera is still inside the air")
	flight.position = terrace - terrace_sun * (terrace_radius + 26.0)
	view.sync(flight, 0.0)
	_check(view._fill.light_energy < reflected_day * 0.20 and view._lighting.fog_enabled
		and view._lighting.fog_light_energy < haze_day * 0.5,
		"On the same planet's dark side both reflected light and atmospheric haze lose their daylight")

	flight.system_id = Catalog.BINARY_SYSTEM
	flight.target = Catalog.BINARY_MOON
	flight.position = flight.target_gate(flight.target)
	var primary := flight.target_position(Catalog.BINARY_PRIMARY)
	var companion := flight.target_position(Catalog.BINARY_SECONDARY)
	view.sync(flight, 0.0)
	_check(_directed_to_ship(view._sunlight, primary, flight.position)
		and _directed_to_ship(view._fill, companion, flight.position),
		"Both binary lights still point from their respective physical stars")
	_check(is_equal_approx(view._sunlight.light_energy, _energy(1.10, primary, flight.position))
		and is_equal_approx(view._fill.light_energy, _energy(0.65, companion, flight.position)),
		"The established primary and companion energy curves remain active in the binary system")
	view.queue_free()
	await process_frame
	print("Stellar lighting integration: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _directed_to_ship(light: DirectionalLight3D, star: Vector3, ship: Vector3) -> bool:
	return (-light.basis.z).dot(star.direction_to(ship)) > 0.99999


func _energy(strength: float, star: Vector3, ship: Vector3) -> float:
	return strength * lerpf(0.25, 1.0, 1.0 / (1.0 + star.distance_squared_to(ship) / 2250000.0))


func _check(condition: bool, explanation: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr(explanation)
