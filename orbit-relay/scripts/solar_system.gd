extends RefCounted
## Public astronomical facts, expressed separately from the playable scene scale.
## No FFE assets, catalogue entries or proprietary world-generation data are used.
##
## Sources for the rounded physical values and mean elements below:
## NASA planetary fact sheets: https://nssdc.gsfc.nasa.gov/planetary/factsheet/
## JPL planetary J2000 mean elements: https://ssd.jpl.nasa.gov/planets/approx_pos.html
## JPL satellite elements: https://ssd.jpl.nasa.gov/sats/elem/
## JPL satellite physical parameters: https://ssd.jpl.nasa.gov/sats/phys_par/
## JPL small-body database: https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html
## NASA Halley overview: https://science.nasa.gov/solar-system/comets/1p-halley/
## IAU dwarf-planet classification: https://www.iau.org/public/themes/pluto/
## IAU nominal solar radius: https://www.iau.org/static/resolutions/IAU2015_English.pdf
##
## This is an approximate two-body catalogue, not a live Horizons/DE ephemeris.
## The nine JPL rows (eight planets and Pluto) use J2000 mean elements. Satellite,
## other dwarf-planet and Halley orientations/phases are explicitly illustrative.
## Their real dimensions, mean orbital distances and periods remain metadata.
## Moon orbits and all visible body radii are enlarged independently for play.

const SITE_COUNT := 40
const EARTH_INDEX := 3
const AU_IN_SCENE := 2000.0
const AU_KM := 149597870.7
const DAY_SECONDS := 86400.0
const EPOCH := "J2000.0 · JD2451545.0"
const FACT_SOURCES := [
	"https://nssdc.gsfc.nasa.gov/planetary/factsheet/",
	"https://ssd.jpl.nasa.gov/planets/approx_pos.html",
	"https://ssd.jpl.nasa.gov/sats/elem/",
	"https://ssd.jpl.nasa.gov/sats/phys_par/",
	"https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html",
]
const SCALE_NOTICE := "Расстояния между планетами: 1 а.е. = 2000 единиц сцены. Радиусы тел и орбиты спутников увеличены для видимости; физические величины приведены отдельно."
const APPROXIMATE_ORIENTATION := "Ориентация и начальная фаза этой орбиты схематичны; точное положение на календарную дату не заявляется."

