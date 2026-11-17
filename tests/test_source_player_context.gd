extends SceneTree
const Context=preload("res://scripts/source_player_context.gd")
const Player=preload("res://scripts/source_player_dispatch.gd")
const FIXTURE:="res://tests/fixtures/source_player_dispatch_native.json"
const REPORT:="res://build/current-test-reports/source-player-context.json"
var checks:=0
var failures:=0
var contexts:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<24:push_error(message)
func digest(value:Variant)->String:return JSON.stringify(JSON.parse_string(JSON.stringify(value)),"",true).sha256_text()
func root_for(globals:Dictionary,index:int)->PackedByteArray:
	var root:=PackedByteArray();root.resize(Context.ROOT_BYTES);root.fill((index*13+29)&255)
	root.encode_s32(0xdc,int(globals.spin_elapsed_s32));root[0xe8]=int(globals.player_mode_u8);root[0xe9]=int(globals.flight_flags_u8)
	root.encode_s32(0x1b8,int(globals.set_speed_s32));root[0x3fb6]=int(globals.damping_flags_u8)
	for axis in range(3):root.encode_s32(0x88+axis*4,int(globals.reference_velocity_s32[axis]))
	root.encode_u32(0xc0,int(globals.player_index_u32));root.encode_s16(0x210,int(globals.player_roll_s16))
	root.encode_u32(0xe0,int(globals.drift_ticks_low_u32));root.encode_u32(0xe4,int(globals.drift_ticks_high_u32))
	root[0x3f5e]=0x5a;root[0x3f54]=11;root[0x3f55]=22;root[0x3f56]=33
	return root
func external_for(globals:Dictionary)->Dictionary:
	return {"frame_ticks_u32":globals.frame_ticks_u32,"forward_key_u8":globals.forward_key_u8,"reverse_key_u8":globals.reverse_key_u8,"spin_xyz_s32":globals.spin_xyz_s32.duplicate(),"unrelated_owner":{"payload":[4,5,6]},"set_speed_s32":123456,"DATA9030_u8":177}
