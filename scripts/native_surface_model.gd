extends "res://scripts/surface_model.gd"
# Explicit bounded landing trial. The regular flight/surface revision is never
# replaced. Original integer contact and literal Float32 render leaves remain
# separately witnessed laws; this is not a claim of a universal source mesh.
const NativeProvider=preload("res://scripts/source_native_surface_provider.gd")
const NativeSession=preload("res://scripts/source_natural_contact_session.gd")
const NativeFootprint=preload("res://scripts/source_natural_footprint_probe.gd")
const NativePhone=preload("res://scripts/source_surface_contact_bridge.gd")
const NativeNatural=preload("res://scripts/source_natural_contact.gd")
const NativeFuel=preload("res://scripts/source_fuel_flight_bridge.gd")
const NativeTrace=preload("res://scripts/source_terrain_query_trace.gd")
const NativeGravityFrame=preload("res://scripts/source_fuel_contact.gd")
const NativePhysics=preload("res://scripts/source_physics_bridge.gd")
const NATIVE_SCHEMA:="starfrontier-native-surface-trial-v1"
const NATIVE_POLICY:="bounded-native-manual-landing-host-adapter-v1"
const MOTION_POLICY:="phone-delta-over-persistent-source-position-and-q16-velocity-v1"
const SNAPSHOT_KEYS:=["schema","version","policy","motion_policy","active","landed","body_id","system_id","source_record_hex","chart","source_days_f64_hex","phone_pose_f32_hex","phone_legacy_anchor","source_phone_anchor_f32_hex","source_phone_ship_id","orbit_position_f32_hex","orbit_attitude_f32_hex","provider","provider_retained_render_only","session","takeoff_requested","host_park_policy","snapshot_sha256"]
var native_session:RefCounted
var native_provider:RefCounted
var _native_phone_frame:Dictionary={}
var _native_source_record:=PackedByteArray()
var _native_anchor_position:=Vector3.ZERO
var _native_anchor_velocity:=Vector3.ZERO
var _native_anchor_attitude:=Quaternion.IDENTITY
var _native_anchor_ship_id:=""
var _native_stage:Dictionary={}
var _native_takeoff_requested:=false
var _native_provider_retained:=false
var native_last_reason:=""

static func _native_fail(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"damage_calls":[],"callbacks":[],"hp_applied":false,"clock_advanced":false,"fuel_advanced":false,"ordinary_terrain_fallback":false}
static func _native_hex(value:Variant,count:int)->bool:return NativeSession._hex(value,count)
static func _native_floats(values:Array,width:int)->String:
	var bytes:=PackedByteArray();bytes.resize(values.size()*width)
	for index in range(values.size()):
		if width==4:bytes.encode_float(index*width,float(values[index]))
		else:bytes.encode_double(index*width,float(values[index]))
	return bytes.hex_encode()
static func _native_numbers(hex:String,width:int)->Array:
	var bytes:=hex.hex_decode();var result:Array=[]
	for index in range(bytes.size()/width):result.append(bytes.decode_float(index*width) if width==4 else bytes.decode_double(index*width))
	return result
static func _native_pose(position:Vector3,velocity:Vector3,attitude:Quaternion)->String:
	return _native_floats([position.x,position.y,position.z,velocity.x,velocity.y,velocity.z,attitude.x,attitude.y,attitude.z,attitude.w],4)
static func _native_pose_valid(hex:Variant)->bool:
	if not _native_hex(hex,40):return false
	var values:=_native_numbers(str(hex),4)
	for value:float in values:
		if not is_finite(value) or absf(value)>1e9:return false
	var q:=Quaternion(values[6],values[7],values[8],values[9])
	return q.length_squared()>=0.01 and absf(q.length_squared()-1.0)<0.0001
static func _native_decode_pose(hex:String)->Dictionary:
	var values:=_native_numbers(hex,4)
	return {"position":Vector3(values[0],values[1],values[2]),"velocity":Vector3(values[3],values[4],values[5]),"attitude":Quaternion(values[6],values[7],values[8],values[9])}
static func _native_legacy_pose(ship:RefCounted)->Dictionary:
	return NativeSession._json({"position":[ship.position.x,ship.position.y,ship.position.z],"velocity":[ship.velocity.x,ship.velocity.y,ship.velocity.z],"attitude":[ship.attitude.x,ship.attitude.y,ship.attitude.z,ship.attitude.w]})
