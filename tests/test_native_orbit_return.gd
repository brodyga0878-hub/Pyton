extends "res://tests/test_native_orbit_trial.gd"
const ReturnTrial=preload("res://scripts/native_orbit_return.gd")
const RETURN_REPORT:="res://build/current-test-reports/native-orbit-return.json"
var return_evidence:Array=[]

func returned_row(prepared:Dictionary)->Dictionary:
	return {"ship":prepared.candidate_ship,"nav":prepared.candidate_nav,"gear":prepared.candidate_gear,"world":prepared.candidate_world,"surface":prepared.candidate_surface}

func cold_return(row:Dictionary)->Dictionary:
	var ship:=Ship.new();var nav:=Nav.new();var gear:=Gear.new();var world:=World.new();var surface:=NativeSurface.new()
	check(ship.restore(OrbitTrial._json(row.ship.snapshot())) and nav.restore(OrbitTrial._json(row.nav.snapshot())) and gear.restore(OrbitTrial._json(row.gear.snapshot())),"Returned Flight/Nav/Gear cold-decode through their actual production contracts")
	world.configure(nav.current(),World.FULL_LAYOUT)
	check(world.restore(OrbitTrial._json(row.world.snapshot())) and nav.bind_thermal_ship(ship),"Returned World and genuine source HP/fuel owner cold-decode without a time interval")
	var restored:bool=surface.restore(OrbitTrial._json(row.surface.snapshot()),ship,world)
	check(restored,"Airborne return's ordinary native snapshot validates exact source raw anchor, provider and retained leaf witness")
	if not restored:return {}
	nav.elapsed_days=surface._source_days;ship.source_motion_profile=row.ship.source_motion_profile
	return {"ship":ship,"nav":nav,"gear":gear,"world":world,"surface":surface}

func genuine_return(row:Dictionary)->Dictionary:
	var before:=orbit_owners(row)
	var hp:Dictionary=row.nav.thermal_state(row.ship);var fuel:Dictionary=row.nav.fuel_state(row.ship);var day:float=row.nav.elapsed_days;var gear:Dictionary=row.gear.snapshot()
	var prepared:=ReturnTrial.prepare_return(row.orbit,row.ship,row.nav,row.gear,row.world)
	check(prepared.get("ok",false),"Actually flown twenty-kilometre trial returns continuously to its native source chart: "+str(prepared.get("reason","")))
	check(orbit_owners(row)==before,"Return preparation leaves original orbital F64 residual, physical owners and every World cache unchanged")
	if not prepared.get("ok",false):return {}
	var next:=returned_row(prepared);var receipt:Dictionary=prepared.receipt
	check(next.surface.is_native_landing_trial() and not next.surface.landed and next.surface.native_session.phase()=="free" and next.ship.surface_mode,"Returned frame is actual free native flight, not another parked or fifty-metre trial entry")
	check(next.nav.elapsed_days==day and next.nav.thermal_state(next.ship)==hp and next.nav.fuel_state(next.ship)==fuel and next.gear.snapshot()==gear,"Return boundary preserves exact source day, HP/RNG/fuel and mechanical gear without another interval")
	check(next.ship.target_speed==row.ship.target_speed and next.ship.assisted==row.ship.assisted and next.ship.source_motion_profile==row.ship.source_motion_profile,"Frame return preserves current chosen controls and actual thrust capacity")
	check(not receipt.position_snapped and not receipt.clock_advanced and not receipt.hp_applied and not receipt.fuel_advanced and not receipt.omega_cross_radius_added,"Return receipt declares the actual zero-time affine policy without invented impulse or protection snap")
	check(receipt.space_position_f64_hex==NativeSurface._native_floats(Array(row.orbit._position_f64),8) and receipt.space_pose_f32_hex==OrbitTrial._pose(row.ship) and receipt.phone_pose_f32_hex==OrbitTrial._pose(next.ship),"Measured return receipt binds actual exact accumulated space position and output phone pose")
	check(receipt.airborne_rebind.source_generation_after==receipt.airborne_rebind.source_generation_before+1 and not receipt.airborne_rebind.contact_detected and receipt.airborne_rebind.damage_calls.is_empty() and receipt.airborne_rebind.callbacks.is_empty(),"Real source no-contact boundary updates raw anchor exactly once and emits no physical response, HP or callback commands")
	var ideal:Array=NativeSurface._native_numbers(receipt.phone_position_ideal_f64_hex,8)
	var errors:Array=NativeSurface._native_numbers(receipt.phone_position_rounding_error_f64_hex,8)
	for axis in range(3):check(absf(float(next.ship.position[axis])-float(ideal[axis]))==float(errors[axis]),"Return records only final local Float32 rounding on axis "+str(axis))
	var lineage_pose:=NativeSurface._native_decode_pose(str(row.orbit._receipt.source_phone_pose_f32_hex))
	if row.orbit._generation==0:
		check(next.ship.position.distance_to(lineage_pose.position)<0.002 and next.ship.velocity.distance_to(lineage_pose.velocity)<0.00001 and absf(next.ship.attitude.dot(lineage_pose.attitude))>0.999999,"Immediate inverse transfer recovers actually reached outbound pose/velocity/attitude without subtracting rounded world coordinates")
	return_evidence.append({"case":"actual_continuous_airborne_inverse_transfer","space_generation":row.orbit._generation,"receipt":receipt,"original_owners_unchanged":true})
	return next

