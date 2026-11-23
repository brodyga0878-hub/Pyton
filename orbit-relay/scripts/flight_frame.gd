extends RefCounted
## Selects a reference for flight readouts and manual controls.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const Ground = preload("res://scripts/ground_port.gd")

const AUTO := -2
const SYSTEM := -1
const ENTER_MARGIN := 108.0
const MOON_ENTER_MARGIN := 75.0
const LEAVE_MARGIN := 136.0
const SWITCH_RATIO := 0.83

var choice: int = AUTO
var auto_site: int = SYSTEM
var rotating := false


func reference_site(sim: RefCounted) -> int:
	if sim.docked >= 0:
		return sim.docked
	if sim.landed_site >= 0:
		return sim.landed_site
	if choice == SYSTEM:
		return SYSTEM
	var available: Array = sim.local_targets()
	if choice >= 0:
		if _allowed_site(choice, available):
			return choice
		choice = AUTO
		rotating = false
	return _auto_reference(sim, available)


func select(request: int, next_allowed: Array, body_fixed := false) -> bool:
	if request != AUTO and request != SYSTEM and not _allowed_site(request, next_allowed):
		return false
	if body_fixed and not supports_rotation(request):
		return false
	choice = request
	rotating = body_fixed
	auto_site = SYSTEM
	return true


func reset_on_arrival() -> void:
	if choice != SYSTEM:
		choice = AUTO
	auto_site = SYSTEM
	rotating = false


func snapshot() -> Dictionary:
	return {"choice": choice, "auto_site": auto_site, "rotating": rotating}


func restore(raw: Variant, allowed: Array) -> bool:
	if not raw is Dictionary or raw.size() not in [2, 3] or (raw.size() == 3 and not raw.get("rotating") is bool):
		return false
	if not _valid_number(raw.get("choice"), AUTO) or not _valid_number(raw.get("auto_site"), SYSTEM):
		return false
	var saved_choice := int(raw.choice)
	var saved_auto := int(raw.auto_site)
	if saved_choice >= 0 and not _allowed_site(saved_choice, allowed):
		return false
	if saved_auto >= 0 and (saved_choice != AUTO or not _allowed_site(saved_auto, allowed) or not _auto_eligible(saved_auto)):
		return false
	var saved_rotation: bool = raw.get("rotating", false)
	if saved_rotation and not supports_rotation(saved_choice):
		return false
	choice = saved_choice
	auto_site = saved_auto
	rotating = saved_rotation
	return true


static func supports_rotation(site: int) -> bool:
	if site < 0:
		return false
	if Catalog.is_port(site) and not Ground.is_port(site):
		return not is_zero_approx(float(Catalog.site(site).spin))
	return Terrain.spin_rate(Ground.body(site) if Ground.is_port(site) else site) > 0.0


func _auto_reference(sim: RefCounted, available: Array) -> int:
	var position: Vector3 = sim.position
	var best := SYSTEM
	var best_score := INF
	var retained_score := INF
	for id: int in available:
		if not _auto_eligible(id):
			continue
		var margin := MOON_ENTER_MARGIN if id == Catalog.BINARY_MOON else ENTER_MARGIN
		var clearance := maxf(0.0, position.distance_to(sim.target_position(id)) - float(Catalog.site(id).radius))
		var score := clearance / margin
		if id == auto_site and clearance <= LEAVE_MARGIN:
			retained_score = score
		if clearance <= margin and (score < best_score or (score == best_score and id < best)):
			best = id
			best_score = score
	if retained_score < INF and best_score >= retained_score * SWITCH_RATIO:
		return auto_site
	auto_site = best
	return auto_site


static func _allowed_site(id: int, allowed: Array) -> bool:
	return Catalog.is_site_id(id) and id in allowed


static func _auto_eligible(id: int) -> bool:
	return not Catalog.is_star(id) or Orbit.period(id) > 0.0


static func _valid_number(raw: Variant, minimum: int) -> bool:
	return (raw is int or raw is float) and is_finite(raw) and raw == floorf(raw) \
		and raw >= minimum and raw < Catalog.SITE_ID_LIMIT \
		and (raw < 0 or Catalog.is_site_id(int(raw)))
