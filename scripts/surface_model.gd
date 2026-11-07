extends RefCounted

const OrbitLink=preload("res://scripts/surface_orbit_link.gd")
var orbit_link:Dictionary={}
const CityRuntime=preload("res://scripts/source_city_runtime.gd")
var city_data:Dictionary={}
const SphereTerrain=preload("res://scripts/spherical_terrain.gd")
const SourceTerrain=preload("res://scripts/source_surface_terrain.gd")
const Underground=preload("res://scripts/source_underground_controller.gd")
const RenderPacket=preload("res://scripts/source_surface_render_packet.gd")
var underground:RefCounted
var source_render_packet:Dictionary={}
var source_render_worker_state:Dictionary={}
var source_render_state:RefCounted
var render_position:=Vector3.ZERO
var render_velocity:=Vector3.ZERO
var _source_render_ship:RefCounted
var _source_render_clearance:=NAN
var _render_frame_shift:=Vector3.ZERO
var gravity_vector:=Vector3.DOWN
var _source_system:RefCounted
var _source_days:=0.0
const ENTRY_PREPARATION:="source-surface-entry-preparation-v1"
var _prepared_entry:Dictionary={}
class EntrySystem extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=0
const REBASE_DISTANCE:=512.0
const MIN_DESCENT_HEIGHT:=1800.0
const MAX_DESCENT_HEIGHT:=60000.0
# Height over the rendered terrain can exceed geoid height in shallow depressions.
const MAX_FLIGHT_HEIGHT:=60200.0
var extended_flight:=false
var flight_phase:=""
var ready_for_orbit:=false
var globe:RefCounted
var frame_index:=0
var frame_rotation:=Quaternion.IDENTITY
var rebase_from:=Vector3.ZERO
var rebase_to:=Vector3.ZERO
const SegmentBox=preload("res://scripts/segment_box.gd")
const G := 6.67430e-11
const SOLAR_MASS := 1.98847e30
const LIMIT := 1750.0
const GRID_WIDTH:=4000.0
const GRID_CELLS:=96
var taking_off:=false
var active := false
var landed := false
var landing := false
var body_id := ""
var seed_value := 0
var gravity := 0.0
var orbit_position := Vector3.ZERO
var orbit_attitude := Quaternion.IDENTITY
var message := ""
var kind := "rock"
var site_name:=""

static func preferred_terrain_revision(system:RefCounted)->String:return OrbitLink.preferred_terrain_revision(system)
static func source_layout(system:RefCounted)->bool:return OrbitLink.is_source_layout(system)
static func _entry_context(system:RefCounted,ship:RefCounted)->String:
	var site:Dictionary=system.current_site()
	var body:Dictionary=system.by_id.get(str(system.focus_id),{})
	var profile:Dictionary=ship.profile()
	if not (profile.get("visual_span_m") is float or profile.get("visual_span_m") is int) or not is_finite(float(profile.visual_span_m)) or float(profile.visual_span_m)<=0:return ""
	var span:=float(profile.visual_span_m)
	return var_to_bytes([ENTRY_PREPARATION,str(system.layout_mode),str(system.source_digest),int(system.system_id),str(system.focus_id),str(system.site_id),str(body.get("runtime_record_hex","")),str(site.get("runtime_record_hex","")),str(ship.ship_id),span,bool(ship.source_motion_profile)]).hex_encode().sha256_text()
static func create_entry_snapshot(system:RefCounted,ship:RefCounted,days:=0.0)->Dictionary:
	if not source_layout(system) or not system.by_id.has(str(system.focus_id)):return {}
	var body:Dictionary=system.by_id[str(system.focus_id)]
	if not body.get("landable",false):return {}
	if _entry_context(system,ship).is_empty():return {}
	var selected:Dictionary=system.current_site().duplicate(true)
	var anchor:=str(selected.get("id","")) if int(selected.get("type_code",-1))==35 else ""
	var sites:Array=[]
	for site:Dictionary in system.settlements:
		if str(site.get("parent",""))==str(system.focus_id) and int(site.get("type_code",-1))==35:sites.append(site.duplicate(true))
	var span:=float(ship.profile().visual_span_m)
	var body_point:Vector3=system.body_rotation_basis(str(system.focus_id),days).inverse()*(ship.position-system.local_meters(str(system.focus_id),days))
	return {"revision":ENTRY_PREPARATION,"context":_entry_context(system,ship),"body_id":str(system.focus_id),"site_id":anchor,"site":selected if not anchor.is_empty() else {},"system_id":int(system.system_id),"by_id":{str(system.focus_id):body.duplicate(true)},"settlements":sites,"radii":Vector3(span*0.55,span*0.14+2.0,span*0.55),"bodyfixed_ship_point":body_point,"ship_position":Vector3(ship.position),"days":days}
static func prepare_entry(snapshot:Dictionary)->Dictionary:
	if snapshot.get("revision")!=ENTRY_PREPARATION or not snapshot.get("context") is String or not snapshot.get("by_id") is Dictionary or not snapshot.get("settlements") is Array or not snapshot.get("body_id") is String or not snapshot.get("site_id") is String or not snapshot.get("site") is Dictionary or not snapshot.get("radii") is Vector3:return {"ok":false,"error":"Invalid source surface preparation snapshot"}
	var proxy:=EntrySystem.new();proxy.system_id=int(snapshot.get("system_id",0));proxy.by_id=snapshot.by_id.duplicate(true);proxy.settlements=snapshot.settlements.duplicate(true)
	var terrain:=SourceTerrain.new();terrain.configure(proxy,str(snapshot.body_id),str(snapshot.site_id))
	if not terrain.configured_ok:return {"ok":false,"error":terrain.configuration_error}
	var point:Variant=snapshot.get("bodyfixed_ship_point")
	if point is Vector3 and point.is_finite() and point.length()>1.0:
		var body:Dictionary=proxy.by_id[str(snapshot.body_id)]
		var envelope:=maxf(float(body.get("source_outer_bound_m",terrain.radius)),terrain.radius)+MAX_DESCENT_HEIGHT
		if point.length()<=envelope:
			var ll:=[atan2(float(point.y),sqrt(float(point.x)*point.x+float(point.z)*point.z)),atan2(-float(point.z),float(point.x))]
			var height:float=point.length()-terrain.radius-terrain.elevation(ll[0],ll[1])
			if height>=MIN_DESCENT_HEIGHT and height<=MAX_DESCENT_HEIGHT:terrain.latitude=ll[0];terrain.longitude=ll[1]
	var helper:RefCounted=load("res://scripts/surface_model.gd").new()
	var prepared:Dictionary=helper._prepare_city(terrain,snapshot.site,snapshot.radii)
	if not prepared.get("ok",false):return prepared
	var kind:=str(proxy.by_id[str(snapshot.body_id)].get("kind","rock"))
	if kind not in RenderPacket.KINDS:kind="rock"
	var packet:=RenderPacket.prepare(terrain,{"kind":kind,"core_width":8000.0 if terrain.source_model_index==117 else 4000.0,"core_cells":32 if terrain.source_model_index==117 else 64})
	if not packet.get("ok",false):return packet
	return {"ok":true,"revision":ENTRY_PREPARATION,"context":snapshot.context,"body_id":snapshot.body_id,"site_id":snapshot.site_id,"globe":terrain,"data":prepared.data,"underground":prepared.get("underground"),"render_packet":packet,"render_worker_state":terrain.capture_worker_state(),"ship_position":snapshot.get("ship_position",Vector3.INF),"days":snapshot.get("days",0.0)}
