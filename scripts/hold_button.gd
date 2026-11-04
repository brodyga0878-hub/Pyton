extends "res://scripts/pointer_control.gd"
signal state_changed(pressed:bool)
var text:=""
var held:=false
func _ready()->void:
	super._ready()
	var label:=Label.new();label.text=text;label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",22);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(label)
func _pointer_at(_point:Vector2)->void:
	if not held:held=true;state_changed.emit(true);queue_redraw()
func _pointer_released()->void:
	if held:held=false;state_changed.emit(false)
func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("27626f") if held else Color(0.04,0.14,0.21,0.9))
	draw_rect(Rect2(Vector2.ZERO,size),Color("69d8cf") if held else Color("3c7185"),false,2)
