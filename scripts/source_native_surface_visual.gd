extends Node3D
# Explicit native-surface trial rendering. Vertices/indices are copied
# literally from every emitted verified leaf; this node owns no flight camera,
# physical provider, source clock, contact classification or response.
const Provider=preload("res://scripts/source_native_surface_provider.gd")
const WorldMaterials=preload("res://scripts/world_surface_library.gd")
const CONTRACT:="source-native-literal-leaf-surface-visual-v1"
const PALETTE:={"earth":Color("426b51"),"rock":Color("737984"),"desert":Color("aa714d"),"ice":Color("a5c5cf")}
const WITNESS_COLOURS:=[Color("74d9ef"),Color("ecc276"),Color("8fe3b0")]
var last_error:=""
var _kind:="rock"
var _quality:=2
var _witnesses_visible:=true
var _mesh_root:Node3D
var _terrain:MeshInstance3D
var _material:StandardMaterial3D
var _geometry:Dictionary={}
var _payload:Dictionary={}
var _publication_count:=0
var _rejected_publication_count:=0
var _clear_count:=0
var _last_clear_reason:=""

static func _failure(reason:String)->Dictionary:return {"ok":false,"reason":reason}
static func _integer(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _sha(bytes:PackedByteArray)->String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(bytes);return digest.finish().hex_encode()
static func _hex(value:Variant)->bool:
	if not value is String or value.length()!=64:return false
	for character:String in value:
		if not "0123456789abcdef".contains(character):return false
	return true
static func _vertex_bytes(vertices:PackedVector3Array)->PackedByteArray:
	var result:=PackedByteArray();result.resize(vertices.size()*12)
	for corner in range(vertices.size()):
		for axis in range(3):result.encode_float(corner*12+axis*4,vertices[corner][axis])
	return result
static func _index_bytes(indices:PackedInt32Array)->PackedByteArray:
	var result:=PackedByteArray();result.resize(indices.size()*4)
	for index in range(indices.size()):result.encode_s32(index*4,indices[index])
	return result
static func _normal(vertices:PackedVector3Array)->Vector3:
	# Derive shading only in doubles; actual terrain vertices never move.
	var ab:=PackedFloat64Array();var ac:=PackedFloat64Array()
	for axis in range(3):ab.append(float(vertices[1][axis])-float(vertices[0][axis]));ac.append(float(vertices[2][axis])-float(vertices[0][axis]))
	var values:=PackedFloat64Array([ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]])
	var length:=sqrt(values[0]*values[0]+values[1]*values[1]+values[2]*values[2])
	if not is_finite(length) or length<=0:return Vector3.ZERO
	var direction:=-1.0 if values[1]<0 else 1.0
	return Vector3(values[0]/length*direction,values[1]/length*direction,values[2]/length*direction)
static func _centroid(vertices:PackedVector3Array)->Vector3:
	return Vector3((float(vertices[0].x)+float(vertices[1].x)+float(vertices[2].x))/3.0,(float(vertices[0].y)+float(vertices[1].y)+float(vertices[2].y))/3.0,(float(vertices[0].z)+float(vertices[1].z)+float(vertices[2].z))/3.0)
static func _validate_payload(payload:Dictionary,identity:String,generation:int)->Dictionary:
	if payload.get("ok")!=true or payload.get("source_contract")!=Provider.CONTRACT or not _hex(payload.get("snapshot_sha256")) or str(payload.snapshot_sha256)!=identity or not _integer(payload.get("generation"),0,0x7fffffff) or int(payload.generation)!=generation:return _failure("provider_payload_identity_mismatch")
	var binding:Variant=payload.get("request_binding")
	if not binding is Dictionary or not _integer(binding.get("generation"),0,0x7fffffff) or int(binding.generation)!=generation or not binding.get("request_token") is String or not _hex(binding.get("request_sha256")):return _failure("invalid_provider_request_binding")
	var triangles:Variant=payload.get("triangles")
	if not triangles is Array or triangles.is_empty() or triangles.size()>3 or not _integer(payload.get("active_child_id"),0,2):return _failure("invalid_native_leaf_list")
	var active:Dictionary={};var ids:Dictionary={}
	for row:Variant in triangles:
		if not row is Dictionary or not _integer(row.get("child_id"),0,2) or ids.has(int(row.child_id)) or not _hex(row.get("packet_sha256")) or row.get("role") not in ["active","visited_witness"]:return _failure("invalid_native_leaf_identity")
		if not row.get("vertices") is PackedVector3Array or row.vertices.size()!=3 or not row.get("indices") is PackedInt32Array or row.indices!=PackedInt32Array([0,1,2]):return _failure("invalid_literal_native_vertex_buffer")
		for point:Vector3 in row.vertices:
			if not point.is_finite():return _failure("nonfinite_native_vertex")
		var normal:=_normal(row.vertices)
		if not normal.is_finite() or normal==Vector3.ZERO:return _failure("degenerate_literal_native_triangle")
		ids[int(row.child_id)]=true
		if row.role=="active":
			if not active.is_empty() or int(row.child_id)!=int(payload.active_child_id):return _failure("ambiguous_active_native_leaf")
			active=row.duplicate(true)
		elif int(row.child_id)==int(payload.active_child_id):return _failure("active_leaf_marked_as_witness")
	if active.is_empty():return _failure("missing_active_native_leaf")
	return {"ok":true,"active":active,"triangles":triangles.duplicate(true)}
