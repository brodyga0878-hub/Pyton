extends Control
## Projects catalog coordinates and displays discovered systems, routes and source density.

const Sector := preload("res://scripts/sector_catalog.gd")
const TEXT := Color("e8f4fa")
const MUTED := Color("a5bac7")
const MINT := Color("9debd7")
const AMBER := Color("f3c991")
const BORDER := Color("365561")
const FIELD := Color("081622")
const MIN_ZOOM := 1.0
const MAX_ZOOM := 32.0
const DENSITY_SIDE := 224
const DENSITY_RADIUS := 6
const MAX_LABELS := 24

static var _density_by_projection: Dictionary[bool, Dictionary] = {}

var current := -1
var planned := -1
var candidate := -1
var jump_capacity := 0.0
var jump_tariff: Callable
var planned_path: Array[int] = []
var preview_path: Array[int] = []
var contested: Array[int] = []
var _known_systems: Array[int] = []
var _systems: Array[int] = []
var _points: Dictionary[int, Vector2] = {}
var _center := Vector2.ZERO
var _extent := Vector2.ONE
var _view_offset := Vector2.ZERO
var _zoom := MIN_ZOOM
var _focus := -1
var _atlas := false
var _label_boxes: Array[Rect2] = []
var _detailed := false
var _elevation := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)


func set_systems(known: Array[int], systems: Array[int], focus: int, elevation: bool) -> void:
	_known_systems = known
	_systems = systems
	var context_changed := focus != _focus or elevation != _elevation
	_focus = focus
	_detailed = focus >= 0
	_elevation = elevation
	_points.clear()
	for id in _systems:
		_points[id] = _project(id, _elevation)
	var former_center := _center
	_update_frame()
	if context_changed:
		reset_view()
	elif _zoom != MIN_ZOOM or not _view_offset.is_zero_approx():
		_view_offset = _bound_offset(_view_offset + former_center - _center)
	queue_redraw()


func set_atlas(active: bool) -> void:
	if _atlas == active:
		return
	_atlas = active
	_update_frame()
	reset_view()


func reset_view() -> void:
	_view_offset = Vector2.ZERO
	_zoom = MIN_ZOOM
	queue_redraw()


func pan_by(pixel_delta: Vector2) -> void:
	if not pixel_delta.is_finite():
		return
	_view_offset = _bound_offset(_view_offset - pixel_delta / _pixels_per_light_year())
	queue_redraw()


func zoom_by(factor: float, anchor: Vector2) -> void:
	if not is_finite(factor) or factor <= 0.0 or not anchor.is_finite():
		return
	var before := _pixels_per_light_year()
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var after := _pixels_per_light_year()
	_view_offset = _bound_offset(_view_offset + (anchor - size * 0.5) * (1.0 / before - 1.0 / after))
	queue_redraw()


func can_zoom_in() -> bool:
	return _zoom < MAX_ZOOM


func can_zoom_out() -> bool:
	return _zoom > MIN_ZOOM


func _bound_offset(offset: Vector2) -> Vector2:
	var visible_span := size / _pixels_per_light_year()
	var limit := (_extent * 0.5 - visible_span * 0.18).max(Vector2.ZERO)
	return offset.clamp(-limit, limit)


func _update_frame() -> void:
	if _atlas:
		var density: Dictionary = _density_layer(_elevation)
		var frame: Rect2 = density.bounds
		_center = frame.get_center()
		_extent = frame.size
		return
	if _systems.is_empty():
		_center = Vector2.ZERO
		_extent = Vector2.ONE
		return
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for id in _systems:
		var point := _points[id]
		low = low.min(point)
		high = high.max(point)
	if _detailed:
		var corner := Vector2(Sector.sector_coordinates(_focus)) * Sector.SECTOR_SIZE
		low.x = corner.x
		high.x = corner.x + Sector.SECTOR_SIZE
		if _elevation:
			low.y = minf(low.y, -Sector.SECTOR_SIZE * 0.5)
			high.y = maxf(high.y, Sector.SECTOR_SIZE * 0.5)
		else:
			low.y = corner.y
			high.y = corner.y + Sector.SECTOR_SIZE
	_center = (low + high) * 0.5
	_extent = (high - low).max(Vector2.ONE)


