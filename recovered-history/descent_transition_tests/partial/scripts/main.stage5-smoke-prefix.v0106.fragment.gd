func _run_stage5_smoke() -> void:
	help_panel.hide()
	model=Flight.new();combat=Combat.new();surface=Surface.new();nav=Navigation.new();planetary.configure(nav.current())
	_apply_system()
	# An actual 0.4 envelope lacks combat/surface state.
	var legacy4:={"format_version":4,"flight":model.snapshot(),"navigation":nav.snapshot(),"planetary":planetary.snapshot()}
	legacy4.flight.credits=1666
	var legacy_file:=FileAccess.open("user://flight.json",FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy4));legacy_file.close()
	_load_game()
	if model.credits!=1666 or combat.active or surface.active or planetary.focus_id!="earth":
		push_error("STAGE5 SMOKE FAILED: 0.4 migration");get_tree().quit(1);return
	_combat_action()
	combat.shield=19;combat.enemy_hull=40
	_save_game(false)
	model=Flight.new();combat=Combat.new();surface=Surface.new();nav=Navigation.new();planetary=Planetary.new()
	_load_game()
	if not combat.active or not model.combat_active or combat.shield!=19 or combat.enemy_hull!=40:
		push_error("STAGE5 SMOKE FAILED: combat file persistence");get_tree().quit(1);return
	var original_model:=model
	var invalid: Variant=_read_save_data()
	invalid.combat.shield=61
	var bad_file:=FileAccess.open("user://flight.json",FileAccess.WRITE)
	bad_file.store_string(JSON.stringify(invalid));bad_file.close()
	_load_game()
	if model!=original_model or combat.shield!=19 or not model.combat_active:
		push_error("STAGE5 SMOKE FAILED: atomic invalid-save rejection");get_tree().quit(1);return
	_save_game(false)
	if nav.begin_jump(model) or planetary.begin_transfer(model,nav):
		push_error("STAGE5 SMOKE FAILED: encounter escape guards");get_tree().quit(1);return
	combat.enemy_position=model.position+model.forward()*1000
	_fire();combat.cooldown=0;combat.heat=0;_fire()
	if combat.active or combat.kills!=1:
		push_error("STAGE5 SMOKE FAILED: combat kill through UI");get_tree().quit(1);return
	_surface_action();_settle_vertical_for_test()
	if not surface.active or not surface_root.visible or celestial_root.visible:
		push_error("STAGE5 SMOKE FAILED: surface render mode");get_tree().quit(1);return
	_toggle_auto()
