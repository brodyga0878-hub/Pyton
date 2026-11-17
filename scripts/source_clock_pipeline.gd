extends RefCounted
# Exact DOS main-loop counter admission and calendar event order. Millisecond
# collection, F1418, physics dispatch and event effects are separate owners.
const Calendar=preload("res://scripts/source_clock.gd")
const SCHEMA:="starfrontier-source-clock-pipeline-v1"
const PROFILE:="dos-firstenc-main-clock-admission-v1"
const MASK:=0xffffffff
const STATE_KEYS:=["clock_low_u32","clock_day_u32","deadline_low_u32","deadline_day_u32","accelerated_counter_u32","frame_ticks_u32","system_counter_u32","system_frame_ticks_u32","system_total_u32"]
const SNAPSHOT_KEYS:=["schema","version","profile","generation","state","last_witness","snapshot_sha256"]
var _state:Dictionary={}
var _generation:=0
var _last_witness:Dictionary={}
# Prepared counter deliveries belong to one live owner revision. This token is
# intentionally not portable: a load must never revive a wall-time delivery.
var _revision:=0

static func _whole(value:Variant,maximum:int=MASK)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=maximum and float(value)==floorf(float(value))
static func _keys(value:Dictionary,expected:Array)->bool:
	if value.size()!=expected.size():return false
	for key:Variant in expected:
		if not value.has(key):return false
	return true
static func _valid_state(value:Variant)->bool:
	if not value is Dictionary or not _keys(value,STATE_KEYS):return false
	for key:String in STATE_KEYS:
		if not _whole(value[key]):return false
	return true
static func _valid_events(value:Variant)->bool:
	if not value is Array or value.size()>3:return false
	for event:Variant in value:
		if not event is Dictionary or not _keys(event,["event_u32","param_u32"]) or not _whole(event.event_u32) or int(event.event_u32) not in [0x15,0x10,0x0f] or not _whole(event.param_u32,0):return false
	return true
static func _valid_witness(value:Variant,generation_value:int)->bool:
	return value is Dictionary and _keys(value,["before_generation","before_state","accelerated_delivery_u32","system_delivery_u32","events"]) and _whole(value.get("before_generation"),0x7ffffffe) and int(value.before_generation)==generation_value-1 and _valid_state(value.get("before_state")) and _whole(value.get("accelerated_delivery_u32")) and _whole(value.get("system_delivery_u32")) and _valid_events(value.get("events"))
static func _canonical(value:Dictionary)->Dictionary:
	return JSON.parse_string(JSON.stringify(value))
static func _hash(value:Dictionary)->String:
	return JSON.stringify(_canonical(value),"",true).sha256_text()
static func _state_copy(value:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in STATE_KEYS:result[key]=int(value[key])
	return result
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"clock_advanced":false,"event_effects_applied":false}

static func consume(state:Variant)->Dictionary:
	if not _valid_state(state):return _reject("invalid_raw_clock_state")
	var candidate:=_state_copy(state)
	var old_day:int=candidate.clock_day_u32
	var increment:int=candidate.accelerated_counter_u32
	candidate.frame_ticks_u32=increment
	candidate.accelerated_counter_u32=0
	candidate.clock_low_u32=(int(candidate.clock_low_u32)+increment)&MASK
	if increment>int(candidate.clock_low_u32):candidate.clock_day_u32=(old_day+1)&MASK
	var events:Array=[]
	# Preserve the actual uploaded DOS predicate. JJFFE's Groundhog-day FIX
	# additionally admits a higher day with a smaller low word; DOS does not.
	if int(candidate.clock_day_u32)>=int(candidate.deadline_day_u32) and int(candidate.clock_low_u32)>=int(candidate.deadline_low_u32):
		candidate.clock_low_u32=int(candidate.deadline_low_u32)
		candidate.clock_day_u32=int(candidate.deadline_day_u32)
		events.append({"event_u32":0x15,"param_u32":0})
		candidate.deadline_day_u32=MASK
	if old_day!=int(candidate.clock_day_u32):
		if int(candidate.clock_day_u32)%7==0:events.append({"event_u32":0x10,"param_u32":0})
		events.append({"event_u32":0x0f,"param_u32":0})
	candidate.system_frame_ticks_u32=int(candidate.system_counter_u32)
	candidate.system_counter_u32=0
	candidate.system_total_u32=(int(candidate.system_total_u32)+int(candidate.system_frame_ticks_u32))&MASK
	return {"ok":true,"profile":PROFILE,"state_after":candidate,"events":events,"clock_advanced":increment!=0,"clock_changed":candidate.clock_low_u32!=state.clock_low_u32 or candidate.clock_day_u32!=state.clock_day_u32,"event_effects_applied":false,"original_dos_deadline_predicate":true,"jjffe_groundhog_fix_applied":false,"F1418_executed":false,"full_world_event_dispatch_executed":false}