func marker_position(id: int) -> Vector2:
	return _project_to_view(_points.get(id, _center))


func _project_to_view(point: Vector2) -> Vector2:
	return size * 0.5 + (point - _center - _view_offset) * _pixels_per_light_year()


static func _project(id: int, elevation: bool) -> Vector2:
	var coordinates := Sector.system_position3(id)
	return Vector2(coordinates.x, -coordinates.z if elevation else coordinates.y)


func system_at(point: Vector2) -> int:
	if size.x < 64.0 or size.y < 64.0:
		return -1
	var bounds := Rect2(Vector2.ZERO, size)
	if not bounds.has_point(point):
		return -1
	var visible_bounds := bounds.grow(-3.0)
	var nearest := -1
	var pick_radius := 40.0 if _detailed else 30.0
	var limit := pick_radius * pick_radius
	for id in _systems:
		var marker := marker_position(id)
		if not visible_bounds.has_point(marker):
			continue
		var distance := marker.distance_squared_to(point)
		if distance <= limit:
			nearest = id
			limit = distance
	return nearest


func _pixels_per_light_year() -> float:
	var span := (size - Vector2(126, 126)).max(Vector2.ONE)
	return minf(span.x / _extent.x, span.y / _extent.y) * _zoom


func _draw() -> void:
	if size.x < 64.0 or size.y < 64.0:
		return
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, FIELD)
	if _atlas:
		_draw_density(bounds)
	elif _detailed:
		_draw_sector_border()
	var active := _route_path(planned_path, planned)
	var preview_fallback := -1 if not active.is_empty() and candidate == active[-1] else candidate
	var preview := _route_path(preview_path, preview_fallback)
	if preview == active:
		preview = []
	_draw_routes(active, preview)
	var visible_ids: Array[int] = []
	var visible_bounds := bounds.grow(-3.0)
	for id: int in _systems:
		if not visible_bounds.has_point(marker_position(id)):
			continue
		visible_ids.append(id)
		_draw_marker(id, active)
	_label_boxes.clear()
	# Route endpoints receive space before optional intermediate captions.
	var order := visible_ids.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool:
		return _label_priority(a, active, preview) < _label_priority(b, active, preview))
	for id: int in order:
		if (_atlas or _zoom < 1.5 and order.size() > 40) and _label_priority(id, active, preview) >= 4:
			continue
		_draw_label(id, active, preview, visible_ids)
		if _label_boxes.size() >= MAX_LABELS:
			break
	draw_rect(bounds.grow(-0.5), BORDER, false, 1.0)
	_draw_scale()
	draw_string(ThemeDB.fallback_font, size - Vector2(81, 17), "X →  Z ↑" if _elevation else "X →  Y ↓",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, MUTED)


func _draw_density(bounds: Rect2) -> void:
	var density := _density_layer(_elevation)
	var world: Rect2 = density.bounds
	var texture: ImageTexture = density.texture
	var viewport_rect := Rect2(_project_to_view(world.position), world.size * _pixels_per_light_year())
	var clipped := viewport_rect.intersection(bounds)
	if not clipped.has_area():
		return
	var factor := texture.get_size() / viewport_rect.size
	var source := Rect2((clipped.position - viewport_rect.position) * factor, clipped.size * factor)
	draw_texture_rect_region(texture, clipped, source)


