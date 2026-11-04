class_name PlanetarySystem
extends RefCounted
# Rebuilt integration of recovered analytic flight code and original source
# constructor records. This is not the original FFE ephemeris/physics engine.
const AU_METERS:=149597870700.0
const EARTHS_PER_SUN:=332946.0
const YEAR_DAYS:=365.256
const G:=6.67430e-11
const SOLAR_MASS:=1.98847e30
const SOL_ID:=0x02a49718
const ARRIVAL_DIRECTION:=Vector3(0.48,-0.28,-1.0)
const SOURCE_LAYOUT:="handcrafted_analytic_rebuild_v1"
const SOLAR_LAYOUT:="reconstructed_solar_v1"
const EMPTY_LAYOUT:="source_unavailable_rebuild_v1"
var source_digest:=""
var star_context:Dictionary={}
var layout_mode:=SOLAR_LAYOUT
var settlements:Array=[]
var system_id:=-1
var bodies:Array=[]
var by_id:Dictionary={}
var focus_id:=""
var selected_id:=""
var default_id:=""
var transfer_remaining:=0.0
var pending_id:=""
var site_id:=""
var pending_site_id:=""
var message:=""
var _source_worlds:Dictionary={}
var _source_records:Dictionary={}
var _translations:Dictionary={}
var _source_hash:=""

func _read_object(path:String)->Dictionary:
	if not FileAccess.file_exists(path):return {}
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _load_sources()->void:
	_source_worlds=_read_object("res://data/ffe_worlds.json")
	_source_records=_read_object("res://data/ffe_handcrafted_records.json").get("records",{})
	_translations=_read_object("res://data/world_names_ru.json")
	var raw:=FileAccess.get_file_as_string("res://data/ffe_worlds.json") if FileAccess.file_exists("res://data/ffe_worlds.json") else ""
	var records:=FileAccess.get_file_as_string("res://data/ffe_handcrafted_records.json") if FileAccess.file_exists("res://data/ffe_handcrafted_records.json") else ""
	_source_hash=(raw+records).sha256_text()

func configure(star:Dictionary,layout:String="current")->void:
	star_context=star.duplicate(true)
	system_id=int(star.get("id",SOL_ID))
	bodies.clear();by_id.clear();settlements.clear();site_id="";pending_site_id="";pending_id="";transfer_remaining=0;message=""
	_load_sources()
	var applied:=false
	if layout in ["current",SOURCE_LAYOUT]:
		for entry in _source_worlds.get("systems",[]):
			if entry is Dictionary and int(entry.get("system_id",-1))==system_id:
				applied=_apply_handcrafted(entry);break
	if applied:
		layout_mode=SOURCE_LAYOUT;source_digest=(SOURCE_LAYOUT+str(system_id)+_source_hash).sha256_text()
	elif system_id==SOL_ID and layout in ["current",SOLAR_LAYOUT]:
		bodies.clear();by_id.clear();settlements.clear()
		_reconstructed_solar();layout_mode=SOLAR_LAYOUT;source_digest="physical-solar-adapter-v1".sha256_text()
	else:
		bodies.clear();by_id.clear();settlements.clear()
		_add(_star_body(str(star.get("name","Звезда"))))
		default_id="star";layout_mode=EMPTY_LAYOUT;source_digest=(EMPTY_LAYOUT+str(system_id)).sha256_text()
		message="Для этой системы пока не восстановлены исходные данные миров."
	focus_id=default_id;selected_id=default_id

func preferred_layout()->String:return layout_mode

func _star_body(title:String)->Dictionary:
	return {"id":"star","name":title,"name_en":str(star_context.get("original_name",title)),"parent":"","kind":"star","radius_km":696340.0,"mass_solar":1.0,"a_au":0.0,"eccentricity":0.0,"inclination":0.0,"node":0.0,"periapsis":0.0,"phase":0.0,"period_days":0.0,"rotation_hours":600.0,"rings":false,"source":"reconstructed_arrival_star"}

func _add(body:Dictionary)->void:
	bodies.append(body);by_id[str(body.id)]=body

