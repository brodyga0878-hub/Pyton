extends SceneTree
const Trial=preload("res://scripts/native_landing_trial.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Nav=preload("res://scripts/navigation.gd")
const Gear=preload("res://scripts/source_landing_gear_session.gd")
const World=preload("res://scripts/planetary_system.gd")
const FuelFlight=preload("res://scripts/source_fuel_flight_bridge.gd")
const REPORT:="res://build/current-test-reports/native-landing-trial.json"
var checks:=0
var failures:=0

# This harness injects failures AFTER real shared-HP processing. It checks the
# transaction boundary, independently of the separate original-kernel bank.
class StagedSurface extends RefCounted:
	var active:=true
	var landed:=false
	var landing:=false
	var ready_for_orbit:=false
	var calls:Array=[]
	var reject_stage:=false
	var reject_commit:=false
	var reject_anchor:=false
	var bad_atmosphere:=false
	var accepting:=false
	var days:=0.0
	var generation:=0
	var world:RefCounted
	func _init()->void:world=World.new()
	func source_surface()->bool:return false
	func native_world()->RefCounted:return null if bad_atmosphere else world
	func set_source_time(value:float)->void:days=value
	func fork_runtime(_ship:RefCounted)->RefCounted:
		var result:=StagedSurface.new()
		for property:Dictionary in get_property_list():
			if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)!=0:
				var value:Variant=get(str(property.name))
				result.set(str(property.name),value.duplicate(true) if value is Array or value is Dictionary else value)
		return result
	func stage_manual(ship:RefCounted,seconds:float,steering:Vector2,roll:float,lift:float,_gear:int,_receipt:Dictionary)->Dictionary:
		ship.step(seconds,steering,roll,Vector3.ZERO,lift)
		if reject_stage:return {"ok":false,"reason":"injected_stage_failure"}
		return {"ok":true,"parked_idle":landed,"landing_accepted":accepting,"damage_calls":calls.duplicate(true),"fuel_commands":FuelFlight.commands(ship,seconds),"contact_detected":not calls.is_empty() or accepting}
	func finish_native_step(ship:RefCounted,_stage:Dictionary,parked:bool,_hp:Dictionary)->bool:
		if reject_commit:return false
		generation+=1;landed=parked
		if landed:ship.velocity=Vector3.ZERO;ship.target_speed=0
		return true
	func acknowledge_post_interval(_ship:RefCounted)->bool:return not reject_anchor
	func snapshot()->Dictionary:return {"landed":landed,"days":days,"generation":generation,"calls":calls.duplicate(true),"world_count":world.native_evaluation_count}

func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func fixture()->Dictionary:
	var ship:=Ship.new();ship.surface_mode=true;ship.station_available=false;ship.source_motion_profile=true;ship.assisted=false;ship.position=Vector3(0,80,0)
	var nav:=Nav.new();check(nav.configure_source(ship.ship_id) and nav.sync_source_ship(ship) and nav.bind_thermal_ship(ship),"Transaction fixture uses actual source fuel/HP owner")
	var gear:=Gear.new();check(gear.configure(true),"Transaction fixture uses actual persisted landing gear")
	var surface:=StagedSurface.new();surface.world.native_evaluation_count=47
	return {"ship":ship,"nav":nav,"gear":gear,"surface":surface}
func state(row:Dictionary)->PackedByteArray:
	return var_to_bytes([row.ship.snapshot(),row.ship.source_thrust_limits_u16,row.ship.propulsion_available,row.ship.last_propulsive_delta_v,row.nav.snapshot(),row.nav.message,row.gear.snapshot(),row.surface.snapshot()])
func execute(row:Dictionary,dt:=1.0/60.0,lift:=0.0)->Dictionary:return Trial.prepare(row.ship,row.nav,row.gear,row.surface,dt,Vector2.ZERO,0,lift)
func row_from(result:Dictionary)->Dictionary:return {"ship":result.candidate_ship,"nav":result.candidate_nav,"gear":result.candidate_gear,"surface":result.candidate_surface}

