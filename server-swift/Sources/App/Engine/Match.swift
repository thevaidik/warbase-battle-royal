import Foundation
import NIOCore
import SwiftProtobuf

struct TheatreInfo: Codable, Sendable {
    let id: String
    let name: String
    let map: String
    let commanderCount: Int
}

actor Match {
    var theatres: [String: OperationalTheatre] = [:]
    
    init() {}
    
    func seedDefaultTheatres() {
        let defaults = [
            ("theatre-donbas", "Donbas Operational Sector", "donbas"),
            ("theatre-kharkiv", "Kharkiv Border Theatre", "kharkiv"),
            ("theatre-steppe", "Southern Steppe Front", "steppe")
        ]
        for (id, name, map) in defaults where theatres[id] == nil {
            let t = OperationalTheatre(id: id, name: name, mapName: map)
            t.isPermanent = true
            theatres[id] = t
        }
    }
    
    func listTheatres() -> [TheatreInfo] {
        seedDefaultTheatres()
        return theatres.values.map {
            TheatreInfo(id: $0.id, name: $0.name, map: $0.mapName, commanderCount: $0.sessions.count)
        }.sorted { $0.commanderCount > $1.commanderCount }
    }
    
    func createTheatre(name: String, mapName: String) -> OperationalTheatre {
        let id = "theatre-\(UUID().uuidString.prefix(8))"
        let t = OperationalTheatre(id: id, name: name, mapName: mapName)
        theatres[id] = t
        return t
    }
    
    func register(session: GameSession) {
        seedDefaultTheatres()
        let theatre: OperationalTheatre
        if let existing = theatres[session.roomID] {
            theatre = existing
        } else {
            theatre = createTheatre(name: "Tactical Sector (\(session.roomID.prefix(6)))", mapName: "donbas")
            theatres[session.roomID] = theatre
        }
        theatre.sessions[session.id] = session
    }
    
    func unregister(sessionID: String, roomID: String) {
        guard let theatre = theatres[roomID] else { return }
        theatre.sessions.removeValue(forKey: sessionID)
        if theatre.sessions.isEmpty && !theatre.isPermanent {
            theatres.removeValue(forKey: roomID)
        }
    }
    
    func handleClientEvent(senderID: String, roomID: String, data: Data) {
        guard let theatre = theatres[roomID] else { return }
        do {
            let clientEvent = try Warbase_ClientEvent(serializedBytes: data)
            switch clientEvent.event {
            case .commanderOrder(let order):
                theatre.handleCommanderOrder(order)
            case .ping(let ping):
                var pong = Warbase_ServerPongEvent()
                pong.clientTime = ping.clientTime
                var evt = Warbase_TheatreEvent()
                evt.pong = pong
                var msg = Warbase_ServerMessage()
                msg.theatreEvent = evt
                if let session = theatre.sessions[senderID] {
                    if let bufData = try? msg.serializedData() {
                        session.send(ByteBuffer(bytes: bufData))
                    }
                }
            default:
                break
            }
        } catch {
            print("Failed to decode ClientEvent: \(error)")
        }
    }
    
    func runTicker() async {
        seedDefaultTheatres()
        let clock = ContinuousClock()
        let interval = Duration.milliseconds(33) // 30Hz simulation loop
        var nextTick = clock.now
        
        while true {
            nextTick += interval
            let deltaSeconds: Float = 0.0333
            
            for (_, theatre) in theatres {
                theatre.tick(deltaTime: deltaSeconds)
            }
            
            let now = clock.now
            if now < nextTick {
                try? await Task.sleep(until: nextTick, clock: clock)
            } else {
                nextTick = now
            }
        }
    }
}
