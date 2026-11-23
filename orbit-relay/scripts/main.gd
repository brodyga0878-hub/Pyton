extends Node

const Flight = preload("res://scripts/flight_sim.gd")
const FlightView = preload("res://scripts/flight_view.gd")
const FlightCamera = preload("res://scripts/flight_camera.gd")
const FlightText = preload("res://scripts/flight_text.gd")
const FlightAudio = preload("res://scripts/flight_audio.gd")
const FlightHUD = preload("res://scripts/flight_hud.gd")
const CockpitContacts = preload("res://scripts/cockpit_contacts.gd")
const SectorMap = preload("res://scripts/sector_map.gd")
const GalaxyMap = preload("res://scripts/galaxy_map.gd")
const PortServices = preload("res://scripts/port_services.gd")
const PortMarket = preload("res://scripts/port_market.gd")
const DisplaySettings = preload("res://scripts/display_settings.gd")
const PresentationMenu = preload("res://scripts/presentation_menu.gd")
const MissionJournal = preload("res://scripts/mission_journal.gd")
const ExpansionBoard = preload("res://scripts/expansion_board.gd")
const ReconPanel = preload("res://scripts/recon_panel.gd")
const OperationsPanel = preload("res://scripts/operations_panel.gd")
const FlightCommsView = preload("res://scripts/flight_comms_view.gd")
const SessionIO = preload("res://scripts/session_io.gd")
const VoyageMenu = preload("res://scripts/voyage_menu.gd")
const VoyageLibrary = preload("res://scripts/voyage_library.gd")
const VoyageImport = preload("res://scripts/voyage_import.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const SAVE_INTERVAL := 8.0
const ANTIALIASING := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
const REPORT_JOURNAL_ONLY := "В ZIP только журнал и сведения о версии. Состояние рейса недоступно."

@export var show_voyage_menu_on_launch := false

var flight := Flight.new()
var presentation := DisplaySettings.new()
var _view := FlightView.new()
var _audio := FlightAudio.new()
var _camera_mode := FlightCamera.Mode.EXTERIOR
var _hud := FlightHUD.new()
var _map := SectorMap.new()
var _galaxy := GalaxyMap.new()
var _services := PortServices.new()
var _market := PortMarket.new()
var _settings := PresentationMenu.new()
var _journal := MissionJournal.new()
var _frontier := ExpansionBoard.new()
var _recon := ReconPanel.new()
var _operations_panel := OperationsPanel.new()
var _comms := FlightCommsView.new()
var _voyages := VoyageMenu.new()
var _voyage_picker: FileDialog
var _flight_active := false
var _io := SessionIO.new()
var _save_elapsed := 0.0
var _save_error_shown := false
var _preserve_backup_on_next_save := false
var _report: CenterContainer
var _report_text: Label
var _report_buttons: Array[Button] = []
var _report_touches: Dictionary[int, Button] = {}
var _report_sharing := false


func _ready() -> void:
	presentation.load_preferences()
	FlightText.set_language(presentation.language)
	_flight_active = not show_voyage_menu_on_launch
	var loaded := SessionIO.LoadResult.NO_SAVE
	if _flight_active:
		loaded = SessionIO.load_valid_state(SessionIO.SAVE_PATH, flight.restore)
	_preserve_backup_on_next_save = loaded == SessionIO.LoadResult.BACKUP
	if loaded != SessionIO.LoadResult.NO_SAVE:
		_io.trace("load", {"accepted": loaded != SessionIO.LoadResult.INVALID, "backup": _preserve_backup_on_next_save})
	add_child(_audio)
	add_child(_view)
	_view.build()
	add_child(_hud)
	_hud.build()
	_hud.action_requested.connect(_handle_action)
	_hud.frame_requested.connect(_handle_action.bind("frame"))
	_hud.navigation_requested.connect(_select_cockpit_target)
	_hud.combat_target_requested.connect(_select_cockpit_contact)
	add_child(_map)
	_map.build()
	_map.destination_selected.connect(_select_destination)
	_map.orbit_requested.connect(_map_orbit_action)
	_map.rendezvous_requested.connect(_map_rendezvous_action)
	_map.rendezvous_finish_requested.connect(_map_rendezvous_finish)
	_map.survey_requested.connect(_map_survey)
	_map.frame_selected.connect(_map_frame)
	_map.frame_rotation_selected.connect(_map_frame.bind(true))
	_map.dismissed.connect(_close_map)
	add_child(_galaxy)
	_galaxy.build()
	_galaxy.destination_selected.connect(_plan_jump)
	_galaxy.jump_requested.connect(_start_jump)
	_galaxy.emergency_jump_requested.connect(_start_jump.bind(true))
	_galaxy.hyperspace_track_requested.connect(_target_hyperspace_trail)
	_galaxy.hyperspace_analysis_requested.connect(_analyze_hyperspace_trail)
	_galaxy.route_cancel_requested.connect(_cancel_jump_route)
	_galaxy.galaxy_scan_requested.connect(_galaxy_scan)
	_galaxy.dismissed.connect(_close_galaxy)
	add_child(_services)
	_services.build()
	_services.service_requested.connect(_service_purchase)
	_services.missile_selected.connect(_select_missile)
	_services.transfer_requested.connect(_fuel_transfer)
	_services.fuel_module_removed.connect(_remove_fuel_module)
	_services.pump_mode_requested.connect(_set_pump_mode)
	_services.drive_selected.connect(_select_drive)
	_services.weapon_selected.connect(_select_weapon)
	_services.jettison_requested.connect(_jettison_cargo)
	_services.cargo_pod_requested.connect(_cargo_pod_action)
	_services.crew_requested.connect(_crew_action)
	_services.ship_exchange_requested.connect(_ship_exchange)
	_services.ship_yard_requested.connect(_ship_yard_action)
	_services.customs_payment_requested.connect(_customs_pay)
	_services.law_radio_requested.connect(_open_law_radio)
	_services.dismissed.connect(_close_services)
	add_child(_market)
	_market.build()
	_market.trade_requested.connect(_market_trade)
	_market.courier_requested.connect(_accept_courier)
	_market.passenger_requested.connect(_passenger_action)
	_market.dismissed.connect(_close_market)
	add_child(_settings)
	_settings.build()
	_settings.preference_requested.connect(_change_preference)
	_settings.dismissed.connect(_close_settings)
	_settings.voyages_requested.connect(_open_voyages_from_settings)
	add_child(_journal)
	_journal.build()
	_journal.follow_requested.connect(_follow_journal)
	_journal.career_requested.connect(_career_dispatch)
	_journal.story_requested.connect(_story_action)
	_journal.operations_requested.connect(_open_operations)
	_journal.rig_selected.connect(_select_rig_slot)
	_journal.subscription_requested.connect(_subscribe_news)
	_journal.calendar_wait_requested.connect(_calendar_wait)
	_journal.dismissed.connect(_close_journal)
	add_child(_frontier)
	_frontier.build()
	_frontier.project_requested.connect(_project_action)
	_frontier.convoy_requested.connect(_convoy_action)
	_frontier.search_requested.connect(_search_action)
	_frontier.dismissed.connect(_close_frontier)
	add_child(_recon)
	_recon.build()
	_recon.action_requested.connect(_recon_action)
	_recon.dismissed.connect(_close_recon)
	add_child(_operations_panel)
	_operations_panel.build()
	_operations_panel.operation_requested.connect(_operation_action)
	_operations_panel.dismissed.connect(_close_operations)
	add_child(_comms)
	_comms.build()
	_comms.command_requested.connect(_comms_action)
	_comms.dismissed.connect(_close_comms)
	add_child(_voyages)
	_voyages.build()
	_voyages.action_requested.connect(_voyage_action)
	_build_report_panel()
	_apply_presentation()
	_update_display(0.0)
	if show_voyage_menu_on_launch:
		_open_voyages()
		return
	var flight_notice := flight.status_message if not flight.status_event.is_empty() else ""
	_deliver_notice()
	if loaded == SessionIO.LoadResult.BACKUP:
		var message := "Рейс восстановлен из резервной копии."
		if not flight_notice.is_empty():
			message += " " + flight_notice
		_hud.notify(message)
	elif loaded == SessionIO.LoadResult.INVALID:
		_hud.notify("Сохранённый рейс недоступен. Начат новый рейс.")
	_trace_voyage_start()


func _process(delta: float) -> void:
	_audio.advance_music(flight if _flight_active else null, delta)
	_update_display(delta)


func _overlay_open() -> bool:
	return _voyages.is_open() or _report.visible or _map.is_open() or _galaxy.is_open() or _services.is_open() or _market.is_open() or _settings.is_open() or _journal.is_open() or _frontier.is_open() or _recon.is_open() or _operations_panel.is_open() or _comms.is_open()


func _physics_process(delta: float) -> void:
	if not _flight_active or _overlay_open() or flight.time_paused:
		return
	var steering := presentation.pilot_steering(_hud.move_input())
	flight.update(delta, steering, _hud.roll_input(), _hud.boost_held(), _hud.brake_held(), _hud.translation_input())
	if not flight.status_event.is_empty():
		_deliver_notice()
	else:
		var caption := _audio.poll(flight)
		if not caption.is_empty():
			_hud.notify(caption)
			_io.trace("flight_notification", {"message": caption, "orbit_time": flight.orbit_time})
	_save_elapsed += delta
	if _save_elapsed >= SAVE_INTERVAL:
		_save()


func _update_display(delta: float) -> void:
	_view.sync(flight, delta)
	_camera_mode = _view.preferred_camera_mode()
	_hud.sync(flight, delta)
	var combat_lock := flight.combat_lock_contact()
	var final_approach := flight.autopilot and flight.autopilot_phase in ["Стыковка", "Посадка", "Выпуск шасси", "Вход в зону сбора"]
	var marker := flight.target_contact(flight.target) if final_approach else flight.target_gate(flight.target)
	var patrol_status := flight.patrol_status()
	var signal_selected: bool = patrol_status.phase == Flight.Patrol.OUTBOUND and patrol_status.same_system and not flight.autopilot
	if signal_selected:
		marker = patrol_status.point
	var project := flight.frontier_status()
	var project_marker: bool = flight.project_course and project.has_point
	if project_marker:
		marker = project.point
	var convoy := flight.convoy_status()
	var convoy_marker: bool = flight.convoy_course and convoy.has_point
	if convoy_marker:
		marker = convoy.point
	var rendezvous_marker := flight.rendezvous_active
	if rendezvous_marker:
		var rendezvous := flight.rendezvous_status()
		marker = flight.target_position(rendezvous.site) if rendezvous.phase == "hold" else rendezvous.point
	var fragment := flight.orbital_mining.fragment_state(flight.target, flight.orbit_time)
	var fragment_marker := not fragment.is_empty() and not flight.autopilot and not signal_selected and not project_marker and not convoy_marker
	if fragment_marker:
		marker = fragment.position
	var local_traffic := flight.ambient_status()
	var hostile_marker: bool = combat_lock.is_empty() and local_traffic.fire_visible and not flight.autopilot and not signal_selected and not project_marker and not convoy_marker and not rendezvous_marker and not fragment_marker
	if hostile_marker:
		marker = local_traffic.position
	var pod: Dictionary = flight.cargo_pod_status()
	var cargo_marker: bool = pod.active and pod.tracking and not flight.autopilot
	if cargo_marker:
		marker = pod.position
	var echo := flight.hyperspace_trail_status()
	var echo_marker: bool = echo.active and echo.tracking and echo.targetable
	if echo_marker:
		marker = echo.position
	var operation := flight.operation_marker()
	if not operation.is_empty():
		marker = operation.position
	var special_marker := signal_selected or project_marker or convoy_marker or rendezvous_marker or fragment_marker or hostile_marker or cargo_marker or echo_marker or not operation.is_empty()
	var instruments_visible := flight.docked < 0 and not flight.landed and not _overlay_open() and flight.jump_seconds_left <= 0.0
	var forward_aim := _view.shows_forward_aim()
	var bearing := ""
	if instruments_visible and forward_aim and _camera_mode == FlightCamera.Mode.COCKPIT and flight.navigation_computer_fitted:
		var point := marker
		if not special_marker and flight.docking_guidance().get("near", false):
			point = flight.target_contact(flight.target)
		var offset := point - flight.position
		if offset.length_squared() >= 0.25:
			var course := flight.attitude().transposed() * offset.normalized()
			var azimuth := rad_to_deg(atan2(course.x, -course.z))
			var elevation := rad_to_deg(asin(clampf(course.y, -1.0, 1.0)))
			bearing = FlightText.text("NAV_BEARING") % [azimuth, elevation]
	_hud.set_camera_view(_camera_mode, forward_aim, bearing)
	var in_view := instruments_visible and not _view.camera.is_position_behind(marker)
	var patrol_engaged: bool = patrol_status.phase == Flight.Patrol.ENGAGED and patrol_status.same_system
	if patrol_engaged:
		in_view = false
	elif in_view and not flight.autopilot and not special_marker:
		var surface := flight.surface_status()
		in_view = not surface.near or surface.pad
	_hud.set_target_marker(_view.camera.unproject_position(marker) if in_view else Vector2.ZERO, in_view)
	var active_mark := {}
	if instruments_visible and not combat_lock.is_empty():
		var contact_position: Vector3 = combat_lock.position
		if not _view.camera.is_position_behind(contact_position) and flight.combat_line_clear(_view.camera.global_position, contact_position):
			active_mark.screen = _view.camera.unproject_position(contact_position)
	_hud.set_combat_lock(str(combat_lock.get("id", "")), str(combat_lock.get("name", "")), active_mark)
	var markers: Array[Dictionary] = []
	var contacts: Array[Dictionary] = []
	if instruments_visible and (_hud.ship_markers_enabled() or _hud.scanner_is_open()):
		contacts = flight.traffic_contacts()
	if instruments_visible and _hud.ship_markers_enabled():
		var targetable := flight.combat_targetable_contacts()
		for contact: Dictionary in contacts:
			var distance := flight.position.distance_to(contact.position)
			if distance > 1100.0 or _view.camera.is_position_behind(contact.position):
				continue
			var lockable := targetable.has(contact.id) and flight.combat_line_clear(_view.camera.global_position, contact.position)
			markers.append({"screen": _view.camera.unproject_position(contact.position), "role": contact.role,
				"name": contact.name, "distance": distance, "id": contact.id, "lockable": lockable})
	_hud.set_traffic_markers(markers)
	if _hud.scanner_is_open():
		_hud.set_scanner_status(flight.scanner_status(contacts))
	var sites := flight.local_targets()
	_hud.set_navigation_targets(sites, flight.target, flight.navigation_computer_fitted, not flight.missile_camera_record().is_empty())
	var navigation_markers: Array[Dictionary] = []
	if instruments_visible:
		navigation_markers = CockpitContacts.project(flight, _view.camera, sites)
	_hud.set_navigation_markers(navigation_markers)
	var guide := {}
	if instruments_visible and forward_aim and not patrol_engaged and not special_marker \
			and not flight.orbit_maneuver and _hud.navigation_corridor_enabled():
		guide = CockpitContacts.approach_corridor(flight, _view.camera, sites)
	_view.set_navigation_corridor(guide)


func _select_cockpit_target(site: int, from_view: bool) -> void:
	if not _flight_active or _overlay_open() or flight.docked >= 0 or flight.landed or flight.jump_seconds_left > 0.0:
		return
	if not from_view and not flight.navigation_computer_fitted:
		return
	var sites := flight.local_targets()
	if site not in sites or (from_view and not CockpitContacts.is_visible(flight, _view.camera, sites, site)):
		return
	if not flight.select_target(site):
		return
	_io.trace("route_selected", {"target": site, "source": "marker" if from_view else "onboard"})
	_hud.notify("Цель · %s" % flight.target_name(site))
	_save()
	_update_display(0.0)


func _select_cockpit_contact(id: String) -> void:
	if not _flight_active or _overlay_open() or flight.docked >= 0 or flight.landed or flight.jump_seconds_left > 0.0:
		return
	if not flight.select_combat_contact(id):
		_hud.notify("Контакт недоступен для захвата.")
		return
	_deliver_notice()
	_update_display(0.0)


func _handle_action(action: String) -> void:
	if not _flight_active or _overlay_open():
		return
	if action == "voyages":
		_open_voyages()
		return
	if flight.escape_status().active and action not in ["rescue_signal", "time_pause", "report", "settings", "camera"]:
		return
	if flight.jump_seconds_left > 0.0 and action not in ["throttle_up", "throttle_down", "time_pause"]:
		return
	if flight.docked >= 0:
		var departure := flight.departure_status()
		if departure.active and action != "time_pause" and (action != "dock" or not departure.can_cancel):
			return
	var near_target := flight.nearby_pilot_target()
	var throttle_step := 0.025 if near_target else 0.1
	var speed_step := 2.0 if near_target else 10.0
	var previous_speed := flight.speed_hold.snapshot()
	match action:
		"target":
			flight.change_target()
		"autopilot":
			flight.set_autopilot(not flight.autopilot)
		"dock_sync":
			flight.toggle_dock_sync()
		"dock_clearance":
			flight.dock_clearance_action()
		"gear":
			flight.gear_action()
		"flight_assist":
			flight.set_flight_assist(not flight.flight_assist)
		"frame":
			flight.cycle_reference_frame()
		"camera":
			if flight.docked >= 0 or flight.landed:
				return
			_camera_mode = FlightCamera.next_basic(_camera_mode)
			_view.select_camera_mode(_camera_mode)
		"camera_observer":
			if flight.docked < 0 and not flight.landed:
				_view.select_camera_mode(FlightCamera.Mode.OBSERVER)
		"camera_missile":
			if not flight.missile_camera_record().is_empty():
				_view.select_camera_mode(FlightCamera.Mode.MISSILE)
		"speed_hold":
			flight.toggle_speed_hold()
		"orbit_cancel":
			flight.cancel_orbit_maneuver()
		"rendezvous_cancel":
			flight.cancel_rendezvous()
		"rendezvous_finish":
			flight.finish_rendezvous()
		"throttle_up":
			flight.change_speed_pilot_control(throttle_step, speed_step)
		"throttle_down":
			flight.change_speed_pilot_control(-throttle_step, -speed_step)
		"dock":
			flight.dock_action()
		"contract":
			flight.contract_action()
		"patrol":
			flight.patrol_action()
		"convoy":
			flight.convoy_action()
		"fire":
			flight.fire_action()
		"ecm":
			flight.use_ecm()
		"missile_next":
			flight.select_missile_slot(flight.next_missile_slot())
		"missile_fire":
			flight.launch_missile(flight.combat_lock_id())
		"decoy":
			flight.launch_decoy()
		"energy_pulse":
			flight.launch_energy_pulse()
		"rescue_signal":
			flight.request_rescue()
		"rescue_eject":
			flight.eject_escape_pod()
		"mine":
			flight.mine_action()
		"mining_pulse":
			flight.fire_mining_pulse()
		"fragment_collect":
			flight.collect_fragment()
		"rig_deploy":
			flight.leave_remote_rig()
		"rig_unload":
			flight.unload_remote_rig()
		"rig_retrieve":
			flight.retrieve_remote_rig()
		"rig_route":
			flight.track_remote_rig()
		"processor_deploy", "processor_feed", "processor_unload", "processor_retrieve", "processor_route":
			flight.processor_action(action)
		"sell_ore":
			flight.sell_ore_action()
		"scoop":
			flight.scoop_action()
		"time":
			flight.cycle_time_scale()
		"time_pause":
			flight.toggle_time_pause()
		"services":
			if flight.station_services_available():
				_hud.set_input_enabled(false)
				_services.open(flight)
			return
		"fuel":
			_hud.set_input_enabled(false)
			_services.open(flight, true)
			return
		"market":
			if flight.station_services_available():
				_hud.set_input_enabled(false)
				_market.open(flight)
			return
		"map":
			_hud.set_input_enabled(false)
			_map.open(flight)
			return
		"galaxy":
			_hud.set_input_enabled(false)
			_galaxy.open(flight)
			return
		"report":
			_open_report()
			return
		"settings":
			_hud.set_input_enabled(false)
			_settings.open(presentation)
			return
		"journal":
			_hud.set_input_enabled(false)
			_journal.open(flight)
			return
		"frontier":
			_hud.set_input_enabled(false)
			_frontier.open(flight)
			return
		"recon":
			_hud.set_input_enabled(false)
			_recon.open(flight)
			return
		"operations":
			_open_operations()
			return
		"comms":
			var id := _hud.radio_contact_id()
			_open_comms(id if not id.is_empty() else flight.combat_lock_id())
			return
		_:
			return
	if action in ["target", "autopilot", "throttle_up", "throttle_down"]:
		_io.trace(action, {"target": flight.target, "autopilot": flight.autopilot, "throttle": flight.throttle})
	var speed_changed: bool = flight.speed_hold.enabled != previous_speed.enabled or flight.speed_hold.setpoint != previous_speed.setpoint
	var save_without_notice: bool = action == "target" or (speed_changed and flight.status_event.is_empty())
	_deliver_notice()
	if save_without_notice:
		_save()
	_update_display(0.0)


func _deliver_notice() -> void:
	if flight.status_event.is_empty():
		return
	var event := flight.status_event
	var touchdown := flight.landing_direction
	var convoy := flight.convoy_status()
	var trace_fields := {
		"docked": flight.docked, "landed_site": flight.landed_site, "target": flight.target,
		"planned_target": flight.planned_target, "speed": flight.speed(), "credits": flight.credits,
		"mining_phase": flight.mining.phase, "cargo_units": flight.mining.ore_hold,
		"fuel": flight.ship.fuel, "scooping": flight.scooping, "star_heat": flight.star_heat,
		"jump_fuel": flight.ship.jump_fuel, "hydrogen_canisters": flight.mining.cargo_amount("hydrogen"),
		"entry_heat": flight.entry_heat, "heat_shield": flight.ship.heat_shield,
		"gear_extension": flight.gear_extension, "gear_deployed": flight.gear_deployed,
		"flight_assist": flight.flight_assist,
		"speed_hold": flight.speed_hold.snapshot(), "autopilot_fitted": flight.ship.autopilot_fitted,
		"orbit_maneuver": flight.orbit_maneuver, "orbit_maneuver_focus": flight.orbit_maneuver_focus,
		"rendezvous_active": flight.rendezvous_active,
		"hull": flight.ship.hull, "contract_route": flight.contract_route_id, "contract_leg": flight.contract_leg,
		"patrol_phase": flight.patrol.phase, "patrol_origin": flight.patrol.origin,
		"convoy_id": convoy.id, "convoy_order_phase": convoy.phase, "convoy_order_kind": convoy.kind,
		"faction": flight.factions.owner(flight.system_id),
		"system_id": flight.system_id, "jump_target": flight.jump_target,
		"orbit_time": flight.orbit_time, "time_scale": flight.time_scale,
		"offpad": flight.landed_offpad(), "landing_direction": [touchdown.x, touchdown.y, touchdown.z],
	}
	if event in ["dock_request", "dock_ready", "dock_expired", "dock_denied"]:
		var access := flight.dock_access_status(flight.target)
		trace_fields = {
			"port": flight.target, "phase": access.phase, "open_fraction": access.open_fraction,
			"wait_seconds": access.wait, "remaining_seconds": access.remaining, "reason": flight.status_message,
			"system_id": flight.system_id, "orbit_time": flight.orbit_time, "speed": flight.speed(),
		}
	elif event in ["departure_requested", "departure_canceled", "departure_open"]:
		var departure := flight.departure_status()
		trace_fields = {
			"port": flight.docked, "phase": departure.phase, "progress": departure.progress,
			"wait_seconds": departure.wait, "reason": flight.status_message,
			"system_id": flight.system_id, "orbit_time": flight.orbit_time,
		}
	elif event.begins_with("passenger_"):
		var passengers := flight.passenger_status()
		trace_fields = {
			"port": flight.docked, "origin": passengers.origin, "destination": passengers.destination,
			"seats": passengers.seats, "overdue": passengers.overdue, "debt": passengers.debt,
			"credits": flight.credits, "remaining_seconds": passengers.remaining, "reason": flight.status_message,
			"system_id": flight.system_id, "orbit_time": flight.orbit_time,
		}
	elif event.begins_with("crew_") or event == "departure_crew_denied":
		var crew := flight.crew_status()
		trace_fields = {
			"port": flight.docked, "crew": crew.count, "arrears": crew.arrears, "credits": flight.credits,
			"engineer": crew.engineer, "navigator": crew.navigator, "next_due": crew.next_due,
			"hull_id": flight.ship.hull_id, "crew_required": flight.ship.crew_required(),
			"system_id": flight.system_id, "orbit_time": flight.orbit_time, "reason": flight.status_message,
		}
	elif event in ["ship_exchange", "ship_purchased", "ship_switched", "ship_sold"]:
		trace_fields = {
			"port": flight.docked, "hull_id": flight.ship.hull_id, "credits": flight.credits,
			"cargo_capacity": flight.ship.cargo_capacity(), "crew_required": flight.ship.crew_required(),
			"stored_hulls": flight.shipyard_storage().size(),
			"system_id": flight.system_id, "orbit_time": flight.orbit_time, "reason": flight.status_message,
		}
	elif event in ["customs_inspection", "customs_paid"]:
		var customs := flight.customs_status()
		trace_fields = {
			"port": flight.docked, "authority": customs.authority, "unpaid": customs.debt,
			"credits": flight.credits, "system_id": flight.system_id, "orbit_time": flight.orbit_time,
			"notice": customs.notice,
		}
	elif event.begins_with("remote_rig_"):
		var rig := flight.remote_rig_status()
		trace_fields = {
			"site": rig.site, "stored": rig.stored, "reserve": rig.reserve,
			"system_id": flight.system_id, "orbit_time": flight.orbit_time, "landed_site": flight.landed_site,
		}
	elif event in ["mining_pulse", "fragment_collected"]:
		var mining := flight.orbital_mining_status()
		trace_fields = {
			"site": mining.site, "fragment": mining.fragment, "resource": mining.resource,
			"reserve": flight.mining.reserve_at(mining.site), "fuel": flight.ship.fuel,
			"system_id": flight.system_id, "orbit_time": flight.orbit_time,
		}
	elif event in ["time_paused", "time_resumed"]:
		var clock := flight.clock_status()
		trace_fields = {
			"stamp": clock.stamp, "paused": clock.paused, "time_scale": clock.scale,
			"orbit_time": clock.epoch, "system_id": flight.system_id,
		}
	elif event == "jump_committed":
		var transit := flight.jump_progress_status()
		trace_fields = {
			"system_id": flight.system_id, "destination": transit.destination, "fare": transit.fare,
			"emergency": transit.emergency, "requested": transit.requested,
			"game_seconds": transit.duration, "arrival_epoch": transit.arrival_epoch,
			"drive": flight.ship.drive_kind, "fuel_remaining": flight.ship.active_jump_fuel(),
			"military_waste": flight.ship.military_waste,
		}
	elif event == "emergency_jump_arrival":
		trace_fields = {"system_id": flight.system_id, "orbit_time": flight.orbit_time,
			"fault": flight.jump_drive_status().fault, "message": flight.status_message}
	elif event == "reference_frame":
		var frame := flight.frame_status()
		trace_fields = {
			"mode": frame.mode, "reference": frame.reference, "surface": frame.surface,
			"relative_speed": frame.relative_speed, "speed": flight.speed(),
			"system_id": flight.system_id, "orbit_time": flight.orbit_time,
		}
	_io.trace(event, trace_fields)
	_audio.notify(event, Time.get_ticks_msec(), flight.dock_access.port)
	_hud.notify(flight.status_message)
	flight.status_event = ""
	if event in [
		"launch", "dock", "land", "lift", "contract", "delivery", "mining_deploy", "mining_recover",
		"dock_request", "dock_ready", "dock_expired",
		"departure_requested", "departure_canceled", "departure_open", "departure_crew_denied",
		"mining_ready", "mining_loaded", "ore_sold",
		"remote_rig_deployed", "remote_rig_unloaded", "remote_rig_retrieved", "remote_rig_route", "service_refuel", "service_tank", "service_eco",
		"processor_deploy", "processor_feed", "processor_ready", "processor_unload", "processor_retrieve",
		"service_surface_processor", "service_military_drive", "service_military_refuel", "service_military_waste",
		"scoop_full", "scoop_stop", "star_arrival", "gas_arrival", "fuel_empty", "thermal_damage",
		"fuel_transfer", "service_jump_refuel", "cargo_jettisoned", "cargo_pod_targeted", "cargo_pod_collected",
		"berth_bill", "berth_payment", "berth_permit", "civic_donation",
		"fuel_pump_mode", "fuel_pump_transfer", "fuel_module_removed", "service_hydrogen_scoop", "service_fuel_pump",
		"atmosphere_enter", "atmosphere_exit", "atmosphere_damage",
		"gear_deploy", "gear_retract", "gear_ready", "gear_stowed",
		"service_heat_shield", "service_mining_laser", "service_fragment_collector",
		"mining_pulse", "fragment_collected",
		"jump_planned", "jump_committed", "jump_complete", "emergency_jump_arrival", "jump_repaired",
		"hyperspace_analyzer", "route_canceled",
		"service_range_drive", "jump_drive_selected",
		"service_combat_shield", "service_combat_ecm", "service_combat_focus", "service_combat_repair",
		"combat_weapon_selected", "combat_missile", "combat_missile_hit", "combat_ecm",
		"combat_missile_selected", "combat_player_missile", "combat_decoy", "combat_decoy_hit",
		"service_combat_launcher", "service_combat_missile_dart", "service_combat_missile_lance", "service_combat_ecm_advanced", "service_combat_decoy",
		"combat_lock", "combat_lock_clear", "service_radar_mapper",
		"market_buy", "market_sell", "service_repair", "service_cargo", "hull_damage", "contract_leg",
		"passenger_accepted", "passenger_overdue", "passenger_paid", "passenger_late", "passenger_canceled",
		"passenger_debt_paid", "passenger_course",
		"crew_hired", "crew_dismissed", "crew_payroll", "crew_arrears_paid", "ship_exchange",
		"ship_purchased", "ship_switched", "ship_sold",
		"patrol_accepted", "patrol_engaged", "patrol_fire", "patrol_enemy_hit", "patrol_retreat", "patrol_victory", "patrol_paid",
		"expedition_accepted", "expedition_survey", "expedition_report", "expedition_supply", "expedition_complete", "expedition_course",
		"missing_accepted", "missing_clue", "missing_evidence", "missing_boarded", "missing_paid", "missing_expired",
		"missing_disembarked", "missing_course",
		"recon_camera_installed", "recon_accepted", "recon_captured", "recon_paid", "recon_expired", "recon_cancelled", "recon_course",
		"operation_equipment", "operation_progress", "operation_paid", "operation_expired", "operation_hit", "operation_intercepted", "operation_course",
		"law_challenge", "law_pursuit", "law_interdiction", "law_arrest", "law_answer", "law_paid", "law_contest",
		"law_bribe", "law_release", "law_departure_denied", "comms_route", "comms_distress",
		"combat_energy_pulse", "ship_destroyed", "escape_ejected", "rescue_signal", "rescue_complete", "service_combat_energy_pulse",
		"service_combat_maintenance", "service_combat_auto_repair", "combat_auto_repaired",
		"remote_rig_bought", "remote_rig_sold", "remote_rig_selected",
		"war_declared", "war_round", "war_captured", "war_repulsed", "war_convoy_delivered", "war_convoy_intercepted",
		"convoy_order_accepted", "convoy_order_escorted", "convoy_order_failed", "convoy_order_paid",
		"convoy_order_fire", "convoy_order_enemy_hit",
		"ambient_engaged", "ambient_fire", "ambient_enemy_hit", "ambient_victory",
		"career_dispatch_accepted", "career_dispatch_paid", "career_dispatch_expired", "career_dispatch_course",
		"career_order_accepted", "career_order_proved", "career_order_course", "career_order_paid", "career_order_expired", "career_order_removed",
		"story_brief", "story_registry", "story_mirror", "story_collect_key", "story_submit", "story_course",
		"flight_assist", "reference_frame", "time_paused", "time_resumed", "autopilot_equipment", "navigation_computer", "missile_telemetry", "speed_hold_on", "speed_hold_off",
		"survey_record", "galaxy_scan", "customs_inspection", "customs_paid",
		"orbit_start", "orbit_complete", "orbit_abort", "orbit_cancel",
		"rendezvous_start", "rendezvous_hold", "rendezvous_abort", "rendezvous_cancel", "rendezvous_finish",
	]:
		_save()


func _save(keep_backup: bool = false) -> void:
	if not _flight_active:
		return
	_save_elapsed = 0.0
	var result := SessionIO.save_state(flight.snapshot(), SessionIO.SAVE_PATH, keep_backup or _preserve_backup_on_next_save)
	if result == OK and not keep_backup:
		_preserve_backup_on_next_save = false
	if result != OK and not _save_error_shown:
		_hud.notify("Не удалось сохранить рейс.")
		_io.trace("save_error", {"error": int(result)})
	_save_error_shown = result != OK


func _open_voyages_from_settings() -> void:
	_settings.close()
	_open_voyages()


func _open_voyages() -> void:
	var primary_available := _flight_active or _read_voyage(SessionIO.SAVE_PATH) != null
	var backup_available := _read_voyage(SessionIO.BACKUP_PATH) != null
	_hud.set_input_enabled(false)
	_voyages.open(not _flight_active, primary_available, backup_available, VoyageLibrary.list_slots())
	if not primary_available and not backup_available and (FileAccess.file_exists(SessionIO.SAVE_PATH) or FileAccess.file_exists(SessionIO.BACKUP_PATH)):
		_voyages.notify("Автосохранения повреждены. Выберите именную копию, отчёт ZIP или новый рейс.")


func _refresh_voyages() -> void:
	_voyages.refresh(_flight_active or _read_voyage(SessionIO.SAVE_PATH) != null,
		_read_voyage(SessionIO.BACKUP_PATH) != null, VoyageLibrary.list_slots())


static func _read_voyage(path: String) -> Flight:
	var state := SessionIO.load_single_state(path)
	if state.is_empty():
		return null
	var candidate := Flight.new()
	return candidate if candidate.restore(state) else null


func _voyage_action(action: String, slot_id: String, slot_name: String) -> void:
	if not _voyages.is_open():
		return
	match action:
		"continue", "close":
			if _flight_active:
				_close_voyages()
			elif action == "continue":
				var candidate := _read_voyage(SessionIO.SAVE_PATH)
				if candidate != null:
					_activate_voyage(candidate, "Рейс продолжен.")
				else:
					_refresh_voyages()
					_voyages.notify("Автосохранение недоступно.")
		"new":
			_replace_voyage(Flight.new(), "Начат новый рейс.")
		"recover":
			var candidate := _read_voyage(SessionIO.BACKUP_PATH)
			if candidate == null:
				_refresh_voyages()
				_voyages.notify("Резервная копия недоступна.")
				return
			_replace_voyage(candidate, "Рейс восстановлен из резервной копии.")
		"load":
			var candidate := Flight.new()
			if not VoyageLibrary.load_slot(slot_id, candidate.restore):
				_refresh_voyages()
				_voyages.notify("Не удалось загрузить именную копию.")
				return
			_replace_voyage(candidate, "Именная копия загружена.")
		"create":
			if _flight_active:
				var result := VoyageLibrary.create_slot(slot_name, flight.snapshot())
				_show_voyage_library_result(int(result.get("error", OK if result.ok else FAILED)), "Именная копия сохранена.")
		"rename":
			_show_voyage_library_result(VoyageLibrary.rename_slot(slot_id, slot_name), "Имя копии изменено.")
		"delete":
			_show_voyage_library_result(VoyageLibrary.delete_slot(slot_id), "Именная копия удалена.")
		"import":
			_open_voyage_file()


func _close_voyages() -> void:
	_voyages.close()
	_hud.set_input_enabled(true)


func _show_voyage_library_result(error: Error, success_message: String) -> void:
	if error == OK:
		_refresh_voyages()
	_voyages.notify(success_message if error == OK else VoyageLibrary.error_message(error))


func _replace_voyage(candidate: Flight, message: String) -> void:
	var rotate_previous := _flight_active or _read_voyage(SessionIO.SAVE_PATH) != null
	if _flight_active:
		# Checkpoint the outgoing live flight so rotation also covers the time
		# since the last autosave. Keep the older backup until this succeeds.
		if SessionIO.save_state(flight.snapshot(), SessionIO.SAVE_PATH, true) != OK:
			_voyages.notify("Не удалось сохранить текущий рейс. Переключение отменено.")
			return
	if SessionIO.save_state(candidate.snapshot(), SessionIO.SAVE_PATH, not rotate_previous) != OK:
		_voyages.notify("Не удалось записать выбранный рейс. Переключение отменено.")
		return
	_preserve_backup_on_next_save = not rotate_previous and FileAccess.file_exists(SessionIO.BACKUP_PATH)
	_activate_voyage(candidate, message)


func _activate_voyage(candidate: Flight, message: String) -> void:
	flight = candidate
	_flight_active = true
	_save_elapsed = 0.0
	_save_error_shown = false
	_io = SessionIO.new()
	_camera_mode = FlightCamera.Mode.EXTERIOR
	_view.select_camera_mode(_camera_mode)
	_close_voyages()
	var interruption := flight.status_message if not flight.status_event.is_empty() else ""
	_deliver_notice()
	_hud.notify(message if interruption.is_empty() else message + " " + interruption)
	_update_display(0.0)
	_trace_voyage_start()


func _trace_voyage_start() -> void:
	_io.trace("session_started", {"system_id": flight.system_id, "docked": flight.docked, "deliveries": flight.deliveries, "presentation": presentation.snapshot()})


func _open_voyage_file() -> void:
	var native_available := DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
	if OS.has_feature("android") and not native_available:
		_voyages.notify("На этом устройстве системный выбор ZIP недоступен.")
		return
	if _voyage_picker == null:
		_voyage_picker = FileDialog.new()
		_voyage_picker.title = "Выбрать отчёт о рейсе"
		_voyage_picker.access = FileDialog.ACCESS_FILESYSTEM
		_voyage_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_voyage_picker.use_native_dialog = native_available
		_voyage_picker.add_filter("*.zip", "Отчёт ZIP", "application/zip")
		_voyage_picker.size = Vector2i(850, 480)
		_voyage_picker.file_selected.connect(_import_voyage_file)
		add_child(_voyage_picker)
		var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		if DirAccess.dir_exists_absolute(downloads):
			_voyage_picker.current_dir = downloads
	_voyage_picker.popup_file_dialog()


func _import_voyage_file(path: String) -> void:
	if not _voyages.is_open():
		return
	var candidate := Flight.new()
	var result := VoyageImport.load_report(path, candidate.restore)
	if result == ERR_UNAVAILABLE:
		_voyages.notify("В этом отчёте есть только журнал. Выберите ZIP с состоянием рейса.")
	elif result != OK:
		_voyages.notify("Не удалось прочитать рейс из ZIP. Проверьте выбранный файл.")
	else:
		_replace_voyage(candidate, "Рейс восстановлен из отчёта ZIP.")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _voyages.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_voyages.handle_back()
		return
	if _report.visible:
		if event.physical_keycode == KEY_ESCAPE:
			_close_report()
		return
	if _map.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_map()
		return
	if _galaxy.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_galaxy()
		return
	if _services.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_services()
		return
	if _market.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_market()
		return
	if _settings.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_settings()
		return
	if _journal.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_journal()
		return
	if _frontier.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_frontier()
		return
	if _recon.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_recon()
		return
	if _operations_panel.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_close_operations()
		return
	if _comms.is_open():
		if event.physical_keycode == KEY_ESCAPE:
			_comms.handle_back()
		return
	if event.physical_keycode == KEY_F12:
		_hud.toggle_navigation()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE and _hud.close_navigation():
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE and flight.departure_status().can_cancel:
		_handle_action("dock")
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE and (flight.cancel_jump() or flight.cancel_orbit_maneuver() or flight.cancel_rendezvous()):
		_deliver_notice()
		get_viewport().set_input_as_handled()
		return
	var actions := {
		KEY_T: "target", KEY_F: "autopilot", KEY_R: "throttle_up", KEY_V: "throttle_down",
		KEY_ENTER: "dock", KEY_M: "contract", KEY_G: "mine", KEY_B: "sell_ore", KEY_F8: "report",
		KEY_N: "map", KEY_J: "galaxy", KEY_K: "scoop", KEY_P: "services", KEY_O: "time", KEY_L: "market",
		KEY_U: "patrol", KEY_X: "fire", KEY_I: "convoy", KEY_H: "flight_assist", KEY_Q: "recon",
		KEY_Z: "missile_fire", KEY_BRACKETRIGHT: "missile_next", KEY_BRACKETLEFT: "decoy",
		KEY_SEMICOLON: "operations", KEY_BACKSLASH: "comms",
		KEY_F1: "camera", KEY_F2: "settings", KEY_F3: "journal", KEY_F4: "frontier",
		KEY_F5: "dock_sync", KEY_F6: "dock_clearance", KEY_F7: "frame", KEY_F9: "time_pause", KEY_F10: "speed_hold", KEY_F11: "voyages", KEY_Y: "gear", KEY_C: "fuel",
	}
	if actions.has(event.physical_keycode):
		_handle_action(actions[event.physical_keycode])
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_report_touches.clear()
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_report_sharing = false
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _voyages.is_open():
			_save(true)
			return
		var sharing_report := what == NOTIFICATION_APPLICATION_PAUSED and _report.visible and _report_sharing
		# Preserve the interruption receipt before changing the live controls.
		_save()
		if not sharing_report:
			flight.cancel_jump()
			flight.cancel_orbit_maneuver()
			flight.cancel_rendezvous()
			flight.cancel_dock_sync()
			flight.reset_time_scale()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _voyages.is_open():
			_voyages.handle_back()
		elif _report.visible:
			_close_report()
		elif _map.is_open():
			_close_map()
		elif _galaxy.is_open():
			_close_galaxy()
		elif _services.is_open():
			_close_services()
		elif _market.is_open():
			_close_market()
		elif _settings.is_open():
			_close_settings()
		elif _journal.is_open():
			_close_journal()
		elif _frontier.is_open():
			_close_frontier()
		elif _recon.is_open():
			_close_recon()
		elif _operations_panel.is_open():
			_close_operations()
		elif _comms.is_open():
			_comms.handle_back()
		elif _hud.close_navigation():
			return
		elif flight.departure_status().can_cancel:
			_handle_action("dock")
		elif flight.cancel_jump() or flight.cancel_orbit_maneuver() or flight.cancel_rendezvous():
			_deliver_notice()
		else:
			_save()
			get_tree().quit()


func _build_report_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_report = CenterContainer.new()
	layer.add_child(_report)
	_report.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.025, 0.86)
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.move_child(shade, 0)
	_report.visibility_changed.connect(func(): shade.visible = _report.visible)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101f29")
	style.border_color = Color("547b86")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	_report.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	panel.add_child(contents)
	var title := Label.new()
	title.text = "Отчёт о рейсе"
	title.add_theme_font_size_override("font_size", 28)
	contents.add_child(title)
	_report_text = Label.new()
	_report_text.custom_minimum_size = Vector2(490, 80)
	_report_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report_text.add_theme_font_size_override("font_size", 18)
	contents.add_child(_report_text)
	var buttons: Container
	if OS.has_feature("android"):
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		buttons = grid
		_add_report_button(buttons, "Поделиться ZIP", _share_report)
	else:
		buttons = HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 10)
	contents.add_child(buttons)
	_add_report_button(buttons, "Сохранить ZIP", _export_report)
	_add_report_button(buttons, "Копировать текст", _copy_report)
	_add_report_button(buttons, "Закрыть", _close_report)
	_report.hide()


