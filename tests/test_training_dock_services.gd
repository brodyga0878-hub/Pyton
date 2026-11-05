extends SceneTree
# Real-flight transactions plus malformed-state controls use no game/user files.
const Services=preload("res://scripts/training_dock_services.gd")
const Flight=preload("res://scripts/flight_model.gd")
const NavigationData=preload("res://scripts/navigation.gd")
class MalformedShip extends RefCounted:
	var hull:Variant=75.0
	var credits:Variant=1000
	var original_port:Variant=false
	var docked:Variant=true
	var surface_mode:Variant=false
	var combat_active:Variant=false
	var station_available:Variant=true
	var goods:Dictionary={"medicines":2}
	var equipment:Array=["shield"]
	func snapshot()->Dictionary:
		return {"hull":hull,"credits":credits,"original_port":original_port,"docked":docked,"surface_mode":surface_mode,"combat_active":combat_active,"station_available":station_available,"goods":goods.duplicate(),"equipment":equipment.duplicate()}
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func state(ship:RefCounted)->PackedByteArray:
	return var_to_bytes({"save":ship.snapshot(),"original_port":ship.get("original_port"),"surface_mode":ship.get("surface_mode"),"combat_active":ship.get("combat_active"),"station_available":ship.get("station_available")})
func docked_ship(hull:=75.0,credits:=1000)->RefCounted:
	var ship:=Flight.new();ship.position=ship.STATION+Vector3.BACK*80.0;ship.hull=hull;ship.credits=credits
	check(ship.dock(),"Independent actual training dock accepts the fixture ship")
	return ship
func reject_atomic(ship:RefCounted,status:String)->void:
	var before:=state(ship)
	var quote:=Services.repair_quote(ship)
	check(not quote.ok and quote.status==status,"Quote rejects with distinct status "+status)
	check(state(ship)==before,"Rejected quote does not mutate ship: "+status)
	var result:=Services.repair(ship)
	check(not result.ok and result.status==status,"Transaction rejects with distinct status "+status)
	check(state(ship)==before,"Rejected transaction preserves complete save/runtime state: "+status)
func successful_repairs()->void:
	for sample in [[75.0,1000,50],[99.9,10,1],[0.1,200,200],[50.25,100,100]]:
		var ship:=docked_ship(float(sample[0]),int(sample[1]));ship.goods.food=3;ship.equipment=["shield"]
		var before:Dictionary=ship.snapshot();var original:=state(ship)
		var quote:=Services.repair_quote(ship)
		check(quote.ok and quote.status=="available" and quote.cost==int(sample[2]),"Repair quote uses rounded-up2-credit-per-percent price")
		check(quote.hull_after==100.0 and quote.credits_after==int(sample[1])-int(sample[2]),"Quote reports the exact resulting balance")
		check(state(ship)==original,"Successful quote is read-only")
		var result:=Services.repair(ship)
		check(result.ok and result.status=="repaired" and result.cost==int(sample[2]),"Actual repair transaction succeeds at the quoted cost")
		check(ship.hull==100.0 and ship.credits==int(sample[1])-int(sample[2]),"Only damage and exact credit charge are applied")
		var expected:Dictionary=before.duplicate(true);expected.hull=100.0;expected.credits=int(sample[1])-int(sample[2])
		check(ship.snapshot()==expected and ship.docked and not ship.original_port and not ship.surface_mode,"Repair preserves all cargo, equipment, identity and flight fields")
		reject_atomic(ship,"already_repaired")
func rejected_contexts()->void:
	reject_atomic(docked_ship(75.0,49),"insufficient_funds")
	reject_atomic(docked_ship(99.9,0),"insufficient_funds")
	var ship:=docked_ship();ship.original_port=true;reject_atomic(ship,"context_unavailable")
	ship=docked_ship();ship.docked=false;reject_atomic(ship,"context_unavailable")
	ship=docked_ship();ship.surface_mode=true;reject_atomic(ship,"context_unavailable")
	ship=docked_ship();ship.combat_active=true;reject_atomic(ship,"context_unavailable")
	ship=docked_ship();ship.station_available=false;reject_atomic(ship,"context_unavailable")
	ship=docked_ship();ship.hull=0;reject_atomic(ship,"destroyed")
