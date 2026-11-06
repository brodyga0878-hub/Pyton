extends RefCounted
# Bounded modern global LOD, sampling exactly the surface v4 elevation policy.
# Scene nodes / mesh resources are created only by the renderer on its thread.
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const REVISION:="source-height-global-lod-v1"
const SAMPLE_COLUMNS:=24
const SAMPLE_ROWS:=12
const RENDER_COLUMNS:=64
const RENDER_ROWS:=32
class InputWorld extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=0
class Cancellation extends RefCounted:
	var _mutex:=Mutex.new()
	var _cancelled:=false
	func cancel()->void:_mutex.lock();_cancelled=true;_mutex.unlock()
	func cancelled()->bool:_mutex.lock();var value:=_cancelled;_mutex.unlock();return value

static func key(snapshot:Dictionary)->String:
	return JSON.stringify([REVISION,Terrain.REVISION_NAME,Terrain.SAMPLE_POLICY,snapshot.get("system_id"),snapshot.get("body",{}),snapshot.get("settlements",[])]).sha256_text()

static func snapshot(system:RefCounted,body_id:String)->Dictionary:
	if system==null or not system.get("by_id") is Dictionary or not system.by_id.has(body_id):return {}
	var body:Dictionary=system.by_id[body_id]
	if not body.get("landable",false) or not Terrain.supported_model(str(body.get("runtime_record_hex","")).hex_decode()):return {}
	var sites:Array=[]
	for site:Dictionary in system.settlements:
		if str(site.get("parent",""))==body_id and int(site.get("type_code",-1))==35:sites.append(site.duplicate(true))
	return {"system_id":int(system.system_id),"body":body.duplicate(true),"settlements":sites}

static func _height(nodes:PackedFloat64Array,x:float,y:float)->float:
	x=clampf(x,0,SAMPLE_COLUMNS);y=clampf(y,0,SAMPLE_ROWS)
	var ix:=mini(SAMPLE_COLUMNS-1,floori(x));var iy:=mini(SAMPLE_ROWS-1,floori(y))
	var a:=iy*(SAMPLE_COLUMNS+1)+ix;var b:=a+SAMPLE_COLUMNS+1
	return lerpf(lerpf(nodes[a],nodes[a+1],x-ix),lerpf(nodes[b],nodes[b+1],x-ix),y-iy)

static func build(input:Dictionary,cancellation:Cancellation=null)->Dictionary:
	if cancellation!=null and cancellation.cancelled():return {"ok":false,"cancelled":true}
	var body:Dictionary=input.get("body",{})
	if body.is_empty() or not input.get("settlements") is Array or not input.get("system_id") is int:return {"ok":false,"error":"Invalid immutable source body snapshot"}
	if not body.get("id") is String or not body.get("landable",false):return {"ok":false,"error":"Body is outside original landable domain"}
	var system:=InputWorld.new();system.system_id=int(input.system_id);system.by_id={str(body.id):body.duplicate(true)};system.settlements=input.settlements.duplicate(true)
	var terrain:=Terrain.new();terrain.configure(system,str(body.id),"",Terrain.REVISION_NAME)
	if not terrain.configured_ok:return {"ok":false,"error":terrain.configuration_error}
	var radius:=float(terrain.radius);var nodes:=PackedFloat64Array();nodes.resize((SAMPLE_COLUMNS+1)*(SAMPLE_ROWS+1))
	for y in range(SAMPLE_ROWS+1):
		for x in range(SAMPLE_COLUMNS+1):
			if cancellation!=null and cancellation.cancelled():return {"ok":false,"cancelled":true}
			var at:=y*(SAMPLE_COLUMNS+1)+x
			if x==SAMPLE_COLUMNS:nodes[at]=nodes[y*(SAMPLE_COLUMNS+1)];continue
			if (y==0 or y==SAMPLE_ROWS) and x>0:nodes[at]=nodes[y*(SAMPLE_COLUMNS+1)];continue
			var lat:=-PI*0.5+PI*float(y)/SAMPLE_ROWS;var lon:=-PI+TAU*float(x)/SAMPLE_COLUMNS
			var height:=terrain.elevation(lat,lon)
			if not is_finite(height) or radius+height<=0:return {"ok":false,"error":"Original source height did not produce a finite exterior surface"}
			nodes[at]=height
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
	for y in range(RENDER_ROWS+1):
		var lat:=-PI*0.5+PI*float(y)/RENDER_ROWS
		for x in range(RENDER_COLUMNS+1):
			var lon:=-PI+TAU*float(x)/RENDER_COLUMNS
			var height:=_height(nodes,float(x)*SAMPLE_COLUMNS/RENDER_COLUMNS,float(y)*SAMPLE_ROWS/RENDER_ROWS)
			var direction:=Vector3(cos(lat)*cos(lon),sin(lat),-cos(lat)*sin(lon))
			vertices.append(vertices[y*(RENDER_COLUMNS+1)] if x==RENDER_COLUMNS else direction*(1.0+height/radius))
			uv.append(Vector2(float(x)/RENDER_COLUMNS,1.0-float(y)/RENDER_ROWS))
	for y in range(RENDER_ROWS+1):
		for x in range(RENDER_COLUMNS+1):
			var at:=y*(RENDER_COLUMNS+1)+x;var around:=x%RENDER_COLUMNS
			var across:Vector3=vertices[y*(RENDER_COLUMNS+1)+posmod(around+1,RENDER_COLUMNS)]-vertices[y*(RENDER_COLUMNS+1)+posmod(around-1,RENDER_COLUMNS)]
			var north:Vector3=vertices[mini(y+1,RENDER_ROWS)*(RENDER_COLUMNS+1)+around]-vertices[maxi(y-1,0)*(RENDER_COLUMNS+1)+around]
			var normal:=across.cross(north).normalized()
			if normal.length_squared()<0.5:normal=vertices[at].normalized()
			if normal.dot(vertices[at])<0:normal=-normal
			normals.append(normal)
	for y in range(RENDER_ROWS):
		for x in range(RENDER_COLUMNS):
			var a:=y*(RENDER_COLUMNS+1)+x;var b:=a+1;var c:=a+RENDER_COLUMNS+1;var d:=c+1
			indices.append_array(PackedInt32Array([a,c,b,b,c,d])) # Godot clockwise exterior winding.
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	return {"ok":true,"revision":REVISION,"key":key(input),"body_id":str(body.id),"record_hex":terrain.source_record.hex_encode(),"height_policy":Terrain.SAMPLE_POLICY,"source_policy":terrain.source_policy.duplicate(true),"radius_m":radius,"sample_columns":SAMPLE_COLUMNS,"sample_rows":SAMPLE_ROWS,"sample_nodes":nodes,"render_columns":RENDER_COLUMNS,"render_rows":RENDER_ROWS,"arrays":arrays,"source_stats":terrain.cache_stats(),"sampled_global_lod":true,"original_adaptive_renderer":false}
