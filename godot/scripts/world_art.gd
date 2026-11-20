extends RefCounted
## Deterministic, engine-native environmental art; no imported proprietary assets.
## Instancing keeps geometric detail affordable on GLES3/Android.

const SECTOR_COLORS := [
	Color(0.08, 0.46, 0.40), Color(0.25, 0.40, 0.73), Color(0.75, 0.32, 0.43)
]
const INK := Color(0.035, 0.056, 0.090)
const BASE := Vector3(-22.0, 0.05, -10.0)

static func build(root: Node3D) -> void:
	var environment := WorldEnvironment.new()
	environment.name = "Cinematic soft atmospheric lighting"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.027, 0.045, 0.080)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.29, 0.38, 0.52)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	root.add_child(environment)
	var floor_mat := _mat(Color(0.18, 0.23, 0.27), 0.9)
	var frame_mat := _mat(Color(0.10, 0.18, 0.25), 0.55)
	for zone in range(3):
		var hue: Color = SECTOR_COLORS[zone]
		var light_mat := _mat(hue, 0.38, true)
		var dark_mat := _mat(Color(0.065, 0.09, 0.14).lerp(hue, 0.07), 0.9)
		_paint_living_floor(root, zone)
		_tracks(root, zone, light_mat, frame_mat)
		for ix in range(4):
			for iz in range(5):
				var gx := -32.0 + 23.0 * float(zone) + float(ix) * 6.4
				var gz := -18.0 + float(iz) * 9.0
				if Vector2(gx - BASE.x, gz - BASE.z).length() < 7.2:
					continue
				if ((ix * 13 + iz * 19 + zone * 11) % 4) == 0:
					_crystal(root, Vector3(gx, 0, gz), zone, light_mat, dark_mat)
				elif ((ix * 7 + iz * 5 + zone) % 3) == 0:
					_growth(root, Vector3(gx, 0, gz), zone, light_mat, dark_mat)
		for z in [-19.4, 19.4]:
			for dx in [-8.4, 0.0, 8.4]:
				_pylon(root, Vector3(-23.0 + float(zone) * 23.0 + dx, 0, z), light_mat, frame_mat)
		_icon(root, Vector3(-23.0 + float(zone) * 23.0, 0.2, -19.0), zone, light_mat, frame_mat)
	_base_decor(root)
	_lighting(root)

