"""Read-only Linux performance snapshot, also runnable via `ssh host python3 -`."""

import csv
import json
import math
import socket
import subprocess
import time
from pathlib import Path
from typing import Any


def read(path: Path) -> str:
    try:
        return path.read_text().strip()
    except OSError:
        return ""


def number(raw: str) -> float | None:
    try:
        value = float(raw)
    except ValueError:
        return None
    return value if math.isfinite(value) else None


def counters(proc: Path, sys: Path) -> dict[str, Any]:
    stat = read(proc / "stat").splitlines()
    cpu = [int(value) for value in stat[0].split()[1:9]]
    # Physical whole disks only: partitions and dm layers would double count I/O.
    disks = {}
    for line in read(proc / "diskstats").splitlines():
        fields = line.split()
        name = fields[2]
        if len(fields) < 14 or not (sys / "block" / name / "device").exists():
            continue
        disks[name] = [int(fields[5]) * 512, int(fields[9]) * 512]
    # Physical interfaces only: exclude loopback, bridges, containers and VPNs.
    network = {}
    for line in read(proc / "net/dev").splitlines():
        name, sep, values = line.partition(":")
        name = name.strip()
        fields = values.split()
        if sep and len(fields) >= 16 and (sys / "class/net" / name / "device").exists():
            network[name] = [int(fields[0]), int(fields[8])]
    return {"cpu": cpu, "disks": disks, "network": network, "time": time.monotonic()}


def rates(before: dict[str, list[int]], after: dict[str, list[int]], seconds: float) -> list[float]:
    # Removed/new devices and counters reset by a reconnect are not activity spikes.
    return [sum(max(0, values[index] - before[name][index])
                for name, values in after.items() if name in before) / seconds
            for index in range(2)]


def cpu_temperature(sys: Path) -> float | None:
    values = []
    for sensor in (sys / "class/hwmon").glob("hwmon*"):
        if read(sensor / "name") not in {"coretemp", "k10temp", "zenpower", "cpu_thermal"}:
            continue
        for path in sensor.glob("temp*_input"):
            value = number(read(path))
            if value is not None:
                values.append(value / 1000)
    return max(values) if values else None


def pressure(proc: Path) -> dict[str, float | None]:
    result = {}
    for resource in ("cpu", "memory", "io"):
        result[resource] = None
        for line in read(proc / "pressure" / resource).splitlines():
            fields = line.split()
            if fields and fields[0] == "some":
                stats = dict(field.split("=", 1) for field in fields[1:] if "=" in field)
                result[resource] = number(stats.get("avg10", ""))
    return result


def gpus(sys: Path) -> list[dict[str, Any]]:
    result = []
    # NVIDIA reports N/A for unsupported fields; leave those absent, never zero.
    try:
        query = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=2, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        query = None
    if query is not None and query.returncode == 0:
        for fields in csv.reader(query.stdout.splitlines(), skipinitialspace=True):
            if len(fields) != 6:
                continue
            values = [number(field) for field in fields[1:]]
            result.append({"name": fields[0], "percent": values[0],
                           "usedBytes": values[1] * 1024**2 if values[1] is not None else None,
                           "totalBytes": values[2] * 1024**2 if values[2] is not None else None,
                           "temperature": values[3], "watts": values[4]})
    for card in (sys / "class/drm").glob("card[0-9]*"):
        if "-" in card.name or read(card / "device/vendor") != "0x1002":
            continue
        device = card / "device"
        used = number(read(device / "mem_info_vram_used"))
        total = number(read(device / "mem_info_vram_total"))
        temperatures = [number(read(path)) for path in device.glob("hwmon/hwmon*/temp*_input")]
        temperatures = [value / 1000 for value in temperatures if value is not None]
        result.append({"name": "AMD GPU", "percent": number(read(device / "gpu_busy_percent")),
                       "usedBytes": used, "totalBytes": total,
                       "temperature": max(temperatures) if temperatures else None, "watts": None})
    return result


def snapshot(before: dict[str, Any], after: dict[str, Any], proc: Path, sys: Path) -> dict[str, Any]:
    seconds = max(0.001, after["time"] - before["time"])
    deltas = [new - old for old, new in zip(before["cpu"], after["cpu"])]
    total = sum(deltas)
    idle = deltas[3] + deltas[4]
    cpu = max(0, min(100, (total - idle) / total * 100)) if total > 0 else None
    mem = {}
    for line in read(proc / "meminfo").splitlines():
        key, _, value = line.partition(":")
        fields = value.split()
        if fields:
            mem[key] = int(fields[0]) * 1024
    memory_total = mem.get("MemTotal")
    available = mem.get("MemAvailable")
    memory_used = (memory_total - available
                   if memory_total is not None and available is not None else None)
    swap_total = mem.get("SwapTotal")
    swap_free = mem.get("SwapFree")
    loads = read(proc / "loadavg").split()
    cores = sum(line.startswith("cpu") and line[3:4].isdigit()
                for line in read(proc / "stat").splitlines())
    disk = rates(before["disks"], after["disks"], seconds)
    net = rates(before["network"], after["network"], seconds)
    return {
        "schemaVersion": 1, "hostname": socket.gethostname(),
        "deviceKind": "laptop" if read(sys / "class/dmi/id/chassis_type") in {"8", "9", "10", "14", "31", "32"} else "desktop",
        "sampleSeconds": seconds, "cpuPercent": cpu,
        "memoryPercent": memory_used / memory_total * 100 if memory_used is not None and memory_total else None,
        "memoryUsedBytes": memory_used, "memoryTotalBytes": memory_total,
        "swapUsedBytes": swap_total - swap_free if swap_total is not None and swap_free is not None else None,
        "swapTotalBytes": swap_total, "load": [number(value) for value in loads[:3]],
        "cores": cores, "cpuTemperature": cpu_temperature(sys), "pressure": pressure(proc),
        "diskReadBps": disk[0] if after["disks"] else None,
        "diskWriteBps": disk[1] if after["disks"] else None,
        "networkRxBps": net[0] if after["network"] else None,
        "networkTxBps": net[1] if after["network"] else None,
        "gpus": gpus(sys),
    }


def main() -> None:
    proc, sys = Path("/proc"), Path("/sys")
    before = counters(proc, sys)
    time.sleep(0.5)
    after = counters(proc, sys)
    print(json.dumps(snapshot(before, after, proc, sys), allow_nan=False))


if __name__ == "__main__":
    main()
