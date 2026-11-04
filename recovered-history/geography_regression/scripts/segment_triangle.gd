extends RefCounted
# Continuous axis-aligned ellipsoid against one double-sided triangle. This is
# a modern collision adapter, not an emulation of the original FFE collision code.
# A strict initial overlap returns a separated contact center at time zero.
# Touching while tangent/separating does not block motion. Positive finite radii
# are required; degenerate triangles retain their segment/point contacts.
const DISTANCE_EPS:=0.000001
const MOTION_EPS:=0.0000000001

static func _dot(first:Vector3,second:Vector3)->float:
	return float(first.x)*second.x+float(first.y)*second.y+float(first.z)*second.z

static func _cross(first:Vector3,second:Vector3)->Vector3:
	return Vector3(float(first.y)*second.z-float(first.z)*second.y,float(first.z)*second.x-float(first.x)*second.z,float(first.x)*second.y-float(first.y)*second.x)

static func _at(start:Vector3,delta:Vector3,time:float)->Vector3:
	# Scalar arithmetic avoids an intermediate float32 product on fast sweeps.
	return Vector3(float(start.x)+float(delta.x)*time,float(start.y)+float(delta.y)*time,float(start.z)+float(delta.z)*time)

static func _unit(value:Vector3)->Vector3:
	var length_squared:=_dot(value,value)
	return value/sqrt(length_squared) if length_squared>1e-30 else Vector3.ZERO

static func _scaled(value:Vector3,radii:Vector3)->Vector3:
	return Vector3(float(value.x)/radii.x,float(value.y)/radii.y,float(value.z)/radii.z)

static func _inside_face(point:Vector3,a:Vector3,b:Vector3,c:Vector3,normal:Vector3)->bool:
	var normal_squared:=_dot(normal,normal)
	var vertices:Array[Vector3]=[a,b,c]
	for index in range(3):
		var edge:Vector3=vertices[(index+1)%3]-vertices[index]
		var tolerance:=DISTANCE_EPS*sqrt(_dot(edge,edge)*normal_squared)
		if _dot(_cross(edge,point-vertices[index]),normal)<-tolerance:return false
	return true

static func _closest_segment(point:Vector3,a:Vector3,b:Vector3)->Vector3:
	var edge:=b-a
	var length_squared:=_dot(edge,edge)
	if length_squared<=1e-30:return a
	return _at(a,edge,clampf(_dot(point-a,edge)/length_squared,0,1))

static func _closest_triangle(point:Vector3,a:Vector3,b:Vector3,c:Vector3,normal:Vector3)->Vector3:
	var normal_squared:=_dot(normal,normal)
	if normal_squared>1e-30:
		var projected:=_at(point,normal,-_dot(point-a,normal)/normal_squared)
		if _inside_face(projected,a,b,c,normal):return projected
	var closest:=_closest_segment(point,a,b)
	for candidate in [_closest_segment(point,b,c),_closest_segment(point,c,a)]:
		if _dot(candidate-point,candidate-point)<_dot(closest-point,closest-point):closest=candidate
	return closest

static func _overlap_normal(delta:Vector3,a:Vector3,b:Vector3,c:Vector3,normal:Vector3)->Vector3:
	if _dot(normal,normal)>1e-30:
		var unit:=_unit(normal)
		var direction:=_dot(delta,unit)
		if absf(direction)>MOTION_EPS:return unit*(-signf(direction))
		# A stationary center exactly on the plane needs a deterministic side.
		var dominant:=0
		if absf(unit.y)>absf(unit[dominant]):dominant=1
		if absf(unit.z)>absf(unit[dominant]):dominant=2
		return unit if unit[dominant]>=0 else -unit
	var longest:=b-a
	for edge in [c-b,a-c]:
		if _dot(edge,edge)>_dot(longest,longest):longest=edge
	if _dot(longest,longest)<=1e-30:
		return _unit(-delta) if _dot(delta,delta)>1e-30 else Vector3.UP
	var perpendicular:=_at(-delta,longest,_dot(delta,longest)/_dot(longest,longest))
	if _dot(perpendicular,perpendicular)>1e-30:return _unit(perpendicular)
	var axis:=Vector3.UP if absf(_unit(longest).y)<0.9 else Vector3.RIGHT
	return _unit(_cross(longest,axis))

static func _sphere_entry(offset:Vector3,delta:Vector3)->float:
	var speed_squared:=_dot(delta,delta)
	if speed_squared<=1e-30:return INF
	# Closest approach avoids cancellation in b*b-4*a*c for long, fast paths.
	var middle:float=-_dot(offset,delta)/speed_squared
	var nearest:=_at(offset,delta,middle)
	var distance_squared:=_dot(nearest,nearest)
	if distance_squared>1.0+DISTANCE_EPS:return INF
	return middle-sqrt(maxf(0.0,1.0-distance_squared)/speed_squared)

