extends RefCounted
# Original F893 populated-body names and bounded F791 textual categories.
# Names retain original byte encoding; display decoding is deliberately separate.
const SOURCE_VARIANT:="jjffe-7e54034-names-original-text"
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const DATA_PATH:="res://data/ffe_planet_names.json"
const MASK:=0xffffffff
static var _data:Dictionary={}
static var _strings:Array=[]

static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=MASK and float(value)==floorf(float(value))

static func _load()->bool:
	if not _data.is_empty():return true
	if not FileAccess.file_exists(DATA_PATH):return false
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or parsed.get("source_sha256")!=SOURCE_SHA or parsed.get("source_variant")!=SOURCE_VARIANT or parsed.get("schema")!=1:return false
	if not parsed.get("strings_hex") is Array or parsed.strings_hex.size()!=510:return false
	if not parsed.get("type_offsets") is Array or parsed.type_offsets.size()!=15 or not parsed.get("type_ranges") is Array or parsed.type_ranges.size()!=15:return false
	if not parsed.get("special_offsets") is Array or parsed.special_offsets.size()!=2 or not parsed.get("special_ranges") is Array or parsed.special_ranges.size()!=2:return false
	for key in ["type_offsets","type_ranges","special_offsets","special_ranges"]:
		for value in parsed[key]:
			if not _u32(value) or value>510:return false
	for kind in range(6,15):
		if int(parsed.type_offsets[kind])+int(parsed.type_ranges[kind])>510:return false
	for kind in range(2):
		if int(parsed.special_offsets[kind])+int(parsed.special_ranges[kind])>510:return false
	var strings:Array=[]
	for text in parsed.strings_hex:
		if not text is String or text.length()%2!=0:return false
		for character in text:
			if character not in "0123456789abcdefABCDEF":return false
		var raw:=str(text).hex_decode()
		if raw.is_empty() or raw[-1]!=0:return false
		for i in range(raw.size()-1):
			if raw[i]==0:return false
		strings.append(raw)
	_data=parsed;_strings=strings
	return true

static func _rotate(value:int,amount:int)->int:
	return ((value<<amount)|(value>>(32-amount)))&MASK

static func random_bounded(first:Variant,second:Variant,bound:Variant)->Dictionary:
	# F921: local pointer RNG used by F791/F793, distinct from global F894.
	if not _u32(first) or not _u32(second) or not _u32(bound):return {}
	var next_second:=_rotate(int(second),5)
	var next_first:=_rotate((int(first)+int(second)+next_second)&MASK,16)
	return {"first":next_first,"second":next_second,"value":(((next_first&65535)*int(bound))&MASK)>>16}

static func _write_bytes(buffer:PackedByteArray,at:int,raw:PackedByteArray)->void:
	if buffer.size()<at+raw.size():buffer.resize(at+raw.size())
	for i in range(raw.size()):buffer[at+i]=raw[i]

static func _expand_buffer(table:Array,index:Variant,var3:PackedByteArray)->Dictionary:
	if not _u32(index) or int(index)>=table.size():return {}
	var text:Variant=table[int(index)]
	if text is String:text=str(text).hex_decode()
	if not text is PackedByteArray or text.is_empty() or text[-1]!=0:return {}
	var buffer:=PackedByteArray();var at:=0;var cursor:=0
	while at<text.size():
		var byte:=int(text[at]);at+=1
		if byte==0:
			_write_bytes(buffer,cursor,PackedByteArray([0]));cursor+=1
			return {"name_bytes":buffer.slice(0,cursor),"write_bytes":buffer,"end_offset":cursor}
		if byte==255:
			if at+1>=text.size() or int(text[at])!=0x30 or int(text[at+1])!=0x16 or var3.is_empty() or var3[-1]!=0:return {}
			at+=2
			var expanded:=_source_brackets(var3)
			if expanded.is_empty():return {}
			# F1364/F1348 writes the raw inserted name first. F1343 then
			# copies the possibly shorter F77 result over that same buffer.
			# Bytes after its new NUL are intentionally retained.
			_write_bytes(buffer,cursor,var3);_write_bytes(buffer,cursor,expanded)
			cursor+=expanded.size()-1
		elif byte==254:
			if at+1>=text.size():return {}
			_write_bytes(buffer,cursor,PackedByteArray([31,text[at],text[at+1]]));at+=2;cursor+=3
		elif byte==253:
			if at>=text.size():return {}
			_write_bytes(buffer,cursor,PackedByteArray([30,text[at]]));at+=1;cursor+=2
		else:_write_bytes(buffer,cursor,PackedByteArray([byte]));cursor+=1
	return {}

static func expand_table_index(table:Array,index:Variant,var3:PackedByteArray=PackedByteArray())->PackedByteArray:
	# Actual naming templates use only FF3016 (StringVar4). Other FF domains
	# belong to different text modules and are rejected, never fabricated.
	var result:=_expand_buffer(table,index,var3)
	return PackedByteArray() if result.is_empty() else result.name_bytes

static func _source_brackets(text:PackedByteArray)->PackedByteArray:
	# F1343 invokes F77/F76 on the inserted plain name. The original table
	# contains one literal '[': M[nich. Its unknown 'ni' bracket command
	# consumes those two bytes and leaves '['. Preserve that source quirk.
	var result:=PackedByteArray();var at:=0
	while at<text.size()-1:
		var byte:=int(text[at]);at+=1
		if byte in [0,253,254,255]:return PackedByteArray()
		if byte==91:
			if at+1>=text.size()-1 or text[at]!=110 or text[at+1]!=105:return PackedByteArray()
			at+=2
		result.append(39 if byte==0xd5 else byte)
	result.append(0)
	return result

