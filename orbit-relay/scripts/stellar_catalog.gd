extends RefCounted
## Historical measured star records, not procedurally invented planetary systems.
## HYG data attribution and reproducible import: data/stellar_catalog/README.md.

const Data := preload("res://scripts/stellar_catalog_data.gd")
const COUNT := Data.COUNT
const SOURCE := "HYG Database 4.1"
const SOURCE_URL := "https://github.com/astronexus/HYG-Database/blob/c7f7f883fe678cc7680169a50ccd7dcc49b060ce/hyg/CURRENT/hygdata_v41.csv"
const SOURCE_LICENSE := "CC-BY-SA-4.0"
# These are explicitly game-local reference dimensions, not catalog measurements.
const LOCAL_RADIUS := 220.0
const LOCAL_GRAVITY_PARAMETER := 8000.0
const SECTOR_SIZE := 8.0


static func position_at(index: int) -> Vector3:
	if index < 0 or index >= COUNT:
		return Vector3.ZERO
	var point: Array = Data.ROWS[index][Data.GALACTIC_LY]
	return Vector3(point[0], point[1], point[2])


static func name_at(index: int) -> String:
	return str(Data.ROWS[index][Data.NAME]) if index >= 0 and index < COUNT else ""


static func hyg_id_at(index: int) -> int:
	return int(Data.ROWS[index][Data.HYG_ID]) if index >= 0 and index < COUNT else -1


static func index_for_hyg(hyg_id: int) -> int:
	var low := 0
	var high := COUNT
	while low < high:
		@warning_ignore("integer_division")
		var middle := (low + high) / 2
		var candidate := int(Data.ROWS[middle][Data.HYG_ID])
		if candidate < hyg_id:
			low = middle + 1
		else:
			high = middle
	return low if low < COUNT and int(Data.ROWS[low][Data.HYG_ID]) == hyg_id else -1


static func metadata_at(index: int) -> Dictionary:
	if index < 0 or index >= COUNT:
		return {}
	var row: Array = Data.ROWS[index]
	var equatorial: Array = row[Data.EQUATORIAL_PC].duplicate()
	var galactic: Array = row[Data.GALACTIC_LY].duplicate()
	var group_ids: Array = row[Data.GROUP_IDS].duplicate()
	for values: Array in [equatorial, galactic, group_ids]:
		values.make_read_only()
	var result := {
		"catalog": SOURCE, "catalog_id": "HYG-4.1:%d" % int(row[Data.HYG_ID]),
		"hyg_id": int(row[Data.HYG_ID]), "source_url": SOURCE_URL, "source_sha256": Data.SOURCE_SHA256,
		"source_author": "David Nash / Astronexus", "license": SOURCE_LICENSE,
		"license_url": "https://creativecommons.org/licenses/by-sa/4.0/",
		"record_type": "individual_star_record", "epoch": "J2000.0",
		"source_label": row[Data.LABEL], "proper_name": row[Data.PROPER],
		"bayer_flamsteed": row[Data.BAYER_FLAMSTEED], "gliese": row[Data.GLIESE],
		"hip_id": row[Data.HIP] if int(row[Data.HIP]) > 0 else null,
		"hd_id": row[Data.HD] if int(row[Data.HD]) > 0 else null,
		"hr_id": row[Data.HR] if int(row[Data.HR]) > 0 else null,
		"right_ascension_hours": row[Data.RA_HOURS], "declination_degrees": row[Data.DEC_DEGREES],
		"distance_pc": row[Data.DISTANCE_PC], "distance_ly": float(row[Data.DISTANCE_PC]) * Data.PARSEC_TO_LY,
		"equatorial_xyz_pc": equatorial, "galactic_xyz_ly": galactic,
		"coordinate_axes": "heliocentric Galactic +X(l=0), +Y(l=90), +Z(north); right-handed",
		"coordinate_policy": "Original HYG xyz rotated to Galactic; not rescaled to independent dist column",
		"spectral_class": row[Data.SPECTRUM], "color_index_bv": row[Data.COLOR_INDEX],
		"apparent_magnitude": row[Data.APPARENT_MAGNITUDE], "absolute_magnitude": row[Data.ABSOLUTE_MAGNITUDE],
		"luminosity_solar": row[Data.LUMINOSITY_SOLAR],
		"luminosity_basis": "HYG catalog photometric lum; not a verified bolometric measurement",
		"constellation": row[Data.CONSTELLATION],
		"source_comp": row[Data.COMP], "source_comp_primary": row[Data.COMP_PRIMARY], "source_base": row[Data.BASE],
		"same_hyg_group_record_ids": group_ids, "binary_orbits_modelled": false,
		"proper_motion_ra_mas_per_year": row[Data.PROPER_MOTION_RA],
		"proper_motion_dec_mas_per_year": row[Data.PROPER_MOTION_DEC], "radial_velocity_km_per_sec": row[Data.RADIAL_VELOCITY],
		"motion_propagated": false, "zero_rv_may_mean_unknown": true,
		"russian_display_alias": row[Data.NAME_LOCALIZED], "unofficial_hyg_companion_name": row[Data.UNOFFICIAL_COMPANION_NAME],
		"distance_uncertainty_available": false, "mass_solar": null, "radius_solar": null,
		"planetary_data_available": false, "local_dimensions_are_simulation_references": true,
	}
	result.make_read_only()
	return result