func source_continuation(warm:Dictionary)->void:
	if warm.is_empty():return
	var restored:=cold_return(warm)
	if restored.is_empty():return
	check(warm.surface.snapshot()==restored.surface.snapshot() and OrbitTrial._pose(warm.ship)==OrbitTrial._pose(restored.ship) and warm.nav.elapsed_days==restored.nav.elapsed_days,"Return cold restore retains exact current native phone/raw pose, provider, time and source history")
	for tick in range(12):
		var before:=owners(warm)
		var a:=Trial.prepare(warm.ship,warm.nav,warm.gear,warm.surface,0.1,Vector2.ZERO,0,-0.2)
		var b:=Trial.prepare(restored.ship,restored.nav,restored.gear,restored.surface,0.1,Vector2.ZERO,0,-0.2)
		check(a.get("ok",false) and b.get("ok",false),"Warm and cold returned frames execute the real next source flight interval "+str(a.get("reason","")))
		check(owners(warm)==before,"Native interval following return prepares without changing its previous source owner set")
		if not a.get("ok",false) or not b.get("ok",false):return
		warm=apply(warm,a);restored=apply(restored,b)
		check(OrbitTrial._pose(warm.ship)==OrbitTrial._pose(restored.ship) and warm.surface.snapshot()==restored.surface.snapshot() and warm.nav.snapshot().source_hyperdrive==restored.nav.snapshot().source_hyperdrive and warm.nav.elapsed_days==restored.nav.elapsed_days and warm.gear.snapshot()==restored.gear.snapshot(),"Cold returned native frame reproduces raw movement, source HP/RNG/fuel, gear and one clock exactly")
	return_evidence.append({"case":"returned_native_cold_warm_continuation","compared_intervals":12,"source_generation":warm.surface.native_session.generation()})

