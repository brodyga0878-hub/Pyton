extends SceneTree
# Rendering-resource contract; actual GPU images are a separate verification.
const CityShader=preload("res://scripts/source_model.gdshader")
# Independent body captured from source shader in published0.11.6 commit8ca06bd.
const OLD_VERTEX_SHA256:="f1402896e8d638dc0c8ebb2e352b53ee398edc74a0563f862d84045d6e394cb6"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run()->void:
	var code:=CityShader.code
	var vertex:=code.get_slice("void vertex() {",1).get_slice("\n}\n",0)
	check(vertex.sha256_text()==OLD_VERTEX_SHA256,"Original source vertex/painter-depth body remains byte-for-byte unchanged")
	var uniforms:=CityShader.get_shader_uniform_list()
	var samplers:Array[String]=[];var types:Dictionary={}
	for uniform in uniforms:
		types[str(uniform.name)]=int(uniform.type)
		if int(uniform.type)==TYPE_OBJECT:samplers.append(str(uniform.name))
	samplers.sort()
	check(samplers==["city_albedo","city_normal","city_orm"],"City shader requires only the three actual atlas samplers")
	for name in ["city_gains","city_scales","city_roughness","city_metallic"]:
		check(types.get(name,-1)==TYPE_VECTOR4,"Four-role material metadata has a vector contract: "+name)
	for name in ["city_atlas_size","city_tile_size","city_gutter","city_max_lod"]:
		check(types.get(name,-1)==TYPE_FLOAT,"Atlas packing metadata has a scalar contract: "+name)
	check(types.get("detail_level",-1)==TYPE_INT,"Existing quality control remains available to source-city visuals")
	print("CITY SURFACE SHADER TESTS: %d checks, %d failures; resource/vertex contract, GPU validation separate"%[checks,failures])
	quit(1 if failures else 0)
