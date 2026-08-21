import RealityKit
import Foundation

// Procedural FPS weapons ported from client/src/physics/{AK47,M2010,Pistol}Builder.ts
enum RealityWeapons {
    private static func mat(_ c: PlatformColor, metallic: Bool, roughness: Float) -> SimpleMaterial {
        SimpleMaterial(color: c, roughness: .init(floatLiteral: roughness), isMetallic: metallic)
    }
    private static func box(_ n: String, _ s: SIMD3<Float>, _ m: SimpleMaterial) -> ModelEntity {
        let e = ModelEntity(mesh: .generateBox(width: s.x, height: s.y, depth: s.z), materials: [m]); e.name = n; return e
    }
    private static func cyl(_ n: String, _ r: Float, _ h: Float, _ m: SimpleMaterial) -> ModelEntity {
        let e = ModelEntity(mesh: .generateCylinder(height: h, radius: r), materials: [m]); e.name = n; return e
    }
    private static func sphere(_ n: String, _ r: Float, _ m: SimpleMaterial) -> ModelEntity {
        let e = ModelEntity(mesh: .generateSphere(radius: r), materials: [m]); e.name = n; return e
    }

    static func ak47() -> ModelEntity {
        let root = ModelEntity(mesh: .generateBox(size: 0.001), materials: [SimpleMaterial(color: .clear, isMetallic: false)])
        root.name = "ak47"
        let metal = mat(PlatformColor(white: 0.13, alpha: 1), metallic: true, roughness: 0.35)
        let darkSteel = mat(PlatformColor(white: 0.07, alpha: 1), metallic: true, roughness: 0.25)
        let wood = mat(PlatformColor(red: 0.42, green: 0.18, blue: 0.08, alpha: 1), metallic: false, roughness: 0.4)

        root.addChild(box("receiver", [0.28, 0.45, 1.8], metal))
        root.addChild(box("stock", [0.24, 0.42, 1.3], wood).then { $0.position = [0, -0.12, -1.55]; $0.orientation = simd_quatf(angle: .pi/30, axis: [1,0,0]) })
        root.addChild(box("buttPlate", [0.25, 0.44, 0.06], darkSteel).then { $0.position = [0, -0.15, -2.2] })
        root.addChild(box("magazine", [0.22, 1.1, 0.38], metal).then { $0.position = [0, -0.65, 0.55]; $0.orientation = simd_quatf(angle: -.pi/7, axis: [1,0,0]) })
        root.addChild(box("grip", [0.22, 0.55, 0.28], wood).then { $0.position = [0, -0.45, -0.65]; $0.orientation = simd_quatf(angle: -.pi/10, axis: [1,0,0]) })
        root.addChild(cyl("barrel", 0.055, 2.4, darkSteel).then { $0.position = [0, 0.1, 2.1]; $0.orientation = simd_quatf(angle: .pi/2, axis: [1,0,0]) })
        root.addChild(cyl("gasTube", 0.07, 1.1, darkSteel).then { $0.position = [0, 0.24, 1.5]; $0.orientation = simd_quatf(angle: .pi/2, axis: [1,0,0]) })
        root.addChild(cyl("dustCover", 0.145, 1.82, metal).then { $0.position = [0, 0.22, 0]; $0.orientation = simd_quatf(angle: .pi/2, axis: [1,0,0]) })
        root.addChild(box("lowerHandguard", [0.32, 0.28, 1.05], wood).then { $0.position = [0, 0.04, 1.45] })
        root.addChild(box("rearSight", [0.18, 0.18, 0.3], darkSteel).then { $0.position = [0, 0.38, 0.85] })
        root.addChild(box("frontSightPost", [0.04, 0.22, 0.08], darkSteel).then { $0.position = [0, 0.32, 3.1] })
        root.addChild(box("opticMount", [0.2, 0.15, 0.6], darkSteel).then { $0.position = [0, 0.42, 0.2] })
        root.addChild(box("opticHousing", [0.24, 0.25, 0.4], darkSteel).then { $0.position = [0, 0.58, 0.2] })

        root.scale = SIMD3<Float>(repeating: 0.08)
        root.orientation = simd_quatf(angle: .pi, axis: [0,1,0]) // barrel points -Z (camera forward)
        return root
    }

