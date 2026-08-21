import SwiftUI

/// In-game pause menu overlay. Shows when ESC is pressed.
struct PauseMenuView: View {
    @ObservedObject var gameVM: GameViewModel
    var onExit: () -> Void

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("PAUSED")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                    .tracking(10)

                Divider()
                    .frame(width: 200)
                    .background(Color.red.opacity(0.6))

                VStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            gameVM.showPauseMenu = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            InputManager.setPauseMenuActive(false)
                            #if os(macOS)
                            InputManager.lockCursor()
                            #endif
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("RESUME")
                        }
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 260, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            gameVM.showPauseMenu = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            InputManager.setPauseMenuActive(false)
                            #if os(macOS)
                            InputManager.unlockCursor()
                            #endif
                            onExit()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.left.circle.fill")
                            Text("EXIT TO LOBBY")
                        }
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .frame(width: 260, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.red.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .transition(.opacity)
    }
}
