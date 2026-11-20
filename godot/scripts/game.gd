extends Node3D
## Parasite Evolution: original Godot 4.4 3D vertical slice.
## Distinct from the Crown Rush Godot project in a different repository.

const Rules = preload("res://scripts/economy.gd")
const Slime = preload("res://scripts/slime_v2.gd")
const Art = preload("res://scripts/world_art.gd")
const MobArt = preload("res://scripts/enemy_art.gd")
const Effects = preload("res://scripts/effects.gd")
const SAVE := "user://parasite-evolution-v1.json"
const SAFE_POINT := Vector3(-22.0, 0.62, -10.0)
const SAFE_RADIUS := 5.0
const QUEST_NAMES := [
	"Захопи 4 зразки", "Двічі поверни вантаж на базу",
	"Придбай покращення", "Досліди 3 зони", "Переможи Наглядача"
]
const UPGRADE_NAMES := ["Захоплення", "Місткість", "Швидкість", "Радіус", "Канали", "Здоров'я"]
const ZONE_COLORS := [
	Color(0.20, 0.30, 0.36), Color(0.26, 0.23, 0.33), Color(0.32, 0.20, 0.26)
]

var profile: Dictionary
var player: CharacterBody3D
var camera: Camera3D
var fx: Node3D
var mobs: Array[Dictionary] = []
var _hud: Control
var _stats: Label
var _quest: Label
var _message: Label
var _health_bar: ProgressBar
var _cargo_bar: ProgressBar
var _zone_label: Label
var _shop_balance: Label
var _shop_content: VBoxContainer
var _pause_content: VBoxContainer
var _reward_button: Button
var _skill_buttons: Dictionary = {}
var _shop_buttons: Array[Button] = []
var _relay_button: Button
var _shop: PanelContainer
var _paused := false
var _shop_open := false
var _save_disabled := false
var _safe_previous := false
var _save_elapsed := 0.0
var _hud_elapsed := 0.0
var _toast_until := 0.0
var _move_stick := Vector2.ZERO
var _stick_id := -1
var _stick_base: Panel
var _stick_knob: Panel
var _last_heading := Vector3.FORWARD

func _ready() -> void:
	profile = _load_profile()
	_build_world()
	Art.build(self)
	fx = Effects.new()
	fx.name = "Capture, attack and absorption effects"
	add_child(fx)
	player = Slime.new()
	player.name = "Amorphous Parasite"
	add_child(player)
	player.global_position = Vector3(float(profile["x"]), SAFE_POINT.y, float(profile["z"]))
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.7
	camera.current = true
	camera.near = 0.1
	camera.far = 120.0
	add_child(camera)
	_camera_update(1.0)
	_build_ui()
	_note("Рухайся, поглинай зразки та повертайся на базу.")
	if _save_disabled:
		_note("Помилка збереження: старі файли збережено; нові записи вимкнені.")

func _box(label: String, center: Vector3, size: Vector3, color: Color, solid := true) -> Node3D:
	var host: Node3D = StaticBody3D.new() if solid else Node3D.new()
	host.name = label
	add_child(host)
	host.position = center
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	mesh_node.material_override = mat
	host.add_child(mesh_node)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		host.add_child(collider)
	return host

