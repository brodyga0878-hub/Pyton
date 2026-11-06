class_name PlanetarySystem
extends RefCounted
# Source celestial/port centres and versioned station-following frames. Legacy
# v1/v2 layouts and analytic SI surface/gravity adapters remain explicit.
const AU_METERS:=149597870700.0
const EARTHS_PER_SUN:=332946.0
const YEAR_DAYS:=365.256
const G:=6.67430e-11
const SOLAR_MASS:=1.98847e30
const SOL_ID:=0x02a49718
const ARRIVAL_DIRECTION:=Vector3(0.48,-0.28,-1.0)
const SOURCE_LAYOUT:="handcrafted_analytic_rebuild_v1"
const NATIVE_LAYOUT:="handcrafted_jjffe_orbits_v2"
const NATIVE_CONTRACT:="jjffe-f880-3250-anchor-f866-orbit-xyz-v1"
const PORT_LAYOUT:="handcrafted_jjffe_ports_v3"
const FULL_LAYOUT:="source_jjffe_systems_v4"
const GENERATED_LAYOUT:=FULL_LAYOUT
const FULL_CONTRACT:="source-system-hierarchy-native-frames-sampled-f603-v4"
const ZERO_ROOT_RADIUS_POLICY:="zero-root-orbit-radius-seed-step-v1"
const BETA_LYRAE_POLICY:="beta-lyrae-invalid-class23-to-last-defined-class22-v1"
const BODY_SPIN_REVISION:="source-world-body-spin-v1"
const PORT_CONTRACT:="source-orbital-centres-station-following-v1"
const ORBITAL_DOCK_LOCAL:=Vector3(0,0,-2500)
const SOLAR_LAYOUT:="reconstructed_solar_v1"
const EMPTY_LAYOUT:="source_unavailable_rebuild_v1"
const RuntimeBuilder=preload("res://scripts/handcrafted_runtime_builder.gd")
const SourceOrbit=preload("res://scripts/source_orbit.gd")
const SourceClock=preload("res://scripts/source_clock.gd")
const SourceUnits=preload("res://scripts/source_units.gd")
const SourceMath=preload("res://scripts/ffe_math.gd")
const SourceGravity=preload("res://scripts/source_gravity.gd")
const FullDefinition=preload("res://scripts/source_system_definition.gd")
const FullBuilder=preload("res://scripts/source_system_builder.gd")
const FullCatalogue=preload("res://scripts/source_world_catalogue.gd")
const SourceTerrain=preload("res://scripts/source_surface_terrain.gd")
const PhysicsBridge=preload("res://scripts/source_physics_bridge.gd")
const StationGeometry=preload("res://scripts/source_station_geometry.gd")
const OrbitSurfaceGuard=preload("res://scripts/source_orbit_surface_guard.gd")
const SourceRotation=preload("res://scripts/body_rotation.gd")
var _full_surface_guard:=OrbitSurfaceGuard.new()
var station_state_by_site:Dictionary={}
var body_spin_by_id:Dictionary={}
var full_system_state:Dictionary={}
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
var source_runtime_state:Dictionary={}
var _runtime_by_global:Dictionary={}
var requested_layout:=SOURCE_LAYOUT
var orbit_backend_state:Dictionary={}
var port_backend_state:Dictionary={}
var source_physics_state:Dictionary={}
var native_evaluation_count:=0
var _native_cache_tick:=-1
var _native_cache_day:=-1
var _native_positions_raw:Dictionary={}
var _native_relative_raw:Dictionary={}

func _clear_orbit_cache()->void:
	_native_cache_tick=-1;_native_cache_day=-1
	_native_positions_raw.clear();_native_relative_raw.clear();native_evaluation_count=0

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
	source_runtime_state.clear();_runtime_by_global.clear()
	orbit_backend_state.clear();port_backend_state.clear();source_physics_state.clear();_clear_orbit_cache()
	requested_layout=SOURCE_LAYOUT if layout=="current" else layout
	station_state_by_site.clear();body_spin_by_id.clear();full_system_state.clear();_full_surface_guard.clear_cache()
	if layout==FULL_LAYOUT:
		if _apply_full_system():
			layout_mode=FULL_LAYOUT;focus_id=default_id;selected_id=default_id;return
		# A missing or unsafe source input remains an explicit empty v4 world.
		source_runtime_state.clear();_runtime_by_global.clear();orbit_backend_state.clear();port_backend_state.clear();source_physics_state.clear();_clear_orbit_cache()
		bodies.clear();by_id.clear();settlements.clear();_add(_star_body(str(star.get("name","Звезда"))))
		default_id="star";focus_id=default_id;selected_id=default_id;layout_mode=EMPTY_LAYOUT
		source_digest=(EMPTY_LAYOUT+str(system_id)+FULL_CONTRACT).sha256_text()
		message="Исходные параметры этой системы недоступны или небезопасны для построения.";return
	_load_sources()
	var applied:=false
	if layout in ["current",SOURCE_LAYOUT,NATIVE_LAYOUT,PORT_LAYOUT]:
		for entry in _source_worlds.get("systems",[]):
			if entry is Dictionary and int(entry.get("system_id",-1))==system_id:
				applied=_apply_handcrafted(entry);break
	if applied and layout in [NATIVE_LAYOUT,PORT_LAYOUT]:applied=_enable_native_orbits()
	if applied:
		layout_mode=layout if layout in [NATIVE_LAYOUT,PORT_LAYOUT] else SOURCE_LAYOUT
		source_digest=(layout_mode+str(system_id)+_source_hash+(SourceOrbit.SOURCE_VARIANT+NATIVE_CONTRACT+String.num(SourceUnits.METRES_PER_RAW,16) if layout_mode in [NATIVE_LAYOUT,PORT_LAYOUT] else "")+(PORT_CONTRACT+SourceGravity.SOURCE_VARIANT if layout_mode==PORT_LAYOUT else "")).sha256_text()
	elif system_id==SOL_ID and layout in ["current",SOLAR_LAYOUT]:
		source_runtime_state.clear();_runtime_by_global.clear()
		bodies.clear();by_id.clear();settlements.clear()
		_reconstructed_solar();layout_mode=SOLAR_LAYOUT;source_digest="physical-solar-adapter-v1".sha256_text()
	else:
		source_runtime_state.clear();_runtime_by_global.clear()
		orbit_backend_state.clear();port_backend_state.clear();source_physics_state.clear();_clear_orbit_cache()
		bodies.clear();by_id.clear();settlements.clear()
		_add(_star_body(str(star.get("name","Звезда"))))
		default_id="star";layout_mode=EMPTY_LAYOUT;source_digest=(EMPTY_LAYOUT+str(system_id)).sha256_text()
		message="Для этой системы пока не восстановлены исходные данные миров."
	focus_id=default_id;selected_id=default_id

