extends Node3D
# New visual reconstruction for the three adapted flight profiles, not FFE hull geometry.
func configure(profile:Dictionary)->void:
	for child in get_children():remove_child(child);child.queue_free()
	var span:=float(profile.get("visual_span_m",42.0))
	var id:=str(profile.get("id","cobra"))
	var width:=span*0.5;var length:=span*0.65
	var points:Array[Vector3]=[Vector3(0,0,-length),Vector3(-width,0,length*0.4),Vector3(width,0,length*0.4),Vector3(0,span*0.13,0),Vector3(0,-span*0.08,length*0.1),Vector3(-width*0.35,0,length),Vector3(width*0.35,0,length)]
	if id=="shuttle":points[1].x*=0.65;points[2].x*=0.65;points[3].y*=1.6
	if id=="eagle":points[1].z=-length*0.05;points[2].z=-length*0.05
	var faces:Array=[[0,1,3],[0,3,2],[0,4,1],[0,2,4],[1,5,3],[2,3,6],[3,5,6],[1,4,5],[2,6,4],[4,6,5]]
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
	for face in faces:
		var a:Vector3=points[face[0]];var b:Vector3=points[face[1]];var c:Vector3=points[face[2]]
		var normal:Vector3=(b-a).cross(c-a).normalized()
		for p in [a,b,c]:vertices.append(p);normals.append(normal)
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var hull:=MeshInstance3D.new();hull.mesh=mesh
	var material:=StandardMaterial3D.new();material.albedo_color=Color("8aabbc") if id!="eagle" else Color("b5ac8c")
	material.metallic=0.55;material.roughness=0.32;material.cull_mode=BaseMaterial3D.CULL_DISABLED;hull.material_override=material;add_child(hull)
	for x in [-span*0.2,span*0.2]:
		var engine:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=span*0.045;sphere.height=sphere.radius*2;engine.mesh=sphere
		engine.position=Vector3(x,0,length*0.83)
		var glow:=StandardMaterial3D.new();glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glow.albedo_color=Color("65dcff");engine.material_override=glow;add_child(engine)
