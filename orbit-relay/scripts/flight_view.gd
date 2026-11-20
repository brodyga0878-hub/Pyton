extends Node3D

const AsteroidView = preload("res://scripts/asteroid_view.gd")
const MiningRigView = preload("res://scripts/mining_rig_view.gd")
const StarView = preload("res://scripts/star_view.gd")
const TrafficView = preload("res://scripts/traffic_view.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const AtmosphereView = preload("res://scripts/atmosphere_view.gd")
const STAR_DISTANCE := 2700.0
const STATION_RADIAL_SEGMENTS := 20
const BACKDROP_ORBIT_SECONDS := 28800.0
const CAMERA_SURFACE_CLEARANCE := 2.0

static var _panel_shader: Shader

var camera: Camera3D
var _ship: Node3D
var _landing_gear: Node3D
var _jet: MeshInstance3D
var _jet_material: ShaderMaterial
var _lighting: Environment
var _sunlight: DirectionalLight3D
var _fill: DirectionalLight3D
var _sector: Node3D
var _system_id := -1
var _star_id := -1
var _stars: MeshInstance3D
var _star: Node3D
var _backdrop_planet: Node3D
var _backdrop_orbit_offset := Vector3.ZERO
var _backdrop_orbit_axis := Vector3.UP
var _mining_rig: Node3D
var _traffic: Node3D
var _atmosphere: Node3D
var _surface_views: Dictionary[int, Node3D] = {}
var _stations: Dictionary[int, Node3D] = {}
var _approaches: Dictionary[int, Node3D] = {}
var _gate_materials: Dictionary[int, StandardMaterial3D] = {}
var _last_position := Vector3.INF
var _last_berth := -1
var _camera_up := Vector3.UP
var _flight_time := 0.0
var _visual_profile := 1
var _ship_fittings: Array[Node3D] = []
var _sector_fittings: Array[Node3D] = []
var _ship_finishes: Array[ShaderMaterial] = []
var _sector_finishes: Array[ShaderMaterial] = []

func build() -> void:
	if is_instance_valid(camera):
		return
	var space := WorldEnvironment.new()
	_lighting = Environment.new()
	_lighting.background_mode = Environment.BG_COLOR
	_lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_lighting.ambient_light_energy = 0.53
	space.environment = _lighting
	add_child(space)

	_sunlight = DirectionalLight3D.new()
	_sunlight.light_energy = 1.22
	add_child(_sunlight)
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(16.0, 145.0, 0.0)
	_fill.light_energy = 0.39
	add_child(_fill)

	_ship = Node3D.new()
	add_child(_ship)
	_build_ship()
	_mining_rig = MiningRigView.new()
	add_child(_mining_rig)
	_traffic = TrafficView.new()
	add_child(_traffic)
	_traffic.set_visual_profile(_visual_profile)
	_atmosphere = AtmosphereView.new()
	add_child(_atmosphere)
	camera = Camera3D.new()
	camera.fov = 67.0
	camera.near = 0.2
	camera.far = 8000.0
	add_child(camera)
	camera.make_current()
	set_visual_profile(_visual_profile)


func _load_sector(id: int) -> void:
	if is_instance_valid(_sector):
		remove_child(_sector)
		_sector.queue_free()
	_stations.clear()
	_approaches.clear()
	_gate_materials.clear()
	_surface_views.clear()
	_sector_fittings.clear()
	_sector_finishes.clear()
	_system_id = id
	_star_id = Catalog.star_for(id)
	_last_position = Vector3.INF

	var cool := id == Catalog.VELAR_SYSTEM
	var fringe := id == Catalog.FRINGE_SYSTEM
	_lighting.background_color = Color("#07091a") if cool else Color("#050910")
	_lighting.ambient_light_color = Color("#8eaae5") if cool else Color("#99b8d0")
	_sunlight.rotation_degrees = Vector3(-26.0, 47.0, 0.0) if cool else Vector3(-32.0, -36.0, 0.0)
	_sunlight.light_color = Color("#b6dbff") if cool else Color("#ffefd9")
	_fill.light_color = Color("#c8a6ee") if cool else Color("#84c8ff")
	if fringe:
		_lighting.background_color = Color("#091511")
		_lighting.ambient_light_color = Color("#8da99a")
		_sunlight.rotation_degrees = Vector3(-29.0, 68.0, 0.0)
		_sunlight.light_color = Color("#ffe3ad")
		_fill.light_color = Color("#81cdb0")

	_sector = Node3D.new()
	add_child(_sector)
	_build_stars(cool, fringe)
	_build_planet(cool, fringe)
	_star = StarView.new()
	_sector.add_child(_star)
	_star.set_visual_profile(_visual_profile)
	_star.setup(Catalog.site(_star_id), Catalog.SCOOP_INNER, Catalog.SCOOP_OUTER, cool)

	for site_id: int in Catalog.ports_for(id):
		var site := Catalog.site(site_id)
		var station := Node3D.new()
		_sector.add_child(station)
		_stations[site_id] = station
		_build_station(station, site_id, site.accent)
		var approach := Node3D.new()
		_sector.add_child(approach)
		_approaches[site_id] = approach
		_gate_materials[site_id] = _build_approach(approach, site.accent)
	for site_id: int in Catalog.mines_for(id):
		var body := AsteroidView.new()
		_sector.add_child(body)
		body.set_visual_profile(_visual_profile)
		body.build(Catalog.site(site_id), site_id)
		_surface_views[site_id] = body
	set_visual_profile(_visual_profile)


func set_visual_profile(profile: int) -> void:
	_visual_profile = clampi(profile, 0, 2)
	for fittings in [_ship_fittings, _sector_fittings]:
		for item: Node3D in fittings:
			item.visible = _visual_profile >= int(item.get_meta("minimum_profile"))
	for finishes in [_ship_finishes, _sector_finishes]:
		for finish: ShaderMaterial in finishes:
			finish.set_shader_parameter("finish_quality", _visual_profile)
	# A profile also applies to every newly loaded surface, star and NPC.
	for body: Node3D in _surface_views.values():
		body.set_visual_profile(_visual_profile)
	for layer: Node3D in [_star, _traffic]:
		if is_instance_valid(layer):
			layer.set_visual_profile(_visual_profile)
	if is_instance_valid(_atmosphere):
		_atmosphere.set_visual_profile(_visual_profile)


func sync(sim: RefCounted, delta: float) -> void:
	if not is_instance_valid(camera):
		build()
	if _system_id != int(sim.system_id):
		_load_sector(sim.system_id)
	var position_now: Vector3 = sim.position
	var docked := int(sim.docked) >= 0
	var surface_id := int(sim.landed_site)
	var landed := surface_id >= 0
	var settled := docked or landed
	var berth := int(sim.docked) if docked else surface_id
	var ship_orientation: Basis = sim.attitude()
	var heading := Basis.IDENTITY if docked else ship_orientation
	_ship.position = position_now
	_ship.basis = ship_orientation
	_landing_gear.visible = landed
	var thrust := clampf(float(sim.throttle), 0.0, 1.0)
	_flight_time += delta
	_jet.visible = not settled and thrust > 0.01
	_jet.scale = Vector3(1.0, (0.45 + thrust * 0.85) * (1.45 if sim.boost else 1.0), 1.0)
	_jet_material.set_shader_parameter("pulse", 0.59 + sin(_flight_time * 31.0) * 0.08)

	var camera_offset := Vector3(8.4, 9.2, 24.0) if docked else Vector3(0.0, 3.4, 10.5)
	var focal_offset := Vector3(0.0, 0.0, -15.0) if docked else Vector3(0.0, 2.0, -30.0)
	var up := heading.y
	if landed:
		camera_offset = Vector3(-8.4, -13.5, 12.5)
		focal_offset = Vector3(2.8, 2.0, -3.2)
		up = heading.z
	var desired := position_now + heading * camera_offset
	var jump := delta <= 0.0 or not _last_position.is_finite()
	if not jump:
		jump = position_now.distance_squared_to(_last_position) > 144.0
	var blend := 1.0 - exp(-delta * 14.0)
	var camera_start := camera.position
	if not jump and settled and berth == _last_berth:
		camera_start += position_now - _last_position
	var chase_origin := desired if jump else camera_start.lerp(desired, blend)
	camera.position = _surface_safe_camera(chase_origin, sim)
	if not settled:
		var close_follow := smoothstep(0.0, 7.0, camera.position.distance_to(chase_origin))
		focal_offset = focal_offset.lerp(Vector3(0.0, 0.4, -2.5), close_follow)
	var look_target := position_now + heading * focal_offset
	var sight := (look_target - camera.position).normalized()
	var blended_up := _camera_up.lerp(up, blend).normalized()
	_camera_up = up if jump or blended_up.is_zero_approx() else blended_up
	if absf(sight.dot(_camera_up)) > 0.995:
		_camera_up = up if absf(sight.dot(up)) < 0.995 else heading.x
	camera.look_at(look_target, _camera_up)
	_stars.position = camera.position
	_star.position = sim.target_position(_star_id)
	var backdrop_phase := TAU * fposmod(float(sim.orbit_time), BACKDROP_ORBIT_SECONDS) / BACKDROP_ORBIT_SECONDS
	_backdrop_planet.position = _star.position + _backdrop_orbit_offset.rotated(_backdrop_orbit_axis, backdrop_phase)
	_star.update_approach(camera.global_position, position_now, int(sim.target) == _star_id and not settled, bool(sim.scooping))
	_last_position = position_now
	_last_berth = berth

	for site_id: int in _stations:
		var operational: bool = sim.station_operational(site_id)
		_stations[site_id].visible = operational
		_stations[site_id].position = sim.target_position(site_id)
		_stations[site_id].rotation.z = sim.station_angle(site_id)
		_approaches[site_id].position = sim.target_gate(site_id)
		_approaches[site_id].visible = operational and not settled
		var strength := 1.45 if site_id == int(sim.target) else 0.43
		_gate_materials[site_id].albedo_color = Catalog.site(site_id).accent * strength
	for site_id: int in _surface_views:
		_surface_views[site_id].position = sim.target_position(site_id)
		var field_direction: Vector3 = sim.landing_direction if site_id == surface_id else Vector3.ZERO
		_surface_views[site_id].sync(position_now, site_id == int(sim.target), not settled, field_direction)
	var deposit: Transform3D = sim.surface_deposit() if landed else _ship.global_transform
	_mining_rig.sync(_ship.global_transform, deposit, int(sim.mining.phase) if landed else 0, sim.mining.progress(), float(sim.elapsed))
	_traffic.sync(sim.traffic_contacts(), sim.combat_beams())
	_atmosphere.sync(sim, camera, settled)
	# Compatibility supports ordinary distance fog; keep it local and subtle.
	# It never covers the CanvasLayer instruments and is absent outside air.
	var haze: Dictionary = _atmosphere.local_haze()
	_lighting.fog_enabled = bool(haze.get("inside", false))
	if _lighting.fog_enabled:
		_lighting.fog_light_color = haze.color
		_lighting.fog_light_energy = 0.48
		_lighting.fog_density = float(haze.density) * 0.0015
		_lighting.fog_sky_affect = 0.0


func _surface_safe_camera(at: Vector3, sim: RefCounted) -> Vector3:
	# The chase offset points into the rock during the first moment of an outward launch.
	for site_id: int in _surface_views:
		var center: Vector3 = sim.target_position(site_id)
		var relative := at - center
		var outer := float(Catalog.site(site_id).radius) * Terrain.MAX_RADIUS_FACTOR + CAMERA_SURFACE_CLEARANCE
		if relative.length_squared() >= outer * outer:
			continue
		var direction := Vector3.BACK if relative.is_zero_approx() else relative.normalized()
		var threshold := Terrain.radius_at(site_id, direction) + CAMERA_SURFACE_CLEARANCE
		if relative.length_squared() < threshold * threshold:
			at = center + direction * threshold
	return at


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


func _panel_finish(color: Color, metallic: float, roughness: float, seams: Vector2, ship := false) -> ShaderMaterial:
	if _panel_shader == null:
		_panel_shader = Shader.new()
		_panel_shader.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 paint : source_color;
uniform float metal = 0.3;
uniform float rough = 0.6;
uniform vec2 seams = vec2(2.0, 3.0);
uniform int finish_quality = 1;

void fragment() {
	vec3 surface = paint.rgb;
	float micro_roughness = rough;
	if (finish_quality > 0) {
		vec2 cell = UV * seams;
		vec2 edge = 0.5 - abs(fract(cell) - 0.5);
		float spacing = min(edge.x, edge.y);
		float pixel = max(fwidth(cell.x), fwidth(cell.y));
		float fade = 1.0 - smoothstep(0.10, 0.42, pixel);
		float seam = (1.0 - smoothstep(0.014, 0.042 + pixel * 0.45, spacing)) * fade;
		float ridge = (1.0 - smoothstep(0.006, 0.021 + pixel * 0.45, abs(spacing - 0.060))) * fade;
		float variation = sin(dot(floor(cell), vec2(7.1, 5.3))) * 0.063 * fade;
		surface *= 1.0 + variation + ridge * 0.15 - seam * 0.52;
		micro_roughness += seam * 0.17 - ridge * 0.08;
		if (finish_quality > 1) {
			float grain = sin(UV.y * 305.0 + cos(UV.x * 17.0 + sin(UV.y * 13.0)) * 2.8);
			float tint = sin(UV.x * 28.0 + sin(UV.y * 8.0) * 3.2);
			float visible = 1.0 - smoothstep(0.25, 1.2, fwidth(UV.y * 305.0));
			surface *= 1.0 + grain * visible * 0.048 + tint * 0.037;
			micro_roughness += grain * visible * 0.045;
		}
	}
	ALBEDO = surface;
	METALLIC = metal;
	ROUGHNESS = clamp(micro_roughness, 0.16, 0.96);
	SPECULAR = 0.43;
}
"""
	var finish := ShaderMaterial.new()
	finish.shader = _panel_shader
	finish.set_shader_parameter("paint", color)
	finish.set_shader_parameter("metal", metallic)
	finish.set_shader_parameter("rough", roughness)
	finish.set_shader_parameter("seams", seams)
	if ship:
		_ship_finishes.append(finish)
	else:
		_sector_finishes.append(finish)
	return finish


func _fitting(parent: Node3D, minimum: int) -> Node3D:
	var layer := Node3D.new()
	layer.set_meta("minimum_profile", minimum)
	parent.add_child(layer)
	if parent == _ship:
		_ship_fittings.append(layer)
	else:
		_sector_fittings.append(layer)
	return layer


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


func _build_station(station: Node3D, index: int, accent: Color) -> void:
	var primary := Color("#8c9bab") if index == 0 else Color("#969692").lerp(accent, 0.16)
	var ceramic := _panel_finish(primary, 0.28, 0.56, Vector2(5, 3))
	var graphite := _panel_finish(Color("#2a3b49"), 0.51, 0.68, Vector2(4, 2))
	var panels := _panel_finish(Color("#234a68") if index == 0 else Color("#483d4d").lerp(accent, 0.15), 0.35, 0.50, Vector2(4, 3))
	var glow := _light(accent)
	_cylinder(station, ceramic, Vector3(0, 0, -4), 7.4, 9.1, 8.8, 24)
	_cylinder(station, graphite, Vector3(0, 0, 0.45), 6.9, 7.5, 1.4, 24)
	_cylinder(station, _light(Color("#080f19")), Vector3(0, 0, 1.25), 5.14, 5.14, 0.13, 22)
	_ring(station, ceramic, Vector3(0, 0, 1.65), 5.9, 1.0, 36)
	_ring(station, glow, Vector3(0, 0, 1.95), 5.8, 0.16, 36)
	_ring(station, graphite, Vector3(0, 0, -6.65), 8.0, 0.7, 36)
	_build_dock_fittings(station, ceramic, graphite, glow)
	if index in [3, 10]:
		_build_ring_station(station, glow)
		return

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
			_cylinder(station, ceramic, pod, 4.1, 4.75, 9.0, 20)
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


func _build_dock_fittings(station: Node3D, ceramic: Material, graphite: Material, glow: Material) -> void:
	var collar := _fitting(station, 1)
	_ring(collar, graphite, Vector3(0, 0, 2.05), 6.58, 0.37, 40)
	_ring(collar, ceramic, Vector3(0, 0, -2.85), 8.34, 0.23, 40)
	var panels: Array = []
	var brackets: Array = []
	var lamps: Array = []
	var louvers: Array = []
	for index in range(12):
		var angle := TAU * index / 12.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		panels.append([radial * 7.65 + Vector3(0, 0, -0.85), Vector3(0.41, 1.18, 1.64), angle])
		brackets.append([radial * 6.56 + Vector3(0, 0, 2.27), Vector3(0.58, 0.99, 0.25), angle])
		if index % 3 == 0:
			lamps.append([radial * 6.64 + Vector3(0, 0, 2.41), Vector3(0.24, 0.76, 0.055), angle])
		for slot in range(3):
			var depth := -4.1 - float(slot) * 0.37
			louvers.append([radial * (8.40 + float(slot) * 0.07) + Vector3(0, 0, depth), Vector3(0.23, 0.93, 0.12), angle])
	_box_batch(collar, ceramic, brackets)
	_box_batch(collar, graphite, panels)
	_box_batch(collar, glow, lamps)
	_box_batch(_fitting(station, 2), graphite, louvers)


func _build_ring_station(station: Node3D, glow: StandardMaterial3D) -> void:
	var pale := _panel_finish(Color("#8498b6"), 0.36, 0.58, Vector2(12, 2))
	var shade := _panel_finish(Color("#35425a"), 0.38, 0.72, Vector2(8, 3))
	_ring(station, shade, Vector3(0, 0, -4.8), 17.9, 2.7, 44)
	_ring(station, pale, Vector3(0, 0, -3.1), 17.9, 1.3, 44)
	_ring(station, glow, Vector3(0, 0, -2.35), 17.8, 0.16, 44)
	var pylons: Array = []
	var lamps: Array = []
	var radiators: Array = []
	for index in range(8):
		var angle := TAU * float(index) / 8.0 + PI * 0.125
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		var tangent := Vector3(-radial.y, radial.x, 0.0)
		pylons.append([radial * 12.5 + Vector3(0, 0, -3.8), Vector3(11.0, 0.9, 1.4), angle])
		radiators.append([radial * 18.2 + Vector3(0, 0, -4.2), Vector3(4.2, 2.6, 1.22), angle])
		lamps.append([radial * 18.5 + Vector3(0, 0, -2.98), Vector3(2.12, 0.26, 0.12), angle])
		if index in [0, 4]:
			for side: float in [-1.0, 1.0]:
				radiators.append([radial * 20.3 + tangent * side * 3.6 + Vector3(0, 0, -5.6), Vector3(5.8, 1.35, 1.48), angle])
	_box_batch(station, pale, pylons)
	_box_batch(station, shade, radiators)
	_box_batch(station, glow, lamps)


func _build_approach(approach: Node3D, accent: Color) -> StandardMaterial3D:
	var paint := _light(accent)
	_ring(approach, paint, Vector3.ZERO, 7.4, 0.11, 48)
	var markers: Array = []
	for side: float in [-1.0, 1.0]:
		markers.append([Vector3(side * 7.4, 0, 0), Vector3(0.30, 2.05, 0.16)])
		markers.append([Vector3(0, side * 7.4, 0), Vector3(2.05, 0.30, 0.16)])
		for offset: float in [8.0, 16.0, 24.0, 34.0, 44.0, 54.0]:
			var width: float = lerpf(6.4, 5.25, offset / 54.0)
			markers.append([Vector3(side * width, -0.18, -offset), Vector3(0.14, 0.20, 1.53)])
	_box_batch(approach, paint, markers)
	return paint


func _sectioned_shell(parent: Node3D, paint: Material, sections: Array[Vector3], at := Vector3.ZERO) -> void:
	# An octagonal cross section keeps a clear silhouette without hard box edges.
	var outline := PackedVector2Array([
		Vector2(1, 0.64), Vector2(0.71, 1), Vector2(-0.71, 1), Vector2(-1, 0.64),
		Vector2(-1, -0.64), Vector2(-0.71, -1), Vector2(0.71, -1), Vector2(1, -0.64),
	])
	var rows: Array[PackedVector3Array] = []
	for section: Vector3 in sections:
		var row := PackedVector3Array()
		for point: Vector2 in outline:
			row.append(Vector3(point.x * section.y, point.y * section.z, section.x))
		rows.append(row)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var first := sections[0].x
	var length := sections[-1].x - first
	for row in range(rows.size() - 1):
		var v0 := (sections[row].x - first) / length
		var v1 := (sections[row + 1].x - first) / length
		for edge in range(outline.size()):
			var next := (edge + 1) % outline.size()
			var u0 := float(edge) / outline.size()
			var u1 := float(edge + 1) / outline.size()
			var a := rows[row][edge]
			var b := rows[row + 1][edge]
			var c := rows[row + 1][next]
			var d := rows[row][next]
			_facet(tool, a, b, c, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1))
			_facet(tool, a, c, d, Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0))
	for edge in range(outline.size()):
		var next := (edge + 1) % outline.size()
		var uv0 := outline[edge] * 0.5 + Vector2(0.5, 0.5)
		var uv1 := outline[next] * 0.5 + Vector2(0.5, 0.5)
		_facet(tool, Vector3(0, 0, first), rows[0][edge], rows[0][next], Vector2(0.5, 0.5), uv0, uv1)
		_facet(tool, Vector3(0, 0, sections[-1].x), rows[-1][next], rows[-1][edge], Vector2(0.5, 0.5), uv1, uv0)
	_mesh(parent, tool.commit(), paint, at)


func _facet(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2) -> void:
	var normal := (c - a).cross(b - a).normalized()
	tool.set_normal(normal)
	tool.set_uv(uv0)
	tool.add_vertex(a)
	tool.set_normal(normal)
	tool.set_uv(uv1)
	tool.add_vertex(b)
	tool.set_normal(normal)
	tool.set_uv(uv2)
	tool.add_vertex(c)


func _build_ship() -> void:
	var shell := _panel_finish(Color("#c2c8c6"), 0.35, 0.48, Vector2(7.0, 3.0), true)
	var graphite := _panel_finish(Color("#354853"), 0.49, 0.58, Vector2(4.0, 3.0), true)
	var cargo := _panel_finish(Color("#be7548"), 0.31, 0.51, Vector2(6.0, 2.0), true)
	var bare_metal := _surface(Color("#778b96"), 0.61, 0.32)
	var ice := _light(Color("#8df8e6"))
	var warm := _light(Color("#fbb768"))
	var canopy := _surface(Color("#214f70"), 0.38, 0.18)
	canopy.emission_enabled = true
	canopy.emission = Color("#16415c")
	canopy.emission_energy_multiplier = 0.26
	_sectioned_shell(_ship, shell, [
		Vector3(-1.58, 0.16, 0.12), Vector3(-1.43, 0.30, 0.21), Vector3(-0.48, 0.55, 0.39),
		Vector3(0.19, 0.59, 0.42), Vector3(1.18, 0.62, 0.50), Vector3(1.44, 0.56, 0.44),
	])
	_sectioned_shell(_ship, graphite, [
		Vector3(-1.44, 0.22, 0.08), Vector3(-0.30, 0.52, 0.18), Vector3(1.00, 0.64, 0.23), Vector3(1.37, 0.54, 0.19),
	], Vector3(0, -0.34, 0))
	_sectioned_shell(_ship, graphite, [
		Vector3(-1.34, 0.21, 0.052), Vector3(-0.86, 0.38, 0.22), Vector3(-0.27, 0.41, 0.25), Vector3(0.23, 0.30, 0.14),
	], Vector3(0, 0.33, 0))
	_sectioned_shell(_ship, canopy, [
		Vector3(-1.30, 0.18, 0.05), Vector3(-0.84, 0.34, 0.18), Vector3(-0.29, 0.36, 0.20), Vector3(0.13, 0.26, 0.107),
	], Vector3(0, 0.40, 0))
	_cylinder(_ship, graphite, Vector3(0, 0.02, 1.48), 0.48, 0.59, 0.51, 16)
	_cylinder(_ship, _surface(Color("#131e27"), 0.22, 0.80), Vector3(0, 0.02, 1.69), 0.35, 0.35, 0.08, 20)
	_cylinder(_ship, ice, Vector3(0, 0.02, 1.74), 0.25, 0.27, 0.072, 20)
	_ring(_ship, bare_metal, Vector3(0, 0.02, 1.75), 0.41, 0.12, 28)
	_ring(_ship, ice, Vector3(0, 0.02, 1.79), 0.30, 0.045, 28)
	var trim := _fitting(_ship, 1)
	var detail := _fitting(_ship, 2)
	var plates: Array = []
	var lights: Array = []
	var retaining_straps: Array = []
	var radiator_slots: Array = []
	var service_slots: Array = []
	for side: float in [-1.0, 1.0]:
		_sectioned_shell(_ship, graphite, [
			Vector3(-0.62, 0.27, 0.055), Vector3(-0.25, 0.63, 0.09), Vector3(0.88, 0.85, 0.12), Vector3(1.45, 0.56, 0.06),
		], Vector3(side * 0.94, -0.145, 0))
		_sectioned_shell(_ship, cargo, [
			Vector3(-0.59, 0.19, 0.16), Vector3(-0.41, 0.33, 0.24), Vector3(1.12, 0.34, 0.28), Vector3(1.42, 0.26, 0.22),
		], Vector3(side * 1.16, -0.11, 0))
		_cylinder(_ship, graphite, Vector3(side * 1.16, -0.11, 1.43), 0.21, 0.27, 0.18, 14)
		_cylinder(_ship, ice, Vector3(side * 1.16, -0.11, 1.54), 0.126, 0.14, 0.054, 14)
		plates.append([Vector3(side * 0.61, 0.29, 0.70), Vector3(0.33, 0.16, 0.95), side * -0.25])
		plates.append([Vector3(side * 1.64, -0.06, 0.93), Vector3(0.18, 0.14, 0.53), side * 0.10])
		lights.append([Vector3(side * 1.64, 0.025, 0.91), Vector3(0.12, 0.033, 0.43)])
		retaining_straps.append([Vector3(side * 1.16, 0.178, 0.81), Vector3(0.45, 0.035, 0.12)])
		retaining_straps.append([Vector3(side * 1.16, 0.141, -0.24), Vector3(0.43, 0.035, 0.12)])
		for slot in range(4):
			radiator_slots.append([Vector3(side * 0.61, 0.378, 0.47 + float(slot) * 0.15), Vector3(0.24, 0.045, 0.052), side * -0.25])
		for slot in range(3):
			service_slots.append([Vector3(side * 1.17, 0.182, 0.22 + float(slot) * 0.16), Vector3(0.34, 0.033, 0.045)])
	_box_batch(_ship, graphite, plates)
	_box_batch(_ship, ice, lights)
	_box_batch(trim, bare_metal, retaining_straps)
	_box_batch(trim, bare_metal, radiator_slots)
	_box_batch(detail, warm, service_slots)
	_ring(trim, graphite, Vector3(0, 0.02, 1.77), 0.47, 0.045, 30)
	_landing_gear = Node3D.new()
	_landing_gear.visible = false
	_ship.add_child(_landing_gear)
	var legs: Array = []
	for index in range(3):
		var angle := PI * 0.5 + TAU * float(index) / 3.0
		var radius := Vector3(cos(angle), sin(angle), 0.0)
		var joint := radius * 0.38 + Vector3(0, 0, -0.75)
		var foot := radius * 1.32 + Vector3(0, 0, -3.92)
		var strut := _cylinder(_landing_gear, shell, (joint + foot) * 0.5, 0.066, 0.1, joint.distance_to(foot), 6)
		strut.basis = Basis.looking_at(foot - joint) * Basis(Vector3.RIGHT, PI * 0.5)
		legs.append([foot, Vector3(0.46, 0.32, 0.13), angle])
	_box_batch(_landing_gear, graphite, legs)

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


func _build_stars(cool: bool, fringe: bool) -> void:
	var generator := RandomNumberGenerator.new()
	generator.seed = 86507 if fringe else (64871 if cool else 22361)
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
	_stars = _mesh(_sector, mesh.commit(), paint, Vector3.ZERO)


func _build_planet(cool: bool, fringe: bool) -> void:
	_backdrop_planet = Node3D.new()
	_sector.add_child(_backdrop_planet)
	var display_scale := 1.65 if cool else 1.0
	var initial_center := Vector3(1125, -330, -3370) if cool else Vector3(-1450, -475, -2900)
	if fringe:
		display_scale = 1.18
		initial_center = Vector3(1480, -620, -2570)
	var star_center: Vector3 = Catalog.site(_star_id).center
	_backdrop_planet.scale = Vector3.ONE * display_scale
	_backdrop_orbit_offset = initial_center * display_scale - star_center
	_backdrop_orbit_axis = _backdrop_orbit_offset.cross(Vector3.UP).normalized()

	var sphere := SphereMesh.new()
	sphere.radius = 870.0
	sphere.height = 1740.0
	sphere.radial_segments = 56
	sphere.rings = 26
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform bool cool = false;
uniform bool fringe = false;
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
	vec3 low = cool ? vec3(0.13, 0.20, 0.46) : vec3(0.09, 0.27, 0.37);
	vec3 high = cool ? vec3(0.44, 0.68, 0.71) : vec3(0.65, 0.43, 0.30);
	if (fringe) {
		low = vec3(0.09, 0.24, 0.18);
		high = vec3(0.78, 0.60, 0.34);
	}
	vec3 bands = mix(low, high, m);
	vec3 light_dir = cool ? vec3(0.65, 0.54, 0.63) : vec3(-0.6, 0.46, 0.72);
	float day = smoothstep(-0.23, 0.89, dot(p, normalize(light_dir)));
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 4.0);
	vec3 haze = fringe ? vec3(0.56, 0.63, 0.28) : (cool ? vec3(0.26, 0.44, 0.70) : vec3(0.17, 0.36, 0.44));
	ALBEDO = bands * (0.105 + day * 0.75) + rim * haze * (0.15 + day * 0.75);
}
"""
	var world := ShaderMaterial.new()
	world.shader = shader
	world.set_shader_parameter("cool", cool)
	world.set_shader_parameter("fringe", fringe)
	_mesh(_backdrop_planet, sphere, world, Vector3.ZERO)
	var air := SphereMesh.new()
	air.radius = 894.0
	air.height = 1788.0
	air.radial_segments = 48
	air.rings = 22
	var halo := Shader.new()
	halo.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform bool cool = false;
uniform bool fringe = false;
void fragment() {
	float rim = 1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	ALBEDO = fringe ? vec3(0.55, 0.76, 0.48) : (cool ? vec3(0.36, 0.59, 0.91) : vec3(0.22, 0.46, 0.58));
	ALPHA = smoothstep(0.54, 0.80, rim) * (1.0 - smoothstep(0.83, 1.0, rim)) * 0.38;
}
"""
	var air_material := ShaderMaterial.new()
	air_material.shader = halo
	air_material.set_shader_parameter("cool", cool)
	air_material.set_shader_parameter("fringe", fringe)
	_mesh(_fitting(_backdrop_planet, 1), air, air_material, Vector3.ZERO)
	if cool:
		_build_planet_ring()


func _build_planet_ring() -> void:
	var disc := QuadMesh.new()
	disc.size = Vector2(3210.0, 3210.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
void fragment() {
	vec2 radial = UV * 2.0 - 1.0;
	float radius = length(radial);
	if (radius < 0.63 || radius > 0.988) {
		discard;
	}
	float rim = smoothstep(0.63, 0.69, radius) * (1.0 - smoothstep(0.955, 0.988, radius));
	float bands = 0.61 + 0.22 * sin(radius * 155.0) + 0.16 * sin(radius * 423.0);
	float gap = smoothstep(0.005, 0.024, abs(radius - 0.833));
	float light = 0.52 + 0.43 * smoothstep(-0.8, 0.92, radial.x - radial.y * 0.4);
	ALBEDO = mix(vec3(0.42, 0.42, 0.67), vec3(0.56, 0.78, 0.87), bands) * light;
	ALPHA = bands * rim * gap * 0.55;
}
"""
	var paint := ShaderMaterial.new()
	paint.shader = shader
	var ring := _mesh(_backdrop_planet, disc, paint, Vector3.ZERO)
	ring.basis = Basis(Vector3.FORWARD, -0.37) * Basis(Vector3.RIGHT, 1.12)