    static func m2010() -> ModelEntity {
        let root = ModelEntity(mesh: .generateBox(size: 0.001), materials: [SimpleMaterial(color: .clear, isMetallic: false)])
        root.name = "m2010"
        let chassis = mat(PlatformColor(red: 0.18, green: 0.17, blue: 0.15, alpha: 1), metallic: true, roughness: 0.3)
        let steel = mat(PlatformColor(white: 0.08, alpha: 1), metallic: true, roughness: 0.25)
        let polymer = mat(PlatformColor(white: 0.05, alpha: 1), metallic: false, roughness: 0.7)
        let lens = mat(PlatformColor(red: 0.1, green: 0.4, blue: 0.6, alpha: 0.85), metallic: true, roughness: 0.05)

        root.addChild(box("receiver", [0.07, 0.09, 0.4], chassis).then { $0.position = [0, 0.04, 0.15] })
        root.addChild(box("stock", [0.05, 0.08, 0.3], chassis).then { $0.position = [0, 0.02, -0.2] })
        root.addChild(box("buttpad", [0.055, 0.12, 0.04], polymer).then { $0.position = [0, 0.01, -0.37] })
        root.addChild(box("grip", [0.04, 0.13, 0.05], polymer).then { $0.position = [0, -0.06, -0.02] })
        root.addChild(cyl("barrel", 0.016, 0.85, steel).then { $0.position = [0, 0.045, 0.77]; $0.orientation = simd_quatf(angle: .pi/2, axis: [1,0,0]) })
        root.addChild(box("muzzleBrake", [0.042, 0.042, 0.1], steel).then { $0.position = [0, 0.045, 1.23] })
        root.addChild(box("magazine", [0.035, 0.14, 0.09], steel).then { $0.position = [0, -0.05, 0.16] })
        root.addChild(box("rail", [0.035, 0.015, 0.35], steel).then { $0.position = [0, 0.095, 0.15] })
        root.addChild(cyl("scopeTube", 0.02, 0.36, steel).then { $0.position = [0, 0.135, 0.15]; $0.orientation = simd_quatf(angle: .pi/2, axis: [1,0,0]) })
        root.addChild(cyl("objective", 0.03, 0.08, steel).then { $0.position = [0, 0.135, 0.37]; $0.orientation = simd_quatf(angle: .pi/2, axis: [1,0,0]) })
        root.addChild(cyl("frontLens", 0.028, 0.005, lens).then { $0.position = [0, 0.135, 0.41]; $0.orientation = simd_quatf(angle: .pi/2, axis: [1,0,0]) })

        root.scale = SIMD3<Float>(repeating: 0.12)
        root.orientation = simd_quatf(angle: .pi, axis: [0,1,0])
        return root
    }

    static func pistol() -> ModelEntity {
        let root = ModelEntity(mesh: .generateBox(size: 0.001), materials: [SimpleMaterial(color: .clear, isMetallic: false)])
        root.name = "pistol"
        let steel = mat(PlatformColor(white: 0.1, alpha: 1), metallic: true, roughness: 0.3)
        let grip = mat(PlatformColor(white: 0.06, alpha: 1), metallic: false, roughness: 0.7)
        root.addChild(box("slide", [0.05, 0.05, 0.25], steel).then { $0.position = [0, 0.03, 0.05] })
        root.addChild(cyl("barrel", 0.02, 0.2, steel).then { $0.position = [0, 0.03, 0.15]; $0.orientation = simd_quatf(angle: .pi/2, axis: [1,0,0]) })
        root.addChild(box("grip", [0.04, 0.14, 0.05], grip).then { $0.position = [0, -0.07, -0.02] })
        root.scale = SIMD3<Float>(repeating: 0.15)
        root.orientation = simd_quatf(angle: .pi, axis: [0,1,0])
        return root
    }
}

private extension ModelEntity {
    func then(_ block: (ModelEntity) -> Void) -> ModelEntity { block(self); return self }
}
