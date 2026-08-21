import SwiftUI
import RealityKit

struct WeaponPreview3D: View {
    let weaponName: String
    var body: some View {
        RealityView { content in
            let box: ModelEntity
            if weaponName.lowercased().contains("m2010") {
                box = ModelEntity(mesh: .generateBox(width: 0.04, height: 0.04, depth: 0.6), materials: [SimpleMaterial(color: .black, roughness: 0.6, isMetallic: false)])
            } else {
                box = ModelEntity(mesh: .generateBox(width: 0.05, height: 0.04, depth: 0.45), materials: [SimpleMaterial(color: PlatformColor(white: 0.25, alpha: 1), roughness: 0.7, isMetallic: false)])
            }
            box.position = SIMD3<Float>(0,0,0)
            let anchor = RealityKit.AnchorEntity(world: SIMD3<Float>(0,0,0))
            anchor.addChild(box)
            content.add(anchor)
            let sun = RealityKit.Entity()
            sun.components.set(DirectionalLightComponent(color: .white, intensity: 1500))
            sun.position = SIMD3<Float>(2,3,2)
            content.add(sun)
        }
    }
}
