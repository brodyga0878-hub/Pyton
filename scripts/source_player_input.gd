extends RefCounted
# Original DOS F1037/F1038/F1039/F1040/F1121. GUI accumulation and F931 are
# explicit observed boundaries, not Android input or a full event handler.
const PROFILE:="dos-firstenc-player-input-v1"
const SOURCE_EXE_SHA256:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const ROOT_BYTES:=0x4000
const OBJECT_BYTES:=338
const MASK:=0xffffffff
const GLOBAL_KEYS:=["input_gate_s8","system_frame_ticks_u32","speed_multiplier_u32","forward_key_u8","reverse_key_u8","throttle_key_u8","aux_key1_u8","aux_key2_u8","mouse_buttons_u8"]
const OPERATIONS:=["throttle_f1037","accumulate_f1038","view_f1039","auxiliary_f1040","speed_increment_f1121"]
static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and float(value)==floorf(float(value))
static func _s32(value:int)->int:return (value&0x7fffffff)-(value&0x80000000)
static func _s16(value:int)->int:return (value&0x7fff)-(value&0x8000)
static func _s8(value:int)->int:return (value&0x7f)-(value&0x80)
static func _globals(value:Variant)->bool:
	if not value is Dictionary or value.size()!=GLOBAL_KEYS.size():return false
	for key:String in GLOBAL_KEYS:
		if not value.has(key):return false
	if not _whole(value.input_gate_s8,-128,127):return false
	for key:String in ["system_frame_ticks_u32","speed_multiplier_u32"]:
		if not _whole(value[key],0,MASK):return false
	for key:String in ["forward_key_u8","reverse_key_u8","throttle_key_u8","aux_key1_u8","aux_key2_u8","mouse_buttons_u8"]:
		if not _whole(value[key],0,255):return false
	return true
static func _copy_globals(value:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in GLOBAL_KEYS:result[key]=int(value[key])
	return result
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"GUI_input_collected":false,"F931_effects_executed":false,"JJFFE_key_path_selected":false}
static func _increment(value:int,state:Dictionary)->int:
	var word:int=value&MASK;var count:=0
	while true:
		if (word&0x80000000)!=0:
			word=0x7ffeffff;break
		word=(word<<1)&MASK;count+=1
		if count>=5:break
	word=(word>>16)+1
	var multiplier:int=state.speed_multiplier_u32
	if (multiplier&255)>16:
		word=((word*multiplier)&MASK)>>4
		if word>0x7fff:word=0x7fff
	return ((word*int(state.system_frame_ticks_u32))&MASK)>>6
static func speed_increment_raw(value:Variant,globals:Variant)->Dictionary:
	if not _whole(value,-0x80000000,0x7fffffff) or not _globals(globals):return _reject("invalid_speed_increment_context")
	return {"ok":true,"value_u32":_increment(int(value),globals),"profile":PROFILE}
static func _add_word(bytes:PackedByteArray,offset:int,value:int)->void:
	bytes.encode_u16(offset,(int(bytes.decode_u16(offset))+value)&65535)
static func _accumulate(body:PackedByteArray,root:PackedByteArray,gui:int,requests:Array,order:Array)->void:
	order.append("F1038")
	var previous:int=root.decode_u32(0xd0)
	order.append("F1445");requests.append({"kind":"F1445","return_u32":gui})
	root.encode_u32(0xd0,gui)
	var dx:=_s16(((gui&65535)-(previous&65535))<<6)
	var dy:=_s16(((gui>>16)-(previous>>16))<<6)
	var view:=int(root[0xea])
	if view==2 or view==3:
		_add_word(root,0x204,dx);_add_word(root,0x206,-dy)
		var pitch:int=root.decode_s16(0x206)
		if pitch<0:
			root[0xea]=2
			if pitch<=-0x4000:root.encode_u16(0x206,0xc001)
		elif _s8(int(body[0xd1]))>=4:
			root[0xea]=3
			if pitch>=0x4000:root.encode_u16(0x206,0x3fff)
		else:root.encode_u16(0x206,0xffff)
		return
	if root[0x3f54]==0:dx=_s16(-dx)
	if root[0x3f55]==0:dy=_s16(-dy)
	_add_word(body,0xb0,dy)
	if root[0x3f56]==0:_add_word(body,0xb4,-dx)
	elif (int(root[0x212])&0x20)==0:
		_add_word(body,0xb2,dx)
		if root.decode_s32(0xdc)<=0x2625a00:_add_word(body,0xb4,-dy)

