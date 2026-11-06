extends RefCounted
# Complete opt-in F877/F878/F896/F897 hierarchy. Records are the original
# packed F878 output domain; the legacy sixty-record factories remain separate.
const Factory=preload("res://scripts/source_body_factory.gd")
const Stellar=preload("res://scripts/stellar_body_factory.gd")
const Math=preload("res://scripts/ffe_math.gd")
const Metadata=preload("res://scripts/source_system_metadata.gd")
const Handcrafted=preload("res://scripts/handcrafted_runtime_builder.gd")
const MASK:=0xffffffff
const CAPACITY:=128
const SOURCE_VARIANT:="jjffe-7e54034-full-system-binary-light-fix"
const GLOBAL_FIELDS:=["index","seed_a","seed_b","depth","counter","body_count_byte","star_count_byte","planet_counter","moon_counter","third_counter","port_count_byte","orbital_count_byte","language","star_quota","largest_mass","population_raw","system_id"]
var _factory:=Factory.new()
var _data:Dictionary={}
var _failed:=false
var _steps:=0

static func empty_bank()->Array:
 var records:Array=[]
 for i in range(CAPACITY):
  var record:=PackedByteArray();record.resize(68);records.append(record)
 return records

func _load()->bool:
 if not _data.is_empty():return true
 if not Metadata._load():return false
 _data=Metadata._data
 return _data.get("orbit_lookup_u32") is Array and _data.orbit_lookup_u32.size()==257

static func _bank_valid(records:Array)->bool:
 if records.size()!=CAPACITY:return false
 for record in records:
  if not record is PackedByteArray or record.size()!=68:return false
 return true

static func _name(request:Dictionary)->PackedByteArray:
 var name:=Factory._system_name_bytes(request)
 if name.is_empty() or name.size()>28:return PackedByteArray()
 return name

func orbit_lookup(value:Variant)->int:
 if not Factory._u32(value) or not _load():return -1
 var word:=int(value)&65535
 return 65535 if word>0x4000 else int(_data.orbit_lookup_u32[word>>6])&65535

func _rng(state:Dictionary)->int:
 var seeds:=Stellar.rng_step(int(state.seed_a),int(state.seed_b))
 state.seed_a=seeds[0];state.seed_b=seeds[1];return int(seeds[0])

func _body(state:Dictionary,mass:int,parent:int,multiplier:int,distance:int,name:PackedByteArray,ordinals:Dictionary)->int:
 var request:=state.duplicate()
 request.mass=mass;request.parent=parent;request.multiplier=multiplier;request.distance=distance;request.system_name_bytes=name
 for key in ordinals:request[key]=ordinals[key]
 var result:=_factory.construct_full(state.records,request)
 if result.is_empty() or (not result.get("ok",false) and result.get("reason")!="capacity"):
  _failed=true;return 65535
 state.records=result.records
 for key in ["index","seed_a","seed_b","depth","counter","body_count_byte","star_count_byte","port_count_byte","orbital_count_byte"]:state[key]=result[key]
 for key in ordinals:ordinals[key]=result[key]
 return int(result.return_word)

func _binary(state:Dictionary,parent:int,mass:int,multiplier:int,distance:int,second:int,name:PackedByteArray)->int:
 var ordinals:={"planet_counter":0,"moon_counter":0,"third_counter":0}
 if mass>=0xffffffef or (mass>=0x0a21fe80 and mass<0x0a6e49c0):
  _body(state,mass,parent,multiplier,distance,name,ordinals)
  _body(state,mass>>2,int(state.index),multiplier,second,name,ordinals)
 else:
  _rng(state)
  var extra:=(((Math.s16((int(state.seed_a)&65535)|0x8000)>>2)&65535)*(mass>>16))&MASK
  extra=maxi(extra,Stellar.MIN_MASS)
  var index:=int(state.index)
  var initialized:=_factory.initialize_full(state.records,index,parent,multiplier,distance,(mass+extra)&MASK,int(state.seed_a),int(state.seed_b),int(state.depth),int(state.counter))
  if initialized.is_empty():_failed=true;return 65535
  var body:PackedByteArray=initialized.record
  state.counter=int(initialized.counter);body.encode_u16(10,0);body.encode_u16(12,23)
  for i in range(name.size()):body[38+i]=name[i]
  var length:=name.size()-1
  var at:=mini(length,11)
  body[38+at]=46 if length>11 else 32;at+=1
  body[38+at]=(int(state.star_count_byte)+65)&255;at+=1;body[38+at]=44;at+=1
  body[38+at]=(int(state.star_count_byte)+66)&255;at+=1;body[38+at]=0
  state.records[index]=body;state.index=index+1
  _body(state,mass,index+1,multiplier,second,name,ordinals)
  state.records[int(state.index)-1].encode_u16(18,0)
  _body(state,extra,index+1,multiplier,second,name,ordinals)
  state.records[int(state.index)-1].encode_u16(18,0x7fff)
  # This is the explicit JJFFE binary-light correction, including its exact
  # index-relative writes when F881 has reached the original sixty-entry gate.
  var count:=int(state.index)
  state.records[count-3].encode_u32(28,(int(state.records[count-1].decode_u32(28))+int(state.records[count-2].decode_u32(28)))&MASK)
 return (second<<3)&65535

