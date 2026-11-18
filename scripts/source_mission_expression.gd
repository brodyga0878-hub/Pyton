extends RefCounted
# Original expression procedures and explicitly witnessed world-service calls.
# Persistent references are bank offsets or source resource offsets, never host pointers.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const RNG=preload("res://scripts/source_global_rng.gd")
const PROFILE:="dos-firstenc-mission-expressions-v1"
const MASK:=0xffffffff
const CONTEXT_KEYS:=["root","root_tail","bank","event_registers","module_globals","task_variables","program","ip_u32","module_global_offset_u32","temporary_event_index_s32"]
const BYTE_COUNTS:={"root":16384,"root_tail":6160,"bank":38986,"event_registers":284,"module_globals":40}
const OPERATIONS:=["F20","F21","F22","F23","F24","F25","F26","F27","F28","F29","F30","F31","F462","F463","F1532","F922","F1530"]
const UNDEFINED_SELECTORS:=[0,1,28,29,30,33,38,39,40,41,42,43,44]
const MAX_PROGRAM:=65536
const MAX_DEPTH:=64
const MAX_STEPS:=4096
const MAX_OBSERVATIONS:=64
const MAX_LIST_RECORDS:=60
const PROVIDERS:={"F85":2,"F96":3,"F106":1,"F392":2,"F461":1,"F649":1,"F658":1,"F857":2,"F870":1,"F871":1,"F1476":0,"F909":2,"F48":3}
static func _u32(value:int)->int:return value&MASK
static func _s32(value:int)->int:return (value&0x7fffffff)-(value&0x80000000)
static func _s8(value:int)->int:return (value&127)-(value&128)
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:Variant in value:
		if not (key is String or key is StringName) or str(key) not in keys:return false
	return true
static func _whole(value:Variant,low:int,high:int)->bool:return Frame._whole(value,low,high)
static func _words(value:Variant,count:int)->bool:
	if not value is Array or value.size()!=count:return false
	for word:Variant in value:
		if not _whole(word,0,MASK):return false
	return true
static func _body_reference(value:int)->bool:return value==0 or (value>=116 and value<=116+114*338 and (value-116)%338==0)
static func _context(value:Variant)->bool:
	if not _keys(value,CONTEXT_KEYS):return false
	for key:String in BYTE_COUNTS:
		if not value[key] is PackedByteArray or value[key].size()!=int(BYTE_COUNTS[key]):return false
	if not value.task_variables is PackedByteArray or value.task_variables.size()<8 or value.task_variables.size()>1024 or value.task_variables.size()%4!=0:return false
	if not value.program is PackedByteArray or value.program.is_empty() or value.program.size()>MAX_PROGRAM or not _whole(value.ip_u32,0,value.program.size()) or not _whole(value.module_global_offset_u32,0,MASK) or not _whole(value.temporary_event_index_s32,-0x80000000,0x7fffffff):return false
	var global_offset:=int(value.module_global_offset_u32)
	if global_offset!=MASK and (global_offset>36 or global_offset%4!=0):return false
	return value.root_tail.decode_u32(0x180c)==1 and _body_reference(value.root.decode_u32(0xc8)) and _body_reference(value.root.decode_u32(0xcc))
static func _copy_context(value:Variant)->Dictionary:
	if not _context(value):return {}
	var result:Dictionary=value.duplicate(true)
	for key:String in ["ip_u32","module_global_offset_u32","temporary_event_index_s32"]:result[key]=int(value[key])
	return result
static func _same_context(first:Variant,second:Dictionary)->bool:
	if not _context(first):return false
	for key:String in CONTEXT_KEYS:
		if first[key]!=second[key]:return false
	return true
