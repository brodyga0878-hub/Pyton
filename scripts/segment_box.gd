extends RefCounted
# Swept point against a box expanded by the vessel's conservative spherical radius.
static func intersect(start:Vector3,finish:Vector3,box:AABB)->Dictionary:
	var inside:=start.x>box.position.x and start.x<box.end.x and start.y>box.position.y and start.y<box.end.y and start.z>box.position.z and start.z<box.end.z
	if inside:return {"inside":true,"time":0.0,"position":start,"normal":Vector3.UP}
	var delta:=finish-start
	var near:=-1.0e30;var far:=1.0;var normal:=Vector3.ZERO
	for axis in range(3):
		if absf(delta[axis])<1e-8:
			if start[axis]<box.position[axis] or start[axis]>box.end[axis]:return {}
			continue
		var first:float=(box.position[axis]-start[axis])/delta[axis]
		var last:float=(box.end[axis]-start[axis])/delta[axis]
		if first>last:var swap:=first;first=last;last=swap
		if first>near:
			near=first;normal=Vector3.ZERO;normal[axis]=-signf(delta[axis])
		far=minf(far,last)
		if near>far:return {}
	if near<0 or near>1 or far<0 or normal==Vector3.ZERO:return {}
	return {"inside":false,"time":near,"position":start+delta*near,"normal":normal}
