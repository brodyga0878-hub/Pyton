extends RefCounted
## Survey and construction contracts reveal the frontier in order.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Factions = preload("res://scripts/faction_fronts.gd")
const MiningRig = preload("res://scripts/mining_rig.gd")

const LOCKED := 0
const SURVEY := 1
const REPORT := 2
const BUILD := 3
const COMPLETE := 4
const FRONTIER_SYSTEMS := [Catalog.HEATHER_SYSTEM, Catalog.LIMIT_SYSTEM]
const SURVEY_TOTAL := 2
const BUILD_TOTAL := 2
const SURVEY_RANGE := 80.0
const SUPPLY_RANGE := 90.0
const SERVICE_SPEED := 34.0
const BUILD_APPROACH_OFFSET := 90.0
const SURVEY_REWARDS := [520, 620]
const CONSTRUCTION_REWARDS := [680, 880]
const SUPPLIES := [
	[{"ore": 6, "circuits": 2}, {"ore": 4, "crystal": 3}],
	[{"ore": 8, "medical": 3}, {"crystal": 4, "circuits": 3}],
]
const PROJECT_FIELDS := ["phase", "sponsor_port", "sponsor", "scan_index", "build_index"]

var _projects: Array[Dictionary] = [_new_project(), _new_project()]


func known(system: int) -> bool:
	if system >= 0 and system < Catalog.CORE_SYSTEM_COUNT:
		return true
	var index := FRONTIER_SYSTEMS.find(system)
	return index >= 0 and int(_projects[index].phase) != LOCKED


func commissioned(system: int) -> bool:
	var index := FRONTIER_SYSTEMS.find(system)
	return index >= 0 and int(_projects[index].phase) == COMPLETE


func status(sim: RefCounted) -> Dictionary:
	var active := _active_project()
	var index := active if active >= 0 else _projects.size() - 1
	var record := _projects[index]
	var system: int = FRONTIER_SYSTEMS[index]
	var phase: int = record.phase
	var result := {
		"phase": phase, "system": system, "sponsor_port": int(record.sponsor_port), "sponsor": int(record.sponsor),
		"scan_index": int(record.scan_index), "scan_total": SURVEY_TOTAL,
		"build_index": int(record.build_index), "build_total": BUILD_TOTAL,
		"survey_reward": SURVEY_REWARDS[index], "build_reward": CONSTRUCTION_REWARDS[index],
		"site": -1, "point": Vector3.ZERO, "has_point": false, "distance": -1.0,
		"ready": false, "can_follow": false, "can_act": false,
		"caption": "", "reason": "", "needs": {}, "missing": {},
		"route_system": -1, "route_port": -1, "series_done": active < 0,
	}
	if phase == COMPLETE:
		result.reason = "Обе станции введены в строй. Сведения о них есть на карте фракций."
		return result
	if phase == LOCKED:
		result.caption = "Принять заказ"
		result.can_act = _eligible_sponsor(sim)
		result.reason = "Следующий сектор откроется после принятия заказа."
		if not result.can_act:
			result.reason = "Примите заказ в действующем порту одной из фракций."
		return result
	if phase == REPORT:
		var port: int = record.sponsor_port
		result.route_port = port
		result.route_system = Catalog.system_of_site(port)
		result.can_act = sim.docked == port and sim.system_id == result.route_system and sim.station_operational(port)
		result.caption = "Передать отчёт"
		result.reason = "Вернитесь с отчётом в порт «%s»." % Catalog.site(port).name
		if sim.system_id == system:
			result.reason += " Для обратного прыжка соберите водород у звезды и перелейте его в прыжковый запас."
		return result
	var area := Catalog.system(system)
	var site := -1
	if phase == SURVEY:
		var sites: Array = area.get("survey_sites", [])
		if sites.size() != SURVEY_TOTAL:
			return result
		site = int(sites[record.scan_index])
		result.caption = "Обследовать"
	else:
		site = int(area.get("construction_port", -1))
		if site < 0:
			return result
		var needs: Dictionary = SUPPLIES[index][record.build_index]
		result.needs = needs.duplicate()
		result.missing = _missing_materials(sim, needs)
		result.caption = "Разгрузить"
	result.site = site
	result.route_system = system
	if sim.system_id != system:
		result.reason = "Выполните прыжок в систему «%s»." % area.name
		if phase == SURVEY:
			result.reason += " Действующего порта там пока нет."
		elif sim.ship.jump_fuel < Catalog.jump_cost(sim.system_id, system):
			result.reason += " Водород можно собрать у местной звезды и перелить в прыжковый запас."
		return result
	var point: Vector3 = sim.target_gate(site)
	if phase == BUILD:
		point += Vector3.BACK * BUILD_APPROACH_OFFSET
	result.point = point
	result.has_point = true
	var distance: float = sim.position.distance_to(point)
	result.distance = distance
	if not _airborne(sim):
		result.reason = "Выйдите в открытый космос, чтобы продолжить."
		return result
	var range := SURVEY_RANGE if phase == SURVEY else SUPPLY_RANGE
	if distance > range:
		result.can_follow = true
		result.reason = "Сблизьтесь с целью обследования." if phase == SURVEY else "Подойдите к стройплощадке."
		return result
	if sim.speed_relative_to(site) > SERVICE_SPEED:
		result.can_follow = true
		result.reason = "Снизьте относительную скорость до %d м/с." % int(SERVICE_SPEED)
		return result
	result.ready = true
	if phase == BUILD:
		if sim.mining.phase != MiningRig.STOWED:
			result.reason = "Верните добывающий модуль на борт перед разгрузкой."
			return result
		if not result.missing.is_empty():
			result.reason = "В трюме не хватает материалов для этой поставки."
			return result
	result.can_act = true
	result.reason = "Доступно обследование тела «%s»." % Catalog.site(site).name if phase == SURVEY else "Материалы готовы к передаче."
	return result


