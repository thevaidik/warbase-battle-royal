import SceneKit
import Foundation

public class ViewMaps {
    public var entityNodes: [Int: SCNNode] = [:]
    public var entityPhysicsBodies: [Int: SCNPhysicsBody] = [:]
    public var entityCameras: [Int: SCNNode] = [:]
    
    public var entitySwayRoots: [Int: SCNNode] = [:]
    public var entityWeaponSocketOffsets: [Int: SCNNode] = [:]
    
    public var entityAKRoots: [Int: SCNNode] = [:]
    public var entityPistolRoots: [Int: SCNNode] = [:]
    public var entityM2010Roots: [Int: SCNNode] = [:]
    
    public var entityAimPoints: [Int: SCNNode] = [:]
    
    public var entityFlashParticles: [Int: SCNParticleSystem] = [:]
    public var entityShellParticles: [Int: SCNParticleSystem] = [:]
    
    public init() {}
    
    public func clearAll() {
        entityNodes.removeAll()
        entityPhysicsBodies.removeAll()
        entityCameras.removeAll()
        entitySwayRoots.removeAll()
        entityWeaponSocketOffsets.removeAll()
        entityAKRoots.removeAll()
        entityPistolRoots.removeAll()
        entityM2010Roots.removeAll()
        entityAimPoints.removeAll()
        entityFlashParticles.removeAll()
        entityShellParticles.removeAll()
    }
}
