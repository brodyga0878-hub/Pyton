extends Node3D
# New authored training/orbital station visual. The unchanged dock target is local
# origin. All physical-looking structures stay behind z=-110 or outside r=120.
const SolarShader=preload("res://scripts/station_solar.gdshader")
const MaterialLibrary=preload("res://scripts/material_library.gd")
var quality:=-1
var geometry_batches:=0
var _surfaces:Dictionary={}
var _materials:Dictionary={}

func _material(colour:Color,metal:=0.7,rough:=0.34,emission:=0.0,kind:="painted_alloy")->StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	if emission<=0:
		MaterialLibrary.apply_standard(m,kind,0.25 if kind=="painted_alloy" else 0.65)
		m.normal_enabled=quality>0;m.normal_scale=0.18 if quality>1 else 0.1
		# Compensate sRGB map mean while retaining the station's existing palette.
		var gain:float=MaterialLibrary.albedo_gain(kind)
		var alpha:float=colour.a;colour=(colour.srgb_to_linear()*gain).linear_to_srgb();colour.a=alpha
		rough=clampf(rough/MaterialLibrary.roughness_mean(kind),0.0,1.0)
	m.albedo_color=colour;m.metallic=metal;m.roughness=rough
	if emission>0:m.emission_enabled=true;m.emission=colour;m.emission_energy_multiplier=emission
	return m
func _add_mesh(mesh:Mesh,key:String,at:Vector3,basis:=Basis.IDENTITY)->void:
	if not _surfaces.has(key):
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);_surfaces[key]=surface
	_surfaces[key].append_from(mesh,0,Transform3D(basis,at))
func _box(key:String,at:Vector3,dimensions:Vector3,basis:=Basis.IDENTITY)->void:
	var mesh:=BoxMesh.new();mesh.size=dimensions;_add_mesh(mesh,key,at,basis)
func _cylinder(key:String,at:Vector3,radius:float,length:float,basis:=Basis.IDENTITY)->void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=length;mesh.radial_segments=24 if quality>0 else 12;_add_mesh(mesh,key,at,basis)
func _beam(key:String,start:Vector3,end:Vector3,width:float)->void:
	var direction:=(end-start).normalized();var across:=direction.cross(Vector3.UP)
	if across.length_squared()<0.01:across=direction.cross(Vector3.RIGHT)
	across=across.normalized();var basis:=Basis(across,direction,across.cross(direction).normalized())
	_box(key,(start+end)*0.5,Vector3(width,start.distance_to(end),width),basis)
func _ring(key:String,at:Vector3,inner:float,outer:float)->void:
	var torus:=TorusMesh.new();torus.inner_radius=inner;torus.outer_radius=outer;torus.rings=96 if quality>0 else 48;torus.ring_segments=12 if quality>0 else 6
	_add_mesh(torus,key,at,Basis(Vector3.RIGHT,PI/2))
func configure(value:=2)->void:
	value=clampi(value,0,2)
	if value==quality:return
	quality=value
	for child in get_children():remove_child(child);child.queue_free()
	_surfaces.clear();_materials.clear()
	_materials["shell"]=_material(Color("c5cdd2"),0.65,0.37)
	_materials["dark"]=_material(Color("202e3c"),0.8,0.3,0.0,"brushed_metal")
	_materials["gold"]=_material(Color("c99342"),0.73,0.32,0.0,"brushed_metal")
	_materials["light"]=_material(Color("a4e9ff"),0.1,0.3,2.5)
	_materials["amber"]=_material(Color("ff9545"),0.1,0.4,2.0)
	var solar:=ShaderMaterial.new();solar.shader=SolarShader;MaterialLibrary.apply_shader(solar,"brushed_metal",0.6);solar.set_shader_parameter("detail_level",quality);_materials["solar"]=solar
	# Layered annulus gives a 240m clear central aperture.
	_ring("dark",Vector3(0,0,-145),134,184)
	_ring("shell",Vector3(0,0,-157),148,180)
	_ring("gold",Vector3(0,0,-123),126,133)
	_ring("light",Vector3(0,0,-118),123.0,125.0)
	_ring("dark",Vector3(0,0,-214),146,164)
	var along_z:=Basis(Vector3.RIGHT,PI/2)
	_cylinder("dark",Vector3(0,0,-404),54,165,along_z)
	_cylinder("shell",Vector3(0,0,-420),58,100,along_z)
	_ring("gold",Vector3(0,0,-370),58,63)
	_cylinder("dark",Vector3(0,0,-312),39,32,along_z)
	_cylinder("light",Vector3(0,0,-293),23,2,along_z)
	for i in range(12):
		var angle:=TAU*float(i)/12.0
		var radial:=Vector3(cos(angle),sin(angle),0)
		var around:=Basis(Vector3.FORWARD,-angle)
		_box("shell",radial*164+Vector3(0,0,-166),Vector3(30,17,54),around)
		_box("dark",radial*179+Vector3(0,0,-160),Vector3(7,13,34),around)
		_box("light",radial*177+Vector3(0,0,-130),Vector3(5,10,2),around)
		_box("gold",radial*165+Vector3(0,0,-130),Vector3(11,15,3),around)
		_beam("dark",radial*152+Vector3(0,0,-198),radial*35+Vector3(0,0,-365),10)
		if quality>0:
			_box("dark",radial*171+Vector3(0,0,-179),Vector3(3,14,55),around)
			for j in range(3):_box("light",radial*(155+j*5)+Vector3(0,0,-129),Vector3(2,5,1),around)
	# Long solar wings deliberately sit farther behind the open approach.
	for sign_value in [-1,1]:
		var side:=float(sign_value)
		_beam("dark",Vector3(side*45,0,-400),Vector3(side*510,0,-400),14)
		_box("shell",Vector3(side*236,0,-400),Vector3(66,40,44))
		_box("gold",Vector3(side*238,0,-375),Vector3(60,34,5))
		for segment in range(4):
			var x:=side*(302+segment*60)
			for row in [-1,1]:
				_box("dark",Vector3(x,row*87,-400),Vector3(56,148,5))
				_box("solar",Vector3(x,row*87,-395),Vector3(52,144,1))
		_box("amber",Vector3(side*525,0,-395),Vector3(5,9,5))
	# Habitat towers and radiators make the back silhouette legible from afar.
	for sign_value in [-1,1]:
		var y:=float(sign_value)*226
		_beam("dark",Vector3(0,float(sign_value)*150,-182),Vector3(0,y,-270),15)
		_cylinder("shell",Vector3(0,y,-282),30,90,along_z)
		_ring("gold",Vector3(0,y,-239),29,33)
		_box("dark",Vector3(0,y,-218),Vector3(37,22,7))
		_box("light",Vector3(0,y,-213),Vector3(28,4,2))
		if quality>0:
			for rib in range(8):_box("dark",Vector3(-40+rib*11,y+float(sign_value)*50,-302),Vector3(4,45,70))
	for key in _surfaces:
		var instance:=MeshInstance3D.new();instance.name="Station_"+key;instance.mesh=_surfaces[key].commit();instance.material_override=_materials[key];add_child(instance)
	geometry_batches=_surfaces.size();_surfaces.clear()
	var label:=Label3D.new();label.text="ОРБИТАЛЬНЫЙ УЗЕЛ\n01  /  ПРИЧАЛ";label.font_size=64;label.pixel_size=0.12;label.position=Vector3(0,182,-125);label.modulate=Color("e4edf3");label.outline_size=5;add_child(label)
