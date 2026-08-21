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
    var floor: Entity?

    func clearAll() {
        player?.removeFromParent()
        cameraAnchor?.removeFromParent()
        player = nil
        cameraEntity = nil
        cameraAnchor = nil
        swayRoot = nil; weaponAK = nil; weaponM2010 = nil; weaponPistol = nil
        soldier = nil
    }
}
