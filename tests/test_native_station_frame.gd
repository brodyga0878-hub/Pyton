extends "res://tests/test_native_orbit_trial.gd"
const StationFrame=preload("res://scripts/native_station_frame.gd")
const FRAME_REPORT:="res://build/current-test-reports/native-station-frame.json"
var station_frame_evidence:Array=[]

func frame_world_facts(world:RefCounted)->PackedByteArray:
	return var_to_bytes([world.snapshot(),world.native_evaluation_count,world._native_cache_tick,world._native_cache_day,world._native_positions_raw,world._native_relative_raw,world.body_spin_by_id,world.station_state_by_site])
func station_world(body:RefCounted,id:String="site13")->RefCounted:
	var result:=OrbitTrial._fork_world(body);result.site_id=id;return result
func local64(point:Vector3)->PackedFloat64Array:return PackedFloat64Array([point.x,point.y,point.z])
func vec(values:PackedFloat64Array)->Vector3:return Vector3(values[0],values[1],values[2])

func cache_isolation_and_bound(world:RefCounted)->void:
	var record:PackedByteArray=StationFrame._record(world.by_id.earth)
	var clock:=StationFrame.Clock.from_elapsed_days(0.123)
	var expected:PackedInt64Array=StationFrame.Ephemeris.evaluate_from_epoch(record,int(clock.tick_u32),int(clock.day_u32),StationFrame.Clock.EPOCH_TICK_U32,StationFrame.Clock.EPOCH_DAY_U32).position_raw
	var first:=StationFrame._relative(record,clock);first[0]+=123456789
	var second:=StationFrame._relative(record,clock)
	check(second==expected and second!=first,"Mutating a returned source-position buffer cannot poison a later memoized frame mapping")
	for index in range(StationFrame.RELATIVE_CACHE_LIMIT+3):
		var sampled:=StationFrame._relative(record,StationFrame.Clock.from_elapsed_days(0.25+float(index)/86400.0))
		if sampled.size()!=3:check(false,"Every independent cache-bound sample is a real original source orbit point");return
	check(StationFrame._relative_cache.size()<=StationFrame.RELATIVE_CACHE_LIMIT and StationFrame._relative_cache_order.size()==StationFrame._relative_cache.size(),"Pure ephemeris memo remains bounded after more unique record/clock inputs than its capacity")
	check(StationFrame._relative(record,clock)==expected,"Eviction and later recomputation preserve the exact source position")

func explicit_near_station_fixture(flown:Dictionary)->Dictionary:
	# This is deliberately NOT a claim that the35Mm transit has been flown.
	# The preceding real orbit interval makes the saved lineage non-generation0;
	# then this labelled fixture places a bound body-frame ship near the real site.
	var step:Dictionary=flown.orbit.prepare(flown.ship,flown.nav,flown.gear,flown.world,0.1)
	check(step.get("ok",false),"A real orbital interval precedes the explicitly labelled near-station placement")
	if not step.get("ok",false):return {}
	var row:=cold(apply_orbit(step));var target:=station_world(row.world)
	var point:=Ship.STATION+Vector3(13,8,8000);var relative_velocity:=Vector3(2,1,-3)
	var mapped:=StationFrame.map_between(target,row.world,local64(point),relative_velocity,row.nav.elapsed_days)
	check(mapped.get("ok",false),"The labelled near-station fixture is translated from the actual same-parent station frame")
	if not mapped.get("ok",false):return {}
	row.ship.position=vec(mapped.position_f64);row.ship.velocity=vec(mapped.velocity_f64)
	row.ship.attitude=target.source_station_basis(row.nav.elapsed_days).get_rotation_quaternion().normalized()
	row.orbit._position_f64=mapped.position_f64.duplicate();row.orbit._bind(row.ship,row.nav,row.world,row.gear)
	check(row.orbit._generation>0 and row.orbit._matches(row.ship,row.nav,row.world,row.gear),"Fixture remains an explicitly bound current orbital owner, not an invented generation-zero handoff")
	row=cold(row)
	return row

