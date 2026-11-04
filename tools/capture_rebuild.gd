extends SceneTree
# Render the actual game scene through desktop GLES; never changes user progress.
var game:Node3D
func _initialize()->void:
	call_deferred("_capture")
func _frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw
func _image(name:String)->void:
	await _frame()
	var path:="res://build/screenshots/"+name+".png"
	if root.get_texture().get_image().save_png(path)!=OK:
		push_error("Cannot save rendered capture: "+path);quit(1)
func _capture()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Capture requires --rebuild-capture");quit(1);return
	DirAccess.make_dir_recursive_absolute("res://build/screenshots")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await _image("01-space")
	game._show_system();await _image("02-system");game._close_menu()
	game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id="site10";game._apply_system()
	await game._enter_surface()
	game._refresh_hud();game.notice_timer=0
	await _image("03-new-moscow-approach")
	game.surface.begin_landing(game.ship)
	for step in range(24000):
		game.surface.step(0.05,game.ship,Vector2.ZERO,0)
		if game.surface.landed:break
	game.ship.external_view=true;game._refresh_hud()
	await _image("04-new-moscow-landed")
	print("REBUILD RENDER CAPTURES PASS: actual space/system/native city approach/landing")
	game.queue_free();await process_frame;quit()
