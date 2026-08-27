import RealityKit

final class RealityViewMaps {
    var player: RealityKit.Entity?
    var cameraEntity: RealityKit.Entity?
    var cameraAnchor: RealityKit.Entity?
    var swayRoot: RealityKit.Entity?
    var weaponAK: ModelEntity?
    var weaponM2010: ModelEntity?
    var weaponPistol: ModelEntity?
    var soldier: RealityKit.Entity?
    var soldierAnims: [String: RealityKit.AnimationResource] = [:]
    var floor: RealityKit.Entity?

    func clearAll() {
        player?.removeFromParent()
        // floor was missed — ghost collision after re-enter
        floor?.removeFromParent()
        cameraAnchor?.removeFromParent()
        player = nil
        cameraEntity = nil
        cameraAnchor = nil
        swayRoot = nil; weaponAK = nil; weaponM2010 = nil; weaponPistol = nil
        soldier = nil; soldierAnims.removeAll(); floor = nil
    }
}
