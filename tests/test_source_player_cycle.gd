extends SceneTree
const Cycle=preload("res://scripts/source_player_cycle.gd")
const Context=preload("res://scripts/source_player_context.gd")
const Phase=preload("res://scripts/source_player_phase.gd")
const PlayerInput=preload("res://scripts/source_player_input.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_player_cycle_native.json"
const FIXTURE_SHA:="c1ed973184be474bcbe6a2ce3dad324aeec3fa4c7cd25fad6dbe53372c171512"
const INPUT_FIXTURE:="res://tests/fixtures/source_player_input_native.json"
const INPUT_FIXTURE_SHA:="6644b8eaec991b79a28c6b26e3be8f1e8b2303a21f9fdb5d21019b6e8b6cfeb8"
const REPORT:="res://build/current-test-reports/source-player-cycle.json"
var checks:=0
var failures:=0
var native_cases:=0
var cold_cases:=0
var input_value_cases:=0
var proof_dependencies:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<28:push_error(message)
func digest(value:Dictionary)->String:return Clock._hash(value)
func blank_payload()->Dictionary:return {"mode_observations":[],"phase_observations":[],"gui_samples":[],"contacts":[]}
func base_core()->Dictionary:
	var body:=PackedByteArray();body.resize(338);body[0x86]=1;body.encode_u16(0x9e,10);body.encode_u32(0xa8,3);body.encode_u32(0xac,1);body.encode_u32(0x8c,1024)
	var parent:=PackedByteArray();parent.resize(338);parent[0x86]=2
	var root:=PackedByteArray();root.resize(Context.ROOT_BYTES);root.encode_u32(0xc0,1);root.encode_u32(0xc8,1);root.encode_u32(0xcc,2);root[0xe8]=44
	return {"body_hex":body.hex_encode(),"parent_hex":parent.hex_encode(),"root_hex":root.hex_encode(),"external":{"frame_ticks_u32":7,"system_frame_ticks_u32":11,"speed_multiplier_u32":16,"forward_key_u8":255,"reverse_key_u8":255,"throttle_key_u8":255,"aux_key1_u8":255,"aux_key2_u8":255,"mouse_buttons_u8":255,"input_gate_s8":-1,"spin_xyz_s32":[0,0,0],"transfer_state_u32":0,"saved_flight_flags_u32":0,"effect_gate_s32":0,"action_a_u32":0,"action_b_u32":0},"clock":{"tick_u32":10,"day_u32":1}}
func configure(owner:RefCounted,core:Dictionary)->bool:return owner.configure(str(core.body_hex).hex_decode(),str(core.parent_hex).hex_decode(),str(core.root_hex).hex_decode(),core.external,core.clock)
func signed_snapshot(data:Dictionary)->Dictionary:
	var copied:=data.duplicate(true);copied.erase("snapshot_sha256");copied.snapshot_sha256=digest(copied);return copied
func altered_hex(value:String,offset:int)->String:
	var bytes:=value.hex_decode();bytes[offset]=int(bytes[offset])^1;return bytes.hex_encode()
func ownership()->void:
	var core:=base_core();var payload:=blank_payload();var frozen:=var_to_bytes([core,payload]);var owner:=Cycle.new()
	check(not owner.is_active() and owner.generation()==0 and owner.snapshot().is_empty() and owner.raw_core().is_empty(),"Fresh owner has no implicit initialized game context")
	check(not owner.prepare("control",payload).ok and not owner.commit({}),"Inactive owner rejects commands and commits")
	check(configure(owner,core) and owner.is_active() and owner.generation()==0,"Explicit raw context configures the owner")
	var initial:=owner.snapshot();var initial_hash:=digest(initial)
	var first:=owner.prepare("control",payload)
	check(first.ok,"Owned control composes F1009 with actual source F1044")
	if not first.ok:return
	check(owner.generation()==0 and digest(owner.snapshot())==initial_hash,"Preparing a real control does not mutate the live owner")
	check(first.candidate_state.generation()==1 and first.receipt.generation_after==1 and first.receipt.selected_function_id_u32==1044 and first.receipt.phase_source_order==["F1044","F1045","F1512"],"Candidate identifies the actual selected drift phase and source procedures")
	check(var_to_bytes([core,payload])==frozen,"Configure and prepare keep all caller-owned raw context and payload unchanged")
	var duplicate:=owner.raw_core();duplicate.external.spin_xyz_s32[0]=99;duplicate.root_hex="00"
	check(digest(owner.snapshot())==initial_hash,"Raw-core copies cannot mutate the owner")
	var snap_copy:=owner.snapshot();snap_copy.core.external.spin_xyz_s32[0]=99
	check(digest(owner.snapshot())==initial_hash,"Portable snapshots cannot alias owned context")
	var candidate_copy:Dictionary=first.candidate_state.raw_core();candidate_copy.external.spin_xyz_s32[0]=99
	check(first.candidate_state.raw_core().external.spin_xyz_s32[0]!=99,"Candidate accessors preserve independent ownership")
	var peer:=Cycle.new();check(configure(peer,core),"Second independent owner configures")
	check(not peer.commit(first) and digest(peer.snapshot())==initial_hash,"A receipt from another live owner cannot commit")
	var forged:=first.duplicate(true);forged.receipt=forged.receipt.duplicate(true);forged.receipt.generation_after=2
	check(not owner.commit(forged) and digest(owner.snapshot())==initial_hash,"A modified receipt fails deterministic replay without mutation")
	for key:String in ["owner_instance_id","owner_revision","before_generation","before_core_sha256","profile"]:
		forged=first.duplicate(true);forged[key]=0 if key!="profile" and key!="before_core_sha256" else "forged"
		if key=="before_generation":forged[key]=1
		check(not owner.commit(forged) and digest(owner.snapshot())==initial_hash,"Forged transaction context rejects: "+key)
	forged=first.duplicate(true);forged.candidate_state=owner
	check(not owner.commit(forged),"Live owner cannot be supplied as its own prepared candidate")
	forged=first.duplicate(true);forged.candidate_state=RefCounted.new()
	check(not owner.commit(forged),"A foreign candidate script cannot commit")
	var candidate_before:Dictionary=first.candidate_state.snapshot();var corrupted:Dictionary=candidate_before.duplicate(true);corrupted.core.body_hex=altered_hex(corrupted.core.body_hex,0)
	check(not first.candidate_state.restore(signed_snapshot(corrupted)) and digest(first.candidate_state.snapshot())==digest(candidate_before),"Rehashed candidate with forged raw output fails original command replay")
	var competing:=owner.prepare("control",payload)
	check(competing.ok and owner.commit(first),"A valid prepared native control commits exactly once")
	var committed:=owner.snapshot();var committed_hash:=digest(committed)
	check(owner.generation()==1 and digest(owner.raw_core())==digest(first.candidate_state.raw_core()),"Commit installs the independently owned candidate and generation")
	check(not owner.commit(first) and not owner.commit(competing) and digest(owner.snapshot())==committed_hash,"Repeated and stale competing receipts cannot commit")
	var fresh:=owner.prepare("input",{"operation":"accumulate_f1038","gui_u32":17,"speed_s32":0})
	check(fresh.ok and owner.restore(JSON.parse_string(JSON.stringify(committed))),"Cold JSON snapshot restores through actual command replay")
	check(not owner.commit(fresh) and digest(owner.snapshot())==committed_hash,"A restore invalidates outstanding receipts even when raw state matches")
	var cold:=Cycle.new();check(cold.restore(JSON.parse_string(JSON.stringify(committed))) and digest(cold.raw_core())==digest(owner.raw_core()),"New process-style owner restores complete raw state and witness")
	var next:=owner.prepare("control",payload);var next_cold:=cold.prepare("control",payload)
	check(next.ok and next_cold.ok and digest(next.candidate_state.raw_core())==digest(next_cold.candidate_state.raw_core()) and digest(next.receipt)==digest(next_cold.receipt),"Cold and uninterrupted owners continue the same control result and receipt")
	check(not cold.commit(next),"A cold owner's identical raw state does not authorize another owner's receipt")
	check(owner.restore(initial) and owner.generation()==0 and not owner.commit(next),"Restoring generation0 also invalidates prepared state")
	var reset_pending:=owner.prepare("control",payload)
	check(configure(owner,core) and not owner.commit(reset_pending),"Reconfiguration invalidates old transactions at the same generation")
	var returned:=owner.prepare("input",{"operation":"speed_increment_f1121","gui_u32":0,"speed_s32":65536})
	check(returned.ok and owner.commit(returned),"Explicit input kernel is also owned and committed through replay")
	check(var_to_bytes([core,payload])==frozen,"All ownership, cold-load and reject checks preserve caller context")
func malformed()->void:
	var core:=base_core();var owner:=Cycle.new();check(configure(owner,core),"Malformed tests start from a valid owner")
	var frozen:=digest(owner.snapshot());var body:=str(core.body_hex).hex_decode();var parent:=str(core.parent_hex).hex_decode();var root:=str(core.root_hex).hex_decode()
	for bad:Variant in [null,true,0,"raw",[],{},PackedByteArray()]:
		check(not owner.configure(bad,parent,root,core.external,core.clock),"Malformed player body rejects")
		check(not owner.configure(body,bad,root,core.external,core.clock),"Malformed parent body rejects")
		check(not owner.configure(body,parent,bad,core.external,core.clock),"Malformed raw root rejects")
	for bad:Variant in [null,true,0,"raw",[],{}]:
		check(not owner.configure(body,parent,root,bad,core.clock),"Malformed canonical external globals reject")
		check(not owner.configure(body,parent,root,core.external,bad),"Malformed clock words reject")
	for key:String in Cycle.EXTERNAL_KEYS:
		var external:Dictionary=core.external.duplicate(true);external.erase(key)
		check(not owner.configure(body,parent,root,external,core.clock),"Missing canonical external field rejects: "+key)
	var external:Dictionary=core.external.duplicate(true);external.player_mode_u8=44
	check(not owner.configure(body,parent,root,external,core.clock),"A second owner for root phase aliases cannot be introduced")
	for key:String in ["frame_ticks_u32","system_frame_ticks_u32","speed_multiplier_u32","transfer_state_u32","saved_flight_flags_u32","action_a_u32","action_b_u32"]:
		for bad:Variant in [-1,0x100000000,NAN,INF,true,0.5,"0"]:
			external=core.external.duplicate(true);external[key]=bad
			check(not owner.configure(body,parent,root,external,core.clock),"Invalid unsigned canonical global rejects: "+key)
	for key:String in ["forward_key_u8","reverse_key_u8","throttle_key_u8","aux_key1_u8","aux_key2_u8","mouse_buttons_u8"]:
		for bad:Variant in [-1,256,NAN,INF,true,0.5,"0"]:
			external=core.external.duplicate(true);external[key]=bad
			check(not owner.configure(body,parent,root,external,core.clock),"Invalid canonical input byte rejects: "+key)
	for key:String in ["input_gate_s8","effect_gate_s32"]:
		for bad:Variant in [-0x80000001,0x80000000,NAN,INF,true,0.5,"0"]:
			external=core.external.duplicate(true);external[key]=bad
			check(not owner.configure(body,parent,root,external,core.clock),"Invalid signed canonical field rejects: "+key)
	for bad:Variant in [null,true,[],[0,0],[0,0,true],[0,0,0x80000000]]:
		external=core.external.duplicate(true);external.spin_xyz_s32=bad
		check(not owner.configure(body,parent,root,external,core.clock),"Malformed raw angular scratch rejects")
	for offset:int in [0xc0,0xc8,0xcc]:
		var invalid:=root.duplicate();invalid.encode_u32(offset,115)
		check(not owner.configure(body,parent,invalid,core.external,core.clock),"Host addresses or invalid logical root references reject: %x"%offset)
	for index:int in [0,115,255]:
		var invalid:=body.duplicate();invalid[0x86]=index
		check(not owner.configure(invalid,parent,root,core.external,core.clock),"Invalid raw player identity rejects")
	for operation:Variant in [null,true,0,"F1009","",[]]:check(not owner.prepare(operation,blank_payload()).ok,"Unknown owned command rejects")
	for bad:Variant in [null,true,0,"payload",[],{}]:check(not owner.prepare("control",bad).ok,"Malformed command payload rejects")
	for key:String in ["mode_observations","phase_observations","gui_samples","contacts"]:
		var payload:=blank_payload();payload.erase(key)
		check(not owner.prepare("control",payload).ok,"Missing explicit control input rejects: "+key)
		for bad:Variant in [null,true,0,"rows",{}]:
			payload=blank_payload();payload[key]=bad
			check(not owner.prepare("control",payload).ok,"Malformed control input rejects: "+key)
		payload=blank_payload();payload[key]=[{}]
		check(not owner.prepare("control",payload).ok,"Unused or unmatched control observation rejects: "+key)
		payload=blank_payload();payload[key].resize(65)
		check(not owner.prepare("control",payload).ok,"Unbounded control inputs reject: "+key)
	for bad:Variant in [null,true,0,"prepared",[],{}]:check(not owner.commit(bad),"Malformed prepared command rejects")
	for bad:Variant in [null,true,0,"snapshot",[],{}]:check(not owner.restore(bad),"Malformed portable snapshot rejects")
	var snap:=owner.snapshot()
	for key:String in ["schema","version","profile","generation","core","last_witness","snapshot_sha256"]:
		var invalid:=snap.duplicate(true);invalid.erase(key)
		check(not owner.restore(invalid),"Incomplete portable snapshot rejects: "+key)
	var invalid:=snap.duplicate(true);invalid.extra=0
	check(not owner.restore(signed_snapshot(invalid)),"Unknown snapshot keys reject even after rehash")
	invalid=snap.duplicate(true);invalid.core.body_hex=invalid.core.body_hex.to_upper()
	check(not owner.restore(signed_snapshot(invalid)),"Noncanonical raw hex rejects")
	invalid=snap.duplicate(true);invalid.last_witness={"fake":0}
	check(not owner.restore(signed_snapshot(invalid)),"Generation0 cannot carry an invented witness")
	check(digest(owner.snapshot())==frozen,"All malformed command, restore and configure failures are atomic")
func owned_gui_contact()->void:
	var core:=base_core();var root:=str(core.root_hex).hex_decode();root[0xe8]=2;root[0xea]=2;core.root_hex=root.hex_encode()
	var before:Dictionary={"body":str(core.body_hex).hex_decode(),"root":root,"external":Cycle._pick(core.external,Cycle.PHASE_KEYS)}
	var first:=Phase.execute("phase_f1019",before.body,str(core.parent_hex).hex_decode(),root,before.external)
	check(not first.ok and first.get("pending",{}).get("kind")=="F1039","Owned GUI scenario reaches exact original view callback")
	if not first.get("pending") is Dictionary:return
	var sample:Dictionary={"kind":"F1039","before_sha256":Cycle.phase_boundary_sha256(first.pending.before),"gui_u32":0x00070009}
	var input:=PlayerInput.execute("view_f1039",first.pending.before.body,first.pending.before.root,Cycle._pick(core.external,PlayerInput.GLOBAL_KEYS),sample.gui_u32)
	check(input.ok,"Owned GUI scenario uses the proven raw input kernel")
	if not input.ok:return
	var collider:=PackedByteArray();collider.resize(338);collider[0x86]=2
	var contact:Dictionary={"caller_profile":"dos-firstenc-f569-explicit-observation-v1","body_before_hex":input.body_after.hex_encode(),"body_after_hex":input.body_after.hex_encode(),"flags_u8":0xe0,"altitude_raw_s32":0,"collider_ref_u32":2,"collider_index_u8":2,"material_u8":0,"collider_body_hex":collider.hex_encode()}
	var payload:=blank_payload();payload.operation="phase_f1019";payload.gui_samples=[sample];payload.contacts=[contact]
	var owner:=Cycle.new();check(configure(owner,core),"GUI/contact owner configures")
	var frozen:=digest(owner.snapshot());var prepared:=owner.prepare("phase",payload)
	check(prepared.ok,"Owned view and signed contact0xE0 compose through the whole original F1019 phase")
	if prepared.ok:
		check(prepared.receipt.source_order==["F1019","F1039","F1033"] and owner.commit(prepared),"Original early contact exit retains order and commits once")
		check(owner.generation()==1 and int(str(owner.raw_core().root_hex).hex_decode()[0xe8])==2,"Contact observation does not invent a landed state")
	for key:String in ["kind","before_sha256","gui_u32"]:
		var invalid:=payload.duplicate(true);invalid.gui_samples[0].erase(key);var isolated:=Cycle.new();configure(isolated,core)
		check(not isolated.prepare("phase",invalid).ok and digest(isolated.snapshot())==frozen,"Unmatched GUI token rejects atomically: "+key)
	var invalid:=payload.duplicate(true);invalid.contacts[0].body_before_hex=altered_hex(contact.body_before_hex,0)
	var isolated:=Cycle.new();configure(isolated,core)
	check(not isolated.prepare("phase",invalid).ok and digest(isolated.snapshot())==frozen,"F569 contact must match the actual post-input338B body")
	invalid=payload.duplicate(true);invalid.gui_samples[0].before_sha256="forged"
	check(not isolated.prepare("phase",invalid).ok,"GUI sample cannot be replayed at another raw context")
func delivery()->void:
	var core:=base_core();var owner:=Cycle.new();check(configure(owner,core),"Delivery owner starts with explicit raw context")
	var first:=owner.prepare("control",blank_payload())
	check(first.ok and owner.commit(first),"Delivery follows an already committed source control without reconfiguration")
	var before:=owner.raw_core();var initial:=digest(owner.snapshot());var external:Dictionary=before.external.duplicate(true)
	external.frame_ticks_u32=19;external.system_frame_ticks_u32=23;external.forward_key_u8=0;external.reverse_key_u8=1;external.spin_xyz_s32=[-2147483648,0,2147483647]
	var delivered_clock:Dictionary={"tick_u32":203,"day_u32":2};var payload:Dictionary={"clock":delivered_clock,"external":external}
	var frozen:=var_to_bytes(payload);var prepared:=owner.prepare("delivery",payload)
	check(prepared.ok and digest(owner.snapshot())==initial and var_to_bytes(payload)==frozen,"Preparing measured delivery preserves owner and caller payload")
	if not prepared.ok:return
	var after:Dictionary=prepared.candidate_state.raw_core()
	check(after.body_hex==before.body_hex and after.parent_hex==before.parent_hex and after.root_hex==before.root_hex,"Delivery preserves every raw player, parent and root byte")
	check(digest(after.external)==digest(external) and digest(after.clock)==digest(delivered_clock),"Delivery adopts only the explicitly supplied counter and key words")
	check(prepared.receipt.source_order.is_empty() and prepared.receipt.requests.is_empty() and not prepared.receipt.counter_collection_executed,"Delivery does not claim original counter collection or execute a source procedure")
	var stale:=owner.prepare("control",blank_payload())
	payload.clock.tick_u32=999;payload.external.frame_ticks_u32=999;payload.external.spin_xyz_s32[0]=99
	check(digest(prepared.candidate_state.raw_core())==digest(after) and owner.commit(prepared),"Changing caller delivery words cannot alter candidate, receipt or witness")
	check(not owner.commit(stale) and owner.generation()==2,"Delivered counters invalidate earlier prepared controls without resetting generation")
	var cold:=Cycle.new();check(cold.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))),"Cold save retains an explicit measured delivery witness")
	var live_control:=owner.prepare("control",blank_payload());var cold_control:=cold.prepare("control",blank_payload())
	check(live_control.ok and cold_control.ok and digest(live_control.candidate_state.raw_core())==digest(cold_control.candidate_state.raw_core()) and digest(live_control.receipt)==digest(cold_control.receipt),"Delivered clock/key words continue identically after a cold load")
	check(owner.commit(live_control) and cold.commit(cold_control) and owner.generation()==3 and cold.generation()==3 and digest(owner.raw_core())==digest(cold.raw_core()),"Delivery then source control advances owned generations and raw state consistently")
	initial=digest(owner.snapshot())
	for bad:Variant in [null,true,0,"delivery",[],{}, {"clock":delivered_clock}, {"external":external}, {"clock":delivered_clock,"external":external,"extra":0}]:check(not owner.prepare("delivery",bad).ok,"Malformed measured delivery rejects")
	for bad:Variant in [null,true,0,"clock",[],{}, {"tick_u32":-1,"day_u32":0}, {"tick_u32":0,"day_u32":0x100000000}]:check(not owner.prepare("delivery",{"clock":bad,"external":before.external}).ok,"Invalid delivered clock rejects")
	for bad:Variant in [null,true,0,"external",[],{}]:check(not owner.prepare("delivery",{"clock":delivered_clock,"external":bad}).ok,"Invalid delivered key/counter shape rejects")
	check(digest(owner.snapshot())==initial,"All malformed deliveries leave generation, raw context and witness unchanged")
