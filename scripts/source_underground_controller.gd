extends RefCounted
# Surface-v4 bridge. Cache the immutable city and replay the actual model237
# subtree in its captured source frame; never invent a hatch collision shape.
const Hangar=preload("res://scripts/source_underground_port.gd")
const Compiler=preload("res://scripts/source_model_mesh.gd")
const City=preload("res://scripts/source_city_runtime.gd")
const Units=preload("res://scripts/source_units.gd")
const Clock=preload("res://scripts/source_clock.gd")
const REVISION:="source-enclosed-ground-controller-v1"
const TERRAIN_REVISION:="sphere-source-ground-v4"
const SUBTREE:="96/237@20"

class StaticCompiler:
	extends "res://scripts/source_model_mesh.gd"
	var captured_frame:Dictionary={}
	var insertion:Dictionary={}
	func _run_model(index:int,frame:Dictionary,depth:int)->void:
		if index==237 and str(frame.path)=="96/237@20":
			captured_frame=frame.duplicate(true)
			insertion={"triangles_raw":triangles.size(),"source_events":events.size(),"instances":instances.size()}
			return # The exact recorded subtree is replayed for each door pose.
		super._run_model(index,frame,depth)
class MovingCompiler:
	extends "res://scripts/source_model_mesh.gd"
	var captured_frame:Dictionary={}
	func _run_model(index:int,frame:Dictionary,depth:int)->void:
		if depth==0:frame=captured_frame.duplicate(true)
		super._run_model(index,frame,depth)

var profile:Dictionary={}
var data:Dictionary={}
var route:Dictionary={}
var state:Dictionary={}
var dirty:=false
var configured_ok:=false
var last_error:=""
var _static:Dictionary={}
var _frame:Dictionary={}
var _insertion:Dictionary={}
var _pending:Dictionary={}
var _generation:=0
var _fractional_tick:=0.0
var _pose_cache:Dictionary={}
var _pose_order:Array=[]
var _mutex:=Mutex.new()

func _globe_valid(globe:RefCounted)->bool:
	if globe==null or str(globe.get("revision"))!=TERRAIN_REVISION:return false
	for field in ["latitude","longitude","radius"]:
		var value:Variant=globe.get(field)
		if not (value is int or value is float) or not is_finite(float(value)):return false
	return absf(float(globe.latitude))<=PI/2 and float(globe.radius)>0
func _radii_valid(radii:Vector3)->bool:return radii.is_finite() and minf(radii.x,minf(radii.y,radii.z))>0
func _entity(door:int)->Array:
	var result:Array=[];result.resize(64);result.fill(0)
	result[1]=door;result[2]=int(profile.source_seed)&65535;result[3]=(int(profile.source_seed)>>16)&65535
	return result
