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
const Lever=preload("res://scripts/speed_lever.gd")
const ActionButton=preload("res://scripts/touch_action_button.gd")
const FlightConsole=preload("res://scripts/flight_console.gd")
const ShipView=preload("res://scripts/ship_visual.gd")
const StationView=preload("res://scripts/station_visual.gd")
const SpaceEnvironment=preload("res://scripts/space_environment.gd")
const FlightTheme=preload("res://scripts/flight_theme.gd")
const FlightReticle=preload("res://scripts/flight_reticle.gd")
const BuildInfo=preload("res://scripts/build_info.gd")
const SourceClock=preload("res://scripts/source_clock.gd")
const Diagnostics=preload("res://scripts/game_diagnostics.gd")
const ReportExport=preload("res://scripts/report_export.gd")
const DockServices=preload("res://scripts/training_dock_services.gd")
const DockServicesView=preload("res://scripts/dock_services_view.gd")
var ship:RefCounted
var nav:RefCounted
var world:RefCounted
var surface:RefCounted
var near:=Near.new()
var settings:=Settings.new()
var saves:=SaveStore.new()
var presentation:=Presentation.new()
var camera:Camera3D
var environment:WorldEnvironment
var sunlight:DirectionalLight3D
var planet_fill:DirectionalLight3D
var celestial:Node3D
var ground_view:Node3D
var city_view:Node3D
var station:Node3D
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
var dock_services_view:Control
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
	settings.load_file();_new_models();_build_world();_build_ui();_apply_settings()
	if not automated:_load_game()
	_apply_system();_refresh_hud()
	if notice_timer<=0:_announce("Стик — поворот. Справа — скорость. «Авто» помогает подойти к станции.")
	get_viewport().size_changed.connect(_safe_area)
	_safe_area()
	if "--rebuild-smoke" in OS.get_cmdline_user_args():call_deferred("_run_smoke")

func _new_models()->void:
	ship=Flight.new();nav=NavigationData.new();world=World.new();world.configure(nav.current(),World.PORT_LAYOUT);surface=Surface.new();near.clear()

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
	flight_reticle=FlightReticle.new();_anchored(flight_reticle,Control.PRESET_FULL_RECT,Vector4.ZERO);flight_widgets.append(flight_reticle)
	hud=_label("",20);_anchored(hud,Control.PRESET_TOP_WIDE,Vector4(18,8,-260,38));hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;flight_widgets.append(hud)
	var console_height:float=FlightConsole.HEIGHT
	stick=Stick.new();_anchored(stick,Control.PRESET_BOTTOM_LEFT,Vector4(20,-250-console_height,250,-20-console_height));flight_widgets.append(stick)
	lever=Lever.new();_anchored(lever,Control.PRESET_BOTTOM_RIGHT,Vector4(-115,-315-console_height,-25,-20-console_height));lever.target_changed.connect(_set_speed);flight_widgets.append(lever)
	var caption:=_label("СКОРОСТЬ",16);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(caption,Control.PRESET_BOTTOM_RIGHT,Vector4(-125,-350-console_height,-15,-318-console_height));flight_widgets.append(caption)
	var lift1:=Hold.new();lift1.text="ПОДЪЁМ";_anchored(lift1,Control.PRESET_BOTTOM_RIGHT,Vector4(-275,-230-console_height,-135,-145-console_height));lift1.state_changed.connect(func(value:bool):lift_up=value);holds.append(lift1);flight_widgets.append(lift1)
	var lift2:=Hold.new();lift2.text="СНИЖЕНИЕ";_anchored(lift2,Control.PRESET_BOTTOM_RIGHT,Vector4(-275,-125-console_height,-135,-40-console_height));lift2.state_changed.connect(func(value:bool):lift_down=value);holds.append(lift2);flight_widgets.append(lift2)
	flight_console=FlightConsole.new();_anchored(flight_console,Control.PRESET_BOTTOM_WIDE,Vector4(0,-console_height,0,0));flight_widgets.append(flight_console)
	flight_console.system_requested.connect(_show_system);flight_console.routes_requested.connect(_show_routes);flight_console.menu_requested.connect(_show_menu)
	flight_console.view_requested.connect(func():ship.external_view=not ship.external_view)
	flight_console.auto_requested.connect(_toggle_auto);flight_console.brake_requested.connect(_brake);flight_console.dock_requested.connect(_dock_action)
	auto_button=flight_console.buttons.auto;dock_button=flight_console.buttons.dock
	surface_button=_button("К поверхности",_surface_action,215);_anchored(surface_button,Control.PRESET_TOP_RIGHT,Vector4(-240,110,-25,190));flight_widgets.append(surface_button)
	var cross:=_label("·",27);cross.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(cross,Control.PRESET_CENTER,Vector4(-15,-20,15,20));cross.mouse_filter=Control.MOUSE_FILTER_IGNORE;flight_widgets.append(cross)
	target_label=_label("",18);target_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(target_label,Control.PRESET_CENTER_TOP,Vector4(-330,40,330,94));target_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	flight_widgets.append(target_label)
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

