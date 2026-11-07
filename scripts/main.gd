extends Node3D
# Newly reconstructed application controller around preserved and rebuilt modules.
const Flight=preload("res://scripts/flight_model.gd")
const NavigationData=preload("res://scripts/navigation.gd")
const World=preload("res://scripts/planetary_system.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Near=preload("res://scripts/near_surface_view.gd")
const SurfaceView=preload("res://scripts/surface_visual.gd")
const Celestial=preload("res://scripts/celestial_renderer.gd")
const CityView=preload("res://scripts/source_city_view.gd")
const CityRuntime=preload("res://scripts/source_city_runtime.gd")
const CityProfile=preload("res://scripts/source_city_profile.gd")
const Presentation=preload("res://scripts/world_presentation.gd")
const Settings=preload("res://scripts/device_settings.gd")
const SettingsPanel=preload("res://scripts/settings_panel.gd")
const SaveStore=preload("res://scripts/save_store.gd")
const Stick=preload("res://scripts/touch_stick.gd")
const Hold=preload("res://scripts/hold_button.gd")
const RollControl=preload("res://scripts/roll_control.gd")
const Lever=preload("res://scripts/speed_lever.gd")
const ActionButton=preload("res://scripts/touch_action_button.gd")
const FlightConsole=preload("res://scripts/flight_console.gd")
const FlightInstruments=preload("res://scripts/flight_instruments.gd")
const TimeControls=preload("res://scripts/flight_time_controls.gd")
const TimeController=preload("res://scripts/flight_time_controller.gd")
const GalacticMap=preload("res://scripts/galactic_map_view.gd")
const SystemMap=preload("res://scripts/system_map_view.gd")
const SystemInformation=preload("res://scripts/system_information_view.gd")
const HyperdriveServices=preload("res://scripts/hyperdrive_services_view.gd")
const ShipView=preload("res://scripts/ship_visual.gd")
const StationView=preload("res://scripts/station_visual.gd")
const SourceStationView=preload("res://scripts/source_station_visual.gd")
const StationSession=preload("res://scripts/source_station_session.gd")
const SourceTerrain=preload("res://scripts/source_surface_terrain.gd")
const SpaceEnvironment=preload("res://scripts/space_environment.gd")
const FlightTheme=preload("res://scripts/flight_theme.gd")
const FlightReticle=preload("res://scripts/flight_reticle.gd")
const BuildInfo=preload("res://scripts/build_info.gd")
const SourceClock=preload("res://scripts/source_clock.gd")
const SourceUnits=preload("res://scripts/source_units.gd")
const MotionBridge=preload("res://scripts/source_motion_bridge.gd")
const FuelFlightBridge=preload("res://scripts/source_fuel_flight_bridge.gd")
const FuelContact=preload("res://scripts/source_fuel_contact.gd")
const AtmosphereContact=preload("res://scripts/source_atmosphere_contact.gd")
const LandingGearSession=preload("res://scripts/source_landing_gear_session.gd")
const SurfaceContactBridge=preload("res://scripts/source_surface_contact_bridge.gd")
const Diagnostics=preload("res://scripts/game_diagnostics.gd")
const ReportExport=preload("res://scripts/report_export.gd")
const DockServices=preload("res://scripts/training_dock_services.gd")
const DockServicesView=preload("res://scripts/dock_services_view.gd")
var ship:RefCounted
var nav:RefCounted
var world:RefCounted
var surface:RefCounted
var near:=Near.new()
var fuel_contact:=FuelContact.new()
var atmosphere_contact:=AtmosphereContact.new()
var landing_gear:RefCounted
var source_contact_last:Dictionary={}
var source_contact_error:=""
var _source_contact_interval:Dictionary={}
var _thermal_notice_level:=""
var settings:=Settings.new()
var saves:=SaveStore.new()
var presentation:=Presentation.new()
var camera:Camera3D
var flight_view_rect:=Rect2()
var _flight_projection_signature:Array=[]
var flight_cross:Label
var environment:WorldEnvironment
var sunlight:DirectionalLight3D
var planet_fill:DirectionalLight3D
var celestial:Node3D
var ground_view:Node3D
var city_view:Node3D
var station:Node3D
var source_station:Node3D
var source_station_key:=""
var player:Node3D
var stars:MultiMeshInstance3D
var space_environment:Node3D
var ui:Control
var hud:Label
var notice:Label
var target_label:Label
var fps_label:Label
var flight_reticle:Control
var stick:Control
var lever:Control
var holds:Array=[]
var lift_up:=false
var lift_down:=false
var roll_left:=false
var roll_right:=false
var roll_left_strength:=0.0
var roll_right_strength:=0.0
var menu:PanelContainer
var menu_rows:VBoxContainer
var menu_title:Label
var menu_feedback:Label
var settings_panel:Control
var backup_edit:TextEdit
var auto_button:Button
var dock_button:Button
var surface_button:Button
var flight_console:Control
var time_controls:Control
var flight_time:=TimeController.new()
var active_map:Control
var active_map_kind:=""
var information_parent:Control
var information_parent_kind:=""
var information_return_menu:=false
var information_worker:Thread
var information_job_view:Control
var docking_label:Label
var target_site_id:=""
var target_reference:Dictionary={}
var target_worker:Thread
var target_job_key:=""
var target_job_world:RefCounted
var source_motion:=MotionBridge.new()
var source_motion_enabled:=false
var last_motion_result:Dictionary={}
var instruments:=FlightInstruments.new()
var last_view:=""
var dock_services_view:Control
var hyperdrive_services_view:Control
var action_buttons:Array=[]
var flight_widgets:Array=[]
var busy:=false
var active:=true
var automated:=false
var saving_enabled:=true
var save_timer:=0.0
var hud_timer:=0.0
var notice_timer:=0.0
var worker:Thread
var hatch_worker:Thread
var hatch_owner:RefCounted
var presentation_key:=""
var last_external:=false
var graphics_return:Dictionary={}
var diagnostics:Node
var report_export:Node
var report_description:TextEdit
var report_feedback:Label
var report_retry:Button
var report_include_save:=false
var report_draft:=""
var current_report:Dictionary={}
var diagnostic_timer:=0.0
var last_flight_sample:Dictionary={}

func _ready()->void:
	get_tree().auto_accept_quit=false
	automated="--rebuild-smoke" in OS.get_cmdline_user_args() or "--rebuild-capture" in OS.get_cmdline_user_args()
	saving_enabled=not automated
	diagnostics=Diagnostics.new();add_child(diagnostics)
	if not automated:diagnostics.initialize(BuildInfo.VERSION)
	report_export=ReportExport.new();add_child(report_export);report_export.completed.connect(_report_export_completed)
	settings.load_file();_new_models(World.PORT_LAYOUT if automated else World.FULL_LAYOUT);_build_world();_build_ui();_apply_settings()
	if not automated:
		_enable_source_hyperdrive()
		_load_game()
	_apply_system();_refresh_hud()
	if notice_timer<=0:_announce("Стик — поворот. Справа — скорость. «Авто» помогает подойти к станции.")
	get_viewport().size_changed.connect(_safe_area)
	_safe_area()
	if "--rebuild-smoke" in OS.get_cmdline_user_args():call_deferred("_run_smoke")

func _new_models(layout:String=World.PORT_LAYOUT)->void:
	_close_map(false)
	instruments.reset();flight_time.reset();last_view="";target_site_id="";target_reference.clear();_thermal_notice_level="";source_contact_last.clear();source_contact_error="";_source_contact_interval.clear()
	source_motion=MotionBridge.new();source_motion_enabled=layout==World.FULL_LAYOUT;last_motion_result.clear()
	ship=Flight.new();nav=NavigationData.new()
	if layout==World.FULL_LAYOUT and not nav.configure_native():push_error("Original galaxy could not be initialized")
	world=World.new();world.configure(nav.current(),layout);surface=Surface.new();near.clear()
	StationSession.configure_flight(ship,world,nav)
	landing_gear=LandingGearSession.new();landing_gear.configure(ship.docked or surface.landed)
	_apply_landing_gear_state()

func _gear_enabled()->bool:return world!=null and world.layout_mode==World.FULL_LAYOUT

func _gear_context()->Dictionary:
	# The complete source player-state dispatcher is not yet connected. Manual
	# flight and the parked-surface phase are explicit phone context adapters.
	var speed:=FuelContact.raw_speed(ship.velocity)
	return {"flight_state_u8":0,"autopilot_phase_u8":0x24 if surface.landed or ship.docked else 0,"speed_s32":speed.get("speed_s32"),"paused":instruments.paused or not active or busy}

func _gear_state()->Dictionary:
	if not _gear_enabled() or landing_gear==null:return {}
	return landing_gear.state(_gear_context())

func _apply_landing_gear_state()->void:
	var current:=_gear_state()
	if surface!=null:surface.set_landing_gear_state(not current.is_empty(),bool(current.get("deployed",true)) and bool(current.get("requested_down",true)),str(current.get("status_text","")))
	if surface!=null:surface.set_source_contact_enabled(world!=null and world.layout_mode==World.FULL_LAYOUT and nav!=null and nav.is_source_hyperdrive())
	if player!=null:
		if current.is_empty():player.clear_gear_fraction_override()
		else:player.set_gear_fraction(float(current.get("extension_fraction",0.0)))

func _source_contact_enabled()->bool:
	return surface!=null and surface.uses_source_contact()

func _source_contact_failed(reason:String)->bool:
	if source_contact_error!=reason:
		source_contact_error=reason
		_record_event("source_surface_contact_error",{"reason":reason,"candidate":surface.pending_source_contact()})
		_announce("Расчёт касания приостановлен. Отправьте отчёт об ошибке или загрузите последнее сохранение.")
		_release_inputs()
	flight_time.interrupt("Ошибка расчёта касания.")
	return false

func _apply_pending_source_contact()->bool:
	var event:Dictionary=surface.pending_source_contact()
	if event.is_empty():return true
	if not _source_contact_enabled():return _source_contact_failed("disabled_contact_provider")
	if event.get("body_id")!=surface.body_id or event.get("frame_index")!=surface.frame_index:return _source_contact_failed("stale_contact_frame")
	var resolution:Dictionary=SurfaceContactBridge.resolve(surface,ship,int(_gear_state().get("position_u16",0)),event)
	if not resolution.get("ok",false):return _source_contact_failed(str(resolution.get("error","contact_bridge_rejected")))
	if not resolution.get("position") is Vector3 or not resolution.position.is_finite() or not resolution.get("velocity") is Vector3 or not resolution.velocity.is_finite() or not resolution.get("attitude") is Quaternion or not resolution.attitude.is_finite() or resolution.attitude.length_squared()<0.5:return _source_contact_failed("invalid_resolved_pose")
	# Any earlier ordinary wall response is explicitly synchronized first.
	# F575 requests then use the same raw hull/shields/RNG as the atmosphere;
	# the validated pose is committed once without another percent penalty.
	if not nav.sync_thermal_ship(ship):return _source_contact_failed("invalid_shared_hp_anchor")
	var damage:Dictionary=nav.apply_contact_damage(resolution.get("damage_calls",[]),ship)
	if not damage.get("ok",false):return _source_contact_failed("contact_damage_rejected")
	var parked:bool=bool(resolution.get("landing_accepted",false)) and bool(_gear_state().get("requested_down",false)) and ship.hull>0
	var hpdetail:Dictionary=damage.get("contact_damage",{})
	surface.finish_source_contact(ship,resolution,parked,hpdetail)
	source_contact_error=""
	var kernel:Dictionary=resolution.get("kernel",{})
	var facts:Dictionary=resolution.get("facts",{})
	var response:Dictionary={}
	for key:String in ["source_contract","landing_accepted","l1_speed_s32","alignment_q31","normal_q31","damage_calls","return_flags_u8"]:response[key]=kernel.get(key)
	source_contact_last={"provider":str(facts.get("provider",event.get("kind","surface"))),"resolution":response,"hpdetail":hpdetail.duplicate(true),"parked":parked,"body_model_index":facts.get("parent_model_index",-1),"ship_model_index":facts.get("model_index",-1),"body_id":surface.body_id,"facts":facts.duplicate(true)}
	_record_event("source_surface_contact",source_contact_last)
	if damage.get("destruction_requested",false):
		_source_contact_interval.clear()
		_source_ship_destroyed("Корабль потерян при ударе о поверхность.","surface_contact_destruction",source_contact_last)
		return false
	return true

func _request_landing_gear(down:bool)->Dictionary:
	if not _gear_enabled() or landing_gear==null:return {"ok":false,"accepted":false,"message":"Управляемые шасси недоступны в этом полёте."}
	var result:Dictionary=landing_gear.command_request(down,_gear_context())
	_apply_landing_gear_state();return result

func _toggle_landing_gear()->void:
	if _paused_command() or busy or not active or ship.hull<=0 or not _gear_enabled() or landing_gear==null:return
	_release_inputs()
	var result:Dictionary=landing_gear.command_toggle(_gear_context())
	_apply_landing_gear_state()
	var feedback:=str(result.get("message","Команда шасси отклонена."))
	if result.get("accepted",false) and saving_enabled and not _save_game():feedback+=" Изменения пока не удалось сохранить."
	_record_event("landing_gear_command",{"accepted":result.get("accepted",false),"position_u16":_gear_state().get("position_u16",0),"requested_down":_gear_state().get("requested_down",false)})
	_announce(feedback);_refresh_hud()

func _step_landing_gear(seconds:float)->bool:
	if not _gear_enabled():_apply_landing_gear_state();return true
	if landing_gear==null:return false
	# The existing phone surface pilot requests extension through the real
	# toggle branch when needed; it does not fabricate native autopilot phases.
	if surface.active and (surface.landing or surface.flight_phase=="descent"):
		var requested:=_request_landing_gear(true)
		if not requested.get("ok",false):return false
	var result:Dictionary=landing_gear.advance_seconds(seconds,_gear_context())
	if not result.get("ok",false):_announce("Не удалось обновить шасси. Сохраните отчёт об ошибке.");return false
	_apply_landing_gear_state()
	if not str(result.get("message","")).is_empty():_announce(str(result.message))
	return true

func _enable_source_hyperdrive()->bool:
	if world.layout_mode!=World.FULL_LAYOUT:return false
	if not nav.configure_source(ship.ship_id,nav.current_id) or not nav.sync_source_ship(ship):
		saving_enabled=false;_announce("Не удалось подготовить исходный гипердвигатель. Сохраните отчёт об ошибке.");return false
	return _apply_source_fuel_state()

func _apply_source_fuel_state()->bool:
	if not nav.bind_thermal_ship(ship):return false
	if not nav.apply_fuel_availability(ship):return false
	return source_motion.synchronize_thrust_limits(ship)

func _build_world()->void:
	environment=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("020712")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("91b5cf");environment.environment.ambient_light_energy=0.3
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;add_child(environment)
	sunlight=DirectionalLight3D.new();sunlight.light_color=Color("ffe9ca");sunlight.light_energy=2.0;sunlight.rotation_degrees=Vector3(-48,-35,0);add_child(sunlight)
	planet_fill=DirectionalLight3D.new();planet_fill.light_color=Color("81bfe8");planet_fill.light_energy=0.65;planet_fill.rotation_degrees=Vector3(-25,145,0);add_child(planet_fill)
	camera=Camera3D.new();camera.fov=74;camera.near=0.5;camera.far=180000;add_child(camera);camera.make_current()
	celestial=Celestial.new();add_child(celestial)
	ground_view=SurfaceView.new();add_child(ground_view);ground_view.hide()
	city_view=CityView.new();add_child(city_view);city_view.hide()
	player=ShipView.new();add_child(player);player.set_quality(settings.quality);player.configure(ship.profile())
	station=StationView.new();add_child(station);station.configure(settings.quality)
	source_station=SourceStationView.new();add_child(source_station);source_station.hide()
	space_environment=SpaceEnvironment.new();add_child(space_environment);space_environment.hide()
	stars=MultiMeshInstance3D.new();var star_mesh:=SphereMesh.new();star_mesh.radius=22;star_mesh.height=44;star_mesh.radial_segments=4;star_mesh.rings=2
	var star_material:=StandardMaterial3D.new();star_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;star_material.vertex_color_use_as_albedo=true;star_mesh.material=star_material
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=star_mesh;multi.instance_count=3200
	var rng:=RandomNumberGenerator.new();rng.seed=784112
	for i in range(multi.instance_count):
		var direction:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(0.35,1.6)),direction*50000))
		multi.set_instance_color(i,Color("c5dcf6").lerp(Color("ffe3b5"),rng.randf()*0.65))
	stars.multimesh=multi;add_child(stars)

