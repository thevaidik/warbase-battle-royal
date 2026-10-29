# Official Colyseus load diagnostic

Run: 2026-10-29 UTC, `https://war.vaidik.blog/colyseus`, Industrial FFA, room `8becd331-0602-4b36-9c9c-6e187da606a4`. The cohort ran on Umbrel’s nested `warbase_server_default` Docker network, colocated with the candidate server. It used 63 Colyseus SDK clients plus one native `QA_NATIVE` observer, a 180-second measurement window, and a 2 CPU / 1536 MiB / 128 PID helper-container limit.

## Results

- 63/63 SDK peers joined. Server state reached 64 human actors at peak. The native observer left early after its frame rate dropped; the run therefore does **not** demonstrate 64 humans sustained for 180 seconds or establish a capacity limit.
- The SDK cohort sent 705,263 buffered inputs at the advertised 60 Hz rate; ACKs advanced by 694,047 sequence numbers. SDK ping RTT was 764 ms p50 and 1,342 ms p95. State-patch gaps were 1,215 ms p95 and 2,415 ms maximum.
- Authoritative movement was observed for all 63 SDK peers, with each moving over 0.5 m and 7,172.87 m of combined sampled path.
- Gameplay coverage: 63 fire echoes, 38 confirmed hits, 8 accepted grenades and 8 unique explosions, 15 seat entries, 799 vehicle inputs, and 2 moving vehicles covering 14.63 m total. No kill confirmation occurred, so kill-confirmation behavior was not covered.
- The intentional transport drop reconnected successfully. Cleanup observed 62/62 expected non-gate SDK peer removals, with no cleanup timeout or harness errors. The candidate returned 404 for the temporary room after cleanup.
- Candidate container CPU averaged 94.9%, reached 112.0% p95 and 114.8% maximum (Docker reports 100% as one core); maximum memory was 126.4 MiB. The helper averaged 22.2% CPU, peaked at 57.2%, and used at most 77.5 MiB of its 1.5 GiB limit. These are Umbrel-side readings; cohort RTT does not represent Mac-user latency.

## Observer limitation

The single Godot observer ran headless with `--max-fps 30`, not with graphical GPU rendering. Its partial log shows 30 FPS through approximately `t=43s`, followed by 1–3 FPS from `t=44s` through `t=61s` while it had 63 remotes. The parent/client reported about 99% CPU, then stopped that exact process. This is headless software-rendering evidence, not graphical-player FPS. No final observer JSON was produced.

## Reporting notes

The raw runner JSON says `nativeObserverSeen: false` because it checked the observer after the gate client had left during cleanup. The runner had already required `QA_NATIVE` to appear as a human before starting the cohort, and server state reached 64 humans at peak. The raw file is preserved unchanged; the reusable harness now records the gate verification before cleanup.

The raw `peersWithAckStalls: 20442` field also mislabeled a count of repeated 100 ms sampling intervals, not distinct peers. The reusable harness now reports those intervals separately and counts unique peers. Treat the raw count as intervals only.

The overall result is a bounded diagnostic, not a pass or capacity claim. High server CPU, ACK backlog, long state-patch gaps, and the headless observer slowdown warrant client/server optimization before repeating this run.

## Artifacts and cleanup

- Raw cohort report: `official-load-umbrel.json` (SHA-256 `27c33203b3757169e497ed8c693b5c3c5451532826073b89bd6560c4254865ef`)
- Container resources: `official-load-container-resources.csv` (SHA-256 `9a82e5161abe1c3c8f129864bce3bdd8df188d6c9f91fb4e18fc1f65a9628b0d`)
- Helper log: `official-load-helper.log` (SHA-256 `c82763abdd7c344574044a5fee00a2faf6336a0f91db01516c2a398125da1970`)
- Partial native observer log: `native-observer.log` (SHA-256 `af3e12fc2de1acbf6c5ccb117552ab63a35f21ee7b1e73d6e9e0e0a4a0e89bcb`)

The helper container auto-removed. Both outer and nested Docker engines have no load-test container or `warbase-colyseus-load:temporary` image. The candidate and legacy server containers remain healthy.

## Repeat after server and client optimization

The optimized candidate was tested on 2026-10-29 UTC in fresh room `7b0c8bb7-cec4-4194-9914-248ff99ea5c1`, again with 63 SDK peers and one native observer. The SDK cohort completed its 180-second window in 256.5 seconds wall time. The observer reached 63 remotes and verified as human; it was stopped around t=70 after sustained headless 1–4 FPS and about 99% process CPU. It therefore also does not demonstrate 64 humans sustained for the full window.

| Metric | Before optimization | Repeat | Interpretation |
| --- | ---: | ---: | --- |
| Candidate CPU average / p95 / max | 94.9% / 112.0% / 114.8% | 94.5% / 114.8% / 120.4% | No measured CPU reduction; peak was higher. Docker CPU percentages use 100% per core. |
| Candidate memory max | 126.4 MiB | 115.4 MiB | Slightly lower peak. |
| SDK ping RTT p50 / p95 | 764 / 1,342 ms | 677 / 1,239 ms | Lower, but still high; clients were colocated with the server. |
| State-gap p95 / max | 1,215 / 2,415 ms | 1,054 / 2,191 ms | Lower, but state updates still had long gaps. |
| SDK peers joined / peak humans | 63 / 64 | 63 / 64 | Observer left before the cohort window ended in both runs. |

Repeat gameplay coverage included 20 confirmed hits, 8 accepted grenades and 8 unique explosions, 13 seat entries, 725 vehicle inputs, and 2 vehicles moving 13.38 m total. All 63 SDK peers moved over 0.5 m; total sampled path was 8,139.83 m. ACKs advanced 694,323 of 704,694 sent inputs; all 63 SDK peers experienced at least one ACK-stall interval. One intentional transport drop reconnected successfully. Cleanup observed 62/62 expected peer removals, with zero harness errors or timeout. Kill confirmations remained uncovered (`killEvents=0`).

The repeat observer JSON is cumulative through about t=70 (`frame_ms_p50=33.36`, `frame_ms_p95=134.27`, `cpu_process_ms_p95=823.4`), while its per-second log shows 1–4 FPS from t=63–70 at 63 remotes. Treat the latter as the late-run behavior; cumulative p50 masks the stall. This was headless software rendering, not graphical GPU performance. The observer report also recorded a maximum position error of 22.0 m and five snapshots over 2.5 m error.

The repeat harness now records observer-gate verification before cleanup and separates ACK-stall intervals from distinct affected peers. The raw first-run report above remains unchanged with its original post-cleanup observer-field issue. The nested helper build succeeded; its cache reference used an obsolete image tag and BuildKit continued without importing that cache. For future runs the wrapper now discovers the active candidate image tag automatically.

Repeat artifacts:

- Raw cohort report: `official-load-repeat-umbrel.json` (SHA-256 `d662ebd91f14cc1d348fa3f4d24464ebcde17dd8e3e0b30c89045a77049a5deb`)
- Container resource samples: `official-load-repeat-container-resources.csv` (SHA-256 `f7a307617a766c3134d19840823727b2291511021c209508c217dafda9159423`)
- Helper log: `official-load-repeat-helper.log` (SHA-256 `56c33f76b2f49016d9e7eb2991949d365cafd6fa920f385bd18253a7c6db5631`)
- Partial headless observer report/log: `native-observer-repeat.json` / `native-observer-repeat.log` (the report is incomplete by design because the observer was stopped to limit CPU).

After the repeat, the temporary room returned 404. No helper container or `warbase-colyseus-load:temporary` image remained in either Docker engine, and both candidate and legacy server containers were healthy.