func _new_material(kind:String,quality:int)->StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.albedo_color=PALETTE[kind];material.roughness=0.63 if kind=="ice" else 0.96;material.metallic=0.0
	material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if quality>0:
		var metadata:Dictionary=WorldMaterials.metadata()
		if int(metadata.get("resolution",0))!=1024:return null
		var albedo:=WorldMaterials.texture(kind,"albedo");var normal:=WorldMaterials.texture(kind,"normal");var orm:=WorldMaterials.texture(kind,"orm")
		if albedo==null or normal==null or orm==null:return null
		material.albedo_texture=albedo;material.normal_enabled=true;material.normal_texture=normal;material.normal_scale=0.6 if quality==1 else 1.0
		material.roughness_texture=orm;material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN;material.ao_enabled=true;material.ao_texture=orm;material.ao_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.uv1_triplanar=true;material.uv1_triplanar_sharpness=4.0;material.uv1_scale=Vector3.ONE*(0.03125 if kind=="ice" else 0.0625)
	return material
func set_kind(value:String)->bool:
	if not PALETTE.has(value):last_error="unsupported_native_surface_palette";return false
	var material:=_new_material(value,_quality)
	if material==null:last_error="native_surface_material_unavailable";return false
	_kind=value;_material=material
	if is_instance_valid(_terrain):_terrain.material_override=material
	last_error="";return true
func set_quality(value:int)->bool:
	if value<0 or value>2:last_error="invalid_native_surface_quality";return false
	var material:=_new_material(_kind,value)
	if material==null:last_error="native_surface_material_unavailable";return false
	_quality=value;_material=material
	if is_instance_valid(_terrain):_terrain.material_override=material
	last_error="";return true
func set_witnesses_visible(value:bool)->void:
	_witnesses_visible=value
	if is_instance_valid(_mesh_root):
		for child:Node in _mesh_root.get_children():
			if child is Label3D:child.visible=value
func _reject(reason:String)->bool:
	last_error=reason;_rejected_publication_count+=1;return false
func configure(value:Variant)->bool:
	# Main may synchronize an unchanged immutable provider every render frame.
	# Reuse only the already verified, privately retained literal buffer;
	# changed identities or emitted bytes always pass full publication again.
	if not value is RefCounted:return _reject("verified_native_provider_required")
	var provider:RefCounted=value
	if provider.get_script()==Provider and provider.configured() and not _geometry.is_empty() and provider.snapshot_identity()==str(_geometry.snapshot_sha256) and provider.generation()==int(_geometry.generation) and var_to_bytes(provider.render_payload())==var_to_bytes(_payload):
		last_error="";return true
	return publish(provider)