func malformed_states()->void:
	check(Services.repair_quote(null).status=="invalid_state" and not Services.repair(null).ok,"Absent ship rejects without dereference")
	for value in [NAN,INF,-INF,-0.01,100.01,"75",true]:
		var ship:=MalformedShip.new();ship.hull=value;reject_atomic(ship,"invalid_state")
	for value in [NAN,INF,-INF,-1,1000000001,2.5,"1000",true]:
		var ship:=MalformedShip.new();ship.credits=value;reject_atomic(ship,"invalid_state")
	for name in ["original_port","docked","surface_mode","combat_active","station_available"]:
		var ship:=MalformedShip.new();ship.set(name,1);reject_atomic(ship,"invalid_state")
func joint_state(ship:RefCounted,nav:RefCounted)->PackedByteArray:
	return var_to_bytes({"ship":state(ship),"nav":nav.snapshot(),"nav_message":nav.message,"station_override":nav.get("station_override")})
func reject_execution(ship:RefCounted,nav:RefCounted,action:String,id:="")->void:
	var before:=joint_state(ship,nav);var result:=Services.execute(ship,nav,action,id)
	check(not result.ok and not result.ship_changed,"Unavailable executor command rejected: "+action+":"+id)
	check(joint_state(ship,nav)==before,"Rejected executor command keeps all model/save/message fields: "+action+":"+id)
func market_quotes_and_execution()->void:
	var ship:=docked_ship(75,10000);var nav:=NavigationData.new();nav.fuel=4
	var before:=joint_state(ship,nav);var quoted:=Services.service_state(ship,nav)
	check(joint_state(ship,nav)==before,"Entire dock view quotation is read-only")
	check(quoted.goods.size()==6 and quoted.ships.size()==3,"View receives every current adapted good and ship")
	check(quoted.cargo_used==ship.total_cargo() and quoted.cargo_capacity==ship.cargo_capacity() and quoted.profile_name==ship.profile().name,"View summary derives actual inventory and ship metadata")
	check(quoted.fuel==4 and quoted.fuel_capacity==nav.FUEL_CAPACITY and quoted.repair.price==50 and quoted.refuel.price==80,"Repair and fuel quote show actual damaged/missing amounts")
	for row in quoted.goods:
		var good:Dictionary=ship.economy_catalog.goods[row.id]
		check(row.buy_price==good.price and row.sell_price==floori(float(good.price)*0.8),"Both goods quotes use underlying catalogue price: "+str(row.id))
		ship=docked_ship(75,10000);nav=NavigationData.new()
		var owned:int=ship.goods[row.id];var credits:int=ship.credits
		var purchased:=Services.execute(ship,nav,"buy",str(row.id))
		check(purchased.ok and not purchased.ship_changed and ship.goods[row.id]==owned+1 and ship.credits==credits-int(row.buy_price),"Quoted purchase executes exactly one unit with exact charge: "+str(row.id))
		var sold:=Services.execute(ship,nav,"sell",str(row.id))
		check(sold.ok and not sold.ship_changed and ship.goods[row.id]==owned and ship.credits==credits-int(row.buy_price)+int(row.sell_price),"Quoted sale executes exactly one unit with exact refund: "+str(row.id))
	ship=docked_ship(75,1000);nav=NavigationData.new();ship.goods.food=58
	var full:=Services.service_state(ship,nav)
	check(full.cargo_used==full.cargo_capacity and not full.goods[0].can_buy,"Full hold disables buying before execution")
	reject_execution(ship,nav,"buy","medicines")
	ship=docked_ship(75,0);nav=NavigationData.new();reject_execution(ship,nav,"buy","food");reject_execution(ship,nav,"sell","food")
	ship=docked_ship(75,MAX_BALANCE);nav=NavigationData.new();reject_execution(ship,nav,"sell","medicines");reject_execution(ship,nav,"deliver")
	ship=docked_ship();nav=NavigationData.new();reject_execution(ship,nav,"buy","unknown");reject_execution(ship,nav,"trade_ship","unknown");reject_execution(ship,nav,"unknown")
