extends SceneTree
const Scenery=preload("res://scripts/space_environment.gd")
const Station=preload("res://scripts/station_visual.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _init()->void:call_deferred("run")
func run()->void:
	var station:=Station.new();root.add_child(station);station.configure(2)
	check(station.geometry_batches==6,"Six material-batched station meshes")
	check(station.get_child_count()==7,"One label plus six batches bounds station draw groups")
	for child in station.get_children():
		if not child is MeshInstance3D:continue
		var bounds:AABB=child.mesh.get_aabb()
		check(bounds.position.is_finite() and bounds.size.is_finite(),"Station bounds finite")
		check(bounds.end.z < -110.0,"All station structure behind unchanged dockingpoint corridor")
	var initial_count:=station.get_child_count();station.configure(2)
	check(station.get_child_count()==initial_count,"Same quality does not rebuild station")
	var scenery:=Scenery.new();root.add_child(scenery);var anchor:=Vector3(0,0,-2500)
	scenery.configure(anchor,2)
	check(scenery.asteroid_count==275,"High-quality deterministic asteroid count")
	check(scenery.get_child_count()==16,"Eight asteroid variants across two LOD levels")
	var before:Array=[]
	for rock in scenery.rocks:
		var p:Vector3=rock.transform.origin-anchor
		check(Vector2(p.x,p.y).length()>float(rock.radius)*1.7+230,"Asteroids clear complete original approach cylinder")
		check(rock.transform.is_finite(),"Finite asteroid placement")
		var world_position:Vector3=rock.transform.origin
		var angular_size:=asin(clampf(float(rock.radius)*1.7/world_position.length(),0,0.95))
		var separation:=acos(clampf(world_position.normalized().dot(Vector3(0.48,-0.28,-1.0).normalized()),-1,1))
		check(separation>0.34+angular_size,"Actual complete asteroid bounds preserve initial Earth scenic cone")
		before.append(rock.transform)
	var maximum_bound:=0.0
	for variant in range(8):
		for detail in [false,true]:
			var mesh:=scenery._mesh(variant,detail)
			for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:maximum_bound=maxf(maximum_bound,vertex.length())
	check(maximum_bound<1.7,"Actual asteroid bound fits reserved corridor margin")
	scenery.update_view(Vector3(100000,100000,100000))
	for child in scenery.get_children():check(child.multimesh.instance_count==0 and not child.visible,"Distant belt has no visible instances")
	scenery.configure(anchor,0);check(scenery.asteroid_count==95,"Economy profile reduces asteroid instances")
	scenery.configure(anchor,2)
	for index in range(before.size()):check(scenery.rocks[index].transform==before[index],"Quality roundtrip preserves deterministic placement")
	check(scenery.sky.sky_material.shader!=null,"Procedural sky resource exists")
	station.queue_free();scenery.queue_free();await process_frame
	print("GRAPHICS SPACE ENVIRONMENT TESTS: %d checks, %d failures; visual scenery only"%[checks,failures])
	quit(1 if failures else 0)
