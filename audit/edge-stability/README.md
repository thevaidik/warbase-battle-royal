# Remaining edge shimmer: rendering profile

The earlier stadium mesh-overlap fix and disabled world shadows remain. User still reports flickering edges, so this pass targets spatial edge aliasing and unsynchronized frame presentation without claiming the exact remaining artifact has been visually identified.

Changes:
- 4× MSAA configured in both project settings and the actual game viewport.
- Full-resolution 3D rendering on desktop and web; removed the web's 0.85× bilinear upscaling.
- V-sync enabled by default, with the existing F3 toggle retained.
- Real-time map shadows remain disabled.

Validation:
- `native-check.log`: actual fullscreen framebuffer 3024×1898, 4× MSAA (enum value 2), render scale 1.0, synchronized presentation; 120 FPS reported during a 1.49 second, 8.44 metre walking sample. Sun and map transforms stayed fixed.
- `godot-tests.log`: stadium geometry/spawns, grenade, Industrial collision, weapons and gameplay checks passed.
- `web-tests.log`: main and optional-pack compression/hash and actual optional-pack mounting checks passed.

The user was asked whether this happens in the native fullscreen game or browser, and whether it is stadium-only or affects other maps. A short recording would be needed to distinguish any remaining edge artifact conclusively from temporal aliasing, tearing, or another geometry/material defect.
