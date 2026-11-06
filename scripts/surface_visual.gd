extends Node3D
const TransitionShader=preload("res://scripts/terrain_transition.gdshader")
const TerrainShader=preload("res://scripts/terrain.gdshader")
const PadShader=preload("res://scripts/landing_pad.gdshader")
const BuildingShader=preload("res://scripts/building.gdshader")
const Materials=preload("res://scripts/material_library.gd")
const WorldMaterials=preload("res://scripts/world_surface_library.gd")
const SourceTerrain=preload("res://scripts/source_surface_terrain.gd")
const SourcePacket=preload("res://scripts/source_surface_render_packet.gd")
const SourceState=preload("res://scripts/source_surface_render_state.gd")
const SourceTerrainShader=preload("res://scripts/source_terrain_packet.gdshader")
const SourceTransitionShader=preload("res://scripts/source_terrain_packet_transition.gdshader")
const SOURCE_STREAM_DISTANCE:=512.0
const SOURCE_REGION_DISTANCE:=8000.0
var _source_owner:RefCounted
var _source_key:=""
var _source_base:Node3D
var _source_core:Node3D
var _source_base_state:RefCounted
var _source_core_state:RefCounted
var _source_region:Dictionary={}
var _source_core_offset:=Vector2.ZERO
var _source_nodes:Array[MeshInstance3D]=[]
var _source_worker:Thread
var _source_far_worker:Thread
var _source_job_key:=""
var _source_packet:Dictionary={}
var _source_material:ShaderMaterial
var _source_core_material:ShaderMaterial
var _source_context:RefCounted
var _source_jobs_started:=0
var _source_jobs_finished:=0
var _source_publish_usec:=0
var _source_far_started:=0
var _source_far_finished:=0
var _source_far_job_usec:=0
var _source_far_duration:=1.0
var _source_last_error:=""
var _source_last_core_usec:=0
var _source_last_core_queries:=0
var _source_last_core_evictions:=0
var _source_generation:=0
class SourcePatchContext extends RefCounted:
	var revision:=SourceTerrain.REVISION_NAME
	var source_record:=PackedByteArray()
	var source_policy:Dictionary={}
	var latitude:=0.0
	var longitude:=0.0
	var radius:=0.0
	var extent:=0.0
	func maximum_patch_extent()->float:return extent
var quality:=2
var view_coverage:=1.0
var world_material_kind:="rock"
func set_quality(value:int)->void:
	quality=clampi(value,0,2)
	if _source_base!=null:
		for node:MeshInstance3D in _source_nodes:
			if is_instance_valid(node) and node.material_override is ShaderMaterial:
				node.material_override.set_shader_parameter("detail_level",quality);_bind_ground_material(node.material_override)
		return
	for child in get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			if child.material_override.shader in [TerrainShader,TransitionShader,BuildingShader,PadShader]:
				child.material_override.set_shader_parameter("detail_level",quality)
				if child.material_override.shader in [TerrainShader,TransitionShader]:_bind_ground_material(child.material_override)

func _bind_ground_material(material:ShaderMaterial)->void:
	if quality==0:WorldMaterials.clear_material(material);return
	var scale:=0.03125 if world_material_kind=="ice" else 0.0625
	if not WorldMaterials.bind_shader(material,world_material_kind,scale):
		material.set_shader_parameter("detail_level",0)
		push_error("World surface material could not be loaded: "+world_material_kind)


