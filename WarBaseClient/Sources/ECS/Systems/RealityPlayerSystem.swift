import RealityKit
import Foundation

final class RealityPlayerSystem {
    var localPlayerId: Int = -1
    private var world: World
    private var viewMaps: RealityViewMaps

    init(world: World, viewMaps: RealityViewMaps) {
        self.world = world
        self.viewMaps = viewMaps
    }

    @MainActor func initPlayer(spawnPosition: SIMD3<Float> = [0,2,0]) async -> RealityKit.Entity {
        let id = world.createEntity()
        localPlayerId = id
        let e = world.entities[id]!
        e.addComponent(Position(x: spawnPosition.x, y: spawnPosition.y, z: spawnPosition.z))
        e.addComponent(Velocity())
        e.addComponent(Rotation())
        e.addComponent(InputState())
        e.addComponent(PlayerComponentState())
        e.addComponent(WeaponState())
        e.addComponent(RecoilState())
        e.addComponent(SwayState())

        let player = RealityKit.Entity()
        player.name = "localPlayer"
        player.position = spawnPosition
        // Web parity: PhysicsAggregate CAPSULE h1.8 r0.4 mass80 friction0 — solid, not trigger
        // RealityKit touch: capsule + dynamic body with zero angular inertia
        var collision = CollisionComponent(shapes: [.generateCapsule(height: 1.75, radius: 0.32)])
        collision.mode = .default
        collision.filter = .init(group: .default, mask: .all)
        player.components.set(collision)
        var physics = PhysicsBodyComponent(massProperties: .init(mass: 80), material: .generate(friction: 0.0, restitution: 0), mode: .dynamic)
        player.components.set(physics)
        // zero spin like web inertia Vector3.Zero
        var motion0 = PhysicsMotionComponent()
        motion0.linearVelocity = .zero
        motion0.angularVelocity = .zero
        player.components.set(motion0)
        viewMaps.player = player

        if let url = Bundle.main.url(forResource: "AnimatedSoldier", withExtension: "usdz"),
           let soldier = try? await RealityKit.Entity.load(contentsOf: url) {
            soldier.name = "soldierBody"
            var bounds = soldier.visualBounds(relativeTo: nil)
            // USDZ is Z-up (upAxis="Z") — height is along Z, not Y. Use max extent.
            let height = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            // Also try Z directly for Z-up assets
            let zHeight = bounds.extents.z
            let h = (zHeight > height * 0.8) ? zHeight : height
            if h > 0.01 {
                let sc = 1.8 / h
                soldier.scale = SIMD3<Float>(repeating: sc)
                NSLog("[WB-R] soldier bounds extents=\(bounds.extents) height=\(h) scale=\(sc)")
            } else {
                soldier.scale = SIMD3<Float>(repeating: 0.9)
            }
            // In-scene skinning renders the raw Z-up skeleton frame (the loader's
            // upAxis wrapper does not affect posed skinning), so rotate the node
            // ourselves: model-up (+Z raw) -> world +Y.
            soldier.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0]) * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            // visualBounds reports the BIND pose, but the animated skeleton
            // (hips locked at raw (0.355,-1.693,-1.221)) renders 1.22m below and
            // offset from the node under rotY(pi)*rotX(-pi/2). Counter-offset so
            // the RENDERED feet land at capsule bottom (-0.9):
            //   hips_render = (-0.355, -1.221, -1.693), feet = hips - 0.81 leg
            soldier.position = SIMD3<Float>(0.6, 1.131, 1.693)
            // Bind per-action clips from external USDZs (AnimatedSoldier only
            // embeds 'Dying' — never use availableAnimations here!)
            for clipName in ["Rifle_Idle", "Rifle_Run", "Rifle_Jump", "Firing_Rifle",
                             "Firing_walk_Rifle", "Strafe_Left", "Strafe_Right",
                             "Walking_Backwards", "Dying"] {
                if let u = Bundle.main.url(forResource: clipName, withExtension: "usdz"),
                   let clip = try? await RealityKit.Entity.load(contentsOf: u),
                   let res = clip.availableAnimations.first {
                    viewMaps.soldierAnims[clipName] = res
                }
            }
            NSLog("[WB-R] clips bound: %@", viewMaps.soldierAnims.keys.sorted().joined(separator: ","))
            if let idle = viewMaps.soldierAnims["Rifle_Idle"] {
                soldier.playAnimation(idle.repeat(), transitionDuration: 0.2)
            }
            player.addChild(soldier)
            viewMaps.soldier = soldier
        } else {
            NSLog("[WB-R] soldier FAILED to load, using fallback box")
            let body = ModelEntity(mesh: .generateBox(width: 0.4, height: 1.0, depth: 0.25), materials: [SimpleMaterial(color: .green, roughness: 0.8, isMetallic: false)])
            body.position = [0, -0.4, 0]
            player.addChild(body)
        }

        let anchor = RealityKit.Entity()
        anchor.name = "cameraAnchor"
        anchor.position = [0.6, 1.5, 1.6]
        let camEntity = RealityKit.Entity()
        var cam = PerspectiveCameraComponent()
        cam.fieldOfViewInDegrees = 75
        camEntity.components.set(cam)
        anchor.addChild(camEntity)
        player.addChild(anchor)
        viewMaps.cameraAnchor = anchor
        viewMaps.cameraEntity = camEntity

        // Third-person weapon: parent to RightHand bone so bullets leave the hand (web parity: RightHand)
        if let soldier = viewMaps.soldier {
            // BFS for RightHand joint (USDZ skeleton joints are entities)
            func findBoneExact(_ names: [String]) -> RealityKit.Entity? {
                // exact matches first, then contains as fallback
                for target in names {
                    var q: [RealityKit.Entity] = [soldier]
                    while !q.isEmpty {
                        let e = q.removeFirst()
                        if e.name == target { return e }
                        q.append(contentsOf: e.children)
                    }
                }
                for target in names {
                    var q: [RealityKit.Entity] = [soldier]
                    while !q.isEmpty {
                        let e = q.removeFirst()
                        if e.name.lowercased().contains(target.lowercased()) { return e }
                        q.append(contentsOf: e.children)
                    }
                }
                return nil
            }
            let rightHand = findBoneExact(["RightHand","mixamorig:RightHand","hand_r"]) ?? soldier
            let handIsBone = (rightHand !== soldier)
            if handIsBone { NSLog("[WB-R] swayRoot parent = RightHand joint \(rightHand.name)") }
            else { NSLog("[WB-R] RightHand not found, swayRoot parent = soldier") }

            let swayRoot = RealityKit.Entity()
            swayRoot.name = "swayRoot"
            rightHand.addChild(swayRoot)
            // In hand local space, barrel forward is -Z (weapon oriented pi around Y); offset to seat grip in palm
            // Web: ak at (-0.05,0.05,0) rotation pi/2 on RightHand. RealityKit hand joint is already animated.
            let handOffset: SIMD3<Float> = handIsBone ? SIMD3<Float>(0.06, -0.12, -0.08) : SIMD3<Float>(0.15, 0.20, 0.35)
            swayRoot.position = handOffset
            let ak = RealityWeapons.ak47()
            ak.position = handIsBone ? SIMD3<Float>(0, 0, 0) : SIMD3<Float>(0.05, 0, 0)
            ak.scale = SIMD3<Float>(repeating: handIsBone ? 0.11 : 0.17)
            swayRoot.addChild(ak)
            let m2010 = RealityWeapons.m2010()
            m2010.position = handIsBone ? SIMD3<Float>(0, 0, 0) : SIMD3<Float>(0.05, 0, 0)
            m2010.scale = SIMD3<Float>(repeating: handIsBone ? 0.11 : 0.69)
            m2010.isEnabled = false
            swayRoot.addChild(m2010)
            let pistol = RealityWeapons.pistol()
            pistol.position = handIsBone ? SIMD3<Float>(0, 0, 0) : SIMD3<Float>(0.05, 0, 0)
            pistol.scale = SIMD3<Float>(repeating: handIsBone ? 0.11 : 0.63)
            pistol.isEnabled = false
            swayRoot.addChild(pistol)
            viewMaps.swayRoot = swayRoot; viewMaps.weaponAK = ak; viewMaps.weaponM2010 = m2010; viewMaps.weaponPistol = pistol
        }
        return player
    }
}
