extends SceneTree
const Nav=preload("res://scripts/navigation.gd")
const Session=preload("res://scripts/source_hyperdrive_session.gd")
const Kernel=preload("res://scripts/source_hyperdrive.gd")
const Ship=preload("res://scripts/flight_model.gd")
const GalaxyData=preload("res://scripts/galaxy.gd")
const ALPHA:=111449880
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func encoded(nav:RefCounted)->String:return JSON.stringify(nav.snapshot())
func dock(nav:RefCounted,ship:RefCounted)->void:
	ship.docked=true;ship.station_available=true;ship.original_port=true;nav.set_source_port_available(true)
func flying(ship:RefCounted)->void:
	ship.docked=false;ship.station_available=false;ship.original_port=false;ship.velocity=Vector3.ZERO
func source(ship:RefCounted)->RefCounted:
	var nav:=Nav.new()
	check(nav.configure_source(str(ship.ship_id)),"Explicit source session configures supported ship")
	check(nav.sync_source_ship(ship),"Prototype cargo is explicitly captured in source capacity")
	return nav
func _initialize()->void:call_deferred("run")

func profiles_and_readonly()->void:
	var ship:=Ship.new();var nav:=source(ship);var state:Dictionary=nav.snapshot().source_hyperdrive
	check(nav.snapshot().schema=="starfrontier-rebuild-navigation-v3" and nav.is_native() and nav.is_source_hyperdrive(),"Source inventory requires explicit navigation v3")
	check(state.model_index==38 and state.drive_index==3 and state.hydrogen==4 and state.military==0,"Cobra uses exact F998 profile model38, class2, H4")
	check(nav.fuel==4 and nav.fuel_capacity()==47,"Active fuel alias and capacity include drive25, fixed6 and prototype cargo2")
	check(nav.validate_source_ship(ship),"Bound source ship bridge validates")
	var before:=encoded(nav);var shipbefore:=JSON.stringify(ship.snapshot())
	var quote:Dictionary=nav.quote_for(ALPHA,ship);var metric:=Kernel.distance_raw_from_q16(nav.current().position_q16,nav.galaxy.get_system(ALPHA).position_q16)
	var session:=Session.new();check(session.restore(state),"Source inventory snapshot is standalone restorable")
	var direct:=Kernel.quote(session.profile(),int(metric.distance_raw),4,0)
	check(quote.ok and quote.can_jump and quote.distance_raw==metric.distance_raw,"Route uses exact F833 native distance")
	for key in ["required_fuel","duration_raw_u32","current_range_raw","max_range_raw"]:check(quote[key]==direct[key],"Route returns original F903 field "+key)
	check(quote.max_range_raw==1200,"Original Cobra hull mass100 gives class2 maximum12ly")
	var profile:Dictionary=nav.map_profile(ship);check(Nav.validate_map_profile(profile),"Copied worker source profile validates")
	var mapped:=Nav.source_map_quote(profile,nav.current(),nav.galaxy.get_system(ALPHA))
	check(mapped.profile_valid and mapped.reachable and mapped.fuel_required==quote.required_fuel and mapped.duration_raw_u32==quote.duration_raw_u32,"Map readonly quote matches actual navigation F903")
	var same:=Nav.source_map_quote(profile,nav.current(),nav.current())
	check(same.profile_valid and not same.reachable and same.distance_raw==0 and not str(same.reason).is_empty(),"Already selected system preserves original zero-distance rejection")
	for key in ["fuel","fuel_capacity","jump_range_ly","maximum_jump_range_ly"]:
		var bad:Dictionary=copy(profile);bad[key]+=1
		check(not Nav.validate_map_profile(bad),"Map rejects forged aggregate "+key)
	var wrong:Dictionary=nav.current().duplicate(true);wrong.id=ALPHA
	check(not Nav.source_map_quote(profile,wrong,nav.galaxy.get_system(ALPHA)).profile_valid,"Worker cannot quote from a different origin ID")
	check(encoded(nav)==before and JSON.stringify(ship.snapshot())==shipbefore,"All readonly quotes leave navigation and Flight bytes unchanged")
	var eagle:=Ship.new();eagle.ship_id="eagle";var eagle_nav:=source(eagle)
	check(eagle_nav.snapshot().source_hyperdrive.model_index==24,"Eagle uses explicit MkII fitting adapter model24")
	var shuttle:=Nav.new();check(shuttle.configure_source("shuttle"),"Bare Shuttle stock drive profile exists")
	var shuttle_ship:=Ship.new();shuttle_ship.ship_id="shuttle"
	check(not shuttle.sync_source_ship(shuttle_ship),"Zero free-capacity Shuttle cannot silently discard prototype starter cargo")
	shuttle_ship.goods.medicines=0
	check(shuttle.sync_source_ship(shuttle_ship) and shuttle.fuel==0 and shuttle.fuel_capacity()==0,"Bare Shuttle binds with explicit empty cargo and zero source fuel")
	check(not nav.configure_source("missing") and encoded(nav)==before,"Invalid source configure is atomic")

