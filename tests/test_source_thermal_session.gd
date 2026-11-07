extends SceneTree
const Nav=preload("res://scripts/navigation.gd")
const Session=preload("res://scripts/source_hyperdrive_session.gd")
const Core=preload("res://scripts/source_atmospheric_dynamics.gd")
const Contact=preload("res://scripts/source_atmosphere_contact.gd")
const Ship=preload("res://scripts/flight_model.gd")
const ALPHA:=111449880
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func encoded(nav:RefCounted)->String:return JSON.stringify(nav.snapshot())
func manifest(nav:RefCounted)->Dictionary:return nav.snapshot().source_hyperdrive
func source(ship:RefCounted,bind:=true)->RefCounted:
	var nav:=Nav.new();check(nav.configure_source(ship.ship_id) and nav.sync_source_ship(ship),"Source hull and cargo fixture configures")
	if bind:check(nav.bind_thermal_ship(ship),"Explicit thermal binding uses actual ship HP")
	return nav
func raw_context(velocity:Array=[8192,0,0],altitude:=100,active:=true)->Dictionary:
	var speed:=Contact.raw_speed_words(velocity)
	return {"apply_f1014":active,"altitude_s32":altitude,"speed_s32":int(speed.get("speed_s32",0)),"velocity_s32":velocity.duplicate(),"gear_down":false,"wind_enabled":false,"wind_armed":false,"parent_shield_s16":0,"wind_flags_u8":0,"step_ticks_u32":828}
func combined(thermal:Dictionary)->Dictionary:
	return {"commands_s16":[512,0,0],"speed_s32":int(thermal.speed_s32),"contact":{"flags_u8":1,"altitude_raw_s32":int(thermal.altitude_s32),"parent_model_u32":120},"thermal":thermal.duplicate(true)}
func _initialize()->void:call_deferred("run")

func binding_and_projection()->void:
	var ship:=Ship.new();ship.hull=37.625;var nav:=source(ship,false)
	var old:Dictionary=copy(nav.snapshot());var old_fuel:=JSON.stringify(manifest(nav).fuel_system)
	check(not manifest(nav).has("thermal_system") and not nav.thermal_state(ship).initialized,"Old0.16 source remains unbound, never assumed100HP")
	var loaded:=Nav.new();check(loaded.restore(old) and loaded.thermal_extension_upgraded,"Old13-key source snapshot explicitly marks thermal initialization")
	check(loaded.bind_thermal_ship(ship) and ship.hull==37.625 and JSON.stringify(manifest(loaded).fuel_system)==old_fuel,"Binding preserves exact old HP and all17fuel fields bytewise")
	var thermal:Dictionary=manifest(loaded).thermal_system
	check(thermal.full_hull_u16==400 and thermal.hull_anchor_raw_u16==151 and thermal.hull_u16==151 and thermal.shield_u16==0,"Ceil source hull anchor preserves partial legacy HP without rounding visible percentage")
	check(loaded.thermal_state(ship).upgrade_notice.length()>0 and not loaded.thermal_state(ship).shield_available,"Upgrade is visible and ATM protection is not a defensive shield")
	var context:=raw_context();var caller:=JSON.stringify(context);var before_rng:=[thermal.rng_seed_a_u32,thermal.rng_seed_b_u32]
	var result:Dictionary=loaded.thermal_step(context,ship)
	check(result.ok and ship.hull==37.125 and manifest(loaded).thermal_system.hull_u16==149,"Exact F953 rawdamage2 projects only0.5percent from37.625anchor")
	check(manifest(loaded).thermal_system.rng_seed_a_u32!=before_rng[0] or manifest(loaded).thermal_system.rng_seed_b_u32!=before_rng[1],"Small hull damage advances only the persisted local F1530 stream")
	check(JSON.stringify(context)==caller and result.thermal.velocity_changed,"Caller context is untouched and source drag is returned separately")
	check(loaded.thermal_state(ship).atmosphere_active and loaded.thermal_state(ship).thermal_severity=="danger","Human status follows actual source hull damage")
	var before:=encoded(loaded);var hull_before:float=ship.hull
	ship.hull-=1.23456789
	check(not loaded.bind_thermal_ship(ship) and encoded(loaded)==before,"Restore binding cannot heal a real HP mismatch")
	check(not loaded.thermal_step(context,ship).ok and encoded(loaded)==before,"Unacknowledged external damage rejects before any thermal changes")
	check(loaded.sync_thermal_ship(ship) and ship.hull==hull_before-1.23456789,"Explicit live collision sync reanchors actual HP without mutation")
	var sync_snapshot:Dictionary=manifest(loaded).thermal_system
	check(int(sync_snapshot.hull_u16)==ceili(ship.hull*4.0),"Live reanchor uses source ceil and exact percent anchor")
	var eagle:=Ship.new();eagle.ship_id="eagle";eagle.hull=99.9;var en:=source(eagle)
	eagle.docked=true;eagle.station_available=true;en.set_source_port_available(true)
	check(en.service("remove_fuel_equipment","atmospheric_shielding",1,eagle),"Unshielded Eagle precision fixture removes actual baseline atmospheric equipment")
	eagle.docked=false
	check(en.thermal_step(raw_context([8192,0,0]),eagle).ok and eagle.hull<99.9 and eagle.hull!=roundf(eagle.hull*10)/10,"Eagle source damage creates a nondecimal percentage projection")
	var exact:float=eagle.hull;var stored:Dictionary=copy(en.snapshot());var rounded_ship:=Ship.new()
	check(rounded_ship.restore(copy(eagle.snapshot())),"Legacy Flight JSON decimal restores for precision bridge")
	var cold:=Nav.new();check(cold.restore(stored) and cold.bind_thermal_ship(rounded_ship) and rounded_ship.hull==exact,"Existing thermal F64anchor restores exact preserialization HP after JSON decimal tolerance check")
	var bad_hull:float=rounded_ship.hull;rounded_ship.hull+=0.000001
	check(not cold.bind_thermal_ship(rounded_ship) and rounded_ship.hull==bad_hull+0.000001,"HP coherence tolerance does not accept a meaningful forged heal")

