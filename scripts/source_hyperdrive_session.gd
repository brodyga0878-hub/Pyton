extends RefCounted
# Source hardware/inventory with an explicit bridge to the prototype cargo.
# F903 always reads the unchanged source hull spec; carried mass is capacity only.
const Kernel=preload("res://scripts/source_hyperdrive.gd")
const Jet=preload("res://scripts/source_jet_fuel.gd")
const Scoop=preload("res://scripts/source_fuel_scoop.gd")
const Motion=preload("res://scripts/source_motion_pipeline.gd")
const Thermal=preload("res://scripts/source_atmospheric_dynamics.gd")
const ThermalContact=preload("res://scripts/source_atmosphere_contact.gd")
const SCHEMA:="starfrontier-source-hyperdrive-session-v1"
const FUEL_PROFILE:="source-f903-hydrogen-military-v1"
const PRICING:="basic-source-workshop-pricing-adapter-v1"
const MAX_QUANTITY:=65535
const FUEL_SCHEMA:="starfrontier-source-jetfuel-session-v1"
const HOST_FUEL_POLICY:="nominal-day-si-player-f152-49710-cadence-v1"
const PLAYER_UPDATE_TICKS:=49710
const FUEL_KEYS:=["schema","version","source_digest","initialization_policy","jet_raw_u32","disabled_axes_mask_u8","refueller_installed","refueller_enabled","scoop_installed","atmospheric_shielding_installed","status_u16","cooldown_u32","heat_s32","ticks_fraction_f64_hex","jet_update_remainder_raw","last_scoop_reason","thermal_destruction_requested"]
const SCOOP_REASONS:=["not_evaluated","outside_atmosphere","ineligible_parent_model","too_high","too_slow","cooldown","scooped","cargo_full","no_scoop"]
const THERMAL_SCHEMA:="starfrontier-source-thermal-session-v1"
const THERMAL_DATA_PATH:="res://data/ffe_atmosphere.json"
const THERMAL_HOST_POLICY:="nominal-day-si-fixed60-combined-source-thermal-v1"
const THERMAL_HZ:=60
const THERMAL_TICK_DENOMINATOR:=86400*THERMAL_HZ
const MAX_THERMAL_STEPS:=256
const THERMAL_KEYS:=["schema","version","source_contract","source_sha256","source_digest","host_policy","initialization_policy","phase_f64_hex","frame_tick_remainder_raw","tick_fraction_anchor_f64_hex","full_hull_u16","hull_anchor_raw_u16","hull_anchor_percent_f64_hex","hull_u16","shield_max_u16","shield_u16","damage_timer_u8","damage_flags_u8","rng_seed_a_u32","rng_seed_b_u32","destroyed","last_atmosphere_active","last_drag_active","last_hull_damage_u16","last_shield_damage_u16","equipment_damage_requested","wind_flags_u8"]
static var _resource:Dictionary={}
static var _resource_mutex:=Mutex.new()
static var _resource_digest:=""
static var _fuel_resource:Dictionary={}
static var _fuel_resource_mutex:=Mutex.new()
static var _fuel_resource_digest:=""
static var _thermal_resource_digest:=""
var ship_id:=""
var model_index:=-1
var drive_index:=0
var hydrogen:=0
var military:=0
var radioactives:=0
var fixed_equipment_space_t:=0
var adapted_cargo_t:=0
var adapted_equipment_space_t:=0
var fuel_system:Dictionary={}
var fuel_extension_upgraded:=false # Transient notification; never a saved privilege.
var thermal_system:Dictionary={}
var thermal_extension_upgraded:=false
var _thermal_initialization_policy:="source-new-profile-hull-anchor-v1"

static func _number(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _data()->Dictionary:
	# Map workers repeatedly validate copied sessions. Keep one private immutable
	# resource copy instead of duplicating all extraction metadata per drive row.
	_resource_mutex.lock()
	if _resource.is_empty():_resource=Kernel.resource()
	var result:=_resource
	_resource_mutex.unlock();return result
static func _definition(id:String)->Dictionary:
	var data:=_data();var profiles:Variant=data.get("new_session_profiles",{})
	var value:Variant=profiles.get(id) if profiles is Dictionary else null
	return value.duplicate(true) if value is Dictionary else {}
static func _digest()->String:
	_resource_mutex.lock()
	if _resource_digest.is_empty():_resource_digest=FileAccess.get_sha256(Kernel.DATA_PATH)
	var result:=_resource_digest
	_resource_mutex.unlock();return result
static func _fuel_digest()->String:
	_fuel_resource_mutex.lock()
	if _fuel_resource_digest.is_empty():_fuel_resource_digest=FileAccess.get_sha256(Jet.DATA_PATH)
	var result:=_fuel_resource_digest
	_fuel_resource_mutex.unlock();return result
static func _thermal_digest()->String:
	_fuel_resource_mutex.lock()
	if _thermal_resource_digest.is_empty():_thermal_resource_digest=FileAccess.get_sha256(THERMAL_DATA_PATH)
	var result:=_thermal_resource_digest
	_fuel_resource_mutex.unlock();return result
static func _float_hex(value:float)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()
static func _fraction(value:Variant)->float:
	if not value is String or value.length()!=16:return -1.0
	for character:String in value:
		if not character in "0123456789abcdef":return -1.0
	var number:float=value.hex_decode().decode_double(0)
	return number if is_finite(number) and number>=0 and number<1 else -1.0
static func _finite_hex(value:Variant)->float:
	if not value is String or value.length()!=16:return NAN
	for character:String in value:
		if not character in "0123456789abcdef":return NAN
	var number:float=value.hex_decode().decode_double(0)
	return number if is_finite(number) else NAN
static func _fuel_data()->Dictionary:
	_fuel_resource_mutex.lock()
	if _fuel_resource.is_empty() and FileAccess.file_exists(Jet.DATA_PATH):
		var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(Jet.DATA_PATH))
		if data is Dictionary and data.get("schema")==1 and data.get("source_sha256")==Kernel.SOURCE_SHA:_fuel_resource=data
	var result:=_fuel_resource
	_fuel_resource_mutex.unlock();return result
static func equipment_definition(id:String)->Dictionary:
	var equipment:Variant=_fuel_data().get("equipment",{})
	var item:Variant=equipment.get(id) if equipment is Dictionary else null
	return item.duplicate(true) if item is Dictionary else {}
static func equipment_mass(id:String)->int:
	var item:=equipment_definition(id)
	return int(item.mass_tonnes_u32) if _number(item.get("mass_tonnes_u32"),0,MAX_QUANTITY) else -1
func _initialize_fuel(policy:String)->bool:
	var definition:=_definition(ship_id);var raw:Variant=definition.get("source_jetfuel_raw_u32")
	if raw==null:raw=0 # Explicit bare Shuttle adapter; no invented F998 starter.
	if not _number(raw,0,0xffffffff) or _fuel_digest().length()!=64:return false
	fuel_system={"schema":FUEL_SCHEMA,"version":1,"source_digest":_fuel_digest(),"initialization_policy":policy,"jet_raw_u32":int(raw),"disabled_axes_mask_u8":0x15 if int(raw)==0 else 0,"refueller_installed":false,"refueller_enabled":false,"scoop_installed":false,"atmospheric_shielding_installed":starter_shielding_credit()>0,"status_u16":0,"cooldown_u32":0,"heat_s32":0,"ticks_fraction_f64_hex":_float_hex(0),"jet_update_remainder_raw":0,"last_scoop_reason":"not_evaluated","thermal_destruction_requested":false}
	return _valid_fuel()
