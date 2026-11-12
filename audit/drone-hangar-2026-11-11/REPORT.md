# Drone hangar and third-person update — 2026-11-11

Implemented locally; no public deployment or Git push in this task.

- Drone Hangar equips and saves primary and secondary weapon choices from all seven game weapons, with weapon statistics and selected movement controls. Wheels, tracks, helicopter and wing profiles persist between launches.
- One modular airframe carries the movement attachments. New procedural payload geometry uses the existing authoritative weapon IDs and balance, with distinct receivers, barrels, feeds and sights. Removed cosmetic-only weapon packages.
- Chamfered armor uses shared cached meshes. Static parts are combined by material while preserving animated rotors and wheels. The visual regression enforces fewer than 50 airframe mesh instances and tests actual vertices against the existing collision sphere.
- Third-person chase camera is 2.2 m behind the drone, sweeps against geometry and hides the local hull only when compressed into it. The weapon gimbal converges on the camera target. Grenades originate beside the drone. Wheels and tracks ignore vertical movement input and remain on the ground.
- Network fire uses the physical muzzle-to-target direction. Close-range regression checks cover interception and the server's positive-down pitch convention.

Validation: hangar equip/save checks passed for seven weapons and four movement profiles; visual bounds/muzzle suite, weapon clearance and complete drone smoke checks passed. Native hangar and gameplay renders were inspected; see `hangar.png` and `chase.png`. These are higher-detail procedural game models, not a claim of finished AAA art quality or a 64-player performance certification.

The native source client was relaunched against the healthy local protocol-13 server at `127.0.0.1:18301`. Public protocol-12 deployment remains incompatible with this client until the coordinated server/client upgrade. Audio stays disabled.
