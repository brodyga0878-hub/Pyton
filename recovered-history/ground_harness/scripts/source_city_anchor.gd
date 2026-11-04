extends RefCounted
# F879 raw city placement for the audited positive-clearance ground path.
# No geographic, metre, body-radius normalization or live scene adapter.
# City81..90/96 have zero inner radius, nonempty collision data and a terminated
# F576 extra-probe suffix. Penetration/physics paths fail explicitly here.
const Ground=preload("res://scripts/ground_coordinates.gd")
const Pads=preload("res://scripts/source_ground_pads.gd")
const Point=preload("res://scripts/terrain_surface_point.gd")
const Query=preload("res://scripts/terrain_query.gd")
const SUPPORTED_CITIES:=[81,82,83,84,85,86,87,88,89,90,96]
var terrain:=Point.new()

static func _s32(value:int)->int:return Ground.signed32(value)
static func _s16(value:int)->int:
	var low:=value&65535
	return low-65536 if low>=32768 else low
static func _failure(reason:String)->Dictionary:return {"ok":false,"error":reason}

static func vector64_msb(vector:PackedInt64Array)->int:
	# Actual F1657 inspects signed high words first, with special0/-1 cases;
	# abs(high_word) can differ from the high word of abs(full_int64).
	var high_words:PackedInt64Array=[]
	var use_high:=false
	for value in vector:
		var high:=value>>32
		high_words.append(high)
		if high!=0 and high!=(-1):use_high=true
	var bits:=0
	for axis in range(3):
		var word:=int(high_words[axis]) if use_high else int(vector[axis])&0xffffffff
		if (use_high and word<0) or (not use_high and high_words[axis]<0):word=_s32(-word)
		bits|=word&0xffffffff
	return (32 if use_high else 0)+Query._msb(bits)

static func _position(radial:PackedInt64Array,radius:int,exponent:int)->PackedInt64Array:
	var result:=PackedInt64Array()
	for value in radial:result.append(Point.shift_int64(value*(radius&0xffffffff),exponent-31))
	return result

func _clearance(parent_model:int,uid:int,position:PackedInt64Array,zoom:int,outer:int,inner:int,detail:int)->Dictionary:
	# F579: F1658 truncates to28bits, then enforces zoom-23 minimum scale.
	var scale:=maxi(maxi(0,vector64_msb(position)-28),zoom-23)
	var observer:=PackedInt64Array()
	for value in position:observer.append(_s32(Point.shift_int64(value,-scale)))
	var center:=PackedInt64Array([-observer[0],-observer[1],-observer[2]])
	var distance:=Point.source_length(center)
	var outer_scaled:=_s32(Point.shift_int64(outer,-scale))
	var inner_scaled:=_s32(Point.shift_int64(inner,-scale))
	if _s32(distance-outer_scaled)>=0:return _failure("Original F581 outer bound skips the terrain query")
	if _s32(distance-inner_scaled)<=0:return _failure("Original F581 inner bound enters unsupported penetration physics")
	var result:=terrain.query_point_raw(parent_model,uid,observer,scale,detail,0)
	if result.is_empty():return _failure("Original terrain query could not construct the city probe")
	if not result.altitude_written or result.pending_query_flag!=0:return _failure("Original city clearance was not written by a completed query")
	var altitude:=int(result.altitude_raw_i64)
	if int(result.collision_status)!=(-1) or altitude<=0 or altitude>2147483647:
		return _failure("Original F574 city probe requires an unsupported collision/error path")
	result.ok=true
	result.clearance_i32=altitude
	result.input_position_vec64_raw=position.duplicate()
	return result

func place_raw(parent_model:int,source_uid:int,city_model:int,phase:int,inclination:int,variant:String,graphics_level_raw:=1)->Dictionary:
	if variant not in ["jjffe_sar3","archive_local_sar4"]:return _failure("An explicit reviewed F879 correction variant is required")
	if city_model not in SUPPORTED_CITIES:return _failure("City model is outside the audited F879 ground collision contract")
	if graphics_level_raw<1 or graphics_level_raw>12:return _failure("Source city query detail is outside the bounded graphics range")
	if not terrain.kernel._load_resources():return _failure("Original terrain resources are unavailable")
	var model:Dictionary=Query.resources.models.get(str(parent_model),{})
	if model.is_empty() or not model.get("spherical_provider_eligible",false):return _failure("Parent model is outside the audited uniform planet set")
	var zoom:=int(model.mesh_zoom)
	var outer:=Point.shift_int64(_s16(int(model.interaction_radius_raw)),zoom-8)
	var inner:=Point.shift_int64(_s16(int(model.collision_radius_raw)),zoom-8)
	var matrix:=Pads.matrix_for_angles(phase,inclination)
	var radial:=PackedInt64Array([int(matrix[3]),int(matrix[4]),int(matrix[5])])
	var radius:=_s32(int(model.interaction_radius_raw)-1)
	var exponent:=zoom-8
	var first:=_clearance(parent_model,source_uid,_position(radial,radius,exponent),zoom,outer,inner,graphics_level_raw)
	if not first.ok:return first
	var amount:=int(first.clearance_i32)
	amount=_s32(amount-(amount>>(3 if variant=="jjffe_sar3" else 4)))
	if exponent<0:radius=_s32(radius-_s32(amount<<((-exponent)&31)))
	elif exponent<16:
		radius=_s32(_s32(radius<<(exponent&31))-amount)
		exponent=0
	else:
		exponent-=16
		radius=_s32(_s32(radius<<16)-(amount>>(exponent&31)))
	var second:=_clearance(parent_model,source_uid,_position(radial,radius,exponent),zoom,outer,inner,graphics_level_raw)
	if not second.ok:return second
	amount=int(second.clearance_i32)
	radius=_s32(radius-(_s32(amount<<((-exponent)&31)) if exponent<0 else amount>>(exponent&31)))
	return {"ok":true,"variant":variant,"matrix_q31":matrix,"position_vec64_raw":_position(radial,radius,exponent),"parent_outer_raw_i64":outer,"parent_inner_raw_i64":inner,"passes":[first,second],"graphics_level_raw":graphics_level_raw,"source_units":"original Vec64 raw; no physical-size or geographic adaptation"}
