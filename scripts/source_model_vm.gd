extends RefCounted
# Bounded original world-model VM. Raw integer geometry and source events are
# separate from modern materials, text rendering and world placement.
const Vertices=preload("res://scripts/source_model_vertices.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
static var assets:Dictionary={}
static var _underground_assets:Dictionary={}
static var _underground_checked:=false
static var _underground_mutex:=Mutex.new()
var error:=""
static func s16(value:int)->int:
	var n:=value&65535
	return n-65536 if n>=32768 else n
static func s32(value:int)->int:return Vertices.s32(value)
static func parameter(code:int,locals:Array,entity:Array,angle:=false)->Dictionary:
	var kind:=code&0xc0;var index:=code&63
	if kind==0 or kind==0x40:
		return {"ok":true,"value":(s16((code&127)<<9)|((code>>7)&511)) if angle else (index<<10 if kind==0x40 else index)}
	var values:Array=entity if kind==0x80 else locals
	if index>=values.size():return {"ok":false,"error":"Missing source model parameter %02x"%code}
	return {"ok":true,"value":int(values[index])&65535 if kind==0x80 else s32(int(values[index]))}
static func math(command:int,first_code:int,second_code:int,locals:Array,entity:Array)->Dictionary:
	var a:=parameter(first_code,locals,entity);var b:=parameter(second_code,locals,entity)
	if not a.ok:return a
	if not b.ok:return b
	var left:int=a.value;var right:int=b.value;var value:=0
	match (command>>4)&15:
		0:value=s32(left+right)
		1:value=s32(left-right)
		2:value=s32(left*right)
		3:
			if right==0:value=left
			elif left==(-2147483648) and right==(-1):return {"ok":false,"error":"Original model signed division trap"}
			else:
				value=absi(left)/absi(right)
				if (left<0)!=(right<0):value=-value
		4:value=(left&0xffffffff)>>(right&31)
		5:value=s32(left<<(right&31))
		6:value=left if (left&0xffffffff)>=(right&0xffffffff) else right
		7:value=left if (left&0xffffffff)<(right&0xffffffff) else s32(right-1)
		8:
			if right==0:return {"ok":false,"error":"Original model unsigned division trap"}
			value=((left<<16)&0xffffffff)/(right&0xffffffff)
		9:value=left>>(right&31)
		10:
			var index:=s32(left+right)
			if index<0 or index>=entity.size():return {"ok":false,"error":"Model entity lookup outside supplied state"}
			value=int(entity[index])&65535
		11:value=left if (left&0xffffffff)>=(right&0xffffffff) else 0
		12:value=left if (left&0xffffffff)<=(right&0xffffffff) else 0
		13:value=Vertices.mul(left,Ground.sin_q31(right))
		14:value=Vertices.mul(left,Ground.sin_q31(right+0x4000))
		15:value=left&right
	return {"ok":true,"value":value&65535,"destination":(command>>8)&7}
static func orientation(source:Array,source_parity:int,word:int)->Dictionary:
	if source.size()!=9:return {"ok":false,"error":"Invalid source orientation matrix"}
	var kind:=(word>>8)&7
	if kind==7:return {"ok":false,"error":"Unreviewed source orientation permutation 7"}
	var permutations:Array=[[0,1,2],[1,2,0],[2,0,1],[2,1,0],[1,0,2],[0,2,1],[0,1,2]]
	var result:Array=[0,0,0,0,0,0,0,0,0]
	var parity:int=s32(~source_parity) if kind in [3,4,5] else s32(source_parity)
	for axis in range(3):
		var negate:bool=(word&(0x2000>>axis))!=0
		var destination:int=permutations[kind][axis]
		for k in range(3):result[destination*3+k]=s32(-int(source[axis*3+k]) if negate else int(source[axis*3+k]))
		if negate:parity=s32(~parity)
	return {"ok":true,"matrix":result,"parity":parity}
static func branch(condition:bool,command:int,next_offset:int,active:=0x12345678)->Dictionary:
	if not condition:return {"offset":next_offset,"active":active}
	if command>>5==0:return {"offset":next_offset,"active":0}
	return {"offset":next_offset+(s16(command)>>5)*2,"active":active}
static func bit_condition(nonzero:bool,selector:int,bit_index:int,locals:Array,entity:Array)->Dictionary:
	var p:=parameter(selector,locals,entity)
	if not p.ok:return p
	var mask:=0xffffffff if bit_index==0 else (1<<((bit_index-1)&31))
	var tested:bool=((int(p.value)&0xffffffff)&mask)!=0
	return {"ok":true,"value":tested if nonzero else not tested}
static func auxiliary_rotation(matrix:Array,axis:int,cosine:int,sine:int)->Dictionary:
	if matrix.size()!=9 or axis<0 or axis>2:return {"ok":false,"error":"Invalid source auxiliary rotation"}
	var result:Array=matrix.duplicate();var first:int=[1,2,0][axis];var second:int=[2,0,1][axis]
	for k in range(3):
		result[first*3+k]=s32(Vertices.mul(int(matrix[first*3+k]),cosine)+Vertices.mul(int(matrix[second*3+k]),sine))
		result[second*3+k]=s32(Vertices.mul(s32(-int(matrix[first*3+k])),sine)+Vertices.mul(int(matrix[second*3+k]),cosine))
	return {"ok":true,"matrix":result}
static func material_base(code:int,local_rgb4:Array)->Dictionary:
	# F1692/F1694 byte arithmetic before the original normal/sun lighting.
	var texture:=(code&4095) if code>>14 else 0
	var rgb:Array=[0,0,0] if code>>14 else [(code>>8)&15,(code>>4)&15,code&15]
	if code&0x1000:
		for k in range(3):rgb[k]=(int(rgb[k])+int(local_rgb4[k]))&255
	return {"rgb4_base":rgb,"texture_index":texture,"textured":bool(code>>14),"unlit":bool(code&0x2000),"local_colour":bool(code&0x1000),"source_lighting_applied":false}
static func model(index:int)->Dictionary:
	if assets.is_empty():assets=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_world_models.json")).models
	if assets.has(str(index)):return assets[str(index)]
	# The original model96 closure is an optional append-only resource. Existing
	# open-city/station assets keep their exact records and lookup precedence.
	if not _underground_checked:
		_underground_mutex.lock()
		if not _underground_checked:
			var path:="res://data/ffe_underground_models.json"
			if FileAccess.file_exists(path):
				var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
				if parsed is Dictionary and parsed.get("schema")==1 and parsed.get("source_sha256")=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and parsed.get("models") is Dictionary:_underground_assets=parsed.models
			_underground_checked=true
		_underground_mutex.unlock()
	return _underground_assets.get(str(index),{})
