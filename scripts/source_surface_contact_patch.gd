extends RefCounted
# A verified saved contact triangle, not an unverified AGL correction. Only
# three original surface vertices are serialized/recomputed; no mesh is saved.
const Frame=preload("res://scripts/source_surface_render_state.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const REVISION:="source-surface-contact-triangle-v1"
const CONTACT_TERRAIN_REVISION:="sphere-source-contact-v5"
const CONTACT_HEIGHT_POLICY:="signed-f581-contact-root-grid-v1"
var configured_ok:=false
var source_key:=""
var core_width:=0.0
var core_cells:=0
var core_offset:=Vector2.ZERO
var validation_samples:=0
var _patch:Dictionary={}
var _frame:Dictionary={}
var _points:Array[Vector3]=[]
var _record:=PackedByteArray()
var _target_lat:=INF
var _target_lon:=INF
var _transform:=Transform3D.IDENTITY
var _inverse:=PackedFloat64Array()

static func _terrain_policy(terrain_revision:Variant)->String:
	if terrain_revision==Terrain.REVISION_NAME:return Terrain.SAMPLE_POLICY
	if terrain_revision==CONTACT_TERRAIN_REVISION:return CONTACT_HEIGHT_POLICY
	return ""

static func _clone_terrain(globe:RefCounted)->RefCounted:
	if globe.revision==Terrain.REVISION_NAME:return Terrain.from_worker_state(globe.capture_worker_state())
	if globe.revision==CONTACT_TERRAIN_REVISION:
		var script:Script=load("res://scripts/source_contact_surface_terrain.gd")
		return script.from_worker_state(globe.capture_worker_state()) if script!=null else null
	return null

static func _profile(model:int,width:float,cells:int)->String:
	if width==4000.0 and cells==64:return "source-mobile-core-4000-64-v1"
	if model==117 and width==8000.0 and cells in [32,64]:return "source-mobile117-core-8000-%d-v1"%cells
	return ""

static func _plain(value:Variant,depth:=0)->bool:
	if depth>12:return false
	if value is Dictionary:
		for key in value:
			if not key is String or not _plain(value[key],depth+1):return false
		return true
	if value is Array:
		for item in value:
			if not _plain(item,depth+1):return false
		return true
	return value is String or value is bool or value==null or Frame._number(value)

static func _canonical(value:Dictionary)->Dictionary:
	if not _plain(value) or not value.get("revision") is String or not value.get("terrain_policy") is String:return {}
	for key in value:
		if key not in ["revision","terrain_policy","profile","model_index","frame","grid","vertices","checksum"]:return {}
	if value.get("revision")!=REVISION or not value.get("profile") is String or not Frame._integer(value.get("model_index"),117,133) or not value.get("frame") is Dictionary or not value.get("grid") is Dictionary:return {}
	var f:Dictionary=value.frame;var g:Dictionary=value.grid
	var policy:=_terrain_policy(f.get("terrain_revision"))
	if policy.is_empty() or value.terrain_policy!=policy:return {}
	for key in ["latitude","longitude","radius"]:
		if not Frame._number(f.get(key)):return {}
	if f.size()!=6 or not f.get("terrain_revision") is String or not f.get("record_domain") is String or absf(float(f.latitude))>PI*0.5 or absf(float(f.longitude))>PI+0.000001 or float(f.radius)<=0 or f.get("record_domain")!=Frame.RECORD_DOMAIN or not f.get("record_hash") is String or f.record_hash.length()!=64 or not f.record_hash.is_valid_hex_number(false):return {}
	if g.size()!=5 or not Frame._number(g.get("width")) or not Frame._integer(g.get("cells"),2,128) or not g.get("offset") is Array or g.offset.size()!=2 or not g.get("cell") is Array or g.cell.size()!=2 or not Frame._integer(g.get("triangle"),0,1):return {}
	for number in g.offset:
		if not Frame._number(number):return {}
	for number in g.cell:
		if not Frame._integer(number,0,int(g.cells)-1):return {}
	var width:=float(g.width);var cells:=int(g.cells);var model:=int(value.model_index);var profile:=_profile(model,width,cells)
	if profile.is_empty() or profile!=str(value.profile):return {}
	var step:=width/cells
	for number in g.offset:
		if absf(float(number)/step-roundf(float(number)/step))>1e-8:return {}
	if not value.get("vertices") is Array or value.vertices.size()!=3:return {}
	var vertices:Array=[]
	var ix:=int(g.cell[0]);var iz:=int(g.cell[1]);var which:=int(g.triangle)
	var corners:Array=[[ix,iz],[ix+1,iz],[ix,iz+1]] if which==0 else [[ix+1,iz],[ix+1,iz+1],[ix,iz+1]]
	for index in range(3):
		var point:Variant=value.vertices[index]
		if not point is Array or point.size()!=3:return {}
		for coordinate in point:
			if not Frame._number(coordinate):return {}
		var expected:=Vector3(float(g.offset[0])-width*0.5+int(corners[index][0])*step,0,float(g.offset[1])-width*0.5+int(corners[index][1])*step)
		var stored:=Vector3(float(point[0]),float(point[1]),float(point[2]))
		if not stored.is_finite() or float(point[0])!=float(expected.x) or float(point[2])!=float(expected.z) or float(point[1])!=float(stored.y):return {}
		vertices.append([float(stored.x),float(stored.y),float(stored.z)])
	return {"revision":REVISION,"profile":profile,"model_index":model,"terrain_policy":policy,"frame":{"latitude":float(f.latitude),"longitude":float(f.longitude),"radius":float(f.radius),"record_hash":str(f.record_hash).to_lower(),"terrain_revision":str(f.terrain_revision),"record_domain":Frame.RECORD_DOMAIN},"grid":{"width":width,"cells":cells,"offset":[float(g.offset[0]),float(g.offset[1])],"cell":[ix,iz],"triangle":which},"vertices":vertices}

static func checksum_for(value:Dictionary)->String:
	# Corruption detection, not authentication. Source-height reconstruction is
	# the authority even if an editor recalculates this public checksum.
	var p:=_canonical(value)
	if p.is_empty():return ""
	var f:Dictionary=p.frame;var g:Dictionary=p.grid
	return JSON.stringify([p.revision,p.profile,p.model_index,p.terrain_policy,[f.latitude,f.longitude,f.radius,f.record_hash,f.terrain_revision,f.record_domain],[g.width,g.cells,g.offset,g.cell,g.triangle],p.vertices]).sha256_text()

static func seal_capture(frame:Dictionary,width:float,cells:int,offset:Vector2,cell:Vector2i,which:int,points:Array,globe:RefCounted)->Dictionary:
	if globe==null or not globe.get("source_record") is PackedByteArray or globe.source_record.size()!=68 or points.size()!=3:return {}
	var model:=int(globe.source_record.decode_u16(12));var profile:=_profile(model,width,cells)
	if profile.is_empty():return {}
	var vertices:Array=[]
	for point:Variant in points:
		if not point is Vector3 or not point.is_finite():return {}
		vertices.append([float(point.x),float(point.y),float(point.z)])
	var policy:=_terrain_policy(globe.get("revision"))
	if policy.is_empty() or frame.get("terrain_revision")!=globe.revision:return {}
	var raw:={"revision":REVISION,"profile":profile,"model_index":model,"terrain_policy":policy,"frame":frame.duplicate(true),"grid":{"width":width,"cells":cells,"offset":[float(offset.x),float(offset.y)],"cell":[cell.x,cell.y],"triangle":which},"vertices":vertices}
	# Normalize the exact numeric spelling that the ordinary game JSON writer
	# preserves before sealing. No Vector/PackedArray is allowed in this result.
	var canonical:=_canonical(JSON.parse_string(JSON.stringify(raw)))
	if canonical.is_empty():return {}
	canonical["checksum"]=checksum_for(canonical)
	return canonical

static func float32_tolerance(value:float)->float:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_float(0,value)
	var exponent:=(int(bytes.decode_u32(0))>>23)&255
	var ulp:=pow(2.0,-149) if exponent==0 else pow(2.0,exponent-127-23)
	return maxf(0.00001,ulp*2.0)

func clear()->void:
	configured_ok=false;_patch={};_frame={};_points.clear();_record.clear();_inverse.clear();_target_lat=INF;_target_lon=INF;validation_samples=0;source_key="";core_width=0;core_cells=0;core_offset=Vector2.ZERO

func configure(value:Dictionary,globe:RefCounted)->bool:
	var patch:=_canonical(value)
	if patch.is_empty() or not value.get("checksum") is String or value.checksum!=checksum_for(patch) or globe==null or globe.get("revision")!=patch.frame.terrain_revision or globe.get("configured_ok")!=true or not globe.get("source_record") is PackedByteArray or globe.source_record.size()!=68:return false
	if patch.frame.record_hash!=Frame._sha(globe.source_record) or int(patch.model_index)!=int(globe.source_record.decode_u16(12)) or not Frame._number(globe.get("radius")) or float(patch.frame.radius)!=float(globe.radius) or not globe.has_method("capture_worker_state"):return false
	# The caller globe has already been reconstructed from validated World/body
	# data. Its isolated clone preserves all verified native city grading, while
	# the saved OLD packet anchor is used only for these three vertex probes.
	var sampler:RefCounted=_clone_terrain(globe)
	if sampler==null:return false
	sampler.latitude=float(patch.frame.latitude);sampler.longitude=float(patch.frame.longitude)
	var points:Array[Vector3]=[]
	for raw:Array in patch.vertices:
		var actual:=float(sampler.raw_height(float(raw[0]),float(raw[2])))
		if not is_finite(actual):return false
		var quantized:=float(Vector3(0,actual,0).y)
		if not is_finite(quantized) or absf(float(raw[1])-quantized)>float32_tolerance(quantized):return false
		points.append(Vector3(raw[0],raw[1],raw[2]))
	patch["checksum"]=str(value.checksum)
	_patch=patch;_frame=patch.frame;_points=points;_record=globe.source_record.duplicate();configured_ok=true;validation_samples=3
	core_width=float(patch.grid.width);core_cells=int(patch.grid.cells);core_offset=Vector2(patch.grid.offset[0],patch.grid.offset[1]);source_key="verified-contact:"+str(patch.checksum)
	_target_lat=INF;_target_lon=INF;_inverse.clear()
	return true

static func reconstruct(patch:Dictionary,globe:RefCounted)->RefCounted:
	var state:RefCounted=load("res://scripts/source_surface_contact_patch.gd").new()
	return state if state.configure(patch,globe) else null

func matches(globe:RefCounted)->bool:
	return configured_ok and globe!=null and globe.get("revision")==_frame.get("terrain_revision") and not _terrain_policy(globe.get("revision")).is_empty() and globe.get("configured_ok")==true and globe.get("source_record") is PackedByteArray and globe.source_record==_record and Frame._number(globe.get("radius")) and float(globe.radius)==float(_frame.radius) and Frame._number(globe.get("latitude")) and Frame._number(globe.get("longitude")) and absf(float(globe.latitude))<=PI*0.5 and absf(float(globe.longitude))<=PI+0.000001

func transform_to(globe:RefCounted)->Transform3D:
	if not matches(globe):return Transform3D(Basis.IDENTITY,Vector3(INF,INF,INF))
	var lat:=float(globe.latitude);var lon:=float(globe.longitude)
	if lat==_target_lat and lon==_target_lon:return _transform
	if lat==float(_frame.latitude) and lon==float(_frame.longitude):_transform=Transform3D.IDENTITY
	else:
		var old:=Frame._axes(float(_frame.latitude),float(_frame.longitude));var current:=Frame._axes(lat,lon);var rows:Array=[];var delta:Array=[]
		for axis in range(3):
			var row:Array=[]
			for column in range(3):row.append(Frame._dot(current[axis],old[column]))
			rows.append(row);delta.append(float(_frame.radius)*(float(old[1][axis])-float(current[1][axis])))
		_transform=Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(Frame._dot(current[0],delta),Frame._dot(current[1],delta),Frame._dot(current[2],delta)))
	_inverse=Frame._inverse_rows(_transform.basis);_target_lat=lat;_target_lon=lon
	return _transform