static func _consider(best:Dictionary,start:Vector3,delta:Vector3,time:float,normal:Vector3)->void:
	if not is_finite(time):return
	var speed:=sqrt(_dot(delta,delta))
	var time_tolerance:=DISTANCE_EPS/maxf(1.0,speed)
	if time<-time_tolerance or time>1.0+time_tolerance:return
	time=clampf(time,0,1)
	var unit:=_unit(normal)
	if unit==Vector3.ZERO or _dot(unit,delta)>=-MOTION_EPS*maxf(1.0,speed):return
	if time<float(best.get("time",INF)):
		best.time=time;best.normal=unit

static func _result(start:Vector3,finish:Vector3,radii:Vector3,time:float,normal:Vector3,inside:bool,center:Vector3,origin:Vector3)->Dictionary:
	var position:=Vector3(float(start.x)+(float(finish.x)-start.x)*time,float(start.y)+(float(finish.y)-start.y)*time,float(start.z)+(float(finish.z)-start.z)*time)
	if inside:position=Vector3(float(origin.x)+float(center.x)*radii.x,float(origin.y)+float(center.y)*radii.y,float(origin.z)+float(center.z)*radii.z)
	var world_normal:=_unit(_scaled(normal,radii))
	return {"time":time,"position":position,"normal":world_normal,"inside":inside}

static func sweep(start:Vector3,finish:Vector3,triangle:Array[Vector3],radii:Vector3)->Dictionary:
	if triangle.size()!=3 or not start.is_finite() or not finish.is_finite() or not radii.is_finite() or radii.x<=0 or radii.y<=0 or radii.z<=0:return {}
	for vertex in triangle:
		if not vertex.is_finite():return {}
	var origin:Vector3=triangle[0]
	var a:=Vector3.ZERO;var b:=_scaled(triangle[1]-origin,radii);var c:=_scaled(triangle[2]-origin,radii)
	var first:=_scaled(start-origin,radii);var last:=_scaled(finish-origin,radii)
	if not first.is_finite() or not last.is_finite() or not b.is_finite() or not c.is_finite():return {}
	var delta:=last-first
	var normal:=_cross(b,c)
	var longest_squared:=maxf(_dot(b,b),maxf(_dot(c,c),_dot(c-b,c-b)))
	if _dot(normal,normal)<=1e-20*longest_squared*longest_squared:normal=Vector3.ZERO
	var closest:=_closest_triangle(first,a,b,c,normal)
	var separation:=first-closest;var distance_squared:=_dot(separation,separation)
	if distance_squared<(1.0-DISTANCE_EPS)*(1.0-DISTANCE_EPS):
		var outward:=_unit(separation)
		if outward==Vector3.ZERO:outward=_overlap_normal(delta,a,b,c,normal)
		return _result(start,finish,radii,0,outward,true,closest+outward,origin)
	var best:Dictionary={}
	if distance_squared<=1.0+DISTANCE_EPS:
		_consider(best,first,delta,0,separation)
	if _dot(delta,delta)<=1e-30:
		return _result(start,finish,radii,float(best.time),best.normal,false,Vector3.ZERO,origin) if not best.is_empty() else {}
	var normal_squared:=_dot(normal,normal)
	if normal_squared>1e-30:
		var speed_normal:=_dot(delta,normal)
		var signed_distance:=_dot(first,normal)
		if absf(speed_normal)>1e-30:
			for side in [-1.0,1.0]:
				if side*speed_normal>=0:continue
				var time:float=(side*sqrt(normal_squared)-signed_distance)/speed_normal
				var center:=_at(first,delta,time)
				var point:=_at(center,normal,-_dot(center,normal)/normal_squared)
				if _inside_face(point,a,b,c,normal):_consider(best,first,delta,time,normal*side)
	var vertices:Array[Vector3]=[a,b,c]
	for index in range(3):
		var vertex:Vector3=vertices[index]
		var vertex_time:=_sphere_entry(first-vertex,delta)
		if is_finite(vertex_time):_consider(best,first,delta,vertex_time,_at(first-vertex,delta,vertex_time))
		var edge:Vector3=vertices[(index+1)%3]-vertex
		var edge_squared:=_dot(edge,edge)
		if edge_squared<=1e-30:continue
		var offset:=first-vertex
		var perpendicular:=_at(offset,edge,-_dot(offset,edge)/edge_squared)
		var perpendicular_delta:=_at(delta,edge,-_dot(delta,edge)/edge_squared)
		var edge_time:=_sphere_entry(perpendicular,perpendicular_delta)
		if not is_finite(edge_time):continue
		var center:=_at(first,delta,edge_time)
		var along:float=_dot(center-vertex,edge)/edge_squared
		var along_tolerance:=DISTANCE_EPS/maxf(sqrt(edge_squared),DISTANCE_EPS)
		if along<-along_tolerance or along>1.0+along_tolerance:continue
		_consider(best,first,delta,edge_time,center-_at(vertex,edge,clampf(along,0,1)))
	if best.is_empty():return {}
	return _result(start,finish,radii,float(best.time),best.normal,false,Vector3.ZERO,origin)
