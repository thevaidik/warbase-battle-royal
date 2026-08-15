import Foundation
import SceneKit

public struct RemotePlayer {
    public var mesh: SCNNode
    public var stateBuffer: [(time: TimeInterval, state: NetworkPlayerState)]
    public var weapons: [String: SCNNode]
    public var muzzlePoints: [String: SCNNode]
    public var health: Float
    public var isDead: Bool
}

public class MultiplayerEntities {
    private var scene: SCNScene
    public var players: [String: RemotePlayer] = [:]
    
    private let RENDER_DELAY: TimeInterval = 0.035 // 35ms interpolation buffer
    
    public init(scene: SCNScene) {
        self.scene = scene
    }
    
    public func spawnPlayer(id: String, state: NetworkPlayerState) {
        let node = SCNNode()
        node.name = "player_\(id)"
        
        // Load USDZ model
        if let url = Bundle.main.url(forResource: "AnimatedSoldier", withExtension: "usdz"),
           let referenceNode = SCNReferenceNode(url: url) {
            referenceNode.load()
            node.addChildNode(referenceNode)
            
            // Attach hitboxes to bones if skeleton exists
            attachHitboxesToBones(in: referenceNode, playerId: id)
        } else {
            // Fallback mock hitboxes
            let hitboxNodes = createHitboxes(playerId: id)
            for hb in hitboxNodes { node.addChildNode(hb) }
        }
        
        node.position = SCNVector3(state.x, state.y, state.z)
        node.orientation = SCNVector4(state.rx, state.ry, state.rz, state.rw)
        
        scene.rootNode.addChildNode(node)
        players[id] = RemotePlayer(
            mesh: node,
            stateBuffer: [(time: Date().timeIntervalSince1970, state: state)],
            weapons: [:],
            muzzlePoints: [:],
            health: state.health,
            isDead: state.isDead
        )
    }
    
