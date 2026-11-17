extends RefCounted
# Original F928/F924/F925 raw bank ownership. F144 module work is supplied as
# exact observations; this does not implement the world event or debris engine.
const Factory=preload("res://scripts/source_object_factory.gd")
const PROFILE:="dos-firstenc-object-slots-v1"
const BANK_BYTES:=38986
const HEADER_BYTES:=116
const OBJECT_BYTES:=338
const SLOT_COUNT:=115
const MODULE_WINDOW_BYTES:=168
const MASK:=0xffffffff
static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and float(value)==floorf(float(value))
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:Variant in value:
		if not key is String or key not in keys:return false
	return true
static func _hex(value:Variant,minimum:int,maximum:int)->bool:
	if not value is String or value.length()%2 or value.length()<minimum*2 or value.length()>maximum*2:return false
	for c:String in value:
		if c not in "0123456789abcdef":return false
	return true
static func _sha(raw:PackedByteArray)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(raw);return h.finish().hex_encode()
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"raw_owners_changed":false,"source_clock_advanced":false,"full_world_event_engine":false,"full_debris_engine":false}
static func _same_fields(left:Dictionary,right:Dictionary)->bool:
	if left.size()!=right.size():return false
	for key:Variant in right:
		if not left.has(key) or left[key]!=right[key]:return false
	return true
static func _result(bank:PackedByteArray,source:PackedByteArray,count:int,highest:int,window:PackedByteArray,selected:int,offset:int,copies:int,lookups:int,events:Array,source_slot:int=-1)->Dictionary:
	return {"ok":true,"profile":PROFILE,"bank_after":bank,"selected_slot_u32":selected,"return_body_offset_u32":offset,"recyclable_count_after_u32":count,"module_highest_after_s32":highest,"module_window_after":window,"factory_copy_calls_u32":copies,"factory_lookup_calls_u32":lookups,"events":events,"external_source_body_after":source,"source_pointer_body_after":source if source_slot<0 else bank.slice(HEADER_BYTES+source_slot*OBJECT_BYTES,HEADER_BYTES+(source_slot+1)*OBJECT_BYTES),"raw_owners_changed":false,"source_clock_advanced":false,"full_world_event_engine":false,"full_debris_engine":false,"count_source_alias":"Root+0x70/D8834","flags_pointer_policy":"D7758-explicit-owned-bank"}
static func allocate(bank:Variant,source:Variant,model_index:Variant,flags:Variant,clock:Variant,recyclable_count:Variant,source_slot:Variant=-1)->Dictionary:
	if not bank is PackedByteArray or bank.size()!=BANK_BYTES or not source is PackedByteArray or source.size()!=OBJECT_BYTES or not _whole(model_index,0,148) or not _whole(flags,0,255) or not Factory._clock(clock) or not _whole(recyclable_count,0,MASK) or not _whole(source_slot,-1,114):return _reject("invalid_raw_allocation_inputs")
	var resources:=Factory.source_model(model_index)
	if resources.is_empty():return _reject("factory_model_resource_unavailable")
	var candidate:PackedByteArray=bank.duplicate();var count:=int(recyclable_count);var selected:=0
	# F928 completes the zero search before starting the recyclable search.
	for index:int in range(114,0,-1):
		if candidate[index]==0:selected=index;break
	if selected==0:
		for index:int in range(114,0,-1):
			if int(candidate[index])&0x20:
				selected=index;count=(count-1)&MASK;break
	if selected==0:return _result(candidate,source.duplicate(),count,-1,PackedByteArray(),0,MASK,0,0,[],int(source_slot))
	candidate[selected]=int(flags)
	if int(flags)&0x20:count=(count+1)&MASK
	var at:=HEADER_BYTES+selected*OBJECT_BYTES
	var destination:=candidate.slice(at,at+OBJECT_BYTES)
	var supplied:PackedByteArray=source.duplicate() if int(source_slot)<0 else candidate.slice(HEADER_BYTES+int(source_slot)*OBJECT_BYTES,HEADER_BYTES+(int(source_slot)+1)*OBJECT_BYTES)
	var copy_source:=int(source_slot)!=selected
	var initialized:=Factory.initialize_context(destination,supplied,model_index,clock,resources,copy_source)
	if not initialized.get("ok",false):return _reject("factory_initialization_rejected")
	var body:PackedByteArray=initialized.body_after;body[0x86]=selected
	for i:int in range(OBJECT_BYTES):candidate[at+i]=body[i]
	return _result(candidate,source.duplicate(),count,-1,PackedByteArray(),selected,at,1 if copy_source else 0,1 if int(model_index)!=0 else 0,[],int(source_slot))
