import SwiftUI

/// Manages all lobby/menu state. Single source of truth for the menu UI.
final class LobbyViewModel: ObservableObject {
    // MARK: - Player
    @Published var callsign: String {
        didSet { UserDefaults.standard.set(callsign, forKey: "warbase_callsign") }
    }
    @Published var showCallsignEditor = false
    @Published var editingCallsign = ""

    // MARK: - Navigation
    @Published var activeTab = 0 // 0=Loadouts, 1=Join, 2=Create

    // MARK: - Loadouts
    @Published var selectedClass = "ASSAULT"

    // MARK: - Join Match
    @Published var roomID = ""

    // MARK: - Create Match
    @Published var createMatchName = ""
    @Published var selectedMap = "industrial"
    @Published var selectedGameMode = "FFA"

    // MARK: - Loading
    @Published var isLoading = false
    @Published var loadingStatus = "Connecting to server..."

    // MARK: - Init
    init() {
        let saved = UserDefaults.standard.string(forKey: "warbase_callsign") ?? "OPERATOR"
        _callsign = Published(initialValue: saved)
    }

    func saveCallsign() {
        callsign = editingCallsign.uppercased()
    }

    func startLoading() {
        isLoading = true
        loadingStatus = "Initializing network..."
    }

    func finishLoading() {
        isLoading = false
    }
}
