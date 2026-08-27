import SwiftUI

/// Manages in-game HUD state. Updated by the render loop via DispatchQueue.main.async.
final class GameViewModel: ObservableObject {
    // MARK: - HUD
    @Published var health: Int = 100
    @Published var ammo: Int = 30
    @Published var isDead = false
    @Published var respawnTime = 3

    // MARK: - Killfeed
    @Published var killFeedText = ""
    @Published var showKillFeed = false

    // MARK: - Scoreboard
    @Published var showScoreboard = false

    // MARK: - Pause Menu
    @Published var showPauseMenu = false
    var onExitGame: (() -> Void)?

    // MARK: - Crosshair
    @Published var crosshairColor: Color = .white

    // MARK: - Network (read-only display)
    @Published var ping: Int = 0
    @Published var players: [NetworkPlayerState] = []

    // MARK: - Weapon display
    @Published var weaponName: String = "AK-47"
    @Published var maxAmmo: Int = 30
    @Published var isScoped: Bool = false

    // MARK: - Callbacks
    var onHitConfirmed: (() -> Void)?
    var onKillConfirmed: ((String) -> Void)?
    var onRespawn: (() -> Void)?

    func setupNetworkCallbacks(_ networkManager: NetworkManager) {
        networkManager.onHitConfirmed = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.crosshairColor = .red
                self?.showKillFeed = true
                self?.killFeedText = "HIT!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.crosshairColor = .white
                }
            }
        }
        networkManager.onKillConfirmed = { [weak self] targetId in
            DispatchQueue.main.async {
                self?.crosshairColor = .red
                self?.killFeedText = "KILLED \(targetId)"
                self?.showKillFeed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self?.crosshairColor = .white
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if self?.killFeedText.contains(targetId) == true {
                        self?.showKillFeed = false
                        self?.killFeedText = ""
                    }
                }
            }
        }
        networkManager.onRespawn = { [weak self] x, y, z in
            DispatchQueue.main.async {
                self?.isDead = false
                self?.health = 100
                self?.respawnTime = 3
            }
        }
        networkManager.onStateReceived = { [weak self] state in
            DispatchQueue.main.async {
                self?.players = state.players.values.sorted { $0.kills > $1.kills }
                if state.winnerId != nil {
                    self?.killFeedText = "WINNER: \(state.winnerId!)"
                    self?.showKillFeed = true
                }
            }
        }
    }

    func setHealth(_ h: Int) {
        if self.health != h {
            DispatchQueue.main.async { self.health = h }
        }
    }

    func setAmmo(_ a: Int) {
        if self.ammo != a {
            DispatchQueue.main.async { self.ammo = a }
        }
    }

    func setDead(_ d: Bool) {
        if self.isDead != d {
            DispatchQueue.main.async { self.isDead = d }
        }
    }

    func setPing(_ p: Int) {
        if self.ping != p {
            DispatchQueue.main.async { self.ping = p }
        }
    }
}
