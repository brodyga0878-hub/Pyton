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
		if atmosphere:visuals[str(body.id)].air=atmosphere
		for child in anchor.get_children():
			if child is MeshInstance3D and child.mesh is TorusMesh:visuals[str(body.id)].rings=child

func update_view(days: float, observer: Vector3) -> void:
	if not context: return
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
			entry.anchor.scale=Vector3.ONE*maxf(1.0,float(body.radius_km)*1000.0-350.0*(1.0-surface_space_blend))
		var to_sun:Vector3=context.local_meters("star",days)-center
		var sunlight:Vector3=(global_basis*to_sun).normalized()
		if sunlight.length_squared()<0.5:sunlight=Vector3(0.3,0.5,0.8).normalized()
		entry.mesh.material_override.set_shader_parameter("sun_direction_world",sunlight)
		if entry.has("air"):
			entry.air.material_override.set_shader_parameter("sun_direction_world",sunlight)
		if entry.has("rings"):
			entry.rings.material_override.set_shader_parameter("sun_direction_local",entry.rings.global_basis.orthonormalized().inverse()*sunlight)
		entry.mesh.rotation.y = fposmod(days*TAU*24.0/float(body.rotation_hours),TAU)

func suppress_focus_surface(suppress:bool)->void:
	for id in visuals:
		visuals[id].anchor.visible=not (suppress and id==context.focus_id)

func set_surface_transition(enabled:bool,blend:float)->void:
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
