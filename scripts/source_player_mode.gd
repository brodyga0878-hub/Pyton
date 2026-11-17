extends RefCounted
# Original DOS F1008/F1009/F1010 and the original paired player-mode table.
# Selected player/UI callbacks are explicit matched observation boundaries.
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Bank=preload("res://scripts/source_reference_bank.gd")
const PROFILE:="dos-firstenc-player-mode-v1"
const SOURCE_EXE_SHA256:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const RESOURCE_PATH:="res://data/ffe_player_modes.json"
const RESOURCE_SHA256:="960a2d48ab43ca93259fe3a5618277bec998f8c6cb30671e7b234a376059e88c"
const ROOT_WINDOW_BYTES:=0x4000
const OBJECT_BYTES:=338
const EXTERNAL_KEYS:=["frame_ticks_u32","action_a_u32","action_b_u32"]
const TRACE_KEYS:=["request","body_before_hex","root_before_hex","externals_before","body_after_hex","root_after_hex","externals_after"]
const REQUEST_KEYS:=["kind","function_id_u32","args_u32","body_argument"]
const OPERATIONS:=["housekeeping_f1008","control_f1009","post_f1010"]
const MASK:=0xffffffff
static var _modes:Dictionary={}
static var _mutex:=Mutex.new()

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"callback_bodies_executed":false,"full_player_cycle":false}
static func _externals(value:Variant)->bool:
	if not value is Dictionary or not Clock._keys(value,EXTERNAL_KEYS):return false
	for key:String in EXTERNAL_KEYS:
		if not Clock._whole(value[key]):return false
	return true
static func _copy_externals(value:Dictionary)->Dictionary:
	return {"frame_ticks_u32":int(value.frame_ticks_u32),"action_a_u32":int(value.action_a_u32),"action_b_u32":int(value.action_b_u32)}
static func _clock(value:Variant)->bool:
	return value is Dictionary and Clock._keys(value,["tick_u32","day_u32"]) and Clock._whole(value.tick_u32) and Clock._whole(value.day_u32)
static func _request(value:Variant)->bool:
	if not value is Dictionary or not Clock._keys(value,REQUEST_KEYS) or not value.kind is String or value.kind not in ["F1116","F1097","F1062","F1064","control_phase","post_phase"] or not Clock._whole(value.function_id_u32) or not value.body_argument is bool or not value.args_u32 is Array or value.args_u32.size()>2:return false
	for word:Variant in value.args_u32:
		if not Clock._whole(word):return false
	return true
static func _trace(value:Variant)->bool:
	if not value is Array or value.size()>4:return false
	for row:Variant in value:
		if not row is Dictionary or not Clock._keys(row,TRACE_KEYS) or not _request(row.request) or not Bank._hex(row.body_before_hex,OBJECT_BYTES) or not Bank._hex(row.body_after_hex,OBJECT_BYTES) or not Bank._hex(row.root_before_hex,ROOT_WINDOW_BYTES) or not Bank._hex(row.root_after_hex,ROOT_WINDOW_BYTES) or not _externals(row.externals_before) or not _externals(row.externals_after):return false
	return true
