extends "res://tests/test_native_orbit_return.gd"
const DESCENT_REPORT:="res://build/current-test-reports/native-return-descent.json"
var descent_evidence:Array=[]

func descent_fixture()->Dictionary:
	var orbital:=actual_ascent_to_handoff()
	if orbital.is_empty():return {}
	var prepared:=ReturnTrial.prepare_return(orbital.orbit,orbital.ship,orbital.nav,orbital.gear,orbital.world)
	check(prepared.get("ok",false),"Long descent starts with an actually flown twenty-kilometre outbound and inverse frame return")
	if not prepared.get("ok",false):return {}
	var row:=returned_row(prepared);row.pilot=Pilot.new()
	var before:=owners(row);var pose:=OrbitTrial._pose(row.ship)
	check(row.pilot.configure_descent(row.ship,row.nav,row.surface),"Return-descent guidance binds to the actual airborne native source pose")
	check(row.pilot.mode()=="return_landing" and row.pilot.is_active() and row.pilot.phase()=="entry","Long descent has an explicit saved return_landing mode rather than pretending to be the original AI")
	check(owners(row)==before and OrbitTrial._pose(row.ship)==pose,"A long-descent request changes no physical source pose, HP/RNG/fuel, gear or day")
	return row

func pure_descent_state(row:Dictionary)->PackedByteArray:
	return var_to_bytes([owners(row),row.pilot.snapshot()])