func configure(site:Dictionary,globe:RefCounted,saved:Dictionary={},radii:=Vector3(10,4,12))->bool:
	last_error=""
	if not _globe_valid(globe) or int(site.get("model_index",-1))!=96 or not globe.get("city_profiles") is Dictionary:
		last_error="Closed ground hangars require source surface v4";return false
	var candidate_profile:Dictionary=globe.city_profiles.get(str(site.get("id","")),{})
	if not Hangar._profile_valid(candidate_profile) or str(candidate_profile.get("site_id",""))!=str(site.get("id","")) or candidate_profile.get("terrain_revision")!=TERRAIN_REVISION:
		last_error="Missing exact F879 closed-hangar anchor";return false
	var restored:Dictionary={};var fraction:=0.0
	if saved.is_empty():restored=Hangar.new_state(str(site.id))
	else:
		if saved.get("revision")!=REVISION or not saved.get("state") is Dictionary or not (saved.get("fractional_tick") is int or saved.get("fractional_tick") is float) or not is_finite(float(saved.fractional_tick)) or float(saved.fractional_tick)<0 or float(saved.fractional_tick)>=1:
			last_error="Invalid saved enclosed-hangar controller";return false
		restored=Hangar.restore(saved.state,str(site.id));fraction=float(saved.fractional_tick)
	if restored.is_empty():last_error="Incompatible enclosed-hangar save";return false
	# Construct an isolated controller before publishing any live field.
	var candidate:RefCounted=get_script().new()
	candidate.profile=candidate_profile.duplicate(true);candidate.route=Hangar.route(candidate.profile,radii)
	if candidate.route.is_empty() or not candidate.route.fits:last_error="Ship does not fit original enclosed hangar";return false
	var compiler:=StaticCompiler.new()
	var static_result:=compiler.compile(96,{"source_seed":int(candidate.profile.source_seed),"matrix_q31":candidate.profile.source_matrix_q31,"entity_variables_u16":candidate._entity(int(restored.door_u16))})
	if not static_result.get("ok",false) or compiler.captured_frame.is_empty():last_error=str(static_result.get("error","Missing actual model237 source frame"));return false
	candidate._static=static_result;candidate._frame=compiler.captured_frame;candidate._insertion=compiler.insertion
	var initial:Dictionary=candidate.prepare_pose(int(restored.door_u16))
	if not initial.get("ok",false):last_error=str(initial.get("error","Cannot prepare enclosed source geometry"));return false
	_mutex.lock()
	profile=candidate.profile;route=candidate.route;data=initial;state=restored
	_static=candidate._static;_frame=candidate._frame;_insertion=candidate._insertion
	_pose_cache=candidate._pose_cache;_pose_order=candidate._pose_order;_fractional_tick=fraction
	_pending={};dirty=false;configured_ok=true;_generation+=1
	_mutex.unlock()
	return true

func _combined(dynamic:Dictionary,door:int)->Dictionary:
	var result:=_static.duplicate()
	for key in ["triangles_raw","source_events","instances"]:
		var rows:Array=[];var at:=int(_insertion[key])
		rows.append_array(_static[key].slice(0,at));rows.append_array(dynamic[key]);rows.append_array(_static[key].slice(at))
		if key=="triangles_raw":
			# Source compiler deduplicates globally, not by model path. Restore
			# precisely the original visit order before applying that same key.
			var unique:Array=[];var seen:Dictionary={}
			for face in rows:
				var vertices:Array=[]
				for point in face.vertices:vertices.append(JSON.stringify(point))
				vertices.sort()
				var fingerprint:="%d:"%int(face.material_code)+JSON.stringify(face.material_base)+":".join(vertices)
				if not seen.has(fingerprint):seen[fingerprint]=true;unique.append(face)
			rows=unique
		result[key]=rows
	var minimum:Array=[];var maximum:Array=[]
	for face in result.triangles_raw:
		for point in face.vertices:
			if minimum.is_empty():minimum=point.duplicate();maximum=point.duplicate()
			for axis in range(3):minimum[axis]=mini(int(minimum[axis]),int(point[axis]));maximum[axis]=maxi(int(maximum[axis]),int(point[axis]))
	result.bounds_raw={"minimum":minimum,"maximum":maximum};result.triangle_count=result.triangles_raw.size();result.instance_count=result.instances.size()
	result.instruction_count=int(_static.instruction_count)+int(dynamic.instruction_count)
	return result

