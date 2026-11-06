extends RefCounted
# Original complete F883..F887 callbacks, including F893 names and F891/F892
# appended records. The historical bounded classifier remains unchanged.
const RandomSource=preload("res://scripts/stellar_body_factory.gd")
const Names=preload("res://scripts/source_planet_names.gd")
const Settlement=preload("res://scripts/source_settlement_builder.gd")
const SOURCE_VARIANT:="jjffe-7e54034-populated-classifiers-v1"
const CALLBACKS:=[883,884,885,886,887]
const FIELDS:=["index","seed_a","seed_b","ordinal_counter","port_count_byte","orbital_count_byte","population_raw","system_id","language"]
const MASK:=0xffffffff
var _settlements:=Settlement.new()

static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=MASK and float(value)==floorf(float(value))
static func _s16(value:int)->int:return (value&65535)-65536 if (value&65535)>=32768 else value&65535
static func _s32(value:int)->int:return (value&MASK)-0x100000000 if (value&MASK)>=0x80000000 else value&MASK
static func _body(context:Dictionary)->PackedByteArray:return context.records[int(context.state.index)]
static func _word(context:Dictionary,offset:int)->int:return int(_body(context).decode_u16(offset))
static func _set_word(context:Dictionary,offset:int,value:int)->void:
	var body:=_body(context).duplicate();body.encode_u16(offset,value&65535);context.records[int(context.state.index)]=body
static func _class(context:Dictionary,model:int,kind:int)->void:
	var body:=_body(context).duplicate();body.encode_u16(0xc,model);body.encode_u16(0xa,kind);context.records[int(context.state.index)]=body
static func _temperature(context:Dictionary,amount:int)->int:
	var result:=(_word(context,0x24)+amount)&65535;_set_word(context,0x24,result);return result
static func _population(context:Dictionary)->int:return _s32(int(context.state.population_raw))

static func _name(context:Dictionary,category:int)->bool:
	var result:=Names.rename(_body(context),category,context.state.language)
	if result.is_empty():context.failed=true;return false
	context.records[int(context.state.index)]=result.record
	return true

func _settle(context:Dictionary,ground:bool,first:int,second:int)->bool:
	var request:Dictionary={}
	for key in Settlement.FIELDS:request[str(key)]=int(context.state[key])
	var result:Dictionary
	if ground:
		request["model_offset"]=first;request["count_scale"]=second&MASK
		result=_settlements.construct_ground_full(context.records,request)
	else:
		request["port_type"]=first;request["parent_index"]=second
		result=_settlements.construct_orbital_full(context.records,request)
	if result.is_empty() or not result.get("ok",false):
		context.failed=true;context.error=result
		return false
	context.records=result.records
	for key in Settlement.FIELDS:context.state[str(key)]=int(result[key])
	return true

func _ground(context:Dictionary,model_offset:int,count_scale:int)->bool:
	return _settle(context,true,model_offset,count_scale)
func _orbital(context:Dictionary,port_type:int)->bool:
	return _settle(context,false,port_type,int(context.entry_index)+1)

func _earthlike(context:Dictionary,population_shift:int,upper_type_threshold:int)->void:
	# Shared source blocks after an F883/F884 inhabited-body classification.
	var population:=_population(context)
	if not _name(context,8) or not _ground(context,0,population>>population_shift):return
	if population>=30:_orbital(context,2 if population>=upper_type_threshold else (1 if population>=50 else 0))

