extends "res://scripts/source_surface_terrain.gd"
# A distinct renderer sampling policy. The original v4 F879 sampler and all
# old saved geometry stay available through their unchanged class/revision.
# F581 certification applies to sampled nodes, not interpolated triangles.
const BaseTerrain=preload("res://scripts/source_surface_terrain.gd")
const ContactField=preload("res://scripts/source_terrain_contact_field.gd")
const CONTACT_REVISION:="sphere-source-contact-v5"
const HEIGHT_POLICY:="signed-f581-contact-root-grid-v1"
const FIELD_PATH:="res://scripts/source_terrain_contact_field.gd"
var _contact_field:RefCounted
var _contact_queries:=0
var _contact_failures:=0
var _last_contact_error:=""

class SnapshotWorld extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=0

func _init()->void:revision=CONTACT_REVISION

static func geometry_metadata(record:PackedByteArray)->Dictionary:
	var result:=BaseTerrain.geometry_metadata(record)
	if result.is_empty():return {}
	result.height_policy=HEIGHT_POLICY
	result["terrain_revision"]=CONTACT_REVISION
	result["seed_placement_policy"]=BaseTerrain.SAMPLE_POLICY
	result["seed_source_variant"]=SourceKernel.SOURCE_VARIANT
	result["field_graphics_level_raw"]=1
	result["signed_field_policy"]=ContactField.HEIGHT_POLICY
	result["signed_field_contract"]=ContactField.CONTRACT
	result["sampled_nodes_certified_against_signed_F581"]=true
	result["interpolated_points_certified_against_F581"]=false
	result["original_F576_bounds_require_separate_eligibility"]=true
	result["city_plane_policy"]="unchanged-reviewed-jjffe-F879-anchor-explicit-grading-v1"
	return result

static func _contact_city_profile(profile:Dictionary)->Dictionary:
	if profile.is_empty():return {}
	profile["terrain_revision"]=CONTACT_REVISION
	profile["placement_policy"]="unchanged-reviewed-jjffe-two-query-F879-anchor-v1"
	if not str(profile.get("key","")).begins_with(CONTACT_REVISION+":"):profile["key"]=CONTACT_REVISION+":"+str(profile.get("key",""))
	return profile

static func source_city_profile(site:Dictionary,parent_record:PackedByteArray,reference_radius_m:float)->Dictionary:
	return _contact_city_profile(BaseTerrain.source_city_profile(site,parent_record,reference_radius_m))

func configure(system:RefCounted,body_id:String,site_id:String,revision_value:String=CONTACT_REVISION)->void:
	if revision_value!=CONTACT_REVISION:
		configured_ok=false;configuration_error="Unsupported contact terrain revision";return
	# The original constructor supplies the source objects and unchanged city
	# anchor records. Only the subsequent terrain sampling policy is replaced.
	super.configure(system,body_id,site_id,BaseTerrain.REVISION_NAME)
	if not configured_ok:return
	_contact_field=ContactField.new()
	revision=CONTACT_REVISION;source_policy=geometry_metadata(source_record)
	for id:Variant in city_profiles:
		city_profiles[id]=_contact_city_profile(city_profiles[id])
	_contact_queries=0;_contact_failures=0;_last_contact_error=""

func _sample_direction_unlocked(radial:PackedInt64Array)->Dictionary:
	if not configured_ok or _contact_field==null or radial.size()!=3:return {}
	var result:Dictionary=_contact_field.sample_radial(source_record,radial,1)
	_contact_queries+=int(result.get("query_count",0))
	if not result.get("ok",false) or result.get("certified")!=true or not result.get("position_raw") is PackedInt64Array or result.position_raw.size()!=3:
		_contact_failures+=1;_last_contact_error=str(result.get("error",result.get("reason","uncertified_source_contact_root")))
		return {}
	var height:=Units.metres(_radius_raw(result.position_raw))-radius
	if not is_finite(height) or radius+height<=0:
		_contact_failures+=1;_last_contact_error="invalid_certified_contact_radius";return {}
	_source_samples+=1
	var sampled:=result.duplicate(true)
	sampled["elevation_m"]=height;sampled["terrain_revision"]=CONTACT_REVISION
	sampled["height_policy"]=HEIGHT_POLICY
	_last_contact_error=""
	return sampled

func exact_root_query(lat:float,lon:float)->Dictionary:
	# Unlike elevation()/raw_height(), this bypasses the 256m interpolation
	# and returns the actual signed-F581 root certificate for this direction.
	if not is_finite(lat) or not is_finite(lon) or absf(lat)>PI*0.5+1e-12:return {}
	return exact_source_sample(lat,lon)