static func _native_phone(frame:Dictionary,operands:Dictionary)->Dictionary:
	var values:Array=[]
	for axis:Vector3 in [frame.basis.x,frame.basis.y,frame.basis.z]:
		for component:float in [axis.x,axis.y,axis.z]:values.append(component)
	return {"basis_f64":values,"radius_m":float(frame.globe.radius),"source_uid_u32":int(frame.record.decode_u32(4)),"source_model_index":int(frame.model),"latitude":float(frame.globe.latitude),"longitude":float(frame.globe.longitude),"parent_frame_policy":"isolated-matching-bodyfixed-parent-q31","source_body_parent_index_u8":int(operands.body[0x56]),"source_body_frame_u8":int(operands.body[0x57]),"source_parent_index_u8":int(operands.parent[0x86]),"source_parent_matrix_q31_hex":operands.parent.slice(0,36).hex_encode()}

func is_native_landing_trial()->bool:return active and native_session!=null and native_provider!=null
func native_world()->RefCounted:return _source_system
func _refresh_gravity(ship:RefCounted)->bool:
	# Same isolated source spin helper used by the fuel/atmosphere observers;
	# never advance World.body_spin_by_id merely to sample candidate gravity.
	if globe==null or _source_system==null or not _source_system.by_id.has(body_id):return false
	var body:Dictionary=_source_system.by_id[body_id]
	var rotation:=NativeGravityFrame._basis_readonly(_source_system,body,_source_days)
	if rotation.is_empty():return false
	var geoid:=geoid_height(ship)
	var up_sq:float=pow(float(globe.radius)+geoid,2)-float(ship.position.x)*ship.position.x-float(ship.position.z)*ship.position.z
	if up_sq<=0:return false
	var ll:Array=globe.coordinates_at_height(ship.position.x,ship.position.z,sqrt(up_sq)-float(globe.radius))
	var point:=OrbitLink.direction(ll[0],ll[1])*(float(globe.radius)+geoid)
	var raw:=NativePhysics.relative_from_metres(Basis(rotation.basis)*point)
	if raw.size()!=3:return false
	var sample:=NativePhysics.sample_prepared(int(body.source_a4_packed),raw)
	if sample.is_empty() or not is_finite(float(sample.get("gravity_mps2",NAN))):return false
	var frame:Basis=Basis(rotation.basis)*globe.basis_at(globe.latitude,globe.longitude)
	gravity=float(sample.gravity_mps2);gravity_vector=frame.inverse()*Vector3(sample.acceleration)
	return gravity_vector.is_finite()
func source_city()->bool:return false
# The old Main contact bridge must never consume this surface accidentally.
func uses_source_contact()->bool:return false
func set_source_contact_enabled(_enabled:bool)->void:
	source_contact_enabled=false;_pending_source_contact.clear()
func publish_source_render_state(_state:RefCounted)->void:pass
func pending_source_contact()->Dictionary:return {}
func height_sample(x:float,z:float)->Dictionary:
	# Display AGL uses the uppermost of the emitted literal Float32 triangles.
	# Original contact still tests each source observer against its own leaf.
	return native_provider.height_at(x,z) if native_provider!=null else {}
func height_at(x:float,z:float)->float:
	var hit:=height_sample(x,z)
	return float(hit.height) if not hit.is_empty() else NAN
func raw_height_at(x:float,z:float)->float:return height_at(x,z)
func terrain_key()->String:return NATIVE_SCHEMA+":"+native_provider.snapshot_identity() if native_provider!=null else NATIVE_SCHEMA+":unconfigured"
func recenter(_ship:RefCounted)->void:pass
func pad_position()->Vector3:return Vector3(NAN,NAN,NAN)
func pad_distance(_ship:RefCounted)->float:return INF
func begin_landing(_ship:RefCounted)->bool:
	message="В испытании исходного контакта выполняйте посадку вручную с выпущенными шасси.";return false
func touch_down(_ship:RefCounted)->bool:return false
func begin_departure(_ship:RefCounted)->bool:return false
func begin_ascent(_ship:RefCounted)->bool:return false
func begin_descent(_ship:RefCounted,_system:RefCounted,_days:float)->bool:return false
func resume_descent(_ship:RefCounted)->bool:return false
func enter(_ship:RefCounted,_system:RefCounted,_spherical:=false,_terrain_revision:String=SphereTerrain.CURRENT_REVISION)->bool:return false
func enter_from_orbit(_ship:RefCounted,_system:RefCounted,_days:float)->bool:return false
func leave(_ship:RefCounted,_system:RefCounted=null,_days:=0.0)->bool:return false
func bind_city(_site:Dictionary)->bool:return false

func _native_anchor(ship:RefCounted)->void:
	_native_anchor_position=ship.position;_native_anchor_velocity=ship.velocity;_native_anchor_attitude=ship.attitude;_native_anchor_ship_id=str(ship.ship_id)

