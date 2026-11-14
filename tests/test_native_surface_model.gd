extends SceneTree
const NativeSurface=preload("res://scripts/native_surface_model.gd")
const OldSurface=preload("res://scripts/surface_model.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const World=preload("res://scripts/planetary_system.gd")
const Natural=preload("res://scripts/source_natural_contact.gd")
const Provider=preload("res://scripts/source_native_surface_provider.gd")
const Session=preload("res://scripts/source_natural_contact_session.gd")
const Trace=preload("res://scripts/source_terrain_query_trace.gd")
const REPORT:="res://build/current-test-reports/native-surface-model.json"
var checks:=0
var failures:=0
var evidence:Array=[]
var galaxy:=Galaxy.new()
var world:=World.new()
var original:=OldSurface.new()
var ship:=Flight.new()
var surface:=NativeSurface.new()
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func fixture()->bool:
	if not galaxy.configure_native():return false
	world.configure(galaxy.get_system(World.SOL_ID),World.FULL_LAYOUT);world.focus_id="earth";world.site_id=""
	var globe:=Terrain.new();globe.configure(world,"earth","");globe.latitude=0;globe.longitude=0
	original.active=true;original.body_id="earth";original.globe=globe;original.kind="earth"
	ship.position=Vector3(10,200,30);ship.velocity=Vector3.ZERO;ship.attitude=Quaternion.IDENTITY
	var before:=var_to_bytes([world.body_spin_by_id,original.globe.capture_worker_state(),original.snapshot()])
	var ok:=surface.initialize_from(original,ship,world,0.0)
	check(before==var_to_bytes([world.body_spin_by_id,original.globe.capture_worker_state(),original.snapshot()]),"New trial does not move/mutate old terrain, source World spin or original surface session")
	return ok
func interval(target:RefCounted,pilot:RefCounted,receipt:int=1,lift:float=0.0)->Dictionary:
	return target.stage_manual(pilot,1.0/60.0,Vector2.ZERO,0.0,lift,65535,{"test_interval":receipt})
func clone_ship(source:RefCounted)->RefCounted:
	var copy:=Flight.new();check(copy.restore(source.snapshot()),"Independent flight clone restores legacy data")
	# The transaction host preserves exact runtime phone values, not only JSON.
	copy.position=source.position;copy.velocity=source.velocity;copy.attitude=source.attitude;copy.surface_mode=true;copy.station_available=false
	copy.propulsion_available=source.propulsion_available;copy.source_thrust_limits_u16=source.source_thrust_limits_u16.duplicate();copy.assisted=source.assisted
	return copy
func reseal(state:Dictionary)->Dictionary:
	var copy:=state.duplicate(true);copy.erase("snapshot_sha256");copy.snapshot_sha256=Session._hash(copy);return copy
func reject_cold(state:Dictionary,label:String)->void:
	var copy:=Flight.new();check(copy.restore(JSON.parse_string(JSON.stringify(ship.snapshot()))),"Invalid-witness control begins with an actual independent legacy flight decode")
	var before:=var_to_bytes([copy.snapshot(),world.body_spin_by_id])
	check(not NativeSurface.new().restore(reseal(state),copy,world),label)
	check(before==var_to_bytes([copy.snapshot(),world.body_spin_by_id]),"Rejected coherent witness does not change candidate phone pose or World spin")
func post_provider(body:PackedByteArray,binding:Dictionary,phase:String="post_response_render_only")->Dictionary:
	var classifier:=Natural.new();var trace:=Trace.new();classifier.set("_query",trace)
	var parent:PackedByteArray=surface.native_session.raw_parent();var relative:=Session._relative(body)
	var classified:=classifier.classify_natural_player(body,parent,relative,{"graphics_level":1,"initial_globals":Session.caller_globals(surface.native_session.globals())})
	return Provider.stage_from_classification(body,parent,relative,classified,trace.read_trace(),surface.get("_native_phone_frame"),binding,phase)
func initial_and_nohit()->void:
	check(surface.is_native_landing_trial() and not surface.uses_source_contact(),"Explicit new trial cannot enter the legacy Main collision bridge")
	check(absf(surface.altitude(ship)-50.0)<0.01,"Entry clearance is fifty metres above literal signed-native-root render triangle")
	check(surface.native_provider.render_payload().render_only_root,"Initial geometry is labelled render-only signed source root")
	var before:=var_to_bytes([surface.snapshot(),ship.snapshot(),world.body_spin_by_id])
	var candidate_ship:=clone_ship(ship);var candidate:=surface.fork_runtime(candidate_ship)
	candidate_ship.propulsion_available=false;candidate_ship.assisted=false;candidate_ship.target_speed=41.25
	var staged:=interval(candidate,candidate_ship)
	check(staged.get("ok",false),"Every airborne manual interval stages real original classifier and own render leaves: "+str(staged.get("reason")))
	check(before==var_to_bytes([surface.snapshot(),ship.snapshot(),world.body_spin_by_id]),"Prepared candidate preserves published source history, flight and World spin cache")
	if not staged.get("ok",false):return
	check(not staged.contact_detected and int(staged.source_prepared.classification.terrain_query_calls)>0,"F576 no-hit is an actual traced ordered source query walk")
	var controls:=[candidate_ship.target_speed,candidate_ship.assisted,candidate_ship.position,candidate_ship.attitude]
	check(candidate.finish_native_step(candidate_ship,staged,false,{}),"No-hit commits exact caller history without fabricated response")
	check(candidate_ship.target_speed==controls[0] and candidate_ship.assisted==controls[1] and candidate_ship.position==controls[2] and candidate_ship.attitude==controls[3],"No-hit acknowledgment preserves target speed, assistance and integrated phone pose")
	check(candidate.native_session.generation()==surface.native_session.generation()+1,"Exactly one physical contact session generation advances per airborne interval")
	check(candidate.acknowledge_post_interval(candidate_ship),"Post-interval acknowledgment validates actual phone pose")
	check(before==var_to_bytes([surface.snapshot(),ship.snapshot(),world.body_spin_by_id]),"Candidate commit still preserves published original models")
	surface=candidate;ship=candidate_ship
	evidence.append({"case":"airborne_nohit","terrain_queries":int(staged.source_prepared.classification.terrain_query_calls),"provider_phase":candidate.native_provider.render_payload().render_phase,"source_generation":candidate.native_session.generation()})
func cold_restore()->void:
	var snapshot:=surface.snapshot();var flight_snapshot:Dictionary=JSON.parse_string(JSON.stringify(ship.snapshot()))
	var restored_ship:=Flight.new();check(restored_ship.restore(flight_snapshot),"Legacy flight envelope JSON round-trips before native restore")
	var before_world:=var_to_bytes(world.body_spin_by_id)
	var restored:=NativeSurface.new();check(restored.restore(JSON.parse_string(JSON.stringify(snapshot)),restored_ship,world),"Cold restore rebuilds source provider witness and exact phone chart without an AGL floor condition")
	check(before_world==var_to_bytes(world.body_spin_by_id),"Cold restore gravity sampling does not advance live source World spin")
	if not restored.active:return
	check(restored.snapshot()==snapshot,"All source history, geometry witness, exact source days and Float32 phone pose survive cold restore")
	check(NativeSurface._native_pose(restored_ship.position,restored_ship.velocity,restored_ship.attitude)==snapshot.phone_pose_f32_hex,"Cold restore reinstalls exact phone pose bits after legacy JSON quaternion normalization")
	var bad:=snapshot.duplicate(true);bad.chart.radius_f64_hex=NativeSurface._native_floats([float(surface.globe.radius)+1],8)
	check(not NativeSurface.new().restore(bad,restored_ship,world),"Changed source chart radius rejects")
	bad=snapshot.duplicate(true);bad.source_record_hex="00".repeat(68)
	check(not NativeSurface.new().restore(bad,restored_ship,world),"Changed source record rejects")
	bad=snapshot.duplicate(true);bad.provider.snapshot_sha256="00".repeat(32)
	check(not NativeSurface.new().restore(bad,restored_ship,world),"Changed provider witness seal rejects")
	bad=snapshot.duplicate(true);bad.phone_pose_f32_hex=NativeSurface._native_pose(ship.position+Vector3.UP,ship.velocity,ship.attitude)
	check(not NativeSurface.new().restore(bad,restored_ship,world),"Changed exact pose cannot hide behind unchanged legacy flight anchor")
	bad=snapshot.duplicate(true);bad.extra=true
	check(not NativeSurface.new().restore(bad,restored_ship,world),"Unknown native surface schema fields reject")
	# Each substituted provider below is a valid independently rebuilt source
	# witness with a valid outer surface seal. These exercise cross-object
	# coupling, rather than only corrupting an integrity digest.
	if surface.native_session.generation()>0:
		var payload:Dictionary=surface.native_provider.render_payload();var binding:Dictionary=payload.request_binding.duplicate(true)
		var moved:PackedByteArray=surface.native_session.raw_body();moved.encode_s64(0x3e,moved.decode_s64(0x3e)+32)
		for phase:String in ["session_f576_stage","post_response_render_only","airborne_render_only"]:
			var stale:=post_provider(moved,binding,phase)
			check(stale.get("ok",false),"A displaced raw body generates a genuine, internally valid source geometry witness: "+phase)
			if not stale.get("ok",false):continue
			check(Provider.verify_snapshot(stale.provider.snapshot()).ok,"Stale geometry is intrinsically valid before coupling it to a different session pose")
			bad=snapshot.duplicate(true);bad.provider=stale.provider.snapshot();reject_cold(bad,"A valid "+phase+" provider from a different raw source pose cannot replace the current body witness")
			bad.provider_retained_render_only=true;reject_cold(bad,"Retained-provider flag cannot bypass a current source terrain query and pose mismatch")
		var wrong_binding:=binding.duplicate(true);wrong_binding.request_token="1".repeat(64);wrong_binding.request_sha256="1".repeat(64)
		var wrong:=post_provider(surface.native_session.raw_body(),wrong_binding)
		check(wrong.get("ok",false),"Different receipt still yields an internally valid current-pose render-only witness")
		if wrong.get("ok",false):bad=snapshot.duplicate(true);bad.provider=wrong.provider.snapshot();reject_cold(bad,"Current geometry with a different request token cannot attach to the committed contact session")
		wrong_binding=binding.duplicate(true);wrong_binding.generation=int(binding.generation)+1
		wrong=post_provider(surface.native_session.raw_body(),wrong_binding)
		check(wrong.get("ok",false),"Different generation still yields an internally valid current-pose render-only witness")
		if wrong.get("ok",false):bad=snapshot.duplicate(true);bad.provider=wrong.provider.snapshot();reject_cold(bad,"Current geometry with a different generation cannot attach to the committed contact session")
func flown_park_and_release()->void:
	# Fly the actual fifty-metre entry under source gravity, rather than moving
	# a fixture to an assumed mesh contact plane or manufacturing a hit kind.
	ship.target_speed=0;ship.assisted=false;ship.propulsion_available=true;ship.attitude=Quaternion(Vector3.FORWARD,0.16)
	var steps:=0;var contact:Dictionary={};var stopped:=""
	for index in range(600):
		var candidate_ship:=clone_ship(ship);var candidate:=surface.fork_runtime(candidate_ship)
		var staged:=interval(candidate,candidate_ship,index+10)
		if not staged.get("ok",false):stopped=str(staged.get("reason"));break
		var park:=bool(staged.landing_accepted)
		if not candidate.finish_native_step(candidate_ship,staged,park,{}):stopped="source_commit_or_park_rejected";break
		surface=candidate;ship=candidate_ship;steps+=1
		if staged.contact_detected:contact=staged;break
	check(not contact.is_empty(),"Actual integrated source-gravity flight reaches a genuine source contact without AGL-triggered collision: "+stopped)
	if contact.is_empty():return
	check(contact.landing_accepted and surface.landed and surface.native_session.phase()=="parked","Source speed/gear/alignment accepts the actual flown contact and host park")
	check(contact.damage_calls.is_empty() and surface.native_provider.render_payload().render_phase=="post_response_render_only","Accepted park causes no invented damage and publishes fresh post-response render-only source geometry")
	var parked_pose:=NativeSurface._native_pose(ship.position,ship.velocity,ship.attitude)
	var raw_park:PackedByteArray=surface.native_session.raw_body();var history:Dictionary=surface.native_session.globals();var generation:int=surface.native_session.generation()
	var agl:=surface.altitude(ship)
	for index in range(8):
		var idle:=interval(surface,ship,index+1000)
		check(idle.ok and idle.parked_idle and idle.damage_calls.is_empty() and surface.finish_native_step(ship,idle,true,{}),"Parked interval skips original contact scheduler and preserves accepted source witness")
	check(parked_pose==NativeSurface._native_pose(ship.position,ship.velocity,ship.attitude) and raw_park==surface.native_session.raw_body() and history==surface.native_session.globals() and generation==surface.native_session.generation(),"Park remains at exact source accepted anchor under repeated gravity ticks without AGL snap")
	check(absf(surface.altitude(ship)-agl)<0.000001,"Higher-than-mesh accepted park keeps its actual clearance")
	check(agl>1.0,"A real tilted-child source park lies more than one metre above the rendered mesh, exercising the legacy restore rejection boundary")
	cold_restore()
	ship.propulsion_available=false
	check(not surface.take_off(ship) and parked_pose==NativeSurface._native_pose(ship.position,ship.velocity,ship.attitude),"No fuel cannot release source park or teleport phone pose")
	ship.propulsion_available=true;ship.source_thrust_limits_u16=[0,0,0,0,0,0]
	check(not surface.take_off(ship) and surface.native_session.phase()=="parked","Disabled lift nozzle cannot release source park")
	ship.source_thrust_limits_u16=[]
	check(surface.take_off(ship) and parked_pose==NativeSurface._native_pose(ship.position,ship.velocity,ship.attitude) and raw_park==surface.native_session.raw_body(),"Positive powered launch request queues intent without changing source or phone pose")
	var old_session:Dictionary=surface.native_session.snapshot();var candidate_ship:=clone_ship(ship);var candidate:=surface.fork_runtime(candidate_ship)
	var launch:=interval(candidate,candidate_ship,2000)
	check(launch.get("ok",false) and not launch.get("parked_idle",true),"Candidate launch releases park only within a valid powered movement interval: "+str(launch.get("reason")))
	check(surface.native_session.snapshot()==old_session and parked_pose==NativeSurface._native_pose(ship.position,ship.velocity,ship.attitude),"Prepared launch leaves the published parked trial unchanged")
	if launch.get("ok",false):
		check(candidate_ship.position.distance_to(ship.position)<0.01 and candidate_ship.attitude==ship.attitude and candidate_ship.last_propulsive_delta_v.dot(Vector3.UP)>0,"Powered integration uses actual impulse without a 0.3 metre teleport or orientation reset")
		check(candidate.finish_native_step(candidate_ship,launch,false,{}),"Powered launch commits exact source nohit/contact continuation")
		check(not candidate.landed and candidate.native_session.phase()=="free","Accepted powered launch leaves source park while retaining source history")
	evidence.append({"case":"actual_flown_source_park","integrated_steps":steps,"parked_agl_m":agl,"source_generation":generation,"source_native_park_witness":true,"physical_device_tested":false})
func bounded_guards()->void:
	var copy_ship:=clone_ship(ship);var copy:=surface.fork_runtime(copy_ship)
	var state:Dictionary=copy.native_session.snapshot();var pose:Vector3=copy_ship.position
	copy.step(1.0/60.0,copy_ship,Vector2.ZERO,0.0)
	check(copy.native_session.snapshot()==state and copy_ship.position==pose,"Legacy Surface.step cannot integrate or collide this trial")
	check(not copy.begin_landing(copy_ship) and not copy.touch_down(copy_ship) and not copy.begin_ascent(copy_ship),"Unported autoland/touchdown/orbit actions cannot invoke legacy floor code")
	check(is_nan(copy.height_at(1e9,1e9)),"Missing emitted-leaf coverage returns unavailable rather than a legacy height fallback")
	var before:=var_to_bytes([surface.snapshot(),world.body_spin_by_id])
	copy_ship.position.x=1e8
	var staged:=interval(copy,copy_ship,2)
	check(not staged.get("ok",false),"Leaving bounded source geometry rejects the candidate interval")
	check(before==var_to_bytes([surface.snapshot(),world.body_spin_by_id]),"Rejected outside-chart candidate preserves published session and World cache")
	check(not surface.take_off(ship),"An airborne ship cannot acquire parked launch intent")
func run()->void:
	check(fixture(),"Actual original Earth data create a separate native landing trial: "+surface.native_last_reason)
	if surface.active:
		initial_and_nohit();cold_restore();bounded_guards();flown_park_and_release()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual source Earth, real original F576/F575 session and literal Float32 geometry provider; no physical Android/device or full original object bank claim."},"\t"));file.close()
	print("native_surface_model: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
