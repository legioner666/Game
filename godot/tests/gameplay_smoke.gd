extends SceneTree
## Exercises real Godot scene methods (not only the economy rules).
## Run: godot --headless --path godot --script res://tests/gameplay_smoke.gd

const RULES = preload("res://scripts/economy.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS gameplay: ", label)
	else:
		failed += 1
		push_error("FAIL gameplay: " + label)

func _run() -> void:
	var err := change_scene_to_file("res://scenes/main.tscn")
	_check(err == OK, "scene can be opened")
	if err != OK:
		quit(1)
		return
	await process_frame
	await physics_frame
	var game := current_scene
	if game == null or game.player == null:
		_check(false, "game initialized")
		quit(1)
		return
	_check(game.mobs.size() == 22, "three sectors and 22 original enemies present")
	_check(game.player._legs.size() == 10, "procedural organism has ten support limbs")
	_check(game.camera.size <= 14.0, "player camera zoomed for mobile readability")
	_check(game.fx != null, "impact VFX pool exists")
	_check(game._inside_base(), "safe zone starts active")
	_check(RULES.validate(game.profile), "fresh progress can validate")
	var first: Dictionary = game.mobs[0]
	_check(first["node"] is CharacterBody3D, "mobs collide with world rather than passing walls")
	game.profile["bank"] = 400
	game.profile["biomass"] = 35
	game.player.evolve(RULES.level(game.profile), game.profile["upgrades"])
	_check(game.player.mutation_stage == 2, "evolution visibly unlocks a new body stage")
	game._open_shop()
	_check(game._paused and game._shop_open, "safe-zone mutation panel pauses combat")
	game._buy_upgrade(1)
	_check(int(game.profile["upgrades"][1]) == 1, "capacity mutation bought")
	game._buy_relay()
	_check(int(game.profile["relay_level"]) == 1, "organic relay bought")
	game._unlock("AB-MOVE")
	_check(game.profile["abilities"].has("AB-MOVE"), "dash ability purchased")
	game._close_panel()
	_check(not game._paused and not game._shop_open, "closing mutations resumes movement")
	game.player.global_position = Vector3(-19.0, 0.62, -3.0)
	game.player.reset_contacts()
	await physics_frame
	game._use_ability("AB-MOVE")
	_check(float(game.profile["cooldowns"]["AB-MOVE"]) > 0.0, "dash has cooldown")
	game.player.global_position = first["node"].global_position + Vector3(0.0, 0.05, 1.1)
	game.player.reset_contacts()
	game._damage_mob(first, 999.0)
	_check(not first["alive"], "lethal capture updates enemy state")
	_check(int(game.profile["cargo_units"]) > 0, "captured samples fill cargo")
	_check(game.fx.pulses.size() > 0, "successful capture triggers visual feedback")
	game.profile["bank"] = 100
	game.player.global_position = Vector3(-2.0, 0.62, -5.0)
	game.player.reset_contacts()
	game._hurt(500.0)
	_check(int(game.profile["death_serial"]) == 1, "death transaction has serial")
	_check(int(game.profile["bank"]) < 100, "death charges only partial genome penalty")
	_check(game._inside_base(), "death teleports organism back to safe zone")
	game._save_game()
	var save_path := "user://parasite-evolution-v1.json"
	_check(FileAccess.file_exists(save_path), "progress is persisted after real gameplay loop")
	var loaded = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	_check(typeof(loaded) == TYPE_DICTIONARY and RULES.validate(loaded), "actual saved JSON validates")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = game._stick_base.get_global_rect().get_center() + Vector2(55.0, 0)
	game._input(touch)
	_check(game._move_stick.x > 0.2, "screen joystick accepts touch")
	touch.pressed = false
	game._input(touch)
	_check(game._move_stick == Vector2.ZERO, "touch release stops player")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".tmp"))
	print("Godot gameplay smoke: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
