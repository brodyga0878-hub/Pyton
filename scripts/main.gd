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
const ShipView=preload("res://scripts/ship_visual.gd")
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
var celestial:Node3D
var ground_view:Node3D
var city_view:Node3D
var station:Node3D
var player:Node3D
var stars:MultiMeshInstance3D
var ui:Control
var hud:Label
var notice:Label
var target_label:Label
var fps_label:Label
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

func _ready()->void:
	get_tree().auto_accept_quit=false
	automated="--rebuild-smoke" in OS.get_cmdline_user_args() or "--rebuild-capture" in OS.get_cmdline_user_args()
	saving_enabled=not automated
	settings.load_file();_new_models();_build_world();_build_ui();_apply_settings()
	if not automated:_load_game()
	_apply_system();_refresh_hud()
	if notice_timer<=0:_announce("Стик — поворот. Справа — скорость. «Авто» помогает подойти к станции.")
	get_viewport().size_changed.connect(_safe_area)
	_safe_area()
	if "--rebuild-smoke" in OS.get_cmdline_user_args():call_deferred("_run_smoke")

func _new_models()->void:
	ship=Flight.new();nav=NavigationData.new();world=World.new();world.configure(nav.current());surface=Surface.new();near.clear()

func _build_world()->void:
	environment=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("020712")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("91b5cf");environment.environment.ambient_light_energy=0.3
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;add_child(environment)
	sunlight=DirectionalLight3D.new();sunlight.light_color=Color("ffe9ca");sunlight.light_energy=2;sunlight.rotation_degrees=Vector3(-50,-30,0);add_child(sunlight)
	camera=Camera3D.new();camera.fov=74;camera.near=0.5;camera.far=180000;add_child(camera);camera.make_current()
	celestial=Celestial.new();add_child(celestial)
	ground_view=SurfaceView.new();add_child(ground_view);ground_view.hide()
	city_view=CityView.new();add_child(city_view);city_view.hide()
	player=ShipView.new();add_child(player);player.configure(ship.profile())
	station=Node3D.new();add_child(station)
	var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=27;torus.outer_radius=44;torus.rings=64;torus.ring_segments=12;ring.mesh=torus;ring.rotation.x=PI/2
	var metal:=StandardMaterial3D.new();metal.albedo_color=Color("bda77d");metal.metallic=0.6;metal.roughness=0.35;ring.material_override=metal;station.add_child(ring)
	for angle in range(4):
		var light:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(5,5,5);light.mesh=box;light.position=Vector3(cos(angle*PI/2)*48,sin(angle*PI/2)*48,0)
		var glow:=StandardMaterial3D.new();glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glow.albedo_color=Color("65e5cb");light.material_override=glow;station.add_child(light)
	stars=MultiMeshInstance3D.new();var star_mesh:=SphereMesh.new();star_mesh.radius=12;star_mesh.height=24;star_mesh.radial_segments=4;star_mesh.rings=2
	var star_material:=StandardMaterial3D.new();star_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;star_material.albedo_color=Color("c9d9e9");star_mesh.material=star_material
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=star_mesh;multi.instance_count=1800
	var rng:=RandomNumberGenerator.new();rng.seed=784112
	for i in range(multi.instance_count):
		var direction:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(0.5,1.6)),direction*50000))
	stars.multimesh=multi;add_child(stars)

func _button(text:String,callback:Callable,width:=150.0)->Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(width,76);button.focus_mode=Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",22);button.pressed.connect(callback);return button
func _label(text:String,size_value:=20)->Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",size_value);return label
func _anchored(node:Control,preset:int,offsets:Vector4)->void:
	ui.add_child(node);node.set_anchors_and_offsets_preset(preset)
	node.offset_left=offsets.x;node.offset_top=offsets.y;node.offset_right=offsets.z;node.offset_bottom=offsets.w