func preferred_layout()->String:
	# Legacy jumps always selected the current source adapter, including jumps
	# out of an explicitly restored Solar adapter. Only v2 opts into new orbits.
	return requested_layout if requested_layout in [NATIVE_LAYOUT,PORT_LAYOUT,FULL_LAYOUT] else SOURCE_LAYOUT

func _enable_native_orbits()->bool:
	if source_runtime_state.is_empty():return false
	for body in bodies:
		var raw:=str(body.get("runtime_record_hex","")).hex_decode()
		if raw.size()!=68:return false
		var packed_orbit:=int(raw.decode_u32(14));var packed_period:=int(raw.decode_u32(20))
		var distance:=SourceUnits.metres(SourceMath.real(packed_orbit))
		var seconds:=SourceMath.real(packed_period)
		if not is_finite(distance) or not is_finite(seconds) or distance<0 or seconds<0:return false
		body.a_au=distance/AU_METERS;body.period_days=seconds/86400.0
		body.inclination=float(SourceMath.s16(raw.decode_u16(34)))*TAU/65536.0
		body.orbit_backend=SourceOrbit.SOURCE_VARIANT
		body.physical_adapter="analytic_si_rebuild_v1"
		if requested_layout==PORT_LAYOUT:
			var coefficient:=SourceGravity.coefficient(raw)
			if coefficient.is_empty():return false
			body["source_a4_packed"]=int(coefficient.a4_u32)
	if not _prepare_native_positions(0.0):return false
	source_runtime_state.physical_layout_changed=true
	orbit_backend_state={"source_variant":SourceOrbit.SOURCE_VARIANT,"contract":NATIVE_CONTRACT,"layout":NATIVE_LAYOUT,"coordinate_units":"raw geometry calibrated by16785/2^24 metres","celestial_parent_composition":"non-rotating signed64 translation","clock":"fixed F880 initialization at3250 epoch then ordinary F866 orbital updates via elapsed-days bridge","epoch_tick_u32":SourceClock.EPOCH_TICK_U32,"epoch_day_u32":SourceClock.EPOCH_DAY_U32,"radius_mass_gravity_spin":"analytic_si_rebuild_v1","orbital_ports_rendered":false,"complete_original_physics":false}
	if requested_layout==PORT_LAYOUT:
		orbit_backend_state.layout=PORT_LAYOUT;orbit_backend_state.orbital_ports_rendered=true
		var ports:=0
		for site in settlements:
			if int(site.type_code) in [32,33,34]:ports+=1
		port_backend_state={"contract":PORT_CONTRACT,"source_variant":SourceOrbit.SOURCE_VARIANT,"orbital_ports":ports,"position":"native source centres with non-rotating parent translation","local_frame":"non-rotating station-following origin","dock_local":[0,0,-2500],"render_scope":"selected orbital port only","geometry_orientation_services":"existing adapted station; source spin and full dock geometry/services remain separate","complete_original_docking":false}
		source_physics_state={"source_variant":SourceGravity.SOURCE_VARIANT,"F880_a4_initialized":true,"body_count":bodies.size(),"F603_velocity_kernel_available":true,"F1511_F1512_kernel_available":true,"live_gravity":"analytic_si_rebuild_v1","live_surface_radius":"analytic_si_rebuild_v1","descriptor_bounds_are_surface_radius":false,"source_time_policy_integrated":false,"complete_original_physics":false}
	return true

func _prepare_native_positions(days:float)->bool:
	var clock:=SourceClock.from_elapsed_days(days)
	if clock.is_empty():return false
	if _native_cache_tick==int(clock.tick_u32) and _native_cache_day==int(clock.day_u32):return true
	var relative:Dictionary={};var absolute:Dictionary={}
	var objects:Array=bodies.duplicate()
	if requested_layout in [PORT_LAYOUT,FULL_LAYOUT]:
		for site in settlements:
			if int(site.type_code) in [32,33,34]:objects.append(site)
	for body in objects:
		var record:=str(body.get("runtime_record_hex","")).hex_decode()
		if record.size()!=68:return false
		var evaluated:=SourceOrbit.evaluate_from_epoch(record,clock.tick_u32,clock.day_u32,SourceClock.EPOCH_TICK_U32,SourceClock.EPOCH_DAY_U32)
		if evaluated.is_empty():return false
		var point:PackedInt64Array=evaluated.position_raw
		var parent:=str(body.parent)
		if not parent.is_empty() and not absolute.has(parent):return false
		relative[str(body.id)]=point.duplicate()
		absolute[str(body.id)]=SourceOrbit.add_positions(absolute[parent],point) if not parent.is_empty() else point.duplicate()
	_native_relative_raw=relative;_native_positions_raw=absolute
	_native_cache_tick=int(clock.tick_u32);_native_cache_day=int(clock.day_u32)
	native_evaluation_count+=objects.size()
	return true

