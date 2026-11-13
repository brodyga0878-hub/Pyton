extends RefCounted
# Characterization, not a collision policy. Every terrain/provider/object below
# belongs to this isolated experiment; no live World, ship, HP or clock is used.
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Natural=preload("res://scripts/source_natural_contact.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const Bridge=preload("res://scripts/source_surface_contact_bridge.gd")
const Frame=preload("res://scripts/source_surface_render_state.gd")
const Contact=preload("res://scripts/source_surface_contact_patch.gd")
const Catalog=preload("res://scripts/ship_catalog.gd")
const FIXTURE:="res://tests/fixtures/source_ground_surface_native.json"
const PLAYERS:={24:"eagle",38:"cobra",15:"shuttle"}
const INPUTS:=["scripts/source_surface_terrain.gd","scripts/source_ground_surface.gd","scripts/source_terrain_point.gd","scripts/source_terrain_query.gd","scripts/source_natural_contact.gd","scripts/source_surface_contact_bridge.gd","scripts/source_surface_render_state.gd","scripts/source_surface_contact_patch.gd","scripts/surface_model.gd","data/ships.json","data/ffe_natural_contact.json","tests/fixtures/source_ground_surface_native.json","tools/check_source_contact_alignment.gd"]
class NativeSystem extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=44341016
var _classifier:=Natural.new()
var _catalog:=Catalog.new()
var _errors:Array=[]
var _classifications:Array=[]
var _metrics:Array=[]
var _branches:Dictionary={}
var _source_pins:Dictionary={}

static func _vector_hex(point:PackedInt64Array)->String:
	var raw:=PackedByteArray();raw.resize(24)
	for axis in range(3):raw.encode_s64(axis*8,point[axis])
	return raw.hex_encode()
static func _hex64(value:int)->String:
	var raw:=PackedByteArray();raw.resize(8);raw.encode_s64(0,value);return raw.hex_encode()
static func _radius(point:PackedInt64Array)->float:
	return sqrt(float(point[0])*point[0]+float(point[1])*point[1]+float(point[2])*point[2])
static func _matrix_write(object:PackedByteArray,matrix:PackedInt64Array)->void:
	for element in range(9):object.encode_s32(element*4,matrix[element])
static func _raw(values:PackedFloat64Array)->PackedInt64Array:
	var result:=PackedInt64Array()
	for value in values:result.append(roundi(value/Bridge.Units.METRES_PER_RAW))
	return result
static func _phone_raw(globe:RefCounted,x:float,height:float,z:float)->PackedInt64Array:
	return _raw(Bridge.to_bodyfixed_point(globe.basis_at(globe.latitude,globe.longitude),globe.radius,Vector3(x,height,z)))
static func _scalar_raw(globe:RefCounted,x:float,height:float,z:float)->PackedInt64Array:
	var axes:=Frame._axes(globe.latitude,globe.longitude);var values:=PackedFloat64Array()
	for axis in range(3):values.append(float(axes[0][axis])*x+float(axes[1][axis])*(globe.radius+height)+float(axes[2][axis])*z)
	return _raw(values)
static func _distance(first:PackedInt64Array,second:PackedInt64Array)->float:
	var sum:=0.0
	for axis in range(3):sum+=pow(float(first[axis]-second[axis]),2)
	return sqrt(sum)*Bridge.Units.METRES_PER_RAW

func _classify(globe:RefCounted,record:PackedByteArray,player_model:int,relative:PackedInt64Array,label:String,anchor:String,offset_name:String,offset_m:float,phone_offset_m:float,native_offset_m:float)->void:
	var descriptor:=Natural.ship_model(player_model)
	var player:=PackedByteArray();player.resize(Natural.OBJECT_BYTES);player.fill(0);var initial_parent:=player.duplicate()
	_matrix_write(player,Bridge.contact_orientation_q31(globe.basis_at(globe.latitude,globe.longitude),Quaternion.IDENTITY))
	_matrix_write(initial_parent,PackedInt64Array([0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff]))
	player.encode_u32(0x82,player_model);player[0x86]=1;player[0x56]=2;player[0x57]=1;player[0x14c]=int(descriptor.initial_object_flags_14c_u8)
	player.encode_s64(0x138,int(descriptor.f1533_radii.outer_s64));player.encode_s64(0x140,int(descriptor.f1533_radii.inner_s64))
	initial_parent[0x86]=2;initial_parent.encode_u32(0xa0,record.decode_u32(4))
	var initialized:=Ground.initialize_model(initial_parent,int(record.decode_u16(12)))
	if initialized.is_empty():_errors.append("Missing original parent descriptor");return
	var parent:PackedByteArray=initialized.object
	var before:=var_to_bytes([player,parent,relative]);var result:=_classifier.classify_natural_player(player,parent,relative,{"graphics_level":1,"initial_globals":{}})
	if before!=var_to_bytes([player,parent,relative]):_errors.append("Classifier mutated caller data")
	if not result.get("ok",false):_errors.append("Rejected matrix point: "+str(result.get("error","")));return
	var last:Dictionary=result.iterations[-1];var branch:=str(last.branch)
	_branches[branch]=int(_branches.get(branch,0))+1
	var query_previous:Variant=int(result.previous_altitude_s64)*Bridge.Units.METRES_PER_RAW if int(result.terrain_query_calls)>0 else null
	_classifications.append({"model_index":int(record.decode_u16(12)),"player_model":player_model,"anchor":anchor,"height_layer":label,"offset_policy":offset_name,"offset_m":offset_m,"phone_clearance_m":phone_offset_m,"native_inner_m":native_offset_m,"relative_s64_hex":_vector_hex(relative),"return_s32":int(result.return_s32),"kind_u8":int(result.globals_after.collision_kind_u8),"last_branch":branch,"volume_count":result.iterations.size(),"terrain_query_calls":int(result.terrain_query_calls),"previous_altitude_s64_hex":_hex64(int(result.previous_altitude_s64)),"previous_altitude_m_when_query_executed":query_previous,"F575_correction_m_if_query_kind1":native_offset_m-float(query_previous) if query_previous!=null and int(result.return_s32)==0 and int(result.globals_after.collision_kind_u8)==1 else null,"F575_executed":false})

func _saved_triangle(globe:RefCounted,width:float,cells:int)->Dictionary:
	var step:=width/cells;var points:Array=[]
	for point in [Vector2.ZERO,Vector2(step,0),Vector2(0,step)]:points.append(Vector3(point.x,globe.raw_height(point.x,point.y),point.y))
	var frame:={"latitude":globe.latitude,"longitude":globe.longitude,"radius":globe.radius,"record_hash":Frame._sha(globe.source_record),"terrain_revision":Terrain.REVISION_NAME,"record_domain":Frame.RECORD_DOMAIN}
	var captured:=Contact.seal_capture(frame,width,cells,Vector2.ZERO,Vector2i(cells/2,cells/2),0,points,globe)
	var verified:=Contact.new()
	if captured.is_empty() or not verified.configure(JSON.parse_string(JSON.stringify(captured)),globe):return {}
	var x:=step*0.3125;var z:=step*0.35;var hit:=verified.height_at(globe,x,z)
	if hit.is_empty():return {}
	return {"height":float(hit.height),"x":x,"z":z,"width":width,"cells":cells,"verified_vertices":verified.validation_samples,"checksum":str(captured.checksum),"profile":str(captured.profile)}

func _anchor(globe:RefCounted,record:PackedByteArray,name:String,latitude:float,longitude:float)->void:
	globe.latitude=latitude;globe.longitude=longitude
	var exact:Dictionary=globe.exact_source_sample(latitude,longitude)
	var grid_height:=float(globe.raw_height(0,0))
	if exact.is_empty() or not is_finite(grid_height):_errors.append("Unavailable source sample "+str(record.decode_u16(12))+"/"+name);return
	var exact_height:=float(exact.elevation_m);var native_point:PackedInt64Array=exact.position_raw
	var phone_exact:=_phone_raw(globe,0,exact_height,0);var scalar_exact:=_scalar_raw(globe,0,exact_height,0)
	var metric:={"model_index":int(record.decode_u16(12)),"anchor":name,"latitude":latitude,"longitude":longitude,"source_uid_u32":int(record.decode_u32(4)),"exact_F879_elevation_m":exact_height,"bilinear_256m_elevation_m":grid_height,"grid_minus_F879_m":grid_height-exact_height,"F879_point_s64_hex":_vector_hex(native_point),"scalar_point_minus_F879_m":_distance(scalar_exact,native_point),"phone_point_minus_scalar_m":_distance(phone_exact,scalar_exact),"F879_source_pass_count":exact.passes.size(),"model117_corrected_exterior_caller":int(record.decode_u16(12))==117,"triangles":[]}
	var triangles:Array=[]
	for spec in [[4000.0,64]]+([[8000.0,32],[8000.0,64]] if int(record.decode_u16(12))==117 else []):
		var triangle:=_saved_triangle(globe,float(spec[0]),int(spec[1]))
		if triangle.is_empty():_errors.append("Failed saved triangle "+str(spec));continue
		triangle["field_height_at_nonvertex_m"]=float(globe.raw_height(float(triangle.x),float(triangle.z)))
		triangle["triangle_minus_field_m"]=float(triangle.height)-float(triangle.field_height_at_nonvertex_m)
		triangles.append(triangle);metric.triangles.append(triangle.duplicate(true))
	_metrics.append(metric)
	for player_model:int in PLAYERS:
		var data:=Natural.ship_model(player_model);var native_inner:=int(data.f1533_radii.inner_s64)*Bridge.Units.METRES_PER_RAW
		var phone_clearance:=float(_catalog.get_ship(PLAYERS[player_model]).visual_span_m)*0.14+2.0
		for offset in [["surface_zero",0.0],["phone_authored_clearance",phone_clearance],["native_inner_clearance",native_inner]]:
			var offset_name:=str(offset[0]);var offset_m:=float(offset[1]);var native_offset:=PackedInt64Array()
			for component:int in native_point:native_offset.append(component+roundi(float(component)/_radius(native_point)*offset_m/Bridge.Units.METRES_PER_RAW))
			_classify(globe,record,player_model,native_offset,"exact_F879_raw_point",name,offset_name,offset_m,phone_clearance,native_inner)
			_classify(globe,record,player_model,_phone_raw(globe,0,grid_height+offset_m,0),"bilinear_visual_origin_phone_basis",name,offset_name,offset_m,phone_clearance,native_inner)
			_classify(globe,record,player_model,_scalar_raw(globe,0,grid_height+offset_m,0),"bilinear_visual_origin_scalar64_axes",name,offset_name,offset_m,phone_clearance,native_inner)
			for triangle:Dictionary in triangles:
				var suffix:="_%d_%d"%[int(triangle.width),int(triangle.cells)]
				_classify(globe,record,player_model,_phone_raw(globe,float(triangle.x),float(triangle.field_height_at_nonvertex_m)+offset_m,float(triangle.z)),"bilinear_nonvertex"+suffix,name,offset_name,offset_m,phone_clearance,native_inner)
				_classify(globe,record,player_model,_phone_raw(globe,float(triangle.x),float(triangle.height)+offset_m,float(triangle.z)),"verified_saved_triangle_nonvertex"+suffix,name,offset_name,offset_m,phone_clearance,native_inner)

func characterize()->Dictionary:
	_errors.clear();_classifications.clear();_metrics.clear();_branches.clear();_source_pins.clear()
	for path:String in INPUTS:_source_pins[path]=FileAccess.get_sha256("res://"+path)
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));var records:Dictionary={}
	for row:Dictionary in fixture.cases:
		if not records.has(int(row.parent_model)):records[int(row.parent_model)]=str(row.parent_record_hex).hex_decode()
	var started:=Time.get_ticks_usec()
	for model in range(117,134):
		if not records.has(model):_errors.append("Missing model record "+str(model));continue
		var record:PackedByteArray=records[model];var system:=NativeSystem.new()
		system.by_id.body={"runtime_record_hex":record.hex_encode(),"radius_km":1.0}
		var globe:=Terrain.new();globe.configure(system,"body","")
		if not globe.configured_ok:_errors.append("Unconfigured terrain "+str(model));continue
		_anchor(globe,record,"fixture_default",globe.latitude,globe.longitude)
		_anchor(globe,record,"north_east",0.31,0.42)
		_anchor(globe,record,"south_west",-0.6,-1.1)
	for path:String in INPUTS:
		if FileAccess.get_sha256("res://"+path)!=_source_pins[path]:_errors.append("Characterization changed input "+path)
	var excluded:Array=[]
	for model in range(134,149):excluded.append({"model_index":model,"natural_classifier_data_available":not Natural.parent_model(model).is_empty(),"landing_surface_supported":Terrain.supported_model(_record_for_model(model)),"landing_or_render_alignment_claim":false})
	return {"schema":"source-contact-height-characterization-v1","completed_utc":Time.get_datetime_string_from_system(true),"duration_ms":(Time.get_ticks_usec()-started)/1000.0,"terrain_revision":Terrain.REVISION_NAME,"terrain_height_policy":Terrain.SAMPLE_POLICY,"source_sha256":_source_pins.duplicate(),"model_count":17,"anchor_count":3,"player_count":3,"offset_policy_count":3,"metrics":_metrics.duplicate(true),"classifications":_classifications.duplicate(true),"classification_count":_classifications.size(),"branches":_branches.duplicate(),"gas_and_stellar_exclusions":excluded,"errors":_errors.duplicate(),"ok":_errors.is_empty(),"scope":"Isolated characterization of exact F879 continuous-direction construction, current256m bilinear visual field, phone/Basis mapping and validated three-vertex saved production-profile triangles versus unchanged source F576. Three anchors/all17 landable models/all3players/three centre-offset policies. Saved triangles use actual independent source-vertex validation, not full GPU/packet generation. Model117 render caller corrections do not replace classifier original parent bounds. Gas/stars are classifier-only exclusions. No original native oracle rerun, live gameplay, F575 response, HP/fuel/time or device benchmark."}

static func _record_for_model(model:int)->PackedByteArray:
	var record:=PackedByteArray();record.resize(68);record.encode_u16(12,model);return record