func install_prepared_entry(bundle:Dictionary,system:RefCounted,ship:RefCounted)->bool:
	if active or not source_layout(system) or bundle.get("ok")!=true or bundle.get("revision")!=ENTRY_PREPARATION or bundle.get("context")!=_entry_context(system,ship) or bundle.get("body_id")!=str(system.focus_id) or not bundle.get("globe") is RefCounted or not bundle.get("data") is Dictionary:return false
	if not bundle.get("ship_position") is Vector3 or not bundle.ship_position.is_finite() or bundle.ship_position!=ship.position:return false
	var terrain:RefCounted=bundle.globe
	if not bundle.get("render_packet") is Dictionary or not RenderPacket.valid(bundle.render_packet) or not bundle.get("render_worker_state") is Dictionary:return false
	var site:Dictionary=system.current_site()
	var anchor:=str(site.get("id","")) if int(site.get("type_code",-1))==35 else ""
	if bundle.get("site_id")!=anchor or terrain.get("revision")!=SourceTerrain.REVISION_NAME or terrain.get("configured_ok")!=true or terrain.get("source_record")!=str(system.by_id[system.focus_id].runtime_record_hex).hex_decode():return false
	if not anchor.is_empty():
		if bundle.data.is_empty() or not bundle.data.get("profile") is Dictionary or bundle.data.profile.get("site_id")!=anchor or int(bundle.data.profile.get("model_index",-1))!=int(site.model_index) or bundle.data.profile.get("terrain_revision")!=SourceTerrain.REVISION_NAME:return false
		if int(site.model_index)==96 and (not bundle.get("underground") is RefCounted or not bundle.underground.configured_ok):return false
	_prepared_entry=bundle.duplicate();return true
func has_prepared_entry(system:RefCounted=null,ship:RefCounted=null)->bool:
	if _prepared_entry.is_empty():return false
	return true if system==null or ship==null else _prepared_entry.get("context")==_entry_context(system,ship)
func source_surface()->bool:return globe!=null and globe.revision==SourceTerrain.REVISION_NAME
func source_city()->bool:return globe!=null and globe.revision in [SphereTerrain.CITY_REVISION,SourceTerrain.REVISION_NAME]
func publish_source_render_state(state:RefCounted)->void:
	# An exact source-field LOD can have different interpolated triangles after
	# changing its regional grid. Keep the player's clearance through the
	# atomic visible/collider handoff, including a saved parked ship.
	if active and source_surface() and _source_render_ship!=null and state!=null:
		var point:Vector3=_source_render_ship.position
		var next:Dictionary=state.height_at(globe,point.x,point.z)
		var previous:Dictionary=source_render_state.height_at(globe,point.x,point.z) if source_render_state!=null else {}
		if not next.is_empty():
			var old_height:=float(previous.height) if not previous.is_empty() else (point.y-clearance(_source_render_ship)-_source_render_clearance)
			if is_finite(old_height):
				var correction:=float(next.height)-old_height
				_source_render_ship.position.y+=correction;render_position=_source_render_ship.position
				_render_frame_shift+=Vector3.UP*correction
	source_render_state=state
func consume_render_frame_shift()->Vector3:
	var result:=_render_frame_shift;_render_frame_shift=Vector3.ZERO;return result
func set_source_time(days:float)->bool:
	if not is_finite(days) or days<0 or days>1e9:return false
	_source_days=days;return true
static func make_globe(system:RefCounted,target_body:String,site:String,terrain_revision:String)->RefCounted:
	if not OrbitLink.supports_terrain_revision(terrain_revision,system):return null
	var candidate:RefCounted=SourceTerrain.new() if terrain_revision==SourceTerrain.REVISION_NAME else SphereTerrain.new()
	candidate.configure(system,target_body,site,terrain_revision)
	if terrain_revision==SourceTerrain.REVISION_NAME and not candidate.configured_ok:return null
	return candidate
func _source_gravity_at(system:RefCounted,terrain:RefCounted,x:float,z:float,geoid:float)->Dictionary:
	var up_sq:=pow(float(terrain.radius)+geoid,2)-x*x-z*z
	if up_sq<=0:return {}
	var ll:Array=terrain.coordinates_at_height(x,z,sqrt(up_sq)-float(terrain.radius))
	var point:=OrbitLink.direction(ll[0],ll[1])*(float(terrain.radius)+geoid)
	return system.source_surface_gravity(str(system.focus_id),point,_source_days)
func _refresh_gravity(ship:RefCounted)->bool:
	if not source_surface():gravity_vector=Vector3.DOWN*gravity;return true
	var sample:=_source_gravity_at(_source_system,globe,ship.position.x,ship.position.z,geoid_height(ship))
	if sample.is_empty() or not is_finite(float(sample.get("gravity_mps2",NAN))):return false
	var frame:Basis=OrbitLink.rotation_basis(_source_system,body_id,_source_days)*globe.basis_at(globe.latitude,globe.longitude)
	gravity=float(sample.gravity_mps2);gravity_vector=frame.inverse()*Vector3(sample.acceleration)
	return gravity_vector.is_finite()

func raw_height_at(x: float, z: float) -> float:
	if globe:return globe.raw_height(x,z)
	var phase:=float(seed_value&1023)*0.013
	var relief:=sin(x*0.003+phase)*cos(z*0.0023)*95+sin(z*0.008+x*0.004)*22
	# A flat, marked landing field blends into a deterministic patch of hills.
	return relief*smoothstep(100,420,Vector2(x,z).length())

func height_at(x: float, z: float) -> float:
	if source_surface() and source_render_state!=null:
		var hit:Dictionary=source_render_state.height_at(globe,x,z)
		if not hit.is_empty():return float(hit.height)
	# Exact same diagonal and vertices as the rendered mesh, eliminating hill clipping.
	var cell:=GRID_WIDTH/grid_cells()
	var gx:=(x+GRID_WIDTH/2)/cell;var gz:=(z+GRID_WIDTH/2)/cell
	var ix:=floorf(gx);var iz:=floorf(gz);var fx:=gx-ix;var fz:=gz-iz
	var x0:=ix*cell-GRID_WIDTH/2;var z0:=iz*cell-GRID_WIDTH/2
	var a:=raw_height_at(x0,z0);var b:=raw_height_at(x0+cell,z0);var c:=raw_height_at(x0,z0+cell)
	if fx+fz<=1:return a+(b-a)*fx+(c-a)*fz
	var d:=raw_height_at(x0+cell,z0+cell)
	return d+(c-d)*(1-fx)+(b-d)*(1-fz)

func clearance(ship: RefCounted) -> float:
	return float(ship.profile().visual_span_m)*0.14+2.0

func _grounded_height(ship:RefCounted,x:float,z:float)->float:
	# Native Q31 face vertices round by millimetres relative to the analytic
	# graded plane. A 5-mm separation avoids a stationary CCD penetration.
	var skin:=0.005 if source_city() else 0.0
	return height_at(x,z)+clearance(ship)+skin

func altitude(ship: RefCounted) -> float:
	return ship.position.y-height_at(ship.position.x,ship.position.z)-clearance(ship)

