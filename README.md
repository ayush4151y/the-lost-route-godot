# The Lost Route (Godot)

Native 3D block-puzzle path game — a faithful reimplementation of the
original Three.js web game "The Lost Route" (AY GAME STUDIO), built in
**Godot 4.7** using only code (no binary art / audio assets; textures and
SFX are generated procedurally at runtime).

## Run locally
- Open this folder in **Godot 4.7.2** (Linux / macOS / Windows / Android).
- Press **Play**.
- Controls: Arrow keys / WASD, or tap/hold on the screen to hop one cell.
  Buttons: HINT, II (pause), ROT (rotate camera 90°), SKIP (campaign only).

## Build Android APK
Pushing to `main` triggers `.github/workflows/build-android.yml`, which:
1. Installs Godot 4.7.2 + export templates
2. Installs the Android SDK (API 34)
3. Runs `godot --headless --export-release "Android"`
4. Uploads `TheLostRoute-APK` as a downloadable artifact

Download the artifact from the Actions tab and install on your device.

## Features (matching the original)
- Seeded deterministic path generation (reproducible per level)
- Block types: grass, ice (slide timer), fire (burn budget + hearts loss),
  TNT decoy barrels (corner placement, defuse by walking back), heart (+1)
- Camera that frames the path, 90° yaw rotation
- Floating start/end islands with decor, sky, clouds, distant islands, leaves
- Modes: **Campaign (200 levels)**, **Endless**, **Daily challenge**
- Progression saved to `user://` (localStorage equivalent)
- HUD: level, hearts, fire bar, phase text, hint glow after idle
- Screens: menu, level select, settings, pause, win, game over
- Procedural audio (no binary files) with master/sfx volume buses

## Project layout
```
scripts/autoload/   save_data.gd, audio_manager.gd  (singletons)
scripts/world/      path_generator, cube_factory, block_manager,
                    camera_rig, game_env, island_builder
scripts/entities/   player.gd
scripts/ui/         ui.gd
scripts/game/       game_manager.gd  (orchestrator / state machine)
scenes/Main.tscn
```
