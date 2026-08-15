import Foundation
import SceneKit


public class M2010Builder {
    public static func build() -> SCNNode {
        let m2010Node = SCNNode()
        m2010Node.name = "M2010"
        
        let scale: Float = 0.08
        m2010Node.scale = SCNVector3(scale, scale, scale)
        
        // Materials
        let darkMetal = SCNMaterial()
        darkMetal.lightingModel = .physicallyBased
        darkMetal.diffuse.contents = PlatformColor(white: 0.1, alpha: 1.0)
        darkMetal.roughness.contents = NSNumber(value: 0.4)
        darkMetal.metalness.contents = NSNumber(value: 0.9)
        
        let polymerMat = SCNMaterial()
        polymerMat.lightingModel = .physicallyBased
        polymerMat.diffuse.contents = PlatformColor(red: 0.2, green: 0.2, blue: 0.18, alpha: 1.0) // Olive/dark earth
        polymerMat.roughness.contents = NSNumber(value: 0.9)
        polymerMat.metalness.contents = NSNumber(value: 0.1)
        
        let glassMat = SCNMaterial()
        glassMat.lightingModel = .physicallyBased
        glassMat.diffuse.contents = PlatformColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 0.8)
        glassMat.roughness.contents = NSNumber(value: 0.0)
        glassMat.metalness.contents = NSNumber(value: 1.0)
        
        // Receiver
        let receiverGeom = SCNBox(width: 0.35, height: 0.4, length: 2.0, chamferRadius: 0.05)
        receiverGeom.materials = [darkMetal]
        let receiver = SCNNode(geometry: receiverGeom)
        receiver.position = SCNVector3(0, 0, 0)
        m2010Node.addChildNode(receiver)
        
        // Ejection Port
        let ejectPortGeom = SCNBox(width: 0.2, height: 0.2, length: 0.8, chamferRadius: 0.0)
        let ejectMat = SCNMaterial()
        ejectMat.diffuse.contents = PlatformColor.black
        ejectPortGeom.materials = [ejectMat]
        let ejectPort = SCNNode(geometry: ejectPortGeom)
        ejectPort.position = SCNVector3(0.1, 0.1, 0.2)
        receiver.addChildNode(ejectPort)
        
        // Bolt
        let boltStemGeom = SCNCylinder(radius: 0.12, height: 2.2)
        boltStemGeom.materials = [darkMetal]
        let boltStem = SCNNode(geometry: boltStemGeom)
        boltStem.position = SCNVector3(0, 0.1, -0.2)
        boltStem.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        m2010Node.addChildNode(boltStem)
        
        let boltKnobGeom = SCNSphere(radius: 0.15)
        boltKnobGeom.materials = [darkMetal]
        let boltKnob = SCNNode(geometry: boltKnobGeom)
        boltKnob.position = SCNVector3(0.3, 0.1, -1.0)
        m2010Node.addChildNode(boltKnob)
        
        let boltHandleGeom = SCNCylinder(radius: 0.05, height: 0.4)
        boltHandleGeom.materials = [darkMetal]
        let boltHandle = SCNNode(geometry: boltHandleGeom)
        boltHandle.position = SCNVector3(0.15, 0.1, -1.0)
        boltHandle.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        m2010Node.addChildNode(boltHandle)
        
        // Stock
        let stockGeom = SCNBox(width: 0.3, height: 0.5, length: 1.5, chamferRadius: 0.05)
        stockGeom.materials = [polymerMat]
        let stock = SCNNode(geometry: stockGeom)
        stock.position = SCNVector3(0, -0.1, -1.5)
        m2010Node.addChildNode(stock)
        
        let buttpadGeom = SCNBox(width: 0.32, height: 0.6, length: 0.1, chamferRadius: 0.02)
        let buttpadMat = SCNMaterial()
        buttpadMat.diffuse.contents = PlatformColor.black
        buttpadGeom.materials = [buttpadMat]
        let buttpad = SCNNode(geometry: buttpadGeom)
        buttpad.position = SCNVector3(0, -0.1, -2.3)
        m2010Node.addChildNode(buttpad)
        
        let cheekRiserGeom = SCNBox(width: 0.35, height: 0.2, length: 0.6, chamferRadius: 0.05)
        cheekRiserGeom.materials = [polymerMat]
        let cheekRiser = SCNNode(geometry: cheekRiserGeom)
        cheekRiser.position = SCNVector3(0, 0.25, -1.6)
        m2010Node.addChildNode(cheekRiser)
        
        let pistolGripGeom = SCNBox(width: 0.25, height: 0.8, length: 0.35, chamferRadius: 0.05)
        pistolGripGeom.materials = [polymerMat]
        let pistolGrip = SCNNode(geometry: pistolGripGeom)
        pistolGrip.position = SCNVector3(0, -0.6, -0.8)
        pistolGrip.eulerAngles = SCNVector3(Float.pi * 0.15, 0, 0)
        m2010Node.addChildNode(pistolGrip)
        
        // Barrel
        let barrelGroup = SCNNode()
        barrelGroup.position = SCNVector3(0, 0.05, 2.0)
        
