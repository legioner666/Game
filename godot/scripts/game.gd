extends Node3D
## Parasite Evolution: original Godot 4.4 3D vertical slice.
## Distinct from the Crown Rush Godot project in a different repository.

const Rules = preload("res://scripts/economy.gd")
const Slime = preload("res://scripts/slime.gd")
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
var mobs: Array[Dictionary] = []
var _hud: Control
var _stats: Label
var _quest: Label
var _message: Label
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
var _stick_base: ColorRect
var _stick_knob: ColorRect
var _last_heading := Vector3.FORWARD

func _ready() -> void:
	profile = _load_profile()
	_build_world()
	player = Slime.new()
	player.name = "Amorphous Parasite"
	add_child(player)
	player.global_position = Vector3(float(profile["x"]), SAFE_POINT.y, float(profile["z"]))
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.5
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
	var creature := Node3D.new()
	creature.name = "Warden" if warden else "Specimen %s" % str(mobs.size())
	add_child(creature)
	creature.position = point
	var shell := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.85 if warden else 0.35
	mesh.height = 2.5 if warden else 1.1
	shell.mesh = mesh
	shell.position.y = 0.65 if warden else 0.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.69, 0.24, 0.16) if warden else Color(0.25, 0.57, 0.61)
	shell.material_override = mat
	creature.add_child(shell)
	var hp: float = 200.0 if warden else 24.0 + float(zone) * 18.0
	mobs.append({
		"node": creature, "home": point, "zone": zone, "warden": warden,
		"hp": hp, "max_hp": hp, "alive": true, "respawn": 0.0, "pulled": 0.0,
		"attack": 0.0, "warning": 0.0
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
			continue
		mob["attack"] = maxf(0.0, float(mob["attack"]) - delta)
		mob["pulled"] = maxf(0.0, float(mob["pulled"]) - delta)
		var distance := node.global_position.distance_to(player.global_position)
		if mob["warning"] > 0.0:
			mob["warning"] -= delta
			if mob["warning"] <= 0.0 and distance < 3.0 and not safe:
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
					_note("Наглядач готує удар!")
				else:
					_hurt(4.0 + float(mob["zone"]) * 2.0)
		var movement: Vector3 = destination - node.global_position
		movement.y = 0.0
		if movement.length_squared() > 0.05:
			var velocity: float = 11.0 if mob["pulled"] > 0.0 else (1.3 if mob["warden"] else 2.0)
			var step := movement.limit_length(velocity * delta)
			var candidate := node.global_position + step
			if _zone_at(candidate) == mob["zone"] and not _inside_base(candidate):
				node.global_position = candidate
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
	mob["node"].visible = false
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
	var target := player.global_position + Vector3(0, 19, -14)
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
	_move_stick = ((screen_point - center) / 68.0).limit_length(1.0)
	_stick_knob.position = Vector2(70, 70) + _move_stick * 50.0

func _reset_stick() -> void:
	_stick_id = -1
	_move_stick = Vector2.ZERO
	if _stick_knob:
		_stick_knob.position = Vector2(70, 70)

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

func _make_button(text: String, parent: Control, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 42)
	parent.add_child(b)
	b.pressed.connect(action)
	return b

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	_stats = Label.new()
	_stats.position = Vector2(22, 14)
	_stats.add_theme_font_size_override("font_size", 21)
	_hud.add_child(_stats)
	_quest = Label.new()
	_quest.position = Vector2(22, 89)
	_quest.add_theme_font_size_override("font_size", 20)
	_hud.add_child(_quest)
	_message = Label.new()
	_message.anchor_left = 0.27
	_message.anchor_right = 0.77
	_message.anchor_top = 0.19
	_message.anchor_bottom = 0.19
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 22)
	_hud.add_child(_message)
	var top := HBoxContainer.new()
	top.anchor_left = 1.0
	top.anchor_right = 1.0
	top.offset_left = -275
	top.offset_right = -20
	top.offset_top = 18
	top.offset_bottom = 67
	_hud.add_child(top)
	_make_button("База", top, _open_shop)
	_make_button("Пауза", top, _toggle_pause)
	_stick_base = ColorRect.new()
	_stick_base.color = Color(0.10, 0.20, 0.22, 0.78)
	_stick_base.anchor_top = 1.0
	_stick_base.anchor_bottom = 1.0
	_stick_base.offset_left = 35
	_stick_base.offset_right = 215
	_stick_base.offset_top = -216
	_stick_base.offset_bottom = -36
	_hud.add_child(_stick_base)
	_stick_knob = ColorRect.new()
	_stick_knob.color = Color(0.25, 0.82, 0.58, 0.9)
	_stick_knob.size = Vector2(40, 40)
	_stick_knob.position = Vector2(70, 70)
	_stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_base.add_child(_stick_knob)
	var abilities := VBoxContainer.new()
	abilities.anchor_left = 1.0
	abilities.anchor_right = 1.0
	abilities.anchor_top = 1.0
	abilities.anchor_bottom = 1.0
	abilities.offset_left = -240
	abilities.offset_right = -24
	abilities.offset_top = -262
	abilities.offset_bottom = -30
	_hud.add_child(abilities)
	for id in ["AB-PULL", "AB-MOVE", "AB-DAMAGE"]:
		_skill_buttons[id] = _make_button(id, abilities, _use_ability.bind(id))
	var reward := Button.new()
	reward.text = "Нагорода"
	reward.anchor_left = 0.49
	reward.anchor_right = 0.65
	reward.anchor_top = 1.0
	reward.anchor_bottom = 1.0
	reward.offset_top = -65
	reward.offset_bottom = -18
	_hud.add_child(reward)
	reward.pressed.connect(_claim_quest)
	_shop = PanelContainer.new()
	_shop.anchor_left = 0.5
	_shop.anchor_right = 0.5
	_shop.anchor_top = 0.5
	_shop.anchor_bottom = 0.5
	_shop.offset_left = -330
	_shop.offset_right = 330
	_shop.offset_top = -300
	_shop.offset_bottom = 300
	_hud.add_child(_shop)
	var content := VBoxContainer.new()
	_shop.add_child(content)
	var heading := Label.new()
	heading.text = "Лабораторія адаптацій"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	content.add_child(heading)
	var upgrade_grid := GridContainer.new()
	upgrade_grid.columns = 2
	content.add_child(upgrade_grid)
	for i in range(6):
		var b := _make_button("", upgrade_grid, _buy_upgrade.bind(i))
		b.custom_minimum_size = Vector2(305, 42)
		_shop_buttons.append(b)
	_relay_button = _make_button("", content, _buy_relay)
	_make_button("Відкрити: Ривок", content, _unlock.bind("AB-MOVE"))
	_make_button("Відкрити: Сильний удар", content, _unlock.bind("AB-DAMAGE"))
	_make_button("Отримати нагороду завдання", content, _claim_quest)
	_make_button("Продовжити", content, _close_panel)
	_shop.visible = false
	_update_hud()

func _update_hud() -> void:
	if not is_instance_valid(player) or not _stats:
		return
	var lvl: int = Rules.level(profile)
	_stats.text = "HP %d/%d  Геном %d  Рівень %d\nВантаж %d/%d  Реле %d/2" % [
		ceili(float(profile["health"])), int(Rules.maximum_health(profile)), int(profile["bank"]), lvl,
		int(profile["cargo_units"]), Rules.capacity(profile), int(profile["relay_level"])
	]
	var stage: int = int(profile["quest_stage"])
	_quest.text = "%s  %d/%d" % [
		QUEST_NAMES[stage] if stage < QUEST_NAMES.size() else "Досліджуй світ",
		Rules.quest_progress(profile), Rules.QUEST_GOALS[stage] if stage < 5 else 0
	]
	for id in _skill_buttons.keys():
		var cooldown: float = float(profile["cooldowns"][id])
		_skill_buttons[id].text = "%s  %s" % [id,
			("%.1f с" % cooldown) if cooldown > 0.0 else ("OK" if profile["abilities"].has(id) else "Заблоковано")]
	for i in range(_shop_buttons.size()):
		var price := Rules.upgrade_price(profile, i)
		_shop_buttons[i].text = "%s %d  •  %d" % [UPGRADE_NAMES[i], int(profile["upgrades"][i]), price]
	if _relay_button:
		_relay_button.text = "Органічне реле: %d/2  •  %d" % [
			int(profile["relay_level"]), Rules.relay_price(profile)]
	if _message and Time.get_ticks_msec() / 1000.0 > _toast_until:
		_message.text = ""
