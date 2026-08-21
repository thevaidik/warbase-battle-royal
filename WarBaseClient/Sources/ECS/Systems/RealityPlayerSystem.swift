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
            soldier.position = [0, -0.9, 0]
            let idleAnim = soldier.availableAnimations.first(where: { ($0.name ?? "").lowercased().contains("idle") }) ?? soldier.availableAnimations.first
            if let anim = idleAnim {
                soldier.playAnimation(anim.repeat(), transitionDuration: 0.2)
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
        anchor.position = [0, 0.6, 0]
        let camEntity = RealityKit.Entity()
        var cam = PerspectiveCameraComponent()
        cam.fieldOfViewInDegrees = 75
        camEntity.components.set(cam)
        anchor.addChild(camEntity)
        player.addChild(anchor)
        viewMaps.cameraAnchor = anchor
        viewMaps.cameraEntity = camEntity

        // FPS weapon viewmodel: swayRoot (camera child) + 3 weapons, scale 0.08 (web initWeapons)
        let swayRoot = RealityKit.Entity()
        swayRoot.name = "swayRoot"
        anchor.addChild(swayRoot)
        let ak = RealityWeapons.ak47()
        ak.position = [0.08, -0.12, -0.38]
        swayRoot.addChild(ak)
        let m2010 = RealityWeapons.m2010()
        m2010.position = [0.08, -0.12, -0.38]
        m2010.isEnabled = false
        swayRoot.addChild(m2010)
        let pistol = RealityWeapons.pistol()
        pistol.position = [0.08, -0.12, -0.38]
        pistol.isEnabled = false
        swayRoot.addChild(pistol)
        viewMaps.swayRoot = swayRoot; viewMaps.weaponAK = ak; viewMaps.weaponM2010 = m2010; viewMaps.weaponPistol = pistol
        return player
    }
}
