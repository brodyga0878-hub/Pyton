extends RefCounted
# Pure integer F1876 query mode. Inputs and outputs keep the original raw units;
# geographic coordinates, metres, planetary clocks and rendering are not inferred.
const Ground=preload("res://scripts/ground_coordinates.gd")
const TerrainMath=preload("res://scripts/terrain_math.gd")
const FFPMath=preload("res://scripts/ffe_math.gd")
const MASK:=0xffffffff
static var resources:Dictionary={}
var depth_control:=0
var feature_schedule:Array=[]
var vertex_count:=0
var vertex_serial:=0
var invalid_query:=false
var raw_tables:PackedByteArray
var table_offsets:Dictionary={}
var table_symbols:Dictionary={}
var map_bytes:Dictionary={}

static func _s32(value:int)->int:return Ground.signed32(value)
static func _s16(value:int)->int:
	var low:=value&65535
	return low-65536 if low>=32768 else low
static func _qmul(a:int,b:int)->int:return Ground.multiply_q31(a,b)
static func _avg(a:int,b:int)->int:return _s32(a+b)>>1
static func _msb(value:int)->int:
	var low:=value&MASK
	var answer:=0
	while low>=2:low>>=1;answer+=1
	return answer
static func _abs32(value:int)->int:return _s32(-value) if value<0 else value
static func _div32(numerator:int,denominator:int)->int:
	var quotient:int=absi(numerator)/absi(denominator)
	return _s32(-quotient if (numerator<0)!=(denominator<0) else quotient)
static func _vector(values:Variant)->PackedInt64Array:
	var result:=PackedInt64Array()
	for value in values:result.append(_s32(int(value)))
	return result
static func _add(a:PackedInt64Array,b:PackedInt64Array)->PackedInt64Array:
	return PackedInt64Array([_s32(a[0]+b[0]),_s32(a[1]+b[1]),_s32(a[2]+b[2])])
static func _subtract(a:PackedInt64Array,b:PackedInt64Array)->PackedInt64Array:
	return PackedInt64Array([_s32(a[0]-b[0]),_s32(a[1]-b[1]),_s32(a[2]-b[2])])
static func _orientation(a:PackedInt64Array,b:PackedInt64Array)->int:
	# F1875 forms the signed 64-bit cross-product difference then reads its sign.
	return -1 if a[0]*b[1]-a[1]*b[0]<0 else 0
static func _vector_bits(p:PackedInt64Array)->int:
	return _msb(_abs32(p[0])|_abs32(p[1])|_abs32(p[2]))
static func _raw_length(p:PackedInt64Array)->int:
	var shift:=maxi(0,_vector_bits(p)-14)
	var total:=0
	for axis in range(3):
		var value:int=p[axis]>>shift
		total=_s32(total+_s32(value*value))
	return _s32(FFPMath.integer_sqrt(total)<<shift)

func _table_i32(number:int,index:int)->int:
	return raw_tables.decode_s32(int(table_offsets[str(number)])+index*4)
func _table_i16(number:int,index:int)->int:
	return raw_tables.decode_s16(int(table_offsets[str(number)])+index*2)
func _map_sample(number:String,index:int,signed:bool)->int:
	if number.is_empty():return 0
	var byte:int=map_bytes[number][index]
	return byte-256 if signed and byte>=128 else byte

func _vertex(p:PackedInt64Array,n:PackedInt64Array,height:int)->Dictionary:
	var result:Dictionary={"id":vertex_serial,"p":p,"n":n,"height":height,"land":0,"depth":0,"uv":[Vector2i.ZERO,Vector2i.ZERO],"screen":Vector2i.ZERO}
	vertex_serial+=1
	return result
func _set_depth(vertex:Dictionary)->void:
	var value:int=depth_control-_msb(maxi(int(vertex.p[2]),1024))
	vertex.depth=maxi(1,value)
func _new_node(parent:Variant=null,root:=false)->Dictionary:
	var node:Dictionary={"features":[0,0],"children":[]}
	node.children.resize(20 if root else 4)
	if parent!=null:
		for slot in range(2):
			var inherited:Variant=parent.features[slot]
			if inherited is Dictionary:
				inherited=1-_feature_config(int(inherited.kind)).duration
			elif int(inherited)<0:inherited=int(inherited)+1
			node.features[slot]=inherited
	return node
