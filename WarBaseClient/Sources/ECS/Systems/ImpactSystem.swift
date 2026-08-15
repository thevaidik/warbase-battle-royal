
import SceneKit
import Foundation

public class ImpactSystem {
    private weak var scene: SCNScene?
    
    private let particleSystem: SCNParticleSystem
    
    public init(scene: SCNScene?) {
        self.scene = scene
        
        particleSystem = SCNParticleSystem()
        particleSystem.birthRate = 0
        particleSystem.particleLifeSpan = 0.5
        particleSystem.particleSize = 0.1
        particleSystem.particleSizeVariation = 0.05
        particleSystem.particleVelocity = 2.0
        particleSystem.particleVelocityVariation = 1.0
        particleSystem.particleColor = PlatformColor.gray
        particleSystem.emitterShape = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0)
        particleSystem.spreadingAngle = 45
        
        let emitterNode = SCNNode()
        emitterNode.addParticleSystem(particleSystem)
        scene?.rootNode.addChildNode(emitterNode)
    }
    
    public func spawnImpact(position: SCNVector3, normal: SCNVector3) {
        let node = SCNNode()
        node.position = position
        
        let burst = particleSystem.copy() as! SCNParticleSystem
        burst.birthRate = 200 // Set high momentarily, or use birthDirection/burst count
        burst.emissionDuration = 0.1
        burst.loops = false
        
        node.addParticleSystem(burst)
        scene?.rootNode.addChildNode(node)
        
        // Cleanup node after particles die
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            node.removeFromParentNode()
        }
    }
}