func configure(surface: RefCounted) -> void:
	if surface.get("globe")!=null and str(surface.globe.get("revision"))==SourceTerrain.REVISION_NAME:
		_configure_source(surface);return
	if not _source_key.is_empty():
		_source_key="";_source_owner=null;_source_base=null;_source_core=null;_source_base_state=null;_source_core_state=null;_source_context=null;_source_region={};_source_nodes.clear()
	var current_site:String=str(surface.get("site_name")) if surface.get("site_name")!=null else ""
	var cache_key:String=surface.terrain_key() if surface.has_method("terrain_key") else str(surface.seed_value)+":"+str(surface.kind)+":"+current_site
	if get_meta("terrain_key","")==cache_key and get_child_count()>0:return
	for child in get_children():remove_child(child);child.queue_free()
	set_meta("terrain_key",cache_key)
	world_material_kind=WorldMaterials.canonical_kind(str(surface.kind))
	var base: Color={"earth":Color("426b51"),"ice":Color("a5c5cf"),"desert":Color("aa714d"),"rock":Color("737984")}.get(surface.kind,Color("737984"))
	var count:int=surface.grid_cells() if surface.has_method("grid_cells") else surface.GRID_CELLS
	var width: float=surface.GRID_WIDTH
	var uvs:=PackedVector2Array();var uv2s:=PackedVector2Array()
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	var spherical:bool=surface.get("globe")!=null
	set_meta("material_spherical",spherical)
	set_meta("material_kind",int({"earth":0,"rock":1,"desert":2,"ice":3}.get(surface.kind,1)))
	var heights:=PackedFloat64Array()
	var samples:Array[PackedFloat64Array]=[]
	var cell:=width/count
	if spherical:
		heights.resize((count+3)*(count+3));samples.resize(heights.size())
		for z in range(count+3):
			for x in range(count+3):
				var sampled:PackedFloat64Array=surface.globe.sample(-width/2+(x-1)*cell,-width/2+(z-1)*cell)
				samples[z*(count+3)+x]=sampled;heights[z*(count+3)+x]=sampled[0]
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
				var sampled:PackedFloat64Array=samples[(z+1)*(count+3)+x+1]
				uvs.append(Vector2(sampled[2],sampled[3]));uv2s.append(Vector2(sampled[4],0))
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
	_bind_ground_material(mat)
	if spherical:
		var origin_sample:PackedFloat64Array=surface.globe.sample(0,0)
		# Exactly an integer number of every texture tile; adjacent terrain rings
		# share this material and streaming rebases preserve body-fixed phase.
		mat.set_shader_parameter("material_origin",Vector3(floor(origin_sample[2]/1024.0)*1024.0,floor(origin_sample[3]/1024.0)*1024.0,floor(origin_sample[4]/1024.0)*1024.0))
	terrain.material_override=mat
	terrain.set_meta("terrain_layer",true)
	add_child(terrain)
	if spherical:
		var inner:=width*0.5
		var maximum:float=surface.globe.maximum_patch_extent() if surface.globe.has_method("maximum_patch_extent") else INF
		for outer in [8000.0,32000.0,128000.0]:
			var bound:=minf(float(outer),maximum)
			if bound<=inner:break
			var ring:=_far_ring(surface,inner,bound,mat,base);ring.set_meta("terrain_layer",true);add_child(ring);inner=bound
		if surface.get("extended_flight")==true:
			var outer:float=minf(maximum,minf(512000.0,float(surface.globe.radius)*0.7))
			if outer>inner:
				var ring:=_far_ring(surface,inner,outer,mat,base);ring.set_meta("terrain_layer",true);add_child(ring)
	var landing_point:Vector3=surface.pad_position() if surface.has_method("pad_position") else Vector3.ZERO
	if spherical and Vector2(landing_point.x,landing_point.z).length()>width*0.45:return
	# Source3 cities already contain their original pad geometry and buildings.
	if spherical and surface.source_city() and not surface.city_data.is_empty():
		var label:=Label3D.new();label.text=surface.site_name.to_upper();label.font_size=64;label.pixel_size=0.08
		label.position=landing_point+Vector3(0,22,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		return
	var pad:=MeshInstance3D.new()
	var box:=BoxMesh.new();box.size=Vector3(100,0.3,100)
	pad.mesh=box;pad.position=landing_point+Vector3(0,0.2,0)
	var pm:=ShaderMaterial.new();pm.shader=PadShader
	Materials.apply_shader(pm,"asphalt",0.25)
	pm.set_shader_parameter("detail_level",quality)
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
			Materials.apply_shader(wall,"concrete",0.16)
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
				var sampled:PackedFloat64Array=surface.globe.sample(p.x,p.y)
				var angle:=p.length()/float(surface.globe.radius)
				var direction:=p.normalized()*sin(angle)
				vertices.append(Vector3(p.x,sampled[0],p.y));normals.append(Vector3(direction.x,cos(angle),direction.y).normalized())
				var shade:float=clampf(sampled[1]/400.0,-0.2,0.3)
				if surface.get("extended_flight")==true:shade*=1.0-smoothstep(4000.0,24000.0,p.length())
				colors.append(base.lightened(shade))
				uv.append(Vector2(sampled[2],sampled[3]));uv2.append(Vector2(sampled[4],0))
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

func set_view_coverage(value:float)->void:
	view_coverage=clampf(value,0,1)
	if _source_base!=null:
		for node:MeshInstance3D in _source_nodes:
			if is_instance_valid(node):_source_coverage(node.material_override)
		_source_update_clip()
		return
	for child in get_children():
		if child.get_meta("terrain_layer",false):
			var target:Shader=TerrainShader if view_coverage>=1.0 else TransitionShader
			if child.material_override.shader!=target:
				child.material_override.shader=target
				child.material_override.set_shader_parameter("detail_level",quality)
				child.material_override.set_shader_parameter("spherical_coordinates",bool(get_meta("material_spherical",false)))
				child.material_override.set_shader_parameter("surface_kind",int(get_meta("material_kind",1)))
				_bind_ground_material(child.material_override)
				child.material_override.set_shader_parameter("view_coverage",view_coverage)
				child.material_override.set_shader_parameter("coverage_invert",true)
		else:child.visible=view_coverage>=0.5

func _exit_tree()->void:finish_source_preparation()
func finish_source_preparation()->void:
	if _source_worker!=null:_source_worker.wait_to_finish();_source_worker=null
	if _source_far_worker!=null:_source_far_worker.wait_to_finish();_source_far_worker=null
func source_ground_patch_context()->RefCounted:return _source_context
func source_stream_stats()->Dictionary:
	return {"jobs_started":_source_jobs_started,"jobs_finished":_source_jobs_finished,"pending_jobs":(1 if _source_worker!=null else 0)+(1 if _source_far_worker!=null else 0),"pending_core_jobs":1 if _source_worker!=null else 0,"pending_far_jobs":1 if _source_far_worker!=null else 0,"far_jobs_started":_source_far_started,"far_jobs_finished":_source_far_finished,"last_publication_usec":_source_publish_usec,"last_core_duration_usec":_source_last_core_usec,"last_core_queries":_source_last_core_queries,"last_core_evictions":_source_last_core_evictions,"last_error":_source_last_error,"core_offset":_source_core_offset,"has_geometry":_source_base!=null}
func _source_coverage(material:ShaderMaterial)->void:
	var target:Shader=SourceTerrainShader if view_coverage>=1.0 else SourceTransitionShader
	if material.shader!=target:
		material.shader=target
		material.set_shader_parameter("detail_level",quality);material.set_shader_parameter("spherical_coordinates",true)
		material.set_shader_parameter("surface_kind",int(get_meta("material_kind",1)));_bind_ground_material(material)
		material.set_shader_parameter("material_origin",_source_packet.get("material_origin",Vector3.ZERO))
	material.set_shader_parameter("view_coverage",view_coverage);material.set_shader_parameter("coverage_invert",true)
func _source_mesh(data:Dictionary,material:ShaderMaterial=null)->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_COLOR]=data.colors
	arrays[Mesh.ARRAY_TEX_UV]=data.uv;arrays[Mesh.ARRAY_TEX_UV2]=data.uv2;arrays[Mesh.ARRAY_INDEX]=data.indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name=str(data.name);node.mesh=mesh;node.material_override=_source_material if material==null else material;node.set_meta("terrain_layer",true)
	_source_nodes.append(node);return node
