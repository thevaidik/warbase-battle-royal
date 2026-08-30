import Foundation

final class CombatSystem: Sendable {
    init() {}
    
    func update(
        identities: [String: UnitIdentityComponent],
        combatStats: inout [String: CombatStatsComponent],
        transforms: inout [String: TransformComponent],
        supplies: inout [String: SupplyComponent],
        destroyedEvents: inout [Warbase_UnitDestroyedEvent],
        deltaTime: Float
    ) {
        for (attackerId, attackerIdentity) in identities {
            guard var attackerStats = combatStats[attackerId],
                  attackerStats.status != .destroyed,
                  let targetId = attackerStats.activeTargetId,
                  let targetIdentity = identities[targetId],
                  targetIdentity.faction != attackerIdentity.faction,
                  var targetStats = combatStats[targetId],
                  targetStats.status != .destroyed else { continue }
            
            // Suppression natural recovery
            attackerStats.suppression = max(0.0, attackerStats.suppression - (0.02 * deltaTime))
            
            // Check ammunition
            if let supply = supplies[attackerId], supply.ammoLevel <= 0.05 {
                attackerStats.status = .idle
                combatStats[attackerId] = attackerStats
                continue
            }
            
            // Direct fire resolution
            let firePower = (attackerStats.softAttack + attackerStats.hardAttack) * (1.0 - (attackerStats.suppression * 0.6))
            let damage = firePower * 0.05 * deltaTime
            
            targetStats.health = max(0.0, targetStats.health - damage)
            targetStats.suppression = min(1.0, targetStats.suppression + (0.1 * deltaTime))
            
            if targetStats.health <= 0 {
                targetStats.status = .destroyed
                var destroyedEvent = Warbase_UnitDestroyedEvent()
                destroyedEvent.unitID = targetId
                destroyedEvent.unitName = targetIdentity.name
                destroyedEvent.faction = targetIdentity.faction.rawValue
                destroyedEvent.destroyedByUnitID = attackerId
                destroyedEvent.cause = "DIRECT_FIRE"
                destroyedEvents.append(destroyedEvent)
                attackerStats.activeTargetId = nil
            } else {
                targetStats.status = .engaged
            }
            
            combatStats[targetId] = targetStats
            combatStats[attackerId] = attackerStats
            
            // Consume ammo
            if var supply = supplies[attackerId] {
                supply.ammoLevel = max(0.0, supply.ammoLevel - (0.001 * deltaTime))
                supplies[attackerId] = supply
            }
        }
    }
}