static func decode_context(value:Variant)->Dictionary:
	if not _keys(value,CONTEXT_KEYS):return {}
	var result:Dictionary={}
	for key:String in BYTE_COUNTS:
		var raw:Variant=value[key]
		if raw is PackedByteArray and raw.size()==int(BYTE_COUNTS[key]):result[key]=raw.duplicate()
		elif Frame._hex(raw,int(BYTE_COUNTS[key])):result[key]=str(raw).hex_decode()
		else:return {}
	for key:String in ["task_variables","program"]:
		var raw:Variant=value[key]
		var low:=8 if key=="task_variables" else 1
		var high:=1024 if key=="task_variables" else MAX_PROGRAM
		if raw is PackedByteArray and raw.size()>=low and raw.size()<=high:result[key]=raw.duplicate()
		elif raw is String and raw.length()>=low*2 and raw.length()<=high*2 and raw.length()%2==0 and Frame._hex(raw,raw.length()/2):result[key]=str(raw).hex_decode()
		else:return {}
	for key:String in ["ip_u32","module_global_offset_u32","temporary_event_index_s32"]:
		if not _whole(value[key],-0x80000000 if key=="temporary_event_index_s32" else 0,0x7fffffff if key=="temporary_event_index_s32" else MASK):return {}
		result[key]=int(value[key])
	return _copy_context(result) if _context(result) else {}
static func _operation(operation:Variant,args:Variant)->bool:
	if not operation is String or operation not in OPERATIONS or not args is Array:return false
	if operation in ["F20","F31","F462","F1530"]:return args.is_empty()
	if operation in ["F21","F23","F24","F30","F463","F922"]:return _words(args,1)
	if operation=="F22":return _words(args,2)
	if operation=="F25":return args.size()==1 and args[0]==30 and _whole(args[0],30,30)
	if operation=="F26":return _words(args,2) and int(args[0])==30
	if operation=="F27":return _words(args,2) and int(args[0]) in [28,29]
	return _words(args,1) and int(args[0])<=114
static func _observation(value:Variant)->bool:
	if not _keys(value,["kind","args","before","after","return_u32","input_hex","output_hex"]) or not value.kind is String or not PROVIDERS.has(value.kind) or not _words(value.args,int(PROVIDERS[value.kind])) or not _context(value.before) or not _context(value.after) or not _whole(value.return_u32,0,MASK) or value.input_hex!="" or not value.output_hex is String:return false
	for key:String in ["program","ip_u32","module_global_offset_u32"]:
		if value.before[key]!=value.after[key]:return false
	if value.before.task_variables.size()!=value.after.task_variables.size():return false
	var count:=4096 if value.kind=="F461" else 308 if value.kind=="F649" and int(value.return_u32)==1 else 2 if value.kind=="F658" else 16 if value.kind=="F870" else 8 if value.kind=="F871" else 0
	if value.kind=="F649" and int(value.return_u32) not in [0,1]:return false
	if value.kind in ["F870","F871","F909","F48"] and int(value.return_u32)!=0:return false
	return value.output_hex=="" if count==0 else Frame._hex(value.output_hex,count)
static func decode_observations(value:Variant)->Variant:
	if not value is Array or value.size()>MAX_OBSERVATIONS:return null
	var result:Array=[]
	for row:Variant in value:
		if not _keys(row,["kind","args","before","after","return_u32","input_hex","output_hex"]) or not row.kind is String or not PROVIDERS.has(row.kind) or not _words(row.args,int(PROVIDERS[row.kind])) or not _whole(row.return_u32,0,MASK) or row.input_hex!="" or not row.output_hex is String:return null
		var copy:Dictionary={"kind":row.kind,"args":[],"before":decode_context(row.before),"after":decode_context(row.after),"return_u32":int(row.return_u32),"input_hex":"","output_hex":row.output_hex}
		for word:Variant in row.args:copy.args.append(int(word))
		if not _observation(copy):return null
		result.append(copy)
	return result
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}
static func execute(context:Variant,operation:Variant="F31",args:Variant=[],observations:Variant=[])->Dictionary:
	if not _context(context) or not _operation(operation,args) or not observations is Array or observations.size()>MAX_OBSERVATIONS:return _reject("invalid_mission_expression_context")
	for row:Variant in observations:
		if not _observation(row):return _reject("invalid_mission_expression_observation")
	var runner:=MissionExpression.new();runner.context=_copy_context(context);runner.observations=observations.duplicate(true)
	return runner.run(operation,args)

