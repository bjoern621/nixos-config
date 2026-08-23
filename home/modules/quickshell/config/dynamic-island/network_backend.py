#!/usr/bin/env python3
"""Network backend helper for the Quickshell network menu.

Purpose:
Run NetworkManager mutating actions as a standalone backend process.

Related files:
- base/NetworkService.qml: nmcli reads, models, action dispatch, status rendering.
- menus/NetworkUtils.js: terse-output parsing.
- menus/NetworkMenu.qml: view + password capture.

Specific concern:
- Execute nmcli / rfkill mutations (connect, disconnect, device, forget, vpn, radio, modify).
- Emit STATUS:/RESULT: lines consumed by the QML Process parser.
- Guarantee exactly one RESULT: line; QML waits on it with no timeout.
- No reads, no model shaping. Reads live in QML.
"""

from __future__ import annotations

import subprocess
import sys

# nmcli blocks on the D-Bus call while NetworkManager negotiates.
# A wrong-password associate can sit for the full activation window.
CMD_TIMEOUT = 45
CODE_TIMEOUT = 124
CODE_MISSING = 127


def _run(cmd: list[str]) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False,
            timeout=CMD_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        return CODE_TIMEOUT, f"{cmd[0]} timed out after {CMD_TIMEOUT}s"
    except FileNotFoundError:
        return CODE_MISSING, f"{cmd[0]} not found"
    output = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode, output.strip()


def _status(code: str) -> None:
    print(f"STATUS:{code}", flush=True)


def _result(code: str) -> None:
    print(f"RESULT:{code}", flush=True)


# Raw tool output to stderr. stdout carries the STATUS:/RESULT: protocol only.
def _echo(output: str) -> None:
    if output:
        print(output, file=sys.stderr, flush=True)


# nmcli maps a failed secret negotiation to exit 4.
# The row surfaces "wrong password" distinctly from a generic failure.
def _connect_result(code: int, output: str) -> None:
    if code == 0:
        _result("OK")
        return
    lower = output.lower()
    if code == CODE_MISSING:
        _result("FAIL:MISSING")
    elif "secrets were required" in lower or "no secrets" in lower or code == 4:
        _result("FAIL:AUTH")
    elif code == CODE_TIMEOUT:
        _result("FAIL:TIMEOUT")
    else:
        _result("FAIL")


def cmd_connect(argv: list[str]) -> int:
    # connect <ssid> <password> <hidden:0|1>
    ssid = argv[0]
    password = argv[1] if len(argv) > 1 else ""
    hidden = len(argv) > 2 and argv[2] == "1"

    _status("CONNECTING")
    cmd = ["nmcli", "device", "wifi", "connect", ssid]
    if password:
        cmd += ["password", password]
    if hidden:
        cmd += ["hidden", "yes"]
    code, output = _run(cmd)
    _echo(output)
    _connect_result(code, output)
    return 0


def cmd_disconnect(argv: list[str]) -> int:
    # disconnect <uuid-or-name>
    _status("DISCONNECTING")
    code, output = _run(["nmcli", "connection", "down", argv[0]])
    _echo(output)
    _result("OK" if code == 0 else "FAIL")
    return 0


def cmd_device(argv: list[str]) -> int:
    # device <connect|disconnect> <ifname>
    # Wired links are addressed per device, not per profile: several ethernet
    # adapters can be up at once, `disconnect` blocks autoconnect until asked
    # back up, and `connect` picks a profile even when none was saved.
    direction, ifname = argv[0], argv[1]
    _status("CONNECTING" if direction == "connect" else "DISCONNECTING")
    code, output = _run(["nmcli", "device", direction, ifname])
    _echo(output)
    _connect_result(code, output)
    return 0


def cmd_forget(argv: list[str]) -> int:
    # forget <uuid-or-name>
    code, output = _run(["nmcli", "connection", "delete", argv[0]])
    _echo(output)
    _result("OK" if code == 0 else "FAIL")
    return 0


def cmd_vpn(argv: list[str]) -> int:
    # vpn <up|down> <uuid-or-name>
    direction, target = argv[0], argv[1]
    _status("VPN_UP" if direction == "up" else "VPN_DOWN")
    code, output = _run(["nmcli", "connection", direction, target])
    _echo(output)
    _connect_result(code, output)
    return 0


def cmd_tailscale(argv: list[str]) -> int:
    # tailscale <up|down>
    # Tailscale is a tun device NetworkManager cannot toggle; the daemon owns it.
    # Operator permission (services.tailscale-client.operator) lets the user run
    # this without sudo.
    direction = argv[0]
    _status("VPN_UP" if direction == "up" else "VPN_DOWN")
    code, output = _run(["tailscale", direction])
    _echo(output)
    _connect_result(code, output)
    return 0


def cmd_wg_wstunnel(argv: list[str]) -> int:
    # wg-wstunnel <up|down>
    # wg-quick unit carried by wstunnel; NetworkManager cannot host either. A polkit
    # rule (modules/wireguard-wstunnel.nix) lets the user start/stop it without sudo.
    direction = argv[0]
    action = "start" if direction == "up" else "stop"
    _status("VPN_UP" if direction == "up" else "VPN_DOWN")
    code, output = _run(["systemctl", action, "wg-quick-wg-wstunnel.service"])
    _echo(output)
    _connect_result(code, output)
    return 0


def cmd_radio(argv: list[str]) -> int:
    # radio wifi <on|off>
    code, output = _run(["nmcli", "radio", "wifi", argv[1]])
    _echo(output)
    _result("OK" if code == 0 else "FAIL")
    return 0


def cmd_airplane(argv: list[str]) -> int:
    # airplane <on|off>  (on = block all radios)
    action = "block" if argv[0] == "on" else "unblock"
    code, output = _run(["rfkill", action, "all"])
    _echo(output)
    _result("OK" if code == 0 else "FAIL")
    return 0


def cmd_modify(argv: list[str]) -> int:
    # modify <uuid-or-name> <key> <value>
    target, key, value = argv[0], argv[1], argv[2]
    code, output = _run(["nmcli", "connection", "modify", target, key, value])
    _echo(output)
    _result("OK" if code == 0 else "FAIL")
    return 0


def cmd_rescan(_argv: list[str]) -> int:
    # A rescan within NetworkManager's rate-limit window exits non-zero.
    # That is not a user-facing failure, so it always reports OK.
    code, output = _run(["nmcli", "device", "wifi", "rescan"])
    _echo(output)
    _result("OK")
    return 0


_COMMANDS = {
    "connect": cmd_connect,
    "disconnect": cmd_disconnect,
    "device": cmd_device,
    "forget": cmd_forget,
    "vpn": cmd_vpn,
    "tailscale": cmd_tailscale,
    "wg-wstunnel": cmd_wg_wstunnel,
    "radio": cmd_radio,
    "airplane": cmd_airplane,
    "modify": cmd_modify,
    "rescan": cmd_rescan,
}


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] not in _COMMANDS:
        print(f"Usage: network_backend.py <{'|'.join(_COMMANDS)}> ...", file=sys.stderr)
        _result("FAIL")
        return 2

    handler = _COMMANDS[sys.argv[1]]
    try:
        return handler(sys.argv[2:])
    except IndexError:
        print(f"network_backend: missing argument for {sys.argv[1]}", file=sys.stderr)
        _result("FAIL")
        return 2
    except Exception as exc:  # one RESULT line no matter what; QML waits forever otherwise
        print(f"network_backend: {exc!r}", file=sys.stderr, flush=True)
        _result("FAIL")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
