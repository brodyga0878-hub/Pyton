extends Node

const Flight = preload("res://scripts/flight_sim.gd")
const FlightView = preload("res://scripts/flight_view.gd")
const FlightHUD = preload("res://scripts/flight_hud.gd")
const SectorMap = preload("res://scripts/sector_map.gd")
const GalaxyMap = preload("res://scripts/galaxy_map.gd")
const PortServices = preload("res://scripts/port_services.gd")
const PortMarket = preload("res://scripts/port_market.gd")
const DisplaySettings = preload("res://scripts/display_settings.gd")
const PresentationMenu = preload("res://scripts/presentation_menu.gd")
const MissionJournal = preload("res://scripts/mission_journal.gd")
const ExpansionBoard = preload("res://scripts/expansion_board.gd")
const SessionIO = preload("res://scripts/session_io.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const SAVE_INTERVAL := 8.0
const ANTIALIASING := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]

var flight := Flight.new()
var presentation := DisplaySettings.new()
var _view := FlightView.new()
var _hud := FlightHUD.new()
var _map := SectorMap.new()
var _galaxy := GalaxyMap.new()
var _services := PortServices.new()
var _market := PortMarket.new()
var _settings := PresentationMenu.new()
var _journal := MissionJournal.new()
var _frontier := ExpansionBoard.new()
var _io := SessionIO.new()
var _save_elapsed := 0.0
var _save_error_shown := false
var _report: CenterContainer
var _report_text: Label
var _report_buttons: Array[Button] = []
var _report_touches: Dictionary[int, Button] = {}
var _report_sharing := false


func _ready() -> void:
	presentation.load_preferences()
	var saved := SessionIO.load_state()
	if not saved.is_empty():
		_io.trace("load", {"accepted": flight.restore(saved)})
	add_child(_view)
	_view.build()
	add_child(_hud)
	_hud.build()
	_hud.action_requested.connect(_handle_action)
	_hud.frame_requested.connect(_handle_action.bind("frame"))
	add_child(_map)
	_map.build()
	_map.destination_selected.connect(_select_destination)
	_map.orbit_requested.connect(_map_orbit_action)
	_map.rendezvous_requested.connect(_map_rendezvous_action)
	_map.rendezvous_finish_requested.connect(_map_rendezvous_finish)
	_map.survey_requested.connect(_map_survey)
	_map.frame_selected.connect(_map_frame)
	_map.dismissed.connect(_close_map)
	add_child(_galaxy)
	_galaxy.build()
	_galaxy.destination_selected.connect(_plan_jump)
	_galaxy.jump_requested.connect(_start_jump)
	_galaxy.route_cancel_requested.connect(_cancel_jump_route)
	_galaxy.galaxy_scan_requested.connect(_galaxy_scan)
	_galaxy.dismissed.connect(_close_galaxy)
	add_child(_services)
	_services.build()
	_services.service_requested.connect(_service_purchase)
	_services.transfer_requested.connect(_fuel_transfer)
	_services.jettison_requested.connect(_jettison_cargo)
	_services.crew_requested.connect(_crew_action)
	_services.ship_exchange_requested.connect(_ship_exchange)
	_services.customs_payment_requested.connect(_customs_pay)
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
	add_child(_journal)
	_journal.build()
	_journal.follow_requested.connect(_follow_journal)
	_journal.dismissed.connect(_close_journal)
	add_child(_frontier)
	_frontier.build()
	_frontier.project_requested.connect(_project_action)
	_frontier.convoy_requested.connect(_convoy_action)
	_frontier.dismissed.connect(_close_frontier)
	_build_report_panel()
	_apply_presentation()
	_update_display(0.0)
	_io.trace("session_started", {"system_id": flight.system_id, "docked": flight.docked, "deliveries": flight.deliveries, "presentation": presentation.snapshot()})


func _process(delta: float) -> void:
	_update_display(delta)


func _overlay_open() -> bool:
	return _report.visible or _map.is_open() or _galaxy.is_open() or _services.is_open() or _market.is_open() or _settings.is_open() or _journal.is_open() or _frontier.is_open()


func _physics_process(delta: float) -> void:
	if _overlay_open():
		return
	flight.update(delta, _hud.move_input(), _hud.roll_input(), _hud.boost_held(), _hud.brake_held(), _hud.translation_input())
	_deliver_notice()
	_save_elapsed += delta
	if _save_elapsed >= SAVE_INTERVAL:
		_save()


