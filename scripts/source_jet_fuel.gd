extends RefCounted
# Uploaded DOS F938 fuel tail, F929 depletion/automatic feeder and F289 manual
# refuelling. The other F938 shield/hull/cooldown transitions are not applied.
# Every operation returns an independent state; callbacks are observations,
# never invocations of the original GUI or another gameplay model.
const DATA_PATH:="res://data/ffe_fuel.json"
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const CONTRACT:="dos-firstenc-f929-f938-tail-f289-jet-v1"
const SOURCE_POLICY:="uploaded-dos-f929-three-positive-limits-no-automatic-restore"
const MASK:=0xffffffff
const RAW_PER_TONNE:=0x20000000
const MANUAL_NEAR_FULL_MARGIN:=0x01999999
const TICKS_PER_UPDATE_SECOND:=0xc22e
const STATE_KEYS:=["jet_raw_u32","object_index_u8","drive_index_s8","npc_fuel_u8","auto_refueller","thrust_u16","cached_thrust_u16","player_object_index_u32","status_u16","cargo_s32","hydrogen_u16","military_u16","waste_u16"]
static var _tables:Dictionary={}
static var _mutex:=Mutex.new()

static func _number(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _s32(value:int)->int:
	value&=MASK;return value-0x100000000 if value>=0x80000000 else value
static func _hex(value:Variant)->bool:
	if not value is String or value.length()%2!=0:return false
	for character:String in value:
		if not character in "0123456789abcdefABCDEF":return false
	return true
static func _load()->bool:
	_mutex.lock()
	if not _tables.is_empty():_mutex.unlock();return true
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	if not data is Dictionary or data.get("schema")!=1 or data.get("source_sha256")!=SOURCE_SHA or not data.get("tables_hex") is Dictionary:_mutex.unlock();return false
	var candidate:Dictionary={}
	for key:String in ["5111","6266"]:
		var raw:Variant=data.tables_hex.get(key)
		if not _hex(raw) or raw.length()!=120:_mutex.unlock();return false
		candidate[key]=str(raw).hex_decode()
	_tables=candidate;_mutex.unlock();return true
static func jet_capacity_raw(drive_index:int)->int:
	if drive_index<0 or drive_index>=15 or not _load():return -1
	return int(_tables["5111"].decode_u32(drive_index*4))
static func npc_initial_jet_raw(drive_index:int)->int:
	# Exact isolated F773 DATA6266 lookup/SHL24; not a player-starter policy.
	if drive_index<0 or drive_index>=15 or not _load():return -1
	return (int(_tables["6266"].decode_u32(drive_index*4))<<24)&MASK

static func valid_state(state:Dictionary)->bool:
	for key:String in STATE_KEYS:
		if not state.has(key):return false
	for key:String in ["jet_raw_u32","player_object_index_u32"]:
		if not _number(state[key],0,MASK):return false
	for key:String in ["object_index_u8","npc_fuel_u8"]:
		if not _number(state[key],0,255):return false
	if not _number(state.drive_index_s8,-128,127) or not state.auto_refueller is bool or not _number(state.cargo_s32,-2147483648,2147483647):return false
	for key:String in ["status_u16","hydrogen_u16","military_u16","waste_u16"]:
		if not _number(state[key],0,65535):return false
	for key:String in ["thrust_u16","cached_thrust_u16"]:
		if not state[key] is Array or state[key].size()!=6:return false
		for value:Variant in state[key]:
			if not _number(value,0,65535):return false
	return true
static func _rejected(state:Dictionary,reason:String)->Dictionary:
	return {"ok":false,"accepted":false,"changed":false,"state":state.duplicate(true),"reason":reason,"events":[],"callbacks":[],"source_contract":CONTRACT,"source_sha256":SOURCE_SHA}
static func _result(original:Dictionary,state:Dictionary,reason:String,events:Array=[],callbacks:Array=[],accepted:=true,refilled:=false)->Dictionary:
	var available:=false;var disabled:=0
	for index in range(6):
		if int(state.thrust_u16[index])!=0:available=true
		elif int(state.cached_thrust_u16[index])!=0:disabled|=1<<index
	return {"ok":true,"accepted":accepted,"changed":state!=original,"state":state,"reason":reason,"events":events,"callbacks":callbacks,"refilled":refilled,"propulsion_available":available,"disabled_axes_mask_u8":disabled,"source_policy":SOURCE_POLICY,"source_contract":CONTRACT,"source_sha256":SOURCE_SHA}

static func consumption(mass_s16:int,commands_s16:Array,step_s32:int)->Dictionary:
	if not _number(mass_s16,-32768,32767) or not _number(step_s32,-2147483648,2147483647) or commands_s16.size()!=3:return {"ok":false,"amount_u32":0,"reason":"invalid_source_domain"}
	var magnitude:=0
	for value:Variant in commands_s16:
		if not _number(value,-32768,32767):return {"ok":false,"amount_u32":0,"reason":"invalid_source_domain"}
		# MOVSX/NEG is a32-bit operation; -32768 therefore becomes+32768.
		magnitude+=absi(int(value))
	var amount:=_s32(mass_s16*magnitude)>>9
	amount=_s32(amount*step_s32)
	return {"ok":true,"amount_u32":amount&MASK,"amount_s32":amount,"command_magnitude":magnitude,"source_procedure":"F938 fuel tail","step_units":"F152/F151 whole display seconds, each49710 master ticks; player F1007 and NPC F707/F706/F732 share this event quantum"}

static func cadence(current_tick_u32:int,last_processed_tick_u32:int)->Dictionary:
	if not _number(current_tick_u32,0,MASK) or not _number(last_processed_tick_u32,0,MASK):return {"ok":false,"reason":"invalid_source_clock"}
	var delta:=(current_tick_u32-last_processed_tick_u32)&MASK
	@warning_ignore("integer_division")
	var seconds:int=delta/TICKS_PER_UPDATE_SECOND
	return {"ok":true,"whole_seconds":seconds,"last_processed_tick_u32":(last_processed_tick_u32+seconds*TICKS_PER_UPDATE_SECOND)&MASK,"delta_u32":delta,"remainder_ticks":delta%TICKS_PER_UPDATE_SECOND,"source_procedure":"F152 display-second event boundary"}

static func cooling(heat_s32:int,step_s32:int,shielding:bool=false)->Dictionary:
	if not _number(heat_s32,-2147483648,2147483647) or not _number(step_s32,-2147483648,2147483647):return {"ok":false,"reason":"invalid_source_domain"}
	# F1007's initial signed32 heat field. Zero skips cooling altogether;
	# subtraction and the source negative clamp happen after32-bit truncation.
	var result:=heat_s32
	if heat_s32!=0:result=maxi(0,_s32(heat_s32-_s32(step_s32<<(9 if shielding else 7))))
	return {"ok":true,"heat_s32":result,"source_procedure":"F1007 thermal head only","source_step_units":"whole display seconds from F152/F151"}

static func consume(input:Dictionary,amount_u32:int)->Dictionary:
	if not valid_state(input):return _rejected(input,"invalid_state")
	if not _number(amount_u32,0,MASK):return _rejected(input,"invalid_amount")
	var state:=input.duplicate(true);var player:=int(state.object_index_u8)==int(state.player_object_index_u32)
	if int(state.jet_raw_u32)>amount_u32:
		state.jet_raw_u32=(int(state.jet_raw_u32)-amount_u32)&MASK
		# DOS has a direct jump to return here. The later JJFFE cached-six-axis
		# restoration is a verified separate patch, not the reference behavior.
		return _result(input,state,"spent")
	# Exact F929 JNA includes equality and empty+zero demand. Unspent debit
	# beyond the old tank is not carried into the newly transferred tonne.
	state.jet_raw_u32=0
	if player and state.auto_refueller:
		if int(state.drive_index_s8)<10 and int(state.hydrogen_u16)!=0:
			state.hydrogen_u16=(int(state.hydrogen_u16)-1)&65535
			state.cargo_s32=_s32(int(state.cargo_s32)-1);state.jet_raw_u32=RAW_PER_TONNE
			return _result(input,state,"auto_hydrogen",[],[],true,true)
		if int(state.drive_index_s8)>=10 and int(state.military_u16)!=0:
			state.military_u16=(int(state.military_u16)-1)&65535
			state.waste_u16=(int(state.waste_u16)+1)&65535;state.jet_raw_u32=RAW_PER_TONNE
			return _result(input,state,"auto_military",[],[],true,true)
	elif not player and int(state.npc_fuel_u8)!=0:
		state.npc_fuel_u8=(int(state.npc_fuel_u8)-1)&255;state.jet_raw_u32=RAW_PER_TONNE
		return _result(input,state,"npc_refill",[],[],true,true)
	var events:Array=[]
	if player and (int(state.status_u16)&1)==0:
		state.status_u16=int(state.status_u16)|1;events.append(0x9907)
	# Actual DOS clears only the BC/C0/C4 positive-direction words. Preserve
	# the reverse-direction words; JJFFE additionally clears BE/C2/C6.
	for index in [0,2,4]:state.thrust_u16[index]=0
	return _result(input,state,"empty",events,[],false)

static func fuel_step(input:Dictionary,mass_s16:int,commands_s16:Array,step_s32:int)->Dictionary:
	var demand:=consumption(mass_s16,commands_s16,step_s32)
	if not demand.ok:return _rejected(input,"invalid_source_domain")
	var result:=consume(input,int(demand.amount_u32));result["consumption"]=demand
	return result

static func manual_refuel(input:Dictionary,capacity_raw_u32:int)->Dictionary:
	if not valid_state(input):return _rejected(input,"invalid_state")
	var drive_index:=int(input.drive_index_s8)&255
	if drive_index>=15 or not _number(capacity_raw_u32,0,MASK):return _rejected(input,"invalid_capacity_domain")
	var state:=input.duplicate(true);var previous:=int(state.jet_raw_u32)
	if previous>=((capacity_raw_u32-MANUAL_NEAR_FULL_MARGIN)&MASK):return _result(input,state,"near_full",[0x99e3],[287],false)
	# F289's drive test is UNSIGNED, unlike F929's signed byte comparison.
	if drive_index<10:
		if int(state.hydrogen_u16)==0:return _result(input,state,"no_fuel",[],[293],false)
		state.hydrogen_u16=(int(state.hydrogen_u16)-1)&65535;state.cargo_s32=_s32(int(state.cargo_s32)-1)
	else:
		if int(state.military_u16)==0:return _result(input,state,"no_fuel",[],[293],false)
		state.military_u16=(int(state.military_u16)-1)&65535;state.waste_u16=(int(state.waste_u16)+1)&65535
	state.status_u16=int(state.status_u16)&0xfffe;state.thrust_u16=state.cached_thrust_u16.duplicate()
	var after:=(previous+RAW_PER_TONNE)&MASK;var events:Array=[]
	if after>capacity_raw_u32 or after<=previous:after=capacity_raw_u32;events.append(0x99e3)
	state.jet_raw_u32=after
	return _result(input,state,"manual_refuel",events,[287],true,true)
