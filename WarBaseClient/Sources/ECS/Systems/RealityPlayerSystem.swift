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
        var collision = CollisionComponent(shapes: [.generateBox(width: 0.5, height: 1.8, depth: 0.5)])
        collision.mode = .trigger
        player.components.set(collision)
        var physics = PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.5, restitution: 0), mode: .kinematic)
        player.components.set(physics)
        viewMaps.player = player

        if let url = Bundle.main.url(forResource: "AnimatedSoldier", withExtension: "usdz"),
           let soldier = try? await RealityKit.Entity.load(contentsOf: url) {
            soldier.name = "soldierBody"
            let bounds = soldier.visualBounds(relativeTo: nil)
            let height = bounds.extents.y
            if height > 0.01 {
                let s = 1.8 / height
                soldier.scale = SIMD3<Float>(repeating: s)
                NSLog("[WB-R] soldier loaded height=\(height) scale=\(s)")
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
            soldier.position = SIMD3<Float>(0.355, 1.131, 1.693)
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
        anchor.position = [0, 1.5, 1.7]
        let camEntity = RealityKit.Entity()
        var cam = PerspectiveCameraComponent()
        cam.fieldOfViewInDegrees = 75
        camEntity.components.set(cam)
        anchor.addChild(camEntity)
        player.addChild(anchor)
        viewMaps.cameraAnchor = anchor
        viewMaps.cameraEntity = camEntity

        // Third-person weapon: parented to the SOLDIER so it hangs at the body
        // (right-hand/chest area) instead of floating in front of the camera.
        if let soldier = viewMaps.soldier {
            let swayRoot = RealityKit.Entity()
            swayRoot.name = "swayRoot"
            soldier.addChild(swayRoot)
            let ak = RealityWeapons.ak47()
            // Soldier local space: rendered body is offset by (0.355,1.131,1.693);
            // hands sit ~1.3m above feet and ~0.3m right of body center.
            ak.position = [0.05, 1.35, 1.45]
            ak.scale = SIMD3<Float>(repeating: 0.17)
            swayRoot.addChild(ak)
            let m2010 = RealityWeapons.m2010()
            m2010.position = [0.05, 1.35, 1.45]
            m2010.scale = SIMD3<Float>(repeating: 0.69)
            m2010.isEnabled = false
            swayRoot.addChild(m2010)
            let pistol = RealityWeapons.pistol()
            pistol.position = [0.05, 1.35, 1.45]
            pistol.scale = SIMD3<Float>(repeating: 0.63)
            pistol.isEnabled = false
            swayRoot.addChild(pistol)
            viewMaps.swayRoot = swayRoot; viewMaps.weaponAK = ak; viewMaps.weaponM2010 = m2010; viewMaps.weaponPistol = pistol
        }
        return player
    }
}
