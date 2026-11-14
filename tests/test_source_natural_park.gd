extends SceneTree
const Park=preload("res://scripts/source_natural_park.gd")
const Natural=preload("res://scripts/source_natural_contact.gd")
const FIXTURE:="res://tests/fixtures/source_contact_lifecycle_native.json"
const REPORT:="res://build/current-test-reports/source-natural-park.json"
var checks:=0
var failures:=0
var counts:={"native_acceptances":0,"native_state32_cold_ticks":0,"native_sound_cases":0}
var first:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<30:push_error(label)
func callbacks(value:Array,function_name:String)->Array:
	var result:Array=[]
	for call:Dictionary in value:
		if call.function==function_name:result.append(call.arguments_u32)
	return result
func run()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.source_sha256==Natural.SOURCE_SHA and fixture.native_fresh_process_runs_per_bank==3,"The separate park oracle identifies original executable bytes and three native runs")
	for sample:Dictionary in fixture.actor_cases:
		var native:Dictionary=sample.expected.natural_continuation
		if not native.executed:continue
		var body:=str(sample.expected.body_after_f575_hex).hex_decode();var parent:=str(sample.parent_object_hex).hex_decode();var root:=str(native.game_root_before_hex).hex_decode()
		var context:={"collision_flags_u8":int(sample.expected.canonical.globals.collision_flags_u8),"body_pointer_u32":int(native.body_pointer_u32),"parent_pointer_u32":int(native.parent_pointer_u32),"parent_index_u8":int(parent[0x86]),"source_flags_8860_u8":int(native.source_flags_8860_before_u8),"control_8918_s32":int(native.source_8918_before_s32),"reference_policy":"native-captured-pointer-word-v1"}
		var before:=var_to_bytes([body,parent,root,context]);var parked:=Park.accept(body,parent,root,context);counts.native_acceptances+=1
		check(parked.ok and parked.body_after.hex_encode()==sample.expected.canonical.player_hex and parked.game_root_after.hex_encode()==native.game_root_hex,"The actual original accepted fragment and F1042 agree on every body/root byte: "+str(sample.id))
		check(var_to_bytes([body,parent,root,context])==before,"Pure accepted source park leaves all caller buffers untouched")
		var observed:Dictionary=JSON.parse_string(JSON.stringify({"ui":callbacks(parked.callbacks,"F48"),"sound":callbacks(parked.callbacks,"F1910")}))
		check(parked.control_8918_after_s32==int(native.source_8918_after_s32) and observed.ui==native.ui_f48_requests and observed.sound==native.sound_f1910_requests,"Original control reset and ordered UI/sound argument words match the native observations")
		if not native.sound_f1910_requests.is_empty():counts.native_sound_cases+=1
		for offset:int in [0xec,0xee,0xf0]:check(parked.body_after.decode_u16(offset)==body.decode_u16(offset),"Original F1042 preserves every source fractional velocity word")
		var held_context:=context.duplicate(true);held_context.control_8918_s32=0
		var held:=Park.parked_tick(parked.body_after,parent,parked.game_root_after,held_context)
		check(held.ok and held.body_after==parked.body_after and held.game_root_after==parked.game_root_after and held.callbacks.is_empty(),"The source state32 F1030 RET tick has no movement, query, command or reset")
		if first.is_empty():first={"body":body,"parent":parent,"root":root,"context":context,"parked":parked}
	for sample:Dictionary in fixture.parked_tick_cases:
		var native:Dictionary=sample.expected.natural_continuation;var body:=str(sample.player_object_hex).hex_decode();var parent:=str(sample.parent_object_hex).hex_decode();var root:=str(native.game_root_before_hex).hex_decode()
		var context:={"collision_flags_u8":int(sample.context.initial_globals.collision_flags_u8),"body_pointer_u32":int(native.body_pointer_u32),"parent_pointer_u32":int(native.parent_pointer_u32),"parent_index_u8":int(parent[0x86]),"source_flags_8860_u8":int(native.source_flags_8860_before_u8),"control_8918_s32":int(native.source_8918_before_s32),"reference_policy":"native-captured-pointer-word-v1"}
		var result:=Park.parked_tick(body,parent,root,context);counts.native_state32_cold_ticks+=1
		check(result.ok and result.body_after.hex_encode()==sample.expected.canonical.player_hex and result.game_root_after.hex_encode()==native.game_root_hex and result.control_8918_after_s32==int(native.source_8918_after_s32) and result.callbacks.is_empty(),"An independently cold-restored native source32 tick preserves exact raw state")
	if not first.is_empty():
		var row:Dictionary=first;var original:=var_to_bytes(row)
		for flag:int in [0,2,0x20,0x60,0x80]:
			var changed:Dictionary=row.context.duplicate(true);changed.collision_flags_u8=flag;var result:=Park.accept(row.body,row.parent,row.root,changed)
			check(not result.ok and result.body_after==row.body and result.game_root_after==row.root and result.callbacks.is_empty(),"Unsupported flags cannot enter the accepted-natural source branch")
		var changed:PackedByteArray=row.root.duplicate();changed[0xe8]=0x2c;check(not Park.accept(row.body,row.parent,changed,row.context).ok,"Source state2C preceding guard excludes the natural accepted branch")
		var context:Dictionary=row.context.duplicate(true);context.parent_index_u8=(int(row.parent[0x86])+1)&255;check(not Park.accept(row.body,row.parent,row.root,context).ok,"A wrong selected parent index cannot bind a source pointer word")
		context=row.context.duplicate(true);context.source_flags_8860_u8=int(row.root[0xc6])^0x80;check(not Park.accept(row.body,row.parent,row.root,context).ok,"The actual game-root DATA8860 byte cannot be replaced by a conflicting caller sound flag")
		context=row.context.duplicate(true);context.reference_policy="isolated-parent-reference-word-v1";check(not Park.accept(row.body,row.parent,row.root,context).ok,"Actual native address words cannot masquerade as isolated index references")
		check(var_to_bytes(row)==original,"Rejected park operands preserve the private native reference fixture")
		var copied:=Park.accept(row.body,row.parent,row.root,row.context);copied.body_after[0]=0;copied.game_root_after[0]=1;copied.callbacks.clear();check(Park.accept(row.body,row.parent,row.root,row.context)==row.parked,"Returned source park buffers and callback arrays are independent copies")
	check(counts.native_acceptances==fixture.parked_cold_tick_case_count and counts.native_state32_cold_ticks==fixture.parked_cold_tick_case_count and counts.native_sound_cases>0,"Every accepted/cold tick bank and the actual optional station-noise callback complete")
	var pins:Dictionary={}
	for path:String in ["scripts/source_natural_park.gd","tests/test_source_natural_park.gd","tests/fixtures/source_contact_lifecycle_native.json"]:pins[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE);file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"counts":counts,"sources":pins,"scope":"Actual original F1021 JUMP4228 accepted natural branch, F1042 resets and F1030 state32 RET only; native byte-exact body/root and command arguments, explicit captured pointer-word bindings. No full F1021 dispatcher/object bank, executed sound/UI, native launch/F1047, HP/fuel/time or Main/Android proof."},"\t"));file.close();print("Natural park: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
