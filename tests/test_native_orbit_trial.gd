extends "res://tests/test_native_surface_ascent.gd"
const OrbitTrial=preload("res://scripts/native_orbit_trial.gd")
const ORBIT_REPORT:="res://build/current-test-reports/native-orbit-trial.json"
var orbit_evidence:Array=[]
func fixture(down:bool=true)->Dictionary:
	var row:Dictionary=super.fixture(down)
	# Explicit preflight fitting fixture: the real source service charges the
	# existing funds/cargo budget. Thermal state and hull are never patched.
	row.ship.docked=true;row.ship.surface_mode=false;row.ship.station_available=true;row.nav.set_source_port_available(true)
	check(row.nav.service("install_fuel_equipment","atmospheric_shielding",1,row.ship),"Actual source service fits and charges atmospheric shielding for the long Earth departure")
	row.ship.docked=false;row.ship.surface_mode=true;row.ship.station_available=false;row.nav.set_source_port_available(false)
	check(row.nav.fuel_state(row.ship).atmospheric_shielding_installed,"Twenty-kilometre departure uses genuinely fitted shielding rather than suppressed source heat")
	return row
func orbit_owners(row:Dictionary)->PackedByteArray:
	return var_to_bytes([row.ship.snapshot(),row.nav.snapshot(),row.gear.snapshot(),row.world.snapshot(),row.surface.snapshot(),row.world.native_evaluation_count,row.world._native_cache_tick,row.world._native_cache_day,row.world._native_positions_raw,row.world._native_relative_raw,row.world.body_spin_by_id,row.orbit.snapshot(row.ship,row.nav,row.world,row.gear) if row.has("orbit") else {}])
func apply_orbit(result:Dictionary)->Dictionary:
	return {"ship":result.candidate_ship,"nav":result.candidate_nav,"gear":result.candidate_gear,"world":result.candidate_world,"surface":result.candidate_surface,"orbit":result.candidate_orbit}
