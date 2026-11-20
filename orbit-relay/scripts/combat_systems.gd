extends RefCounted
## Ship combat equipment, energy and the single active hostile projectile.

const Catalog = preload("res://scripts/sector_catalog.gd")

const PULSE := "pulse"
const FOCUS := "focus"
const ECM := "ecm"
const SHIELD_COST := 120
const FOCUS_COST := 170
const ECM_COST := 90
const REPAIR_COST := 60
const MAX_HEAT := 100.0
const COOLING_RATE := 16.0
const SHIELD_CAPACITY := 36.0
const SHIELD_RECHARGE_RATE := 6.0
const SHIELD_RECHARGE_DELAY := 3.0
const SALVOS_PER_PROJECTILE := 2
const PROJECTILE_SPEED := 64.0
const PROJECTILE_LIFETIME := 6.0
const PROJECTILE_COOLDOWN := 6.0
const ECM_RANGE := 140.0
const ECM_COOLDOWN := 3.0

const MAX_EPOCH := 3155760000.0
const CLOCK_TOLERANCE := 0.000002
const WORLD_LIMIT := 10000000.0
const PROFILES := {
	PULSE: {"range_bonus": 0.0, "heat": 17.0, "cooldown": 0.38, "name": "Каскад"},
	FOCUS: {"range_bonus": 80.0, "heat": 40.0, "cooldown": 0.60, "name": "Нить"},
}
const SAVE_FIELDS := ["heat", "shield", "shield_fitted", "ecm_fitted", "focus_owned", "weapon", "damaged",
	"fire_ready_at", "shield_recharge_at", "ecm_ready_at", "projectile_ready_at", "salvos", "projectile"]
const PROJECTILE_FIELDS := ["system", "position", "velocity", "expires"]

var weapon := PULSE
var focus_owned := false
var heat := 0.0
var shield_fitted := false
var shield := 0.0
var ecm_fitted := false
var damaged := ""

var _fire_ready_at := 0.0
var _shield_recharge_at := 0.0
var _ecm_ready_at := 0.0
var _projectile_ready_at := 0.0
var _salvos := 0
var _projectile: Dictionary = {}


func service_offer(action: String, credits: int) -> Dictionary:
	var cost := 0
	var installed := false
	match action:
		"combat_shield":
			cost = SHIELD_COST
			installed = shield_fitted
		"combat_focus":
			cost = FOCUS_COST
			installed = focus_owned
		"combat_ecm":
			cost = ECM_COST
			installed = ecm_fitted
		"combat_repair":
			cost = REPAIR_COST if not damaged.is_empty() else 0
	return {"allowed": cost > 0 and not installed and credits >= cost, "cost": cost, "installed": installed}


func buy(action: String, credits: int) -> int:
	var offer := service_offer(action, credits)
	if not offer.allowed:
		return 0
	match action:
		"combat_shield":
			shield_fitted = true
			shield = SHIELD_CAPACITY
		"combat_focus":
			focus_owned = true
			weapon = FOCUS
		"combat_ecm":
			ecm_fitted = true
		"combat_repair":
			damaged = ""
	return int(offer.cost)


func select_weapon(id: String) -> bool:
	if id == weapon or not PROFILES.has(id) or (id == FOCUS and (not focus_owned or damaged == FOCUS)):
		return false
	weapon = id
	return true


func profile() -> Dictionary:
	return PROFILES[weapon].duplicate()


func fire_denial(epoch: float) -> String:
	if not _valid_epoch(epoch):
		return "Вооружение недоступно."
	if weapon == damaged:
		return "Вооружение повреждено. Выберите «Каскад» или выполните ремонт."
	if heat + float(PROFILES[weapon].heat) > MAX_HEAT:
		return "Перегрев вооружения. Дождитесь охлаждения."
	if epoch + CLOCK_TOLERANCE < _fire_ready_at:
		return "Вооружение перезаряжается."
	return ""


func record_fire(epoch: float) -> void:
	if not fire_denial(epoch).is_empty():
		return
	var emitter: Dictionary = PROFILES[weapon]
	heat = minf(MAX_HEAT, heat + float(emitter.heat))
	_fire_ready_at = epoch + float(emitter.cooldown)


func advance_energy(previous: float, now: float) -> void:
	if not _valid_epoch(previous) or not _valid_epoch(now) or now <= previous:
		return
	heat = maxf(0.0, heat - (now - previous) * COOLING_RATE)
	if shield_fitted and shield < SHIELD_CAPACITY:
		var recharge_time := maxf(0.0, now - maxf(previous, _shield_recharge_at))
		shield = minf(SHIELD_CAPACITY, shield + recharge_time * SHIELD_RECHARGE_RATE)


