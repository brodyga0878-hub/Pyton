extends RefCounted
# Original F881 composition for stellar and bounded ordinal-named bodies.
# Unported naming/settlement paths reject atomically; this is not a galaxy.
const Stellar=preload("res://scripts/stellar_body_factory.gd")
const Initializer=preload("res://scripts/body_initializer.gd")
const Classifier=preload("res://scripts/planetary_classifier.gd")
const FullClassifier=preload("res://scripts/source_body_classifier_full.gd")
const FullNames=preload("res://scripts/source_planet_names.gd")
const PackedMath=preload("res://scripts/ffe_math.gd")
const SOURCE_SHA:=Stellar.SOURCE_SHA
const MASK:=0xffffffff
const FIELDS:=["index","parent","multiplier","distance","mass","seed_a","seed_b","depth","counter","body_count_byte","star_count_byte","planet_counter","moon_counter","third_counter","population_raw","system_id"]
var _stellar:=Stellar.new()
var _initializer:=Initializer.new()
var _classifier:=Classifier.new()
var _full_classifier:=FullClassifier.new()
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

static func _full_name(record:PackedByteArray)->PackedByteArray:
	var name:=PackedByteArray()
	for offset in range(38,68):
		if record[offset]==0:return name
		name.append(record[offset])
	return PackedByteArray()

static func _system_name_bytes(request:Dictionary)->PackedByteArray:
	if request.get("system_name_bytes") is PackedByteArray:
		var bytes:PackedByteArray=request.system_name_bytes
		if bytes.is_empty() or bytes[-1]!=0:return PackedByteArray()
		for i in range(bytes.size()-1):
			if bytes[i]==0:return PackedByteArray()
		return bytes.duplicate()
	if not request.get("system_name") is String:return PackedByteArray()
	var bytes:=str(request.system_name).to_ascii_buffer();bytes.append(0)
	return bytes

func initialize_full(records:Array,index:int,parent:int,multiplier:int,distance:int,mass:int,seed_a:int,seed_b:int,depth:int,counter:int)->Dictionary:
	# F881 itself retains its60-entry limit, but F877 can create a barycentre
	# after a callback appended past it. The new explicit bank has128records.
	if index<60:return _initializer.construct(records,index,parent,multiplier,distance,mass,seed_a,seed_b,depth,counter)
	if records.size()!=128 or index<0 or index>=128 or parent<0 or parent>index:return {}
	for value in [multiplier,distance,mass,seed_a,seed_b,depth,counter]:
		if not _u32(value):return {}
	for i in range(index+1):
		if not records[i] is PackedByteArray or records[i].size()!=68:return {}
		if i<index and int(records[i].decode_u16(8))>i:return {}
	var body:PackedByteArray=records[index].duplicate()
	var orbit:=PackedMath.fixed_multiply(multiplier,distance&65535)
	body.encode_u32(14,orbit)
	if orbit!=0:
		orbit=PackedMath.shift(PackedMath.from_uint(orbit),25);body.encode_u32(14,orbit)
		if parent!=0:
			var period_orbit:=orbit
			if records[parent-1].decode_u16(10)==0 and index-1<=parent:period_orbit=PackedMath.shift(period_orbit,1)
			body.encode_u32(20,PackedMath.period(period_orbit,int(records[parent-1].decode_u32(0))))
		else:body.encode_u32(20,0)
		body.encode_u16(18,seed_a&65535)
	body.encode_u32(4,seed_b);body.encode_u16(8,parent);body.encode_u32(0,PackedMath.shift(PackedMath.from_uint(mass),63));body.encode_u16(32,0)
	var rotated:=(((seed_a&65535)>>3)|((seed_a&65535)<<13))&65535
	var square:=(rotated*rotated)&MASK
	if square>=0x80000000:square-=0x100000000
	var inclination:=square>>20
	if parent!=0:inclination+=int(records[parent-1].decode_u16(66))
	body.encode_u16(34,inclination&65535)
	var orientation:=PackedMath.s16((seed_b&65535)*(seed_b&65535))>>17
	body.encode_u16(66,orientation&65535);body[62]=orientation&3;body[63]=depth&255
	if body.decode_u16(36)<1000:
		var total:=0;var current:=index;var path:=records.duplicate();path[index]=body
		while int(path[current].decode_u16(8))!=0:
			var next:=int(path[current].decode_u16(8))-1;var light:int=path[next].decode_u32(28)
			if light!=0:
				var intensity:=PackedMath.divide(PackedMath.shift(PackedMath.from_uint(light),50),int(path[current].decode_u32(14)))
				total=PackedMath.add(total,PackedMath.multiply(intensity,intensity))
			current=next
		body.encode_u16(36,(int(body.decode_u16(36))+PackedMath.to_integer(PackedMath.square_root(PackedMath.square_root(total))))&65535)
	return {"record":body,"counter":(counter+1)&MASK}

