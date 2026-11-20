extends Node3D
## Finite, low-overdraw atmosphere volumes and ship-local entry light.
## This view reads the simulation; it neither computes drag nor changes heat.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Atmosphere = preload("res://scripts/atmosphere.gd")
const MAX_STREAKS := 22
const SHELL_SEGMENTS := [32, 48, 64]
const SHELL_RINGS := [18, 26, 34]

static var _air_shader: Shader
static var _entry_shader: Shader
static var _streak_shader: Shader

var _shells: Dictionary[int, MeshInstance3D] = {}
var _shell_meshes: Dictionary[int, SphereMesh] = {}
var _shell_paints: Dictionary[int, ShaderMaterial] = {}
var _entry: Node3D
var _sheath: MeshInstance3D
var _entry_paint: ShaderMaterial
var _streaks: MultiMeshInstance3D
var _streak_paint: ShaderMaterial
var _profile := 1
var _system := -1
var _entry_strength := 0.0
var _camera_haze: Dictionary = {}


func setup(system_id: int) -> void:
	if _system == system_id:
		return
	for shell: MeshInstance3D in _shells.values():
		remove_child(shell)
		shell.queue_free()
	_shells.clear()
	_shell_meshes.clear()
	_shell_paints.clear()
	_system = system_id
	for site_id: int in Catalog.targets_for(system_id):
		var profile: Dictionary = Atmosphere.profile(site_id)
		if profile.is_empty():
			continue
		var planet: Dictionary = Catalog.site(site_id)
		var mesh := SphereMesh.new()
		mesh.radius = float(planet.radius) + float(profile.height)
		mesh.height = mesh.radius * 2.0
		var paint := ShaderMaterial.new()
		paint.shader = _atmosphere_shader()
		paint.set_shader_parameter("body_radius", float(planet.radius))
		paint.set_shader_parameter("air_height", float(profile.height))
		paint.set_shader_parameter("air_density", float(profile.density))
		paint.set_shader_parameter("air_color", profile.color)
		var shell := MeshInstance3D.new()
		shell.name = "Atmosphere_%d" % site_id
		shell.mesh = mesh
		shell.material_override = paint
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shell)
		_shells[site_id] = shell
		_shell_meshes[site_id] = mesh
		_shell_paints[site_id] = paint
	if not is_instance_valid(_entry):
		_build_entry()
	_entry.hide()
	set_visual_profile(_profile)


func set_visual_profile(profile: int) -> void:
	_profile = clampi(profile, 0, 2)
	for site_id: int in _shell_meshes:
		_shell_meshes[site_id].radial_segments = SHELL_SEGMENTS[_profile]
		_shell_meshes[site_id].rings = SHELL_RINGS[_profile]
		_shell_paints[site_id].set_shader_parameter("profile", _profile)
	if is_instance_valid(_streaks):
		_streaks.multimesh.visible_instance_count = [6, 14, MAX_STREAKS][_profile]
		_entry_paint.set_shader_parameter("profile", _profile)


