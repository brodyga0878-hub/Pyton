func _view_point(point:Vector3)->Vector3:
	return global_transform*point

func _run_far_surface_smoke()->void:
	help_panel.hide();resume_panel.hide();model=Flight.new();model.docked=false;model.credits=57913
	nav=Navigation.new();economy=Economy.new();combat=Combat.new();surface=Surface.new();campaign=Campaign.new();planetary=Planetary.new();planetary.configure(nav.current());planetary.site_id="site10"
	surface.enter(model,planetary,true);model.position.y=surface.height_at(0,0)+surface.clearance(model)+700;model.velocity=Vector3.ZERO
	surface.leave(model,planetary,nav.elapsed_days);planetary.site_id=""
	var center:Vector3=planetary.local_meters(planetary.focus_id,nav.elapsed_days)
	var radial:Vector3=(model.position-center).normalized();var radius:float=planetary.by_id[planetary.focus_id].radius_km*1000.0
	var previous:=-1.0
	for height in [20000,23800,30000,41900,50000,59990]:
		model.position=center+radial*(radius+height);_apply_system();celestial_root.update_view(nav.elapsed_days,model.position)
		if not near_surface_view.active or near_surface_view.space_blend<previous:push_error("FAR SURFACE SMOKE FAILED: outward transition");get_tree().quit(1);return
		previous=near_surface_view.space_blend
		if celestial_root.visuals[planetary.focus_id].anchor.position.distance_to(center)>1:push_error("FAR SURFACE SMOKE FAILED: missing physical baseline");get_tree().quit(1);return
	model.position=center+radial*(radius+41900);_apply_system()
	var weight:float=near_surface_view.space_blend;_save_game(false);model=Flight.new();_load_game()
	if not near_surface_view.active or absf(near_surface_view.space_blend-weight)>0.001 or model.credits!=57913:push_error("FAR SURFACE SMOKE FAILED: blend reload");get_tree().quit(1);return
	model.position=center+radial*(radius+61000);_apply_system()
	var before:=JSON.stringify(_snapshot_game());_surface_action()
	if surface.active or JSON.stringify(_snapshot_game())!=before:push_error("FAR SURFACE SMOKE FAILED: out-of-band descent guard");get_tree().quit(1);return
	model.position=center+radial*(radius+61000);_apply_system();celestial_root.update_view(nav.elapsed_days,model.position)
	if near_surface_view.active or surface_root.visible or _view_point(model.position).length()>0.1:push_error("FAR SURFACE SMOKE FAILED: far endpoint and floating origin");get_tree().quit(1);return
	model.position=center+radial*(radius+20000);model.velocity=Vector3.ZERO;_apply_system();_surface_action()
	if not surface.active or surface.flight_phase!="descent":push_error("FAR SURFACE SMOKE FAILED: inward return");get_tree().quit(1);return
	_settle_vertical_for_test();_save_game(false);model=Flight.new();_load_game()
	if not surface.active or absf(surface.altitude(model)-1500)>0.01 or model.credits!=57913:push_error("FAR SURFACE SMOKE FAILED: return reload");get_tree().quit(1);return
	print("FAR SURFACE SMOKE PASS: outward blend and physical baseline, midband save/reload, guarded descent, far endpoint with floating origin, inward return and descent reload")
	get_tree().quit()
