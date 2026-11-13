extends SceneTree
const Terrain=preload("res://scripts/source_contact_surface_terrain.gd")
const Legacy=preload("res://scripts/source_surface_terrain.gd")
const Field=preload("res://scripts/source_terrain_contact_field.gd")
const Units=preload("res://scripts/source_units.gd")
const REPORT:="res://build/current-test-reports/source-contact-surface-terrain.json"
const LEGACY_SHA:="5c2939f5dae7adfa08e7591980612d6e53fd6fcdcf321850d00d388982024a17"
class TestWorld extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=44341016
class RejectedField extends RefCounted:
	func sample_radial(_record:PackedByteArray,_direction:PackedInt64Array,_graphics:int)->Dictionary:
		return {"ok":false,"certified":false,"error":"explicit_uncertified_field_fixture","query_count":1}
var checks:=0
var failures:=0
var evidence:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func world_for(record:PackedByteArray)->TestWorld:
	var world:=TestWorld.new();world.by_id.body={"runtime_record_hex":record.hex_encode(),"radius_km":1.0};return world
func same_sources()->void:
	check(FileAccess.get_sha256("res://scripts/source_surface_terrain.gd")==LEGACY_SHA,"Original v4 sampler remains byte-exact")
	check(Terrain.CONTACT_REVISION!=Legacy.REVISION_NAME and Terrain.HEIGHT_POLICY!=Legacy.SAMPLE_POLICY,"New contact geometry has a separate revision and cache policy")
func configure_and_real_roots(record:PackedByteArray)->Terrain:
	var world:=world_for(record);var original:=Legacy.new();original.configure(world,"body","")
	var terrain:=Terrain.new();terrain.configure(world,"body","")
	check(original.configured_ok and terrain.configured_ok,"Actual original model120 configures both explicit geometry revisions")
	check(original.revision==Legacy.REVISION_NAME and terrain.revision==Terrain.CONTACT_REVISION,"Contact terrain never changes the old sampler's revision")
	check(terrain.source_record==record and terrain._parent==original._parent and terrain._probe==original._probe,"Original UID, source objects and model descriptors remain unchanged")
	check(terrain.source_policy==Terrain.geometry_metadata(record) and terrain.source_policy.height_policy==Terrain.HEIGHT_POLICY,"New worker metadata canonically identifies the certified-node policy")
	check(terrain.source_policy.sampled_nodes_certified_against_signed_F581 and not terrain.source_policy.interpolated_points_certified_against_F581,"Node certification is explicitly distinct from interpolation or triangle certification")
	check(terrain.source_policy.original_F576_bounds_require_separate_eligibility,"Geometry cannot bypass original F576 bounds")
	var immutable:=var_to_bytes([record,terrain.source_record,original.source_record]);var lat:=terrain.latitude;var lon:=terrain.longitude
	var expected:=Field.new().sample_radial(record,Legacy.radial_q31(lat,lon),1)
	var actual:=terrain.exact_root_query(lat,lon)
	check(expected.get("ok",false) and actual.get("ok",false) and actual.get("certified")==true,"Actual signed F581 field certifies the model120 root")
	if expected.get("ok",false) and actual.get("ok",false):
		check(actual.position_raw==expected.position_raw and actual.status==expected.status and actual.residual_raw_s64==expected.residual_raw_s64,"Terrain uses the actual field certificate rather than a substituted phone height")
		check(absf(actual.elevation_m-(Units.metres(Legacy._radius_raw(expected.position_raw))-terrain.radius))<1e-9,"Certified raw geometry uses the canonical source HUD metre conversion")
		check(actual.terrain_revision==Terrain.CONTACT_REVISION and actual.height_policy==Terrain.HEIGHT_POLICY,"Root observation retains the geometry and cache revision")
		evidence.append({"case":"actual_model120_certified_root","status":actual.status,"position_raw_hex":Field._hex(actual.position_raw),"residual_raw_s64":actual.residual_raw_s64,"elevation_m":actual.elevation_m,"query_count":actual.query_count,"source_bounds":actual.source_bounds,"original_seed_is_unchanged":actual.seed.position_raw==expected.seed.position_raw})
	check(var_to_bytes([record,terrain.source_record,original.source_record])==immutable,"Querying the new field cannot mutate source record inputs")
	check(terrain.exact_root_query(NAN,0).is_empty() and terrain.exact_root_query(PI,0).is_empty(),"Invalid geographic directions fail closed")
	var rejected:=Terrain.new();rejected.configure(world,"body","",Legacy.REVISION_NAME)
	check(not rejected.configured_ok,"A v4 revision cannot silently select v5 geometry")
	return terrain
