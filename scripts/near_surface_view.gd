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
var context_key:=""
var _source_sampler:RefCounted
var _source_sampler_key:=""
var _preview_worker:Thread
var _preview_bundle:Dictionary={}
func _notification(what:int)->void:
	# A RefCounted self cannot dispatch another script method duringPREDELETE.
	if what==NOTIFICATION_PREDELETE and _preview_worker!=null:
		_preview_worker.wait_to_finish();_preview_worker=null
func finish_preparation()->void:
	if _preview_worker==null:return
	var result:Variant=_preview_worker.wait_to_finish();_preview_worker=null
	_preview_bundle=result if result is Dictionary else {}
func _prepare_enclosed_preview(system:RefCounted,ship:RefCounted,days:float)->Dictionary:
	var context:=Surface._entry_context(system,ship)
	if _preview_worker!=null:
		if _preview_worker.is_alive():return {}
		finish_preparation()
	if _preview_bundle.get("ok",false) and _preview_bundle.get("context")==context:return _preview_bundle
	_preview_bundle={}
	var snapshot:=Surface.create_entry_snapshot(system,ship,days)
	if snapshot.is_empty():return {}
	_preview_worker=Thread.new()
	if _preview_worker.start(Surface.prepare_entry.bind(snapshot))!=OK:_preview_worker=null
	return {}
static func world_frame(globe:RefCounted,system:RefCounted,days:float)->Transform3D:
	var rotation:=Link.rotation_basis(system,system.focus_id,days)
	var basis:Basis=rotation*globe.basis_at(globe.latitude,globe.longitude)
	return Transform3D(basis,system.local_meters(system.focus_id,days)+basis.y*float(globe.radius))
func clear()->void:
	active=false;drawing=null;owner_id=0;context_key="";frame=Transform3D.IDENTITY;space_blend=0.0
func update(surface:RefCounted,ship:RefCounted,system:RefCounted,days:float)->bool:
	if not ship.position.is_finite() or not is_finite(days):clear();return false
	if surface.active or ship.docked or str(system.by_id[system.focus_id].kind) in ["star","barycenter","gas","ice_gas"]:clear();return false
	var linked:=Link.matches(surface.orbit_link,system)
	if linked and surface.orbit_link.get("revision")==Link.LEGACY_REVISION:clear();return false
	var geoid_height:float=ship.position.distance_to(system.local_meters(system.focus_id,days))-float(system.by_id[system.focus_id].radius_km)*1000.0
	if Link.is_source_layout(system):
		var body:Dictionary=system.by_id[system.focus_id]
		if not body.get("landable",false):clear();return false
		# Reject known-distant orbit points before loading any source sampler,
		# constructing city anchors or evaluating terrain rays on the render path.
		var envelope:=maxf(float(body.get("source_outer_bound_m",0.0)),float(body.radius_km)*1000.0)
		if ship.position.distance_to(system.local_meters(system.focus_id,days))>envelope+FADE_END:clear();return false
	var anchor:String=Link.anchor(surface.orbit_link,system)
	var terrain_revision:String=Link.terrain_revision(surface.orbit_link) if linked else Surface.preferred_terrain_revision(system)
	# Source terrain may be far below its static-axis reference sphere. Use
	# height above that actual field for preview eligibility and transition.
	var source_globe:RefCounted=null
	var enclosed_bundle:Dictionary={}
	if Link.is_source_layout(system):
		var selected_site:Dictionary=system.get_site(anchor)
		if int(selected_site.get("model_index",-1))==96 and anchor==str(system.site_id):
			enclosed_bundle=_prepare_enclosed_preview(system,ship,days)
			if enclosed_bundle.is_empty():clear();return false
		var sampler_key:String=str(system.system_id)+":"+system.focus_id+":"+system.layout_mode+":"+system.source_digest+":"+anchor+":"+terrain_revision
		if _source_sampler==null or _source_sampler_key!=sampler_key:
			_source_sampler=enclosed_bundle.globe if not enclosed_bundle.is_empty() else Surface.make_globe(system,system.focus_id,anchor,terrain_revision);_source_sampler_key=sampler_key
		source_globe=_source_sampler
		var source_ll:=Link.coordinates(surface.orbit_link,ship,system,days)
		if source_globe==null or source_ll.is_empty():clear();return false
		geoid_height-=source_globe.elevation(source_ll[0],source_ll[1])
	if geoid_height<Surface.MIN_DESCENT_HEIGHT or geoid_height>FADE_END:clear();return false
	var key:String=str(system.system_id)+":"+system.focus_id+":"+system.layout_mode+":"+system.source_digest+":"+anchor+":"+terrain_revision
	if drawing==null or owner_id!=surface.get_instance_id() or context_key!=key:
		drawing=Surface.new();owner_id=surface.get_instance_id();context_key=key
		drawing.body_id=system.focus_id;drawing.kind=str(system.by_id[system.focus_id].kind)
		drawing.seed_value=system.system_id^system.focus_id.hash()
		if not anchor.is_empty():drawing.seed_value^=anchor.hash();drawing.site_name=str(system.get_site(anchor).name)
		if linked and surface.globe!=null and surface.globe.revision==terrain_revision:
			drawing.globe=surface.globe;drawing.frame_index=surface.frame_index
		else:
			drawing.globe=source_globe if source_globe!=null else Surface.make_globe(system,system.focus_id,anchor,terrain_revision)
			if drawing.globe==null:clear();return false
			var ll:Array=Link.coordinates(surface.orbit_link,ship,system,days)
			if ll.is_empty():clear();return false
			drawing.globe.latitude=ll[0];drawing.globe.longitude=ll[1]
		if not enclosed_bundle.is_empty():
			drawing.city_data=enclosed_bundle.data;drawing.underground=enclosed_bundle.underground
			drawing.source_render_packet=enclosed_bundle.render_packet;drawing.source_render_worker_state=enclosed_bundle.render_worker_state
		elif not drawing.bind_city(system.get_site(anchor)):clear();return false
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
	drawing.render_position=local
	drawing.render_velocity=frame.basis.inverse()*ship.velocity
	height=local.y-drawing.height_at(local.x,local.z)-drawing.clearance(ship)
	active=true
	return true
