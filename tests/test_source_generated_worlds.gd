extends SceneTree
const World=preload("res://scripts/planetary_system.gd")
const Definition=preload("res://scripts/source_system_definition.gd")
const Bridge=preload("res://scripts/source_physics_bridge.gd")
const Units=preload("res://scripts/source_units.gd")
const Orbit=preload("res://scripts/source_orbit.gd")
const Clock=preload("res://scripts/source_clock.gd")
const Rotation=preload("res://scripts/body_rotation.gd")
const Station=preload("res://scripts/source_station_geometry.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Nav=preload("res://scripts/navigation.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
var checks:=0
var failures:=0
var station_models:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<30:push_error(label)
func vector_close(a:Vector3,b:Vector3,epsilon:=0.000001)->bool:return a.distance_to(b)<=epsilon*maxf(1.0,b.length())
func native_bank(row:Dictionary)->Array:
 var bank:Array=[]
 for i in range(128):
  var b:=PackedByteArray();b.resize(68);bank.append(b)
 for key in row.records:bank[int(key)]=str(row.records[key]).hex_decode()
 for key in row.expected_records:bank[int(key)]=str(row.expected_records[key]).hex_decode()
 return bank
func json_copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func check_save(world:RefCounted,star:Dictionary)->void:
 var save:Dictionary=json_copy(world.snapshot());var restored:=World.new();restored.configure(star,World.FULL_LAYOUT)
 check(restored.restore(save),"Complete v4 world saves restore through JSON")
 check(restored.snapshot()==world.snapshot(),"v4 full snapshot preserves selected site, pending transfer and Q31frames")
 var before:=var_to_bytes(restored.snapshot());var bad:=save.duplicate(true);bad.source_digest="wrong"
 check(not restored.restore(bad),"Source dataset digest rejects a mismatched v4 save")
 check(before==var_to_bytes(restored.snapshot()),"Rejected v4 save is atomic")
 if not save.body_spin_by_id.is_empty():
  bad=save.duplicate(true);bad.body_spin_by_id[bad.body_spin_by_id.keys()[0]].matrix_q31=[0,0,0,0,0,0,0,0,0]
  check(not restored.restore(bad),"Corrupt body rotation rejects before assignment")
 if not save.station_state_by_site.is_empty():
  bad=save.duplicate(true);bad.station_state_by_site[bad.station_state_by_site.keys()[0]].door_u16=65536
  check(not restored.restore(bad),"Invalid original door word rejects before assignment")
  bad=save.duplicate(true);bad.station_state_by_site[bad.station_state_by_site.keys()[0]].pending_launch=1
  check(not restored.restore(bad),"Pending launch flag accepts only an explicit bool")
func test_system(row:Dictionary)->void:
 var star:=Definition.new().describe(row.system_id);var world:=World.new();world.configure(star,World.FULL_LAYOUT)
 check(world.layout_mode==World.FULL_LAYOUT and world.preferred_layout()==World.FULL_LAYOUT,"Actual F860 system uses opt-in v4 "+str(row.system_name))
 if world.layout_mode!=World.FULL_LAYOUT:return
 if row.group=="actual_f860_zero_radius_caller_fix":
  check(int(world.full_system_state.original_parameters.seed_a)==int(row.original_seed_a) and int(world.full_system_state.effective_parameters.seed_a)==int(row.seed_a),"World preserves original nonterminating header and independently native safe input")
  check(world.full_system_state.caller_correction_policies.has(World.ZERO_ROOT_RADIUS_POLICY),"Zero-radius caller correction is explicit in world provenance")
 var bank:=native_bank(row);var count:=int(row.expected.index)
 check(world.bodies.size()+world.settlements.size()==count,"Live catalogue retains every actual native body and settlement")
 check(world.source_runtime_state.count==count and world.source_runtime_state.record_bank_slots==128,"World reports original full hierarchy capacity and count")
 for pair in [["body_count_byte","body_count_byte"],["star_count_byte","star_count_byte"],["port_count_byte","port_count_byte"],["orbital_port_count_byte","orbital_count_byte"]]:check(world.source_runtime_state[pair[0]]==int(row.expected[pair[1]]),"Exact full-system source byte count "+pair[0])
 for object:Dictionary in world.bodies+world.settlements:
  check(str(object.runtime_record_hex)==bank[int(object.original_index)-1].hex_encode(),"Live object preserves all68 independently native record bytes")
  check(object.source_name_bytes_hex.hex_decode()==_source_name(bank[int(object.original_index)-1]),"Original native display-name bytes retained")
 for body:Dictionary in world.bodies:
  if body.get("landable",false):check(is_equal_approx(float(body.radius_km)*1000.0,Terrain.reference_radius(str(body.runtime_record_hex).hex_decode())),"Landable reference radius is actual source model geometry")
  if not str(body.parent).is_empty():check(world.by_id.has(str(body.parent)),"Body's original parent is live")
 var days:=0.125;var clock:=Clock.from_elapsed_days(days);var absolute:Dictionary={}
 for body:Dictionary in world.bodies:
  var native:=Orbit.evaluate_from_epoch(bank[int(body.original_index)-1],clock.tick_u32,clock.day_u32)
  var point:PackedInt64Array=native.position_raw
  if not str(body.parent).is_empty():point=Orbit.add_positions(absolute[str(body.parent)],point)
  absolute[str(body.id)]=point
  world.position_au(str(body.id),days)
  check(world._native_positions_raw[str(body.id)]==point,"Live centre composes actual source parent translation at source clock")
  var initialized:=Rotation.initialize(int(bank[int(body.original_index)-1][62]),int(bank[int(body.original_index)-1].decode_u16(66)),Clock.EPOCH_TICK_U32)
  var expected_spin:=Rotation.advance(initialized,int(bank[int(body.original_index)-1][62]),int(bank[int(body.original_index)-1].decode_u16(66)),0,Clock.EPOCH_TICK_U32,clock.tick_u32,Clock.EPOCH_DAY_U32,clock.day_u32)
  var basis:=world.body_rotation_basis(str(body.id),days)
  var live_before:=var_to_bytes(world.body_spin_by_id)
  var historical:=world.body_rotation_state(str(body.id),0.0)
  check(live_before==var_to_bytes(world.body_spin_by_id) and int(historical.tick_u32)==Clock.EPOCH_TICK_U32,"Historical rotation query cannot rewind saved live source frames")
  check(world.body_spin_by_id[str(body.id)].matrix_q31==Array(expected_spin.matrix) and basis.is_finite(),"Live natural-body rotation uses source F880/F866 Q31 branch")
 var point:=Vector3(123.0,456.0,789.0);var actual_gravity:=world.gravity_at(point,days)
 var local_raw:=Bridge.relative_from_metres(point);var origin:=world._full_origin_raw(days);var ship_raw:=Orbit.add_positions(origin,local_raw)
 var focus:Dictionary=world.by_id[world.focus_id];var relative:=PackedInt64Array()
 for axis in range(3):relative.append(ship_raw[axis]-world._native_positions_raw[world.focus_id][axis])
 var focus_sample:=Bridge.sample_prepared(int(focus.source_a4_packed),relative)
 check(not focus_sample.is_empty() and vector_close(actual_gravity,focus_sample.acceleration),"Live gravity routes only the current focus parent through independently checked F603 bridge")
 check(world.source_physics_state.live_gravity==Bridge.CONTRACT and world.source_physics_state.original_per_frame_dynamics==false,"World honestly identifies sampled nominal-day SI policy")
 for site:Dictionary in world.settlements:
  if int(site.type_code) not in [32,33,34]:continue
  world.focus_id=str(site.parent);world.selected_id=world.focus_id;world.site_id=str(site.id)
  check(world.site_local_meters(str(site.id),days)==World.ORBITAL_DOCK_LOCAL,"Selected source station has stable local dock centre")
  if station_models.has(int(site.model_index)):continue
  station_models[int(site.model_index)]=true
  var geometry:=world.source_station_geometry(days);var basis:=world.source_station_basis(days)
  check(geometry.get("ok",false) and int(geometry.model_index)==int(site.model_index),"Selected station uses its actual original model triangles")
  check(basis.is_finite() and absf(basis.determinant()-1.0)<0.00001,"Selected station's persistent source orientation is a valid render basis")
  var before:Dictionary=world.source_station_state(days)
  if before.is_empty():continue
  world.station_state_by_site[str(site.id)].status_u8=1
  check(world.advance_station(0.5,days+0.5/86400.0),"Live source station advances original door and spin")
  var after:Dictionary=world.source_station_state(days+0.5/86400.0)
  check(int(after.door_u16)==int(Station.advance_door(before.door_u16,1,roundi(0.5*Bridge.TICKS_PER_SECOND)).door_u16),"Live door follows actual F865 tick policy")
  world.station_state_by_site[str(site.id)].door_u16=65535;world.station_state_by_site[str(site.id)].status_u8=0
  check(world.request_station_open(days+0.5/86400.0,true) and world.station_launch_pending() and not world.station_launch_ready(),"Closed saved station requests actual F865 opening before pending launch")
  check(int(world.source_station_state(days+0.5/86400.0).status_u8)==254,"Opening uses actual negative signed F865 status, not stationary0")
  check_save(world,star)
  check(world.cancel_station_launch() and not world.station_launch_pending(),"Braking can cancel persisted launch intent while door safely opens")
  check(world.request_station_open(days+0.5/86400.0,true),"Cancelled source launch can be explicitly retried")
  check(not world.finish_station_launch(false) and world.station_launch_pending(),"Failed physical launch cannot clear persisted pending request")
  check(world.advance_station(4.0,days+4.5/86400.0) and world.station_launch_ready(),"Original F865 reaches actual open door before launch becomes ready")
  check(world.finish_station_launch(true) and not world.station_launch_pending(),"Only successful launch clears saved request")
  world.station_state_by_site[str(site.id)].door_u16=0;world.station_state_by_site[str(site.id)].status_u8=0
  check_save(world,star)
 world.site_id=""
 var landable:Dictionary={}
 for body:Dictionary in world.bodies:
  if body.get("landable",false):landable=body;break
 if not landable.is_empty():
  var body_point:=Vector3(float(landable.radius_km)*1000.0+1000.0,0,0)
  var sample:=world.source_surface_gravity(str(landable.id),body_point,days)
  var inertial:=world.body_rotation_basis(str(landable.id),days)*body_point
  var expected:=Bridge.sample_prepared(int(landable.source_a4_packed),Bridge.relative_from_metres(inertial))
  check(not sample.is_empty() and vector_close(sample.acceleration,expected.acceleration) and sample.acceleration_frame=="inertial_world_axes","Surface thrust and live force share actual F603 policy and inertial frame")
 check_save(world,star)
 if int(row.system_id)==World.SOL_ID:
  var nav:=Nav.new();check(nav.configure_native(int(star.id)),"Native navigation configures independently for v4 transfer")
  nav.elapsed_days=days;var ship:=Flight.new();ship.station_available=false
  var destination:Dictionary={}
  for site:Dictionary in world.settlements:
   if int(site.type_code) in [32,33,34] and world.by_id[str(site.parent)].kind not in ["star","barycenter"]:destination=site;break
  check(not destination.is_empty(),"Actual Sol has an orbital transfer destination")
  if not destination.is_empty():
   world.site_id="";check(world.begin_site_transfer(str(destination.id),ship,nav),"Full source orbital transfer starts")
   check(world.transfer_remaining==3 and world.pending_site_id==str(destination.id),"Source transfer preserves pending selected actual port")
   check_save(world,star)
   check(world.step_transfer(3.0,ship,nav) and world.site_id==str(destination.id) and world.focus_id==str(destination.parent),"Source transfer arrives in actual station parent frame")
   check(ship.station_available and world.site_local_meters(str(destination.id),nav.elapsed_days)==World.ORBITAL_DOCK_LOCAL,"Arrived station has live dock availability and source-following local centre")
   check_save(world,star)
func _source_name(record:PackedByteArray)->PackedByteArray:
 for i in range(38,62):
  if record[i]==0:return record.slice(38,i+1)
 return PackedByteArray()
func run()->void:
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_system_native.json"));var tested:=0
 for row:Dictionary in fixture.system_cases:
  if row.group in ["actual_f860_header","actual_f860_zero_radius_caller_fix","actual_f860_special_polaris"]:test_system(row);tested+=1
 check(tested==47,"All42 real F860 systems,Polaris and4 native corrected headers are integrated")
 var beta:=Definition.new().describe(0x02af3686);var world:=World.new();world.configure(beta,World.FULL_LAYOUT)
 check(world.layout_mode==World.FULL_LAYOUT and world.full_system_state.caller_correction_policy==World.BETA_LYRAE_POLICY,"Beta Lyrae correction is explicit at caller, not faked as original generation")
 check(world.full_system_state.original_parameters.mass==0xffffffff and world.full_system_state.effective_parameters.mass==0xfffffffe,"Both original unsafe Beta header and effective corrected class are retained")
 check_save(world,beta)
 var strict=preload("res://scripts/source_system_builder.gd").new()
 check(strict.build(beta.source_parameters).is_empty(),"Strict source builder continues to reject undefined Beta class23")
 var definitions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_system_definition_native.json"))
 for row:Dictionary in definitions.cases:
  if int(row.return_s32)==0:continue
  var unknown:=World.new();var unknown_star:={"id":int(row.id),"name":"Unavailable"};unknown.configure(unknown_star,World.FULL_LAYOUT)
  check(unknown.layout_mode==World.EMPTY_LAYOUT and unknown.preferred_layout()==World.FULL_LAYOUT,"Unavailable source header remains explicit empty v4")
  check_save(unknown,unknown_star);break
 var legacy:=World.new();legacy.configure(Definition.new().describe(World.SOL_ID),World.PORT_LAYOUT)
 check(legacy.source_station_geometry(0).is_empty() and legacy.snapshot().version==3,"Legacy v3 does not opt into source station geometry or save schema")
 check(station_models.has_all([69,72,73,74,76,77,78,80]),"All eight orbital station models present in actual native header corpus are live")
 print("SOURCE GENERATED WORLD TESTS: %d checks, %d failures;42realF860headers,Polaris,4zero-radius fixes and explicitBeta fix"%[checks,failures]);quit(1 if failures else 0)
