import SceneKit
import Foundation

public class PlayerMovementSystem {
    private let WALK_SPEED: Float = 4.5
    private let SPRINT_SPEED: Float = 5.5
    private let CROUCH_SPEED: Float = 2.0
    
    private let GROUND_ACCEL: Float = 40.0
    private let GROUND_DECEL: Float = 55.0
    private let AIR_ACCEL: Float = 12.0
    private let AIR_DECEL: Float = 5.0
    
    private let JUMP_IMPULSE: Float = 5.0
    private let JUMP_COOLDOWN: Float = 0.15
    
    private let BASE_FOV: CGFloat = 75.0
    private let SPRINT_FOV_BOOST: CGFloat = 4.0
    private let FOV_LERP_SPEED: Float = 6.0
    
    private let STAND_CAM_Y: Float = 0.6
    private let CROUCH_CAM_Y: Float = 0.3
    private let CROUCH_LERP_SPEED: Float = 10.0
    
    private let BASE_SENSITIVITY: Float = 0.002
    
    private weak var scene: SCNScene?
    
    public init(scene: SCNScene?) {
        self.scene = scene
    }
    
    private func moveTowards(_ current: Float, _ target: Float, _ maxDelta: Float) -> Float {
        if abs(target - current) <= maxDelta { return target }
        return current + (target > current ? maxDelta : -maxDelta)
    }
    
