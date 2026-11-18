extends RefCounted
# Original F349/F350/F351/F352 routing and the real ten-record F271 backend.
# Menu selection, audio, formatting and wrapping bodies remain typed providers.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-message-backend-v1"
const BYTE_COUNTS:={"root":16384,"bank":38986,"packet":48,"queue_records":10380,"queue_control":36,"fallback_name":612}
const OPERATIONS:=["F349","F350","F351","F352","F271"]
const MAX_OBSERVATIONS:=16
const MASK:=0xffffffff
static func _s32(v:int)->int:return (v&0x7fffffff)-(v&0x80000000)
static func _keys(v:Variant,k:Array)->bool:return Frame._keys(v,k)
static func _context(v:Variant)->bool:
	if not _keys(v,BYTE_COUNTS.keys()):return false
	for key:String in BYTE_COUNTS:
		if not v[key] is PackedByteArray or v[key].size()!=int(BYTE_COUNTS[key]):return false
	for index in [4,5,6]:
		if v.queue_control.decode_u32(index*4)>9:return false
	return true
static func _same(a:Variant,b:Dictionary)->bool:
	if not _context(a):return false
	for key:String in BYTE_COUNTS:
		if a[key]!=b[key]:return false
	return true
static func _text(value:Variant)->bool:
	if not value is PackedByteArray or value.is_empty() or value.size()>1024 or value[-1]!=0:return false
	for i in range(value.size()-1):
		if value[i]==0:return false
	return true
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"rendering_executed":false}
static func decode_context(value:Variant)->Dictionary:
	if not _keys(value,BYTE_COUNTS.keys()):return {}
	var result:Dictionary=value.duplicate(true)
	for key:String in BYTE_COUNTS:
		if Frame._hex(result[key],int(BYTE_COUNTS[key])):result[key]=str(result[key]).hex_decode()
	return result if _context(result) else {}
static func decode_observations(value:Variant)->Variant:
	if not value is Array or value.size()>MAX_OBSERVATIONS:return null
	var result:Array=value.duplicate(true)
	for row:Variant in result:
		if not _keys(row,["kind","args","before","after","return_u32","input_text_hex","output_text_hex"]):return null
		row.before=decode_context(row.before);row.after=decode_context(row.after)
		if row.before.is_empty() or row.after.is_empty():return null
	return result
static func execute(context:Variant,operation:Variant="F349",observations:Variant=[],display_mode_s32:Variant=1,submitted_text:Variant=null)->Dictionary:
	if not _context(context) or not operation is String or operation not in OPERATIONS or not observations is Array or observations.size()>MAX_OBSERVATIONS or not Frame._whole(display_mode_s32,-0x80000000,0x7fffffff) or (submitted_text!=null and (operation!="F271" or not _text(submitted_text))):return _reject("invalid_message_context")
	var runner:=Messages.new();runner.context=context.duplicate(true);runner.observations=observations.duplicate(true)
	var okay:=true
	match operation:
		"F349":
			runner.order.append("F349")
			if int(runner.context.root[0xe8])!=4:okay=runner.boundary("F217",[],PackedByteArray()).get("ok",false)
			if okay:okay=runner.f351()
		"F351":okay=runner.f351()
		"F350":okay=runner.f350(runner.context.packet.duplicate(),int(display_mode_s32))
		"F352":
			runner.order.append("F352");var local:PackedByteArray=runner.context.packet.duplicate();local.encode_u32(0x18,MASK);okay=runner.f350(local,0)
		"F271":okay=runner.f271(submitted_text.duplicate() if submitted_text!=null else null,0,0)
	if not okay:return runner.stopped
	if runner.used!=observations.size():return _reject("unused_message_observations")
	return {"ok":true,"profile":PROFILE,"context_after":runner.context.duplicate(true),"source_order":runner.order.duplicate(),"requests":runner.requests.duplicate(true),"observations_used":runner.used,"submissions":runner.submissions.duplicate(true),"return_u32":0,"void_return_register_ignored":true,"F271_backend_executed":runner.backend_calls>0,"F1344_body_executed":false,"F1398_body_executed":false,"F217_body_executed":false,"rendering_executed":false,"live_owners_changed":false,"Main_integrated":false}
