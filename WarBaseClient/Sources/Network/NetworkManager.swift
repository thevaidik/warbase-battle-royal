import Foundation
import Combine
import simd

final class NetworkManager: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    
    @Published var isConnected: Bool = false
    @Published var ping: Int = 0
    @Published var gameState: Warbase_StrategicGameState?
    
    // Event Callbacks
    var onStateReceived: ((Warbase_StrategicGameState) -> Void)?
    var onDetonationReceived: ((Warbase_ArtilleryDetonationEvent) -> Void)?
    var onDroneStrikeReceived: ((Warbase_DroneStrikeEvent) -> Void)?
    var onCounterBatteryReceived: ((Warbase_CounterBatteryAlert) -> Void)?
    var onUnitDestroyedReceived: ((Warbase_UnitDestroyedEvent) -> Void)?
    
    init() {}
    
    deinit {
        disconnect()
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.gameState = nil
        }
    }
    
    func connect(username: String = "Commander", room: String = "theatre-donbas", host: String = "127.0.0.1:8081") {
        disconnect()
        
        let cleanUser = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Commander"
        let cleanRoom = room.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "theatre-donbas"
        
        let scheme = host.contains("localhost") || host.contains("127.0.0.1") ? "ws" : "wss"
        guard let url = URL(string: "\(scheme)://\(host)/connect?user=\(cleanUser)&room=\(cleanRoom)") else { return }
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        DispatchQueue.main.async {
            self.isConnected = true
        }
        
        receiveMessage()
        startPingTimer()
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.handleIncomingData(data)
                default:
                    break
                }
                self.receiveMessage()
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
            }
        }
    }
    
    private func handleIncomingData(_ data: Data) {
        do {
            let serverMsg = try Warbase_ServerMessage(serializedBytes: data)
            switch serverMsg.message {
            case .gameState(let state):
                DispatchQueue.main.async {
                    self.gameState = state
                    self.onStateReceived?(state)
                }
            case .theatreEvent(let evt):
                DispatchQueue.main.async {
                    switch evt.event {
                    case .detonation(let det):
                        self.onDetonationReceived?(det)
                    case .droneStrike(let strike):
                        self.onDroneStrikeReceived?(strike)
                    case .counterBattery(let cb):
                        self.onCounterBatteryReceived?(cb)
                    case .unitDestroyed(let dest):
                        self.onUnitDestroyedReceived?(dest)
                    case .pong(let pong):
                        let now = Int64(Date().timeIntervalSince1970 * 1000)
                        self.ping = Int(now - pong.clientTime)
                    default:
                        break
                    }
                }
            default:
                break
            }
        } catch {
            print("Failed to decode Protobuf ServerMessage: \(error)")
        }
    }
    
    func sendOrder(
        unitId: String,
        orderType: String,
        targetX: Float = 0,
        targetY: Float = 0,
        targetZ: Float = 0,
        targetUnitId: String = "",
        munitionType: String = "HE",
        roundsCount: Int32 = 1,
        stance: String = "AGGRESSIVE"
    ) {
        var order = Warbase_CommanderOrderEvent()
        order.orderID = UUID().uuidString
        order.unitID = unitId
        order.orderType = orderType
        order.targetX = targetX
        order.targetY = targetY
        order.targetZ = targetZ
        order.targetUnitID = targetUnitId
        order.munitionType = munitionType
        order.roundsCount = roundsCount
        order.stance = stance
        
        var clientEvent = Warbase_ClientEvent()
        clientEvent.commanderOrder = order
        
        send(clientEvent)
    }
    
    func sendDroneControl(
        droneId: String,
        pitch: Float,
        yaw: Float,
        throttle: Float,
        laserDesignator: Bool = false,
        initiateDive: Bool = false
    ) {
        var ctrl = Warbase_DroneManualControlEvent()
        ctrl.droneID = droneId
        ctrl.pitch = pitch
        ctrl.yaw = yaw
        ctrl.throttle = throttle
        ctrl.laserDesignatorActive = laserDesignator
        ctrl.initiateDiveStrike = initiateDive
        
        var clientEvent = Warbase_ClientEvent()
        clientEvent.droneControl = ctrl
        send(clientEvent)
    }
    
    private func send(_ event: Warbase_ClientEvent) {
        guard let data = try? event.serializedData() else { return }
        webSocket?.send(.data(data)) { error in
            if let error = error {
                print("Failed to send WebSocket event: \(error)")
            }
        }
    }
    
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            var ping = Warbase_PingEvent()
            ping.clientTime = Int64(Date().timeIntervalSince1970 * 1000)
            var clientEvt = Warbase_ClientEvent()
            clientEvt.ping = ping
            self.send(clientEvt)
        }
    }
}
