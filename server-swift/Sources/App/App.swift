import Hummingbird
import HummingbirdWebSocket
import HTTPTypes
import NIOCore
import Foundation

struct HealthCheckResponse: Encodable, Sendable {
    struct SystemInfo: Encodable, Sendable {
        let environment: String
        let version: String
    }
    let status: String
    let system_info: SystemInfo
}

struct RoomsListResponse: Encodable, Sendable {
    let rooms: [RoomInfo]
    let online_players: Int
}

struct CreateRoomResponse: Encodable, Sendable {
    let room_id: String
}

@main struct ServerApp {
    static func main() async throws {
        let env = Environment()
        let port = env.get("PORT").flatMap(Int.init) ?? 8081
        let match = Match()
        await match.seedDefaultRooms()
        Task { await match.runTicker() }

        let router = Router()
        router.add(middleware: LogRequestsMiddleware(.info))
        
        router.get("/healthcheck") { _, _ -> Response in
            let res = HealthCheckResponse(status: "available", system_info: .init(environment: "production", version: "1.0.0"))
            let body = try JSONEncoder().encode(res)
            return Response(status: .ok, headers: [.contentType: "application/json"], body: .init(byteBuffer: ByteBuffer(bytes: body)))
        }

        router.get("/api/rooms") { _, _ -> Response in
            let rooms = await match.listRooms()
            let totalPlayers = rooms.reduce(0) { $0 + $1.playerCount }
            let res = RoomsListResponse(rooms: rooms, online_players: totalPlayers)
            let body = try JSONEncoder().encode(res)
            return Response(status: .ok, headers: [.contentType: "application/json"], body: .init(byteBuffer: ByteBuffer(bytes: body)))
        }

        router.post("/api/rooms") { req, context -> Response in
            struct Input: Decodable { var name: String; var map: String; var mode: String? }
            let input = try await req.decode(as: Input.self, context: context)
            guard !input.name.isEmpty, !input.map.isEmpty else { throw HTTPError(.badRequest) }
            let room = await match.createRoom(name: input.name, mapName: input.map, mode: input.mode ?? "FFA")
            let body = try JSONEncoder().encode(CreateRoomResponse(room_id: room.id))
            return Response(status: .created, headers: [.contentType: "application/json"], body: .init(byteBuffer: ByteBuffer(bytes: body)))
        }

        let distPath = env.get("ENV") == "production" ? "/app/dist" : "../client/dist"
        router.add(middleware: FileMiddleware(distPath, searchForIndexHtml: true))

        let app = Application(
            router: router,
            server: .http1WebSocketUpgrade(shouldUpgrade: { request, channel, logger in
                guard let rawPath = request.path else { return .dontUpgrade }
                let parts = rawPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: true)
                let path = String(parts.first ?? "")
                guard path == "/connect" else { return .dontUpgrade }

                var username = "Player_\(Int.random(in: 1000...9999))"
                var roomID = "industrial-public"
                if parts.count > 1 {
                    let query = String(parts[1])
                    let pairs = query.components(separatedBy: "&")
                    for pair in pairs {
                        let kv = pair.components(separatedBy: "=")
                        if kv.count == 2 {
                            let key = kv[0]
                            let val = kv[1].removingPercentEncoding ?? kv[1]
                            if key == "user" && !val.isEmpty { username = val }
                            else if key == "room" && !val.isEmpty { roomID = val }
                        }
                    }
                }

                let user = username
                let room = roomID

                return .upgrade([:]) { inbound, outbound, context in
                    let (stream, continuation) = AsyncStream<ByteBuffer>.makeStream()
                    let session = GameSession(id: user, roomID: room, continuation: continuation)
                    await match.register(session: session)

                    // Background task to pump binary messages from session to WebSocket outbound
                    let sendTask = Task {
                        for await buffer in stream {
                            do {
                                try await outbound.writeBinaryMessage(buffer)
                            } catch {
                                break
                            }
                        }
                    }

                    // Loop over inbound WebSocket frames
                    do {
                        for try await frame in inbound {
                            if frame.opcode == .binary {
                                let data = Data(frame.data.readableBytesView)
                                await match.handleClientEvent(senderID: user, roomID: room, data: data)
                            }
                        }
                    } catch {
                        // Disconnected
                    }

                    sendTask.cancel()
                    await match.unregister(session: session)
                }
            }),
            configuration: .init(address: .hostname("0.0.0.0", port: port), serverName: "WarBase-Swift")
        )

        try await app.runService()
    }
}