static func _pick(state:Dictionary,bound:int)->int:
	var next:=random_bounded(state.first,state.second,bound)
	state.first=next.first;state.second=next.second
	return int(next.value)

static func _expand(index:int,var3:PackedByteArray=PackedByteArray())->PackedByteArray:
	return expand_table_index(_strings,index,var3)

static func _surname(state:Dictionary)->PackedByteArray:
	if (int(state.first)&255)>=25:return _expand(89+_pick(state,138))
	var result:=_expand(79+_pick(state,10))
	result[-1]=115
	if (int(state.first)&0x800)==0:result.append_array(PackedByteArray([111,110]))
	result.append(0)
	return result

static func surname(first:Variant,second:Variant,table:Array=[])->Dictionary:
	# Reusable F793 for callers such as source system names. Its source id
	# argument is unused; the explicit local pair is the full mutable input.
	if not _u32(first) or not _u32(second):return {}
	if table.is_empty() and not _load():return {}
	var state:={"first":int(first),"second":int(second)}
	var raw:=PackedByteArray()
	if table.is_empty():raw=_surname(state)
	else:
		if (int(state.first)&255)>=25:raw=expand_table_index(table,89+_pick(state,138))
		else:
			raw=expand_table_index(table,79+_pick(state,10))
			if raw.is_empty():return {}
			raw[-1]=115
			if (int(state.first)&0x800)==0:raw.append_array(PackedByteArray([111,110]))
			raw.append(0)
	if raw.is_empty():return {}
	return {"name_bytes":raw,"first":int(state.first),"second":int(state.second)}

static func generate(category:Variant,uid:Variant,player_name:PackedByteArray=PackedByteArray([0]))->Dictionary:
	if not _u32(category) or not _u32(uid) or int(category)>22 or not _load():return {}
	var kind:=int(category);var first:=int(uid);var second:=0
	if kind<22:
		if kind<6:second=(_rotate(first,16)+first)&MASK;first=_rotate(first,7)
		else:
			second=_rotate(first,16);first=(first+second)&MASK
			second=_rotate(second,7);first=(first+second)&MASK
			second=_rotate(second,4);first=(first+second)&MASK
	var state:={"first":first,"second":second};var raw:=PackedByteArray();var write_bytes:=PackedByteArray()
	if kind in [0,15,21]:raw=PackedByteArray([63,63,63,63,0])
	elif kind in [1,2,3,5]:
		var female:=kind==2
		if kind in [3,5]:female=(_pick(state,255)&0x40)!=0
		raw=_expand(224+_pick(state,60) if female else _pick(state,105))
		if kind!=5:
			raw[-1]=32;raw.append_array(_surname(state))
	elif kind==4:
		_pick(state,4);raw=_expand(89+_pick(state,138))
	elif kind>=6 and kind<=14:
		var base:=_surname(state)
		var expanded:=_expand_buffer(_strings,int(_data.type_offsets[kind])+_pick(state,int(_data.type_ranges[kind])),base)
		if expanded.is_empty():return {}
		raw=expanded.name_bytes;write_bytes=expanded.write_bytes
	elif kind in [16,17]:
		var base:=_expand(394+_pick(state,88))
		var expanded:=_expand_buffer(_strings,int(_data.special_offsets[kind-16])+_pick(state,int(_data.special_ranges[kind-16])),base)
		if expanded.is_empty():return {}
		raw=expanded.name_bytes;write_bytes=expanded.write_bytes
	elif kind in [18,19,20]:
		if kind==19:raw.append_array(PackedByteArray([32,43]))
		else:
			for i in range(2):raw.append(65+_pick(state,26))
			raw.append_array(PackedByteArray([45]) if kind==18 else PackedByteArray([42,32,32]))
		for i in range(3 if kind in [18,19] else 1):raw.append(48+_pick(state,10))
		if kind==19:raw.append(65+_pick(state,26))
		raw.append(0)
	elif kind==22:
		if player_name.is_empty() or player_name[-1]!=0:return {}
		for i in range(player_name.size()-1):
			if player_name[i]==0:return {}
		raw=player_name.duplicate()
	if raw.is_empty():return {}
	return {"name_bytes":raw,"write_bytes":raw.duplicate() if write_bytes.is_empty() else write_bytes,"end_offset":raw.size(),"first":int(state.first),"second":int(state.second),"source_variant":SOURCE_VARIANT}

static func rename(record:PackedByteArray,category:Variant,language:Variant=0)->Dictionary:
	# These are every F893 category reachable from F881/F883..887/F891/F892.
	if record.size()!=68 or not _u32(category) or not _u32(language) or int(category) not in [6,7,8,9,10]:return {}
	var kind:=int(category)
	if int(language)==3:
		if kind in [8,9]:kind=16
		elif kind in [6,7]:kind=17
	var result:=generate(kind,int(record.decode_u32(4)))
	if result.is_empty() or result.write_bytes.size()>30:return {}
	var renamed:=record.duplicate();renamed[0x3f]|=0x80
	for i in range(result.write_bytes.size()):renamed[38+i]=result.write_bytes[i]
	result["record"]=renamed;result["effective_category"]=kind
	return result
