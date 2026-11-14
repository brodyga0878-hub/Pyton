extends SceneTree
# Native expectations observe original leaf p/depth/SAR/intersection words.
# Phone charts are explicit render fixtures, not a live terrain provider.
const Geometry=preload("res://scripts/source_native_contact_geometry.gd")
const SourceFrame=preload("res://scripts/source_terrain_query_frame.gd")
const Trace=preload("res://scripts/source_terrain_query_trace.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Natural=preload("res://scripts/source_natural_contact.gd")
const Diagnostics=preload("res://scripts/game_diagnostics.gd")
const FIXTURE:="res://tests/fixtures/source_footprint_native.json"
const REPORT:="res://validation/contact-frame-2026-11-14/source-native-contact-geometry.json"
var checks:=0
var failures:=0
var counts:={"native_leaf_inputs":0,"packets":0,"source_frame_exclusions":0,"nonzero_native_float_plane_gaps":0,"nonexact_render_forward_points":0}
var evidence:Array=[]
var first:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=30:push_error(label)
func equal_words(a:Variant,b:Variant)->bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key:Variant in a:
			if not b.has(key) or not equal_words(a[key],b[key]):return false
		return true
	if (a is Array or a is PackedInt64Array) and (b is Array or b is PackedInt64Array):
		if a.size()!=b.size():return false
		for index in range(a.size()):
			if not equal_words(a[index],b[index]):return false
		return true
	if (a is int or a is float) and (b is int or b is float):return a==b
	return a==b
func phone_frame(model:int,uid:int,latitude:float=0.31,longitude:float=0.47)->Dictionary:
	var record:=PackedByteArray();record.resize(68);record.encode_u16(12,model);var basis:Basis=Terrain.new().basis_at(latitude,longitude);var values:Array=[]
	for axis:Vector3 in [basis.x,basis.y,basis.z]:
		for component:float in [axis.x,axis.y,axis.z]:values.append(component)
	var parent:=PackedByteArray();parent.resize(36)
	for axis in range(3):parent.encode_s32(axis*16,0x7fffffff)
	return {"basis_f64":values,"radius_m":Terrain.reference_radius(record),"source_uid_u32":uid,"source_model_index":model,"latitude":latitude,"longitude":longitude,"parent_frame_policy":"isolated-matching-bodyfixed-parent-q31","source_body_parent_index_u8":2,"source_body_frame_u8":1,"source_parent_index_u8":2,"source_parent_matrix_q31_hex":parent.hex_encode()}
func floats(hex:String,width:int)->PackedFloat64Array:
	var bytes:=hex.hex_decode();var result:=PackedFloat64Array()
	for index in range(bytes.size()/width):result.append(bytes.decode_double(index*width) if width==8 else bytes.decode_float(index*width))
	return result
func native_packets()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.source_sha256==Natural.SOURCE_SHA and fixture.native_fresh_process_runs_per_bank==3,"Input leaves identify independently executed original instructions and fresh native runs")
	for bank:String in ["actor_cases","ground_cases"]:
		for sample:Dictionary in fixture[bank]:
			var model:=int(sample.parent_model)
			if model<117 or model>133:continue
			var parent:=str(sample.parent_object_hex).hex_decode();var phone:=phone_frame(model,parent.decode_u32(0xa0))
			for native:Dictionary in sample.expected.volume_trace:
				if not native.winning_triangle.captured:continue
				counts.native_leaf_inputs+=1
				var observer:=PackedInt64Array(native.observer_model_local_raw);var frame:=SourceFrame.build(model,observer,int(native.vector_scale_s32))
				if not frame.ok:
					counts.source_frame_exclusions+=1;check(not Geometry.build(frame,{},phone).ok,"Rejected original source chart cannot silently produce a render triangle");continue
				var point:=Point.new().frame_raw(model,observer,int(native.vector_scale_s32));var tracer:=Trace.new();var queried:=tracer.query_raw(parent.decode_u32(0xa0),int(point.query_style_raw),point.query_matrix_raw,point.query_center_raw,int(point.query_limit_raw),1,point.features);var row:Dictionary=tracer.read_trace()[0]
				check(not queried.is_empty() and Geometry._hex32(Geometry._words(row.winning_triangle.positions_raw,9))==Geometry._hex32(Geometry._words(native.winning_triangle.positions_raw,9)) and int(row.winning_triangle.recorded_intersection_raw)==int(native.winning_triangle.recorded_intersection_raw),"Source row exactly matches the independently captured native winning leaf")
				var before:=var_to_bytes([frame,row,phone]);var result:=Geometry.build(frame,row,phone)
				check(result.get("ok",false),"Actual original native leaf has a bounded declared projection: "+str(sample.id)+"/"+str(native.child_index)+" "+str(result.get("reason","missing build result")))
				check(var_to_bytes([frame,row,phone])==before,"Building a packet preserves the source frame, trace and phone chart")
				if not result.get("ok",false):continue
				counts.packets+=1
				var packet:Dictionary=result.packet;var certificate:Dictionary=result.certificate
				check(certificate.ok and certificate.source_query_identity_verified and certificate.raw_leaf_identity_verified and certificate.original_integer_intersection_replayed and certificate.render_projection_verified and certificate.native_forward_derived_intervals_verified,"Certificate identifies source generation, original SAR/Q15 replay and the declared projection")
				check(not certificate.source_geometry_identity_verified and not certificate.float_collision_height_equivalence and not certificate.whole_mesh_certified and not certificate.live_response_enabled,"A raw leaf/render derivation never claims float collision equivalence, a whole mesh or live admission")
				check(certificate.packet_sha256==Geometry.packet_sha256(packet) and packet.indices==[0.0,1.0,2.0],"Packet seal binds exact canonical metadata and native vertex order")
				var vertices:=floats(packet.local_vertices_f64_hex,8);var rendered:=floats(packet.local_vertices_f32_hex,4);var exact:=floats(packet.linear_projection_enclosure_f64_hex,8);var floor_region:=floats(packet.q31_floor_preimage_enclosure_f64_hex,8);var cells:=floats(packet.float32_rounding_cells_f64_hex,8);var errors:=floats(packet.render_vs_q31_preimage_error_f64_hex,8);var sar_region:=floats(packet.f579_sar_preimage_enclosure_f64_hex,8);var sar_errors:=floats(packet.render_vs_f579_sar_preimage_error_f64_hex,8)
				check(vertices.size()==9 and rendered.size()==9 and exact.size()==18 and floor_region.size()==18 and cells.size()==18 and errors.size()==18 and sar_region.size()==18 and sar_errors.size()==18,"All vertex and interval payloads are shallow fixed-size exact binary hex")
				for axis in range(9):
					check(vertices[axis]>=exact[axis*2] and vertices[axis]<=exact[axis*2+1] and vertices[axis]>=cells[axis*2] and vertices[axis]<=cells[axis*2+1],"Actual projection is enclosed by outward arithmetic and its adjacent-float rounding cell")
					check(rendered[axis]-floor_region[axis*2+1]>=errors[axis*2] and rendered[axis]-floor_region[axis*2]<=errors[axis*2+1],"Q31 preimage/render error comes from its derived interval rather than a height epsilon")
					check(sar_region[axis*2]<=floor_region[axis*2] and sar_region[axis*2+1]>=floor_region[axis*2+1] and rendered[axis]-sar_region[axis*2+1]>=sar_errors[axis*2] and rendered[axis]-sar_region[axis*2]<=sar_errors[axis*2+1],"The full F579 SAR-low-bit enclosure contains its zero-low-bit representative and derives its render error without epsilon")
				if certificate.has("raw_leaf_float_intercept_gap_m") and float(certificate.raw_leaf_float_intercept_gap_m)!=0:counts.nonzero_native_float_plane_gaps+=1
				var projected:=str(packet.render_native_query_error_s32_hex).hex_decode();var nonexact:=false
				for axis in range(9):nonexact=nonexact or projected.decode_s32(axis*4)!=0
				if nonexact:counts.nonexact_render_forward_points+=1
				var transported:Dictionary=JSON.parse_string(JSON.stringify(packet));check(Geometry.verify(transported,frame,row,phone).ok,"JSON transport preserves exact raw vertices, quantization witnesses, render bytes and packet seal")
				if first.is_empty():first={"frame":frame.duplicate(true),"row":row.duplicate(true),"phone":phone.duplicate(true),"result":result.duplicate(true)}
	check(counts.packets>0 and counts.nonzero_native_float_plane_gaps>0 and counts.nonexact_render_forward_points>0,"Native cases demonstrate useful packets and actual float/integer differences without forcing them to zero")
	evidence.append({"case":"independently_observed_native_leaves","counts":counts.duplicate(true),"source_native_chain_executed_by_this_test":false,"separate_native_fixture_consumed":true})
