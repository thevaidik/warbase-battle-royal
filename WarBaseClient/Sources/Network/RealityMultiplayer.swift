import RealityKit
import Foundation

struct RemotePlayerReality {
    var mesh: ModelEntity
    var stateBuffer: [(time: TimeInterval, state: NetworkPlayerState)]
    var weapons: [String: ModelEntity] = [:]
    var hitboxes: [RealityKit.Entity] = []
    var currentAnim: String = ""
}

final class RealityMultiplayer {
    var players: [String: RemotePlayerReality] = [:]
    private let lock = NSRecursiveLock()
    private let RENDER_DELAY: TimeInterval = 0.035

    func spawn(id: String, state: NetworkPlayerState) -> ModelEntity {
        let mesh = ModelEntity(mesh: .generateBox(width: 0.5, height: 1.8, depth: 0.5), materials: [SimpleMaterial(color: .red, isMetallic: false)])
        mesh.name = "player_\(id)"
        mesh.position = [state.x, state.y - 0.9, state.z]
        mesh.orientation = simd_quatf(ix: state.rx, iy: state.ry, iz: state.rz, r: state.rw)
        func makeHitbox(zone: String, shape: ShapeResource, mult: Float, offset: SIMD3<Float>) -> RealityKit.Entity {
            let e = RealityKit.Entity()
            e.name = "hitbox::\(id)::\(mult)::\(zone)"
            e.position = offset
            e.components.set(CollisionComponent(shapes: [shape], mode: .trigger, filter: .init(group: .default, mask: .all)))
            e.components.set(PhysicsBodyComponent(massProperties: .default, material: .default, mode: .kinematic))
            mesh.addChild(e)
            return e
        }
        let head = makeHitbox(zone: "head", shape: .generateCapsule(height: 0.4, radius: 0.11), mult: 2.5, offset: [0,1.7,0])
        let torso = makeHitbox(zone: "torso", shape: .generateBox(width: 0.4, height: 0.6, depth: 0.25), mult: 1.0, offset: [0,1.2,0])
        let ak = RealityWeapons.ak47()
        ak.position = [0.2, 0.9, 0.3]
        ak.isEnabled = (state.weaponId ?? "ak47") == "ak47"
        mesh.addChild(ak)
        let m2010 = RealityWeapons.m2010()
        m2010.position = [0.2, 0.9, 0.3]
        m2010.isEnabled = (state.weaponId ?? "ak47") == "m2010"
        mesh.addChild(m2010)
        let rp = RemotePlayerReality(mesh: mesh, stateBuffer: [(Date().timeIntervalSince1970, state)], weapons: ["ak47": ak, "m2010": m2010], hitboxes: [head, torso], currentAnim: state.anim)
        lock.lock()
        players[id] = rp
        lock.unlock()
        return mesh
    }

    func updateNetworkState(gameState: GameStateData, localUsername: String) {
        let now = Date().timeIntervalSince1970
        lock.lock()
        var toSpawn: [(String, NetworkPlayerState)] = []
        for (id, state) in gameState.players where id != localUsername {
            if players[id] == nil {
                toSpawn.append((id, state))
            } else {
                players[id]?.stateBuffer.append((now, state))
                if players[id]!.stateBuffer.count > 10 {
                    players[id]!.stateBuffer.removeFirst(players[id]!.stateBuffer.count - 10)
                }
            }
        }
        var toRemove: [String] = []
        for id in players.keys where gameState.players[id] == nil { toRemove.append(id) }
        lock.unlock()
        for id in toRemove {
            lock.lock()
            let p = players.removeValue(forKey: id)
            lock.unlock()
            p?.mesh.removeFromParent()
        }
    }

    func interpolate(currentTime: TimeInterval) {
        let renderTime = Date().timeIntervalSince1970 - RENDER_DELAY
        lock.lock()
        defer { lock.unlock() }
        for (_, var player) in players {
            let buf = player.stateBuffer
            guard buf.count >= 2 else { continue }
            var idx = 0
            while idx < buf.count - 1 && buf[idx+1].time < renderTime { idx += 1 }
            guard idx < buf.count - 1 else { continue }
            let s1 = buf[idx], s2 = buf[idx+1]
            let t = Float((renderTime - s1.time) / (s2.time - s1.time))
            let p1: SIMD3<Float> = [s1.state.x, s1.state.y - 0.9, s1.state.z]
            let p2: SIMD3<Float> = [s2.state.x, s2.state.y - 0.9, s2.state.z]
            player.mesh.position = mix(p1, p2, t: t)
            let r1 = simd_quatf(ix: s1.state.rx, iy: s1.state.ry, iz: s1.state.rz, r: s1.state.rw)
            let r2 = simd_quatf(ix: s2.state.rx, iy: s2.state.ry, iz: s2.state.rz, r: s2.state.rw)
            player.mesh.orientation = simd_slerp(r1, r2, t)
            players[player.mesh.name.replacingOccurrences(of: "player_", with: "")] = player
        }
    }
}