func construct_full(records:Array,request:Dictionary)->Dictionary:
	# Explicit full-domain opt-in. The published construct() contract and its
	# historical60-slot/unsupported-helper behavior above are unchanged.
	if records.size()!=128:return {}
	for body in records:
		if not body is PackedByteArray or body.size()!=68:return {}
	for key in FIELDS+["port_count_byte","orbital_count_byte","language"]:
		if not _u32(request.get(key)):return {}
	var state:Dictionary={}
	for key in FIELDS+["port_count_byte","orbital_count_byte","language"]:state[str(key)]=int(request[key])
	var index:=int(state.index);var parent:=int(state.parent);var mass:=int(state.mass)
	if index>=128 or parent>index or mass>Stellar.MAX_MASS or state.body_count_byte>255 or state.star_count_byte>255 or state.port_count_byte>255 or state.orbital_count_byte>255:return {}
	state.depth=int(state.depth)&255
	if not _load_tables():return {}
	if index>=60:
		state["ok"]=false;state["reason"]="capacity";state["return_word"]=65535;state["next_index"]=index;state["records"]=records.duplicate();return state
	for prior in range(index):
		if int(records[prior].decode_u16(8))>prior:return {}
	var name:=_system_name_bytes(request)
	if name.is_empty() or name.size()>28:return {}
	var bin:=0
	while int(_tables.mass_thresholds[bin])!=0 and mass>=int(_tables.mass_thresholds[bin]):bin+=1
	if bin>=23:return {}
	var callback:=int(_tables.callback_ids[bin]);var working:=records.duplicate();var body:PackedByteArray=working[index].duplicate()
	body.encode_u32(28,int(_tables.light_outputs[bin]));body.encode_u16(10,int(_tables.type_codes[bin])&65535);body.encode_u16(36,int(_tables.temperatures[bin])&65535);body.encode_u16(12,int(_tables.model_indices[bin])&65535)
	state.body_count_byte=(int(state.body_count_byte)+1)&255
	if mass>=Stellar.MIN_MASS:
		state.star_count_byte=(int(state.star_count_byte)+1)&255
		name.resize(name.size()-1);name.append(32)
		if parent!=0:name.append((int(state.star_count_byte)+0x40)&255)
		name.append(0)
	elif parent==0:return {}
	elif (int(records[parent-1][63])&0x80)!=0:
		body.encode_u32(4,int(state.seed_b))
		var renamed:=FullNames.rename(body,10,int(state.language))
		if renamed.is_empty():return {}
		body=renamed.record;name=PackedByteArray()
	else:
		name=_full_name(records[parent-1])
		if name.is_empty() and records[parent-1][38]!=0:return {}
		if state.depth==0:
			state.planet_counter=(int(state.planet_counter)+1)&MASK
			if state.planet_counter<=9:name.append((int(state.planet_counter)+0x30)&255)
			else:name.append(0x31);name.append((int(state.planet_counter)+0x26)&255)
		elif state.depth==1:state.moon_counter=(int(state.moon_counter)+1)&MASK;name.append((int(state.moon_counter)+0x60)&255)
		else:state.third_counter=(int(state.third_counter)+1)&MASK;name.append((int(state.third_counter)+0x30)&255)
		name.append(0)
	if name.size()>30:return {}
	for offset in range(name.size()):body[38+offset]=name[offset]
	working[index]=body
	var initialized:=initialize_full(working,index,parent,int(state.multiplier),int(state.distance),mass,int(state.seed_a),int(state.seed_b),int(state.depth),int(state.counter))
	if initialized.is_empty():return {}
	working[index]=initialized.record;state.counter=int(initialized.counter)
	if callback in FullClassifier.CALLBACKS:
		var classification_state:Dictionary={}
		for key in FullClassifier.FIELDS:classification_state[str(key)]=int(state[key]) if key!="ordinal_counter" else int(state.counter)
		var classified:=_full_classifier.classify(working,callback,mass,classification_state)
		if classified.is_empty() or not classified.get("ok",false):return classified
		working=classified.records;state.index=int(classified.index)
		for key in ["seed_a","seed_b","port_count_byte","orbital_count_byte"]:state[str(key)]=int(classified[key])
		state.counter=int(classified.ordinal_counter)
	elif callback!=0:
		# Checked remnant callbacks F888/F889/F890 operate on the original body.
		var remnant:=callback==888
		if callback in [889,890]:
			var seeds:=Stellar.rng_step(state.seed_a,state.seed_b);state.seed_a=seeds[0];state.seed_b=seeds[1]
			if (int(state.seed_a)&0x80000000)!=0:
				if callback==890:remnant=true
				else:
					seeds=Stellar.rng_step(state.seed_a,state.seed_b);state.seed_a=seeds[0];state.seed_b=seeds[1];remnant=(int(state.seed_a)&0x80000000)!=0
		if remnant and Stellar._signed32(int(state.counter))>2:
			body=working[index].duplicate();body.encode_u16(12,0x94);body.encode_u16(10,0x19);body.encode_u32(28,0x3e2);body.encode_u16(36,0x2c09);body.encode_u16(2,(int(body.decode_u16(2))-1)&65535);working[index]=body
	state.index=int(state.index)+1
	state["ok"]=true;state["records"]=working;state["record"]=working[index];state["next_index"]=int(state.index);state["return_word"]=int(_tables.return_words[bin])&65535;state["mass_bin"]=bin
	return state
