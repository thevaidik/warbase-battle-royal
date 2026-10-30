# Colyseus StateView reproduction

This is an isolated room and test harness. It does not change `BattleRoom` or enable StateView in the game.

## Versions

- Node.js: 24.16.0 used for this workspace run; package engine floor is Node 22.
- `colyseus`: 0.18.10
- `@colyseus/core`: 0.18.10
- `@colyseus/schema`: 5.0.42
- `@colyseus/ws-transport`: 0.18.4
- Node SDK: `@colyseus/sdk` 0.18.8
- Godot: project reports 4.7.2 in the existing verification notes.
- Godot Colyseus SDK: 0.18.7, native macOS arm64 and Web wasm32 artifacts (see `warbase-godot/client/addons/colyseus/UPSTREAM.txt`).

## Node SDK test

From `warbase-colyseus`:

```sh
npm run test:state-view
```

The test first checks an unfiltered two-peer baseline, then a tagged `ownerSecret` field where both peers must see their own value and must not see the other's value. It closes and automatically reconnects one peer, checks visibility again, then leaves the second peer and checks map removal reaches the remaining peer.

## Godot native or Web probe

Start the room server from `warbase-colyseus`; it prints a room ID for the selected mode:

```sh
npm run state-view:server
```

For the unfiltered baseline, start it with `STATE_VIEW_FILTERED=false npm run state-view:server` instead. Use the printed room ID for both Godot processes.

Launch two independent Godot processes with project path `warbase-godot/state-view-repro` (main scene `StateViewRepro.tscn`), setting the same `STATE_VIEW_ROOM_ID` and distinct `STATE_VIEW_NAME=alice` / `STATE_VIEW_NAME=bob`. Optional `STATE_VIEW_ENDPOINT` selects the server URL. Each process checks its own tagged value, the other peer's public field, and whether the other peer's tagged value leaked. Run the same project through the native editor/runtime and an exported Web build, and keep the logs separate.

## Observed run status

The Node SDK test passes all three checks, including the unfiltered baseline, filtered owner/non-owner assertions, automatic reconnect, and removal. It uses the exact package versions listed above.

The native probe was run with Godot 4.7.2 and the pinned 0.18.7 addon. Both clients joined the same room ID and received state patches. However, each process observed only its own entry in the public `players` map and timed out waiting for the second entry in both filtered and unfiltered modes. That means this run does not isolate a StateView failure: the unfiltered baseline also fails. The native result points to a remaining small-schema/client-decoding or harness mismatch that needs isolation before claiming an upstream StateView defect. The Web build has not been exercised, and the Godot probe does not yet cover reconnect/removal; those lifecycle cases are covered only by the Node SDK test.
