extends SceneTree
# Analytic rigid-frame controls plus real source station meshes and live World.
const Dynamics=preload("res://scripts/rotating_dock_dynamics.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Geometry=preload("res://scripts/source_station_geometry.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const Session=preload("res://scripts/source_station_session.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func near(a:Vector3,b:Vector3,tolerance:=0.0001)->bool:return a.distance_to(b)<tolerance
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func ship_at(model:=80)->RefCounted:
	var ship:=Ship.new()
	check(ship.configure_source_station(Geometry.prepare(model),Basis.IDENTITY),"Real source model configures without inventing a hull")
	ship.position=Ship.STATION;ship.assisted=false;ship.target_speed=0;return ship

func analytic_controls()->void:
	for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK,Vector3(1,2,-3).normalized()]:
		for angle in [-1.2,-0.2,0.0,0.1,0.8]:
			var first:=Basis(Vector3.UP,0.3)*Basis(Vector3.RIGHT,-0.2)
			var last:=Basis(axis,angle)*first
			var motion:=Dynamics.sample(first,last,0.25)
			check(near(motion.angular_velocity_world_rad_s,axis*(angle/0.25),0.00001),"Rigid pose sample yields the analytic world-axis angular velocity")
	check(Dynamics.sample(Basis.IDENTITY,Basis.IDENTITY,0).sample_valid==false,"Zero-duration configuration has no fabricated angular-rate history")
	check(Dynamics.sample(Basis.IDENTITY,Basis.IDENTITY,-1).is_empty() and Dynamics.sample(Basis.IDENTITY,Basis.IDENTITY,NAN).is_empty(),"Invalid step durations reject")
	check(Dynamics.sample(Basis.IDENTITY.scaled(Vector3(2,1,1)),Basis.IDENTITY,1).is_empty(),"Nonrigid pose rejects before angular sampling")
	check(near(Dynamics.surface_velocity(Vector3(0,0,0.4),Vector3(10,0,0),Vector3.ZERO),Vector3(0,4,0)),"Rotating wall velocity uses omega cross radius at the actual point")
	check(near(Dynamics.support_offset(Vector3(2,3,4),Quaternion.IDENTITY,Vector3.UP),Vector3(0,3,0)),"Ellipsoid support agrees with the analytic principal-axis point")
	var rotation:=Quaternion(Vector3.FORWARD,PI*0.5)
	check(near(Dynamics.support_offset(Vector3(2,3,4),rotation,Vector3.RIGHT),Vector3(3,0,0)),"Support follows a rotated ellipsoid instead of retaining a fixed thin Y")
	var info:=Dynamics.telemetry(Basis.IDENTITY,Vector3(0,0,0.4),Vector3(10,0,0),Vector3(0,4,-3),Quaternion.IDENTITY,Vector3.ZERO,Vector3.ZERO,true)
	check(near(info.relative_linear_velocity_mps,Vector3(0,0,-3)),"Contact-frame velocity subtracts rotating-wall translation before orientation transform")
	check(is_equal_approx(info.roll_rate_error_rad_s,-0.4),"Roll-rate instrument follows the station's forward-axis convention")
	info=Dynamics.telemetry(Basis.IDENTITY,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Quaternion(Vector3.FORWARD,0.25),Vector3.ZERO,Vector3.ZERO,false)
	check(absf(info.roll_error_rad+0.25)<0.00001,"Signed roll-error instrument indicates the actual corrective turn")
	check(Dynamics.telemetry(Basis.IDENTITY,Vector3(INF,0,0),Vector3.ZERO,Vector3.ZERO,Quaternion.IDENTITY,Vector3.ZERO,Vector3.ZERO,true).is_empty(),"Invalid angular telemetry cannot poison cockpit instruments")

