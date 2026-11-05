extends Button
# Standard Button appearance/signals with independent touch ownership. Native
# mouse emulation represents only one finger, so it cannot carry phone actions.
var input_allowed:=true:
	set(value):
		input_allowed=value
		if not value:release_pointer()
var pointer_id:=-1
var _press_origin:=Vector2.ZERO
var _last_position:=Vector2.ZERO
var _toggle_before:=false
var _scroll:ScrollContainer
var _scrolling:=false
const SCROLL_DRAG_THRESHOLD:=12.0

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_process(false)
	set_process_input(true)

func _enabled()->bool:
	return input_allowed and not disabled and is_visible_in_tree()

func _contains(point:Vector2)->bool:
	if not Rect2(Vector2.ZERO,size).has_point(get_global_transform_with_canvas().affine_inverse()*point):return false
	var ancestor:=get_parent()
	while ancestor!=null:
		if ancestor is Control and ancestor.clip_contents:
			if not Rect2(Vector2.ZERO,ancestor.size).has_point(ancestor.get_global_transform_with_canvas().affine_inverse()*point):return false
		ancestor=ancestor.get_parent()
	return true

func _scroll_parent()->ScrollContainer:
	var ancestor:=get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:return ancestor
		ancestor=ancestor.get_parent()
	return null

func _capture(pointer:int,point:Vector2)->void:
	pointer_id=pointer;_press_origin=point;_last_position=point
	_toggle_before=button_pressed;_scroll=_scroll_parent();_scrolling=false
	set_pressed_no_signal(true);set_process(true);button_down.emit()

func _motion(point:Vector2)->void:
	if is_instance_valid(_scroll) and (_scrolling or point.distance_to(_press_origin)>SCROLL_DRAG_THRESHOLD):
		_scrolling=true
		var inverse:=_scroll.get_global_transform_with_canvas().affine_inverse()
		var delta:Vector2=inverse*_last_position-inverse*point
		_scroll.scroll_vertical+=roundi(delta.y);_scroll.scroll_horizontal+=roundi(delta.x)
	set_pressed_no_signal(_toggle_before if _scrolling else _contains(point))
	_last_position=point

func _finish(point:Vector2)->void:
	var activate:=_enabled() and _contains(point) and not _scrolling
	var toggled_value:=not _toggle_before
	release_pointer()
	if not activate:return
	if toggle_mode:set_pressed_no_signal(toggled_value);toggled.emit(toggled_value)
	pressed.emit()

func release_pointer()->void:
	if pointer_id==-1:return
	pointer_id=-1;_scroll=null;_scrolling=false;set_process(false)
	set_pressed_no_signal(_toggle_before if toggle_mode else false)
	button_up.emit()

func _process(_dt:float)->void:
	if not _enabled():release_pointer()

func _notification(what:int)->void:
	if what==NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():release_pointer()
	elif what in [NOTIFICATION_PAUSED,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_EXIT_TREE]:release_pointer()

func _input(event:InputEvent)->void:
	if not _enabled():release_pointer();return
	if event is InputEventScreenTouch:
		if event.canceled:
			if event.index==pointer_id:release_pointer();get_viewport().set_input_as_handled()
		elif event.pressed:
			if pointer_id==-1 and _contains(event.position):
				_capture(event.index,event.position);get_viewport().set_input_as_handled()
		elif event.index==pointer_id:
			_finish(event.position);get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==pointer_id:
		_motion(event.position);get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.device==-1 or pointer_id>=0:return
		if event.pressed:
			if pointer_id==-1 and _contains(event.position):
				_capture(-2,event.position);get_viewport().set_input_as_handled()
		elif pointer_id==-2:
			_finish(event.position);get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer_id==-2:
		if event.device==-1:return
		if not event.button_mask&MOUSE_BUTTON_MASK_LEFT:release_pointer()
		else:_motion(event.position)
		get_viewport().set_input_as_handled()