static func _paint_living_floor(root: Node3D, sector: int) -> void:
	var floor: Node3D = root.get_node_or_null("Sector floor " + str(sector))
	if floor == null:
		return
	var surface: MeshInstance3D = floor.get_child(0) as MeshInstance3D
	if surface == null:
		return
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley;
uniform vec4 dark_floor : source_color = vec4(0.10, 0.16, 0.19, 1.0);
uniform vec3 flow_color : source_color = vec3(0.13, 0.48, 0.40);
uniform float seed = 0.0;
float pattern(vec2 p) {
	return sin(p.x * 8.7 + sin(p.y * 5.3 + seed) * 2.0)
		* sin(p.y * 6.2 + sin(p.x * 3.4) * 1.9);
}
void fragment() {
	vec2 p = UV * vec2(7.0, 11.0);
	float vein = pattern(p + vec2(seed, TIME * 0.017));
	float whorl = sin(p.x * 10.2 + p.y * 4.8 + 0.8 * sin(p.y * 2.1));
	float network = smoothstep(0.72, 0.97, abs(vein)) * 0.26;
	float islands = 0.09 * sin(p.x * 3.7 + p.y * 6.3) * sin(p.x * 6.1 - p.y * 1.9);
	ALBEDO = dark_floor.rgb * (0.83 + 0.14 * whorl + islands);
	ALBEDO += flow_color * network;
	ROUGHNESS = 0.88;
	METALLIC = 0.02;
	EMISSION = flow_color * network * 0.13;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var palettes := [
		Color(0.09, 0.18, 0.19), Color(0.14, 0.13, 0.24), Color(0.20, 0.11, 0.16)
	]
	var pigments := [
		Color(0.15, 0.55, 0.42), Color(0.26, 0.33, 0.67), Color(0.68, 0.19, 0.32)
	]
	material.set_shader_parameter("dark_floor", palettes[sector])
	material.set_shader_parameter("flow_color", Vector3(pigments[sector].r,
		pigments[sector].g, pigments[sector].b))
	material.set_shader_parameter("seed", float(sector) * 1.7)
	surface.material_override = material

static func _mat(color: Color, roughness: float, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.15
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.25
	return material

static func _mesh(root: Node3D, name: String, mesh: Mesh, position: Vector3,
		material: Material, rotation := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	part.mesh = mesh
	part.material_override = material
	part.position = position
	part.rotation = rotation
	part.scale = scale
	root.add_child(part)
	return part

static func _prism(root: Node3D, name: String, center: Vector3, dimensions: Vector3,
		material: Material, rotation := Vector3.ZERO) -> void:
	var box := BoxMesh.new()
	box.size = dimensions
	_mesh(root, name, box, center, material, rotation)

static func _tiles(root: Node3D, zone: int, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 0.024, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 96
	for x in range(8):
		for z in range(12):
			var idx := x * 12 + z
			var gx := -33.2 + float(zone) * 23.0 + float(x) * 2.83
			var gz := -20.0 + float(z) * 3.55
			var width := 2.7
			var length := 3.4
			var offset := 0.0 if idx % 7 != 0 else 0.03
			mm.set_instance_transform(idx, Transform3D(
				Basis().scaled(Vector3(width, 1.0, length)),
				Vector3(gx, 0.009 + offset, gz)))
			var color := Color(0.63, 0.72, 0.83)
			if idx % 7 == 0:
				color = Color(0.43, 0.65, 0.75)
			elif idx % 11 == 0:
				color = Color(0.40, 0.48, 0.63)
			mm.set_instance_color(idx, color)
	var material_tile := material.duplicate() as StandardMaterial3D
	material_tile.vertex_color_use_as_albedo = true
	var node := MultiMeshInstance3D.new()
	node.name = "Instanced engraved deck — sector " + str(zone)
	node.multimesh = mm
	node.material_override = material_tile
	root.add_child(node)

static func _tracks(root: Node3D, zone: int, light: Material, frame: Material) -> void:
	var xcenter := -23.0 + float(zone) * 23.0
	for dx in [-9.8, 9.8]:
		for z in range(-20, 21, 5):
			_prism(root, "Luminous runway tick", Vector3(xcenter + dx, 0.060, float(z)),
				Vector3(0.16, 0.08, 2.6), light)
	for dx in [-7.2, 7.2]:
		_prism(root, "Dark technical floor seam", Vector3(xcenter + dx, 0.041, 0),
			Vector3(0.18, 0.06, 39.0), frame)
	for z in [-18.8, 18.8]:
		_prism(root, "Wall uplight", Vector3(xcenter, 1.3, z),
			Vector3(17.0, 0.12, 0.25), light)

static func _crystal(root: Node3D, center: Vector3, zone: int,
		light: Material, dark: Material) -> void:
	var column := CylinderMesh.new()
	column.top_radius = 0.05
	column.bottom_radius = 0.55
	column.height = 2.0 + float((zone + int(center.x)) % 3) * 0.6
	column.radial_segments = 6
	for i in range(3):
		var theta := float(i) * TAU / 3.0 + center.x * 0.07
		var dx := cos(theta) * (0.30 + float(i) * 0.14)
		var dz := sin(theta) * (0.31 + float(i) * 0.11)
		var height := column.height * (0.75 + 0.18 * float(i))
		_mesh(root, "Bioelectric crystal", column,
			center + Vector3(dx, height * 0.42, dz),
			light if i == 0 else dark, Vector3(0.15 * float(i), 0.0, -0.10 * float(i)))

static func _growth(root: Node3D, center: Vector3, zone: int,
		light: Material, dark: Material) -> void:
	var bulb := SphereMesh.new()
	bulb.radius = 0.62
	bulb.height = 1.24
	bulb.radial_segments = 12
	bulb.rings = 8
	var stem := CylinderMesh.new()
	stem.top_radius = 0.14
	stem.bottom_radius = 0.36
	stem.height = 1.4
	stem.radial_segments = 9
	for i in range(3):
		var position := center + Vector3(float(i - 1) * 0.62, 0.45, float(i % 2) * 0.31)
		_mesh(root, "Fungal membrane", stem, position, dark)
		_mesh(root, "Light-bearing cap", bulb, position + Vector3(0, 0.91, 0), light,
			Vector3(0, 0, 0), Vector3(1, 0.34, 1))

static func _pylon(root: Node3D, position: Vector3, light: Material, dark: Material) -> void:
	_prism(root, "Ribbed pillar", position + Vector3(0, 1.8, 0),
		Vector3(0.80, 3.6, 0.84), dark)
	_prism(root, "Pillar energy stripe", position + Vector3(0, 2.65, -0.44),
		Vector3(0.49, 1.2, 0.08), light)
	_prism(root, "Pillar crown", position + Vector3(0, 3.75, 0),
		Vector3(1.45, 0.18, 1.1), dark)

static func _icon(root: Node3D, position: Vector3, zone: int,
		light: Material, dark: Material) -> void:
	_prism(root, "Sector shrine", position + Vector3(0, 0.48, 0),
		Vector3(2.0, 0.90, 1.6), dark)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.68
	ring.outer_radius = 0.83
	_mesh(root, "Sector power symbol", ring, position + Vector3(0, 1.4, 0),
		light, Vector3(PI * 0.48, 0, float(zone) * 0.20))

static func _base_decor(root: Node3D) -> void:
	var glow := _mat(Color(0.13, 0.93, 0.66), 0.28, true)
	var base_dark := _mat(Color(0.04, 0.14, 0.17), 0.65)
	var ring := TorusMesh.new()
	ring.inner_radius = 3.94
	ring.outer_radius = 4.08
	_mesh(root, "Base outer luminous circuit", ring, BASE + Vector3(0, 0.11, 0), glow)
	ring = TorusMesh.new()
	ring.inner_radius = 2.38
	ring.outer_radius = 2.51
	_mesh(root, "Base inner circuit", ring, BASE + Vector3(0, 0.12, 0), glow)
	var core := CylinderMesh.new()
	core.top_radius = 0.80
	core.bottom_radius = 1.14
	core.height = 1.4
	core.radial_segments = 12
	_mesh(root, "Base mutation vault", core,
		BASE + Vector3(-1.9, 1.08, -1.1), base_dark)
	var crown := SphereMesh.new()
	crown.radius = 0.56
	crown.height = 1.0
	_mesh(root, "Base organic heart", crown,
		BASE + Vector3(-1.9, 1.95, -1.1), glow)
	for i in range(12):
		var theta := float(i) * TAU / 12.0
		_prism(root, "Twelve heartbeat nodes",
			BASE + Vector3(cos(theta) * 4.65, 0.14, sin(theta) * 4.65),
			Vector3(0.22, 0.16, 0.70), glow, Vector3(0, theta, 0))

static func _lighting(root: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.name = "Soft blue biome fill"
	key.rotation_degrees = Vector3(-62, 32, -8)
	key.light_color = Color(0.49, 0.72, 1.0)
	key.light_energy = 0.32
	root.add_child(key)
	for i in range(3):
		var lamp := OmniLight3D.new()
		lamp.name = "Zone accent " + str(i)
		lamp.position = Vector3(-23.0 + float(i) * 23.0, 4.0, 0)
		lamp.light_color = SECTOR_COLORS[i]
		lamp.light_energy = 1.1
		lamp.omni_range = 15.0
		lamp.shadow_enabled = false
		root.add_child(lamp)
