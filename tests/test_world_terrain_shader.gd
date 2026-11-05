extends SceneTree
# Immutable0.11.7 shader sections and the real parser/resource contract.
# Rendering quality, physical terrain and phone performance are separate checks.
const GroundShader=preload("res://scripts/terrain.gdshader")
const TransitionShader=preload("res://scripts/terrain_transition.gdshader")
const BASELINE_COMMIT:="fad822558bf9be6a54e8be242473a5cceb6d0cad"
const OLD_VERTEX_SHA256:="e6ff926339d794e6a9e47d2552bca9f6ed77dc0b38f17e95c804b494799a2f4a"
const OLD_PROCEDURAL_SHA256:="7e81dabe3ec48b18d23973c84fe122a521a0acaff3fe426e87b75de002ba2843"
const OLD_MACRO_FRAGMENT_SHA256:="1ab48d9babf082a12a6e89e17f69ac9e8e3857d52a8b6a3e7c218ea3e18d0000"
const OLD_BAYER_FUNCTION_SHA256:="16861f5f110575f78a941aa7806adb98f95d2e6a7e70e2769be7a56ff2d94526"
const OLD_GROUND_COVERAGE_SHA256:="fb467c00dae1d7c2c51edd2b35e9e95a00f981a4a045ee59f79647646cf77197"
const TEXTURE_STAGE_START:=" if(detail_level>0) {\n  vec3 weights="
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func texture_stage(code:String)->String:
	return code.get_slice(TEXTURE_STAGE_START,1).get_slice(" // Defaults preserve full opaque coverage;",0).get_slice(" // No vertex displacement:",0)
func one_shader(shader:Shader,label:String)->void:
	var code:=shader.code
	check(code.get_slice("void vertex() {",1).get_slice("\n}\n",0).sha256_text()==OLD_VERTEX_SHA256,label+": original body-fixed coordinates and vertex stage are byte-identical to0.11.7")
	check(code.get_slice("float hash(vec2 p)",1).get_slice("void vertex()",0).sha256_text()==OLD_PROCEDURAL_SHA256,label+": procedural noise functions remain byte-identical")
	check(code.get_slice("void fragment() {",1).get_slice(TEXTURE_STAGE_START,0).sha256_text()==OLD_MACRO_FRAGMENT_SHA256,label+": existing palette, slope, broad/medium/fine procedural inputs and quality0 remain byte-identical")
	check(code.get_slice("float view_dither_threshold(vec2 screen_pixel)",1).get_slice("void fragment()",0).sha256_text()==OLD_BAYER_FUNCTION_SHA256,label+": original Bayer thresholds remain byte-identical")
	var types:Dictionary={};var samplers:Array[String]=[]
	for uniform in shader.get_shader_uniform_list():
		types[str(uniform.name)]=int(uniform.type)
		if int(uniform.type)==TYPE_OBJECT:samplers.append(str(uniform.name))
	samplers.sort()
	check(samplers==["material_albedo","material_normal","material_orm"],label+": only three real material map samplers")
	for name in ["view_coverage","material_scale","material_gain"]:check(types.get(name,-1)==TYPE_FLOAT,label+": existing float uniform "+name)
	for name in ["detail_level","surface_kind"]:check(types.get(name,-1)==TYPE_INT,label+": existing integer uniform "+name)
	for name in ["coverage_invert","spherical_coordinates"]:check(types.get(name,-1)==TYPE_BOOL,label+": existing boolean uniform "+name)
	check(types.get("material_origin",-1)==TYPE_VECTOR3,label+": body-fixed tile origin retains its vector contract")
	check(types.size()==11,label+": no extra runtime uniforms are required")
	var displacement:=RegEx.new();displacement.compile("\\bVERTEX\\s*(?:[.+*/-]?=|\\+\\+|--)")
	check(displacement.search(code)==null,label+": material code cannot displace terrain vertices")
	check(not code.contains("texture("),label+": conditional material reads use explicit gradients instead of branch-dependent implicit derivatives")
	var gradients:=code.find("vec3 texture_dx=dFdx(tp),texture_dy=dFdy(tp);")
	var visibility:=code.find("if(detail_visibility>0.0)")
	check(gradients>=0 and gradients<visibility,label+": map gradients are evaluated before the pixel-dependent visibility branch")
func run()->void:
	one_shader(GroundShader,"Ground")
	one_shader(TransitionShader,"Transition")
	var ground:=GroundShader.code;var transition:=TransitionShader.code
	check(ground.get_slice(" // Defaults preserve full opaque coverage;",1).get_slice(" // No vertex displacement:",0).sha256_text()==OLD_GROUND_COVERAGE_SHA256,"Ground keeps the exact original complementary discard and endpoint rules")
	check(ground.contains("render_mode diffuse_burley;"),"Ordinary terrain keeps opaque depth behavior")
	check(transition.contains("render_mode diffuse_burley, blend_mix, depth_draw_never;"),"Transition retains original transparent depth behavior")
	check(transition.contains(" ALPHA=clamp(view_coverage,0.0,1.0);") and not transition.contains(" discard;"),"Transition retains its original0..1 alpha contract without a new discard")
	check(texture_stage(ground)==texture_stage(transition),"Both terrain presentations use exactly the same new texture stage")
	check(ground.get_slice("vec3 world_decode_srgb",1).get_slice("// Stable Bayer",0)==transition.get_slice("vec3 world_decode_srgb",1).get_slice("// Stable Bayer",0),"Both terrain presentations share the same colour transfer and sampling functions")
	print("WORLD TERRAIN SHADER TESTS: %d checks, %d failures; immutable0.11.7 blocks and parser contract, GPU checks separate"%[checks,failures])
	quit(1 if failures else 0)