func manual_and_rate_history()->void:
	var ship:=ship_at();ship.position+=Vector3(0,0,100)
	var geometry:=Geometry.prepare(80)
	var position:Vector3=ship.position;var velocity:Vector3=ship.velocity;var attitude:Quaternion=ship.attitude
	var basis:=Basis(Vector3.FORWARD,0.25)
	check(ship.configure_source_station(geometry,basis,0.5),"A timed source-pose update configures")
	check(ship.position==position and ship.velocity==velocity and ship.attitude==attitude and not ship.autopilot,"Timed source station spin never secretly aligns or moves an undocked manual ship")
	var telemetry:Dictionary=ship.source_docking_telemetry()
	check(telemetry.sample_valid and near(telemetry.station_angular_velocity_world_rad_s,Vector3.FORWARD*0.5),"Live flight instrument receives measured source pose rate")
	var before:=var_to_bytes(telemetry);var saved:=JSON.stringify(ship.snapshot())
	check(not ship.configure_source_station(geometry,basis,NAN) and not ship.configure_source_station(geometry,basis,-1),"Bad sampling durations reject before changing valid context")
	check(var_to_bytes(ship.source_docking_telemetry())==before and JSON.stringify(ship.snapshot())==saved,"Rejected timed updates preserve flight and derived instruments atomically")
	var restored:=ship_at();check(restored.configure_source_station(geometry,basis),"Restore starts from authoritative current source basis")
	check(restored.restore(copy(ship.snapshot())),"Existing sourcev5 save remains loadable")
	telemetry=restored.source_docking_telemetry()
	check(not telemetry.sample_valid and telemetry.station_angular_velocity_world_rad_s==Vector3.ZERO and telemetry.ship_angular_velocity_world_rad_s==Vector3.ZERO,"Cold restore does not manufacture unsaved angular-rate history")
	check(restored.snapshot().version==5 and restored.snapshot().source_station.size()==5,"Derived rigid contact adds no fields or silent migration to Flightv5")
	var other:=Geometry.prepare(80,1)
	check(ship.configure_source_station(other,Basis.IDENTITY,0.1) and not ship.source_docking_telemetry().sample_valid,"Changing source identity resets the prior station's angular sample")
	ship.clear_source_station();check(ship.source_docking_telemetry().is_empty() and ship.snapshot().version==4,"Clearing source context removes all derived rotation and retains legacy schema")
	ship=ship_at();ship.position+=Vector3(5,0,0)
	basis=Basis(Vector3.BACK,0.5);ship.configure_source_station(geometry,basis,0.05);ship.attitude=basis.get_rotation_quaternion()
	ship.velocity=ship.source_docking_telemetry().station_angular_velocity_world_rad_s.cross(ship.position-Ship.STATION)
	check(ship.velocity.length()>Ship.DOCK_SPEED and ship.can_dock(),"Capture speed is measured relative to the moving bay at the ship centre")
	ship.velocity+=basis*Vector3(0,0,-12.01)
	check(not ship.can_dock(),"The existing12m/s relative approach cap remains enforced without inventing an angular-rate threshold")

func manual_rotation_cycle()->void:
	var geometry:=Geometry.prepare(80)
	var ship:=ship_at();var original:Quaternion=ship.attitude
	ship.configure_source_station(geometry,Basis(Vector3.FORWARD,0.6),0.05)
	check(ship.attitude==original and not ship.can_dock(),"Manual docking rejects mismatched roll while leaving pilot orientation untouched")
	ship=ship_at()
	var dt:=0.05;var rate:=0.2
	var command:float=rate*1.2/float(ship.profile().turn_rate)
	for frame in range(1,101):
		var basis:=Basis(Vector3.FORWARD,frame*dt*rate)
		ship.configure_source_station(geometry,basis,dt);ship.step(dt,Vector2.ZERO,command)
	check(not ship.autopilot and not ship.docked and ship.hull==100,"A real manual roll command tracks the rotating source bay without an automatic synchronizer")
	check(ship.can_dock() and absf(float(ship.source_docking_telemetry().roll_error_rad))<0.001,"Matching manual roll yields a legitimate interior dock pose")
	check(absf(float(ship.source_docking_telemetry().roll_rate_error_rad_s))<0.001,"Measured ship and station roll rates agree after real manual steps")
	check(ship.dock(),"Explicit capture completes the manually aligned cycle")
	var closed:=Geometry.prepare(80,0,65535)
	ship.configure_source_station(closed,Basis(Vector3.FORWARD,1.1),dt)
	ship.launch();check(ship.docked and ship.position==Ship.STATION,"A closed source door remains a physical launch guard after rotating capture")
	ship.configure_source_station(geometry,Basis(Vector3.FORWARD,1.12),dt);ship.launch()
	check(not ship.docked and ship.velocity.length()>0 and not ship.autopilot,"Opening the rotating port restores a physical manual launch")

