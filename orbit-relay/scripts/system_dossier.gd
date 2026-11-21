extends RefCounted

const Catalog := preload("res://scripts/sector_catalog.gd")
const Procedural := preload("res://scripts/procedural_systems.gd")
const Factions := preload("res://scripts/faction_fronts.gd")

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
	return dossier


static func _stars(system_id: int) -> Array[Dictionary]:
	var stars: Array[Dictionary] = []
	for id: int in Catalog.stars_for(system_id):
		var star := Catalog.site(id)
		var spectral_class: String = AUTHORED_SPECTRA.get(id, "")
		if spectral_class.is_empty():
			var color_group := Procedural.STELLAR_COLORS.find(star.accent)
			if color_group >= 0:
				spectral_class = GENERATED_SPECTRA[color_group]
		stars.append({"name": star.name, "spectral_class": spectral_class})
	return stars


static func _authority(control: Dictionary, faction: String) -> String:
	match str(control.stage):
		"core": return "Установленная юрисдикция · %s" % faction
		"peace": return "Администрация форпоста · %s" % faction
		"war":
			return "Контроль удерживает %s. Оспаривает %s." % [faction, Factions.faction_name(int(control.challenger))]
		_: return "Юрисдикция не закреплена"
