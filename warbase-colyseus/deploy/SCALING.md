# Optional official Redis room services

The default remains Colyseus local presence and local room driver. `REDIS_URL` is omitted on Umbrel. There is no evidence yet that distributing rooms is needed; the full-room performance gate remains deferred. Redis does not split one battle's simulation across CPU cores.

`src/room-infrastructure.ts` can instantiate the official pinned `RedisPresence` and `RedisDriver` packages. Configuration and disabled-mode tests pass; a live two-worker Redis exercise has **not** been completed. This is optional infrastructure, not an activated production cluster.

Before enabling:

1. Provide a dedicated private Redis service/database reachable by every worker. Use access controls/TLS as appropriate. Do not reuse an unrelated application's database or expose Redis publicly.
2. Set the same `REDIS_URL` on all workers. Set a distinct reachable `PUBLIC_ADDRESS` for each worker. Matchmaking can run on any worker, but the returned room address must route the WebSocket to the worker that owns that room. Merely adding replicas behind round-robin routing is insufficient.
3. Keep admission JWT signing keys consistent across workers. Current admission, per-caller and room-creation quotas are process-local. Implement shared counters or enforce equivalent global gateway limits before production multi-worker activation; otherwise total permitted traffic grows with worker count.
4. Run real cross-worker matchmaking, listing, duplicate-session, reconnect, removal and worker-loss tests. HTTP room listings already read the framework driver instead of process-local active rooms. Operations metrics still describe only the worker serving the request.
5. Benchmark multiple simultaneous rooms. Retain a single worker if Redis/IPC overhead does not produce a measured benefit.

A failed configured Redis readiness check stops startup; it does not silently start an independent local matchmaking island. Graceful shutdown does not transfer an active battle to another worker.
