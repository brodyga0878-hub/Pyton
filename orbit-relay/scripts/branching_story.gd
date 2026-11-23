extends RefCounted
## Branching courier campaign. Both routes end with a field comparison and a handover.

const TITLE := "Слепая поправка"
const BRIEFING_PORTS := [0, 3]
const ENTRY_SCAN := 8
const AUDIT_BODY := 7
const AUDIT_PORT := 3
const KEY_PORT := 10
const MIRROR_PORT := 11
const REGISTRY_VERIFICATION_SITE := 12
const MIRROR_VERIFICATION_SITE := 18
const MIRROR_FINAL_PORT := 17
const MAX_EPOCH := 3155760000.0
const FIELDS := ["entry", "branch", "briefed_at", "chosen_at", "key_at", "settled_at"]
const EMPTY_FINALE := {"verified_at": -1.0, "finished_at": -1.0}

const BRIEF := "brief"
const REGISTRY := "registry"
const MIRROR := "mirror"
const COLLECT_KEY := "collect_key"
const SUBMIT := "submit"
const VERIFY := "verify"
const FINALE := "finale"

const BRANCHES := {
	REGISTRY: {
		"name": "Официальная проверка",
		"detail": "Измерить орбиту Сланца и передать замер аудиторам на Перевале. Они объявят маршрут закрытым до перекалибровки.",
		"credits": 640, "trust": {0: 4, 1: -1},
		"ending": "Аудит принят. Содружество Маяков закрыло опасный коридор до перекалибровки.",
		"verification_site": REGISTRY_VERIFICATION_SITE, "final_port": KEY_PORT, "final_credits": 580, "final_trust": {0: 2, 1: 2},
		"verification_objective": "У закрытого коридора скопились суда. Сядьте на Лазурь, запишите наблюдение в атлас и сравните замер с поправкой аудиторов.",
		"handover_objective": "Передайте проверенный замер диспетчерам Створа. По нему две стороны смогут согласовать безопасное открытие коридора.",
		"conclusion": "Слепая поправка устранена. Створ и Маяки сверили замеры, открыли коридор и договорились хранить обе копии журнала.",
	},
	MIRROR: {
		"name": "Независимый ретранслятор",
		"detail": "Забрать ключ на Створе и открыть резервный маршрут через Гранитный причал. Лига опубликует поправку без согласования.",
		"credits": 820, "trust": {0: -2, 1: 4},
		"ending": "Поправка опубликована. Веларская лига ведёт пилотов по резервному маршруту.",
		"verification_site": MIRROR_VERIFICATION_SITE, "final_port": MIRROR_FINAL_PORT, "final_credits": 720, "final_trust": {0: 1, 1: 3},
		"verification_objective": "Резервный маршрут требует независимой сверки. Сядьте на Рубец, запишите наблюдение в атлас и сопоставьте замер с данными ретранслятора.",
		"handover_objective": "Передайте проверенный замер диспетчерам Свода. Они решат, закреплять ли резервный маршрут в открытом реестре.",
		"conclusion": "Слепая поправка раскрыта. Свод принял независимый замер и закрепил резервный маршрут в открытом реестре.",
	},
}

var _entry := ""
var _branch := ""
var _briefed_at := -1.0
var _chosen_at := -1.0
var _key_at := -1.0
var _settled_at := -1.0
var _verified_at := -1.0
var _finished_at := -1.0


