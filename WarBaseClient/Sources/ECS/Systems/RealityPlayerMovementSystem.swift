import RealityKit
import Foundation
import simd

// Mirrors client/src/ecs/systems/PlayerMovementSystem.ts exactly
final class RealityPlayerMovementSystem {
    var localPlayerId: Int = 0
    private let WALK_SPEED: Float = 4.5
    private let SPRINT_SPEED: Float = 5.5
    private let CROUCH_SPEED: Float = 2.0
    private let GROUND_ACCEL: Float = 40
    private let GROUND_DECEL: Float = 55
    private let AIR_ACCEL: Float = 12
    private let AIR_DECEL: Float = 5
    private let JUMP_IMPULSE: Float = 5.0
    private let JUMP_COOLDOWN: Float = 0.15
    private let COYOTE_TIME: Float = 0.1
    private let GRAVITY: Float = -15.328
    private let BASE_FOV: Float = 75
    private let SPRINT_FOV_BOOST: Float = 4
    private let FOV_LERP_SPEED: Float = 6
    private let STAND_CAM_Y: Float = 0.6
    private let CROUCH_CAM_Y: Float = 0.3
    private let CROUCH_LERP_SPEED: Float = 10
    private let BASE_SENSITIVITY: Float = 0.002
    private let STRAFE_MULTIPLIER: Float = 0.5

    var spawnPoint: SIMD3<Float> = [0, 2, 0]
    private var verticalVel: Float = 0
    private var currentVelX: Float = 0
    private var currentVelZ: Float = 0
    private var currentFOV: Float = 75
    private var currentCamY: Float = 0.6
    var currentAnim: String = ""

    private func moveTowards(_ current: Float, _ target: Float, _ maxDelta: Float) -> Float {
        if abs(target - current) <= maxDelta { return target }
        return current + (target > current ? maxDelta : -maxDelta)
    }

    private func isInSubtree(_ entity: RealityKit.Entity, root: RealityKit.Entity) -> Bool {
        var cur: RealityKit.Entity? = entity
        while let e = cur {
            if e === root { return true }
            cur = e.parent
        }
        return false
    }

