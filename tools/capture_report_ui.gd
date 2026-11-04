extends SceneTree
# Captures the real report form. No user progress or diagnostics are initialized.
var game:Node3D
func _initialize()->void:call_deferred("run")
func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():
		push_error("Use a real display and --rebuild-capture");quit(1);return
	DirAccess.make_dir_recursive_absolute("res://build/report-ui")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game._show_bug_report();game.report_description.text="После взлёта корабль продолжает поворачивать.\nПовторение: посадка → взлёт → отпустить стик."
	for i in range(5):await frame()
	var result:=root.get_texture().get_image().save_png("res://build/report-ui/bug-report-page.png")
	game.queue_free();await process_frame
	if result!=OK:push_error("Report UI capture failed");quit(1);return
	print("REPORT UI GLES CAPTURE PASS: actual report form, no user data loaded")
	quit()
