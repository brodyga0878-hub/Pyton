extends RefCounted
# Original natural surface packs. Colour metadata is measured in linear light.
const ROOT:="res://assets/world_surfaces/"
const KINDS:=["earth","rock","desert","ice"]
const CHANNELS:=["albedo","normal","orm"]
static var _textures:Dictionary={}
static var _metadata:Dictionary={}

static func canonical_kind(kind:String)->String:
	return kind if kind in KINDS else "rock"

static func metadata()->Dictionary:
	if _metadata.is_empty() and FileAccess.file_exists(ROOT+"manifest.json"):
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
		if parsed is Dictionary:_metadata=parsed
	return _metadata.duplicate(true)

static func texture(kind:String,channel:String)->Texture2D:
	if not kind in KINDS or not channel in CHANNELS:return null
	var path:=ROOT+kind+"/"+channel+".png"
	if not _textures.has(path):
		var loaded:=load(path) as Texture2D
		if loaded==null:return null
		_textures[path]=loaded
	return _textures[path] as Texture2D

static func bind_shader(material:ShaderMaterial,kind:String,scale:float=1.0)->bool:
	if material==null or not kind in KINDS or not is_finite(scale) or scale<=0:return false
	if _metadata.is_empty():metadata()
	if int(_metadata.get("resolution",0))!=1024:return false
	var entry:Dictionary=_metadata.get("materials",{}).get(kind,{})
	var mean:float=float(entry.get("mean_linear_luminance",0.0))
	if not is_finite(mean) or mean<=0:return false
	var maps:Array[Texture2D]=[]
	for channel in CHANNELS:
		var map:=texture(kind,channel)
		if map==null:return false
		maps.append(map)
	for index in range(CHANNELS.size()):material.set_shader_parameter("material_"+CHANNELS[index],maps[index])
	material.set_shader_parameter("material_scale",scale)
	material.set_shader_parameter("material_gain",1.0/maxf(mean,0.01))
	return true

static func clear_material(material:ShaderMaterial)->void:
	if material==null:return
	for channel in CHANNELS:material.set_shader_parameter("material_"+channel,null)
