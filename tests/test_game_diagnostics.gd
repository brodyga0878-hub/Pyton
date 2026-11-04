extends SceneTree
# Current diagnostics tests use only their own private directories. Real engine
# and GDScript errors are generated inside an isolated child Godot process.
const Diagnostics=preload("res://scripts/game_diagnostics.gd")
var checks:=0
var failures:=0
var base:="user://diagnostics-tests-%d"%Time.get_ticks_usec()
var context:={"settings":{"version":1,"fps":60,"quality":2,"password":"DO_NOT_EXPORT"},"flight":{"ship_id":"cobra","hull":97,"position":[1,2,3]},"secret":"DO_NOT_EXPORT","non_finite":INF}

func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=16:push_error(message)

func write(path:String,bytes:PackedByteArray)->void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()

func make_collector(folder:String)->Node:
	var collector:=Diagnostics.new();collector.directory=folder+"/state";collector.reports_directory=folder+"/reports";collector.engine_logs_directory=folder+"/logs";root.add_child(collector)
	return collector

func read_report(result:Dictionary)->Dictionary:
	var reader:=ZIPReader.new()
	check(result.get("ok",false) and reader.open(str(result.get("path","")))==OK,"Report is a real readable ZIP")
	var entries:Dictionary={}
	if not result.get("ok",false):return entries
	for name in reader.get_files():entries[name]=reader.read_file(name)
	reader.close();return entries

func json_entry(entries:Dictionary,name:String)->Dictionary:
	var value:Variant=JSON.parse_string(entries[name].get_string_from_utf8())
	return value if value is Dictionary else {}

