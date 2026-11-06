extends RefCounted
# CPU-only v4 geometry preparation. The caller gives this function its own
# SourceSurfaceTerrain instance; all SceneTree/GPU publication stays outside.
const REVISION:="source-surface-render-packet-v1"
const TERRAIN_REVISION:="sphere-source-ground-v4"
const KINDS:=["earth","ice","desert","rock"]
const MAX_VERTICES:=100000

static func _integer(value:Variant,minimum:int,maximum:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and int(value)>=minimum and int(value)<=maximum

static func _sha(bytes:PackedByteArray)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes)
	return context.finish().hex_encode()

static func _sample(globe:RefCounted,x:float,z:float,stats:Dictionary)->PackedFloat64Array:
	var sampled:Variant=globe.sample(x,z)
	stats.samples+=1
	if not sampled is PackedFloat64Array or sampled.size()!=5:return PackedFloat64Array()
	for component in sampled:
		if not is_finite(component):return PackedFloat64Array()
	return sampled

static func _geometry(name:String,role:String,inner:float,outer:float,vertices:PackedVector3Array,normals:PackedVector3Array,colors:PackedColorArray,uv:PackedVector2Array,uv2:PackedVector2Array,indices:PackedInt32Array)->Dictionary:
	var minimum:=vertices[0];var maximum:=minimum
	for point in vertices:
		minimum=minimum.min(point);maximum=maximum.max(point)
	return {"name":name,"role":role,"inner":inner,"outer":outer,"vertices":vertices,"normals":normals,"colors":colors,"uv":uv,"uv2":uv2,"indices":indices,"bounds":AABB(minimum,maximum-minimum)}

static func _core(globe:RefCounted,width:float,count:int,base:Color,stats:Dictionary,offset:Vector2)->Dictionary:
	var side:=count+3;var cell:=width/count
	var samples:Array[PackedFloat64Array]=[];samples.resize(side*side)
	for z in range(side):
		for x in range(side):
			var sampled:=_sample(globe,float(offset.x)-width/2.0+(x-1)*cell,float(offset.y)-width/2.0+(z-1)*cell,stats)
			if sampled.is_empty():return {}
			samples[z*side+x]=sampled
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray()
	var uv:=PackedVector2Array();var uv2:=PackedVector2Array();var indices:=PackedInt32Array()
	for z in range(count+1):
		for x in range(count+1):
			var index:=(z+1)*side+x+1
			var sampled:PackedFloat64Array=samples[index]
			var point:=Vector3(float(offset.x)-width/2.0+x*width/count,sampled[0],float(offset.y)-width/2.0+z*width/count)
			var dx:=(samples[index+1][0]-samples[index-1][0])/(2.0*cell)
			var dz:=(samples[index+side][0]-samples[index-side][0])/(2.0*cell)
			vertices.append(point);normals.append(Vector3(-dx,1.0,-dz).normalized())
			colors.append(base.lightened(clampf(point.y/400.0,-0.2,0.3)))
			uv.append(Vector2(sampled[2],sampled[3]));uv2.append(Vector2(sampled[4],0.0))
	for z in range(count):
		for x in range(count):
			var a:=z*(count+1)+x;var b:=a+1;var c:=a+count+1;var d:=c+1
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	return _geometry("SourceTerrainCore","core",0.0,width*0.5,vertices,normals,colors,uv,uv2,indices)

static func _ring_normals(vertices:PackedVector3Array,indices:PackedInt32Array)->PackedVector3Array:
	# Average the actual sampled triangle normals, including duplicate corner
	# vertices at adjacent ring sides. This makes no extra terrain query.
	var accumulated:Dictionary={}
	for index in range(0,indices.size(),3):
		var a:=vertices[indices[index]];var b:=vertices[indices[index+1]];var c:=vertices[indices[index+2]]
		var normal:=(b-a).cross(c-a)
		if normal.y<0.0:normal=-normal
		for vertex in [a,b,c]:
			var key:=Vector2(vertex.x,vertex.z)
			accumulated[key]=Vector3(accumulated.get(key,Vector3.ZERO))+normal
	var result:=PackedVector3Array()
	for point in vertices:
		var normal:Vector3=accumulated.get(Vector2(point.x,point.z),Vector3.UP)
		result.append(normal.normalized() if normal.length_squared()>1e-20 else Vector3.UP)
	return result

