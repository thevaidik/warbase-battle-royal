import Foundation
import SceneKit
import Combine

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public protocol WeaponNetworkDelegate: AnyObject {
    func didFireWeapon(weaponName: String, position: SCNVector3, direction: SCNVector3)
    func didHitTarget(targetID: String, damage: Float, isHeadshot: Bool)
    func didThrowGrenade(position: SCNVector3, direction: SCNVector3)
}

public class WeaponSystem {
    private weak var scene: SCNScene?
    private weak var cameraNode: SCNNode?
    public weak var networkDelegate: WeaponNetworkDelegate?
    
    public var currentWeaponName: String = "AK-47"
    public var currentWeaponNode: SCNNode?
    private var config: WeaponConfig!
    
    // Ammo state
    public var currentAmmo: Int = 30
    public var isReloading = false
    private var reloadPhase = 0
    private var reloadTimer: TimeInterval = 0
    
    // Firing state
    private var lastFireTime: TimeInterval = 0
    private var canFireSemi = true
    
    // ADS state
    public var isADS = false
    public var adsProgress: Float = 0
    
    // Spread & Recoil state
    public var currentBloom: Float = 0
    private var currentRecoilPitch: Float = 0
    private var currentRecoilYaw: Float = 0
    
    // Physics / Spring-Damper for recoil
    private var recoilVelocityPitch: Float = 0
    private var recoilVelocityYaw: Float = 0
    private let recoilStiffness: Float = 150.0
    private let recoilDamping: Float = 15.0
    
    // Sway & Bobbing
    private var walkBobTimer: Float = 0
    private var sprintBobTimer: Float = 0
    private var breatheTimer: Float = 0
    
    // Visual kickback
    private var kickbackOffset: Float = 0
    private var kickbackVelocity: Float = 0
    
    // Grenade
    private var lastGrenadeTime: TimeInterval = 0
    private var grenadeSystem: GrenadeSystem!
    
    public init(scene: SCNScene, cameraNode: SCNNode) {
        self.scene = scene
        self.cameraNode = cameraNode
        self.grenadeSystem = GrenadeSystem(scene: scene)
        equipWeapon(name: "AK-47")
    }
    
    public func equipWeapon(name: String) {
        guard let newConfig = WEAPON_CONFIGS[name] else { return }
        self.config = newConfig
        self.currentWeaponName = name
        
        currentWeaponNode?.removeFromParentNode()
        
        switch name {
        case "AK-47":
            currentWeaponNode = AK47Builder.build()
        case "M2010":
            currentWeaponNode = M2010Builder.build()
        case "Pistol":
            currentWeaponNode = PistolBuilder.build()
        default:
            currentWeaponNode = AK47Builder.build()
        }
        
        if let weaponNode = currentWeaponNode {
            cameraNode?.addChildNode(weaponNode)
            weaponNode.position = config.hipPosition
            self.currentAmmo = config.magSize
        }
    }
    
    public func update(dt: TimeInterval, currentTime: TimeInterval, isWalking: Bool, isSprinting: Bool, mouseDeltaX: Float, mouseDeltaY: Float) {
        updateADS(dt: Float(dt))
        updateRecoilAndBloom(dt: Float(dt))
        updateSwayAndBobbing(dt: Float(dt), isWalking: isWalking, isSprinting: isSprinting, mouseDeltaX: mouseDeltaX, mouseDeltaY: mouseDeltaY)
        updateReload(dt: dt)
        applyWeaponTransform()
    }
    
    private func updateADS(dt: Float) {
        let targetADS: Float = isADS ? 1.0 : 0.0
        let speed = 1.0 / config.adsTime
        
        if adsProgress < targetADS {
            adsProgress += dt * speed
            if adsProgress > 1.0 { adsProgress = 1.0 }
        } else if adsProgress > targetADS {
            adsProgress -= dt * speed
            if adsProgress < 0.0 { adsProgress = 0.0 }
        }
        
        if let camera = cameraNode?.camera {
            let baseFOV: CGFloat = 90.0 // Default FOV
            let targetFOV = CGFloat(config.adsFOV)
            camera.fieldOfView = baseFOV + (targetFOV - baseFOV) * CGFloat(adsProgress)
        }
    }
    
    private func updateRecoilAndBloom(dt: Float) {
        // Bloom recovery (exponential)
        if currentBloom > 0 {
            currentBloom -= config.bloomRecovery * dt
            if currentBloom < 0 { currentBloom = 0 }
        }
        
        // Spring-damper recoil recovery
        let forcePitch = -currentRecoilPitch * recoilStiffness - recoilVelocityPitch * recoilDamping
        let forceYaw = -currentRecoilYaw * recoilStiffness - recoilVelocityYaw * recoilDamping
        
        recoilVelocityPitch += forcePitch * dt
        recoilVelocityYaw += forceYaw * dt
        
        currentRecoilPitch += recoilVelocityPitch * dt
        currentRecoilYaw += recoilVelocityYaw * dt
        
        // Visual kickback recovery
        let kickbackForce = -kickbackOffset * 200.0 - kickbackVelocity * 20.0
        kickbackVelocity += kickbackForce * dt
        kickbackOffset += kickbackVelocity * dt
    }
    