static func _load_modes()->bool:
	_mutex.lock()
	if not _modes.is_empty():
		_mutex.unlock();return true
	if FileAccess.get_sha256(RESOURCE_PATH)!=RESOURCE_SHA256:
		_mutex.unlock();return false
	var resource:Variant=JSON.parse_string(FileAccess.get_file_as_string(RESOURCE_PATH))
	if not resource is Dictionary or resource.get("profile")!=PROFILE or resource.get("source_executable_sha256")!=SOURCE_EXE_SHA256 or int(resource.get("root_window_bytes",0))!=ROOT_WINDOW_BYTES or int(resource.get("phase_pair_count",0))!=29 or not resource.get("modes") is Array or resource.modes.size()!=29 or not Bank._hex(resource.get("table_hex"),240):
		_mutex.unlock();return false
	var raw:=str(resource.table_hex).hex_decode();var modes:Dictionary={}
	for index in range(29):
		var row:Variant=resource.modes[index]
		if not row is Dictionary or not Clock._whole(row.get("phase_u8"),56) or int(row.phase_u8)!=index*2 or not Clock._whole(row.get("control_function_id")) or not Clock._whole(row.get("post_function_id")) or not Clock._whole(row.get("control_va_u32")) or not Clock._whole(row.get("post_va_u32")) or int(row.control_va_u32)!=raw.decode_u32(index*8) or int(row.post_va_u32)!=raw.decode_u32(index*8+4) or int(row.control_va_u32)==0 or int(row.post_va_u32)==0:
			_mutex.unlock();return false
		modes[index]={"phase_u8":index*2,"control_function_id":int(row.control_function_id),"control_va_u32":int(row.control_va_u32),"post_function_id":int(row.post_function_id),"post_va_u32":int(row.post_va_u32)}
	if raw.decode_u32(232)!=0 or raw.decode_u32(236)!=0:
		_mutex.unlock();return false
	_modes=modes;_mutex.unlock();return true
static func mode_for(phase:Variant)->Dictionary:
	if not Clock._whole(phase,57) or not _load_modes():return {}
	return _modes[int(phase)>>1].duplicate(true)

static func _emit(context:Dictionary,kind:String,function_id:int,args:Array=[],body_argument:bool=false)->bool:
	var request:Dictionary={"kind":kind,"function_id_u32":function_id,"args_u32":args.duplicate(),"body_argument":body_argument}
	context.requests.append(request.duplicate(true));context.source_order.append("F%d"%function_id)
	if context.allow_pending and int(context.cursor)>=context.trace.size():context.pending_request=request;return false
	if context.trace.is_empty():return true
	if int(context.cursor)>=context.trace.size():context.error="observed_callback_trace_exhausted";return false
	var row:Dictionary=context.trace[int(context.cursor)]
	if Clock._hash(row.request)!=Clock._hash(request) or str(row.body_before_hex)!=context.body.hex_encode() or str(row.root_before_hex)!=context.root.hex_encode() or Clock._hash(row.externals_before)!=Clock._hash(context.externals):context.error="observed_callback_before_mismatch";return false
	context.body=str(row.body_after_hex).hex_decode();context.root=str(row.root_after_hex).hex_decode();context.externals=_copy_externals(row.externals_after);context.cursor=int(context.cursor)+1
	return true
static func _housekeeping(context:Dictionary)->bool:
	context.source_order.append("F1008")
	var body:PackedByteArray=context.body;var root:PackedByteArray=context.root
	var remaining:int=body.decode_u16(0xe8);var ticks:int=context.externals.frame_ticks_u32
	if remaining!=0:body.encode_u16(0xe8,0 if ticks>0xffff or ticks>remaining else remaining-ticks)
	if int(root[0xe8])==2:
		root.encode_u16(0xc6,int(root.decode_u16(0xc6))&0xfffd)
		if int(body[0xff])>30:
			if (int(root[0xe9])&2)!=0:
				context.body=body;context.root=root
				if not _emit(context,"F1116",1116):return false
				body=context.body;root=context.root
			root[0xe9]=int(root[0xe9])&0xfd
		else:
			root[0xe9]=int(root[0xe9])|2
			context.body=body;context.root=root
			if not _emit(context,"F1116",1116):return false
			body=context.body;root=context.root
	if (int(root[0xe9])&2)!=0:
		var shield:int=body.decode_u16(0x9e);var half:int=int(context.externals.frame_ticks_u32)>>1
		body.encode_u16(0x9e,0 if shield<=half else shield-half)
	else:
		if int(root[0xe8])!=2 and root.decode_s32(0xd8)>=0x186a0:
			if (int(root[0xc6])&2)==0:
				context.body=body;context.root=root
				if not _emit(context,"F1097",1097,[0x98ce,MASK]):return false
				body=context.body;root=context.root
			root.encode_u16(0xc6,int(root.decode_u16(0xc6))|2)
		var sum:int=int(body.decode_u16(0x9e))+(int(context.externals.frame_ticks_u32)>>1)
		body.encode_u16(0x9e,0xffff if sum>0xffff else sum)
	context.body=body;context.root=root;return true
