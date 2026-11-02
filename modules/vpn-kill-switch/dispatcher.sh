# NetworkManager dispatcher: records tunnel interface per connection, then rewrites TUNNEL_CHAIN.
# GENERAL.IP-IFACE of a VPN plugin connection names the uplink, so the tun device comes from VPN_IP_IFACE.

interface=${1:-}
action=${2:-}
file=$STATE_DIR/${CONNECTION_UUID:-none}

case $action in
  vpn-up)
    echo "${VPN_IP_IFACE:?}" >"$file"
    ;;
  up)
    [[ $(nmcli -g connection.type connection show "$CONNECTION_UUID" 2>/dev/null) == wireguard ]] || exit 0
    echo "$interface" >"$file"
    ;;
  vpn-down | down)
    [[ -f $file ]] || exit 0
    rm -f "$file"
    ;;
  *)
    exit 0
    ;;
esac
sync_tunnels
