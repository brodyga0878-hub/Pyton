extends "res://tests/test_native_surface_autopilot.gd"
const ASCENT_REPORT:="res://build/current-test-reports/native-surface-ascent.json"
var ascent_evidence:Array=[]
func parked_ascent(target:float=1000.0)->Dictionary:
	var row:=fly_contact(true)
	if row.is_empty():return {}
	row.pilot=Pilot.new();var before:=owners(row);var position:Vector3=row.ship.position
	check(row.pilot.configure_ascent(row.ship,row.nav,row.surface,target),"Automatic powered ascent binds to the actual accepted source park")
	check(owners(row)==before and row.ship.position==position and row.surface.landed,"Requesting automatic ascent changes no phone/source pose, parked state, fuel or clock")
	check(row.pilot.is_active() and row.pilot.mode()=="ascent" and row.pilot.phase()=="launch","A powered ascent request is an active separate launch guidance phase")
	return row
func fly_ascent(target:float,dt:float)->Dictionary:
	var row:=parked_ascent(target);if row.is_empty():return {}
	var initial_hull:float=row.ship.hull;var source_park:Vector3=row.ship.position;var retracted:=false;var powered:=false;var intervals:=0;var max_jump:=0.0
	var before_days:float=row.nav.elapsed_days;var fuel_before:Dictionary=row.nav.fuel_state(row.ship)
	for index in range(4200):
		var before:=all_owners(row);var previous:Vector3=row.ship.position;var previous_altitude:float=row.surface.altitude(row.ship)
		var result:Dictionary=row.pilot.advance(row.ship,row.nav,row.gear,row.surface,dt)
		if not result.get("ok",false):check(false,"Actual guided ascent accepts its native interval: "+str(result));return {}
		check(all_owners(row)==before,"Automatic ascent prepares actual HP/fuel/gear/time/source response without altering live owners")
		row=accepted(row,result);intervals=index+1
		max_jump=maxf(max_jump,previous.distance_to(row.ship.position))
		check(previous.distance_to(row.ship.position)<40.0*dt+1.0,"Powered ascent advances through bounded actual intervals without a height jump")
		if row.ship.velocity.y>0 and not row.surface.landed:powered=true
		if not row.gear.state().requested_down:
			retracted=true;check(previous_altitude>Pilot.ASCENT_CLEARANCE_M,"Actual gear retraction is requested only after the prior pose clears thirty metres")
		if not row.pilot.is_active():break
	check(powered and row.ship.position.y>source_park.y,"Real positive filtered propulsion frees original parking and creates physical ascent")
	check(retracted and not row.gear.state().requested_down,"Automatic ascent retracts the real source gear after safe clearance")
	check(row.pilot.phase()=="completed" and not row.pilot.is_active() and not row.surface.landed and row.surface.native_session.phase()=="free","Ascent completes in actual free flight rather than faking a new landed pose or orbit")
	check(absf(row.surface.altitude(row.ship)-target)<=Pilot.ASCENT_HEIGHT_TOLERANCE_M and absf(row.ship.velocity.y)<=Pilot.ASCENT_SPEED_TOLERANCE_MPS,"The actual powered controller brakes into its height/velocity tolerance without snapping")
	check(row.ship.hull==initial_hull and row.nav.elapsed_days>before_days and row.nav.fuel_state(row.ship)!=fuel_before,"Real ascent retains source HP and advances the one source clock/fuel owner")
	ascent_evidence.append({"case":"actual_powered_source_ascent","target_render_height_m":target,"seconds":dt,"intervals":intervals,"final_render_height_m":row.surface.altitude(row.ship),"final_vertical_mps":row.ship.velocity.y,"max_observed_step_m":max_jump,"source_generation":row.surface.native_session.generation(),"gear_retracted":retracted,"orbit_claimed":false})
	return row
