import Foundation

final class MovementSystem: Sendable {
    init() {}
    
    func update(
        transforms: inout [String: TransformComponent],
        combatStats: inout [String: CombatStatsComponent],
        supplies: inout [String: SupplyComponent],
        deltaTime: Float
    ) {
        for (id, var transform) in transforms {
            guard let targetX = transform.targetX, let targetZ = transform.targetZ else { continue }
            
            // Check fuel availability
            if let supply = supplies[id], supply.fuelLevel <= 0.01 {
                // Out of fuel, cannot move
                if var stats = combatStats[id] {
                    stats.status = .idle
                    combatStats[id] = stats
                }
                continue
            }
            
            let dx = targetX - transform.x
            let dz = targetZ - transform.z
            let dist = sqrt(dx * dx + dz * dz)
            
            if dist < 10.0 {
                // Arrived at destination
                transform.x = targetX
                transform.z = targetZ
                transform.targetX = nil
                transform.targetZ = nil
                transforms[id] = transform
                
                if var stats = combatStats[id], stats.status == .moving {
                    stats.status = .idle
                    combatStats[id] = stats
                }
                continue
            }
            
            // Calculate heading
            transform.heading = atan2(dx, dz)
            
            // Suppression speed penalty
            var effectiveSpeed = transform.speed
            if let stats = combatStats[id] {
                let suppressionFactor = max(0.2, 1.0 - (stats.suppression * 0.7))
                effectiveSpeed *= suppressionFactor
            }
            
            // Move step
            let step = effectiveSpeed * deltaTime
            let moveRatio = min(1.0, step / dist)
            transform.x += dx * moveRatio
            transform.z += dz * moveRatio
            transforms[id] = transform
            
            // Consume fuel
            if var supply = supplies[id] {
                supply.fuelLevel = max(0.0, supply.fuelLevel - (0.0005 * deltaTime))
                supplies[id] = supply
            }
            
            if var stats = combatStats[id], stats.status != .engaged {
                stats.status = .moving
                combatStats[id] = stats
            }
        }
    }
}
