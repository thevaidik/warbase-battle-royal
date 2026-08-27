import Foundation
import NIOCore
import SwiftProtobuf

final class Room: @unchecked Sendable {
    let id: String
    let name: String
    let mapName: String
    let mode: String
    var state: String = "PLAYING"
    var scoreTeamA: Int32 = 0
    var scoreTeamB: Int32 = 0
    var winnerID: String = ""
    var stateTimer: ContinuousClock.Instant?
    var players: [Player] = []
    var playerIndices: [String: Int] = [:]
    var cachedGameState: Warbase_GameState
    var sessions: [String: GameSession] = [:]
    var emptySince: ContinuousClock.Instant = .now
    var isPermanent: Bool = false

    init(id: String, name: String, mapName: String, mode: String) {
        self.id = id
        self.name = name
        self.mapName = mapName
        self.mode = mode
        var gs = Warbase_GameState()
        gs.roomMode = mode
        gs.roomState = "PLAYING"
        self.cachedGameState = gs
    }

    func broadcast(_ buffer: ByteBuffer, excludingID: String? = nil) {
        for (playerID, session) in sessions {
            if playerID != excludingID {
                session.send(buffer)
            }
        }
    }

    func broadcast(message: Warbase_ServerMessage, excludingID: String? = nil) {
        do {
            let data = try message.serializedData()
            let buf = ByteBuffer(bytes: data)
            broadcast(buf, excludingID: excludingID)
        } catch {
            print("Failed to serialize ServerMessage for room \(id): \(error)")
        }
    }

    func sendDirect(playerID: String, message: Warbase_ServerMessage) {
        guard let session = sessions[playerID] else { return }
        do {
            let data = try message.serializedData()
            session.send(ByteBuffer(bytes: data))
        } catch {
            print("Failed to serialize direct ServerMessage for \(playerID): \(error)")
        }
    }
}
