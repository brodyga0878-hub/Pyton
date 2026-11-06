extends SceneTree
# Native117 coarse/fine overlap control. All GPU geometry retains original
# sampled heights; red fine-core colours are only a diagnostic layer tag.
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Packet=preload("res://scripts/source_surface_render_packet.gd")
const State=preload("res://scripts/source_surface_render_state.gd")
const TerrainShader=preload("res://scripts/source_terrain_packet.gdshader")
const TransitionShader=preload("res://scripts/source_terrain_packet_transition.gdshader")
const Materials=preload("res://scripts/world_surface_library.gd")
class NativeSystem extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=44341016
var checks:=0
var failures:=0
var scene:Node3D
var camera:Camera3D
var base_material:ShaderMaterial
var fine_material:ShaderMaterial
var base_nodes:Array=[]
var fine_node:MeshInstance3D
var sample:Dictionary={}
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")

func triangles(packet:Dictionary,transform:Transform3D)->Array:
	var result:Array=[]
	for mesh:Dictionary in packet.meshes:
		for index in range(0,mesh.indices.size(),3):
			var a:Vector3=transform*mesh.vertices[mesh.indices[index]];var b:Vector3=transform*mesh.vertices[mesh.indices[index+1]];var c:Vector3=transform*mesh.vertices[mesh.indices[index+2]]
			var minimum:=a.min(b).min(c);var maximum:=a.max(b).max(c)
			result.append({"a":a,"b":b,"c":c,"minimum":minimum,"maximum":maximum,"role":str(mesh.role)})
	return result
func vertical(rows:Array,x:float,z:float)->Dictionary:
	var best:Dictionary={}
	for row:Dictionary in rows:
		if x<float(row.minimum.x)-0.001 or x>float(row.maximum.x)+0.001 or z<float(row.minimum.z)-0.001 or z>float(row.maximum.z)+0.001:continue
		var a:Vector3=row.a;var b:Vector3=row.b;var c:Vector3=row.c
		var bx:=float(b.x)-a.x;var bz:=float(b.z)-a.z;var cx:=float(c.x)-a.x;var cz:=float(c.z)-a.z;var determinant:=bx*cz-bz*cx
		if absf(determinant)<1e-12:continue
		var dx:=x-float(a.x);var dz:=z-float(a.z);var u:=(dx*cz-dz*cx)/determinant;var v:=(bx*dz-bz*dx)/determinant
		if u<(-1e-7) or v<(-1e-7) or u+v>1.0000001:continue
		var height:=float(a.y)+u*(float(b.y)-a.y)+v*(float(c.y)-a.y)
		if best.is_empty() or height>float(best.height):best={"height":height,"role":str(row.role)}
	return best

func prepare_native()->Dictionary:
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"));var record:=PackedByteArray()
	for row:Dictionary in source.cases:
		if int(row.parent_model)==117:record=str(row.parent_record_hex).hex_decode();break
	var system:=NativeSystem.new();system.by_id.body={"runtime_record_hex":record.hex_encode(),"radius_km":1.0}
	var base_globe:=Terrain.new();base_globe.configure(system,"body","");base_globe.latitude=-PI/8;base_globe.longitude=PI/2
	var base:=Packet.prepare(base_globe,{"extended_flight":true,"source_key":"native117-initial-base"})
	check(Packet.valid(base) and base.meshes.size()>1,"Actual native117 nonflat BASE contains core and coarse far rings")
	var base_state:=State.new();check(base_state.configure(base),"Actual base packet validates physical source frame")
	var fine_globe:RefCounted=Terrain.from_worker_state(base_globe.capture_worker_state());var regional_height:=base_globe.raw_height(2500,1250);var ll:=base_globe.coordinates_at_height(2500,1250,regional_height)
	fine_globe.latitude=ll[0];fine_globe.longitude=ll[1]
	var fine:=Packet.prepare(fine_globe,{"include_rings":false,"source_key":"native117-new-core-after-2km"})
	var fine_state:=State.new();check(Packet.valid(fine) and fine_state.configure(fine),"Actual fine core is rebuilt after more than2km geographic rebase")
	var base_to_scene:=base_state.transform_to(fine_globe);var fine_to_scene:=fine_state.transform_to(fine_globe);var core_from_base:=fine_to_scene.affine_inverse()*base_to_scene
	check(base_to_scene.is_finite() and base_to_scene.origin.length()>2000 and not base_to_scene.basis.is_equal_approx(Basis.IDENTITY),"Clip control has real source rotation and nonzero frame translation")
	var rows:=triangles(base,base_to_scene);var maximum:=-INF;var chosen:=Vector2.ZERO;var height:=0.0;var role:=""
	for z in range(15):
		for x in range(15):
			var point:=Vector2(-1750+x*250,-1750+z*250);var old:=vertical(rows,point.x,point.y);var current:=fine_state.height_at(fine_globe,point.x,point.y)
			if old.is_empty() or current.is_empty():continue
			var overdraw:=float(old.height)-float(current.height)
			if overdraw>maximum:maximum=overdraw;chosen=point;height=float(current.height);role=str(old.role)
	print("NATIVE PACKET OVERDRAW point=",chosen," base_above_fine_m=",maximum," role=",role," base_rings=",base.meshes.size()-1)
	check(is_finite(maximum) and maximum>0,"Actual coarse native117 geometry contains an overlapping raised surface control")
	return {"base":base,"fine":fine,"base_to_scene":base_to_scene,"fine_to_scene":fine_to_scene,"core_from_base":core_from_base,"point":chosen,"height":height,"overdraw_m":maximum,"rows":rows}

