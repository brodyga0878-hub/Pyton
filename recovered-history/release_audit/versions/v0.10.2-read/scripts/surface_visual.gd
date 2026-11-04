extends Node3D
const TerrainShader=preload("res://scripts/terrain.gdshader")
const PadShader=preload("res://scripts/landing_pad.gdshader")
const BuildingShader=preload("res://scripts/building.gdshader")
var quality:=2
func set_quality(value:int)->void:
	quality=clampi(value,0,2)
	for child in get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			if child.material_override.shader in [TerrainShader,BuildingShader]:
				child.material_override.set_shader_parameter("detail_level",quality)


func configure(surface: RefCounted) -> void:
	var current_site:String=str(surface.get("site_name")) if surface.get("site_name")!=null else ""
	var cache_key:String=surface.terrain_key() if surface.has_method("terrain_key") else str(surface.seed_value)+":"+str(surface.kind)+":"+current_site
	if get_meta("terrain_key","")==cache_key and get_child_count()>0:return
	for child in get_children():remove_child(child);child.queue_free()
	set_meta("terrain_key",cache_key)
	var base: Color={"earth":Color("426b51"),"ice":Color("a5c5cf"),"desert":Color("aa714d"),"rock":Color("737984")}.get(surface.kind,Color("737984"))
	var count:int=surface.grid_cells() if surface.has_method("grid_cells") else surface.GRID_CELLS
	var width: float=surface.GRID_WIDTH
	var uvs:=PackedVector2Array();var uv2s:=PackedVector2Array()
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	var spherical:bool=surface.get("globe")!=null
	var heights:=PackedFloat64Array()
	var cell:=width/count
	if spherical:
		heights.resize((count+3)*(count+3))
		for z in range(count+3):
			for x in range(count+3):
				heights[z*(count+3)+x]=surface.raw_height_at(-width/2+(x-1)*cell,-width/2+(z-1)*cell)
	for z in range(count+1):
		for x in range(count+1):
			var point:=Vector3(-width/2+x*width/count,0,-width/2+z*width/count)
			point.y=heights[(z+1)*(count+3)+x+1] if spherical else surface.raw_height_at(point.x,point.z)
			var dx:float
			var dz:float
			if spherical:
				dx=(heights[(z+1)*(count+3)+x+2]-heights[(z+1)*(count+3)+x])/(2*cell)
				dz=(heights[(z+2)*(count+3)+x+1]-heights[z*(count+3)+x+1])/(2*cell)
			else:
				dx=(surface.raw_height_at(point.x+1,point.z)-surface.raw_height_at(point.x-1,point.z))*0.5
				dz=(surface.raw_height_at(point.x,point.z+1)-surface.raw_height_at(point.x,point.z-1))*0.5
			if spherical:
				var ll:Array=surface.globe.coordinates(point.x,point.z)
				var r:float=surface.globe.radius
				uvs.append(Vector2(r*cos(ll[0])*cos(ll[1]),r*sin(ll[0])))
				uv2s.append(Vector2(r*cos(ll[0])*sin(ll[1]),0))
			vertices.append(point);normals.append(Vector3(-dx,1,-dz).normalized());colors.append(base.lightened(clampf(point.y/400,-0.2,0.3)))
	for z in range(count):
		for x in range(count):
			var a:=z*(count+1)+x;var b:=a+1;var c:=a+count+1;var d:=c+1
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	if spherical:arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_TEX_UV2]=uv2s
	var terrain:=MeshInstance3D.new();var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);terrain.mesh=mesh
	var mat:=ShaderMaterial.new();mat.shader=TerrainShader
	mat.set_shader_parameter("detail_level",quality)
	mat.set_shader_parameter("spherical_coordinates",spherical)
	mat.set_shader_parameter("surface_kind",int({"earth":0,"rock":1,"desert":2,"ice":3}.get(surface.kind,1)))
	terrain.material_override=mat
	add_child(terrain)
	if spherical:
		var inner:=width*0.5
		for outer in [8000.0,32000.0,128000.0]:
			add_child(_far_ring(surface,inner,outer,mat,base));inner=outer
	var landing_point:Vector3=surface.pad_position() if surface.has_method("pad_position") else Vector3.ZERO
	if spherical and Vector2(landing_point.x,landing_point.z).length()>width*0.45:return
	var pad:=MeshInstance3D.new()
	var box:=BoxMesh.new();box.size=Vector3(100,0.3,100)
	pad.mesh=box;pad.position=landing_point+Vector3(0,0.2,0)
	var pm:=ShaderMaterial.new();pm.shader=PadShader
	pad.material_override=pm;add_child(pad)
	for i in range(4):
		var beacon:=MeshInstance3D.new()
		var pole:=CylinderMesh.new();pole.top_radius=1.2;pole.bottom_radius=1.2;pole.height=10
		beacon.mesh=pole;beacon.position=landing_point+Vector3(48 if i%2 else -48,5,48 if i/2 else -48)
		var bm:=StandardMaterial3D.new();bm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;bm.albedo_color=Color("65f0d6")
		beacon.material_override=bm;add_child(beacon)
	var site_name:String=str(surface.get("site_name")) if surface.get("site_name")!=null else ""
	if not site_name.is_empty() and surface.has_method("buildings"):
		var index:=0
		for volume in surface.buildings():
			var building:=MeshInstance3D.new();var block:=BoxMesh.new()
			block.size=volume.size;building.mesh=block
			building.position=volume.get_center();building.name="CityBlock%d"%index;index+=1
			var wall:=ShaderMaterial.new();wall.shader=BuildingShader
			wall.set_shader_parameter("detail_level",quality);wall.set_shader_parameter("building_seed",float(index)+float(surface.seed_value&255))
			building.material_override=wall;add_child(building)
	var marker:=Label3D.new();marker.text="ПОСАДОЧНАЯ ПЛОЩАДКА" if site_name.is_empty() else site_name.to_upper();marker.font_size=64;marker.pixel_size=0.08
	marker.position=landing_point+Vector3(0,22,0);marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test=false;add_child(marker)

