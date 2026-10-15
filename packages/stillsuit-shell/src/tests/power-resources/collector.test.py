"""Regression checks for Linux counters and unavailable optional telemetry."""

import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

COLLECTOR = Path(__file__).resolve().parents[2] / "plugins/builtin/resources/collect.py"
SPEC = importlib.util.spec_from_file_location("resource_collector", COLLECTOR)
assert SPEC is not None and SPEC.loader is not None
collector = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(collector)


class CollectorTests(unittest.TestCase):
    def test_rates_ignore_new_and_reset_devices(self) -> None:
        self.assertEqual(collector.rates({"disk": [100, 300]},
                                        {"disk": [140, 200], "new": [9000, 9000]}, 2),
                         [20, 0])

    def test_snapshot_excludes_guest_time_and_keeps_missing_metrics_absent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proc, sys = root / "proc", root / "sys"
            proc.mkdir()
            sys.mkdir()
            (proc / "stat").write_text("cpu 150 0 150 900 0 0 0 0 100 0\ncpu0 1\ncpu1 1\n")
            (proc / "meminfo").write_text("MemTotal: 1000 kB\nMemAvailable: 250 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n")
            (proc / "loadavg").write_text("2.00 1.00 0.50 1/100 7\n")
            before = {"cpu": [100, 0, 100, 800, 0, 0, 0, 0], "disks": {}, "network": {}, "time": 10}
            after = {"cpu": [150, 0, 150, 900, 0, 0, 0, 0], "disks": {}, "network": {}, "time": 12}
            with patch.object(collector, "gpus", return_value=[]):
                data = collector.snapshot(before, after, proc, sys)
            self.assertEqual(data["cpuPercent"], 50)
            self.assertEqual(data["memoryPercent"], 75)
            self.assertEqual(data["cores"], 2)
            self.assertEqual(data["swapTotalBytes"], 0)
            self.assertIsNone(data["cpuTemperature"])
            self.assertIsNone(data["pressure"]["cpu"])
            self.assertIsNone(data["diskReadBps"])
            self.assertIsNone(data["networkRxBps"])

    def test_counters_exclude_partitions_dm_and_virtual_network(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proc, sys = root / "proc", root / "sys"
            (proc / "net").mkdir(parents=True)
            (sys / "block/nvme0n1/device").mkdir(parents=True)
            (sys / "class/net/wlan0/device").mkdir(parents=True)
            (proc / "stat").write_text("cpu 100 0 100 800 0 0 0 0 90 0\n")
            (proc / "diskstats").write_text("259 0 nvme0n1 1 0 20 0 1 0 30 0 0 0 0\n"
                                          "259 1 nvme0n1p1 1 0 20 0 1 0 30 0 0 0 0\n"
                                          "253 0 dm-0 1 0 20 0 1 0 30 0 0 0 0\n")
            fields = "1000 0 0 0 0 0 0 0 2000 0 0 0 0 0 0 0"
            (proc / "net/dev").write_text("header\n" + "\n".join(
                f"{name}: {fields}" for name in ["wlan0", "lo", "docker0", "tailscale0"]))
            data = collector.counters(proc, sys)
            self.assertEqual(sum(data["cpu"]), 1000)
            self.assertEqual(data["disks"], {"nvme0n1": [20 * 512, 30 * 512]})
            self.assertEqual(data["network"], {"wlan0": [1000, 2000]})

    def test_nvidia_unsupported_fields_are_not_zero(self) -> None:
        response = type("Response", (), {"returncode": 0, "stdout": "NVIDIA GPU, N/A, 1, 24, N/A, N/A\n"})()
        with tempfile.TemporaryDirectory() as directory, patch.object(
            collector.subprocess, "run", return_value=response
        ):
            data = collector.gpus(Path(directory))[0]
        self.assertIsNone(data["percent"])
        self.assertIsNone(data["temperature"])
        self.assertIsNone(data["watts"])
        self.assertEqual(data["usedBytes"], 1024**2)


if __name__ == "__main__":
    unittest.main()