static func build(index: int, first_site: int, position: Vector3) -> Dictionary:
	if index < 0 or index >= COUNT or first_site < 0 or not position.is_finite():
		return {}
	var row: Array = Data.ROWS[index]
	var astronomy := metadata_at(index)
	var name := name_at(index)
	var accent := _accent(str(row[Data.SPECTRUM]))
	var spectral := str(row[Data.SPECTRUM])
	var description := "Звёздная запись HYG 4.1. Расстояние от Солнца по каталогу: %s св. л." % _decimal(float(astronomy.distance_ly))
	if not spectral.is_empty():
		description += " Спектр: %s." % spectral
	var group: Array = row[Data.GROUP_IDS]
	if group.size() > 1:
		description += " Группа %s содержит %d записей; здесь представлена одна компонента." % [str(row[Data.BASE]), group.size()]
	if bool(row[Data.UNOFFICIAL_COMPANION_NAME]):
		description += " Имя вторичной компоненты — неофициальная метка HYG."
	description += " Планетных данных в этом каталоге нет."
	var targets: Array[int] = [first_site]
	var empty: Array[int] = []
	targets.make_read_only()
	empty.make_read_only()
	var system := {
		"name": name, "position": Vector2(position.x, position.y), "position_3d": position,
		"sector": Vector2i(floori(position.x / SECTOR_SIZE), floori(position.y / SECTOR_SIZE)),
		"accent": accent, "description": description, "arrival_port": -1, "arrival_target": first_site,
		"star": first_site, "stars": targets, "targets": targets, "ports": empty, "mines": empty, "survey_sites": empty,
		"stellar_heat": 1.0, "gravity_parameter": LOCAL_GRAVITY_PARAMETER, "astronomy": astronomy,
		"stellar_catalog_index": index, "catalog_star_record": true,
	}
	var star := {
		"name": name, "kind": "star", "center": Vector3.ZERO, "radius": LOCAL_RADIUS,
		"pad_offset": 310.0, "gate_offset": 470.0, "accent": accent,
		"cool_star": _spectral_group(spectral) in ["O", "B", "A", "D", "W"],
		"mu": LOCAL_GRAVITY_PARAMETER, "stellar_heat": 1.0, "spectral_class": spectral, "astronomy": astronomy,
	}
	star.make_read_only()
	system.make_read_only()
	var sites: Array[Dictionary] = [star]
	sites.make_read_only()
	return {"system": system, "sites": sites}


static func _spectral_group(spectrum: String) -> String:
	var value := spectrum.strip_edges()
	for prefix: String in ["usd", "esd", "sd"]:
		if value.begins_with(prefix):
			value = value.substr(prefix.length())
	return value.left(1).to_upper()


static func _accent(spectrum: String) -> Color:
	# Chart symbols indicate broad catalog spectral families, not measured RGB.
	match _spectral_group(spectrum):
		"O": return Color("#a8c6ff")
		"B", "W": return Color("#bdd7ff")
		"A", "D": return Color("#e2ebff")
		"F": return Color("#fff0d7")
		"G": return Color("#ffe2ad")
		"K": return Color("#ffbb85")
		"M", "L", "T", "Y", "C", "N", "R", "S": return Color("#ff9975")
	return Color("#dedfd9")


static func _decimal(value: float) -> String:
	return ("%.2f" % value).replace(".", ",")
