extends RefCounted
# Presentation only; source atmosphere chemistry and original terrain are not inferred.
var sky:=Sky.new()
func _init()->void:
	var material:=ProceduralSkyMaterial.new()
	material.sky_top_color=Color("163d72");material.sky_horizon_color=Color("98becb")
	material.sky_curve=0.2;material.sky_energy_multiplier=0.7
	material.ground_bottom_color=Color("263b31");material.ground_horizon_color=Color("98becb")
	material.sun_angle_max=12;material.sun_curve=0.1
	sky.sky_material=material
func apply(environment:Environment,surface:RefCounted,quality:int)->void:
	var earth_air:bool=surface.active and surface.kind=="earth"
	environment.background_mode=Environment.BG_SKY if earth_air else Environment.BG_COLOR
	environment.sky=sky if earth_air else null
	environment.background_color=Color("020712")
	environment.ambient_light_color=Color("91b5cf") if earth_air else Color("6b94b0")
	environment.ambient_light_energy=0.38 if earth_air else 0.18
	environment.fog_enabled=earth_air and quality>0
	environment.fog_light_color=Color("9ebbc6")
	environment.fog_density=0.00012
	environment.fog_sky_affect=0.15
