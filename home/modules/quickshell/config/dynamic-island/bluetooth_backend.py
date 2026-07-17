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
import time

# Wedged bluetoothd or D-Bus never returns.
# QML has no way to cancel this process.
CMD_TIMEOUT = 20
# Exit codes for conditions the subprocess never reports itself.
# 124 mirrors timeout(1).
# 127 mirrors shell "command not found".
CODE_TIMEOUT = 124
CODE_MISSING = 127


def _run_bluetoothctl(*args: str) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            ["bluetoothctl", *args],
            capture_output=True,
            text=True,
            check=False,
            timeout=CMD_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        joined = " ".join(args)
        return CODE_TIMEOUT, f"bluetoothctl {joined} timed out after {CMD_TIMEOUT}s"
    except FileNotFoundError:
        return CODE_MISSING, "bluetoothctl not found"
    output = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode, output.strip()


# rfkill is the Linux interface that globally allows/blocks radio devices.
# "Soft blocked" means Bluetooth is disabled by software policy, so
# bluetoothctl power on can fail until rfkill unblock is executed.
# Return code 127 when rfkill is not installed so callers can handle that case safely.
def _run_rfkill(*args: str) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            ["rfkill", *args],
            capture_output=True,
            text=True,
            check=False,
            timeout=CMD_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        joined = " ".join(args)
        return CODE_TIMEOUT, f"rfkill {joined} timed out after {CMD_TIMEOUT}s"
    except FileNotFoundError:
        return CODE_MISSING, "rfkill not found"
    output = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode, output.strip()


def _print_status(message: str) -> None:
    print(f"STATUS:{message}", flush=True)


def _print_result(message: str) -> None:
    print(f"RESULT:{message}", flush=True)


# Raw bluetoothctl output to stderr.
# QML SplitParser reads stdout as protocol: STATUS:/RESULT: only.
def _echo(output: str) -> None:
    if output:
        print(output, file=sys.stderr, flush=True)


def _is_connected(mac: str) -> bool:
    code, info = _run_bluetoothctl("info", mac)
    if code != 0:
        return False
    return "connected: yes" in info.lower()


def _is_powered() -> bool:
    code, info = _run_bluetoothctl("show")
    if code != 0:
        return False
    return "powered: yes" in info.lower()


def _ensure_powered() -> bool:
    if _is_powered():
        return True

    _print_status("UNBLOCK_BLUETOOTH")
    _run_rfkill("unblock", "bluetooth")

    if _is_powered():
        return True

    _print_status("POWER_ON")
    code, output = _run_bluetoothctl("power", "on")
    _echo(output)
    if code == 0 and _is_powered():
        return True

    # bluetoothd can take a moment to report the new power state.
    for _ in range(20):
        if _is_powered():
            return True
        time.sleep(0.2)

    return False


def _connect_device(mac: str) -> int:
    _print_status("CHECK_BACKEND")
    code, _ = _run_bluetoothctl("show")
    if code != 0:
        _print_result("BACKEND_UNAVAILABLE")
        return 0

    if not _ensure_powered():
        _print_result("FAIL")
        return 0

    _print_status("CONNECT_DEVICE")
    _run_bluetoothctl("trust", mac)
    _, connect_output = _run_bluetoothctl("connect", mac)
    _echo(connect_output)

    if _is_connected(mac):
        _print_result("OK")
    else:
        _print_result("FAIL")

    return 0


def connect_device(mac: str) -> int:
    """Run connect workflow, guaranteeing exactly one RESULT: line.

    QML waits on RESULT: with no timeout.
    Exiting silently on an exception spins it forever.
    """
    try:
        return _connect_device(mac)
    except Exception as exc:
        print(f"bluetooth_backend: {exc!r}", file=sys.stderr, flush=True)
        _print_result("FAIL")
        return 1


def main() -> int:
    # Argv errors emit RESULT:FAIL too.
    # QML has no other exit signal to wait on.
    if len(sys.argv) < 3:
        print("Usage: bluetooth_backend.py connect <MAC>", file=sys.stderr)
        _print_result("FAIL")
        return 2

    command = sys.argv[1]
    if command != "connect":
        print(f"Unknown command: {command}", file=sys.stderr)
        _print_result("FAIL")
        return 2

    mac = sys.argv[2]
    return connect_device(mac)


if __name__ == "__main__":
    raise SystemExit(main())