    private func attachHitboxesToBones(in rootNode: SCNNode, playerId: String) {
        // Recursive search for bones and attach scaled SCNCapsule/SCNBox
        // This simulates the 10-bone precise hitbox system
        rootNode.enumerateChildNodes { child, _ in
            if let name = child.name?.lowercased() {
                var size: SCNVector3?
                var mult: Float = 1.0
                var shape: SCNGeometry?
                
                if name.contains("head") {
                    shape = SCNBox(width: 0.2, height: 0.25, length: 0.2, chamferRadius: 0)
                    mult = 2.5
                } else if name.contains("spine") || name.contains("torso") {
                    shape = SCNBox(width: 0.4, height: 0.6, length: 0.25, chamferRadius: 0)
                    mult = 1.0
                } else if name.contains("arm") {
                    shape = SCNCapsule(capRadius: 0.08, height: 0.4)
                    mult = 0.8
                } else if name.contains("leg") || name.contains("calf") || name.contains("thigh") {
                    shape = SCNCapsule(capRadius: 0.1, height: 0.5)
                    mult = 0.6
                }
                
                if let geo = shape {
                    let hitbox = SCNNode(geometry: geo)
                    hitbox.name = "hitbox_\(playerId)"
                    // Mock metadata since SceneKit doesn't have custom metadata dictionary by default
                    // We encode the multiplier in the name for WeaponSystem to parse, or we can just rely on bone names
                    hitbox.name = "hitbox_\(playerId)_\(mult)"
                    hitbox.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: geo, options: nil))
                    hitbox.physicsBody?.categoryBitMask = 2 // Enemy player category
                    child.addChildNode(hitbox)
                }
            }
        }
    }
    
    public func removePlayer(id: String) {
        players[id]?.mesh.removeFromParentNode()
        players.removeValue(forKey: id)
    }
    
    public func updateNetworkState(gameState: GameStateData) {
        let now = Date().timeIntervalSince1970
        
        for (id, state) in gameState.players {
            if players[id] == nil {
                spawnPlayer(id: id, state: state)
            } else {
                players[id]?.stateBuffer.append((time: now, state: state))
                // Keep buffer size manageable
                if players[id]!.stateBuffer.count > 10 {
                    players[id]!.stateBuffer.removeFirst(players[id]!.stateBuffer.count - 10)
                }
            }
        }
        
        // Remove disconnected
        for id in players.keys {
            if gameState.players[id] == nil {
                removePlayer(id: id)
            }
        }
    }
    
    public func interpolateEntities(currentTime: TimeInterval) {
        let renderTime = Date().timeIntervalSince1970 - RENDER_DELAY
        
        for (id, player) in players {
            let buffer = player.stateBuffer
            guard buffer.count >= 2 else { continue }
            
            // Find the two states bounding the renderTime
            var index = 0
            while index < buffer.count - 1 && buffer[index + 1].time < renderTime {
                index += 1
            }
            
            if index < buffer.count - 1 {
                let s1 = buffer[index]
                let s2 = buffer[index + 1]
                let t = Float((renderTime - s1.time) / (s2.time - s1.time))
                
                let p1 = SCNVector3(s1.state.x, s1.state.y, s1.state.z)
                let p2 = SCNVector3(s2.state.x, s2.state.y, s2.state.z)
                
                let r1 = SCNQuaternion(s1.state.rx, s1.state.ry, s1.state.rz, s1.state.rw)
                let r2 = SCNQuaternion(s2.state.rx, s2.state.ry, s2.state.rz, s2.state.rw)
                
                // Lerp Position
                let lerpPos = SCNVector3(
                    p1.x + (p2.x - p1.x) * t,
                    p1.y + (p2.y - p1.y) * t,
                    p1.z + (p2.z - p1.z) * t
                )
                
                // Slerp Rotation
                let dot = r1.x*r2.x + r1.y*r2.y + r1.z*r2.z + r1.w*r2.w
                var r3 = r2
                if dot < 0 {
                    r3 = SCNQuaternion(-r2.x, -r2.y, -r2.z, -r2.w)
                }
                
                let slerpRot = SCNQuaternion(
                    r1.x + (r3.x - r1.x) * t,
                    r1.y + (r3.y - r1.y) * t,
                    r1.z + (r3.z - r1.z) * t,
                    r1.w + (r3.w - r1.w) * t
                )
                
                player.mesh.position = lerpPos
                player.mesh.orientation = slerpRot
            }
        }
    }
    
    public func triggerFire(id: String) {
        guard let mesh = players[id]?.mesh else { return }
        // Create muzzle flash relative to enemy weapon
        let flash = SCNNode(geometry: SCNSphere(radius: 0.1))
        flash.geometry?.firstMaterial?.diffuse.contents = PlatformColor.yellow
        flash.position = SCNVector3(0, 1.0, 0.5) // Approximate weapon pos
        mesh.addChildNode(flash)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            flash.removeFromParentNode()
        }
    }
    
    private func createHitboxes(playerId: String) -> [SCNNode] {
        var hitboxes: [SCNNode] = []
        
        let head = SCNBox(width: 0.2, height: 0.25, length: 0.2, chamferRadius: 0)
        let headNode = SCNNode(geometry: head)
        headNode.name = "hitbox_\(playerId)_2.5"
        headNode.position = SCNVector3(0, 1.7, 0)
        headNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: head, options: nil))
        hitboxes.append(headNode)
        
        let torso = SCNBox(width: 0.4, height: 0.6, length: 0.25, chamferRadius: 0)
        let torsoNode = SCNNode(geometry: torso)
        torsoNode.name = "hitbox_\(playerId)_1.0"
        torsoNode.position = SCNVector3(0, 1.2, 0)
        torsoNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: torso, options: nil))
        hitboxes.append(torsoNode)
        
        return hitboxes
    }
    
    public func triggerRagdoll(id: String, forceDirection: SCNVector3) {
        guard let player = players[id] else { return }
        
        // Convert to dynamic and apply impulse
        player.mesh.enumerateChildNodes { child, _ in
            if child.name?.starts(with: "hitbox") == true {
                child.physicsBody?.type = .dynamic
                child.physicsBody?.applyForce(forceDirection, asImpulse: true)
                
                // Add ball and socket constraints between dynamic bodies to simulate ragdoll
                // Assuming child.parent has a physics body (in a full skeleton)
                if let parent = child.parent, let parentBody = parent.physicsBody, parentBody.type == .dynamic {
                    let joint = SCNPhysicsBallSocketJoint(bodyA: child.physicsBody!, anchorA: SCNVector3Zero, bodyB: parentBody, anchorB: SCNVector3Zero)
                    scene.physicsWorld.addBehavior(joint)
                }
            }
        }
    }
}
