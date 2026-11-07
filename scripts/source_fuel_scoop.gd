extends RefCounted
# Original F1033/F1034 after the caller supplies an actual F569 result.
# Geometry, SI conversion, timer scheduling and the F953 destruction callback
# belong to the caller. This kernel neither invents an atmosphere nor fills
# the separate reaction tank. Every caller-owned buffer is copied.
const CONTRACT:="jjffe-f1033-after-f569-fuel-scoop-v1"
const ASM_SHA:="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a"
const GAME_BYTES:=544
const OBJECT_BYTES:=338
const MASK:=0xffffffff
const HYDROGEN_COMMODITY_INDEX:=19
const SCOOP_EQUIPMENT_CA_MASK:=0x10
const ALTITUDE_LIMIT_RAW:=30000000
const SPEED_MINIMUM_RAW:=9000
const COOLDOWN_RESET_RAW:=149130

static func _integer(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _s32(value:int)->int:
	value&=MASK;return value-0x100000000 if value>=0x80000000 else value
static func _s8(value:int)->int:
	value&=255;return value-256 if value>=128 else value
static func _rejected(reason:String,game:PackedByteArray,object:PackedByteArray)->Dictionary:
	return {"ok":false,"reason":reason,"source_contract":CONTRACT,"game":game.duplicate(),"object":object.duplicate()}

static func evaluate_buffers(game_bytes:PackedByteArray,object_bytes:PackedByteArray,contact:Dictionary,step_u32:Variant,sound_mode_s8:Variant=0)->Dictionary:
	if game_bytes.size()!=GAME_BYTES or object_bytes.size()!=OBJECT_BYTES:return _rejected("invalid_buffers",game_bytes,object_bytes)
	if not _integer(step_u32,0,MASK) or not _integer(sound_mode_s8,-128,127):return _rejected("invalid_step_or_sound_mode",game_bytes,object_bytes)
	if not _integer(contact.get("flags_u8"),0,255) or not _integer(contact.get("altitude_raw_s32"),-2147483648,2147483647) or not _integer(contact.get("parent_model_u32"),0,MASK):return _rejected("invalid_contact",game_bytes,object_bytes)
	var game:=game_bytes.duplicate();var object:=object_bytes.duplicate()
	var flags:=int(contact.flags_u8);var altitude:=int(contact.altitude_raw_s32);var model:=int(contact.parent_model_u32)
	var events:={"refresh":0,"notify":0,"sound":0,"destroy":0,"message_code":0,"message_amount":0,"notify_first":0,"notify_second":0}
	game[0x212]=flags;game.encode_u32(0xdc,(0x7fffffff if altitude==-1 else altitude)&MASK)
	var hud_altitude:=_s32(game.decode_u32(0xdc));var control_flags:=int(game.decode_u16(0xc6))
	if hud_altitude>=12000000:
		if int(game[0xe8])!=0x2c:
			if control_flags&0x40!=0 and int(sound_mode_s8)<0:events.refresh+=1
			control_flags|=0x40;game.encode_u16(0xc6,control_flags)
	else:
		if control_flags&0x40!=0 and int(sound_mode_s8)<0:events.refresh+=1
		control_flags&=0xffbf;game.encode_u16(0xc6,control_flags)
	var reason:="outside_atmosphere"
	if flags&1==0:
		# F1034: without the cargo life-support mask, livestock/slaves spoil
		# into their two source goods. This does not alter total cargo mass.
		if int(object[0xca])&2==0:
			for pair:Array in [[0x14c,0x146],[0x14a,0x13c]]:
				if game.decode_u16(pair[0])!=0:
					game.encode_u16(pair[0],(int(game.decode_u16(pair[0]))-1)&65535)
					game.encode_u16(pair[1],(int(game.decode_u16(pair[1]))+1)&65535)
	elif model<134 or model>148:reason="ineligible_parent_model"
	else:
		var eligible:=true
		if int(object[0xca])&SCOOP_EQUIPMENT_CA_MASK!=0:
			if altitude>ALTITUDE_LIMIT_RAW:reason="too_high";eligible=false
			elif _s32(game.decode_u32(0xd8))<SPEED_MINIMUM_RAW:reason="too_slow";eligible=false
			elif int(game.decode_u32(0x1e8))>int(step_u32):reason="cooldown";eligible=false
			else:
				if _s32(game.decode_u32(0x120))<_s32(game.decode_u32(0x118)):
					game.encode_u32(0x120,(_s32(game.decode_u32(0x120))+1)&MASK)
					game.encode_u16(0x15a,(int(game.decode_u16(0x15a))+1)&65535)
					events.notify=1;events.sound=1;events.message_code=0x9906;events.message_amount=int(game.decode_u16(0x15a));events.notify_first=0x16;events.notify_second=0x8e13;reason="scooped"
				else:reason="cargo_full"
		else:reason="no_scoop"
		# The original early return also skips stellar heat when a fitted
		# scoop fails altitude/speed/cooldown. Missing scoop or a full hold
		# still sets the timer and enters this thermal branch.
		if eligible:
			game.encode_u32(0x1e8,COOLDOWN_RESET_RAW)
			if model>=137:
				var before:=_s32(game.decode_u32(0x1ec));var increment:=int(step_u32)>>(8 if model>=140 else 10)
				var after:=_s32(before+increment);game.encode_u32(0x1ec,after&MASK)
				if before>after:events.destroy=1
	var result:={"ok":true,"reason":reason,"source_contract":CONTRACT,"asm_sha256":ASM_SHA,"game":game,"object":object,"return_s32":_s8(flags),"events":events,"scooped_tonnes":1 if events.message_code==0x9906 else 0,"destruction_requested":events.destroy!=0,"f569_geometry_validated":false,"cooldown_decremented":false}
	result.merge(_unpack(game,object));return result

static func _unpack(game:PackedByteArray,object:PackedByteArray)->Dictionary:
	return {"flags_c6_u16":int(game.decode_u16(0xc6)),"view_e8_u8":int(game[0xe8]),"equipped_ca_u8":int(object[0xca]),"cargo_used_s32":_s32(game.decode_u32(0x120)),"capacity_s32":_s32(game.decode_u32(0x118)),"hydrogen_u16":int(game.decode_u16(0x15a)),"cooldown_u32":int(game.decode_u32(0x1e8)),"heat_s32":_s32(game.decode_u32(0x1ec)),"speed_s32":_s32(game.decode_u32(0xd8)),"hud_altitude_s32":_s32(game.decode_u32(0xdc)),"flags212_u8":int(game[0x212]),"goods4_u16":int(game.decode_u16(0x13c)),"goods9_u16":int(game.decode_u16(0x146)),"goods11_u16":int(game.decode_u16(0x14a)),"goods12_u16":int(game.decode_u16(0x14c))}

static func evaluate(state:Dictionary,contact:Dictionary)->Dictionary:
	var fields:={"flags_c6_u16":[0,65535,0],"view_e8_u8":[0,255,0],"equipped_ca_u8":[0,255,0],"cargo_used_s32":[-2147483648,2147483647,0],"capacity_s32":[-2147483648,2147483647,0],"hydrogen_u16":[0,65535,0],"cooldown_u32":[0,MASK,0],"heat_s32":[-2147483648,2147483647,0],"speed_s32":[-2147483648,2147483647,0],"step_u32":[0,MASK,0],"sound_mode_s8":[-128,127,0],"goods4_u16":[0,65535,0],"goods9_u16":[0,65535,0],"goods11_u16":[0,65535,0],"goods12_u16":[0,65535,0]}
	var values:Dictionary={}
	for key:String in fields:
		var value:Variant=state.get(key,fields[key][2])
		if not _integer(value,fields[key][0],fields[key][1]):return {"ok":false,"reason":"invalid_state","source_contract":CONTRACT}
		values[key]=int(value)
	var game:=PackedByteArray();game.resize(GAME_BYTES);var object:=PackedByteArray();object.resize(OBJECT_BYTES)
	game.encode_u16(0xc6,values.flags_c6_u16);game[0xe8]=values.view_e8_u8;object[0xca]=values.equipped_ca_u8
	for key:String in {"cargo_used_s32":0x120,"capacity_s32":0x118,"cooldown_u32":0x1e8,"heat_s32":0x1ec,"speed_s32":0xd8}:
		var offset:int={"cargo_used_s32":0x120,"capacity_s32":0x118,"cooldown_u32":0x1e8,"heat_s32":0x1ec,"speed_s32":0xd8}[key];game.encode_u32(offset,int(values[key])&MASK)
	game.encode_u16(0x15a,values.hydrogen_u16)
	for pair:Array in [["goods4_u16",0x13c],["goods9_u16",0x146],["goods11_u16",0x14a],["goods12_u16",0x14c]]:game.encode_u16(pair[1],values[pair[0]])
	return evaluate_buffers(game,object,contact,values.step_u32,values.sound_mode_s8)
