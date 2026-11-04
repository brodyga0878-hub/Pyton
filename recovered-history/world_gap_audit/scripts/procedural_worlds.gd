extends RefCounted
# Exact generated records -> existing analytic flight model. Not original FFE ephemerides/terrain.
const Inputs=preload("res://scripts/world_inputs.gd")
const Math=preload("res://scripts/ffe_math.gd")
const AU:=149597870700.0
var inputs:=Inputs.new()
var geometry:Dictionary
var geometry_hash:PackedByteArray
func _init()->void:
	var raw:=FileAccess.get_file_as_bytes("res://data/ffe_body_geometry.json")
	geometry=JSON.parse_string(raw.get_string_from_utf8())
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw);geometry_hash=hash.finish()
static func display_name(row:PackedByteArray)->String:
	var result:=""
	for byte in row.slice(38,62):
		if byte==0:break
		result+=String.chr(byte) if byte>=32 and byte<127 else "�"
	return result.strip_edges()
func apply(context:RefCounted,star:Dictionary)->bool:
	var resolved:Dictionary
	if int(star.id) in [0x1aa89738,0x2ae1718,0xeb6973d]:resolved=inputs.generate_special_research(star)
	else:resolved=inputs.generate_named_research(star)
	if resolved.status!="generated":return false
	return apply_records(context,star,resolved.world.records)
func apply_records(context:RefCounted,star:Dictionary,records:Array)->bool:
	if records.is_empty() or records.size()>60:return false
	var bodies:Array=[];var sites:Array=[];var ids:Dictionary={};var by_id:Dictionary={}
	var solar_mass:=Math.real(Math.shift(Math.from_uint(200000000),63))
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update("source-flight-v1".to_utf8_buffer());hash.update(geometry_hash)
	for i in range(records.size()):
		var row=records[i]
		if not row is PackedByteArray or row.size()!=68:return false
		var parent:=int(row.decode_u16(8));var kind:=int(row.decode_u16(10));var model:=int(row.decode_u16(12))
		if parent>i or (i>0 and parent==0):return false
		hash.update(row)
		if kind>=32:continue
		if not geometry.models.has(str(model)):return false
		var id:="star" if i==0 else "fg%d"%(i+1)
		var parent_id:String=ids.get(parent,"")
		if parent>0 and parent_id.is_empty():return false
		var category:="rock"
		if kind==0:category="barycenter"
		elif kind>=17:category="star"
		elif kind>=13:category="gas"
		elif kind in [9,10,11]:category="earth"
		elif kind in [4,5,6,7,8,12]:category="desert"
		var shape:Dictionary=geometry.models[str(model)]
		var radius:=0.0 if category=="barycenter" else 6371.0*float(shape.radius_raw)/29792.0*pow(2.0,float(shape.scale_raw)-18.0)
		var mass:=Math.real(int(row.decode_u32(0)))/solar_mass
		var orbit:=Math.real(int(row.decode_u32(14)))/1000.0/AU if parent>0 else 0.0
		var period:=Math.real(int(row.decode_u32(20)))/86400.0 if parent>0 else 0.0
		if not is_finite(radius) or not is_finite(mass) or not is_finite(orbit) or not is_finite(period):return false
		if radius<0 or mass<0 or orbit<0 or period<0 or (orbit>0 and period<=0):return false
		var title:=display_name(row)
		if title.is_empty():title="Объект %d"%(i+1)
		var body:={"id":id,"name":title,"name_en":title,"parent":parent_id,"kind":category,"radius_km":radius,"mass_solar":maxf(1e-12,mass),"a_au":orbit,"eccentricity":0.0,"inclination":float(row.decode_u16(34))*TAU/65536.0,"node":0.0,"periapsis":0.0,"phase":float(row.decode_u16(18))*TAU/65536.0,"period_days":period,"rotation_hours":24.0,"rings":false,"source":"ffe_procedural","original_index":i+1,"original_type":kind,"model_index":model,"temperature_raw":int(row.decode_u16(36)),"mass_ffp":int(row.decode_u32(0)),"orbit_ffp":int(row.decode_u32(14)),"period_ffp":int(row.decode_u32(20)),"record_hex":row.hex_encode(),"special_world":model==0x85}
		bodies.append(body);by_id[id]=body;ids[i+1]=id
	for i in range(records.size()):
		var row:PackedByteArray=records[i];var kind:=int(row.decode_u16(10))
		if kind<32:continue
		if kind>35:return false
		var parent:String=ids.get(int(row.decode_u16(8)),"")
		if parent.is_empty():return false
		var title:=display_name(row)
		sites.append({"id":"fgsite%d"%(i+1),"name":title,"name_en":title,"parent":parent,"orbit_raw":int(row.decode_u32(14)),"type_code":kind,"model_index":int(row.decode_u16(12)),"latitude_raw":int(row.decode_u16(18)),"longitude_raw":int(row.decode_u16(34)),"original_index":i+1,"record_hex":row.hex_encode(),"source":"ffe_procedural"})
	var arrival:=""
	for category in [["earth"],["rock","desert","ice"],["gas","ice_gas"],["star"]]:
		for body in bodies:
			if body.kind in category:arrival=body.id;break
		if not arrival.is_empty():break
	if arrival.is_empty():return false
	if by_id[arrival].kind=="star":by_id[arrival].arrival_only=true
	context.bodies=bodies;context.by_id=by_id;context.settlements=sites;context.default_id=arrival;context.source_digest=hash.finish().hex_encode()
	return true
