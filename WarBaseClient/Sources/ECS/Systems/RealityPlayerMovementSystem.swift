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

        // Dead freeze (web: death anim)
        if pState.isDead {
            let stillDead = (viewMaps.soldier?.isEnabled ?? true)
            if currentAnim != "Dying", let soldier = viewMaps.soldier {
                let res = viewMaps.soldierAnims["Dying"] ?? viewMaps.soldierAnims["Rifle_Idle"]
                if let a = res { soldier.stopAllAnimations(); soldier.playAnimation(a, transitionDuration: 0.2); currentAnim = "Dying" }
            }
            // zero velocity via physics
            var m = player.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
            m.linearVelocity = .zero; m.angularVelocity = .zero; player.components.set(m)
            currentVelX = 0; currentVelZ = 0; verticalVel = 0
            entity.addComponent(pState)
            return
        }

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
        assert(!pState.yaw.isNaN && !pState.pitch.isNaN, "NaN yaw/pitch")
        if pState.yaw.isNaN { pState.yaw = 0 } ; if pState.pitch.isNaN { pState.pitch = 0 }
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

        // Vertical handled after auto-step via physics
        if input.jump && (isGrounded || pState.coyoteTimer > 0) && pState.jumpCooldownTimer <= 0 {
            verticalVel = JUMP_IMPULSE
            pState.isGrounded = false
            pState.coyoteTimer = 0
            pState.jumpCooldownTimer = JUMP_COOLDOWN
        }

        // Auto-step for stairs (web parity: dual low/high rays, 2.5 upward nudge)
        if isGrounded && dirLen > 0 && verticalVel < 0.5, let scene = player.scene {
            let moveDir = normalize(SIMD3<Float>(targetVel.x, 0, targetVel.z))
            if length(moveDir) > 0.001 {
                let lowOrigin = player.position + SIMD3<Float>(0, -0.8, 0)
                let highOrigin = player.position + SIMD3<Float>(0, -0.3, 0)
                let lowHits = scene.raycast(origin: lowOrigin, direction: moveDir, length: 0.6, query: .all, mask: .all)
                let highHits = scene.raycast(origin: highOrigin, direction: moveDir, length: 0.6, query: .all, mask: .all)
                let lowHit = lowHits.first(where: { !isInSubtree($0.entity, root: player) })
                let highHit = highHits.first(where: { !isInSubtree($0.entity, root: player) })
                if lowHit != nil && highHit == nil {
                    verticalVel = 2.5
                }
            }
        }

        // Physics-driven movement — RealityKit dynamic capsule (web: body.setLinearVelocity)
        var vel = SIMD3<Float>(currentVelX, verticalVel, currentVelZ)
        // platform velocity (web: isGrounded + ray pick physicsBody ANIMATED)
        // RealityKit: if ground entity is animated, add its linearVelocity (stub 0 for now)
        var motion = player.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        motion.linearVelocity = vel
        motion.angularVelocity = .zero
        player.components.set(motion)
        // keep visual position in sync — physics will integrate, but we also snap grounded Y like web
        if isGrounded {
            verticalVel = 0
            // gentle snap to ground like web's mesh.position.y = groundY + 0.9 is now handled by physics contact; keep tiny nudge
            if abs(player.position.y - (groundY + 0.9)) > 0.08 {
                player.position.y = groundY + 0.9
                motion.linearVelocity.y = 0
                player.components.set(motion)
            }
        } else {
            verticalVel += GRAVITY * dt
        }

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

        // Spring-arm wall avoidance
        if let anchor = viewMaps.cameraAnchor, let sc = player.scene {
            let desiredLocal: SIMD3<Float> = [0.6, 1.5, 1.6]
            let yawRot = simd_quatf(angle: pState.yaw, axis: [0,1,0])
            let desiredWorld = player.position + yawRot.act(desiredLocal)
            let headWorld = player.position + SIMD3<Float>(0, 1.2, 0)
            let toCam = desiredWorld - headWorld
            let d = length(toCam)
            if d > 0.2 {
                let dir = toCam / d
                let hits = sc.raycast(origin: headWorld, direction: dir, length: d, query: .all, mask: .all).filter { !isInSubtree($0.entity, root: player) }
                if let h = hits.min(by: { $0.distance < $1.distance }), h.distance < d - 0.15 {
                    let clamped: Float = max(Float(0.6), h.distance - 0.25)
                    anchor.position = desiredLocal * (clamped / d)
                } else { anchor.position = desiredLocal }
            }
        }

        // Pin soldier node against animation-baked node tracks
        viewMaps.soldier?.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0]) * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        viewMaps.soldier?.position = SIMD3<Float>(0.6, 1.131, 1.693)

        input.jump = false
        entity.addComponent(input)
        entity.addComponent(pState)
    }
}