func run()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));var first:Dictionary={}
	check(Context.ROOT_BYTES==0x4000 and Context.EXTERNAL_KEYS.size()==4,"Common raw root and four required arithmetic externals are explicit")
	for index in range(128):
		var expected:Dictionary=fixture.cases[index].globals_before;var root:=root_for(expected,index);var external:=external_for(expected);var frozen:=var_to_bytes([root,external])
		var actual:=Context.player_globals(root,external);contexts+=1
		check(actual.size()==14 and digest(actual)==digest(expected),"All14 source aliases decode from raw root plus declared external owners: "+str(index))
		check(int(actual.damping_flags_u8)==int(root[0x3fb6]) and int(root[0x3f5e])==0x5a,"DATA9046 damping and DATA9030 root3F5E remain distinct")
		check(int(actual.spin_elapsed_s32)==int(root.decode_s32(0xdc)),"Legacy spin_elapsed name reads HUD/altitude rootDC without accumulating frame time")
		var after:=actual.duplicate(true);after.player_roll_s16=-32768 if index%2 else 32767;after.spin_xyz_s32=[-0x80000000,index,0x7fffffff]
		var result:=Context.apply_player_globals(root,external,after)
		check(result.ok and result.profile==Context.PROFILE,"Restricted callback admits only roll and external scratch updates")
		if result.ok:
			var expected_root:=root.duplicate();expected_root.encode_s16(0x210,int(after.player_roll_s16))
			check(result.root_after==expected_root,"Entire16KiB root changes only the original roll word")
			check(result.root_after.decode_s32(0xdc)==root.decode_s32(0xdc) and result.root_after[0x3f5e]==root[0x3f5e] and result.root_after[0x3fb6]==root[0x3fb6],"RootDC, DATA9030 and damping retain their exact original bytes")
			var expected_external:=external.duplicate(true);expected_external.spin_xyz_s32=after.spin_xyz_s32.duplicate()
			check(digest(result.external_after)==digest(expected_external),"External supersets preserve every unrelated owner while applying scratch")
			check(var_to_bytes([root,external])==frozen,"Applying callbacks leaves raw root and external caller owners unchanged")
			var frozen_after:=var_to_bytes(after);result.root_after[0]=int(result.root_after[0])^255;result.external_after.spin_xyz_s32[0]=0;result.external_after.unrelated_owner.payload[0]=99
			check(var_to_bytes([root,external])==frozen and var_to_bytes(after)==frozen_after,"Returned updated root and external arrays never alias any caller input")
		for key:String in Player.GLOBAL_KEYS:
			if key in ["player_roll_s16","spin_xyz_s32"]:continue
			var invalid:=actual.duplicate(true)
			if key=="reference_velocity_s32":invalid[key][0]=0 if int(invalid[key][0])!=0 else 1
			else:invalid[key]=0 if int(invalid[key])!=0 else 1
			var rejected:=Context.apply_player_globals(root,external,invalid)
			check(not rejected.ok and rejected.reason=="readonly_player_alias_changed","Every readonly alias rejects an attempted callback write: "+key)
		check(var_to_bytes([root,external])==frozen,"Rejected callback aliases preserve all original owners")
		var detached:=Context.player_globals(root,external);detached.spin_xyz_s32[0]=99;detached.reference_velocity_s32[0]=99
		check(var_to_bytes([root,external])==frozen,"Decoded scratch and velocity vectors never alias root or external arrays")
		if first.is_empty():first={"root":root,"external":external,"after":actual}
	check(contexts==128,"Root aliases are checked against128 independent original DOS callback contexts")
	var root:PackedByteArray=first.root;var external:Dictionary=first.external;var after:Dictionary=first.after;var frozen:=var_to_bytes([root,external,after])
	for bad:Variant in [null,true,{},[],1,"root",PackedByteArray()]:
		check(Context.player_globals(bad,external).is_empty() and not Context.apply_player_globals(bad,external,after).ok,"Malformed raw root rejects")
	for size:int in [1,0x3fff,0x4001]:
		var wrong:=PackedByteArray();wrong.resize(size)
		check(Context.player_globals(wrong,external).is_empty() and not Context.apply_player_globals(wrong,external,after).ok,"A raw root with the wrong extent rejects")
	for bad:Variant in [null,true,[],1,"external"]:
		check(Context.player_globals(root,bad).is_empty() and not Context.apply_player_globals(root,bad,after).ok,"Malformed external owner rejects")
	for key:String in Context.EXTERNAL_KEYS:
		var invalid:=external.duplicate(true);invalid.erase(key)
		check(Context.player_globals(root,invalid).is_empty() and not Context.apply_player_globals(root,invalid,after).ok,"Missing required external rejects: "+key)
	for key:String in Context.EXTERNAL_KEYS:
		for bad:Variant in [NAN,INF,true,0.5,"0",-0x80000001,0x100000000]:
			var invalid:=external.duplicate(true);invalid[key]=bad
			check(Context.player_globals(root,invalid).is_empty() and not Context.apply_player_globals(root,invalid,after).ok,"Invalid numeric external rejects: "+key)
	for key:String in Player.GLOBAL_KEYS:
		var invalid:=after.duplicate(true);invalid.erase(key);check(not Context.apply_player_globals(root,external,invalid).ok,"Missing callback output rejects: "+key)
		for bad:Variant in [NAN,INF,true,0.5,"0",-0x80000001,0x100000000]:
			invalid=after.duplicate(true);invalid[key]=bad;check(not Context.apply_player_globals(root,external,invalid).ok,"Invalid numeric callback alias rejects: "+key)
	for key:String in ["player_roll_s16","spin_xyz_s32"]:
		for bad:Variant in [NAN,INF,true,0.5,"0",-0x80000001,0x100000000]:
			var invalid:=after.duplicate(true);invalid[key]=bad;check(not Context.apply_player_globals(root,external,invalid).ok,"Malformed writable callback output rejects: "+key)
	for bad:Variant in [[],[0,0],[0,0,0,0],[0,true,0],[0,NAN,0],[0,-0x80000001,0]]:
		var invalid:=after.duplicate(true);invalid.spin_xyz_s32=bad;check(not Context.apply_player_globals(root,external,invalid).ok,"Malformed scratch vector rejects")
	check(var_to_bytes([root,external,after])==frozen,"All malformed contexts preserve every input byte and array")
	var sources:Dictionary={}
	for path:String in ["scripts/source_player_context.gd","scripts/source_player_dispatch.gd","tests/test_source_player_context.gd",FIXTURE.trim_prefix("res://")]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"profile":Context.PROFILE,"checks":checks,"failures":failures,"raw_alias_contexts":contexts,"sources":sources,"DC_interpreted_as_new_elapsed_time":false,"DATA9030_alias_root3F5E":true,"live_Main_changed":false},"\t"));file.close()
	print("SOURCE PLAYER CONTEXT TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