func _valid_fuel()->bool:
	if fuel_system.size()!=FUEL_KEYS.size():return false
	for key in FUEL_KEYS:
		if not fuel_system.has(key):return false
	if fuel_system.schema!=FUEL_SCHEMA or fuel_system.version!=1 or fuel_system.source_digest!=_fuel_digest():return false
	if not fuel_system.initialization_policy in ["source-profile-v1","previous-v3-profile-initialization-v1","explicit-v2-migration-profile-v1"]:return false
	for key in ["jet_raw_u32","cooldown_u32"]:
		if not _number(fuel_system[key],0,0xffffffff):return false
	if not _number(fuel_system.disabled_axes_mask_u8,0,0x15) or (int(fuel_system.disabled_axes_mask_u8)&~0x15)!=0 or not _number(fuel_system.status_u16,0,65535) or not _number(fuel_system.heat_s32,-2147483648,2147483647):return false
	for key in ["refueller_installed","refueller_enabled","scoop_installed","atmospheric_shielding_installed","thermal_destruction_requested"]:
		if not fuel_system[key] is bool:return false
	if fuel_system.refueller_enabled and not fuel_system.refueller_installed:return false
	if _fraction(fuel_system.ticks_fraction_f64_hex)<0 or not fuel_system.last_scoop_reason in SCOOP_REASONS:return false
	if not _number(fuel_system.jet_update_remainder_raw,0,PLAYER_UPDATE_TICKS-1):return false
	if equipment_mass("refueller")<0 or equipment_mass("scoop")<0 or equipment_mass("atmospheric_shielding")<0:return false
	return not fuel_system.scoop_installed or equipment_allowed("scoop")
func equipment_allowed(id:String)->bool:
	var definition:=equipment_definition(id)
	if definition.is_empty():return false
	if int(definition.get("required_spec_mask_u16",0))!=0:
		var spec:=Kernel.ship_spec(model_index);var offset:=int(definition.get("required_spec_word_offset",-1))
		if offset<0 or offset+2>spec.size() or (int(spec.decode_u16(offset))&int(definition.required_spec_mask_u16))==0:return false
	return true
static func drive_mass(index:int)->int:
	for value:Variant in _data().get("drives",[]):
		if value is Dictionary and int(value.get("index",-1))==index:return int(value.get("mass_tonnes_u32",-1))
	return -1
static func drive_name(index:int)->String:
	if index==0:return "Гипердвигатель снят"
	if index==1:return "Встроенный межпланетный двигатель"
	if index>=2 and index<=9:return "Стандартный гипердвигатель, класс %d"%(index-1)
	if index>=10 and index<=12:return "Военный гипердвигатель, класс %d"%(index-9)
	return "Специальный гипердвигатель"
func configure(id:String)->bool:
	var definition:=_definition(id)
	for key in ["source_model_index","source_drive_index","hydrogen","military","waste","fixed_equipment_space_t"]:
		if not _number(definition.get(key),0,MAX_QUANTITY):return false
	var candidate:RefCounted=get_script().new()
	candidate.ship_id=id;candidate.model_index=int(definition.source_model_index);candidate.drive_index=int(definition.source_drive_index)
	candidate.hydrogen=int(definition.hydrogen);candidate.military=int(definition.military);candidate.radioactives=int(definition.waste)
	candidate.fixed_equipment_space_t=int(definition.fixed_equipment_space_t)
	if not candidate._initialize_fuel("source-profile-v1"):return false
	if not candidate.valid():return false
	_copy(candidate);return true
func capacity()->int:
	var spec:=Kernel.ship_spec(model_index)
	return Kernel._s16(int(spec.decode_u16(8))) if spec.size()>=10 else -1
func hull_mass()->int:
	var spec:=Kernel.ship_spec(model_index)
	return Kernel._s16(int(spec.decode_u16(6))) if spec.size()>=10 else 0
func cargo_quantity()->int:return adapted_cargo_t+hydrogen+military+radioactives
func starter_shielding_credit()->int:
	return maxi(0,equipment_mass("atmospheric_shielding")) if (int(_definition(ship_id).get("source_equipment_bits_u32",0))&0x40000000)!=0 else 0
func fuel_equipment_space()->int:
	var space:=0
	for id:String in ["refueller","scoop","atmospheric_shielding"]:
		if fuel_system.get(id+"_installed",false):space+=equipment_mass(id)
	return space
func occupied()->int:return cargo_quantity()+adapted_equipment_space_t+fixed_equipment_space_t-starter_shielding_credit()+drive_mass(drive_index)+fuel_equipment_space()
func free_space()->int:return capacity()-occupied()
func fuel_kind()->String:return "military" if drive_index>=10 else "hydrogen"
func fuel()->int:return military if fuel_kind()=="military" else hydrogen
func fuel_capacity()->int:return fuel()+maxi(0,free_space())
func valid()->bool:
	var definition:=_definition(ship_id)
	if definition.is_empty() or model_index!=int(definition.get("source_model_index",-1)) or fixed_equipment_space_t!=int(definition.get("fixed_equipment_space_t",-1)):return false
	if drive_index<0 or drive_index>12 or (drive_index==1 and int(definition.get("source_drive_index",-1))!=1):return false
	for value in [hydrogen,military,radioactives,fixed_equipment_space_t,adapted_cargo_t,adapted_equipment_space_t]:
		if value<0 or value>MAX_QUANTITY:return false
	return hull_mass()>0 and capacity()>=0 and drive_mass(drive_index)>=0 and occupied()<=capacity() and _valid_fuel() and (thermal_system.is_empty() or _valid_thermal())
func full_hull_raw()->int:return hull_mass()*4
func _valid_thermal()->bool:
	if thermal_system.size()!=THERMAL_KEYS.size():return false
	for key in THERMAL_KEYS:
		if not thermal_system.has(key):return false
	if thermal_system.schema!=THERMAL_SCHEMA or thermal_system.version!=1 or thermal_system.source_contract!=Thermal.CONTRACT or thermal_system.source_sha256!=Thermal.SOURCE_SHA or thermal_system.source_digest!=_thermal_digest() or thermal_system.host_policy!=THERMAL_HOST_POLICY:return false
	if not thermal_system.initialization_policy in ["source-new-profile-hull-anchor-v1","previous-v3-hull-anchor-v1","explicit-v2-migration-hull-anchor-v1"]:return false
	if _fraction(thermal_system.phase_f64_hex)<0 or _fraction(thermal_system.tick_fraction_anchor_f64_hex)<0:return false
	if not _number(thermal_system.frame_tick_remainder_raw,0,THERMAL_TICK_DENOMINATOR-1):return false
	for key in ["full_hull_u16","hull_anchor_raw_u16","hull_u16","shield_max_u16","shield_u16","last_hull_damage_u16","last_shield_damage_u16"]:
		if not _number(thermal_system[key],0,65535):return false
	for key in ["damage_timer_u8","damage_flags_u8","wind_flags_u8"]:
		if not _number(thermal_system[key],0,255):return false
	for key in ["rng_seed_a_u32","rng_seed_b_u32"]:
		if not _number(thermal_system[key],0,0xffffffff):return false
	for key in ["destroyed","last_atmosphere_active","last_drag_active","equipment_damage_requested"]:
		if not thermal_system[key] is bool:return false
	var anchor:=_finite_hex(thermal_system.hull_anchor_percent_f64_hex)
	if not is_finite(anchor) or anchor<0 or anchor>100:return false
	if int(thermal_system.full_hull_u16)!=full_hull_raw() or int(thermal_system.hull_anchor_raw_u16)!=ceili(full_hull_raw()*anchor/100.0):return false
	return int(thermal_system.hull_u16)<=int(thermal_system.hull_anchor_raw_u16) and int(thermal_system.shield_u16)<=int(thermal_system.shield_max_u16)
func thermal_hull_percent()->float:
	if thermal_system.is_empty() or not _valid_thermal():return NAN
	if thermal_system.destroyed or int(thermal_system.hull_u16)==0:return 0.0
	var anchor:=_finite_hex(thermal_system.hull_anchor_percent_f64_hex)
	return clampf(anchor-float(int(thermal_system.hull_anchor_raw_u16)-int(thermal_system.hull_u16))*100.0/full_hull_raw(),0,100)
func thermal_hull_matches(percent:Variant)->bool:
	if thermal_system.is_empty():return true # Explicit binding owns initialization.
	if not (percent is int or percent is float) or not is_finite(float(percent)) or float(percent)<0 or float(percent)>100:return false
	var expected:=thermal_hull_percent()
	# Flight's legacy JSON decimal may round; the authoritative anchor is F64.
	return is_finite(expected) and absf(float(percent)-expected)<=maxf(1e-12,absf(expected)*1e-12)
