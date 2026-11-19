extends RefCounted
## Pure game rules, without SceneTree/Node dependencies.
## Keep this module behaviorally equivalent to Unity Balance/Economy for future migration.

const FORMAT := "parasite-evolution"
const LIMIT := 1000000000
const MAX_UPGRADE := 20
const DEATH_PENALTY_BPS := 1000 # Provisional: partial loss, not owner-approved percentage.
const QUEST_GOALS := [4, 2, 1, 3, 1]
const QUEST_REWARDS := [12, 18, 25, 35, 60]
const ABILITY_COST := {"AB-PULL": 0, "AB-MOVE": 35, "AB-DAMAGE": 80}

static func fresh() -> Dictionary:
	return {
		"format": FORMAT, "schema": 1, "revision": 0,
		"bank": 0, "biomass": 0, "cargo_units": 0, "cargo_value": 0,
		"captures": 0, "deposits": 0, "upgrades_bought": 0,
		"quest_stage": 0, "visited_zones": 1, "warden_kills": 0, "death_serial": 0,
		"upgrades": [0, 0, 0, 0, 0, 0], "abilities": ["AB-PULL"],
		"health": 50.0, "x": -22.0, "z": -10.0,
		"cooldowns": {"AB-PULL": 0.0, "AB-MOVE": 0.0, "AB-DAMAGE": 0.0},
		"relay_level": 0, "remote_transfers": 0, "relay_remaining": 0.0
	}

static func level(p: Dictionary) -> int:
	var remaining: int = int(p["biomass"])
	var n := 1
	while n < 100 and remaining >= n * 30:
		remaining -= n * 30
		n += 1
	return n

static func capacity(p: Dictionary) -> int:
	return 6 + int(p["upgrades"][1]) * 2

static func maximum_health(p: Dictionary) -> float:
	return 50.0 + 10.0 * float(p["upgrades"][5])

static func speed(p: Dictionary) -> float:
	return 4.5 + 0.25 * float(p["upgrades"][2])

static func capture_radius(p: Dictionary) -> float:
	return 3.2 + 0.18 * float(p["upgrades"][3])

static func channels(p: Dictionary) -> int:
	return mini(3, 1 + int(p["upgrades"][4]))

static func capture_damage(p: Dictionary) -> float:
	return 12.0 + 3.0 * float(p["upgrades"][0])

static func can_carry(p: Dictionary, units: int) -> bool:
	return units > 0 and units <= capacity(p) - int(p["cargo_units"])

