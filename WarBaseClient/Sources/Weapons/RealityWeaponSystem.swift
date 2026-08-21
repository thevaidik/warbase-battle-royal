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

    func update(input: InputState, entity: WarBaseClient.Entity, weaponState: inout WeaponState, recoilState: inout RecoilState, swayState: inout SwayState, time: TimeInterval, dt: Float, swayRoot: RealityKit.Entity, camera: RealityKit.Entity, scene: RealityKit.Scene, tracer: RealityTracerSystem, impact: RealityImpactSystem, decal: RealityDecalSystem, network: NetworkManager?, content: Any, isAssault: Bool) {
        let rate: Double = isAssault ? 600 : 45
        let interval = 60/rate
        let magSize = isAssault ? 30 : 5
        let isMoving = input.forward || input.backward || input.left || input.right

        if !input.fire { canFireSemi = true }

        let adsMult: Float = weaponState.adsProgress > 0.5 ? (isAssault ? 0.7 : 0.3) : 1.0
        if input.fire, !isReloading, weaponState.currentAmmo > 0, time - lastFire >= interval, (isAssault || canFireSemi) {
            lastFire = time
            canFireSemi = false
            weaponState.currentAmmo -= 1
            velY += (isAssault ? 0.02 : 0.08) * adsMult * 20
            velX += Float.random(in: -1...1) * (isAssault ? 0.008 : 0.015) * adsMult * 20
            spread = min(spread + (isAssault ? 0.4 : 2.0) * (1.0 - weaponState.adsProgress * (1.0 - (isAssault ? 0.4 : 0.05))), isAssault ? 5 : 8)
            recoilState.kickbackZ = weaponState.adsProgress > 0.5 ? -0.02 : -0.05
            recoilState.kickbackRotX = weaponState.adsProgress > 0.5 ? -0.02 : -0.08

            let camPos = camera.position(relativeTo: nil)
            let camDir = -camera.orientation(relativeTo: nil).act([0,0,1])
            let spreadRad = spread * .pi / 180 * (weaponState.adsProgress > 0.5 ? (isAssault ? 0.4 : 0.05) : 1)
            let rot = Float.random(in: 0...2 * .pi)
            let sinA = sin(spreadRad), cosR = cos(rot), sinR = sin(rot)
            let right = SIMD3<Float>(1,0,0) // use world axes for spread cone
            let up = SIMD3<Float>(0,1,0)
            var dir = normalize(camDir + right * cosR * sinA + up * sinR * sinA)
            let end = camPos + dir * 300
            let hits = scene.raycast(from: camPos, to: end, query: .all, mask: .all)
            var hitWall = false
            var hitPos = end, hitNorm = SIMD3<Float>(0,1,0)
            if let hit = hits.first(where: { $0.entity !== camera && $0.entity.parent !== camera }) {
                hitPos = hit.position; hitNorm = hit.normal
                if let name = hit.entity.name as String?, name.hasPrefix("hitbox::") {
                    let parts = name.components(separatedBy: "::")
                    if parts.count >= 3 {
                        let dmg: Float = isAssault ? 34 : 95
                        let mult = Float(parts[2]) ?? 1
                        network?.sendHit(targetId: parts[1], damage: dmg * mult, hitZone: parts.count>3 ? parts[3] : "torso")
                    }
                } else {
                    hitWall = true
                    if let contentAny = content as? any _RealityKit_SwiftUI.RealityViewContentProtocol {
                        decal.spawn(position: hitPos, normal: hitNorm, content: contentAny)
                        impact.spawn(position: hitPos, normal: hitNorm, content: contentAny)
                    }
                }
            }
            if let contentAny = content as? any _RealityKit_SwiftUI.RealityViewContentProtocol {
                tracer.spawn(start: camPos, end: hitPos, content: contentAny)
            }
            network?.sendFire(origin: camPos, hit: hitPos, normal: hitNorm, hitWall: hitWall)
        }

        if (input.reload || (input.fire && weaponState.currentAmmo==0)) && !isReloading && weaponState.currentAmmo < magSize {
            isReloading = true; reloadTimer = time
        }
        if isReloading && time - reloadTimer >= (isAssault ? 2.5 : 3.2) {
            isReloading = false; weaponState.currentAmmo = magSize
            network?.sendReload()
        }

        if spread > (isAssault ? 1.5 : 0.2) {
            spread = (isAssault ? 1.5 : 0.2) + (spread - (isAssault ? 1.5 : 0.2)) * exp(-(isAssault ? 8 : 5)*dt)
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
        swayRoot.position = [bobX * adsSway, bobY * adsSway, recoilState.kickbackZ]
        recoilState.kickbackZ += (0 - recoilState.kickbackZ) * min(1, 15*dt)
        recoilState.kickbackRotX += (0 - recoilState.kickbackRotX) * min(1, 15*dt)

        velX += (-150*recoilX - 15*velX)*dt
        velY += (-150*recoilY - 15*velY)*dt
        recoilX += velX*dt; recoilY += velY*dt
        if var p = entity.getComponent(PlayerComponentState.self) {
            p.yaw += recoilX; p.pitch += recoilY
            entity.addComponent(p)
        }
    }
}
