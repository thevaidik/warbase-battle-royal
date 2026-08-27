import RealityKit
import QuartzCore
import Foundation
import _RealityKit_SwiftUI

struct RemotePlayerReality {
    var mesh: RealityKit.Entity  // root (AnimatedSoldier or fallback box)
    var soldier: RealityKit.Entity?  // skeleton root if loaded
    var stateBuffer: [(time: TimeInterval, state: NetworkPlayerState)]
    var weapons: [String: ModelEntity] = [:]
    var muzzlePoints: [String: RealityKit.Entity] = [:]
    var hitboxes: [RealityKit.Entity] = []
    var currentAnim: String = ""
    var anims: [String: AnimationResource] = [:]
    var fireAnimUntil: TimeInterval = 0
    var billboard: ModelEntity?  // nameplate plane
}

final class RealityMultiplayer {
    var players: [String: RemotePlayerReality] = [:]
    private let lock = NSRecursiveLock()
    private let RENDER_DELAY: TimeInterval = 0.035

    // Web parity: 10 hitboxes — torso, head, 4 arm, 4 leg segments
    private func makeHitbox(zone: String, shape: ShapeResource, mult: Float, offset: SIMD3<Float>, parent: RealityKit.Entity, id: String) -> RealityKit.Entity {
        let e = RealityKit.Entity()
        e.name = "hitbox::\(id)::\(mult)::\(zone)"
        e.position = offset
        e.components.set(CollisionComponent(shapes: [shape], mode: .trigger, filter: .init(group: .default, mask: .all)))
        e.components.set(PhysicsBodyComponent(massProperties: .default, material: .default, mode: .kinematic))
        parent.addChild(e)
        return e
    }