func sync(sim: RefCounted, camera: Camera3D, settled: bool) -> void:
	setup(int(sim.system_id))
	var star: Vector3 = sim.target_position(Catalog.star_for(int(sim.system_id)))
	for site_id: int in _shells:
		var shell: MeshInstance3D = _shells[site_id]
		shell.position = sim.target_position(site_id)
		var profile: Dictionary = Atmosphere.profile(site_id)
		var outer := float(Catalog.site(site_id).radius) + float(profile.height)
		var paint: ShaderMaterial = _shell_paints[site_id]
		paint.set_shader_parameter("body_center", shell.global_position)
		paint.set_shader_parameter("sun_direction", (star - shell.position).normalized())
		paint.set_shader_parameter("inside_volume", camera.global_position.distance_squared_to(shell.global_position) < outer * outer)
		paint.set_shader_parameter("time_now", fposmod(float(sim.elapsed), 2048.0))
	var status: Dictionary = sim.atmosphere_status()
	_camera_haze = Atmosphere.sample(sim, camera.global_position, sim.velocity)
	_entry_strength = 0.0
	var inside := bool(status.get("inside", false))
	var speed := float(status.get("relative_speed", 0.0))
	var heat := float(status.get("heat", 0.0)) / 100.0
	var density := float(status.get("density", 0.0))
	if inside and not settled and is_finite(speed) and is_finite(heat) and is_finite(density):
		_entry_strength = clampf(smoothstep(0.04, 0.66, heat) * smoothstep(20.0, 90.0, speed) * minf(1.0, density * 3.5), 0.0, 1.0)
	_entry.visible = _entry_strength > 0.006
	if not _entry.visible:
		return
	var site_id := int(status.get("site", -1))
	if not _shells.has(site_id):
		_entry.hide()
		return
	var relative_velocity: Vector3 = sim.velocity - sim.target_velocity(site_id)
	if not relative_velocity.is_finite() or relative_velocity.length_squared() < 0.0001:
		_entry.hide()
		return
	var direction := relative_velocity.normalized()
	var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.95 else Vector3.UP
	_entry.position = sim.position
	_entry.look_at(_entry.global_position + direction, up)
	_entry_paint.set_shader_parameter("strength", _entry_strength)
	_entry_paint.set_shader_parameter("time_now", fposmod(float(sim.elapsed), 2048.0))
	_entry_paint.set_shader_parameter("air_color", Atmosphere.profile(site_id).color)
	_streak_paint.set_shader_parameter("strength", _entry_strength)
	_streak_paint.set_shader_parameter("time_now", fposmod(float(sim.elapsed), 2048.0))


func local_haze() -> Dictionary:
	return _camera_haze.duplicate(true)


static func _atmosphere_shader() -> Shader:
	if _air_shader != null:
		return _air_shader
	_air_shader = Shader.new()
	_air_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 body_center;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec4 air_color : source_color = vec4(0.34, 0.63, 0.85, 1.0);
