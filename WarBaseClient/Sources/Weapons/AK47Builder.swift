import Foundation
import SceneKit


public class AK47Builder {
    public static func build() -> SCNNode {
        let akNode = SCNNode()
        akNode.name = "AK-47"
        
        let scale: Float = 0.08
        akNode.scale = SCNVector3(scale, scale, scale)
        
        // Materials
        let darkSteelMat = SCNMaterial()
        darkSteelMat.lightingModel = .physicallyBased
        darkSteelMat.diffuse.contents = PlatformColor(white: 0.15, alpha: 1.0)
        darkSteelMat.roughness.contents = NSNumber(value: 0.5)
        darkSteelMat.metalness.contents = NSNumber(value: 0.9)
        
        let metalMat = SCNMaterial()
        metalMat.lightingModel = .physicallyBased
        metalMat.diffuse.contents = PlatformColor(white: 0.25, alpha: 1.0)
        metalMat.roughness.contents = NSNumber(value: 0.4)
        metalMat.metalness.contents = NSNumber(value: 0.8)
        
        let woodMat = SCNMaterial()
        woodMat.lightingModel = .physicallyBased
        woodMat.diffuse.contents = PlatformColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
        woodMat.roughness.contents = NSNumber(value: 0.7)
        woodMat.metalness.contents = NSNumber(value: 0.0)
        
        let magMat = SCNMaterial()
        magMat.lightingModel = .physicallyBased
        magMat.diffuse.contents = PlatformColor(white: 0.1, alpha: 1.0)
        magMat.roughness.contents = NSNumber(value: 0.6)
        magMat.metalness.contents = NSNumber(value: 0.5)
        
        let glassMat = SCNMaterial()
        glassMat.lightingModel = .physicallyBased
        glassMat.diffuse.contents = PlatformColor(white: 1.0, alpha: 0.3)
        glassMat.roughness.contents = NSNumber(value: 0.1)
        glassMat.metalness.contents = NSNumber(value: 0.9)
        glassMat.isDoubleSided = true
        
        let reticleMat = SCNMaterial()
        reticleMat.lightingModel = .constant
        reticleMat.diffuse.contents = PlatformColor.red
        
        // Receiver
        let receiverGeom = SCNBox(width: 0.35, height: 0.45, length: 2.2, chamferRadius: 0.02)
        receiverGeom.materials = [darkSteelMat]
        let receiver = SCNNode(geometry: receiverGeom)
        akNode.addChildNode(receiver)
        
        // Dust Cover
        let dustCoverGeom = SCNCylinder(radius: 0.18, height: 2.2)
        dustCoverGeom.materials = [darkSteelMat]
        let dustCover = SCNNode(geometry: dustCoverGeom)
        dustCover.position = SCNVector3(0, 0.2, 0)
        dustCover.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        akNode.addChildNode(dustCover)
        
        // Bolt Carrier
        let boltGeom = SCNBox(width: 0.15, height: 0.15, length: 0.8, chamferRadius: 0.0)
        boltGeom.materials = [metalMat]
        let bolt = SCNNode(geometry: boltGeom)
        bolt.position = SCNVector3(0.12, 0.1, 0.2)
        akNode.addChildNode(bolt)
        
        let chargeHandleGeom = SCNCylinder(radius: 0.05, height: 0.2)
        chargeHandleGeom.materials = [metalMat]
        let chargeHandle = SCNNode(geometry: chargeHandleGeom)
        chargeHandle.position = SCNVector3(0.25, 0.1, 0.5)
        chargeHandle.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        akNode.addChildNode(chargeHandle)
        
        // Selector Lever
        let selectorGeom = SCNBox(width: 0.05, height: 0.1, length: 0.6, chamferRadius: 0.0)
        selectorGeom.materials = [darkSteelMat]
        let selector = SCNNode(geometry: selectorGeom)
        selector.position = SCNVector3(0.18, 0, -0.2)
        selector.eulerAngles = SCNVector3(Float.pi * 0.05, 0, 0)
        akNode.addChildNode(selector)
        
        // Stock
        let stockGeom = SCNBox(width: 0.3, height: 0.5, length: 1.8, chamferRadius: 0.05)
        stockGeom.materials = [woodMat]
        let stock = SCNNode(geometry: stockGeom)
        stock.position = SCNVector3(0, -0.2, -1.8)
        stock.eulerAngles = SCNVector3(Float.pi * 0.05, 0, 0)
        akNode.addChildNode(stock)
        
        let buttPlateGeom = SCNBox(width: 0.32, height: 0.55, length: 0.1, chamferRadius: 0.0)
        buttPlateGeom.materials = [darkSteelMat]
        let buttPlate = SCNNode(geometry: buttPlateGeom)
        buttPlate.position = SCNVector3(0, -0.25, -2.7)
        buttPlate.eulerAngles = SCNVector3(Float.pi * 0.05, 0, 0)
        akNode.addChildNode(buttPlate)
        
        // Grip
        let gripGeom = SCNBox(width: 0.25, height: 0.8, length: 0.4, chamferRadius: 0.05)
        gripGeom.materials = [woodMat]
        let grip = SCNNode(geometry: gripGeom)
        grip.position = SCNVector3(0, -0.6, -0.8)
        grip.eulerAngles = SCNVector3(Float.pi * 0.15, 0, 0)
        akNode.addChildNode(grip)
        
        // Trigger & Guard
        let triggerGuardGeom = SCNTube(innerRadius: 0.2, outerRadius: 0.25, height: 0.1)
        triggerGuardGeom.materials = [darkSteelMat]
        let triggerGuard = SCNNode(geometry: triggerGuardGeom)
        triggerGuard.position = SCNVector3(0, -0.3, -0.3)
        triggerGuard.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
        akNode.addChildNode(triggerGuard)
        
        let triggerGeom = SCNBox(width: 0.08, height: 0.2, length: 0.05, chamferRadius: 0.01)
        triggerGeom.materials = [metalMat]
        let trigger = SCNNode(geometry: triggerGeom)
        trigger.position = SCNVector3(0, -0.3, -0.4)
        akNode.addChildNode(trigger)
        
        // Magazine
        let magBaseGeom = SCNBox(width: 0.28, height: 1.2, length: 0.6, chamferRadius: 0.05)
        magBaseGeom.materials = [magMat]
        let magBase = SCNNode(geometry: magBaseGeom)
        magBase.position = SCNVector3(0, -0.8, 0.4)
        magBase.eulerAngles = SCNVector3(-Float.pi * 0.1, 0, 0)
        akNode.addChildNode(magBase)
        
        // Mag ribs
        for i in 0..<4 {
            let ribGeom = SCNBox(width: 0.3, height: 0.1, length: 0.5, chamferRadius: 0)
            ribGeom.materials = [magMat]
            let rib = SCNNode(geometry: ribGeom)
            rib.position = SCNVector3(0, -0.4 - Float(i) * 0.2, 0.42 + Float(i) * 0.04)
            rib.eulerAngles = SCNVector3(-Float.pi * 0.1, 0, 0)
            akNode.addChildNode(rib)
        }
        
        // Barrel Assembly
        let barrelGroup = SCNNode()
        barrelGroup.position = SCNVector3(0, 0.05, 1.1)
        
        let barrelGeom = SCNCylinder(radius: 0.08, height: 3.0)
        barrelGeom.materials = [darkSteelMat]
        let barrel = SCNNode(geometry: barrelGeom)
        barrel.position = SCNVector3(0, 0, 1.5)
        barrel.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        barrelGroup.addChildNode(barrel)
        
        let muzzleGeom = SCNCylinder(radius: 0.1, height: 0.4)
        muzzleGeom.materials = [darkSteelMat]
        let muzzle = SCNNode(geometry: muzzleGeom)
        muzzle.position = SCNVector3(0, 0, 3.2)
        muzzle.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        barrelGroup.addChildNode(muzzle)
        
        let gasTubeGeom = SCNCylinder(radius: 0.06, height: 1.5)
        gasTubeGeom.materials = [darkSteelMat]
        let gasTube = SCNNode(geometry: gasTubeGeom)
        gasTube.position = SCNVector3(0, 0.15, 0.75)
        gasTube.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        barrelGroup.addChildNode(gasTube)
        
        let gasBlockGeom = SCNBox(width: 0.15, height: 0.25, length: 0.3, chamferRadius: 0)
        gasBlockGeom.materials = [darkSteelMat]
        let gasBlock = SCNNode(geometry: gasBlockGeom)
        gasBlock.position = SCNVector3(0, 0.08, 1.6)
        barrelGroup.addChildNode(gasBlock)
        
        // Handguards
        let lowerHgGeom = SCNBox(width: 0.35, height: 0.3, length: 1.2, chamferRadius: 0.05)
        lowerHgGeom.materials = [woodMat]
        let lowerHg = SCNNode(geometry: lowerHgGeom)
        lowerHg.position = SCNVector3(0, -0.1, 0.6)
        barrelGroup.addChildNode(lowerHg)
        
        let upperHgGeom = SCNBox(width: 0.3, height: 0.25, length: 1.0, chamferRadius: 0.05)
        upperHgGeom.materials = [woodMat]
        let upperHg = SCNNode(geometry: upperHgGeom)
        upperHg.position = SCNVector3(0, 0.18, 0.6)
        barrelGroup.addChildNode(upperHg)
        
        akNode.addChildNode(barrelGroup)
        
        // Sights
        let rearSightGeom = SCNBox(width: 0.2, height: 0.15, length: 0.4, chamferRadius: 0)
        rearSightGeom.materials = [darkSteelMat]
        let rearSight = SCNNode(geometry: rearSightGeom)
        rearSight.position = SCNVector3(0, 0.35, 0.5)
        rearSight.eulerAngles = SCNVector3(-Float.pi * 0.05, 0, 0)
        akNode.addChildNode(rearSight)
        
        let frontSightBlockGeom = SCNBox(width: 0.15, height: 0.35, length: 0.2, chamferRadius: 0)
        frontSightBlockGeom.materials = [darkSteelMat]
        let frontSightBlock = SCNNode(geometry: frontSightBlockGeom)
        frontSightBlock.position = SCNVector3(0, 0.22, 3.8)
        akNode.addChildNode(frontSightBlock)
        
        let frontSightRingGeom = SCNTube(innerRadius: 0.1, outerRadius: 0.12, height: 0.15)
        frontSightRingGeom.materials = [darkSteelMat]
        let frontSightRing = SCNNode(geometry: frontSightRingGeom)
        frontSightRing.position = SCNVector3(0, 0.4, 3.8)
        akNode.addChildNode(frontSightRing)
        
        // Red Dot Optic
        let opticGroup = SCNNode()
        opticGroup.position = SCNVector3(0, 0.4, -0.2)
        
        let mountGeom = SCNBox(width: 0.15, height: 0.15, length: 0.4, chamferRadius: 0)
        mountGeom.materials = [darkSteelMat]
        let mount = SCNNode(geometry: mountGeom)
        opticGroup.addChildNode(mount)
        
        let housingGeom = SCNCylinder(radius: 0.2, height: 0.5)
        housingGeom.materials = [darkSteelMat]
        let housing = SCNNode(geometry: housingGeom)
        housing.position = SCNVector3(0, 0.2, 0)
        housing.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        opticGroup.addChildNode(housing)
        
        let lensGeom = SCNCylinder(radius: 0.18, height: 0.02)
        lensGeom.materials = [glassMat]
        let lens = SCNNode(geometry: lensGeom)
        lens.position = SCNVector3(0, 0.2, 0.24)
        lens.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        opticGroup.addChildNode(lens)
        
        let reticleGeom = SCNPlane(width: 0.05, height: 0.05)
        reticleGeom.materials = [reticleMat]
        let reticle = SCNNode(geometry: reticleGeom)
        reticle.position = SCNVector3(0, 0.2, 0.23)
        opticGroup.addChildNode(reticle)
        
        akNode.addChildNode(opticGroup)
        
        return akNode
    }
}
