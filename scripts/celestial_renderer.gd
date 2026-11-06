extends Node3D
var visuals := {}
var context: RefCounted
var quality:=2
var last_high_focus:=""
var focus_surface_preview:=false
var surface_space_blend:=0.0
const RingShader=preload("res://scripts/rings.gdshader")
const AtmosphereShader=preload("res://scripts/atmosphere.gdshader")
const Materials=preload("res://scripts/world_surface_library.gd")
const SourceGlobalMesh=preload("res://scripts/source_global_body_mesh.gd")
const SourceUnits=preload("res://scripts/source_units.gd")
const FULL_LAYOUT:="source_jjffe_systems_v4"
const SOURCE_CACHE_LIMIT:=4
const SOURCE_CAP_MARGIN:=0.9
var _source_cache:Dictionary={}
var _source_cache_order:Array=[]
var _source_thread:Thread
var _source_cancel:SourceGlobalMesh.Cancellation
var _source_job_key:=""
var _source_wanted:Dictionary={}
var _source_focus:=""
var _source_status:="inactive"
var _source_error:=""
var _source_ground_patch:Dictionary={}

func _full_context()->bool:return context!=null and context.get("layout_mode")==FULL_LAYOUT

func _exit_tree()->void:
	if _source_cancel!=null:_source_cancel.cancel()
	if _source_thread!=null and _source_thread.is_started():_source_thread.wait_to_finish()

func _process(_dt:float)->void:
	if _source_thread!=null and _source_thread.is_started() and not _source_thread.is_alive():
		var result:Variant=_source_thread.wait_to_finish();_source_thread=null
		if result is Dictionary and result.get("ok",false):
			_source_cache[_source_job_key]=result;_source_cache_order.erase(_source_job_key);_source_cache_order.append(_source_job_key)
			if _source_cache_order.size()>SOURCE_CACHE_LIMIT:_source_cache.erase(_source_cache_order.pop_front())
			if str(_source_wanted.get("key",""))==_source_job_key:_install_source_mesh(result)
		elif str(_source_wanted.get("key",""))==_source_job_key and result is Dictionary and not result.get("cancelled",false):
			_source_status="failed";_source_error=str(result.get("error","Source global mesh build failed"));_source_wanted={}
		_source_job_key="";_source_cancel=null
	_start_source_job()
	set_process(_source_thread!=null or not _source_wanted.is_empty())

func _start_source_job()->void:
	if _source_thread!=null or _source_wanted.is_empty() or _source_status=="ready":return
	_source_job_key=str(_source_wanted.key);_source_cancel=SourceGlobalMesh.Cancellation.new();_source_thread=Thread.new();_source_status="building";_source_error=""
	var result:=_source_thread.start(SourceGlobalMesh.build.bind(_source_wanted.snapshot.duplicate(true),_source_cancel))
	if result!=OK:_source_thread=null;_source_cancel=null;_source_job_key="";_source_status="failed";_source_error="Could not start source mesh worker";_source_wanted={}

func _request_source_focus()->void:
	if not _full_context():return
	var focus:=str(context.focus_id)
	if focus==_source_focus:return
	_source_focus=focus
	if _source_cancel!=null:_source_cancel.cancel()
	for id in visuals:
		var entry:Dictionary=visuals[id]
		if entry.get("source_height_active",false):entry.mesh.mesh=entry.base_sphere;entry.source_height_active=false
	var snapshot:=SourceGlobalMesh.snapshot(context,focus)
	if snapshot.is_empty():_source_wanted={};_source_status="unsupported";return
	var key:=SourceGlobalMesh.key(snapshot);_source_wanted={"key":key,"snapshot":snapshot};_source_status="pending";_source_error=""
	if _source_cache.has(key):
		_source_cache_order.erase(key);_source_cache_order.append(key);_install_source_mesh(_source_cache[key])
	else:_start_source_job()
	set_process(_source_thread!=null or not _source_wanted.is_empty())

func _install_source_mesh(result:Dictionary)->void:
	if not _full_context() or str(result.get("body_id",""))!=str(context.focus_id) or not visuals.has(str(result.body_id)):return
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result.arrays)
	var entry:Dictionary=visuals[str(result.body_id)];entry.mesh.mesh=mesh;entry.source_height_active=true
	entry.mesh.set_meta("source_global_height_revision",SourceGlobalMesh.REVISION);entry.mesh.set_meta("source_global_height_policy",str(result.height_policy));entry.mesh.set_meta("source_global_height_samples",result.sample_nodes.size())
	_source_status="ready";_source_error="";_source_wanted={}

func source_mesh_state()->Dictionary:
	return {"status":_source_status,"error":_source_error,"focus_id":_source_focus,"job_key":_source_job_key,"cache_entries":_source_cache.size(),"cache_limit":SOURCE_CACHE_LIMIT,"profile":SourceGlobalMesh.REVISION}

