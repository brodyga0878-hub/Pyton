extends SceneTree
const Compiler=preload("res://scripts/source_model_mesh.gd")
const VM=preload("res://scripts/source_model_vm.gd")
var checks:=0
var failures:=0
func check(condition:bool,message:String)->void:
	checks+=1
	if not condition:failures+=1;printerr(message)
func _initialize()->void:
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/model_vertices_reference.json"))
	var leaves:Array=[302,312,366,392,393,394,395,396,269]
	for sample in reference.cases:
		if int(sample.model_index) not in leaves:continue
		var context:Dictionary=reference.contexts[int(sample.context_index)].duplicate(true)
		var before:=JSON.stringify(context)
		var result:=Compiler.new().compile(int(sample.model_index),context)
		check(result.ok,"Native leaf failed: %d/%d %s"%[sample.model_index,sample.context_index,result.get("error","")])
		if not result.ok:continue
		check(JSON.stringify(context)==before,"Compiler mutated supplied context")
		var source_vertices:={}
		for vertex in sample.vertices_local_raw:
			var normalized:Array=[]
			for coordinate in vertex:normalized.append(int(coordinate))
			source_vertices[JSON.stringify(normalized)]=true
		for triangle in result.triangles_raw:
			for vertex in triangle.vertices:check(source_vertices.has(JSON.stringify(vertex)),"Leaf triangle vertex differs from actual native fixture")
		check(result.triangle_count>0,"Static leaf produced no triangles")
	# Strict failures are part of the contract: no invented assets, parent
	# anchors, door variables or undefined source orientations.
	check(not Compiler.new().compile(900).ok,"Unknown asset was fabricated")
	check(not Compiler.new().compile(302).ok,"Uninitialized hangar door parameter accepted")
	check(not Compiler.new().compile(312,{"matrix_q31":[1,2]}).ok,"Invalid matrix accepted")
	check(not Compiler.new().compile(312,{"scale_shift_raw":31}).ok,"Undefined physical scale accepted")
	var pad:=Compiler.new().compile(312)
	check(pad.ok and pad.triangle_count==4,"Original six-sided pad topology changed")
	var pad_area:=0.0
	for triangle in pad.triangles_raw:
		var a:Array=triangle.vertices[0];var b:Array=triangle.vertices[1];var c:Array=triangle.vertices[2]
		check(int(a[1])==0 and int(b[1])==0 and int(c[1])==0,"Pad is not source-horizontal")
		pad_area+=absf((float(b[0])-float(a[0]))*(float(c[2])-float(a[2]))-(float(b[2])-float(a[2]))*(float(c[0])-float(a[0])))*0.5
	check(pad_area>0,"Pad lost its polygon area")
	# Raw source units already include each node's binary exponent. Root pad
	# extents are exactly native Q31 transformed source coordinates <<12.
	check(pad.bounds_raw.minimum==[-327679,0,-299008],"Original pad minimum bounds changed")
	check(pad.bounds_raw.maximum==[327679,0,299007],"Original pad maximum bounds changed")
	for code in [0,0x123,0x1000,0x1abc,0x2000,0x4abc,0x5000,0x8001,0xc001]:
		var rgb:Array=[250,1,20];var material:=VM.material_base(code,rgb)
		check(material.textured==bool(code>>14),"Original texture discrimination changed")
		check(material.unlit==bool(code&0x2000),"Original unlit flag changed")
		var expected:Array=[0,0,0] if code>>14 else [(code>>8)&15,(code>>4)&15,code&15]
		if code&0x1000:
			for k in range(3):expected[k]=(int(expected[k])+int(rgb[k]))&255
		check(material.rgb4_base==expected,"Original local colour byte addition changed")
	# Real city programs exercise model composition, exact UID-selected
	# variants, source pads, dynamic hangars and static observer-normal union.
	for index in range(81,91):
		var result:=Compiler.new().compile(index,{"source_seed":0xbdd3aa2e})
		check(result.ok,"Original city %d failed: %s"%[index,result.get("error","")])
		if not result.ok:continue
		check(result.triangle_count>1000 and result.instance_count>20,"City lost its original composition")
		var minimum:Array=result.bounds_raw.minimum;var maximum:Array=result.bounds_raw.maximum
		for k in range(3):check(int(minimum[k])<=int(maximum[k]),"Inverted source city bounds")
		var pad_count:=0
		for instance in result.instances:
			if int(instance.model_index)==312:
				pad_count+=1
				check(instance.matrix_q31.size()==9,"Pad lost native orientation")
				check(int(instance.scale_shift_raw)==12,"Pad was incorrectly scaled by its parent model")
				for k in range(3):check(int(instance.origin_raw[k])>=int(minimum[k]) and int(instance.origin_raw[k])<=int(maximum[k]),"Source landing pad origin outside compiled bounds")
		check((pad_count>0)==(index in [81,82,83,84,87,88,90]),"City changed its original hex-pad family")
		for triangle in result.triangles_raw:
			if index==89:
				if int(triangle.model_index)==89 and int(triangle.offset)==8:
					check(triangle.sort_hint_kind=="forced_forward_offset" and int(triangle.sort_depth_hint_raw)==1228800,"Root ground painter hint changed")
				if int(triangle.model_index)==277 and int(triangle.offset)==118:
					check(triangle.sort_hint_kind=="forced_forward_offset" and int(triangle.sort_depth_hint_raw)==4096000,"Tile background painter hint changed")
				if int(triangle.model_index)==288 and int(triangle.offset) in [46,66,90,110]:
						check(triangle.sort_hint_kind=="forced_forward_offset" and int(triangle.sort_depth_hint_raw)==499712,"Landing-zone decoration painter hint changed")
			for vertex in triangle.vertices:
				for k in range(3):
					if int(vertex[k])<int(minimum[k]) or int(vertex[k])>int(maximum[k]):check(false,"Triangle outside returned source bounds")
		print("Source city ",index,": ",result.triangle_count," triangles, ",result.instance_count," instances, ",pad_count," pads")
	for index in range(72,81):
		var context:={"source_seed":0xbdd3aa2e,"frame_parameters":[0,0,0,0,0,0,0,0]}
		var before:=JSON.stringify(context)
		var result:=Compiler.new().compile(index,context)
		check(result.ok,"Original orbital %d failed: %s"%[index,result.get("error","")])
		if not result.ok:continue
		check(result.triangle_count>100,"Orbital lost its original body geometry")
		check(JSON.stringify(context)==before,"Orbital compiler mutated supplied static state")
	for index in [83,85,86,87]:
		var result:=Compiler.new().compile(index,{"source_seed":0xffffffff})
		check(result.ok,"Original UID variant %d failed: %s"%[index,result.get("error","")])
		if result.ok:check(result.triangle_count>1000,"UID variant lost its source geometry")
	print("Source model mesh: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
