# Combat pacing, free loadouts, and firing effects

## Survival and pacing

- Reduced automatic-weapon torso damage, reduced headshot multipliers, and added range falloff on both the authority and practice client. Perfect close-range automatic-weapon body-hit time to kill is approximately 0.32–0.40 seconds. Accurate sniper headshots remain lethal.
- Online bot acquisition now takes 450–750 ms; aim dispersion increases with range, with shorter bursts and longer pauses. Practice bots also react more slowly and deal less damage.
- Spawn protection lasts 2.5 seconds and ends on an accepted shot or grenade throw. Health regenerates at 15 HP/s after five seconds without damage. Damage interrupts recovery; dead players cannot regenerate.

## Loadouts

Home → Loadout opens a full equipment screen with primary, secondary, and throwable slots, all seven weapons, live 3D previews, statistics, and automatic saving. Either weapon slot accepts any gun. Choosing a gun already in the other slot swaps the slots. Only the selected pair can be switched to in a match, using 1/2 or mouse wheel.

The server validates the initial loadout, rejects extra weapons, and prevents live loadout changes. Grenade choices are a three-second M67 frag (wide blast) and an impact grenade (focused, weaker blast, 180 ms arming delay, 1.8-second backup fuse). Both supply two per life, with server-owned inventory, detonation, and damage. The HUD displays the equipped throwable and remaining count.

The FPS protocol is version 3. Update the client and server together.

## Firing effects

Replaced thick, brightly coloured laser boxes with 7 mm warm tracer streaks moving at weapon-specific visual muzzle velocities. Impact visuals follow visual travel time. Added short procedural muzzle flashes, reduced light spill and excess sparks, retained ejected brass, and replaced large square bullet marks with smaller radial marks aligned to the hit surface. Damage remains hitscan; these are visual ballistics, not simulated projectile/drop gameplay.

## Verification

- Server race tests and go vet passed, including close-range pacing, falloff, recovery delay/rate/cap, spawn protection, loadout validation, and impact grenade collision/damage.
- Weapon/gameplay regressions passed, including rejection of unequipped weapons and visual tracer velocity.
- Native loadout checks passed at 1280×720, 960×640, and 2560×1440: all weapons, swapping slots, throwable selection, inventory use, and rendered firing effects. Screenshots are in this folder.
- Live online integration passed: custom primary applied, selected secondary switched, impact grenade replicated/detonated, authoritative inventory, seven moving online AI, damage, and scoreboard.
- Web release export completed. The local game/server are run for review; the public site has not been deployed by these changes.
