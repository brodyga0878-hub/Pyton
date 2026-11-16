extends "res://tests/test_native_station_frame.gd"
# Bounded current-station fixture. The distant travel to site13 is NOT flown.
const StationTrial=preload("res://scripts/native_station_trial.gd")
const SourceStation=preload("res://scripts/source_station_session.gd")
const StationWorld=preload("res://scripts/planetary_system.gd")
const StationNav=preload("res://scripts/navigation.gd")
const STATION_REPORT:="res://build/current-test-reports/native-station-trial.json"
var station_evidence:Array=[]
func station_fixture(flown:Dictionary)->Dictionary:
	var row:=explicit_near_station_fixture(flown)
	if row.is_empty():return {}
	var target:RefCounted=OrbitTrial._fork_world(row.world);target.site_id="site13"
	var nav:RefCounted=row.nav.fork_runtime();var pose:RefCounted=Trial._fork_ship(row.ship)
	var context:Dictionary=SourceStation.configure_flight(pose,target,nav)
	check(context.get("ok",false) and context.get("active",false),"Explicit station fixture uses the actual source site13 geometry/spin")
	if not context.get("ok",false):return {}
	var position:Vector3=pose.STATION+pose._source_basis*(Vector3(pose._source_station.approach_waypoint)+Vector3(0,0,100))
	var mapped:Dictionary=StationFrame.map_between(target,row.world,PackedFloat64Array([position.x,position.y,position.z]),Vector3.ZERO,row.nav.elapsed_days)
	check(mapped.get("ok",false),"Fixture's explicit original outer-waypoint-plus100m station position is translated into the existing body frame, not reached by a false flight claim")
	if not mapped.get("ok",false):return {}
	row.ship.position=Vector3(mapped.position_f64[0],mapped.position_f64[1],mapped.position_f64[2]);row.ship.velocity=Vector3(mapped.velocity_f64[0],mapped.velocity_f64[1],mapped.velocity_f64[2]);row.ship.attitude=pose._source_basis.get_rotation_quaternion().normalized();row.orbit._position_f64=mapped.position_f64.duplicate();row.orbit._bind(row.ship,row.nav,row.world,row.gear)
	var protected:=orbit_owners(row)
	var prepared:Dictionary=StationTrial.prepare_handoff(row.orbit,row.ship,row.nav,row.gear,row.world,"site13")
	check(prepared.get("ok",false),"Actual bound orbital owner prepares the near-station transfer: "+str(prepared.get("reason","")))
	check(orbit_owners(row)==protected,"Preparing station phase never changes its actual previous orbital owners")
	return station_apply(prepared) if prepared.get("ok",false) else {}
func station_apply(prepared:Dictionary)->Dictionary:
	return {"ship":prepared.candidate_ship,"nav":prepared.candidate_nav,"gear":prepared.candidate_gear,"world":prepared.candidate_world,"surface":prepared.candidate_surface,"station":prepared.candidate_station}
func station_facts(row:Dictionary)->Dictionary:
	return {"ship":row.ship.snapshot(),"navigation":row.nav.snapshot(),"gear":row.gear.snapshot(),"world":row.world.snapshot(),"station":row.station.snapshot(row.ship,row.nav,row.world,row.gear)}
func station_cold(row:Dictionary)->Dictionary:
	var saved:Dictionary=JSON.parse_string(JSON.stringify(station_facts(row)))
	var nav:=StationNav.new();var gear:=Gear.new();var world:=StationWorld.new();var station:=StationTrial.new()
	check(nav.restore(saved.navigation) and gear.restore(saved.gear),"Cold station uses original Nav/Gear factories")
	var days:float=StationTrial._decode_float(saved.station.elapsed_days_f64_hex)
	check(OrbitTrial._decimal(days)==nav.elapsed_days,"Exact station clock retains its ordinary decimal anchor")
	nav.elapsed_days=days;world.configure(nav.current(),StationWorld.FULL_LAYOUT)
	check(world.restore(saved.world),"Cold station reconstructs validated raw source spin and door")
	var loaded:Dictionary=SourceStation.restore_flight(world,nav,saved.ship)
	check(not loaded.is_empty(),"Cold station uses actual version5 Flight factory")
	if loaded.is_empty():return {}
	var ship:RefCounted=loaded.ship
	check(nav.bind_thermal_ship(ship) and nav.apply_fuel_availability(ship),"Cold station binds original HP/fuel state without repair")
	var restored:bool=station.restore(saved.station,ship,nav,world,gear)
	check(restored,"Cold station validates original entry, source angular witnesses and current owners: "+station.last_error)
	if not restored:
		var debug:=FileAccess.open("res://build/current-test-reports/native-station-cold-failed.json",FileAccess.WRITE)
		if debug:debug.store_string(JSON.stringify(saved));debug.close()
		return {}
	var result:={"ship":ship,"nav":nav,"gear":gear,"world":world,"surface":row.surface.get_script().new(),"station":station}
	check(station_facts(result)==station_facts(row),"Cold station retains exact autopilot phase, F64 carry, raw owners, angular history and clock")
	return result