func height_at(globe:RefCounted,x:float,z:float)->Dictionary:
	if not is_finite(x) or not is_finite(z):return {}
	var transform:=transform_to(globe)
	if not transform.is_finite() or _inverse.size()!=9:return {}
	var qx:=x-float(transform.origin.x);var qy:=-float(transform.origin.y);var qz:=z-float(transform.origin.z)
	var o:=PackedFloat64Array([_inverse[0]*qx+_inverse[1]*qy+_inverse[2]*qz,_inverse[3]*qx+_inverse[4]*qy+_inverse[5]*qz,_inverse[6]*qx+_inverse[7]*qy+_inverse[8]*qz]);var d:=PackedFloat64Array([_inverse[1],_inverse[4],_inverse[7]])
	var a:Vector3=_points[0];var b:Vector3=_points[1];var c:Vector3=_points[2]
	var bx:=float(b.x)-a.x;var by:=float(b.y)-a.y;var bz:=float(b.z)-a.z;var cx:=float(c.x)-a.x;var cy:=float(c.y)-a.y;var cz:=float(c.z)-a.z
	var nx:=by*cz-bz*cy;var ny:=bz*cx-bx*cz;var nz:=bx*cy-by*cx;var denominator:=nx*d[0]+ny*d[1]+nz*d[2]
	if absf(denominator)<1e-12*maxf(1.0,sqrt(nx*nx+ny*ny+nz*nz)):return {}
	var height:=(nx*(float(a.x)-o[0])+ny*(float(a.y)-o[1])+nz*(float(a.z)-o[2]))/denominator
	var px:=o[0]+d[0]*height-float(a.x);var pz:=o[2]+d[2]*height-float(a.z);var determinant:=bx*cz-bz*cx
	if absf(determinant)<1e-12:return {}
	var u:=(px*cz-pz*cx)/determinant;var v:=(bx*pz-bz*px)/determinant;var tolerance:=Frame.RAY_EPS/(core_width/core_cells)
	if u<(-tolerance) or v<(-tolerance) or u+v>1.0+tolerance:return {}
	var normal:=Vector3(_inverse[0]*nx+_inverse[3]*ny+_inverse[6]*nz,_inverse[1]*nx+_inverse[4]*ny+_inverse[7]*nz,_inverse[2]*nx+_inverse[5]*ny+_inverse[8]*nz).normalized()
	if normal.y<0:normal=-normal
	return {"height":height,"normal":normal,"revision":REVISION,"source_key":source_key}

func contact_patch(globe:RefCounted,x:float,z:float)->Dictionary:
	return _patch.duplicate(true) if not height_at(globe,x,z).is_empty() else {}