func _f883(context:Dictionary,mass:int)->void:
	var temperature:=_word(context,0x24)
	if temperature>0x139:
		_class(context,0x7b,0xc);_temperature(context,mass>>1);return
	if temperature<=0xd7:
		if temperature>=0xaa:
			_temperature(context,0x19)
			var population:=_population(context)
			if population<0xc8:
				_class(context,0x7b,6)
				var system:=int(context.state.system_id)
				if system in [0x1aa89738,0x02ae1718,0x0eb6973d]:
					_set_word(context,0xc,0x85)
					if system==0x02ae1718 and int(_body(context).decode_u32(4))==0x5b5ff290:
						if not _orbital(context,3):return
					if system==0x0eb6973d and int(_body(context).decode_u32(4))==0x70740190:_orbital(context,4)
				return
			if _word(context,0x24)<0x127:_set_word(context,0x24,0x127)
			_class(context,0x7e,0xb);_earthlike(context,5,0xf2);return
		if temperature>=0x42 and temperature<=0x7b:
			_temperature(context,0x16);_class(context,0x7c,7);return
		_f884(context);return
	temperature=_temperature(context,0x23)
	var seeds:=RandomSource.rng_step(context.state.seed_a,context.state.seed_b)
	context.state.seed_a=seeds[0];context.state.seed_b=seeds[1]
	var population:=_population(context)
	# Source CMP/JNA uses the unsigned wrapped subtraction, not a float chance.
	if ((int(seeds[0])&255)>>2)>((temperature-0xfa)&MASK):
		if population<0x78:_class(context,0x80,8);return
		if _word(context,0x24)<0x127:_set_word(context,0x24,0x127)
		_class(context,0x7e,0xb);_earthlike(context,5,0xf2);return
	if population<4:return
	if not _name(context,9):return
	if population<16:return
	if (int(context.state.seed_a)&0xf0)==0:_set_word(context,0xc,0x84)
	if _word(context,0x24)>0x118:
		if _word(context,0x24)>0x134:
			_set_word(context,0xc,0x83)
			if _word(context,0x24)>0x152:_set_word(context,0xc,0x82)
		if (int(context.state.seed_a)&15)==0:
			_set_word(context,0xc,0x80)
			if not _ground(context,0x24,population>>5):return
		elif not _ground(context,0,population>>5):return
		if population>=30:_orbital(context,2 if population>=0xf2 else (1 if population>=50 else 0))
	else:
		_set_word(context,0xc,0x7f)
		if not _ground(context,0x18,population>>6):return
		if population>=40:_orbital(context,1 if population>=80 else 0)

func _f884(context:Dictionary)->void:
	var temperature:=_temperature(context,0x14);var population:=_population(context)
	if population>=0x96 and temperature>=0x102 and temperature<=0x139:
		if temperature<0x127:_set_word(context,0x24,0x127)
		_class(context,0x7e,9);_earthlike(context,6,0xb4);return
	_class(context,0x79,4)
	if temperature>0x212:return
	if not ((population>=0xc8 and temperature>=0xa0) or (temperature>=0xb4 and population>6) or (population>=0xfa and temperature>0x87)):return
	if _s16(_word(context,2))>0x47:_set_word(context,2,0x47)
	if not _name(context,10):return
	if population>=30:
		if not _ground(context,0xc,0):return
		if population>=100:_orbital(context,1 if population>=0xaa else 0)

func _f885(context:Dictionary)->void:
	var temperature:=_word(context,0x24);var population:=_population(context)
	if temperature<0x96 or temperature>0x1f4 or not (population>=0xc8 or (temperature>=0xc8 and population>8)):return
	if not _name(context,10):return
	if population>=45:
		if not _ground(context,0xc,0):return
		if population>=0x96:_orbital(context,0)

func _f886(context:Dictionary)->void:
	var population:=_population(context)
	if _word(context,0x24)<0xdc or population<=50:return
	if not _name(context,10):return
	if population>=80:_ground(context,0xc,0)

func _f887(context:Dictionary)->void:
	_set_word(context,0,0);_set_word(context,2,0x38)
	if _word(context,0x24)>=0xdc and _population(context)>50:_name(context,10)

func classify(records:Array,callback:Variant,mass:Variant,state:Dictionary)->Dictionary:
	if records.size()!=128 or not _u32(callback) or int(callback) not in CALLBACKS or not _u32(mass):return {}
	for body in records:
		if not body is PackedByteArray or body.size()!=68:return {}
	var working_state:Dictionary={}
	for key in FIELDS:
		if not _u32(state.get(key)):return {}
		working_state[str(key)]=int(state[key])
	if working_state.index>=128 or working_state.port_count_byte>255 or working_state.orbital_count_byte>255:return {}
	var context:={"records":records.duplicate(),"state":working_state,"entry_index":int(working_state.index),"failed":false,"error":{}}
	match int(callback):
		883:_f883(context,int(mass))
		884:_f884(context)
		885:_f885(context)
		886:_f886(context)
		887:_f887(context)
	if context.failed:return context.error
	var result:Dictionary=context.state.duplicate(true)
	result["ok"]=true;result["records"]=context.records;result["callback"]=int(callback)
	result["appended_count"]=int(context.state.index)-int(context.entry_index)
	result["source_variant"]=SOURCE_VARIANT
	return result
