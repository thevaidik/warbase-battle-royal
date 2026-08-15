import Foundation
import SceneKit

public class EnvironmentManager {
    public enum MapChoice: String {
        case industrial = "industrial"
        case village = "village"
        case arena = "arena"
        case ghost_city = "ghost_city"
        case `default`
    }
    
    private var scene: SCNScene
    private var loadedMapNode: SCNNode?
    public var spawnBounds: (min: SCNVector3, max: SCNVector3) = (SCNVector3Zero, SCNVector3Zero)
    
    public init(scene: SCNScene) {
        self.scene = scene
    }
    
    public func loadMap(choice: MapChoice, progressHandler: @escaping (Float) -> Void, completion: @escaping () -> Void) {
        progressHandler(0.1)
        
        let mapName = choice == .default ? "industrial" : choice.rawValue
        
        guard let url = Bundle.main.url(forResource: mapName, withExtension: "usdz"),
              let referenceNode = SCNReferenceNode(url: url) else {
            print("Failed to find map: \(mapName).usdz in bundle.")
            progressHandler(1.0)
            completion()
            return
        }
        
        referenceNode.load()
        loadedMapNode?.removeFromParentNode()
        loadedMapNode = referenceNode
        
        progressHandler(0.4)
        
        // Strip embedded cameras/lights and enable shadows
        let directionalLight = createDirectionalLight()
        scene.rootNode.addChildNode(directionalLight)
        
        referenceNode.enumerateChildNodes { node, _ in
            if node.camera != nil {
                node.removeFromParentNode()
            }
            if node.light != nil {
                node.removeFromParentNode()
            }
            if let geometry = node.geometry {
                node.castsShadow = true
                for material in geometry.materials {
                    material.lightingModel = .physicallyBased
                    if choice == .village {
                        material.roughness.contents = 0.95
                        material.metalness.contents = 0.0
                    }
                }
            }
        }
        
        progressHandler(0.7)
        scene.rootNode.addChildNode(referenceNode)
        
        setupPhysics(rootNode: referenceNode)
        calculateSpawnBounds(rootNode: referenceNode)
        
        progressHandler(1.0)
        completion()
    }
    
    private func createDirectionalLight() -> SCNNode {
        let lightNode = SCNNode()
        let light = SCNLight()
        light.type = .directional
        light.intensity = 1500
        light.castsShadow = true
        light.shadowMode = .deferred
        light.shadowSampleCount = 4
        light.shadowMapSize = CGSize(width: 2048, height: 2048)
        
        lightNode.light = light
        lightNode.position = SCNVector3(x: -10, y: 30, z: -10)
        lightNode.look(at: SCNVector3(0, 0, 0))
        return lightNode
    }
    
    private func setupPhysics(rootNode: SCNNode) {
        rootNode.enumerateChildNodes { node, _ in
            if let geometry = node.geometry {
                // Using concavePolyhedron for static mesh accurate collisions
                let shape = SCNPhysicsShape(geometry: geometry, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron])
                node.physicsBody = SCNPhysicsBody(type: .static, shape: shape)
                node.physicsBody?.categoryBitMask = 1 // Environment category
            }
        }
    }
    
    private func calculateSpawnBounds(rootNode: SCNNode) {
        let (min, max) = rootNode.boundingBox
        
        // Shrink the spawn bounds slightly to prevent spawning inside walls
        let margin: Float = 2.0
        self.spawnBounds = (
            min: SCNVector3(min.x + margin, min.y, min.z + margin),
            max: SCNVector3(max.x - margin, max.y + 10.0, max.z - margin)
        )
    }
    
    public func getRandomSpawnPoint() -> SCNVector3 {
        let x = Float.random(in: spawnBounds.min.x...spawnBounds.max.x)
        let z = Float.random(in: spawnBounds.min.z...spawnBounds.max.z)
        let y = spawnBounds.max.y // Spawn high, let physics drop them, or do raycast
        
        let origin = SCNVector3(x, y, z)
        let dest = SCNVector3(x, spawnBounds.min.y - 10, z)
        
        let hits = scene.physicsWorld.rayTestWithSegment(from: origin, to: dest, options: [.searchMode: SCNPhysicsWorld.TestSearchMode.closest.rawValue])
        if let firstHit = hits.first {
            return SCNVector3(firstHit.worldCoordinates.x, firstHit.worldCoordinates.y + 1.5, firstHit.worldCoordinates.z)
        }
        
        return SCNVector3(0, 5, 0)
    }
}