func station_compare(warm:Dictionary,steps:int=8)->Dictionary:
	var cold:=station_cold(warm)
	if cold.is_empty():return {}
	for tick in range(steps):
		var a:Dictionary=warm.station.prepare(warm.ship,warm.nav,warm.gear,warm.world,0.1)
		var b:Dictionary=cold.station.prepare(cold.ship,cold.nav,cold.gear,cold.world,0.1)
		check(a.get("ok",false) and b.get("ok",false),"Warm and cold station continuations both accept real interval: "+str(a.get("reason",""))+" / "+str(b.get("reason","")))
		if not a.get("ok",false) or not b.get("ok",false):return {}
		warm=station_apply(a);cold=station_apply(b)
		check(station_facts(warm)==station_facts(cold),"Warm/cold source station next interval is exact "+str(tick))
	return warm
func flow(row:Dictionary)->void:
	var before:=station_facts(row);var command:Dictionary=row.station.prepare_command(row.ship,row.nav,row.gear,row.world,"auto")
	check(command.get("ok",false) and station_facts(row)==before,"Automatic approach command forks actual state with zero live mutation")
	if not command.get("ok",false):return
	row=station_apply(command)
	check(row.ship.autopilot and row.nav.elapsed_days==StationTrial._decode_float(before.station.elapsed_days_f64_hex),"Auto enables real guidance/request without a clock interval")
	row=station_compare(row,8)
	if row.is_empty():return
	var elapsed:=0;var cold_enter:=false;var all_safe:=true
	for index in range(8000):
		var day:float=row.nav.elapsed_days;var result:Dictionary=row.station.prepare(row.ship,row.nav,row.gear,row.world,0.1)
		if not result.get("ok",false):check(false,"Actual station approach interval failed: "+str(result.get("reason","")));return
		row=station_apply(result);elapsed+=1
		if row.nav.elapsed_days!=day+0.1/86400.0 or row.ship.hull!=100:all_safe=false;break
		if not cold_enter and row.ship._source_pilot_phase=="enter":
			row=station_compare(row,8);cold_enter=true
			if row.is_empty():return
		if row.ship.docked:break
	check(all_safe and row.ship.docked and row.ship.hull==100,"Real station-following approach reaches a healthy physical dock")
	check(cold_enter,"Cold continuation also preserves actual final-enter phase")
	if not row.ship.docked:return
	row=station_compare(row,3)
	if row.is_empty():return
	var protected:=station_facts(row)
	var service:Dictionary=row.station.prepare_service(row.ship,row.nav,row.gear,row.world,"refuel","hydrogen",1)
	check(station_facts(row)==protected,"Preparing an actual accepted or rejected source service never leaks paid state")
	check(service.get("ok",false),"Existing source hydrogen service accepts the genuine docked owner: "+str(service.get("message","")))
	if not service.get("ok",false):return
	var day:float=row.nav.elapsed_days;var credits_before:int=row.ship.credits;var fuel_before:int=row.nav.fuel
	row=station_apply(service)
	check(row.nav.elapsed_days==day and row.ship.credits<credits_before and row.nav.fuel==fuel_before+1,"Actual source refuel charges credits, adds one fuel tonne and spends no physical clock interval")
	var launch:Dictionary=row.station.prepare_command(row.ship,row.nav,row.gear,row.world,"launch")
	check(launch.get("ok",false),"Actual original launch command prepares on private owners")
	if not launch.get("ok",false):return
	row=station_apply(launch)
	check(not row.ship.docked and row.ship.velocity.length()>0,"Open source dock releases real outward velocity rather than teleporting away")
	row=station_compare(row,12)
	if row.is_empty():return
	for index in range(120):
		var next:Dictionary=row.station.prepare(row.ship,row.nav,row.gear,row.world,0.1)
		if not next.get("ok",false):check(false,"Actual departure interval accepted: "+str(next.get("reason","")));return
		row=station_apply(next)
	var before_reverse:=station_facts(row);var reversed:Dictionary=row.station.prepare_reverse(row.ship,row.nav,row.gear,row.world)
	check(reversed.get("ok",false) and station_facts(row)==before_reverse,"Actual undocked source session prepares continuous reverse without live mutation")
	if not reversed.get("ok",false):return
	check(reversed.candidate_orbit.is_active() and reversed.candidate_world.site_id.is_empty() and not reversed.candidate_ship.has_source_station() and reversed.candidate_nav.elapsed_days==row.nav.elapsed_days,"Reverse re-enters the unchanged original orbital contract at the same exact clock")
	var orbital:Dictionary=reversed.candidate_orbit.snapshot(reversed.candidate_ship,reversed.candidate_nav,reversed.candidate_world,reversed.candidate_gear)
	check(not orbital.is_empty(),"Returned orbital owner serializes without a schema relaxation")
	station_evidence.append({"case":"actual_station_approach_dock_service_launch_reverse","approach_intervals":elapsed,"cold_enter_compared":cold_enter,"final_hull":row.ship.hull,"reverse_clock_unchanged":true,"fixture_relocation_explicit_not_flown":true,"start":"source_outer_waypoint_plus100m"})
