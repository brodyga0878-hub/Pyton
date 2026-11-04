extends RefCounted
# Original F881 stellar-name domain, composed with the complete checked F882.
# This is a bounded source-record constructor, not full planet/city generation.
const Initializer=preload("res://scripts/body_initializer.gd")
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const DATA_PATH:="res://data/ffe_stellar_factory.json"
const MASK:=0xffffffff
const MIN_MASS:=0x01036640
const MAX_MASS:=0xfffffffe
var _tables:Dictionary={}
var _initializer:=Initializer.new()

static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=MASK and value==floorf(value)
static func _signed32(value:int)->int:
	var word:=value&MASK
	return word-0x100000000 if word>=0x80000000 else word

static func rng_step(seed_a:int,seed_b:int)->PackedInt64Array:
	# F894. All intermediate additions and rotations have register32 width.
	var a:=seed_a&MASK
	var sum:=(seed_b+a)&MASK
	var rotated_a:=((a<<3)|(a>>29))&MASK
	var rotated_b:=((sum<<5)|(sum>>27))&MASK
	return PackedInt64Array([(rotated_a+sum+rotated_b)&MASK,rotated_b])

func _load_tables()->bool:
	if not _tables.is_empty():return true
	if not FileAccess.file_exists(DATA_PATH):return false
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or parsed.get("source_sha256")!=SOURCE_SHA:return false
	var tables:Variant=parsed.get("tables")
	if not tables is Dictionary:return false
	for key in ["mass_thresholds","type_codes","model_indices","temperatures","light_outputs","return_words","callback_ids"]:
		if not tables.get(key) is Array:return false
		if tables[key].size()!=(24 if key=="mass_thresholds" else 23):return false
		for value in tables[key]:
			if not _u32(value):return false
	if int(tables.mass_thresholds[23])!=0:return false
	_tables=tables
	return true

func construct(records:Array,request:Dictionary)->Dictionary:
	# Validate first; a failed call never mutates caller-owned records or state.
	if records.size()!=60:return {}
	for record in records:
		if not record is PackedByteArray or record.size()!=68:return {}
	var fields:=["index","parent","multiplier","distance","mass","seed_a","seed_b","depth","counter","body_count_byte","star_count_byte","planet_counter","moon_counter","third_counter"]
	for key in fields:
		if not _u32(request.get(key)):return {}
	var index:=int(request.index);var parent:=int(request.parent);var mass:=int(request.mass)
	if index>60 or parent>index or mass<MIN_MASS or mass>MAX_MASS:return {}
	if request.body_count_byte>255 or request.star_count_byte>255:return {}
	if not request.get("system_name") is String:return {}
	var name_bytes:String=request.system_name
	if name_bytes.length()>21:return {}
	for character in name_bytes:
		var code:int=character.unicode_at(0)
		if code<32 or code>126:return {}
	if not _load_tables():return {}
	var state:Dictionary={}
	for key in fields:state[key]=int(request[key])
	if index==60:
		state.ok=false;state.reason="capacity";state.return_word=65535;state.next_index=index
		return state
	for prior in range(index):
		if records[prior].decode_u16(8)>prior:return {}
	# Source uses unsigned threshold comparisons and stops at the zero sentinel.
	var bin:=0
	while int(_tables.mass_thresholds[bin])!=0 and mass>=int(_tables.mass_thresholds[bin]):bin+=1
	if bin>=23:return {}
	var callback:=int(_tables.callback_ids[bin])
	if callback not in [0,888,889,890]:return {}
	var body:PackedByteArray=records[index].duplicate()
	body.encode_u32(0x1c,int(_tables.light_outputs[bin]))
	body.encode_u16(0x0a,int(_tables.type_codes[bin])&65535)
	body.encode_u16(0x24,int(_tables.temperatures[bin])&65535)
	body.encode_u16(0x0c,int(_tables.model_indices[bin])&65535)
	state.body_count_byte=(state.body_count_byte+1)&255
	state.star_count_byte=(state.star_count_byte+1)&255
	# F881 copies the supplied system-name bytes, appends a space, and adds
	# star-counter+0x40 only for non-root records. Raw suffix-byte wrap is kept.
	var text:=name_bytes.to_ascii_buffer();text.append(32)
	if parent!=0:text.append((state.star_count_byte+0x40)&255)
	text.append(0)
	for offset in range(text.size()):body[0x26+offset]=text[offset]
	var working:=records.duplicate();working[index]=body
	var initialized:Dictionary=_initializer.construct(working,index,parent,int(request.multiplier),int(request.distance),mass,int(request.seed_a),int(request.seed_b),int(request.depth),int(request.counter))
	if initialized.is_empty():return {}
	body=initialized.record;state.counter=int(initialized.counter)
	var remnant:=callback==888
	if callback in [889,890]:
		var seeds:=rng_step(state.seed_a,state.seed_b);state.seed_a=seeds[0];state.seed_b=seeds[1]
		if (state.seed_a&0x80000000)!=0:
			if callback==890:remnant=true
			else:
				seeds=rng_step(state.seed_a,state.seed_b);state.seed_a=seeds[0];state.seed_b=seeds[1]
				remnant=(state.seed_a&0x80000000)!=0
	if remnant and _signed32(state.counter)>2:
		body.encode_u16(0x0c,0x94);body.encode_u16(0x0a,0x19)
		body.encode_u32(0x1c,0x3e2);body.encode_u16(0x24,0x2c09)
		body.encode_u16(0x02,(int(body.decode_u16(0x02))-1)&65535)
	state.ok=true;state.record=body;state.next_index=index+1
	state.return_word=int(_tables.return_words[bin])&65535;state.mass_bin=bin
	return state
