# WarBase Swift Server (Hummingbird) — Go ditto

Ditto copy of `server/` Go implementation in Swift + Hummingbird 2 + SwiftProtobuf.

## Run
```bash
cd server-swift
swift run App  # PORT=8081 ENV=development
# or docker
docker compose up --build
```

## What is ported
- `weapons.go` → `Engine/Weapons.swift`
- `player.go` → `Engine/Player.swift` (fire/reload/hit validation, threshold clamp)
- `match.go` → `Engine/Match.swift`/`Room.swift` (60Hz ticker, rooms, score, win)
- `session.go` → `Engine/Session.swift`
- `packets.proto` + `Packets.swift` (SwiftProtobuf, same binary)
- `handlers.go`/`routes.go` → `App.swift` (health, rooms API, static FileMiddleware, pprof gate)

WebSocket `/connect` upgrade to be wired via Hummingbird WebSocket (stub now, emits same binary `ServerMessage`).
