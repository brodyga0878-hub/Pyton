extends Node3D
## A stationary landing face on a procedural body. All heights are along +Z.

const LANDING_FACE_Z := 39.0
const LANDING_COLOR := Color("#fac974")
const CRATERS := [
	Vector3(-0.55, 0.35, 0.76),
	Vector3(0.56, 0.49, 0.66),
	Vector3(0.46, -0.54, 0.68),
	Vector3(-0.41, -0.81, 0.42),
	Vector3(0.29, 0.78, -0.55),
]
const RIG_PAINT := Color("#db9b42")

var _gate: Node3D
var _gate_ring: MeshInstance3D
var _rig: Node3D
var _bit: Node3D
var _indicator: StandardMaterial3D
var _sparks: MultiMeshInstance3D
var _spark_angles: Array[float] = []
var _mining_spot: Vector3
var _built := false


func build(center: Vector3, pad: Vector3, gate: Vector3) -> void:
	if _built:
		return
	_built = true
	position = center
	var face := Vector3(pad.x - center.x, pad.y - center.y, LANDING_FACE_Z)
	_mining_spot = face + Vector3(6.1, 0.36, 1.05)
	_add_mesh(self, _rock_mesh(), _rock_paint(), Vector3.ZERO)
	_make_landing_marks(face)
	_make_deposit()
	_make_gate(gate - center)
	_make_rig()


func sync(ship_pose: Transform3D, selected: bool, settled: bool, flight_visible: bool, phase: int, progress: float, seconds: float) -> void:
	_gate.visible = selected and flight_visible
	_gate_ring.visible = to_local(ship_pose.origin).z > _gate.position.z + 14.0
	var stow_world := ship_pose * Vector3(0.86, 0.42, 0.14)
	var stow := to_local(stow_world)
	var deploy_fraction := 0.0
	if settled:
		match phase:
			1:
				deploy_fraction = smoothstep(0.0, 1.0, progress)
			2, 3:
				deploy_fraction = 1.0
			4:
				deploy_fraction = 1.0 - smoothstep(0.0, 1.0, progress)
	_rig.position = stow.lerp(_mining_spot, deploy_fraction)
	_rig.position.z += sin(PI * deploy_fraction) * 2.4
	_rig.basis = ship_pose.basis.slerp(Basis.IDENTITY, deploy_fraction).scaled(Vector3.ONE * lerpf(0.43, 1.0, deploy_fraction))
	_indicator.albedo_color = Color("#8bf4c1") if phase == 3 else Color("#fabb64")
	_bit.rotation.z = seconds * 12.0 if phase == 2 else 0.0
	_bit.position.z = -0.54 - 0.34 * smoothstep(0.02, 0.27, progress) if phase == 2 else -0.32
	_sparks.visible = settled and phase == 2
	if _sparks.visible:
		for index in range(_spark_angles.size()):
			var t := fposmod(seconds * 1.5 + float(index) * 0.171, 1.0)
			var angle := _spark_angles[index]
			var radius := 0.32 + t * 1.45
			var height := 0.80 * sin(PI * t) + 0.04
			var at := _mining_spot - Vector3(0, 0, 1.0) + Vector3(cos(angle) * radius, sin(angle) * radius, height)
			var size := lerpf(0.11, 0.025, t)
			_sparks.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), at))


func _sample(direction: Vector3) -> Vector3:
	var d := direction
	var radius := 39.4 + sin(d.x * 7.5 + d.z * 4.5) * 2.25
	radius += sin(d.y * 9.0 - d.x * 6.0) * cos(d.z * 10.0) * 1.20
	radius += sin(d.y * 23.2 + d.z * 13.0) * sin(d.x * 26.0) * 0.64
	for index in range(CRATERS.size()):
		var distance := d.distance_to(CRATERS[index])
		var width := 0.15 + 0.045 * float(index % 3)
		var valley := 1.0 - smoothstep(width * 0.35, width, distance)
		var rim := 1.0 - smoothstep(width * 0.05, width * 0.28, absf(distance - width))
		radius += 1.65 * rim - (3.8 + float(index % 3)) * valley
	var point := d * radius
	point.x *= 1.08
	point.y *= 0.88
	var flat := smoothstep(0.90, 0.943, d.z)
	point.z = lerpf(minf(point.z, 39.9), LANDING_FACE_Z, flat)
	return point.limit_length(42.7)


func _vertex(direction: Vector3) -> PackedVector3Array:
	var point := _sample(direction)
	var helper := Vector3.BACK if absf(direction.z) < 0.96 else Vector3.UP
	var tangent := direction.cross(helper).normalized()
	var axis := direction.cross(tangent)
	var edge_a := _sample((direction + tangent * 0.012).normalized()) - point
	var edge_b := _sample((direction + axis * 0.012).normalized()) - point
	return PackedVector3Array([point, edge_a.cross(edge_b).normalized()])


func _rock_mesh() -> ArrayMesh:
	const MERIDIANS := 48
	const PARALLELS := 28
	var rows: Array[PackedVector3Array] = []
	for ring in range(PARALLELS + 1):
		var polar := PI * float(ring) / PARALLELS
		var vertices := PackedVector3Array()
		for spoke in range(MERIDIANS):
			var angle := TAU * float(spoke) / MERIDIANS
			var direction := Vector3(cos(angle) * sin(polar), sin(angle) * sin(polar), cos(polar))
			vertices.append_array(_vertex(direction))
		rows.append(vertices)
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(PARALLELS):
		for spoke in range(MERIDIANS):
			var next := (spoke + 1) % MERIDIANS
			if ring != 0:
				_emit_vertex(geometry, rows[ring], spoke)
				_emit_vertex(geometry, rows[ring], next)
				_emit_vertex(geometry, rows[ring + 1], spoke)
			if ring < PARALLELS - 1:
				_emit_vertex(geometry, rows[ring], next)
				_emit_vertex(geometry, rows[ring + 1], next)
				_emit_vertex(geometry, rows[ring + 1], spoke)
	geometry.index()
	return geometry.commit()


