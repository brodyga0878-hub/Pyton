extends SceneTree
const Runtime=preload("res://scripts/source_city_runtime.gd")
const Placement=preload("res://scripts/source_city_profile.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const Units=preload("res://scripts/source_units.gd")
class Frame:
	extends RefCounted
	var latitude:=0.0
	var longitude:=0.0
	var radius:=6371000.0
var checks:=0
var failures:=0
func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;push_error(message)
func profile_at(latitude:float=0,longitude:float=0)->Dictionary:
	return {"root_latitude":latitude,"root_longitude":longitude,"root_elevation_m":0.0,"root_basis":Placement.basis_at(latitude,longitude),"site_id":"analytic"}
func geometry(triangles:Array,profile:Dictionary)->Dictionary:
	var data:=Runtime._index_triangles(triangles)
	data.ok=true;data.triangles=triangles;data.profile=profile
	return data
func wall(x:float=0.0,z:float=0.0)->Array:
	return [[Vector3(x,-100,z-100),Vector3(x,100,z-100),Vector3(x,100,z+100)],
		[Vector3(x,-100,z-100),Vector3(x,100,z+100),Vector3(x,-100,z+100)]]
func _init()->void:call_deferred("run")
func run()->void:
	var globe:=Frame.new();var profile:=profile_at();var data:=geometry(wall(),profile)
	var hit:=Runtime.sweep(data,globe,Vector3(-10,10,0),Vector3(10,10,0),Vector3(2,1,3))
	check(not hit.is_empty() and absf(float(hit.time)-0.4)<0.00001,"Analytic wall CCD finds exact ellipsoid contact before tunnelling")
	check(hit.position.distance_to(Vector3(-2,10,0))<0.0001 and hit.normal.distance_to(Vector3.LEFT)<0.0001,"Contact center and outward normal remain in current frame")
	check(Runtime.sweep(data,globe,Vector3(-2,0,0),Vector3(-2,40,0),Vector3(2,1,3)).is_empty(),"Touching while tangent does not block motion")
	check(Runtime.sweep(data,globe,Vector3(-2,0,0),Vector3(-20,0,0),Vector3(2,1,3)).is_empty(),"Touching while separating permits escape")
	hit=Runtime.sweep(data,globe,Vector3(-1,0,0),Vector3(-1,0,0),Vector3(2,1,3))
	check(not hit.is_empty() and hit.inside and hit.time==0 and absf(hit.position.x+2)<0.0001,"Initial strict overlap returns a separated center")
	check(Runtime.overlaps(data,globe,Vector3(-1,0,0),Vector3(2,1,3)) and not Runtime.overlaps(data,globe,Vector3(-2,0,0),Vector3(2,1,3)),"Stationary overlap distinguishes penetration from exact contact")
	var expected_edge:=2.0*sqrt(1.0-pow(2.0/3.0,2))
	hit=Runtime.sweep(data,globe,Vector3(-10,0,102),Vector3(10,0,102),Vector3(2,1,3))
	check(not hit.is_empty() and absf(float(hit.time)-(10.0-expected_edge)/20.0)<0.00002,"Broad phase retains rounded-edge contact outside triangle XZ bounds")
	var expected_corner:=2.0*sqrt(1.0-0.25-pow(2.0/3.0,2))
	hit=Runtime.sweep(data,globe,Vector3(-10,101,102),Vector3(10,101,102),Vector3(2,2,3))
	check(not hit.is_empty() and absf(float(hit.time)-(10.0-expected_corner)/20.0)<0.00002,"Three-axis ellipsoid reaches the true rounded vertex contact")
	var roof:=geometry([[Vector3(-100,20,-100),Vector3(100,20,100),Vector3(100,20,-100)],
		[Vector3(-100,20,-100),Vector3(-100,20,100),Vector3(100,20,100)]],profile)
	hit=Runtime.sweep(roof,globe,Vector3(40,80,0),Vector3(40,0,0),Vector3(2,3,4))
	check(not hit.is_empty() and absf(float(hit.time)-57.0/80)<0.00001 and hit.normal.distance_to(Vector3.UP)<0.0001,"Roof sweep uses vertical ship radius and upward contact normal")
	var negative:=geometry(wall(-1024,-256),profile)
	hit=Runtime.sweep(negative,globe,Vector3(-1040,0,-256),Vector3(-1000,0,-256),Vector3.ONE*2)
	check(not hit.is_empty() and absf(float(hit.time)-0.35)<0.00001,"Negative 256m cell boundaries do not lose wall contacts")
	hit=Runtime.sweep(data,globe,Vector3(-1000000,0,0),Vector3(1000000,0,0),Vector3.ONE*2)
	check(not hit.is_empty() and absf(float(hit.time)-0.499999)<0.000001,"Huge fast paths use bounded candidate fallback without tunnelling")
	var broad:=geometry([[Vector3(-100000,0,-100000),Vector3(100000,0,100000),Vector3(100000,0,-100000)]],profile)
	check(broad.large_triangles.size()==1 and broad.cells.is_empty(),"Huge floor triangles use conservative global list instead of millions of duplicate bins")
	check(not Runtime.sweep(broad,globe,Vector3(0,10,0),Vector3(0,-10,0),Vector3.ONE).is_empty(),"Large triangle fallback retains actual floor CCD")
	check(Runtime.sweep(data,globe,Vector3(-10,500,0),Vector3(10,500,0),Vector3.ONE).is_empty(),"Above-building path is not blocked by its XZ bins")
	for radii in [Vector3.ZERO,Vector3(-1,2,2),Vector3(INF,2,2)]:check(Runtime.sweep(data,globe,Vector3(-10,0,0),Vector3(10,0,0),radii).is_empty(),"Invalid ellipsoid rejected")
	# A rotated current frame changes ellipsoid support along a root-local wall.
	# Reusing root-axis radii would incorrectly report t=.3 in this case.
	globe.radius=1000;globe.latitude=0.3;globe.longitude=0.6
	var transform:=Runtime.transform_to_frame(profile,globe)
	var normal:Vector3=transform.basis.x.normalized();var radii:=Vector3(8,1,2)
	var support:=sqrt(pow(float(normal.x)*radii.x,2)+pow(float(normal.y)*radii.y,2)+pow(float(normal.z)*radii.z,2))
	hit=Runtime.sweep(data,globe,transform*Vector3(-20,10,0),transform*Vector3(20,10,0),radii)
	check(not hit.is_empty() and absf(float(hit.time)-(20-support)/40)<0.00005,"Rebased anisotropic CCD preserves CURRENT-axis ellipsoid")
	check(absf(float(hit.time)-0.3)>0.01 and hit.normal.distance_to(-normal)<0.0002,"Rotated wall contact is not a falsely root-aligned ellipsoid")
	for radius in [6371000.0,100000000.0]:
		profile=profile_at(0.71,-2.2);globe.radius=radius
		globe.latitude=0.71+0.05/radius;globe.longitude=-2.2+0.02/(radius*cos(0.71))
		transform=Runtime.transform_to_frame(profile,globe)
		check(absf(transform.origin.x+0.02)<0.00002 and absf(transform.origin.z-0.05)<0.00002 and absf(transform.origin.y)<0.00002,"Scalar body-position subtraction retains centimetres on large planetary radii")
	profile=profile_at(0.4,PI-1e-9);globe.radius=6371000;globe.latitude=0.4;globe.longitude=-PI+1e-9
	transform=Runtime.transform_to_frame(profile,globe)
	check(transform.is_finite() and transform.origin.length()<0.1 and transform.origin.x<0,"Longitude seam rebases through a centimetre rather than a full revolution")
	profile=profile_at(PI/2-1e-7,0.3);globe.latitude=PI/2-1e-7+0.01/globe.radius;globe.longitude=0.6
	transform=Runtime.transform_to_frame(profile,globe)
	check(transform.is_finite() and absf(transform.basis.determinant()-1)<0.00001,"Polar local-frame transform stays finite and rigid")
	# Actual archive city, native F1674 frame and F650 highest free pad.
	Runtime.clear_cache()
	var site:=Ground.from_record(12345,7890)
	site.merge({"id":"native89","type_code":35,"model_index":89,"source_seed":0xbdd3aa2e})
	profile=Placement.describe(site,6371000.0)
	var before:=var_to_str(profile)
	data=Runtime.prepare(profile)
	check(data.ok and data.triangles.size()==data.compiled.triangle_count and data.triangles.size()>2000,"Original city89 solid faces prepare with source-model composition")
	check(before==var_to_str(profile) and Runtime.cache_size()==1,"Preparation preserves caller profile and caches data once")
	check(not data.decorative_collision and data.cruise_height_m>=350 and data.cruise_height_m>=data.bounds.end.y+100,"Cruise clears solid roofs; decorative events are not silently solid")
	var raw:Array=data.compiled.triangles_raw[0].vertices[0]
	var body:=Vector3(Units.metres(float(raw[0])),Units.metres(float(raw[1])),Units.metres(float(raw[2])))
	check((profile.root_basis*data.triangles[0][0]).distance_to(body)<0.0005,"Root-local geometry reconstructs native BODY-fixed coordinates without an extra RY90 adapter")
	globe.radius=6371000;globe.latitude=profile.root_latitude;globe.longitude=profile.root_longitude
	var pad:Vector3=profile.pad_offset_local_m
	var start:=pad+Vector3.UP*40;var finish:=pad-Vector3.UP*40
	var native_hit:=Runtime.sweep(data,globe,start,finish,Vector3.ONE*2)
	var ground_face:Array=data.triangles[0]
	var floor_normal:Vector3=(ground_face[1]-ground_face[0]).cross(ground_face[2]-ground_face[0]).normalized()
	if floor_normal.y<0:floor_normal=-floor_normal
	var plane_time:float=(floor_normal.dot(start-ground_face[0])-2.0)/(80.0*floor_normal.y)
	check(not native_hit.is_empty() and absf(float(native_hit.time)-plane_time)<0.00002 and native_hit.normal.dot(floor_normal)>0.9999,"Native F650 pad CCD contacts the actual source city plane")
	var floor_y:float=ground_face[0].y-(floor_normal.x*(pad.x-ground_face[0].x)+floor_normal.z*(pad.z-ground_face[0].z))/floor_normal.y
	check(absf(pad.y-floor_y)>0.1,"F650 pre-shift Q31 rounding is not silently assumed to lie on the high-precision solid floor")
	check(not Runtime.overlaps(data,globe,native_hit.position+native_hit.normal*0.01,Vector3.ONE*2),"Native pad separated contact is clear for touchdown/restore")
	globe.latitude+=500/globe.radius;globe.longitude+=700/(globe.radius*cos(globe.latitude))
	transform=Runtime.transform_to_frame(profile,globe)
	var rebased:=Runtime.sweep(data,globe,transform*start,transform*finish,Vector3.ONE*2)
	check(not rebased.is_empty() and absf(float(rebased.time)-float(native_hit.time))<0.0001,"Collision time survives a real 860m geographic rebase")
	check(rebased.position.distance_to(transform*native_hit.position)<0.003 and rebased.normal.dot((transform.basis*native_hit.normal).normalized())>0.9999,"Rebased contact center and normal stay in active flight axes")
	var changed:=profile.duplicate(true);changed.root_elevation_m=7.25;changed.site_id="current-copy"
	var second:=Runtime.prepare(changed)
	check(Runtime.cache_size()==1 and second.profile.site_id=="current-copy" and second.profile.root_elevation_m==7.25 and data.profile.root_elevation_m==0,"Geometry cache hit returns fresh current placement metadata")
	var invalid:=profile.duplicate(true);invalid.root_basis=Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
	check(not Runtime.prepare(invalid).ok and Runtime.cache_size()==1,"Invalid placement is rejected without cache mutation")
	for i in range(9):
		var next:=profile.duplicate(true);next.key=str(profile.key)+":cache-control:"+str(i)
		check(Runtime.prepare(next).ok,"Bounded cache controls remain real original city geometry")
	check(Runtime.cache_size()==Runtime.CACHE_LIMIT,"City data cache is bounded to eight entries")
	Runtime.clear_cache()
	check(Runtime.cache_size()==0,"Cache releases only data dictionaries without a retained runtime instance")
	print("SOURCE CITY RUNTIME TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
