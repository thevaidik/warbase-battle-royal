# Persistent navigation, guns, room lighting, and online transport

## Menu

- Home, Loadout, Operator, and Settings stay in place across pages. Loadout opens below the header without Back/Done controls; Home restores the map preview and server list.
- Removed the redundant Maps tab. Map arrows select operations. The list heading is SERVERS ONLINE.
- One Join Server action for human and AI matches; an optional Offline switch keeps the local sandbox available without a separate Play With Bots button.
- Operator shows the actual animated soldier with the equipped primary, callsign, and session statistics.
- Loft 17 is removed from advertised rooms, room creation, map selection, exported map data, and release asset packaging. Source assets remain available in the checkout.

## Weapons

Removed the vehicle-asset machine gun import. WB-46 LMG is built from authored geometry: receiver, feed cover/hinge, belt and ammo box, barrel/cooling fins, handguard vents, folded bipod, carry handle, stock, sights, animated bolt and magazine, and muzzle/ejector markers. All seven guns receive receiver pins, selector/trigger details, ejection recesses and magazine/grip/rail detail. Static geometry is batched by material.

## Time of day

Four synchronized presets: Dawn 06:00, Noon 12:00, Dusk 18:00, Night 00:00. They change the sky, sun/moon direction and colour, ambient light, and fog. Public servers choose randomly on creation/new round. Custom rooms retain the preset chosen in Create Match. Server rows, selected-operation header, and in-game HUD show the room time.

## Cars

The previous client explicitly rejected entering online cars. Online transport now has server-authoritative seat claims, driver inputs, bounded movement/steering, chassis/terrain collision checks, input timeout braking, safe exit positions, health/damage, destruction, roadkills, and 20-second respawn. Driver snapshots activate the existing chase camera, and remote cars update on every client. E enters/exits a nearby available vehicle. Infantry weapons and grenades cannot be fired while driving. Turret combat is not implemented. Offline suspension physics remains separate from online kinematic simulation.

Removed an old hidden fallback vehicle collider from online infantry, which could intercept shots against soldiers. Actual replicated cars own their collisions.

The FPS protocol is version 4. Update client and service together.

## Evidence

- Godot weapon/gameplay regressions passed.
- Go race suite and go vet passed. Vehicle tests cover seat distance/ownership, driving, wall collision, stale controls, safe exit, authoritative damage, and respawn. A WebSocket test covers entry, inputs/motion, and exit across actual network sessions.
- Online Godot integration covers custom weapons/throwables, AI, room lighting, vehicle registration, driver-camera snapshot handling, and removal of ghost colliders.
- Native UI checks at 1280×720 and 960×640 verify fixed navigation and the create-room dialog; rendered screenshots include the operator, handmade LMG, and all four lighting presets.
- Web release export completed. Changes are run locally for review; no public deployment is performed. Longer multi-driver/latency playtests remain useful for tuning handling.
