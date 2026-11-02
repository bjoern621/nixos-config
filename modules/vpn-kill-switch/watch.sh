# Arms kill switch when NM VPN or WireGuard connection comes up.
# Deliberate disconnect starts RELEASE_UNIT.
# Any other drop cancels pending release, keeps kill switch armed and notifies.
# Needs UNIT and RELEASE_UNIT in environment.

# NMActiveConnectionState and NMActiveConnectionStateReason values.
# Plugin VPNs and device connections like WireGuard report both alike.
readonly ACTIVATED=2 DEACTIVATED=4 USER_DISCONNECTED=2

# Active connection path -> NM connection type.
# DEACTIVATED arrives as object goes away, so type gets read on earlier states.
declare -A types

connection_type() {
  busctl --json=short get-property org.freedesktop.NetworkManager "$1" \
    org.freedesktop.NetworkManager.Connection.Active Type 2>/dev/null | jq -r .data || true
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

while IFS=: read -r type path; do
  types[$path]=$type
done < <(nmcli -t -f TYPE,ACTIVE-PATH connection show --active)

# Watcher restarted while tunnel up: no ACTIVATED event follows.
if tunnel_up; then
  systemctl start "$UNIT"
fi

busctl monitor --system --json=short \
  --match "type='signal',interface='org.freedesktop.NetworkManager.Connection.Active',member='StateChanged'" |
  jq --unbuffered -r 'select(.member == "StateChanged") | "\(.path) \(.payload.data[0]) \(.payload.data[1])"' |
  while read -r path state reason; do
    type=${types[$path]:-$(connection_type "$path")}
    if ((state == DEACTIVATED)); then
      unset "types[$path]"
    else
      types[$path]=$type
    fi
    [[ $type == vpn || $type == wireguard ]] || continue

    if ((state == ACTIVATED)); then
      systemctl start "$UNIT" || true
    elif ((state == DEACTIVATED)) && armed; then
      if ((reason == USER_DISCONNECTED)); then
        systemctl start --no-block "$RELEASE_UNIT" || true
      else
        # Next tunnel of a switch failed: pending release would leave uplink open.
        systemctl stop --no-block "$RELEASE_UNIT" || true
        notify_users "VPN getrennt" \
          "Der Kill-Switch sperrt das Internet, bis wieder ein VPN verbunden ist. Im Netzwerkmenü lässt er sich ausschalten."
      fi
    fi
  done