    func update(deltaTime: Float, world: World, viewMaps: RealityViewMaps, scene: RealityKit.Scene? = nil) {
        guard let player = viewMaps.player,
              let camEntity = viewMaps.cameraEntity else { return }
        guard let entity = world.entities[localPlayerId],
              var input = entity.getComponent(InputState.self),
              var pState = entity.getComponent(PlayerComponentState.self) else { return }

        let dt = deltaTime

        // Timers (web:56-57)
        pState.jumpCooldownTimer = max(0, pState.jumpCooldownTimer - dt)
        pState.coyoteTimer = max(0, pState.coyoteTimer - dt)

        // Ground check via raycast
        let wasGrounded = pState.isGrounded
        var isGrounded = false
        var groundY: Float = -100
        if let sc = player.scene {
            // Cast from ABOVE the head: if the capsule sinks slightly into the
            // terrain skin, an origin at capsule level is below the top surface
            // and only sees deeper floor layers -> player rests underground.
            let origin = player.position + [0, 1.2, 0]
            let hits = sc.raycast(origin: origin, direction: [0,-1,0], length: 4, query: .all, mask: .all)
            if let h = hits.first(where: { !isInSubtree($0.entity, root: player) }) {
                groundY = h.position.y
                // Require falling: otherwise the launch frame of a jump gets
                // instantly re-grounded and the jump is killed in 1 frame.
                isGrounded = verticalVel <= 0.1 && (player.position.y - 0.9) <= groundY + 0.15
            }
        }
        pState.isGrounded = isGrounded

        // Void fall (web:68-73)
        if player.position.y < spawnPoint.y - 30 {
            player.position = spawnPoint
            verticalVel = 0
            currentVelX = 0
            currentVelZ = 0
            entity.addComponent(input)
            entity.addComponent(pState)
            return
        }

        if wasGrounded && !isGrounded { pState.coyoteTimer = COYOTE_TIME }

        // Rotation (web:77-88) - yaw/pitch accumulate, clamp pitch
        let isAds = input.ads
        let currentSens = isAds ? BASE_SENSITIVITY * 0.5 : BASE_SENSITIVITY
        pState.yaw -= input.mouseDeltaX * currentSens
        pState.pitch -= input.mouseDeltaY * currentSens
        pState.pitch = max(-Float.pi/2.1, min(Float.pi/2.1, pState.pitch))
        player.orientation = simd_quatf(angle: pState.yaw, axis: [0,1,0])
        camEntity.orientation = simd_quatf(angle: pState.pitch, axis: [1,0,0])
        input.mouseDeltaX = 0
        input.mouseDeltaY = 0

        // FOV zoom (web:90-103)
        let isMoving = input.forward || input.backward || input.left || input.right
        let isSprinting = input.sprint && input.forward && isGrounded && !pState.isCrouching
        pState.isSprinting = isSprinting
        var targetFOV: Float = BASE_FOV
        if isAds { targetFOV = 55 }
        else if isSprinting && isMoving { targetFOV = BASE_FOV + SPRINT_FOV_BOOST }
        currentFOV += (targetFOV - currentFOV) * min(1, FOV_LERP_SPEED * dt)
        if var camComp = camEntity.components[PerspectiveCameraComponent.self] {
            camComp.fieldOfViewInDegrees = currentFOV
            camEntity.components.set(camComp)
        }

        // Crouch (web:105-106)
        pState.isCrouching = input.crouch

        // Speed (web:108-117)
        var targetSpeed = WALK_SPEED
        if isSprinting { targetSpeed = SPRINT_SPEED }
        if pState.isCrouching { targetSpeed = CROUCH_SPEED }
        if input.fire && isGrounded && !pState.isCrouching { targetSpeed *= 0.6 }
        if input.backward { targetSpeed *= 0.6 }

        // Direction (web:119-126)
        var dirX: Float = 0, dirZ: Float = 0
        if input.forward { dirZ += 1 }
        if input.backward { dirZ -= 1 }
        if input.left { dirX -= 1 }
        if input.right { dirX += 1 }
        var localDir = SIMD3<Float>(dirX, 0, dirZ)
        let dirLen = length(localDir)
        if dirLen > 0 { localDir /= dirLen }

        // Camera-relative forward/right (web:128-145)
        let camWorldOrientation = camEntity.orientation(relativeTo: nil)
        var fwd = camWorldOrientation.act(SIMD3<Float>(0, 0, -1))
        var rgt = camWorldOrientation.act(SIMD3<Float>(1, 0, 0))
        fwd.y = 0; rgt.y = 0
        if length(fwd) > 0.001 { fwd = normalize(fwd) } else { fwd = SIMD3<Float>(sin(pState.yaw), 0, cos(pState.yaw)) }
        if length(rgt) > 0.001 { rgt = normalize(rgt) } else { rgt = SIMD3<Float>(cos(pState.yaw), 0, -sin(pState.yaw)) }

        var targetVel = fwd * localDir.z + rgt * (localDir.x * STRAFE_MULTIPLIER)
        targetVel *= targetSpeed

        // Acceleration (web:147-166)
        let accel = isGrounded ? (dirLen > 0 ? GROUND_ACCEL : GROUND_DECEL) : (dirLen > 0 ? AIR_ACCEL : AIR_DECEL)
        currentVelX = moveTowards(currentVelX, targetVel.x, accel * dt)
        currentVelZ = moveTowards(currentVelZ, targetVel.z, accel * dt)

        // Vertical (gravity + jump, web:189-194)
        if isGrounded {
            verticalVel = 0
            player.position.y = groundY + 0.9
        } else {
            verticalVel += GRAVITY * dt
        }
        if input.jump && (isGrounded || pState.coyoteTimer > 0) && pState.jumpCooldownTimer <= 0 {
            verticalVel = JUMP_IMPULSE
            pState.isGrounded = false
            pState.coyoteTimer = 0
            pState.jumpCooldownTimer = JUMP_COOLDOWN
        }

        // Wall collision: raycast forward to prevent phasing through map
        var vel = SIMD3<Float>(currentVelX, verticalVel, currentVelZ)
        let horiz = SIMD3<Float>(vel.x, 0, vel.z)
        let horizLen = length(horiz)
        if horizLen > 0.001, let scene = player.scene {
            let origin = player.position + SIMD3<Float>(0, 0.9, 0)
            let dir = normalize(horiz)
            let dist = horizLen * dt + 0.45
            let hits = scene.raycast(origin: origin, direction: dir, length: dist, query: .all, mask: .all)
            if let hit = hits.first(where: { !isInSubtree($0.entity, root: player) }) {
                if hit.distance < dist {
                    currentVelX = 0
                    currentVelZ = 0
                    vel.x = 0
                    vel.z = 0
                }
            }
        }
        player.position += vel * dt

        // Third-person camera anchor stays at [0, 1.6, 4.0] set in initPlayer.
        // (Old first-person crouch-height lerp removed.)

        // Animations (same names as web anim_data.json)
        if let soldier = viewMaps.soldier {
            let targetAnim: String
            if verticalVel > 1.0 || (!isGrounded && !wasGrounded) { targetAnim = "Rifle Jump" }
            else if input.fire { targetAnim = dirLen > 0 ? "Firing walk Rifle" : "Firing Rifle" }
            else if dirLen > 0 {
                if input.left && !input.forward && !input.right { targetAnim = "Strafe Left" }
                else if input.right && !input.forward && !input.left { targetAnim = "Strafe Right" }
                else if input.backward && !input.forward { targetAnim = "Walking Backwards" }
                else { targetAnim = "Rifle Run" }
            } else { targetAnim = "Rifle Idle" }
            if targetAnim != currentAnim {
                let key = targetAnim.replacingOccurrences(of: " ", with: "_")
                let res = viewMaps.soldierAnims[key] ?? viewMaps.soldierAnims["Rifle_Idle"]
                if let a = res {
                    soldier.stopAllAnimations()
                    soldier.playAnimation(a.repeat(), transitionDuration: 0.2)
                    currentAnim = targetAnim
                }
            }
        }

        // Pin soldier node against animation-baked node tracks
        viewMaps.soldier?.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0]) * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        viewMaps.soldier?.position = SIMD3<Float>(0.355, 1.131, 1.693)

        input.jump = false
        entity.addComponent(input)
        entity.addComponent(pState)
    }
}
