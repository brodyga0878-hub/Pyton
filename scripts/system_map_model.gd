extends RefCounted
# Read-only system-map consumer. Only this private World receives preview dates;
# no live World, navigation clock, ship or gameplay save is retained here.
const World=preload("res://scripts/planetary_system.gd")
const Orbit=preload("res://scripts/source_orbit.gd")
const Clock=preload("res://scripts/source_clock.gd")
const Units=preload("res://scripts/source_units.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const AU_METRES:=149597870700.0
const MAX_PREVIEW_DAYS:=36525.0
const ORBIT_SEGMENTS:=64
const MAX_RECORDS:=128
var configured:=false
var system_name:=""
var elapsed_days:=0.0
var preview_offset_days:=0.0
var selected_id:=""
var focus_id:=""
var current_focus_id:=""
var current_site_id:=""
var rows:Array[Dictionary]=[]
var by_id:Dictionary={}
var positions:Dictionary={}
var orbit_curves:Dictionary={}
var ship_position_au:Array=[]
var last_error:=""
var _world:RefCounted
var _spin_anchor:Dictionary={}
var _orbit_queue:Array[String]=[]
var _ground_queue:Array[String]=[]
var _ground_roots:Dictionary={}
var _ground_pads:Dictionary={}
var _initial_snapshot:Dictionary={}

static func _number(value:Variant,low:float,high:float)->bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value)>=low and float(value)<=high

static func _point(value:Variant)->bool:
	if not value is Array and not value is PackedFloat64Array:return false
	if value.size()!=3:return false
	for axis in value:
		if not _number(axis,-1.0e15,1.0e15):return false
	return true

func configure(state:Dictionary)->bool:
	if not state.get("star") is Dictionary or not state.get("world") is Dictionary or not _number(state.get("elapsed_days"),0,Clock.MAX_ELAPSED_DAYS):
		last_error="Неполные данные карты системы.";return false
	var candidate:=World.new()
	var saved:Dictionary=state.world.duplicate(true)
	candidate.configure(state.star,str(saved.get("preferred_layout",saved.get("layout",World.SOURCE_LAYOUT))))
	if not candidate.restore(saved):last_error="Не удалось прочитать систему для карты.";return false
	if candidate.bodies.size()+candidate.settlements.size()>MAX_RECORDS:last_error="Превышен размер исходной системы.";return false
	_world=candidate;_initial_snapshot=saved;_spin_anchor=candidate.body_spin_by_id.duplicate(true)
	system_name=str(state.get("system_name",state.star.get("name","Звёздная система")))
	elapsed_days=float(state.elapsed_days);preview_offset_days=0.0
	current_focus_id=str(candidate.focus_id);current_site_id=str(candidate.site_id)
	selected_id=str(candidate.selected_id);focus_id=_root_focus()
	rows.clear();by_id.clear();positions.clear();orbit_curves.clear();_orbit_queue.clear();_ground_queue.clear();_ground_roots.clear();_ground_pads.clear()
	for source:Dictionary in candidate.bodies:
		var row:=source.duplicate(true);row.is_site=false;row.ground=false
		rows.append(row);by_id[str(row.id)]=row
		if not str(row.parent).is_empty():_orbit_queue.append(str(row.id))
	for source:Dictionary in candidate.settlements:
		var row:=source.duplicate(true);row.is_site=true;row.ground=int(row.get("type_code",35))==35
		rows.append(row);by_id[str(row.id)]=row
		if row.ground:_ground_queue.append(str(row.id))
		else:_orbit_queue.append(str(row.id))
	ship_position_au=Array(state.ship_position_au).duplicate() if _point(state.get("ship_position_au")) else []
	configured=true;last_error=""
	if not by_id.has(selected_id):selected_id=current_focus_id
	return _evaluate_positions()

func _root_focus()->String:
	for body:Dictionary in _world.bodies:
		if str(body.parent).is_empty():return str(body.id)
	return str(_world.default_id)

func preview_days()->float:return elapsed_days+preview_offset_days

func set_time_offset(days:Variant)->bool:
	if not configured or not _number(days,-MAX_PREVIEW_DAYS,MAX_PREVIEW_DAYS):return false
	var next:=clampf(float(days),-elapsed_days,Clock.MAX_ELAPSED_DAYS-elapsed_days)
	var old:=preview_offset_days;preview_offset_days=next
	if _evaluate_positions():return true
	preview_offset_days=old;return false

