extends SceneTree
const BuildInfo=preload("res://scripts/build_info.gd")
const Diagnostics=preload("res://scripts/game_diagnostics.gd")
const REPORT:="res://build/current-test-reports/build-version.json"
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	check(BuildInfo.VERSION=="0.29.0-events-alpha1","Current checkpoint has its new project version")
	check(BuildInfo.VERSION_CODE==54 and BuildInfo.VERSION_CODE>53,"Android update code advances from the published code53")
	var preset:=ConfigFile.new();check(preset.load("res://export_presets.cfg")==OK,"Android preset is readable")
	check(preset.get_value("preset.0.options","version/name","")==BuildInfo.VERSION,"Menu/diagnostics and APK versionName agree")
	check(preset.get_value("preset.0.options","version/code",0)==BuildInfo.VERSION_CODE,"Menu/diagnostics and APK versionCode agree")
	check(preset.get_value("preset.0.options","package/unique_name","")=="org.starfrontier.rebuild","Updates retain the installation package")
	var diagnostics:=Diagnostics.new();diagnostics.directory="user://version-probe-%d"%OS.get_process_id();diagnostics.reports_directory="user://version-reports-%d"%OS.get_process_id();root.add_child(diagnostics)
	check(diagnostics.initialize(BuildInfo.VERSION),"Actual diagnostics initializes with the current project version")
	var session:Variant=JSON.parse_string(FileAccess.get_file_as_string(diagnostics.directory.path_join(Diagnostics.SESSION)))
	check(session is Dictionary and session.get("version")==BuildInfo.VERSION,"Persisted diagnostic session identifies the new version")
	diagnostics.shutdown(true);diagnostics.queue_free();await process_frame
	var sources:Dictionary={}
	for path:String in ["scripts/build_info.gd","export_presets.cfg","scripts/game_diagnostics.gd","scripts/diagnostics_logger.gd","tests/test_build_version.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":sources,"version":BuildInfo.VERSION,"version_code":BuildInfo.VERSION_CODE,"APK_manifest_verified_separately":true},"\t")+"\n");file.close()
	print("BUILD VERSION TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
