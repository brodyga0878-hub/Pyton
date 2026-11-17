extends RefCounted
class_name SourcePlayerPhase
# Whole DOS F1019/F1021 admission and source ordering. Raw arithmetic executes
# through the independently verified kernels. Every unported world/input call
# requires a matched observation; the pure call can be replayed with one more
# response when it returns boundary_required. This is not the live Main route.
const Context=preload("res://scripts/source_player_context.gd")
const Player=preload("res://scripts/source_player_dispatch.gd")
const Motion=preload("res://scripts/source_motion_pipeline.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Angular=preload("res://scripts/source_angular_motion.gd")
const PROFILE:="dos-firstenc-whole-player-phases-v1"
const OPERATIONS:=["phase_f1019","phase_f1021"]
const EXTERNAL_KEYS:=["frame_ticks_u32","forward_key_u8","reverse_key_u8","spin_xyz_s32","transfer_state_u32","saved_flight_flags_u32","effect_gate_s32"]
const ROOT_BYTES:=0x4000
const BODY_BYTES:=338
const MASK:=0xffffffff
static func _whole(value:Variant,low:int,high:int)->bool:return Player._whole(value,low,high)
static func _external(value:Variant)->bool:
	if not value is Dictionary or value.size()!=EXTERNAL_KEYS.size():return false
	for key:String in EXTERNAL_KEYS:
		if not value.has(key):return false
	for key:String in ["frame_ticks_u32","transfer_state_u32","saved_flight_flags_u32"]:
		if not _whole(value[key],0,MASK):return false
	for key:String in ["forward_key_u8","reverse_key_u8"]:
		if not _whole(value[key],0,255):return false
	return _whole(value.effect_gate_s32,-0x80000000,0x7fffffff) and Player._vector(value.spin_xyz_s32)
static func _root(value:Variant,player:int)->bool:
	return value is PackedByteArray and value.size()==ROOT_BYTES and value.decode_u32(0xc8)==player and value.decode_u32(0xcc)<=114
static func _body(value:Variant)->bool:return value is PackedByteArray and value.size()==BODY_BYTES
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"raw_owners_mutated":false,"full_world_effects_executed":false,"live_Main_motion_replaced":false}
static func execute(operation:Variant,body:Variant,parent:Variant,root:Variant,external:Variant,observations:Variant=[])->Dictionary:
	if not operation is String or operation not in OPERATIONS:return _reject("unknown_player_phase")
	if not _body(body) or not _body(parent) or not _external(external) or not observations is Array:return _reject("invalid_phase_context")
	if int(body[0x86])<1 or int(body[0x86])>114 or not _root(root,int(body[0x86])):return _reject("invalid_phase_root_or_reference")
	var runner:=Phase.new();runner.body=body.duplicate();runner.parent=parent.duplicate();runner.root=root.duplicate();runner.external=external.duplicate(true);runner.observations=observations
	return runner.run(operation)

