extends SceneTree
const Nav=preload("res://scripts/navigation.gd")
const Session=preload("res://scripts/source_hyperdrive_session.gd")
const Jet=preload("res://scripts/source_jet_fuel.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Motion=preload("res://scripts/source_motion_pipeline.gd")
const ALPHA:=111449880
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func bytes(nav:RefCounted)->String:return JSON.stringify(nav.snapshot())
func source(ship:RefCounted)->RefCounted:
	var nav:=Nav.new();check(nav.configure_source(ship.ship_id) and nav.sync_source_ship(ship),"Supported source ship configures and captures cargo")
	return nav
func dock(nav:RefCounted,ship:RefCounted)->void:
	ship.docked=true;ship.station_available=true;nav.set_source_port_available(true)
func patch_fuel(nav:RefCounted,fields:Dictionary)->bool:
	var data:Dictionary=nav.snapshot();data.source_hyperdrive.fuel_system.merge(fields,true)
	return nav.restore(data)
func fuel(nav:RefCounted)->Dictionary:return nav.snapshot().source_hyperdrive.fuel_system
func context(step:int=1,scoop_step:int=0)->Dictionary:return {"step_s32":step,"commands_s16":[512,0,0],"scoop_step_u32":scoop_step}
func _initialize()->void:call_deferred("run")

func defaults_and_workshop()->void:
	var ship:=Ship.new();var nav:=source(ship);ship.credits=10000;dock(nav,ship)
	var state:Dictionary=nav.fuel_state(ship);var before:=bytes(nav);var goods:=JSON.stringify(ship.goods)
	check(state.jet_raw_u32==0x40000000 and state.jet_tonnes==2 and state.jet_capacity_tonnes==2 and nav.fuel==4,"Cobra jet tank2t and hypercargo4t are distinct")
	check(state.thrust_disabled_axes_mask_u8==0 and not state.refueller_installed and not state.scoop_installed and not state.atmospheric_shielding_installed,"Cobra starts with source flags, not invented fuel equipment")
	check(nav.service_state(ship).occupied_t==37 and nav.service_state(ship).fuel_equipment.size()==3,"Jet liquid is not added to internal cargo, three equipment quotes exist")
	check(not nav.manual_jet_refuel(ship) and bytes(nav)==before,"Full tank manual F289 consumes no cargo")
	check(bytes(nav)==before and JSON.stringify(ship.goods)==goods,"Fuel/workshop quotes are readonly")
	check(nav.service("install_fuel_equipment","refueller",1,ship) and ship.credits==9900,"Source refueller mass1 uses explicit installation adapter100")
	check(nav.service("install_fuel_equipment","scoop",1,ship) and ship.credits==9300,"Cobra mounting accepts source scoop mass6")
	check(nav.service("install_fuel_equipment","atmospheric_shielding",1,ship) and ship.credits==9200,"Atmospheric shielding occupies1t and costsadapter100")
	check(nav.service_state(ship).occupied_t==45 and nav.service_state(ship).free_t==35,"All three hardware masses count exactly once")
	check(not nav.service("install_fuel_equipment","scoop",1,ship),"Single-install source equipment cannot duplicate")
	ship.docked=false;check(not nav.service("remove_fuel_equipment","scoop",1,ship),"Workshop hardware cannot be removed in flight")
	check(nav.set_refueller_enabled(false,ship) and not nav.fuel_state(ship).refueller_enabled,"Explicit flight toggle switches off fitted feeder")
	check(nav.set_refueller_enabled(true,ship),"Explicit flight toggle may re-enable fitted feeder")
	var eagle:=Ship.new();eagle.ship_id="eagle";eagle.credits=10000;var en:=source(eagle);dock(en,eagle)
	check(en.fuel_state(eagle).atmospheric_shielding_installed and en.fuel_state(eagle).starter_shielding_credit_t==1 and en.service_state(eagle).occupied_t==19,"Eagle borrowed fixed6 already includes atmospheric protection1t")
	check(not en.service("install_fuel_equipment","scoop",1,eagle),"Eagle source spec lacks scoop mounting")
	check(en.service("remove_fuel_equipment","atmospheric_shielding",1,eagle) and en.service_state(eagle).occupied_t==18,"Removing baseline shielding frees exactly one tonne")
	check(en.service("install_fuel_equipment","atmospheric_shielding",1,eagle) and en.service_state(eagle).occupied_t==19,"Reinstalling baseline shielding never double counts fixed6")
	var shuttle:=Session.new();check(shuttle.configure("shuttle") and shuttle.fuel_state().jet_raw_u32==0,"Bare Shuttle has explicit zero jet starter, no invented F998 profile")
	var fullship:=Ship.new();var full:=source(fullship);fullship.credits=10000;dock(full,fullship)
	check(full.service("refuel","hydrogen",43,fullship),"Source full-cargo hardware fixture fills")
	before=bytes(full);var credits:int=fullship.credits
	check(not full.service("install_fuel_equipment","refueller",1,fullship) and bytes(full)==before and fullship.credits==credits,"Capacity failure is atomic for hardware and credits")
	var remove_ship:=Ship.new();var removed:=source(remove_ship);remove_ship.credits=10000;dock(removed,remove_ship)
	check(removed.service("remove_drive","",1,remove_ship) and fuel(removed).jet_raw_u32==0 and fuel(removed).disabled_axes_mask_u8==0,"Source F410 drive removal empties tank without inventing immediate limit changes")
	check(removed.message.contains("бак опустошён") and removed.service("install_drive","3",1,remove_ship) and fuel(removed).jet_raw_u32==0,"Source F408 installation grants no new jet fuel and removal feedback explains loss")

func depletion_manual_and_feeder()->void:
	var ship:=Ship.new();var nav:=source(ship)
	check(patch_fuel(nav,{"jet_raw_u32":100}),"Set exact raw equality boundary fixture")
	var result:Dictionary=nav.fuel_step(context(),ship)
	check(result.ok and result.consumption.amount_u32==100 and fuel(nav).jet_raw_u32==0 and fuel(nav).disabled_axes_mask_u8==0x15,"DOS equality depletes and clears only positive limits")
	check(nav.fuel==4 and ship.goods.medicines==2 and result.jet_events==[0x9907],"Unfed empty event leaves all cargo untouched and warns once")
	check(ship.source_thrust_limits_u16[0]==0 and ship.source_thrust_limits_u16[2]==0 and ship.source_thrust_limits_u16[4]==0 and ship.source_thrust_limits_u16[1]!=0 and ship.propulsion_available and not ship.forward_propulsion_available(),"Derived Flight preserves source reverse/right/down capability")
	result=nav.fuel_step(context(),ship)
	check(result.ok and result.jet_events.is_empty(),"Empty warning flag suppresses repeated notifications")
	check(nav.manual_jet_refuel(ship) and nav.fuel==3 and fuel(nav).jet_raw_u32==Jet.RAW_PER_TONNE and fuel(nav).disabled_axes_mask_u8==0 and fuel(nav).status_u16&1==0,"F289 manual refill consumesH1 and restores all six limits")
	check(ship.forward_propulsion_available() and ship.source_thrust_limits_u16[4]!=0,"Manual refill restores derived forward control immediately")
	dock(nav,ship);ship.credits=10000
	check(nav.service("install_fuel_equipment","refueller",1,ship),"Feeder fixture installs source equipment")
	check(patch_fuel(nav,{"jet_raw_u32":0,"disabled_axes_mask_u8":0x15,"status_u16":1}),"Preserve prior disabled source caps")
	result=nav.fuel_step(context(),ship)
	check(result.ok and nav.fuel==2 and fuel(nav).jet_raw_u32==Jet.RAW_PER_TONNE and fuel(nav).disabled_axes_mask_u8==0x15,"DOS auto refill consumes oneH but does not repair previously zeroed limits")
	check(nav.fuel_step(context(),ship).ok and fuel(nav).disabled_axes_mask_u8==0x15,"Ordinary positive debit has no JJFFE cached-limit restoration")
	check(nav.manual_jet_refuel(ship) and nav.fuel==1 and fuel(nav).disabled_axes_mask_u8==0,"Only explicit F289 restores caps after source depletion")
	dock(nav,ship)
	check(nav.service("install_drive","11",1,ship) and nav.service("refuel","military",3,ship),"Military jet feeder fixture is fitted separately from H2")
	check(patch_fuel(nav,{"jet_raw_u32":0}),"Military raw tank empty fixture")
	var cargo_before:Dictionary=nav.snapshot().source_hyperdrive
	result=nav.fuel_step(context(),ship);var after:Dictionary=nav.snapshot().source_hyperdrive
	check(result.ok and after.military==2 and after.radioactives==1 and after.hydrogen==cargo_before.hydrogen and nav.fuel==2,"Military feeder converts one military tonne to one waste, retaining H2")
	check(after.military+after.radioactives==3 and ship.goods.medicines==2,"Military feeder preserves carried quantity and prototype cargo")
	check(nav.set_refueller_enabled(false,ship) and patch_fuel(nav,{"jet_raw_u32":0}),"Turn off military feeder explicitly")
	result=nav.fuel_step(context(),ship)
	check(result.ok and nav.fuel==2 and fuel(nav).jet_raw_u32==0,"Disabled feeder never silently burns reserve cargo")

func clock_cadence_and_atomicity()->void:
	var ship:=Ship.new();var nav:=source(ship);var start:int=fuel(nav).jet_raw_u32
	var raw:={"commands_s16":[512,0,0]}
	check(nav.advance_fuel_ticks(49709,raw,ship).ok and fuel(nav).jet_raw_u32==start and fuel(nav).jet_update_remainder_raw==49709,"Jet F938 waits for actual F152 whole49710 cadence")
	var saved:Dictionary=copy(nav.snapshot());var resumed:=Nav.new();check(resumed.restore(saved) and resumed.validate_source_ship(ship),"Jet scheduler remainder survives JSON restore")
	check(resumed.advance_fuel_ticks(1,raw,ship).ok and fuel(resumed).jet_raw_u32==start-100 and fuel(resumed).jet_update_remainder_raw==0,"One remaining rawtick yields exactly one displaysecond debit")
	var waiting_ship:=Ship.new();var waiting:=source(waiting_ship);waiting_ship.credits=1000;dock(waiting,waiting_ship)
	check(waiting.service("install_fuel_equipment","refueller",1,waiting_ship) and patch_fuel(waiting,{"jet_raw_u32":0,"disabled_axes_mask_u8":0x15}),"Empty automatic-feeder cadence fixture is valid")
	check(waiting.advance_fuel_ticks(49709,{"commands_s16":[0,0,0]},waiting_ship).ok and waiting.fuel==4 and fuel(waiting).jet_raw_u32==0,"Subsecond F152 wait does not accidentally execute F929 empty+zero refill")
	check(waiting.advance_fuel_ticks(1,{"commands_s16":[0,0,0]},waiting_ship).ok and waiting.fuel==3 and fuel(waiting).jet_raw_u32==Jet.RAW_PER_TONNE,"F929 zero-command refill executes only on actual whole-second event")
	var protected:=bytes(resumed)
	for invalid in [{"step_s32":-1,"commands_s16":[0,0,0]},{"step_s32":1,"commands_s16":[40000,0,0]},{"step_s32":1,"commands_s16":[0,0]},{"step_s32":1,"commands_s16":[0,0,0],"contact":{},"scoop_step_u32":2}]:
		check(not resumed.fuel_step(invalid,ship).ok and bytes(resumed)==protected,"Invalid live source context rejects without partial debit")
	for amount in [NAN,INF,-1.0]:check(not resumed.advance_fuel_seconds(amount,raw,ship).ok and bytes(resumed)==protected,"Invalid elapsed interval rejects atomically")
	check(resumed.advance_fuel_seconds(0,raw,ship).ok and bytes(resumed)==protected,"Zero host seconds preserve all state")
	var split:=source(Ship.new());var splitship:=Ship.new();var one:=source(Ship.new());var oneship:=Ship.new()
	check(split.advance_fuel_seconds(0.123456789,raw,splitship).ok,"Fractional host advance retains exact remainder")
	var mid:Dictionary=copy(split.snapshot());var cold:=Nav.new();check(cold.restore(mid),"Fractional IEEE64 and displaysecond accumulators both restore")
	check(split.advance_fuel_seconds(1.987654321,raw,splitship).ok and cold.advance_fuel_seconds(1.987654321,raw,splitship).ok and JSON.stringify(split.snapshot().source_hyperdrive)==JSON.stringify(cold.snapshot().source_hyperdrive),"Fuel inventory and fractional state continuation are bit-exact after JSON save")
	check(one.advance_fuel_seconds(2.111111110,raw,oneship).ok and fuel(one).jet_raw_u32==fuel(split).jet_raw_u32 and fuel(one).jet_update_remainder_raw==fuel(split).jet_update_remainder_raw,"Equivalent split intervals yield same whole-cadence fuel and remainder")
	var snapshot:Dictionary=resumed.snapshot()
	for key in ["jet_raw_u32","cooldown_u32","jet_update_remainder_raw","heat_s32","disabled_axes_mask_u8"]:
		for value in [-4294967296,4294967296,1.5]:
			var bad:Dictionary=copy(snapshot);bad.source_hyperdrive.fuel_system[key]=value
			check(not resumed.restore(bad) and bytes(resumed)==protected,"Strict fuel extension domain rejects "+key)
	var bad:Dictionary=copy(snapshot);bad.source_hyperdrive.fuel_system.source_digest="bad"
	check(not resumed.restore(bad),"Fuel resource digest cannot be replaced")
	bad=copy(snapshot);bad.source_hyperdrive.fuel_system.ticks_fraction_f64_hex="000000000000f03f"
	check(not resumed.restore(bad),"Saved host fraction must be strictly below one")

func old_v3_and_pending()->void:
	var ship:=Ship.new();var nav:=source(ship);nav.select(ALPHA);check(nav.begin_jump(ship),"Source route locks for historical pending compatibility")
	var old:Dictionary=copy(nav.snapshot());old.source_hyperdrive.erase("fuel_system")
	old.pending_source_quote.erase("fuel_hardware_before_sha256");old.pending_source_quote.schema="source-hyperdrive-pending-v1"
	# Actual0.15 contract serialized normalized integer fields in this order.
	var legacy:=Session.new();check(legacy.restore(old.source_hyperdrive),"Exact old12-field source session is accepted explicitly")
	old.pending_source_quote.session_before_sha256=JSON.stringify(legacy.hyperdrive_snapshot()).sha256_text()
	var restored:=Nav.new();check(restored.restore(old) and restored.fuel_extension_upgraded,"Oldv3 pending validates original hash before deterministic extension")
	check(restored.fuel_state(ship).upgrade_notice.length()>0 and restored.pending_source_quote.schema=="source-hyperdrive-pending-v2","Upgrade is reported and normalized pending lock is versioned")
	check(restored.fuel==4 and restored.snapshot().source_hyperdrive.adapted_cargo_t==2 and fuel(restored).jet_raw_u32==0x40000000,"Old cargo/hyperfuel remain unchanged while jet starter is explicit")
	var saved:Dictionary=copy(restored.snapshot());var again:=Nav.new();check(again.restore(saved) and not again.fuel_extension_upgraded,"Resaved extension is not initialized repeatedly")
	var changed_gear:Dictionary=copy(saved);changed_gear.source_hyperdrive.fuel_system.atmospheric_shielding_installed=true
	check(not again.restore(changed_gear),"Pendingv2 hardware lock rejects altered capacity equipment")
	check(again.step(3,ship) and again.fuel==2 and fuel(again).jet_raw_u32==0x40000000,"Old pending arrives with one original H2 debit and no invented jet debit")
	var invalid:Dictionary=copy(old);invalid.pending_source_quote.session_before_sha256="bad"
	check(not again.restore(invalid),"Old pending hash must actually match before upgrade")
	var raw:Dictionary=again.snapshot();raw.source_hyperdrive.fuel_system.jet_raw_u32=0xffffffff
	check(again.restore(raw) and again.fuel_state(ship).jet_above_nominal and again.fuel_state(ship).jet_percent>100,"Above nominal raw tank is preserved without clamping a valid source value")

func scoop_and_thermal()->void:
	var ship:=Ship.new();var nav:=source(ship);ship.credits=10000;dock(nav,ship)
	check(nav.service("install_fuel_equipment","scoop",1,ship),"Scoop fixture uses allowed Cobra mounting")
	ship.docked=false
	var raw:={"step_s32":0,"commands_s16":[0,0,0],"scoop_step_u32":50000,"speed_s32":9000,"contact":{"flags_u8":1,"altitude_raw_s32":30000000,"parent_model_u32":137}}
	var before:int=nav.fuel;var tank:int=fuel(nav).jet_raw_u32
	var result:Dictionary=nav.fuel_step(raw,ship)
	check(result.ok and result.scooped_tonnes==1 and nav.fuel==before+1 and fuel(nav).jet_raw_u32==tank,"F1033 adds cargo H2, never fills separate jet tank")
	check(fuel(nav).cooldown_u32==149130 and fuel(nav).heat_s32==(50000>>10),"Original reset and stellar heat are preserved")
	var cooling_before:int=fuel(nav).heat_s32;result=nav.fuel_step(raw,ship)
	check(result.ok and result.scooped_tonnes==0 and fuel(nav).cooldown_u32==99130 and fuel(nav).heat_s32==cooling_before,"Explicit countdown advances while source cooldown skips heat and capture")
	check(patch_fuel(nav,{"heat_s32":1000,"cooldown_u32":100000}),"Set thermal cadence fixture")
	var cooling:={"step_s32":1,"commands_s16":[0,0,0],"scoop_step_u32":0}
	check(nav.fuel_step(cooling,ship).ok and fuel(nav).heat_s32==872,"Source F1007 cooling subtracts128 per whole update without shielding")
	dock(nav,ship);check(nav.service("install_fuel_equipment","atmospheric_shielding",1,ship),"Fit thermal protection explicitly")
	check(nav.fuel_step(cooling,ship).ok and fuel(nav).heat_s32==360,"Source F1007 cooling subtracts512 with installed shielding")
	check(nav.select(ALPHA) and nav.begin_jump(ship)==false,"Docked source charge remains guarded")
	ship.docked=false;check(nav.begin_jump(ship),"Begin source pending for independent thermal-state progression")
	var charged:Dictionary=nav.pending_source_quote.duplicate(true);result=nav.fuel_step(cooling,ship)
	check(result.ok and not result.hyperjump_cancelled and nav.pending_source_quote==charged,"Heat-only changes do not invalidate F903 pending inventory")
	check(patch_fuel(nav,{"cooldown_u32":0}),"Restore legitimate thermal change during source charge")
	result=nav.fuel_step(raw,ship)
	check(result.ok and result.scooped_tonnes==1 and result.hyperjump_cancelled and nav.remaining==0,"New source cargo cancels pending quote before atomically keeping scooped H2")

func run()->void:
	defaults_and_workshop();depletion_manual_and_feeder();clock_cadence_and_atomicity();old_v3_and_pending();scoop_and_thermal()
	print("SOURCE FUEL SESSION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
