extends SceneTree
# Actual Main, with persistence disabled by --rebuild-capture. No save/report IO.
var game:Node3D
var checks:=0
var failures:=0
var original_quality:=2
var original_save_directory:=""
var original_save_generation:=0

func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func payload()->String:return JSON.stringify(game._payload())
func references()->Array:return [game.ship,game.nav,game.world,game.surface]
func normal_field_absent(unbuilt:bool,message:String)->void:
	check(game.graphics_return.is_empty() and not game.space_environment.visible,message+": normal flight hides decorative field")
	if unbuilt:
		check(game.space_environment.asteroid_count==0 and game.space_environment.get_child_count()==0,message+": no decorative geometry allocated")
func material_geometry(node:Node,result:Array)->void:
	if node is MeshInstance3D and node.mesh!=null:
		var surfaces:Array=[]
		for surface in range(node.mesh.get_surface_count()):
			surfaces.append(node.mesh.surface_get_arrays(surface))
		result.append([str(node.name),surfaces])
	for child in node.get_children():material_geometry(child,result)
func geometry_digest(node:Node)->String:
	var geometry:Array=[];material_geometry(node,geometry)
	return var_to_bytes(geometry).hex_encode().sha256_text()
func assign_materials(node:Node,library:Script)->int:
	var count:=0
	if node is MeshInstance3D and node.mesh!=null:
		for surface in range(node.mesh.get_surface_count()):
			var material:Material=node.get_active_material(surface)
			if material==null:continue
			if material is ShaderMaterial:
				# The hull shader consumes these channels. Jets/halos have separate shaders.
				if material.shader.resource_path.ends_with("ship_hull.gdshader"):
					if library.apply_shader(material,"painted_alloy",1.0):count+=1
					else:check(false,"Hull material maps load and assign successfully")
			elif material is StandardMaterial3D:
				if library.apply_standard(material,"brushed_metal",1.0):count+=1
				else:check(false,"Standard material maps load and assign successfully")
	for child in node.get_children():count+=assign_materials(child,library)
	return count
func quality_keeps_state(unbuilt:bool,label:String)->void:
	var before:=payload();var original:=references()
	for quality in [0,1,2]:
		game.settings.quality=quality;game._apply_settings();game._sync_scene()
		check(game.player.get("_quality")==quality and game.station.quality==quality,label+": quality reaches existing visuals")
		check(payload()==before and references()==original,label+": quality preserves all four model payloads and identities")
		normal_field_absent(unbuilt,label)
func fresh_flight()->void:
	check(not game.ship.external_view,"New normal flight inherits FlightModel's first-person camera default")
	check(game.ship.DOCK_RADIUS==100.0 and game.ship.DOCK_SPEED==12.0 and game.ship.MAX_SPEED==600.0,"Docking and flight limits retain their established values")
	check(game.ship.STATION==Vector3(0,0,-2500),"Existing station/docking target is unchanged")
	normal_field_absent(true,"Initial state")
	quality_keeps_state(true,"Fresh flight")
	var before:=payload()
	game._show_routes();game._show_system();game._show_menu();game._close_menu()
	check(payload()==before,"Opening route, system and commander menus does not alter the flight")
	normal_field_absent(true,"Normal menus")
