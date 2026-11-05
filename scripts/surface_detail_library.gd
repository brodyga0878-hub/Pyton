extends RefCounted
# Dedicated authored ship surfaces; canonical hull coordinates stay independent
# of camera motion, floating-origin translation, span and mesh UV conventions.
const ROOT:="res://assets/surface_details/ships/"
const PROFILES:=["cobra","eagle","shuttle"]
const CHANNELS:=["albedo","normal","orm"]
static var _textures:Dictionary={}
static var _metadata:Dictionary={}

static func metadata()->Dictionary:
	if _metadata.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
		if parsed is Dictionary:_metadata=parsed
	return _metadata.duplicate(true)

static func texture(profile_id:String,channel:String)->Texture2D:
	if not profile_id in PROFILES or not channel in CHANNELS:return null
	var key:=profile_id+"/"+channel
	if not _textures.has(key):_textures[key]=load(ROOT+key+".png") as Texture2D
	return _textures[key] as Texture2D

static func projection_extent(profile_id:String,span:float)->Vector2:
	if not profile_id in PROFILES or not is_finite(span) or span<8.0 or span>100.0:return Vector2.ZERO
	var factors:Vector2={"cobra":Vector2.ONE,"eagle":Vector2(0.90,1.20),"shuttle":Vector2(0.82,0.96)}[profile_id]
	return factors*span

static func atlas_uv(profile_id:String,span:float,point:Vector3)->Vector2:
	var extent:=projection_extent(profile_id,span)
	if extent==Vector2.ZERO or not point.is_finite():return Vector2(INF,INF)
	return Vector2(point.x,point.z)/extent+Vector2(0.5,0.5)

static func bind_hull(material:ShaderMaterial,profile_id:String,span:float)->bool:
	if material==null or projection_extent(profile_id,span)==Vector2.ZERO:return false
	var maps:Array[Texture2D]=[]
	for channel in CHANNELS:
		var map:=texture(profile_id,channel)
		if map==null:return false
		maps.append(map)
	if _metadata.is_empty():metadata()
	var entry:Dictionary=_metadata.get("profiles",{}).get(profile_id,{})
	for i in range(CHANNELS.size()):material.set_shader_parameter("hull_"+CHANNELS[i],maps[i])
	material.set_shader_parameter("hull_extent",projection_extent(profile_id,span))
	material.set_shader_parameter("hull_gain",1.0/maxf(float(entry.get("mean_linear_luminance",1.0)),0.01))
	material.set_shader_parameter("hull_enabled",true)
	return true
