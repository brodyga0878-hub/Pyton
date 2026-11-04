extends RefCounted
# Presentation only; source atmosphere chemistry and original terrain are not inferred.
var height_key:=""
var sky:=Sky.new()
func _init()->void:
	var material:=ProceduralSkyMaterial.new()
	material.sky_top_color=Color("163d72");material.sky_horizon_color=Color("98becb")
	material.sky_curve=0.2;material.sky_energy_multiplier=0.7
	material.ground_bottom_color=Color("263b31");material.ground_horizon_color=Color("98becb")
	material.sun_angle_max=12;material.sun_curve=0.1
	sky.sky_material=material
func apply(environment:Environment,surface:RefCounted,quality:int)->void:
	height_key=""
	var material:ProceduralSkyMaterial=sky.sky_material
	material.sky_top_color=Color("163d72");material.sky_horizon_color=Color("98becb")
	material.ground_horizon_color=Color("98becb");material.sky_energy_multiplier=0.7
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

func update_height(environment:Environment,surface:RefCounted,height:float,quality:int)->void:
	if not surface.active or not surface.extended_flight:return
	var key:=str(surface.kind)+":"+str(quality)+":"+str(int(maxf(0,height)/100.0))
	if key==height_key:return
	height_key=key
	if surface.kind!="earth":return
	var fade:=smoothstep(1500.0,20000.0,height)
	var material:ProceduralSkyMaterial=sky.sky_material
	material.sky_top_color=Color("163d72").lerp(Color("020712"),fade)
	material.sky_horizon_color=Color("98becb").lerp(Color("071224"),fade)
	material.ground_horizon_color=material.sky_horizon_color
	material.sky_energy_multiplier=lerpf(0.7,0.05,fade)
	environment.ambient_light_energy=lerpf(0.38,0.18,fade)
	environment.fog_light_color=Color("9ebbc6").lerp(Color("203b55"),fade)
	environment.fog_density=0.00012*pow(1.0-fade,4)
	environment.fog_enabled=quality>0 and fade<0.999
