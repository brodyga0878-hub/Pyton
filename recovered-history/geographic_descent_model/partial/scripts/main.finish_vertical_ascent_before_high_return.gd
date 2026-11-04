func _finish_vertical_ascent()->void:
	if not surface.ready_for_orbit:return
	var outgoing_frame:Transform3D=NearSurfaceView.world_frame(surface.globe,planetary,nav.elapsed_days)
	var camera_before:Transform3D=camera.transform
	if not surface.leave(model,planetary,nav.elapsed_days):return
	planetary.site_id="";_apply_system()
	camera.transform=outgoing_frame*camera_before
	_update_celestial_view()
	_announce("Подъём завершён: 20 км над планетой.");_save_game(false)
func _settle_vertical_for_test()->void:
	if OS.has_feature("android"):return
	for step in range(4000):
		if surface.flight_phase.is_empty():return
		nav.elapsed_days+=0.25/86400.0;_tick_economy()
		surface.step(0.25,model,Vector2.ZERO,0)
		if surface.ready_for_orbit:_finish_vertical_ascent()
