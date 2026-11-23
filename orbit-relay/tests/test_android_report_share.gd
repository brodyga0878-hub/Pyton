extends SceneTree

const Share = preload("res://scripts/android_report_share.gd")
const SessionIO = preload("res://scripts/session_io.gd")
const Flight = preload("res://scripts/flight_sim.gd")
var failures: Array[String] = []
var checks := 0
var files: Array[String] = []


class UriToken:
	extends RefCounted
	var scheme := "content"
	var label := ""
	func _init(value: String): label = value


class Platform:
	extends RefCounted
	var calls: Array[String] = []
	var failure := ""
	var sdk := 35
	var provider_available := true
	var delete_ok := true
	var collection := UriToken.new("collection")
	var row := UriToken.new("download-row")
	var private_uri := UriToken.new("private-file")
	var output := RefCounted.new()
	var written := PackedByteArray()
	var chooser_uri: Variant
	var inserted_values: Dictionary = {}
	func available() -> bool: calls.append("available"); return failure != "available"
	func sdk_int() -> int: calls.append("sdk"); return sdk
	func create_values(filename: String, pending: int) -> Variant:
		calls.append("values"); inserted_values = {"file": filename, "is_pending": pending}
		return null if failure == "values" else inserted_values
	func collection_uri() -> Variant: calls.append("collection"); return null if failure == "collection" else collection
	func insert(_collection: Variant, _values: Variant) -> Variant: calls.append("insert"); return null if failure == "insert" else row
	func is_content_uri(uri: Variant) -> bool: calls.append("scheme"); return uri.scheme == "content"
	func open_output(_uri: Variant) -> Variant: calls.append("open"); return null if failure == "open" else output
	func write(_stream: Variant, bytes: PackedByteArray) -> bool: calls.append("write"); written = bytes.duplicate(); return failure != "write"
	func flush(_stream: Variant) -> bool: calls.append("flush"); return failure != "flush"
	func close(_stream: Variant) -> bool: calls.append("close"); return failure != "close"
	func commit(_uri: Variant, _file: String) -> bool: calls.append("commit"); return failure != "commit"
	func delete(_uri: Variant) -> bool: calls.append("delete"); return delete_ok
	func location(_uri: Variant, _file: String) -> Dictionary:
		calls.append("location"); return {"path": Share.DOWNLOAD_DIRECTORY + "actual-name.zip", "file": "actual-name.zip", "path_verified": true}
	func provider_uri(_path: String) -> Variant:
		calls.append("provider"); return private_uri if provider_available else null
	func start_chooser(uri: Variant, _file: String) -> bool:
		calls.append("chooser"); chooser_uri = uri; return failure != "chooser"


# Model the official JavaClassWrapper contract: neither wrap(), cached
# constants nor get_exception() consume the last wrapped-method exception.
class CachedSdk:
	extends RefCounted
	var SDK_INT: Variant = 35


class StickyBridge:
	extends RefCounted
	var exception: Variant
	var version := CachedSdk.new()
	var other_class := RefCounted.new()
	func wrap(name: String) -> Variant:
		return version if name == "android.os.Build$VERSION" else other_class
	func get_exception() -> Variant:
		return exception


class ThrowingProvider:
	extends RefCounted
	var bridge: StickyBridge
	func getUriForFile(_context: Variant, _authority: String, _file: Variant) -> Variant:
		bridge.exception = RefCounted.new()
		return null


class SuccessfulResolver:
	extends RefCounted
	var bridge: StickyBridge
	var uri := UriToken.new("recovered-download")
	func insert(_collection: Variant, _values: Variant) -> Variant:
		# A successful wrapped Java method replaces the stored exception.
		bridge.exception = null
		return uri