func damage_callbacks_and_atomicity()->void:
	var ship:=Ship.new();var nav:=source(ship);var data:Dictionary=nav.snapshot()
	data.source_hyperdrive.thermal_system.shield_max_u16=10;data.source_hyperdrive.thermal_system.shield_u16=10
	check(nav.restore(data) and nav.bind_thermal_ship(ship),"Explicit raw shield fixture restores; no market/generator fitting claim")
	var result:Dictionary=nav.thermal_step(raw_context(),ship)
	check(result.ok and manifest(nav).thermal_system.shield_u16==8 and ship.hull==100,"F953 shield absorption preserves actual hull percentage")
	check(not result.thermal.destruction_requested and nav.thermal_state(ship).shield_percent==80,"Source shield readout is independent from atmospheric protection")
	var protected:=encoded(nav);var hp:float=ship.hull
	for invalid in [{"step_ticks_u32":1},{"step_ticks_u32":-1,"velocity_s32":[0,0,0],"altitude_s32":1,"speed_s32":0},raw_context([0,0,0])]:
		var context:Dictionary=invalid.duplicate(true)
		if context.has("apply_f1014"):context.gear_down=1
		check(not nav.thermal_step(context,ship).ok and encoded(nav)==protected and ship.hull==hp,"Malformed thermal context is fully atomic")
	check(not nav.advance_fuel_seconds(10,combined(raw_context()),ship).ok and encoded(nav)==protected,"Excess fixed-step budget rejects before fuel/heat/HP/RNG changes")
	for key in ["hull_u16","hull_anchor_raw_u16","full_hull_u16","frame_tick_remainder_raw","rng_seed_a_u32","wind_flags_u8"]:
		var bad:Dictionary=copy(nav.snapshot());bad.source_hyperdrive.thermal_system[key]=-1
		check(not nav.restore(bad) and encoded(nav)==protected,"Strict thermal raw domain rejects "+key)
	var bad:Dictionary=copy(nav.snapshot());bad.source_hyperdrive.thermal_system.hull_anchor_percent_f64_hex="000000000000f87f"
	check(not nav.restore(bad),"Nonfinite authoritative HP anchor rejects")
	bad=copy(nav.snapshot());bad.source_hyperdrive.thermal_system={}
	check(not nav.restore(bad) and encoded(nav)==protected,"Present empty thermal state cannot silently discard phase/RNG/history as an old-save upgrade")
	bad=copy(nav.snapshot());bad.source_hyperdrive.thermal_system.phase_f64_hex="000000000000f03f"
	check(not nav.restore(bad),"Fixed-frame fraction must stay below one")
	bad=copy(nav.snapshot());bad.source_hyperdrive.thermal_system.source_digest="wrong"
	check(not nav.restore(bad),"Thermal source metadata digest is pinned")
	var dying_ship:=Ship.new();var dying:=source(dying_ship);dying.select(ALPHA)
	check(dying.begin_jump(dying_ship),"Pending source route exists before atmospheric fatality")
	var fatal:Dictionary=dying.snapshot();fatal.source_hyperdrive.fuel_system.heat_s32=65530
	check(dying.restore(fatal) and dying.bind_thermal_ship(dying_ship),"Saved hot pending route is coherent before fatal frame")
	var old_raw:int=manifest(dying).thermal_system.hull_u16;result=dying.thermal_step(raw_context(),dying_ship)
	check(result.ok and result.destruction_requested and result.thermal_destruction_requested and not result.fuel_destruction_requested and dying_ship.hull==0,"F953 fatal callback projects HP0 and preserves separate source cause")
	check(manifest(dying).thermal_system.destroyed and manifest(dying).thermal_system.hull_u16==old_raw and manifest(dying).fuel_system.heat_s32==65530,"Fatal callback does not forge native hull or store fatal candidate heat")
	check(dying.remaining==0 and dying.pending_id==-1 and dying.fuel==4,"Fatality cancels pending hyperjump atomically without hyperfuel debit")
	var dead:=Nav.new();check(dead.restore(copy(dying.snapshot())) and dead.bind_thermal_ship(dying_ship) and dying_ship.hull==0,"Destroyed state cold-restores without reviving stale positive raw hull word")

