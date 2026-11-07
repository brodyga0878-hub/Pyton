extends SceneTree
# Transform/geometry contract for authored visual gear, not source collision
# meshes or a claim of physically simulated hydraulic mechanisms.
const Ship=preload("res://scripts/ship_visual.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func visual(profile:Dictionary)->Node3D:
	var ship:=Ship.new();ship.set_quality(0);root.add_child(ship);ship.configure(profile);ship.set_process(false);return ship
func source_fraction_and_geometry()->void:
	for profile:Dictionary in [{"id":"cobra","visual_span_m":42.0},{"id":"eagle","visual_span_m":26.0},{"id":"shuttle","visual_span_m":24.0}]:
		var ship:=visual(profile);var hull:Mesh=ship.hull_mesh.mesh;var gear:Mesh=ship.landing_gear.mesh
		var stats:Dictionary=ship.geometry_stats.duplicate(true);var local_hull:Transform3D=ship.hull_mesh.transform;var profile_before:=var_to_bytes(profile)
		var floor_y:float=gear.get_aabb().position.y
		check(absf(floor_y+float(profile.visual_span_m)*0.14+2.0)<0.001,"Full gear artwork retains the established physical clearance plane: "+profile.id)
		ship.set_landed(false)
		for fraction:float in [0.0,0.25,0.5,0.75,1.0]:
			ship.set_gear_fraction(fraction)
			check(ship._gear_amount==fraction and ship.landing_gear.visible==(fraction>0.01) and is_equal_approx(ship.landing_gear.scale.y,maxf(0.02,fraction)),"Authoritative fraction immediately positions all existing gear struts without waiting for render time: "+profile.id+"/"+str(fraction))
			ship._process(0.5)
			check(ship._gear_amount==fraction and not ship._landed,"Visual wall clock and airborne/landed state cannot override the source mechanism position")
			check(ship.hull_mesh.mesh==hull and ship.landing_gear.mesh==gear and ship.geometry_stats==stats and ship.hull_mesh.transform==local_hull,"Gear movement preserves immutable hull/gear meshes, materials, geometry budget and hull pose")
		ship.set_gear_fraction(0.5);var partial_floor:float=ship.landing_gear.transform.origin.y+floor_y*ship.landing_gear.scale.y
		check(partial_floor>floor_y and partial_floor<0,"Partial deployment moves the existing foot plane between its retracted and full positions")
		ship.set_landed(true);ship._process(1)
		check(ship._gear_amount==0.5 and ship._landed,"Grounded state does not silently force authoritative half-deployed gear fully down")
		ship.set_quality(1);ship.set_process(false)
		check(ship._source_gear_driven and ship._gear_amount==0.5 and ship.landing_gear.scale.y==0.5,"Quality rebuild retains authoritative deployment ownership and current position")
		ship.configure(profile);ship.set_process(false)
		check(ship._source_gear_driven and ship._gear_amount==0.5 and ship.landing_gear.scale.y==0.5 and var_to_bytes(profile)==profile_before,"Reconfiguration retains source fraction without editing a flight profile")
		ship.queue_free();await process_frame
func legacy_reset_and_invalid()->void:
	var ship:=visual({"id":"cobra","visual_span_m":42.0})
	ship.set_gear_fraction(NAN);ship.set_gear_fraction(INF);ship.set_landed(true);ship._process(0.1)
	check(not ship._source_gear_driven and is_equal_approx(ship._gear_amount,0.5),"Invalid first source values cannot claim visual ownership or break legacy landed smoothing")
	ship._process(0.1);check(ship.landing_gear.visible and ship.landing_gear.scale.y==1,"Legacy caller still extends gear over its prior0.2second local smoothing")
	ship.set_landed(false);ship._process(0.2);check(not ship.landing_gear.visible and ship._gear_amount==0,"Legacy airborne caller still retracts gear without needing the new API")
	ship.set_gear_fraction(-1);check(ship._source_gear_driven and ship._gear_amount==0 and not ship.landing_gear.visible,"Negative source fraction is safely bounded to fully retracted")
	ship.set_gear_fraction(2);check(ship._gear_amount==1 and ship.landing_gear.scale.y==1,"Out-of-range upper fraction is bounded to fully deployed")
	ship.set_gear_fraction(0.25);ship.set_gear_fraction(NAN);ship.set_gear_fraction(INF)
	check(ship._source_gear_driven and ship._gear_amount==0.25 and ship.landing_gear.transform.is_finite(),"Invalid updates preserve the last finite authoritative transform")
	ship.set_landed(true);ship.clear_gear_fraction_override()
	check(not ship._source_gear_driven and ship._gear_amount==0.25,"Explicit source-to-training reset resumes legacy ownership without jumping the displayed gear")
	ship._process(0.15);check(ship._gear_amount==1 and ship.landing_gear.scale.y==1,"After explicit reset, the latest landed target resumes the original smoothing")
	ship.queue_free();await process_frame
func before_configure_and_isolation()->void:
	var a:=Ship.new();a.set_gear_fraction(0.25);a.set_quality(0);root.add_child(a);a.configure({"id":"cobra","visual_span_m":42.0});a.set_process(false)
	var b:=visual({"id":"cobra","visual_span_m":42.0});b.set_gear_fraction(0.75)
	check(a._source_gear_driven and a.landing_gear.scale.y==0.25,"Source fraction supplied before geometry initialization is applied to the first configured mesh")
	check(a.landing_gear.mesh==b.landing_gear.mesh and a.landing_gear.scale.y==0.25 and b.landing_gear.scale.y==0.75,"Two visual ships share immutable gear geometry while retaining independent physical fractions")
	a.configure({"id":"eagle","visual_span_m":26.0});a.set_process(false)
	check(a._gear_amount==0.25 and a.landing_gear.scale.y==0.25 and b.landing_gear.scale.y==0.75,"A hull/profile rebuild neither loses source ownership nor moves another ship's mechanism")
	a.queue_free();b.queue_free();await process_frame
func run()->void:
	await source_fraction_and_geometry();await legacy_reset_and_invalid();await before_configure_and_isolation()
	print("GEAR SHIP VISUAL TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