func geoid_height(ship:RefCounted)->float:
	if not globe:return ship.position.y
	if source_surface():return sqrt(float(ship.position.x)*ship.position.x+float(ship.position.z)*ship.position.z+pow(float(globe.radius)+float(ship.position.y),2))-float(globe.radius)
	var angle:=Vector2(ship.position.x,ship.position.z).length()/float(globe.radius)
	return (ship.position.y+2.0*float(globe.radius)*pow(sin(angle*0.5),2))/cos(angle)

func entry_error(ship: RefCounted, system: RefCounted) -> String:
	if active:return "Вы уже у поверхности."
	if not ship.position.is_finite() or not ship.velocity.is_finite() or not ship.attitude.is_finite():return "Невозможно определить положение корабля."
	if ship.hull<=0:return "Корабль потерян."
	if ship.docked:return "Сначала вылетите со станции."
	if ship.combat_active:return "Сначала выйдите из боя."
	if system.transfer_remaining>0:return "Сначала отмените перелёт."
	var body: Dictionary=system.by_id[system.focus_id]
	if source_layout(system) and not body.get("landable",false):return "Для этой модели ещё не восстановлена исходная твёрдая поверхность."
	if str(body.kind) in ["star","barycenter","gas","ice_gas"]:return "У этого объекта нет доступной твёрдой поверхности."
	if ship.velocity.length()>20:return "Затормозите до 20 м/с."
	var g:=G*float(body.mass_solar)*SOLAR_MASS/pow(float(body.radius_km)*1000,2)
	if source_layout(system):
		var terrain:RefCounted=_prepared_entry.globe if has_prepared_entry(system,ship) else make_globe(system,system.focus_id,str(system.site_id),SourceTerrain.REVISION_NAME)
		if terrain==null:return "Не удалось подготовить исходный рельеф."
		var sample:=_source_gravity_at(system,terrain,0,0,terrain.elevation(terrain.latitude,terrain.longitude))
		if sample.is_empty():return "Не удалось определить исходную гравитацию."
		g=float(sample.gravity_mps2)
	if g>ship.acceleration()*0.8:return "Недостаточно тяги для безопасного взлёта при этой гравитации."
	return ""

func enter(ship: RefCounted, system: RefCounted, spherical:=false, terrain_revision:String=SphereTerrain.CURRENT_REVISION) -> bool:
	if spherical and source_layout(system) and terrain_revision==SphereTerrain.CURRENT_REVISION:terrain_revision=SourceTerrain.REVISION_NAME
	message=entry_error(ship,system)
	if message!="":return false
	if spherical and not OrbitLink.supports_terrain_revision(terrain_revision,system):message="Неизвестная ревизия поверхности.";return false
	var body: Dictionary=system.by_id[system.focus_id]
	var site:Dictionary=system.current_site()
	# An orbital station is not a ground anchor. Prepare the spherical entry
	# without its id, but do not change the live orbital frame until success.
	var entry_site_id:String=str(system.site_id)
	if spherical and not site.is_empty() and int(site.get("type_code",-1)) in [32,33,34]:entry_site_id=""
	var candidate_globe:RefCounted=null
	var prepared:Dictionary={"ok":true,"data":{}}
	if spherical:
		var ready_source:bool=terrain_revision==SourceTerrain.REVISION_NAME and has_prepared_entry(system,ship)
		candidate_globe=_prepared_entry.globe if ready_source else make_globe(system,system.focus_id,entry_site_id,terrain_revision)
		if candidate_globe==null:message="Не удалось подготовить исходный рельеф.";return false
		prepared=_prepared_entry if ready_source else _prepare_city(candidate_globe,site,collision_radii(ship))
		if not prepared.ok:message=str(prepared.error);return false
		system.site_id=entry_site_id
	body_id=system.focus_id
	kind=str(body.kind)
	seed_value=system.system_id^body_id.hash()
	site_name=""
	if not site.is_empty() and int(site.type_code)==35:
		seed_value^=str(site.id).hash();site_name=str(site.name)
	orbit_link={}
	extended_flight=false;flight_phase="";ready_for_orbit=false
	globe=candidate_globe;frame_index=0;city_data=prepared.data;underground=prepared.get("underground")
	source_render_packet=prepared.get("render_packet",{});source_render_worker_state=prepared.get("render_worker_state",{});source_render_state=null
	_source_system=system if source_surface() else null
	_source_render_ship=ship if source_surface() else null
	_render_frame_shift=Vector3.ZERO
	_prepared_entry={}
	gravity=G*float(body.mass_solar)*SOLAR_MASS/pow(float(body.radius_km)*1000,2)
	orbit_position=ship.position;orbit_attitude=ship.attitude
	active=true;landed=false;landing=false
	ship.surface_mode=true;ship.station_available=false;ship.autopilot=false
	ship.position=Vector3(0,1500,800)
	if source_city():ship.position.y=height_at(0,800)+clearance(ship)+1500.0
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.assisted=true
	ship.attitude=Quaternion(Vector3.RIGHT,-0.35)
	if globe:recenter(ship)
	if not _refresh_gravity(ship):active=false;ship.surface_mode=false;message="Не удалось определить исходную гравитацию.";return false
	render_position=ship.position
	render_velocity=ship.velocity
	_source_render_clearance=altitude(ship) if source_surface() else NAN
	message="Посадочная зона: %s. «Автопилот» — заход; «Стыковка» — мягкая посадка."%(site_name if not site_name.is_empty() else body.name)
	return true

func _prepare_city(terrain:RefCounted,site:Dictionary,radii:=Vector3(10,4,12))->Dictionary:
	if terrain==null or terrain.revision not in [SphereTerrain.CITY_REVISION,SourceTerrain.REVISION_NAME]:return {"ok":true,"data":{}}
	if site.is_empty() or int(site.get("type_code",-1))!=35:return {"ok":true,"data":{}}
	var model:=int(site.get("model_index",-1))
	if model==96:
		if terrain.revision!=SourceTerrain.REVISION_NAME:return {"ok":false,"error":"Подземный город: вход через шлюз ещё не восстановлен. Выберите другой порт."}
		var controller:=Underground.new()
		if not controller.configure(site,terrain,{},radii):return {"ok":false,"error":"Не удалось подготовить закрытый ангар: "+controller.last_error}
		return {"ok":true,"data":controller.data,"underground":controller}
	if model<81 or model>90:return {"ok":false,"error":"Для этого города ещё не восстановлен безопасный вход."}
	var profile:Dictionary=terrain.city_profiles.get(str(site.id),{})
	if profile.is_empty():return {"ok":false,"error":"Нет проверенных данных исходного города."}
	var prepared:Dictionary=CityRuntime.prepare(profile)
	if not prepared.get("ok",false):return {"ok":false,"error":"Не удалось подготовить исходный город: "+str(prepared.get("error","неизвестная ошибка"))}
	return {"ok":true,"data":prepared}
func bind_city(site:Dictionary)->bool:
	var prepared:=_prepare_city(globe,site)
	if not prepared.ok:message=str(prepared.error);return false
	city_data=prepared.data
	underground=prepared.get("underground")
	return true

func begin_landing(ship: RefCounted) -> bool:
	if not active or landed or ship.hull<=0:return false
	if underground!=null and not landing and str(underground.state.phase) in ["closed","closing"] and not underground.request("dock"):return false
	cancel_vertical()
	taking_off=false
	landing=not landing
	ship.autopilot=false;ship.target_speed=0
	message="Автоматический заход на площадку." if landing else "Заход отменён."
	return true