static func _source_au(point:PackedInt64Array)->Array:
	return [SourceUnits.metres(float(point[0]))/AU_METERS,SourceUnits.metres(float(point[1]))/AU_METERS,SourceUnits.metres(float(point[2]))/AU_METERS]

func _star_body(title:String)->Dictionary:
	return {"id":"star","name":title,"name_en":str(star_context.get("original_name",title)),"parent":"","kind":"star","radius_km":696340.0,"mass_solar":1.0,"a_au":0.0,"eccentricity":0.0,"inclination":0.0,"node":0.0,"periapsis":0.0,"phase":0.0,"period_days":0.0,"rotation_hours":600.0,"rings":false,"source":"reconstructed_arrival_star"}

func _add(body:Dictionary)->void:
	bodies.append(body);by_id[str(body.id)]=body

func _translate(title:String)->String:
	var known:Dictionary={"Sol":"Солнце","Mercury":"Меркурий","Venus":"Венера","Earth":"Земля","Mars":"Марс","Jupiter":"Юпитер","Saturn":"Сатурн","Uranus":"Уран","Neptune":"Нептун","Pluto":"Плутон","Moon":"Луна","Io":"Ио","Europa":"Европа","Ganymede":"Ганимед","Callisto":"Каллисто","Titan":"Титан","London":"Лондон","Paris":"Париж","Tokyo":"Токио","New York":"Нью-Йорк","New Moscow":"Новая Москва","New San Francisco":"Новый Сан-Франциско","Sydney":"Сидней","Manchester":"Манчестер","Epping Newtown":"Эппинг-Ньютаун","Apollonius City":"Город Аполлоний","Factory Central":"Центральный завод","Abraham Lincoln":"Авраам Линкольн","M.Gorbachev":"М. Горбачёв","Li Qing Jao":"Ли Цинчжао"}
	return str(_translations.get(title,known.get(title,title)))

func _apply_handcrafted(entry:Dictionary)->bool:
	if not entry.get("objects") is Array or entry.objects.is_empty():return false
	_prepare_source_runtime(entry)
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
		if requested_layout==PORT_LAYOUT:
			body["source_outer_bound_m"]=SourceUnits.metres(float(row.model_radius_raw)*pow(2.0,float(row.model_scale_raw)))
			body["source_bound_role"]="descriptor_outer_sphere_not_surface_radius"
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

func _prepare_source_runtime(entry:Dictionary)->void:
	source_runtime_state.clear();_runtime_by_global.clear()
	var templates:Array=[]
	for row in entry.get("objects",[]):
		if not row is Dictionary or int(row.get("local_index",-1))!=templates.size()+1:return
		var stored:Variant=_source_records.get(str(int(row.get("global_index",-1))))
		if not stored is Dictionary:return
		var encoded:=str(stored.get("record_hex",""))
		if encoded.length()!=136 or int(stored.get("model_index",-1))!=int(row.get("model_index",-2)):return
		var record:=encoded.hex_decode()
		if record.size()!=68:return
		templates.append(record)
	var converted:=RuntimeBuilder.build(templates)
	if not converted.get("ok",false):return
	for index in range(templates.size()):
		_runtime_by_global[int(entry.objects[index].global_index)]=converted.records[index].hex_encode()
	source_runtime_state={"source":"ffe_f878_handcrafted_suffix","record_domain":"packed_runtime_records","count":converted.count,"body_count_byte":converted.body_count_byte,"port_count_byte":converted.port_count_byte,"orbital_port_count_byte":converted.orbital_port_count_byte,"records_sha256":var_to_bytes(converted.records).hex_encode().sha256_text(),"physical_layout_changed":false}

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
	target.source_record_domain="constructor_template"
	var global_index:=int(row.get("global_index",-1))
	if _runtime_by_global.has(global_index):
		target.runtime_record_hex=_runtime_by_global[global_index]
		target.runtime_record_source="ffe_f878_handcrafted_suffix"
		target.runtime_record_domain="packed_runtime_records"

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
	if layout_mode in [NATIVE_LAYOUT,PORT_LAYOUT,FULL_LAYOUT]:
		if not _prepare_native_positions(days) or not _native_relative_raw.has(str(body.get("id",""))):return []
		return _source_au(_native_relative_raw[str(body.id)])
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
	if layout_mode in [NATIVE_LAYOUT,PORT_LAYOUT,FULL_LAYOUT]:
		if not _prepare_native_positions(days):return []
		return _source_au(_native_positions_raw[id])
	var result:Array=[0.0,0.0,0.0];var cursor:=id
	for _depth in range(32):
		var body:Dictionary=by_id[cursor];var relative:=relative_au(body,days)
		for axis in range(3):result[axis]=float(result[axis])+float(relative[axis])
		cursor=str(body.parent)
		if cursor.is_empty():return result
		if not by_id.has(cursor):return []
	return []

