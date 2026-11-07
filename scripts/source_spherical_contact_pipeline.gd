extends RefCounted
# Bounded DOS F575 player/simple-parent route. The original coarse test and
# F577 feed the unchanged postclassification player response. This is a raw
# object API: no object-bank traversal, automatic frame selection, terrain
# collision streams, F578 pair response, HP mutation or live-world dispatch.
const Response=preload("res://scripts/source_surface_contact.gd")
const Sphere=preload("res://scripts/source_spherical_contact.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const CONTRACT:="dos-firstenc-f575-simple-parent-player-route-v1"

static func _reject(body:PackedByteArray,parent:PackedByteArray,context:Dictionary,reason:String)->Dictionary:
	var original:Variant=context.get("globals",{})
	return {"ok":false,"error":reason,"source_contract":CONTRACT,"body_after":body.duplicate(),"parent_after":parent.duplicate(),"globals_after":original.duplicate(true) if original is Dictionary else {},"damage_calls":[],"callbacks":[],"response_applied":false,"classification_applied":false}

static func _valid(body:PackedByteArray,parent:PackedByteArray,context:Dictionary)->bool:
	var checked:=context.duplicate(true)
	checked["distance_squared_s32"]=0
	return Response._valid(body,parent,checked) and checked.globals.get("altitude_s64") is int

static func _absolute(relative:PackedInt64Array)->PackedInt64Array:
	var result:=PackedInt64Array()
	for value:int in relative:result.append(Response._sub64(0,value) if value<0 else value)
	return result

static func _passes_coarse(body:PackedByteArray,parent:PackedByteArray,absolute:PackedInt64Array)->bool:
	var total:=Response._add64(Response._add64(absolute[0],absolute[1]),absolute[2])
	var distance:=Ground._shift64(total,-1)
	distance=Response._sub64(distance,body.decode_s64(0x138))
	if distance>>32<0:return true
	distance=Response._sub64(distance,parent.decode_s64(0x138))
	return distance>>32<0

static func resolve_player(body:PackedByteArray,parent:PackedByteArray,context:Dictionary)->Dictionary:
	if not _valid(body,parent,context):return _reject(body,parent,context,"invalid_raw_player_context")
	var relative:=PackedInt64Array(context.relative_position_s64)
	var absolute:=_absolute(relative)
	var globals:Dictionary=context.globals.duplicate(true)
	var base:={"ok":true,"error":"","source_contract":CONTRACT,"body_after":body.duplicate(),"parent_after":parent.duplicate(),"globals_after":globals,"relative_position_s64":relative,"absolute_position_s64":absolute,"damage_calls":[],"callbacks":[],"response_applied":false,"classification_applied":false,"landing_accepted":false,"full_f569":false,"full_f575":false,"object_bank_traversed":false,"return_flags_u8":0}
	# F1664 changes the caller's vector to wrapped abs before this test. Our
	# public API returns that candidate vector without mutating caller inputs.
	if not _passes_coarse(body,parent,absolute):
		base["branch"]="coarse_rejected"
		return base
	if parent[0x14c]&0x80:return _reject(body,parent,context,"hierarchical_collision_stream_requires_f576")
	globals.collision_kind_u8=0
	var classified:Dictionary=Sphere.classify(body,parent,{"relative_position_s64":relative,"absolute_position_s64":absolute,"globals":globals})
	if not classified.get("ok",false):return _reject(body,parent,context,"sphere_classifier_rejected")
	base.classification_applied=true
	base["classification"]=classified
	globals=classified.globals_after.duplicate(true)
	base.globals_after=globals
	if int(classified.return_s32)!=0:
		base["branch"]="sphere_external_or_equal"
		base.return_flags_u8=int(globals.collision_flags_u8)
		return base
	# The source only takes this player continuation for its selected parent.
	# All other intersecting pairs need F578; reject them atomically rather
	# than turn an unsupported collision into a harmless no-effect result.
	if body[0x56]!=parent[0x86]:return _reject(body,parent,context,"other_pair_response_requires_f578")
	globals.collision_kind_u8=2
	var response_context:=context.duplicate(true)
	response_context.globals=globals
	response_context.distance_squared_s32=int(classified.distance_squared_s32)
	var response:Dictionary=Response.resolve_player(body,parent,response_context)
	if not response.get("ok",false):return _reject(body,parent,context,"player_response_rejected")
	base["branch"]="simple_parent_player_response"
	base.response_applied=true
	base["response"]=response
	for key:String in ["body_after","parent_after","globals_after","damage_calls","callbacks","landing_accepted","return_flags_u8"]:base[key]=response[key]
	return base
