extends Node3D

const TEXTURE_WIDTH := 1024
const TEXTURE_HEIGHT := 512
const CORONA_SPAN := 1.48
const MARKER_RADIUS := 10.5

static var _shared_plasma: ImageTexture

var _radius := 0.0
var _corona: MeshInstance3D
var _sphere: SphereMesh
var _photosphere_paint: ShaderMaterial
var _corona_paint: ShaderMaterial
var _guide: MeshInstance3D
var _guide_paint: StandardMaterial3D
var _scoop_stream: MeshInstance3D
var _visual_profile := 1


func setup(star: Dictionary, scoop_inner: float, scoop_outer: float, cool := false) -> void:
	position = star.center
	_radius = star.radius
	_build_photosphere(cool)
	_build_corona(cool)
	set_visual_profile(_visual_profile)
	var safe_offset := clampf(float(star.pad_offset), scoop_inner, scoop_outer)
	_build_guide(safe_offset)
	_build_scoop_stream()

	var glow := OmniLight3D.new()
	glow.light_color = Color("#9dcbff") if cool else Color("#ffb461")
	glow.light_energy = 1.65
	glow.omni_range = 950.0
	glow.omni_attenuation = 1.7
	glow.shadow_enabled = false
	add_child(glow)


func set_visual_profile(profile: int) -> void:
	_visual_profile = clampi(profile, 0, 2)
	if _sphere == null:
		return
	_sphere.radial_segments = [40, 64, 80][_visual_profile]
	_sphere.rings = [24, 36, 48][_visual_profile]
	_photosphere_paint.set_shader_parameter("profile", _visual_profile)
	_corona_paint.set_shader_parameter("profile", _visual_profile)


func update_approach(camera_position: Vector3, ship_position: Vector3, active_target: bool, scooping: bool) -> void:
	var camera_offset := camera_position - global_position
	var camera_distance := camera_offset.length()
	_corona.visible = camera_distance > _radius + 1.0
	if _corona.visible:
		var axis := camera_offset / camera_distance
		var up := Vector3.FORWARD if absf(axis.y) > 0.96 else Vector3.UP
		_corona.look_at(camera_position, up, true)
		# Match the projected spherical limb from a plane through the star's center.
		var ratio := _radius / camera_distance
		var projected_radius := _radius / sqrt(maxf(0.12, 1.0 - ratio * ratio))
		_corona.scale = Vector3.ONE * (2.0 * projected_radius * CORONA_SPAN)

	_guide.visible = active_target and ship_position.distance_squared_to(global_position) < 1210000.0
	_guide.visible = _guide.visible and ship_position.distance_squared_to(_guide.global_position) > 729.0
	if _guide.visible:
		_guide_paint.albedo_color = Color("#6ff5d6") if scooping else Color("#9edaff")
	_scoop_stream.visible = scooping
	if scooping:
		_scoop_stream.global_position = ship_position
		var inward := (global_position - ship_position).normalized()
		var up := Vector3.FORWARD if absf(inward.y) > 0.96 else Vector3.UP
		_scoop_stream.look_at(global_position, up)


