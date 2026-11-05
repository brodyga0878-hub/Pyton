extends SceneTree
# Actual Main report UI. All diagnostic/save/export files stay in this test's
# private directory; no native picker or user's saved flight is accessed.
const BuildInfo=preload("res://scripts/build_info.gd")
const Export=preload("res://scripts/report_export.gd")
var game:Node3D
var checks:=0
var failures:=0
var directory:=""

func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(message)
func action(text:String)->Button:
	for item in game.menu_rows.get_children():
		if item is Button and item.text==text:return item
	return null
func include_box()->CheckBox:
	for item in game.menu_rows.get_children():
		if item is CheckBox:return item
	return null
func payload()->String:return JSON.stringify(game._payload())
func references()->Array:return [game.ship,game.nav,game.world,game.surface]
func digest(bytes:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func open_report(path:String)->Dictionary:
	var reader:=ZIPReader.new()
	check(reader.open(path)==OK,"Real UI report is a readable ZIP")
	var files:Dictionary={}
	for name in reader.get_files():files[name]=reader.read_file(name)
	reader.close()
	check(files.has("manifest.json") and files.has("report.json") and files.has("description.txt"),"Actual report contains manifest, metadata and description")
	if not files.has("manifest.json"):return files
	var manifest:Dictionary=JSON.parse_string(files["manifest.json"].get_string_from_utf8())
	for entry in manifest.files:
		check(files.has(entry.name),"Manifest member exists: "+entry.name)
		if files.has(entry.name):check(files[entry.name].size()==int(entry.bytes) and digest(files[entry.name])==entry.sha256,"Actual ZIP member matches declared size/SHA: "+entry.name)
	return files
func settle()->void:
	for i in range(4):await process_frame
	check(not game.busy,"Report coroutine releases Main busy state")

func unavailable_diagnostics()->void:
	game._show_menu()
	var entry:=action("Отчёт об ошибке / логи")
	check(entry!=null,"Normal commander menu exposes the actual report action")
	if entry==null:return
	entry.pressed.emit()
	check(game.menu_title.text=="ОТЧЁТ ОБ ОШИБКЕ" and game.report_description!=null,"Report action builds the real report page")
	check(not game.report_include_save and include_box()!=null and not include_box().button_pressed,"Full saved flight is an explicit unchecked option")
	var retry:=action("Повторно сохранить последний ZIP")
	check(retry!=null and retry.disabled,"Retry action is visible but disabled before a report exists")
	var create:=action("Собрать ZIP и сохранить…")
	check(create!=null,"Report page has its actual create/export button")
	if create!=null:create.pressed.emit()
	await settle()
	check(game.current_report.is_empty() and not game.report_export.is_busy(),"Uninitialized diagnostic collection creates no success record or blocked picker")
	check(game.report_feedback.text.contains("не запущена"),"The real collector failure stays visible on the report page")

func report_page_preserves_disk_progress()->void:
	game.saving_enabled=true
	check(game._save_game(),"Readonly report regression starts from an actual private saved flight")
	var generation:int=game.saves.sequence;var credits:int=game.ship.credits
	var path:String=game.saves.directory+"/slot%d.json"%(generation%2)
	var bytes:=FileAccess.get_file_as_bytes(path)
	game.ship.credits+=7
	game._show_bug_report()
	check(game.saves.sequence==generation and FileAccess.get_file_as_bytes(path)==bytes,"Opening report page does not overwrite a saved flight with the current diagnostic state")
	game.report_export._busy=true;game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.saves.sequence==generation and FileAccess.get_file_as_bytes(path)==bytes,"Native report picker focus loss does not trigger an extra game save")
	game.report_export._reset();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game.saving_enabled and game.ship.credits==credits+7,"Readonly reporting leaves saving policy and active flight untouched")
	game.ship.credits=credits;game.saving_enabled=false;game._close_menu()