func _button(text:String,callback:Callable,width:=150.0)->Button:
	action_buttons=action_buttons.filter(func(item):return is_instance_valid(item) and not item.is_queued_for_deletion())
	var button:=ActionButton.new();button.text=text;button.custom_minimum_size=Vector2(width,76);button.focus_mode=Control.FOCUS_NONE
	action_buttons.append(button)
	button.add_theme_font_size_override("font_size",22);button.pressed.connect(callback);return button
func _label(text:String,size_value:=20)->Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",size_value);return label
func _anchored(node:Control,preset:int,offsets:Vector4)->void:
	ui.add_child(node);node.set_anchors_and_offsets_preset(preset)
	node.offset_left=offsets.x;node.offset_top=offsets.y;node.offset_right=offsets.z;node.offset_bottom=offsets.w

func _build_ui()->void:
	var layer:=CanvasLayer.new();add_child(layer);ui=Control.new();ui.theme=FlightTheme.build();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
	flight_reticle=FlightReticle.new();_anchored(flight_reticle,Control.PRESET_FULL_RECT,Vector4(0,0,0,-FlightConsole.HEIGHT));flight_widgets.append(flight_reticle)
	hud=_label("",20);_anchored(hud,Control.PRESET_TOP_WIDE,Vector4(18,8,-260,38));hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;flight_widgets.append(hud)
	var console_height:float=FlightConsole.HEIGHT
	stick=Stick.new();_anchored(stick,Control.PRESET_BOTTOM_LEFT,Vector4(20,-250-console_height,250,-80-console_height));flight_widgets.append(stick)
	lever=Lever.new();_anchored(lever,Control.PRESET_BOTTOM_RIGHT,Vector4(-115,-315-console_height,-25,-20-console_height));lever.target_changed.connect(_set_speed);flight_widgets.append(lever)
	var caption:=_label("СКОРОСТЬ",16);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(caption,Control.PRESET_BOTTOM_RIGHT,Vector4(-125,-350-console_height,-15,-318-console_height));flight_widgets.append(caption)
	var lift1:=Hold.new();lift1.text="ПОДЪЁМ";_anchored(lift1,Control.PRESET_BOTTOM_RIGHT,Vector4(-275,-230-console_height,-135,-145-console_height));lift1.state_changed.connect(func(value:bool):lift_up=value);holds.append(lift1);flight_widgets.append(lift1)
	var lift2:=Hold.new();lift2.text="СНИЖЕНИЕ";_anchored(lift2,Control.PRESET_BOTTOM_RIGHT,Vector4(-275,-125-console_height,-135,-40-console_height));lift2.state_changed.connect(func(value:bool):lift_down=value);holds.append(lift2);flight_widgets.append(lift2)
	var roll1:=RollControl.new();roll1.direction=-1.0;_anchored(roll1,Control.PRESET_BOTTOM_LEFT,Vector4(20,-74-console_height,126,-10-console_height));roll1.axis_changed.connect(func(value:float):roll_left_strength=value;roll_left=value>0);holds.append(roll1);flight_widgets.append(roll1)
	var roll2:=RollControl.new();roll2.direction=1.0;_anchored(roll2,Control.PRESET_BOTTOM_LEFT,Vector4(144,-74-console_height,250,-10-console_height));roll2.axis_changed.connect(func(value:float):roll_right_strength=value;roll_right=value>0);holds.append(roll2);flight_widgets.append(roll2)
	time_controls=TimeControls.new();_anchored(time_controls,Control.PRESET_TOP_LEFT,Vector4(20,104,356,194));time_controls.rate_requested.connect(_request_time_rate);flight_widgets.append(time_controls)
	flight_console=FlightConsole.new();_anchored(flight_console,Control.PRESET_BOTTOM_WIDE,Vector4(0,-console_height,0,0));flight_widgets.append(flight_console)
	flight_console.system_requested.connect(_show_system);flight_console.routes_requested.connect(_show_routes);flight_console.menu_requested.connect(_show_menu)
	flight_console.view_requested.connect(_cycle_view)
	flight_console.auto_requested.connect(_toggle_auto);flight_console.brake_requested.connect(_brake);flight_console.dock_requested.connect(_dock_action)
	flight_console.status_requested.connect(_show_status);flight_console.equipment_requested.connect(_show_equipment)
	flight_console.control_requested.connect(_toggle_control_mode);flight_console.surface_requested.connect(_surface_action);flight_console.pause_requested.connect(_toggle_pause)
	flight_console.gear_requested.connect(_toggle_landing_gear)
	auto_button=flight_console.buttons.auto;dock_button=flight_console.buttons.dock
	# Preserve the public action reference while using the actual lower-console
	# button. A duplicate floating button would overlap the throttle caption.
	surface_button=flight_console.buttons.surface
	flight_cross=_label("·",27);flight_cross.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(flight_cross,Control.PRESET_CENTER,Vector4(-15,-20-console_height*0.5,15,20-console_height*0.5));flight_cross.mouse_filter=Control.MOUSE_FILTER_IGNORE;flight_widgets.append(flight_cross)
	target_label=_label("",18);target_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(target_label,Control.PRESET_CENTER_TOP,Vector4(-330,40,330,94));target_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	flight_widgets.append(target_label)
	docking_label=_label("",16);docking_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(docking_label,Control.PRESET_CENTER_BOTTOM,Vector4(-360,-70-console_height,360,-8-console_height));docking_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;flight_widgets.append(docking_label)
	notice=_label("",21);notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(notice,Control.PRESET_CENTER_BOTTOM,Vector4(-430,-190-console_height,430,-115-console_height));notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fps_label=_label("",16);_anchored(fps_label,Control.PRESET_BOTTOM_LEFT,Vector4(25,-280-console_height,230,-250-console_height))
	menu=PanelContainer.new();_anchored(menu,Control.PRESET_FULL_RECT,Vector4(140,40,-140,-40))
	var panel_style:=StyleBoxFlat.new();panel_style.bg_color=Color("0c1725");panel_style.content_margin_left=20;panel_style.content_margin_right=20;panel_style.content_margin_top=14;panel_style.content_margin_bottom=14
	panel_style.corner_radius_top_left=12;panel_style.corner_radius_top_right=12;panel_style.corner_radius_bottom_left=12;panel_style.corner_radius_bottom_right=12;menu.add_theme_stylebox_override("panel",panel_style)
	var outer:=VBoxContainer.new();outer.add_theme_constant_override("separation",12);menu.add_child(outer)
	var header:=HBoxContainer.new();outer.add_child(header);menu_title=_label("МЕНЮ",27);menu_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(menu_title);header.add_child(_button("Закрыть",_close_menu,150))
	menu_feedback=_label("",20);menu_feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;menu_feedback.add_theme_color_override("font_color",Color("70d9c8"));outer.add_child(menu_feedback)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(scroll)
	menu_rows=VBoxContainer.new();menu_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;menu_rows.add_theme_constant_override("separation",10);scroll.add_child(menu_rows);menu.hide()
	settings_panel=SettingsPanel.new();ui.add_child(settings_panel);settings_panel.close_requested.connect(_close_settings);settings_panel.changed.connect(_settings_changed)
	settings_panel.export_requested.connect(_show_backup);settings_panel.import_requested.connect(_show_backup)

func _safe_area()->void:
	if ui==null:return
	var padding:=Vector4.ZERO
	if OS.has_feature("android"):
		var window:=DisplayServer.window_get_size();var safe:=DisplayServer.get_display_safe_area();var logical:=get_viewport().get_visible_rect().size
		if window.x>0 and window.y>0:
			padding=Vector4(maxi(0,safe.position.x)*logical.x/window.x,maxi(0,safe.position.y)*logical.y/window.y,maxi(0,window.x-safe.end.x)*logical.x/window.x,maxi(0,window.y-safe.end.y)*logical.y/window.y)
	ui.offset_left=padding.x;ui.offset_top=padding.y;ui.offset_right=-padding.z;ui.offset_bottom=-padding.w
	_update_flight_projection()

func _update_flight_projection()->void:
	if camera==null or ui==null or flight_console==null:return
	var viewport_rect:=get_viewport().get_visible_rect()
	if viewport_rect.size.x<=0 or viewport_rect.size.y<=0:return
	var safe_rect:=ui.get_global_rect()
	var console_top:float=flight_console.get_global_rect().position.y
	flight_view_rect=Rect2(safe_rect.position,Vector2(safe_rect.size.x,maxf(1,console_top-safe_rect.position.y)))
	var signature:=[viewport_rect,flight_view_rect,camera.fov,camera.near,camera.far,camera.keep_aspect]
	if signature==_flight_projection_signature:return
	_flight_projection_signature=signature
	# Keep the same angular scale and physical camera pose. Move only the
	# optical centre to the usable flight window above the opaque console.
	# Frustum size is its vertical span at the near plane, even for KEEP_WIDTH.
	var aspect:float=viewport_rect.size.x/viewport_rect.size.y
	var half_height:float=camera.near*tan(deg_to_rad(camera.fov)*0.5)
	if camera.keep_aspect==Camera3D.KEEP_WIDTH:half_height/=aspect
	var centre:Vector2=flight_view_rect.get_center()-viewport_rect.position
	var offset:=Vector2(half_height*aspect*(1.0-2.0*centre.x/viewport_rect.size.x),half_height*(2.0*centre.y/viewport_rect.size.y-1.0))
	camera.set_frustum(half_height*2.0,offset,camera.near,camera.far)

func _release_inputs()->void:
	if stick:stick.release_pointer()
	if lever:lever.release_pointer()
	for hold in holds:hold.release_pointer()
	for button in action_buttons:
		if is_instance_valid(button):button.release_pointer()
	if flight_console!=null:flight_console.release_pointers()
	if time_controls!=null:time_controls.release_pointers()
	if is_instance_valid(active_map) and active_map.has_method("release_pointers"):active_map.release_pointers()
	if is_instance_valid(dock_services_view):dock_services_view.release_pointers()
	if is_instance_valid(hyperdrive_services_view):hyperdrive_services_view.release_pointers()
	lift_up=false;lift_down=false;roll_left=false;roll_right=false;roll_left_strength=0;roll_right_strength=0
func _blocked()->bool:return busy or not active or menu.visible or settings_panel.visible or is_instance_valid(active_map)
func _physics_process(dt:float)->void:
	if automated:return
	_advance_controls(dt)

func _advance_controls(dt:float)->void:
	if _blocked() or instruments.paused:
		flight_time.interrupt("Полёт приостановлен.");return
	if not surface.pending_source_contact().is_empty():
		_tick(0.0,Vector2.ZERO,0.0)
		return
	var steering:Vector2=stick.value
	steering.x+=float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT))
	steering.y+=float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP))
	var roll:float=(roll_right_strength-roll_left_strength)*0.35+float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))
	var lift:=float(lift_up)-float(lift_down)+float(Input.is_physical_key_pressed(KEY_R))-float(Input.is_physical_key_pressed(KEY_F))
	if Input.is_physical_key_pressed(KEY_W):_set_speed(ship.target_speed+150*dt)
	if Input.is_physical_key_pressed(KEY_S):_set_speed(ship.target_speed-150*dt)
	var manual:bool=stick.pointer_id!=-1 or lever.pointer_id!=-1 or absf(roll)>0.0001 or absf(lift)>0.0001 or steering.length()>0.001 or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_S)
	var plan:Dictionary=flight_time.plan_frame(dt,_time_context(manual))
	if not plan.get("ok",false):return
	var executed:=0;var interrupted:=false
	var frame_identity:=[ship,world,nav.current_id,world.focus_id,world.site_id,surface.active]
	for step:float in plan.steps:
		if not flight_time.can_continue(int(plan.effective_rate),_time_context(manual)):interrupted=true;break
		_tick(step,settings.steer(steering.limit_length()),roll,lift);executed+=1
		if frame_identity!=[ship,world,nav.current_id,world.focus_id,world.site_id,surface.active]:interrupted=true;break
		if not flight_time.can_continue(int(plan.effective_rate),_time_context(manual)):interrupted=true;break
	flight_time.finish_frame(int(plan.token),executed,interrupted)