class Phase:
	var body:PackedByteArray
	var parent:PackedByteArray
	var root:PackedByteArray
	var external:Dictionary
	var observations:Array
	var used:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	var collider:=PackedByteArray()
	var collider_index:=0
	var returned:=0
	func context()->Dictionary:return {"body":body.duplicate(),"root":root.duplicate(),"external":external.duplicate(true)}
	func fail(reason:String)->bool:
		stopped=SourcePlayerPhase._reject(reason);stopped.observations_used=used;stopped.source_order=order.duplicate();return false
	func same_external(a:Variant,b:Dictionary)->bool:
		if not SourcePlayerPhase._external(a):return false
		for key:String in SourcePlayerPhase.EXTERNAL_KEYS:
			if key=="spin_xyz_s32":
				for axis in range(3):
					if int(a[key][axis])!=int(b[key][axis]):return false
			elif int(a[key])!=int(b[key]):return false
		return true
	func same_args(a:Variant,b:Array)->bool:
		if not a is Array or a.size()!=b.size():return false
		for index in range(b.size()):
			if not SourcePlayerPhase._whole(a[index],0,SourcePlayerPhase.MASK) or int(a[index])!=int(b[index]):return false
		return true
	func same_context(a:Variant,b:Dictionary)->bool:
		return a is Dictionary and a.size()==3 and a.has("body") and a.has("root") and a.has("external") and a.body==b.body and a.root==b.root and same_external(a.external,b.external)
	func boundary(kind:String,args:Array=[])->bool:
		order.append(kind)
		var pending:={"kind":kind,"args":args.duplicate(),"before":context()}
		if used>=observations.size():
			fail("boundary_required");stopped.pending=pending;return false
		var response:Variant=observations[used]
		if not response is Dictionary or response.get("kind")!=kind or not same_args(response.get("args"),args) or not same_context(response.get("before"),pending.before):return fail("boundary_context_mismatch")
		if not response.has("after") or not response.after is Dictionary or response.after.size()!=3:return fail("invalid_boundary_response")
		var after:Dictionary=response.after
		if not SourcePlayerPhase._body(after.get("body")) or int(after.body[0x86])!=int(body[0x86]) or not SourcePlayerPhase._root(after.get("root"),int(body[0x86])) or not SourcePlayerPhase._external(after.get("external")):return fail("invalid_boundary_response")
		if not SourcePlayerPhase._whole(response.get("return_u32"),0,SourcePlayerPhase.MASK):return fail("invalid_boundary_return")
		# Presentation observers have no authority over the raw player owner.
		if kind in ["F48","F1906","F1910"] and not same_context(after,pending.before):return fail("presentation_boundary_mutated_player")
		if kind=="F1033":
			if not SourcePlayerPhase._body(response.get("collider_body")) or not SourcePlayerPhase._whole(response.get("collider_index"),0,114) or ((int(response.return_u32)&0x60)!=0 and int(response.collider_index)==0) or (int(response.collider_index)!=0 and int(response.collider_body[0x86])!=int(response.collider_index)) or int(response.return_u32)>255:return fail("invalid_contact_boundary")
			collider=response.collider_body.duplicate();collider_index=int(response.collider_index)
		body=after.body.duplicate();root=after.root.duplicate();external=after.external.duplicate(true);returned=int(response.return_u32)
		requests.append(response.duplicate(true));used+=1;return true
	func player()->Dictionary:return SourcePlayerPhase.Context.player_globals(root,external)
	func adopt_player(result:Dictionary)->bool:
		if not result.get("ok",false):return fail("player_kernel_rejected")
		var merged:=SourcePlayerPhase.Context.apply_player_globals(root,external,result.globals_after)
		if not merged.get("ok",false):return fail("player_alias_update_rejected")
		body=result.body_after.duplicate();root=merged.root_after;external=merged.external_after;return true
	func prepare()->bool:
		var result:=SourcePlayerPhase.Player.prefix_f1041(body,parent,player())
		if not result.get("ok",false):return fail("control_prefix_rejected")
		if not adopt_player(result):return false
		for entry:String in result.source_order:
			if entry!="F606":order.append(entry)
		if result.frame_selection_requested:
			if not boundary("F606",[int(body[0x86]),1]):return false
			body[0x14d]=13
		# F606 may have changed Root mode/flags/speed. Read those bytes now,
		# after the observed continuation, before selecting the source tail.
		var state:=player();var thrust:Dictionary
		if int(root[0xe8])==0x24:
			thrust=SourcePlayerPhase.Motion.set_thrust(body,PackedInt64Array([0,0xcc6,0]));order.append("F599")
		elif (int(root[0xe9])&1)!=0:
			var manual:=SourcePlayerPhase.Player.manual_f1043(body,state)
			if not manual.get("ok",false):return fail("manual_control_rejected")
			order.append("F1043")
			for request:Dictionary in manual.requests:
				if not boundary("F1910",request.args):return false
			body=manual.body_after.duplicate();order.append("F599");return true
		else:
			var desired:=SourcePlayerPhase.Motion.desired_acceleration(body,root.decode_s32(0x1b8))
			if desired.is_empty():return fail("speed_hold_rejected")
			thrust=SourcePlayerPhase.Motion.set_thrust(desired.body,desired.command_s32);order.append_array(["F607","F599"])
		if thrust.is_empty():return fail("source_thrust_rejected")
		body=thrust.body;return true
	func effects()->bool:
		order.append("F1046")
		if int(body[0x14e])!=0 and not boundary("F939",[int(body[0x86]),0x3e,0]):return false
		var result:=SourcePlayerPhase.Gravity.integrate(body,PackedInt64Array([root.decode_u32(0xe0),root.decode_u32(0xe4)]))
		if result.is_empty():return fail("source_drift_rejected")
		body=result.body;order.append_array(["F1045","F1512"])
		if int(root[0x3f5e])!=0 and int(external.effect_gate_s32)<0:
			var maximum:=0
			for offset in [0xb6,0xb8,0xba]:maximum=maxi(maximum,absi(body.decode_s16(offset)))
			var amplitude:=maximum-0x221
			if amplitude>=0:
				if not boundary("F1910",[3,amplitude,(0x1ae-amplitude)&SourcePlayerPhase.MASK]):return false
				root.encode_u16(0xc6,root.decode_u16(0xc6)|0x80)
		return true
	func reset_velocity()->bool:
		order.append("F1042")
		for offset in [0x8c,0x90,0x94]:body.encode_u32(offset,0)
		for offset in [0xb0,0xb2,0xb6,0xb8,0xba]:body.encode_u16(offset,0)
		root.encode_u32(0x1b8,0)
		if (int(root[0xc6])&0x80)!=0 and not boundary("F1910",[3,1,300]):return false
		return true
	func ui(which:int)->bool:return boundary("F48",[1,0,which])
	func contact()->bool:return boundary("F1033",[int(body[0x86]),1])
	func control()->bool:return boundary("F1035",[int(body[0x86])])
	func thermal()->bool:return boundary("F1014",[int(body[0x86])])
	func phase1019()->bool:
		order.append("F1019")
		if (int(root[0x3fb6])&2)!=0 and int(external.transfer_state_u32)!=0:return boundary("F1018")
		if not boundary("F1039",[int(body[0x86])]) or not contact():return false
		if int(root[0xe8])==0x2c:return true
		var flags:=returned
		if (flags&0x20)!=0 and (flags&0x40)!=0:
			if (flags&0x80)!=0:return true
			root.encode_u32(0xcc,collider_index);root[0xf8]=0;root[0xc5]=int(collider[0x86])
			if not reset_velocity() or not boundary("F652",[int(root[0xc0]),collider_index]):return false
			if (int(collider[0x14c])&0x40)!=0:
				root[0xe8]=0x2e
				if not boundary("F995") or not boundary("F1116"):return false
			else:
				root.encode_u32(0x106,0x70000)
				if not boundary("F1906",[0x13]):return false
				root[0xe9]=int(root[0xe9])&0xdb
				if (int(collider[0x14c])&0x20)!=0:
					root[0xe8]=8;root.encode_u32(0xdc,0)
				else:root[0xe8]=10
				if not boundary("F1116"):return false
			return ui(13) and ui(14)
		if (flags&1)!=0:
			if not thermal():return false
		elif not control():return false
		if not effects():return false
		order.append("F603")
		var gravity:=SourcePlayerPhase.Gravity.update(body,parent,SourcePlayerPhase.Player._s32(root.decode_u32(0xe0)),PackedInt64Array(external.spin_xyz_s32))
		if gravity.is_empty():return fail("source_gravity_rejected")
		body=gravity.body;external.spin_xyz_s32=Array(gravity.scratch_s32)
		order.append("F601")
		var kick:=SourcePlayerPhase.Motion.velocity_step(body,root.decode_u32(0xe0),true)
		if kick.is_empty():return fail("source_motor_rejected")
		body=kick.body;order.append("F585")
		var state:=player();var angular:=SourcePlayerPhase.Angular.step_raw(body,SourcePlayerPhase.Player._s32(root.decode_u32(0xe0)),true,SourcePlayerPhase.Player._s32(root.decode_u32(0xe0)),{"player_index_u32":state.player_index_u32,"player_roll_s16":state.player_roll_s16})
		if not angular.get("ok",false):return fail("source_angular_rejected")
		body=angular.body_after;root.encode_u16(0x210,int(angular.globals_after.player_roll_s16)&65535);return true
	func phase1021()->bool:
		order.append("F1021")
		if not boundary("F1037",[int(body[0x86])]) or not prepare():return false
		var uncapped:=(int(root[0xe9])&1)!=0
		order.append("F602" if uncapped else "F601")
		var kick:=SourcePlayerPhase.Motion.velocity_step(body,root.decode_u32(0xe0),not uncapped)
		if kick.is_empty():return fail("source_motor_rejected")
		body=kick.body
		if (int(root[0x3fb6])&2)!=0:
			if int(external.transfer_state_u32)!=0:
				if int(root[0xe8])==2 and not boundary("F1018"):return false
				if not boundary("F1120"):return false
				external.saved_flight_flags_u32=int(root[0xe9])&1;external.transfer_state_u32=0
			if not boundary("F726",[2,3,root.decode_u32(0xe0),13]):return false
			root[0xe9]=int(root[0xe9])|1
			if not boundary("F726",[3,2,root.decode_u32(0xe0),11]):return false
		elif int(external.transfer_state_u32)==0:
			root[0xe9]=(int(root[0xe9])&0xfe)|(int(external.saved_flight_flags_u32)&255)
			if not boundary("F1117") or not boundary("F1116"):return false
			external.transfer_state_u32=1
		if not effects() or not contact():return false
		if int(root[0xe8])==0x2c:return true
		var flags:=returned
		if (flags&0x20)!=0:
			if (flags&0x40)!=0:
				root[0xe8]=0x24
				if not boundary("F1116") or not ui(14):return false
			if (int(collider[0x14c])&0x10)==0:return true
			if not boundary("F657",[root.decode_u32(0xc0),collider_index]):return false
			if (returned&255)!=0:root[0xe8]=6;return ui(14)
			return boundary("F1022",[collider_index])
		if (flags&0x40)!=0:
			root.encode_u32(0xcc,collider_index);root[0xc5]=int(collider[0x86])
			if not reset_velocity():return false
			root[0xf8]=255;root[0xe8]=0x32
			return ui(13) and ui(14)
		root[0xeb]=0
		if (flags&1)!=0:
			if not thermal():return false
			for offset in [0x88,0x8c,0x90]:root.encode_u32(offset,0)
			root.encode_u32(0x94,root.decode_u32(0xd8))
		return control()
	func run(operation:String)->Dictionary:
		var ok:=phase1019() if operation=="phase_f1019" else phase1021()
		if not ok:return stopped
		if used!=observations.size():fail("unused_boundary_observations");return stopped
		return {"ok":true,"profile":SourcePlayerPhase.PROFILE,"body_after":body.duplicate(),"root_after":root.duplicate(),"external_after":external.duplicate(true),"source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"raw_owners_mutated":false,"full_world_effects_executed":false,"live_Main_motion_replaced":false}
