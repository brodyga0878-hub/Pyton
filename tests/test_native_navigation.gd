extends SceneTree
const GalaxyData=preload("res://scripts/galaxy.gd")
const Kernel=preload("res://scripts/source_galaxy.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
const ALPHA:=111449880
var checks:=0
var failures:=0

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func _initialize()->void:call_deferred("run")

func coordinates_and_paging()->void:
	var legacy:=GalaxyData.new()
	check(not legacy.is_native() and legacy.system_count()==11,"Default catalogue and its existing 11-entry adapter are unchanged")
	var legacy_rows:=JSON.stringify(legacy.all())
	var galaxy:=GalaxyData.new();check(galaxy.configure_native(),"Native source sector mode opts in explicitly")
	check(galaxy.is_native() and galaxy.system_count()==-1,"Global native count is explicitly unenumerated, never derived from cache size")
	var sol:Dictionary=galaxy.get_system(GalaxyData.SOL_ID);var alpha:Dictionary=galaxy.get_system(ALPHA)
	check(sol.position_ly==[0.0,0.0,0.0],"Source Solar position is subtracted in scalar precision before display")
	check(absf(galaxy.distance(GalaxyData.SOL_ID,ALPHA)-4.35)<0.1,"Alpha Centauri uses native coordinates at about 4.35 ly, not index spacing")
	var kernel:=Kernel.new();var source:Dictionary=kernel.system(ALPHA);var origin:Dictionary=kernel.system(GalaxyData.SOL_ID)
	for axis in range(3):check(float(alpha.position_ly[axis])==float(source.position_q16[axis]-origin.position_q16[axis])*8.0/65536.0,"Q16 sector8ly coordinate conversion is exact")
	check(not sol.has_station and not alpha.has_station,"Native star rows do not manufacture universal arrival docks")
	var rows:=galaxy.all();check(rows.size()>11 and rows.size()<=9*62,"Map is a bounded source 3 by3 sector neighbourhood")
	var ids:Dictionary={}
	for row:Dictionary in rows:
		check(not ids.has(int(row.id)),"Neighbourhood has no duplicated system IDs");ids[int(row.id)]=true
		check(absi(int(row.sector[0])-int(sol.sector[0]))<=1 and absi(int(row.sector[1])-int(sol.sector[1]))<=1,"Every visible row belongs to the current source neighbourhood")
		check(not row.has_station,"No native page creates an authored training dock")
	check(galaxy.search("").size()==rows.size(),"Search is bounded to the same current neighbourhood")
	var invalid:=(GalaxyData.SOL_ID&0x03ffffff)|(63<<26)
	galaxy.by_id[invalid]={"id":invalid,"name":"forged"}
	check(galaxy.get_system(invalid).is_empty() and not galaxy.is_valid_id(invalid),"A cached forged row cannot bypass original source sector count")
	check(galaxy.get_system(-1).is_empty() and galaxy.get_system(4294967296).is_empty() and galaxy.sector_page(-1,3).is_empty() and galaxy.sector_page(8192,3).is_empty(),"Out-of-range source IDs and sectors are rejected")
	galaxy.clear_native_cache()
	for index in range(60):galaxy.sector_page(5900+index,5400)
	var state:Dictionary=galaxy.cache_state()
	check(int(state.sectors)<=GalaxyData.MAX_SECTORS and int(state.rows)<=GalaxyData.MAX_ROWS,"Independent source pages obey bounded LRU sector and row caches")
	check(galaxy.is_valid_id(ALPHA) and galaxy.distance(GalaxyData.SOL_ID,ALPHA)>4,"Valid source systems survive complete cache eviction")
	check(legacy_rows==JSON.stringify(legacy.all()),"Native exploration does not alter another legacy catalogue")
	galaxy.reload_catalog();check(not galaxy.is_native() and galaxy.system_count()==11 and JSON.stringify(galaxy.all())==legacy_rows,"Explicit catalogue reload returns exactly to the legacy map")

func saves_and_jumps()->void:
	var nav:=Nav.new();check(nav.configure_native(),"New native navigation session is configured")
	var ship:=Ship.new();ship.docked=false;ship.station_available=false
	check(not nav.has_station() and nav.select(ALPHA) and nav.fuel_required()==2,"Native distance uses the explicit existing four-ly fuel adapter")
	check(nav.begin_jump(ship),"Native Alpha Centauri jump can charge through actual ship profile guards")
	var saved:Dictionary=copy(nav.snapshot())
	check(saved.schema=="starfrontier-rebuild-navigation-v2" and saved.version==2 and saved.catalogue_mode==GalaxyData.NATIVE_MODE and saved.fuel_profile==Nav.NATIVE_FUEL_PROFILE,"Native save records mode, source digest and explicit adapted fuel profile")
	var clone:=Nav.new();check(clone.restore(saved) and clone.is_native() and clone.pending_id==ALPHA,"Native pending route restores without relying on old catalogue membership")
	clone.galaxy.clear_native_cache()
	check(clone.step(3.0,ship) and clone.current_id==ALPHA and clone.fuel==Nav.FUEL_CAPACITY-2,"Restored route commits source destination and fuel once after caches clear")
	check(not ship.station_available and not clone.has_station() and clone.galaxy.focus_id==ALPHA,"Arrival derives a new focus and leaves source ports unselected")
	check(not clone.step(3.0,ship),"Completed source jump cannot commit twice")
	var source:Dictionary=copy(clone.snapshot())
	var recent:Array=[GalaxyData.SOL_ID,ALPHA]
	for row:Dictionary in clone.galaxy.all():
		if not int(row.id) in recent:recent.append(int(row.id))
	source.visited=recent
	clone.galaxy.clear_native_cache()
	var restored:=Nav.new();check(restored.restore(source) and restored.visited.size()==recent.size(),"Visited source IDs load from original generation after row caches are empty")
	var before:=JSON.stringify(restored.snapshot());var galaxy_before:RefCounted=restored.galaxy
	for key in ["source_digest","catalogue_mode","fuel_profile"]:
		var bad:Dictionary=source.duplicate(true);bad[key]="invalid"
		check(not restored.restore(bad) and JSON.stringify(restored.snapshot())==before and restored.galaxy==galaxy_before,"Invalid native mode/digest/profile rejects atomically")
	for key in ["current_id","selected_id"]:
		var bad:Dictionary=source.duplicate(true);bad[key]=(GalaxyData.SOL_ID&0x03ffffff)|(63<<26)
		check(not restored.restore(bad) and JSON.stringify(restored.snapshot())==before and restored.galaxy==galaxy_before,"Invalid source sector index rejects atomically")
	for bad_visits in [[ALPHA,ALPHA],[4294967295],[GalaxyData.SOL_ID]]:
		var bad:Dictionary=source.duplicate(true);bad.visited=bad_visits
		check(not restored.restore(bad) and JSON.stringify(restored.snapshot())==before,"Duplicate, nonexistent and current-missing visit histories reject atomically")
	for key in ["remaining","fuel","elapsed_days"]:
		var bad:Dictionary=source.duplicate(true);bad[key]=NAN
		check(not restored.restore(bad) and JSON.stringify(restored.snapshot())==before,"Nonfinite native state rejects atomically")
	check(not restored.configure_native(-1) and JSON.stringify(restored.snapshot())==before,"Failed native configuration preserves active route")
	var legacy:=Nav.new();var old:Dictionary=copy(legacy.snapshot());check(legacy.restore(old),"Published legacy JSON snapshot is a valid control")
	check(restored.restore(old) and not restored.is_native() and JSON.stringify(restored.snapshot())==JSON.stringify(legacy.snapshot()) and restored.galaxy.system_count()==11,"Loading legacyv1 into native mode restores exact old map and old navigation schema")
	check(legacy.restore(saved) and legacy.is_native(),"Nativev2 can explicitly load into a fresh legacy-default model")
	var old_pending:Dictionary=copy(Nav.new().snapshot());old_pending.current_id=ALPHA;old_pending.selected_id=ALPHA;old_pending.visited=[ALPHA]
	check(legacy.restore(old_pending) and not legacy.is_native() and legacy.current_id==ALPHA,"An existingv1 progress record never silently upgrades to real galaxy distances")

func border_route_and_services()->void:
	var nav:=Nav.new();check(nav.configure_native(),"Native border route fixture configures")
	var current:Dictionary=nav.current();var destination:=-1;var best:=INF
	for row:Dictionary in nav.galaxy.all():
		if row.sector==current.sector:continue
		var distance:=nav.galaxy.distance(nav.current_id,int(row.id))
		if distance>0 and distance<best:best=distance;destination=int(row.id)
	check(destination>=0 and best<20,"Source neighbourhood includes a reachable system across a sector boundary")
	var ship:=Ship.new();ship.docked=false;ship.station_available=false
	check(nav.select(destination) and nav.begin_jump(ship),"A route across actual sector boundary charges normally")
	var saved:Dictionary=copy(nav.snapshot());var loaded:=Nav.new()
	check(loaded.restore(saved),"Cross-sector pending destination remains valid outside cached row membership")
	loaded.galaxy.clear_native_cache();check(loaded.step(3,ship),"Cross-sector arrival completes from source generation after cache clear")
	var landed:Dictionary=loaded.current();var seen:=false
	for row:Dictionary in loaded.galaxy.all():
		if int(row.id)==loaded.current_id:seen=true
		check(absi(int(row.sector[0])-int(landed.sector[0]))<=1 and absi(int(row.sector[1])-int(landed.sector[1]))<=1,"Jump changes the map neighbourhood to the actual arrival sector")
	check(seen and loaded.galaxy.focus_id==loaded.current_id,"Arrival star is visible in its focused source page")
	ship.docked=true;ship.original_port=true;ship.station_available=true;ship.credits=1000;loaded.fuel=1
	var before:=JSON.stringify(loaded.snapshot());var credits:=ship.credits
	check(not loaded.refuel(ship) and JSON.stringify(loaded.snapshot())==before and ship.credits==credits,"Source-port refuel stays unavailable until actual selected-port context is derived")
	loaded.set_source_port_available(true)
	check(loaded.has_station() and not loaded.has_station(GalaxyData.SOL_ID) and loaded.refuel(ship) and loaded.fuel==Nav.FUEL_CAPACITY,"Explicit selected original port can use separately named basic fuel adapter")
	check(not loaded.current().has_station,"Port service context never mutates universal system metadata")
	var restored:=Nav.new();check(restored.restore(copy(loaded.snapshot())) and not restored.has_station(),"Derived selected-port service flag is never trusted from a saved navigation record")
	var legacy:=Nav.new();legacy.fuel=1;legacy.set_source_port_available(true);credits=ship.credits
	check(not legacy.refuel(ship) and ship.credits==credits and legacy.fuel==1,"Legacy original-port refuel rejection remains unchanged")

func run()->void:
	coordinates_and_paging();saves_and_jumps();border_route_and_services()
	print("NATIVE NAVIGATION TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
