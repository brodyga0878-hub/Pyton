extends Node
# Bounded offline bug-report collection. The caller decides whether to export.
const Recorder=preload("res://scripts/diagnostics_logger.gd")
const SCHEMA:="starfrontier-diagnostics-v1"
const MAX_TOTAL_BYTES:=4*1024*1024
const MAX_ARCHIVE_BYTES:=8*1024*1024
const MAX_LOG_BYTES:=256*1024
const MAX_SAVE_BYTES:=2*1024*1024
const MAX_REPORTS:=5
const CURRENT_EVENTS:="current-events.jsonl"
const PREVIOUS_EVENTS:="previous-events.jsonl"
const SESSION:="session.json"
const SETTINGS_KEYS:=["version","fps","quality","sensitivity","deadzone","invert_y","reading_size","orbital_gravity","show_fps"]
const OMIT_KEYS:=["password","passwd","secret","token","authorization","api_key","email","account","unique_id","device_id","backup_code","environment_variables"]
var directory:="user://diagnostics"
var reports_directory:="user://bug_reports"
var engine_logs_directory:="user://logs"
var last_error:=""
var _recorder:Logger
var _version:=""
var _session:Dictionary={}
var _previous_session:Dictionary={}
var _initialized:=false
var _building:=false
var _flush_timer:=0.0
var _report_counter:=0

func initialize(version:String)->bool:
	if _initialized:return true
	last_error=""
	if not _private_path(directory) or not _private_path(reports_directory) or not _private_path(engine_logs_directory):
		last_error="Недопустимый каталог диагностики.";return false
	if DirAccess.make_dir_recursive_absolute(directory)!=OK or DirAccess.make_dir_recursive_absolute(reports_directory)!=OK:
		last_error="Не удалось подготовить журнал диагностики.";return false
	_version=version.left(100)
	_previous_session=_read_previous_session()
	var current:=directory.path_join(CURRENT_EVENTS)
	var previous:=directory.path_join(PREVIOUS_EVENTS)
	if FileAccess.file_exists(current):
		var bytes:=_tail(current,MAX_LOG_BYTES)
		_write_atomic(previous,bytes)
	_session={"schema":SCHEMA,"version":_version,"started_utc":_utc(),"clean_exit":false,"last_phase":"running"}
	if not _write_atomic(directory.path_join(SESSION),JSON.stringify(_session).to_utf8_buffer()):
		last_error="Не удалось записать состояние диагностического сеанса.";return false
	_recorder=Recorder.new()
	_recorder.user_prefix=ProjectSettings.globalize_path("user://")
	_recorder.project_prefix=ProjectSettings.globalize_path("res://")
	OS.add_logger(_recorder);_initialized=true;set_process(true)
	record("session_started",{"version":_version,"previous_unclean":_previous_session.get("unclean",false)})
	flush()
	return true

func _private_path(path:String)->bool:
	return path.begins_with("user://") and not ".." in path.trim_prefix("user://").split("/") and not path.trim_prefix("user://").is_empty()

func _utc()->String:return Time.get_datetime_string_from_system(true)+"Z"

func _read_previous_session()->Dictionary:
	var path:=directory.path_join(SESSION)
	if not FileAccess.file_exists(path):return {"status":"none","unclean":false}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return {"status":"unreadable","unclean":false}
	if file.get_length()>65536:file.close();return {"status":"invalid_marker","unclean":false}
	var parser:=JSON.new();var parsed_ok:=parser.parse(_utf8_clean(file.get_buffer(file.get_length())))==OK;file.close()
	var value:Variant=parser.data if parsed_ok else null
	if not value is Dictionary or value.get("schema")!=SCHEMA or not value.get("clean_exit") is bool:
		return {"status":"invalid_marker","unclean":false}
	var result:={"status":"found","unclean":not value.clean_exit}
	for key in ["version","started_utc","ended_utc","last_phase","clean_exit"]:
		if value.has(key):result[key]=_safe_value(value[key],0)
	return result

func record(event:String,details:Dictionary={})->void:
	if not _initialized:return
	_recorder.append_entry({"kind":"game_event","event":_clean(event,120),"ticks_ms":Time.get_ticks_msec(),"details":_safe_value(details,0)})