static func _patches(value:Variant,domain:int,limit:int)->bool:
	if not value is Array or value.size()>8:return false
	for p:Variant in value:
		if not _keys(p,["offset_u32","hex"]) or not _whole(p.offset_u32,0,domain-1) or not _hex(p.hex,1,limit) or int(p.offset_u32)+p.hex.length()/2>domain:return false
	return true
static func _event_before(value:Variant)->bool:
	return _keys(value,["event_index_u32","event_code_u32","payload_zero_u32","body_offset_u32","slot_u8","reason_u8","recyclable_count_before_u32","module_highest_before_s32","bank_before_sha256","module_window_before_hex"]) and _whole(value.event_index_u32,0,20) and _whole(value.event_code_u32,11,11) and _whole(value.payload_zero_u32,0,0) and _whole(value.body_offset_u32,HEADER_BYTES,BANK_BYTES-OBJECT_BYTES) and (int(value.body_offset_u32)-HEADER_BYTES)%OBJECT_BYTES==0 and _whole(value.slot_u8,0,114) and _whole(value.reason_u8,0,255) and _whole(value.recyclable_count_before_u32,0,MASK) and _whole(value.module_highest_before_s32,-1,20) and _hex(value.bank_before_sha256,32,32) and _hex(value.module_window_before_hex,MODULE_WINDOW_BYTES,MODULE_WINDOW_BYTES)
static func _reply(value:Variant)->bool:
	return _keys(value,["event_index_u32","recyclable_count_after_u32","module_highest_after_s32","bank_patches","module_patches"]) and _whole(value.event_index_u32,0,20) and _whole(value.recyclable_count_after_u32,0,MASK) and _whole(value.module_highest_after_s32,-1,20) and _patches(value.bank_patches,BANK_BYTES,16) and _patches(value.module_patches,MODULE_WINDOW_BYTES,8)
static func _apply(raw:PackedByteArray,patches:Array)->void:
	for p:Dictionary in patches:
		var bytes:=str(p.hex).hex_decode();var offset:=int(p.offset_u32)
		for i:int in range(bytes.size()):raw[offset+i]=bytes[i]
static func release(bank:Variant,body_slot:Variant,reason:Variant,recyclable_count:Variant,module_window:Variant,module_highest:Variant,event_observations:Variant=[],zero_reason:Variant=false)->Dictionary:
	if not bank is PackedByteArray or bank.size()!=BANK_BYTES or not _whole(body_slot,0,114) or not _whole(reason,0,255) or not _whole(recyclable_count,0,MASK) or not module_window is PackedByteArray or module_window.size()!=MODULE_WINDOW_BYTES or not _whole(module_highest,-1,20) or not event_observations is Array or event_observations.size()>21 or not zero_reason is bool:return _reject("invalid_raw_release_inputs")
	for event:Variant in event_observations:
		if not _keys(event,["before","reply"]) or not _event_before(event.before) or not _reply(event.reply):return _reject("invalid_module_event_observation")
	var candidate:PackedByteArray=bank.duplicate();var window:PackedByteArray=module_window.duplicate()
	var offset:=HEADER_BYTES+int(body_slot)*OBJECT_BYTES;var slot:=int(candidate[offset+0x86])
	if slot>=SLOT_COUNT:return _reject("release_record_slot_outside_owned_bank")
	var count:=int(recyclable_count);var highest:=int(module_highest);var events:Array=[]
	if int(candidate[slot])&0x20:count=(count-1)&MASK
	else:
		var index:=0
		while index<=highest:
			if int(window[index*8])&4:
				var before:={"event_index_u32":index,"event_code_u32":11,"payload_zero_u32":0,"body_offset_u32":offset,"slot_u8":slot,"reason_u8":0 if zero_reason else int(reason),"recyclable_count_before_u32":count,"module_highest_before_s32":highest,"bank_before_sha256":_sha(candidate),"module_window_before_hex":window.hex_encode()}
				if events.size()>=event_observations.size():return _reject("module_event_observation_mismatch")
				if not _same_fields(event_observations[events.size()].before,before) or int(event_observations[events.size()].reply.event_index_u32)!=index:return _reject("module_event_observation_mismatch")
				var reply:Dictionary=event_observations[events.size()].reply
				count=int(reply.recyclable_count_after_u32);highest=int(reply.module_highest_after_s32)
				_apply(candidate,reply.bank_patches);_apply(window,reply.module_patches);events.append(before)
			index+=1
	if events.size()!=event_observations.size():return _reject("unused_module_event_observation")
	# EDI is the slot captured before callbacks, even if record+0x86 changes.
	candidate[slot]=0
	return _result(candidate,PackedByteArray(),count,highest,window,0,MASK,0,0,events)
static func release_zero_reason(bank:Variant,body_slot:Variant,recyclable_count:Variant,module_window:Variant,module_highest:Variant,event_observations:Variant=[])->Dictionary:
	return release(bank,body_slot,0,recyclable_count,module_window,module_highest,event_observations,true)
