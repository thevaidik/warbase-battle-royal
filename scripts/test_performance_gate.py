import unittest

from performance_gate import evaluate


def complete_inputs():
    observer = {
        "build_version": "abc123", "seconds": 120,
        "frame_ms_p95": 12, "frame_ms_p99": 25,
        "disconnects": 0, "applied_corrections": 1,
        "client_memory_p95_bytes": 1000, "correction_magnitude_m_max": 0.25,
        "prediction_samples": [{"diagnostics": {"last_correction_m": 0.25}}],
    }
    load = {"requested": {"sdk": "0.18", "sdkPeers": 63, "durationSeconds": 120},
            "runSeconds": 120,
            "observed": {"humanActorsAtPeak": 64, "fullOccupancySeconds": 120}}
    server_ops = {"build_version": "abc123", "server": {
        "tick_ms_p95": 10, "memory_rss_p95_bytes": 1000}}
    return observer, load, server_ops


class PerformanceGateTests(unittest.TestCase):
    def test_complete_metrics_pass_with_strict_60_fps_budget(self):
        self.assertEqual(evaluate(*complete_inputs(), "native")["status"], "PASS")

    def test_helper_rss_does_not_substitute_for_game_memory(self):
        observer, load, server = complete_inputs()
        observer.pop("client_memory_p95_bytes")
        load["helperResources"] = {"rssP95Bytes": 500}
        report = evaluate(observer, load, server, "web")
        self.assertEqual(report["checks"]["client_memory_p95_bytes"]["status"], "missing")
        self.assertEqual(report["status"], "INCOMPLETE")

    def test_prediction_timing_and_applied_count_are_not_server_tick_or_magnitude(self):
        observer, load, server = complete_inputs()
        server.pop("server")
        observer["prediction_final"] = {"qa_prediction_step_max_us": 10}
        observer["applied_corrections"] = 0
        observer["prediction_samples"] = []
        observer.pop("correction_magnitude_m_max")
        report = evaluate(observer, load, server, "native")
        self.assertEqual(report["checks"]["server_tick_p95_ms"]["status"], "missing")
        self.assertEqual(report["checks"]["correction_magnitude_m_max"]["status"], "missing")
        self.assertEqual(report["status"], "INCOMPLETE")

    def test_small_run_cannot_pass_and_threshold_violation_fails(self):
        observer, load, server = complete_inputs()
        load["observed"]["humanActorsAtPeak"] = 8
        observer["frame_ms_p95"] = 20
        report = evaluate(observer, load, server, "web")
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("occupancy_players", report["failedMetrics"])
        self.assertIn("frame_p95_ms", report["failedMetrics"])

    def test_peak_occupancy_and_respawn_corrections_cannot_certify_run(self):
        observer, load, server = complete_inputs()
        load["observed"].pop("fullOccupancySeconds")
        observer.pop("correction_magnitude_m_max")
        observer["prediction_final"] = {"last_correction_m": 100}
        report = evaluate(observer, load, server, "native")
        self.assertEqual(report["status"], "INCOMPLETE")
        self.assertIn("full_occupancy_seconds", report["missingMetrics"])
        self.assertIn("correction_magnitude_m_max", report["missingMetrics"])

    def test_missing_inputs_are_incomplete_not_zero(self):
        report = evaluate({"frame_ms_p95": 10}, {}, None, "native")
        self.assertEqual(report["status"], "INCOMPLETE")
        self.assertIn("disconnects", report["missingMetrics"])
        self.assertIn("server_tick_p95_ms", report["missingMetrics"])

    def test_explicit_independent_budgets_and_profiles(self):
        observer, load, server = complete_inputs()
        observer["frame_ms_p95"] = 8.2
        observer["frame_ms_p99"] = 11.5  # Exceeds 10.0 ms budget
        server["server"]["tick_ms_p95"] = 7.5
        server["server"]["tick_ms_p99"] = 11.0
        # Under legacy 16.667ms (p99 limit 33.3ms), this would pass.
        # Under strict native-120-v1 profile, it must fail because frame_ms_p99 > 10.0.
        report = evaluate(
            observer, load, server, "native",
            frame_p95_budget_ms=8.5, frame_p99_budget_ms=10.0,
            server_tick_p95_budget_ms=8.0, server_tick_p99_budget_ms=12.0,
            profile="native-120-v1"
        )
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("frame_p99_ms", report["failedMetrics"])
        self.assertEqual(report["profile"], "native-120-v1")
        self.assertEqual(report["checks"]["server_tick_p95_ms"]["status"], "pass")
        self.assertEqual(report["checks"]["server_tick_p99_ms"]["status"], "pass")

    def test_build_version_mismatch_fails_gate(self):
        observer, load, server = complete_inputs()
        server["build_version"] = "DIFFERENT_BUILD"
        report = evaluate(observer, load, server, "web", profile="desktop-web-60-v1")
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("build_version", report["failedMetrics"])

    def test_profile_desktop_web_60_v1_enforces_concrete_budgets(self):
        observer, load, server = complete_inputs()
        observer["frame_ms_p99"] = 25.0  # Over desktop-web-60-v1 20.0ms budget
        server["server"]["tick_ms_p99"] = 15.0  # Over 12.0ms budget
        report = evaluate(observer, load, server, "web", profile="desktop-web-60-v1")
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("frame_p99_ms", report["failedMetrics"])
        self.assertIn("server_tick_p99_ms", report["failedMetrics"])
        self.assertEqual(report["limits"]["frameP99BudgetMs"], 20.0)
        self.assertEqual(report["limits"]["serverTickP99BudgetMs"], 12.0)

    def test_cohort_validity_and_saturation_checks(self):
        # Invalid cohort run
        observer, load, server = complete_inputs()
        load["valid"] = False
        load["error"] = "dropped clients"
        report = evaluate(observer, load, server, "native")
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("cohort_valid", report["failedMetrics"])

        # Helper saturation suspected
        observer, load, server = complete_inputs()
        load["helperSaturationSuspected"] = True
        report = evaluate(observer, load, server, "native")
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("helper_saturation", report["failedMetrics"])

        # Capacity evidence not qualified
        observer, load, server = complete_inputs()
        load["capacityEvidenceQualified"] = False
        report = evaluate(observer, load, server, "native")
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("capacity_evidence_qualified", report["failedMetrics"])

    def test_observation_window_mismatch_fails_gate(self):
        observer, load, server = complete_inputs()
        observer["seconds"] = 30
        load["runSeconds"] = 120
        report = evaluate(observer, load, server, "native")
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("observation_window_overlap", report["failedMetrics"])

    def test_strict_profile_missing_provenance_is_incomplete(self):
        observer, load, server = complete_inputs()
        observer["frame_ms_p99"] = 18.0
        server["server"]["tick_ms_p95"] = 7.0
        # Missing server build in strict profile
        server.pop("build_version", None)
        report = evaluate(observer, load, server, "web", profile="desktop-web-60-v1")
        self.assertEqual(report["status"], "INCOMPLETE")
        self.assertIn("build_version", report["missingMetrics"])
        self.assertIn("protocol_version", report["missingMetrics"])

    def test_strict_profile_disjoint_windows_fails_gate(self):
        observer, load, server = complete_inputs()
        observer["build_version"] = "abc123"
        server["build_version"] = "abc123"
        observer["frame_ms_p99"] = 18.0
        server["server"]["tick_ms_p95"] = 7.0
        server["server"]["tick_ms_p99"] = 10.0
        for s in (observer, load, server):
            s["protocol_version"] = 16
            s["content_fingerprint"] = "fp123"
            s["source_fingerprint"] = "src123"
        load["valid"] = True
        load["helperSaturationSuspected"] = False
        load["capacityEvidenceQualified"] = True
        # Disjoint windows
        observer["measurement_window"] = {"timebase": "unix_ms", "start_ms": 1000, "end_ms": 121000}
        load["measurement_window"] = {"timebase": "unix_ms", "start_ms": 1000000, "end_ms": 1120000}
        server["measurement_window"] = {"timebase": "unix_ms", "start_ms": 1000000, "end_ms": 1120000}
        load["verified_occupancy_window"] = {"timebase": "unix_ms", "start_ms": 1000000, "end_ms": 1120000}
        report = evaluate(observer, load, server, "web", profile="desktop-web-60-v1")
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("observation_window_overlap", report["failedMetrics"])

    def test_zero_duration_fails_closed_without_crash(self):
        observer, load, server = complete_inputs()
        observer["seconds"] = 0
        load["runSeconds"] = 0
        report = evaluate(observer, load, server, "native", profile="legacy-60fps")
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("observer_duration", report["failedMetrics"])
        self.assertIn("load_duration", report["failedMetrics"])

    def test_unknown_profile_raises_value_error(self):
        observer, load, server = complete_inputs()
        with self.assertRaises(ValueError):
            evaluate(observer, load, server, "native", profile="nonexistent-profile-xyz")


if __name__ == "__main__":
    unittest.main()
