extends RefCounted
## A contract credits the recorded exposure after returning to its issuing dock.

const Catalog := preload("res://scripts/sector_catalog.gd")

const CAMERA_PRICE := 85
const WINDOW := 720.0
const MIN_SCORE := 55
const MIN_DISTANCE := 30.0
const MAX_DISTANCE := 340.0
const MAX_SPEED := 40.0
const MAX_ANGLE := 18.0
const VELAR_PORT := 10
const ORDERS := {
	0: {"target": VELAR_PORT, "reward": 230},
	VELAR_PORT: {"target": 1, "reward": 265},
}

var fitted := false
var _issuer := -1
var _started := 0.0
var _photo := {}
var _completed: Array[int] = []


func deadline() -> float:
	return _started + WINDOW if _issuer >= 0 else INF


func status(sim: RefCounted) -> Dictionary:
	var at: int = sim.docked
	var active := _issuer >= 0
	var offer: Dictionary = ORDERS.get(_issuer if active else at, {})
	var target := int(offer.get("target", -1))
	var exposure := _measure(sim, target) if active else {"ok": false, "reason": "Сначала возьмите заказ."}
	var at_port: bool = sim.station_services_available()
	var score := int(_photo.get("score", 0))
	return {
		"fitted": fitted, "cost": CAMERA_PRICE, "active": active, "issuer": _issuer,
		"issuer_name": str(Catalog.site(_issuer).get("name", "")), "target": target,
		"target_name": str(Catalog.site(target).get("name", "")), "available": not offer.is_empty(),
		"completed": at in _completed, "score": score, "minimum_score": MIN_SCORE,
		"remaining": maxf(0.0, deadline() - sim.orbit_time) if active else 0.0,
		"reward": int(offer.get("reward", 0)) + maxi(0, score - MIN_SCORE) * 2,
		"can_buy": at_port and not fitted and sim.credits >= CAMERA_PRICE,
		"can_accept": at_port and fitted and not active and ORDERS.has(at) and at not in _completed,
		"can_photo": exposure.ok, "photo_hint": exposure.reason,
		"can_plot": active, "can_report": at_port and active and at == _issuer and score >= MIN_SCORE,
		"can_cancel": at_port and active and at == _issuer,
	}


func action(sim: RefCounted, command: String) -> Dictionary:
	var state := status(sim)
	match command:
		"buy":
			if state.can_buy:
				fitted = true
				return _result("recon_camera_installed", "Камера установлена. Списано %d кр." % CAMERA_PRICE, -CAMERA_PRICE)
		"accept":
			if state.can_accept:
				_issuer = sim.docked
				_started = sim.orbit_time
				return _result("recon_accepted", "Заказ принят. Сделайте снимок цели и вернитесь в порт выдачи.")
		"photo":
			var exposure := _measure(sim, int(state.target))
			if not exposure.ok:
				return _result("recon_denied", exposure.reason)
			var score := _score(exposure.distance, exposure.angle, exposure.speed)
			if score > int(state.score):
				_photo = {"at": sim.orbit_time, "distance": exposure.distance, "angle": exposure.angle,
					"speed": exposure.speed, "score": score}
			return _result("recon_captured", "Снимок сделан. Качество %d из 100. Лучший результат %d." % [score, maxi(score, int(state.score))])
		"report":
			if state.can_report and sim.credits <= 1000000000 - int(state.reward):
				_completed.append(_issuer)
				_completed.sort()
				_clear_order()
				return _result("recon_paid", "Материалы проверены. Получено %d кр." % int(state.reward), int(state.reward))
		"cancel":
			if state.can_cancel:
				_clear_order()
				return _result("recon_cancelled", "Заказ отменён. Снимок больше не числится в заказе.")
	return _result("recon_denied", "Команда недоступна в текущем состоянии рейса.")


func advance(epoch: float) -> Dictionary:
	if _issuer < 0 or epoch < deadline():
		return {}
	_clear_order()
	return _result("recon_expired", "Срок задания на съёмку истёк. Заказ можно взять заново.")


func course() -> int:
	if not ORDERS.has(_issuer):
		return -1
	return _issuer if int(_photo.get("score", 0)) >= MIN_SCORE else int(ORDERS[_issuer].target)


func snapshot() -> Dictionary:
	return {"fitted": fitted, "issuer": _issuer, "started": _started,
		"photo": _photo.duplicate(), "completed": _completed.duplicate()}


