# Automated Simulator Testing Methodology

Since AI agents cannot physically interact with the iOS Simulator window (tapping buttons, swiping the joystick), we use a programmatic injection and command-line automation approach to verify that the game engine works.

## 1. Input Simulation
To verify that the ECS (Entity Component System) correctly processes movement, collision, and weapon states, we temporarily hardcode inputs directly into the logic loop before compiling.

In `PlayerMovementSystem.swift`, we inject:
```swift
// SIMULATED TEST INPUT:
input.forward = true
input.fire = true
playerState.yaw -= 0.05
```
This forces the game to treat the player as constantly pressing the forward joystick, holding the fire button, and swiping the screen to look around.

## 2. Headless Launch & Verification Pipeline
Instead of relying on the Xcode UI, we use Apple's `simctl` command-line tools to compile, install, and execute the app entirely in the background.

The full pipeline executed by the agent is:
1. **Build**: `xcodebuild -project WarBaseClient.xcodeproj -scheme WarBaseClient -sdk iphonesimulator -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>'`
2. **Install**: `xcrun simctl install <SIMULATOR_ID> WarBaseClient.app`
3. **Launch**: `xcrun simctl launch <SIMULATOR_ID> com.warbase.WarBaseClient`
4. **Wait**: Sleep for ~5 seconds to allow the USDZ maps to load into memory and the player to fall from their spawn point to the floor.
5. **Capture**: `xcrun simctl io <SIMULATOR_ID> screenshot screenshot.png`

By examining the resulting screenshot, we can visually confirm:
* The 3D map rendered with correct PBR/Blinn materials and lighting.
* The player's position changed (proving physics and movement work).
* The ammo counter drained to 0 (proving the firing loop works).
