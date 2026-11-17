extends RefCounted
# Resume original F575 with measured F953 and optional real model/terrain calls.
# External equipment/destruction handlers remain explicit typed continuations.
const Classifier=preload("res://scripts/source_contact_classifier.gd")
const Geometry=preload("res://scripts/source_collision_geometry.gd")
const Damage=preload("res://scripts/source_damage.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const TerrainState=preload("res://scripts/source_terrain_state.gd")
const PROFILE:="dos-firstenc-f575-f953-damage-composition-v1"
const MAX_CALLS:=64

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_damage_effects_executed":false}

static func execute(body:Variant,collider:Variant,relative:Variant,globals:Variant,damage_context:Variant,observations:Variant=[],damage_observations:Variant=[],geometry_observations:Variant=[],terrain_state:Variant=null,use_geometry:Variant=false)->Dictionary:
	if not Damage._context(damage_context) or not Classifier._globals(globals) or not observations is Array or observations.size()>MAX_CALLS or not damage_observations is Array or damage_observations.size()>MAX_CALLS or not geometry_observations is Array or geometry_observations.size()>MAX_CALLS or not use_geometry is bool:return _reject("invalid_actual_damage_contact_context")
	if damage_context.root.decode_u32(0xc0)!=int(globals.player_index_u32):return _reject("unbound_damage_player_reference")
	if terrain_state!=null and (not use_geometry or not TerrainState.matches_root(damage_context.root,terrain_state)):return _reject("unbound_damage_terrain_state")
	if not use_geometry and not geometry_observations.is_empty():return _reject("unused_geometry_observations")
	for packet:Variant in damage_observations:
		if not Classifier._keys(packet,["call_index_u32","observations"]) or not Frame._whole(packet.call_index_u32,0,MAX_CALLS-1) or Damage.decode_observations(packet.observations)==null:return _reject("invalid_damage_observation_packet")
	var context:Dictionary=Damage._copy_context(damage_context)
	var terrain:Variant=terrain_state.duplicate(true) if terrain_state!=null else null
	var trace:Array=[];var used:=0;var damage_used:=0;var geometry_used:=false
	var geometry_calls:Array=[];var damage_calls:Array=[]
	for attempt in range(MAX_CALLS+1):
		var result:=Classifier.execute(body,collider,relative,globals,trace)
		if result.get("ok",false):
			if used!=observations.size() or damage_used!=damage_observations.size() or (not geometry_used and not geometry_observations.is_empty()):return _reject("unused_actual_damage_contact_observations")
			result.profile=PROFILE;result["damage_context_after"]=Damage._copy_context(context);result["damage_calls"]=damage_calls;result["geometry_calls"]=geometry_calls
			result["F953_body_executed"]=not damage_calls.is_empty();result["damage_engine_executed"]=not damage_calls.is_empty();result["actual_damage_route"]=true;result["full_damage_effects_executed"]=false;result["Main_integrated"]=false
			result["F576_body_executed"]=geometry_used
			if terrain!=null:result["terrain_state_after"]=terrain.duplicate(true);result["actual_terrain_route"]=true
			return result
		if not result.get("pending") is Dictionary:return _reject("classifier_"+str(result.get("reason","rejected")))
		var pending:Dictionary=result.pending;var row:Dictionary
		if pending.kind=="F576" and use_geometry:
			if geometry_used:return _reject("unexpected_repeated_F576_boundary")
			var before:Dictionary=pending.before;var state:Dictionary={}
			for key:String in Frame.GLOBAL_KEYS:state[key]=before.globals[key]
			var calculated:=Geometry.execute(before.body,before.collider,before.relative,state,geometry_observations,{},terrain)
			if not calculated.get("ok",false):
				var failure:=_reject("geometry_"+str(calculated.get("reason","rejected")))
				if calculated.get("pending") is Dictionary:failure["pending"]=calculated.pending.duplicate(true)
				if calculated.has("iteration_u32"):failure["geometry_iteration_u32"]=int(calculated.iteration_u32)
				return failure
			if terrain!=null:terrain=calculated.terrain_state_after.duplicate(true)
			var after_globals:Dictionary=before.globals.duplicate(true)
			for key:String in Frame.GLOBAL_KEYS:after_globals[key]=calculated.globals_after[key]
			row={"kind":pending.kind,"args":pending.args.duplicate(),"before":before.duplicate(true),"after":{"body":before.body.duplicate(),"collider":before.collider.duplicate(),"relative":before.relative.duplicate(),"globals":after_globals},"return_u32":int(calculated.return_s32)&0xffffffff}
			geometry_calls.append(calculated.duplicate(true));geometry_used=true
		elif pending.kind=="F953":
			var before:Dictionary=pending.before;var target:int=int(pending.args[0]);var side:String
			if target==int(before.body[0x86]) and target!=int(before.collider[0x86]):side="body"
			elif target==int(before.collider[0x86]) and target!=int(before.body[0x86]):side="collider"
			else:return _reject("unbound_or_ambiguous_damage_target")
			var replies:Array=[]
			if damage_used<damage_observations.size() and int(damage_observations[damage_used].call_index_u32)==damage_calls.size():
				replies=Damage.decode_observations(damage_observations[damage_used].observations);damage_used+=1
			context.root.encode_u32(0xc0,int(before.globals.player_index_u32))
			var amount:int=(int(pending.args[1])&0x7fffffff)-(int(pending.args[1])&0x80000000)
			var calculated:=Damage.execute(before[side],amount,int(pending.args[2])&0xffffffff,context,replies)
			if not calculated.get("ok",false):
				var failure:=_reject("damage_"+str(calculated.get("reason","rejected")))
				if calculated.get("pending") is Dictionary:failure["pending"]=calculated.pending.duplicate(true)
				failure["classifier_pending"]=pending.duplicate(true);failure["damage_call_index_u32"]=damage_calls.size()
				return failure
			context=Damage._copy_context(calculated.context_after)
			if terrain!=null:terrain.graphics_level_u32=context.root.decode_u32(0x10)
			if int(calculated.body_after[0x86])!=target:return _reject("damage_changed_object_identity_requires_slot_lifecycle")
			if context.root.decode_u32(0xc0)>114:return _reject("damage_player_reference_outside_bank")
			var after:Dictionary=before.duplicate(true);after[side]=calculated.body_after.duplicate();after.globals.player_index_u32=context.root.decode_u32(0xc0)
			row={"kind":pending.kind,"args":pending.args.duplicate(),"before":before.duplicate(true),"after":after,"return_u32":int(calculated.return_u32)}
			damage_calls.append({"target":side,"target_index_u8":target,"calculation":calculated.duplicate(true)})
		else:
			if used>=observations.size():
				var failure:=_reject("boundary_required");failure["pending"]=pending.duplicate(true);return failure
			if not observations[used] is Dictionary:return _reject("invalid_damage_contact_observation")
			row=observations[used].duplicate(true);used+=1
			if row.get("kind")=="F953" or (use_geometry and row.get("kind")=="F576"):return _reject("observed_reply_cannot_replace_actual_kernel")
			if Classifier._context(row.get("after")):context.root.encode_u32(0xc0,int(row.after.globals.player_index_u32))
		trace.append(row)
	return _reject("damage_contact_boundary_limit")