func origin_au(days:float)->Array:
	if layout_mode in [PORT_LAYOUT,FULL_LAYOUT] and is_orbital_site():
		var station:=site_position_au(site_id,days)
		if station.size()==3:return [float(station[0])-ORBITAL_DOCK_LOCAL.x/AU_METERS,float(station[1])-ORBITAL_DOCK_LOCAL.y/AU_METERS,float(station[2])-ORBITAL_DOCK_LOCAL.z/AU_METERS]
	var center:=position_au(focus_id,days)
	if center.size()!=3:return [0.0,0.0,0.0]
	var radius:=float(by_id[focus_id].radius_km)*1000.0;var direction:=ARRIVAL_DIRECTION.normalized()
	var offset:=maxf(radius*4.0,3000000.0)/AU_METERS
	return [float(center[0])-direction.x*offset,float(center[1])-direction.y*offset,float(center[2])-direction.z*offset]

func local_meters(id:String,days:float)->Vector3:
	if layout_mode==FULL_LAYOUT:
		if not _prepare_native_positions(days) or not _native_positions_raw.has(id):return Vector3.ZERO
		return _full_local(_native_positions_raw[id],days)
	var p:=position_au(id,days)
	if p.size()!=3:return Vector3.ZERO
	var origin:=origin_au(days)
	return Vector3((float(p[0])-float(origin[0]))*AU_METERS,(float(p[1])-float(origin[1]))*AU_METERS,(float(p[2])-float(origin[2]))*AU_METERS)

func site_position_au(id:String,days:float)->Array:
	if layout_mode not in [PORT_LAYOUT,FULL_LAYOUT]:return []
	var site:=get_site(id)
	if site.is_empty() or int(site.type_code) not in [32,33,34]:return []
	if not _prepare_native_positions(days) or not _native_positions_raw.has(id):return []
	return _source_au(_native_positions_raw[id])

func site_local_meters(id:String,days:float)->Vector3:
	if layout_mode==FULL_LAYOUT:
		var site:=get_site(id)
		if site.is_empty() or int(site.type_code) not in [32,33,34] or not _prepare_native_positions(days) or not _native_positions_raw.has(id):return Vector3.ZERO
		if is_orbital_site() and id==site_id:return ORBITAL_DOCK_LOCAL
		return _full_local(_native_positions_raw[id],days)
	var point:=site_position_au(id,days)
	if point.size()!=3:return Vector3.ZERO
	# Avoid cancellation through AU coordinates for the current local target.
	if is_orbital_site() and id==site_id:return ORBITAL_DOCK_LOCAL
	var origin:=origin_au(days)
	return Vector3((float(point[0])-float(origin[0]))*AU_METERS,(float(point[1])-float(origin[1]))*AU_METERS,(float(point[2])-float(origin[2]))*AU_METERS)

func gravity_at(position:Vector3,days:float)->Vector3:
	if layout_mode==FULL_LAYOUT:return _full_gravity_at(position,days)
	if not position.is_finite() or not is_finite(days):return Vector3.ZERO
	if layout_mode in [NATIVE_LAYOUT,PORT_LAYOUT] and not _prepare_native_positions(days):return Vector3.ZERO
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
		if layout_mode==FULL_LAYOUT:
			if not body.get("landable",false):message="У этого объекта нет восстановленной безопасной поверхности.";return false
			var record:=str(body.get("runtime_record_hex","")).hex_decode()
			var profile:=SourceTerrain.source_city_profile(site,record,float(body.radius_km)*1000.0)
			if profile.is_empty() or not profile.get("source_root_raw") is PackedInt64Array or profile.source_root_raw.size()!=3:message="Не удалось восстановить исходную точку космопорта.";return false
			var root:PackedInt64Array=profile.source_root_raw
			var body_fixed:=Vector3(SourceUnits.metres(float(root[0])),SourceUnits.metres(float(root[1])),SourceUnits.metres(float(root[2])))
			var sampled:=source_surface_gravity(str(body.id),body_fixed,float(nav.elapsed_days))
			if sampled.is_empty():message="Исходная гравитация поверхности недоступна.";return false
			g=float(sampled.gravity_mps2)
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
	if layout_mode==FULL_LAYOUT:return _full_surface_guard.protect(self,ship,days)
	if not by_id.has(focus_id) or not ship.position.is_finite():return false
	var center:=local_meters(focus_id,days);var offset:Vector3=ship.position-center
	var safe:=float(by_id[focus_id].radius_km)*1000.0+2000.0
	if offset.length()>=safe:return false
	var direction:=offset.normalized() if offset.length()>0.1 else Vector3.UP
	ship.position=center+direction*(safe+50.0);ship.velocity=direction*10.0;ship.target_speed=0;ship.autopilot=false;ship.hull=maxf(0,ship.hull-10)
	message="Опасное сближение с поверхностью. Для посадки используйте «К поверхности»."
	return true

