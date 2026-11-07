extends SceneTree
# Primitive provider/frame controls. Synthetic fields below are explicitly
# labelled; one restored patch independently validates original source probes.
const Bridge=preload("res://scripts/source_surface_contact_bridge.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Sphere=preload("res://scripts/spherical_terrain.gd")
const Motion=preload("res://scripts/source_motion_bridge.gd")
const Packet=preload("res://scripts/source_surface_render_packet.gd")
const State=preload("res://scripts/source_surface_render_state.gd")
const Patch=preload("res://scripts/source_surface_contact_patch.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
class Globe extends RefCounted:
	var revision:="sphere-source-ground-v4"
	var configured_ok:=true
	var radius:=7049700.0
	var latitude:=0.31
	var longitude:=0.47
	var source_record:=PackedByteArray()
	var calls:=0
	func _init()->void:source_record.resize(68);source_record[0]=1;source_record[12]=120
	func basis_at(lat:float,lon:float)->Basis:return Sphere.new().basis_at(lat,lon)
	func raw_height(x:float,z:float)->float:calls+=1;return 13.0+0.02*x-0.03*z+0.0001*x*z
	func sample(x:float,z:float)->PackedFloat64Array:
		var h:=raw_height(x,z);return PackedFloat64Array([h,h,x,radius+h,-z])
	func cache_stats()->Dictionary:return {"source_samples":0,"entries":0}
	func maximum_patch_extent()->float:return radius*0.45
class NativeSystem extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=44341016
class BadProvider extends RefCounted:
	func height_at(_globe:RefCounted,_x:float,_z:float)->Dictionary:return {"height":777.0,"normal":Vector3(NAN,0,0)}
var checks:=0
var failures:=0
var evidence:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func setup()->Dictionary:
	var surface:=Surface.new();surface.active=true;surface.globe=Globe.new();var ship:=Flight.new();ship.velocity=Vector3(0.123,-2.456,8.789);ship.attitude=Quaternion.from_euler(Vector3(0.1,0.25,-0.15))
	return {"surface":surface,"ship":ship}
func fallback_diagonal()->void:
	var fixture:=setup();var surface:RefCounted=fixture.surface;var ship:RefCounted=fixture.ship
	var cell:float=Surface.GRID_WIDTH/surface.grid_cells()
	for point:Vector2 in [Vector2(8,12),Vector2(50,44),Vector2(cell/2,cell/2),Vector2(-8,-12),Vector2(-cell,0),Vector2(2000,2000),Vector2(-2011.5,2018.25)]:
		ship.position=Vector3(point.x,123.0,point.y);var before:=var_to_bytes(ship.snapshot());var hit:=Bridge.sample(surface,ship)
		check(hit.ok and hit.provider=="surface-height-grid-exact-triangle-v1" and absf(hit.height-surface.height_at(point.x,point.y))<0.00000001,"Fallback uses exactly the existing Surface cell/diagonal/interpolation, including negative/grid/diagonal boundaries")
		var v:PackedFloat64Array=hit.provider_metadata.vertices_local_f64
		var first:=Vector3(v[0],v[1],v[2]);var second:=Vector3(v[3],v[4],v[5]);var third:=Vector3(v[6],v[7],v[8]);var normal:Vector3=(third-first).cross(second-first).normalized()
		check(normal.dot(hit.normal)>0.999999 and hit.normal.y>0,"Fallback normal is the very same selected triangle plane, never independent neighbouring height probes")
		check(hit.agl_m==float(ship.position.y)-hit.height-surface.clearance(ship) and not hit.mesh_normal_is_native_contact_normal,"Authored clearance is an explicit provider measurement and face normal is not mislabelled native F575 radial normal")
		check(var_to_bytes(ship.snapshot())==before,"Sampling leaves all actual Flight fields unchanged")
	ship.position=Vector3(8,123,12);var calls:int=surface.globe.calls;var first:=Bridge.sample(surface,ship)
	check(surface.globe.calls-calls==3 and first.provider_metadata.triangle==0,"First triangle needs exactly its existing three vertex probes")
	ship.position=Vector3(50,123,44);calls=surface.globe.calls;var second:=Bridge.sample(surface,ship)
	check(surface.globe.calls-calls==4 and second.provider_metadata.triangle==1,"Second triangle follows Surface's existing fourth-vertex path")
func published_priority()->void:
	var fixture:=setup();var surface:RefCounted=fixture.surface;var ship:RefCounted=fixture.ship
	var packet:Dictionary=Packet.prepare(surface.globe,{"core_width":4000.0,"core_cells":8,"include_rings":false,"source_key":"explicit-synthetic-published-provider"});var state:=State.new()
	check(state.configure(packet),"Actual published-render-state class validates the explicit synthetic packet")
	surface.source_render_state=state;ship.position=Vector3(113.25,123,82.5);var calls:int=surface.globe.calls
	var hit:=Bridge.sample(surface,ship);var expected:Dictionary=state.height_at(surface.globe,ship.position.x,ship.position.z)
	check(hit.ok and hit.provider=="published-source-render-triangle" and hit.height==expected.height and hit.normal==expected.normal and hit.provider_metadata.triangle_index==expected.triangle_index,"Published geometry has priority with its exact height, face normal and triangle identity")
	check(surface.globe.calls==calls,"Published contact sampling performs no new underlying source-field queries")
	check(absf(hit.height-surface.height_at(ship.position.x,ship.position.z))<0.0000001,"Bridge and live Surface share the same authoritative published result")
	ship.position=Vector3(2500,123,2200);hit=Bridge.sample(surface,ship)
	check(hit.ok and hit.provider=="surface-height-grid-exact-triangle-v1" and hit.height==surface.height_at(ship.position.x,ship.position.z),"Outside the published physical patch, exact live Surface fallback remains authoritative")
	surface.source_render_state=BadProvider.new();calls=surface.globe.calls;hit=Bridge.sample(surface,ship)
	check(not hit.ok and hit.reason=="invalid_published_height_plane" and surface.globe.calls==calls,"Invalid published normal cannot silently select a different fallback height")
func frames_and_residuals()->void:
	var sphere:=Sphere.new();var local:=Vector3(0.123,-2.456,8.789)
	for ll:Array in [[0.0,0.0],[0.31,0.47],[-PI/2,PI],[PI/2,-PI],[-0.7,2.4]]:
		var basis:Basis=sphere.basis_at(ll[0],ll[1]);var body:=Bridge.to_bodyfixed_vector(basis,local);var back:=Bridge.to_local_vector(basis,body)
		check(back.size()==3 and absf(back[0]-local.x)<1e-10 and absf(back[1]-local.y)<1e-10 and absf(back[2]-local.z)<1e-10,"Single actual tangent basis maps every vector consistently, including poles/seams")
		var original:=Vector3(0.0377,-0.1251,0.00003);var same:=Bridge.apply_bodyfixed_delta(basis,original,[0.0,0.0,0.0])
		check(same.ok and same.value==original,"Zero raw-body delta preserves original SI pose and sub-raw-unit residues exactly")
		var delta_local:=Vector3(0.001,0.002,-0.003);var shifted:=Bridge.apply_bodyfixed_delta(basis,original,Bridge.to_bodyfixed_vector(basis,delta_local))
		check(shifted.ok and shifted.value.distance_to(original+delta_local)<0.0000001,"Contact deltas map back by addition rather than reconstructing rounded absolute bodyfixed positions")
		var matrix:=Bridge.native_orientation_q31(basis,Quaternion.IDENTITY);var axes:=Basis(Vector3(matrix[0],matrix[1],matrix[2])/2147483647.0,Vector3(matrix[3],matrix[4],matrix[5])/2147483647.0,Vector3(matrix[6],matrix[7],matrix[8])/2147483647.0)
		check(axes.determinant()>0.99999 and axes.x.distance_to(-basis.x)<1e-6 and axes.y.distance_to(basis.y)<1e-6 and axes.z.distance_to(-basis.z)<1e-6,"Native matrix uses proper local yaw(pi), retaining a proper bodyfixed orientation instead of global reflection")
	var point:=Bridge.to_bodyfixed_point(Basis.IDENTITY,1e12,Vector3(0,0.125,0))
	check(point[1]==1000000000000.125 and point[1]!=float(Vector3(0,point[1],0).y),"Scalar-double composition retains centimetres that a large absolute Float32 Vector3 would erase")
	var attitude:=Quaternion.from_euler(Vector3(0.3,-0.4,0.5))
	check(Bridge.native_orientation_q31(Basis.IDENTITY,attitude)==Motion._orientation(attitude),"Identity-frame native matrix is bit-for-bit the retained SourceMotionBridge convention")
	check(Bridge.to_bodyfixed_vector(Basis(Vector3.LEFT,Vector3.UP,Vector3.BACK),local).is_empty() and not Bridge.apply_bodyfixed_delta(Basis.IDENTITY,local,[NAN,0,0]).ok,"Reflections and nonfinite deltas reject before touching a pose")
func original_ship_data()->void:
	for pair:Array in [["cobra",38,100],["eagle",24,28],["shuttle",15,8]]:
		var data:=Bridge.source_ship_data(pair[0])
		check(data.ok and data.model_index==pair[1] and data.mass_s16==pair[2] and data.descriptor.size()==68 and data.spec.size()==24,"Original descriptor and immutable hyperdrive physical spec supply the actual ship model/mass")
		var original:PackedByteArray=data.descriptor.duplicate();data.descriptor[0]=0;data.spec[0]=0
		check(Bridge.source_ship_data(pair[0]).descriptor==original,"Caller mutations cannot alter shared original source tables")
	var cobra:=Bridge.source_ship_data("cobra")
	check(cobra.outer_radius_raw==36000 and cobra.inner_radius_raw==9600 and cobra.radii_shift==1,"Cobra common F1533 radii match the independently supplied native initializer values")
	check(not Bridge.source_ship_data("invented").ok and Bridge.model_descriptor(-1).is_empty() and not Bridge.descriptor_radii(PackedByteArray()).ok,"Unsupported/malformed source metadata rejects explicitly")
func restored_original_patch()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"));var record:=PackedByteArray()
	for row:Dictionary in fixture.cases:
		if int(row.parent_model)==120:record=str(row.parent_record_hex).hex_decode();break
	var system:=NativeSystem.new();system.by_id.body={"runtime_record_hex":record.hex_encode(),"radius_km":1.0}
	var globe:=Terrain.new();globe.configure(system,"body","");var surface:=Surface.new();surface.active=true;surface.globe=globe;var ship:=Flight.new()
	check(globe.configured_ok,"Actual source terrain configures from an original native fixture record")
	var cell:=4000.0/64;var points:Array=[Vector3(0,globe.raw_height(0,0),0),Vector3(cell,globe.raw_height(cell,0),0),Vector3(0,globe.raw_height(0,cell),cell)]
	var frame:={"latitude":globe.latitude,"longitude":globe.longitude,"radius":globe.radius,"record_hash":State._sha(globe.source_record),"terrain_revision":Terrain.REVISION_NAME,"record_domain":State.RECORD_DOMAIN}
	var sealed:=Patch.seal_capture(frame,4000.0,64,Vector2.ZERO,Vector2i(32,32),0,points,globe);var verified:=Patch.new()
	check(verified.configure(sealed,globe) and verified.validation_samples==3,"Saved contact patch independently verifies its actual three original source vertices")
	surface.source_render_state=verified;ship.position=Vector3(8,123,12);var before:=var_to_bytes(ship.snapshot());var hit:=Bridge.sample(surface,ship);var expected:=verified.height_at(globe,8,12)
	check(hit.ok and hit.provider=="verified-saved-contact-triangle" and hit.height==expected.height and hit.normal==expected.normal,"Bridge honours a real reconstructed saved contact triangle rather than resampling a different raw height")
	check(var_to_bytes(ship.snapshot())==before,"Original saved-patch sampling is read-only for Flight")
	evidence.append({"case":"original_source120_verified_saved_triangle","provider":hit.provider,"height":hit.height,"agl_m":hit.agl_m,"verified_original_vertices":verified.validation_samples,"native_mesh_classifier_claim":false})
func live_raw_resolution()->void:
	var fixture:=setup();var surface:RefCounted=fixture.surface;var ship:RefCounted=fixture.ship
	ship.position=Vector3(8,surface.height_at(8,12)+surface.clearance(ship)-0.025,12);ship.velocity=Vector3(0.0123,-0.0456,0.0789);ship.attitude=Quaternion.IDENTITY
	var before:=var_to_bytes(ship.snapshot());var position:Vector3=ship.position;var velocity:Vector3=ship.velocity;var hit:=Bridge.sample(surface,ship)
	var actual:=Bridge.resolve(surface,ship,65535)
	check(actual.ok and actual.landing_accepted and actual.damage_calls.is_empty(),"Actual bounded F575 accepts slow upright contact only with physical gear fully deployed")
	if not actual.ok:return
	check(actual.position.y>position.y and absf(actual.position.y-hit.height-hit.phone_clearance_m)<0.002,"Native radial position delta repairs explicit penetration while retaining authored phone clearance")
	check(var_to_bytes(ship.snapshot())==before and not surface.landed and not surface.landing,"Resolution returns candidate pose/landing flag without modifying Flight, Surface landing state, HP or inventories")
	var normal:Vector3=Vector3(actual.kernel.normal_q31[0],actual.kernel.normal_q31[1],actual.kernel.normal_q31[2])/2147483647.0
	check(normal.distance_to(Vector3(hit.provider_normal_bodyfixed_f64[0],hit.provider_normal_bodyfixed_f64[1],hit.provider_normal_bodyfixed_f64[2]))>0.01,"Kind1 native normal remains radial despite a materially tilted actual provider triangle")
	check(actual.facts.source_inner_radius_raw==9600 and actual.facts.previous_altitude_s64==9600+roundi(hit.agl_m/Bridge.Units.METRES_PER_RAW),"Original inner radius plus sampled phone AGL is the named source-height classifier adapter")
	check(absf(actual.facts.source_body_origin_up_offset_m-(9600*Bridge.Units.METRES_PER_RAW-surface.clearance(ship)))<1e-12,"Single fixed native-inner/authored-clearance body-origin offset is explicit")
	var delta_body:=PackedFloat64Array()
	for component:int in actual.facts.velocity_delta_q16:delta_body.append(float(component)*Bridge.Physics.VELOCITY_UNIT_MPS/65536.0)
	var expected:=Bridge.apply_bodyfixed_delta(hit.basis,velocity,delta_body)
	check(actual.velocity==expected.value and actual.velocity.is_finite(),"Native velocity delta is added to original SI velocity, retaining its quantization residues")
	check(actual.attitude.is_finite() and absf(actual.attitude.length()-1)<0.000001 and JSON.parse_string(JSON.stringify(actual.facts)) is Dictionary,"Native rotation delta yields a valid candidate orientation and standalone JSON-safe provenance")
	var gear_up:=Bridge.resolve(surface,ship,0)
	check(gear_up.ok and not gear_up.landing_accepted and gear_up.damage_calls.size()==1 and gear_up.damage_calls[0].amount_s32>=100,"Gear-up contact returns the actual source F953 damage request, not a replacement SI impact law")
	check(var_to_bytes(ship.snapshot())==before and ship.position==position,"Returning source damage never applies HP or pose before the atomic caller commit")
	ship.velocity=Vector3(0,-120,0);var fast:=Bridge.resolve(surface,ship,65535)
	check(fast.ok and not fast.landing_accepted and not fast.damage_calls.is_empty(),"Actual source speed threshold rejects a fast physical-gear-down touchdown")
	check(not Bridge.resolve(surface,ship,-1).ok and not Bridge.resolve(surface,ship,65536).ok,"Out-of-domain physical gear positions reject before native evaluation")
	ship.velocity=velocity;var candidate:=Vector3(20,surface.height_at(20,10)+surface.clearance(ship)-0.01,10)
	var event:={"kind":"terrain","candidate_position":candidate,"provider_hit":{"height":surface.height_at(20,10),"normal":Vector3(0.2,1,0).normalized(),"triangle":"explicit-CCD-provider"}};var event_before:=var_to_bytes(event)
	var ccd:=Bridge.resolve(surface,ship,65535,event)
	check(ccd.ok and ccd.position.x>19.99 and ccd.position.x<20.01 and ship.position==position and var_to_bytes(event)==event_before,"Explicit CCD candidate is resolved without temporarily replacing live pose or mutating caller hit metadata")
	var floor_height:=200.0;event={"kind":"city_floor","candidate_position":Vector3(20,floor_height+surface.clearance(ship)-0.01,10),"provider_hit":{"height":floor_height,"normal":Vector3.UP,"site":"explicit-floor-proxy"}}
	var city:=Bridge.resolve(surface,ship,65535,event)
	check(city.ok and city.facts.city_floor_is_explicit_radial_proxy and absf(city.position.y-floor_height-surface.clearance(ship))<0.002,"City floor uses the explicit plane height and declares its bounded kind1 radial proxy")
	check(not Bridge.resolve(surface,ship,65535,{"kind":"city_floor","candidate_position":candidate,"provider_hit":{"position":candidate,"normal":Vector3.UP}}).ok,"A CCD centre position cannot masquerade as the missing city floor plane height")
	ship.position.y+=10;check(not Bridge.resolve(surface,ship,65535).ok,"Without an explicit classified event, airborne height cannot invent a ground contact")
	evidence.append({"case":"actual_f575_live_boundary","physical_gear_u16":65535,"landing_accepted":actual.landing_accepted,"penetration_before_m":hit.agl_m,"source_inner_radius_raw":actual.facts.source_inner_radius_raw,"authored_source_origin_offset_m":actual.facts.source_body_origin_up_offset_m,"position_delta_raw":actual.facts.position_delta_raw,"gear_up_damage_requested":gear_up.damage_calls[0].amount_s32,"HP_applied_by_bridge":false,"mesh_normal_substituted_for_radial":false})
func q31_contact_matrix_boundary()->void:
	var fixture:=setup();var surface:RefCounted=fixture.surface;var ship:RefCounted=fixture.ship;var rng:=RandomNumberGenerator.new();rng.seed=0x575
	var cases:Array=[]
	for ll:Array in [[0.0,0.0],[0.31,0.47],[-PI/2,PI],[PI/2,-PI],[0.9,-2.4],[-0.6,1.7]]:
		for yaw:float in [-PI,-1.8,-1.0,-0.4,0.0,0.3,1.2,2.2,PI]:cases.append([ll[0],ll[1],rng.randf_range(-0.08,0.08),yaw,rng.randf_range(-0.08,0.08)])
	for index in range(16):cases.append([rng.randf_range(-PI/2,PI/2),rng.randf_range(-PI,PI),rng.randf_range(-0.08,0.08),rng.randf_range(-PI,PI),rng.randf_range(-0.08,0.08)])
	for row:Array in cases:
		surface.globe.latitude=row[0];surface.globe.longitude=row[1];ship.attitude=Quaternion.from_euler(Vector3(row[2],row[3],row[4]));ship.position=Vector3(8,surface.height_at(8,12)+surface.clearance(ship)-0.025,12);ship.velocity=Vector3(0.0123,-0.0456,0.0789)
		var before:=var_to_bytes(ship.snapshot());var result:=Bridge.resolve(surface,ship,65535)
		check(result.ok and result.landing_accepted and result.damage_calls.is_empty(),"Native F1520-normalized contact input accepts genuine slow near-up attitude across poles, seams and varied yaw without unit-dot wrap")
		check(result.ok and result.kernel.alignment_q31>=0 and result.attitude.is_finite() and var_to_bytes(ship.snapshot())==before,"Native alignment remains untouched and positive while candidate attitude/gameplay state remain valid/read-only")
	surface.globe.latitude=0.31;surface.globe.longitude=0.47;ship.attitude=Quaternion.from_euler(Vector3(0.8,0,0))
	var tilted:=Bridge.resolve(surface,ship,65535)
	check(tilted.ok and not tilted.landing_accepted and not tilted.damage_calls.is_empty(),"Source normalization does not pitch a materially tilted phone ship upright or bypass the native landing threshold")
	evidence.append({"case":"phone_q31_unit_boundary","near_up_cases":cases.size(),"input_normalization":"exact source F1520 after scalar-double unit axes and proper local yaw(pi)","kernel_alignment_clamped":false,"tilted_attitude_forced_up":false})
func tangent_native_rank_one()->void:
	var fixture:=setup();var surface:RefCounted=fixture.surface;var ship:RefCounted=fixture.ship
	surface.globe.latitude=PI/2;surface.globe.longitude=0;ship.position=Vector3(0,surface.height_at(0,0)+surface.clearance(ship)-0.025,0)
	ship.attitude=Quaternion.IDENTITY;ship.velocity=Vector3(-100.0*Bridge.Physics.VELOCITY_UNIT_MPS,0,0)
	var before:=var_to_bytes(ship.snapshot());var actual:=Bridge.resolve(surface,ship,0)
	check(actual.ok and not actual.landing_accepted and actual.damage_calls.size()==1 and actual.damage_calls[0].amount_s32==100,"Real tangential gear-up impact returns native damage and recovery candidates instead of freezing a valid contact")
	check(actual.ok and absf(actual.facts.native_orientation_determinant)<0.0001 and actual.facts.orientation_projection_policy=="native-rank-deficient-preserve-phone-quaternion-v1" and actual.attitude==ship.attitude,"Native rank-one basis retains exact source output while explicit phone projection preserves its prior valid Quaternion")
	check(actual.ok and actual.position.y>ship.position.y and actual.velocity!=ship.velocity and var_to_bytes(ship.snapshot())==before,"Singular native orientation cannot suppress valid source position/velocity deltas or mutate HP early")
	var fixture_data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_surface_contact_native.json"));var row:Dictionary={}
	for value:Dictionary in fixture_data.cases:
		if value.id=="dos-surface-contact-0013":row=value;break
	check(not row.is_empty(),"Independent native fixture contains the actual controlled rank-one F575 case0013")
	if row.is_empty():return
	var context:Dictionary=row.context.duplicate(true);context.relative_position_s64=[]
	for axis in range(3):context.relative_position_s64.append(str(row.context.relative_position_s64_hex).hex_decode().decode_s64(axis*8))
	context.globals.previous_altitude_s64=str(row.context.globals.previous_altitude_s64_hex).hex_decode().decode_s64(0)
	for key in ["body_descriptor","parent_descriptor","body_spec"]:context[key]=str(row.context[key+"_hex"]).hex_decode()
	var raw_before:=str(row.body_hex).hex_decode();var raw:=Bridge.Core.resolve_player(raw_before,str(row.parent_hex).hex_decode(),context)
	check(raw.ok and raw.body_after.hex_encode()==row.expected.body_hex and raw.damage_calls.size()==row.expected.damage_calls.size() and int(raw.damage_calls[0].amount_s32)==int(row.expected.damage_calls[0].amount_s32) and int(raw.damage_calls[0].attacker_u32)==int(row.expected.damage_calls[0].attacker_u32),"Raw kernel still exactly reproduces independent native0013 whole-body output and F953 request")
	var old_attitude:=Quaternion(Vector3.UP,PI);var old_velocity:=Vector3(600*Bridge.Physics.VELOCITY_UNIT_MPS,0,0)
	var mapped:=Bridge._pose_delta({"basis":Basis.IDENTITY,"input_position":Vector3(0.123,5.678,0.0003),"input_velocity":old_velocity,"input_attitude":old_attitude},raw_before,raw.body_after)
	check(mapped.ok and mapped.attitude==old_attitude and absf(mapped.native_orientation_determinant)<0.0001 and mapped.velocity!=old_velocity,"Independent original rank-one case projects to a stable phone Quaternion while retaining its other native deltas")
	evidence.append({"case":"native_rank_one_phone_projection","native_fixture":"dos-surface-contact-0013","native_raw_body_unchanged":raw.body_after.hex_encode()==row.expected.body_hex,"native_damage_amount":raw.damage_calls[0].amount_s32,"live_damage_amount":actual.damage_calls[0].amount_s32,"orientation_policy":actual.facts.orientation_projection_policy,"kernel_orientation_repaired":false,"phone_quaternion_retained":true})
func run()->void:
	fallback_diagonal();published_priority();frames_and_residuals();original_ship_data();restored_original_patch();live_raw_resolution();q31_contact_matrix_boundary();tangent_native_rank_one()
	print("SOURCE CONTACT BRIDGE EVIDENCE: ",JSON.stringify(evidence))
	print("SOURCE CONTACT BRIDGE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
