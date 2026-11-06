extends SceneTree
# Actual Main command wiring, pause boundaries and original principal views.
# Capture mode and memory settings keep all user progress untouched.
const Settings=preload("res://scripts/device_settings.gd")
const World=preload("res://scripts/planetary_system.gd")
class MemorySettings extends Settings:
	func load_file()->bool:quality=0;return false
var game:Node3D
var checks:=0
var failures:=0

func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func snapshot()->PackedByteArray:return var_to_bytes(game._payload())
func touch_at(point:Vector2,pointer:int,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=point;event.pressed=pressed
	Input.parse_input_event(event);await process_frame
func tap(key:String,pointer:=70)->void:
	var button:Button=game.flight_console.buttons[key]
	var point:=button.get_global_rect().get_center()
	await touch_at(point,pointer,true);await touch_at(point,pointer,false)
func menu_text()->String:
	var result:=""
	for node in game.menu_rows.get_children():
		if node is Label:result+=node.text+"\n"
	return result
func reset()->void:
	game._release_inputs();game._close_menu();game._new_models(World.PORT_LAYOUT);game._apply_system();game._refresh_hud()
	game._update_flight_controls()

func readonly_instruments()->void:
	game.ship.equipment=["cooler"]
	game._refresh_hud()
	var before:=snapshot()
	await tap("status")
	check(game.menu.visible and game.menu_title.text=="БОРТОВОЙ КОМПЬЮТЕР","Actual status touch opens the real onboard-computer screen")
	check(menu_text().contains(game.ship.profile().name) and menu_text().contains("2/58 т") and menu_text().contains("1000 кр."),"Status reads actual ship, equipped hold capacity, cargo and account")
	check(snapshot()==before,"Onboard computer never changes the game payload")
	game._close_menu();await tap("equipment")
	check(game.menu.visible and game.menu_title.text=="ГРУЗ И ОБОРУДОВАНИЕ","Actual equipment touch opens the cargo/equipment screen")
	check(menu_text().contains("Медикаменты: 2 т") and menu_text().contains("Усиленное охлаждение · 2 т"),"Equipment screen lists the actual goods and installed equipment")
	check(snapshot()==before,"Inspecting equipment never installs, removes or creates anything")
	game._close_menu()

func principal_views()->void:
	var position:Vector3=game.ship.position;var velocity:Vector3=game.ship.velocity;var attitude:Quaternion=game.ship.attitude
	var elapsed:float=game.nav.elapsed_days
	check(game.instruments.view_key(game.ship.external_view)=="front","Camera starts in the original principal forward view")
	await tap("view");game._process(0)
	check(game.instruments.view_key(game.ship.external_view)=="rear" and not game.player.visible,"Camera touch selects a real rear camera with no chase-ship overlay")
	check((-game.camera.basis.z).dot(game.ship.forward())<-0.9999,"Rear camera genuinely looks opposite the ship forward axis")
	check(game.flight_console.labels.view.text=="ВИД НАЗАД","Console labels the actual rear camera")
	await tap("view");game._process(0)
	check(game.ship.external_view and game.player.visible and game.camera.position.distance_to(position)>10,"Next camera selects a real external pose and visible ship")
	await tap("view");game._process(0)
	check(not game.ship.external_view and game.instruments.cockpit_view=="front","Camera cycle returns to the forward view")
	check((-game.camera.basis.z).dot(game.ship.forward())>0.9999,"Forward camera genuinely follows the ship attitude")
	check(game.ship.position==position and game.ship.velocity==velocity and game.ship.attitude==attitude and game.nav.elapsed_days==elapsed,"Camera cycle never rotates/moves the actual ship or advances navigation")

func control_modes()->void:
	game.ship.velocity=game.ship.forward()*35;game.ship.target_speed=200;game.ship.autopilot=true;game._refresh_hud()
	await tap("control")
	check(not game.ship.assisted and not game.ship.autopilot and game.ship.target_speed==0,"Real mode touch cancels guidance and releases axial thrust when entering inertia")
	check(game.ship.velocity.is_equal_approx(game.ship.forward()*35),"Entering inertia preserves real velocity")
	check(game.flight_console.labels.mode.text=="ИНЕРЦИОННЫЙ РЕЖИМ","Inertia is not misleadingly labelled original Engines Off")
	game.ship.velocity=game.ship.forward()*-40+Vector3.RIGHT*10
	await tap("control")
	check(game.ship.assisted and is_equal_approx(game.ship.target_speed,-40),"Returning to assistance adopts current signed forward speed instead of the old slider command")
	var saved:Dictionary=game._decode_state(game._payload())
	check(not saved.is_empty() and saved.ship.assisted and is_equal_approx(saved.ship.target_speed,-40),"Existing save decoding retains the actual new control choice")

func pause_and_pointer_lifecycle()->void:
	reset();game.ship.velocity=game.ship.forward()*20;game.ship.target_speed=20
	var stick_point:Vector2=game.stick.get_global_rect().get_center()
	var lift:Control=game.holds[0];var lift_point:Vector2=lift.get_global_rect().get_center()
	await touch_at(stick_point,81,true);await touch_at(lift_point,82,true)
	check(game.stick.pointer_id==81 and lift.pointer_id==82 and game.lift_up,"Actual stick and lift own separate held fingers before pause (stick=%d lift=%d held=%s lift_up=%s)"%[game.stick.pointer_id,lift.pointer_id,str(lift.held),str(game.lift_up)])
	await tap("pause",83)
	check(game.instruments.paused and game.flight_console.buttons.pause.text=="Продолжить","Third-finger console pause enters a resumable pause")
	check(game.stick.pointer_id==-1 and lift.pointer_id==-1 and not game.lift_up,"Pause releases every held flight pointer")
	check(not game.stick.input_allowed and not game.lever.input_allowed,"Paused movement controls reject fresh inputs")
	check(not game.flight_console.buttons.pause.disabled and not game.flight_console.buttons.view.disabled and game.flight_console.buttons.dock.disabled,"Pause keeps resume/camera available while physical dock actions are unavailable")
	var before:=snapshot()
	game._tick(20,Vector2.ONE,1,1);game._set_speed(500);game._toggle_auto();game._brake();game._dock_action();await game._surface_action();await game._enter_surface()
	check(snapshot()==before,"Pause freezes actual ship, source clock, navigation, transfer and surface despite direct commands")
	await tap("status",84)
	check(game.menu.visible and game.instruments.paused,"Real status screen remains accessible during pause")
	game._close_menu()
	check(game.flight_console.buttons.dock.disabled and not game.stick.input_allowed,"Closing a menu cannot accidentally reactivate paused flight")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game.active and game.instruments.paused,"Background/resume preserves explicit simulation pause")
	await tap("pause",85)
	check(not game.instruments.paused and game.stick.input_allowed,"Actual resume touch restores motion input")
	var elapsed:float=game.nav.elapsed_days
	game._tick(0.05,Vector2.ZERO,0)
	check(game.nav.elapsed_days>elapsed,"Actual simulation advances again only after explicit resume")
	await touch_at(stick_point,81,false);await touch_at(lift_point,82,false)

