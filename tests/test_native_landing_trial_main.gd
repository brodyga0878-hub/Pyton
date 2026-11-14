extends "res://tests/test_source_gear_main.gd"
# Production Main owns mode entry/exit, atomic candidate swaps and separate
# saves. The new source kernels have their independent raw/native test bank.
const NativeSurfaceModel=preload("res://scripts/native_surface_model.gd")
const MAIN_REPORT:="res://build/current-test-reports/native-landing-trial-main.json"
var trial_main_evidence:Array=[]
var trial_directory:="user://native-trial-main-"+str(OS.get_process_id())
var ordinary_store:RecordingStore

func trial_owners()->Array:return [game.ship,game.nav,game.world,game.surface,game.source_motion,game.landing_gear]
func trial_state()->PackedByteArray:
	return var_to_bytes([game.ship.snapshot(),game.nav.snapshot(),game.world.snapshot(),game.surface.snapshot(),game.landing_gear.snapshot(),game.nav.elapsed_days,game.source_motion.snapshot()])
func trial_fresh()->bool:
	if not await stage_gear_surface(40):return false
	game.surface.globe.latitude=0;game.surface.globe.longitude=0
	game.ship.velocity=Vector3.ZERO;game.ship.attitude=Quaternion.IDENTITY;game.ship.target_speed=0;game.ship.assisted=false
	ordinary_store=RecordingStore.new();ordinary_store.directory=trial_directory+"/ordinary";game.saves=ordinary_store
	game.native_saves.directory=trial_directory+"/native";game.native_saves.sequence=0
	game.saving_enabled=true
	return true
func main_landing_and_return()->void:
	if not await trial_fresh():return
	var original:=trial_owners();var before:=trial_state();var old_hp:=thermal();var old_fuel:=fuel();var old_days:float=game.nav.elapsed_days
	check(game._start_native_landing_trial(),"Actual Main starts a separate native landing trial from current Earth source frame")
	check(game._native_surface_active() and not game.native_trial_return.is_empty(),"Main marks explicit native trial and retains ordinary return owners")
	if not game._native_surface_active():return
	check(game.surface is NativeSurfaceModel and game.ship!=original[0] and game.nav!=original[1] and game.surface!=original[3] and game.landing_gear!=original[5],"Trial starts with private Flight/Nav/Surface/Gear owners")
	var ordinary_generation:int=ordinary_store.sequence;var ordinary_payload:=ordinary_store.last_payload.duplicate(true)
	game._close_menu();var scheduled_days:float=game.nav.elapsed_days;var scheduled_generation:int=game.surface.native_session.generation()
	game.flight_time.request_rate(100);game._advance_controls(0.3)
	check(game.surface.native_session.generation()==scheduled_generation+3 and absf(game.nav.elapsed_days-scheduled_days-0.3/86400.0)<1e-15,"Real frame scheduler executes all three native substeps despite atomic Flight owner swaps")
	check(game.flight_time.effective_rate==1 and game.flight_time.pending_real_seconds==0 and game.flight_time._plan.is_empty(),"Native manual trial consumes the complete frame in ordinary time without catch-up debt")
	game._request_landing_gear(true);check(game._step_landing_gear(3.0),"Trial uses actual original gear command and scheduler before descent")
	game._close_menu();game.ship.assisted=false
	var start_y:float=game.ship.position.y;var contact_tick:=-1
	for tick in range(140):
		game._tick(0.1,Vector2.ZERO,0)
		if game.surface.landed:contact_tick=tick+1;break
	check(contact_tick>0 and game.surface.landed and game.ship.position.y<start_y,"Actual Main _tick flies the native 50m descent into original accepted contact")
	check(game.ship.hull==100 and int(thermal().hull_u16)==400,"Main healthy native contact preserves existing shared raw hull")
	check(ordinary_store.sequence==ordinary_generation and ordinary_store.last_payload==ordinary_payload,"Trial ticks/autosaves never replace the ordinary save slot")
	check(game._native_save_game(),"Production Main writes the accepted native contact to its separate real SaveStore")
	var saved_pose:Vector3=game.ship.position;var saved_surface:Dictionary=game.surface.snapshot();var saved_gear:Dictionary=game.landing_gear.snapshot();var saved_nav:Dictionary=game.nav.snapshot();var saved_ship:Dictionary=game.ship.snapshot()
	var generation:int=game.surface.native_session.generation();game._tick(0.1,Vector2.ZERO,0)
	check(game.surface.landed and game.surface.native_session.generation()==generation and game.ship.position==saved_pose,"Main parked _tick retains accepted raw pose without replaying classification")
	check(game.native_saves.write(copied(ordinary_payload)),"A valid ordinary save is deliberately placed in the newest private native slot as a wrong-mode recovery control")
	check(game._load_native_landing_trial(),"Production Main cold-loads the separate native save through the real whole-game factory")
	check(game._native_surface_active() and game.surface.landed and game.ship.position==saved_pose,"Actual native cold load preserves the accepted parked response pose")
	check(game.surface.snapshot()==saved_surface and game.landing_gear.snapshot()==saved_gear and game.nav.snapshot().source_hyperdrive==saved_nav.source_hyperdrive and game.ship.snapshot()==saved_ship,"Native cold Main load retains exact source witness, HP/RNG/fuel/gear and phone state")
	var cold_payload:Dictionary=copied(payload());var cold_owners:=trial_owners();var protected:=trial_state()
	check(game._decode_primary_state(cold_payload).is_empty() and game._decode_native_trial_state(copied(ordinary_payload)).is_empty(),"Typed production save validators reject a valid save belonging to the other mode")
	var malformed:=cold_payload.duplicate(true);malformed.navigation.elapsed_days=float(malformed.navigation.elapsed_days)+0.1/86400.0
	check(game._decode_state(malformed).is_empty(),"Main native cold factory rejects a mismatched exact surface/Navigation clock")
	malformed=cold_payload.duplicate(true);malformed.gear_session.position_u16=65534
	check(game._decode_state(malformed).is_empty(),"Main native cold factory rejects a parked source pose with incomplete physical gear")
	check(trial_owners()==cold_owners and trial_state()==protected,"Rejected native cold candidates preserve all current owner references and exact state")
	check(game._takeoff_action() and game.ship.position==saved_pose,"Actual takeoff command queues powered departure without an instant position jump")
	game._tick(0.1,Vector2.ZERO,0,1)
	check(not game.surface.landed and game.ship.velocity.y>0 and game.ship.hull==100,"Actual Main _tick releases restored park using available lift and preserves hull")
	game.ship.position.x=1e9;protected=trial_state();var rejected_owners:=trial_owners()
	game._tick(0.1,Vector2.ZERO,0,1)
	check(not game.source_contact_error.is_empty() and trial_owners()==rejected_owners and trial_state()==protected,"An actual Main out-of-chart interval keeps every live owner and reports its explicit rejection")
	game._advance_controls(0.3)
	check(trial_owners()==rejected_owners and trial_state()==protected and game.flight_time._plan.is_empty() and game.flight_time.pending_real_seconds==0,"Rejected native frame closes its scheduler plan without counting a failed substep or adding time debt")
	check(game._exit_native_landing_trial(),"Actual Main returns from the trial through its explicit exit action")
	check(trial_owners()==original and trial_state()==before,"Leaving trial restores every original model reference and exact ordinary state")
	check(thermal()==old_hp and fuel()==old_fuel and game.nav.elapsed_days==old_days,"Trial landing/save/load/launch cannot charge ordinary HP/fuel/RNG/time")
	check(ordinary_store.sequence==ordinary_generation and ordinary_store.last_payload==ordinary_payload,"Mode exit retains the original ordinary save bytes and generation")
	trial_main_evidence.append({"case":"actual_Main_native_descent_separate_save_cold_takeoff_return","descent_intervals":contact_tick,"native_generation":generation,"source_pose":str(saved_pose),"ordinary_owners_restored":true,"ordinary_save_generation":ordinary_generation})

