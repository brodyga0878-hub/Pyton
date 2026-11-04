extends SceneTree
const GalaxyData=preload("res://scripts/galaxy.gd")
const NavigationData=preload("res://scripts/navigation.gd")
const World=preload("res://scripts/planetary_system.gd")
const Ship=preload("res://scripts/flight_model.gd")
var checks:=0
var failures:=0

func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(label)
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))

func catalogue_and_records()->void:
	var galaxy:=GalaxyData.new()
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_worlds.json"))
	check(galaxy.system_count()==data.systems.size() and galaxy.system_count()==11,"Bounded catalogue contains exactly the source handcrafted systems")
	check(galaxy.catalogue_mode=="handcrafted_ids_adapted_map_v1","A rebuilt map never claims the complete original galaxy")
	check(galaxy.get_system(GalaxyData.SOL_ID).original_name=="Sol" and galaxy.search("солнце").size()==1,"Source Solar ID and Russian catalogue search")
	check(galaxy.get_system(-1).is_empty() and is_inf(galaxy.distance(GalaxyData.SOL_ID,-1)),"Unknown system IDs do not invent stars")
	var count:=0
	for entry in data.systems:
		var world:=World.new();world.configure(galaxy.get_system(int(entry.system_id)))
		check(world.layout_mode==World.SOURCE_LAYOUT,"Available source system uses the explicit analytic adapter")
		check(world.bodies.size()+world.settlements.size()==entry.objects.size(),"Every source object is accounted for")
		check(world.by_id.has(world.default_id),"Arrival body exists")
		for body in world.bodies:
			check(str(body.parent).is_empty() or world.by_id.has(str(body.parent)),"Source body parent exists")
			check(float(body.radius_km)>=0 and float(body.mass_solar)>0 and float(body.rotation_hours)>0,"Finite physical adapter bounds")
			check(str(body.record_hex).length()==136 and int(body.source_seed)==int(str(body.record_hex).hex_decode().decode_u32(4)),"Body UID is derived from the independently regenerated source record")
			for day in [0.0,365.25,1e9]:check(world.local_meters(str(body.id),day).is_finite(),"Large dates remain finite")
		for site in world.settlements:
			check(world.by_id.has(str(site.parent)),"Source settlement parent exists")
			check(str(site.record_hex).length()==136 and int(site.source_seed)==int(str(site.record_hex).hex_decode().decode_u32(4)),"Source settlement UID survives adaptation")
			count+=1
	check(count==38,"All38 settlements in the eleven mapped source systems are retained; the unmatched Riedquat record is separate")
	var solar:=World.new();solar.configure(galaxy.get_system(GalaxyData.SOL_ID))
	check(solar.default_id=="earth" and absf(float(solar.by_id.earth.radius_km)-6371)<1e-9,"Solar adapter has the stated SI Earth radius")
	check(int(solar.by_id.earth.source_seed)==0x0abc1234 and int(solar.get_site("site10").source_seed)==0xbdd3aa2e,"Independent known Earth and New Moscow native UIDs")
	check(int(solar.get_site("site10").model_index)==84 and solar.get_site("site10").name=="Новая Москва","Actual New Moscow is source model84")
	var center:Vector3=solar.local_meters("earth",0)
	var expected:Vector3=World.ARRIVAL_DIRECTION.normalized()*(6371000.0*4.0)
	check(center.distance_to(expected)<4.0,"Focus anchor is physically separated from Earth at the adapted arrival radius")
	for day in [0.001,300.0,1000000.0]:check(solar.local_meters("earth",day).distance_to(center)<0.1,"AU subtraction occurs in scalar precision before float32 Vector3")
	for ecc in [0.0,0.0167,0.2488,0.8]:
		for mean in [-18.1,0.0,0.3,2.8,8.1]:
			var anomaly:=World.eccentric_anomaly(mean,ecc)
			check(absf(anomaly-ecc*sin(anomaly)-fposmod(mean,TAU))<1e-10,"Kepler residual is bounded independently of rendering")

