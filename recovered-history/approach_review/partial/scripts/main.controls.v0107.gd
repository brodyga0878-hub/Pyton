func _brake() -> void:
	_release_inputs()
	if campaign.remaining>0:campaign.cancel_transition()
	if surface.active: surface.landing=false;surface.cancel_vertical()
	if nav.remaining>0: nav.cancel_jump()
	if planetary.transfer_remaining>0: planetary.cancel_transfer()
	model.brake()
	_announce("Торможение. Помощник гасит движение с доступной тягой.")

func _toggle_auto() -> void:
	if surface.active:
		_release_inputs()
		if not surface.flight_phase.is_empty():surface.cancel_vertical();model.brake()
		elif surface.extended_flight and surface.altitude(model)>3000:surface.resume_descent(model)
		else:surface.begin_landing(model)
		_announce(surface.message)
		return
	if combat.active:
		combat.aim_lock=not combat.aim_lock
		_announce("Наведение: %s. Стик отменяет наведение."%combat.enemy_name() if combat.aim_lock else "Наведение отключено.")
		return
	if model.docked or model.hull <= 0 or not _station_here() or nav.remaining>0 or planetary.transfer_remaining>0 or campaign.remaining>0: return
	model.autopilot = not model.autopilot
	_announce("Автопилот: заход и стыковка с «%s»."%nav.station_name() if model.autopilot else "Автопилот отключён.")

func _toggle_assist() -> void:
	if surface.active: surface.landing=false;surface.cancel_vertical()
	model.assisted = not model.assisted
	model.autopilot = false
	model.target_speed = 0
	_announce("Помощь пилота включена." if model.assisted else "Ручная тяга: для остановки нажмите «Тормозить».")

func _dock() -> void:
	if surface.active:
		if surface.touch_down(model): _announce(surface.message);_save_game(false)
		return
	if model.dock():
		station_panel.show()
		_save_game()
	else:
		_announce("Нужны расстояние до 100 м и скорость до 12 м/с.")
