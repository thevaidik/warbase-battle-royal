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
    @Published var operationalControlScore: Float = 50.0
    @Published var weather: String = "OVERCAST"
    @Published var ping: Int = 0
    @Published var isConnected: Bool = false
    
    let networkManager = NetworkManager()
    
    init() {
        setupCallbacks()
    }
    
    func connect(host: String = "war.nxtlap.com", room: String = "theatre-donbas") {
        networkManager.connect(username: "Commander_HQ", room: room, host: host)
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
            
            // Update active drone feed if selected
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
    
    // Command Actions
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
    }
    
    func orderLaunchDrone(unitId: String, fpvStrike: Bool = false) {
        networkManager.sendOrder(unitId: unitId, orderType: "LAUNCH_DRONE", munitionType: fpvStrike ? "FPV_STRIKE" : "RECON")
    }
    
    func toggleEW(unitId: String) {
        networkManager.sendOrder(unitId: unitId, orderType: "ACTIVATE_EW")
    }
}
