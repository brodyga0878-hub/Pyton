extends RefCounted
# Uploaded DOS F577 only. The F575 caller supplies the signed relative vector
# and its separate, already-absolute F1664 buffer. This helper neither scans
# collider banks nor selects a response: return0 means inside the tested
# sphere; return−1 also includes equality. Source flags2 is not a hit verdict.
# The DOS nonpositive-shift branch uses parent+138 (outer radius), retaining
# the original behavior instead of JJFFE's later parent+140 correction.
const Ground=preload("res://scripts/ground_coordinates.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Surface=preload("res://scripts/source_ground_surface.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Contact=preload("res://scripts/source_surface_contact.gd")
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const CONTRACT:="dos-firstenc-f577-spherical-contact-helper-v1"
const OBJECT_BYTES:=338
const MASK:=0xffffffff
const GLOBAL_KEYS:=["collision_flags_u8","altitude_s64"]

static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _s32(value:int)->int:return Ground.signed32(value)
static func _vector(value:Variant)->bool:
	if not (value is Array or value is PackedInt64Array) or value.size()!=3:return false
	for component:Variant in value:
		if not component is int:return false
	return true
static func _valid(body:PackedByteArray,parent:PackedByteArray,context:Dictionary)->bool:
	if body.size()!=OBJECT_BYTES or parent.size()!=OBJECT_BYTES:return false
	if not _vector(context.get("relative_position_s64")) or not _vector(context.get("absolute_position_s64")):return false
	if not context.get("globals") is Dictionary:return false
	for key:String in GLOBAL_KEYS:
		if not context.globals.has(key):return false
	return _whole(context.globals.collision_flags_u8,0,255) and context.globals.altitude_s64 is int
static func _reject(body:PackedByteArray,parent:PackedByteArray)->Dictionary:
	return {"ok":false,"error":"invalid_raw_spherical_contact_context","body_after":body.duplicate(),"parent_after":parent.duplicate(),"globals_after":{},"global_writes":{},"inside_sphere":false,"source_contract":CONTRACT,"source_sha256":SOURCE_SHA}
static func _square_high(value:int)->int:
	# F1522 is the high DWORD of a signed32 square; the source adds three
	# such words modulo32 before its unsigned radius comparison.
	var signed:=_s32(value)
	return (signed*signed)>>32

static func classify(body:PackedByteArray,parent:PackedByteArray,context:Dictionary)->Dictionary:
	if not _valid(body,parent,context):return _reject(body,parent)
	var relative:=PackedInt64Array(context.relative_position_s64)
	var absolute:=PackedInt64Array(context.absolute_position_s64)
	var globals:Dictionary=context.globals.duplicate(true)
	var combined:=(parent.decode_u32(0x13c)|((absolute[0]>>32)&MASK)|((absolute[1]>>32)&MASK)|((absolute[2]>>32)&MASK))&MASK
	var shift:=0
	if combined!=0:
		shift=Gravity._msb(combined)+3
	else:
		combined=(parent.decode_u32(0x138)|(absolute[0]&MASK)|(absolute[1]&MASK)|(absolute[2]&MASK))&MASK
		shift=Gravity._msb(combined)-29
	var scaled:=relative.duplicate();var radius:=0
	if shift<=0:
		# Original small-coordinate path: add only the low DWORDs, mixing
		# body INNER and parent OUTER radii, then shift only vector LOW words.
		var count:=(-shift)&31
		radius=_s32(_s32(body.decode_u32(0x140)+parent.decode_u32(0x138))<<count)
		for axis in range(3):scaled[axis]=Contact._s64(_s32((relative[axis]&MASK)<<count),relative[axis]>>32)
	else:
		# F1660 shifts the by-value signed vector; F1333 sums two OUTER64
		# radii, then F1341 shifts that sum arithmetically by the same amount.
		for axis in range(3):scaled[axis]=Surface._shift64(relative[axis],-shift)
		var radius64:=Contact._add64(body.decode_s64(0x138),parent.decode_s64(0x138))
		radius=_s32(Surface._shift64(radius64,-shift))
	var distance_squared:=0
	for component:int in scaled:distance_squared=_s32(distance_squared+_square_high(component))
	var radius_squared:=_square_high(radius)
	var inside:=radius_squared>(distance_squared&MASK)
	var writes:Dictionary={}
	if not inside:
		globals.collision_flags_u8=int(globals.collision_flags_u8)|2
		var distance:=_s32(Point.source_square_root((distance_squared&MASK)>>1)*2)
		if distance<0:distance=0
		globals.altitude_s64=Surface._shift64(distance,shift)
		if parent.decode_u32(0x140)!=parent.decode_u32(0x138):globals.collision_flags_u8=int(globals.collision_flags_u8)|1
		writes={"collision_flags_u8":int(globals.collision_flags_u8),"altitude_s64":int(globals.altitude_s64)}
	return {"ok":true,"error":"","return_s32":0 if inside else -1,"inside_sphere":inside,"distance_squared_s32":distance_squared,"globals_after":globals,"global_writes":writes,"body_after":body.duplicate(),"parent_after":parent.duplicate(),"relative_position_s64":relative,"absolute_position_s64":absolute,"scaled_position_s64":scaled,"shift_s32":shift,"radius_s32":radius,"radius_squared_s32":radius_squared,"source_contract":CONTRACT,"source_sha256":SOURCE_SHA,"scope":"Complete DOS F577 helper only; no collider scan, F575 caller decision, F578 response, HP mutation or terrain classifier."}
