import SwiftUI

/// Root view. Shell that switches between lobby and game.
public struct ContentView: View {
    @StateObject private var lobbyVM = LobbyViewModel()
    @StateObject private var gameVM = GameViewModel()
    @StateObject private var networkManager = NetworkManager()
    @State private var inGame = false
    @State private var tabMonitor: Any?

    public init() {}

    public var body: some View {
        ZStack {
            if lobbyVM.isLoading {
                LoadingView(status: lobbyVM.loadingStatus)
            } else if inGame {
                GameContainerView(
                    username: lobbyVM.callsign,
                    roomID: lobbyVM.roomID,
                    selectedMap: lobbyVM.selectedMap,
                    selectedClass: lobbyVM.selectedClass,
                    networkManager: networkManager,
                    gameVM: gameVM,
                    lobbyVM: lobbyVM,
                    inGame: $inGame
                )
            } else {
                LobbyView(
                    viewModel: lobbyVM,
                    onlineCount: networkManager.gameState?.players.count ?? 1,
                    onDeploy: deploy
                )
            }
        }
        .frame(minWidth: 1100, minHeight: 700)
        .onAppear {
            installTabMonitor()
            if CommandLine.arguments.contains("--autodeploy") {
                NSLog("[WB-R] ContentView autodeploy scheduled")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { deploy() }
            }
        }
        .onDisappear { removeTabMonitor() }
    }

    // MARK: - Deploy

    private func deploy() {
        NSLog("[WB-R] deploy called")
        lobbyVM.startLoading()
        gameVM.weaponName = lobbyVM.selectedClass == "ASSAULT" ? "AK-47" : "M2010"
        gameVM.maxAmmo = lobbyVM.selectedClass == "ASSAULT" ? 30 : 5
        gameVM.setupNetworkCallbacks(networkManager)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            lobbyVM.loadingStatus = "Loading environment..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                lobbyVM.finishLoading()
                inGame = true
                NSLog("[WB-R] inGame true")
            }
        }
    }

    // MARK: - TAB Scoreboard toggle

    private func installTabMonitor() {
        #if os(macOS)
        tabMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event -> NSEvent? in
            if event.keyCode == 48 { // TAB
                DispatchQueue.main.async {
                    gameVM.showScoreboard.toggle()
                }
                return nil
            }
            return event
        }
        #endif
    }

    private func removeTabMonitor() {
        #if os(macOS)
        if let monitor = tabMonitor {
            NSEvent.removeMonitor(monitor)
        }
        #endif
    }
}
