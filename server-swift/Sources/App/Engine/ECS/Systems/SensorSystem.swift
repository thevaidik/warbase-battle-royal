import Foundation

final class SensorSystem: Sendable {
    init() {}
    
    func update(
        identities: [String: UnitIdentityComponent],
        transforms: [String: TransformComponent],
        sensors: [String: SensorComponent],
        combatStats: [String: CombatStatsComponent],
        ewEmitters: [String: ElectronicWarfareComponent],
        contacts: inout [Warbase_SensorContact]
    ) {
        contacts.removeAll(keepingCapacity: true)
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        
        for (observerId, observerIdentity) in identities {
            guard let observerPos = transforms[observerId],
                  let observerSensor = sensors[observerId] else { continue }
            
            for (targetId, targetIdentity) in identities {
                if observerIdentity.faction == targetIdentity.faction { continue }
                guard let targetPos = transforms[targetId] else { continue }
                
                let dx = targetPos.x - observerPos.x
                let dz = targetPos.z - observerPos.z
                let dist = sqrt(dx * dx + dz * dz)
                
                // Sensor detection ranges
                var detected = false
                var confidence = "UNCONFIRMED_THERMAL"
                
                if dist <= observerSensor.opticalRange {
                    detected = true
                    confidence = "IDENTIFIED_UNIT"
                } else if dist <= observerSensor.thermalRange {
                    detected = true
                    confidence = "UNCONFIRMED_THERMAL"
                } else if observerSensor.radarRange > 0 && dist <= observerSensor.radarRange {
                    detected = true
                    confidence = "RADAR_BLIP"
                }
                
                if detected {
                    var contact = Warbase_SensorContact()
                    contact.contactID = "\(observerIdentity.faction.rawValue)-\(targetId)"
                    contact.x = targetPos.x
                    contact.y = targetPos.y
                    contact.z = targetPos.z
                    contact.confidence = confidence
                    contact.detectedFaction = targetIdentity.faction.rawValue
                    contact.estimatedType = targetIdentity.unitType.rawValue
                    contact.lastSeenTimestamp = now
                    contacts.append(contact)
                }
            }
        }
    }
}