# JPL rows: [a AU, e, i deg, mean longitude deg, longitude of perihelion deg,
# longitude of ascending node deg, sidereal period days]. The angles are J2000.
# Moon rows instead store a/period about their actual parent; scene_a is the
# deliberately enlarged display orbit, not a measured astronomical distance.
const BODIES := [
	{"name": "Солнце", "key": "sun", "kind": "star", "radius": 220.0,
		"radius_km": 695700.0, "mass_kg": 1.9885e30, "color": Color("#fff0c7"), "type": "Жёлтый карлик G2 V"},
	{"name": "Меркурий", "key": "mercury", "kind": "planet", "radius": 44.0,
		"radius_km": 2439.7, "mass_kg": 3.3011e23, "color": Color("#91867c"), "type": "Планета земной группы",
		"jpl": [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593, 87.9691]},
	{"name": "Венера", "key": "venus", "kind": "planet", "radius": 76.0,
		"radius_km": 6051.8, "mass_kg": 4.8675e24, "color": Color("#cda97b"), "type": "Планета земной группы",
		"jpl": [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255, 224.701],
		"atmosphere": {"height": 30.0, "density": 2.3, "color": Color("#deb57b")}},
	{"name": "Земля", "key": "earth", "kind": "planet", "radius": 84.0,
		"radius_km": 6371.0, "mass_kg": 5.97237e24, "color": Color("#3f79a5"), "type": "Планета земной группы",
		"element_note": "Использованы средние элементы барицентра Земля–Луна; покачивание Земли вокруг него отдельно не вычисляется.",
		"jpl": [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0, 365.256363],
		"atmosphere": {"height": 24.0, "density": 1.0, "color": Color("#80bbf5")}},
	{"name": "Луна", "key": "moon", "kind": "moon", "parent": 3, "radius": 27.0,
		"radius_km": 1737.4, "mass_kg": 7.342e22, "color": Color("#a6a4a0"),
		"a_km": 384400.0, "period_days": 27.321661, "e": 0.0549, "scene_a": 260.0, "phase": 135.0},
	{"name": "Марс", "key": "mars", "kind": "planet", "radius": 62.0,
		"radius_km": 3389.5, "mass_kg": 6.4171e23, "color": Color("#aa5a3b"), "type": "Планета земной группы",
		"jpl": [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891, 686.980],
		"atmosphere": {"height": 12.0, "density": 0.12, "color": Color("#d19371")}},
	{"name": "Фобос", "key": "phobos", "kind": "moon", "parent": 5, "radius": 12.0,
		"radius_km": 11.08, "mass_kg": 1.0659e16, "color": Color("#75675c"),
		"a_km": 9376.0, "period_days": 0.31891023, "e": 0.0151, "scene_a": 145.0, "phase": 28.0},
	{"name": "Деймос", "key": "deimos", "kind": "moon", "parent": 5, "radius": 10.0,
		"radius_km": 6.2, "mass_kg": 1.4762e15, "color": Color("#8b7c6b"),
		"a_km": 23463.2, "period_days": 1.26244, "e": 0.00033, "scene_a": 250.0, "phase": 202.0},
	{"name": "Юпитер", "key": "jupiter", "kind": "gas", "radius": 210.0,
		"radius_km": 69911.0, "mass_kg": 1.8982e27, "color": Color("#c9a786"), "type": "Газовый гигант",
		"gas_palette_low": Color("#8c6758"), "gas_palette_high": Color("#e0cab0"),
		"jpl": [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909, 4332.589],
		"atmosphere": {"height": 45.0, "density": 1.8, "color": Color("#d9b48e")}},
	{"name": "Ио", "key": "io", "kind": "moon", "parent": 8, "radius": 25.0,
		"radius_km": 1821.6, "mass_kg": 8.93194e22, "color": Color("#c8b266"),
		"a_km": 421800.0, "period_days": 1.769137786, "e": 0.0041, "scene_a": 500.0, "phase": 106.0},
	{"name": "Европа", "key": "europa", "kind": "moon", "parent": 8, "radius": 24.0,
		"radius_km": 1560.8, "mass_kg": 4.79984e22, "color": Color("#b2aaa0"), "resource": "ice",
		"a_km": 671100.0, "period_days": 3.551181, "e": 0.0094, "scene_a": 795.0, "phase": 176.0},
	{"name": "Ганимед", "key": "ganymede", "kind": "moon", "parent": 8, "radius": 35.0,
		"radius_km": 2634.1, "mass_kg": 1.4819e23, "color": Color("#8f8d82"), "resource": "ice",
		"a_km": 1070400.0, "period_days": 7.15455296, "e": 0.0013, "scene_a": 1270.0, "phase": 121.0},
	{"name": "Каллисто", "key": "callisto", "kind": "moon", "parent": 8, "radius": 33.0,
		"radius_km": 2410.3, "mass_kg": 1.07594e23, "color": Color("#706f65"), "resource": "ice",
		"a_km": 1882700.0, "period_days": 16.6890184, "e": 0.0074, "scene_a": 2230.0, "phase": 84.0},
	{"name": "Сатурн", "key": "saturn", "kind": "gas", "radius": 180.0,
		"radius_km": 58232.0, "mass_kg": 5.6834e26, "color": Color("#d5c28e"), "type": "Газовый гигант",
		"rings": true, "gas_palette_low": Color("#ab945f"), "gas_palette_high": Color("#e4d5aa"),
		"jpl": [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448, 10759.22],
		"atmosphere": {"height": 42.0, "density": 1.55, "color": Color("#dfcb9a")}},
	{"name": "Мимас", "key": "mimas", "kind": "moon", "parent": 13, "radius": 14.0,
		"radius_km": 198.2, "mass_kg": 3.7493e19, "color": Color("#9d9fa2"), "resource": "ice",
		"a_km": 185539.0, "period_days": 0.942421813, "e": 0.0196, "scene_a": 300.0, "phase": 15.0},
	{"name": "Энцелад", "key": "enceladus", "kind": "moon", "parent": 13, "radius": 17.0,
		"radius_km": 252.1, "mass_kg": 1.08022e20, "color": Color("#cfdae0"), "resource": "ice",
		"a_km": 238037.0, "period_days": 1.370218, "e": 0.0047, "scene_a": 385.0, "phase": 76.0},
	{"name": "Тефия", "key": "tethys", "kind": "moon", "parent": 13, "radius": 21.0,
		"radius_km": 531.1, "mass_kg": 6.17449e20, "color": Color("#b7bdc0"), "resource": "ice",
		"a_km": 294619.0, "period_days": 1.887802, "e": 0.0001, "scene_a": 476.0, "phase": 140.0},
	{"name": "Диона", "key": "dione", "kind": "moon", "parent": 13, "radius": 22.0,
		"radius_km": 561.4, "mass_kg": 1.09545e21, "color": Color("#b1b2af"), "resource": "ice",
		"a_km": 377396.0, "period_days": 2.736915, "e": 0.0022, "scene_a": 610.0, "phase": 212.0},
	{"name": "Рея", "key": "rhea", "kind": "moon", "parent": 13, "radius": 25.0,
		"radius_km": 763.8, "mass_kg": 2.30652e21, "color": Color("#b3b6b2"), "resource": "ice",
		"a_km": 527108.0, "period_days": 4.518212, "e": 0.0010, "scene_a": 852.0, "phase": 276.0},
	{"name": "Титан", "key": "titan", "kind": "moon", "parent": 13, "radius": 35.0,
		"radius_km": 2574.73, "mass_kg": 1.3452e23, "color": Color("#b18b4e"), "resource": "ice",
		"a_km": 1221870.0, "period_days": 15.945421, "e": 0.0288, "scene_a": 1975.0, "phase": 326.0,
		"atmosphere": {"height": 18.0, "density": 1.35, "color": Color("#cca45d")}},
	{"name": "Япет", "key": "iapetus", "kind": "moon", "parent": 13, "radius": 25.0,
		"radius_km": 734.5, "mass_kg": 1.80564e21, "color": Color("#969386"), "resource": "ice",
		"a_km": 3560820.0, "period_days": 79.3215, "e": 0.0283, "scene_a": 5758.0, "phase": 195.0},
	{"name": "Уран", "key": "uranus", "kind": "gas", "radius": 125.0,
		"radius_km": 25362.0, "mass_kg": 8.6810e25, "color": Color("#80c5c7"), "type": "Ледяной гигант",
		"gas_palette_low": Color("#6aadaf"), "gas_palette_high": Color("#ace2df"),
		"jpl": [19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503, 30688.5],
		"atmosphere": {"height": 32.0, "density": 1.3, "color": Color("#94d0d2")}},
	{"name": "Миранда", "key": "miranda", "kind": "moon", "parent": 21, "radius": 16.0,
		"radius_km": 235.8, "mass_kg": 6.59e19, "color": Color("#999e9d"), "resource": "ice",
		"a_km": 129390.0, "period_days": 1.413479, "e": 0.0013, "scene_a": 260.0, "phase": 24.0, "inclination": 102.0},
	{"name": "Ариэль", "key": "ariel", "kind": "moon", "parent": 21, "radius": 22.0,
		"radius_km": 578.9, "mass_kg": 1.353e21, "color": Color("#b4bbbc"), "resource": "ice",
		"a_km": 191020.0, "period_days": 2.520379, "e": 0.0012, "scene_a": 384.0, "phase": 98.0, "inclination": 98.0},
	{"name": "Умбриэль", "key": "umbriel", "kind": "moon", "parent": 21, "radius": 22.0,
		"radius_km": 584.7, "mass_kg": 1.172e21, "color": Color("#646d70"), "resource": "ice",
		"a_km": 266300.0, "period_days": 4.144177, "e": 0.0039, "scene_a": 535.0, "phase": 172.0, "inclination": 98.0},
	{"name": "Титания", "key": "titania", "kind": "moon", "parent": 21, "radius": 27.0,
		"radius_km": 788.9, "mass_kg": 3.527e21, "color": Color("#979c99"), "resource": "ice",
		"a_km": 435910.0, "period_days": 8.705872, "e": 0.0011, "scene_a": 876.0, "phase": 249.0, "inclination": 98.0},
	{"name": "Оберон", "key": "oberon", "kind": "moon", "parent": 21, "radius": 26.0,
		"radius_km": 761.4, "mass_kg": 3.014e21, "color": Color("#858a87"), "resource": "ice",
		"a_km": 583520.0, "period_days": 13.463239, "e": 0.0014, "scene_a": 1173.0, "phase": 320.0, "inclination": 98.0},
	{"name": "Нептун", "key": "neptune", "kind": "gas", "radius": 122.0,
		"radius_km": 24622.0, "mass_kg": 1.02413e26, "color": Color("#416dbd"), "type": "Ледяной гигант",
		"gas_palette_low": Color("#24498a"), "gas_palette_high": Color("#719ad8"),
		"jpl": [30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574, 60182.0],
		"atmosphere": {"height": 32.0, "density": 1.35, "color": Color("#537fd0")}},
	{"name": "Тритон", "key": "triton", "kind": "moon", "parent": 27, "radius": 24.0,
		"radius_km": 1353.4, "mass_kg": 2.139e22, "color": Color("#a6b2ba"), "resource": "ice",
		"a_km": 354759.0, "period_days": 5.876854, "e": 0.000016, "scene_a": 400.0, "phase": 40.0, "inclination": 157.0},
	{"name": "Нереида", "key": "nereid", "kind": "moon", "parent": 27, "radius": 14.0,
		"radius_km": 170.0, "color": Color("#7e8993"), "resource": "ice",
		"a_km": 5513818.0, "period_days": 360.1362, "e": 0.7507, "scene_a": 6217.0, "phase": 145.0, "inclination": 7.0},
	{"name": "Церера", "key": "ceres", "kind": "planet", "radius": 28.0,
		"radius_km": 469.7, "mass_kg": 9.3835e20, "color": Color("#858781"), "type": "Карликовая планета",
		"orbit": [2.7675, 0.0758, 10.593, 80.305, 73.598, 96.0, 1681.63]},
	{"name": "Плутон", "key": "pluto", "kind": "planet", "radius": 35.0,
		"radius_km": 1188.3, "mass_kg": 1.303e22, "color": Color("#b8a28f"), "type": "Карликовая планета", "resource": "ice",
		"element_note": "Движение Плутона и Харона вокруг общего барицентра отдельно не решается.",
		"jpl": [39.48211675, 0.24882730, 17.14001206, 238.92903833, 224.06891629, 110.30393684, 90560.0]},
	{"name": "Харон", "key": "charon", "kind": "moon", "parent": 31, "radius": 21.0,
		"radius_km": 606.0, "mass_kg": 1.586e21, "color": Color("#96969c"), "resource": "ice",
		"a_km": 19596.0, "period_days": 6.3872304, "e": 0.0002, "scene_a": 140.0, "phase": 180.0},
	{"name": "Хаумеа", "key": "haumea", "kind": "planet", "radius": 30.0,
		"radius_km": 798.0, "mass_kg": 4.006e21, "color": Color("#b9c4c9"), "type": "Карликовая планета", "resource": "ice",
		"radius_note": "Приблизительный объёмно-эквивалентный радиус; тело существенно вытянуто.",
		"orbit": [43.13, 0.196, 28.2, 121.9, 240.7, 205.0, 103774.0]},
	{"name": "Намака", "key": "namaka", "kind": "moon", "parent": 33, "radius": 10.0,
		"radius_km": 85.0, "color": Color("#aab8c0"), "resource": "ice", "radius_note": "Оценка по яркости; размер известен с большой неопределённостью.",
		"a_km": 25657.0, "period_days": 18.2783, "e": 0.249, "scene_a": 130.0, "phase": 45.0, "inclination": 13.0},
	{"name": "Хииака", "key": "hiiaka", "kind": "moon", "parent": 33, "radius": 13.0,
		"radius_km": 160.0, "color": Color("#bbc9d0"), "resource": "ice", "radius_note": "Приблизительный радиус; альбедо и форма ограничивают точность.",
		"a_km": 49880.0, "period_days": 49.462, "e": 0.0513, "scene_a": 253.0, "phase": 220.0},
	{"name": "Макемаке", "key": "makemake", "kind": "planet", "radius": 30.0,
		"radius_km": 715.0, "color": Color("#ba8d73"), "type": "Карликовая планета", "resource": "ice",
		"orbit": [45.79, 0.161, 29.0, 79.6, 294.8, 165.0, 112897.0]},
	{"name": "Эрида", "key": "eris", "kind": "planet", "radius": 34.0,
		"radius_km": 1163.0, "mass_kg": 1.6466e22, "color": Color("#d0d9df"), "type": "Карликовая планета", "resource": "ice",
		"orbit": [67.7, 0.44, 44.0, 35.95, 151.6, 202.0, 203450.0]},
	{"name": "Дисномия", "key": "dysnomia", "kind": "moon", "parent": 37, "radius": 16.0,
		"radius_km": 350.0, "color": Color("#8c9aa7"), "resource": "ice", "radius_note": "Приблизительный термически оценённый радиус.",
		"a_km": 37273.0, "period_days": 15.785899, "e": 0.0062, "scene_a": 165.0, "phase": 110.0},
	{"name": "Комета Галлея", "key": "halley", "kind": "comet", "radius": 15.0,
		"radius_km": 5.5, "color": Color("#74818a"), "type": "Периодическая комета 1P/Halley", "resource": "ice",
		"radius_note": "Приблизительный эквивалентный радиус неправильного ядра; это не радиус комы.",
		"orbit": [17.834, 0.96714, 162.26, 58.42, 111.33, 66.4, 27508.0]},
]


