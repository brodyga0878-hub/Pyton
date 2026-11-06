extends SceneTree
const Renderer=preload("res://scripts/celestial_renderer.gd")
const GlobalMesh=preload("res://scripts/source_global_body_mesh.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const World=preload("res://scripts/planetary_system.gd")
const GalaxyData=preload("res://scripts/galaxy.gd")
class LightingWorld extends RefCounted:
	var layout_mode:="source_jjffe_systems_v4"
	var system_id:=23
	var focus_id:="planet"
	var settlements:Array=[]
	var bodies:Array=[]
	var by_id:Dictionary={}
	var points:={"star":Vector3(0,0,1),"first":Vector3(-100,0,0),"second":Vector3(10,0,0),"planet":Vector3.ZERO}
	func _init()->void:
		for entry in [["star","barycenter",0],["first","star",21],["second","star",22],["planet","rock",3]]:
			var body:={"id":entry[0],"kind":entry[1],"type_code":entry[2],"radius_km":1.0,"rotation_hours":0.0,"rings":false,"landable":false}
			bodies.append(body);by_id[str(body.id)]=body
	func local_meters(id:String,_days:float)->Vector3:return points.get(id,Vector3.ZERO)
	func body_rotation_basis(_id:String,days:float)->Basis:return Basis(Vector3.FORWARD,days*0.3)
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func digest(value:Variant)->String:return var_to_bytes(value).hex_encode().sha256_text()

func actual_source_mesh()->Dictionary:
	var galaxy:=GalaxyData.new();var world:=World.new();world.configure(galaxy.get_system(GalaxyData.SOL_ID),World.FULL_LAYOUT)
	check(world.layout_mode==World.FULL_LAYOUT and world.by_id.has("earth") and world.by_id.has("moon"),"Actual complete native Sol supplies source terrain body records")
	var input:=GlobalMesh.snapshot(world,"earth");var before:=digest(input)
	var result:=GlobalMesh.build(input)
	check(result.get("ok",false),"Actual native Earth global height worker data builds")
	if not result.get("ok",false):return {}
	check(digest(input)==before,"Global mesh builder preserves immutable source body/site snapshot")
	check(result.height_policy==Terrain.SAMPLE_POLICY and result.source_policy.height_policy==Terrain.SAMPLE_POLICY and result.record_hex==world.by_id.earth.runtime_record_hex,"Global vertices use exact same source record and v4 surface height policy")
	check(result.sample_nodes.size()==325 and result.arrays[Mesh.ARRAY_VERTEX].size()==2145 and result.arrays[Mesh.ARRAY_INDEX].size()==64*32*6,"Source query lattice and modern smooth render lattice remain explicitly bounded")
	check(result.source_stats.entries<=Terrain.CACHE_LIMIT and result.source_stats.source_samples<=4*325,"Source worker cannot grow its height cache or native query count without bound")
	var terrain:=Terrain.new();terrain.configure(world,"earth","",Terrain.REVISION_NAME)
	var vertices:PackedVector3Array=result.arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=result.arrays[Mesh.ARRAY_NORMAL]
	for y in [0,3,6,9,12]:
		for x in [0,3,6,9,12,15,18,21,24]:
			var lat:=-PI*0.5+PI*float(y)/12.0;var lon:=-PI+TAU*float(x)/24.0
			var expected:=terrain.elevation(lat,lon)
			check(absf(float(result.sample_nodes[y*25+x])-expected)<0.000001,"Global coarse height equals actual surface v4 sampler at its source node")
			var render_y:int=int(y)*8/3;var render_x:int=int(x)*8/3;var point:Vector3=vertices[render_y*65+render_x]
			check(absf(point.length()*float(result.radius_m)-(float(terrain.radius)+expected))<2.0,"Aligned actual source node survives float32 render boundary within2m")
	for y in range(33):
		check(vertices[y*65]==vertices[y*65+64] and normals[y*65].distance_to(normals[y*65+64])<0.000001,"Geographic seam duplicates identical position and smooth normal")
	for index in range(vertices.size()):
		if not vertices[index].is_finite() or not normals[index].is_finite() or absf(normals[index].length()-1.0)>0.00001 or normals[index].dot(vertices[index])<=0:check(false,"Source global mesh must remain finite with outward unit normals")
	check(result.sampled_global_lod and not result.original_adaptive_renderer,"Modern sampled LOD does not claim original adaptive painter renderer")
	var cancelled:=GlobalMesh.Cancellation.new();cancelled.cancel();check(GlobalMesh.build(input,cancelled).get("cancelled",false),"Cancelled immutable mesh job exits without publishing partial geometry")
	check(not GlobalMesh.build({}).get("ok",false) and GlobalMesh.snapshot(world,"star").is_empty(),"Invalid/nonlandable source focus does not fabricate terrain")
	var changed:=input.duplicate(true);changed.body.runtime_record_hex="different";check(GlobalMesh.key(changed)!=GlobalMesh.key(input),"Source body byte change invalidates render cache key")
	return {"world":world,"result":result,"input":input}

func luminous_sources()->void:
	var world:=LightingWorld.new();var renderer:=Renderer.new();root.add_child(renderer);renderer.basis=Basis(Vector3.UP,0.4);renderer.configure(world)
	var light:=renderer.source_light("planet",2.0)
	check(light.body_id=="second" and light.policy=="nearest_actual_source_luminous_star_v1","Nearest actual luminous secondary star wins over barycentre named star")
	check(light.direction_world.distance_to((renderer.global_basis*Vector3.RIGHT).normalized())<0.00001,"Actual stellar light direction includes renderer world frame")
	renderer.update_view(2.0,Vector3(0,0,100))
	for id in renderer.visuals:
		var entry:Dictionary=renderer.visuals[id]
		check(entry.mesh.basis.is_finite() and entry.mesh.basis.is_equal_approx(world.body_rotation_basis(id,2.0)),"Zero rotation-hours FULL body receives actual source Basis without NaN")
	check(renderer.visuals.planet.mesh.get_meta("source_light_body_id")=="second","Planet shader receives actual selected luminous source identity")
	check(not renderer.visuals.has("star") and renderer.source_mesh_state().status=="unsupported","Barycentre has no visual sphere or manufactured source terrain")
	world.bodies=[world.by_id.star,world.by_id.planet]
	check(renderer.source_light("planet",0.0).is_empty(),"Barycentre alone never masquerades as a luminous star")
	renderer.queue_free();await process_frame

func async_render_and_cache(actual:Dictionary)->void:
	if actual.is_empty():return
	var world:RefCounted=actual.world;world.focus_id="moon";var before:=digest([world.bodies,world.settlements])
	var renderer:=Renderer.new();root.add_child(renderer);renderer.configure(world)
	check(renderer.source_mesh_state().status in ["pending","building"],"FULL actual source focus launches asynchronous worker rather than blocking render configure")
	var deadline:=Time.get_ticks_msec()+30000
	while renderer.source_mesh_state().status in ["pending","building"] and Time.get_ticks_msec()<deadline:await process_frame
	check(renderer.source_mesh_state().status=="ready", "Actual native Moon worker installs completed immutable global mesh")
	if renderer.source_mesh_state().status!="ready":renderer.queue_free();await process_frame;return
	var entry:Dictionary=renderer.visuals.moon
	check(entry.mesh.mesh is ArrayMesh and entry.source_height_active and entry.mesh.get_meta("source_global_height_revision")==GlobalMesh.REVISION,"Ready FULL focus uses actual source-height mesh")
	var mesh_hash:=digest(entry.mesh.mesh.surface_get_arrays(0));var cache_before:int=renderer.source_mesh_state().cache_entries
	for index in range(12):renderer.update_view(0.0,Vector3(index*10,0,0));renderer.set_surface_transition(true,float(index)/12.0)
	check(digest([world.bodies,world.settlements])==before and digest(entry.mesh.mesh.surface_get_arrays(0))==mesh_hash,"Per-frame position/coverage changes do not resample or change original source bytes/mesh")
	check(renderer.source_mesh_state().status=="ready" and renderer.source_mesh_state().job_key.is_empty() and renderer.source_mesh_state().cache_entries==cache_before,"Completed global focus schedules no additional native sampling each frame")
	renderer.set_quality(0);renderer.set_surface_transition(false,0);check(digest(entry.mesh.mesh.surface_get_arrays(0))==mesh_hash,"Graphics quality changes preserve actual sampled source geometry")
	world.focus_id="star";renderer.set_surface_transition(false,0)
	check(renderer.source_mesh_state().status=="unsupported" and entry.mesh.mesh is SphereMesh,"Leaving landable source focus releases active global mesh without inventing stellar terrain")
	world.focus_id="moon";renderer.set_surface_transition(true,0.5)
	check(renderer.source_mesh_state().status=="ready" and renderer.visuals.moon.mesh.mesh is ArrayMesh and renderer.source_mesh_state().job_key.is_empty(),"Returning to known source focus uses bounded completed cache immediately")
	renderer.update_view(0.0,Vector3.ZERO)
	check(renderer.visuals.moon.anchor.scale.is_equal_approx(Vector3.ONE*float(world.by_id.moon.radius_km)*1000.0),"FULL transition uses actual source reference radius without authored350m shrink")
	renderer.queue_free();await process_frame

func run()->void:
	var actual:=actual_source_mesh();await luminous_sources();await async_render_and_cache(actual)
	print("SOURCE CELESTIAL RENDERER TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