func bind_thermal_hull(percent:float)->bool:
	if not is_finite(percent) or percent<0 or percent>100 or full_hull_raw()<=0 or full_hull_raw()>65535:return false
	if not thermal_system.is_empty():return thermal_hull_matches(percent)
	var raw:=ceili(full_hull_raw()*percent/100.0);var policy:=_thermal_initialization_policy
	if fuel_system.initialization_policy=="explicit-v2-migration-profile-v1":policy="explicit-v2-migration-hull-anchor-v1"
	thermal_system={"schema":THERMAL_SCHEMA,"version":1,"source_contract":Thermal.CONTRACT,"source_sha256":Thermal.SOURCE_SHA,"source_digest":_thermal_digest(),"host_policy":THERMAL_HOST_POLICY,"initialization_policy":policy,"phase_f64_hex":_float_hex(0),"frame_tick_remainder_raw":0,"tick_fraction_anchor_f64_hex":str(fuel_system.ticks_fraction_f64_hex),"full_hull_u16":full_hull_raw(),"hull_anchor_raw_u16":raw,"hull_anchor_percent_f64_hex":_float_hex(percent),"hull_u16":raw,"shield_max_u16":0,"shield_u16":0,"damage_timer_u8":0,"damage_flags_u8":0,"rng_seed_a_u32":1,"rng_seed_b_u32":1,"destroyed":percent==0,"last_atmosphere_active":false,"last_drag_active":false,"last_hull_damage_u16":0,"last_shield_damage_u16":0,"equipment_damage_requested":false,"wind_flags_u8":0}
	return _valid_thermal()
func sync_thermal_hull(percent:float)->bool:
	if not is_finite(percent) or percent<0 or percent>100:return false
	if thermal_system.is_empty():return bind_thermal_hull(percent)
	if not _valid_thermal():return false
	if percent==thermal_hull_percent():return true
	var raw:=ceili(full_hull_raw()*percent/100.0)
	thermal_system.hull_anchor_percent_f64_hex=_float_hex(percent);thermal_system.hull_anchor_raw_u16=raw;thermal_system.hull_u16=raw;thermal_system.destroyed=percent==0
	thermal_system.last_hull_damage_u16=0;thermal_system.last_shield_damage_u16=0
	return _valid_thermal()
func _thermal_context(context:Dictionary,velocity:Array=[])->Dictionary:
	var actual:Variant=context.get("velocity_s32") if velocity.is_empty() else velocity
	if actual is Array:actual=actual.duplicate(true)
	var altitude:Variant=context.get("altitude_s32")
	if _number(altitude,-2147483648,2147483647) and int(altitude)==-1:altitude=0x7fffffff
	return {"altitude_s32":altitude,"speed_s32":context.get("speed_s32"),"heat_s32":int(fuel_system.heat_s32),"velocity_s32":actual,"shielding":bool(fuel_system.atmospheric_shielding_installed),"gear_down":context.get("gear_down",false),"wind_enabled":context.get("wind_enabled",false),"wind_armed":context.get("wind_armed",false),"parent_shield_s16":context.get("parent_shield_s16",0),"wind_flags_u8":context.get("wind_flags_u8",int(thermal_system.get("wind_flags_u8",0)))}
func _damage_state()->Dictionary:
	return {"object_index_u8":1,"kind_u8":3,"volume_s8":0,"player_selector_u8":255,"shield_u16":int(thermal_system.shield_u16),"hull_u16":int(thermal_system.hull_u16),"damage_timer_u8":int(thermal_system.damage_timer_u8),"damage_flags_u8":int(thermal_system.damage_flags_u8)}
func _apply_damage_call(call:Dictionary)->Dictionary:
	var rng:={"seed_a_u32":int(thermal_system.rng_seed_a_u32),"seed_b_u32":int(thermal_system.rng_seed_b_u32)}
	var result:=Thermal.damage(_damage_state(),call.get("amount_s32"),call.get("attacker_u32",0),{"rng_state":rng})
	if not result.get("ok",false):return result
	for key in ["shield_u16","hull_u16","damage_timer_u8","damage_flags_u8"]:thermal_system[key]=int(result.state[key])
	if result.rng_consumed:
		thermal_system.rng_seed_a_u32=int(result.rng_state.seed_a_u32);thermal_system.rng_seed_b_u32=int(result.rng_state.seed_b_u32)
	thermal_system.destroyed=bool(thermal_system.destroyed) or bool(result.destruction_requested)
	thermal_system.equipment_damage_requested=bool(thermal_system.equipment_damage_requested) or bool(result.equipment_damage_requested)
	return result
func _thermal_step_inplace(context:Dictionary)->Dictionary:
	var rejected:={"ok":false,"reason":"invalid_thermal_context"}
	if not valid() or thermal_system.is_empty() or not _number(context.get("step_ticks_u32"),0,0xffffffff):return rejected
	if context.has("apply_f1014") and not context.apply_f1014 is bool:return rejected
	var state:=_thermal_context(context)
	if not Thermal.valid_atmosphere(state):return rejected
	for axis in range(3):state.velocity_s32[axis]=int(state.velocity_s32[axis])
	var before_velocity:Array=state.velocity_s32.duplicate();var before_hull:=thermal_hull_percent()
	var raw_hull:int=thermal_system.hull_u16;var raw_shield:int=thermal_system.shield_u16
	var result:={"ok":true,"reason":"outside_atmosphere","velocity_before_s32":before_velocity,"velocity_after_s32":before_velocity.duplicate(),"velocity_changed":false,"hull_percent_before":before_hull,"hull_percent_after":before_hull,"damage_calls":[],"callbacks":[],"destruction_requested":bool(thermal_system.destroyed),"equipment_damage_requested":false,"heat_increment_s32":0,"drag_factor_s32":0,"executed_steps":1,"phase_f64_hex":str(thermal_system.phase_f64_hex),"host_policy":THERMAL_HOST_POLICY,"source_contract":Thermal.CONTRACT}
	thermal_system.last_atmosphere_active=false;thermal_system.last_drag_active=false
	thermal_system.last_hull_damage_u16=0;thermal_system.last_shield_damage_u16=0
	if context.get("apply_f1014",true):
		var atmosphere:=Thermal.atmosphere(state,int(context.step_ticks_u32))
		if not atmosphere.get("ok",false):return rejected
		fuel_system.heat_s32=int(atmosphere.state.heat_s32);thermal_system.wind_flags_u8=int(atmosphere.state.wind_flags_u8)
		thermal_system.last_atmosphere_active=atmosphere.reason=="atmosphere"
		result.reason=str(atmosphere.reason);result.damage_calls=atmosphere.damage_calls.duplicate(true)
		result.heat_increment_s32=int(atmosphere.heat_increment_s32);result.drag_factor_s32=int(atmosphere.drag_factor_s32)
		result.velocity_after_s32=atmosphere.state.velocity_s32.duplicate();result.velocity_changed=result.velocity_after_s32!=before_velocity
		thermal_system.last_drag_active=result.velocity_changed
		for callback:Dictionary in atmosphere.callbacks:
			result.callbacks.append(callback.duplicate(true))
			if callback.get("function")=="F953":
				var damage:=_apply_damage_call(callback)
				if not damage.get("ok",false):return rejected
				result.callbacks.append_array(damage.callbacks.duplicate(true))
				result.equipment_damage_requested=bool(result.equipment_damage_requested) or bool(damage.equipment_damage_requested)
	thermal_system.last_hull_damage_u16=maxi(0,raw_hull-int(thermal_system.hull_u16));thermal_system.last_shield_damage_u16=maxi(0,raw_shield-int(thermal_system.shield_u16))
	result.hull_percent_after=thermal_hull_percent();result.destruction_requested=bool(thermal_system.destroyed)
	return result if valid() else rejected
func thermal_step(context:Dictionary)->Dictionary:
	var candidate:=duplicate_session()
	if candidate==null:return {"ok":false,"reason":"invalid_thermal_session"}
	var result:Dictionary=candidate._thermal_step_inplace(context)
	if result.get("ok",false):_copy(candidate)
	return result