func failure_atomicity()->void:
	for fail:String in ["reject_stage","reject_commit","reject_anchor","bad_atmosphere"]:
		var row:=fixture();row.surface.calls=[{"amount_s32":1,"attacker_u32":0xffffffff}];row.surface.set(fail,true)
		var before:=state(row);var result:=execute(row)
		check(not result.ok,"Injected late failure is rejected: "+fail)
		check(state(row)==before,"Failure keeps exact ship/gear/time/fuel/HP/RNG/native history: "+fail)
		check(row.surface.world.native_evaluation_count==47,"Rejected preparation never evaluates or mutates original World: "+fail)
	var invalid:=fixture();var before:=state(invalid)
	for dt:float in [0.0,-0.1,INF,NAN,4.01]:check(not execute(invalid,dt).ok,"Invalid time interval rejects before mutation")
	check(state(invalid)==before,"Malformed interval leaves all actual owners unchanged")

func exact_damage_and_time()->void:
	var row:=fixture();row.ship.hull=37.625;check(row.nav.sync_thermal_ship(row.ship),"Fractional hull binds existing raw anchor")
	row.ship.target_speed=60;row.surface.calls=[{"amount_s32":1,"attacker_u32":0xffffffff}]
	var before:=state(row);var expected_nav:RefCounted=row.nav.fork_runtime();var expected_ship:RefCounted=Trial._fork_ship(row.ship)
	var expected:Dictionary=expected_nav.apply_contact_damage(row.surface.calls,expected_ship)
	var result:=execute(row,0.1)
	check(result.ok,"Real raw HP, fuel, gear and clock interval prepares successfully")
	if not result.ok:return
	check(state(row)==before,"Even successful prepare leaves the source owners untouched")
	check(result.candidate_ship.hull==37.375 and result.damage.contact_damage.applied_calls==1,"One source call applies one quarter percent without rounding fractional hull")
	var actual_raw:Dictionary=result.candidate_nav.snapshot().source_hyperdrive.thermal_system
	var expected_raw:Dictionary=expected_nav.snapshot().source_hyperdrive.thermal_system
	for key:String in ["hull_u16","hull_anchor_raw_u16","hull_anchor_percent_f64_hex","rng_seed_a_u32","rng_seed_b_u32"]:check(actual_raw[key]==expected_raw[key],"Same shared F953 owner and F1530 stream: "+key)
	check(result.damage.contact_damage.rng_state_after==expected.contact_damage.rng_state_after,"No duplicate damage/replay random draw")
	check(result.candidate_nav.elapsed_days==row.nav.elapsed_days+0.1/86400.0 and result.candidate_surface.days==result.candidate_nav.elapsed_days,"Celestial time and terrain time advance by the identical accepted interval")
	check(result.candidate_gear.snapshot()!=row.gear.snapshot() and actual_raw.frame_tick_remainder_raw!=row.nav.snapshot().source_hyperdrive.thermal_system.frame_tick_remainder_raw,"Both independent fixed-host schedulers preserve fractional progress")
	check(result.candidate_ship.target_speed==60 and not result.candidate_surface.landed,"Unsafe hit does not silently park or clear controls")
	var retry:=execute(row,0.1)
	check(retry.ok and state(row_from(retry))==state(row_from(result)),"Retrying uncommitted originals produces the same single interval without accumulation")

