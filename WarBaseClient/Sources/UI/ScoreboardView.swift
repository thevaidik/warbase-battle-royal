import SwiftUI

struct ScoreboardView: View {
    let players: [NetworkPlayerState]
    let username: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SCOREBOARD")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .tracking(2)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.15))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("OPERATOR").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.gray)
                    Spacer()
                    Text("K").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.gray).frame(width: 30, alignment: .trailing)
                    Text("D").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.gray).frame(width: 30, alignment: .trailing)
                    Text("PING").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.gray).frame(width: 40, alignment: .trailing)
                }
                .padding(.horizontal, 16)

                ForEach(players, id: \.id) { player in
                    ScoreboardRowView(player: player, isCurrent: player.id == username)
                }
            }
            .padding(16)
        }
        .frame(width: 420, height: 320)
        .background(Color.black.opacity(0.85))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

struct ScoreboardRowView: View {
    let player: NetworkPlayerState
    let isCurrent: Bool

    private var nameColor: Color {
        if isCurrent { return .red }
        return player.isDead ? Color.gray.opacity(0.4) : Color.white
    }

    private var pingColor: Color {
        if player.ping < 50 { return .green }
        if player.ping < 100 { return .yellow }
        return .red
    }

    var body: some View {
        HStack {
            HStack(spacing: 0) {
                if isCurrent {
                    Text("▸ ").foregroundColor(.red).font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                Text(player.id)
            }
            .font(.system(size: 12, weight: isCurrent ? .bold : .regular, design: .monospaced))
            .foregroundColor(nameColor)

            Spacer()

            Text("\(player.kills)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 30, alignment: .trailing)
            Text("\(player.deaths)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 30, alignment: .trailing)
            Text("\(player.ping)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(pingColor)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }
}