func _fixed_thermal_seconds(dt:float,context:Dictionary,include_fuel:bool,allow_fastpath:=true)->Dictionary:
	var rejected:={"ok":false,"reason":"invalid_thermal_context"}
	if not valid() or thermal_system.is_empty() or not is_finite(dt) or dt<0:return rejected
	var supplied:Variant=context.get("thermal") if include_fuel else context
	if not supplied is Dictionary or not Thermal.valid_atmosphere(_thermal_context(supplied)):return rejected
	if supplied.has("apply_f1014") and not supplied.apply_f1014 is bool:return rejected
	if include_fuel and not _valid_fuel_context(context):return rejected
	var accumulated:=dt*THERMAL_HZ+_fraction(thermal_system.phase_f64_hex)
	if not is_finite(accumulated) or accumulated<0 or accumulated>=MAX_THERMAL_STEPS+1:return {"ok":false,"reason":"thermal_step_budget"}
	var count:=floori(accumulated);var candidate:=duplicate_session()
	var velocity:Array=[]
	for value:Variant in supplied.velocity_s32:velocity.append(int(value))
	var result:={"ok":true,"reason":"combined_fixed_thermal" if include_fuel else "standalone_fixed_thermal","jet_events":[],"jet_callbacks":[],"scoop_events":{},"scooped_tonnes":0,"destruction_requested":false,"fuel_destruction_requested":false,"thermal_destruction_requested":false,"propulsion_available":propulsion_available(),"host_policy":THERMAL_HOST_POLICY}
	var detail:={"ok":true,"velocity_before_s32":velocity.duplicate(),"velocity_after_s32":velocity.duplicate(),"velocity_changed":false,"hull_percent_before":thermal_hull_percent(),"hull_percent_after":thermal_hull_percent(),"callbacks":[],"damage_calls":[],"equipment_damage_requested":false,"destruction_requested":false,"executed_steps":0,"phase_f64_hex":str(thermal_system.phase_f64_hex),"host_policy":THERMAL_HOST_POLICY}
	# A caller may deliberately use the legacy API between fixed-host calls.
	# Reanchor its new scheduling metadata without changing any legacy fuel bit.
	var anchor:=_fraction(candidate.thermal_system.tick_fraction_anchor_f64_hex)
	var remainder:=int(candidate.thermal_system.frame_tick_remainder_raw)
	var expected:=anchor+float(remainder)/THERMAL_TICK_DENOMINATOR
	if count>0 and include_fuel and _float_hex(expected-floorf(expected))!=candidate.fuel_system.ticks_fraction_f64_hex:
		candidate.thermal_system.tick_fraction_anchor_f64_hex=str(candidate.fuel_system.ticks_fraction_f64_hex)
		candidate.thermal_system.frame_tick_remainder_raw=0;anchor=_fraction(candidate.fuel_system.ticks_fraction_f64_hex)
	# In a cold vacuum coast all source state transitions below are identities:
	# positive tank/zero commands, zero heat/timer, no F1033 atmosphere/goods.
	# Aggregate their clock exactly, while still executing one actual source
	# update for HUD flags and the final observable no-effect callback record.
	var vacuum_fast:bool=allow_fastpath and include_fuel and count>0 and not supplied.get("apply_f1014",true) and context.has("contact") and (int(context.contact.flags_u8)&1)==0 and int(candidate.fuel_system.heat_s32)==0 and int(candidate.fuel_system.cooldown_u32)==0 and int(candidate.fuel_system.jet_raw_u32)>0 and not candidate.fuel_system.thermal_destruction_requested and not candidate.thermal_system.destroyed
	if vacuum_fast:
		for command:Variant in context.commands_s16:
			if int(command)!=0:vacuum_fast=false
	if vacuum_fast:
		var old_remainder:=int(candidate.thermal_system.frame_tick_remainder_raw)
		var total:=old_remainder+count*0x100000000
		var ticks:int=total/THERMAL_TICK_DENOMINATOR;var next_remainder:=total%THERMAL_TICK_DENOMINATOR
		var previous_fraction:=anchor+float(old_remainder)/THERMAL_TICK_DENOMINATOR;var next_fraction:=anchor+float(next_remainder)/THERMAL_TICK_DENOMINATOR
		ticks+=floori(next_fraction)-floori(previous_fraction)
		var fuel_context:=context.duplicate(true);fuel_context.erase("thermal")
		var sample:=ThermalContact.raw_speed_words(velocity)
		if not sample.get("ok",false):return rejected
		fuel_context.speed_s32=int(sample.speed_s32)
		var fuel_result:Dictionary=candidate.advance_fuel_ticks(ticks,fuel_context)
		if not fuel_result.get("ok",false):return fuel_result
		candidate.fuel_system.ticks_fraction_f64_hex=_float_hex(next_fraction-floorf(next_fraction))
		candidate.thermal_system.frame_tick_remainder_raw=next_remainder;candidate.thermal_system.phase_f64_hex=_float_hex(accumulated-float(count))
		candidate.thermal_system.last_atmosphere_active=false;candidate.thermal_system.last_drag_active=false;candidate.thermal_system.last_hull_damage_u16=0;candidate.thermal_system.last_shield_damage_u16=0
		result.jet_events=fuel_result.get("jet_events",[]).duplicate(true);result.jet_callbacks=fuel_result.get("jet_callbacks",[]).duplicate(true);result.scoop_events=fuel_result.get("scoop_events",{}).duplicate(true)
		detail.executed_steps=count;detail.phase_f64_hex=str(candidate.thermal_system.phase_f64_hex);result.thermal=detail
		if not candidate.valid():return rejected
		_copy(candidate);return result
	for _index in range(count):
		var old_remainder:=int(candidate.thermal_system.frame_tick_remainder_raw)
		var total:=old_remainder+0x100000000
		var ticks:int=total/THERMAL_TICK_DENOMINATOR;var next_remainder:=total%THERMAL_TICK_DENOMINATOR
		var previous_fraction:=anchor+float(old_remainder)/THERMAL_TICK_DENOMINATOR
		var next_fraction:=anchor+float(next_remainder)/THERMAL_TICK_DENOMINATOR
		ticks+=floori(next_fraction)-floori(previous_fraction)
		candidate.thermal_system.frame_tick_remainder_raw=next_remainder
		var sample:=ThermalContact.raw_speed_words(velocity)
		if not sample.get("ok",false):return rejected
		if include_fuel:
			var fuel_context:=context.duplicate(true);fuel_context.erase("thermal");fuel_context.speed_s32=int(sample.speed_s32)
			var fuel_result:Dictionary=candidate.advance_fuel_ticks(ticks,fuel_context)
			if not fuel_result.get("ok",false):return fuel_result
			candidate.fuel_system.ticks_fraction_f64_hex=_float_hex(next_fraction-floorf(next_fraction))
			result.jet_events.append_array(fuel_result.get("jet_events",[]));result.jet_callbacks.append_array(fuel_result.get("jet_callbacks",[]))
			result.scooped_tonnes+=int(fuel_result.get("scooped_tonnes",0));result.scoop_events=fuel_result.get("scoop_events",{}).duplicate(true)
			result.fuel_destruction_requested=bool(result.fuel_destruction_requested) or bool(fuel_result.get("destruction_requested",false))
		var thermal_context:Dictionary=supplied.duplicate(true);thermal_context.velocity_s32=velocity.duplicate();thermal_context.speed_s32=int(sample.speed_s32);thermal_context.step_ticks_u32=ticks
		var thermal_result:Dictionary=candidate._thermal_step_inplace(thermal_context)
		if not thermal_result.get("ok",false):return thermal_result
		velocity=thermal_result.velocity_after_s32.duplicate()
		detail.callbacks.append_array(thermal_result.callbacks);detail.damage_calls.append_array(thermal_result.damage_calls)
		detail.equipment_damage_requested=bool(detail.equipment_damage_requested) or bool(thermal_result.equipment_damage_requested);detail.executed_steps+=1
		result.thermal_destruction_requested=bool(result.thermal_destruction_requested) or bool(thermal_result.destruction_requested)
		if result.fuel_destruction_requested:candidate.thermal_system.destroyed=true
		if candidate.thermal_system.destroyed:break
	candidate.thermal_system.phase_f64_hex=_float_hex(accumulated-float(count))
	detail.phase_f64_hex=str(candidate.thermal_system.phase_f64_hex);detail.velocity_after_s32=velocity;detail.velocity_changed=velocity!=detail.velocity_before_s32
	detail.hull_percent_after=candidate.thermal_hull_percent();detail.destruction_requested=bool(candidate.thermal_system.destroyed)
	result.destruction_requested=bool(result.fuel_destruction_requested) or bool(result.thermal_destruction_requested);result.thermal=detail;result.propulsion_available=candidate.propulsion_available()
	if not candidate.valid():return rejected
	_copy(candidate);return result