func _test_sticky_java_exception() -> void:
	var bridge := StickyBridge.new()
	var platform := Share.AndroidPlatform.new()
	platform.bridge = bridge
	var provider := ThrowingProvider.new()
	provider.bridge = bridge
	var failed: Variant = platform._call(provider, "getUriForFile", [null, "test.fileprovider", null], "file_provider_failed")
	check(failed == null and platform.last_error == "file_provider_failed", "FileProvider method failure captures Java exception")
	var exception: Variant = bridge.get_exception()
	check(exception != null and bridge.get_exception() == exception, "reading get_exception does not consume a stored Java failure")
	check(platform.sdk_int() == 35 and platform.last_error.is_empty(), "MediaStore SDK lookup succeeds after FileProvider exception")
	check(platform.sdk_int() == 35 and bridge.get_exception() == exception, "cached SDK lookup also ignores the previous method exception")
	check(platform._class("android.content.ContentValues") != null and bridge.get_exception() == exception, "wrapping the next Java class does not misclassify a stale exception")
	var resolver := SuccessfulResolver.new()
	resolver.bridge = bridge
	var published: Variant = platform._call(resolver, "insert", [null, null], "insert_failed")
	check(published == resolver.uri and platform.last_error.is_empty() and bridge.get_exception() == null, "next real ContentResolver method clears the previous exception and returns its URI")
	bridge.version.SDK_INT = null
	check(platform.sdk_int() == 0 and platform.last_error == "android_version_unavailable", "unavailable SDK constant still fails explicitly")


func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func path(name: String) -> String:
	var file := "user://reports/orbital-relay-native-test-%d-%s.zip" % [OS.get_process_id(), name]
	files.append(file); return file
func archive(file: String, metadata: Dictionary, event_text: String = "", extra: Dictionary = {}) -> void:
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var zip := ZIPPacker.new(); check(zip.open(file) == OK, "fixture archive opens")
	for pair: Array in [["report.json", JSON.stringify(metadata)], ["events.jsonl", event_text]]:
		zip.start_file(pair[0]); zip.write_file(pair[1].to_utf8_buffer()); zip.close_file()
	for name: String in extra:
		zip.start_file(name); zip.write_file(str(extra[name]).to_utf8_buffer()); zip.close_file()
	check(zip.close() == OK, "fixture archive closes")


