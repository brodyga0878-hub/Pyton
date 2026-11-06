extends RefCounted
# Original F891/F892 appended source records, in source packed units.
# Naming is delegated to the independently checked original F893/F791 module.
const Math=preload("res://scripts/ffe_math.gd")
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const SOURCE_VARIANT:="jjffe-7e54034-settlements-v1"
const DATA_PATH:="res://data/ffe_settlement_rules.json"
const MASK:=0xffffffff
const FIELDS:=["index","seed_a","seed_b","population_raw","ordinal_counter","port_count_byte","orbital_count_byte","language"]
var _data:Dictionary={}
var _names:Script

static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=MASK and float(value)==floorf(float(value))
static func _s8(value:int)->int:return (value&255)-256 if (value&255)>=128 else value&255
static func _s32(value:int)->int:return (value&MASK)-0x100000000 if (value&MASK)>=0x80000000 else value&MASK
static func _rol(value:int,bits:int)->int:return ((value<<bits)|(value>>(32-bits)))&MASK

func _load()->bool:
	if not _data.is_empty():return true
	if not FileAccess.file_exists(DATA_PATH):return false
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or parsed.get("schema")!=1 or parsed.get("source_sha256")!=SOURCE_SHA:return false
	if not parsed.get("tables") is Dictionary or not parsed.get("templates") is Dictionary:return false
	for entry in [["ground_coordinates",32],["ground_models",48],["orbital_models",12]]:
		if not parsed.tables.get(entry[0]) is Array or parsed.tables[entry[0]].size()!=entry[1]:return false
		for value in parsed.tables[entry[0]]:
			if not _u32(value):return false
	for key in ["2","12","16","17"]:
		if not parsed.templates.get(key) is String or str(parsed.templates[key]).hex_decode().size()!=68:return false
	_data=parsed
	return true

func _request(records:Array,request:Dictionary,extra:Array,slots:int)->Dictionary:
	if records.size()!=slots:return {}
	for record in records:
		if not record is PackedByteArray or record.size()!=68:return {}
	for key in FIELDS+extra:
		if not _u32(request.get(key)):return {}
	if request.index>=slots or request.port_count_byte>255 or request.orbital_count_byte>255:return {}
	if not _load():return {}
	var state:Dictionary={}
	for key in FIELDS+extra:state[str(key)]=int(request[key])
	return state

func _rename(record:PackedByteArray,category:int,language:int)->Dictionary:
	if _names==null:
		if not FileAccess.file_exists("res://scripts/source_planet_names.gd"):return {}
		_names=load("res://scripts/source_planet_names.gd")
	if _names==null:return {}
	return _names.rename(record,category,language)

static func _result(records:Array,state:Dictionary,count:int)->Dictionary:
	var result:=state.duplicate(true)
	result["ok"]=true;result["records"]=records;result["appended_count"]=count
	result["source_variant"]=SOURCE_VARIANT
	return result

static func _capacity(helper:int)->Dictionary:
	return {"ok":false,"reason":"capacity","helper_id":helper}

func construct_ground(records:Array,request:Dictionary)->Dictionary:
	return _construct_ground(records,request,60)

func construct_ground_full(records:Array,request:Dictionary)->Dictionary:
	# F881's body limit is60, but its settlement callbacks append afterwards.
	# A separate source-system bank keeps those real writes and the sentinel.
	return _construct_ground(records,request,128)

func _construct_ground(records:Array,request:Dictionary,slots:int)->Dictionary:
	var state:=_request(records,request,["model_offset","count_scale"],slots)
	if state.is_empty():return {}
	var working:=records.duplicate()
	if _s8(state.port_count_byte)>=18:return _result(working,state,0)
	# F891 uses the low DWORD of signed IMUL, then unsigned SHR16.
	var iterations:=mini(3,(((int(state.seed_b)&65535)*int(state.count_scale))&MASK)>>16)+1
	if state.port_count_byte<18:iterations=mini(iterations,18-int(state.port_count_byte))
	if int(state.index)+iterations>=slots:return _capacity(891)
	var parent:=int(state.index)+1
	var local_a:=int(state.seed_a);var local_b:=int(state.seed_b)
	var appended:=0
	for _step in range(iterations):
		local_b=(local_b+local_a)&MASK
		local_a=(_rol(local_a,5)+local_b)&MASK
		local_a=(_rol(local_a,16)+local_b)&MASK
		state.index+=1
		var body:PackedByteArray=str(_data.templates["16"]).hex_decode()
		body.encode_u32(0,0x00390000);body.encode_u16(8,parent&65535);body.encode_u32(4,local_a)
		state.ordinal_counter=(int(state.ordinal_counter)+1)&MASK
		var pair:=(int(state.ordinal_counter)&15)*2
		body.encode_u16(0x22,int(_data.tables.ground_coordinates[pair])&65535)
		body.encode_u16(0x12,int(_data.tables.ground_coordinates[pair+1])&65535)
		var named:=_rename(body,6,int(state.language))
		if named.is_empty() or not named.get("record") is PackedByteArray or named.record.size()!=68:return {}
		body=named.record
		var model:=(int(state.model_offset)+((int(state.population_raw)>>5)&7)+((local_a&0x30000)>>16))&MASK
		if model>=48:return {}
		body.encode_u16(0x0c,int(_data.tables.ground_models[model])&65535)
		working[int(state.index)]=body
		state.port_count_byte=(int(state.port_count_byte)+1)&255;appended+=1
		if _s8(state.port_count_byte)>=18:break
	return _result(working,state,appended)

func construct_orbital(records:Array,request:Dictionary)->Dictionary:
	return _construct_orbital(records,request,60)

func construct_orbital_full(records:Array,request:Dictionary)->Dictionary:
	return _construct_orbital(records,request,128)

func _construct_orbital(records:Array,request:Dictionary,slots:int)->Dictionary:
	var state:=_request(records,request,["port_type","parent_index"],slots)
	if state.is_empty():return {}
	var working:=records.duplicate()
	if _s8(state.port_count_byte)>=18:return _result(working,state,0)
	if int(state.index)+1>=slots:return _capacity(892)
	if state.parent_index<1 or state.parent_index>int(state.index)+1:return {}
	state.port_count_byte=(int(state.port_count_byte)+1)&255
	state.orbital_count_byte=(int(state.orbital_count_byte)+1)&255
	state.index+=1
	var kind:=int(state.port_type)
	var body:PackedByteArray=records[int(state.index)].duplicate()
	var choice:=(int(state.seed_a)&0x300)>>8
	if kind<=4:
		var template:="2" if kind in [0,3] else ("17" if kind==1 else "12")
		body=str(_data.templates[template]).hex_decode()
		var model:=int(_data.tables.orbital_models[kind*4+choice]) if kind<3 else (0x45 if kind==3 else 0x4f)
		body.encode_u16(0x0c,model&65535)
	body.encode_u32(0,0x00390000);body.encode_u32(4,int(state.seed_a));body.encode_u16(8,int(state.parent_index)&65535)
	state.ordinal_counter=(int(state.ordinal_counter)+1)&MASK
	var orbit:=0x00227fff
	body.encode_u32(0x0e,orbit)
	body.encode_u32(0x14,Math.period(orbit,int(records[int(state.parent_index)-1].decode_u32(0))))
	if kind in [3,4]:
		for offset in range(5):body[0x26+offset]=63 if offset<4 else 0
	else:
		var named:=_rename(body,7,int(state.language))
		if named.is_empty() or not named.get("record") is PackedByteArray or named.record.size()!=68:return {}
		body=named.record
	working[int(state.index)]=body
	return _result(working,state,1)