func _update_display(delta: float) -> void:
	_view.sync(flight, delta)
	_hud.sync(flight, delta)
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
	var instruments_visible := flight.docked < 0 and not flight.landed and not _overlay_open() and flight.jump_seconds_left <= 0.0
	var in_view := instruments_visible and not _view.camera.is_position_behind(marker)
	if patrol_status.phase == Flight.Patrol.ENGAGED and patrol_status.same_system:
		in_view = false
	elif in_view and not flight.autopilot and not signal_selected and not project_marker and not convoy_marker and not rendezvous_marker:
		var surface := flight.surface_status()
		in_view = not surface.near or surface.pad
	_hud.set_target_marker(_view.camera.unproject_position(marker) if in_view else Vector2.ZERO, in_view)
	var markers: Array[Dictionary] = []
	if instruments_visible:
		for contact in flight.traffic_contacts():
			var distance := flight.position.distance_to(contact.position)
			if distance > 1100.0 or _view.camera.is_position_behind(contact.position):
				continue
			markers.append({"screen": _view.camera.unproject_position(contact.position), "role": contact.role, "name": contact.name, "distance": distance})
	_hud.set_traffic_markers(markers)


func _handle_action(action: String) -> void:
	if _overlay_open():
		return
	if flight.jump_seconds_left > 0.0 and action not in ["throttle_up", "throttle_down"]:
		return
	if flight.docked >= 0:
		var departure := flight.departure_status()
		if departure.active and (action != "dock" or not departure.can_cancel):
			return
	var near_target := flight.position.distance_to(flight.target_position(flight.target)) < maxf(150.0, float(Catalog.site(flight.target).radius) + Flight.FRAME_MARGIN)
	var throttle_step := 0.025 if near_target else 0.1
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
		"orbit_cancel":
			flight.cancel_orbit_maneuver()
		"rendezvous_cancel":
			flight.cancel_rendezvous()
		"rendezvous_finish":
			flight.finish_rendezvous()
		"throttle_up":
			flight.change_throttle(throttle_step)
		"throttle_down":
			flight.change_throttle(-throttle_step)
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
		"mine":
			flight.mine_action()
		"rig_deploy":
			flight.leave_remote_rig()
		"rig_unload":
			flight.unload_remote_rig()
		"rig_retrieve":
			flight.retrieve_remote_rig()
		"rig_route":
			flight.track_remote_rig()
		"sell_ore":
			flight.sell_ore_action()
		"scoop":
			flight.scoop_action()
		"time":
			flight.cycle_time_scale()
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
		_:
			return
	if action in ["target", "autopilot", "throttle_up", "throttle_down"]:
		_io.trace(action, {"target": flight.target, "autopilot": flight.autopilot, "throttle": flight.throttle})
	_deliver_notice()
	if action == "target":
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
	elif event == "ship_exchange":
		trace_fields = {
			"port": flight.docked, "hull_id": flight.ship.hull_id, "credits": flight.credits,
			"cargo_capacity": flight.ship.cargo_capacity(), "crew_required": flight.ship.crew_required(),
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
	elif event == "reference_frame":
		var frame := flight.frame_status()
		trace_fields = {
			"mode": frame.mode, "reference": frame.reference, "surface": frame.surface,
			"relative_speed": frame.relative_speed, "speed": flight.speed(),
			"system_id": flight.system_id, "orbit_time": flight.orbit_time,
		}
	_io.trace(event, trace_fields)
	_hud.notify(flight.status_message)
	flight.status_event = ""
	if event in [
		"launch", "dock", "land", "lift", "contract", "delivery", "mining_deploy", "mining_recover",
		"dock_request", "dock_ready", "dock_expired",
		"departure_requested", "departure_canceled", "departure_open", "departure_crew_denied",
		"mining_ready", "mining_loaded", "ore_sold",
		"remote_rig_deployed", "remote_rig_unloaded", "remote_rig_retrieved", "remote_rig_route", "service_refuel", "service_tank", "service_eco",
		"scoop_full", "scoop_stop", "star_arrival", "gas_arrival", "fuel_empty", "thermal_damage",
		"fuel_transfer", "service_jump_refuel", "cargo_jettisoned",
		"atmosphere_enter", "atmosphere_exit", "atmosphere_damage",
		"gear_deploy", "gear_retract", "gear_ready", "gear_stowed",
		"service_heat_shield",
		"jump_planned", "jump_complete", "route_canceled",
		"market_buy", "market_sell", "service_repair", "service_cargo", "hull_damage", "contract_leg",
		"passenger_accepted", "passenger_overdue", "passenger_paid", "passenger_late", "passenger_canceled",
		"passenger_debt_paid", "passenger_course",
		"crew_hired", "crew_dismissed", "crew_payroll", "crew_arrears_paid", "ship_exchange",
		"patrol_accepted", "patrol_engaged", "patrol_fire", "patrol_enemy_hit", "patrol_retreat", "patrol_victory", "patrol_paid",
		"expedition_accepted", "expedition_survey", "expedition_report", "expedition_supply", "expedition_complete", "expedition_course",
		"war_declared", "war_round", "war_captured", "war_repulsed", "war_convoy_delivered", "war_convoy_intercepted",
		"convoy_order_accepted", "convoy_order_escorted", "convoy_order_failed", "convoy_order_paid",
		"convoy_order_fire", "convoy_order_enemy_hit",
		"flight_assist", "reference_frame",
		"survey_record", "galaxy_scan", "customs_inspection", "customs_paid",
		"orbit_start", "orbit_complete", "orbit_abort", "orbit_cancel",
		"rendezvous_start", "rendezvous_hold", "rendezvous_abort", "rendezvous_cancel", "rendezvous_finish",
	]:
		_save()


func _save() -> void:
	_save_elapsed = 0.0
	var result := SessionIO.save_state(flight.snapshot())
	if result != OK and not _save_error_shown:
		_hud.notify("Не удалось сохранить рейс.")
		_io.trace("save_error", {"error": int(result)})
	_save_error_shown = result != OK


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
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
		KEY_U: "patrol", KEY_X: "fire", KEY_I: "convoy", KEY_H: "flight_assist",
		KEY_F2: "settings", KEY_F3: "journal", KEY_F4: "frontier",
		KEY_F5: "dock_sync", KEY_F6: "dock_clearance", KEY_F7: "frame", KEY_Y: "gear", KEY_C: "fuel",
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
		var sharing_report := what == NOTIFICATION_APPLICATION_PAUSED and _report.visible and _report_sharing
		if not sharing_report:
			flight.cancel_jump()
			flight.cancel_orbit_maneuver()
			flight.cancel_rendezvous()
			flight.cancel_dock_sync()
			flight.reset_time_scale()
		_save()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _report.visible:
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
	_report_text.text = "В ZIP входят версия игры, состояние рейса и последние события."
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


func _map_frame(selection: int) -> void:
	if not _map.is_open() or not flight.set_reference_frame(selection):
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


func _start_jump() -> void:
	if not _galaxy.is_open():
		return
	if flight.start_jump():
		_close_galaxy()
	else:
		_galaxy.refresh()
	_deliver_notice()
	_update_display(0.0)


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


func _close_services() -> void:
	_services.close()
	_hud.set_input_enabled(true)


func _market_trade(good: String, side: String, quantity: int) -> void:
	if _market.is_open() and flight.market_trade(good, side, quantity):
		_deliver_notice()
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
	var viewport := get_viewport()
	viewport.msaa_3d = ANTIALIASING[presentation.quality]
	if DisplayServer.get_name() != "headless":
		Engine.max_fps = presentation.fps_limit()
	_view.set_visual_profile(presentation.quality)
	_hud.set_touch_preferences(presentation.sensitivity, presentation.layout == 1)


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
	if not selected:
		_journal.refresh()
		return
	_close_journal()
	if flight.status_event.is_empty():
		_save()
	else:
		_deliver_notice()
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
		return
	_report_sharing = false
	if not result.ok:
		_report_text.text = "Не удалось подготовить ZIP. Можно скопировать текст отчёта."
	elif result.get("public_downloads", false):
		_report_text.text = "Меню отправки недоступно. Передайте ZIP из «Загрузок».\n%s" % result.path
	else:
		_report_text.text = "Меню отправки недоступно. ZIP сохранён в памяти игры. Попробуйте «Сохранить ZIP» или скопируйте текст."


func _copy_report() -> void:
	_report_touches.clear()
	_report_text.text = "Текст отчёта скопирован." if _io.copy_report_text(flight.snapshot()) else "Буфер обмена сейчас недоступен."
