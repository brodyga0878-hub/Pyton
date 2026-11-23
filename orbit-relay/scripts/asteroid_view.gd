extends Node3D
## A radial world with a surveyed touchdown patch facing +Z.

const Surface = preload("res://scripts/surface_terrain.gd")

var _gate: Node3D
var _gate_ring: MeshInstance3D
var _field_deposit: MultiMeshInstance3D
var _debris: MultiMeshInstance3D
var _surface_paint: ShaderMaterial
var _last_field_direction := Vector3.ZERO
var _site_id: int
var _kind: String
var _radius: float
var _face_z: float
var _seed: int
var _surface_color: Color
var _accent: Color
var _built := false
var _visual_profile := 1

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
	_surface_paint = _rock_paint()
	_add_mesh(self, _rock_mesh(), _surface_paint, Vector3.ZERO)
	_make_landing_marks(face)
	var crystals := _make_deposit()
	_add_batch(self, crystals).transform = Surface.deposit(_site_id, Vector3.BACK)
	_field_deposit = _add_batch(self, crystals)
	_field_deposit.hide()
	_make_gate(Vector3(0, 0, site.gate_offset))
	if _kind == "comet":
		_make_comet_tail()
	set_visual_profile(_visual_profile)


func set_visual_profile(profile: int) -> void:
	_visual_profile = clampi(profile, 0, 2)
	if _surface_paint == null:
		return
	_surface_paint.set_shader_parameter("profile", _visual_profile)
	if _visual_profile > 0 and _debris == null:
		_debris = _make_surface_debris()
	if _debris != null:
		_debris.visible = _visual_profile > 0
		var count := _debris.multimesh.instance_count
		_debris.multimesh.visible_instance_count = count if _visual_profile == 2 else ceili(count * 0.56)


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
uniform float ice_fraction = 0.0;
uniform int profile = 1;
// Linear packed data: neutral-centered tone, height, roughness. No sRGB decode.
uniform sampler2D surface_detail : filter_linear_mipmap, repeat_enable;
uniform vec3 detail_offset = vec3(0.0);
varying vec3 rock;
varying vec3 rock_normal;
void vertex() {
	rock = VERTEX;
	rock_normal = NORMAL;
}
vec3 triplanar_data(vec3 p, vec3 weights) {
	return texture(surface_detail, p.yz).rgb * weights.x
		+ texture(surface_detail, p.zx).rgb * weights.y
		+ texture(surface_detail, p.xy).rgb * weights.z;
}
float strata_mask(float bedding, float rough, float width) {
	float phase = bedding + rough;
	float pixel = fwidth(phase);
	float ripple = abs(sin(phase));
	float line = 1.0 - smoothstep(width, width + 0.15 + pixel * 0.4, ripple);
	return line * (1.0 - smoothstep(0.45, 2.5, pixel));
}
vec3 relief_normal(vec3 position, vec3 n, float height) {
	// Bound subpixel slopes at grazing angles without changing model geometry.
	vec3 dx = dFdx(position);
	vec3 dy = dFdy(position);
	vec3 along_x = cross(dy, n);
	vec3 along_y = cross(n, dx);
	float det = dot(dx, along_x);
	vec3 gradient = (along_x * dFdx(height) + along_y * dFdy(height))
		* sign(det) / max(abs(det), 0.00001);
	gradient *= inversesqrt(max(1.0, dot(gradient, gradient) * 3.1));
	return normalize(n - gradient);
}
void fragment() {
	vec3 p = rock;
	vec3 radial = normalize(p);
	vec3 local_normal = normalize(rock_normal);
	float slope = 1.0 - clamp(dot(radial, local_normal), 0.0, 1.0);
	float exposed = smoothstep(0.018, 0.18, slope);
	float bedding = dot(p, vec3(0.21, 0.72, 0.34)) + sin(p.x * 0.18 + p.z * 0.055) * 1.4;
	float sediment = sin(bedding * 0.18 + sin(p.z * 0.071) * 0.63);
	float strata_phase = bedding + sediment * 1.77;
	float strata = sin(strata_phase) * (1.0 - smoothstep(0.60, 2.8, fwidth(strata_phase)));
	float provinces = sin(radial.z * 8.1 + radial.x * 4.7) * cos(radial.y * 7.0 - radial.x * 2.8);
	float basin = smoothstep(-0.52, 0.32, provinces);
	float broad = 0.25 + basin * 0.26 + bands_strength * (0.13 * sediment + exposed * 0.13 * strata);
	vec3 stone = mix(rock_color.rgb, seam_color.rgb, broad) * (0.86 + basin * 0.19);
	float roughness = mix(0.90, 0.71, ice_fraction);
	float sheen = 0.5;
	if (profile > 0) {
		// Stable model-local projection has no spherical UV seam or world-space crawl.
		vec3 weights = abs(local_normal);
		weights *= weights;
		weights *= weights;
		weights /= max(weights.x + weights.y + weights.z, 0.00001);
		vec3 detail = triplanar_data(p * 0.11 + detail_offset, weights);
		float grains = detail.r;
		float fault = detail.g;
		float layer_breaks = smoothstep(0.30, 0.77, grains * 0.57 + fault * 0.43);
		layer_breaks *= mix(0.48, 1.0, exposed);
		float lamina = strata_mask(bedding * 1.27, fault * 12.0 + grains * 1.4 + sediment * 0.73, 0.09) * layer_breaks;
		float crevice = 1.0 - smoothstep(0.36, 0.51, fault);
		float mineral = smoothstep(0.43, 0.67, grains + fault * 0.08 + basin * 0.08);
		float frost = ice_fraction * smoothstep(0.48, 0.71, grains + (1.0 - exposed) * 0.07) * crevice;
		float relief = (fault - 0.5) * (0.19 + exposed * 0.11) + lamina * bands_strength * 0.047;
		stone *= 1.0 + (grains - 0.5) * 0.77 - crevice * (0.09 + exposed * 0.08);
		stone = mix(stone, stone * vec3(0.71, 0.75, 0.82), mineral * terrain_regions);
		stone = mix(stone, seam_color.rgb * 1.06, lamina * bands_strength * 0.24);
		stone = mix(stone, seam_color.rgb * vec3(0.96, 1.07, 1.12), frost * 0.70);
		roughness = mix(roughness, detail.b, 0.55) + crevice * 0.09 - frost * 0.26;
		sheen = mix(0.35, 0.49 + frost * 0.15, ice_fraction);
		if (profile == 2) {
			float resolution = 1.0 - smoothstep(0.17, 0.89, length(fwidth(p * 0.73)));
			vec3 fine = triplanar_data(p * 0.73 + detail_offset.zxy + vec3(0.19, 0.37, 0.61), weights);
			stone *= 1.0 + resolution * (fine.r - 0.5) * 0.38;
			relief += resolution * (fine.g - 0.5) * mix(0.066, 0.041, frost);
			roughness += resolution * (fine.b - 0.5) * 0.09;
		}
		NORMAL = relief_normal(VERTEX, normalize(NORMAL), relief);
	}
	ALBEDO = stone;
	METALLIC = 0.0;
	SPECULAR = sheen;
	ROUGHNESS = clamp(roughness, mix(0.55, 0.30, ice_fraction), 0.98);
}
"""
	var material := ShaderMaterial.new()
	material.shader = _rock_shader
	material.set_shader_parameter("rock_color", _surface_color)
	material.set_shader_parameter("seam_color", _surface_color.lerp(_accent, 0.40 if _kind != "moon" else 0.28))
	material.set_shader_parameter("bands_strength", 0.42 if _kind == "moon" else 1.0)
	material.set_shader_parameter("terrain_regions", 0.79 if _kind == "planet" else 0.31)
	material.set_shader_parameter("ice_fraction", 1.0 if _kind == "moon" or _kind == "comet" else 0.0)
	material.set_shader_parameter("surface_detail", load("res://assets/materials/rock_ice.png" if _kind == "moon" or _kind == "comet" else "res://assets/materials/rock_basalt.png"))
	material.set_shader_parameter("detail_offset", Vector3(fposmod(_seed * 0.137, 1.0), fposmod(_seed * 0.319, 1.0), fposmod(_seed * 0.571, 1.0)))
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


func _make_surface_debris() -> MultiMeshInstance3D:
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
	var world_samples := 128 if _kind == "planet" else 48
	batch.instance_count = world_samples + (96 if _kind == "planet" else 30)
	var random := RandomNumberGenerator.new()
	random.seed = _seed * 19 + 137
	for index in range(batch.instance_count):
		var angle := TAU * fposmod(float(index) * 0.61803398875, 1.0)
		var direction: Vector3
		if index < world_samples:
			var pole := 1.0 - 2.0 * (float(index) + 0.5) / world_samples
			var equator := sqrt(1.0 - pole * pole)
			direction = Vector3(equator * cos(angle), pole, equator * sin(angle))
		else:
			var radial := random.randf_range(13.0, minf(45.0, _radius * 0.83))
			direction = Vector3(cos(angle) * radial, sin(angle) * radial, _face_z).normalized()
		var ground := Surface.point(_site_id, direction)
		var terrain_axes := Surface.basis(_site_id, direction)
		var spin := Basis(Vector3.BACK, random.randf_range(0.0, TAU))
		var size := random.randf_range(0.12, 0.87 if _kind == "planet" else 0.60)
		var axes := (terrain_axes * spin).scaled_local(Vector3(size * 1.6, size, size * 0.56))
		# Preserve the exact clear disk and omit the visible rocks from the surveyed pad.
		if ground.z > 0.0 and Vector2(ground.x, ground.y).length() <= 11.0:
			axes = axes.scaled(0.001 * Vector3.ONE)
		batch.set_instance_transform(index, Transform3D(axes, ground - terrain_axes.z * 0.09))
		var tint := _surface_color.lerp(_accent, random.randf_range(0.0, 0.26))
		batch.set_instance_color(index, tint.darkened(random.randf_range(0.02, 0.31)))
	return _add_batch(self, batch)


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