static func _density_layer(elevation: bool) -> Dictionary:
	if _density_by_projection.has(elevation):
		return _density_by_projection[elevation]
	var positions := PackedVector2Array()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for id in range(Sector.SYSTEM_COUNT):
		var position := _project(id, elevation)
		positions.append(position)
		low = low.min(position)
		high = high.max(position)
	var span := (high - low).max(Vector2.ONE)
	var world := Rect2(low, span).grow(maxf(8.0, maxf(span.x, span.y) * 0.06))
	var densities := PackedFloat32Array()
	densities.resize(DENSITY_SIDE * DENSITY_SIDE)
	# A short kernel around each real system makes the distribution readable at atlas scale.
	for position in positions:
		var center := Vector2i((position - world.position) * (DENSITY_SIDE - 1) / world.size)
		for py in range(maxi(center.y - DENSITY_RADIUS, 0), mini(center.y + DENSITY_RADIUS + 1, DENSITY_SIDE)):
			for px in range(maxi(center.x - DENSITY_RADIUS, 0), mini(center.x + DENSITY_RADIUS + 1, DENSITY_SIDE)):
				var distance := Vector2i(px, py).distance_squared_to(center)
				var weight := maxf(0.0, 1.0 - distance / float(DENSITY_RADIUS * DENSITY_RADIUS))
				densities[py * DENSITY_SIDE + px] += weight * weight * weight
	var image := Image.create_empty(DENSITY_SIDE, DENSITY_SIDE, false, Image.FORMAT_RGBA8)
	for y in range(DENSITY_SIDE):
		for x in range(DENSITY_SIDE):
			var strength := 1.0 - exp(-densities[y * DENSITY_SIDE + x] * 0.24)
			var tint := Color("17546b").lerp(Color("69cfbf"), strength * strength)
			tint.a = strength * 0.82
			image.set_pixel(x, y, tint)
	var density := {"bounds": world, "texture": ImageTexture.create_from_image(image)}
	_density_by_projection[elevation] = density
	return density


func _draw_sector_border() -> void:
	var bounds := Rect2(Vector2.ZERO, size).grow(-1.0)
	var left_top := _project_to_view(_center - _extent * 0.5)
	var right_bottom := _project_to_view(_center + _extent * 0.5)
	var corners := PackedVector2Array([left_top, Vector2(right_bottom.x, left_top.y),
		right_bottom, Vector2(left_top.x, right_bottom.y)])
	for index in range(corners.size()):
		var edge := _clip_segment(corners[index], corners[(index + 1) % corners.size()], bounds)
		if edge.size() == 2:
			draw_line(edge[0], edge[1], Color(BORDER, 0.85), 1.0, true)


func _route_path(requested: Array[int], fallback: int) -> Array[int]:
	var path: Array[int] = requested.duplicate()
	if path.is_empty() and _known_systems.has(current) and _known_systems.has(fallback) and current != fallback:
		path = [current, fallback]
	if path.size() < 2 or path.size() > _known_systems.size() or path[0] != current:
		return []
	var visited: Array[int] = []
	for step in range(path.size()):
		var id := path[step]
		if not _known_systems.has(id) or visited.has(id):
			return []
		if step > 0 and not _leg_reachable(path[step - 1], id):
			return []
		visited.append(id)
	return path


func _has_edge(path: Array[int], a: int, b: int) -> bool:
	for step in range(1, path.size()):
		if (path[step - 1] == a and path[step] == b) or (path[step - 1] == b and path[step] == a):
			return true
	return false


func _draw_routes(active: Array[int], preview: Array[int]) -> void:
	if not _atlas and _systems.has(current) and (_detailed or _systems.size() <= 32):
		for id in _systems:
			if not _leg_reachable(current, id) or _has_edge(active, current, id) or _has_edge(preview, current, id):
				continue
			_draw_leg(current, id, Color("425e69"), 1.1, true, false)
	for step in range(1, active.size()):
		_draw_leg(active[step - 1], active[step], MINT, 2.6, false, true)
	for step in range(1, preview.size()):
		var shift := 4.0 if _has_edge(active, preview[step - 1], preview[step]) else 0.0
		_draw_leg(preview[step - 1], preview[step], AMBER, 1.8, true, true, shift)


func _leg_points(a: int, b: int, shift := 0.0) -> PackedVector2Array:
	if not _systems.has(a) or not _systems.has(b) or not _leg_reachable(a, b):
		return PackedVector2Array()
	var origin := marker_position(a)
	var end := marker_position(b)
	var distance := origin.distance_to(end)
	if distance <= 2.0:
		return PackedVector2Array()
	var direction := origin.direction_to(end)
	var offset := direction.orthogonal() * shift
	var clearance := minf(10.0, distance * 0.28)
	return PackedVector2Array([origin + direction * clearance + offset, end - direction * clearance + offset])