func worker_and_cache(terrain:Terrain)->void:
	var height:=terrain.raw_height(0,0)
	check(is_finite(height),"The bounded geographic grid obtains real certified root nodes")
	var first:=terrain.cache_stats();var second_height:=terrain.raw_height(0,0);var second:=terrain.cache_stats()
	check(height==second_height and second.source_samples==first.source_samples and second.hits>first.hits,"A repeated geographic lookup reuses the same certified nodes")
	check(first.policy==Terrain.HEIGHT_POLICY and not first.node_certification_is_triangle_certification,"Contact cache statistics expose their bounded certification scope")
	var exact:=terrain.exact_root_query(terrain.latitude,terrain.longitude)
	if exact.get("ok",false):evidence.append({"case":"root_node_grid_interpolation","grid_elevation_m":height,"exact_root_elevation_m":exact.elevation_m,"grid_minus_exact_m":height-float(exact.elevation_m),"arbitrary_grid_point_certified":false})
	var direct:=terrain.sample(1,2);var memo:=terrain.sample_render_cached(1,2)
	check(direct==memo and terrain.sample_render_cached(1,2)==memo,"Renderer memoization retains every actual v5 sample component")
	var snapshot:=terrain.capture_worker_state();var snapshot_before:=var_to_bytes(snapshot)
	check(snapshot.revision==Terrain.CONTACT_REVISION and snapshot.height_policy==Terrain.HEIGHT_POLICY,"Worker state cannot be mistaken for a v4 source sampler")
	check(Legacy.from_worker_state(snapshot)==null,"Old worker parser rejects the distinct new revision")
	var clone:=Terrain.from_worker_state(snapshot)
	check(clone!=null,"Complete actual contact-field state restores an independent worker")
	if clone!=null:
		check(clone.revision==Terrain.CONTACT_REVISION and clone.source_policy==terrain.source_policy and clone.source_record==terrain.source_record,"Worker clone preserves canonical metadata and source record")
		check(clone.raw_height(0,0)==height and clone.sample_render_cached(1,2)==memo,"Worker clone preserves both geographic and renderer root caches")
		clone.clear_cache();check(clone.cache_stats().entries==0 and terrain.cache_stats().entries>0,"Worker node caches share no live mutation")
		clone.source_record[4]^=1;check(clone.source_record!=terrain.source_record,"Worker source record buffers are copied privately")
	check(var_to_bytes(snapshot)==snapshot_before,"Restoring a worker never mutates its snapshot")
	var bad:=snapshot.duplicate(true);bad.revision=Legacy.REVISION_NAME
	check(Terrain.from_worker_state(bad)==null,"New parser rejects a v4-labelled state")
	bad=snapshot.duplicate(true);bad.source_policy.height_policy=Legacy.SAMPLE_POLICY
	check(Terrain.from_worker_state(bad)==null,"Worker rejects old or forged field metadata")
	bad=snapshot.duplicate(true);bad.parent[0xa0]^=1
	check(Terrain.from_worker_state(bad)==null,"Worker parent UID must match its canonical original record")
	bad=snapshot.duplicate(true);bad.cache["invalid"]=1.0
	check(Terrain.from_worker_state(bad)==null,"Malformed cached geographic keys reject atomically")
	bad=snapshot.duplicate(true);bad.render_cache[PackedFloat64Array([1,2]).to_byte_array()]=PackedFloat64Array([NAN,0,0,0,0])
	check(Terrain.from_worker_state(bad)==null,"Malformed renderer cache cannot become published geometry")
	var patch:=terrain.prepare_patch(terrain.latitude,terrain.longitude,0)
	check(not patch.is_empty() and patch.revision==Terrain.CONTACT_REVISION and patch.height_policy==Terrain.HEIGHT_POLICY,"Prepared geographic patch stamps the distinct contact policy")
	var other:=Terrain.new();other.configure(world_for(terrain.source_record),"body","")
	check(other.install_patch(patch) and other.raw_height(0,0)==height,"Another actual v5 sampler atomically installs compatible root nodes")
	var stats:=other.cache_stats();bad=patch.duplicate(true);bad.revision=Legacy.REVISION_NAME
	check(not other.install_patch(bad) and other.cache_stats().entries==stats.entries,"An old-revision node patch cannot partially replace a new cache")
	bad=patch.duplicate(true);bad.nodes["bad"]=0.0
	check(not other.install_patch(bad) and other.cache_stats().entries==stats.entries,"Invalid node replacement preserves the existing cache")
	var field_before:RefCounted=terrain._contact_field;terrain._contact_field=RejectedField.new()
	var failed:=terrain.exact_root_query(0.1,0.2);terrain._contact_field=field_before
	check(failed.is_empty() and terrain.cache_stats().last_contact_error=="explicit_uncertified_field_fixture","Explicit rejected field control returns no invented root or height")
