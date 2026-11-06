extends RefCounted
# Original F868/F869/F871 policy metadata. The pinned JJFFE table adds ten
# records to the uploaded DOS table; both source byte domains are documented.
const DATA_PATH:="res://data/ffe_system_metadata.json"
const SOURCE_VARIANT:="jjffe-7e54034-policy-table-with10-added-rows"
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const MASK:=0xffffffff
static var _data:Dictionary={}
static var _bytes:=PackedByteArray()

static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=MASK and float(value)==floorf(float(value))

static func _load()->bool:
	if not _data.is_empty():return true
	if not FileAccess.file_exists(DATA_PATH):return false
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or parsed.get("schema")!=1 or parsed.get("source_sha256")!=SOURCE_SHA or parsed.get("metadata_stride_bytes")!=54 or parsed.get("negative_rows")!=8:return false
	if parsed.get("metadata_variant")!="jjffe-policy-table-with10-added-rows" or not parsed.get("metadata_hex") is String:return false
	var raw:=str(parsed.metadata_hex).hex_decode()
	if raw.size()!=18808:return false
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
	if hash.finish().hex_encode()!=parsed.get("metadata_sha256",""):return false
	if not parsed.get("source_exception_ids") is Array or parsed.source_exception_ids.size()!=4:return false
	_data=parsed;_bytes=raw;return true

static func policy_index(system_id:Variant)->Dictionary:
	if not _u32(system_id) or not _load():return {}
	var id:=int(system_id);var count:=int(_data.handcoded_metadata_rows)
	for index in range(count):
		var known:=int(_bytes.decode_u32(432+index*54))
		if known==0:break
		if known==id:return {"index":index}
	var masked:=id&0x03ffffff
	for exception in _data.source_exception_ids:
		if masked==int(exception):return {"index":-1}
	var child:=(id>>26)&7
	var x:=absi((id&0x1fff)-0x1718)+child
	var y:=absi(((id>>13)&0x1fff)-0x1524)+child
	var distance:=(x*x+y*y)&MASK
	for entry in [[0x4c90,-8],[0x121,-7],[0x64,-6],[0x31,-5],[0x19,-4],[0x9,-3]]:
		if distance>=int(entry[0]):return {"index":int(entry[1])}
	return {"index":-2}

static func query(system_id:Variant,first_value:Variant=0,second_value:Variant=0)->Dictionary:
	if not _u32(first_value) or not _u32(second_value):return {}
	var selected:=policy_index(system_id)
	if selected.is_empty():return {}
	var index:=int(selected.index);var at:=(index+8)*54
	if at<0 or at+54>_bytes.size():return {}
	var values:=[int(_bytes.decode_u32(at+46)),int(_bytes.decode_u32(at+50)),int(_bytes[at+5]),int(_bytes[at+6]),int(_bytes[at+7]),int(_bytes[at+8]),int(_bytes[at+9]),int(_bytes.decode_u16(at+10))]
	var low:=int(_bytes[at+44])&15;var high:=int(_bytes[at+44])>>4
	var language:=int(_bytes.decode_u16(at+10))>>6
	var first_wins:=high>low or (high==low and language==1)
	return {"source_variant":SOURCE_VARIANT,"system_id":int(system_id),"policy_index":index,"F869_values":values,"nibble_low":low,"nibble_high":high,"nibble_max":maxi(low,high),"language":language,"first_value":int(first_value) if first_wins else int(second_value),"second_value":int(second_value) if first_wins else int(first_value)}

static func system_metadata(system_id:Variant,first_value:Variant=0,second_value:Variant=0)->Dictionary:
	return query(system_id,first_value,second_value)
