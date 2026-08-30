import SwiftUI

struct SandtableHUDView: View {
    @ObservedObject var viewModel: SandtableViewModel
    
    init(viewModel: SandtableViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // TOP BAR: Operational Overview
            VStack {
                topTheatreHeader
                Spacer()
            }
            
            // LEFT & RIGHT PANELS
            HStack(alignment: .top) {
                leftBrigadePanel
                    .frame(width: 340)
                
                Spacer()
                
                rightDroneAndCombatPanel
                    .frame(width: 360)
            }
            .padding(.top, 70)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Top Header
    private var topTheatreHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("WARBASE: OPERATIONAL THEATRE")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                Text("DONBAS SECTOR • 60Hz AUTHORITATIVE SIMULATION")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Operational Control Balance
            VStack(spacing: 4) {
                HStack {
                    Text("BLUEFOR \(Int(viewModel.operationalControlScore))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Spacer()
                    Text("REDFOR \(100 - Int(viewModel.operationalControlScore))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                }
                .frame(width: 260)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.red.opacity(0.8))
                        Rectangle()
                            .fill(Color.cyan.opacity(0.9))
                            .frame(width: geo.size.width * CGFloat(viewModel.operationalControlScore / 100.0))
                    }
                    .cornerRadius(4)
                }
                .frame(width: 260, height: 8)
            }
            
            Spacer()
            
            // Environment & Ping Telemetry
            HStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("WEATHER: \(viewModel.weather)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("RTT: \(viewModel.ping) ms")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(viewModel.ping < 50 ? .green : .orange)
                }
                
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
    
    // MARK: - Left Brigade & Unit Details Panel
    private var leftBrigadePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ORDER OF BATTLE")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.cyan)
            
            if let unitId = viewModel.selectedUnitId, let unit = viewModel.units[unitId] {
                unitDetailCard(unit)
            } else {
                Text("Tap any unit counter on the holographic sandtable to view combat readiness and issue operational orders.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            Text("ACTIVE FORMATIONS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.units.values.sorted { $0.name < $1.name }, id: \.unitID) { u in
                        Button(action: { viewModel.selectedUnitId = u.unitID }) {
                            HStack {
                                Circle()
                                    .fill(u.faction == "BLUEFOR" ? Color.cyan : Color.red)
                                    .frame(width: 8, height: 8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(u.name)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text("\(u.echelon) • \(u.status)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Text("\(Int(u.healthPercent))%")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(u.healthPercent > 50 ? .green : .orange)
                            }
                            .padding(8)
                            .background(viewModel.selectedUnitId == u.unitID ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private func unitDetailCard(_ unit: Warbase_TacticalUnitState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text(unit.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("CALLSIGN: \(unit.callsign) [\(unit.faction)]")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                Spacer()
            }
            
            // Stats Grid
            HStack(spacing: 12) {
                statBox(title: "PERSONNEL", value: "\(unit.personnelCount)")
                statBox(title: "VEHICLES", value: "\(unit.vehiclesCount)")
                statBox(title: "TRENCH", value: "LVL \(unit.entrenchmentLevel)")
            }
            
            // Supply Meters
            VStack(spacing: 4) {
                meterRow(title: "AMMO", value: unit.ammoLevel, color: .yellow)
                meterRow(title: "FUEL", value: unit.fuelLevel, color: .orange)
            }
            
            // Action Command Buttons
            HStack(spacing: 8) {
                Button(action: { viewModel.orderEntrench(unitId: unit.unitID) }) {
                    Label("Entrench", systemImage: "shield.fill")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                Button(action: { viewModel.orderLaunchDrone(unitId: unit.unitID, fpvStrike: true) }) {
                    Label("FPV Drone", systemImage: "airplane")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                
                if unit.unitType == "EW_COMPANY" {
                    Button(action: { viewModel.toggleEW(unitId: unit.unitID) }) {
                        Label("Jammer", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            }
            .padding(.top, 4)
        }
    }
    
    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(6)
    }
    
    private func meterRow(title: String, value: Float, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 45, alignment: .leading)
            ProgressView(value: Double(value), total: 1.0)
                .tint(color)
            Text("\(Int(value * 100))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 35, alignment: .trailing)
        }
    }
    
    // MARK: - Right Drone PiP & Real-Time Combat Feed Panel
    private var rightDroneAndCombatPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Simulated Thermal Drone PiP View
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("LIVE DRONE SURVEILLANCE")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.green)
                    Spacer()
                    if let drone = viewModel.activeDronePiP {
                        Text(drone.droneID)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                
                droneThermalFeedBox
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // Combat Events Feed
            Text("THEATRE COMBAT LOG")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.combatFeed) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(feedColor(for: entry.type))
                                .frame(width: 6, height: 6)
                                .padding(.top, 4)
                            Text(entry.message)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var droneThermalFeedBox: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.9))
                .frame(height: 170)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.6), lineWidth: 1)
                )
            
            if let drone = viewModel.activeDronePiP {
                VStack {
                    HStack {
                        Text("FLIR THERMAL • 60 FPS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Spacer()
                        Text("BAT: \(Int(drone.batteryPercent))% | SIG: \(Int(drone.signalQuality * 100))%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(drone.signalQuality > 0.4 ? .green : .red)
                    }
                    
                    Spacer()
                    
                    // Crosshairs
                    ZStack {
                        Circle()
                            .stroke(Color.green.opacity(0.8), lineWidth: 1)
                            .frame(width: 50, height: 50)
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 20, height: 1)
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 1, height: 20)
                    }
                    
                    Spacer()
                    
                    HStack {
                        Text("ALT: \(Int(drone.y))m AGL")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Spacer()
                        Text("HDG: \(Int(drone.heading * 180 / .pi))°")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
                .padding(10)
            } else {
                Text("NO ACTIVE UAV FEED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func feedColor(for type: CombatFeedEntry.EntryType) -> Color {
        switch type {
        case .artillery: return .orange
        case .drone: return .yellow
        case .counterBattery: return .purple
        case .destroyed: return .red
        }
    }
}