func _translate(title:String)->String:
	var known:Dictionary={"Sol":"Солнце","Mercury":"Меркурий","Venus":"Венера","Earth":"Земля","Mars":"Марс","Jupiter":"Юпитер","Saturn":"Сатурн","Uranus":"Уран","Neptune":"Нептун","Pluto":"Плутон","Moon":"Луна","Io":"Ио","Europa":"Европа","Ganymede":"Ганимед","Callisto":"Каллисто","Titan":"Титан","London":"Лондон","Paris":"Париж","Tokyo":"Токио","New York":"Нью-Йорк","New Moscow":"Новая Москва","New San Francisco":"Новый Сан-Франциско","Sydney":"Сидней","Manchester":"Манчестер","Epping Newtown":"Эппинг-Ньютаун","Apollonius City":"Город Аполлоний","Factory Central":"Центральный завод","Abraham Lincoln":"Авраам Линкольн","M.Gorbachev":"М. Горбачёв","Li Qing Jao":"Ли Цинчжао"}
	return str(_translations.get(title,known.get(title,title)))

func _apply_handcrafted(entry:Dictionary)->bool:
	if not entry.get("objects") is Array or entry.objects.is_empty():return false
	var ids:Dictionary={};var candidate:Array=[];var candidate_index:Dictionary={};var sites:Array=[]
	var solar:=system_id==SOL_ID
	var solar_ids:Dictionary={"Sol":"star","Mercury":"mercury","Venus":"venus","Earth":"earth","Mars":"mars","Jupiter":"jupiter","Saturn":"saturn","Uranus":"uranus","Neptune":"neptune","Pluto":"pluto","Moon":"moon","Io":"io","Europa":"europa","Ganymede":"ganymede","Callisto":"callisto","Titan":"titan"}
	var radii:Dictionary={"Sol":696340.0,"Mercury":2439.7,"Venus":6051.8,"Earth":6371.0,"Mars":3389.5,"Jupiter":69911.0,"Saturn":58232.0,"Uranus":25362.0,"Neptune":24622.0,"Pluto":1188.3,"Moon":1737.4,"Io":1821.6,"Europa":1560.8,"Ganymede":2634.1,"Callisto":2410.3,"Titan":2574.7}
	for row in entry.objects:
		if not row is Dictionary or not row.has("local_index") or not row.has("type_code") or not row.has("name_en"):return false
		if int(row.type_code)>=32:continue
		var id:="star" if int(row.local_index)==1 else "hc%d"%int(row.local_index)
		if solar:id=str(solar_ids.get(str(row.name_en),id))
		ids[int(row.local_index)]=id
	for row in entry.objects:
		var type_code:=int(row.type_code)
		if type_code>=32:continue
		var parent:String=ids.get(int(row.parent_index),"")
		if int(row.parent_index)>0 and not candidate_index.has(parent):return false
		var kind:="rock"
		if type_code==0:kind="barycenter"
		elif type_code>=17:kind="star"
		elif type_code>=13:kind="gas"
		elif type_code in [9,10,11]:kind="earth"
		elif type_code in [4,5,6,7,8,12]:kind="desert"
		var mass:=maxf(1e-12,float(row.mass_raw)/200000000.0)
		var radius:=6371.0*float(row.model_radius_raw)/29792.0*pow(2.0,float(row.model_scale_raw)-18.0)
		if solar and radii.has(str(row.name_en)):radius=float(radii[str(row.name_en)])
		if kind=="barycenter":radius=0
		var a:=float(row.orbit_raw)/4458427.0 if not parent.is_empty() else 0.0
		var period:=0.0
		if not parent.is_empty():period=YEAR_DAYS*sqrt(pow(a,3)/(float(candidate_index[parent].mass_solar)+mass))
		var body:={"id":ids[int(row.local_index)],"name":_translate(str(row.name_en)),"name_en":str(row.name_en),"parent":parent,"kind":kind,"radius_km":radius,"mass_solar":mass,"a_au":a,"eccentricity":0.0,"inclination":deg_to_rad(float(row.inclination_tenths_raw)/10.0),"node":0.0,"periapsis":0.0,"phase":deg_to_rad(float(row.phase_degrees)),"period_days":period,"rotation_hours":24.0,"rings":str(row.name_en)=="Saturn","source":"ffe_constructor_parameters","physical_adapter":"analytic_si_rebuild_v1","original_index":int(row.local_index),"original_type":type_code,"model_index":int(row.model_index),"temperature_c":int(row.temperature_c)}
		_attach_record(body,row)
		candidate.append(body);candidate_index[str(body.id)]=body
	for row in entry.objects:
		if int(row.type_code)<32:continue
		var parent:String=ids.get(int(row.parent_index),"")
		if parent.is_empty() or not candidate_index.has(parent):return false
		var site:={"id":"site%d"%int(row.local_index),"name":_translate(str(row.name_en)),"name_en":str(row.name_en),"parent":parent,"orbit_raw":int(row.get("orbit_raw",0)),"type_code":int(row.type_code),"model_index":int(row.model_index),"latitude_raw":int(row.get("latitude_raw",0)),"longitude_raw":int(row.get("longitude_raw",0)),"original_index":int(row.local_index),"source":"ffe_constructor_parameters"}
		if int(row.type_code)==35:
			# Exact recovered F874 unsigned angle packing. The actual Q31 radial
			# transform remains in GroundCoordinates/SourceCityProfile.
			var phase:=int(((int(site.latitude_raw)<<16)&0xffffffff)/36000)
			var inclination:=int(((int(site.longitude_raw)<<16)&0xffffffff)/36000)
			site.ground_phase_u16=(-phase-0x4000)&65535;site.ground_inclination_u16=inclination&65535
			site.ground_coordinate_source="ffe_f874_arguments"
		_attach_record(site,row)
		sites.append(site)
	var arrival:="earth" if solar and candidate_index.has("earth") else ""
	for allowed in [["earth"],["rock","desert","ice"],["gas","ice_gas"],["star"]]:
		if not arrival.is_empty():break
		for body in candidate:
			if body.kind in allowed:arrival=str(body.id);break
	if arrival.is_empty():return false
	bodies=candidate;by_id=candidate_index;settlements=sites;default_id=arrival
	return true

