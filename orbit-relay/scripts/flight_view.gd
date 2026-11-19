extends Node3D

const STATION_COLORS := [Color("#5df6c9"), Color("#ffb66f")]
const STAR_DISTANCE := 2700.0
const STATION_RADIAL_SEGMENTS := 20

var camera: Camera3D
var _ship: Node3D
var _jet: MeshInstance3D
var _jet_material: ShaderMaterial
var _stars: MeshInstance3D
var _stations: Array[Node3D] = []
var _approaches: Array[Node3D] = []
var _gate_materials: Array[StandardMaterial3D] = []
var _last_position := Vector3.INF
var _flight_time := 0.0

func build() -> void:
	if is_instance_valid(camera):
		return
	var space := WorldEnvironment.new()
	var lighting := Environment.new()
	lighting.background_mode = Environment.BG_COLOR
	lighting.background_color = Color("#050910")
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Color("#99b8d0")
	lighting.ambient_light_energy = 0.63
	space.environment = lighting
	add_child(space)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-32.0, -36.0, 0.0)
	sunlight.light_color = Color("#ffefd9")
	sunlight.light_energy = 1.3
	add_child(sunlight)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(16.0, 145.0, 0.0)
	fill.light_color = Color("#84c8ff")
	fill.light_energy = 0.47
	add_child(fill)

	_build_stars()
	_build_planet()

	for station_index in range(STATION_COLORS.size()):
		var station := Node3D.new()
		add_child(station)
		_stations.append(station)
		_build_station(station, station_index)
		var approach := Node3D.new()
		add_child(approach)
		_approaches.append(approach)
		_build_approach(approach, station_index)

	_ship = Node3D.new()
	add_child(_ship)
	_build_ship()
	camera = Camera3D.new()
	camera.fov = 67.0
	camera.near = 0.2
	camera.far = 5200.0
	add_child(camera)
	camera.make_current()


func sync(sim: RefCounted, delta: float) -> void:
	if not is_instance_valid(camera):
		build()
	var heading := Basis.from_euler(Vector3(float(sim.pitch), float(sim.yaw), 0.0))
	var position_now: Vector3 = sim.position
	_ship.position = position_now
	_ship.basis = heading * Basis(Vector3.BACK, float(sim.roll))

	var docked := int(sim.docked) >= 0
	var thrust := clampf(float(sim.throttle), 0.0, 1.0)
	_flight_time += delta
	_jet.visible = not docked and thrust > 0.01
	_jet.scale = Vector3(1.0, (0.45 + thrust * 0.85) * (1.45 if sim.boost else 1.0), 1.0)
	_jet_material.set_shader_parameter("pulse", 0.59 + sin(_flight_time * 31.0) * 0.08)

	var camera_offset := Vector3(8.4, 9.2, 24.0) if docked else Vector3(0.0, 3.4, 10.5)
	var focal_offset := Vector3(0.0, 0.0, -15.0) if docked else Vector3(0.0, 2.0, -30.0)
	var desired := position_now + heading * camera_offset
	var jump := delta <= 0.0 or not _last_position.is_finite()
	if not jump:
		jump = position_now.distance_squared_to(_last_position) > 144.0
	camera.position = desired if jump else camera.position.lerp(desired, 1.0 - exp(-delta * 14.0))
	camera.look_at(position_now + heading * focal_offset, heading.y)
	_stars.position = camera.position
	_last_position = position_now

	for station_index in range(_stations.size()):
		_stations[station_index].position = sim.station_positions[station_index]
		_stations[station_index].rotation.z = sim.station_angle(station_index)
		_approaches[station_index].position = sim.gate_position(station_index)
		_approaches[station_index].visible = not docked
		var strength := 1.45 if station_index == int(sim.target) else 0.43
		_gate_materials[station_index].albedo_color = STATION_COLORS[station_index] * strength


func _mesh(parent: Node3D, primitive: Mesh, paint: Material, at: Vector3) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = primitive
	item.material_override = paint
	item.position = at
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	return item


