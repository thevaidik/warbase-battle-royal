import RealityKit
import _RealityKit_SwiftUI
import simd

final class RealityTracerSystem {
    private let MAX = 30
    private let SPEED: Float = 85  // ~85 m/s so a 30m shot takes 0.35s — you SEE it fly
    private var pool: [ModelEntity] = []
    private var data: [(start: SIMD3<Float>, end: SIMD3<Float>, active: Bool, progress: Float, dist: Float, dir: SIMD3<Float>)] = []

    init() {
        for _ in 0..<MAX {
            var mat = UnlitMaterial(color: .init(red: 1.0, green: 0.96, blue: 0.35, alpha: 1.0))
            mat.faceCulling = .none
            // THICK streak — you can see it at 2m. Box depth = forward (Z)
            let e = ModelEntity(mesh: .generateBox(width: 0.035, height: 0.035, depth: 1), materials: [mat])
            e.isEnabled = false
            // trailing glow head
            pool.append(e)
            data.append((.zero, .zero, false, 0, 0, .zero))
        }
        // pre-warm a head sphere pool for the flying bullet tip
    }

    func spawn(start: SIMD3<Float>, end: SIMD3<Float>, content: any RealityViewContentProtocol) {
        let v = end - start
        let dist = length(v)
        guard dist > 0.01 else { return }
        let n = v / dist
        let idx = data.firstIndex(where: { !$0.active }) ?? (data.firstIndex(where: { $0.progress > 0.5 }) ?? 0)
        data[idx] = (start, end, true, 0, dist, n)
        let e = pool[idx]
        e.isEnabled = true
        let initialLen: Float = 0.6
        e.scale = [1,1,initialLen]
        // box center = start + n * len/2 so beam starts at muzzle, not behind
        e.position = start + n * (initialLen * 0.5)
        e.look(at: end, from: e.position, relativeTo: nil)
        if e.parent == nil { content.add(e) }
    }

    func update(delta: Float) {
        for i in 0..<MAX where data[i].active {
            data[i].progress += SPEED * delta
            if data[i].progress >= data[i].dist {
                data[i].active = false
                pool[i].isEnabled = false
            } else {
                let p = data[i].progress
                let tip = data[i].start + data[i].dir * p
                // streak: 0.4m long beam pointing back
                let len: Float = min(p, 0.6)
                pool[i].scale = [1, 1, len]
                // center of box is len/2 behind tip along -dir
                pool[i].position = tip - data[i].dir * (len * 0.5)
                pool[i].look(at: data[i].end, from: pool[i].position, relativeTo: nil)
            }
        }
    }
}