func absorb_hit(amount: float, epoch: float) -> float:
	if not is_finite(amount) or amount <= 0.0:
		return 0.0
	if not shield_fitted or not _valid_epoch(epoch):
		return amount
	var absorbed := minf(shield, amount)
	shield -= absorbed
	_shield_recharge_at = epoch + SHIELD_RECHARGE_DELAY
	return amount - absorbed


func damage_module() -> String:
	if not damaged.is_empty():
		return ""
	if weapon == FOCUS or (focus_owned and not ecm_fitted):
		damaged = FOCUS
	elif ecm_fitted:
		damaged = ECM
	return damaged


func incoming_shot(source: Vector3, ship_position: Vector3, system: int, epoch: float) -> bool:
	if not _valid_epoch(epoch) or system < 0 or system >= Catalog.SYSTEM_COUNT:
		return false
	if not _valid_position(source) or not _valid_position(ship_position) or source.distance_squared_to(ship_position) <= 0.000001:
		return false
	_salvos = mini(SALVOS_PER_PROJECTILE, _salvos + 1)
	if _salvos < SALVOS_PER_PROJECTILE or not _projectile.is_empty() or epoch + CLOCK_TOLERANCE < _projectile_ready_at:
		return false
	_projectile = {
		"system": system, "position": source, "velocity": source.direction_to(ship_position) * PROJECTILE_SPEED,
		"expires": epoch + PROJECTILE_LIFETIME,
	}
	_projectile_ready_at = epoch + PROJECTILE_COOLDOWN
	reset_salvos()
	return true


func reset_salvos() -> void:
	_salvos = 0


func projectile_status() -> Dictionary:
	return _projectile.duplicate()


func advance_projectile(epoch: float, delta: float) -> Dictionary:
	if _projectile.is_empty() or not _valid_epoch(epoch) or not is_finite(delta) or delta <= 0.0:
		return {}
	var earliest := float(_projectile.expires) - PROJECTILE_LIFETIME
	var start_at := maxf(epoch - delta, earliest)
	var finish_at := minf(epoch, float(_projectile.expires))
	if start_at >= finish_at:
		if epoch >= float(_projectile.expires):
			clear_projectile()
		return {}
	var from: Vector3 = _projectile.position
	var to: Vector3 = from + _projectile.velocity * (finish_at - start_at)
	var system := int(_projectile.system)
	_projectile.position = to
	if epoch >= float(_projectile.expires):
		clear_projectile()
	return {"from": from, "to": to, "system": system}


func clear_projectile() -> void:
	_projectile.clear()


func ecm_denial(ship_position: Vector3, epoch: float) -> String:
	if not ecm_fitted:
		return "Модуль РЭБ не установлен."
	if damaged == ECM:
		return "Модуль РЭБ повреждён. Требуется ремонт."
	if not _valid_epoch(epoch) or not _valid_position(ship_position) or _projectile.is_empty() or epoch >= float(_projectile.expires):
		return "Нет ракеты для подавления."
	if epoch + CLOCK_TOLERANCE < _ecm_ready_at:
		return "Модуль РЭБ перезаряжается."
	if ship_position.distance_squared_to(_projectile.position) > ECM_RANGE * ECM_RANGE:
		return "Дождитесь сближения ракеты до 140 м."
	return ""


func use_ecm(ship_position: Vector3, epoch: float) -> bool:
	if not ecm_denial(ship_position, epoch).is_empty():
		return false
	clear_projectile()
	_ecm_ready_at = epoch + ECM_COOLDOWN
	return true


func snapshot() -> Dictionary:
	var encoded: Dictionary = {}
	if not _projectile.is_empty():
		var position: Vector3 = _projectile.position
		var velocity: Vector3 = _projectile.velocity
		encoded = {
			"system": _projectile.system, "position": [position.x, position.y, position.z],
			"velocity": [velocity.x, velocity.y, velocity.z], "expires": _projectile.expires,
		}
	return {
		"heat": heat, "shield": shield, "shield_fitted": shield_fitted, "ecm_fitted": ecm_fitted,
		"focus_owned": focus_owned, "weapon": weapon, "damaged": damaged, "fire_ready_at": _fire_ready_at,
		"shield_recharge_at": _shield_recharge_at, "ecm_ready_at": _ecm_ready_at,
		"projectile_ready_at": _projectile_ready_at, "salvos": _salvos, "projectile": encoded,
	}


