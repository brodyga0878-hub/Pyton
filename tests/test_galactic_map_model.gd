extends SceneTree
const Model=preload("res://scripts/galactic_map_model.gd")
const GalaxyData=preload("res://scripts/galaxy.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func state()->Dictionary:return {"native":true,"current_id":GalaxyData.SOL_ID,"selected_id":GalaxyData.SOL_ID,"jump_range_ly":12.0,"fuel":12,"fuel_capacity":12,"jump_blocked_reason":""}
func run()->void:
	check(Model.prepare_shared_resources(),"Source map static text resources prepare before worker use")
	var m:=Model.new();check(m.configure_state(state()),"Native map configures its private source catalogue")
	check(Model.display_sector(Vector2i(5912,5412))==Vector2i.ZERO and Model.raw_sector(Vector2i(-1,76))==Vector2i(5911,5488),"Original F830 display sectors use Sol offset5912/5412")
	check(not Model.valid_sector(Model.raw_sector(Vector2i(-5913,0))) and Model.valid_sector(Vector2i(0,0)) and Model.valid_sector(Vector2i(8191,8191)),"Signed display coordinates retain finite source raw boundaries")
	check(m.load_sector_window(m.sector_position(m.current)) and m.rows.size()>11 and m.rows.size()<=558,"Map loads original bounded nine-sector region")
	var bytes:=var_to_bytes(state())
	var alpha:Dictionary=m.galaxy.get_system(0x06a49718)
	check(not alpha.is_empty() and absf(m.distance_ly(alpha)-4.35)<0.1,"Selected-system distance uses actual3Dsource AlphaCentauri coordinates")
	check(m.select(0x06a49718) and m.jump_state().reachable,"Separate selection supplies actual reachable route without starting a jump")
	check(var_to_bytes(state())==bytes,"Map operations do not mutate caller snapshots")
	var names:Array=m.search("солнце")
	check(names.any(func(row:Dictionary):return int(row.id)==GalaxyData.SOL_ID),"Russian name alias finds original Sol")
	var polaris:Array=m.search("Polaris")
	check(not polaris.is_empty() and polaris[0].original_name.to_lower().contains("polaris"),"Original named systems are searchable outside the current page")
	check(int(m.galaxy.cache_state().sectors)<=24 and int(m.galaxy.cache_state().rows)<=768,"Search preserves bounded page/row caches")
	check(m.load_sector_window(Vector2(0,8191)) and m.center_sector.x==0,"Edge-sector navigation stays inside raw source limits")
	check(not m.load_sector_window(Vector2(NAN,0)),"Invalid pan cannot poison map centre")
	var f:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_galactic_map_native.json"))
	check(FileAccess.get_sha256("res://tests/fixtures/source_galactic_map_native.json")=="0a15ce8ee486da83adbd9c52d9ecc8a57505378e9ff8a68f6ea116d1b24f480a","Independent F853 fixture identity is pinned")
	check(FileAccess.get_sha256(Model.MAP_DATA_PATH)==f.runtime_resource_sha256 and f.canaries_unchanged and f.fresh_process_runs_per_scale==3 and f.case_count==4536,"Actual source tables/native process controls have the expected provenance")
	for row:Dictionary in f.cases:check(m.overview_density(int(row.x),int(row.y),int(row.scale))==int(row.result),"Overview density matches actually executed F853 at"+str([row.x,row.y,row.scale]))
	check(m.overview_density(-1,0)==0 and m.overview_density(8192,8191)==0,"Overview never wraps invalid raw sectors")
	m.center_sector=Vector2(4096,4096)
	var pixels:=m.overview_pixels(52)
	check(pixels.size()==320*158*4,"Overview uses the original320×158 grid with source palette")
	var has_bright:=false
	for at in range(0,pixels.size(),4):
		if pixels[at]>0:has_bright=true
		if pixels[at]>240 or pixels[at]!=pixels[at+1] or pixels[at]!=pixels[at+2] or pixels[at+3]!=255:check(false,"SDL grayscale source palette remains exact");break
	check(has_bright,"Overview has real source-density light, not a decorative starfield")
	check(m.overview_sector(Vector2(159.5,78.5),52).distance_to(Vector2(4096,4096))<0.01,"Overview click centre reverses original F847 sampling")
	var front:=Model.map_point([8.0,0.0,0.0],[0.0,0.0,0.0],0,PI/6,10,Vector2(500,300))
	check(front.point.is_equal_approx(Vector2(580,300)),"Sector projection places an8ly x-offset at its grid coordinate")
	var elevated:=Model.map_point([0.0,0.0,8.0],[0.0,0.0,0.0],0,PI/6,10,Vector2(500,300))
	check(elevated.point.y<300,"True source vertical coordinates rise above the sector plane")
	check(Model.map_point([INF,0,0],[0,0,0],0,0.5,10,Vector2.ZERO).is_empty(),"Invalid source coordinates cannot produce a GUI contact")
	var old_id:=m.selected_id;var bad:=state();bad.jump_range_ly=INF
	check(not m.configure_state(bad) and m.selected_id==old_id,"Rejected state configuration preserves the existing map selection")
	bad=state();bad.fuel=13;check(not m.configure_state(bad),"Inconsistent fuel capacity is rejected rather than inventing a jump")
	var legacy:=Model.new();var old:=state();old.native=false
	check(legacy.configure_state(old) and legacy.load_sector_window(legacy.center_sector) and legacy.rows.size()==11,"Legacy saves display their unchanged explicit11-system layout")
	print("GALACTIC MAP MODEL TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
