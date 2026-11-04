extends SceneTree
## Pixel-level PBR validity and resource/color contracts for authored maps.
const Materials = preload("res://scripts/material_library.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var manifest := Materials.metadata()
	check(manifest.get("resolution", 0) == 512, "Texture budget resolution is explicit")
	check(manifest.get("orm_channels", {}).get("g") == "roughness", "ORM channels have explicit physical semantics")
	for kind in Materials.KINDS:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(.15, .24, .67, .6)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.emission_enabled = true
		material.emission = Color(.3, .6, .9)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		var original_color := material.albedo_color
		check(Materials.apply_standard(material, kind, .2), kind + ": material binding succeeds")
		check(material.albedo_color == original_color, kind + ": original tint and alpha are exact")
		check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.cull_mode == BaseMaterial3D.CULL_DISABLED, kind + ": transparency/culling are preserved")
		check(material.emission == Color(.3, .6, .9) and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_VERTEX, kind + ": emission and shading mode are preserved")
		check(material.uv1_triplanar and not material.uv1_world_triplanar and material.texture_repeat, kind + ": texture coordinates use bounded object-space tiling")
		check(material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN and material.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE, kind + ": ORM channels bind without gamma conversion")
		var scalar_before := material.roughness
		check(not Materials.apply_standard(material, "missing_family", 1), "Invalid family rejected")
		check(not Materials.apply_standard(material, kind, NAN), "Invalid scale rejected")
		check(material.albedo_color == original_color and material.roughness == scalar_before, "Invalid input cannot mutate materials")
		for channel in Materials.CHANNELS:
			var map := Materials.texture(kind, channel)
			check(map != null and map == Materials.texture(kind, channel), kind + ": shared cache for " + channel)
			if map == null:
				continue
			check(map.get_width() == 512 and map.get_height() == 512, kind + ": bounded pixel dimensions for " + channel)
			var image := map.get_image()
			check(image.has_mipmaps(), kind + ": GPU imports have mipmaps for " + channel)
			# Sample the complete map sparsely across both axes, including wrapped edges.
			var valid_normals := true
			var valid_orm := true
			for y in range(0, 512, 13):
				for x in range(0, 512, 17):
					var color := image.get_pixel(x,y)
					if channel == "normal":
						var normal := Vector3(color.r, color.g, color.b)*2-Vector3.ONE
						valid_normals = valid_normals and absf(normal.length()-1) < .01 and normal.z > .5
					elif channel == "orm":
						valid_orm = valid_orm and color.r > .58 and color.g >= .039 and color.g <= .982
						if kind not in ["painted_alloy", "brushed_metal"]:
							valid_orm = valid_orm and color.b == 0
			check(valid_normals, kind + ": finite normalized positive-Z OpenGL tangent normals")
			check(valid_orm, kind + ": roughness bounds, local AO and dielectric metal mask")
		check(Materials.albedo_gain(kind) > 1 and Materials.albedo_gain(kind) < 3, kind + ": linear map normalization is measured")
		check(Materials.roughness_mean(kind) > .05 and Materials.roughness_mean(kind) < .98, kind + ": authored mean roughness is measured")
	check(Materials.texture("invalid", "normal") == null, "Unknown material doesn't attempt a resource load")
	check(Materials.texture("rock", "invalid") == null, "Unknown channel doesn't attempt a resource load")
	check(Materials.texture("rock", "basecolor") == Materials.texture("rock", "albedo"), "Basecolor alias preserves resource sharing")
	var copy := Materials.metadata()
	copy["resolution"] = 8
	check(Materials.metadata()["resolution"] == 512, "Metadata consumers cannot mutate the shared cache")
	# Shader samples are colour/gamma aware; the helper binds maps without editing tint.
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform sampler2D material_albedo:source_color; uniform sampler2D material_normal:hint_normal; uniform sampler2D material_orm; uniform float material_scale=1.0; uniform float material_gain=1.0; void fragment(){ALBEDO=texture(material_albedo,UV*material_scale).rgb*material_gain;NORMAL_MAP=texture(material_normal,UV*material_scale).rgb;ROUGHNESS=texture(material_orm,UV*material_scale).g;}"
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	check(Materials.apply_shader(shader_material, "rock", .2), "Shader map binding succeeds")
	check(shader_material.get_shader_parameter("material_albedo") == Materials.texture("rock", "albedo"), "Shader shares imported map resources")
	check(is_equal_approx(float(shader_material.get_shader_parameter("material_gain")), Materials.albedo_gain("rock")), "Shader gain uses linear measured albedo")
	check(not Materials.apply_shader(shader_material, "rock", -1), "Shader rejects a negative texture scale")
	print("MATERIAL LIBRARY TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
