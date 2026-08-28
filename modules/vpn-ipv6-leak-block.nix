{ pkgs, ... }:

# Public IPv6 dies while an NM vpn-type connection is up.
# CyberGhost tunnels IPv4 only, uplink keeps its IPv6 default route,
# so AAAA traffic bypasses the tunnel with the real address.
# Unreachable default at metric 50 beats RA defaults (ethernet 100, wifi 600).
# Connect attempts fail instantly with ENETUNREACH, happy-eyeballs falls to IPv4 through tunnel.
# Link-local and on-link /64 survive (more specific routes), only internet IPv6 dies.
# vpn-up/vpn-down fire for NM vpn-type connections only (plugin VPNs like OpenVPN).
# Applies to every current and future vpn-type profile, none by name.
# VPN pushing its own IPv6 config routes v6 through tunnel itself, block skipped.
# wireguard-type and non-NM tunnels (Tailscale) fire plain up/down, stay unaffected.
# Leak window: established IPv6 flows die on route insert, but the seconds between
# tunnel up and dispatcher run leak; same on NM crash until reboot removes the route.

{
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "vpn-ipv6-leak-block" ''
        case "$2" in
          vpn-up)
            # VPN with own IPv6 config carries v6 in-tunnel, no leak to block.
            [ "''${VPN_IP6_NUM_ADDRESSES:-0}" -gt 0 ] && exit 0
            ${pkgs.iproute2}/bin/ip -6 route replace unreachable default metric 50
            ;;
          vpn-down) ${pkgs.iproute2}/bin/ip -6 route del unreachable default metric 50 2>/dev/null || true ;;
        esac
      '';
    }
  ];
}