func source_light(body_id:String,days:float)->Dictionary:
	if not _full_context() or not context.by_id.has(body_id):return {}
	var centre:Vector3=context.local_meters(body_id,days);var best:=INF;var chosen:="";var delta:=Vector3.ZERO
	for body:Dictionary in context.bodies:
		if str(body.get("kind",""))!="star" or str(body.id)==body_id:continue
		var type_code:=int(body.get("type_code",body.get("original_type",-1)))
		if type_code<17 or type_code>30:continue
		var offset:Vector3=context.local_meters(str(body.id),days)-centre;var distance:=offset.length_squared()
		if is_finite(distance) and distance>0 and distance<best:best=distance;chosen=str(body.id);delta=offset
	if chosen.is_empty():return {}
	return {"body_id":chosen,"direction_world":(global_basis*delta).normalized(),"distance_squared_m":best,"policy":"nearest_actual_source_luminous_star_v1"}

static func source_cap_hidden(direction:Vector3,cap:Dictionary,threshold:float)->bool:
	# Same opt-in screen mask as PlanetShader; useful for non-GPU control and
	# diagnostics. It never evaluates terrain or changes body collision geometry.
	if not cap.get("enabled",false) or not direction.is_finite() or direction.length_squared()==0:return false
	if direction.normalized().dot(cap.direction)<float(cap.cosine):return false
	var coverage:=clampf(float(cap.coverage),0,1)
	return coverage<=0 or threshold<1.0-coverage

func source_cap_state(body_id:String)->Dictionary:
	if not visuals.has(body_id):return {}
	return visuals[body_id].get("source_surface_cap",{}).duplicate(true)

func set_source_ground_patch(globe:RefCounted)->void:
	_source_ground_patch={}
	if not _full_context() or globe==null or globe.get("revision")!=SourceGlobalMesh.Terrain.REVISION_NAME or not globe.has_method("maximum_patch_extent"):return
	var record:Variant=globe.get("source_record");var policy:Variant=globe.get("source_policy")
	if not record is PackedByteArray or record.size()!=68 or not policy is Dictionary:return
	var radius:=float(globe.radius);var latitude:=float(globe.latitude);var longitude:=float(globe.longitude)
	if not is_finite(radius) or radius<=0 or not is_finite(latitude) or not is_finite(longitude):return
	var outer:=minf(float(globe.maximum_patch_extent()),minf(512000.0,radius*0.7))
	var bound:=maxf(radius,SourceUnits.metres(float(policy.get("original_outer_bound_raw",0))))
	if context.by_id.has(str(context.focus_id)):bound=maxf(bound,float(context.by_id[str(context.focus_id)].get("source_outer_bound_m",0.0)))
	if not is_finite(outer) or outer<=0:return
	_source_ground_patch={"record_hex":record.hex_encode(),"direction":Vector3(cos(latitude)*cos(longitude),sin(latitude),-cos(latitude)*sin(longitude)),"radius_m":outer*SOURCE_CAP_MARGIN,"rendered_outer_m":outer,"maximum_body_radius_m":bound,"cosine":cos(asin(clampf(outer*SOURCE_CAP_MARGIN/bound,0,1)))}

func _source_cap(entry:Dictionary,body:Dictionary,centre:Vector3,observer:Vector3,basis:Basis)->void:
	var enabled:bool=focus_surface_preview and str(body.id)==str(context.focus_id) and body.get("landable",false) and not _source_ground_patch.is_empty() and _source_ground_patch.record_hex==str(body.get("runtime_record_hex",""))
	var cap:={"enabled":enabled,"direction":Vector3.UP,"cosine":1.0,"coverage":surface_space_blend,"radius_m":0.0,"policy":"source-ground-angular-cap-v1"}
	if enabled:
		cap.direction=_source_ground_patch.direction
		# Use the actual surface's maximum_patch_extent, including nonspherical
		# model117. Its orthographic patch must cover the whole clipped disc.
		cap.radius_m=_source_ground_patch.radius_m;cap.cosine=_source_ground_patch.cosine
		cap.rendered_outer_m=_source_ground_patch.rendered_outer_m;cap.maximum_body_radius_m=_source_ground_patch.maximum_body_radius_m
	cap.direction_world=(global_basis*basis*Vector3(cap.direction)).normalized()
	entry.source_surface_cap=cap
	entry.mesh.material_override.set_shader_parameter("source_surface_cap_enabled",enabled)
	entry.mesh.material_override.set_shader_parameter("source_surface_cap_direction_world",cap.direction_world)
	entry.mesh.material_override.set_shader_parameter("source_surface_cap_cosine",cap.cosine)
	entry.mesh.material_override.set_shader_parameter("source_surface_cap_coverage",surface_space_blend)
