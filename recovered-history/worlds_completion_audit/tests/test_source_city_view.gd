extends SceneTree
const View=preload("res://scripts/source_city_view.gd")
const Runtime=preload("res://scripts/source_city_runtime.gd")
const Profile=preload("res://scripts/source_city_profile.gd")
const Units=preload("res://scripts/source_units.gd")
class FakeGlobe extends RefCounted:
	var revision:="sphere-source-city-v3"
	var radius:=6371000.0
	var latitude:=0.1
	var longitude:=0.2
	func basis_at(lat:float,lon:float)->Basis:
		return Profile.basis_at(lat,lon)
class FakeSurface extends RefCounted:
	var active:=true
	var globe:RefCounted
	var city_data:Dictionary={}
var checks:=0
var failures:=0

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)

func _init()->void:call_deferred("run")

func data_for(key:String)->Dictionary:
	var root_basis:=Profile.basis_at(0.1,0.2)
	var profile:Dictionary={"key":key,"model_index":89,"source_seed":123,
		"root_latitude":0.1,"root_longitude":0.2,"root_basis":root_basis,
		"root_elevation_m":17.0}
	var face:Dictionary={"vertices":[[0,0,0],[1000000,0,0],[0,0,1000000]],
		"material_code":0x765,"instance_path":"stub","offset":1}
	var compiled:Dictionary={"ok":true,"model_index":89,"triangles_raw":[face],"source_events":[]}
	return {"ok":true,"profile":profile,"compiled":compiled,"conversion_basis":root_basis.inverse(),"bounds":AABB(Vector3(-10,0,-10),Vector3(20,50,20))}

func run()->void:
	var draw:=FakeSurface.new();draw.globe=FakeGlobe.new();draw.city_data=data_for("city0")
	var view:=View.new();root.add_child(view)
	for legacy in ["sphere-v1","sphere-source-sites-v2"]:
		draw.globe.revision=legacy
		check(view.configure(draw,Transform3D.IDENTITY) and not view.visible and view.get_child_count()==0,"Legacy terrain does not acquire source city geometry")
	draw.globe.revision="sphere-source-city-v3"
	draw.active=false
	check(view.configure(draw,Transform3D.IDENTITY) and view.build_count==0,"Inactive drawing never constructs source geometry")
	draw.active=true
	check(view.configure(draw,Transform3D.IDENTITY,0.49) and view.build_count==0,"An initially faded city does not allocate a hidden mesh")
	var inputs_before:=JSON.stringify(draw.city_data)
	check(view.configure(draw,Transform3D.IDENTITY) and view.visible,"Ready source city is shown")
	var city:Node3D=view.current_visual()
	var mesh:MeshInstance3D=city.get_child(0)
	var geometry:Mesh=mesh.mesh
	check(view.build_count==1 and view.get_child_count()==1 and city.triangle_count==1,"One synthetic compiled city creates one persistent node")
	check(city.transform.is_equal_approx(Runtime.transform_to_frame(draw.city_data.profile,draw.globe)),"Runtime computes source root placement")
	var vertices:PackedVector3Array=geometry.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var expected:Vector3=draw.city_data.conversion_basis*Vector3(1000000,0,0)*Units.METRES_PER_RAW
	check(vertices[1].distance_to(expected)<0.001,"Provided body-fixed conversion basis is applied exactly once")
	check(city.transform.origin.distance_to(Vector3(0,17,0))<0.001,"Root elevation is retained at the initial frame")
	var old_placement:Transform3D=city.transform
	draw.globe.longitude+=512.0/draw.globe.radius
	check(view.configure(draw,Transform3D.IDENTITY) and city==view.current_visual() and mesh.mesh==geometry and view.build_count==1,"A 512-metre terrain rebase retains the source mesh")
	check(not city.transform.is_equal_approx(old_placement) and city.transform.is_equal_approx(Runtime.transform_to_frame(draw.city_data.profile,draw.globe)),"Only city placement follows a terrain rebase")
	var outer:=Transform3D(Basis(Vector3.UP,0.7),Vector3(4000,8000,-16000))
	check(view.configure(draw,outer) and view.transform==outer and view.current_visual()==city,"Orbital preview uses the outer geographic frame without rebuilding")
	check(city.global_transform.is_equal_approx(view.global_transform*Runtime.transform_to_frame(draw.city_data.profile,draw.globe)),"Preview and local city transform compose once")
	check(view.configure(draw,Transform3D.IDENTITY) and view.current_visual()==city and mesh.mesh==geometry,"Preview-to-descent handoff preserves the same source mesh")
	check(view.configure(draw,Transform3D.IDENTITY,0.49) and not view.visible and is_instance_valid(city),"Coverage hides a city without freeing it")
	check(view.configure(null,Transform3D.IDENTITY) and not view.visible and is_instance_valid(city),"Leaving the surface retains the cached city")
	check(view.configure(draw,Transform3D.IDENTITY,0.5) and view.visible and view.current_visual()==city,"Half coverage and return restore the same cached mesh")
	check(JSON.stringify(draw.city_data)==inputs_before,"The visual does not mutate compiled runtime inputs")
	# No pad-distance or terrain-width gate: a 30-km city can extend beyond the pad.
	draw.globe.longitude+=30000.0/draw.globe.radius
	check(view.configure(draw,Transform3D.IDENTITY) and view.visible and view.current_visual()==city,"A source city remains eligible outside the 4-km terrain district")
	var weak_city:WeakRef=weakref(city)
	for index in range(1,8):
		draw.city_data=data_for("city%d"%index)
		check(view.configure(draw,Transform3D.IDENTITY),"New ready city enters bounded visual cache")
	check(view.cached_cities.size()==8 and view.get_child_count()==8,"Eight source cities bound retained node instances")
	draw.city_data=data_for("city0");view.configure(draw,Transform3D.IDENTITY)
	draw.city_data=data_for("city8");view.configure(draw,Transform3D.IDENTITY)
	check(view.cached_cities.has("city0") and not view.cached_cities.has("city1") and view.cached_cities.size()==8,"Cache eviction follows actual recent use")
	check(view.current_visual().triangle_count==1,"Cached synthetic geometry remains valid after eviction")
	draw.city_data={"ok":false,"error":"synthetic rejection"}
	check(not view.configure(draw,Transform3D.IDENTITY) and not view.visible and view.last_error.contains("synthetic rejection"),"Runtime failure is explicit and does not display another city")
	draw.city_data=data_for("invalidvisual");draw.city_data.compiled.triangles_raw=[]
	check(not view.configure(draw,Transform3D.IDENTITY) and not view.last_error.is_empty() and not view.cached_cities.has("invalidvisual"),"Rejected geometry reports failure without entering the cache")
	view.clear_cache()
	check(view.get_child_count()==0 and view.cached_cities.is_empty() and not view.visible,"Explicit teardown releases retained city nodes")
	await process_frame
	check(weak_city.get_ref()==null,"Queued cached nodes are actually freed")
	view.queue_free();await process_frame
	print("SOURCE CITY VIEW TESTS: %d checks, %d failures; synthetic geometry only"%[checks,failures])
	quit(1 if failures else 0)
