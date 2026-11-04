func _surface_action() -> void:
	_release_inputs()
	if campaign.guard_available(nav):_announce("Сначала устраните угрозу охраны INRA через панель «Контакт».");return
	if not app_active or help_panel.visible or map_overlay.visible or system_panel.visible or hangar_panel.visible or services_panel.visible or story_panel.visible or model.hull<=0:return
	stick.release();roll_left=false;roll_right=false
	if campaign.remaining>0 or nav.remaining>0 or planetary.transfer_remaining>0 or combat.active:return
	fire_held=false
	var was_active:bool=surface.active
	var camera_before:Transform3D=camera.transform
	var incoming_frame:=Transform3D.IDENTITY
	var from_preview:=false
	if surface.active:
		if surface.landed:surface.take_off(model)
		elif not surface.flight_phase.is_empty():surface.cancel_vertical();model.brake()
		elif surface.globe:surface.begin_ascent(model)
		elif surface.leave(model,planetary,nav.elapsed_days):planetary.site_id=""
	else:
		from_preview=near_surface_view.update(surface,model,planetary,nav.elapsed_days)
		if from_preview:incoming_frame=near_surface_view.frame
		near_surface_view.enter_descent(surface,model,planetary,nav.elapsed_days)
	_apply_system()
	if not was_active and surface.active:
		if from_preview:camera.transform=incoming_frame.affine_inverse()*camera_before
		else:camera.position=model.position;camera.quaternion=model.attitude
	_announce(surface.message)
	_save_game(false)
	_refresh_hud()