func reject(frame:Dictionary,row:Dictionary,phone:Dictionary,label:String)->void:
	var before:=var_to_bytes([frame,row,phone]);var value:=Geometry.build(frame,row,phone)
	check(not value.ok and not value.certificate.ok and value.packet.is_empty(),label+" rejects before producing a claimed certificate")
	check(var_to_bytes([frame,row,phone])==before,label+" leaves all inputs unchanged")
func tampering_and_transport()->void:
	if first.is_empty():return
	var frame:Dictionary=first.frame;var row:Dictionary=first.row;var phone:Dictionary=first.phone;var packet:Dictionary=first.result.packet
	var changed:=frame.duplicate(true);changed.rotation_q31_raw[0]+=1;reject(changed,row,phone,"Changed source U")
	changed=frame.duplicate(true);changed.query_center_raw[2]+=1;reject(changed,row,phone,"Changed source C")
	changed=row.duplicate(true);changed.source_uid_u32=(int(changed.source_uid_u32)+1)&0xffffffff;reject(frame,changed,phone,"Stale parent UID")
	changed=row.duplicate(true);changed.query_matrix_raw[0]+=1;reject(frame,changed,phone,"Changed source A")
	changed=row.duplicate(true);changed.winning_triangle.positions_raw[0][0]+=1;reject(frame,changed,phone,"Changed native leaf point")
	changed=row.duplicate(true);changed.winning_triangle.vertex_ids_s32[0]+=1;reject(frame,changed,phone,"Changed native leaf order identity")
	changed=row.duplicate(true);changed.winning_triangle.sar_positions_raw[0][0]+=1;reject(frame,changed,phone,"Changed original SAR witness")
	changed=row.duplicate(true);changed.winning_triangle.plane_fraction_calls[0].fraction_s32+=1;reject(frame,changed,phone,"Changed original Q15 witness")
	changed=phone.duplicate(true);changed.basis_f64[0]=0.25;reject(frame,row,changed,"Phone basis does not match its geographic chart")
	changed=phone.duplicate(true);changed.source_body_frame_u8=0;reject(frame,row,changed,"Inertial source frame is not silently treated as bodyfixed")
	changed=phone.duplicate(true);changed.source_parent_index_u8=3;reject(frame,row,changed,"Mismatched original parent identity")
	changed=phone.duplicate(true);changed.source_parent_matrix_q31_hex="00000000"+str(changed.source_parent_matrix_q31_hex).substr(8);reject(frame,row,changed,"An unsupported original parent orientation is not discarded")
	changed=phone.duplicate(true);changed.radius_m=1e308;reject(frame,row,changed,"Finite source chart overflows Float32 presentation")
	changed=packet.duplicate(true);changed.indices=[0,2,1];check(not Geometry.verify(changed,frame,row,phone).ok,"Changed render indices cannot reuse a packet certificate")
	changed=packet.duplicate(true);changed.local_vertices_f32_hex="00000000"+str(changed.local_vertices_f32_hex).substr(8);check(not Geometry.verify(changed,frame,row,phone).ok,"Changed rendered vertex cannot reuse a packet certificate")
	changed=phone.duplicate(true);changed.radius_m=float(changed.radius_m)+1.0;check(not Geometry.verify(packet,frame,row,changed).ok,"A valid different reference origin still invalidates an old packet")
	var pole:=SourceFrame.build(118,PackedInt64Array([0,0,200000000]),3);reject(pole,{},phone_frame(118,int(phone.source_uid_u32)),"Original zero-XY antiparallel pole")
	check(Geometry._inverse(PackedFloat64Array([0,0,0,0,0,0,0,0,0])).is_empty(),"An interval determinant containing zero is rejected without a chosen epsilon")
	var diagnostics:=Diagnostics.new();var envelope:={"context":{"flight":{"geometry":{"volumes":[{"packet":packet,"certificate":first.result.certificate}]}}}};var safe:Variant=diagnostics._safe_value(envelope,0);diagnostics.free()
	check(equal_words(safe,envelope),"Actual report collector preserves shallow packet/certificate hex metadata at its real nesting depth")
	var again:=Geometry.build(frame,row,phone);first.result.packet.local_vertices_f32_hex="caller edit";first.result.certificate.ok=false
	check(Geometry.build(frame,row,phone)==again,"Packet and certificate output buffers are independent of caller edits")
	evidence.append({"case":"native_leaf_projection_example","packet":again.packet,"certificate":again.certificate,"native_whole_mesh_claim":false})
