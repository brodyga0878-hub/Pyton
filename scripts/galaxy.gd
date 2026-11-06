class_name Galaxy
extends RefCounted
# Newly rebuilt bounded catalogue. System IDs/names come from the extracted
# handcrafted table; navigation positions below are an explicit adapter, not
# a recovered FFE galaxy generator or original sector coordinates.
const SOL_ID:=0x02a49718
const CATALOG_PATH:="res://data/ffe_worlds.json"
const NativeKernel=preload("res://scripts/source_galaxy.gd")
const NATIVE_MODE:="ffe_native_sectors_v1"
const DEFINITION_PATH:="res://scripts/source_system_definition.gd"
const MAX_SECTORS:=24
const MAX_ROWS:=768
var stars:Array=[]
var by_id:Dictionary={}
var catalogue_mode:="reconstructed_sol_only_v1"
var source_digest:=""
var focus_id:=SOL_ID
var _kernel:RefCounted
var _definition:RefCounted
var _sectors:Dictionary={}
var _sector_order:Array=[]
var _row_order:Array=[]
var _sol_q16:PackedInt64Array=PackedInt64Array()

func _init()->void:reload_catalog()

func reload_catalog()->void:
	stars.clear();by_id.clear();_kernel=null;_definition=null;_sectors.clear();_sector_order.clear();_row_order.clear();_sol_q16.clear();focus_id=SOL_ID
	var systems:Array=[]
	if FileAccess.file_exists(CATALOG_PATH):
		var raw:=FileAccess.get_file_as_string(CATALOG_PATH)
		var parsed:Variant=JSON.parse_string(raw)
		if parsed is Dictionary and parsed.get("systems") is Array:
			systems=parsed.systems
			source_digest=raw.sha256_text()
	if systems.is_empty():
		catalogue_mode="reconstructed_sol_only_v1"
		_add(SOL_ID,"Sol",0)
		return
	catalogue_mode="handcrafted_ids_adapted_map_v1"
	for entry in systems:
		if not entry is Dictionary or not _whole_id(entry.get("system_id")) or not entry.get("name_en") is String:continue
		_add(int(entry.system_id),str(entry.name_en),stars.size())
	if not by_id.has(SOL_ID):_add(SOL_ID,"Sol",0)