static func _ring(globe:RefCounted,inner:float,outer:float,along:int,radial:int,base:Color,extended:bool,stats:Dictionary)->Dictionary:
	var vertices:=PackedVector3Array();var colors:=PackedColorArray()
	var uv:=PackedVector2Array();var uv2:=PackedVector2Array();var indices:=PackedInt32Array()
	for side in range(4):
		var first:=vertices.size()
		for row in range(radial+1):
			var extent:=lerpf(inner,outer,float(row)/radial)
			for index in range(along+1):
				var t:=lerpf(-1.0,1.0,float(index)/along)
				var point:Vector2=[Vector2(t,-1),Vector2(1,t),Vector2(-t,1),Vector2(-1,-t)][side]*extent
				var sampled:=_sample(globe,point.x,point.y,stats)
				if sampled.is_empty():return {}
				vertices.append(Vector3(point.x,sampled[0],point.y))
				var shade:=clampf(sampled[1]/400.0,-0.2,0.3)
				if extended:shade*=1.0-smoothstep(4000.0,24000.0,point.length())
				colors.append(base.lightened(shade))
				uv.append(Vector2(sampled[2],sampled[3]));uv2.append(Vector2(sampled[4],0))
		for row in range(radial):
			for index in range(along):
				var a:=first+row*(along+1)+index;var b:=a+1;var c:=a+along+1;var d:=c+1
				indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	return _geometry("SourceDistantTerrain%d"%roundi(outer),"ring",inner,outer,vertices,_ring_normals(vertices,indices),colors,uv,uv2,indices)

