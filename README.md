# Sendokai 3D Offline Football Cup

An original, unofficial anime-inspired 3D football prototype. It is offline single-player only: you control the blue team against computer-controlled red-team opponents. No LAN, Wi-Fi matchmaking, or online multiplayer is included.

## Current gameplay prototype
- 3D football pitch with markings, simple stands, goals, and a follow camera.
- 11 players per side using lightweight procedural placeholder models.
- Computer-controlled teammates and opponents that move around the pitch.
- Touchscreen controls for movement, short pass, long pass, shot, tackle, player switch, and a special shot.
- Scoreboard, match timer, and a small tactical minimap.
- Offline cup progression across multiple matches.
- Android ARM64 export preset and GitHub Actions APK workflow.

## Important prototype limitations
This is an early gameplay prototype, not a finished Captain Tsubasa ACE-scale game. Player animation, goalkeeper logic, robust formations/tactics, polished joystick input, advanced skill cutscenes, sound, menus, and extensive testing still need development. Placeholder models and simple AI are used to keep the first version lightweight for Android.

## Build the Android APK
1. Open **Actions** in this repository.
2. Run **Build Sendokai Offline Cup APK**, or push a commit to `main`.
3. Download the `Sendokai3DOfflineCup-Android-APK` artifact from a successful workflow run.

## Device target
Designed for a low-end Android phone with the Godot Compatibility renderer and ARM64 export. Performance and gameplay must still be tested on the actual device.

## Legal note
This is an unofficial fan prototype inspired by anime football games. It is not affiliated with or endorsed by the owners of Captain Tsubasa or Sendokai Champions. It does not include official character models, logos, music, or other protected game assets.
