extends RefCounted
## Live drive condition and fading records left by completed jump transitions.

const ANALYZER_COST := 190
const ANALYZER_RANGE := 1400.0
const LIFETIME := 100.0
const MAX_TRAILS := 12
const MAX_EPOCH := 3155760000.0
const MAX_ID := 2147483647
const CLOCK_SLACK := 0.00001
const TIME_TICKS := 1000000.0
const KG_PER_TONNE := 1000.0
const DEPARTURE := "departure"
const INCOMING := "incoming"
const RESIDUAL := "residual"
const PLAYER_FIELDS := ["id", "kind", "origin", "destination", "position", "mass", "created", "due"]

var installed := false
var drive_fault := false
var _next_id := 1
var _trails: Array[Dictionary] = []


func record(kind: String, origin: int, destination: int, position: Vector3, mass: float, epoch: float, due: float) -> void:
	if _next_id >= MAX_ID:
		return
	advance(epoch)
	if _trails.size() >= MAX_TRAILS:
		_trails.pop_front()
	_trails.append({"id": _next_id, "kind": kind, "origin": origin, "destination": destination,
		"position": position, "mass": mass, "created": epoch, "due": due})
	_next_id += 1


func advance(epoch: float) -> void:
	while not _trails.is_empty() and epoch - float(_trails.front().created) >= LIFETIME:
		_trails.pop_front()


func local(system: int, epoch: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for trail: Dictionary in _trails:
		var departure: bool = trail.kind == DEPARTURE
		var location := int(trail.origin if departure else trail.destination)
		var remaining := LIFETIME - (epoch - float(trail.created))
		if location != system or remaining <= 0.0:
			continue
		result.append({"id": "player-jump-%d" % int(trail.id), "name": "След вашего корабля", "kind": trail.kind,
			"position": trail.position, "origin": trail.origin, "destination": trail.destination,
			"mass": trail.mass, "eta": maxf(0.0, float(trail.due) - epoch) if departure else -1.0, "remaining": remaining})
	return result


func snapshot() -> Dictionary:
	var encoded: Array[Dictionary] = []
	for trail: Dictionary in _trails:
		var position: Vector3 = trail.position
		# Integral microseconds and kilograms survive a cold JSON round trip exactly.
		encoded.append({"id": trail.id, "kind": trail.kind, "origin": trail.origin, "destination": trail.destination,
			"position": [position.x, position.y, position.z], "mass": roundi(float(trail.mass) * KG_PER_TONNE),
			"created": roundi(float(trail.created) * TIME_TICKS), "due": roundi(float(trail.due) * TIME_TICKS)})
	return {"installed": installed, "drive_fault": drive_fault, "next_id": _next_id, "trails": encoded}


func restore(value: Variant, epoch: float, known: Array[int]) -> bool:
	if not value is Dictionary or value.size() != 4 or not value.get("installed") is bool or not value.get("drive_fault") is bool:
		return false
	if not _number(value.get("next_id"), 1.0, MAX_ID) or int(value.next_id) != value.next_id:
		return false
	if not value.get("trails") is Array or value.trails.size() > MAX_TRAILS:
		return false
	var restored: Array[Dictionary] = []
	var last_id := 0
	var last_time := 0.0
	for item: Variant in value.trails:
		if not item is Dictionary or item.size() != PLAYER_FIELDS.size() or not item.has_all(PLAYER_FIELDS):
			return false
		if not _number(item.id, float(last_id + 1), float(value.next_id) - 1.0) or int(item.id) != item.id:
			return false
		if item.kind not in [DEPARTURE, RESIDUAL] or not _valid_system(item.origin, known) or not _valid_system(item.destination, known):
			return false
		if item.origin == item.destination or not _integer(item.mass, 35.0 * KG_PER_TONNE, 150.0 * KG_PER_TONNE):
			return false
		if not _integer(item.created, last_time * TIME_TICKS - 0.5, (epoch + CLOCK_SLACK) * TIME_TICKS):
			return false
		var created := float(item.created) / TIME_TICKS
		if epoch - created >= LIFETIME + CLOCK_SLACK:
			return false
		if not _integer(item.due, float(item.created), MAX_EPOCH * TIME_TICKS) or (item.kind == RESIDUAL and item.due != item.created):
			return false
		if not item.position is Array or item.position.size() != 3:
			return false
		for axis: Variant in item.position:
			if not _number(axis, -10000000.0, 10000000.0):
				return false
		last_id = int(item.id)
		last_time = created
		restored.append({"id": last_id, "kind": str(item.kind), "origin": int(item.origin), "destination": int(item.destination),
			"position": Vector3(item.position[0], item.position[1], item.position[2]), "mass": float(item.mass) / KG_PER_TONNE,
			"created": created, "due": float(item.due) / TIME_TICKS})
	installed = value.installed
	drive_fault = value.drive_fault
	_next_id = int(value.next_id)
	_trails = restored
	return true


static func _valid_system(id: Variant, known: Array[int]) -> bool:
	return (id is int or id is float) and is_finite(float(id)) and float(id) == floorf(float(id)) and int(id) in known


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


static func _integer(value: Variant, low: float, high: float) -> bool:
	return _number(value, low, high) and float(value) == floorf(float(value))