func contents_and_limits()->void:
	var collector:=make_collector(base+"/main")
	check(collector.initialize("0.11.2-test"),"Explicit initialization succeeds")
	check(collector.initialize("different-version"),"Repeated initialization does not rotate or duplicate active loggers")
	var utf8:PackedByteArray=[0xff,0xc0,0x80,65,0xd0,0x9f,0]
	check(collector._utf8_clean(utf8)=="???AП?","Damaged UTF8 and NUL are repaired before decoding")
	var oversized:="Событие диагностики\n".repeat(22000).to_utf8_buffer();oversized.append_array(utf8)
	write(collector.engine_logs_directory+"/godot.log",oversized)
	write(collector.engine_logs_directory+"/godot-previous.log","Previous native log\n".to_utf8_buffer())
	write(collector.engine_logs_directory+"/unrelated.txt","PRIVATE_OTHER_FILE".to_utf8_buffer())
	write(collector.directory+"/credentials.key","PRIVATE_OTHER_FILE".to_utf8_buffer())
	collector.record("flight_issue",{"function":"test","password":"DO_NOT_EXPORT","offset":Vector3(1,2,3)})
	var report:Dictionary=collector.build_report("Ошибка после посадки",context)
	var entries:=read_report(report)
	check(report.absolute_path==ProjectSettings.globalize_path(report.path),"Exporter receives actual absolute source path")
	check(report.filename.ends_with(".zip") and report.report_bytes<=8*1024*1024,"Archive size and filename contract")
	check(entries.has("report.json") and entries.has("description.txt") and entries.has("manifest.json") and entries.has("settings.json"),"Required diagnostics files exist")
	check(not entries.has("game-save.json"),"Default archive excludes game progress")
	check(entries.has("events/current-events.jsonl") and entries.has("engine/godot.log"),"Current bounded custom and available native logs are collected")
	check(entries["description.txt"].get_string_from_utf8()=="Ошибка после посадки","Russian description remains readable")
	var metadata:=json_entry(entries,"report.json")
	check(metadata.version=="0.11.2-test" and metadata.schema=="starfrontier-diagnostics-v1","Actual initialized build and diagnostic schema are recorded")
	check(metadata.device.has("os") and metadata.device.has("engine") and metadata.device.has("rendering_method"),"Runtime device/engine/render facts are included")
	check(not metadata.device.has("unique_id") and not metadata.device.has("device_id"),"Device unique identifiers are not collected")
	check(metadata.context.non_finite=="[non-finite]","Non-finite state cannot produce invalid report JSON")
	var manifest:=json_entry(entries,"manifest.json");var total:=0
	for row in manifest.files:
		check(entries.has(row.name) and entries[row.name].size()==int(row.bytes) and collector._hash(entries[row.name])==row.sha256,"ZIP payload size/hash verified: "+row.name)
		total+=int(row.bytes)
	check(total==int(manifest.total_payload_bytes) and total+entries["manifest.json"].size()<=4*1024*1024,"Manifest and uncompressed budget match real payload")
	for name in entries:
		check(not name.begins_with("/") and not ".." in name.split("/"),"Archive entry cannot escape extraction folder: "+name)
		check(not "PRIVATE_OTHER_FILE" in entries[name].get_string_from_utf8() and not "DO_NOT_EXPORT" in entries[name].get_string_from_utf8(),"Unrelated files and credential fields absent: "+name)
	check(entries["engine/godot.log"].size()<=256*1024 and not entries["engine/godot.log"].get_string_from_utf8().is_empty(),"Oversized corrupt native log becomes a bounded readable tail")
	var snapshot:={"schema":"starfrontier-rebuild-game-v1","flight":{"credits":1234,"marker":"EXPLICIT_SNAPSHOT"}}
	var before:=JSON.stringify(snapshot)
	var saved:Dictionary=collector.build_report("С прогрессом",context,true,snapshot)
	var saved_entries:=read_report(saved)
	check(saved_entries.has("game-save.json") and saved_entries["game-save.json"].get_string_from_utf8()==before,"Explicit checkbox includes complete canonical supplied progress")
	check(JSON.stringify(snapshot)==before,"Report generation does not mutate original progress")
	check(not collector.build_report("",context,true,{}).ok,"Missing requested save is rejected")
	check(not collector.build_report("",context,true,{"bad":Vector3.ZERO}).ok,"Unsupported save values are rejected instead of silently corrupting progress")
	check(not collector.build_report("",context,true,{"big":"x".repeat(2*1024*1024)}).ok,"Oversized optional save is rejected within bounded memory")
	for index in range(1000):collector.record("flood",{"index":index,"message":"Ж".repeat(2000)})
	collector.flush()
	var queued:Dictionary=collector._recorder.snapshot()
	check(queued.lines.size()<=256 and queued.bytes<=262144 and queued.dropped>0,"Log flood remains bounded by entries and bytes")
	var file:=FileAccess.open(collector.directory+"/current-events.jsonl",FileAccess.READ)
	check(file!=null and file.get_length()<=262144,"Persisted custom event log is bounded too")
	if file!=null:file.close()
	write(collector.reports_directory+"/unrelated.zip","not ours".to_utf8_buffer())
	for index in range(7):
		var latest:Dictionary=collector.build_report("retention%d"%index,context)
		check(latest.ok and FileAccess.file_exists(latest.path),"New report survives retention: %d"%index)
	var own_reports:=0
	for name in DirAccess.get_files_at(collector.reports_directory):
		if name.begins_with("StarFrontier-report-") and name.ends_with(".zip"):own_reports+=1
	check(own_reports==5 and FileAccess.file_exists(collector.reports_directory+"/unrelated.zip"),"Only the latest five owned ZIPs are retained; other files survive")
	var original_reports:String=collector.reports_directory
	collector.reports_directory=base+"/obstruction";write(collector.reports_directory,"KEEP".to_utf8_buffer())
	check(not collector.build_report("blocked",context).ok and FileAccess.get_file_as_string(collector.reports_directory)=="KEEP","Write failure preserves existing obstructing file")
	collector.reports_directory="res://forbidden"
	check(not collector.build_report("",context).ok,"Runtime path changes cannot export outside private diagnostics")
	collector.reports_directory=original_reports;collector.shutdown(true);collector.queue_free()
	var invalid:=make_collector(base+"/invalid");invalid.directory="user://../escape"
	check(not invalid.initialize("test"),"Traversal directory is rejected before any writes")
	invalid.queue_free()

