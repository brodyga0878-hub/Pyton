extends Node3D
# A persistent sibling of SurfaceVisual: terrain streaming never rebuilds cities.
# This consumes already compiled city_data and never invokes the source model VM.
const Visual=preload("res://scripts/source_model_visual.gd")
const Runtime=preload("res://scripts/source_city_runtime.gd")
const CACHE_LIMIT:=8
const LEGACY_REVISIONS:=["sphere-v1","sphere-source-sites-v2"]
var last_error:=""
var active_key:=""
var build_count:=0
var cached_cities:Dictionary={}
var _recent:Array[String]=[]

func current_visual()->Node3D:
	return cached_cities.get(active_key,null)

func _hide_cities()->void:
	visible=false
	for city in cached_cities.values():city.visible=false

func _fail(message:String)->bool:
	last_error=message
	active_key=""
	_hide_cities()
	return false

func _touch(key:String)->void:
	_recent.erase(key)
	_recent.append(key)

func _trim_cache()->void:
	while _recent.size()>CACHE_LIMIT:
		var key:String=_recent.pop_front()
		var obsolete:Node3D=cached_cities[key]
		cached_cities.erase(key)
		remove_child(obsolete)
		obsolete.queue_free()

func clear_cache()->void:
	for city in cached_cities.values():
		remove_child(city)
		city.queue_free()
	cached_cities.clear()
	_recent.clear()
	active_key=""
	last_error=""
	visible=false

func configure(draw:RefCounted,outer_frame:Transform3D,view_coverage:=1.0)->bool:
	last_error=""
	if not outer_frame.is_finite() or not is_finite(view_coverage):
		return _fail("Non-finite source city view frame or coverage")
	transform=outer_frame
	if draw==null or draw.get("active")!=true or draw.get("globe")==null:
		active_key=""
		_hide_cities()
		return true
	var globe:RefCounted=draw.globe
	if str(globe.revision) in LEGACY_REVISIONS:
		active_key=""
		_hide_cities()
		return true
	var data:Variant=draw.get("city_data")
	if data==null or (data is Dictionary and data.is_empty()):
		active_key=""
		_hide_cities()
		return true
	if not data is Dictionary or not data.get("ok",false):
		return _fail("Source city runtime data failed: "+str(data.get("error","invalid city_data") if data is Dictionary else "invalid city_data"))
	if not data.get("profile") is Dictionary or not data.get("compiled") is Dictionary or not data.get("conversion_basis") is Basis:
		return _fail("Incomplete source city runtime data")
	var profile:Dictionary=data.profile
	var key:String=str(profile.get("key",""))
	if key.is_empty() or not data.compiled.get("ok",false):
		return _fail("Missing source city identity or unsuccessful compiled model")
	var placement:Transform3D=Runtime.transform_to_frame(profile,globe)
	if not placement.is_finite() or not data.conversion_basis.is_finite():
		return _fail("Non-finite source city placement or geometry basis")
	# Coverage and inactive previews never allocate a mesh merely to hide it.
	if view_coverage<0.5:
		active_key=key if cached_cities.has(key) else ""
		_hide_cities()
		if not active_key.is_empty():cached_cities[key].transform=placement
		return true
	if not cached_cities.has(key):
		var city:=Visual.new()
		if not city.configure(data.compiled,data.conversion_basis):
			city.free()
			return _fail("Source city visual rejected compiled geometry for "+key)
		city.name="SourceCity%d"%build_count
		city.set_meta("source_city_key",key)
		add_child(city)
		cached_cities[key]=city
		build_count+=1
	_touch(key)
	_trim_cache()
	active_key=key
	for cached_key in cached_cities:
		cached_cities[cached_key].visible=cached_key==key
	cached_cities[key].transform=placement
	visible=true
	return true