        let mainBarrelGeom = SCNCylinder(radius: 0.12, height: 3.0)
        mainBarrelGeom.materials = [darkMetal]
        let mainBarrel = SCNNode(geometry: mainBarrelGeom)
        mainBarrel.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        barrelGroup.addChildNode(mainBarrel)
        
        // Flutes
        for i in 0..<4 {
            let angle = Float(i) * (Float.pi / 2.0)
            let fluteGeom = SCNCylinder(radius: 0.03, height: 2.8)
            fluteGeom.materials = [darkMetal]
            let flute = SCNNode(geometry: fluteGeom)
            flute.position = SCNVector3(cos(angle) * 0.12, sin(angle) * 0.12, 0)
            flute.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            barrelGroup.addChildNode(flute)
        }
        
        // Muzzle brake
        let muzzleGeom = SCNCylinder(radius: 0.15, height: 0.5)
        muzzleGeom.materials = [darkMetal]
        let muzzle = SCNNode(geometry: muzzleGeom)
        muzzle.position = SCNVector3(0, 0, 1.6)
        muzzle.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        barrelGroup.addChildNode(muzzle)
        
        m2010Node.addChildNode(barrelGroup)
        
        // Magazine
        let magGeom = SCNBox(width: 0.28, height: 0.6, length: 0.6, chamferRadius: 0.02)
        magGeom.materials = [darkMetal]
        let mag = SCNNode(geometry: magGeom)
        mag.position = SCNVector3(0, -0.4, 0.2)
        m2010Node.addChildNode(mag)
        
        // Scope
        let scopeGroup = SCNNode()
        scopeGroup.position = SCNVector3(0, 0.5, 0.2)
        
        let railGeom = SCNBox(width: 0.2, height: 0.05, length: 1.5, chamferRadius: 0)
        railGeom.materials = [darkMetal]
        let rail = SCNNode(geometry: railGeom)
        rail.position = SCNVector3(0, -0.25, 0)
        scopeGroup.addChildNode(rail)
        
        let ring1Geom = SCNBox(width: 0.25, height: 0.3, length: 0.15, chamferRadius: 0)
        ring1Geom.materials = [darkMetal]
        let ring1 = SCNNode(geometry: ring1Geom)
        ring1.position = SCNVector3(0, -0.1, -0.4)
        scopeGroup.addChildNode(ring1)
        
        let ring2Geom = SCNBox(width: 0.25, height: 0.3, length: 0.15, chamferRadius: 0)
        ring2Geom.materials = [darkMetal]
        let ring2 = SCNNode(geometry: ring2Geom)
        ring2.position = SCNVector3(0, -0.1, 0.4)
        scopeGroup.addChildNode(ring2)
        
        let tubeGeom = SCNCylinder(radius: 0.15, height: 1.8)
        tubeGeom.materials = [darkMetal]
        let tube = SCNNode(geometry: tubeGeom)
        tube.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scopeGroup.addChildNode(tube)
        
        let objectiveGeom = SCNCylinder(radius: 0.25, height: 0.5)
        objectiveGeom.materials = [darkMetal]
        let objective = SCNNode(geometry: objectiveGeom)
        objective.position = SCNVector3(0, 0, 1.0)
        objective.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scopeGroup.addChildNode(objective)
        
        let ocularGeom = SCNCylinder(radius: 0.2, height: 0.4)
        ocularGeom.materials = [darkMetal]
        let ocular = SCNNode(geometry: ocularGeom)
        ocular.position = SCNVector3(0, 0, -1.0)
        ocular.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scopeGroup.addChildNode(ocular)
        
        let topTurretGeom = SCNCylinder(radius: 0.1, height: 0.2)
        topTurretGeom.materials = [darkMetal]
        let topTurret = SCNNode(geometry: topTurretGeom)
        topTurret.position = SCNVector3(0, 0.2, 0)
        scopeGroup.addChildNode(topTurret)
        
        let sideTurretGeom = SCNCylinder(radius: 0.1, height: 0.2)
        sideTurretGeom.materials = [darkMetal]
        let sideTurret = SCNNode(geometry: sideTurretGeom)
        sideTurret.position = SCNVector3(0.2, 0, 0)
        sideTurret.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        scopeGroup.addChildNode(sideTurret)
        
        // Lenses
        let objLensGeom = SCNCylinder(radius: 0.23, height: 0.02)
        objLensGeom.materials = [glassMat]
        let objLens = SCNNode(geometry: objLensGeom)
        objLens.position = SCNVector3(0, 0, 1.24)
        objLens.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scopeGroup.addChildNode(objLens)
        
        let ocularLensGeom = SCNCylinder(radius: 0.18, height: 0.02)
        ocularLensGeom.materials = [glassMat]
        let ocularLens = SCNNode(geometry: ocularLensGeom)
        ocularLens.position = SCNVector3(0, 0, -1.19)
        ocularLens.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scopeGroup.addChildNode(ocularLens)
        
        m2010Node.addChildNode(scopeGroup)
        
        return m2010Node
    }
}