    private func updateSwayAndBobbing(dt: Float, isWalking: Bool, isSprinting: Bool, mouseDeltaX: Float, mouseDeltaY: Float) {
        // Idle breathing
        breatheTimer += dt * 1.5
        
        if isWalking { walkBobTimer += dt * 8.0 }
        if isSprinting { sprintBobTimer += dt * 12.0 }
    }
    
    private func applyWeaponTransform() {
        guard let weaponNode = currentWeaponNode else { return }
        
        // Interpolate position
        let hipPos = config.hipPosition
        let adsPos = config.adsPosition
        
        var targetPos = SCNVector3(
            hipPos.x + (adsPos.x - hipPos.x) * adsProgress,
            hipPos.y + (adsPos.y - hipPos.y) * adsProgress,
            hipPos.z + (adsPos.z - hipPos.z) * adsProgress
        )
        
        // Add kickback
        targetPos.z += kickbackOffset
        
        // Add sway and bob
        let bobAmt = (1.0 - adsProgress) * 0.02
        targetPos.y += sin(breatheTimer) * 0.005
        targetPos.x += cos(breatheTimer * 0.5) * 0.002
        
        weaponNode.position = targetPos
        
        // Rotation (pitch/yaw from recoil)
        let recoilMod = 1.0 - (adsProgress * (1.0 - config.adsRecoilMult))
        weaponNode.eulerAngles = SCNVector3(
            currentRecoilPitch * recoilMod,
            currentRecoilYaw * recoilMod,
            0
        )
    }
    
    public func handleInput(isFiring: Bool, currentTime: TimeInterval) {
        if isReloading { return }
        
        if !isFiring {
            canFireSemi = true
            return
        }
        
        if !config.isAuto && !canFireSemi {
            return
        }
        
        let timeSinceLastFire = currentTime - lastFireTime
        let fireInterval = 60.0 / Double(config.fireRate)
        
        if timeSinceLastFire >= fireInterval {
            if currentAmmo > 0 {
                fire(currentTime: currentTime)
                canFireSemi = false
            } else {
                startReload()
            }
        }
    }
    
    private func fire(currentTime: TimeInterval) {
        lastFireTime = currentTime
        currentAmmo -= 1
        
        // Recoil impulse
        let pitchImpulse = config.recoilVertical * Float.random(in: 0.8...1.2)
        let yawImpulse = config.recoilHorizontal * Float.random(in: -1.0...1.0)
        
        recoilVelocityPitch += pitchImpulse * 50.0
        recoilVelocityYaw += yawImpulse * 50.0
        
        // Bloom
        let spreadMod = 1.0 - (adsProgress * (1.0 - config.adsSpreadMult))
        currentBloom += config.bloomPerShot * spreadMod
        if currentBloom > config.maxSpread {
            currentBloom = config.maxSpread
        }
        
        // Visual kickback
        kickbackVelocity += 0.5 // Z-axis kick
        
        // FX
        spawnMuzzleFlash()
        spawnShellEjection()
        
        // Raycast
        performRaycast()
        
        // Network
        if let cam = cameraNode {
            let fwd = cam.presentation.worldFront
            networkDelegate?.didFireWeapon(weaponName: currentWeaponName, position: cam.presentation.worldPosition, direction: fwd)
        }
    }
    
