extends RefCounted
const Sphere=preload("res://scripts/spherical_terrain.gd")
const SourceTerrain=preload("res://scripts/source_surface_terrain.gd")
const ContactTerrain=preload("res://scripts/source_contact_surface_terrain.gd")
const SOURCE_LAYOUT:="source_jjffe_systems_v4"
const SOURCE_REVISION:="orbit-link-source-v3"
const ALTITUDE:=20000.0
const REVISION:="orbit-link-v2"
const LEGACY_REVISION:="orbit-link-v1"
static func spin(body:Dictionary,days:float)->float:
	return fposmod(days*TAU*24.0/float(body.rotation_hours),TAU)
static func direction(latitude:float,longitude:float)->Vector3:
	return Vector3(cos(latitude)*cos(longitude),sin(latitude),-cos(latitude)*sin(longitude))
static func is_source_layout(system:RefCounted)->bool:return str(system.layout_mode)==SOURCE_LAYOUT
static func rotation_basis(system:RefCounted,body_id:String,days:float)->Basis:
	if is_source_layout(system):return system.body_rotation_basis(body_id,days)
	return Basis(Vector3.UP,spin(system.by_id[body_id],days))
static func preferred_terrain_revision(system:RefCounted)->String:
	return SourceTerrain.REVISION_NAME if is_source_layout(system) else Sphere.CURRENT_REVISION
static func supports_terrain_revision(value:Variant,system:RefCounted)->bool:
	return Sphere.supports_revision(value) or (is_source_layout(system) and value in [SourceTerrain.REVISION_NAME,ContactTerrain.CONTACT_REVISION])
static func _raw_saved_basis(value:Variant)->Basis:
	if not value is Array or value.size()!=9:return Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
	for component in value:
		if not (component is float or component is int) or not is_finite(float(component)) or component<(-2147483648) or component>2147483647 or float(component)!=floorf(float(component)):return Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
	return Basis(Vector3(value[0],value[1],value[2])/2147483648.0,Vector3(value[3],value[4],value[5])/2147483648.0,Vector3(value[6],value[7],value[8])/2147483648.0)
static func _saved_basis(value:Variant)->Basis:
	var basis:=_raw_saved_basis(value)
	return basis.orthonormalized() if basis.determinant()>0.5 else basis
static func _valid_saved_basis(value:Variant)->bool:
	var basis:=_raw_saved_basis(value)
	return absf(basis.determinant()-1.0)<0.01 and absf(basis.x.length_squared()-1.0)<0.01 and absf(basis.y.length_squared()-1.0)<0.01 and absf(basis.z.length_squared()-1.0)<0.01 and absf(basis.x.dot(basis.y))<0.01 and absf(basis.y.dot(basis.z))<0.01 and absf(basis.z.dot(basis.x))<0.01
static func matches(link:Dictionary,system:RefCounted)->bool:
	return not link.is_empty() and link.get("system_id",-1)==system.system_id and link.get("body_id","")==system.focus_id and link.get("layout")==system.layout_mode and link.get("source_digest")==system.source_digest
static func make(surface:RefCounted,ship:RefCounted,system:RefCounted,days:float)->Dictionary:
	var ll:Array=surface.geographic_position(ship)
	var body:Dictionary=system.by_id[system.focus_id]
	var rotation:=rotation_basis(system,system.focus_id,days)
	var radial:Vector3=rotation*direction(ll[0],ll[1])
	var source:bool=surface.globe.revision in [SourceTerrain.REVISION_NAME,ContactTerrain.CONTACT_REVISION]
	var elevation:float=surface.globe.elevation(ll[0],ll[1]) if source else 0.0
	var position:Vector3=system.local_meters(system.focus_id,days)+radial*(surface.globe.radius+elevation+ALTITUDE)
	var link:Dictionary={"revision":REVISION,"layout":system.layout_mode,"source_digest":system.source_digest,"system_id":system.system_id,"body_id":system.focus_id,"site_id":system.site_id,"latitude":ll[0],"longitude":ll[1],"days":days,"position":[position.x,position.y,position.z]}
	if surface.globe.revision!=Sphere.REVISION:link.terrain_revision=surface.globe.revision
	if source:
		link.revision=SOURCE_REVISION;link.surface_elevation_m=elevation
		link.departure_matrix_q31=system.body_rotation_state(system.focus_id,days).matrix_q31.duplicate()
	return link