    @MainActor func spawn(id: String, state: NetworkPlayerState, viewMaps: RealityViewMaps? = nil) async -> RealityKit.Entity {
        // Try to instantiate AnimatedSoldier for remote (like web assetContainer)
        let root = RealityKit.Entity()
        root.name = "player_\(id)"
        root.position = [state.x, state.y - 0.9, state.z]
        root.orientation = simd_quatf(ix: state.rx, iy: state.ry, iz: state.rz, r: state.rw)

        var soldier: RealityKit.Entity? = nil
        var anims: [String: AnimationResource] = [:]
        var hitParent: RealityKit.Entity = root

        if let url = Bundle.main.url(forResource: "AnimatedSoldier", withExtension: "usdz"),
           let loaded = try? await RealityKit.Entity.load(contentsOf: url) {
            loaded.name = "soldierBody"
            // same scale/orientation as local
            let bounds = loaded.visualBounds(relativeTo: nil)
            let h = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            let zH = bounds.extents.z
            let hh = (zH > h * 0.8) ? zH : h
            if hh > 0.01 { loaded.scale = SIMD3<Float>(repeating: 1.8 / hh) } else { loaded.scale = SIMD3<Float>(repeating: 0.9) }
            loaded.orientation = simd_quatf(angle: .pi, axis: [0,1,0]) * simd_quatf(angle: -.pi/2, axis: [1,0,0])
            loaded.position = SIMD3<Float>(0.6, 1.131, 1.693)
            // load clips for remote (reuse same 9)
            for clipName in ["Rifle_Idle","Rifle_Run","Rifle_Jump","Firing_Rifle","Firing_walk_Rifle","Strafe_Left","Strafe_Right","Walking_Backwards","Dying"] {
                if let u = Bundle.main.url(forResource: clipName, withExtension: "usdz"),
                   let clip = try? await RealityKit.Entity.load(contentsOf: u),
                   let res = clip.availableAnimations.first {
                    anims[clipName] = res
                }
            }
            if let idle = anims["Rifle_Idle"] { loaded.playAnimation(idle.repeat(), transitionDuration: 0.2) }
            root.addChild(loaded)
            soldier = loaded
            hitParent = loaded
        } else {
            // fallback box
            let box = ModelEntity(mesh: .generateBox(width: 0.5, height: 1.8, depth: 0.5), materials: [SimpleMaterial(color: .red, isMetallic: false)])
            box.name = "fallback"
            root.addChild(box)
        }

        // 10 hitboxes — bone-attached so they track animation (web: ANIMATED+trigger on Spine/Head/Arm/Leg)
        var hitboxes: [RealityKit.Entity] = []
        func bone(_ needles: [String]) -> RealityKit.Entity? {
            for n in needles {
                if let b = findBoneExact([n]) { return b }
            }
            // contains fallback
            guard let sol = soldier else { return nil }
            for n in needles {
                var q: [RealityKit.Entity] = [sol]
                while !q.isEmpty { let e = q.removeFirst(); if e.name.lowercased().contains(n.lowercased()) { return e }; q.append(contentsOf: e.children) }
            }
            return nil
        }
        let headBone = bone(["Head","mixamorig:Head"]) ?? hitParent
        let spineBone = bone(["Spine2","Spine","mixamorig:Spine2"]) ?? hitParent
        let lArm = bone(["LeftArm","mixamorig:LeftArm"]) ?? hitParent
        let rArm = bone(["RightArm","mixamorig:RightArm"]) ?? hitParent
        let lFore = bone(["LeftForeArm","LeftForearm","mixamorig:LeftForeArm"]) ?? hitParent
        let rFore = bone(["RightForeArm","mixamorig:RightForeArm"]) ?? hitParent
        let lUpLeg = bone(["LeftUpLeg","mixamorig:LeftUpLeg"]) ?? hitParent
        let rUpLeg = bone(["RightUpLeg","mixamorig:RightUpLeg"]) ?? hitParent
        let lLeg = bone(["LeftLeg","mixamorig:LeftLeg"]) ?? hitParent
        let rLeg = bone(["RightLeg","mixamorig:RightLeg"]) ?? hitParent
        // offsets are in BONE local space (small, centered), not world
        // Web exact: torso box 0.35x0.45, head cyl d0.22 h0.4, arm 0.12x0.25, fore 0.10x0.25, upLeg 0.16x0.65, calf 0.14x0.65
        hitboxes.append(makeHitbox(zone: "torso", shape: .generateBox(width: 0.35, height: 0.45, depth: 0.25), mult: 1.0, offset: [0,0.06,0], parent: spineBone, id: id))
        hitboxes.append(makeHitbox(zone: "head", shape: .generateCapsule(height: 0.40, radius: 0.11), mult: 2.5, offset: [0,0.05,0], parent: headBone, id: id))
        hitboxes.append(makeHitbox(zone: "arm", shape: .generateCapsule(height: 0.25, radius: 0.06), mult: 0.8, offset: [0,0.11,0], parent: lArm, id: id))
        hitboxes.append(makeHitbox(zone: "arm", shape: .generateCapsule(height: 0.25, radius: 0.06), mult: 0.8, offset: [0,0.11,0], parent: rArm, id: id))
        hitboxes.append(makeHitbox(zone: "arm", shape: .generateCapsule(height: 0.25, radius: 0.05), mult: 0.8, offset: [0,0.11,0], parent: lFore, id: id))
        hitboxes.append(makeHitbox(zone: "arm", shape: .generateCapsule(height: 0.25, radius: 0.05), mult: 0.8, offset: [0,0.11,0], parent: rFore, id: id))
        hitboxes.append(makeHitbox(zone: "leg", shape: .generateCapsule(height: 0.65, radius: 0.08), mult: 0.6, offset: [0,0.22,0], parent: lUpLeg, id: id))
        hitboxes.append(makeHitbox(zone: "leg", shape: .generateCapsule(height: 0.65, radius: 0.08), mult: 0.6, offset: [0,0.22,0], parent: rUpLeg, id: id))
        hitboxes.append(makeHitbox(zone: "leg", shape: .generateCapsule(height: 0.65, radius: 0.07), mult: 0.6, offset: [0,0.22,0], parent: lLeg, id: id))
        hitboxes.append(makeHitbox(zone: "leg", shape: .generateCapsule(height: 0.65, radius: 0.07), mult: 0.6, offset: [0,0.22,0], parent: rLeg, id: id))

        // Weapons: parent to RightHand bone like web (MultiplayerEntities.ts:230)
        func findBoneExact(_ names: [String]) -> RealityKit.Entity? {
            guard let sol = soldier else { return nil }
            for target in names {
                var q: [RealityKit.Entity] = [sol]
                while !q.isEmpty { let e = q.removeFirst(); if e.name == target { return e }; q.append(contentsOf: e.children) }
            }
            for target in names {
                var q: [RealityKit.Entity] = [sol]
                while !q.isEmpty { let e = q.removeFirst(); if e.name.lowercased().contains(target.lowercased()) { return e }; q.append(contentsOf: e.children) }
            }
            return nil
        }
        let rightHand = findBoneExact(["RightHand","mixamorig:RightHand","hand_r"])
        let handIsBoneRemote = (rightHand != nil)
        // holder so we don't mutate the bone joint itself
        let weaponHolder: RealityKit.Entity
        if let rh = rightHand {
            let h = RealityKit.Entity(); h.name = "remoteSway_\(id)"; h.position = SIMD3<Float>(0.06, -0.12, -0.08); rh.addChild(h); weaponHolder = h
        } else if let sol = soldier {
            let h = RealityKit.Entity(); h.name = "remoteSway_\(id)"; h.position = SIMD3<Float>(0.15, 0.20, 0.35); sol.addChild(h); weaponHolder = h
        } else {
            weaponHolder = root
        }
        var weapons: [String: ModelEntity] = [:]
        var muzzles: [String: RealityKit.Entity] = [:]
        let ak = RealityWeapons.ak47(); ak.position = .zero; ak.scale = SIMD3<Float>(repeating: handIsBoneRemote ? 0.12 : (soldier != nil ? 0.17 : 0.12)); ak.isEnabled = (state.weaponId ?? "ak47") == "ak47"
        weaponHolder.addChild(ak); weapons["ak47"]=ak; muzzles["ak47"]=RealityKit.Entity()
        let m2010 = RealityWeapons.m2010(); m2010.position = .zero; m2010.scale = SIMD3<Float>(repeating: handIsBoneRemote ? 0.12 : (soldier != nil ? 0.69 : 0.12)); m2010.isEnabled = (state.weaponId ?? "ak47") == "m2010"
        weaponHolder.addChild(m2010); weapons["m2010"]=m2010; muzzles["m2010"]=RealityKit.Entity()
        let pistol = RealityWeapons.pistol(); pistol.position = .zero; pistol.scale = SIMD3<Float>(repeating: handIsBoneRemote ? 0.12 : 0.63); pistol.isEnabled = (state.weaponId ?? "ak47") == "pistol"
        weaponHolder.addChild(pistol); weapons["pistol"]=pistol; muzzles["pistol"]=RealityKit.Entity()

        // Nameplate billboard — simple plane with unlit material (web parity: mesh.billboardMode)
        let plate = ModelEntity(mesh: .generatePlane(width: 1.2, height: 0.25), materials: [UnlitMaterial(color: .init(red: 0, green: 0, blue: 0, alpha: 0.45))])
        plate.name = "nameplate_\(id)"
        plate.position = [0, 2.15, 0]
        // billboard via look-at in interpolate()
        root.addChild(plate)

        let rp = RemotePlayerReality(mesh: root, soldier: soldier, stateBuffer: [(CACurrentMediaTime(), state)], weapons: weapons, muzzlePoints: muzzles, hitboxes: hitboxes, currentAnim: state.anim, anims: anims, billboard: plate)
        lock.lock(); players[id] = rp; lock.unlock()
        return root
    }

