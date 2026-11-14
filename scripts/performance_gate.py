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


PROFILES = {
    "desktop-web-60-v1": {
        "frame_p95_budget_ms": 16.9,
        "frame_p99_budget_ms": 20.0,
        "server_tick_p95_budget_ms": 8.0,
        "server_tick_p99_budget_ms": 12.0,
    },
    "native-60-v1": {
        "frame_p95_budget_ms": 16.667,
        "frame_p99_budget_ms": 20.0,
        "server_tick_p95_budget_ms": 8.0,
        "server_tick_p99_budget_ms": 12.0,
    },
    "native-120-v1": {
        "frame_p95_budget_ms": 8.5,
        "frame_p99_budget_ms": 10.0,
        "server_tick_p95_budget_ms": 8.0,
        "server_tick_p99_budget_ms": 12.0,
    },
    "legacy-60fps": {
        "frame_p95_budget_ms": 16.667,
        "frame_p99_budget_ms": 33.334,
        "server_tick_p95_budget_ms": 16.667,
        "server_tick_p99_budget_ms": None,
    },
}


def evaluate(observer, load, server_ops, platform, *, frame_budget_ms=16.667,
             frame_p95_budget_ms=None, frame_p99_budget_ms=None,
             server_tick_p95_budget_ms=None, server_tick_p99_budget_ms=None,
             max_frames_over_33ms=None, max_late_ticks=None,
             profile=None,
             expected_players=64, minimum_duration_seconds=60,
             max_corrections_per_minute=10.0, max_correction_magnitude_m=2.5,
             max_client_memory_bytes=1_610_612_736,
             max_server_memory_bytes=1_610_612_736):
    """Build a report. Missing evidence is INCOMPLETE; only full evidence can PASS."""
    if profile is not None and profile not in PROFILES:
        raise ValueError(f"unknown performance profile: {profile}")
    strict = profile != "legacy-60fps" and (profile is not None or any(
        value is not None for value in (frame_p95_budget_ms, frame_p99_budget_ms,
                                        server_tick_p95_budget_ms, server_tick_p99_budget_ms)))
    # Resolve profile defaults vs explicit budgets
    prof_defaults = PROFILES.get(profile, {}) if profile else {}
    is_legacy = (profile is None and frame_p95_budget_ms is None and frame_p99_budget_ms is None and
                 server_tick_p95_budget_ms is None and server_tick_p99_budget_ms is None)
    eff_frame_p95 = frame_p95_budget_ms if frame_p95_budget_ms is not None else prof_defaults.get("frame_p95_budget_ms", frame_budget_ms)
    eff_frame_p99 = frame_p99_budget_ms if frame_p99_budget_ms is not None else prof_defaults.get("frame_p99_budget_ms", frame_budget_ms * 2)
    eff_server_p95 = server_tick_p95_budget_ms if server_tick_p95_budget_ms is not None else prof_defaults.get("server_tick_p95_budget_ms", frame_budget_ms)
    eff_server_p99 = server_tick_p99_budget_ms if server_tick_p99_budget_ms is not None else prof_defaults.get("server_tick_p99_budget_ms", None)
    eff_profile = profile or ("legacy-60fps" if is_legacy else "custom-budget-v1")

    observed_seconds = _first(load or {}, ["runSeconds"])
    observer_seconds = _first(observer or {}, ["seconds", "duration_seconds"])
    load_duration = _first(load or {}, ["requested.durationSeconds"])
    measured_duration = observed_seconds if observed_seconds is not None else observer_seconds
    correction_count = _first(observer or {}, ["applied_corrections", "correction_count"])
    rate_duration = observer_seconds or measured_duration
    correction_rate = (correction_count * 60.0 / rate_duration
                       if correction_count is not None and rate_duration and rate_duration > 0 else None)
    correction_magnitude = _first(observer or {}, ["correction_magnitude_m_max"])

    observed_players = _first(load or {}, ["observed.humanActorsAtPeak", "observed.maxHumanPlayers"])

    obs_build = _text(observer or {}, ["build_version", "version", "source_revision", "commit"])
    srv_build = _text(server_ops or {}, ["build_version", "version", "source_revision", "commit"])
    sdk_version = _text(load or {}, ["requested.sdk"])

    full_seconds = _first(load or {}, ["observed.fullOccupancySeconds"])
    checks = {
        "full_occupancy_seconds": {"status": "missing" if full_seconds is None else ("pass" if full_seconds >= minimum_duration_seconds else "fail"), "value": full_seconds, "minimum": minimum_duration_seconds},
        "platform": {"status": "observed", "value": platform},
        "sdk_version": {"status": "pass" if sdk_version else "missing", **({"value": sdk_version} if sdk_version else {})},
        "occupancy_players": {"status": "missing" if observed_players is None else ("pass" if observed_players >= expected_players else "fail"),
                              "value": observed_players, "minimum": expected_players},
        "duration_seconds": {"status": "missing" if measured_duration is None else ("pass" if measured_duration >= minimum_duration_seconds else "fail"),
                             "value": measured_duration, "minimum": minimum_duration_seconds},
        "requested_duration_seconds": {"status": "missing" if load_duration is None else ("pass" if load_duration >= minimum_duration_seconds else "fail"),
                                        "value": load_duration, "minimum": minimum_duration_seconds},
        "frame_p95_ms": {"status": "missing" if _first(observer or {}, ["frame_ms_p95"]) is None else ("pass" if _first(observer, ["frame_ms_p95"]) <= eff_frame_p95 else "fail"),
                          "value": _first(observer or {}, ["frame_ms_p95"]), "maximum": eff_frame_p95},
        "frame_p99_ms": {"status": "missing" if _first(observer or {}, ["frame_ms_p99"]) is None else ("pass" if _first(observer, ["frame_ms_p99"]) <= eff_frame_p99 else "fail"),
                          "value": _first(observer or {}, ["frame_ms_p99"]), "maximum": eff_frame_p99},
        "server_tick_p95_ms": {"status": "missing" if _first(server_ops or {}, ["server.tick_ms_p95", "tick_ms_p95"]) is None else ("pass" if _first(server_ops, ["server.tick_ms_p95", "tick_ms_p95"]) <= eff_server_p95 else "fail"),
                               "value": _first(server_ops or {}, ["server.tick_ms_p95", "tick_ms_p95"]), "maximum": eff_server_p95},
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

    # Version comparison check
    if obs_build and srv_build:
        if obs_build != srv_build:
            checks["build_version"] = {
                "status": "fail",
                "observer_build": obs_build,
                "server_build": srv_build,
                "error": "observer and server build versions do not match"
            }
        else:
            checks["build_version"] = {"status": "pass", "value": obs_build}
    elif not strict and (obs_build or srv_build):
        checks["build_version"] = {"status": "pass", "value": obs_build or srv_build}
    else:
        checks["build_version"] = {"status": "missing"}

    # Strict profiles require typed coordinator evidence; omission is not success.
    for key, check_name, expected in (
        ("valid", "cohort_valid", True),
        ("helperSaturationSuspected", "helper_saturation", False),
        ("capacityEvidenceQualified", "capacity_evidence_qualified", True),
    ):
        value = (load or {}).get(key)
        if strict or key in (load or {}):
            checks[check_name] = {"status": "missing" if value is None else
                                  "pass" if value is expected else "fail", "value": value}

    if strict:
        sources = (observer or {}, load or {}, server_ops or {})
        for field in ("protocol_version", "content_fingerprint", "source_fingerprint"):
            values = [source.get(field) for source in sources]
            present = [(isinstance(v, int) and not isinstance(v, bool) and v >= 0)
                       if field == "protocol_version" else
                       (isinstance(v, str) and bool(v.strip())) for v in values]
            checks[field] = {"status": "missing" if not all(present) else
                             "pass" if values[0] == values[1] == values[2] else "fail"}

        # Canonical capture intervals are UTC Unix milliseconds, not durations
        # or unrelated monotonic clocks. Include the verified occupancy window.
        windows = [source.get("measurement_window", {}) for source in sources]
        windows.append((load or {}).get("verified_occupancy_window", {}))
        intervals = []
        window_status = "pass"
        for window in windows:
            if not isinstance(window, dict) or window.get("timebase") != "unix_ms":
                if window_status != "fail": window_status = "missing"
                continue
            start, end = _number(window.get("start_ms")), _number(window.get("end_ms"))
            if start is None or end is None:
                if window_status != "fail": window_status = "missing"
            elif start < 0 or end <= start:
                window_status = "fail"
            else:
                intervals.append((start, end))
        overlap = None
        if len(intervals) == 4:
            overlap = max(0, min(end for _, end in intervals) - max(start for start, _ in intervals)) / 1000
            if overlap < minimum_duration_seconds: window_status = "fail"
        checks["observation_window_overlap"] = {"status": window_status,
                                                "overlap_seconds": overlap,
                                                "minimum": minimum_duration_seconds}
    elif observed_seconds is not None and observer_seconds is not None:
        # Compatibility diagnostic only; this is not proof of shared timestamps.
        positive = observed_seconds > 0 and observer_seconds > 0
        ratio = min(observed_seconds, observer_seconds) / max(observed_seconds, observer_seconds) if positive else 0
        checks["observation_window_overlap"] = {"status": "pass" if positive and ratio >= 0.75 else "fail",
                                                "legacy_duration_comparison_only": True}
    for name, duration in (("observer_duration", observer_seconds), ("load_duration", observed_seconds)):
        if duration is not None and duration <= 0:
            checks[name] = {"status": "fail", "value": duration}
    if eff_server_p99 is not None:
        val = _first(server_ops or {}, ["server.tick_ms_p99", "tick_ms_p99"])
        checks["server_tick_p99_ms"] = {
            "status": "missing" if val is None else ("pass" if val <= eff_server_p99 else "fail"),
            "value": val, "maximum": eff_server_p99
        }
    if max_frames_over_33ms is not None:
        val = _first(observer or {}, ["frames_over_33ms", "frames_gt_33ms"])
        checks["frames_over_33ms"] = {
            "status": "missing" if val is None else ("pass" if val <= max_frames_over_33ms else "fail"),
            "value": val, "maximum": max_frames_over_33ms
        }
    if max_late_ticks is not None:
        val = _first(server_ops or {}, ["server.late_ticks", "late_ticks"])
        checks["late_ticks"] = {
            "status": "missing" if val is None else ("pass" if val <= max_late_ticks else "fail"),
            "value": val, "maximum": max_late_ticks
        }

    missing = [name for name, check in checks.items() if check["status"] == "missing"]
    failed = [name for name, check in checks.items() if check["status"] == "fail"]
    status = "FAIL" if failed else "INCOMPLETE" if missing else "PASS"
    return {"status": status, "schema_version": 2, "profile": eff_profile, "platform": platform, "checks": checks,
            "missingMetrics": missing, "failedMetrics": failed,
            "limits": {"frameBudgetMs": frame_budget_ms,
                       "frameP95BudgetMs": eff_frame_p95,
                       "frameP99BudgetMs": eff_frame_p99,
                       "serverTickP95BudgetMs": eff_server_p95,
                       "serverTickP99BudgetMs": eff_server_p99,
                       "expectedPlayers": expected_players,
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
    parser.add_argument("--frame-budget-ms", type=float, default=16.667, help="legacy p95 frame and server tick budget (default 60 FPS)")
    parser.add_argument("--frame-p95-budget-ms", type=float, help="explicit p95 frame budget (e.g. 16.9 or 8.5)")
    parser.add_argument("--frame-p99-budget-ms", type=float, help="explicit p99 frame budget (e.g. 20.0 or 10.0)")
    parser.add_argument("--server-tick-p95-budget-ms", type=float, help="explicit server tick p95 budget (e.g. 8.0)")
    parser.add_argument("--server-tick-p99-budget-ms", type=float, help="explicit server tick p99 budget (e.g. 12.0)")
    parser.add_argument("--profile", help="named acceptance profile, e.g. desktop-web-60-v1")
    parser.add_argument("--expected-players", type=int, default=64)
    parser.add_argument("--minimum-duration-seconds", type=float, default=60)
    parser.add_argument("--output", help="write report JSON")
    args = parser.parse_args(argv)
    try:
        report = evaluate(read_json(args.observer), read_json(args.load),
                          read_json(args.server_ops) if args.server_ops else None,
                          args.platform, frame_budget_ms=args.frame_budget_ms,
                          frame_p95_budget_ms=args.frame_p95_budget_ms,
                          frame_p99_budget_ms=args.frame_p99_budget_ms,
                          server_tick_p95_budget_ms=args.server_tick_p95_budget_ms,
                          server_tick_p99_budget_ms=args.server_tick_p99_budget_ms,
                          profile=args.profile,
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
