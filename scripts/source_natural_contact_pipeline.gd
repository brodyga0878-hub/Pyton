extends RefCounted
# Explicit raw-object composition of F576 and the supported natural branch of
# F575. F574/F570 resets, broad phase and source frame selection are caller
# responsibilities. No phone clearance, height synthesis or HP/RNG owner is used.
const Natural=preload("res://scripts/source_natural_contact.gd")
const Response=preload("res://scripts/source_surface_contact.gd")
const CONTRACT:="dos-firstenc-f576-f575-natural-player-pipeline-v1"
const SCOPE:="Explicit raw natural-player F576 classification and supported F575 kind1 continuation only; no F574 reset, F575 broad phase, F569/F570, F578, world bank, phone pose, executed HP/RNG, fuel or clock."
const MASK:=0xffffffff
var _classifier:=Natural.new()

static func _reject(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,context:Dictionary,reason:String)->Dictionary:
	var initial:Variant=context.get("initial_globals",{})
	return {"ok":false,"error":reason,"body_after":body.duplicate(),"parent_after":parent.duplicate(),"relative_position_s64":relative.duplicate(),"globals_after":initial.duplicate(true) if initial is Dictionary else {},"global_writes":{},"response_applied":false,"contact_detected":false,"landing_accepted":false,"damage_calls":[],"callbacks":[],"classification":{},"response":{},"source_contract":CONTRACT,"source_sha256":Natural.SOURCE_SHA,"scope":SCOPE}

static func _valid_context(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,context:Dictionary)->bool:
	if body.size()!=Natural.OBJECT_BYTES or parent.size()!=Natural.OBJECT_BYTES or relative.size()!=3:return false
	# The natural-parent F575 dispatch requires the signed collision flag.
	if parent[0x14c]<128:return false
	for key:Variant in context:
		if key not in ["graphics_level","initial_globals","player_object_index_u32"]:return false
	if not context.get("initial_globals") is Dictionary:return false
	var initial:Dictionary=context.initial_globals
	# All low/high words are explicit. In particular, an inner-bound hit does
	# not write previous altitude; a missing caller word must not become zero.
	for key:String in Natural.GLOBAL_KEYS:
		if not initial.has(key):return false
	if Natural._globals(initial).is_empty():return false
	var player:Variant=context.get("player_object_index_u32")
	if not Natural._whole(player,0,MASK) or int(player)!=int(body[0x86]):return false
	return Natural._whole(context.get("graphics_level",1),0,15)

static func _writes(before:Dictionary,after:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in Natural.GLOBAL_KEYS:
		if before[key]!=after[key]:result[key]=after[key]
	return result

func resolve_natural_player(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,context:Dictionary)->Dictionary:
	if not _valid_context(body,parent,relative,context):return _reject(body,parent,relative,context,"invalid_or_unsupported_raw_natural_context")
	var classified:=_classifier.classify_natural_player(body,parent,relative,{"graphics_level":int(context.get("graphics_level",1)),"initial_globals":context.initial_globals.duplicate(true)})
	if not classified.get("ok",false):return _reject(body,parent,relative,context,str(classified.get("error","natural_classification_failed")))
	return _dispatch_classification(body,parent,relative,context,classified)

func _dispatch_classification(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,context:Dictionary,classified:Dictionary)->Dictionary:
	# Internal dispatch seam. Production calls receive this value only from
	# the classifier above. Synthetic guard tests do not prove source hits.
	var state:Dictionary=classified.globals_after.duplicate(true)
	var classifier_return:=int(classified.f576_return_s32)
	var response:Dictionary={};var candidate:=body.duplicate();var hit:=false
	var dispatch:="f575_early_return"
	if classifier_return==0:
		var kind:=int(state.collision_kind_u8)
		if kind==0:return _reject(body,parent,relative,context,"unsupported_f578_contact")
		if kind!=1:return _reject(body,parent,relative,context,"unsupported_f575_contact_kind")
		var ship:=Natural.ship_model(body.decode_u32(0x82));var natural_parent:=Natural.parent_model(parent.decode_u32(0x82))
		var spec:=str(ship.get("physical_spec_hex","")).hex_decode()
		if ship.is_empty() or natural_parent.is_empty() or spec.size()!=Response.SPEC_BYTES or Natural._sha(spec)!=str(ship.get("physical_spec_sha256","")):
			return _reject(body,parent,relative,context,"unverified_source_response_resources")
		var response_globals:=state.duplicate(true)
		response_globals["previous_altitude_s64"]=(int(state.previous_altitude_high_s32)<<32)|int(state.previous_altitude_low_u32)
		response_globals["player_object_index_u32"]=int(context.player_object_index_u32)
		# F575 uses its original unshifted relative copy, not the last child
		# query's observer. The previous altitude is exactly the F581 result.
		response=Response.resolve_player(body,parent,{"relative_position_s64":relative.duplicate(),"distance_squared_s32":0,"globals":response_globals,"body_descriptor":ship.descriptor.duplicate(),"parent_descriptor":natural_parent.descriptor.duplicate(),"body_spec":spec})
		if not response.get("ok",false):return _reject(body,parent,relative,context,str(response.get("error","natural_response_failed")))
		candidate=response.body_after.duplicate();hit=true;dispatch="f575_natural_kind1_response"
		for key:String in Natural.GLOBAL_KEYS:state[key]=response.globals_after[key]
	var previous:=(int(state.previous_altitude_high_s32)<<32)|int(state.previous_altitude_low_u32)
	var altitude:=(int(state.altitude_high_s32)<<32)|int(state.altitude_low_u32)
	return {"ok":true,"error":"","body_after":candidate,"parent_after":parent.duplicate(),"relative_position_s64":relative.duplicate(),"globals_after":state,"global_writes":_writes(context.initial_globals,state),"f576_return_s32":classifier_return,"return_flags_u8":int(state.collision_flags_u8),"dispatch":dispatch,"response_applied":hit,"contact_detected":hit,"landing_accepted":bool(response.get("landing_accepted",false)),"damage_calls":response.get("damage_calls",[]).duplicate(true),"callbacks":response.get("callbacks",[]).duplicate(true),"altitude_s64":altitude,"previous_altitude_s64":previous,"classification":classified.duplicate(true),"response":response.duplicate(true),"source_contract":CONTRACT,"source_sha256":Natural.SOURCE_SHA,"scope":SCOPE}