func update_elapsed_days(days:Variant)->bool:
	if not configured or not _number(days,0,Clock.MAX_ELAPSED_DAYS):return false
	if float(days)==elapsed_days:return true
	elapsed_days=float(days)
	preview_offset_days=clampf(preview_offset_days,-elapsed_days,Clock.MAX_ELAPSED_DAYS-elapsed_days)
	return _evaluate_positions()

func _evaluate_positions()->bool:
	# Forecasts always start from the copied saved spin. Request order therefore
	# cannot accumulate preview rotations into a future gameplay snapshot.
	_world.body_spin_by_id=_spin_anchor.duplicate(true)
	var date:=preview_days();var next:Dictionary={}
	for row:Dictionary in rows:
		if row.is_site:continue
		var point:Array=_world.position_au(str(row.id),date)
		if not _point(point):last_error="Недоступна орбита объекта.";return false
		next[str(row.id)]=point.duplicate()
	for row:Dictionary in rows:
		if not row.is_site:continue
		if not row.ground:
			var point:Array=_world.site_position_au(str(row.id),date)
			if _point(point):next[str(row.id)]=point.duplicate()
		elif _ground_roots.has(str(row.id)) and next.has(str(row.parent)):
			var root:PackedFloat64Array=_ground_roots[str(row.id)]
			var basis:Basis=_world.body_rotation_basis(str(row.parent),date) if _world.layout_mode==World.FULL_LAYOUT else Basis.IDENTITY
			var parent:Array=next[str(row.parent)];var point:Array=[]
			# Scalar double dot products preserve small ground offsets at AU scales.
			for axis in range(3):point.append(float(parent[axis])+(float(basis.x[axis])*root[0]+float(basis.y[axis])*root[1]+float(basis.z[axis])*root[2])/AU_METRES)
			next[str(row.id)]=point
	positions=next;last_error="";return true

func prepare_geometry(budget:int=2)->int:
	if not configured or budget<1:return 0
	var completed:=0
	# One source city preparation per call bounds expensive terrain queries.
	if not _ground_queue.is_empty():
		var id:String=_ground_queue.pop_front();var row:Dictionary=by_id[id]
		if by_id.has(str(row.parent)):
			var body:Dictionary=by_id[str(row.parent)]
			if _world.layout_mode==World.FULL_LAYOUT:
				var profile:=Terrain.source_city_profile(row,str(body.get("runtime_record_hex","")).hex_decode(),float(body.get("radius_km",0))*1000.0)
				if profile.get("source_root_body_m") is PackedFloat64Array:
					_ground_roots[id]=profile.source_root_body_m.duplicate()
					if profile.get("pad_offset_body_m") is Vector3:
						var offset:Vector3=profile.pad_offset_body_m;var root:PackedFloat64Array=_ground_roots[id]
						_ground_pads[id]=PackedFloat64Array([root[0]+float(offset.x),root[1]+float(offset.y),root[2]+float(offset.z)])
			else:
				# Legacy ground sites have no verified source placement in their
				# world contract. Keep their selectable hierarchy without fake XYZ.
				pass
		completed+=1;_evaluate_positions()
	while completed<budget and not _orbit_queue.is_empty():
		var id:String=_orbit_queue.pop_front()
		var curve:=_build_orbit(by_id[id])
		if not curve.is_empty():orbit_curves[id]=curve
		completed+=1
	return completed

func preparation_remaining()->int:return _ground_queue.size()+_orbit_queue.size()

func _build_orbit(row:Dictionary)->Array:
	var points:Array=[]
	var record:=str(row.get("runtime_record_hex","")).hex_decode()
	if _world.layout_mode in [World.NATIVE_LAYOUT,World.PORT_LAYOUT,World.FULL_LAYOUT] and record.size()==68:
		if record.decode_u16(10)==35 or record.decode_u32(14)==0:return points
		for index in range(ORBIT_SEGMENTS+1):
			var phase:=int(index*4294967296.0/ORBIT_SEGMENTS)&0xffffffff
			var result:=Orbit.position(int(record.decode_u32(14)),int(record.decode_u16(34)),phase)
			if result.is_empty():return []
			var raw:PackedInt64Array=result.position_raw
			points.append(PackedFloat64Array([Units.metres(float(raw[0]))/AU_METRES,Units.metres(float(raw[1]))/AU_METRES,Units.metres(float(raw[2]))/AU_METRES]))
		return points
	var period:float=float(row.get("period_days",0))
	if period<=0 or not is_finite(period):return points
	for index in range(ORBIT_SEGMENTS+1):
		var point:Array=_world.relative_au(row,preview_days()+period*float(index)/ORBIT_SEGMENTS)
		if not _point(point):return []
		points.append(PackedFloat64Array(point))
	return points

