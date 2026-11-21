extends Node3D

const BEAM_LIMIT := 4
const UNIT_BOX_CORNERS := [
	Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5),
	Vector3(0.5, 0.5, -0.5), Vector3(-0.5, 0.5, -0.5),
	Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5),
	Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5),
]
const BOX_FACES := [
	Vector4i(0, 1, 2, 3), Vector4i(4, 7, 6, 5), Vector4i(0, 3, 7, 4),
	Vector4i(1, 5, 6, 2), Vector4i(0, 4, 5, 1), Vector4i(3, 2, 6, 7),
]

var _ships: Dictionary[String, Node3D] = {}
var _pool: Dictionary[String, Array] = {"trader": [], "patrol": [], "raider": [], "convoy": [], "relay": []}
var _hulls: Dictionary[String, Array] = {}
var _trim: Array[MeshInstance3D] = []
var _beams: Array[Node3D] = []
var _beam_paints: Array[StandardMaterial3D] = []
var _metal: ShaderMaterial
var _light: StandardMaterial3D
var _visual_profile := 1


func set_visual_profile(profile: int) -> void:
	_visual_profile = clampi(profile, 0, 2)
	if _metal != null:
		_metal.set_shader_parameter("profile", _visual_profile)
	for detail: MeshInstance3D in _trim:
		detail.visible = _visual_profile > 0
	for beam: Node3D in _beams:
		beam.get_child(1).visible = _visual_profile > 0


func sync(contacts: Array, beams: Array) -> void:
	if _metal == null:
		_metal = _hull_finish()
		_light = _paint(Color.WHITE, true)
		_light.vertex_color_use_as_albedo = true
	var active: Dictionary[String, bool] = {}
	for contact: Dictionary in contacts:
		var id: String = contact.id
		var role: String = contact.role
		if id.is_empty() or not _pool.has(role):
			continue
		active[id] = true
		var actor: Node3D = _ships.get(id)
		if actor == null:
			actor = _acquire_ship(role)
			_ships[id] = actor
		actor.position = contact.position
		if role == "relay":
			actor.get_child(1).visible = float(contact.get("hull", 0.0)) > 0.0
		var course: Vector3 = contact.get("forward", contact.velocity)
		if course.length_squared() > 0.001:
			var direction := course.normalized()
			var up := Vector3.FORWARD if absf(direction.y) > 0.97 else Vector3.UP
			actor.basis = Basis.looking_at(direction, up)
	for id: String in _ships.keys():
		if active.has(id):
			continue
		var actor := _ships[id]
		actor.hide()
		_pool[actor.get_meta("role")].append(actor)
		_ships.erase(id)
	_sync_beams(beams)


func _acquire_ship(role: String) -> Node3D:
	var pool := _pool[role]
	if not pool.is_empty():
		var reused: Node3D = pool.pop_back()
		reused.basis = Basis.IDENTITY
		reused.show()
		return reused
	if not _hulls.has(role):
		_hulls[role] = _build_hull(role)
	var actor := Node3D.new()
	actor.set_meta("role", role)
	add_child(actor)
	var meshes := _hulls[role]
	_mesh(actor, meshes[0], _metal)
	_mesh(actor, meshes[1], _light)
	var detail := _mesh(actor, meshes[2], _metal)
	detail.visible = _visual_profile > 0
	_trim.append(detail)
	return actor


func _sync_beams(beams: Array) -> void:
	var count := mini(beams.size(), BEAM_LIMIT)
	while _beams.size() < count:
		_beams.append(_make_beam())
	for index in range(_beams.size()):
		var node := _beams[index]
		node.visible = index < count
		if not node.visible:
			continue
		var beam: Dictionary = beams[index]
		var start: Vector3 = beam.from
		var finish: Vector3 = beam.to
		var offset := finish - start
		var length := offset.length()
		if length <= 0.1:
			node.hide()
			continue
		var direction := offset / length
		var up := Vector3.FORWARD if absf(direction.y) > 0.97 else Vector3.UP
		node.position = (start + finish) * 0.5
		node.basis = Basis.looking_at(direction, up).scaled_local(Vector3(1.0, 1.0, length))
		var tint := 2 if beam.hostile else 0
		node.get_child(0).material_override = _beam_paints[tint]
		node.get_child(1).material_override = _beam_paints[tint + 1]


func _make_beam() -> Node3D:
	if _beam_paints.is_empty():
		_beam_paints = [
			_paint(Color("#b7fff4"), true), _beam_halo(Color(0.16, 0.91, 0.83, 0.33)),
			_paint(Color("#ffb391"), true), _beam_halo(Color(1.0, 0.27, 0.17, 0.36)),
		]
	var beam := Node3D.new()
	add_child(beam)
	for radius: float in [0.16, 0.31]:
		var tube := CylinderMesh.new()
		tube.top_radius = radius
		tube.bottom_radius = radius
		tube.height = 1.0
		tube.radial_segments = 6
		tube.rings = 1
		_mesh(beam, tube, _beam_paints[0]).rotation.x = PI * 0.5
	beam.get_child(1).visible = _visual_profile > 0
	return beam


