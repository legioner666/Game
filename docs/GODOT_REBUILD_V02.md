# Parasite Evolution 0.2 — Godot rebuild: evidence and release gate

**Engine:** Godot 4.4.1, GDScript / GL Compatibility. **Scope:** independent `legioner666/Game`; Crown Rush unchanged.

## Why the first APK was rejected

The owner supplied a phone recording `5174.mp4`, showing that `v0.1.0-debug` only demonstrated technical mechanics: barely readable black spider-like model, simple tiled floors, placeholder enemies and poor portrait/landscape touch presentation. CI accepted the build but no physical playtest or screenshot review took place before publishing it.

## What was actually changed in 0.2

- **Organism:** 10 asymmetric retractable organic supports, each represented by one continuous tapered, curved tube mesh with pulsing shader, supporting a larger irregular multi-lobed slime body. Animated anchoring, contraction, radial rest pose and visible collection tendrils. Three visible mutation stages based on experience, stage-specific bio-luminescence and growth.
- **World:** three sector-specific organic floor shaders and color palettes; rune circuits, bio-lights, crystal and fungal growth, pylons, distinct safe-base rings, softer global lighting. Flat prototype tile grid removed.
- **Enemies:** new differentiated procedural appearance by biome, separate Warden silhouette; physical CharacterBody3D collisions against static walls and telegraphed Warden attacks.
- **Combat feedback:** timed capture rings, sparks and impulse waves, visible boss attack telegraph, hit flash and death feedback. No copied Alien Invasion assets.
- **Controls / UI:** enlarged landscape joystick and action controls, dark HUD surfaces, HUD health/cargo bars, legible sector display, contextual quest tracker, full-screen dim layer and a readable mutation shop.
- **Gameplay rules preserved:** capture/cargo/deposit, six types of upgrade, three abilities, organic relay, 5-step quest chain, 22 enemies, three connected sectors, death returns to safe zone with provisional 10% loss, save backup and schema validation.
- **Test pipeline:** game smoke test drives the real scene through upgrades, unlock, dash, capture, VFX, death, progress save and joystick touch input; separate rendered screenshot CI captures four images through an Xvfb Godot renderer.

## Evidence (NOT Android device QA)

- `godot/tests/economy_test.gd`: 29 rule checks.
- `godot/tests/gameplay_smoke.gd`: >24 gameplay/scene checks (check current CI logs).
- Godot CLI import and headless boot as part of CI.
- Godot 4.4.1 Android ARM64 debug APK build (only from the successful CI run), `apksigner verify`.
- **Four real rendered scene frames**, committed under `qa/screenshots/`:
  - [01 — organism and base](../qa/screenshots/01-organism-base.png)
  - [02 — synaptic biome and specimens](../qa/screenshots/02-synaptic-sector.png)
  - [03 — reactor and Warden at higher mutation stage](../qa/screenshots/03-reactor-warden.png)
  - [04 — mutation shop](../qa/screenshots/04-evolution-shop.png)

These are captured using a Linux Mesa software renderer in GitHub Actions. Screenshots and CI can catch regressions; **they cannot replace player feedback from physical Android hardware**.

## Release gate for any next public APK

1. Get explicit review of these four actual screenshots, no claim that output is polished merely because source was compiled.
2. Install debug APK on Android and perform a human 5-minute loop: move, capture, deposit, upgrade, unlock, use each ability, face Warden, die, return, save, restart.
3. Observe both landscape orientations, different aspect ratios, touch input, FPS under normal gameplay, heating and crash reports.
4. No release/Play Store claim until visual quality and core gameplay are confirmed. The previous `v0.1.0-debug` release remains a **rejected technical prototype**.

## Limitations still open

- No fully sculpted production character with true volumetric fluid behavior or bespoke rigged animation.
- Procedural world still requires environmental composition, audio, story content, AI navigation around complex obstacles and deeper boss patterns.
- Visual test on Linux is not a mobile GPU performance benchmark. Procedural tube mesh update cost needs profiling.
- No shader-driven destructive environment, advanced particles, controller accessibility testing, account services or monetization.
- Screenshot frames do not prove full animation smoothness; phone video playtest required.

**Unity migration:** The Unity C# prototype remains untouched under `unity/` and is not linked into Godot builds. Behavioural parity should be checked against `docs/ENGINE_TRANSITION.md`.
