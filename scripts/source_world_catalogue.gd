extends RefCounted
# Adapter for an actual completed F878 runtime bank. No constructor templates,
# modern Solar System constants, synthetic ports or replacement hierarchy.
const Math=preload("res://scripts/ffe_math.gd")
const Units=preload("res://scripts/source_units.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const SOURCE_VARIANT:="jjffe-7e54034-runtime-world-catalogue-v1"
const RECORD_DOMAIN:="f878_runtime_bank_with_unconverted_type35_fields"
const MASS_ADAPTER:="packed_mass_ratio_to_f878_sol_005b5f5e_display_v1"
const SOL_ID:=0x02a49718
const SOL_MASS_PACKED:=0x005b5f5e
const AU_METRES:=149597870700.0
const MODEL117_POLICY:="source_exterior_probe_125pct_axes_v1"
const SOL_IDS:={"Sol":"star","Mercury":"mercury","Venus":"venus","Earth":"earth","Mars":"mars","Jupiter":"jupiter","Saturn":"saturn","Uranus":"uranus","Neptune":"neptune","Pluto":"pluto","Moon":"moon","Io":"io","Europa":"europa","Ganymede":"ganymede","Callisto":"callisto","Titan":"titan"}
var radius_provider:Callable
var _models:Dictionary={}
var _terrain:Dictionary={}
var _translations:Dictionary={}
var _resource_digest:=""

static func _integer(value:Variant,maximum:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=maximum and float(value)==floorf(float(value))

static func _sha(raw:PackedByteArray)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(raw);return context.finish().hex_encode()

static func _read(path:String)->Dictionary:
	if not FileAccess.file_exists(path):return {}
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _load()->bool:
	if not _models.is_empty():return true
	var path:="res://data/ffe_runtime_model_descriptors.json"
	var resource:=_read(path)
	if resource.get("schema")!=1 or resource.get("source_sha256")!="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" or not resource.get("models") is Dictionary:return false
	_models=resource.models
	_terrain=_read("res://data/ffe_terrain_query.json").get("models",{})
	_translations=_read("res://data/world_names_ru.json")
	_resource_digest=FileAccess.get_file_as_string(path).sha256_text()
	return not _terrain.is_empty()

static func display_name(name_bytes:PackedByteArray)->Dictionary:
	# The source's extended glyph set is not UTF-8 or a proven DOS code page.
	# Keep every byte and use U+FFFD for unknown/control glyphs in the UI only.
	var title:="";var substituted:=false
	for value in name_bytes:
		if value==0:break
		if value>=32 and value<=126:title+=String.chr(value)
		else:title+=String.chr(0xfffd);substituted=true
	return {"text":title,"has_unmapped_glyphs":substituted,"encoding":"original_source_bytes_ascii_safe_fallback_v1"}

static func _name_bytes(record:PackedByteArray)->PackedByteArray:
	for offset in range(38,62):
		if record[offset]==0:return record.slice(38,offset+1)
	return PackedByteArray()

func _reference_radius(record:PackedByteArray)->Dictionary:
	var model:=int(record.decode_u16(12))
	if model<117 or model>133:return {"metres":0.0,"landable":false,"policy":"no_native_natural_terrain_domain"}
	var data:Variant=_terrain.get(str(model))
	if not data is Dictionary or not data.get("static_axis_vertices_raw") is Array:return {}
	var axes:Array=data.static_axis_vertices_raw
	if axes.size()!=3:return {}
	var corrected:=model==117
	if not corrected and (axes[0]!=axes[1] or axes[0]!=axes[2]):return {}
	var radius:=Units.metres(float(maxi(absi(int(axes[0])),maxi(absi(int(axes[1])),absi(int(axes[2])))))*pow(2.0,int(data.mesh_zoom)))
	if corrected:radius*=1.25
	if radius_provider.is_valid():
		var provided:Variant=radius_provider.call(record.duplicate())
		if not (provided is float or provided is int):return {}
		radius=float(provided)
	if not is_finite(radius) or radius<=0:return {}
	return {"metres":radius,"landable":true,"policy":MODEL117_POLICY if corrected else "original_static_equal_axis_reference_not_terrain_height_v1"}

static func _kind(type_code:int)->String:
	if type_code==0:return "barycenter"
	if type_code>=17:return "star"
	if type_code>=13:return "gas"
	if type_code in [9,10,11]:return "earth"
	if type_code in [4,5,6,7,8,12]:return "desert"
	return "rock"

static func _reject(reason:String)->Dictionary:return {"ok":false,"error":reason,"source_variant":SOURCE_VARIANT}

func build(star:Dictionary,generated:Dictionary)->Dictionary:
	if not generated.get("ok",false) or not generated.get("records") is Array or generated.records.size()!=128:return _reject("invalid_runtime_bank")
	if not _integer(generated.get("record_count"),127) or int(generated.record_count)==0:return _reject("invalid_record_count")
	for key in ["body_count_byte","star_count_byte","port_count_byte","orbital_count_byte"]:
		if not _integer(generated.get(key),255):return _reject("invalid_source_count")
	if not generated.get("source_variant") is String or str(generated.source_variant).is_empty():return _reject("missing_runtime_provenance")
	var count:=int(generated.record_count);var records:Array=generated.records
	for record in records:
		if not record is PackedByteArray or record.size()!=68:return _reject("invalid_runtime_record")
	if records[count].decode_u32(0)!=0:return _reject("missing_runtime_sentinel")
	if not _integer(star.get("id"),0xffffffff):return _reject("invalid_system_id")
	if not _load():return _reject("missing_source_models")
	var ids:Dictionary={};var infos:Array=[];var all_ids:Dictionary={};var bank_bytes:=PackedByteArray()
	for record:PackedByteArray in records:bank_bytes.append_array(record)
	for index in range(count):
		var record:PackedByteArray=records[index];var type_code:=int(record.decode_u16(10));var model:=int(record.decode_u16(12));var parent:=int(record.decode_u16(8))
		if record.decode_u32(0)==0:return _reject("early_runtime_sentinel")
		if type_code>35 or type_code==31:return _reject("unsupported_source_type")
		if parent>count or parent==index+1 or (type_code>=32 and parent==0):return _reject("invalid_parent")
		var descriptor:Variant=_models.get(str(model))
		if not descriptor is Dictionary:return _reject("missing_model_descriptor")
		var raw_descriptor:=str(descriptor.get("descriptor_hex","")).hex_decode()
		if raw_descriptor.size()!=68 or _sha(raw_descriptor)!=str(descriptor.get("descriptor_sha256","")):return _reject("invalid_model_descriptor")
		var name_bytes:=_name_bytes(record)
		if name_bytes.is_empty():return _reject("unterminated_source_name")
		var safe:=display_name(name_bytes);var english:=str(safe.text)
		var id:="site%d"%(index+1) if type_code>=32 else ("star" if index==0 else "hc%d"%(index+1))
		if int(star.id)==SOL_ID and type_code<32:id=str(SOL_IDS.get(english,id))
		if all_ids.has(id):return _reject("duplicate_display_id")
		all_ids[id]=true;ids[index+1]=id
		infos.append({"record":record,"type":type_code,"model":model,"parent":parent,"descriptor":descriptor,"name_bytes":name_bytes,"safe":safe,"english":english})
	# Validate the whole forest before constructing any externally visible row.
	var order:Array=[];var done:Dictionary={}
	while order.size()<count:
		var progress:=false
		for index in range(count):
			if done.has(index+1):continue
			var parent:=int(infos[index].parent)
			if parent!=0 and int(infos[parent-1].type)>=32:return _reject("settlement_as_parent")
			if parent==0 or done.has(parent):order.append(index);done[index+1]=true;progress=true
		if not progress:return _reject("cyclic_parent_forest")
	var bodies:Array=[];var settlements:Array=[];var default_id:=""
	for index:int in order:
		var info:Dictionary=infos[index];var record:PackedByteArray=info.record;var descriptor:Dictionary=info.descriptor
		var type_code:=int(info.type);var model:=int(info.model);var raw_descriptor:=str(descriptor.descriptor_hex).hex_decode()
		var exponent:=int(raw_descriptor.decode_u32(20))+int(raw_descriptor.decode_u32(24))-8
		var outer:=Units.metres(float(Math.s16(raw_descriptor.decode_u16(44)))*pow(2.0,exponent))
		var inner:=Units.metres(float(Math.s16(raw_descriptor.decode_u16(48)))*pow(2.0,exponent))
		if not is_finite(outer) or not is_finite(inner) or outer<0 or inner<0:return _reject("invalid_descriptor_bound")
		var row:={"id":ids[index+1],"name":str(_translations.get(info.english,info.english)),"name_en":info.english,"parent":str(ids.get(info.parent,"")),"original_index":index+1,"original_type":type_code,"type_code":type_code,"model_index":model,"source":SOURCE_VARIANT,"runtime_record_hex":record.hex_encode(),"runtime_record_source":str(generated.get("source_variant","")),"runtime_record_domain":RECORD_DOMAIN,"source_record_domain":RECORD_DOMAIN,"source_seed":int(record.decode_u32(4)),"source_uid_u32":int(record.decode_u32(4)),"source_parent_index":int(info.parent),"source_name_bytes_hex":info.name_bytes.hex_encode(),"source_name_encoding":info.safe.encoding,"source_name_has_unmapped_glyphs":info.safe.has_unmapped_glyphs,"source_mass_raw_u32":int(record.decode_u32(0)),"source_orbit_raw_u32":int(record.decode_u32(14)),"source_phase_u16":int(record.decode_u16(18)),"source_period_raw_u32":int(record.decode_u32(20)),"source_inclination_u16":int(record.decode_u16(34)),"source_temperature_u16":int(record.decode_u16(36)),"source_rotation_raw":int(record[62]),"source_generation_depth_u8":int(record[63]),"source_orientation_u16":int(record.decode_u16(66)),"source_outer_bound_m":outer,"source_inner_bound_m":inner,"source_bound_role":"original_descriptor_spheres_not_terrain_surface","source_model_descriptor_sha256":descriptor.descriptor_sha256,"source_model_descriptor_offset":int(descriptor.descriptor_executable_offset),"source_model_scale_raw":exponent,"source_model_flags_u32":int(descriptor.source_flags_u32),"temperature_c":int(record.decode_u16(36))-273}
		if type_code>=32:
			row.orbit_raw=int(record.decode_u32(14));row.source_parameter_domain="unconverted_ground_constructor_fields" if type_code==35 else "packed_runtime_fields"
			if type_code==35:
				row.ground_phase_u16=int(record.decode_u16(18));row.ground_inclination_u16=int(record.decode_u16(34));row.ground_coordinate_source="original_runtime_angle_words"
			settlements.append(row);continue
		var radius:=_reference_radius(record)
		if radius.is_empty():return _reject("invalid_natural_reference_radius")
		var mass:=Math.real(int(record.decode_u32(0)));var orbit:=Units.metres(Math.real(int(record.decode_u32(14))));var period:=Math.real(int(record.decode_u32(20)))
		if not is_finite(mass) or not is_finite(orbit) or not is_finite(period) or mass<0 or orbit<0 or period<0:return _reject("invalid_packed_physical_fields")
		var coefficient:=Gravity.coefficient(record)
		if coefficient.is_empty():return _reject("invalid_source_gravity_coefficient")
		row.kind=_kind(type_code);row.landable=radius.landable and type_code!=0 and type_code<17
		row.radius_km=(float(radius.metres) if row.landable else outer)/1000.0
		if type_code==0:row.radius_km=0.0
		row.radius_policy=radius.policy if row.landable else "descriptor_bound_render_reference_no_native_landable_domain"
		row.source_reference_radius_m=float(radius.metres);row.source_a4_packed=int(coefficient.a4_u32)
		row.mass_solar=mass/Math.real(SOL_MASS_PACKED);row.mass_adapter=MASS_ADAPTER
		row.a_au=orbit/AU_METRES;row.period_days=period/86400.0;row.inclination=float(Math.s16(record.decode_u16(34)))*TAU/65536.0
		row.phase=float(record.decode_u16(18))*TAU/65536.0
		row.eccentricity=0.0;row.node=0.0;row.periapsis=0.0;row.rings=false
		row.orbital_element_policy="native_record_phase_and_inclination_no_keplerian_reconstruction"
		var spin:=int(record[62]);spin=spin-256 if spin>=128 else spin
		row.rotation_hours=0.0 if spin==0 else 24.0*pow(2.0,1-spin)
		row.rotation_policy="source_f866_tick_shift_elapsed_day_display_adapter"
		row.physical_adapter="original_runtime_units_with_explicit_display_adapters_v1"
		bodies.append(row)
		if default_id.is_empty() and row.landable:default_id=str(row.id)
		if int(star.id)==SOL_ID and row.id=="earth":default_id="earth"
	if default_id.is_empty():
		for body:Dictionary in bodies:
			if body.kind!="barycenter":default_id=str(body.id);break
	if default_id.is_empty():return _reject("no_visible_natural_body")
	return {"ok":true,"bodies":bodies,"settlements":settlements,"default_id":default_id,"record_count":count,"source_variant":SOURCE_VARIANT,"runtime_record_domain":RECORD_DOMAIN,"runtime_bank_sha256":_sha(bank_bytes),"descriptor_resource_sha256":_resource_digest,"mass_adapter":MASS_ADAPTER,"radius_policy":"source_static_terrain_axes_or_explicit_descriptor_render_reference","counts":{"body_count_byte":int(generated.get("body_count_byte",0)),"star_count_byte":int(generated.get("star_count_byte",0)),"port_count_byte":int(generated.get("port_count_byte",0)),"orbital_count_byte":int(generated.get("orbital_count_byte",0))}}
