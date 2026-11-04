extends SceneTree
# Actual Main controller integration. All disk writes stay in a private test dir.
var game:Node3D
var checks:=0
var failures:=0
var test_directory:=""
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<20:push_error(message)
func payload()->String:return JSON.stringify(game._payload())
func references()->Array:return [game.ship,game.nav,game.world,game.surface]
func disk()->Dictionary:
	var result:Dictionary={}
	for slot in range(2):
		var file:=test_directory+"/slot%d.json"%slot
		if FileAccess.file_exists(file):result[slot]=FileAccess.get_file_as_string(file)
	return result
func action(text:String)->Button:
	for node in game.menu_rows.get_children():
		if node is Button and node.text==text:return node
	return null
func failed_pre_demo_save_blocks_entry()->void:
	DirAccess.make_dir_recursive_absolute(test_directory)
	var blocked:=test_directory+"/not-a-directory"
	var obstacle:=FileAccess.open(blocked,FileAccess.WRITE);obstacle.store_string("owned test obstacle");obstacle.close()
	game.saves.directory=blocked;game.saving_enabled=true
	var original:=references();var before:=payload();var sequence:int=game.saves.sequence
	game._show_menu();var start:=action("Графический полёт · осмотреть обновление")
	check(start!=null,"Failed-save regression uses the actual graphics menu action")
	if start!=null:start.pressed.emit()
	check(game.graphics_return.is_empty() and references()==original and payload()==before,"Failed pre-demo disk save prevents replacing the active flight")
	check(game.saving_enabled and game.menu.visible and game.saves.sequence==sequence,"Failed entry keeps the original saving policy, menu and save generation")
	check(not game.saves.last_error.is_empty() and game.notice.text==game.saves.last_error and game.menu_feedback.text==game.saves.last_error,"The real save error remains visible instead of a graphics-flight success message")
	check(FileAccess.get_file_as_string(blocked)=="owned test obstacle","Failed entry never overwrites the obstructing file")
	DirAccess.remove_absolute(blocked);game.saves.directory=test_directory;game.saving_enabled=false;game._close_menu()
func demo_preserves_pending_flight()->void:
	game.saving_enabled=true
	game.ship.credits=1789;game.ship.goods.food=3
	game._start_jump(int(game.nav.galaxy.all()[1].id))
	check(game.nav.remaining>0,"Original test flight has a real pending hypercharge")
	var original_refs:=references();var original_payload:=payload()
	game.busy=true;game._begin_graphics_demo()
	check(game.graphics_return.is_empty() and references()==original_refs,"Busy city preparation cannot enter graphics mode")
	game.busy=false
	game._show_menu()
	var start:=action("Графический полёт · осмотреть обновление")
	check(start!=null,"Actual commander menu exposes the graphics-flight action")
	if start==null:return
	game.stick.pointer_id=2;game.stick.value=Vector2(0.8,0.3)
	game.holds[0]._pointer_at(Vector2.ONE)
	start.pressed.emit()
	check(not game.graphics_return.is_empty(),"Pressing the real menu action enters graphics flight")
	check(references()!=original_refs and game.ship!=original_refs[0] and game.nav!=original_refs[1] and game.world!=original_refs[2] and game.surface!=original_refs[3],"All four demo models are separate from the paused flight")
	check(not game.saving_enabled and not game.menu.visible,"Demo disables persistence before resuming flight controls")
	check(game.nav.elapsed_days==225.0 and game.ship.external_view,"Demo date and external camera are explicit playable state")
	check(game.stick.pointer_id==-1 and game.stick.value==Vector2.ZERO and not game.lift_up,"Entering demo releases held steering and lift")
	check(game.graphics_return.ship==original_refs[0] and game.graphics_return.surface==original_refs[3],"Paused progress retains exact original references")
	var stored:=disk();var sequence:int=game.saves.sequence
	check(not stored.is_empty(),"Entry actually saved original progress into the private test slots")
	game._begin_graphics_demo()
	check(game.graphics_return.ship==original_refs[0],"Repeated entry cannot replace the return flight with demo state")
	game.ship.credits=99999;game.ship.goods.food=8;game._set_speed(180)
	for i in range(240):game._tick(0.1,Vector2.ZERO,0)
	check(not game._save_game() and game.saves.sequence==sequence,"Periodic and manual demo saves cannot advance the original save sequence")
	game._show_routes();game._show_system();game._close_menu()
	game._show_backup();game._import_backup()
	check(not game.saving_enabled and game.backup_edit==null,"Demo rejects export/import before touching a backup editor or enabling saves")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not game.active and game.stick.pointer_id==-1,"Pause releases control and suspends the demo")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(game.active and not game.saving_enabled,"Resume keeps the demo persistence guard")
	check(disk()==stored and game.saves.sequence==sequence,"Menus, import/export, pause and flying leave original save bytes unchanged")
	check(JSON.stringify({"schema":"starfrontier-rebuild-game-v1","flight":original_refs[0].snapshot(),"navigation":original_refs[1].snapshot(),"planetary":original_refs[2].snapshot(),"surface":original_refs[3].snapshot()})==original_payload,"Original pending flight never advances while the demo runs")
	game._show_menu();var finish:=action("Вернуться к основному полёту")
	check(finish!=null and action("Начать новый полёт…")==null,"Graphics menu offers return without the normal destructive new-flight action")
	if finish==null:return
	finish.pressed.emit()
	check(game.graphics_return.is_empty() and references()==original_refs,"Return action restores all original object identities")
	check(payload()==original_payload and game.ship.credits==1789 and game.ship.goods.food==3,"Original money, cargo, navigation and surface payload restore exactly")
	check(game.saving_enabled and game.nav.remaining>0,"Original saving policy and pending hypercharge are restored")
	check(disk()==stored,"Returning does not overwrite original slots with any demo state")
	var remaining:float=game.nav.remaining
	game._tick(0.1,Vector2.ZERO,0)
	check(game.nav.remaining<remaining,"Original pending hypercharge resumes only after return")
	game.saving_enabled=false;game._new_models();game._apply_system()
