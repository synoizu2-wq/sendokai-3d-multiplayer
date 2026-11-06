# Sendokai 3D Offline Cup

An original, unofficial fan-made 3D energy-ball tournament prototype. The game is **offline single-player only**: one human player competes against computer-controlled opponents. It contains no LAN, Wi-Fi matchmaking, online play, or multiplayer networking code.

## Current prototype
- Lightweight 3D arena using Godot 4.4 and the Compatibility renderer.
- Offline tournament progression: semifinal, then grand final if you win.
- Computer-controlled opponent that moves toward and shoots the energy ball.
- Touch controls for movement and energy-ball shooting.
- First-to-three scoring in each match.
- Android ARM64 export preset and GitHub Actions APK workflow.
- Procedural placeholder fighters and arena geometry; no official cartoon artwork or character models.

## Build the Android APK
1. Open **Actions** in this repository.
2. Run **Build Sendokai Offline Cup APK**, or push a commit to `main`.
3. Download the `Sendokai3DOfflineCup-Android-APK` artifact from the completed workflow run.

The workflow uses a Godot CI container. No local Godot installation is needed for the GitHub build.

## Device target
Designed for a low-end Android phone with the Godot Compatibility renderer and ARM64 export. Performance and gameplay still need to be tested on the actual device.

## Legal note
This is an unofficial fan prototype and is not affiliated with or endorsed by the owners of Sendokai Champions. Use original or properly licensed assets when expanding it.
