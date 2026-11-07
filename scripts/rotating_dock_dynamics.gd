extends RefCounted
# Explicit modern rigid-contact adapter over original source station poses.
# This is not F582/F583 or a reconstruction of an unobserved source omega.
const PROFILE:="sampled-source-pose-rotating-contact-v1"
const MAX_SEGMENTS:=128
const NOMINAL_SEGMENT_ANGLE:=0.02

static func rigid(basis:Basis)->bool:
	return basis.is_finite() and absf(basis.determinant()-1.0)<0.001 and absf(basis.x.length_squared()-1.0)<0.001 and absf(basis.y.length_squared()-1.0)<0.001 and absf(basis.z.length_squared()-1.0)<0.001 and absf(basis.x.dot(basis.y))<0.001 and absf(basis.x.dot(basis.z))<0.001 and absf(basis.y.dot(basis.z))<0.001

static func angular_displacement(first:Quaternion,last:Quaternion)->Vector3:
	if not first.is_finite() or not last.is_finite() or first.length_squared()<0.01 or last.length_squared()<0.01:return Vector3.ZERO
	var delta:Quaternion=(last.normalized()*first.normalized().inverse()).normalized()
	if delta.w<0:delta=Quaternion(-delta.x,-delta.y,-delta.z,-delta.w)
	var vector:=Vector3(delta.x,delta.y,delta.z)
	var sine:=vector.length()
	if sine<0.00000001:return Vector3.ZERO
	var angle:=2.0*atan2(sine,clampf(delta.w,0,1))
	return vector*(angle/sine)

static func sample(first:Basis,last:Basis,seconds:float)->Dictionary:
	if not rigid(first) or not rigid(last) or not is_finite(seconds) or seconds<0:return {}
	var displacement:=angular_displacement(first.get_rotation_quaternion(),last.get_rotation_quaternion()) if seconds>0 else Vector3.ZERO
	return {"profile":PROFILE,"sample_valid":seconds>0,"seconds":seconds,"displacement_world_rad":displacement,"angle_rad":displacement.length(),"angular_velocity_world_rad_s":displacement/seconds if seconds>0 else Vector3.ZERO}

static func surface_velocity(omega:Vector3,point:Vector3,center:Vector3)->Vector3:
	return omega.cross(point-center)

static func support_offset(radii:Vector3,rotation:Quaternion,direction:Vector3)->Vector3:
	if not radii.is_finite() or minf(radii.x,minf(radii.y,radii.z))<=0 or not rotation.is_finite() or rotation.length_squared()<0.01 or not direction.is_finite() or direction.length_squared()<0.00000001:return Vector3.ZERO
	var basis:=Basis(rotation.normalized());var local:=basis.transposed()*direction.normalized()
	var squared:=Vector3(radii.x*radii.x,radii.y*radii.y,radii.z*radii.z)
	var denominator:=sqrt(local.x*local.x*squared.x+local.y*local.y*squared.y+local.z*local.z*squared.z)
	return basis*(local*squared/denominator)

static func telemetry(basis:Basis,omega:Vector3,ship_position:Vector3,ship_velocity:Vector3,ship_attitude:Quaternion,ship_omega:Vector3,center:Vector3,sample_valid:bool)->Dictionary:
	if not rigid(basis) or not omega.is_finite() or not ship_omega.is_finite() or not ship_position.is_finite() or not ship_velocity.is_finite() or not ship_attitude.is_finite() or ship_attitude.length_squared()<0.01:return {}
	var ship_basis:=Basis(ship_attitude.normalized())
	var forward:Vector3=-basis.z
	var up:Vector3=ship_basis.y-forward*ship_basis.y.dot(forward)
	var roll_error:=0.0
	if up.length_squared()>0.000001:
		up=up.normalized();roll_error=atan2(forward.dot(up.cross(basis.y)),clampf(up.dot(basis.y),-1,1))
	var wall:=surface_velocity(omega,ship_position,center)
	return {"profile":PROFILE,"sample_valid":sample_valid,"roll_error_rad":roll_error,"heading_error_rad":acos(clampf((-ship_basis.z).dot(forward),-1,1)),"station_angular_velocity_world_rad_s":omega,"ship_angular_velocity_world_rad_s":ship_omega,"roll_rate_error_rad_s":(omega-ship_omega).dot(forward),"station_surface_velocity_mps":wall,"relative_linear_velocity_mps":basis.transposed()*(ship_velocity-wall),"angular_velocity_capture_threshold":false}