func initialize_from(previous:RefCounted,ship:RefCounted,world:RefCounted,days:float,entry_height:float=50.0)->bool:
	if active or previous==null or previous.get("active")!=true or ship==null or world==null or not is_finite(days) or days<0 or days>1e9 or not is_finite(entry_height) or entry_height!=50.0:return false
	if not previous.get("city_data") is Dictionary or not previous.city_data.is_empty() or previous.get("underground")!=null or not previous.get("globe") is SourceTerrain:return false
	var old_globe:RefCounted=previous.globe
	if old_globe.get("configured_ok")!=true or not old_globe.get("source_record") is PackedByteArray or old_globe.source_record.size()!=68:return false
	var target:=str(previous.body_id)
	if target!=str(world.focus_id) or not world.by_id.has(target) or str(world.by_id[target].get("runtime_record_hex",""))!=old_globe.source_record.hex_encode():return false
	if ship.docked or ship.hull<=0 or not _native_pose_valid(_native_pose(ship.position,ship.velocity,ship.attitude)):return false
	var terrain:=SourceTerrain.new();terrain.configure(world,target,"")
	if not terrain.configured_ok:return false
	terrain.latitude=float(old_globe.latitude);terrain.longitude=float(old_globe.longitude)
	# Only metadata/frame comes from the old revision. No old sampled height is
	# consulted and no existing play session is translated to this source field.
	globe=terrain;body_id=target;_source_system=world;_source_days=days;active=true
	var prepared:=NativeFootprint._prepare(self,ship,{})
	if not prepared.get("ok",false):active=false;return false
	var initial:=NativeFootprint._operands(prepared,0)
	if initial.is_empty():active=false;return false
	_native_phone_frame=_native_phone(prepared,initial);_native_source_record=prepared.record.duplicate()
	var direction:=PackedInt64Array();var basis:Basis=prepared.basis
	var length:=sqrt(float(basis.y.x)*basis.y.x+float(basis.y.y)*basis.y.y+float(basis.y.z)*basis.y.z)
	for value:float in [basis.y.x,basis.y.y,basis.y.z]:direction.append(clampi(roundi(value/length*2147483647.0),-2147483647,2147483647))
	var entry_hash:=NativeSession._hash({"system_id":int(world.system_id),"body_id":target,"source_record_hex":_native_source_record.hex_encode(),"phone_frame":_native_phone_frame,"entry_policy":"explicit-new-trial-signed-native-root-plus-50m"})
	var root:=NativeProvider.prepare_root(_native_source_record,_native_phone_frame,direction,{"generation":0,"request_token":entry_hash,"request_sha256":entry_hash})
	if not root.get("ok",false):active=false;native_last_reason=str(root.get("reason","native_root_unavailable"));return false
	var provider:RefCounted=root.provider;var anchor:Dictionary=provider.root_anchor();var local:Variant=anchor.get("local_point")
	if not local is PackedFloat64Array or local.size()!=3:active=false;return false
	var x:=float(Vector3(local[0],0,local[2]).x);var z:=float(Vector3(local[0],0,local[2]).z)
	var ground:Dictionary=provider.height_at(x,z,0)
	if ground.is_empty():active=false;native_last_reason="entry_float32_anchor_outside_literal_leaf";return false
	var original_pose:=_native_pose(ship.position,ship.velocity,ship.attitude)
	ship.position=Vector3(x,float(ground.height)+clearance(ship)+entry_height,z);ship.velocity=Vector3.ZERO;ship.attitude=Quaternion.IDENTITY
	prepared=NativeFootprint._prepare(self,ship,{})
	var operands:=NativeFootprint._operands(prepared,0) if prepared.get("ok",false) else {}
	var session:=NativeSession.new()
	var binding:={"system_id":int(world.system_id),"parent_id":target,"source_record_hex":_native_source_record.hex_encode(),"coordinate_policy":NativeSession.COORDINATE_POLICY,"history_policy":NativeSession.HISTORY_POLICY}
	if operands.is_empty() or not session.configure(operands.body,operands.parent,NativeNatural._globals({}),binding) or not _refresh_gravity(ship):
		var old:=_native_decode_pose(original_pose);ship.position=old.position;ship.velocity=old.velocity;ship.attitude=old.attitude;active=false;return false
	native_provider=provider;native_session=session;_source_render_ship=ship;_native_anchor(ship)
	orbit_position=previous.orbit_position;orbit_attitude=previous.orbit_attitude;kind=str(previous.kind);seed_value=int(previous.seed_value)
	landed=false;landing=false;taking_off=false;flight_phase="";extended_flight=false;ready_for_orbit=false;frame_index=0
	ship.surface_mode=true;ship.station_available=false;ship.autopilot=false;ship.target_speed=0;ship.assisted=true;ship.source_motion_profile=false
	render_position=ship.position;render_velocity=ship.velocity;_source_render_clearance=altitude(ship)
	message="Испытание исходной посадки: ручное управление, шасси, ограниченный участок исходного рельефа."
	native_last_reason="native_trial_initialized_from_signed_root";return true

