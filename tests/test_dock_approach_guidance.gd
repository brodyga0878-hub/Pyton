extends "res://tests/test_source_hyperdrive_main.gd"
# Exact existing guard feedback plus actual Main source-station approach,
# opening request, service and launch. Initial outer-point placement is an
# explicit fixture; the approach afterwards is genuinely flown by Main.
const Guidance=preload("res://scripts/dock_approach_guidance.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Geometry=preload("res://scripts/source_station_geometry.gd")
const REPORT:="res://build/current-test-reports/dock-approach-guidance.json"

func feedback_state(ship:RefCounted)->PackedByteArray:
	return var_to_bytes([ship.snapshot(),ship.source_docking_telemetry(),ship._source_basis,ship._source_previous_basis,ship._source_clear_key,ship._source_clear,ship._source_motion_pending,ship.last_notice,ship.autopilot,ship.original_port,ship.station_available])
func source_ship(model:int=80,id:String="cobra")->RefCounted:
	var ship:=Flight.new();ship.ship_id=id;ship.original_port=true;ship.station_available=true
	check(ship.configure_source_station(Geometry.prepare(model),Basis.IDENTITY),"Feedback uses actual source geometry model "+str(model)+" for "+id)
	ship.position=Flight.STATION;ship.velocity=Vector3.ZERO;ship.attitude=Quaternion.IDENTITY;ship.target_speed=0
	return ship
func exact_source_guards()->void:
	check(Guidance.status(null).reason=="invalid_state" and not Guidance.status(null).available,"Missing Flight yields unavailable typed feedback")
	check(Guidance.status(RefCounted.new()).reason=="invalid_state","An unrelated RefCounted cannot masquerade as Flight")
	for model:int in Geometry.MODELS:
		for id:String in ["cobra","eagle","shuttle"]:
			var ship:=source_ship(model,id);var before:=feedback_state(ship);var info:Dictionary=Guidance.status(ship)
			check(info.policy==Guidance.POLICY and info.source and info.available and info.ready and ship.can_dock(),"Exact legitimate source interior is reported ready "+str(model)+"/"+id)
			check(feedback_state(ship)==before,"Reading source docking feedback changes no owner, rates, controls or clearance cache")
	var ship:=source_ship()
	ship.position+=Vector3.BACK*80.0
	check(ship.position.distance_to(Flight.STATION)<100 and not ship.can_dock() and Guidance.status(ship).reason=="outside_capture","Being inside the old100m sphere does not grant capture at a source station")
	ship.position=Flight.STATION+Vector3.BACK*8.0
	check(ship.can_dock() and Guidance.status(ship).ready,"The actual inclusive source eight-metre axial boundary remains ready")
	ship.position=Flight.STATION+Vector3.BACK*8.0003
	check(not ship.can_dock() and Guidance.status(ship).reason=="outside_capture","A value displayed as8.0m still rejects when its actual axial position exceeds8m")
	ship.position=Flight.STATION;ship.velocity=Vector3(0,0,-12)
	check(Guidance.status(ship).ready and ship.can_dock(),"The exact existing12m/s source limit remains inclusive")
	ship.velocity=Vector3(0,0,-12.0001)
	check(Guidance.status(ship).reason=="relative_speed" and not ship.can_dock(),"A speed rounded to12.00 in the UI cannot bypass the physical guard")
	ship.velocity=Vector3.ZERO;ship.attitude=Quaternion(Vector3.UP,0.5)
	check(Guidance.status(ship).reason=="heading" and not ship.can_dock(),"Source nose misalignment has an exact heading reason")
	ship.attitude=Quaternion(Vector3.FORWARD,0.5)
	check(Guidance.status(ship).reason=="roll" and not ship.can_dock(),"Source roll misalignment is distinguished from heading")
	ship.attitude=Quaternion.IDENTITY;var bay:AABB=ship._source_station.dock_bay
	ship.position=Flight.STATION+Vector3(minf(-bay.position.x,bay.end.x),0,0)
	check(Guidance.status(ship).reason=="hull_clearance" and not ship.can_dock(),"Actual fitted hull clearance controls lateral bay feedback")
	ship.position=Flight.STATION;check(ship.configure_source_station(Geometry.prepare(80,0,65535),Basis.IDENTITY),"Closed-door control uses actual newly compiled source solids")
	var before:=feedback_state(ship);var info:Dictionary=Guidance.status(ship)
	check(info.reason=="door_closed" and info.can_request_clearance and not info.door_open and not info.ready and not ship.can_dock(),"Closed physical door is reported as a request rather than fabricated permission")
	check(feedback_state(ship)==before,"Closed-door feedback cannot open the aperture or begin motion")
	ship=source_ship();ship.position+=Vector3(5,0,0)
	var basis:=Basis(Vector3.BACK,0.5);check(ship.configure_source_station(Geometry.prepare(80),basis,0.05),"Timed source orientation supplies actual sampled omega")
	ship.attitude=basis.get_rotation_quaternion();ship.velocity=ship._source_angular_velocity.cross(ship.position-Flight.STATION)
	info=Guidance.status(ship)
	check(ship.velocity.length()>12 and info.relative_speed_mps<0.00001 and info.ready and ship.can_dock(),"Feedback subtracts omega cross radius: world speed alone cannot reject a matching rotating bay")
	check(info.rate_sample_valid and info.station_angular_velocity_world_rad_s.length()>0,"Feedback distinguishes a genuine measured station rate from cold configuration")
	ship.velocity+=basis*Vector3(0,0,-12.0001)
	check(Guidance.status(ship).reason=="relative_speed" and not ship.can_dock(),"The same actual rotating frame rejects excessive relative speed")
	ship=source_ship();ship.station_available=false
	check(not Guidance.status(ship).available and not Guidance.status(ship).can_request_clearance,"A retained geometry pack cannot create station availability")
	ship.station_available=true;ship.surface_mode=true
	check(Guidance.status(ship).reason=="surface" and not Guidance.status(ship).ready,"A natural surface is never reported as a dock")
	ship.surface_mode=false;ship.combat_active=true
	check(Guidance.status(ship).reason=="combat","Combat keeps existing docking unavailability")
	ship.combat_active=false;ship.hull=0
	check(Guidance.status(ship).reason=="destroyed","A lost hull cannot acquire docking permission")
	ship=source_ship();check(ship.dock(),"Docked feedback control is accepted by the real physical guard")
	check(Guidance.status(ship).reason=="docked" and not Guidance.status(ship).ready and not Guidance.status(ship).can_request_clearance,"Accepted dock state points to services without exposing another capture request")
	ship=source_ship();ship._source_basis=Basis.IDENTITY.scaled(Vector3(2,1,1))
	check(Guidance.status(ship).reason=="invalid_state" and not Guidance.status(ship).available,"Corrupted station basis cannot display default metrics as verified")
	evidence.append({"case":"readonly_exact_source_guard_feedback","models":Array(Geometry.MODELS),"supported_hulls":["cobra","eagle","shuttle"],"old100m_rejected":true,"rounded_display_never_authoritative":true,"rotating_relative_speed_used":true})

func legacy_boundaries()->void:
	var ship:=Flight.new();ship.position=Flight.STATION+Vector3.BACK*100;ship.velocity=Vector3(0,0,-12)
	var before:=feedback_state(ship);var info:Dictionary=Guidance.status(ship)
	check(not info.source and info.available and info.ready and ship.can_dock(),"Legacy training fallback preserves exact inclusive100m/12mps contract")
	check(feedback_state(ship)==before,"Legacy feedback is read-only")
	ship.position=Flight.STATION+Vector3.BACK*100.001
	check(Guidance.status(ship).reason=="distance" and not ship.can_dock(),"Legacy distance remains authoritative immediately beyond100m")
	ship.position=Flight.STATION;ship.velocity=Vector3(0,0,-12.001)
	check(Guidance.status(ship).reason=="relative_speed" and not ship.can_dock(),"Legacy speed remains authoritative immediately beyond12mps")
	ship.station_available=false
	check(not Guidance.status(ship).available and not Guidance.status(ship).ready,"Legacy unavailable context stays unavailable")
	evidence.append({"case":"legacy100m12mps_unchanged"})

func source_outer_fixture()->bool:
	fresh();game.settings.orbital_gravity=false;game.active=true
	var port:Dictionary={}
	for row:Dictionary in game.world.settlements:
		if int(row.type_code) in [32,33,34]:port=row;break
	check(not port.is_empty(),"Actual source Solar world supplies a real orbital station")
	if port.is_empty():return false
	game.world.focus_id=str(port.parent);game.world.selected_id=str(port.parent);game.world.site_id=str(port.id);game._apply_system()
	var basis:Basis=game.world.source_station_basis(game.nav.elapsed_days)
	game.ship.position=Flight.STATION+basis*Vector3(game.ship._source_station.approach_waypoint)
	game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0;game.ship.attitude=basis.get_rotation_quaternion();game.ship.assisted=true;game.ship.autopilot=false
	game._refresh_hud()
	check(game._station_here() and game.ship.has_source_station() and game.ship.station_available and not game._native_trial_active(),"A labelled source outer-point placement derives its actual station context without enabling any trial port")
	return game.ship.has_source_station()

func main_open_approach_service_launch()->void:
	if not await source_outer_fixture():return
	var state_before:=state();var old_owners:=identities()
	game._show_docking_guidance();await frame()
	check(game.menu.visible and game.menu_title.text=="ПОДХОД К ДОКУ","Actual Main opens the new station approach window")
	check(state()==state_before and identities()==old_owners,"Opening guidance changes no physical pose, source fuel/HP/time or owner identity")
	var days:float=game.nav.elapsed_days;game._advance_controls(5)
	check(game.nav.elapsed_days==days,"The actual guidance modal pauses the station and flight clock")
	game._close_menu()
	var world_state:Dictionary=game.world.station_state_by_site[game.world.site_id]
	world_state.door_u16=65535;world_state.status_u8=0;game._apply_system()
	check(Guidance.status(game.ship).reason=="door_closed","Actual Main receives a labelled fully closed source-door fixture")
	game._dock_action();await frame()
	check(game.menu.visible and game.menu_title.text=="ПОДХОД К ДОКУ" and not game.notice.text.contains("дистанция до 100"),"Rejected real source docking opens correct interior/door guidance instead of the obsolete100m rule")
	game._close_menu();game._toggle_pause();var paused:=state()
	check(not game._request_dock_clearance() and state()==paused,"The actual clearance action cannot alter door permission, pose or clocks while paused")
	game._toggle_pause();var before_pose:Vector3=game.ship.position;var before_velocity:Vector3=game.ship.velocity;days=game.nav.elapsed_days
	var before_nav:Dictionary=game.nav.snapshot();var before_flight:Dictionary=game.ship.snapshot()
	check(game._request_dock_clearance(),"Actual Main requests opening from the selected persistent source station")
	check(game.world.station_state_by_site[game.world.site_id].status_u8==254 and game.world.station_state_by_site[game.world.site_id].door_u16==65535,"A request arms the source door scheduler without instantly opening it")
	check(game.ship.position==before_pose and game.ship.velocity==before_velocity and game.nav.elapsed_days==days and game.ship.snapshot()==before_flight and game.nav.snapshot()==before_nav,"Opening request neither teleports the ship nor spends an interval of fuel, HP or time")
	game._show_docking_guidance();game._advance_controls(5)
	check(game.world.station_state_by_site[game.world.site_id].door_u16==65535 and game.nav.elapsed_days==days,"Requested source door remains frozen while its guidance window is open")
	game._close_menu();game._toggle_auto()
	check(game.ship.autopilot and not game.ship.docked,"Existing actual Auto begins a physical approach after the opening request")
	var iterations:=0;var measured_spin:=false;var opened:=false;var safe:=true;var approach_start:Vector3=game.ship.position
	for index in range(5000):
		game._tick(0.1,Vector2.ZERO,0);iterations=index+1
		var info:Dictionary=Guidance.status(game.ship)
		measured_spin=measured_spin or info.station_angular_velocity_world_rad_s.length()>0.000001
		opened=opened or bool(info.door_open)
		if game.ship.hull!=100 or not game.source_contact_error.is_empty():safe=false;break
		if game.ship.docked:break
	check(opened and measured_spin,"Actual Main advances the requested source door and original station orientation during the approach")
	check(safe and game.ship.docked and game.ship.hull==100,"Actual Main flies through the rotating source aperture into a healthy accepted dock")
	if not game.ship.docked:
		evidence.append({"case":"actual_Main_source_dock_failed","iterations":iterations,"guidance":str(Guidance.status(game.ship)),"phase":game.ship._source_pilot_phase});return
	check(game.ship.position==Flight.STATION and game.ship.position.distance_to(approach_start)>100 and game.ship.velocity==Vector3.ZERO,"The accepted source capture follows a flown approach from the outer point")
	var dock_payload:Dictionary=copied(payload())
	check(not game._decode_state(dock_payload).is_empty(),"The actual docked source pose, equipment and station clock validate in the whole-game cold factory")
	game._show_services(false);await frame()
	check(game.menu.visible and game.hyperdrive_services_view!=null,"A legitimately captured source dock opens its real equipment and fuel service UI")
	var button:Button=game.hyperdrive_services_view.buttons.get("install_fuel_equipment:atmospheric_shielding",null)
	check(button!=null and not button.disabled,"A real source dock quotes an available atmospheric protection purchase")
	var credits:int=game.ship.credits
	if button!=null and not button.disabled:
		var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame();await tap(button,721)
	var fuel_system:Dictionary=game.nav.snapshot().source_hyperdrive.fuel_system
	check(bool(fuel_system.atmospheric_shielding_installed) and game.ship.credits==credits-100,"Actual routed service touch installs protection once and charges the quoted100credits")
	game._close_menu();var departure_position:Vector3=game.ship.position;days=game.nav.elapsed_days
	game._dock_action()
	check(not game.ship.docked and game.ship.position==departure_position and game.ship.velocity.length()>0 and game.nav.elapsed_days==days,"The actual source launch command begins outward flight through the aperture without moving the ship outside or spending time")
	for index in range(400):game._tick(0.1,Vector2.ZERO,0)
	var relative:Vector3=game.world.source_station_basis(game.nav.elapsed_days).transposed()*(game.ship.position-Flight.STATION)
	check(not game.ship.docked and game.ship.hull==100 and relative.z>250,"The real departure continues safely out of the rotating station")
	check(not game._payload().is_empty() and not game._decode_state(copied(payload())).is_empty(),"Post-service departure remains a cold-loadable ordinary source flight")
	evidence.append({"case":"actual_Main_requested_door_rotating_approach_dock_service_departure","labelled_initial_outer_point_placement":true,"source_station_id":str(game.world.site_id),"approach_intervals":iterations,"seconds_per_interval":0.1,"measured_original_spin":measured_spin,"source_door_scheduler_opened":opened,"real_equipment_purchase_credits":credits-game.ship.credits,"remaining_hull":game.ship.hull,"departure_axis_m":relative.z,"separate_native_trial_not_attached":true})

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	exact_source_guards();legacy_boundaries()
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	await main_open_approach_service_launch()
	game.queue_free();await frame();var sources:Dictionary={}
	for name:String in ["scripts/main.gd","scripts/dock_approach_guidance.gd","scripts/flight_model.gd","scripts/source_station_geometry.gd","scripts/source_station_session.gd","scripts/rotating_dock_dynamics.gd","scripts/planetary_system.gd","scripts/navigation.gd","scripts/hyperdrive_services_view.gd","tests/test_dock_approach_guidance.gd"]:sources[name]=FileAccess.get_sha256("res://"+name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"policy":Guidance.POLICY,"checks":checks,"failures":failures,"evidence":evidence,"sources":sources,"scope":"Read-only feedback of the exact retained mobile source dock guard and legacy training guard. Actual Main source opening request, paused modal, measured original spin, physical autopilot approach, legitimate capture, routed paid service and real launch. Initial source outer-point placement and closed-door state are labelled fixtures. This does not attach the separate native surface/orbit trial to a station, reconstruct original F597/object-bank station frames or certify physical Android/FPS."},"\t"))
	print("Dock approach guidance: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