class Messages:
	var context:Dictionary
	var observations:Array
	var used:=0
	var order:Array=[]
	var requests:Array=[]
	var submissions:Array=[]
	var stopped:Dictionary={}
	var backend_calls:=0
	func host()->GDScript:return load("res://scripts/source_messages.gd")
	func fail(reason:String)->bool:
		stopped=host()._reject(reason);stopped["source_order"]=order.duplicate();stopped["observations_used"]=used;return false
	func boundary(kind:String,args:Array,input:PackedByteArray)->Dictionary:
		order.append(kind)
		var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":context.duplicate(true),"input_text_hex":input.hex_encode()}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return {}
		var row:Variant=observations[used]
		if not host()._keys(row,["kind","args","before","after","return_u32","input_text_hex","output_text_hex"]) or row.kind!=kind or not row.args is Array or row.args.size()!=args.size() or not host()._same(row.before,context) or not host()._context(row.after) or not Frame._whole(row.return_u32,0,MASK) or row.input_text_hex!=input.hex_encode() or not row.output_text_hex is String:
			fail("unmatched_message_observation");return {}
		for i in range(args.size()):
			if not Frame._whole(row.args[i],-0x80000000,MASK) or (int(row.args[i])&MASK)!=(int(args[i])&MASK):fail("unmatched_message_arguments");return {}
		var text:=PackedByteArray()
		if kind in ["F1344","F1398"]:
			if not Frame._hex(row.output_text_hex,row.output_text_hex.length()/2) or row.output_text_hex.length()%2!=0:fail("invalid_message_provider_text");return {}
			text=str(row.output_text_hex).hex_decode()
			if not host()._text(text):fail("unbounded_message_provider_text");return {}
		elif not str(row.output_text_hex).is_empty():fail("unexpected_message_provider_text");return {}
		context=row.after.duplicate(true);requests.append(row.duplicate(true));used+=1;return {"ok":true,"text":text,"return_u32":int(row.return_u32)}
	func f351()->bool:
		order.append("F351")
		if int(context.root[0xe8])==44:return true
		if context.packet.decode_s32(0x18)>=0 and boundary("F1906",[22],PackedByteArray()).is_empty():return false
		return f350(context.packet.duplicate(),1)
	func f350(packet:PackedByteArray,mode:int)->bool:
		order.append("F350")
		var flags:int=packet.decode_s32(0x18);var code:int=packet.decode_u32(0);var params:Array=[packet.decode_u32(4),packet.decode_u32(8),packet.decode_u32(12),packet.decode_u32(0x24),packet.decode_u32(0x2c)];var style:=17 if flags<0 else 95;var parameter_kind:=0
		if flags>=0 and (flags&1)==0:
			var actor:int=packet.decode_u32(0x1c);code=0x9917;params[0]=packet.decode_u32(0);params[3]=packet.decode_u32(0x2c)
			if actor==0:params[4]=0;parameter_kind=2
			else:
				if actor<116 or actor+338>38986 or (actor-116)%338!=0:return fail("unbound_message_actor_reference")
				params[4]=actor+0x124;parameter_kind=1
		var args:Array=[code];args.append_array(params);args.append(parameter_kind)
		var formatted:=boundary("F1344",args,PackedByteArray())
		if formatted.is_empty():return false
		return f271(formatted.text,style,1 if mode==0 else 0)
	func control(index:int)->int:return context.queue_control.decode_s32(index*4)
	func store(index:int,value:int)->void:context.queue_control.encode_u32(index*4,value&MASK)
	func f271(text:Variant,style:int,flags:int)->bool:
		order.append("F271");backend_calls+=1
		if text==null:
			var cursor:=control(6);var at:=cursor*1038
			if (int(context.queue_records.decode_u32(at+1034))&1)!=0:
				var last:=control(5)-1
				if last==-1:last=9
				store(5,last);store(4,(last+1)%10);context.queue_records.encode_u32(at+1034,0);context.queue_records[at+9]=0;store(2,-1)
			return true
		var wrapped:=boundary("F1398",[120],text)
		if wrapped.is_empty():return false
		var lines:=0
		for byte:int in wrapped.text:
			if byte==13:lines+=1
		var cursor:=control(6);var at:=cursor*1038
		for i in range(text.size()):context.queue_records[at+9+i]=text[i]
		context.queue_records.encode_u32(at+1034,flags);context.queue_records[at+8]=style&255
		context.queue_records.encode_u32(at,context.root.decode_u32(4));context.queue_records.encode_u32(at+4,context.root.decode_u32(0))
		store(5,cursor);store(4,(cursor+1)%10)
		if (flags&1)==0:store(6,(cursor+1)%10);store(2,-1)
		else:store(2,lines)
		var height:int=host()._s32((lines<<3)-24);var delta:int=host()._s32(height-control(3));store(0,delta if delta>0 else host()._s32(-delta));store(7,1 if height>=control(3) else -1);store(1,control(8))
		submissions.append({"text_hex":text.hex_encode(),"style_u8":style&255,"flags_u32":flags,"slot_u32":cursor,"wrapped_line_count_u32":lines});return true