func make_mesh(data:Dictionary,red:bool)->ArrayMesh:
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_TEX_UV]=data.uv;arrays[Mesh.ARRAY_TEX_UV2]=data.uv2;arrays[Mesh.ARRAY_INDEX]=data.indices
	var colors:PackedColorArray=data.colors.duplicate()
	if red:
		for index in range(colors.size()):colors[index]=Color(1.0,0.01,0.005)
	arrays[Mesh.ARRAY_COLOR]=colors;var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func configure_material(material:ShaderMaterial,shader:Shader,clip:bool)->void:
	material.shader=shader;material.set_shader_parameter("detail_level",0);material.set_shader_parameter("spherical_coordinates",true);material.set_shader_parameter("surface_kind",1);material.set_shader_parameter("view_coverage",1.0);material.set_shader_parameter("source_clip_core",clip)
	material.set_shader_parameter("source_core_from_packet_basis",sample.core_from_base.basis);material.set_shader_parameter("source_core_from_packet_origin",sample.core_from_base.origin);material.set_shader_parameter("source_core_center",sample.fine.core_offset);material.set_shader_parameter("source_core_half_width",float(sample.fine.core_width)*0.5)
func point_camera(point:Vector2,span:=30.0)->void:
	var ground:=vertical(sample.rows,point.x,point.y);var height:=float(ground.get("height",sample.height))
	camera.position=Vector3(point.x,maxf(height,float(sample.height))+150.0,point.y);camera.look_at(Vector3(point.x,camera.position.y-100,point.y),Vector3.FORWARD);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=span
func picture()->Image:
	for frame in range(3):await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func centre(image:Image)->Color:return image.get_pixel(image.get_width()/2,image.get_height()/2)
func red(pixel:Color)->bool:return pixel.r>pixel.g+0.15 and pixel.r>pixel.b+0.15

