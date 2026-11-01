# Arms kill switch on CyberGhost VPN up.
# Deliberate disconnect releases it, any other drop keeps it and notifies.
# Needs DEVICE and UNIT in environment.

# NMVpnConnectionState and NMActiveConnectionStateReason values.
readonly ACTIVATED=5 FAILED=6 DISCONNECTED=7 USER_DISCONNECTED=2

cyberghost_up() {
  ip link show dev "$DEVICE" >/dev/null 2>&1
}

armed() {
  systemctl is-active --quiet "$UNIT"
}

notify_users() {
  local bus uid
  for bus in /run/user/*/bus; do
    [[ -S $bus ]] || continue
    uid=$(basename "$(dirname "$bus")")
    ((uid >= 1000)) || continue
    setpriv --reuid="$uid" --regid="$(id -g "$uid")" --clear-groups \
      env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
      notify-send -a Netzwerk -u critical "$1" "$2" || true
  done
}

# Watcher restarted while VPN up: no ACTIVATED event follows.
if cyberghost_up; then
  systemctl start "$UNIT"
fi

# Only CyberGhost profiles use NM's OpenVPN plugin, so every VpnStateChanged belongs to one.
busctl monitor --system --json=short \
  --match "type='signal',interface='org.freedesktop.NetworkManager.VPN.Connection',member='VpnStateChanged'" |
  jq --unbuffered -r 'select(.member == "VpnStateChanged") | .payload.data | "\(.[0]) \(.[1])"' |
  while read -r state reason; do
    if ((state == ACTIVATED)) && cyberghost_up; then
      systemctl start "$UNIT" || true
    elif ((state == FAILED || state == DISCONNECTED)) && armed; then
      if ((reason == USER_DISCONNECTED)); then
        systemctl stop "$UNIT" || true
      else
        notify_users "CyberGhost getrennt" \
          "Der Kill-Switch sperrt das Internet, bis CyberGhost wieder verbunden ist. Im Netzwerkmenü lässt er sich ausschalten."
      fi
    fi
  done
