import Foundation

final class DroneSystem: Sendable {
    init() {}
    
    func update(
        dronePlatforms: inout [String: DronePlatformComponent],
        droneTransforms: inout [String: TransformComponent],
        combatStats: inout [String: CombatStatsComponent],
        droneStrikeEvents: inout [Warbase_DroneStrikeEvent],
        deltaTime: Float
    ) {
        for (droneId, var platform) in dronePlatforms {
            guard var transform = droneTransforms[droneId] else { continue }
            
            // Battery depletion
            platform.batteryPercent = max(0.0, platform.batteryPercent - (0.05 * deltaTime))
            
            // FPV Dive Attack Simulation
            if platform.droneType == .fpvKamikaze && platform.isDiving {
                guard let targetId = platform.targetUnitId,
                      var targetStats = combatStats[targetId] else { continue }
                
                // Signal loss near EW ground level check
                if platform.signalQuality < 0.10 {
                    // Lost video feed, miss
                    platform.isDiving = false
                    dronePlatforms[droneId] = platform
                    continue
                }
                
                // Strike detonation
                var strikeEvent = Warbase_DroneStrikeEvent()
                strikeEvent.droneID = droneId
                strikeEvent.targetUnitID = targetId
                strikeEvent.x = transform.x
                strikeEvent.y = transform.y
                strikeEvent.z = transform.z
                
                let penetrated = platform.payloadArmorPenetration >= targetStats.armorRating
                strikeEvent.armorPenetrated = penetrated
                
                let damage = penetrated ? platform.payloadDamage : (platform.payloadDamage * 0.25)
                strikeEvent.damageDealt = damage
                droneStrikeEvents.append(strikeEvent)
                
                targetStats.health = max(0.0, targetStats.health - damage)
                if targetStats.vehicles > 0 && penetrated {
                    targetStats.vehicles -= 1
                }
                if targetStats.health <= 0 {
                    targetStats.status = .destroyed
                }
                combatStats[targetId] = targetStats
                
                // Drone destroyed on impact
                dronePlatforms.removeValue(forKey: droneId)
                droneTransforms.removeValue(forKey: droneId)
                continue
            }
            
            // Recon Loitering
            if platform.droneType == .reconQuadcopter || platform.droneType == .reconFixedWing {
                transform.heading += 0.15 * deltaTime
                let radius: Float = 150.0
                transform.x += cos(transform.heading) * radius * deltaTime
                transform.z += sin(transform.heading) * radius * deltaTime
                droneTransforms[droneId] = transform
            }
            
            dronePlatforms[droneId] = platform
        }
    }
}