func charge_arrival_and_restores()->void:
	var ship:=Ship.new();var nav:=source(ship);flying(ship)
	check(nav.select(ALPHA),"Select actual source Alpha Centauri")
	var quote:Dictionary=nav.quote_for(ALPHA,ship);var original:=encoded(nav)
	check(nav.begin_jump(ship) and nav.remaining==Nav.CHARGE_SECONDS and nav.fuel==4,"Three-second activation adapter locks quote without fuel debit")
	check(not nav.step(1,ship) and nav.fuel==4,"Partial charge consumes no fuel")
	var pending:Dictionary=copy(nav.snapshot());var restored:=Nav.new()
	check(restored.restore(pending) and restored.validate_source_ship(ship),"JSON pending v3 restores with exact inventory bridge")
	var protected:=encoded(restored)
	for key in ["distance_raw","required_fuel","duration_raw_u32","max_range_raw","current_range_raw","origin_id","destination_id"]:
		var bad:Dictionary=copy(pending);bad.pending_source_quote[key]+=1
		check(not restored.restore(bad) and encoded(restored)==protected,"Tampered pending raw field rejects atomically: "+key)
	var hashbad:Dictionary=copy(pending);hashbad.pending_source_quote.session_before_sha256="bad"
	check(not restored.restore(hashbad) and encoded(restored)==protected,"Pending inventory lock hash cannot be forged")
	for key in ["hydrogen","model_index","drive_index","fixed_equipment_space_t","adapted_cargo_t"]:
		var bad:Dictionary=copy(pending);bad.source_hyperdrive[key]+=1
		check(not restored.restore(bad) and encoded(restored)==protected,"Pending source inventory modification rejects: "+key)
	check(restored.step(2,ship),"Restored remaining charge arrives once")
	check(restored.current_id==ALPHA and restored.fuel==4-int(quote.required_fuel),"Arrival consumes exact quoted hydrogen once")
	check(restored.elapsed_days==float(quote.duration_raw_u32)/65536.0,"Arrival clock uses original unsigned Q16 days")
	check(restored.visited.size()==2 and int(restored.visited[0])==GalaxyData.SOL_ID and int(restored.visited[1])==ALPHA and restored.pending_source_quote.is_empty(),"Arrival records destination and clears quote")
	var arrived:=encoded(restored)
	check(not restored.step(999,ship) and encoded(restored)==arrived,"Repeated step cannot consume twice or add time")
	check(restored.snapshot().source_hyperdrive.adapted_cargo_t==2 and ship.total_cargo()==2,"Source hydrogen expenditure does not debit prototype goods")
	nav.cancel_jump()
	check(encoded(nav)==original and nav.fuel==4,"Explicit cancellation clears charge without fuel/time debit")
	check(nav.begin_jump(ship),"Cancelled source route may charge again")
	ship.goods.medicines+=1
	check(not nav.step(3,ship) and nav.fuel==4 and nav.remaining==0,"Cargo changes during charge cancel without debit")
	check(not nav.validate_source_ship(ship) and nav.sync_source_ship(ship) and nav.validate_source_ship(ship),"Only explicit idle sync may update the bridge")
	var saved:Dictionary=copy(nav.snapshot());var mismatch:=Ship.new();mismatch.ship_id="eagle"
	check(not nav.validate_source_ship(mismatch),"Restored source hull cannot bind a different Flight hull")
	for key in ["hydrogen","military","radioactives","adapted_cargo_t","adapted_equipment_space_t"]:
		for value in [-1,65536,1.5]:
			var bad:Dictionary=copy(saved);bad.source_hyperdrive[key]=value
			check(not nav.restore(bad),"Source snapshot rejects invalid inventory domain "+key)
	var overflow:Dictionary=copy(saved);overflow.source_hyperdrive.adapted_cargo_t=80
	check(not nav.restore(overflow),"Capacity overflow cannot restore")
	var digest:Dictionary=copy(saved);digest.source_hyperdrive.source_digest="bad"
	check(not nav.restore(digest),"Source resource digest is pinned in session")
	var extra:Dictionary=copy(saved);extra.source_hyperdrive.unknown=0
	check(not nav.restore(extra),"Unknown source inventory fields reject strict session restore")

