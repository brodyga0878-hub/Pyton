extends Node3D
# Keep the static96 city mesh while publishing only the real237 hatch subtree.
const Visual=preload("res://scripts/source_model_visual.gd")
const Roles=preload("res://scripts/city_material_roles.gd")
var static_visual:Node3D
var dynamic_visual:Node3D
var quality:=2
var static_key:=""
var door_u16:=-1
var static_build_count:=0
var dynamic_build_count:=0
var triangle_count:=0

func set_quality(value:int)->void:
	quality=clampi(value,0,2)
	if static_visual!=null:static_visual.set_quality(quality)
	if dynamic_visual!=null:dynamic_visual.set_quality(quality)

func configure_data(data:Dictionary)->bool:
	if not data.get("ok",false) or not data.get("static_compiled") is Dictionary or not data.get("dynamic_compiled") is Dictionary or not data.get("conversion_basis") is Basis or not data.get("profile") is Dictionary:return false
	var key:=str(data.get("static_key",""))
	if key.is_empty():return false
	var context:=Roles.context_for(data.profile,data.conversion_basis,data.compiled)
	if static_visual==null or static_key!=key:
		var candidate:=Visual.new();candidate.set_quality(quality)
		if not candidate.configure(data.static_compiled,data.conversion_basis,context):candidate.free();return false
		if static_visual!=null:remove_child(static_visual);static_visual.queue_free()
		static_visual=candidate;add_child(candidate);static_key=key;static_build_count+=1;door_u16=-1
	if door_u16!=int(data.door_u16):
		var candidate:=Visual.new();candidate.set_quality(quality)
		if not candidate.configure(data.dynamic_compiled,data.conversion_basis,context):candidate.free();return false
		if dynamic_visual!=null:remove_child(dynamic_visual);dynamic_visual.queue_free()
		dynamic_visual=candidate;add_child(candidate);door_u16=int(data.door_u16);dynamic_build_count+=1
	triangle_count=int(static_visual.triangle_count)+int(dynamic_visual.triangle_count)
	return true