func publish(provider:RefCounted)->bool:
	# All mutable work occurs in a private staged scene. A bad or stale
	# candidate cannot replace an already published literal terrain leaf.
	if provider==null or provider.get_script()!=Provider or not provider.configured():return _reject("unconfigured_or_unsupported_native_provider")
	var snapshot:Dictionary=provider.snapshot();var rebuilt:RefCounted=Provider.from_snapshot(snapshot)
	if rebuilt==null:return _reject("native_provider_snapshot_rejected")
	var identity:String=provider.snapshot_identity();var generation:int=provider.generation();var payload:Dictionary=provider.render_payload()
	if var_to_bytes(payload)!=var_to_bytes(rebuilt.render_payload()):return _reject("native_provider_payload_differs_from_sealed_snapshot")
	var validated:=_validate_payload(payload,identity,generation)
	if not validated.ok:return _reject(str(validated.reason))
	var material:=_new_material(_kind,_quality)
	if material==null:return _reject("native_surface_material_unavailable")
	var active:Dictionary=validated.active;var vertices:=PackedVector3Array();var indices:=PackedInt32Array();var normals:=PackedVector3Array();var literal:Array=[]
	for row:Dictionary in validated.triangles:
		var normal:=_normal(row.vertices);var base:=vertices.size()
		vertices.append_array(row.vertices)
		for index:int in row.indices:indices.append(base+index)
		normals.append_array(PackedVector3Array([normal,normal,normal]))
		literal.append({"child_id":int(row.child_id),"role":str(row.role),"vertices":row.vertices.duplicate(),"indices":row.indices.duplicate(),"packet_sha256":str(row.packet_sha256),"vertex_f32_hex":_vertex_bytes(row.vertices).hex_encode(),"vertex_f32_sha256":_sha(_vertex_bytes(row.vertices))})
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var staged:=Node3D.new();staged.name="PublishedNativeLeaves";var terrain:=MeshInstance3D.new();terrain.name="LiteralNativeTerrainSoup";terrain.mesh=mesh;terrain.material_override=material;staged.add_child(terrain)
	for ordinal in range(validated.triangles.size()):
		var row:Dictionary=validated.triangles[ordinal];var label:=Label3D.new();label.name="NativeVolumeWitness_%d"%int(row.child_id)
		label.text="Корпус" if int(row.child_id)==0 else "Объём %d"%int(row.child_id)
		if row.role=="active":label.text+=" · активный"
		label.position=_centroid(row.vertices);label.offset=Vector2(0,-18*ordinal);label.font_size=18;label.pixel_size=0.005;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.fixed_size=true;label.no_depth_test=true;label.modulate=WITNESS_COLOURS[int(row.child_id)];label.outline_size=4;label.visible=_witnesses_visible;staged.add_child(label)
	# Re-read the same sealed provider after construction, before publication.
	if not provider.configured() or provider.snapshot_identity()!=identity or provider.generation()!=generation or var_to_bytes(provider.render_payload())!=var_to_bytes(payload):staged.free();return _reject("native_provider_changed_during_publication")
	var geometry:={"vertices":vertices.duplicate(),"indices":indices.duplicate(),"normals":normals.duplicate(),"triangles":literal,"child_id":int(active.child_id),"packet_sha256":str(active.packet_sha256),"active_vertex_f32_sha256":_sha(_vertex_bytes(active.vertices)),"snapshot_sha256":identity,"generation":generation,"request_binding":payload.request_binding.duplicate(true),"vertex_f32_sha256":_sha(_vertex_bytes(vertices)),"vertex_f32_hex":_vertex_bytes(vertices).hex_encode(),"indices_s32_hex":_index_bytes(indices).hex_encode()}
	if payload.has("source_model_index"):geometry["source_model_index"]=payload.source_model_index
	if payload.has("source_uid_u32"):geometry["source_uid_u32"]=payload.source_uid_u32
	if is_instance_valid(_mesh_root):remove_child(_mesh_root);_mesh_root.queue_free()
	add_child(staged);_mesh_root=staged;_terrain=terrain;_material=material;_geometry=geometry;_payload=payload.duplicate(true);_publication_count+=1;last_error="";_last_clear_reason=""
	return true
func clear(reason:String="cleared")->void:
	if is_instance_valid(_mesh_root):remove_child(_mesh_root);_mesh_root.queue_free()
	_mesh_root=null;_terrain=null;_material=null;_geometry={};_payload={};_clear_count+=1;_last_clear_reason=reason;last_error=""
func terrain_geometry()->Dictionary:return _geometry.duplicate(true)
func stats()->Dictionary:
	return {"source_contract":CONTRACT,"provider_contract":Provider.CONTRACT,"configured":not _geometry.is_empty(),"publication_count":_publication_count,"rejected_publication_count":_rejected_publication_count,"clear_count":_clear_count,"last_clear_reason":_last_clear_reason,"last_error":last_error,"snapshot_sha256":str(_geometry.get("snapshot_sha256","")),"generation":int(_geometry.get("generation",0)),"request_binding":_geometry.get("request_binding",{}).duplicate(true),"active_child_id":int(_geometry.get("child_id",-1)),"terrain_triangle_count":_geometry.get("triangles",[]).size(),"visited_leaf_count":_payload.get("triangles",[]).size(),"visited_witness_count":maxi(0,_payload.get("triangles",[]).size()-1),"terrain_vertex_f32_sha256":str(_geometry.get("vertex_f32_sha256","")),"terrain_vertex_f32_hex":str(_geometry.get("vertex_f32_hex","")),"terrain_indices_s32_hex":str(_geometry.get("indices_s32_hex","")),"palette_kind":_kind,"detail_quality":_quality,"witnesses_visible":_witnesses_visible,"literal_packet_vertices":true,"terrain_vertex_deformation":false,"active_leaf_only_filled":false,"all_emitted_leaves_filled":true,"overlap_policy":"literal-triangle-soup-no-displacement","shading_normal_policy":"double-cross-of-literal-F32-face-oriented-toward-local-up","shading_normal_is_native_contact_normal":false,"marker_policy":"captured-leaf-centroid-with-screen-text-offset-only","physics_camera_clock_or_provider_written":false,"render_only":true,"native_live_response_enabled":false,"fullmesh_geometry_certified":false}