func _time_context(manual:=false)->Dictionary:
	var result:={"active":active and ship.hull>0,"menu_open":menu.visible or settings_panel.visible or is_instance_valid(active_map),"busy":busy,"paused":instruments.paused,"source_world":world.layout_mode==World.FULL_LAYOUT,"manual_input":manual,"autopilot":ship.autopilot,"landing":surface.landing,"taking_off":surface.taking_off,"docked":ship.docked,"surface_active":surface.active,"combat_active":ship.combat_active,"jump_remaining":nav.remaining,"transfer_remaining":world.transfer_remaining,"speed_mps":ship.velocity.length(),"station_available":ship.station_available}
	if nav.is_source_hyperdrive():
		var thermal:Dictionary=nav.thermal_state(ship)
		result.atmospheric_hazard=bool(thermal.get("atmosphere_active",false)) or float(thermal.get("heat_percent",0.0))>=75.0
	var clearance:=INF
	for body:Dictionary in world.bodies:
		if str(body.kind)=="barycenter":continue
		var centre:Vector3=world.local_meters(str(body.id),nav.elapsed_days)
		var envelope:=maxf(float(body.get("source_outer_bound_m",0.0)),float(body.get("radius_km",0.0))*1000.0)
		var distance:float=ship.position.distance_to(centre)
		if centre.is_finite() and is_finite(distance) and is_finite(envelope):clearance=minf(clearance,distance-envelope)
	if is_finite(clearance):result.body_clearance_m=clearance
	var gravity:Vector3=world.gravity_at(ship.position,nav.elapsed_days) if settings.orbital_gravity else Vector3.ZERO
	if gravity.is_finite():result.gravity_mps2=gravity.length()
	if ship.station_available:
		var bound:=0.0
		if ship.has_source_station():
			var bounds:Variant=ship._source_station.get("bounds")
			if bounds is AABB:bound=bounds.get_center().length()+bounds.size.length()*0.5
		result.station_distance_m=ship.position.distance_to(ship.STATION)-bound
	return result

func _request_time_rate(rate:int)->void:
	if not surface.pending_source_contact().is_empty():return
	var context:=_time_context()
	for option:Dictionary in flight_time.rate_options(context):
		if int(option.rate)!=rate:continue
		if not option.enabled:_announce(str(option.reason));return
		_release_inputs();flight_time.interrupt();flight_time.request_rate(rate);_refresh_hud();return

func _tick(dt:float,steering:Vector2,roll:float,lift:=0.0)->void:
	if instruments.paused or ship.hull<=0:return
	# A queued command or failed prior contact is completed before starting
	# another simulation interval. Failed retries cannot advance gear, clocks
	# or fuel while the unresolved pose is deliberately excluded from saves.
	if not surface.pending_source_contact().is_empty():
		if not _apply_pending_source_contact():return
		if not _source_contact_interval.is_empty():
			var interval:=_source_contact_interval.duplicate(true)
			_source_contact_interval.clear()
			var save_after:bool=_finish_surface_interval(int(interval.frame),bool(interval.was_landed))
			_finish_flight_interval(float(interval.seconds),interval.commands,save_after)
		return
	if not _apply_source_fuel_state():_announce("Не удалось согласовать реактивный бак. Сохраните отчёт об ошибке.");return
	ship.last_propulsive_delta_v=Vector3.ZERO
	var fuel_commands:Array=[0,0,0]
	var save_after_fuel:=false
	if steering.length()>0.04 or absf(roll)>0.05 or absf(lift)>0.1:
		ship.autopilot=false
		if surface.active:surface.landing=false
	if not _step_landing_gear(dt):return
	if nav.remaining>0:
		# New source sessions keep charging time on the same celestial clock.
		# Saves without the opt-in retain their published legacy timing.
		if source_motion_enabled:nav.elapsed_days+=dt/86400.0
		if nav.step(dt,ship):
			world.configure(nav.current(),world.preferred_layout());surface=Surface.new();near.clear();_apply_system();_announce(nav.message);save_after_fuel=true
	elif world.transfer_remaining>0:
		if source_motion_enabled:nav.elapsed_days+=dt/86400.0
		if world.step_transfer(dt,ship,nav):
			# An explicit transfer starts a new local flight. A geographic link
			# from the previous departure belongs to its previous origin/focus.
			surface=Surface.new();near.clear()
			_apply_system();_announce(world.message)
			if not world.current_site().is_empty() and int(world.current_site().type_code)==35:_enter_surface()
			else:save_after_fuel=true
	else:
		nav.elapsed_days+=dt/86400.0
		if surface.active:
			var frame:int=surface.frame_index;var was_landed:bool=surface.landed
			surface.set_source_time(nav.elapsed_days)
			surface.step(dt,ship,steering,roll,lift)
			# Powered impulse belongs to the pre-impact attitude. Native F575
			# may rotate or rebase the ship; it must not relabel fired nozzles.
			fuel_commands=FuelFlightBridge.commands(ship,dt)
			if not surface.pending_source_contact().is_empty():_source_contact_interval={"seconds":dt,"commands":fuel_commands.duplicate(),"frame":frame,"was_landed":was_landed}
			if not _apply_pending_source_contact():return
			_source_contact_interval.clear()
			save_after_fuel=_finish_surface_interval(frame,was_landed)
		else:
			if world.layout_mode==World.FULL_LAYOUT:
				var context:=StationSession.refresh(ship,world,nav,dt)
				if not context.ok:ship.brake();_announce("Не удалось подготовить станцию. Сохраните отчёт об ошибке.");return
				if ship.docked and world.station_launch_ready():
					ship.launch();world.finish_station_launch(not ship.docked)
			if _source_motion_step(dt,steering,roll,lift):fuel_commands=last_motion_result.get("commands_s16",[0,0,0])
			else:
				ship.step(dt,steering,roll,world.gravity_at(ship.position,nav.elapsed_days) if settings.orbital_gravity else Vector3.ZERO,lift)
				fuel_commands=FuelFlightBridge.commands(ship,dt)
			if world.protect_surface(ship,nav.elapsed_days):source_motion.reset();_announce(world.message)
	_finish_flight_interval(dt,fuel_commands,save_after_fuel)

func _finish_surface_interval(frame:int,was_landed:bool)->bool:
	if frame!=surface.frame_index:
		camera.position=surface.rebase_to+surface.frame_rotation*(camera.position-surface.rebase_from)
		camera.quaternion=(surface.frame_rotation*camera.quaternion).normalized()
	var save_after:=false
	if surface.ready_for_orbit:_finish_ascent(false);save_after=true
	if surface.landed and not was_landed:save_after=true
	if not surface.message.is_empty():_announce(surface.message);surface.message=""
	return save_after

func _finish_flight_interval(dt:float,fuel_commands:Array,save_after_fuel:bool)->void:
	_step_source_fuel(dt,fuel_commands)
	if save_after_fuel:_save_game()
	if not ship.last_notice.is_empty():_announce(ship.last_notice);ship.last_notice=""
	save_timer+=dt
	if save_timer>20:save_timer=0;_save_game()

func _step_source_fuel(seconds:float,commands:Array)->void:
	if not nav.is_source_hyperdrive():return
	if commands.size()!=3:_announce("Не удалось рассчитать расход реактивного топлива.");return
	# Only a live physical collision/repair may reanchor the raw-HP adapter.
	# Loading and ordinary saves use strict bind instead, preserving exact HP.
	if not nav.sync_thermal_ship(ship):_announce("Не удалось согласовать состояние корпуса. Сохраните отчёт об ошибке.");return
	if ship.hull<=0:_source_ship_destroyed("Корабль потерян при столкновении.","physical_collision");return
	# The historical thermal argument name gear_down carries the RAW E9 bit2:
	# SET requests retraction, CLEAR requests deployment. Physical readiness
	# comes separately from object+9E==FFFF and must not invert this input.
	var context:Dictionary=atmosphere_contact.sample(world,ship,surface,nav.elapsed_days,bool(_gear_state().get("f1014_raw_gear_flag",false)))
	if not context.get("ok",false):_announce("Не удалось определить состояние атмосферы. Сохраните отчёт об ошибке.");return
	var raw_motion:bool=not surface.active and source_motion.is_active() and source_motion.synchronized(world,ship,nav.elapsed_days)
	if raw_motion:
		context.velocity_s32=source_motion.velocity_words()
		var exact_speed:=AtmosphereContact.raw_speed_words(context.velocity_s32)
		if not exact_speed.get("ok",false):return
		context.speed_s32=int(exact_speed.speed_s32)
	if int(context.contact.get("flags_u8",0))&0x80 and int(context.contact.get("parent_model_u32",0))>=134 and int(context.contact.get("parent_model_u32",0))<=148:
		# The read-only source field is probed at the phone ship's centre. This
		# fatal contact guard is an explicit adapter, not F575's hull response.
		_source_ship_destroyed("Корабль потерян: столкновение с недоступной поверхностью звезды или газового гиганта.","source_fuel_body_contact",{"body_id":str(context.get("body_id","")),"flags":int(context.contact.flags_u8),"response_policy":"phone-point-solid-contact-fatality-v1"});return
	context["commands_s16"]=commands
	context["thermal"]={"apply_f1014":bool(context.apply_f1014),"altitude_s32":int(context.altitude_s32),"speed_s32":int(context.speed_s32),"velocity_s32":context.velocity_s32.duplicate(),"shielding":bool(nav.fuel_state(ship).get("atmospheric_shielding_installed",false)),"gear_down":bool(context.gear_down),"wind_enabled":false,"wind_armed":false,"parent_shield_s16":0,"wind_flags_u8":0}
	var result:Dictionary=nav.advance_fuel_seconds(seconds,context,ship)
	if not result.get("ok",false):_announce("Топливная система отклонила состояние. Сохраните отчёт об ошибке.");return
	var thermal_result:Dictionary=result.get("thermal",{})
	if thermal_result.get("velocity_changed",false):
		var before:Array=thermal_result.velocity_before_s32;var after:Array=thermal_result.velocity_after_s32
		if not raw_motion or not source_motion.apply_velocity_words(after,ship):
			# The ordinary and surface controllers retain their SI residual.
			# Only the source integer-word DELTA crosses this explicit frame boundary.
			if source_motion.is_active():source_motion.reset()
			var delta:=Vector3(int(after[0])-int(before[0]),int(after[1])-int(before[1]),int(after[2])-int(before[2]))*float(context.velocity_unit_mps)
			ship.velocity+=Basis(context.velocity_to_phone_basis)*delta
	if not _apply_source_fuel_state():_announce("Не удалось согласовать тягу после заправки.");return
	if result.get("destruction_requested",false):
		_source_ship_destroyed("Корабль потерян: перегрев и разрушение корпуса.","thermal_destruction",{"heat":nav.fuel_state(ship).get("heat_s32",0)});return
	var fuel_notice:=""
	if 0x9907 in result.get("jet_events",[]):fuel_notice="Реактивный бак пуст. Прямая и подъёмная тяга недоступны; заправьте бак из груза через «Оснащение»."
	if int(result.get("scooped_tonnes",0))>0:
		fuel_notice="Топливозаборник собрал водород: +%d т в трюм."%int(result.scooped_tonnes);_record_event("fuel_scooped",{"tonnes":int(result.scooped_tonnes),"body_id":str(context.get("body_id",""))})
	if result.get("hyperjump_cancelled",false):fuel_notice+=" Заряд гипердвигателя отменён: запас грузового топлива изменился."
	var thermal_state:Dictionary=nav.thermal_state(ship);var severity:=str(thermal_state.get("thermal_severity","unknown"))
	if severity!=_thermal_notice_level:
		if severity in ["warning","danger","critical"]:fuel_notice=str(thermal_state.get("thermal_status",""))+" "+str(thermal_state.get("escape_guidance",""))
		_thermal_notice_level=severity
	if float(thermal_result.get("hull_percent_after",ship.hull))<float(thermal_result.get("hull_percent_before",ship.hull)):
		_record_event("atmospheric_hull_damage",{"hull":ship.hull,"heat":nav.fuel_state(ship).get("heat_s32",0),"body_id":str(context.get("body_id","")),"equipment_effect_requested":thermal_result.get("equipment_damage_requested",false)})
	if not fuel_notice.is_empty():_announce(fuel_notice.strip_edges())

func _source_ship_destroyed(reason:String,event:String,details:Dictionary={})->void:
	ship.hull=0;ship.autopilot=false
	if nav.remaining>0:nav.cancel_jump()
	if world.transfer_remaining>0:world.cancel_transfer()
	source_motion.reset();nav.sync_thermal_ship(ship)
	_record_event(event,details);_announce(reason);_save_game()

func _source_motion_step(dt:float,steering:Vector2,roll:float,lift:float)->bool:
	if not source_motion_enabled or not settings.orbital_gravity or not MotionBridge.eligible(world,ship,surface.active) or dt>MotionBridge.MAX_STEP_SECONDS or absf(lift)>0.000001:
		source_motion.reset();return false
	var previous:Quaternion=ship.attitude
	var turn:float=ship.profile().turn_rate
	var local_rotation:=Quaternion(Vector3.UP,-steering.x*dt*turn)*Quaternion(Vector3.RIGHT,-steering.y*dt*turn)*Quaternion(Vector3.FORWARD,roll*dt*turn/1.2)
	ship.attitude=(previous*local_rotation).normalized()
	last_motion_result=source_motion.step(dt,ship,world,nav.elapsed_days,lift)
	if last_motion_result.get("ok",false) and last_motion_result.get("handled",false):return true
	ship.attitude=previous
	if not last_motion_result.get("ok",false):source_motion.reset()
	return false

func _update_flight_controls()->void:
	var blocked:=_blocked()
	for item in flight_widgets:item.visible=not blocked
	var contact_pending:bool=not surface.pending_source_contact().is_empty()
	stick.input_allowed=not blocked and not contact_pending and not instruments.paused and not ship.docked and ship.hull>0
	lever.input_allowed=stick.input_allowed
	for hold in holds:hold.input_allowed=stick.input_allowed
	flight_console.set_actions_enabled(not blocked)
	if contact_pending and not blocked:
		# Keep Menu's touch ownership across frames while flight controls
		# are frozen, so report/reload remains reachable on the phone.
		for button in flight_console._all_pointer_buttons():
			if button!=flight_console.buttons.menu:button.input_allowed=false
	if time_controls!=null:time_controls.set_actions_enabled(not blocked and not contact_pending)
	if is_instance_valid(active_map):active_map.set("input_allowed",active and not busy)
	if is_instance_valid(hyperdrive_services_view):hyperdrive_services_view.input_allowed=active and not busy
	for button in action_buttons:
		if is_instance_valid(button):button.input_allowed=active and not busy
	if is_instance_valid(dock_services_view):
		for button in dock_services_view.action_buttons:button.input_allowed=active and not busy
