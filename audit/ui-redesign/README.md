# UI redesign

The lobby now uses a charcoal, muted-gold, and sage palette, a selected-operation hero, map previews, readable room cards, a dedicated loadout/preferences panel, and separate online/practice actions. The arena uses an overhead wireframe generated from its actual scene geometry; other previews are rendered from the game maps.

Combat UI has compact health/ammunition cards, a quieter identity badge, a corner killfeed, a controls hint, and optional FPS telemetry on F3. Pause and scoreboard overlays share the same theme. The scoreboard focuses on players instead of hardware diagnostics, and practice controls stay separate from online play.

Native windows have a 960×640 minimum and use responsive layout rather than shrinking all text below the design size. The deploy action and loadout panel were checked inside both 960×640 and 1280×720 windows. Create-match controls remain inside the window.

Validation: `gameplay-tests.log` contains the 12-check weapon regression and completed gameplay smoke run. `layout-checks.log` records the rendered bounds checks. Screenshots cover the lobby, settings, map selection, compact layout, match creation, HUD, scoreboard, and pause menu. The Web build has been regenerated.

Sources: `MainMenu.gd`, `HUD.gd`, and shared `WarUI.gd` under `warbase-godot/client/scripts/ui/`. Preview artwork can be rebuilt with Godot using `--script res://scripts/tools/render_menu_previews.gd`; optionally pass `-- map=arena` to regenerate one map.

The game was launched natively against the temporary local service at `localhost:18091`. This is a local development run, not a public deployment.

## Fullscreen, bots, and map browsing corrections

- Window content now scales from a 1280×720 logical layout at large resolutions, while retaining the 960×640 compact layout. Rendered checks passed at 960×640, 1280×720, 1920×1080, and 2560×1440.
- Practice is explicitly labelled “Play with bots”; verified that seven bots spawn. Online deploy remains a separate human-player match.
- Home preview now has previous/next map controls and a Browse maps shortcut. All nine supported room maps have their own rendered preview; removed Industrial fallback usage for the four additional room maps. Map selection uses the room's actual ID and mode.
- Weapon and gameplay regression checks and Web export passed after the changes.