func moved_space_return(row:Dictionary)->void:
	row=cold(row)
	row.ship.target_speed=1;row.ship.assisted=true
	for tick in range(70):
		var prepared:Dictionary=row.orbit.prepare(row.ship,row.nav,row.gear,row.world,1.0/60.0,Vector2(0.2,0.1) if tick<60 else Vector2.ZERO)
		check(prepared.get("ok",false),"Real space steering and fractional motion precede inverse transfer")
		if not prepared.get("ok",false):return
		row=apply_orbit(prepared)
	var next:=genuine_return(row)
	if next.is_empty():return
	check(next.ship.velocity.length()>0.5 and absf(next.ship.velocity.length()-row.ship.velocity.length())<0.00001,"Return rotates actual nonzero manual space velocity rather than resetting it to the outbound source value")
	var chart:Basis=next.surface.globe.basis_at(next.surface.globe.latitude,next.surface.globe.longitude)
	var rotation:=OrbitTrial.Gas._basis_readonly(row.world,row.world.by_id[row.world.focus_id],row.nav.elapsed_days)
	var center:Vector3=row.world.local_meters(row.world.focus_id,row.nav.elapsed_days)
	var rounded_relative:=PackedFloat64Array()
	for axis in range(3):rounded_relative.append(float(row.ship.position[axis])-float(center[axis]))
	var naive:=ReturnTrial.Phone.to_local_vector(chart,ReturnTrial.Phone.to_local_vector(Basis(rotation.basis),rounded_relative));naive[1]-=float(next.surface.globe.radius)
	var correct:Array=NativeSurface._native_numbers(ReturnTrial.prepare_return(row.orbit,row.ship,row.nav,row.gear,row.world).receipt.phone_position_ideal_f64_hex,8)
	var residual:=0.0
	for axis in range(3):residual+=pow(float(correct[axis])-naive[axis],2)
	check(sqrt(residual)>0.01,"Actual return consumes persistent space Float64 residual; using rounded world Vector3 would lose measurable centimetres")
	source_continuation(next)

func return_guards(row:Dictionary)->void:
	var before:=orbit_owners(row)
	var stale:=Trial._fork_ship(row.ship);stale.position.x+=2
	check(not ReturnTrial.prepare_return(row.orbit,stale,row.nav,row.gear,row.world).ok and orbit_owners(row)==before,"A stale external physical orbit pose cannot be accepted as a continuous surface return")
	check(not ReturnTrial.prepare_return(null,row.ship,row.nav,row.gear,row.world).ok and orbit_owners(row)==before,"No return is fabricated outside an actual bound orbital trial")
	var source:=ReturnTrial._outbound_surface(row.orbit,row.nav)
	check(source!=null,"Helper guard fixture restores the exact outbound source surface rather than synthesizing another terrain")
	if source==null:return
	var unsafe:RefCounted=Trial._fork_ship(source._source_render_ship)
	unsafe.position.y=source.height_at(unsafe.position.x,unsafe.position.z)-100.0
	var source_before:Dictionary=source.snapshot()
	var rejected:Dictionary=source.rebind_airborne(unsafe,row.world,row.nav.elapsed_days,0,{"schema":"explicit-unsafe-boundary-fixture"})
	check(not rejected.ok and source.snapshot()==source_before and not source.native_session.is_pending(),"Actual unsafe contact at a zero-time boundary rejects without changing raw anchor, history, leaf, pose or parked state")
	var invalid:Dictionary=source.rebind_airborne(source._source_render_ship,row.world,-1,0,{})
	check(not invalid.ok and source.snapshot()==source_before and orbit_owners(row)==before,"Invalid source day rejects atomically without touching the real orbital owners")
	return_evidence.append({"case":"typed_return_and_unsafe_zero_time_contact_guards","unsafe_reason":str(rejected.get("reason","")),"original_owners_unchanged":true})

func run()->void:
	var row:=actual_ascent_to_handoff()
	if not row.is_empty():
		source_continuation(genuine_return(row));moved_space_return(row);return_guards(row)
	var sources:Dictionary={}
	for path:String in ["scripts/native_orbit_return.gd","scripts/native_orbit_trial.gd","scripts/native_surface_model.gd","scripts/native_landing_trial.gd","tests/test_native_orbit_return.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RETURN_REPORT.get_base_dir()));var file:=FileAccess.open(RETURN_REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":sources,"evidence":return_evidence,"scope":"Actual powered source20km departure; inverse affine return over current F64 space position and current body spin; real zero-time airborne source rebind; unchanged HP/RNG/fuel/gear/day; typed native cold and following real intervals. Bounded observed source leaf/1..30km, no full F570/F606 dispatcher, original autopilot or physical Android claim."},"\t"));file.close()
	print("Native orbit return: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
