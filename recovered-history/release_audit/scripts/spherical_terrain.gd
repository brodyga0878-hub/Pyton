extends RefCounted
# A new deterministic spherical terrain, not the original FFE terrain generator.
# Latitude/longitude and trigonometry use scalar doubles; Vector3 stays local.
const REVISION:="sphere-v1"
var radius:=6371000.0
var seed_value:=0
var latitude:=0.0
var longitude:=0.0
var pad_latitude:=0.0
var pad_longitude:=0.0
var flat_sites:Array=[]
func configure(system:RefCounted,body_id:String,site_id:String)->void:
	radius=float(system.by_id[body_id].radius_km)*1000.0
	seed_value=system.system_id^body_id.hash()
	flat_sites=[site_coordinates("")]
	for site in system.settlements:
		if str(site.parent)==body_id and int(site.type_code)==35:flat_sites.append(site_coordinates(str(site.id)))
	var pad:=site_coordinates(site_id)
	pad_latitude=pad[0];pad_longitude=pad[1]
	latitude=pad_latitude;longitude=pad_longitude
func site_coordinates(id:String)->Array:
	# Stable artistic locations until original FFE surface coordinates are decoded.
	var key:=str(seed_value)+":"+id
	return [(float((key+":lat").hash()&0x7fffffff)/2147483647.0-0.5)*2.4,(float((key+":lon").hash()&0x7fffffff)/2147483647.0-0.5)*TAU]
func coordinates(x:float,z:float)->Array:
	var distance:=sqrt(x*x+z*z)
	if distance<0.000001:return [latitude,longitude]
	var angle:=distance/radius
	var sn:=sin(angle);var cs:=cos(angle)
	var north:=-z/distance;var east:=x/distance
	var sl:=sin(latitude);var cl:=cos(latitude);var so:=sin(longitude);var co:=cos(longitude)
	var cx:=cl*co*cs+sn*(-east*so-north*sl*co)
	var cy:=sl*cs+sn*north*cl
	var cz:=cl*so*cs+sn*(east*co-north*sl*so)
	return [atan2(cy,sqrt(cx*cx+cz*cz)),atan2(cz,cx)]

func project(lat:float,lon:float)->Vector2:
	var dl:=wrapf(lon-longitude,-PI,PI)
	var east:=cos(lat)*sin(dl)
	var north:=cos(latitude)*sin(lat)-sin(latitude)*cos(lat)*cos(dl)
	var up:=sin(latitude)*sin(lat)+cos(latitude)*cos(lat)*cos(dl)
	var tangent:=sqrt(east*east+north*north)
	if tangent<1e-14:return Vector2.ZERO if up>0 else Vector2(PI*radius,0)
	var scale:=atan2(tangent,up)*radius/tangent
	return Vector2(east*scale,-north*scale)
func distance_to(lat:float,lon:float)->float:
	# Haversine avoids cancellation for nearby sites and remains finite at antipodes.
	var a:=pow(sin((lat-latitude)*0.5),2)+cos(latitude)*cos(lat)*pow(sin((lon-longitude)*0.5),2)
	return 2.0*radius*asin(sqrt(clampf(a,0.0,1.0)))
func elevation(lat:float,lon:float)->float:
	var cl:=cos(lat)
	var x:=radius*cl*cos(lon);var y:=radius*sin(lat);var z:=radius*cl*sin(lon)
	var phase:=float(seed_value&1023)*0.013
	var relief:=sin(x*0.0007+phase)*cos(y*0.0009+phase)*110.0+sin(z*0.0023+x*0.0011)*30.0+sin(y*0.006-z*0.004)*8.0
	var nearest:=10000.0
	for site in flat_sites:
		if absf(lat-float(site[0]))*radius>420.0:continue
		var a:=pow(sin((lat-float(site[0]))*0.5),2)+cos(lat)*cos(float(site[0]))*pow(sin((lon-float(site[1]))*0.5),2)
		nearest=minf(nearest,2.0*radius*asin(sqrt(clampf(a,0.0,1.0))))
	return relief*smoothstep(100.0,420.0,nearest)
func raw_height(x:float,z:float)->float:
	var ll:=coordinates(x,z)
	var angle:=sqrt(x*x+z*z)/radius
	return elevation(ll[0],ll[1])*cos(angle)-2.0*radius*pow(sin(angle*0.5),2)
func basis_at(lat:float,lon:float)->Basis:
	var sl:=sin(lat);var cl:=cos(lat);var sn:=sin(lon);var cs:=cos(lon)
	return Basis(Vector3(-sn,0,cs),Vector3(cl*cs,sl,cl*sn),Vector3(sl*cs,-cl,sl*sn))

func sample(x:float,z:float)->PackedFloat64Array:
	# One geographic conversion and elevation sample serves height, colour and material coordinates.
	var ll:=coordinates(x,z)
	var relief:=elevation(ll[0],ll[1])
	var angle:=sqrt(x*x+z*z)/radius
	var height:=relief*cos(angle)-2.0*radius*pow(sin(angle*0.5),2)
	return PackedFloat64Array([height,relief,radius*cos(ll[0])*cos(ll[1]),radius*sin(ll[0]),radius*cos(ll[0])*sin(ll[1])])
