extends Node3D
## A surveyed field with a stable touchdown patch facing +Z.

var _gate: Node3D
var _gate_ring: MeshInstance3D
var _mining_spot: Vector3
var _kind: String
var _radius: float
var _face_z: float
var _seed: int
var _morph_phase: float
var _stretch: Vector3
var _surface_color: Color
var _accent: Color
var _craters: Array[Vector3] = []
var _crater_widths: Array[float] = []
var _built := false

static var _rock_shader: Shader


func build(site: Dictionary) -> void:
	if _built:
		return
	_built = true
	position = site.center
	_kind = site.kind
	_radius = site.radius
	_face_z = site.pad_offset - 4.0
	_surface_color = site.surface_color
	_accent = site.accent
	_seed = site.seed
	var random := RandomNumberGenerator.new()
	random.seed = _seed
	_morph_phase = random.randf_range(-PI, PI)
	_stretch = Vector3(random.randf_range(0.96, 1.13), random.randf_range(0.83, 1.07), 0.95)
	match _kind:
		"moon":
			_stretch = Vector3(1.0, 0.98, 1.0)
		"comet":
			_stretch = Vector3(1.25, 0.72, 0.84)
	var crater_count := 9 if _kind == "moon" else 5
	for index in range(crater_count):
		var angle := TAU * float(index) / crater_count + random.randf_range(-0.17, 0.17)
		var elevation := random.randf_range(0.08, 0.82) if index % 3 != 2 else random.randf_range(-0.9, -0.25)
		var reach := sqrt(1.0 - elevation * elevation)
		_craters.append(Vector3(cos(angle) * reach, sin(angle) * reach, elevation))
		_crater_widths.append(random.randf_range(0.12, 0.26))
	var face := Vector3(0, 0, _face_z)
	_mining_spot = face + Vector3(6.1, 0.36, 1.05)
	_add_mesh(self, _rock_mesh(), _rock_paint(), Vector3.ZERO)
	_make_landing_marks(face)
	_make_deposit()
	_make_gate(Vector3(0, 0, site.gate_offset))
	if _kind == "comet":
		_make_comet_tail()


func mining_spot() -> Vector3:
	return to_global(_mining_spot)


func sync(ship_position: Vector3, selected: bool, flight_visible: bool) -> void:
	_gate.visible = selected and flight_visible
	_gate_ring.visible = to_local(ship_position).z > _gate.position.z + 14.0


func _sample(direction: Vector3) -> Vector3:
	var d := direction
	var wobble := 0.032 if _kind == "moon" else 0.16
	var shape := 0.975 if _kind == "moon" else 0.90
	shape += sin(d.x * 7.5 + d.z * 4.5 + _morph_phase) * wobble * 0.62
	shape += sin(d.y * 9.0 - d.x * 6.0 + _morph_phase) * cos(d.z * 10.0) * wobble * 0.38
	shape += sin(d.y * 23.2 + d.z * 13.0) * sin(d.x * 26.0) * wobble * 0.14
	if _kind == "comet":
		shape += smoothstep(0.27, 0.74, absf(d.x)) * 0.17 - 0.07
	for index in range(_craters.size()):
		var distance := d.distance_to(_craters[index])
		var width := _crater_widths[index]
		var valley := 1.0 - smoothstep(width * 0.35, width, distance)
		var rim := 1.0 - smoothstep(width * 0.05, width * 0.28, absf(distance - width))
		shape += 0.028 * rim - 0.105 * valley
	var point: Vector3 = d * (_radius * shape) * _stretch
	if d.z > 0.0:
		var from_pad := Vector2(point.x, point.y).length()
		var flat := 1.0 - smoothstep(11.0, 23.0, from_pad)
		point.z = lerpf(minf(point.z, _face_z + 0.9), _face_z, flat)
	return point.limit_length(_radius - 0.3)


func _vertex(direction: Vector3) -> PackedVector3Array:
	var point := _sample(direction)
	var helper := Vector3.BACK if absf(direction.z) < 0.96 else Vector3.UP
	var tangent := direction.cross(helper).normalized()
	var axis := direction.cross(tangent)
	var edge_a := _sample((direction + tangent * 0.012).normalized()) - point
	var edge_b := _sample((direction + axis * 0.012).normalized()) - point
	return PackedVector3Array([point, edge_a.cross(edge_b).normalized()])


func _rock_mesh() -> ArrayMesh:
	var meridians := 52 if _kind == "moon" else 44
	var parallels := 32 if _kind == "moon" else 26
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
	ALBEDO = mix(rock_color.rgb, seam_color.rgb, rock_bands) * (0.96 + coarse * 0.28 + fine * 0.18 * detail);
	METALLIC = 0.0;
	ROUGHNESS = 0.87;
}
"""
	var material := ShaderMaterial.new()
	material.shader = _rock_shader
	material.set_shader_parameter("rock_color", _surface_color)
	material.set_shader_parameter("seam_color", _surface_color.lerp(_accent, 0.31 if _kind != "moon" else 0.22))
	material.set_shader_parameter("bands_strength", 0.37 if _kind == "moon" else 1.0)
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


func _make_deposit() -> void:
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
		var at := _mining_spot - Vector3(0, 0, 0.91) + Vector3(cos(angle) * radius, sin(angle) * radius, 0.0)
		var axes := Basis.from_euler(Vector3(random.randf_range(-0.45, 0.42), 0.24, angle))
		axes = axes.scaled(Vector3.ONE * random.randf_range(0.50, 1.08))
		batch.set_instance_transform(index, Transform3D(axes, at))
		batch.set_instance_color(index, _surface_color.lerp(_accent, 0.67 if index % 3 else 0.22))
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


func _add_batch(parent: Node3D, batch: MultiMesh) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
