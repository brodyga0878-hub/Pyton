extends RefCounted
## The port notice, registry clue, surface search and delivery share one flight record.

const Catalog := preload("res://scripts/sector_catalog.gd")
const Calendar := preload("res://scripts/mission_calendar.gd")
const TITLE := "Последний сеанс связи"
const SUBJECT := "Ива Севрина"
const ISSUER := 0
const REGISTRY := 10
const SEARCH_SITE := Catalog.TERRACE_ID
const REWARD := 460
const RESCUE_BONUS := 180
const TIME_LIMIT := 1800.0
const FIELDS := ["accepted_at", "clue_at", "evidence_at", "boarded_at", "closed_at", "expired"]

var _accepted_at := -1.0
var _clue_at := -1.0
var _evidence_at := -1.0
var _boarded_at := -1.0
var _closed_at := -1.0
var _expired := false


func status(sim: RefCounted) -> Dictionary:
	var port: int = sim.docked if sim.station_services_available() else -1
	var view := {"title": TITLE, "subject": SUBJECT, "stage": "locked", "detail": "", "action": "", "caption": "",
		"can_act": false, "show_pickup": false, "can_pickup": false, "aboard": occupied_seats() > 0, "route_site": -1,
		"deadline": _accepted_at + TIME_LIMIT if _accepted_at >= 0.0 else -1.0,
		"reward": REWARD, "bonus": RESCUE_BONUS, "paid": 0}
	if _closed_at >= 0.0 and not _expired:
		view.stage = "complete"
		view.paid = REWARD + (RESCUE_BONUS if _boarded_at >= 0.0 else 0)
		view.detail = "Ива передана диспетчеру вместе с записью приюта." if _boarded_at >= 0.0 else "Диспетчер получил координаты приюта и отправил дежурный бот."
		return view
	if _deadline_reached(sim.orbit_time):
		view.stage = "expired"
		view.detail = "Срок объявления истёк. Вознаграждение закрыто."
		if occupied_seats() > 0:
			_set_objective(view, "evacuate", "Срок выплаты истёк. Ива на борту. Передайте её дежурному любого действующего порта.",
				-1, "disembark", "Высадить инженера", port >= 0)
		return view
	if _accepted_at < 0.0:
		if sim.deliveries < 1:
			view.detail = "Завершите первую грузовую доставку, чтобы получить объявление на Маяке‑7."
		elif sim.orbit_time + TIME_LIMIT > Calendar.MAX_EPOCH:
			view.detail = "До конца игрового календаря осталось меньше срока поиска."
		else:
			_set_objective(view, "offer", "Маяк‑7 ищет инженера Иву Севрину. Она пропала после вылета из порта Створ.",
				ISSUER, "accept", "Взять поиск", port == ISSUER)
	elif _clue_at < 0.0:
		_set_objective(view, "clue", "Сверьте номер пропавшего катера в журнале вылетов порта Створ.",
			REGISTRY, "clue", "Проверить журнал вылетов", port == REGISTRY)
	elif _evidence_at < 0.0:
		_set_objective(view, "inspect", "В журнале указан посадочный маяк Террасы. Сядьте на Террасу и проверьте аварийный сигнал.",
			SEARCH_SITE, "inspect", "Проверить сигнал", sim.landed_site == SEARCH_SITE)
	else:
		var landed: bool = sim.landed_site == SEARCH_SITE
		var aboard := occupied_seats() > 0
		var detail := "Ива на борту. Доставьте её и запись приюта на Маяк‑7." if aboard else "Координаты приюта записаны. Передайте их диспетчеру Маяка‑7."
		_set_objective(view, "report", detail, ISSUER, "submit", "Сдать отчёт", port == ISSUER)
		view.show_pickup = landed and not aboard
		if view.show_pickup:
			var manifest: Dictionary = sim.passengers.status(sim.orbit_time)
			view.can_pickup = int(manifest.seats) < int(manifest.capacity)
	return view