func actual_ascent_to_handoff()->Dictionary:
	var row:=parked_ascent(20000.0)
	if row.is_empty():return {}
	var first_before:=all_owners(row);var intervals:=0
	for tick in range(4200):
		var result:Dictionary=row.pilot.advance(row.ship,row.nav,row.gear,row.surface,0.5)
		if not result.get("ok",false):check(false,"Actual twenty-kilometre native ascent remains accepted: "+str(result));return {}
		if tick==0:check(all_owners(row)==first_before,"Actual high-ascent first prepared interval leaves original source owners unchanged")
		row=accepted(row,result);intervals=tick+1
		if not row.pilot.is_active():break
	check(not row.pilot.is_active() and absf(row.surface.altitude(row.ship)-20000.0)<0.6,"Actual powered source ascent reaches twenty kilometres without a test teleport: "+str({"phase":row.pilot.phase(),"state":row.pilot._saved,"hull":row.ship.hull,"altitude":row.surface.altitude(row.ship),"fuel":row.nav.fuel_state(row.ship),"velocity":row.ship.velocity,"intervals":intervals}))
	if row.pilot.is_active():return {}
	var before:=orbit_owners(row);var hp:Dictionary=row.nav.thermal_state(row.ship);var fuel:Dictionary=row.nav.fuel_state(row.ship);var days:float=row.nav.elapsed_days;var gear:Dictionary=row.gear.snapshot()
	var result:=OrbitTrial.prepare_handoff(row.ship,row.nav,row.gear,row.surface)
	check(result.get("ok",false),"A genuinely flown native ascent can hand off to bounded space: "+str(result.get("reason","")))
	check(orbit_owners(row)==before,"Handoff changes no original Flight/Nav/Gear/World/source pose, spin or position cache")
	if not result.get("ok",false):return {}
	var next:=apply_orbit(result);var receipt:Dictionary=result.receipt
	check(next.nav.elapsed_days==days and next.nav.thermal_state(next.ship)==hp and next.nav.fuel_state(next.ship)==fuel and next.gear.snapshot()==gear,"Coordinate handoff advances no source clock, HP/RNG/fuel or gear interval")
	check(next.orbit.is_active() and not next.surface.active and not next.ship.surface_mode and not next.ship.station_available,"Handoff enters an explicitly separate orbital trial with inactive ordinary Surface")
	check(not receipt.position_snapped and not receipt.omega_cross_radius_added and not receipt.circular_orbit_inserted,"Receipt honestly separates continuous coordinate transfer from unported omega/bank and circular insertion")
	check(OrbitTrial._pose(next.ship)==receipt.space_pose_f32_hex and OrbitTrial._float(days)==receipt.source_days_f64_hex,"Handoff receipt retains exact actual output F32 pose and exact existing F64 time")
	var ideal:Array=NativeSurface._native_numbers(receipt.ideal_position_f64_hex,8)
	var errors:Array=NativeSurface._native_numbers(receipt.position_rounding_error_f64_hex,8)
	for axis in range(3):check(absf(float(next.ship.position[axis])-float(ideal[axis]))==float(errors[axis]),"Final F32 coordinate rounding is measured per axis "+str(axis))
	check(next.ship.velocity.length()>0 and absf(next.ship.velocity.length()-row.ship.velocity.length())<0.00001,"Handoff rotates and preserves actual nonzero velocity rather than zeroing it")
	var clear:Dictionary=next.world._full_surface_guard.probe(next.world,next.ship,days)
	check(clear.get("ok",false) and (clear.get("coarse_only",false) or float(clear.altitude_m)>=2000.0),"First orbital pose already satisfies the real v4 guard without protect/teleport")
	var native_profile:bool=row.ship.source_motion_profile;row.ship.source_motion_profile=true
	var profiled:=OrbitTrial.prepare_handoff(row.ship,row.nav,row.gear,row.surface)
	check(profiled.get("ok",false) and profiled.candidate_orbit.thrust_profile_enabled() and profiled.candidate_ship.acceleration()==row.ship.acceleration(),"Actual source-control profile and thrust capacity are preserved through handoff")
	if profiled.get("ok",false):
		var profiled_cold:=cold(apply_orbit(profiled))
		check(profiled_cold.ship.source_motion_profile and profiled_cold.ship.acceleration()==row.ship.acceleration(),"Cold replay restores the actual source-control profile after native Surface resets derived flags")
	row.ship.source_motion_profile=native_profile
	orbit_evidence.append({"case":"actual_source20km_powered_flight_to_space","intervals":intervals,"interval_seconds":0.5,"native_height_m":row.surface.altitude(row.ship),"handoff_receipt":receipt,"source_generation":row.surface.native_session.generation(),"ordinary_owners_unchanged":true})
	return next
func cold(row:Dictionary)->Dictionary:
	var snapshot:Dictionary=OrbitTrial._json(row.orbit.snapshot(row.ship,row.nav,row.world,row.gear))
	check(not snapshot.is_empty(),"Current bound orbital owners produce a strict complete JSON snapshot")
	var ship:=Ship.new();var nav:=Nav.new();var gear:=Gear.new();var world:=World.new();var surface:=Surface.new();var orbit:=OrbitTrial.new()
	check(ship.restore(OrbitTrial._json(row.ship.snapshot())) and nav.restore(OrbitTrial._json(row.nav.snapshot())) and gear.restore(OrbitTrial._json(row.gear.snapshot())),"Cold orbit restores legacy Flight/Nav/Gear anchors")
	world.configure(nav.current(),World.FULL_LAYOUT);check(world.restore(OrbitTrial._json(row.world.snapshot())),"Cold orbit restores source World without a new gameplay transfer")
	check(nav.bind_thermal_ship(ship) and nav.apply_fuel_availability(ship),"Cold orbit binds existing source HP/fuel owner")
	ship.station_available=false;ship.clear_source_station()
	var restored:bool=orbit.restore(snapshot,ship,nav,world,gear)
	if not restored:
		var replay:Dictionary=OrbitTrial._replay_lineage(snapshot.lineage);print("Orbit cold failure: ",orbit.last_error," ",replay.get("reason","missing"))
		if replay.get("ok",false):
			for key in snapshot.receipt:
				if snapshot.receipt[key]!=replay.receipt.get(key):print("RECEIPTDIFF ",key," ",snapshot.receipt[key]," VS ",replay.receipt.get(key))
			var pose:=NativeSurface._native_decode_pose(snapshot.pose_f32_hex);var copy_ship:=Trial._fork_ship(ship);var copy_nav:RefCounted=nav.fork_runtime();copy_ship.position=pose.position;copy_ship.velocity=pose.velocity;copy_ship.attitude=pose.attitude;copy_nav.elapsed_days=str(snapshot.elapsed_days_f64_hex).hex_decode().decode_double(0)
			print("BINDINGDEBUG ",OrbitTrial._owner_binding(copy_ship,copy_nav,world,gear)," VS ",snapshot.owners)
	check(restored,"Orbital cold restore replays genuine native pre-handoff lineage and validates the actual receipt")
	return {"ship":ship,"nav":nav,"gear":gear,"world":world,"surface":surface,"orbit":orbit}
