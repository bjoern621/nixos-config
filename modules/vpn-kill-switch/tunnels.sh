# Shared by watch.sh and release.sh.
# Needs WSTUNNEL_UNIT in environment.

# True while any VPN tunnel is up or coming up.
# Tailscale counts as none: reaches tailnet only.
tunnel_up() {
  nmcli -t -f TYPE connection show --active | grep -xE 'vpn|wireguard' >/dev/null && return 0
  { systemctl is-active "$WSTUNNEL_UNIT" || true; } | grep -xE 'active|activating' >/dev/null
}

armed() {
  systemctl is-active --quiet "$UNIT"
}

