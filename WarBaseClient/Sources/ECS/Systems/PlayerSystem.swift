
import SceneKit
import Foundation

public class PlayerSystem {
    private weak var scene: SCNScene?
    private weak var view: SCNView?
    private var world: World
    private var viewMaps: ViewMaps
    
    public var localPlayerId: Int = -1
    
    public init(scene: SCNScene?, view: SCNView?, world: World, viewMaps: ViewMaps) {
        self.scene = scene
        self.view = view
        self.world = world
        self.viewMaps = viewMaps
    }
    
    public func initPlayer() {
        let id = world.createEntity()
        localPlayerId = id
        
        let entity = world.entities[id]!
        
        entity.addComponent(Position(x: 0, y: 10, z: 0))
        entity.addComponent(Velocity())
        entity.addComponent(Rotation())
        entity.addComponent(InputState())
        entity.addComponent(PlayerComponentState())
        entity.addComponent(WeaponState())
        entity.addComponent(RecoilState())
        entity.addComponent(SwayState())
        
        // Node
        let node = SCNNode()
        node.position = SCNVector3(0, 10, 0)
        scene?.rootNode.addChildNode(node)
        viewMaps.entityNodes[id] = node
        
        // Physics Body (Capsule: height 1.8m, radius 0.4m, mass 80kg)
        let capsule = SCNCapsule(capRadius: 0.4, height: 1.8)
        let shape = SCNPhysicsShape(geometry: capsule, options: nil)
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: shape)
        physicsBody.mass = 80.0
        physicsBody.allowsResting = false
        physicsBody.angularVelocityFactor = SCNVector3(0, 0, 0) // Keep upright
        physicsBody.friction = 0
        physicsBody.restitution = 0
        node.physicsBody = physicsBody
        viewMaps.entityPhysicsBodies[id] = physicsBody
        
        // Camera
        let camNode = SCNNode()
        camNode.position = SCNVector3(0, 0.6, 0)
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 1000
        camera.fieldOfView = 75
        camNode.camera = camera
        node.addChildNode(camNode)
        
        // We will store the camera in viewMaps, but for parent references we can assume camera node is parent of camera
        viewMaps.entityCameras[id] = camNode
        
        setupInputListeners()
    }
    
    private func setupInputListeners() {
        // Implement keyboard/mouse listeners bridging here based on platform
        // E.g., gesture recognizers, NSEvent/UIEvent
    }
    
    public func update(deltaTime: Float) {
        // Additional player specific updates if needed
    }
}