func snapshot()->Dictionary:
	var result:={"schema":"starfrontier-rebuild-world-v1","version":1,"layout":layout_mode,"source_digest":source_digest,"system_id":system_id,"focus_id":focus_id,"selected_id":selected_id,"site_id":site_id,"pending_id":pending_id,"pending_site_id":pending_site_id,"transfer_remaining":transfer_remaining}
	if requested_layout==FULL_LAYOUT:
		result.schema="starfrontier-rebuild-world-v4";result.version=4;result["preferred_layout"]=FULL_LAYOUT
		result["station_state_by_site"]=station_state_by_site.duplicate(true);result["body_spin_by_id"]=body_spin_by_id.duplicate(true)
	elif requested_layout==NATIVE_LAYOUT:
		result.schema="starfrontier-rebuild-world-v2";result.version=2;result["preferred_layout"]=NATIVE_LAYOUT
	elif requested_layout==PORT_LAYOUT:
		result.schema="starfrontier-rebuild-world-v3";result.version=3;result["preferred_layout"]=PORT_LAYOUT
	return result

func restore(data:Dictionary)->bool:
	var full_save:bool=data.get("schema")=="starfrontier-rebuild-world-v4" and data.get("version")==4
	var native_save:bool=data.get("schema")=="starfrontier-rebuild-world-v2" and data.get("version")==2
	var port_save:bool=data.get("schema")=="starfrontier-rebuild-world-v3" and data.get("version")==3
	var legacy_save:bool=data.get("schema")=="starfrontier-rebuild-world-v1" and data.get("version")==1
	if not full_save and not native_save and not port_save and not legacy_save:return false
	if not (data.get("system_id") is int or data.get("system_id") is float) or not is_finite(float(data.system_id)) or float(data.system_id)!=float(system_id):return false
	if not data.get("source_digest") is String:return false
	if full_save:
		if data.get("layout") not in [FULL_LAYOUT,EMPTY_LAYOUT] or data.get("preferred_layout")!=FULL_LAYOUT:return false
		if not data.get("station_state_by_site") is Dictionary or not data.get("body_spin_by_id") is Dictionary:return false
	elif port_save:
		if data.get("layout") not in [PORT_LAYOUT,EMPTY_LAYOUT] or data.get("preferred_layout")!=PORT_LAYOUT:return false
	elif native_save:
		if data.get("layout") not in [NATIVE_LAYOUT,EMPTY_LAYOUT] or data.get("preferred_layout")!=NATIVE_LAYOUT:return false
	elif data.get("layout") not in [SOURCE_LAYOUT,SOLAR_LAYOUT,EMPTY_LAYOUT] or data.has("preferred_layout"):return false
	for key in ["focus_id","selected_id","site_id","pending_id","pending_site_id"]:
		if not data.get(key) is String:return false
	var remaining:Variant=data.get("transfer_remaining")
	if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or float(remaining)<0 or float(remaining)>3:return false
	var candidate:RefCounted=get_script().new();candidate.configure(star_context,FULL_LAYOUT if full_save else str(data.layout))
	if candidate.layout_mode!=data.layout or candidate.source_digest!=data.source_digest:return false
	if full_save and not candidate._restore_full_frames(data.station_state_by_site,data.body_spin_by_id):return false
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
	requested_layout=FULL_LAYOUT if full_save else (PORT_LAYOUT if port_save else (NATIVE_LAYOUT if native_save else (SOURCE_LAYOUT if layout_mode==EMPTY_LAYOUT else layout_mode)))
	station_state_by_site=candidate.station_state_by_site.duplicate(true);body_spin_by_id=candidate.body_spin_by_id.duplicate(true);full_system_state=candidate.full_system_state.duplicate(true)
	orbit_backend_state=candidate.orbit_backend_state.duplicate(true)
	port_backend_state=candidate.port_backend_state.duplicate(true);source_physics_state=candidate.source_physics_state.duplicate(true)
	_native_cache_tick=candidate._native_cache_tick;_native_cache_day=candidate._native_cache_day
	_native_positions_raw=candidate._native_positions_raw.duplicate(true);_native_relative_raw=candidate._native_relative_raw.duplicate(true);native_evaluation_count=candidate.native_evaluation_count
	source_runtime_state=candidate.source_runtime_state.duplicate(true);_runtime_by_global=candidate._runtime_by_global.duplicate(true)
	focus_id=str(data.focus_id);selected_id=str(data.selected_id);site_id=str(data.site_id)
	pending_id=str(data.pending_id);pending_site_id=str(data.pending_site_id);transfer_remaining=float(remaining);message=""
	_full_surface_guard.clear_cache()
	return true

static func normalize_source_parameters(header:Dictionary)->Dictionary:
	for key in ["seed_a","mass","num_stars","system_id","population_raw"]:
		if not FullBuilder.Factory._u32(header.get(key)):return {}
	if FullBuilder.Factory._system_name_bytes(header).is_empty():return {}
	var original:=header.duplicate(true);var effective:=header.duplicate(true);var policies:Array[String]=[]
	if int(effective.seed_a)!=0 and int(effective.mass)==0xffffffff:
		effective.mass=0xfffffffe;policies.append(BETA_LYRAE_POLICY)
	if FullBuilder.root_radius_would_not_advance(effective):
		for attempt in range(64):
			effective.seed_a=(int(effective.seed_a)+1)&0xffffffff
			if int(effective.seed_a)==0:effective.seed_a=1
			if not FullBuilder.root_radius_would_not_advance(effective):break
		if FullBuilder.root_radius_would_not_advance(effective):return {}
		policies.append(ZERO_ROOT_RADIUS_POLICY)
	return {"original":original,"effective":effective,"policies":policies}

