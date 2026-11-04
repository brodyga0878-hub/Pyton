extends "res://scripts/pointer_control.gd"
signal target_changed(speed:float)
var value:=0.0
var minimum:=-100.0
var maximum:=600.0
func display_value(speed:float)->void:value=clampf(speed,minimum,maximum);queue_redraw()
func _pointer_at(point:Vector2)->void:
	value=lerpf(maximum,minimum,clampf((point.y-20.0)/maxf(1,size.y-40.0),0,1));target_changed.emit(value);queue_redraw()
func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.03,0.1,0.17,0.9))
	var zero:=20.0+(size.y-40.0)*(maximum/(maximum-minimum))
	var current:=20.0+(size.y-40.0)*(maximum-value)/(maximum-minimum)
	draw_line(Vector2(size.x*0.5,20),Vector2(size.x*0.5,size.y-20),Color("3b7187"),5,true)
	draw_line(Vector2(8,zero),Vector2(size.x-8,zero),Color("f4c780"),2,true)
	draw_style_box(_thumb(),Rect2(6,current-16,size.x-12,32))
func _thumb()->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("70d9c8")
	style.corner_radius_top_left=7;style.corner_radius_top_right=7;style.corner_radius_bottom_left=7;style.corner_radius_bottom_right=7
	return style
