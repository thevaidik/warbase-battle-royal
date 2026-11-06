# Pinned Colyseus Godot compatibility patch

`colyseus-godot-0.18.9-room-lifetime.patch` applies only to the GDScript wrapper shipped with Godot SDK 0.18.9. Native dylibs and WASM are unchanged. The installer checks the original official ZIP checksum, applies this source patch, and records the resulting script hash in `LOCAL_PATCH.json`; native/Web export provenance carries that patch identity.

The patch fixes room signal closures retaining their wrapper and balances the extra `reference()` made by the pinned native SDK's `matchmaking_ptrcall_with_options` and `matchmaking_ptrcall_one_string`. The extra reference is released once after initial join/reconnect, error or leave. The request owner stays alive until async completion, then releases through Godot's deferred queue so cancelling before initial state does not orphan the request or destroy the client inside a native callback.

This is a targeted SDK ownership correction, not a transport or reconciliation rewrite. Revalidate the reference-count contract before updating the SDK; do not carry the compensation into a version that already balances its native return reference. Source: https://github.com/colyseus/native-sdk/blob/godot-v0.18.9/platforms/godot/src/colyseus_client.c

Coverage: all forwarded signals/payloads; weak wrapper disposal; real typed-state decode; walking/driving/walking reconciler handoff; reconnect/removal; ten repeated join/leave cycles; rejected joins; cancellation before initial state. The lifecycle fixture retains neither room wrapper nor native room after cleanup, and object counts plateau after warm-up. Browser verification is recorded in the release report separately.
