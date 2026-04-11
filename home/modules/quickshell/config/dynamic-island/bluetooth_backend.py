#!/usr/bin/env python3
"""Bluetooth backend helper for Quickshell volume output switching.

Purpose:
Run bluetoothctl connect workflow as a standalone backend process.

Related files:
- menus/VolumeSliderMenu.qml: UI state machine and status rendering.
- menus/BluetoothUtils.js: sink parsing and matching helpers.

Specific concern:
- Execute bluetoothctl operations (show, power, trust, connect, info).
- Emit STATUS:/RESULT: lines consumed by the QML Process parser.
- Avoid any UI logic or PipeWire model shaping.
"""

from __future__ import annotations

import subprocess
import sys


def _run_bluetoothctl(*args: str) -> tuple[int, str]:
    proc = subprocess.run(
        ["bluetoothctl", *args],
        capture_output=True,
        text=True,
        check=False,
    )
    output = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode, output.strip()


def _print_status(message: str) -> None:
    print(f"STATUS:{message}", flush=True)


def _print_result(message: str) -> None:
    print(f"RESULT:{message}", flush=True)


def _is_connected(mac: str) -> bool:
    code, info = _run_bluetoothctl("info", mac)
    if code != 0:
        return False
    return "connected: yes" in info.lower()


def connect_device(mac: str) -> int:
    _print_status("CHECK_BACKEND")
    code, _ = _run_bluetoothctl("show")
    if code != 0:
        _print_result("BACKEND_UNAVAILABLE")
        return 0

    _print_status("POWER_ON")
    _run_bluetoothctl("power", "on")

    _print_status("CONNECT_DEVICE")
    _run_bluetoothctl("trust", mac)
    _, connect_output = _run_bluetoothctl("connect", mac)
    if connect_output:
        print(connect_output, flush=True)

    if _is_connected(mac):
        _print_result("OK")
    else:
        _print_result("FAIL")

    return 0


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: bluetooth_backend.py connect <MAC>", file=sys.stderr)
        return 2

    command = sys.argv[1]
    if command != "connect":
        print(f"Unknown command: {command}", file=sys.stderr)
        return 2

    mac = sys.argv[2]
    return connect_device(mac)


if __name__ == "__main__":
    raise SystemExit(main())
