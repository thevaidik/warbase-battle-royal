# Traversal, daylight and combat feedback

## Surface sticking and backward glitches
- World concave collision is now two-sided, matching the authority's triangle traces. Previously the client could enter through the back of a thin surface that the server blocked.
- Replaced the center-ray-only step check with capsule clearance at the landing point plus upward and forward body sweeps. Automatic steps are limited to grounded, walkable ledges up to 0.45 m; automatic airborne mantling was removed.
- A validated step lift persists until completed, so briefly losing floor contact does not interrupt it. Horizontal movement during a lift is limited to keep the combined movement inside the server's 12 m/s budget. Jumping, driving, respawning and authoritative corrections cancel pending steps.
- Standing from crouch requires capsule clearance. Each player owns its capsule resource.
- The fall cutoff moved from -4 m to just above the map's safety floor (-14 m normally, -119 m for Canyon). Stadium geometry extends below -4 m, so the old cutoff could teleport a player away from valid lower surfaces.
- Authoritative correction resets interpolation to prevent streaking through geometry.

`traversal-tests.log` covers a low step, a blocked step beneath a ceiling, crouch/standing clearance, two-sided map collision, and valid ground below -4 m. All pass. These address concrete clipping/teleport sources; all possible online correction causes are not claimed eliminated.

## Lighting
Selectable presets are Dawn 06:00, Noon 12:00, Dusk 18:00 and bright Overcast 14:00. Random rooms no longer choose total night. Legacy night requests normalize to Overcast. Server lighting tests and real online synchronization passed.

## Combat feedback
- Stronger pooled blood droplets, scaled by confirmed damage.
- A cached procedural splatter texture shared by edge-of-screen hit feedback and world blood stains.
- Brief hurt tint and aim flinch, with smooth damage-direction fading. Screen splatter positions are stable between redraws.
- Local, offline-bot and remote deaths produce a blood burst and ground stain. World stains share the bounded decal budget, start fading after 12 seconds and expire after 18 seconds.
- Local death drops/tilts the view, hides the first-person weapon, sets health to zero and shows the existing respawn presentation. Respawn restores the camera/weapon and clears screen blood.
- Existing character death animations remain in use.

`feedback-tests.log`, `hit-feedback.png`, `death-feedback.png`: native daylight, hit, death, blood stain and clean respawn checks passed and were visually inspected.

## Other validation
`godot-tests.log`: traversal, stadium, grenades, Industrial collision, weapons and gameplay passed. `server-tests.log` and `server-vet.log`: full race suite and vet passed. `online-tests.log`: real authority/AI/vehicle/impact-grenade/damage integration passed. `web-tests.log`: release compression/hash and optional stadium pack mounting passed. Rebuilt client and server are run together locally; no remote deployment performed.
