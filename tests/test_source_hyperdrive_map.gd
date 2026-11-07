extends SceneTree
# Actual navigation quote and background map must agree at source precision.
const Nav=preload("res://scripts/navigation.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Model=preload("res://scripts/galactic_map_model.gd")
const View=preload("res://scripts/galactic_map_view.gd")
const ALPHA:=0x06a49718
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func copied(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func run()->void:
	root.size=Vector2i(1440,720)
	var nav:=Nav.new();var ship:=Flight.new()
	check(nav.configure_source("cobra") and nav.sync_source_ship(ship),"Real source Cobra session configures")
	var before:=var_to_bytes(nav.snapshot());var ship_before:=var_to_bytes(ship.snapshot())
	var profile:=nav.map_profile(ship)
	var state:={"native":true,"current_id":nav.current_id,"selected_id":ALPHA,"jump_range_ly":nav.source_range_ly(ship),"fuel":nav.fuel,"fuel_capacity":nav.fuel_capacity(),"source_hyperdrive_profile":profile}
	var model:=Model.new();check(model.configure_state(state),"Source profile enters isolated map model")
	for id:int in [ALPHA,0x1aa51717,nav.current_id]:
		var row:=nav.galaxy.get_system(id)
		check(not row.is_empty(),"Original source target exists")
		var expected:=nav.quote_for(id,ship);var actual:=model.jump_state(row)
		check(actual.get("profile_valid",false),"Map retains valid source profile")
		check(int(actual.get("distance_raw",-1))==int(expected.get("distance_raw",-2)),"Map uses exact F833 distance")
		check(int(actual.get("fuel_required",-1))==maxi(0,int(expected.get("required_fuel",0))),"Map and navigation agree on source fuel")
		check(int(actual.get("duration_raw_u32",-1))==int(expected.get("duration_raw_u32",-2)),"Map and navigation agree on original Q16 travel duration")
		check(is_equal_approx(model.distance_ly(row),float(actual.distance_ly)),"Search/distance labels use the same source metric")
	check(var_to_bytes(nav.snapshot())==before and var_to_bytes(ship.snapshot())==ship_before,"Map quotes preserve entire live navigation and ship")
	var bad:Dictionary=copied(state);bad.source_hyperdrive_profile.fuel+=1
	check(not Model.new().configure_state(bad),"Invalid saved fuel cannot make a route appear affordable")
	bad=copied(state);bad.native=false;check(not Model.new().configure_state(bad),"Source profile cannot enter legacy coordinate map")
	bad=copied(state);bad.current_id=ALPHA;check(not Model.new().configure_state(bad),"Profile origin must match actual map origin")
	var view:=View.new();check(view.configure_state(state),"Actual map UI accepts source state")
	root.add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var started:=Time.get_ticks_msec()
	while view.loading() and Time.get_ticks_msec()-started<30000:await process_frame
	await process_frame
	check(not view.loading() and view.model!=null,"Actual map worker publishes source profile")
	if view.model!=null:
		var actual:Dictionary=view.model.jump_state();var expected:=nav.quote_for(ALPHA,ship)
		check(int(actual.distance_raw)==int(expected.distance_raw),"Background worker keeps source distance")
		check(int(actual.fuel_required)==int(expected.required_fuel),"Background worker keeps source fuel quote")
		check(int(actual.duration_raw_u32)==int(expected.duration_raw_u32),"Background worker keeps source duration")
		check(view.selection_state.text.contains("сут."),"Phone route card displays original travel duration")
	check(var_to_bytes(nav.snapshot())==before and var_to_bytes(ship.snapshot())==ship_before,"Actual chart rendering never edits fuel, time, target or ship")
	view.queue_free();await process_frame
	print("SOURCE HYPERDRIVE MAP TESTS: %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