func _build_world() -> void:
	for zone in range(3):
		var x := -23.0 + float(zone) * 23.0
		_box("Sector floor " + str(zone), Vector3(x, -0.30, 0), Vector3(23, 0.6, 44), ZONE_COLORS[zone])
		for z in range(-20, 21, 4):
			_box("Sector marking", Vector3(x, 0.01, float(z)), Vector3(22, 0.02, 0.05), Color(0.30, 0.56, 0.60), false)
	for x in [-35.0, 35.0]:
		_box("Outer wall", Vector3(x, 1, 0), Vector3(1, 2, 46), Color(0.10, 0.15, 0.23))
	for z in [-23.0, 23.0]:
		_box("Outer wall", Vector3(0, 1, z), Vector3(71, 2, 1), Color(0.10, 0.15, 0.23))
	for x in [-11.5, 11.5]:
		for seg in [[-15.5, 13.0], [1.5, 9.0], [17.0, 10.0]]:
			_box("Partition", Vector3(x, 0.7, float(seg[0])), Vector3(0.65, 1.4, float(seg[1])), Color(0.15, 0.22, 0.27))
	var safe := MeshInstance3D.new()
	safe.name = "Symbiotic base"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = SAFE_RADIUS
	cylinder.bottom_radius = SAFE_RADIUS
	cylinder.height = 0.04
	safe.mesh = cylinder
	var safe_material := StandardMaterial3D.new()
	safe_material.albedo_color = Color(0.07, 0.50, 0.35)
	safe_material.emission_enabled = true
	safe_material.emission = Color(0.02, 0.08, 0.05)
	safe.material_override = safe_material
	safe.position = Vector3(SAFE_POINT.x, 0.04, SAFE_POINT.z)
	add_child(safe)
	_box("Core station", SAFE_POINT + Vector3(-1.8, 0.12, -1.1),
		Vector3(1.4, 1.5, 1.4), Color(0.12, 0.23, 0.26), false)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.5
	add_child(sun)
	for zone in range(3):
		for n in range(7):
			var x := -24.0 + float(zone * 23 + (n % 3) * 3)
			var z := 4.0 + float(n / 3) * 4.0 if zone == 0 else -13.0 + float(n / 3) * 10.0
			_spawn_mob(Vector3(x, 0.60, z), zone, false)
	_spawn_mob(Vector3(27, 0.75, 15), 2, true)

func _spawn_mob(point: Vector3, zone: int, warden: bool) -> void:
	var creature := CharacterBody3D.new()
	creature.collision_layer = 4
	creature.collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.8 if warden else 0.42
	capsule.height = 2.2 if warden else 1.25
	collider.shape = capsule
	collider.position.y = 0.45 if warden else 0.09
	creature.add_child(collider)
	creature.name = "Warden" if warden else "Specimen %s" % str(mobs.size())
	add_child(creature)
	creature.position = point
	MobArt.create(creature, zone, warden)
	mobs.append({
		"node": creature, "home": point, "zone": zone, "warden": warden,
		"hp": hp, "max_hp": hp, "alive": true, "respawn": 0.0, "pulled": 0.0,
		"attack": 0.0, "warning": 0.0, "stomp": point
	})

func _physics_process(delta: float) -> void:
	if _paused or not is_instance_valid(player):
		return
	_save_elapsed += delta
	_hud_elapsed += delta
	var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (_move_stick + keys).limit_length(1.0)
	player.movement = direction
	player.movement_speed = Rules.speed(profile)
	if direction.length_squared() > 0.03:
		_last_heading = Vector3(direction.x, 0, direction.y).normalized()
	var safe := _inside_base()
	if safe:
		profile["health"] = move_toward(float(profile["health"]), Rules.maximum_health(profile), delta * 8.0)
		if not _safe_previous and int(profile["cargo_units"]) > 0:
			if Rules.deposit(profile):
				_note("Зразки перероблено на базі.")
				_save_game()
	_safe_previous = safe
	var zone := _zone_at(player.global_position)
	profile["visited_zones"] = int(profile["visited_zones"]) | (1 << zone)
	for id in profile["cooldowns"].keys():
		profile["cooldowns"][id] = maxf(0.0, float(profile["cooldowns"][id]) - delta)
	if int(profile["relay_level"]) > 0 and not safe:
		var remaining := maxf(0.0, float(profile["relay_remaining"]) - delta)
		profile["relay_remaining"] = remaining
		if remaining <= 0.0 and int(profile["cargo_units"]) > 0:
			if Rules.relay_transfer(profile):
				profile["relay_remaining"] = Rules.relay_interval(profile)
				_note("Органічне реле доставило зразки.")
				_save_game()
	_update_enemies(delta, safe)
	_auto_capture(delta, safe)
	_camera_update(delta)
	if _save_elapsed >= 5.0:
		_save_elapsed = 0.0
		_save_game()
	if _hud_elapsed >= 0.15:
		_hud_elapsed = 0.0
		_update_hud()