static func execute(operation:Variant,body:Variant,root:Variant,globals:Variant,gui_accumulator_u32:Variant=0,speed_input_s32:Variant=0)->Dictionary:
	if not operation is String or operation not in OPERATIONS or not body is PackedByteArray or body.size()!=OBJECT_BYTES or not root is PackedByteArray or root.size()!=ROOT_BYTES or not _globals(globals) or not _whole(gui_accumulator_u32,0,MASK) or not _whole(speed_input_s32,-0x80000000,0x7fffffff):return _reject("invalid_raw_input_context")
	var candidate:PackedByteArray=body.duplicate();var copied_root:PackedByteArray=root.duplicate();var state:=_copy_globals(globals)
	var requests:Array=[];var order:Array=[];var value:=0
	match operation:
		"speed_increment_f1121":order.append("F1121");value=_increment(int(speed_input_s32),state)
		"accumulate_f1038":_accumulate(candidate,copied_root,int(gui_accumulator_u32),requests,order)
		"view_f1039":
			order.append("F1039")
			if int(copied_root[0xea]) in [2,3]:_accumulate(candidate,copied_root,int(gui_accumulator_u32),requests,order)
		"auxiliary_f1040":
			order.append_array(["F1040","F1445"]);requests.append({"kind":"F1445","return_u32":int(gui_accumulator_u32)})
			var view:=int(copied_root[0xea])
			if view!=5:
				var route:=int(state.throttle_key_u8)==0 or (int(state.mouse_buttons_u8)&0x10)==0 or (int(state.mouse_buttons_u8)&0x20)==0
				if route or (int(state.aux_key1_u8)!=0 and int(state.aux_key2_u8)!=0):
					var mode:=0 if view in [4,6] else _s8(view)
					order.append("F931");requests.append({"kind":"F931","mode_s32":mode,"body_hex_at_call":candidate.hex_encode()})
		"throttle_f1037":
			order.append("F1037")
			if int(state.input_gate_s8)<0:
				if (int(copied_root[0xe9])&1)==0:
					var speed:int=copied_root.decode_s32(0x1b8)
					if int(state.forward_key_u8)==0 and speed<0:
						copied_root.encode_u32(0x1b8,0)
						_accumulate(candidate,copied_root,int(gui_accumulator_u32),requests,order)
						return _result(candidate,copied_root,state,requests,order,value)
					if int(state.forward_key_u8)==0:
						order.append("F1121");speed=_s32(speed+_increment(speed,state))
						if speed<0:speed=0x7fffffff
						copied_root.encode_s32(0x1b8,speed)
					if int(state.reverse_key_u8)==0:
						if speed<=0:
							if (int(copied_root[0xe9])&0x80)==0:
								speed=_s32(speed-(int(state.system_frame_ticks_u32)>>8))
								if speed>0:speed=-0x80000000
								copied_root.encode_s32(0x1b8,speed)
						else:
							copied_root[0xe9]=int(copied_root[0xe9])|0x80
							order.append("F1121");var original:=speed;speed=_s32(speed-_increment(speed,state))
							if original<speed or speed<0:speed=0
							copied_root.encode_s32(0x1b8,speed)
					else:copied_root[0xe9]=int(copied_root[0xe9])&0x7f
				_accumulate(candidate,copied_root,int(gui_accumulator_u32),requests,order)
	return _result(candidate,copied_root,state,requests,order,value)
static func _result(body:PackedByteArray,root:PackedByteArray,globals:Dictionary,requests:Array,order:Array,value:int)->Dictionary:
	return {"ok":true,"profile":PROFILE,"body_after":body,"root_after":root,"globals_after":globals,"requests":requests,"source_order":order,"value_u32":value,"live_owners_changed":false,"GUI_input_collected":false,"F931_effects_executed":false,"JJFFE_key_path_selected":false,"full_player_cycle":false}