func transfer_and_save()->void:
	var nav:=NavigationData.new();var world:=World.new();world.configure(nav.current())
	var ship:=Ship.new();ship.docked=false;ship.station_available=true
	check(world.select("mars") and world.begin_transfer(ship,nav),"Real source body can be selected for a safe transfer")
	check(not world.select("moon") and not world.step_transfer(1.0,ship,nav) and not world.step_transfer(1.99,ship,nav),"Target cannot change while a bounded transfer is pending")
	var state:Dictionary=copy(world.snapshot());var before:=JSON.stringify(world.snapshot())
	for field in ["focus_id","selected_id","source_digest"]:
		var bad:=state.duplicate(true);bad[field]="not-a-real-id"
		check(not world.restore(bad) and JSON.stringify(world.snapshot())==before,"Malformed world snapshot is rejected atomically")
	var clone:=World.new();clone.configure(nav.current())
	check(clone.restore(state) and clone.pending_id=="mars" and clone.transfer_remaining>0,"Pending transfer state restores without executing a move")
	check(clone.step_transfer(0.02,ship,nav) and clone.focus_id=="mars" and ship.position==Vector3.ZERO,"Arrival commits one focus-frame transition and resets local flight")
	check(ship.velocity==Vector3.ZERO and not ship.autopilot and clone.transfer_remaining==0,"Arrival preserves safe stopped controls")
	var settled:Dictionary=copy(clone.snapshot());var stable:=JSON.stringify(clone.snapshot())
	var invalid:Dictionary=settled.duplicate(true);invalid.transfer_remaining=NAN
	check(not clone.restore(invalid) and JSON.stringify(clone.snapshot())==stable,"Non-finite world time is rejected atomically")
	var solar:=World.new();solar.configure(nav.current());ship=Ship.new();ship.docked=false
	check(solar.begin_site_transfer("site10",ship,nav) and solar.step_transfer(3.0,ship,nav),"Native New Moscow route can complete")
	check(solar.current_site().name_en=="New Moscow" and solar.focus_id=="earth" and not ship.station_available,"Ground source port has no phantom orbital dock")
	var ground:Dictionary=copy(solar.snapshot());var restored:=World.new();restored.configure(nav.current())
	check(restored.restore(ground) and restored.site_id=="site10","Actual ground site identity survives JSON round trip")
	var site_mismatch:Dictionary=ground.duplicate(true);site_mismatch.focus_id="mars"
	check(not restored.restore(site_mismatch) and restored.site_id=="site10","A site cannot be loaded onto a different parent body")

func jumps_and_navigation_validation()->void:
	var nav:=NavigationData.new();var ship:=Ship.new();ship.docked=false;ship.station_available=false
	var candidates:Array=nav.galaxy.all();var destination:=int(candidates[1].id)
	check(nav.select(destination) and nav.distance()>0 and nav.fuel_required()==2,"Explicit map distance and fuel rule are visible adapters")
	var initial_fuel:=nav.fuel
	check(nav.begin_jump(ship) and not nav.select(int(candidates[2].id)),"Jump locks its destination")
	nav.cancel_jump();check(nav.fuel==initial_fuel and nav.remaining==0,"Cancelling a charge neither burns nor refunds extra fuel")
	check(nav.begin_jump(ship),"A cancelled jump can restart")
	var state:Dictionary=copy(nav.snapshot());var before:=JSON.stringify(nav.snapshot())
	for field in ["fuel","elapsed_days","remaining"]:
		var bad:Dictionary=state.duplicate(true);bad[field]=INF
		check(not nav.restore(bad) and JSON.stringify(nav.snapshot())==before,"Non-finite navigation data cannot poison live progress")
	var other:=NavigationData.new()
	check(other.restore(state) and other.pending_id==destination,"Pending jump survives JSON without advancing")
	check(other.step(3.0,ship) and other.current_id==destination,"Jump arrival commits destination")
	check(other.fuel==initial_fuel-2 and destination in other.visited and ship.velocity==Vector3.ZERO,"Jump consumes the committed amount once and records the visit")
	check(not other.step(1.0,ship) and other.fuel==initial_fuel-2,"A completed jump does not consume fuel twice")
	var malformed:Dictionary=copy(other.snapshot());malformed.visited=[other.current_id,other.current_id]
	check(not other.restore(malformed),"Repeated visited records are rejected")
	ship.docked=true;ship.credits=1000;other.fuel=9
	check(other.refuel(ship) and other.fuel==12 and ship.credits==970,"Prototype arrival refuelling remains bounded and charged once")

func run()->void:
	catalogue_and_records();transfer_and_save();jumps_and_navigation_validation()
	print("REBUILT WORLD TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
