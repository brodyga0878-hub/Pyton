extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")
const Procedural := preload("res://scripts/procedural_systems.gd")
const Factions := preload("res://scripts/faction_fronts.gd")
const Named := preload("res://scripts/named_systems.gd")

# The chart colours of authored stars are independent of their spectral class.
const AUTHORED_SPECTRA := {
	Catalog.STAR_ID: "G V",
	Catalog.VELAR_STAR_ID: "A V",
	Catalog.FRINGE_STAR_ID: "K V",
	Catalog.HEATHER_STAR: "G V",
	Catalog.LIMIT_STAR: "F V",
	Catalog.BINARY_PRIMARY: "G V",
	Catalog.BINARY_SECONDARY: "K V",
}
const GENERATED_SPECTRA := ["K V", "G V", "A V"]
const STELLAR_TEMPERATURES := {"K V": 4650.0, "G V": 5772.0, "F V": 6850.0, "A V": 8300.0}
const CORE_PROFILES := {
	Catalog.HOME_SYSTEM: ["Постоянные орбитальные поселения", "Добыча и перевалка ресурсов"],
	Catalog.VELAR_SYSTEM: ["Орбитальные поселения и наземные службы на Лазури", "Торговые порты и ремонтные мастерские"],
	Catalog.FRINGE_SYSTEM: ["Поселения при перевалочных портах", "Грузовые перевозки и добыча кристаллов"],
}


static func read(sim: RefCounted, system_id: int) -> Dictionary:
	var dossier: Dictionary = sim.system_dossier(system_id)
	if not dossier.known:
		return dossier
	dossier.stars = _stars(system_id)
	var system := Catalog.system(system_id)
	dossier.archive = system.get("archive", Named.ARCHIVE.get(system_id, []))
	var astronomy := physical_metadata(system.get("astronomy", {}))
	for field: String in ["scale_notice", "ephemeris_notice"]:
		if system.has(field) or astronomy.has(field):
			dossier[field] = str(system.get(field, astronomy.get(field, "")))
	if not astronomy.is_empty():
		dossier["astronomy"] = astronomy
		if dossier.archive.is_empty():
			dossier.archive = _astronomical_archive(astronomy)
	dossier.population_range = Named.population(dossier.ports)
	var local_profile: Array = CORE_PROFILES.get(system_id, [])
	if not local_profile.is_empty():
		dossier.population = local_profile[0]
		dossier.economy = local_profile[1]
	elif not dossier.ports.is_empty():
		dossier.population = "Постоянный орбитальный форпост"
		dossier.economy = "Снабжение форпоста и местная добыча"
	else:
		dossier.population = "Постоянные поселения не зарегистрированы"
		dossier.economy = "Действующих портовых рынков нет"
	var control: Dictionary = sim.factions.system_state(system_id)
	dossier.authority = _authority(control, dossier.faction)
	var owner := int(control.owner)
	dossier.regime = "Советы портов" if owner == 0 else "Концессионная администрация Лиги" if owner == 1 else ""
	return dossier


static func _astronomical_archive(astronomy: Dictionary) -> Array[String]:
	var result: Array[String] = ["Открытые астрономические данные"]
	if astronomy.has("epoch"):
		result.append("Эпоха каталога: " + str(astronomy.epoch))
	for field: String in ["scale_notice", "ephemeris_notice"]:
		if not str(astronomy.get(field, "")).is_empty():
			result.append(str(astronomy[field]))
	var sources := PackedStringArray()
	if astronomy.get("sources") is Array:
		for source: Variant in astronomy.sources:
			if source is String and not source.is_empty():
				sources.append(source)
	if not str(astronomy.get("source_url", "")).is_empty():
		sources.append(str(astronomy.source_url))
	if not sources.is_empty():
		result.append("Источники:\n" + "\n".join(sources))
	if not str(astronomy.get("license", "")).is_empty():
		result.append("Лицензия источника: " + str(astronomy.license) + "\n" + str(astronomy.get("license_url", "")))
	return result


static func _stars(system_id: int) -> Array[Dictionary]:
	var stars: Array[Dictionary] = []
	for id: int in Catalog.stars_for(system_id):
		var row := {"name": Catalog.site(id).name, "spectral_class": stellar_class(id)}
		var physical := body_astronomy(id)
		if not physical.is_empty():
			row["astronomy"] = physical
		stars.append(row)
	return stars


static func stellar_class(site_id: int) -> String:
	var physical := body_astronomy(site_id)
	if not str(physical.get("spectral_class", "")).is_empty():
		return str(physical.spectral_class)
	if Catalog.is_astronomical_system(Catalog.system_of_site(site_id)):
		# An absent public spectrum must not inherit a procedural colour class.
		return ""
	if AUTHORED_SPECTRA.has(site_id):
		return AUTHORED_SPECTRA[site_id]
	var star := Catalog.site(site_id)
	if star.get("kind", "") != "star":
		return ""
	if star.has("mu"):
		return "K V" if site_id != Catalog.star_for(Catalog.system_of_site(site_id)) else "G V"
	var color_group := Procedural.STELLAR_COLORS.find(star.accent)
	return GENERATED_SPECTRA[color_group] if color_group >= 0 else ""


static func stellar_temperature(site_id: int) -> float:
	var physical := body_astronomy(site_id)
	if float(physical.get("temperature_k", 0.0)) > 0.0:
		return float(physical.temperature_k)
	if Catalog.is_astronomical_system(Catalog.system_of_site(site_id)):
		return 0.0
	return STELLAR_TEMPERATURES.get(stellar_class(site_id), 0.0)


static func body_astronomy(site_id: int) -> Dictionary:
	return physical_metadata(Catalog.site(site_id).get("astronomy", {}))


static func physical_metadata(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var result: Dictionary = raw.duplicate(true)
	for field: String in ["radius_km", "mass_kg", "semimajor_km", "period_days", "temperature_k", "rotation_period_days"]:
		if not result.has(field):
			continue
		var value: Variant = result[field]
		if not (value is float or value is int) or not is_finite(float(value)) or (field != "rotation_period_days" and float(value) < 0.0):
			result.erase(field)
	for field: String in ["type", "spectral_class", "epoch", "scale_notice", "ephemeris_notice"]:
		if result.has(field) and not result[field] is String:
			result.erase(field)
	return result


static func _authority(control: Dictionary, faction: String) -> String:
	match str(control.stage):
		"core": return "Установленная юрисдикция · %s" % faction
		"peace": return "Администрация форпоста · %s" % faction
		"war":
			return "Контроль удерживает %s. Оспаривает %s." % [faction, Factions.faction_name(int(control.challenger))]
		_: return "Юрисдикция не закреплена"
