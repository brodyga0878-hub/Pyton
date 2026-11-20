extends RefCounted
## A single passage slot runs on the same clock as orbital traffic.

const Catalog := preload("res://scripts/sector_catalog.gd")
const Freight := preload("res://scripts/npc_freight.gd")

const HATCH_AXIS_OFFSET := 6.0
const HATCH_RADIUS := 4.4
const HEADING_SECONDS := 2.4
const OPENING_SECONDS := 1.4
const CLEARANCE_SECONDS := 26.0
const CLOSING_SECONDS := 1.4
const TRAFFIC_LOOKAHEAD := 6.0
const TRAFFIC_BUFFER := 2.4
const TRAFFIC_EXIT_BUFFER := 3.2
const MAX_QUEUE_SECONDS := TRAFFIC_LOOKAHEAD + TRAFFIC_BUFFER
const MAX_EPOCH := 3155760000.0
const CLOCK_PRECISION := 0.0001
const SAVE_FIELDS := ["port", "requested_at", "opening_at", "closing_at"]

var port := -1
var _requested_at := 0.0
var _opening_at := 0.0
var _closing_at := 0.0


func request(site: int, now: float, traffic: Array[Dictionary]) -> bool:
	if not Catalog.is_port(site) or not _number_in_range(now, 0.0, MAX_EPOCH):
		return false
	if port == site and now < _closing_at + _closing_duration():
		return false
	port = site
	_requested_at = now
	_opening_at = now + _departure_and_arrival_wait(site, traffic)
	_closing_at = _opening_at + OPENING_SECONDS + CLEARANCE_SECONDS
	return true


func status(site: int, now: float) -> Dictionary:
	if port < 0 or site != port or not is_finite(now) or now < _requested_at - CLOCK_PRECISION:
		return _status("closed", 0.0, 0.0)
	if now >= _closing_at:
		var closing_left := _closing_at + _closing_duration() - now
		if closing_left > 0.0:
			return _status("closing", minf(1.0, closing_left / CLOSING_SECONDS), closing_left)
		return _status("closed", 0.0, 0.0)
	var ready_at := _opening_at + OPENING_SECONDS
	if now < _opening_at:
		return _status("queued", 0.0, ready_at - now)
	if now < ready_at:
		return _status("opening", (now - _opening_at) / OPENING_SECONDS, ready_at - now)
	return _status("open", 1.0, 0.0, _closing_at - now)


func settle(now: float) -> void:
	if status(port, now).ready:
		_closing_at = now


func cancel(now: float) -> void:
	match status(port, now).phase:
		"opening", "open": _closing_at = now
		"queued": clear()


func _closing_duration() -> float:
	var fraction := clampf((_closing_at - _opening_at) / OPENING_SECONDS, 0.0, 1.0)
	return fraction * CLOSING_SECONDS


func clear() -> void:
	port = -1
	_requested_at = 0.0
	_opening_at = 0.0
	_closing_at = 0.0


func snapshot() -> Dictionary:
	return {"port": port, "requested_at": _requested_at, "opening_at": _opening_at, "closing_at": _closing_at}


func restore(raw: Variant, now: float) -> bool:
	if not _number_in_range(now, 0.0, MAX_EPOCH) or not raw is Dictionary or raw.size() != SAVE_FIELDS.size() or not raw.has_all(SAVE_FIELDS):
		return false
	if not _number_in_range(raw.port, -1.0, Catalog.DESTINATION_COUNT - 1) or float(raw.port) != floorf(float(raw.port)):
		return false
	var site := int(raw.port)
	if site == -1:
		if not _number_in_range(raw.requested_at, 0.0, 0.0) or not _number_in_range(raw.opening_at, 0.0, 0.0) or not _number_in_range(raw.closing_at, 0.0, 0.0):
			return false
		clear()
		return true
	if not Catalog.is_port(site) or not _number_in_range(raw.requested_at, 0.0, minf(MAX_EPOCH, now + CLOCK_PRECISION)):
		return false
	var requested_at := float(raw.requested_at)
	if not _number_in_range(raw.opening_at, requested_at + HEADING_SECONDS - CLOCK_PRECISION,
			requested_at + MAX_QUEUE_SECONDS + CLOCK_PRECISION):
		return false
	var opening_at := float(raw.opening_at)
	var ready_at := opening_at + OPENING_SECONDS
	if not _number_in_range(raw.closing_at, opening_at - CLOCK_PRECISION, ready_at + CLEARANCE_SECONDS + CLOCK_PRECISION):
		return false
	var closing_at := float(raw.closing_at)
	# Early closure is caused by capture, departure, or cancellation at the current epoch.
	if closing_at < ready_at + CLEARANCE_SECONDS - CLOCK_PRECISION and closing_at > now + CLOCK_PRECISION:
		return false
	port = site
	_requested_at = requested_at
	_opening_at = opening_at
	_closing_at = closing_at
	return true


static func _departure_and_arrival_wait(site: int, traffic: Array[Dictionary]) -> float:
	var wait := HEADING_SECONDS
	for contact in traffic:
		if contact.get("in_transit", false):
			var eta: Variant = contact.get("arrival_eta")
			if contact.get("destination", -1) == site and _number_in_range(eta, 0.0, TRAFFIC_LOOKAHEAD):
				wait = maxf(wait, float(eta) + TRAFFIC_BUFFER)
			if contact.get("origin", -1) == site and _number_in_range(eta, Freight.TRANSIT_SECONDS - TRAFFIC_EXIT_BUFFER, Freight.TRANSIT_SECONDS):
				wait = maxf(wait, float(eta) - Freight.TRANSIT_SECONDS + TRAFFIC_EXIT_BUFFER)
		elif contact.get("origin", -1) == site:
			var eta: Variant = contact.get("departure_eta")
			if _number_in_range(eta, 0.0, TRAFFIC_LOOKAHEAD):
				wait = maxf(wait, float(eta) + TRAFFIC_BUFFER)
	return wait


static func _status(phase: String, open_fraction: float, wait: float, remaining := 0.0) -> Dictionary:
	return {"phase": phase, "open_fraction": open_fraction, "ready": phase == "open", "wait": wait, "remaining": remaining}


static func _number_in_range(value: Variant, lower: float, upper: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= lower and value <= upper