func input_value_receipts()->void:
	check(FileAccess.get_sha256(INPUT_FIXTURE)==INPUT_FIXTURE_SHA,"Original native F1121 return-value corpus is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INPUT_FIXTURE))
	for row:Dictionary in fixture.cases:
		if row.operation!="speed_increment_f1121" or int(row.expected.value_u32)==0:continue
		if input_value_cases>=12:break
		var core:=base_core()
		for key:String in PlayerInput.GLOBAL_KEYS:core.external[key]=row.globals_before[key]
		var owner:=Cycle.new();check(configure(owner,core),"Native F1121 return context configures")
		var before:=digest(owner.raw_core());var prepared:=owner.prepare("input",{"operation":row.operation,"gui_u32":row.gui_accumulator_u32,"speed_s32":row.speed_input_s32})
		check(prepared.ok and prepared.receipt.value_u32==row.expected.value_u32,"Owned input receipt retains the actual nonzero native F1121 result")
		if prepared.ok:check(digest(prepared.candidate_state.raw_core())==before and owner.commit(prepared),"Return-only F1121 preserves raw body/root/context while committing its witness")
		input_value_cases+=1
	check(input_value_cases==12,"Twelve independent nonzero native speed increments reach their owned receipts")
func native_bank()->void:
	if not FileAccess.file_exists(FIXTURE):check(false,"Independent composed original control fixture is required");return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent composed native player-cycle fixture is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.schema=="starfrontier-source-player-cycle-native-v1" and int(fixture.case_count)==80 and fixture.cases.size()==80 and fixture.proof is Dictionary,"All80 actual original mode-to-phase cases are present")
	check(fixture.proof.source_executable_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and fixture.proof.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a" and fixture.proof.source_data_sha256=="34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850","Composed native source executable, instructions and logical table identities stay explicit")
	check(fixture.proof.native_calls==304 and fixture.proof.fresh_process_runs_each_call==3 and not fixture.proof.private_original_inputs_needed and not fixture.proof.expected_arithmetic_calculated_in_python,"304 actual native calls repeat in three fresh processes without private inputs or Python expected arithmetic")
	check(digest(fixture.case_counts_by_selected_function)==digest({"1044":64,"1019":8,"1021":8}),"Composed native bank includes drift and both complete phase dispatchers")
	if fixture.proof.get("source_dependencies_sha256") is Dictionary:proof_dependencies=fixture.proof.source_dependencies_sha256.duplicate(true)
	for path:String in proof_dependencies:check(FileAccess.get_sha256("res://"+path)==proof_dependencies[path],"Native composed proof dependency is pinned: "+path)
	for row:Dictionary in fixture.cases:
		var label:=str(row.name);var owner:=Cycle.new();var original:=var_to_bytes([row.core_before,row.command]);native_cases+=1
		check(configure(owner,row.core_before),"Native raw owner configures: "+label)
		var initial:=digest(owner.snapshot());var prepared:=owner.prepare(row.command.operation,row.command.payload)
		check(prepared.ok,"Actual mode-to-phase command prepares: "+label+" "+str(prepared.get("reason","")))
		if not prepared.ok:continue
		check(digest(prepared.candidate_state.raw_core())==digest(row.expected_core),"Whole native338Bbody/338Bparent/16384Broot/16globals/clock match: "+label)
		check(digest(owner.snapshot())==initial and var_to_bytes([row.core_before,row.command])==original,"Native prepare keeps owner and all caller inputs unchanged: "+label)
		check(prepared.receipt.selected_function_id_u32==row.expected_selected_function_id_u32 and prepared.receipt.phase_source_order==row.expected_phase_source_order,"Native selected mode and actual source phase order match: "+label)
		check(prepared.receipt.source_order==row.expected_mode_source_order,"Whole native mode continuation retains its original procedure order: "+label)
		check(owner.commit(prepared) and owner.generation()==1 and digest(owner.raw_core())==digest(row.expected_core),"Actual composed native output commits once: "+label)
		var snapshot:=owner.snapshot();var cold:=Cycle.new();cold_cases+=1
		check(cold.restore(JSON.parse_string(JSON.stringify(snapshot))) and digest(cold.raw_core())==digest(row.expected_core),"Cold JSON replay retains the entire native output: "+label)
		check(not cold.commit(prepared) and not owner.commit(prepared),"Native receipt cannot cross owners or commit twice: "+label)
func run()->void:
	ownership();malformed();owned_gui_contact();delivery();input_value_receipts();native_bank()
	var sources:Dictionary={}
	for path:String in proof_dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in ["scripts/source_player_cycle.gd","scripts/source_player_context.gd","scripts/source_player_mode.gd","scripts/source_player_input.gd","scripts/source_player_phase.gd","scripts/source_player_motion.gd","scripts/source_player_dispatch.gd","scripts/source_clock_pipeline.gd","tests/test_source_player_cycle.gd","tests/fixtures/source_player_cycle_native.json","tests/fixtures/source_player_input_native.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"profile":Cycle.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"cold_native_cases":cold_cases,"native_input_value_receipts":input_value_cases,"sources":sources,"live_Main_replaced":false,"full_world_scheduler":false,"Android_device_tested":false,"scope":"Explicit raw player owner, actual mode selection and supported original phase kernels, matched GUI/contact callbacks, measured counter/key delivery, prepare/commit/replay and cold JSON witnesses. Independent native composed corpus checks every raw owner byte and canonical global; native F1121 returns reach receipts. Unported world callbacks require observations; this is not live Main or Android proof."},"\t"));file.close()
	print("SOURCE PLAYER CYCLE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