func _surface(color: Color, metallic := 0.25, roughness := 0.65) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = metallic
	paint.roughness = roughness
	return paint


func _light(color: Color) -> StandardMaterial3D:
	var paint := _surface(color)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return paint


func _box_batch(parent: Node3D, paint: Material, shapes: Array) -> void:
	if shapes.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = paint
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = shapes.size()
	for index in range(shapes.size()):
		var shape: Array = shapes[index]
		var size: Vector3 = shape[1]
		var axes := Basis(Vector3.BACK, float(shape[2])) if shape.size() > 2 else Basis.IDENTITY
		batch.set_instance_transform(index, Transform3D(axes.scaled_local(size), shape[0]))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _cylinder(parent: Node3D, paint: Material, at: Vector3, radius_front: float, radius_back: float, length: float, segments := STATION_RADIAL_SEGMENTS) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius_front
	cylinder.bottom_radius = radius_back
	cylinder.height = length
	cylinder.radial_segments = segments
	cylinder.rings = 1
	var item := _mesh(parent, cylinder, paint, at)
	item.rotation.x = PI * 0.5
	return item


func _ring(parent: Node3D, paint: Material, at: Vector3, radius: float, thickness: float, segments := 32) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = radius - thickness * 0.5
	ring.outer_radius = radius + thickness * 0.5
	ring.rings = segments
	ring.ring_segments = 6
	var item := _mesh(parent, ring, paint, at)
	item.rotation.x = PI * 0.5


func _build_station(station: Node3D, index: int) -> void:
	var ceramic := _surface(Color("#8798ac") if index == 0 else Color("#9c8a7e"))
	var graphite := _surface(Color("#253646"), 0.22, 0.78)
	var panels := _surface(Color("#153c5a") if index == 0 else Color("#573043"), 0.23, 0.48)
	var glow := _light(STATION_COLORS[index])
	_cylinder(station, ceramic, Vector3(0, 0, -4), 7.4, 9.1, 8.8, 12)
	_cylinder(station, graphite, Vector3(0, 0, 0.45), 6.9, 7.5, 1.4, 12)
	_cylinder(station, _light(Color("#080f19")), Vector3(0, 0, 1.25), 5.14, 5.14, 0.13, 22)
	_ring(station, ceramic, Vector3(0, 0, 1.65), 5.9, 1.0, 36)
	_ring(station, glow, Vector3(0, 0, 1.95), 5.8, 0.16, 36)
	_ring(station, graphite, Vector3(0, 0, -6.65), 8.0, 0.7, 36)

	var struts: Array = []
	var plates: Array = []
	var lamps: Array = []
	var stripes: Array = []
	var arms := 4 if index == 0 else 3
	for arm in range(arms):
		var angle := TAU * float(arm) / float(arms) + (PI * 0.5 if index == 0 else PI * 0.16)
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		var tangent := Vector3(-radial.y, radial.x, 0.0)
		if index == 0:
			struts.append([radial * 13.0 + Vector3(0, 0, -4), Vector3(14.0, 2.45, 3.15), angle])
			for side: float in [-1.0, 1.0]:
				var panel := radial * 16.6 + tangent * side * 4.0 + Vector3(0, 0, -4.3)
				plates.append([panel, Vector3(10.6, 5.6, 0.7), angle])
				for bar in range(5):
					var line := panel + radial * (float(bar) - 2.0) * 2.1 + Vector3(0, 0, 0.42)
					stripes.append([line, Vector3(0.13, 5.52, 0.08), angle])
		else:
			struts.append([radial * 12.5 + Vector3(0, 0, -6), Vector3(12.4, 4.0, 4.0), angle])
			var pod := radial * 17.0 + Vector3(0, 0, -4)
			_cylinder(station, ceramic, pod, 4.1, 4.75, 9.0, 12)
			_ring(station, glow, pod + Vector3(0, 0, 4.3), 3.78, 0.12, 24)
			stripes.append([radial * 13.0 + Vector3(0, 0, -3.91), Vector3(6.1, 1.15, 0.1), angle])
		lamps.append([radial * 20.4 + Vector3(0, 0, -2.9), Vector3(1.2, 0.34, 0.4), angle])
		lamps.append([radial * 6.9 + Vector3(0, 0, 1.19), Vector3(0.65, 1.95, 0.18), angle])
		# Asymmetric radial marks make bay rotation readable at a glance.
		if arm == 0:
			lamps.append([radial * 3.25 + Vector3(0, 0, 1.98), Vector3(3.75, 0.26, 0.08), angle])
	for panel_index in range(16):
		var angle := TAU * float(panel_index) / 16.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		stripes.append([radial * 7.38 + Vector3(0, 0, -1.38), Vector3(0.17, 1.2, 0.75), angle])
	_box_batch(station, ceramic, struts)
	_box_batch(station, panels, plates)
	_box_batch(station, graphite, stripes)
	_box_batch(station, glow, lamps)


