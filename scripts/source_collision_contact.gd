extends RefCounted
# Actual F576 geometry is resumed inside F575 before its pair/player response.
# Damage remains matched; raw terrain state enables actual height queries.
const Classifier=preload("res://scripts/source_contact_classifier.gd")
const Geometry=preload("res://scripts/source_collision_geometry.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const TerrainState=preload("res://scripts/source_terrain_state.gd")
const PROFILE:="dos-firstenc-geometry-contact-composition-v1"

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_collision_program_VM":false}
static func execute(body:Variant,collider:Variant,relative:Variant,globals:Variant,observations:Variant=[],geometry_observations:Variant=[],terrain_state:Variant=null)->Dictionary:
	if not observations is Array or observations.size()>64 or not geometry_observations is Array or geometry_observations.size()>64:return _reject("invalid_geometry_contact_observations")
	if terrain_state!=null and (not TerrainState.valid(terrain_state) or not geometry_observations.is_empty()):return _reject("invalid_actual_terrain_context_or_observations")
	var terrain:Variant=terrain_state.duplicate(true) if terrain_state!=null else null
	var trace:Array=[];var used:=0;var geometry_used:=false;var calls:Array=[]
	for attempt in range(65):
		var result:=Classifier.execute(body,collider,relative,globals,trace)
		if result.get("ok",false):
			if used!=observations.size() or (not geometry_used and not geometry_observations.is_empty()):return _reject("unused_geometry_contact_observations")
			result.profile=PROFILE;result.geometry_calls=calls;result.F576_body_executed=geometry_used;result.full_collision_program_VM=false
			if terrain!=null:result["terrain_state_after"]=terrain.duplicate(true);result["actual_terrain_route"]=true
			return result
		if not result.get("pending") is Dictionary:return _reject("classifier_"+str(result.get("reason","rejected")))
		var pending:Dictionary=result.pending;var row:Dictionary
		if pending.kind=="F576":
			if geometry_used:return _reject("unexpected_repeated_F576_boundary")
			var before:Dictionary=pending.before
			var state:Dictionary={}
			for key:String in Frame.GLOBAL_KEYS:state[key]=before.globals[key]
			var geometry:=Geometry.execute(before.body,before.collider,before.relative,state,geometry_observations,{},terrain)
			if not geometry.get("ok",false):
				var failure:=_reject("geometry_"+str(geometry.get("reason","rejected")))
				if geometry.get("pending") is Dictionary:failure.pending=geometry.pending.duplicate(true)
				if geometry.has("iteration_u32"):failure["geometry_iteration_u32"]=int(geometry.iteration_u32)
				return failure
			if terrain!=null:terrain=geometry.terrain_state_after.duplicate(true)
			var after_globals:Dictionary=before.globals.duplicate(true)
			for key:String in Frame.GLOBAL_KEYS:after_globals[key]=geometry.globals_after[key]
			row={"kind":pending.kind,"args":pending.args.duplicate(),"before":before.duplicate(true),"after":{"body":before.body.duplicate(),"collider":before.collider.duplicate(),"relative":before.relative.duplicate(),"globals":after_globals},"return_u32":int(geometry.return_s32)&0xffffffff}
			calls.append(geometry.duplicate(true));geometry_used=true
		else:
			if used>=observations.size():
				var failure:=_reject("boundary_required");failure.pending=pending.duplicate(true);return failure
			if not observations[used] is Dictionary:return _reject("invalid_geometry_contact_observation")
			row=observations[used].duplicate(true);used+=1
			if row.get("kind")=="F576":return _reject("F576_requires_actual_geometry")
		trace.append(row)
	return _reject("geometry_contact_boundary_limit")
