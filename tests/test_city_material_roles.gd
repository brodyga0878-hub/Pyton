extends SceneTree
const Roles=preload("res://scripts/city_material_roles.gd")
const Pads=preload("res://scripts/source_ground_pads.gd")
const Units=preload("res://scripts/source_units.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const Profile=preload("res://scripts/source_city_profile.gd")
const Compiler=preload("res://scripts/source_model_mesh.gd")
const World=preload("res://scripts/planetary_system.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
var checks:=0
var failures:=0

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=20:push_error(message)

func _init()->void:call_deferred("run")

func packet(code:int,model:int=400,offset:int=0,path:String="fixture")->Dictionary:
	return {"model_index":model,"offset":offset,"instance_path":path,"material_code":code,"material_base":{"rgb4_base":[(code>>8)&15,(code>>4)&15,code&15],"unlit":(code&0x2000)!=0,"textured":(code>>14)!=0}}

func points(face:Dictionary,basis:Basis)->Array[Vector3]:
	var result:Array[Vector3]=[]
	for point in face.vertices:result.append(basis*Vector3(Units.metres(float(point[0])),Units.metres(float(point[1])),Units.metres(float(point[2]))))
	return result

func normal_for(face:Dictionary,vertices:Array,basis:Basis)->Vector3:
	var normal:Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
	if face.has("normal_raw"):
		var declared:=(basis*Vector3(float(face.normal_raw[0]),float(face.normal_raw[1]),float(face.normal_raw[2]))).normalized()
		if declared.length_squared()>0:normal=declared
	return normal

func fallback_contract()->void:
	var triangle:Array=[Vector3.ZERO,Vector3.RIGHT*10,Vector3.BACK*10]
	check(Roles.classify(packet(0x0333),Vector3.UP,triangle,84)==Roles.ROAD,"No-context dark horizontal preview retains its old slot")
	check(Roles.classify(packet(0x0800),Vector3.RIGHT,triangle,84)==Roles.PAD,"No-context coloured preview retains its old slot")
	check(Roles.classify(packet(0x0777),Vector3.UP,triangle,84)==Roles.ROOF,"No-context light horizontal preview retains its old slot")
	check(Roles.classify(packet(0x0444),Vector3.RIGHT,triangle,84)==Roles.FACADE,"No-context neutral vertical preview retains its old slot")
	check(Roles.classify(packet(0x2800),Vector3.RIGHT,[Vector3.ZERO,Vector3.UP,Vector3.BACK],12)==Roles.PAD,"Other source models keep the old preview contract without new flags")
	check(Roles.context_for({},Basis.IDENTITY).is_empty(),"An absent city profile does not invent pad context")
	check(Roles.context_for({"model_index":96},Basis.IDENTITY).is_empty(),"Unsupported underground cities do not get open-air material context")

func oriented_geometry()->void:
	# The actual city compiler is body-fixed: its ground is not necessarily Y=0.
	var up:=Vector3.FORWARD
	var context:={"model_index":84,"ground_up":up,"ground_height":0.0,"selected_pad":Vector3.ZERO,"selected_pad_primitives":{}}
	var floor:Array=[Vector3.ZERO,Vector3.RIGHT*10,Vector3.UP*10]
	check(Roles.classify(packet(0x2444),up,floor,84,context)==Roles.ROAD,"A rotated unlit ground face gets paving independent of world Y")
	check(Roles.classify(packet(0x2444),-up,floor,84,context)==Roles.ROAD,"Source triangle winding does not change the ground finish")
	var roof:Array=[]
	for point:Vector3 in floor:roof.append(point+up*20)
	check(Roles.classify(packet(0x2444),up,roof,84,context)==Roles.ROOF,"A parallel face above the source plane is a roof, not road or pad")
	var wall:Array=[Vector3.ZERO,Vector3.RIGHT*10,up*10]
	check(Roles.classify(packet(0x2800),Vector3.UP,wall,84,context)==Roles.FACADE,"A large saturated unlit wall stays a textured facade")
	check(Roles.classify(packet(0x2444,312),up,floor,84,context)==Roles.PAD,"Source model312 identifies an existing ground marker")
	check(Roles.classify(packet(0x2444,312),up,roof,84,context)==Roles.ROOF,"Model312 alone cannot turn a raised face into a landing pad")
	check(Roles.classify(packet(0x2444,382),up,floor,84,context)==Roles.ROAD,"The independent source382 ground overlay keeps its own paving finish")
	var small_wall:Array=[Vector3.ZERO,Vector3.RIGHT,up]
	check(Roles.classify(packet(0x2800),Vector3.UP,small_wall,84,context)==Roles.FACADE+Roles.CLEAN_EMISSION,"Small bright unlit colour marks retain clean emission")
	check(Roles.classify(packet(0x2888),Vector3.UP,small_wall,84,context)==Roles.FACADE+Roles.CLEAN_EMISSION,"Small white unlit marks also retain clean emission")
	check(Roles.classify(packet(0x0800),Vector3.UP,small_wall,84,context)==Roles.FACADE,"Lit small paint receives no emission flag")
	check(Roles.classify(packet(0x2444),Vector3.UP,small_wall,84,context)==Roles.FACADE,"A dim unlit wall does not become a clean light")
	check(Roles.classify(packet(0x2888),up,[Vector3.ZERO,Vector3.RIGHT,Vector3.UP],84,context)==Roles.ROAD,"Small white ground paint does not become a lamp")

func primitive_coverage()->void:
	var matrix:Array=[2147483647,0,0,0,2147483647,0,0,0,2147483647]
	var selected_index:=Pads.pick_highest_free(89)
	var raw:Array=Pads.transformed_positions(89,matrix)[selected_index]
	var selected:=Vector3(Units.metres(float(raw[0])),Units.metres(float(raw[1])),Units.metres(float(raw[2])))
	var profile:={"model_index":89,"plane_normal_body":[0,1,0],"source_matrix_q31":matrix,"pad_offset_local_m":selected,"pad_index":selected_index}
	var before:=var_to_bytes(profile)
	var corners:Array=[selected+Vector3(-10,0,-20),selected+Vector3(30,0,-20),selected+Vector3(30,0,20),selected+Vector3(-10,0,20)]
	var faces:Array=[]
	for indices in [[0,1,2],[0,2,3]]:
		var face:=packet(0x4035,89,8,"89/selected")
		face.vertices=[]
		for index:int in indices:
			var point:Vector3=corners[index]
			face.vertices.append([Units.raw(point.x),Units.raw(point.y),Units.raw(point.z)])
		faces.append(face)
	var other:Dictionary=faces[0].duplicate(true);other.instance_path="89/other"
	for point:Array in other.vertices:point[0]=float(point[0])+Units.raw(1000)
	faces.append(other)
	var unknown:Dictionary=faces[1].duplicate(true);unknown.model_index=999;unknown.instance_path="89/unknown";faces.append(unknown)
	var compiled:={"ok":true,"model_index":89,"triangles_raw":faces}
	var packets_before:=var_to_bytes(compiled)
	var context:=Roles.context_for(profile,Basis.IDENTITY,compiled)
	check(not context.is_empty() and context.selected_pad_primitives.size()==1,"Only a verified primitive covering the selected native point receives pad finish")
	for index in range(2):
		check(Roles.classify(faces[index],Vector3.UP,points(faces[index],Basis.IDENTITY),89,context)==Roles.PAD,"Both triangles in the same selected source primitive share pad finish without a diagonal seam")
	check(Roles.classify(other,Vector3.UP,points(other,Basis.IDENTITY),89,context)==Roles.ROAD,"Another instance of the exact source primitive stays paving")
	check(Roles.classify(unknown,Vector3.UP,points(unknown,Basis.IDENTITY),89,context)==Roles.ROAD,"Unknown source geometry covering F650's point does not acquire pad semantics")
	var without_compiled:=Roles.context_for(profile,Basis.IDENTITY)
	check(Roles.classify(faces[1],Vector3.UP,points(faces[1],Basis.IDENTITY),89,without_compiled)==Roles.ROAD,"A target point without a verified primitive does not invent pad dimensions")
	check(var_to_bytes(profile)==before and var_to_bytes(compiled)==packets_before,"Context construction and classification leave source profile and face packets byte-identical")
	var bad:Dictionary=profile.duplicate(true);bad.pad_offset_local_m+=Vector3.RIGHT
	check(Roles.context_for(bad,Basis.IDENTITY,compiled).is_empty(),"A profile with inconsistent selected native point is rejected")
	bad=profile.duplicate(true);bad.plane_normal_body=[0,0,0]
	check(Roles.context_for(bad,Basis.IDENTITY).is_empty(),"A degenerate ground plane is rejected")
	check(Roles.context_for(profile,Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)).is_empty(),"A singular coordinate conversion is rejected")

func compiled_city_controls()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ground_pads_reference.json"))
	var total_triangles:=0
	var total_clean:=0
	var total_ground_lit:=0
	var total_ground_unlit:=0
	for model in range(81,91):
		var native:Dictionary={}
		for row:Dictionary in fixture.cases:
			if int(row.model_index)==model and row.origin=="all_free" and row.get("matrix_source")=="original_f1674":native=row;break
		check(not native.is_empty(),"Native F1674/F650 fixture exists for source root%d"%model)
		if native.is_empty():continue
		var site:=Ground.from_record(int(native.ground_phase_u16),int(native.ground_inclination_u16))
		site.merge({"id":"material-control%d"%model,"type_code":35,"model_index":model,"source_seed":0xbdd3aa2e})
		var profile:=Profile.describe(site,6371000.0)
		var compiled:=Compiler.new().compile(model,{"source_seed":int(profile.source_seed),"matrix_q31":profile.source_matrix_q31})
		check(compiled.get("ok",false),"Original source root%d compiles with its native body-fixed matrix"%model)
		if not compiled.get("ok",false):continue
		var source_before:=var_to_bytes(compiled.triangles_raw)
		var profile_before:=var_to_bytes(profile)
		var conversion:Basis=profile.root_basis.inverse()
		var context:=Roles.context_for(profile,conversion,compiled)
		check(not context.is_empty(),"Original source root%d has a consistent render material context"%model)
		if context.is_empty():continue
		var counts:Array=[0,0,0,0]
		var markers:=0
		var clean:=0
		var ground_lit:=0
		var ground_unlit:=0
		for face:Dictionary in compiled.triangles_raw:
			var vertices:=points(face,conversion)
			var normal:=normal_for(face,vertices,conversion)
			var slot:=Roles.classify(face,normal,vertices,model,context)
			check(slot in [0,1,2,3,8,9,10,11],"Root%d emits only four roles and the reserved clean emission flag"%model)
			var role:=slot%8
			counts[role]+=1
			if slot>=8:
				clean+=1
				check(bool(face.material_base.unlit),"Clean emission never changes a lit source face into a lamp")
			if role in [Roles.ROAD,Roles.PAD]:
				if face.material_base.unlit:ground_unlit+=1
				else:ground_lit+=1
			if int(face.model_index)==312:
				markers+=1
				check(role==Roles.PAD,"Every original312 ground marker remains a pad finish in native root%d"%model)
		check(counts[Roles.FACADE]>0 and counts[Roles.ROAD]>0 and counts[Roles.PAD]>0 and counts[Roles.ROOF]>0,"Each actual source city has classified facades, ground, pads and roofs: root%d %s"%[model,str(counts)])
		if model in [85,86,89]:
			check(markers==0 and context.selected_pad_primitives.size()==1,"Root%d without312 uses exactly one verified selected source primitive"%model)
		else:
			check(markers==int(profile.pad_count)*4 and context.selected_pad_primitives.is_empty(),"Root%d retains the original marker geometry without a floor fallback"%model)
		check(var_to_bytes(compiled.triangles_raw)==source_before and var_to_bytes(profile)==profile_before,"All original city%d vertices, normals, colour/material words and source flags remain byte-identical"%model)
		total_triangles+=compiled.triangle_count;total_clean+=clean;total_ground_lit+=ground_lit;total_ground_unlit+=ground_unlit
		print("city_material_roles root%d roles=%s clean=%d ground_lit/unlit=%d/%d"%[model,str(counts),clean,ground_lit,ground_unlit])
	check(total_triangles>100000 and total_ground_unlit>total_ground_lit,"Actual city packets exercise predominantly unlit ground rather than only synthetic materials")
	check(total_clean>0,"Actual source geometry exercises the conservative small clean emission path")
	print("city_material_roles actual_triangles=%d clean=%d ground_lit/unlit=%d/%d"%[total_triangles,total_clean,total_ground_lit,total_ground_unlit])

func actual_settlement_planes()->void:
	# Zero-angle matrix controls cannot expose F650's rounded off-plane Y.
	# These are persistent catalogue sites with their actual angles and UIDs.
	var records:Array=[[111466264,"site11","Epping Newtown"],[111466264,"site10","Manchester"],[44341016,"site7","Paris"],[44341016,"site6","London"],[44349207,"site5","Amundsen"],[44341016,"site8","Tokyo"],[44341016,"site10","New Moscow"]]
	var above:=0.0;var below:=0.0;var total:=0
	for record:Array in records:
		var world:=World.new();world.configure(Galaxy.new().get_system(int(record[0])))
		var site:=world.get_site(str(record[1]))
		check(not site.is_empty() and str(site.name_en)==str(record[2]),"Actual material regression resolves catalogue site: "+str(record[2]))
		if site.is_empty():continue
		var profile:=Profile.describe(site,float(world.by_id[str(site.parent)].radius_km)*1000.0)
		var compiled:=Compiler.new().compile(int(profile.model_index),{"source_seed":int(profile.source_seed),"matrix_q31":profile.source_matrix_q31})
		check(compiled.get("ok",false),"Actual material regression compiles catalogue site: "+str(record[2]))
		if not compiled.get("ok",false):continue
		var source_before:=var_to_bytes(compiled.triangles_raw);var profile_before:=var_to_bytes(profile)
		var conversion:Basis=profile.root_basis.inverse()
		var context:=Roles.context_for(profile,conversion,compiled)
		check(not context.is_empty(),"Actual catalogue city has render context: "+str(record[2]))
		if context.is_empty():continue
		var native_height:float=context.selected_pad.dot(context.ground_up)
		above=maxf(above,native_height);below=minf(below,native_height)
		check(context.ground_height==0.0 and context.selected_pad==profile.pad_offset_local_m,"Render ground stays at original model origin while native F650 target stays intact: "+str(record[2]))
		check(absf((context.selected_pad_projected as Vector3).dot(context.ground_up))<0.0001,"Only the render coverage target is projected onto the original plane: "+str(record[2]))
		var counts:Array=[0,0,0,0]
		for face:Dictionary in compiled.triangles_raw:
			var vertices:=points(face,conversion)
			counts[Roles.classify(face,normal_for(face,vertices,conversion),vertices,int(profile.model_index),context)%8]+=1
		check(counts[0]>0 and counts[1]>0 and counts[2]>0 and counts[3]>0,"Actual rotated city retains ground and pads despite native target rounding: %s %s"%[str(record[2]),str(counts)])
		if int(profile.model_index)==85:check(context.selected_pad_primitives.size()==1,"Actual Amundsen covers one confirmed source primitive after render-only target projection")
		check(var_to_bytes(compiled.triangles_raw)==source_before and var_to_bytes(profile)==profile_before,"Actual city source faces and native target profile remain byte-identical: "+str(record[2]))
		total+=int(compiled.triangle_count)
		print("city_material_roles actual %s native_target_height=%.6fm roles=%s"%[str(record[2]),native_height,str(counts)])
	check(above>1.0 and below<(-1.0),"Actual regression covers native F650 targets above and below the original render plane")
	print("city_material_roles catalogue_triangles=%d"%total)

func run()->void:
	fallback_contract();oriented_geometry();primitive_coverage();compiled_city_controls();actual_settlement_planes()
	print("city_material_roles: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
