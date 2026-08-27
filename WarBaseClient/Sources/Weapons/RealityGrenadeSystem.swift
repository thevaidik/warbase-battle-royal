import RealityKit
import _RealityKit_SwiftUI
final class RealityGrenadeSystem {
    func throwGrenade(position: SIMD3<Float>, direction: SIMD3<Float>, content: any RealityViewContentProtocol) {
        let e = ModelEntity(mesh: .generateSphere(radius: 0.1), materials: [SimpleMaterial(color: .init(red: 0.33, green: 0.42, blue: 0.18, alpha: 1), isMetallic: false)])
        // spawn 0.7m in front so it doesn't collide with owner's capsule
        e.position = position + normalize(direction) * 0.7 + [0,0.1,0]
        // collision group 2 so it doesn't hit the thrower for first 100ms
        var filter = CollisionFilter(group: .init(rawValue: 1 << 1), mask: .all)
        e.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.1)], mode: .default, filter: filter))
        e.components.set(PhysicsBodyComponent(massProperties: .init(mass: 3), material: .generate(friction: 0.8, restitution: 0.1), mode: .dynamic))
        var motion = PhysicsMotionComponent()
        motion.linearVelocity = normalize(direction) * 8 + [0,5,0]
        e.components.set(motion)
        content.add(e)
        Task { @MainActor in try? await Task.sleep(nanoseconds: 100_000_000); filter = CollisionFilter(group: .default, mask: .all); e.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.1)], mode: .default, filter: filter)) }
        Task { @MainActor in try? await Task.sleep(nanoseconds: 3_000_000_000); e.removeFromParent() }
    }
}