func unchanged_city_anchor(row:Dictionary)->void:
	var record:=str(row.parent_record_hex).hex_decode();var port:=str(row.port_record_hex).hex_decode()
	var site:={"id":"port","parent":"body","model_index":int(row.port_model),"type_code":35,"original_index":int(row.local_index),"source_seed":int(port.decode_u32(4)),"ground_phase_u16":int(port.decode_u16(18)),"ground_inclination_u16":int(port.decode_u16(34)),"runtime_record_hex":port.hex_encode()}
	var world:=world_for(record);world.settlements=[site]
	var original:=Legacy.new();original.configure(world,"body","port")
	var terrain:=Terrain.new();terrain.configure(world,"body","port")
	check(original.configured_ok and terrain.configured_ok and terrain.city_profiles.has("port"),"Actual original ground-port anchor configures the new explicit surface policy")
	if not original.city_profiles.has("port") or not terrain.city_profiles.has("port"):return
	var a:Dictionary=original.city_profiles.port;var b:Dictionary=terrain.city_profiles.port
	for name:String in ["source_root_raw","source_matrix_q31","plane_normal_body","root_elevation_m","pad_latitude","pad_longitude"]:check(a[name]==b[name],"Original F879 city anchor is unchanged: "+name)
	check(b.terrain_revision==Terrain.CONTACT_REVISION and b.placement_policy=="unchanged-reviewed-jjffe-two-query-F879-anchor-v1","City grading explicitly identifies its unchanged constructor anchor")
	var before:=terrain.cache_stats()
	check(absf(terrain.elevation(b.root_latitude,b.root_longitude)-float(b.root_elevation_m))<0.001,"Fully graded city plane retains its original anchor height")
	check(terrain.cache_stats().source_samples==before.source_samples,"City-plane grading does not masquerade as a certified natural-field query")
	var clone:=Terrain.from_worker_state(terrain.capture_worker_state())
	check(clone!=null and clone.city_profiles==terrain.city_profiles,"Worker retains the explicit v5 city profile without moving its original geometry")
	evidence.append({"case":"unchanged_original_city_anchor","parent_model":record.decode_u16(12),"port_model":int(row.port_model),"source_root_raw_hex":Field._hex(b.source_root_raw),"native_natural_collision_claim":false})
func run()->void:
	same_sources()
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"))
	var record:=PackedByteArray();var city:Dictionary={}
	for row:Dictionary in fixture.cases:
		if record.is_empty() and int(row.parent_model)==120:record=str(row.parent_record_hex).hex_decode()
		if city.is_empty() and int(row.parent_model)!=117 and str(row.get("origin","")).begins_with("original handcrafted"):city=row
	check(record.size()==68 and not city.is_empty(),"Actual original model120 and handcrafted ground-port controls are available")
	if record.size()==68:worker_and_cache(configure_and_real_roots(record))
	if not city.is_empty():unchanged_city_anchor(city)
	same_sources()
	var sources:Dictionary={}
	for path:String in ["scripts/source_contact_surface_terrain.gd","scripts/source_terrain_contact_field.gd","scripts/source_surface_terrain.gd","scripts/source_units.gd","tests/test_source_contact_surface_terrain.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"sources":sources,"evidence":evidence,"scope":"Distinct v5 certified-node surface integration using actual source model120, private worker/cache validation and unchanged original city anchors. Grid/triangle interpolation is explicitly not a certified F581 root. No Main default enablement, live collision response, object-bank/frame selection, GPU rendering or physical Android execution."},"\t"));file.close()
	print("SOURCE CONTACT SURFACE TERRAIN: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