func act(sim: RefCounted) -> Dictionary:
	var state := status(sim)
	if not state.can_act:
		return {"ok": false}
	var index := _active_project()
	var record := _projects[index]
	var system: int = state.system
	var name: String = Catalog.system(system).name
	match int(record.phase):
		LOCKED:
			record.sponsor_port = int(sim.docked)
			record.sponsor = int(sim.factions.owner(sim.system_id))
			record.phase = SURVEY
			return {
				"ok": true, "event": "expedition_accepted", "planned_system": system,
				"message": "Система «%s» добавлена на карту. Обследуйте два небесных тела." % name,
			}
		SURVEY:
			record.scan_index += 1
			if record.scan_index == SURVEY_TOTAL:
				record.phase = REPORT
				return {
					"ok": true, "event": "expedition_survey", "planned_system": Catalog.system_of_site(record.sponsor_port),
					"message": "Обследование завершено. Передайте отчёт в порт «%s»." % Catalog.site(record.sponsor_port).name,
				}
			return {"ok": true, "event": "expedition_survey", "message": "Данные получены. Обследуйте следующее тело."}
		REPORT:
			record.phase = BUILD
			return {
				"ok": true, "event": "expedition_report", "planned_system": system, "credits": SURVEY_REWARDS[index],
				"message": "Отчёт принят. Оплата %d кр. Доставьте материалы для станции." % SURVEY_REWARDS[index],
			}
		BUILD:
			var final_lot: bool = record.build_index + 1 == BUILD_TOTAL
			if final_lot and sim.factions.owner(system) >= 0:
				return {"ok": false}
			if not _transfer_materials(sim, state.needs):
				return {"ok": false}
			record.build_index += 1
			if final_lot:
				record.phase = COMPLETE
				return {
					"ok": true, "event": "expedition_complete", "commissioned": system,
					"owner": int(record.sponsor), "credits": CONSTRUCTION_REWARDS[index],
					"message": "Станция в системе «%s» введена в строй. Оплата %d кр." % [name, CONSTRUCTION_REWARDS[index]],
				}
			return {"ok": true, "event": "expedition_supply", "message": "Первая партия доставлена. Проверьте состав следующей поставки."}
	return {"ok": false}


