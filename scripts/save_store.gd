extends RefCounted
# New reconstruction: two independent atomic slots, hash exact serialized bytes.
const SCHEMA:="starfrontier-rebuild-save-v1"
var directory:="user://saves"
var sequence:=0
var last_error:=""
func _digest(body:String)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(body.to_utf8_buffer());return hash.finish().hex_encode()
func encode(payload:Dictionary,generation:int)->String:
	var body:=JSON.stringify(payload)
	return JSON.stringify({"schema":SCHEMA,"generation":generation,"body":body,"sha256":_digest(body)})
func decode(text:String)->Dictionary:
	var parsed:Variant=JSON.parse_string(text)
	if not parsed is Dictionary or parsed.get("schema")!=SCHEMA or not parsed.get("body") is String or not parsed.get("sha256") is String:return {}
	var generation:Variant=parsed.get("generation")
	if not (generation is int or generation is float) or not is_finite(float(generation)) or generation<0 or generation>1000000000 or generation!=floorf(generation):return {}
	if parsed.body.length()>2000000 or _digest(parsed.body)!=parsed.sha256:return {}
	var payload:Variant=JSON.parse_string(parsed.body)
	if not payload is Dictionary:return {}
	return {"generation":int(generation),"payload":payload}
func candidates()->Array:
	var found:Array=[]
	for slot in range(2):
		var path:=directory+"/slot%d.json"%slot
		if not FileAccess.file_exists(path):continue
		var entry:=decode(FileAccess.get_file_as_string(path))
		if not entry.is_empty():found.append(entry)
	found.sort_custom(func(a:Dictionary,b:Dictionary):return int(a.generation)>int(b.generation))
	return found
func load_valid(validator:Callable)->Dictionary:
	last_error=""
	for entry in candidates():
		var restored:Variant=validator.call(entry.payload)
		if restored is Dictionary and not restored.is_empty():sequence=int(entry.generation);return restored
	return {}
func write(payload:Dictionary)->bool:
	last_error=""
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:last_error="Не удалось создать каталог сохранений.";return false
	var next:=sequence+1;var target:=directory+"/slot%d.json"%(next%2);var temporary:=target+".tmp"
	var content:=encode(payload,next)
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:last_error="Не удалось записать сохранение.";return false
	file.store_string(content);file.flush();var failed:=file.get_error()!=OK;file.close()
	if failed or decode(FileAccess.get_file_as_string(temporary)).is_empty():last_error="Проверка записанного сохранения не пройдена.";return false
	if DirAccess.rename_absolute(temporary,target)!=OK:last_error="Не удалось заменить файл сохранения.";return false
	sequence=next;return true