func native_report_zip()->void:
	if not await trial_fresh():return
	check(game._start_native_landing_trial(),"Report fixture enters actual Main native mode")
	if not game._native_surface_active():return
	game._close_menu();game._tick(0.1,Vector2.ZERO,0)
	game.diagnostics.directory=trial_directory+"/diagnostics";game.diagnostics.reports_directory=trial_directory+"/reports";game.diagnostics.engine_logs_directory=trial_directory+"/empty-logs"
	check(game.diagnostics.initialize("native-trial-main-validation"),"Actual collector initializes only private test diagnostics")
	var protected:=trial_state();var complete:Dictionary=copied(payload())
	game.report_include_save=true;game.report_draft="Проверка исходной посадки: полный снимок геометрии, целочисленных состояний и управления."
	game._show_bug_report();await game._create_bug_report(false)
	check(game.current_report.get("ok",false),"Production button builds an offline ZIP with the native trial snapshot")
	if game.current_report.get("ok",false):
		var zip:=ZIPReader.new();check(zip.open(str(game.current_report.path))==OK,"Actual native bug-report ZIP opens")
		check(zip.file_exists("game-save.json") and zip.file_exists("report.json") and zip.file_exists("manifest.json"),"Report contains reproducible native save plus context and checksum manifest")
		if zip.file_exists("game-save.json"):
			var contents:=zip.read_file("game-save.json").get_string_from_utf8();var saved:Dictionary=JSON.parse_string(contents)
			check(saved==complete and not contents.contains("[depth limit]") and not contents.contains("[unsupported value]"),"Top-level optional native save preserves every raw/source leaf witness without context truncation")
			check(saved.surface.session==complete.surface.session and saved.surface.provider==complete.surface.provider,"Actual ZIP retains exact raw body/history and full bound source geometry")
			check(not game._decode_state(saved).is_empty(),"The real whole-game factory can validate the native save directly from its diagnostic archive")
		zip.close()
	check(trial_state()==protected,"Creating the actual native diagnostic archive changes no flight/HP/RNG/fuel/gear/clock state")
	check(game._exit_native_landing_trial(),"Report mode returns to the ordinary source surface")
	trial_main_evidence.append({"case":"production_native_include_save_ZIP","archive":str(game.current_report.get("filename","")),"complete_native_witness_transport":true})

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Actual Main trial tests start in private capture mode without player progress")
	await main_landing_and_return();await native_report_zip()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/native_landing_trial.gd","scripts/native_surface_model.gd","scripts/source_natural_contact_session.gd","scripts/source_native_surface_provider.gd","tests/test_native_landing_trial_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAIN_REPORT.get_base_dir()));var report:=FileAccess.open(MAIN_REPORT,FileAccess.WRITE)
	if report:report.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":trial_main_evidence,"sources":sources,"scope":"Production Main native manual mode, source descent, separate save/cold factory, queued takeoff, exact ordinary return and optional diagnostic ZIP; no full bank/autopilot/Android claim"},"\t"))
	game.queue_free();await frame();print("Native landing trial Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
