extends RefCounted
## One commission to protect or stop a convoy in a contested system.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Factions = preload("res://scripts/faction_fronts.gd")
const Traffic = preload("res://scripts/sector_traffic.gd")
const IDLE := "idle"
const ACTIVE := "active"
const ESCORTED := "escorted"
const SUCCEEDED := "succeeded"
const FAILED := "failed"
const ESCORT := "escort"
const INTERCEPT := "intercept"
const ESCORT_RANGE := 96.0
const ESCORT_SPEED := 25.0
const ESCORT_SECONDS := 7.0
const BEAM_RANGE := 260.0
const DEFENCE_RANGE := 195.0
const AIM_COSINE := cos(deg_to_rad(24.0))
const PLAYER_DELAY := 0.38
const DEFENCE_DELAY := 2.6
const BEAM_DURATION := 0.18
const PLAYER_DAMAGE := 28.0
const MAX_HULL := 100.0
const ESCORT_REWARD := 360
const INTERCEPT_REWARD := 420
const SAVE_FIELDS := ["phase", "system", "id", "kind", "faction", "target_faction", "port",
	"deadline", "formation_time", "enemy_hull"]

var phase := IDLE
var system := -1
var convoy_id := ""
var kind := ""
var faction := -1
var target_faction := -1
var port := -1
var deadline := 0.0
var formation_time := 0.0
var enemy_hull := MAX_HULL

var _shot_delay := 0.0
var _attack_delay := DEFENCE_DELAY
var _player_flash := 0.0
var _enemy_flash := 0.0
var _player_beam := {}
var _enemy_beam := {}


