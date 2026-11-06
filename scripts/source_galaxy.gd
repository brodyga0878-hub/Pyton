extends RefCounted
# Original F841 sectors, F853 density, F856 positions and F861 RNG. No GUI.
# Full system composition and original text expansion are separate modules.
const Math=preload("res://scripts/ground_coordinates.gd")
const DATA_PATH:="res://data/ffe_galaxy.json"
const SOURCE_VARIANT:="ffe-d919566-f841-sectors-v1"
const MASK:=0xffffffff
const OBJECT_BYTES:=338
const STAR_BYTES:=384
var _tables:Dictionary={}

static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=MASK and value==floorf(float(value))
static func _coordinate(value:Variant)->bool:return _u32(value) and value<8192
static func _s32(value:int)->int:return Math.signed32(value)
static func _s8(value:int)->int:return (value&255)-256 if value&128 else value&255
static func _rol(value:int,amount:int)->int:return ((value<<amount)|(value>>(32-amount)))&MASK
static func _random(first:int,second:int)->PackedInt64Array:
	var total:=(first+second)&MASK
	return PackedInt64Array([(_rol(first,3)+total)&MASK,_rol(total,5)])

func _load()->bool:
	if not _tables.is_empty():return true
	if not FileAccess.file_exists(DATA_PATH):return false
	var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not raw is Dictionary or raw.get("source_sha256")!="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" or not raw.get("tables_hex") is Dictionary:return false
	for key in raw.tables_hex:
		if not raw.tables_hex[key] is String:return false
		_tables[str(key)]=str(raw.tables_hex[key]).hex_decode()
	for entry in [["6793",4],["6794",698],["6795",234],["6799",196],["6800",4],["6801",204],["6805",576],["6806",1],["6807",127],["6808",1],["6809",16383],["6810",32],["6811",32]]:
		if not _tables.has(entry[0]) or _tables[entry[0]].size()!=entry[1]:_tables.clear();return false
	var density:PackedByteArray=_tables["6806"].duplicate()
	for key in ["6807","6808","6809","6810","6811"]:density.append_array(_tables[key])
	_tables["density"]=density
	var vectors:PackedByteArray=_tables["6793"].duplicate();vectors.append_array(_tables["6794"]);_tables["vectors"]=vectors
	var starts:PackedByteArray=_tables["6800"].duplicate();starts.append_array(_tables["6801"]);_tables["starts"]=starts
	return true

func _handcrafted(x:int,y:int)->int:
	var key:=x|(y<<16)
	for i in range(49):
		if int(_tables["6799"].decode_u32(i*4))==key:return i
	return -1

func density(x:Variant,y:Variant)->int:
	if not _coordinate(x) or not _coordinate(y) or not _load():return -1
	var index:=_handcrafted(int(x),int(y))
	if index>=0:return (int(_tables["starts"].decode_u32((index+1)*4))-int(_tables["starts"].decode_u32(index*4)))<<10
	var eax:=int(x)<<3;var edx:=int(y)<<3
	index=((edx&0xfe00)+(eax>>7))>>2
	var grid:PackedByteArray=_tables.density
	var c:=int(grid[index]);var right:=int(grid[index+1]);var down:=int(grid[index+128]);var diagonal:=int(grid[index+129])
	eax=(eax&511)<<6;edx=(edx&511)<<6
	var value:=_s32((right-c)*eax+(down-c)*edx)
	var cross:=_s32(eax*edx)>>15
	value=_s32(value+_s32(cross*(diagonal-down-right+c)))
	value=_s32(_s32(value*2)+(c<<16))>>8
	var sample:=_s32(eax+value)
	sample=(_s32(sample^(_s32(eax*edx)>>15))>>5)&127
	var rate:=int(_tables["6805"].decode_u32(sample*4))
	return (_s32(value*rate)&MASK)>>16

