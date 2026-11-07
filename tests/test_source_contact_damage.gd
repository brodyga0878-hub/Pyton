extends SceneTree
const Nav=preload("res://scripts/navigation.gd")
const Session=preload("res://scripts/source_hyperdrive_session.gd")
const Core=preload("res://scripts/source_atmospheric_dynamics.gd")
const Ship=preload("res://scripts/flight_model.gd")
const ALPHA:=111449880
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func encoded(nav:RefCounted)->String:return JSON.stringify(nav.snapshot())
func source(ship:RefCounted)->RefCounted:
	var nav:=Nav.new();check(nav.configure_source(ship.ship_id) and nav.sync_source_ship(ship) and nav.bind_thermal_ship(ship),"Existing shared raw HP and cargo bind to actual fractional ship state")
	return nav
func data(nav:RefCounted)->Dictionary:return nav.snapshot().source_hyperdrive
func hit(amount:int,attacker:int=0)->Dictionary:return {"amount_s32":amount,"attacker_u32":attacker}
func has_callback(callbacks:Array,name:String)->bool:
	for callback:Dictionary in callbacks:
		if callback.get("function")==name:return true
	return false
func _initialize()->void:call_deferred("run")

func fractional_hull_and_local_rng()->void:
	var ship:=Ship.new();ship.hull=37.625;var nav:=source(ship)
	var before:Dictionary=data(nav);var fuel:=JSON.stringify(before.fuel_system);var ship_before:=ship.snapshot()
	var call:Array=[hit(1,0xffffffff)];var input_before:=JSON.stringify(call)
	var expected:=Core.rng({"seed_a_u32":int(before.thermal_system.rng_seed_a_u32),"seed_b_u32":int(before.thermal_system.rng_seed_b_u32)})
	var result:Dictionary=nav.apply_contact_damage(call,ship);var after:Dictionary=data(nav);var detail:Dictionary=result.contact_damage
	check(result.ok and detail.applied_calls==1 and detail.raw_hull_before==151 and detail.raw_hull_after==150,"Source minimum raw damage1 consumes the existing ceil151 anchor")
	check(ship.hull==37.375 and detail.hull_percent_before==37.625 and detail.hull_percent_after==37.375 and detail.hull_percent_loss==0.25,"Contact projects one raw point as0.25percent without rounding37.625")
	check(detail.rng_consumed and after.thermal_system.rng_seed_a_u32==expected.state.seed_a_u32 and after.thermal_system.rng_seed_b_u32==expected.state.seed_b_u32,"Contact uses the existing shared local F1530 stream exactly once")
	check(after.thermal_system.hull_anchor_raw_u16==before.thermal_system.hull_anchor_raw_u16 and after.thermal_system.hull_anchor_percent_f64_hex==before.thermal_system.hull_anchor_percent_f64_hex,"Contact never creates a second HP store or reanchors fractional HP")
	check(JSON.stringify(after.fuel_system)==fuel and after.fuel_system.size()==17 and after.thermal_system.size()==27,"Every fuel quantity/heat/cadence value and both strict schemas remain unchanged")
	for key in ["phase_f64_hex","frame_tick_remainder_raw","tick_fraction_anchor_f64_hex","last_atmosphere_active","last_drag_active","last_hull_damage_u16","last_shield_damage_u16","wind_flags_u8"]:
		check(after.thermal_system[key]==before.thermal_system[key],"Contact does not advance or relabel thermal field "+key)
	check(not nav.thermal_state(ship).atmosphere_active and not str(nav.thermal_state(ship).damage_status).contains("атмосфер"),"Contact hull loss is not presented as a new atmospheric event")
	check(not result.has("thermal") and has_callback(result.callbacks,"F34") and has_callback(result.callbacks,"F1530"),"Contact observations are separate from atmospheric drag and retain source callback requests")
	check(JSON.stringify(call)==input_before and ship.goods==ship_before.goods and ship.credits==ship_before.credits,"Caller damage list, goods and credits are never rewritten")
	var cold_ship:=Ship.new();check(cold_ship.restore(copy(ship.snapshot())),"Fractional damaged Flight restores through ordinary JSON")
	var cold:=Nav.new();check(cold.restore(copy(nav.snapshot())) and cold.bind_thermal_ship(cold_ship),"Existing shared raw contact HP/RNG survives cold source restore")
	var live_next:Dictionary=nav.apply_contact_damage([hit(1)],ship);var cold_next:Dictionary=cold.apply_contact_damage([hit(1)],cold_ship)
	check(live_next.ok and cold_next.ok and JSON.stringify(data(nav))==JSON.stringify(data(cold)) and ship.hull==cold_ship.hull,"Cold continuation preserves exact anchored HP and RNG sequence without replaying old damage")

