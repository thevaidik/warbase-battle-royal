import RealityKit
import _RealityKit_SwiftUI
final class RealityGrenadeSystem {
    func throwGrenade(position: SIMD3<Float>, direction: SIMD3<Float>, content: any RealityViewContentProtocol) {
        let e = ModelEntity(mesh: .generateSphere(radius: 0.1), materials: [SimpleMaterial(color: .init(red: 0.33, green: 0.42, blue: 0.18, alpha: 1), isMetallic: false)])
        e.position = position
        e.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.1)]))
        e.components.set(PhysicsBodyComponent(massProperties: .init(mass: 3), material: .generate(friction: 0.8, restitution: 0.1), mode: .dynamic))
        var motion = PhysicsMotionComponent()
        motion.linearVelocity = direction * 25 + [0,5,0]
        e.components.set(motion)
        content.add(e)
        Task { @MainActor in try? await Task.sleep(nanoseconds: 3_000_000_000); e.removeFromParent() }
    }
}
