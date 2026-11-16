extends "res://tests/test_native_landing_trial_integration.gd"
const Pilot=preload("res://scripts/native_surface_autopilot.gd")
const AUTO_REPORT:="res://build/current-test-reports/native-surface-autopilot.json"
var auto_evidence:Array=[]
func with_pilot(down:bool)->Dictionary:
	var row:=fixture(down);var pilot:=Pilot.new()
	check(pilot.configure_land(row.ship,row.nav,row.surface),"A source guidance session attaches to the actual native Earth fifty-metre entry")
	row.pilot=pilot;return row
func accepted(row:Dictionary,result:Dictionary)->Dictionary:
	var next:=apply(row,result);next.pilot=result.candidate_pilot;return next
func all_owners(row:Dictionary)->PackedByteArray:return var_to_bytes([owners(row),row.pilot.snapshot()])
func fly_guided(down:bool,dt:float,tilted:bool=false)->Dictionary:
	var row:=with_pilot(down)
	if tilted:
		var turn:=Trial.prepare(row.ship,row.nav,row.gear,row.surface,0.8,Vector2(0,0.4),0.4)
		check(turn.get("ok",false),"The tilted test starts through a real native manual angular-control interval")
		if not turn.get("ok",false):return {}
		row=apply(row,turn);row.pilot=Pilot.new()
		check(row.pilot.configure_land(row.ship,row.nav,row.surface),"Guidance attaches to the actually flown tilted source frame")
		check(acos(clampf(Basis(row.ship.attitude).y.dot(Vector3.UP),-1,1))>Pilot.MAX_LEVEL_ERROR_RAD,"Actual manual steering creates a tilt outside the conservative approach cone")
	var start:Vector3=row.ship.position;var initial_hull:float=row.ship.hull
	var start_fuel:Dictionary=row.nav.fuel_state(row.ship);var gear_wait:=false;var align_wait:=false;var intervals:=0;var last:Dictionary={}
	for index in range(2400):
		var before:=all_owners(row);var result:Dictionary=row.pilot.advance(row.ship,row.nav,row.gear,row.surface,dt)
		if not result.get("ok",false):check(false,"Actual guided descent accepts its bounded native interval: "+str(result));return {}
		check(all_owners(row)==before,"Guidance preparation preserves all live source/phone/gear/world/pilot owners")
		if result.guidance.phase=="gear":gear_wait=true
		if result.guidance.phase=="align":align_wait=true
		row=accepted(row,result);intervals=index+1;last=result
		if not row.pilot.is_active():break
	check(row.surface.landed and row.surface.native_session.phase()=="parked" and last.stage.landing_accepted,"Autoland completes only on the actual F575 accepted original park")
	check(not row.pilot.is_active() and row.pilot.phase()=="completed" and row.pilot.snapshot().is_empty(),"Completed guidance stops and does not serialize an active request")
	check(row.ship.hull==initial_hull and last.damage.contact_damage.applied_calls==0,"Guidance descent applies no invented damage and retains the real shared HP owner")
	check(row.ship.position.y<start.y and row.ship.velocity==Vector3.ZERO and row.gear.state().deployed,"Guidance physically descends and parks with the real original gear fully deployed")
	check(down or gear_wait,"Initially retracted gear uses a real guided waiting phase")
	check(not tilted or align_wait,"A genuinely tilted source ship levels through actual steering/roll before descent")
	check(row.nav.elapsed_days>0 and row.nav.fuel_state(row.ship)!=start_fuel,"Actual guidance intervals advance the one clock and consume actual hovering/descent propulsion")
	auto_evidence.append({"case":"actual_guided_descent","initial_gear_down":down,"initial_manual_tilt":tilted,"seconds":dt,"intervals":intervals,"elapsed_days":row.nav.elapsed_days,"source_generation":row.surface.native_session.generation(),"final_hull":row.ship.hull,"park_pose":str(row.ship.position),"render_agl":row.surface.altitude(row.ship),"gear_wait_observed":gear_wait,"angular_alignment_observed":align_wait})
	return row
