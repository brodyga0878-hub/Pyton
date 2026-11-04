extends SceneTree
const Export=preload("res://scripts/report_export.gd")
var checks:=0
var failures:=0
var directory:=""
var events:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func make_zip(path:String)->void:
	var zip:=ZIPPacker.new();check(zip.open(path)==OK,"ZIP fixture opens")
	check(zip.start_file("report.json")==OK,"ZIP metadata entry")
	check(zip.write_file('{"source":"export-test"}'.to_utf8_buffer())==OK,"ZIP metadata writes")
	zip.close_file();zip.start_file("logs/game.log")
	var content:=PackedByteArray();content.resize(170123)
	var random:=RandomNumberGenerator.new();random.seed=1729041
	for i in range(content.size()):content[i]=random.randi()&255
	zip.write_file(content);zip.close_file();check(zip.close()==OK,"ZIP fixture closes")
func run()->void:
	directory="user://report-export-test-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(directory)
	var original:=directory+"/report.zip";var exported:=directory+"/exported.zip";make_zip(original)
	var original_bytes:=FileAccess.get_file_as_bytes(original)
	check(original_bytes.size()>Export.BLOCK_BYTES*2,"ZIP fixture actually exercises multiple copy blocks")
	var copied:Dictionary=Export.copy_file_verified(original,exported)
	check(copied.ok and copied.verified and copied.bytes==original_bytes.size(),"Checked copy reports complete byte count")
	check(FileAccess.get_file_as_bytes(exported)==original_bytes,"ZIP byte-for-byte copy")
	check(FileAccess.get_file_as_bytes(original)==original_bytes,"Original ZIP remains unchanged")
	var zip:=ZIPReader.new();check(zip.open(exported)==OK,"Exported ZIP is readable")
	check(zip.get_files().has("report.json") and zip.read_file("logs/game.log").size()==170123,"Exported ZIP metadata and large log intact")
	zip.close()
	check(not Export.copy_file_verified(original,original).ok,"Same report cannot be truncated by self-copy")
	check(not Export.copy_file_verified(original,ProjectSettings.globalize_path(original)).ok,"Absolute alias self-copy rejected")
	check(FileAccess.get_file_as_bytes(original)==original_bytes,"Rejected self-copy preserves source")
	check(not Export.copy_file_verified(directory+"/missing.zip",exported).ok,"Missing source rejected")
	check(FileAccess.get_file_as_bytes(exported)==original_bytes,"Missing source preserves previous export")
	var invalid:=directory+"/bad.zip";var file:=FileAccess.open(invalid,FileAccess.WRITE);file.store_string("This is not a ZIP report with enough bytes");file.close()
	check(not Export.copy_file_verified(invalid,exported).ok,"Non-ZIP data rejected before destination write")
	check(FileAccess.get_file_as_bytes(exported)==original_bytes,"Invalid source preserves previous export")
	check(not Export.copy_file_verified(original,"").ok,"Empty destination rejected")
	check(not Export.copy_file_verified(original,directory+"/no-parent/file.zip").ok,"Failed destination returns an error")
	check(FileAccess.get_file_as_bytes(original)==original_bytes,"Failed destination preserves source archive")
	var exporter:=Export.new();root.add_child(exporter);exporter.completed.connect(func(result:Dictionary):events.append(result))
	check(not exporter.export_report(directory+"/missing.zip","x.zip").ok and not exporter.is_busy(),"Missing-source picker request fails atomically")
	# Exercise native callback semantics without requiring Android or a GUI.
	exporter._busy=true;exporter._source_path=original;exporter._filename="report.zip"
	exporter._on_native_selected(false,PackedStringArray(),0)
	check(events.size()==1 and events[0].cancelled and not exporter.is_busy(),"Native cancellation releases busy state")
	exporter._on_native_selected(false,PackedStringArray(),0)
	check(events.size()==1,"Late duplicate callback ignored")
	exporter._busy=true;exporter._source_path=original;exporter._filename="report.zip"
	exporter._on_native_selected(true,PackedStringArray(),0)
	check(events.size()==2 and not events[1].ok and not events[1].cancelled and not exporter.is_busy(),"Invalid native result is a visible error, not cancellation/success")
	exporter._busy=true;exporter._source_path=original;exporter._filename="report.zip"
	exporter._on_native_selected(true,PackedStringArray([exported]),0)
	check(events.size()==3 and events[2].ok and events[2].verified and events[2].filename=="report.zip","Native selected URI callback completes checked export")
	check(not exporter.is_busy(),"Completed export permits a later request")
	exporter._busy=true
	check(not exporter.export_report(original,"another.zip").ok,"Concurrent picker request rejected")
	exporter._reset();exporter.queue_free();await process_frame
	for path in [original,exported,invalid]:DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(directory)
	print("REPORT EXPORT TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
