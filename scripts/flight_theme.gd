extends RefCounted
# New phone interface styling; input and game state are unchanged.
static func _panel(fill:Color,border:Color,radius:int=9)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border
	style.set_border_width_all(1);style.set_corner_radius_all(radius)
	style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=8;style.content_margin_bottom=8
	return style
static func build()->Theme:
	var theme:=Theme.new();theme.default_font_size=21
	theme.set_color("font_color","Label",Color("e3edf3"))
	theme.set_color("font_outline_color","Label",Color(0.005,0.015,0.025,0.8));theme.set_constant("outline_size","Label",3)
	theme.set_stylebox("normal","Button",_panel(Color(0.025,0.07,0.11,0.86),Color(0.27,0.48,0.57,0.65)))
	theme.set_stylebox("hover","Button",_panel(Color(0.07,0.17,0.22,0.96),Color("68ccda")))
	theme.set_stylebox("pressed","Button",_panel(Color(0.10,0.26,0.30,0.98),Color("99eee4")))
	theme.set_stylebox("focus","Button",_panel(Color(0,0,0,0),Color("71d5d2")))
	theme.set_stylebox("disabled","Button",_panel(Color(0.03,0.05,0.07,0.75),Color(0.2,0.26,0.28,0.4)))
	theme.set_color("font_color","Button",Color("d9ebf3"));theme.set_color("font_hover_color","Button",Color.WHITE)
	theme.set_color("font_pressed_color","Button",Color("c8ffef"));theme.set_color("font_disabled_color","Button",Color("7c919d"))
	theme.set_stylebox("panel","PanelContainer",_panel(Color(0.018,0.04,0.065,0.88),Color(0.22,0.36,0.45,0.5),11))
	theme.set_stylebox("normal","TextEdit",_panel(Color("07121d"),Color("365664")))
	theme.set_color("font_color","TextEdit",Color("c6e7ed"))
	return theme
