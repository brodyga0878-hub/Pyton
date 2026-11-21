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
	dossier.archive = Named.ARCHIVE.get(system_id, [])
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


static func _stars(system_id: int) -> Array[Dictionary]:
	var stars: Array[Dictionary] = []
	for id: int in Catalog.stars_for(system_id):
		stars.append({"name": Catalog.site(id).name, "spectral_class": stellar_class(id)})
	return stars


static func stellar_class(site_id: int) -> String:
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
	return STELLAR_TEMPERATURES.get(stellar_class(site_id), 0.0)


static func _authority(control: Dictionary, faction: String) -> String:
	match str(control.stage):
		"core": return "Установленная юрисдикция · %s" % faction
		"peace": return "Администрация форпоста · %s" % faction
		"war":
			return "Контроль удерживает %s. Оспаривает %s." % [faction, Factions.faction_name(int(control.challenger))]
		_: return "Юрисдикция не закреплена"