func step(dt: float, ship: RefCounted, steering: Vector2, roll: float, lift := 0.0) -> void:
	ship.last_propulsive_delta_v=Vector3.ZERO
	if not active or not is_finite(dt) or dt<=0 or ship.hull<=0:return
	if not _refresh_gravity(ship):message="Не удалось обновить исходную гравитацию.";return
	if underground!=null:underground.step_seconds(dt,globe,ship.position,collision_radii(ship),landed)
	if landed:
		if is_finite(lift) and lift>0.1:
			# The visible phone lift control must also work from a healthy landing.
			# Negative lift, steering and throttle alone keep the ship parked.
			if not take_off(ship):return
		else:
			ship.velocity=Vector3.ZERO;ship.target_speed=0
			return
	var previous:Vector3=ship.position
	var previous_velocity:Vector3=ship.velocity
	if not flight_phase.is_empty() and (steering.length()>0.05 or absf(roll)>0.05 or absf(lift)>0.1):cancel_vertical()
	if absf(lift)>0.1:landing=false;taking_off=false
	if not ship.propulsion_available:
		# Empty source thrust limits leave the ship ballistic. Automated descent
		# must not retain its historical minimum 0.1 m/s² powered correction.
		landing=false;taking_off=false;flight_phase="";ready_for_orbit=false;ship.autopilot=false
		ship.step(dt,steering,roll,gravity_vector,lift)
	elif underground!=null and ((landing and str(underground.state.intent)=="dock") or str(underground.state.intent)=="launch"):
		_step_underground_navigation(dt,ship)
	elif not flight_phase.is_empty():
		_step_vertical(dt,ship)
	elif taking_off:
		ship.velocity=ship.velocity.move_toward(Vector3.UP*15,maxf(0.1,ship.acceleration()-gravity)*dt)
		ship.position+=ship.velocity*dt
		if altitude(ship)>=35:taking_off=false;ship.brake()
	elif landing:
		var pad:=pad_position()
		var horizontal:=Vector3(pad.x-ship.position.x,0,pad.z-ship.position.z)
		var height:=maxf(0,ship.position.y-pad.y-clearance(ship))
		var reserve:=maxf(0.1,ship.acceleration()-gravity)
		var desired:=horizontal.normalized()*minf(60,sqrt(horizontal.length()*reserve))
		var cruise:float=maxf(350.0,float(city_data.cruise_height_m)) if not city_data.is_empty() else 200.0
		desired.y=-minf(25,sqrt(maxf(0,height-0.3)*reserve)) if horizontal.length()<40 else clampf((height_at(ship.position.x,ship.position.z)+cruise+clearance(ship)-ship.position.y)*0.1,-20,20)
		var climb_threshold:float=cruise-20.0 if not city_data.is_empty() else 100.0
		if globe and horizontal.length()>40 and altitude(ship)<climb_threshold:
			# Climb above the actual city roofs before crossing the district.
			desired=Vector3.UP*minf(20,sqrt(maxf(0,(cruise if not city_data.is_empty() else 180.0)-altitude(ship))*reserve))
		ship.velocity=ship.velocity.move_toward(desired,reserve*dt)
		ship.attitude=ship.attitude.slerp(Quaternion.IDENTITY,minf(1,dt*1.5)).normalized()
		ship.position+=ship.velocity*dt
	else:
		ship.step(dt,steering,roll,gravity_vector,lift)
	var requested_delta:Vector3=ship.velocity-previous_velocity-gravity_vector*dt
	ship.last_propulsive_delta_v=ship.filter_propulsive_delta(requested_delta)
	var correction:Vector3=ship.last_propulsive_delta_v-requested_delta
	ship.velocity+=correction;ship.position+=correction*dt
	_clip_buildings(previous,ship)
	if ship.hull<=0:return
	var radial:=Vector2(ship.position.x,ship.position.z)
	if not globe and radial.length()>LIMIT:
		var edge:=radial.normalized()*LIMIT
		ship.position.x=edge.x;ship.position.z=edge.y
		ship.velocity.x=0;ship.velocity.z=0
		ship.target_speed=0
		message="Граница посадочного района. Вернитесь к площадке или на орбиту."
	var ceiling:=height_at(ship.position.x,ship.position.z)+clearance(ship)+(MAX_FLIGHT_HEIGHT if extended_flight else 4000.0) if globe else 4000.0
	if ship.position.y>ceiling:
		ship.position.y=ceiling;ship.velocity.y=minf(ship.velocity.y,0);ship.target_speed=0
	if landing and altitude(ship)<=0.6 and ship.velocity.length()<=6 and (not globe or pad_distance(ship)<80):
		ship.position.y=_grounded_height(ship,ship.position.x,ship.position.z)
		ship.velocity=Vector3.ZERO;ship.target_speed=0;landing=false;landed=true
		message="Посадка выполнена. «Взлететь» — подъём над поверхностью."
	if altitude(ship)<=0 and not landed:
		var impact: float=ship.velocity.length()
		ship.position.y=_grounded_height(ship,ship.position.x,ship.position.z)
		ship.velocity=Vector3.ZERO;ship.target_speed=0;landing=false
		if impact>6:
			ship.hull=maxf(0,ship.hull-(impact-6)*3)
			message="Жёсткое касание: %.0f м/с. Проверьте корпус."%impact
		else:message="Посадка выполнена. «Взлететь» — подъём над поверхностью."
		landed=true

	if globe and radial.length()>REBASE_DISTANCE:recenter(ship)
	render_position=ship.position
	render_velocity=ship.velocity
	_source_render_clearance=altitude(ship) if source_surface() else NAN

func touch_down(ship: RefCounted) -> bool:
	if not active or landed or ship.hull<=0 or altitude(ship)>3 or ship.velocity.length()>6:return false
	ship.position.y=_grounded_height(ship,ship.position.x,ship.position.z)
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.attitude=Quaternion.IDENTITY
	landed=true;landing=false
	message="Мягкая посадка выполнена."
	return true

func take_off(ship: RefCounted) -> bool:
	if not active:message="Взлёт доступен после посадки на поверхность.";return false
	if ship.hull<=0:message="Взлёт невозможен: корпус корабля разрушен (0%).";return false
	if not landed:message="Корабль уже находится над поверхностью.";return false
	if ship.source_thrust_limits_u16.size()==6 and int(ship.source_thrust_limits_u16[2])==0:
		message="Подъёмная тяга недоступна. Заправьте реактивный бак из груза через «Оснащение».";return false
	if underground!=null and str(underground.state.phase)=="docked":
		if not underground.request("launch"):return false
		landed=false;landing=false;taking_off=false;flight_phase="";ready_for_orbit=false;ship.autopilot=false
		ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.assisted=true
		message="Открываем шлюз ангара для вылета.";return true
	landed=false;landing=false;taking_off=true
	flight_phase="";ready_for_orbit=false;ship.autopilot=false
	ship.position.y+=0.3
	ship.velocity=Vector3.UP
	ship.attitude=Quaternion(Vector3.RIGHT,0.35)
	ship.assisted=true;ship.target_speed=0
	message="Взлёт. Поднимитесь выше 500 м, затем нажмите «На орбиту»."
	return true