func _release_inputs()->void:
	if stick:stick.release_pointer()
	if lever:lever.release_pointer()
	for hold in holds:hold.release_pointer()
	for button in action_buttons:
		if is_instance_valid(button):button.release_pointer()
	if flight_console!=null:flight_console.release_pointers()
	if is_instance_valid(dock_services_view):dock_services_view.release_pointers()
	lift_up=false;lift_down=false;roll_left=false;roll_right=false
func _blocked()->bool:return busy or not active or menu.visible or settings_panel.visible
func _physics_process(dt:float)->void:
	if automated or _blocked():return
	var steering:Vector2=stick.value
	steering.x+=float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT))
	steering.y+=float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP))
	var roll:=float(roll_right)-float(roll_left)+float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))
	var lift:=float(lift_up)-float(lift_down)+float(Input.is_physical_key_pressed(KEY_R))-float(Input.is_physical_key_pressed(KEY_F))
	if Input.is_physical_key_pressed(KEY_W):_set_speed(ship.target_speed+150*dt)
	if Input.is_physical_key_pressed(KEY_S):_set_speed(ship.target_speed-150*dt)
	_tick(minf(dt,0.1),settings.steer(steering.limit_length()),roll,lift)

func _tick(dt:float,steering:Vector2,roll:float,lift:=0.0)->void:
	if ship.hull<=0:return
	if steering.length()>0.04 or absf(roll)>0.05 or absf(lift)>0.1:
		ship.autopilot=false
		if surface.active:surface.landing=false
	if nav.remaining>0:
		if nav.step(dt,ship):
			world.configure(nav.current(),world.preferred_layout());surface=Surface.new();near.clear();_apply_system();_announce(nav.message);_save_game()
	elif world.transfer_remaining>0:
		if world.step_transfer(dt,ship,nav):
			# An explicit transfer starts a new local flight. A geographic link
			# from the previous departure belongs to its previous origin/focus.
			surface=Surface.new();near.clear()
			_apply_system();_announce(world.message)
			if not world.current_site().is_empty() and int(world.current_site().type_code)==35:_enter_surface()
			else:_save_game()
	else:
		nav.elapsed_days+=dt/86400.0
		if surface.active:
			var frame:int=surface.frame_index;var was_landed:bool=surface.landed
			surface.step(dt,ship,steering,roll,lift)
			if frame!=surface.frame_index:
				camera.position=surface.rebase_to+surface.frame_rotation*(camera.position-surface.rebase_from)
				camera.quaternion=(surface.frame_rotation*camera.quaternion).normalized()
			if surface.ready_for_orbit:_finish_ascent()
			if surface.landed and not was_landed:_save_game()
			if not surface.message.is_empty():_announce(surface.message);surface.message=""
		else:
			ship.step(dt,steering,roll,world.gravity_at(ship.position,nav.elapsed_days) if settings.orbital_gravity else Vector3.ZERO,lift)
			if world.protect_surface(ship,nav.elapsed_days):_announce(world.message)
	if not ship.last_notice.is_empty():_announce(ship.last_notice);ship.last_notice=""
	save_timer+=dt
	if save_timer>20:save_timer=0;_save_game()

func _update_flight_controls()->void:
	var blocked:=_blocked()
	for item in flight_widgets:item.visible=not blocked
	stick.input_allowed=not blocked and not ship.docked and ship.hull>0
	lever.input_allowed=stick.input_allowed
	for hold in holds:hold.input_allowed=stick.input_allowed
	flight_console.set_actions_enabled(not blocked)
	for button in action_buttons:
		if is_instance_valid(button):button.input_allowed=active and not busy
	if is_instance_valid(dock_services_view):
		for button in dock_services_view.action_buttons:button.input_allowed=active and not busy
