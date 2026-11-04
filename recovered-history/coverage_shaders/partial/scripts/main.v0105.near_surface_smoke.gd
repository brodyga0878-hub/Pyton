# HISTORICAL FRAGMENT ONLY: complete functions read in inherited root context, 0.10.5-alpha1.
func _run_near_surface_smoke()->void:
	help_panel.hide();resume_panel.hide();model=Flight.new();model.docked=false;model.external_view=true;model.credits=46802
	nav=Navigation.new();economy=Economy.new();combat=Combat.new();surface=Surface.new();campaign=Campaign.new();planetary=Planetary.new();planetary.configure(nav.current())
	planetary.site_id="site10";surface.enter(model,planetary,true);model.position.y=surface.height_at(0,0)+surface.clearance(model)+700;model.velocity=Vector3.ZERO;surface.begin_ascent(model)
	for step in range(2000):
		nav.elapsed_days+=0.25/86400;surface.step(0.25,model,Vector2.ZERO,0)
		if surface.ready_for_orbit:break
	_apply_system();camera.position=model.position+Vector3(0,20,100);camera.quaternion=model.attitude
	var mesh_before:Node=surface_root.get_child(0);var camera_before:Transform3D=camera.transform
	var frame:Transform3D=NearSurfaceView.world_frame(surface.globe,planetary,nav.elapsed_days)
	_finish_vertical_ascent()
	if not near_surface_view.active or not surface_root.visible or celestial_root.visible or surface_root.get_child(0)!=mesh_before:push_error("NEAR SURFACE SMOKE FAILED: outgoing common mesh");get_tree().quit(1);return
	if (frame.affine_inverse()*camera.transform).origin.distance_to(camera_before.origin)>4:push_error("NEAR SURFACE SMOKE FAILED: camera frame discontinuity");get_tree().quit(1);return
	if _view_point(model.position).length()>0.1:push_error("NEAR SURFACE SMOKE FAILED: floating render origin");get_tree().quit(1);return
	var live:=JSON.stringify(_snapshot_game());_sync_planet_visuals()
	if JSON.stringify(_snapshot_game())!=live:push_error("NEAR SURFACE SMOKE FAILED: preview changed progress");get_tree().quit(1);return
	_save_game(false);model=Flight.new();_load_game()
	if not near_surface_view.active or not surface_root.visible or model.credits!=46802:push_error("NEAR SURFACE SMOKE FAILED: orbital reload preview");get_tree().quit(1);return
	mesh_before=surface_root.get_child(0)
	_surface_action()
	if not surface.active or near_surface_view.active or position!=Vector3.ZERO or surface_root.transform!=Transform3D.IDENTITY or surface_root.get_child(0)!=mesh_before:push_error("NEAR SURFACE SMOKE FAILED: incoming common mesh");get_tree().quit(1);return
	_settle_vertical_for_test();_save_game(false);model=Flight.new();_load_game()
	if not surface.active or absf(surface.altitude(model)-1500)>0.01 or model.credits!=46802:push_error("NEAR SURFACE SMOKE FAILED: completed descent reload");get_tree().quit(1);return
	print("NEAR SURFACE SMOKE PASS: shared mesh and camera across outgoing handoff, immutable progress, near-orbit save/reload, shared incoming mesh, completed descent and reload")
	get_tree().quit()

func _view_point(point:Vector3)->Vector3:
	return global_transform*point