func previous_session()->void:
	var folder:=base+"/previous"
	var first:=make_collector(folder);check(first.initialize("first"),"First lifecycle starts")
	first.record("PREVIOUS_SESSION_MARKER");first.lifecycle("paused");first.shutdown(false);first.queue_free()
	var second:=make_collector(folder);check(second.initialize("second"),"Following lifecycle starts")
	var entries:=read_report(second.build_report("resume",context));var metadata:=json_entry(entries,"report.json")
	check(metadata.previous_session.unclean and metadata.previous_session.last_phase=="stopped","Unclosed prior session is detected without claiming a definite crash")
	check(entries.has("events/previous-events.jsonl") and "PREVIOUS_SESSION_MARKER" in entries["events/previous-events.jsonl"].get_string_from_utf8(),"Previous bounded session remains in report")
	second.shutdown(true);second.queue_free()
	var third:=make_collector(folder);check(third.initialize("third"),"Clean restart opens")
	check(not third._previous_session.unclean,"Clean prior shutdown is distinguished")
	third.shutdown();third.queue_free()
	write(folder+"/state/session.json","broken marker".to_utf8_buffer())
	var corrupt:=make_collector(folder);check(corrupt.initialize("after corrupt"),"Corrupt old marker cannot block diagnostics")
	check(corrupt._previous_session.status=="invalid_marker" and not corrupt._previous_session.unclean,"Corrupt marker is recorded as unknown, not a fabricated crash")
	corrupt.shutdown();corrupt.queue_free()

func actual_engine_capture()->void:
	var project:=base+"/engine-fixture"
	DirAccess.make_dir_recursive_absolute(project+"/scripts")
	for source in ["game_diagnostics.gd","diagnostics_logger.gd"]:
		write(project+"/scripts/"+source,FileAccess.get_file_as_bytes("res://scripts/"+source))
	write(project+"/project.godot",("config_version=5\n[application]\nconfig/name=\"DiagnosticsEngineFixture-%d\"\n[debug]\nfile_logging/enable_file_logging=false\n"%Time.get_ticks_usec()).to_utf8_buffer())
	var fixture:='''extends SceneTree
const Diagnostics=preload("res://scripts/game_diagnostics.gd")
func _initialize():call_deferred("run")
func trigger_script_error():
 var values:Dictionary={}
 return values["DIAGNOSTICS_EXPECTED_SCRIPT_KEY"]
func run():
 var diagnostic=Diagnostics.new();root.add_child(diagnostic)
 if not diagnostic.initialize("actual-engine-fixture"):quit(1);return
 push_error("DIAGNOSTICS_EXPECTED_ENGINE_ERROR")
 trigger_script_error()
 diagnostic.flush()
 var result=diagnostic.build_report("Real engine and script errors",{"settings":{"fps":60}})
 print("DIAGNOSTICS_FIXTURE_JSON="+JSON.stringify(result))
 diagnostic.shutdown();diagnostic.queue_free();await process_frame;quit(0)
'''
	write(project+"/fixture.gd",fixture.to_utf8_buffer())
	var output:Array=[]
	var status:=OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path(project),"--script","res://fixture.gd","--quit-after","120"]),output,true)
	var captured:String="\n".join(output)
	check(status==0,"Isolated real engine error fixture completed")
	check("ERROR: DIAGNOSTICS_EXPECTED_ENGINE_ERROR" in captured and "SCRIPT ERROR:" in captured,"Fixture actually executed engine and GDScript error paths")
	var result:Dictionary={}
	for line in captured.split("\n"):
		if line.begins_with("DIAGNOSTICS_FIXTURE_JSON="):
			var parsed:Variant=JSON.parse_string(line.trim_prefix("DIAGNOSTICS_FIXTURE_JSON="))
			if parsed is Dictionary:result=parsed
	check(result.get("ok",false),"Real error fixture built its archive")
	if not result.get("ok",false):return
	result.path=result.absolute_path
	var entries:=read_report(result)
	var events:String=entries["events/current-events.jsonl"].get_string_from_utf8()
	check("DIAGNOSTICS_EXPECTED_ENGINE_ERROR" in events,"Actual engine error reaches persistent report through OS.add_logger")
	check("DIAGNOSTICS_EXPECTED_SCRIPT_KEY" in events and "engine_error" in events,"Actual unhandled GDScript error reaches persistent report")
	check(not "get_local_variable_value" in events and not "get_global_variable_value" in events,"Backtraces collect locations, never variable values")
	DirAccess.remove_absolute(str(result.path))

func cleanup(path:String)->void:
	for name in DirAccess.get_files_at(path):DirAccess.remove_absolute(path.path_join(name))
	for name in DirAccess.get_directories_at(path):cleanup(path.path_join(name))
	DirAccess.remove_absolute(path)

func run()->void:
	contents_and_limits();previous_session();actual_engine_capture()
	await process_frame
	cleanup(base)
	print("GAME DIAGNOSTICS TESTS: %d checks, %d failures; isolated real engine/script errors captured"%[checks,failures])
	quit(1 if failures else 0)