func quality_and_controls()->void:
	var old_quality:int=game.settings.quality
	for quality in [0,2]:
		game.settings.quality=quality;game._apply_settings()
		check(game.player.get("_quality")==quality and game.station.quality==quality and game.space_environment.quality==quality,"Phone graphics quality reaches ship, station and asteroids: %d"%quality)
		check(game.player.geometry_stats.triangles>10,"Configured ship uses authored detailed geometry")
	check(game.space_environment.asteroid_count==275,"High quality uses the tested batched asteroid count")
	game._show_menu();game._process(0.05)
	check(not game.stick.input_allowed and not game.lever.input_allowed,"Overlay menu prevents steering and throttle capture")
	game._close_menu();game._process(0.05)
	check(game.stick.input_allowed and game.lever.input_allowed,"Closing menu restores interactive flight controls")
	game.settings.quality=old_quality;game._apply_settings()
func source_surface_roundtrip()->void:
	game.saving_enabled=false;game._new_models();game.world.site_id="site10";game._apply_system()
	await game._enter_surface()
	check(game.surface.active and not game.surface.city_data.is_empty(),"Actual source-city entry remains functional after graphics integration")
	check(game.city_view.current_visual()!=null and int(game.surface.city_data.profile.model_index)==84,"New Moscow84 retains a persistent native city visual")
	var original:=references();var before:=payload()
	game._begin_graphics_demo()
	check(not game.surface.active and game.graphics_return.surface==original[3],"Graphics flight leaves the original surface model paused rather than converting it")
	game._tick(0.5,Vector2(0.2,0),0)
	game._end_graphics_demo()
	check(references()==original and payload()==before and not game.saving_enabled,"Returning restores exact source-surface state and the previous disabled-save policy")
	check(game.surface.active and game.city_view.current_visual()!=null and game.ground_view.visible,"Native ground and source city reappear after graphics mode")
func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Use -- --rebuild-capture");quit(1);return
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	check(game.automated and not game.saving_enabled,"Test starts with actual Main user persistence disabled")
	test_directory="user://graphics-integration-%d"%OS.get_process_id();game.saves.directory=test_directory
	failed_pre_demo_save_blocks_entry();demo_preserves_pending_flight();quality_and_controls();await source_surface_roundtrip()
	game.queue_free();await process_frame
	for name in ["slot0.json","slot1.json","slot0.json.tmp","slot1.json.tmp"]:
		var path:String=test_directory+"/"+str(name)
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(test_directory)
	print("GRAPHICS INTEGRATION TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