func act(action: String, sim: RefCounted) -> Dictionary:
	var view := status(sim)
	var now: float = sim.orbit_time
	if action == "pickup" and view.can_pickup:
		_boarded_at = now
		return _result("missing_boarded", "Ива Севрина заняла одно место в пассажирской каюте.")
	if view.action != action or not view.can_act:
		return {}
	match action:
		"accept":
			_accepted_at = now
			return _result("missing_accepted", "Поиск принят. Первая зацепка в порту Створ (Велар).")
		"clue":
			_clue_at = now
			return _result("missing_clue", "Журнал Створа указывает на аварийный маяк на Террасе.")
		"inspect":
			_evidence_at = now
			return _result("missing_evidence", "Инженер найдена в приюте. Координаты записаны. Ива сможет лететь с вами, если есть место.")
		"submit":
			_closed_at = now
			var paid := REWARD + (RESCUE_BONUS if _boarded_at >= 0.0 else 0)
			return _result("missing_paid", "Поиск закрыт. Маяк‑7 выплатил %d кр." % paid, paid)
		"disembark":
			_expired = true
			_closed_at = now
			return _result("missing_disembarked", "Ива передана дежурному порта. Срок выплаты истёк.")
	return {}


func advance(epoch: float) -> Dictionary:
	if _expired or not _deadline_reached(epoch):
		return {}
	_expired = true
	return _result("missing_expired", "Срок поискового заказа истёк. Проверьте раздел «Поиск».")


func occupied_seats() -> int:
	return int(_boarded_at >= 0.0 and _closed_at < 0.0)


func next_deadline() -> float:
	if _accepted_at < 0.0 or _closed_at >= 0.0 or _expired:
		return INF
	return _accepted_at + TIME_LIMIT


func snapshot() -> Dictionary:
	return {"accepted_at": _accepted_at, "clue_at": _clue_at, "evidence_at": _evidence_at,
		"boarded_at": _boarded_at, "closed_at": _closed_at, "expired": _expired}


func restore(state: Variant, epoch: float, eligible: bool) -> bool:
	if not state is Dictionary or state.size() != FIELDS.size() or not state.has_all(FIELDS) or not state.expired is bool:
		return false
	for key: String in FIELDS.slice(0, -1):
		if not _history_time(state[key], epoch):
			return false
	var accepted := float(state.accepted_at)
	var clue := float(state.clue_at)
	var evidence := float(state.evidence_at)
	var boarded := float(state.boarded_at)
	var closed := float(state.closed_at)
	var expired: bool = state.expired
	var deadline := accepted + TIME_LIMIT
	if accepted < 0.0:
		if clue >= 0.0 or evidence >= 0.0 or boarded >= 0.0 or closed >= 0.0 or expired:
			return false
	else:
		if not eligible or deadline > Calendar.MAX_EPOCH or not _sequence(clue, accepted, deadline) \
				or not _sequence(evidence, clue, deadline) or not _sequence(boarded, evidence, deadline):
			return false
		if expired:
			if epoch < deadline or (closed >= 0.0 and (boarded < 0.0 or closed < deadline)):
				return false
		elif (closed < 0.0 and epoch >= deadline) or not _sequence(closed, maxf(evidence, boarded), deadline):
			return false
	_accepted_at = accepted
	_clue_at = clue
	_evidence_at = evidence
	_boarded_at = boarded
	_closed_at = closed
	_expired = expired
	return true


func _deadline_reached(epoch: float) -> bool:
	return _expired or epoch >= next_deadline()


static func _set_objective(view: Dictionary, stage: String, detail: String, site: int, action: String, caption: String, enabled: bool) -> void:
	view.stage = stage
	view.detail = detail
	view.route_site = site
	view.action = action
	view.caption = caption
	view.can_act = enabled


static func _result(event: String, message: String, credits := 0) -> Dictionary:
	return {"ok": true, "event": event, "message": message, "credits": credits}


static func _sequence(value: float, previous: float, deadline: float) -> bool:
	return value < 0.0 or (previous >= 0.0 and value >= previous and value < deadline)


static func _history_time(value: Variant, epoch: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and (value == -1.0 or (value >= 0.0 and value <= epoch))
