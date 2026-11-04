extends SceneTree
# Behavioural tests for visiting a body before any surface/orbit link exists.
const Surface=preload("res://scripts/surface_model.gd")
const NearView=preload("res://scripts/near_surface_view.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _init()->void:call_deferred("run")
func world_for(body:String,site:="")->RefCounted:
	var world:=World.new();world.configure(Nav.new().current());world.focus_id=body;world.selected_id=body;world.site_id=site
	return world
func arriving(world:RefCounted,lat:float,lon:float,height:float,days:float)->RefCounted:
	var ship:=Ship.new()
	var body:Dictionary=world.by_id[world.focus_id]
	var up:Vector3=Basis(Vector3.UP,Link.spin(body,days))*Link.direction(lat,lon)
	ship.position=world.local_meters(world.focus_id,days)+up*(float(body.radius_km)*1000.0+height)
	# A generic initial orientation and a small lateral velocity expose lost rotations.
	ship.attitude=Quaternion(Vector3(1,2,3).normalized(),0.73)
	ship.velocity=Vector3(3,-4,2)
	ship.credits=7319;ship.goods.medicines=4;ship.equipment=["engine"]
	ship.mission_cargo={"delivery":2};ship.story_cargo=2
	return ship
func progress(ship:RefCounted)->String:
	return JSON.stringify([ship.hull,ship.credits,ship.goods,ship.equipment,ship.mission_cargo,ship.story_cargo,ship.ship_id])
func snapshot(value:RefCounted)->String:
	return JSON.stringify(value.snapshot())
func run()->void:
	var days:=25.125
	# A fresh visit has no saved departure point. Verify both axes at poles and seam,
	# and use a second body so a hidden Earth radius/rotation does not pass the test.
	for body in ["earth","moon"]:
		for point in [[0.2,1.1],[-0.5,PI-0.00001],[0.6,-PI+0.00001],[PI/2,0.0],[-PI/2,1.0]]:
			var world:=world_for(body)
			var ship:=arriving(world,float(point[0]),float(point[1]),41900,days)
			var surface:=Surface.new();var view:=NearView.new()
			var saved_surface:=snapshot(surface);var saved_ship:=snapshot(ship);var saved_world:=snapshot(world)
			var original_position:Vector3=ship.position;var original_attitude:Quaternion=ship.attitude;var original_velocity:Vector3=ship.velocity
			var original_progress:=progress(ship)
			var physical_height:float=ship.position.distance_to(world.local_meters(body,days))-float(world.by_id[body].radius_km)*1000.0
			check(view.update(surface,ship,world,days) and view.active,"First visit has a preview throughout the high descent band")
			if not view.active:continue
			check(snapshot(surface)==saved_surface and snapshot(ship)==saved_ship and snapshot(world)==saved_world,"First-visit preview does not mutate gameplay or saves")
			check(view.drawing.body_id==body and view.drawing.globe!=null and surface.globe==null,"Fresh preview uses a separate render-only globe for the focused body")
			var expected_up:Vector3=(original_position-world.local_meters(body,days)).normalized()
			check(view.frame.basis.y.distance_to(expected_up)<0.000001,"New geographic frame points up along the actual orbital radius")
			check(absf(view.frame.basis.determinant()-1.0)<0.00001,"New entry frame remains a proper rotation at poles and seam")
			var frame:Transform3D=view.frame;var cached_globe:RefCounted=view.drawing.globe;var terrain_key:String=view.drawing.terrain_key()
			check(view.enter_descent(surface,ship,world,days),"First visit starts a controlled descent without a saved orbital link")
			check(surface.active and surface.extended_flight and surface.flight_phase=="descent" and ship.surface_mode,"First entry enables the real surface descent controller")
			check(surface.globe==cached_globe and surface.terrain_key()==terrain_key,"Entry adopts the preview globe and terrain frame")
			check(absf(surface.geoid_height(ship)-physical_height)<4.0 and surface.altitude(ship)>41000,"Entry preserves height rather than moving straight to a low landing zone")
			check((frame.basis*Basis(ship.attitude)).is_equal_approx(Basis(original_attitude)),"Entry preserves world orientation through the local-frame conversion")
			check((frame.basis*ship.velocity).distance_to(original_velocity)<0.0001,"Entry preserves world velocity through the local-frame conversion")
			check(progress(ship)==original_progress and snapshot(world)==saved_world,"First entry preserves progress and planetary selection")
			var ll:Array=surface.geographic_position(ship)
			check(absf(float(ll[0])-float(point[0]))<0.000002,"First entry remains below the same geographic latitude")
			# Longitude is undefined exactly at a pole; radial direction still has to match.
			check(Link.direction(float(ll[0]),float(ll[1])).distance_to(Link.direction(float(point[0]),float(point[1])))<0.000002,"First entry remains below the same radial point, including seam and poles")
			var position:Vector3=ship.position
			surface.step(0.25,ship,Vector2.ZERO,0)
			check(ship.position.distance_to(position)<76 and ship.hull==100,"The first simulation step moves continuously without damage")
	# The model API must be safe even without the presentation helper.
	var world:=world_for("moon");var ship:=arriving(world,-0.35,-1.7,50000,days);var surface:=Surface.new()
	var original_attitude:Quaternion=ship.attitude;var original_velocity:Vector3=ship.velocity
	var original_height:float=ship.position.distance_to(world.local_meters("moon",days))-float(world.by_id.moon.radius_km)*1000
	check(surface.begin_descent(ship,world,days),"Direct model API can enter a new body at 50 km")
	check(absf(surface.geoid_height(ship)-original_height)<4,"Direct model entry preserves physical height")
	var frame:Transform3D=NearView.world_frame(surface.globe,world,days)
	check((frame.basis*Basis(ship.attitude)).is_equal_approx(Basis(original_attitude)) and (frame.basis*ship.velocity).distance_to(original_velocity)<0.0001,"Direct model entry transforms orientation and velocity consistently")
	for entry_height in [1802.0,23800.0,30000.0,59990.0]:
		world=world_for("earth");ship=arriving(world,0.2,1.1,entry_height,days);surface=Surface.new()
		var measured_height:float=ship.position.distance_to(world.local_meters("earth",days))-float(world.by_id.earth.radius_km)*1000
		check(surface.begin_descent(ship,world,days) and absf(surface.geoid_height(ship)-measured_height)<4,"First descent covers the old and newly supported height bands")
	# Save above the old ceiling, reload through JSON, stop, resume and finish the same trip.
	world=world_for("earth","site10");ship=arriving(world,0.31,-0.75,59990,days);surface=Surface.new()
	ship.velocity=Vector3.ZERO
	check(NearView.new().enter_descent(surface,ship,world,days),"Descent can start just below 60 km")
	var original_progress:=progress(ship)
	var data:Dictionary=JSON.parse_string(snapshot(surface));var flight:Dictionary=JSON.parse_string(snapshot(ship))
	check(data.version==6 and surface.altitude(ship)>59000,"High descent keeps the existing extended-flight save version")
	var copy:=Ship.new();var clone:=Surface.new()
	check(copy.restore(flight) and clone.restore(data,copy,world),"Mid-descent save above 24 km restores through JSON")
	check(clone.flight_phase=="descent" and absf(clone.geoid_height(copy)-surface.geoid_height(ship))<0.01 and progress(copy)==original_progress,"Reload keeps phase, height and player progress")
	var valid_position:Vector3=copy.position;var before_clone:=snapshot(clone)
	copy.position.y=70000
	var invalid_ship:=snapshot(copy)
	check(not clone.restore(data,copy,world) and snapshot(clone)==before_clone and snapshot(copy)==invalid_ship,"Corrupt high-altitude saves are rejected without mutating the candidate or ship")
	copy.position=valid_position
	surface=clone;ship=copy
	surface.cancel_vertical();ship.brake()
	check(surface.flight_phase.is_empty(),"High descent can be cancelled and braked")
	data=JSON.parse_string(snapshot(surface));flight=JSON.parse_string(snapshot(ship));copy=Ship.new();clone=Surface.new()
	check(copy.restore(flight) and clone.restore(data,copy,world) and clone.flight_phase.is_empty(),"A paused high descent remains paused after reload")
	surface=clone;ship=copy
	var position:Vector3=ship.position
	check(surface.resume_descent(ship) and ship.position==position,"Resume starts from the saved height without teleporting")
	var elapsed:=0.0;var sampled_midflight:=false
	for tick in range(3000):
		var previous:Vector3=ship.position;var height:float=surface.altitude(ship)
		surface.step(0.25,ship,Vector2.ZERO,0);elapsed+=0.25
		check(ship.position.distance_to(previous)<76 and ship.velocity.length()<=300.01 and ship.hull==100,"Full 60-km descent respects its speed bound without discontinuities")
		check(surface.altitude(ship)<=height+0.01,"Full descent advances monotonically toward the hover height")
		if not sampled_midflight and surface.altitude(ship)<40000 and surface.altitude(ship)>30000:
			sampled_midflight=true
			data=JSON.parse_string(snapshot(surface));flight=JSON.parse_string(snapshot(ship));copy=Ship.new();clone=Surface.new()
			check(copy.restore(flight) and clone.restore(data,copy,world) and clone.flight_phase=="descent","Moving midband descent reloads with velocity and controller intact")
			surface=clone;ship=copy
		if surface.flight_phase.is_empty():break
	check(sampled_midflight and elapsed>190 and elapsed<500,"A 60-km trip takes real simulated time and crosses the former height ceiling")
	check(surface.flight_phase.is_empty() and absf(surface.altitude(ship)-1500)<0.01 and ship.velocity.length()<0.01,"The full high descent finishes in the same stable 1500-metre hover")
	check(progress(ship)==original_progress,"Complete descent, cancellation and reload preserve player progress")
	check(surface.resume_descent(ship),"A completed descent can be controlled again")
	surface.step(0.25,ship,Vector2(0.2,0),0)
	check(surface.flight_phase.is_empty(),"Manual steering still cancels the vertical controller")
	# Invalid requests may set a message, but must leave saved gameplay untouched.
	for reason in ["fast","docked","combat","transfer","low","gas"]:
		world=world_for("saturn" if reason=="gas" else "earth","" if reason=="gas" else "site10")
		ship=arriving(world,0.2,1.1,1000 if reason=="low" else 40000,days);surface=Surface.new()
		if reason=="fast":ship.velocity=Vector3.RIGHT*21
		if reason=="docked":ship.docked=true
		if reason=="combat":ship.combat_active=true
		if reason=="transfer":world.transfer_remaining=2
		var before_surface:=snapshot(surface);var before_ship:=snapshot(ship);var before_world:=snapshot(world)
		check(not NearView.new().enter_descent(surface,ship,world,days),"Unsafe or unsupported entry is rejected: "+reason)
		check(snapshot(surface)==before_surface and snapshot(ship)==before_ship and snapshot(world)==before_world,"Rejected first entry is atomic: "+reason)
	# A linked craft must approach the supported band; it may not use the old first-visit shortcut.
	world=world_for("earth","site10");ship=Ship.new();surface=Surface.new();surface.enter(ship,world,true)
	ship.position.y=surface.height_at(0,0)+surface.clearance(ship)+700;ship.velocity=Vector3.ZERO
	check(surface.leave(ship,world,days),"Prepare a known v2 geographic link")
	world.site_id=""
	var center:Vector3=world.local_meters("earth",days);var radial:Vector3=(ship.position-center).normalized();var radius:float=world.by_id.earth.radius_km*1000
	check(absf(ship.position.distance_to(center)-radius-Link.ALTITUDE)<4,"Legacy low departure retains the existing 20-km handoff")
	ship.position=center+radial*(radius+61000)
	var before_surface:=snapshot(surface);var before_ship:=snapshot(ship);var before_world:=snapshot(world)
	check(not NearView.new().enter_descent(surface,ship,world,days),"Linked high entry outside 60 km is refused")
	check(snapshot(surface)==before_surface and snapshot(ship)==before_ship and snapshot(world)==before_world,"Out-of-band linked refusal preserves all saved state")
	# Cancelling a high descent and returning to orbit must not jump down to the
	# link's historical 20-km reference point, including after a fresh save load.
	for entry_height in [41900.0,59990.0]:
		world=world_for("earth","site10");ship=arriving(world,0.31,-0.75,entry_height,days);surface=Surface.new();ship.velocity=Vector3.ZERO
		check(NearView.new().enter_descent(surface,ship,world,days),"Prepare high descent for return to orbit")
		surface.cancel_vertical();ship.brake()
		var retained_height:float=surface.geoid_height(ship)
		var retained_ll:Array=surface.geographic_position(ship)
		var retained_frame:Transform3D=NearView.world_frame(surface.globe,world,days)
		var retained_orientation:Basis=retained_frame.basis*Basis(ship.attitude)
		var retained_progress:=progress(ship)
		check(surface.leave(ship,world,days) and not surface.active and not ship.surface_mode,"Cancelled high descent can hand off directly to orbital control")
		center=world.local_meters("earth",days);radius=world.by_id.earth.radius_km*1000
		check(absf(ship.position.distance_to(center)-radius-retained_height)<4,"High return preserves actual altitude instead of dropping to 20 km")
		check(Basis(ship.attitude).is_equal_approx(retained_orientation),"High return preserves world orientation")
		check(Link.valid(surface.orbit_link,world) and surface.orbit_link.revision==Link.REVISION and surface.snapshot().version==5,"High return keeps the existing v2 link and inactive save format")
		var reference:=Vector3(surface.orbit_link.position[0],surface.orbit_link.position[1],surface.orbit_link.position[2])
		check(absf(reference.distance_to(center)-radius-Link.ALTITUDE)<4 and reference.distance_to(ship.position)>20000,"Legacy link metadata remains a reference rather than replacing actual high flight position")
		world.site_id=""
		data=JSON.parse_string(snapshot(surface));flight=JSON.parse_string(snapshot(ship));copy=Ship.new();clone=Surface.new()
		check(copy.restore(flight) and clone.restore(data,copy,world),"High orbital return restores from a fresh JSON save")
		check(copy.position==ship.position and Basis(copy.attitude).is_equal_approx(retained_orientation) and progress(copy)==retained_progress,"Orbital reload keeps the high position, orientation and progress")
		var return_view:=NearView.new()
		check(return_view.update(clone,copy,world,days) and return_view.space_blend>0,"Reloaded high return reconstructs the orbital transition preview")
		check(return_view.enter_descent(clone,copy,world,days) and clone.flight_phase=="descent","High orbital return can enter the same descent again")
		check(absf(clone.geoid_height(copy)-retained_height)<4,"Reloaded re-entry preserves the actual high altitude")
		var returned_ll:Array=clone.geographic_position(copy)
		check(Link.direction(float(returned_ll[0]),float(returned_ll[1])).distance_to(Link.direction(float(retained_ll[0]),float(retained_ll[1])))<0.000002,"High return and fresh re-entry retain the same geographic point")
		var returned_frame:Transform3D=NearView.world_frame(clone.globe,world,days)
		check((returned_frame.basis*Basis(copy.attitude)).is_equal_approx(retained_orientation) and progress(copy)==retained_progress,"High re-entry keeps world orientation and player progress")
	# The local ceiling is measured above terrain and hull clearance. Its legal
	# radial height may therefore exceed MAX_FLIGHT_HEIGHT and must not be clamped.
	world=world_for("earth","site10");ship=Ship.new();surface=Surface.new();surface.enter(ship,world,true)
	surface.extended_flight=true;surface.globe.latitude=surface.globe.pad_latitude;surface.globe.longitude=surface.globe.pad_longitude
	ship.position=Vector3(0,surface.height_at(0,0)+surface.clearance(ship)+Surface.MAX_FLIGHT_HEIGHT,0);ship.velocity=Vector3.ZERO
	var ceiling_height:float=surface.geoid_height(ship)
	check(ceiling_height>Surface.MAX_FLIGHT_HEIGHT and absf(surface.altitude(ship)-Surface.MAX_FLIGHT_HEIGHT)<0.01,"A legal terrain-relative ceiling can lie above the nominal radial height")
	check(surface.leave(ship,world,days) and absf(ship.position.distance_to(world.local_meters("earth",days))-float(world.by_id.earth.radius_km)*1000-ceiling_height)<4,"Leaving the legal ceiling preserves radial height without an upper clamp")
	world.site_id="";data=JSON.parse_string(snapshot(surface));flight=JSON.parse_string(snapshot(ship));copy=Ship.new();clone=Surface.new()
	check(Link.valid(surface.orbit_link,world) and copy.restore(flight) and clone.restore(data,copy,world) and copy.position==ship.position,"A ceiling-height departure retains a valid v5 JSON save and actual ship position")
	# Previous 24-km saves are a subset of v6 and retain their exact frame and phase.
	world=world_for("earth","site10");ship=Ship.new();surface=Surface.new();surface.enter(ship,world,true)
	surface.extended_flight=true;surface.flight_phase="descent";ship.position.y=18000;ship.velocity=Vector3.DOWN*100;ship.target_speed=0;ship.assisted=true
	data=JSON.parse_string(snapshot(surface));flight=JSON.parse_string(snapshot(ship));copy=Ship.new();clone=Surface.new()
	check(copy.restore(flight) and clone.restore(data,copy,world),"Existing v6 saves below the old ceiling stay readable")
	check(copy.position==ship.position and copy.velocity==ship.velocity and clone.flight_phase==surface.flight_phase,"Loading old-range v6 does not migrate or move the ship")
	# The old remote convenience approach is intentionally still a separate path.
	world=world_for("earth","site10");ship=arriving(world,0.2,1.1,600000,days);surface=Surface.new();ship.velocity=Vector3.ZERO
	check(surface.begin_descent(ship,world,days) and surface.active and surface.globe!=null and not surface.extended_flight and surface.flight_phase.is_empty(),"Distant first visits retain the existing quick district approach")
	check(surface.altitude(ship)<2000 and surface.orbit_link.is_empty(),"Remote quick approach remains distinguishable from actual-height descent")
	print("GEOGRAPHIC DESCENT TESTS: %d checks, %d failures; high descent %.2f s"%[checks,failures,elapsed]);quit(1 if failures else 0)
