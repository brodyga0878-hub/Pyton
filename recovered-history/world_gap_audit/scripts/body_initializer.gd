extends RefCounted
# Exact packed-record F882 initialization; not climate, naming, or the complete F881 factory.
const Math=preload("res://scripts/ffe_math.gd")
const MASK:=0xffffffff
func construct(records:Array,index:int,parent:int,multiplier:int,distance:int,mass:int,seed_a:int,seed_b:int,depth:int,counter:int)->Dictionary:
	if index<0 or index>=60 or index>=records.size() or parent<0 or parent>index:return {}
	for value in [multiplier,distance,mass,seed_a,seed_b,depth,counter]:
		if value<0 or value>MASK:return {}
	for i in range(index+1):
		if not records[i] is PackedByteArray or records[i].size()!=68:return {}
		if i<index and int(records[i].decode_u16(8))>i:return {}
	var body:PackedByteArray=records[index].duplicate()
	var orbit:=Math.fixed_multiply(multiplier,distance&65535)
	body.encode_u32(0xe,orbit)
	if orbit!=0:
		orbit=Math.shift(Math.from_uint(orbit),25);body.encode_u32(0xe,orbit)
		if parent!=0:
			var parent_body:PackedByteArray=records[parent-1]
			var period_orbit:=orbit
			if parent_body.decode_u16(0xa)==0 and index-1<=parent:period_orbit=Math.shift(period_orbit,1)
			body.encode_u32(0x14,Math.period(period_orbit,int(parent_body.decode_u32(0))))
		else:body.encode_u32(0x14,0)
		body.encode_u16(0x12,seed_a&65535)
	body.encode_u32(4,seed_b)
	body.encode_u16(8,parent)
	body.encode_u32(0,Math.shift(Math.from_uint(mass),63))
	# Original movzx of the low product word makes eccentricity zero.
	body.encode_u16(0x20,0)
	var rotated:=(((seed_a&65535)>>3)|((seed_a&65535)<<13))&65535
	var square:=(rotated*rotated)&MASK
	if square>=0x80000000:square-=0x100000000
	var inclination:=square>>20
	if parent!=0:inclination+=int(records[parent-1].decode_u16(0x42))
	body.encode_u16(0x22,inclination&65535)
	var orientation:=Math.s16((seed_b&65535)*(seed_b&65535))>>17
	body.encode_u16(0x42,orientation&65535)
	body[0x3e]=orientation&3;body[0x3f]=depth&255
	if body.decode_u16(0x24)<1000:
		var total:=0;var current:=index
		var path:Array=records.duplicate();path[index]=body
		while int(path[current].decode_u16(8))!=0:
			var next:=int(path[current].decode_u16(8))-1
			var light:int=path[next].decode_u32(0x1c)
			if light!=0:
				var intensity:=Math.divide(Math.shift(Math.from_uint(light),50),int(path[current].decode_u32(0xe)))
				total=Math.add(total,Math.multiply(intensity,intensity))
			current=next
		var heating:=Math.to_integer(Math.square_root(Math.square_root(total)))
		body.encode_u16(0x24,(int(body.decode_u16(0x24))+heating)&65535)
	return {"record":body,"counter":(counter+1)&MASK}