func restore(raw: Variant, epoch: float) -> bool:
	if not raw is Dictionary or raw.size() != 5 or not raw.get("fitted") is bool:
		return false
	if not _number(raw.get("issuer"), -1, Catalog.DESTINATION_COUNT - 1) or floorf(raw.issuer) != raw.issuer:
		return false
	if not _number(raw.get("started"), 0.0, epoch) or not raw.get("photo") is Dictionary or not raw.get("completed") is Array:
		return false
	var issuer := int(raw.issuer)
	var started := float(raw.started)
	if issuer == -1:
		if started != 0.0 or not raw.photo.is_empty():
			return false
	elif not ORDERS.has(issuer) or not raw.fitted or epoch >= started + WINDOW or not _valid_photo(raw.photo, started, epoch):
		return false
	var completed: Array[int] = []
	for entry: Variant in raw.completed:
		if not _number(entry, 0, Catalog.DESTINATION_COUNT - 1) or floorf(entry) != entry:
			return false
		if not ORDERS.has(int(entry)) or int(entry) == issuer or (not completed.is_empty() and int(entry) <= completed[-1]):
			return false
		completed.append(int(entry))
	if not completed.is_empty() and not raw.fitted:
		return false
	fitted = raw.fitted
	_issuer = issuer
	_started = started
	_photo = raw.photo.duplicate()
	_completed = completed
	return true


func _measure(sim: RefCounted, target: int) -> Dictionary:
	if not fitted or _issuer < 0 or target < 0:
		return {"ok": false, "reason": "Нет камеры или активного задания."}
	if sim.orbit_time >= deadline():
		return {"ok": false, "reason": "Срок съёмки истёк."}
	if sim.docked >= 0 or sim.landed or sim.jump_seconds_left > 0.0:
		return {"ok": false, "reason": "Съёмка доступна после выхода из дока, взлёта или завершения прыжка."}
	if Catalog.system_of_site(target) != sim.system_id:
		return {"ok": false, "reason": "Сначала войдите в систему цели."}
	var offset: Vector3 = sim.target_position(target) - sim.position
	var radius := float(Catalog.site(target).radius)
	var range_to_surface := offset.length() - radius
	if range_to_surface < MIN_DISTANCE or range_to_surface > MAX_DISTANCE:
		return {"ok": false, "reason": "Для снимка держитесь в 30–340 м от поверхности цели."}
	var sight: Vector3 = sim.attitude() * Vector3.FORWARD
	var angle := rad_to_deg(sight.angle_to(offset))
	if angle > MAX_ANGLE:
		return {"ok": false, "reason": "Наведите нос на цель. Допустимое отклонение до 18°."}
	var speed: float = sim.speed_relative_to(target)
	if speed > MAX_SPEED:
		return {"ok": false, "reason": "Снизьте скорость относительно цели до 40 м/с."}
	var image_edge: Vector3 = sim.target_position(target) - offset.normalized() * (radius + 8.0)
	if not sim.combat_line_clear(sim.position, image_edge):
		return {"ok": false, "reason": "Цель закрыта препятствием."}
	return {"ok": true, "reason": "Съёмка доступна. Точный ракурс и малая скорость повышают качество.",
		"distance": range_to_surface, "angle": angle, "speed": speed}


func _clear_order() -> void:
	_issuer = -1
	_started = 0.0
	_photo.clear()


static func _valid_photo(photo: Dictionary, start: float, epoch: float) -> bool:
	if photo.is_empty():
		return true
	if photo.size() != 5 or not _number(photo.get("at"), start, epoch):
		return false
	if not _number(photo.get("distance"), MIN_DISTANCE, MAX_DISTANCE) or not _number(photo.get("angle"), 0.0, MAX_ANGLE):
		return false
	if not _number(photo.get("speed"), 0.0, MAX_SPEED) or not _number(photo.get("score"), 1, 100):
		return false
	return photo.score == _score(float(photo.distance), float(photo.angle), float(photo.speed))


static func _score(distance: float, angle: float, speed: float) -> int:
	var distance_penalty := inverse_lerp(MIN_DISTANCE, MAX_DISTANCE, distance) * 30.0
	return roundi(100.0 - distance_penalty - angle * 35.0 / MAX_ANGLE - speed * 25.0 / MAX_SPEED)


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


static func _result(event: String, message: String, credits := 0) -> Dictionary:
	return {"ok": event != "recon_denied", "event": event, "message": message, "credits": credits}
