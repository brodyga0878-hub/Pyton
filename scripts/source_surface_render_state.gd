extends RefCounted
# Published CORE geometry is authoritative only inside its own physical mesh.
# SourceTerrain remains the caller's fallback outside this bounded ray lookup.
const Packet=preload("res://scripts/source_surface_render_packet.gd")
const REVISION:="source-surface-render-state-v1"
const RECORD_DOMAIN:="f878_runtime_bank_with_unconverted_type35_fields"
const RAY_EPS:=0.00001
var configured_ok:=false
var source_key:=""
var core_width:=0.0
var core_cells:=0
var core_offset:=Vector2.ZERO
var _frame:Dictionary={}
var _vertices:=PackedVector3Array()
var _minimum:=PackedFloat64Array()
var _maximum:=PackedFloat64Array()
var _record:=PackedByteArray()
var _target_lat:=INF
var _target_lon:=INF
var _transform:=Transform3D.IDENTITY
var _inverse:=PackedFloat64Array()
var _queries:=0
var _last_cells:=0
var _last_triangles:=0
var _maximum_cells:=0

static func _number(value:Variant)->bool:return (value is float or value is int) and is_finite(float(value))
static func _integer(value:Variant,minimum:int,maximum:int)->bool:return _number(value) and float(value)==floorf(float(value)) and value>=minimum and value<=maximum
static func _sha(value:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(value);return hash.finish().hex_encode()

func clear()->void:
	configured_ok=false;source_key="";core_width=0;core_cells=0;core_offset=Vector2.ZERO;_frame={};_vertices.clear();_minimum.clear();_maximum.clear();_record.clear();_target_lat=INF;_target_lon=INF;_inverse.clear();_transform=Transform3D.IDENTITY;_queries=0;_last_cells=0;_last_triangles=0;_maximum_cells=0

func configure(packet:Dictionary)->bool:
	# Validate before assigning any live state. A failed replacement leaves the
	# previous visual/collision pair usable until the caller publishes a new one.
	if not packet.get("ok") is bool or not packet.get("revision") is String or not Packet.valid(packet):return false
	var frame:Dictionary=packet.frame
	if frame.get("terrain_revision")!=Packet.TERRAIN_REVISION or frame.get("record_domain")!=RECORD_DOMAIN or not packet.get("source_key","") is String:return false
	if not _integer(packet.get("core_cells"),2,128) or not _number(packet.get("core_width")) or float(packet.core_width)<64 or float(packet.core_width)>65536:return false
	var offset:Variant=packet.get("core_offset",Vector2.ZERO)
	if not offset is Vector2 or not offset.is_finite():return false
	var count:=int(packet.core_cells);var width:=float(packet.core_width);var core:Dictionary=packet.meshes[0]
	if str(core.get("role",""))!="core" or core.vertices.size()!=(count+1)*(count+1) or core.indices.size()!=count*count*6:return false
	for z in range(count+1):
		for x in range(count+1):
			var point:Vector3=core.vertices[z*(count+1)+x]
			var expected:=Vector3(float(offset.x)-width*0.5+float(x)*width/count,0,float(offset.y)-width*0.5+float(z)*width/count)
			if point.x!=expected.x or point.z!=expected.z:return false
	for z in range(count):
		for x in range(count):
			var a:=z*(count+1)+x;var at:=(z*count+x)*6
			var expected:=PackedInt32Array([a,a+1,a+count+1,a+1,a+count+2,a+count+1])
			for index in range(6):
				if core.indices[at+index]!=expected[index]:return false
	var minimum:=PackedFloat64Array([INF,INF,INF]);var maximum:=PackedFloat64Array([-INF,-INF,-INF])
	for point:Vector3 in core.vertices:
		for axis in range(3):minimum[axis]=minf(minimum[axis],float(point[axis]));maximum[axis]=maxf(maximum[axis],float(point[axis]))
	_frame=frame.duplicate(true);_frame.record_hash=str(frame.record_hash).to_lower();_vertices=core.vertices.duplicate();_minimum=minimum;_maximum=maximum
	source_key=str(packet.get("source_key",""));core_cells=count;core_width=width;core_offset=offset;configured_ok=true
	_record.clear();_target_lat=INF;_target_lon=INF;_inverse.clear();_queries=0;_last_cells=0;_last_triangles=0;_maximum_cells=0
	return true

func matches(globe:RefCounted)->bool:
	if not configured_ok or globe==null or globe.get("revision")!=Packet.TERRAIN_REVISION or globe.get("configured_ok")!=true:return false
	if not _number(globe.get("radius")) or float(globe.radius)!=float(_frame.radius) or not _number(globe.get("latitude")) or not _number(globe.get("longitude")) or absf(float(globe.latitude))>PI*0.5 or absf(float(globe.longitude))>PI+0.000001:return false
	var record:Variant=globe.get("source_record")
	if not record is PackedByteArray or record.size()!=68:return false
	if _record!=record:
		if _sha(record)!=str(_frame.record_hash):return false
		_record=record.duplicate()
	return true

static func _axes(latitude:float,longitude:float)->Array:
	var sl:=sin(latitude);var cl:=cos(latitude);var sn:=sin(longitude);var cs:=cos(longitude)
	return [[-sn,0.0,-cs],[cl*cs,sl,-cl*sn],[sl*cs,-cl,-sl*sn]]
static func _dot(first:Array,second:Array)->float:return float(first[0])*float(second[0])+float(first[1])*float(second[1])+float(first[2])*float(second[2])

static func _inverse_rows(basis:Basis)->PackedFloat64Array:
	var a:=float(basis.x.x);var b:=float(basis.y.x);var c:=float(basis.z.x);var d:=float(basis.x.y);var e:=float(basis.y.y);var f:=float(basis.z.y);var g:=float(basis.x.z);var h:=float(basis.y.z);var i:=float(basis.z.z)
	var determinant:=a*(e*i-f*h)-b*(d*i-f*g)+c*(d*h-e*g)
	if not is_finite(determinant) or absf(determinant)<0.5:return PackedFloat64Array()
	return PackedFloat64Array([(e*i-f*h)/determinant,(c*h-b*i)/determinant,(b*f-c*e)/determinant,(f*g-d*i)/determinant,(a*i-c*g)/determinant,(c*d-a*f)/determinant,(d*h-e*g)/determinant,(b*g-a*h)/determinant,(a*e-b*d)/determinant])

func transform_to(globe:RefCounted)->Transform3D:
	if not matches(globe):return Transform3D(Basis.IDENTITY,Vector3(INF,INF,INF))
	var lat:=float(globe.latitude);var lon:=float(globe.longitude)
	if lat==_target_lat and lon==_target_lon:return _transform
	if lat==float(_frame.latitude) and lon==float(_frame.longitude):_transform=Transform3D.IDENTITY
	else:
		var old:=_axes(float(_frame.latitude),float(_frame.longitude));var current:=_axes(lat,lon);var rows:Array=[]
		for axis in range(3):
			var row:Array=[]
			for column in range(3):row.append(_dot(current[axis],old[column]))
			rows.append(row)
		# Keep R*(oldUp-newUp) in scalar doubles. Subtracting two large Vector3
		# planet origins first would lose a512m rebase at sufficiently large R.
		var delta:Array=[]
		for axis in range(3):delta.append(float(_frame.radius)*(float(old[1][axis])-float(current[1][axis])))
		_transform=Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(_dot(current[0],delta),_dot(current[1],delta),_dot(current[2],delta)))
	_inverse=_inverse_rows(_transform.basis);_target_lat=lat;_target_lon=lon
	return _transform