func space_ticks_and_cold(row:Dictionary)->void:
	if row.is_empty():return
	row.ship.target_speed=17;row.ship.assisted=not row.ship.assisted;row.ship.external_view=not row.ship.external_view
	var speed:=OrbitTrial.Gas.raw_speed(row.ship.velocity)
	check(row.gear.command_request(true,{"flight_state_u8":0,"autopilot_phase_u8":0,"speed_s32":int(speed.speed_s32),"paused":false}).get("ok",false),"Legitimate orbital gear command changes requested controls before an interval")
	row.world.body_rotation_basis(row.world.focus_id,row.nav.elapsed_days)
	check(not row.orbit.snapshot(row.ship,row.nav,row.world,row.gear).is_empty(),"Speed/assistance/camera/gear controls and actual render spin-cache update do not invalidate physical orbit ownership")
	var cold_row:=cold(row)
	check(OrbitTrial._pose(cold_row.ship)==OrbitTrial._pose(row.ship) and cold_row.nav.elapsed_days==row.nav.elapsed_days and cold_row.orbit.snapshot(cold_row.ship,cold_row.nav,cold_row.world,cold_row.gear)==row.orbit.snapshot(row.ship,row.nav,row.world,row.gear),"Cold orbital phase retains exact phone pose, source day64 and full native lineage")
	for tick in range(3):
		var original:=orbit_owners(row);var before_day:float=row.nav.elapsed_days
		var a:Dictionary=row.orbit.prepare(row.ship,row.nav,row.gear,row.world,0.1,Vector2.ZERO,0,0.2)
		var b:Dictionary=cold_row.orbit.prepare(cold_row.ship,cold_row.nav,cold_row.gear,cold_row.world,0.1,Vector2.ZERO,0,0.2)
		check(a.get("ok",false) and b.get("ok",false),"Actual original-gravity/F574/fuel/thermal orbital interval prepares: "+str(a.get("reason","")))
		if not a.get("ok",false) or not b.get("ok",false):return
		check(orbit_owners(row)==original,"Actual orbital preparation changes no original World caches, gear, HP/fuel/RNG/clock or pose")
		row=apply_orbit(a);cold_row=apply_orbit(b)
		check(row.nav.elapsed_days==before_day+0.1/86400.0 and row.orbit._generation==tick+1,"One orbital step advances exactly one day interval and one trial generation")
		check(OrbitTrial._pose(row.ship)==OrbitTrial._pose(cold_row.ship) and row.nav.snapshot().source_hyperdrive==cold_row.nav.snapshot().source_hyperdrive and row.world.snapshot()==cold_row.world.snapshot() and row.gear.snapshot()==cold_row.gear.snapshot(),"Warm and strict-cold orbital steps reproduce the same pose, source HP/RNG/fuel, spin and gear")
		check(a.interval_receipt.legacy_orbit_guard.get("coarse_only",false) or float(a.interval_receipt.legacy_orbit_guard.altitude_m)>=2000.0,"Accepted space step remains above the actual guard without a protection teleport")
	var again:=cold(row)
	check(again.orbit.is_active() and OrbitTrial._pose(again.ship)==OrbitTrial._pose(row.ship) and again.nav.elapsed_days==row.nav.elapsed_days,"Nonzero orbital generation cold-restores exact current state as well as the initial lineage")
	orbit_evidence.append({"case":"actual_orbit_steps_and_cold_repeat","generations":row.orbit._generation,"hull":row.ship.hull,"day_f64_hex":OrbitTrial._float(row.nav.elapsed_days),"full_source_object_bank":false})
