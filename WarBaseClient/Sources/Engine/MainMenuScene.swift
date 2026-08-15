import Foundation
import SceneKit
import SwiftUI

public class MainMenuScene: ObservableObject {
    public let scene: SCNScene
    private var cameraNode: SCNNode
    private var soldierNode: SCNNode?
    
    public init() {
        scene = SCNScene()
        
        // ArcRotate camera with auto-orbit
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 1.5, 4)
        
        let lookAtNode = SCNNode()
        lookAtNode.position = SCNVector3(0, 1.0, 0)
        scene.rootNode.addChildNode(lookAtNode)
        
        let constraint = SCNLookAtConstraint(target: lookAtNode)
        cameraNode.constraints = [constraint]
        
        let orbitNode = SCNNode()
        orbitNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(orbitNode)
        
        let orbitAction = SCNAction.rotateBy(x: 0, y: CGFloat(2 * Float.pi), z: 0, duration: 20.0)
        orbitNode.runAction(SCNAction.repeatForever(orbitAction))
        
        setupLighting()
        setupPedestal()
        loadSoldier()
    }
    
    private func setupLighting() {
        // Cyberpunk lighting (red main + blue rim spotlights)
        let redLight = SCNNode()
        redLight.light = SCNLight()
        redLight.light?.type = .spot
        redLight.light?.color = UIColor.red
        redLight.light?.intensity = 2000
        redLight.position = SCNVector3(2, 3, 2)
        redLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(redLight)
        
        let blueLight = SCNNode()
        blueLight.light = SCNLight()
        blueLight.light?.type = .spot
        blueLight.light?.color = UIColor.blue
        blueLight.light?.intensity = 1500
        blueLight.position = SCNVector3(-2, 2, -3)
        blueLight.look(at: SCNVector3(0, 1, 0))
        scene.rootNode.addChildNode(blueLight)
        
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 100
        scene.rootNode.addChildNode(ambient)
    }
    
    private func setupPedestal() {
        // Reflective ground pedestal
        let cylinder = SCNCylinder(radius: 1.5, height: 0.1)
        cylinder.firstMaterial?.lightingModel = .physicallyBased
        cylinder.firstMaterial?.diffuse.contents = UIColor.darkGray
        cylinder.firstMaterial?.metalness.contents = 0.9
        cylinder.firstMaterial?.roughness.contents = 0.1
        
        let pedestalNode = SCNNode(geometry: cylinder)
        pedestalNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(pedestalNode)
    }
    
    private func loadSoldier() {
        // AnimatedSoldier loading with weapon attachment
        let capsule = SCNCapsule(capRadius: 0.3, height: 1.8)
        capsule.firstMaterial?.diffuse.contents = UIColor.gray
        
        soldierNode = SCNNode(geometry: capsule)
        soldierNode?.position = SCNVector3(0, 0.9, 0)
        
        if let soldierNode = soldierNode {
            scene.rootNode.addChildNode(soldierNode)
        }
    }
    
    public func setHeldWeapon(weaponId: String) {
        // setHeldWeapon toggle logic
        guard let soldierNode = soldierNode else { return }
        
        soldierNode.childNodes.forEach { $0.removeFromParentNode() }
        
        let weaponGeo = SCNBox(width: 0.1, height: 0.2, length: 0.8, chamferRadius: 0)
        weaponGeo.firstMaterial?.diffuse.contents = UIColor.black
        let weaponNode = SCNNode(geometry: weaponGeo)
        weaponNode.position = SCNVector3(0.4, 0, 0.4) // Attach to hand approximation
        
        soldierNode.addChildNode(weaponNode)
    }
}