func _update_enemies(delta: float, safe: bool) -> void:
	for mob in mobs:
		var node: Node3D = mob["node"]
		if not mob["alive"]:
			mob["respawn"] -= delta
			if mob["respawn"] <= 0.0 and node.global_position.distance_to(player.global_position) > 14.0:
				mob["alive"] = true
				mob["hp"] = mob["max_hp"]
				node.visible = true
				(node as CharacterBody3D).collision_layer = 4
			continue
		mob["attack"] = maxf(0.0, float(mob["attack"]) - delta)
		mob["pulled"] = maxf(0.0, float(mob["pulled"]) - delta)
		var distance := node.global_position.distance_to(player.global_position)
		if mob["warning"] > 0.0:
			mob["warning"] -= delta
			if mob["warning"] <= 0.0:
				fx.hit(mob["stomp"], true)
				if not safe and player.global_position.distance_to(mob["stomp"]) < 3.0:
					_hurt(15.0)
			continue
		var destination: Vector3 = mob["home"]
		if mob["pulled"] > 0.0 and not safe:
			destination = player.global_position + (node.global_position - player.global_position).normalized() * 1.25
		elif distance < 7.0 and not safe and node.global_position.distance_to(mob["home"]) < 16.0:
			destination = player.global_position
			if mob["zone"] == 0 and not mob["warden"]:
				destination = node.global_position + (node.global_position - player.global_position).normalized() * 2.0
			if mob["zone"] > 0 and distance < (4.0 if mob["warden"] else 1.5) and mob["attack"] <= 0.0:
				mob["attack"] = 3.0 if mob["warden"] else 1.5
				if mob["warden"]:
					mob["warning"] = 0.85
					mob["stomp"] = player.global_position
					fx.telegraph(player.global_position)
					_note("Наглядач готує удар — ухиляйся!")
				else:
					_hurt(4.0 + float(mob["zone"]) * 2.0)
		var movement: Vector3 = destination - node.global_position
		movement.y = 0.0
		if movement.length_squared() > 0.05:
			var velocity: float = 11.0 if mob["pulled"] > 0.0 else (1.3 if mob["warden"] else 2.0)
			var step := movement.limit_length(velocity * delta)
			var candidate := node.global_position + step
			if _zone_at(candidate) == mob["zone"] and not _inside_base(candidate):
				(node as CharacterBody3D).move_and_collide(step)
		if mob["warden"]:
			node.rotation.y += delta * 0.4

func _auto_capture(delta: float, safe: bool) -> void:
	player.work_targets.clear()
	if safe:
		return
	var eligible: Array[Dictionary] = []
	for mob in mobs:
		if mob["alive"] and Rules.can_carry(profile, _units(mob)):
			var point: Vector3 = mob["node"].global_position
			if point.distance_to(player.global_position) <= Rules.capture_radius(profile):
				eligible.append(mob)
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["node"].global_position.distance_squared_to(player.global_position) < b["node"].global_position.distance_squared_to(player.global_position)
	)
	var count := mini(Rules.channels(profile), eligible.size())
	for i in range(count):
		var mob: Dictionary = eligible[i]
		if not Rules.can_carry(profile, _units(mob)):
			continue
		player.work_targets.append(mob["node"].global_position + Vector3.UP * 0.2)
		_damage_mob(mob, Rules.capture_damage(profile) * delta)

func _damage_mob(mob: Dictionary, damage: float) -> void:
	if not mob["alive"] or damage <= 0.0:
		return
	mob["hp"] = maxf(0.0, float(mob["hp"]) - damage)
	if mob["hp"] > 0.0:
		return
	var units := _units(mob)
	var value := 30 if mob["warden"] else 3 + int(mob["zone"]) * 2
	var experience := 20 if mob["warden"] else 3 + int(mob["zone"])
	if not Rules.capture(profile, units, value, experience, mob["warden"]):
		mob["hp"] = 1.0
		return
	mob["alive"] = false
	fx.capture(mob["node"].global_position, bool(mob["warden"]))
	player.absorb_flash()
	mob["node"].visible = false
	(mob["node"] as CharacterBody3D).collision_layer = 0
	mob["respawn"] = 90.0 if mob["warden"] else 25.0
	if int(profile["cargo_units"]) == Rules.capacity(profile):
		_note("Вантаж заповнений. Повернися на базу.")
	_save_game()

func _units(mob: Dictionary) -> int:
	return 3 if mob["warden"] else (2 if int(mob["zone"]) == 2 else 1)

