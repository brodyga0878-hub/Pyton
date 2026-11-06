extends SceneTree
const Guard=preload("res://scripts/source_orbit_surface_guard.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const World=preload("res://scripts/planetary_system.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func fixture(model:int)->Dictionary:
	var world:=World.new();world.configure(Galaxy.new().get_system(Galaxy.SOL_ID),World.FULL_LAYOUT)
	var body:Dictionary={}
	var anchor:=""
	if model==129:
		for site:Dictionary in world.settlements:
			if int(site.model_index)==84 and int(world.by_id[str(site.parent)].model_index)==model:
				body=world.by_id[str(site.parent)];anchor=str(site.id);break
	else:
		for candidate:Dictionary in world.bodies:
			if int(candidate.model_index)==model and candidate.get("landable",false):body=candidate;break
	if body.is_empty():return {}
	world.focus_id=str(body.id);world.selected_id=world.focus_id;world.site_id=anchor
	var terrain:=Terrain.new();terrain.configure(world,str(body.id),anchor)
	var ship:=Flight.new();ship.source_motion_profile=true;ship.station_available=false
	return {"world":world,"body":body,"terrain":terrain,"ship":ship,"guard":Guard.new()}
func place(f:Dictionary,altitude:float)->void:
	var ll:Array=[f.terrain.latitude,f.terrain.longitude]
	var radius:float=float(f.terrain.radius)+float(f.terrain.elevation(ll[0],ll[1]))
	f.ship.position=f.world.local_meters(f.world.focus_id,0.0)+f.world.body_rotation_basis(f.world.focus_id,0.0)*Link.direction(ll[0],ll[1])*(radius+altitude)
	f.ship.velocity=Vector3.ZERO
func run()->void:
	for model in [129,117]:
		var f:=fixture(model)
		check(not f.is_empty(),"Actual native Sol landable body "+str(model))
		if f.is_empty():continue
		var world:RefCounted=f.world;var ship:RefCounted=f.ship;var guard:RefCounted=f.guard
		place(f,30000.0)
		var before:Dictionary=ship.snapshot()
		check(ship.position.distance_to(world.local_meters(world.focus_id,0.0))<float(f.body.radius_km)*1000.0+2000.0,"Fixture lies inside obsolete reference-sphere collision band "+str(model))
		check(not guard.protect(world,ship,0.0) and ship.snapshot()==before,"30km above actual source terrain has no phantom collision "+str(model))
		var sampled:Dictionary=guard.probe(world,ship,0.0)
		check(not sampled.is_empty() and not sampled.coarse_only and absf(float(sampled.altitude_m)-30000.0)<2.0,"Actual shared source field measured in body-fixed pose "+str(model))
		var first:Dictionary=guard.cache_stats();guard.probe(world,ship,0.0);var second:Dictionary=guard.cache_stats()
		check(first.samplers==1 and second.hits>first.hits and second.source_samples==first.source_samples,"Repeated orbit probe reuses body and height nodes "+str(model))
		place(f,1900.0);ship.autopilot=true;ship.target_speed=100.0
		check(guard.protect(world,ship,0.0),"Actual source surface proximity protected "+str(model))
		sampled=guard.probe(world,ship,0.0)
		check(absf(float(sampled.altitude_m)-2050.0)<2.0,"Source protection separates50m beyond2kmAGL "+str(model))
		check(ship.hull==90.0 and absf(ship.velocity.length()-10.0)<0.0001 and ship.target_speed==0.0 and not ship.autopilot,"Existing mobile impact response retained "+str(model))
		before=ship.snapshot();check(not guard.protect(world,ship,0.0) and ship.snapshot()==before,"Protection does not repeatedly damage separated ship "+str(model))
		place(f,10.0);ship.docked=true;before=ship.snapshot()
		check(not guard.protect(world,ship,0.0) and ship.snapshot()==before,"Docked ship never receives orbit terrain response "+str(model))
		ship.docked=false;ship.surface_mode=true;before=ship.snapshot()
		check(not guard.protect(world,ship,0.0) and ship.snapshot()==before,"Live surface controller owns close collision "+str(model))
		ship.surface_mode=false;ship.hull=100.0;ship.velocity=Vector3.ZERO
		var surface:=Surface.new();check(surface.enter(ship,world,true),"Real source surface entry before departure "+str(model))
		if not surface.active:continue
		ship.position=Vector3(0,surface.height_at(0,0)+surface.clearance(ship)+600.0,0)
		check(surface.leave(ship,world,0.0),"Real source surface departure "+str(model))
		before=ship.snapshot()
		check(not guard.protect(world,ship,0.0) and ship.snapshot()==before,"Next orbit guard after20kmAGL departure preserves hull and pose "+str(model))
		check(not world.protect_surface(ship,0.0),"World FULL integration uses actual source guard "+str(model))
		before=ship.snapshot();check(not guard.protect(world,ship,NAN) and not guard.protect(world,ship,-1.0) and ship.snapshot()==before,"Invalid time cannot change orbit state")
		cache_controls(f)
	print("SOURCE ORBIT SURFACE GUARD TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func cache_controls(f:Dictionary)->void:
	var world:RefCounted=f.world;var ship:RefCounted=f.ship
	var far:=Guard.new();var center:Vector3=world.local_meters(world.focus_id,0.0)
	ship.position=center+Vector3.RIGHT*float(f.body.radius_km)*3000.0
	check(not far.protect(world,ship,0.0) and far.cache_stats().samplers==0,"Distant orbit rejects before creating source sampler")
	var cache:=Guard.new();var count:=0
	for body:Dictionary in world.bodies:
		if not body.get("landable",false):continue
		world.focus_id=str(body.id);world.site_id=""
		check(cache._sampler(world,world.focus_id)!=null,"Prepared source cache body "+str(body.id))
		count+=1
		if count==6:break
	check(count==6 and cache.cache_stats().samplers==Guard.CACHE_LIMIT,"Source guard body cache bounded tofour")
	var before:=cache.cache_stats();world.source_digest+="-cache-revision-test"
	check(cache._sampler(world,world.focus_id)!=null and cache.cache_stats().misses==before.misses+1,"Source digest invalidates previous cached body")
	cache.clear_cache();check(cache.cache_stats().samplers==0,"Public source safety cache reset")
	for body:Dictionary in world.bodies:
		if str(body.kind)!="star":continue
		world.focus_id=str(body.id);ship.position=world.local_meters(world.focus_id,0.0)
		var before_ship:Dictionary=ship.snapshot()
		check(not cache.protect(world,ship,0.0) and ship.snapshot()==before_ship,"Star centre never substitutes a landable surface")
		break
	world.layout_mode=World.PORT_LAYOUT
	check(not cache.protect(world,ship,0.0),"Legacy world cannot opt into new safety helper")