func low_speed_fractional_motion(row:Dictionary)->void:
	if row.is_empty():return
	row.ship.target_speed=1.0;row.ship.assisted=true
	# Real steering creates a mixed-component direction. No pose or velocity
	# is injected into the bound session; the actual Flight controls do it.
	for tick in range(64):
		var steering:=Vector2(0.6,0.4) if tick<60 else Vector2.ZERO
		var turned:Dictionary=row.orbit.prepare(row.ship,row.nav,row.gear,row.world,1.0/60.0,steering)
		check(turned.get("ok",false),"Actual orbital steering reaches a stable one-metre-per-second assisted coast")
		if not turned.get("ok",false):return
		row=apply_orbit(turned)
	var velocity:Vector3=row.ship.velocity;var start:PackedFloat64Array=row.orbit._position_f64.duplicate();var naive:Vector3=row.ship.position;var start_scene:=naive
	check(absf(velocity.length()-1.0)<0.00001 and absf(velocity.x)>0.01 and absf(velocity.y)>0.01 and absf(velocity.z)>0.01,"One-metre-per-second precision fixture has three genuine nonzero velocity components")
	var cold_row:Dictionary={}
	for tick in range(60):
		var result:Dictionary=row.orbit.prepare(row.ship,row.nav,row.gear,row.world,1.0/60.0)
		check(result.get("ok",false),"Sub-Float32-ULP orbital interval remains accepted")
		if not result.get("ok",false):return
		naive+=result.candidate_ship.velocity*(1.0/60.0)
		row=apply_orbit(result)
		if tick==29:cold_row=cold(row)
		elif tick>=30:
			var resumed:Dictionary=cold_row.orbit.prepare(cold_row.ship,cold_row.nav,cold_row.gear,cold_row.world,1.0/60.0)
			check(resumed.get("ok",false),"Halfway-cold precision coast continues the actual source interval")
			if not resumed.get("ok",false):return
			cold_row=apply_orbit(resumed)
			check(cold_row.orbit._position_f64==row.orbit._position_f64 and OrbitTrial._pose(cold_row.ship)==OrbitTrial._pose(row.ship) and cold_row.nav.elapsed_days==row.nav.elapsed_days and cold_row.nav.snapshot().source_hyperdrive==row.nav.snapshot().source_hyperdrive,"Cold halfway continuation preserves fractional position, exact pose and source fuel/clock")
	check(naive==start_scene,"The same per-tick Float32 position integration genuinely loses every small displacement at this actual orbital coordinate")
	var displacement:=PackedFloat64Array()
	for axis in range(3):
		displacement.append(row.orbit._position_f64[axis]-start[axis])
		check(absf(displacement[axis]-float(velocity[axis]))<0.001,"Persistent double position retains a second of actual mixed-axis low-speed motion "+str(axis))
	check(Vector3(displacement[0],displacement[1],displacement[2]).length()>0.999 and row.ship.position!=naive,"Accumulated physical movement reaches one metre and crosses a visible Float32 cell instead of remaining stuck")
	orbit_evidence.append({"case":"actual_large_frame_one_metre_per_second60Hz_coast","ticks":60,"interval_seconds":1.0/60.0,"start_position_f64_hex":NativeSurface._native_floats(Array(start),8),"final_position_f64_hex":NativeSurface._native_floats(Array(row.orbit._position_f64),8),"displacement_m":Array(displacement),"velocity_mps":[velocity.x,velocity.y,velocity.z],"naive_float32_trajectory_stuck":true,"cold_halfway_bit_exact":true})