func swept_rotating_collision()->void:
	var geometry:=Geometry.prepare(80)
	var ship:=ship_at();ship.position+=Vector3(10,0,0)
	var start:Vector3=ship.position;var original:Quaternion=ship.attitude
	check(ship._source_shape_sweep(Vector3(10,0,0),Vector3(10,0,0),original).is_empty(),"Actual source bay has a clear starting hull pose")
	ship.configure_source_station(geometry,Basis(Vector3.BACK,PI),1)
	check(ship._source_shape_sweep(Vector3(-10,0,0),Vector3(-10,0,0),original).is_empty(),"The same stationary ship also has a clear final half-turn pose")
	ship.step(1,Vector2.ZERO)
	var collision:Dictionary=ship.source_docking_telemetry().last_collision
	check(not collision.is_empty() and collision.time>0 and collision.time<1,"Rotating sweep detects the real intermediate source wall crossing despite two clear endpoints")
	check(collision.segments>1 and collision.segments<=Dynamics.MAX_SEGMENTS and collision.ellipsoid_scale>=1,"Rotating sweep has a bounded and explicitly conservative footprint")
	check(ship.hull<100 and ship.hull>0 and ship.velocity.length()>0,"A moving source wall can impart a contact impulse and damage a stationary ship")
	check(collision.relative_normal_speed_mps>0 and collision.station_surface_velocity_mps.length()>0,"Collision response evaluates relative speed at the hull support point, including omega cross radius")
	check(ship.attitude==original and ship.position.distance_to(start)<100,"Wall contact does not rotate the pilot or teleport outside the kilometre-scale station")
	check(ship._source_shape_sweep(ship._source_local(ship.position),ship._source_local(ship.position),ship.attitude).is_empty(),"Final contact resolution leaves the actual hull outside current source solids")
	ship=ship_at();ship.configure_source_station(geometry,Basis(Vector3.BACK,PI),1);ship.step(1,Vector2.ZERO)
	check(ship.hull==100 and ship.position==Ship.STATION and ship.source_docking_telemetry().last_collision.is_empty(),"A genuinely clear centred real hull is not mistaken for the off-axis crossing control")
	# No-motion path must remain bit-identical, not merely numerically similar.
	var untimed:=ship_at();var timed:=ship_at()
	for control in [untimed,timed]:control.position=Ship.STATION+Vector3(100,0,700);control.velocity=Vector3(0,0,-1000)
	timed.configure_source_station(geometry,Basis.IDENTITY,0.1)
	untimed.step(0.1,Vector2.ZERO);timed.step(0.1,Vector2.ZERO)
	check(var_to_bytes(untimed.snapshot())==var_to_bytes(timed.snapshot()),"Unchanged source poses retain exactly the prior static CCD/dynamics path")

func supported_hulls_and_stations()->void:
	var tilt:=Basis(Vector3.UP,0.4)*Basis(Vector3.RIGHT,-0.3)
	for model in Geometry.MODELS:
		var geometry:=Geometry.prepare(int(model))
		for id in ["cobra","eagle","shuttle"]:
			var ship:=ship_at(int(model));ship.ship_id=id;ship.attitude=tilt.get_rotation_quaternion()
			ship.configure_source_station(geometry,tilt)
			var rate:=0.1;var dt:=0.05;var command:float=rate*1.2/float(ship.profile().turn_rate)
			for frame in range(1,21):
				ship.configure_source_station(geometry,tilt*Basis(Vector3.FORWARD,frame*dt*rate),dt)
				ship.step(dt,Vector2.ZERO,command)
			check(ship.hull==100 and ship.position==Ship.STATION and not ship.autopilot,"Actual %s/%s remains clear under synchronous manual roll in a tilted frame"%[str(model),id])
			check(ship.can_dock() and ship.dock(),"Actual %s/%s rotating pose supports explicit manual capture"%[str(model),id])
			var payload:Dictionary=copy(ship.snapshot());var loaded:=Ship.new()
			loaded.configure_source_station(geometry,ship._source_basis)
			check(loaded.restore(payload) and loaded.docked,"Actual %s/%s manually captured save restores against the authoritative final source pose"%[str(model),id])