static func terrain_revision(link:Dictionary)->String:
	return str(link.get("terrain_revision",Sphere.REVISION))
static func anchor(link:Dictionary,system:RefCounted)->String:
	if matches(link,system):return str(link.site_id)
	var site:Dictionary=system.current_site()
	return str(site.id) if not site.is_empty() and site.parent==system.focus_id and int(site.type_code)==35 else ""
static func coordinates(link:Dictionary,ship:RefCounted,system:RefCounted,days:float)->Array:
	if not ship.position.is_finite() or not is_finite(days):return []
	var body:Dictionary=system.by_id[system.focus_id]
	var linked:=matches(link,system)
	if linked:
		var previous:=Vector3(link.position[0],link.position[1],link.position[2])
		if ship.position==previous:
			if str(link.revision)==SOURCE_REVISION:
				if days==float(link.days):return [float(link.latitude),float(link.longitude)]
				if not _valid_saved_basis(link.get("departure_matrix_q31")):return []
				var old_rotation:=_saved_basis(link.departure_matrix_q31)
				var new_rotation:=rotation_basis(system,system.focus_id,days)
				var local:Vector3=new_rotation.inverse()*old_rotation*direction(float(link.latitude),float(link.longitude))
				return [atan2(float(local.y),sqrt(float(local.x)*local.x+float(local.z)*local.z)),atan2(-float(local.z),float(local.x))]
			# Avoid quantizing the saved geographic point through a large float32 Vector3.
			var turn:float=spin(body,days)-spin(body,float(link.days))
			return [float(link.latitude),wrapf(float(link.longitude)+(turn if link.revision==LEGACY_REVISION else -turn),-PI,PI)]
	var offset:Vector3=ship.position-system.local_meters(system.focus_id,days)
	if offset.length()<1:return []
	var local:Vector3=rotation_basis(system,system.focus_id,days).inverse()*offset.normalized()
	return [atan2(float(local.y),sqrt(float(local.x)*local.x+float(local.z)*local.z)),atan2(float(local.z) if linked and link.revision==LEGACY_REVISION else -float(local.z),float(local.x))]
static func valid(link:Variant,system:RefCounted)->bool:
	if not link is Dictionary or link.get("revision") not in [REVISION,LEGACY_REVISION,SOURCE_REVISION]:return false
	if not matches(link,system):return false
	if not supports_terrain_revision(link.get("terrain_revision",Sphere.REVISION),system):return false
	if (link.revision==SOURCE_REVISION)!=(terrain_revision(link) in [SourceTerrain.REVISION_NAME,ContactTerrain.CONTACT_REVISION]):return false
	if link.revision==LEGACY_REVISION and terrain_revision(link)!=Sphere.REVISION:return false
	if not link.get("site_id") is String:return false
	if terrain_revision(link)==ContactTerrain.CONTACT_REVISION and not link.site_id.is_empty():return false
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
	var radial:Vector3=direction(float(link.latitude),float(link.longitude))
	if link.revision==LEGACY_REVISION:radial.z=-radial.z
	var elevation:=0.0
	var rotation:Basis
	if link.revision==SOURCE_REVISION:
		if not is_source_layout(system) or not _valid_saved_basis(link.get("departure_matrix_q31")) or not (link.get("surface_elevation_m") is float or link.get("surface_elevation_m") is int) or not is_finite(float(link.surface_elevation_m)):return false
		var terrain:RefCounted=ContactTerrain.new() if terrain_revision(link)==ContactTerrain.CONTACT_REVISION else SourceTerrain.new()
		terrain.configure(system,system.focus_id,str(link.site_id))
		if not terrain.configured_ok:return false
		elevation=terrain.elevation(float(link.latitude),float(link.longitude))
		if absf(elevation-float(link.surface_elevation_m))>0.002:return false
		rotation=_saved_basis(link.departure_matrix_q31)
	else:rotation=rotation_basis(system,system.focus_id,float(link.days))
	var expected:Vector3=system.local_meters(system.focus_id,float(link.days))+rotation*radial*(float(system.by_id[system.focus_id].radius_km)*1000.0+elevation+ALTITUDE)
	return expected.distance_to(Vector3(link.position[0],link.position[1],link.position[2]))<8.0
