extends RefCounted
class_name SourceContactClassifier
# Whole DOS F575 caller, source sphere and pair response. General hierarchy
# F576 and authoritative damage F953 require exact observed continuations.
const Response=preload("res://scripts/source_surface_contact.gd")
const Sphere=preload("res://scripts/source_spherical_contact.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const Factory=preload("res://scripts/source_object_factory.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Pair=preload("res://scripts/source_pair_response.gd")
const PROFILE:="dos-firstenc-whole-f575-classifier-v1"
const BODY_BYTES:=338
const GLOBAL_KEYS:=["collision_flags_u8","volume_flags_u8","collider_index_u8","collision_active_u8","collision_enabled_u8","primitive_flags_u8","altitude_low_u32","altitude_high_s32","previous_altitude_low_u32","previous_altitude_high_s32","collision_kind_u8","collider_ref_u32","player_index_u32"]
const MASK:=0xffffffff
static func _globals(value:Variant)->bool:
	if not value is Dictionary or not _keys(value,GLOBAL_KEYS):return false
	var subset:Dictionary={}
	for key:String in Frame.GLOBAL_KEYS:subset[key]=value[key]
	return Frame._globals(subset) and Factory._whole(value.player_index_u32,0,MASK)
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:Variant in value:
		if not (key is String or key is StringName) or str(key) not in keys:return false
	return true
static func _body(value:Variant)->bool:return value is PackedByteArray and value.size()==BODY_BYTES
static func _relative(value:Variant)->bool:return value is PackedByteArray and value.size()==24
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"general_F576_geometry_executed":false,"damage_engine_executed":false,"full_world_classifier":false}
static func _context(value:Variant)->bool:return value is Dictionary and _keys(value,["body","collider","relative","globals"]) and _body(value.body) and _body(value.collider) and _relative(value.relative) and _globals(value.globals)
static func _copy_globals(value:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in GLOBAL_KEYS:result[key]=int(value[key])
	return result
static func _same_context(first:Variant,second:Dictionary)->bool:
	if not _context(first) or first.body!=second.body or first.collider!=second.collider or first.relative!=second.relative:return false
	for key:String in GLOBAL_KEYS:
		if int(first.globals[key])!=int(second.globals[key]):return false
	return true
static func _same_args(value:Variant,expected:Array)->bool:
	if not value is Array or value.size()!=expected.size():return false
	for index in range(expected.size()):
		if not Factory._whole(value[index],-0x80000000,MASK) or (int(value[index])&MASK)!=(int(expected[index])&MASK):return false
	return true
static func _vector(raw:PackedByteArray)->PackedInt64Array:return PackedInt64Array([raw.decode_s64(0),raw.decode_s64(8),raw.decode_s64(16)])
static func _bytes(vector:PackedInt64Array)->PackedByteArray:
	var raw:=PackedByteArray();raw.resize(24)
	for axis in range(3):raw.encode_s64(axis*8,vector[axis])
	return raw
static func execute(body:Variant,collider:Variant,relative:Variant,globals:Variant,observations:Variant=[])->Dictionary:
	if not _body(body) or not _body(collider) or not _relative(relative) or not _globals(globals) or not observations is Array or observations.size()>64:return _reject("invalid_classifier_context")
	var runner:=Classifier.new();runner.body=body.duplicate();runner.collider=collider.duplicate();runner.relative=relative.duplicate();runner.globals=_copy_globals(globals);runner.observations=observations.duplicate(true)
	return runner.run()

class Classifier:
	var body:PackedByteArray
	var collider:PackedByteArray
	var relative:PackedByteArray
	var absolute:PackedByteArray
	var globals:Dictionary
	var observations:Array
	var used:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	var sphere_executed:=false
	var pair_executed:=false
	func context()->Dictionary:return {"body":body.duplicate(),"collider":collider.duplicate(),"relative":relative.duplicate(),"globals":globals.duplicate(true)}
	func fail(reason:String)->bool:
		stopped=SourceContactClassifier._reject(reason);stopped.observations_used=used;stopped.source_order=order.duplicate();return false
	func boundary(kind:String,args:Array)->Dictionary:
		order.append(kind)
		var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":context()}
		if used>=observations.size():fail("boundary_required");stopped.pending=pending;return {}
		var row:Variant=observations[used]
		if not row is Dictionary or not SourceContactClassifier._keys(row,["kind","args","before","after","return_u32"]) or row.kind!=kind or not SourceContactClassifier._same_args(row.args,args) or not SourceContactClassifier._same_context(row.before,pending.before) or not SourceContactClassifier._context(row.after) or not SourceContactClassifier.Factory._whole(row.return_u32,0,SourceContactClassifier.MASK):fail("unmatched_classifier_observation");return {}
		# Logical references belong to the outer raw bank. Destruction that
		# reallocates a slot is outside this bounded callback composition.
		if row.after.body[0x86]!=body[0x86] or row.after.collider[0x86]!=collider[0x86]:fail("classifier_observation_changed_object_identity");return {}
		if kind!="F576" and row.after.relative!=relative:fail("unpassed_relative_mutated");return {}
		body=row.after.body.duplicate();collider=row.after.collider.duplicate();relative=row.after.relative.duplicate();globals=SourceContactClassifier._copy_globals(row.after.globals)
		requests.append(row.duplicate(true));used+=1;return {"ok":true,"return_u32":int(row.return_u32)}
	func model(record:PackedByteArray)->Dictionary:
		order.append("F1538")
		var result:=SourceContactClassifier.Factory.source_model(record.decode_u32(0x82))
		if result.is_empty():fail("source_model_unavailable")
		return result
	func result(value:int)->Dictionary:
		if used!=observations.size():fail("unused_classifier_observations");return stopped
		return {"ok":true,"profile":SourceContactClassifier.PROFILE,"body_after":body.duplicate(),"collider_after":collider.duplicate(),"relative_after":absolute.duplicate(),"globals_after":globals.duplicate(true),"return_u8":value&255,"source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"F575_body_executed":true,"F577_body_executed":sphere_executed,"F578_body_executed":pair_executed,"general_F576_geometry_executed":false,"damage_engine_executed":false,"live_owners_changed":false,"full_world_classifier":false}
	func align(normal:PackedInt64Array)->void:
		order.append_array(["F571","F1520","F571"])
		SourceContactClassifier.Response._write_matrix(body,SourceContactClassifier.Response._align_up(SourceContactClassifier.Response._matrix(body),normal))
	func response(distance_squared:int)->bool:
		var R=SourceContactClassifier.Response
		globals.collision_flags_u8=int(globals.collision_flags_u8)|2
		var old_l1:int=R._l1(R._velocity(body));var normal:PackedInt64Array=R._radial_normal(SourceContactClassifier._vector(relative)) if int(globals.collision_kind_u8)==1 else SourceContactClassifier.Ground._normalize_vector(PackedInt64Array([R._s32(relative.decode_s64(0)),R._s32(relative.decode_s64(8)),R._s32(relative.decode_s64(16))]))
		var matrix:PackedInt64Array=R._matrix(body)
		var alignment:int=R._dot(PackedInt64Array([matrix[3],matrix[4],matrix[5]]),normal)
		if old_l1<=0x258 and body.decode_u16(0x9e)==65535 and alignment>=0x78000000:
			globals.collision_flags_u8=(int(globals.collision_flags_u8)|0x40)&0x7f;globals.collision_active_u8=0
		else:globals.collision_active_u8=int(globals.collision_enabled_u8)
		var own_model:=model(body)
		if own_model.is_empty():return false
		var other_model:=model(collider)
		if other_model.is_empty():return false
		var descriptor:PackedByteArray=str(own_model.descriptor_hex).hex_decode();var other:PackedByteArray=str(other_model.descriptor_hex).hex_decode()
		if int(globals.collision_kind_u8)==1:
			var previous:int=R._s64(int(globals.previous_altitude_low_u32),int(globals.previous_altitude_high_s32))
			var correction:int=R._s32(R._sub64(body.decode_s64(0x140),previous))
			for axis in range(3):body.encode_s64(0x3e+axis*8,R._add64(body.decode_s64(0x3e+axis*8),R._mul(correction,normal[axis])))
		else:
			var target:int=R._s32(other.decode_s32(0x2c)<<16);var parent_scale:int=R._s32(other.decode_s32(0x14)+other.decode_s32(0x18));var own_scale:int=R._s32(descriptor.decode_s32(0x14)+descriptor.decode_s32(0x18));var shift:int=R._s32(parent_scale-own_scale)
			var own_radius:int=R._s32(descriptor.decode_s32(0x30)<<16)
			if shift!=0:own_radius>>=shift&31
			target=R._s32(target+own_radius)
			if target<0:target=(target&SourceContactClassifier.MASK)>>1;distance_squared=R._s32(distance_squared+1)
			var vector:=PackedInt64Array([R._s32(relative.decode_s64(0)),R._s32(relative.decode_s64(8)),R._s32(relative.decode_s64(16))]);var projected:PackedInt64Array=R._normalize_to(vector,target,distance_squared)
			var high_shift:int=R._s32(56-parent_scale);var low_shift:int=R._s32(32-high_shift)
			for axis in range(3):body.encode_s64(0x3e+axis*8,R._s64(R._s32(projected[axis]<<(low_shift&31)),projected[axis]>>(high_shift&31)))
		if int(globals.collision_active_u8)!=0:
			globals.collision_flags_u8=int(globals.collision_flags_u8)|0x80
			if int(body[0x86])==int(globals.player_index_u32):
				var old_matrix:PackedInt64Array=R._matrix(body);align(normal)
				var old_velocity:PackedInt64Array=R._velocity(body);var velocity:=old_velocity.duplicate();var normal_speed:int=R._dot(normal,old_velocity)
				for axis in range(3):velocity[axis]=R._s32(R._div(R._s32(old_velocity[axis]*2),3)-R._div(R._s32(R._mul(normal[axis],normal_speed)*10),12));body.encode_s32(0x8c+axis*4,velocity[axis])
				var forward:=PackedInt64Array([old_matrix[6],old_matrix[7],old_matrix[8]]);var projection:=velocity.duplicate()
				if R._dot(velocity,forward)<0:
					for axis in range(3):projection[axis]=R._s32(-projection[axis])
				var lost:int=R._s32(old_l1-R._l1(velocity));var damaged_model:=model(body)
				if damaged_model.is_empty() or str(damaged_model.physical_spec_hex).length()!=48:return fail("source_damage_spec_unavailable")
				var spec:PackedByteArray=str(damaged_model.physical_spec_hex).hex_decode();var hull:int=R._s32(spec.decode_s16(6)<<2);var amount:int=maxi(R._div(R._s32(hull*lost),0x708),R._div(hull,4))
				if boundary("F953",[int(body[0x86]),amount,0]).is_empty():return false
				if projection==PackedInt64Array([0,0,0]):projection=forward
				var final_forward:PackedInt64Array=SourceContactClassifier.Ground._normalize_1503(projection)
				for axis in range(3):old_matrix[6+axis]=final_forward[axis]
				order.append("F1520");R._write_matrix(body,SourceContactClassifier.Ground._orthonormalize(old_matrix))
			elif body.decode_u32(0x82)>13 and int(body[0x87]) in [11,14]:
				align(normal)
				for axis in range(3):body.encode_s32(0x8c+axis*4,0)
				if int(globals.collision_enabled_u8)!=0 and boundary("F953",[int(body[0x86]),-1,0]).is_empty():return false
		else:
			align(normal)
			for axis in range(3):body.encode_s32(0x8c+axis*4,0)
		if collider.decode_u32(0x140)!=collider.decode_u32(0x138):globals.collision_flags_u8=int(globals.collision_flags_u8)|1
		if int(globals.collider_index_u8)==0:globals.collider_index_u8=int(collider[0x86]);globals.collider_ref_u32=int(collider[0x86])
		return true
	func pair()->bool:
		order.append("F578");pair_executed=true
		var initial_body:=body.duplicate();var initial_collider:=collider.duplicate()
		var pair_globals:Dictionary={"collision_flags_u8":int(globals.collision_flags_u8),"collision_enabled_u8":int(globals.collision_enabled_u8)};var trace:Array=[]
		for attempt in range(3):
			var invoked:=SourceContactClassifier.Pair.execute(initial_body,initial_collider,pair_globals,trace)
			if invoked.get("ok",false):
				body=invoked.body_after.duplicate();collider=invoked.collider_after.duplicate()
				for key:String in pair_globals:globals[key]=int(invoked.globals_after[key])
				return true
			if not invoked.get("pending") is Dictionary:return fail("source_pair_response_rejected")
			var pending:Dictionary=invoked.pending
			body=pending.before.body.duplicate();collider=pending.before.collider.duplicate()
			for key:String in pair_globals:globals[key]=int(pending.before.globals[key])
			var target:int=int(body[0x86]) if pending.target=="body" else int(collider[0x86])
			var observed:=boundary("F953",[target,int(pending.args[0]),int(pending.args[1])])
			if observed.is_empty():return false
			var row:Dictionary=pending.duplicate(true)
			row.after={"body":body.duplicate(),"collider":collider.duplicate(),"globals":{"collision_flags_u8":int(globals.collision_flags_u8),"collision_enabled_u8":int(globals.collision_enabled_u8)}}
			trace.append(row)
		return fail("source_pair_boundary_limit")
	func run()->Dictionary:
		var R=SourceContactClassifier.Response
		order.append_array(["F575","F1664"])
		var absolute_vector:=SourceContactClassifier._vector(relative)
		for axis in range(3):
			if absolute_vector[axis]<0:absolute_vector[axis]=R._sub64(0,absolute_vector[axis])
		absolute=SourceContactClassifier._bytes(absolute_vector)
		var total:int=R._add64(R._add64(absolute_vector[0],absolute_vector[1]),absolute_vector[2]);var bound:int=R._sub64(SourceContactClassifier.Ground._shift64(total,-1),body.decode_s64(0x138))
		if bound>>32>=0:
			bound=R._sub64(bound,collider.decode_s64(0x138))
			if bound>>32>=0:return result(0)
		globals.collision_kind_u8=0
		var squared:=0
		if (int(collider[0x14c])&0x80)!=0:
			var observed:=boundary("F576",[int(body[0x86]),int(collider[0x86])])
			if observed.is_empty():return stopped
			if int(observed.return_u32)!=0:return result(int(globals.collision_flags_u8))
			if int(globals.collision_kind_u8)==0:
				if not pair():return stopped
				return result(int(globals.collision_flags_u8))
			if int(globals.collision_kind_u8)!=1:fail("unsupported_uninitialized_F576_distance_operand");return stopped
		else:
			order.append("F577");sphere_executed=true
			var sphere:=SourceContactClassifier.Sphere.classify(body,collider,{"relative_position_s64":SourceContactClassifier._vector(relative),"absolute_position_s64":absolute_vector,"globals":{"collision_flags_u8":int(globals.collision_flags_u8),"altitude_s64":R._s64(int(globals.altitude_low_u32),int(globals.altitude_high_s32))}})
			if not sphere.get("ok",false):fail("source_sphere_rejected");return stopped
			globals.collision_flags_u8=int(sphere.globals_after.collision_flags_u8);globals.altitude_low_u32=int(sphere.globals_after.altitude_s64)&SourceContactClassifier.MASK;globals.altitude_high_s32=R._s32(int(sphere.globals_after.altitude_s64)>>32)
			squared=int(sphere.distance_squared_s32)
			if int(sphere.return_s32)!=0:return result(int(globals.collision_flags_u8))
			if int(body[0x56])!=int(collider[0x86]):
				if not pair():return stopped
				return result(int(globals.collision_flags_u8))
			globals.collision_kind_u8=2
		if not response(squared):return stopped
		return result(int(globals.collision_flags_u8))
