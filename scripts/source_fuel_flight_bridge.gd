extends RefCounted
# Explicit conversion of the existing phone controller's actual powered
# impulse to F938's three signed source force words. It is not F995's complete
# original key/autopilot dispatcher. Source-motion steps use their own words.
const Profile=preload("res://scripts/source_ship_control_profile.gd")
const Hyperdrive=preload("res://scripts/source_hyperdrive.gd")
const CONTRACT:="phone-powered-impulse-to-f938-force-v1"

static func _signed16(value:int)->int:return (value&65535)-65536 if (value&65535)>=32768 else value&65535

static func cached_limits(ship_id:String)->Array:
	var resource:=Hyperdrive.resource();var profiles:Variant=resource.get("new_session_profiles",{})
	if not profiles is Dictionary or not profiles.get(ship_id) is Dictionary:return []
	var spec:=Hyperdrive.ship_spec(int(profiles[ship_id].get("source_model_index",-1)))
	if spec.size()!=24:return []
	var main:=int(spec.decode_s16(0));var retro:=int(spec.decode_s16(2))
	return [(-retro)&65535,retro&65535,(-retro)&65535,retro&65535,main&65535,retro&65535]

static func commands(ship:RefCounted,seconds:float)->Array:
	if ship==null or not is_finite(seconds) or seconds<=0 or not ship.last_propulsive_delta_v.is_finite():return []
	var limits:Array=ship.source_thrust_limits_u16 if ship.source_thrust_limits_u16.size()==6 else cached_limits(str(ship.ship_id))
	if limits.size()!=6:return []
	if not ship.propulsion_available:return [0,0,0]
	var calibration:=Profile._nominal_sample(1)
	var per_raw:=float(calibration.get("acceleration_mps2",0.0))
	if not is_finite(per_raw) or per_raw<=0:return []
	var local:Vector3=Basis(ship.attitude.normalized()).transposed()*(ship.last_propulsive_delta_v/seconds)
	var native:=Vector3(-local.x,local.y,-local.z);var result:Array=[]
	for axis in range(3):
		var raw:=roundi(float(native[axis])/per_raw)
		var index:=axis*2+(0 if raw>=0 else 1)
		var limit:=absi(_signed16(int(limits[index])))
		result.append(clampi(raw,-limit,limit))
	return result