func _feature_tree(stream:PackedByteArray)->Dictionary:
	var root:=_new_node(null,true)
	var cursor:=0
	while cursor+2<=stream.size():
		var encoded:=int(stream.decode_s16(cursor))
		if encoded==0:return root
		if cursor+16>stream.size():return {}
		var bits:=_msb(encoded)
		var packed:=(encoded<<((16-bits)&31))&65535
		var count:int=(bits-3)/2
		var node:Dictionary=root
		for level in range(count):
			var child:=packed>>11
			if child>=node.children.size():return {}
			if node.children[child]==null:node.children[child]=_new_node(node)
			node=node.children[child]
			packed=(packed<<2)&8191
		var descriptor:Dictionary={"kind":int(stream.decode_s16(cursor+2)),"uv":[]}
		for vertex in range(3):descriptor.uv.append(Vector2i(stream.decode_s16(cursor+4+vertex*4),stream.decode_s16(cursor+6+vertex*4)))
		var feature_count:int=(int(table_offsets["7843"])-int(table_offsets["7841"]))/12
		if descriptor.kind<0 or descriptor.kind>=feature_count:return {}
		for slot in range(2):
			if not node.features[slot] is Dictionary and int(node.features[slot])==0:node.features[slot]=descriptor;break
		cursor+=16
	return {}
func _feature_config(kind:int)->Dictionary:
	var offset:int=table_offsets["7841"]+kind*12
	return {"height_map":str(table_symbols.get(str(offset),"")),"mask_map":str(table_symbols.get(str(offset+4),"")),"duration":raw_tables.decode_s32(offset+8)}
func _patch_height(height:int,configuration:Dictionary,uv:Vector2i)->int:
	if uv.x<0 or uv.x>=128 or uv.y<0 or uv.y>=128:return height
	var index:=uv.x+uv.y*128
	var value:=height>>7
	if not str(configuration.mask_map).is_empty():value=_s32(value*_map_sample(configuration.mask_map,index,false))
	return _s32(value+(_map_sample(configuration.height_map,index,true)<<21))
func _prepare_triangle(vertices:Array,node:Variant)->void:
	for vertex in vertices:_set_depth(vertex)
	if node!=null:
		for slot in range(2):
			var feature:Variant=node.features[slot]
			if not feature is Dictionary:continue
			var configuration:=_feature_config(int(feature.kind))
			for corner in range(3):vertices[corner].height=_patch_height(int(vertices[corner].height),configuration,feature.uv[corner])
	for vertex in vertices:vertex.land=maxi(0,int(vertex.height))
func _schedule_features(vertices:Array,node:Variant,depth:int)->void:
	if node==null:return
	for slot in range(2):
		var feature:Variant=node.features[slot]
		if not feature is Dictionary:continue
		var configuration:=_feature_config(int(feature.kind))
		for index in range(configuration.duration):
			if depth+index<32:feature_schedule[slot][depth+index]=configuration
		for corner in range(3):vertices[corner].uv[slot]=feature.uv[corner]

func _edge(first:Dictionary)->Dictionary:
	return {"first":first,"left":null,"right":null,"midpoint":null}
func _edge_child(edge:Dictionary,first:Dictionary)->Dictionary:
	return edge.left if edge.first.id==first.id else edge.right
func _edge_midpoint(edge:Dictionary,a:Dictionary,b:Dictionary,c:Dictionary,depth:int,worker:int)->Dictionary:
	if edge.midpoint!=null:
		if worker>=1858 and worker<=1865:_midpoint_uv(a,b,depth,edge.midpoint.uv)
		return edge.midpoint
	var midpoint:Dictionary=_midpoint(a,b,c,depth,worker)
	midpoint.id=vertex_serial;vertex_serial+=1;vertex_count+=1
	edge.midpoint=midpoint
	edge.left=_edge(edge.first)
	edge.right=_edge(b if edge.first.id==a.id else a)
	return midpoint
func _intersection(vertices:Array)->int:
	var bits:=0
	for vertex in vertices:
		for value in vertex.p:bits|=_abs32(value)
	var shift:=maxi(0,_msb(bits)-13)
	var a:PackedInt64Array=vertices[0].p.duplicate()
	var b:PackedInt64Array=vertices[1].p.duplicate()
	var c:PackedInt64Array=vertices[2].p.duplicate()
	for axis in range(3):a[axis]>>=shift;b[axis]>>=shift;c[axis]>>=shift
	var denominator_first:=_s32(_s32((a[0]-c[0])*b[1])+_s32((b[0]-a[0])*c[1])+_s32((c[0]-b[0])*a[1]))
	var denominator_second:=_s32(_s32((a[0]-b[0])*c[1])+_s32((c[0]-a[0])*b[1])+_s32((b[0]-c[0])*a[1]))
	var numerator_first:=_s32(_s32(a[0]*b[1])-_s32(b[0]*a[1]))
	var numerator_second:=_s32(_s32(a[0]*c[1])-_s32(c[0]*a[1]))
	var fraction_first:=_plane_fraction(numerator_second,denominator_second)
	var fraction_second:=_plane_fraction(numerator_first,denominator_first)
	var delta:=_s32(_s32((b[2]-a[2])*fraction_first)+_s32((c[2]-a[2])*fraction_second))
	return _s32((delta>>(15-shift) if shift<15 else _s32(delta<<(shift-15)))+int(vertices[0].p[2]))
