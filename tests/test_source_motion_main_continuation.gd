extends SceneTree
# Focused actual Main save/restore continuation regression; no disk saves.
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
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires safe capture mode");quit(1);return
	var game:Node3D=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await process_frame
	check(game.automated and not game.saving_enabled,"Focused Main continuation does not touch user saves")
	game._new_models(World.FULL_LAYOUT);game._apply_system();game.ship.velocity=Vector3(0.00123,-0.00234,0.00345);game.ship.assisted=false
	game._tick(0.0073,Vector2.ZERO,0)
	# Includes the original failing7.3ms→save→9.1ms case and further rotated
	# save points, so restoring an identity quaternion is not the only control.
	for index in range(3):
		var saved:Dictionary=JSON.parse_string(JSON.stringify(game._payload()));var before:Dictionary=game.source_motion.snapshot();var before_days:float=game.nav.elapsed_days
		var decoded:Dictionary=game._decode_state(saved)
		check(not decoded.is_empty(),"Actual Main decoder accepts source continuation %d"%index)
		if decoded.is_empty():break
		check(decoded.source_motion.snapshot()==before,"Every raw/fractional/IEEE64 word survives isolated JSON decode %d"%index)
		check(decoded.nav.elapsed_days==before_days and decoded.nav.elapsed_days==decoded.source_motion.elapsed_days(),"Validated motion IEEE64 clock restores exact Navigation time %d"%index)
		var dt:float=[0.0091,0.0237,0.0893][index];var steering:=Vector2(0.2,-0.1);var roll:=0.07
		game._tick(dt,steering,roll)
		var expected:Dictionary=game.source_motion.snapshot();var expected_position:Vector3=game.ship.position;var expected_velocity:Vector3=game.ship.velocity;var expected_attitude:Quaternion=game.ship.attitude;var expected_days:float=game.nav.elapsed_days
		game._commit_state(decoded);game._apply_system()
		check(game.source_motion.snapshot()==before and game.nav.elapsed_days==before_days,"Commit and actual system refresh retain exact raw state/time %d"%index)
		game._tick(dt,steering,roll)
		var actual:Dictionary=game.source_motion.snapshot()
		check(expected_position==game.ship.position and expected_velocity==game.ship.velocity,"Next-step displayed translation is identical %d"%index)
		check(expected_attitude==game.ship.attitude,"Next-step phone quaternion is identical %d"%index)
		check(expected.motion==actual.motion,"Next-step entire338byte body and parent are identical %d"%index)
		check(expected_days==game.nav.elapsed_days and expected.elapsed_days_f64_hex==actual.elapsed_days_f64_hex,"Next-step canonical source and navigation clocks are identical %d"%index)
		check(expected.ticks_fraction_f64_hex==actual.ticks_fraction_f64_hex and expected==actual,"Next-step exact raw session continues deterministically %d"%index)
	game.queue_free();await process_frame
	print("SOURCE MOTION MAIN CONTINUATION TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