func _apply_full_system()->bool:
	var definition:=FullDefinition.new().describe(system_id)
	if definition.is_empty():return false
	var normalized:=normalize_source_parameters(definition.source_parameters)
	if normalized.is_empty():return false
	var original:Dictionary=normalized.original;var parameters:Dictionary=normalized.effective
	var correction:="+".join(normalized.policies)

	var generated:=FullBuilder.new().build(parameters)
	if not generated.get("ok",false):return false
	var catalogue_builder:=FullCatalogue.new();catalogue_builder.radius_provider=SourceTerrain.reference_radius
	var catalogue:=catalogue_builder.build(definition,generated)
	if not catalogue.get("ok",false):return false
	bodies=catalogue.bodies;settlements=catalogue.settlements;by_id.clear()
	for body:Dictionary in bodies:by_id[str(body.id)]=body
	default_id=str(catalogue.default_id)
	if not _prepare_native_positions(0.0):return false
	for body:Dictionary in bodies:
		var record:=str(body.runtime_record_hex).hex_decode()
		body_spin_by_id[str(body.id)]=_new_body_spin(record)
	full_system_state={"contract":FULL_CONTRACT,"definition_variant":FullDefinition.SOURCE_VARIANT,"builder_variant":FullBuilder.SOURCE_VARIANT,"catalogue_variant":FullCatalogue.SOURCE_VARIANT,"original_parameters":original,"effective_parameters":parameters,"caller_correction_policy":correction,"caller_correction_policies":normalized.policies,"runtime_bank_sha256":catalogue.runtime_bank_sha256,"descriptor_resource_sha256":catalogue.descriptor_resource_sha256}
	source_runtime_state={"source":FullBuilder.SOURCE_VARIANT,"record_domain":FullCatalogue.RECORD_DOMAIN,"count":int(generated.record_count),"record_bank_slots":128,"source_f881_entry_limit":60,"body_count_byte":int(generated.body_count_byte),"star_count_byte":int(generated.star_count_byte),"port_count_byte":int(generated.port_count_byte),"orbital_port_count_byte":int(generated.orbital_count_byte),"records_sha256":catalogue.runtime_bank_sha256,"language":int(generated.language),"physical_layout_changed":true,"caller_correction_policy":correction}
	orbit_backend_state={"source_variant":SourceOrbit.SOURCE_VARIANT,"contract":NATIVE_CONTRACT,"layout":FULL_LAYOUT,"coordinate_units":"raw geometry calibrated by16785/2^24 metres","celestial_parent_composition":"non-rotating signed64 translation","clock":"fixed F880 initialization at3250 epoch then ordinary F866 orbital updates via elapsed-days bridge","epoch_tick_u32":SourceClock.EPOCH_TICK_U32,"epoch_day_u32":SourceClock.EPOCH_DAY_U32,"orbital_ports_rendered":true,"complete_original_physics":false}
	port_backend_state={"contract":PORT_CONTRACT,"geometry_revision":StationGeometry.REVISION,"spin_revision":StationGeometry.SPIN_REVISION,"orbital_ports":int(generated.orbital_count_byte),"position":"native source centres with non-rotating parent translation","local_frame":"non-rotating station-following origin with persistent original Q31 model orientation","dock_local":[0,0,-2500],"complete_original_docking":false}
	source_physics_state={"source_variant":SourceGravity.SOURCE_VARIANT,"contract":PhysicsBridge.CONTRACT,"F880_a4_initialized":true,"body_count":bodies.size(),"live_gravity":PhysicsBridge.CONTRACT,"live_surface_radius":"source model geometry with explicit exterior-probe policy for117","source_time_policy_integrated":true,"gravity_parent_policy":"single_current_focus_parent_f603_v1","orbit_clearance_policy":OrbitSurfaceGuard.CONTRACT,"original_per_frame_dynamics":false,"complete_original_physics":false}
	var provenance:=[FULL_LAYOUT,FULL_CONTRACT,system_id,catalogue.runtime_bank_sha256,catalogue.descriptor_resource_sha256,FullDefinition.SOURCE_VARIANT,FullBuilder.SOURCE_VARIANT,FullCatalogue.SOURCE_VARIANT,SourceOrbit.SOURCE_VARIANT,PhysicsBridge.CONTRACT,SourceTerrain.REVISION_NAME,StationGeometry.REVISION,StationGeometry.SPIN_REVISION,OrbitSurfaceGuard.CONTRACT,correction]
	for path in ["res://data/ffe_system_metadata.json","res://data/ffe_stellar_factory.json","res://data/ffe_settlement_rules.json","res://data/ffe_planet_names.json","res://data/ffe_ground_collision.json","res://data/ffe_terrain_query.json","res://data/ffe_special_station_models.json"]:provenance.append(FileAccess.get_file_as_string(path).sha256_text())
	source_digest=JSON.stringify(provenance).sha256_text()
	return true

func _full_origin_raw(days:float)->PackedInt64Array:
	if not _prepare_native_positions(days):return PackedInt64Array()
	if is_orbital_site() and _native_positions_raw.has(site_id):
		var dock:=PhysicsBridge.relative_from_metres(-ORBITAL_DOCK_LOCAL)
		return SourceOrbit.add_positions(_native_positions_raw[site_id],dock)
	if not by_id.has(focus_id) or not _native_positions_raw.has(focus_id):return PackedInt64Array()
	var radius:=float(by_id[focus_id].radius_km)*1000.0
	var offset:=PhysicsBridge.relative_from_metres(-ARRIVAL_DIRECTION.normalized()*maxf(radius*4.0,3000000.0))
	return SourceOrbit.add_positions(_native_positions_raw[focus_id],offset)

