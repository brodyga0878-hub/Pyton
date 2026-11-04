extends SceneTree
const Surface=preload("res://scripts/surface_model.gd")
const Sphere=preload("res://scripts/spherical_terrain.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Visual=preload("res://scripts/surface_visual.gd")
var checks:=0
var failures:=0
func check(ok:bool,text:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _init()->void:call_deferred("run")
func run()->void:
	var world:=World.new();var nav:=Nav.new();world.configure(nav.current());world.site_id="site10"
	var ship:=Ship.new();var surface:=Surface.new()
	check(surface.enter(ship,world,true) and surface.globe!=null,"Game can enter spherical terrain")
	check(surface.snapshot().version==4 and surface.frame_index>0,"Initial surface entry already has bounded local coordinates")
	var clone:=Surface.new();var copy:=Ship.new();copy.restore(JSON.parse_string(JSON.stringify(ship.snapshot())))
	check(clone.restore(JSON.parse_string(JSON.stringify(surface.snapshot())),copy,world),"Immediate entry save reloads before any physics tick")
	var initial: Array=surface.geographic_position(ship)
	ship.position.y=surface.height_at(ship.position.x,ship.position.z)+surface.clearance(ship)+1200
	ship.attitude=Basis.looking_at(Vector3.RIGHT,Vector3.UP).get_rotation_quaternion()
	ship.velocity=Vector3.RIGHT*300;ship.target_speed=300;ship.assisted=true
	for step in range(400):
		surface.step(0.2,ship,Vector2.ZERO,0)
		check(ship.hull==100 and not surface.landed and ship.position.is_finite(),"Unrestricted travel stays above terrain")
		check(Vector2(ship.position.x,ship.position.z).length()<=Surface.REBASE_DISTANCE+0.01,"Local coordinates stay small through distant travel")
	check(surface.frame_index>30,"Terrain frame follows ship beyond old 1750-metre boundary")
	check(surface.pad_distance(ship)>20000,"Ship travels over 20 km from its landing site")
	var travelled:=surface.geographic_position(ship)
	var offset:Vector2=surface.globe.project(initial[0],initial[1])
	check(offset.length()>20000 and absf(travelled[0]-initial[0])+absf(travelled[1]-initial[1])>0.0001,"Latitude and longitude represent actual movement")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(surface.snapshot()))
	copy=Ship.new();copy.restore(JSON.parse_string(JSON.stringify(ship.snapshot())));clone=Surface.new()
	check(clone.restore(saved,copy,world),"Distant surface save restores")
	var restored_ll:Array=clone.geographic_position(copy);var live_ll:Array=surface.geographic_position(ship)
	check(absf(restored_ll[0]-live_ll[0])<1e-12 and absf(restored_ll[1]-live_ll[1])<1e-12,"JSON reload preserves geographic position to micrometre tolerance")
	for p in [Vector2.ZERO,Vector2(125,200),Vector2(-400,-350)]:
		check(absf(clone.height_at(p.x,p.y)-surface.height_at(p.x,p.y))<0.00001,"Reload reproduces same terrain triangles")
	var downgraded:=saved.duplicate(true);downgraded.version=3
	check(not clone.restore(downgraded,copy,world),"Global metadata cannot silently load as old flat terrain")
	var before:=JSON.stringify(clone.snapshot());var ship_before:=JSON.stringify(copy.snapshot())
	for key in ["latitude","longitude","terrain_revision","active","layout"]:
		var bad:=saved.duplicate(true)
		bad[key]=91.0 if key in ["latitude","longitude"] else (1 if key=="active" else "unknown")
		check(not clone.restore(bad,copy,world),"Malformed global metadata rejected")
		check(JSON.stringify(clone.snapshot())==before and JSON.stringify(copy.snapshot())==ship_before,"Bad load does not mutate live globe or ship")
	ship.velocity=Vector3.ZERO;ship.position.y=surface.height_at(ship.position.x,ship.position.z)+surface.clearance(ship)
	check(surface.touch_down(ship),"Manual landing is possible away from any port")
	copy=Ship.new();copy.restore(JSON.parse_string(JSON.stringify(ship.snapshot())));clone=Surface.new()
	check(clone.restore(JSON.parse_string(JSON.stringify(surface.snapshot())),copy,world) and clone.landed,"Wilderness landing survives save and reload")
	check(surface.take_off(ship),"Takeoff works in wilderness")
	var visual:=Visual.new();root.add_child(visual)
	var started:=Time.get_ticks_usec();visual.configure(surface)
	var build_ms:float=(Time.get_ticks_usec()-started)/1000.0
	var mesh:MeshInstance3D=visual.get_child(0)
	var vertices:PackedVector3Array=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for index in [0,64,65,2112,2113,4224]:
		var vertex:Vector3=vertices[index]
		check(absf(vertex.y-surface.height_at(vertex.x,vertex.z))<0.001,"Streamed visible mesh and collision height agree")
	var edge:=2000.0
	for extent in [8000,32000,128000]:
		var ring:MeshInstance3D=visual.get_node("DistantTerrain%d"%extent)
		var ring_arrays:Array=ring.mesh.surface_get_arrays(0)
		var points:PackedVector3Array=ring_arrays[Mesh.ARRAY_VERTEX]
		for side in range(4):
			for i in range(65):
				var v:Vector3=points[side*325+i]
				check(absf(maxf(absf(v.x),absf(v.z))-edge)<0.01,"Distant LOD ring shares exact square boundary")
				check(absf(v.y-surface.raw_height_at(v.x,v.z))<0.01,"Ring border follows same spherical height field")
		edge=float(extent)
	check(visual.get_child_count()==4,"Distant district is not carried along with ship")
	var old_mesh:Node=visual.get_child(0);visual.configure(surface)
	check(visual.get_child(0)==old_mesh,"No terrain rebuild between frame shifts")
	ship.position.x=600;ship.position.y=surface.height_at(600,ship.position.z)+surface.clearance(ship)+500;surface.recenter(ship);visual.configure(surface)
	check(visual.get_child(0)!=old_mesh,"Terrain streams when local frame moves")
	ship.position.y=surface.height_at(ship.position.x,ship.position.z)+surface.clearance(ship);ship.velocity=Vector3.ZERO
	check(surface.touch_down(ship) and surface.take_off(ship),"Return autopilot starts immediately after ground takeoff")
	check(surface.begin_landing(ship),"Return autopilot can start in distant wilderness")
	for step in range(18000):
		surface.step(0.1,ship,Vector2.ZERO,0)
		if surface.landed:break
	check(surface.landed and ship.hull==100 and surface.pad_distance(ship)<40,"Autopilot returns over 20 km and lands without damage")
	visual.configure(surface)
	check(visual.get_child_count()>10,"Landing district appears again when returning to port")
	var legacy:=Surface.new();var old_ship:=Ship.new();legacy.enter(old_ship,world)
	check(legacy.snapshot().version==3 and clone.restore(legacy.snapshot(),old_ship,world) and clone.globe==null,"Old local district saves keep old terrain")
	var math:=Sphere.new();math.configure(world,"earth","site10")
	for lat in [-PI/2,-1.1,0.0,1.1,PI/2]:
		for lon in [-PI,-0.7,0.0,PI]:
			math.latitude=lat;math.longitude=lon
			for xy in [Vector2(0,1),Vector2(800,600),Vector2(-1200,-1600)]:
				var ll:Array=math.coordinates(xy.x,xy.y)
				var roundtrip:Vector2=math.project(ll[0],ll[1])
				check(roundtrip.distance_to(xy)<0.02,"Spherical projection works at both poles and longitude seam")
	for lat in [-1.0,0.0,1.0]:
		check(absf(math.elevation(lat,-PI+1e-11)-math.elevation(lat,PI-1e-11))<0.001,"Terrain has no longitude seam")
	for pole in [-PI/2,PI/2]:
		check(absf(math.elevation(pole,0)-math.elevation(pole,2.5))<0.00001,"Terrain meets consistently at poles")
	math.latitude=0;math.longitude=0
	for segment in range(72):
		var ll:Array=math.coordinates(TAU*math.radius/72.0,0)
		math.latitude=ll[0];math.longitude=ll[1]
	check(absf(math.latitude)<1e-10 and absf(math.longitude)<1e-10,"Full circumnavigation closes without boundary clamp")
	var other:=Sphere.new();other.configure(world,"earth","")
	for lat in [-1.0,0.0,1.0]:check(other.elevation(lat,0.8)==math.elevation(lat,0.8),"Body terrain does not change with selected landing site")
	visual.queue_free();await process_frame
	print("GLOBAL SURFACE TESTS: %d checks, %d failures; host mesh build %.2f ms"%[checks,failures,build_ms])
	quit(1 if failures else 0)