func _step_underground_navigation(dt:float,ship:RefCounted)->void:
	var route:Dictionary=underground.current_route(globe,collision_radii(ship))
	if route.is_empty():landing=false;return
	var phase:=str(underground.state.phase)
	var launching:=str(underground.state.intent)=="launch"
	var target:Vector3=route.interior_local_m if launching and phase=="opening" else route.entrance_local_m
	var horizontal:=Vector2(target.x-ship.position.x,target.z-ship.position.z).length()
	if not launching and phase in ["approach","inside"] and horizontal<2.0:target=route.interior_local_m
	elif not launching and horizontal>20.0:target.y=height_at(ship.position.x,ship.position.z)+clearance(ship)+maxf(350.0,float(city_data.get("cruise_height_m",350.0)))
	var offset:Vector3=target-ship.position
	var reserve:=maxf(0.1,ship.acceleration()-gravity)
	var speed:=minf(20.0,sqrt(maxf(0.0,2.0*reserve*offset.length()))*0.5)
	if offset.length()<1.0:speed=minf(speed,0.5)
	ship.velocity=ship.velocity.move_toward(offset.normalized()*speed,reserve*dt)
	ship.attitude=ship.attitude.slerp(Quaternion.IDENTITY,minf(1.0,dt*1.5)).normalized()
	ship.position+=ship.velocity*dt

func prepare_underground_geometry()->Dictionary:
	return {} if underground==null or not underground.dirty else underground.prepare_pending()
func publish_underground_geometry(bundle:Dictionary,ship:RefCounted)->bool:
	if underground==null or not underground.publish_prepared(bundle,globe,ship.position,collision_radii(ship)):return false
	city_data=underground.data
	return true
func prepare_underground_update()->Dictionary:return prepare_underground_geometry()
func publish_underground_update(bundle:Dictionary,ship:RefCounted)->bool:return publish_underground_geometry(bundle,ship)

func leave(ship: RefCounted,system:RefCounted=null,days:=0.0) -> bool:
	if not active or landed or ship.hull<=0 or altitude(ship)<500 or ship.velocity.length()>20:
		message="Для выхода на орбиту: высота от 500 м, скорость до 20 м/с."
		return false
	if globe and system:
		# Older active spherical saves could retain the station selected before
		# descent. Drop that orbit-only anchor before creating the ground link.
		var site:Dictionary=system.current_site()
		if not site.is_empty() and int(site.get("type_code",-1)) in [32,33,34]:system.site_id=""
		orbit_link=OrbitLink.make(self,ship,system,days)
		var ll:Array=geographic_position(ship)
		var world_basis:Basis=OrbitLink.rotation_basis(system,body_id,days)*globe.basis_at(globe.latitude,globe.longitude)
		ship.attitude=(world_basis.get_rotation_quaternion()*ship.attitude).normalized()
		var terrain_elevation:float=globe.elevation(ll[0],ll[1]) if source_surface() else 0.0
		var height:float=clampf(geoid_height(ship)-terrain_elevation,OrbitLink.ALTITUDE,MAX_FLIGHT_HEIGHT)+terrain_elevation if extended_flight else OrbitLink.ALTITUDE+terrain_elevation
		# Keep the v2 record as its original 20-km geographic reference. Higher
		# departures retain their real position, so re-entry uses the radial path.
		if height>OrbitLink.ALTITUDE+terrain_elevation:
			var radial:Vector3=OrbitLink.rotation_basis(system,body_id,days)*OrbitLink.direction(ll[0],ll[1])
			ship.position=system.local_meters(body_id,days)+radial*(float(globe.radius)+height)
		else:ship.position=Vector3(orbit_link.position[0],orbit_link.position[1],orbit_link.position[2])
	else:
		ship.position=orbit_position;ship.attitude=orbit_attitude
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.autopilot=false;ship.surface_mode=false
	active=false;landing=false;taking_off=false;flight_phase="";ready_for_orbit=false
	_source_render_ship=null;_source_render_clearance=NAN
	_render_frame_shift=Vector3.ZERO
	message="Возврат в орбитальную зону."
	return true

func snapshot() -> Dictionary:
	var state:Dictionary={"version":3,"active":active,"landed":landed,"body_id":body_id,"orbit_position":[orbit_position.x,orbit_position.y,orbit_position.z],"orbit_attitude":[orbit_attitude.x,orbit_attitude.y,orbit_attitude.z,orbit_attitude.w]}

	if active and globe:
		state.version=4;state.layout="globe_v1";state.terrain_revision=globe.revision
		state.latitude=globe.latitude;state.longitude=globe.longitude
		if underground!=null:state.underground=underground.snapshot()
		if source_surface() and source_render_state!=null and _source_render_ship!=null and source_render_state.has_method("contact_patch"):
			var patch:Dictionary=source_render_state.contact_patch(globe,_source_render_ship.position.x,_source_render_ship.position.z)
			if not patch.is_empty():state.terrain_contact=patch
	if active and extended_flight:state.version=6;state.flight_phase=flight_phase
	if not active and not orbit_link.is_empty():state.version=5;state.orbit_link=orbit_link.duplicate(true)
	return state

func restore(data: Dictionary, ship: RefCounted, system: RefCounted) -> bool:
	if data.get("version",0)==6:
		if not data.get("flight_phase") is String or data.flight_phase not in ["","ascent","descent"]:return false
		if data.get("landed")==true and not data.flight_phase.is_empty():return false
		if not data.flight_phase.is_empty() and (ship.velocity.length()>301 or not ship.assisted or absf(ship.target_speed)>0.01):return false
		if not _restore_globe(data,ship,system,MAX_FLIGHT_HEIGHT+1):return false
		extended_flight=true;flight_phase=data.flight_phase
		return true
	if data.get("version",0)==5:
		if not data.get("active") is bool or not data.get("landed") is bool or data.active or data.landed or data.get("body_id")!=system.focus_id or not OrbitLink.valid(data.get("orbit_link"),system):return false
		var old:=data.duplicate(true);old.version=3;old.erase("orbit_link")
		var candidate:RefCounted=get_script().new()
		if not candidate.restore(old,ship,system):return false
		if not restore(old,ship,system):return false
		orbit_link=data.orbit_link.duplicate(true)
		return true
	if data.get("version",0)==4:
		if data.has("flight_phase"):return false
		return _restore_globe(data,ship,system)
	if data.has("terrain_revision") or data.has("layout"):return false
	if (data.get("version",0)!=1 and data.get("version",0)!=2 and data.get("version",0)!=3) or not data.get("active") is bool or not data.get("landed") is bool:return false
	for key in ["orbit_position","orbit_attitude"]:
		var values: Variant=data.get(key)
		if not values is Array or values.size()!=(4 if key=="orbit_attitude" else 3):return false
		for value in values:
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>1e9:return false
	var rotation:=Quaternion(data.orbit_attitude[0],data.orbit_attitude[1],data.orbit_attitude[2],data.orbit_attitude[3])
	if rotation.length_squared()<0.01:return false
	if data.active:
		if data.get("body_id","")!=system.focus_id or ship.docked:return false
		if str(system.by_id[system.focus_id].kind) in ["gas","ice_gas","star","barycenter"]:return false
		if Vector2(ship.position.x,ship.position.z).length()>LIMIT+1 or ship.position.y>4001 or ship.position.y< -200:return false
		var candidate: RefCounted=get_script().new()
		candidate.seed_value=system.system_id^system.focus_id.hash()
		if not system.site_id.is_empty():candidate.seed_value^=system.site_id.hash()
		var site:Dictionary=system.current_site()
		if not site.is_empty() and int(site.type_code)==35:candidate.site_name=str(site.name)
		if data.version==3 and candidate.overlaps_building(ship):return false
		var altitude_now: float=candidate.altitude(ship)
		if data.get("version",0)==1:altitude_now=ship.position.y-candidate.raw_height_at(ship.position.x,ship.position.z)-candidate.clearance(ship)
		if altitude_now < -1 or (data.landed and (absf(altitude_now)>1 or ship.velocity.length()>0.1)):return false
	elif data.landed:return false
	orbit_link={}
	extended_flight=false;flight_phase="";ready_for_orbit=false
	globe=null;city_data={};underground=null;source_render_packet={};source_render_worker_state={};source_render_state=null;_source_system=null;_source_render_ship=null;_source_render_clearance=NAN;frame_index=0
	site_name=""
	active=data.active;landed=data.landed;landing=false;body_id=str(data.get("body_id",""))
	orbit_position=Vector3(data.orbit_position[0],data.orbit_position[1],data.orbit_position[2]);orbit_attitude=rotation.normalized()
	if active:
		var body: Dictionary=system.by_id[system.focus_id]
		kind=str(body.kind);seed_value=system.system_id^body_id.hash()
		site_name=""
		var site:Dictionary=system.current_site()
		if not site.is_empty() and int(site.type_code)==35:seed_value^=str(site.id).hash();site_name=str(site.name)
		gravity=G*float(body.mass_solar)*SOLAR_MASS/pow(float(body.radius_km)*1000,2)
	taking_off=false
	if active and data.get("version",0)==1:
		ship.position.y=maxf(ship.position.y,height_at(ship.position.x,ship.position.z)+clearance(ship))
		if landed:ship.position.y=height_at(ship.position.x,ship.position.z)+clearance(ship)
	if active and data.version!=3 and overlaps_building(ship):
		evacuate_building(ship);landed=false
		message="Старое сохранение: корабль безопасно поднят над зданием. Прогресс и корпус сохранены."
	ship.surface_mode=active
	return true