func reject_far_and_parent(flown:Dictionary)->void:
	var before:=orbit_owners(flown)
	var far:=StationFrame.prepare(flown.orbit,flown.ship,flown.nav,flown.gear,flown.world,"site13")
	check(not far.ok and far.reason=="station_is_not_within_100km_manual_approach","A genuinely flown20km Earth departure does not teleport to its distant real orbital station")
	var elsewhere:=StationFrame.prepare(flown.orbit,flown.ship,flown.nav,flown.gear,flown.world,"site3")
	check(not elsewhere.ok and elsewhere.reason=="unsupported_or_nonlocal_orbital_station","Mercury's real site3 cannot become an Earth-frame station by selecting its identifier")
	check(not StationFrame.prepare(flown.orbit,flown.ship,flown.nav,flown.gear,flown.world,"unknown").ok,"An unknown station does not create a source port")
	check(orbit_owners(flown)==before,"Far, mismatched-parent and unknown-station refusals preserve every live owner and cache")
	station_frame_evidence.append({"case":"genuine20km_departure_rejects_distant_station","site":"site13","reason":far.reason,"no_flown35Mm_transit_claim":true})

func pure_mapping(row:Dictionary)->void:
	var target:=station_world(row.world);var before_body:=frame_world_facts(row.world);var before_station:=frame_world_facts(target)
	for days:float in [0.0,row.nav.elapsed_days,1.0,1000000000.0]:
		var mapped:=StationFrame.map_between(row.world,target,row.orbit._position_f64,row.ship.velocity,days)
		check(mapped.get("ok",false),"Original ephemeris moving-origin mapping supports epoch/interior/day-crossing/end clocks")
		if not mapped.get("ok",false):continue
		var clock:=StationFrame.Clock.from_elapsed_days(days)
		var exact_old:=StationFrame._raw_origin(row.world,clock);var exact_new:=StationFrame._raw_origin(target,clock)
		var original_old:=OrbitTrial._fork_world(row.world);var original_new:=OrbitTrial._fork_world(target)
		check(exact_old==original_old._full_origin_raw(days) and exact_new==original_new._full_origin_raw(days),"Readonly raw origins equal actual World source-origin rules before any floating-point conversion")
		var reverse:=StationFrame.map_between(target,row.world,mapped.position_f64,vec(mapped.velocity_f64),days)
		check(reverse.get("ok",false),"The same sampled moving-origin policy has a real inverse")
		if not reverse.get("ok",false):continue
		for axis in range(3):
			check(absf(float(reverse.position_f64[axis])-float(row.orbit._position_f64[axis]))<0.0000001,"F64 position roundtrip retains the existing residual on axis"+str(axis))
		check(vec(reverse.velocity_f64).distance_to(row.ship.velocity)<0.001,"Canonical body velocity roundtrip retains only the declared finalFloat32 velocity rounding")
		var offset:=StationFrame.offset(row.world,target,days)
		check(vec(offset.velocity_delta_f64).length()>2000 and vec(offset.velocity_delta_f64).length()<4000,"Earth station origin motion is actually measured near3km/s rather than silently retaining numeric velocity")
		check(not mapped.receipt.axes_rotated and not mapped.receipt.omega_cross_radius_added and not mapped.receipt.full_original_object_bank,"Mapping names non-rotating translation and finite-difference host policy without claiming original F570/F606")
	check(frame_world_facts(row.world)==before_body and frame_world_facts(target)==before_station,"All readonly clock samples preserve both original World caches, source spin and station state")
	check(StationFrame._difference(PackedInt64Array([StationFrame.MAX_INT,0,0]),PackedInt64Array([-1,0,0])).is_empty(),"Signed64 origin-difference overflow rejects before conversion or wrapping")
	var bad:=station_world(row.world);bad.source_digest="unrelated-source"
	check(not StationFrame.map_between(row.world,bad,row.orbit._position_f64,row.ship.velocity,row.nav.elapsed_days).ok,"A different source definition cannot supply a silently substituted frame")
	check(not StationFrame.offset(row.world,target,NAN).ok and not StationFrame.offset(row.world,target,-1).ok,"Invalid ephemeris clock samples reject without changed state")

