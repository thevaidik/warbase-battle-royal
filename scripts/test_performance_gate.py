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


if __name__ == "__main__":
    unittest.main()
