extends SceneTree
# Mount an independently exported pack and hash its compiled scripts directly.
func _initialize()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:quit(2);return
	var paths:Variant=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not paths is Array or not ProjectSettings.load_resource_pack(args[0],true):quit(3);return
	var hashes:Dictionary={}
	for path:Variant in paths:
		if not path is String or not path.begins_with("scripts/") or not path.ends_with(".gd"):quit(4);return
		var compiled:="res://"+str(path).trim_suffix(".gd")+".gdc"
		var bytes:=FileAccess.get_file_as_bytes(compiled)
		if bytes.size()<=64 or bytes.slice(0,4).get_string_from_ascii()!="GDSC":quit(5);return
		hashes[path]=FileAccess.get_sha256(compiled)
	var file:=FileAccess.open(args[2],FileAccess.WRITE)
	if file==null:quit(6);return
	file.store_string(JSON.stringify(hashes)+"\n");file.close();quit()
