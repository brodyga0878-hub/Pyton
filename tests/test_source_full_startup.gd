extends SceneTree
# Exercise the actual non-automated startup branch with a private user directory.
const World=preload("res://scripts/planetary_system.gd")
const Settings=preload("res://scripts/device_settings.gd")
class MemorySettings extends Settings:
	func load_file()->bool:quality=0;return false
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run()->void:
	if not "--source-startup-isolated" in OS.get_cmdline_user_args() or not OS.get_user_data_dir().contains("source_full_startup"):
		push_error("Run with an isolated source_full_startup XDG directory and -- --source-startup-isolated");quit(1);return
	var game:Node3D=load("res://scenes/main.tscn").instantiate()
	game.settings=MemorySettings.new();game.saves.directory="user://startup-private-%d"%OS.get_process_id()
	root.add_child(game)
	check(not game.automated and game.saving_enabled,"Actual normal startup executes outside capture/test flight mode")
	check(game.world.layout_mode==World.FULL_LAYOUT and game.nav.is_native(),"Normal application starts the complete source world and native sectors")
	check(game.world.system_id==World.SOL_ID and game.world.by_id.has("earth"),"Actual startup constructs original Sol/Earth")
	check(game.world.source_runtime_state.record_bank_slots==128,"Normal startup uses the full original runtime record bank")
	check(not game.ship.station_available and not game.nav.has_station(),"Native arrival does not invent a training station")
	check(game.ship.source_motion_profile and game.ship.acceleration()>70 and game.ship.acceleration()<71,"Normal startup derives the proven native Cobra control bound")
	check(game.flight_console!=null and game.flight_console.buttons.has("dock"),"Preferred lower instrument console is present")
	check(game._save_game(),"Normal startup persists into an isolated private save directory")
	var loaded:Dictionary=game.saves.load_valid(game._decode_state)
	check(not loaded.is_empty(),"Actual normal-startup source save passes full candidate decoding")
	if not loaded.is_empty():check(loaded.world.layout_mode==World.FULL_LAYOUT and loaded.nav.is_native() and loaded.ship.source_motion_profile,"Normal startup restore derives native world, navigation and motion together")
	game.saving_enabled=false;game.queue_free();await process_frame
	print("SOURCE FULL STARTUP TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