func _plane_fraction(numerator:int,denominator:int)->int:
	var shift:=clampi(30-_msb(_abs32(numerator)),0,15)
	if shift<15:
		denominator>>=15-shift
		if denominator==0:denominator=1
	if denominator==0:invalid_query=true;return 0
	return _div32(_s32(numerator<<shift),denominator)

func _load_resources()->bool:
	if not raw_tables.is_empty():return true
	if resources.is_empty():
		var text:=FileAccess.get_file_as_string("res://data/ffe_terrain_query.json")
		if text.is_empty():return false
		resources=JSON.parse_string(text)
	raw_tables=PackedByteArray();table_offsets.clear();table_symbols.clear();map_bytes.clear()
	for number in range(7835,7895):
		var key:=str(number)
		var entry:Dictionary=resources.tables[key]
		table_offsets[key]=raw_tables.size()
		for relocation in entry.relocations:table_symbols[str(raw_tables.size()+int(relocation.offset))]=str(relocation.symbol)
		raw_tables.append_array(str(entry.bytes_hex).hex_decode())
	for number in [7637,7638]:map_bytes["DATA_%06d"%number]=str(resources.maps[str(number)].bytes_hex).hex_decode()
	return true

func query_raw(seed:int,style:int,matrix_raw:PackedInt64Array,center_raw:PackedInt64Array,query_limit_raw:int,graphics_level_raw:=1,features:=PackedByteArray())->Dictionary:
	if matrix_raw.size()!=9 or center_raw.size()!=3 or style<0 or style>=14:return {}
	if not _load_resources():return {}
	var stream:=features if not features.is_empty() else PackedByteArray([0,0])
	var tree:=_feature_tree(stream)
	if tree.is_empty():return {}
	vertex_count=0;vertex_serial=0;invalid_query=false
	feature_schedule=[]
	for slot in range(2):
		var schedule:Array=[];schedule.resize(32);schedule.fill({});feature_schedule.append(schedule)
	var matrix:=_vector(matrix_raw);var center:=_vector(center_raw)
	var radius:=0
	for row in range(3):radius=maxi(radius,_raw_length(PackedInt64Array([matrix[row*3],matrix[row*3+1],matrix[row*3+2]])))
	if radius<=0:return {}
	var distance:=_s32(_qmul(radius,0x54000000)*2)
	depth_control=_msb(distance)+graphics_level_raw-1
	var style_offset:int=table_offsets["7843"]+style*48
	var style_function:String=table_symbols[str(style_offset)]
	var style_parameter:=raw_tables.decode_s32(style_offset+8)
	var vertices:Array=[]
	var random_value:=_s32(seed)
	for index in range(12):
		var n:=PackedInt64Array()
		for axis in range(3):
			var value:=0
			for row in range(3):value=_s32(value+_qmul(_table_i32(7892,index*3+row),matrix[row*3+axis]))
			n.append(value)
		random_value=TerrainMath.hash32(random_value)
		var height:int=(_table_i32(7892,index*3+1)>>5)+0x4000000 if style_function=="FUNC_001842" else random_value>>4
		vertices.append(_vertex(_add(center,n),n,height))
	var edges:Array=[]
	for index in range(30):edges.append(_edge(vertices[_table_i32(7894,index*2)]))
	var recorded:=0x7fffffff
	for face in range(20):
		var triangle:Array=[]
		var triangle_edges:Array=[]
		for corner in range(3):
			triangle.append(vertices[_table_i32(7893,face*6+corner)])
			triangle_edges.append(edges[_table_i32(7893,face*6+3+corner)])
		var node:Variant=tree.children[face]
		_prepare_triangle(triangle,node)
		var radial:Array=[]
		for vertex in triangle:radial.append(_subtract(vertex.p,center))
		if _orientation(radial[0],radial[1])<0 or _orientation(radial[1],radial[2])<0 or _orientation(radial[2],radial[0])<0:continue
		var dispatch:=style_parameter+(8 if node!=null else 0)+(2 if int(center[2])<=_s32(radius*2) else 0)
		var depth:=0
		while depth<=9 and (int(triangle[0].depth)>=depth or int(triangle[1].depth)>=depth or int(triangle[2].depth)>=depth):
			_schedule_features(triangle,node,depth)
			var base:int=table_offsets["7845" if depth<5 else "7844"]+dispatch*4
			var worker_symbol:String=table_symbols[str(base)]
			var worker:=int(worker_symbol.trim_prefix("FUNC_"))
			var a:Dictionary=triangle[0];var b:Dictionary=triangle[1];var c:Dictionary=triangle[2]
			var ab:Dictionary=_edge_midpoint(triangle_edges[0],a,b,c,depth,worker)
			var bc:Dictionary=_edge_midpoint(triangle_edges[1],b,c,a,depth,worker)
			var ca:Dictionary=_edge_midpoint(triangle_edges[2],c,a,b,depth,worker)
			var selected:=3
			if _orientation(_subtract(ab.p,center),_subtract(ca.p,center))>=0:selected=0
			elif _orientation(_subtract(bc.p,center),_subtract(ab.p,center))>=0:selected=1
			elif _orientation(_subtract(ca.p,center),_subtract(bc.p,center))>=0:selected=2
			if selected<3:
				var first:Dictionary=triangle[selected]
				var next_first:Dictionary=[ab,bc,ca][selected]
				var next_second:Dictionary=[ca,ab,bc][selected]
				var old_first:Dictionary=triangle_edges[selected]
				var old_second:Dictionary=triangle_edges[(selected+2)%3]
				triangle=[first,next_first,next_second]
				triangle_edges=[_edge_child(old_first,first),_edge(next_first),_edge_child(old_second,first)]
			else:
				triangle=[bc,ca,ab]
				triangle_edges=[_edge(bc),_edge(ca),_edge(ab)]
			if node!=null:node=node.children[selected]
			depth+=1
		recorded=_intersection(triangle)
		if invalid_query:return {}
		break
	return {"query_result_raw":mini(recorded,_s32(query_limit_raw)),"recorded_intersection_raw":recorded,"pending_query_flag":0x4000 if recorded==0x7fffffff else 0,"query_limit_raw":_s32(query_limit_raw),"vertex_pool_count_after_return":vertex_count,"depth_control_raw":depth_control}