func _leg_reachable(a: int, b: int) -> bool:
	var units := int(jump_tariff.call(a, b)) if jump_tariff.is_valid() else 0
	return units > 0 and units <= jump_capacity


func _draw_leg(a: int, b: int, tint: Color, width: float, dashed: bool, arrow: bool, shift := 0.0) -> void:
	var points := _leg_points(a, b, shift)
	if points.is_empty():
		return
	var bounds := Rect2(Vector2.ZERO, size).grow(-3.0)
	var visible := _clip_segment(points[0], points[1], bounds)
	if visible.size() != 2 or visible[0].distance_squared_to(visible[1]) < 1.0:
		return
	if dashed:
		draw_dashed_line(visible[0], visible[1], tint, width, 7.0, true, true)
	else:
		draw_line(visible[0], visible[1], Color(tint, 0.12), width + 4.0, true)
		draw_line(visible[0], visible[1], tint, width, true)
	if arrow and bounds.grow(-8.0).has_point(points[1]):
		var direction := visible[0].direction_to(visible[1])
		var length := minf(10.0, visible[0].distance_to(visible[1]) * 0.45)
		var side := direction.orthogonal() * length * 0.52
		var base := points[1] - direction * length
		draw_colored_polygon(PackedVector2Array([points[1], base + side, base - side]), tint)


static func _clip_segment(start: Vector2, end: Vector2, bounds: Rect2) -> PackedVector2Array:
	var delta := end - start
	var enter := 0.0
	var exit := 1.0
	for axis in range(2):
		if is_zero_approx(delta[axis]):
			if start[axis] < bounds.position[axis] or start[axis] > bounds.end[axis]:
				return PackedVector2Array()
			continue
		var first := (bounds.position[axis] - start[axis]) / delta[axis]
		var last := (bounds.end[axis] - start[axis]) / delta[axis]
		enter = maxf(enter, minf(first, last))
		exit = minf(exit, maxf(first, last))
		if enter > exit:
			return PackedVector2Array()
	return PackedVector2Array([start + delta * enter, start + delta * exit])


func _draw_marker(id: int, active: Array[int]) -> void:
	var system := Sector.system(id)
	var point := marker_position(id)
	var bounds := Rect2(Vector2.ZERO, size)
	var accent: Color = system.accent
	var scale := _marker_scale(id, active)
	if bounds.grow(-11.0 * scale).has_point(point):
		draw_circle(point, 10.0 * scale, Color(accent, 0.15), true, -1.0, true)
	var core := 4.8 * scale if bounds.grow(-6.0).has_point(point) else 2.0
	draw_circle(point, core, accent, true, -1.0, true)
	if scale >= 0.8:
		draw_circle(point, core * 0.42, accent.lerp(Color.WHITE, 0.65), true, -1.0, true)
	if contested.has(id) and bounds.grow(-20.0).has_point(point):
		var warning := point + Vector2(13, -12)
		draw_circle(warning, 6.0, FIELD, true, -1.0, true)
		draw_arc(warning, 5.0, 0.0, TAU, 18, AMBER, 1.3, true)
		draw_line(warning - Vector2(0, 3), warning, AMBER, 1.3, true)
		draw_circle(warning + Vector2(0, 2.3), 0.8, AMBER, true, -1.0, true)
	if id == current and bounds.grow(-28.0).has_point(point):
		var pointer := PackedVector2Array([point + Vector2(0, -16), point + Vector2(5, -24), point + Vector2(-5, -24)])
		draw_colored_polygon(pointer, MINT)
	if id == candidate and bounds.grow(-17.0).has_point(point):
		var color := MINT if active.has(id) or id == current else AMBER
		for index in range(4):
			var angle := index * TAU * 0.25 + 0.17
			draw_arc(point, 14.0, angle, angle + 1.17, 12, color, 1.7, true)
	if active.size() > 2 and (id == active[1] or id == active.back()) and bounds.grow(-13.0).has_point(point):
		draw_arc(point, 11.0, 0.0, TAU, 32, MINT, 1.3, true)


