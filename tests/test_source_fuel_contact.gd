extends SceneTree
const Contact=preload("res://scripts/source_fuel_contact.gd")
const Query=preload("res://scripts/source_terrain_query.gd")
const World=preload("res://scripts/planetary_system.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const FIXTURE:="res://tests/fixtures/source_fuel_contact_native.json"
var checks:=0
var failures:=0
var evidence:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=35:push_error(message)
func native_cases()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));check(fixture is Dictionary and fixture.get("source_sha256")==Contact.SOURCE_SHA and fixture.get("source_contract")==Contact.CONTRACT,"Native contact source contract")
	if not fixture is Dictionary:return
	check(fixture.get("fresh_process_runs")==3 and fixture.get("reverse_repeat_count")==fixture.get("case_count") and fixture.get("canaries_unchanged",false) and fixture.get("parent_bank_unchanged",false),"Fresh reverse and guarded actual original geometry executions")
	var core:=Contact.new();var models:Dictionary={};var branches:Dictionary={}
	for sample:Dictionary in fixture.cases:
		var point:=PackedInt64Array()
		for value:Variant in sample.point_input_raw:point.append(int(value))
		var before:=point.duplicate();var result:=core.query_raw(int(sample.parent_model),int(sample.parent_uid_u32),point,int(sample.graphics_level));var expected:Dictionary=sample.expected.passes[0];var label:="native model%d %s"%[int(sample.parent_model),str(point)]
		check(result.ok,label+" original model/point accepted")
		if not result.ok:continue
		models[int(sample.parent_model)]=true;branches[result.branch]=int(branches.get(result.branch,0))+1
		check(int(result.contact.altitude_raw_s32)==int(expected.height_s32),label+" actual F574 altitude")
		check(int(result.contact.flags_u8)==int(expected.collision_flags_u8),label+" actual F575 atmosphere/contact flags")
		check(int(result.terrain_query_calls)==int(sample.expected.terrain_query_calls),label+" same original F1876 call count")
		check(point==before,label+" immutable source64point")
	check(models.size()==15 and branches.has("terrain_query") and branches.has("broad_phase_rejected") and branches.has("inside_inner_bound") and branches.has("outside_outer_bound"),"Every15 actual models and source bound/field branches covered")
	evidence.append({"native_cases":fixture.case_count,"models":models.keys(),"branches":branches,"source_fixture_sha256":FileAccess.get_file_as_string(FIXTURE).sha256_text()})
func contracts()->void:
	var core:=Contact.new()
	for id in range(134,149):
		var meta:=Contact.metadata(id)
		check(not meta.is_empty() and int(meta.outer_bound_raw)>int(meta.inner_bound_raw) and int(meta.terrain_style_raw)==(3 if id==134 else (6 if id==135 else (5 if id==136 else 9))),"Actual source style/bounds model"+str(id))
	check(Contact.model(133).is_empty() and Contact.model(149).is_empty(),"Unvalidated model domains reject")
	for bad:Variant in [[],[0,0],[0,0,INF],[0,0,1.5],[0,0,0x2000000000000000]]:check(not core.query_raw(137,1,bad).ok,"Invalid raw points reject")
	check(not core.query_raw(137,-1,[1,2,3]).ok,"Negative source UID rejects")
	var at:=Contact.raw_speed(Vector3(874.21875,0,0));check(at.ok and at.speed_s32==9000,"Source9000speed means874.21875 nominal metres/sec in current controller frame")
	check(Contact.raw_speed(Vector3(874.0,0,0)).speed_s32<9000,"Below raw source speed remains below9000")
	check(not Contact.raw_speed(Vector3(INF,0,0)).ok,"Invalid live velocity rejects")
	var galaxy:=Galaxy.new();galaxy.configure_native();var world:=World.new();var ship:=Flight.new();world.configure(galaxy.get_system(World.SOL_ID),World.FULL_LAYOUT)
	check(world.layout_mode==World.FULL_LAYOUT,"Actual completed source Sol world")
	var old_tables:=var_to_bytes(Query.resources);var source_world_before:=var_to_bytes(world.snapshot());var flight_before:=var_to_bytes(ship.snapshot());var initial:=core.sample(world,ship,0)
	check(initial.ok and var_to_bytes(world.snapshot())==source_world_before and var_to_bytes(ship.snapshot())==flight_before,"Live geometry sampling preserves physical world and ship")
	check(var_to_bytes(Query.resources)==old_tables,"New gas/star model records do not modify common original terrain resources")
	var spin_before:=var_to_bytes(world.snapshot().body_spin_by_id);var future:=core.sample(world,ship,2.0)
	check(future.ok and var_to_bytes(world.snapshot().body_spin_by_id)==spin_before,"Future contact sampling advances a private source spin and leaves persistent world timestamps unchanged")
	check(not core.sample(world,ship,-1).ok,"Invalid negative source time cannot create a fake centre")
	var source:Dictionary=world.by_id.star;var center:=world.local_meters("star",0);var meta:=Contact.metadata(int(source.model_index));ship.position=center+Vector3(float(meta.outer_bound_m)*3.0,0,0);ship.velocity=Vector3(900,0,0)
	var far:=core.sample(world,ship,0);check(far.ok and int(far.contact.flags_u8)&1==0,"Actual distant position cannot gain atmosphere from brightness or selection")
	ship.position=center+Vector3(float(meta.outer_bound_m)*0.95,0,0)
	var near:=core.sample(world,ship,0);check(near.ok and near.body_id=="star" and int(near.contact.flags_u8)&1!=0 and int(near.contact.parent_model_u32)==int(source.model_index),"Actual source Sol position runs native natural field, without selecting it")
	ship.position=center;var core_center:=core.sample(world,ship,0)
	check(core_center.ok and int(core_center.contact.flags_u8)&0x80!=0 and core_center.geometry.branch=="inside_inner_bound","Exact centre remains original core contact rather than an invalid-frame atmosphere fallback")
	ship.surface_mode=true;check(core.sample(world,ship,0).contact.flags_u8==0,"Surface context never scoops through space geometry")
	ship.surface_mode=false;ship.docked=true;check(core.sample(world,ship,0).contact.flags_u8==0,"Docked context never scoops")
	world.layout_mode=World.PORT_LAYOUT;ship.docked=false;check(core.sample(world,ship,0).reason=="legacy_world","Legacy world contract remains separate")
	evidence.append({"live_sol_model":source.model_index,"near_contact":near.contact,"near_branch":near.geometry.branch if near.get("geometry") is Dictionary else "missing","actual_near_source_speed":near.speed_s32,"si_policy":Contact.POLICY,"native_units_bridged_by_current_controller_adapter":true})
func run()->void:
	native_cases();contracts()
	var report:={"schema":1,"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual F1533/F574/F575/F576/F579/F582/F581/F1876 native gas/star reference geometry; isolated readonly natural branch. Current World body orientation/local position and phone SI speed are explicit adapters, not full F569 object scanning or automatic frame selection. No collision response, thermal damage or physical Android execution.","physical_device_tested":false,"sources":{"core_sha256":FileAccess.get_file_as_string("res://scripts/source_fuel_contact.gd").sha256_text(),"fixture_sha256":FileAccess.get_file_as_string(FIXTURE).sha256_text(),"test_sha256":FileAccess.get_file_as_string("res://tests/test_source_fuel_contact.gd").sha256_text(),"resource_sha256":FileAccess.get_file_as_string(Contact.DATA_PATH).sha256_text()}}
	var path:="res://validation/fuel-2026-11-07/source-fuel-contact-core.json";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()));var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));print("Source fuel contact: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