func gpu_controls()->void:
	root.size=Vector2i(512,512);scene=Node3D.new();root.add_child(scene)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=1.0;environment.environment=env;scene.add_child(environment)
	base_material=ShaderMaterial.new();fine_material=ShaderMaterial.new();configure_material(base_material,TerrainShader,false);configure_material(fine_material,TerrainShader,false)
	base_material.set_shader_parameter("material_origin",sample.base.material_origin);fine_material.set_shader_parameter("material_origin",sample.fine.material_origin)
	for data:Dictionary in sample.base.meshes:
		var node:=MeshInstance3D.new();node.mesh=make_mesh(data,false);node.transform=sample.base_to_scene;node.material_override=base_material;scene.add_child(node);base_nodes.append(node)
	fine_node=MeshInstance3D.new();fine_node.mesh=make_mesh(sample.fine.meshes[0],true);fine_node.transform=sample.fine_to_scene;fine_node.material_override=fine_material;scene.add_child(fine_node)
	camera=Camera3D.new();camera.near=0.05;camera.far=5000;scene.add_child(camera);camera.make_current();point_camera(sample.point)
	var before:=centre(await picture());base_material.set_shader_parameter("source_clip_core",true);var after:=centre(await picture())
	print("PACKET CLIP GLES before=",before," after=",after," raised_m=",sample.overdraw_m)
	check(not red(before),"Actual old BASE occludes diagnostic fine-core colour before source clip")
	check(red(after),"Actual packet shader clip exposes new native fine-core geometry afterrebase")
	check(fine_material.get_shader_parameter("source_clip_core")==false,"Fine material has no recursive self-clip")
	for point in [Vector2(2500,0),Vector2(-2500,0),Vector2(0,2500),Vector2(0,-2500)]:
		point_camera(point,20);base_material.set_shader_parameter("source_clip_core",false);var outside_before:=centre(await picture());base_material.set_shader_parameter("source_clip_core",true);var outside_after:=centre(await picture())
		check(outside_before.r+outside_before.g+outside_before.b>0.05,"Actual far geometry remains visible outside fine rectangle")
		check(absf(outside_before.r-outside_after.r)+absf(outside_before.g-outside_after.g)+absf(outside_before.b-outside_after.b)<0.015,"Clip leaves all outside-edge far pixels unchanged")
	for point in [Vector2(1999,0),Vector2(-1999,0),Vector2(0,1999),Vector2(0,-1999)]:
		point_camera(point,4);base_material.set_shader_parameter("source_clip_core",true)
		check(red(centre(await picture())),"Published fine core remains visible one metre inside each rectangle edge")
	for point in [Vector2(2001,0),Vector2(-2001,0),Vector2(0,2001),Vector2(0,-2001)]:
		point_camera(point,4);base_material.set_shader_parameter("source_clip_core",false);var edge_before:=centre(await picture());base_material.set_shader_parameter("source_clip_core",true);var edge_after:=centre(await picture())
		check(edge_after.r+edge_after.g+edge_after.b>0.05 and absf(edge_before.r-edge_after.r)+absf(edge_before.g-edge_after.g)+absf(edge_before.b-edge_after.b)<0.015,"Retained far surface has no clip hole one metre outside each rectangle edge")
	point_camera(sample.point,30)
	configure_material(base_material,TransitionShader,true);configure_material(fine_material,TransitionShader,false)
	var previous:=-1.0
	for coverage in [0.0,0.35,0.7,1.0]:
		base_material.set_shader_parameter("view_coverage",coverage);fine_material.set_shader_parameter("view_coverage",coverage)
		var image:=await picture();var pixel:=centre(image);var total:=pixel.r+pixel.g+pixel.b
		check(is_finite(total) and total+0.02>=previous,"Native packet transition remains finite and increases smoothly with coverage")
		previous=total
		if coverage==1.0:check(red(pixel),"Transition source clip also exposes full fine-core endpoint")
	# Texture derivatives execute before the rectangular discard in both copies.
	for shader in [TerrainShader,TransitionShader]:
		configure_material(base_material,shader,true);configure_material(fine_material,shader,false)
		check(Materials.bind_shader(base_material,"rock",0.0625) and Materials.bind_shader(fine_material,"rock",0.0625),"Real packet material maps bind in both shader variants")
		base_material.set_shader_parameter("detail_level",2);fine_material.set_shader_parameter("detail_level",2)
		var image:=await picture();var pixel:=centre(image)
		check(is_finite(pixel.r+pixel.g+pixel.b) and pixel.r+pixel.g+pixel.b>0.05,"Mapped packet gradients stay finite at actual native overlap clip")
		point_camera(Vector2(2000,0),8);image=await picture()
		var inside:=image.get_pixel(128,256);var outside:=image.get_pixel(384,256)
		check(red(inside) and not red(outside) and outside.r+outside.g+outside.b>0.05,"Both real shader variants retain fine/far textured coverage across actual clip boundary")
		point_camera(sample.point,30)
	scene.queue_free();await process_frame

func run()->void:
	sample=prepare_native()
	if DisplayServer.get_name()=="headless":print("Source packet GPU controls require real GLES display; CPU preparation only")
	else:await gpu_controls()
	print("SOURCE SURFACE PACKET CLIP TESTS: ",checks," checks, ",failures," failures; real117nativeheights, coarse/fineframes, outsideedges, transitions")
	quit(1 if failures else 0)
