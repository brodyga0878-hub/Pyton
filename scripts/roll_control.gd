extends "res://scripts/pointer_control.gd"
# Independent analog roll control. Moving toward the outside edge increases
# the rate; the inner edge permits fine manual tracking of a rotating dock.
signal axis_changed(value:float)
var direction:=-1.0
var strength:=0.0
var held:=false

func _pointer_at(point:Vector2)->void:
	held=true
	strength=clampf(point.x/maxf(1,size.x),0,1)
	if direction<0:strength=1.0-strength
	axis_changed.emit(strength);queue_redraw()

func _pointer_released()->void:
	held=false;strength=0.0;axis_changed.emit(0.0);queue_redraw()

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("3b5b5d") if held else Color("737e80"))
	draw_rect(Rect2(Vector2.ZERO,size),Color("d2d8d0"),false,1.5)
	var font:=ThemeDB.fallback_font
	var title:="КРЕН ↶" if direction<0 else "КРЕН ↷"
	draw_string(font,Vector2(6,26),title,HORIZONTAL_ALIGNMENT_CENTER,size.x-12,17,Color("e3ebde"))
	draw_string(font,Vector2(6,49),"%.0f%%"%(strength*100),HORIZONTAL_ALIGNMENT_CENTER,size.x-12,14,Color("d4efae"))
	if held:
		var x:=size.x*(1-strength if direction<0 else strength)
		draw_line(Vector2(x,2),Vector2(x,size.y-2),Color("93efab"),2,true)
