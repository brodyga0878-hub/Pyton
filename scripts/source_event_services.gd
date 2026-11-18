extends RefCounted
# One owner projected into original event, player-handler and message kernels.
# A 48-byte message packet is always an explicit caller witness, never invented.
const Effects=preload("res://scripts/source_damage_effects.gd")
const Events=preload("res://scripts/source_events.gd")
const Player=preload("res://scripts/source_player_events.gd")
const Messages=preload("res://scripts/source_messages.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-event-services-v1"
const EVENT_LOCAL_KEYS:=["arena","tree_root_u32","nodes","next_node_id_u32","task_variables","next_variable_id_u32","definitions","scratch_words"]
const MESSAGE_KEYS:=["queue_records","queue_control","fallback_name"]
const KEYS:=["root","bank","event_registers","module_entries","module_count_s32","model_resources","arena","tree_root_u32","nodes","next_node_id_u32","task_variables","next_variable_id_u32","definitions","scratch_words","queue_records","queue_control","fallback_name","temporary_event_index_s32","watched_index_u8"]
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}
static func _view(value:Dictionary,keys:Array)->Dictionary:
	var result:Dictionary={}
	for key:String in keys:result[key]=value[key].duplicate(true) if value[key] is Dictionary or value[key] is Array else (value[key].duplicate() if value[key] is PackedByteArray else value[key])
	return result
static func _context(value:Variant)->bool:
	if not Events._keys(value,KEYS):return false
	if not Effects._context(_view(value,Effects.KEYS)) or not Events._context(_view(value,Events.CONTEXT_KEYS)) or not Player._context(_view(value,Player.CONTEXT_KEYS)):return false
	for key:String in MESSAGE_KEYS:
		if not value[key] is PackedByteArray or value[key].size()!=int(Messages.BYTE_COUNTS[key]):return false
	for index in [4,5,6]:
		if value.queue_control.decode_u32(index*4)>9:return false
	return true
static func _copy_context(value:Dictionary)->Dictionary:return value.duplicate(true)
static func decode_context(value:Variant)->Dictionary:
	if not Events._keys(value,KEYS):return {}
	var result:Dictionary=value.duplicate(true)
	var event:=Events.decode_context(_view(result,Events.CONTEXT_KEYS))
	if event.is_empty():return {}
	for key:String in event:result[key]=event[key]
	for key:String in ["module_entries"]+MESSAGE_KEYS:
		var count:int=168 if key=="module_entries" else int(Messages.BYTE_COUNTS[key])
		if Frame._hex(result[key],count):result[key]=str(result[key]).hex_decode()
	return _copy_context(result) if _context(result) else {}
static func _merge(base:Dictionary,result:Dictionary,keys:Array)->Dictionary:
	var out:=_copy_context(base)
	for key:String in keys:out[key]=result[key].duplicate(true) if result[key] is Dictionary or result[key] is Array else (result[key].duplicate() if result[key] is PackedByteArray else result[key])
	return out
static func _packets(value:Variant)->bool:
	if not value is Array or value.size()>32:return false
	for packet:Variant in value:
		if not Events._keys(packet,["call_index_u32","observations"]) or not Frame._whole(packet.call_index_u32,0,31) or not packet.observations is Array:return false
	return true
static func _packet(value:Variant)->Variant:
	if value is PackedByteArray and value.size()==48:return value.duplicate()
	return str(value).hex_decode() if Frame._hex(value,48) else null
static func bind_message_packet(pending:Variant,packet_value:Variant,caller_kind:Variant)->Dictionary:
	var packet:Variant=_packet(packet_value)
	if packet==null or not caller_kind is String or not pending is Dictionary or pending.get("kind")!="F349" or not pending.get("args") is Array:return _reject("invalid_partial_message_witness")
	var args:Array=pending.args;var offsets:Array=[0,0x18]
	if caller_kind=="equipment":
		if args.size()!=3:return _reject("invalid_equipment_message_witness")
		for word:Variant in args:
			if not Frame._whole(word,0,0xffffffff):return _reject("invalid_equipment_message_word")
		if packet.decode_u32(0)!=(int(args[0])&0xffffffff) or packet.decode_u32(4)!=(int(args[1])&0xffffffff) or packet.decode_u32(0x18)!=(int(args[2])&0xffffffff):return _reject("equipment_message_defined_word_mismatch")
		offsets.append(4)
	elif caller_kind=="destruction":
		if args.size()!=4 or not Frame._whole(args[1],0,1):return _reject("invalid_destruction_message_witness")
		for word:Variant in [args[0],args[2],args[3]]:
			if not Frame._whole(word,0,0xffffffff):return _reject("invalid_destruction_message_word")
		if packet.decode_u32(0)!=(int(args[0])&0xffffffff) or packet.decode_u32(0x18)!=(int(args[3])&0xffffffff) or (int(args[1])==1 and packet.decode_u32(0xc)!=(int(args[2])&0xffffffff)):return _reject("destruction_message_defined_word_mismatch")
		if int(args[1])==1:offsets.append(0xc)
	else:return _reject("unknown_message_callsite")
	return {"ok":true,"packet":packet,"defined_word_offsets_u32":offsets,"other_words_policy":"explicit-opaque-caller-witness","Main_integrated":false}