func fork_runtime(ship:RefCounted=null)->RefCounted:
	var copy:RefCounted=get_script().new()
	for property:Dictionary in get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:
			var key:=str(property.name);var value:Variant=get(key)
			if key=="native_session":value=native_session.fork_runtime() if native_session!=null else null
			elif value is Dictionary or value is Array:value=value.duplicate(true)
			elif value is PackedByteArray or value is PackedInt64Array or value is PackedFloat64Array:value=value.duplicate()
			copy.set(key,value)
	copy._source_render_ship=ship if ship!=null else _source_render_ship
	return copy

func take_off(ship:RefCounted)->bool:
	if not is_native_landing_trial() or not landed or native_session.phase()!="parked" or ship.hull<=0 or not ship.propulsion_available:return false
	var valid_lift:Vector3=ship.filter_propulsive_delta(Vector3.UP)
	if not valid_lift.is_finite() or valid_lift.dot(Vector3.UP)<=0:return false
	# A request arms the next powered interval. It never teleports or rotates.
	_native_takeoff_requested=true;message="Взлёт запрошен. Подъём начнётся при доступной тяге.";return true

func _native_operands(ship:RefCounted,gear:int)->Dictionary:
	var frame:=NativeFootprint._prepare(self,ship,{})
	if not frame.get("ok",false):return _native_fail(str(frame.get("reason","invalid_native_phone_frame")))
	var operands:=NativeFootprint._operands(frame,gear)
	if operands.is_empty() or _native_anchor_ship_id!=str(ship.ship_id):return _native_fail("invalid_or_changed_native_trial_ship")
	if _native_phone(frame,operands)!=_native_phone_frame or operands.parent!=native_session.raw_parent():return _native_fail("native_trial_chart_or_parent_changed")
	var old:PackedByteArray=native_session.raw_body();var candidate:PackedByteArray=operands.body
	var move:=NativePhone.to_bodyfixed_vector(frame.basis,ship.position-_native_anchor_position)
	var delta_velocity:=NativePhone.to_bodyfixed_vector(frame.basis,ship.velocity-_native_anchor_velocity)
	if move.size()!=3 or delta_velocity.size()!=3:return _native_fail("native_motion_delta_undefined")
	for axis in range(3):
		var delta_raw:=roundi(move[axis]/SourceUnits.METRES_PER_RAW)
		var position_raw:int=old.decode_s64(0x3e+axis*8)
		if absf(float(position_raw))+absf(float(delta_raw))>4503599627370495.0:return _native_fail("native_position_delta_overflow")
		candidate.encode_s64(0x3e+axis*8,position_raw+delta_raw)
		var q16:int=old.decode_s32(0x8c+axis*4)*65536+old.decode_u16(0xec+axis*2)
		q16+=roundi(delta_velocity[axis]/NativePhone.Physics.VELOCITY_UNIT_MPS*65536.0)
		if q16<(-140737488355328) or q16>140737488355327:return _native_fail("native_velocity_delta_overflow")
		candidate.encode_s32(0x8c+axis*4,q16>>16);candidate.encode_u16(0xec+axis*2,q16&65535)
	if ship.attitude==_native_anchor_attitude:
		for index in range(36):candidate[index]=old[index]
	return {"ok":true,"frame":frame,"body":candidate,"parent":operands.parent,"relative":NativeSession._relative(candidate)}