static func build(first_site: int, position: Vector3) -> Dictionary:
	var sites: Array[Dictionary] = []
	var targets: Array[int] = []
	var mines: Array[int] = []
	var gas_giants: Array[int] = []
	var atmospheric_sites: Array[int] = []
	for index in range(BODIES.size()):
		var site := _site(BODIES[index], index, first_site)
		sites.append(site)
		var id := first_site + index
		targets.append(id)
		if site.kind == "gas":
			gas_giants.append(id)
		elif site.kind != "star":
			mines.append(id)
		if site.has("atmosphere"):
			atmospheric_sites.append(id)
	var surveys: Array[int] = targets.duplicate()
	surveys.erase(first_site)
	var system := {
		"name": "Sol / Солнечная система", "type": "astronomy",
		"position": Vector2(position.x, position.y), "position_3d": position,
		"sector": Vector2i(floori(position.x / 8.0), floori(position.y / 8.0)),
		"seed": 2451545, "accent": Color("#fff0c7"),
		"description": "Солнце, восемь планет, пять признанных карликовых планет, 25 именованных спутников и комета Галлея. Игровые порты не заданы. " + SCALE_NOTICE,
		"star": first_site, "targets": targets, "ports": [], "mines": mines,
		"survey_sites": surveys, "gas_giant": first_site + 8,
		"gas_giants": gas_giants, "atmospheric_sites": atmospheric_sites,
		"arrival_port": -1, "arrival_target": first_site,
		"stellar_heat": 1.0, "gravity_parameter": 8500.0,
		"astronomy": {"epoch": EPOCH, "scale_notice": SCALE_NOTICE,
			"ephemeris_notice": "Средние двухтельные орбиты; спутниковые фазы схематичны. Возмущения, прецессия и точные эфемериды Horizons не моделируются.",
			"sources": FACT_SOURCES.duplicate()},
	}
	return {"system": system, "sites": sites}


