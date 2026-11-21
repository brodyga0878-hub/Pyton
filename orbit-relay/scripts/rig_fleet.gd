extends RefCounted

const Rig := preload("res://scripts/unattended_mining.gd")
const LIMIT := 3
const PRICE := 145
const RESALE := 65

var units: Array[RefCounted] = [Rig.new()]
var selected := 0


func current() -> RefCounted:
	return units[selected]


func active_at(site: int) -> bool:
	for unit: RefCounted in units:
		if unit.active() and (site < 0 or unit.site_id == site):
			return true
	return false


func offload() -> bool:
	if selected == 0 or units[selected].active():
		return false
	units.remove_at(selected)
	selected = 0
	return true


func snapshot() -> Dictionary:
	var extra: Array[Dictionary] = []
	for slot in range(1, units.size()):
		extra.append(units[slot].snapshot())
	return {"selected": selected, "extra": extra}


func restore(raw: Variant, first: RefCounted, epoch: float, mining: RefCounted, available: Callable) -> bool:
	if not raw is Dictionary or raw.size() != 2 or not raw.get("extra") is Array or raw.extra.size() >= LIMIT:
		return false
	var slot: Variant = raw.get("selected")
	if not (slot is int or slot is float) or not is_finite(float(slot)) or slot != int(slot) or slot < 0 or slot > raw.extra.size():
		return false
	var restored: Array[RefCounted] = [first]
	var installed := stored_by_site(restored)
	for state: Variant in raw.extra:
		var unit := Rig.new()
		if not unit.restore(state, epoch, mining):
			return false
		if unit.active():
			if installed.has(unit.site_id) or not available.call(unit.site_id):
				return false
			installed[unit.site_id] = unit.stored
		restored.append(unit)
	units = restored
	selected = int(slot)
	return true


static func stored_by_site(rigs: Array[RefCounted]) -> Dictionary:
	var counts := {}
	for unit: RefCounted in rigs:
		if unit.active():
			counts[unit.site_id] = unit.stored
	return counts
