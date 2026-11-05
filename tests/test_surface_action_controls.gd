extends SceneTree
# Actual Main buttons/touch controls; progress IO remains disabled in capture mode.
var game:Node3D
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func landed_fixture()->void:
	game._release_inputs();game._new_models();game._close_menu();game.active=true
	game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id=""
	check(game.surface.enter(game.ship,game.world),"Actual surface entry accepts an undocked healthy ship")
	game.ship.position=Vector3(650,0,-600)
	game.ship.position.y=game.surface.height_at(650,-600)+game.surface.clearance(game.ship)+1.0
	game.ship.velocity=Vector3.ZERO
	check(game.surface.touch_down(game.ship),"Healthy ship manually lands outside the marked pad")
	game._apply_system();game._refresh_hud();game._process(0.0)
	check(game.surface.pad_distance(game.ship)>500 and game.surface.landed and game.ship.hull==100,"Fixture is off-pad and undamaged")
	check(game.dock_button.text=="Взлететь" and game.dock_button.is_visible_in_tree() and not game.dock_button.disabled,"Actual dock action is visible and labelled takeoff")
func press_hold(index:int,pointer:int)->void:
	var control:Control=game.holds[index]
	var touch:=InputEventScreenTouch.new();touch.index=pointer;touch.pressed=true;touch.position=control.get_global_rect().get_center()
	control._input(touch)
	check(control.pointer_id==pointer and control.held,"Real touch control captures its own finger")
func step_inputs(count:int)->void:
	for i in range(count):
		game._tick(0.05,game.settings.steer(game.stick.value),0,float(game.lift_up)-float(game.lift_down))
func takeoff_button_releases_previous_touch()->void:
	landed_fixture();press_hold(1,21)
	check(game.lift_down,"Descent hold is active before the explicit takeoff command")
	game.dock_button.pressed.emit()
	check(not game.surface.landed and game.surface.taking_off,"Actual takeoff button starts departure from off-pad ground")
	check(not game.lift_down and not game.lift_up and game.holds[1].pointer_id==-1,"Explicit takeoff releases previous touch capture")
	step_inputs(240)
	check(not game.surface.landed and game.surface.altitude(game.ship)>=34.5 and game.ship.hull==100,"A previously held descent finger cannot silently cancel takeoff and reland")
func positive_lift_is_usable_on_ground()->void:
	landed_fixture();press_hold(0,22)
	step_inputs(100)
	check(not game.surface.landed and game.surface.altitude(game.ship)>10 and game.ship.hull==100,"Visible lift control can depart a healthy manually landed ship")
	game._release_inputs()
func surface_action_releases_previous_touch()->void:
	landed_fixture();press_hold(1,24)
	game.surface_button.pressed.emit()
	check(not game.surface.landed and not game.lift_down and game.holds[1].pointer_id==-1,"Surface departure button also releases the previous landing finger")
	step_inputs(240)
	check(not game.surface.landed and game.surface.altitude(game.ship)>=34.5 and game.ship.hull==100,"Alternate departure action remains usable outside the pad")
func destroyed_ship_has_a_reason()->void:
	landed_fixture();game.ship.hull=0
	var position:Vector3=game.ship.position
	game.dock_button.pressed.emit()
	check(game.surface.landed and game.ship.position==position and game.ship.hull==0,"Destroyed hull is not silently repaired or moved by takeoff")
	check(game.notice.text.to_lower().contains("потерян") or game.notice.text.to_lower().contains("разруш"),"Rejected destroyed-hull takeoff explains why departure is unavailable")
