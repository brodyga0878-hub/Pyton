extends RefCounted
## Narrow source MB4 record kernel. Main, physical deployment and inventory
## integration are deliberately separate consumers; no resource is spawned here.
## F243 event0x10 and normal model110 F247/F252 have independent host controls.

const SCHEMA := "starfrontier-source-mining-machine-v1"
const PROFILE := "jjffe-normal-mb4-f243-f247-v1"
const SOURCE_ASM_SHA256 := "d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a"
const F243_SHA256 := "c0c696f4e9a2c4050ce08e67d1d3b0523007d19341c44e3026c7f71d1be2aaf0"
const F247_SHA256 := "7636581c1e11aa2f5d344dcd9e8537714abe8a761a1ebf982bb9f8a67b7901e4"
const F252_SHA256 := "d99a86cc96ff25ac575d266b1a54a7640ea9c7aa53bacd7ec9c8b737aefd27a1"
const COMMODITY_BY_PROSPECT := [0, 0, 0, 18, 18, 18, 15, 15, 16]
const HOPPER_CAPACITY_TONNES := 10
const RETRIEVAL_SPACE_TONNES := 30
const MAX_BATCH_EVENTS := 2147483647
const SNAPSHOT_KEYS := ["schema", "version", "profile", "source_assembly_sha256", "f243_sha256", "f247_sha256", "f252_sha256", "hopper_tonnes", "remaining_raw", "prospect"]

var _configured := false
var _hopper := 0
var _remaining := 0
var _prospect := 0


func configure(hopper: Variant, remaining_raw: Variant, prospect: Variant) -> bool:
	if not _integer(hopper, 0, HOPPER_CAPACITY_TONNES) or not _integer(remaining_raw, 0, 255) or not _integer(prospect, 0, 8):
		return false
	_hopper = int(hopper)
	_remaining = int(remaining_raw)
	_prospect = int(prospect)
	_configured = true
	return true


func hopper_tonnes() -> int:
	return _hopper


func remaining_raw() -> int:
	return _remaining


func prospect() -> int:
	return _prospect


func apply_weekly_event() -> Dictionary:
	return apply_weekly_events(1)


func apply_weekly_events(event_count: Variant) -> Dictionary:
	if not _configured or not _integer(event_count, 0, MAX_BATCH_EVENTS):
		return {"ok": false, "produced_tonnes": 0}
	# Original F243 uses signed-byte JNG: 0x80..0xff are not positive reserves.
	# In particular 0xff is NOT silently converted to infinite water production.
	var produced := 0
	if _remaining > 0 and _remaining < 128 and _hopper < HOPPER_CAPACITY_TONNES:
		produced = mini(int(event_count), mini(_remaining, HOPPER_CAPACITY_TONNES - _hopper))
	_hopper += produced
	_remaining -= produced
	return {"ok": true, "produced_tonnes": produced, "hopper_tonnes": _hopper, "remaining_raw": _remaining}


func request_load(free_cargo_tonnes: Variant) -> Dictionary:
	if not _configured or not _integer(free_cargo_tonnes, 0, 2147483647):
		return {"ok": false}
	# This returns the exact normal-MB4 F247 inventory delta/request. A caller
	# must atomically apply the delta to its own inventory. No Main consumer exists.
	var loaded := 0
	var retrieval := false
	var message := 0x98e3
	var near_flag := 16
	if _hopper > 0:
		loaded = mini(_hopper, int(free_cargo_tonnes))
		message = 0xa20f if int(free_cargo_tonnes) >= _hopper else 0xa210
		_hopper -= loaded
	elif int(free_cargo_tonnes) >= RETRIEVAL_SPACE_TONNES:
		retrieval = true
		near_flag = 0
		message = 0xa20d
	return {"ok": true, "loaded_tonnes": loaded, "commodity_index": int(COMMODITY_BY_PROSPECT[_prospect]), "hopper_tonnes": _hopper, "remaining_raw": _remaining, "retrieval_animation_requested": retrieval, "near_machine_flag_after": near_flag, "message_ffcode": message}


func snapshot() -> Dictionary:
	if not _configured:
		return {}
	return {"schema": SCHEMA, "version": 1, "profile": PROFILE, "source_assembly_sha256": SOURCE_ASM_SHA256, "f243_sha256": F243_SHA256, "f247_sha256": F247_SHA256, "f252_sha256": F252_SHA256, "hopper_tonnes": _hopper, "remaining_raw": _remaining, "prospect": _prospect}


func restore(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != SNAPSHOT_KEYS.size():
		return false
	for key in SNAPSHOT_KEYS:
		if not value.has(key):
			return false
	if value.schema != SCHEMA or not _integer(value.version, 1, 1) or value.profile != PROFILE or value.source_assembly_sha256 != SOURCE_ASM_SHA256 or value.f243_sha256 != F243_SHA256 or value.f247_sha256 != F247_SHA256 or value.f252_sha256 != F252_SHA256:
		return false
	return configure(value.hopper_tonnes, value.remaining_raw, value.prospect)


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	# JSON numbers are floats in Godot; accept exact finite integral values only.
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number >= float(minimum) and number <= float(maximum) and number == floor(number)
