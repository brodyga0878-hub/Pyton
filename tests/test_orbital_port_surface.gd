extends SceneTree
# Real source-port -> spherical surface -> ascent regressions. No Main/user I/O.
const World=preload("res://scripts/planetary_system.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(message)
func fixture(layout:String)->Dictionary:
	var world:=World.new();world.configure(Galaxy.new().get_system(Galaxy.SOL_ID),layout)
	world.focus_id="earth";world.selected_id="earth";world.site_id="site13"
	var ship:=Flight.new();ship.station_available=true;ship.original_port=true
	return {"world":world,"ship":ship,"surface":Surface.new()}
func roundtrip(surface:RefCounted,ship:RefCounted,world:RefCounted,label:String)->void:
	var saved_world:Dictionary=JSON.parse_string(JSON.stringify(world.snapshot()))
	var saved_ship:Dictionary=JSON.parse_string(JSON.stringify(ship.snapshot()))
	var saved_surface:Dictionary=JSON.parse_string(JSON.stringify(surface.snapshot()))
	var restored_world:=World.new();restored_world.configure(world.star_context)
	check(restored_world.restore(saved_world),label+" world restores")
	var restored_ship:=Flight.new();check(restored_ship.restore(saved_ship),label+" flight restores")
	var restored_surface:=Surface.new();check(restored_surface.restore(saved_surface,restored_ship,restored_world),label+" surface restores")
	check(JSON.parse_string(JSON.stringify(restored_world.snapshot()))==saved_world,label+" restore keeps the committed world and empty ground anchor")
func spherical_entry(layout:String)->void:
	var row:=fixture(layout);var world:RefCounted=row.world;var ship:RefCounted=row.ship;var surface:RefCounted=row.surface
	var bank_before:Dictionary=world.get_site("site13").duplicate(true)
	check(world.is_orbital_site(),layout+" starts at the real orbital site")
	check(surface.enter(ship,world,true),layout+" accepts healthy spherical entry")
	check(world.site_id.is_empty() and surface.globe.selected_site_id.is_empty(),layout+" spherical surface has no orbital ground anchor")
	check(world.get_site("site13")==bank_before,layout+" source station record remains unchanged")
	check(surface.leave(ship,world,0.0),layout+" healthy ascent returns to orbit")
	check(surface.orbit_link.site_id.is_empty() and Link.valid(surface.orbit_link,world),layout+" generated v5 geographic link is valid")
	roundtrip(surface,ship,world,layout+" spherical ascent")
func failed_entry(layout:String)->void:
	var row:=fixture(layout);var world:RefCounted=row.world;var ship:RefCounted=row.ship;var surface:RefCounted=row.surface
	var before:Dictionary=world.snapshot().duplicate(true);var position:Vector3=ship.position
	check(not surface.enter(ship,world,true,"invalid-terrain"),layout+" rejects unknown terrain")
	check(world.snapshot()==before and world.site_id=="site13" and ship.position==position and not surface.active,layout+" failed preparation preserves the station frame and flight")
	ship.hull=0
	check(not surface.enter(ship,world,true),layout+" rejects destroyed hull")
	check(world.snapshot()==before and ship.position==position and not surface.active,layout+" rejected entry leaves world and ship position intact")
func flat_legacy_frame(layout:String)->void:
	var row:=fixture(layout);var world:RefCounted=row.world;var ship:RefCounted=row.ship;var surface:RefCounted=row.surface
	var position:Vector3=ship.position
	check(surface.enter(ship,world,false),layout+" legacy flat entry remains available")
	check(world.site_id=="site13" and surface.globe==null,layout+" flat flow keeps its original orbit frame")
	check(surface.leave(ship,world,0.0) and ship.position==position and world.site_id=="site13",layout+" flat return restores the same station-relative position")
func old_active_globe(layout:String)->void:
	var row:=fixture(layout);var world:RefCounted=row.world;var ship:RefCounted=row.ship;var surface:RefCounted=row.surface
	check(surface.enter(ship,world,true),layout+" prepares current spherical fixture")
	# A valid old-format active globe could retain an orbital station id.
	world.site_id="site13"
	var current:Dictionary=surface.snapshot();var old_globe:Dictionary=JSON.parse_string(JSON.stringify(current))
	var restored:=Surface.new();check(restored.restore(old_globe,ship,world),layout+" still loads a valid historical active globe")
	check(world.site_id=="site13",layout+" restore does not silently replace old world frame")
	check(restored.leave(ship,world,0.0),layout+" historical active globe can leave")
	check(world.site_id.is_empty() and Link.valid(restored.orbit_link,world),layout+" historical globe creates a valid empty-anchor orbit link")
	roundtrip(restored,ship,world,layout+" old active globe ascent")
func nearby_geographic_entry()->void:
	var row:=fixture(World.PORT_LAYOUT);var world:RefCounted=row.world;var ship:RefCounted=row.ship;var surface:RefCounted=row.surface
	var days:=0.25
	var centre:Vector3=world.local_meters("earth",days)
	var radial:=Vector3(0.62,0.43,-0.655).normalized()
	ship.position=centre+radial*(float(world.by_id.earth.radius_km)*1000.0+30000.0)
	var ll:Array=Link.coordinates({},ship,world,days)
	check(ll.size()==2,"Port-frame descent has a geographic point before origin changes")
	check(surface.begin_descent(ship,world,days),"Nearby descent from real orbital frame succeeds")
	check(world.site_id.is_empty() and surface.extended_flight and surface.flight_phase=="descent","Nearby descent commits the ordinary planetary surface frame")
	var actual:Array=surface.geographic_position(ship)
	check(absf(float(actual[0])-float(ll[0]))<1e-6 and absf(wrapf(float(actual[1])-float(ll[1]),-PI,PI))<1e-6,"Clearing the station frame preserves the precomputed geographic point")
	roundtrip(surface,ship,world,"Nearby source-port descent")
func run()->void:
	for layout in [World.SOURCE_LAYOUT,World.NATIVE_LAYOUT,World.PORT_LAYOUT]:
		spherical_entry(layout);failed_entry(layout);flat_legacy_frame(layout);old_active_globe(layout)
	nearby_geographic_entry()
	print("ORBITAL PORT SURFACE TESTS: %d checks, %d failures; real orbital-site spherical entry/ascent and atomic rejection, no phone claim"%[checks,failures])
	quit(1 if failures else 0)