func _children(state:Dictionary,parent:int,random_value:int,start_radius:int,mass_limit:int,mass_divisor:int,name:PackedByteArray,ordinals:Dictionary,level:int=0)->void:
 if _failed:return
 # A validation guard rejects the entire candidate; valid source controls do
 # not reach it. Source capacity and RNG behavior are not changed by this guard.
 if level>64:_failed=true;return
 var limit:=MASK if mass_limit>0x7fffffff else (mass_limit*2)&MASK
 var previous:=orbit_lookup(start_radius);var spacing:=0;var radius:=start_radius&65535
 while true:
  _steps+=1
  if _steps>1000000:_failed=true;return
  spacing+=radius
  if spacing>=65536:return
  var random:=(_rng(state)&65535)>>3;random+=(random_value&65535)
  var term:=radius if random>=65536 else ((radius*random)&MASK)>>16
  spacing=(radius>>2)+(radius>>3)+term
  if radius+spacing>=65536:continue
  var square:=_rng(state)&65535;square=((square*square)&MASK)>>16;square=((square*square)&MASK)>>16
  var lookup:=orbit_lookup((radius+spacing)&65535)
  var part:=((((lookup-previous)&MASK)*square)&MASK)>>16
  previous=(previous+part)&65535
  var mass:=Math.fixed_multiply(mass_divisor,part&65535)
  if mass<=32:radius=(radius+spacing)&65535;continue
  if mass<15000:mass>>=3
  var entry:=int(state.index);var returned:=0
  if mass>Stellar.MIN_MASS and int(state.star_quota)>1:
   mass=mini(mass,int(state.largest_mass)>>1);_rng(state)
   _binary(state,parent,mass,limit,((spacing>>1)+radius)&65535,(int(state.seed_b)&65535)>>11,name)
   state.star_quota=(int(state.star_quota)-2)&255;returned=0x3000;mass>>=2
  else:
   if mass>Stellar.MIN_MASS:
    if int(state.star_quota)!=0:
     state.star_quota=(int(state.star_quota)-1)&255
     if mass>(int(state.largest_mass)>>1):mass=maxi(Stellar.MIN_MASS,int(state.largest_mass)>>1)
    else:mass=((_rng(state)&65535)*259)&MASK
   returned=_body(state,mass,parent,limit,((spacing>>1)+radius)&65535,name,ordinals)
  if _failed:return
  if mass<=15000:mass=(mass<<3)&MASK
  var child_limit:=mini(mass,limit>>6)
  var saved_a:=int(state.seed_a);var saved_b:=int(state.seed_b);var saved_depth:=int(state.depth)
  state.depth=0 if mass>Stellar.MIN_MASS else (saved_depth+1)&255
  var child_name:=Factory._full_name(state.records[entry]);child_name.append(0)
  var next_random:=_rng(state)
  _children(state,entry+1,next_random,returned,child_limit,mass>>7,child_name,ordinals.duplicate(),level+1)
  state.seed_a=saved_a;state.seed_b=saved_b;state.depth=saved_depth
  if _failed:return
  radius=(radius+spacing)&65535

func _prepare(records:Array,request:Dictionary)->Dictionary:
 if not _bank_valid(records) or not _load():return {}
 var state:Dictionary={}
 for key in GLOBAL_FIELDS:
  if not Factory._u32(request.get(key)):return {}
  state[key]=int(request[key])
 if state.index>=128:return {}
 for key in ["body_count_byte","star_count_byte","port_count_byte","orbital_count_byte","star_quota"]:
  if state[key]>255:return {}
 state.depth=int(state.depth)&255
 state.records=records.duplicate();_failed=false;_steps=0;return state

func construct_binary(records:Array,request:Dictionary)->Dictionary:
 var state:=_prepare(records,request);var name:=_name(request)
 if state.is_empty() or name.is_empty():return {}
 for key in ["parent","mass","multiplier","distance","secondary_distance"]:
  if not Factory._u32(request.get(key)):return {}
 if int(request.parent)>int(state.index) or int(request.mass)<Stellar.MIN_MASS:return {}
 state.return_word=_binary(state,int(request.parent),int(request.mass),int(request.multiplier),int(request.distance),int(request.secondary_distance),name)
 if _failed:return {}
 state.ok=true;state.source_variant=SOURCE_VARIANT;return state

