# Parasite Evolution — active Godot prototype

Godot 4.4.1 project for Android (landscape, GDScript, GL Compatibility renderer).

**Start:**
```bash
godot --headless --path godot --import
godot --path godot
```
**Economy tests (no display):**
```bash
godot --headless --path godot --script res://tests/economy_test.gd
```

Gameplay: original asymmetric slime and eight non-permanent procedural support tendrils; three connected sectors with a safe base, 22 sample mobs and a Warden; touch joystick (left bottom), three ability buttons (right bottom), auto-capture, cargo, genome, upgrades, organic relay and partial-loss respawn. Keyboard WASD/arrows via built-in ui_left/right/up/down actions; Escape for pause. The save is in `user://parasite-evolution-v1.json`.

No art, Unity project or dependencies from Crown Rush are included. No payments, ads, analytics or third-party game assets.

## Limits
This is a prototype, not a ready-to-publish game. Mob navigation is basic, 3D art is procedural, and QA on real Android hardware is mandatory. Death penalty and prices are provisional. CI may produce a debug APK artifact; publishing and Play Store readiness are separate. The Unity version is preserved in `../unity/` but is not built by Godot.

## Later Unity migration
Keep game rules and acceptance tests engine-independent. Behavior mapping: `scripts/economy.gd` ↔ `unity/Assets/_Game/Scripts/ProfileData.cs`; gameplay/controls ↔ `GameSession.cs` / `SlimeActor.cs` / `SlimeVisual.cs`. Save formats differ, do not blindly copy Android save files across engines. See `../docs/ENGINE_TRANSITION.md`.