static func _site(row: Dictionary, index: int, first_site: int) -> Dictionary:
	var radius := float(row.radius)
	var is_star: bool = row.kind == "star"
	var site := {
		"name": row.name, "kind": row.kind, "center": Vector3.ZERO,
		"radius": radius, "pad_offset": radius, "gate_offset": radius + 90.0,
		"seed": 2451545 + index * 7919, "surface_color": row.color,
		"accent": Color(row.color).lightened(0.18), "astronomical_body": str(row.key),
		"orbit_parent": first_site + int(row.parent) if row.has("parent") else -1,
	}
	var facts := {
		"radius_km": float(row.radius_km), "epoch": EPOCH,
		"type": row.get("type", "Естественный спутник"), "scale_notice": SCALE_NOTICE,
		"sources": FACT_SOURCES.duplicate(),
	}
	if row.has("mass_kg"):
		facts.mass_kg = float(row.mass_kg)
	if row.has("radius_note"):
		facts.radius_note = str(row.radius_note)
	if is_star:
		# Scene gravity and scoop safety retain the existing game's unit system.
		# They are deliberately separate from the measured stellar mass/radius.
		site.pad_offset = 310.0
		site.gate_offset = 470.0
		site.star_clearance = 250.0
		site.mu = 8500.0
		site.stellar_heat = 1.0
		facts.spectral_class = "G2 V"
		facts.temperature_k = 5772.0
	else:
		var orbit := _orbit(row)
		site.astronomical_orbit = orbit
		facts.semimajor_km = float(row.a_km) if row.has("parent") else orbit.semimajor / AU_IN_SCENE * AU_KM
		facts.period_days = orbit.period / DAY_SECONDS
		facts.eccentricity = orbit.eccentricity
		facts.orbit_orientation_approximate = not row.has("jpl")
		facts.ephemeris_notice = APPROXIMATE_ORIENTATION if not row.has("jpl") else "Приближённые средние элементы JPL на J2000; взаимные возмущения и вековые поправки не рассчитываются."
		if row.has("element_note"):
			facts.ephemeris_notice += " " + str(row.element_note)
		if row.kind != "gas":
			# Deposits/reserves are gameplay values, not measured mineral surveys.
			site.resource = row.get("resource", "ore")
			site.reserve = 240
			site.drill_seconds = 12.0
		if row.has("atmosphere"):
			# Gameplay density and layer thickness, not real SI atmospheric profiles.
			site.atmosphere = row.atmosphere.duplicate(true)
		if row.kind == "gas":
			site.pad_offset = radius + 45.0
			site.gate_offset = radius + 160.0
			for key: String in ["rings", "gas_palette_low", "gas_palette_high"]:
				if row.has(key):
					site[key] = row[key]
	site.astronomy = facts
	return site


