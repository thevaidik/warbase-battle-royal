#!/usr/bin/env python3
"""Diagnostic acceptance report for native/web observer + official load evidence."""

import argparse
import json
import math
import sys
from pathlib import Path


def _number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        return None
    return float(value)


def _path(obj, path):
    for key in path.split("."):
        if not isinstance(obj, dict) or key not in obj:
            return None
        obj = obj[key]
    return _number(obj)


def _first(obj, paths):
    for path in paths:
        result = _path(obj, path)
        if result is not None:
            return result
    return None


def _text(obj, paths):
    for path in paths:
        value = obj
        for part in path.split("."):
            value = value.get(part) if isinstance(value, dict) else None
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def evaluate(observer, load, server_ops, platform, *, frame_budget_ms=16.667,
             expected_players=64, minimum_duration_seconds=60,
             max_corrections_per_minute=10.0, max_correction_magnitude_m=2.5,
             max_client_memory_bytes=1_610_612_736,
             max_server_memory_bytes=1_610_612_736):
    """Build a report. Missing evidence is INCOMPLETE; only full evidence can PASS."""
    observed_seconds = _first(load or {}, ["runSeconds"])
    observer_seconds = _first(observer or {}, ["seconds", "duration_seconds"])
    load_duration = _first(load or {}, ["requested.durationSeconds"])
    measured_duration = observed_seconds if observed_seconds is not None else observer_seconds
    correction_count = _first(observer or {}, ["applied_corrections", "correction_count"])
    rate_duration = observer_seconds or measured_duration
    correction_rate = (correction_count * 60.0 / rate_duration
                       if correction_count is not None and rate_duration and rate_duration > 0 else None)
    correction_magnitude = _first(observer or {}, ["correction_magnitude_m_max"])
    # Raw last_correction_m can include intentional respawns/seat transitions.
    # Require a separately qualified gameplay correction measurement.

    observed_players = _first(load or {}, ["observed.humanActorsAtPeak", "observed.maxHumanPlayers"])
    version = _text(observer or {}, ["build_version", "version", "source_revision", "commit"]) \
        or _text(server_ops or {}, ["build_version", "version", "source_revision", "commit"])
    sdk_version = _text(load or {}, ["requested.sdk"])
    if version and sdk_version:
        version = f"{version}; sdk={sdk_version}"

    full_seconds = _first(load or {}, ["observed.fullOccupancySeconds"])
    checks = {
        "full_occupancy_seconds": {"status": "missing" if full_seconds is None else ("pass" if full_seconds >= minimum_duration_seconds else "fail"), "value": full_seconds, "minimum": minimum_duration_seconds},
        "platform": {"status": "observed", "value": platform},
        "build_version": {"status": "pass" if version else "missing", **({"value": version} if version else {})},
        "sdk_version": {"status": "pass" if sdk_version else "missing", **({"value": sdk_version} if sdk_version else {})},
        "occupancy_players": {"status": "missing" if observed_players is None else ("pass" if observed_players >= expected_players else "fail"),
                              "value": observed_players, "minimum": expected_players},
        "duration_seconds": {"status": "missing" if measured_duration is None else ("pass" if measured_duration >= minimum_duration_seconds else "fail"),
                             "value": measured_duration, "minimum": minimum_duration_seconds},
        "requested_duration_seconds": {"status": "missing" if load_duration is None else ("pass" if load_duration >= minimum_duration_seconds else "fail"),
                                        "value": load_duration, "minimum": minimum_duration_seconds},
        "frame_p95_ms": {"status": "missing" if _first(observer or {}, ["frame_ms_p95"]) is None else ("pass" if _first(observer, ["frame_ms_p95"]) <= frame_budget_ms else "fail"),
                          "value": _first(observer or {}, ["frame_ms_p95"]), "maximum": frame_budget_ms},
        "frame_p99_ms": {"status": "missing" if _first(observer or {}, ["frame_ms_p99"]) is None else ("pass" if _first(observer, ["frame_ms_p99"]) <= frame_budget_ms * 2 else "fail"),
                          "value": _first(observer or {}, ["frame_ms_p99"]), "maximum": frame_budget_ms * 2},
        "server_tick_p95_ms": {"status": "missing" if _first(server_ops or {}, ["server.tick_ms_p95", "tick_ms_p95"]) is None else ("pass" if _first(server_ops, ["server.tick_ms_p95", "tick_ms_p95"]) <= frame_budget_ms else "fail"),
                               "value": _first(server_ops or {}, ["server.tick_ms_p95", "tick_ms_p95"]), "maximum": frame_budget_ms},
        "disconnects": {"status": "missing" if _first(observer or {}, ["disconnects"]) is None else ("pass" if _first(observer, ["disconnects"]) == 0 else "fail"),
                        "value": _first(observer or {}, ["disconnects"]), "maximum": 0},
        "correction_rate_per_minute": {"status": "missing" if correction_rate is None else ("pass" if correction_rate <= max_corrections_per_minute else "fail"),
                                        "value": correction_rate, "maximum": max_corrections_per_minute},
        "correction_magnitude_m_max": {"status": "missing" if correction_magnitude is None else ("pass" if correction_magnitude <= max_correction_magnitude_m else "fail"),
                                        "value": correction_magnitude, "maximum": max_correction_magnitude_m},
        "client_memory_p95_bytes": {"status": "missing" if _first(observer or {}, ["client_memory_p95_bytes", "memory.client_rss_p95_bytes"]) is None else ("pass" if _first(observer, ["client_memory_p95_bytes", "memory.client_rss_p95_bytes"]) <= max_client_memory_bytes else "fail"),
                                     "value": _first(observer or {}, ["client_memory_p95_bytes", "memory.client_rss_p95_bytes"]), "maximum": max_client_memory_bytes},
        "server_memory_p95_bytes": {"status": "missing" if _first(server_ops or {}, ["server.memory_rss_p95_bytes", "memory_rss_p95_bytes"]) is None else ("pass" if _first(server_ops, ["server.memory_rss_p95_bytes", "memory_rss_p95_bytes"]) <= max_server_memory_bytes else "fail"),
                                     "value": _first(server_ops or {}, ["server.memory_rss_p95_bytes", "memory_rss_p95_bytes"]), "maximum": max_server_memory_bytes},
    }
    missing = [name for name, check in checks.items() if check["status"] == "missing"]
    failed = [name for name, check in checks.items() if check["status"] == "fail"]
    status = "FAIL" if failed else "INCOMPLETE" if missing else "PASS"
    return {"status": status, "platform": platform, "checks": checks,
            "missingMetrics": missing, "failedMetrics": failed,
            "limits": {"frameBudgetMs": frame_budget_ms, "expectedPlayers": expected_players,
                       "minimumDurationSeconds": minimum_duration_seconds,
                       "maxCorrectionsPerMinute": max_corrections_per_minute,
                       "maxCorrectionMagnitudeM": max_correction_magnitude_m,
                       "maxClientMemoryBytes": max_client_memory_bytes,
                       "maxServerMemoryBytes": max_server_memory_bytes},
            "note": "SDK helper RSS and client prediction timings are diagnostic only; neither substitutes for game memory or server tick measurements."}


def read_json(path):
    try:
        with Path(path).open(encoding="utf-8") as stream:
            value = json.load(stream)
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", required=True, choices=("native", "web"))
    parser.add_argument("--observer", required=True, help="native or web observer JSON")
    parser.add_argument("--load", required=True, help="official SDK load report JSON")
    parser.add_argument("--server-ops", help="server telemetry JSON with tick/memory percentiles")
    parser.add_argument("--frame-budget-ms", type=float, default=16.667, help="p95 frame and server tick budget (default 60 FPS)")
    parser.add_argument("--expected-players", type=int, default=64)
    parser.add_argument("--minimum-duration-seconds", type=float, default=60)
    parser.add_argument("--output", help="write report JSON")
    args = parser.parse_args(argv)
    try:
        report = evaluate(read_json(args.observer), read_json(args.load),
                          read_json(args.server_ops) if args.server_ops else None,
                          args.platform, frame_budget_ms=args.frame_budget_ms,
                          expected_players=args.expected_players,
                          minimum_duration_seconds=args.minimum_duration_seconds)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        Path(args.output).write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return {"PASS": 0, "INCOMPLETE": 2, "FAIL": 1}[report["status"]]


if __name__ == "__main__":
    raise SystemExit(main())
