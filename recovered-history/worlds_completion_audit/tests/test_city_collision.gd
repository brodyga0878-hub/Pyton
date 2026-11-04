extends SceneTree
const Surface=preload("res://scripts/surface_model.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Visual=preload("res://scripts/surface_visual.gd")
const Segment=preload("res://scripts/segment_box.gd")
var checks:=0
var failures:=0
func check(ok:bool,text:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _init()->void:call_deferred("run")
func run()->void:
	var nav:=Nav.new();var world:=World.new();world.configure(nav.current());world.site_id="site10"
	var ship:=Ship.new();var surface:=Surface.new();surface.enter(ship,world)
	var blocks:Array[AABB]=surface.buildings()
	check(blocks.size()==10,"City model provides canonical building volumes")
	var visual:=Visual.new();root.add_child(visual);visual.configure(surface)
	for i in range(10):
		var mesh:MeshInstance3D=visual.get_node("CityBlock%d"%i)
		check(mesh.mesh.size==blocks[i].size and mesh.position==blocks[i].get_center(),"Rendered block must match collision volume")
	var block:AABB=blocks[0];var radius:=surface.collision_radius(ship);var expanded:=block.grow(radius)
	var center:=block.get_center()
	var previous:=Vector3(-500,center.y,center.z)
	ship.position=Vector3(500,center.y,center.z);ship.velocity=Vector3.RIGHT*100;surface.landing=true
	surface._clip_buildings(previous,ship)
	check(ship.position.x<expanded.position.x,"Fast sweep cannot tunnel through city blocks")
	check(ship.hull<100 and ship.velocity.x==0,"Impact applies damage and removes inward velocity")
	check(not surface.landing and ship.target_speed==0,"Collision cancels automated approach")
	check(not surface.overlaps_building(ship),"Contact stops outside expanded volume")
	ship=Ship.new();ship.position=Vector3(expanded.position.x+1,center.y,center.z);ship.velocity=Vector3(3,0,12)
	surface._clip_buildings(Vector3(expanded.position.x-1,center.y,center.z),ship)
	check(ship.hull==100 and ship.velocity.z==12 and ship.velocity.x==0,"Slow contact slides without damage")
	ship=Ship.new();ship.position=Vector3(500,expanded.end.y+5,center.z);ship.velocity=Vector3.RIGHT*100
	surface._clip_buildings(Vector3(-500,expanded.end.y+5,center.z),ship)
	check(ship.position.x==500 and ship.hull==100,"Flight above roof is unobstructed")
	ship=Ship.new();ship.position=Vector3(center.x,expanded.position.y-5,center.z);ship.velocity=Vector3.DOWN*30
	surface._clip_buildings(Vector3(center.x,expanded.end.y+50,center.z),ship)
	check(ship.position.y>expanded.end.y and ship.velocity.y==0 and ship.hull<100,"Roof sweep stops before roof")
	var saved:=surface.snapshot();ship=Ship.new();ship.position=center;ship.velocity=Vector3.ZERO
	var before:=ship.position
	var restored:=Surface.new()
	check(not restored.restore(saved,ship,world) and ship.position==before,"New save inside a solid building rejected atomically")
	saved.version=2
	var hull:float=ship.hull
	check(restored.restore(saved,ship,world),"Older city save remains loadable")
	check(ship.position.y>expanded.end.y and ship.hull==hull and not restored.landed,"Legacy overlap moved above roof without damage")
	check(not restored.overlaps_building(ship),"Migrated position is clear")
	ship=Ship.new();surface=Surface.new();surface.enter(ship,world);surface.begin_landing(ship)
	for i in range(24000):
		surface.step(1.0/60,ship,Vector2.ZERO,0)
		if surface.landed:break
	check(surface.landed and ship.hull==100,"Autoland reaches clear pad between blocks")
	check(surface.take_off(ship),"Takeoff still available")
	for i in range(360):surface.step(1.0/60,ship,Vector2.ZERO,0)
	check(not surface.landed and ship.hull==100,"Takeoff does not strike city blocks")
	var no_city:=Surface.new()
	check(no_city.buildings().is_empty(),"Non-city terrain has no phantom buildings")
	var box:=AABB(Vector3.ZERO,Vector3.ONE*10)
	check(Segment.intersect(Vector3(-1,20,5),Vector3(20,20,5),box).is_empty(),"Parallel segment outside slab misses")
	check(Segment.intersect(Vector3(5,5,5),Vector3(20,5,5),box).inside,"Embedded start reported explicitly")
	check(Segment.intersect(Vector3(-1,5,5),Vector3(-0.1,5,5),box).is_empty(),"Stop before wall is clear")
	var touch:=Segment.intersect(Vector3(10,5,5),Vector3(9,5,5),box)
	check(not touch.is_empty() and touch.time==0 and touch.normal==Vector3.RIGHT and not touch.inside,"Wall-face start blocks inward motion without embedded-state rescue")
	check(Segment.intersect(Vector3(10,5,5),Vector3(11,5,5),box).is_empty(),"Wall-face start allows outward escape")
	visual.queue_free();await process_frame
	print("CITY COLLISION TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