func stage_manual(ship:RefCounted,seconds:float,steering:Vector2,roll:float,lift:float,gear_word:int,interval_receipt:Dictionary)->Dictionary:
	if not is_native_landing_trial() or not _native_stage.is_empty() or native_session.is_pending():return _native_fail("inactive_or_pending_native_trial")
	if not is_finite(seconds) or seconds<=0 or seconds>1.0 or not steering.is_finite() or not is_finite(roll) or not is_finite(lift) or not NativeNatural._whole(gear_word,0,65535) or not NativeSession._plain(interval_receipt):return _native_fail("invalid_native_manual_interval")
	if ship.hull<=0 or ship.docked or not _native_pose_valid(_native_pose(ship.position,ship.velocity,ship.attitude)):return _native_fail("invalid_native_manual_ship")
	if not _refresh_gravity(ship):return _native_fail("native_trial_gravity_unavailable")
	ship.last_propulsive_delta_v=Vector3.ZERO
	if landed:
		var request_lift:=1.0 if _native_takeoff_requested else clampf(lift,-1,1)
		var powered:Vector3=ship.filter_propulsive_delta(Vector3.UP*request_lift*ship.acceleration()*seconds)
		if request_lift<=0 or not ship.propulsion_available or not powered.is_finite() or powered.dot(Vector3.UP)<=0:
			var scheduler:Dictionary=native_session.parked_tick()
			if not scheduler.get("ok",false):return _native_fail("native_parked_scheduler_rejected")
			return {"ok":true,"parked_idle":true,"reason":"native_raw_park_anchor_retained","damage_calls":[],"callbacks":[],"fuel_commands":[0,0,0],"contact_detected":false,"landing_accepted":false,"parked_scheduler":scheduler.duplicate(true)}
		var released:Dictionary=native_session.release_park()
		if not released.get("ok",false):return _native_fail("native_park_release_rejected")
		landed=false;_native_takeoff_requested=false;lift=request_lift
	ship.autopilot=false;landing=false;taking_off=false;flight_phase="";ready_for_orbit=false
	var manual_attitude:Quaternion=ship.attitude
	ship.step(seconds,steering,roll,gravity_vector,lift)
	if steering==Vector2.ZERO and roll==0.0:ship.attitude=manual_attitude
	if not _native_pose_valid(_native_pose(ship.position,ship.velocity,ship.attitude)):return _native_fail("nonfinite_native_manual_candidate")
	var fuel_commands:=NativeFuel.commands(ship,seconds)
	var operands:=_native_operands(ship,gear_word)
	if not operands.get("ok",false):return operands
	var request:={"sequence":native_session.generation()+1,"graphics_level":1,"caller_policy":NativeSession.CALLER_POLICY,"interval_receipt":interval_receipt.duplicate(true)}
	var prepared:Dictionary=native_session.prepare(operands.body,operands.parent,operands.relative,request)
	if not prepared.get("ok",false):return prepared
	var binding:={"generation":int(prepared.generation),"request_token":str(prepared.token),"request_sha256":str(prepared.request_sha256)}
	var built:=NativeProvider.stage_from_classification(operands.body,operands.parent,operands.relative,prepared.classification,prepared.trace_rows,_native_phone_frame,binding)
	var provider:RefCounted
	var retained:=false
	if built.get("ok",false):provider=built.provider
	elif not prepared.contact_detected and int(prepared.classification.get("terrain_query_calls",0))==0 and not native_provider.height_at(ship.position.x,ship.position.z).is_empty():
		# Render-only retention does not fabricate a missing original query.
		provider=native_provider;retained=true
	else:
		native_session.discard(str(prepared.token));return _native_fail(str(built.get("reason","native_provider_unavailable")))
	var resolution:=NativePhone._pose_delta(operands.frame,operands.body,prepared.kernel.body_after)
	if not resolution.get("ok",false):native_session.discard(str(prepared.token));return _native_fail(str(resolution.get("reason","native_response_projection_failed")))
	if prepared.response_applied:
		# F575 may move/align a body to a different observer leaf. Generate fresh
		# visible geometry without running another physical response or committing
		# the observational classifier's globals to the accepted park/history.
		var raw_after:PackedByteArray=prepared.kernel.body_after
		var relative_after:=NativeSession._relative(raw_after)
		var classifier:=NativeNatural.new();var trace:=NativeTrace.new();classifier.set("_query",trace)
		var observed:=classifier.classify_natural_player(raw_after,operands.parent,relative_after,{"graphics_level":1,"initial_globals":NativeSession.caller_globals(prepared.globals_after)})
		var post:=NativeProvider.stage_from_classification(raw_after,operands.parent,relative_after,observed,trace.read_trace(),_native_phone_frame,binding,"post_response_render_only")
		if not post.get("ok",false):native_session.discard(str(prepared.token));return _native_fail(str(post.get("reason","native_post_response_render_unavailable")))
		provider=post.provider;retained=false
	if provider.height_at(resolution.position.x,resolution.position.z).is_empty():native_session.discard(str(prepared.token));return _native_fail("native_response_outside_literal_rendered_leaves")
	_native_stage={"ok":true,"parked_idle":false,"reason":"native_manual_interval_prepared","token":str(prepared.token),"commit_receipt":prepared.commit_receipt.duplicate(true),"damage_calls":prepared.damage_calls.duplicate(true),"callbacks":prepared.callbacks.duplicate(true),"contact_detected":bool(prepared.contact_detected),"landing_accepted":bool(prepared.landing_accepted),"response_applied":bool(prepared.response_applied),"resolution":resolution.duplicate(true),"provider":provider,"provider_retained_render_only":retained,"manual_position":ship.position,"manual_velocity":ship.velocity,"manual_attitude":ship.attitude,"fuel_commands":fuel_commands.duplicate(true),"source_prepared":prepared.duplicate(true),"motion_policy":MOTION_POLICY}
	return _native_stage.duplicate(true)

