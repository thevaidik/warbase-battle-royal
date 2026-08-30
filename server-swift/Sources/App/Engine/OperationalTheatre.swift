import Foundation
import NIOCore
import SwiftProtobuf

final class OperationalTheatre: @unchecked Sendable {
    let id: String
    let name: String
    let mapName: String
    
    // ECS Entity Stores
    var identities: [String: UnitIdentityComponent] = [:]
    var transforms: [String: TransformComponent] = [:]
    var combatStats: [String: CombatStatsComponent] = [:]
    var sensors: [String: SensorComponent] = [:]
    var ewEmitters: [String: ElectronicWarfareComponent] = [:]
    var artilleryBatteries: [String: ArtilleryBatteryComponent] = [:]
    var dronePlatforms: [String: DronePlatformComponent] = [:]
    var droneTransforms: [String: TransformComponent] = [:]
    var droneIdentities: [String: UnitIdentityComponent] = [:]
    var supplies: [String: SupplyComponent] = [:]
    var orderQueues: [String: OrderQueueComponent] = [:]
    
    // Environment & Static Objects
    var supplyDepots: [Warbase_SupplyDepotState] = []
    var fortifications: [Warbase_FortificationState] = []
    var contacts: [Warbase_SensorContact] = []
    
    // Systems
    let movementSystem = MovementSystem()
    let sensorSystem = SensorSystem()
    let ewSystem = ElectronicWarfareSystem()
    let artillerySystem = ArtillerySystem()
    let droneSystem = DroneSystem()
    let combatSystem = CombatSystem()
    let logisticsSystem = LogisticsSystem()
    
    // Networking
    var sessions: [String: GameSession] = [:]
    var tickCount: Int64 = 0
    var isPermanent: Bool = false
    var emptySince: ContinuousClock.Instant = .now
    
    init(id: String, name: String, mapName: String) {
        self.id = id
        self.name = name
        self.mapName = mapName
        seedRealisticModernScenario()
    }
    
