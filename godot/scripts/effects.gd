extends Node3D
## Pooled-effect-style short-lived rings, sparks and hit pulses.
## Visual feedback is deliberately obvious in landscape mobile camera.

var pulses: Array[Dictionary] = []
var _spark_mesh: SphereMesh

func _ready() -> void:
	_spark_mesh = SphereMesh.new()
	_spark_mesh.radius = 0.11
	_spark_mesh.height = 0.22
	_spark_mesh.radial_segments = 8
	_spark_mesh.rings = 4

func capture(at: Vector3, large := false) -> void:
	_ring(at, Color(0.17, 1.0, 0.73), 0.32 if large else 0.16, 1.8 if large else 1.1, 0.47)
	_sparks(at, 8 if large else 5, Color(0.31, 1.0, 0.78))

func hit(at: Vector3, warden := false) -> void:
	_ring(at, Color(1.0, 0.36, 0.22), 0.2, 2.0 if warden else 1.1, 0.45)
	_sparks(at, 8 if warden else 4, Color(1.0, 0.63, 0.22))

func telegraph(at: Vector3) -> void:
	_ring(at, Color(1.0, 0.21, 0.18), 0.28, 3.0, 0.85)

func shockwave(at: Vector3) -> void:
	_ring(at, Color(0.76, 0.32, 1.0), 0.25, 5.0, 0.45)
	_sparks(at, 14, Color(0.74, 0.49, 1.0))

func _ring(at: Vector3, tint: Color, minimum: float, maximum: float, duration: float) -> void:
	var part := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.88
	mesh.outer_radius = 1.0
	part.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = tint
	part.material_override = material
	part.position = at + Vector3.UP * 0.17
	add_child(part)
	pulses.append({
		"node": part, "t": 0.0, "duration": duration, "min": minimum,
		"max": maximum, "tint": tint, "kind": 0, "velocity": Vector3.ZERO
	})

func _sparks(at: Vector3, count: int, tint: Color) -> void:
	for i in range(count):
		var part := MeshInstance3D.new()
		part.mesh = _spark_mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = tint
		material.emission_enabled = true
		material.emission = tint
		part.material_override = material
		part.position = at + Vector3.UP * 0.35
		add_child(part)
		var theta := TAU * float(i) / float(count)
		pulses.append({
			"node": part, "t": 0.0, "duration": 0.36, "min": 0.20, "max": 0.0,
			"tint": tint, "kind": 1,
			"velocity": Vector3(cos(theta) * 4.0, 2.3 + float(i % 3), sin(theta) * 4.0)
		})

func _process(delta: float) -> void:
	for i in range(pulses.size() - 1, -1, -1):
		var state: Dictionary = pulses[i]
		var node: MeshInstance3D = state["node"]
		if not is_instance_valid(node):
			pulses.remove_at(i)
			continue
		var elapsed: float = float(state["t"]) + delta
		state["t"] = elapsed
		var u: float = minf(1.0, elapsed / float(state["duration"]))
		if u >= 1.0:
			node.queue_free()
			pulses.remove_at(i)
			continue
		var mat: StandardMaterial3D = node.material_override
		var shade: Color = state["tint"]
		shade.a = (1.0 - u) * (1.0 - u) * 0.85
		mat.albedo_color = shade
		if int(state["kind"]) == 0:
			var size: float = lerpf(float(state["min"]), float(state["max"]), u)
			node.scale = Vector3.ONE * size
		else:
			var velocity: Vector3 = state["velocity"]
			node.position += velocity * delta
			state["velocity"] = velocity + Vector3.DOWN * 5.0 * delta
			node.scale = Vector3.ONE * lerpf(0.9, 0.1, u)