func _far_ring(surface:RefCounted,inner:float,outer:float,material:Material,base:Color)->MeshInstance3D:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray()
	var uv:=PackedVector2Array();var uv2:=PackedVector2Array();var indices:=PackedInt32Array()
	const ALONG:=64
	const RADIAL:=4
	for side in range(4):
		var first:=vertices.size()
		for row in range(RADIAL+1):
			var extent:=lerpf(inner,outer,float(row)/RADIAL)
			for i in range(ALONG+1):
				var t:float=lerpf(-1.0,1.0,float(i)/ALONG)
				var p:Vector2=[Vector2(t,-1),Vector2(1,t),Vector2(-t,1),Vector2(-1,-t)][side]*extent
				var height:float=surface.raw_height_at(p.x,p.y)
				var ll:Array=surface.globe.coordinates(p.x,p.y)
				var radius:float=surface.globe.radius
				var angle:=p.length()/radius
				var direction:=p.normalized()*sin(angle)
				vertices.append(Vector3(p.x,height,p.y));normals.append(Vector3(direction.x,cos(angle),direction.y).normalized())
				colors.append(base.lightened(clampf(surface.globe.elevation(ll[0],ll[1])/400.0,-0.2,0.3)))
				uv.append(Vector2(radius*cos(ll[0])*cos(ll[1]),radius*sin(ll[0])));uv2.append(Vector2(radius*cos(ll[0])*sin(ll[1]),0))
		for row in range(RADIAL):
			for i in range(ALONG):
				var a:=first+row*(ALONG+1)+i;var b:=a+1;var c:=a+ALONG+1;var d:=c+1
				indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=uv2;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name="DistantTerrain%d"%int(outer);node.mesh=mesh;node.material_override=material
	return node
