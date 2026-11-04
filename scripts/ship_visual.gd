extends Node3D
# Authored procedural graphics reconstruction: original wedge-inspired artwork.
# These three adapted hulls are not the original57-model catalogue or collision meshes.
const HullShader=preload("res://scripts/ship_hull.gdshader")
const ExhaustShader=preload("res://scripts/ship_exhaust.gdshader")
const HaloShader=preload("res://scripts/ship_halo.gdshader")
static var _mesh_cache:Dictionary={}
static var _material_cache:Dictionary={}
var _groups:Dictionary={}
var _profile:Dictionary={}
var _quality:=2
var _span:=42.0
var _id:="cobra"
var _thrust:=0.25
var _display_thrust:=0.25
var _clock:=0.0
var _landed:=false
var _gear_amount:=0.0
var landing_gear:MeshInstance3D
var _exhausts:Array[MeshInstance3D]=[]
var _halos:Array[MeshInstance3D]=[]
var _engine_bases:Array[Vector3]=[]
var geometry_stats:Dictionary={}
var hull_mesh:MeshInstance3D
const RIB_Z:=[-17.0,-13.0,-7.0,1.0,8.0,12.0]
const RIB_W:=[1.7,7.0,13.0,19.8,21.0,14.5]
const RIB_TOP:=[0.65,1.15,1.85,2.7,2.45,1.55]
const RIB_BOTTOM:=[-0.45,-0.85,-1.4,-1.95,-1.75,-1.0]

func configure(profile:Dictionary)->void:
	_profile=profile.duplicate(true);_id=str(profile.get("id","cobra"));_span=clampf(float(profile.get("visual_span_m",42.0)),8.0,100.0)
	for child in get_children():remove_child(child);child.queue_free()
	_exhausts.clear();_halos.clear();_engine_bases.clear();_groups.clear()
	var key:="%s:%.3f:%d"%[_id,_span,_quality]
	if not _mesh_cache.has(key):
		_build_geometry()
		var mesh:=ArrayMesh.new();var triangles:=0
		for group in _groups:
			var entry:Dictionary=_groups[group];var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=entry.vertices;arrays[Mesh.ARRAY_NORMAL]=entry.normals;arrays[Mesh.ARRAY_TEX_UV]=entry.uv
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(mesh.get_surface_count()-1,_material(group))
			triangles+=entry.vertices.size()/3
		_groups.clear()
		_build_landing_gear()
		var gear_mesh:=ArrayMesh.new();var gear_triangles:=0
		for group in _groups:
			var entry:Dictionary=_groups[group];var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=entry.vertices;arrays[Mesh.ARRAY_NORMAL]=entry.normals;arrays[Mesh.ARRAY_TEX_UV]=entry.uv
			gear_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);gear_mesh.surface_set_material(gear_mesh.get_surface_count()-1,_material(group));gear_triangles+=entry.vertices.size()/3
		_mesh_cache[key]={"mesh":mesh,"triangles":triangles,"gear":gear_mesh,"gear_triangles":gear_triangles}
	var cached:Dictionary=_mesh_cache[key]
	hull_mesh=MeshInstance3D.new();hull_mesh.name="ArmouredHull";hull_mesh.mesh=cached.mesh;add_child(hull_mesh)
	geometry_stats={"triangles":cached.triangles,"material_surfaces":hull_mesh.mesh.get_surface_count(),"nominal_span_m":_span,"source":"authored-procedural-graphics-v1","landing_gear_triangles":cached.gear_triangles}
	landing_gear=MeshInstance3D.new();landing_gear.name="RetractableLandingGear";landing_gear.mesh=cached.gear;landing_gear.visible=_gear_amount>0.01;landing_gear.scale.y=maxf(0.02,_gear_amount);add_child(landing_gear)
	for x in [-8.8,8.8]:_add_exhaust(_transform_point(Vector3(x,0.0,14.3)))
	_add_registry_markings()
	_groups.clear();set_process(true)

func set_quality(value:int)->void:
	value=clampi(value,0,2)
	if value==_quality:return
	_quality=value
	if not _profile.is_empty():configure(_profile)
func set_thrust(value:float)->void:
	_thrust=clampf(absf(value),0,1) if is_finite(value) else 0.0