func typed_guards(row:Dictionary)->void:
	var low:=parked_ascent(30.0)
	if not low.is_empty():
		var before:=all_owners(low);var rejected:=OrbitTrial.prepare_handoff(low.ship,low.nav,low.gear,low.surface)
		check(not rejected.ok and all_owners(low)==before,"Low or parked native handoff rejects without releasing park or changing source owners")
	if row.is_empty():return
	var protected:=orbit_owners(row)
	var lowered_ship:=Trial._fork_ship(row.ship);var lowered_world:=OrbitTrial._fork_world(row.world)
	var sampled:Dictionary=lowered_world._full_surface_guard.probe(lowered_world,lowered_ship,row.nav.elapsed_days)
	check(sampled.get("ok",false) and not sampled.get("coarse_only",true),"Explicit guard-boundary fixture samples the actual v4 field under the flown orbital point")
	if sampled.get("ok",false) and not sampled.get("coarse_only",true):
		lowered_ship.position-=Vector3(sampled.direction)*(float(sampled.altitude_m)-1000.0)
		var low_guard:=OrbitTrial._guard(lowered_world,lowered_ship,row.nav.elapsed_days)
		check(not low_guard.ok and low_guard.required_extra_climb_m>0 and not low_guard.position_snapped and orbit_owners(row)==protected,"Actual low-v4-clearance boundary requests further powered climb and changes no live owners or pose")
	var changed_ship:=Trial._fork_ship(row.ship);changed_ship.position.x+=2.0
	check(row.orbit.snapshot(changed_ship,row.nav,row.world,row.gear).is_empty(),"Physical pose drift cannot be silently rebound as legitimate UI/render changes")
	check(not row.orbit.prepare(changed_ship,row.nav,row.gear,row.world,0.1).ok and orbit_owners(row)==protected,"External physical pose drift rejects atomically before any orbital source interval")
	for dt:float in [0.0,-0.1,0.2,INF,NAN]:
		var failed:Dictionary=row.orbit.prepare(row.ship,row.nav,row.gear,row.world,dt)
		check(not failed.ok and orbit_owners(row)==protected,"Invalid orbital interval fails atomically "+str(dt))
	var good:Dictionary=OrbitTrial._json(row.orbit.snapshot(row.ship,row.nav,row.world,row.gear))
	var variants:Array=[];var bad:=good.duplicate(true);bad.receipt.position_snapped=true;variants.append(bad)
	bad=good.duplicate(true);bad.lineage.surface.phone_pose_f32_hex="00".repeat(40);variants.append(bad)
	bad=good.duplicate(true);bad.pose_f32_hex="00".repeat(40);variants.append(bad)
	bad=good.duplicate(true);bad.owners.body_id="mars";variants.append(bad)
	bad=good.duplicate(true);bad.elapsed_days_f64_hex=OrbitTrial._float(row.nav.elapsed_days+1);variants.append(bad)
	bad=good.duplicate(true);bad.generation=1;variants.append(bad)
	bad=good.duplicate(true);bad.thrust_profile_enabled=1;variants.append(bad)
	bad=good.duplicate(true);bad.position_f64_hex="00".repeat(24);variants.append(bad)
	for i in range(variants.size()):
		var value:Dictionary=variants[i];value.lineage_sha256=OrbitTrial._hash(value.lineage);value.erase("snapshot_sha256");value.snapshot_sha256=OrbitTrial._hash(value)
		var copy_ship:=Trial._fork_ship(row.ship);var copy_nav:RefCounted=row.nav.fork_runtime();var copy_world:=OrbitTrial._fork_world(row.world);var copy_gear:=OrbitTrial._fork_gear(row.gear);var trial:=OrbitTrial.new()
		var previous:=var_to_bytes([copy_ship.snapshot(),copy_nav.snapshot(),copy_world.snapshot(),copy_gear.snapshot()])
		check(not trial.restore(value,copy_ship,copy_nav,copy_world,copy_gear),"Resealed foreign lineage/receipt/current binding is rejected "+str(i))
		check(previous==var_to_bytes([copy_ship.snapshot(),copy_nav.snapshot(),copy_world.snapshot(),copy_gear.snapshot()]) and not trial.is_active(),"Rejected orbital restore changes no candidate owners "+str(i))
func run()->void:
	var row:=actual_ascent_to_handoff();space_ticks_and_cold(row);low_speed_fractional_motion(row);typed_guards(row)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ORBIT_REPORT.get_base_dir()));var file:=FileAccess.open(ORBIT_REPORT,FileAccess.WRITE)
	var sources:Dictionary={}
	for path:String in ["scripts/native_orbit_trial.gd","scripts/native_landing_trial.gd","scripts/native_surface_model.gd","scripts/native_surface_autopilot.gd","tests/test_native_orbit_trial.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":orbit_evidence,"sources":sources,"scope":"Genuinely flown original-contact Earth20km powered ascent; affine frame handoff; bounded manual orbit with source gravity/fuel/thermal and old-guard rejection; pure cold lineage replay. No original object-bank/F573caller/circularorbit or physical Android claim."},"\t"));file.close()
	print("Native orbit trial: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
