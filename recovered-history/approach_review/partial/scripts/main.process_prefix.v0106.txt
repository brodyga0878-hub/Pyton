	speed_slider.input_allowed=not full_menu and not model.docked and model.hull>0
	get_viewport().disable_3d=full_menu
	if not benchmarking:Engine.max_fps=mini(30,device_settings.fps) if full_menu else device_settings.fps
	if full_menu:
		hud_time+=dt
		if hud_time>0.2:_refresh_hud();hud_time=0
		_capture_tick()
		return
	_sync_planet_visuals()
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
	aim_reticle.visible=not camera.is_position_behind(_view_point(aiming_point))
	if aim_reticle.visible:aim_reticle.position=camera.unproject_position(_view_point(aiming_point))-ui.position-Vector2(18,30)
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
