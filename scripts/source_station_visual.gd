extends Node3D
# Authored PBR finish on original station72/73/80 triangles. Model axes and
# colours are preserved; no replacement torus/cube station is constructed.
const Geometry=preload("res://scripts/source_station_geometry.gd")
const SourceAppearance=preload("res://scripts/source_model_visual.gd")
const Units=preload("res://scripts/source_units.gd")
const Materials=preload("res://scripts/material_library.gd")
const Finish=preload("res://scripts/station_visual.gd")
var quality:=2
var geometry:Dictionary={}
var triangle_count:=0
var model_index:=-1
var local_bounds:=AABB()
var retained_event_kinds:Dictionary={}
var unresolved_texture_indices:Array=[]
var _mesh_nodes:Array=[]
var _ball_nodes:Array=[]

func _material(unlit:bool)->StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.metallic=0.65;material.roughness=0.42
	if quality>0:
		Materials.apply_standard(material,"painted_alloy",1.0/16.0)
		material.albedo_texture=Finish.finish_texture("albedo");material.normal_texture=Finish.finish_texture("normal")
		var orm:Texture2D=Finish.finish_texture("orm");material.ao_texture=orm;material.roughness_texture=orm;material.metallic_texture=orm
		material.normal_scale=0.5 if quality>1 else 0.28
	if unlit:material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.normal_enabled=false
	return material

func _gain()->float:
	return 1.0/maxf(float(Finish.finish_metadata().get("mean_linear_luminance",0.6)),0.01) if quality>0 else 1.0

func set_quality(value:int)->void:
	value=clampi(value,0,2)
	if value==quality:return
	quality=value
	for entry in _mesh_nodes:
		if is_instance_valid(entry.node):entry.node.material_override=_material(entry.unlit)
	for entry in _ball_nodes:
		if is_instance_valid(entry.node):_ball_material(entry)
	if not geometry.is_empty():_rebuild_colours()

func configure_site(site:Dictionary,door_u16:Variant=0)->bool:
	var candidate:=Geometry.prepare_site(site,door_u16)
	return configure(candidate)

func configure(candidate:Dictionary)->bool:
	if not candidate.get("ok",false) or candidate.get("revision")!=Geometry.REVISION:return false
	var compiled:Dictionary=candidate.get("compiled",{})
	if not compiled.get("ok",false) or not compiled.get("triangles_raw") is Array or compiled.triangles_raw.is_empty():return false
	for child in get_children():remove_child(child);child.queue_free()
	geometry=candidate;model_index=int(candidate.model_index);triangle_count=compiled.triangles_raw.size();local_bounds=candidate.bounds
	retained_event_kinds.clear();unresolved_texture_indices.clear();_mesh_nodes.clear();_ball_nodes.clear()
	var batches:Dictionary={false:{"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colours":PackedColorArray(),"source_colours":[]},true:{"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colours":PackedColorArray(),"source_colours":[]}}
	var gain:=_gain()
	for face:Dictionary in compiled.triangles_raw:
		var vertices:Array[Vector3]=[]
		for point:Array in face.vertices:vertices.append(Vector3(Units.metres(float(point[0])),Units.metres(float(point[1])),Units.metres(float(point[2]))))
		var normal:Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
		if face.has("normal_raw"):
			var declared:=Vector3(float(face.normal_raw[0]),float(face.normal_raw[1]),float(face.normal_raw[2])).normalized()
			if declared.length_squared()>0:normal=declared
		var appearance:=SourceAppearance.face_material(face)
		if appearance.texture>=0 and not appearance.texture in unresolved_texture_indices:unresolved_texture_indices.append(appearance.texture)
		var colour:Color=(appearance.colour.srgb_to_linear()*gain).linear_to_srgb()
		var batch:Dictionary=batches[appearance.unlit]
		for point:Vector3 in vertices:
			batch.vertices.append(point);batch.normals.append(normal);batch.colours.append(colour);batch.source_colours.append(appearance.colour)
	for unlit:bool in batches:
		var batch:Dictionary=batches[unlit]
		if batch.vertices.is_empty():continue
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=batch.vertices;arrays[Mesh.ARRAY_NORMAL]=batch.normals;arrays[Mesh.ARRAY_COLOR]=batch.colours
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var node:=MeshInstance3D.new();node.name="SourceStationUnlit" if unlit else "SourceStationLit";node.mesh=mesh;node.material_override=_material(unlit)
		add_child(node);_mesh_nodes.append({"node":node,"unlit":unlit,"source_colours":batch.source_colours})
	for event:Dictionary in compiled.source_events:
		var kind:String=str(event.kind);retained_event_kinds[kind]=int(retained_event_kinds.get(kind,0))+1
		if kind=="ball" and int(event.get("radius_raw",0))>0:
			var sphere:=SphereMesh.new();sphere.radius=Units.metres(float(event.radius_raw));sphere.height=sphere.radius*2.0;sphere.radial_segments=24;sphere.rings=12
			var node:=MeshInstance3D.new();node.mesh=sphere
			var raw:Array=event.center_raw;node.position=Vector3(Units.metres(float(raw[0])),Units.metres(float(raw[1])),Units.metres(float(raw[2])))
			var appearance:=SourceAppearance.face_material(event)
			var entry:={"node":node,"unlit":bool(appearance.unlit),"colour":appearance.colour}
			_ball_material(entry);add_child(node);_ball_nodes.append(entry)
	return true

func _ball_material(entry:Dictionary)->void:
	var material:=_material(entry.unlit);material.vertex_color_use_as_albedo=false
	material.albedo_color=(entry.colour.srgb_to_linear()*_gain()).linear_to_srgb();entry.node.material_override=material

func _rebuild_colours()->void:
	var gain:=_gain()
	for entry in _mesh_nodes:
		if not is_instance_valid(entry.node):continue
		var mesh:ArrayMesh=entry.node.mesh;var arrays:Array=mesh.surface_get_arrays(0);var colours:=PackedColorArray()
		for colour:Color in entry.source_colours:colours.append((colour.srgb_to_linear()*gain).linear_to_srgb())
		arrays[Mesh.ARRAY_COLOR]=colours
		var replacement:=ArrayMesh.new();replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);entry.node.mesh=replacement