func actual_station_boundary(row:Dictionary)->void:
	var before:=orbit_owners(row);var day:float=row.nav.elapsed_days;var hp:Dictionary=row.nav.thermal_state(row.ship);var fuel:Dictionary=row.nav.fuel_state(row.ship);var gear:Dictionary=row.gear.snapshot()
	var prepared:=StationFrame.prepare(row.orbit,row.ship,row.nav,row.gear,row.world,"site13")
	check(prepared.get("ok",false),"A genuinely bound orbital owner near its same-parent real station prepares a zero-time handoff: "+str(prepared.get("reason","")))
	check(orbit_owners(row)==before,"Successful preparation changes neither the original body frame nor any raw/live owner or ephemeris cache")
	if not prepared.get("ok",false):return
	var ship:RefCounted=prepared.candidate_ship;var nav:RefCounted=prepared.candidate_nav;var world:RefCounted=prepared.candidate_world
	check(world.site_id=="site13" and world.focus_id=="earth" and world.is_orbital_site() and ship.has_source_station() and ship.station_available,"The actual compiled source station context is established without changing the parent body")
	check(not prepared.candidate_surface.active and not ship.surface_mode and not ship.docked and not ship.autopilot,"Handoff does not fabricate a dock, surface, autopilot, or completed flight")
	check(nav.elapsed_days==day and nav.thermal_state(ship)==hp and nav.fuel_state(ship)==fuel and prepared.candidate_gear.snapshot()==gear,"The source clock, raw HP/RNG/fuel and physical gear remain exact across the coordinate boundary")
	check(ship.attitude==row.ship.attitude and ship.assisted==row.ship.assisted and ship.target_speed==row.ship.target_speed and ship.source_motion_profile==row.ship.source_motion_profile,"Orientation, existing control intent and actual thrust profile are preserved")
	check(ship.position.distance_to(Ship.STATION+Vector3(13,8,8000))<0.002 and ship.velocity.distance_to(Vector3(2,1,-3))<0.001,"Origin translation and actual3km/s velocity offset recover the labelled nearby station-frame pose")
	check(OrbitTrial._pose(ship)==prepared.receipt.station_pose_f32_hex and prepared.receipt.ideal_position_f64_hex==NativeSurface._native_floats(Array(prepared.candidate_position_f64),8),"Boundary receipt seals exact F64 carry and finalFloat32 physical pose")
	check(not prepared.receipt.clock_advanced and not prepared.receipt.hp_applied and not prepared.receipt.fuel_advanced and not prepared.receipt.position_snapped,"The handoff executes no second physical interval, damage application, fuel burn or safety relocation")
	check(not prepared.receipt.source_atmosphere.apply_f1014 and prepared.receipt.distance_to_station_m<=StationFrame.MAX_DISTANCE_M,"The bounded handoff is genuinely near its source station and outside source atmospheric processing")
	var old_copy:=OrbitTrial._fork_world(row.world)
	var gravity_body:Vector3=old_copy.gravity_at(row.ship.position,day);var gravity_station:Vector3=world.gravity_at(ship.position,day)
	check(gravity_body.distance_to(gravity_station)<0.00001,"Source gravity samples the same real parent-space point, up to measured Float32 coordinate projection")
	station_frame_evidence.append({"case":"explicit_near_station_same_time_handoff","labelled_position_fixture_not_flown35Mm":true,"receipt":prepared.receipt,"gravity_body":str(gravity_body),"gravity_station":str(gravity_station),"all_input_owners_unchanged":true})

func run()->void:
	if "--frame-cache-only" in OS.get_cmdline_user_args():
		var nav:=Nav.new();check(nav.configure_source("cobra"),"Cache-only check initializes the actual source system")
		var world:=World.new();world.configure(nav.current(),World.FULL_LAYOUT);cache_isolation_and_bound(world)
		print("Native station frame cache: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0);return
	var flown:=actual_ascent_to_handoff()
	if not flown.is_empty():
		reject_far_and_parent(flown)
		var nearby:=explicit_near_station_fixture(flown)
		if not nearby.is_empty():pure_mapping(nearby);actual_station_boundary(nearby);cache_isolation_and_bound(nearby.world)
	var sources:Dictionary={}
	for path:String in ["scripts/native_station_frame.gd","scripts/native_orbit_trial.gd","scripts/planetary_system.gd","scripts/source_station_session.gd","scripts/source_orbit.gd","scripts/source_clock.gd","scripts/source_units.gd","tests/test_native_station_frame.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAME_REPORT.get_base_dir()));var file:=FileAccess.open(FRAME_REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":sources,"evidence":station_frame_evidence,"scope":"Actual20km powered source departure rejects the distant station. A separately labelled near-station orbital pose tests exact source raw-origin translation, sampled origin velocity, canonical roundtrip, sourcegravity and zero-time physical ownership. No flown35Mm transfer, complete F570/F606 object bank or ongoing inertial-trajectory equivalence claim."},"\t"));file.close()
	print("Native station frame: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
