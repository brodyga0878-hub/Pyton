func _run_geographic_descent_smoke()->void:
	help_panel.hide();resume_panel.hide();model=Flight.new();model.docked=false;model.external_view=true;model.credits=68124;model.cargo=3
	nav=Navigation.new();economy=Economy.new();combat=Combat.new();surface=Surface.new();campaign=Campaign.new();planetary=Planetary.new();planetary.configure(nav.current());planetary.site_id="site10"
	var globe:=Surface.SphereTerrain.new();globe.configure(planetary,planetary.focus_id,planetary.site_id);globe.latitude=0.45;globe.longitude=1.23
	var frame:Transform3D=NearSurfaceView.world_frame(globe,planetary,nav.elapsed_days)
	model.position=frame*Vector3(0,50000,0);model.velocity=frame.basis*Vector3(3,-5,2);model.attitude=frame.basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,-0.35)
	_apply_system();camera.position=model.position+frame.basis*Vector3(0,20,100);camera.quaternion=model.attitude;_sync_planet_visuals()
	if not near_surface_view.active or not surface.orbit_link.is_empty():push_error("GEOGRAPHIC DESCENT SMOKE FAILED: first-visit preview");get_tree().quit(1);return
	var mesh_before:Node=surface_root.get_child(0)
	var pixels:Array=[];var points:Array[Vector3]=[Vector3(0,0,-16000),Vector3(1200,-300,-18000),Vector3(-1200,-300,-18000)]
	for point in points:pixels.append(camera.unproject_position(surface_root.to_global(point)))
	var before_camera:Transform3D=camera.transform
	var planet_view:Vector3=camera.global_transform.affine_inverse()*celestial_root.visuals[planetary.focus_id].anchor.global_position
	var light_view:Basis=camera.global_basis.inverse()*sun_light.global_basis
	var stars_view:Transform3D=camera.global_transform.affine_inverse()*star_field.global_transform
	var coverage:float=surface_root.view_coverage
	_surface_action()
	if not surface.active or surface.flight_phase!="descent" or near_surface_view.active or surface_root.get_child(0)!=mesh_before:push_error("GEOGRAPHIC DESCENT SMOKE FAILED: shared first-entry mesh");get_tree().quit(1);return
	if absf(surface.geoid_height(model)-50000)>4 or model.velocity.distance_to(Vector3(3,-5,2))>0.01 or not celestial_root.visible or not celestial_root.focus_surface_preview:push_error("GEOGRAPHIC DESCENT SMOKE FAILED: continuous high entry");get_tree().quit(1);return
	if absf(surface_root.view_coverage-coverage)>0.0001 or (frame*camera.transform).origin.distance_to(before_camera.origin)>4:push_error("GEOGRAPHIC DESCENT SMOKE FAILED: camera or material jump");get_tree().quit(1);return
	for i in range(points.size()):
		if camera.unproject_position(surface_root.to_global(points[i])).distance_to(pixels[i])>2:push_error("GEOGRAPHIC DESCENT SMOKE FAILED: terrain projection jump");get_tree().quit(1);return
	var planet_after:Vector3=camera.global_transform.affine_inverse()*celestial_root.visuals[planetary.focus_id].anchor.global_position
	var light_after:Basis=camera.global_basis.inverse()*sun_light.global_basis
	var stars_after:Transform3D=camera.global_transform.affine_inverse()*star_field.global_transform
	if planet_after.distance_to(planet_view)>8 or light_after.get_rotation_quaternion().angle_to(light_view.get_rotation_quaternion())>0.001 or stars_after.origin.distance_to(stars_view.origin)>64 or stars_after.basis.get_rotation_quaternion().angle_to(stars_view.basis.get_rotation_quaternion())>0.001:push_error("GEOGRAPHIC DESCENT SMOKE FAILED: planet/light/stars frame jump");get_tree().quit(1);return
	var height:float=surface.geoid_height(model);_save_game(false);model=Flight.new();_load_game()
	if not surface.active or surface.flight_phase!="descent" or absf(surface.geoid_height(model)-height)>0.1 or model.credits!=68124 or model.cargo!=3 or planetary.site_id!="site10":push_error("GEOGRAPHIC DESCENT SMOKE FAILED: high save/reload");get_tree().quit(1);return
	var saved:=_snapshot_game();saved.flight.position[1]=Surface.MAX_FLIGHT_HEIGHT+1000
	var before:=JSON.stringify(_snapshot_game())
	if not _decode_game(saved).is_empty() or JSON.stringify(_snapshot_game())!=before:push_error("GEOGRAPHIC DESCENT SMOKE FAILED: invalid high save atomicity");get_tree().quit(1);return
	_surface_action()
	for tick in range(180):surface.step(0.25,model,Vector2.ZERO,0)
	if not surface.flight_phase.is_empty() or model.velocity.length()>0.01:push_error("GEOGRAPHIC DESCENT SMOKE FAILED: stop descent");get_tree().quit(1);return
	_save_game(false);model=Flight.new();_load_game();_toggle_auto()
	if surface.flight_phase!="descent":push_error("GEOGRAPHIC DESCENT SMOKE FAILED: reload/resume descent");get_tree().quit(1);return
	for tick in range(1600):
		var previous:Vector3=model.position
		nav.elapsed_days+=0.25/86400.0;surface.step(0.25,model,Vector2.ZERO,0)
		if model.position.distance_to(previous)>76 or model.hull!=100:push_error("GEOGRAPHIC DESCENT SMOKE FAILED: discontinuity or damage");get_tree().quit(1);return
		if surface.altitude(model)<22000:break
	_sync_planet_visuals()
	if surface_root.view_coverage!=1.0 or surface_root.get_child(0).material_override.shader!=SurfaceVisual.TerrainShader:push_error("GEOGRAPHIC DESCENT SMOKE FAILED: opaque low material");get_tree().quit(1);return
	_settle_vertical_for_test();_save_game(false);model=Flight.new();_load_game()
	if not surface.active or absf(surface.altitude(model)-1500)>0.01 or model.hull!=100 or model.credits!=68124 or model.cargo!=3:push_error("GEOGRAPHIC DESCENT SMOKE FAILED: completed descent reload");get_tree().quit(1);return
	print("GEOGRAPHIC DESCENT SMOKE PASS: first-entry actual position, same mesh/projection/camera/planet/light/stars, high save and atomic rejection, stopped reload/resume, continuous descent through blend to opaque terrain and 1500m hover")
	get_tree().quit()