func strict_cold(row:Dictionary)->Dictionary:
	var ship:=Ship.new();var nav:=Nav.new();var gear:=Gear.new();var surface:=NativeSurface.new();var pilot:=Pilot.new()
	check(ship.restore(JSON.parse_string(JSON.stringify(row.ship.snapshot()))),"Guided cold ship uses the actual Flight decoder")
	check(nav.restore(JSON.parse_string(JSON.stringify(row.nav.snapshot()))) and nav.bind_thermal_ship(ship),"Guided cold navigation retains actual source HP/fuel/RNG")
	check(gear.restore(JSON.parse_string(JSON.stringify(row.gear.snapshot()))),"Guided cold gear retains its real phase")
	check(surface.restore(JSON.parse_string(JSON.stringify(row.surface.snapshot())),ship,row.world),"Guided cold surface replays the real source/native witnesses")
	nav.elapsed_days=surface._source_days
	check(pilot.restore(JSON.parse_string(JSON.stringify(row.pilot.snapshot())),ship,nav,surface),"Guidance cold session binds to the exact validated source/phone/clock state")
	return {"ship":ship,"nav":nav,"gear":gear,"surface":surface,"world":row.world,"pilot":pilot}
func cold_continuation_and_guards()->void:
	var row:=with_pilot(false)
	for index in range(43):
		var result:Dictionary=row.pilot.advance(row.ship,row.nav,row.gear,row.surface,0.1)
		check(result.get("ok",false),"Pre-cold guidance flies an actual source interval")
		if not result.get("ok",false):return
		row=accepted(row,result)
	var cold:=strict_cold(row)
	for index in range(24):
		var warm_next:Dictionary=row.pilot.advance(row.ship,row.nav,row.gear,row.surface,0.1);var cold_next:Dictionary=cold.pilot.advance(cold.ship,cold.nav,cold.gear,cold.surface,0.1)
		check(warm_next.get("ok",false) and cold_next.get("ok",false),"Both warm and restored guidance continue through actual native contact control")
		if not warm_next.get("ok",false) or not cold_next.get("ok",false):return
		row=accepted(row,warm_next);cold=accepted(cold,cold_next)
		check(row.ship.position==cold.ship.position and row.ship.velocity==cold.ship.velocity and row.ship.attitude==cold.ship.attitude and row.surface.snapshot()==cold.surface.snapshot() and row.pilot.snapshot()==cold.pilot.snapshot() and row.nav.snapshot().source_hyperdrive==cold.nav.snapshot().source_hyperdrive and row.gear.snapshot()==cold.gear.snapshot(),"Cold guidance reproduces every following actual source/HP/fuel/gear/control interval exactly")
	var original:=all_owners(row);var saved:Dictionary=row.pilot.snapshot();var invalid:Dictionary=saved.duplicate(true)
	invalid.binding.source_generation=int(invalid.binding.source_generation)+1;invalid=Pilot._sealed(invalid)
	check(not Pilot.new().restore(invalid,row.ship,row.nav,row.surface) and all_owners(row)==original,"Rehashed stale source generation cannot attach a pilot to unrelated live contact history")
	invalid=saved.duplicate(true);invalid.binding.phone_pose_f32_hex="00".repeat(40);invalid=Pilot._sealed(invalid)
	check(not Pilot.new().restore(invalid,row.ship,row.nav,row.surface) and all_owners(row)==original,"Rehashed foreign phone pose cannot attach a pilot to current source history")
	var failure:Dictionary=row.pilot.advance(row.ship,row.nav,row.gear,row.surface,NAN)
	check(not failure.ok and all_owners(row)==original,"Rejected guidance interval changes no source or phone owner")
	var cancelled:RefCounted=row.pilot.fork_runtime();cancelled.cancel("manual_input")
	check(not cancelled.is_active() and cancelled.snapshot().is_empty() and not cancelled.advance(row.ship,row.nav,row.gear,row.surface,0.1).ok,"Manual cancellation releases guidance and cannot issue another interval")
	auto_evidence.append({"case":"warm_cold_continuation_and_stale_binding_guards","compared_intervals":24,"raw_source_history_preserved":true})
