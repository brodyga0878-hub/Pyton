extends "res://scripts/pointer_control.gd"
var value:=Vector2.ZERO
var deadzone:=0.12
var knob:=Vector2.ZERO
func _pointer_at(point:Vector2)->void:
	knob=((point-size*0.5)/(minf(size.x,size.y)*0.36)).limit_length()
	var magnitude:=knob.length()
	value=Vector2.ZERO if magnitude<=deadzone else knob.normalized()*pow((magnitude-deadzone)/(1.0-deadzone),1.5)
	queue_redraw()
func _pointer_released()->void:value=Vector2.ZERO;knob=Vector2.ZERO
func _draw()->void:
	var center:=size*0.5;var radius:=minf(size.x,size.y)*0.47
	draw_circle(center,radius,Color(0.03,0.12,0.19,0.82))
	draw_arc(center,radius,0,TAU,72,Color(0.3,0.71,0.82,0.65),2,true)
	draw_line(center-Vector2(radius*0.7,0),center+Vector2(radius*0.7,0),Color(0.2,0.45,0.55,0.4),1)
	draw_line(center-Vector2(0,radius*0.7),center+Vector2(0,radius*0.7),Color(0.2,0.45,0.55,0.4),1)
	draw_circle(center+knob*radius*0.7,radius*0.27,Color("65dbc9") if pointer_id!=-1 else Color("497d91"))
