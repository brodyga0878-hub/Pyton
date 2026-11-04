class_name Galaxy
extends RefCounted
# Newly rebuilt bounded catalogue. System IDs/names come from the extracted
# handcrafted table; navigation positions below are an explicit adapter, not
# a recovered FFE galaxy generator or original sector coordinates.
const SOL_ID:=0x02a49718
const CATALOG_PATH:="res://data/ffe_worlds.json"
var stars:Array=[]
var by_id:Dictionary={}
var catalogue_mode:="reconstructed_sol_only_v1"
var source_digest:=""

func _init()->void:reload_catalog()

func reload_catalog()->void:
	stars.clear();by_id.clear()
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

func get_system(id:int)->Dictionary:return by_id.get(id,{}).duplicate(true)
func all()->Array:return stars.duplicate(true)
func system_count()->int:return stars.size()

func search(query:String)->Array:
	var needle:=query.strip_edges().to_lower();var result:Array=[]
	for star in stars:
		if needle.is_empty() or str(star.name).to_lower().contains(needle) or str(star.original_name).to_lower().contains(needle):result.append(star.duplicate(true))
	return result

func distance(first:int,second:int)->float:
	if not by_id.has(first) or not by_id.has(second):return INF
	var a:Array=by_id[first].position_ly;var b:Array=by_id[second].position_ly
	return sqrt(pow(float(a[0])-float(b[0]),2)+pow(float(a[1])-float(b[1]),2)+pow(float(a[2])-float(b[2]),2))
