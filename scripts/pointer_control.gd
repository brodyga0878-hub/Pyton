extends Control
# New reconstruction: independent fingers for steering, throttle and lift.
var input_allowed:=true:
	set(value):
		input_allowed=value
		if not value:release_pointer()
var pointer_id:=-1

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func _notification(what:int)->void:
	if what==NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():release_pointer()
	elif what==NOTIFICATION_PAUSED or what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_EXIT_TREE:
		release_pointer()

func _input(event:InputEvent)->void:
	if not input_allowed or not is_visible_in_tree():return
	if event is InputEventScreenTouch:
		if event.canceled:
			if event.index==pointer_id:release_pointer();get_viewport().set_input_as_handled()
			return
		var local:Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
		if event.pressed and pointer_id==-1 and Rect2(Vector2.ZERO,size).has_point(local):
			pointer_id=event.index;_pointer_at(local);get_viewport().set_input_as_handled()
		elif not event.pressed and event.index==pointer_id:
			release_pointer();get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==pointer_id:
		_pointer_at(get_global_transform_with_canvas().affine_inverse()*event.position);get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if pointer_id>=0:return
		var local:Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
		if event.pressed and Rect2(Vector2.ZERO,size).has_point(local):
			pointer_id=-2;_pointer_at(local);get_viewport().set_input_as_handled()
		elif not event.pressed and pointer_id==-2:
			release_pointer();get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer_id==-2:
		if not event.button_mask&MOUSE_BUTTON_MASK_LEFT:release_pointer()
		else:_pointer_at(get_global_transform_with_canvas().affine_inverse()*event.position)
		get_viewport().set_input_as_handled()

func release_pointer()->void:
	pointer_id=-1;_pointer_released();queue_redraw()
func _pointer_at(_point:Vector2)->void:pass
func _pointer_released()->void:pass