func snapshot() -> Dictionary:
	return {"projects": _projects.duplicate(true)}


func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 1 or not value.get("projects") is Array:
		return false
	if value.projects.size() != FRONTIER_SYSTEMS.size():
		return false
	var restored: Array[Dictionary] = []
	for index in range(FRONTIER_SYSTEMS.size()):
		var item: Variant = value.projects[index]
		if not item is Dictionary or item.size() != PROJECT_FIELDS.size() or not item.has_all(PROJECT_FIELDS):
			return false
		if not _integer(item.phase, LOCKED, COMPLETE) or not _integer(item.scan_index, 0, SURVEY_TOTAL) or not _integer(item.build_index, 0, BUILD_TOTAL):
			return false
		if not _integer(item.sponsor, -1, Factions.FACTIONS.size() - 1) or not _integer(item.sponsor_port, -1, Catalog.DESTINATION_COUNT - 1):
			return false
		var phase := int(item.phase)
		var scans := int(item.scan_index)
		var lots := int(item.build_index)
		var sponsor := int(item.sponsor)
		var port := int(item.sponsor_port)
		if phase == LOCKED:
			if sponsor != -1 or port != -1 or scans != 0 or lots != 0:
				return false
		else:
			if index > 0 and restored[index - 1].phase != COMPLETE:
				return false
			var sponsor_system := Catalog.system_of_site(port)
			if sponsor < 0 or not Catalog.is_port(port) or sponsor_system >= FRONTIER_SYSTEMS[index]:
				return false
			if sponsor_system < Catalog.CORE_SYSTEM_COUNT and sponsor != Factions.CORE_OWNERS[sponsor_system]:
				return false
			if not _counts_match(phase, scans, lots):
				return false
		restored.append({"phase": phase, "sponsor_port": port, "sponsor": sponsor, "scan_index": scans, "build_index": lots})
	_projects = restored
	return true


func _active_project() -> int:
	for index in range(_projects.size()):
		if _projects[index].phase != COMPLETE:
			return index
	return -1


static func _counts_match(phase: int, scans: int, lots: int) -> bool:
	match phase:
		SURVEY: return scans < SURVEY_TOTAL and lots == 0
		REPORT: return scans == SURVEY_TOTAL and lots == 0
		BUILD: return scans == SURVEY_TOTAL and lots < BUILD_TOTAL
		COMPLETE: return scans == SURVEY_TOTAL and lots == BUILD_TOTAL
	return false


static func _new_project() -> Dictionary:
	return {"phase": LOCKED, "sponsor_port": -1, "sponsor": -1, "scan_index": 0, "build_index": 0}


static func _eligible_sponsor(sim: RefCounted) -> bool:
	if not sim.station_operational(sim.docked) or Catalog.system_of_site(sim.docked) != sim.system_id:
		return false
	var faction: int = sim.factions.owner(sim.system_id)
	return faction >= 0 and faction < Factions.FACTIONS.size()


static func _airborne(sim: RefCounted) -> bool:
	return sim.docked < 0 and not sim.landed and sim.jump_seconds_left <= 0.0


static func _missing_materials(sim: RefCounted, needs: Dictionary) -> Dictionary:
	var missing := {}
	for good: String in needs:
		var short := int(needs[good]) - int(sim.mining.cargo_amount(good))
		if short > 0:
			missing[good] = short
	return missing


static func _transfer_materials(sim: RefCounted, needs: Dictionary) -> bool:
	var removed := {}
	for good: String in needs:
		if not sim.mining.remove_cargo(good, int(needs[good])):
			for returned: String in removed:
				sim.mining.insert_cargo(returned, int(removed[returned]))
			return false
		removed[good] = needs[good]
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(value) and floorf(value) == value and value >= minimum and value <= maximum