func _inside_base(point: Vector3 = Vector3.INF) -> bool:
	var p: Vector3 = player.global_position if point == Vector3.INF else point
	return Vector2(p.x - SAFE_POINT.x, p.z - SAFE_POINT.z).length() <= SAFE_RADIUS

func _zone_at(point: Vector3) -> int:
	return 0 if point.x < -11.5 else (1 if point.x < 11.5 else 2)

func _hurt(value: float) -> void:
	if _inside_base() or value <= 0.0:
		return
	player.flash_hit()
	fx.hit(player.global_position)
	profile["health"] = maxf(0.0, float(profile["health"]) - value)
	if profile["health"] <= 0.0:
		var serial: int = int(profile["death_serial"]) + 1
		if Rules.settle_death(profile, serial):
			player.global_position = SAFE_POINT
			player.reset_contacts()
			_safe_previous = false
			_note("Ти повернувся на базу та втратив частину геному.")
			_save_game()

func _use_ability(id: String) -> void:
	if _paused or _inside_base():
		return
	if not profile["abilities"].has(id):
		_note("Відкрий здібність на базі.")
		return
	if float(profile["cooldowns"].get(id, 0.0)) > 0.0:
		return
	if id == "AB-MOVE":
		if not player.begin_dash(_last_heading):
			return
		profile["cooldowns"][id] = 7.0
	elif id == "AB-PULL":
		var target := _nearest(8.0)
		if target.is_empty():
			_note("Немає цілі для притягування.")
			return
		target["pulled"] = 0.8
		profile["cooldowns"][id] = 4.0
	elif id == "AB-DAMAGE":
		var inflicted := 0
		fx.shockwave(player.global_position)
		for mob in mobs:
			if mob["alive"] and mob["node"].global_position.distance_to(player.global_position) < 4.5:
				_damage_mob(mob, 38.0)
				inflicted += 1
		if inflicted == 0:
			_note("Немає цілей поруч.")
			return
		profile["cooldowns"][id] = 13.0
	_save_game()

func _nearest(radius: float) -> Dictionary:
	var chosen: Dictionary = {}
	var best := radius * radius
	for mob in mobs:
		if not mob["alive"] or not Rules.can_carry(profile, _units(mob)):
			continue
		var d: float = mob["node"].global_position.distance_squared_to(player.global_position)
		if d < best:
			best = d
			chosen = mob
	return chosen

func _camera_update(delta: float) -> void:
	var target := player.global_position + Vector3(0, 14.8, -10.8)
	camera.global_position = target if delta >= 1.0 else camera.global_position.lerp(target, 1.0 - exp(-7.0 * delta))
	camera.look_at(player.global_position + Vector3.UP * 0.3, Vector3.UP)