    func seedRealisticModernScenario() {
        // --- BLUEFOR (3rd Separate Assault Brigade & 44th Artillery) ---
        addUnit(
            id: "bluefor-3rd-assault-bde",
            name: "3rd Separate Assault Brigade",
            callsign: "Trident-1",
            faction: .bluefor,
            unitType: .mechInfantry,
            echelon: .brigade,
            x: -2500, y: 0, z: -1000,
            personnel: 3200, vehicles: 120, armor: 65, softAtk: 75, hardAtk: 60
        )
        
        addUnit(
            id: "bluefor-47th-mech-btn",
            name: "47th Mechanized Battalion (M2 Bradley)",
            callsign: "Magura-47",
            faction: .bluefor,
            unitType: .mechInfantry,
            echelon: .battalion,
            x: -1800, y: 0, z: -400,
            personnel: 650, vehicles: 31, armor: 85, softAtk: 60, hardAtk: 70
        )
        
        addUnit(
            id: "bluefor-44th-arty-battery",
            name: "44th Artillery Battery (M777 / Excalibur)",
            callsign: "Thunder-44",
            faction: .bluefor,
            unitType: .tubeArtillery,
            echelon: .battery,
            x: -4500, y: 0, z: -2000,
            personnel: 95, vehicles: 8, armor: 15, softAtk: 95, hardAtk: 90
        )
        artilleryBatteries["bluefor-44th-arty-battery"] = ArtilleryBatteryComponent(caliberMm: 155, maxRangeM: 30000, reloadTimeSec: 6.0, dispersionCepM: 15.0)
        
        addUnit(
            id: "bluefor-himars-platoon",
            name: "Rocket Artillery Detachment (M142 HIMARS)",
            callsign: "Archer-6",
            faction: .bluefor,
            unitType: .rocketArtillery,
            echelon: .platoon,
            x: -6000, y: 0, z: -3500,
            personnel: 40, vehicles: 4, armor: 20, softAtk: 120, hardAtk: 140
        )
        artilleryBatteries["bluefor-himars-platoon"] = ArtilleryBatteryComponent(caliberMm: 227, maxRangeM: 70000, reloadTimeSec: 30.0, dispersionCepM: 5.0)
        
        addUnit(
            id: "bluefor-ew-nota",
            name: "EW Detachment (Nota Anti-Drone System)",
            callsign: "Spectrum-1",
            faction: .bluefor,
            unitType: .ewCompany,
            echelon: .company,
            x: -2200, y: 0, z: -800,
            personnel: 50, vehicles: 6, armor: 25, softAtk: 10, hardAtk: 5
        )
        ewEmitters["bluefor-ew-nota"] = ElectronicWarfareComponent(jammingRadius: 6000, powerDbm: 90, isTransmitting: true)
        
        addUnit(
            id: "bluefor-fpv-strike-squad",
            name: "Birds of Magyar (FPV Strike Company)",
            callsign: "Hornet-9",
            faction: .bluefor,
            unitType: .fpvPlatoon,
            echelon: .company,
            x: -1200, y: 0, z: 200,
            personnel: 45, vehicles: 4, armor: 10, softAtk: 80, hardAtk: 95
        )
        
        // --- REDFOR (74th Motor Rifle Brigade & 120th Artillery) ---
        addUnit(
            id: "redfor-74th-motor-bde",
            name: "74th Guards Motor Rifle Brigade",
            callsign: "Zarya-74",
            faction: .redfor,
            unitType: .mechInfantry,
            echelon: .brigade,
            x: 2800, y: 0, z: 1200,
            personnel: 3500, vehicles: 140, armor: 60, softAtk: 70, hardAtk: 55
        )
        
        addUnit(
            id: "redfor-90th-tank-btn",
            name: "90th Guard Tank Battalion (T-90M / T-72B3)",
            callsign: "Ural-90",
            faction: .redfor,
            unitType: .armor,
            echelon: .battalion,
            x: 2200, y: 0, z: 500,
            personnel: 450, vehicles: 31, armor: 120, softAtk: 50, hardAtk: 85
        )
        
        addUnit(
            id: "redfor-120th-arty-battery",
            name: "120th Artillery Battery (2S19 Msta-S)",
            callsign: "Molot-12",
            faction: .redfor,
            unitType: .tubeArtillery,
            echelon: .battery,
            x: 5000, y: 0, z: 2500,
            personnel: 110, vehicles: 12, armor: 20, softAtk: 90, hardAtk: 80
        )
        artilleryBatteries["redfor-120th-arty-battery"] = ArtilleryBatteryComponent(caliberMm: 152, maxRangeM: 29000, reloadTimeSec: 7.0, dispersionCepM: 25.0)
        
        addUnit(
            id: "redfor-ew-krasukha",
            name: "EW Complex (Krasukha-4 / Pole-21)",
            callsign: "Zaslon-4",
            faction: .redfor,
            unitType: .ewCompany,
            echelon: .company,
            x: 3500, y: 0, z: 1800,
            personnel: 60, vehicles: 8, armor: 25, softAtk: 10, hardAtk: 5
        )
        ewEmitters["redfor-ew-krasukha"] = ElectronicWarfareComponent(jammingRadius: 7500, powerDbm: 95, isTransmitting: true)
        
        // Drones
        addDrone(id: "drone-shark-recon-1", parentId: "bluefor-3rd-assault-bde", type: .reconFixedWing, faction: .bluefor, x: -800, y: 350, z: -200)
        addDrone(id: "drone-fpv-kamikaze-1", parentId: "bluefor-fpv-strike-squad", type: .fpvKamikaze, faction: .bluefor, x: -200, y: 80, z: 100, payloadPenetration: 130, payloadDamage: 90)
        addDrone(id: "drone-orlan-recon-2", parentId: "redfor-74th-motor-bde", type: .reconFixedWing, faction: .redfor, x: 800, y: 400, z: 400)
        
        // Supply Depots
        var blueDepot = Warbase_SupplyDepotState()
        blueDepot.depotID = "depot-bluefor-forward"
        blueDepot.faction = "BLUEFOR"
        blueDepot.x = -4000
        blueDepot.z = -1500
        blueDepot.ammoTons = 450
        blueDepot.fuelTons = 300
        blueDepot.droneBatteries = 500
        supplyDepots.append(blueDepot)
        
        var redDepot = Warbase_SupplyDepotState()
        redDepot.depotID = "depot-redfor-forward"
        redDepot.faction = "REDFOR"
        redDepot.x = 4500
        redDepot.z = 2000
        redDepot.ammoTons = 500
        redDepot.fuelTons = 350
        redDepot.droneBatteries = 400
        supplyDepots.append(redDepot)
        
        // Fortifications & Surovikin / Donbas Defense Lines
        var trench1 = Warbase_FortificationState()
        trench1.fortID = "trench-surovikin-line-1"
        trench1.x1 = 500; trench1.z1 = -2000
        trench1.x2 = 600; trench1.z2 = 2000
        trench1.type = "TRENCH"
        trench1.integrity = 100.0
        fortifications.append(trench1)
        
        var minefield = Warbase_FortificationState()
        minefield.fortID = "minefield-at-sector-a"
        minefield.x1 = 200; minefield.z1 = -1000
        minefield.x2 = 300; minefield.z2 = 1000
        minefield.type = "MINEFIELD_AT"
        minefield.integrity = 100.0
        fortifications.append(minefield)
    }
    
