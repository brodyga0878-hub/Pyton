extends SceneTree
# Pure candidate tests. Explicit provider fixtures below certify one visible
# point only; they do not establish that stock v5 triangles support live use.
const Bridge=preload("res://scripts/source_natural_surface_bridge.gd")
const Natural=preload("res://scripts/source_natural_contact.gd")
const Terrain=preload("res://scripts/source_contact_surface_terrain.gd")
const Legacy=preload("res://scripts/source_surface_terrain.gd")
const Packet=preload("res://scripts/source_surface_render_packet.gd")
const Frame=preload("res://scripts/source_surface_render_state.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Phone=preload("res://scripts/source_surface_contact_bridge.gd")
const REPORT:="res://validation/alignment-2026-11-13/source-natural-surface-bridge.json"
class TestWorld extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=44341016
class TestSurface extends RefCounted:
	var active:=true
	var globe:RefCounted
	var source_render_state:RefCounted
	var city_data:Dictionary={}
	var underground:RefCounted
	var body_id:="body"
	var landed:=false
	var landing:=true
	var taking_off:=false
	func clearance(ship:RefCounted)->float:return float(ship.profile().visual_span_m)*0.14+2.0
var checks:=0
var failures:=0
var evidence:Array=[]
var system:=TestWorld.new()
var surface:=TestSurface.new()
var ship:=Flight.new()
var base_packet:Dictionary={}
var accepted_guard:Dictionary={}
var accepted_height:=0.0

func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func history()->Dictionary:
	return Natural._globals({"altitude_low_u32":0x12345678,"altitude_high_s32":-1234567,"previous_altitude_low_u32":0x89abcdef,"previous_altitude_high_s32":-2345678,"collision_active_u8":77,"collision_enabled_u8":0,"collision_flags_u8":165,"primitive_flags_u8":109,"recorded_intersection_raw":-91,"pending_query_flag":17})
func context(guard:Dictionary=accepted_guard)->Dictionary:return {"history_globals":history(),"geometry_guard":guard.duplicate(true)}
func protected_state()->PackedByteArray:
	var provider:RefCounted=surface.source_render_state
	var raw_provider:Dictionary={}
	if provider!=null:
		for item:Dictionary in provider.get_property_list():
			if int(item.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:raw_provider[str(item.name)]=provider.get(item.name)
	return var_to_bytes([ship.snapshot(),surface.active,surface.city_data,surface.landed,surface.landing,surface.taking_off,surface.globe.capture_worker_state(),surface.globe.cache_stats(),raw_provider])
func flat_provider(height:float)->bool:
	var packet:=base_packet.duplicate(true);var mesh:Dictionary=packet.meshes[0];var vertices:PackedVector3Array=mesh.vertices.duplicate()
	for index in range(vertices.size()):vertices[index]=Vector3(vertices[index].x,height,vertices[index].z)
	mesh.vertices=vertices;mesh.bounds=AABB(Vector3(-32,float(vertices[0].y),-32),Vector3(64,0,64));packet.meshes[0]=mesh
	var state:=Frame.new()
	if not state.configure(packet):return false
	surface.source_render_state=state;return true
func configure()->bool:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"));var record:=PackedByteArray()
	for row:Dictionary in fixture.cases:
		if int(row.parent_model)==118:record=str(row.parent_record_hex).hex_decode();break
	system.by_id={"body":{"runtime_record_hex":record.hex_encode(),"radius_km":1.0}}
	var globe:=Terrain.new();globe.configure(system,"body","");globe.latitude=0;globe.longitude=0;surface.globe=globe
	check(globe.configured_ok,"Actual v5 contact geometry configures from the original native body118 record")
	if not globe.configured_ok:return false
	base_packet=Packet.prepare(globe,{"core_width":64.0,"core_cells":2,"include_rings":false,"source_key":"explicit-v5-local-point-provider-fixture"})
	check(base_packet.get("ok",false),"Actual v5 sampling prepares an isolated bounded published core")
	if not base_packet.get("ok",false):return false
	var original:=Frame.new();check(original.configure(base_packet),"Original v5 packet configures the real published provider class");surface.source_render_state=original
	ship.position=Vector3(0,float(globe.raw_height(0,0))+20,0);ship.velocity=Vector3(0.0123,-0.0456,0.0789);ship.attitude=Quaternion.IDENTITY
	var before:=protected_state();var stock:=Bridge.certify_geometry_point(surface,ship)
	check(protected_state()==before,"Stock v5 point certification does not alter geometry caches, provider counters or ship state")
	check(stock.contract==Bridge.GUARD_CONTRACT and stock.scope=="local-visible-point-only-not-whole-triangle","A sampled-node policy never becomes an implicit triangle certificate")
	evidence.append({"case":"actual_stock_v5_visible_point","guard":stock,"whole_triangle_certification":false})
	var exact:=globe.exact_root_query(0,0)
	check(exact.get("ok",false) and exact.get("certified")==true,"Actual v5 signed field supplies the search origin for an explicit visible-point fixture")
	if not exact.get("ok",false):return false
	var seen:Dictionary={}
	for index in range(257):
		var step:=0 if index==0 else ((index+1)/2)*(1 if index%2 else -1)
		var candidate:=float(Vector3(0,float(exact.elevation_m)+float(step)*0.002,0).y)
		if seen.has(candidate):continue
		seen[candidate]=true
		if not flat_provider(candidate):continue
		var guard:=Bridge.certify_geometry_point(surface,ship)
		if guard.get("certified")==true:accepted_guard=guard;accepted_height=candidate;break
	check(not accepted_guard.is_empty(),"An explicit published vertex is independently certified at an exact native zero or identical adjacent boundary")
	if accepted_guard.is_empty():return false
	check(Bridge.eligibility(surface,ship,accepted_guard).eligible and Bridge._plain(accepted_guard),"Only a current exact local-point certificate yields typed-JSON point eligibility")
	evidence.append({"case":"explicit_exact_local_point_fixture","guard":accepted_guard,"stock_v5_triangle_claim":false,"search_unique_float32_heights":seen.size()})
	return true
func rejected(ctx:Dictionary,label:String,event:Dictionary={},gear:int=65535)->void:
	var before:=protected_state();var arguments:=var_to_bytes([ctx,event]);var result:=Bridge.resolve(surface,ship,gear,ctx,event)
	check(not result.ok and not result.response_applied and result.damage_calls.is_empty() and result.callbacks.is_empty() and result.kernel.is_empty(),label+" rejects without source response or HP requests")
	check(result.position==ship.position and result.velocity==ship.velocity and result.attitude==ship.attitude and result.globals_after==ctx.get("history_globals",{}),label+" retains original pose and raw history atomically")
	check(before==protected_state() and arguments==var_to_bytes([ctx,event]),label+" preserves live objects, provider caches and caller buffers")
func caller_and_domain_guards()->void:
	var original:=history();var before:=var_to_bytes(original);var reset:=Bridge.caller_globals(original)
	check(before==var_to_bytes(original) and reset.collision_enabled_u8==255 and reset.altitude_low_u32==0xffffffff and reset.collider_parent_selected,"Explicit live caller adapts F569 enabled FF and F570 primary-parent prefix without changing history")
	for key:String in ["altitude_high_s32","previous_altitude_low_u32","previous_altitude_high_s32","collision_active_u8","recorded_intersection_raw","pending_query_flag"]:check(reset[key]==original[key],"Bounded F570 prefix preserves explicit caller word "+key)
	for key:String in ["collision_flags_u8","volume_flags_u8","collider_index_u8","primitive_flags_u8","collision_kind_u8"]:check(reset[key]==0,"Bounded F570 prefix clears its actual field "+key)
	for key:String in Natural.GLOBAL_KEYS:
		var invalid:=context();invalid.history_globals.erase(key);rejected(invalid,"Missing explicit history "+key)
	var invalid:=context();invalid.history_globals.previous_altitude_high_s32=0.5;rejected(invalid,"Fractional raw high word")
	invalid=context();invalid.history_globals["invented"]=0;rejected(invalid,"Unknown source history field")
	invalid=context();invalid["phone_AGL"]=0.0;rejected(invalid,"Phone AGL cannot become an implicit raw altitude")
	rejected(context(),"Unsupported gear word",{},65536)
	rejected(context(),"City event is not natural terrain",{"kind":"city_floor"})
	rejected(context(),"Provider plane cannot replace original terrain",{"provider_hit":{"height":0.0}})
	surface.city_data={"explicit_city_fixture":true};rejected(context(),"City geometry uses its separate unchanged bridge");surface.city_data={}
	var revision:String=surface.globe.revision;surface.globe.revision=Legacy.REVISION_NAME;rejected(context(),"Old v4 geometry is not silently upgraded");surface.globe.revision=revision
	surface.globe.city_profiles={"fixture":{"flat_outer_m":1000.0,"root_latitude":0.0,"root_longitude":0.0}};rejected(context(),"Source city grading excludes this local geometry");surface.globe.city_profiles={}
	evidence.append({"case":"explicit_caller_and_domain","complete_history_required":true,"full_F570_executed":false,"enabled_byte":255,"old_runtime_changed":false})
func genuine_nohit_and_response()->void:
	for ship_id:String in ["eagle","cobra","shuttle"]:
		ship.ship_id=ship_id;ship.position=Vector3(0,accepted_height+surface.clearance(ship)+50,0);ship.velocity=Vector3(0.0123,-0.0456,0.0789);ship.attitude=Quaternion.IDENTITY
		var ctx:=context({});var before:=protected_state();var input:=var_to_bytes(ctx);var nohit:=Bridge.resolve(surface,ship,65535,ctx)
		check(nohit.ok and not nohit.response_applied and not nohit.contact_detected and not nohit.landing_accepted and nohit.kernel.f576_return_s32==-1,"Actual positive-radius "+ship_id+" F576 nohit succeeds even without permission to apply a response")
		check(nohit.position==ship.position and nohit.velocity==ship.velocity and nohit.attitude==ship.attitude and nohit.damage_calls.is_empty() and nohit.callbacks.is_empty(),"Real nohit preserves pose and produces no F953 requests: "+ship_id)
		check(protected_state()==before and input==var_to_bytes(ctx),"Actual nohit has no live/source-provider/history mutations: "+ship_id)
		var data:=Phone.source_ship_data(ship_id);var inner_m:=int(data.inner_radius_raw)*Phone.Units.METRES_PER_RAW
		# Explicit observer fixture, not a flown descent. Native centre is
		# half a metre below the certified point; source F576 decides contact.
		ship.position=Vector3(0,accepted_height+surface.clearance(ship)-inner_m-0.5,0)
		var guard:=Bridge.certify_geometry_point(surface,ship);ctx=context(guard);before=protected_state();input=var_to_bytes(ctx)
		var hit:=Bridge.resolve(surface,ship,65535,ctx)
		check(hit.ok and hit.eligible and hit.response_applied and hit.contact_detected and hit.landing_accepted and hit.damage_calls.is_empty(),"Actual native terrain query and valid point guard admit an aligned soft candidate: "+ship_id)
		if not hit.ok:continue
		check(hit.kernel.classification.iterations[-1].branch=="terrain_query" and hit.facts.native_previous_is_phone_AGL==false and hit.facts.parent_uid_u32==int(surface.globe.source_record.decode_u32(4)),"Response uses original terrain-query previous altitude and UID: "+ship_id)
		check(hit.facts.matching_bodyfixed_frame_56_57 and int(hit.facts.body_flags_14c_u8)>=128 and int(hit.facts.parent_flags_14c_u8)>=128,"Actual F1533 flags and matching body frame reach the classifier: "+ship_id)
		check(protected_state()==before and input==var_to_bytes(ctx) and surface.landing and not surface.landed,"Pure candidate cannot apply landing, pose or caller history: "+ship_id)
		var unsafe:=Bridge.resolve(surface,ship,0,ctx)
		check(unsafe.ok and unsafe.response_applied and not unsafe.landing_accepted and unsafe.damage_calls.size()==1 and int(unsafe.damage_calls[0].amount_s32)==int(data.mass_s16) and int(unsafe.kernel.globals_after.collision_active_u8)==255,"Gear-up candidate emits the original mass-based minimum F575 request through enabled FF without applying HP: "+ship_id)
		var transported:Dictionary=JSON.parse_string(JSON.stringify(ctx));check(Bridge.resolve(surface,ship,65535,transported)==hit,"Complete source history and local-point guard survive typed JSON transport: "+ship_id)
		var again:=Bridge.resolve(surface,ship,65535,ctx);hit.kernel.body_after[0]=0;hit.kernel.globals_after.previous_altitude_high_s32=0;hit.globals_after.previous_altitude_high_s32=0;hit.geometry_guard.reason="caller mutation"
		check(protected_state()==before and Bridge.resolve(surface,ship,65535,ctx)==again,"Returned raw bodies, state and certificates are private: "+ship_id)
		evidence.append({"case":"actual_candidate_"+ship_id,"nohit_flags_u8":nohit.kernel.return_flags_u8,"hit_previous_hex":again.facts.previous_altitude_s64_hex,"source_origin_offset_m":again.facts.source_body_origin_up_offset_m,"unsafe_F953_calls":unsafe.damage_calls,"HP_applied":false,"flow_executed_in_Main":false})
func geometry_gate_and_inner_guard()->void:
	ship.ship_id="eagle";ship.attitude=Quaternion.IDENTITY;ship.velocity=Vector3.ZERO
	var data:=Phone.source_ship_data(ship.ship_id);var inner_m:=int(data.inner_radius_raw)*Phone.Units.METRES_PER_RAW;ship.position=Vector3(0,accepted_height+surface.clearance(ship)-inner_m-0.5,0)
	rejected(context({}),"An actual hit has no implicit geometry certificate")
	var forged:=accepted_guard.duplicate(true);forged.visible_height_m=float(forged.visible_height_m)+1;rejected(context(forged),"Certificate must match the current measured visible point")
	var saved:=accepted_guard.duplicate(true);check(flat_provider(accepted_height+3.0),"A deliberate mismatched visible provider fixture configures")
	var mismatch:=Bridge.certify_geometry_point(surface,ship);check(not mismatch.certified and mismatch.reason=="visible_point_not_exact_source_boundary","Measured nonzero source residual cannot be accepted by a truthy certificate flag")
	var counterfeit:=mismatch.duplicate(true);counterfeit.certified=true;counterfeit.reason="exact_visible_source_zero";rejected(context(counterfeit),"Forged certified flag cannot override a fresh native measurement")
	var blocked:=Bridge.resolve(surface,ship,65535,context(counterfeit))
	check(blocked.facts.get("native_contact_observed")==true and blocked.geometry_guard==mismatch and not blocked.response_applied,"Blocked native hit retains fresh measured diagnostic evidence without becoming nohit or a response")
	rejected(context(saved),"Changed mesh invalidates an old local-point certificate")
	check(flat_provider(accepted_height),"The actual certified provider fixture can be restored")
	# An actual rolled Cobra child reaches the source field while its primary
	# centre is still above it. The primary point certificate cannot certify
	# that different probe's visible x/z or source facet.
	ship.ship_id="cobra";ship.attitude=Quaternion.from_euler(Vector3(0,0,0.25));data=Phone.source_ship_data(ship.ship_id);inner_m=int(data.inner_radius_raw)*Phone.Units.METRES_PER_RAW
	ship.position=Vector3(0,accepted_height+surface.clearance(ship)-inner_m+3.0,0)
	var child_guard:=Bridge.certify_geometry_point(surface,ship);var child_context:=context(child_guard);var child_before:=protected_state();var child:=Bridge.resolve(surface,ship,65535,child_context)
	check(not child.ok and child.error=="unsupported_child_geometry_certificate" and child.facts.get("native_contact_observed")==true and int(child.facts.get("selected_child_index",0))>0,"A real child-first Cobra F576 hit cannot borrow the primary visible-point certificate")
	check(child.position==ship.position and child.globals_after==child_context.history_globals and child.damage_calls.is_empty() and child.kernel.is_empty() and protected_state()==child_before,"Unsupported child contact is atomic and produces no continuation or damage request")
	evidence.append({"case":"actual_child_first_exclusion","observer_roll_radians":0.25,"source_centre_height_fixture_m":3.0,"facts":child.facts,"response_applied":false})
	ship.ship_id="eagle";ship.attitude=Quaternion.IDENTITY
	var parent_radii:=Phone.descriptor_radii(Phone.model_descriptor(118));ship.position=Vector3(0,float(parent_radii.inner_raw)*Phone.Units.METRES_PER_RAW/2.0-float(surface.globe.radius),0)
	rejected(context(Bridge.certify_geometry_point(surface,ship)),"Deep inner fast branch cannot consume unrelated caller previous history")
	evidence.append({"case":"physical_visible_guard","truthy_flag_is_not_certificate":true,"native_hit_forced":false,"inner_fast_history_assumed":false,"whole_triangle_certified":false})
func run()->void:
	if configure():caller_and_domain_guards();genuine_nohit_and_response();geometry_gate_and_inner_guard()
	var sources:Dictionary={}
	for path:String in ["scripts/source_natural_surface_bridge.gd","tests/test_source_natural_surface_bridge.gd","scripts/source_natural_contact.gd","scripts/source_natural_contact_pipeline.gd","scripts/source_contact_surface_terrain.gd","scripts/source_terrain_contact_field.gd","scripts/source_surface_contact_bridge.gd","scripts/source_surface_render_state.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"evidence":evidence,"sources":sources,"scope":"Pure v5/source candidate bridge with exact local visible-point gate, source caller prefix and real F576-to-bounded-F575 composition. Explicit observer/flat-provider fixtures do not certify stock v5 triangles, Main live landing, Android, a complete object bank or full F570."},"\t"));file.close()
	print("Natural surface bridge: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
