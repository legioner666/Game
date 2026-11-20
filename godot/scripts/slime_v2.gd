extends CharacterBody3D
## Parasite Evolution 0.2 — an original, organic silhouette.
## The broad body stays visible with retracted tentacles. Legs animate independently
## and use two organic tapered sections, with persistent ground contact even at idle.

const ROOTS := [
	Vector3(-0.62, 0.04, 0.55), Vector3(0.57, 0.10, 0.61),
	Vector3(-0.78, 0.10, 0.20), Vector3(0.77, 0.05, 0.15),
	Vector3(-0.75, 0.13, -0.29), Vector3(0.69, 0.10, -0.38),
	Vector3(-0.41, 0.19, -0.63), Vector3(0.32, 0.08, -0.68),
	Vector3(-0.20, 0.04, 0.73), Vector3(0.11, 0.11, 0.76)
]
const LENGTHS := [3.3, 2.6, 3.8, 3.2, 3.4, 4.0, 2.7, 3.3, 2.5, 2.9]
const DARK := Color(0.055, 0.035, 0.089)
const BIO := Color(0.14, 0.90, 0.70)

var movement := Vector2.ZERO
var movement_speed := 4.5
var frozen := false
var work_targets: Array[Vector3] = []
var ability_anchor := Vector3.ZERO
var has_ability_anchor := false
var dash_duration := 0.0
var dash_heading := Vector3.ZERO
var dash_speed := 18.0

var _clock := 0.0
var _last_position := Vector3.ZERO
var _body: Node3D
var _shells: Array[MeshInstance3D] = []
var _shell_scales: Array[Vector3] = []
var _legs: Array[Dictionary] = []
var _whips: Array[MeshInstance3D] = []
var _hit_flash := 0.0
var _pulse := 0.0
var _slime_material: ShaderMaterial

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.2
	var shape := CapsuleShape3D.new()
	shape.radius = 0.60
	shape.height = 1.25
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.06
	add_child(collider)
	_body = Node3D.new()
	_body.name = "Living mass"
	add_child(_body)
	_slime_material = ShaderMaterial.new()
	var surface := Shader.new()
	surface.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 body_color : source_color = vec4(0.065, 0.044, 0.13, 1.0);