func _attach_record(target:Dictionary,row:Dictionary)->void:
	var record:Variant=_source_records.get(str(int(row.get("global_index",-1))))
	if not record is Dictionary:return
	var encoded:=str(record.get("record_hex",""))
	if encoded.length()!=136 or int(record.get("model_index",-1))!=int(row.get("model_index",-2)):return
	var raw:=encoded.hex_decode()
	if raw.size()!=68:return
	target.record_hex=encoded;target.source_seed=int(record.seed_u32)
	target.source_rotation_raw=int(raw[62]);target.source_orientation_u16=int(raw.decode_u16(66))
	target.source_record_source="regenerated_ffe_f875_record"

func _planet(id:String,title:String,parent:String,radius:float,mass_earth:float,a:float,e:float,inclination:float,phase:float,kind:String,rings:=false)->void:
	var parent_mass:=float(by_id[parent].mass_solar)
	_add({"id":id,"name":title,"name_en":title,"parent":parent,"kind":kind,"radius_km":radius,"mass_solar":mass_earth/EARTHS_PER_SUN,"a_au":a,"eccentricity":e,"inclination":deg_to_rad(inclination),"node":phase*0.31,"periapsis":phase*0.57,"phase":phase,"period_days":YEAR_DAYS*sqrt(pow(a,3)/(parent_mass+mass_earth/EARTHS_PER_SUN)),"rotation_hours":24.0+phase*8.0,"rings":rings,"source":"reconstructed_solar_adapter"})

