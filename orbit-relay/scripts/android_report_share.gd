extends RefCounted
## Android-only transport for this game's private, generated report ZIPs.
## `shared` means the system chooser opened, never that a recipient received it.

const MIME := "application/zip"
const DOWNLOAD_DIRECTORY := "Download/OrbitalRelay/"
const MAX_ZIP_BYTES := 8 * 1024 * 1024
const MAX_ENTRY_BYTES := 4 * 1024 * 1024
const MAX_TOTAL_BYTES := 6 * 1024 * 1024
const ALLOWED_ENTRIES := ["report.json", "events.jsonl", "flight.json"]


class AndroidPlatform:
	extends RefCounted
	var last_error := ""
	var bridge: Variant
	var runtime: Variant
	var context: Variant
	var resolver: Variant
	var activity: Variant
	var _classes: Dictionary = {}

	func available() -> bool:
		if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):
			last_error = "android_runtime_unavailable"
			return false
		bridge = Engine.get_singleton("JavaClassWrapper")
		runtime = Engine.get_singleton("AndroidRuntime")
		context = runtime.getApplicationContext()
		if context == null:
			last_error = "android_context_unavailable"
			return false
		resolver = _call(context, "getContentResolver", [], "resolver_failed")
		return resolver != null

	func _class(name: String) -> Variant:
		if _classes.has(name):
			return _classes[name]
		last_error = ""
		var result: Variant = bridge.wrap(name)
		# wrap() and cached Java constants do not replace the exception stored
		# by the previous wrapped Java method. Judge the class by its result.
		if result == null:
			last_error = "java_class_unavailable"
			return null
		_classes[name] = result
		return result

	func _call(target: Variant, method: String, args: Array, stage: String) -> Variant:
		last_error = ""
		if target == null:
			last_error = stage
			return null
		var result: Variant = target.callv(method, args)
		# Capture immediately: the next Java call clears the stored exception.
		if bridge.get_exception() != null:
			last_error = stage
			return null
		return result

	func sdk_int() -> int:
		var version: Variant = _class("android.os.Build$VERSION")
		if version == null:
			return 0
		last_error = ""
		var result: Variant = version.SDK_INT
		# SDK_INT is a cached constant, so get_exception() may still describe
		# a failed FileProvider call before the MediaStore fallback.
		if not (result is int or result is float):
			last_error = "android_version_unavailable"
			return 0
		return int(result)

	func create_values(filename: String, pending: int) -> Variant:
		var values_type: Variant = _class("android.content.ContentValues")
		if values_type == null:
			return null
		# Java constructors are Class.ClassName(), not GDScript Class.new().
		var values: Variant = _call(values_type, "ContentValues", [], "values_constructor_failed")
		if values == null:
			return null
		var pairs: Array = [["is_pending", pending]]
		if pending == 1:
			pairs = [["_display_name", filename], ["mime_type", MIME], ["relative_path", DOWNLOAD_DIRECTORY], ["is_pending", pending]]
		for pair: Array in pairs:
			_call(values, "put", pair, "values_put_failed")
			if not last_error.is_empty():
				return null
		# JavaClassWrapper auto-boxes numeric arguments. Confirm the exact flag.
		var flag: Variant = _call(values, "getAsInteger", ["is_pending"], "pending_flag_failed")
		if flag == null or int(flag) != pending:
			last_error = "pending_flag_failed"
			return null
		return values

	func collection_uri() -> Variant:
		var downloads: Variant = _class("android.provider.MediaStore$Downloads")
		return _call(downloads, "getContentUri", ["external_primary"], "downloads_uri_failed") if downloads != null else null

	func insert(collection: Variant, values: Variant) -> Variant:
		return _call(resolver, "insert", [collection, values], "insert_failed")

	func is_content_uri(uri: Variant) -> bool:
		var scheme: Variant = _call(uri, "getScheme", [], "uri_scheme_failed")
		return scheme != null and str(scheme) == "content"

	func open_output(uri: Variant) -> Variant:
		return _call(resolver, "openOutputStream", [uri, "w"], "open_output_failed")

	func write(stream: Variant, bytes: PackedByteArray) -> bool:
		_call(stream, "write", [bytes], "write_failed")
		return last_error.is_empty()

	func flush(stream: Variant) -> bool:
		_call(stream, "flush", [], "flush_failed")
		return last_error.is_empty()

	func close(stream: Variant) -> bool:
		_call(stream, "close", [], "close_failed")
		return last_error.is_empty()

	func commit(uri: Variant, filename: String) -> bool:
		var values: Variant = create_values(filename, 0)
		if values == null:
			return false
		# Empty String/array match these exact JNI signatures; null String is not
		# accepted by Godot's JavaClassWrapper. Empty SQL selection means none.
		var result: Variant = _call(resolver, "update", [uri, values, "", PackedStringArray()], "commit_failed")
		return result != null and int(result) == 1

	func delete(uri: Variant) -> bool:
		var result: Variant = _call(resolver, "delete", [uri, "", PackedStringArray()], "delete_failed")
		return result != null and int(result) >= 0

	func location(uri: Variant, filename: String) -> Dictionary:
		var fallback := {"path": DOWNLOAD_DIRECTORY, "file": filename, "path_verified": false}
		var cursor: Variant = _call(resolver, "query", [uri, PackedStringArray(["_display_name"]), "", PackedStringArray(), ""], "query_failed")
		if cursor == null:
			return fallback
		var moved: Variant = _call(cursor, "moveToFirst", [], "cursor_failed")
		var actual := ""
		if moved == true:
			var value: Variant = _call(cursor, "getString", [0], "display_name_failed")
			if value != null:
				actual = str(value)
		_call(cursor, "close", [], "cursor_close_failed")
		if actual.is_empty() or actual.get_file() != actual:
			return fallback
		return {"path": DOWNLOAD_DIRECTORY + actual, "file": actual, "path_verified": true}

	func provider_uri(path: String) -> Variant:
		activity = runtime.getActivity()
		if activity == null:
			last_error = "android_activity_unavailable"
			return null
		var package: Variant = _call(activity, "getPackageName", [], "package_failed")
		if package == null:
			return null
		var file_type: Variant = _class("java.io.File")
		if file_type == null:
			return null
		var file: Variant = _call(file_type, "File", [path], "file_constructor_failed")
		if file == null:
			return null
		var provider: Variant = _class("androidx.core.content.FileProvider")
		if provider == null:
			return null
		return _call(provider, "getUriForFile", [activity, str(package) + ".fileprovider", file], "file_provider_failed")

	func start_chooser(uri: Variant, filename: String) -> bool:
		if activity == null:
			activity = runtime.getActivity()
		if activity == null:
			last_error = "android_activity_unavailable"
			return false
		var intent_type: Variant = _class("android.content.Intent")
		if intent_type == null:
			return false
		var intent: Variant = _call(intent_type, "Intent", [], "intent_constructor_failed")
		if intent == null:
			return false
		for call: Array in [["setAction", ["android.intent.action.SEND"]], ["setType", [MIME]], ["putExtra", ["android.intent.extra.STREAM", uri]], ["putExtra", ["android.intent.extra.SUBJECT", "Отчёт об ошибке: " + filename]], ["addFlags", [1]]]:
			_call(intent, call[0], call[1], "share_intent_failed")
			if not last_error.is_empty():
				return false
		var clip_type: Variant = _class("android.content.ClipData")
		if clip_type == null:
			return false
		var clip: Variant = _call(clip_type, "newUri", [resolver, "ZIP-отчёт игры", uri], "share_clip_failed")
		if clip == null:
			return false
		_call(intent, "setClipData", [clip], "share_clip_failed")
		if not last_error.is_empty():
			return false
		var chooser: Variant = _call(intent_type, "createChooser", [intent, "Отправить ZIP-отчёт"], "share_chooser_failed")
		if chooser == null:
			return false
		# 1 == FLAG_GRANT_READ_URI_PERMISSION. Grant only this content URI.
		_call(chooser, "addFlags", [1], "share_grant_failed")
		if not last_error.is_empty():
			return false
		# Same synchronous startActivity pattern as the official Godot JNI guide.
		_call(activity, "startActivity", [chooser], "share_launch_failed")
		return last_error.is_empty()


