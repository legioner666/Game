# Engine selection and migration boundary

Decision (2026-11-19): **Godot 4.4.1 is the active development engine** for Parasite Evolution because the only available workstation is Android. The Unity 6000.3.11f1 prototype is archived in `unity/`, still editable and intact for later testing when access to the Editor becomes available.

- Godot: `godot/` original, standalone 3D project. APK development and mobile playtest happen here.
- Unity: `unity/` original C# source, assets metadata, Editor build script and .NET tests; **no shared binaries or builds**.
- Product design: `docs/` describes intended mechanics, world, art direction and QA; not every design item is implemented in Godot yet.

## Port parity contract

| Behavior | Godot | Unity |
| --- | --- | --- |
| Cargo capacity: starts at 6 | economy.gd | Balance.Capacity |
| Catch value/XP and cargo limits | economy.gd | Economy.Capture |
| Bank and deposit once | economy.gd | Economy.Deposit |
| Organic relay moves owned cargo | economy.gd | Economy.RelayTransfer |
| Partial death penalty (provisional 10%) | economy.gd | Economy.SettleDeath |
| Ability IDs AB-PULL/MOVE/DAMAGE | game.gd | GameSession.Cast |
| Slime supports and retractile tendrils | slime.gd | SlimeVisual.cs |
| Three continuous zones | game.gd | WorldBuilder.cs |

Use behavior tests rather than assumptions of one-to-one source translation. Godot save file uses snake_case JSON, Unity uses camelCase JsonUtility fields. **No automatic save migration has been implemented.**

## Repository isolation
- `legioner666/Game` hosts Parasite Evolution.
- `legioner666/Game-` hosts Crown Rush and remains unchanged by this extraction.
- Historical Parasite Evolution branches in the older mixed repo are references only. Future changes and PRs belong here.

## Release policy
Only claim a successful Android build when GitHub Actions exports the APK and the artifact is present. Manual installation, FPS, crash, battery and touch tests remain open until device evidence exists. No advertisements, in-app purchases or premium services.