func full_descent(row:Dictionary)->void:
	if row.is_empty():return
	var start_hull:float=row.ship.hull;var start_fuel:Dictionary=row.nav.fuel_state(row.ship);var start_day:float=row.nav.elapsed_days;var start_height:float=row.surface.altitude(row.ship);var start_position:Vector3=row.ship.position
	var cold_row:Dictionary={};var compared:=0;var cold_windows:=0;var window_left:=0;var high_cold:=false;var low_cold:=false
	var fast_seen:=false;var high_gear_stowed:=false;var real_extension:=false;var gear_request_below_gate:=false;var braking_seen:=false;var max_step:=0.0;var steps:=0;var accepted_contact:Dictionary={};var phases:Dictionary={}
	for tick in range(2400):
		var before:=pure_descent_state(row);var old_position:Vector3=row.ship.position;var old_altitude:float=row.surface.altitude(row.ship)
		var result:Dictionary=row.pilot.advance(row.ship,row.nav,row.gear,row.surface,0.5)
		check(result.get("ok",false),"Actual long native descent prepares a real source interval: "+str(result.get("reason","")))
		check(pure_descent_state(row)==before,"Prepared long descent leaves all original source/gear/HP/fuel/day/pilot owners unchanged")
		if not result.get("ok",false):return
		var cold_result:Dictionary={}
		if window_left>0:
			cold_result=cold_row.pilot.advance(cold_row.ship,cold_row.nav,cold_row.gear,cold_row.surface,0.5)
			check(cold_result.get("ok",false),"Restored return_landing guidance continues its actual source interval")
			if not cold_result.get("ok",false):return
		row=accepted(row,result);steps=tick+1
		var height:float=row.surface.altitude(row.ship);var gear_state:Dictionary=row.gear.state()
		var phase_name:=str(result.guidance.phase);phases[phase_name]=true
		max_step=maxf(max_step,old_position.distance_to(row.ship.position))
		check(old_position.distance_to(row.ship.position)<=30.1,"A half-second descent interval moves by its actual bounded speed and never snaps the height")
		check(row.ship.hull==start_hull and result.damage.contact_damage.applied_calls==0,"Healthy long return preserves actual raw hull without synthetic atmospheric/contact HP patches")
		if old_altitude>1000.0 and not gear_state.requested_down:high_gear_stowed=true
		if old_altitude>1000.0 and row.ship.velocity.y<(-20.0):fast_seen=true
		if phase_name=="braking":braking_seen=true
		if gear_state.requested_down:
			gear_request_below_gate=true
			check(old_altitude<=Pilot.RETURN_GEAR_HEIGHT_M,"Real source gear is requested down only after the preceding pose reaches the declared low-altitude gate")
		if gear_state.moving and gear_state.requested_down:real_extension=true
		if window_left>0:
			cold_row=accepted(cold_row,cold_result);window_left-=1;compared+=1
			check(OrbitTrial._pose(row.ship)==OrbitTrial._pose(cold_row.ship) and row.surface.snapshot()==cold_row.surface.snapshot() and row.pilot.snapshot()==cold_row.pilot.snapshot() and row.gear.snapshot()==cold_row.gear.snapshot() and row.nav.elapsed_days==cold_row.nav.elapsed_days and row.nav.snapshot().source_hyperdrive==cold_row.nav.snapshot().source_hyperdrive,"Cold long return reproduces exact physical/raw pose, guidance, real gear, source HP/RNG/fuel and one day clock")
		if not high_cold and steps>=4:
			cold_row=strict_cold(row);high_cold=true;window_left=12;cold_windows+=1
			check(cold_row.pilot.mode()=="return_landing" and cold_row.pilot.snapshot()==row.pilot.snapshot(),"High-altitude return_landing mode and exact native binding survive the ordinary cold contracts")
		elif high_cold and not low_cold and window_left==0 and height<290.0 and row.pilot.is_active():
			cold_row=strict_cold(row);low_cold=true;window_left=12;cold_windows+=1
			check(cold_row.pilot.mode()=="return_landing" and cold_row.gear.snapshot()==row.gear.snapshot(),"Low-altitude return cold-decodes the actual deployed or moving gear and source descent phase")
		if result.stage.contact_detected:accepted_contact=result
		if not row.pilot.is_active():break
	check(fast_seen and high_gear_stowed and braking_seen,"Actual twenty-kilometre descent flies a fast stowed-gear segment and physical braking segment")
	check(gear_request_below_gate and real_extension and row.gear.state().deployed,"Low-altitude approach requests and physically completes actual source gear extension")
	check(cold_windows==2 and compared>=24,"Both high descent and low approach cold-restores reproduce at least twenty-four following real intervals")
	check(not row.pilot.is_active() and row.pilot.phase()=="completed" and row.surface.landed and row.surface.native_session.phase()=="parked","Full return finishes in the genuinely accepted original parked state and stops guidance")
	check(not accepted_contact.is_empty() and accepted_contact.stage.landing_accepted and accepted_contact.stage.source_prepared.contact_detected,"Real F576/F575 source contact alone accepts the eventual return landing")
	check(row.ship.velocity==Vector3.ZERO and row.ship.position.y<start_position.y and row.ship.hull==start_hull,"Full powered descent reaches an actual healthy source park with zero parked velocity")
	check(row.nav.elapsed_days>start_day and row.nav.fuel_state(row.ship)!=start_fuel,"The long descent consumes genuine source propulsion fuel and advances actual navigation time")
	descent_evidence.append({"case":"actual20km_return_descent_to_original_park","interval_seconds":0.5,"intervals":steps,"start_display_agl_m":start_height,"final_display_agl_m":row.surface.altitude(row.ship),"phases":phases.keys(),"max_observed_step_m":max_step,"cold_windows":cold_windows,"exact_cold_intervals":compared,"hull":row.ship.hull,"source_generation":row.surface.native_session.generation(),"gear_deployed":row.gear.state().deployed,"original_contact_accepted":not accepted_contact.is_empty() and bool(accepted_contact.stage.landing_accepted)})