static func _error(reason: String, path: String = "") -> Dictionary:
	return {"ok": false, "shared": false, "chooser_opened": false, "path": path, "file": path.get_file(), "local_path": path, "uri": null, "public_downloads": false, "reason": reason}


static func _report(local_path: String) -> Dictionary:
	var path := ProjectSettings.globalize_path(local_path).simplify_path()
	var root := OS.get_user_data_dir().simplify_path().trim_suffix("/") + "/reports/"
	if not path.begins_with(root) or not path.get_file().begins_with("orbital-relay-") or not path.ends_with(".zip"):
		return _error("not_private_report", path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("report_not_found", path)
	var length := file.get_length()
	if length < 22 or length > MAX_ZIP_BYTES:
		file.close()
		return _error("report_size_invalid", path)
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size() != length or not _zip_policy(bytes):
		return _error("report_zip_invalid", path)
	var archive := ZIPReader.new()
	if archive.open(path) != OK:
		return _error("report_zip_invalid", path)
	var metadata: Variant = JSON.parse_string(archive.read_file("report.json").get_string_from_utf8())
	var events := archive.read_file("events.jsonl").get_string_from_utf8()
	var names := archive.get_files()
	var valid: bool = metadata is Dictionary and metadata.get("game") == "Орбитальный рейс" and metadata.get("includes_flight_state") is bool and metadata.get("event_count") is float
	if valid:
		var lines := events.strip_edges().split("\n", false)
		valid = int(metadata.event_count) == lines.size() and lines.size() <= 48 and bool(metadata.includes_flight_state) == names.has("flight.json")
		for line: String in lines:
			if not JSON.parse_string(line) is Dictionary:
				valid = false
		if names.has("flight.json") and not JSON.parse_string(archive.read_file("flight.json").get_string_from_utf8()) is Dictionary:
			valid = false
	archive.close()
	if not valid:
		return _error("not_game_report", path)
	return {"ok": true, "path": path, "file": path.get_file(), "bytes": bytes}


static func _zip_policy(bytes: PackedByteArray) -> bool:
	# Bound expanded data before ZIPReader allocates it; accept this game's
	# three canonical entries only, not arbitrary private files or ZIP bombs.
	if bytes.decode_u32(0) != 0x04034b50:
		return false
	var end := -1
	for i in range(bytes.size() - 22, maxi(-1, bytes.size() - 65558), -1):
		if bytes.decode_u32(i) == 0x06054b50 and i + 22 + bytes.decode_u16(i + 20) == bytes.size():
			end = i
			break
	if end < 0 or bytes.decode_u16(end + 4) != 0 or bytes.decode_u16(end + 6) != 0:
		return false
	var count := int(bytes.decode_u16(end + 10))
	if count < 2 or count > 3 or bytes.decode_u16(end + 8) != count:
		return false
	var offset := int(bytes.decode_u32(end + 16))
	var central_size := int(bytes.decode_u32(end + 12))
	if offset < 0 or offset + central_size != end:
		return false
	var position := offset
	var names: Dictionary = {}
	var expanded := 0
	for entry in range(count):
		if position + 46 > end or bytes.decode_u32(position) != 0x02014b50:
			return false
		var flags := bytes.decode_u16(position + 8)
		var method := bytes.decode_u16(position + 10)
		var compressed := int(bytes.decode_u32(position + 20))
		var size := int(bytes.decode_u32(position + 24))
		var name_length := int(bytes.decode_u16(position + 28))
		var next := position + 46 + name_length + bytes.decode_u16(position + 30) + bytes.decode_u16(position + 32)
		if flags & 1 or method not in [0, 8] or size > MAX_ENTRY_BYTES or next > end or bytes.decode_u16(position + 34) != 0:
			return false
		var name := bytes.slice(position + 46, position + 46 + name_length).get_string_from_utf8()
		if name not in ALLOWED_ENTRIES or names.has(name):
			return false
		var local := int(bytes.decode_u32(position + 42))
		if local < 0 or local + 30 > offset or bytes.decode_u32(local) != 0x04034b50:
			return false
		var payload := local + 30 + bytes.decode_u16(local + 26) + bytes.decode_u16(local + 28)
		if payload + compressed > offset:
			return false
		names[name] = true
		expanded += size
		position = next
	return position == end and expanded <= MAX_TOTAL_BYTES and names.has("report.json") and names.has("events.jsonl")


static func _platform(platform: Variant) -> Variant:
	if platform != null:
		return platform
	if not OS.has_feature("android"):
		return null
	return AndroidPlatform.new()


static func publish(local_path: String, platform: Variant = null) -> Dictionary:
	var report := _report(local_path)
	if not report.ok:
		return report
	var native: Variant = _platform(platform)
	if native == null or not native.available():
		return _error("android_runtime_unavailable", report.path)
	return _publish(report, native)


static func _publish(report: Dictionary, native: Variant) -> Dictionary:
	if native.sdk_int() < 29:
		return _error("downloads_requires_android_10", report.path)
	var values: Variant = native.create_values(report.file, 1)
	if values == null:
		return _error("download_values_failed", report.path)
	var collection: Variant = native.collection_uri()
	if collection == null:
		return _error("downloads_uri_failed", report.path)
	var uri: Variant = native.insert(collection, values)
	if uri == null:
		return _error("download_insert_failed", report.path)
	if not native.is_content_uri(uri):
		var invalid := _error("download_uri_invalid", report.path)
		invalid["cleanup_failed"] = not native.delete(uri)
		return invalid
	var stream: Variant = native.open_output(uri)
	var reason := ""
	if stream == null:
		reason = "download_open_failed"
	else:
		if not native.write(stream, report.bytes):
			reason = "download_write_failed"
		elif not native.flush(stream):
			reason = "download_flush_failed"
		var closed: bool = native.close(stream)
		if not closed and reason.is_empty():
			reason = "download_close_failed"
	if reason.is_empty() and not native.commit(uri, report.file):
		reason = "download_commit_failed"
	if not reason.is_empty():
		var failed := _error(reason, report.path)
		failed["cleanup_failed"] = not native.delete(uri)
		return failed
	var location: Dictionary = native.location(uri, report.file)
	return {"ok": true, "shared": false, "chooser_opened": false, "path": location.path, "file": location.file, "local_path": report.path, "uri": uri, "public_downloads": true, "path_verified": location.get("path_verified", false), "reason": "published"}


static func share(local_path: String, platform: Variant = null) -> Dictionary:
	var report := _report(local_path)
	if not report.ok:
		return report
	var native: Variant = _platform(platform)
	if native == null or not native.available():
		return _error("android_runtime_unavailable", report.path)
	var uri: Variant = native.provider_uri(report.path)
	var result := {"ok": true, "path": report.path, "file": report.file, "local_path": report.path, "public_downloads": false}
	if uri == null or not native.is_content_uri(uri):
		result = _publish(report, native)
		if not result.ok:
			return result
		uri = result.uri
	if not native.start_chooser(uri, result.file):
		result["ok"] = false
		result["shared"] = false
		result["chooser_opened"] = false
		result["reason"] = "android_chooser_failed"
		return result
	result["ok"] = true
	result["shared"] = true
	result["chooser_opened"] = true
	result["reason"] = "chooser_opened"
	return result
