extends RefCounted
# Actual uploaded DOS F578. The JJFFE replacement mass/reflection code is
# deliberately excluded. Damage/world F953 calls require matched responses.
const PROFILE:="dos-firstenc-pair-response-v1"
const OBJECT_BYTES:=338
const MASK:=0xffffffff
const GLOBAL_KEYS:=["collision_flags_u8","collision_enabled_u8"]
static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high and float(value)==floorf(float(value))
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:String in keys:
		if not value.has(key):return false
	return true
static func _body(value:Variant)->bool:return value is PackedByteArray and value.size()==OBJECT_BYTES
static func _globals(value:Variant)->bool:
	return _keys(value,GLOBAL_KEYS) and _whole(value.collision_flags_u8,0,255) and _whole(value.collision_enabled_u8,0,255)
static func _context(value:Variant)->bool:
	return _keys(value,["body","collider","globals"]) and _body(value.body) and _body(value.collider) and _globals(value.globals)
static func _same(first:Variant,second:Dictionary)->bool:
	return _context(first) and first.body==second.body and first.collider==second.collider and int(first.globals.collision_flags_u8)==int(second.globals.collision_flags_u8) and int(first.globals.collision_enabled_u8)==int(second.globals.collision_enabled_u8)
static func _s32(value:int)->int:return (value&0x7fffffff)-(value&0x80000000)
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"F953_body_executed":false,"complete_collision_pipeline":false}
static func _boundary(state:Dictionary,target:String,damage:int,attacker:int)->bool:
	state.order.append("F953")
	var before:Dictionary={"body":state.body.duplicate(),"collider":state.collider.duplicate(),"globals":state.globals.duplicate(true)}
	var request:Dictionary={"kind":"F953","target":target,"args":[damage&MASK,attacker&MASK],"before":before}
	state.requests.append(request.duplicate(true))
	if int(state.cursor)>=state.observations.size():state.pending=request;state.reason="boundary_required";return false
	var row:Variant=state.observations[int(state.cursor)]
	if not _keys(row,["kind","target","args","before","after"]) or not row.kind is String or not row.target is String or not row.args is Array or row.args.size()!=2:state.reason="unmatched_F953_response";return false
	if not _whole(row.args[0],0,MASK) or not _whole(row.args[1],0,MASK) or row.kind!="F953" or row.target!=target or int(row.args[0])!=int(request.args[0]) or int(row.args[1])!=int(request.args[1]) or not _same(row.before,before) or not _context(row.after):state.reason="unmatched_F953_response";return false
	state.body=row.after.body.duplicate();state.collider=row.after.collider.duplicate();state.globals={"collision_flags_u8":int(row.after.globals.collision_flags_u8),"collision_enabled_u8":int(row.after.globals.collision_enabled_u8)}
	state.cursor=int(state.cursor)+1;return true
static func execute(body:Variant,collider:Variant,globals:Variant,observations:Variant=[])->Dictionary:
	if not _body(body) or not _body(collider) or not _globals(globals) or not observations is Array or observations.size()>2:return _reject("invalid_pair_context")
	var state:Dictionary={"body":body.duplicate(),"collider":collider.duplicate(),"globals":{"collision_flags_u8":int(globals.collision_flags_u8)|0x80,"collision_enabled_u8":int(globals.collision_enabled_u8)},"observations":observations,"cursor":0,"order":["F578"],"requests":[],"pending":{},"reason":""}
	var ok:=true
	if int(state.body[0x56])==int(state.collider[0x86]) or int(state.collider[0x87])==1:
		for offset:int in [0x8c,0x90,0x94]:state.body.encode_s32(offset,_s32(-(state.body.decode_s32(offset)>>2)))
		var damage:=10
		for offset:int in [0x8c,0x90,0x94]:
			damage=_s32(damage+absi(state.body.decode_s32(offset)));state.order.append("_abs")
		if state.body.decode_u32(0x82)>13:ok=_boundary(state,"body",damage,0)
	else:
		for offset:int in [0x8c,0x90,0x94]:
			var velocity:=_s32(state.body.decode_s32(offset)+state.collider.decode_s32(offset))>>1
			state.body.encode_s32(offset,velocity);state.collider.encode_s32(offset,velocity)
		if int(state.globals.collision_enabled_u8)!=0 and state.body.decode_u32(0x82)>13 and state.collider.decode_u32(0x82)>13:
			var parent_was_minimum:bool=int(state.collider.decode_u16(0xe4))<=int(state.body.decode_u16(0xe4))
			var first_damage:int=int(state.collider.decode_u16(0xe4) if parent_was_minimum else state.body.decode_u16(0xe4))*2
			ok=_boundary(state,"collider",first_damage,int(state.body[0x86]))
			if ok:
				# Both HP and attacker identity are reloaded after first F953;
				# the minimum comparison itself is not repeated by the source.
				var second_damage:int=int(state.collider.decode_u16(0xe4) if parent_was_minimum else state.body.decode_u16(0xe4))*2
				ok=_boundary(state,"body",second_damage,int(state.collider[0x86]))
	if not ok:
		var failed:=_reject(str(state.reason));failed.source_order=state.order.duplicate();failed.observations_used=int(state.cursor)
		if not state.pending.is_empty():failed.pending=state.pending.duplicate(true)
		return failed
	if int(state.cursor)!=observations.size():return _reject("unused_pair_observations")
	return {"ok":true,"profile":PROFILE,"body_after":state.body,"collider_after":state.collider,"globals_after":state.globals,"requests":state.requests,"source_order":state.order,"observations_used":int(state.cursor),"live_owners_changed":false,"F953_body_executed":false,"complete_collision_pipeline":false}
