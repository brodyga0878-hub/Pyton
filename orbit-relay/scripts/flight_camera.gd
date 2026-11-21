extends RefCounted
## Presentation-only shot changes. World trajectory and flight inputs remain in FlightSim.

enum Mode { EXTERIOR, COCKPIT, REAR, OBSERVER, MISSILE }

const Text := preload("res://scripts/flight_text.gd")
const MODE_NAMES := ["Снаружи", "Кабина", "Назад", "Обзор", "Ракета"]
const MODE_KEYS := ["CAMERA_EXTERIOR", "CAMERA_COCKPIT", "CAMERA_REAR", "CAMERA_OBSERVER", "CAMERA_MISSILE"]
const FIELD_OF_VIEW := [67.0, 73.0, 69.0, 59.0, 66.0]
const BASIC_MODE_COUNT := 3
const STARTER_SEAT := Vector3(0.0, 0.58, -0.73)
const FREIGHTER_SEAT := Vector3(0.0, 0.92, -1.28)
const HULL_CLEARANCE := 4.5
const TRANSITION_SECONDS := 0.42

var mode: int = Mode.EXTERIOR
var field_of_view: float = FIELD_OF_VIEW[Mode.EXTERIOR]
var cockpit_mix := 0.0
var _elapsed := TRANSITION_SECONDS
var _initialized := false
var _local_pose := Transform3D.IDENTITY
var _from_pose := Transform3D.IDENTITY
var _from_field_of_view: float = FIELD_OF_VIEW[Mode.EXTERIOR]
var _from_cockpit := 0.0
var _target_rotation := Quaternion.IDENTITY
var _has_target_rotation := false


func select(next: int) -> bool:
	if next < 0 or next >= MODE_NAMES.size() or next == mode:
		return false
	_from_pose = _local_pose
	_from_field_of_view = field_of_view
	_from_cockpit = cockpit_mix
	_elapsed = 0.0
	_has_target_rotation = false
	mode = next
	return true


func cycle() -> void:
	select(next_basic(mode))


static func next_basic(current: int) -> int:
	return (current + 1) % BASIC_MODE_COUNT if current < BASIC_MODE_COUNT else Mode.EXTERIOR


static func translated_name(current: int) -> String:
	return Text.text(MODE_KEYS[current])


func transitioning() -> bool:
	return _elapsed < TRANSITION_SECONDS


func sample(ship: Transform3D, exterior: Transform3D, delta: float, freighter := false,
		cut := false, special := Transform3D.IDENTITY) -> Transform3D:
	var ship_relative := _seat_pose(freighter)
	if mode == Mode.EXTERIOR:
		ship_relative = ship.affine_inverse() * exterior
	elif mode in [Mode.OBSERVER, Mode.MISSILE]:
		ship_relative = ship.affine_inverse() * special
	var goal := ship_relative
	var target_fov: float = FIELD_OF_VIEW[mode]
	var target_cockpit := float(mode == Mode.COCKPIT)
	if cut or not _initialized:
		_initialized = true
		_elapsed = TRANSITION_SECONDS
	elif is_finite(delta) and delta > 0.0:
		_elapsed = minf(TRANSITION_SECONDS, _elapsed + delta)
	if not transitioning():
		_local_pose = goal
		field_of_view = target_fov
		cockpit_mix = target_cockpit
		return exterior if mode == Mode.EXTERIOR else ship * goal

	var blend := smoothstep(0.0, 1.0, _elapsed / TRANSITION_SECONDS)
	var from_rotation := _from_pose.basis.get_rotation_quaternion()
	var target_rotation := goal.basis.get_rotation_quaternion()
	var previous_goal := _target_rotation if _has_target_rotation else from_rotation
	# Keep the same side of the turn when a moving goal crosses the 180-degree seam.
	_target_rotation = -target_rotation if previous_goal.dot(target_rotation) < 0.0 else target_rotation
	_has_target_rotation = true
	var orientation := from_rotation.slerpni(_target_rotation, blend)
	_local_pose = Transform3D(Basis(orientation), _from_pose.origin.lerp(goal.origin, blend))
	field_of_view = lerpf(_from_field_of_view, target_fov, blend)
	cockpit_mix = lerpf(_from_cockpit, target_cockpit, blend)
	return ship * _local_pose


func shows_hull() -> bool:
	return (mode == Mode.EXTERIOR and not transitioning()) or _local_pose.origin.length_squared() >= HULL_CLEARANCE * HULL_CLEARANCE


func shows_forward_aim() -> bool:
	if mode in [Mode.OBSERVER, Mode.MISSILE]:
		return false
	return (mode == Mode.EXTERIOR and not transitioning()) or _local_pose.basis.z.dot(Vector3.BACK) >= 0.5


func _seat_pose(freighter: bool) -> Transform3D:
	var seat := FREIGHTER_SEAT if freighter else STARTER_SEAT
	var direction := Basis(Vector3.UP, PI) if mode == Mode.REAR else Basis.IDENTITY
	return Transform3D(direction, seat)