func shield_zero_empty_and_status_history()->void:
	var ship:=Ship.new();ship.hull=37.625;var nav:=source(ship);var saved:Dictionary=nav.snapshot()
	saved.source_hyperdrive.thermal_system.shield_max_u16=10;saved.source_hyperdrive.thermal_system.shield_u16=10
	check(nav.restore(saved) and nav.bind_thermal_ship(ship),"Explicit raw shield fixture is valid independently of a full equipment market")
	var before:Dictionary=data(nav);var result:Dictionary=nav.apply_contact_damage([hit(5)],ship)
	check(result.ok and ship.hull==37.625 and result.contact_damage.shield_damage_u16==5 and result.contact_damage.hull_damage_u16==0,"F953 shield absorbs contact loss without touching hull percent")
	check(not result.contact_damage.rng_consumed and result.contact_damage.rng_state_after==result.contact_damage.rng_state_before,"Shield absorption does not consume the hull-damage random branch")
	check(data(nav).thermal_system.last_shield_damage_u16==before.thermal_system.last_shield_damage_u16,"Contact shield loss does not become atmospheric shield-loss history")
	var protected:=encoded(nav);var hp:float=ship.hull
	result=nav.apply_contact_damage([],ship)
	check(result.ok and not result.contact_damage.changed and result.callbacks.is_empty() and result.contact_damage.applied_calls==0 and encoded(nav)==protected and ship.hull==hp,"Empty source landing response is a strict no-effect without HP projection or clocks")
	var zero_ship:=Ship.new();var zero:=source(zero_ship);result=zero.apply_contact_damage([hit(0)],zero_ship)
	check(result.ok and zero_ship.hull==100 and not result.contact_damage.rng_consumed and has_callback(result.callbacks,"F1907"),"A real F953zero call retains its source flag/sound observations and is not confused with an empty list")
	check(data(zero).thermal_system.damage_flags_u8&1==1 and data(zero).thermal_system.last_hull_damage_u16==0,"Zero damage changes only actual F953 fields, never fake atmospheric history")
	var history_ship:=Ship.new();var history:=source(history_ship)
	var atmosphere:={"apply_f1014":true,"altitude_s32":100,"speed_s32":8192,"velocity_s32":[8192,0,0],"gear_down":false,"wind_enabled":false,"wind_armed":false,"parent_shield_s16":0,"wind_flags_u8":0,"step_ticks_u32":828}
	check(history.thermal_step(atmosphere,history_ship).ok,"Actual preceding atmosphere/drag creates independent source history")
	before=data(history);result=history.apply_contact_damage([hit(3)],history_ship)
	check(result.ok and result.contact_damage.hull_damage_u16==3,"New contact loss is returned in its own result")
	for key in ["last_atmosphere_active","last_drag_active","last_hull_damage_u16","last_shield_damage_u16","phase_f64_hex","frame_tick_remainder_raw"]:check(data(history).thermal_system[key]==before.thermal_system[key],"Preceding atmosphere history is preserved rather than replaced by contact: "+key)
	check(JSON.stringify(data(history).fuel_system)==JSON.stringify(before.fuel_system),"Contact does not heat, cool, feed, scoop or advance the prior fuel state")