func _process(dt:float)->void:
	_update_flight_controls()
	if not active:return
	var blocked:=_blocked()
	if not busy:_sync_scene()
	player.position=ship.position;player.quaternion=ship.attitude;player.visible=ship.external_view
	player.set_thrust(0.0 if ship.docked or surface.landed else clampf(maxf(absf(ship.target_speed),ship.velocity.length())/ship.MAX_SPEED,0.04,1.0))
	player.set_landed(surface.landed)
	var desired:Vector3=ship.position;var attitude:Quaternion=ship.attitude
	if ship.external_view:
		var span:float=ship.profile().visual_span_m;desired+=Basis(ship.attitude)*Vector3(0,span*0.34,span*1.65)
		attitude=(ship.attitude*Quaternion(Vector3.RIGHT,-atan(0.25/1.65))).normalized()
	if last_external!=ship.external_view:camera.position=desired;camera.quaternion=attitude;last_external=ship.external_view
	camera.position=camera.position.lerp(desired,minf(1,dt*30));camera.quaternion=camera.quaternion.slerp(attitude,minf(1,dt*25))
	notice_timer=maxf(0,notice_timer-dt);notice.visible=notice_timer>0 and not menu.visible and not settings_panel.visible
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
	return {"stick":[stick.value.x,stick.value.y] if stick!=null else [],"stick_pointer":stick.pointer_id if stick!=null else -1,"throttle_pointer":lever.pointer_id if lever!=null else -1,"lift_up":lift_up,"lift_down":lift_down,"active":active,"busy":busy,"menu_open":menu!=null and menu.visible,"settings_open":settings_panel!=null and settings_panel.visible}
func _flight_diagnostic_sample()->Dictionary:
	if ship==null or nav==null or world==null or surface==null:return {}
	return {"ship_id":ship.ship_id,"position":[ship.position.x,ship.position.y,ship.position.z],"velocity":[ship.velocity.x,ship.velocity.y,ship.velocity.z],"target_speed":ship.target_speed,"hull":ship.hull,"docked":ship.docked,"autopilot":ship.autopilot,"system_id":nav.current_id,"focus_id":world.focus_id,"site_id":world.site_id,"jump_remaining":nav.remaining,"transfer_remaining":world.transfer_remaining,"surface":surface.active,"landed":surface.landed,"flight_phase":surface.flight_phase,"surface_motion":{"landing":surface.landing,"taking_off":surface.taking_off,"altitude_m":surface.altitude(ship) if surface.active else 0.0,"pad_distance_m":surface.pad_distance(ship) if surface.active else 0.0},"controls":_input_diagnostic_state()}