func cache_stats()->Dictionary:
	_mutex.lock()
	var result:={"entries":_cache.size(),"limit":CACHE_LIMIT,"source_samples":_source_samples,"hits":_cache_hits,"evictions":_cache_evictions,"generation":_generation,"cell_metres":CELL_METRES,"policy":HEIGHT_POLICY,"terrain_revision":CONTACT_REVISION}
	result["signed_contact_query_count"]=_contact_queries
	result["uncertified_contact_roots"]=_contact_failures
	result["last_contact_error"]=_last_contact_error
	result["node_certification_is_triangle_certification"]=false
	_mutex.unlock()
	return result

func capture_worker_state()->Dictionary:
	var result:=super.capture_worker_state()
	result.revision=CONTACT_REVISION
	result["height_policy"]=HEIGHT_POLICY
	return result

static func _canonical_objects(record:PackedByteArray)->Dictionary:
	var world:=SnapshotWorld.new()
	world.by_id={"body":{"runtime_record_hex":record.hex_encode(),"radius_km":1.0}}
	var original:=BaseTerrain.new();original.configure(world,"body","")
	return {"parent":original._parent.duplicate(),"probe":original._probe.duplicate()} if original.configured_ok else {}

static func from_worker_state(snapshot:Dictionary)->RefCounted:
	if snapshot.get("revision")!=CONTACT_REVISION or snapshot.get("height_policy")!=HEIGHT_POLICY or snapshot.get("configured_ok")!=true or not snapshot.get("source_record") is PackedByteArray:return null
	var metadata:=geometry_metadata(snapshot.source_record)
	if metadata.is_empty() or snapshot.get("source_policy")!=metadata:return null
	var canonical:=_canonical_objects(snapshot.source_record)
	if canonical.is_empty() or snapshot.get("parent")!=canonical.parent or snapshot.get("probe")!=canonical.probe:return null
	if not snapshot.get("city_profiles") is Dictionary or not snapshot.get("source_site_coordinates") is Dictionary:return null
	for id:Variant in snapshot.city_profiles:
		var profile:Variant=snapshot.city_profiles[id]
		if not id is String or not profile is Dictionary or profile.get("site_id")!=id or profile.get("terrain_revision")!=CONTACT_REVISION or profile.get("placement_policy")!="unchanged-reviewed-jjffe-two-query-F879-anchor-v1":return null
	# Reuse the existing complete node-key/cache/render validation without
	# asking that old class to recognize a new policy or querying its heights.
	var compatible:=snapshot.duplicate(true)
	compatible.revision=BaseTerrain.REVISION_NAME
	compatible.source_policy=BaseTerrain.geometry_metadata(snapshot.source_record)
	var validated:=BaseTerrain.from_worker_state(compatible)
	if validated==null:return null
	var result:RefCounted=load("res://scripts/source_contact_surface_terrain.gd").new()
	result._contact_field=ContactField.new()
	result.revision=CONTACT_REVISION;result.source_record=validated.source_record.duplicate();result.source_model_index=validated.source_model_index
	result.source_policy=metadata.duplicate(true);result._parent=validated._parent.duplicate();result._probe=validated._probe.duplicate()
	for name:String in ["radius","seed_value","latitude","longitude","pad_latitude","pad_longitude","selected_site_id","_lat_cells","_lon_cells"]:result.set(name,validated.get(name))
	result.city_profiles=validated.city_profiles.duplicate(true);result.source_site_coordinates=validated.source_site_coordinates.duplicate(true);result.flat_sites=[]
	result._cache=validated._cache.duplicate(true);result._cache_order=validated._cache_order.duplicate();result._cache_head=0
	result._render_cache=validated._render_cache.duplicate(true);result._render_order=validated._render_order.duplicate(true);result._render_head=0
	result._render_latitude=validated._render_latitude;result._render_longitude=validated._render_longitude;result._render_record=validated._render_record.duplicate()
	if not result._kernel.point_kernel.kernel._load_resources():return null
	result.configured_ok=true;result.configuration_error=""
	return result

func prepare_patch(center_lat:float,center_lon:float,width_m:float,step_m:float=CELL_METRES)->Dictionary:
	var patch:=super.prepare_patch(center_lat,center_lon,width_m,step_m)
	if patch.is_empty():return {}
	patch.revision=CONTACT_REVISION;patch.height_policy=HEIGHT_POLICY
	return patch

func _install_patch_locked(patch:Dictionary)->bool:
	if patch.get("revision")!=CONTACT_REVISION or patch.get("height_policy")!=HEIGHT_POLICY or patch.get("source_policy")!=source_policy:return false
	var compatible:=patch.duplicate(true)
	compatible.revision=BaseTerrain.REVISION_NAME;compatible.height_policy=BaseTerrain.SAMPLE_POLICY
	return super._install_patch_locked(compatible)