func is_active()->bool:return _valid_state(_state)
func raw_state()->Dictionary:return _state_copy(_state) if is_active() else {}
func generation()->int:return _generation
func presentation()->Dictionary:
	return Calendar.decode(_state.clock_day_u32,_state.clock_low_u32) if is_active() else {}
func configure(state:Variant,profile:String=PROFILE)->bool:
	if profile!=PROFILE or not _valid_state(state):return false
	_state=_state_copy(state);_generation=0;_last_witness={};_revision+=1;return true

func prepare(accelerated_ticks:Variant=0,system_ticks:Variant=0)->Dictionary:
	if not is_active() or not _whole(accelerated_ticks) or not _whole(system_ticks) or _generation>=0x7fffffff:return _reject("invalid_clock_counter_delivery")
	var supplied:=raw_state()
	supplied.accelerated_counter_u32=(int(supplied.accelerated_counter_u32)+int(accelerated_ticks))&MASK
	supplied.system_counter_u32=(int(supplied.system_counter_u32)+int(system_ticks))&MASK
	var admitted:=consume(supplied)
	if not admitted.ok:return admitted
	var witness:Dictionary={"before_generation":_generation,"before_state":raw_state(),"accelerated_delivery_u32":int(accelerated_ticks),"system_delivery_u32":int(system_ticks),"events":admitted.events.duplicate(true)}
	var candidate=get_script().new()
	candidate._state=_state_copy(admitted.state_after)
	candidate._generation=_generation+1
	candidate._last_witness=witness.duplicate(true)
	return {"ok":true,"profile":PROFILE,"candidate_clock":candidate,"owner_instance_id":get_instance_id(),"owner_revision":_revision,"before_generation":_generation,"before_state_sha256":_hash(_state),"receipt":witness,"events":admitted.events.duplicate(true),"clock_advanced":admitted.clock_advanced,"event_effects_applied":false,"counter_delivery_policy":"caller-supplied-u32-counters-not-F1418-millisecond-collection"}

func commit(prepared:Variant)->bool:
	if not prepared is Dictionary or prepared.get("ok")!=true or prepared.get("profile")!=PROFILE or not prepared.get("candidate_clock") is RefCounted:return false
	if not prepared.get("owner_instance_id") is int or prepared.owner_instance_id!=get_instance_id() or not prepared.get("owner_revision") is int or prepared.owner_revision!=_revision:return false
	var candidate:RefCounted=prepared.candidate_clock
	if candidate.get_script()!=get_script() or candidate==self or not is_active() or not _whole(prepared.get("before_generation"),0x7fffffff) or int(prepared.before_generation)!=_generation or prepared.get("before_state_sha256")!=_hash(_state):return false
	var check=get_script().new()
	if not check.restore(candidate.snapshot()) or check._generation!=_generation+1 or _hash(check._last_witness.before_state)!=_hash(_state) or not _valid_witness(prepared.get("receipt"),_generation+1) or not _valid_events(prepared.get("events")) or _hash(prepared.receipt)!=_hash(candidate._last_witness) or _hash({"events":prepared.events})!=_hash({"events":candidate._last_witness.events}):return false
	_state=check.raw_state();_generation=check._generation;_last_witness=check._last_witness.duplicate(true);_revision+=1;return true

func snapshot()->Dictionary:
	if not is_active():return {}
	var result:Dictionary={"schema":SCHEMA,"version":1,"profile":PROFILE,"generation":_generation,"state":raw_state(),"last_witness":_last_witness.duplicate(true)}
	result.snapshot_sha256=_hash(result)
	return result

func restore(data:Variant)->bool:
	if not data is Dictionary or not _keys(data,SNAPSHOT_KEYS) or data.get("schema")!=SCHEMA or not _whole(data.get("version"),1) or int(data.version)!=1 or data.get("profile")!=PROFILE or not _whole(data.get("generation"),0x7fffffff) or not _valid_state(data.get("state")) or not data.get("last_witness") is Dictionary:return false
	var witness:Dictionary=data.last_witness
	if int(data.generation)==0:
		if not witness.is_empty():return false
	else:
		if not _valid_witness(witness,int(data.generation)):return false
		var before:=_state_copy(witness.before_state)
		before.accelerated_counter_u32=(int(before.accelerated_counter_u32)+int(witness.accelerated_delivery_u32))&MASK
		before.system_counter_u32=(int(before.system_counter_u32)+int(witness.system_delivery_u32))&MASK
		var replay:=consume(before)
		if not replay.ok or _hash(replay.state_after)!=_hash(data.state) or _hash({"events":replay.events})!=_hash({"events":witness.events}):return false
	var unsigned:Dictionary=data.duplicate(true);unsigned.erase("snapshot_sha256")
	if not data.snapshot_sha256 is String or data.snapshot_sha256!=_hash(unsigned):return false
	_state=_state_copy(data.state);_generation=int(data.generation);_last_witness=witness.duplicate(true);_revision+=1;return true
