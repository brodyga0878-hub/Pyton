func _white_dwarf()->void:
	var signed:=counter if counter<0x80000000 else counter-0x100000000
	if signed<=2:return
	_classify(0x94,0x19);records[index].encode_u32(0x1c,0x3e2);_set_temperature(0x2c09)
	records[index].encode_u32(0,Math.shift(int(records[index].decode_u32(0)),-1))
func _append(template:int)->bool:
	if index>=59:failed=true;return false
	index+=1;records[index]=str(data.templates[str(template)]).hex_decode()
	return true
func _ground(offset:int,rate:int)->void:
	if settlement_count>=18:return
	var amount:=mini(((((b&65535)*rate)&MASK)>>16),3)+1
	var parent:=index+1;var local_a:=a;var local_b:=b
	for i in range(amount):
		local_b=(local_b+local_a)&MASK;local_a=(rol(local_a,5)+local_b)&MASK;local_a=(rol(local_a,16)+local_b)&MASK
		if not _append(16):return
		var row:PackedByteArray=records[index]
		row.encode_u32(0,Math.pack(0,0x39));row.encode_u16(8,parent);row.encode_u32(4,local_a)
		counter=(counter+1)&MASK
		row.encode_u16(0x22,int(data.tables.ground_coordinates[(counter&15)*2])&65535)
		row.encode_u16(0x12,int(data.tables.ground_coordinates[(counter&15)*2+1])&65535)
		records[index]=row;_name(index,6)
		var model_index:=((development>>5)&7)+offset+((local_a&0x30000)>>16)
		if model_index<0 or model_index>=data.tables.ground_models.size():failed=true;return
		records[index].encode_u16(0xc,int(data.tables.ground_models[model_index])&65535)
		settlement_count+=1
		if settlement_count>=18:return