func _process(dt:float)->void:
	_update_flight_controls()
	if not active:return
	_pump_information()
	_pump_target_reference()
	var blocked:=_blocked()
	# Publishing completed geometry can move the physical contact frame. Keep
	# that publication frozen with simulation while a modal screen is open.
	if not instruments.paused and not blocked and surface.pending_source_contact().is_empty():
		_pump_underground_geometry()
		if not busy:_sync_scene()
		if surface.active:camera.position+=surface.consume_render_frame_shift()
	player.position=ship.position;player.quaternion=ship.attitude;player.visible=ship.external_view
	player.set_thrust(0.0 if ship.docked or surface.landed else clampf(maxf(absf(ship.target_speed),ship.velocity.length())/ship.MAX_SPEED,0.04,1.0))
	player.set_landed(surface.landed)
	_apply_landing_gear_state()
	var pose:=instruments.camera_pose(ship.position,ship.attitude,ship.external_view,float(ship.profile().visual_span_m))
	var desired:Vector3=pose.position;var attitude:Quaternion=pose.attitude
	var current_view:=instruments.view_key(ship.external_view)
	if last_view!=current_view:camera.position=desired;camera.quaternion=attitude;last_view=current_view
	last_external=ship.external_view
	camera.position=camera.position.lerp(desired,minf(1,dt*30));camera.quaternion=camera.quaternion.slerp(attitude,minf(1,dt*25))
	_update_flight_projection()
	notice_timer=maxf(0,notice_timer-dt);notice.visible=notice_timer>0 and not menu.visible and not settings_panel.visible and not is_instance_valid(active_map)
	menu_feedback.visible=notice_timer>0 and not menu_feedback.text.is_empty()
	hud_timer+=dt
	if hud_timer>0.15:hud_timer=0;_refresh_hud()
	lever.display_value(ship.target_speed)
	flight_reticle.update_state(ship.hull,ship.velocity.length())
	if not automated and not blocked:
		diagnostic_timer+=dt
		if diagnostic_timer>=2.0:
			diagnostic_timer=0;last_flight_sample=_flight_diagnostic_sample();_record_event("flight_sample",last_flight_sample)

func _record_event(event:String,details:Dictionary={})->void:
	if diagnostics!=null and not automated:diagnostics.record(event,details)
func _input_diagnostic_state()->Dictionary:
	return {"stick":[stick.value.x,stick.value.y] if stick!=null else [],"stick_pointer":stick.pointer_id if stick!=null else -1,"throttle_pointer":lever.pointer_id if lever!=null else -1,"lift_up":lift_up,"lift_down":lift_down,"roll_left":roll_left_strength,"roll_right":roll_right_strength,"active":active,"busy":busy,"menu_open":menu!=null and menu.visible,"settings_open":settings_panel!=null and settings_panel.visible,"map_open":is_instance_valid(active_map),"map_kind":active_map_kind,"camera_view":instruments.view_key(ship.external_view) if ship!=null else "front","simulation_paused":instruments.paused,"time_rate":flight_time.effective_rate,"source_motion_enabled":source_motion_enabled,"source_motion_active":source_motion.is_active()}
func _flight_diagnostic_sample()->Dictionary:
	if ship==null or nav==null or world==null or surface==null:return {}
	return {"ship_id":ship.ship_id,"position":[ship.position.x,ship.position.y,ship.position.z],"velocity":[ship.velocity.x,ship.velocity.y,ship.velocity.z],"target_speed":ship.target_speed,"hull":ship.hull,"docked":ship.docked,"autopilot":ship.autopilot,"system_id":nav.current_id,"focus_id":world.focus_id,"site_id":world.site_id,"jump_remaining":nav.remaining,"transfer_remaining":world.transfer_remaining,"surface":surface.active,"landed":surface.landed,"flight_phase":surface.flight_phase,"surface_motion":{"landing":surface.landing,"taking_off":surface.taking_off,"altitude_m":surface.altitude(ship) if surface.active else 0.0,"pad_distance_m":surface.pad_distance(ship) if surface.active else 0.0},"controls":_input_diagnostic_state(),"source_fuel":nav.fuel_state(ship),"landing_gear":_gear_state(),"source_contact":source_contact_last.duplicate(true),"source_contact_error":source_contact_error,"pending_source_contact":surface.pending_source_contact(),"deferred_contact_interval":_source_contact_interval.duplicate(true)}
func _diagnostic_context()->Dictionary:
	var context:=_base_diagnostic_context()
	if world!=null and world.layout_mode==World.FULL_LAYOUT:
		context.session["source_station"]=StationSession.diagnostics(ship,world,nav)
		context.session["source_world_contract"]=world.full_system_state.duplicate(true)
		context.session["source_surface_stream"]=ground_view.source_stream_stats() if ground_view!=null else {}
		if surface!=null and surface.source_surface():context.session["source_terrain_cache"]=surface.globe.cache_stats()
	return context