func _build_approach(approach: Node3D, index: int) -> void:
	var paint := _light(STATION_COLORS[index])
	_gate_materials.append(paint)
	_ring(approach, paint, Vector3.ZERO, 7.4, 0.11, 48)
	var markers: Array = []
	for side: float in [-1.0, 1.0]:
		markers.append([Vector3(side * 7.4, 0, 0), Vector3(0.30, 2.05, 0.16)])
		markers.append([Vector3(0, side * 7.4, 0), Vector3(2.05, 0.30, 0.16)])
		for offset: float in [8.0, 16.0, 24.0, 34.0, 44.0, 54.0]:
			var width: float = lerpf(6.4, 5.25, offset / 54.0)
			markers.append([Vector3(side * width, -0.18, -offset), Vector3(0.14, 0.20, 1.53)])
	_box_batch(approach, paint, markers)


func _build_ship() -> void:
	var shell := _surface(Color("#bdcbd4"), 0.31, 0.55)
	var graphite := _surface(Color("#2f454f"), 0.27, 0.54)
	var cargo := _surface(Color("#b35c3b"), 0.17, 0.64)
	var ice := _light(Color("#8df8e6"))
	var canopy := _surface(Color("#123957"), 0.29, 0.32)
	_cylinder(_ship, shell, Vector3(0, 0, 0), 0.66, 0.31, 3.1, 6)
	_cylinder(_ship, graphite, Vector3(0, 0.02, 1.45), 0.62, 0.69, 0.42, 8)
	_cylinder(_ship, ice, Vector3(0, 0.02, 1.69), 0.30, 0.34, 0.085, 12)
	_ring(_ship, graphite, Vector3(0, 0.02, 1.72), 0.46, 0.14, 20)
	_box_batch(_ship, canopy, [[Vector3(0, 0.42, -0.92), Vector3(0.59, 0.27, 1.09)]])
	var plates: Array = []
	var pods: Array = []
	var lights: Array = []
	var retaining_straps: Array = []
	for side: float in [-1.0, 1.0]:
		plates.append([Vector3(side * 0.93, -0.12, 0.27), Vector3(1.82, 0.21, 1.22), side * 0.17])
		pods.append([Vector3(side * 1.18, -0.11, 0.48), Vector3(0.58, 0.51, 1.79), side * 0.10])
		lights.append([Vector3(side * 1.58, -0.034, 0.85), Vector3(0.28, 0.075, 0.69)])
		retaining_straps.append([Vector3(side * 1.18, -0.11, 0.93), Vector3(0.62, 0.54, 0.14), side * 0.10])
		retaining_straps.append([Vector3(side * 1.18, -0.11, -0.18), Vector3(0.62, 0.54, 0.14), side * 0.10])
	_box_batch(_ship, graphite, plates)
	_box_batch(_ship, cargo, pods)
	_box_batch(_ship, ice, lights)
	_box_batch(_ship, shell, retaining_straps)

	var flow := Shader.new()
	flow.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float pulse = 0.6;