static func prepare(globe:RefCounted,options:Dictionary={})->Dictionary:
	var started:=Time.get_ticks_usec()
	if globe==null or globe.get("revision")!=TERRAIN_REVISION or globe.get("configured_ok")!=true or not globe.get("source_record") is PackedByteArray or globe.source_record.size()!=68:return {"ok":false,"error":"A configured worker-owned source terrain is required"}
	var count_value:Variant=options.get("core_cells",64);var along_value:Variant=options.get("far_along",16);var radial_value:Variant=options.get("far_radial",2)
	var width_value:Variant=options.get("core_width",4000.0)
	if not _integer(count_value,2,128) or not _integer(along_value,4,64) or not _integer(radial_value,1,8) or not (width_value is int or width_value is float) or not is_finite(float(width_value)) or float(width_value)<64.0 or float(width_value)>65536.0:return {"ok":false,"error":"Invalid source render grid dimensions"}
	var kind:=str(options.get("kind","rock"))
	var offset:Variant=options.get("core_offset",Vector2.ZERO)
	if kind not in KINDS or not options.get("extended_flight",false) is bool or not options.get("include_rings",true) is bool or not offset is Vector2 or not offset.is_finite():return {"ok":false,"error":"Invalid source render material, flight flag or core offset"}
	var latitude:float=globe.latitude;var longitude:float=globe.longitude;var radius:float=globe.radius
	var maximum:float=globe.maximum_patch_extent()
	if not is_finite(latitude) or not is_finite(longitude) or absf(latitude)>PI*0.5 or not is_finite(radius) or radius<=0.0 or not is_finite(maximum) or maximum<=0.0:return {"ok":false,"error":"Invalid source render frame or extent"}
	var count:=int(count_value);var along:=int(along_value);var radial:=int(radial_value);var width:=float(width_value)
	var extended:=bool(options.get("extended_flight",false))
	var include_rings:=bool(options.get("include_rings",true))
	var before:Dictionary=globe.cache_stats();var stats:={"samples":0}
	var base:Color={"earth":Color("426b51"),"ice":Color("a5c5cf"),"desert":Color("aa714d"),"rock":Color("737984")}[kind]
	var meshes:Array[Dictionary]=[]
	var core:=_core(globe,width,count,base,stats,offset)
	if core.is_empty():return {"ok":false,"error":"Source core height query was not finite"}
	meshes.append(core)
	var inner:=width*0.5
	for outer in ([8000.0,32000.0,128000.0] if include_rings else []):
		var bound:=minf(float(outer),maximum)
		if bound<=inner:break
		var ring:=_ring(globe,inner,bound,along,radial,base,extended,stats)
		if ring.is_empty():return {"ok":false,"error":"Source ring height query was not finite"}
		meshes.append(ring);inner=bound
	if extended and include_rings:
		var outer:=minf(maximum,minf(512000.0,radius*0.7))
		if outer>inner:
			var ring:=_ring(globe,inner,outer,along,radial,base,extended,stats)
			if ring.is_empty():return {"ok":false,"error":"Source extended ring query was not finite"}
			meshes.append(ring)
	var origin:=_sample(globe,offset.x,offset.y,stats)
	if origin.is_empty():return {"ok":false,"error":"Source material origin query was not finite"}
	var after:Dictionary=globe.cache_stats()
	var result:={"ok":true,"revision":REVISION,"frame":{"latitude":latitude,"longitude":longitude,"radius":radius,"record_hash":_sha(globe.source_record),"terrain_revision":TERRAIN_REVISION,"record_domain":"f878_runtime_bank_with_unconverted_type35_fields"},"source_key":str(options.get("source_key","")),"meshes":meshes,"material_origin":Vector3(floor(origin[2]/1024.0)*1024.0,floor(origin[3]/1024.0)*1024.0,floor(origin[4]/1024.0)*1024.0),"kind":kind,"extended_flight":extended,"core_cells":count,"core_width":width,"core_offset":offset,"include_rings":include_rings,"far_along":along,"far_radial":radial,"sample_count":int(stats.samples),"source_query_count":int(after.get("source_samples",0))-int(before.get("source_samples",0)),"cache_stats_before":before,"cache_stats_after":after,"duration_usec":Time.get_ticks_usec()-started}
	return result if valid(result) else {"ok":false,"error":"Prepared source geometry failed finite/bounds validation"}