func set_landed(value:bool)->void:
	_landed=value
func _process(dt:float)->void:
	_clock+=dt;_display_thrust=move_toward(_display_thrust,_thrust,dt*3.0)
	_gear_amount=move_toward(_gear_amount,1.0 if _landed else 0.0,dt*5.0)
	if landing_gear!=null:
		landing_gear.visible=_gear_amount>0.01;landing_gear.scale.y=maxf(0.02,_gear_amount)
	for i in range(_exhausts.size()):
		var jet:MeshInstance3D=_exhausts[i]
		var length_scale:float=(0.28+_display_thrust*1.15)*(1+sin(_clock*32+i)*0.025)
		jet.scale=Vector3(0.75+_display_thrust*0.25,length_scale,0.75+_display_thrust*0.25)
		jet.position=_engine_bases[i]+Vector3(0,0,4.0*length_scale*_span/42.0)
		jet.material_override.set_shader_parameter("power",_display_thrust)
		_halos[i].material_override.set_shader_parameter("power",_display_thrust)
		jet.visible=_quality>0 or _display_thrust>0.1

func _transform_point(point:Vector3)->Vector3:
	var p:=point
	if _id=="eagle":p.x*=0.90;p.z*=1.20;p.y*=0.88
	elif _id=="shuttle":p.x*=0.82;p.z*=0.96;p.y*=1.35
	return p*(_span/42.0)
func _triangle(group:String,a:Vector3,b:Vector3,c:Vector3,normal:Vector3=Vector3.ZERO)->void:
	a=_transform_point(a);b=_transform_point(b);c=_transform_point(c)
	var n:Vector3=(b-a).cross(c-a).normalized() if normal==Vector3.ZERO else normal.normalized()
	if n.length_squared()<0.5:return
	if not _groups.has(group):_groups[group]={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"uv":PackedVector2Array()}
	var entry:Dictionary=_groups[group]
	for p in [a,b,c]:entry.vertices.append(p);entry.normals.append(n);entry.uv.append(Vector2(p.x,p.z))
