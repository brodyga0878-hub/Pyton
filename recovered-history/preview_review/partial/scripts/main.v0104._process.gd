func _process(dt: float) -> void:
	if not app_active:return
	var full_menu:=help_panel.visible or settings_panel.visible or story_panel.visible or services_panel.visible or hangar_panel.visible or map_overlay.visible or system_panel.visible or resume_panel.visible
	if full_menu!=flight_widgets_hidden:
		for widget in flight_widgets:widget.visible=not full_menu
		flight_widgets_hidden=full_menu
		if not full_menu:_refresh_hud()
	for hold in hold_buttons:hold.input_allowed=not full_menu and not model.docked and model.hull>0
	speed_slider.input_allowed=not full_menu and not model.docked and model.hull>0
	get_viewport().disable_3d=full_menu
	if not benchmarking:Engine.max_fps=mini(30,device_settings.fps) if full_menu else device_settings.fps
	if full_menu:
		hud_time+=dt
		if hud_time>0.2:_refresh_hud();hud_time=0
		_capture_tick()
		return
	if surface.active:
		surface_root.configure(surface)
		var height:float=surface.altitude(model)
		camera.far=1100000.0 if surface.extended_flight else 180000.0
		camera.near=2.0 if height>5000 else 0.5
		world_presentation.update_height(world_environment.environment,surface,height,device_settings.quality)
		star_field.visible=surface.kind!="earth" or (surface.extended_flight and height>15000)
	else:camera.far=180000.0;camera.near=0.5
	player_root.position=model.position
	player_root.quaternion=model.attitude
	var desired_position:=model.position
	var desired_attitude:=model.attitude
	if model.external_view:
		var span:float=model.profile().visual_span_m
		desired_position+=Basis(model.attitude)*Vector3(0,span*0.55,span*2.8)
		desired_attitude=(model.attitude*Quaternion(Vector3.RIGHT,-atan(0.55/3.5))).normalized()
	if last_external_view!=model.external_view:
		camera.position=desired_position
		camera.quaternion=desired_attitude
		last_external_view=model.external_view
	camera.position = camera.position.lerp(desired_position,minf(dt*30,1))
	camera.quaternion = camera.quaternion.slerp(desired_attitude,minf(dt*25,1))
	player_ship.visible=model.external_view
	var thrust:=maxf(0,(model.target_speed-model.velocity.dot(model.forward()))/60.0) if model.assisted else maxf(0,model.target_speed/600.0)
	player_ship.set_thrust(clampf(thrust,0,1))
	var aiming_point:=model.position+model.forward()*2000.0
	aim_reticle.visible=not camera.is_position_behind(aiming_point)
	if aim_reticle.visible:aim_reticle.position=camera.unproject_position(aiming_point)-ui.position-Vector2(18,30)
	if not surface.active: celestial_root.update_view(nav.elapsed_days,camera.position)
	enemy_root.visible=combat.active
	enemy_root.position=combat.enemy_position
	enemy_root.quaternion=combat.enemy_attitude
	enemy_ship.visible=combat.enemy_kind!="thargoid"
	enemy_alien.visible=combat.enemy_kind=="thargoid"
	_update_aliens()
	enemy_ship.set_thrust(0.7 if combat.active else 0)
	enemy_laser.visible=combat.active and combat.enemy_flash>0
	if enemy_laser.visible:
		var beam_mesh:=ImmediateMesh.new()
		beam_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		beam_mesh.surface_add_vertex(combat.enemy_position)
		beam_mesh.surface_add_vertex(combat.enemy_beam_end)
		beam_mesh.surface_end()
		enemy_laser.mesh=beam_mesh
	enemy_label.visible=combat.active and not camera.is_position_behind(combat.enemy_position)
	if enemy_label.visible:
		enemy_label.position=camera.unproject_position(combat.enemy_position)-ui.position+Vector2(24,-25)
		enemy_label.text="□ %s · %d%% · %.1f км"%[combat.enemy_name().to_upper(),combat.enemy_hull,model.position.distance_to(combat.enemy_position)/1000]
	var sunlight: Vector3 = planetary.local_meters("star",nav.elapsed_days)-camera.position
	if not surface.active and sunlight.length()>1:
		var direction := sunlight.normalized()
		sun_light.look_at(sun_light.global_position-direction,Vector3.UP if absf(direction.y)<0.98 else Vector3.RIGHT)
	laser_time = maxf(0, laser_time-dt)
	laser.visible = laser_time > 0
	drone.rotation.y += dt * 0.25
	hud_time += dt
	if hud_time > 0.1:
		_refresh_hud()
		hud_time = 0
	var target_is_station := _station_here() and planetary.selected_id==planetary.focus_id
	var point:Vector3=surface.pad_position() if surface.active else Vector3.ZERO
	if not surface.active:
		if target_is_station:point=Flight.STATION
		elif celestial_root.visuals.has(planetary.selected_id):point=celestial_root.visuals[planetary.selected_id].anchor.position
		else:point=model.position+(planetary.local_meters(planetary.selected_id,nav.elapsed_days)-model.position).normalized()*80000
	target_label.visible = not camera.is_position_behind(point)
	if target_label.visible:
		target_label.position = camera.unproject_position(point)-ui.position+Vector2(20,-12)
	_capture_tick()
