import RealityKit
import _RealityKit_SwiftUI
final class RealityDecalSystem {
    private var pool: [ModelEntity] = []
    private var idx = 0
    init() {
        for _ in 0..<50 {
            let e = ModelEntity(mesh: .generatePlane(width: 0.2, depth: 0.2), materials: [SimpleMaterial(color: .black, isMetallic: false)])
            e.isEnabled = false; pool.append(e)
        }
    }
    func spawn(position: SIMD3<Float>, normal: SIMD3<Float>, content: any RealityViewContentProtocol) {
        let e = pool[idx]; idx = (idx+1)%pool.count
        e.isEnabled = true; e.position = position + normal*0.001
        e.look(at: position+normal, from: position, relativeTo: nil)
        if e.parent == nil { content.add(e) }
    }
}
