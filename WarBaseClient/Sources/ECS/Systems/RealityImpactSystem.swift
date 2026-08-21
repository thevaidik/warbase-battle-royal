import RealityKit
import _RealityKit_SwiftUI

final class RealityImpactSystem {
    func spawn(position: SIMD3<Float>, normal: SIMD3<Float>, content: any RealityViewContentProtocol) {
        // --- RealityKit magic: impact flash sphere + point light + tiny spark burst ---
        let flash = ModelEntity(mesh: .generateSphere(radius: 0.06), materials: [UnlitMaterial(color: .init(red: 1.0, green: 0.75, blue: 0.2, alpha: 1.0))])
        flash.position = position + normal * 0.02
        // orient flat to surface
        flash.look(at: position + normal, from: position + normal * 0.02, relativeTo: nil)
        // scale burst
        flash.scale = [0.4, 0.4, 0.4]
        content.add(flash)
        // bright point light flash
        let light = RealityKit.Entity()
        light.components.set(PointLightComponent(color: .init(red: 1, green: 0.85, blue: 0.4, alpha: 1), intensity: 18000, attenuationRadius: 2.5))
        light.position = position + normal * 0.05
        content.add(light)
        // tiny spark debris
        for i in 0..<4 {
            let spark = RealityKit.ModelEntity(mesh: .generateSphere(radius: 0.012), materials: [UnlitMaterial(color: .init(red: 1, green: 0.5, blue: 0.1, alpha: 1))])
            spark.position = position + normal * 0.02 + SIMD3<Float>(Float.random(in: -0.04...0.04), Float.random(in: 0...0.06), Float.random(in: -0.04...0.04))
            content.add(spark)
            Task { @MainActor in try? await Task.sleep(nanoseconds: 250_000_000); spark.removeFromParent() }
        }
        Task { @MainActor in
            // quick scale-up then fade
            try? await Task.sleep(nanoseconds: 80_000_000)
            flash.scale = [1.2, 1.2, 1.2]
            try? await Task.sleep(nanoseconds: 120_000_000)
            flash.removeFromParent()
            light.removeFromParent()
        }
    }
}
