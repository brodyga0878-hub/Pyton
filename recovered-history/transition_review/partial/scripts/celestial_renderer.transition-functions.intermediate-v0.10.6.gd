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
		if entry.has("air"):
			var to_sun:Vector3=context.local_meters("star",days)-center
			entry.air.material_override.set_shader_parameter("sun_direction_world",to_sun.normalized())
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
