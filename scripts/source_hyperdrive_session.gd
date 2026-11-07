extends RefCounted
# Source hardware/inventory with an explicit bridge to the prototype cargo.
# F903 always reads the unchanged source hull spec; carried mass is capacity only.
const Kernel=preload("res://scripts/source_hyperdrive.gd")
const Jet=preload("res://scripts/source_jet_fuel.gd")
const Scoop=preload("res://scripts/source_fuel_scoop.gd")
const Motion=preload("res://scripts/source_motion_pipeline.gd")
const SCHEMA:="starfrontier-source-hyperdrive-session-v1"
const FUEL_PROFILE:="source-f903-hydrogen-military-v1"
const PRICING:="basic-source-workshop-pricing-adapter-v1"
const MAX_QUANTITY:=65535
const FUEL_SCHEMA:="starfrontier-source-jetfuel-session-v1"
const HOST_FUEL_POLICY:="nominal-day-si-player-f152-49710-cadence-v1"
const PLAYER_UPDATE_TICKS:=49710
const FUEL_KEYS:=["schema","version","source_digest","initialization_policy","jet_raw_u32","disabled_axes_mask_u8","refueller_installed","refueller_enabled","scoop_installed","atmospheric_shielding_installed","status_u16","cooldown_u32","heat_s32","ticks_fraction_f64_hex","jet_update_remainder_raw","last_scoop_reason","thermal_destruction_requested"]
const SCOOP_REASONS:=["not_evaluated","outside_atmosphere","ineligible_parent_model","too_high","too_slow","cooldown","scooped","cargo_full","no_scoop"]
static var _resource:Dictionary={}
static var _resource_mutex:=Mutex.new()
static var _resource_digest:=""
static var _fuel_resource:Dictionary={}
static var _fuel_resource_mutex:=Mutex.new()
static var _fuel_resource_digest:=""
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
static func _float_hex(value:float)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()
static func _fraction(value:Variant)->float:
	if not value is String or value.length()!=16:return -1.0
	for character:String in value:
		if not character in "0123456789abcdef":return -1.0
	var number:float=value.hex_decode().decode_double(0)
	return number if is_finite(number) and number>=0 and number<1 else -1.0
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
	return hull_mass()>0 and capacity()>=0 and drive_mass(drive_index)>=0 and occupied()<=capacity() and _valid_fuel()
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
	var result:=hyperdrive_snapshot();result.fuel_system=fuel_system.duplicate(true);return result
func restore(data:Dictionary)->bool:
	var keys:=["schema","version","source_digest","ship_id","model_index","drive_index","hydrogen","military","radioactives","fixed_equipment_space_t","adapted_cargo_t","adapted_equipment_space_t"]
	if data.has("fuel_system"):keys.append("fuel_system")
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
	if not candidate.valid():return false
	for key in ["version","jet_raw_u32","disabled_axes_mask_u8","status_u16","cooldown_u32","heat_s32","jet_update_remainder_raw"]:candidate.fuel_system[key]=int(candidate.fuel_system[key])
	_copy(candidate);return true
func _copy(other:RefCounted)->void:
	ship_id=other.ship_id;model_index=other.model_index;drive_index=other.drive_index;hydrogen=other.hydrogen;military=other.military;radioactives=other.radioactives
	fixed_equipment_space_t=other.fixed_equipment_space_t;adapted_cargo_t=other.adapted_cargo_t;adapted_equipment_space_t=other.adapted_equipment_space_t
	fuel_system=other.fuel_system.duplicate(true);fuel_extension_upgraded=other.fuel_extension_upgraded
func duplicate_session()->RefCounted:
	var candidate:RefCounted=get_script().new()
	if not candidate.restore(snapshot()):return null
	candidate.fuel_extension_upgraded=fuel_extension_upgraded;return candidate
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
func advance_fuel_seconds(dt:float,context:Dictionary)->Dictionary:
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
func fuel_state()->Dictionary:
	if not valid():return {"source_mode":true,"reason":"Недопустимое состояние топливной системы."}
	var capacity_raw:=Jet.jet_capacity_raw(drive_index);var raw:=int(fuel_system.jet_raw_u32)
	var manual:=Jet.manual_refuel(_jet_state(),capacity_raw) if capacity_raw>=0 else {"ok":false,"accepted":false,"reason":"invalid_capacity"}
	var labels:={"not_evaluated":"Ожидание подходящих условий.","outside_atmosphere":"Для забора нужна атмосфера звезды или газового гиганта.","ineligible_parent_model":"Этот объект не подходит для забора топлива.","too_high":"Слишком большая высота для забора топлива.","too_slow":"Недостаточная скорость для забора топлива.","cooldown":"Подготовка следующего забора.","scooped":"Водород поступает в трюм.","cargo_full":"Трюм заполнен.","no_scoop":"Топливозаборник не установлен."}
	var upgraded:="Реактивная топливная система добавлена к сохранению0.15.0 по начальному профилю корабля; прежний груз и гипертопливо сохранены." if fuel_extension_upgraded else ""
	return {"source_mode":true,"jet_raw_u32":raw,"jet_capacity_raw_u32":maxi(0,capacity_raw),"jet_tonnes":float(raw)/Jet.RAW_PER_TONNE,"jet_capacity_tonnes":float(maxi(0,capacity_raw))/Jet.RAW_PER_TONNE,"jet_percent":float(raw)*100.0/capacity_raw if capacity_raw>0 else (100.0 if raw>0 else 0.0),"jet_above_nominal":raw>capacity_raw,"propulsion_available":propulsion_available(),"forward_propulsion_available":int(thrust_limits_u16()[4])!=0,"thrust_disabled_axes_mask_u8":int(fuel_system.disabled_axes_mask_u8),"thrust_limits_u16":thrust_limits_u16(),"refueller_installed":bool(fuel_system.refueller_installed),"refueller_enabled":bool(fuel_system.refueller_enabled),"can_toggle_refueller":bool(fuel_system.refueller_installed),"toggle_reason":"" if fuel_system.refueller_installed else "Автозаправщик не установлен.","can_manual_refuel":bool(manual.get("ok",false)) and bool(manual.get("accepted",false)),"manual_refuel_reason":_manual_reason(str(manual.get("reason",""))),"scoop_installed":bool(fuel_system.scoop_installed),"atmospheric_shielding_installed":bool(fuel_system.atmospheric_shielding_installed),"starter_shielding_credit_t":starter_shielding_credit(),"heat_s32":int(fuel_system.heat_s32),"heat_label":"Критический перегрев корпуса." if fuel_system.thermal_destruction_requested else "Нагрев корпуса: %d (шкала игры)."%int(fuel_system.heat_s32),"cooldown_u32":int(fuel_system.cooldown_u32),"cooldown_seconds":float(fuel_system.cooldown_u32)/Motion.NOMINAL_TICKS_PER_SECOND,"scoop_status":str(labels.get(str(fuel_system.last_scoop_reason),labels.not_evaluated)) if fuel_system.scoop_installed else labels.no_scoop,"upgrade_notice":upgraded,"initialization_policy":str(fuel_system.initialization_policy),"host_policy":HOST_FUEL_POLICY}
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
