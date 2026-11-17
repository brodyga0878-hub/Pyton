extends RefCounted
class_name SourceCollisionProgram
# Original DOS F582 decisions with real F583/F580. A supplied raw terrain
# state enables actual F581; the default retains matched old continuations.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Planes=preload("res://scripts/source_collision_planes.gd")
const Transform=preload("res://scripts/source_collision_transform.gd")
const Terrain=preload("res://scripts/source_collision_terrain.gd")
const PROFILE:="dos-firstenc-f582-collision-program-v1"
const BODY_BYTES:=338
const MAX_DEPTH:=32
const MAX_STEPS:=65536
const CONTEXT_KEYS:=["point_xyz_s32","normals","vertices","mesh_zoom_s32","vector_scale_s32"]
const ORIGIN_KEYS:=["normal_origin_u32","vertex_origin_u32"]
const MASK:=0xffffffff
static func _whole(value:Variant,low:int,high:int)->bool:return Frame._whole(value,low,high)
static func _keys(value:Variant,required:Array,optional:Array=[])->bool:
	if not value is Dictionary:return false
	for key:String in required:
		if not value.has(key):return false
	for key:Variant in value:
		if not (key is String or key is StringName) or str(key) not in required+optional:return false
	return true
static func _context(value:Variant)->bool:
	if not _keys(value,CONTEXT_KEYS,ORIGIN_KEYS) or not value.point_xyz_s32 is Array and not value.point_xyz_s32 is PackedInt64Array or value.point_xyz_s32.size()!=3 or not value.normals is PackedByteArray or not value.vertices is PackedByteArray:return false
	for cell:Variant in value.point_xyz_s32:
		if not _whole(cell,-0x80000000,0x7fffffff):return false
	for key:String in ["mesh_zoom_s32","vector_scale_s32"]:
		if not _whole(value[key],-0x80000000,0x7fffffff):return false
	for key:String in ORIGIN_KEYS:
		if value.has(key) and not _whole(value[key],0,value.normals.size() if key=="normal_origin_u32" else value.vertices.size()):return false
	return true
static func _copy_context(value:Dictionary)->Dictionary:
	return {"point_xyz_s32":[int(value.point_xyz_s32[0]),int(value.point_xyz_s32[1]),int(value.point_xyz_s32[2])],"normals":value.normals.duplicate(),"vertices":value.vertices.duplicate(),"mesh_zoom_s32":int(value.mesh_zoom_s32),"vector_scale_s32":int(value.vector_scale_s32),"normal_origin_u32":int(value.get("normal_origin_u32",0)),"vertex_origin_u32":int(value.get("vertex_origin_u32",0))}
static func _copy_globals(value:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in Frame.GLOBAL_KEYS:result[key]=int(value[key])
	return result
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"F581_body_executed":false,"full_collision_programs_executed":false}
static func _same_context(first:Variant,second:Dictionary)->bool:
	if not _context(first):return false
	var a:=_copy_context(first);var b:=_copy_context(second)
	return a==b
static func skip_terrain_features(program:Variant,offset_u32:Variant=0)->Dictionary:
	if not program is PackedByteArray or not _whole(offset_u32,0,program.size()):return _reject("invalid_terrain_feature_context")
	var at:=int(offset_u32)
	while at+2<=program.size():
		if program.decode_s16(at)==0:return {"ok":true,"next_offset_u32":at+2,"source_order":["F1822"],"live_owners_changed":false}
		at+=16
	return _reject("unterminated_terrain_feature_records")
static func execute(body:Variant,program:Variant,context:Variant,threshold_s32:Variant,globals:Variant,observations:Variant=[],resources:Variant={},primitive_u8_before:Variant=0,terrain_state:Variant=null)->Dictionary:
	if not body is PackedByteArray or body.size()!=BODY_BYTES or not program is PackedByteArray or program.is_empty() or not _context(context) or not _whole(threshold_s32,-0x80000000,0x7fffffff) or not Frame._globals(globals) or not observations is Array or observations.size()>1024 or not resources is Dictionary or not _whole(primitive_u8_before,0,255):return _reject("invalid_collision_program_context")
	if terrain_state!=null and (not Terrain._terrain_state(terrain_state) or not observations.is_empty()):return _reject("invalid_actual_terrain_context_or_observations")
	var runner:=Program.new();runner.body=body.duplicate();runner.globals=_copy_globals(globals);runner.observations=observations.duplicate(true);runner.resources=resources.duplicate(true)
	if terrain_state!=null:runner.terrain_state=Terrain._copy_terrain(terrain_state)
	var result:=runner.run(program.duplicate(),_copy_context(context),int(threshold_s32),int(primitive_u8_before),0)
	if not result.get("ok",false):return runner.stopped
	if runner.used!=observations.size():return _reject("unused_collision_program_observations")
	result.profile=PROFILE;result.body_after=runner.body.duplicate();result.globals_after=runner.globals.duplicate(true);result.source_order=runner.order.duplicate();result.requests=runner.requests.duplicate(true);result.observations_used=runner.used;result.live_owners_changed=false;result.F582_body_executed=true;result.F581_body_executed=false;result.full_collision_programs_executed=false
	if terrain_state!=null:
		result["terrain_state_after"]=runner.terrain_state.duplicate(true);result["terrain_calls"]=runner.terrain_calls.duplicate(true);result["actual_terrain_route"]=true;result.F581_body_executed=not runner.terrain_calls.is_empty()
	return result

