extends RefCounted
# The original F569/F570 bank traversal now invokes the whole F575 kernel.
# F576 general model programs and destruction effects still require exact
# observed continuations. Missing geometry never becomes an empty collision.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Classifier=preload("res://scripts/source_contact_classifier.gd")
const GeometryContact=preload("res://scripts/source_collision_contact.gd")
const Context=preload("res://scripts/source_player_context.gd")
const Motion=preload("res://scripts/source_player_motion.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const PROFILE:="dos-firstenc-actual-f569-f575-scan-v1"
const LIMIT:=115

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"full_collision_program_VM":false,"Main_integrated":false}
static func json_value(value:Variant)->Variant:
	if value is PackedByteArray:return value.hex_encode()
	if value is Dictionary:
		var result:Dictionary={}
		for key:Variant in value:result[key]=json_value(value[key])
		return result
	if value is Array:
		var result:Array=[]
		for cell:Variant in value:result.append(json_value(cell))
		return result
	return value
static func _observations(value:Variant)->Variant:
	if not value is Array or value.size()>32:return null
	var result:Array=[]
	for item:Variant in value:
		if not item is Dictionary:return null
		var row:Dictionary=item.duplicate(true)
		for side:String in ["before","after"]:
			if not row.get(side) is Dictionary:return null
			for key:String in ["body","collider","relative"]:
				var count:=24 if key=="relative" else 338
				if row[side].get(key) is PackedByteArray:
					if row[side][key].size()!=count:return null
				elif Frame._hex(row[side].get(key),count):row[side][key]=str(row[side][key]).hex_decode()
				else:return null
		result.append(row)
	return result
static func dispatch(body:Variant,objects:Variant,flags:Variant,root:Variant,globals:Variant,frame_ticks_u32:Variant,source_frame_byte:Variant,classifier_observations:Variant=[],enabled:Variant=true,use_geometry:Variant=false)->Dictionary:
	if not Frame._raw_bank(body,objects,flags) or not Context._root(root) or root.decode_u32(0xc0)>114 or not Frame._globals(globals) or not Frame._whole(frame_ticks_u32,0,0xffffffff) or not Frame._whole(source_frame_byte,0,255) or not enabled is bool or not use_geometry is bool or not classifier_observations is Array or classifier_observations.size()>LIMIT:return _reject("invalid_actual_contact_scan_context")
	for row:Variant in classifier_observations:
		if not row is Dictionary:return _reject("invalid_classifier_observation_packet")
		var keys:Array=["call_index_u32","observations"]
		if use_geometry and row.has("geometry_observations"):keys.append("geometry_observations")
		if not Clock._keys(row,keys) or not Frame._whole(row.call_index_u32,0,LIMIT-1) or _observations(row.observations)==null:return _reject("invalid_classifier_observation_packet")
		if row.has("geometry_observations") and (not row.geometry_observations is Array or row.geometry_observations.size()>64):return _reject("invalid_geometry_observation_packet")
	var trace:Array=[];var used:=0;var game:PackedByteArray=root.duplicate();var calls:Array=[]
	for attempt in range(LIMIT+1):
		var result:=Frame.dispatch(body,objects,flags,globals,frame_ticks_u32,source_frame_byte,trace,enabled,Frame.PROFILE,true)
		if result.get("ok",false):
			if used!=classifier_observations.size():return _reject("unused_classifier_observation_packet")
			result.profile=PROFILE;result.root_after=game;result.classifier_calls=calls;result.classifier_trace=trace;result.body_before_hex=body.hex_encode()
			result.F575_body_executed=not calls.is_empty();result.full_collision_classifier=false
			result.full_collision_program_VM=false;result.Main_integrated=false
			if use_geometry:result["actual_geometry_route"]=true
			return result
		if not result.get("pending") is Dictionary:return _reject("frame_"+str(result.get("reason","rejected")))
		var pending:Dictionary=result.pending
		var state:Dictionary=pending.globals.duplicate(true);state["player_index_u32"]=game.decode_u32(0xc0)
		var responses:Array=[]
		var geometry_responses:Array=[]
		if used<classifier_observations.size() and int(classifier_observations[used].call_index_u32)==trace.size():
			responses=_observations(classifier_observations[used].observations)
			geometry_responses=classifier_observations[used].get("geometry_observations",[]).duplicate(true);used+=1
		var classified:=GeometryContact.execute(pending.subject,pending.collider,pending.relative,state,responses,geometry_responses) if use_geometry else Classifier.execute(pending.subject,pending.collider,pending.relative,state,responses)
		if not classified.get("ok",false):
			var failure:=_reject("classifier_"+str(classified.get("reason","rejected")))
			if classified.get("pending") is Dictionary:
				failure.pending=classified.pending.duplicate(true);failure.classifier_call_index_u32=trace.size()
			if classified.has("geometry_iteration_u32"):failure["geometry_iteration_u32"]=int(classified.geometry_iteration_u32)
			return failure
		if int(classified.globals_after.player_index_u32)>114:return _reject("classifier_player_reference_outside_bank")
		game.encode_u32(0xc0,int(classified.globals_after.player_index_u32))
		var after:Dictionary={}
		for key:String in Frame.GLOBAL_KEYS:after[key]=classified.globals_after[key]
		trace.append({"subject_before_hex":pending.subject.hex_encode(),"collider_index_u8":pending.collider_index_u8,"collider_before_hex":pending.collider.hex_encode(),"relative_before_hex":pending.relative.hex_encode(),"globals_before":pending.globals.duplicate(true),"subject_after_hex":classified.body_after.hex_encode(),"collider_after_hex":classified.collider_after.hex_encode(),"globals_after":after,"return_u8":int(classified.return_u8)})
		calls.append({"collider_index_u8":pending.collider_index_u8,"source_order":classified.source_order.duplicate(),"requests":json_value(classified.requests),"relative_after_hex":classified.relative_after.hex_encode()})
		if use_geometry:calls[-1]["geometry_calls"]=json_value(classified.geometry_calls)
	return _reject("contact_scan_boundary_limit")
static func contact_boundary(before_body:Variant,result:Variant)->Dictionary:
	if not before_body is PackedByteArray or before_body.size()!=338 or not result is Dictionary or result.get("ok")!=true or result.get("profile")!=PROFILE or result.get("body_before_hex")!=before_body.hex_encode():return {}
	var outputs:Variant=result.get("outputs")
	if not outputs is Dictionary or not result.get("body") is PackedByteArray or not result.get("objects_by_index") is Dictionary:return {}
	var reference:int=int(outputs.collider_ref_u32);var collider:=PackedByteArray();collider.resize(338)
	if reference==int(result.body[0x86]):collider=result.body.duplicate()
	elif reference!=0:
		if not result.objects_by_index.has(reference):return {}
		collider=result.objects_by_index[reference].duplicate()
	return {"caller_profile":Motion.CONTACT_PROFILE,"body_before_hex":before_body.hex_encode(),"body_after_hex":result.body.hex_encode(),"flags_u8":int(outputs.flags_u8),"altitude_raw_s32":int(outputs.altitude_s32),"collider_ref_u32":reference,"collider_index_u8":int(outputs.collider_index_u8),"material_u8":int(outputs.material_u8),"collider_body_hex":collider.hex_encode()}
