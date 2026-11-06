extends SceneTree
const State=preload("res://scripts/source_surface_render_state.gd")
const Packet=preload("res://scripts/source_surface_render_packet.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
class Globe extends RefCounted:
	var revision:="sphere-source-ground-v4"
	var configured_ok:=true
	var source_record:=PackedByteArray()
	var latitude:=0.31
	var longitude:=0.47
	var radius:=7049700.0
	var bias:=0.0
	var calls:=0
	func _init()->void:source_record.resize(68);source_record[0]=1;source_record[12]=120
	func sample(x:float,z:float)->PackedFloat64Array:
		calls+=1
		var height:=bias+13+0.02*x-0.03*z+80*sin(x/700.0)*cos(z/900.0)
		return PackedFloat64Array([height,height,x,radius+height,-z])
	func cache_stats()->Dictionary:return {"source_samples":0,"entries":0}
	func maximum_patch_extent()->float:return radius*0.45
class NativeSystem extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=44341016
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func packet_for(globe:RefCounted,cells:=8,offset:=Vector2.ZERO)->Dictionary:
	return Packet.prepare(globe,{"core_width":4000.0,"core_cells":cells,"far_along":4,"far_radial":1,"include_rings":false,"core_offset":offset,"source_key":"independent-published-core"})
func brute(packet:Dictionary,transform:Transform3D,x:float,z:float)->Dictionary:
	# Independent oracle: transform every published triangle into the CURRENT
	# renderer frame, then solve the vertical triangle intersection directly.
	var core:Dictionary=packet.meshes[0];var best:Dictionary={}
	for index in range(0,core.indices.size(),3):
		var a:Vector3=transform*core.vertices[core.indices[index]];var b:Vector3=transform*core.vertices[core.indices[index+1]];var c:Vector3=transform*core.vertices[core.indices[index+2]]
		var bx:=float(b.x)-a.x;var bz:=float(b.z)-a.z;var cx:=float(c.x)-a.x;var cz:=float(c.z)-a.z
		var denominator:=bx*cz-bz*cx
		if absf(denominator)<1e-12:continue
		var dx:=x-float(a.x);var dz:=z-float(a.z)
		var u:=(dx*cz-dz*cx)/denominator;var v:=(bx*dz-bz*dx)/denominator
		if u<(-1e-7) or v<(-1e-7) or u+v>1.0000001:continue
		var height:=float(a.y)+u*(float(b.y)-a.y)+v*(float(c.y)-a.y)
		if best.is_empty() or height>float(best.height):best={"height":height,"triangle_index":index/3}
	return best

func identity_and_validation()->void:
	var globe:=Globe.new();var packet:=packet_for(globe,8,Vector2(750,-500));var state:=State.new()
	check(Packet.valid(packet) and state.configure(packet) and state.configured_ok,"Valid immutable offset core configures published render state")
	check(state.matches(globe) and state.transform_to(globe)==Transform3D.IDENTITY,"Same published source frame is exact identity")
	var calls:=globe.calls
	for point in [Vector2(750,-500),Vector2(-1100,-2200),Vector2(2500,1200),Vector2(-1250,-2500),Vector2(2750,1500)]:
		var actual:=state.height_at(globe,point.x,point.y);var expected:=brute(packet,Transform3D.IDENTITY,point.x,point.y)
		check(not actual.is_empty() and not expected.is_empty() and absf(float(actual.height)-float(expected.height))<0.000001,"Core vertical query follows actual published diagonal, including boundaries/offset")
	check(globe.calls==calls,"Published height lookup makes no SourceTerrain/native sampling call")
	for point in [Vector2(-1250.01,0),Vector2(2750.01,0),Vector2(0,-2500.01),Vector2(0,1500.01),Vector2(INF,0),Vector2(0,NAN)]:check(state.height_at(globe,point.x,point.y).is_empty(),"Outside/nonfinite core query falls back explicitly")
	var reference:Dictionary=state.height_at(globe,750,-500)
	for mutation in ["topology","coordinate","domain","revision","record","nan_frame","offset","cells","typed_domain","typed_role"]:
		var bad:=packet.duplicate(true)
		if mutation=="topology":bad.meshes[0].indices[0]=1
		elif mutation=="coordinate":bad.meshes[0].vertices[0]=bad.meshes[0].vertices[0]+Vector3(1,0,0)
		elif mutation=="domain":bad.frame.record_domain="template_record"
		elif mutation=="revision":bad.frame.terrain_revision="sphere-v1"
		elif mutation=="record":bad.frame.record_hash="bad"
		elif mutation=="nan_frame":bad.frame.latitude=NAN
		elif mutation=="offset":bad.core_offset=Vector2.ZERO
		elif mutation=="cells":bad.core_cells=9
		elif mutation=="typed_domain":bad.frame.record_domain=17
		elif mutation=="typed_role":bad.meshes[0].role=17
		check(not state.configure(bad) and state.configured_ok and state.height_at(globe,750,-500)==reference,"Bad replacement preserves live physical/render pair atomically: "+mutation)
	packet.meshes[0].vertices[40]=Vector3(750,9999,-500)
	check(state.height_at(globe,750,-500)==reference,"Caller mutation cannot alias state-owned core vertices")
	var changed:=Globe.new();changed.source_record[4]=17
	check(not state.matches(changed) and not state.transform_to(changed).is_finite() and state.height_at(changed,0,0).is_empty(),"Foreign source record never reuses old-body core")
	changed=Globe.new();changed.radius+=1
	check(not state.matches(changed) and state.height_at(changed,0,0).is_empty(),"Different canonical body radius rejects stale packet")
	check(state.height_at(null,0,0).is_empty() and not state.transform_to(null).is_finite(),"Null lifecycle has explicit no-hit/nonfinite transform sentinel")
	state.clear();state.clear();check(not state.configured_ok and state.height_at(globe,0,0).is_empty(),"Repeated clear removes published height authority safely")

func rebase_controls()->void:
	for radius in [10000.0,744834.375,7049700.0,1e12]:
		var globe:=Globe.new();globe.radius=radius;globe.bias=-radius*0.8 if radius<100000 else (-200000.0 if radius<1000000 else 0.0)
		var packet:=packet_for(globe,8,Vector2(1250,500));var state:=State.new();check(state.configure(packet),"Source-like depth packet configures radius "+str(radius))
		var original_lat:=globe.latitude;var original_lon:=globe.longitude
		globe.latitude+=600.0/radius;globe.longitude+=512.0/(radius*cos(original_lat))
		var transform:=state.transform_to(globe)
		check(transform.is_finite() and absf(transform.basis.determinant()-1.0)<0.000001,"Published core retains rigid source frame after600m/512m rebase")
		if radius==1e12:check(transform.origin.length()>700 and transform.origin.length()<850,"Scalar R*unit difference preserves subkilometre frame translation at trillion-metre reference")
		for point in [Vector2(0,0),Vector2(400,300),Vector2(1000,-200),Vector2(1800,700),Vector2(-500,-700)]:
			var actual:=state.height_at(globe,point.x,point.y);var expected:=brute(packet,transform,point.x,point.y)
			check(actual.is_empty()==expected.is_empty(),"Rebased packet vertical ray agrees with independent transformed triangle coverage")
			if not actual.is_empty():check(absf(float(actual.height)-float(expected.height))<0.08 and actual.normal.is_finite() and actual.normal.y>0,"Rebased height/normal intersects actual retained rendered triangles")
		check(globe.latitude!=original_lat or globe.longitude!=original_lon,"Rebase control actually changed the geographic anchor")
	var globe:=Globe.new();var packet:=packet_for(globe,64);var state:=State.new();check(state.configure(packet),"Production4000m/64-cell core configures")
	globe.latitude+=512.0/globe.radius;globe.longitude+=600.0/(globe.radius*cos(globe.latitude));var calls:=globe.calls
	for index in range(1000):
		var x:=float((index*73)%2400)-1200;var z:=float((index*101)%2400)-1200
		check(not state.height_at(globe,x,z).is_empty(),"Production retained mesh core responds inside stable rebase neighbourhood")
	var stats:=state.stats()
	check(globe.calls==calls and stats.maximum_cells<=4 and stats.last_triangles<=8 and stats.cell_budget==130,"Normal512m rebase uses bounded few-cell DDA, never scans8192triangles or samples sourcefield")
	# Non-power-of-two spacing becomes slightly nonuniform when actually stored
	# as Float32 vertices; DDA must use those published boundaries too.
	globe=Globe.new();packet=Packet.prepare(globe,{"core_width":4000.3,"core_cells":7,"far_along":4,"far_radial":1,"include_rings":false,"core_offset":Vector2(813.25,-112.75),"source_key":"rounded-published-grid"});state=State.new()
	check(state.configure(packet),"Validated rounded seven-cell offset lattice configures")
	globe.latitude+=600.0/globe.radius;var transform:=state.transform_to(globe)
	for index in [1,5,9,17,25,32,46,54,62]:
		var point:Vector3=transform*packet.meshes[0].vertices[index]
		var actual:=state.height_at(globe,point.x,point.z);var expected:=brute(packet,transform,point.x,point.z)
		check(actual.is_empty()==expected.is_empty(),"Rounded published grid-line hit has matching exact triangle coverage")
		if not actual.is_empty():check(absf(float(actual.height)-float(expected.height))<0.001,"Rounded grid DDA follows actual Float32 vertex planes")

func native117_control()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"));var record:=PackedByteArray()
	for row:Dictionary in fixture.cases:
		if int(row.parent_model)==117:record=str(row.parent_record_hex).hex_decode();break
	var system:=NativeSystem.new();system.by_id.body={"runtime_record_hex":record.hex_encode(),"radius_km":1.0}
	var globe:=Terrain.new();globe.configure(system,"body","");globe.latitude=-PI/8;globe.longitude=PI/2
	var packet:=packet_for(globe,8);var state:=State.new();check(state.configure(packet),"Actual independent native117record prepares published source core")
	globe.latitude+=600.0/globe.radius;globe.longitude+=512.0/(globe.radius*cos(globe.latitude));var before:=globe.cache_stats();var transform:=state.transform_to(globe)
	for point in [Vector2.ZERO,Vector2(300,-400),Vector2(-600,700)]:
		var actual:=state.height_at(globe,point.x,point.y);var expected:=brute(packet,transform,point.x,point.y)
		check(not actual.is_empty() and not expected.is_empty() and absf(float(actual.height)-float(expected.height))<0.08,"Actual deep117retained-render height stays on published physical triangles afterrebase")
	check(globe.cache_stats()==before,"Actual117retained geometry lookup performs zero additional native height queries")

func run()->void:
	identity_and_validation();rebase_controls();native117_control()
	print("SOURCE SURFACE RENDER STATE TESTS: ",checks," checks, ",failures," failures; publishedCORE, exactdiagonal, scalarrebase, boundedDDA, native117")
	quit(1 if failures else 0)
