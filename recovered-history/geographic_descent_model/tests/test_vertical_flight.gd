extends SceneTree
const Surface=preload("res://scripts/surface_model.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Visual=preload("res://scripts/surface_visual.gd")
const Presentation=preload("res://scripts/world_presentation.gd")
var checks:=0
var failures:=0
func check(ok:bool,text:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _init()->void:call_deferred("run")
func run()->void:
	var nav:=Nav.new();var world:=World.new();world.configure(nav.current());world.site_id="site10"
	var ship:=Ship.new();var surface:=Surface.new();surface.enter(ship,world,true)
	ship.position.y=surface.height_at(0,0)+surface.clearance(ship)+700;ship.velocity=Vector3.ZERO
	var ll:Array=surface.geographic_position(ship)
	check(surface.begin_ascent(ship) and surface.extended_flight and surface.flight_phase=="ascent","Ascent starts without teleporting")
	check(surface.altitude(ship)<701,"Ascent command preserves physical height")
	var saved_once:=false;var duration:=0.0
	for step in range(2000):
		var previous:Vector3=ship.position;var old_height:float=surface.altitude(ship)
		surface.step(0.25,ship,Vector2.ZERO,0);duration+=0.25
		check(surface.altitude(ship)>=old_height-0.01 and ship.hull==100,"Climb advances monotonically without damage")
		check(ship.position.distance_to(previous)<76 and ship.velocity.length()<=300.01,"Climb respects continuous speed-limited movement")
		if surface.altitude(ship)>6000 and not saved_once:
			saved_once=true
			var data:Dictionary=JSON.parse_string(JSON.stringify(surface.snapshot()))
			var copy:=Ship.new();copy.restore(JSON.parse_string(JSON.stringify(ship.snapshot())))
			var clone:=Surface.new()
			check(data.version==6 and clone.restore(data,copy,world),"Save above old 4-km ceiling restores")
			check(clone.flight_phase=="ascent" and clone.extended_flight and absf(clone.geographic_position(copy)[0]-ll[0])<1e-12 and absf(clone.geographic_position(copy)[1]-ll[1])<1e-12,"Reload preserves climb and geographic point")
			var before:=JSON.stringify(clone.snapshot());var before_ship:=JSON.stringify(copy.snapshot())
			for phase in [true,"invalid",123]:
				var bad:=data.duplicate(true);bad.flight_phase=phase
				check(not clone.restore(bad,copy,world) and JSON.stringify(clone.snapshot())==before and JSON.stringify(copy.snapshot())==before_ship,"Invalid phase rejected atomically")
			var bad:=data.duplicate(true);bad.erase("flight_phase")
			check(not clone.restore(bad,copy,world),"Missing vertical phase rejected")
			bad=data.duplicate(true);bad.version=4
			check(not clone.restore(bad,copy,world),"High-altitude save cannot masquerade as legacy globe")
			bad=data.duplicate(true);bad.landed=true
			check(not clone.restore(bad,copy,world),"Cannot load a landed ship with active ascent")
			var original_flight:=copy.snapshot()
			copy.velocity=Vector3.UP*500
			check(not clone.restore(data,copy,world),"Automatic phase rejects unsafe saved velocity")
			copy.restore(original_flight);copy.assisted=false
			check(not clone.restore(data,copy,world),"Automatic phase rejects inconsistent manual mode")
			copy.restore(original_flight);copy.target_speed=100
			check(not clone.restore(data,copy,world),"Automatic phase rejects inconsistent saved throttle")
			copy.restore(original_flight)
			surface=clone;ship=copy
		if surface.ready_for_orbit:break
	check(saved_once and surface.ready_for_orbit and duration>60 and duration<300,"Real ascent reaches handoff height over elapsed simulation time")
	var ascent_seconds:=duration
	check(surface.leave(ship,world,50),"Completed climb can hand off to orbital frame")
	world.site_id=""
	var reference_height:float=ship.position.distance_to(world.local_meters(world.focus_id,50))-world.by_id[world.focus_id].radius_km*1000
	check(surface.begin_descent(ship,world,50) and surface.flight_phase=="descent","Linked entry starts controlled descent")
	check(absf(ship.position.y-reference_height)<0.01 and surface.altitude(ship)>19000,"Re-entry preserves altitude instead of jumping to 1500 m")
	var visual:=Visual.new();root.add_child(visual);visual.configure(surface)
	check(visual.has_node("DistantTerrain512000"),"High flight has extended horizon terrain")
	var env:=Environment.new();var presentation:=Presentation.new();presentation.apply(env,surface,2)
	presentation.update_height(env,surface,20000,2)
	check(env.fog_density<0.000001 and env.ambient_light_energy<0.2,"Atmosphere dims at high altitude")
	saved_once=false;duration=0
	for step in range(2000):
		var previous:Vector3=ship.position;var old_height:float=surface.altitude(ship)
		surface.step(0.25,ship,Vector2.ZERO,0);duration+=0.25
		check(surface.altitude(ship)<=old_height+0.01 and ship.hull==100,"Descent advances without damage")
		check(ship.position.distance_to(previous)<76 and ship.velocity.length()<=300.01,"Descent does not teleport or exceed speed cap")
		if surface.altitude(ship)<10000 and not saved_once:
			saved_once=true
			var copy:=Ship.new();copy.restore(JSON.parse_string(JSON.stringify(ship.snapshot())))
			var clone:=Surface.new()
			check(clone.restore(JSON.parse_string(JSON.stringify(surface.snapshot())),copy,world) and clone.flight_phase=="descent","Descent reload retains phase")
			surface=clone;ship=copy
		if surface.flight_phase.is_empty():break
	check(saved_once and surface.flight_phase.is_empty() and absf(surface.altitude(ship)-1500)<0.01 and ship.velocity.length()<0.01,"Descent ends in controlled 1500-metre hover")
	check(surface.begin_ascent(ship),"High-flight mode can start another climb")
	surface.step(0.25,ship,Vector2(0.2,0),0)
	check(surface.flight_phase.is_empty(),"Manual steering cancels vertical autopilot")
	ship.velocity=Vector3.ZERO;surface.resume_descent(ship);surface.step(0.25,ship,Vector2.ZERO,0,1)
	check(surface.flight_phase.is_empty(),"Manual lift cancels vertical autopilot")
	var legacy:=Surface.new();ship=Ship.new();legacy.enter(ship,world,true)
	ship.position.y=9000;legacy.step(0.01,ship,Vector2.ZERO,0)
	check(legacy.altitude(ship)<=4000.01 and legacy.snapshot().version==4,"Legacy globe keeps previous ceiling and save format")
	presentation.apply(env,legacy,2)
	check(is_equal_approx(env.sky.sky_material.sky_energy_multiplier,0.7),"Returning to a low legacy scene restores sky")
	visual.queue_free();await process_frame
	print("VERTICAL FLIGHT TESTS: %d checks, %d failures; ascent %.2f s, descent %.2f s"%[checks,failures,ascent_seconds,duration]);quit(1 if failures else 0)
