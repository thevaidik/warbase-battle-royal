import SwiftUI
import SceneKit

public struct WeaponPreview3D: UIViewRepresentable {
    public var weaponName: String
    
    public init(weaponName: String) {
        self.weaponName = weaponName
    }
    
    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false
        scnView.backgroundColor = UIColor.clear
        
        let scene = SCNScene()
        scnView.scene = scene
        
        // Studio lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500
        scene.rootNode.addChildNode(ambientLight)
        
        let dirLight = SCNNode()
        dirLight.light = SCNLight()
        dirLight.light?.type = .directional
        dirLight.light?.intensity = 1000
        dirLight.light?.temperature = 5500
        dirLight.eulerAngles = SCNVector3(x: -.pi/4, y: -.pi/4, z: 0)
        scene.rootNode.addChildNode(dirLight)
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 5)
        scene.rootNode.addChildNode(cameraNode)
        
        // Auto-rotation
        let rotationAction = SCNAction.rotateBy(x: 0, y: 0.008, z: 0, duration: 1.0 / 60.0)
        let repeatAction = SCNAction.repeatForever(rotationAction)
        
        let weaponNode = SCNNode()
        weaponNode.name = "Weapon"
        scene.rootNode.addChildNode(weaponNode)
        weaponNode.runAction(repeatAction)
        
        updateWeapon(in: scene, with: weaponName)
        
        return scnView
    }
    
    public func updateUIView(_ uiView: SCNView, context: Context) {
        guard let scene = uiView.scene else { return }
        updateWeapon(in: scene, with: weaponName)
    }
    
    private func updateWeapon(in scene: SCNScene, with name: String) {
        guard let weaponNode = scene.rootNode.childNode(withName: "Weapon", recursively: false) else { return }
        weaponNode.childNodes.forEach { $0.removeFromParentNode() }
        
        // Load weapon mesh (mock)
        let geometry: SCNGeometry
        let scale: Float
        
        switch name.lowercased() {
        case "m2010":
            geometry = SCNBox(width: 0.2, height: 0.5, length: 2.5, chamferRadius: 0.05)
            scale = 1.0
        case "pistol":
            geometry = SCNBox(width: 0.1, height: 0.4, length: 0.6, chamferRadius: 0.02)
            scale = 1.5
        default: // ak47
            geometry = SCNBox(width: 0.15, height: 0.4, length: 2.0, chamferRadius: 0.05)
            scale = 1.2
        }
        
        geometry.firstMaterial?.diffuse.contents = UIColor.darkGray
        geometry.firstMaterial?.metalness.contents = 0.8
        geometry.firstMaterial?.roughness.contents = 0.2
        
        let meshNode = SCNNode(geometry: geometry)
        meshNode.scale = SCNVector3(scale, scale, scale)
        weaponNode.addChildNode(meshNode)
    }
}
