# Performance gate

Generate a platform-specific report from an observer capture, full-room SDK load artifact, and server telemetry capture:

```sh
python3 scripts/performance_gate.py \
  --platform native \
  --observer path/to/native-observer.json \
  --load path/to/official-load.json \
  --server-ops path/to/server-ops.json \
  --output audit/performance-next-2026-11-05/report.json
```

For web, pass `--platform web` and a web observer artifact. The observer must include frame p95/p99, disconnects, correction count and sampled maximum correction magnitude, client RSS p95, run duration, and build/version metadata. The server telemetry JSON must contain `server.tick_ms_p95` and `server.memory_rss_p95_bytes` plus build/version metadata. Full-room acceptance additionally requires `observed.fullOccupancySeconds`; a momentary peak is insufficient. Correction magnitude must explicitly exclude intentional teleports/respawns. The load artifact must identify its SDK version, requested duration, run duration, and peak human occupancy. Its helper process RSS is deliberately excluded: it is not game memory. Native QA prediction timings are client-side work, not server tick duration.

Defaults require 64 humans for at least 60 seconds. The p95 frame and server tick budget defaults to 16.667 ms (60 FPS); p99 frame budget is twice that. Disconnects must be zero. Correction rate defaults to at most 10/minute and maximum correction magnitude to 2.5 m. Client and server memory each default to at most 1.5 GiB. `--frame-budget-ms`, `--expected-players`, and `--minimum-duration-seconds` are configurable. Missing measurements produce `INCOMPLETE`, threshold violations produce `FAIL`, and only complete evidence can produce `PASS`.

Run focused tests with:

```sh
python3 -m unittest discover -s scripts -p 'test_performance_gate.py' -v
```