func finish_native_step(ship:RefCounted,stage:Dictionary,parked:bool,hpdetail:Dictionary)->bool:
	if stage.get("parked_idle")==true:return landed and native_session.phase()=="parked"
	if _native_stage.is_empty() or stage.get("token")!=_native_stage.token or stage.get("commit_receipt")!=_native_stage.commit_receipt or stage.get("provider")!=_native_stage.provider:return false
	if parked and (not _native_stage.landing_accepted or ship.hull<=0):return false
	var prepared:Dictionary=_native_stage
	var committed:Dictionary=native_session.commit(str(prepared.token),prepared.commit_receipt)
	if not committed.get("ok",false) or committed.get("already_committed",false):return false
	if parked and not native_session.mark_parked():return false
	var correction:Vector3=ship.velocity-Vector3(prepared.manual_velocity)
	var resolved:Dictionary=prepared.resolution
	ship.position=resolved.position;ship.velocity=Vector3(resolved.velocity)+correction;ship.attitude=resolved.attitude
	native_provider=prepared.provider
	_native_provider_retained=bool(prepared.provider_retained_render_only)
	# The mapping anchor denotes exact source output BEFORE host thermal drag.
	_native_anchor_position=resolved.position;_native_anchor_velocity=resolved.velocity;_native_anchor_attitude=resolved.attitude;_native_anchor_ship_id=str(ship.ship_id)
	landed=parked
	if parked:
		ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.autopilot=false
		_native_anchor_velocity=Vector3.ZERO
		message="Исходная посадка принята. «Взлететь» или «Подъём» — запрос доступной тяги."
	elif bool(prepared.contact_detected):
		message="Исходное касание обработано. Корпус %.2f%%."%ship.hull
	elif hpdetail.get("destruction_requested",false):message="Корабль потерян."
	# No-hit has no landing/control reset and no position/AGL correction.
	_source_render_ship=ship;render_position=ship.position;render_velocity=ship.velocity;_source_render_clearance=altitude(ship)
	_native_stage={};native_last_reason="native_manual_interval_committed";return true

func acknowledge_post_interval(ship:RefCounted)->bool:
	if not is_native_landing_trial() or not _native_stage.is_empty() or native_session.is_pending() or str(ship.ship_id)!=_native_anchor_ship_id or ship.position!=_native_anchor_position or ship.attitude!=_native_anchor_attitude or not ship.velocity.is_finite():return false
	if landed and ship.velocity!=Vector3.ZERO:return false
	# Host thermal velocity is an explicit deferred delta over the exact raw
	# source anchor. It is applied once by the next _native_operands call, and
	# both anchors survive a cold restore without dropping Q16 low words.
	_source_render_ship=ship;render_position=ship.position;render_velocity=ship.velocity;return true

func step(_dt:float,_ship:RefCounted,_steering:Vector2,_roll:float,_lift:=0.0)->void:
	message="Исходный контакт требует атомарного контроллера испытания."

func snapshot()->Dictionary:
	if not is_native_landing_trial() or _source_render_ship==null or not _native_stage.is_empty() or native_session.is_pending():return {}
	var ship:RefCounted=_source_render_ship
	var basis:Basis=globe.basis_at(globe.latitude,globe.longitude)
	var values:Array=[]
	for axis:Vector3 in [basis.x,basis.y,basis.z]:
		for value:float in [axis.x,axis.y,axis.z]:values.append(value)
	var state:=NativeSession._json({"schema":NATIVE_SCHEMA,"version":1,"policy":NATIVE_POLICY,"motion_policy":MOTION_POLICY,"active":true,"landed":landed,"body_id":body_id,"system_id":int(_source_system.system_id),"source_record_hex":_native_source_record.hex_encode(),"chart":{"latitude_f64_hex":_native_floats([globe.latitude],8),"longitude_f64_hex":_native_floats([globe.longitude],8),"radius_f64_hex":_native_floats([globe.radius],8),"basis_f32_hex":_native_floats(values,4)},"source_days_f64_hex":_native_floats([_source_days],8),"phone_pose_f32_hex":_native_pose(ship.position,ship.velocity,ship.attitude),"phone_legacy_anchor":_native_legacy_pose(ship),"source_phone_anchor_f32_hex":_native_pose(_native_anchor_position,_native_anchor_velocity,_native_anchor_attitude),"source_phone_ship_id":_native_anchor_ship_id,"orbit_position_f32_hex":_native_floats([orbit_position.x,orbit_position.y,orbit_position.z],4),"orbit_attitude_f32_hex":_native_floats([orbit_attitude.x,orbit_attitude.y,orbit_attitude.z,orbit_attitude.w],4),"provider":native_provider.snapshot(),"provider_retained_render_only":_native_provider_retained,"session":native_session.snapshot(),"takeoff_requested":_native_takeoff_requested,"host_park_policy":NativeSession.PARK_POLICY})
	state.snapshot_sha256=NativeSession._hash(state);return state

