extends RefCounted
## Plans only through discovered systems and uses the tank's capacity per leg.
## An optional first-leg budget accounts for fuel already in the tank.

const Catalog := preload("res://scripts/sector_catalog.gd")


static func plan(origin: int, goal: int, known: Array[int], capacity: float, first_budget := INF) -> Dictionary:
	if not _valid_system(origin) or not _valid_system(goal):
		return _unavailable("Выберите звёздную систему")
	if origin == goal:
		return _unavailable("Корабль уже в выбранной системе")
	if origin not in known or goal not in known:
		return _unavailable("Для маршрута нужны известные системы")
	var no_route := "До цели нет маршрута в пределах ёмкости бака"
	if not _valid_capacity(capacity):
		return _unavailable(no_route)
	if first_budget < capacity:
		no_route = "До цели нет маршрута с текущим запасом топлива"
	if is_nan(first_budget) or first_budget <= 0.0:
		return _unavailable(no_route)
	var launch_limit := minf(capacity, first_budget)
	var remaining: Array[int] = []
	for system in range(Catalog.SYSTEM_COUNT):
		if system in known:
			remaining.append(system)
	var first: Array[int] = [origin]
	var best: Dictionary[int, Dictionary] = {origin: {"fuel": 0, "path": first}}
	while not remaining.is_empty():
		var current := -1
		var label := {}
		for candidate: int in remaining:
			if best.has(candidate) and _better(best[candidate], label):
				current = candidate
				label = best[candidate]
		if current < 0:
			break
		if current == goal:
			return describe(label.path)
		remaining.erase(current)
		# Costs are positive: every prefix of an optimal route settles before its endpoint.
		var leg_limit := launch_limit if current == origin else capacity
		for destination: int in remaining:
			var fuel := Catalog.jump_cost(current, destination)
			if fuel <= 0 or fuel > leg_limit:
				continue
			var path: Array[int] = label.path.duplicate()
			path.append(destination)
			var proposed := {"fuel": int(label.fuel) + fuel, "path": path}
			if _better(proposed, best.get(destination, {})):
				best[destination] = proposed
	return _unavailable(no_route)


static func describe(path: Array[int]) -> Dictionary:
	if not _valid_nodes(path):
		return _unavailable("Укажите маршрут между разными системами без повторов")
	var legs: Array[Dictionary] = []
	var total_fuel := 0
	var total_distance := 0.0
	for index in range(1, path.size()):
		var origin := path[index - 1]
		var destination := path[index]
		var fuel := Catalog.jump_cost(origin, destination)
		if fuel <= 0:
			return _unavailable("Один из переходов маршрута недоступен")
		var distance := Catalog.jump_distance(origin, destination)
		legs.append({"origin": origin, "destination": destination, "fuel": fuel, "distance": distance})
		total_fuel += fuel
		total_distance += distance
	return {
		"available": true, "path": path.duplicate(), "legs": legs, "fuel": total_fuel,
		"distance": total_distance, "next": path[1], "goal": path[-1], "reason": "",
	}


static func valid_path(path: Array[int], known: Array[int], capacity: float) -> bool:
	if not _valid_capacity(capacity) or not _valid_nodes(path):
		return false
	for system: int in path:
		if system not in known:
			return false
	for index in range(1, path.size()):
		var fuel := Catalog.jump_cost(path[index - 1], path[index])
		if fuel <= 0 or fuel > capacity:
			return false
	return true


static func _better(candidate: Dictionary, incumbent: Dictionary) -> bool:
	if incumbent.is_empty():
		return true
	if candidate.fuel != incumbent.fuel:
		return candidate.fuel < incumbent.fuel
	var path: Array[int] = candidate.path
	var previous: Array[int] = incumbent.path
	if path.size() != previous.size():
		return path.size() < previous.size()
	for index in range(path.size()):
		if path[index] != previous[index]:
			return path[index] < previous[index]
	return false


static func _valid_nodes(path: Array[int]) -> bool:
	if path.size() < 2 or path.size() > Catalog.SYSTEM_COUNT:
		return false
	var seen: Dictionary[int, bool] = {}
	for system: int in path:
		if not _valid_system(system) or seen.has(system):
			return false
		seen[system] = true
	return true


static func _valid_system(system: int) -> bool:
	return system >= 0 and system < Catalog.SYSTEM_COUNT


static func _valid_capacity(capacity: float) -> bool:
	return is_finite(capacity) and capacity > 0.0


static func _unavailable(reason: String) -> Dictionary:
	var path: Array[int] = []
	var legs: Array[Dictionary] = []
	return {
		"available": false, "path": path, "legs": legs, "fuel": 0, "distance": 0.0,
		"next": -1, "goal": -1, "reason": reason,
	}