func landed_pause()->void:
	reset();game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id=""
	check(game.surface.enter(game.ship,game.world),"Real ground entry prepares the landed pause case")
	game.ship.position=Vector3(650,0,-600)
	game.ship.position.y=game.surface.height_at(650,-600)+game.surface.clearance(game.ship)+1
	game.ship.velocity=Vector3.ZERO
	check(game.surface.touch_down(game.ship),"Actual ship lands outside the marked pad before pause")
	game._apply_system();game._refresh_hud();await tap("pause",88)
	var before:=snapshot()
	check(not game._takeoff_action() and not game._begin_departure_action(),"Direct/manual and menu/automatic takeoff both reject paused movement")
	game._tick(20,Vector2.ZERO,0,1)
	check(snapshot()==before and game.surface.landed,"Paused off-pad ship stays landed without changing clocks, hull or placement")
	await tap("pause",89);await tap("dock",90)
	for step in range(240):game._tick(0.05,Vector2.ZERO,0)
	check(not game.surface.landed and game.surface.altitude(game.ship)>=34.5 and game.ship.hull==100,"Resumed console still performs a real healthy off-pad takeoff")

func pending_jump_pause()->void:
	reset()
	var destination:=-1
	for system:Dictionary in game.nav.galaxy.all():
		if int(system.id)!=game.nav.current_id and game.nav.galaxy.distance(game.nav.current_id,int(system.id))<=game.ship.jump_range():destination=int(system.id);break
	check(destination>=0,"An actual in-range target exists for pending-jump pause")
	if destination<0:return
	game._start_jump(destination);game._refresh_hud()
	check(game.nav.remaining>0,"Actual Main starts a pending jump")
	await tap("pause",90)
	var before:=snapshot()
	game._tick(10,Vector2.ZERO,0)
	check(game.instruments.paused and snapshot()==before,"Pause cannot finish a pending jump, change its fuel or advance elapsed days")
	var restored:Dictionary=game._decode_state(game._payload())
	check(not restored.is_empty() and restored.nav.remaining==game.nav.remaining,"Paused pending jump still has a valid legacy-compatible game payload")
	game._commit_state(restored);game._apply_system();game._refresh_hud()
	check(not game.instruments.paused and game.instruments.cockpit_view=="front","Loading a save resets session-only pause/camera without changing flight state")
	var remaining:float=game.nav.remaining
	game._tick(0.1,Vector2.ZERO,0)
	check(game.nav.remaining<remaining,"Restored pending jump resumes through the real simulation")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires safe capture mode");quit(1);return
	root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await process_frame
	check(game.automated and not game.saving_enabled,"Actual Main capture mode never loads/writes user progress")
	await readonly_instruments();await principal_views();await control_modes();await pause_and_pointer_lifecycle();await landed_pause();await pending_jump_pause()
	game.queue_free();await process_frame
	print("CLASSIC CONSOLE MAIN TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