func enter_descent(surface:RefCounted,ship:RefCounted,system:RefCounted,days:float)->bool:
	if surface.has_prepared_entry(system,ship):return surface.begin_descent(ship,system,days)
	if not update(surface,ship,system,days):return surface.begin_descent(ship,system,days)
	var cached:RefCounted=drawing
	var local:Vector3=_local_position(surface,ship,system,days)
	var attitude:Quaternion=(frame.basis.inverse()*Basis(ship.attitude)).get_rotation_quaternion().normalized()
	var velocity:Vector3=frame.basis.inverse()*ship.velocity
	if not surface.begin_descent(ship,system,days):return false
	surface.globe=cached.globe;surface.frame_index=cached.frame_index;surface.city_data=cached.city_data
	ship.position=local;ship.attitude=attitude;ship.velocity=velocity
	return true

func _local_position(surface:RefCounted,ship:RefCounted,system:RefCounted,days:float)->Vector3:
	var ll:Array=Link.coordinates(surface.orbit_link,ship,system,days)
	var xz:Vector2=drawing.globe.project(ll[0],ll[1])
	var radius:float=drawing.globe.radius
	var geoid_height:float=ship.position.distance_to(system.local_meters(system.focus_id,days))-radius
	if Link.matches(surface.orbit_link,system):
		var record:Array=surface.orbit_link.position
		if ship.position==Vector3(record[0],record[1],record[2]):geoid_height=Link.ALTITUDE+float(surface.orbit_link.get("surface_elevation_m",0.0))
	if drawing.source_surface():
		# Source projector uses the physical tangent distance, including the
		# ship's current radial height rather than the surface's smaller radius.
		var dl:float=float(ll[1])-float(drawing.globe.longitude)
		var radial:float=radius+geoid_height
		var east:float=radial*cos(float(ll[0]))*sin(dl)
		var south:float=radial*(sin(float(drawing.globe.latitude))*cos(float(ll[0]))*cos(dl)-cos(float(drawing.globe.latitude))*sin(float(ll[0])))
		var up:float=radial*(sin(float(drawing.globe.latitude))*sin(float(ll[0]))+cos(float(drawing.globe.latitude))*cos(float(ll[0]))*cos(dl))-radius
		return Vector3(east,up,south)
	var angle:float=xz.length()/radius
	return Vector3(xz.x,geoid_height*cos(angle)-2.0*radius*pow(sin(angle*0.5),2),xz.y)