func _clip(origin:PackedFloat64Array,direction:PackedFloat64Array)->PackedFloat64Array:
	var low:=-INF;var high:=INF
	for axis in range(3):
		if absf(direction[axis])<1e-15:
			if origin[axis]<_minimum[axis]-RAY_EPS or origin[axis]>_maximum[axis]+RAY_EPS:return PackedFloat64Array()
		else:
			var first:=(_minimum[axis]-origin[axis])/direction[axis];var second:=(_maximum[axis]-origin[axis])/direction[axis]
			low=maxf(low,minf(first,second));high=minf(high,maxf(first,second))
	if not is_finite(low) or not is_finite(high) or low>high+RAY_EPS:return PackedFloat64Array()
	return PackedFloat64Array([low,high])

func _triangle(ix:int,iz:int,which:int,origin:PackedFloat64Array,direction:PackedFloat64Array,low:float,high:float)->Dictionary:
	_last_triangles+=1
	var a:=iz*(core_cells+1)+ix;var ia:=a if which==0 else a+1;var ib:=a+1 if which==0 else a+core_cells+2;var ic:=a+core_cells+1
	var first:Vector3=_vertices[ia];var b:Vector3=_vertices[ib];var c:Vector3=_vertices[ic]
	var bx:=float(b.x)-first.x;var by:=float(b.y)-first.y;var bz:=float(b.z)-first.z;var cx:=float(c.x)-first.x;var cy:=float(c.y)-first.y;var cz:=float(c.z)-first.z
	var nx:=by*cz-bz*cy;var ny:=bz*cx-bx*cz;var nz:=bx*cy-by*cx
	var denominator:=nx*direction[0]+ny*direction[1]+nz*direction[2]
	if absf(denominator)<1e-12*maxf(1.0,sqrt(nx*nx+ny*ny+nz*nz)):return {}
	var height:=(nx*(float(first.x)-origin[0])+ny*(float(first.y)-origin[1])+nz*(float(first.z)-origin[2]))/denominator
	if height<low-RAY_EPS or height>high+RAY_EPS:return {}
	var x:=origin[0]+direction[0]*height;var z:=origin[2]+direction[2]*height
	var corner:Vector3=_vertices[a];var end:Vector3=_vertices[a+core_cells+2]
	var fx:=(x-float(corner.x))/(float(end.x)-corner.x);var fz:=(z-float(corner.z))/(float(end.z)-corner.z)
	if fx<(-1e-7) or fz<(-1e-7) or fx>1.0000001 or fz>1.0000001 or (which==0 and fx+fz>1.0000001) or (which==1 and fx+fz<0.9999999):return {}
	var normal:=Vector3(_inverse[0]*nx+_inverse[3]*ny+_inverse[6]*nz,_inverse[1]*nx+_inverse[4]*ny+_inverse[7]*nz,_inverse[2]*nx+_inverse[5]*ny+_inverse[8]*nz).normalized()
	if normal.y<0:normal=-normal
	return {"height":height,"normal":normal,"triangle_index":(iz*core_cells+ix)*2+which,"cell":Vector2i(ix,iz),"revision":REVISION,"source_key":source_key}

