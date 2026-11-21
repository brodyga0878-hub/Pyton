extends HBoxContainer
## A journal page for dated issues from the pilot's current system.

signal story_requested()

const Sector := preload("res://scripts/sector_catalog.gd")
const ARCHIVE_LIMIT := 12
const PAGE_SIZE := 4
const INK := Color("edf7f9")
const MUTED := Color("adc0c9")
const MINT := Color("a4e9d6")
const BORDER := Color("355360")

var _sim: RefCounted
var _archive_system := -1
var _archive: Array[Dictionary] = []
var _archive_start := 0
var _edition_system := -1
var _published_at := -1.0
var _edition: Dictionary = {}
var _article_index := 0

var _archive_title: Label
var _issue_buttons: Array[Button] = []
var _archive_nav: HBoxContainer
var _newer: Button
var _older: Button
var _issue_stamp: Label
var _article_title: Label
var _article_source: Label
var _article_text: Label
var _article_nav: HBoxContainer
var _previous_article: Button
var _next_article: Button
var _article_number: Label
var _related: Button
var _story: Button
var _buttons: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var archive := _column(340.0, 0.68)
	_archive_title = _label(archive, 23, INK)
	for slot in range(PAGE_SIZE):
		var button := _button(archive, "")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 72.0
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.toggle_mode = true
		button.pressed.connect(_select_archive_slot.bind(slot))
		_issue_buttons.append(button)
	_archive_nav = _row(archive)
	_newer = _button(_archive_nav, "Новее")
	_newer.pressed.connect(_change_archive_page.bind(-PAGE_SIZE))
	_older = _button(_archive_nav, "Старее")
	_older.pressed.connect(_change_archive_page.bind(PAGE_SIZE))

	var article := _column(430.0, 1.32)
	_issue_stamp = _label(article, 17, MINT)
	_article_title = _label(article, 26, INK)
	_article_source = _label(article, 17, MUTED)
	_article_text = _label(article, 19, INK)
	_article_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_article_nav = _row(article)
	_previous_article = _button(_article_nav, "Предыдущая заметка")
	_previous_article.pressed.connect(_move_article.bind(-1))
	_article_number = _label(_article_nav, 16, MUTED)
	_article_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_next_article = _button(_article_nav, "Следующая заметка")
	_next_article.pressed.connect(_move_article.bind(1))
	var actions := _row(article)
	_related = _button(actions, "К предыдущему сообщению")
	_related.pressed.connect(_show_related)
	_story = _button(actions, "К сюжету")
	_story.pressed.connect(func() -> void: story_requested.emit())


func reset() -> void:
	_sim = null
	_archive_system = -1
	_archive_start = 0
	_edition_system = -1
	_published_at = -1.0
	_edition.clear()
	_article_index = 0


func refresh(sim: RefCounted) -> void:
	var system: int = sim.system_id
	if _sim != sim or _archive_system != system:
		reset()
	_sim = sim
	_archive_system = system
	_archive.assign(_sim.news_archive(system, ARCHIVE_LIMIT))
	_archive_title.text = "Архив системы «%s»" % Sector.system(system).name
	var last_page := floori(float(maxi(0, _archive.size() - 1)) / PAGE_SIZE) * PAGE_SIZE
	_archive_start = mini(_archive_start, last_page)
	if _published_at >= 0.0:
		_edition = _sim.news_edition(_edition_system, _published_at)
	if _edition.is_empty() and not _archive.is_empty():
		_archive_start = 0
		_open_edition(system, float(_archive[0].published_at))
	_render_archive()
	_render_edition()


func button_at(point: Vector2) -> Button:
	for button: Button in _buttons:
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			return button
	return null


func _render_archive() -> void:
	for slot in range(PAGE_SIZE):
		var button := _issue_buttons[slot]
		var index := _archive_start + slot
		button.visible = index < _archive.size()
		if not button.visible:
			continue
		var issue := _archive[index]
		button.text = "%s\n%s" % [issue.stamp, issue.headline]
		button.set_pressed_no_signal(_edition_system == _archive_system and float(issue.published_at) == _published_at)
	_archive_nav.visible = _archive.size() > PAGE_SIZE
	_newer.disabled = _archive_start == 0
	_older.disabled = _archive_start + PAGE_SIZE >= _archive.size()


func _render_edition() -> void:
	var articles: Array = _edition.get("articles", [])
	var has_article := not articles.is_empty()
	_issue_stamp.visible = has_article
	_article_source.visible = has_article
	_article_nav.visible = articles.size() > 1
	_related.hide()
	_story.hide()
	if not has_article:
		_article_title.text = "В этой системе ещё нет выпусков"
		_article_text.text = ""
		return
	_article_index = clampi(_article_index, 0, articles.size() - 1)
	var article: Dictionary = articles[_article_index]
	_issue_stamp.text = _edition.stamp
	_article_title.text = article.title
	_article_source.text = article.source
	_article_text.text = article.text
	_article_number.text = "%d из %d" % [_article_index + 1, articles.size()]
	_previous_article.disabled = _article_index == 0
	_next_article.disabled = _article_index == articles.size() - 1
	_related.visible = bool(article.related_available)
	_story.visible = article.action == "story"


func _select_archive_slot(slot: int) -> void:
	var index := _archive_start + slot
	if index >= _archive.size():
		return
	if _open_edition(_archive_system, float(_archive[index].published_at)):
		_render_archive()
		_render_edition()


func _change_archive_page(delta: int) -> void:
	var start := _archive_start + delta
	if start >= 0 and start < _archive.size():
		_archive_start = start
		_render_archive()


func _open_edition(system: int, published_at: float, article_id := "") -> bool:
	var edition: Dictionary = _sim.news_edition(system, published_at)
	if edition.is_empty():
		return false
	_edition_system = system
	_published_at = published_at
	_edition = edition
	_article_index = 0
	if not article_id.is_empty():
		var articles: Array = edition.articles
		for index in range(articles.size()):
			if articles[index].id == article_id:
				_article_index = index
				break
	return true


func _move_article(step: int) -> void:
	_article_index += step
	_render_edition()


func _show_related() -> void:
	var articles: Array = _edition.get("articles", [])
	if _sim == null or articles.is_empty():
		return
	var article: Dictionary = _sim.news_article(articles[_article_index].related)
	if article.is_empty():
		_related.hide()
		return
	var system := int(article.system)
	if _open_edition(system if system >= 0 else _archive_system, float(article.published_at), str(article.id)):
		_render_archive()
		_render_edition()


func _column(min_width: float, stretch: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = min_width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	panel.add_theme_stylebox_override("panel", _style(Color("101f2a"), BORDER, 14, 18))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column


static func _row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


static func _label(parent: Container, points: int, tint: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


func _button(parent: Container, caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 52.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", _style(Color("173a41"), Color("457783"), 8, 12))
	button.add_theme_stylebox_override("hover", _style(Color("205459"), MINT, 8, 12))
	button.add_theme_stylebox_override("pressed", _style(Color("224650"), MINT, 8, 12))
	button.add_theme_stylebox_override("disabled", _style(Color("15242e"), BORDER, 8, 12))
	parent.add_child(button)
	_buttons.append(button)
	return button


static func _style(fill: Color, border: Color, radius: int, padding: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding * 0.8
	box.content_margin_bottom = padding * 0.8
	return box