static func query(case:Dictionary,features:=PackedByteArray())->Dictionary:
	var kernel:RefCounted=load("res://scripts/terrain_query.gd").new()
	return kernel.query_raw(int(case.seed),int(case.style),_vector(case.matrix_raw),_vector(case.center_raw),int(case.query_limit_raw),int(case.get("graphics_level_raw",1)),features)

# F1849..F1867 shared semantic workers. Parent provides depth_control,
# feature_schedule, _s32, _qmul, _avg, _table_i32, _table_i16 and _map_sample.
# Integer helpers deliberately preserve x86 ADD/SAR/NEG wrap and signed words.
func _midpoint_s16(value:int)->int:
	var low:=value&65535
	return low-65536 if low>=32768 else low

func _midpoint_msb(value:int)->int:
	var low:int=value&0xffffffff
	var result:=0
	while low>1:
		low>>=1
		result+=1
	return result

func _midpoint_uv(a:Dictionary,b:Dictionary,depth:int,uv:Array)->void:
	# F1858..65 refresh these UV words even when their shared midpoint exists.
	# The edge cache owner should call this helper again on a cached feature edge.
	for channel in range(2):
		var descriptor:Dictionary=feature_schedule[channel][depth]
		if str(descriptor.get("height_map","")).is_empty():continue
		var first:Vector2i=a.uv[channel]
		var second:Vector2i=b.uv[channel]
		uv[channel]=Vector2i(_midpoint_s16((_midpoint_s16(first.x)+_midpoint_s16(second.x))>>1),_midpoint_s16((_midpoint_s16(first.y)+_midpoint_s16(second.y))>>1))

func _midpoint_apply_features(height:int,uv:Array,depth:int)->int:
	var result:=height
	for channel in range(2):
		var descriptor:Dictionary=feature_schedule[channel][depth]
		var height_map:String=str(descriptor.get("height_map",""))
		if height_map.is_empty():continue
		var coordinate:Vector2i=uv[channel]
		var u:=_midpoint_s16(coordinate.x)
		var v:=_midpoint_s16(coordinate.y)
		# The original JNC after MOVSX excludes negative coordinates as unsigned.
		if u<0 or u>=128 or v<0 or v>=128:continue
		var index:=u+(v<<7)
		result>>=7
		var mask_map:String=str(descriptor.get("mask_map",""))
		if not mask_map.is_empty():result=_s32(result*_map_sample(mask_map,index,false))
		result=_s32(result+_s32(_map_sample(height_map,index,true)<<21))
	return result

