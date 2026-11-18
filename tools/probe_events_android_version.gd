extends SceneTree
# Read the actual exported bytecode with the engine's own parser.
func _initialize()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var script:Variant=load(args[0])
	if not script is GDScript:quit(3);return
	var values:Dictionary=script.get_script_constant_map()
	var result:Dictionary={"version":values.get("VERSION"),"version_code":values.get("VERSION_CODE"),"channel":values.get("CHANNEL"),"actual_exported_bytecode_loaded":true}
	var file:=FileAccess.open(args[1],FileAccess.WRITE)
	if file==null:quit(4);return
	file.store_string(JSON.stringify(result)+"\n");file.close();quit()
