class_name FlightModel
extends RefCounted

const Catalog = preload("res://scripts/ship_catalog.gd")
var catalog := Catalog.new()
const EconomyCatalog = preload("res://scripts/economy_catalog.gd")
var economy_catalog := EconomyCatalog.new()
var goods := {"medicines":2,"food":0,"metals":0,"machines":0,"electronics":0,"luxury":0}
var equipment: Array = []
var mission_cargo := {}
var story_cargo := 0
var ship_id := "cobra"
var external_view := false

const ACCELERATION := 18.0
const MAX_SPEED := 600.0
const DOCK_RADIUS := 100.0
const DOCK_SPEED := 12.0
const STATION := Vector3(0, 0, -2500)
var original_port:=false # Derived from planetary context, never trusted from a save.
var station_available := true
var surface_mode := false
var combat_active := false
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var attitude := Quaternion.IDENTITY
var target_speed := 0.0
var assisted := true
var autopilot := false
var docked := false
var hull := 100.0
var credits := 1000
var cargo: int:
	get: return int(goods.get("medicines",0))
	set(value): goods["medicines"]=value
var delivered := false
var shots := 0
var last_notice := ""

func profile() -> Dictionary:
	return catalog.get_ship(ship_id)

func acceleration() -> float:
	return float(profile().acceleration)*(1.2 if "engine" in equipment else 1.0)

func cargo_capacity() -> int:
	return int(profile().cargo_capacity)-equipment_space()

func jump_range() -> float:
	return float(profile().jump_range)*(1.25 if "hyperdrive" in equipment else 1.0)

func change_ship(id: String) -> bool:
	var candidate:=catalog.get_ship(id)
	if original_port or candidate.is_empty() or not docked or hull<=0 or total_cargo()>int(candidate.cargo_capacity)-equipment_space(): return false
	ship_id=id
	velocity=Vector3.ZERO
	target_speed=0
	autopilot=false
	return true

func forward() -> Vector3:
	return -(Basis(attitude).z)

func step(dt: float, steering: Vector2, roll: float = 0.0, gravity := Vector3.ZERO, lift := 0.0) -> void:
	if docked or hull<=0:
		return
	if not station_available: autopilot = false
	if autopilot:
		var offset := STATION - position
		var distance := offset.length()
		var direction := offset.normalized()
		if distance > 1.0:
			var desired_basis := Basis.looking_at(direction, Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT)
			attitude = attitude.slerp(desired_basis.get_rotation_quaternion(), minf(dt * 2.5, 1.0)).normalized()
		var available:=maxf(0,acceleration()-gravity.length())
		var approach_speed := minf(300.0, sqrt(available * maxf(distance - 60.0, 0.0)))
		target_speed = approach_speed
		velocity = velocity.move_toward(direction * approach_speed, available * dt)
		if gravity.length()>acceleration():velocity+=gravity.normalized()*(gravity.length()-acceleration())*dt
		if can_dock():
			dock()
			return
	else:
		var local_rotation := Quaternion(Vector3.UP, -steering.x * dt * float(profile().turn_rate)) * Quaternion(Vector3.RIGHT, -steering.y * dt * float(profile().turn_rate)) * Quaternion(Vector3.FORWARD, roll * dt * float(profile().turn_rate)/1.2)
		attitude = (attitude * local_rotation).normalized()
		if assisted:
			velocity = velocity.move_toward(forward() * target_speed+Vector3.UP*clampf(lift,-1,1)*60, maxf(0,acceleration()-gravity.length()) * dt)
			if gravity.length()>acceleration(): velocity+=gravity.normalized()*(gravity.length()-acceleration())*dt
		else:
			# Inertial mode: the slider sets axial thrust, not a hidden velocity clamp.
