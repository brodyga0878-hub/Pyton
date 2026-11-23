extends RefCounted
## Plans only through discovered systems and uses the tank's capacity per leg.
## An optional first-leg budget accounts for fuel already in the tank.
## Fare and travel-time callbacks take the origin and destination of a leg.

const Catalog := preload("res://scripts/sector_catalog.gd")


class RouteLabel extends RefCounted:
	var system: int
	var fuel: int
	var nodes: int
	var previous: RouteLabel

	func _init(destination: int, fare: int, prefix: RouteLabel = null) -> void:
		system = destination
		fuel = fare
		nodes = 1 if prefix == null else prefix.nodes + 1
		previous = prefix

	func path() -> Array[int]:
		var result: Array[int] = []
		result.resize(nodes)
		var point := self
		for index in range(nodes - 1, -1, -1):
			result[index] = point.system
			point = point.previous
		return result


static func plan(origin: int, goal: int, known: Array[int], capacity: float, first_budget := INF,
		tariff: Callable = Callable(), duration: Callable = Callable(), nearby: Callable = Callable()) -> Dictionary:
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
	var included: Dictionary[int, bool] = {}
	for system: int in known:
		if _valid_system(system):
			included[system] = true
	var first := RouteLabel.new(origin, 0)
	var best: Dictionary[int, RouteLabel] = {origin: first}
	var queue: Array[RouteLabel] = [first]
	while not queue.is_empty():
		var label := _pop_label(queue)
		var current := label.system
		if not included.has(current) or label != best[current]:
			continue
		if current == goal:
			return describe(label.path(), tariff, duration)
		included.erase(current)
		best.erase(current)
		# Costs are positive: every prefix of an optimal route settles before its endpoint.
		var leg_limit := launch_limit if current == origin else capacity
		var candidates: Array = nearby.call(current, leg_limit) if nearby.is_valid() else included.keys()
		for destination: int in candidates:
			if not included.has(destination):
				continue
			var fuel := _leg_cost(current, destination, tariff)
			if fuel <= 0 or fuel > leg_limit:
				continue
			var cost := label.fuel + fuel
			var existing: RouteLabel = best.get(destination)
			if existing != null and (cost > existing.fuel or (cost == existing.fuel and label.nodes + 1 > existing.nodes)):
				continue
			var proposed := RouteLabel.new(destination, cost, label)
			if _better(proposed, existing):
				best[destination] = proposed
				_push_label(queue, proposed)
	return _unavailable(no_route)


static func describe(path: Array[int], tariff: Callable = Callable(), duration: Callable = Callable()) -> Dictionary:
	if not _valid_nodes(path):
		return _unavailable("Укажите маршрут между разными системами без повторов")
	var legs: Array[Dictionary] = []
	var total_fuel := 0
	var total_distance := 0.0
	var total_seconds := 0.0
	var include_duration := duration.is_valid()
	for index in range(1, path.size()):
		var origin := path[index - 1]
		var destination := path[index]
		var fuel := _leg_cost(origin, destination, tariff)
		if fuel <= 0:
			return _unavailable("Один из переходов маршрута недоступен")
		var distance := Catalog.jump_distance(origin, destination)
		var leg := {"origin": origin, "destination": destination, "fuel": fuel, "distance": distance}
		if include_duration:
			var seconds := float(duration.call(origin, destination))
			if not is_finite(seconds) or seconds <= 0.0:
				return _unavailable("Для одного из переходов не рассчитано время")
			leg.seconds = seconds
			total_seconds += seconds
		legs.append(leg)
		total_fuel += fuel
		total_distance += distance
	var route := {
		"available": true, "path": path.duplicate(), "legs": legs, "fuel": total_fuel,
		"distance": total_distance, "next": path[1], "goal": path[-1], "reason": "",
	}
	if include_duration:
		route.seconds = total_seconds
	return route


static func valid_path(path: Array[int], known: Array[int], capacity: float, tariff: Callable = Callable()) -> bool:
	if not _valid_capacity(capacity) or not _valid_nodes(path):
		return false
	var discovered: Dictionary[int, bool] = {}
	for system: int in known:
		discovered[system] = true
	for system: int in path:
		if not discovered.has(system):
			return false
	for index in range(1, path.size()):
		var fuel := _leg_cost(path[index - 1], path[index], tariff)
		if fuel <= 0 or fuel > capacity:
			return false
	return true


static func _leg_cost(origin: int, destination: int, tariff: Callable) -> int:
	return int(tariff.call(origin, destination)) if tariff.is_valid() else Catalog.jump_cost(origin, destination)


static func _better(candidate: RouteLabel, incumbent: RouteLabel) -> bool:
	if incumbent == null:
		return true
	if candidate.fuel != incumbent.fuel:
		return candidate.fuel < incumbent.fuel
	if candidate.nodes != incumbent.nodes:
		return candidate.nodes < incumbent.nodes
	# Traverse equal-depth paths backwards. An earlier mismatch wins.
	var smaller := false
	while candidate != incumbent:
		if candidate.system != incumbent.system:
			smaller = candidate.system < incumbent.system
		candidate = candidate.previous
		incumbent = incumbent.previous
	return smaller


static func _push_label(queue: Array[RouteLabel], label: RouteLabel) -> void:
	var index := queue.size()
	queue.append(label)
	while index > 0:
		var parent := (index - 1) >> 1
		if not _better(label, queue[parent]):
			break
		queue[index] = queue[parent]
		index = parent
	queue[index] = label


static func _pop_label(queue: Array[RouteLabel]) -> RouteLabel:
	var first := queue.front() as RouteLabel
	var tail := queue.pop_back() as RouteLabel
	if queue.is_empty():
		return first
	var index := 0
	var child := 1
	while child < queue.size():
		if child + 1 < queue.size() and _better(queue[child + 1], queue[child]):
			child += 1
		if not _better(queue[child], tail):
			break
		queue[index] = queue[child]
		index = child
		child = index * 2 + 1
	queue[index] = tail
	return first


static func _valid_nodes(path: Array[int]) -> bool:
	if path.size() < 2 or path.size() > Catalog.SYSTEM_ID_LIMIT:
		return false
	var seen: Dictionary[int, bool] = {}
	for system: int in path:
		if not _valid_system(system) or seen.has(system):
			return false
		seen[system] = true
	return true


static func _valid_system(system: int) -> bool:
	return Catalog.is_system_id(system)


static func _valid_capacity(capacity: float) -> bool:
	return is_finite(capacity) and capacity > 0.0


static func _unavailable(reason: String) -> Dictionary:
	var path: Array[int] = []
	var legs: Array[Dictionary] = []
	return {
		"available": false, "path": path, "legs": legs, "fuel": 0, "distance": 0.0,
		"next": -1, "goal": -1, "reason": reason,
	}
