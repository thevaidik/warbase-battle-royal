# Conquest objective markers — 30 October 2026

Floating A–D HUD badges project the authoritative capture positions above the map. Each shows distance, fixed team ownership color (blue A/red B/gray neutral), an amber contested state and a capture progress ring. Off-screen or behind-camera objectives use edge arrows. Markers remain visible through scenery for navigation; they do not indicate visibility or line of sight. The full tactical map suppresses these badges while open.

Implementation processes at most four markers at 20 Hz. It uses the active gameplay camera for projection and adds no 3D cameras, meshes, lights or physics queries. Actual capture rules and state remain on the server.

Verification: Godot import/parse passed. A focused Godot scene verifies four markers, forward and behind/edge projection, viewport containment, distance, team colors, contested color, capture fraction and tactical-map suppression. Web and native exports/package passed. No combat or physics rules changed, and no fresh capacity benchmark was run.

Paired source fingerprint: `2a9a09811524726fa723ca2f70e7cadd794e719411fb7cef55d30705c4c9e559`.

Native ZIP SHA256: `eb24c8706a020b528acac72315826b6876afe69e3095886ffd7588057aa622b5`.

Deployment target: `warbase-colyseus:objective-markers-20261030`, preserving existing environment, dashboard data and secrets. The previous Conquest release remains a stopped rollback container. No Git push requested or performed.

Deployment completed. The official-domain Web manifest matches the paired fingerprint above. A manual check of the matching exported Mac client in the official public Conquest room confirmed A–D badges, distances, ownership colors, capture rings and edge arrows during gameplay.