static func sweep(sweep_local:Callable,start:Vector3,finish:Vector3,ship_first:Quaternion,ship_last:Quaternion,station_first:Basis,station_last:Basis,center:Vector3,radii:Vector3)->Dictionary:
	if not sweep_local.is_valid() or not start.is_finite() or not finish.is_finite() or not center.is_finite() or not rigid(station_first) or not rigid(station_last) or not ship_first.is_finite() or not ship_last.is_finite() or ship_first.length_squared()<0.01 or ship_last.length_squared()<0.01 or not radii.is_finite() or minf(radii.x,minf(radii.y,radii.z))<=0:return {}
	var first_q:=station_first.get_rotation_quaternion();var last_q:=station_last.get_rotation_quaternion()
	var station_angle:=angular_displacement(first_q,last_q).length()
	var ship_angle:=angular_displacement(ship_first,ship_last).length()
	var count:=clampi(ceili((station_angle+ship_angle)/NOMINAL_SEGMENT_ANGLE),1,MAX_SEGMENTS)
	var minimum_radius:=minf(radii.x,minf(radii.y,radii.z));var maximum_radius:=maxf(radii.x,maxf(radii.y,radii.z))
	var full_motion:=finish-start
	for index in range(count):
		var begin:=float(index)/count;var end:=float(index+1)/count;var middle:=(begin+end)*0.5
		var begin_basis:=Basis(first_q.slerp(last_q,begin));var end_basis:=Basis(first_q.slerp(last_q,end));var middle_basis:=Basis(first_q.slerp(last_q,middle))
		var world_first:=start.lerp(finish,begin);var world_last:=start.lerp(finish,end)
		var local_first:=begin_basis.transposed()*(world_first-center);var local_last:=end_basis.transposed()*(world_last-center)
		var rotation:=ship_first.slerp(ship_last,middle).normalized()
		var angle:=station_angle/count;var relative_angle:float=(station_angle+ship_angle)/count
		var maximum_distance:=maxf((world_first-center).length(),(world_last-center).length())
		# For p(t)=B(t)^T*(linear(t)-center), the endpoint-chord deviation is
		# bounded by max|p''|/8. Changing ellipsoid orientation is bounded by
		# its maximum-radius point displacement from the midpoint orientation.
		var center_error:float=(angle*angle*maximum_distance+2.0*angle*full_motion.length()/count)/8.0
		var shape_error:=2.0*maximum_radius*sin(minf(PI,relative_angle)*0.25)
		# Uniform expansion encloses E + a Euclidean error ball: unlike simply
		# adding a pad to each radius, scale(E) >= E + ball at every support plane.
		var scale:=1.0+(center_error+shape_error)/minimum_radius
		var candidate:Variant=sweep_local.call(local_first,local_last,rotation,middle_basis,scale)
		if not candidate is Dictionary or candidate.is_empty():continue
		var segment_time:=clampf(float(candidate.get("time",0.0)),0,1)
		var hit_time:=lerpf(begin,end,segment_time)
		var hit_basis:=Basis(first_q.slerp(last_q,hit_time))
		candidate["time"]=hit_time;candidate["station_basis_at_hit"]=hit_basis
		candidate["world_position"]=center+hit_basis*candidate.position
		candidate["world_normal"]=(hit_basis*candidate.normal).normalized()
		candidate["segments"]=count;candidate["segment_index"]=index
		candidate["center_error_bound_m"]=center_error;candidate["shape_error_bound_m"]=shape_error
		candidate["ellipsoid_scale"]=scale;candidate["profile"]=PROFILE
		return candidate
	return {}
