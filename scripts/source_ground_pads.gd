extends RefCounted
# Original F650 open-air pad targets, independent of rendered model312 markers.
# Physical target = signed32(F1669(table_vector, object_matrix) << 10).
# The caller supplies the city anchor, body rotation and landing permissions.
const Ground=preload("res://scripts/ground_coordinates.gd")
static var _assets:Dictionary={}
static var _asset_mutex:=Mutex.new()

static func _load()->void:
	_asset_mutex.lock()
	if _assets.is_empty():
		_assets=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_ground_pads.json"))
	_asset_mutex.unlock()

static func pad_count(model:int)->int:
	_load()
	var descriptor:Dictionary=_assets.models.get(str(model),{})
	return int(descriptor.get("pad_count",0))

static func table_vectors(model:int)->Array:
	_load()
	var descriptor:Dictionary=_assets.models.get(str(model),{})
	if descriptor.is_empty():return []
	return _assets.tables[descriptor.table].vectors_i32.duplicate(true)

static func raw_local_positions(model:int)->Array:
	# Ideal local anchors before orientation. Actual F650 positions must use
	# transformed_positions: Q31 rounding occurs BEFORE the final shift.
	var result:Array=[]
	for vector in table_vectors(model):
		result.append([Ground.signed32(int(vector[0])<<10),Ground.signed32(int(vector[1])<<10),Ground.signed32(int(vector[2])<<10)])
	return result

static func matrix_for_angles(phase:int,inclination:int)->Array:
	# Full original F1674 matrix, rows interpreted as basis vectors by F1669.
	var sp:=Ground.sin_q31(phase)
	var cp:=Ground.sin_q31(phase+0x4000)
	var sq:=Ground.sin_q31(inclination)
	var cq:=Ground.sin_q31(inclination+0x4000)
	return [Ground.signed32(-Ground.multiply_q31(cp,sq)),cq,Ground.multiply_q31(sq,sp),Ground.multiply_q31(cq,cp),sq,Ground.signed32(-Ground.multiply_q31(cq,sp)),Ground.signed32(-sp),0,Ground.signed32(-cp)]

static func transformed_positions(model:int,matrix_q31:Array)->Array:
	if matrix_q31.size()!=9:return []
	var result:Array=[]
	for vector in table_vectors(model):
		var target:Array=[]
		for axis in range(3):
			var total:=0
			for k in range(3):total+=Ground.multiply_q31(int(vector[k]),int(matrix_q31[k*3+axis]))
			target.append(Ground.signed32(Ground.signed32(total)<<10))
		result.append(target)
	return result

static func pick_highest_free(model:int,occupancy:Array=[])->int:
	var count:=pad_count(model)
	if count==0:return -1
	if occupancy.is_empty():return count-1
	if occupancy.size()<count:return -1
	for index in range(count-1,-1,-1):
		if (int(occupancy[index])&255)==0:return index
	return -1

static func allocate(model:int,identifier:int,occupancy:Array,matrix_q31:Array,last_pad_index:=-2)->Dictionary:
	# F650 performs ONE descending scan: first same signed-byte ID OR free
	# slot wins. This can allocate above a matching ID at a lower index.
	# This pure helper does not execute the original player's UI callbacks.
	var count:=pad_count(model)
	if count==0 or occupancy.size()<count or occupancy.size()>8 or matrix_q31.size()!=9:
		return {"ok":false,"error":"Invalid source ground pad state"}
	var last:=count-1 if last_pad_index==(-2) else last_pad_index
	if last<(-1) or last>=count:return {"ok":false,"error":"Source pad index outside extracted table"}
	var slots:Array=[]
	for value in occupancy:slots.append(int(value)&255)
	var owner:=Ground.signed32(identifier)
	var selected:=-1
	var status:=0
	for index in range(last,-1,-1):
		var slot:=int(slots[index])
		if slot>=128:slot-=256
		if slot==owner:
			selected=index
			break
		if slot==0:
			slots[index]=owner&255
			status=-1
			selected=index
			break
	if selected<0:return {"ok":false,"return_i32":-1,"occupancy_after_u8":slots,"error":"No source pad available"}
	return {"ok":true,"return_i32":0,"allocation_status_i32":status,"selected_pad_i32":selected,"target_vec64_raw":transformed_positions(model,matrix_q31)[selected],"occupancy_after_u8":slots}