func select(id:String)->bool:
	if not by_id.has(id):return false
	selected_id=id;return true

func set_focus(id:String)->bool:
	if not by_id.has(id):return false
	var row:Dictionary=by_id[id]
	focus_id=str(row.parent) if row.is_site else id
	return true

func reset_focus()->void:focus_id=_root_focus() if configured else ""

func selected()->Dictionary:return by_id.get(selected_id,{}).duplicate(true)
func position_au(id:String)->Array:return positions.get(id,[]).duplicate()
func focus_position()->Array:return position_au(focus_id)

func children(id:String)->Array:
	var result:Array=[]
	for row:Dictionary in rows:
		if str(row.parent)==id:result.append(row.duplicate(true))
	return result

func hierarchy()->Array[Dictionary]:
	var result:Array[Dictionary]=[];var stack:Array[String]=[]
	for index in range(rows.size()-1,-1,-1):
		if str(rows[index].parent).is_empty():stack.append(str(rows[index].id))
	var seen:Dictionary={}
	while not stack.is_empty() and result.size()<MAX_RECORDS:
		var id:String=stack.pop_back()
		if seen.has(id):continue
		seen[id]=true;result.append(by_id[id].duplicate(true))
		for index in range(rows.size()-1,-1,-1):
			if str(rows[index].parent)==id:stack.append(str(rows[index].id))
	return result

func ancestors(id:String)->Array[String]:
	var result:Array[String]=[];var cursor:=id
	for index in range(MAX_RECORDS):
		if not by_id.has(cursor):break
		cursor=str(by_id[cursor].get("parent",""))
		if cursor.is_empty():break
		result.append(cursor)
	return result

func depth(id:String)->int:return ancestors(id).size()

func selected_travel()->Dictionary:
	if not by_id.has(selected_id):return {}
	var row:Dictionary=by_id[selected_id]
	if row.is_site:return {"body_id":str(row.parent),"site_id":str(row.id)}
	if str(row.get("kind","")) in ["star","barycenter"]:return {}
	return {"body_id":selected_id,"site_id":""}

func orbit_points_au(id:String)->Array:
	if not orbit_curves.has(id) or not by_id.has(id):return []
	var parent:Array=position_au(str(by_id[id].parent))
	if parent.is_empty():return []
	var result:Array=[]
	for point:PackedFloat64Array in orbit_curves[id]:result.append(PackedFloat64Array([float(parent[0])+point[0],float(parent[1])+point[1],float(parent[2])+point[2]]))
	return result

func visible_orbit(id:String)->bool:
	if not by_id.has(id):return false
	return str(by_id[id].parent)==focus_id or id==selected_id or id==focus_id or id in ancestors(selected_id)

func distance_au(first:String,second:String)->float:
	var a:=position_au(first);var b:=position_au(second)
	if a.is_empty() or b.is_empty():return INF
	return sqrt(pow(float(a[0])-float(b[0]),2)+pow(float(a[1])-float(b[1]),2)+pow(float(a[2])-float(b[2]),2))

func source_snapshot()->Dictionary:return _initial_snapshot.duplicate(true)

static func _digest(raw:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw);return hash.finish().hex_encode()

func ground_target_reference(site_id:String)->Dictionary:
	if not configured or not by_id.has(site_id) or not _ground_roots.has(site_id):return {}
	var site:Dictionary=by_id[site_id];var parent_id:=str(site.parent)
	if not site.is_site or not site.ground or not by_id.has(parent_id):return {}
	var point:PackedFloat64Array=_ground_roots[site_id]
	var reference:={"profile":"system-map-source-f879-root-v1","terrain_revision":Terrain.REVISION_NAME,"system_id":int(_world.system_id),"site_id":site_id,"body_id":parent_id,"body_fixed_m":Vector3(point[0],point[1],point[2]),"body_fixed_metres_double":point.duplicate(),"site_record_sha256":_digest(str(site.get("runtime_record_hex","")).hex_decode()),"body_record_sha256":_digest(str(by_id[parent_id].get("runtime_record_hex","")).hex_decode())}
	if _ground_pads.has(site_id):
		var pad:PackedFloat64Array=_ground_pads[site_id]
		reference["pad_body_fixed_m"]=Vector3(pad[0],pad[1],pad[2]);reference["pad_body_fixed_metres_double"]=pad.duplicate()
	return reference
