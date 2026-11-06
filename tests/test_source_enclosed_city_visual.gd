extends SceneTree
const Controller=preload("res://scripts/source_underground_controller.gd")
const Hangar=preload("res://scripts/source_underground_port.gd")
const View=preload("res://scripts/source_city_view.gd")
class Globe:
	extends RefCounted
	var revision:="sphere-source-ground-v4"
	var city_profiles:Dictionary={}
	var latitude:=0.0
	var longitude:=0.0
	var radius:=3961260.0
class Drawing:
	extends RefCounted
	var active:=true
	var globe:RefCounted
	var city_data:Dictionary={}
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var site:={"id":"native96-visual","type_code":35,"model_index":96,"source_seed":0xd1d76465,"ground_phase_u16":26563,"ground_inclination_u16":1585}
	var profile:=Hangar.describe(site,3961260.0);profile.terrain_revision=Controller.TERRAIN_REVISION
	var globe:=Globe.new();globe.latitude=profile.root_latitude;globe.longitude=profile.root_longitude;globe.city_profiles[site.id]=profile
	var controller:=Controller.new()
	check(controller.configure(site,globe),"Actual96 compiled controller data available for rendering")
	var draw:=Drawing.new();draw.globe=globe;draw.city_data=controller.data
	var view:=View.new();root.add_child(view)
	check(view.configure(draw,Transform3D.IDENTITY),"Closed original96 visual renders")
	var visual:Node3D=view.current_visual();var static_id:int=visual.static_visual.get_instance_id()
	check(visual.static_build_count==1 and visual.dynamic_build_count==1,"Static city and real hatch allocated once")
	for door in [32768,0,16384,65535]:
		draw.city_data=controller.prepare_pose(door)
		check(view.configure(draw,Transform3D.IDENTITY),"Exact moving hatch pose renders")
		check(view.current_visual()==visual and view.cached_cities.size()==1,"Door motion retains one city cache entry")
		check(visual.static_visual.get_instance_id()==static_id and visual.static_build_count==1,"Door updates preserve immutable ten-thousand-face city mesh")
		check(visual.door_u16==door,"Visible hatch follows paired published door word")
	check(view.build_count==1 and visual.dynamic_build_count==5,"Only source237 subtree rebuilds")
	view.set_quality(0);check(visual.quality==0 and visual.static_visual.quality==0 and visual.dynamic_visual.quality==0,"Both source parts obey graphics quality")
	check(view.configure(null,Transform3D.IDENTITY) and not view.visible,"No surface hides the source hangar")
	view.queue_free();await process_frame
	print("SOURCE ENCLOSED CITY VISUAL TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
