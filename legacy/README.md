# Retired implementation reference

The production game uses `warbase-colyseus` and the official Colyseus Godot adapter. This directory preserves the former Go backend, protobuf definitions, transport and wire-protocol tests, including local edits that existed before cleanup. It is outside the Godot project and excluded from production Docker build contexts.

These are historical references, not a supported deployment workflow. Do not start the old Compose definition against the production ports. Live gateway/server replacement follows `warbase-colyseus/deploy/ADMISSION.md`.

Current map-authoring output goes to ignored `build/map-authoring/maps.json.gz`; extraction generates the matching Godot/Colyseus collision data. Hit-pose export writes the current Colyseus data directly. The archived soldier pose file remains a historical parity fixture in server tests.
