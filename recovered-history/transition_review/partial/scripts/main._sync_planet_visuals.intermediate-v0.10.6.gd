func _sync_planet_visuals()->void:
	var draw:RefCounted=surface if surface.active else null
	if surface.active:near_surface_view.clear()
	elif near_surface_view.update(surface,model,planetary,nav.elapsed_days):draw=near_surface_view.drawing
	var preview:bool=near_surface_view.active
	position=-model.position if not surface.active else Vector3.ZERO
	surface_root.visible=draw!=null
	surface_root.transform=near_surface_view.frame if preview else Transform3D.IDENTITY
	if preview:
		var turn:Quaternion=near_surface_view.frame.basis.get_rotation_quaternion().slerp(Quaternion.IDENTITY,near_surface_view.space_blend)
		star_field.transform=Transform3D(Basis(turn),near_surface_view.frame.origin.lerp(model.position,near_surface_view.space_blend))
	else:star_field.transform=Transform3D(Basis.IDENTITY,model.position if not surface.active else Vector3.ZERO)
	celestial_root.visible=not surface.active
	celestial_root.set_surface_transition(preview,near_surface_view.space_blend if preview else 1.0)
	station_root.visible=_station_here() and not preview;drone.visible=station_root.visible
	var key:="space" if draw==null else ("preview:" if preview else "surface:")+str(draw.kind)+":"+str(device_settings.quality)
	if key!=presentation_key:
		world_presentation.apply(world_environment.environment,draw if draw!=null else surface,device_settings.quality)
		presentation_key=key
	world_environment.environment.sky_rotation=Basis(near_surface_view.frame.basis.get_rotation_quaternion().slerp(Quaternion.IDENTITY,near_surface_view.space_blend)).get_euler() if preview else Vector3.ZERO
	if draw!=null:
		surface_root.configure(draw)
		surface_root.set_view_coverage(1.0-near_surface_view.space_blend if preview else 1.0)
		var height:float=near_surface_view.height if preview else surface.altitude(model)
		camera.far=1100000.0 if draw.extended_flight else 180000.0
		camera.near=2.0 if height>5000 else 0.5
		world_presentation.update_height(world_environment.environment,draw,height,device_settings.quality,near_surface_view.space_blend if preview else 0.0)
		star_field.visible=draw.kind!="earth" or (draw.extended_flight and height>15000)
		var local_light:=Basis.from_euler(Vector3(-50,-30,0)*PI/180.0)
		if preview:
			var sunlight:Vector3=planetary.local_meters("star",nav.elapsed_days)-model.position
			var direction:Vector3=sunlight.normalized()
			var far_light:Basis=Basis.looking_at(-direction,Vector3.UP if absf(direction.y)<0.98 else Vector3.RIGHT)
			var close_light:Basis=near_surface_view.frame.basis*local_light
			sun_light.basis=Basis(close_light.get_rotation_quaternion().slerp(far_light.get_rotation_quaternion(),near_surface_view.space_blend))
		else:sun_light.basis=local_light
	else:
		camera.far=180000.0;camera.near=0.5;star_field.visible=true