    func triggerFire(id: String, origin: SIMD3<Float>, hitPoint: SIMD3<Float>, normal: SIMD3<Float>, hitWall: Bool, content: any RealityViewContentProtocol, tracer: RealityTracerSystem, impact: RealityImpactSystem, decal: RealityDecalSystem) {
        guard var p = players[id] else { return }
        // 250ms fire lock like web
        p.fireAnimUntil = CACurrentMediaTime() + 0.25
        // animation sync: prefer firing variants
        let isMoving = p.stateBuffer.last?.state.anim.lowercased().contains("run") == true
        let targetAnim = isMoving ? "Firing_walk_Rifle" : "Firing_Rifle"
        if let soldier = p.soldier, let res = p.anims[targetAnim] ?? p.anims["Firing_Rifle"] {
            soldier.stopAllAnimations(); soldier.playAnimation(res.repeat(), transitionDuration: 0.1)
            p.currentAnim = targetAnim
        }
        players[id] = p
        // tracer + impact
        if length(origin - hitPoint) > 0.01 {
            tracer.spawn(start: origin, end: hitPoint, content: content)
        }
        if hitWall {
            impact.spawn(position: hitPoint, normal: normal, content: content)
            decal.spawn(position: hitPoint, normal: normal, content: content)
        }
        // muzzle flash at origin
        let flash = ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [UnlitMaterial(color: .init(red: 1, green: 0.9, blue: 0.4, alpha: 1))])
        flash.position = origin
        content.add(flash)
        let light = RealityKit.Entity(); light.components.set(PointLightComponent(color: .init(red: 1, green: 0.85, blue: 0.4, alpha: 1), intensity: 18000, attenuationRadius: 1.5)); light.position = origin
        content.add(light)
        Task { @MainActor in try? await Task.sleep(nanoseconds: 50_000_000); flash.removeFromParent(); light.removeFromParent() }
    }

    func updateNetworkState(gameState: GameStateData, localUsername: String) {
        let now = CACurrentMediaTime()
        lock.lock()
        var toSpawn: [(String, NetworkPlayerState)] = []
        for (id, state) in gameState.players where id != localUsername {
            if players[id] == nil {
                toSpawn.append((id, state))
            } else {
                // recycle tuple like web: reuse first element to reduce allocs (L1)
                var buf = players[id]!.stateBuffer
                if buf.count >= 10 {
                    var recycled = buf.removeFirst()
                    recycled.time = now; recycled.state = state
                    buf.append(recycled)
                    players[id]!.stateBuffer = buf
                } else {
                    players[id]!.stateBuffer.append((now, state))
                }
                // animation + weapon sync (like web syncAnimation)
                if var rp = players[id] {
                    // weapon
                    let wid = state.weaponId ?? "ak47"
                    for (k, w) in rp.weapons { w.isEnabled = (k == wid) }
                    // health death -> ragdoll placeholder (hide mesh, show red)
                    if state.isDead && rp.currentAnim != "Dying" {
                        rp.currentAnim = "Dying"
                        if let soldier = rp.soldier, let dying = rp.anims["Dying"] {
                            soldier.stopAllAnimations(); soldier.playAnimation(dying.repeat(), transitionDuration: 0.2)
                        }
                    } else if !state.isDead && rp.fireAnimUntil < CACurrentMediaTime() {
                        // sync anim from server, with fire lock
                        let target = state.anim.isEmpty ? "Rifle_Idle" : state.anim.replacingOccurrences(of: " ", with: "_")
                        if target != rp.currentAnim, let res = rp.anims[target] {
                            rp.soldier?.stopAllAnimations(); rp.soldier?.playAnimation(res.repeat(), transitionDuration: 0.2)
                            rp.currentAnim = target
                        }
                    }
                    players[id] = rp
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

    func interpolate(currentTime: TimeInterval, viewMaps: RealityViewMaps? = nil) {
        let renderTime = currentTime - RENDER_DELAY
        lock.lock()
        defer { lock.unlock() }
        for (id, var player) in players {
            let buf = player.stateBuffer
            guard buf.count >= 2 else { continue }
            var idx = 0
            while idx < buf.count - 1 && buf[idx+1].time < renderTime { idx += 1 }
            guard idx < buf.count - 1 else { continue }
            let s1 = buf[idx], s2 = buf[idx+1]
            let denom = s2.time - s1.time
            guard denom > 1e-6 else { continue }
            let t = Float((renderTime - s1.time) / denom)
            // platform transform if any (M1) — if scene has node with platform_id, offset there
            let p1: SIMD3<Float> = [s1.state.x, s1.state.y - 0.9, s1.state.z]
            let p2: SIMD3<Float> = [s2.state.x, s2.state.y - 0.9, s2.state.z]
            player.mesh.position = mix(p1, p2, t: max(0, min(1, t)))
            let r1 = simd_quatf(ix: s1.state.rx, iy: s1.state.ry, iz: s1.state.rz, r: s1.state.rw)
            let r2 = simd_quatf(ix: s2.state.rx, iy: s2.state.ry, iz: s2.state.rz, r: s2.state.rw)
            player.mesh.orientation = simd_slerp(r1, r2, max(0, min(1, t)))
            // billboard: keep nameplate facing the local camera (approx — uses mesh forward)
            if let plate = player.billboard, let camPos = viewMaps?.cameraEntity?.position(relativeTo: nil) {
                plate.look(at: camPos, from: plate.position(relativeTo: nil), relativeTo: nil)
            }
            players[id] = player
        }
    }
}
