import Foundation
import SceneKit
import Combine


public class GrenadeSystem {
    public static let GRENADE_RADIUS: Float = 0.1
    public static let FUSE: TimeInterval = 3.0 // 3000ms
    public static let EXPLOSION_RADIUS: Float = 8.0
    public static let EXPLOSION_FORCE: Float = 30.0
    
    private weak var scene: SCNScene?
    
    public init(scene: SCNScene) {
        self.scene = scene
    }
    
    public func throwNetworkGrenade(position: SCNVector3, direction: SCNVector3) {
        guard let scene = scene else { return }
        
        let sphere = SCNSphere(radius: CGFloat(GrenadeSystem.GRENADE_RADIUS))
        let material = SCNMaterial()
        material.diffuse.contents = PlatformColor(red: 0.33, green: 0.42, blue: 0.18, alpha: 1.0) // Olive green
        sphere.materials = [material]
        
        let grenadeNode = SCNNode(geometry: sphere)
        grenadeNode.position = position
        
        let physicsShape = SCNPhysicsShape(geometry: sphere, options: nil)
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
        physicsBody.mass = 3.0
        physicsBody.restitution = 0.1
        physicsBody.friction = 0.8
        
        grenadeNode.physicsBody = physicsBody
        scene.rootNode.addChildNode(grenadeNode)
        
        // Launch impulse
        let impulse = SCNVector3(
            direction.x * 25.0,
            (direction.y + 0.2) * 25.0,
            direction.z * 25.0
        )
        physicsBody.applyForce(impulse, asImpulse: true)
        
        // Timer for detonation
        DispatchQueue.main.asyncAfter(deadline: .now() + GrenadeSystem.FUSE) { [weak self] in
            self?.detonateGrenade(node: grenadeNode)
        }
    }
    
    private func detonateGrenade(node: SCNNode) {
        guard let scene = scene else { return }
        
        let explosionPos = node.presentation.position
        
        // Create explosion particles
        createExplosionParticles(at: explosionPos)
        
        // Remove grenade node
        node.removeFromParentNode()
        
        // Explosion logic - find bodies in radius
        // SceneKit doesn't have a direct sphere query for physics bodies, 
        // but we can query nodes and check distances or use physics world's rayTests/contact tests if needed.
        // For simplicity, we'll iterate through child nodes with physics bodies.
        
        let maxDistSq = GrenadeSystem.EXPLOSION_RADIUS * GrenadeSystem.EXPLOSION_RADIUS
        
        for child in scene.rootNode.childNodes {
            guard let body = child.physicsBody, body.type == .dynamic else { continue }
            
            let dx = child.presentation.position.x - explosionPos.x
            let dy = child.presentation.position.y - explosionPos.y
            let dz = child.presentation.position.z - explosionPos.z
            
            let distSq = dx*dx + dy*dy + dz*dz
            
            if distSq < maxDistSq {
                let dist = sqrt(distSq)
                let falloff = 1.0 - (dist / GrenadeSystem.EXPLOSION_RADIUS)
                let forceMagnitude = GrenadeSystem.EXPLOSION_FORCE * falloff
                
                // Normalize direction and add upward arc boost
                var dir = SCNVector3(dx, dy, dz)
                if dist > 0 {
                    dir.x /= dist
                    dir.y /= dist
                    dir.z /= dist
                }
                dir.y += 0.5 // Upward arc boost
                
                // Re-normalize roughly
                let len = sqrt(dir.x*dir.x + dir.y*dir.y + dir.z*dir.z)
                if len > 0 {
                    dir.x /= len
                    dir.y /= len
                    dir.z /= len
                }
                
                let force = SCNVector3(
                    dir.x * forceMagnitude,
                    dir.y * forceMagnitude,
                    dir.z * forceMagnitude
                )
                
                body.applyForce(force, asImpulse: true)
            }
        }
    }
    
    private func createExplosionParticles(at position: SCNVector3) {
        guard let scene = scene else { return }
        
        let particleSystem = SCNParticleSystem()
        particleSystem.birthRate = 200
        particleSystem.emissionDuration = 0.1
        particleSystem.loops = false
        
        particleSystem.particleLifeSpan = 1.0
        particleSystem.particleLifeSpanVariation = 0.5
        
        particleSystem.particleSize = 0.5
        particleSystem.particleSizeVariation = 0.2
        
        particleSystem.particleVelocity = 5.0
        particleSystem.particleVelocityVariation = 2.0
        
        particleSystem.spreadingAngle = 180
        
        particleSystem.particleColor = PlatformColor.orange
        particleSystem.particleColorVariation = SCNVector4(0.2, 0.1, 0, 0)
        
        // Color gradient: orange -> red -> smoke
        let colorAnim = CAKeyframeAnimation(keyPath: "particleColor")
        colorAnim.values = [
            PlatformColor.orange,
            PlatformColor.red,
            PlatformColor.darkGray,
            PlatformColor.clear
        ]
        colorAnim.keyTimes = [0.0, 0.2, 0.6, 1.0]
        
        // SceneKit doesn't easily map CAAnimations to particle color over life dynamically without complex modifiers,
        // but we can set basic properties for smoke-like behavior.
        particleSystem.particleColor = PlatformColor.orange
        
        let explosionNode = SCNNode()
        explosionNode.position = position
        explosionNode.addParticleSystem(particleSystem)
        
        scene.rootNode.addChildNode(explosionNode)
        
        // Remove after particles die
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            explosionNode.removeFromParentNode()
        }
    }
}
