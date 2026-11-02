# Shared by every script of this module.

# True while any VPN tunnel is up or coming up.
# Tailscale counts as none: reaches tailnet only.
tunnel_up() {
  nmcli -t -f TYPE connection show --active | grep -xE 'vpn|wireguard' >/dev/null && return 0
  { systemctl is-active "$WSTUNNEL_UNIT" || true; } | grep -xE 'active|activating' >/dev/null
}

armed() {
  systemctl is-active --quiet "$UNIT"
}

# Interface of each up tunnel, one per line.
# A VPN plugin connection reports its tun device as IP-IFACE, not the uplink.
tunnel_interfaces() {
  local uuid type
  nmcli -t -f UUID,TYPE connection show --active | while IFS=: read -r uuid type; do
    if [[ $type == vpn || $type == wireguard ]]; then
      nmcli -g GENERAL.IP-IFACE connection show --active "$uuid" || true
    fi
  done
  case $(systemctl is-active "$WSTUNNEL_UNIT" || true) in
    active | activating) echo "$WSTUNNEL_INTERFACE" ;;
  esac
}

# Rewrites TUNNEL_CHAIN to accept exactly the up tunnel interfaces.
# Lock keeps watcher, wstunnel hooks and firewall reload from interleaving rewrites.
sync_tunnels() (
  flock 9
  local interfaces interface ipt
  mapfile -t interfaces < <(tunnel_interfaces)
  for ipt in iptables ip6tables; do
    $ipt -F "$TUNNEL_CHAIN"
    for interface in "${interfaces[@]}"; do
      if [[ -n $interface ]]; then
        $ipt -A "$TUNNEL_CHAIN" -o "$interface" -j ACCEPT
      fi
    done
  done
) 9>"$LOCK_FILE"

