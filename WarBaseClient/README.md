# WarBaseClient (macOS / RealityKit)

Third-person shooter client. This document explains the full player pipeline and the hard-won
lessons from debugging it. Read before touching camera / soldier / map code.

## Pipeline overview

```
InputManager (NSEvent monitor, cursor-locked)
   -> InputState component (per frame)
      -> RealityPlayerMovementSystem (SceneEvents.Update)
         |- yaw/pitch -> player.orientation (yaw), camera pitch
         |- gravity + raycast grounding (feet snap)
         |- WASD accel/decel, jump + coyote time
         |- wall/step raycasts (exclude own subtree!)
         |- animation state machine (clips by key)
         -> RealityWeaponSystem (fire/sway/recoil from camera transform)
```

## Entity hierarchy

```
player (Entity, position = capsule center; feet at position.y - 0.9)
├── soldier (AnimatedSoldier.usdz)
│     orientation = rotY(π) * rotX(-π/2)      // SEE "soldier orientation"
│     position = [0, -0.9, 0]
└── cameraAnchor
      position = [0, 1.2, 4.0]                // third person: 4 m behind, 1.2 m up
      └── camEntity (PerspectiveCameraComponent, pitch applied locally)
```

The camera is a **child of player**: it follows position automatically, yaw comes from the
player's rotation, pitch is set on camEntity each frame. Never re-position the anchor per
frame and never call `look(at:from:)` here — both caused weeks-old bugs (camera inside body).

## SceneEvents.Update subscription

```swift
let sub = content.subscribe(to: SceneEvents.Update.self) { ... }
subs.append(sub)          // MUST be stored or it is deallocated and never fires
```

## Soldier orientation (the big one)

`AnimatedSoldier.usdz` (and all clip USDZs) are **Blender Z-up exports** (`upAxis = "Z"`).

1. At load, RealityKit wraps the hierarchy in a -90°X rotation from the `upAxis` metadata.
   `visualBounds` and preview see the upright pose.
2. **In a live scene with skeletal animation, skinning renders the RAW Z-up skeleton frame**
   — the wrapper is ignored. The body renders lying along +Z unless we correct it.
3. Correction (applied in `RealityPlayerSystem.initPlayer` and re-pinned every frame in
   the movement system, because clips can bake node tracks):

```swift
soldier.orientation = simd_quatf(angle: .pi, axis: [0,1,0])     // face away from camera
                  * simd_quatf(angle: -.pi/2, axis: [1,0,0])    // Z-up -> Y-up
soldier.position    = SIMD3<Float>(0.355, 1.131, 1.693)         // SEE "bind-pose lie"
```

**The bind-pose lie**: `visualBounds` reports the BIND pose, but skinning renders the
animated skeleton, whose locked hips `(0.355, -1.693, -1.221)` sit ~1.22 m below and
~1.69 m offset from the node under the rotation above. Without the counter-offset the
body renders ~2 m underground while all bounds-based diagnostics look correct. The
offset is derived from the clip data (hips → feet = 0.81 m leg) and stays valid for
every clip because all Hips tracks are locked to the same rest value.

Order matters: the Y-flip must be applied AFTER the X correction (i.e. multiply on the left).
Wrong sign of the X rotation = upside-down body (head below feet). Missing Y-flip = body
faces the camera. Bounds alone cannot detect either — verify `soldierMin.y` sits at
`groundY - 0.9 + ε` and eyeball the facing.

## Animation clips

- `AnimatedSoldier.usdz` embeds exactly ONE animation: `Dying`. Never use
  `soldier.availableAnimations` — you will play the death anim.
- Action clips live in separate USDZs (`Rifle_Idle`, `Rifle_Run`, `Rifle_Jump`,
  `Firing_Rifle`, `Firing_walk_Rifle`, `Strafe_Left`, `Strafe_Right`,
  `Walking_Backwards`, `Dying`), loaded at init into `viewMaps.soldierAnims` and played by
  name from the movement system's state machine.
- The source clips contained **absolute scene-space Hips root motion** (e.g. Rifle_Run's
  hips at z≈-8, Rifle_Jump flying to z+37) — the body drifted/teleported across the map.
  They were normalized offline (usd-core): Hips translation locked to the base skeleton's
  rest value `(0.355, -1.693, -1.221)` in every sample. Pristine originals:
  `asset_backups/raw_usdz_pre_rootmotion_fix/`.
- When editing USDs programmatically, translations are **per-joint arrays (65 entries)**.
  Writing a 1-element array per sample corrupts the skeleton (limbs stretch to infinity).

## Grounding, walls, jumps

- Ground: raycast down from `player.position + [0, 0.2, 0]`, length 2, query `.all`.
  Filter out hits on the player's own subtree (walk parents up to `player`), otherwise the
  soldier/camera shapes ground you in mid-air or block all movement.
- Grounded requires `verticalVel <= 0.1` — otherwise the jump launch frame re-grounds
  instantly and jumps never leave the floor.
- Walls: horizontal ray at chest height; zero velocity on hit. Same subtree filter.
- Spawn: multi-probe downward raycast; take the **lowest** hit (highest hits are rooftops).

## Map collision (the other big one)

`industrial.usdz` is one merged mesh. `generateCollisionShapes(recursive: true)` and any
box/convex approach degenerate to the mesh's **bounding box** — players walk on an invisible
"ceiling" ~20 m above the real ground and the whole map feels like flying.

Fix: triangle-accurate static collision:

```swift
if let shape = try? await ShapeResource.generateStaticMesh(from: model.mesh) {
    e.components.set(CollisionComponent(shapes: [shape]))
}
```

Raycasts then hit real terrain (probes report ground y≈0.84 with multiple layered hits).

## Spawn (matches web client behavior)

Web (`client/src/engine/Environment.ts`): spawn above first decent mesh bbox, min +5 m,
gravity drops the player. Here: 13 downward probes from y=60, pick lowest surface, spawn
1 m above it; safety-net floor lives `map.visualBounds.min.y - 2`.

## Diagnostics

Per-second log in `RealityGameView.tick`:
`player= cam= grounded= yaw= soldierExtents= soldierMin=`
Plus `--autodeploy` CLI flag (auto-presses W for 2 s) for headless-style testing with
`./WarBaseClient --autodeploy` and reading Console output.

Sanity values: upright soldier extents ≈ (1.77, 1.80, 0.39); soldierMin.y ≈ groundY - 0.9;
cam ≈ player + (0, 1.2, 4.0) rotated by yaw.

## Known issues / next steps

- FPS weapon viewmodel (`swayRoot`) is parented to the camera anchor — floats oddly in
  third person; should attach to the soldier's right hand.
- Remote players (`RealityMultiplayer`) not yet verified against this pipeline.
- `Entity.swift` ECS `Position/Velocity/Rotation` components are written but unused.
- Pelvis root motion is locked for stability; re-enable only Y-delta if you want bob.