func _midpoint(a:Dictionary,b:Dictionary,c:Dictionary,depth:int,worker:int)->Dictionary:
	var feature_worker:bool=worker>=1858 and worker<=1865
	var normalized:bool=worker==1849 or worker==1867 or (worker>=1854 and worker<=1857) or (worker>=1862 and worker<=1865)
	# family0/1: jitter only changes the scalar field; family2 moves all heights;
	# family3 moves clamped positive heights and refines the coastline one level.
	# -1 (1849) is a sphere without scalar noise, -2 (1866/7) averages scalars.
	var family:=-1 if worker==1849 else (-2 if worker>=1866 else ((worker-1850)&3))
	var m:Dictionary={"p":PackedInt64Array([0,0,0]),"n":PackedInt64Array([0,0,0]),"height":0,"land":0,"depth":1,"uv":[Vector2i.ZERO,Vector2i.ZERO],"screen":Vector2i.ZERO}
	if feature_worker:_midpoint_uv(a,b,depth,m.uv)
	var coefficient:=0
	if normalized:
		var normalize_coefficient:int=_table_i32(7840,depth)
		for axis in range(3):m.n[axis]=_qmul(_s32(int(a.n[axis])+int(b.n[axis])),normalize_coefficient)
		coefficient=_table_i32(7839,depth)
	else:
		m.n=a.n.duplicate()
	var effective_depth:=depth
	if family==1 or family==3:
		if _s32(_s32(int(a.height)-1)^_s32(int(b.height)-1))<0:effective_depth-=1
	var fast:bool=effective_depth>int(a.depth) and effective_depth>int(b.depth)
	var averaged_height:int=_avg(int(a.height),int(b.height))
	if fast:
		if family==3:
			if int(a.land)!=0 or int(b.land)!=0:
				m.land=_avg(int(a.land),int(b.land));m.height=m.land
			else:
				m.height=averaged_height;m.land=0
		elif family!=-1:m.height=averaged_height
		for axis in range(3):m.p[axis]=_avg(int(a.p[axis]),int(b.p[axis]))
		# Packed screen correction affects only rendering fields; the flag-1 query
		# observes physical p, scalar/land and depth, never these packed screen words.
		if int(a.p[2])>=64 and int(b.p[2])>=64:
			var sa:Vector2i=a.get("screen",Vector2i.ZERO)
			var sb:Vector2i=b.get("screen",Vector2i.ZERO)
			var sc:Vector2i=c.get("screen",Vector2i.ZERO)
			var x:=(_midpoint_s16(sa.x)+_midpoint_s16(sb.x))>>1
			var y:=(_midpoint_s16(sa.y)+_midpoint_s16(sb.y))>>1
			if int(c.p[2])>64:
				var x_order:=int(_midpoint_s16(sa.x)>_midpoint_s16(sb.x))
				var y_order:=int(_midpoint_s16(sa.y)>_midpoint_s16(sb.y))
				var left:int=_s32((_midpoint_s16(sc.x)-_midpoint_s16(sa.x))*(_midpoint_s16(sb.y)-_midpoint_s16(sa.y)))
				var right:int=_s32((_midpoint_s16(sb.x)-_midpoint_s16(sa.x))*(_midpoint_s16(sc.y)-_midpoint_s16(sa.y)))
				var table_index:=y_order*8+x_order*4+int(left>right)*2
				var table:=7854+(worker-1849)*2
				x+=_table_i16(table,table_index);y+=_table_i16(table+1,table_index)
			m.screen=Vector2i(_midpoint_s16(x),_midpoint_s16(y))
	else:
		if family>=0:
			m.height=_s32(averaged_height+TerrainMath.jitter(int(a.height),int(b.height),depth))
			if feature_worker:m.height=_midpoint_apply_features(int(m.height),m.uv,depth)
			if family==2:
				coefficient=_s32(coefficient+(_s32(int(m.height)-averaged_height)>>3))
			elif family==3:
				m.land=maxi(0,int(m.height))
				coefficient=_s32(coefficient+(_s32(int(m.land)-_avg(int(a.land),int(b.land)))>>3))
		elif family==-2:m.height=averaged_height
		for axis in range(3):m.p[axis]=_s32(_avg(int(a.p[axis]),int(b.p[axis]))+_qmul(int(m.n[axis]),coefficient))
	m.depth=maxi(1,depth_control-_midpoint_msb(maxi(1024,int(m.p[2]))))
	return m
