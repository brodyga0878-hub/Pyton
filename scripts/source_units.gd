extends RefCounted
# Original HUD kilometre calibration, derived from F1100/F1109 and FF30/07.
# Canonical source geometry stays integer; convert only at the rendering boundary.
const METRES_PER_RAW:=16785.0/16777216.0
static func metres(raw:float)->float:return raw*METRES_PER_RAW
static func raw(metres_value:float)->float:return metres_value/METRES_PER_RAW
static func city_point(point:Array)->Vector3:
	# Original ground-model axes [north,up,east] -> surface [east,up,south].
	return Vector3(metres(float(point[2])),metres(float(point[1])),-metres(float(point[0])))
static func city_direction(vector:Variant)->Vector3:
	return Vector3(float(vector[2]),float(vector[1]),-float(vector[0])).normalized()