    private func performRaycast() {
        guard let scene = scene, let cam = cameraNode else { return }
        
        let startPos = cam.presentation.worldPosition
        let forward = cam.presentation.worldFront
        
        // Calculate cone spread
        let spreadAngle = (config.baseSpread + currentBloom) * (Float.pi / 180.0)
        let randomAngle = Float.random(in: 0...(2 * Float.pi))
        let randomRadius = Float.random(in: 0...spreadAngle)
        
        let right = cam.presentation.worldRight
        let up = cam.presentation.worldUp
        
        var dir = forward
        let scaledRight = SCNVector3(right.x * cos(randomAngle) * randomRadius, right.y * cos(randomAngle) * randomRadius, right.z * cos(randomAngle) * randomRadius)
        let scaledUp = SCNVector3(up.x * sin(randomAngle) * randomRadius, up.y * sin(randomAngle) * randomRadius, up.z * sin(randomAngle) * randomRadius)
        
        dir.x += scaledRight.x + scaledUp.x
        dir.y += scaledRight.y + scaledUp.y
        dir.z += scaledRight.z + scaledUp.z
        dir = dir.normalized()
        
        let endPos = SCNVector3(
            startPos.x + dir.x * 1000.0,
            startPos.y + dir.y * 1000.0,
            startPos.z + dir.z * 1000.0
        )
        
        let hits = scene.physicsWorld.rayTestWithSegment(from: startPos, to: endPos, options: [
            .searchMode: SCNPhysicsWorld.TestSearchMode.closest
        ])
        
        if let hit = hits.first {
            spawnTracer(start: startPos, end: hit.worldCoordinates)
            
            // Check hit detection
            if let targetName = hit.node.name, targetName.hasPrefix("player_") {
                let isHeadshot = hit.node.name?.contains("head") ?? false
                let damage = config.damage * (isHeadshot ? config.headshotMult : 1.0)
                networkDelegate?.didHitTarget(targetID: targetName, damage: damage, isHeadshot: isHeadshot)
            } else if let body = hit.node.physicsBody, body.type == .dynamic {
                let impulse = SCNVector3(dir.x * 10.0, dir.y * 10.0, dir.z * 10.0)
                body.applyForce(impulse, at: hit.localCoordinates, asImpulse: true)
                spawnImpact(hitPoint: hit.worldCoordinates, normal: hit.worldNormal)
            } else {
                spawnDecal(hitPoint: hit.worldCoordinates, normal: hit.worldNormal)
                spawnImpact(hitPoint: hit.worldCoordinates, normal: hit.worldNormal)
            }
        } else {
            spawnTracer(start: startPos, end: endPos)
        }
    }
    
    public func startReload() {
        if isReloading || currentAmmo == config.magSize { return }
        isReloading = true
        reloadPhase = 0
        reloadTimer = 0
        
        // Play reload sound/anim locally
    }
    
    private func updateReload(dt: TimeInterval) {
        if !isReloading { return }
        
        reloadTimer += dt
        let phaseTime = Double(config.reloadTime) / 3.0
        
        if reloadTimer > phaseTime * 3.0 {
            // Recover phase done
            isReloading = false
            currentAmmo = config.magSize
        } else if reloadTimer > phaseTime * 2.0 && reloadPhase == 1 {
            // Hold -> Recover
            reloadPhase = 2
        } else if reloadTimer > phaseTime && reloadPhase == 0 {
            // Enter -> Hold
            reloadPhase = 1
        }
        
        // Animate weapon down/up based on phase
        if let weaponNode = currentWeaponNode {
            if reloadPhase == 0 {
                weaponNode.position.y -= Float(dt) * 0.5
                weaponNode.eulerAngles.x += Float(dt) * 0.5
            } else if reloadPhase == 2 {
                // Return to normal is handled by interpolation in applyWeaponTransform,
                // but we'll reset euler here roughly
                weaponNode.eulerAngles.x -= Float(dt) * 0.5
            }
        }
    }
    
    public func throwGrenade(currentTime: TimeInterval) {
        if currentTime - lastGrenadeTime < 1.0 { return }
        lastGrenadeTime = currentTime
        
        guard let cam = cameraNode else { return }
        let pos = cam.presentation.worldPosition
        let dir = cam.presentation.worldFront
        let throwDir = SCNVector3(dir.x, dir.y + 0.2, dir.z).normalized()
        let vel = SCNVector3(throwDir.x * 25.0, throwDir.y * 25.0, throwDir.z * 25.0)
        
        grenadeSystem.throwNetworkGrenade(position: pos, direction: vel)
        networkDelegate?.didThrowGrenade(position: pos, direction: vel)
    }
    
    public func switchWeapon(to index: Int) {
        if isReloading { return } // Block switch during reload
        
        let weaponKeys = Array(WEAPON_CONFIGS.keys).sorted() // Just an example, usually bounded by loadout
        if index >= 0 && index < weaponKeys.count {
            equipWeapon(name: weaponKeys[index])
        }
    }
    
