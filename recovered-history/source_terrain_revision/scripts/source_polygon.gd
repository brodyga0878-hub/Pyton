extends RefCounted
# Planar even-odd tessellation for source contours, including touching/crossing
# boundaries. Every generated vertex retains linear source-edge provenance.
# Vertical slabs end at every vertex and segment crossing; inside each slab
# boundary order is fixed, so paired crossings bound simple trapezoids.
const RELATIVE_EPSILON:=1e-12

static func _cross(first:PackedFloat64Array,second:PackedFloat64Array)->float:
	return first[0]*second[1]-first[1]*second[0]
static func _edge_value(edge:Dictionary,x:float)->Dictionary:
	var t:=clampf((x-float(edge.a[0]))/(float(edge.b[0])-float(edge.a[0])),0.0,1.0)
	var y:float=float(edge.a[1])+(float(edge.b[1])-float(edge.a[1]))*t
	var weights:Dictionary={}
	if t<1.0:weights[int(edge.first)]=1.0-t
	if t>0.0:weights[int(edge.second)]=t
	return {"point":PackedFloat64Array([x,y]),"weights":weights}
static func _failure(reason:String)->Dictionary:
	return {"ok":false,"error":reason}

static func tessellate(contours:Array)->Dictionary:
	var edges:Array=[]
	var critical:Array[float]=[]
	var source_offsets:Array[int]=[]
	var source_count:=0
	var scale:=1.0
	for contour in contours:
		source_offsets.append(source_count)
		for point in contour:
			if not is_finite(float(point.x)) or not is_finite(float(point.y)):return _failure("Non-finite source polygon coordinate")
			scale=maxf(scale,maxf(absf(float(point.x)),absf(float(point.y))));critical.append(float(point.x))
		if contour.size()>=3:
			for index in range(contour.size()):
				var next:int=(index+1)%contour.size()
				var a:=PackedFloat64Array([float(contour[index].x),float(contour[index].y)])
				var b:=PackedFloat64Array([float(contour[next].x),float(contour[next].y)])
				if a[0]==b[0]:continue
				edges.append({"a":a,"b":b,"first":source_count+index,"second":source_count+next,"minimum":minf(a[0],b[0]),"maximum":maxf(a[0],b[0]),"serial":edges.size()})
		source_count+=contour.size()
	var epsilon:=scale*RELATIVE_EPSILON
	for first in range(edges.size()):
		var a:Dictionary=edges[first]
		var direction_a:=PackedFloat64Array([float(a.b[0])-float(a.a[0]),float(a.b[1])-float(a.a[1])])
		for second in range(first+1,edges.size()):
			var b:Dictionary=edges[second]
			if float(a.minimum)>float(b.maximum) or float(b.minimum)>float(a.maximum):continue
			var direction_b:=PackedFloat64Array([float(b.b[0])-float(b.a[0]),float(b.b[1])-float(b.a[1])])
			var denominator:=_cross(direction_a,direction_b)
			if denominator==0.0:continue # Collinear endpoint x values already split overlaps.
			var offset:=PackedFloat64Array([float(b.a[0])-float(a.a[0]),float(b.a[1])-float(a.a[1])])
			var t:=_cross(offset,direction_b)/denominator
			var u:=_cross(offset,direction_a)/denominator
			if t>=-RELATIVE_EPSILON and t<=1.0+RELATIVE_EPSILON and u>=-RELATIVE_EPSILON and u<=1.0+RELATIVE_EPSILON:
				critical.append(float(a.a[0])+clampf(t,0.0,1.0)*direction_a[0])
	critical.sort()
	var boundaries:Array[float]=[]
	for x in critical:
		if boundaries.is_empty() or x-boundaries[-1]>epsilon:boundaries.append(x)
	var vertices:=PackedVector2Array()
	var vertices_xy_double:Array[PackedFloat64Array]=[]
	var weights:Array=[]
	var indices:=PackedInt32Array()
	var area:=0.0
	for slab in range(boundaries.size()-1):
		var left:float=boundaries[slab];var right:float=boundaries[slab+1]
		var middle:float=left+(right-left)*0.5
		var crossings:Array=[]
		for edge in edges:
			if middle<=float(edge.minimum) or middle>=float(edge.maximum):continue
			var at:=_edge_value(edge,middle)
			crossings.append({"edge":edge,"y":float(at.point[1])})
		crossings.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a.y)<float(b.y) if float(a.y)!=float(b.y) else int(a.edge.serial)<int(b.edge.serial))
		if crossings.size()&1:return _failure("Source polygon has an odd number of boundary crossings")
		for pair in range(0,crossings.size(),2):
			var lower:Dictionary=crossings[pair].edge;var upper:Dictionary=crossings[pair+1].edge
			var corners:Array=[_edge_value(lower,left),_edge_value(lower,right),_edge_value(upper,right),_edge_value(upper,left)]
			if float(corners[3].point[1])-float(corners[0].point[1])< -epsilon or float(corners[2].point[1])-float(corners[1].point[1])< -epsilon:return _failure("Source polygon boundary order changed inside a slab")
			var start:=vertices.size()
			for corner in corners:
				vertices.append(Vector2(corner.point[0],corner.point[1]));vertices_xy_double.append(corner.point);weights.append(corner.weights)
			for triangle in [[0,1,2],[0,2,3]]:
				var a:PackedFloat64Array=corners[triangle[0]].point
				var b:PackedFloat64Array=corners[triangle[1]].point
				var c:PackedFloat64Array=corners[triangle[2]].point
				var twice:float=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
				# An intersection may produce a numerical zero at a slab endpoint.
				if absf(twice)<=epsilon*(right-left):continue
				if twice<0.0:return _failure("Source polygon produced inverted slab geometry")
				for index in triangle:indices.append(start+index)
				area+=twice*0.5
	return {"ok":true,"vertices":vertices,"vertices_xy_double":vertices_xy_double,"indices":indices,"weights":weights,"source_offsets":source_offsets,"area":area,"fill_rule":"even_odd"}
