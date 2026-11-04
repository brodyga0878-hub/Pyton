extends RefCounted
# Exact unprojected F1470/F1478 vertex subset used by the audited world models.
# Source integer coordinates are kept until the final rendering adapter.
const SUPPORTED_KINDS:=[0,1,5,7,11,19]
# A deterministic diagnostic/effect snapshot, not the original per-model seed.
# Original F1476 shares global gameplay state; DrawModel never reseeds by UID.
const CHOSEN_STATIC_RANDOM_STATE:=[0x12345678,0x87654321]
var error:=""
var records:=PackedByteArray()
var matrix:Array=[]
var scale_shift:=0
var parameters:Array=[]
var entity_words:Array=[]
var anchors:Array=[]
var random_state:Array=[]
var cache:Dictionary={}
var visiting:Dictionary={}
static func s32(value:int)->int:
	var n:=value&0xffffffff
	return n-0x100000000 if n>=0x80000000 else n
static func s8(value:int)->int:
	var n:=value&255
	return n-256 if n>=128 else n
static func mul(a:int,b:int)->int:return s32((s32(a)*s32(b))>>31)
static func mean(a:int,b:int)->int:
	var n:=s32(a+b)
	return (n>>1)+(1 if n<0 and n&1 else 0)
func configure(raw:PackedByteArray,context:Dictionary)->bool:
	error="";cache.clear();visiting.clear();records=raw
	if raw.is_empty() or raw.size()%6 or raw.size()>384:return _fail("Invalid paired vertex stream")
	for i in range(0,raw.size(),6):
		if raw[i] not in SUPPORTED_KINDS:return _fail("Unsupported original vertex kind %d"%raw[i])
	matrix=context.get("matrix_q31",[2147483647,0,0,0,2147483647,0,0,0,2147483647]).duplicate()
	if matrix.size()!=9:return _fail("Invalid source matrix")
	scale_shift=int(context.get("scale_shift_raw",0))&31
	parameters=context.get("frame_parameters",[0,0,0,0,0,0,0,0])
	entity_words=context.get("entity_variables_u16",[])
	anchors=context.get("anchors_local_raw",[])
	random_state=context.get("random_state_u32",CHOSEN_STATIC_RANDOM_STATE).duplicate()
	if random_state.size()!=2:return _fail("Invalid source PRNG state")
	for i in range(2):random_state[i]=int(random_state[i])&0xffffffff
	return true
func _fail(reason:String)->bool:
	if error.is_empty():error=reason
	return false
func parameter(code:int)->int:
	var kind:=code&0xc0;var index:=code&63
	if kind==0:return index
	if kind==0x40:return index<<10
	var values:Array=entity_words if kind==0x80 else parameters
	if index>=values.size():_fail("Missing source parameter %02x"%code);return 0
	if values[index]==null:_fail("Uninitialized source parameter %02x"%code);return 0
	return int(values[index])&65535 if kind==0x80 else s32(int(values[index]))
func _random()->int:
	var old:int=int(random_state[0])&0xffffffff
	random_state[0]=(old+int(random_state[1]))&0xffffffff
	random_state[1]=((old<<16)|(old>>16))&0xffffffff
	return s32(int(random_state[1]))
func point(raw_index:int)->Array:
	var index:=s8(raw_index)
	if not error.is_empty():return []
	if cache.has(index):return cache[index]
	if index<0:
		if -index>anchors.size():_fail("Missing source parent vertex %d"%index);return []
		var anchor:Array=anchors[-index-1]
		if anchor.size()!=3:_fail("Invalid source parent vertex");return []
		return [s32(int(anchor[0])),s32(int(anchor[1])),s32(int(anchor[2]))]
	if index>=records.size()/3:_fail("Original vertex index out of range");return []
	if visiting.has(index) or visiting.size()>128:_fail("Cyclic original vertex reference");return []
	visiting[index]=true
	var offset:=(index/2)*6
	var kind:int=records[offset]
	var even:=index&~1;var parity:=index&1
	if kind==0 or kind==1:
		var source:Array=[]
		for k in range(3):source.append(s32(s8(records[offset+2+k])<<scale_shift))
		var first:Array=[];var mirror:Array=[]
		for axis in range(3):
			var value:=0
			for k in range(3):value=s32(value+mul(int(source[k]),int(matrix[k*3+axis])))
			first.append(value);mirror.append(s32(value-2*mul(int(source[0]),int(matrix[axis]))))
		cache[even]=first;cache[even+1]=mirror
	elif kind==5:
		var first:=point(records[offset+4]);var second:=point(records[offset+4]^1)
		if error.is_empty():
			cache[even]=[s32(-int(first[0])),s32(-int(first[1])),s32(-int(first[2]))]
			cache[even+1]=[s32(-int(second[0])),s32(-int(second[1])),s32(-int(second[2]))]
	elif kind==7:
		var first:=point(records[offset+4]);var second:=point(records[offset+4]^1)
		if error.is_empty():
			var displacement:Array=[]
			for k in range(3):displacement.append(_random()>>(records[offset+2]&31))
			var a:Array=[];var b:Array=[]
			for k in range(3):a.append(s32(int(first[k])+int(displacement[k])));b.append(s32(int(second[k])+int(displacement[2-k])))
			cache[even]=a;cache[even+1]=b
	elif kind==11 or kind==19:
		var first:=point(records[offset+3]^parity);var second:=point(records[offset+4]^parity)
		if error.is_empty():
			var value:Array=[]
			var amount:=s32(parameter(records[offset+2])<<14) if kind==19 else 0
			for k in range(3):value.append(mean(int(first[k]),int(second[k])) if kind==11 else s32(int(first[k])+2*mul(s32(int(second[k])-int(first[k])),amount)))
			cache[index]=value
	visiting.erase(index)
	return cache.get(index,[])
func all_points()->Dictionary:
	var points:Array=[]
	for i in range(records.size()/3):
		points.append(point(i).duplicate())
		if not error.is_empty():return {"ok":false,"error":error}
	return {"ok":true,"vertices_local_raw":points,"final_random_state_u32":random_state.duplicate()}
