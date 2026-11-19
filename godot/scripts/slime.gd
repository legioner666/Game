extends CharacterBody3D
## Original procedural amorphous organism. No imported models, rigs or textures.
## Body stays identifiable when every appendage is withdrawn.

const ROOTS := [
	Vector3(-0.52, 0.18, 0.38), Vector3(0.42, 0.20, 0.52),
	Vector3(-0.60, 0.14, 0.06), Vector3(0.55, 0.15, 0.08),
	Vector3(-0.51, 0.12, -0.36), Vector3(0.41, 0.19, -0.48),
	Vector3(-0.14, 0.24, 0.50), Vector3(0.12, 0.15, -0.58)
]
const LENGTHS := [3.5, 2.8, 4.3, 3.2, 3.9, 3.1, 2.9, 3.7]
const SAFE_HEIGHT := 0.61

var movement := Vector2.ZERO
var movement_speed := 4.5
var frozen := false
var work_targets: Array[Vector3] = []
var ability_anchor := Vector3.ZERO
var has_ability_anchor := false
var dash_duration := 0.0
var dash_heading := Vector3.ZERO
var dash_speed := 18.0

var _supports: Array[MeshInstance3D] = []
var _working: Array[MeshInstance3D] = []
var _anchors: Array[Vector3] = []
var _extensions: Array[float] = []
var _plants: Array[bool] = []
var _lobes: Array[MeshInstance3D] = []
var _clock := 0.0
var _last_position := Vector3.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.15
	var shape := CapsuleShape3D.new()
	shape.height = 1.15
	shape.radius = 0.55
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	var slime_mat := StandardMaterial3D.new()
	slime_mat.albedo_color = Color(0.07, 0.042, 0.12)
	slime_mat.metallic = 0.05
	slime_mat.roughness = 0.3
	var lobe_sizes := [
		Vector3(1.35, 0.55, 1.12), Vector3(0.87, 0.40, 0.78),
		Vector3(0.64, 0.33, 0.55), Vector3(0.56, 0.30, 0.49)
	]
	var lobe_positions := [
		Vector3(0, 0.12, 0), Vector3(-0.42, 0.06, 0.28),
		Vector3(0.45, -0.06, -0.11), Vector3(-0.20, 0.17, -0.36)
	]
	for i in range(lobe_sizes.size()):
		var mesh := SphereMesh.new()
		mesh.radial_segments = 16
		mesh.rings = 8
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = slime_mat
		node.scale = lobe_sizes[i]
		node.position = lobe_positions[i]
		add_child(node)
		_lobes.append(node)
	for i in range(ROOTS.size()):
		var arm := _make_arm(0.17 * (1.0 + float(i % 3) * 0.13), slime_mat)
		_supports.append(arm)
		_anchors.append(global_position)
		_extensions.append(0.0)
		_plants.append(false)
	for i in range(3):
		_working.append(_make_arm(0.19 + float(i) * 0.03, slime_mat))
	_last_position = global_position

func _make_arm(radius: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = 1.0
	mesh.bottom_radius = radius
	mesh.top_radius = 0.008
	mesh.radial_segments = 7
	mesh.rings = 1
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material
	item.visible = false
	get_tree().current_scene.add_child(item)
	return item

func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector3.ZERO
		return
	if dash_duration > 0.0:
		dash_duration = maxf(0.0, dash_duration - delta)
		velocity = dash_heading * dash_speed
	else:
		var input_dir := Vector3(movement.x, 0, movement.y).limit_length(1.0)
		velocity = input_dir * movement_speed * (1.0 - 0.07 * cos(_clock * 11.0))
	velocity.y = -2.0
	move_and_slide()
	_clock += delta
	_update_tendrils(delta)
	_last_position = global_position

func begin_dash(direction: Vector3) -> bool:
	if direction.length_squared() < 0.01:
		return false
	dash_heading = direction.normalized()
	dash_duration = 0.32
	has_ability_anchor = true
	ability_anchor = global_position + dash_heading * 5.7
	return true

func reset_contacts() -> void:
	dash_duration = 0.0
	has_ability_anchor = false
	work_targets.clear()
	for i in range(_supports.size()):
		_extensions[i] = 0.0
		_plants[i] = false
		_supports[i].visible = false
	for arm in _working:
		arm.visible = false
	_last_position = global_position

func _update_tendrils(delta: float) -> void:
	if dash_duration <= 0.0:
		has_ability_anchor = false
	var planar_velocity := Vector2(velocity.x, velocity.z)
	var speed := planar_velocity.length()
	var heading := Vector3(velocity.x, 0.0, velocity.z).normalized()
	if heading.length_squared() < 0.001:
		heading = Vector3.FORWARD
	for i in range(_lobes.size()):
		_lobes[i].scale.y = (0.50 + 0.07 * sin(_clock * 2.8 + i)) if i == 0 else _lobes[i].scale.y
	var roots_count := _supports.size()
	for i in range(roots_count):
		var root := global_position + ROOTS[i]
		var phase := fposmod(_clock * (0.75 + speed * 0.14) + float(i) * 0.175, 1.0)
		var planted := speed > 0.12 and phase < 0.43 and not has_ability_anchor
		if planted and not _plants[i]:
			var radial := Vector3(ROOTS[i].x, 0, ROOTS[i].z).normalized()
			_anchors[i] = global_position + radial * LENGTHS[i] + heading * (0.5 + float(i % 3) * 0.2)
			_anchors[i].y = 0.12
		_plants[i] = planted
		_extensions[i] = move_toward(_extensions[i], 1.0 if planted else 0.0, delta * 5.0)
		_draw_between(_supports[i], root, root.lerp(_anchors[i], _extensions[i]))
	for i in range(_working.size()):
		var root := global_position + Vector3((float(i) - 1.0) * 0.25, 0.22, 0.3)
		var show := false
		var target := root
		if i == 0 and has_ability_anchor:
			target = ability_anchor
			show = true
		elif i < work_targets.size():
			target = work_targets[i]
			show = true
		_draw_between(_working[i], root, target if show else root)

func _draw_between(arm: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var delta := b - a
	if delta.length_squared() < 0.004:
		arm.visible = false
		return
	arm.visible = true
	var orientation := Quaternion(Vector3.UP, delta.normalized())
	arm.global_transform = Transform3D(Basis(orientation).scaled(Vector3(1.0, delta.length(), 1.0)), (a + b) * 0.5)

func _exit_tree() -> void:
	for arm in _supports:
		if is_instance_valid(arm):
			arm.queue_free()
	for arm in _working:
		if is_instance_valid(arm):
			arm.queue_free()
