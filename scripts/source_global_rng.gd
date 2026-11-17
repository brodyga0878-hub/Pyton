extends RefCounted
# F1530 and F922 share the original GameRoot words at +0x24/+0x28. The kernel
# returns a private Root copy; no independent seed or host RNG is introduced.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const PROFILE:="dos-firstenc-shared-root-rng-v1"
const ROOT_BYTES:=0x4000
const MASK:=0xffffffff
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false}
static func _rotate(value:int,count:int)->int:return ((value<<count)|(value>>(32-count)))&MASK
static func execute(root:Variant,operation:Variant,bound_u32:Variant=null)->Dictionary:
	if not root is PackedByteArray or root.size()!=ROOT_BYTES or not operation is String or operation not in ["F1530","F922"]:return _reject("invalid_shared_rng_context")
	if (operation=="F1530" and bound_u32!=null) or (operation=="F922" and not Frame._whole(bound_u32,0,MASK)):return _reject("invalid_shared_rng_bound")
	var candidate:PackedByteArray=root.duplicate();var first:=candidate.decode_u32(0x24);var second:=candidate.decode_u32(0x28);var value:=0
	if operation=="F1530":
		candidate.encode_u32(0x24,(first+_rotate(second^0x1234567f,25))&MASK)
		candidate.encode_u32(0x28,_rotate(first,13));value=candidate.decode_u32(0x24)&65535
	else:
		var rotated:=_rotate(second,5)
		candidate.encode_u32(0x24,_rotate((first+second+rotated)&MASK,16));candidate.encode_u32(0x28,rotated)
		value=((int(bound_u32)*(candidate.decode_u32(0x24)&65535))&MASK)>>16
	return {"ok":true,"profile":PROFILE,"root_after":candidate,"return_u32":value,"return_s32":Ground.signed32(value),"source_order":[operation],"F1530_body_executed":operation=="F1530","F922_body_executed":operation=="F922","live_owners_changed":false,"Main_integrated":false}
