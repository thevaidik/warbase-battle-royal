import Foundation
import SceneKit


public class PistolBuilder {
    public static func build() -> SCNNode {
        let pistolNode = SCNNode()
        pistolNode.name = "Pistol"
        
        let scale: Float = 0.08
        pistolNode.scale = SCNVector3(scale, scale, scale)
        
        // Materials
        let polymerMat = SCNMaterial()
        polymerMat.lightingModel = .physicallyBased
        polymerMat.diffuse.contents = PlatformColor(white: 0.15, alpha: 1.0)
        polymerMat.roughness.contents = NSNumber(value: 0.8)
        polymerMat.metalness.contents = NSNumber(value: 0.2)
        
        let slideMat = SCNMaterial()
        slideMat.lightingModel = .physicallyBased
        slideMat.diffuse.contents = PlatformColor(white: 0.25, alpha: 1.0)
        slideMat.roughness.contents = NSNumber(value: 0.5)
        slideMat.metalness.contents = NSNumber(value: 0.8)
        
        let barrelMat = SCNMaterial()
        barrelMat.lightingModel = .physicallyBased
        barrelMat.diffuse.contents = PlatformColor(white: 0.1, alpha: 1.0)
        barrelMat.roughness.contents = NSNumber(value: 0.3)
        barrelMat.metalness.contents = NSNumber(value: 0.9)
        
        // Grip / Frame
        let gripGeom = SCNBox(width: 0.3, height: 1.2, length: 0.45, chamferRadius: 0.05)
        gripGeom.materials = [polymerMat]
        let grip = SCNNode(geometry: gripGeom)
        grip.position = SCNVector3(0, -0.6, 0)
        grip.eulerAngles = SCNVector3(Float.pi * 0.1, 0, 0) // Slight angle
        pistolNode.addChildNode(grip)
        
        // Mag plate
        let magPlateGeom = SCNBox(width: 0.32, height: 0.1, length: 0.5, chamferRadius: 0.02)
        magPlateGeom.materials = [polymerMat]
        let magPlate = SCNNode(geometry: magPlateGeom)
        magPlate.position = SCNVector3(0, -1.2, 0.05)
        pistolNode.addChildNode(magPlate)
        
        // Frame top
        let frameGeom = SCNBox(width: 0.35, height: 0.3, length: 1.8, chamferRadius: 0.02)
        frameGeom.materials = [polymerMat]
        let frame = SCNNode(geometry: frameGeom)
        frame.position = SCNVector3(0, 0.15, 0.6)
        pistolNode.addChildNode(frame)
        
        // Slide
        let slideGeom = SCNBox(width: 0.36, height: 0.35, length: 1.85, chamferRadius: 0.03)
        slideGeom.materials = [slideMat]
        let slide = SCNNode(geometry: slideGeom)
        slide.position = SCNVector3(0, 0.45, 0.6)
        pistolNode.addChildNode(slide)
        
        // Barrel
        let barrelGeom = SCNCylinder(radius: 0.08, height: 1.9)
        barrelGeom.materials = [barrelMat]
        let barrel = SCNNode(geometry: barrelGeom)
        barrel.position = SCNVector3(0, 0.4, 0.65)
        barrel.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        pistolNode.addChildNode(barrel)
        
        // Trigger Guard
        let tgGeom = SCNTube(innerRadius: 0.2, outerRadius: 0.25, height: 0.1)
        tgGeom.materials = [polymerMat]
        let triggerGuard = SCNNode(geometry: tgGeom)
        triggerGuard.position = SCNVector3(0, -0.1, 0.6)
        triggerGuard.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
        pistolNode.addChildNode(triggerGuard)
        
        // Trigger
        let triggerGeom = SCNBox(width: 0.08, height: 0.2, length: 0.05, chamferRadius: 0.01)
        triggerGeom.materials = [slideMat]
        let trigger = SCNNode(geometry: triggerGeom)
        trigger.position = SCNVector3(0, -0.05, 0.5)
        trigger.eulerAngles = SCNVector3(Float.pi * 0.1, 0, 0)
        pistolNode.addChildNode(trigger)
        
        // Sights
        let rearSightGeom = SCNBox(width: 0.15, height: 0.1, length: 0.1, chamferRadius: 0.01)
        rearSightGeom.materials = [polymerMat]
        let rearSight = SCNNode(geometry: rearSightGeom)
        rearSight.position = SCNVector3(0, 0.65, -0.2)
        pistolNode.addChildNode(rearSight)
        
        let frontSightGeom = SCNBox(width: 0.05, height: 0.08, length: 0.1, chamferRadius: 0.01)
        frontSightGeom.materials = [polymerMat]
        let frontSight = SCNNode(geometry: frontSightGeom)
        frontSight.position = SCNVector3(0, 0.65, 1.4)
        pistolNode.addChildNode(frontSight)
        
        return pistolNode
    }
}