func advance_thermal_seconds(dt:float,context:Dictionary)->Dictionary:return _fixed_thermal_seconds(dt,context,false)
func thermal_state()->Dictionary:
	var heat:=int(fuel_system.get("heat_s32",0));var percentage:=float(heat)*100.0/65535.0
	if thermal_system.is_empty():return {"initialized":false,"atmosphere_active":false,"heat_percent":percentage,"thermal_severity":"unknown","thermal_status":"Тепловая модель ожидает привязки корпуса.","atmospheric_status":"Нет подтверждённого состояния атмосферы.","drag_status":"Нет данных о сопротивлении.","damage_status":"Нет исходных данных о повреждениях.","escape_guidance":"","shielding":bool(fuel_system.get("atmospheric_shielding_installed",false)),"shield_available":false,"shield_percent":0.0,"hull_percent":0.0,"upgrade_notice":""}
	var destroyed:bool=thermal_system.destroyed;var hull_damage:=int(thermal_system.last_hull_damage_u16);var shield_damage:=int(thermal_system.last_shield_damage_u16)
	var severity:="critical" if destroyed else ("danger" if percentage>=75 or hull_damage>0 else ("warning" if percentage>=50 or shield_damage>0 else "normal"))
	var statuses:={"normal":"Температурный режим в норме.","warning":"Нагрев повышен.","danger":"Опасный нагрев или повреждение корпуса.","critical":"Корабль потерян из-за повреждений."}
	var damage_status:="Корпус: %.2f%%."%thermal_hull_percent()
	if destroyed:damage_status="Корпус разрушен."
	elif hull_damage>0:damage_status="Урон корпусу от атмосферы: %.2f%%."%(float(hull_damage)*100.0/full_hull_raw())
	elif shield_damage>0:damage_status="Атмосферный урон поглощён щитом."
	return {"initialized":true,"atmosphere_active":bool(thermal_system.last_atmosphere_active),"heat_percent":percentage,"thermal_severity":severity,"thermal_status":str(statuses[severity]),"atmospheric_status":"Корабль находится в атмосфере." if thermal_system.last_atmosphere_active else "Атмосферное воздействие не обнаружено.","drag_status":"Действует атмосферное торможение." if thermal_system.last_drag_active else "Атмосферное торможение не действует.","damage_status":damage_status,"escape_guidance":("Уменьшите скорость и выходите из плотных слоёв атмосферы." if thermal_system.last_atmosphere_active else "Удаляйтесь от источника нагрева и дайте корпусу остыть.") if severity in ["warning","danger"] else "","shielding":bool(fuel_system.atmospheric_shielding_installed),"shield_available":int(thermal_system.shield_max_u16)>0,"shield_percent":float(thermal_system.shield_u16)*100.0/int(thermal_system.shield_max_u16) if int(thermal_system.shield_max_u16)>0 else 0.0,"hull_percent":thermal_hull_percent(),"upgrade_notice":"Тепловая модель добавлена к сохранению без изменения корпуса и топлива." if thermal_extension_upgraded else "","host_policy":THERMAL_HOST_POLICY,"source_contract":Thermal.CONTRACT,"phase_f64_hex":str(thermal_system.phase_f64_hex)}
static func ship_bridge(ship:RefCounted)->Dictionary:
	if ship==null or not ship.has_method("total_cargo") or not ship.has_method("equipment_space"):return {}
	var cargo:Variant=ship.total_cargo();var equipment:Variant=ship.equipment_space()
	if not _number(cargo,0,MAX_QUANTITY) or not _number(equipment,0,MAX_QUANTITY) or not ship.ship_id is String:return {}
	return {"ship_id":str(ship.ship_id),"adapted_cargo_t":int(cargo),"adapted_equipment_space_t":int(equipment)}
func bridge_matches(ship:RefCounted)->bool:
	var bridge:=ship_bridge(ship)
	return not bridge.is_empty() and str(bridge.ship_id)==ship_id and int(bridge.adapted_cargo_t)==adapted_cargo_t and int(bridge.adapted_equipment_space_t)==adapted_equipment_space_t and valid()
func with_ship(ship:RefCounted)->RefCounted:
	var bridge:=ship_bridge(ship)
	if bridge.is_empty() or str(bridge.ship_id)!=ship_id:return null
	var candidate:=duplicate_session()
	if candidate==null:return null
	candidate.adapted_cargo_t=int(bridge.adapted_cargo_t);candidate.adapted_equipment_space_t=int(bridge.adapted_equipment_space_t)
	return candidate if candidate.valid() else null
func profile()->Dictionary:
	return {"model_index":model_index,"source_drive_index":drive_index,"player":true,"cargo_u32":cargo_quantity(),"waste_u16":radioactives,"status_u16":0}
func quote(distance_raw:int,consume:=false)->Dictionary:
	if not valid():return {"ok":false,"can_jump":false,"reason":"invalid_session"}
	return Kernel.quote(profile(),distance_raw,hydrogen,military,consume)
func range_quote()->Dictionary:return quote(1)
func hyperdrive_snapshot()->Dictionary:
	return {"schema":SCHEMA,"version":1,"source_digest":_digest(),"ship_id":ship_id,"model_index":model_index,"drive_index":drive_index,"hydrogen":hydrogen,"military":military,"radioactives":radioactives,"fixed_equipment_space_t":fixed_equipment_space_t,"adapted_cargo_t":adapted_cargo_t,"adapted_equipment_space_t":adapted_equipment_space_t}
func snapshot()->Dictionary:
	var result:=hyperdrive_snapshot();result.fuel_system=fuel_system.duplicate(true)
	if not thermal_system.is_empty():result.thermal_system=thermal_system.duplicate(true)
	return result
func restore(data:Dictionary)->bool:
	var keys:=["schema","version","source_digest","ship_id","model_index","drive_index","hydrogen","military","radioactives","fixed_equipment_space_t","adapted_cargo_t","adapted_equipment_space_t"]
	if data.has("fuel_system"):keys.append("fuel_system")
	if data.has("thermal_system"):keys.append("thermal_system")
	if data.size()!=keys.size():return false
	for key in keys:
		if not data.has(key):return false
	if data.schema!=SCHEMA or data.version!=1 or not data.source_digest is String or data.source_digest!=_digest() or not data.ship_id is String:return false
	for key in ["model_index","drive_index","hydrogen","military","radioactives","fixed_equipment_space_t","adapted_cargo_t","adapted_equipment_space_t"]:
		if not _number(data.get(key),0,MAX_QUANTITY):return false
	var candidate:RefCounted=get_script().new()
	candidate.ship_id=str(data.ship_id);candidate.model_index=int(data.model_index);candidate.drive_index=int(data.drive_index)
	candidate.hydrogen=int(data.hydrogen);candidate.military=int(data.military);candidate.radioactives=int(data.radioactives)
	candidate.fixed_equipment_space_t=int(data.fixed_equipment_space_t);candidate.adapted_cargo_t=int(data.adapted_cargo_t);candidate.adapted_equipment_space_t=int(data.adapted_equipment_space_t)
	if data.has("fuel_system"):
		if not data.fuel_system is Dictionary:return false
		candidate.fuel_system=data.fuel_system.duplicate(true)
	elif not candidate._initialize_fuel("previous-v3-profile-initialization-v1"):return false
	candidate.fuel_extension_upgraded=not data.has("fuel_system")
	if data.has("thermal_system"):
		if not data.thermal_system is Dictionary or not data.has("fuel_system"):return false
		candidate.thermal_system=data.thermal_system.duplicate(true)
		if not candidate._valid_thermal():return false
	else:
		candidate._thermal_initialization_policy="previous-v3-hull-anchor-v1";candidate.thermal_extension_upgraded=true
	if not candidate.valid():return false
	for key in ["version","jet_raw_u32","disabled_axes_mask_u8","status_u16","cooldown_u32","heat_s32","jet_update_remainder_raw"]:candidate.fuel_system[key]=int(candidate.fuel_system[key])
	for key in ["version","frame_tick_remainder_raw","full_hull_u16","hull_anchor_raw_u16","hull_u16","shield_max_u16","shield_u16","damage_timer_u8","damage_flags_u8","rng_seed_a_u32","rng_seed_b_u32","last_hull_damage_u16","last_shield_damage_u16","wind_flags_u8"]:
		if not candidate.thermal_system.is_empty():candidate.thermal_system[key]=int(candidate.thermal_system[key])
	_copy(candidate);return true