func _add_report_button(parent: Container, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	_report_buttons.append(button)


func _input(event: InputEvent) -> void:
	if _report == null or not _report.visible:
		return
	if event is InputEventScreenTouch:
		var button: Button = _report_touches.get(event.index)
		_report_touches.erase(event.index)
		if not event.canceled:
			if event.pressed:
				for candidate in _report_buttons:
					if _report_button_hit(candidate, event.position) and candidate not in _report_touches.values():
						_report_touches[event.index] = candidate
						break
			elif _report_button_hit(button, event.position):
				button.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if not _report_button_hit(_report_touches.get(event.index), event.position):
			_report_touches.erase(event.index)
		get_viewport().set_input_as_handled()


static func _report_button_hit(button: Button, position: Vector2) -> bool:
	return button != null and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(position)


func _open_report() -> void:
	_hud.set_input_enabled(false)
	_report_touches.clear()
	if SessionIO.can_archive_flight(flight.snapshot()):
		_report_text.text = "В ZIP входят версия игры, состояние рейса и последние события."
	else:
		_report_text.text = REPORT_JOURNAL_ONLY
	if OS.has_feature("android"):
		_report_text.text += "\nПри отправке вы выбираете приложение и получателя."
	_report.show()


func _select_destination(site_id: int) -> void:
	if not _map.is_open() or not flight.select_target(site_id):
		return
	_close_map()
	_io.trace("route_selected", {"target": site_id})
	_hud.notify("Маршрут проложен. «%s»." % flight.target_name(site_id))
	_save()
	_update_display(0.0)


func _map_orbit_action(focus_id: int) -> void:
	if not _map.is_open():
		return
	var handled := flight.cancel_orbit_maneuver() if flight.orbit_maneuver else flight.start_orbit_maneuver(focus_id)
	if handled:
		_close_map()
		_deliver_notice()
		_update_display(0.0)


func _map_rendezvous_action(site_id: int, gap: int) -> void:
	if not _map.is_open():
		return
	var handled := flight.cancel_rendezvous() if flight.rendezvous_active else flight.start_rendezvous(site_id, gap)
	if handled:
		_close_map()
		_deliver_notice()
		_update_display(0.0)


func _map_rendezvous_finish() -> void:
	if _map.is_open() and flight.finish_rendezvous():
		_close_map()
		_deliver_notice()
		_update_display(0.0)


func _map_frame(selection: int, rotating := false) -> void:
	if not _map.is_open() or not flight.set_reference_frame(selection, rotating):
		return
	_deliver_notice()
	_update_display(0.0)


func _map_survey(site: int) -> void:
	if not _map.is_open():
		return
	if flight.survey_action(site):
		_io.trace("atlas_observation", {"site": site, "system": flight.system_id, "orbit_time": flight.orbit_time})
		_deliver_notice()
	_map.refresh_survey()


func _galaxy_scan() -> void:
	if not _galaxy.is_open():
		return
	if flight.scan_galaxy():
		_deliver_notice()
	_galaxy.refresh()


func _close_map() -> void:
	_map.close()
	_hud.set_input_enabled(true)


func _plan_jump(destination: int) -> void:
	if _galaxy.is_open() and flight.plan_route(destination):
		_deliver_notice()
		_galaxy.refresh()


func _cancel_jump_route() -> void:
	if _galaxy.is_open() and flight.cancel_route():
		_deliver_notice()
		_galaxy.refresh()


func _start_jump(emergency := false) -> void:
	if not _galaxy.is_open():
		return
	if flight.start_jump(emergency):
		_close_galaxy()
	else:
		_galaxy.refresh()
	_deliver_notice()
	_update_display(0.0)


func _target_hyperspace_trail() -> void:
	if _galaxy.is_open() and flight.target_hyperspace_trail():
		_close_galaxy()
		_deliver_notice()
		_update_display(0.0)


func _analyze_hyperspace_trail(id: String) -> void:
	if _galaxy.is_open():
		flight.analyze_hyperspace_trail(id)
		_galaxy.refresh()
		_deliver_notice()


func _close_galaxy() -> void:
	_galaxy.close()
	_hud.set_input_enabled(true)


func _service_purchase(action: String) -> void:
	if not _services.is_open():
		return
	flight.service_action(action)
	_deliver_notice()
	_services.refresh()
	_update_display(0.0)


func _select_weapon(weapon: String) -> void:
	if not _services.is_open():
		return
	flight.select_weapon(weapon)
	_deliver_notice()
	_services.refresh()
	_update_display(0.0)


func _select_missile(slot: int) -> void:
	if not _services.is_open():
		return
	flight.select_missile_slot(slot)
	_deliver_notice()
	_services.refresh()
	_update_display(0.0)


func _select_drive(id: String) -> void:
	if not _services.is_open():
		return
	flight.select_jump_drive(id)
	_deliver_notice()
	_services.refresh()
	_update_display(0.0)


func _remove_fuel_module(module: String) -> void:
	if not _services.is_open():
		return
	flight.remove_fuel_module(module)
	_deliver_notice()
	_services.refresh()
	_update_display(0.0)


func _set_pump_mode(mode: String) -> void:
	if not _services.is_open():
		return
	flight.set_fuel_pump_mode(mode)
	_deliver_notice()
	_services.refresh()
	_update_display(0.0)


func _fuel_transfer(destination: String) -> void:
	if not _services.is_open():
		return
	flight.fuel_transfer(destination)
	_deliver_notice()
	_services.refresh()
	_update_display(0.0)


func _jettison_cargo(good: String) -> void:
	if not _services.is_open():
		return
	flight.jettison_cargo(good)
	_deliver_notice()
	_services.refresh()
	_update_display(0.0)


func _cargo_pod_action(action: String) -> void:
	if not _services.is_open():
		return
	if action == "track":
		if flight.target_cargo_pod():
			_close_services()
	elif action == "collect":
		flight.collect_cargo_pod()
	_deliver_notice()
	_services.refresh()
	_update_display(0.0)


func _crew_action(action: String, member: int) -> void:
	if not _services.is_open() or not flight.station_services_available():
		return
	var changed := false
	match action:
		"hire": changed = flight.crew_hire(member)
		"dismiss": changed = flight.crew_dismiss(member)
		"pay": changed = flight.crew_pay(member)
	if changed:
		_deliver_notice()
		_update_display(0.0)
	_services.refresh()


func _customs_pay() -> void:
	if not _services.is_open():
		return
	if flight.customs_pay():
		_deliver_notice()
		_update_display(0.0)
	_services.refresh()


func _ship_exchange(hull: String) -> void:
	if not _services.is_open() or not flight.shipyard_available():
		return
	if flight.shipyard_swap(hull):
		_deliver_notice()
		_update_display(0.0)
	_services.refresh()


func _ship_yard_action(action: String, id: String) -> void:
	if not _services.is_open() or not flight.shipyard_available():
		return
	if flight.shipyard_action(action, id):
		_deliver_notice()
		_update_display(0.0)
	_services.refresh()


func _close_services() -> void:
	_services.close()
	_hud.set_input_enabled(true)


func _market_trade(good: String, side: String, quantity: int, hidden: bool) -> void:
	if _market.is_open() and flight.market_trade(good, side, quantity, hidden):
		_market.show_trade_receipt(flight.status_message)
		_deliver_notice()
		if hidden:
			_save()
		_update_display(0.0)
	_market.refresh()


func _accept_courier(route_id: String) -> void:
	if _market.is_open() and flight.accept_courier(route_id):
		_deliver_notice()
		_update_display(0.0)
	_market.refresh()


func _passenger_action(action: String, destination: int) -> void:
	if not _market.is_open():
		return
	var changed := false
	match action:
		"accept": changed = flight.passenger_accept(destination)
		"discharge": changed = flight.passenger_discharge()
		"repay": changed = flight.passenger_repay()
	if changed:
		_deliver_notice()
		_update_display(0.0)
	_market.refresh()


func _close_market() -> void:
	_market.close()
	_hud.set_input_enabled(true)


func _apply_presentation() -> void:
	FlightText.set_language(presentation.language)
	_hud.apply_interface_language()
	var viewport := get_viewport()
	viewport.msaa_3d = ANTIALIASING[presentation.quality]
	if DisplayServer.get_name() != "headless":
		Engine.max_fps = presentation.fps_limit()
	_view.set_visual_profile(presentation.quality)
	_hud.set_touch_preferences(presentation.sensitivity, presentation.layout == 1)
	_audio.set_level(presentation.notification_volume)
	_audio.set_effect_level(presentation.effects_volume)
	_audio.music.configure(presentation.music_volume, presentation.music_mode)


func _change_preference(field: String, value: int) -> void:
	if not _settings.is_open() or not presentation.change(field, value):
		return
	_apply_presentation()
	var saved := presentation.save_preferences()
	_io.trace("presentation_changed", {"field": field, "value": value, "saved": saved == OK})
	if saved != OK:
		_hud.notify("Не удалось сохранить настройки.")
	_settings.refresh()
	_update_display(0.0)


func _close_settings() -> void:
	_settings.close()
	_hud.set_input_enabled(true)


func _follow_journal(kind: String) -> void:
	if not _journal.is_open():
		return
	var selected := false
	if kind == "delivery" and flight.contract_stage == 1:
		var port := flight.contract_destination
		var system := Catalog.system_of_site(port)
		selected = flight.select_target(port) if system == flight.system_id else flight.plan_jump(system)
		if selected and system == flight.system_id:
			_hud.notify("Курс доставки. «%s»." % flight.target_name(port))
	elif kind == "patrol":
		var status := flight.patrol_status()
		if status.phase in [Flight.Patrol.OUTBOUND, Flight.Patrol.ENGAGED, Flight.Patrol.RETURN]:
			if not status.same_system:
				selected = flight.plan_jump(Catalog.system_of_site(flight.patrol.origin))
			elif flight.docked < 0 and not flight.landed and status.available:
				selected = flight.patrol_course or flight.patrol_action()
	elif kind == "passenger":
		selected = flight.passenger_follow()
	elif kind == "rig":
		selected = flight.track_remote_rig()
	elif kind == "career":
		selected = flight.career_follow()
	elif kind == "story":
		var status := flight.story_status()
		if status.can_follow and status.stage == "observe" and int(status.target) == flight.landed_site:
			_close_journal()
			_hud.set_input_enabled(false)
			_map.open_atlas(flight, int(status.target))
			return
		selected = flight.story_follow()
	if not selected:
		_journal.refresh()
		return
	_close_journal()
	if flight.status_event.is_empty():
		_save()
	else:
		_deliver_notice()
	_update_display(0.0)


func _career_dispatch(kind: String) -> void:
	if not _journal.is_open():
		return
	flight.career_dispatch_action(kind)
	_deliver_notice()
	_journal.refresh()
	_update_display(0.0)


func _story_action(action: String) -> void:
	if not _journal.is_open():
		return
	flight.story_action(action)
	_deliver_notice()
	_journal.refresh()
	_update_display(0.0)


func _close_journal() -> void:
	_journal.close()
	_hud.set_input_enabled(true)


func _project_action() -> void:
	if not _frontier.is_open():
		return
	if flight.project_action():
		var routed := flight.status_event in ["expedition_course", "jump_planned"]
		_deliver_notice()
		if routed:
			_close_frontier()
		_update_display(0.0)
	_frontier.refresh()


func _convoy_action(system: int, id: String) -> void:
	if not _frontier.is_open() or not flight.convoy_action(system, id):
		return
	var routed := id.is_empty() and flight.status_event in ["convoy_order_course", "jump_planned"]
	_deliver_notice()
	if routed:
		_close_frontier()
	_update_display(0.0)
	_frontier.refresh()


func _close_frontier() -> void:
	_frontier.close()
	_hud.set_input_enabled(true)


func _search_action(action: String) -> void:
	if not _frontier.is_open():
		return
	if flight.search_action(action) and action == "follow":
		_close_frontier()
	_deliver_notice()
	_frontier.refresh()
	_update_display(0.0)


func _recon_action(action: String) -> void:
	if not _recon.is_open():
		return
	var done := flight.recon_action(action)
	var notice := flight.status_message if not flight.status_event.is_empty() else "Команда сейчас недоступна."
	if done and action == "follow":
		_close_recon()
	else:
		_recon.refresh(notice)
	_deliver_notice()
	_update_display(0.0)


func _close_recon() -> void:
	_recon.close()
	_hud.set_input_enabled(true)


func _open_operations() -> void:
	if _journal.is_open():
		_journal.close()
	_hud.set_input_enabled(false)
	_operations_panel.open(flight)


func _operation_action(id: String, action: String) -> void:
	if not _operations_panel.is_open():
		return
	var done := flight.operation_action(id, action)
	var message := flight.status_message if done else "Команда пока недоступна."
	if done and action == "follow":
		_close_operations()
	else:
		_operations_panel.refresh(message)
	_deliver_notice()
	_update_display(0.0)


func _close_operations() -> void:
	_operations_panel.close()
	_hud.set_input_enabled(true)


func _open_comms(id := "") -> void:
	_hud.close_navigation()
	_hud.set_input_enabled(false)
	_comms.open(flight, id)


func _open_law_radio() -> void:
	_services.close()
	_open_comms()


func _select_rig_slot(slot: int) -> void:
	if _journal.is_open() and flight.select_rig_slot(slot):
		_deliver_notice()
		_journal.refresh()


func _comms_action(action: String) -> void:
	if not _comms.is_open():
		return
	flight.comms_action(action, _comms.contact_id())
	_deliver_notice()
	_comms.refresh()
	_update_display(0.0)


func _close_comms() -> void:
	_comms.close()
	_hud.set_input_enabled(true)


func _subscribe_news(id: String) -> void:
	if not _journal.is_open():
		return
	var subscribed := flight.subscribe_news(id)
	_deliver_notice()
	if subscribed:
		_save()
	_journal.refresh()


func _calendar_wait(epoch: float) -> void:
	if not _journal.is_open():
		return
	if flight.wait_on_calendar(epoch):
		_close_journal()
	_deliver_notice()
	_update_display(0.0)


func _close_report() -> void:
	_report_touches.clear()
	_report_sharing = false
	_report.hide()
	_hud.set_input_enabled(true)


func _export_report() -> void:
	_report_touches.clear()
	var result := _io.export_report(flight.snapshot())
	if not result.ok:
		_report_text.text = "Не удалось записать архив. Можно скопировать текст отчёта."
		return
	if result.get("public_downloads", false):
		_report_text.text = "ZIP сохранён в «Загрузках».\n%s" % result.path
	elif OS.has_feature("android"):
		_report_text.text = "ZIP сохранён в памяти игры. Используйте «Поделиться ZIP»."
		_report_text.text += " Текст отчёта скопирован." if result.get("clipboard_copied", false) else " Можно скопировать текст."
	else:
		_report_text.text = "ZIP сохранён.\n%s" % result.path
	_show_report_scope(result)


func _share_report() -> void:
	if not _report.visible or _report_sharing:
		return
	_report_touches.clear()
	if not OS.has_feature("android"):
		_report_text.text = "На этом устройстве можно сохранить ZIP или скопировать текст."
		return
	_report_sharing = true
	var result := _io.share_report(flight.snapshot())
	if result.get("shared", false):
		_report_text.text = "Игра открыла системное меню отправки ZIP."
		_show_report_scope(result)
		return
	_report_sharing = false
	if not result.ok:
		_report_text.text = "Не удалось подготовить ZIP. Можно скопировать текст отчёта."
	elif result.get("public_downloads", false):
		_report_text.text = "Меню отправки недоступно. Передайте ZIP из «Загрузок».\n%s" % result.path
	else:
		_report_text.text = "Меню отправки недоступно. ZIP сохранён в памяти игры. Попробуйте «Сохранить ZIP» или скопируйте текст."
	if result.ok:
		_show_report_scope(result)


func _show_report_scope(result: Dictionary) -> void:
	if not result.includes_flight_state:
		_report_text.text += "\n" + REPORT_JOURNAL_ONLY


func _copy_report() -> void:
	_report_touches.clear()
	_report_text.text = "Текст отчёта скопирован." if _io.copy_report_text(flight.snapshot()) else "Буфер обмена сейчас недоступен."