func fatality_and_multiple_calls()->void:
	var ship:=Ship.new();ship.hull=37.625;var nav:=source(ship);nav.select(ALPHA)
	check(nav.begin_jump(ship),"Source hyperjump charge is pending before the fatal contact")
	var before:Dictionary=data(nav);var old_time:float=nav.elapsed_days
	var result:Dictionary=nav.apply_contact_damage([hit(-1)],ship);var after:Dictionary=data(nav)
	check(result.ok and result.destruction_requested and result.contact_destruction_requested and result.hyperjump_cancelled and ship.hull==0,"Fatal source contact projects HP0 and cancels source charge in the same commit")
	check(after.thermal_system.destroyed and after.thermal_system.hull_u16==before.thermal_system.hull_u16 and result.contact_damage.hull_percent_loss==37.625,"Fatal F942request preserves its actual stale native hull word without reviving the ship")
	check(nav.remaining==0 and nav.pending_id==-1 and nav.fuel==4 and nav.elapsed_days==old_time and JSON.stringify(after.fuel_system)==JSON.stringify(before.fuel_system),"Fatal contact never commits jump fuel/time or an unrelated fuel/thermal tick")
	check(has_callback(result.callbacks,"F942") and not result.contact_damage.rng_consumed,"Fatal branch returns destruction observation without inventing a random draw")
	var protected:=encoded(nav);result=nav.apply_contact_damage([],ship)
	check(result.ok and not result.destruction_requested and encoded(nav)==protected and ship.hull==0,"Empty list on a valid destroyed state is still a no-effect, not a second fatal event")
	var dead:=Nav.new();check(dead.restore(copy(nav.snapshot())) and dead.bind_thermal_ship(ship) and ship.hull==0,"Fatal shared state saves/restores without duplicate damage or HP healing")
	var mixed_ship:=Ship.new();mixed_ship.hull=37.625;var mixed:=source(mixed_ship)
	result=mixed.apply_contact_damage([hit(1),hit(-1),hit(1)],mixed_ship)
	check(result.ok and result.contact_damage.applied_calls==2 and mixed_ship.hull==0 and result.contact_damage.raw_hull_after==150,"Ordered composition stops after the first fatal request and does not damage a removed object again")
	var tiny_ship:=Ship.new();tiny_ship.hull=0.01;var tiny:=source(tiny_ship)
	check(data(tiny).thermal_system.hull_u16==1,"Small positive legacy percentage binds to minimum raw hull1 without rounding visible HP")
	result=tiny.apply_contact_damage([hit(1)],tiny_ship)
	check(result.ok and result.destruction_requested and tiny_ship.hull==0 and result.contact_damage.hull_percent_loss==0.01,"Exact raw1 equality is fatal and preserves the original tiny percent until impact")

func invalid_and_explicit_sync()->void:
	var ship:=Ship.new();ship.hull=37.625;var nav:=source(ship);var protected:=encoded(nav);var hp:float=ship.hull
	var invalid:Array=[[{}],[1],[{"amount_s32":1}],[{"amount_s32":1,"attacker_u32":0,"extra":0}],[hit(1),{"amount_s32":1.5,"attacker_u32":0}],[{"amount_s32":2147483648,"attacker_u32":0}],[{"amount_s32":-2147483649,"attacker_u32":0}],[{"amount_s32":1,"attacker_u32":-1}],[{"amount_s32":1,"attacker_u32":4294967296}],[{"amount_s32":true,"attacker_u32":0}],[{"amount_s32":NAN,"attacker_u32":0}]]
	var huge:Array=[]
	for _index in range(Session.MAX_CONTACT_DAMAGE_CALLS+1):huge.append(hit(1))
	invalid.append(huge)
	for calls:Array in invalid:
		var result:Dictionary=nav.apply_contact_damage(calls,ship)
		check(not result.ok and result.get("callbacks",[]).is_empty() and encoded(nav)==protected and ship.hull==hp,"Malformed list rejects atomically before any HP/RNG/callback emission, including a bad tail after a valid call")
	ship.hull=31.2345
	check(not nav.apply_contact_damage([hit(1)],ship).ok and encoded(nav)==protected and ship.hull==31.2345,"Contact consumer never silently reanchors a preceding unrelated collision")
	check(nav.sync_thermal_ship(ship),"Host explicitly acknowledges the preceding non-source collision once")
	var before:float=ship.hull;var result:Dictionary=nav.apply_contact_damage([hit(1)],ship)
	check(result.ok and ship.hull==before-0.25,"After explicit live sync only the new source raw damage is projected once")
	ship.goods.medicines+=1;protected=encoded(nav);hp=ship.hull
	check(not nav.apply_contact_damage([],ship).ok and encoded(nav)==protected and ship.hull==hp,"Even an empty contact list cannot silently replace mismatched cargo/bridge state")
	var legacy:=Nav.new();check(legacy.configure_native() and not legacy.apply_contact_damage([hit(1)],Ship.new()).ok,"Legacy hyperdrive navigation stays on its previous contact path without silent migration")

func run()->void:
	fractional_hull_and_local_rng();shield_zero_empty_and_status_history();fatality_and_multiple_calls();invalid_and_explicit_sync()
	print("SOURCE CONTACT DAMAGE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
