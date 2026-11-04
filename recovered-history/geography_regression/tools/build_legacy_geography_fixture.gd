extends SceneTree
# Execute this script with --path pointing to an extracted, unchanged 0.10.7 project.
# The preload paths intentionally resolve against that previous project, not this one.
const Surface=preload("res://scripts/surface_model.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
var cases:Array=[]
var nav:=Nav.new()
func _init()->void:call_deferred("run")
func prepare()->Dictionary:
	var world:=World.new();world.configure(nav.current());world.site_id="site10"
	var ship:=Ship.new();ship.credits=7319;ship.goods.medicines=4
	var surface:=Surface.new()
	assert(surface.enter(ship,world,true))
	ship.velocity=Vector3.ZERO;ship.assisted=true;ship.target_speed=0
	return {"world":world,"ship":ship,"surface":surface}
func encode_boxes(surface:RefCounted)->Array:
	var boxes:Array=[]
	for box in surface.buildings():boxes.append([box.position.x,box.position.y,box.position.z,box.size.x,box.size.y,box.size.z])
	return boxes
func capture(label:String,context:Dictionary)->void:
	var surface:RefCounted=context.surface;var ship:RefCounted=context.ship
	var heights:Array=[]
	for point in [Vector2.ZERO,Vector2(-400,-350),Vector2(140,270),Vector2(380,-120)]:
		heights.append([point.x,point.y,surface.height_at(point.x,point.y)])
	cases.append({"label":label,"navigation":nav.snapshot(),"world":context.world.snapshot(),"flight":ship.snapshot(),"surface":surface.snapshot(),"geographic":surface.geographic_position(ship) if surface.active else [surface.globe.latitude,surface.globe.longitude],"pad_coordinates":[surface.globe.pad_latitude,surface.globe.pad_longitude],"pad_distance":surface.pad_distance(ship) if surface.active else 0,"height_samples":heights,"buildings":encode_boxes(surface)})
func run()->void:
	assert(not FileAccess.get_file_as_string("res://scripts/spherical_terrain.gd").contains("SOURCE_REVISION"),"The generator must run against the unchanged previous source package")
	nav.elapsed_days=25.125
	var context:=prepare();var surface:RefCounted=context.surface;var ship:RefCounted=context.ship
	var pad:Vector3=surface.pad_position();ship.position=Vector3(pad.x,surface.height_at(pad.x,pad.z)+surface.clearance(ship),pad.z)
	surface.recenter(ship);assert(surface.touch_down(ship));capture("landed_port_v4",context)
	context=prepare();capture("hovering_port_v4",context)
	context=prepare();surface=context.surface;ship=context.ship
	surface.extended_flight=true;surface.flight_phase="descent"
	ship.position.y=surface.height_at(0,0)+surface.clearance(ship)+41900;ship.velocity=Vector3(0,-120,0)
	capture("descending_high_v6",context)
	context=prepare();surface=context.surface;ship=context.ship
	for index in range(45):
		ship.position=Vector3(600,surface.height_at(600,0)+surface.clearance(ship)+700,0);surface.recenter(ship)
	ship.position.y=surface.height_at(0,0)+surface.clearance(ship);assert(surface.touch_down(ship))
	capture("landed_wilderness_v4",context)
	context=prepare();surface=context.surface;ship=context.ship
	for index in range(45):
		ship.position=Vector3(600,surface.height_at(600,0)+surface.clearance(ship)+700,0);surface.recenter(ship)
	surface.extended_flight=true;ship.position.y=surface.height_at(0,0)+surface.clearance(ship)+20000
	capture("paused_wilderness_v6",context)
	context=prepare();surface=context.surface;ship=context.ship
	ship.position=Vector3(0,surface.height_at(0,0)+surface.clearance(ship)+700,0)
	assert(surface.leave(ship,context.world,nav.elapsed_days));context.world.site_id=""
	capture("orbital_v5_link_v2",context)
	var link:Dictionary=surface.orbit_link
	link.revision=Link.LEGACY_REVISION
	var radial:Vector3=Link.direction(float(link.latitude),float(link.longitude));radial.z=-radial.z
	var position:Vector3=context.world.local_meters(context.world.focus_id,nav.elapsed_days)+Basis(Vector3.UP,Link.spin(context.world.by_id[context.world.focus_id],nav.elapsed_days))*radial*(float(surface.globe.radius)+Link.ALTITUDE)
	link.position=[position.x,position.y,position.z];ship.position=position
	assert(Link.valid(link,context.world));capture("orbital_v5_link_v1",context)
	var arguments:=OS.get_cmdline_user_args()
	assert(arguments.size()==2,"Pass output path and source-zip SHA-256 after --")
	var script_hashes:Dictionary={}
	for name in ["surface_model","spherical_terrain","surface_orbit_link"]:script_hashes[name]=FileAccess.get_sha256("res://scripts/"+name+".gd")
	var output:Dictionary={"schema":1,"source_version":"0.10.7-alpha1","source_zip":"starfrontier-stage10-18-source.zip","source_zip_sha256":arguments[1],"source_script_sha256":script_hashes,"scope":"Actual snapshots and geographic samples produced by the unchanged previous project's scripts, before source-site geography was introduced.","cases":cases}
	var file:=FileAccess.open(arguments[0],FileAccess.WRITE);assert(file!=null)
	file.store_string(JSON.stringify(output));file.close()
	print("LEGACY GEOGRAPHY FIXTURE: %d cases"%cases.size());quit()