static func _phase(context:Dictionary,post:bool)->bool:
	var row:=mode_for(int(context.root[0xe8]))
	if row.is_empty():context.error="unsupported_or_null_source_mode_selector";return false
	var function_id:int=int(row.post_function_id if post else row.control_function_id)
	context.selected=function_id
	return _emit(context,"post_phase" if post else "control_phase",function_id,[],not post)

static func execute(operation:Variant,body:Variant,root:Variant,externals:Variant,clock:Variant,trace:Variant=[],allow_pending:Variant=false)->Dictionary:
	if not operation is String or operation not in OPERATIONS or not body is PackedByteArray or body.size()!=OBJECT_BYTES or not root is PackedByteArray or root.size()!=ROOT_WINDOW_BYTES or not _externals(externals) or not _clock(clock) or not _trace(trace) or not allow_pending is bool:return _reject("invalid_mode_context_or_trace")
	var context:Dictionary={"body":body.duplicate(),"root":root.duplicate(),"externals":_copy_externals(externals),"requests":[],"trace":trace.duplicate(true),"cursor":0,"selected":0,"source_order":[],"error":"","allow_pending":allow_pending,"pending_request":{}}
	var ok:=true
	match operation:
		"housekeeping_f1008":ok=_housekeeping(context)
		"control_f1009":
			context.source_order.append("F1009")
			var current:PackedByteArray=context.body;var game:PackedByteArray=context.root
			var old_tick:int=current.decode_u32(0xa8);var low:int=int(clock.tick_u32)
			game.encode_u32(0xe0,(low-old_tick)&MASK)
			game.encode_u32(0xe4,(int(clock.day_u32)-int(current.decode_u32(0xac))-(1 if low<old_tick else 0))&MASK)
			current.encode_u32(0xa8,low);current.encode_u32(0xac,int(clock.day_u32));current[0x8a]=0;current[0x8b]=0
			context.body=current;context.root=game
			ok=_housekeeping(context)
			if ok:ok=_phase(context,false)
		"post_f1010":
			context.source_order.append("F1010")
			var view:int=context.root[0xea]
			if view!=5 and view!=6:
				if int(context.externals.action_a_u32)!=0:ok=_emit(context,"F1062",1062)
				if ok and int(context.externals.action_b_u32)!=0:ok=_emit(context,"F1064",1064)
			if ok:ok=_phase(context,true)
	if not ok:
		if not context.pending_request.is_empty():return {"ok":false,"pending":true,"profile":PROFILE,"request":context.pending_request.duplicate(true),"body_before":context.body.duplicate(),"root_before":context.root.duplicate(),"externals_before":context.externals.duplicate(true),"requests":context.requests.duplicate(true),"trace_consumed":int(context.cursor),"selected_function_id_u32":int(context.selected),"source_order":context.source_order.duplicate(),"live_owners_changed":false,"callback_bodies_executed":false,"full_player_cycle":false,"callback_effect_policy":"matched-raw-observation-boundaries-only","root_window_bytes":ROOT_WINDOW_BYTES}
		return _reject(str(context.error) if not str(context.error).is_empty() else "mode_callback_rejected")
	if not context.trace.is_empty() and int(context.cursor)!=context.trace.size():return _reject("unconsumed_observed_callback_trace")
	return {"ok":true,"profile":PROFILE,"body_after":context.body,"root_after":context.root,"externals_after":context.externals,"requests":context.requests,"trace_consumed":int(context.cursor),"selected_function_id_u32":int(context.selected),"source_order":context.source_order,"live_owners_changed":false,"callback_bodies_executed":false,"full_player_cycle":false,"callback_effect_policy":"matched-raw-observation-boundaries-only","root_window_bytes":ROOT_WINDOW_BYTES}
