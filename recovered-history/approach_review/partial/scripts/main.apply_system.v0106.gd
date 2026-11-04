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
	presentation_key=""
	celestial_root.visible=not surface.active
	surface_root.visible=surface.active
	if surface.active:
		surface_root.configure(surface)
		sun_light.rotation_degrees=Vector3(-50,-30,0)
	world_presentation.apply(world_environment.environment,surface,device_settings.quality)
	star_field.visible=not surface.active or surface.kind!="earth"
	sun_light.light_color = Color("ffe9ca") if (int(nav.current().type_code)&31)<6 else Color("c4dcff")
	_sync_planet_visuals()

func _upgrade_worlds()->bool:
	if not saving_enabled or model.original_port or not model.docked or surface.active or combat.active or nav.remaining>0 or planetary.transfer_remaining>0 or campaign.remaining>0:return false
	var candidate:=Planetary.new();candidate.configure(nav.current())
	if planetary.layout_mode not in ["prototype_v1","original_v1"] or candidate.layout_mode not in ["original_v2","source_v1"]:return false
	if not save_store.write(_snapshot_game()):_announce(save_store.last_error);return false
	var before:=planetary
	planetary=candidate
	if not save_store.write(_snapshot_game()):
		planetary=before;_announce(save_store.last_error);return false
	_apply_system()
	system_panel.loaded_id=-1
	system_panel.configure(planetary,nav,model)
	_announce("Подключена исходная структура миров FFE. Деньги, груз и задания сохранены.")
	return true
