import Foundation
import NIOCore
import SwiftProtobuf

struct RoomInfo: Codable, Sendable {
    let id: String
    let name: String
    let map: String
    let mode: String
    let playerCount: Int
}

actor Match {
    var rooms: [String: Room] = [:]

    func seedDefaultRooms() {
        let defaults = [
            ("industrial-public", "Industrial Zone (Public)", "industrial", "TDM"),
            ("village-public", "Village Outpost (Public)", "village", "FFA"),
            ("arena-public", "Game Arena (Public)", "arena", "FFA")
        ]
        for (id, name, map, mode) in defaults where rooms[id] == nil {
            let r = Room(id: id, name: name, mapName: map, mode: mode)
            r.isPermanent = true
            rooms[id] = r
        }
    }

    func listRooms() -> [RoomInfo] {
        seedDefaultRooms()
        return rooms.values.map {
            RoomInfo(id: $0.id, name: $0.name, map: $0.mapName, mode: $0.mode, playerCount: $0.players.count)
        }.sorted { $0.playerCount > $1.playerCount }
    }

    func createRoom(name: String, mapName: String, mode: String) -> Room {
        let id = UUID().uuidString
        let r = Room(id: id, name: name, mapName: mapName, mode: mode.isEmpty ? "FFA" : mode)
        rooms[id] = r
        return r
    }

    func register(session: GameSession) {
        let room: Room
        if let existing = rooms[session.roomID] {
            room = existing
        } else {
            let mapName: String
            let lower = session.roomID.lowercased()
            if lower.contains("village") { mapName = "village" }
            else if lower.contains("arena") { mapName = "arena" }
            else { mapName = "industrial" }
            
            let prefix = String(session.roomID.prefix(8))
            let r = Room(id: session.roomID, name: "Custom Match (\(prefix))", mapName: mapName, mode: "FFA")
            rooms[session.roomID] = r
            room = r
        }

        room.sessions[session.id] = session

        // Check if player entity already exists (reconnect case)
        if room.playerIndices[session.id] == nil {
            let player = Player(id: session.id)
            if room.mode == "TDM" {
                var teamACount = 0
                var teamBCount = 0
                for p in room.players {
                    if p.state.team == "A" { teamACount += 1 }
                    else if p.state.team == "B" { teamBCount += 1 }
                }
                player.state.team = teamACount <= teamBCount ? "A" : "B"
            } else {
                player.state.team = "NONE"
            }

            room.players.append(player)
            let idx = room.players.count - 1
            room.playerIndices[session.id] = idx
            room.cachedGameState.players[session.id] = player.state
        }

        print("[SwiftServer] Player \(session.id) joined room \(session.roomID) (total: \(room.players.count))")
    }

    func unregister(session: GameSession) {
        guard let room = rooms[session.roomID] else { return }
        room.sessions.removeValue(forKey: session.id)

        if let idx = room.playerIndices[session.id] {
            let lastIdx = room.players.count - 1
            if idx != lastIdx {
                room.players[idx] = room.players[lastIdx]
                room.playerIndices[room.players[idx].id] = idx
            }
            room.players.removeLast()
            room.playerIndices.removeValue(forKey: session.id)
            room.cachedGameState.players.removeValue(forKey: session.id)

            if room.players.isEmpty {
                room.emptySince = .now
            }
        }

        session.close()
        print("[SwiftServer] Player \(session.id) disconnected from room \(session.roomID)")
    }

    func handleClientEvent(senderID: String, roomID: String, data: Data) {
        guard let room = rooms[roomID] else { return }
        guard let event = try? Warbase_ClientEvent(serializedBytes: data) else { return }

        guard let payload = event.event else { return }
        let now = ContinuousClock.now

        switch payload {
        case .stateUpdate(let update):
            guard let idx = room.playerIndices[senderID] else { return }
            let player = room.players[idx]

            if player.state.isDead {
                player.state.animation = "death"
            } else {
                // Anti-teleport speed clamp
                let x = update.x, y = update.y, z = update.z
                if !x.isNaN && !x.isInfinite && !y.isNaN && !y.isInfinite && !z.isNaN && !z.isInfinite {
                    let dx = x - player.state.x
                    let dy = y - player.state.y
                    let dz = z - player.state.z
                    let dist2 = dx*dx + dy*dy + dz*dz
                    if dist2 <= 36 { // >6m in 1 tick dropped
                        player.state.x = x
                        player.state.y = y
                        player.state.z = z
                    }
                }
                let rx = update.rx, ry = update.ry, rz = update.rz, rw = update.rw
                if !rx.isNaN && !ry.isNaN && !rz.isNaN && !rw.isNaN {
                    player.state.rx = rx
                    player.state.ry = ry
                    player.state.rz = rz
                    player.state.rw = rw
                }
                player.state.animation = update.animation
                player.state.platformID = update.platformID
                player.state.ping = update.ping
                if !update.weaponID.isEmpty {
                    player.state.weaponID = update.weaponID
                }
                room.cachedGameState.players[senderID] = player.state
            }

        case .ping(let ping):
            var pong = Warbase_ServerPongEvent()
            pong.clientTime = ping.clientTime
            var sEvt = Warbase_ServerEvent()
            sEvt.pong = pong
            var msg = Warbase_ServerMessage()
            msg.serverEvent = sEvt
            room.sendDirect(playerID: senderID, message: msg)

        case .hit(let hit):
            guard let shooterIdx = room.playerIndices[senderID],
                  let targetIdx = room.playerIndices[hit.targetID] else { return }
            
            let shooter = room.players[shooterIdx]
            let target = room.players[targetIdx]

            // Hit rejected if no recent fire (<800ms)
            if now - shooter.lastShotTime > .milliseconds(800) {
                return
            }

            if room.mode == "TDM" && shooter.state.team == target.state.team && shooter.state.team != "NONE" {
                return // Friendly fire disabled
            }

            do {
                let isKill = try shooter.validateAndApplyHit(target: target, clientDamage: Int(hit.damage))
                if isKill {
                    // Score & Win Condition
                    if room.mode == "FFA" {
                        if shooter.state.kills >= 30 {
                            room.state = "FINISHED"
                            room.winnerID = shooter.id
                            room.stateTimer = now + .seconds(10)
                        }
                    } else if room.mode == "TDM" {
                        if shooter.state.team == "A" {
                            room.scoreTeamA += 1
                            if room.scoreTeamA >= 60 {
                                room.state = "FINISHED"
                                room.winnerID = "A"
                                room.stateTimer = now + .seconds(10)
                            }
                        } else if shooter.state.team == "B" {
                            room.scoreTeamB += 1
                            if room.scoreTeamB >= 60 {
                                room.state = "FINISHED"
                                room.winnerID = "B"
                                room.stateTimer = now + .seconds(10)
                            }
                        }
                    }

                    var killEvt = Warbase_ServerEvent()
                    killEvt.killConfirmed = Warbase_KillConfirmedEvent()
                    var msg = Warbase_ServerMessage()
                    msg.serverEvent = killEvt
                    room.sendDirect(playerID: shooter.id, message: msg)
                } else {
                    var hitEvt = Warbase_ServerEvent()
                    hitEvt.hitConfirmed = Warbase_HitConfirmedEvent()
                    var msg = Warbase_ServerMessage()
                    msg.serverEvent = hitEvt
                    room.sendDirect(playerID: shooter.id, message: msg)
                }
            } catch {
                // Invalid hit
            }

        case .fire(let f):
            guard let idx = room.playerIndices[senderID] else { return }
            let shooter = room.players[idx]
            do {
                try shooter.validateAndApplyFire(now: now)
                var sFire = Warbase_ServerFireEvent()
                sFire.shooterID = senderID
                sFire.originX = f.originX
                sFire.originY = f.originY
                sFire.originZ = f.originZ
                sFire.hitX = f.hitX
                sFire.hitY = f.hitY
                sFire.hitZ = f.hitZ
                sFire.normalX = f.normalX
                sFire.normalY = f.normalY
                sFire.normalZ = f.normalZ
                sFire.hitWall = f.hitWall

                var sEvt = Warbase_ServerEvent()
                sEvt.fire = sFire
                var msg = Warbase_ServerMessage()
                msg.serverEvent = sEvt
                room.broadcast(message: msg, excludingID: senderID)
            } catch {
                // Fire denied
            }

        case .reload:
            guard let idx = room.playerIndices[senderID] else { return }
            let shooter = room.players[idx]
            try? shooter.validateAndApplyReload(now: now)

        case .switchWeapon(let sw):
            guard let idx = room.playerIndices[senderID] else { return }
            let shooter = room.players[idx]
            if !shooter.state.isDead, let cfg = Weapons[sw.weaponID] {
                shooter.activeWeapon = cfg
                shooter.state.weaponID = sw.weaponID
                if let saved = shooter.ammoStore[cfg.id] {
                    shooter.ammoCount = saved
                } else {
                    shooter.ammoCount = cfg.magSize
                }
                shooter.isReloading = false
            }

        case .respawnRequest:
            guard let idx = room.playerIndices[senderID] else { return }
            let player = room.players[idx]
            if player.state.isDead, let dt = player.deathTime, now - dt >= .milliseconds(2900) {
                player.state.isDead = false
                player.state.health = 100
                player.state.animation = "idle"
                player.isReloading = false
                player.ammoCount = player.activeWeapon.magSize
                player.ammoStore[player.activeWeapon.id] = player.ammoCount
                player.deathTime = nil

                let newX = Float.random(in: -3...3)
                let newZ = Float.random(in: -3...3)
                player.state.x = newX
                player.state.y = 10
                player.state.z = newZ

                var rEvt = Warbase_RespawnEvent()
                rEvt.x = newX
                rEvt.y = 10
                rEvt.z = newZ

                var sEvt = Warbase_ServerEvent()
                sEvt.respawn = rEvt
                var msg = Warbase_ServerMessage()
                msg.serverEvent = sEvt
                room.sendDirect(playerID: senderID, message: msg)
            }

        case .throwGrenade(let g):
            guard let idx = room.playerIndices[senderID] else { return }
            let pl = room.players[idx]
            if pl.state.isDead { return }
            let vx = g.vx, vy = g.vy, vz = g.vz
            let vlen = vx*vx + vy*vy + vz*vz
            if vlen > 225 { return } // >15m/s rejected
            let dx = g.px - pl.state.x
            let dz = g.pz - pl.state.z
            if dx*dx + dz*dz > 16 { return } // >4m from player rejected

            var gEvt = Warbase_ServerThrowGrenadeEvent()
            gEvt.shooterID = senderID
            gEvt.px = g.px
            gEvt.py = g.py
            gEvt.pz = g.pz
            gEvt.vx = vx
            gEvt.vy = vy
            gEvt.vz = vz

            var sEvt = Warbase_ServerEvent()
            sEvt.throwGrenade = gEvt
            var msg = Warbase_ServerMessage()
            msg.serverEvent = sEvt
            room.broadcast(message: msg, excludingID: senderID)
        }
    }

    func runTicker() async {
        var nextTick = ContinuousClock.now
        while true {
            nextTick += .milliseconds(16) // Target 60Hz (~16.6ms)
            let remaining = nextTick - ContinuousClock.now
            if remaining > .zero {
                try? await Task.sleep(for: remaining)
            } else {
                nextTick = ContinuousClock.now
                await Task.yield()
            }

            let now = ContinuousClock.now

            for room in rooms.values {
                // Reload resolve
                for p in room.players where p.isReloading && now >= p.reloadStart + p.activeWeapon.reloadTime {
                    p.isReloading = false
                    p.ammoCount = p.activeWeapon.magSize
                    p.ammoStore[p.activeWeapon.id] = p.ammoCount
                    room.cachedGameState.players[p.id] = p.state
                }

                // Win reset (10s)
                if room.state == "FINISHED", let t = room.stateTimer, now >= t {
                    room.state = "PLAYING"
                    room.scoreTeamA = 0
                    room.scoreTeamB = 0
                    room.winnerID = ""
                    room.stateTimer = nil
                    for pl in room.players {
                        pl.state.kills = 0
                        pl.state.deaths = 0
                        pl.state.health = 100
                        pl.state.isDead = false
                        pl.state.animation = "idle"
                        pl.isReloading = false
                        pl.ammoCount = pl.activeWeapon.magSize
                        pl.deathTime = nil
                        room.cachedGameState.players[pl.id] = pl.state
                    }
                }

                // Skip broadcast if no active sessions
                if room.sessions.isEmpty { continue }

                // Update room metadata in cached state
                room.cachedGameState.roomMode = room.mode
                room.cachedGameState.roomState = room.state
                room.cachedGameState.scoreTeamA = room.scoreTeamA
                room.cachedGameState.scoreTeamB = room.scoreTeamB
                room.cachedGameState.winnerID = room.winnerID

                var serverMsg = Warbase_ServerMessage()
                serverMsg.gameState = room.cachedGameState

                room.broadcast(message: serverMsg)
            }
        }
    }
}
