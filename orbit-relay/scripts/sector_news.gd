extends RefCounted
## Local dispatches use the mission calendar. The saved records describe dated
## events, while editions and the archive are derived without advancing time.

const Calendar = preload("res://scripts/mission_calendar.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const MINUTE := 60.0
const DAY := Calendar.SECONDS_PER_DAY
const START_OFFSET := Calendar.START_DAY_OFFSET
const MAX_REPORTS := 96
const MAX_ARCHIVE := 32
const MAX_TEXT := 480
const MAX_KEY := 96
const FIELDS := ["id", "kind", "system", "at", "published_at", "text", "related", "action"]
const HEADLINES := {
	"expedition_accepted": "Открыта программа разведки",
	"expedition_report": "Разведчики передали данные о системе",
	"expedition_complete": "Открытие станции",
	"war_declared": "Спор о контроле над системой",
	"war_round": "Сводка о ходе кампании",
	"war_convoy_delivered": "Снабжение дошло до фронта",
	"war_convoy_intercepted": "Конвой перехвачен",
	"war_captured": "Контроль над системой перешёл к другой фракции",
	"war_repulsed": "Наступление остановлено",
	"story_brief": "Диспетчеры проверяют навигационные данные",
	"story_choice": "Началась проверка маячной поправки",
	"story_registry": "Опасный коридор закрыт",
	"story_mirror": "Работает резервный маршрут",
}

var _reports := {}


func record(id: String, kind: String, system: int, at: float, report: String, related := "", action := "") -> bool:
	if _reports.has(id) or not _valid_fields(id, kind, system, at, report, related, action):
		return false
	# An edition already issued with an unavailable reference keeps its date.
	for published_report: Dictionary in _reports.values():
		if published_report.related == id:
			return false
	var source: Dictionary = _reports.get(related, {})
	if not source.is_empty() and float(source.at) > at:
		return false
	var published := _release_time(at, source)
	_reports[id] = {"id": id, "kind": kind, "system": system, "at": at,
		"published_at": published, "text": report, "related": related, "action": action}
	if _reports.size() > MAX_REPORTS:
		_reports.erase(_oldest_report())
	return _reports.has(id)


func archive(system: int, epoch: float, limit := 12) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not _valid_system(system) or not _valid_epoch(epoch) or limit < 1:
		return rows
	var count := mini(limit, MAX_ARCHIVE)
	var releases := {}
	var day := _midnight(epoch)
	for slot in range(count):
		var at := day - float(slot) * DAY
		if at < 0.0:
			releases[0.0] = []
			break
		releases[at] = []
		if at == 0.0:
			break
	for report: Dictionary in _reports.values():
		if not _visible_in(report, system, epoch):
			continue
		var published := float(report.published_at)
		if not releases.has(published):
			releases[published] = []
		releases[published].append(report)
	var times := releases.keys()
	times.sort()
	times.reverse()
	for index in range(mini(count, times.size())):
		var at := float(times[index])
		var reports: Array = releases[at]
		var summary := _edition_row(system, at)
		summary.report_count = reports.size() + (1 if _regular_release(at) else 0)
		summary.headline = _lead_headline(reports) if not reports.is_empty() else _dispatch_title(at)
		rows.append(summary)
	return rows


func edition(system: int, published_at: float, epoch: float) -> Dictionary:
	if not _valid_system(system) or not _valid_epoch(epoch) or not _valid_epoch(published_at) or published_at > epoch:
		return {}
	var articles: Array[Dictionary] = []
	for report: Dictionary in _reports.values():
		if float(report.published_at) == published_at and _visible_in(report, system, epoch):
			articles.append(_display_report(report, epoch))
	articles.sort_custom(_newest_first)
	if _regular_release(published_at):
		articles.append(_dispatch(system, published_at))
	if articles.is_empty():
		return {}
	var result := _edition_row(system, published_at)
	result.articles = articles
	result.report_count = articles.size()
	result.headline = articles[0].title
	return result


func article(id: String, epoch: float) -> Dictionary:
	if not _valid_epoch(epoch):
		return {}
	var report: Dictionary = _reports.get(id, {})
	return _display_report(report, epoch) if not report.is_empty() and float(report.published_at) <= epoch else {}


func periodical_articles(prefix: String, systems: Array[int], after: float, published_at: float) -> Array[Dictionary]:
	var articles: Array[Dictionary] = []
	for report: Dictionary in _reports.values():
		var published := float(report.published_at)
		var system := int(report.system)
		if published > after and published <= published_at and str(report.kind).begins_with(prefix) \
				and (system == -1 or system in systems):
			articles.append(_display_report(report, published_at))
	articles.sort_custom(_newest_first)
	return articles


func snapshot() -> Dictionary:
	return {"reports": _reports.values().duplicate(true)}


func restore(raw: Variant, epoch: float) -> bool:
	if not _valid_epoch(epoch) or not raw is Dictionary or raw.size() != 1:
		return false
	var reports: Variant = raw.get("reports")
	if not reports is Array or reports.size() > MAX_REPORTS:
		return false
	var loaded := {}
	for report: Variant in reports:
		if not report is Dictionary or report.size() != FIELDS.size() or not report.has_all(FIELDS):
			return false
		if not _valid_fields(report.id, report.kind, report.system, report.at, report.text, report.related, report.action):
			return false
		if loaded.has(report.id) or float(report.at) > epoch or not _number(report.published_at):
			return false
		var published := float(report.published_at)
		if published < _release_time(float(report.at), {}) or published > float(report.at) + (MAX_REPORTS + 1) * MINUTE:
			return false
		if fposmod(published + START_OFFSET, MINUTE) != 0.0:
			return false
		loaded[report.id] = {"id": report.id, "kind": report.kind, "system": int(report.system), "at": float(report.at),
			"published_at": published, "text": report.text, "related": report.related, "action": report.action}
	for report: Dictionary in loaded.values():
		var source: Dictionary = loaded.get(report.related, {})
		if not source.is_empty() and (source.at > report.at or _release_time(report.at, source) != report.published_at):
			return false
		if str(report.related).is_empty() and _release_time(report.at, {}) != report.published_at:
			return false
	_reports = loaded
	return true


func _display_report(report: Dictionary, epoch: float) -> Dictionary:
	var result := report.duplicate()
	var system := int(result.system)
	result.title = HEADLINES[result.kind]
	result.source = _desk(system)
	result.date = Calendar.date(result.published_at)
	result.stamp = Calendar.stamp(result.published_at)
	var source: Dictionary = _reports.get(result.related, {})
	result.related_available = not source.is_empty() and float(source.published_at) <= epoch
	result.related_at = float(source.published_at) if result.related_available else -1.0
	result.related_system = int(source.system) if result.related_available else -1
	return result


func _oldest_report() -> String:
	var id := ""
	var earliest := INF
	for report: Dictionary in _reports.values():
		if float(report.at) < earliest:
			id = report.id
			earliest = float(report.at)
	return id


static func _valid_fields(id: Variant, kind: Variant, system: Variant, at: Variant, report: Variant, related: Variant, action: Variant) -> bool:
	return _key(id) and kind is String and HEADLINES.has(kind) and _number(system) \
		and floorf(float(system)) == float(system) and _valid_system(int(system)) and _valid_epoch(at) \
		and _valid_text(report) \
		and related != id and _key(related, true) and _key(action, true)


static func _valid_text(report: Variant) -> bool:
	if not report is String or report.length() > MAX_TEXT or report.strip_edges().is_empty():
		return false
	for index in range(report.length()):
		var character: int = report.unicode_at(index)
		if (character < 32 and character != 10) or (character >= 127 and character <= 159):
			return false
	return true


static func _key(value: Variant, empty_allowed := false) -> bool:
	if not value is String or value.length() > MAX_KEY:
		return false
	if value.is_empty():
		return empty_allowed
	for index in range(value.length()):
		var character: int = value.unicode_at(index)
		if (character < 97 or character > 122) and (character < 48 or character > 57) and character != 45:
			return false
	return true


static func _valid_system(system: int) -> bool:
	return system >= -1 and system < Catalog.SYSTEM_COUNT


static func _valid_epoch(epoch: Variant) -> bool:
	return _number(epoch) and epoch >= 0.0 and epoch <= Calendar.MAX_EPOCH


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _visible_in(report: Dictionary, system: int, epoch: float) -> bool:
	return (int(report.system) == system or int(report.system) == -1) and float(report.published_at) <= epoch


static func _release_time(epoch: float, source: Dictionary) -> float:
	var minute := (floorf((epoch + START_OFFSET) / MINUTE) + 1.0) * MINUTE - START_OFFSET
	return minute if source.is_empty() else maxf(minute, float(source.published_at) + MINUTE)


static func _midnight(epoch: float) -> float:
	return maxf(0.0, floorf((epoch + START_OFFSET) / DAY) * DAY - START_OFFSET)


static func _regular_release(epoch: float) -> bool:
	return epoch == _midnight(epoch)


static func _edition_row(system: int, published_at: float) -> Dictionary:
	var issue := "%d-%d" % [system, int(published_at)]
	return {"id": issue, "system": system, "published_at": published_at,
		"title": _desk(system), "date": Calendar.date(published_at), "stamp": Calendar.stamp(published_at)}


static func _lead_headline(reports: Array) -> String:
	var latest: Dictionary = reports[0]
	for report: Dictionary in reports:
		if _newest_first(report, latest):
			latest = report
	return HEADLINES[latest.kind]


static func _newest_first(left: Dictionary, right: Dictionary) -> bool:
	return left.id < right.id if left.at == right.at else left.at > right.at


static func _desk(system: int) -> String:
	return "Секторная служба связи" if system < 0 else "Бюллетень системы «%s»" % Catalog.system(system).name


static func _dispatch_title(epoch: float) -> String:
	return "Открыта местная лента" if epoch == 0.0 else "Начался новый навигационный день"


static func _dispatch(system: int, epoch: float) -> Dictionary:
	var layout := _edition_row(system, epoch)
	return {"id": "dispatch-" + layout.id, "kind": "dispatch", "system": system, "at": epoch, "published_at": epoch,
		"title": _dispatch_title(epoch), "source": layout.title, "date": layout.date, "stamp": layout.stamp,
		"text": "Сводка местной службы связи. Сообщения о рейсах и работе станций выходят по мере поступления.",
		"related": "", "related_available": false, "related_at": -1.0, "related_system": -1, "action": ""}
