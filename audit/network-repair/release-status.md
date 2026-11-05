> Historical handoff. See the [28 October follow-up](../production-followup-2026-10-28/REPORT.md) for subsequent fixes, full-suite results and official retesting.

# Release status — 28 October 2026

Deployed to https://war.vaidik.blog using `ssh umbrel`. Public health is available and the public index references `game-cbc1dc20e568e252.pck`. Server SHA-256: `cfa456203022a6b7cececa7513288e77345a1aa7111d4b4e30f70cd62b9a1f07`. Image: `warbase_server-warbase-server:network-complete-20261027`, also tagged `latest`. Public profiler returns 404; the active container has diagnostics disabled.

Previous deployment retained as `warbase-server-pre-complete`; original rollback retained as `warbase-server-before-network-20261027`. See the [handoff](README.md) for recovery details.

Updated native build: [WarBase-macOS.zip](../../build/WarBase-macOS.zip). ZIP integrity and Web packaging/compression checks passed. Godot regressions, targeted network race checks and cosmetic relevance checks passed; static analysis passed. Full server race suite had one failed bot RPM assertion, recorded in `server-tests-final.log`; investigation and deterministic retesting remain required. The corrected test fixture avoids copying protobuf mutexes.

No new full-capacity retest was started after the final refinements, as requested. Existing full-room latency and driving limits are documented in the handoff. This release is not certified production-ready for 64 players.
