extends SceneTree
const NearView=preload("res://scripts/near_surface_view.gd")
const Surface=preload("res://scripts/surface_model.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Visual=preload("res://scripts/surface_visual.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
var checks:=0
var failures:=0
func check(ok:bool,text:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _init()->void:call_deferred("run")
func screen(point:Vector3,position:Vector3,attitude:Quaternion)->Vector2:
	var p:Vector3=Basis(attitude).inverse()*(point-position)
	return Vector2(p.x,-p.y)/maxf(1.0,-p.z)*640.0/tan(deg_to_rad(74.0)*0.5)
func run()->void:
	var world:=World.new();var nav:=Nav.new();world.configure(nav.current());world.site_id="site10"
	var ship:=Ship.new();var surface:=Surface.new();surface.enter(ship,world,true)
	surface.extended_flight=true
	ship.position=Vector3(130,0,-170)
	var ll:Array=surface.geographic_position(ship)
	ship.position.y=surface.height_at(ship.position.x,ship.position.z)+20000.0-surface.globe.elevation(ll[0],ll[1])
	ship.velocity=Vector3.ZERO;ship.attitude=Quaternion(Vector3.RIGHT,-PI/2)
	var old_position:=ship.position;var old_attitude:=ship.attitude
	var before_frame:Transform3D=NearView.world_frame(surface.globe,world,10)
	check(before_frame.basis.determinant()>0.9999 and before_frame.basis.determinant()<1.0001,"Planet preview frame is a proper rotation")
	check((before_frame.affine_inverse()*(before_frame*old_position)).distance_to(old_position)<8,"World-frame round trip is bounded by orbital float precision")
	var origin_lat:float=surface.globe.latitude;var origin_lon:float=surface.globe.longitude
	for lat in [-PI/2,-1.0,0.0,1.0,PI/2]:
		for lon in [-PI,-1.0,0.0,1.0,PI]:
			surface.globe.latitude=lat;surface.globe.longitude=lon
			var frame:Transform3D=NearView.world_frame(surface.globe,world,10)
			check(absf(frame.basis.determinant()-1.0)<0.0001,"Preview uses proper handedness at poles and longitude seam")
			var up:Vector3=Basis(Vector3.UP,Link.spin(world.by_id[world.focus_id],10))*Link.direction(lat,lon)
			check(frame.basis.y.distance_to(up)<0.000001,"Preview up direction agrees with orbital link embedding")
	surface.globe.latitude=origin_lat;surface.globe.longitude=origin_lon
	var visual:=Visual.new();root.add_child(visual);visual.configure(surface)
	var old_key:String=surface.terrain_key();var old_mesh:Node=visual.get_child(0)
	var vertices:PackedVector3Array=visual.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(surface.leave(ship,world,10),"Prepared high flight can hand off to orbit")
	world.site_id=""
	var orbital_position:=ship.position;var orbital_attitude:=ship.attitude
	check((before_frame.basis.get_rotation_quaternion()*old_attitude).angle_to(orbital_attitude)<0.0001,"Orbital handoff preserves surface-frame attitude")
	var view:=NearView.new()
	var source_before:=JSON.stringify(surface.snapshot());var ship_before:=JSON.stringify(ship.snapshot());var world_before:=JSON.stringify(world.snapshot())
	check(view.update(surface,ship,world,10) and view.active,"Linked orbital position activates render-only preview")
	check(view.drawing!=surface and view.drawing.active and not surface.active and not ship.surface_mode,"Drawing proxy does not switch physics into surface mode")
	check(view.drawing.globe==surface.globe and view.drawing.terrain_key()==old_key,"Handoff keeps retained globe and terrain cache key")
	visual.configure(view.drawing)
	check(visual.get_child(0)==old_mesh,"Handoff reuses actual terrain mesh")
	var local:Vector3=view.frame.affine_inverse()*ship.position
	check(local.distance_to(old_position)<8,"Orbital camera maps back to local surface camera within metre tolerance")
	for index in [0,64,2112,4224]:
		var point:Vector3=vertices[index]
		var old_pixel:=screen(point,old_position,old_attitude)
		var orbital_pixel:=screen(view.frame*point,ship.position,ship.attitude)
		check(old_pixel.distance_to(orbital_pixel)<1.0,"Terrain screen projection stays within one pixel across handoff")
	for tick in range(20):
		check(view.update(surface,ship,world,10) and view.drawing.terrain_key()==old_key,"Unchanged preview frame stays cached")
	check(JSON.stringify(surface.snapshot())==source_before and JSON.stringify(ship.snapshot())==ship_before and JSON.stringify(world.snapshot())==world_before,"Preview updates preserve live snapshots")
	check(view.enter_descent(surface,ship,world,10),"Preview can transfer back to controlled descent")
	check(surface.globe==view.drawing.globe and surface.terrain_key()==old_key,"Re-entry adopts retained draw frame without mesh replacement")
	visual.configure(surface)
	check(visual.get_child(0)==old_mesh,"Re-entry keeps cached near terrain mesh")
	check(Basis(ship.attitude).is_equal_approx(before_frame.basis.inverse()*Basis(orbital_attitude)),"Re-entry transforms attitude through inverse preview frame")
	var returned:Array=surface.geographic_position(ship)
	check(absf(returned[0]-ll[0])<1e-12 and absf(returned[1]-ll[1])<1e-12,"Preview adoption preserves geographic point")
	for index in [0,64,2112,4224]:
		var point:Vector3=vertices[index]
		var orbital_pixel:=screen(before_frame*point,orbital_position,orbital_attitude)
		var returned_pixel:=screen(point,ship.position,ship.attitude)
		check(orbital_pixel.distance_to(returned_pixel)<1.0,"Preview-to-descent camera projection stays within one pixel")
	check(not view.update(surface,ship,world,10) and not view.active and view.drawing==null,"Active surface clears orbital preview")
	# Fresh inactive version-5 saves do not retain their old in-memory globe.
	ship.velocity=Vector3.ZERO
	check(surface.leave(ship,world,10),"Second handoff creates an inactive orbital save")
	world.site_id=""
	var saved:Dictionary=JSON.parse_string(JSON.stringify(surface.snapshot()))
	var copy:=Ship.new();copy.restore(JSON.parse_string(JSON.stringify(ship.snapshot())))
	var clone:=Surface.new()
	check(saved.version==5 and clone.restore(saved,copy,world) and clone.globe==null,"Fresh version-5 load contains no render globe")
	var fresh:=NearView.new()
	source_before=JSON.stringify(clone.snapshot());ship_before=JSON.stringify(copy.snapshot());world_before=JSON.stringify(world.snapshot())
	check(fresh.update(clone,copy,world,10) and fresh.drawing.globe!=null,"Fresh orbital load constructs a derived preview globe")
	check(clone.globe==null and not clone.active and not copy.surface_mode,"Fresh preview leaves actual save model inactive")
	check(fresh.drawing.site_name=="Новая Москва" and fresh.drawing.body_id=="earth","Fresh preview reconstructs the original return district")
	var cached_id:int=fresh.drawing.globe.get_instance_id();var cached_index:int=fresh.drawing.frame_index
	for tick in range(20):fresh.update(clone,copy,world,10)
	check(fresh.drawing.globe.get_instance_id()==cached_id and fresh.drawing.frame_index==cached_index,"Repeated fresh preview updates avoid rebuilds")
	check(JSON.stringify(clone.snapshot())==source_before and JSON.stringify(copy.snapshot())==ship_before and JSON.stringify(world.snapshot())==world_before,"Fresh preview reconstruction preserves source, ship and world saves")
	# A stationary orbital ship sees a rotating planet: rebase occasionally, not every frame.
	var changes:=0;var previous_index:int=fresh.drawing.frame_index
	for tick in range(1,61):
		check(fresh.update(clone,copy,world,10+float(tick)*0.1/86400.0),"Short orbital drift remains inside linked preview corridor")
		var mapped:Vector3=fresh.frame.affine_inverse()*copy.position
		check(Vector2(mapped.x,mapped.z).length()<Surface.REBASE_DISTANCE+8,"Preview recenters before local horizontal coordinates grow")
		if fresh.drawing.frame_index!=previous_index:changes+=1;previous_index=fresh.drawing.frame_index
	check(changes>0 and changes<10,"Six seconds of body rotation produce bounded cached frame shifts")
	check(fresh.drawing.globe.get_instance_id()==cached_id,"Drift retains the same sampled globe object")
	check(JSON.stringify(clone.snapshot())==source_before and JSON.stringify(copy.snapshot())==ship_before and JSON.stringify(world.snapshot())==world_before,"Drift and rebasing do not mutate saved game state")
	# Cached previews must stop when their physical context is no longer valid.
	copy.docked=true
	check(not fresh.update(clone,copy,world,10) and fresh.drawing==null,"Docking invalidates preview")
	copy.docked=false
	var center:Vector3=world.local_meters(world.focus_id,10);var radius:float=world.by_id[world.focus_id].radius_km*1000
	var radial:Vector3=(copy.position-center).normalized()
	copy.position=center+radial*(radius+30000)
	check(not fresh.update(clone,copy,world,10),"Preview does not render outside upper altitude band")
	copy.position=center+radial*(radius+1000)
	check(not fresh.update(clone,copy,world,10),"Preview does not render below orbital safety band")
	copy.position=Vector3(saved.orbit_link.position[0],saved.orbit_link.position[1],saved.orbit_link.position[2])
	check(fresh.update(clone,copy,world,10),"Preview reactivates when returning to valid band")
	world.focus_id="moon"
	check(not fresh.update(clone,copy,world,10) and fresh.drawing==null,"Different focus body invalidates linked preview")
	world.focus_id="earth"
	var digest:String=world.source_digest;world.source_digest="changed"
	check(not fresh.update(clone,copy,world,10),"Changed world generation digest invalidates preview")
	world.source_digest=digest
	check(fresh.update(clone,copy,world,10),"Restored matching context can reconstruct preview")
	fresh.clear()
	check(not fresh.active and fresh.drawing==null and fresh.frame==Transform3D.IDENTITY,"Explicit clear resets rendering frame")
	# V1 orbital saves used the previous world-Z embedding. They remain loadable without
	# enabling the new preview against their old world positions.
	var legacy_data:=saved.duplicate(true)
	var legacy_link:Dictionary=legacy_data.orbit_link
	legacy_link.revision=Link.LEGACY_REVISION
	var legacy_direction:=Link.direction(float(legacy_link.latitude),float(legacy_link.longitude));legacy_direction.z=-legacy_direction.z
	var legacy_position:Vector3=world.local_meters(world.focus_id,float(legacy_link.days))+Basis(Vector3.UP,Link.spin(world.by_id[world.focus_id],float(legacy_link.days)))*legacy_direction*(radius+Link.ALTITUDE)
	legacy_link.position=[legacy_position.x,legacy_position.y,legacy_position.z]
	var legacy_ship:=Ship.new();legacy_ship.restore(copy.snapshot());legacy_ship.position=legacy_position
	var legacy_surface:=Surface.new();var legacy_view:=NearView.new()
	check(Link.valid(legacy_link,world),"Legacy V1 link validates using its original embedding")
	check(legacy_surface.restore(legacy_data,legacy_ship,world),"Version-5 surface with V1 orbital link stays loadable")
	check(Link.matches(legacy_surface.orbit_link,world),"Legacy link still matches its physics context")
	var legacy_before:=JSON.stringify(legacy_surface.snapshot());var legacy_ship_before:=JSON.stringify(legacy_ship.snapshot())
	check(not legacy_view.update(legacy_surface,legacy_ship,world,10) and not legacy_view.active,"V1 link does not activate V2 preview against old world positions")
	check(JSON.stringify(legacy_surface.snapshot())==legacy_before and JSON.stringify(legacy_ship.snapshot())==legacy_ship_before,"Legacy no-preview path preserves source and ship")
	var legacy_coords:Array=Link.coordinates(legacy_link,legacy_ship,world,10.125)
	var expected_legacy_lon:=wrapf(float(legacy_link.longitude)+Link.spin(world.by_id[world.focus_id],10.125)-Link.spin(world.by_id[world.focus_id],10),-PI,PI)
	check(absf(legacy_coords[1]-expected_legacy_lon)<1e-12,"V1 stationary-ship longitude keeps its previous spin convention")
	check(legacy_view.enter_descent(legacy_surface,legacy_ship,world,10),"Legacy link can enter via existing descent fallback")
	var legacy_returned:Array=legacy_surface.geographic_position(legacy_ship)
	check(absf(legacy_returned[0]-float(legacy_link.latitude))<1e-12 and absf(legacy_returned[1]-float(legacy_link.longitude))<1e-12,"Legacy descent retains the saved geographic point")
	visual.queue_free();await process_frame
	print("NEAR SURFACE VIEW TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