func lifecycle(phase:String)->void:
	if not _initialized:return
	_session.last_phase=phase.left(50);_session.last_update_utc=_utc()
	record("lifecycle",{"phase":phase});flush()
	_write_atomic(directory.path_join(SESSION),JSON.stringify(_session).to_utf8_buffer())

func _process(dt:float)->void:
	if not _initialized:return
	_flush_timer+=dt
	if _flush_timer>=5.0:_flush_timer=0;flush()

func flush()->bool:
	if not _initialized:return false
	var snapshot:Dictionary=_recorder.snapshot()
	var content:String="\n".join(snapshot.lines)
	if not content.is_empty():content+="\n"
	return _write_atomic(directory.path_join(CURRENT_EVENTS),content.to_utf8_buffer())

func shutdown(clean:=true)->void:
	if not _initialized:return
	record("session_stopped",{"clean_exit":clean});flush()
	_session.clean_exit=clean;_session.ended_utc=_utc();_session.last_phase="stopped"
	_write_atomic(directory.path_join(SESSION),JSON.stringify(_session).to_utf8_buffer())
	OS.remove_logger(_recorder);_recorder=null;_initialized=false;set_process(false)

func _exit_tree()->void:shutdown(true)

func _clean(text:String,limit:=4000)->String:
	var result:=text.left(limit)
	result=result.replace(ProjectSettings.globalize_path("user://"),"user://")
	result=result.replace(ProjectSettings.globalize_path("res://"),"res://")
	return result

func _safe_value(value:Variant,depth:int)->Variant:
	if depth>8:return "[depth limit]"
	if value is Dictionary:
		var result:Dictionary={};var count:=0
		for key in value:
			if not (key is String or key is StringName):continue
			var lowered:String=str(key).to_lower()
			if lowered in OMIT_KEYS or lowered.ends_with("_token") or lowered.ends_with("_password"):continue
			result[_clean(str(key),80)]=_safe_value(value[key],depth+1);count+=1
			if count>=80:break
		return result
	if value is Array:
		var result:Array=[]
		for index in range(mini(value.size(),64)):result.append(_safe_value(value[index],depth+1))
		return result
	if value is String or value is StringName:return _clean(str(value),4000)
	if value is float:return value if is_finite(value) else "[non-finite]"
	if value is int or value is bool or value==null:return value
	if value is Vector2:return _safe_value([value.x,value.y],depth+1)
	if value is Vector3:return _safe_value([value.x,value.y,value.z],depth+1)
	return "[unsupported value]"

func _json_safe(value:Variant,depth:=0)->bool:
	if depth>24:return false
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName) or not _json_safe(value[key],depth+1):return false
		return true
	if value is Array:
		for item in value:
			if not _json_safe(item,depth+1):return false
		return true
	return value==null or value is String or value is StringName or value is int or value is bool or (value is float and is_finite(value))

func _utf8_clean(bytes:PackedByteArray)->String:
	# Replace invalid sequences before String decoding, which otherwise logs
	# Unicode parser errors while trying to collect an already damaged log.
	var clean:=PackedByteArray();var index:=0
	while index<bytes.size():
		var first:=int(bytes[index]);var count:=1
		if first>=0xc2 and first<=0xdf:count=2
		elif first>=0xe0 and first<=0xef:count=3
		elif first>=0xf0 and first<=0xf4:count=4
		elif first>=0x80:clean.append(63);index+=1;continue
		var valid:=index+count<=bytes.size()
		for offset in range(1,count):
			if index+offset>=bytes.size() or bytes[index+offset]<0x80 or bytes[index+offset]>0xbf:valid=false
		if valid and count==3:
			if first==0xe0 and bytes[index+1]<0xa0:valid=false
			if first==0xed and bytes[index+1]>=0xa0:valid=false
		if valid and count==4:
			if first==0xf0 and bytes[index+1]<0x90:valid=false
			if first==0xf4 and bytes[index+1]>=0x90:valid=false
		if not valid:clean.append(63);index+=1;continue
		for offset in range(count):clean.append(bytes[index+offset] if bytes[index+offset]!=0 else 63)
		index+=count
	return clean.get_string_from_utf8()

