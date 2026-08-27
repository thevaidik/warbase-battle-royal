import RealityKit
import Foundation
import _RealityKit_SwiftUI

final class RealityWeaponSystem {
    private var lastFire: TimeInterval = 0
    private var isReloading = false
    private var reloadTimer: TimeInterval = 0
    private var spread: Float = 0
    private var recoilX: Float = 0, recoilY: Float = 0, velX: Float = 0, velY: Float = 0
    private var canFireSemi = true

    func update(input: InputState, entity: WarBaseClient.Entity, weaponState: inout WeaponState, recoilState: inout RecoilState, swayState: inout SwayState, time: TimeInterval, dt: Float, swayRoot: RealityKit.Entity, camera: RealityKit.Entity, scene: RealityKit.Scene, tracer: RealityTracerSystem, impact: RealityImpactSystem, decal: RealityDecalSystem, network: NetworkManager?, content: Any, isAssault: Bool, muzzlePos: SIMD3<Float>? = nil) {
        let isPistol = weaponState.activeWeaponIndex == 1
        let rate: Double = isPistol ? 400 : (isAssault ? 600 : 45)
        let interval = 60/rate
        let magSize = isPistol ? 12 : (isAssault ? 30 : 5)
        let cfg: WeaponConfig = {
            if isPistol { return WEAPON_CONFIGS["Pistol"]! }
            return isAssault ? WEAPON_CONFIGS["AK-47"]! : WEAPON_CONFIGS["M2010"]!
        }()
        let isMoving = input.forward || input.backward || input.left || input.right

        #if true
        // Weapon switch (1 = primary, 2 = pistol)
        if input.weapon1 && !isReloading { weaponState.activeWeaponIndex = 0 }
        else if input.weapon2 && !isReloading { weaponState.activeWeaponIndex = 1 }
        #endif

        if !input.fire { canFireSemi = true }

        // ADS: smooth 0→1 / 1→0 transition
        let adsTarget: Float = input.ads ? 1.0 : 0.0
        let adsSpeed: Float = input.ads ? cfg.adsTime : (cfg.adsTime * 1.5)
        weaponState.adsProgress += (adsTarget - weaponState.adsProgress) * min(1, Float(dt) / max(adsSpeed, 0.01))

        // Dead cannot shoot (web ValidateAndApplyFire IsDead)
        if let ps = entity.getComponent(PlayerComponentState.self), ps.isDead { return }
        let adsMult: Float = weaponState.adsProgress > 0.5 ? (isAssault ? 0.7 : 0.3) : 1.0
        if input.fire, !isReloading, weaponState.currentAmmo > 0, time - lastFire >= interval, (isAssault || canFireSemi) {
            lastFire = time
            canFireSemi = false
            weaponState.currentAmmo -= 1
            velY += cfg.recoilVertical * adsMult * 20
            velX += Float.random(in: -1...1) * cfg.recoilHorizontal * adsMult * 20
            spread = min(spread + cfg.bloomPerShot * (1.0 - weaponState.adsProgress * (1.0 - cfg.adsSpreadMult)), cfg.maxSpread)
            recoilState.kickbackZ = weaponState.adsProgress > 0.5 ? -0.02 : -0.05
            recoilState.kickbackRotX = weaponState.adsProgress > 0.5 ? -0.02 : -0.08

            // --- RealityKit-native firing pipeline ---
            // 1) Eye ray: start from camera, build orthonormal basis around camDir (no roll).
            let camPos = camera.position(relativeTo: nil)
            let camWorldQ = camera.orientation(relativeTo: nil)
            let camDir = normalize(-camWorldQ.act(SIMD3<Float>(0,0,1)))
            // orthonormal basis perpendicular to camDir
            let worldUp: SIMD3<Float> = [0,1,0]
            var camRight = normalize(cross(camDir, worldUp))
            if length(camRight) < 0.1 { camRight = camWorldQ.act(SIMD3<Float>(1,0,0)) }
            camRight = normalize(camRight)
            let camUp = normalize(cross(camRight, camDir))
            let spreadRad = spread * .pi / 180 * (weaponState.adsProgress > 0.5 ? (isAssault ? 0.4 : 0.05) : 1)
            let rot = Float.random(in: 0...2 * .pi)
            // uniform disc
            let r = sqrt(Float.random(in: 0...1)) * sin(spreadRad)
            let coneOff = camRight * (cos(rot) * r) + camUp * (sin(rot) * r)
            let dir = normalize(camDir + coneOff)
            let eyeEnd = camPos + dir * 600
            let hits = scene.raycast(from: camPos, to: eyeEnd, query: .all, mask: .all)
            var hitWall = false
            var hitPos = eyeEnd, hitNorm = SIMD3<Float>(0,1,0)
            var hitEntity: RealityKit.Entity? = nil
            // Firm H5: exclude own player+soldier subtree (was hitting own trigger capsule at 0.35m)
            func isInPlayerSubtree(_ e: RealityKit.Entity) -> Bool {
                var cur: RealityKit.Entity? = e
                while let c = cur {
                    if c.name == "localPlayer" || c.name == "soldierBody" || c.name == "swayRoot" { return true }
                    cur = c.parent
                }
                return false
            }
            if let hit = hits.first(where: { $0.entity !== camera && $0.entity.parent !== camera && !isInPlayerSubtree($0.entity) }) {
                hitPos = hit.position; hitNorm = hit.normal; hitEntity = hit.entity
                if let name = hit.entity.name as String?, name.hasPrefix("hitbox::") {
                    let parts = name.components(separatedBy: "::")
                    if parts.count >= 3 {
                        let dmg: Float = cfg.damage
                        let mult = Float(parts[2]) ?? 1
                        network?.sendHit(targetId: parts[1], damage: dmg * mult, hitZone: parts.count>3 ? parts[3] : "torso")
                    }
                }
            }
            // Decide hitWall: only if we actually hit geometry (not sky) and not a hitbox
            if let e = hitEntity {
                if let n = e.name as String?, n.hasPrefix("hitbox::") {
                    hitWall = false
                } else if length(hitPos - camPos) < 590 {
                    hitWall = true
                }
            }
            if hitWall, let contentAny = content as? any _RealityKit_SwiftUI.RealityViewContentProtocol {
                decal.spawn(position: hitPos, normal: hitNorm, content: contentAny)
                impact.spawn(position: hitPos, normal: hitNorm, content: contentAny)
            }
            // 2) Visuals: tracer from MUZZLE to hitPos (parallax-correct), flash at muzzle
            // muzzlePos is already world-space from coordinator via convert(); validate it
            // Fallback to hand/body (never camera)
            let start = muzzlePos ?? (swayRoot.position(relativeTo: nil) + dir * 0.35)
            // one-shot log to catch sky fallback
            if muzzlePos == nil { NSLog("[WB-R] FIRE fallback swayRoot=%@ cam=%@ start=%@", "\(swayRoot.position(relativeTo: nil))", "\(camPos)", "\(start)") }
            if let contentAny = content as? any _RealityKit_SwiftUI.RealityViewContentProtocol {
                // Don't draw 600m streak into sky — clamp sky shots to 300m from MUZZLE, not camera
                let visualEnd: SIMD3<Float> = hitWall ? hitPos : (start + dir * 300)
                // For muzzle visuals use the clamped end so beam doesn't fly to sky
                tracer.spawn(start: start, end: visualEnd, content: contentAny)
                spawnMuzzleFlash(at: start, dir: dir, content: contentAny)
            }
            network?.sendFire(origin: start, hit: hitPos, normal: hitNorm, hitWall: hitWall)
        }

        if (input.reload || (input.fire && weaponState.currentAmmo==0)) && !isReloading && weaponState.currentAmmo < magSize {
            isReloading = true; reloadTimer = time
            network?.sendReload()
        }
        if isReloading && time - reloadTimer >= Double(cfg.reloadTime) {
            isReloading = false; weaponState.currentAmmo = magSize
        }

        if spread > cfg.baseSpread {
            spread = cfg.baseSpread + (spread - cfg.baseSpread) * Float(exp(-Double(cfg.bloomRecovery)*Double(dt)))
        }

        let isReloadingFlag = isReloading
        if isMoving && !isReloadingFlag {
            swayState.walkBobTimer += dt * (input.sprint ? 15 : 10)
        } else { swayState.walkBobTimer = 0 }
        let swayX = -input.mouseDeltaX * 0.001 + velX * 0.1
        let swayY = -input.mouseDeltaY * 0.001 + velY * 0.1
        swayState.swayX = swayState.swayX + (swayX - swayState.swayX) * min(1, 10*dt)
        swayState.swayY = swayState.swayY + (swayY - swayState.swayY) * min(1, 10*dt)
        var bobX: Float = 0, bobY: Float = 0
        if isMoving && !isReloadingFlag {
            let amp: Float = input.sprint ? 0.012 : 0.01
            bobX = sin(swayState.walkBobTimer) * amp
            bobY = abs(cos(swayState.walkBobTimer)) * amp
        } else {
            bobY = sin(Float(time) * 1.5) * 0.003
        }
        let adsSway: Float = 1.0 - weaponState.adsProgress * 0.8
        swayRoot.orientation = simd_quatf(angle: swayState.swayX * adsSway, axis: [0,1,0])
        // combine with recoil kick
        var swayOrient = swayRoot.orientation
        let kickQ = simd_quatf(angle: recoilState.kickbackRotX, axis: [1,0,0])
        swayRoot.orientation = swayOrient * kickQ
        // Base = hand offset when swayRoot is on RightHand bone, else chest fallback
        let base: SIMD3<Float> = {
            if let parentName = swayRoot.parent?.name.lowercased(), parentName.contains("hand") {
                return SIMD3<Float>(0.06, -0.12, -0.08)
            }
            return SIMD3<Float>(0.15, 0.20, 0.35)
        }()
        swayRoot.position = base + SIMD3<Float>(bobX * adsSway, bobY * adsSway, recoilState.kickbackZ)
        recoilState.kickbackZ += (0 - recoilState.kickbackZ) * min(1, 15*dt)
        recoilState.kickbackRotX += (0 - recoilState.kickbackRotX) * min(1, 15*dt)

        velX += (-150*recoilX - 15*velX)*dt
        velY += (-150*recoilY - 15*velY)*dt
        recoilX += velX*dt; recoilY += velY*dt
        // Firm H1: toggle visible mesh to match activeWeaponIndex (was never wired)
        if let ak = swayRoot.children.first(where: { $0.name == "ak47" }) as? ModelEntity { ak.isEnabled = (weaponState.activeWeaponIndex == 0 && isAssault) }
        if let m2010 = swayRoot.children.first(where: { $0.name == "m2010" }) as? ModelEntity { m2010.isEnabled = (weaponState.activeWeaponIndex == 0 && !isAssault) }
        if let pistol = swayRoot.children.first(where: { $0.name == "pistol" }) as? ModelEntity { pistol.isEnabled = (weaponState.activeWeaponIndex == 1) }

        // TPS: NEVER touch pState.yaw/pitch — those drive the camera + player facing.
        // Visual recoil lives entirely in swayRoot kick + soldier body lean.
        // Lean the SOLDIER torso, not the hand joint (swayRoot.parent is RightHand since hand-fix).
        do {
            // walk up to soldierBody (or fallback to swayRoot parent chain)
            var cur: RealityKit.Entity? = swayRoot
            var soldierNode: RealityKit.Entity? = nil
            while let c = cur {
                if c.name == "soldierBody" { soldierNode = c; break }
                cur = c.parent
            }
            // fallback: direct parent chain search up to 6 levels
            if soldierNode == nil {
                cur = swayRoot.parent
                for _ in 0..<6 { if cur?.name == "soldierBody" { soldierNode = cur; break }; cur = cur?.parent }
            }
            if let body = soldierNode {
                let lean: Float = recoilY * 0.85 * 2.0
                body.orientation = simd_quatf(angle: .pi, axis: [0,1,0]) * simd_quatf(angle: -.pi/2 + lean, axis: [1,0,0])
            }
        }
    }