func _build_ui()->void:
	var layer:=CanvasLayer.new();add_child(layer);ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
	var top:=HBoxContainer.new();_anchored(top,Control.PRESET_TOP_WIDE,Vector4(18,10,-18,92));top.add_theme_constant_override("separation",12)
	flight_widgets.append(top)
	hud=_label("",21);hud.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(hud)
	top.add_child(_button("Система",_show_system,145));top.add_child(_button("Маршруты",_show_routes,155));top.add_child(_button("Меню",_show_menu,130))
	stick=Stick.new();_anchored(stick,Control.PRESET_BOTTOM_LEFT,Vector4(20,-250,250,-20));flight_widgets.append(stick)
	lever=Lever.new();_anchored(lever,Control.PRESET_BOTTOM_RIGHT,Vector4(-115,-315,-25,-20));lever.target_changed.connect(_set_speed);flight_widgets.append(lever)
	var caption:=_label("СКОРОСТЬ",16);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(caption,Control.PRESET_BOTTOM_RIGHT,Vector4(-125,-350,-15,-318));flight_widgets.append(caption)
	var lift1:=Hold.new();lift1.text="ПОДЪЁМ";_anchored(lift1,Control.PRESET_BOTTOM_RIGHT,Vector4(-275,-230,-135,-145));lift1.state_changed.connect(func(value:bool):lift_up=value);holds.append(lift1);flight_widgets.append(lift1)
	var lift2:=Hold.new();lift2.text="СНИЖЕНИЕ";_anchored(lift2,Control.PRESET_BOTTOM_RIGHT,Vector4(-275,-125,-135,-40));lift2.state_changed.connect(func(value:bool):lift_down=value);holds.append(lift2);flight_widgets.append(lift2)
	var controls:=HBoxContainer.new();controls.add_theme_constant_override("separation",12);_anchored(controls,Control.PRESET_CENTER_BOTTOM,Vector4(-330,-106,330,-24))
	auto_button=_button("Авто",_toggle_auto,150);controls.add_child(auto_button)
	controls.add_child(_button("Тормозить",_brake,175));dock_button=_button("Стыковка",_dock_action,175);controls.add_child(dock_button);flight_widgets.append(controls)
	surface_button=_button("К поверхности",_surface_action,215);_anchored(surface_button,Control.PRESET_TOP_RIGHT,Vector4(-240,110,-25,190));flight_widgets.append(surface_button)
	var view_button:=_button("Вид",func():ship.external_view=not ship.external_view,110);_anchored(view_button,Control.PRESET_TOP_RIGHT,Vector4(-135,205,-25,281));flight_widgets.append(view_button)
	var cross:=_label("＋",30);cross.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(cross,Control.PRESET_CENTER,Vector4(-25,-25,25,25));cross.mouse_filter=Control.MOUSE_FILTER_IGNORE;flight_widgets.append(cross)
	target_label=_label("",19);target_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(target_label,Control.PRESET_CENTER_TOP,Vector4(-330,100,330,150));target_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	flight_widgets.append(target_label)
	notice=_label("",21);notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_anchored(notice,Control.PRESET_CENTER_BOTTOM,Vector4(-430,-190,430,-115));notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fps_label=_label("",16);_anchored(fps_label,Control.PRESET_BOTTOM_LEFT,Vector4(25,-280,230,-250))
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
			world.configure(nav.current());surface=Surface.new();near.clear();_apply_system();_announce(nav.message);_save_game()
	elif world.transfer_remaining>0:
		if world.step_transfer(dt,ship,nav):
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

func _process(dt:float)->void:
	if not active:return
	var blocked:=_blocked()
	for item in flight_widgets:item.visible=not blocked
	stick.input_allowed=not blocked and not ship.docked and ship.hull>0
	lever.input_allowed=stick.input_allowed
	for hold in holds:hold.input_allowed=stick.input_allowed
	if not busy:_sync_scene()
	player.position=ship.position;player.quaternion=ship.attitude;player.visible=ship.external_view
	var desired:Vector3=ship.position;var attitude:Quaternion=ship.attitude
	if ship.external_view:
		var span:float=ship.profile().visual_span_m;desired+=Basis(ship.attitude)*Vector3(0,span*0.55,span*2.8)
		attitude=(ship.attitude*Quaternion(Vector3.RIGHT,-atan(0.55/3.5))).normalized()
	if last_external!=ship.external_view:camera.position=desired;camera.quaternion=attitude;last_external=ship.external_view
	camera.position=camera.position.lerp(desired,minf(1,dt*30));camera.quaternion=camera.quaternion.slerp(attitude,minf(1,dt*25))
	notice_timer=maxf(0,notice_timer-dt);notice.visible=notice_timer>0 and not menu.visible and not settings_panel.visible
	menu_feedback.visible=notice_timer>0 and not menu_feedback.text.is_empty()
	hud_timer+=dt
	if hud_timer>0.15:hud_timer=0;_refresh_hud()
	lever.display_value(ship.target_speed)

