import SwiftUI

public struct ContentView: View {
    @State private var username = "Player"
    @State private var roomID = ""
    @State private var selectedMap = "Original"
    @State private var selectedClass = "ASSAULT"
    @State private var inGame = false
    
    let maps = ["Original", "Industrial", "Village", "Arena", "Ghost City"]
    let classes = ["ASSAULT", "SCOUT"]
    
    // HUD States
    @State private var health: Int = 100
    @State private var ammo: Int = 30
    @State private var isADS = false
    @State private var showScoreboard = false
    @State private var isDead = false
    @State private var respawnTime = 3
    // Network
    @StateObject private var networkManager = NetworkManager()
    
    // Graphics Settings
    @State private var useSSAO = true
    @State private var useSSR = false
    @State private var useMSAA = true
    @State private var useAnisotropic = true
    
    // Dynamic Crosshair / Killfeed
    @State private var crosshairColor: Color = .white
    @State private var killFeedText: String = ""
    
    public init() {}
    
    public var body: some View {
        if inGame {
            gameView
        } else {
            lobbyView
        }
    }
    
    private var lobbyView: some View {
        VStack(spacing: 20) {
            Text("WarBase")
                .font(.largeTitle)
                .bold()
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 250)
            
            TextField("Room ID", text: $roomID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 250)
            
            Picker("Map", selection: $selectedMap) {
                ForEach(maps, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Picker("Class", selection: $selectedClass) {
                ForEach(classes, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Text(selectedClass == "ASSAULT" ? "Weapon: AK47\nBalanced assault rifle." : "Weapon: M2010\nHigh-power sniper rifle.")
                .multilineTextAlignment(.center)
            
            WeaponPreview3D(weaponName: selectedClass == "ASSAULT" ? "ak47" : "m2010")
                .frame(height: 200)
            
            VStack {
                Toggle("SSAO", isOn: $useSSAO)
                Toggle("SSR", isOn: $useSSR)
                Toggle("MSAA", isOn: $useMSAA)
                Toggle("Anisotropic", isOn: $useAnisotropic)
            }.frame(width: 200)
            
            Button("Join Game") {
                setupNetworkCallbacks()
                inGame = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private func setupNetworkCallbacks() {
        networkManager.onHitConfirmed = { targetId, damage in
            crosshairColor = .red
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                crosshairColor = .white
            }
        }
        networkManager.onKillConfirmed = { targetId in
            crosshairColor = .red
            killFeedText = "You killed \(targetId)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                crosshairColor = .white
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if killFeedText.contains(targetId) { killFeedText = "" }
            }
        }
        networkManager.onRespawn = {
            isDead = false
            health = 100
            ammo = selectedClass == "ASSAULT" ? 30 : 5
        }
        networkManager.onStateReceived = { state in
            if let winner = state.winnerId {
                killFeedText = "Winner: \(winner)!"
            }
        }
    }
    
    private var gameView: some View {
        ZStack {
            // Engine Render
            GameSceneView(
                username: username,
                roomID: roomID,
                selectedMap: selectedMap,
                selectedClass: selectedClass,
                health: $health,
                ammo: $ammo,
                isDead: $isDead
            ).edgesIgnoringSafeArea(.all)
            
            ScopeOverlay(isVisible: $isADS)
            
            // HUD
            VStack {
                HStack {
                    Text("Health: \(health)")
                        .foregroundColor(health > 30 ? .green : .red)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                    Spacer()
                    if !killFeedText.isEmpty {
                        Text(killFeedText)
                            .font(.caption)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                Spacer()
                HStack {
                    // Virtual Joystick Left
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(Circle().fill(Color.white).frame(width: 40, height: 40))
                    
                    Spacer()
                    
                    VStack {
                        Text("Ammo: \(ammo)")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                        
                        HStack {
                            Button("Grenade") { }
                            Button("Reload") { ammo = 30 }
                        }
                        
                        HStack {
                            Button("ADS") { isADS.toggle() }
                            Button("FIRE") { ammo = max(0, ammo - 1) }
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                    }
                }
            }.padding()
            
            if isDead {
                VStack {
                    Text("YOU DIED")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Respawning in \(respawnTime)s")
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.8))
            }
            
            if showScoreboard {
                VStack {
                    Text("Scoreboard")
                        .font(.title)
                    HStack {
                        VStack {
                            Text("Team A").bold()
                            Text("Score: \(networkManager.gameState?.scoreTeamA ?? 0)")
                            ForEach(networkManager.gameState?.players.filter { $0.value.team == "A" }.map { $0.value } ?? [], id: \.id) { p in
                                Text("\(p.id) - \(p.kills)/\(p.deaths)")
                            }
                        }
                        Spacer()
                        VStack {
                            Text("Team B").bold()
                            Text("Score: \(networkManager.gameState?.scoreTeamB ?? 0)")
                            ForEach(networkManager.gameState?.players.filter { $0.value.team == "B" }.map { $0.value } ?? [], id: \.id) { p in
                                Text("\(p.id) - \(p.kills)/\(p.deaths)")
                            }
                        }
                    }
                }
                .padding()
                .frame(width: 400, height: 300)
                .background(Color.black.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(15)
            }
            
            // Dynamic Crosshair overlay
            VStack {
                Rectangle().fill(crosshairColor).frame(width: 2, height: 10)
                HStack {
                    Rectangle().fill(crosshairColor).frame(width: 10, height: 2)
                    Rectangle().fill(Color.clear).frame(width: 10, height: 2)
                    Rectangle().fill(crosshairColor).frame(width: 10, height: 2)
                }
                Rectangle().fill(crosshairColor).frame(width: 2, height: 10)
            }.frame(width: 40, height: 40)
        }
    }
}
