extends SceneTree
# Texture/resource contracts only. Geometry and flight regressions live in the
# existing ship and space-environment suites; GPU screenshots validate shading.
const Ship=preload("res://scripts/ship_visual.gd")
const Station=preload("res://scripts/station_visual.gd")
const Library=preload("res://scripts/material_library.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func shader_maps(material:ShaderMaterial,kind:String)->void:
	for channel in ["albedo","normal","orm"]:
		check(material.get_shader_parameter("material_"+channel)==Library.texture(kind,channel),"Shader binds the shared %s %s map"%[kind,channel])
	check(float(material.get_shader_parameter("material_scale"))>0.0,"Physical texture scale remains positive")
	check(float(material.get_shader_parameter("material_gain"))>1.0,"sRGB albedo normalization is supplied")
func standard_maps(material:StandardMaterial3D,kind:String)->void:
	check(material.albedo_texture==Library.texture(kind,"albedo"),"Standard surface binds %s albedo"%kind)
	check(material.normal_texture==Library.texture(kind,"normal"),"Standard surface binds %s normal"%kind)
	check(material.ao_texture==Library.texture(kind,"orm"),"Standard surface binds shared occlusion map")
	check(material.roughness_texture==Library.texture(kind,"orm"),"Standard surface binds shared roughness map")
	check(material.metallic_texture==Library.texture(kind,"orm"),"Standard surface binds shared metalness map")
	check(material.uv1_triplanar,"Existing geometry receives textures without adding tangent or UV streams")
func station_finish_maps(material:StandardMaterial3D)->void:
	check(material.albedo_texture==Station.finish_texture("albedo"),"Station shell/dark use the dedicated authored albedo")
	check(material.normal_texture==Station.finish_texture("normal"),"Station shell/dark use the dedicated authored normal")
	for map in [material.ao_texture,material.roughness_texture,material.metallic_texture]:
		check(map==Station.finish_texture("orm"),"Station finish uses the shared physical ORM")
	check(material.uv1_triplanar and not material.uv1_world_triplanar,"Station textures remain attached to existing object coordinates")
func run()->void:
	var ship:=Ship.new();root.add_child(ship);ship.configure({"id":"cobra","visual_span_m":42.0})
	check(int(ship.geometry_stats.triangles)==7534,"Material upgrade preserves the existing high-detail 7534-triangle hull")
	for group in ["frame","armour","edge","navy","gold","copper","rubber"]:
		var kind:="rubber" if group=="rubber" else ("painted_alloy" if group in ["armour","navy"] else "brushed_metal")
		shader_maps(ship._material(group),kind)
		check(int(ship._material(group).get_shader_parameter("detail_level"))==2,"High-detail hull has normal detail enabled")
	check(ship._material("armour").get_shader_parameter("paint")==Color("b6c4c7"),"Hull paint palette remains the established colour")
	var glass:StandardMaterial3D=ship._material("glass");standard_maps(glass,"glass")
	check(glass.clearcoat_enabled and glass.normal_scale<=0.1,"Cockpit glazing retains clearcoat and restrained normal relief")
	var high_material:ShaderMaterial=ship._material("armour")
	ship.set_quality(0)
	var low_material:ShaderMaterial=ship._material("armour")
	check(low_material!=high_material,"Quality profiles cannot mutate another ship's cached shader detail")
	check(int(low_material.get_shader_parameter("detail_level"))==0,"Economy profile skips normal samples")
	check(int(high_material.get_shader_parameter("detail_level"))==2,"High-detail cached material survives economy configuration")
	check(not ship._material("glass").normal_enabled,"Economy glazing skips normal detail")
	var station:=Station.new();root.add_child(station);station.configure(2)
	station_finish_maps(station._materials.shell)
	station_finish_maps(station._materials.dark)
	standard_maps(station._materials.gold,"brushed_metal")
	shader_maps(station._materials.solar,"brushed_metal")
	check(station._materials.light.albedo_texture==null and station._materials.amber.albedo_texture==null,"Navigation lamps retain their clean emissive colours")
	check(int(station._materials.solar.get_shader_parameter("detail_level"))==2,"Solar material follows station quality")
	station.configure(0)
	check(not station._materials.shell.normal_enabled,"Economy station skips normal detail")
	check(int(station._materials.solar.get_shader_parameter("detail_level"))==0,"Economy solar shader skips normal detail")
	ship.queue_free();station.queue_free();await process_frame
	print("SPACE MATERIAL BINDINGS TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
