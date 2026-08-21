import SwiftUI

/// The in-game ZStack: 3D engine + HUD + touch controls (iOS) + death screen + scoreboard + pause menu
struct GameContainerView: View {
    let username: String
    let roomID: String
    let selectedMap: String
    let selectedClass: String
    let networkManager: NetworkManager

    @ObservedObject var gameVM: GameViewModel
    @ObservedObject var lobbyVM: LobbyViewModel
    @Binding var inGame: Bool

    var body: some View {
        ZStack {
            RealityGameView(
                username: username,
                roomID: roomID,
                selectedMap: selectedMap,
                selectedClass: selectedClass,
                networkManager: networkManager,
                gameVM: gameVM
            )
            .edgesIgnoringSafeArea(.all)

            // HUD
            HUDView(viewModel: gameVM)
                .allowsHitTesting(false)

            // iOS Touch Controls (Virtual Joystick, Look Area, Action Triggers)
            #if os(iOS)
            MobileControlsView(gameVM: gameVM)
            #endif

            // Death screen
            if gameVM.isDead {
                VStack {
                    Text("ELIMINATED")
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundColor(.red).tracking(8)
                    Text("Respawning in \(gameVM.respawnTime)s")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7))
                .allowsHitTesting(false)
            }

            // Scoreboard (TAB)
            if gameVM.showScoreboard {
                ScoreboardView(players: gameVM.players, username: username)
            }

            // Pause menu (ESC)
            if gameVM.showPauseMenu {
                PauseMenuView(gameVM: gameVM) {
                    InputManager.unlockCursor()
                    InputManager.setPauseMenuActive(false)
                    InputManager.onCleanup?()
                    InputManager.remove()
                    networkManager.disconnect()
                    gameVM.showPauseMenu = false
                    gameVM.showScoreboard = false
                    lobbyVM.isLoading = false
                    lobbyVM.loadingStatus = "Connecting to server..."
                    inGame = false
                }
            }
        }
        .onAppear {
            #if os(macOS)
            InputManager.lockCursor()
            #endif
        }
    }
}
