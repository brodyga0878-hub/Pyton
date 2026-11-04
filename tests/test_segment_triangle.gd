extends SceneTree
const Sweep=preload("res://scripts/segment_triangle.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<16:push_error(message)
func tri(a:Vector3,b:Vector3,c:Vector3)->Array[Vector3]:return [a,b,c]
func expect(hit:Dictionary,time:float,position:Vector3,normal:Vector3,label:String,tolerance:=0.00001)->void:
	check(not hit.is_empty(),label+": contact exists")
	if hit.is_empty():return
	check(is_finite(float(hit.time)) and float(hit.time)>=0 and float(hit.time)<=1 and absf(float(hit.time)-time)<tolerance,label+": earliest bounded time")
	check(Vector3(hit.position).distance_to(position)<tolerance,label+": correct center at contact")
	check(Vector3(hit.normal).is_finite() and Vector3(hit.normal).distance_to(normal)<tolerance and absf(Vector3(hit.normal).length()-1)<tolerance,label+": finite unit normal")
func earliest(start:Vector3,finish:Vector3,faces:Array,radii:Vector3)->Dictionary:
	var best:Dictionary={}
	for face in faces:
		var hit:=Sweep.sweep(start,finish,face,radii)
		if not hit.is_empty() and float(hit.time)<float(best.get("time",INF)):best=hit
	return best
func transformed(face:Array[Vector3],rotation:Quaternion,offset:Vector3)->Array[Vector3]:
	var result:Array[Vector3]=[]
	for point in face:result.append(rotation*point+offset)
	return result
func _init()->void:call_deferred("run")
func run()->void:
	var floor:=tri(Vector3(-100,0,-100),Vector3(100,0,-100),Vector3(0,0,100))
	var wall:=tri(Vector3(0,-100,-100),Vector3(0,100,-100),Vector3(0,0,100))
	var corner:=tri(Vector3.ZERO,Vector3(10,0,0),Vector3(0,10,0))
	var reverse:=tri(floor[2],floor[1],floor[0])
	var face_hit:=Sweep.sweep(Vector3(0,5,0),Vector3(0,-5,0),floor,Vector3.ONE)
	expect(face_hit,0.4,Vector3.UP,Vector3.UP,"front floor")
	check(not face_hit.get("inside",true),"A future face contact is not an initial overlap")
	expect(Sweep.sweep(Vector3(0,-5,0),Vector3(0,5,0),floor,Vector3.ONE),0.4,Vector3.DOWN,Vector3.DOWN,"double-sided floor")
	expect(Sweep.sweep(Vector3(0,5,0),Vector3(0,-5,0),reverse,Vector3.ONE),0.4,Vector3.UP,Vector3.UP,"winding independence")
	expect(Sweep.sweep(Vector3(5,0,0),Vector3(-5,0,0),wall,Vector3.ONE),0.4,Vector3.RIGHT,Vector3.RIGHT,"vertical facade")
	expect(Sweep.sweep(Vector3(0,20,0),Vector3.ZERO,floor,Vector3(23,7.88,23)),(20-7.88)/20,Vector3(0,7.88,0),Vector3.UP,"ship floor clearance")
	expect(Sweep.sweep(Vector3(50,0,0),Vector3.ZERO,wall,Vector3(23,7.88,23)),(50-23.0)/50,Vector3(23,0,0),Vector3.RIGHT,"ship facade width")
	var edge_time:=(3.0-0.8)/6.0
	expect(Sweep.sweep(Vector3(5,-0.6,3),Vector3(5,-0.6,-3),corner,Vector3.ONE),edge_time,Vector3(5,-0.6,0.8),Vector3(0,-0.6,0.8),"finite edge cylinder")
	expect(Sweep.sweep(Vector3(5,-3,0),Vector3(5,3,0),corner,Vector3.ONE),1.0/3.0,Vector3(5,-1,0),Vector3.DOWN,"coplanar edge approach")
	expect(Sweep.sweep(Vector3(-3,-0.6,0),Vector3(13,-0.6,0),corner,Vector3.ONE),(3.0-0.8)/16.0,Vector3(-0.8,-0.6,0),Vector3(-0.8,-0.6,0),"parallel edge approach meets its finite cap")
	var vertex_height:=sqrt(0.28)
	var vertex_time:=(3.0-vertex_height)/6.0
	expect(Sweep.sweep(Vector3(-0.6,-0.6,3),Vector3(-0.6,-0.6,-3),corner,Vector3.ONE),vertex_time,Vector3(-0.6,-0.6,vertex_height),Vector3(-0.6,-0.6,vertex_height),"vertex sphere")
	expect(Sweep.sweep(Vector3(5,-0.6,3),Vector3(5,-0.6,-3),corner,Vector3(2,1,0.5)),(3.0-0.4)/6.0,Vector3(5,-0.6,0.4),Vector3(0,-0.6,1.6).normalized(),"anisotropic edge normal")
	check(Sweep.sweep(Vector3(9,9,3),Vector3(9,9,-3),corner,Vector3.ONE).is_empty(),"A projected point inside a triangle AABB can still miss the actual triangle")
	check(Sweep.sweep(Vector3(-1.1,-1.1,3),Vector3(-1.1,-1.1,-3),corner,Vector3.ONE).is_empty(),"A finite vertex sphere does not become an infinite edge plane")
	var hangar:Array=[
		tri(Vector3(-10,-5,0),Vector3(-3,-5,0),Vector3(-3,5,0)),
		tri(Vector3(-10,-5,0),Vector3(-3,5,0),Vector3(-10,5,0)),
		tri(Vector3(3,-5,0),Vector3(10,-5,0),Vector3(10,5,0)),
		tri(Vector3(3,-5,0),Vector3(10,5,0),Vector3(3,5,0))]
	check(earliest(Vector3(0,0,5),Vector3(0,0,-5),hangar,Vector3.ONE).is_empty(),"An open hangar remains passable instead of colliding with the combined city AABB")
	var jamb_height:=sqrt(0.75)
	expect(earliest(Vector3(2.5,0,5),Vector3(2.5,0,-5),hangar,Vector3.ONE),(5-jamb_height)/10.0,Vector3(2.5,0,jamb_height),Vector3(-0.5,0,jamb_height),"hangar jamb earliest edge")
	expect(Sweep.sweep(Vector3(0,1000000000,0),Vector3(0,-1000000000,0),floor,Vector3.ONE),(1000000000.0-1)/2000000000.0,Vector3.UP,Vector3.UP,"high-speed face tunneling",0.0001)
	expect(Sweep.sweep(Vector3(-0.6,-0.6,1000000000),Vector3(-0.6,-0.6,-1000000000),corner,Vector3.ONE),(1000000000.0-vertex_height)/2000000000.0,Vector3(-0.6,-0.6,vertex_height),Vector3(-0.6,-0.6,vertex_height),"high-speed vertex tunneling",0.0001)
	check(Sweep.sweep(Vector3(0,5,0),Vector3(0,2,0),floor,Vector3.ONE).is_empty(),"Contact beyond the end of a segment is not returned")
	expect(Sweep.sweep(Vector3(0,5,0),Vector3.UP,floor,Vector3.ONE),1.0,Vector3.UP,Vector3.UP,"contact at segment endpoint")
	expect(Sweep.sweep(Vector3.UP,Vector3(0,-5,0),floor,Vector3.ONE),0.0,Vector3.UP,Vector3.UP,"initial touching inward")
	check(Sweep.sweep(Vector3.UP,Vector3(0,5,0),floor,Vector3.ONE).is_empty(),"A separating face contact does not trap the ship")
	check(Sweep.sweep(Vector3.UP,Vector3(5,1,0),floor,Vector3.ONE).is_empty(),"Tangential movement along a floor is not blocked")
	check(Sweep.sweep(Vector3(5,-1,3),Vector3(5,-1,-3),corner,Vector3.ONE).is_empty(),"An exact grazing edge tangent does not create an impact")
	check(Sweep.sweep(Vector3(-3,-1,0),Vector3(3,-1,0),corner,Vector3.ONE).is_empty(),"A grazing vertex followed by tangency along an edge does not create an impact")
	var overlap:=Sweep.sweep(Vector3(0,0.5,0),Vector3(0,5,0),floor,Vector3.ONE)
	expect(overlap,0,Vector3.UP,Vector3.UP,"initial penetration resolution")
	check(overlap.get("inside",false),"Strict initial penetration is identified independently of separating velocity")
	expect(Sweep.sweep(Vector3(0,4,0),Vector3(0,4,0),floor,Vector3(23,7.88,23)),0,Vector3(0,7.88,0),Vector3.UP,"anisotropic initial clearance resolution")
	var edge_out:=Vector3(0,-1,1).normalized()
	var edge_overlap:=Sweep.sweep(Vector3(5,-0.5,0.5),Vector3(5,-0.5,0.5),corner,Vector3.ONE)
	expect(edge_overlap,0,Vector3(5,edge_out.y,edge_out.z),edge_out,"static edge penetration")
	check(edge_overlap.get("inside",false),"A stationary edge overlap is resolved without requiring velocity")
	expect(Sweep.sweep(Vector3.ZERO,Vector3.ZERO,floor,Vector3.ONE),0,Vector3.UP,Vector3.UP,"center exactly on face")
	expect(Sweep.sweep(Vector3.ZERO,Vector3.ZERO,reverse,Vector3.ONE),0,Vector3.UP,Vector3.UP,"stationary overlap winding independence")
	check(Sweep.sweep(Vector3(0,3,0),Vector3(0,3,0),floor,Vector3.ONE).is_empty(),"A stationary separated vessel has no contact")
	check(Sweep.sweep(Vector3.UP,Vector3.UP,floor,Vector3.ONE).is_empty(),"A static touching vessel does not repeatedly collide")
	var line:=tri(Vector3(-10,0,0),Vector3(10,0,0),Vector3.ZERO)
	var point:=tri(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
	expect(Sweep.sweep(Vector3(0,3,0),Vector3(0,-3,0),line,Vector3.ONE),1.0/3.0,Vector3.UP,Vector3.UP,"degenerate segment triangle")
	expect(Sweep.sweep(Vector3(0,3,0),Vector3(0,-3,0),point,Vector3.ONE),1.0/3.0,Vector3.UP,Vector3.UP,"degenerate point triangle")
	var long_edge:=tri(Vector3.ZERO,Vector3(1000000,0,0),Vector3(1000000,0,0))
	expect(Sweep.sweep(Vector3(1000000.5,0,3),Vector3(1000000.5,0,-3),long_edge,Vector3.ONE),(3-sqrt(0.75))/6.0,Vector3(1000000.5,0,sqrt(0.75)),Vector3(0.5,0,sqrt(0.75)),"a long finite edge ends in its vertex sphere")
	expect(Sweep.sweep(Vector3.ZERO,Vector3.ZERO,point,Vector3.ONE),0,Vector3.UP,Vector3.UP,"stationary point overlap")
	var empty:Array[Vector3]=[]
	check(Sweep.sweep(Vector3.UP,Vector3.DOWN,empty,Vector3.ONE).is_empty(),"Missing triangle geometry is rejected")
	for invalid in [Vector3.ZERO,Vector3(-1,1,1),Vector3(1,INF,1)]:
		check(Sweep.sweep(Vector3.UP,Vector3.DOWN,floor,invalid).is_empty(),"Non-positive or non-finite ellipsoid radii are rejected")
	check(Sweep.sweep(Vector3(INF,0,0),Vector3.ZERO,floor,Vector3.ONE).is_empty(),"Non-finite motion is rejected")
	var rotation:=Quaternion(Vector3(1,2,3).normalized(),0.73)
	var shift:=Vector3(3000,-4000,5000)
	var cases:Array=[
		{"triangle":floor,"start":Vector3(0,5,0),"finish":Vector3(0,-5,0)},
		{"triangle":corner,"start":Vector3(5,-0.6,3),"finish":Vector3(5,-0.6,-3)},
		{"triangle":corner,"start":Vector3(-0.6,-0.6,3),"finish":Vector3(-0.6,-0.6,-3)}]
	for case in cases:
		var base:=Sweep.sweep(case.start,case.finish,case.triangle,Vector3.ONE)
		var moved:=Sweep.sweep(case.start+shift,case.finish+shift,transformed(case.triangle,Quaternion.IDENTITY,shift),Vector3.ONE)
		expect(moved,float(base.time),Vector3(base.position)+shift,base.normal,"translation invariance",0.002)
		var turned:=Sweep.sweep(rotation*case.start,rotation*case.finish,transformed(case.triangle,rotation,Vector3.ZERO),Vector3.ONE)
		expect(turned,float(base.time),rotation*Vector3(base.position),rotation*Vector3(base.normal),"uniform sphere rotation invariance",0.0001)
	check(Sweep.sweep(Vector3(0,5,0),Vector3(0,3,0),floor,Vector3.ONE).is_empty(),"A step before contact remains free")
	var second_step:=Sweep.sweep(Vector3(0,3,0),Vector3(0,-5,0),floor,Vector3.ONE)
	check(not second_step.is_empty() and absf(0.2+0.8*float(second_step.time)-float(face_hit.time))<0.00001,"Splitting a movement before impact preserves the global earliest contact")
	print("SEGMENT TRIANGLE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