func probe_equivalence(row:Dictionary)->void:
	var protected:=station_facts(row)
	var bodyworld:RefCounted=row.station._body_world(row.nav,row.world)
	var mapped:Dictionary=StationFrame.map_between(row.world,bodyworld,row.station._position_f64,row.ship.velocity,row.nav.elapsed_days)
	check(mapped.get("ok",false),"Read-only comparison maps the actual same physical station point into the canonical body frame")
	if not mapped.get("ok",false):return
	for case_index in range(3):
		var full:RefCounted=Trial._fork_ship(row.ship)
		full.position=Vector3(mapped.position_f64[0],mapped.position_f64[1],mapped.position_f64[2]);full.velocity=Vector3(mapped.velocity_f64[0],mapped.velocity_f64[1],mapped.velocity_f64[2]);full.docked=false;full.surface_mode=false;full.clear_source_station()
		if case_index==1:full.hull=0.0
		if case_index==2:
			var body:Dictionary=bodyworld.by_id[bodyworld.focus_id]
			full.position=bodyworld.local_meters(bodyworld.focus_id,row.nav.elapsed_days)+Vector3.UP*(float(body.radius_km)*1000.0+2500.0)
			full.velocity=Vector3(2,-3,4)
		var light:=StationTrial.BodyProbe.new();light.position=full.position;light.velocity=full.velocity;light.hull=full.hull
		var first:Dictionary=StationTrial.Atmosphere.new().sample(OrbitTrial._fork_world(bodyworld),full,StationTrial.Surface.new(),row.nav.elapsed_days,false)
		var second:Dictionary=StationTrial.Atmosphere.new().sample(OrbitTrial._fork_world(bodyworld),light,StationTrial.Surface.new(),row.nav.elapsed_days,false)
		check(var_to_bytes(first)==var_to_bytes(second),"Light probe preserves every exact source atmosphere output at station/zero-hull/body-edge case "+str(case_index))
		first=OrbitTrial.Gas.new().sample(OrbitTrial._fork_world(bodyworld),full,row.nav.elapsed_days);second=OrbitTrial.Gas.new().sample(OrbitTrial._fork_world(bodyworld),light,row.nav.elapsed_days)
		check(var_to_bytes(first)==var_to_bytes(second),"Light probe preserves every exact source fuel/contact output case "+str(case_index))
		first=OrbitTrial._guard(OrbitTrial._fork_world(bodyworld),full,row.nav.elapsed_days);second=OrbitTrial._guard(OrbitTrial._fork_world(bodyworld),light,row.nav.elapsed_days)
		check(var_to_bytes(first)==var_to_bytes(second),"Light probe preserves every exact body guard output and rejection case "+str(case_index))
	check(station_facts(row)==protected,"Comparison probes never mutate original geometry, pose, raw owners, source caches or time")
	station_evidence.append({"case":"private_light_probe_bitexact_comparison","cases":3,"independent_sampler_pairs":9,"station_and_zero_hull_and_body_edge":true,"physical_owner_unchanged":true})
func guards(row:Dictionary)->void:
	var protected:=station_facts(row);var stale:RefCounted=Trial._fork_ship(row.ship);stale.position.x+=1
	check(not row.station.prepare(stale,row.nav,row.gear,row.world,0.1).get("ok",false) and station_facts(row)==protected,"A stale physical station pose rejects before owner publication")
	check(not row.station.prepare(row.ship,row.nav,row.gear,row.world,0).get("ok",false) and not row.station.prepare_command(row.ship,row.nav,row.gear,row.world,"unknown").get("ok",false) and station_facts(row)==protected,"Malformed interval/command preserve raw owners and exact clock")
	var bad:Dictionary=protected.station.duplicate(true);bad.motion.angular_f32_hex=StationTrial._vec(Vector3(1,2,3));var sealed:=bad.duplicate(true);sealed.erase("snapshot_sha256");bad.snapshot_sha256=OrbitTrial._hash(sealed)
	var rejected:=StationTrial.new();check(not rejected.restore(bad,row.ship,row.nav,row.world,row.gear) and station_facts(row)==protected,"Even resealed false angular history cannot attach to current source raw spin")
func run()->void:
	var flown:=actual_ascent_to_handoff();var row:Dictionary={}
	if not flown.is_empty():row=station_fixture(flown)
	if not row.is_empty():probe_equivalence(row);guards(row);flow(row)
	var sources:Dictionary={}
	for path:String in ["scripts/native_station_trial.gd","scripts/native_station_frame.gd","scripts/native_orbit_trial.gd","scripts/source_station_session.gd","scripts/flight_model.gd","scripts/rotating_dock_dynamics.gd","tests/test_native_station_trial.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STATION_REPORT.get_base_dir()));var file:=FileAccess.open(STATION_REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":sources,"evidence":station_evidence,"scope":"Bounded near-station fixture derived from an actual outbound owner. Same-time station/body boundary; existing station-following flight law, actual spin/door/CCD/autopilot/dock/source services/launch, exact cold angular history and raw HP/fuel/day ownership. Explicit far-position fixture is not a flown planet-to-station transit or full original F570/F606/AI proof."},"\t"));file.close()
	print("Native station trial: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
