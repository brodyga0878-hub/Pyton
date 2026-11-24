extends SceneTree

const Stars := preload("res://scripts/stellar_catalog.gd")
const Data := preload("res://scripts/stellar_catalog_data.gd")
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_expect(Stars.COUNT == 4380, "Pinned historical catalog has4380 non-Sol source star records")
	var near_count := 0
	var previous_id := -1
	var names := {}
	for index in range(Stars.COUNT):
		var id := Stars.hyg_id_at(index)
		var point := Stars.position_at(index)
		var entry := Stars.build(index, 7000 + index, point)
		var metadata: Dictionary = entry.system.astronomy
		_expect(id > previous_id and id != 0 and Stars.index_for_hyg(id) == index, "HYG IDs are unique, sorted and exactly reversible")
		_expect(point.is_finite() and point.length_squared() > 0.0, "Every source position is finite and distinct from the excluded solar origin")
		_expect(metadata.distance_pc > 0.0 and metadata.distance_pc < 100000.0, "Unknown/dubious HYG distance sentinel is excluded")
		_expect(metadata.distance_ly <= 100.0 or not str(metadata.proper_name).is_empty(), "Every included record satisfies the documented selection")
		_expect(entry.sites.size() == 1 and entry.sites[0].kind == "star" and entry.system.targets == [7000 + index]
			and entry.system.ports.is_empty() and entry.system.mines.is_empty(), "One star record produces exactly one fixed star site and no invented planets")
		_expect(entry.system.position_3d == point and entry.system.star == 7000 + index and entry.sites[0].center == Vector3.ZERO,
			"Catalog galaxy coordinates and caller-assigned site identity remain separate from local star coordinates")
		_expect(metadata.mass_solar == null and metadata.radius_solar == null and not metadata.planetary_data_available,
			"Unprovided physical and planetary quantities stay unavailable")
		_expect(entry.system.is_read_only() and entry.sites.is_read_only() and metadata.is_read_only()
			and metadata.equatorial_xyz_pc.is_read_only(), "Returned catalog records protect their stored provenance")
		_expect(not names.has(entry.system.name), "Localized display labels remain unambiguous")
		names[entry.system.name] = true
		if metadata.distance_ly <= 100.0:
			near_count += 1
		previous_id = id
	_expect(near_count == 4059, "Exactly4059 valid source records lie within100ly")
	_test_neighbors()
	_test_invalid()
	print("Measured stellar catalog: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_neighbors() -> void:
	var proxima := Stars.index_for_hyg(70666)
	var sirius := Stars.index_for_hyg(32263)
	var alpha_a := Stars.index_for_hyg(71456)
	var alpha_b := Stars.index_for_hyg(71453)
	_expect(Stars.name_at(proxima) == "Проксима Центавра" and Stars.name_at(sirius) == "Сириус A",
		"Familiar neighbors retain Russian labels with original source names in metadata")
	_expect(Stars.position_at(proxima).distance_to(Vector3(2.9309081507, -3.0414282247, -0.1421219809)) < 0.000002
		and Stars.position_at(sirius).distance_to(Vector3(-5.7702309915, -6.2378966813, -1.3291897015)) < 0.000002,
		"Independent reference directions confirm Galactic rotation, light-year units and handedness")
	var proxima_data := Stars.metadata_at(proxima)
	var a := Stars.metadata_at(alpha_a)
	var b := Stars.metadata_at(alpha_b)
	_expect(absf(float(proxima_data.distance_ly) - 4.22666049883128) < 0.000000001,
		"Distance preserves the pinned catalog value rather than a fabricated modern measurement")
	_expect(a.same_hyg_group_record_ids.has(71453) and b.same_hyg_group_record_ids.has(71456)
		and proxima_data.same_hyg_group_record_ids.is_empty() and not a.binary_orbits_modelled,
		"Only actual HYG cross-identifications are associated; Proxima is not merged by proximity")
	var mismatch := Stars.metadata_at(Stars.index_for_hyg(119395))
	var xyz: Array = mismatch.equatorial_xyz_pc
	var norm := sqrt(float(xyz[0]) * float(xyz[0]) + float(xyz[1]) * float(xyz[1]) + float(xyz[2]) * float(xyz[2]))
	_expect(absf(norm - float(mismatch.distance_pc)) > 0.01,
		"The source's small xyz/dist inconsistency is preserved transparently")
	var moved := Stars.build(proxima, 8000, Vector3(10, 20, 30))
	_expect(moved.system.position_3d == Vector3(10, 20, 30)
		and moved.system.astronomy.galactic_xyz_ly == proxima_data.galactic_xyz_ly,
		"A caller's atlas translation never alters the original heliocentric source metadata")


func _test_invalid() -> void:
	_expect(Stars.position_at(-1) == Vector3.ZERO and Stars.position_at(Stars.COUNT) == Vector3.ZERO
		and Stars.name_at(-1).is_empty() and Stars.hyg_id_at(Stars.COUNT) == -1, "Out-of-range identities do not create phantom records")
	_expect(Stars.build(-1, 0, Vector3.ZERO).is_empty() and Stars.build(Stars.COUNT, 0, Vector3.ZERO).is_empty()
		and Stars.build(0, -1, Vector3.ZERO).is_empty() and Stars.build(0, 0, Vector3(INF, 0, 0)).is_empty(),
		"Invalid site/position inputs fail without generating a system")
	_expect(Stars.index_for_hyg(0) == -1 and Stars.index_for_hyg(-1) == -1 and Stars.index_for_hyg(9999999) == -1,
		"Sol and unknown source IDs have no accidental catalog index")
	_expect(Stars.metadata_at(-1).is_empty() and Stars.metadata_at(Stars.COUNT).is_empty(), "Invalid metadata requests return no invented values")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition and _failures.size() < 30:
		_failures.append(message)