func insufficient_fuel_guard()->void:
	var row:=with_pilot(true);var state:Dictionary=row.nav.snapshot();state.source_hyperdrive.fuel_system.jet_raw_u32=0;state.source_hyperdrive.fuel_system.disabled_axes_mask_u8=0x15;state.source_hyperdrive.fuel_system.status_u16=1
	check(row.nav.restore(state) and row.nav.bind_thermal_ship(row.ship) and row.nav.apply_fuel_availability(row.ship),"Guard fixture uses the real exhausted positive-nozzle state")
	var before:=all_owners(row);var result:Dictionary=row.pilot.advance(row.ship,row.nav,row.gear,row.surface,0.1)
	check(not result.ok and result.reason=="insufficient_vertical_propulsion" and all_owners(row)==before,"Autoland does not fabricate unavailable upward braking or mutate an exhausted source owner")
	check(not Pilot.new().configure_land(row.ship,row.nav,row.surface),"An exhausted aircraft cannot start guided hovering")
func fatal_contact_commits()->void:
	var row:=fixture(false)
	for index in range(80):
		if row.surface.altitude(row.ship)<4.0:break
		var manual:=Trial.prepare(row.ship,row.nav,row.gear,row.surface,0.1)
		check(manual.get("ok",false),"Fatal fixture approaches ground using actual gear-up free-fall intervals")
		if not manual.get("ok",false):return
		row=apply(row,manual)
	check(not row.surface.landed and row.surface.altitude(row.ship)<4.0 and row.ship.velocity.y<(-10),"Fatal fixture is a genuinely descending native source ship with insufficient stopping distance")
	row.ship.hull=1.0
	check(row.nav.sync_thermal_ship(row.ship),"Fatal fixture uses the actual raw HP synchronizer for one-percent surviving hull")
	row.pilot=Pilot.new();check(row.pilot.configure_land(row.ship,row.nav,row.surface),"A live low-hull source ship can request emergency guidance")
	var terminal:Dictionary={}
	for index in range(12):
		var before:=all_owners(row);var result:Dictionary=row.pilot.advance(row.ship,row.nav,row.gear,row.surface,0.1)
		check(result.get("ok",false),"A genuine terminal source-contact interval remains a successful atomic publication")
		if not result.get("ok",false):return
		check(all_owners(row)==before,"Terminal guidance preparation does not mutate original HP/fuel/phone/gear owners")
		row=accepted(row,result)
		if result.destruction_requested:terminal=result;break
	check(not terminal.is_empty() and row.ship.hull==0 and not row.pilot.is_active() and row.pilot.phase()=="cancelled","Actual unsafe source contact destroys the private ship and stops guidance without rolling HP back")
	if not terminal.is_empty():
		check(terminal.damage.contact_damage.applied_calls>0 and terminal.fuel.reason=="source_caller_stopped_after_contact_destruction","True fatal F953 damage commits once and preserves the existing stop-before-fuel caller policy")
		auto_evidence.append({"case":"actual_emergency_fatal_source_contact_committed","source_generation":row.surface.native_session.generation(),"damage_calls":terminal.stage.damage_calls,"hull":row.ship.hull,"pilot_phase":row.pilot.phase()})
func run()->void:
	fly_guided(false,0.1);fly_guided(true,1.0/60.0);fly_guided(true,0.1,true);cold_continuation_and_guards();insufficient_fuel_guard();fatal_contact_commits()
	var sources:Dictionary={}
	for path:String in ["scripts/native_surface_autopilot.gd","scripts/native_landing_trial.gd","scripts/native_surface_model.gd","scripts/source_natural_contact_session.gd","scripts/flight_model.gd","tests/test_native_surface_autopilot.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUTO_REPORT.get_base_dir()));var report:=FileAccess.open(AUTO_REPORT,FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":sources,"evidence":auto_evidence,"scope":"Actual native Earth guided descent at0.1s/60Hz, original contact/gear/HP/fuel/time, pure owner publication and strict cold continuation; bounded phone guidance, not the original complete autopilot or physical Android."},"\t"));report.close()
	print("Native surface autopilot: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