func prepare_pose(door_u16:Variant)->Dictionary:
	# Call outside the fixed-physics loop. This method publishes no live state.
	if not Hangar._u16(door_u16) or _static.is_empty():return {"ok":false,"error":"Invalid source hatch pose request"}
	var door:=int(door_u16)
	if _pose_cache.has(door):return _pose_cache[door]
	var compiler:=MovingCompiler.new();compiler.captured_frame=_frame
	var moving:=compiler.compile(237,{"source_seed":int(profile.source_seed),"entity_variables_u16":_entity(door)})
	if not moving.get("ok",false):return moving
	var compiled:=_combined(moving,door);var inverse:Basis=profile.root_basis.inverse()
	var triangles:Array=[];var hatch:Array=[];var footprint:=0.0
	for face in compiled.triangles_raw:
		var triangle:Array[Vector3]=[]
		for point in face.vertices:
			var local:=inverse*Vector3(Units.metres(point[0]),Units.metres(point[1]),Units.metres(point[2]))
			triangle.append(local);footprint=maxf(footprint,Vector2(local.x,local.z).length())
		triangles.append(triangle)
		if str(face.instance_path)==SUBTREE and int(face.offset)>=272 and int(face.offset)<=320:hatch.append(triangle)
	if footprint>=float(profile.flat_inner_m)-1:return {"ok":false,"error":"Source hangar footprint exceeds anchored terrain region"}
	var indexed:=City._index_triangles(triangles);var key:=Hangar._pose_key(profile,door)
	var placed:=profile.duplicate(true);placed.key=key
	var prepared:={"ok":true,"compiled":compiled,"conversion_basis":inverse,"triangles":triangles,"bounds":indexed.bounds,
		"footprint_m":footprint,"cells":indexed.cells,"large_triangles":indexed.large_triangles,"triangle_bounds":indexed.triangle_bounds,
		"cruise_height_m":maxf(350.0,indexed.bounds.end.y+100.0),"collision_profile":"modern-source-solid-triangles-v1","decorative_collision":false,
		"cache_key":key,"profile":placed,"door_u16":door,"hatch_triangles":hatch,"enclosed_hangar":true,"revision":Hangar.REVISION,
		"static_compiled":_static,"dynamic_compiled":moving,"static_key":Hangar._pose_key(profile,0)+":immutable-city","dynamic_subtree":SUBTREE}
	_pose_cache[door]=prepared;_pose_order.append(door)
	while _pose_order.size()>3:_pose_cache.erase(_pose_order.pop_front())
	return prepared

func frame(globe:RefCounted)->Transform3D:return City.transform_to_frame(profile,globe)
func root_position(globe:RefCounted,position:Vector3)->Vector3:
	if not configured_ok or not _globe_valid(globe) or not position.is_finite():return Vector3(INF,INF,INF)
	return frame(globe).affine_inverse()*position
func current_route(globe:RefCounted,radii:Vector3)->Dictionary:
	if not configured_ok or not _globe_valid(globe) or not _radii_valid(radii):return {}
	var plan:=Hangar.route(profile,City._root_radii(frame(globe).basis.inverse(),radii))
	if plan.is_empty():return {}
	var transform:=frame(globe)
	for key in ["outer_local_m","entrance_local_m","interior_local_m","hatch_center_local_m"]:plan[key]=transform*Vector3(plan[key])
	plan.up_local=(transform.basis*Vector3(plan.up_local)).normalized()
	return plan
func request(action:String)->bool:
	_mutex.lock()
	var result:=_request_locked(action)
	_mutex.unlock()
	return result
func _request_locked(action:String)->bool:
	if not configured_ok:return false
	var candidate:=Hangar.command(state,action)
	if candidate.is_empty():last_error="Invalid enclosed-hangar transition";return false
	state=candidate;_pending={};dirty=false;_generation+=1
	return true
func step_source(source_step:Variant,globe:RefCounted,position:Vector3,radii:Vector3,contact_ok:=false)->bool:
	_mutex.lock()
	var result:=_step_source_locked(source_step,globe,position,radii,contact_ok)
	_mutex.unlock()
	return result
func _step_source_locked(source_step:Variant,globe:RefCounted,position:Vector3,radii:Vector3,contact_ok:bool)->bool:
	if not configured_ok or not _pending.is_empty() or not Hangar._u32(source_step) or not _globe_valid(globe) or not position.is_finite() or not _radii_valid(radii):return false
	var transform:=frame(globe);var local:=transform.affine_inverse()*position
	var local_radii:=City._root_radii(transform.basis.inverse(),radii)
	var candidate:=Hangar.advance(state,source_step,profile,local,local_radii,contact_ok)
	if candidate.is_empty():last_error="Invalid source hatch update";return false
	if int(candidate.door_u16)==int(data.door_u16):state=candidate;return true
	_pending={"generation":_generation,"state":candidate};dirty=true
	return true