class Program:
	var body:PackedByteArray
	var globals:Dictionary
	var observations:Array
	var resources:Dictionary
	var used:=0
	var steps:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	var terrain_state:Variant=null
	var terrain_calls:Array=[]
	func fail(reason:String)->Dictionary:
		stopped=SourceCollisionProgram._reject(reason);stopped.source_order=order.duplicate();stopped.observations_used=used;return stopped
	func read_byte(program:PackedByteArray,at:int)->int:
		if at<0 or at>=program.size():fail("collision_program_out_of_bounds");return -1
		return int(program[at])
	func skip_list(program:PackedByteArray,at:int)->int:
		while at<program.size():
			var value:=read_byte(program,at);at+=1
			if value==0:return at
		fail("unterminated_collision_plane_list");return -1
	func terrain_end(program:PackedByteArray,at:int)->int:
		# Actual F1822: step16 while signed16 feature word is nonzero,
		# then advance by2. It is not a scan to an arbitrary zero byte.
		order.append("F1822")
		var result:=SourceCollisionProgram.skip_terrain_features(program,at)
		if result.get("ok",false):return int(result.next_offset_u32)
		fail(str(result.reason));return -1
	func plane(context:Dictionary,index:int,threshold:int)->int:
		order.append("F583")
		var result:=SourceCollisionProgram.Planes.execute(context,index,threshold)
		if not result.get("ok",false):fail("plane_"+str(result.get("reason","rejected")));return -1
		return int(result.get("return_s32",result.get("value_s32",result.get("value_u32",-1))))
	func boundary(program:PackedByteArray,context:Dictionary,threshold:int,at:int,depth:int)->Dictionary:
		order.append("F581")
		var before:Dictionary={"body":body.duplicate(),"program":program.duplicate(),"context":context.duplicate(true),"globals":globals.duplicate(true)}
		if terrain_state!=null:
			var actual:=SourceCollisionProgram.Terrain.execute(body,program,at,context,threshold,globals,terrain_state)
			if not actual.get("ok",false):return fail("terrain_"+str(actual.get("reason","rejected")))
			globals=SourceCollisionProgram._copy_globals(actual.globals_after);terrain_state=SourceCollisionProgram.Terrain._copy_terrain(actual.terrain_state_after)
			terrain_calls.append(actual.duplicate(true))
			for entry:String in actual.source_order:
				if entry!="F581":order.append(entry)
			return {"ok":true,"hit_s32":int(actual.hit_s32),"next":int(actual.next_offset_u32)}
		var request:Dictionary={"kind":"F581","args":[at,threshold],"depth_u32":depth,"before":before}
		if used>=observations.size():
			fail("boundary_required");stopped.pending=request;return {}
		var row:Variant=observations[used]
		if not SourceCollisionProgram._keys(row,["kind","args","before","after","return_s32","next_offset_u32"],["depth_u32"]) or row.kind!="F581" or not row.args is Array or row.args.size()!=2 or not SourceCollisionProgram._whole(row.args[0],0,program.size()) or int(row.args[0])!=at or not SourceCollisionProgram._whole(row.args[1],-0x80000000,0x7fffffff) or int(row.args[1])!=threshold:return fail("unmatched_terrain_request")
		if row.has("depth_u32") and (not SourceCollisionProgram._whole(row.depth_u32,0,SourceCollisionProgram.MAX_DEPTH) or int(row.depth_u32)!=depth):return fail("unmatched_terrain_recursion_depth")
		if not SourceCollisionProgram._keys(row.before,["body","program","context","globals"]) or not SourceCollisionProgram._keys(row.after,["body","program","context","globals"]) or row.before.body!=body or row.before.program!=program or not SourceCollisionProgram._same_context(row.before.context,context) or not SourceCollisionProgram.Frame._globals(row.before.globals):return fail("unmatched_terrain_before_context")
		for key:String in SourceCollisionProgram.Frame.GLOBAL_KEYS:
			if int(row.before.globals[key])!=int(globals[key]):return fail("unmatched_terrain_before_globals")
		if row.after.body!=body or row.after.program!=program or not SourceCollisionProgram._same_context(row.after.context,context) or not SourceCollisionProgram.Frame._globals(row.after.globals) or not SourceCollisionProgram._whole(row.return_s32,-0x80000000,0x7fffffff) or not SourceCollisionProgram._whole(row.next_offset_u32,at,program.size()):return fail("invalid_terrain_continuation")
		globals=SourceCollisionProgram._copy_globals(row.after.globals);used+=1;requests.append(row.duplicate(true))
		return {"ok":true,"hit_s32":int(row.return_s32),"next":int(row.next_offset_u32)}
	func nested(context:Dictionary,threshold:int,model_index:int,vertex:int,orientation:int,depth:int)->Dictionary:
		var resource:Variant=resources.get(model_index,resources.get(str(model_index)))
		if not resource is Dictionary:return fail("nested_collision_model_unavailable")
		var transformed:=SourceCollisionProgram.Transform.prepare_nested(context,resource,vertex,orientation,threshold)
		if not transformed.get("ok",false):return fail("nested_"+str(transformed.get("reason","rejected")))
		order.append_array(transformed.get("source_order",["F580","F1538"]))
		return run(transformed.program,transformed.context_after,int(transformed.threshold_s32),0,depth+1)
	func returned(value:int,primitive:int,cursor:int)->Dictionary:
		return {"ok":true,"return_s8":value,"primitive_u8":primitive&255,"primitive_written":true,"stream_cursor_u32":cursor}
	func run(program:PackedByteArray,context:Dictionary,threshold:int,primitive:int,depth:int)->Dictionary:
		if depth>SourceCollisionProgram.MAX_DEPTH:return fail("collision_program_recursion_limit")
		order.append("F582")
		var at:=0;var opcode:=read_byte(program,at);at+=1
		if opcode<0:return stopped
		while opcode!=0:
			steps+=1
			if steps>SourceCollisionProgram.MAX_STEPS:return fail("collision_program_step_limit")
			var volume:=read_byte(program,at);at+=1
			if volume<0:return stopped
			var skip:=false
			if (opcode&0x20)!=0:
				var equipment:=read_byte(program,at);var bit:=read_byte(program,at+1);at+=2
				if equipment<0 or bit<0:return stopped
				var offset:=0x9c+equipment*2
				if offset+2>body.size():return fail("equipment_index_outside_subject")
				var word:int=body.decode_u16(offset);var invert:=0xffffffff if bit>=128 else 0
				skip=((((word>>(bit&31))^invert)&1)!=0)
			var kind:=opcode&0xc0
			if skip:
				if kind==0:
					var first:=read_byte(program,at);at+=1
					if first<0:return stopped
					if first==255:at=terrain_end(program,at+6)
					elif first!=0:at=skip_list(program,at)
				elif kind==0x80:at+=4
				else:at=skip_list(program,at)
				if at<0:return stopped
			elif kind==0:
				var first:=read_byte(program,at);at+=1
				if first<0:return stopped
				if first==255:
					var terrain:=boundary(program,context,threshold,at,depth)
					if not terrain.get("ok",false):return stopped
					at=int(terrain.next)
					if int(terrain.hit_s32)==0:
						globals.volume_flags_u8=int(globals.volume_flags_u8)|volume
						return returned(0,opcode,at)
					globals.volume_flags_u8=int(globals.volume_flags_u8)|(volume&127)
				elif first!=0:
					while true:
						var value:=plane(context,first,threshold)
						if value<0:return stopped
						if value!=0:
							globals.volume_flags_u8=int(globals.volume_flags_u8)|(volume&127)
							return returned(-1,opcode,at)
						first=read_byte(program,at);at+=1
						if first<0:return stopped
						if first==0:break
			elif kind==0x40:
				while true:
					var index:=read_byte(program,at);at+=1
					if index<0:return stopped
					if index==0:
						globals.volume_flags_u8=int(globals.volume_flags_u8)|(volume&127)
						return returned(-1,opcode,at)
					var value:=plane(context,index,threshold)
					if value<0:return stopped
					if value==0:
						at=skip_list(program,at)
						if at<0:return stopped
						break
			elif kind==0x80:
				if at+4>program.size():return fail("truncated_nested_model_record")
				var model_index:=(int(program[at])<<8)|int(program[at+1]);var orientation:=int(program[at+2]);var vertex:=int(program[at+3]);at+=4
				var child:=nested(context,threshold,model_index,vertex,orientation,depth)
				if not child.get("ok",false):return stopped
				primitive=int(child.primitive_u8);globals.primitive_flags_u8=int(globals.primitive_flags_u8)|primitive
				if int(child.return_s8)<0:
					globals.volume_flags_u8=int(globals.volume_flags_u8)|(volume&127)
					return returned(-1,opcode,at)
				if int(child.return_s8)==0:
					globals.volume_flags_u8=int(globals.volume_flags_u8)|volume
					if (volume&128)!=0:return returned(0,opcode,at)
			else:
				while true:
					var index:=read_byte(program,at);at+=1
					if index<0:return stopped
					if index==0:
						globals.volume_flags_u8=int(globals.volume_flags_u8)|volume
						if (volume&128)!=0:return returned(0,opcode,at)
					var value:=plane(context,index,threshold)
					if value<0:return stopped
					if value!=0:
						# Original JUMP2529 loads BL until the terminator; that
						# clobber must not become an opcode reused afterwards.
						at=skip_list(program,at)
						if at<0:return stopped
						opcode=0;break
			opcode=read_byte(program,at);at+=1
			if opcode<0:return stopped
		return returned(1,0,at)