static func validate(p: Dictionary) -> bool:
	if p.get("format", "") != FORMAT or int(p.get("schema", -1)) != 1:
		return false
	if not p.get("upgrades", null) is Array or not p.get("abilities", null) is Array:
		return false
	if p["upgrades"].size() != 6:
		return false
	for n in p["upgrades"]:
		if typeof(n) != TYPE_INT and typeof(n) != TYPE_FLOAT:
			return false
		if n < 0 or n > MAX_UPGRADE:
			return false
	for k in ["revision", "bank", "biomass", "cargo_units", "cargo_value", "captures",
			"deposits", "upgrades_bought", "quest_stage", "visited_zones", "warden_kills",
			"death_serial", "relay_level", "remote_transfers"]:
		if not p.has(k) or typeof(p[k]) not in [TYPE_INT, TYPE_FLOAT] or p[k] < 0:
			return false
	for k in ["bank", "biomass", "cargo_value"]:
		if int(p[k]) > LIMIT:
			return false
	if int(p["cargo_units"]) > capacity(p) or int(p["quest_stage"]) > 5:
		return false
	if int(p["visited_zones"]) > 7 or int(p["relay_level"]) > 2:
		return false
	if not p.get("cooldowns", null) is Dictionary:
		return false
	for k in ["health", "x", "z", "relay_remaining"]:
		if not p.has(k) or typeof(p[k]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		if not is_finite(float(p[k])):
			return false
	if p["health"] < 0.0 or p["health"] > maximum_health(p):
		return false
	if absf(p["x"]) > 1000.0 or absf(p["z"]) > 1000.0:
		return false
	if p["relay_remaining"] < 0.0 or p["relay_remaining"] > 120.0:
		return false
	for id in ABILITY_COST.keys():
		if not p["cooldowns"].has(id):
			return false
		var t: float = float(p["cooldowns"][id])
		if not is_finite(t) or t < 0.0:
			return false
	var seen := {}
	for id in p["abilities"]:
		if not ABILITY_COST.has(id) or seen.has(id):
			return false
		seen[id] = true
	return true

static func capture(p: Dictionary, units: int, value: int, xp: int, warden: bool = false) -> bool:
	if not can_carry(p, units) or value < 0 or xp < 0:
		return false
	if int(p["cargo_value"]) + value > LIMIT or int(p["biomass"]) + xp > LIMIT:
		return false
	if int(p["captures"]) >= 2147483647 or (warden and int(p["warden_kills"]) >= 2147483647):
		return false
	p["cargo_units"] += units
	p["cargo_value"] += value
	p["biomass"] += xp
	p["captures"] += 1
	if warden:
		p["warden_kills"] += 1
	return true

static func deposit(p: Dictionary) -> bool:
	if int(p["cargo_units"]) <= 0 or int(p["bank"]) + int(p["cargo_value"]) > LIMIT:
		return false
	if int(p["deposits"]) >= 2147483647:
		return false
	p["bank"] += p["cargo_value"]
	p["cargo_value"] = 0
	p["cargo_units"] = 0
	p["deposits"] += 1
	return true

static func relay_interval(p: Dictionary) -> float:
	match int(p["relay_level"]):
		1: return 30.0
		2: return 18.0
	return 0.0

static func relay_price(p: Dictionary) -> int:
	match int(p["relay_level"]):
		0: return 60
		1: return 150
	return -1

static func buy_relay(p: Dictionary) -> bool:
	var cost := relay_price(p)
	if level(p) < 2 or cost < 0 or int(p["bank"]) < cost:
		return false
	p["bank"] -= cost
	p["relay_level"] += 1
	return true

static func relay_transfer(p: Dictionary) -> bool:
	if int(p["relay_level"]) <= 0 or int(p["cargo_units"]) <= 0:
		return false
	if int(p["bank"]) + int(p["cargo_value"]) > LIMIT or int(p["remote_transfers"]) >= 2147483647:
		return false
	p["bank"] += p["cargo_value"]
	p["cargo_value"] = 0
	p["cargo_units"] = 0
	p["remote_transfers"] += 1
	return true

static func upgrade_price(p: Dictionary, index: int) -> int:
	if index < 0 or index > 5:
		return -1
	return mini(LIMIT, ceili(float(30 if index == 4 else 8) * pow(1.55, float(p["upgrades"][index]))))

static func buy_upgrade(p: Dictionary, index: int) -> bool:
	if index < 0 or index > 5:
		return false
	if int(p["upgrades"][index]) >= (2 if index == 4 else MAX_UPGRADE):
		return false
	if index in [3, 4] and level(p) < 2:
		return false
	var price := upgrade_price(p, index)
	if int(p["bank"]) < price:
		return false
	p["bank"] -= price
	p["upgrades"][index] += 1
	p["upgrades_bought"] += 1
	return true

static func unlock(p: Dictionary, id: String) -> bool:
	var price: int = int(ABILITY_COST.get(id, -1))
	if price < 0 or p["abilities"].has(id) or int(p["bank"]) < price:
		return false
	p["bank"] -= price
	p["abilities"].append(id)
	return true

static func quest_progress(p: Dictionary) -> int:
	match int(p["quest_stage"]):
		0: return int(p["captures"])
		1: return int(p["deposits"])
		2: return int(p["upgrades_bought"])
		3:
			var bits: int = int(p["visited_zones"])
			return int(bool(bits & 1)) + int(bool(bits & 2)) + int(bool(bits & 4))
		4: return int(p["warden_kills"])
	return 0

static func claim_quest(p: Dictionary) -> bool:
	var stage: int = int(p["quest_stage"])
	if stage < 0 or stage >= QUEST_GOALS.size():
		return false
	if quest_progress(p) < QUEST_GOALS[stage] or int(p["bank"]) + QUEST_REWARDS[stage] > LIMIT:
		return false
	p["bank"] += QUEST_REWARDS[stage]
	p["quest_stage"] += 1
	return true

static func settle_death(p: Dictionary, serial: int, bps: int = DEATH_PENALTY_BPS) -> bool:
	if serial != int(p["death_serial"]) + 1 or bps < 0 or bps > 10000:
		return false
	p["bank"] -= int(int(p["bank"]) * bps / 10000.0)
	p["death_serial"] = serial
	p["health"] = maximum_health(p)
	p["x"] = -22.0
	p["z"] = -10.0
	return true
