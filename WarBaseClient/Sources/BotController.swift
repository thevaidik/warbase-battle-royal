import Foundation
import SceneKit

public class BotController {
    public enum State {
        case idle
        case wandering
    }
    
    public struct Bot {
        public let id: String
        public let node: SCNNode
        public var state: State
        public var timer: TimeInterval
        public var targetDirection: Float
        public var currentDirection: Float
        public var walkWeight: CGFloat
        public var idleWeight: CGFloat
    }
    
    public var bots: [Bot] = []
    
    public init(scene: SCNScene) {
        // Create 3 bots at preset positions
        let positions: [SCNVector3] = [
            SCNVector3(x: 5, y: 1.8, z: 5),
            SCNVector3(x: -5, y: 1.8, z: 5),
            SCNVector3(x: 0, y: 1.8, z: -5)
        ]
        
        for (index, pos) in positions.enumerated() {
            let botNode = createBotNode()
            botNode.position = pos
            scene.rootNode.addChildNode(botNode)
            
            let bot = Bot(
                id: "bot_\(index)",
                node: botNode,
                state: .idle,
                timer: Double.random(in: 1...4),
                targetDirection: 0,
                currentDirection: 0,
                walkWeight: 0,
                idleWeight: 1
            )
            bots.append(bot)
        }
    }
    
    private func createBotNode() -> SCNNode {
        let capsule = SCNCapsule(capRadius: 0.4, height: 1.8)
        capsule.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode(geometry: capsule)
        
        // Physics
        let shape = SCNPhysicsShape(geometry: capsule, options: nil)
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)
        body.mass = 80
        body.angularVelocityFactor = SCNVector3(0, 0, 0) // Keep upright
        node.physicsBody = body
        
        return node
    }
    
    public func update(deltaTime: TimeInterval) {
        for i in 0..<bots.count {
            var bot = bots[i]
            
            bot.timer -= deltaTime
            
            if bot.timer <= 0 {
                if bot.state == .idle {
                    bot.state = .wandering
                    bot.timer = Double.random(in: 2...6)
                    bot.targetDirection = Float.random(in: 0...(2 * .pi))
                } else {
                    bot.state = .idle
                    bot.timer = Double.random(in: 1...4)
                }
            }
            
            // Angular interpolation
            let angleDiff = bot.targetDirection - bot.currentDirection
            var normalizedDiff = angleDiff.truncatingRemainder(dividingBy: 2 * .pi)
            if normalizedDiff > .pi { normalizedDiff -= 2 * .pi }
            if normalizedDiff < -.pi { normalizedDiff += 2 * .pi }
            
            bot.currentDirection += normalizedDiff * Float(deltaTime) * 2.0
            bot.node.eulerAngles.y = bot.currentDirection
            
            // Walk speed 2.5 m/s, turn deceleration at >45° (0.785 rad)
            if bot.state == .wandering {
                let turnPenalty = abs(normalizedDiff) > 0.785 ? 0.5 : 1.0
                let speed: Float = 2.5 * Float(turnPenalty)
                
                let dx = sin(bot.currentDirection) * speed
                let dz = cos(bot.currentDirection) * speed
                
                bot.node.physicsBody?.velocity = SCNVector3(dx, bot.node.physicsBody?.velocity.y ?? 0, dz)
                
                bot.walkWeight = min(1.0, bot.walkWeight + CGFloat(deltaTime) * 2.0)
                bot.idleWeight = max(0.0, bot.idleWeight - CGFloat(deltaTime) * 2.0)
            } else {
                bot.node.physicsBody?.velocity = SCNVector3(0, bot.node.physicsBody?.velocity.y ?? 0, 0)
                
                bot.walkWeight = max(0.0, bot.walkWeight - CGFloat(deltaTime) * 2.0)
                bot.idleWeight = min(1.0, bot.idleWeight + CGFloat(deltaTime) * 2.0)
            }
            
            bots[i] = bot
        }
    }
}
