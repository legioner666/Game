extends RefCounted
## Distinctive, original enemy silhouettes generated from primitives.
## No generic capsules or copyrighted models.

static func create(host: Node3D, zone: int, warden: bool) -> void:
	var body := Node3D.new()
	body.name = "Specimen visual"
	host.add_child(body)
	var shell_col: Color = [
		Color(0.31, 0.59, 0.54), Color(0.39, 0.40, 0.77), Color(0.70, 0.36, 0.46)
	][zone]
	var skin := _material(shell_col.darkened(0.45), false)
	var accent := _material(shell_col.lightened(0.18), true)
	var black := _material(Color(0.05, 0.09, 0.16), false)
	var size := 1.8 if warden else 1.0
	var orb := SphereMesh.new()
	orb.radial_segments = 12
	orb.rings = 8
	_node(body, orb, skin, Vector3(0, 0.40 * size, 0),
		Vector3(0.73, 0.65, 0.68) * size)
	var under := SphereMesh.new()
	under.radial_segments = 12
	under.rings = 8
	_node(body, under, accent, Vector3(0, 0.29 * size, 0.13 * size),
		Vector3(0.38, 0.33, 0.35) * size)
	for i in range(5 if warden else 3):
		var a := TAU * float(i) / float(5 if warden else 3)
		var thorn := CylinderMesh.new()
		thorn.radial_segments = 5
		thorn.bottom_radius = 0.25 * size
		thorn.top_radius = 0.018
		thorn.height = 1.0 * size
		var p := Vector3(cos(a) * 0.58 * size, 0.70 * size, sin(a) * 0.48 * size)
		_node(body, thorn, skin, p, Vector3.ONE, Vector3(0, 0, -cos(a) * 0.6))
	for i in range(4 if warden else 2):
		var side := -1.0 if i % 2 == 0 else 1.0
		var front := -1.0 if i < 2 else 1.0
		var claw := CylinderMesh.new()
		claw.radial_segments = 6
		claw.bottom_radius = 0.22 * size
		claw.top_radius = 0.03
		claw.height = 1.25 * size
		_node(body, claw, black,
			Vector3(side * 0.85 * size, 0.07 * size, front * 0.38 * size),
			Vector3.ONE, Vector3(0, 0, side * 0.52))
	if warden:
		var halo := TorusMesh.new()
		halo.inner_radius = 1.10
		halo.outer_radius = 1.19
		_node(body, halo, accent, Vector3(0, 1.6, 0), Vector3.ONE, Vector3(0, 0, PI * 0.35))
		var crown := CylinderMesh.new()
		crown.top_radius = 0.04
		crown.bottom_radius = 0.51
		crown.height = 1.25
		crown.radial_segments = 7
		_node(body, crown, accent, Vector3(0, 2.15, 0), Vector3.ONE)
	var eye := SphereMesh.new()
	eye.radius = 0.14 * size
	eye.height = 0.26 * size
	for n in range(3):
		_node(body, eye, accent,
			Vector3((float(n) - 1.0) * 0.28 * size, 0.45 * size, -0.55 * size),
			Vector3.ONE)

static func _material(color: Color, lit: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.13
	m.roughness = 0.38
	if lit:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
	return m

static func _node(parent: Node3D, mesh: Mesh, material: Material,
		at: Vector3, size: Vector3, angles := Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.scale = size
	part.rotation = angles
	parent.add_child(part)