func set_quality(value:int)->void:
	quality=clampi(value,0,2)
	for entry in visuals.values():
		entry.mesh.material_override.set_shader_parameter("detail_level",quality)
		_bind_body_material(entry.mesh.material_override,str(entry.get("material_kind","rock")))
		if entry.has("air"):entry.air.visible=quality>0
		if entry.has("rings"):entry.rings.material_override.set_shader_parameter("detail_level",quality)

const PlanetShader = preload("res://scripts/planet.gdshader")

func _bind_body_material(material:ShaderMaterial,kind:String)->void:
	if quality==0 or kind in ["gas","ice_gas","star","barycenter"]:
		Materials.clear_material(material);return
	if not Materials.bind_shader(material,Materials.canonical_kind(kind),48.0):
		material.set_shader_parameter("detail_level",0)
		push_error("Planet surface material could not be loaded: "+kind)

func configure(system: RefCounted) -> void:
	last_high_focus=""
	if _source_cancel!=null:_source_cancel.cancel()
	_source_wanted={};_source_focus="";_source_status="inactive";_source_error=""
	context = system
	for child in get_children():
		remove_child(child)
		child.queue_free()
	visuals.clear()
	var inhabited:Dictionary={}
	for site in context.settlements:
		if int(site.get("type_code",0))==35:inhabited[str(site.get("parent",""))]=true
	for body in context.bodies:
		if body.kind=="barycenter":continue
		var anchor := Node3D.new()
		add_child(anchor)
		var mesh := MeshInstance3D.new()
		# Far planets are compressed for rendering and must not fill local shadow maps.
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sphere := SphereMesh.new()
		sphere.radius = 1
		sphere.height = 2
		sphere.radial_segments = 64
		sphere.rings = 32
		mesh.mesh = sphere
		var mat := ShaderMaterial.new()
		mat.shader = PlanetShader
		mat.set_shader_parameter("detail_level",quality)
		mat.set_shader_parameter("inhabited",inhabited.has(str(body.id)))
		var kind := str(body.kind)
		# Mineral maps add fine surface response only; procedural geography,
		# cloud placement, body radii/orbits and source records are untouched.
		_bind_body_material(mat,kind)
		var code := {"earth":0,"rock":1,"desert":2,"gas":3,"ice_gas":4,"ice":5,"star":6}
		mat.set_shader_parameter("body_kind",int(code.get(kind,1)))
		var tint := Color.from_hsv(float((context.system_id+str(body.id).hash())&255)/255.0,0.36,0.4)
		mat.set_shader_parameter("land",Color("315336") if body.id=="earth" else tint)
		mat.set_shader_parameter("ocean",Color("07314b"))
		mat.set_shader_parameter("seed_offset",float(str(body.id).hash()&255)/30.0)
		mesh.material_override = mat
		anchor.add_child(mesh)
		var atmosphere:MeshInstance3D
		if kind in ["earth","gas","ice_gas"]:
			var air := MeshInstance3D.new()
			air.mesh = sphere
			air.scale = Vector3.ONE*1.014
			air.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var am := ShaderMaterial.new()
			am.shader = AtmosphereShader
			am.set_shader_parameter("atmosphere_color",Color("72b6e5") if kind=="earth" else (Color("cfad7c") if kind=="gas" else Color("63c0d4")))
			air.visible=quality>0;atmosphere=air
			air.material_override = am
			anchor.add_child(air)
		if bool(body.rings):
			var rings := MeshInstance3D.new()
			var ring := TorusMesh.new()
			ring.inner_radius = 1.25
			ring.outer_radius = 2.25
			ring.rings = 96
			ring.ring_segments = 12
			rings.mesh = ring
			rings.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rings.scale = Vector3(1,0.025,1)
			rings.rotation.z = 0.47
			var rm:=ShaderMaterial.new();rm.shader=RingShader;rm.set_shader_parameter("ring_color",Color("bfa984"))
			rm.set_shader_parameter("detail_level",quality)
			rings.material_override = rm
			anchor.add_child(rings)
		visuals[str(body.id)] = {"anchor":anchor,"mesh":mesh,"material_kind":kind}
		if _full_context():visuals[str(body.id)].base_sphere=sphere;visuals[str(body.id)].source_height_active=false
		if atmosphere:visuals[str(body.id)].air=atmosphere
		for child in anchor.get_children():
			if child is MeshInstance3D and child.mesh is TorusMesh:visuals[str(body.id)].rings=child
	if _full_context():_request_source_focus()

