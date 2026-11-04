func _jump_action() -> void:
	if campaign.remaining>0:_announce("Сначала отмените экспедиционный переход кнопкой «Тормозить».");return
	if planetary.transfer_remaining>0:
		_announce("Сначала отмените автоперелёт к планете.")
		return
	if nav.remaining>0:
		nav.cancel_jump()
	else:
		if nav.begin_jump(model):
			_close_map()
			station_panel.hide()
			stick.release()
			roll_left = false
			roll_right = false
	_announce(nav.message)
	_refresh_hud()
