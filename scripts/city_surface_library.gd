extends RefCounted
# Authored settlement atlas. Three shared maps replace four separate PBR packs.
const ROOT:="res://assets/city_surfaces/"
const CHANNELS:=["albedo","normal","orm"]
const ROLES:=["facade","road","pad","roof"]
static var _textures:Dictionary={}
static var _metadata:Dictionary={}

static func metadata()->Dictionary:
	if _metadata.is_empty() and FileAccess.file_exists(ROOT+"manifest.json"):
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
		if parsed is Dictionary:_metadata=parsed
	return _metadata.duplicate(true)

static func texture(channel:String)->Texture2D:
	if not channel in CHANNELS:return null
	if not _textures.has(channel):_textures[channel]=load(ROOT+channel+".png") as Texture2D
	return _textures[channel] as Texture2D

static func _role_values(key:String,fallback:float,inverse:=false)->Vector4:
	if _metadata.is_empty():metadata()
	var result:=Vector4.ONE*fallback
	for i in range(ROLES.size()):
		var role:Dictionary=_metadata.get("roles",{}).get(ROLES[i],{})
		var value:float=float(role.get(key,fallback))
		if not is_finite(value):value=fallback
		result[i]=1.0/maxf(value,0.01) if inverse else value
	return result

static func bind_shader(material:ShaderMaterial)->bool:
	if material==null:return false
	if _metadata.is_empty():metadata()
	if _metadata.get("resolution",0)!=2048 or _metadata.get("tile_size",0)!=1024 or _metadata.get("gutter",0)!=16:return false
	var maps:Array[Texture2D]=[]
	for channel in CHANNELS:
		var map:=texture(channel)
		if map==null:return false
		maps.append(map)
	for i in range(CHANNELS.size()):material.set_shader_parameter("city_"+CHANNELS[i],maps[i])
	material.set_shader_parameter("city_gains",_role_values("mean_linear_luminance",1.0,true))
	material.set_shader_parameter("city_scales",Vector4(0.125,0.0625,0.0625,0.125))
	material.set_shader_parameter("city_roughness",_role_values("mean_roughness",0.65))
	material.set_shader_parameter("city_metallic",_role_values("mean_metallic",0.0))
	material.set_shader_parameter("city_atlas_size",float(_metadata.resolution))
	material.set_shader_parameter("city_tile_size",float(_metadata.tile_size))
	material.set_shader_parameter("city_gutter",float(_metadata.gutter))
	material.set_shader_parameter("city_max_lod",minf(3.0,float(_metadata.get("max_safe_lod",3.0))))
	return true

static func clear_material(material:ShaderMaterial)->void:
	for channel in CHANNELS:material.set_shader_parameter("city_"+channel,null)