    public func update(deltaTime: Float, world: World, viewMaps: ViewMaps) {
        guard let scene = scene else { return }
        
        for (id, entity) in world.entities {
            guard var input = entity.getComponent(InputState.self),
                  var playerState = entity.getComponent(PlayerComponentState.self),
                  let weaponState = entity.getComponent(WeaponState.self),
                  let physicsBody = viewMaps.entityPhysicsBodies[id],
                  let node = viewMaps.entityNodes[id],
                  let camNode = viewMaps.entityCameras[id] else {
                continue
            }
            
            // Timers
            playerState.jumpCooldownTimer = max(0, playerState.jumpCooldownTimer - deltaTime)
            playerState.coyoteTimer = max(0, playerState.coyoteTimer - deltaTime)
            
            // Ground Check via Raycast
            let groundRayOrigin = node.position
            let groundRayDest = SCNVector3(groundRayOrigin.x, groundRayOrigin.y - 0.95, groundRayOrigin.z)
            let groundHits = scene.physicsWorld.rayTestWithSegment(from: groundRayOrigin, to: groundRayDest, options: [.searchMode: SCNPhysicsWorld.TestSearchMode.closest.rawValue])
            let rayResult = groundHits.first { $0.node != node && !$0.node.isDescendant(of: node) }
            
            let wasGrounded = playerState.isGrounded
            let isGrounded = (rayResult != nil)
            playerState.isGrounded = isGrounded
            
            if wasGrounded && !isGrounded {
                playerState.coyoteTimer = 0.1
            }
            
            // Void fall protection
            let spawnY: Float = 20.0
            if node.position.y < spawnY - 30.0 {
                node.position = SCNVector3(0, spawnY, 0)
                physicsBody.velocity = SCNVector3Zero
                continue
            }
            
            // Rotation
            let isAds = input.ads
            let currentSens = isAds ? BASE_SENSITIVITY * 0.5 : BASE_SENSITIVITY
            
            playerState.yaw -= input.mouseDeltaX * currentSens
            playerState.pitch -= input.mouseDeltaY * currentSens
            
            // Clamp pitch
            let maxPitch = Float.pi / 2.1
            playerState.pitch = max(min(playerState.pitch, maxPitch), -maxPitch)
            
            node.eulerAngles = SCNVector3(0, playerState.yaw, 0)
            camNode.eulerAngles = SCNVector3(playerState.pitch, 0, 0)
            
            input.mouseDeltaX = 0
            input.mouseDeltaY = 0
            
            // Speed Calculation
            playerState.isCrouching = input.crouch
            playerState.isSprinting = input.sprint && input.forward && isGrounded && !input.crouch
            let isMoving = input.forward || input.backward || input.left || input.right
            
            var targetSpeed = WALK_SPEED
            if playerState.isSprinting { targetSpeed = SPRINT_SPEED }
            if playerState.isCrouching { targetSpeed = CROUCH_SPEED }
            
            // Penalties
            if input.fire && isGrounded && !playerState.isCrouching {
                targetSpeed *= 0.6
            }
            if input.backward {
                targetSpeed *= 0.6
            }
            
            // FOV Zoom
            var targetFOV = BASE_FOV
            if isAds {
                let weaponKeys = ["AK-47", "Pistol", "M2010"]
                let weaponKey = (weaponState.activeWeaponIndex >= 0 && weaponState.activeWeaponIndex < weaponKeys.count) ? weaponKeys[weaponState.activeWeaponIndex] : "AK-47"
                let wepConfig = WEAPON_CONFIGS[weaponKey] ?? WEAPON_CONFIGS["AK-47"]!
                targetFOV = CGFloat(wepConfig.adsFOV)
            } else if playerState.isSprinting && isMoving {
                targetFOV = BASE_FOV + SPRINT_FOV_BOOST
            }
            let currentFOV = camNode.camera?.fieldOfView ?? BASE_FOV
            camNode.camera?.fieldOfView = currentFOV + (targetFOV - currentFOV) * CGFloat(FOV_LERP_SPEED * deltaTime)
            
            // Direction Vectors
            var dirX: Float = 0, dirZ: Float = 0
            if input.forward { dirZ += 1 }
            if input.backward { dirZ -= 1 }
            if input.left { dirX -= 1 }
            if input.right { dirX += 1 }
            
            var localDir = SCNVector3(dirX, 0, dirZ)
            let length = sqrt(localDir.x * localDir.x + localDir.z * localDir.z)
            if length > 0 {
                localDir.x /= length
                localDir.z /= length
            }
            
            let cosYaw = cos(playerState.yaw)
            let sinYaw = sin(playerState.yaw)
            let tempForward = SCNVector3(-sinYaw, 0, -cosYaw)
            let tempRight = SCNVector3(-cosYaw, 0, sinYaw)
            
            let STRAFE_MULTIPLIER: Float = 0.5
            var targetVel = SCNVector3(
                tempForward.x * localDir.z + tempRight.x * (localDir.x * STRAFE_MULTIPLIER),
                0,
                tempForward.z * localDir.z + tempRight.z * (localDir.x * STRAFE_MULTIPLIER)
            )
            targetVel.x *= targetSpeed
            targetVel.z *= targetSpeed
            
            let accel = isGrounded ? (length > 0 ? GROUND_ACCEL : GROUND_DECEL) : (length > 0 ? AIR_ACCEL : AIR_DECEL)
            
            let currentVel = physicsBody.velocity
            
            // Platform Physics
            var platformVel = SCNVector3Zero
            if isGrounded, let hitNode = rayResult?.node, let hitBody = hitNode.physicsBody {
                if hitBody.type == SCNPhysicsBodyType.kinematic || hitBody.type == SCNPhysicsBodyType.dynamic {
                    platformVel = hitBody.velocity
                }
            }
            
            let localCurrentX = Float(currentVel.x) - platformVel.x
            let localCurrentZ = Float(currentVel.z) - platformVel.z
            
            let newLocalX = moveTowards(localCurrentX, targetVel.x, accel * deltaTime)
            let newLocalZ = moveTowards(localCurrentZ, targetVel.z, accel * deltaTime)
            
            let newX = newLocalX + platformVel.x
            let newZ = newLocalZ + platformVel.z
            var newY = Float(currentVel.y)
            
            // Auto-step for stairs: Dual raycast stepping
            if isGrounded && length > 0 && newY < 0.5 {
                let moveDir = SCNVector3(targetVel.x, 0, targetVel.z)
                let moveLen = sqrt(moveDir.x * moveDir.x + moveDir.z * moveDir.z)
                if moveLen > 0 {
                    let normDir = SCNVector3(moveDir.x / moveLen, 0, moveDir.z / moveLen)
                    
                    let originLow = SCNVector3(node.position.x, node.position.y - 0.8, node.position.z)
                    let destLow = SCNVector3(originLow.x + normDir.x * 0.6, originLow.y, originLow.z + normDir.z * 0.6)
                    let hitsLow = scene.physicsWorld.rayTestWithSegment(from: originLow, to: destLow, options: [.searchMode: SCNPhysicsWorld.TestSearchMode.closest.rawValue])
                    let lowHit = hitsLow.first { $0.node != node && !$0.node.isDescendant(of: node) }
                    
                    let originHigh = SCNVector3(node.position.x, node.position.y - 0.3, node.position.z)
                    let destHigh = SCNVector3(originHigh.x + normDir.x * 0.6, originHigh.y, originHigh.z + normDir.z * 0.6)
                    let hitsHigh = scene.physicsWorld.rayTestWithSegment(from: originHigh, to: destHigh, options: [.searchMode: SCNPhysicsWorld.TestSearchMode.closest.rawValue])
                    let highHit = hitsHigh.first { $0.node != node && !$0.node.isDescendant(of: node) }
                    
                    if lowHit != nil && highHit == nil {
                        newY = 2.5 // Upward nudge to slide over the step
                    }
                }
            }
            
            // Jump
            if input.jump && (isGrounded || playerState.coyoteTimer > 0) && playerState.jumpCooldownTimer <= 0 {
                newY = JUMP_IMPULSE
                playerState.isGrounded = false
                playerState.coyoteTimer = 0
                playerState.jumpCooldownTimer = JUMP_COOLDOWN
            }
            
            physicsBody.velocity = SCNVector3(newX, newY, newZ)
            physicsBody.angularVelocity = SCNVector4(0,0,0,0) // Keep upright
            
            // Camera Height Lerp
            let targetCamY = playerState.isCrouching ? CROUCH_CAM_Y : STAND_CAM_Y
            let currentCamY = Float(camNode.position.y)
            let newCamY = currentCamY + (targetCamY - currentCamY) * CROUCH_LERP_SPEED * deltaTime
            camNode.position.y = newCamY
            camNode.position.x = 0 // Reset X shift
            
            // Clear jump intent
            input.jump = false
            
            // Save state
            entity.addComponent(input)
            entity.addComponent(playerState)
            entity.addComponent(Position(x: Float(node.position.x), y: Float(node.position.y), z: Float(node.position.z)))
            entity.addComponent(Velocity(x: Float(newX), y: Float(newY), z: Float(newZ)))
        }
    }
}

extension SCNNode {
    func isDescendant(of target: SCNNode) -> Bool {
        var p = self.parent
        while let current = p {
            if current == target { return true }
            p = current.parent
        }
        return false
    }
}
