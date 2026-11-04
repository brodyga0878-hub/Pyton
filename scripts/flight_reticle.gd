extends Control
# A lightweight drawn flight display; no target acquisition or combat is implied.
var hull:=100.0
var speed:=0.0
func _ready()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func update_state(next_hull:float,next_speed:float)->void:
	if is_equal_approx(hull,next_hull) and is_equal_approx(speed,next_speed):return
	hull=next_hull;speed=next_speed;queue_redraw()
func _draw()->void:
	var c:=size*0.5
	var cyan:=Color(0.5,0.9,0.94,0.48)
	draw_arc(c,40,0,TAU,64,Color(0.7,0.9,0.96,0.16),1,true)
	for angle in [0.0,PI*0.5,PI,PI*1.5]:
		var d:=Vector2(cos(angle),sin(angle));draw_line(c+d*29,c+d*35,cyan,1.5,true)
	draw_arc(c,104,PI*0.78,PI*1.22,32,Color(0.2,0.38,0.45,0.4),4,true)
	draw_arc(c,104,PI*0.78,PI*0.78+PI*0.44*clampf(hull/100,0,1),32,cyan,2,true)
	draw_arc(c,104,-PI*0.22,PI*0.22,32,Color(0.2,0.38,0.45,0.4),4,true)
	draw_arc(c,104,-PI*0.22,-PI*0.22+PI*0.44*clampf(absf(speed)/600,0,1),32,Color(0.93,0.68,0.3,0.6),2,true)
