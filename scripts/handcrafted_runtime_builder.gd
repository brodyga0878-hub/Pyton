extends RefCounted
# Exact bounded F878 handcrafted suffix. Input templates are F873/F874/F875
# records; the result is the packed record domain consumed by F880.
# SI physics, object allocation and procedural system generation are separate.
const Math=preload("res://scripts/ffe_math.gd")
const CAPACITY:=60
const RECORD_BYTES:=68
const COUNTS:=["body_count_byte","port_count_byte","orbital_port_count_byte"]
const COPIED_FIELDS:=[[4,4],[8,2],[10,2],[12,2],[18,2],[32,2],[34,2],[36,2],[58,2],[60,2],[62,1],[66,2]]

static func _byte(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=255 and value==floorf(value)

static func build(templates:Array,destination:Array=[],initial_counts:Dictionary={})->Dictionary:
	# The original suffix does not check capacity. Reserve one of its sixty
	# destination records for its four-byte sentinel, and validate before writes.
	if templates.size()>=CAPACITY:return {}
	if not destination.is_empty() and destination.size()!=CAPACITY:return {}
	for record in destination:
		if not record is PackedByteArray or record.size()!=RECORD_BYTES:return {}
	var counts:Dictionary={}
	for key in COUNTS:
		var value:Variant=initial_counts.get(key,0)
		if not _byte(value):return {}
		counts[key]=int(value)
	for index in range(templates.size()):
		var record:Variant=templates[index]
		if not record is PackedByteArray or record.size()!=RECORD_BYTES:return {}
		if record.decode_u32(0)==0 or record.decode_u16(8)>index:return {}
		if record.decode_u16(10)!=35:
			var terminated:=false
			for offset in range(38,62):
				if record[offset]==0:terminated=true;break
			if not terminated:return {}
	var records:Array=[]
	for index in range(CAPACITY):
		var record:=PackedByteArray()
		if destination.is_empty():record.resize(RECORD_BYTES)
		else:record=destination[index].duplicate()
		records.append(record)
	for index in range(templates.size()):
		var source:PackedByteArray=templates[index]
		var type_code:=int(source.decode_u16(10))
		if type_code==35:
			records[index]=source.duplicate()
			counts.port_count_byte=(int(counts.port_count_byte)+1)&255
			continue
		var body:PackedByteArray=records[index]
		body.encode_u32(0,Math.shift(Math.from_uint((int(source.decode_u32(0))-1)&0xffffffff),63))
		for field in COPIED_FIELDS:
			for offset in range(int(field[0]),int(field[0])+int(field[1])):body[offset]=source[offset]
		var orbit:=Math.shift(Math.from_uint(int(source.decode_u32(14))),25)
		body.encode_u32(14,orbit)
		var parent:=int(body.decode_u16(8))
		body.encode_u32(20,Math.period(orbit,int(records[parent-1].decode_u32(0))) if parent!=0 else 0)
		# Source strcpy happens after the other writes, including 0x3a/0x3c.
		for offset in range(38,62):
			body[offset]=source[offset]
			if source[offset]==0:break
		records[index]=body
		counts.body_count_byte=(int(counts.body_count_byte)+1)&255
		if type_code>=32 and type_code<=34:
			counts.port_count_byte=(int(counts.port_count_byte)+1)&255
			counts.orbital_port_count_byte=(int(counts.orbital_port_count_byte)+1)&255
	records[templates.size()].encode_u32(0,0)
	return {"ok":true,"records":records,"count":templates.size(),"next_index":templates.size(),"body_count_byte":counts.body_count_byte,"port_count_byte":counts.port_count_byte,"orbital_port_count_byte":counts.orbital_port_count_byte}
