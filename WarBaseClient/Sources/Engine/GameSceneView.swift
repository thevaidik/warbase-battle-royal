import SwiftUI
import SceneKit
import Combine

public struct GameSceneView: UIViewRepresentable {
    public let username: String
    public let roomID: String
    public let selectedMap: String
    public let selectedClass: String
    
    // Bindings to sync state with ContentView HUD
    @Binding var health: Int
    @Binding var ammo: Int
    @Binding var isDead: Bool
    
    public init(username: String, roomID: String, selectedMap: String, selectedClass: String, health: Binding<Int>, ammo: Binding<Int>, isDead: Binding<Bool>) {
        self.username = username
        self.roomID = roomID
        self.selectedMap = selectedMap
        self.selectedClass = selectedClass
        self._health = health
        self._ammo = ammo
        self._isDead = isDead
    }
    
    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = false
        scnView.showsStatistics = true
        scnView.backgroundColor = PlatformColor.black
        
        let scene = SCNScene()
        scnView.scene = scene
        
        // Physics Engine Setup
        scene.physicsWorld.gravity = SCNVector3(0, -15.328, 0)
        scene.physicsWorld.speed = 1.0
        
        context.coordinator.setupEngine(scene: scene, view: scnView)
        scnView.delegate = context.coordinator
        
        return scnView
    }
    
    public func updateUIView(_ uiView: SCNView, context: Context) {
        // Sync any state from UI -> Engine if needed
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: GameSceneView
        var world: World!
        var viewMaps: ViewMaps!
        var playerSystem: PlayerSystem!
        var envManager: EnvironmentManager!
        
        // SCNView reference
        weak var scnView: SCNView?
        weak var scene: SCNScene?
        
        var previousTime: TimeInterval = 0
        
        init(_ parent: GameSceneView) {
            self.parent = parent
        }
        
        func setupEngine(scene: SCNScene, view: SCNView) {
            self.scene = scene
            self.scnView = view
            
            self.world = World()
            self.viewMaps = ViewMaps()
            
            // 1. Environment and Lighting
            self.envManager = EnvironmentManager(scene: scene)
            
            let mapChoice = EnvironmentManager.MapChoice(rawValue: parent.selectedMap.lowercased()) ?? .default
            self.envManager.loadMap(choice: mapChoice, progressHandler: { _ in }, completion: {})
            
            // 2. Initialize Player
            self.playerSystem = PlayerSystem(scene: scene, view: view, world: world, viewMaps: viewMaps)
            self.playerSystem.initPlayer()
            
            let localPlayerId = self.playerSystem.localPlayerId
            
            // Assign active camera to view
            if let camNode = viewMaps.entityCameras[localPlayerId] {
                view.pointOfView = camNode
            }
            
            // Equip Weapon (mocking initWeapons)
            let weaponNode: SCNNode
            if parent.selectedClass == "ASSAULT" {
                weaponNode = AK47Builder.build()
                weaponNode.position = SCNVector3(0.3, -0.3, -0.6)
            } else {
                weaponNode = M2010Builder.build()
                weaponNode.position = SCNVector3(0.12, -0.15, -0.25)
            }
            // Attach weapon to camera so it stays in FPS view
            if let camNode = viewMaps.entityCameras[localPlayerId] {
                camNode.addChildNode(weaponNode)
            }
        }
        
        public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            if previousTime == 0 {
                previousTime = time
                return
            }
            let deltaTime = Float(time - previousTime)
            previousTime = time
            
            self.playerSystem.update(deltaTime: deltaTime)
            
            let localPlayerId = self.playerSystem.localPlayerId
            if let playerState = world.entities[localPlayerId]?.getComponent(PlayerComponentState.self) {
                // Example: Sync health
                // DispatchQueue.main.async { self.parent.health = playerState.health }
            }
        }
    }
}