func status(port: int, deliveries: int, surveyed_sites: Array, landed_site := -1) -> Dictionary:
	var view := {
		"title": TITLE, "stage": "locked", "entry": _entry, "branch": _branch,
		"target": -1, "objective": "", "actions": [], "can_follow": false,
	}
	if _finished_at >= 0.0:
		view.stage = "complete"
		view.objective = BRANCHES[_branch].conclusion
	elif _settled_at >= 0.0:
		var final_leg: Dictionary = BRANCHES[_branch]
		if _verified_at < 0.0:
			var site := int(final_leg.verification_site)
			var ready := landed_site == site and site in surveyed_sites
			_set_objective(view, "verify", final_leg.verification_objective, site, site if ready else -1,
				[_action(VERIFY, "Сверить замер")])
		else:
			_set_objective(view, "finale", final_leg.handover_objective, int(final_leg.final_port), port,
				[_action(FINALE, "Передать проверенный замер")])
	elif _briefed_at < 0.0:
		if _entry_source(deliveries, surveyed_sites).is_empty():
			view.objective = "Завершите доставку или запишите в атлас наблюдение кометы «Дымка»."
		else:
			_set_objective(view, "offer", "В порту получена заявка о расхождении маячных координат.",
				port if port in BRIEFING_PORTS else AUDIT_PORT, port,
				[_action(BRIEF, "Выслушать диспетчера")])
	elif _branch.is_empty():
		_set_objective(view, "choice", "Поправка маяков ведёт суда к опасному сближению со Сланцем. Как передать предупреждение?",
			port if port in BRIEFING_PORTS else AUDIT_PORT, port,
			[_action(REGISTRY, BRANCHES[REGISTRY].name, BRANCHES[REGISTRY].detail),
			_action(MIRROR, BRANCHES[MIRROR].name, BRANCHES[MIRROR].detail)])
	elif _branch == REGISTRY and AUDIT_BODY not in surveyed_sites:
		_set_objective(view, "observe", "Запишите в атлас наблюдение Сланца у границы коридора.", AUDIT_BODY, port)
	elif _branch == REGISTRY:
		_set_objective(view, "report", "Передайте наблюдение аудиторам на Перевале.", AUDIT_PORT, port,
			[_action(SUBMIT, "Подать официальный отчёт")])
	elif _key_at < 0.0:
		_set_objective(view, "key", "Заберите у техника Створа ключ от независимого ретранслятора.", KEY_PORT, port,
			[_action(COLLECT_KEY, "Взять ключ")])
	else:
		_set_objective(view, "publish", "Опубликуйте поправку на Гранитном причале.", MIRROR_PORT, port,
			[_action(SUBMIT, "Открыть резервный маршрут")])
	return view


func perform(action: String, port: int, deliveries: int, surveyed_sites: Array, now: float, landed_site := -1) -> Dictionary:
	var last_opening := maxf(maxf(_briefed_at, _chosen_at), maxf(_key_at, _settled_at))
	var last_receipt := maxf(last_opening, maxf(_verified_at, _finished_at))
	if not _valid_epoch(now, MAX_EPOCH) or now < last_receipt:
		return {}
	var view := status(port, deliveries, surveyed_sites, landed_site)
	for option: Dictionary in view.actions:
		if option.id == action:
			return _apply_action(action, deliveries, surveyed_sites, now)
	return {}


func trust_for(faction: int) -> int:
	if _settled_at < 0.0:
		return 0
	var path: Dictionary = BRANCHES[_branch]
	return int(path.trust.get(faction, 0)) + (int(path.final_trust.get(faction, 0)) if _finished_at >= 0.0 else 0)


func reward_for(action: String) -> int:
	if _branch.is_empty():
		return 0
	match action:
		SUBMIT:
			return int(BRANCHES[_branch].credits)
		FINALE:
			return int(BRANCHES[_branch].final_credits)
	return 0


func snapshot() -> Dictionary:
	return {
		"entry": _entry, "branch": _branch, "briefed_at": _briefed_at,
		"chosen_at": _chosen_at, "key_at": _key_at, "settled_at": _settled_at,
	}


func finale_snapshot() -> Dictionary:
	return {"verified_at": _verified_at, "finished_at": _finished_at}