static func position_q16(x:int,y:int,record:PackedByteArray)->PackedInt64Array:
	if x<0 or x>=8192 or y<0 or y>=8192 or record.size()!=6:return PackedInt64Array()
	var px:=((x<<16)&0xffff0000)+((_s8(record[4])*512+32768)&65535)
	var py:=((y<<16)&0xffff0000)+((_s8(record[3])*512+32768)&65535)
	var z:=(65535 if _s8(record[2])>0 else 0)|((-_s8(record[2])<<16)&MASK)
	return PackedInt64Array([_s32(px),_s32(py),-(_s32(z)>>7)])

func sector_raw(x:Variant,y:Variant,object:PackedByteArray,records:PackedByteArray,seed_a:Variant=0,seed_b:Variant=0)->Dictionary:
	if not _coordinate(x) or not _coordinate(y) or not _u32(seed_a) or not _u32(seed_b) or object.size()!=OBJECT_BYTES or records.size()!=STAR_BYTES or not _load():return {}
	var obj:=object.duplicate();var stars:=records.duplicate()
	var packed:=int(x)|(int(y)<<13)
	obj.encode_u32(0xa0,packed)
	var index:=_handcrafted(int(x),int(y));var count:=0
	var first:=int(seed_a);var second:=int(seed_b)
	var source_handcrafted:bool=index>=0 or (x==0 and y==0)
	if source_handcrafted:
		if index<0:index=49 # Original zero-coordinate fallback reads zero-length tail.
		obj.encode_u32(0x82,0xab)
		var start:=int(_tables.starts.decode_u32(index*4))
		count=int(_tables.starts.decode_u32((index+1)*4))-start
		for i in range(count):
			for j in range(6):stars[i*6+j]=_tables.vectors[(start+i)*6+j]
			obj.encode_u16(0xa6+i*2,int(_tables["6795"].decode_u16((start+i)*2)))
		# Empty handcrafted sectors skip the source count-store entirely.
		if count>0:obj.encode_u16(0xa4,count)
	else:
		count=mini(density(x,y)>>10,62);obj.encode_u16(0xa4,count)
		if count>0:
			obj.encode_u32(0x82,0xab)
			var xy:=int(x)|(int(y)<<16);first=_rol(xy,16);second=xy
			for _i in range(3):
				var rng:=_random(first,second);first=rng[0];second=rng[1]
			for i in range(count):
				var rng:=_random(first,second);first=rng[0];second=rng[1]
				stars[i*6]=9;stars[i*6+2]=(first>>16)&255
				stars[i*6+3]=(Math.signed32((first&0xff00)<<16)>>25)&255
				stars[i*6+4]=(_s8((first&0x1fe)>>1)>>1)&255
				obj[0xa7+i*2]=_tables["6810"][second&31];obj[0xa6+i*2]=_tables["6811"][(second>>16)&31]
	var systems:Array=[]
	for i in range(count):
		var record:=stars.slice(i*6,i*6+6)
		systems.append({"id":packed|(i<<26),"record":record,"position_q16":position_q16(int(x),int(y),record),"star_type":int(obj[0xa6+i*2]),"star_count_code":int(obj[0xa7+i*2])})
	return {"object":obj,"records":stars,"count":count,"seed_a_u32":first,"seed_b_u32":second,"systems":systems,"handcrafted":source_handcrafted,"source_variant":SOURCE_VARIANT}

func sector(x:Variant,y:Variant)->Dictionary:
	var object:=PackedByteArray();object.resize(OBJECT_BYTES)
	var records:=PackedByteArray();records.resize(STAR_BYTES)
	return sector_raw(x,y,object,records)

func system(id:Variant)->Dictionary:
	if not _u32(id):return {}
	var x:=int(id)&8191;var y:=(int(id)>>13)&8191;var index:=(int(id)>>26)&63
	var generated:=sector(x,y)
	if generated.is_empty() or index>=int(generated.count):return {}
	return generated.systems[index].duplicate(true)
