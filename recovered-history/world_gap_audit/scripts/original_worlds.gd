extends RefCounted
# Original hierarchy + explicit analytic adapter, NOT original FFE ephemerides.
const AU:=149597870700.0
const FFPMath=preload("res://scripts/ffe_math.gd")
const EARTH_ORBIT_RAW:=4458427.0
var data:Dictionary
var names:Dictionary
func _init()->void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_worlds.json"))
	names=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_names_ru.json"))
func system(star:Dictionary)->Dictionary:
	for entry in data.systems:
		if int(entry.system_id)==int(star.id):return entry
	if star.original_name=="Riedquat":return {"system_id":star.id,"name_en":"Riedquat","objects":data.unmatched_fallback}
	return {}
func translate(name:String)->String:return str(names.get(name,name))
func apply(context:RefCounted,star:Dictionary,precise:bool=false)->bool:
	var entry:=system(star)
	if entry.is_empty():return false
	context.bodies.clear();context.by_id.clear();context.settlements.clear()
	var ids:Dictionary={}
	var solar_ids:Dictionary={"Sol":"star","Mercury":"mercury","Venus":"venus","Earth":"earth","Mars":"mars","Jupiter":"jupiter","Saturn":"saturn","Uranus":"uranus","Neptune":"neptune","Pluto":"pluto","Moon":"moon","Io":"io","Europa":"europa","Ganymede":"ganymede","Callisto":"callisto","Titan":"titan"}
	var solar_radii:Dictionary={"Sol":696340.0,"Mercury":2439.7,"Venus":6051.8,"Earth":6371.0,"Mars":3389.5,"Jupiter":69911.0,"Saturn":58232.0,"Uranus":25362.0,"Neptune":24622.0,"Pluto":1188.3,"Moon":1737.4,"Io":1821.6,"Europa":1560.8,"Ganymede":2634.1,"Callisto":2410.3,"Titan":2574.7}
	for row in entry.objects:
		if int(row.type_code)>=32:continue
		var id:="star" if int(row.local_index)==1 else "hc%d"%int(row.local_index)
		if star.original_name=="Sol":id=str(solar_ids.get(row.name_en,id))
		ids[int(row.local_index)]=id
	for row in entry.objects:
		var type_code:=int(row.type_code)
		if type_code>=32:continue
		var parent: String=ids.get(int(row.parent_index),"")
		var kind:="rock"
		if type_code==0:kind="barycenter"
		elif type_code>=18:kind="star"
		elif type_code>=13:kind="gas"
		elif type_code in [9,10,11]:kind="earth"
		elif type_code in [4,5,6,7,8,12]:kind="desert"
		var mass:=maxf(1e-12,float(row.mass_raw)/200000000.0)
		var radius:=6371.0*float(row.model_radius_raw)/29792.0*pow(2.0,float(row.model_scale_raw)-18.0)
		if star.original_name=="Sol" and solar_radii.has(row.name_en):radius=float(solar_radii[row.name_en])
		if kind=="barycenter":radius=0
		var a:float=float(row.orbit_raw)/EARTH_ORBIT_RAW if parent!="" else 0.0
		var period:=0.0
		if parent!="":
			var parent_mass:float=context.by_id[parent].mass_solar
			period=365.256*sqrt(pow(a,3)/(parent_mass+mass))
		var packed_mass:=FFPMath.shift(FFPMath.from_uint(int(row.mass_raw)),63)
		var packed_orbit:=FFPMath.shift(FFPMath.from_uint(int(row.orbit_raw)),25)
		var packed_period:=0
		if precise:
			mass=maxf(1e-12,FFPMath.real(packed_mass)/FFPMath.real(FFPMath.shift(FFPMath.from_uint(200000000),63)))
			a=FFPMath.real(packed_orbit)/1000.0/AU if parent!="" else 0.0
			if parent!="":
				packed_period=FFPMath.period(packed_orbit,int(context.by_id[parent].mass_ffp))
				period=FFPMath.real(packed_period)/86400.0
		var body:={"id":ids[int(row.local_index)],"name":translate(row.name_en),"name_en":row.name_en,"parent":parent,"kind":kind,"radius_km":radius,"mass_solar":mass,"a_au":a,"eccentricity":0.0,"inclination":deg_to_rad(float(row.inclination_tenths_raw)/10.0),"node":0.0,"periapsis":0.0,"phase":deg_to_rad(float(row.phase_degrees)),"period_days":period,"rotation_hours":24.0,"rings":row.name_en=="Saturn","source":"ffe_handcrafted","original_index":int(row.local_index),"original_type":type_code,"temperature_c":int(row.temperature_c)}
		if precise:
			body.mass_ffp=packed_mass;body.orbit_ffp=packed_orbit;body.period_ffp=packed_period
			body.phase=float(((int(row.phase_degrees)<<16)&0xffffffff)/360&65535)*TAU/65536.0
			body.inclination=float(((int(row.inclination_tenths_raw)<<16)&0xffffffff)/3600&65535)*TAU/65536.0
		context._add(body)
	for row in entry.objects:
		if int(row.type_code)<32:continue
		var parent:String=ids.get(int(row.parent_index),"")
		if parent.is_empty():continue
		context.settlements.append({"id":"site%d"%row.local_index,"name":translate(row.name_en),"name_en":row.name_en,"parent":parent,"orbit_raw":int(row.get("orbit_raw",0)),"type_code":int(row.type_code),"model_index":int(row.model_index),"latitude_raw":int(row.get("latitude_raw",0)),"longitude_raw":int(row.get("longitude_raw",0)),"original_index":int(row.local_index)})
	context.default_id=""
	if star.original_name=="Sol":context.default_id="earth"
	elif star.original_name=="Alpha Centauri":
		for body in context.bodies:
			if body.name_en=="Eden":context.default_id=body.id
	if context.default_id.is_empty():
		for body in context.bodies:
			if body.kind=="earth":context.default_id=body.id;break
	if context.default_id.is_empty():
		for body in context.bodies:
			if body.kind not in ["star","barycenter","gas"]:context.default_id=body.id;break
	return not context.default_id.is_empty()
