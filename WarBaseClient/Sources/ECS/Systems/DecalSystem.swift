
import SceneKit
import Foundation

public class DecalSystem {
    private let MAX_DECALS = 50
    private var decals: [SCNNode] = []
    private var currentIndex = 0
    private weak var scene: SCNScene?
    
    private var decalMaterial: SCNMaterial
    
    public init(scene: SCNScene?) {
        self.scene = scene
        
        decalMaterial = SCNMaterial()
        decalMaterial.diffuse.contents = PlatformColor.black // Replace with bullet hole texture
        decalMaterial.isDoubleSided = true
        decalMaterial.lightingModel = .physicallyBased
        
        for _ in 0..<MAX_DECALS {
            let plane = SCNPlane(width: 0.2, height: 0.2)
            plane.materials = [decalMaterial]
            let node = SCNNode(geometry: plane)
            node.isHidden = true
            scene?.rootNode.addChildNode(node)
            decals.append(node)
        }
    }
    
    public func spawnDecal(position: SCNVector3, normal: SCNVector3) {
        let node = decals[currentIndex]
        node.isHidden = false
        node.position = position + (normal * 0.001) // slight offset to prevent Z-fighting
        
        // Look at along normal
        let up = SCNVector3(0, 1, 0)
        let isCollinear = abs(normal.y) > 0.99
        let right = isCollinear ? SCNVector3(1, 0, 0) : SCNVector3(
            up.y * normal.z - up.z * normal.y,
            up.z * normal.x - up.x * normal.z,
            up.x * normal.y - up.y * normal.x
        )
        
        node.simdLook(at: simd_float3(Float(position.x + normal.x), Float(position.y + normal.y), Float(position.z + normal.z)),
                      up: simd_float3(Float(right.x), Float(right.y), Float(right.z)),
                      localFront: simd_float3(0, 0, 1))
        
        currentIndex = (currentIndex + 1) % MAX_DECALS
    }
}

// Helper extension for SCNVector3 math
func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3(left.x + right.x, left.y + right.y, left.z + right.z)
}
func *(vector: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3(Float(vector.x) * scalar, Float(vector.y) * scalar, Float(vector.z) * scalar)
}