uniform vec3 bioluminescence : source_color = vec3(0.07, 0.63, 0.51);
uniform float pulse = 0.0;
void vertex() {
	float ripple = sin(TIME * 2.0 + VERTEX.x * 4.1 + VERTEX.z * 3.3);
	VERTEX.xyz += NORMAL * (0.015 + 0.022 * ripple);
}
void fragment() {
	float pattern = sin(UV.x * 18.0 + UV.y * 7.0 + 0.55 * sin(TIME + UV.y * 12.0));
	ALBEDO = body_color.rgb * (0.94 + 0.13 * pattern);
	ROUGHNESS = 0.31;
	METALLIC = 0.10;
	float edge = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	EMISSION = bioluminescence * (edge * 0.40 + pulse * 0.55);
}
"""
	_slime_material.shader = surface
	var positions := [
		Vector3(0.0, 0.12, 0.0), Vector3(-0.36, 0.08, 0.29),
		Vector3(0.44, -0.10, -0.20), Vector3(-0.20, 0.15, -0.51),
		Vector3(0.16, 0.11, 0.51), Vector3(-0.61, -0.11, -0.16),
		Vector3(0.47, -0.14, 0.29)
	]
	var sizes := [
		Vector3(1.45, 0.69, 1.21), Vector3(0.86, 0.53, 0.91),
		Vector3(0.80, 0.46, 0.75), Vector3(0.72, 0.43, 0.65),
		Vector3(0.63, 0.43, 0.58), Vector3(0.55, 0.38, 0.62),
		Vector3(0.58, 0.42, 0.61)
	]
	var sphere := SphereMesh.new()
	sphere.radial_segments = 20
	sphere.rings = 12
	for i in range(sizes.size()):
		var lobe := MeshInstance3D.new()
		lobe.mesh = sphere
		lobe.material_override = _slime_material
		lobe.position = positions[i]
		lobe.scale = sizes[i]
		_body.add_child(lobe)
		_shells.append(lobe)
		_shell_scales.append(sizes[i])
	var armor := _material(Color(0.10, 0.17, 0.21), false)
	var vein := _material(Color(0.09, 0.79, 0.65), true)
	for i in range(11):
		var t := float(i) * 2.399
		var r := 0.50 + float(i % 3) * 0.15
		var spot := MeshInstance3D.new()
		var bead := SphereMesh.new()
		bead.radius = 0.10 + float(i % 3) * 0.028
		bead.height = bead.radius * 2.0
		spot.mesh = bead
		spot.material_override = vein if i % 3 == 0 else armor
		spot.position = Vector3(cos(t) * r, 0.60 - float(i % 4) * 0.06, sin(t) * r)
		_body.add_child(spot)
	for i in range(ROOTS.size()):
		var thick := 0.22 + float(i % 4) * 0.032
		var lower := _segment(thick, thick * 0.67, armor)
		var upper := _segment(thick * 0.68, 0.016, _material(Color(0.09, 0.16 + float(i % 3) * 0.03, 0.20), false))
		var tip := MeshInstance3D.new()
		var tip_mesh := SphereMesh.new()
		tip_mesh.radius = 0.08
		tip_mesh.height = 0.16
		tip.mesh = tip_mesh
		tip.material_override = vein
		get_tree().current_scene.add_child(tip)
		_legs.append({"root": lower, "tip_section": upper, "bead": tip,
			"anchor": global_position + ROOTS[i] * 2.2, "swing": 1.0,
			"planted": false, "phase": float(i) / float(ROOTS.size())})
	for i in range(3):
		_whips.append(_segment(0.22 + float(i) * 0.03, 0.01, vein))
	_last_position = global_position

func _material(color: Color, glowing: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.32 if glowing else 0.56
	if glowing:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.4
	return m

func _segment(base_radius: float, end_radius: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = 1.0
	mesh.bottom_radius = base_radius
	mesh.top_radius = end_radius
	mesh.radial_segments = 8
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	get_tree().current_scene.add_child(instance)
	return instance

func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector3.ZERO
		return
	_clock += delta
	_hit_flash = maxf(0.0, _hit_flash - delta * 3.8)
	_pulse = move_toward(_pulse, 0.0, delta * 2.3)
	if dash_duration > 0.0:
		dash_duration = maxf(0.0, dash_duration - delta)
		velocity = dash_heading * dash_speed
	else:
		var vector := Vector3(movement.x, 0.0, movement.y).limit_length(1.0)
		velocity = vector * movement_speed * (0.94 + 0.06 * sin(_clock * 10.0))
	velocity.y = -2.0
	move_and_slide()
	_animate(delta)

func begin_dash(direction: Vector3) -> bool:
	if direction.length_squared() < 0.01:
		return false
	dash_heading = direction.normalized()
	dash_duration = 0.28
	has_ability_anchor = true
	ability_anchor = global_position + dash_heading * 5.0
	_pulse = 1.0
	return true

func absorb_flash() -> void:
	_pulse = 0.75

func flash_hit() -> void:
	_hit_flash = 1.0

func reset_contacts() -> void:
	dash_duration = 0.0
	has_ability_anchor = false
	work_targets.clear()
	for limb in _legs:
		limb["planted"] = false
		limb["swing"] = 0.3
	for whip in _whips:
		whip.visible = false
	_last_position = global_position

func _animate(delta: float) -> void:
	_slime_material.set_shader_parameter("pulse", maxf(_pulse, _hit_flash * 0.9))
	var speed := Vector2(velocity.x, velocity.z).length()
	_body.position.y = sin(_clock * (3.0 + speed)) * (0.035 + speed * 0.006)
	_body.rotation.z = -velocity.x * 0.016
	_body.rotation.x = velocity.z * 0.013
	for i in range(_shells.size()):
		var original: Vector3 = _shell_scales[i]
		_shells[i].scale = Vector3(
			original.x * (1.0 + 0.018 * sin(_clock * 2.7 + float(i))),
			original.y * (1.0 + 0.03 * sin(_clock * 2.5 + float(i) * 1.7)),
			original.z * (1.0 + 0.023 * sin(_clock * 2.3 + float(i) * 2.0))
		)
	var direction := Vector3(velocity.x, 0.0, velocity.z).normalized()
	for i in range(_legs.size()):
		var limb: Dictionary = _legs[i]
		var root: Vector3 = global_position + ROOTS[i] + Vector3(0.0, _body.position.y, 0.0)
		var radial := Vector3(ROOTS[i].x, 0, ROOTS[i].z).normalized()
		var phase: float = fposmod(_clock * (0.56 + speed * 0.12) + float(limb["phase"]), 1.0)
		var planting := speed > 0.18 and phase < 0.55
		if planting and not bool(limb["planted"]):
			var plant: Vector3 = global_position + radial * LENGTHS[i] + direction * (0.8 + float(i % 3) * 0.25)
			plant.y = 0.14
			limb["anchor"] = plant
		elif speed < 0.18:
			var rest: Vector3 = global_position + radial * LENGTHS[i] * (0.70 + 0.10 * sin(float(i) * 1.9))
			rest.y = 0.12
			limb["anchor"] = (limb["anchor"] as Vector3).lerp(rest, minf(1.0, delta * 4.0))
		limb["planted"] = planting
		# Keep most legs visible while several shorten asymmetrically.
		var target_extension := 1.0 if planting else (0.76 if speed < 0.18 else 0.55)
		limb["swing"] = move_toward(float(limb["swing"]), target_extension, delta * 5.5)
		var full_anchor: Vector3 = limb["anchor"]
		var foot: Vector3 = root.lerp(full_anchor, float(limb["swing"]))
		foot.y = maxf(0.10, foot.y)
		var elbow := root.lerp(foot, 0.51)
		elbow.y += 0.30 + 0.10 * sin(phase * TAU)
		_draw_segment(limb["root"], root, elbow)
		_draw_segment(limb["tip_section"], elbow, foot)
		var bead: MeshInstance3D = limb["bead"]
		bead.global_position = foot
		bead.visible = true
	for i in range(_whips.size()):
		var root := global_position + Vector3((float(i) - 1.0) * 0.27, 0.34, 0.51)
		var point: Vector3 = root
		var enabled := false
		if i == 0 and has_ability_anchor and dash_duration > 0.0:
			point = ability_anchor
			enabled = true
		elif i < work_targets.size():
			point = work_targets[i]
			enabled = true
		_draw_segment(_whips[i], root, point if enabled else root)
	if dash_duration <= 0.0:
		has_ability_anchor = false
	_last_position = global_position

func _draw_segment(node: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var offset := b - a
	if offset.length_squared() < 0.006:
		node.visible = false
		return
	node.visible = true
	node.global_transform = Transform3D(
		Basis(Quaternion(Vector3.UP, offset.normalized())).scaled(Vector3(1.0, offset.length(), 1.0)),
		(a + b) * 0.5
	)

func _exit_tree() -> void:
	for leg in _legs:
		for key in ["root", "tip_section", "bead"]:
			var item: MeshInstance3D = leg[key]
			if is_instance_valid(item):
				item.queue_free()
	for item in _whips:
		if is_instance_valid(item):
			item.queue_free()
