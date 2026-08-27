# No-Cheat Guide — Easy Words

This file explains how WarBase stops cheating. No login needed.

## 1. What players can do?
- Anyone with the domain can open the game and play.
- No one can run code on the server. They can only send game moves.

## 2. How we stop cheats?
- **Names:** Must be 3-16 letters/numbers. Bad names become Guest_.
- **Rooms:** Must be simple names (like industrial, village). If the room name is bad (empty or weird symbols), server puts you in "industrial" — the main map — so you still can play.
- **Speed:** If you move more than 6 meters in one tiny tick (60 times per second), server ignores it. No teleport.
- **Bullets:** Server knows your gun. AK does 34, head is 2.5x. If you say "I did 500 damage", server says no.
- **Fire speed:** AK is 600 per minute. Server has a timer. If you shoot too fast, it blocks. We fixed the timer bug where fast guns were never blocked.
- **Hit needs fire:** You must have shot recently (0.8 seconds) to claim a hit. No fake hits.
- **Grenades:** Must be near you (4 meters), not too fast (15 m/s), not when dead. Bad numbers are dropped.
- **Ammo:** Server counts bullets. No shooting while reloading or with 0 ammo.
- **Heads:** Only 10 invisible boxes on bones count. You cannot say "I hit head" if ray missed.

## 3. What the server still trusts?
- Your position, aim, and animation come from your device. Server checks speed but does not fully check walls yet. Future: server will check "did bullet line hit a wall?".

## 4. What about connection?
- Web and Mac use same `wss://domain/connect?user=&room=&cid=`. Cloudflare gives the lock (TLS).
- `cid` stays same after reconnect so you keep your place. New name cannot steal old name while you are still connected.
- Original check for "who is this?" allowed any website. Now only your domain and localhost can connect.

## 5. What is hidden in production?
- Debug page `/debug/pprof` is off when `ENV=production`.
- Headers `X-Content-Type-Options`, `X-Frame-Options` are set.

## 6. What is baked for Mac?
- Debug build: shows Server field, defaults to localhost:8081 or your saved host.
- Release build: hides Server field, always connects to `warbase.nxtlap.com` (change in `RealityGameView.swift:138`).

## 7. What is left to add later?
- Room password for private matches.
- Full wall check for bullets.
- Login with Cloudflare Access if you want friends-only.

**Rule:** Server is the boss for health, kills, and deaths. Client is fast for aiming. If they disagree, server wins.