func _marker_scale(id: int, active: Array[int]) -> float:
	if id == current or id == candidate or active.has(id):
		return 1.0
	if _atlas:
		return 0.40
	return 0.85 if _detailed else 0.65


func _label_priority(id: int, active: Array[int], preview: Array[int]) -> int:
	if id == current:
		return 0
	if not active.is_empty() and id == active.back():
		return 1
	if active.size() > 2 and id == active[1]:
		return 2
	if id == candidate or (not preview.is_empty() and id == preview.back()):
		return 3
	return 4 + id


func _draw_label(id: int, active: Array[int], preview: Array[int], visible_ids: Array[int]) -> void:
	var point := marker_position(id)
	var annotation := ""
	var tint := MINT
	if id == current:
		annotation = "Корабль"
	elif not active.is_empty() and id == active.back():
		annotation = "Цель маршрута"
	elif active.size() > 2 and id == active[1]:
		annotation = "Следующий"
	elif active.has(id):
		annotation = "Переход %d" % active.find(id)
	elif not preview.is_empty() and id == preview.back():
		annotation = "Просмотр"
		tint = AMBER
	elif id == candidate:
		annotation = "Выбрано"
		tint = AMBER
	var font := ThemeDB.fallback_font
	var name: String = Sector.system(id).name
	for sizes: Vector2i in [Vector2i(19, 13), Vector2i(16, 12)]:
		var name_width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes.x).x
		var note_width := font.get_string_size(annotation, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes.y).x
		var extent := Vector2(maxf(name_width, note_width) + 16.0, sizes.x + sizes.y + 11.0 if not annotation.is_empty() else sizes.x + 8.0)
		for at: Vector2 in [point + Vector2(-extent.x * 0.5, 18.0), point - Vector2(extent.x * 0.5, 28.0 + extent.y), point + Vector2(20.0, -extent.y * 0.5), point - Vector2(20.0 + extent.x, extent.y * 0.5)]:
			var box := Rect2(at.clamp(Vector2.ONE * 8.0, (size - extent - Vector2.ONE * 8.0).max(Vector2.ONE * 8.0)), extent)
			var blocked := not Rect2(Vector2.ZERO, size).encloses(box)
			for other in _label_boxes:
				if box.grow(3.0).intersects(other):
					blocked = true
					break
			if blocked:
				continue
			for system_id in visible_ids:
				var scale := _marker_scale(system_id, active)
				if box.intersects(Rect2(marker_position(system_id) - Vector2(11.0, 16.0) * scale, Vector2(22.0, 27.0) * scale)):
					blocked = true
					break
			if blocked:
				continue
			_label_boxes.append(box)
			draw_rect(box, FIELD)
			draw_string(font, box.position + Vector2((extent.x - name_width) * 0.5, sizes.x + 1.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes.x, TEXT)
			if not annotation.is_empty():
				draw_string(font, box.position + Vector2((extent.x - note_width) * 0.5, sizes.x + sizes.y + 5.0), annotation, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes.y, tint)
			return


func _draw_scale() -> void:
	var pixels := _pixels_per_light_year()
	var limit := minf(100.0, size.x * 0.20) / pixels
	var magnitude := pow(10.0, floorf(log(limit) / log(10.0)))
	var units := magnitude
	if magnitude * 5.0 <= limit:
		units *= 5.0
	elif magnitude * 2.0 <= limit:
		units *= 2.0
	var left := Vector2(22, 27)
	var right := left + Vector2(pixels * units, 0)
	draw_line(left, right, MUTED, 1.0, true)
	draw_line(left - Vector2(0, 4), left + Vector2(0, 4), MUTED, 1.0, true)
	draw_line(right - Vector2(0, 4), right + Vector2(0, 4), MUTED, 1.0, true)
	var label := ("%.3f" % units).rstrip("0").rstrip(".").replace(".", ",")
	draw_string(ThemeDB.fallback_font, right + Vector2(10, 5), "%s св. л." % label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, MUTED)