func _reconstructed_solar()->void:
	_add(_star_body("Солнце"))
	_planet("mercury","Меркурий","star",2439.7,0.0553,0.3871,0.2056,7.0,0.4,"rock")
	_planet("venus","Венера","star",6051.8,0.815,0.7233,0.0068,3.39,2.0,"desert")
	_planet("earth","Земля","star",6371.0,1.0,1.0,0.0167,0.0,3.0,"earth")
	_planet("mars","Марс","star",3389.5,0.1074,1.5237,0.0934,1.85,4.0,"desert")
	_planet("jupiter","Юпитер","star",69911.0,317.8,5.2028,0.0489,1.30,5.0,"gas")
	_planet("saturn","Сатурн","star",58232.0,95.16,9.5388,0.0565,2.49,1.1,"gas",true)
	_planet("uranus","Уран","star",25362.0,14.54,19.1914,0.0463,0.77,2.1,"ice_gas")
	_planet("neptune","Нептун","star",24622.0,17.15,30.0611,0.0095,1.77,3.1,"ice_gas")
	_planet("pluto","Плутон","star",1188.3,0.00218,39.482,0.2488,17.16,4.1,"ice")
	_planet("moon","Луна","earth",1737.4,0.0123,384400000.0/AU_METERS,0.0549,5.145,0.8,"rock")
	settlements.append({"id":"rebuild_field","name":"Посадочная площадка","name_en":"Rebuilt landing field","parent":"earth","type_code":35,"model_index":-1,"source":"reconstructed_landing_field"})
	default_id="earth"

static func eccentric_anomaly(mean:float,eccentricity:float)->float:
	var m:=fposmod(mean,TAU);var e:=m
	for i in range(16):
		var correction:=(e-eccentricity*sin(e)-m)/(1-eccentricity*cos(e));e-=correction
		if absf(correction)<1e-13:break
	return e

func relative_au(body:Dictionary,days:float)->Array:
	if str(body.parent).is_empty():return [0.0,0.0,0.0]
	var ecc:=float(body.eccentricity);var period:=float(body.period_days)
	var mean:=float(body.phase)+(TAU*fposmod(days,period)/period if period>0 else 0.0)
	var anomaly:=eccentric_anomaly(mean,ecc)
	var x:=float(body.a_au)*(cos(anomaly)-ecc);var y:=float(body.a_au)*sqrt(1-ecc*ecc)*sin(anomaly)
	var longitude:=float(body.periapsis);var inclination:=float(body.inclination)
	var xp:=x*cos(longitude)-y*sin(longitude);var yp:=x*sin(longitude)+y*cos(longitude);var flat:=yp*cos(inclination)
	return [xp*cos(float(body.node))-flat*sin(float(body.node)),yp*sin(inclination),xp*sin(float(body.node))+flat*cos(float(body.node))]

func position_au(id:String,days:float)->Array:
	if not by_id.has(id) or not is_finite(days):return []
	var result:Array=[0.0,0.0,0.0];var cursor:=id
	for _depth in range(32):
		var body:Dictionary=by_id[cursor];var relative:=relative_au(body,days)
		for axis in range(3):result[axis]=float(result[axis])+float(relative[axis])
		cursor=str(body.parent)
		if cursor.is_empty():return result
		if not by_id.has(cursor):return []
	return []

func origin_au(days:float)->Array:
	var center:=position_au(focus_id,days)
	if center.size()!=3:return [0.0,0.0,0.0]
	var radius:=float(by_id[focus_id].radius_km)*1000.0;var direction:=ARRIVAL_DIRECTION.normalized()
	var offset:=maxf(radius*4.0,3000000.0)/AU_METERS
	return [float(center[0])-direction.x*offset,float(center[1])-direction.y*offset,float(center[2])-direction.z*offset]

func local_meters(id:String,days:float)->Vector3:
	var p:=position_au(id,days)
	if p.size()!=3:return Vector3.ZERO
	var origin:=origin_au(days)
	return Vector3((float(p[0])-float(origin[0]))*AU_METERS,(float(p[1])-float(origin[1]))*AU_METERS,(float(p[2])-float(origin[2]))*AU_METERS)

func gravity_at(position:Vector3,days:float)->Vector3:
	if not position.is_finite() or not is_finite(days):return Vector3.ZERO
	var gravity:=Vector3.ZERO
	for body in bodies:
		if body.kind=="barycenter":continue
		var delta:=local_meters(str(body.id),days)-position;var distance:=maxf(delta.length(),maxf(1.0,float(body.radius_km)*500.0))
		gravity+=delta.normalized()*(G*SOLAR_MASS*float(body.mass_solar)/(distance*distance))
	return gravity

func select(id:String)->bool:
	if not by_id.has(id) or transfer_remaining>0:return false
	selected_id=id;return true