static func execute(context:Variant,command:Variant,observations:Variant=[],event_packets:Variant=[])->Dictionary:
	if not _context(context) or not command is Dictionary or not command.get("kind") is String or not observations is Array or observations.size()>256 or not _packets(event_packets):return _reject("invalid_event_services_command")
	var kind:String=command.kind;var state:=_copy_context(context);var result:Dictionary;var calls:Array=[]
	if kind=="events":
		if not Events._keys(command,["kind","operation","args"]) or not event_packets.is_empty():return _reject("invalid_events_service_command")
		var decoded:Variant=Events.decode_observations(observations)
		if decoded==null:return _reject("invalid_events_service_observations")
		result=Events.execute(_view(state,Events.CONTEXT_KEYS),command.operation,command.args,decoded)
		if result.get("ok",false):state=_merge(state,result.context_after,Events.CONTEXT_KEYS)
	elif kind=="message":
		var keys:Array=["kind","operation","packet","display_mode_s32"]
		if command.has("submitted_text"):keys.append("submitted_text")
		if not Events._keys(command,keys) or not event_packets.is_empty():return _reject("invalid_message_service_command")
		var packet:Variant=_packet(command.packet)
		if packet==null:return _reject("missing_explicit_message_packet")
		var message:=_view(state,["root","bank"]+MESSAGE_KEYS);message["packet"]=packet
		var decoded:Variant=Messages.decode_observations(observations)
		if decoded==null:return _reject("invalid_message_service_observations")
		var text:Variant=command.get("submitted_text",null)
		if text is String:
			if not Frame._hex(text,int(text.length()/2)):return _reject("invalid_submitted_message_hex")
			text=text.hex_decode()
		result=Messages.execute(message,command.operation,decoded,command.display_mode_s32,text)
		if result.get("ok",false):state=_merge(state,result.context_after,["root","bank"]+MESSAGE_KEYS)
	elif kind=="player":
		if not Events._keys(command,["kind","operation","payload"]):return _reject("invalid_player_service_command")
		var decoded:Variant=Player.decode_observations(observations)
		if decoded==null:return _reject("invalid_player_service_observations")
		var initial:=_view(state,Player.CONTEXT_KEYS);var trace:Array=[];var used:=0;var packet_used:=0
		for attempt in range(33):
			result=Player.execute(initial,command.payload,trace,command.operation)
			if result.get("ok",false):
				if used!=decoded.size() or packet_used!=event_packets.size():return _reject("unused_player_service_observations")
				state=_merge(state,result.context_after,Player.CONTEXT_KEYS);break
			if not result.get("pending") is Dictionary:break
			var pending:Dictionary=result.pending;state=_merge(state,pending.before,Player.CONTEXT_KEYS);var row:Dictionary
			if pending.kind=="F48":
				var replies:Array=[]
				if packet_used<event_packets.size() and int(event_packets[packet_used].call_index_u32)==calls.size():
					var nested:Variant=Events.decode_observations(event_packets[packet_used].observations)
					if nested==null:return _reject("invalid_nested_event_observations")
					replies=nested;packet_used+=1
				var event_args:Array=[]
				for word:Variant in pending.args:event_args.append(int(word)&0xffffffff)
				var invoked:=Events.execute(_view(state,Events.CONTEXT_KEYS),"F48",event_args,replies)
				if not invoked.get("ok",false):
					var failed:=_reject("events_"+str(invoked.get("reason","rejected")));failed["service_stage"]="events";failed["event_call_index_u32"]=calls.size();failed["caller_pending"]=pending.duplicate(true)
					if invoked.get("pending") is Dictionary:failed["pending"]=invoked.pending.duplicate(true)
					return failed
				state=_merge(state,invoked.context_after,Events.CONTEXT_KEYS)
				row={"kind":"F48","args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":_view(state,Player.CONTEXT_KEYS),"return_u32":0};calls.append(invoked.duplicate(true))
			else:
				if used>=decoded.size():break
				row=decoded[used].duplicate(true);used+=1
				if row.kind=="F48":return _reject("observed_F48_cannot_replace_actual_dispatch")
			trace.append(row)
	else:return _reject("unknown_event_service")
	if not result.get("ok",false):
		var failed:=_reject(kind+"_"+str(result.get("reason","rejected")));failed["service_stage"]=kind
		if result.get("pending") is Dictionary:failed["pending"]=result.pending.duplicate(true)
		return failed
	if not _context(state):return _reject("invalid_event_services_result")
	return {"ok":true,"profile":PROFILE,"context_after":state,"service_kind":kind,"kernel_result":result,"event_calls":calls,"source_order":result.get("source_order",[]).duplicate(),"live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}