func _copy(other:RefCounted)->void:
	ship_id=other.ship_id;model_index=other.model_index;drive_index=other.drive_index;hydrogen=other.hydrogen;military=other.military;radioactives=other.radioactives
	fixed_equipment_space_t=other.fixed_equipment_space_t;adapted_cargo_t=other.adapted_cargo_t;adapted_equipment_space_t=other.adapted_equipment_space_t
	fuel_system=other.fuel_system.duplicate(true);fuel_extension_upgraded=other.fuel_extension_upgraded
	thermal_system=other.thermal_system.duplicate(true);thermal_extension_upgraded=other.thermal_extension_upgraded;_thermal_initialization_policy=other._thermal_initialization_policy
func duplicate_session()->RefCounted:
	var candidate:RefCounted=get_script().new()
	if not candidate.restore(snapshot()):return null
	candidate.fuel_extension_upgraded=fuel_extension_upgraded;candidate.thermal_extension_upgraded=thermal_extension_upgraded;candidate._thermal_initialization_policy=_thermal_initialization_policy;return candidate
func commit(distance_raw:int,expected:Dictionary)->Dictionary:
	var current:=quote(distance_raw)
	if not current.get("ok",false) or not current.get("can_jump",false):return {"ok":false,"reason":"quote_unavailable"}
	for key in ["required_fuel","duration_raw_u32","max_range_raw","current_range_raw"]:
		if current.get(key)!=expected.get(key):return {"ok":false,"reason":"quote_changed"}
	var consumed:=quote(distance_raw,true)
	if not consumed.get("ok",false) or not consumed.get("can_jump",false):return {"ok":false,"reason":"commit_rejected"}
	var candidate:=duplicate_session()
	if candidate==null:return {"ok":false,"reason":"invalid_session"}
	candidate.hydrogen=int(consumed.hydrogen_after);candidate.military=int(consumed.military_after);candidate.radioactives=int(consumed.waste_after)
	if not candidate.valid() or int(consumed.cargo_after)!=candidate.cargo_quantity():return {"ok":false,"reason":"cargo_accounting_mismatch"}
	_copy(candidate);return consumed
func cached_thrust_u16()->Array:
	var spec:=Kernel.ship_spec(model_index)
	if spec.size()<4:return []
	var main:=Kernel._s16(int(spec.decode_u16(0)));var retro:=Kernel._s16(int(spec.decode_u16(2)))
	return [(-retro)&65535,retro&65535,(-retro)&65535,retro&65535,main&65535,retro&65535]
func thrust_limits_u16()->Array:
	var limits:=cached_thrust_u16();var mask:=int(fuel_system.get("disabled_axes_mask_u8",0))
	for axis in range(limits.size()):
		if mask&(1<<axis)!=0:limits[axis]=0
	return limits
func propulsion_available()->bool:
	for value:int in thrust_limits_u16():
		if value!=0:return true
	return false
func _jet_state()->Dictionary:
	return {"jet_raw_u32":int(fuel_system.jet_raw_u32),"object_index_u8":1,"drive_index_s8":drive_index,"npc_fuel_u8":0,"auto_refueller":bool(fuel_system.refueller_installed) and bool(fuel_system.refueller_enabled),"thrust_u16":thrust_limits_u16(),"cached_thrust_u16":cached_thrust_u16(),"player_object_index_u32":1,"status_u16":int(fuel_system.status_u16),"cargo_s32":cargo_quantity(),"hydrogen_u16":hydrogen,"military_u16":military,"waste_u16":radioactives}
func _accept_jet(result:Dictionary)->bool:
	if not result.get("ok",false) or not result.get("state") is Dictionary:return false
	var state:Dictionary=result.state
	if not Jet.valid_state(state) or not _number(result.get("disabled_axes_mask_u8"),0,0x15) or (int(result.disabled_axes_mask_u8)&~0x15)!=0:return false
	hydrogen=int(state.hydrogen_u16);military=int(state.military_u16);radioactives=int(state.waste_u16)
	fuel_system.jet_raw_u32=int(state.jet_raw_u32);fuel_system.status_u16=int(state.status_u16);fuel_system.disabled_axes_mask_u8=int(result.disabled_axes_mask_u8)
	return int(state.cargo_s32)==cargo_quantity() and valid()
func _manual_reason(code:String)->String:
	return str({"near_full":"Реактивный бак заполнен.","no_fuel":"Нет подходящего грузового топлива.","manual_refuel":"Тонна грузового топлива перенесена в реактивный бак."}.get(code,"Ручная заправка недоступна."))
func manual_jet_refuel()->Dictionary:
	var rejected:={"ok":false,"accepted":false,"reason":"invalid_session","message":"Недопустимое состояние топливной системы."}
	if not valid():return rejected
	var capacity_raw:=Jet.jet_capacity_raw(drive_index)
	if capacity_raw<0:return rejected
	var candidate:=duplicate_session();var result:=Jet.manual_refuel(candidate._jet_state(),capacity_raw)
	if not candidate._accept_jet(result):return rejected
	_copy(candidate);result.message=_manual_reason(str(result.reason));return result
func set_refueller_enabled(enabled:bool)->bool:
	if not valid() or not fuel_system.refueller_installed:return false
	fuel_system.refueller_enabled=enabled;return true
func _valid_fuel_context(context:Dictionary)->bool:
	if not context.get("commands_s16") is Array or not Jet.consumption(hull_mass(),context.commands_s16,0).get("ok",false):return false
	if context.has("cached_thrust_u16"):
		if not context.cached_thrust_u16 is Array or context.cached_thrust_u16.size()!=6:return false
		var expected:=cached_thrust_u16()
		for axis in range(6):
			if not _number(context.cached_thrust_u16[axis],0,65535) or int(context.cached_thrust_u16[axis])!=int(expected[axis]):return false
	if not _number(context.get("speed_s32",0),-2147483648,2147483647):return false
	if context.has("contact"):
		if not context.contact is Dictionary:return false
		if not _number(context.contact.get("flags_u8"),0,255) or not _number(context.contact.get("altitude_raw_s32"),-2147483648,2147483647) or not _number(context.contact.get("parent_model_u32"),0,0xffffffff):return false
	return true
