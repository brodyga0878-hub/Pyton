extends SceneTree
const Hangar=preload("res://scripts/source_underground_port.gd")
const VM=preload("res://scripts/source_model_vm.gd")
const City=preload("res://scripts/source_city_runtime.gd")
const Placement=preload("res://scripts/source_city_profile.gd")
const Units=preload("res://scripts/source_units.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<35:push_error(message)
func load_json(path:String)->Dictionary:
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}
func integers(value:Array)->Array:
	var result:Array=[]
	for item in value:result.append(int(item))
	return result
func native_controls()->void:
	var fixture:=load_json("res://tests/fixtures/source_underground_native.json")
	check(fixture.get("source_executable_sha256")=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72","Enclosed hangar uses uploaded original source image")
	check(fixture.get("source_assembly_sha256")=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a" and int(fixture.get("case_count",0))==480,"Actual F650/F741 assembly controls are complete")
	check(fixture.get("fresh_process_runs")==3 and fixture.get("reverse_repeat_count")==480,"Independent instruction controls repeat fresh and reversed")
	for row:Dictionary in fixture.get("cases",[]):
		var original:=var_to_bytes(row.occupancy_before_u8)
		var result:=Hangar.reserve(row.npc_id_i32,row.occupancy_before_u8,integers(row.matrix_q31),5 if int(row.last_slot_override_i32)==-2 else int(row.last_slot_override_i32))
		check(not result.is_empty(),"Enclosed F650 valid native context")
		for key in ["return_i32","initialized_last_slot_i32"]:check(result.get(key)==row.expected[key],"Native enclosed F650 "+str(key))
		check(integers(result.occupancy_after_u8)==integers(row.expected.occupancy_after_u8),"Native enclosed F650 occupancy bytes")
		if int(row.expected.return_i32)==0:
			for key in ["allocation_status_i32","selected_slot_i32"]:check(result.get(key)==row.expected[key],"Native non-openpad target "+str(key))
			check(integers(result.target_vec64_raw)==integers(row.expected.target_vec64_raw),"Native non-openpad sentinel target")
		else:
			check(not result.has("target_vec64_raw") and not result.has("allocation_status_i32"),"Failed reservation does not fabricate target outputs")
		check(Hangar.approach_raw(integers(row.matrix_q31))==integers(row.expected.approach_raw),"Native F741 signed16 ground waypoint and F1669 Q31 rounding")
		check(var_to_bytes(row.occupancy_before_u8)==original,"Reservation does not mutate caller occupancy")
	check(Hangar.reserve(7,[0,0,0,0,0,0],[],5).is_empty() and Hangar.reserve(7,[0,0,0,0,0,0],[1,0,0,0,1,0,0,0,1],6).is_empty(),"Invalid reservation domains rejected atomically")
func source_assets()->void:
	var base:=load_json("res://data/ffe_world_models.json");var overlay:=load_json("res://data/ffe_underground_models.json")
	check(integers(overlay.get("new_model_indices",[]))==[96,162,237,267,301] and overlay.get("models",{}).size()==36,"Actual model96 reachable closure adds exactly five missing source models")
	var shared:=0
	for key in overlay.get("models",{}):
		if base.models.has(key):
			check(overlay.models[key]==base.models[key] and VM.model(int(key))==base.models[key],"Shared model bytes and base lookup precedence preserved "+str(key));shared+=1
	check(shared==31,"All31 shared source models remain identical")
	for index in range(81,91):check(VM.model(index)==base.models[str(index)],"All legacy open ground-port model assets unchanged")
	check(VM.model(96).descriptor_sha256=="4ca90e4d2299918305bda2c013c0aa3d083d224def9b3e12c3276e0750e0fbea","Actual original enclosed hangar descriptor present")
func site(id:String,phase:int,inclination:int)->Dictionary:
	return {"id":id,"type_code":35,"model_index":96,"source_seed":0xd1d76465,"ground_phase_u16":phase,"ground_inclination_u16":inclination}
func state_controls(profile:Dictionary,radii:Vector3,planned:Dictionary)->void:
	var state:=Hangar.new_state(str(profile.site_id));var before:=var_to_bytes(state)
	var opening:=Hangar.command(state,"dock")
	check(state.phase=="closed" and var_to_bytes(state)==before and opening.phase=="opening" and opening.status_u8==255,"Arrival explicitly requests F654 hatch opening without modifying supplied state")
	var restored:=Hangar.restore(JSON.parse_string(JSON.stringify(opening)),str(profile.site_id))
	check(restored==opening,"Opening state survives plain JSON save/restore")
	var opened:=Hangar.advance(restored,131072,profile,planned.entrance_local_m,radii)
	check(opened.phase=="approach" and opened.door_u16==0,"Original F865 reaches open hatch before approach is enabled")
	var inside:=Hangar.advance(opened,0,profile,planned.interior_local_m,radii)
	check(inside.phase=="inside","Actual enclosed volume identifies interior after crossing roof")
	var no_contact:=Hangar.advance(inside,0,profile,planned.interior_local_m,radii)
	check(no_contact.phase=="inside","Interior proximity alone does not grant dock services")
	var aborted:=Hangar.advance(inside,0,profile,planned.entrance_local_m,radii)
	check(aborted.phase=="closing" and Hangar.advance(aborted,131072,profile,planned.outer_local_m,radii).phase=="closed","Manual departure from interior completes aborted approach")
	var landed:=Hangar.advance(inside,0,profile,planned.interior_local_m,radii,true)
	check(landed.phase=="docked" and landed.status_u8==3,"Accepted surface contact enables F652 closing and dock services")
	var closed:=Hangar.advance(landed,131072,profile,planned.interior_local_m,radii,true)
	check(closed.phase=="docked" and closed.door_u16==65535,"Interior docking can seal original roof above ship")
	var launch:=Hangar.command(closed,"launch")
	check(launch.phase=="opening" and launch.intent=="launch","Takeoff has an explicit launch path even with sealed hatch")
	var departing:=Hangar.advance(launch,131072,profile,planned.interior_local_m,radii)
	check(departing.phase=="departing" and departing.door_u16==0,"Launch waits for fully open source geometry")
	var leaving:=Hangar.advance(departing,0,profile,planned.entrance_local_m,radii)
	check(leaving.phase=="closing","Hatch may close only after the whole ship clears its roof")
	var crossing:=Hangar.advance(leaving,10000,profile,planned.hatch_center_local_m,radii)
	check(crossing.door_u16==0,"Closing hatch reopens while hull intersects aperture")
	var edge:Vector3=profile.port_basis_local*Vector3(190,float(profile.hatch_height_source_m),0)
	var edge_class:=Hangar.classify(profile,edge,radii)
	check(not edge_class.lateral_inside and edge_class.aperture_overlap,"Source roof-edge overlap is distinct from whole-hull entry clearance")
	check(Hangar.advance(leaving,10000,profile,edge,radii).door_u16==0,"Closing hatch also reopens for hull straddling aperture edge")
	var outside:=Hangar.advance(crossing,131072,profile,planned.outer_local_m,radii)
	check(outside.phase=="closed" and outside.door_u16==65535,"Completed launch returns to stable closed traffic state")
	for frame:Dictionary in [state,opening,opened,inside,landed,closed,launch,departing,leaving,crossing,outside]:
		check(Hangar.restore(JSON.parse_string(JSON.stringify(frame)),str(profile.site_id))==frame,"Every reachable transition has a stable savable representation")
	for field in ["phase","site_id","door_u16","status_u8","revision","intent"]:
		var corrupt:=opening.duplicate(true);corrupt[field]="broken";check(Hangar.restore(corrupt,str(profile.site_id)).is_empty(),"Corrupt hangar save rejected "+field)
	var invalid:=opened.duplicate(true);invalid.door_u16=65535
	check(Hangar.restore(invalid,str(profile.site_id)).is_empty(),"Save cannot claim open approach with closed hatch")
	check(Hangar.command(state,"launch").is_empty() and Hangar.advance(opening,-1,profile,planned.outer_local_m,radii).is_empty(),"Invalid launch and source tick rejected")
func geometry_controls()->void:
	var radii:=Vector3(10,4,12)
	for entry:Dictionary in [site("sol-apollonius",26563,1585),site("sirius-factory",33966,3247)]:
		var profile:=Hangar.describe(entry,1737400.0)
		check(not profile.is_empty() and profile.pad_count==0 and profile.pad_index==-1 and profile.reservation_count==6,"Enclosed source city describes occupancy slots without invented open pads")
		check(absf(float(profile.hatch_height_source_m)-65.5654052495956)<0.01,"Roof height uses original65535 source raw units")
		var route:=Hangar.route(profile,radii)
		check(route.get("fits",false) and float(route.hatch_inradius_source_m)>160,"Current ship ellipsoid fits actual hexagonal source entrance")
		check(route.source_dock_sentinel_raw==[0,0,-1] and route.outer_local_m.length()>6000,"Actual F650 sentinel and F741 vertical outer waypoint retained")
		var open:=Hangar.prepare(profile,0);var closed:=Hangar.prepare(profile,65535);var half:=Hangar.prepare(profile,32768)
		check(open.get("ok",false) and closed.get("ok",false) and half.get("ok",false),"Every actual source hatch pose compiles on both named ports")
		if not open.get("ok",false) or not closed.get("ok",false) or not half.get("ok",false):continue
		check(open.compiled.triangle_count>10000 and closed.compiled.triangle_count==open.compiled.triangle_count+7 and half.compiled.triangle_count==closed.compiled.triangle_count,"Actual full city and seven animated roof source faces; original Q31 rotation retained")
		check(open.hatch_triangles.is_empty() and closed.hatch_triangles.size()==7 and half.hatch_triangles.size()==7 and closed.hatch_triangles!=half.hatch_triangles,"Entityword1 drives actual source door vertices; intermediate geometry is not substituted")
		check(open.profile.key!=closed.profile.key and open.cache_key!=half.cache_key,"Visual and collision cache distinguish actual hatch poses")
		check(open.footprint_m<float(profile.flat_inner_m) and not open.decorative_collision,"Entire source city fits graded plane and only solid source faces collide")
		var clear:=Hangar.sweep(open,route.entrance_local_m,route.interior_local_m,radii)
		check(clear.is_empty(),"Fully open original roof has an uninterrupted vertical ship corridor: "+str(clear))
		var blocked:=Hangar.sweep(closed,route.entrance_local_m,route.interior_local_m,radii)
		check(not blocked.is_empty() and float(blocked.time)>0 and float(blocked.time)<1,"Closed real source hatch blocks fast vertical sweep")
		var floor:=Hangar.sweep(open,route.interior_local_m,route.interior_local_m-route.up_local*20,radii)
		check(not floor.is_empty(),"Original hangar floor catches descent; no fabricated floor box")
		var side:Vector3=profile.port_basis_local*Vector3(350,25,0)
		check(not Hangar.sweep(open,profile.port_basis_local*Vector3(0,25,0),side,radii).is_empty(),"Actual enclosed walls block horizontal escape")
		check(Hangar.classify(profile,route.interior_local_m,radii).inside and Hangar.classify(profile,route.entrance_local_m,radii).above_roof,"Source enclosure distinguishes inside and roof clearance")
		check(not Hangar.route(profile,Vector3(300,5,300)).fits,"Oversize ship cannot advertise safe aperture route")
		check(not Hangar.route(profile,Vector3(10,100,12)).fits,"Ship taller than real enclosed hangar cannot advertise interior route")
		var invalid_profile:=profile.duplicate(true);invalid_profile.approach_vec_raw=["bad",0,0]
		check(Hangar.route(invalid_profile,radii).is_empty(),"Malformed approach vector cannot throw during route preparation")
		var short_profile:=profile.duplicate(true);short_profile.flat_inner_m=10.0
		check(not Hangar.prepare(short_profile,0).get("ok",false),"Cached city still checks caller graded-region coverage")
		var changed:=profile.duplicate(true);changed.source_seed=int(profile.source_seed)^1
		check(Hangar._pose_key(profile,0)!=Hangar._pose_key(changed,0),"Source seed change cannot reuse stale geometry under unchanged external key")
		var globe:={"latitude":profile.root_latitude,"longitude":profile.root_longitude,"radius":1737400.0}
		var transform:=City.transform_to_frame(profile,globe)
		check(transform.origin.length()<0.01 and (transform.basis*Vector3.UP-Vector3.UP).length()<0.001,"Existing city frame adapter handles enclosed port without axis swapping")
		check(not City.sweep(closed,globe,route.entrance_local_m,route.interior_local_m,radii).is_empty(),"Existing globe CCD consumes compatible underground city data")
		state_controls(profile,radii,route)
	check(Hangar.describe(site("wrong",0,0),-1).is_empty() and not Hangar.prepare({},0).get("ok",false),"Invalid profile cannot publish underground geometry")
func run()->void:
	native_controls();source_assets();geometry_controls()
	print("Source enclosed ground hangar: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