func _diagnostic_context()->Dictionary:
	return {"build":{"version":BuildInfo.VERSION,"code":BuildInfo.VERSION_CODE,"channel":BuildInfo.CHANNEL},"mode":"graphics_preview" if not graphics_return.is_empty() else ("surface" if surface!=null and surface.active else "space"),"flight":_flight_diagnostic_sample(),"last_flight_sample":last_flight_sample,"settings":settings.snapshot(),"session":{"saving_enabled":saving_enabled,"save_generation":saves.sequence,"elapsed_days":nav.elapsed_days if nav!=null else 0,"source_clock":SourceClock.from_elapsed_days(nav.elapsed_days) if nav!=null else {},"source_runtime":world.source_runtime_state.duplicate(true) if world!=null else {},"source_orbit":world.orbit_backend_state.duplicate(true) if world!=null else {},"source_ports":world.port_backend_state.duplicate(true) if world!=null else {},"source_physics":world.source_physics_state.duplicate(true) if world!=null else {},"world_layout":world.layout_mode if world!=null else "","preferred_world_layout":world.preferred_layout() if world!=null else "","source_port_position_au":world.site_position_au(world.site_id,nav.elapsed_days) if world!=null and nav!=null else [],"origin_au":world.origin_au(nav.elapsed_days) if world!=null and nav!=null else []},"display":{"fps":Engine.get_frames_per_second(),"viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]}}

func _station_here()->bool:return not surface.active and (world.is_orbital_site() or (world.site_id.is_empty() and world.focus_id==world.default_id and nav.has_station()))
func _apply_system()->void:
	ship.original_port=not world.current_site().is_empty();ship.station_available=_station_here()
	celestial.configure(world);celestial.set_quality(settings.quality);player.configure(ship.profile())
	player.set_quality(settings.quality);station.configure(settings.quality);city_view.set_quality(settings.quality)
	if not graphics_return.is_empty():space_environment.configure(ship.STATION,settings.quality)
	station.position=ship.STATION;camera.position=ship.position;camera.quaternion=ship.attitude;presentation_key="";_sync_scene()

func _sync_scene()->void:
	var draw:RefCounted=surface if surface.active else null
	if surface.active:near.clear()
	elif near.update(surface,ship,world,nav.elapsed_days):draw=near.drawing
	var preview:bool=near.active;var high:bool=surface.active and surface.globe!=null and surface.extended_flight
	var layered:bool=preview or high
	var frame:Transform3D=near.frame if preview else (Near.world_frame(surface.globe,world,nav.elapsed_days) if high else Transform3D.IDENTITY)
	var to_scene:Transform3D=frame.affine_inverse() if high else Transform3D.IDENTITY
	var observer:Vector3=frame*ship.position if high else ship.position
	var blend:float=near.space_blend if preview else (Near.far_blend(surface.geoid_height(ship)) if high else 0.0)
	position=-ship.position if not surface.active else Vector3.ZERO
	ground_view.visible=draw!=null;ground_view.transform=near.frame if preview else Transform3D.IDENTITY
	if not city_view.configure(draw,ground_view.transform,1.0-blend if layered else 1.0):push_error(city_view.last_error)
	celestial.transform=to_scene;celestial.visible=not surface.active or high;celestial.set_surface_transition(layered,blend if layered else 1.0)
	station.visible=_station_here() and not preview
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
	if celestial.visible:celestial.update_view(nav.elapsed_days,camera.position)

func _refresh_hud()->void:
	var space_context:String=str(world.by_id[world.focus_id].name)
	if world.layout_mode==World.PORT_LAYOUT and world.is_orbital_site():space_context=str(world.current_site().name)
	var state:="СТЫКОВКА" if ship.docked else ("ПОСАДКА" if surface.landed else ("АВТО" if ship.autopilot or surface.landing or not surface.flight_phase.is_empty() else "ПОЛЁТ"))
	if ship.hull<=0:state="КОРАБЛЬ ПОТЕРЯН"
	hud.text="%s · %s · %s"%["Графический полёт" if not graphics_return.is_empty() else nav.current().name,ship.profile().name,state]
	auto_button.text="Службы" if ship.docked else ("На орбиту" if surface.active and surface.landed and surface.globe!=null else ("Отмена" if ship.autopilot or surface.landing or not surface.flight_phase.is_empty() else "Авто"))
	dock_button.text="Взлететь" if surface.landed else ("Вылететь" if ship.docked else "Посадка" if surface.active else "Стыковка")
	surface_button.text="Взлететь" if surface.active and surface.landed else ("На орбиту" if surface.active else "К поверхности")
	if surface.active:target_label.text="%s · высота %.0f м\nДо площадки %.0f м"%[surface.site_name if not surface.site_name.is_empty() else world.by_id[world.focus_id].name,maxf(0,surface.altitude(ship)),surface.pad_distance(ship)]
	else:target_label.text="%s · до станции %.0f м"%[space_context,ship.position.distance_to(ship.STATION)] if _station_here() else space_context
	var target:Vector3=surface.pad_position() if surface.active else (ship.STATION if _station_here() else world.local_meters(world.focus_id,nav.elapsed_days))
	flight_console.configure_state({"actual_speed_mps":ship.velocity.length(),"target_speed_mps":ship.target_speed,"surface_active":surface.active,"altitude_m":surface.altitude(ship) if surface.active else 0.0,"target_distance_m":ship.position.distance_to(target),"target_local":Basis(ship.attitude).inverse()*(target-ship.position),"hull_percent":ship.hull,"fuel":nav.fuel,"fuel_capacity":nav.FUEL_CAPACITY,"cargo_t":ship.total_cargo(),"totalcredits":ship.credits,"elapsed_days":nav.elapsed_days,"assisted":ship.assisted,"autopilot":ship.autopilot,"landing":surface.landing,"taking_off":surface.taking_off,"landed":surface.landed,"docked":ship.docked,"flight_phase":surface.flight_phase,"external_view":ship.external_view,"contextlabel":surface.site_name if surface.active and not surface.site_name.is_empty() else space_context,"auto_text":auto_button.text,"dock_text":dock_button.text})
	fps_label.visible=settings.show_fps;fps_label.text="%d FPS"%Engine.get_frames_per_second()

func _announce(text:String)->void:
	_record_event("notice",{"text":text})
	if notice:notice.text=text;notice_timer=7
	if menu_feedback:menu_feedback.text=text
	if settings_panel and settings_panel.visible:settings_panel.feedback.text=text
func _set_speed(value:float)->void:
	ship.autopilot=false;ship.target_speed=clampf(value,-100,ship.MAX_SPEED)
	if surface.active:surface.landing=false;surface.cancel_vertical()
func _brake()->void:
	ship.brake();_release_inputs()
	if surface.active:surface.landing=false;surface.cancel_vertical()
	if nav.remaining>0:nav.cancel_jump()
	if world.transfer_remaining>0:world.cancel_transfer()
	_announce("Торможение и удержание скорости.")
func _toggle_auto()->void:
	if ship.hull<=0:return
	if surface.active:
		if surface.landed:_begin_departure_action()
		elif surface.landing or not surface.flight_phase.is_empty():surface.landing=false;surface.cancel_vertical();_announce("Автоматический полёт отменён.")
		else:surface.begin_landing(ship);_announce(surface.message)
	elif ship.docked:_show_services()
	elif not _station_here():_announce("Автоподход доступен у станции. Выберите объект в системе.")
	else:ship.autopilot=not ship.autopilot;_announce("Автоподход к станции." if ship.autopilot else "Автоподход отменён.")
func _begin_departure_action()->bool:
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
	var previous_controls:=_input_diagnostic_state()
	_release_inputs()
	var accepted:bool=surface.take_off(ship)
	_record_event("surface_takeoff",{"accepted":accepted,"controls_before_release":previous_controls,"hull":ship.hull,"landed":surface.landed,"taking_off":surface.taking_off})
	_announce(surface.message);_refresh_hud()
	return accepted
func _dock_action()->void:
	if surface.active:
		if surface.landed:_takeoff_action();return
		if not surface.touch_down(ship):surface.begin_landing(ship)
		_announce(surface.message)
	elif ship.docked:ship.launch();_announce("Вылет выполнен. Корабль направлен от станции.")
	elif ship.dock():_announce("Стыковка выполнена. Службы доступны в меню.");_save_game()
	else:_announce("Для стыковки: дистанция до 100 м и скорость до 12 м/с. Используйте «Авто».")

func _surface_action()->void:
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
	if busy:return
	if nav.remaining>0:_announce("Сначала отмените гиперпереход кнопкой «Тормозить».");return
	if world.transfer_remaining>0:_announce("Сначала отмените автоперелёт кнопкой «Тормозить».");return
	if not surface.entry_error(ship,world).is_empty():_announce(surface.entry_error(ship,world));return
	var site:Dictionary=world.current_site()
	var entry_ship:RefCounted=ship;var entry_world:RefCounted=world
	if not site.is_empty() and int(site.get("model_index",-1))>=81 and int(site.get("model_index",-1))<=90:
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
func _finish_ascent()->void:
	if not surface.leave(ship,world,nav.elapsed_days):_announce(surface.message);return
	_apply_system();_announce("Выход на орбиту. Положение над планетой сохранено.");_save_game()

func _open_menu(title:String,save_progress:bool=true)->void:
	_record_event("menu_open",{"title":title,"controls_before_release":_input_diagnostic_state()})
	_release_inputs()
	if save_progress:_save_game()
	menu_title.text=title
	for child in menu_rows.get_children():menu_rows.remove_child(child);child.queue_free()
	dock_services_view=null
	menu.show()
	_update_flight_controls()
func _menu_text(text:String)->void:
	var label:=_label(text,21);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=900;menu_rows.add_child(label)
func _menu_action(text:String,callback:Callable)->void:
	menu_rows.add_child(_button(text,callback,900))
func _close_menu()->void:menu.hide();backup_edit=null;_release_inputs();_update_flight_controls()
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
	if busy or not graphics_return.is_empty():return
	if saving_enabled and not _save_game():return
	_release_inputs()
	graphics_return={"ship":ship,"nav":nav,"world":world,"surface":surface,"saving_enabled":saving_enabled}
	saving_enabled=false;_new_models();ship.external_view=true;nav.elapsed_days=225.0;ship.target_speed=0;ship.attitude=Quaternion(Vector3.UP,-0.38)
	_close_menu();_apply_system();_refresh_hud();_announce("Осмотрите обновлённый корабль и станцию. Вернуться к основному полёту можно через меню.")
func _end_graphics_demo()->void:
	if busy or graphics_return.is_empty():return
	_release_inputs();ship=graphics_return.ship;nav=graphics_return.nav;world=graphics_return.world;surface=graphics_return.surface;saving_enabled=graphics_return.saving_enabled
	graphics_return={};near.clear();_close_menu();_apply_system();_refresh_hud();_announce("Основной полёт продолжен.")
func _show_system()->void:
	_open_menu("%s · ОБЪЕКТЫ И КОСМОПОРТЫ"%nav.current().name)
	_menu_text("Для автоперелёта остановитесь. После вылета отойдите от станции минимум на 400 м.")
	for body in world.bodies:
		if body.kind in ["star","barycenter"]:continue
		var id:String=str(body.id)
		_menu_action("%s · подойти к объекту"%body.name,func():_choose_body(id))
		for site in world.settlements:
			if str(site.parent)!=id:continue
			var site_id:String=str(site.id)
			_menu_action("    %s · %s"%[site.name,"наземный порт" if int(site.type_code)==35 else "орбитальный порт"],func():_choose_site(site_id))
func _choose_body(id:String)->void:
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
	if busy:return
	if surface.active:_announce("Сначала вернитесь на орбиту.");return
	if world.transfer_remaining>0:
		if world.pending_site_id==id:world.cancel_transfer();_announce(world.message)
		else:_announce("Сначала отмените текущий автоперелёт кнопкой «Тормозить».")
		return
	if world.begin_site_transfer(id,ship,nav):_close_menu()
	_announce(world.message)
func _show_routes()->void:
	_open_menu("МАРШРУТЫ ВОССТАНОВЛЕННЫХ СИСТЕМ")
	_menu_text("Здесь доступны 11 восстановленных систем. Это временная схема маршрутов; полная исходная карта галактики ещё не возвращена.")
	for star in nav.galaxy.all():
		var id:int=int(star.id);var distance:float=nav.galaxy.distance(nav.current_id,id)
		_menu_action("%s · %.1f св. лет"%[star.name,distance],func():_start_jump(id))
func _start_jump(id:int)->void:
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
	dock_services_view=DockServicesView.new()
	dock_services_view.configure_state(DockServices.service_state(ship,nav))
	dock_services_view.command.connect(_service_command)
	menu_rows.add_child(dock_services_view)
func _service_command(action:String,id:String="")->void:
	if busy:return
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
	if is_instance_valid(dock_services_view):dock_services_view.configure_state(DockServices.service_state(ship,nav))
	_refresh_hud();_announce(feedback)
func _show_help()->void:
	_open_menu("УПРАВЛЕНИЕ И СБОРКА")
	_menu_text("Левый стик меняет направление носа. Правая шкала задаёт скорость. «Тормозить» отменяет автоматический полёт и плавно останавливает корабль. «Авто» ведёт к станции или площадке; после посадки команда «На орбиту» выполняет автоматический вылет. «Взлететь» оставляет управление вам после короткого подъёма. Кнопки подъёма и снижения помогают лететь над землёй. В доке кнопка «Службы» открывает обслуживание.")
	_menu_text("Клавиатура: стрелки — поворот, W/S — скорость, Q/E — крен, R/F — подъём, пробел — тормоз, A — авто, L — поверхность/орбита, D — стыковка/взлёт, V — вид, Esc — меню.")
	_menu_text("Сборка %s. Отчёт об ошибке и журналы можно сохранить ZIP-архивом через меню. Осмотрите корабль, планеты и станцию через «Графический полёт». Полёт и данные исходных миров возвращены частично. Новые полёты используют исходные расчёты орбит JJFFE и положения орбитальных портов. Форма станции и стыковочный коридор пока адаптированы. Радиусы, гравитация, карта маршрутов, три лётных профиля и учебная торговля пока используют адаптации. Полная кампания, исходная экономика и ИИ ещё не готовы. Проверка на настоящем телефоне нужна отдельно."%BuildInfo.VERSION)

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
	_menu_action("Начать новый полёт",func():_new_models();saving_enabled=true;_close_menu();_apply_system();_save_game();_announce("Начат новый полёт."))

func _payload()->Dictionary:return {"schema":"starfrontier-rebuild-game-v1","flight":ship.snapshot(),"navigation":nav.snapshot(),"planetary":world.snapshot(),"surface":surface.snapshot()}
func _decode_state(data:Dictionary)->Dictionary:
	if data.get("schema")!="starfrontier-rebuild-game-v1":return {}
	for key in ["flight","navigation","planetary","surface"]:
		if not data.get(key) is Dictionary:return {}
	var candidate_ship:=Flight.new();var candidate_nav:=NavigationData.new()
	if not candidate_ship.restore(data.flight) or not candidate_nav.restore(data.navigation):return {}
	var candidate_world:=World.new();candidate_world.configure(candidate_nav.current())
	if not candidate_world.restore(data.planetary):return {}
	var candidate_surface:=Surface.new()
	if not candidate_surface.restore(data.surface,candidate_ship,candidate_world):return {}
	if candidate_surface.active and (candidate_ship.docked or candidate_nav.remaining>0 or candidate_world.transfer_remaining>0):return {}
	if candidate_nav.remaining>0 and candidate_world.transfer_remaining>0:return {}
	if candidate_ship.docked:
		if candidate_nav.remaining>0 or candidate_world.transfer_remaining>0:return {}
		if not candidate_world.is_orbital_site() and not (candidate_world.site_id.is_empty() and candidate_world.focus_id==candidate_world.default_id and candidate_nav.has_station()):return {}
		if candidate_ship.position.distance_to(candidate_ship.STATION)>candidate_ship.DOCK_RADIUS+0.01 or candidate_ship.velocity.length()>0.001 or absf(candidate_ship.target_speed)>0.001:return {}
	return {"ship":candidate_ship,"nav":candidate_nav,"world":candidate_world,"surface":candidate_surface}
func _commit_state(data:Dictionary)->void:
	ship=data.ship;nav=data.nav;world=data.world;surface=data.surface;near.clear()
func _save_game()->bool:
	if not saving_enabled or busy:return false
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
func _show_backup()->void:
	if not graphics_return.is_empty():_announce("Для резервной копии вернитесь к основному полёту через меню.");return
	settings_panel.hide();_open_menu("РЕЗЕРВНАЯ КОПИЯ")
	_menu_text("Скопируйте код и сохраните его вне приложения. Для восстановления вставьте код сюда. Формат относится к этой восстановительной сборке.")
	backup_edit=TextEdit.new();backup_edit.custom_minimum_size=Vector2(900,230);backup_edit.add_theme_font_size_override("font_size",settings.reading_size);backup_edit.text=saves.encode(_payload(),0);menu_rows.add_child(backup_edit)
	_menu_action("Копировать код",func():DisplayServer.clipboard_set(backup_edit.text);_announce("Код резервной копии скопирован."))
	_menu_action("Вставить из буфера",func():backup_edit.text=DisplayServer.clipboard_get())
	_menu_action("Восстановить из кода",_import_backup)
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
		elif menu.visible:_close_menu()
		else:_show_menu()
		return
	if _blocked():return
	match event.physical_keycode:
		KEY_SPACE:_brake()
		KEY_A:_toggle_auto()
		KEY_D:_dock_action()
		KEY_L:_surface_action()
		KEY_V:ship.external_view=not ship.external_view
		KEY_M:_show_system()
func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		if diagnostics!=null and not automated:diagnostics.lifecycle("paused" if what==NOTIFICATION_APPLICATION_PAUSED else "focus_out")
		active=false;_release_inputs()
		if ship!=null and (report_export==null or not report_export.is_busy()):_save_game()
	elif what==NOTIFICATION_APPLICATION_RESUMED or what==NOTIFICATION_APPLICATION_FOCUS_IN:
		active=true
		if diagnostics!=null and not automated:diagnostics.lifecycle("resumed" if what==NOTIFICATION_APPLICATION_RESUMED else "focus_in")
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if menu!=null:
			if settings_panel.visible:_close_settings()
			elif menu.visible:_close_menu()
			else:_show_menu()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game();get_tree().quit()
func _exit_tree()->void:
	if diagnostics!=null:diagnostics.shutdown(true)
	if worker!=null and worker.is_started():worker.wait_to_finish()

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