func normal_report()->void:
	game.diagnostics.directory=directory+"/diagnostics"
	game.diagnostics.reports_directory=directory+"/reports"
	game.diagnostics.engine_logs_directory=directory+"/legacy-logs"
	check(game.diagnostics.initialize(BuildInfo.VERSION),"Actual collector initializes only in private test directories")
	game.diagnostics.record("ui_report_fixture",{"operation":"verify diagnostic page"})
	game._show_bug_report()
	var before:=payload();var original:=references();var generation:int=game.saves.sequence
	game.report_description.text="Ошибка посадки: после касания экрана корабль продолжает поворот.\nПовторение: открыть меню, затем закрыть."
	game.report_description.text_changed.emit()
	check(game.report_draft.contains("Ошибка посадки"),"The real text field signal updates the description draft")
	var create:=action("Собрать ZIP и сохранить…")
	if create!=null:create.pressed.emit()
	await settle()
	check(game.current_report.get("ok",false),"Pressing the real button creates a complete report before the picker step")
	if not game.current_report.get("ok",false):return
	check(FileAccess.file_exists(game.current_report.path),"Created report is retained for retry")
	var retry:=action("Повторно сохранить последний ZIP")
	check(retry!=null and not retry.disabled,"First successful build enables retry immediately on the current page")
	var retained_path:String=game.current_report.path;var retained_count:=DirAccess.get_files_at(game.diagnostics.reports_directory).size()
	if retry!=null:retry.pressed.emit()
	check(game.current_report.path==retained_path and DirAccess.get_files_at(game.diagnostics.reports_directory).size()==retained_count and not game.report_export.is_busy(),"Immediate retry reuses the same ZIP without reopening the page or creating another archive")
	check(not game.report_export.is_busy(),"Headless picker unavailability does not leave the export locked")
	check(game.report_feedback.text.contains("графический интерфейс"),"Unavailable graphical picker reports a useful error after keeping the ZIP")
	var files:=open_report(game.current_report.path)
	var report:Dictionary=JSON.parse_string(files["report.json"].get_string_from_utf8())
	check(report.version==BuildInfo.VERSION and report.context.build.code==BuildInfo.VERSION_CODE,"Archive identifies the actual runtime release")
	check(report.context.mode=="space" and report.context.flight.system_id==game.nav.current_id,"Archive contains the actual active flight context")
	check(report.context.session.world_layout==game.world.NATIVE_LAYOUT and report.context.session.preferred_world_layout==game.world.NATIVE_LAYOUT,"Report identifies the native orbital layout and its persistent preference")
	check(report.context.session.source_orbit==JSON.parse_string(JSON.stringify(game.world.orbit_backend_state)),"Report preserves the actual source-orbit contract and explicit local-physics adapters")
	check(not report.included_save and not files.has("game-save.json"),"Default report excludes full saved progress")
	check(files["description.txt"].get_string_from_utf8()==game.report_draft,"Russian multiline description survives the complete UI-to-ZIP path")
	check(files.has("events/current-events.jsonl") and files["events/current-events.jsonl"].get_string_from_utf8().contains("ui_report_fixture"),"Collected application events are in the real archive")
	check(payload()==before and references()==original and game.saves.sequence==generation,"Report creation/export failure does not change flight, references or save generation")

func optional_save_and_export_callbacks()->void:
	game._show_bug_report()
	check(action("Повторно сохранить последний ZIP")!=null,"Reopening report page offers retry of the retained ZIP")
	check(game.report_description.text==game.report_draft,"Description draft survives reopening the page")
	var option:=include_box()
	if option!=null:option.button_pressed=true;option.toggled.emit(true)
	check(game.report_include_save,"Explicit checkbox opts in to the current flight snapshot")
	check(game.diagnostics._json_safe(game._payload()),"Native world snapshot contains only strict JSON values and String keys")
	var before:=payload()
	var previous_path:String=game.current_report.path
	await game._create_bug_report(false)
	check(not game.busy and game.current_report.get("ok",false) and game.current_report.path!=previous_path,"Archive-only path creates a fresh report without opening a picker")
	var files:=open_report(game.current_report.path)
	var report:Dictionary=JSON.parse_string(files["report.json"].get_string_from_utf8())
	check(report.included_save and files.has("game-save.json"),"Opted-in archive contains the requested saved flight")
	if files.has("game-save.json"):
		var saved:Dictionary=JSON.parse_string(files["game-save.json"].get_string_from_utf8())
		check(saved==JSON.parse_string(before),"Opted-in snapshot matches the exact active whole-game payload after JSON decoding")
		check(saved.planetary.schema=="starfrontier-rebuild-world-v2" and saved.planetary.preferred_layout==game.world.NATIVE_LAYOUT,"Opted-in flight retains the native world schema and future-jump backend")
	var source:String=game.current_report.path;var source_bytes:=FileAccess.get_file_as_bytes(source)
	game.report_export._busy=true;game.report_export._source_path=source;game.report_export._filename=game.current_report.filename
	game.report_export._on_native_selected(false,PackedStringArray(),0)
	check(not game.report_export.is_busy() and game.report_feedback.text.contains("отменено"),"Native cancellation updates the actual report UI and permits retry")
	check(FileAccess.get_file_as_bytes(source)==source_bytes,"Cancelling export preserves the generated report")
	var destination:=directory+"/saved-report.zip"
	game.report_export._busy=true;game.report_export._source_path=source;game.report_export._filename=game.current_report.filename
	game.report_export._on_native_selected(true,PackedStringArray([destination]),0)
	check(not game.report_export.is_busy() and game.report_feedback.text.contains("ChatGPT"),"Successful checked export callback reaches the real UI")
	check(FileAccess.get_file_as_bytes(destination)==source_bytes and FileAccess.get_file_as_bytes(source)==source_bytes,"Exported archive and retained original are byte-identical")
	var exported:=open_report(destination)
	check(exported.has("game-save.json"),"Copied report remains a complete usable reproduction archive")
	var retained:Dictionary=game.current_report
	game.current_report={"ok":true,"path":directory+"/missing.zip","absolute_path":ProjectSettings.globalize_path(directory+"/missing.zip"),"filename":"missing.zip"}
	game._export_bug_report()
	check(not game.report_export.is_busy() and game.report_feedback.text.contains("не найден"),"Missing-source retry returns an actionable UI error")
	game.current_report=retained
	check(payload()==before,"Optional save and all export callbacks leave the active game untouched")