func _quad(group:String,a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
	_triangle(group,a,b,c);_triangle(group,a,c,d)
func _face(group:String,points:Array)->void:
	if points.size()<3:return
	for i in range(1,points.size()-1):_triangle(group,points[0],points[i],points[i+1])
func _material(group:String)->Material:
	if _material_cache.has(group):return _material_cache[group]
	var palette:={"frame":[Color("354b57"),0.40,0.44],"armour":[Color("b6c4c7"),0.12,0.33],"edge":[Color("c2d0d2"),0.52,0.29],"navy":[Color("45677c"),0.12,0.39],"gold":[Color("e6b354"),0.45,0.33],"copper":[Color("88614b"),0.8,0.35],"rubber":[Color("0b141b"),0.08,0.72]}
	if palette.has(group):
		var row:Array=palette[group];var material:=ShaderMaterial.new();material.shader=HullShader;material.set_shader_parameter("paint",row[0]);material.set_shader_parameter("metalness",row[1]);material.set_shader_parameter("finish",row[2]);_material_cache[group]=material
	else:
		var material:=StandardMaterial3D.new()
		if group=="glass":material.albedo_color=Color("10384e");material.metallic=0.72;material.roughness=0.12;material.metallic_specular=0.85;material.clearcoat_enabled=true;material.clearcoat=0.9
		else:
			material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color={"cyan":Color("7eeaff"),"white":Color("d9faff"),"amber":Color("ffb549"),"red":Color("ff5052")}.get(group,Color.WHITE)
		_material_cache[group]=material
	return _material_cache[group]
func _sample(values:Array,z:float)->float:
	for i in range(RIB_Z.size()-1):
		if z<=RIB_Z[i+1]:return lerpf(float(values[i]),float(values[i+1]),clampf((z-RIB_Z[i])/(RIB_Z[i+1]-RIB_Z[i]),0,1))
	return float(values[-1])
func _top(x:float,z:float)->float:
	return lerpf(_sample(RIB_TOP,z),0.35,pow(clampf(absf(x)/maxf(1,_sample(RIB_W,z)),0,1),0.85))
func _plate(poly:Array,lift:float,depth:float,group:String)->void:
	poly=poly.duplicate()
	var area:=0.0
	for i in range(poly.size()):area+=poly[i].x*poly[(i+1)%poly.size()].y-poly[(i+1)%poly.size()].x*poly[i].y
	if area>0:poly.reverse()
	var center:=Vector2.ZERO
	for p in poly:center+=p
	center/=poly.size()
	var outer:Array=[];var inner:Array=[]
	for p in poly:
		outer.append(Vector3(p.x,_top(p.x,p.y)+lift,p.y))
		var q:Vector2=center+(p-center)*0.96
		inner.append(Vector3(q.x,_top(q.x,q.y)+lift+depth,q.y))
	var mid:=Vector3(center.x,_top(center.x,center.y)+lift+depth,center.y)
	for i in range(poly.size()):
		var next:=(i+1)%poly.size()
		_quad(group,outer[i],outer[next],inner[next],inner[i])
		_triangle(group,mid,inner[i],inner[next])
func _mirrored_plate(poly:Array,lift:float,depth:float,group:String)->void:
	_plate(poly,lift,depth,group)
	var mirror:Array=[]
	for i in range(poly.size()-1,-1,-1):mirror.append(Vector2(-poly[i].x,poly[i].y))
	_plate(mirror,lift,depth,group)
func _bevel_box(center:Vector3,size:Vector3,bevel:float,group:String,basis:Basis=Basis.IDENTITY)->void:
	var b:=minf(bevel,minf(size.x,minf(size.y,size.z))*0.3)
	var x:=size.x*0.5;var y:=size.y*0.5;var z:=size.z*0.5
	var perimeter:Array=[Vector2(-x+b,-z),Vector2(x-b,-z),Vector2(x,-z+b),Vector2(x,z-b),Vector2(x-b,z),Vector2(-x+b,z),Vector2(-x,z-b),Vector2(-x,-z+b)]
	var rings:Array=[]
	for height in [-y,-y+b,y-b,y]:
		var ring:Array=[];var shrink:float=b if height==-y or height==y else 0.0
		for p in perimeter:ring.append(center+basis*Vector3(p.x*(1-shrink/maxf(x,0.01)),height,p.y*(1-shrink/maxf(z,0.01))))
		rings.append(ring)
	for level in range(3):
		for i in range(8):_quad(group,rings[level][(i+1)%8],rings[level][i],rings[level+1][i],rings[level+1][(i+1)%8])
	var top:Array=rings[3].duplicate();top.reverse();_face(group,rings[0]);_face(group,top)
func _cylinder(a:Vector3,b:Vector3,radius:float,group:String,segments:=16,end_radius:float=-1.0)->void:
	if end_radius<0:end_radius=radius
	var axis:Vector3=(b-a).normalized();var helper:Vector3=Vector3.UP if absf(axis.y)<0.95 else Vector3.RIGHT
	var u:Vector3=axis.cross(helper).normalized();var v:Vector3=axis.cross(u).normalized()
	for i in range(segments):
		var t1:=TAU*i/segments;var t2:=TAU*(i+1)/segments
		var d1:Vector3=u*cos(t1)+v*sin(t1);var d2:Vector3=u*cos(t2)+v*sin(t2)
		_quad(group,a+d1*radius,a+d2*radius,b+d2*end_radius,b+d1*end_radius)
		_triangle(group,a,a+d2*radius,a+d1*radius);_triangle(group,b,b+d1*end_radius,b+d2*end_radius)
func _tube(center:Vector3,outer:float,inner:float,length:float,group:String,segments:=32)->void:
	for i in range(segments):
		var t1:=TAU*i/segments;var t2:=TAU*(i+1)/segments
		var d1:=Vector3(cos(t1),sin(t1),0);var d2:=Vector3(cos(t2),sin(t2),0)
		var front:=center-Vector3(0,0,length*0.5);var back:=center+Vector3(0,0,length*0.5)
		_quad(group,front+d1*outer,front+d2*outer,back+d2*outer,back+d1*outer)
		_quad(group,front+d2*inner,front+d1*inner,back+d1*inner,back+d2*inner)
		_quad(group,back+d1*inner,back+d1*outer,back+d2*outer,back+d2*inner)
func _line(a:Vector3,b:Vector3,width:float,group:String)->void:
	_cylinder(a,b,width,group,6)

func _build_geometry()->void:
	# Broad wedge core, with a raised keel and individually articulated armour.
	for side in [-1.0,1.0]:
		for i in range(RIB_Z.size()-1):
			var z1:float=RIB_Z[i];var z2:float=RIB_Z[i+1];var w1:float=RIB_W[i]*side;var w2:float=RIB_W[i+1]*side
			var upper1:=Vector3(0,RIB_TOP[i],z1);var upper2:=Vector3(0,RIB_TOP[i+1],z2)
			var e1:=Vector3(w1,0.2,z1);var e2:=Vector3(w2,0.2,z2)
			var lower1:=Vector3(0,RIB_BOTTOM[i],z1);var lower2:=Vector3(0,RIB_BOTTOM[i+1],z2)
			if side>0:
				_quad("frame",upper1,upper2,e2,e1);_quad("navy",e1,e2,lower2,lower1)
			else:
				_quad("frame",upper1,e1,e2,upper2);_quad("navy",e1,lower1,lower2,e2)
			_line(e1+Vector3(0,0.05,0),e2+Vector3(0,0.05,0),0.105,"edge")
	_face("frame",[Vector3(-14.5,0.2,12),Vector3(0,1.55,12),Vector3(14.5,0.2,12),Vector3(0,-1,12)])
	_face("edge",[Vector3(-1.7,0.2,-17),Vector3(0,0.65,-17),Vector3(1.7,0.2,-17),Vector3(0,-0.45,-17)])
	_mirrored_plate([Vector2(0.5,-16.2),Vector2(4.8,-13.3),Vector2(8.6,-8.8),Vector2(1.8,-9.8)],0.035,0.15,"armour")
	_mirrored_plate([Vector2(4.4,-8.1),Vector2(9.6,-8.2),Vector2(15.7,-1),Vector2(5.1,-1.4)],0.045,0.24,"armour")
	_mirrored_plate([Vector2(6.0,-0.6),Vector2(16.5,-0.2),Vector2(19.8,4.3),Vector2(8.5,3.0)],0.055,0.27,"navy")
	_mirrored_plate([Vector2(10.1,3.9),Vector2(20.1,5.1),Vector2(19.7,7.4),Vector2(14.8,10.7),Vector2(10.2,9.8)],0.06,0.22,"armour")
	_mirrored_plate([Vector2(4.9,0.0),Vector2(8.3,3.8),Vector2(8.0,10.7),Vector2(4.2,10.9)],0.055,0.3,"armour")
	_mirrored_plate([Vector2(1.0,3.1),Vector2(3.5,2.8),Vector2(3.5,10.7),Vector2(1,11.1)],0.06,0.32,"navy")
	# Thin ochre identification panels and crisp white wingtip trim.
	_mirrored_plate([Vector2(8.9,-6.6),Vector2(9.55,-6.6),Vector2(16.1,0.2),Vector2(15.25,0.0)],0.32,0.06,"gold")
	_mirrored_plate([Vector2(11.1,4.8),Vector2(18.9,5.6),Vector2(18.7,6.35),Vector2(11.1,5.5)],0.32,0.06,"gold")
	_mirrored_plate([Vector2(18.7,3.7),Vector2(19.4,4.8),Vector2(18.9,5.0),Vector2(18.15,3.9)],0.32,0.08,"white")
	_plate([Vector2(-0.35,-15),Vector2(0.35,-15),Vector2(0.6,-10),Vector2(-0.6,-10)],0.24,0.05,"gold")
	# Cockpit: smoked glass facets with a visible metal cage, not a painted triangle.
	var canopy:Array=[Vector3(-1.9,2.0,-9.9),Vector3(1.9,2.0,-9.9),Vector3(3.25,3.35,-5.7),Vector3(3.7,3.7,-0.6),Vector3(-3.7,3.7,-0.6),Vector3(-3.25,3.35,-5.7)]
	_face("glass",[canopy[5],canopy[2],canopy[1],canopy[0]])
	_face("glass",[canopy[4],canopy[3],canopy[2],canopy[5]])
	for i in range(canopy.size()):
		var a:Vector3=canopy[i];var b:Vector3=canopy[(i+1)%canopy.size()]
		_line(a,b,0.115,"edge")
		var floor:=Vector3(a.x,_top(a.x,a.z)+0.1,a.z)
		_line(floor,a,0.09,"frame")
		_quad("glass",Vector3(b.x,_top(b.x,b.z)+0.1,b.z),floor,a,b)
	_line(Vector3(0,2,-9.9),Vector3(0,3.35,-5.7),0.1,"frame")
	_line(Vector3(0,3.35,-5.7),Vector3(0,3.7,-0.6),0.1,"frame")
	_bevel_box(Vector3(0,3.05,1.2),Vector3(7.9,1.25,3.5),0.25,"armour")
	_bevel_box(Vector3(0,3.72,1.2),Vector3(3.9,0.12,2.2),0.07,"navy")
	for side in [-1.0,1.0]:
		# Recessed heat exchanger, copper plumbing, vents and fasteners.
		var x:float=side*6.5
		_bevel_box(Vector3(x,1.9,6.0),Vector3(2.05,0.32,5.8),0.12,"rubber")
		for j in range(10 if _quality>0 else 5):
			var z:=3.4+j*(0.55 if _quality>0 else 1.1)
			_bevel_box(Vector3(x,2.12,z),Vector3(1.85,0.18,0.18),0.03,"edge")
		_line(Vector3(side*4.8,2.45,3.3),Vector3(side*4.8,2.45,10.5),0.14,"copper")
		_line(Vector3(side*5.2,2.37,5),Vector3(side*5.2,2.37,10.5),0.09,"edge")
		for z in [3.3,6.6,9.8]:
			_bevel_box(Vector3(side*4.8,2.49,z),Vector3(0.7,0.35,0.22),0.05,"navy")
		for z in [-4.0,0.0,7.9]:
			var px:float=side*(12.0 if z>0 else 10.0)
			_cylinder(Vector3(px,_top(px,z)+0.35,z),Vector3(px,_top(px,z)+0.41,z),0.085,"edge",8)
		# Twin inset engine nacelles, metallic petals, dark throat and luminous iris.
		var ex:float=side*8.8
		_bevel_box(Vector3(ex,0.25,10.2),Vector3(5.5,2.9,5.0),0.42,"frame")
		_bevel_box(Vector3(ex,1.88,9.6),Vector3(5.1,0.32,3.4),0.12,"armour")
		_tube(Vector3(ex,0,12.6),1.72,1.19,3.15,"copper",32 if _quality>0 else 16)
		_tube(Vector3(ex,0,14.0),1.90,1.15,0.45,"edge",32 if _quality>0 else 16)
		_tube(Vector3(ex,0,13.7),1.30,1.14,0.30,"navy",24)
		_cylinder(Vector3(ex,0,13.65),Vector3(ex,0,13.69),1.08,"cyan",32)
		_cylinder(Vector3(ex,0,13.70),Vector3(ex,0,13.73),0.48,"white",24)
		for j in range(12):
			var angle:=j*TAU/12;var p:=Vector3(ex+cos(angle)*1.56,sin(angle)*1.56,13.15)
			_bevel_box(p,Vector3(0.18,0.18,1.9),0.04,"navy")
		# Recessed weapon at the forward cheek, a body/coil/barrel assembly.
		var gun_x:float=side*7.9
		_bevel_box(Vector3(gun_x,0.25,-10.6),Vector3(1.35,1.0,2.9),0.16,"navy")
		_cylinder(Vector3(gun_x,0.3,-10.7),Vector3(gun_x,0.3,-14.35),0.27,"edge",12)
		_cylinder(Vector3(gun_x,0.3,-12),Vector3(gun_x,0.3,-12.25),0.38,"copper",12)
		_cylinder(Vector3(gun_x,0.3,-14.34),Vector3(gun_x,0.3,-14.39),0.19,"rubber",12)
		_bevel_box(Vector3(side*19.5,0.48,6.1),Vector3(0.24,0.18,1.55),0.04,"red" if side<0 else "cyan")
		_bevel_box(Vector3(side*12.4,0.28,10.7),Vector3(1.55,0.3,0.3),0.08,"amber")
		# Belly attachment ribs and landing recess stay inside the visual envelope.
		_bevel_box(Vector3(side*7,-1.22,0),Vector3(1.0,0.7,8),0.12,"frame")
		_bevel_box(Vector3(side*7,-1.6,2),Vector3(1.2,0.18,2.5),0.08,"navy")
	# Aft keel antenna/radiator and triangular tail machinery.
	_bevel_box(Vector3(0,2.85,7.4),Vector3(1.45,0.6,7),0.16,"frame")
	for j in range(6):_bevel_box(Vector3(0,3.26,4.8+j*0.8),Vector3(1.1,0.16,0.25),0.04,"edge")
	_line(Vector3(0,3.1,9.6),Vector3(0,4.6,10.4),0.08,"edge")
	_bevel_box(Vector3(0,4.62,10.4),Vector3(0.3,0.22,0.5),0.04,"amber")

func _add_exhaust(base:Vector3)->void:
	var jet:=MeshInstance3D.new();jet.name="EnginePlume%d"%_exhausts.size()
	var cone:=CylinderMesh.new();cone.top_radius=0;cone.bottom_radius=1.05*_span/42.0;cone.height=8.0*_span/42.0;cone.radial_segments=24;cone.rings=3;cone.cap_bottom=false;cone.cap_top=false
	jet.mesh=cone;jet.rotation.x=PI/2;jet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new();material.shader=ExhaustShader;jet.material_override=material
	add_child(jet);_exhausts.append(jet);_engine_bases.append(base)
	jet.position=base+Vector3(0,0,4*_span/42.0)
	var halo:=MeshInstance3D.new();halo.name="NozzleGlow";var quad:=QuadMesh.new();quad.size=Vector2.ONE*5.3*_span/42.0;halo.mesh=quad
	var halo_material:=ShaderMaterial.new();halo_material.shader=HaloShader;halo.material_override=halo_material;halo.position=Vector3(0,-4.0*_span/42.0,0);halo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;jet.add_child(halo);_halos.append(halo)
func _add_registry_markings()->void:
	if _quality==0:return
	var registry:=Label3D.new();registry.name="RegistryMarking";registry.text={"cobra":"SF / 03","eagle":"SF / 02","shuttle":"SF / 01"}.get(_id,"SF / 03")
	registry.font_size=70;registry.pixel_size=0.019*_span/42.0;registry.modulate=Color("c6dadd");registry.outline_size=0;registry.shaded=true;registry.no_depth_test=false
	registry.position=_transform_point(Vector3(12.6,_top(12.6,7.7)+0.56,7.7));registry.rotation_degrees=Vector3(-90,0,-7);add_child(registry)

func _build_landing_gear()->void:
	# Preserve the existing physical clearance without floating artwork or a
	# change to gameplay/save geometry. Feet reach exactly that ground plane.
	var height_factor:=0.88 if _id=="eagle" else 1.35 if _id=="shuttle" else 1.0
	var ground_y:float=-(_span*0.14+2.0)/(_span/42.0*height_factor)
	for anchor in [Vector3(-8,-1.35,5.5),Vector3(8,-1.35,5.5),Vector3(0,-1.0,-10.4)]:
		var knee:=Vector3(anchor.x,ground_y*0.54,anchor.z+0.55)
		var foot:=Vector3(anchor.x,ground_y+0.15,anchor.z+0.85)
		_bevel_box(anchor,Vector3(1.3,0.6,1.7),0.12,"frame")
		_cylinder(anchor,knee,0.26,"edge",12)
		_cylinder(knee,foot+Vector3(0,0.48,0),0.17,"edge",12)
		_cylinder(anchor+Vector3(0.55,0,0.4),knee,0.10,"copper",8)
		_cylinder(knee-Vector3(0.5,0,0),knee+Vector3(0.5,0,0),0.24,"frame",12)
		_bevel_box(foot,Vector3(2.0,0.3,2.8),0.09,"frame")
		_bevel_box(foot+Vector3(0,0.17,0),Vector3(1.6,0.1,1.9),0.025,"edge")