func _build_hull(role: String) -> Array:
	var shell := SurfaceTool.new()
	var lamps := SurfaceTool.new()
	var trim := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	lamps.begin(Mesh.PRIMITIVE_TRIANGLES)
	trim.begin(Mesh.PRIMITIVE_TRIANGLES)
	match role:
		"trader": _trader(shell, lamps)
		"patrol": _patrol(shell, lamps)
		"raider": _raider(shell, lamps)
		"convoy": _convoy(shell, lamps)
		"relay": _relay(shell, lamps)
	_add_role_trim(trim, role)
	return [shell.commit(), lamps.commit(), trim.commit()]


func _hull_finish() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform int profile = 1;
varying vec3 finish_position;
varying vec3 paint_color;
void vertex() {
	finish_position = VERTEX;
	paint_color = COLOR.rgb;
}
float fine_line(float coordinate, float width) {
	float footprint = fwidth(coordinate);
	float pivot = abs(fract(coordinate) - 0.5);
	return (1.0 - smoothstep(width, width + footprint + 0.010, pivot))
		* (1.0 - smoothstep(0.12, 0.47, footprint));
}
void fragment() {
	vec3 p = finish_position;
	vec3 paint = paint_color;
	float roughness = 0.71;
	if (profile > 0) {
		float plating = sin(p.z * 2.8 + p.x * 0.69);
		float seams = max(fine_line(p.z * 0.63 + 0.21, 0.021), fine_line(abs(p.x) * 0.51 + p.y * 0.10, 0.014));
		paint *= 1.0 + plating * 0.058 - seams * 0.29;
		roughness = 0.63 + plating * 0.052 + seams * 0.093;
		if (profile == 2) {
			float brush = sin(p.z * 39.0 + sin(p.x * 11.0)) * (1.0 - smoothstep(0.23, 1.3, fwidth(p.z * 39.0)));
			float ribs = fine_line(abs(p.x) * 2.2 + p.z * 0.13, 0.016);
			paint *= 1.0 + brush * 0.051 + ribs * 0.039;
			roughness -= brush * 0.059;
		}
	}
	ALBEDO = paint;
	METALLIC = 0.24;
	ROUGHNESS = clamp(roughness, 0.47, 0.85);
}
"""
	var finish := ShaderMaterial.new()
	finish.shader = shader
	finish.set_shader_parameter("profile", _visual_profile)
	return finish


func _add_role_trim(tool: SurfaceTool, role: String) -> void:
	for side: float in [-1.0, 1.0]:
		match role:
			"trader":
				_box(tool, Vector3(side * 2.35, 0.63, 0.71), Vector3(1.48, 0.12, 4.38), Color("#765643"))
				for index in range(5):
					_box(tool, Vector3(side * 2.91, 0.74, -0.81 + index * 0.31), Vector3(0.10, 0.11, 0.17), Color("#efc194"))
			"patrol":
				_box(tool, Vector3(side * 3.74, 0.23, 1.66), Vector3(0.84, 0.12, 1.2), Color("#2b4e55"))
				_box(tool, Vector3(side * 2.13, 0.16, 1.08), Vector3(0.54, 0.11, 0.25), Color("#b8d2de"), side * 0.34)
			"raider":
				_box(tool, Vector3(side * 2.8, 0.19, 0.8), Vector3(1.14, 0.19, 1.84), Color("#943b34"), -side * 0.44)
				for index in range(3):
					_box(tool, Vector3(side * 2.64, 0.33, 0.09 + index * 0.52), Vector3(0.64, 0.07, 0.16), Color("#dc8a67"), -side * 0.44)
			"convoy":
				for position_z: float in [-3.3, 1.3]:
					_box(tool, Vector3(side * 3.15, 1.11, position_z), Vector3(2.1, 0.14, 0.20), Color("#f4bf6e"))
					_box(tool, Vector3(side * 4.46, 0.16, position_z), Vector3(0.13, 0.85, 2.35), Color("#603e27"))
			"relay":
				for slat: int in range(6):
					_box(tool, Vector3(side * (4.3 + slat * 1.29), 0.23, 0.0), Vector3(0.10, 0.08, 4.4), Color("4b8492"))


func _relay(shell: SurfaceTool, lamps: SurfaceTool) -> void:
	var frame := Color("9daaa9")
	_box(shell, Vector3.ZERO, Vector3(4.0, 3.2, 5.5), Color("627a7b"))
	_box(shell, Vector3(0, 4.9, 0), Vector3(0.45, 8.0, 0.42), frame)
	_box(shell, Vector3(0, 8.0, -1.15), Vector3(0.67, 0.40, 3.40), frame)
	_box(shell, Vector3(0, 0, 0), Vector3(25.0, 0.45, 0.57), frame)
	for side: float in [-1.0, 1.0]:
		_box(shell, Vector3(side * 8.30, 0.05, 0), Vector3(9.0, 0.36, 4.55), Color("264e7a"))
		_box(shell, Vector3(side * 12.75, 0.16, 0), Vector3(0.24, 0.65, 4.60), frame)
		_box(lamps, Vector3(side * 12.83, 0.52, 0.05), Vector3(0.42, 0.28, 0.40), Color("b0ffe4"))
	_box(lamps, Vector3(0, 9.1, 0), Vector3(0.67, 0.43, 0.56), Color("ffe583"))
	_box(lamps, Vector3(0, 0.65, -2.80), Vector3(2.14, 0.42, 0.14), Color("93e8d1"))


func _trader(shell: SurfaceTool, lamps: SurfaceTool) -> void:
	var ceramic := Color("#95a5ae")
	var hull := Color("#324d57")
	var crates := Color("#a86b44")
	var canopy := Color("#173c48")
	_sectioned(shell, [Vector3(0.75, 0.6, -5.7), Vector3(1.52, 1.1, -3.1), Vector3(1.68, 1.30, 4.7)], ceramic)
	_box(shell, Vector3(0, 1.02, -3.5), Vector3(1.50, 0.63, 1.50), canopy)
	for side: float in [-1.0, 1.0]:
		_box(shell, Vector3(side * 2.35, -0.15, 0.5), Vector3(2.2, 1.4, 6.65), crates)
		_box(shell, Vector3(side * 2.95, -0.52, 4.15), Vector3(1.15, 1.56, 2.50), hull)
		for brace: float in [-2.3, 0.25, 2.75]:
			_box(shell, Vector3(side * 2.35, -0.15, brace), Vector3(2.32, 1.52, 0.23), hull)
		_box(lamps, Vector3(side * 2.95, -0.52, 5.43), Vector3(0.74, 0.48, 0.11), Color("#8fe0ff"))
		_box(lamps, Vector3(side * 3.48, 0.22, -1.45), Vector3(0.14, 0.22, 0.84), Color("#ffce80"))


func _convoy(shell: SurfaceTool, lamps: SurfaceTool) -> void:
	var structure := Color("#384953")
	var frame := Color("#acbbc2")
	var cargo := Color("#a77c47")
	var beacon := Color("#ffcc80")
	_sectioned(shell, [
		Vector3(0.8, 0.37, -8.1), Vector3(1.52, 1.1, -5.9),
		Vector3(1.79, 0.99, 5.9), Vector3(1.3, 0.79, 7.2),
	], frame)
	_box(shell, Vector3(0.0, 1.0, -6.06), Vector3(1.79, 0.72, 2.50), Color("#1d4152"))
	_box(shell, Vector3(0.0, -0.92, 0.3), Vector3(8.82, 0.8, 8.9), structure)
	for side: float in [-1.0, 1.0]:
		for position_z: float in [-2.9, 1.7]:
			_box(shell, Vector3(side * 3.03, -0.02, position_z), Vector3(2.72, 2.1, 3.97), cargo)
			_box(shell, Vector3(side * 3.03, -0.02, position_z + 1.83), Vector3(2.86, 2.23, 0.28), structure)
		_box(shell, Vector3(side * 2.8, -0.14, 5.64), Vector3(2.68, 2.12, 3.16), frame)
		_box(shell, Vector3(side * 2.8, -0.14, 7.24), Vector3(1.84, 1.39, 0.32), structure)
		_box(lamps, Vector3(side * 2.8, -0.14, 7.41), Vector3(1.14, 0.76, 0.08), Color("#9fecff"))
		_box(lamps, Vector3(side * 4.38, 0.64, -4.18), Vector3(0.23, 0.26, 0.65), beacon)
		_box(lamps, Vector3(side * 4.38, 0.64, 3.21), Vector3(0.23, 0.26, 0.65), beacon)


func _patrol(shell: SurfaceTool, lamps: SurfaceTool) -> void:
	var ceramic := Color("#b9cdd6")
	var enamel := Color("#356968")
	var hull := Color("#23414d")
	_sectioned(shell, [Vector3(0.25, 0.25, -5.4), Vector3(1.08, 0.81, -2.4), Vector3(1.56, 0.68, 2.4), Vector3(1.15, 0.62, 4.32)], ceramic)
	_box(shell, Vector3(0, 0.68, -2.08), Vector3(1.12, 0.41, 1.79), hull)
	for side: float in [-1.0, 1.0]:
		_box(shell, Vector3(side * 2.25, -0.28, 0.85), Vector3(4.42, 0.45, 2.40), enamel, side * 0.34)
		_box(shell, Vector3(side * 3.75, -0.19, 2.00), Vector3(1.01, 0.72, 3.55), ceramic)
		_box(shell, Vector3(side * 1.71, 0.40, 2.67), Vector3(0.29, 1.50, 1.70), hull)
		_box(lamps, Vector3(side * 3.75, -0.19, 3.80), Vector3(0.61, 0.46, 0.11), Color("#8ae9f6"))
		_box(lamps, Vector3(side * 3.73, 0.23, -0.25), Vector3(0.42, 0.10, 1.22), Color("#9efad6"))


func _raider(shell: SurfaceTool, lamps: SurfaceTool) -> void:
	var armor := Color("#6a3c48")
	var red := Color("#bd473c")
	var shadow := Color("#344055")
	var lumen := Color("#ff8264")
	_sectioned(shell, [Vector3(0.52, 0.34, -6.1), Vector3(1.82, 1.00, -2.1), Vector3(2.32, 0.84, 3.6), Vector3(1.15, 0.58, 4.72)], armor)
	_box(shell, Vector3(0, 0.83, -1.38), Vector3(1.7, 0.53, 2.25), shadow)
	for side: float in [-1.0, 1.0]:
		_box(shell, Vector3(side * 2.76, -0.11, 0.83), Vector3(4.8, 0.51, 2.65), red, -side * 0.44)
		_box(shell, Vector3(side * 4.02, 0.12, -0.70), Vector3(0.91, 0.80, 4.30), shadow, side * 0.17)
		_box(shell, Vector3(side * 1.74, 0.29, 3.62), Vector3(1.26, 1.90, 2.10), shadow)
		_box(lamps, Vector3(side * 1.74, 0.29, 4.70), Vector3(0.85, 1.19, 0.11), lumen)
		_box(lamps, Vector3(side * 4.02, 0.43, -1.71), Vector3(0.43, 0.30, 1.79), Color("#ff4f3a"), side * 0.17)
	_box(lamps, Vector3(0, 0.31, -5.52), Vector3(0.61, 0.20, 0.26), lumen)


func _sectioned(tool: SurfaceTool, sections: Array, tint: Color) -> void:
	var rings: Array[PackedVector3Array] = []
	for section: Vector3 in sections:
		var ring := PackedVector3Array()
		for spoke in range(8):
			var angle := TAU * (float(spoke) + 0.5) / 8.0
			ring.append(Vector3(cos(angle) * section.x, sin(angle) * section.y, section.z))
		rings.append(ring)
	for index in range(rings.size() - 1):
		for spoke in range(8):
			var next := (spoke + 1) % 8
			var outward := rings[index][spoke] + rings[index][next]
			outward.z = 0.0
			_face(tool, rings[index][spoke], rings[index][next], rings[index + 1][next], outward, tint)
			_face(tool, rings[index][spoke], rings[index + 1][next], rings[index + 1][spoke], outward, tint)
	for index: int in [0, rings.size() - 1]:
		var direction := Vector3.FORWARD if index == 0 else Vector3.BACK
		for spoke in range(1, 7):
			_face(tool, rings[index][0], rings[index][spoke], rings[index][spoke + 1], direction, tint)


func _box(tool: SurfaceTool, position: Vector3, size: Vector3, tint: Color, turn := 0.0) -> void:
	var points := PackedVector3Array()
	var axes := Basis(Vector3.UP, turn)
	for corner: Vector3 in UNIT_BOX_CORNERS:
		points.append(position + axes * (corner * size))
	for corners: Vector4i in BOX_FACES:
		var a := points[corners.x]
		var b := points[corners.y]
		var c := points[corners.z]
		var d := points[corners.w]
		var outward := (a + b + c + d) * 0.25 - position
		_face(tool, a, b, c, outward, tint)
		_face(tool, a, c, d, outward, tint)


func _face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, tint: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var facing := normal.dot(outward) > 0.0
	if not facing:
		normal = -normal
	for vertex: Vector3 in [a, c, b] if facing else [a, b, c]:
		tool.set_normal(normal)
		tool.set_color(tint)
		tool.add_vertex(vertex)


func _mesh(parent: Node3D, mesh: Mesh, paint: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = paint
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _paint(color: Color, unshaded: bool) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	if unshaded:
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return paint


func _beam_halo(color: Color) -> StandardMaterial3D:
	var paint := _paint(color, true)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return paint
