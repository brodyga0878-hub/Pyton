extends Node3D
var visuals := {}
var context: RefCounted
const PlanetShader = preload("res://scripts/planet.gdshader")

func configure(system: RefCounted) -> void:
	context = system
	for child in get_children():
		remove_child(child)
		child.queue_free()
	visuals.clear()
	for body in context.bodies:
		if body.kind=="barycenter":continue
		var anchor := Node3D.new()
		add_child(anchor)
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1
		sphere.height = 2
		sphere.radial_segments = 64
		sphere.rings = 32
		mesh.mesh = sphere
		var mat := ShaderMaterial.new()
		mat.shader = PlanetShader
		var kind := str(body.kind)
		var code := {"earth":0,"rock":1,"desert":2,"gas":3,"ice_gas":4,"ice":5,"star":6}
		mat.set_shader_parameter("body_kind",int(code.get(kind,1)))
		var tint := Color.from_hsv(float((context.system_id+str(body.id).hash())&255)/255.0,0.36,0.4)
		mat.set_shader_parameter("land",Color("285a3f") if body.id=="earth" else tint)
		mat.set_shader_parameter("ocean",Color("133751"))
		mat.set_shader_parameter("seed_offset",float(str(body.id).hash()&255)/30.0)
		mesh.material_override = mat
		anchor.add_child(mesh)
		if kind in ["earth","desert","gas","ice_gas"]:
			var air := MeshInstance3D.new()
			air.mesh = sphere
			air.scale = Vector3.ONE*1.025
			var am := ShaderMaterial.new()
			am.shader = Shader.new()
			am.shader.code = "shader_type spatial; render_mode unshaded, blend_add, cull_back, depth_draw_never; void fragment(){ float rim=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),4.0); ALBEDO=vec3(0.1,0.4,0.8); ALPHA=rim*0.22; }"
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
			rings.scale = Vector3(1,0.025,1)
			rings.rotation.z = 0.47
			var rm := StandardMaterial3D.new()
			rm.albedo_color = Color("bfa984")
			rm.roughness = 1
			rings.material_override = rm
			anchor.add_child(rings)
		visuals[str(body.id)] = {"anchor":anchor,"mesh":mesh}

func update_view(days: float, observer: Vector3) -> void:
	if not context: return
	for body in context.bodies:
		if body.kind=="barycenter":continue
		var center: Vector3 = context.local_meters(str(body.id),days)
		var relative := center-observer
		var distance := maxf(relative.length(),1)
		var draw_distance := 60000.0+minf(28000,log(distance/1000000.0+1)*2200)
		var entry: Dictionary = visuals[str(body.id)]
		entry.anchor.position = observer+relative/distance*draw_distance
		var apparent_radius: float = float(body.radius_km)*1000*draw_distance/distance
		entry.anchor.scale = Vector3.ONE*apparent_radius
		entry.mesh.rotation.y = fposmod(days*TAU*24.0/float(body.rotation_hours),TAU)