func _station_here()->bool:return not surface.active and (world.is_orbital_site() or (world.site_id.is_empty() and world.focus_id==world.default_id and nav.has_station()))
func _apply_system()->void:
	ship.original_port=not world.current_site().is_empty();ship.station_available=_station_here()
	celestial.configure(world);celestial.set_quality(settings.quality);player.configure(ship.profile())
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
	var state:="СТЫКОВКА" if ship.docked else ("ПОСАДКА" if surface.landed else ("АВТО" if ship.autopilot or surface.landing or not surface.flight_phase.is_empty() else "ПОЛЁТ"))
	if ship.hull<=0:state="КОРАБЛЬ ПОТЕРЯН"
	hud.text="%s · %s · %s\n%.0f м/с  |  Корпус %.0f%%  |  %d кр.  |  Топливо %d/%d"%[nav.current().name,ship.profile().name,state,ship.velocity.length(),ship.hull,ship.credits,nav.fuel,nav.FUEL_CAPACITY]
	auto_button.text="Отменить авто" if ship.autopilot or surface.landing or not surface.flight_phase.is_empty() else "Авто"
	dock_button.text="Взлететь" if surface.landed else ("Вылететь" if ship.docked else "Посадка" if surface.active else "Стыковка")
	surface_button.text="На орбиту" if surface.active else "К поверхности"
	if surface.active:target_label.text="%s · высота %.0f м\nДо площадки %.0f м"%[surface.site_name if not surface.site_name.is_empty() else world.by_id[world.focus_id].name,maxf(0,surface.altitude(ship)),surface.pad_distance(ship)]
	else:target_label.text="%s · до станции %.0f м"%[world.by_id[world.focus_id].name,ship.position.distance_to(ship.STATION)] if _station_here() else str(world.by_id[world.focus_id].name)
	fps_label.visible=settings.show_fps;fps_label.text="%d FPS"%Engine.get_frames_per_second()

func _announce(text:String)->void:
	if notice:notice.text=text;notice_timer=7
	if menu_feedback:menu_feedback.text=text
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
		if surface.landing or not surface.flight_phase.is_empty():surface.landing=false;surface.cancel_vertical();_announce("Автоматический полёт отменён.")
		else:surface.begin_landing(ship);_announce(surface.message)
	elif ship.docked:_announce("Сначала вылетите со станции.")
	elif not _station_here():_announce("Автоподход доступен у станции. Выберите объект в системе.")
	else:ship.autopilot=not ship.autopilot;_announce("Автоподход к станции." if ship.autopilot else "Автоподход отменён.")
func _dock_action()->void:
	if surface.active:
		if surface.landed:surface.take_off(ship)
		elif not surface.touch_down(ship):surface.begin_landing(ship)
		_announce(surface.message)
	elif ship.docked:ship.launch();_announce("Вылет выполнен. Корабль направлен от станции.")
	elif ship.dock():_announce("Стыковка выполнена. Службы доступны в меню.");_save_game()
	else:_announce("Для стыковки: дистанция до 100 м и скорость до 12 м/с. Используйте «Авто».")

func _surface_action()->void:
	if busy:return
	if surface.active:
		if surface.landed:surface.take_off(ship);_announce(surface.message)
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

func _open_menu(title:String)->void:
	_release_inputs();_save_game();menu_title.text=title
	for child in menu_rows.get_children():menu_rows.remove_child(child);child.queue_free()
	menu.show()
func _menu_text(text:String)->void:
	var label:=_label(text,21);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=900;menu_rows.add_child(label)
func _menu_action(text:String,callback:Callable)->void:
	menu_rows.add_child(_button(text,callback,900))
func _close_menu()->void:menu.hide();backup_edit=null;_release_inputs()
func _show_menu()->void:
	_open_menu("КОМАНДИР")
	_menu_action("Продолжить полёт",_close_menu)
	_menu_action("Космопорты и объекты системы",_show_system)
	_menu_action("Маршруты между системами",_show_routes)
	if ship.docked:_menu_action("Службы станции и корабли",_show_services)
	_menu_action("Настройки телефона",func():menu.hide();settings_panel.configure(settings);settings_panel.show())
	_menu_action("Сохранить сейчас",func():
		if _save_game():_announce("Полёт сохранён.");_close_menu()
	)
	_menu_action("Резервная копия",_show_backup)
	_menu_action("Управление и сведения о сборке",_show_help)
	_menu_action("Начать новый полёт…",_confirm_new_game)
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
func _show_services()->void:
	_open_menu("СЛУЖБЫ СТАНЦИИ")
	_menu_text("Баланс: %d кр. · груз: %d/%d т"%[ship.credits,ship.total_cargo(),ship.cargo_capacity()])
	if ship.original_port:
		_menu_text("Службы исходных космопортов ещё восстанавливаются. Учебный рынок доступен у тренировочного стыковочного узла.");return
	_menu_action("Сдать учебный груз лекарств",func():_announce("Учебная доставка завершена." if ship.deliver() else "Нет подходящего груза для доставки.");_save_game();_show_services())
	_menu_action("Купить 1 т лекарств · 100 кр.",func():_announce("Груз загружен." if ship.buy() else "Покупка недоступна: проверьте деньги и трюм.");_save_game();_show_services())
	_menu_action("Продать 1 т лекарств",func():_announce("Груз продан." if ship.sell() else "Нет груза для продажи.");_save_game();_show_services())
	_menu_action("Заправить гипердвигатель",func():nav.refuel(ship);_announce(nav.message);_save_game();_show_services())
	for profile in ship.catalog.all():
		var id:String=str(profile.id)
		_menu_action("Корабль: %s · трюм %d т"%[profile.name,profile.cargo_capacity],func():_announce("Корабль заменён." if ship.trade_ship(id) else "Обмен недоступен: проверьте средства, груз и оборудование.");_apply_system();_save_game();_show_services())