    private func addUnit(
        id: String, name: String, callsign: String, faction: Faction,
        unitType: UnitType, echelon: Echelon, x: Float, y: Float, z: Float,
        personnel: Int32, vehicles: Int32, armor: Float, softAtk: Float, hardAtk: Float
    ) {
        identities[id] = UnitIdentityComponent(id: id, name: name, callsign: callsign, faction: faction, unitType: unitType, echelon: echelon)
        transforms[id] = TransformComponent(x: x, y: y, z: z)
        combatStats[id] = CombatStatsComponent(health: 100.0, personnel: personnel, vehicles: vehicles, armorRating: armor, softAttack: softAtk, hardAttack: hardAtk)
        sensors[id] = SensorComponent(opticalRange: 4000, thermalRange: 2500, radarRange: unitType == .shorad ? 15000 : 0)
        supplies[id] = SupplyComponent()
        orderQueues[id] = OrderQueueComponent()
    }
    
    private func addDrone(id: String, parentId: String, type: DroneType, faction: Faction, x: Float, y: Float, z: Float, payloadPenetration: Float = 0, payloadDamage: Float = 0) {
        droneIdentities[id] = UnitIdentityComponent(id: id, name: "\(type.rawValue) #\(id.suffix(4))", callsign: "UAV-\(id.suffix(3))", faction: faction, unitType: .droneRecon, echelon: .platoon, parentId: parentId)
        droneTransforms[id] = TransformComponent(x: x, y: y, z: z, speed: type == .fpvKamikaze ? 45.0 : 25.0)
        dronePlatforms[id] = DronePlatformComponent(droneType: type, payloadPenetration: payloadPenetration, payloadDamage: payloadDamage)
    }
    
    func handleCommanderOrder(_ order: Warbase_CommanderOrderEvent) {
        let unitId = order.unitID
        guard var transform = transforms[unitId] else { return }
        
        switch order.orderType {
        case "MOVE", "ASSAULT":
            transform.targetX = order.targetX
            transform.targetZ = order.targetZ
            transforms[unitId] = transform
            if var stats = combatStats[unitId] {
                stats.status = .moving
                stats.entrenchmentLevel = 0
                combatStats[unitId] = stats
            }
            
        case "ENTRENCH":
            transform.targetX = nil
            transform.targetZ = nil
            transforms[unitId] = transform
            if var stats = combatStats[unitId] {
                stats.status = .entrenching
                stats.entrenchmentLevel = min(3, stats.entrenchmentLevel + 1)
                combatStats[unitId] = stats
            }
            
        case "FIRE_MISSION":
            guard var battery = artilleryBatteries[unitId] else { return }
            let origin = transform
            let dx = order.targetX - origin.x
            let dz = order.targetZ - origin.z
            let distance = sqrt(dx * dx + dz * dz)
            
            if distance <= battery.maxRangeM {
                let flightTime = 10.0 + (distance / 500.0)
                let mission = FireMission(
                    missionId: order.orderID.isEmpty ? UUID().uuidString : order.orderID,
                    targetX: order.targetX,
                    targetY: order.targetY,
                    targetZ: order.targetZ,
                    munitionType: order.munitionType.isEmpty ? "HE" : order.munitionType,
                    totalRounds: max(1, order.roundsCount),
                    roundsFired: 0,
                    flightTimeSec: flightTime,
                    timeToImpact: flightTime,
                    dispersionCep: battery.dispersionCepM
                )
                battery.activeMissions.append(mission)
                artilleryBatteries[unitId] = battery
                
                if var stats = combatStats[unitId] {
                    stats.status = .firing
                    combatStats[unitId] = stats
                }
            }
            
        case "LAUNCH_DRONE":
            let droneId = "drone-uav-\(UUID().uuidString.prefix(6))"
            let faction = identities[unitId]?.faction ?? .bluefor
            addDrone(
                id: droneId,
                parentId: unitId,
                type: order.munitionType == "FPV_STRIKE" ? .fpvKamikaze : .reconQuadcopter,
                faction: faction,
                x: transform.x,
                y: 150.0,
                z: transform.z,
                payloadPenetration: 120,
                payloadDamage: 85
            )
            
        case "ACTIVATE_EW":
            if var ew = ewEmitters[unitId] {
                ew.isTransmitting.toggle()
                ewEmitters[unitId] = ew
            }
            
        default:
            break
        }
    }
    