func cold_ascent_and_guard()->void:
	var warm:=parked_ascent();if warm.is_empty():return
	var cold:=strict_cold(warm)
	for index in range(20):
		var a:Dictionary=warm.pilot.advance(warm.ship,warm.nav,warm.gear,warm.surface,0.1);var b:Dictionary=cold.pilot.advance(cold.ship,cold.nav,cold.gear,cold.surface,0.1)
		check(a.get("ok",false) and b.get("ok",false),"Both warm and cold pending-launch guidance execute actual source intervals")
		if not a.get("ok",false) or not b.get("ok",false):return
		warm=accepted(warm,a);cold=accepted(cold,b)
		check(warm.ship.position==cold.ship.position and warm.ship.velocity==cold.ship.velocity and warm.surface.snapshot()==cold.surface.snapshot() and warm.pilot.snapshot()==cold.pilot.snapshot() and warm.gear.snapshot()==cold.gear.snapshot() and warm.nav.snapshot().source_hyperdrive==cold.nav.snapshot().source_hyperdrive,"Cold parked launch reproduces raw source state, phone pose, gear and HP/fuel/RNG exactly")
	while warm.surface.altitude(warm.ship)<45.0:
		var result:Dictionary=warm.pilot.advance(warm.ship,warm.nav,warm.gear,warm.surface,0.1)
		check(result.get("ok",false),"Actual launch rises through gear-clearance transition")
		if not result.get("ok",false):return
		warm=accepted(warm,result)
	cold=strict_cold(warm)
	for index in range(20):
		var a:Dictionary=warm.pilot.advance(warm.ship,warm.nav,warm.gear,warm.surface,0.1);var b:Dictionary=cold.pilot.advance(cold.ship,cold.nav,cold.gear,cold.surface,0.1)
		check(a.get("ok",false) and b.get("ok",false),"Both warm and cold airborne ascent continue real intervals")
		if not a.get("ok",false) or not b.get("ok",false):return
		warm=accepted(warm,a);cold=accepted(cold,b)
		check(warm.ship.position==cold.ship.position and warm.ship.velocity==cold.ship.velocity and warm.surface.snapshot()==cold.surface.snapshot() and warm.pilot.snapshot()==cold.pilot.snapshot() and warm.gear.snapshot()==cold.gear.snapshot() and warm.nav.snapshot().source_hyperdrive==cold.nav.snapshot().source_hyperdrive,"Cold airborne ascent reproduces raw source state, exact controls, moving gear and HP/fuel/RNG")
	var saved:Dictionary=warm.pilot.snapshot();var invalid:Dictionary=saved.duplicate(true);invalid.target_height_f64_hex=Pilot._float_hex(1e6);invalid=Pilot._sealed(invalid)
	var original:=all_owners(warm)
	check(not Pilot.new().restore(invalid,warm.ship,warm.nav,warm.surface) and all_owners(warm)==original,"Rehashed excessive ascent targets are rejected without touching any owner")
	var cancelled:RefCounted=warm.pilot.fork_runtime();cancelled.cancel("manual_lift")
	check(not cancelled.is_active() and not cancelled.advance(warm.ship,warm.nav,warm.gear,warm.surface,0.1).ok,"Manual input cancels ascent and releases automatic controls")
	ascent_evidence.append({"case":"cold_pending_and_airborne_ascent","exact_compared_intervals":40})
func exhausted_launch()->void:
	var row:=parked_ascent();if row.is_empty():return
	var pose:Vector3=row.ship.position;var saved:Dictionary=row.nav.snapshot();saved.source_hyperdrive.fuel_system.jet_raw_u32=0;saved.source_hyperdrive.fuel_system.disabled_axes_mask_u8=0x15;saved.source_hyperdrive.fuel_system.status_u16=1
	check(row.nav.restore(saved) and row.nav.bind_thermal_ship(row.ship) and row.nav.apply_fuel_availability(row.ship),"Automatic launch guard uses actual exhausted positive source nozzle limits")
	var before:=all_owners(row);var result:Dictionary=row.pilot.advance(row.ship,row.nav,row.gear,row.surface,0.1)
	check(not result.ok and result.reason=="insufficient_vertical_propulsion" and all_owners(row)==before and row.ship.position==pose and row.surface.landed,"An exhausted automatic launch cannot release, teleport or charge parked source state")
	check(not Pilot.new().configure_ascent(row.ship,row.nav,row.surface,1000),"Automatic ascent does not start with unavailable positive propulsion")
	for target:float in [-1.0,0.0,9.0,30001.0,INF,NAN]:check(not Pilot.new().configure_ascent(row.ship,row.nav,row.surface,target) and all_owners(row)==before,"Invalid bounded target never mutates exhausted source state")
func run()->void:
	fly_ascent(1000.0,0.1);fly_ascent(100.0,1.0/60.0);cold_ascent_and_guard();exhausted_launch()
	var sources:Dictionary={}
	for path:String in ["scripts/native_surface_autopilot.gd","scripts/native_landing_trial.gd","scripts/native_surface_model.gd","scripts/source_natural_contact_session.gd","scripts/flight_model.gd","tests/test_native_surface_ascent.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ASCENT_REPORT.get_base_dir()));var report:=FileAccess.open(ASCENT_REPORT,FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":sources,"evidence":ascent_evidence,"scope":"Actual original parked source state, powered filtered ascent, source gear/HP/fuel/time, braking to bounded visible-height target and exact cold continuation. Phone guidance only; height is not an orbit, full original autopilot and physical Android remain unproved."},"\t"));report.close()
	print("Native surface ascent: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
