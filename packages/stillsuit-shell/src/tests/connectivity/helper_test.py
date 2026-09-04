from __future__ import annotations

import importlib.machinery
import subprocess
from pathlib import Path
from types import ModuleType
from typing import Any


def load_helper(path: Path) -> ModuleType:
    return importlib.machinery.SourceFileLoader(
        "stillsuit_network", str(path)
    ).load_module()


def completed(
    command: list[str], stdout: str = "", stderr: str = "", code: int = 0
) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(command, code, stdout, stderr)


def main() -> None:
    helper_path = Path(__file__).resolve().parents[3] / "bin" / "stillsuit-network"
    helper = load_helper(helper_path)
    calls: list[dict[str, Any]] = []
    secret = "helper-secret-value"

    def fake_run(
        command: list[str],
        *,
        input_text: str | None = None,
        timeout: int = 25,
    ) -> subprocess.CompletedProcess[str]:
        calls.append({"command": command, "input": input_text, "timeout": timeout})
        if command[:2] == ["nmcli", "--ask"]:
            return completed(command)
        if "general" in command:
            return completed(command, "enabled\n")
        if command[-2:] == ["device", "status"]:
            return completed(command, "eth0:ethernet:connected:Fixture Ethernet\n")
        if "--get-values" in command and "802-11-wireless.ssid" in command:
            return completed(command, "Home\\:WiFi\n")
        if command[-2:] == ["connection", "show"]:
            return completed(
                command,
                "saved:Apartment Wi-Fi:802-11-wireless:no\n"
                "moberg:MobergAnalytics:vpn:no\n"
                "other:Other VPN:vpn:yes\n",
            )
        if "wifi" in command and "list" in command:
            return completed(
                command,
                "*:Home\\:WiFi:WPA2:88\n:Open\\:Cafe:--:63\n:Enterprise:WPA2 802.1X:74\n",
            )
        if command[:2] == ["tailscale", "status"]:
            return completed(
                command,
                '{"BackendState":"Running","Self":{"HostName":"fixture-host",'
                '"DNSName":"fixture-host.fixture.ts.net.","TailscaleIPs":['
                '"fd7a:115c:a1e0::1","100.64.0.9"]},"ExtraRecords":['
                '{"Name":"siren.fixture.ts.net.","Value":"100.64.0.10"},'
                '{"Name":"siren.fixture.ts.net.","Value":"fd7a:115c:a1e0::2"},'
                '{"Name":"vault.fixture.ts.net.","Value":"100.64.0.11"}]}',
            )
        if command == ["wl-copy"]:
            return completed(command)
        return completed(command)

    setattr(helper, "_run", fake_run)  # noqa: B010
    response = helper._dispatch(
        {
            "operation": "join",
            "kind": "personal",
            "name": "Secret Wi-Fi",
            "password": secret,
        }
    )
    join_call = next(
        call for call in calls if call["command"][:2] == ["nmcli", "--ask"]
    )
    assert secret not in "\0".join(join_call["command"])
    assert join_call["input"] == secret + "\n"
    assert secret not in str(response)
    assert response["ok"] is True
    assert response["snapshot"]["networks"][0]["name"] == "Home:WiFi"
    assert response["snapshot"]["networks"][0]["known"] is True
    assert response["snapshot"]["networks"][0]["uuid"] == "saved"
    assert response["snapshot"]["networks"][0]["profileName"] == "Apartment Wi-Fi"
    assert response["snapshot"]["networks"][1]["name"] == "Enterprise"
    assert response["snapshot"]["networks"][1]["kind"] == "enterprise"
    assert response["snapshot"]["networks"][2]["name"] == "Open:Cafe"
    assert response["snapshot"]["vpns"][0]["name"] == "MobergAnalytics"
    assert response["snapshot"]["vpns"][0]["toggleAllowed"] is True
    assert response["snapshot"]["vpns"][1]["name"] == "Other VPN"
    assert response["snapshot"]["vpns"][1]["readOnly"] is True
    assert response["snapshot"]["tailscale"] == {
        "available": True,
        "status": "running",
        "ip": "100.64.0.9",
        "hostName": "fixture-host",
        "dnsName": "fixture-host.fixture.ts.net",
        "services": ["siren.fixture.ts.net", "vault.fixture.ts.net"],
    }
    copied_dns = helper._dispatch({"operation": "copy-tailscale", "field": "dns"})
    assert copied_dns["ok"] is True
    dns_copy_call = next(call for call in calls if call["command"] == ["wl-copy"])
    assert dns_copy_call["input"] == "fixture-host.fixture.ts.net"
    calls.clear()
    copied_service = helper._dispatch(
        {
            "operation": "copy-tailscale",
            "field": "service",
            "serviceName": "siren.fixture.ts.net",
        }
    )
    assert copied_service["ok"] is True
    service_copy_call = next(
        call for call in calls if call["command"] == ["wl-copy"]
    )
    assert service_copy_call["input"] == "https://siren.fixture.ts.net"
    rejected_service = helper._dispatch(
        {
            "operation": "copy-tailscale",
            "field": "service",
            "serviceName": "unknown.fixture.ts.net",
        }
    )
    assert rejected_service["ok"] is False
    list_call = next(
        call
        for call in calls
        if call["command"][-2:] == ["connection", "show"]
    )
    assert "802-11-wireless.ssid" not in list_call["command"]
    assert any(
        "--get-values" in call["command"]
        and "802-11-wireless.ssid" in call["command"]
        for call in calls
    )

    calls.clear()
    saved_join = helper._dispatch(
        {"operation": "join", "kind": "saved", "uuid": "saved"}
    )
    assert saved_join["ok"] is True
    assert any(
        call["command"] == [
            "nmcli", "--wait", "25", "connection", "up", "uuid", "saved"
        ]
        for call in calls
    )

    def failing_run(
        command: list[str],
        *,
        input_text: str | None = None,
        timeout: int = 25,
    ) -> subprocess.CompletedProcess[str]:
        if command[:2] == ["nmcli", "--ask"]:
            return completed(command, stderr=f"bad password {secret}", code=10)
        return fake_run(command, input_text=input_text, timeout=timeout)

    setattr(helper, "_run", failing_run)  # noqa: B010
    failed = helper._dispatch(
        {
            "operation": "join",
            "kind": "personal",
            "name": "Secret Wi-Fi",
            "password": secret,
        }
    )
    assert failed["ok"] is False
    assert secret not in str(failed)
    assert "[REDACTED]" in failed["error"]

    calls.clear()
    setattr(helper, "_run", fake_run)  # noqa: B010
    rejected = helper._dispatch({"operation": "vpn-toggle", "uuid": "other"})
    assert rejected["ok"] is False
    assert "not allowlisted" in rejected["error"]
    assert not any(
        "connection" in call["command"] and "up" in call["command"] for call in calls
    )

    print("connectivity helper tests ok")


if __name__ == "__main__":
    main()
