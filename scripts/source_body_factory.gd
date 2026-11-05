extends RefCounted
# Original F881 composition for stellar and bounded ordinal-named bodies.
# Unported naming/settlement paths reject atomically; this is not a galaxy.
const Stellar=preload("res://scripts/stellar_body_factory.gd")
const Initializer=preload("res://scripts/body_initializer.gd")
const Classifier=preload("res://scripts/planetary_classifier.gd")
const SOURCE_SHA:=Stellar.SOURCE_SHA
const MASK:=0xffffffff
const FIELDS:=["index","parent","multiplier","distance","mass","seed_a","seed_b","depth","counter","body_count_byte","star_count_byte","planet_counter","moon_counter","third_counter","population_raw","system_id"]
var _stellar:=Stellar.new()
var _initializer:=Initializer.new()
var _classifier:=Classifier.new()
var _tables:Dictionary={}

static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=MASK and value==floorf(value)

static func _blocked(helper:int)->Dictionary:
	return {"ok":false,"reason":"requires_unimplemented_source_helper","helper_id":helper}

func _load_tables()->bool:
	if not _tables.is_empty():return true
	if not FileAccess.file_exists(Stellar.DATA_PATH):return false
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(Stellar.DATA_PATH))
	if not parsed is Dictionary or parsed.get("source_sha256")!=Stellar.SOURCE_SHA:return false
	var tables:Variant=parsed.get("tables")
	if not tables is Dictionary:return false
	for key in ["mass_thresholds","type_codes","model_indices","temperatures","light_outputs","return_words","callback_ids"]:
		if not tables.get(key) is Array or tables[key].size()!=(24 if key=="mass_thresholds" else 23):return false
		for value in tables[key]:
			if not _u32(value):return false
	if int(tables.mass_thresholds[23])!=0:return false
	_tables=tables
	return true

static func _parent_name(record:PackedByteArray)->PackedByteArray:
	# A bounded API domain keeps the longest two-byte ordinal plus NUL inside
	# the original24-byte name field. No truncation or invented names are used.
	var name:=PackedByteArray()
	for offset in range(38,62):
		var value:=int(record[offset])
		if value==0:return name if name.size()<=21 else PackedByteArray()
		if value<32 or value>126:return PackedByteArray()
		name.append(value)
	return PackedByteArray()

func construct(records:Array,request:Dictionary)->Dictionary:
	if records.size()!=60:return {}
	for record in records:
		if not record is PackedByteArray or record.size()!=68:return {}
	for key in FIELDS:
		if not _u32(request.get(key)):return {}
	var index:=int(request.index);var parent:=int(request.parent);var mass:=int(request.mass)
	if index>60 or parent>index or mass>Stellar.MAX_MASS:return {}
	if request.body_count_byte>255 or request.star_count_byte>255:return {}
	if not request.get("system_name") is String or request.system_name.length()>21:return {}
	for character in request.system_name:
		if character.unicode_at(0)<32 or character.unicode_at(0)>126:return {}
	if not _load_tables():return {}
	var state:Dictionary={}
	for key in FIELDS:state[key]=int(request[key])
	# F881 tests capacity before touching records, names, counters or RNG.
	if index==60:
		state.ok=false;state.reason="capacity";state.return_word=65535;state.next_index=index
		return state
	for prior in range(index):
		if int(records[prior].decode_u16(8))>prior:return {}
	if mass>=Stellar.MIN_MASS:
		var stellar:Dictionary=_stellar.construct(records,request)
		if stellar.is_empty():return {}
		stellar.population_raw=state.population_raw;stellar.system_id=state.system_id
		return stellar
	# The lower-mass source path reads parent-1. It is only valid with a real
	# preceding parent record, not a fabricated low-mass root.
	if parent==0:return {}
	var parent_record:PackedByteArray=records[parent-1]
	if (int(parent_record[0x3f])&0x80)!=0:return _blocked(893)
	var name:=_parent_name(parent_record)
	# Distinguish a valid empty source name from an invalid unterminated/long one.
	if name.is_empty() and int(parent_record[38])!=0:return {}
	var bin:=0
	while int(_tables.mass_thresholds[bin])!=0 and mass>=int(_tables.mass_thresholds[bin]):bin+=1
	if bin>=23:return {}
	var callback:=int(_tables.callback_ids[bin])
	if callback!=0 and not callback in Classifier.CALLBACKS:return {}
	var body:PackedByteArray=records[index].duplicate()
	body.encode_u32(0x1c,int(_tables.light_outputs[bin]))
	body.encode_u16(0x0a,int(_tables.type_codes[bin])&65535)
	body.encode_u16(0x24,int(_tables.temperatures[bin])&65535)
	body.encode_u16(0x0c,int(_tables.model_indices[bin])&65535)
	state.body_count_byte=(state.body_count_byte+1)&255
	var depth_byte:=int(state.depth)&255
	if depth_byte==0:
		state.planet_counter=(state.planet_counter+1)&MASK
		if state.planet_counter<=9:name.append((state.planet_counter+0x30)&255)
		else:
			name.append(0x31);name.append((state.planet_counter+0x26)&255)
	elif depth_byte==1:
		state.moon_counter=(state.moon_counter+1)&MASK
		name.append((state.moon_counter+0x60)&255)
	else:
		state.third_counter=(state.third_counter+1)&MASK
		name.append((state.third_counter+0x30)&255)
	name.append(0)
	for offset in range(name.size()):body[38+offset]=name[offset]
	var working:=records.duplicate();working[index]=body
	var initialized:Dictionary=_initializer.construct(working,index,parent,int(state.multiplier),int(state.distance),mass,int(state.seed_a),int(state.seed_b),int(state.depth),int(state.counter))
	if initialized.is_empty():return {}
	body=initialized.record;state.counter=int(initialized.counter)
	if callback!=0:
		var classified:Dictionary=_classifier.classify(body,callback,mass,int(state.population_raw),int(state.system_id),int(state.seed_a),int(state.seed_b))
		if classified.is_empty():return {}
		if not classified.get("ok",false):return _blocked(int(classified.helper_id))
		body=classified.record;state.seed_a=int(classified.seed_a);state.seed_b=int(classified.seed_b)
	state.ok=true;state.record=body;state.return_word=int(_tables.return_words[bin])&65535;state.mass_bin=bin;state.next_index=index+1
	return state
