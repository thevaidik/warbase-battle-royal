# Rugged cyberpunk UI — 6 November 2026

Dark gunmetal surfaces, acid-lime primary actions, cyan system accents, square panels, static corner markings and licensed Rajdhani display typography. Font is by Indian Type Foundry under SIL OFL 1.1; its license ships with the asset.

The home screen keeps persistent navigation, map browsing, online server counts, equipped kit and deployment controls. Small windows use a shorter map hero and scrollable lists. Loadout, operator, settings, pause and scoreboard inherit the shared theme.

The combat HUD uses larger health/ammo numerals, dark-backed tickets, separated objective chips, safe bottom margins and a kill feed below the top score region. Scope/crosshair and damage behavior remain gameplay-driven. Audio stays disabled.

Decoration redraws only on resize; no per-frame animation, blur, extra 3D scene, postprocess or render target was introduced. This is a design constraint, not a measured FPS improvement claim.

Verification: native rendering at 1440×900 and 960×640; lobby, loadout, operator, live practice HUD and pause screenshots. HUD ammo bounds asserted within viewport at both sizes. All 16 existing bounded Godot scenes passed. Screenshots use isolated UI fixture server rows and an offline practice match; their player counts are not live server telemetry.

Matched native/Web source fingerprint: `21149affbad355f6884dc50abeb2afa58b2631e59ee4dd1f162c57ae0eccd03b`. Protocol remains 7; native SDK/WASM binaries remain pinned. Font redistribution license is included in both export presets and verified in the Web pack. Release image: `warbase-colyseus:cyber-ui-20261106`.

Staged release passed health, signed admission, forged-forwarded-header rejection, HTML cache checks and public admin/monitor isolation. Screenshot fixture capture completed without script errors. Combat balance, networking protocol and server simulation are unchanged by this UI release.

Deployed and verified through the public domain. Public maps/room API and exact native/Web manifest fingerprint passed. The native packaged app was launched against `war.vaidik.blog`. Previous release containers and temporary build contexts were retired after health verification; persistent dashboard/secret volumes were preserved.