func _build_photosphere(cool: bool) -> void:
	_sphere = SphereMesh.new()
	_sphere.radius = _radius
	_sphere.height = _radius * 2.0
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D plasma : filter_linear_mipmap, repeat_enable;
uniform bool cool = false;
uniform int profile = 1;
void fragment() {
	vec2 uv = vec2(UV.x + TIME * 0.006, UV.y);
	vec2 cells = texture(plasma, uv).rg;
	float heat = cells.r * 0.91 + cells.g * 0.09;
	float granules = 0.0;
	if (profile > 0) {
		vec2 flow = uv + vec2(sin(UV.y * 18.0 - TIME * 0.39) * 0.013 + TIME * 0.005, 0.0);
		heat += (texture(plasma, flow).r - cells.r) * 0.25;
	}
	if (profile == 2) {
		vec2 inner = texture(plasma, uv * vec2(4.0, 1.0) - vec2(TIME * 0.023, 0.0)).rg;
		granules = (inner.g - 0.5) * sin(UV.y * 3.141593);
		heat += granules * 0.14;
	}
	float ribbons = smoothstep(0.24, 0.67, heat);
	float sparks = smoothstep(0.45, 0.77, heat + cells.g * 0.11 + granules * 0.19);
	vec3 low = cool ? vec3(0.10, 0.22, 0.54) : vec3(0.51, 0.055, 0.010);
	vec3 high = cool ? vec3(0.43, 0.75, 1.0) : vec3(1.0, 0.54, 0.105);
	vec3 peak = cool ? vec3(0.93, 0.99, 1.0) : vec3(1.0, 0.91, 0.54);
	float limb = smoothstep(0.0, 0.63, max(dot(normalize(NORMAL), VIEW), 0.0));
	ALBEDO = mix(mix(low, high, ribbons), peak, sparks * 0.76) * (0.69 + limb * 0.31);
}
"""
	_photosphere_paint = ShaderMaterial.new()
	_photosphere_paint.shader = shader
	if _shared_plasma == null:
		_shared_plasma = _plasma_texture()
	_photosphere_paint.set_shader_parameter("plasma", _shared_plasma)
	_photosphere_paint.set_shader_parameter("cool", cool)
	_add_mesh(_sphere, _photosphere_paint)


static func _plasma_texture() -> ImageTexture:
	# Evaluate a volume on a sphere so the longitude seam and poles join naturally.
	var noise := FastNoiseLite.new()
	noise.seed = 20351
	noise.frequency = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var image := Image.create_empty(TEXTURE_WIDTH, TEXTURE_HEIGHT, false, Image.FORMAT_RG8)
	var directions := PackedVector2Array()
	for x in range(TEXTURE_WIDTH):
		var longitude := TAU * (float(x) + 0.5) / float(TEXTURE_WIDTH)
		directions.append(Vector2(cos(longitude), sin(longitude)))
	for y in range(TEXTURE_HEIGHT):
		var latitude := PI * (float(y) + 0.5) / float(TEXTURE_HEIGHT)
		var equator := sin(latitude)
		var height := cos(latitude)
		var row := Vector3(0.0, height, 0.0)
		for x in range(TEXTURE_WIDTH):
			var direction := directions[x] * equator
			var point := row + Vector3(direction.x, 0.0, direction.y)
			var patches := noise.get_noise_3dv(point * 6.0) * 0.5 + 0.5
			var convection := 1.0 - absf(noise.get_noise_3dv(point * 23.0 + Vector3(2.1, 6.0, 3.5)))
			var grains := noise.get_noise_3dv(point * 66.0 + Vector3(11.0, 1.4, 3.0)) * 0.5 + 0.5
			var heat := patches * 0.47 + pow(convection, 5.0) * 0.35 + grains * 0.18
			image.set_pixel(x, y, Color(heat, grains, 0.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _build_corona(cool: bool) -> void:
	var quad := QuadMesh.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform bool cool = false;
uniform int profile = 1;
void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * 1.48;
	float r = length(p);
	if (r > 1.47) {
		discard;
	}
	float rays = 0.0;
	float tongues = 0.0;
	float arcs = 0.0;
	if (profile > 0) {
		float angle = atan(p.y, p.x + 0.000001);
		rays = 0.5 + 0.5 * sin(angle * 23.0 + sin(angle * 7.0) * 1.8 + TIME * 0.21);
		tongues = max(0.0, sin(angle * 9.0 + sin(angle * 4.0 + sin(angle * 3.0)) * 2.2 - TIME * 0.16));
		if (profile == 2) {
			float loops = sin(angle * 16.0 + (r - 1.0) * 11.0 + sin(angle * 3.0 - TIME * 0.17));
			arcs = smoothstep(0.75, 0.96, loops) * (1.0 - smoothstep(1.02, 1.30, r));
		}
	}
	float fringe = (1.0 - smoothstep(1.0, 1.11 + tongues * 0.17, r)) * (0.56 + rays * 0.44);
	float haze = (1.0 - smoothstep(1.0, 1.47, r)) * (0.68 + tongues * 0.32);
	vec3 outer = cool ? vec3(0.16, 0.35, 0.94) : vec3(0.90, 0.20, 0.024);
	vec3 inner = cool ? vec3(0.54, 0.80, 1.0) : vec3(1.0, 0.56, 0.11);
	ALBEDO = mix(outer, inner, fringe);
	ALPHA = fringe * 0.52 + haze * 0.23 + arcs * 0.12;
}
"""
	_corona_paint = ShaderMaterial.new()
	_corona_paint.shader = shader
	_corona_paint.set_shader_parameter("cool", cool)
	_corona = _add_mesh(quad, _corona_paint)
	_corona.visible = false


