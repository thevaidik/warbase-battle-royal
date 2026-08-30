import SwiftUI
import Combine

struct CombatFeedEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let message: String
    let type: EntryType
    
    enum EntryType {
        case artillery
        case drone
        case counterBattery
        case destroyed
    }
}

final class SandtableViewModel: ObservableObject {
    @Published var units: [String: Warbase_TacticalUnitState] = [:]
    @Published var drones: [String: Warbase_DroneState] = [:]
    @Published var fireMissions: [Warbase_ActiveFireMission] = []
    @Published var ewEmitters: [Warbase_EWEmitterState] = []
    @Published var supplyDepots: [Warbase_SupplyDepotState] = []
    @Published var fortifications: [Warbase_FortificationState] = []
    @Published var contacts: [Warbase_SensorContact] = []
    
    @Published var selectedUnitId: String?
    @Published var selectedDroneId: String?
    @Published var selectedTargetPos: SIMD3<Float>?
    
    @Published var activeDronePiP: Warbase_DroneState?
    @Published var isThermalMode: Bool = true
    @Published var isLaserLockActive: Bool = false
    
    @Published var combatFeed: [CombatFeedEntry] = []
    @Published var operationalControlScore: Float = 54.0
    @Published var weather: String = "OVERCAST (5°C)"
    @Published var ping: Int = 0
    @Published var isConnected: Bool = false
    
    let networkManager = NetworkManager()
    
    init() {
        seedInitialState()
        setupCallbacks()
    }
    
