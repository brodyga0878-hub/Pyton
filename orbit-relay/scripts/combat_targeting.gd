extends RefCounted

const Convoys := preload("res://scripts/convoy_orders.gd")
const Traffic := preload("res://scripts/sector_traffic.gd")
const SCANNER_RANGE := 1400.0
const MAPPER_PRICE := 850
const LOCK_LIMIT := 64

var lock_id := ""
var mapper_fitted := false


static func airborne(sim: RefCounted) -> bool:
	return sim.docked < 0 and not sim.landed and sim.jump_seconds_left <= 0.0 and sim.ship.hull > 1.0


static func attackable(sim: RefCounted) -> Dictionary:
	var contacts := {}
	if not airborne(sim):
		return contacts
	for row: Dictionary in sim.patrol.contacts(sim):
		row.channel = "patrol"
		contacts[row.id] = row
	var raid: Dictionary = sim.ambient.status(sim)
	if raid.hostile and raid.hull > 0.0:
		raid.channel = "ambient"
		contacts[raid.id] = raid
	var order: Dictionary = sim.convoy_order.status(sim)
	if order.phase == Convoys.ACTIVE and order.local and order.kind == Convoys.INTERCEPT and order.enemy_hull > 0.0:
		var convoy := Traffic.convoy_contact(sim, order.id)
		if not convoy.is_empty():
			convoy.hull = order.enemy_hull
			convoy.channel = "convoy"
			contacts[convoy.id] = convoy
	var operation: Dictionary = sim.operation_contact()
	if not operation.is_empty():
		contacts[operation.id] = operation
	return contacts


func current(sim: RefCounted) -> Dictionary:
	if lock_id.is_empty():
		return {}
	var contact: Dictionary = attackable(sim).get(lock_id, {})
	if contact.is_empty() or sim.position.distance_squared_to(contact.position) > SCANNER_RANGE * SCANNER_RANGE:
		lock_id = ""
		return {}
	return contact


func select(sim: RefCounted, id: String) -> bool:
	var contact: Dictionary = attackable(sim).get(id, {})
	if not can_lock(sim, contact):
		return false
	lock_id = id
	return true


static func can_lock(sim: RefCounted, contact: Dictionary) -> bool:
	return not contact.is_empty() and sim.position.distance_squared_to(contact.position) <= SCANNER_RANGE * SCANNER_RANGE \
		and sim.combat_line_clear(sim.position, contact.position)


func scanner(sim: RefCounted, contacts: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not airborne(sim):
		return result
	var hostile := attackable(sim)
	var frame: Basis = sim.attitude().transposed()
	for contact: Dictionary in contacts:
		var offset: Vector3 = contact.position - sim.position
		var distance := offset.length()
		if distance > SCANNER_RANGE:
			continue
		var drift: Vector3 = contact.velocity - sim.velocity
		result.append({
			"id": contact.id, "name": contact.name, "role": contact.role,
			"relative": frame * offset, "distance": distance, "relative_speed": drift.length(),
			"hull": contact.hull, "attackable": hostile.has(contact.id),
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return left.distance < right.distance if left.distance != right.distance else left.id < right.id)
	return result


func snapshot(sim: RefCounted) -> Dictionary:
	current(sim)
	return {"lock": lock_id, "radar_mapper": mapper_fitted}


func restore(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() != 2 or not raw.get("lock") is String or not raw.get("radar_mapper") is bool:
		return false
	var id: String = raw.lock
	if id.length() > LOCK_LIMIT:
		return false
	lock_id = id
	mapper_fitted = raw.radar_mapper
	return true