static func _orbit(row: Dictionary) -> Dictionary:
	var axis: float
	var eccentricity: float
	var inclination: float
	var ascending_node: float
	var periapsis: float
	var mean_anomaly: float
	var period_days: float
	if row.has("jpl"):
		var values: Array = row.jpl
		axis = float(values[0]) * AU_IN_SCENE
		eccentricity = float(values[1])
		inclination = float(values[2])
		ascending_node = float(values[5])
		periapsis = float(values[4]) - ascending_node
		mean_anomaly = float(values[3]) - float(values[4])
		period_days = float(values[6])
	elif row.has("parent"):
		axis = float(row.scene_a)
		eccentricity = float(row.e)
		inclination = float(row.get("inclination", 0.0))
		ascending_node = 0.0
		periapsis = 0.0
		mean_anomaly = float(row.phase)
		period_days = float(row.period_days)
	else:
		var values: Array = row.orbit
		axis = float(values[0]) * AU_IN_SCENE
		eccentricity = float(values[1])
		inclination = float(values[2])
		ascending_node = float(values[3])
		periapsis = float(values[4])
		mean_anomaly = float(values[5])
		period_days = float(values[6])
	return {
		"semimajor": axis, "eccentricity": eccentricity, "inclination": inclination,
		"ascending_node": wrapf(ascending_node, 0.0, 360.0),
		"argument_of_periapsis": wrapf(periapsis, 0.0, 360.0),
		"mean_anomaly": wrapf(mean_anomaly, 0.0, 360.0), "period": period_days * DAY_SECONDS,
	}