func services_and_military()->void:
	var ship:=Ship.new();var nav:=source(ship);ship.credits=100000;dock(nav,ship)
	var state:Dictionary=nav.service_state(ship);var before:=encoded(nav);var credits:int=ship.credits
	check(state.profile_name==ship.profile().name and state.source_capacity_t==80 and state.occupied_t==37 and state.free_t==43,"Service state shows actual ship and exact bridged occupancy")
	check(state.service_available and state.pricing_profile==Session.PRICING,"Workshop explicitly names separate pricing adapter")
	for row:Dictionary in state.drives:
		check(row.price==Session.drive_mass(int(row["class"]))*100,"Install price is quoted from installed mass adapter")
	for row:Dictionary in state.fuels:
		check(row.fill_quantity==43 and row.fill_price==430 and row.unit_price==10,"Fill quantity/price is precomputed using all occupied space")
	check(encoded(nav)==before and ship.credits==credits,"Service quoting is readonly")
	check(not nav.service("install_drive","9",1,ship) and encoded(nav)==before and ship.credits==credits,"Overlarge drive rejects atomically")
	check(not nav.service("install_drive","2",0,ship) and not nav.service("install_drive","02",1,ship),"Malformed installation commands reject")
	check(not nav.service("refuel","hydrogen",44,ship) and encoded(nav)==before and ship.credits==credits,"Refuel cannot exceed source capacity")
	check(nav.service("install_drive","11",1,ship) and ship.credits==credits-1200,"Military class2 installs with original mass12 and explicit price1200")
	check(nav.fuel==0 and nav.snapshot().source_hyperdrive.hydrogen==4,"Installing military drive changes active fuel without converting hydrogen")
	check(nav.service("refuel","military",8,ship),"Separate military fuel is loaded into source cargo")
	check(nav.fuel==8 and ship.goods.medicines==2,"Military cargo is separate from jetfuel/prototype medicines")
	var unload_before:=encoded(nav);credits=ship.credits
	check(not nav.service("unload_fuel","hydrogen",5,ship) and encoded(nav)==unload_before and ship.credits==credits,"Fuel handover cannot unload more than owned")
	check(nav.service_state(ship).fuels[0].can_unload and nav.service_state(ship).fuels[0].unload_price==0,"Fuel handover quote is free and readonly")
	check(nav.service("unload_fuel","hydrogen",1,ship) and ship.credits==credits and nav.snapshot().source_hyperdrive.hydrogen==3,"Docked fuel handover frees one tonne without refund or fee")
	flying(ship);check(nav.select(ALPHA),"Military source route selects native destination")
	var quote:Dictionary=nav.quote_for(ALPHA,ship);var start:Dictionary=nav.snapshot().source_hyperdrive
	check(quote.ok and quote.can_jump and nav.begin_jump(ship) and nav.step(3,ship),"Military route uses original F903 and commits")
	var after:Dictionary=nav.snapshot().source_hyperdrive
	check(after.military==start.military-int(quote.required_fuel) and after.radioactives==int(quote.required_fuel) and after.hydrogen==3,"Military expenditure becomes waste exactly once")
	check(after.military+after.radioactives==start.military and ship.total_cargo()==2,"Military replacement preserves source cargo quantity and prototype cargo")
	var committed:=encoded(nav);check(not nav.step(3,ship) and encoded(nav)==committed,"Military waste cannot be produced twice")
	check(not nav.service("unload_waste","",int(after.radioactives),ship),"Waste service requires selected dock context")
	dock(nav,ship);credits=ship.credits
	check(nav.service("unload_waste","",int(after.radioactives),ship) and ship.credits==credits-int(after.radioactives)*10,"Waste disposal costs credits and never pays a farming reward")
	check(nav.snapshot().source_hyperdrive.radioactives==0,"Waste inventory is removed exactly once")
	var remove:Dictionary=nav.service_state(ship);credits=ship.credits
	check(remove.remove_price==600 and nav.service("remove_drive","",1,ship) and ship.credits==credits+600,"Drive removal pays explicit half-price refund")
	check(nav.snapshot().source_hyperdrive.drive_index==0,"Removal leaves no source hyperdrive")
	flying(ship);check(nav.select(GalaxyData.SOL_ID) and not nav.begin_jump(ship),"Removed drive cannot jump")
	dock(nav,ship);ship.credits=1000000000
	check(nav.service("install_drive","2",1,ship),"Drive may install below maximum balance")
	ship.credits=1000000000
	check(not nav.service_state(ship).can_remove and not nav.service("remove_drive","",1,ship),"Refund quote and command reject balance overflow consistently")
	ship.credits=0;before=encoded(nav)
	check(not nav.service("refuel","hydrogen",1,ship) and encoded(nav)==before and ship.credits==0,"Insufficient funds cannot partially load fuel")
	ship.docked=false;check(not nav.service_state(ship).service_available and not nav.service("unload_fuel","hydrogen",1,ship),"In-flight workshop and fuel handover are readonly")
	var full_ship:=Ship.new();var full:=source(full_ship);full_ship.credits=100000;dock(full,full_ship)
	check(full.service("refuel","hydrogen",43,full_ship) and full.service_state(full_ship).free_t==0,"Source fuel fill really occupies every free tonne")
	var full_before:=encoded(full);credits=full_ship.credits
	check(not full.service("install_drive","4",1,full_ship) and encoded(full)==full_before and full_ship.credits==credits,"Full hydrogen cargo prevents a larger drive without discarding fuel")
	check(full.service("unload_fuel","hydrogen",20,full_ship) and full.service_state(full_ship).free_t==20,"Explicit free fuel handover makes room for larger hardware")
	check(full.service("install_drive","4",1,full_ship) and full.service_state(full_ship).free_t==0,"Larger original drive fits after explicit fuel handover")

