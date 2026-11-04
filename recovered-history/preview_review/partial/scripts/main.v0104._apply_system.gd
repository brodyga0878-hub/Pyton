func _apply_system() -> void:
	if planetary.system_id!=nav.current_id: planetary.configure(nav.current())
	if not surface.active and not surface.orbit_link.is_empty() and not Surface.OrbitLink.matches(surface.orbit_link,planetary):surface.orbit_link={}
	if celestial_root.context!=planetary or celestial_root.get_meta("system_id",-1)!=nav.current_id or celestial_root.get_meta("layout","")!=planetary.layout_mode:
		celestial_root.configure(planetary)
		celestial_root.set_meta("system_id",nav.current_id)
		celestial_root.set_meta("layout",planetary.layout_mode)
	_apply_ship()
	model.original_port=not planetary.current_site().is_empty()
	nav.station_override=str(planetary.current_site().name) if planetary.is_orbital_site() else ""
	model.station_available = _station_here()
	station_root.visible = _station_here()
	drone.visible = _station_here()
	celestial_root.visible=not surface.active
	surface_root.visible=surface.active
	if surface.active:
		surface_root.configure(surface)
		sun_light.rotation_degrees=Vector3(-50,-30,0)
	world_presentation.apply(world_environment.environment,surface,device_settings.quality)
	star_field.visible=not surface.active or surface.kind!="earth"
	sun_light.light_color = Color("ffe9ca") if (int(nav.current().type_code)&31)<6 else Color("c4dcff")