func _emit_vertex(geometry: SurfaceTool, row: PackedVector3Array, index: int) -> void:
	geometry.set_normal(row[index * 2 + 1])
	geometry.add_vertex(row[index * 2])


func _rock_paint() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley;
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
	float rock_bands = clamp(0.47 + 0.27 * sediment + 0.11 * strata, 0.0, 1.0);
	float coarse = deposits(p * 0.68) - 0.5;
	float fine = grit(floor(p * 6.4)) - 0.5;
	float detail = 1.0 - smoothstep(0.3, 1.4, length(fwidth(p * 6.4)));
	vec3 slate = vec3(0.22, 0.24, 0.29);
	vec3 ochre = vec3(0.42, 0.32, 0.25);
	ALBEDO = mix(slate, ochre, rock_bands) * (0.96 + coarse * 0.28 + fine * 0.18 * detail);
	METALLIC = 0.0;
	ROUGHNESS = 0.87;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _make_landing_marks(face: Vector3) -> void:
	var lines := _paint(LANDING_COLOR, true)
	var alloy := _paint(Color("#3f5867"))
	var center := face + Vector3(0, 0, 0.045)
	var directions: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.LEFT, Vector3.DOWN]
	for index in range(directions.size()):
		var outward: Vector3 = directions[index]
		var angle := float(index) * PI * 0.5
		var point: Vector3 = center + outward * 7.2
		_box(self, alloy, point, Vector3(1.1, 3.0, 0.10), angle)
		_box(self, lines, point + Vector3(0, 0, 0.07), Vector3(0.24, 2.2, 0.05), angle)
		_box(self, lines, point + outward * 0.74 + Vector3(0, 0, 0.07), Vector3(0.24, 1.0, 0.045), angle)
	# Spaced corners preserve the rock as the landing surface.
	for sign_x: float in [-1.0, 1.0]:
		for sign_y: float in [-1.0, 1.0]:
			var corner := center + Vector3(4.65 * sign_x, 4.65 * sign_y, 0.013)
			_box(self, lines, corner - Vector3(0.48 * sign_x, 0, 0), Vector3(1.08, 0.16, 0.035))
			_box(self, lines, corner - Vector3(0, 0.48 * sign_y, 0), Vector3(0.16, 1.08, 0.035))


func _make_deposit() -> void:
	var crystal := PrismMesh.new()
	crystal.size = Vector3(0.36, 0.34, 0.68)
	var gold := _paint(Color("#a77546"))
	var silver := _paint(Color("#b0a398"))
	var random := RandomNumberGenerator.new()
	random.seed = 7819
	for index in range(18):
		var angle := TAU * float(index) / 18.0
		var radius := random.randf_range(1.44, 2.46)
		var at := _mining_spot - Vector3(0, 0, 0.91) + Vector3(cos(angle) * radius, sin(angle) * radius, 0.0)
		var shard := _add_mesh(self, crystal, gold if index % 3 else silver, at)
		shard.rotation = Vector3(random.randf_range(-0.45, 0.42), 0.24, angle)
		shard.scale *= random.randf_range(0.50, 1.08)


func _make_gate(at: Vector3) -> void:
	var mark := _paint(LANDING_COLOR, true)
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
	for side: float in [-1.0, 1.0]:
		for step: float in [9.0, 18.0, 27.0, 38.0, 49.0]:
			_box(_gate, mark, Vector3(side * lerpf(9.0, 7.3, step / 50.0), -0.18, -step), Vector3(0.25, 0.22, 1.8))


func _make_rig() -> void:
	_rig = Node3D.new()
	add_child(_rig)
	var shell := _paint(RIG_PAINT)
	var support := _paint(Color("#293944"))
	var drill := _paint(Color("#b8c1be"))
	_indicator = _paint(Color("#fabb64"), true)
	_box(_rig, shell, Vector3(0, 0, 0.0), Vector3(1.62, 1.64, 0.70))
	_box(_rig, support, Vector3(0, 0, 0.40), Vector3(1.10, 1.13, 0.19))
	_box(_rig, _indicator, Vector3(0.0, -0.08, 0.504), Vector3(0.62, 0.28, 0.04))
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			_box(_rig, support, Vector3(x * 0.83, y * 0.81, -0.34), Vector3(0.21, 0.23, 0.78), x * y * 0.52)
			_box(_rig, drill, Vector3(x * 0.90, y * 0.88, -0.69), Vector3(0.49, 0.43, 0.13), x * y * 0.23)
	_bit = Node3D.new()
	_rig.add_child(_bit)
	_box(_bit, drill, Vector3.ZERO, Vector3(0.24, 0.67, 0.56))
	_box(_bit, drill, Vector3.ZERO, Vector3(0.61, 0.24, 0.45))
	var spark := BoxMesh.new()
	spark.size = Vector3.ONE
	spark.material = _paint(Color("#ffbd72"), true)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = spark
	batch.instance_count = 14
	for index in range(batch.instance_count):
		_spark_angles.append(TAU * fposmod(float(index) * 0.381966, 1.0))
	_sparks = MultiMeshInstance3D.new()
	_sparks.multimesh = batch
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.visible = false
	add_child(_sparks)


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


func _box(parent: Node3D, paint: Material, at: Vector3, size: Vector3, turn: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add_mesh(parent, mesh, paint, at).rotation.z = turn