    func tick(deltaTime: Float) {
        tickCount += 1
        
        // 1. Movement System
        movementSystem.update(transforms: &transforms, combatStats: &combatStats, supplies: &supplies, deltaTime: deltaTime)
        
        // 2. Electronic Warfare System
        ewSystem.update(
            ewIdentities: identities,
            ewComponents: ewEmitters,
            ewTransforms: transforms,
            droneIdentities: droneIdentities,
            dronePlatforms: &dronePlatforms,
            droneTransforms: droneTransforms
        )
        
        // 3. Sensor & Fog of War System
        sensorSystem.update(
            identities: identities,
            transforms: transforms,
            sensors: sensors,
            combatStats: combatStats,
            ewEmitters: ewEmitters,
            contacts: &contacts
        )
        
        // 4. Artillery Ballistics System
        var activeMissions: [Warbase_ActiveFireMission] = []
        var detonations: [Warbase_ArtilleryDetonationEvent] = []
        var counterBatteryAlerts: [Warbase_CounterBatteryAlert] = []
        artillerySystem.update(
            batteries: &artilleryBatteries,
            batteryTransforms: transforms,
            targetTransforms: transforms,
            combatStats: &combatStats,
            supplies: &supplies,
            activeMissionsOut: &activeMissions,
            detonationEvents: &detonations,
            counterBatteryEvents: &counterBatteryAlerts,
            deltaTime: deltaTime
        )
        
        // 5. Drone Platforms System
        var droneStrikes: [Warbase_DroneStrikeEvent] = []
        droneSystem.update(
            dronePlatforms: &dronePlatforms,
            droneTransforms: &droneTransforms,
            combatStats: &combatStats,
            droneStrikeEvents: &droneStrikes,
            deltaTime: deltaTime
        )
        
        // 6. Direct Combat System
        var destroyedUnits: [Warbase_UnitDestroyedEvent] = []
        combatSystem.update(
            identities: identities,
            combatStats: &combatStats,
            transforms: &transforms,
            supplies: &supplies,
            destroyedEvents: &destroyedUnits,
            deltaTime: deltaTime
        )
        
        // 7. Logistics Resupply System
        logisticsSystem.update(
            supplies: &supplies,
            transforms: transforms,
            depots: supplyDepots,
            deltaTime: deltaTime
        )
        
        // Broadcast Events
        for det in detonations {
            var msg = Warbase_ServerMessage()
            var evt = Warbase_TheatreEvent()
            evt.detonation = det
            msg.theatreEvent = evt
            broadcast(message: msg)
        }
        
        for strike in droneStrikes {
            var msg = Warbase_ServerMessage()
            var evt = Warbase_TheatreEvent()
            evt.droneStrike = strike
            msg.theatreEvent = evt
            broadcast(message: msg)
        }
        
        for alert in counterBatteryAlerts {
            var msg = Warbase_ServerMessage()
            var evt = Warbase_TheatreEvent()
            evt.counterBattery = alert
            msg.theatreEvent = evt
            broadcast(message: msg)
        }
        
        for destroyed in destroyedUnits {
            var msg = Warbase_ServerMessage()
            var evt = Warbase_TheatreEvent()
            evt.unitDestroyed = destroyed
            msg.theatreEvent = evt
            broadcast(message: msg)
        }
        
        // Build & Broadcast Authoritative Strategic Game State
        var gameState = Warbase_StrategicGameState()
        gameState.theatreID = id
        gameState.tick = tickCount
        gameState.theatreTime = Int64(Date().timeIntervalSince1970 * 1000)
        gameState.weather = "OVERCAST"
        gameState.operationalControlScore = 52.5
        gameState.supplyDepots = supplyDepots
        gameState.fortifications = fortifications
        gameState.contacts = contacts
        gameState.fireMissions = activeMissions
        
        // Populate Units
        for (uId, identity) in identities {
            guard let pos = transforms[uId],
                  let stats = combatStats[uId] else { continue }
            let sup = supplies[uId]
            
            var unitState = Warbase_TacticalUnitState()
            unitState.unitID = uId
            unitState.name = identity.name
            unitState.callsign = identity.callsign
            unitState.faction = identity.faction.rawValue
            unitState.unitType = identity.unitType.rawValue
            unitState.echelon = identity.echelon.rawValue
            unitState.x = pos.x
            unitState.y = pos.y
            unitState.z = pos.z
            unitState.heading = pos.heading
            unitState.healthPercent = stats.health
            unitState.personnelCount = stats.personnel
            unitState.vehiclesCount = stats.vehicles
            unitState.combatEffectiveness = (stats.health / 100.0) * (1.0 - stats.suppression * 0.5)
            unitState.suppressionLevel = stats.suppression
            unitState.moraleLevel = stats.morale
            unitState.ammoLevel = sup?.ammoLevel ?? 1.0
            unitState.fuelLevel = sup?.fuelLevel ?? 1.0
            unitState.batteryLevel = sup?.batteryLevel ?? 1.0
            unitState.entrenchmentLevel = stats.entrenchmentLevel
            unitState.status = stats.status.rawValue
            unitState.activeTargetID = stats.activeTargetId ?? ""
            unitState.isJammed = false
            unitState.isSpotted = true
            gameState.units[uId] = unitState
        }
        
        // Populate Drones
        for (dId, identity) in droneIdentities {
            guard let pos = droneTransforms[dId],
                  let platform = dronePlatforms[dId] else { continue }
            
            var droneState = Warbase_DroneState()
            droneState.droneID = dId
            droneState.parentUnitID = identity.parentId ?? ""
            droneState.droneType = platform.droneType.rawValue
            droneState.faction = identity.faction.rawValue
            droneState.x = pos.x
            droneState.y = pos.y
            droneState.z = pos.z
            droneState.heading = pos.heading
            droneState.batteryPercent = platform.batteryPercent
            droneState.signalQuality = platform.signalQuality
            droneState.laserDesignating = platform.isLaserDesignating
            droneState.status = platform.isDiving ? "DIVING" : (platform.signalQuality < 0.15 ? "LOST_SIGNAL" : "CRUISING")
            gameState.drones[dId] = droneState
        }
        
        // Populate EW Emitters
        for (ewId, ew) in ewEmitters {
            guard let pos = transforms[ewId],
                  let identity = identities[ewId] else { continue }
            var ewState = Warbase_EWEmitterState()
            ewState.emitterID = ewId
            ewState.unitID = ewId
            ewState.faction = identity.faction.rawValue
            ewState.centerX = pos.x
            ewState.centerZ = pos.z
            ewState.jammingRadius = ew.jammingRadius
            ewState.powerDbm = ew.powerDbm
            ewState.gpsDenied = ew.gpsDenied
            gameState.ewEmitters.append(ewState)
        }
        
        var serverMsg = Warbase_ServerMessage()
        serverMsg.gameState = gameState
        broadcast(message: serverMsg)
    }
    
    func broadcast(message: Warbase_ServerMessage) {
        do {
            let data = try message.serializedData()
            let buf = ByteBuffer(bytes: data)
            for (_, session) in sessions {
                session.send(buf)
            }
        } catch {
            print("Serialization error in theatre \(id): \(error)")
        }
    }
}