    private func spawnMuzzleFlash(at pos: SIMD3<Float>, dir: SIMD3<Float>, content: any _RealityKit_SwiftUI.RealityViewContentProtocol) {
        // RealityKit-native: emissive cone + point light + short smoke puff
        let cone = RealityKit.ModelEntity(mesh: .generateCone(height: 0.18, radius: 0.06), materials: [RealityKit.UnlitMaterial(color: .init(red: 1, green: 0.92, blue: 0.45, alpha: 1))])
        cone.position = pos + dir * 0.09
        // cone points +Y by default, rotate Y->dir
        cone.look(at: pos + dir, from: cone.position, relativeTo: nil)
        content.add(cone)
        let flash = RealityKit.ModelEntity(mesh: .generateSphere(radius: 0.055), materials: [RealityKit.UnlitMaterial(color: .init(red: 1, green: 0.9, blue: 0.4, alpha: 1))])
        flash.position = pos + dir * 0.02
        content.add(flash)
        let light = RealityKit.Entity()
        light.components.set(RealityKit.PointLightComponent(color: .init(red: 1, green: 0.85, blue: 0.4, alpha: 1), intensity: 28000, attenuationRadius: 2.0))
        light.position = pos + dir * 0.05
        content.add(light)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 45_000_000)
            if cone.parent != nil { cone.removeFromParent() }
            if flash.parent != nil { flash.removeFromParent() }
            if light.parent != nil { light.removeFromParent() }
        }
    }

}