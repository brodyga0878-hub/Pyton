extends RefCounted
# Conservative isotropic phone controller bound for the original Cobra38.
# This is a versioned F601 nominal sample, not the full original ship controller.
const Bridge=preload("res://scripts/source_physics_bridge.gd")
const PROFILE:="source-cobra38-conservative-f601-mobile-v1"
const EXE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const SPEC_SHA:="b0f77d55db624b023accc8542f6b990d95515ab3e4c23bdd4e1d6e30c4cf2656"
const REFERENCE_TICKS:=49710
static var _description:Dictionary={}

static func _s16(value:int)->int:return value-65536 if value>=32768 else value
static func _s32(value:int)->int:
	var word:=value&0xffffffff
	return word-0x100000000 if word>=0x80000000 else word
static func _sha(bytes:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()

static func _nominal_sample(raw_thrust:int)->Dictionary:
	# Exact F601 small-step branch at an identity Q31 matrix, starting at rest.
	# 49710>>3=6213; (32767*6213)>>15=6212 before multiplying by thrust.
	# All source Cobra axis values stay inside signed32 arithmetic here.
	var time_factor:=(0x7fff*(REFERENCE_TICKS>>3))>>15
	var velocity_q16:=_s32(_s32(time_factor*raw_thrust)<<1)
	var duration:=float(REFERENCE_TICKS)/Bridge.TICKS_PER_SECOND
	var acceleration:=float(velocity_q16)*(Bridge.VELOCITY_UNIT_MPS/65536.0)/duration
	return {"raw_thrust_s16":raw_thrust,"velocity_q16":velocity_q16,"velocity_s32":velocity_q16>>16,"fraction_u16":velocity_q16&65535,"acceleration_mps2":acceleration}

static func describe(ship_id:String="cobra")->Dictionary:
	if ship_id!="cobra":return {}
	if not _description.is_empty():return _description.duplicate(true)
	var path:="res://data/ffe_ship_registry.json"
	if not FileAccess.file_exists(path):return {}
	var resource:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not resource is Dictionary or resource.get("source_sha256")!=EXE_SHA or not resource.get("ships") is Array:return {}
	var original:Dictionary={}
	for row:Variant in resource.ships:
		if row is Dictionary and int(row.get("index",-1))==38:original=row;break
	var spec:=str(original.get("spec_hex","")).hex_decode()
	if spec.size()!=24 or _sha(spec)!=SPEC_SHA:return {}
	var main:=_s16(spec.decode_u16(0));var retro:=_s16(spec.decode_u16(2))
	if main<=0 or retro>=0:return {}
	# F1533 copies the reverse word to retro/down/right and its negation to
	# up/left; the main word supplies forward. Use the weakest of all six.
	var raw_axes:=[-retro,retro,-retro,retro,main,retro]
	var samples:Array=[];var bound:=INF
	for raw:int in raw_axes:
		var sample:=_nominal_sample(raw);samples.append(sample)
		bound=minf(bound,absf(float(sample.acceleration_mps2)))
	if not is_finite(bound) or bound<=0:return {}
	_description={"profile":PROFILE,"ship_id":"cobra","source_model_index":38,"source_sha256":EXE_SHA,"source_spec_sha256":SPEC_SHA,"source_spec_hex":spec.hex_encode(),"source_spec_offset":str(original.get("spec_offset","")),"source_mass_tonnes":int(spec.decode_u16(6)),"source_internal_capacity_tonnes":int(spec.decode_u16(8)),"source_axis_order":["left","right","up","down","forward","retro"],"source_axis_thrust_s16":raw_axes,"source_axis_samples":samples,"acceleration_mps2":bound,"bound_policy":"minimum_six_source_axis_magnitudes_nominal_identity_sample","reference_step_ticks":REFERENCE_TICKS,"ticks_per_second":Bridge.TICKS_PER_SECOND,"velocity_unit_mps":Bridge.VELOCITY_UNIT_MPS,"physics_bridge_contract":Bridge.CONTRACT,"original_controller":false,"equipment_multiplier":1.0}
	return _description.duplicate(true)

static func acceleration(ship_id:String="cobra")->float:
	var profile:=describe(ship_id)
	return float(profile.acceleration_mps2) if not profile.is_empty() else 0.0