func _step_fuel(context:Dictionary)->Dictionary:
	var rejected:={"ok":false,"reason":"invalid_fuel_context","propulsion_available":propulsion_available()}
	if not valid() or not _valid_fuel_context(context) or not _number(context.get("step_s32"),0,0x7fffffff):return rejected
	var speed:Variant=context.get("speed_s32",0)
	if not _number(speed,-2147483648,2147483647):return rejected
	var candidate:=duplicate_session();var jet:Dictionary
	if int(context.step_s32)>0:
		var shielding:=bool(candidate.fuel_system.atmospheric_shielding_installed)
		var cooling:=Jet.cooling(int(candidate.fuel_system.heat_s32),int(context.step_s32),shielding)
		if not cooling.get("ok",false):return rejected
		candidate.fuel_system.heat_s32=int(cooling.heat_s32)
		jet=Jet.fuel_step(candidate._jet_state(),hull_mass(),context.commands_s16,int(context.step_s32))
		if not candidate._accept_jet(jet):return rejected
	else:
		if not Jet.consumption(hull_mass(),context.commands_s16,0).get("ok",false):return rejected
		jet={"reason":"jet_cadence_wait","events":[],"callbacks":[],"consumption":{"ok":true,"amount_u32":0}}
	var scoop:Dictionary={};var reset:=false;var step:Variant=context.get("scoop_step_u32",0)
	if not _number(step,0,0xffffffff):return rejected
	if context.has("contact"):
		if not context.has("scoop_step_u32"):return rejected
		var scoop_state:={"cargo_used_s32":candidate.cargo_quantity(),"capacity_s32":candidate.capacity()-(candidate.occupied()-candidate.cargo_quantity()),"hydrogen_u16":candidate.hydrogen,"cooldown_u32":int(candidate.fuel_system.cooldown_u32),"heat_s32":int(candidate.fuel_system.heat_s32),"speed_s32":int(speed),"step_u32":int(step),"equipped_ca_u8":0x10 if candidate.fuel_system.scoop_installed else 0,"flags_c6_u16":int(candidate.fuel_system.status_u16)}
		scoop=Scoop.evaluate(scoop_state,context.contact)
		if not scoop.get("ok",false):return rejected
		candidate.hydrogen=int(scoop.hydrogen_u16)
		candidate.fuel_system.cooldown_u32=int(scoop.cooldown_u32);candidate.fuel_system.heat_s32=int(scoop.heat_s32);candidate.fuel_system.status_u16=int(scoop.flags_c6_u16)
		candidate.fuel_system.last_scoop_reason=str(scoop.reason);candidate.fuel_system.thermal_destruction_requested=bool(candidate.fuel_system.thermal_destruction_requested) or bool(scoop.destruction_requested)
		reset=str(scoop.reason) in ["scooped","cargo_full","no_scoop"]
		if int(scoop.cargo_used_s32)!=candidate.cargo_quantity():return rejected
	else:candidate.fuel_system.last_scoop_reason="not_evaluated"
	# Named host countdown adapter: the kernel itself never decrements 1e8.
	# Keep a newly written149130 intact; otherwise advance the remaining count.
	if not reset:candidate.fuel_system.cooldown_u32=maxi(0,int(candidate.fuel_system.cooldown_u32)-int(step))
	if not candidate.valid():return rejected
	_copy(candidate)
	return {"ok":true,"reason":str(jet.reason),"jet_events":jet.events.duplicate(true),"jet_callbacks":jet.callbacks.duplicate(true),"consumption":jet.consumption.duplicate(true),"scoop_events":scoop.get("events",{}).duplicate(true),"scooped_tonnes":int(scoop.get("scooped_tonnes",0)),"destruction_requested":bool(fuel_system.thermal_destruction_requested),"propulsion_available":propulsion_available(),"disabled_axes_mask_u8":int(fuel_system.disabled_axes_mask_u8),"step_s32":int(context.step_s32),"scoop_step_u32":int(step)}
func fuel_step(context:Dictionary)->Dictionary:return _step_fuel(context)
func advance_fuel_ticks(ticks:int,context:Dictionary)->Dictionary:
	if not valid() or ticks<0 or ticks>0x7fffffff:return {"ok":false,"reason":"source_tick_range"}
	if not _valid_fuel_context(context):return {"ok":false,"reason":"invalid_fuel_context"}
	if ticks==0:return {"ok":true,"reason":"zero_elapsed_ticks","step_s32":0,"jet_events":[],"jet_callbacks":[],"scoop_events":{},"scooped_tonnes":0,"destruction_requested":bool(fuel_system.thermal_destruction_requested),"propulsion_available":propulsion_available()}
	var candidate:=duplicate_session();var total:=int(fuel_system.jet_update_remainder_raw)+ticks
	var supplied:=context.duplicate(true);supplied.step_s32=int(total/PLAYER_UPDATE_TICKS);supplied.scoop_step_u32=ticks
	var result:Dictionary=candidate._step_fuel(supplied)
	if not result.get("ok",false):return result
	candidate.fuel_system.jet_update_remainder_raw=total%PLAYER_UPDATE_TICKS;_copy(candidate)
	result.host_policy=HOST_FUEL_POLICY;return result
func _legacy_advance_fuel_seconds(dt:float,context:Dictionary)->Dictionary:
	if not valid() or not _valid_fuel_context(context) or not is_finite(dt) or dt<0:return {"ok":false,"reason":"invalid_fuel_seconds"}
	var accumulated:=dt*Motion.NOMINAL_TICKS_PER_SECOND+_fraction(fuel_system.ticks_fraction_f64_hex)
	if not is_finite(accumulated) or accumulated<0 or accumulated>0x7fffffff:return {"ok":false,"reason":"source_tick_range"}
	var step:=floori(accumulated);var candidate:=duplicate_session();var result:Dictionary
	if step>0:
		result=candidate.advance_fuel_ticks(step,context)
		if not result.get("ok",false):return result
	else:result={"ok":true,"reason":"fraction_only","step_s32":0,"jet_events":[],"jet_callbacks":[],"scoop_events":{},"scooped_tonnes":0,"destruction_requested":bool(fuel_system.thermal_destruction_requested),"propulsion_available":propulsion_available()}
	candidate.fuel_system.ticks_fraction_f64_hex=_float_hex(accumulated-float(step));_copy(candidate)
	result.host_policy=HOST_FUEL_POLICY;return result
func advance_fuel_seconds(dt:float,context:Dictionary)->Dictionary:
	return _fixed_thermal_seconds(dt,context,true) if context.has("thermal") else _legacy_advance_fuel_seconds(dt,context)
func fuel_state()->Dictionary:
	if not valid():return {"source_mode":true,"reason":"Недопустимое состояние топливной системы."}
	var capacity_raw:=Jet.jet_capacity_raw(drive_index);var raw:=int(fuel_system.jet_raw_u32)
	var manual:=Jet.manual_refuel(_jet_state(),capacity_raw) if capacity_raw>=0 else {"ok":false,"accepted":false,"reason":"invalid_capacity"}
	var labels:={"not_evaluated":"Ожидание подходящих условий.","outside_atmosphere":"Для забора нужна атмосфера звезды или газового гиганта.","ineligible_parent_model":"Этот объект не подходит для забора топлива.","too_high":"Слишком большая высота для забора топлива.","too_slow":"Недостаточная скорость для забора топлива.","cooldown":"Подготовка следующего забора.","scooped":"Водород поступает в трюм.","cargo_full":"Трюм заполнен.","no_scoop":"Топливозаборник не установлен."}
	var upgraded:="Реактивная топливная система добавлена к сохранению0.15.0 по начальному профилю корабля; прежний груз и гипертопливо сохранены." if fuel_extension_upgraded else ""
	return {"source_mode":true,"jet_raw_u32":raw,"jet_capacity_raw_u32":maxi(0,capacity_raw),"jet_tonnes":float(raw)/Jet.RAW_PER_TONNE,"jet_capacity_tonnes":float(maxi(0,capacity_raw))/Jet.RAW_PER_TONNE,"jet_percent":float(raw)*100.0/capacity_raw if capacity_raw>0 else (100.0 if raw>0 else 0.0),"jet_above_nominal":raw>capacity_raw,"propulsion_available":propulsion_available(),"forward_propulsion_available":int(thrust_limits_u16()[4])!=0,"thrust_disabled_axes_mask_u8":int(fuel_system.disabled_axes_mask_u8),"thrust_limits_u16":thrust_limits_u16(),"refueller_installed":bool(fuel_system.refueller_installed),"refueller_enabled":bool(fuel_system.refueller_enabled),"can_toggle_refueller":bool(fuel_system.refueller_installed),"toggle_reason":"" if fuel_system.refueller_installed else "Автозаправщик не установлен.","can_manual_refuel":bool(manual.get("ok",false)) and bool(manual.get("accepted",false)),"manual_refuel_reason":_manual_reason(str(manual.get("reason",""))),"scoop_installed":bool(fuel_system.scoop_installed),"atmospheric_shielding_installed":bool(fuel_system.atmospheric_shielding_installed),"starter_shielding_credit_t":starter_shielding_credit(),"heat_s32":int(fuel_system.heat_s32),"heat_label":"Критический перегрев корпуса." if fuel_system.thermal_destruction_requested else "Нагрев корпуса: %d (шкала игры)."%int(fuel_system.heat_s32),"cooldown_u32":int(fuel_system.cooldown_u32),"cooldown_seconds":float(fuel_system.cooldown_u32)/Motion.NOMINAL_TICKS_PER_SECOND,"scoop_status":str(labels.get(str(fuel_system.last_scoop_reason),labels.not_evaluated)) if fuel_system.scoop_installed else labels.no_scoop,"upgrade_notice":upgraded,"initialization_policy":str(fuel_system.initialization_policy),"host_policy":HOST_FUEL_POLICY,"thermal":thermal_state()}