func _source_publish(packet:Dictionary,worker_state:Dictionary,full:bool)->bool:
	var started:=Time.get_ticks_usec()
	var state:=SourceState.new()
	if not state.configure(packet):return false
	if full:
		for child in get_children():remove_child(child);child.queue_free()
		_source_nodes.clear();_source_core=null
		_source_base=Node3D.new();_source_base.name="SourceBodyFixedTerrain";add_child(_source_base)
		_source_packet=packet;_source_base_state=state
		_source_far_duration=maxf(0.1,float(packet.get("duration_usec",1000000))/1000000.0)
		_source_material=ShaderMaterial.new();_source_material.shader=SourceTerrainShader
		_source_material.set_shader_parameter("detail_level",quality);_source_material.set_shader_parameter("spherical_coordinates",true)
		_source_material.set_shader_parameter("surface_kind",int(get_meta("material_kind",1)));_source_material.set_shader_parameter("material_origin",packet.material_origin)
		_bind_ground_material(_source_material);_source_coverage(_source_material)
		for data:Dictionary in packet.meshes:_source_base.add_child(_source_mesh(data))
		var context:=SourcePatchContext.new();context.source_record=worker_state.source_record.duplicate();context.source_policy=worker_state.source_policy.duplicate(true)
		context.latitude=float(packet.frame.latitude);context.longitude=float(packet.frame.longitude);context.radius=float(packet.frame.radius);context.extent=float(packet.meshes[-1].outer)
		_source_context=context
	else:
		if _source_core!=null:
			for old in _source_core.get_children():_source_nodes.erase(old)
			remove_child(_source_core);_source_core.queue_free()
		_source_core=Node3D.new();_source_core.name="SourceStreamedCore";add_child(_source_core)
		_source_core_material=_source_material.duplicate();_source_core_material.set_shader_parameter("source_clip_core",false)
		_source_core.add_child(_source_mesh(packet.meshes[0],_source_core_material))
	_source_core_state=state;_source_region=worker_state;_source_core_offset=packet.get("core_offset",Vector2.ZERO)
	_source_owner.publish_source_render_state(state)
	_source_publish_usec=Time.get_ticks_usec()-started
	return true