static func valid(packet:Dictionary)->bool:
	if packet.get("ok")!=true or packet.get("revision")!=REVISION or not packet.get("frame") is Dictionary or not packet.get("meshes") is Array or packet.meshes.size()<1 or packet.meshes.size()>5 or packet.get("kind") not in KINDS or not packet.get("material_origin") is Vector3 or not packet.material_origin.is_finite():return false
	if not _integer(packet.get("core_cells"),2,128) or not _integer(packet.get("far_along"),4,64) or not _integer(packet.get("far_radial"),1,8) or not (packet.get("core_width") is float or packet.get("core_width") is int) or not is_finite(float(packet.core_width)) or float(packet.core_width)<64.0 or float(packet.core_width)>65536.0 or not packet.get("extended_flight") is bool or not packet.get("source_key") is String or not _integer(packet.get("sample_count"),1,100000) or not _integer(packet.get("source_query_count"),0,1000000) or not packet.get("core_offset") is Vector2 or not packet.core_offset.is_finite() or not packet.get("include_rings") is bool:return false
	if not packet.include_rings and packet.meshes.size()!=1:return false
	var frame:Dictionary=packet.frame
	for key in ["latitude","longitude","radius"]:
		if not (frame.get(key) is int or frame.get(key) is float) or not is_finite(float(frame[key])):return false
	if absf(float(frame.latitude))>PI*0.5 or absf(float(frame.longitude))>PI+0.000001 or float(frame.radius)<=0.0 or not frame.get("record_hash") is String or frame.record_hash.length()!=64 or not frame.record_hash.is_valid_hex_number(false) or frame.get("terrain_revision")!=TERRAIN_REVISION or frame.get("record_domain")!="f878_runtime_bank_with_unconverted_type35_fields":return false
	var total:=0
	for mesh_index in range(packet.meshes.size()):
		var mesh:Variant=packet.meshes[mesh_index]
		if not mesh is Dictionary or not mesh.get("vertices") is PackedVector3Array or not mesh.get("normals") is PackedVector3Array or not mesh.get("colors") is PackedColorArray or not mesh.get("uv") is PackedVector2Array or not mesh.get("uv2") is PackedVector2Array or not mesh.get("indices") is PackedInt32Array or not mesh.get("bounds") is AABB:return false
		var count:int=mesh.vertices.size();total+=count
		if count<3 or total>MAX_VERTICES or mesh.normals.size()!=count or mesh.colors.size()!=count or mesh.uv.size()!=count or mesh.uv2.size()!=count or mesh.indices.size()<3 or mesh.indices.size()%3!=0:return false
		if not mesh.get("name") is String or mesh.get("role")!=("core" if mesh_index==0 else "ring") or not (mesh.get("inner") is float or mesh.get("inner") is int) or not (mesh.get("outer") is float or mesh.get("outer") is int) or not is_finite(float(mesh.inner)) or not is_finite(float(mesh.outer)) or float(mesh.inner)<0.0 or float(mesh.outer)<=float(mesh.inner):return false
		if mesh_index==0:
			var cells:=int(packet.core_cells)
			if count!=(cells+1)*(cells+1) or mesh.indices.size()!=cells*cells*6 or mesh.inner!=0.0 or absf(float(mesh.outer)-float(packet.core_width)*0.5)>1e-6:return false
			for z in range(cells):
				for x in range(cells):
					var start:=(z*cells+x)*6;var a:=z*(cells+1)+x
					var expected:=PackedInt32Array([a,a+1,a+cells+1,a+1,a+cells+2,a+cells+1])
					for offset in range(6):
						if mesh.indices[start+offset]!=expected[offset]:return false
		else:
			if count!=4*(int(packet.far_along)+1)*(int(packet.far_radial)+1) or mesh.indices.size()!=4*int(packet.far_along)*int(packet.far_radial)*6 or absf(float(mesh.inner)-float(packet.meshes[mesh_index-1].outer))>0.01:return false
		var bounds:AABB=mesh.bounds
		if not bounds.position.is_finite() or not bounds.size.is_finite() or minf(bounds.size.x,minf(bounds.size.y,bounds.size.z))<0.0:return false
		for index in range(count):
			var point:Vector3=mesh.vertices[index];var normal:Vector3=mesh.normals[index];var color:Color=mesh.colors[index]
			if not point.is_finite() or not normal.is_finite() or not mesh.uv[index].is_finite() or not mesh.uv2[index].is_finite() or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a) or absf(normal.length_squared()-1.0)>0.01:return false
			if point.x<bounds.position.x-0.1 or point.y<bounds.position.y-0.1 or point.z<bounds.position.z-0.1 or point.x>bounds.end.x+0.1 or point.y>bounds.end.y+0.1 or point.z>bounds.end.z+0.1:return false
			if mesh_index==0:
				var cells:=int(packet.core_cells);var width:=float(packet.core_width)
				if absf(float(point.x)-(float(packet.core_offset.x)-width*0.5+(index%(cells+1))*width/cells))>0.05 or absf(float(point.z)-(float(packet.core_offset.y)-width*0.5+floori(float(index)/(cells+1))*width/cells))>0.05:return false
		for index in mesh.indices:
			if index<0 or index>=count:return false
	return true