func buildings()->Array[AABB]:
	var result:Array[AABB]=[]
	if site_name.is_empty() or (source_city()):return result
	var pad:=pad_position()
	if globe and Vector2(pad.x,pad.z).length()>GRID_WIDTH:return result
	for i in range(10):
		var height:=20.0+float((seed_value+i*53)&63)
		var x:=float(-180 if i<5 else 180);var z:=float((i%5)*130-260)
		x+=pad.x;z+=pad.z
		result.append(AABB(Vector3(x-16,height_at(x,z),z-20),Vector3(32,height,40)))
	return result
func collision_radius(ship:RefCounted)->float:return float(ship.profile().visual_span_m)*0.55
func collision_radii(ship:RefCounted)->Vector3:
	var span:float=ship.profile().visual_span_m
	return Vector3(span*0.55,clearance(ship),span*0.55)
func overlaps_building(ship:RefCounted)->bool:
	if source_city():
		return false if city_data.is_empty() else CityRuntime.overlaps(city_data,globe,ship.position,collision_radii(ship))
	for box in buildings():
		if box.grow(collision_radius(ship)-0.02).has_point(ship.position):return true
	return false
func evacuate_building(ship:RefCounted)->void:
	if source_city():
		if not city_data.is_empty():ship.position.y=height_at(ship.position.x,ship.position.z)+clearance(ship)+maxf(350.0,float(city_data.cruise_height_m))
		ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.autopilot=false
		return
	for box in buildings():
		var expanded:AABB=box.grow(collision_radius(ship))
		if expanded.has_point(ship.position):ship.position.y=expanded.end.y+0.05
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.autopilot=false
func _clip_buildings(previous:Vector3,ship:RefCounted)->void:
	if source_city():
		_clip_source_city(previous,ship)
		return
	var best:Dictionary={};var first:=2.0
	for box in buildings():
		var expanded:AABB=box.grow(collision_radius(ship))
		var contact:=SegmentBox.intersect(previous,ship.position,expanded)
		if not contact.is_empty() and float(contact.time)<first:
			best=contact;first=float(contact.time)
			if contact.inside:best.position=Vector3(previous.x,expanded.end.y+0.05,previous.z)
	if best.is_empty():return
	ship.position=Vector3(best.position)+Vector3(best.normal)*0.05
	var inward:float=ship.velocity.dot(best.normal)
	if inward<0:
		ship.hull=maxf(0,ship.hull-maxf(0,-inward-6)*2)
		ship.velocity-=Vector3(best.normal)*inward
	ship.brake();landing=false;taking_off=false
	message="Столкновение со зданием. Снизьте скорость и отойдите от фасада."

# Original city faces and the terrain share a graded plane. A floor hit must
# complete touchdown once; wall/roof hits remain ordinary collision responses.
func _clip_source_city(previous:Vector3,ship:RefCounted)->void:
	if city_data.is_empty():return
	var radii:=collision_radii(ship)
	var contact:Dictionary=CityRuntime.sweep(city_data,globe,previous,ship.position,radii)
	if contact.is_empty():return
	var ground:=height_at(contact.position.x,contact.position.z)
	var floor_contact:bool=contact.normal.dot(Vector3.UP)>0.9 and absf(float(contact.position.y)-radii.y-ground)<=0.25
	if floor_contact:
		var impact:float=ship.velocity.length()
		ship.position=Vector3(contact.position.x,_grounded_height(ship,contact.position.x,contact.position.z),contact.position.z)
		ship.velocity=Vector3.ZERO;ship.target_speed=0;landing=false;taking_off=false;landed=true
		flight_phase="";ready_for_orbit=false
		if impact>6:
			ship.hull=maxf(0,ship.hull-(impact-6)*3)
			message="Жёсткое касание: %.0f м/с. Проверьте корпус."%impact
		else:message="Посадка выполнена. «Взлететь» — подъём над поверхностью."
		return
	ship.position=Vector3(contact.position)+Vector3(contact.normal)*0.05
	var inward:float=ship.velocity.dot(contact.normal)
	if inward<0:
		ship.hull=maxf(0,ship.hull-maxf(0,-inward-6)*2)
		ship.velocity-=Vector3(contact.normal)*inward
	ship.brake();landing=false;taking_off=false;flight_phase="";ready_for_orbit=false
	message="Столкновение со зданием. Снизьте скорость и отойдите от фасада."

func grid_cells()->int:return 64 if globe else GRID_CELLS

func terrain_key()->String:
	return str(seed_value)+":"+kind+":"+site_name+(":globe:"+str(globe.get_instance_id())+":"+globe.revision+":"+str(frame_index)+(":high" if extended_flight else "") if globe else ":local")
func pad_position()->Vector3:
	if not globe:return Vector3.ZERO
	if source_city() and not city_data.is_empty():
		var pad:Vector3=CityRuntime.transform_to_frame(city_data.profile,globe)*Vector3(city_data.profile.pad_offset_local_m)
		return Vector3(pad.x,height_at(pad.x,pad.z) if Vector2(pad.x,pad.z).length()<GRID_WIDTH*1.5 else height_at(0,0),pad.z)
	var p:Vector2=globe.project(globe.pad_latitude,globe.pad_longitude)
	# Far-side ports are navigation targets, not rendered through the planet.
	return Vector3(p.x,height_at(p.x,p.y) if p.length()<GRID_WIDTH*1.5 else height_at(0,0),p.y)