func _base_diagnostic_context()->Dictionary:
	return {"build":{"version":BuildInfo.VERSION,"code":BuildInfo.VERSION_CODE,"channel":BuildInfo.CHANNEL},"mode":"graphics_preview" if not graphics_return.is_empty() else ("surface" if surface!=null and surface.active else "space"),"flight":_flight_diagnostic_sample(),"last_flight_sample":last_flight_sample,"settings":settings.snapshot(),"session":{"saving_enabled":saving_enabled,"save_generation":saves.sequence,"elapsed_days":nav.elapsed_days if nav!=null else 0,"source_clock":SourceClock.from_elapsed_days(nav.elapsed_days) if nav!=null else {},"source_runtime":world.source_runtime_state.duplicate(true) if world!=null else {},"source_orbit":world.orbit_backend_state.duplicate(true) if world!=null else {},"source_ports":world.port_backend_state.duplicate(true) if world!=null else {},"source_physics":world.source_physics_state.duplicate(true) if world!=null else {},"world_layout":world.layout_mode if world!=null else "","preferred_world_layout":world.preferred_layout() if world!=null else "","source_port_position_au":world.site_position_au(world.site_id,nav.elapsed_days) if world!=null and nav!=null else [],"origin_au":world.origin_au(nav.elapsed_days) if world!=null and nav!=null else []},"display":{"fps":Engine.get_frames_per_second(),"viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]}}

func _station_here()->bool:return not surface.active and (world.is_orbital_site() or (world.site_id.is_empty() and world.focus_id==world.default_id and nav.has_station()))
func _apply_system()->void:
	_validate_navigation_target()
	if source_motion.is_active() and (not MotionBridge.eligible(world,ship,surface.active) or not source_motion.synchronized(world,ship,nav.elapsed_days)):source_motion.reset()
	ship.original_port=not world.current_site().is_empty();ship.station_available=_station_here()
	if world.layout_mode==World.FULL_LAYOUT:
		var context:=StationSession.configure_flight(ship,world,nav)
		if not context.ok:_announce("Не удалось подготовить исходную станцию. Сохраните отчёт об ошибке.")
	else:ship.clear_source_station()
	celestial.configure(world);celestial.set_quality(settings.quality);player.configure(ship.profile())
	_apply_landing_gear_state()
	player.set_quality(settings.quality);station.configure(settings.quality);city_view.set_quality(settings.quality)
	if not graphics_return.is_empty():space_environment.configure(ship.STATION,settings.quality)
	station.position=ship.STATION;camera.position=ship.position;camera.quaternion=ship.attitude;presentation_key="";_sync_scene();_update_flight_projection()

func _sync_source_station()->void:
	var visible_source:bool=_station_here() and world.layout_mode==World.FULL_LAYOUT and not near.active
	source_station.visible=visible_source
	if not visible_source:return
	var state:Dictionary=world.source_station_state(nav.elapsed_days)
	var site:Dictionary=world.current_site()
	var key:="%s:%s:%d:%d"%[world.source_digest,world.site_id,int(site.get("source_seed",0)),int(state.get("door_u16",0))]
	if key!=source_station_key:
		var geometry:Dictionary=world.source_station_geometry(nav.elapsed_days)
		if not source_station.configure(geometry):source_station.hide();return
		source_station_key=key
	source_station.set_quality(settings.quality)
	source_station.transform=Transform3D(world.source_station_basis(nav.elapsed_days),ship.STATION)

func _pump_underground_geometry()->void:
	if hatch_worker!=null:
		if hatch_worker.is_alive():return
		var bundle:Variant=hatch_worker.wait_to_finish();hatch_worker=null
		if hatch_owner==surface and surface.active and bundle is Dictionary:
			surface.publish_underground_geometry(bundle,ship)
		hatch_owner=null
	if surface.active and surface.underground!=null and surface.underground.dirty:
		hatch_owner=surface
		var controller:RefCounted=surface.underground
		hatch_worker=Thread.new();hatch_worker.start(func():return controller.prepare_pending())

func _sync_scene()->void:
	var draw:RefCounted=surface if surface.active else null
	if surface.active:near.clear()
	elif not busy and near.update(surface,ship,world,nav.elapsed_days):draw=near.drawing
	var preview:bool=near.active;var high:bool=surface.active and surface.globe!=null and surface.extended_flight
	var layered:bool=preview or high
	var frame:Transform3D=near.frame if preview else (Near.world_frame(surface.globe,world,nav.elapsed_days) if high else Transform3D.IDENTITY)
	var to_scene:Transform3D=frame.affine_inverse() if high else Transform3D.IDENTITY
	var observer:Vector3=frame*ship.position if high else ship.position
	var blend:float=near.space_blend if preview else (Near.far_blend(surface.geoid_height(ship)) if high else 0.0)
	position=-ship.position if not surface.active else Vector3.ZERO
	ground_view.visible=draw!=null;ground_view.transform=near.frame if preview else Transform3D.IDENTITY
	if not city_view.configure(draw,ground_view.transform,1.0-blend if layered else 1.0):push_error(city_view.last_error)
	celestial.transform=to_scene;celestial.visible=not surface.active or high
	station.visible=_station_here() and not preview and world.layout_mode!=World.FULL_LAYOUT
	_sync_source_station()
	planet_fill.visible=not surface.active or high
	space_environment.visible=station.visible and not graphics_return.is_empty()
	if space_environment.visible:space_environment.update_view(ship.position)
	if layered:
		var turn:Quaternion=frame.basis.get_rotation_quaternion().slerp(Quaternion.IDENTITY,blend)
		var origin:Vector3=frame.origin.lerp(observer,blend)
		stars.transform=to_scene*Transform3D(Basis(turn),observer+origin-observer)
	else:stars.transform=Transform3D(Basis.IDENTITY,ship.position if not surface.active else Vector3.ZERO)
	var key:="space" if draw==null else str(draw.kind)+":"+str(settings.quality)
	if key!=presentation_key:presentation.apply(environment.environment,draw if draw!=null else surface,settings.quality);presentation_key=key
	if draw!=null:
		ground_view.configure(draw);ground_view.set_view_coverage(1.0-blend if layered else 1.0)
		var height:float=near.height if preview else surface.altitude(ship)
		camera.far=6000000.0 if draw.extended_flight else 180000.0;camera.near=2.0 if height>5000 else 0.5
		presentation.update_height(environment.environment,draw,height,settings.quality,blend)
		stars.visible=draw.kind!="earth" or (draw.extended_flight and height>15000)
	else:camera.far=180000;camera.near=0.5;stars.visible=true
	celestial.set_source_ground_patch(ground_view.source_ground_patch_context() if layered and draw!=null else null)
	celestial.set_surface_transition(layered,blend if layered else 1.0)
	if celestial.visible:celestial.update_view(nav.elapsed_days,camera.position)
	if world.layout_mode==World.FULL_LAYOUT:
		var light:Dictionary=celestial.source_light(world.focus_id,nav.elapsed_days)
		if not light.is_empty():
			var direction:Vector3=light.direction_world
			if direction.is_finite() and direction.length_squared()>0.5:
				var up:=Vector3.RIGHT if absf(direction.dot(Vector3.UP))>0.99 else Vector3.UP
				sunlight.global_basis=Basis.looking_at(-direction,up)

func _refresh_hud()->void:
	var space_context:String=str(world.by_id[world.focus_id].name)
	if world.layout_mode in [World.PORT_LAYOUT,World.FULL_LAYOUT] and world.is_orbital_site():space_context=str(world.current_site().name)
	var state:="СТЫКОВКА" if ship.docked else ("ПОСАДКА" if surface.landed else ("АВТО" if ship.autopilot or surface.landing or not surface.flight_phase.is_empty() else "ПОЛЁТ"))
	if ship.hull<=0:state="КОРАБЛЬ ПОТЕРЯН"
	hud.text="%s · %s · %s"%["Графический полёт" if not graphics_return.is_empty() else nav.current().name,ship.profile().name,state]
	auto_button.text="Службы" if ship.docked else ("На орбиту" if surface.active and surface.landed and surface.globe!=null else ("Отмена" if ship.autopilot or surface.landing or not surface.flight_phase.is_empty() else "Авто"))
	dock_button.text="Взлететь" if surface.landed else ("Вылететь" if ship.docked else "Посадка" if surface.active else "Стыковка")
	surface_button.text="Взлететь" if surface.active and surface.landed else ("На орбиту" if surface.active else "К поверхности")
	var navigation_target:=_navigation_target()
	var target:Vector3=navigation_target.position
	if surface.active:target_label.text="%s · высота %.0f м\nДо площадки %.0f м"%[surface.site_name if not surface.site_name.is_empty() else world.by_id[world.focus_id].name,maxf(0,surface.altitude(ship)),surface.pad_distance(ship)]
	else:target_label.text="%s · до цели %.0f м"%[navigation_target.label,ship.position.distance_to(target)]
	var console_state:={
		"actual_speed_mps":ship.velocity.length(),"target_speed_mps":ship.target_speed,
		"surface_active":surface.active,"altitude_m":surface.altitude(ship) if surface.active else 0.0,
		"target_distance_m":ship.position.distance_to(target),"target_local":Basis(ship.attitude).inverse()*(target-ship.position),
		"hull_percent":ship.hull,"fuel":nav.fuel,"fuel_capacity":nav.fuel_capacity(),
		"cargo_t":ship.total_cargo(),"cargo_capacity_t":ship.cargo_capacity(),"totalcredits":ship.credits,"elapsed_days":nav.elapsed_days,
		"assisted":ship.assisted,"autopilot":ship.autopilot,"landing":surface.landing,"taking_off":surface.taking_off,
		"landed":surface.landed,"docked":ship.docked,"flight_phase":surface.flight_phase,"external_view":ship.external_view,
		"view_label":instruments.view_label(ship.external_view),"simulation_paused":instruments.paused,
		"control_enabled":_control_mode_available(),"surface_enabled":not instruments.paused and ship.hull>0,
		"contextlabel":surface.site_name if surface.active and not surface.site_name.is_empty() else space_context,
		"auto_text":auto_button.text,"dock_text":dock_button.text,"surface_text":surface_button.text}
	var gear:=_gear_state()
	if not gear.is_empty():
		console_state.merge({"gear_available":true,"gear_enabled":ship.hull>0 and bool(gear.get("can_toggle",false)),"gear_text":str(gear.get("command_label","Шасси")),"gear_status":str(gear.get("status_text","")),"gear_fraction":float(gear.get("extension_fraction",0.0))})
	flight_console.configure_state(console_state)
	fps_label.visible=settings.show_fps;fps_label.text="%d FPS"%Engine.get_frames_per_second()
	if time_controls!=null:time_controls.configure_state({"options":flight_time.rate_options(_time_context()),"requested_rate":flight_time.requested_rate,"applied_rate":flight_time.effective_rate,"paused":instruments.paused,"reason":flight_time.last_reason})
	if docking_label!=null:
		docking_label.text=""
		if ship.has_source_station() and not ship.docked and ship.has_method("source_docking_telemetry"):
			var docking:Dictionary=ship.source_docking_telemetry()
			if docking.get("sample_valid",false):
				var spin:Vector3=docking.get("station_angular_velocity_world_rad_s",Vector3.ZERO)
				docking_label.text="Крен к проёму: %+.1f° · вращение %.2f°/с\nОтносительная скорость %.1f м/с"%[rad_to_deg(float(docking.get("roll_error_rad",0))),rad_to_deg(spin.length()),Vector3(docking.get("relative_linear_velocity_mps",Vector3.ZERO)).length()]

func _navigation_target()->Dictionary:
	if surface.active:return {"position":surface.pad_position(),"label":surface.site_name}
	if not target_site_id.is_empty():
		var site:Dictionary=world.get_site(target_site_id)
		if not site.is_empty() and str(site.parent)==world.selected_id:
			if int(site.type_code) in [32,33,34]:return {"position":world.site_local_meters(target_site_id,nav.elapsed_days),"label":str(site.name)}
			_request_target_reference()
			if target_reference.get("site_id")==target_site_id and target_reference.get("system_id")==nav.current_id:
				return {"position":world.local_meters(str(site.parent),nav.elapsed_days)+world.body_rotation_basis(str(site.parent),nav.elapsed_days)*Vector3(target_reference.body_fixed_m),"label":str(site.name)}
	var id:String=world.selected_id if world.by_id.has(world.selected_id) else world.focus_id
	if id==world.focus_id and _station_here():return {"position":ship.STATION,"label":str(world.current_site().get("name",world.by_id[id].name))}
	return {"position":world.local_meters(id,nav.elapsed_days),"label":str(world.by_id[id].name)}

func _validate_navigation_target()->void:
	if target_site_id.is_empty():return
	var site:Dictionary=world.get_site(target_site_id)
	if site.is_empty() or str(site.parent)!=world.selected_id:
		target_site_id="";target_reference.clear()

func _request_target_reference()->void:
	if target_worker!=null or target_site_id.is_empty() or world.layout_mode!=World.FULL_LAYOUT:return
	if target_reference.get("site_id")==target_site_id and target_reference.get("system_id")==nav.current_id:return
	var site:Dictionary=world.get_site(target_site_id)
	if site.is_empty() or int(site.type_code)!=35 or not world.by_id.has(str(site.parent)):return
	var body:Dictionary=world.by_id[str(site.parent)]
	var record:=str(body.get("runtime_record_hex","")).hex_decode()
	if record.size()!=68:return
	var radius:=float(body.radius_km)*1000.0;var copied_site:=site.duplicate(true)
	var system_id:int=nav.current_id;var requested_site:=target_site_id
	if target_job_world==world and target_job_key==str(system_id)+":"+requested_site:return
	target_job_key=str(system_id)+":"+requested_site
	target_job_world=world
	target_worker=Thread.new()
	target_worker.start(func():
		var profile:Dictionary=SourceTerrain.source_city_profile(copied_site,record,radius)
		var raw:Variant=profile.get("source_root_raw")
		if not raw is PackedInt64Array or raw.size()!=3:return {}
		return {"system_id":system_id,"site_id":requested_site,"body_fixed_m":Vector3(SourceUnits.metres(float(raw[0])),SourceUnits.metres(float(raw[1])),SourceUnits.metres(float(raw[2])))}
	)

func _pump_target_reference()->void:
	if target_worker==null or target_worker.is_alive():return
	var result:Variant=target_worker.wait_to_finish();target_worker=null
	if target_job_world!=world:return
	if not result is Dictionary or result.get("site_id")!=target_site_id or result.get("system_id")!=nav.current_id:return
	if result.get("body_fixed_m") is Vector3 and result.body_fixed_m.is_finite():target_reference=result

func _announce(text:String)->void:
	_record_event("notice",{"text":text})
	if notice:notice.text=text;notice_timer=7
	if menu_feedback:menu_feedback.text=text
	if settings_panel and settings_panel.visible:settings_panel.feedback.text=text
func _set_speed(value:float)->void:
	if instruments.paused or not surface.pending_source_contact().is_empty():return
	ship.autopilot=false;ship.target_speed=clampf(value,-100,ship.MAX_SPEED)
	if surface.active:surface.landing=false;surface.cancel_vertical()
func _brake()->void:
	if _paused_command():return
	ship.brake();_release_inputs()
	if surface.active:surface.landing=false;surface.cancel_vertical()
	if nav.remaining>0:nav.cancel_jump()
	if world.transfer_remaining>0:world.cancel_transfer()
	if world.layout_mode==World.FULL_LAYOUT:world.cancel_station_launch()
	_announce("Торможение и удержание скорости.")
func _toggle_auto()->void:
	if _paused_command():return
	if ship.hull<=0:return
	if surface.active:
		if surface.landed:_begin_departure_action()
		elif surface.landing or not surface.flight_phase.is_empty():surface.landing=false;surface.cancel_vertical();_announce("Автоматический полёт отменён.")
		else:
			if _gear_enabled():_request_landing_gear(true)
			surface.begin_landing(ship);_announce(surface.message)
	elif ship.docked:_show_services()
	elif not target_site_id.is_empty() and target_site_id!=world.site_id:_choose_site(target_site_id)
	elif world.selected_id!=world.focus_id:_choose_body(world.selected_id)
	elif not _station_here():_announce("Автоподход доступен у станции. Выберите объект в системе.")
	else:
		ship.autopilot=not ship.autopilot
		if ship.autopilot and world.layout_mode==World.FULL_LAYOUT and not world.request_station_open(nav.elapsed_days):ship.autopilot=false
		_announce("Автоподход к станции." if ship.autopilot else "Автоподход отменён.")
func _begin_departure_action()->bool:
	if _paused_command():return false
	if busy:return false
	_release_inputs()
	var accepted:bool=surface.begin_departure(ship)
	var departure_message:String=surface.message
	if accepted:
		_close_menu()
		if saving_enabled and not _save_game():departure_message+=" Текущий полёт пока не удалось сохранить."
	_record_event("surface_departure",{"accepted":accepted,"flight_phase":surface.flight_phase,"hull":ship.hull})
	_announce(departure_message);_refresh_hud()
	return accepted
func _takeoff_action()->bool:
	if _paused_command():return false
	var previous_controls:=_input_diagnostic_state()
	_release_inputs()
	var accepted:bool=surface.take_off(ship)
	_record_event("surface_takeoff",{"accepted":accepted,"controls_before_release":previous_controls,"hull":ship.hull,"landed":surface.landed,"taking_off":surface.taking_off})
	_announce(surface.message);_refresh_hud()
	return accepted
func _dock_action()->void:
	if _paused_command():return
	if surface.active:
		if surface.landed:_takeoff_action();return
		if _gear_enabled():_request_landing_gear(true)
		if not surface.touch_down(ship):
			if not surface.landing:surface.begin_landing(ship)
			else:surface.message="Посадочный заход продолжается. Дождитесь готовности шасси и касания."
		elif not _apply_pending_source_contact():return
		_announce(surface.message)
	elif ship.docked:
		_release_inputs()
		if ship.has_source_station() and world.layout_mode==World.FULL_LAYOUT:
			if not world.request_station_open(nav.elapsed_days,true):_announce("Не удалось запросить открытие стыковочного проёма.");return
		ship.launch()
		if world.layout_mode==World.FULL_LAYOUT:world.finish_station_launch(not ship.docked)
		_announce("Люк закрыт: вылет ожидает открытия." if ship.docked else "Вылет начат. Корабль выходит из ангара.")
		_save_game()
	elif ship.dock():_announce("Стыковка выполнена. Службы доступны в меню.");_save_game()
	else:_announce("Для стыковки: дистанция до 100 м и скорость до 12 м/с. Используйте «Авто».")

func _surface_action()->void:
	if _paused_command():return
	if busy:return
	if surface.active:
		if surface.landed:_takeoff_action()
		elif surface.globe!=null:
			if surface.flight_phase=="ascent":_announce("Автоподъём уже выполняется. «Тормозить» или «Отмена» остановят его.")
			else:_begin_departure_action()
		elif surface.begin_ascent(ship):_announce(surface.message)
		else:_announce(surface.message)
	else:await _enter_surface()
func _enter_surface()->void:
	if _paused_command():return
	if busy:return
	if nav.remaining>0:_announce("Сначала отмените гиперпереход кнопкой «Тормозить».");return
	if world.transfer_remaining>0:_announce("Сначала отмените автоперелёт кнопкой «Тормозить».");return
	surface.set_source_time(nav.elapsed_days)
	if not surface.entry_error(ship,world).is_empty():_announce(surface.entry_error(ship,world));return
	var site:Dictionary=world.current_site()
	var entry_ship:RefCounted=ship;var entry_world:RefCounted=world
	if world.layout_mode==World.FULL_LAYOUT:
		var snapshot:=Surface.create_entry_snapshot(world,ship,nav.elapsed_days)
		if snapshot.is_empty():_announce("Не удалось подготовить исходную поверхность.");return
		busy=true;_release_inputs();_announce("Подготовка поверхности и космопорта…")
		await get_tree().process_frame
		worker=Thread.new();worker.start(func():return Surface.prepare_entry(snapshot))
		while worker.is_alive():await get_tree().process_frame
		var result:Variant=worker.wait_to_finish();worker=null;busy=false
		if ship!=entry_ship or world!=entry_world or nav.remaining>0 or world.transfer_remaining>0:return
		if not result is Dictionary or not result.get("ok",false):_announce("Не удалось подготовить исходный космопорт.");return
		if not surface.entry_error(ship,world).is_empty():_announce(surface.entry_error(ship,world));return
		if not surface.install_prepared_entry(result,world,ship):_announce("Условия входа изменились. Повторите команду.");return
	elif not site.is_empty() and int(site.get("model_index",-1))>=81 and int(site.get("model_index",-1))<=90:
		var profile:Dictionary=CityProfile.describe(site,float(world.by_id[world.focus_id].radius_km)*1000.0)
		if profile.is_empty():_announce("Не удалось подготовить посадочную площадку.");return
		busy=true;_release_inputs();_announce("Подготовка космопорта…")
		await get_tree().process_frame
		worker=Thread.new();worker.start(func():return CityRuntime.prepare(profile))
		while worker.is_alive():await get_tree().process_frame
		var result:Variant=worker.wait_to_finish();worker=null;busy=false
		if not result is Dictionary or not result.get("ok",false):_announce("Космопорт пока недоступен в этой сборке.");return
		if ship!=entry_ship or world!=entry_world or nav.remaining>0 or world.transfer_remaining>0:return
		if not surface.entry_error(ship,world).is_empty():_announce(surface.entry_error(ship,world));return
	if near.enter_descent(surface,ship,world,nav.elapsed_days):_apply_system();_announce(surface.message);_save_game()
	else:_announce(surface.message)
func _finish_ascent(save_progress:=true)->void:
	if not surface.leave(ship,world,nav.elapsed_days):_announce(surface.message);return
	_apply_system();_announce("Выход на орбиту. Положение над планетой сохранено.")
	if save_progress:_save_game()

func _open_menu(title:String,save_progress:bool=true)->void:
	_close_map(false);flight_time.interrupt("Открыто меню.")
	_record_event("menu_open",{"title":title,"controls_before_release":_input_diagnostic_state()})
	_release_inputs()
	if save_progress:_save_game()
	menu_title.text=title
	_clear_menu_rows()
	menu.show()
	_update_flight_controls()

func _clear_menu_rows()->void:
	for child in menu_rows.get_children():menu_rows.remove_child(child);child.queue_free()
	dock_services_view=null
func _menu_text(text:String)->void:
	var label:=_label(text,21);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=900;menu_rows.add_child(label)
func _menu_action(text:String,callback:Callable)->void:
	menu_rows.add_child(_button(text,callback,900))
func _close_menu()->void:_close_map(false);menu.hide();backup_edit=null;_release_inputs();_update_flight_controls()

func _cycle_view()->void:
	if _blocked():return
	_release_inputs();ship.external_view=instruments.cycle_view(ship.external_view)
	last_view="";_refresh_hud();_record_event("camera_view",{"view":instruments.view_key(ship.external_view)})

func _toggle_pause()->void:
	if busy or not active:return
	instruments.paused=not instruments.paused;_release_inputs();_update_flight_controls();_refresh_hud()
	flight_time.interrupt("Пауза." if instruments.paused else "Обычное время.")
	_record_event("simulation_pause",{"paused":instruments.paused})
	_announce("Полёт приостановлен. Кнопка «Продолжить» возвращает управление." if instruments.paused else "Полёт продолжен.")

func _paused_command()->bool:
	if not surface.pending_source_contact().is_empty():
		_announce("Сначала завершите расчёт касания или загрузите последнее сохранение.")
		return true
	if not instruments.paused:return false
	_announce("Полёт приостановлен. Сначала нажмите «Продолжить».");return true

func _control_mode_available()->bool:
	return not busy and not instruments.paused and surface.pending_source_contact().is_empty() and ship.hull>0 and not ship.docked and not surface.landed and nav.remaining<=0 and world.transfer_remaining<=0

func _toggle_control_mode()->void:
	if not _control_mode_available() or _blocked():return
	_release_inputs();ship.autopilot=false
	if surface.active:surface.landing=false;surface.cancel_vertical()
	ship.assisted=not ship.assisted
	# Entering inertial flight releases axial thrust. Returning to assistance
	# adopts the current forward speed instead of an old slider command.
	ship.target_speed=clampf(ship.velocity.dot(ship.forward()),-100,ship.MAX_SPEED) if ship.assisted else 0.0
	_refresh_hud();_record_event("control_mode",{"assisted":ship.assisted})
	_announce("Стабилизация скорости включена." if ship.assisted else "Инерционный режим. Шкала скорости задаёт осевую тягу.")

func _show_status()->void:
	_open_menu("БОРТОВОЙ КОМПЬЮТЕР")
	_menu_text("%s · система %s"%[ship.profile().name,nav.current().name])
	var context:String=surface.site_name if surface.active and not surface.site_name.is_empty() else str(world.by_id[world.focus_id].name)
	_menu_text("Объект: %s\nКорпус: %.0f%%\nСкорость: %.1f м/с · задано %.1f м/с\nТопливо гиперпереходов: %d/%d\nГруз: %d/%d т\nСчёт: %d кр."%[context,ship.hull,ship.velocity.length(),ship.target_speed,nav.fuel,nav.fuel_capacity(),ship.total_cargo(),ship.cargo_capacity(),ship.credits])
	_menu_text("%s · %s"%[instruments.view_label(ship.external_view),"ПАУЗА" if instruments.paused else ("Стабилизация скорости" if ship.assisted else "Инерционный режим")])
	if nav.is_source_hyperdrive():
		var fuel_status:Dictionary=nav.fuel_state(ship)
		var manifest:Dictionary=nav.service_state(ship)
		_menu_text("Реактивный бак: %.1f%% · %.2f т\nВодород: %d т · военное топливо: %d т · отходы: %d т\n%s"%[float(fuel_status.get("jet_percent",0)),float(fuel_status.get("jet_tonnes",0)),int(manifest.get("hydrogen",0)),int(manifest.get("military",0)),int(manifest.get("radioactives",0)),str(fuel_status.get("heat_label",""))])
	_menu_action("Груз и оборудование",_show_equipment)
	_menu_action("Объекты и космопорты",_show_system)
	_menu_action("Сведения о системе",func():_show_information())
	_menu_action("Маршруты",_show_routes)
	if ship.docked:_menu_action("Службы космопорта",_show_services)

func _show_equipment()->void:
	_open_menu("ГРУЗ И ОБОРУДОВАНИЕ")
	if nav.is_source_hyperdrive():
		_embed_hyperdrive_services()
		_menu_action("Бортовой компьютер",_show_status);_fit_hyperdrive_menu();return
	if nav.is_native() and world.layout_mode==World.FULL_LAYOUT:
		_menu_action("Исходный гипердвигатель · перейти",_show_hyperdrive_migration)
	_menu_text("Грузовой отсек: %d/%d т · оборудование занимает %d т"%[ship.total_cargo(),ship.cargo_capacity(),ship.equipment_space()])
	for id in ship.goods:
		if int(ship.goods[id])>0:_menu_text("%s: %d т"%[str(ship.economy_catalog.good(str(id)).get("name_ru",id)),int(ship.goods[id])])
	if ship.story_cargo>0:_menu_text("Специальный груз: %d т"%ship.story_cargo)
	if not ship.mission_cargo.is_empty():
		for id in ship.mission_cargo:_menu_text("Груз задания %s: %d т"%[str(id),int(ship.mission_cargo[id])])
	if ship.equipment.is_empty():_menu_text("Дополнительное оборудование не установлено.")
	else:
		for id in ship.equipment:
			var item:Dictionary=ship.economy_catalog.item(str(id))
			_menu_text("%s · %d т"%[str(item.get("name_ru",id)),int(item.get("space",0))])
	if ship.docked:_menu_action("Службы космопорта",_show_services)
	_menu_action("Бортовой компьютер",_show_status)

func _show_menu()->void:
	_open_menu("КОМАНДИР")
	if not graphics_return.is_empty():
		_menu_text("Графический полёт: осмотрите корабль, станцию и астероиды. Основной полёт приостановлен; этот просмотр не заменяет его сохранение.")
		_menu_action("Продолжить графический полёт",_close_menu)
		_menu_action("Вернуться к основному полёту",_end_graphics_demo)
		_menu_action("Отчёт об ошибке / логи",_show_bug_report)
		_menu_action("Настройки телефона",func():menu.hide();settings_panel.configure(settings);settings_panel.show())
		return
	_menu_action("Продолжить полёт",_close_menu)
	if not surface.pending_source_contact().is_empty():_menu_action("Загрузить последнее сохранение",_reload_after_contact_error)
	_menu_action("Бортовой компьютер",_show_status)
	_menu_action("Груз и оборудование",_show_equipment)
	_menu_action("Графический полёт · осмотреть обновление",_begin_graphics_demo)
	_menu_action("Космопорты и объекты системы",_show_system)
	_menu_action("Маршруты между системами",_show_routes)
	if surface.active and surface.globe!=null:_menu_action("Автовылет на орбиту",_begin_departure_action)
	if ship.docked:_menu_action("Службы станции и корабли",_show_services)
	_menu_action("Настройки телефона",func():menu.hide();settings_panel.configure(settings);settings_panel.show())
	_menu_action("Сохранить сейчас",func():
		if _save_game():_announce("Полёт сохранён.");_close_menu()
	)
	_menu_action("Резервная копия",_show_backup)
	_menu_action("Отчёт об ошибке / логи",_show_bug_report)
	_menu_action("Управление и сведения о сборке",_show_help)
	_menu_action("Начать новый полёт…",_confirm_new_game)
func _begin_graphics_demo()->void:
	if not surface.pending_source_contact().is_empty():_paused_command();return
	if busy or not graphics_return.is_empty():return
	if saving_enabled and not _save_game():return
	_release_inputs()
	graphics_return={"ship":ship,"nav":nav,"world":world,"surface":surface,"saving_enabled":saving_enabled,"source_motion":source_motion,"source_motion_enabled":source_motion_enabled,"target_site_id":target_site_id,"target_reference":target_reference.duplicate(true),"paused":instruments.paused}
	saving_enabled=false;_new_models();ship.external_view=true;nav.elapsed_days=225.0;ship.target_speed=0;ship.attitude=Quaternion(Vector3.UP,-0.38)
	_close_menu();_apply_system();_refresh_hud();_announce("Осмотрите обновлённый корабль и станцию. Вернуться к основному полёту можно через меню.")
func _end_graphics_demo()->void:
	if busy or graphics_return.is_empty():return
	_release_inputs();ship=graphics_return.ship;nav=graphics_return.nav;world=graphics_return.world;surface=graphics_return.surface;saving_enabled=graphics_return.saving_enabled
	source_motion=graphics_return.source_motion;source_motion_enabled=bool(graphics_return.source_motion_enabled);target_site_id=str(graphics_return.target_site_id);target_reference=graphics_return.target_reference.duplicate(true)
	instruments.paused=bool(graphics_return.paused);flight_time.reset()
	graphics_return={};near.clear();_close_menu();_apply_system();_refresh_hud();_announce("Основной полёт продолжен.")
func _show_system()->void:
	if busy:return
	var view:=SystemMap.new()
	var state:={"star":nav.current(),"world":world.snapshot(),"elapsed_days":nav.elapsed_days,"system_name":nav.current().name}
	if not surface.active:
		var origin:Array=world.origin_au(nav.elapsed_days)
		state.ship_position_au=[float(origin[0])+ship.position.x/world.AU_METERS,float(origin[1])+ship.position.y/world.AU_METERS,float(origin[2])+ship.position.z/world.AU_METERS]
	if not view.configure(state):view.free();_announce("Не удалось подготовить карту системы.");return
	view.body_selected.connect(func(id:String):
		if active_map!=view:return
		if world.select(id):target_site_id="";target_reference.clear();_refresh_hud()
	)
	view.site_selected.connect(func(id:String):
		if active_map!=view:return
		if world.select_site(id):
			target_site_id=id;target_reference=view.model.ground_target_reference(id)
			_request_target_reference();_refresh_hud()
	)
	view.travel_requested.connect(func(body_id:String,site_id:String):
		if active_map!=view:return
		if site_id.is_empty():_choose_body(body_id)
		else:_choose_site(site_id)
		if is_instance_valid(active_map) and active_map==view:view.set_feedback(world.message if not instruments.paused else "Сначала продолжите полёт.")
	)
	view.close_requested.connect(func():
		if active_map==view:_close_map()
	)
	view.information_requested.connect(func(id:String):
		if active_map==view:_show_information(world.system_id,id)
	)
	_install_map(view,"system")
func _choose_body(id:String)->void:
	if _paused_command():return
	if busy:return
	if surface.active:_announce("Сначала вернитесь на орбиту.");return
	if world.transfer_remaining>0:
		if world.pending_id==id and world.pending_site_id.is_empty():world.cancel_transfer();_announce(world.message)
		else:_announce("Сначала отмените текущий автоперелёт кнопкой «Тормозить».")
		return
	world.select(id)
	if world.begin_transfer(ship,nav):_close_menu()
	_announce(world.message)
func _choose_site(id:String)->void:
	if _paused_command():return
	if busy:return
	if surface.active:_announce("Сначала вернитесь на орбиту.");return
	if world.transfer_remaining>0:
		if world.pending_site_id==id:world.cancel_transfer();_announce(world.message)
		else:_announce("Сначала отмените текущий автоперелёт кнопкой «Тормозить».")
		return
	if world.begin_site_transfer(id,ship,nav):_close_menu()
	_announce(world.message)
func _show_routes()->void:
	if busy:return
	var view:=GalacticMap.new()
	var reason:=""
	if instruments.paused:reason="Сначала продолжите полёт."
	elif ship.hull<=0:reason="Корабль потерян."
	elif ship.docked:reason="Сначала вылетите со станции."
	elif surface.active:reason="Сначала вернитесь на орбиту."
	elif ship.combat_active:reason="Сначала выйдите из боя."
	elif nav.remaining>0 or world.transfer_remaining>0:reason="Сначала завершите или отмените текущий переход."
	elif ship.velocity.length()>20:reason="Затормозите до 20 м/с."
	var map_state:={"native":nav.is_native(),"current_id":nav.current_id,"selected_id":nav.selected_id,"jump_range_ly":ship.jump_range(),"fuel":nav.fuel,"fuel_capacity":nav.fuel_capacity(),"jump_blocked_reason":reason}
	if nav.is_source_hyperdrive():
		map_state.source_hyperdrive_profile=nav.map_profile(ship);map_state.jump_range_ly=nav.source_range_ly(ship)
	if not view.configure_state(map_state):view.free();_announce("Не удалось подготовить карту галактики.");return
	view.system_selected.connect(func(id:int):
		if active_map==view:nav.select(id)
	)
	view.jump_requested.connect(func(id:int):
		if active_map!=view:return
		_start_jump(id)
		if is_instance_valid(active_map) and active_map==view:view.set_feedback(nav.message if not instruments.paused else "Сначала продолжите полёт.")
	)
	view.close_requested.connect(func():
		if active_map==view:_close_map()
	)
	view.information_requested.connect(func(id:int):
		if active_map==view:_show_information(id)
	)
	_install_map(view,"galaxy")

static func _information_source_counts(system:RefCounted)->Dictionary:
	var value:Variant=system.source_runtime_state.get("body_count_byte")
	return {"body_count_byte":int(value)} if value is int and value>=0 and value<=255 else {}

static func _prepare_information_context(star:Dictionary)->Dictionary:
	# Only this private World is constructed on the worker. The live navigation,
	# source motion, clock, target, spin and save models never enter this job.
	var context:={"system_id":int(star.id),"system_name":str(star.name),"known":int(star.get("source_parameters",{}).get("population_raw",0))!=0,"bodies":[],"settlements":[],"selected_body_id":"","source_counts":{}}
	if not context.known:return context
	var candidate:=World.new();candidate.configure(star,World.FULL_LAYOUT)
	if candidate.layout_mode!=World.FULL_LAYOUT:return {"error":"Не удалось прочитать исходные сведения о телах этой системы."}
	context.bodies=candidate.bodies.duplicate(true);context.settlements=candidate.settlements.duplicate(true)
	context.body_generation_variant=candidate.layout_mode
	context.source_counts=_information_source_counts(candidate)
	return context

func _show_information(system_id:int=-1,body_id:String="")->void:
	if busy or active_map_kind=="information":return
	_finish_information_preparation()
	var requested:int=nav.current_id if system_id<0 else system_id
	var star:Dictionary=nav.galaxy.get_system(requested)
	if star.is_empty():_announce("Сведения об этой системе недоступны.");return
	var view:=SystemInformation.new()
	view.configure_loading(requested,str(star.name))
	view.close_requested.connect(_close_information)
	_release_inputs();flight_time.interrupt("Открыты сведения.");information_parent=active_map;information_parent_kind=active_map_kind
	information_return_menu=menu.visible
	if is_instance_valid(information_parent):
		information_parent.set("input_allowed",false);information_parent.hide()
	menu.hide();settings_panel.hide();active_map=view;active_map_kind="information"
	ui.add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.move_to_front();_update_flight_controls()
	if requested==world.system_id:
		view.configure({"system_id":requested,"system_name":str(star.name),"known":int(star.get("source_parameters",{}).get("population_raw",0))!=0,"bodies":world.bodies.duplicate(true),"settlements":world.settlements.duplicate(true),"selected_body_id":body_id,"body_generation_variant":world.layout_mode,"source_counts":_information_source_counts(world)})
	else:
		information_job_view=view;information_worker=Thread.new()
		if information_worker.start(_prepare_information_context.bind(star.duplicate(true)))!=OK:
			information_worker=null;information_job_view=null;view.configure_error("Не удалось подготовить сведения о системе.")
	_record_event("information_open",{"system_id":requested,"body_id":body_id})

func _pump_information()->void:
	if information_worker==null or information_worker.is_alive():return
	var result:Variant=information_worker.wait_to_finish();information_worker=null
	var view:Control=information_job_view;information_job_view=null
	if not is_instance_valid(view) or active_map!=view or active_map_kind!="information":return
	if not result is Dictionary or result.has("error"):
		view.configure_error(str(result.get("error","Не удалось прочитать сведения.")) if result is Dictionary else "Не удалось прочитать сведения.")
	else:view.configure(result)

func _finish_information_preparation()->void:
	if information_worker!=null:
		if information_worker.is_started():information_worker.wait_to_finish()
		information_worker=null
	information_job_view=null

func _discard_information_parent()->void:
	if is_instance_valid(information_parent):
		information_parent.set("input_allowed",false)
		if information_parent.has_method("finish_preparation"):information_parent.finish_preparation()
		information_parent.queue_free()
	information_parent=null;information_parent_kind="";information_return_menu=false

func _close_information()->void:
	if active_map_kind!="information":return
	_finish_information_preparation()
	var closing:Control=active_map;active_map=null;active_map_kind=""
	if is_instance_valid(closing):closing.input_allowed=false;closing.release_pointers();closing.hide();closing.queue_free()
	if is_instance_valid(information_parent):
		active_map=information_parent;active_map_kind=information_parent_kind
		active_map.show();active_map.move_to_front()
	elif information_return_menu:menu.show()
	information_parent=null;information_parent_kind="";information_return_menu=false
	_release_inputs();_update_flight_controls()

func _install_map(view:Control,kind:String)->void:
	_close_map(false);_release_inputs();flight_time.interrupt("Открыта карта.")
	_clear_menu_rows()
	_save_game();menu.hide();settings_panel.hide();active_map=view;active_map_kind=kind
	ui.add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.move_to_front();_update_flight_controls()
	_record_event("map_open",{"kind":kind})

func _close_map(save_progress:=true)->void:
	if active_map_kind=="information":
		if save_progress:_close_information();return
		_finish_information_preparation();_discard_information_parent()
	if not is_instance_valid(active_map):active_map=null;active_map_kind="";return
	var closing:=active_map;active_map=null;active_map_kind=""
	closing.set("input_allowed",false)
	if closing.has_method("release_pointers"):closing.release_pointers()
	closing.hide()
	if closing.has_method("finish_preparation"):closing.finish_preparation()
	closing.queue_free();_release_inputs()
	if save_progress:_save_game()
	_update_flight_controls()
func _start_jump(id:int)->void:
	if _paused_command():return
	if busy:return
	if world.transfer_remaining>0:_announce("Сначала отмените автоперелёт.");return
	if nav.remaining>0:
		if nav.pending_id==id:nav.cancel_jump();_announce(nav.message)
		else:_announce("Сначала отмените текущий гиперпереход кнопкой «Тормозить».")
		return
	nav.select(id)
	if nav.begin_jump(ship):_close_menu()
	_announce(nav.message)
func _show_services(save_progress:bool=true)->void:
	menu_feedback.text=""
	_open_menu("СЛУЖБЫ СТАНЦИИ",save_progress)
	if nav.is_source_hyperdrive():_embed_hyperdrive_services();_fit_hyperdrive_menu();return
	dock_services_view=DockServicesView.new()
	dock_services_view.configure_state(_dock_services_state())
	dock_services_view.command.connect(_service_command)
	menu_rows.add_child(dock_services_view)

func _embed_hyperdrive_services()->void:
	hyperdrive_services_view=HyperdriveServices.new()
	hyperdrive_services_view.configure_state(nav.service_state(ship))
	hyperdrive_services_view.command.connect(_hyperdrive_service_command)
	hyperdrive_services_view.runtime_command.connect(_fuel_runtime_command)
	menu_rows.add_child(hyperdrive_services_view)

func _fuel_runtime_command(action:String,enabled:bool)->void:
	if not surface.pending_source_contact().is_empty():_paused_command();return
	if busy or not active or not menu.visible or not is_instance_valid(hyperdrive_services_view):return
	_release_inputs()
	var accepted:=false
	if action=="manual_jet_refuel":accepted=nav.manual_jet_refuel(ship)
	elif action=="set_refueller_enabled":accepted=nav.set_refueller_enabled(enabled,ship)
	else:return
	var feedback:=str(nav.message)
	if accepted:
		if not _apply_source_fuel_state():feedback+=" Не удалось согласовать тягу."
		elif not _save_game() and saving_enabled:feedback+=" "+str(saves.last_error)
	_record_event("fuel_command",{"action":action,"enabled":enabled,"accepted":accepted})
	if is_instance_valid(hyperdrive_services_view):hyperdrive_services_view.configure_state(nav.service_state(ship))
	menu_feedback.text=feedback;_announce(feedback);_refresh_hud()

func _fit_hyperdrive_menu()->void:
	# Existing menus retain their historical widths. This embedded workshop
	# uses the actual available phone width, including narrow logical windows.
	menu_title.clip_text=true
	for row:Node in menu_rows.get_children():
		if row is Control:row.custom_minimum_size.x=minf(row.custom_minimum_size.x,300.0)
	var header:Node=menu_title.get_parent()
	for child:Node in header.get_children():
		if child is Button:child.custom_minimum_size.x=112

func _hyperdrive_service_command(action:String,id:String,quantity:int)->void:
	if not surface.pending_source_contact().is_empty():_paused_command();return
	if busy:return
	_release_inputs()
	var accepted:bool=nav.service(action,id,quantity,ship)
	var result:={"ok":accepted,"message":nav.message}
	_record_event("hyperdrive_service",{"action":action,"id":id,"quantity":quantity,"accepted":result.get("ok",false)})
	var feedback:=str(result.get("message","Операция недоступна."))
	if result.get("ok",false) and saving_enabled and not _save_game():feedback+=" Изменения пока не удалось сохранить."
	if is_instance_valid(hyperdrive_services_view):hyperdrive_services_view.configure_state(nav.service_state(ship))
	_refresh_hud();_announce(feedback)

func _hyperdrive_backup_folder()->String:return saves.directory.path_join("hyperdrive-backups")

func _backup_before_source_hyperdrive()->String:
	var payload:=_payload()
	if payload.is_empty() or _decode_state(payload).is_empty():return ""
	var code:String=saves.encode(payload,saves.sequence)
	if saves.decode(code).is_empty():return ""
	var folder:=_hyperdrive_backup_folder()
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:return ""
	var name:="before-source-%s-%012d.txt"%[Time.get_datetime_string_from_system().replace(":","-"),Time.get_ticks_msec()]
	var path:=folder.path_join(name);var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return ""
	file.store_string(code);file.flush();file.close()
	return path if FileAccess.get_file_as_string(path)==code else ""

func _latest_hyperdrive_backup()->String:
	var directory:=DirAccess.open(_hyperdrive_backup_folder())
	if directory==null:return ""
	var files:Array[String]=[]
	for name:String in directory.get_files():
		if name.begins_with("before-source-") and name.ends_with(".txt"):files.append(name)
	files.sort()
	return _hyperdrive_backup_folder().path_join(files[-1]) if not files.is_empty() else ""

func _show_previous_hyperdrive_backup()->void:
	var path:=_latest_hyperdrive_backup()
	if path.is_empty():_announce("Резервная копия до перехода не найдена.");return
	_show_backup();backup_edit.text=FileAccess.get_file_as_string(path);menu_title.text="СОХРАНЕНИЕ ДО ПЕРЕХОДА"

func _apply_hyperdrive_migration()->void:
	var quote:Dictionary=nav.migration_quote(ship)
	if not quote.get("ok",false):_announce(str(quote.get("message","Переход недоступен.")));return
	var backup:=_backup_before_source_hyperdrive()
	if backup.is_empty():_announce("Не удалось сохранить прежний полёт. Переход отменён.");return
	var result:Dictionary=nav.migrate_source(ship)
	if result.get("ok",false):
		if saving_enabled and not _save_game():result.message=str(result.get("message",""))+" Изменения пока не удалось сохранить."
		_show_equipment()
	_record_event("hyperdrive_migration",{"accepted":result.get("ok",false),"backup_created":true})
	_announce(str(result.get("message","Переход недоступен.")))

func _show_hyperdrive_migration()->void:
	_open_menu("ИСХОДНЫЙ ГИПЕРДВИГАТЕЛЬ")
	var quote:Dictionary=nav.migration_quote(ship)
	_menu_text("Прежний полёт сохранит систему, время, корабль и груз. Двигатель получит исходную базовую комплектацию; каждая прежняя единица топлива станет тонной водорода. Дальность и сроки переходов будут рассчитываться по правилам оригинала.")
	_menu_text(str(quote.get("message","")))
	_menu_action("Сохранить код резервной копии",_show_backup)
	if quote.get("ok",false):_menu_action("Применить исходный гипердвигатель",_apply_hyperdrive_migration)
	_fit_hyperdrive_menu()
func _service_command(action:String,id:String="")->void:
	if busy:return
	if nav.is_source_hyperdrive():
		if action=="refuel":
			var state:Dictionary=nav.service_state(ship)
			for row:Dictionary in state.get("fuels",[]):
				if str(row.id)==str(state.get("fuel_kind","")):
					_hyperdrive_service_command("refuel",str(row.id),int(row.get("fill_quantity",0)));return
			_announce("Заправка недоступна.")
		else:_announce("Обслуживание доступно на экране гипердвигателя.")
		return
	if surface.active or not _station_here() or not ship.docked:
		_announce("Для обслуживания сначала выполните стыковку с доступной станцией.")
		return
	_release_inputs()
	var result:Dictionary=DockServices.execute(ship,nav,action,id)
	var feedback:String=str(result.message)
	if result.ok:
		if result.get("ship_changed",false):_apply_system()
		if saving_enabled and not _save_game():feedback+=" Текущие изменения пока не удалось сохранить."
	_record_event("dock_service",{"action":action,"id":id,"accepted":result.ok,"status":result.status})
	if is_instance_valid(dock_services_view):dock_services_view.configure_state(_dock_services_state())
	_refresh_hud();_announce(feedback)
func _dock_services_state()->Dictionary:
	var state:Dictionary=DockServices.service_state(ship,nav)
	if state.get("source_refuel_only",false):state["source_port_name"]=str(world.current_site().get("name","Космопорт"))
	return state
func _show_help()->void:
	_open_menu("УПРАВЛЕНИЕ И СБОРКА")
	_menu_text("Левый стик меняет направление носа. Правая шкала задаёт скорость. «Тормозить» отменяет автоматический полёт и плавно останавливает корабль. «Авто» ведёт к станции или площадке; после посадки команда «На орбиту» выполняет автоматический вылет. «Взлететь» оставляет управление вам после короткого подъёма. Кнопки подъёма и снижения помогают лететь над землёй. В доке кнопка «Службы» открывает обслуживание.")
	_menu_text("Клавиатура: стрелки — поворот, W/S — скорость, Q/E — крен, R/F — подъём, пробел — тормоз, A — авто, L — поверхность/орбита, D — стыковка/взлёт, V — передняя/задняя/внешняя камера, C — стабилизация/инерция, P — пауза/продолжение, Esc — меню.")
	_menu_text("Сборка %s. Через меню можно сохранить ZIP с отчётом об ошибке и журналами. Новый полёт использует исходные сектора, системы, рельеф, орбиты и модели космопортов; прежние сохранения сохраняют свою версию мира. Управление адаптировано для телефона, тяга «Кобры» ограничена проверенным исходным значением. Полный каталог кораблей, оборудование, экономика, кампания и ИИ ещё в разработке. Проверка на настоящем телефоне выполняется отдельно."%BuildInfo.VERSION)

func _show_bug_report()->void:
	if busy:return
	settings_panel.hide();_open_menu("ОТЧЁТ ОБ ОШИБКЕ",false)
	_menu_text("Опишите проблему и действия перед ней. ZIP содержит версию, параметры устройства, настройки, последние события и ошибки игры. Сохраните архив в «Загрузки» и прикрепите его к сообщению в ChatGPT.")
	report_description=TextEdit.new();report_description.custom_minimum_size=Vector2(900,180);report_description.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	report_description.placeholder_text="Что произошло? Как повторить ошибку?";report_description.text=report_draft;report_description.add_theme_font_size_override("font_size",21)
	report_description.text_changed.connect(func():report_draft=report_description.text.left(8000));menu_rows.add_child(report_description)
	var include:=CheckBox.new();include.text="Добавить сохранение текущего полёта для воспроизведения";include.button_pressed=report_include_save;include.custom_minimum_size=Vector2(900,60)
	include.toggled.connect(func(value:bool):report_include_save=value);menu_rows.add_child(include)
	_menu_action("Собрать ZIP и сохранить…",func():_create_bug_report(true))
	report_retry=_button("Повторно сохранить последний ZIP",_export_bug_report,900);report_retry.disabled=not current_report.get("ok",false);menu_rows.add_child(report_retry)
	report_feedback=_label("",20);report_feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;report_feedback.custom_minimum_size.x=900;menu_rows.add_child(report_feedback)
	if current_report.get("ok",false):report_feedback.text="Последний архив: %s"%current_report.filename
func _report_status(text:String)->void:
	if is_instance_valid(report_feedback) and not report_feedback.is_queued_for_deletion():report_feedback.text=text
	_announce(text)
func _create_bug_report(export_after:bool=true)->void:
	if busy or report_export.is_busy():return
	var description:=report_draft.left(8000)
	var snapshot:Dictionary=_payload().duplicate(true) if report_include_save else {}
	var context:=_diagnostic_context()
	busy=true;_release_inputs();_report_status("Собираю ZIP-отчёт…")
	await get_tree().process_frame
	var result:Dictionary=diagnostics.build_report(description,context,report_include_save,snapshot)
	busy=false
	if not result.get("ok",false):_report_status(str(result.get("error","Не удалось создать ZIP-отчёт.")));return
	current_report=result
	if is_instance_valid(report_retry) and not report_retry.is_queued_for_deletion():report_retry.disabled=false
	_report_status("Архив готов: %s · %.0f КБ"%[result.filename,maxf(1.0,float(result.get("report_bytes",0))/1024.0)])
	if export_after:_export_bug_report()
func _export_bug_report()->void:
	if busy or report_export.is_busy():return
	if not current_report.get("ok",false):_report_status("Сначала создайте ZIP-отчёт.");return
	_report_status("Выберите место для ZIP-отчёта. Удобно сохранить его в «Загрузки».")
	var result:Dictionary=report_export.export_report(str(current_report.get("absolute_path",current_report.path)),str(current_report.filename))
	if not result.get("ok",false):_report_status(str(result.get("message",result.get("error","Не удалось открыть сохранение ZIP."))))
func _report_export_completed(result:Dictionary)->void:
	_record_event("report_export",{"ok":result.get("ok",false),"cancelled":result.get("cancelled",false),"verified":result.get("verified",false)})
	_report_status(str(result.get("message","Сохранение отчёта завершено.")))
func _confirm_new_game()->void:
	_open_menu("НОВЫЙ ПОЛЁТ")
	_menu_text("Текущий прогресс будет заменён новым полётом. При необходимости сначала сделайте резервную копию.")
	_menu_action("Сохранить код резервной копии",_show_backup)
	_menu_action("Начать новый полёт",func():
		_new_models(World.FULL_LAYOUT)
		if not _enable_source_hyperdrive():return
		saving_enabled=true;_close_menu();_apply_system();_save_game();_announce("Начат новый полёт.")
	)

func _payload()->Dictionary:
	_validate_navigation_target()
	if surface!=null and not surface.pending_source_contact().is_empty():return {}
	if nav.is_source_hyperdrive() and not nav.sync_source_ship(ship):return {}
	if not _apply_source_fuel_state():return {}
	var result:={"schema":"starfrontier-rebuild-game-v1","flight":ship.snapshot(),"navigation":nav.snapshot(),"planetary":world.snapshot(),"surface":surface.snapshot()}
	if _gear_enabled():
		if landing_gear==null or not landing_gear.state().get("initialized",false):return {}
		result.gear_session=landing_gear.snapshot()
	if not target_site_id.is_empty():result.target_session={"version":1,"system_id":nav.current_id,"body_id":world.selected_id,"site_id":target_site_id}
	if source_motion_enabled:
		if source_motion.is_active() and not source_motion.synchronized(world,ship,nav.elapsed_days):source_motion.reset()
		var snapshot:Dictionary=source_motion.snapshot() if MotionBridge.eligible(world,ship,surface.active) else {}
		result.motion_session={"version":1,"profile":MotionBridge.CONTRACT,"enabled":true,"state":snapshot}
	return result
func _decode_state(data:Dictionary)->Dictionary:
	if data.get("schema")!="starfrontier-rebuild-game-v1":return {}
	for key in ["flight","navigation","planetary","surface"]:
		if not data.get(key) is Dictionary:return {}
	var candidate_nav:=NavigationData.new()
	if not candidate_nav.restore(data.navigation):return {}
	var candidate_world:=World.new();candidate_world.configure(candidate_nav.current())
	if not candidate_world.restore(data.planetary):return {}
	var restored:=StationSession.restore_flight(candidate_world,candidate_nav,data.flight)
	if restored.is_empty():return {}
	var candidate_ship:RefCounted=restored.ship
	if not candidate_nav.validate_source_ship(candidate_ship):return {}
	if not candidate_nav.bind_thermal_ship(candidate_ship):return {}
	candidate_nav.apply_fuel_availability(candidate_ship)
	var candidate_surface:=Surface.new()
	candidate_surface.set_source_time(candidate_nav.elapsed_days)
	if not candidate_surface.restore(data.surface,candidate_ship,candidate_world):return {}
	if candidate_surface.active and (candidate_ship.docked or candidate_nav.remaining>0 or candidate_world.transfer_remaining>0):return {}
	var candidate_gear:=LandingGearSession.new()
	if data.has("gear_session"):
		if candidate_world.layout_mode!=World.FULL_LAYOUT or not data.gear_session is Dictionary or not candidate_gear.restore(data.gear_session):return {}
	else:
		if not candidate_gear.configure(candidate_surface.landed or candidate_ship.docked):return {}
	var restored_gear:Dictionary=candidate_gear.state()
	if candidate_surface.landed and (not restored_gear.get("deployed",false) or not restored_gear.get("requested_down",false)):return {}
	candidate_surface.set_landing_gear_state(candidate_world.layout_mode==World.FULL_LAYOUT,bool(restored_gear.get("deployed",true)) and bool(restored_gear.get("requested_down",true)),str(restored_gear.get("status_text","")))
	candidate_surface.set_source_contact_enabled(candidate_world.layout_mode==World.FULL_LAYOUT and candidate_nav.is_source_hyperdrive())
	if candidate_nav.remaining>0 and candidate_world.transfer_remaining>0:return {}
	if candidate_ship.docked:
		if candidate_nav.remaining>0 or candidate_world.transfer_remaining>0:return {}
		if not candidate_world.is_orbital_site() and not (candidate_world.site_id.is_empty() and candidate_world.focus_id==candidate_world.default_id and candidate_nav.has_station()):return {}
		if candidate_ship.has_source_station():
			if not candidate_ship.source_dock_pose_valid(candidate_ship.position,candidate_ship.velocity,candidate_ship.attitude,candidate_ship.ship_id):return {}
		elif candidate_ship.position.distance_to(candidate_ship.STATION)>candidate_ship.DOCK_RADIUS+0.01 or candidate_ship.velocity.length()>0.001 or absf(candidate_ship.target_speed)>0.001:return {}
	var candidate_target:=""
	if data.has("target_session"):
		var target:Variant=data.target_session
		if not target is Dictionary or target.size()!=4 or not NavigationData._number(target.get("version"),1,1,true) or not NavigationData._number(target.get("system_id"),0,4294967295.0,true) or target.get("system_id")!=candidate_nav.current_id or not target.get("body_id") is String or target.body_id!=candidate_world.selected_id or not target.get("site_id") is String:return {}
		var selected_site:Dictionary=candidate_world.get_site(str(target.site_id))
		if selected_site.is_empty() or str(selected_site.parent)!=candidate_world.selected_id:return {}
		candidate_target=str(target.site_id)
	var candidate_motion:=MotionBridge.new();var candidate_motion_enabled:=false
	if data.has("motion_session"):
		var motion:Variant=data.motion_session
		if not motion is Dictionary or motion.size()!=4 or not NavigationData._number(motion.get("version"),1,1,true) or motion.get("profile")!=MotionBridge.CONTRACT or not motion.get("enabled") is bool or not motion.get("state") is Dictionary:return {}
		candidate_motion_enabled=motion.enabled
		if candidate_motion_enabled:
			if candidate_world.layout_mode!=World.FULL_LAYOUT:return {}
			if not motion.state.is_empty() and (candidate_surface.active or not candidate_motion.restore(motion.state,candidate_world,candidate_ship,candidate_nav.elapsed_days)):return {}
			# Ordinary JSON rounds decimal days. The validated opt-in session
			# carries their exact IEEE64 bits alongside the fractional ticks.
			if candidate_motion.is_active():candidate_nav.elapsed_days=candidate_motion.elapsed_days()
		elif not motion.state.is_empty():return {}
	return {"ship":candidate_ship,"nav":candidate_nav,"world":candidate_world,"surface":candidate_surface,"target_site_id":candidate_target,"source_motion_enabled":candidate_motion_enabled,"source_motion":candidate_motion,"landing_gear":candidate_gear}
func _commit_state(data:Dictionary)->void:
	_close_map(false)
	ship=data.ship;nav=data.nav;world=data.world;surface=data.surface;near.clear();instruments.reset();flight_time.reset();last_view=""
	source_contact_last.clear();source_contact_error="";_source_contact_interval.clear()
	landing_gear=data.get("landing_gear")
	if landing_gear==null:landing_gear=LandingGearSession.new();landing_gear.configure(surface.landed or ship.docked)
	target_site_id=str(data.get("target_site_id",""));target_reference.clear()
	source_motion_enabled=bool(data.get("source_motion_enabled",false));source_motion=data.get("source_motion",MotionBridge.new());last_motion_result.clear()
	_apply_source_fuel_state()
	_apply_landing_gear_state()
func _save_game()->bool:
	if not saving_enabled or busy:return false
	if not surface.pending_source_contact().is_empty():return false
	if _gear_enabled() and (landing_gear==null or not landing_gear.state().get("initialized",false)):return false
	if nav.is_source_hyperdrive() and not nav.sync_source_ship(ship):return false
	if not _apply_source_fuel_state():return false
	var ok:=saves.write(_payload())
	_record_event("save_result",{"ok":ok,"generation":saves.sequence})
	if not ok:_announce(saves.last_error)
	return ok
func _load_game()->bool:
	var loaded:Dictionary=saves.load_valid(_decode_state)
	if not loaded.is_empty():_commit_state(loaded);return true
	if FileAccess.file_exists(saves.directory+"/slot0.json") or FileAccess.file_exists(saves.directory+"/slot1.json"):
		saving_enabled=false;_announce("Сохранение не прочитано. Копии оставлены; новый полёт можно начать через меню.")
	return false
func _reload_after_contact_error()->void:
	if surface.pending_source_contact().is_empty() or busy:return
	if not _load_game():_announce("Исправное сохранение не найдено. Можно восстановить прежний код резервной копии.");return
	saving_enabled=true;_close_menu();_apply_system();_announce("Загружено последнее исправное сохранение.")
func _show_backup()->void:
	if not graphics_return.is_empty():_announce("Для резервной копии вернитесь к основному полёту через меню.");return
	settings_panel.hide();_open_menu("РЕЗЕРВНАЯ КОПИЯ")
	_menu_text("Скопируйте код и сохраните его вне приложения. Для восстановления вставьте код сюда. Формат относится к этой восстановительной сборке.")
	var backup_payload:=_payload()
	if backup_payload.is_empty():_menu_text("Расчёт касания не завершён: новый код не создан. Здесь можно вставить прежний исправный код для восстановления.")
	backup_edit=TextEdit.new();backup_edit.custom_minimum_size=Vector2(900,230);backup_edit.add_theme_font_size_override("font_size",settings.reading_size);backup_edit.text="" if backup_payload.is_empty() else saves.encode(backup_payload,0);menu_rows.add_child(backup_edit)
	_menu_action("Копировать код",func():
		if backup_edit.text.is_empty():_announce("Новый код пока недоступен.");return
		DisplayServer.clipboard_set(backup_edit.text);_announce("Код резервной копии скопирован."))
	_menu_action("Вставить из буфера",func():backup_edit.text=DisplayServer.clipboard_get())
	_menu_action("Восстановить из кода",_import_backup)
	if not _latest_hyperdrive_backup().is_empty():_menu_action("Сохранение до перехода на исходный двигатель",_show_previous_hyperdrive_backup)
func _import_backup()->void:
	if busy:return
	if not graphics_return.is_empty():_announce("Сначала вернитесь к основному полёту через меню.");return
	var entry:Dictionary=saves.decode(backup_edit.text)
	var loaded:Dictionary={} if entry.is_empty() else _decode_state(entry.payload)
	if loaded.is_empty():_announce("Код повреждён или несовместим. Текущий полёт не изменён.");return
	_commit_state(loaded);saving_enabled=true;_close_menu();_apply_system();_save_game();_announce("Резервная копия восстановлена.")
func _apply_settings()->void:
	Engine.max_fps=settings.fps;get_viewport().msaa_3d=settings.msaa();ground_view.set_quality(settings.quality);celestial.set_quality(settings.quality);stick.deadzone=settings.deadzone;presentation_key=""
	player.set_quality(settings.quality);station.configure(settings.quality);city_view.set_quality(settings.quality)
	if not graphics_return.is_empty():space_environment.configure(ship.STATION,settings.quality)
func _settings_changed()->void:_apply_settings();settings.save_file();_record_event("settings_changed",settings.snapshot())
func _close_settings()->void:settings_panel.hide();_release_inputs();_save_game()

func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_ESCAPE:
		if settings_panel.visible:_close_settings()
		elif is_instance_valid(active_map):_close_map()
		elif menu.visible:_close_menu()
		else:_show_menu()
		return
	if _blocked():return
	match event.physical_keycode:
		KEY_SPACE:_brake()
		KEY_A:_toggle_auto()
		KEY_D:_dock_action()
		KEY_L:_surface_action()
		KEY_V:_cycle_view()
		KEY_P:_toggle_pause()
		KEY_C:_toggle_control_mode()
		KEY_M:_show_system()
func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		if diagnostics!=null and not automated:diagnostics.lifecycle("paused" if what==NOTIFICATION_APPLICATION_PAUSED else "focus_out")
		active=false;_release_inputs()
		flight_time.interrupt("Приложение неактивно.")
		if ui!=null:_update_flight_controls()
		if ship!=null and (report_export==null or not report_export.is_busy()):_save_game()
	elif what==NOTIFICATION_APPLICATION_RESUMED or what==NOTIFICATION_APPLICATION_FOCUS_IN:
		active=true
		if ui!=null:_update_flight_controls()
		if diagnostics!=null and not automated:diagnostics.lifecycle("resumed" if what==NOTIFICATION_APPLICATION_RESUMED else "focus_in")
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if menu!=null:
			if settings_panel.visible:_close_settings()
			elif is_instance_valid(active_map):_close_map()
			elif menu.visible:_close_menu()
			else:_show_menu()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game();get_tree().quit()
func _exit_tree()->void:
	if diagnostics!=null:diagnostics.shutdown(true)
	_finish_information_preparation()
	if is_instance_valid(information_parent) and information_parent.has_method("finish_preparation"):information_parent.finish_preparation()
	if target_worker!=null and target_worker.is_started():target_worker.wait_to_finish()
	if is_instance_valid(active_map) and active_map.has_method("finish_preparation"):active_map.finish_preparation()
	if worker!=null and worker.is_started():worker.wait_to_finish()
	if hatch_worker!=null and hatch_worker.is_started():hatch_worker.wait_to_finish()
	near.finish_preparation()
	if ground_view!=null:ground_view.finish_source_preparation()

func _run_smoke()->void:
	await get_tree().process_frame
	if world.system_id!=44341016 or not world.by_id.has("earth"):push_error("REBUILD SMOKE FAILED: source Sol/Earth");get_tree().quit(1);return
	_toggle_auto()
	for step in range(4000):
		_tick(0.05,Vector2.ZERO,0)
		if ship.docked:break
	if not ship.docked or ship.hull!=100:push_error("REBUILD SMOKE FAILED: actual training auto dock");get_tree().quit(1);return
	if not ship.deliver():push_error("REBUILD SMOKE FAILED: training delivery");get_tree().quit(1);return
	ship.launch();ship.position=Vector3.ZERO;ship.velocity=Vector3.ZERO
	world.focus_id="earth";world.selected_id="earth";world.site_id="site10";_apply_system()
	await _enter_surface()
	if not surface.active or surface.city_data.is_empty():push_error("REBUILD SMOKE FAILED: original city entry");get_tree().quit(1);return
	_toggle_auto()
	for step in range(24000):
		surface.step(0.05,ship,Vector2.ZERO,0)
		if surface.landed:break
	if not surface.landed or ship.hull!=100:push_error("REBUILD SMOKE FAILED: original city landing");get_tree().quit(1);return
	var stored:=SaveStore.new();stored.directory="user://smoke-%d"%OS.get_process_id()
	if not stored.write(_payload()):push_error("REBUILD SMOKE FAILED: save write");get_tree().quit(1);return
	var decoded:Dictionary=stored.load_valid(_decode_state)
	if decoded.is_empty():push_error("REBUILD SMOKE FAILED: save decode");get_tree().quit(1);return
	_commit_state(decoded);_apply_system()
	if not surface.landed or ship.credits!=1800 or int(surface.city_data.profile.model_index)!=84:push_error("REBUILD SMOKE FAILED: progress and native city reload");get_tree().quit(1);return
	if city_view.current_visual()==null:push_error("REBUILD SMOKE FAILED: city mesh integration");get_tree().quit(1);return
	print("REBUILD APP SMOKE PASS: native source Sol/Earth, training auto dock/delivery, original New Moscow84 entry/landing, atomic disk save/reload, persistent original city view")
	await get_tree().process_frame
	get_tree().quit()