func simulate(rate:int,seconds:float=1.0)->Dictionary:
	var ship:=Ship.new();var nav:=source(ship);var velocity:Array=[8192,0,0];var calls:=0
	for index in range(roundi(rate*seconds)):
		var result:Dictionary=nav.advance_fuel_seconds(1.0/rate,combined(raw_context(velocity)),ship)
		if not result.get("ok",false):check(false,"Combined fixed simulation must accept bounded frame");return {}
		velocity=result.thermal.velocity_after_s32.duplicate();calls+=int(result.thermal.executed_steps)
	return {"nav":nav,"ship":ship,"velocity":velocity,"steps":calls}
func fixed_cadence_and_cold()->void:
	var results:Array=[]
	for fps in [30,60,120]:results.append(simulate(fps))
	var reference:Dictionary=results[1];var expected:=JSON.stringify(manifest(reference.nav))
	for result:Dictionary in results:
		check(result.steps==60 and JSON.stringify(manifest(result.nav))==expected and result.velocity==reference.velocity and result.ship.hull==reference.ship.hull,"30/60/120 frame batching preserves all fuel/RNG/HP/cadence fields and source velocity")
	check(manifest(reference.nav).fuel_system.jet_raw_u32==0x40000000-100,"Combined 60Hz keeps F938 whole49710 fuel cadence")
	var ship:=Ship.new();var nav:=source(ship);var result:Dictionary=nav.advance_fuel_seconds(0.3712345,combined(raw_context()),ship)
	check(result.ok and result.thermal.executed_steps==22,"Partial combined frame interval retains explicit phase")
	var velocity:Array=result.thermal.velocity_after_s32.duplicate();var stored:Dictionary=copy(nav.snapshot());var ship_save:Dictionary=copy(ship.snapshot())
	var loaded:=Nav.new();var loaded_ship:=Ship.new();check(loaded_ship.restore(ship_save) and loaded.restore(stored) and loaded.bind_thermal_ship(loaded_ship),"Combined fractional/cadence/RNG/partialHP cold restore validates")
	var next:=combined(raw_context(velocity));var uninterrupted:Dictionary=nav.advance_fuel_seconds(0.6512345,next,ship);var cold:Dictionary=loaded.advance_fuel_seconds(0.6512345,next,loaded_ship)
	check(uninterrupted.ok and cold.ok and JSON.stringify(manifest(nav))==JSON.stringify(manifest(loaded)) and uninterrupted.thermal.velocity_after_s32==cold.thermal.velocity_after_s32 and ship.hull==loaded_ship.hull,"Combined cold continuation is bit-exact for both clocks, RNG, all fuel and rawHP")
	var old_ship:=Ship.new();var old:=source(old_ship,false);var old_data:Dictionary=manifest(old).fuel_system
	check(old.bind_thermal_ship(old_ship) and JSON.stringify(manifest(old).fuel_system)==JSON.stringify(old_data),"Enabling new host never rewrites17oldfuel fields")
	var old_clock:={"commands_s16":[512,0,0]};var legacy_control:=Session.new();check(legacy_control.configure("cobra"),"Independent old API source session configures")
	check(old.advance_fuel_seconds(0.123456789,old_clock,old_ship).ok and legacy_control.advance_fuel_seconds(0.123456789,old_clock).ok and JSON.stringify(manifest(old).fuel_system)==JSON.stringify(legacy_control.fuel_system),"Without thermal context the legacy0.16 API keeps exact fuel trajectory")
	var unknown:=raw_context([8192,0,0],-1)
	var clear_ship:=Ship.new();var clear:=source(clear_ship);var before:int=manifest(clear).fuel_system.heat_s32
	check(clear.thermal_step(unknown,clear_ship).ok and manifest(clear).fuel_system.heat_s32==before and not clear.thermal_state(clear_ship).atmosphere_active,"Unknown height−1 follows F1033 HUD normalization, not phantom atmosphere")
