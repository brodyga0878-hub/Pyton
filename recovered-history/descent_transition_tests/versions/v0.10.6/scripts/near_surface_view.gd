extends RefCounted
# Render-only bridge: physics stays in its existing orbital or surface coordinates.
const Surface=preload("res://scripts/surface_model.gd")
const Link=preload("res://scripts/surface_orbit_link.gd")
const Sphere=preload("res://scripts/spherical_terrain.gd")
const Ship=preload("res://scripts/flight_model.gd")
const FADE_START:=23800.0
const FADE_END:=60000.0
var space_blend:=0.0
static func far_blend(geoid_height:float)->float:
	return smoothstep(FADE_START,FADE_END,geoid_height)
var active:=false
var drawing:RefCounted
var frame:=Transform3D.IDENTITY
var height:=0.0
var owner_id:=0
static func world_frame(globe:RefCounted,system:RefCounted,days:float)->Transform3D:
	var rotation:=Basis(Vector3.UP,Link.spin(system.by_id[system.focus_id],days))
	var basis:Basis=rotation*globe.basis_at(globe.latitude,globe.longitude)
	return Transform3D(basis,system.local_meters(system.focus_id,days)+basis.y*float(globe.radius))
func clear()->void:
	active=false;drawing=null;owner_id=0;frame=Transform3D.IDENTITY;space_blend=0.0
func update(surface:RefCounted,ship:RefCounted,system:RefCounted,days:float)->bool:
	if surface.active or ship.docked or not Link.matches(surface.orbit_link,system) or surface.orbit_link.get("revision")!=Link.REVISION:clear();return false
	var geoid_height:float=ship.position.distance_to(system.local_meters(system.focus_id,days))-float(system.by_id[system.focus_id].radius_km)*1000.0
	if geoid_height<1800 or geoid_height>FADE_END:clear();return false
	if drawing==null or owner_id!=surface.get_instance_id():
		drawing=Surface.new();owner_id=surface.get_instance_id()
		drawing.body_id=system.focus_id;drawing.kind=str(system.by_id[system.focus_id].kind)
		drawing.seed_value=system.system_id^system.focus_id.hash()
		var anchor:String=surface.orbit_link.site_id
		if not anchor.is_empty():drawing.seed_value^=anchor.hash();drawing.site_name=str(system.get_site(anchor).name)
		if surface.globe!=null:
			drawing.globe=surface.globe;drawing.frame_index=surface.frame_index
		else:
			drawing.globe=Sphere.new();drawing.globe.configure(system,system.focus_id,anchor)
			var ll:Array=Link.coordinates(surface.orbit_link,ship,system,days)
			if ll.is_empty():clear();return false
			drawing.globe.latitude=ll[0];drawing.globe.longitude=ll[1]
		drawing.active=true;drawing.extended_flight=true
	frame=world_frame(drawing.globe,system,days)
	var local:Vector3=_local_position(surface,ship,system,days)
	if Vector2(local.x,local.z).length()>Surface.REBASE_DISTANCE:
		var surrogate:=Ship.new();surrogate.ship_id=ship.ship_id
		surrogate.position=local;surrogate.velocity=frame.basis.inverse()*ship.velocity
		surrogate.attitude=(frame.basis.inverse()*Basis(ship.attitude)).get_rotation_quaternion()
		drawing.recenter(surrogate)
		frame=world_frame(drawing.globe,system,days);local=_local_position(surface,ship,system,days)
	space_blend=far_blend(geoid_height)
	height=local.y-drawing.height_at(local.x,local.z)-drawing.clearance(ship)
	active=true
	return true
func enter_descent(surface:RefCounted,ship:RefCounted,system:RefCounted,days:float)->bool:
	if not update(surface,ship,system,days):return surface.begin_descent(ship,system,days)
	var cached:RefCounted=drawing
	var local:Vector3=_local_position(surface,ship,system,days)
	var attitude:Quaternion=(frame.basis.inverse()*Basis(ship.attitude)).get_rotation_quaternion().normalized()
	var velocity:Vector3=frame.basis.inverse()*ship.velocity
	if not surface.begin_descent(ship,system,days):return false
	surface.globe=cached.globe;surface.frame_index=cached.frame_index
	ship.position=local;ship.attitude=attitude;ship.velocity=velocity
	return true

func _local_position(surface:RefCounted,ship:RefCounted,system:RefCounted,days:float)->Vector3:
	var ll:Array=Link.coordinates(surface.orbit_link,ship,system,days)
	var xz:Vector2=drawing.globe.project(ll[0],ll[1])
	var radius:float=drawing.globe.radius
	var geoid_height:float=ship.position.distance_to(system.local_meters(system.focus_id,days))-radius
	var record:Array=surface.orbit_link.position
	if ship.position==Vector3(record[0],record[1],record[2]):geoid_height=Link.ALTITUDE
	var angle:float=xz.length()/radius
	return Vector3(xz.x,geoid_height*cos(angle)-2.0*radius*pow(sin(angle*0.5),2),xz.y)
