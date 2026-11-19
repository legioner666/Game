extends SceneTree
## Run: godot --headless --path godot --script res://tests/economy_test.gd
const Rules = preload("res://scripts/economy.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("PASS ", what)
	else:
		failed += 1
		push_error("FAIL " + what)

func _run() -> void:
	var p := Rules.fresh()
	_check(Rules.validate(p), "fresh schema accepted")
	_check(Rules.level(p) == 1 and Rules.capacity(p) == 6, "starting balance")
	_check(Rules.capture(p, 6, 18, 18), "full capture")
	_check(not Rules.capture(p, 1, 3, 3), "full cargo blocks capture")
	_check(int(p["biomass"]) == 18 and int(p["captures"]) == 1, "rejected capture atomic")
	_check(Rules.deposit(p), "first base deposit")
	_check(not Rules.deposit(p), "double deposit rejected")
	_check(int(p["bank"]) == 18 and int(p["deposits"]) == 1, "base deposit counted")
	p = Rules.fresh()
	p["bank"] = 34
	_check(not Rules.unlock(p, "AB-MOVE"), "insufficient funds")
	p["bank"] = 100
	_check(Rules.unlock(p, "AB-MOVE"), "ability unlock")
	_check(not Rules.unlock(p, "AB-MOVE") and int(p["bank"]) == 65, "unlock only charged once")
	p = Rules.fresh()
	p["bank"] = 300
	_check(not Rules.buy_relay(p), "relay level gate")
	p["biomass"] = 30
	_check(Rules.buy_relay(p) and int(p["bank"]) == 240, "first organic relay")
	_check(Rules.buy_relay(p) and int(p["bank"]) == 90, "second organic relay")
	_check(not Rules.buy_relay(p) and Rules.relay_interval(p) == 18.0, "relay maximum")
	p = Rules.fresh()
	p["relay_level"] = 1
	_check(Rules.capture(p, 2, 9, 6), "collect for relay")
	_check(Rules.relay_transfer(p), "relay delivers carried sample")
	_check(not Rules.relay_transfer(p), "relay does not double credit")
	_check(int(p["bank"]) == 9 and int(p["deposits"]) == 0 and int(p["remote_transfers"]) == 1,
		"relay differs from physical base deposit")
	p = Rules.fresh()
	p["bank"] = 97
	_check(Rules.settle_death(p, 1), "one death")
	_check(int(p["bank"]) == 88 and not Rules.settle_death(p, 1), "death replay protection")
	p = Rules.fresh()
	p["bank"] = 1000
	_check(not Rules.buy_upgrade(p, 4), "channel level two requirement")
	p["biomass"] = 30
	_check(Rules.buy_upgrade(p, 4) and Rules.buy_upgrade(p, 4), "both channels purchased")
	_check(not Rules.buy_upgrade(p, 4) and Rules.channels(p) == 3, "channel cap")
	p = Rules.fresh()
	p["captures"] = 4
	_check(Rules.claim_quest(p), "quest reward")
	_check(not Rules.claim_quest(p), "quest cannot repeat")
	p["schema"] = 2
	_check(not Rules.validate(p), "future schema rejected")
	p = Rules.fresh()
	p["relay_remaining"] = 31.0
	_check(Rules.validate(p), "relay cooldown validates")
	p["relay_remaining"] = -1.0
	_check(not Rules.validate(p), "negative cooldown invalid")
	print("Godot economy checks: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
