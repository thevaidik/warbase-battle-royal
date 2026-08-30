import Foundation

final class ElectronicWarfareSystem: Sendable {
    init() {}
    
    func update(
        ewIdentities: [String: UnitIdentityComponent],
        ewComponents: [String: ElectronicWarfareComponent],
        ewTransforms: [String: TransformComponent],
        droneIdentities: [String: UnitIdentityComponent],
        dronePlatforms: inout [String: DronePlatformComponent],
        droneTransforms: [String: TransformComponent]
    ) {
        for (droneId, droneIdentity) in droneIdentities {
            guard var platform = dronePlatforms[droneId],
                  let dronePos = droneTransforms[droneId] else { continue }
            
            var highestJammingPower: Float = 0.0
            
            for (ewId, ewIdentity) in ewIdentities {
                if ewIdentity.faction == droneIdentity.faction { continue }
                guard let ewComp = ewComponents[ewId], ewComp.isTransmitting,
                      let ewPos = ewTransforms[ewId] else { continue }
                
                let dx = dronePos.x - ewPos.x
                let dz = dronePos.z - ewPos.z
                let dist = sqrt(dx * dx + dz * dz)
                
                if dist <= ewComp.jammingRadius {
                    let falloff = 1.0 - (dist / ewComp.jammingRadius)
                    let jammingEffect = falloff * (ewComp.powerDbm / 100.0)
                    highestJammingPower = max(highestJammingPower, jammingEffect)
                }
            }
            
            // Degrade signal quality based on jamming power
            platform.signalQuality = max(0.0, 1.0 - highestJammingPower)
            dronePlatforms[droneId] = platform
        }
    }
}
