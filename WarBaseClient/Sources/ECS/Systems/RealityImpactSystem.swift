import RealityKit
import _RealityKit_SwiftUI
final class RealityImpactSystem {
    func spawn(position: SIMD3<Float>, normal: SIMD3<Float>, content: any RealityViewContentProtocol) {
        let e = ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [SimpleMaterial(color: .gray, isMetallic: false)])
        e.position = position
        content.add(e)
        Task { @MainActor in try? await Task.sleep(nanoseconds: 600_000_000); e.removeFromParent() }
    }
}
