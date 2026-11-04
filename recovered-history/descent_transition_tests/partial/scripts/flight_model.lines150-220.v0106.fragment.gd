	return true

func snapshot() -> Dictionary:
	return {"version": 4,"story_cargo":story_cargo, "goods":goods.duplicate(),"equipment":equipment.duplicate(),"mission_cargo":mission_cargo.duplicate(),"ship_id":ship_id,"external_view":external_view, "position": [position.x, position.y, position.z], "velocity": [velocity.x, velocity.y, velocity.z], "attitude": [attitude.x, attitude.y, attitude.z, attitude.w], "target_speed": target_speed, "assisted": assisted, "docked": docked, "hull": hull, "credits": credits, "cargo": cargo, "delivered": delivered}

func restore(data: Dictionary) -> bool:
	if data.get("version",0)!=1 and data.get("version",0)!=2 and data.get("version",0)!=3 and data.get("version",0)!=4:
		return false
	var saved_id := "cobra"
	if data.get("version",0)==2 or data.get("version",0)==3 or data.get("version",0)==4:
		if not data.get("ship_id") is String or catalog.get_ship(data.ship_id).is_empty():return false
		saved_id=data.ship_id
	for key in ["position", "velocity", "attitude"]:
		var a: Variant = data.get(key)
		var count := 4 if key == "attitude" else 3
		if not a is Array or a.size() != count:
			return false
		for v in a:
			if not (v is float or v is int) or not is_finite(float(v)) or absf(float(v)) > 1.0e9:
				return false
	for key in ["target_speed", "hull", "credits", "cargo"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):
			return false
	if float(data.credits) < 0 or float(data.credits) > 1.0e9 or float(data.cargo) < 0 or float(data.cargo) > float(catalog.get_ship(saved_id).cargo_capacity):
		return false
	if float(data.credits)!=floorf(float(data.credits)) or float(data.cargo)!=floorf(float(data.cargo)): return false
	if data.get("version",0)==1 and data.cargo>10: return false
	var loaded_goods:=economy_catalog.empty_manifest()
	loaded_goods.medicines=int(data.cargo)
	var loaded_equipment: Array=[]
	var loaded_missions: Dictionary={}
	if data.get("version",0)==3 or data.get("version",0)==4:
		if not data.get("goods") is Dictionary or not data.get("equipment") is Array or not data.get("mission_cargo") is Dictionary:return false
		for id in data.goods:
			if not economy_catalog.goods.has(id) or not _whole_quantity(data.goods[id]):return false
			loaded_goods[id]=int(data.goods[id])
		if loaded_goods.medicines!=data.cargo:return false
		for id in data.equipment:
			if not id is String or not economy_catalog.equipment.has(id) or id in loaded_equipment:return false
			loaded_equipment.append(id)
		if data.mission_cargo.size()>3:return false
		for id in data.mission_cargo:
			if not id is String or id.length()>100 or not _whole_quantity(data.mission_cargo[id]) or data.mission_cargo[id]<=0:return false
			loaded_missions[id]=int(data.mission_cargo[id])
	var loaded_story:=0
	if data.get("version",0)==4:
		if not _whole_quantity(data.get("story_cargo")) or (data.story_cargo!=0 and data.story_cargo!=2):return false
		loaded_story=int(data.story_cargo)
	var used:=loaded_story
	for count in loaded_goods.values():used+=int(count)
	for count in loaded_missions.values():used+=int(count)
	for id in loaded_equipment:used+=int(economy_catalog.equipment[id].space)
	if used>int(catalog.get_ship(saved_id).cargo_capacity):return false
	var q: Array = data.attitude
	var restored_q := Quaternion(q[0], q[1], q[2], q[3])
	if restored_q.length_squared() < 0.01:
		return false
	var p: Array = data.position
	var v: Array = data.velocity
	original_port=false
	story_cargo=loaded_story
	goods=loaded_goods;equipment=loaded_equipment;mission_cargo=loaded_missions
	ship_id=saved_id
	external_view=bool(data.get("external_view",false))
	position = Vector3(p[0], p[1], p[2])
	velocity = Vector3(v[0], v[1], v[2])
	attitude = restored_q.normalized()
	target_speed = clampf(data.target_speed, -100.0, MAX_SPEED)
	assisted = bool(data.get("assisted", true))
	docked = bool(data.get("docked", false))
	hull = clampf(data.hull, 0.0, 100.0)
