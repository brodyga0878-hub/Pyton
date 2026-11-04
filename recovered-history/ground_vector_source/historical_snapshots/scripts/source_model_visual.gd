extends Node3D
# Modern rendering of compiled source geometry. No assembler/CPU interpreter runs.
# Raw source model execution and geographic placement have separate contracts.
const Units=preload("res://scripts/source_units.gd")
var triangle_count:=0
var source_model_index:=-1
var unresolved_texture_indices:Array=[]
var retained_event_kinds:Dictionary={}
var local_bounds:=AABB()

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

func configure(compiled:Dictionary)->bool:
	if not compiled.get("ok",false):return false
	for child in get_children():remove_child(child);child.queue_free()
	triangle_count=0;source_model_index=int(compiled.model_index)
	unresolved_texture_indices.clear();retained_event_kinds.clear()
	var batches:Dictionary={false:{"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colours":PackedColorArray()},true:{"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colours":PackedColorArray()}}
	var first:=true
	for face in compiled.triangles_raw:
		var vertices:Array[Vector3]=[]
		for point in face.vertices:vertices.append(Units.city_point(point))
		var normal:Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
		if face.has("normal_raw"):
			var declared:=Units.city_direction(face.normal_raw)
			if declared.length_squared()>0:normal=declared
		var appearance:=face_material(face)
		if appearance.texture>=0 and not appearance.texture in unresolved_texture_indices:unresolved_texture_indices.append(appearance.texture)
		var batch:Dictionary=batches[appearance.unlit]
		for point in vertices:
			batch.vertices.append(point);batch.normals.append(normal);batch.colours.append(appearance.colour)
			if first:local_bounds=AABB(point,Vector3.ZERO);first=false
			else:local_bounds=local_bounds.expand(point)
		triangle_count+=1
	for unlit in batches:
		var batch:Dictionary=batches[unlit]
		if batch.vertices.is_empty():continue
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=batch.vertices;arrays[Mesh.ARRAY_NORMAL]=batch.normals;arrays[Mesh.ARRAY_COLOR]=batch.colours
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var visual:=MeshInstance3D.new();visual.name="SourceUnlit" if unlit else "SourceLit";visual.mesh=mesh
		var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.roughness=0.66;material.metallic=0.14
		if unlit:material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		visual.material_override=material;add_child(visual)
	for event in compiled.source_events:
		var kind:String=str(event.kind)
		retained_event_kinds[kind]=int(retained_event_kinds.get(kind,0))+1
		if kind=="ball" and int(event.radius_raw)>0:
			var sphere:=SphereMesh.new();sphere.radius=Units.metres(float(event.radius_raw));sphere.height=sphere.radius*2
			sphere.radial_segments=32;sphere.rings=16
			var visual:=MeshInstance3D.new();visual.mesh=sphere;visual.position=Units.city_point(event.center_raw)
			var material:=StandardMaterial3D.new();var appearance:=face_material(event)
			material.albedo_color=appearance.colour;material.roughness=0.5;material.metallic=0.1
			if appearance.unlit:material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			visual.material_override=material;add_child(visual)
	return triangle_count>0