func restore(data:Dictionary,ship:RefCounted,world:RefCounted)->bool:
	if active or not NativeSession._keys(data,SNAPSHOT_KEYS) or data.schema!=NATIVE_SCHEMA or not NativeNatural._whole(data.version,1,1) or data.policy!=NATIVE_POLICY or data.motion_policy!=MOTION_POLICY or data.active!=true or not data.landed is bool or not data.takeoff_requested is bool or not data.provider_retained_render_only is bool or data.host_park_policy!=NativeSession.PARK_POLICY or data.body_id!=str(world.focus_id) or not NativeNatural._whole(data.system_id,0,0xffffffff) or int(data.system_id)!=int(world.system_id):return false
	var sealed:=data.duplicate(true);sealed.erase("snapshot_sha256")
	if not _native_hex(data.snapshot_sha256,32) or NativeSession._hash(sealed)!=data.snapshot_sha256:return false
	if not _native_hex(data.source_record_hex,68) or not world.by_id.has(str(data.body_id)) or world.by_id[str(data.body_id)].get("runtime_record_hex")!=data.source_record_hex or not _native_hex(data.source_days_f64_hex,8) or not _native_pose_valid(data.phone_pose_f32_hex) or not _native_pose_valid(data.source_phone_anchor_f32_hex) or not data.source_phone_ship_id is String or data.source_phone_ship_id!=str(ship.ship_id):return false
	if not data.chart is Dictionary or not NativeSession._keys(data.chart,["latitude_f64_hex","longitude_f64_hex","radius_f64_hex","basis_f32_hex"]):return false
	for key:String in ["latitude_f64_hex","longitude_f64_hex","radius_f64_hex"]:
		if not _native_hex(data.chart[key],8):return false
	if not _native_hex(data.chart.basis_f32_hex,36) or not _native_hex(data.orbit_position_f32_hex,12) or not _native_hex(data.orbit_attitude_f32_hex,16) or not data.provider is Dictionary or not data.session is Dictionary or not data.phone_legacy_anchor is Dictionary:return false
	var legacy:Dictionary=data.phone_legacy_anchor
	if not NativeSession._keys(legacy,["position","velocity","attitude"]):return false
	for key:String in ["position","velocity","attitude"]:
		if not legacy[key] is Array or legacy[key].size()!=(4 if key=="attitude" else 3):return false
		for value:Variant in legacy[key]:
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>1e9:return false
	if ship.position!=Vector3(legacy.position[0],legacy.position[1],legacy.position[2]) or ship.velocity!=Vector3(legacy.velocity[0],legacy.velocity[1],legacy.velocity[2]) or ship.attitude!=Quaternion(legacy.attitude[0],legacy.attitude[1],legacy.attitude[2],legacy.attitude[3]).normalized():return false
	var pose:=_native_decode_pose(data.phone_pose_f32_hex);var anchor:=_native_decode_pose(data.source_phone_anchor_f32_hex)
	if data.landed and (pose.velocity!=Vector3.ZERO or ship.hull<=0):return false
	# Exact bits must project to the same legacy JSON anchors; arbitrary exact
	# pose substitutions cannot hide behind the old Flight serialization.
	var exact_legacy:=NativeSession._json({"position":[pose.position.x,pose.position.y,pose.position.z],"velocity":[pose.velocity.x,pose.velocity.y,pose.velocity.z],"attitude":[pose.attitude.x,pose.attitude.y,pose.attitude.z,pose.attitude.w]})
	if exact_legacy!=legacy or pose.position!=anchor.position or pose.attitude!=anchor.attitude or ship.docked:return false
	var days:float=_native_numbers(data.source_days_f64_hex,8)[0];var lat:float=_native_numbers(data.chart.latitude_f64_hex,8)[0];var lon:float=_native_numbers(data.chart.longitude_f64_hex,8)[0];var radius:float=_native_numbers(data.chart.radius_f64_hex,8)[0]
	if not is_finite(days) or days<0 or days>1e9 or not is_finite(lat) or absf(lat)>PI*0.5 or not is_finite(lon) or absf(lon)>PI or not is_finite(radius) or radius<=0:return false
	var terrain:=SourceTerrain.new();terrain.configure(world,str(data.body_id),"");terrain.latitude=lat;terrain.longitude=lon
	if not terrain.configured_ok or float(terrain.radius)!=radius:return false
	var basis:Basis=terrain.basis_at(lat,lon);var values:Array=[]
	for axis:Vector3 in [basis.x,basis.y,basis.z]:
		for value:float in [axis.x,axis.y,axis.z]:values.append(value)
	if _native_floats(values,4)!=data.chart.basis_f32_hex:return false
	var provider:=NativeProvider.from_snapshot(data.provider);var session:=NativeSession.new()
	if provider==null or not session.restore(data.session) or session.binding().parent_id!=data.body_id or int(session.binding().system_id)!=int(data.system_id) or session.binding().source_record_hex!=data.source_record_hex or (session.phase()=="parked")!=bool(data.landed):return false
	var decoded:=NativeProvider._decode(data.provider.source_witness,{"nodes":0})
	if not decoded.get("ok",false) or not decoded.value is Dictionary or not decoded.value.get("phone_frame") is Dictionary:return false
	var phone:Dictionary=decoded.value.phone_frame
	if phone.get("basis_f64")!=values or phone.get("latitude")!=lat or phone.get("longitude")!=lon or phone.get("radius_m")!=radius or int(phone.get("source_uid_u32",-1))!=terrain.source_record.decode_u32(4) or int(phone.get("source_model_index",-1))!=terrain.source_model_index or provider.height_at(pose.position.x,pose.position.z).is_empty():return false
	if data.provider.kind in ["actual_f576_visited_leaves","post_response_render_only","airborne_render_only"] and not data.provider_retained_render_only:
		var witness_body:Variant=decoded.value.get("body");var source_body:PackedByteArray=session.raw_body()
		if not witness_body is PackedByteArray or witness_body.size()!=338 or witness_body.slice(0,36)!=source_body.slice(0,36) or witness_body.slice(0x3e,0x58)!=source_body.slice(0x3e,0x58) or decoded.value.get("parent")!=session.raw_parent():return false
	var payload:Dictionary=provider.render_payload();var provider_binding:Dictionary=payload.request_binding
	if int(provider_binding.generation)>session.generation() or int(provider_binding.generation)<0:return false
	if data.provider_retained_render_only:
		if data.landed or int(provider_binding.generation)>=session.generation():return false
		# The flag is not a general witness/pose mismatch escape hatch. Retention
		# is admitted only when the current source header or coarse classifier
		# genuinely does not issue a terrain query, matching runtime admission.
		var current_body:PackedByteArray=session.raw_body();var current_parent:PackedByteArray=session.raw_parent();var current_relative:=NativeSession._relative(current_body)
		if NativeSession._header_enters(current_body,current_parent,current_relative):
			var coarse:=NativeNatural.new().classify_natural_player(current_body,current_parent,current_relative,{"graphics_level":1,"initial_globals":NativeSession.caller_globals(session.globals())})
			if not coarse.get("ok",false) or int(coarse.get("f576_return_s32",0))==0 or int(coarse.get("terrain_query_calls",-1))!=0:return false
	elif data.provider.kind=="render_only_signed_root":
		if session.generation()!=0 or int(provider_binding.generation)!=0 or decoded.value.get("record")!=terrain.source_record:return false
	else:
		var source_snapshot:Dictionary=data.session
		if session.generation()<1 or int(provider_binding.generation)+1!=session.generation() or provider_binding.request_token!=source_snapshot.last_token or provider_binding.request_sha256!=source_snapshot.last_token:return false
	var orbit_p:=_native_numbers(data.orbit_position_f32_hex,4);var orbit_q:=_native_numbers(data.orbit_attitude_f32_hex,4)
	var orbit_rotation:=Quaternion(orbit_q[0],orbit_q[1],orbit_q[2],orbit_q[3]);var orbit_point:=Vector3(orbit_p[0],orbit_p[1],orbit_p[2])
	if not orbit_point.is_finite() or not orbit_rotation.is_finite() or orbit_rotation.length_squared()<0.01:return false
	# Pure restore: accepted parked raw F575 witness was replayed by session.
	# No AGL +/-1m rule, no old grid, no gear/fuel/HP/time mutation or snap.
	globe=terrain;_source_system=world;_source_days=days;body_id=str(data.body_id);active=true
	_native_source_record=terrain.source_record.duplicate();_native_phone_frame=phone.duplicate(true);native_provider=provider;native_session=session
	ship.position=pose.position;ship.velocity=pose.velocity;ship.attitude=pose.attitude
	_native_anchor_position=anchor.position;_native_anchor_velocity=anchor.velocity;_native_anchor_attitude=anchor.attitude;_native_anchor_ship_id=str(ship.ship_id)
	landed=bool(data.landed);_native_takeoff_requested=bool(data.takeoff_requested)
	_native_provider_retained=bool(data.provider_retained_render_only)
	if landed and (ship.velocity!=Vector3.ZERO or ship.hull<=0):active=false;return false
	orbit_position=orbit_point;orbit_attitude=orbit_rotation;_source_render_ship=ship;kind=str(world.by_id[body_id].get("kind","rock"));seed_value=int(world.system_id)^body_id.hash()
	if not _refresh_gravity(ship):active=false;return false
	ship.surface_mode=true;ship.station_available=false;ship.source_motion_profile=false;ship.autopilot=false
	render_position=ship.position;render_velocity=ship.velocity;_source_render_clearance=altitude(ship);native_last_reason="native_trial_cold_witness_restored";return true
