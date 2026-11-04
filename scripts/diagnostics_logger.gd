extends Logger
# Godot 4.6 logger. Callbacks may arrive on worker threads: only bounded memory
# operations occur here. No console output, scene calls, file writes or variables.
const MAX_LINES:=256
const MAX_BYTES:=262144
const MAX_LINE_CHARS:=4000
var mutex:=Mutex.new()
var _lines:Array[String]=[]
var _bytes:=0
var _dropped:=0
var user_prefix:=""
var project_prefix:=""

func clean_text(value:String,limit:=MAX_LINE_CHARS)->String:
	var text:=value.left(limit)
	if not user_prefix.is_empty():text=text.replace(user_prefix,"user://")
	if not project_prefix.is_empty():text=text.replace(project_prefix,"res://")
	return text

func append_entry(entry:Dictionary)->void:
	var line:=JSON.stringify(entry)
	if line.length()>MAX_LINE_CHARS*2:line=JSON.stringify({"kind":"entry_truncated","message":clean_text(line)})
	var count:=line.to_utf8_buffer().size()+1
	mutex.lock()
	_lines.append(line);_bytes+=count
	while _lines.size()>MAX_LINES or _bytes>MAX_BYTES:
		_bytes-=_lines.pop_front().to_utf8_buffer().size()+1;_dropped+=1
	mutex.unlock()

func snapshot()->Dictionary:
	mutex.lock()
	var result:={"lines":_lines.duplicate(),"dropped":_dropped,"bytes":_bytes}
	mutex.unlock()
	return result

func _log_message(message:String,error:bool)->void:
	append_entry({"kind":"stderr" if error else "stdout","ticks_ms":Time.get_ticks_msec(),"message":clean_text(message)})

func _log_error(function:String,file:String,line:int,code:String,rationale:String,_editor_notify:bool,error_type:int,script_backtraces:Array[ScriptBacktrace])->void:
	var frames:Array=[]
	for trace in script_backtraces:
		for index in range(mini(trace.get_frame_count(),24-frames.size())):
			frames.append({"function":clean_text(trace.get_frame_function(index),160),"file":clean_text(trace.get_frame_file(index),300),"line":trace.get_frame_line(index)})
		if frames.size()>=24:break
	append_entry({"kind":"engine_error","ticks_ms":Time.get_ticks_msec(),"error_type":error_type,"function":clean_text(function,160),"file":clean_text(file,300),"line":line,"code":clean_text(code),"message":clean_text(rationale),"frames":frames})
