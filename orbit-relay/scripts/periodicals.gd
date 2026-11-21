extends RefCounted
## Independent paid releases assembled from editorial features and dated events.

const Calendar := preload("res://scripts/mission_calendar.gd")
const SectorNews := preload("res://scripts/sector_news.gd")
const TERM_DAYS := 7
const ARCHIVE_LIMIT := 12
const MAX_EVENT_ARTICLES := 8
const FEEDS := {
	"navigation": {"name": "Вахтенный журнал", "label": "Вахта", "days": 1, "hour": 0, "price": 24, "topic": "story_"},
	"frontier": {"name": "Рубежный вестник", "label": "Рубежи", "days": 2, "hour": 12, "price": 32, "topic": "expedition_"},
	"dispatch": {"name": "Сводка патрулей", "label": "Патрули", "days": 7, "hour": 18, "price": 42, "topic": "war_"},
}
const EDITORIALS := {
	"navigation": [
		["Скорость в кадре цели", "Перед заходом сравнивайте своё движение со скоростью причала. Корабль может почти стоять в системе отсчёта станции, хотя оба объекта движутся по орбите."],
		["Точка касания на Лазури", "Наземные площадки вращаются вместе с Лазурью. При ручном спуске держите створ и гасите движение относительно грунта уже на последнем участке."],
		["Обратный рейс с новым грузом", "Перед прыжком сверьте массу в карточке маршрута. Доставка тяжёлой партии может сократить дальность обратного маршрута, особенно при попутной закупке."],
	],
	"frontier": [
		["Замеры до снабжения", "Разведка открывает данные о телах. Экипажам полезно сохранить наблюдения, пока корабль уже держит скорость относительно цели."],
		["Цена рабочего причала", "Грузовой маршрут появляется после ввода причала. До сдачи работ рассчитывайте на снабжение из уже действующих портов."],
		["Рейс за припасами", "Сравнивайте спрос порта со складом у отправителя. В системе с форпостом разные грузы нужны на разных стадиях работ."],
	],
	"dispatch": [
		["Гражданский груз в спорном секторе", "Рейс в действующий порт иногда проходит через район перехвата конвоя. Проверяйте обстановку в журнале перед ручным заходом."],
		["Смена контроля и портовые правила", "После смены власти проверяйте правила ввоза до стыковки. В торговом досье видны действующие квоты и товары, которые могут изъять."],
		["Дорога назад после боя", "Действующий боевой контакт мешает зарядить прыжковый привод. Сначала выйдите из зоны боя, затем погасите скорость в безопасной точке."],
	],
}

var _paid_until: Dictionary[String, float] = {}


func publications(epoch: float, credits: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id: String in FEEDS:
		rows.append(status(id, epoch, credits))
	return rows


func status(id: String, epoch: float, credits: int) -> Dictionary:
	if not FEEDS.has(id):
		return {}
	var feed: Dictionary = FEEDS[id]
	var until: float = _paid_until.get(id, 0.0)
	var next := _epoch(feed, _index(feed, epoch) + 1)
	var active := until > epoch
	var reason := ""
	if active:
		reason = "Подписка уже действует."
	elif credits < int(feed.price):
		reason = "Недостаточно средств для подписки."
	elif epoch + TERM_DAYS * Calendar.SECONDS_PER_DAY > Calendar.MAX_EPOCH:
		reason = "Срок подписки выходит за пределы календаря."
	return {"id": id, "name": feed.name, "label": feed.label, "days": feed.days, "price": feed.price,
		"term_days": TERM_DAYS, "active": active, "until": until,
		"next": next if next <= Calendar.MAX_EPOCH else -1.0, "can_subscribe": reason.is_empty(), "reason": reason}


func subscribe(id: String, epoch: float, credits: int) -> Dictionary:
	var offer := status(id, epoch, credits)
	if offer.is_empty() or not bool(offer.can_subscribe):
		return {"ok": false, "reason": offer.get("reason", "Издание недоступно.")}
	var until := epoch + TERM_DAYS * Calendar.SECONDS_PER_DAY
	_paid_until[id] = until
	return {"ok": true, "price": offer.price, "name": offer.name, "until": until}


func archive(id: String, epoch: float, limit: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not FEEDS.has(id) or not _has_access(id, epoch):
		return rows
	var feed: Dictionary = FEEDS[id]
	var latest := _index(feed, epoch)
	for index in range(latest, maxi(-1, latest - clampi(limit, 0, ARCHIVE_LIMIT)), -1):
		rows.append(_edition_row(id, feed, index))
	return rows


func issue(id: String, at: float, epoch: float, systems: Array[int], news: SectorNews) -> Dictionary:
	if not FEEDS.has(id) or not is_finite(at) or at < 0.0 or at > epoch or not _has_access(id, epoch):
		return {}
	var feed: Dictionary = FEEDS[id]
	var index := _index(feed, at)
	if at != _epoch(feed, index) or _index(feed, epoch) - index >= ARCHIVE_LIMIT:
		return {}
	var result := _edition_row(id, feed, index)
	var before := _epoch(feed, index - 1) if index > 0 else -1.0
	var articles := news.periodical_articles(str(feed.topic), systems, before, at)
	articles.resize(mini(MAX_EVENT_ARTICLES, articles.size()))
	var editorial: Array = EDITORIALS[id][index % EDITORIALS[id].size()]
	articles.push_front({"id": result.id, "title": editorial[0], "text": editorial[1], "source": result.title,
		"related": "", "related_available": false, "action": ""})
	result.articles = articles
	return result


func snapshot() -> Dictionary:
	return _paid_until.duplicate()


func restore(raw: Variant, epoch: float) -> bool:
	if not raw is Dictionary or raw.size() > FEEDS.size():
		return false
	var restored: Dictionary[String, float] = {}
	var cap := minf(Calendar.MAX_EPOCH, epoch + TERM_DAYS * Calendar.SECONDS_PER_DAY)
	for key: Variant in raw:
		var value: Variant = raw[key]
		if not key is String or not FEEDS.has(key) or not (value is int or value is float):
			return false
		if not is_finite(float(value)) or float(value) < TERM_DAYS * Calendar.SECONDS_PER_DAY or float(value) > cap:
			return false
		restored[key] = float(value)
	_paid_until = restored
	return true


func _has_access(id: String, epoch: float) -> bool:
	return _paid_until.get(id, 0.0) > epoch


static func _index(feed: Dictionary, epoch: float) -> int:
	return Calendar.release_index(epoch, int(feed.days), int(feed.hour) * 3600)


static func _epoch(feed: Dictionary, index: int) -> float:
	return Calendar.release_epoch(index, int(feed.days), int(feed.hour) * 3600)


static func _edition_row(id: String, feed: Dictionary, index: int) -> Dictionary:
	var at := _epoch(feed, index)
	return {"id": "%s-%d" % [id, index], "title": feed.name, "stamp": Calendar.stamp(at),
		"published_at": at, "headline": EDITORIALS[id][index % EDITORIALS[id].size()][0]}