func construct_children(records:Array,request:Dictionary)->Dictionary:
 var state:=_prepare(records,request);var name:=_name(request)
 if state.is_empty() or name.is_empty():return {}
 for key in ["parent","random_value","start_radius","mass_limit","mass_divisor"]:
  if not Factory._u32(request.get(key)):return {}
 if int(request.parent)>int(state.index) or (int(request.start_radius)&65535)==0:return {}
 var ordinals:={"planet_counter":state.planet_counter,"moon_counter":state.moon_counter,"third_counter":state.third_counter}
 _children(state,int(request.parent),int(request.random_value),int(request.start_radius),int(request.mass_limit),int(request.mass_divisor),name,ordinals)
 if _failed:return {}
 state.return_word=0;state.ok=true;state.source_variant=SOURCE_VARIANT;return state

func build(request:Dictionary,destination:Array=[])->Dictionary:
 if not _load():return {}
 for key in ["seed_a","mass","num_stars","system_id","population_raw"]:
  if not Factory._u32(request.get(key)):return {}
 var name:=_name(request)
 if name.is_empty() or (not destination.is_empty() and not _bank_valid(destination)):return {}
 for key in ["initial_seed_a","initial_seed_b","initial_star_quota"]:
  if request.has(key) and not Factory._u32(request[key]):return {}
 if int(request.get("initial_star_quota",0))>255:return {}
 if int(request.seed_a)!=0 and (int(request.mass)<Stellar.MIN_MASS or int(request.mass)>Stellar.MAX_MASS):return {}
 var metadata:=Metadata.query(request.system_id)
 if metadata.is_empty():return {}
 var records:=empty_bank() if destination.is_empty() else destination.duplicate()
 var state:={"records":records,"index":0,"seed_a":int(request.seed_a),"seed_b":0,"depth":0,"counter":0,"body_count_byte":0,"star_count_byte":0,"planet_counter":0,"moon_counter":0,"third_counter":0,"port_count_byte":0,"orbital_count_byte":0,"language":int(metadata.language),"star_quota":int(request.num_stars)&255,"largest_mass":int(request.mass),"population_raw":int(request.population_raw),"system_id":int(request.system_id)}
 _failed=false;_steps=0
 if int(request.seed_a)==0:
  # The source's handcrafted branch preserves its incoming global RNG words;
  # explicit diagnostic state is optional and does not enter system parameters.
  state.seed_a=int(request.get("initial_seed_a",0));state.seed_b=int(request.get("initial_seed_b",0));state.star_quota=int(request.get("initial_star_quota",0))
  var mapping:=str(_data.handcrafted_mapping_hex).hex_decode();var global_index:=143
  for at in range(0,mapping.size(),8):
   var id:=int(mapping.decode_u32(at))
   if id==0:break
   if id==int(request.system_id):global_index=int(mapping.decode_u32(at+4));break
  var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_handcrafted_records.json"))
  if not raw is Dictionary or raw.get("source_sha256")!=Metadata.SOURCE_SHA:return {}
  var templates:Array=[]
  while raw.records.has(str(global_index)):
   templates.append(str(raw.records[str(global_index)].record_hex).hex_decode());global_index+=1
  var converted:=Handcrafted.build(templates,records.slice(0,60))
  if converted.is_empty():return {}
  for i in range(60):records[i]=converted.records[i]
  state.index=int(converted.count);state.body_count_byte=int(converted.body_count_byte);state.port_count_byte=int(converted.port_count_byte);state.orbital_count_byte=int(converted.orbital_port_count_byte)
 else:
  state.seed_b=int(request.mass)
  var ordinals:={"planet_counter":0,"moon_counter":0,"third_counter":0};var returned:=0
  if int(request.num_stars)==0:
   returned=_body(state,int(request.mass),0,0,0,name,ordinals)
   if returned!=0:
    var random:=_rng(state)
    _children(state,1,random,returned,int(request.mass),int(request.mass)>>8,name,ordinals.duplicate())
  elif int(request.num_stars)==1:
   state.star_quota=(int(state.star_quota)-1)&255;_rng(state)
   var second:=(int(state.seed_b)&65535)>>3
   var limit:=MASK if ((int(request.mass)>>24)&0xe0)!=0 else (int(request.mass)<<3)&MASK
   returned=_binary(state,0,int(request.mass),limit,0,second,name)
   var random:=_rng(state)
   _children(state,1,random,returned,limit,int(request.mass)>>6,name,ordinals.duplicate())
  else:
   _rng(state);var second:=(int(state.seed_b)&65535)>>8
   _binary(state,0,int(request.mass),MASK,0,second,name)
   returned=(second<<4)&65535;state.star_quota=(int(state.star_quota)-1)&255
   var adjusted:=(int(request.mass)+0x081b3200)&MASK
   if int(state.star_quota)>2:adjusted=MASK
   var random:=(Math.s16((_rng(state)&65535)|0x8000)>>2)&MASK
   _children(state,1,random,returned,MASK,adjusted,name,ordinals.duplicate())
  if _failed or int(state.index)>=128:return {}
  state.records[int(state.index)].encode_u32(0,0)
 state.record_count=int(state.index);state.return_word=0;state.ok=true;state.source_variant=SOURCE_VARIANT;state.metadata=metadata
 return state
