extends SceneTree
# Independent 0.11.7 presentation contracts; actual GPU images remain separate.
const PlanetShader=preload("res://scripts/planet.gdshader")
const BASELINE_COMMIT:="fad822558bf9be6a54e8be242473a5cceb6d0cad"
const BASELINE_SOURCE_SHA256:="121c49442e340149a7ebf6f60f8ba2e2d438031dd199c2c89b9162d53424c9c7"
# Captured with git show from the published baseline before changing the shader.
const BASELINE_SECTIONS:=[
	["vertex","void vertex() {","}\nfloat hash","2d6199e0731b41cbbc1070178666cda5cbc4b4b5bff623a2a23e01b9b208a32f"],
	["procedural","float hash(vec3 p) {","float view_dither_threshold","df17a8bc6eb762a71263cc7c1cdf15e1a13b13a29dbd453b9825c14c7d534864"],
	["dither","float view_dither_threshold(vec2 screen_pixel) {","vec3 surface_finish","4eaef45f0d1cc00830442e8085d907ac0833bb0f5766104c223c3ac8e60b4108"],
	["fragment coordinates and lighting","void fragment() {"," if(body_kind==0) {","3aa9a02ad4b3607f56241b87c767841b7aaca38e9681bf7194dbfa2b3c02e150"],
	["Earth continents and climate"," if(body_kind==0) {","  // Microtexture modulates","3927860b432b0623b558793d050bcad7ec1085a1cd88756f1f21f04f76e4ea74"],
	["Earth water, clouds and lighting","  vec3 sea="," } else if(body_kind==3 || body_kind==4) {","6de635c3c0d66c64a9e3cdc1d57243720c4decea12a1380cc805ac3bef0c9ff3"],
	["Gas and star presentation"," } else if(body_kind==3 || body_kind==4) {"," } else {\n  vec3 base=","612da00911e97f8703fe071743131f0bf9b13df9ed3e113b1e6b01e340e2ce47"],
	["Mineral macro pattern"," } else {\n  vec3 base=","  if(detail_level>0) {","ad09ee9102f99487c8fdc72050a3b6bba0881fbfd05c34062066513a152df4ab"]
]
const BASELINE_COVERAGE_OUTPUT:="1980acbf887bc4f02970fad441e4eee131399499f1288d6403eb812bd731d31c"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run()->void:
	var source:=PlanetShader.code
	for row in BASELINE_SECTIONS:
		var start:int=source.find(str(row[1]));var finish:=-1
		if start>=0:start+=str(row[1]).length();finish=source.find(str(row[2]),start)
		check(start>=0 and finish>=start,"Baseline section remains identifiable: "+str(row[0]))
		if start>=0 and finish>=start:
			check(source.substr(start,finish-start).sha256_text()==str(row[3]),"Published procedural presentation remains byte-identical: "+str(row[0]))
	var coverage:=source.rfind(" if(view_coverage<1.0) {")
	check(coverage>=0 and source.substr(coverage).sha256_text()==BASELINE_COVERAGE_OUTPUT,"Complementary coverage endpoints and final output retain the original code")
	var types:Dictionary={};var samplers:Array[String]=[]
	for uniform in PlanetShader.get_shader_uniform_list():
		types[str(uniform.name)]=int(uniform.type)
		if int(uniform.type)==TYPE_OBJECT:samplers.append(str(uniform.name))
	samplers.sort()
	check(samplers==["material_albedo","material_normal","material_orm"],"Planet shader retains exactly three surface samplers and adds no geography texture")
	for name in ["material_gain","material_scale","seed_offset","view_coverage"]:check(types.get(name,-1)==TYPE_FLOAT,"Existing scalar renderer contract: "+name)
	for name in ["body_kind","detail_level"]:check(types.get(name,-1)==TYPE_INT,"Existing branch renderer contract: "+name)
	for name in ["coverage_invert","inhabited"]:check(types.get(name,-1)==TYPE_BOOL,"Existing visibility renderer contract: "+name)
	for name in ["ocean","land"]:check(types.get(name,-1)==TYPE_COLOR,"Existing source colour renderer contract: "+name)
	check(types.get("sun_direction_world",-1)==TYPE_VECTOR3,"Existing light direction renderer contract")
	print("WORLD PLANET SHADER TESTS: %d checks, %d failures; independent0.11.7 geography contracts, GPU verification separate"%[checks,failures])
	quit(1 if failures else 0)
