import SceneKit
import Foundation

public class PhysicsSystem {
    public init() {}
    
    public func update(deltaTime: Float, world: World, viewMaps: ViewMaps) {
        for (id, entity) in world.entities {
            if let node = viewMaps.entityNodes[id], let _ = viewMaps.entityPhysicsBodies[id] {
                // Sync Physics Node Position back to ECS
                let pos = node.position
                let vel = node.physicsBody?.velocity ?? SCNVector3Zero
                
                entity.addComponent(Position(x: Float(pos.x), y: Float(pos.y), z: Float(pos.z)))
                entity.addComponent(Velocity(x: Float(vel.x), y: Float(vel.y), z: Float(vel.z)))
            }
        }
    }
}
