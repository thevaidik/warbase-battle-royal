import Foundation
import Combine

public struct NetworkPlayerState {
    public var id: String
    public var x: Float
    public var y: Float
    public var z: Float
    public var rx: Float
    public var ry: Float
    public var rz: Float
    public var rw: Float
    public var anim: String
    public var health: Float
    public var kills: Int
    public var deaths: Int
    public var isDead: Bool
    public var platformId: String
    public var ping: Int
    public var weaponId: String
    public var team: String
}


public struct GameStateData {
    public var players: [String: NetworkPlayerState]
    public var roomMode: String
    public var roomState: String
    public var scoreTeamA: Int
    public var scoreTeamB: Int
    public var winnerId: String?
}


public class NetworkManager: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    
    @Published public var gameState: GameStateData?
    
    public var onStateReceived: ((GameStateData) -> Void)?
    public var onHitConfirmed: ((String, Float) -> Void)?
    public var onKillConfirmed: ((String) -> Void)?
    public var onRespawn: (() -> Void)?
    public var onFireReceived: ((String, [Float], [Float]) -> Void)?
    public var onGrenadeReceived: ((String, [Float], [Float]) -> Void)?
    
    public init() {}
    
    public func connect(url: URL) {
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        receiveMessage()
        
        pingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("WebSocket error: \(error)")
                self?.handleDisconnect()
            case .success(let message):
                switch message {
                case .data(let data):
                    self?.handleBinaryData(data)
                case .string(let str):
                    print("Received string: \(str)")
                @unknown default:
                    break
                }
                self?.receiveMessage()
            }
        }
    }
    
    private func handleDisconnect() {
        pingTimer?.invalidate()
        if reconnectAttempts < maxReconnectAttempts {
            let delay = min(pow(2.0, Double(reconnectAttempts)), 10.0)
            reconnectAttempts += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Reconnect logic (omit for brevity)
            }
        }
    }
    
    private func sendPing() {
        var clientEvent = Warbase_ClientEvent()
        var pingEvent = Warbase_PingEvent()
        pingEvent.clientTime = Int64(Date().timeIntervalSince1970 * 1000)
        clientEvent.ping = pingEvent
        send(clientEvent)
    }
    
    private func handleBinaryData(_ data: Data) {
        do {
            let serverMessage = try Warbase_ServerMessage(serializedBytes: [UInt8](data))
            
            switch serverMessage.message {
            case .gameState(let gs):
                var playersDict: [String: NetworkPlayerState] = [:]
                for (id, p) in gs.players {
                    // Strict NaN Safety Validation for Quaternions
                    let isQuaternionValid = !p.rx.isNaN && !p.ry.isNaN && !p.rz.isNaN && !p.rw.isNaN
                    let rx = isQuaternionValid ? p.rx : 0
                    let ry = isQuaternionValid ? p.ry : 0
                    let rz = isQuaternionValid ? p.rz : 0
                    let rw = isQuaternionValid ? p.rw : 1.0
                    
                    playersDict[id] = NetworkPlayerState(
                        id: id,
                        x: p.x, y: p.y, z: p.z,
                        rx: rx, ry: ry, rz: rz, rw: rw,
                        anim: p.animation,
                        health: Float(p.health),
                        kills: Int(p.kills),
                        deaths: Int(p.deaths),
                        isDead: p.isDead,
                        platformId: p.platformID,
                        ping: Int(p.ping),
                        weaponId: p.weaponID,
                        team: p.team
                    )
                }
                
                let newGameState = GameStateData(
                    players: playersDict,
                    roomMode: gs.roomMode,
                    roomState: gs.roomState,
                    scoreTeamA: Int(gs.scoreTeamA),
                    scoreTeamB: Int(gs.scoreTeamB),
                    winnerId: gs.winnerID.isEmpty ? nil : gs.winnerID
                )
                
                DispatchQueue.main.async {
                    self.gameState = newGameState
                    self.onStateReceived?(newGameState)
                }
                
            case .serverEvent(let evt):
                switch evt.event {
                case .fire(let f):
                    DispatchQueue.main.async {
                        self.onFireReceived?(f.shooterID, [f.originX, f.originY, f.originZ], [f.hitX, f.hitY, f.hitZ])
                    }
                case .hitConfirmed(_):
                    DispatchQueue.main.async {
                        self.onHitConfirmed?("target", 0) // Simplify for now
                    }
                case .killConfirmed(_):
                    DispatchQueue.main.async {
                        self.onKillConfirmed?("target") // Simplify for now
                    }
                case .throwGrenade(let g):
                    DispatchQueue.main.async {
                        self.onGrenadeReceived?(g.shooterID, [g.px, g.py, g.pz], [g.vx, g.vy, g.vz])
                    }
                case .respawn(_):
                    DispatchQueue.main.async {
                        self.onRespawn?()
                    }
                default:
                    break
                }
                
            default:
                break
            }
        } catch {
            print("Failed to decode ServerMessage: \(error)")
        }
    }
    
    private func send(_ event: Warbase_ClientEvent) {
        do {
            let data = try event.serializedData()
            webSocket?.send(.data(data)) { error in
                if let error = error {
                    print("Failed to send ClientEvent: \(error)")
                }
            }
        } catch {
            print("Failed to serialize ClientEvent: \(error)")
        }
    }
    
    public func sendState(state: NetworkPlayerState) {
        guard !state.x.isNaN, !state.y.isNaN, !state.z.isNaN else { return }
        
        var clientEvent = Warbase_ClientEvent()
        var update = Warbase_PlayerStateUpdate()
        update.x = state.x
        update.y = state.y
        update.z = state.z
        update.rx = state.rx.isNaN ? 0 : state.rx
        update.ry = state.ry.isNaN ? 0 : state.ry
        update.rz = state.rz.isNaN ? 0 : state.rz
        update.rw = state.rw.isNaN ? 1 : state.rw
        update.animation = state.anim
        update.platformID = state.platformId
        update.weaponID = state.weaponId
        
        clientEvent.stateUpdate = update
        send(clientEvent)
    }
    
    public func sendFire(position: [Float], direction: [Float]) {
        var clientEvent = Warbase_ClientEvent()
        var fireEvent = Warbase_FireEvent()
        fireEvent.originX = position[0]
        fireEvent.originY = position[1]
        fireEvent.originZ = position[2]
        
        let endX = position[0] + direction[0]
        let endY = position[1] + direction[1]
        let endZ = position[2] + direction[2]
        
        fireEvent.hitX = endX
        fireEvent.hitY = endY
        fireEvent.hitZ = endZ
        
        clientEvent.fire = fireEvent
        send(clientEvent)
    }
    
    public func sendGrenade(position: [Float], velocity: [Float]) {
        var clientEvent = Warbase_ClientEvent()
        var grenadeEvent = Warbase_ThrowGrenadeEvent()
        grenadeEvent.px = position[0]
        grenadeEvent.py = position[1]
        grenadeEvent.pz = position[2]
        grenadeEvent.vx = velocity[0]
        grenadeEvent.vy = velocity[1]
        grenadeEvent.vz = velocity[2]
        
        clientEvent.throwGrenade = grenadeEvent
        send(clientEvent)
    }
    
    public func sendHit(targetId: String, damage: Float, hitZone: String) {
        var clientEvent = Warbase_ClientEvent()
        var hitEvent = Warbase_HitEvent()
        hitEvent.targetID = targetId
        hitEvent.damage = Int32(damage)
        
        clientEvent.hit = hitEvent
        send(clientEvent)
    }
    
    public func sendReload() {
        var clientEvent = Warbase_ClientEvent()
        clientEvent.reload = Warbase_ReloadEvent()
        send(clientEvent)
    }
    
    public func sendSwitchWeapon(weaponId: String) {
        var clientEvent = Warbase_ClientEvent()
        var switchEvent = Warbase_SwitchWeaponEvent()
        switchEvent.weaponID = weaponId
        
        clientEvent.switchWeapon = switchEvent
        send(clientEvent)
    }
    
    public func sendRespawnRequest() {
        var clientEvent = Warbase_ClientEvent()
        clientEvent.respawnRequest = Warbase_RespawnRequestEvent()
        send(clientEvent)
    }
}
