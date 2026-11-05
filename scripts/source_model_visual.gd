extends Node3D
# Modern rendering of compiled source geometry. No assembler/CPU interpreter runs.
# Raw source model execution and geographic placement have separate contracts.
const Units=preload("res://scripts/source_units.gd")
const MaterialShader=preload("res://scripts/source_model.gdshader")
const Materials=preload("res://scripts/material_library.gd")
const CityMaterials=preload("res://scripts/city_surface_library.gd")
const Roles=preload("res://scripts/city_material_roles.gd")
# Default: source ground axes [north,up,east] -> surface [east,up,south].
# Live cities are compiled in body-fixed orientation and supply its inverse.
const DEFAULT_CONVERSION:=Basis(Vector3(0,0,-1),Vector3.UP,Vector3.RIGHT)
var triangle_count:=0
var source_model_index:=-1
var unresolved_texture_indices:Array=[]
var retained_event_kinds:Dictionary={}
var local_bounds:=AABB()
var quality:=2

func set_quality(value:int)->void:
	quality=clampi(value,0,2)
	for child in get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			child.material_override.set_shader_parameter("detail_level",quality)
			if quality>0:CityMaterials.bind_shader(child.material_override)
			else:CityMaterials.clear_material(child.material_override)

static func material_slot(appearance:Dictionary,normal:Vector3)->int:
	# Provisional modern finish, not a decoded FFE material semantic. Preserve
	# source palette and illumination; only classify texture response by colour
	# and face orientation. Source palette has no named road/window/roof tags.
	var colour:Color=appearance.colour
	var brightness:float=maxf(colour.r,maxf(colour.g,colour.b))
	var saturation:float=brightness-minf(colour.r,minf(colour.g,colour.b))
	if absf(normal.y)>0.75 and brightness<0.48:return 1 # dark horizontal paving
	if saturation>0.18:return 2 # coloured alloy retains source paint
	if absf(normal.y)>0.75 and brightness>0.65:return 3 # light roof alloy
	return 0 # neutral mineral facade / remaining source faces

static func palette_colour(rgb:Array)->Color:
	return Color(clampf(float(rgb[0])/8.0,0,1),clampf(float(rgb[1])/8.0,0,1),clampf(float(rgb[2])/8.0,0,1))

static func face_material(face:Dictionary)->Dictionary:
	var source:Dictionary=face.get("material_base",{})
	var code:int=int(face.get("material_code",0))
	var rgb:Array=source.get("rgb4_base",[(code>>8)&15,(code>>4)&15,code&15])
	var colour:=palette_colour(rgb)
	if source.get("textured",false):
		# The original texture ID is retained. A modern material is deliberate;
		# this adapter does not claim to decode original UV/texture command state.
		colour=Color("758892")
	return {"colour":colour,"unlit":bool(source.get("unlit",(code&0x2000)!=0)),"texture":int(source.get("texture_index",-1)) if source.get("textured",false) else -1}