func restore(value: Variant, epoch: float, finale: Variant = EMPTY_FINALE) -> bool:
	if not _valid_epoch(epoch, MAX_EPOCH) or not value is Dictionary or value.size() != FIELDS.size() or not value.has_all(FIELDS):
		return false
	if not finale is Dictionary or finale.size() != EMPTY_FINALE.size() or not finale.has_all(EMPTY_FINALE.keys()):
		return false
	if not value.entry is String or value.entry not in ["", "freight", "survey"]:
		return false
	if not value.branch is String or (not value.branch.is_empty() and not BRANCHES.has(value.branch)):
		return false
	for field: String in FIELDS.slice(2):
		if not _valid_receipt(value[field], epoch):
			return false
	for field: String in EMPTY_FINALE:
		if not _valid_receipt(finale[field], epoch):
			return false
	var briefed := float(value.briefed_at)
	var chosen := float(value.chosen_at)
	var key := float(value.key_at)
	var settled := float(value.settled_at)
	var verified := float(finale.verified_at)
	var finished := float(finale.finished_at)
	if (briefed < 0.0) != value.entry.is_empty() or (chosen < 0.0) != value.branch.is_empty():
		return false
	if chosen >= 0.0 and (briefed < 0.0 or chosen < briefed):
		return false
	if key >= 0.0 and (value.branch != MIRROR or key < chosen):
		return false
	if settled >= 0.0 and (chosen < 0.0 or settled < chosen or (value.branch == MIRROR and (key < 0.0 or settled < key))):
		return false
	if verified >= 0.0 and (settled < 0.0 or verified < settled):
		return false
	if finished >= 0.0 and (verified < 0.0 or finished < verified):
		return false
	_entry = value.entry
	_branch = value.branch
	_briefed_at = briefed
	_chosen_at = chosen
	_key_at = key
	_settled_at = settled
	_verified_at = verified
	_finished_at = finished
	return true


func _apply_action(action: String, deliveries: int, surveyed_sites: Array, now: float) -> Dictionary:
	var message := ""
	var credits := 0
	var trust := {}
	match action:
		BRIEF:
			_entry = _entry_source(deliveries, surveyed_sites)
			_briefed_at = now
			message = "Диспетчер передал расчёт опасного сближения. Выберите, кому сообщить о сбое."
		REGISTRY, MIRROR:
			_branch = action
			_chosen_at = now
			message = "Выбран план «%s»." % BRANCHES[_branch].name
		COLLECT_KEY:
			_key_at = now
			message = "Ключ от ретранслятора сохранён в судовом журнале."
		SUBMIT:
			_settled_at = now
			var ending: Dictionary = BRANCHES[_branch]
			credits = reward_for(action)
			trust = ending.trust.duplicate()
			message = "%s Начислено %d кр." % [ending.ending, credits]
		VERIFY:
			_verified_at = now
			message = "Контрольный замер подтверждён. Передайте его диспетчерам."
		FINALE:
			_finished_at = now
			var ending: Dictionary = BRANCHES[_branch]
			credits = reward_for(action)
			trust = ending.final_trust.duplicate()
			message = "%s Начислено %d кр." % [ending.conclusion, credits]
	return {"action": action, "message": message, "credits": credits, "trust": trust}


static func _entry_source(deliveries: int, surveyed_sites: Array) -> String:
	if deliveries > 0:
		return "freight"
	return "survey" if ENTRY_SCAN in surveyed_sites else ""


static func _set_objective(view: Dictionary, stage: String, objective: String, target: int, port: int,
		actions: Array = []) -> void:
	view.stage = stage
	view.target = target
	view.objective = objective
	view.can_follow = target != port
	if target == port:
		view.actions = actions


static func _action(id: String, name: String, detail := "") -> Dictionary:
	return {"id": id, "name": name, "detail": detail}


static func _valid_receipt(value: Variant, upper: float) -> bool:
	return value == -1.0 or _valid_epoch(value, upper)


static func _valid_epoch(value: Variant, upper: float, lower := 0.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= lower and value <= upper
