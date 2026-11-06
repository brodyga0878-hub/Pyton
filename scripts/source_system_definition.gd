extends RefCounted
# Original F830 names and F860 headers; the sector kernel supplies F852 inputs.
const Kernel=preload("res://scripts/source_galaxy.gd")
const Metadata=preload("res://scripts/source_system_metadata.gd")
const Names=preload("res://scripts/source_planet_names.gd")
const Math=preload("res://scripts/ground_coordinates.gd")
const DATA_PATH:="res://data/ffe_system_names.json"
const SOURCE_VARIANT:="ffe-f830-f860-native-headers-v1"
const MASK:=0xffffffff
const SOL_Q16:=Vector3i(387481600,354721792,-27648)
var _kernel:=Kernel.new()
var _data:Dictionary={}
var _tables:Dictionary={}
var _cache:Dictionary={}
var _order:Array=[]

func _load()->bool:
	if not _data.is_empty():return true
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var galaxy:Variant=JSON.parse_string(FileAccess.get_file_as_string(Kernel.DATA_PATH))
	if not parsed is Dictionary or parsed.get("schema")!=1 or parsed.get("source_sha256")!=Metadata.SOURCE_SHA or not parsed.get("strings_hex") is Array or parsed.strings_hex.size()!=267:return false
	if not galaxy is Dictionary or not galaxy.get("tables_hex") is Dictionary:return false
	for key in ["6799","6800","6801","6802","6803","6804","6805"]:
		if not galaxy.tables_hex.get(key) is String:return false
		_tables[key]=str(galaxy.tables_hex[key]).hex_decode()
	var starts:PackedByteArray=_tables["6800"].duplicate();starts.append_array(_tables["6801"]);_tables["starts"]=starts
	# Exotic type15 reads adjacent original DATA6805 words in F860 too.
	var masses:PackedByteArray=_tables["6803"].duplicate();masses.append_array(_tables["6804"]);masses.append_array(_tables["6805"]);_tables["masses"]=masses
	_data=parsed;return true

static func _rol16(value:int,amount:int)->int:
	amount&=15;value&=65535
	return ((value<<amount)|(value>>(16-amount)))&65535 if amount else value

func name_bytes(id:Variant)->PackedByteArray:
	if not Kernel._u32(id) or not _load():return PackedByteArray()
	var value:=int(id);var x:=value&8191;var y:=(value>>13)&8191;var index:=(value>>26)&63
	for sector in range(49):
		if int(_tables["6799"].decode_u32(sector*4))==(x|(y<<16)):
			var at:=int(_tables.starts.decode_u32(sector*4))+index
			if at>=_data.strings_hex.size():return PackedByteArray()
			return Names.expand_table_index(_data.strings_hex,at)
	if value==0x1aa51717:
		var gateway:=str(_data.gateway_hex).hex_decode().slice(4)
		return gateway.slice(0,gateway.find(0)+1)
	var bx:=(x+index)&65535;var di:=(y+bx)&65535
	bx=(_rol16(bx,3)+di)&65535
	di=(_rol16(di,5)+bx)&65535
	di=_rol16(di,4);bx=(_rol16(bx,index&15)+di)&65535
	var first:=bx;bx=_rol16(bx,11);var second:=bx;bx=_rol16(bx,11)
	var result:=PackedByteArray();var chunks:PackedByteArray=_tables["6802"]
	for part in [first,second,bx]:
		var at:=int(part)&0x7c
		for offset in range(4):
			if chunks[at+offset]==0:break
			result.append(chunks[at+offset])
	if not result.is_empty():result[0]=(int(result[0])+0xe0)&255
	result.append(0);return result

func header(id:Variant)->Dictionary:
	if not Kernel._u32(id) or not _load():return {}
	var star:=_kernel.system(id)
	if star.is_empty():return {}
	var text:=name_bytes(id);var policy:=Metadata.query(id)
	if text.is_empty() or policy.is_empty():return {}
	var kind:=int(star.star_type)&15;var count:=int(star.star_count_code)
	var masses:PackedByteArray=_tables.masses
	if (kind+2)*4>masses.size():return {}
	var minimum:=int(masses.decode_u32(kind*4));var maximum:=int(masses.decode_u32((kind+1)*4))
	var mass:=(minimum+((((maximum-minimum)&MASK)>>16)*((count&0xf8)<<8)))&MASK
	var point:PackedInt64Array=star.position_q16
	var seed:=0 if int(star.star_type)&128 else ((int(point[1])>>16)+(int(point[1])<<16)+int(point[0])-int(point[2]))&MASK
	return {"seed_a":seed,"mass":mass,"num_stars":count&7,"system_id":int(id),"population_raw":int(policy.F869_values[2]),"system_name_bytes":text,"system_name":text.slice(0,text.size()-1).get_string_from_ascii()}

func describe(id:Variant)->Dictionary:
	if not Kernel._u32(id):return {}
	var key:=int(id)
	if _cache.has(key):_order.erase(key);_order.append(key);return _cache[key].duplicate(true)
	var parameters:=header(id)
	if parameters.is_empty():return {}
	var star:=_kernel.system(id);var point:PackedInt64Array=star.position_q16
	var original:=str(parameters.system_name);var title:=original
	var translations:={"Sol":"Солнце","Alpha Centauri":"Альфа Центавра","Sirius":"Сириус","Gateway":"Гейтвей","Lave":"Лейв","Diso":"Дисо","Leesti":"Листи","Zaonce":"Заонс","Riedquat":"Ридкват"}
	title=str(translations.get(original,original))
	var row:={"id":key,"name":title,"original_name":original,"source_parameters":parameters,"source_variant":SOURCE_VARIANT,"sector":[key&8191,(key>>13)&8191],"position_q16":Array(point),"position_ly":[float(point[0]-SOL_Q16.x)*8.0/65536.0,float(point[1]-SOL_Q16.y)*8.0/65536.0,float(point[2]-SOL_Q16.z)*8.0/65536.0],"type_code":int(star.star_type),"star_count_code":int(star.star_count_code),"type":"Звёздная система","coordinates_source":Kernel.SOURCE_VARIANT,"has_station":false,"station_source":"source_port_selection_required","source_metadata":Metadata.query(id)}
	_order.append(key);_cache[key]=row
	if _order.size()>64:_cache.erase(_order.pop_front())
	return row.duplicate(true)
