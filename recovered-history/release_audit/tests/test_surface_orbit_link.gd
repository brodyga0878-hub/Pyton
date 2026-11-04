extends SceneTree
const Surface=preload("res://scripts/surface_model.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Visual=preload("res://scripts/surface_visual.gd")
const PreviousVisual=preload("res://tests/surface_visual_reference_v0102.gd")
var checks:=0
var failures:=0
func check(ok:bool,text:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _init()->void:call_deferred("run")
func run()->void:
	var world:=World.new();var nav:=Nav.new();world.configure(nav.current());world.site_id="site10"
	var ship:=Ship.new();var surface:=Surface.new();surface.enter(ship,world,true)
	for i in range(40):
		ship.position.x=600;ship.position.y=surface.height_at(600,0)+surface.clearance(ship)+700;surface.recenter(ship)
	var ll:Array=surface.geographic_position(ship);ship.velocity=Vector3.ZERO
	var distance:float=surface.pad_distance(ship);var previous:=surface.orbit_position
	check(surface.leave(ship,world,10),"Surface can exit above actual geographic location")
	world.site_id=""
	var radius:float=world.by_id.earth.radius_km*1000
	check(ship.position.distance_to(previous)>1000000,"Exit no longer restores old arrival point")
	check(absf(ship.position.distance_to(world.local_meters("earth",10))-radius-Link.ALTITUDE)<4,"Exit is 20 km above reference sphere")
	var hull:float=ship.hull
	check(not world.protect_surface(ship,10) and ship.hull==hull,"Orbital exit clears near-surface damage guard")
	check(surface.snapshot().version==5,"Inactive orbital link has its own save version")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(surface.snapshot()))
	var copy:=Ship.new();copy.restore(JSON.parse_string(JSON.stringify(ship.snapshot())))
	var clone:=Surface.new()
	check(clone.restore(saved,copy,world),"Orbit link restores with normal flight save")
	var before:=JSON.stringify(clone.snapshot());var before_ship:=JSON.stringify(copy.snapshot())
	for key in ["latitude","longitude","days","revision","position","site_id","layout","source_digest"]:
		var bad:=saved.duplicate(true)
		bad.orbit_link[key]=123.0 if key in ["latitude","longitude"] else (-1 if key=="days" else "invalid")
		check(not clone.restore(bad,copy,world),"Malformed orbit link rejected")
		check(JSON.stringify(clone.snapshot())==before and JSON.stringify(copy.snapshot())==before_ship,"Invalid orbit link does not mutate live state")
	for key in ["revision","system_id","body_id","layout","source_digest","site_id","latitude","longitude","days","position"]:
		var bad:=saved.duplicate(true);bad.orbit_link.erase(key)
		check(not clone.restore(bad,copy,world),"Missing orbit metadata is rejected without runtime errors")
		check(JSON.stringify(clone.snapshot())==before and JSON.stringify(copy.snapshot())==before_ship,"Missing fields preserve live state")
	check(clone.enter_from_orbit(copy,world,10),"Re-entry uses orbital position")
	var returned:Array=clone.geographic_position(copy)
	check(absf(returned[0]-ll[0])<1e-12 and absf(returned[1]-ll[1])<1e-12,"Stationary immediate re-entry preserves exact geographic point")
	check(world.site_id=="site10" and clone.site_name=="Новая Москва" and absf(clone.pad_distance(copy)-distance)<0.01,"Re-entry retains original port as return target")
	world.site_id="";copy=Ship.new();copy.restore(JSON.parse_string(JSON.stringify(ship.snapshot())));clone=Surface.new();clone.restore(saved,copy,world)
	var later:=10.125
	check(clone.enter_from_orbit(copy,world,later),"Re-entry can occur after time passes in orbit")
	returned=clone.geographic_position(copy)
	var expected:=wrapf(float(ll[1])+Link.spin(world.by_id.earth,later)-Link.spin(world.by_id.earth,10),-PI,PI)
	check(absf(returned[1]-expected)<1e-12,"Body rotation advances geographic longitude under stationary ship")
	world.site_id="";copy=Ship.new();copy.restore(ship.snapshot());clone=Surface.new();clone.restore(saved,copy,world)
	var target_lat:=0.45;var target_lon:=1.23
	copy.position=world.local_meters("earth",10)+Basis(Vector3.UP,Link.spin(world.by_id.earth,10))*Link.direction(target_lat,target_lon)*(radius+30000)
	check(clone.enter_from_orbit(copy,world,10),"Moved orbital ship enters below its new radial position")
	returned=clone.geographic_position(copy)
	check(absf(returned[0]-target_lat)<1e-6 and absf(returned[1]-target_lon)<1e-6,"Changed orbital position maps back to geographic coordinates")
	world.site_id="";copy=Ship.new();copy.restore(ship.snapshot());copy.velocity=Vector3.RIGHT*21;clone=Surface.new();clone.restore(saved,copy,world)
	check(not clone.enter_from_orbit(copy,world,10) and world.site_id.is_empty(),"Unsafe entry preserves orbital context")
	copy.velocity=Vector3.ZERO
	world.select(world.default_id)
	check(world.begin_transfer(copy,nav) and world.step_transfer(3,copy,nav) and copy.position==Vector3.ZERO,"Fast return to prototype station is available after geographic exit")
	var old_times:Array=[];var new_times:Array=[]
	world.site_id="site10";surface=Surface.new();ship=Ship.new();surface.enter(ship,world,true)
	for run in range(5):
		ship.position.x=600;ship.position.y=surface.height_at(600,0)+surface.clearance(ship)+700;surface.recenter(ship)
		var old_visual:=PreviousVisual.new();var new_visual:=Visual.new();root.add_child(old_visual);root.add_child(new_visual)
		var start:=Time.get_ticks_usec();old_visual.configure(surface);old_times.append((Time.get_ticks_usec()-start)/1000.0)
		start=Time.get_ticks_usec();new_visual.configure(surface);new_times.append((Time.get_ticks_usec()-start)/1000.0)
		check(old_visual.get_child_count()==new_visual.get_child_count(),"Sampling optimization preserves node count")
		for i in range(4):
			var old_arrays:Array=old_visual.get_child(i).mesh.surface_get_arrays(0)
			var new_arrays:Array=new_visual.get_child(i).mesh.surface_get_arrays(0)
			for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_INDEX]:
				check(old_arrays[channel]==new_arrays[channel],"Optimized mesh is byte-identical to 0.10.2")
		old_visual.queue_free();new_visual.queue_free();await process_frame
	old_times.sort();new_times.sort()
	print("SURFACE ORBIT LINK TESTS: %d checks, %d failures; host mesh median %.2f -> %.2f ms"%[checks,failures,old_times[2],new_times[2]])
	quit(1 if failures else 0)