varying float tail;
void vertex() {
	tail = 1.0 - clamp(VERTEX.y / 1.6 + 0.5, 0.0, 1.0);
}
void fragment() {
	ALBEDO = mix(vec3(0.16, 0.56, 0.83), vec3(0.55, 0.94, 1.0), tail);
	ALPHA = pulse * tail * tail;
}
"""
	_jet_material = ShaderMaterial.new()
	_jet_material.shader = flow
	var flare := CylinderMesh.new()
	flare.top_radius = 0.05
	flare.bottom_radius = 0.35
	flare.height = 1.6
	flare.radial_segments = 10
	flare.rings = 1
	_jet = _mesh(_ship, flare, _jet_material, Vector3(0, 0.02, 2.33))
	_jet.rotation.x = PI * 0.5


func _build_stars() -> void:
	var generator := RandomNumberGenerator.new()
	generator.seed = 22361
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(1730):
		var vertical := generator.randf_range(-1.0, 1.0)
		var longitude := generator.randf_range(0.0, TAU)
		var equator := sqrt(1.0 - vertical * vertical)
		var direction := Vector3(cos(longitude) * equator, vertical, sin(longitude) * equator)
		var horizontal := direction.cross(Vector3.UP).normalized()
		var upright := direction.cross(horizontal).normalized()
		var size := generator.randf_range(1.17, 3.0)
		var amount := generator.randf_range(0.25, 0.72)
		if index % 43 == 0:
			size *= 1.75
			amount = 0.93
		var tint := Color(amount * 0.82, amount * 0.90, amount)
		if index % 7 == 0:
			tint = Color(amount, amount * 0.83, amount * 0.71)
		var center := direction * STAR_DISTANCE
		var vertices: Array[Vector3] = [
			center + horizontal * size, center + upright * size,
			center - horizontal * size, center - upright * size
		]
		for corner in [0, 1, 2, 0, 2, 3]:
			mesh.set_color(tint)
			mesh.add_vertex(vertices[corner])
	var paint := _light(Color.WHITE)
	paint.vertex_color_use_as_albedo = true
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_stars = _mesh(self, mesh.commit(), paint, Vector3.ZERO)


func _build_planet() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 870.0
	sphere.height = 1740.0
	sphere.radial_segments = 56
	sphere.rings = 26
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
varying vec3 surface_point;
float strata(vec3 p) {
	return sin(p.x * 21.0 + sin(p.z * 9.0) * 0.65) * cos(p.z * 18.0 + p.y * 13.0);
}
void vertex() {
	surface_point = normalize(VERTEX);
}
void fragment() {
	vec3 p = normalize(surface_point);
	float latitude = p.y + p.x * 0.23 + strata(p) * 0.009;
	float warp = sin(p.z * 10.0 + p.x * 13.0) * 0.52;
	float ribbons = sin(latitude * 26.0 + warp);
	float details = sin(latitude * 112.0 + sin(p.x * 25.0) * 1.5) * 0.1;
	float m = smoothstep(-0.86, 0.87, ribbons * 0.60 + details + sin(latitude * 8.0) * 0.34);
	vec3 bands = mix(vec3(0.09, 0.27, 0.37), vec3(0.65, 0.43, 0.30), m);
	float day = smoothstep(-0.23, 0.89, dot(p, normalize(vec3(-0.6, 0.46, 0.72))));
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 4.0);
	ALBEDO = bands * (0.105 + day * 0.75) + rim * vec3(0.17, 0.36, 0.44) * (0.15 + day * 0.75);
}
"""
	var world := ShaderMaterial.new()
	world.shader = shader
	var center := Vector3(-1450, -475, -2900)
	_mesh(self, sphere, world, center)
	var air := SphereMesh.new()
	air.radius = 894.0
	air.height = 1788.0
	air.radial_segments = 48
	air.rings = 22
	var halo := Shader.new()
	halo.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
void fragment() {
	float rim = 1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	ALBEDO = vec3(0.22, 0.46, 0.58);
	ALPHA = smoothstep(0.54, 0.80, rim) * (1.0 - smoothstep(0.83, 1.0, rim)) * 0.38;
}
"""
	var air_material := ShaderMaterial.new()
	air_material.shader = halo
	_mesh(self, air, air_material, center)
