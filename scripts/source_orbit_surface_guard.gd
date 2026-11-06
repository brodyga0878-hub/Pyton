extends RefCounted
# Mobile orbit safety policy sampled against the same v4 source-height field.
# It does not restore original F575 player collision response or damage.
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const LAYOUT:="source_jjffe_systems_v4"
const CONTRACT:="source-height-orbit-clearance-v1"
const CACHE_LIMIT:=4
const CLEARANCE_METRES:=2000.0
const SEPARATION_METRES:=50.0
var _samplers:Dictionary={}
var _lru:Array[String]=[]
var _hits:=0
var _misses:=0

func clear_cache()->void:
	_samplers.clear();_lru.clear();_hits=0;_misses=0

func cache_stats()->Dictionary:
	var samples:=0
	for sampler:RefCounted in _samplers.values():samples+=int(sampler.cache_stats().source_samples)
	return {"samplers":_samplers.size(),"limit":CACHE_LIMIT,"hits":_hits,"misses":_misses,"source_samples":samples,"contract":CONTRACT}

func _sampler(world:RefCounted,body_id:String)->RefCounted:
	var body:Dictionary=world.by_id[body_id]
	var site:Dictionary=world.current_site()
	var anchor:=str(site.get("id","")) if int(site.get("type_code",-1))==35 and str(site.get("parent",""))==body_id else ""
	var key:=var_to_bytes([str(world.layout_mode),int(world.system_id),str(world.source_digest),body_id,str(body.get("runtime_record_hex","")),anchor]).hex_encode().sha256_text()
	if _samplers.has(key):
		_hits+=1;_lru.erase(key);_lru.append(key);return _samplers[key]
	var candidate:=Terrain.new();candidate.configure(world,body_id,anchor)
	if not candidate.configured_ok:return null
	_misses+=1;_samplers[key]=candidate;_lru.append(key)
	while _lru.size()>CACHE_LIMIT:_samplers.erase(_lru.pop_front())
	return candidate

func probe(world:RefCounted,ship:RefCounted,days:float)->Dictionary:
	if str(world.layout_mode)!=LAYOUT or not is_finite(days) or days<0.0 or days>1e9 or ship.surface_mode or ship.docked or not ship.position.is_finite():return {}
	var body_id:=str(world.focus_id)
	if not world.by_id.has(body_id):return {}
	var body:Dictionary=world.by_id[body_id]
	if not body.get("landable",false) or str(body.get("kind","")) in ["star","barycenter","gas","ice_gas"]:return {}
	var center:Vector3=world.local_meters(body_id,days)
	var offset:Vector3=ship.position-center
	if not center.is_finite() or not offset.is_finite():return {}
	var distance:=sqrt(float(offset.x)*offset.x+float(offset.y)*offset.y+float(offset.z)*offset.z)
	var direction:=offset.normalized() if distance>0.1 else Vector3.UP
	# The original descriptor is an outer envelope, not a surface radius.
	# Model117 additionally has an explicit larger corrected reference sphere.
	var envelope:=maxf(float(body.get("source_outer_bound_m",0.0)),float(body.get("radius_km",0.0))*1000.0)
	if distance>=envelope+CLEARANCE_METRES:
		return {"ok":true,"coarse_only":true,"outside_envelope":true,"minimum_altitude_m":distance-envelope,"contract":CONTRACT}
	var sampler:=_sampler(world,body_id)
	if sampler==null:return {}
	var rotation:Basis=world.body_rotation_basis(body_id,days)
	var body_direction:Vector3=rotation.inverse()*direction
	if not body_direction.is_finite() or body_direction.length_squared()<0.5:return {}
	var latitude:=atan2(float(body_direction.y),sqrt(float(body_direction.x)*body_direction.x+float(body_direction.z)*body_direction.z))
	var longitude:=atan2(-float(body_direction.z),float(body_direction.x))
	var elevation:float=sampler.elevation(latitude,longitude)
	var source_radius:=float(sampler.radius)+elevation
	if not is_finite(source_radius) or source_radius<=0.0:return {}
	return {"ok":true,"coarse_only":false,"outside_envelope":false,"body_id":body_id,"center":center,"direction":direction,"body_direction":body_direction,"latitude":latitude,"longitude":longitude,"distance_m":distance,"terrain_radius_m":source_radius,"elevation_m":elevation,"altitude_m":distance-source_radius,"contract":CONTRACT,"terrain_revision":Terrain.REVISION_NAME}

func protect(world:RefCounted,ship:RefCounted,days:float)->bool:
	var sampled:=probe(world,ship,days)
	if sampled.is_empty() or sampled.get("coarse_only",true) or float(sampled.altitude_m)>=CLEARANCE_METRES:return false
	if not is_finite(float(ship.hull)):return false
	var direction:Vector3=sampled.direction
	ship.position=Vector3(sampled.center)+direction*(float(sampled.terrain_radius_m)+CLEARANCE_METRES+SEPARATION_METRES)
	ship.velocity=direction*10.0;ship.target_speed=0;ship.autopilot=false;ship.hull=maxf(0.0,float(ship.hull)-10.0)
	world.message="Опасное сближение с поверхностью. Для посадки используйте «К поверхности»."
	return true