    func connect(host: String = "127.0.0.1:8081", room: String = "theatre-donbas") {
        networkManager.connect(username: "Commander_HQ", room: room, host: host)
        
        // Auto fallback to production tunnel if local server is offline
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self else { return }
            if !self.networkManager.isConnected && host.contains("127.0.0.1") {
                print("Local server offline, connecting to cloud production theatre at war.nxtlap.com...")
                self.networkManager.connect(username: "Commander_HQ", room: room, host: "war.nxtlap.com")
            }
        }
    }
    
    private func seedInitialState() {
        // BLUEFOR
        var b1 = Warbase_TacticalUnitState()
        b1.unitID = "bluefor-3rd-assault-bde"
        b1.name = "3rd Separate Assault Brigade"
        b1.callsign = "Trident-1"
        b1.faction = "BLUEFOR"
        b1.unitType = "MECH_INFANTRY"
        b1.echelon = "BRIGADE"
        b1.x = -2500; b1.z = -1000
        b1.healthPercent = 94.0
        b1.personnelCount = 3200; b1.vehiclesCount = 120
        b1.ammoLevel = 0.88; b1.fuelLevel = 0.74; b1.entrenchmentLevel = 1
        b1.status = "IDLE"
        units[b1.unitID] = b1
        selectedUnitId = b1.unitID
        
        var b2 = Warbase_TacticalUnitState()
        b2.unitID = "bluefor-47th-mech-btn"
        b2.name = "47th Mechanized Battalion (M2 Bradley)"
        b2.callsign = "Magura-47"
        b2.faction = "BLUEFOR"
        b2.unitType = "MECH_INFANTRY"
        b2.echelon = "BATTALION"
        b2.x = -1800; b2.z = -400
        b2.healthPercent = 88.0
        b2.personnelCount = 650; b2.vehiclesCount = 31
        b2.ammoLevel = 0.92; b2.fuelLevel = 0.81; b2.entrenchmentLevel = 2
        b2.status = "ENGAGED"
        units[b2.unitID] = b2
        
        var b3 = Warbase_TacticalUnitState()
        b3.unitID = "bluefor-44th-arty-battery"
        b3.name = "44th Artillery Battery (M777 Excalibur)"
        b3.callsign = "Thunder-44"
        b3.faction = "BLUEFOR"
        b3.unitType = "TUBE_ARTILLERY"
        b3.echelon = "BATTERY"
        b3.x = -4500; b3.z = -2000
        b3.healthPercent = 100.0
        b3.personnelCount = 95; b3.vehiclesCount = 8
        b3.ammoLevel = 0.65; b3.fuelLevel = 0.90
        b3.status = "FIRING"
        units[b3.unitID] = b3
        
        var b4 = Warbase_TacticalUnitState()
        b4.unitID = "bluefor-fpv-strike-squad"
        b4.name = "Birds of Magyar (FPV Strike Company)"
        b4.callsign = "Hornet-9"
        b4.faction = "BLUEFOR"
        b4.unitType = "FPV_PLATOON"
        b4.echelon = "COMPANY"
        b4.x = -1200; b4.z = 200
        b4.healthPercent = 100.0
        b4.personnelCount = 45; b4.vehiclesCount = 4
        b4.ammoLevel = 0.80; b4.batteryLevel = 0.95
        b4.status = "IDLE"
        units[b4.unitID] = b4
        
        // REDFOR
        var r1 = Warbase_TacticalUnitState()
        r1.unitID = "redfor-74th-motor-bde"
        r1.name = "74th Guards Motor Rifle Brigade"
        r1.callsign = "Zarya-74"
        r1.faction = "REDFOR"
        r1.unitType = "MECH_INFANTRY"
        r1.echelon = "BRIGADE"
        r1.x = 2800; r1.z = 1200
        r1.healthPercent = 82.0
        r1.personnelCount = 3100; r1.vehiclesCount = 110
        r1.ammoLevel = 0.70; r1.fuelLevel = 0.60; r1.entrenchmentLevel = 2
        r1.status = "ENGAGED"
        units[r1.unitID] = r1
        
        var r2 = Warbase_TacticalUnitState()
        r2.unitID = "redfor-90th-tank-btn"
        r2.name = "90th Guard Tank Battalion (T-90M)"
        r2.callsign = "Ural-90"
        r2.faction = "REDFOR"
        r2.unitType = "ARMORED"
        r2.echelon = "BATTALION"
        r2.x = 2200; r2.z = 500
        r2.healthPercent = 78.0
        r2.personnelCount = 410; r2.vehiclesCount = 28
        r2.ammoLevel = 0.75; r2.fuelLevel = 0.55
        r2.status = "MOVING"
        units[r2.unitID] = r2
        
        // DRONES
        var d1 = Warbase_DroneState()
        d1.droneID = "drone-shark-recon-1"
        d1.droneType = "RECON_FIXED_WING"
        d1.faction = "BLUEFOR"
        d1.x = -600; d1.y = 350; d1.z = -150
        d1.batteryPercent = 87.0
        d1.signalQuality = 0.94
        d1.status = "CRUISING"
        d1.heading = 0.85
        drones[d1.droneID] = d1
        activeDronePiP = d1
        selectedDroneId = d1.droneID
        
        // Initial Combat Log
        combatFeed.append(CombatFeedEntry(message: "Theatre Initialized: Donbas Operational Sector", type: .artillery))
        combatFeed.append(CombatFeedEntry(message: "44th Arty Battery engaged grid (2200, 500) with 155mm Excalibur", type: .artillery))
        combatFeed.append(CombatFeedEntry(message: "UAV Shark-1 active over forward edge of battle area (FEBA)", type: .drone))
    }
    
    private func setupCallbacks() {
        networkManager.onStateReceived = { [weak self] state in
            guard let self = self else { return }
            self.units = state.units
            self.drones = state.drones
            self.fireMissions = state.fireMissions
            self.ewEmitters = state.ewEmitters
            self.supplyDepots = state.supplyDepots
            self.fortifications = state.fortifications
            self.contacts = state.contacts
            self.operationalControlScore = state.operationalControlScore
            self.weather = state.weather
            self.ping = self.networkManager.ping
            self.isConnected = self.networkManager.isConnected
            
            if let droneId = self.selectedDroneId, let drone = state.drones[droneId] {
                self.activeDronePiP = drone
            } else if self.activeDronePiP == nil, let firstDrone = state.drones.values.first {
                self.activeDronePiP = firstDrone
            }
        }
        
        networkManager.onDetonationReceived = { [weak self] det in
            guard let self = self else { return }
            let entry = CombatFeedEntry(
                message: "Artillery Impact: \(det.munitionType) at (\(Int(det.x)), \(Int(det.z))) - Casualties: \(det.casualties)",
                type: .artillery
            )
            self.addFeed(entry)
        }
        
        networkManager.onDroneStrikeReceived = { [weak self] strike in
            guard let self = self else { return }
            let entry = CombatFeedEntry(
                message: "FPV Strike on \(strike.targetUnitID) - Penetration: \(strike.armorPenetrated ? "YES" : "NO") (\(Int(strike.damageDealt)) dmg)",
                type: .drone
            )
            self.addFeed(entry)
        }
        
        networkManager.onCounterBatteryReceived = { [weak self] cb in
            guard let self = self else { return }
            let entry = CombatFeedEntry(
                message: "Counter-Battery Radar Lock! Firing origin: (\(Int(cb.detectedOriginX)), \(Int(cb.detectedOriginZ)))",
                type: .counterBattery
            )
            self.addFeed(entry)
        }
        
        networkManager.onUnitDestroyedReceived = { [weak self] dest in
            guard let self = self else { return }
            let entry = CombatFeedEntry(
                message: "UNIT DESTROYED: \(dest.unitName) [\(dest.faction)] by \(dest.cause)",
                type: .destroyed
            )
            self.addFeed(entry)
        }
    }
    
    private func addFeed(_ entry: CombatFeedEntry) {
        combatFeed.insert(entry, at: 0)
        if combatFeed.count > 25 {
            combatFeed.removeLast()
        }
    }
    
    func orderMoveSelected(to target: SIMD3<Float>) {
        guard let unitId = selectedUnitId else { return }
        networkManager.sendOrder(unitId: unitId, orderType: "MOVE", targetX: target.x, targetY: target.y, targetZ: target.z)
    }
    
    func orderFireMission(batteryId: String, target: SIMD3<Float>, munition: String = "HE", rounds: Int32 = 4) {
        networkManager.sendOrder(
            unitId: batteryId,
            orderType: "FIRE_MISSION",
            targetX: target.x,
            targetY: target.y,
            targetZ: target.z,
            munitionType: munition,
            roundsCount: rounds
        )
    }
    
    func orderEntrench(unitId: String) {
        networkManager.sendOrder(unitId: unitId, orderType: "ENTRENCH")
        if var u = units[unitId] {
            u.entrenchmentLevel = min(3, u.entrenchmentLevel + 1)
            u.status = "ENTRENCHING"
            units[unitId] = u
        }
    }
    
    func orderLaunchDrone(unitId: String, fpvStrike: Bool = false) {
        networkManager.sendOrder(unitId: unitId, orderType: "LAUNCH_DRONE", munitionType: fpvStrike ? "FPV_STRIKE" : "RECON")
    }
    
    func toggleEW(unitId: String) {
        networkManager.sendOrder(unitId: unitId, orderType: "ACTIVATE_EW")
    }
}
