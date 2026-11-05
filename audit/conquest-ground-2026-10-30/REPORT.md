# Conquest and ground-contact release — 30 October 2026

## Released

Official Umbrel image: `warbase-colyseus:conquest-ground-20261030`. Matching Web and macOS exports use source fingerprint `8461a3e4fd63f90c584d6bdee0a2962a9a76ec852a3cb6516fd6e46d8406e283`. Native ZIP SHA256: `4a41920bf12d39b4bae27a712b73610ad937caf2f3e7cdc74ed99db674c18b64`.

The public directory includes **Industrial Zone · Conquest (Public)**. Create match also offers Conquest on the other supported maps. Four server-owned points A–D capture in 12 seconds with uncontested, living, on-foot presence. Enemy points must first be neutralized. Each team starts with 500 tickets; kills and objective advantage drain enemy tickets. Zero tickets finishes the match. Bots pursue objectives when not fighting.

M opens an on-demand top-down view of the actual loaded map, with objective ownership/progress and the local player. M or Esc closes it. Gameplay controls are neutralized while it is open; the live match continues. The extra map camera renders once per opening and stays disabled while closed.

## Ground-contact repair

Live diagnostics identified a Nuketown spawn at x=28,z=0 authored below its visible road. A failed downward sweep left the player embedded while vertical velocity accumulated. The server now raises buried spawn markers to nearby walkable ground. Server and prediction both settle vertical velocity when capsule contacts block falling or jumping. Grounded presentation accepts capsule edge support.

Actual Godot map/player check: feet y=0.8421, camera height=1.6500, vertical velocity=0, grounded=true. This is a targeted fix; it does not establish that every collision edge on every map is perfect.

## Verification

- Server suite: 63 passed, zero failed, one optional benchmark skipped. Includes capture, contesting, tickets, admission, bots, and spawn settling.
- TypeScript build and Godot editor parsing passed.
- Ten-map idle/prediction regression and actual Godot spawn-floor check passed.
- Tactical map component test passed, including bounds and disabled render state.
- Actual Main/SDK integration passed: four objectives, neutral inputs while map open, movement resumes after close, acknowledged inputs, 0.000m SDK pose error.
- Remote preflight and post-deployment checks passed; admin storage and secret mounts preserved.
- Official-domain SDK join: protocol 6, Industrial Conquest, A/B/C/D, tickets 500/500, team A, input acknowledged.
- Matching exported Mac client joined the official public Conquest room. One manual check confirmed the entire map and A–D markers; closing it returned to gameplay with changing tickets/objective state.
- Public admin route returned 404; private Tailnet admin page returned 200.

## Limits and follow-up

No fresh 64-player capacity run or interactive Web gameplay check was performed for this release. Web export/package succeeded and is deployed; native received the manual visual check. Existing grenade event prediction remains disabled pending the pinned Godot SDK expiry crash fix. Game-specific movement, vehicle physics, capture rules and rendering remain application code; Colyseus supplies room state, input buffering, prediction/reconciliation and transport.

The gateway is unchanged. The previous combat container remains stopped with restart disabled as a rollback snapshot. No Git push was performed.