static func _whole_id(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=0 and float(value)<=4294967295.0

func _add(id:int,original_name:String,index:int)->void:
	if by_id.has(id):return
	# A connected, bounded development map keeps adjacent catalogue entries
	# reachable while the lost native galaxy/sector module is reconstructed.
	var position:Array=[float(index)*4.0,0.5*sin(float(index)),0.5*cos(float(index))-0.5]
	if original_name=="Sol":position=[0.0,0.0,0.0]
	var names:Dictionary={"Sol":"Солнце","Alpha Centauri A,B":"Альфа Центавра A,B","Wolf 630 A,B":"Вольф 630 A,B","61 Cygni A,B":"61 Лебедя A,B","Sirius, Sirius B":"Сириус и Сириус B","Eta Cassiopeia":"Эта Кассиопеи","Ross 154":"Росс 154","Lave":"Лейв","Diso":"Дисо","Leesti":"Листи","Zaonce":"Заонс"}
	var row:={"id":id,"name":str(names.get(original_name,original_name)),"original_name":original_name,"type_code":4,"type":"Звёздная система","sector":[floori(float(position[0])/8.0),floori(float(position[2])/8.0)],"position_ly":position,"coordinates_source":"reconstructed_navigation_layout_v1","has_station":true,"station_source":"reconstructed_arrival_dock_v1"}
	stars.append(row);by_id[id]=row

func is_native()->bool:return catalogue_mode==NATIVE_MODE

func configure_native()->bool:
	var kernel:=NativeKernel.new()
	var sol:Dictionary=kernel.system(SOL_ID)
	if sol.is_empty() or not sol.get("position_q16") is PackedInt64Array:return false
	_kernel=kernel;_definition=null;_sol_q16=sol.position_q16.duplicate()
	catalogue_mode=NATIVE_MODE;source_digest=(NativeKernel.SOURCE_VARIANT+":"+FileAccess.get_sha256(NativeKernel.DATA_PATH)).sha256_text()
	focus_id=SOL_ID;clear_native_cache()
	return true

func clear_native_cache()->void:
	if not is_native():return
	stars.clear();by_id.clear();_sectors.clear();_sector_order.clear();_row_order.clear()

func _touch(order:Array,key:Variant,limit:int)->Variant:
	order.erase(key);order.append(key)
	return order.pop_front() if order.size()>limit else null

func _sector(x:int,y:int)->Dictionary:
	if not is_native() or x<0 or x>=8192 or y<0 or y>=8192:return {}
	var key:=x|(y<<13)
	if _sectors.has(key):_touch(_sector_order,key,MAX_SECTORS);return _sectors[key]
	var generated:Dictionary=_kernel.sector(x,y)
	if generated.is_empty():return {}
	var evicted:Variant=_touch(_sector_order,key,MAX_SECTORS)
	if evicted!=null:_sectors.erase(evicted)
	_sectors[key]=generated
	return generated

func _native_system(id:int)->Dictionary:
	if not _whole_id(id):return {}
	var generated:=_sector(id&8191,(id>>13)&8191)
	var index:=(id>>26)&63
	if generated.is_empty() or index>=int(generated.count):return {}
	return generated.systems[index]

func _native_position(sample:Dictionary)->Array:
	var raw:PackedInt64Array=sample.position_q16
	return [float(raw[0]-_sol_q16[0])*8.0/65536.0,float(raw[1]-_sol_q16[1])*8.0/65536.0,float(raw[2]-_sol_q16[2])*8.0/65536.0]

func _native_row(id:int,sample:Dictionary)->Dictionary:
	# The source system definition is loaded lazily, keeping the independent
	# sector kernel usable while composition/text modules are being prepared.
	if _definition==null and FileAccess.file_exists(DEFINITION_PATH):
		var definition_script:Script=load(DEFINITION_PATH)
		if definition_script!=null:_definition=definition_script.new()
	var row:Dictionary={}
	if _definition!=null and _definition.has_method("describe"):
		var described:Variant=_definition.call("describe",id)
		if described is Dictionary:row=described.duplicate(true)
	var x:=id&8191;var y:=(id>>13)&8191;var index:=(id>>26)&63
	if row.is_empty():row={"name":"Система %d,%d №%d"%[x,y,index],"original_name":"System %d,%d #%d"%[x,y,index],"type":"Звёздная система"}
	row.id=id;row.sector=[x,y];row.position_q16=Array(sample.position_q16);row.position_ly=_native_position(sample)
	row.type_code=int(sample.star_type);row.star_count_code=int(sample.star_count_code)
	row.coordinates_source=NativeKernel.SOURCE_VARIANT;row.has_station=false;row.station_source="source_port_selection_required"
	return row

func get_system(id:int)->Dictionary:
	if not is_native():return by_id.get(id,{}).duplicate(true)
	# Validate against the source sector count even when a caller has inserted
	# a row into the public compatibility cache.
	var sample:=_native_system(id)
	if sample.is_empty():return {}
	if by_id.has(id):_touch(_row_order,id,MAX_ROWS);return by_id[id].duplicate(true)
	var row:=_native_row(id,sample)
	var evicted:Variant=_touch(_row_order,id,MAX_ROWS)
	if evicted!=null:by_id.erase(evicted)
	by_id[id]=row
	return row.duplicate(true)

func is_valid_id(id:int)->bool:return not _native_system(id).is_empty() if is_native() else by_id.has(id)

func set_focus(id:int)->bool:
	if get_system(id).is_empty():return false
	focus_id=id
	return true

func sector_page(x:int,y:int)->Array:
	var result:Array=[];var generated:=_sector(x,y)
	if generated.is_empty():return result
	for sample:Dictionary in generated.systems:result.append(get_system(int(sample.id)))
	return result

func all()->Array:
	if not is_native():return stars.duplicate(true)
	var result:Array=[];var x:=focus_id&8191;var y:=(focus_id>>13)&8191
	for dy in range(-1,2):
		for dx in range(-1,2):result.append_array(sector_page(x+dx,y+dy))
	stars=result
	return result.duplicate(true)

func system_count()->int:
	# The native galaxy is paged. -1 is an explicit unknown global count,
	# never a cache-dependent upper bound for saved visited IDs.
	return -1 if is_native() else stars.size()

func cache_state()->Dictionary:return {"sectors":_sectors.size(),"rows":by_id.size(),"sector_limit":MAX_SECTORS,"row_limit":MAX_ROWS}

func search(query:String)->Array:
	var needle:=query.strip_edges().to_lower();var result:Array=[]
	for star in all():
		if needle.is_empty() or str(star.name).to_lower().contains(needle) or str(star.original_name).to_lower().contains(needle):result.append(star.duplicate(true))
	return result

func distance(first:int,second:int)->float:
	var first_row:=get_system(first);var second_row:=get_system(second)
	if first_row.is_empty() or second_row.is_empty():return INF
	var a:Array=first_row.position_ly;var b:Array=second_row.position_ly
	return sqrt(pow(float(a[0])-float(b[0]),2)+pow(float(a[1])-float(b[1]),2)+pow(float(a[2])-float(b[2]),2))
