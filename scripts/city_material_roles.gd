extends RefCounted
# Render-only finishes for the compiled open-air city roots. These are modern
# classification rules, not names decoded from the original material words.
const Pads=preload("res://scripts/source_ground_pads.gd")
const Units=preload("res://scripts/source_units.gd")
const FACADE:=0
const ROAD:=1
const PAD:=2
const ROOF:=3
const CLEAN_EMISSION:=8
const GROUND_TOLERANCE_M:=0.35
const PAD_POINT_TOLERANCE_M:=0.1
const SMALL_LIGHT_AREA_M2:=4.0

static func context_for(profile:Dictionary,conversion_basis:Basis,compiled:Dictionary={})->Dictionary:
	var model:=int(profile.get("model_index",-1))
	var plane:Variant=profile.get("plane_normal_body",[])
	var matrix:Variant=profile.get("source_matrix_q31",[])
	var selected:Variant=profile.get("pad_offset_local_m",null)
	if model<81 or model>90 or not plane is Array or plane.size()!=3 or not matrix is Array or matrix.size()!=9 or not selected is Vector3:return {}
	if not conversion_basis.is_finite() or absf(conversion_basis.determinant())<0.000001 or not selected.is_finite():return {}
	var up:=conversion_basis*Vector3(float(plane[0]),float(plane[1]),float(plane[2]))
	if not up.is_finite() or up.length_squared()<0.000001:return {}
	up=up.normalized()
	var centres:Array[Vector3]=[]
	for point in Pads.transformed_positions(model,matrix):
		centres.append(conversion_basis*Vector3(Units.metres(float(point[0])),Units.metres(float(point[1])),Units.metres(float(point[2]))))
	var index:=int(profile.get("pad_index",-1))
	if index<0 or index>=centres.size() or centres[index].distance_to(selected)>PAD_POINT_TOLERANCE_M:return {}
	# The original model's ground plane passes through its local origin. F650
	# rounds a target before its final <<10: its native Y can be over a metre
	# off this plane at actual settlement orientations. Keep that physical target
	# intact, projecting it ONLY for this render-only primitive coverage check.
	var projected:Vector3=selected-up*selected.dot(up)
	var owners:Dictionary={}
	if model in [85,86,89] and compiled.get("ok",false) and int(compiled.get("model_index",-1))==model:
		for face:Dictionary in compiled.get("triangles_raw",[]):
			if not _known_pad_primitive(face,model):continue
			var vertices:Array[Vector3]=[]
			for point in face.vertices:
				vertices.append(conversion_basis*Vector3(Units.metres(float(point[0])),Units.metres(float(point[1])),Units.metres(float(point[2]))))
			if _covers_point(vertices,projected):owners[_owner(face)]=true
	return {"model_index":model,"ground_up":up,"ground_height":0.0,"selected_pad":selected,"selected_pad_projected":projected,"pad_centres":centres,"pad_index":index,"selected_pad_primitives":owners}

static func classify(face:Dictionary,normal:Vector3,vertices:Array,model_index:int,pad_context:Dictionary={})->int:
	var colour:=_colour(face)
	# Keep the historical no-context contract for generic source model previews.
	if model_index<81 or model_index>90 or int(pad_context.get("model_index",-1))!=model_index or not pad_context.has("ground_up") or vertices.size()!=3:
		return _palette_slot(colour,normal)
	var up:Vector3=pad_context.ground_up
	var alignment:=absf(normal.normalized().dot(up))
	var ground:=alignment>0.85
	for point:Vector3 in vertices:
		if absf(point.dot(up)-float(pad_context.ground_height))>GROUND_TOLERANCE_M:ground=false
	var role:=FACADE
	if ground:
		role=PAD if int(face.get("model_index",-1))==312 or pad_context.get("selected_pad_primitives",{}).has(_owner(face)) else ROAD
	elif alignment>0.35:
		role=ROOF
	# Small, bright unlit marks keep the clean original emission. This is a
	# conservative area/colour heuristic, not a recovered lamp/sign opcode.
	var code:=int(face.get("material_code",0))
	var source:Dictionary=face.get("material_base",{})
	var unlit:=bool(source.get("unlit",(code&0x2000)!=0))
	var high:=maxf(colour.r,maxf(colour.g,colour.b))
	var low:=minf(colour.r,minf(colour.g,colour.b))
	var area:=((vertices[1] as Vector3)-(vertices[0] as Vector3)).cross((vertices[2] as Vector3)-(vertices[0] as Vector3)).length()*0.5
	if not ground and unlit and area>0.000001 and area<=SMALL_LIGHT_AREA_M2 and high>=0.875 and (high-low>=0.25 or low>=0.875):role+=CLEAN_EMISSION
	return role

static func _known_pad_primitive(face:Dictionary,model_index:int)->bool:
	# These existing source primitives cover the independently recovered F650
	# target in roots without model312. F650 provides a point, not pad bounds.
	var child:=int(face.get("model_index",-1))
	var offset:=int(face.get("offset",-1))
	var material:=int(face.get("material_code",-1))
	return (model_index==85 and child==268 and offset==10 and material==0x6016) or (model_index==86 and child==271 and offset==196 and material==0x0444) or (model_index==89 and child==89 and offset==8 and material==0x4035)

static func _owner(face:Dictionary)->String:
	return "%s:%d:%d:%d"%[str(face.get("instance_path","")),int(face.get("model_index",-1)),int(face.get("offset",-1)),int(face.get("material_code",-1))]

static func _covers_point(vertices:Array,point:Vector3)->bool:
	var normal:Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0])
	if normal.length_squared()<0.0000000001:return false
	normal=normal.normalized()
	if absf((point-vertices[0]).dot(normal))>PAD_POINT_TOLERANCE_M:return false
	for index in range(3):
		var edge:Vector3=vertices[(index+1)%3]-vertices[index]
		if edge.cross(point-vertices[index]).dot(normal)<-PAD_POINT_TOLERANCE_M*edge.length():return false
	return true

static func _colour(face:Dictionary)->Color:
	var source:Dictionary=face.get("material_base",{})
	var code:=int(face.get("material_code",0))
	if source.get("textured",false):return Color("758892")
	var rgb:Array=source.get("rgb4_base",[(code>>8)&15,(code>>4)&15,code&15])
	return Color(clampf(float(rgb[0])/8.0,0,1),clampf(float(rgb[1])/8.0,0,1),clampf(float(rgb[2])/8.0,0,1))

static func _palette_slot(colour:Color,normal:Vector3)->int:
	var high:=maxf(colour.r,maxf(colour.g,colour.b))
	var low:=minf(colour.r,minf(colour.g,colour.b))
	if absf(normal.y)>0.75 and high<0.48:return ROAD
	if high-low>0.18:return PAD
	if absf(normal.y)>0.75 and high>0.65:return ROOF
	return FACADE