func material_assignment_keeps_geometry()->void:
	game.settings.quality=2;game._apply_settings()
	var before:=payload();var original:=references()
	var hull_before:=geometry_digest(game.player.hull_mesh)
	var ship_before:=geometry_digest(game.player)
	var station_before:=geometry_digest(game.station)
	check(int(game.player.geometry_stats.triangles)==7534,"High quality retains the existing 7534-triangle reconstructed hull")
	var library:Script=load("res://scripts/material_library.gd")
	check(library!=null,"Real material library is available")
	if library!=null:
		check(assign_materials(game.player,library)>0 and assign_materials(game.station,library)>0,"Real material maps assign to existing ship and station surfaces")
	check(geometry_digest(game.player.hull_mesh)==hull_before,"Material assignment preserves hull vertex, normal, UV and index bytes")
	check(geometry_digest(game.player)==ship_before,"Material assignment preserves ship and landing-gear geometry bytes")
	check(geometry_digest(game.station)==station_before,"Material assignment preserves station geometry bytes")
	check(payload()==before and references()==original,"Material assignment leaves all four flight models unchanged")
	game.player.configure(game.ship.profile());game.station.configure(2)
	check(geometry_digest(game.player)==ship_before and geometry_digest(game.station)==station_before,"Visual reconfiguration reuses identical geometry at the same quality")
	print("GRAPHICS SCOPE GEOMETRY: hull=%s ship=%s station=%s"%[hull_before,ship_before,station_before])
func preview_isolation()->void:
	game.ship.credits=1789;game.ship.goods.food=3
	game._start_jump(int(game.nav.galaxy.all()[1].id))
	check(game.nav.remaining>0,"Normal route selection still begins a pending hypercharge")
	quality_keeps_state(true,"Pending route")
	var before:=payload();var original:=references()
	game._begin_graphics_demo()
	check(not game.graphics_return.is_empty() and references()!=original,"Optional demo enters with separate models")
	check(game.ship!=original[0] and game.nav!=original[1] and game.world!=original[2] and game.surface!=original[3],"Demo replaces all four models without mutating the paused originals")
	check(game.ship.external_view and game.space_environment.visible,"Optional demo explicitly selects external view and decorative asteroids")
	check(game.space_environment.asteroid_count==275 and game.space_environment.get_child_count()>0,"Decorative geometry builds lazily for the high-quality optional demo")
	check(not game.saving_enabled,"Demo cannot replace saved normal progress")
	var demo_before:=payload()
	for quality in [0,2]:
		game.settings.quality=quality;game._apply_settings();game._sync_scene()
		check(game.space_environment.visible and game.space_environment.quality==quality,"Demo quality updates the explicitly enabled decorative field")
		check(payload()==demo_before,"Demo quality remains a visual operation")
	game._tick(0.5,Vector2(0.2,0.1),0)
	game._end_graphics_demo()
	check(references()==original and payload()==before,"Exiting demo restores exact original model identities and payload bytes")
	check(not game.ship.external_view and game.nav.remaining>0,"Normal first-person view and pending route restore after demo")
	normal_field_absent(false,"Return from demo")
	quality_keeps_state(false,"Returned route")
func normal_actions_after_preview()->void:
	game._brake();game._choose_site("site10")
	check(game.world.pending_site_id=="site10" and game.world.transfer_remaining>0,"Existing site-selection transfer still works after preview")
	quality_keeps_state(false,"Pending source-site transfer")
	game._brake();game._new_models();game._apply_system()
	check(not game.ship.external_view,"Another normal new flight also keeps the model camera default")
	normal_field_absent(false,"New flight after preview")
	game.ship.position=game.ship.STATION;game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0
	game._dock_action()
	check(game.ship.docked,"Existing docking action still succeeds at its original physical target")
	quality_keeps_state(false,"Docked flight")
	check(game._payload().schema=="starfrontier-rebuild-game-v1" and game.saves.SCHEMA=="starfrontier-rebuild-save-v1","Game and save serialization schema remain unchanged")
func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Use -- --rebuild-capture");quit(1);return
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	check(game.automated and not game.saving_enabled,"Actual Main runs without user save or diagnostics writes")
	original_quality=game.settings.quality;original_save_directory=game.saves.directory;original_save_generation=game.saves.sequence
	fresh_flight();material_assignment_keeps_geometry();preview_isolation();normal_actions_after_preview()
	check(not game.saving_enabled and game.saves.sequence==original_save_generation and game.saves.directory==original_save_directory,"All scope checks retain disabled persistence, save generation and directory")
	game.settings.quality=original_quality
	game.queue_free();await process_frame
	print("GRAPHICS SCOPE TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