func graphics_preview_report()->void:
	game._close_menu();var original:=references();var before:=payload()
	game._begin_graphics_demo();game._show_menu()
	var entry:=action("Отчёт об ошибке / логи")
	check(entry!=null,"Graphics-flight menu also exposes the report action")
	if entry!=null:entry.pressed.emit()
	var option:=include_box()
	if option!=null:option.button_pressed=false;option.toggled.emit(false)
	await game._create_bug_report(false)
	check(game.current_report.get("ok",false) and not game.saving_enabled,"Preview report succeeds without enabling original persistence")
	var files:=open_report(game.current_report.path)
	var report:Dictionary=JSON.parse_string(files["report.json"].get_string_from_utf8())
	check(report.context.mode=="graphics_preview" and not files.has("game-save.json"),"Preview is identified as preview and unchecked snapshot stays absent")
	game._end_graphics_demo()
	check(references()==original and payload()==before and not game.saving_enabled,"Report roundtrip returns exact paused original progress and saving policy")

func page_close_during_collection()->void:
	game._show_bug_report();var before:=payload()
	game.report_include_save=false
	game._create_bug_report(false)
	check(game.busy,"Collection visibly guards Main while its UI frame is pending")
	game._show_menu()
	await settle()
	check(game.menu_title.text=="КОМАНДИР" and game.current_report.get("ok",false),"Closing report page during its frame does not write to freed labels or lose the completed ZIP")
	check(payload()==before,"Asynchronous page closure leaves the whole flight unchanged")
	var previous:String=game.current_report.path
	var count:=DirAccess.get_files_at(game.diagnostics.reports_directory).size()
	game.report_export._busy=true;game._create_bug_report(false)
	check(game.current_report.path==previous and DirAccess.get_files_at(game.diagnostics.reports_directory).size()==count and not game.busy,"Pending native picker blocks duplicate collection without replacing the retained archive")
	game.report_export._reset()

func remove_owned(path:String)->void:
	if not path.begins_with(directory):return
	if DirAccess.dir_exists_absolute(path):
		for child in DirAccess.get_directories_at(path):remove_owned(path.path_join(child))
		for child in DirAccess.get_files_at(path):DirAccess.remove_absolute(path.path_join(child))
		DirAccess.remove_absolute(path)

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():
		push_error("Run with -- --rebuild-capture");quit(1);return
	directory="user://bug-report-ui-test-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(directory)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.saves.directory=directory+"/saves"
	check(game.automated and not game.saving_enabled,"Actual Main test never loads or saves the user's flight")
	await unavailable_diagnostics();report_page_preserves_disk_progress();await normal_report();await optional_save_and_export_callbacks();await graphics_preview_report();await page_close_during_collection()
	game.queue_free();await process_frame;remove_owned(directory)
	check(not DirAccess.dir_exists_absolute(directory),"All diagnostic/export fixtures are cleaned from the private test tree")
	print("BUG REPORT UI TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
