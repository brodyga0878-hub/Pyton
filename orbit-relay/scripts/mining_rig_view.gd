extends Node3D
## One physical module follows the ship and deploys at the current deposit.

var _rig: Node3D
var _bit: Node3D
var _indicator: StandardMaterial3D
var _sparks: MultiMeshInstance3D
var _spark_angles: Array[float] = []


func sync(ship_pose: Transform3D, mining_spot: Vector3, phase: int, progress: float, seconds: float) -> void:
	if _rig == null:
		_make_rig()
	var stow := to_local(ship_pose * Vector3(0.86, 0.42, 0.14))
	var deposit := to_local(mining_spot)
	var deploy_fraction := 0.0
	match phase:
		1:
			deploy_fraction = smoothstep(0.0, 1.0, progress)
		2, 3:
			deploy_fraction = 1.0
		4:
			deploy_fraction = 1.0 - smoothstep(0.0, 1.0, progress)
	_rig.position = stow.lerp(deposit, deploy_fraction)
	_rig.position.z += sin(PI * deploy_fraction) * 2.4
	_rig.basis = ship_pose.basis.slerp(Basis.IDENTITY, deploy_fraction).scaled(Vector3.ONE * lerpf(0.43, 1.0, deploy_fraction))
	_indicator.albedo_color = Color("#8bf4c1") if phase == 3 else Color("#fabb64")
	_bit.rotation.z = seconds * 12.0 if phase == 2 else 0.0
	_bit.position.z = -0.54 - 0.34 * smoothstep(0.02, 0.27, progress) if phase == 2 else -0.32
	_sparks.visible = phase == 2
	if _sparks.visible:
		for index in range(_spark_angles.size()):
			var t := fposmod(seconds * 1.5 + float(index) * 0.171, 1.0)
			var angle := _spark_angles[index]
			var radius := 0.32 + t * 1.45
			var height := 0.80 * sin(PI * t) + 0.04
			var at := deposit - Vector3(0, 0, 1.0) + Vector3(cos(angle) * radius, sin(angle) * radius, height)
			var size := lerpf(0.11, 0.025, t)
			_sparks.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), at))


func _make_rig() -> void:
	_rig = Node3D.new()
	add_child(_rig)
	var shell := _paint(Color("#db9b42"))
	var support := _paint(Color("#293944"))
	var drill := _paint(Color("#b8c1be"))
	_indicator = _paint(Color("#fabb64"), true)
	_box(_rig, shell, Vector3(0, 0, 0.0), Vector3(1.62, 1.64, 0.70))
	_box(_rig, support, Vector3(0, 0, 0.40), Vector3(1.10, 1.13, 0.19))
	_box(_rig, _indicator, Vector3(0.0, -0.08, 0.504), Vector3(0.62, 0.28, 0.04))
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			_box(_rig, support, Vector3(x * 0.83, y * 0.81, -0.34), Vector3(0.21, 0.23, 0.78), x * y * 0.52)
			_box(_rig, drill, Vector3(x * 0.90, y * 0.88, -0.69), Vector3(0.49, 0.43, 0.13), x * y * 0.23)
	_bit = Node3D.new()
	_rig.add_child(_bit)
	_box(_bit, drill, Vector3.ZERO, Vector3(0.24, 0.67, 0.56))
	_box(_bit, drill, Vector3.ZERO, Vector3(0.61, 0.24, 0.45))
	var spark := BoxMesh.new()
	spark.size = Vector3.ONE
	spark.material = _paint(Color("#ffbd72"), true)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = spark
	batch.instance_count = 14
	for index in range(batch.instance_count):
		_spark_angles.append(TAU * fposmod(float(index) * 0.381966, 1.0))
	_sparks = MultiMeshInstance3D.new()
	_sparks.multimesh = batch
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.visible = false
	add_child(_sparks)


func _paint(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 0.68
	if unshaded:
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return paint


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _box(parent: Node3D, paint: Material, at: Vector3, size: Vector3, turn: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add_mesh(parent, mesh, paint, at).rotation.z = turn