func _load_profile() -> Dictionary:
	var latest: Dictionary = {}
	var found := false
	for path in [SAVE, SAVE + ".tmp", SAVE + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		found = true
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			if int(parsed.get("schema", 0)) > 1:
				_save_disabled = true
				continue
			if Rules.validate(parsed) and (latest.is_empty() or int(parsed["revision"]) > int(latest["revision"])):
				latest = parsed
	if not latest.is_empty():
		return latest
	if found:
		_save_disabled = true
	return Rules.fresh()

func _save_game() -> void:
	if _save_disabled or not is_instance_valid(player):
		return
	var next: Dictionary = profile.duplicate(true)
	next["revision"] = int(next["revision"]) + 1
	next["x"] = player.global_position.x
	next["z"] = player.global_position.z
	if not Rules.validate(next):
		_save_disabled = true
		_note("Невірне збереження: запис призупинено.")
		return
	var temp_file := FileAccess.open(SAVE + ".tmp", FileAccess.WRITE)
	if temp_file == null:
		_save_disabled = true
		return
	temp_file.store_string(JSON.stringify(next))
	temp_file.flush()
	temp_file.close()
	if FileAccess.file_exists(SAVE):
		if DirAccess.copy_absolute(SAVE, SAVE + ".bak") != OK:
			_save_disabled = true
			return
		if DirAccess.remove_absolute(SAVE) != OK:
			_save_disabled = true
			return
	if DirAccess.rename_absolute(SAVE + ".tmp", SAVE) != OK:
		_save_disabled = true
		return
	profile["revision"] = next["revision"]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(player):
			_save_game()
		_set_paused(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	if _stick_base == null or _paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _stick_base.get_global_rect().has_point(event.position) and _stick_id == -1:
			_stick_id = event.index
			_move_stick_at(event.position)
		elif not event.pressed and event.index == _stick_id:
			_reset_stick()
	elif event is InputEventScreenDrag and event.index == _stick_id:
		_move_stick_at(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _stick_base.get_global_rect().has_point(event.position):
			_stick_id = -2
			_move_stick_at(event.position)
		elif not event.pressed and _stick_id == -2:
			_reset_stick()
	elif event is InputEventMouseMotion and _stick_id == -2:
		_move_stick_at(event.position)

func _move_stick_at(screen_point: Vector2) -> void:
	var center := _stick_base.get_global_rect().get_center()
	_move_stick = ((screen_point - center) / 88.0).limit_length(1.0)
	_stick_knob.position = Vector2(69, 69) + _move_stick * 64.0

func _reset_stick() -> void:
	_stick_id = -1
	_move_stick = Vector2.ZERO
	if _stick_knob:
		_stick_knob.position = Vector2(69, 69)

func _set_paused(value: bool) -> void:
	_paused = value
	if is_instance_valid(player):
		player.frozen = value
	if value:
		_reset_stick()

func _toggle_pause() -> void:
	if _shop_open:
		_close_panel()
		return
	_set_paused(not _paused)
	_shop.visible = _paused

func _open_shop() -> void:
	if not _inside_base():
		_note("Мутації можна купити лише на базі.")
		return
	_save_game()
	_shop_open = true
	_set_paused(true)
	_shop.visible = true
	_update_hud()

func _close_panel() -> void:
	_shop_open = false
	_shop.visible = false
	_set_paused(false)

func _buy_upgrade(index: int) -> void:
	if not _shop_open or not _inside_base():
		return
	if Rules.buy_upgrade(profile, index):
		profile["health"] = minf(Rules.maximum_health(profile), float(profile["health"]) + (10.0 if index == 5 else 0.0))
		_note("Мутацію придбано.")
		_save_game()
	else:
		_note("Недостатньо геному, рівня або максимум.")
	_update_hud()

func _buy_relay() -> void:
	if not _shop_open or not _inside_base():
		return
	if Rules.buy_relay(profile):
		profile["relay_remaining"] = Rules.relay_interval(profile)
		_note("Органічне реле розвинено.")
		_save_game()
	else:
		_note("Потрібен 2 рівень, геном або досягнуто максимум.")
	_update_hud()

func _unlock(id: String) -> void:
	if not _shop_open or not _inside_base():
		return
	if Rules.unlock(profile, id):
		_note("Нову здібність відкрито.")
		_save_game()
	else:
		_note("Не вистачає геному або здібність вже відкрита.")
	_update_hud()

func _claim_quest() -> void:
	if not _inside_base():
		_note("Повернися на базу по нагороду.")
		return
	if Rules.claim_quest(profile):
		_note("Нагорода отримана.")
		_save_game()
	else:
		_note("Завдання ще не виконано.")
	_update_hud()

func _note(text: String) -> void:
	_toast_until = Time.get_ticks_msec() / 1000.0 + 3.5
	if _message:
		_message.text = text
	else:
		print("[Parasite Evolution] ", text)

func _style(color: Color, outline: Color, radius := 18) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = outline
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func _make_button(text: String, parent: Control, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(178, 60)
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", Color(0.89, 0.99, 0.97))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(Color(0.065, 0.13, 0.18, 0.94),
		Color(0.14, 0.43, 0.44), 15))
	button.add_theme_stylebox_override("hover", _style(Color(0.12, 0.33, 0.35, 0.98),
		Color(0.20, 0.91, 0.72), 15))
	button.add_theme_stylebox_override("pressed", _style(Color(0.09, 0.49, 0.38, 1.0),
		Color(0.34, 1.0, 0.72), 15))
	button.add_theme_stylebox_override("disabled", _style(Color(0.10, 0.11, 0.16, 0.82),
		Color(0.20, 0.23, 0.28), 15))
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _make_label(value: String, parent: Control, size: int,
		color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.005, 0.025, 0.035, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _make_panel(parent: Control, name: String,
		color: Color, border: Color, radius := 20) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name
	panel.add_theme_stylebox_override("panel", _style(color, border, radius))
	parent.add_child(panel)
	return panel

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Mobile HUD / large safe-area controls"
	add_child(layer)
	_hud = Control.new()
	_hud.name = "Landscape HUD"
	layer.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var info := _make_panel(_hud, "Organism telemetry", Color(0.035, 0.065, 0.105, 0.88),
		Color(0.16, 0.49, 0.48, 0.80))
	info.position = Vector2(24, 20)
	info.custom_minimum_size = Vector2(500, 160)
	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 12)
	info_margin.add_theme_constant_override("margin_right", 12)
	info_margin.add_theme_constant_override("margin_top", 6)
	info_margin.add_theme_constant_override("margin_bottom", 6)
	info.add_child(info_margin)
	var info_stack := VBoxContainer.new()
	info_stack.add_theme_constant_override("separation", 3)
	info_margin.add_child(info_stack)
	_stats = _make_label("", info_stack, 26, Color(0.94, 1.0, 0.95))
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(450, 18)
	_health_bar.show_percentage = false
	_health_bar.add_theme_stylebox_override("background",
		_style(Color(0.14, 0.17, 0.24, 0.96), Color(0.15, 0.21, 0.27), 7))
	_health_bar.add_theme_stylebox_override("fill",
		_style(Color(0.19, 0.93, 0.67), Color(0.19, 0.93, 0.67), 7))
	info_stack.add_child(_health_bar)
	_cargo_bar = ProgressBar.new()
	_cargo_bar.custom_minimum_size = Vector2(450, 12)
	_cargo_bar.show_percentage = false
	_cargo_bar.add_theme_stylebox_override("background",
		_style(Color(0.15, 0.17, 0.25, 0.96), Color(0.16, 0.21, 0.28), 6))
	_cargo_bar.add_theme_stylebox_override("fill",
		_style(Color(0.67, 0.42, 0.94), Color(0.67, 0.42, 0.94), 6))
	info_stack.add_child(_cargo_bar)
	_quest = _make_label("", info_stack, 20, Color(0.73, 0.93, 0.88))

	var top := HBoxContainer.new()
	top.name = "Primary actions"
	top.anchor_left = 1.0
	top.anchor_right = 1.0
	top.offset_left = -374
	top.offset_right = -22
	top.offset_top = 26
	top.offset_bottom = 96
	top.add_theme_constant_override("separation", 10)
	_hud.add_child(top)
	var home := _make_button("БАЗА", top, _open_shop)
	home.custom_minimum_size = Vector2(162, 66)
	var pause := _make_button("ПАУЗА", top, _toggle_pause)
	pause.custom_minimum_size = Vector2(160, 66)

	_zone_label = _make_label("ЗОНА 01  /  ТИХИЙ СЕКТОР", _hud, 22,
		Color(0.36, 0.96, 0.78))
	_zone_label.anchor_left = 0.49
	_zone_label.anchor_right = 0.75
	_zone_label.offset_left = -150
	_zone_label.offset_right = 0
	_zone_label.offset_top = 28
	_zone_label.offset_bottom = 65

	var toast_panel := _make_panel(_hud, "Signal notification",
		Color(0.02, 0.08, 0.12, 0.92), Color(0.27, 0.76, 0.64), 14)
	toast_panel.anchor_left = 0.31
	toast_panel.anchor_right = 0.69
	toast_panel.anchor_top = 0.23
	toast_panel.anchor_bottom = 0.23
	toast_panel.offset_top = -22
	toast_panel.offset_bottom = 44
	_message = _make_label("", toast_panel, 24, Color(0.94, 1.0, 0.90))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.visible = false

	_stick_base = Panel.new()
	_stick_base.name = "Analog membrane joystick"
	_stick_base.anchor_top = 1.0
	_stick_base.anchor_bottom = 1.0
	_stick_base.offset_left = 30
	_stick_base.offset_right = 228
	_stick_base.offset_top = -244
	_stick_base.offset_bottom = -46
	_stick_base.add_theme_stylebox_override("panel",
		_style(Color(0.06, 0.19, 0.22, 0.57), Color(0.23, 0.74, 0.62, 0.68), 105))
	_hud.add_child(_stick_base)
	_stick_knob = Panel.new()
	_stick_knob.name = "Move anchor"
	_stick_knob.size = Vector2(60, 60)
	_stick_knob.position = Vector2(69, 69)
	_stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_knob.add_theme_stylebox_override("panel",
		_style(Color(0.23, 0.88, 0.67, 0.90), Color(0.86, 1.0, 0.85), 36))
	_stick_base.add_child(_stick_knob)

	var abilities := VBoxContainer.new()
	abilities.name = "Three survival mutations"
	abilities.anchor_left = 1.0
	abilities.anchor_right = 1.0
	abilities.anchor_top = 1.0
	abilities.anchor_bottom = 1.0
	abilities.offset_left = -245
	abilities.offset_right = -26
	abilities.offset_top = -287
	abilities.offset_bottom = -40
	abilities.add_theme_constant_override("separation", 9)
	_hud.add_child(abilities)
	for id in ["AB-PULL", "AB-MOVE", "AB-DAMAGE"]:
		var b := _make_button(id, abilities, _use_ability.bind(id))
		b.custom_minimum_size = Vector2(212, 70)
		_skill_buttons[id] = b

	_reward_button = _make_button("НАГОРОДА", _hud, _claim_quest)
	_reward_button.anchor_left = 0.45
	_reward_button.anchor_right = 0.61
	_reward_button.anchor_top = 1.0
	_reward_button.anchor_bottom = 1.0
	_reward_button.offset_top = -105
	_reward_button.offset_bottom = -43

	_shop = _make_panel(_hud, "Evolution and pause",
		Color(0.025, 0.054, 0.095, 0.985), Color(0.22, 0.82, 0.66), 26)
	_shop.anchor_left = 0.5
	_shop.anchor_right = 0.5
	_shop.anchor_top = 0.5
	_shop.anchor_bottom = 0.5
	_shop.offset_left = -440
	_shop.offset_right = 440
	_shop.offset_top = -318
	_shop.offset_bottom = 318
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(826, 575)
	_shop.add_child(scroll)
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(810, 0)
	holder.add_theme_constant_override("separation", 14)
	scroll.add_child(holder)
	_shop_content = VBoxContainer.new()
	_shop_content.add_theme_constant_override("separation", 13)
	holder.add_child(_shop_content)
	var heading := _make_label("ГЕНОМНА ЛАБОРАТОРІЯ", _shop_content, 31,
		Color(0.33, 1.0, 0.79))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_balance = _make_label("", _shop_content, 24, Color(0.91, 0.96, 1.0))
	_shop_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var upgrade_grid := GridContainer.new()
	upgrade_grid.columns = 2
	upgrade_grid.add_theme_constant_override("h_separation", 12)
	upgrade_grid.add_theme_constant_override("v_separation", 10)
	_shop_content.add_child(upgrade_grid)
	for i in range(6):
		var b := _make_button("", upgrade_grid, _buy_upgrade.bind(i))
		b.custom_minimum_size = Vector2(393, 62)
		_shop_buttons.append(b)
	_relay_button = _make_button("ОРГАНІЧНЕ РЕЛЕ", _shop_content, _buy_relay)
	_relay_button.custom_minimum_size.y = 62
	var unlocks := HBoxContainer.new()
	unlocks.add_theme_constant_override("separation", 12)
	_shop_content.add_child(unlocks)
	var move_btn := _make_button("РИВОК · 35", unlocks, _unlock.bind("AB-MOVE"))
	move_btn.custom_minimum_size = Vector2(393, 65)
	var damage_btn := _make_button("ІМПУЛЬС · 80", unlocks, _unlock.bind("AB-DAMAGE"))
	damage_btn.custom_minimum_size = Vector2(393, 65)
	_make_button("ОТРИМАТИ НАГОРОДУ ЗА ЗАВДАННЯ", _shop_content, _claim_quest)
	_make_button("ПОВЕРНУТИСЯ ДО ЕКСПЕДИЦІЇ", _shop_content, _close_panel)

	_pause_content = VBoxContainer.new()
	_pause_content.add_theme_constant_override("separation", 32)
	holder.add_child(_pause_content)
	var pause_heading := _make_label("ПАУЗА", _pause_content, 40, Color(0.33, 1.0, 0.79))
	pause_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pause_description := _make_label(
		"Дослідження призупинене.\nВідкритий світ зберігає твій прогрес.", _pause_content, 26)
	pause_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_make_button("ПРОДОВЖИТИ", _pause_content, _close_panel)
	_shop.visible = false
	_update_hud()

func _update_hud() -> void:
	if not is_instance_valid(player) or not _stats:
		return
	var level: int = Rules.level(profile)
	var bank: int = int(profile["bank"])
	var units: int = int(profile["cargo_units"])
	var capacity: int = Rules.capacity(profile)
	_stats.text = "ГЕНОМ %d   •   РІВЕНЬ %d    •   HP %d/%d" % [
		bank, level, ceili(float(profile["health"])), int(Rules.maximum_health(profile))
	]
	_health_bar.max_value = Rules.maximum_health(profile)
	_health_bar.value = float(profile["health"])
	_cargo_bar.max_value = capacity
	_cargo_bar.value = units
	var stage: int = int(profile["quest_stage"])
	_quest.text = ("ЗАВДАННЯ: %s   %d/%d" % [
		QUEST_NAMES[stage], mini(Rules.quest_progress(profile), Rules.QUEST_GOALS[stage]),
		Rules.QUEST_GOALS[stage]
	]) if stage < QUEST_NAMES.size() else "ЗАВДАННЯ ВИКОНАНІ · ДОСЛІДЖУЙ СВІТ"
	var current_sector := _zone_at(player.global_position)
	var zone_titles := ["ТИХИЙ БІОМ", "СИНАПТИЧНИЙ КРИСТАЛ", "СЕРЦЕ РЕАКТОРА"]
	_zone_label.text = "ЗОНА %02d   /   %s" % [current_sector + 1, zone_titles[current_sector]]
	var names := {"AB-PULL":"ХВАТКА", "AB-MOVE":"РИВОК", "AB-DAMAGE":"ІМПУЛЬС"}
	for id in _skill_buttons.keys():
		var cd: float = float(profile["cooldowns"].get(id, 0.0))
		var owned: bool = profile["abilities"].has(id)
		_skill_buttons[id].text = "%s    %s" % [
			names[id], ("%.1f c" % cd) if cd > 0.0 else ("ГОТОВО" if owned else "ЗАКРИТО")
		]
		_skill_buttons[id].disabled = cd > 0.0 or _paused
	for i in range(_shop_buttons.size()):
		var current_level: int = int(profile["upgrades"][i])
		var limit: int = 2 if i == 4 else 20
		var locked: bool = i in [3, 4] and level < 2
		var price: int = Rules.upgrade_price(profile, i)
		_shop_buttons[i].text = "%s  %d/%d    •    %s" % [
			UPGRADE_NAMES[i].to_upper(), current_level, limit,
			"РІВЕНЬ 2" if locked else ("МАКС." if current_level >= limit else str(price))
		]
		_shop_buttons[i].disabled = locked or current_level >= limit or bank < price
	_relay_button.text = "ОРГАНІЧНЕ РЕЛЕ %d/2   •   %s" % [
		int(profile["relay_level"]),
		"РІВЕНЬ 2" if level < 2 else ("МАКС." if int(profile["relay_level"]) >= 2 else str(Rules.relay_price(profile)))
	]
	_relay_button.disabled = level < 2 or int(profile["relay_level"]) >= 2 or bank < Rules.relay_price(profile)
	_shop_balance.text = "ДОСТУПНИЙ ГЕНОМ: %d     |     ВАНТАЖ: %d/%d" % [bank, units, capacity]
	_reward_button.disabled = not _inside_base() or stage >= QUEST_NAMES.size() or Rules.quest_progress(profile) < Rules.QUEST_GOALS[stage]
	_shop.visible = _paused
	_shop_content.visible = _shop_open
	_pause_content.visible = not _shop_open
	if _message:
		if Time.get_ticks_msec() / 1000.0 > _toast_until:
			_message.text = ""
		_message.get_parent().visible = not _message.text.is_empty()