func get_site(id:String)->Dictionary:
	for site in settlements:
		if str(site.id)==id:return site
	return {}
func current_site()->Dictionary:
	var site:=get_site(site_id)
	return site if not site.is_empty() and str(site.parent)==focus_id else {}
func is_orbital_site()->bool:
	var site:=current_site();return not site.is_empty() and int(site.type_code)<35
func ground_sites(body_id:String="")->Array:
	var result:Array=[]
	for site in settlements:
		if int(site.type_code)==35 and (body_id.is_empty() or str(site.parent)==body_id):result.append(site)
	return result

func select_site(id:String)->bool:
	var site:=get_site(id)
	if site.is_empty() or transfer_remaining>0:return false
	selected_id=str(site.parent);return true

func can_transfer(ship:RefCounted,nav:RefCounted,destination_site:String="")->String:
	if transfer_remaining>0:return "Автоперелёт уже готовится."
	if ship.hull<=0:return "Корабль потерян."
	if ship.surface_mode:return "Сначала вернитесь на орбиту."
	if ship.combat_active:return "Сначала выйдите из боя."
	if ship.docked:return "Сначала вылетите со станции."
	if nav.remaining>0:return "Сначала отмените гиперпереход."
	if not by_id.has(selected_id):return "Неизвестный объект."
	if selected_id==focus_id and destination_site.is_empty() and site_id.is_empty():
		if not (focus_id==default_id and nav.has_station() and ship.position.distance_to(ship.STATION)>1000):return "Вы уже у выбранного объекта."
	if str(by_id[selected_id].kind) in ["star","barycenter"]:return "Непосредственный подлёт к звезде заблокирован."
	if not ship.velocity.is_finite() or ship.velocity.length()>20:return "Затормозите до 20 м/с."
	if ship.station_available and ship.position.distance_to(ship.STATION)<400:return "Отойдите от станции минимум на 400 м."
	return ""

func begin_transfer(ship:RefCounted,nav:RefCounted,destination_site:String="")->bool:
	if not destination_site.is_empty():
		var target:=get_site(destination_site)
		if target.is_empty() or str(target.parent)!=selected_id:return false
	message=can_transfer(ship,nav,destination_site)
	if not message.is_empty():return false
	pending_id=selected_id;pending_site_id=destination_site;transfer_remaining=3.0;ship.brake()
	message="Подготовка автоперелёта. Повторное нажатие отменяет его."
	return true

func begin_site_transfer(id:String,ship:RefCounted,nav:RefCounted)->bool:
	var site:=get_site(id)
	if site.is_empty():message="Неизвестное поселение.";return false
	if transfer_remaining>0:message="Сначала отмените текущий перелёт.";return false
	if id==site_id:message="Вы уже у выбранного поселения.";return false
	if int(site.type_code)==35:
		var body:Dictionary=by_id[str(site.parent)]
		var g:=G*SOLAR_MASS*float(body.mass_solar)/pow(float(body.radius_km)*1000.0,2)
		if body.kind in ["star","barycenter","gas","ice_gas"] or g>ship.acceleration()*0.8:message="Нет безопасного входа к этому космопорту при текущей тяге.";return false
	var previous:=selected_id;selected_id=str(site.parent)
	if not begin_transfer(ship,nav,id):selected_id=previous;return false
	return true

func cancel_transfer()->void:
	pending_site_id="";transfer_remaining=0;pending_id="";message="Автоперелёт отменён."

