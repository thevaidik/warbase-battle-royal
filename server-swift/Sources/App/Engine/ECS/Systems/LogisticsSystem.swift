import Foundation

final class LogisticsSystem: Sendable {
    init() {}
    
    func update(
        supplies: inout [String: SupplyComponent],
        transforms: [String: TransformComponent],
        depots: [Warbase_SupplyDepotState],
        deltaTime: Float
    ) {
        for (unitId, var supply) in supplies {
            guard let unitPos = transforms[unitId] else { continue }
            
            // Check proximity to supply depots for automatic replenishment
            for depot in depots {
                let dx = unitPos.x - depot.x
                let dz = unitPos.z - depot.z
                let dist = sqrt(dx * dx + dz * dz)
                
                if dist <= 1500.0 {
                    // Resupply
                    supply.ammoLevel = min(1.0, supply.ammoLevel + (supply.resupplyRatePerSec * deltaTime))
                    supply.fuelLevel = min(1.0, supply.fuelLevel + (supply.resupplyRatePerSec * deltaTime))
                    supply.batteryLevel = min(1.0, supply.batteryLevel + (supply.resupplyRatePerSec * deltaTime))
                }
            }
            
            supplies[unitId] = supply
        }
    }
}
