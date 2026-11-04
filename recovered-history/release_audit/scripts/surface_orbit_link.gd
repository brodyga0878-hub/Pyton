extends RefCounted
const Sphere=preload("res://scripts/spherical_terrain.gd")
const ALTITUDE:=20000.0
const REVISION:="orbit-link-v1"
static func spin(body:Dictionary,days:float)->float:
	return fposmod(days*TAU*24.0/float(body.rotation_hours),TAU)
static func direction(latitude:float,longitude:float)->Vector3:
	return Vector3(cos(latitude)*cos(longitude),sin(latitude),cos(latitude)*sin(longitude))
static func matches(link:Dictionary,system:RefCounted)->bool:
	return not link.is_empty() and link.get("system_id",-1)==system.system_id and link.get("body_id","")==system.focus_id and link.get("layout")==system.layout_mode and link.get("source_digest")==system.source_digest
static func make(surface:RefCounted,ship:RefCounted,system:RefCounted,days:float)->Dictionary:
	var ll:Array=surface.geographic_position(ship)
	var body:Dictionary=system.by_id[system.focus_id]
	var radial:Vector3=Basis(Vector3.UP,spin(body,days))*direction(ll[0],ll[1])
	var position:Vector3=system.local_meters(system.focus_id,days)+radial*(surface.globe.radius+ALTITUDE)
	return {"revision":REVISION,"layout":system.layout_mode,"source_digest":system.source_digest,"system_id":system.system_id,"body_id":system.focus_id,"site_id":system.site_id,"latitude":ll[0],"longitude":ll[1],"days":days,"position":[position.x,position.y,position.z]}
static func coordinates(link:Dictionary,ship:RefCounted,system:RefCounted,days:float)->Array:
	var body:Dictionary=system.by_id[system.focus_id]
	var previous:=Vector3(link.position[0],link.position[1],link.position[2])
	if ship.position==previous:
		# Avoid quantizing the saved geographic point through a large float32 Vector3.
		return [float(link.latitude),wrapf(float(link.longitude)+spin(body,days)-spin(body,float(link.days)),-PI,PI)]
	var offset:Vector3=ship.position-system.local_meters(system.focus_id,days)
	if offset.length()<1:return []
	var local:Vector3=Basis(Vector3.UP,-spin(body,days))*offset.normalized()
	return [atan2(float(local.y),sqrt(float(local.x)*local.x+float(local.z)*local.z)),atan2(float(local.z),float(local.x))]
static func valid(link:Variant,system:RefCounted)->bool:
	if not link is Dictionary or link.get("revision")!=REVISION:return false
	if not matches(link,system):return false
	if not link.get("site_id") is String:return false
	if not link.site_id.is_empty():
		var site:Dictionary=system.get_site(link.site_id)
		if site.is_empty() or site.parent!=system.focus_id or int(site.type_code)!=35:return false
	if str(system.by_id[system.focus_id].kind) in ["star","barycenter","gas","ice_gas"]:return false
	for key in ["latitude","longitude","days"]:
		if not (link.get(key) is float or link.get(key) is int) or not is_finite(float(link[key])):return false
	if absf(float(link.latitude))>PI/2 or absf(float(link.longitude))>PI or float(link.days)<0 or float(link.days)>1e9:return false
	if not link.get("position") is Array or link.position.size()!=3:return false
	for n in link.position:
		if not (n is float or n is int) or not is_finite(float(n)) or absf(float(n))>1e9:return false
	var expected:Vector3=system.local_meters(system.focus_id,float(link.days))+Basis(Vector3.UP,spin(system.by_id[system.focus_id],float(link.days)))*direction(float(link.latitude),float(link.longitude))*(float(system.by_id[system.focus_id].radius_km)*1000.0+ALTITUDE)
	return expected.distance_to(Vector3(link.position[0],link.position[1],link.position[2]))<8.0