func _source_publish_far(packet:Dictionary,worker_state:Dictionary)->bool:
	var started:=Time.get_ticks_usec()
	var state:=SourceState.new()
	if not state.configure(packet):return false
	if _source_base!=null:
		for old in _source_base.get_children():_source_nodes.erase(old)
		remove_child(_source_base);_source_base.queue_free()
	_source_base=Node3D.new();_source_base.name="SourceBodyFixedTerrain";add_child(_source_base)
	_source_base_state=state;_source_packet=packet
	_source_material=ShaderMaterial.new();_source_material.shader=SourceTerrainShader
	_source_material.set_shader_parameter("detail_level",quality);_source_material.set_shader_parameter("spherical_coordinates",true)
	_source_material.set_shader_parameter("surface_kind",int(get_meta("material_kind",1)));_source_material.set_shader_parameter("material_origin",packet.material_origin)
	_bind_ground_material(_source_material);_source_coverage(_source_material)
	for data:Dictionary in packet.meshes:_source_base.add_child(_source_mesh(data))
	var context:=SourcePatchContext.new();context.source_record=worker_state.source_record.duplicate();context.source_policy=worker_state.source_policy.duplicate(true)
	context.latitude=float(packet.frame.latitude);context.longitude=float(packet.frame.longitude);context.radius=float(packet.frame.radius);context.extent=float(packet.meshes[-1].outer)
	_source_context=context;_source_update_clip();_source_publish_usec=Time.get_ticks_usec()-started
	# A finished far job already contains an exact warm core in its predicted
	# frame. Adopt it when it covers the live ship, avoiding a cold reanchor.
	var local:Vector3=state.transform_to(_source_owner.globe).affine_inverse()*Vector3(_source_owner.render_position)
	if maxf(absf(local.x-float(state.core_offset.x)),absf(local.z-float(state.core_offset.y)))<float(state.core_width)*0.5-SOURCE_STREAM_DISTANCE:
		_source_generation+=1
		_source_publish(packet,worker_state,false)
	return true
