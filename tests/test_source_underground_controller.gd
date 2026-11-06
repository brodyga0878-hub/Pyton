extends SceneTree
const Controller=preload("res://scripts/source_underground_controller.gd")
const Hangar=preload("res://scripts/source_underground_port.gd")
const Compiler=preload("res://scripts/source_model_mesh.gd")
class Globe:
	extends RefCounted
	var revision:="sphere-source-ground-v4"
	var city_profiles:Dictionary={}
	var latitude:=0.0
	var longitude:=0.0
	var radius:=1737400.0
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(message)
func fixture_site(phase:int,inclination:int)->Dictionary:
	return {"id":"actual96-%d-%d"%[phase,inclination],"type_code":35,"model_index":96,"source_seed":0xd1d76465,"ground_phase_u16":phase,"ground_inclination_u16":inclination}
func same_source(actual:Dictionary,expected:Dictionary)->void:
	for key in ["triangles_raw","source_events","instances","bounds_raw","triangle_count","instruction_count","instance_count","initial_random_state_u32"]:
		check(var_to_bytes(actual.get(key))==var_to_bytes(expected.get(key)),"Captured-frame subtree replay equals complete original VM "+key)
func run()->void:
	var radii:=Vector3(10,4,12)
	for angles in [[26563,1585],[33966,3247],[0,16384]]:
		var site:=fixture_site(angles[0],angles[1]);var profile:=Hangar.describe(site,1737400.0)
		if angles[0]==0:
			site.source_seed=0xffffffff;profile=Hangar.describe(site,1737400.0)
		# Isolated frame-adapter fixture; actual F879 anchoring is verified in the
		# SourceSurfaceTerrain suite, not fabricated as a controller oracle.
		profile.terrain_revision=Controller.TERRAIN_REVISION
		var globe:=Globe.new();globe.latitude=profile.root_latitude;globe.longitude=profile.root_longitude;globe.city_profiles[str(site.id)]=profile
		var control:=Controller.new()
		check(control.configure(site,globe,{},radii),"Source-v4 controller prepares source96 closed anchor: "+control.last_error)
		if not control.configured_ok:continue
		for door in [65535,32768,0,16384]:
			var replay:=control.prepare_pose(door)
			var whole:=Compiler.new().compile(96,{"source_seed":int(site.source_seed),"matrix_q31":profile.source_matrix_q31,"entity_variables_u16":control._entity(door)})
			check(replay.get("ok",false) and whole.get("ok",false),"Both source execution paths complete for exact door word "+str(door))
			same_source(replay.compiled,whole)
			check(replay.static_compiled.triangle_count>10000 and replay.dynamic_compiled.triangle_count<1000,"Replay caches actual immutable city and executes only actual hangar subtree")
		var route:=control.current_route(globe,radii)
		check(route.get("fits",false),"Controller converts route to current rebased frame")
		var original_local:=control.root_position(globe,route.interior_local_m)
		globe.latitude-=0.00001
		var rebased:=control.current_route(globe,radii)
		check((control.root_position(globe,rebased.interior_local_m)-original_local).length()<0.001,"Route remains fixed to actual source hangar after tangent-frame rebase")
		globe.latitude=profile.root_latitude
		check(not control.step_seconds(-1,globe,route.entrance_local_m,radii) and control.current_route(null,radii).is_empty() and not control.step_source(1,globe,route.entrance_local_m,Vector3.ZERO),"Invalid source timing/frame/radii rejected before physics update")
		check(control.request("dock"),"Controller queues arrival")
		var old_pose:=var_to_bytes(control.data.compiled)
		check(control.step_source(131072,globe,route.entrance_local_m,radii) and control.dirty,"Source tick queues exact open geometry outside physics")
		check(control.state.phase=="opening" and control.data.door_u16==65535 and var_to_bytes(control.data.compiled)==old_pose,"State and collision retain paired old pose before publication")
		var saved:=control.snapshot();var pending:=control.prepare_pending()
		check(pending.get("ok",false) and pending.data.door_u16==0,"Prepared bundle contains original open pose")
		check(control.publish_prepared(pending,globe,route.entrance_local_m,radii) and control.state.phase=="approach" and control.data.door_u16==0,"Atomic publication enables corridor only with matching open collider")
		check(not control.publish_prepared(pending,globe,route.entrance_local_m,radii),"Stale prepared bundle cannot replace later state")
		var restored:=Controller.new()
		check(restored.configure(site,globe,JSON.parse_string(JSON.stringify(saved)),radii) and restored.state.phase=="opening" and restored.data.door_u16==65535,"Save during worker preparation restores published paired state")
		check(control.step_source(0,globe,route.interior_local_m,radii) and control.state.phase=="inside","Controller tracks physical passage through roof")
		check(control.step_source(0,globe,route.interior_local_m,radii,true) and control.state.phase=="docked","Physical floor contact enables dock state")
		check(control.step_source(131072,globe,route.interior_local_m,radii,true) and control.dirty,"Docked ship queues sealing pose")
		pending=control.prepare_pending()
		check(control.publish_prepared(pending,globe,route.interior_local_m,radii) and control.data.door_u16==65535,"Closed roof publishes safely above docked ship")
		check(control.request("launch") and control.step_source(131072,globe,route.interior_local_m,radii),"Saved closed dock has an explicit opening launch path")
		pending=control.prepare_pending()
		check(control.publish_prepared(pending,globe,route.interior_local_m,radii) and control.state.phase=="departing","Launch proceeds after open collision publication")
		check(control.step_source(0,globe,route.entrance_local_m,radii) and control.state.phase=="closing","Whole ship exiting roof triggers closing")
		check(control.step_source(131072,globe,route.entrance_local_m,radii),"Closing exact geometry prepared")
		pending=control.prepare_pending()
		check(not control.publish_prepared(pending,globe,route.hatch_center_local_m,radii) and control.data.door_u16==0,"Worker publication cannot close roof through ship that moved into aperture")
		check(control.step_source(131072,globe,route.entrance_local_m,radii),"Rejected worker geometry does not lock subsequent updates")
		pending=control.prepare_pending()
		check(control.publish_prepared(pending,globe,route.entrance_local_m,radii) and control.state.phase=="closed","Cleared roof resumes and completes close")
		var final:=control.snapshot();var fingerprint:=var_to_bytes(final)
		var old_revision:=globe.revision;globe.revision="sphere-source-cities-v3"
		check(not control.configure(site,globe,{},radii) and var_to_bytes(control.snapshot())==fingerprint,"Legacy surface cannot silently enable96 or destroy live controller")
		globe.revision=old_revision
		var corrupt:=final.duplicate(true);corrupt.fractional_tick=1.5
		check(not control.configure(site,globe,corrupt,radii) and var_to_bytes(control.snapshot())==fingerprint,"Corrupt save rejected atomically")
		if angles[0]==26563:
			check(control.request("dock") and control.step_source(65536,globe,route.entrance_local_m,radii),"Immutable worker job captures intermediate source pose")
			var job:=control.capture_job();var thread:=Thread.new()
			check(thread.start(Controller.prepare_job.bind(job))==OK,"Source subtree preparation runs on actual worker thread")
			check(control.configure(site,globe,final,radii) and control.request("dock") and control.step_source(65536,globe,route.entrance_local_m,radii),"Live controller reconfigures while immutable worker may still run")
			var stale:Dictionary=thread.wait_to_finish()
			check(stale.get("ok",false) and not control.publish_prepared(stale,globe,route.entrance_local_m,radii),"Worker from previous controller generation cannot replace same-word pending state")
			var fresh:=control.prepare_pending()
			check(control.publish_prepared(fresh,globe,route.entrance_local_m,radii),"Fresh generation publishes after stale worker rejection")
	print("Source underground controller: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