func small_tilt_regression()->void:
	# The old dot(up)>0.999999 shortcut discarded about0.0012rad of real roll.
	# The analytic vertical support grows enough to cross the true source ceiling.
	var ship:=ship_at();var geometry:=Geometry.prepare(80);var radii:Vector3=ship.source_collision_radii()
	var angle:=0.0012;var clearance:=0.00002
	var support_y:=sqrt(pow(radii.x*sin(angle),2)+pow(radii.y*cos(angle),2))
	var point:=Vector3(0,geometry.dock_bay.end.y-radii.y-clearance,0)
	check(point.y+support_y>geometry.dock_bay.end.y,"Analytic rotated ellipsoid really crosses the original ceiling at the small-angle control")
	var rotation:=Quaternion(Vector3.FORWARD,angle)
	check(not ship._source_shape_sweep(point,point,rotation).is_empty(),"Small real roll cannot be rounded to an axis-aligned hull in the static source sweep")
	ship.position=Ship.STATION+point;ship.attitude=rotation
	ship.configure_source_station(geometry,Basis(Vector3.FORWARD,0.0000002),0.05);ship.step(0.05,Vector2.ZERO)
	check(not ship.source_docking_telemetry().last_collision.is_empty(),"Tiny station rotation does not hide the same real ceiling overlap from conservative rotating CCD")

func actual_world_spin()->void:
	var nav:=Nav.new();check(nav.configure_native(),"Actual native navigation initializes")
	var world:=World.new();world.configure(nav.current(),World.FULL_LAYOUT)
	var port:Dictionary={}
	for site:Dictionary in world.settlements:
		if int(site.model_index)==80:port=site;break
	check(not port.is_empty(),"Actual Sol contains an original model80 orbital station")
	if port.is_empty():return
	world.focus_id=str(port.parent);world.selected_id=str(port.parent);world.site_id=str(port.id)
	var ship:=Ship.new();check(Session.configure_flight(ship,world,nav).active,"Real World/Navigation coordinator configures original station identity")
	var original:Quaternion=ship.attitude;var found:=false
	for frame in range(160):
		nav.elapsed_days+=0.05/86400.0
		var result:=Session.refresh(ship,world,nav,0.05)
		if not result.ok:check(false,"Real source station pose update must succeed");break
		var telemetry:Dictionary=ship.source_docking_telemetry()
		if telemetry.station_angular_velocity_world_rad_s.length()>0.000001:
			found=true
			check(telemetry.sample_valid and ship.attitude==original and ship.velocity==Vector3.ZERO,"Real F866/Q31 pose changes feed rate instruments without moving an undocked ship")
			break
	check(found,"Actual source spin produces a nonzero measured pose sample")
	var payload:Dictionary=copy(ship.snapshot());var world_payload:Dictionary=copy(world.snapshot());var nav_payload:Dictionary=copy(nav.snapshot())
	var candidate_nav:=Nav.new();check(candidate_nav.restore(nav_payload),"Native navigation snapshot restores")
	var candidate_world:=World.new();candidate_world.configure(candidate_nav.current())
	check(candidate_world.restore(world_payload),"Actual persistent source station pose restores")
	var candidate:Dictionary=Session.restore_flight(candidate_world,candidate_nav,payload)
	check(not candidate.is_empty() and not candidate.ship.source_docking_telemetry().sample_valid,"World-before-Flight restore keeps valid source context and starts a fresh rate baseline")

func run()->void:
	analytic_controls();manual_and_rate_history();manual_rotation_cycle();swept_rotating_collision();supported_hulls_and_stations();small_tilt_regression();actual_world_spin()
	print("ROTATING DOCK DYNAMICS TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
