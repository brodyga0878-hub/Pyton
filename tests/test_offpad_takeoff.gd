extends SceneTree
# Current Surface model regression: neutral takeoff already works outside a pad.
# Positive lift from a healthy landed ship must not be silently ignored.
const Surface=preload("res://scripts/surface_model.gd")
const Ship=preload("res://scripts/flight_model.gd")
const World=preload("res://scripts/planetary_system.gd")
const Navigation=preload("res://scripts/navigation.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func json_copy(value:Dictionary)->Dictionary:return JSON.parse_string(JSON.stringify(value))
func context(mode:String,id:String)->Dictionary:
	var navigation:=Navigation.new();var world:=World.new();world.configure(navigation.current())
	world.focus_id="earth";world.selected_id="earth";world.site_id="site10" if mode=="source_city" else ""
	var ship:=Ship.new();ship.ship_id=id
	# The unupgraded Shuttle is correctly rejected by Earth's gravity guard.
	if id=="shuttle":ship.equipment.append("engine");ship.goods.medicines=0
	var surface:=Surface.new()
	check(surface.enter(ship,world,mode!="local"),"Surface entry supports the eligible "+mode+" "+id+" loadout")
	return {"surface":surface,"ship":ship,"world":world}
func landed_offpad(ctx:Dictionary,at:Vector2)->bool:
	var surface:RefCounted=ctx.surface;var ship:RefCounted=ctx.ship
	surface.landed=false;surface.landing=false;surface.taking_off=false;surface.flight_phase=""
	ship.position=Vector3(at.x,surface.height_at(at.x,at.y)+surface.clearance(ship)+0.5,at.y)
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.hull=100
	if surface.overlaps_building(ship):return false
	return surface.touch_down(ship)
func simulate(surface:RefCounted,ship:RefCounted,lift:float,frames:=250)->void:
	for tick in range(frames):surface.step(0.05,ship,Vector2.ZERO,0,lift)
func case_for(mode:String,id:String)->void:
	var ctx:=context(mode,id);var surface:RefCounted=ctx.surface;var ship:RefCounted=ctx.ship
	if not surface.active:return
	check(landed_offpad(ctx,Vector2(300,200)),"Soft manual contact lands clear of buildings outside the marked pad: "+mode+" "+id)
	if not surface.landed:return
	check(surface.pad_distance(ship)>80 and ship.hull==100,"Fixture is an actual healthy off-pad landing: "+mode+" "+id)
	var saved_surface:Dictionary=json_copy(surface.snapshot());var saved_ship:Dictionary=json_copy(ship.snapshot())
	var position:Vector3=ship.position
	simulate(surface,ship,0,10);simulate(surface,ship,-1,10)
	check(surface.landed and ship.position==position and ship.hull==100,"Neutral/downward input keeps a landed ship safely on the ground: "+mode+" "+id)
	check(surface.take_off(ship),"Explicit takeoff accepts the healthy off-pad landing: "+mode+" "+id)
	simulate(surface,ship,0)
	check(not surface.landed and not surface.taking_off and surface.altitude(ship)>=34.5 and ship.hull==100,"Explicit takeoff clears the terrain without hull damage: "+mode+" "+id)
	var fresh_ship:=Ship.new();var fresh_surface:=Surface.new()
	check(fresh_ship.restore(saved_ship) and fresh_surface.restore(saved_surface,fresh_ship,ctx.world),"Restore returns the same healthy off-pad landing before testing touch lift: "+mode+" "+id)
	simulate(fresh_surface,fresh_ship,1)
	check(not fresh_surface.landed and fresh_surface.altitude(fresh_ship)>35 and fresh_ship.hull==100,"Holding the enabled positive-lift control lifts a healthy landed ship after restore: "+mode+" "+id)
	# Repeat the same positive control on the original (unrestored) contact path.
	var direct:=context(mode,id)
	check(landed_offpad(direct,Vector2(-300,200)),"Second clean off-pad fixture lands for direct touch-lift: "+mode+" "+id)
	simulate(direct.surface,direct.ship,1)
	check(not direct.surface.landed and direct.surface.altitude(direct.ship)>35 and direct.ship.hull==100,"Positive lift works before any reload as well: "+mode+" "+id)
func steep_ground()->void:
	var ctx:=context("local","cobra");var surface:RefCounted=ctx.surface;var ship:RefCounted=ctx.ship
	var selected:=Vector2.ZERO;var steepness:=0.0
	for x in range(-1500,1501,250):
		for z in range(-1000,1001,250):
			if Vector2(x,z).length()>1700 or Vector2(x,z).length()<450:continue
			var slope:=Vector2(surface.height_at(x+1,z)-surface.height_at(x-1,z),surface.height_at(x,z+1)-surface.height_at(x,z-1)).length()*0.5
			if slope>steepness:steepness=slope;selected=Vector2(x,z)
	check(steepness>0.1,"Off-pad regression includes a real sloping rendered terrain cell")
	check(landed_offpad(ctx,selected),"Slope fixture uses normal manual touchdown on the existing mesh height")
	simulate(surface,ship,1)
	check(not surface.landed and surface.altitude(ship)>35 and ship.hull==100,"Positive lift clears a sloping terrain cell without a pad permission check")
func damaged_and_destroyed()->void:
	var ctx:=context("local","cobra");var surface:RefCounted=ctx.surface;var ship:RefCounted=ctx.ship
	ship.position=Vector3(300,surface.height_at(300,200)+surface.clearance(ship)+3,200)
	ship.velocity=Vector3.DOWN*16;ship.target_speed=0;ship.assisted=false
	surface.step(0.25,ship,Vector2.ZERO,0)
	check(surface.landed and ship.hull>0 and ship.hull<100,"A survivable hard off-pad impact retains a damaged but usable ship")
	var hull:float=ship.hull;simulate(surface,ship,1)
	check(not surface.landed and surface.altitude(ship)>35 and ship.hull==hull,"A damaged surviving ship can lift without repeatedly taking contact damage")
	check(landed_offpad(ctx,Vector2(300,200)),"Destroyed-ship guard uses a normal grounded context")
	ship.hull=0
	var before_flight:=JSON.stringify(ship.snapshot());var before_surface:=JSON.stringify(surface.snapshot())
	check(not surface.take_off(ship),"A destroyed hull is correctly refused takeoff")
	simulate(surface,ship,1)
	check(JSON.stringify(ship.snapshot())==before_flight and JSON.stringify(surface.snapshot())==before_surface,"Positive lift cannot revive or move a destroyed ship")
func run()->void:
	for mode in ["local","globe","source_city"]:
		for id in ["cobra","eagle","shuttle"]:case_for(mode,id)
	steep_ground();damaged_and_destroyed()
	print("OFFPAD TAKEOFF TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
