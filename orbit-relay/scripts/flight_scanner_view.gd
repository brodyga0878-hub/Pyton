extends Control

const Text := preload("res://scripts/flight_text.gd")

const GRID := Color("40626d")
const TEXT := Color("b8dadd")
const FRIENDLY := Color("79ddd1")
const HOSTILE := Color("ff978c")
const FOCUS := Color("ffd38a")

var _contacts: Array[Dictionary] = []
var _range := 1400.0
var _focus := ""
var _lock := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func read_contacts(contacts: Array[Dictionary], maximum: float, focus: String, lock: String) -> void:
	_contacts = contacts
	_range = maximum
	_focus = focus
	_lock = lock
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.37
	draw_circle(center, radius, Color("0c222d"), true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 50, GRID, 1.5, true)
	draw_arc(center, radius * 0.52, 0.0, TAU, 32, GRID, 1.0, true)
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), GRID, 1.0, true)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), GRID, 1.0, true)
	draw_circle(center, 3.0, TEXT, true, -1.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, center - Vector2(15, radius + 3), Text.text("SCANNER_NOSE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
	draw_string(font, center + Vector2(-20, radius + 15), Text.text("SCANNER_RANGE") % roundi(_range), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
	for contact: Dictionary in _contacts:
		var point := _contact_points(contact.relative, center, radius)
		var tint := HOSTILE if contact.attackable else FRIENDLY
		draw_line(point[0], point[1], tint, 1.4, true)
		draw_circle(point[0], 2.0, tint.darkened(0.45), true, -1.0, true)
		draw_circle(point[1], 3.3, tint, true, -1.0, true)
		if contact.id == _focus or contact.id == _lock:
			var edge := HOSTILE if contact.id == _lock else FOCUS
			draw_arc(point[1], 7.0, 0.0, TAU, 16, edge, 1.5, true)


func _contact_points(relative: Vector3, center: Vector2, radius: float) -> PackedVector2Array:
	var base := center + Vector2(relative.x, relative.z) * (radius / _range)
	var height := clampf(relative.y / _range, -1.0, 1.0) * radius * 0.46
	return PackedVector2Array([base, base - Vector2(0, height)])