func migration_and_legacy()->void:
	var ship:=Ship.new();var legacy:=Nav.new();check(legacy.configure_native(),"Legacy native v2 setup remains explicit")
	var v2:Dictionary=copy(legacy.snapshot());check(v2.version==2 and not legacy.is_source_hyperdrive(),"Native sessions do not silently upgrade")
	legacy.select(ALPHA);legacy.elapsed_days=12.25;legacy.fuel=7;dock(legacy,ship)
	var before:=encoded(legacy);var shipbefore:=JSON.stringify(ship.snapshot());var quoted:=legacy.migration_quote(ship)
	check(quoted.ok and quoted.hydrogen==7 and quoted.price==0,"Explicit migration quotes one-to-one old fuel to hydrogen")
	check(encoded(legacy)==before and JSON.stringify(ship.snapshot())==shipbefore,"Migration review does not mutate ship/session")
	check(legacy.migrate_source(ship).ok and legacy.is_source_hyperdrive(),"Explicit reviewed migration activates v3")
	check(legacy.fuel==7 and legacy.elapsed_days==12.25 and legacy.current_id==GalaxyData.SOL_ID and legacy.selected_id==ALPHA and legacy.visited==[GalaxyData.SOL_ID],"Migration preserves old route IDs clock visits and fuel units")
	check(legacy.has_station() and legacy.service_state(ship).service_available,"Validated selected-port context survives immediate migration")
	check(JSON.stringify(ship.snapshot())==shipbefore,"Migration leaves all Flight inventory and credits unchanged")
	var restored:=Nav.new();check(restored.restore(v2) and not restored.is_source_hyperdrive() and restored.snapshot().schema==v2.schema and restored.fuel==12 and restored.elapsed_days==0,"Old native JSON save retains original v2 fuel/time contract")
	var from_source:=source(Ship.new());check(from_source.restore(v2) and not from_source.is_source_hyperdrive() and from_source.pending_source_quote.is_empty(),"Loading v2 into active v3 clears source inventory instead of silently migrating old save")
	dock(restored,ship);ship.equipment=["shield"];before=encoded(restored)
	check(not restored.migration_quote(ship).ok and not restored.migrate_source(ship).ok and encoded(restored)==before,"Ambiguous prototype equipment cannot silently migrate")
	ship.equipment=[];ship.goods.medicines=70
	check(not restored.migration_quote(ship).ok and encoded(restored)==before,"Migration capacity failure is atomic")
	ship.goods.medicines=2;flying(ship);restored.select(ALPHA)
	check(restored.fuel_required()==2 and restored.begin_jump(ship),"v2 still uses adapted ceil(distance/4) cost")
	var old_quote:=restored.distance();check(restored.step(3,ship) and restored.fuel==10 and restored.elapsed_days==maxf(0.02,old_quote*0.1),"v2 fuel/time arrival formulas remain unchanged")
	var v1:=Nav.new();var snapshot:=encoded(v1);check(not v1.is_source_hyperdrive() and v1.snapshot().version==1 and restored.restore(v1.snapshot()) and encoded(restored)==snapshot,"Old bounded v1 in-memory load remains byte-equivalent")

func run()->void:
	profiles_and_readonly();charge_arrival_and_restores();services_and_military();migration_and_legacy()
	print("SOURCE HYPERDRIVE NAVIGATION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