func height_at(globe:RefCounted,x:float,z:float)->Dictionary:
	_queries+=1;_last_cells=0;_last_triangles=0
	if not is_finite(x) or not is_finite(z):return {}
	var transform:=transform_to(globe)
	if not transform.is_finite() or _inverse.size()!=9:return {}
	var qx:=x-float(transform.origin.x);var qy:=-float(transform.origin.y);var qz:=z-float(transform.origin.z)
	var origin:=PackedFloat64Array([_inverse[0]*qx+_inverse[1]*qy+_inverse[2]*qz,_inverse[3]*qx+_inverse[4]*qy+_inverse[5]*qz,_inverse[6]*qx+_inverse[7]*qy+_inverse[8]*qz])
	var direction:=PackedFloat64Array([_inverse[1],_inverse[4],_inverse[7]]);var clipped:=_clip(origin,direction)
	if clipped.is_empty():return {}
	var low:=clipped[0];var high:=clipped[1];var span:=maxf(0.0,high-low)
	var start_x:=origin[0]+direction[0]*high;var start_z:=origin[2]+direction[2]*high
	var dx:=-direction[0];var dz:=-direction[2];var cell_x:=(_maximum[0]-_minimum[0])/core_cells;var cell_z:=(_maximum[2]-_minimum[2])/core_cells
	var gx:=(start_x-_minimum[0])/cell_x;var gz:=(start_z-_minimum[2])/cell_z
	var ix:=clampi(floori(gx),0,core_cells-1);var iz:=clampi(floori(gz),0,core_cells-1)
	if dx<0 and absf(gx-roundf(gx))<1e-9:ix=clampi(ceili(gx)-1,0,core_cells-1)
	if dz<0 and absf(gz-roundf(gz))<1e-9:iz=clampi(ceili(gz)-1,0,core_cells-1)
	var step_x:=1 if dx>0 else -1;var step_z:=1 if dz>0 else -1
	var next_x:=INF if absf(dx)<1e-15 else (_minimum[0]+float(ix+(1 if dx>0 else 0))*cell_x-start_x)/dx
	var next_z:=INF if absf(dz)<1e-15 else (_minimum[2]+float(iz+(1 if dz>0 else 0))*cell_z-start_z)/dz
	var delta_x:=INF if absf(dx)<1e-15 else cell_x/absf(dx);var delta_z:=INF if absf(dz)<1e-15 else cell_z/absf(dz)
	for visit in range(core_cells*2+2):
		_last_cells+=1;_maximum_cells=maxi(_maximum_cells,_last_cells)
		var first:=_triangle(ix,iz,0,origin,direction,low,high);var second:=_triangle(ix,iz,1,origin,direction,low,high)
		if not first.is_empty() or not second.is_empty():
			return second if first.is_empty() else (first if second.is_empty() or float(first.height)>=float(second.height) else second)
		var next:=minf(next_x,next_z)
		if not is_finite(next) or next>span+RAY_EPS:break
		if next_x<=next_z+1e-10:ix+=step_x;next_x+=delta_x
		if next_z<=next+1e-10:iz+=step_z;next_z+=delta_z
		if ix<0 or iz<0 or ix>=core_cells or iz>=core_cells:break
	return {}

func stats()->Dictionary:return {"queries":_queries,"last_cells":_last_cells,"last_triangles":_last_triangles,"maximum_cells":_maximum_cells,"cell_budget":core_cells*2+2,"configured_ok":configured_ok,"source_key":source_key}