uniform float body_radius = 150.0;
uniform float air_height = 30.0;
uniform float air_density = 1.0;
uniform bool inside_volume = false;
uniform int profile = 1;
uniform float time_now = 0.0;
varying vec3 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Render one interface of the volume, including when the camera is inside.
	if (FRONT_FACING == inside_volume) discard;
	vec3 origin = CAMERA_POSITION_WORLD - body_center;
	vec3 ray = normalize(world_point - CAMERA_POSITION_WORLD);
	float outer = body_radius + air_height;
	float b = dot(origin, ray);
	float discriminant = b * b - dot(origin, origin) + outer * outer;
	if (discriminant <= 0.0) discard;
	float root = sqrt(discriminant);
	float start = max(0.0, -b - root);
	float finish = -b + root;
	float ground = b * b - dot(origin, origin) + body_radius * body_radius;
	if (ground > 0.0) {
		float first_ground = -b - sqrt(ground);
		if (first_ground > 0.0) finish = min(finish, first_ground);
	}
	float span = max(0.0, finish - start);
	float optical = 0.0;
	float daylight = 0.0;
	float steps = profile == 0 ? 3.0 : (profile == 1 ? 5.0 : 7.0);
	for (int i = 0; i < 7; i++) {
		if (float(i) >= steps) break;
		vec3 point = origin + ray * (start + span * (float(i) + 0.5) / steps);
		float altitude = max(0.0, length(point) - body_radius);
		float depth = clamp((air_height - altitude) / max(1.0, air_height), 0.0, 1.0);
		float density = depth * depth;
		optical += density;
		daylight += density * smoothstep(-0.24, 0.50, dot(normalize(point), sun_direction));
	}
	float light = daylight / max(optical, 0.0001);
	optical *= span / (steps * max(1.0, air_height));
	float opacity = min(0.48, 1.0 - exp(-optical * air_density * 0.46));
	float view_sun = dot(ray, sun_direction);
	float phase = 0.72 + 0.28 * view_sun * view_sun;
	vec3 color = air_color.rgb * (0.18 + light * 0.82) * phase;
	float sunset = (1.0 - abs(light * 2.0 - 1.0)) * max(0.0, dot(ray, sun_direction));
	color = mix(color, vec3(0.93, 0.53, 0.27), sunset * 0.22);
	if (profile > 0) {
		vec3 p = normalize(origin + ray * (start + span * 0.5));
		float strands = sin(p.x * 39.0 + p.z * 25.0 + sin(p.y * 31.0) * 1.8 + time_now * 0.018);
		color *= 1.0 + strands * 0.018;
	}
	ALBEDO = color;
	ALPHA = opacity;
}
"""
	return _air_shader


func _build_entry() -> void:
	_entry = Node3D.new()
	_entry.name = "AtmosphericEntry"
	add_child(_entry)
	var shell := SphereMesh.new()
	shell.radius = 2.0
	shell.height = 4.0
	shell.radial_segments = 24
	shell.rings = 14
	if _entry_shader == null:
		_entry_shader = Shader.new()
		_entry_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
uniform float strength = 0.0;
uniform float time_now = 0.0;
uniform int profile = 1;
uniform vec4 air_color : source_color;
varying vec3 local_point;
void vertex() { local_point = normalize(VERTEX); }
void fragment() {
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), VIEW)), 1.35);
	float leading = 0.15 + (1.0 - smoothstep(-0.75, 0.35, local_point.z)) * 0.85;
	float flow = 0.88;
	if (profile > 0) flow += sin(local_point.z * 31.0 - time_now * 24.0 + local_point.x * 13.0) * 0.12;
	vec3 plasma = mix(vec3(1.0, 0.22, 0.035), vec3(1.0, 0.74, 0.30), leading * 0.72);
	plasma = mix(plasma, air_color.rgb, 0.08);
	ALBEDO = plasma * 1.5;
	ALPHA = edge * leading * flow * strength * 0.39;
}
"""
	_entry_paint = ShaderMaterial.new()
	_entry_paint.shader = _entry_shader
	_sheath = MeshInstance3D.new()
	_sheath.mesh = shell
	_sheath.material_override = _entry_paint
	_sheath.scale = Vector3(1.0, 0.60, 1.48)
	_sheath.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_entry.add_child(_sheath)
	if _streak_shader == null:
		_streak_shader = Shader.new()
		_streak_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float strength = 0.0;
uniform float time_now = 0.0;
varying float phase;
void vertex() { phase = INSTANCE_CUSTOM.r; }
void fragment() {
	float trail = sin(UV.y * 3.141593);
	float pulse = 0.65 + sin(time_now * 19.0 + phase * 35.0) * 0.35;
	ALBEDO = mix(vec3(1.0, 0.27, 0.045), vec3(1.0, 0.76, 0.33), UV.y);
	ALPHA = trail * pulse * strength * 0.54;
}
"""
	_streak_paint = ShaderMaterial.new()
	_streak_paint.shader = _streak_shader
	var line := CylinderMesh.new()
	line.top_radius = 0.008
	line.bottom_radius = 0.025
	line.height = 1.0
	line.radial_segments = 5
	line.rings = 1
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	batch.mesh = line
	batch.instance_count = MAX_STREAKS
	for index in range(MAX_STREAKS):
		var phase := float(index) / MAX_STREAKS
		var angle := phase * TAU * 2.618
		var length := 1.8 + fposmod(float(index) * 0.37, 2.3)
		var radial := Vector3(cos(angle) * 2.0, sin(angle) * 1.05, 0.0)
		var basis := Basis(Vector3.RIGHT, PI * 0.5)
		basis.y *= length
		batch.set_instance_transform(index, Transform3D(basis, radial + Vector3(0.0, 0.0, length * 0.35)))
		batch.set_instance_custom_data(index, Color(phase, 0, 0, 0))
	_streaks = MultiMeshInstance3D.new()
	_streaks.multimesh = batch
	_streaks.material_override = _streak_paint
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_entry.add_child(_streaks)