func _full_local(point:PackedInt64Array,days:float)->Vector3:
	var origin:=_full_origin_raw(days)
	if origin.size()!=3:return Vector3.ZERO
	return Vector3(SourceUnits.metres(float(point[0]-origin[0])),SourceUnits.metres(float(point[1]-origin[1])),SourceUnits.metres(float(point[2]-origin[2])))

func _full_gravity_at(position:Vector3,days:float)->Vector3:
	if not position.is_finite() or not is_finite(days) or not _prepare_native_positions(days):return Vector3.ZERO
	var local_raw:=PhysicsBridge.relative_from_metres(position);var origin:=_full_origin_raw(days)
	if local_raw.size()!=3 or origin.size()!=3:return Vector3.ZERO
	if not by_id.has(focus_id) or not _native_positions_raw.has(focus_id):return Vector3.ZERO
	# F603 acts on the object's current parent. The focus frame selects that
	# parent; this is not an added Newtonian many-body force policy.
	var ship_raw:=SourceOrbit.add_positions(origin,local_raw)
	var body:Dictionary=by_id[focus_id];var centre:PackedInt64Array=_native_positions_raw[focus_id];var relative:=PackedInt64Array()
	for axis in range(3):relative.append(ship_raw[axis]-centre[axis])
	var sampled:=PhysicsBridge.sample_prepared(int(body.source_a4_packed),relative)
	return sampled.acceleration if not sampled.is_empty() else Vector3.ZERO

func _new_body_spin(record:PackedByteArray)->Dictionary:
	return {"revision":BODY_SPIN_REVISION,"rotation_raw":int(record[62]),"tilt_u16":int(record.decode_u16(66)),"matrix_q31":Array(SourceRotation.initialize(int(record[62]),int(record.decode_u16(66)),SourceClock.EPOCH_TICK_U32)),"tick_u32":SourceClock.EPOCH_TICK_U32,"day_u32":SourceClock.EPOCH_DAY_U32}

func _body_rotation_state(body_id:String,days:float)->Dictionary:
	if layout_mode!=FULL_LAYOUT or not by_id.has(body_id):return {}
	var clock:=SourceClock.from_elapsed_days(days)
	if clock.is_empty():return {}
	if not body_spin_by_id.has(body_id):body_spin_by_id[body_id]=_new_body_spin(str(by_id[body_id].runtime_record_hex).hex_decode())
	var spin:Dictionary=body_spin_by_id[body_id]
	var historical:=int(clock.day_u32)<int(spin.day_u32) or (int(clock.day_u32)==int(spin.day_u32) and int(clock.tick_u32)<int(spin.tick_u32))
	if historical:spin=_new_body_spin(str(by_id[body_id].runtime_record_hex).hex_decode())
	var advanced:=SourceRotation.advance(PackedInt64Array(spin.matrix_q31),int(spin.rotation_raw),int(spin.tilt_u16),0,int(spin.tick_u32),int(clock.tick_u32),int(spin.day_u32),int(clock.day_u32))
	spin.matrix_q31=Array(advanced.matrix);spin.tick_u32=int(clock.tick_u32);spin.day_u32=int(clock.day_u32)
	return spin

func body_rotation_basis(body_id:String,days:float)->Basis:
	return StationGeometry.orientation_basis(_body_rotation_state(body_id,days))

func body_rotation_state(body_id:String,days:float)->Dictionary:
	return _body_rotation_state(body_id,days).duplicate(true)

func source_surface_gravity(body_id:String,bodyfixed_point:Vector3,days:float)->Dictionary:
	if layout_mode!=FULL_LAYOUT or not by_id.has(body_id) or not bodyfixed_point.is_finite() or bodyfixed_point.length_squared()==0 or SourceClock.from_elapsed_days(days).is_empty():return {}
	var inertial:=body_rotation_basis(body_id,days)*bodyfixed_point
	var raw:=PhysicsBridge.relative_from_metres(inertial)
	if raw.size()!=3:return {}
	var result:=PhysicsBridge.sample_prepared(int(by_id[body_id].source_a4_packed),raw)
	if not result.is_empty():result["acceleration_frame"]="inertial_world_axes";result["body_id"]=body_id
	return result

func _station_state(days:float)->Dictionary:
	if layout_mode!=FULL_LAYOUT or not is_orbital_site():return {}
	var clock:=SourceClock.from_elapsed_days(days);var site:=current_site()
	if clock.is_empty() or int(site.get("model_index",-1)) not in StationGeometry.MODELS:return {}
	if not station_state_by_site.has(site_id):
		var record:=str(site.get("runtime_record_hex","")).hex_decode()
		var initialized:=StationGeometry.initialize_orientation(record,SourceClock.EPOCH_TICK_U32,SourceClock.EPOCH_DAY_U32)
		if initialized.is_empty():return {}
		station_state_by_site[site_id]={"site_id":site_id,"door_u16":0,"status_u8":0,"pending_launch":false,"spin":initialized}
	var state:Dictionary=station_state_by_site[site_id]
	var updated:=StationGeometry.advance_orientation(state.spin,int(clock.tick_u32),int(clock.day_u32))
	if updated.is_empty():return {}
	state.spin=updated
	return state

func source_station_state(days:float)->Dictionary:
	return _station_state(days).duplicate(true)

func source_station_geometry(days:float)->Dictionary:
	var state:=_station_state(days)
	return StationGeometry.prepare_site(current_site(),int(state.door_u16)) if not state.is_empty() else {}

