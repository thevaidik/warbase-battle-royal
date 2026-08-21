import SwiftUI

struct HUDView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack {
            // Top: kill feed
            HStack {
                Spacer()
                if viewModel.showKillFeed && !viewModel.killFeedText.isEmpty {
                    Text(viewModel.killFeedText)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                        .transition(.opacity)
                }
                Spacer()
            }
            .padding(.top, 20)

            Spacer()

            // Bottom HUD
            HStack {
                // Health (bottom-left)
                healthBar

                Spacer()

                // Crosshair
                crosshair

                Spacer()

                // Ammo (bottom-right)
                ammoDisplay
            }
            .padding(20)
        }
    }

    // MARK: - Health Bar

    private var healthBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundColor(viewModel.health > 30 ? .red : .red.opacity(0.8))
                Text("\(viewModel.health)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(viewModel.health > 30 ? .white : .red)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(viewModel.health > 30 ? Color.green : Color.red)
                        .frame(width: geo.size.width * CGFloat(viewModel.health) / 100.0, height: 6)
                }
            }
            .frame(width: 180, height: 6)
        }
        .padding(12)
        .background(Color.black.opacity(0.4))
        .cornerRadius(8)
    }

    // MARK: - Crosshair

    private var crosshair: some View {
        VStack(spacing: 4) {
            Rectangle().fill(viewModel.crosshairColor).frame(width: 2, height: 12)
            HStack(spacing: 6) {
                Rectangle().fill(viewModel.crosshairColor).frame(width: 12, height: 2)
                Rectangle().fill(Color.clear).frame(width: 8, height: 2)
                Rectangle().fill(viewModel.crosshairColor).frame(width: 12, height: 2)
            }
            Rectangle().fill(viewModel.crosshairColor).frame(width: 2, height: 12)
        }
    }

    // MARK: - Ammo Display

    private var ammoDisplay: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if viewModel.ping > 0 {
                Text("PING \(viewModel.ping)ms")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(viewModel.ping < 50 ? .green : (viewModel.ping < 100 ? .yellow : .red))
            }
            Text(viewModel.weaponName)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(viewModel.ammo)")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("/ \(viewModel.maxAmmo)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.4))
        .cornerRadius(8)
    }
}
