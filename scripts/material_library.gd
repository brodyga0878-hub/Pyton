extends RefCounted
## Original tiled PBR maps; a shared resource per family/channel. No geometry changes.
## Albedo uses sRGB; normal/ORM are linear. ORM = ambient occlusion, roughness, metal.
const ROOT := "res://assets/materials/"
const KINDS := ["painted_alloy", "brushed_metal", "concrete", "asphalt", "rock", "ice", "rubber", "glass"]
const CHANNELS := ["albedo", "normal", "orm"]
static var _textures: Dictionary = {}
static var _manifest: Dictionary = {}

static func metadata() -> Dictionary:
	if _manifest.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
		if parsed is Dictionary:
			_manifest = parsed
	return _manifest.duplicate(true)

static func texture(kind: String, channel: String) -> Texture2D:
	if channel in ["basecolor", "base_color"]:
		channel = "albedo"
	if not kind in KINDS or not channel in CHANNELS:
		return null
	var path := ROOT + kind + "/" + channel + ".png"
	if not _textures.has(path):
		var loaded: Texture2D = load(path) as Texture2D
		if loaded == null:
			return null
		_textures[path] = loaded
	return _textures[path] as Texture2D

static func albedo_gain(kind: String) -> float:
	if _manifest.is_empty():
		metadata()
	var entry: Dictionary = _manifest.get("materials", {}).get(kind, {})
	return 1.0 / maxf(float(entry.get("mean_linear_luminance", 1.0)), 0.01)

static func roughness_mean(kind: String) -> float:
	if _manifest.is_empty():
		metadata()
	var entry: Dictionary = _manifest.get("materials", {}).get(kind, {})
	return float(entry.get("mean_roughness", 0.5))

static func apply_shader(material: ShaderMaterial, kind: String, scale: float = 1.0) -> bool:
	if material == null or not kind in KINDS or not is_finite(scale) or scale <= 0.0:
		return false
	for channel in CHANNELS:
		var map := texture(kind, channel)
		if map == null:
			return false
		material.set_shader_parameter("material_" + channel, map)
	material.set_shader_parameter("material_scale", scale)
	material.set_shader_parameter("material_gain", albedo_gain(kind))
	return true

static func apply_standard(material: StandardMaterial3D, kind: String, scale: float = 1.0) -> bool:
	if material == null or not kind in KINDS or not is_finite(scale) or scale <= 0.0:
		return false
	var color_map := texture(kind, "albedo")
	var normal_map := texture(kind, "normal")
	var orm := texture(kind, "orm")
	if color_map == null or normal_map == null or orm == null:
		return false
	# Preserve the existing tint, transparency, culling, emission and shading mode.
	# Existing materials can use this without changing their source colour palette.
	material.albedo_texture = color_map
	material.normal_enabled = true
	material.normal_texture = normal_map
	material.normal_scale = 1.0
	material.ao_enabled = true
	material.ao_texture = orm
	material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.ao_light_affect = 0.0
	material.roughness_texture = orm
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.roughness = 1.0
	material.metallic_texture = orm
	material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	material.metallic = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = true
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_scale = Vector3.ONE * scale
	material.uv1_triplanar_sharpness = 4.0
	return true