func update_view(days: float, observer: Vector3) -> void:
	if not context: return
	# Main passes its camera in the scene parent frame. A FULL high-surface
	# renderer is transformed from inertial coordinates into that local frame.
	# Convert the observer back before doing source-centre/radial arithmetic.
	if _full_context():observer=transform.affine_inverse()*observer
	for body in context.bodies:
		if body.kind=="barycenter":continue
		var center: Vector3 = context.local_meters(str(body.id),days)
		var relative := center-observer
		var distance := maxf(relative.length(),1)
		var draw_distance := 3000000.0 if focus_surface_preview and str(body.id)!=context.focus_id else 60000.0+minf(28000,log(distance/1000000.0+1)*2200)
		var entry: Dictionary = visuals[str(body.id)]
		entry.anchor.position = observer+relative/distance*draw_distance
		var apparent_radius: float = float(body.radius_km)*1000*draw_distance/distance
		entry.anchor.scale = Vector3.ONE*apparent_radius
		if focus_surface_preview and str(body.id)==context.focus_id:
			entry.anchor.position=center
			entry.anchor.scale=Vector3.ONE*(float(body.radius_km)*1000.0 if _full_context() else maxf(1.0,float(body.radius_km)*1000.0-350.0*(1.0-surface_space_blend)))
		var sunlight:=Vector3.ZERO
		if _full_context():
			var source:=source_light(str(body.id),days)
			if not source.is_empty():sunlight=source.direction_world;entry.mesh.set_meta("source_light_body_id",str(source.body_id))
		else:
			var to_sun:Vector3=context.local_meters("star",days)-center
			sunlight=(global_basis*to_sun).normalized()
		if sunlight.length_squared()<0.5:sunlight=Vector3(0.3,0.5,0.8).normalized()
		entry.mesh.material_override.set_shader_parameter("sun_direction_world",sunlight)
		if entry.has("air"):
			entry.air.material_override.set_shader_parameter("sun_direction_world",sunlight)
		if entry.has("rings"):
			entry.rings.material_override.set_shader_parameter("sun_direction_local",entry.rings.global_basis.orthonormalized().inverse()*sunlight)
		if _full_context():
			var source_basis:Basis=context.body_rotation_basis(str(body.id),days)
			entry.mesh.basis=source_basis;_source_cap(entry,body,center,observer,source_basis)
		else:entry.mesh.rotation.y = fposmod(days*TAU*24.0/float(body.rotation_hours),TAU)

func suppress_focus_surface(suppress:bool)->void:
	for id in visuals:
		visuals[id].anchor.visible=not (suppress and id==context.focus_id)

func set_surface_transition(enabled:bool,blend:float)->void:
	if _full_context():
		_request_source_focus();focus_surface_preview=enabled;surface_space_blend=clampf(blend,0,1)
		for id in visuals:
			var entry:Dictionary=visuals[id];entry.anchor.visible=true
			var coverage:float=1.0 if not enabled or id==context.focus_id else surface_space_blend
			entry.mesh.material_override.set_shader_parameter("view_coverage",coverage);entry.mesh.material_override.set_shader_parameter("coverage_invert",false)
			if entry.has("air"):entry.air.material_override.set_shader_parameter("view_coverage",surface_space_blend if enabled else 1.0);entry.air.material_override.set_shader_parameter("coverage_invert",false)
			if entry.has("rings"):entry.rings.material_override.set_shader_parameter("view_coverage",coverage);entry.rings.material_override.set_shader_parameter("coverage_invert",false)
		return
	if last_high_focus!="" and last_high_focus!=context.focus_id and visuals.has(last_high_focus):
		var old:SphereMesh=visuals[last_high_focus].mesh.mesh;old.radial_segments=64;old.rings=32;last_high_focus=""
	focus_surface_preview=enabled;surface_space_blend=clampf(blend,0,1)
	for id in visuals:
		var entry:Dictionary=visuals[id]
		entry.anchor.visible=true
		var is_focus:bool=id==context.focus_id
		var coverage:float=1.0 if not enabled or is_focus else surface_space_blend
		entry.mesh.material_override.set_shader_parameter("view_coverage",coverage)
		entry.mesh.material_override.set_shader_parameter("coverage_invert",false)
		if entry.has("air"):
			entry.air.material_override.set_shader_parameter("view_coverage",surface_space_blend if enabled else 1.0)
			entry.air.material_override.set_shader_parameter("coverage_invert",false)
		if entry.has("rings"):
			entry.rings.material_override.set_shader_parameter("view_coverage",coverage)
			entry.rings.material_override.set_shader_parameter("coverage_invert",false)
		if is_focus:
			if enabled:last_high_focus=id
			var sphere:SphereMesh=entry.mesh.mesh
			if enabled and sphere.radial_segments!=256:sphere.radial_segments=256;sphere.rings=128