func geographic_position(ship:RefCounted)->Array:
	if source_surface():return globe.coordinates_at_height(ship.position.x,ship.position.z,ship.position.y)
	return globe.coordinates(ship.position.x,ship.position.z) if globe else []
func pad_distance(ship:RefCounted)->float:
	if not globe:return Vector2(ship.position.x,ship.position.z).length()
	var ll:=geographic_position(ship)
	var saved_lat:float=globe.latitude;var saved_lon:float=globe.longitude
	globe.latitude=ll[0];globe.longitude=ll[1]
	var result:float=globe.distance_to(globe.pad_latitude,globe.pad_longitude)
	globe.latitude=saved_lat;globe.longitude=saved_lon
	return result
func recenter(ship:RefCounted)->void:
	if not globe:return
	var altitude_now:=altitude(ship)
	var source_height:=sqrt(float(ship.position.x)*ship.position.x+float(ship.position.z)*ship.position.z+pow(float(globe.radius)+float(ship.position.y),2))-float(globe.radius) if source_surface() else 0.0
	var ll: Array=geographic_position(ship)
	var old_basis:Basis=globe.basis_at(globe.latitude,globe.longitude)
	var next_basis:Basis=globe.basis_at(ll[0],ll[1])
	frame_rotation=(next_basis.transposed()*old_basis).get_rotation_quaternion().normalized()
	rebase_from=ship.position
	globe.latitude=ll[0];globe.longitude=ll[1];frame_index+=1
	ship.position=Vector3(0,source_height if source_surface() else height_at(0,0)+clearance(ship)+altitude_now,0)
	ship.velocity=frame_rotation*ship.velocity
	ship.attitude=(frame_rotation*ship.attitude).normalized()
	rebase_to=ship.position
	render_position=ship.position
	render_velocity=ship.velocity
func _restore_globe(data:Dictionary,ship:RefCounted,system:RefCounted,maximum_height:=4001.0)->bool:
	if data.get("layout")!="globe_v1" or not OrbitLink.supports_terrain_revision(data.get("terrain_revision"),system):return false
	if not data.get("active") is bool or not data.active or not data.get("landed") is bool or data.get("body_id")!=system.focus_id:return false
	if ship.docked or str(system.by_id[system.focus_id].kind) in ["gas","ice_gas","star","barycenter"]:return false
	for key in ["latitude","longitude"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):return false
	if absf(float(data.latitude))>PI*0.5 or float(data.longitude)< -PI or float(data.longitude)>PI:return false
	for key in ["orbit_position","orbit_attitude"]:
		if not data.get(key) is Array or data[key].size()!=(4 if key=="orbit_attitude" else 3):return false
		for value in data[key]:
			if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value))>1e9:return false
	var rotation:=Quaternion(data.orbit_attitude[0],data.orbit_attitude[1],data.orbit_attitude[2],data.orbit_attitude[3])
	if rotation.length_squared()<0.01 or not ship.position.is_finite() or not ship.velocity.is_finite():return false
	if Vector2(ship.position.x,ship.position.z).length()>REBASE_DISTANCE+20:return false
	var candidate:RefCounted=get_script().new()
	candidate.globe=make_globe(system,system.focus_id,system.site_id,str(data.terrain_revision))
	if candidate.globe==null:return false
	var prepared:Dictionary=candidate._prepare_city(candidate.globe,system.current_site(),candidate.collision_radii(ship))
	if not prepared.ok:return false
	candidate.city_data=prepared.data
	candidate.underground=prepared.get("underground")
	if data.has("underground"):
		if candidate.underground==null or not data.underground is Dictionary:return false
		if not candidate.underground.configure(system.current_site(),candidate.globe,data.underground,candidate.collision_radii(ship)):return false
		candidate.city_data=candidate.underground.data
	elif candidate.underground!=null:return false
	candidate.globe.latitude=float(data.latitude);candidate.globe.longitude=float(data.longitude)
	if data.has("terrain_contact"):
		if not candidate.source_surface() or not data.terrain_contact is Dictionary:return false
		var contact_script:Variant=load("res://scripts/source_surface_contact_patch.gd")
		if contact_script==null:return false
		var contact:RefCounted=contact_script.new()
		if not contact.configure(data.terrain_contact,candidate.globe):return false
		candidate.source_render_state=contact
	candidate.seed_value=system.system_id^system.focus_id.hash()
	var site:Dictionary=system.current_site()
	if not site.is_empty() and int(site.type_code)==35:
		candidate.site_name=str(site.name);candidate.seed_value^=system.site_id.hash()
	var height:float=candidate.altitude(ship)
	if height< -1 or height>maximum_height or candidate.overlaps_building(ship):return false
	if data.landed and (absf(height)>1 or ship.velocity.length()>0.1):return false
	candidate.body_id=system.focus_id;candidate._source_system=system;candidate._source_days=_source_days
	candidate.gravity=G*float(system.by_id[system.focus_id].mass_solar)*SOLAR_MASS/pow(float(system.by_id[system.focus_id].radius_km)*1000,2)
	if not candidate._refresh_gravity(ship):return false
	orbit_link={}
	extended_flight=false;flight_phase="";ready_for_orbit=false
	globe=candidate.globe;seed_value=candidate.seed_value;site_name=candidate.site_name;city_data=candidate.city_data;underground=candidate.underground
	source_render_packet={};source_render_worker_state={};source_render_state=candidate.source_render_state
	_source_system=system if source_surface() else null
	_source_render_ship=ship if source_surface() else null
	_render_frame_shift=Vector3.ZERO
	frame_index=0;active=true;landed=data.landed;landing=false;taking_off=false;body_id=system.focus_id
	kind=str(system.by_id[body_id].kind)
	gravity=candidate.gravity;gravity_vector=candidate.gravity_vector
	orbit_position=Vector3(data.orbit_position[0],data.orbit_position[1],data.orbit_position[2]);orbit_attitude=rotation.normalized()
	ship.surface_mode=true
	render_position=ship.position
	render_velocity=ship.velocity
	_source_render_clearance=altitude(ship) if source_surface() else NAN
	return true

func enter_from_orbit(ship:RefCounted,system:RefCounted,days:float)->bool:
	set_source_time(days)
	if not OrbitLink.matches(orbit_link,system):return enter(ship,system,true)
	message=entry_error(ship,system)
	if not message.is_empty():return false
	var ll:Array=OrbitLink.coordinates(orbit_link,ship,system,days)
	if ll.is_empty():message="Невозможно определить точку входа над планетой.";return false
	var anchor:String=orbit_link.site_id
	var terrain_revision:String=OrbitLink.terrain_revision(orbit_link)
	var previous_site:String=system.site_id
	system.site_id=anchor
	if not enter(ship,system,true,terrain_revision):system.site_id=previous_site;return false
	globe.latitude=ll[0];globe.longitude=ll[1];frame_index+=1
	ship.position=Vector3(0,height_at(0,0)+clearance(ship)+1500,0)
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.attitude=Quaternion(Vector3.RIGHT,-0.35)
	message="Вход над текущей точкой планеты. До исходной площадки %.1f км."%(pad_distance(ship)/1000.0)
	return true

func cancel_vertical()->void:
	if not flight_phase.is_empty():message="Вертикальный автополёт отменён. Торможение доступно отдельной кнопкой."
	flight_phase="";ready_for_orbit=false