func offers(sim: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _is_active() or not sim.station_operational(sim.docked):
		return result
	var sponsor: int = sim.factions.owner(sim.system_id)
	if sponsor < 0:
		return result
	for sector: int in Factions.FRONTIER_SYSTEMS:
		for convoy: Dictionary in sim.factions.active_convoys(sector):
			if convoy.assistance != "none" or float(convoy.due_at) <= sim.orbit_time:
				continue
			var order_kind := ESCORT if convoy.faction == sponsor else INTERCEPT
			result.append({
				"system": sector, "id": convoy.id, "kind": order_kind, "faction": sponsor,
				"target_faction": convoy.faction, "port": sim.docked, "deadline": convoy.due_at,
				"reward": _reward(order_kind), "name": _convoy_name(convoy.faction),
			})
	return result


func accept(sim: RefCounted, sector: int, id: String) -> Dictionary:
	for offer in offers(sim):
		if offer.system != sector or offer.id != id:
			continue
		phase = ACTIVE
		system = sector
		convoy_id = id
		kind = offer.kind
		faction = offer.faction
		target_faction = offer.target_faction
		port = offer.port
		deadline = float(offer.deadline)
		formation_time = 0.0
		enemy_hull = MAX_HULL
		_clear_effects()
		var action := "сопроводите" if kind == ESCORT else "перехватите"
		return {"ok": true, "event": "convoy_order_accepted", "message":
			"Заказ принят. В системе «%s» %s конвой фракции «%s»." % [
				Catalog.system(sector).name, action, Factions.faction_name(target_faction),
			]}
	return {}


func status(sim: RefCounted) -> Dictionary:
	var active := _is_active()
	var local: bool = system >= 0 and sim.system_id == system
	var contact := Traffic.convoy_contact(sim, convoy_id) if active and local else {}
	var has_point := not contact.is_empty()
	var point: Vector3 = contact.get("position", Vector3.ZERO)
	var drift: Vector3 = contact.get("velocity", Vector3.ZERO)
	var distance: float = sim.position.distance_to(point) if has_point else -1.0
	var ready := phase == ACTIVE and local and has_point and _airborne(sim)
	var can_fire := ready and kind == INTERCEPT
	var reason := "Заказы на конвои выдают в портах воюющих фракций."
	match phase:
		ACTIVE:
			if not local:
				reason = "Прыгните в систему «%s», пока конвой в пути." % Catalog.system(system).name
			elif not _airborne(sim):
				reason = "Выйдите в открытый космос и направьтесь к конвою."
			elif sim.ship.hull <= 1.0:
				reason = "Для продолжения восстановите корпус в порту."
			elif kind == ESCORT:
				reason = "Держитесь в пределах %d м от конвоя при относительной скорости до %d м/с." % [
					int(ESCORT_RANGE), int(ESCORT_SPEED),
				]
			else:
				reason = "Сблизьтесь с конвоем до %d м, наведитесь на цель и откройте огонь." % int(BEAM_RANGE)
		ESCORTED:
			reason = "Конвой под защитой. Дождитесь доставки груза."
		SUCCEEDED:
			reason = "Заказ выполнен. Получено %d кр." % _reward(kind)
		FAILED:
			reason = "Конвой закончил рейс до выполнения заказа."
	return {
		"phase": phase, "active": active, "system": system, "id": convoy_id, "kind": kind, "faction": faction,
		"target_faction": target_faction, "port": port, "deadline": deadline,
		"remaining": maxf(0.0, deadline - sim.orbit_time) if active else 0.0,
		"reward": _reward(kind), "name": _convoy_name(target_faction), "local": local,
		"distance": distance, "point": point, "point_velocity": drift, "has_point": has_point,
		"can_route": phase == ACTIVE and (not local or (ready and sim.ship.hull > 1.0)),
		"can_fire": can_fire, "fire_visible": can_fire, "formation_time": formation_time,
		"formation_required": ESCORT_SECONDS, "enemy_hull": enemy_hull, "reason": reason,
	}


func in_danger(sim: RefCounted) -> bool:
	if phase != ACTIVE or sim.system_id != system or not _airborne(sim):
		return false
	var contact := Traffic.convoy_contact(sim, convoy_id)
	if contact.is_empty():
		return false
	var range := BEAM_RANGE + 58.0 if kind == INTERCEPT else ESCORT_RANGE + 30.0
	return sim.position.distance_squared_to(contact.position) <= range * range


func step(sim: RefCounted, delta: float) -> Dictionary:
	# An exact calendar boundary can settle a delivered or expired contract.
	if not is_finite(delta) or delta < 0.0:
		return {}
	_shot_delay = maxf(0.0, _shot_delay - delta)
	_player_flash = maxf(0.0, _player_flash - delta)
	_enemy_flash = maxf(0.0, _enemy_flash - delta)
	if not _is_active():
		return {}
	var convoy: Dictionary = sim.factions.convoy(system, convoy_id)
	var outcome := _settle(convoy)
	if phase != ACTIVE:
		return outcome
	var contact := Traffic.convoy_contact(sim, convoy_id) if sim.system_id == system and _airborne(sim) else {}
	if kind == ESCORT:
		return _escort(sim, contact, delta)
	return _defend(sim, contact, delta)


func settle_front(sim: RefCounted) -> Dictionary:
	if not _is_active():
		return {}
	return _settle(sim.factions.convoy(system, convoy_id))


func _settle(convoy: Dictionary) -> Dictionary:
	if convoy.is_empty():
		return _fail()
	if phase == ESCORTED:
		if convoy.stage == "delivered" and convoy.assistance == ESCORT:
			return _pay("Конвой доставил груз.")
		return {} if convoy.stage == "en_route" else _fail()
	if convoy.stage != "en_route" or convoy.assistance != "none":
		return _fail()
	return {}


func fire_status(sim: RefCounted, range_bonus := 0.0) -> Dictionary:
	if kind != INTERCEPT or phase != ACTIVE or sim.system_id != system or not _airborne(sim):
		return {"ok": false, "reason": "Нет цели для огня", "distance": -1.0}
	return _aim_status(sim, Traffic.convoy_contact(sim, convoy_id), range_bonus)


func fire(sim: RefCounted, range_bonus := 0.0) -> Dictionary:
	if kind != INTERCEPT or phase != ACTIVE or sim.system_id != system or not _airborne(sim):
		return {"ok": false, "message": "Нет цели для огня"}
	var contact := Traffic.convoy_contact(sim, convoy_id)
	var ready := _aim_status(sim, contact, range_bonus)
	if not ready.ok:
		return {"ok": false, "message": ready.reason}
	var result := _take_hit(sim, PLAYER_DAMAGE)
	if result.ok:
		_shot_delay = PLAYER_DELAY
		_player_flash = BEAM_DURATION
		_player_beam = {"from": sim.position + sim.forward() * 2.5, "to": contact.position, "hostile": false}
	return result


func missile_hit(sim: RefCounted, id: String, damage: float) -> Dictionary:
	if id != convoy_id or kind != INTERCEPT or phase != ACTIVE or sim.system_id != system or not _airborne(sim):
		return {}
	if Traffic.convoy_contact(sim, convoy_id).is_empty():
		return {}
	return _take_hit(sim, damage)


func _take_hit(sim: RefCounted, damage: float) -> Dictionary:
	var hull := maxf(0.0, enemy_hull - damage)
	var interdiction: Dictionary = {}
	if hull == 0.0:
		interdiction = sim.factions.intercept_convoy(system, convoy_id, faction)
		if interdiction.is_empty():
			return {"ok": false, "message": "Конвой завершил рейс."}
	enemy_hull = hull
	if hull == 0.0:
		var outcome := _pay(str(interdiction.message))
		outcome.ok = true
		outcome.front_news = interdiction
		return outcome
	return {"ok": true, "event": "convoy_order_fire", "message": "Попадание. Корпус конвоя %.0f%%." % hull}


func beams() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _player_flash > 0.0:
		result.append(_player_beam)
	if _enemy_flash > 0.0:
		result.append(_enemy_beam)
	return result


func snapshot() -> Dictionary:
	return {
		"phase": phase, "system": system, "id": convoy_id, "kind": kind, "faction": faction,
		"target_faction": target_faction, "port": port, "deadline": deadline,
		"formation_time": formation_time, "enemy_hull": enemy_hull,
	}


func combat_clock() -> Dictionary:
	return {"shot": _shot_delay, "attack": _attack_delay} if phase == ACTIVE and kind == INTERCEPT else {}


func restore_combat_clock(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if phase != ACTIVE or kind != INTERCEPT:
		return value.is_empty()
	if value.size() != 2 or not _number(value.get("shot"), 0.0, PLAYER_DELAY) or not _number(value.get("attack"), 0.0, DEFENCE_DELAY):
		return false
	_shot_delay = float(value.shot)
	_attack_delay = float(value.attack)
	return true


func restore(value: Variant, fronts: RefCounted, progress: RefCounted = null) -> bool:
	if not value is Dictionary or value.size() != SAVE_FIELDS.size() or not value.has_all(SAVE_FIELDS):
		return false
	if not value.phase is String or value.phase not in [IDLE, ACTIVE, ESCORTED, SUCCEEDED, FAILED]:
		return false
	if value.phase == IDLE:
		if not _valid_idle(value):
			return false
	elif not _valid_order(value, fronts, progress):
		return false
	phase = value.phase
	system = int(value.system)
	convoy_id = value.id
	kind = value.kind
	faction = int(value.faction)
	target_faction = int(value.target_faction)
	port = int(value.port)
	deadline = float(value.deadline)
	formation_time = float(value.formation_time)
	enemy_hull = float(value.enemy_hull)
	_clear_effects()
	return true


func _escort(sim: RefCounted, contact: Dictionary, delta: float) -> Dictionary:
	var in_formation: bool = not contact.is_empty() and sim.ship.hull > 1.0 \
		and sim.position.distance_squared_to(contact.position) <= ESCORT_RANGE * ESCORT_RANGE \
		and sim.velocity.distance_squared_to(contact.velocity) <= ESCORT_SPEED * ESCORT_SPEED \
		and sim.combat_line_clear(sim.position, contact.position)
	formation_time = minf(formation_time + delta, ESCORT_SECONDS) if in_formation else 0.0
	if formation_time < ESCORT_SECONDS:
		return {}
	if not sim.factions.escort_convoy(system, convoy_id, faction):
		return _fail()
	phase = ESCORTED
	return {"event": "convoy_order_escorted", "message": "Конвой под защитой. Оплата после доставки груза."}


func _defend(sim: RefCounted, contact: Dictionary, delta: float) -> Dictionary:
	if contact.is_empty() or sim.ship.hull <= 1.0 or sim.position.distance_squared_to(contact.position) > DEFENCE_RANGE * DEFENCE_RANGE:
		_attack_delay = DEFENCE_DELAY
		return {}
	_attack_delay -= delta
	if _attack_delay > 0.0:
		return {}
	if not sim.combat_line_clear(contact.position, sim.position):
		_attack_delay = 0.25
		return {}
	_attack_delay = DEFENCE_DELAY
	_enemy_flash = BEAM_DURATION
	var source: Vector3 = contact.position
	_enemy_beam = {"from": source, "to": sim.position, "hostile": true}
	return {"event": "convoy_order_enemy_hit", "message": "Охрана конвоя повредила корпус.", "damage": 7.0, "source": source}


func _aim_status(sim: RefCounted, contact: Dictionary, range_bonus: float) -> Dictionary:
	if contact.is_empty():
		return {"ok": false, "reason": "Конвой завершил рейс", "distance": -1.0}
	var offset: Vector3 = contact.position - sim.position
	var distance := offset.length()
	var effective_range := BEAM_RANGE + (maxf(0.0, range_bonus) if is_finite(range_bonus) else 0.0)
	var reason := ""
	if sim.ship.hull <= 1.0:
		reason = "Восстановите корпус в порту"
	elif distance > effective_range:
		reason = "Сблизьтесь до %d м" % int(effective_range)
	elif distance <= 0.01 or sim.forward().dot(offset / distance) < AIM_COSINE:
		reason = "Наведите нос на конвой"
	elif not sim.combat_line_clear(sim.position, contact.position):
		reason = "Цель закрыта препятствием"
	elif _shot_delay > 0.0:
		reason = "Перезарядка"
	return {"ok": reason.is_empty(), "reason": "Можно стрелять" if reason.is_empty() else reason, "distance": distance}


func _is_active() -> bool:
	return phase == ACTIVE or phase == ESCORTED


func _pay(message: String) -> Dictionary:
	phase = SUCCEEDED
	var credits := _reward(kind)
	return {"event": "convoy_order_paid", "message": "%s Награда %d кр." % [message, credits], "credits": credits}


func _fail() -> Dictionary:
	phase = FAILED
	formation_time = 0.0
	_clear_effects()
	return {"event": "convoy_order_failed", "message": "Рейс конвоя завершён. Заказ закрыт."}


func _clear_effects() -> void:
	_shot_delay = 0.0
	_attack_delay = DEFENCE_DELAY
	_player_flash = 0.0
	_enemy_flash = 0.0
	_player_beam.clear()
	_enemy_beam.clear()


static func _airborne(sim: RefCounted) -> bool:
	return sim.docked < 0 and not sim.landed and sim.jump_seconds_left <= 0.0


static func _reward(order_kind: String) -> int:
	if order_kind == ESCORT:
		return ESCORT_REWARD
	return INTERCEPT_REWARD if order_kind == INTERCEPT else 0


static func _convoy_name(side: int) -> String:
	return Traffic.CONVOY_NAMES[side] if side >= 0 and side < Traffic.CONVOY_NAMES.size() else ""


static func _valid_idle(value: Dictionary) -> bool:
	for field in ["system", "faction", "target_faction", "port"]:
		if not _integer(value[field], -1, -1):
			return false
	return value.id is String and value.id.is_empty() and value.kind is String and value.kind.is_empty() \
		and _number(value.deadline, 0.0, 0.0) and _number(value.formation_time, 0.0, 0.0) \
		and _number(value.enemy_hull, MAX_HULL, MAX_HULL)


static func _valid_order(value: Dictionary, fronts: RefCounted, progress: RefCounted) -> bool:
	if not _integer(value.system, 0, Catalog.SYSTEM_COUNT - 1) or int(value.system) not in Factions.FRONTIER_SYSTEMS:
		return false
	if not value.kind is String or value.kind not in [ESCORT, INTERCEPT]:
		return false
	if not _integer(value.faction, 0, Factions.FACTIONS.size() - 1) or not _integer(value.target_faction, 0, Factions.FACTIONS.size() - 1):
		return false
	if (value.kind == ESCORT) != (value.faction == value.target_faction):
		return false
	if not _integer(value.port, 0, Catalog.DESTINATION_COUNT - 1) or not Catalog.is_port(int(value.port)):
		return false
	var port_system := Catalog.system_of_site(int(value.port))
	if port_system < Catalog.CORE_SYSTEM_COUNT and Factions.CORE_OWNERS[port_system] != value.faction:
		return false
	if progress != null and (not progress.commissioned(int(value.system)) or
			(port_system >= Catalog.CORE_SYSTEM_COUNT and not progress.commissioned(port_system))):
		return false
	if not _matches_id(value.id, int(value.system), int(value.target_faction)):
		return false
	if not _number(value.deadline, Factions.FOUNDING_GRACE, Factions.MAX_ORBIT_CLOCK + Factions.ROUND_SECONDS):
		return false
	if not _number(value.formation_time, 0.0, ESCORT_SECONDS) or not _number(value.enemy_hull, 0.0, MAX_HULL):
		return false
	if not _valid_progress(value):
		return false
	var convoy: Dictionary = fronts.convoy(int(value.system), value.id)
	if convoy.is_empty():
		return value.phase == SUCCEEDED or value.phase == FAILED
	if not is_equal_approx(float(convoy.due_at), float(value.deadline)):
		return false
	match value.phase:
		ACTIVE:
			return convoy.stage == "en_route" and convoy.assistance == "none"
		ESCORTED:
			return convoy.stage == "en_route" and convoy.assistance == ESCORT
		SUCCEEDED:
			var outcome := "delivered" if value.kind == ESCORT else "intercepted"
			return convoy.stage == outcome and convoy.assistance == value.kind
		FAILED:
			return convoy.stage != "en_route" or convoy.assistance != "none"
	return false


static func _valid_progress(value: Dictionary) -> bool:
	if value.kind == ESCORT:
		if value.enemy_hull != MAX_HULL:
			return false
		if value.phase in [ESCORTED, SUCCEEDED]:
			return value.formation_time == ESCORT_SECONDS
		return value.formation_time < ESCORT_SECONDS and (value.phase != FAILED or value.formation_time == 0.0)
	if value.phase == ESCORTED or value.formation_time != 0.0:
		return false
	if value.phase == SUCCEEDED:
		return value.enemy_hull == 0.0
	return value.enemy_hull > 0.0 and fmod(MAX_HULL - float(value.enemy_hull), PLAYER_DAMAGE) == 0.0


static func _matches_id(value: Variant, sector: int, side: int) -> bool:
	if not value is String or value.length() > 32:
		return false
	var id: String = value
	var parts := id.split("-")
	if parts.size() != 5 or not parts[2].is_valid_int() or not parts[3].is_valid_int():
		return false
	var round := parts[3].to_int()
	var campaign := parts[2].to_int()
	return round >= 0 and round < Factions.CAMPAIGN_ROUNDS and campaign > 0 and campaign <= Factions.MAX_CAMPAIGNS \
		and id == "front-%d-%d-%d-%d" % [sector, campaign, round, side]


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and floorf(float(value)) == value
