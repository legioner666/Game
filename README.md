# Parasite Evolution

> **Стан QA (20.11.2026):** першій Android-збірці `v0.1.0-debug` **відмовлено в прийманні** за результатами відео гравця: слабка графіка, анімації та інтерфейс. Не завантажуйте її як готову гру. Переробка v0.2 проходить перевірку в [PR #2](https://github.com/legioner666/Game/pull/2), [скриншоти реального рендера](https://github.com/legioner666/Game/tree/gpt/parasite-rebuild-v02/qa/screenshots), а [прямий APK v0.2 (тільки для тестування на Android)](https://github.com/legioner666/Game/releases/download/parasite-v0.2.0-qa/parasite-evolution-debug.apk) позначений як QA-only. Тест на фізичному Android після переробки поки не підтверджено.\n\n
Original 3D mobile action game about an amorphous slime organism with retractile organic tentacles.

**Active engine:** Godot 4.4 (GDScript) in `godot/`.  
**Preserved Unity prototype:** Unity 6000.3.11f1 (C#) in `unity/` for later migration.

This repository is **separate** from [Crown Rush](https://github.com/legioner666/Game-). It does not contain or build Crown Rush.

## Project layout
- `godot/` — active playable prototype, tests and Android export preset.
- `unity/` — existing Unity prototype source preserved without engine conversion.
- `docs/` — product vision, world, mechanics, art, engineering and QA notes.
- `.github/workflows/` — isolated Godot CI and (optional) standalone Unity-free C# checks.

## Local Godot start

Open `godot/project.godot` in Godot 4.4.1, or run:

```bash
godot --headless --path godot --import
godot --path godot
```

Android APK will be published as a GitHub Actions artifact **only when a build succeeds**; see Actions. This project contains no ads, payment integrations or third-party game assets.

## Verified Android prototype build

First successful Godot 4.4.1 CI run: [#44621505624](https://github.com/legioner666/Game/actions/runs/44621505624).

- Godot project import: PASS.
- 29 pure economy tests: PASS.
- Headless startup: PASS.
- ARM64 debug APK export, APK verification/signature and artifact upload: PASS.
- Device installation, multi-touch, graphics, FPS and crashes: **not yet tested**.

[Download the Android debug build artifact (ZIP)](https://github.com/legioner666/Game/actions/runs/44621505624/artifacts/14577755406). Extract `parasite-evolution-debug.apk` from ZIP and install on Android. The debug key is generated per CI run, so later debug builds may require uninstalling the previous version first. This artifact expires 2026-12-03.

The **current** build status and new APKs appear under [GitHub Actions](https://github.com/legioner666/Game/actions/workflows/godot-ci.yml).

## Direct APK (no ZIP)

[Download parasite-evolution-debug.apk directly](https://github.com/legioner666/Game/releases/download/parasite-v0.1.0-debug/parasite-evolution-debug.apk) — verified prerelease asset from GitHub Actions run #44621505624. This is a **debug test build**, not a Google Play release. Android and Play Protect may still show security prompts for sideloaded applications; this project does not disable or bypass them. The signing key for this historical build was generated in CI, so subsequent independently signed debug builds may require removal of the old installation before updating.