func _build_guide(offset: float) -> void:
	var triangles := SurfaceTool.new()
	triangles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := Color("#12232e")
	for turn in range(4):
		var center_angle := TAU * float(turn) / 4.0 + PI * 0.25
		for segment in range(10):
			var first := center_angle - 0.37 + float(segment) * 0.074
			var last := first + 0.074
			_add_guide_strip(triangles, first, last, 0.32, 0.0, dark)
			_add_guide_strip(triangles, first, last, 0.11, 0.04, Color.WHITE)

	_guide_paint = StandardMaterial3D.new()
	_guide_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_guide_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_guide_paint.vertex_color_use_as_albedo = true
	_guide = _add_mesh(triangles.commit(), _guide_paint)
	_guide.position = Vector3.BACK * offset
	_guide.visible = false


func _add_guide_strip(triangles: SurfaceTool, first: float, last: float, width: float, depth: float, color: Color) -> void:
	var start := Vector3(cos(first), sin(first), 0.0)
	var end := Vector3(cos(last), sin(last), 0.0)
	var lift := Vector3.BACK * depth
	var points := [
		start * (MARKER_RADIUS - width) + lift, start * (MARKER_RADIUS + width) + lift,
		end * (MARKER_RADIUS - width) + lift, end * (MARKER_RADIUS + width) + lift,
	]
	for point in [0, 1, 2, 1, 3, 2]:
		triangles.set_color(color)
		triangles.add_vertex(points[point])


func _build_scoop_stream() -> void:
	var shapes := SurfaceTool.new()
	shapes.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ray in range(20):
		var angle := float(ray) * 2.39996
		var span := 0.6 + float(ray % 6) * 0.14
		var outward := Vector3(cos(angle), sin(angle), 0.0)
		var tangent := Vector3(-outward.y, outward.x, 0.0)
		for point: Vector3 in [
			outward * span, outward * span + tangent * 0.036 + Vector3.BACK * 2.0,
			outward * span - tangent * 0.036 + Vector3.BACK * 2.0,
		]:
			shapes.set_uv(Vector2(float((ray * 7) % 20) / 20.0, float(ray % 4) / 4.0))
			shapes.add_vertex(point)

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
varying float visibility;
void vertex() {
	float age = fract(UV.x + TIME * (0.58 + UV.y * 0.33));
	VERTEX.xy *= mix(14.0, 1.3, age);
	VERTEX.z -= mix(30.0, 2.2, age);
	visibility = smoothstep(0.0, 0.14, age) * (1.0 - smoothstep(0.82, 1.0, age));
}
void fragment() {
	ALBEDO = vec3(0.32, 0.90, 0.95);
	ALPHA = visibility * 0.73;
}
"""
	var paint := ShaderMaterial.new()
	paint.shader = shader
	_scoop_stream = _add_mesh(shapes.commit(), paint)
	_scoop_stream.custom_aabb = AABB(Vector3(-18.0, -18.0, -32.0), Vector3(36.0, 36.0, 34.0))
	_scoop_stream.visible = false


func _add_mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	return item
