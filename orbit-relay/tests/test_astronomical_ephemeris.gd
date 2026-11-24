extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Solar := preload("res://scripts/solar_system.gd")

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_test_elements()
	_test_kepler()
	_test_catalog()
	print("Astronomical ephemeris: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(int(not _failures.is_empty()))


func _circle() -> Dictionary:
	return {"semimajor": 2000.0, "eccentricity": 0.0, "inclination": 0.0,
		"ascending_node": 0.0, "argument_of_periapsis": 0.0, "mean_anomaly": 0.0, "period": 86400.0}


func _test_elements() -> void:
	var elements := _circle()
	for fraction: float in [0.0, 0.25, 0.5, 0.75, 1.0, -0.25]:
		var state := Orbit.sample_elements(elements, fraction * 86400.0)
		var phase := TAU * fraction
		_expect(state.position.distance_to(Vector3(cos(phase), 0.0, -sin(phase)) * 2000.0) < 0.001,
			"Circular J2000 motion has the correct quadrant and real second period at %.2f" % fraction)
		_expect(state.velocity.distance_to(Vector3(-sin(phase), 0.0, -cos(phase)) * (2000.0 * TAU / 86400.0)) < 0.000001,
			"Circular analytic velocity has the correct direction and magnitude")
	elements.inclination = 90.0
	_expect(Orbit.sample_elements(elements, 21600.0).position.distance_to(Vector3.UP * 2000.0) < 0.001,
		"An inclination of 90 degrees reaches ecliptic north at the quarter period")
	elements = _circle()
	elements.ascending_node = 90.0
	_expect(Orbit.sample_elements(elements).position.distance_to(Vector3.FORWARD * 2000.0) < 0.001,
		"Longitude of ascending node rotates the initial ray around the ecliptic pole")
	elements = _circle()
	elements.argument_of_periapsis = 90.0
	elements.eccentricity = 0.4
	_expect(Orbit.sample_elements(elements).position.distance_to(Vector3.FORWARD * 1200.0) < 0.001,
		"Argument of periapsis locates the independently specified ellipse")
	for eccentricity: float in [0.0, 0.20563593, 0.7507, 0.96714, 0.999999999999999]:
		elements = _circle()
		elements.eccentricity = eccentricity
		for time: float in [0.0, -1234567.0, 1.0e100, NAN, INF, -INF]:
			var state := Orbit.sample_elements(elements, time)
			_expect(not state.is_empty() and state.position.is_finite() and state.velocity.is_finite(),
				"Finite bound state for e=%s and time=%s" % [eccentricity, time])
			if not is_finite(time):
				_expect(state == Orbit.sample_elements(elements, 0.0), "A nonfinite clock uses the declared epoch")
	for key: String in _circle():
		var invalid := _circle()
		invalid.erase(key)
		_expect(Orbit.sample_elements(invalid).is_empty(), "An incomplete element set is unavailable: %s" % key)
	for change: Dictionary in [{"eccentricity": -0.1}, {"eccentricity": 1.0}, {"eccentricity": INF},
		{"period": 0.0}, {"period": -1.0}, {"period": NAN}, {"semimajor": -1.0}, {"semimajor": 1.0e300},
		{"mean_anomaly": "0"}, {"inclination": NAN}]:
		var invalid := _circle()
		invalid.merge(change, true)
		_expect(Orbit.sample_elements(invalid).is_empty(), "Invalid elements fail without fabricating a circular orbit: %s" % change)


func _test_kepler() -> void:
	# Independent 180-decimal mpmath bisection fixtures, using the exact binary64
	# input values (not rounded decimal eccentricities) in the reference solve.
	var references := [
		[0.96714, 0.001, "0.03029574229411389044113835954"],
		[0.7507, 0.1, "0.3748699206866462384461294379"],
		[0.999999999, 1.0e-12, "0.0001707199067162513220202628616"],
		[0.999999999999999, 1.0e-20, "3.863824109285968516403950899e-7"],
		[0.999999999999999, 1.0e-100, "1.000799917193443575563447223e-85"],
	]
	for row: Array in references:
		for sign_value: float in [-1.0, 1.0]:
			var result := Orbit.solve_eccentric_anomaly(float(row[1]) * sign_value, float(row[0]))
			var expected := float(row[2]) * sign_value
			_expect(absf((result - expected) / expected) < 1.0e-11,
				"Kepler reference e=%s M=%s: got %s expected %s relative_error=%s" % [row[0], row[1], String.num_scientific(result), String.num_scientific(expected), String.num_scientific(absf((result - expected) / expected))])
	_expect(is_nan(Orbit.solve_eccentric_anomaly(NAN, 0.5)) and is_nan(Orbit.solve_eccentric_anomaly(0.0, 1.0)),
		"Invalid or nonelliptic Kepler equations are unavailable")


func _test_catalog() -> void:
	var sol := Catalog.SOLAR_SYSTEM
	var sites := Catalog.targets_for(sol)
	_expect(sites.size() == Solar.SITE_COUNT, "Every declared Solar body is reachable through the public catalogue")
	var moon_count := 0
	for id: int in sites:
		var site := Catalog.site(id)
		if not site.has("astronomical_orbit"):
			_expect(Orbit.sample(id, 1.0e100).position == Vector3.ZERO, "The Sun stays at the inertial origin")
			continue
		var elements: Dictionary = site.astronomical_orbit
		var actual_period := float(site.astronomy.period_days) * 86400.0
		_expect(absf(Orbit.period(id) - actual_period) < actual_period * 1.0e-12,
			"The catalogue period is actual elapsed SI seconds for %s" % site.name)
		var parent := Orbit.orbit_parent(id)
		if parent >= 0:
			moon_count += 1
		_expect(parent == int(site.get("orbit_parent", -1)), "The supplied orbit parent is retained for %s" % site.name)
		for epoch: float in [0.0, 1234567.0, 1.0e8, -1.0e8, 1.0e100, NAN]:
			var state := Orbit.sample(id, epoch)
			var relative := Orbit.sample_elements(elements, epoch)
			var parent_state := Orbit.sample(parent, epoch) if parent >= 0 else {"position": Vector3.ZERO, "velocity": Vector3.ZERO}
			_expect(state.position.is_finite() and state.velocity.is_finite()
				and state.position == relative.position + parent_state.position
				and state.velocity == relative.velocity + parent_state.velocity,
				"Parent position and velocity compose at the same finite epoch for %s (%s)" % [site.name, epoch])
		var extrema := Orbit.extrema(id)
		var path := Orbit.orbit_points(id, 1234567.0)
		_expect(path.size() == Orbit.ORBIT_SEGMENTS + 1 and path[0] == path[-1]
			and extrema.x > 0.0 and extrema.y >= extrema.x,
			"The local map receives a closed ellipse and positive radial extrema for %s" % site.name)
		var bounds_center: Vector3 = Orbit.sample(parent, 1234567.0).position if parent >= 0 else Vector3.ZERO
		for point: Vector3 in path:
			if not point.is_finite() or point.distance_to(bounds_center) > extrema.y + 0.1:
				_expect(false, "A map vertex escapes the finite parent-relative ellipse for %s" % site.name)
				break
	_expect(moon_count >= 20, "The astronomical hierarchy includes the supplied satellite families")
	var earth: Vector3 = Orbit.sample(Catalog.SOLAR_EARTH, 0.0).position / Solar.AU_IN_SCENE
	_expect(absf(earth.x - -0.177171) < 0.0001 and absf(earth.z - -0.967214) < 0.0001 and absf(earth.y) < 0.00001,
		"Earth's J2000 mean-element position agrees with the external ecliptic reference quadrant and radius")
	for id in range(Catalog.PRE_BINARY_DESTINATION_COUNT):
		_expect(Orbit.sample(id, 0.0).position == Catalog.site(id).center,
			"The legacy catalogue epoch remains exact for site %d" % id)


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
