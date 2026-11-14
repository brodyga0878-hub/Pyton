extends SceneTree
const Trial=preload("res://scripts/native_landing_trial.gd")
const NativeSurface=preload("res://scripts/native_surface_model.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Nav=preload("res://scripts/navigation.gd")
const Gear=preload("res://scripts/source_landing_gear_session.gd")
const World=preload("res://scripts/planetary_system.gd")
const REPORT:="res://build/current-test-reports/native-landing-trial-integration.json"
var checks:=0
var failures:=0
var evidence:Array=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func fixture(down:bool=true)->Dictionary:
	var ship:=Ship.new();var nav:=Nav.new()
	check(nav.configure_source(ship.ship_id) and nav.sync_source_ship(ship) and nav.bind_thermal_ship(ship),"Actual Sol trial source Navigation, Flight and raw HP bind")
	var world:=World.new();world.configure(nav.current(),World.FULL_LAYOUT);world.focus_id="earth";world.selected_id="earth";world.site_id=""
	var terrain:=Terrain.new();terrain.configure(world,"earth","");terrain.latitude=0;terrain.longitude=0
	var previous:=Surface.new();previous.active=true;previous.body_id="earth";previous.globe=terrain
	ship.surface_mode=true;ship.station_available=false;ship.position=Vector3.ZERO
	var surface:=NativeSurface.new();check(surface.initialize_from(previous,ship,world,0),"A separate native Earth trial starts 50m above its own source root")
	ship.assisted=false
	var gear:=Gear.new();check(gear.configure(down),"Actual persisted gear is configured for flown source landing")
	return {"ship":ship,"nav":nav,"gear":gear,"surface":surface,"world":world}
func owners(row:Dictionary)->PackedByteArray:
	return var_to_bytes([row.ship.snapshot(),row.nav.snapshot(),row.gear.snapshot(),row.surface.snapshot(),row.world.snapshot(),row.world.native_evaluation_count,row.world._native_cache_tick,row.world._native_cache_day])
func apply(row:Dictionary,result:Dictionary)->Dictionary:
	return {"ship":result.candidate_ship,"nav":result.candidate_nav,"gear":result.candidate_gear,"surface":result.candidate_surface,"world":row.world}
func step(row:Dictionary,dt:float=0.1,lift:float=0.0)->Dictionary:return Trial.prepare(row.ship,row.nav,row.gear,row.surface,dt,Vector2.ZERO,0,lift)
func actual_coast_and_rollback()->void:
	var row:=fixture();if not row.surface.active:return
	row.ship.target_speed=17
	var before:=owners(row);var first:=step(row)
	check(first.ok,"Actual manual native interval prepares with original F576/provider/F574/fuel/thermal")
	if not first.ok:push_error(str(first));return
	check(owners(row)==before,"Successful real preparation preserves every original owner and World spin/cache")
	check(not first.stage.contact_detected and first.damage.contact_damage.applied_calls==0,"High native trial interval genuinely classifies nohit and emits no damage")
	check(first.candidate_ship.target_speed==17 and not first.candidate_ship.assisted and not first.candidate_surface.landed,"Genuine native nohit preserves the chosen manual speed and inertial controls")
	var prepared:Dictionary=first.stage.source_prepared
	check(prepared.trace_rows.size()==int(prepared.classification.terrain_query_calls),"The original classifier and provider consume the identical observed query rows")
	check(first.candidate_surface.native_session.generation()==1 and first.candidate_nav.elapsed_days==0.1/86400.0,"A genuine nohit acknowledges history and celestial clock exactly once")
	row.ship.position.x=1e9
	before=owners(row);var rejected:=step(row)
	check(not rejected.ok and owners(row)==before,"An actual out-of-chart source query rolls back all mutable owners and World")
	evidence.append({"case":"actual_nohit_and_out_of_chart_rollback","queries":prepared.trace_rows.size(),"failure_reason":rejected.reason})

func fly_contact(down:bool)->Dictionary:
	var row:=fixture(down);if not row.surface.active:return {}
	var old_world:=var_to_bytes([row.world.snapshot(),row.world.native_evaluation_count,row.world._native_cache_tick,row.world._native_cache_day])
	var start_y:float=row.ship.position.y;var accepted:Dictionary={}
	for tick in range(140):
		var before:=owners(row);var result:=step(row)
		if not result.ok:
			check(false,"Flown native descent interval remains inside its witnessed source leaf: "+str(result.reason));return {}
		check(owners(row)==before,"Real flown interval changes no originals before the host swap")
		row=apply(row,result)
		if result.stage.contact_detected:accepted=result;break
	check(not accepted.is_empty(),"Continuous gravity descent reaches a genuine original contact without a test teleport")
	if accepted.is_empty():return {}
	check(row.ship.position.y<start_y and accepted.stage.source_prepared.contact_detected,"Source contact follows actual motion from the 50m native entry")
	check(var_to_bytes([row.world.snapshot(),row.world.native_evaluation_count,row.world._native_cache_tick,row.world._native_cache_day])==old_world,"Every actual gravity/contact interval keeps the shared celestial World read-only")
	if down:
		check(accepted.stage.landing_accepted and row.surface.landed and row.ship.velocity==Vector3.ZERO,"Aligned deployed-gear descent parks at the exact accepted original response")
		check(accepted.damage.contact_damage.applied_calls==0 and row.ship.hull==100,"Healthy original landing does not charge an invented impact loss")
	else:
		check(not accepted.stage.landing_accepted and not row.surface.landed and accepted.damage.contact_damage.applied_calls==1,"Retracted-gear descent emits exactly one original unsafe damage call")
		check(accepted.damage.contact_damage.raw_hull_before-accepted.damage.contact_damage.raw_hull_after==int(accepted.stage.damage_calls[0].amount_s32),"Unsafe contact debits exactly the original amount in the existing raw HP owner")
	evidence.append({"case":"flown_deployed_contact" if down else "flown_retracted_contact","hull":row.ship.hull,"source_generation":row.surface.native_session.generation(),"queries":accepted.stage.source_prepared.trace_rows.size(),"native_damage_calls":accepted.stage.damage_calls,"response_pose":str(row.ship.position),"render_agl":row.surface.altitude(row.ship)})
	return row

func cold_park_and_takeoff(row:Dictionary)->void:
	if row.is_empty() or not row.surface.landed:return
	var before:=owners(row);var idle:=step(row)
	check(idle.ok and idle.candidate_surface.landed and idle.stage.parked_idle and owners(row)==before,"Accepted parked idle keeps its anchor without reclassifying or damaging original owners")
	if not idle.ok:return
	row=apply(row,idle)
	var ship:=Ship.new();check(ship.restore(JSON.parse_string(JSON.stringify(row.ship.snapshot()))),"Parked actual ship restores old Flight JSON")
	var nav:=Nav.new();check(nav.restore(JSON.parse_string(JSON.stringify(row.nav.snapshot()))) and nav.bind_thermal_ship(ship),"Parked shared raw HP/fuel/RNG restores without old contact replay")
	var gear:=Gear.new();check(gear.restore(JSON.parse_string(JSON.stringify(row.gear.snapshot()))),"Parked actual gear restores exact phase")
	var surface:=NativeSurface.new();check(surface.restore(JSON.parse_string(JSON.stringify(row.surface.snapshot())),ship,row.world),"New strict source Surface restores its accepted raw pose and leaf witness")
	if not surface.active:return
	nav.elapsed_days=surface._source_days
	var cold:={"ship":ship,"nav":nav,"gear":gear,"surface":surface,"world":row.world}
	check(surface.snapshot()==row.surface.snapshot() and ship.snapshot()==row.ship.snapshot() and gear.snapshot()==row.gear.snapshot() and nav.snapshot().source_hyperdrive==row.nav.snapshot().source_hyperdrive and nav.elapsed_days==row.nav.elapsed_days,"Cold restore retains exact trial source anchors, raw HP/fuel/RNG/gear, clock and phone pose")
	var p:Vector3=ship.position;check(surface.take_off(ship) and ship.position==p,"Takeoff request arms propulsion without teleporting above the ground")
	var launch:=step(cold,0.1,1)
	check(launch.ok and not launch.candidate_surface.landed and launch.candidate_ship.velocity.y>0 and launch.candidate_ship.hull==ship.hull,"Powered manual lift releases restored original park and preserves HP")
	if launch.ok:evidence.append({"case":"strict_cold_park_then_powered_takeoff","launch_velocity":str(launch.candidate_ship.velocity),"original_park_pose":str(p),"source_generation":launch.candidate_surface.native_session.generation()})

func actual_dry_park(row:Dictionary)->void:
	if row.is_empty() or not row.surface.landed:return
	var ship:RefCounted=Trial._fork_ship(row.ship);var nav:RefCounted=row.nav.fork_runtime();var surface:RefCounted=row.surface.fork_runtime(ship)
	var gear:=Gear.new();check(gear.restore(row.gear.snapshot()),"Dry-park fixture copies exact accepted gear state")
	var saved:Dictionary=nav.snapshot();saved.source_hyperdrive.fuel_system.jet_raw_u32=0;saved.source_hyperdrive.fuel_system.disabled_axes_mask_u8=0x15;saved.source_hyperdrive.fuel_system.status_u16=1
	check(nav.restore(saved) and nav.bind_thermal_ship(ship) and nav.apply_fuel_availability(ship),"Native accepted park binds real empty positive-nozzle limits")
	var p:Vector3=ship.position;var raw:PackedByteArray=surface.native_session.raw_body();var generation:int=surface.native_session.generation()
	check(not surface.take_off(ship) and ship.position==p and surface.native_session.raw_body()==raw,"Dry takeoff command cannot teleport, release the raw anchor or fabricate upward thrust")
	var dry:={"ship":ship,"nav":nav,"gear":gear,"surface":surface,"world":row.world};var original:=owners(dry);var result:=step(dry,0.1,1)
	check(result.ok and owners(dry)==original,"Dry lift request remains an atomic accepted parked interval")
	if not result.ok:return
	check(result.candidate_surface.landed and result.candidate_ship.position==p and result.candidate_ship.velocity==Vector3.ZERO,"Actual empty native launch retains the exact accepted pose and responds to idle scheduling")
	check(result.candidate_surface.native_session.raw_body()==raw and result.candidate_surface.native_session.generation()==generation and result.damage.contact_damage.applied_calls==0,"Parked dry interval neither reclassifies nor reapplies source damage/history")
	evidence.append({"case":"actual_dry_park_cannot_invent_launch","source_generation":generation,"source_pose_unchanged":true,"fuel_commands":result.stage.fuel_commands})

func run()->void:
	actual_coast_and_rollback();var healthy:=fly_contact(true);fly_contact(false);actual_dry_park(healthy);cold_park_and_takeoff(healthy)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report:=FileAccess.open(REPORT,FileAccess.WRITE)
	if report:report.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"actual bounded manual source-contact trial; original F576 trace/provider/F575 + shared Nav HP/fuel/thermal/Gear; full F569 bank/autopilot/Android not claimed"},"\t"))
	print("Native landing trial integration: %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
