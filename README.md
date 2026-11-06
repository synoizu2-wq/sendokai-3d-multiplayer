# Sendokai 3D Multiplayer Prototype

An original, unofficial fan-made prototype inspired by the energy-ball sport concept of Sendokai. It uses procedural placeholder characters and arena geometry; no official cartoon artwork, logos, music, or character models are included.

## Prototype features
- Lightweight 3D arena using Godot 4 and the Compatibility renderer.
- Two-player 1v1 match over a local Wi-Fi network using ENet.
- Touch controls for movement and energy-ball shooting.
- Basic score display and first-to-three scoring.
- Android ARM64 export preset and GitHub Actions APK workflow.

## Build the Android APK
1. Put the project files in a GitHub repository.
2. Open **Actions** and run **Build Sendokai Android APK**, or push a commit to `main`.
3. Download the `Sendokai3DPrototype-Android-APK` artifact from the completed workflow run.

The workflow uses the Godot CI container to export the APK. No local Godot installation is needed for the GitHub build.

## Multiplayer
This first prototype uses ENet on UDP port `24567`. Both devices must be on the same Wi-Fi network. One player taps **HOST** and shares the host device's local IP; the other enters that IP and taps **JOIN**. Internet matchmaking and relay hosting are not included yet.

## Device target
Designed for a low-end Android phone with the Godot Compatibility renderer and ARM64 export. Performance still needs to be measured on the actual device.

## Legal note
This is an unofficial fan prototype and is not affiliated with or endorsed by the owners of Sendokai Champions. Use original or properly licensed assets when expanding it.
