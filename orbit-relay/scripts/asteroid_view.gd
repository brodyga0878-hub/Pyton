extends Node3D
## A radial world with a surveyed touchdown patch facing +Z.

const Surface = preload("res://scripts/surface_terrain.gd")

var _gate: Node3D
var _gate_ring: MeshInstance3D
var _field_deposit: MultiMeshInstance3D
var _last_field_direction := Vector3.ZERO
var _site_id: int
var _kind: String
var _radius: float
var _face_z: float
var _seed: int
var _surface_color: Color
var _accent: Color
var _built := false

static var _rock_shader: Shader


func build(site: Dictionary, site_id: int) -> void:
	if _built:
		return
	_built = true
	_site_id = site_id
	position = site.center
	_kind = site.kind
	_radius = site.radius
	_face_z = site.pad_offset - 4.0
	_surface_color = site.surface_color
	_accent = site.accent
	_seed = site.seed
	var face := Vector3(0, 0, _face_z)
	_add_mesh(self, _rock_mesh(), _rock_paint(), Vector3.ZERO)
	_make_landing_marks(face)
	var crystals := _make_deposit()
	_add_batch(self, crystals).transform = Surface.deposit(_site_id, Vector3.BACK)
	_field_deposit = _add_batch(self, crystals)
	_field_deposit.hide()
	_make_gate(Vector3(0, 0, site.gate_offset))
	if _kind == "planet":
		_make_planet_rocks()
	if _kind == "comet":
		_make_comet_tail()


func sync(ship_position: Vector3, selected: bool, flight_visible: bool, field_direction: Vector3) -> void:
	_gate.visible = selected and flight_visible
	_gate_ring.visible = to_local(ship_position).z > _gate.position.z + 14.0
	_field_deposit.visible = not field_direction.is_zero_approx() and not field_direction.is_equal_approx(Vector3.BACK)
	if _field_deposit.visible and field_direction != _last_field_direction:
		_field_deposit.transform = Surface.deposit(_site_id, field_direction)
		_last_field_direction = field_direction


func _vertex(direction: Vector3) -> PackedVector3Array:
	return PackedVector3Array([Surface.point(_site_id, direction), Surface.normal(_site_id, direction)])


func _rock_mesh() -> ArrayMesh:
	var meridians := 52
	var parallels := 32
	if _kind == "planet":
		meridians = 96
		parallels = 64
	var rows: Array[PackedVector3Array] = []
	for ring in range(parallels + 1):
		var polar := PI * float(ring) / parallels
		var vertices := PackedVector3Array()
		for spoke in range(meridians):
			var angle := TAU * float(spoke) / meridians
			var direction := Vector3(cos(angle) * sin(polar), sin(angle) * sin(polar), cos(polar))
			vertices.append_array(_vertex(direction))
		rows.append(vertices)
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(parallels):
		for spoke in range(meridians):
			var next := (spoke + 1) % meridians
			if ring != 0:
				_emit_vertex(geometry, rows[ring], spoke)
				_emit_vertex(geometry, rows[ring], next)
				_emit_vertex(geometry, rows[ring + 1], spoke)
			if ring < parallels - 1:
				_emit_vertex(geometry, rows[ring], next)
				_emit_vertex(geometry, rows[ring + 1], next)
				_emit_vertex(geometry, rows[ring + 1], spoke)
	geometry.index()
	return geometry.commit()


func _emit_vertex(geometry: SurfaceTool, row: PackedVector3Array, index: int) -> void:
	geometry.set_normal(row[index * 2 + 1])
	geometry.add_vertex(row[index * 2])


func _rock_paint() -> ShaderMaterial:
	if _rock_shader == null:
		_rock_shader = Shader.new()
		_rock_shader.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 rock_color : source_color = vec4(0.48, 0.45, 0.42, 1.0);