func vacuum_context()->Dictionary:
	return {"commands_s16":[0,0,0],"speed_s32":0,"contact":{"flags_u8":0,"altitude_raw_s32":-1,"parent_model_u32":0},"thermal":raw_context([123,-9,7],0x7fffffff,false)}
func vacuum_fastpath_reference()->void:
	for fps in [30,60,120]:
		for rate in [1,100]:
			var fast:=Session.new();check(fast.configure("cobra") and fast.bind_thermal_hull(37.625),"Vacuum reference session binds partial HP")
			fast.fuel_system.ticks_fraction_f64_hex=Session._float_hex(0.73456789);fast.fuel_system.jet_update_remainder_raw=49709
			fast.thermal_system.phase_f64_hex=Session._float_hex(0.375)
			var slow:RefCounted=fast.duplicate_session();var frame:=vacuum_context()
			for _index in range(int(fps/30)):
				var quicker:Dictionary=fast._fixed_thermal_seconds(float(rate)/fps,frame,true,true)
				var reference:Dictionary=slow._fixed_thermal_seconds(float(rate)/fps,frame,true,false)
				check(quicker.ok and reference.ok and JSON.stringify(fast.snapshot())==JSON.stringify(slow.snapshot()),"Vacuum fast/forced-slow full snapshots match at FPS%d/warp%d including phase, all fuel and both remainders"%[fps,rate])
				check(JSON.stringify(quicker)==JSON.stringify(reference),"Vacuum fast/forced-slow source events and projected result match")
	var guards:Array=["heat","cooldown","empty_auto","commands","scoop_atmosphere","f1014","source_destroy_flag"]
	for guard:String in guards:
		var fast:=Session.new();check(fast.configure("cobra") and fast.bind_thermal_hull(100),"Boundary reference source session configures")
		var frame:=vacuum_context()
		match guard:
			"heat":fast.fuel_system.heat_s32=1024
			"cooldown":fast.fuel_system.cooldown_u32=149130
			"empty_auto":
				fast.fuel_system.jet_raw_u32=0;fast.fuel_system.refueller_installed=true;fast.fuel_system.refueller_enabled=true
			"commands":frame.commands_s16=[512,0,0]
			"scoop_atmosphere":frame.contact={"flags_u8":1,"altitude_raw_s32":25000000,"parent_model_u32":140}
			"f1014":frame.thermal=raw_context([8192,0,0])
			"source_destroy_flag":fast.fuel_system.thermal_destruction_requested=true
		var slow:RefCounted=fast.duplicate_session()
		var quicker:Dictionary=fast._fixed_thermal_seconds(1.0,frame,true,true)
		var reference:Dictionary=slow._fixed_thermal_seconds(1.0,frame,true,false)
		check(quicker.ok and reference.ok and JSON.stringify(fast.snapshot())==JSON.stringify(slow.snapshot()) and JSON.stringify(quicker)==JSON.stringify(reference),"Fastpath boundary guard preserves exact slow semantics: "+guard)

func run()->void:
	binding_and_projection();damage_callbacks_and_atomicity();fixed_cadence_and_cold();vacuum_fastpath_reference()
	print("SOURCE THERMAL SESSION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