const MAX_BALANCE:=1000000000
func other_services_execution()->void:
	var ship:=docked_ship(64.5,1000);var nav:=NavigationData.new();var q:=Services.service_state(ship,nav)
	check(q.repair.price==71 and q.repair.can_repair,"Executor repair quote retains fractional damage rounding")
	var repaired:=Services.execute(ship,nav,"repair")
	check(repaired.ok and not repaired.ship_changed and ship.hull==100 and ship.credits==929,"Executor repairs at model price without requesting a hull/profile reconstruction")
	reject_execution(ship,nav,"repair")
	ship=docked_ship(75,100);nav=NavigationData.new();nav.fuel=2;q=Services.service_state(ship,nav)
	check(q.refuel.can_refuel and q.refuel.price==100,"Full-refuel quote uses the exact missing amount")
	var refueled:=Services.execute(ship,nav,"refuel")
	check(refueled.ok and nav.fuel==nav.FUEL_CAPACITY and ship.credits==0 and not refueled.ship_changed,"Underlying refuel executes the exact quote once")
	reject_execution(ship,nav,"refuel")
	ship=docked_ship(75,99);nav=NavigationData.new();nav.fuel=2;reject_execution(ship,nav,"refuel")
	ship=docked_ship(75,1000);nav=NavigationData.new();q=Services.service_state(ship,nav)
	check(q.delivery.can_deliver and q.delivery.reward==800,"Default training cargo quote matches underlying delivery reward")
	var delivered:=Services.execute(ship,nav,"deliver")
	check(delivered.ok and ship.cargo==0 and ship.credits==1800 and ship.delivered,"Training delivery executes once and removes the paid cargo")
	reject_execution(ship,nav,"deliver")
	for target in ["eagle","shuttle"]:
		ship=docked_ship(75,6000);nav=NavigationData.new();q=Services.service_state(ship,nav)
		var expected_cost:int=ship.economy_catalog.ship_prices[target]-ship.ship_trade_value()
		var price_found:=false
		for row in q.ships:
			if row.id==target:price_found=row.can_trade and row.trade_cost==expected_cost and not row.current
		check(price_found,"Ship-exchange quote uses the actual model resale formula: "+target)
		var changed:=Services.execute(ship,nav,"trade_ship",target)
		check(changed.ok and changed.ship_changed and ship.ship_id==target and ship.credits==6000-expected_cost and ship.hull==75,"Exchange executes exact signed quote and preserves damage: "+target)
	ship=docked_ship();nav=NavigationData.new();reject_execution(ship,nav,"trade_ship","cobra")
func every_executor_context_guard()->void:
	for blocked in ["original_port","docked","surface_mode","combat_active","station_available","jump","destroyed","invalid_credits","invalid_fuel"]:
		var ship:=docked_ship();var nav:=NavigationData.new();nav.fuel=2
		if blocked=="jump":nav.remaining=1.0
		elif blocked=="destroyed":ship.hull=0
		elif blocked=="invalid_credits":ship.credits=-1
		elif blocked=="invalid_fuel":nav.fuel=-1
		else:ship.set(blocked,blocked in ["original_port","surface_mode","combat_active"])
		for command in [["buy","food"],["sell","medicines"],["repair",""],["refuel",""],["deliver",""],["trade_ship","eagle"]]:
			reject_execution(ship,nav,str(command[0]),str(command[1]))
		var before:=joint_state(ship,nav);var q:=Services.service_state(ship,nav)
		check(joint_state(ship,nav)==before,"Blocked quotation leaves models unchanged: "+blocked)
		check(not q.repair.can_repair and not q.refuel.can_refuel and not q.delivery.can_deliver,"All summary actions disabled in blocked context: "+blocked)
		for row in q.goods:check(not row.can_buy and not row.can_sell,"Market context disables both operations for "+str(row.id))
		for row in q.ships:check(not row.can_trade,"Ship-exchange context disabled for "+str(row.id))
func run()->void:
	successful_repairs();rejected_contexts();malformed_states()
	print("TRAINING REPAIR TRANSACTION BATCH: %d verified conditions; failures=%d"%[checks,failures])
	market_quotes_and_execution();other_services_execution();every_executor_context_guard()
	print("TRAINING DOCK SERVICES TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
