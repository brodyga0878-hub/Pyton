extends RefCounted
# Whole DOS F41 caller. External services remain exact observed boundaries;
# pointer-backed local bytes retain their invocation seed and definedness.
const Safe=preload("res://scripts/source_mission_services.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-mission-statements-v1"
const MASK:=0xffffffff
const VECTORS_SHA:="a59194e05117f7bd46e82b9ca92c5bbf0ebe3952e6cddfbdebbe102332c56ae2"
const CONTEXT_KEYS:=["root","root_tail","bank","program","program_base_u32","ip_u32","task_record","task_slot_u32","vectors","text_buffer","text_cursor_u32"]
const OBSERVATION_KEYS:=["kind","args","before","after","return_u32","input_hex","output_hex","input_defined_hex","output_defined_hex"]
const BYTE_COUNTS:={"root":16384,"root_tail":6160,"bank":38986,"task_record":36,"vectors":324}
const PROVIDERS:={"F31":1,"F37":2,"F52":3,"F331":6,"F342":0,"F326":0,"F38":1,"F101":5,"F102":1,"F103":1,"F97":1,"F98":5,"F99":2,"F100":3,"F104":2,"F105":1,"F772":1,"F39":1,"F953":3,"F349":1,"F345":1,"F346":1,"F360":1,"F1344":3,"F48":3,"F352":1,"F347":1,"F332":2,"F359":0,"F314":11,"F315":1,"F664":5,"F236":3,"F665":2,"F666":2,"F668":2,"F297":5,"F290":5,"F40":9,"F942":2,"F926":2,"F305":3,"F304":3,"F702":2,"F291":2}
const VALUE_PROVIDERS:=["F31","F52","F101","F772","F1344","F314","F664","F665","F666","F668","F297","F40","F926","F291"]
const UI_PROVIDERS:=["F345","F346","F347","F349","F352","F360"]
const MAX_OBSERVATIONS:=256
const MAX_STEPS:=4096
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_world_services_executed":false}
static func _whole(value:Variant,low:int,high:int)->bool:return Frame._whole(value,low,high)
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:Variant in value:
		if not key is String or key not in keys:return false
	return true
static func _mask(value:Variant,count:int)->bool:
	if not Frame._hex(value,count):return false
	for byte:int in str(value).hex_decode():
		if byte>1:return false
	return true
static func _body_reference(value:int)->bool:return value==0 or (value>=116 and (value-116)%338==0 and (value-116)/338<=114)
static func _context(value:Variant)->bool:
	if not Safe._plain(value) or not _keys(value,CONTEXT_KEYS):return false
	for key:String in BYTE_COUNTS:
		if not value[key] is PackedByteArray or value[key].size()!=int(BYTE_COUNTS[key]):return false
	if not value.program is PackedByteArray or value.program.is_empty() or value.program.size()>65536 or not _whole(value.program_base_u32,1,MASK) or int(value.program_base_u32)+value.program.size()>0x100000000 or not _whole(value.ip_u32,0,value.program.size()) or not _whole(value.task_slot_u32,0,149) or not value.text_buffer is PackedByteArray or value.text_buffer.is_empty() or value.text_buffer.size()>65536 or not _whole(value.text_cursor_u32,0,value.text_buffer.size()) or value.root_tail.decode_u32(0x180c)>1:return false
	if not _body_reference(value.root.decode_u32(0xc8)) or not _body_reference(value.root.decode_u32(0xcc)):return false
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(value.vectors)
	return hash.finish().hex_encode()==VECTORS_SHA
static func _copy_context(value:Variant)->Dictionary:
	if not _context(value):return {}
	var result:Dictionary=value.duplicate(true)
	for key:String in ["program_base_u32","ip_u32","task_slot_u32","text_cursor_u32"]:result[key]=int(result[key])
	return result
static func decode_context(value:Variant)->Dictionary:
	if not Safe._plain(value) or not _keys(value,CONTEXT_KEYS):return {}
	var result:Dictionary=value.duplicate(true)
	for key:String in BYTE_COUNTS:
		if result[key] is String and Frame._hex(result[key],int(BYTE_COUNTS[key])):result[key]=str(result[key]).hex_decode()
	for key:String in ["program","text_buffer"]:
		if result[key] is String and result[key].length()%2==0 and result[key].length()<=131072 and Frame._hex(result[key],result[key].length()/2):result[key]=str(result[key]).hex_decode()
	return _copy_context(result)
static func _words(value:Variant,count:int)->bool:
	if not value is Array or value.size()!=count:return false
	for word:Variant in value:
		if not _whole(word,0,MASK):return false
	return true
static func _observation(value:Variant)->bool:
	if not Safe._plain(value) or not _keys(value,OBSERVATION_KEYS) or not value.kind is String or not PROVIDERS.has(value.kind) or not _words(value.args,int(PROVIDERS[value.kind])) or not _context(value.before) or not _context(value.after) or not _whole(value.return_u32,0,MASK) or not value.input_hex is String or not value.output_hex is String or not _mask(value.input_defined_hex,value.input_hex.length()/2) or not _mask(value.output_defined_hex,value.output_hex.length()/2) or value.input_hex.length()%2!=0 or value.output_hex.length()%2!=0 or not Frame._hex(value.input_hex,value.input_hex.length()/2) or not Frame._hex(value.output_hex,value.output_hex.length()/2):return false
	for key:String in ["program","program_base_u32","task_slot_u32","vectors"]:
		if value.before[key]!=value.after[key]:return false
	if value.before.text_buffer.size()!=value.after.text_buffer.size():return false
	if value.kind not in ["F31","F37","F52"] and int(value.before.ip_u32)!=int(value.after.ip_u32):return false
	return value.kind in VALUE_PROVIDERS or int(value.return_u32)==0
static func decode_observations(value:Variant)->Variant:
	if not Safe._plain(value) or not value is Array or value.size()>MAX_OBSERVATIONS:return null
	var result:Array=[]
	for raw:Variant in value:
		if not _keys(raw,OBSERVATION_KEYS):return null
		var row:Dictionary=raw.duplicate(true);row.before=decode_context(row.before);row.after=decode_context(row.after)
		if not _observation(row):return null
		row.return_u32=int(row.return_u32)
		for index in range(row.args.size()):row.args[index]=int(row.args[index])
		result.append(row)
	return result
static func execute(context:Variant,observations:Variant=[],scratch:Variant={})->Dictionary:
	if not _context(context) or not Safe._plain(observations) or not observations is Array or observations.size()>MAX_OBSERVATIONS or not Safe._plain(scratch) or not _keys(scratch,["seed_hex","defined_hex"]) or not Frame._hex(scratch.seed_hex,156) or not _mask(scratch.defined_hex,156):return _reject("invalid_mission_statements_command")
	var decoded:Variant=decode_observations(observations)
	if decoded==null:return _reject("invalid_mission_statements_observations")
	var runner:=Statements.new();runner.context=_copy_context(context);runner.observations=decoded;runner.local_bytes=str(scratch.seed_hex).hex_decode();runner.defined=str(scratch.defined_hex).hex_decode()
	return runner.run()
class Statements:
	var context:Dictionary
	var observations:Array
	var local_bytes:PackedByteArray
	var defined:PackedByteArray
	var used:=0
	var steps:=0
	var order:Array=[]
	var requests:Array=[]
	var opcode_counts:Array=[]
	var stopped:Dictionary={}
	func host()->GDScript:return load("res://scripts/source_mission_statements.gd")
	func fail(reason:String)->bool:
		if stopped.is_empty():stopped=host()._reject(reason);stopped["source_order"]=order.duplicate();stopped["observations_used"]=used;stopped["scratch_after_hex"]=local_bytes.hex_encode();stopped["scratch_defined_hex"]=defined.hex_encode()
		return false
	func span(at:int,count:int)->bool:return true if at>=0 and count>=0 and at+count<=context.program.size() else fail("statement_program_span_out_of_bounds")
	func immediate()->int:
		if not stopped.is_empty() or not span(int(context.ip_u32),4):return 0
		order.append("F20");var value:int=context.program.decode_u32(int(context.ip_u32));context.ip_u32=int(context.ip_u32)+4;return value
	func body(slot:int,captured_mode:int=-1)->int:
		order.append("F1532")
		var offset:=(116+slot*338)&MASK
		if offset<116 or (offset-116)%338!=0 or (offset-116)/338>114:fail("statement_body_index_out_of_bounds");return -1
		if (int(context.root_tail.decode_u32(0x180c)) if captured_mode<0 else captured_mode)==0:fail("null_bank_body_pointer_outside_owned_profile");return -1
		return offset
	func returned_body(reference:int)->int:
		if reference==0:return 0
		if reference<116 or (reference-116)%338!=0 or (reference-116)/338>114:fail("unbound_statement_body_result");return -1
		return reference
	func local_word(at:int,value:int)->void:
		local_bytes.encode_u32(at,value&MASK)
		for index in range(4):defined[at+index]=1
	func args_values(count:int)->Array:
		var result:Array=[]
		for index in range(count):result.append(expression())
		return result
	func boundary(kind:String,args:Array,input:PackedByteArray=PackedByteArray(),mask:PackedByteArray=PackedByteArray(),output_sizes:Array=[0])->Dictionary:
		if not stopped.is_empty():return {}
		order.append(kind)
		var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":host()._copy_context(context),"input_hex":input.hex_encode(),"input_defined_hex":mask.hex_encode(),"output_byte_count_u32":int(output_sizes[-1])}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return {}
		var row:Dictionary=observations[used]
		if row.kind!=kind or row.args.size()!=args.size() or row.before!=context or row.input_hex!=pending.input_hex or row.input_defined_hex!=pending.input_defined_hex:fail("unmatched_statement_observation");return {}
		for index in range(args.size()):
			if int(row.args[index])!=int(args[index]):fail("unmatched_statement_arguments");return {}
		if row.output_hex.length()/2 not in output_sizes:fail("invalid_statement_output_buffer");return {}
		context=host()._copy_context(row.after);used+=1;requests.append(row.duplicate(true))
		return {"ok":true,"return_u32":int(row.return_u32),"output":str(row.output_hex).hex_decode(),"defined":str(row.output_defined_hex).hex_decode()}
	func scalar(kind:String,args:Array)->int:
		var result:=boundary(kind,args);return int(result.return_u32) if result.get("ok",false) else 0
	func expression()->int:return scalar("F31",[int(context.task_slot_u32)])
	func store(value:int)->void:boundary("F37",[int(context.task_slot_u32),value&MASK])
	func packet(kind:String,args:Array=[0],present:bool=true)->void:
		var result:=boundary(kind,args,local_bytes.slice(20,68) if present else PackedByteArray(),defined.slice(20,68) if present else PackedByteArray(),[0,48] if present else [0])
		if result.get("ok",false) and not result.output.is_empty():
			for index in range(48):local_bytes[20+index]=result.output[index];defined[20+index]=result.defined[index]
	func ui(kind:String,count:int,sentinel:int=-1,last_offset:int=-1)->void:
		if sentinel>=0:local_word(44,sentinel)
		for index in range(count):local_word(20+index*4,expression())
		if last_offset>=0:local_word(20+last_offset,expression())
		packet(kind)
	func expand(owner:int,at:int,format:int)->void:
		var result:=boundary("F1344",[owner,at,format],local_bytes.slice(0,20),defined.slice(0,20),[0,20])
		if not result.get("ok",false):return
		if not result.output.is_empty():
			for index in range(20):local_bytes[index]=result.output[index];defined[index]=result.defined[index]
		if owner==0:
			var end:=int(result.return_u32)
			if end<1 or end>context.text_buffer.size()+1:fail("statement_text_cursor_outside_owner");return
			context.text_cursor_u32=end-1
	func pointer_store(kind:String,args:Array)->void:
		var at:=returned_body(scalar(kind,args))
		if at>=0 and stopped.is_empty():store(0 if at==0 else int(context.bank[at+0x86]))
	func day(value:int)->int:order.append("F23");return (int(value/86400)+0x121cf7)&MASK
	func tick(value:int)->int:order.append("F24");return ((value%86400)*0xc22e)&MASK
	func run()->Dictionary:
		order.append("F41");opcode_counts.resize(256);opcode_counts.fill(0);var done:=false
		while not done and stopped.is_empty():
			steps+=1
			if steps>MAX_STEPS:fail("statement_iteration_profile_limit");break
			if not span(int(context.ip_u32),1):break
			var opcode:int=context.program[int(context.ip_u32)];context.ip_u32=int(context.ip_u32)+1;opcode_counts[opcode]=int(opcode_counts[opcode])+1
			match opcode:
				0:done=true
				1:
					var module:=immediate();var value:=scalar("F52",[int(context.task_slot_u32),module,context.task_record.decode_u32(4)]);store(value)
				2:
					if expression()!=0:
						if span(int(context.ip_u32),4):context.ip_u32=int(context.ip_u32)+4
					else:
						var distance:=immediate();var next:=(int(context.ip_u32)+distance-4)&MASK
						if next>context.program.size():fail("statement_relative_jump_outside_program")
						else:context.ip_u32=next
				3:
					var distance:=immediate();var next:=(int(context.ip_u32)+distance-4)&MASK
					if next>context.program.size():fail("statement_relative_jump_outside_program")
					else:context.ip_u32=next
				4:
					var values:=args_values(6);local_word(20,int(values[2]));packet("F331",[values[0],values[1],0 if int(values[2])!=0 else MASK,values[3],values[4],values[5]],int(values[2])!=0)
				5:boundary("F342",[])
				6:boundary("F326",[])
				7:store(expression())
				8:
					var handle:=expression();boundary("F38",[handle]);done=handle==context.task_record.decode_u32(4)
				9:
					var index:=immediate();context.task_record.encode_u32(20,index);var at:=((int(context.task_record.decode_u32(28))+28+index*4)&MASK)-int(context.program_base_u32)
					if span(at,4):context.task_record.encode_u32(16,context.program.decode_u32(at));context.task_record.encode_u32(0,4);done=true
				10:
					var start:=int(context.ip_u32);var at:=start
					while at<context.program.size() and context.program[at]!=0:at+=1
					if at>=context.program.size():fail("unterminated_statement_inline_string")
					else:
						order.append("_strlen");context.ip_u32=at+1;var values:=args_values(4);var text:PackedByteArray=context.program.slice(start,at+1);var known:=PackedByteArray();known.resize(text.size());known.fill(1);var result:=boundary("F101",[int(context.program_base_u32)+start]+values,text,known);store(int(result.get("return_u32",0)))
				11,12,13,18,20,38:
					var names:={11:"F102",12:"F103",13:"F97",18:"F105",20:"F39",38:"F315"};boundary(names[opcode],[expression()])
				14:boundary("F98",args_values(3)+[0,0])
				15:boundary("F99",args_values(2))
				16:boundary("F100",args_values(3))
				17:boundary("F104",args_values(2))
				19:pointer_store("F772",[expression()])
				21:
					var values:=args_values(3);var at:=body(int(values[0]));boundary("F953",[at,values[1],values[2]])
				22:ui("F349",1,0xffffffff)
				23:ui("F345",1)
				24:ui("F346",1)
				25:
					local_word(20,expression());local_word(44,0);packet("F360")
				26,47:
					var slot:=expression();var format:=expression()
					if opcode==47:local_word(0,expression())
					var at:=body(slot)
					if at>=0:expand(1,at+0x124,format);boundary("F48",[18,0,slot])
				27:ui("F345",2)
				28:ui("F349",2,0xffffffff)
				29:ui("F352",1,0xffffffff)
				30:ui("F352",2,0xffffffff)
				31:ui("F352",3,0xffffffff)
				32:ui("F347",1,0xffffffff)
				33:
					var first:=expression();var second:=(expression()*0xc22e)&MASK;boundary("F332",[first,second])
				34:boundary("F359",[])
				35,36,45:
					var format:=expression()
					if opcode in [36,45]:local_word(0,expression())
					if opcode==45:local_word(4,expression())
					expand(0,int(context.text_cursor_u32),format)
				37:
					var input:=PackedByteArray([0,0]);var result:=boundary("F314",[7,0,0,0,0,0,0,0,0,0x49aa16,context.root.decode_u32(0x10a)],input,PackedByteArray([1,1]));store(int(result.get("return_u32",0)))
				39:
					var values:=args_values(4);var days:=day(int(values[3]));var ticks:=tick(int(values[3]));pointer_store("F664",[values[0],values[1],int(values[2])&255,ticks,days])
				40:
					var values:=args_values(2);boundary("F236",[values[0],values[1],context.root.decode_u32(0xcc)])
				41,42,43:
					var names:={41:"F665",42:"F666",43:"F668"};pointer_store(names[opcode],args_values(2))
				44:ui("F346",2)
				46:ui("F347",2,0xffffffff)
				48:pointer_store("F297",args_values(5))
				49:
					var values:=args_values(3);var days:=day(expression());boundary("F290",values+[days,expression()])
				50:pointer_store("F40",args_values(9))
				51:
					var slot:=expression();var value:=expression();var at:=body(slot)
					if at>=0:boundary("F942",[at,value])
				52:
					var model:=expression();var slot:=expression();var at:=body(slot)
					if at>=0:pointer_store("F926",[(model+0x8e00)&MASK,at])
				53:
					var values:=args_values(3)
					if int(values[0]) in [1,2]:
						var result:=boundary("F305" if int(values[0])==1 else "F304",[int(values[1])&255,0,values[2]],local_bytes.slice(152,156),defined.slice(152,156),[0,4])
						if result.get("ok",false) and not result.output.is_empty():
							for index in range(4):local_bytes[152+index]=result.output[index];defined[152+index]=result.defined[index]
				54:
					var mode:int=context.root_tail.decode_u32(0x180c);var at:=body(expression(),mode);var parent:=expression();var third:=expression();boundary("F702",[at,third])
					if at>=0 and stopped.is_empty():
						if parent==0:context.bank[at+0x56]=0
						elif context.root_tail.decode_u32(0x180c)!=0:context.bank[at+0x56]=parent&255
						else:body(parent)
				55:ui("F345",3)
				56:ui("F345",4)
				57:
					var mode:int=context.root_tail.decode_u32(0x180c);var at:=body(expression(),mode)
					if at>=0:
						for offset in [0x8c,0x90,0x94]:context.bank.encode_u32(at+offset,0)
				58:
					var slot:=expression();var item:=(expression()-1000)&MASK;var at:=body(slot)
					if at>=0:
						if item<38:
							if at!=context.root.decode_u32(0xc8) or context.root.decode_u16(0x134+item*2)!=0:at=returned_body(scalar("F291",[at,item]))
							else:at=0
						if at>=0 and stopped.is_empty():store(0 if at==0 else int(context.bank[at+0x86]))
				59:
					for index in range(4):local_word(20+index*4,expression())
					local_word(56,expression());local_word(44,0);packet("F360")
				60:
					var mode:int=context.root_tail.decode_u32(0x180c);var at:=body(expression(),mode)
					if at>=0:
						context.bank[at+0xff]=11;context.bank[at+0x100]=context.bank[at+0xfe];context.bank[at+0xfe]=expression()&255;var index:=expression();var offset:=(index*12)&MASK
						if offset<0 or offset+10>context.vectors.size():fail("statement_vector_table_index_out_of_bounds")
						else:
							for axis in range(3):context.bank.encode_u16(at+0x102+axis*2,context.vectors.decode_u16(offset+axis*4))
		if not stopped.is_empty():return stopped
		if used!=observations.size():fail("unused_statement_observations");return stopped
		if not host()._context(context):fail("invalid_statement_result");return stopped
		return {"ok":true,"profile":PROFILE,"context_after":host()._copy_context(context),"cursor_after_u32":int(context.ip_u32),"opcode_counts_u32":opcode_counts.duplicate(),"dispatch_iterations_u32":steps,"source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"return_u32":0,"return_defined":false,"void_return_register_ignored":true,"scratch_after_hex":local_bytes.hex_encode(),"scratch_defined_hex":defined.hex_encode(),"live_owners_changed":false,"Main_integrated":false,"full_world_services_executed":false}