func step_transfer(dt:float,ship:RefCounted,nav:RefCounted)->bool:
	if transfer_remaining<=0 or not is_finite(dt) or dt<=0:return false
	if ship.hull<=0 or ship.surface_mode or ship.combat_active or ship.docked or nav.remaining>0 or not ship.velocity.is_finite() or ship.velocity.length()>20 or (ship.station_available and ship.position.distance_to(ship.STATION)<400):
		cancel_transfer();return false
	transfer_remaining=maxf(0,transfer_remaining-dt)
	if transfer_remaining>0:return false
	if pending_id.is_empty() or not by_id.has(pending_id):cancel_transfer();return false
	var old_pos:=position_au(focus_id,float(nav.elapsed_days));var target_pos:=position_au(pending_id,float(nav.elapsed_days))
	var distance:=sqrt(pow(float(old_pos[0])-float(target_pos[0]),2)+pow(float(old_pos[1])-float(target_pos[1]),2)+pow(float(old_pos[2])-float(target_pos[2]),2))
	nav.elapsed_days+=maxf(0.02,distance*0.35)
	focus_id=pending_id;selected_id=pending_id;site_id=pending_site_id;pending_site_id="";pending_id=""
	ship.position=Vector3.ZERO;ship.velocity=Vector3.ZERO;ship.attitude=Quaternion.IDENTITY;ship.target_speed=0;ship.autopilot=false
	ship.station_available=is_orbital_site() or (site_id.is_empty() and nav.has_station() and focus_id==default_id)
	message="Прибытие к объекту: %s."%by_id[focus_id].name
	return true

func protect_surface(ship:RefCounted,days:float)->bool:
	if not by_id.has(focus_id) or not ship.position.is_finite():return false
	var center:=local_meters(focus_id,days);var offset:Vector3=ship.position-center
	var safe:=float(by_id[focus_id].radius_km)*1000.0+2000.0
	if offset.length()>=safe:return false
	var direction:=offset.normalized() if offset.length()>0.1 else Vector3.UP
	ship.position=center+direction*(safe+50.0);ship.velocity=direction*10.0;ship.target_speed=0;ship.autopilot=false;ship.hull=maxf(0,ship.hull-10)
	message="Опасное сближение с поверхностью. Для посадки используйте «К поверхности»."
	return true

func snapshot()->Dictionary:
	return {"schema":"starfrontier-rebuild-world-v1","version":1,"layout":layout_mode,"source_digest":source_digest,"system_id":system_id,"focus_id":focus_id,"selected_id":selected_id,"site_id":site_id,"pending_id":pending_id,"pending_site_id":pending_site_id,"transfer_remaining":transfer_remaining}

func restore(data:Dictionary)->bool:
	if data.get("schema")!="starfrontier-rebuild-world-v1" or data.get("version")!=1 or not (data.get("system_id") is int or data.get("system_id") is float) or not is_finite(float(data.system_id)) or float(data.system_id)!=float(system_id):return false
	if data.get("layout") not in [SOURCE_LAYOUT,SOLAR_LAYOUT,EMPTY_LAYOUT] or not data.get("source_digest") is String:return false
	for key in ["focus_id","selected_id","site_id","pending_id","pending_site_id"]:
		if not data.get(key) is String:return false
	var remaining:Variant=data.get("transfer_remaining")
	if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or float(remaining)<0 or float(remaining)>3:return false
	var candidate:RefCounted=get_script().new();candidate.configure(star_context,str(data.layout))
	if candidate.layout_mode!=data.layout or candidate.source_digest!=data.source_digest:return false
	if not candidate.by_id.has(str(data.focus_id)) or not candidate.by_id.has(str(data.selected_id)):return false
	if not str(data.site_id).is_empty():
		var site:Dictionary=candidate.get_site(str(data.site_id))
		if site.is_empty() or str(site.parent)!=str(data.focus_id):return false
	if float(remaining)>0:
		if str(data.pending_id)!=str(data.selected_id):return false
		if not candidate.by_id.has(str(data.pending_id)) or str(candidate.by_id[str(data.pending_id)].kind) in ["star","barycenter"]:return false
		if not str(data.pending_site_id).is_empty():
			var site:Dictionary=candidate.get_site(str(data.pending_site_id))
			if site.is_empty() or str(site.parent)!=str(data.pending_id):return false
	elif not str(data.pending_id).is_empty() or not str(data.pending_site_id).is_empty():return false
	bodies=candidate.bodies;by_id=candidate.by_id;settlements=candidate.settlements;default_id=candidate.default_id
	layout_mode=candidate.layout_mode;source_digest=candidate.source_digest
	focus_id=str(data.focus_id);selected_id=str(data.selected_id);site_id=str(data.site_id)
	pending_id=str(data.pending_id);pending_site_id=str(data.pending_site_id);transfer_remaining=float(remaining);message=""
	return true
