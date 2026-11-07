extends RefCounted
# Bounded source F1343/F1348 information-text consumer. Original bytes stay
# separate from Unicode localisation and from semantic (non-pixel) UI layout.
const DATA_PATH:="res://data/ffe_system_information.json"
const RU_PATH:="res://data/system_information_ru.json"
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const MAX_DEPTH:=24
const MAX_STEPS:=4096
const MAX_OUTPUT:=16384
static var _data:Dictionary={}
static var _ru:Dictionary={}
static var _mutex:=Mutex.new()

static func _integer(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _hex(value:Variant)->bool:
	if not value is String or value.length()%2!=0:return false
	for character:String in value:
		if not character in "0123456789abcdefABCDEF":return false
	return true
static func _load()->bool:
	_mutex.lock()
	if not _data.is_empty():_mutex.unlock();return true
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	var translated:Variant=JSON.parse_string(FileAccess.get_file_as_string(RU_PATH)) if FileAccess.file_exists(RU_PATH) else null
	if not parsed is Dictionary or parsed.get("schema")!=1 or parsed.get("source_sha256")!=SOURCE_SHA or not parsed.get("strings") is Dictionary or not parsed.get("ff_code_to_label") is Dictionary:
		_mutex.unlock();return false
	if not translated is Dictionary or translated.get("schema")!=1 or translated.get("language")!="ru" or not translated.get("strings") is Dictionary:
		_mutex.unlock();return false
	_data=parsed;_ru=translated;_mutex.unlock();return true
static func source_resource()->Dictionary:return _data.duplicate(true) if _load() else {}
static func ui(key:String,language:="ru")->String:
	if not _load():return ""
	if language=="ru":return str(_ru.get("ui",{}).get(key,""))
	var english:={"general":"System information","demography":"Demography","trade":"Trade","body":"Object information","major_imports":"Major Imports","minor_imports":"Minor Imports","major_exports":"Major Exports","minor_exports":"Minor Exports","illegal_goods":"Illegal Goods","unknown":"Unexplored system","unsupported":"Some original fields are not supported yet.","parent":"Parent","ground_port":"Surface starport","no_entries":"None"}
	return str(english.get(key,""))

static func _issue(state:Dictionary,code:int,message:="")->void:
	if not state.unsupported_codes.has(code):state.unsupported_codes.append(code)
	if not message.is_empty() and not state.errors.has(message):state.errors.append(message)
static func _s32(value:int)->int:
	var word:=value&0xffffffff
	return word-0x100000000 if word>=0x80000000 else word
static func _bytes_to_string(bytes:PackedByteArray)->String:
	var result:=""
	for value:int in bytes:
		# Godot String rejects NUL. A private supplementary scalar carries zero
		# through FF/FD/FE operands; normal byte0 still terminates in the parser.
		result+=String.chr(value if value!=0 else 0x10000)
	return result
static func _string_bytes(value:String,language:String)->PackedByteArray:
	if language=="ru":
		var utf8:=value.to_utf8_buffer();utf8.append(0);return utf8
	var raw:=PackedByteArray()
	for index in range(value.length()):raw.append(value.unicode_at(index)&255)
	raw.append(0);return raw

@warning_ignore("integer_division")
static func _source_integer(value:int)->String:
	# F1544/F1545 signed32 NEG and IDIV. Preserve INT_MIN's original wrapped
	# remainder characters rather than silently applying a modern abs formatter.
	var number:=_s32(value);var negative:=number<0
	if negative:number=_s32(-number)
	var digits:=""
	for _index in range(16):
		var quotient:int=number/10;var remainder:=number-quotient*10
		digits=String.chr(48+remainder)+digits;number=quotient
		if number==0:break
	return ("-" if negative else "")+digits
static func _source_fraction(value:int,places:int)->String:
	# F1377 pads/counts the signed text, then inserts '.', including its source
	# negative-number quirks. No rounding or locale-specific decimal conversion.
	var text:=_source_integer(value)
	if places>=text.length():text="0".repeat(places+1-text.length())+text
	return text.substr(0,text.length()-places)+"."+text.substr(text.length()-places)
static func _variable(state:Dictionary,index:int,code:int)->Variant:
	if index<0 or index>=state.variables.size():_issue(state,code,"Missing original text variable");return null
	return state.variables[index]

static func _brackets(text:String,state:Dictionary)->String:
	var result:="";var at:=0
	while at<text.length():
		var character:=text.substr(at,1);at+=1
		if character==String.chr(0xd5):result+="'";continue
		if character!="[":result+=character;continue
		if at+1>=text.length():_issue(state,0x100005b,"Truncated original bracket command");result+="[";continue
		var command:=text.substr(at,2);at+=2
		# F76 compares these exact case-sensitive commands. Its default consumes
		# any other two bytes, preserving '[' (Kr[ger and M[nich do use it).
		if command in ["Gr","Mi","Ca","Fm","Ff","Cr","Co","Dr","Nu","Ri","Rf","Re","Sh","Si","Sl","Oo","Pn","Zz","Sy","Ci","Pl","Sc","Cs","Sr"]:
			_issue(state,0x1000000|(command.unicode_at(0)<<8)|command.unicode_at(1),"Unsupported stateful original bracket command")
		result+="["
	return result

static func _expand_code(code:int,state:Dictionary,depth:int)->String:
	if depth>MAX_DEPTH or int(state.steps)>=MAX_STEPS or state.stack.has(code):_issue(state,code,"Recursive original text exceeds its supported bounds");return ""
	state.steps+=1;state.stack.append(code)
	var result:=""
	if code>=0x8000:
		var label:Variant=_data.ff_code_to_label.get(str(code))
		var entry:Variant=_data.strings.get(str(label)) if label!=null else null
		if not entry is Dictionary or not _hex(entry.get("hex")):_issue(state,code,"Original text code is not extracted")
		else:
			var raw:=str(entry.hex).hex_decode()
			if raw.is_empty() or raw[-1]!=0:_issue(state,code,"Invalid original C string")
			elif state.language=="ru":
				var translation:Variant=_ru.strings.get(str(label))
				if not translation is Dictionary or not translation.get("text") is String or str(translation.get("source_hex","")).to_lower()!=str(entry.hex).to_lower():_issue(state,code,"Missing or stale Russian source translation")
				else:result=_expand_input(translation.text,state,depth+1)
			else:result=_expand_input(raw,state,depth+1)
	elif code==0x3000:pass
	elif code>=0x3001 and code<=0x300c:
		var index:=(code-0x3001)%3;var value:Variant=_variable(state,index,code)
		if not _integer(value,-2147483648,4294967295):_issue(state,code,"Original numeric text variable is not a32-bit integer")
		elif code<=0x3003:result=_source_integer(int(value))
		else:result=_source_fraction(int(value),1+int((code-0x3004)/3))
	elif code in [0x3016,0x3017]:
		var value:Variant=_variable(state,code-0x3013,code)
		if value is String or value is PackedByteArray:result=_expand_input(value,state,depth+1)
		else:_issue(state,code,"Original string text variable is unavailable")
	elif code>=0x3018 and code<=0x301c:
		var value:Variant=_variable(state,code-0x3018,code)
		if _integer(value,0,65535):result=_expand_code(int(value),state,depth+1)
		else:_issue(state,code,"Original recursive FF variable is unavailable")
	elif code in [0x301d,0x301e]:
		var value:Variant=_variable(state,code-0x301a,code)
		if _integer(value,-2147483648,4294967295):result=_source_integer(int(value))
		else:_issue(state,code,"Original numeric text variable is unavailable")
	elif code>=0x301f and code<=0x3021:
		var value:Variant=_variable(state,code-0x301f,code)
		if _integer(value,-2147483648,4294967295):result="-" if _s32(int(value))==0 else _source_integer(int(value))+"t"
		else:_issue(state,code,"Original cargo text variable is unavailable")
	else:_issue(state,code,"Original FF branch is outside the supported information scope")
	state.stack.pop_back()
	return _brackets(result,state)

static func _expand_input(input:Variant,state:Dictionary,depth:int)->String:
	if depth>MAX_DEPTH:_issue(state,-1,"Original text nesting is too deep");return ""
	var text:String=_bytes_to_string(input) if input is PackedByteArray else str(input)
	var result:="";var at:=0
	while at<text.length() and result.length()<MAX_OUTPUT:
		var value:=text.unicode_at(at);at+=1
		if value==0 or value==0x10000:break
		if value==255:
			if at+1>=text.length():_issue(state,255,"Truncated original FF code");break
			var code:=((text.unicode_at(at)&255)<<8)|(text.unicode_at(at+1)&255);at+=2;result+=_expand_code(code,state,depth+1)
		elif value in [253,254]:
			var count:=1 if value==253 else 2
			if at+count>text.length():_issue(state,value,"Truncated original position code");break
			result+=String.chr(30 if value==253 else 31)+text.substr(at,count);at+=count
		elif value==123 and input is String:
			var end:=text.find("}",at)
			if end<0:result+="{";continue
			var token:=text.substr(at,end-at);var consumed:=true
			if token.begins_with("FF") and token.length()==6 and _hex(token.substr(2)):result+=_expand_code(token.substr(2).hex_to_int(),state,depth+1)
			elif token.begins_with("FD") and token.length()==4 and _hex(token.substr(2)):result+=String.chr(30)+String.chr(token.substr(2).hex_to_int())
			elif token.begins_with("FE") and token.length()==6 and _hex(token.substr(2)):result+=String.chr(31)+String.chr(token.substr(2,2).hex_to_int())+String.chr(token.substr(4,2).hex_to_int())
			elif token.begins_with("CTRL") and token.length()==6 and _hex(token.substr(4)):result+=String.chr(token.substr(4).hex_to_int())
			else:consumed=false;result+="{"
			if consumed:at=end+1
		else:result+=String.chr(value)
	if result.length()>=MAX_OUTPUT:
		_issue(state,-1,"Original expanded text exceeds the information buffer")
		result=result.substr(0,MAX_OUTPUT)
	return result

static func plain_text(expanded:String,language:="en")->String:
	# UI uses semantic text, not the original320px positioned glyph renderer.
	# Keep the expansion bytes available separately; turn x-position into a
	# column separator and absolute-position into a new semantic line.
	var result:="";var at:=0
	while at<expanded.length():
		var value:=expanded.unicode_at(at);at+=1
		if value==30:at+=1;result+="\t"
		elif value==31:at+=2;result+="\n"
		elif value in [10,13]:result+="\n"
		elif value>=128 and value<=255 and language=="en":result+=String.chr(0xfffd)
		elif value>=32:result+=String.chr(value)
	return result
static func _result(expanded:String,state:Dictionary)->Dictionary:
	var glyphs:Array=[];var at:=0
	if state.language=="en":
		while at<expanded.length():
			var value:=expanded.unicode_at(at);at+=1
			if value==30:at+=1
			elif value==31:at+=2
			elif value>=128 and value<=255 and not glyphs.has(value):glyphs.append(value)
	return {"ok":state.errors.is_empty(),"text":plain_text(expanded,state.language),"expanded_text":expanded,"raw_bytes":_string_bytes(expanded,state.language),"unmapped_glyphs":glyphs,"unsupported_codes":state.unsupported_codes.duplicate(),"error":"; ".join(state.errors),"language":state.language,"presentation":"semantic_text_with_tabs_not_original_pixel_layout"}
static func _state(variables:Array,context:Dictionary,language:String)->Dictionary:
	return {"variables":variables.duplicate(true),"context":context.duplicate(true),"language":language,"unsupported_codes":[],"errors":[],"stack":[],"steps":0}
static func render_code(code:int,variables:Array=[],context:Dictionary={},language:="ru")->Dictionary:
	if code<0 or code>65535 or not language in ["en","ru"] or not _load():return {"ok":false,"text":"","expanded_text":"","raw_bytes":PackedByteArray(),"unsupported_codes":[],"error":"Original system-information text data are unavailable or invalid."}
	var state:=_state(variables,context,language);var expanded:=_expand_code(code,state,0)
	return _result(expanded,state)
static func expand(input:Variant,variables:Array=[],context:Dictionary={},language:="ru")->Dictionary:
	if not (input is String or input is PackedByteArray) or not language in ["en","ru"] or not _load():return {"ok":false,"text":"","expanded_text":"","raw_bytes":PackedByteArray(),"unsupported_codes":[],"error":"Original system-information text input is unavailable or invalid."}
	var state:=_state(variables,context,language);var expanded:=_expand_input(input,state,0)
	return _result(expanded,state)

static func render_label(label:int,variables:Array=[],context:Dictionary={},language:="ru")->Dictionary:
	if not _load() or not language in ["en","ru"] or not _data.strings.has(str(label)):
		return {"ok":false,"text":"","raw_bytes":PackedByteArray(),"unsupported_codes":[],"error":"Original information literal is unavailable."}
	var entry:Dictionary=_data.strings[str(label)]
	if language=="ru":
		var translated:Variant=_ru.strings.get(str(label))
		if not translated is Dictionary or str(translated.get("source_hex","")).to_lower()!=str(entry.hex).to_lower():
			return {"ok":false,"text":"","raw_bytes":PackedByteArray(),"unsupported_codes":[],"error":"Russian information literal is missing or stale."}
		return expand(str(translated.text),variables,context,language)
	return expand(str(entry.hex).hex_decode(),variables,context,language)
