{ pkgs, ... }:

# Policy-routing escape so eduVPN (HAW Hamburg) can actually connect.
#
# Problem: once the eduVPN client brings up its WireGuard interface, it installs
# a "send everything into the tunnel" rule at pref 4. During handshake the
# tunnel is not yet carrying traffic, so handshake / proxyguard fallback
# packets destined for the VPN server get black-holed inside the incomplete
# tunnel. eduVPN tries to escape this with a narrow per-socket rule, but its
# source port is often stale, so proxyguard's TCP dial times out and the
# connection fails.
#
# Fix: add a port-agnostic rule at pref 3 that forces any traffic to the
# eduVPN server IP through the main routing table (physical NIC). Rule is
# listed before eduVPN's own rule at the same priority, so ours wins.
#
# Harmless when eduVPN is not connected — just a single extra rule.
#
# Hardcoded to HAW's server IP (141.22.192.15). If HAW changes the IP this
# module needs updating.

{
  systemd.services.eduvpn-escape-rule = {
    description = "Policy-routing escape for eduVPN server (HAW Hamburg)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.iproute2}/bin/ip rule add pref 3 to 141.22.192.15/32 lookup main";
      ExecStop = "${pkgs.iproute2}/bin/ip rule del pref 3 to 141.22.192.15/32 lookup main";
    };
  };
}