func _source_update_clip()->void:
	if _source_material==null:return
	var enabled:=_source_core!=null and _source_core_state!=null and _source_base_state!=null
	_source_material.set_shader_parameter("source_clip_core",enabled)
	if not enabled:return
	var core_from_base:Transform3D=_source_core_state.transform_to(_source_owner.globe).affine_inverse()*_source_base_state.transform_to(_source_owner.globe)
	_source_material.set_shader_parameter("source_core_from_packet_basis",core_from_base.basis)
	_source_material.set_shader_parameter("source_core_from_packet_origin",core_from_base.origin)
	_source_material.set_shader_parameter("source_core_center",_source_core_state.core_offset)
	_source_material.set_shader_parameter("source_core_half_width",float(_source_core_state.core_width)*0.5)
static func _prepare_source_job(snapshot:Dictionary,options:Dictionary,key:String,full:bool)->Dictionary:
	var terrain:=SourceTerrain.from_worker_state(snapshot)
	if terrain==null:return {"ok":false,"key":key}
	var prepared_options:=options.duplicate()
	if not prepared_options.has("core_width") and terrain.source_model_index==117:prepared_options.core_width=8000.0
	if not prepared_options.has("core_cells") and terrain.source_model_index==117:prepared_options.core_cells=32
	var packet:=SourcePacket.prepare(terrain,prepared_options)
	return {"ok":packet.get("ok",false),"key":key,"packet":packet,"state":terrain.capture_worker_state(),"full":full,"generation":int(options.get("generation",0))}
func _source_poll()->void:
	if _source_worker!=null and not _source_worker.is_alive():
		var result:Variant=_source_worker.wait_to_finish();_source_worker=null;_source_jobs_finished+=1
		if result is Dictionary and result.get("key")==_source_key:
			_source_last_error=str(result.get("packet",{}).get("error",""));_source_last_core_usec=int(result.get("packet",{}).get("duration_usec",0))
			_source_last_core_queries=int(result.get("packet",{}).get("source_query_count",0))
			_source_last_core_evictions=int(result.get("packet",{}).get("cache_stats_after",{}).get("evictions",0))-int(result.get("packet",{}).get("cache_stats_before",{}).get("evictions",0))
			if result.get("ok",false) and int(result.get("generation",-1))==_source_generation and _source_owner!=null and _source_owner.globe!=null:_source_publish(result.packet,result.state,bool(result.full))
	if _source_far_worker!=null and not _source_far_worker.is_alive():
		var result:Variant=_source_far_worker.wait_to_finish();_source_far_worker=null;_source_far_finished+=1
		if result is Dictionary and result.get("ok",false) and result.get("key")==_source_key and _source_owner!=null and _source_owner.globe!=null:
			_source_far_duration=maxf(0.1,float(Time.get_ticks_usec()-_source_far_job_usec)/1000000.0)
			_source_publish_far(result.packet,result.state)
func _source_request(snapshot:Dictionary,options:Dictionary,full:bool)->void:
	if _source_worker!=null:return
	options=options.duplicate();options.generation=_source_generation
	_source_worker=Thread.new();_source_job_key=_source_key;_source_jobs_started+=1
	if _source_worker.start(_prepare_source_job.bind(snapshot,options,_source_key,full))!=OK:_source_worker=null
