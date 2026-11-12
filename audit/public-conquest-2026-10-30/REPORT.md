# All-map public Conquest defaults — 30 October 2026

Every canonical `<map>-public` room is now server-owned Conquest. The directory lists exactly one default public entry for each of the ten playable maps, removing the earlier duplicate Industrial Conquest preset. Public admission ignores stale client FFA/TDM mode and conflicting map options for these reserved identities. Invalid modes remain rejected. Custom rooms retain explicit mode selection; custom HTTP room creation defaults to Conquest.

The official combat container is replaced for a clean match state. This clears volatile rooms, actors, tickets, captures and scores. Dashboard accounts, audit storage, signing secrets and configuration are preserved. Public entries are joinable presets: rooms are instantiated on join, avoiding ten idle physics/bot simulations.

Server suite: 64 passed, zero failed, one optional benchmark skipped. The new regression checks all ten public presets against FFA/TDM/Conquest requests and a conflicting map, plus preservation of explicit custom TDM. TypeScript build passed.

This server-only release reuses the verified objective-marker native/Web artifacts (source fingerprint `2a9a09811524726fa723ca2f70e7cadd794e719411fb7cef55d30705c4c9e559`). It changes no rendering, prediction or combat physics. No fresh capacity benchmark or Git push was performed.

Official image: `warbase-colyseus:public-conquest-20261030`. Previous image is retained as a stopped rollback container with automatic restart disabled.

Deployment and official-domain verification passed for all ten maps. Each real SDK join deliberately requested stale FFA, received Conquest on the correct map with four objectives, an active round and 500/500 tickets, then left. Final directory verification showed exactly ten Conquest presets and zero humans/bots after cleanup. The native match was closed before reset so it did not recreate the old duplicate room.