func run()->void:
	var literal:=Geometry._leaf_plane(PackedFloat64Array([1,0,3,0,1,4,1,1,5]))
	check(literal.nondegenerate and literal.intercept_defined and literal.intercept==2.0,"Independent plane z=x+2y+2 has query-axis intercept+2 with the correct source-plane sign")
	native_packets();tampering_and_transport()
	check(counts.native_leaf_inputs>100 and int(counts.packets)+int(counts.source_frame_exclusions)==int(counts.native_leaf_inputs),"The complete native leaf bank finishes without an interrupted test function")
	var pins:Dictionary={}
	for path:String in ["scripts/source_native_contact_geometry.gd","tests/test_source_native_contact_geometry.gd","scripts/source_terrain_query_frame.gd","scripts/source_terrain_query_trace.gd","scripts/source_terrain_query.gd","tests/fixtures/source_footprint_native.json","tests/fixtures/source_contact_frame_native.json","data/ffe_terrain_query.json"]:pins[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"counts":counts,"sources":pins,"evidence":evidence,"scope":"One freshly regenerated original native integer leaf per packet, original unchanged SAR13/Q15 intersection replay, declared inverse phone projection, outward binary64 intervals and adjacent-binary32 rounding cells. No selected height epsilon, float collision-height equivalence, source bank, whole mesh, live F575, GPU or physical Android proof."},"\t"));file.close()
	print("Native contact geometry: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
