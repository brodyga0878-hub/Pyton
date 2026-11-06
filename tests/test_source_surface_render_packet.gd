extends SceneTree
const Packet=preload("res://scripts/source_surface_render_packet.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const World=preload("res://scripts/planetary_system.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
class Probe extends RefCounted:
	var revision:="sphere-source-ground-v4"
	var configured_ok:=true
	var source_record:=PackedByteArray()
	var latitude:=0.31
	var longitude:=-0.42
	var radius:=7000000.0
	var calls:=32
	var extent:=1000000.0
	func _init()->void:source_record.resize(68)
	func sample(x:float,z:float)->PackedFloat64Array:
		calls+=1
		var height:=x*0.12-z*0.07+sin(x*0.0005)*10.0
		return PackedFloat64Array([height,height,1000000.0+x,2000000.0+height,3000000.0+z])
	func maximum_patch_extent()->float:return extent
	func cache_stats()->Dictionary:return {"source_samples":calls,"entries":0,"hits":0}
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func prepare_on_worker(globe:RefCounted,options:Dictionary)->Dictionary:
	var worker:=Thread.new();check(worker.start(Packet.prepare.bind(globe,options))==OK,"Worker starts CPU source render preparation")
	var result:Variant=worker.wait_to_finish()
	check(result is Dictionary,"Worker returns serializable CPU packet")
	return result if result is Dictionary else {}
func run()->void:
	var probe:=Probe.new()
	var packet:=prepare_on_worker(probe,{"kind":"earth","source_key":"synthetic-probe-only"})
	check(packet.get("ok",false) and Packet.valid(packet),"Default geometry packet passes complete finite/index validation")
	if not packet.get("ok",false):push_error(str(packet));quit(1);return
	check(packet.meshes.size()==4 and packet.core_cells==64 and packet.far_along==16 and packet.far_radial==2,"Default CPU packet uses64core and16x2farLOD")
	check(packet.meshes[0].vertices.size()==4225 and packet.meshes[0].indices.size()==24576,"Core topology matches rendered collision-grid diagonal")
	for index in range(1,4):check(packet.meshes[index].vertices.size()==204 and packet.meshes[index].indices.size()==768,"Distant source ring has bounded204vertices")
	check(packet.sample_count==5102 and packet.source_query_count==5102 and packet.cache_stats_before.source_samples==32,"Packet reports actual samples and source query delta")
	check(packet.frame.latitude==probe.latitude and packet.frame.longitude==probe.longitude and packet.frame.radius==probe.radius and packet.source_key=="synthetic-probe-only","Packet identifies exact source frame and caller stamp")
	check(packet.material_origin==Vector3(999424,1999872,2999296),"Material origin remains1024m aligned body-fixed phase")
	for index in [0,32,145,2048,4224]:
		var point:Vector3=packet.meshes[0].vertices[index]
		var expected:=probe.sample(point.x,point.z)
		check(point.y==Vector3(0,expected[0],0).y,"Core vertex comes from supplied source sampler")
		var cell:float=packet.core_width/packet.core_cells
		var dx:float=(probe.sample(point.x+cell,point.z)[0]-probe.sample(point.x-cell,point.z)[0])/(2.0*cell)
		var dz:float=(probe.sample(point.x,point.z+cell)[0]-probe.sample(point.x,point.z-cell)[0])/(2.0*cell)
		check(Vector3(packet.meshes[0].normals[index]).distance_to(Vector3(-dx,1,-dz).normalized())<1e-6,"Core normal uses real central source height differences")
		check(packet.meshes[0].uv[index]==Vector2(expected[2],expected[3]) and packet.meshes[0].uv2[index]==Vector2(expected[4],0),"Body material coordinates copied from same sample")
	var extended:=Packet.prepare(Probe.new(),{"core_cells":8,"far_along":4,"extended_flight":true})
	check(Packet.valid(extended) and extended.meshes.size()==5 and extended.meshes[4].outer==512000.0,"Extended flight adds bounded source ring")
	var capped:=Probe.new();capped.extent=12000.0
	var capped_packet:=Packet.prepare(capped,{"core_cells":8,"far_along":4,"extended_flight":true})
	check(Packet.valid(capped_packet) and capped_packet.meshes.size()==3 and capped_packet.meshes[2].outer==12000.0,"Local source horizon cap prevents oversized far rings")
	var streamed:=Packet.prepare(Probe.new(),{"core_offset":Vector2(125.0,-62.5),"include_rings":false})
	check(Packet.valid(streamed) and streamed.meshes.size()==1 and streamed.core_offset==Vector2(125.0,-62.5) and streamed.sample_count==4490,"Core-only stream uses offset regional coordinates without newfar rings")
	check(streamed.meshes[0].vertices[0].x==-1875.0 and streamed.meshes[0].vertices[0].z==-2062.5,"Streamed grid vertices retain the regional frame")
	for row in range(1,65):
		for column in range(63):
			var old_index:=(row-1)*65+column+2;var new_index:=row*65+column
			check(streamed.meshes[0].vertices[new_index]==packet.meshes[0].vertices[old_index] and streamed.meshes[0].normals[new_index]==packet.meshes[0].normals[old_index],"Cell-aligned streamed overlap has identical sampled geometry")
	corruption_controls(packet)
	native_controls()
	if "--render-packet-benchmark" in OS.get_cmdline_user_args():native_benchmark()
	print("SOURCE SURFACE RENDER PACKET TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func corruption_controls(packet:Dictionary)->void:
	var bad:=packet.duplicate(true);var vertices:PackedVector3Array=bad.meshes[0].vertices
	vertices[0]=Vector3(NAN,0,0);bad.meshes[0].vertices=vertices
	check(not Packet.valid(bad),"Reject nonfinite render vertex")
	bad=packet.duplicate(true);var indices:PackedInt32Array=bad.meshes[0].indices;indices[0]=999999;bad.meshes[0].indices=indices
	check(not Packet.valid(bad),"Reject out-of-bounds render index")
	bad=packet.duplicate(true);bad.core_cells=8;check(not Packet.valid(bad),"Reject metadata/grid topology mismatch")
	bad=packet.duplicate(true);bad.frame.record_hash="x".repeat(64);check(not Packet.valid(bad),"Reject malformed source record fingerprint")
	bad=packet.duplicate(true);bad.meshes[0].bounds=AABB(Vector3.ZERO,Vector3.ONE);check(not Packet.valid(bad),"Reject false mesh bounds")
	bad=packet.duplicate(true);var normals:PackedVector3Array=bad.meshes[0].normals;normals[0]=Vector3.ZERO;bad.meshes[0].normals=normals
	check(not Packet.valid(bad),"Reject degenerate render normal")
	check(not Packet.prepare(Probe.new(),{"core_cells":0}).get("ok",false) and not Packet.prepare(Probe.new(),{"core_width":NAN}).get("ok",false),"Reject invalid render job dimensions")
	var legacy:=Probe.new();legacy.revision="sphere-v1"
	check(not Packet.prepare(legacy).get("ok",false),"Legacy sphere cannot enter v4 render packet path")
func native_globe(model:int)->RefCounted:
	var world:=World.new();world.configure(Galaxy.new().get_system(Galaxy.SOL_ID),World.FULL_LAYOUT)
	var selected:Dictionary={};var site_id:=""
	for body:Dictionary in world.bodies:
		if int(body.model_index)==model and body.get("landable",false):selected=body;break
	if selected.is_empty():return null
	world.focus_id=str(selected.id)
	if model==129:
		for site:Dictionary in world.settlements:
			if str(site.parent)==world.focus_id and int(site.model_index)==84:site_id=str(site.id);break
	var globe:=Terrain.new();globe.configure(world,world.focus_id,site_id)
	return globe if globe.configured_ok else null
func native_controls()->void:
	for model in [129,117]:
		var globe:=native_globe(model)
		check(globe!=null,"Native Sol source render body exists "+str(model))
		if globe==null:continue
		var packet:=prepare_on_worker(globe,{"core_cells":8,"far_along":4,"kind":"earth" if model==129 else "rock"})
		check(packet.get("ok",false) and Packet.valid(packet),"Actual source Earth/Hyperion render packet finite "+str(model))
		if not packet.get("ok",false):push_error(str(packet));continue
		for index in [0,4,40,80]:
			var point:Vector3=packet.meshes[0].vertices[index]
			var expected:PackedFloat64Array=globe.sample(point.x,point.z)
			check(point.y==Vector3(0,expected[0],0).y,"Published core vertex equals actual source height "+str(model))
		check(packet.frame.radius==globe.radius and packet.source_query_count>=0 and packet.sample_count<=302,"Native packet bounded source sampling and exact frame metadata "+str(model))
		var streamed:=prepare_on_worker(globe,{"core_cells":8,"far_along":4,"core_offset":Vector2(500,-500),"include_rings":false})
		check(Packet.valid(streamed) and streamed.meshes.size()==1 and streamed.frame==packet.frame,"Native source stream retains exact regional frame "+str(model))
		if not streamed.get("ok",false):continue
		for row in range(1,9):
			for column in range(8):
				check(streamed.meshes[0].vertices[row*9+column]==packet.meshes[0].vertices[(row-1)*9+column+1],"Native cell-aligned source overlap is bit-identical "+str(model))
func native_benchmark()->void:
	for model in [129,117]:
		var globe:=native_globe(model)
		if globe==null:continue
		var packet:=prepare_on_worker(globe,{"kind":"earth" if model==129 else "rock"})
		check(packet.get("ok",false) and Packet.valid(packet),"Default native CPU packet benchmark "+str(model))
		print("SOURCE RENDER BENCHMARK model=%d duration_ms=%.3f samples=%d source_queries=%d vertices=%d"%[model,float(packet.get("duration_usec",0))/1000.0,int(packet.get("sample_count",0)),int(packet.get("source_query_count",0)),packet.meshes[0].vertices.size() if packet.get("ok",false) else 0])
		for offset in [Vector2(62.5,0.0),Vector2(125.0,0.0)]:
			var streamed:=prepare_on_worker(globe,{"kind":"earth" if model==129 else "rock","core_offset":offset,"include_rings":false})
			check(streamed.get("ok",false) and Packet.valid(streamed),"Warm regional source core benchmark "+str(model))
			print("SOURCE CORE STREAM BENCHMARK model=%d offset_x=%.1f duration_ms=%.3f samples=%d source_queries=%d"%[model,offset.x,float(streamed.get("duration_usec",0))/1000.0,int(streamed.get("sample_count",0)),int(streamed.get("source_query_count",0))])