func restore(raw: Variant, epoch: float, system: int) -> bool:
	if not _valid_epoch(epoch) or system < 0 or system >= Catalog.SYSTEM_COUNT:
		return false
	if not raw is Dictionary or raw.size() != SAVE_FIELDS.size() or not raw.has_all(SAVE_FIELDS):
		return false
	if not raw.shield_fitted is bool or not raw.ecm_fitted is bool or not raw.focus_owned is bool:
		return false
	if not raw.weapon is String or not PROFILES.has(raw.weapon) or (raw.weapon == FOCUS and not raw.focus_owned):
		return false
	if not raw.damaged is String or raw.damaged not in ["", FOCUS, ECM]:
		return false
	if (raw.damaged == FOCUS and not raw.focus_owned) or (raw.damaged == ECM and not raw.ecm_fitted):
		return false
	var shield_limit := SHIELD_CAPACITY if raw.shield_fitted else 0.0
	if not _number(raw.heat, 0.0, MAX_HEAT) or not _number(raw.shield, 0.0, shield_limit):
		return false
	var recharge_limit := SHIELD_RECHARGE_DELAY if raw.shield_fitted else 0.0
	var ecm_limit := ECM_COOLDOWN if raw.ecm_fitted else 0.0
	if not _timestamp(raw.fire_ready_at, epoch, float(PROFILES[FOCUS].cooldown)):
		return false
	if not _timestamp(raw.shield_recharge_at, epoch, recharge_limit) or not _timestamp(raw.ecm_ready_at, epoch, ecm_limit):
		return false
	if not _timestamp(raw.projectile_ready_at, epoch, PROJECTILE_COOLDOWN) or not _integer(raw.salvos, 0, SALVOS_PER_PROJECTILE):
		return false
	if not raw.projectile is Dictionary:
		return false
	var restored_projectile: Dictionary = {}
	if not raw.projectile.is_empty():
		restored_projectile = _restore_projectile(raw.projectile, epoch, system, float(raw.projectile_ready_at))
		if restored_projectile.is_empty():
			return false
	heat = float(raw.heat)
	shield = float(raw.shield)
	shield_fitted = raw.shield_fitted
	ecm_fitted = raw.ecm_fitted
	focus_owned = raw.focus_owned
	weapon = raw.weapon
	damaged = raw.damaged
	_fire_ready_at = float(raw.fire_ready_at)
	_shield_recharge_at = float(raw.shield_recharge_at)
	_ecm_ready_at = float(raw.ecm_ready_at)
	_projectile_ready_at = float(raw.projectile_ready_at)
	_salvos = int(raw.salvos)
	_projectile = restored_projectile
	return true


static func _restore_projectile(raw: Dictionary, epoch: float, system: int, ready_at: float) -> Dictionary:
	if raw.size() != PROJECTILE_FIELDS.size() or not raw.has_all(PROJECTILE_FIELDS):
		return {}
	if not _integer(raw.system, system, system) or not _number(raw.expires, epoch, epoch + PROJECTILE_LIFETIME + CLOCK_TOLERANCE):
		return {}
	var expires := float(raw.expires)
	if expires <= epoch or absf(expires - ready_at - (PROJECTILE_LIFETIME - PROJECTILE_COOLDOWN)) > CLOCK_TOLERANCE:
		return {}
	var position := _decode_vector(raw.position, WORLD_LIMIT + PROJECTILE_SPEED * PROJECTILE_LIFETIME)
	var velocity := _decode_vector(raw.velocity, PROJECTILE_SPEED + 0.001)
	if not position.is_finite() or not velocity.is_finite() or absf(velocity.length() - PROJECTILE_SPEED) > 0.001:
		return {}
	return {"system": system, "position": position, "velocity": velocity, "expires": expires}


static func _decode_vector(raw: Variant, limit: float) -> Vector3:
	if not raw is Array or raw.size() != 3:
		return Vector3.INF
	for value: Variant in raw:
		if not _number(value, -limit, limit):
			return Vector3.INF
	return Vector3(raw[0], raw[1], raw[2])


static func _valid_position(position: Vector3) -> bool:
	return position.is_finite() and maxf(absf(position.x), maxf(absf(position.y), absf(position.z))) <= WORLD_LIMIT


static func _valid_epoch(epoch: float) -> bool:
	return is_finite(epoch) and epoch >= 0.0 and epoch <= MAX_EPOCH


static func _timestamp(value: Variant, epoch: float, horizon: float) -> bool:
	return _number(value, 0.0, epoch + horizon + CLOCK_TOLERANCE) if horizon > 0.0 else _number(value, 0.0, 0.0)


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and value == floorf(float(value))