func malformed_return_guidance(row:Dictionary)->void:
	if row.is_empty():return
	var saved:Dictionary=row.pilot.snapshot();var original:=pure_descent_state(row)
	var variants:Array=[];var bad:=saved.duplicate(true);bad.mode="return_landing_extra";variants.append(bad)
	bad=saved.duplicate(true);bad.phase="launch";variants.append(bad)
	bad=saved.duplicate(true);bad.phase="completed";variants.append(bad)
	bad=saved.duplicate(true);bad.target_height_f64_hex=Pilot._float_hex(1000000.0);variants.append(bad)
	bad=saved.duplicate(true);bad.binding.source_generation=int(bad.binding.source_generation)+1;variants.append(bad)
	for index in range(variants.size()):
		var rejected:=Pilot.new()
		check(not rejected.restore(Pilot._sealed(variants[index]),row.ship,row.nav,row.surface) and pure_descent_state(row)==original,"Rehashed malformed return mode/phase/target or stale raw binding rejects without modifying source owners "+str(index))
	var high_ship:RefCounted=Trial._fork_ship(row.ship);high_ship.position.y+=40000
	var high_surface:RefCounted=row.surface.fork_runtime(high_ship)
	check(not Pilot.new().configure_descent(high_ship,row.nav,high_surface) and pure_descent_state(row)==original,"Explicit excessive-height boundary fixture cannot start bounded return guidance")
	var cancelled:RefCounted=row.pilot.fork_runtime();cancelled.cancel("manual_return_control")
	check(not cancelled.is_active() and not cancelled.advance(row.ship,row.nav,row.gear,row.surface,0.5).ok and pure_descent_state(row)==original,"Manual cancellation prevents any further automatic descent interval")
	descent_evidence.append({"case":"typed_return_guidance_guards","malformed_variants":variants.size(),"original_owners_unchanged":true})

func dry_return_braking(row:Dictionary)->void:
	if row.is_empty():return
	var ship:RefCounted=Trial._fork_ship(row.ship);var nav:RefCounted=row.nav.fork_runtime();var surface:RefCounted=row.surface.fork_runtime(ship);var gear:=Gear.new()
	check(gear.restore(row.gear.snapshot()),"Exhausted-return fixture retains the real mechanical gear phase")
	var saved:Dictionary=nav.snapshot();saved.source_hyperdrive.fuel_system.jet_raw_u32=0;saved.source_hyperdrive.fuel_system.disabled_axes_mask_u8=0x15;saved.source_hyperdrive.fuel_system.status_u16=1
	check(nav.restore(saved) and nav.bind_thermal_ship(ship) and nav.apply_fuel_availability(ship),"Exhausted return uses the actual source empty tank and positive nozzle limits")
	var dry:={"ship":ship,"nav":nav,"surface":surface,"gear":gear,"world":row.world,"pilot":row.pilot.fork_runtime()}
	var before:=pure_descent_state(dry);var position:Vector3=ship.position
	# Inverse F32 orientation can leave microscopic rotated-axis roundoff. The
	# original component filter must still remove every useful upward impulse.
	var filtered:Vector3=ship.filter_propulsive_delta(Vector3.UP)
	check(filtered.length()<0.000001 and filtered.dot(Vector3.UP)<0.00000001,"The real source propulsion filter prevents useful upward braking after positive nozzles exhaust")
	check(not Pilot.new().configure_descent(ship,nav,surface) and pure_descent_state(dry)==before,"Empty positive propulsion cannot start a controller that requires upward braking")
	var prepared:Dictionary=dry.pilot.advance(ship,nav,gear,surface,0.5)
	check(not prepared.get("ok",false) and prepared.get("reason")=="insufficient_vertical_propulsion" and pure_descent_state(dry)==before and ship.position==position,"An active return request with an exhausted tank rejects atomically without moving, advancing time/fuel or fabricating braking")
	descent_evidence.append({"case":"actual_source_empty_positive_nozzle_return_guard","reason":str(prepared.get("reason","")),"filtered_upward_unit_command":[filtered.x,filtered.y,filtered.z],"propulsion_filter_respected":true,"original_owners_unchanged":true})

func run()->void:
	var row:=descent_fixture()
	if not row.is_empty():malformed_return_guidance(row);dry_return_braking(row);full_descent(row)
	var sources:Dictionary={}
	for path:String in ["scripts/native_surface_autopilot.gd","scripts/native_orbit_return.gd","scripts/native_surface_model.gd","scripts/native_landing_trial.gd","tests/test_native_return_descent.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESCENT_REPORT.get_base_dir()));var file:=FileAccess.open(DESCENT_REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":sources,"evidence":descent_evidence,"scope":"Actual source20km departure and continuous inverse transfer, powered full return descent with real source gear/fuel/thermal/HP and accepted F576/F575 parked contact; high/low strict cold continuation, typed guidance and real exhausted-positive-nozzle guards. Bounded host controller, not complete original AI, universal terrain or physical Android proof."},"\t"));file.close()
	print("Native return descent: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