func step_seconds(dt:float,globe:RefCounted,position:Vector3,radii:Vector3,contact_ok:=false)->bool:
	if not is_finite(dt) or dt<=0 or dt>60:return false
	_mutex.lock()
	if not _pending.is_empty():_mutex.unlock();return false
	# Explicit real-time bridge: source calendar ticks, preserving fractional
	# tick remainder. This does not claim the original renderer's frame pacing.
	var ticks:=dt*float(Clock.TICKS_PER_DISPLAY_SECOND)+_fractional_tick
	var count:=floori(ticks)
	if not _step_source_locked(count,globe,position,radii,contact_ok):_mutex.unlock();return false
	_fractional_tick=ticks-count
	_mutex.unlock()
	return true

func capture_job()->Dictionary:
	# Only this bounded copy touches the live controller. The costly worker uses
	# immutable captured resources; request/configure may proceed concurrently.
	_mutex.lock()
	if _pending.is_empty():_mutex.unlock();return {}
	var door:=int(_pending.state.door_u16)
	var job:={"revision":REVISION,"controller_id":get_instance_id(),"generation":_pending.generation,"state":_pending.state.duplicate(true),
		"profile":profile.duplicate(true),"static":_static,"frame":_frame.duplicate(true),"insertion":_insertion.duplicate(true),
		"cached":_pose_cache.get(door,{})}
	_mutex.unlock()
	return job
static func prepare_job(job:Dictionary)->Dictionary:
	if job.is_empty():return {}
	if job.get("revision")!=REVISION or not job.get("profile") is Dictionary or not job.get("state") is Dictionary or not job.get("static") is Dictionary or not job.get("frame") is Dictionary or not job.get("insertion") is Dictionary:return {"ok":false,"error":"Invalid immutable source hangar job"}
	var worker:RefCounted=load("res://scripts/source_underground_controller.gd").new()
	worker.profile=job.profile;worker._static=job.static;worker._frame=job.frame;worker._insertion=job.insertion
	var prepared:Dictionary=job.get("cached",{})
	if prepared.is_empty():prepared=worker.prepare_pose(int(job.state.door_u16))
	if not prepared.get("ok",false):return prepared
	return {"ok":true,"controller_id":job.controller_id,"generation":job.generation,"state":job.state.duplicate(true),"data":prepared}
func prepare_pending()->Dictionary:return prepare_job(capture_job())
func publish_prepared(bundle:Dictionary,globe:RefCounted,position:Vector3,radii:Vector3)->bool:
	_mutex.lock()
	var result:=_publish_locked(bundle,globe,position,radii)
	_mutex.unlock()
	return result
func _publish_locked(bundle:Dictionary,globe:RefCounted,position:Vector3,radii:Vector3)->bool:
	if not _globe_valid(globe) or not position.is_finite() or not _radii_valid(radii) or _pending.is_empty() or not bundle.get("ok",false) or int(bundle.get("controller_id",-1))!=get_instance_id() or int(bundle.get("generation",-1))!=_generation or bundle.get("state")!=_pending.state or not bundle.get("data") is Dictionary or int(bundle.data.get("door_u16",-1))!=int(_pending.state.door_u16):return false
	# A worker may finish after the ship moved. Never publish a solid moving
	# door through its current hull; leave the old exact pose in use instead.
	if not City.sweep(bundle.data,globe,position,position,radii).is_empty():
		last_error="Hatch geometry update waits for hull clearance";_pending={};dirty=false;return false
	data=bundle.data;state=_pending.state;_pending={};dirty=false;_generation+=1
	var door:=int(data.door_u16)
	if not _pose_cache.has(door):_pose_cache[door]=data;_pose_order.append(door)
	while _pose_order.size()>3:_pose_cache.erase(_pose_order.pop_front())
	return true
func snapshot()->Dictionary:
	_mutex.lock()
	if not configured_ok or Hangar.snapshot(state).is_empty():_mutex.unlock();return {}
	# Pending geometry has never been published: persist the live paired pose.
	var result:={"revision":REVISION,"state":Hangar.snapshot(state),"fractional_tick":_fractional_tick}
	_mutex.unlock()
	return result