func _show_help()->void:
	_open_menu("УПРАВЛЕНИЕ И СБОРКА")
	_menu_text("Левый стик меняет направление носа. Правая шкала задаёт скорость. «Тормозить» включает плавную остановку; «Авто» ведёт к станции или посадочной площадке. Кнопки подъёма и снижения помогают висеть над землёй.")
	_menu_text("Клавиатура: стрелки — поворот, W/S — скорость, Q/E — крен, R/F — подъём, пробел — тормоз, A — авто, L — поверхность/орбита, D — стыковка/взлёт, V — вид, Esc — меню.")
	_menu_text("Восстановительная альфа 0.11.0. Полёт и данные исходных миров возвращены частично. Карта маршрутов, физика орбит, три лётных профиля и учебная торговля — адаптации. Полная кампания, исходная экономика и ИИ ещё не готовы. Проверка на настоящем телефоне нужна отдельно.")
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
	if not ok:_announce(saves.last_error)
	return ok
func _load_game()->bool:
	var loaded:Dictionary=saves.load_valid(_decode_state)
	if not loaded.is_empty():_commit_state(loaded);return true
	if FileAccess.file_exists(saves.directory+"/slot0.json") or FileAccess.file_exists(saves.directory+"/slot1.json"):
		saving_enabled=false;_announce("Сохранение не прочитано. Копии оставлены; новый полёт можно начать через меню.")
	return false
func _show_backup()->void:
	settings_panel.hide();_open_menu("РЕЗЕРВНАЯ КОПИЯ")
	_menu_text("Скопируйте код и сохраните его вне приложения. Для восстановления вставьте код сюда. Формат относится к этой восстановительной сборке.")
	backup_edit=TextEdit.new();backup_edit.custom_minimum_size=Vector2(900,230);backup_edit.add_theme_font_size_override("font_size",settings.reading_size);backup_edit.text=saves.encode(_payload(),0);menu_rows.add_child(backup_edit)
	_menu_action("Копировать код",func():DisplayServer.clipboard_set(backup_edit.text);_announce("Код резервной копии скопирован."))
	_menu_action("Вставить из буфера",func():backup_edit.text=DisplayServer.clipboard_get())
	_menu_action("Восстановить из кода",_import_backup)
func _import_backup()->void:
	if busy:return
	var entry:Dictionary=saves.decode(backup_edit.text)
	var loaded:Dictionary={} if entry.is_empty() else _decode_state(entry.payload)
	if loaded.is_empty():_announce("Код повреждён или несовместим. Текущий полёт не изменён.");return
	_commit_state(loaded);saving_enabled=true;_close_menu();_apply_system();_save_game();_announce("Резервная копия восстановлена.")
func _apply_settings()->void:
	Engine.max_fps=settings.fps;get_viewport().msaa_3d=settings.msaa();ground_view.set_quality(settings.quality);celestial.set_quality(settings.quality);stick.deadzone=settings.deadzone;presentation_key=""
func _settings_changed()->void:_apply_settings();settings.save_file()
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
		active=false;_release_inputs()
		if ship!=null:_save_game()
	elif what==NOTIFICATION_APPLICATION_RESUMED or what==NOTIFICATION_APPLICATION_FOCUS_IN:active=true
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if menu!=null:
			if settings_panel.visible:_close_settings()
			elif menu.visible:_close_menu()
			else:_show_menu()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game();get_tree().quit()
func _exit_tree()->void:
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
