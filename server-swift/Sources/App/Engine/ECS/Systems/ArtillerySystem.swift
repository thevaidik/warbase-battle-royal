import Foundation

final class ArtillerySystem: Sendable {
    init() {}
    
    func update(
        batteries: inout [String: ArtilleryBatteryComponent],
        batteryTransforms: [String: TransformComponent],
        targetTransforms: [String: TransformComponent],
        combatStats: inout [String: CombatStatsComponent],
        supplies: inout [String: SupplyComponent],
        activeMissionsOut: inout [Warbase_ActiveFireMission],
        detonationEvents: inout [Warbase_ArtilleryDetonationEvent],
        counterBatteryEvents: inout [Warbase_CounterBatteryAlert],
        deltaTime: Float
    ) {
        activeMissionsOut.removeAll(keepingCapacity: true)
        
        for (batteryId, var battery) in batteries {
            guard let originPos = batteryTransforms[batteryId] else { continue }
            
            var updatedMissions: [FireMission] = []
            
            for var mission in battery.activeMissions {
                mission.timeToImpact -= deltaTime
                
                if mission.timeToImpact <= 0 {
                    // Detonation impact!
                    // Apply dispersion CEP
                    let randomAngle = Float.random(in: 0...(2 * .pi))
                    let randomRadius = Float.random(in: 0...mission.dispersionCep)
                    let impactX = mission.targetX + cos(randomAngle) * randomRadius
                    let impactZ = mission.targetZ + sin(randomAngle) * randomRadius
                    
                    var detonation = Warbase_ArtilleryDetonationEvent()
                    detonation.missionID = mission.missionId
                    detonation.x = impactX
                    detonation.y = mission.targetY
                    detonation.z = impactZ
                    detonation.munitionType = mission.munitionType
                    detonation.damageRadius = (mission.munitionType == "CLUSTER") ? 85.0 : 45.0
                    
                    var casualtiesInflicted: Int32 = 0
                    var vehiclesDestroyed: Int32 = 0
                    
                    // Damage nearby enemy units
                    for (targetId, targetPos) in targetTransforms {
                        let dx = targetPos.x - impactX
                        let dz = targetPos.z - impactZ
                        let dist = sqrt(dx * dx + dz * dz)
                        
                        if dist <= detonation.damageRadius {
                            guard var targetStats = combatStats[targetId] else { continue }
                            
                            // Entrenchment damage mitigation (Level 1: 30%, Level 2: 60%, Level 3: 85%)
                            let entrenchmentReduction: Float
                            switch targetStats.entrenchmentLevel {
                            case 1: entrenchmentReduction = 0.30
                            case 2: entrenchmentReduction = 0.60
                            case 3: entrenchmentReduction = 0.85
                            default: entrenchmentReduction = 0.0
                            }
                            
                            let baseDamage: Float = (mission.munitionType == "PRECISION_GUIDED") ? 80.0 : 45.0
                            let effectiveDamage = baseDamage * (1.0 - (dist / detonation.damageRadius)) * (1.0 - entrenchmentReduction)
                            
                            targetStats.health = max(0.0, targetStats.health - effectiveDamage)
                            targetStats.suppression = min(1.0, targetStats.suppression + 0.5)
                            
                            let killedPersonnel = Int32(Float(targetStats.personnel) * (effectiveDamage / 200.0))
                            targetStats.personnel = max(0, targetStats.personnel - killedPersonnel)
                            casualtiesInflicted += killedPersonnel
                            
                            if effectiveDamage > 30.0 && targetStats.vehicles > 0 {
                                targetStats.vehicles -= 1
                                vehiclesDestroyed += 1
                            }
                            
                            if targetStats.health <= 0 {
                                targetStats.status = .destroyed
                            } else {
                                targetStats.status = .suppressed
                            }
                            
                            combatStats[targetId] = targetStats
                        }
                    }
                    
                    detonation.casualties = casualtiesInflicted
                    detonation.vehiclesDestroyed = vehiclesDestroyed
                    detonationEvents.append(detonation)
                    
                    // Generate counter-battery detection alert
                    var alert = Warbase_CounterBatteryAlert()
                    alert.detectionID = UUID().uuidString
                    alert.detectedOriginX = originPos.x + Float.random(in: -30...30)
                    alert.detectedOriginZ = originPos.z + Float.random(in: -30...30)
                    alert.confidenceCep = 40.0
                    alert.detectingRadarID = "RADAR-COBRA-1"
                    counterBatteryEvents.append(alert)
                    
                    mission.roundsFired += 1
                    if mission.roundsFired < mission.totalRounds {
                        // Queue next round in burst
                        mission.timeToImpact = battery.reloadTimeSec + Float(sqrt(Double(originPos.x * originPos.x + originPos.z * originPos.z))) / 450.0
                        updatedMissions.append(mission)
                    }
                } else {
                    updatedMissions.append(mission)
                }
                
                var protoMission = Warbase_ActiveFireMission()
                protoMission.missionID = mission.missionId
                protoMission.batteryID = batteryId
                protoMission.originX = originPos.x
                protoMission.originY = originPos.y
                protoMission.originZ = originPos.z
                protoMission.targetX = mission.targetX
                protoMission.targetY = mission.targetY
                protoMission.targetZ = mission.targetZ
                protoMission.munitionType = mission.munitionType
                protoMission.totalRounds = mission.totalRounds
                protoMission.roundsFired = mission.roundsFired
                protoMission.flightTimeSeconds = mission.flightTimeSec
                protoMission.timeToImpact = mission.timeToImpact
                protoMission.dispersionCep = mission.dispersionCep
                activeMissionsOut.append(protoMission)
            }
            
            battery.activeMissions = updatedMissions
            batteries[batteryId] = battery
        }
    }
}