func configure(compiled:Dictionary,conversion_basis:Basis=DEFAULT_CONVERSION,material_context:Dictionary={})->bool:
	if not compiled.get("ok",false):return false
	for child in get_children():remove_child(child);child.queue_free()
	triangle_count=0;source_model_index=int(compiled.model_index)
	unresolved_texture_indices.clear();retained_event_kinds.clear()
	var batches:Dictionary={false:{"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colours":PackedColorArray(),"layers":PackedVector2Array()},true:{"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colours":PackedColorArray(),"layers":PackedVector2Array()}}
	var layers:=_decal_layers(compiled.triangles_raw,conversion_basis)
	var first:=true
	for face_index in range(compiled.triangles_raw.size()):
		var face:Dictionary=compiled.triangles_raw[face_index]
		var vertices:Array[Vector3]=[]
		for point in face.vertices:vertices.append(_point(point,conversion_basis))
		var normal:Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
		if face.has("normal_raw"):
			var declared:=(conversion_basis*Vector3(float(face.normal_raw[0]),float(face.normal_raw[1]),float(face.normal_raw[2]))).normalized()
			if declared.length_squared()>0:normal=declared
		var appearance:=face_material(face)
		if appearance.texture>=0 and not appearance.texture in unresolved_texture_indices:unresolved_texture_indices.append(appearance.texture)
		var batch:Dictionary=batches[appearance.unlit]
		var colour:Color=appearance.colour.srgb_to_linear();colour.a=1.0 if appearance.unlit else 0.0
		var role:=Roles.classify(face,normal,vertices,source_model_index,material_context)
		for point in vertices:
			batch.vertices.append(point);batch.normals.append(normal);batch.colours.append(colour);batch.layers.append(Vector2(layers[face_index],role))
			if first:local_bounds=AABB(point,Vector3.ZERO);first=false
			else:local_bounds=local_bounds.expand(point)
		triangle_count+=1
	for unlit in batches:
		var batch:Dictionary=batches[unlit]
		if batch.vertices.is_empty():continue
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=batch.vertices;arrays[Mesh.ARRAY_NORMAL]=batch.normals;arrays[Mesh.ARRAY_COLOR]=batch.colours
		arrays[Mesh.ARRAY_TEX_UV2]=batch.layers
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material:=ShaderMaterial.new();material.shader=MaterialShader
		material.set_shader_parameter("detail_level",quality)
		if quality>0 and not CityMaterials.bind_shader(material):return false
		var visual:=MeshInstance3D.new();visual.name="SourceUnlit" if unlit else "SourceLit";visual.mesh=mesh
		visual.material_override=material;add_child(visual)
	for event in compiled.source_events:
		var kind:String=str(event.kind)
		retained_event_kinds[kind]=int(retained_event_kinds.get(kind,0))+1
		if kind=="ball" and int(event.radius_raw)>0:
			var sphere:=SphereMesh.new();sphere.radius=Units.metres(float(event.radius_raw));sphere.height=sphere.radius*2
			sphere.radial_segments=32;sphere.rings=16
			var visual:=MeshInstance3D.new();visual.mesh=sphere;visual.position=_point(event.center_raw,conversion_basis)
			var material:=StandardMaterial3D.new();var appearance:=face_material(event)
			material.albedo_color=appearance.colour;material.roughness=0.5;material.metallic=0.1
			if not appearance.unlit:Materials.apply_standard(material,"painted_alloy",0.25)
			if appearance.unlit:material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			visual.material_override=material;add_child(visual)
	return triangle_count>0

static func _point(point:Variant,conversion_basis:Basis)->Vector3:
	return conversion_basis*Vector3(Units.metres(float(point[0])),Units.metres(float(point[1])),Units.metres(float(point[2])))

static func _decal_layers(faces:Array,conversion_basis:Basis=DEFAULT_CONVERSION)->PackedFloat32Array:
	var planes:Dictionary={};var records:Array=[]
	for face in faces:
		var a:=_point(face.vertices[0],conversion_basis);var b:=_point(face.vertices[1],conversion_basis);var c:=_point(face.vertices[2],conversion_basis)
		var cross:Vector3=(b-a).cross(c-a);var normal:=cross.normalized()
		var axis:=0
		if absf(normal.y)>absf(normal[axis]):axis=1
		if absf(normal.z)>absf(normal[axis]):axis=2
		if normal[axis]<0:normal=-normal
		var plane:="%d:%d:%d:%d"%[roundi(normal.x*1000),roundi(normal.y*1000),roundi(normal.z*1000),roundi(normal.dot(a)*20)]
		var owner:=str(face.get("instance_path",""))+":"+str(face.get("offset",0))+":"+JSON.stringify(face.get("material_base",{}))
		if not planes.has(plane):planes[plane]={}
		var groups:Dictionary=planes[plane]
		if not groups.has(owner):groups[owner]={"area":0.0,"hint":int(face.get("sort_depth_hint_raw",0)),"forced":face.get("sort_hint_kind","")=="forced_forward_offset"}
		groups[owner].area+=cross.length()*0.5
		records.append([plane,owner])
	# Rank each source primitive once. Repeating a plane scan per triangle
	# becomes quadratic for large cities with thousands of coplanar tiles.
	for groups in planes.values():
		if groups.size()<2:continue
		var maximum_area:=0.0;var low:=INF;var high:=-INF
		for group in groups.values():
			maximum_area=maxf(maximum_area,group.area)
			if group.forced:low=minf(low,float(group.hint));high=maxf(high,float(group.hint))
		for current in groups.values():
			var area_layer:=clampf(log(maximum_area/maxf(0.0001,current.area))/log(2.0)/3.0,0,3)
			var layer:float=3.0*(high-float(current.hint))/(high-low) if current.forced and high>low else area_layer
			current["render_layer"]=1.0+clampf(layer,0,3)+area_layer*0.025
	var result:=PackedFloat32Array();result.resize(faces.size())
	for index in range(records.size()):
		result[index]=float(planes[records[index][0]][records[index][1]].get("render_layer",0.0))
	return result