func source_station_basis(days:float)->Basis:
	var state:=_station_state(days)
	return StationGeometry.orientation_basis(state.spin) if not state.is_empty() else Basis.IDENTITY

func request_station_open(days:float,launch_pending:bool=false)->bool:
	var state:=_station_state(days)
	if state.is_empty():return false
	# F865 subtracts for a negative signed status byte. Zero means stationary,
	# while door0 is the actual open aperture in the original station model.
	state.status_u8=254 if int(state.door_u16)>0 else 0
	state.pending_launch=bool(state.get("pending_launch",false)) or launch_pending
	return true

func station_launch_pending()->bool:
	return layout_mode==FULL_LAYOUT and is_orbital_site() and station_state_by_site.has(site_id) and bool(station_state_by_site[site_id].get("pending_launch",false))

func station_launch_ready()->bool:
	return station_launch_pending() and int(station_state_by_site[site_id].door_u16)==0

func cancel_station_launch()->bool:
	if not station_launch_pending():return false
	station_state_by_site[site_id].pending_launch=false
	return true

func finish_station_launch(succeeded:bool)->bool:
	if not succeeded or not station_launch_ready():return false
	station_state_by_site[site_id].pending_launch=false
	return true

func advance_station(dt:float,days:float)->bool:
	if layout_mode!=FULL_LAYOUT or not is_finite(dt) or dt<0 or dt*PhysicsBridge.TICKS_PER_SECOND>0xffffffff:return false
	if SourceClock.from_elapsed_days(days).is_empty():return false
	if not is_orbital_site():return true
	var state:=_station_state(days)
	if state.is_empty():return false
	var door:=StationGeometry.advance_door(int(state.door_u16),int(state.status_u8),roundi(dt*PhysicsBridge.TICKS_PER_SECOND))
	if door.is_empty():return false
	state.door_u16=int(door.door_u16);state.status_u8=int(door.status_u8)
	return true

func _valid_body_spin(spin:Variant,record:PackedByteArray)->bool:
	if not spin is Dictionary or spin.get("revision")!=BODY_SPIN_REVISION or not spin.get("matrix_q31") is Array or spin.matrix_q31.size()!=9:return false
	if spin.get("rotation_raw")!=int(record[62]) or spin.get("tilt_u16")!=int(record.decode_u16(66)):return false
	if not SourceClock._u32(spin.get("tick_u32")) or not SourceClock._u32(spin.get("day_u32")):return false
	for value in spin.matrix_q31:
		if not StationGeometry._s32(value):return false
	var values:Array=spin.matrix_q31
	var basis:=Basis(Vector3(values[0],values[1],values[2])/2147483648.0,Vector3(values[3],values[4],values[5])/2147483648.0,Vector3(values[6],values[7],values[8])/2147483648.0)
	return basis.is_finite() and basis.determinant()>0.99 and absf(basis.x.length_squared()-1.0)<0.001 and absf(basis.y.length_squared()-1.0)<0.001 and absf(basis.z.length_squared()-1.0)<0.001 and absf(basis.x.dot(basis.y))<0.001 and absf(basis.x.dot(basis.z))<0.001 and absf(basis.y.dot(basis.z))<0.001

func _restore_full_frames(stations:Dictionary,spins:Dictionary)->bool:
	if layout_mode==EMPTY_LAYOUT:return stations.is_empty() and spins.is_empty()
	if spins.size()!=bodies.size():return false
	for body:Dictionary in bodies:
		var record:=str(body.runtime_record_hex).hex_decode()
		if not spins.has(str(body.id)) or not _valid_body_spin(spins[str(body.id)],record):return false
	for key in stations:
		if not key is String:return false
		var site:=get_site(key);var state:Variant=stations[key]
		if site.is_empty() or int(site.type_code) not in [32,33,34] or int(site.model_index) not in StationGeometry.MODELS or not state is Dictionary or state.get("site_id")!=key:return false
		if state.has("pending_launch") and not state.pending_launch is bool:return false
		if not StationGeometry._u16(state.get("door_u16")) or not StationGeometry._u16(state.get("status_u8")) or int(state.status_u8)>255 or not state.get("spin") is Dictionary:return false
		var spin:Dictionary=state.spin;var record:=str(site.runtime_record_hex).hex_decode()
		if spin.get("model_index")!=int(site.model_index) or spin.get("rotation_raw")!=int(record[62]) or spin.get("tilt_u16")!=int(record.decode_u16(66)):return false
		if StationGeometry.advance_orientation(spin,spin.get("tick_u32"),spin.get("day_u32")).is_empty():return false
		var equivalent:=spin.duplicate(true);equivalent.revision=BODY_SPIN_REVISION
		if not _valid_body_spin(equivalent,record):return false
	station_state_by_site.clear();body_spin_by_id.clear()
	for key in spins:
		var normalized:Dictionary=spins[key].duplicate(true)
		for field in ["rotation_raw","tilt_u16","tick_u32","day_u32"]:normalized[field]=int(normalized[field])
		normalized.matrix_q31=Array(PackedInt64Array(normalized.matrix_q31));body_spin_by_id[key]=normalized
	for key in stations:
		var normalized:Dictionary=stations[key].duplicate(true)
		normalized.door_u16=int(normalized.door_u16);normalized.status_u8=int(normalized.status_u8);normalized.pending_launch=bool(normalized.get("pending_launch",false))
		normalized.spin=StationGeometry.advance_orientation(normalized.spin,int(normalized.spin.tick_u32),int(normalized.spin.day_u32))
		station_state_by_site[key]=normalized
	return true