func parse_touch(pointer:int,point:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=point;event.pressed=pressed
	# Go through Godot's real touch-to-mouse path rather than emitting pressed.
	Input.parse_input_event(event)
func second_finger_departure()->void:
	for use_surface_button in [false,true]:
		landed_fixture()
		var button:Button=game.surface_button if use_surface_button else game.dock_button
		var presses:Array=[0]
		var counter:Callable=func():presses[0]+=1
		button.pressed.connect(counter)
		var hold_point:Vector2=game.holds[1].get_global_rect().get_center()
		var action_point:Vector2=button.get_global_rect().get_center()
		parse_touch(0,hold_point,true);await process_frame
		check(game.lift_down and game.holds[1].held,"Primary real touch holds descent before a secondary action tap")
		parse_touch(1,action_point,true);await process_frame
		parse_touch(1,action_point,false);await process_frame
		check(presses[0]==1,"Secondary real touch activates the visible departure action exactly once")
		parse_touch(0,hold_point,false);await process_frame
		step_inputs(240)
		check(not game.surface.landed and game.surface.altitude(game.ship)>=34.5 and game.ship.hull==100,"Two-finger departure produces a real healthy off-pad takeoff")
		button.pressed.disconnect(counter)
func viewport_touch(pointer:int,point:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=point;event.pressed=pressed
	root.push_input(event,true)
func same_tick_modal_blocks_flight()->void:
	landed_fixture()
	check(game.dock_button.get_script().resource_path=="res://scripts/touch_action_button.gd" and game.surface_button.get_script().resource_path=="res://scripts/touch_action_button.gd","Console and surface actions both use the independent-touch button implementation")
	var point:Vector2=game.dock_button.get_global_rect().get_center()
	var presses:Array=[0];var counter:Callable=func():presses[0]+=1
	game.dock_button.pressed.connect(counter)
	viewport_touch(40,point,true)
	check(game.dock_button.pointer_id==40,"Real viewport touch captures a console action before menu opening")
	var before:=JSON.stringify(game._payload())
	game._show_menu() # Intentionally no frame or _process between menu and input.
	check(game.menu.visible and not game.flight_console.is_visible_in_tree() and not game.dock_button.input_allowed and not game.holds[0].input_allowed and game.dock_button.pointer_id==-1,"Opening a modal menu synchronously hides and disables flight controls and releases their captures")
	viewport_touch(40,point,false)
	check(presses[0]==0 and JSON.stringify(game._payload())==before,"An old finger release immediately after menu opening cannot replay the hidden console action")
	viewport_touch(41,point,true);viewport_touch(41,point,false)
	check(presses[0]==0 and game.surface.landed and JSON.stringify(game._payload())==before,"A new same-tick touch behind the menu cannot launch or change the paused flight")
	game._close_menu()
	check(game.flight_console.is_visible_in_tree() and game.dock_button.input_allowed and game.holds[0].input_allowed,"Closing the menu synchronously restores the appropriate surface controls")
	viewport_touch(42,point,true);game._close_menu();viewport_touch(42,point,false)
	check(game.dock_button.pointer_id==-1 and presses[0]==0,"Closing also releases pending action captures without replaying their release")
	viewport_touch(43,point,true);viewport_touch(43,point,false)
	check(presses[0]==1 and not game.surface.landed,"A fresh action after the modal transition still activates exactly once")
	step_inputs(240)
	check(game.surface.altitude(game.ship)>=34.5 and game.ship.hull==100,"The restored console action performs a healthy off-pad takeoff")
	game.dock_button.pressed.disconnect(counter)
func focus_and_report_recovery()->void:
	landed_fixture();press_hold(1,23)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.active and not game.lift_down and game.holds[1].pointer_id==-1,"Focus loss releases a captured landing finger")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);game._process(0.0)
	check(game.active and game.holds[0].input_allowed and game.dock_button.visible,"Focus return restores the normal surface controls")
	game._show_bug_report();game._process(0.0)
	check(game.menu.visible and not game.holds[0].input_allowed,"Report page correctly blocks surface controls")
	game.report_export._busy=true;game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.report_export._reset();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);game._close_menu();game._process(0.0)
	check(not game._blocked() and game.holds[0].input_allowed and not game.report_export.is_busy(),"Closing the report and returning focus does not leave a control lock")
	game.dock_button.pressed.emit();step_inputs(240)
	check(not game.surface.landed and game.surface.altitude(game.ship)>=34.5,"Takeoff still works after report/focus lifecycle")
func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Needs --rebuild-capture");quit(1);return
	root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	await process_frame
	check(game.automated and not game.saving_enabled,"Actual Main disables saved progress IO for the test")
	takeoff_button_releases_previous_touch();positive_lift_is_usable_on_ground();surface_action_releases_previous_touch();focus_and_report_recovery();destroyed_ship_has_a_reason()
	await second_finger_departure()
	same_tick_modal_blocks_flight()
	game.queue_free();await process_frame
	print("SURFACE ACTION CONTROLS TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