func begin_departure(ship:RefCounted)->bool:
	# Automatic departure reuses the existing saved ascent phase. The ordinary
	# take_off command remains a short lift; this command continues to orbit.
	if not active or globe==null:
		message="Для этой посадки используйте «Взлететь», затем наберите высоту для выхода на орбиту."
		return false
	if not is_finite(ship.hull) or ship.hull<=0 or ship.hull>100 or ship.docked or ship.combat_active:
		message="Автовылет недоступен в текущем состоянии корабля.";return false
	if not ship.position.is_finite() or not ship.velocity.is_finite() or not ship.attitude.is_finite() or ship.attitude.length_squared()<0.0001 or not is_finite(ship.target_speed) or ship.velocity.length()>20:
		message="Для автовылета остановитесь до 20 м/с.";return false
	var thrust:float=ship.available_acceleration(Vector3.UP)
	if not is_finite(gravity) or gravity<0 or not is_finite(thrust) or thrust<=0 or gravity>thrust*0.8:
		message="Недостаточно тяги для безопасного автовылета при этой гравитации.";return false
	var height:float=altitude(ship)
	if not is_finite(height) or height< -1 or height>MAX_FLIGHT_HEIGHT or overlaps_building(ship):
		message="Для автовылета отойдите от здания и освободите путь над кораблём.";return false
	if not _departure_column_clear(ship):
		message="Путь вверх перекрыт зданием. Сначала перелетите на свободный участок.";return false
	if landed and not take_off(ship):return false
	_engage_ascent(ship)
	message="Автовылет на орбиту. «Тормозить» или ручное управление отменяют подъём."
	return true
func _departure_column_clear(ship:RefCounted)->bool:
	if underground!=null and str(underground.state.phase)=="docked":return not underground.current_route(globe,collision_radii(ship)).is_empty()
	# Use the same ellipsoid/triangle and box tests as live flight. A 0.3-m
	# start separation matches take_off; no position or collision data is changed.
	var start:Vector3=ship.position+Vector3.UP*0.3 if landed else ship.position
	var climb:float=maxf(1000.0,float(city_data.get("cruise_height_m",350.0))+100.0)
	var end:Vector3=start+Vector3.UP*climb
	if source_city():
		return city_data.is_empty() or CityRuntime.sweep(city_data,globe,start,end,collision_radii(ship)).is_empty()
	for box in buildings():
		if not SegmentBox.intersect(start,end,box.grow(collision_radius(ship))).is_empty():return false
	return true
func _engage_ascent(ship:RefCounted)->void:
	extended_flight=true;flight_phase="ascent";ready_for_orbit=false;landing=false;taking_off=false
	ship.assisted=true;ship.target_speed=0;ship.autopilot=false
func begin_ascent(ship:RefCounted)->bool:
	if not active or not globe or landed or ship.hull<=0 or altitude(ship)<500 or ship.velocity.length()>20:
		message="Для автоподъёма: высота от 500 м, скорость до 20 м/с."
		return false
	_engage_ascent(ship)
	message="Автоподъём к 20 км. «Тормозить» или ручное управление отменяют подъём."
	return true
func begin_descent(ship:RefCounted,system:RefCounted,days:float)->bool:
	if not is_finite(days):message="Невозможно определить время входа.";return false
	set_source_time(days)
	message=entry_error(ship,system)
	if not message.is_empty():return false
	var linked:=OrbitLink.matches(orbit_link,system)
	var height:float=ship.position.distance_to(system.local_meters(system.focus_id,days))-float(system.by_id[system.focus_id].radius_km)*1000.0
	var source_terrain:RefCounted=null
	if source_layout(system):
		source_terrain=_prepared_entry.globe if has_prepared_entry(system,ship) else make_globe(system,system.focus_id,str(system.site_id),SourceTerrain.REVISION_NAME)
		var source_ll:=OrbitLink.coordinates(orbit_link,ship,system,days)
		if source_terrain==null or source_ll.is_empty():message="Не удалось определить исходную поверхность.";return false
		height-=source_terrain.elevation(source_ll[0],source_ll[1])
	# Distant, previously unlinked district visits retain the existing fast approach.
	# Nearby first arrivals use the same physical geographic descent as return flights.
	if not linked and height>MAX_DESCENT_HEIGHT:return enter(ship,system,true)
	if height>MAX_DESCENT_HEIGHT or height<MIN_DESCENT_HEIGHT:
		message="Для автоспуска подойдите на высоту от 1,8 до 60 км над планетой."
		return false
	var ll:Array=OrbitLink.coordinates(orbit_link,ship,system,days)
	if ll.is_empty():message="Невозможно определить точку входа над планетой.";return false
	var anchor:String=OrbitLink.anchor(orbit_link,system)
	var terrain_revision:String=OrbitLink.terrain_revision(orbit_link) if linked else preferred_terrain_revision(system)
	var velocity:Vector3=ship.velocity
	var attitude:Quaternion=ship.attitude
	var previous_site:String=system.site_id
	system.site_id=anchor
	if not enter(ship,system,true,terrain_revision):system.site_id=previous_site;return false
	globe.latitude=ll[0];globe.longitude=ll[1];frame_index+=1
	var world_basis:Basis=OrbitLink.rotation_basis(system,body_id,days)*globe.basis_at(ll[0],ll[1])
	ship.position=Vector3(0,height+(globe.elevation(ll[0],ll[1]) if source_surface() else 0.0),0)
	ship.velocity=world_basis.inverse()*velocity
	ship.attitude=(world_basis.inverse()*Basis(attitude)).get_rotation_quaternion().normalized()
	extended_flight=true;flight_phase="descent"
	message="Управляемый спуск к высоте 1500 м. «Тормозить» отменяет спуск."
	return true
func resume_descent(ship:RefCounted)->bool:
	if not active or not globe or landed or ship.hull<=0:return false
	extended_flight=true;flight_phase="descent";ready_for_orbit=false;landing=false;taking_off=false
	ship.assisted=true;ship.target_speed=0;ship.autopilot=false
	message="Управляемое снижение к 1500 м."
	return true
func _step_vertical(dt:float,ship:RefCounted)->void:
	var height:=altitude(ship)
	var target:=1500.0
	if flight_phase=="ascent":
		var ll:Array=geographic_position(ship)
		target=OrbitLink.ALTITUDE-clearance(ship) if source_surface() else OrbitLink.ALTITUDE-globe.elevation(ll[0],ll[1])-clearance(ship)
	var error:=target-height
	var reserve:=maxf(0.1,ship.acceleration()-gravity)
	var speed:=minf(300.0,sqrt(2.0*reserve*absf(error))*0.65)
	ship.velocity=ship.velocity.move_toward(Vector3.UP*signf(error)*speed,reserve*dt)
	ship.attitude=ship.attitude.slerp(Quaternion(Vector3.RIGHT,0.15 if flight_phase=="ascent" else -0.35),minf(1,dt)).normalized()
	ship.position+=ship.velocity*dt
	if absf(error)<0.6 and ship.velocity.length()<2:
		ship.position.y=height_at(ship.position.x,ship.position.z)+clearance(ship)+target
		ship.velocity=Vector3.ZERO
		if flight_phase=="ascent":ready_for_orbit=true
		else:
			flight_phase="";message="Спуск завершён. Можно лететь вручную или включить автопосадку."
