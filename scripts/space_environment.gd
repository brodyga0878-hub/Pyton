extends Node3D
# New authored orbital scenery. Visual asteroids do not add mining, damage or
# collision gameplay. Deterministic geometry; no alteration of saved world data.
const RockShader=preload("res://scripts/asteroid_surface.gdshader")
const BackdropShader=preload("res://scripts/space_backdrop.gdshader")
const VARIANTS:=8
var quality:=-1
var asteroid_count:=0
var anchor:=Vector3.ZERO
var seed_value:=7124901
var rocks:Array=[]
var sky:Sky
var _batches:Array=[]
var _last_observer:=Vector3(INF,INF,INF)

func _init()->void:
	sky=Sky.new();var material:=ShaderMaterial.new();material.shader=BackdropShader;sky.sky_material=material
func _height(direction:Vector3,variant:int)->Vector3:
	var phase:=float(variant)*1.731
	var radius:=1.0+0.14*sin(direction.x*5.2+phase)*cos(direction.z*4.3-phase)+0.1*sin(direction.y*7.3+direction.x*3.0+phase)+0.04*cos(direction.z*14.0+direction.y*8.0)
	var depression:=Vector3(sin(phase+0.4),cos(phase+1.2),sin(phase+2.6)).normalized()
	radius-=0.15*exp(-pow((direction-depression).length()*4.0,2.0))
	return direction*radius*Vector3(1.0+0.12*sin(phase),0.84+0.16*cos(phase),1.0+0.18*cos(phase+0.8))
func _point(latitude:int,longitude:int,latitudes:int,longitudes:int,variant:int)->Dictionary:
	var theta:=PI*float(latitude)/float(latitudes);var phi:=TAU*float(longitude)/float(longitudes)
	var direction:=Vector3(sin(theta)*cos(phi),cos(theta),sin(theta)*sin(phi))
	var vertex:=_height(direction,variant)
	var tangent:=direction.cross(Vector3.UP)
	if tangent.length_squared()<0.001:tangent=direction.cross(Vector3.RIGHT)
	tangent=tangent.normalized();var bitangent:=direction.cross(tangent).normalized()
	var normal:=(_height((direction+tangent*0.003).normalized(),variant)-vertex).cross(_height((direction+bitangent*0.003).normalized(),variant)-vertex).normalized()
	if normal.dot(direction)<0:normal=-normal
	return {"vertex":vertex,"normal":normal,"uv":Vector2(float(longitude)/longitudes,float(latitude)/latitudes)}
func _mesh(variant:int,detail:bool)->ArrayMesh:
	var latitudes:=16 if detail else 6;var longitudes:=28 if detail else 10
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for latitude in range(latitudes):
		for longitude in range(longitudes):
			var corners:Array=[_point(latitude,longitude,latitudes,longitudes,variant),_point(latitude+1,longitude,latitudes,longitudes,variant),_point(latitude+1,longitude+1,latitudes,longitudes,variant),_point(latitude,longitude+1,latitudes,longitudes,variant)]
			for i in [0,2,1,0,3,2]:
				var corner:Dictionary=corners[i];tool.set_normal(corner.normal);tool.set_uv(corner.uv);tool.add_vertex(corner.vertex)
	tool.generate_tangents();return tool.commit()
func configure(station_anchor:Vector3,value:=2,new_seed:=7124901)->void:
	value=clampi(value,0,2)
	if quality==value and anchor==station_anchor and seed_value==new_seed:return
	quality=value;anchor=station_anchor;seed_value=new_seed
	for child in get_children():remove_child(child);child.queue_free()
	rocks.clear();_batches.clear()
	var material:=ShaderMaterial.new();material.shader=RockShader
	for lod in range(2):
		for variant in range(VARIANTS):
			var visual:=MultiMeshInstance3D.new();visual.name="Asteroids_%d_%d"%[lod,variant]
			var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=_mesh(variant,lod==0);visual.multimesh=multi;visual.material_override=material
			visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual);_batches.append(visual)
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	asteroid_count=[92,176,272][quality]
	for i in range(asteroid_count):
		var theta:=rng.randf_range(0,TAU)
		var radius:=rng.randf_range(520,4800)
		var position_value:=anchor+Vector3(cos(theta)*radius,sin(theta)*radius*0.62,rng.randf_range(-3300,2300))
		var size_value:=rng.randf_range(18,105)
		if i%13==0:size_value=rng.randf_range(110,175)
		# A clean cylindrical approach corridor, including the complete rock bound.
		if Vector2(position_value.x-anchor.x,position_value.y-anchor.y).length()<size_value*1.7+230:
			position_value.x+=signf(position_value.x-anchor.x+0.01)*(size_value*1.7+350)
		# Preserve a clear scenic cone toward Earth's initial direction. This is
		# art composition around the authored training belt, not body ephemerides.
		position_value=_clear_planet_view(position_value,size_value)
		var rotation_value:=Basis.from_euler(Vector3(rng.randf_range(-PI,PI),rng.randf_range(-PI,PI),rng.randf_range(-PI,PI)))
		rocks.append({"variant":i%VARIANTS,"transform":Transform3D(rotation_value.scaled(Vector3.ONE*size_value),position_value),"radius":size_value,"colour":Color.from_hsv(rng.randf_range(0.50,0.62),rng.randf_range(0.02,0.13),rng.randf_range(0.76,1.12))})
	# Nearer silhouettes frame the route without obstructing its open centre.
	for row in [{"p":Vector3(-650,210,1700),"r":210.0,"v":2},{"p":Vector3(1180,480,950),"r":180.0,"v":5},{"p":Vector3(-470,-420,1100),"r":135.0,"v":1}]:
		rocks.append({"variant":row.v,"transform":Transform3D(Basis.from_euler(Vector3(0.4,0.8,0.2)).scaled(Vector3.ONE*row.r),anchor+row.p),"radius":row.r,"colour":Color("ccd0d0")})
	asteroid_count=rocks.size();_last_observer=Vector3(INF,INF,INF);update_view(Vector3.ZERO)
func _clear_planet_view(position_value:Vector3,radius:float)->Vector3:
	var distance:=position_value.length()
	if distance<=1:return position_value
	var planet_direction:=Vector3(0.48,-0.28,-1.0).normalized()
	var extent:=asin(clampf(radius*1.7/distance,0,0.95))
	if acos(clampf(position_value.normalized().dot(planet_direction),-1,1))<0.34+extent:
		position_value.x=-absf(position_value.x)-radius*2.0
	return position_value
func update_view(observer:Vector3)->void:
	if _batches.is_empty():return
	if _last_observer.is_finite() and observer.distance_squared_to(_last_observer)<1600:return
	_last_observer=observer
	var groups:Array=[]
	for index in range(VARIANTS*2):groups.append([])
	for rock in rocks:
		var distance:float=observer.distance_to(rock.transform.origin)
		if distance>14500:continue
		var lod:=0 if quality>0 and distance<2200 else 1
		groups[lod*VARIANTS+int(rock.variant)].append(rock)
	for index in range(_batches.size()):
		var batch:MultiMeshInstance3D=_batches[index];var group:Array=groups[index]
		batch.multimesh.instance_count=group.size();batch.visible=not group.is_empty()
		for i in range(group.size()):batch.multimesh.set_instance_transform(i,group[i].transform);batch.multimesh.set_instance_color(i,group[i].colour)
