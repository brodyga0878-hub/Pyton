# HISTORICAL FRAGMENT ONLY: complete function read in inherited root context, 0.10.5-alpha1.
func _sync_planet_visuals()->void:
	var draw:RefCounted=surface if surface.active else null
	if surface.active:near_surface_view.clear()
	elif near_surface_view.update(surface,model,planetary,nav.elapsed_days):draw=near_surface_view.drawing
	var preview:bool=near_surface_view.active
	position=-model.position if preview else Vector3.ZERO
	surface_root.visible=draw!=null
	surface_root.transform=near_surface_view.frame if preview else Transform3D.IDENTITY
	star_field.transform=near_surface_view.frame if preview else Transform3D.IDENTITY
	celestial_root.visible=not surface.active and not preview
	celestial_root.suppress_focus_surface(preview)
	station_root.visible=_station_here() and not preview;drone.visible=station_root.visible
	var key:="space" if draw==null else ("preview:" if preview else "surface:")+str(draw.kind)+":"+str(device_settings.quality)
	if key!=presentation_key:
		world_presentation.apply(world_environment.environment,draw if draw!=null else surface,device_settings.quality)
		presentation_key=key
	world_environment.environment.sky_rotation=near_surface_view.frame.basis.get_euler() if preview else Vector3.ZERO
	if draw!=null:
		surface_root.configure(draw)
		var height:float=near_surface_view.height if preview else surface.altitude(model)
		camera.far=1100000.0 if draw.extended_flight else 180000.0
		camera.near=2.0 if height>5000 else 0.5
		world_presentation.update_height(world_environment.environment,draw,height,device_settings.quality)
		star_field.visible=draw.kind!="earth" or (draw.extended_flight and height>15000)
		var local_light:=Basis.from_euler(Vector3(-50,-30,0)*PI/180.0)
		sun_light.basis=near_surface_view.frame.basis*local_light if preview else local_light
	else:
		camera.far=180000.0;camera.near=0.5;star_field.visible=true