func run() -> void:
	_test_sticky_java_exception()
	var source := path("source")
	var producer := SessionIO.new(); producer.trace("actual-production", {"step": 1})
	var generated := producer.export_report(Flight.new().snapshot(), source)
	check(generated.ok and generated.includes_flight_state, "actual SessionIO producer creates private report with a valid flight")
	var bytes := FileAccess.get_file_as_bytes(source)
	var native := Platform.new()
	var result := Share.publish(source, native)
	check(result.ok and result.public_downloads and result.uri == native.row, "publish returns the same URI object created by insert")
	check(result.path == Share.DOWNLOAD_DIRECTORY + "actual-name.zip" and result.file == "actual-name.zip", "returned Downloads name comes from provider query, not assumed filename")
	check(native.inserted_values.is_pending == 1, "new MediaStore row begins pending")
	check(native.written == bytes, "all exact generated ZIP bytes written")
	check(native.calls.find("close") < native.calls.find("commit"), "output closed before publication")
	check(not native.calls.has("delete") and not native.calls.has("chooser"), "successful publish neither rolls back nor opens sharing implicitly")
	check(FileAccess.get_file_as_bytes(source) == bytes, "successful publish retains private source")
	for stage: String in ["values", "collection", "insert", "open", "write", "flush", "close", "commit"]:
		native = Platform.new(); native.failure = stage
		result = Share.publish(source, native)
		check(not result.ok and not result.public_downloads, "failure is never reported as public success: " + stage)
		check(native.calls.has("delete") == (stage in ["open", "write", "flush", "close", "commit"]), "inserted rows rolled back at the right stages: " + stage)
		check(native.calls.has("close") == (stage in ["write", "flush", "close", "commit"]), "every opened output stream closes after a failed operation: " + stage)
		check(FileAccess.get_file_as_bytes(source) == bytes, "private source survives stage failure: " + stage)
		if stage in ["write", "flush", "close"]:
			check(not native.calls.has("commit"), "failed write never publishes row: " + stage)
	native = Platform.new(); native.failure = "write"; native.delete_ok = false
	result = Share.publish(source, native)
	check(not result.ok and result.cleanup_failed, "failed rollback is surfaced without hiding the write error")
	native = Platform.new(); native.sdk = 28
	check(not Share.publish(source, native).ok and not native.calls.has("insert"), "old Android never attempts Downloads insertion")
	native = Platform.new(); native.row.scheme = "file"
	check(not Share.publish(source, native).ok and native.calls.has("delete") and not native.calls.has("open"), "non-content result rejected and rolled back")
	native = Platform.new(); native.sdk = 24
	result = Share.share(source, native)
	check(result.ok and result.shared and result.chooser_opened and result.reason == "chooser_opened", "FileProvider route launches chooser even below API29 without claiming delivery")
	check(not result.public_downloads and native.chooser_uri == native.private_uri and not native.calls.has("insert"), "share grants exact private URI without unrelated public copy")
	native = Platform.new(); native.provider_available = false
	result = Share.share(source, native)
	check(result.ok and result.public_downloads and native.chooser_uri == native.row, "missing provider falls back to completed MediaStore content URI")
	check(native.calls.find("commit") < native.calls.find("chooser"), "pending public file is not shared until committed")
	native = Platform.new(); native.provider_available = false; native.failure = "chooser"
	result = Share.share(source, native)
	check(not result.ok and not result.shared and result.public_downloads and result.path.begins_with(Share.DOWNLOAD_DIRECTORY), "chooser failure preserves truthful public Downloads fallback")
	check(not native.calls.has("delete"), "chooser cancellation/failure never deletes a completed Downloads file")
	native = Platform.new(); native.failure = "chooser"
	check(not Share.share(source, native).ok and FileAccess.get_file_as_bytes(source) == bytes, "private chooser failure retains source")
	native = Platform.new(); native.provider_available = false; native.sdk = 28
	check(not Share.share(source, native).ok and not native.calls.has("chooser"), "unavailable fallback is explicit, not false share success")
	var invalid := path("foreign")
	archive(invalid, {"game": "Other", "event_count": 0, "includes_flight_state": false})
	native = Platform.new(); check(not Share.publish(invalid, native).ok and native.calls.is_empty(), "foreign ZIP rejected before platform access")
	var arbitrary := path("entry")
	archive(arbitrary, {"game": "Орбитальный рейс", "event_count": 0, "includes_flight_state": false}, "", {"private.key": "no"})
	native = Platform.new(); check(not Share.share(arbitrary, native).ok and native.calls.is_empty(), "extra arbitrary entries cannot be shared")
	var inconsistent := path("mismatch")
	archive(inconsistent, {"game": "Орбитальный рейс", "event_count": 2, "includes_flight_state": false})
	native = Platform.new(); check(not Share.publish(inconsistent, native).ok and native.calls.is_empty(), "inconsistent report metadata rejected")
	var fractional := path("fractional-count")
	archive(fractional, {"game": "Орбитальный рейс", "event_count": 0.5, "includes_flight_state": false})
	native = Platform.new()
	check(not Share.publish(fractional, native).ok and native.calls.is_empty(),
		"A fractional count cannot pass as an empty journal before Android handoff")
	var grown := path("large-state")
	archive(grown, {"game": "Орбитальный рейс", "event_count": 0, "includes_flight_state": true}, "", {"flight.json": JSON.stringify({"future_campaign_fixture": "a".repeat(100000)})})
	native = Platform.new(); check(Share.publish(grown, native).ok, "future valid-shaped campaign fixture above64KiB remains supported")
	var renamed := "user://reports/not-a-game-report-%d.zip" % OS.get_process_id()
	files.append(renamed); var out := FileAccess.open(renamed, FileAccess.WRITE); out.store_buffer(bytes); out.close()
	native = Platform.new(); check(not Share.share(renamed, native).ok and native.calls.is_empty(), "uncontrolled private filename rejected")
	var outside := "user://orbital-relay-outside-%d.zip" % OS.get_process_id()
	files.append(outside); out = FileAccess.open(outside, FileAccess.WRITE); out.store_buffer(bytes); out.close()
	native = Platform.new(); check(not Share.share(outside, native).ok and native.calls.is_empty(), "arbitrary private directories rejected")
	if not OS.has_feature("android"):
		check(not Share.publish(source).ok and not Share.share(source).ok, "desktop rejects native operations rather than treating a private path as public")
	for file: String in files: DirAccess.remove_absolute(file)
	print("Android report transport: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