    // FX Spawners
    private func spawnMuzzleFlash() {
        guard let scene = scene else { return }
        
        let flash = SCNParticleSystem()
        flash.birthRate = 0
        flash.emissionDuration = 0.05
        flash.loops = false
        flash.particleLifeSpan = 0.08
        flash.particleColor = PlatformColor.orange
        flash.particleSize = 0.1
        flash.particleVelocity = 0.5
        flash.spreadingAngle = 45
        
        // Attach to muzzle point if exists, else attach to camera
        let muzzleNode = SCNNode()
        muzzleNode.position = SCNVector3(0.08, -0.05, -0.5) // Approximate right side of screen
        
        if let cam = cameraNode {
            cam.addChildNode(muzzleNode)
            muzzleNode.addParticleSystem(flash)
            
            // Emit burst
            flash.birthRate = 150
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                flash.birthRate = 0
                muzzleNode.removeFromParentNode()
            }
        }
    }
    
    private func spawnShellEjection() {
        guard let scene = scene else { return }
        
        let shell = SCNCylinder(radius: 0.005, height: 0.02)
        shell.firstMaterial?.diffuse.contents = PlatformColor.yellow
        let shellNode = SCNNode(geometry: shell)
        
        if let cam = cameraNode {
            // Eject from right side of weapon
            let ejectPos = cam.presentation.convertPosition(SCNVector3(0.1, -0.1, -0.3), to: nil)
            shellNode.position = ejectPos
            shellNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            shellNode.physicsBody?.restitution = 0.3
            scene.rootNode.addChildNode(shellNode)
            
            // Impulse up and right
            let right = cam.presentation.worldRight
            let up = cam.presentation.worldUp
            let impulse = SCNVector3(right.x * 2.0 + up.x * 1.5, right.y * 2.0 + up.y * 1.5, right.z * 2.0 + up.z * 1.5)
            
            shellNode.physicsBody?.applyForce(impulse, asImpulse: true)
            shellNode.physicsBody?.angularVelocity = SCNVector4(1, 0, 0, 5)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                shellNode.removeFromParentNode()
            }
        }
    }
    
    private func spawnTracer(start: SCNVector3, end: SCNVector3) {
        guard let scene = scene else { return }
        
        let distance = Float(simd_distance(simd_float3(start.x, start.y, start.z), simd_float3(end.x, end.y, end.z)))
        let tracerGeo = SCNCapsule(capRadius: 0.02, height: CGFloat(distance))
        tracerGeo.firstMaterial?.diffuse.contents = PlatformColor.yellow
        tracerGeo.firstMaterial?.emission.contents = PlatformColor.yellow
        let tracerNode = SCNNode(geometry: tracerGeo)
        
        let midPoint = SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)
        tracerNode.position = midPoint
        
        // Orient towards end
        let up = SCNVector3(0, 1, 0)
        let dir = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z).normalized()
        let axis = SCNVector3(up.y * dir.z - up.z * dir.y, up.z * dir.x - up.x * dir.z, up.x * dir.y - up.y * dir.x)
        let dotProduct = up.x * dir.x + up.y * dir.y + up.z * dir.z
        let angle = acos(max(-1.0, min(1.0, dotProduct)))
        if length(v: axis) > 0.001 {
            tracerNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        }
        
        scene.rootNode.addChildNode(tracerNode)
        
        // Fade out
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.2
        tracerNode.opacity = 0.0
        SCNTransaction.commit()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            tracerNode.removeFromParentNode()
        }
    }
    
    private func spawnDecal(hitPoint: SCNVector3, normal: SCNVector3) {
        guard let scene = scene else { return }
        let decal = SCNPlane(width: 0.2, height: 0.2)
        decal.firstMaterial?.diffuse.contents = PlatformColor.black
        let node = SCNNode(geometry: decal)
        node.position = SCNVector3(hitPoint.x + normal.x * 0.02, hitPoint.y + normal.y * 0.02, hitPoint.z + normal.z * 0.02)
        // Align to normal
        let up = SCNVector3(0, 1, 0)
        let axis = SCNVector3(up.y * normal.z - up.z * normal.y, up.z * normal.x - up.x * normal.z, up.x * normal.y - up.y * normal.x)
        let angle = acos(max(-1.0, min(1.0, up.x * normal.x + up.y * normal.y + up.z * normal.z)))
        if length(v: axis) > 0.001 {
            node.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        }
        scene.rootNode.addChildNode(node)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            node.removeFromParentNode()
        }
    }
    
    private func spawnImpact(hitPoint: SCNVector3, normal: SCNVector3) {
        guard let scene = scene else { return }
        
        let spark = SCNParticleSystem()
        spark.birthRate = 300
        spark.emissionDuration = 0.05
        spark.loops = false
        spark.particleLifeSpan = 0.2
        spark.particleColor = PlatformColor.gray
        spark.particleSize = 0.03
        spark.particleVelocity = 5.0
        spark.spreadingAngle = 90
        
        let node = SCNNode()
        node.position = hitPoint
        // Orient sparks along normal
        node.orientation = SCNVector4(normal.x, normal.y, normal.z, 0)
        node.addParticleSystem(spark)
        
        scene.rootNode.addChildNode(node)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            node.removeFromParentNode()
        }
    }
    
    private func length(v: SCNVector3) -> Float {
        return sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
    }
}

extension SCNVector3 {
    func normalized() -> SCNVector3 {
        let len = sqrt(x*x + y*y + z*z)
        if len == 0 { return self }
        return SCNVector3(x/len, y/len, z/len)
    }
}
