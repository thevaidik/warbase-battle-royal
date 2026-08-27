import SwiftUI

public struct RoomInfo: Identifiable, Decodable, Hashable {
    public let id: String
    public let name: String
    public let map: String
    public let playerCount: Int
    public let mode: String?

    public init(id: String, name: String, map: String, playerCount: Int, mode: String? = nil) {
        self.id = id
        self.name = name
        self.map = map
        self.playerCount = playerCount
        self.mode = mode
    }
}

private struct RoomsResponse: Decodable {
    let rooms: [RoomInfo]?
    let online_players: Int?
}

/// Manages all lobby/menu state. Single source of truth for the menu UI.
final class LobbyViewModel: ObservableObject {
    // MARK: - Player
    @Published var callsign: String {
        didSet { /* coalesced: saved only on saveCallsign() */ }
    }
    @Published var showCallsignEditor = false
    @Published var editingCallsign = ""

    // MARK: - Navigation
    @Published var activeTab = 0 // 0=Loadouts, 1=Join, 2=Create

    // MARK: - Loadouts
    @Published var selectedClass = "ASSAULT"

    // MARK: - Join Match
    @Published var roomID = ""
    @Published var serverHost: String {
        didSet {
            UserDefaults.standard.set(serverHost, forKey: "warbase_host")
            checkServer()
            fetchRooms()
        }
    }

    // MARK: - Rooms
    @Published var availableRooms: [RoomInfo] = []
    @Published var onlinePlayersCount: Int = 0
    @Published var isFetchingRooms = false

    // MARK: - Create Match
    @Published var createMatchName = ""
    @Published var selectedMap = "industrial"
    @Published var selectedGameMode = "FFA"
    @Published var isCreatingRoom = false
    @Published var createError: String? = nil

    // MARK: - Server Status
    @Published var serverOnline = false
    @Published var serverCheckedHost = ""

    // MARK: - Loading
    @Published var isLoading = false
    @Published var loadingStatus = "Connecting to server..."

    private var healthCheckTimer: Timer?

    // MARK: - Init
    init() {
        let saved = UserDefaults.standard.string(forKey: "warbase_callsign") ?? "OPERATOR"
        _callsign = Published(initialValue: saved)
        var host = UserDefaults.standard.string(forKey: "warbase_host") ?? "war.nxtlap.com"
        if host == "localhost:8081" || host == "localhost" || host.isEmpty || host == "warbase.nxtlap.com" {
            host = "war.nxtlap.com"
            UserDefaults.standard.set(host, forKey: "warbase_host")
        }
        _serverHost = Published(initialValue: host)
        checkServer()
        fetchRooms()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.checkServer()
            self?.fetchRooms()
        }
    }

    deinit {
        healthCheckTimer?.invalidate()
    }

    func checkServer() {
        let host = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let h = host.isEmpty ? "war.nxtlap.com" : host
        serverCheckedHost = h
        let scheme = h.hasPrefix("localhost") || h.hasPrefix("127.") ? "http" : "https"
        let clean = h.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "wss://", with: "").replacingOccurrences(of: "ws://", with: "")
        guard let url = URL(string: "\(scheme)://\(clean)/healthcheck") else { serverOnline = false; return }
        var req = URLRequest(url: url, timeoutInterval: 3)
        req.httpMethod = "GET"
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, _ in
            DispatchQueue.main.async {
                if let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    self?.serverOnline = true
                } else {
                    self?.serverOnline = false
                }
            }
        }.resume()
    }

    func fetchRooms() {
        let host = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let h = host.isEmpty ? "war.nxtlap.com" : host
        let scheme = h.hasPrefix("localhost") || h.hasPrefix("127.") ? "http" : "https"
        let clean = h.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "wss://", with: "").replacingOccurrences(of: "ws://", with: "")
        
        let cid: String = {
            if let saved = UserDefaults.standard.string(forKey: "warbase_client_id") { return saved }
            let fresh = UUID().uuidString; UserDefaults.standard.set(fresh, forKey: "warbase_client_id"); return fresh
        }()
        
        guard let url = URL(string: "\(scheme)://\(clean)/api/rooms?cid=\(cid)") else { return }
        isFetchingRooms = true
        var req = URLRequest(url: url, timeoutInterval: 4)
        req.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isFetchingRooms = false
                guard let data = data, let resp = resp as? HTTPURLResponse, (200...299).contains(resp.statusCode) else {
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(RoomsResponse.self, from: data)
                    let roomsList = decoded.rooms ?? []
                    self.availableRooms = roomsList
                    if let count = decoded.online_players {
                        self.onlinePlayersCount = count
                    }
                    if self.roomID.isEmpty && !roomsList.isEmpty {
                        self.roomID = roomsList[0].id
                        self.selectedMap = roomsList[0].map
                    }
                } catch {
                    print("Failed to decode /api/rooms: \(error)")
                }
            }
        }.resume()
    }

    func createMatch(onSuccess: @escaping () -> Void) {
        let host = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let h = host.isEmpty ? "war.nxtlap.com" : host
        let scheme = h.hasPrefix("localhost") || h.hasPrefix("127.") ? "http" : "https"
        let clean = h.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "wss://", with: "").replacingOccurrences(of: "ws://", with: "")
        
        guard let url = URL(string: "\(scheme)://\(clean)/api/rooms") else { return }
        
        let matchName = createMatchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Operation \(selectedMap.capitalized)" : createMatchName
        let payload: [String: String] = [
            "name": matchName,
            "map": selectedMap,
            "mode": selectedGameMode
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return }
        
        isCreatingRoom = true
        createError = nil
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = httpBody
        
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isCreatingRoom = false
                if let error = error {
                    self.createError = error.localizedDescription
                    return
                }
                guard let data = data, let resp = resp as? HTTPURLResponse, (200...299).contains(resp.statusCode) else {
                    self.createError = "Server rejected room creation"
                    return
                }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let roomId = json["room_id"] as? String {
                    self.roomID = roomId
                    self.fetchRooms()
                    onSuccess()
                } else {
                    self.createError = "Invalid response from server"
                }
            }
        }.resume()
    }

    func saveCallsign() {
        callsign = editingCallsign.uppercased()
        UserDefaults.standard.set(callsign, forKey: "warbase_callsign")
    }

    func startLoading() {
        isLoading = true
        loadingStatus = "Initializing network..."
    }

    func finishLoading() {
        isLoading = false
    }
}