func service_state(credits:int,available:bool,reason:String="")->Dictionary:
	var ranges:=range_quote();var current_range:=float(ranges.get("current_range_raw",0))/100.0
	var state:={"schema":"source-hyperdrive-services-v1","source_mode":true,"ship_id":ship_id,"source_model_index":model_index,"profile_name":"Корабельное оборудование и гипертопливо","pricing_profile":PRICING,"drive_class":drive_index,"drive_index":drive_index,"drive_name":drive_name(drive_index),"drive_class_label":drive_name(drive_index),"class_label":drive_name(drive_index),"range_ly":maxf(0,current_range),"maximum_range_ly":maxf(0,float(ranges.get("max_range_raw",0))/100.0),"fuel_kind":fuel_kind(),"hydrogen":hydrogen,"military":military,"radioactives":radioactives,"source_capacity_t":capacity(),"occupied_t":occupied(),"free_t":free_space(),"flight_cargo_t":adapted_cargo_t,"flight_equipment_space_t":adapted_equipment_space_t,"credits":credits,"docked":available,"service_available":available,"reason":reason,"drives":[],"fuels":[],"remove_price":maxi(0,drive_mass(drive_index))*50,"can_remove":available and drive_index>=2,"remove_reason":reason,"can_unload_waste":available and radioactives>0 and credits>=radioactives*10,"unload_quantity":radioactives,"waste_price":radioactives*10,"waste_reason":reason}
	for index in range(2,13):
		var mass:=drive_mass(index);var price:=mass*100;var after:=occupied()-drive_mass(drive_index)+mass
		var why:=reason
		if index==drive_index:why="Этот гипердвигатель уже установлен."
		elif after>capacity():why="Недостаточно свободного места."
		elif credits<price:why="Недостаточно средств."
		state.drives.append({"class":index,"drive_index":index,"name":drive_name(index),"class_label":drive_name(index),"space_t":mass,"installed":index==drive_index,"price":price,"can_install":available and why.is_empty(),"reason":why})
	for kind in ["hydrogen","military"]:
		var quantity:=hydrogen if kind=="hydrogen" else military
		var fill:=mini(maxi(0,free_space()),maxi(0,int(credits/10)))
		var why:=reason
		if free_space()<1:why="В трюме нет свободного места."
		elif credits<10:why="Недостаточно средств."
		state.fuels.append({"id":kind,"name":"Водородное топливо" if kind=="hydrogen" else "Военное топливо","quantity":quantity,"unit_price":10,"can_refuel":available and why.is_empty(),"reason":why,"fill_quantity":fill,"fill_price":fill*10,"can_fill":available and fill>0,"fill_reason":why,"can_unload":available and quantity>0,"unload_quantity":1 if quantity>0 else 0,"unload_price":0,"unload_reason":reason if not available else ("Топлива этого типа нет." if quantity==0 else "")})
	if radioactives==0:state.waste_reason="Радиоактивных отходов нет."
	elif credits<radioactives*10:state.waste_reason="Недостаточно средств для передачи отходов."
	if drive_index<2:state.remove_reason="Съёмный гипердвигатель не установлен."
	elif credits+int(state.remove_price)>1000000000:
		state.can_remove=false;state.remove_reason="Сумма возврата превышает допустимый баланс."
	state.fuel_system=fuel_state();state.fuel_equipment=[]
	for id:String in ["refueller","scoop","atmospheric_shielding"]:
		var fitted:=bool(fuel_system[id+"_installed"]);var mass:=equipment_mass(id);var install_reason:=reason;var remove_reason:=reason
		if fitted:install_reason="Оборудование уже установлено."
		elif not equipment_allowed(id):install_reason="У корабля нет крепления для топливозаборника."
		elif free_space()<mass:install_reason="Недостаточно свободного места."
		elif credits<mass*100:install_reason="Недостаточно средств."
		if not fitted:remove_reason="Оборудование не установлено."
		elif credits+mass*50>1000000000:remove_reason="Сумма возврата превышает допустимый баланс."
		state.fuel_equipment.append({"id":id,"name":str({"refueller":"Автозаправщик","scoop":"Топливозаборник","atmospheric_shielding":"Атмосферная защита"}[id]),"mass_t":mass,"installed":fitted,"install_price":mass*100,"remove_refund":mass*50,"can_install":available and install_reason.is_empty(),"install_reason":install_reason,"can_remove":available and remove_reason.is_empty(),"remove_reason":remove_reason})
	return state
func service(action:String,id:String,quantity:int,credits:int)->Dictionary:
	var rejected:={"ok":false,"credits":credits,"message":"Недопустимая операция службы станции."}
	if not valid() or credits<0 or credits>1000000000:return rejected
	var candidate:=duplicate_session()
	if candidate==null:return rejected
	var cost:=0;var message:=""
	match action:
		"install_drive":
			if not id.is_valid_int() or quantity!=1:return rejected
			var index:=id.to_int()
			if str(index)!=id or index<2 or index>12 or index==drive_index:return rejected
			candidate.drive_index=index;cost=drive_mass(index)*100;message="Гипердвигатель установлен."
		"remove_drive":
			if not id.is_empty() or quantity!=1 or drive_index<2:return rejected
			# DOS F410 clears11e but does not change any thrust-limit word.
			cost=-drive_mass(drive_index)*50;candidate.drive_index=0;candidate.fuel_system.jet_raw_u32=0;message="Гипердвигатель снят, реактивный бак опустошён."
		"refuel":
			if quantity<1 or quantity>MAX_QUANTITY or not id in ["hydrogen","military"]:return rejected
			if id=="hydrogen":candidate.hydrogen+=quantity
			else:candidate.military+=quantity
			cost=quantity*10;message="Гипертопливо пополнено."
		"unload_fuel":
			if quantity<1 or quantity>MAX_QUANTITY or not id in ["hydrogen","military"]:return rejected
			if id=="hydrogen":candidate.hydrogen-=quantity
			else:candidate.military-=quantity
			message="Гипертопливо передано службе станции без оплаты."
		"unload_waste":
			if not id.is_empty() or quantity<1 or quantity>radioactives:return rejected
			candidate.radioactives-=quantity;cost=quantity*10;message="Радиоактивные отходы переданы службе станции."
		"install_fuel_equipment":
			if quantity!=1 or not id in ["refueller","scoop","atmospheric_shielding"] or candidate.fuel_system[id+"_installed"] or not equipment_allowed(id):return rejected
			candidate.fuel_system[id+"_installed"]=true
			if id=="refueller":candidate.fuel_system.refueller_enabled=true
			cost=equipment_mass(id)*100;message="Топливное оборудование установлено."
		"remove_fuel_equipment":
			if quantity!=1 or not id in ["refueller","scoop","atmospheric_shielding"] or not candidate.fuel_system[id+"_installed"]:return rejected
			candidate.fuel_system[id+"_installed"]=false
			if id=="refueller":candidate.fuel_system.refueller_enabled=false
			cost=-equipment_mass(id)*50;message="Топливное оборудование снято."
		_:return rejected
	if not candidate.valid() or cost>credits or credits-cost<0 or credits-cost>1000000000:return rejected
	_copy(candidate);return {"ok":true,"credits":credits-cost,"message":message,"pricing_profile":PRICING}
