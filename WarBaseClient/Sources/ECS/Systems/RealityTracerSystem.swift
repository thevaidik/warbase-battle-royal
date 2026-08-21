import RealityKit
import _RealityKit_SwiftUI
import simd

final class RealityTracerSystem {
    private let MAX = 30
    private let SPEED: Float = 300
    private var pool: [ModelEntity] = []
    private var data: [(start: SIMD3<Float>, end: SIMD3<Float>, active: Bool, progress: Float, dist: Float, dir: SIMD3<Float>)] = []

    init() {
        for _ in 0..<MAX {
            var mat = UnlitMaterial(color: .init(red: 1.0, green: 0.92, blue: 0.35, alpha: 1.0))
            let e = ModelEntity(mesh: .generateCylinder(height: 1, radius: 0.012), materials: [mat])
            e.isEnabled = false
            // Additive glow via emissive light on tracer head
            pool.append(e)
            data.append((.zero, .zero, false, 0, 0, .zero))
        }
    }

    func addTo(_ content: any RealityViewContentProtocol, _ index: Int) {
        content.add(pool[index])
    }

    func spawn(start: SIMD3<Float>, end: SIMD3<Float>, content: any RealityViewContentProtocol) {
        let dir = end - start
        let dist = length(dir)
        guard dist > 0.001 else { return }
        let n = normalize(dir)
        let idx = data.firstIndex(where: { !$0.active }) ?? 0
        data[idx] = (start, end, true, 0, dist, n)
        let e = pool[idx]
        e.isEnabled = true
        e.position = start
        e.look(at: end, from: start, relativeTo: nil)
        if pool[idx].parent == nil { content.add(e) }
    }

    func update(delta: Float) {
        for i in 0..<MAX where data[i].active {
            data[i].progress += SPEED * delta
            if data[i].progress >= data[i].dist {
                data[i].active = false
                pool[i].isEnabled = false
            } else {
                let p = data[i].progress
                pool[i].position = data[i].start + data[i].dir * p
                let len = min(p, 3)
                pool[i].scale = [1, len, 1]
            }
        }
    }
}