func dry_thrust_and_nohit()->void:
	var row:=fixture();var saved:Dictionary=row.nav.snapshot();saved.source_hyperdrive.fuel_system.jet_raw_u32=0;saved.source_hyperdrive.fuel_system.disabled_axes_mask_u8=0x15;saved.source_hyperdrive.fuel_system.status_u16=1
	check(row.nav.restore(saved) and row.nav.bind_thermal_ship(row.ship),"Actual exhausted DOS positive-axis limit fixture is valid")
	row.ship.target_speed=600;row.ship.velocity=Vector3(1,0,0)
	var result:=execute(row,0.1,1)
	check(result.ok,"Dry native trial accepts inertial manual coast")
	if not result.ok:return
	check(result.candidate_ship.velocity==Vector3(1,0,0) and result.candidate_ship.position==row.ship.position+Vector3(0.1,0,0),"Empty positive nozzles cannot invent forward or upward powered impulse")
	check(result.stage.fuel_commands==[0,0,0] and result.damage.contact_damage.applied_calls==0,"Genuine no-response commits no HP call and no powered fuel command")
	check(result.candidate_ship.target_speed==600 and result.candidate_surface.generation==1 and not result.candidate_surface.landed,"Nohit advances native history and preserves target controls")
	var live:=row_from(result);var cold_ship:=Ship.new();check(cold_ship.restore(JSON.parse_string(JSON.stringify(live.ship.snapshot()))),"Resulting actual ship uses existing cold save schema")
	cold_ship.surface_mode=true;cold_ship.station_available=false;cold_ship.source_motion_profile=true
	var cold_nav:=Nav.new();check(cold_nav.restore(JSON.parse_string(JSON.stringify(live.nav.snapshot()))) and cold_nav.bind_thermal_ship(cold_ship),"Resulting source HP/RNG/fuel scheduler restores without replay")
	# The new Surface cold factory restores its strict F64 clock anchor after
	# accepting the legacy Navigation JSON value (whose decimal format rounds).
	cold_nav.elapsed_days=live.surface.days
	var cold_gear:=Gear.new();check(cold_gear.restore(JSON.parse_string(JSON.stringify(live.gear.snapshot()))),"Accepted gear fraction survives JSON cold restore")
	var cold_surface:RefCounted=live.surface.fork_runtime(cold_ship)
	var continued:=execute(live,0.1,1);var cold:=execute({"ship":cold_ship,"nav":cold_nav,"gear":cold_gear,"surface":cold_surface},0.1,1)
	check(continued.ok and cold.ok,"Live and cold continuation both accept dry inertial interval")
	if continued.ok and cold.ok:
		check(continued.candidate_nav.snapshot().source_hyperdrive==cold.candidate_nav.snapshot().source_hyperdrive and continued.candidate_nav.elapsed_days==cold.candidate_nav.elapsed_days and continued.candidate_gear.snapshot()==cold.candidate_gear.snapshot() and continued.candidate_ship.snapshot()==cold.candidate_ship.snapshot(),"Cold continuation keeps exact shared fuel/HP/RNG/gear and visible motion")

func fork_isolation_and_parking()->void:
	var row:=fixture();var fork:RefCounted=row.nav.fork_runtime();var original:=state(row)
	fork.visited.append(8);fork.pending_source_quote.injected=true;fork._hyperdrive.fuel_system.heat_s32=200
	check(state(row)==original,"Navigation fork owns private visit/pending/fuel/thermal containers")
	row.surface.accepting=true;row.ship.target_speed=50
	var result:=execute(row)
	check(result.ok and result.candidate_surface.landed and result.candidate_ship.target_speed==0,"Accepted healthy contact can park after exact damage acknowledgement")
	if not result.ok:return
	var parked:=execute(row_from(result))
	check(parked.ok and parked.candidate_surface.landed and parked.damage.contact_damage.applied_calls==0,"Parked idle advances schedulers without replaying a contact-damage event")
	row=fixture();row.surface.calls=[{"amount_s32":-1,"attacker_u32":0}]
	result=execute(row)
	check(result.ok and result.destruction_requested and result.candidate_ship.hull==0,"Fatal source request is committed once in the same atomic owner set")
	if result.ok:check(result.fuel.reason=="source_caller_stopped_after_contact_destruction" and result.candidate_nav.snapshot().source_hyperdrive.fuel_system==row.nav.snapshot().source_hyperdrive.fuel_system,"Existing caller stops subsequent fuel/thermal after terminal contact")

func run()->void:
	failure_atomicity();exact_damage_and_time();dry_thrust_and_nohit();fork_isolation_and_parking()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report:=FileAccess.open(REPORT,FileAccess.WRITE)
	if report:report.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"atomic-owner-transaction-harness-with-real-Flight-Nav-HP-RNG-fuel-gear; natural-kernel-bank-tested-separately"},"\t"))
	print("Native landing trial: %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