func _tail(path:String,limit:int)->PackedByteArray:
	if not _private_path(path):return PackedByteArray()
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return PackedByteArray()
	var start:=maxi(0,file.get_length()-limit);file.seek(start)
	var text:=_clean(_utf8_clean(file.get_buffer(mini(limit,file.get_length()))),limit)
	file.close()
	return _utf8_clean(text.to_utf8_buffer().slice(0,limit)).to_utf8_buffer()

func _write_atomic(path:String,bytes:PackedByteArray)->bool:
	if not _private_path(path):return false
	var temporary:=path+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:return false
	file.store_buffer(bytes);file.flush();var status:=file.get_error();file.close()
	if status!=OK:return false
	return DirAccess.rename_absolute(temporary,path)==OK

func _hash(bytes:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()

func _device_info()->Dictionary:
	var info:={"os":OS.get_name(),"os_version":OS.get_version(),"model":OS.get_model_name(),"processor_count":OS.get_processor_count(),"engine":Engine.get_version_info(),"debug_build":OS.is_debug_build(),"rendering_method":RenderingServer.get_current_rendering_method(),"rendering_driver":RenderingServer.get_current_rendering_driver_name(),"gpu":RenderingServer.get_video_adapter_name(),"gpu_vendor":RenderingServer.get_video_adapter_vendor(),"locale":OS.get_locale_language(),"window_size":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"static_memory_bytes":OS.get_static_memory_usage()}
	return _safe_value(info,0)

func _settings(context:Dictionary)->Dictionary:
	var settings:Variant=context.get("settings",{})
	if not settings is Dictionary:settings={}
	if settings.is_empty() and FileAccess.file_exists("user://device_settings.json"):
		var file:=FileAccess.open("user://device_settings.json",FileAccess.READ)
		if file!=null:
			if file.get_length()<=65536:
				var parser:=JSON.new()
				if parser.parse(_utf8_clean(file.get_buffer(file.get_length())))==OK and parser.data is Dictionary:settings=parser.data
			file.close()
	var result:Dictionary={}
	for key in SETTINGS_KEYS:
		if settings.has(key):result[key]=_safe_value(settings[key],0)
	return result

func build_report(description:String,context:Dictionary,include_save:=false,optional_snapshot:Dictionary={})->Dictionary:
	if not _initialized:return _failure("Диагностика ещё не запущена.")
	if not _private_path(directory) or not _private_path(reports_directory) or not _private_path(engine_logs_directory):return _failure("Недопустимый каталог диагностики.")
	if _building:return _failure("Отчёт уже создаётся.")
	_building=true
	var result:=_build_report(description,context,include_save,optional_snapshot)
	_building=false;return result

func _failure(message:String)->Dictionary:
	last_error=message;return {"ok":false,"error":message}

func _build_report(description:String,context:Dictionary,include_save:bool,snapshot:Dictionary)->Dictionary:
	last_error="";flush()
	if DirAccess.make_dir_recursive_absolute(reports_directory)!=OK:return _failure("Не удалось создать каталог отчётов.")
	var entries:Dictionary={}
	entries["description.txt"]=_clean(description,8000).to_utf8_buffer()
	entries["settings.json"]=JSON.stringify(_settings(context),"\t").to_utf8_buffer()
	for name in [CURRENT_EVENTS,PREVIOUS_EVENTS]:
		var path:=directory.path_join(name)
		if FileAccess.file_exists(path):entries["events/"+name]=_tail(path,MAX_LOG_BYTES)
	var logs:Array=[]
	if DirAccess.dir_exists_absolute(engine_logs_directory):
		for name in DirAccess.get_files_at(engine_logs_directory):
			if name.begins_with("godot") and name.ends_with(".log") and name.length()<=80 and name.is_valid_filename():
				logs.append({"name":name,"time":FileAccess.get_modified_time(engine_logs_directory.path_join(name))})
		logs.sort_custom(func(a:Dictionary,b:Dictionary):return int(a.time)>int(b.time))
	for index in range(mini(logs.size(),3)):
		entries["engine/"+str(logs[index].name)]=_tail(engine_logs_directory.path_join(logs[index].name),MAX_LOG_BYTES)
	if include_save:
		if snapshot.is_empty() or not _json_safe(snapshot):return _failure("Снимок полёта недоступен или имеет неподдерживаемый формат.")
		var save:=JSON.stringify(snapshot).to_utf8_buffer()
		if save.size()>MAX_SAVE_BYTES:return _failure("Снимок полёта слишком большой для отчёта.")
		entries["game-save.json"]=save
	var memory:Dictionary=_recorder.snapshot()
	var report:={"schema":SCHEMA,"version":_version,"created_utc":_utc(),"session":_session.duplicate(true),"previous_session":_previous_session.duplicate(true),"previous_session_note":"An unclosed session may mean a crash, force-stop, power loss or normal OS termination; it is not a crash diagnosis.","device":_device_info(),"context":_safe_value(context,0),"included_save":include_save,"captured_events_dropped":memory.dropped,"limits":{"uncompressed_bytes":MAX_TOTAL_BYTES,"log_tail_bytes":MAX_LOG_BYTES,"reports_retained":MAX_REPORTS},"collection":"Offline application diagnostics; no logcat/tombstone, environment, account credentials or device unique identifier collection."}
	entries["report.json"]=JSON.stringify(report,"\t").to_utf8_buffer()
	var total:=0;var manifest:Array=[]
	for name in entries:
		total+=entries[name].size();manifest.append({"name":name,"bytes":entries[name].size(),"sha256":_hash(entries[name])})
	entries["manifest.json"]=JSON.stringify({"schema":SCHEMA,"files":manifest,"total_payload_bytes":total},"\t").to_utf8_buffer()
	if total+entries["manifest.json"].size()>MAX_TOTAL_BYTES:return _failure("Отчёт превышает ограничение размера.")
	_report_counter+=1
	var filename:="StarFrontier-report-"+Time.get_datetime_string_from_system(true).replace(":","-")+"Z-%016d-%04d.zip"%[Time.get_ticks_usec(),_report_counter]
	var path:=reports_directory.path_join(filename);var temporary:=path+".tmp"
	if FileAccess.file_exists(path) or FileAccess.file_exists(temporary):return _failure("Не удалось выбрать свободное имя отчёта.")
	var packer:=ZIPPacker.new()
	if packer.open(temporary)!=OK:
		if FileAccess.file_exists(temporary):DirAccess.remove_absolute(temporary)
		return _failure("Не удалось открыть архив отчёта для записи.")
	packer.set_compression_level(6)
	var ok:=true
	for name in entries:
		if packer.start_file(name)!=OK:ok=false;break
		if packer.write_file(entries[name])!=OK:ok=false
		if packer.close_file()!=OK:ok=false
		if not ok:break
	if packer.close()!=OK:ok=false
	if not ok or not _verify_zip(temporary,entries):
		DirAccess.remove_absolute(temporary);return _failure("Проверка записанного архива не пройдена.")
	var archive:=FileAccess.open(temporary,FileAccess.READ)
	var size:=archive.get_length() if archive!=null else MAX_ARCHIVE_BYTES+1
	if archive!=null:archive.close()
	if size>MAX_ARCHIVE_BYTES:DirAccess.remove_absolute(temporary);return _failure("Архив превышает ограничение размера.")
	if DirAccess.rename_absolute(temporary,path)!=OK:DirAccess.remove_absolute(temporary);return _failure("Не удалось завершить запись архива.")
	_trim_reports(filename)
	record("report_built",{"filename":filename,"bytes":size,"included_save":include_save})
	return {"ok":true,"path":path,"absolute_path":ProjectSettings.globalize_path(path),"filename":filename,"report_bytes":size,"included_save":include_save,"error":""}

func _verify_zip(path:String,entries:Dictionary)->bool:
	var reader:=ZIPReader.new()
	if reader.open(path)!=OK:return false
	var ok:=reader.get_files().size()==entries.size()
	for name in entries:
		if not reader.file_exists(name) or reader.read_file(name)!=entries[name]:ok=false;break
	reader.close();return ok

func _trim_reports(protect_filename:String)->void:
	var files:Array=[]
	for name in DirAccess.get_files_at(reports_directory):
		if name!=protect_filename and name.begins_with("StarFrontier-report-") and name.ends_with(".zip"):
			files.append(name)
	files.sort()
	while files.size()>=MAX_REPORTS:DirAccess.remove_absolute(reports_directory.path_join(files.pop_front()))
