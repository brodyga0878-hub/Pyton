extends RefCounted
## Converts simulation seconds to the fixed mission calendar in UTC.

const START_UNIX := 16031087922 # 2478-01-01 23:58:42 UTC
const MAX_EPOCH := 3155760000.0
const SECONDS_PER_DAY := 86400.0
const START_DAY_OFFSET := float(START_UNIX % int(SECONDS_PER_DAY))


static func next_midnight(epoch: float) -> float:
	if not is_finite(epoch) or epoch < 0.0 or epoch >= MAX_EPOCH:
		return -1.0
	var next := (floorf((epoch + START_DAY_OFFSET) / SECONDS_PER_DAY) + 1.0) * SECONDS_PER_DAY - START_DAY_OFFSET
	return next if next <= MAX_EPOCH else -1.0


static func release_index(epoch: float, days: int, seconds_of_day: int) -> int:
	return maxi(0, floori((epoch + START_DAY_OFFSET - seconds_of_day) / (float(days) * SECONDS_PER_DAY)))


static func release_epoch(index: int, days: int, seconds_of_day: int) -> float:
	return maxf(0.0, float(index) * float(days) * SECONDS_PER_DAY + seconds_of_day - START_DAY_OFFSET)


static func stamp(epoch: float) -> String:
	var parts := _parts(epoch)
	if parts.is_empty():
		return ""
	return "%s · %s" % [_format_date(parts), _format_clock(parts)]


static func date(epoch: float) -> String:
	var parts := _parts(epoch)
	return "" if parts.is_empty() else _format_date(parts)


static func clock(epoch: float) -> String:
	var parts := _parts(epoch)
	return "" if parts.is_empty() else _format_clock(parts)


static func _parts(epoch: float) -> Dictionary:
	# A scheduled deadline can fall after the last saveable instant.
	if not is_finite(epoch) or epoch < 0.0 or epoch > MAX_EPOCH + SECONDS_PER_DAY:
		return {}
	return Time.get_datetime_dict_from_unix_time(START_UNIX + floori(epoch))


static func _format_date(parts: Dictionary) -> String:
	return "%02d.%02d.%04d" % [parts.day, parts.month, parts.year]


static func _format_clock(parts: Dictionary) -> String:
	return "%02d:%02d:%02d" % [parts.hour, parts.minute, parts.second]