uniform vec4 seam_color : source_color = vec4(0.62, 0.48, 0.36, 1.0);
uniform float bands_strength = 1.0;
uniform float terrain_regions = 0.0;
varying vec3 rock;
void vertex() {
	rock = VERTEX;
}
float grit(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.17, 0.29, 0.1));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float deposits(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 a = vec2(
		mix(grit(cell), grit(cell + vec3(1.0, 0.0, 0.0)), f.x),
		mix(grit(cell + vec3(0.0, 1.0, 0.0)), grit(cell + vec3(1.0, 1.0, 0.0)), f.x)
	);
	vec2 b = vec2(
		mix(grit(cell + vec3(0.0, 0.0, 1.0)), grit(cell + vec3(1.0, 0.0, 1.0)), f.x),
		mix(grit(cell + vec3(0.0, 1.0, 1.0)), grit(cell + vec3(1.0, 1.0, 1.0)), f.x)
	);
	return mix(mix(a.x, a.y, f.y), mix(b.x, b.y, f.y), f.z);
}
void fragment() {
	vec3 p = rock;
	float sediment = sin(p.y * 0.17 + p.x * 0.07 + p.z * 0.16 + sin(p.x * 0.21) * 1.18);
	float strata = sin(p.y * 0.71 + p.x * 0.18 + p.z * 0.29 + sediment * 2.80);
	float rock_bands = clamp(0.43 + bands_strength * (0.27 * sediment + 0.11 * strata), 0.0, 1.0);
	float coarse = deposits(p * 0.68) - 0.5;
	float fine = grit(floor(p * 6.4)) - 0.5;
	float detail = 1.0 - smoothstep(0.3, 1.4, length(fwidth(p * 6.4)));
	vec3 stone = mix(rock_color.rgb, seam_color.rgb, rock_bands);
	if (terrain_regions > 0.0) {
		float provinces = deposits(p * 0.034 + vec3(9.2, 1.7, 3.4));
		float basalt = smoothstep(0.42, 0.64, provinces + coarse * 0.066);
		stone = mix(stone, stone * vec3(0.57, 0.67, 0.79), basalt * terrain_regions);
	}
	ALBEDO = stone * (0.96 + coarse * 0.28 + fine * 0.18 * detail);
	METALLIC = 0.0;
	ROUGHNESS = 0.87;
}
"""
	var material := ShaderMaterial.new()
	material.shader = _rock_shader
	material.set_shader_parameter("rock_color", _surface_color)
	material.set_shader_parameter("seam_color", _surface_color.lerp(_accent, 0.31 if _kind != "moon" else 0.22))
	material.set_shader_parameter("bands_strength", 0.37 if _kind == "moon" else 1.0)
	material.set_shader_parameter("terrain_regions", 0.85 if _kind == "planet" else 0.0)
	return material


func _make_landing_marks(face: Vector3) -> void:
	var lines := _paint(_accent, true)
	var alloy := _paint(Color("#3f5867"))
	var center := face + Vector3(0, 0, 0.045)
	var directions: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.LEFT, Vector3.DOWN]
	var plates: Array = []
	var lamps: Array = []
	for index in range(directions.size()):
		var outward: Vector3 = directions[index]
		var angle := float(index) * PI * 0.5
		var point: Vector3 = center + outward * 7.2
		plates.append([point, Vector3(1.1, 3.0, 0.10), angle])
		lamps.append([point + Vector3(0, 0, 0.07), Vector3(0.24, 2.2, 0.05), angle])
		lamps.append([point + outward * 0.74 + Vector3(0, 0, 0.07), Vector3(0.24, 1.0, 0.045), angle])
	# Spaced corners preserve the rock as the landing surface.
	for sign_x: float in [-1.0, 1.0]:
		for sign_y: float in [-1.0, 1.0]:
			var corner := center + Vector3(4.65 * sign_x, 4.65 * sign_y, 0.013)
			lamps.append([corner - Vector3(0.48 * sign_x, 0, 0), Vector3(1.08, 0.16, 0.035), 0.0])
			lamps.append([corner - Vector3(0, 0.48 * sign_y, 0), Vector3(0.16, 1.08, 0.035), 0.0])
	_box_batch(self, alloy, plates)
	_box_batch(self, lines, lamps)


func _make_deposit() -> MultiMesh:
	var crystal := PrismMesh.new()
	crystal.size = Vector3(0.36, 0.34, 0.68)
	var paint := _paint(Color.WHITE)
	paint.vertex_color_use_as_albedo = true
	crystal.material = paint
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = crystal
	batch.instance_count = 18
	var random := RandomNumberGenerator.new()
	random.seed = _seed * 7 + 7819
	for index in range(batch.instance_count):
		var angle := TAU * float(index) / batch.instance_count
		var radius := random.randf_range(1.44, 2.46)
		var at := Vector3(cos(angle) * radius, sin(angle) * radius, -0.91)
		var axes := Basis.from_euler(Vector3(random.randf_range(-0.45, 0.42), 0.24, angle))
		axes = axes.scaled(Vector3.ONE * random.randf_range(0.50, 1.08))
		batch.set_instance_transform(index, Transform3D(axes, at))
		batch.set_instance_color(index, _surface_color.lerp(_accent, 0.67 if index % 3 else 0.22))
	return batch


func _make_planet_rocks() -> void:
	var stone := SphereMesh.new()
	stone.radius = 1.0
	stone.height = 2.0
	stone.radial_segments = 7
	stone.rings = 3
	var material := _paint(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	stone.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = stone
	batch.instance_count = 176
	var random := RandomNumberGenerator.new()
	random.seed = _seed * 19 + 137
	for index in range(batch.instance_count):
		var angle := TAU * fposmod(float(index) * 0.61803398875, 1.0)
		var direction: Vector3
		if index < 128:
			var pole := 1.0 - 2.0 * (float(index) + 0.5) / 128.0
			var equator := sqrt(1.0 - pole * pole)
			direction = Vector3(equator * cos(angle), pole, equator * sin(angle))
		else:
			var radial := random.randf_range(16.0, 41.0)
			direction = Vector3(cos(angle) * radial, sin(angle) * radial, _face_z).normalized()
		var ground := Surface.point(_site_id, direction)
		var terrain_axes := Surface.basis(_site_id, direction)
		var spin := Basis(Vector3.BACK, random.randf_range(0.0, TAU))
		var size := random.randf_range(0.17, 0.8)
		var axes := (terrain_axes * spin).scaled_local(Vector3(size * 1.5, size, size * 0.68))
		batch.set_instance_transform(index, Transform3D(axes, ground - terrain_axes.z * 0.025))
		var tint := _surface_color.lerp(_accent, random.randf_range(0.0, 0.26))
		batch.set_instance_color(index, tint.darkened(random.randf_range(0.02, 0.31)))
	_add_batch(self, batch)


func _make_gate(at: Vector3) -> void:
	var mark := _paint(_accent, true)
	_gate = Node3D.new()
	_gate.position = at
	_gate.visible = false
	add_child(_gate)
	var ring := TorusMesh.new()
	ring.inner_radius = 9.8
	ring.outer_radius = 10.1
	ring.rings = 40
	ring.ring_segments = 5
	_gate_ring = _add_mesh(_gate, ring, mark, Vector3.ZERO)
	_gate_ring.rotation.x = PI * 0.5
	var rails: Array = []
	for side: float in [-1.0, 1.0]:
		for fraction: float in [0.17, 0.34, 0.51, 0.72, 0.93]:
			var step := (at.z - _face_z - 12.0) * fraction
			rails.append([Vector3(side * lerpf(9.0, 7.3, fraction), -0.18, -step), Vector3(0.25, 0.22, 1.8), 0.0])
	_box_batch(_gate, mark, rails)


func _make_comet_tail() -> void:
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var direction := Vector3(-0.82, 0.23, -0.51).normalized()
	var start := direction * _radius * 0.44
	var length := _radius * 3.3
	var first_side := direction.cross(Vector3.UP).normalized()
	for lateral in [first_side, direction.cross(first_side)]:
		for segment in range(7):
			for corner: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var t := (float(segment) + corner.x) / 7.0
				var axis := start + direction * (length * t)
				var width := _radius * lerpf(0.31, 0.82, t)
				geometry.set_uv(Vector2(t, corner.y))
				geometry.add_vertex(axis + lateral * width * (corner.y * 2.0 - 1.0))
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 dust : source_color = vec4(0.40, 0.73, 0.85, 1.0);
void fragment() {
	float width = abs((UV.y - 0.5) * 2.0);
	float shaft = 1.0 - smoothstep(0.06, 1.0, width);
	float fade = smoothstep(0.0, 0.17, UV.x) * (1.0 - smoothstep(0.11, 1.0, UV.x));
	float wisps = sin(UV.y * 36.0 + UV.x * 9.0) * 0.15 + 0.85;
	ALBEDO = dust.rgb;
	ALPHA = shaft * fade * wisps * 0.13;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("dust", _accent)
	_add_mesh(self, geometry.commit(), material, Vector3.ZERO)


func _paint(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 0.68
	if unshaded:
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return paint


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _box_batch(parent: Node3D, paint: Material, shapes: Array) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = paint
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = shapes.size()
	for index in range(shapes.size()):
		var shape: Array = shapes[index]
		var axes := Basis(Vector3.BACK, shape[2]).scaled_local(shape[1])
		batch.set_instance_transform(index, Transform3D(axes, shape[0]))
	_add_batch(parent, batch)


func _add_batch(parent: Node3D, batch: MultiMesh) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