class MissionExpression:
	var context:Dictionary
	var observations:Array
	var used:=0
	var steps:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	func host()->GDScript:return load("res://scripts/source_mission_expression.gd")
	func fail(reason:String)->int:
		if stopped.is_empty():stopped=host()._reject(reason);stopped["source_order"]=order.duplicate();stopped["observations_used"]=used
		return 0
	func boundary(kind:String,args:Array)->Dictionary:
		if not stopped.is_empty():return {}
		order.append(kind)
		var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":host()._copy_context(context),"input_hex":""}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return {}
		var row:Variant=observations[used]
		if not host()._observation(row) or row.kind!=kind or not host()._same_context(row.before,context) or row.args.size()!=args.size():fail("unmatched_mission_expression_observation");return {}
		for index in range(args.size()):
			if int(row.args[index])!=int(args[index]):fail("unmatched_mission_expression_arguments");return {}
		context=host()._copy_context(row.after);requests.append(row.duplicate(true));used+=1
		return {"ok":true,"return_u32":int(row.return_u32),"output":str(row.output_hex).hex_decode()}
	func call_scalar(kind:String,args:Array)->int:
		var result:=boundary(kind,args)
		return int(result.return_u32) if result.get("ok",false) else 0
	func read(buffer:PackedByteArray,offset:int,width:int=4,signed:bool=false)->int:
		if not stopped.is_empty():return 0
		if offset<0 or offset+width>buffer.size():return fail("mission_memory_read_out_of_bounds")
		if width==1:return host()._s8(buffer[offset]) if signed else int(buffer[offset])
		if width==2:return buffer.decode_s16(offset) if signed else buffer.decode_u16(offset)
		return buffer.decode_s32(offset) if signed else buffer.decode_u32(offset)
	func immediate()->int:
		if not stopped.is_empty():return 0
		order.append("F20");var at:=int(context.ip_u32)
		var value:=read(context.program,at)
		if stopped.is_empty():context.ip_u32=at+4
		return value
	func body_offset(slot:int,trace:bool=true)->int:
		if trace:order.append("F1532")
		if slot<0 or slot>114:return fail("mission_body_index_out_of_bounds")
		return 116+338*slot
	func body_reference(value:int)->int:
		if value==0 or not host()._body_reference(value):return fail("unbound_mission_body_reference")
		return value
	func body_value(slot:int,offset:int,width:int=4,signed:bool=false)->int:
		var at:=body_offset(slot)
		return read(context.bank,at+offset,width,signed) if stopped.is_empty() else 0
	func player_index()->int:
		var at:=body_reference(context.root.decode_u32(0xc8))
		return read(context.bank,at+0x86,1) if stopped.is_empty() else 0
	func global_value(selector:int)->int:
		order.append("F21")
		if selector==0:return player_index()
		if selector==13:
			var at:=body_reference(context.root.decode_u32(0xcc));return read(context.bank,at+0x86,1) if stopped.is_empty() else 0
		if selector in [5,6,7,8,9,10,11]:return (int(context.root.decode_u32(0)/0xc22e)+(context.root.decode_u32(4)-0x121cf7)*86400)&MASK
		if selector==12:return host()._s8(context.root[0xec])
		if selector==14:return host()._s8(context.root[0xe8])
		var offsets:Dictionary={1:0x19c,2:0x114,3:0x1f0,4:0x10a,15:0x11c,16:0x124,17:0x1f4,18:0x1f8,19:0x1fc,20:0x200}
		return context.root.decode_u32(int(offsets[selector])) if offsets.has(selector) else 0
	func set_global(selector:int,value:int)->int:
		order.append("F22")
		if selector==1:context.root.encode_u32(0x19c,clampi(host()._s32(value),0,0x0fffffff))
		elif selector==4:
			if boundary("F909",[value,0]).is_empty():return 0
		elif selector==12:context.root[0xec]=value&255
		else:
			var offsets:Dictionary={2:0x114,3:0x1f0,15:0x124,17:0x1f4,18:0x1f8,19:0x1fc,20:0x200}
			if offsets.has(selector):context.root.encode_u32(int(offsets[selector]),value)
		boundary("F48",[1,0,selector]);return 0
	func rng(operation:String,bound:int=0)->int:
		if not stopped.is_empty():return 0
		order.append(operation)
		var result:=RNG.execute(context.root,operation,bound if operation=="F922" else null)
		if not result.get("ok",false):return fail("invalid_mission_rng_transition")
		context.root=result.root_after;return int(result.return_u32)
	func day_value(value:int)->int:
		order.append("F23");return (int(value/86400)+0x121cf7)&MASK
	func tick_value(value:int)->int:
		order.append("F24");return ((value%86400)*0xc22e)&MASK
	func predicate(buffer:PackedByteArray,offset:int,kind:int)->int:
		if not stopped.is_empty():return 0
		order.append("F%d"%kind)
		if kind==28:return 1 if (read(buffer,offset+0x14c,1)&0x10)!=0 else 0
		if kind==29:
			var model:=read(buffer,offset+0x82);return 1 if model>=0x76 and model<=0x85 else 0
		var model:=read(buffer,offset+0xc,2);return 1 if model>=0x76 and model<=0x85 else 0
	func list_sum(buffer:PackedByteArray,kind:int)->int:
		order.append("F25");var total:=0
		for index in range(MAX_LIST_RECORDS+1):
			var offset:=index*68;var marker:=read(buffer,offset)
			if not stopped.is_empty():return 0
			if marker==0:return total
			if index==MAX_LIST_RECORDS:return fail("unterminated_mission_list")
			total=(total+predicate(buffer,offset,kind))&MASK
			if not stopped.is_empty():return 0
		return fail("unterminated_mission_list")
	func list_nth_value(buffer:PackedByteArray,kind:int,ordinal:int)->int:
		order.append("F26")
		for index in range(MAX_LIST_RECORDS+1):
			var offset:=index*68;var marker:=read(buffer,offset)
			if not stopped.is_empty():return 0
			if marker==0:return read(buffer,offset+4)
			if index==MAX_LIST_RECORDS:return fail("unterminated_mission_list")
			if predicate(buffer,offset,kind)!=0:
				var before:=ordinal;ordinal=(ordinal-1)&MASK
				if before==0:return read(buffer,offset+4)
			if not stopped.is_empty():return 0
		return fail("unterminated_mission_list")
	func list_count_qualified(buffer:PackedByteArray)->int:
		order.append("F462");var count:=0
		for index in range(MAX_LIST_RECORDS+1):
			var offset:=index*68;var marker:=read(buffer,offset)
			if not stopped.is_empty():return 0
			if marker==0:return count
			if index==MAX_LIST_RECORDS:return fail("unterminated_mission_list")
			if read(buffer,offset+0xa,2)>=0x20:count+=1
		return fail("unterminated_mission_list")
	func list_qualified_offset(buffer:PackedByteArray,ordinal:int)->int:
		order.append("F463")
		for index in range(MAX_LIST_RECORDS+1):
			var offset:=index*68;var marker:=read(buffer,offset)
			if not stopped.is_empty():return -1
			if marker==0:return -1
			if index==MAX_LIST_RECORDS:fail("unterminated_mission_list");return -1
			if read(buffer,offset+0xa,2)>=0x20:
				var before:=ordinal;ordinal=(ordinal-1)&MASK
				if before==0:return offset
		return -1
	func bank_find(kind:int,serial:int)->int:
		order.append("F27")
		for slot in range(114,0,-1):
			if context.bank[slot]==0:continue
			var at:=116+slot*338
			if predicate(context.bank,at,kind)!=0 and context.bank.decode_u32(at+0xa0)==serial:return slot
		return 0
	func expression(depth:int=0)->int:
		if not stopped.is_empty():return 0
		order.append("F31");steps+=1
		if depth>=MAX_DEPTH or steps>MAX_STEPS:return fail("mission_expression_budget_exceeded")
		var opcode:=read(context.program,int(context.ip_u32),1)
		if not stopped.is_empty():return 0
		context.ip_u32=int(context.ip_u32)+1
		if opcode>67 or opcode in UNDEFINED_SELECTORS:return fail("undefined_source_expression_result")
		if opcode==2:return immediate()
		if opcode==3:
			var selector:=immediate();return global_value(selector) if stopped.is_empty() else 0
		if opcode in [4,5,6]:
			var index:=immediate()
			if not stopped.is_empty():return 0
			if opcode==4:
				if index>=71:return fail("event_register_index_out_of_bounds")
				return context.event_registers.decode_u32(index*4)
			if opcode==5:
				var base:=int(context.module_global_offset_u32)
				if base==MASK or index>=10 or base+index*4+4>40:return fail("module_global_index_out_of_bounds")
				return context.module_globals.decode_u32(base+index*4)
			if index>=context.task_variables.size()/4:return fail("task_variable_index_out_of_bounds")
			return context.task_variables.decode_u32(index*4)
		if opcode==50:
			var value:=call_scalar("F1476",[])
			var divisor:=expression(depth+1)
			if not stopped.is_empty():return 0
			if divisor==0:return fail("source_unsigned_division_fault")
			return value%divisor
		var first:=expression(depth+1)
		if not stopped.is_empty():return 0
		match opcode:
			7:return (-first)&MASK
			8:return (~first)&MASK
			9:return 1 if first==0 else 0
			31:return read(context.root_tail,0x10e0+first*4) if first<6 else 0
			34:return context.root.decode_u32(0x1a4) if first==1 else context.root.decode_u32(0x1a0) if first==2 else 0
			35:return read(context.root_tail,0x10f8+first*4) if first<6 else 0
			36,61:return body_value(first,0x82)
			45:return call_scalar("F106",[first])
			47:return (((first&0x1fff)<<16)|((first>>13)&0x1fff))&MASK
			48:return context.root.decode_u32(0x184+first*4) if first<6 else 0
			49:
				# Of six output arguments, the fourth points at the result;
				# the other five alias the one scratch DWORD.
				var result:=boundary("F871",[first]);return result.output.decode_u32(4) if not result.is_empty() else 0
			51:return bank_find(28,first)
			52:return 1 if first==(int(context.temporary_event_index_s32)&MASK) else 0
			53:return call_scalar("F658",[first])
			54:return day_value(first)
			55:return tick_value(first)
			56:return body_value(first,0xa0)
			57:
				var random:=rng("F922",3);return call_scalar("F857",[first,random]) if stopped.is_empty() else 0
			58:
				var result:=boundary("F461",[first])
				if result.is_empty() or int(result.return_u32)!=0:return 0
				var list:PackedByteArray=result.output;var count:=list_count_qualified(list)
				if not stopped.is_empty() or count==0:return 0
				var ordinal:=rng("F922",count);var offset:=list_qualified_offset(list,ordinal)
				return read(list,offset+4) if offset>=0 and stopped.is_empty() else 0
			60:return bank_find(29,first)
			62:return body_value(first,0xff,1)
			63:
				var result:=boundary("F461",[first])
				if result.is_empty() or int(result.return_u32)!=0:return 0
				var list:PackedByteArray=result.output;var count:=list_sum(list,30)
				if not stopped.is_empty() or count==0:return 0
				var ordinal:=rng("F922",count);return list_nth_value(list,30,ordinal) if stopped.is_empty() else 0
			64:return body_value(first,0x88,1,true)&MASK
			65:return body_value(first,0xfe,1)
			67:
				var result:=boundary("F870",[first]);return result.output.decode_u32(4) if not result.is_empty() else 0
		var second:=expression(depth+1)
		if not stopped.is_empty():return 0
		match opcode:
			10:return (host()._s32(first)*host()._s32(second))&MASK
			11,12:
				var a:int=host()._s32(first);var b:int=host()._s32(second)
				if b==0 or (a==-0x80000000 and b==-1):return fail("source_signed_division_fault")
				var quotient:=int(a/b);return quotient&MASK if opcode==11 else (a-quotient*b)&MASK
			13:return (first+second)&MASK
			14:return (first-second)&MASK
			15:return (first<<(second&31))&MASK
			16:return (host()._s32(first)>>(second&31))&MASK
			17:return 1 if host()._s32(first)<host()._s32(second) else 0
			18:return 1 if host()._s32(first)<=host()._s32(second) else 0
			19:return 1 if host()._s32(first)>host()._s32(second) else 0
			20:return 1 if host()._s32(first)>=host()._s32(second) else 0
			21:return 1 if first==second else 0
			22:return 1 if first!=second else 0
			23:return first&second
			24:return first^second
			25:return first|second
			26:return 1 if first!=0 and second!=0 else 0
			27:return 1 if first!=0 or second!=0 else 0
			32:return call_scalar("F85",[first,second])
			37:
				if host()._s32(second)<1000:
					var at:=body_offset(first)
					return call_scalar("F392",[at,(second-100)&MASK]) if stopped.is_empty() else 0
				var index:=second-1000;var player:=player_index()
				return context.root.decode_u16(0x134+index*2) if stopped.is_empty() and first==player and index<38 else 0
			66:
				var index:int=host()._s32((second-1000)&MASK);var result:=boundary("F649",[first])
				return result.output.decode_u32(index*8+4) if not result.is_empty() and int(result.return_u32)!=0 and index>=0 and index<38 else 0
		var third:=expression(depth+1)
		if not stopped.is_empty():return 0
		if opcode==46:return call_scalar("F96",[first,second,third])
		if opcode==59:return ((first+0x1718)|((second+0x1524)<<13)|(third<<26))&MASK
		return fail("unsupported_mission_expression_selector")
	func run(operation:String,args:Array)->Dictionary:
		var value:=0;var pointer:=false;var pointer_kind:="";var defined:=true
		match operation:
			"F20":value=immediate()
			"F21":value=global_value(int(args[0]))
			"F22":value=set_global(int(args[0]),int(args[1]));defined=false
			"F23":value=day_value(int(args[0]))
			"F24":value=tick_value(int(args[0]))
			"F25":value=list_sum(context.program,30)
			"F26":value=list_nth_value(context.program,30,int(args[1]))
			"F27":value=bank_find(int(args[0]),int(args[1]))
			"F28","F29":value=predicate(context.bank,body_offset(int(args[0]),false),int(operation.trim_prefix("F")))
			"F30":value=predicate(context.program,int(args[0]),30)
			"F31":value=expression()
			"F462":value=list_count_qualified(context.program)
			"F463":
				var offset:=list_qualified_offset(context.program,int(args[0]));value=offset+1 if offset>=0 else 0;pointer=true;defined=false;pointer_kind="logical_list_record_offset_plus_one"
			"F1532":value=body_offset(int(args[0]));pointer=true;defined=false;pointer_kind="logical_bank_offset"
			"F922","F1530":value=rng(operation,int(args[0]) if not args.is_empty() else 0)
		if not stopped.is_empty():return stopped
		if used!=observations.size():return host()._reject("unused_mission_expression_observations")
		return {"ok":true,"profile":PROFILE,"context_after":host()._copy_context(context),"return_u32":value&MASK,"return_s32":host()._s32(value),"return_defined":defined,"scalar_return_defined":defined,"pointer_return_defined":pointer,"pointer_result_kind":pointer_kind,"void_return_register_ignored":operation=="F22","source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"expression_nodes_executed":steps,"live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}
