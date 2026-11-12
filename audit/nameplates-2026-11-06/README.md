# Tactical 3D nameplates — 2026-11-06

Online actors and practice bots now use the same Rajdhani HUD font, restrained dark outline, compact uppercase callsign and cyan/coral team colours. Bot identities display as `VIPER-01 / AI`, without exposing the raw `[BOT]` prefix or numeric HP. Human callsigns use the same style without the AI tag. Labels sit closer to the head and retain world-space scaling, camera-facing billboarding and depth testing against walls.

Snapshot and LOD updates previously disagreed about label visibility, allowing distant/intersecting labels to reappear between distance checks. Visibility now has one policy: living actors from 2m through 60m. Death hides labels immediately; state updates preserve that policy. Colour and text change only when necessary, avoiding repeated label reshaping as HP updates. No additional per-actor viewport, panel, mesh or network field was added.

Ten focused checks cover callsign formatting, HUD font/colours, wall depth testing, health updates, near/far visibility, death and human-vs-AI labels. The automatic 11-map/132-spawn export gate also passes. Native and Web exports retain protocol 11 and the official pinned SDK binaries.

Native/Web client fingerprint: `a558207ae068af5bba4c45d26ed30304acd375d07073a95336fd39ddbadde3c3`. Native and Web exports have matching provenance. The existing network recovery/respawn/remote-actor checks also pass.

Deployed `warbase-colyseus:nameplates-20261106` on Umbrel with the existing gateway/private dashboard mounts. Public manifest fingerprint and protocol 11 verified after promotion. The matching native client was reopened.