func _source_request_far(surface:RefCounted)->void:
	if _source_far_worker!=null or _source_context==null:return
	var ll:Array=surface.globe.coordinates_at_height(surface.render_position.x,surface.render_position.z,surface.render_position.y)
	var direction:=Vector3(cos(ll[0])*cos(ll[1]),sin(ll[0]),-cos(ll[0])*sin(ll[1]))
	var bound:=maxf(float(_source_context.radius),float(_source_context.source_policy.get("original_outer_bound_raw",0))*16785.0/16777216.0)
	var angle:=asin(clampf(float(_source_context.extent)*0.9/bound,0.0,1.0))
	var delta:=pow(sin((float(ll[0])-float(_source_context.latitude))*0.5),2)+cos(float(ll[0]))*cos(float(_source_context.latitude))*pow(sin((float(ll[1])-float(_source_context.longitude))*0.5),2)
	if 2.0*asin(sqrt(clampf(delta,0.0,1.0)))<angle*0.2:return
	var future:Vector3=surface.render_position+Vector3(surface.render_velocity)*clampf(_source_far_duration,1.0,12.0)
	var predicted:Array=surface.globe.coordinates_at_height(future.x,future.z,future.y)
	var predicted_direction:=Vector3(cos(predicted[0])*cos(predicted[1]),sin(predicted[0]),-cos(predicted[0])*sin(predicted[1]))
	var ahead:=acos(clampf(direction.dot(predicted_direction),-1.0,1.0))
	if ahead>angle*0.8:predicted_direction=direction.slerp(predicted_direction,angle*0.8/ahead).normalized()
	var snapshot:=_source_region.duplicate(false)
	snapshot.latitude=atan2(float(predicted_direction.y),sqrt(float(predicted_direction.x)*predicted_direction.x+float(predicted_direction.z)*predicted_direction.z));snapshot.longitude=atan2(-float(predicted_direction.z),float(predicted_direction.x))
	_source_far_worker=Thread.new();_source_far_started+=1;_source_far_job_usec=Time.get_ticks_usec()
	if _source_far_worker.start(_prepare_source_job.bind(snapshot,{"kind":world_material_kind,"extended_flight":bool(surface.extended_flight)},_source_key,true))!=OK:_source_far_worker=null
func _configure_source(surface:RefCounted)->void:
	var key:=str(surface.get_instance_id())+":"+str(surface.globe.get_instance_id())
	if key!=_source_key:
		for child in get_children():remove_child(child);child.queue_free()
		_source_nodes.clear();_source_base=null;_source_core=null;_source_base_state=null;_source_core_state=null;_source_context=null;_source_region={}
		_source_key=key;_source_owner=surface
		world_material_kind=WorldMaterials.canonical_kind(str(surface.kind));set_meta("material_kind",int({"earth":0,"rock":1,"desert":2,"ice":3}.get(surface.kind,1)));set_meta("material_spherical",true)
		if not surface.source_render_packet.is_empty() and not surface.source_render_worker_state.is_empty():_source_publish(surface.source_render_packet,surface.source_render_worker_state,true)
	_source_poll()
	if _source_base==null:
		_source_request(surface.globe.capture_worker_state(),{"kind":world_material_kind,"extended_flight":bool(surface.extended_flight)},true);return
	if _source_base_state.matches(surface.globe):_source_base.transform=_source_base_state.transform_to(surface.globe)
	if _source_core!=null and _source_core_state.matches(surface.globe):_source_core.transform=_source_core_state.transform_to(surface.globe)
	_source_update_clip()
	_source_request_far(surface)
	if not _source_core_state.matches(surface.globe) or _source_worker!=null:return
	var regional:Vector3=_source_core_state.transform_to(surface.globe).affine_inverse()*Vector3(surface.render_position)
	var target:=Vector2(regional.x,regional.z)
	if target.distance_to(_source_core_offset)<SOURCE_STREAM_DISTANCE:return
	var snapshot:=_source_region.duplicate(false)
	var cell:=float(_source_packet.core_width)/int(_source_packet.core_cells)
	target=Vector2(roundf(target.x/cell)*cell,roundf(target.y/cell)*cell)
	if target.length()>SOURCE_REGION_DISTANCE:
		snapshot.latitude=float(surface.globe.latitude);snapshot.longitude=float(surface.globe.longitude);target=Vector2.ZERO
	_source_request(snapshot,{"kind":world_material_kind,"include_rings":false,"core_offset":target,"core_cells":int(_source_packet.core_cells),"core_width":float(_source_packet.core_width)},false)
